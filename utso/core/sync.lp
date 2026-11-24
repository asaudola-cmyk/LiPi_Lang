// ==============================================================================
// LIPI PURE KERNEL SYNCHRONIZATION & WORKER THREADPOOL (utso/core/sync.lp)
// 100% Pure Lipi | 0% libc | 0% pthreads | Direct x86_64 Atomics + Linux SYS_futex
// Provides:
//   - FutexMutex (Drepper 3-state lock/trylock/unlock/free)
//   - FutexCondvar (race-free monotonic sequence wait/signal/broadcast/free)
//   - FutexRwLock (single-word atomic reader-writer lock rdlock/rdunlock/wrlock/wrunlock/free)
//   - Blocking MPSC Channel (mpsc_new/send/recv/recv_ok/try_recv/close/len/free)
//   - Joinable Worker ThreadPool (threadpool_new/submit/shutdown)
// ==============================================================================

// ── 1. Drepper 3-State Futex Mutex ────────────────────────────────────────────
// State word at offset 0: 0 = unlocked, 1 = locked (uncontended), 2 = locked (contended)
fn futex_mutex_new
    m = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if m <= 0
        return 0
    end
    mem_word_write(m, 0, 0)
    mem_word_write(m, 8, 0)
    return m

fn futex_mutex_trylock mtx
    // WHY: Single lock cmpxchg fast-path acquisition returning 1 on success, 0 if held.
    return atomic_cas(mtx, 0, 1)

fn futex_mutex_lock mtx
    // WHY: 1-instruction lock cmpxchg fast path; kernel SYS_futex sleep only on contention.
    if atomic_cas(mtx, 0, 1) == 1
        return 1
    end
    while atomic_cas(mtx, 0, 2) == 0
        atomic_cas(mtx, 1, 2)
        futex_wait(mtx, 2)
    end
    return 1

fn futex_mutex_unlock mtx
    // WHY: Uncontended fast unlock (1->0); wakes kernel futex waiter when state==2.
    if atomic_cas(mtx, 1, 0) == 1
        return 0
    end
    while atomic_cas(mtx, 2, 0) == 0
        if atomic_cas(mtx, 1, 0) == 1
            return 0
        end
    end
    futex_wake(mtx, 1)
    return 0

fn futex_mutex_free mtx
    if mtx > 0
        syscall(11, mtx, 4096, 0, 0, 0, 0)
    end
    return 0

fn ফিউটেক্স_লক mtx
    return futex_mutex_lock(mtx)

fn ফিউটেক্স_আনলক mtx
    return futex_mutex_unlock(mtx)

// ── 2. Zero-Lost-Wakeup Futex Condition Variable ──────────────────────────────
// Offset 0: monotonic 31-bit sequence counter (always >= 0 for Linux 32-bit FUTEX_WAIT)
fn futex_condvar_new
    cv = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if cv <= 0
        return 0
    end
    mem_word_write(cv, 0, 0)
    return cv

fn futex_condvar_wait cv mtx
    // WHY: Captures sequence under mtx before unlocking so any concurrent signal/broadcast
    // bumps *cv != seq, causing SYS_futex to return -EAGAIN immediately with zero lost wakeups.
    seq = mem_word_read(cv, 0) & 2147483647
    futex_mutex_unlock(mtx)
    futex_wait(cv, seq)
    futex_mutex_lock(mtx)
    return 1

fn futex_condvar_signal cv
    swapped = 0
    while swapped == 0
        old_s = mem_word_read(cv, 0)
        new_s = (old_s + 1) & 2147483647
        swapped = atomic_cas(cv, old_s, new_s)
    end
    futex_wake(cv, 1)
    return 1

fn futex_condvar_broadcast cv
    swapped = 0
    while swapped == 0
        old_s = mem_word_read(cv, 0)
        new_s = (old_s + 1) & 2147483647
        swapped = atomic_cas(cv, old_s, new_s)
    end
    futex_wake(cv, 2147483647)
    return 1

fn futex_condvar_free cv
    if cv > 0
        syscall(11, cv, 4096, 0, 0, 0, 0)
    end
    return 0

// ── 3. Single-Word Atomic Futex Reader-Writer Lock ────────────────────────────
// State word at offset 0 (all states strictly within positive signed 32-bit range):
//   0             = unlocked
//   1..536870911  = active concurrent reader count
//   536870912     = exclusive writer active (1 << 29)
fn futex_rwlock_new
    rw = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if rw <= 0
        return 0
    end
    mem_word_write(rw, 0, 0)
    return rw

fn futex_rwlock_rdlock rw
    while 1 == 1
        st = mem_word_read(rw, 0)
        if (st & 536870912) == 0
            if atomic_cas(rw, st, st + 1) == 1
                return 1
            end
        else
            futex_wait(rw, st)
        end
    end
    return 1

fn futex_rwlock_rdunlock rw
    while 1 == 1
        st = mem_word_read(rw, 0)
        nxt = st - 1
        if atomic_cas(rw, st, nxt) == 1
            if nxt == 0
                futex_wake(rw, 2147483647)
            end
            return 0
        end
    end
    return 0

fn futex_rwlock_wrlock rw
    while 1 == 1
        st = mem_word_read(rw, 0)
        if st == 0
            if atomic_cas(rw, 0, 536870912) == 1
                return 1
            end
        else
            futex_wait(rw, st)
        end
    end
    return 1

fn futex_rwlock_wrunlock rw
    atomic_cas(rw, 536870912, 0)
    futex_wake(rw, 2147483647)
    return 0

fn futex_rwlock_free rw
    if rw > 0
        syscall(11, rw, 4096, 0, 0, 0, 0)
    end
    return 0

// ── 4. Zero-Spin Blocking Futex MPSC Channel ──────────────────────────────────
// Control page (4096B anonymous mmap, GC-immune across OS threads):
//   0:  mtx          8: cv_not_empty  16: cv_not_full
//   24: buf_ptr      32: cap          40: head
//   48: tail         56: count        64: closed
//   72: buf_bytes
fn mpsc_new capacity
    cap = capacity
    if cap < 4
        cap = 4
    end
    ch = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if ch <= 0
        return 0
    end
    buf_bytes = ((cap * 8 + 4095) / 4096) * 4096
    buf = syscall(9, 0, buf_bytes, 3, 34, 0 - 1, 0)
    if buf <= 0
        syscall(11, ch, 4096, 0, 0, 0, 0)
        return 0
    end
    mtx = futex_mutex_new()
    cv_ne = futex_condvar_new()
    cv_nf = futex_condvar_new()
    mem_word_write(ch, 0, mtx)
    mem_word_write(ch, 8, cv_ne)
    mem_word_write(ch, 16, cv_nf)
    mem_word_write(ch, 24, buf)
    mem_word_write(ch, 32, cap)
    mem_word_write(ch, 40, 0)
    mem_word_write(ch, 48, 0)
    mem_word_write(ch, 56, 0)
    mem_word_write(ch, 64, 0)
    mem_word_write(ch, 72, buf_bytes)
    return ch

fn mpsc_send ch val
    mtx = mem_word_read(ch, 0)
    cv_ne = mem_word_read(ch, 8)
    cv_nf = mem_word_read(ch, 16)
    buf = mem_word_read(ch, 24)
    cap = mem_word_read(ch, 32)
    futex_mutex_lock(mtx)
    while mem_word_read(ch, 56) >= cap and mem_word_read(ch, 64) == 0
        futex_condvar_wait(cv_nf, mtx)
    end
    if mem_word_read(ch, 64) == 1
        futex_mutex_unlock(mtx)
        return 0
    end
    tail = mem_word_read(ch, 48)
    mem_word_write(buf, tail * 8, val)
    ntail = tail + 1
    if ntail >= cap
        ntail = 0
    end
    mem_word_write(ch, 48, ntail)
    mem_word_write(ch, 56, mem_word_read(ch, 56) + 1)
    futex_mutex_unlock(mtx)
    futex_condvar_signal(cv_ne)
    return 1

fn mpsc_recv_ok ch out_ptr
    // WHY: Blocks on kernel futex until item arrives or channel closes; writes value to out_ptr.
    // Returns 1 if an item was received, 0 if channel is closed and drained.
    mtx = mem_word_read(ch, 0)
    cv_ne = mem_word_read(ch, 8)
    cv_nf = mem_word_read(ch, 16)
    buf = mem_word_read(ch, 24)
    cap = mem_word_read(ch, 32)
    futex_mutex_lock(mtx)
    while mem_word_read(ch, 56) == 0 and mem_word_read(ch, 64) == 0
        futex_condvar_wait(cv_ne, mtx)
    end
    if mem_word_read(ch, 56) == 0
        futex_mutex_unlock(mtx)
        return 0
    end
    head = mem_word_read(ch, 40)
    val = mem_word_read(buf, head * 8)
    nhead = head + 1
    if nhead >= cap
        nhead = 0
    end
    mem_word_write(ch, 40, nhead)
    mem_word_write(ch, 56, mem_word_read(ch, 56) - 1)
    futex_mutex_unlock(mtx)
    futex_condvar_signal(cv_nf)
    if out_ptr > 0
        mem_word_write(out_ptr, 0, val)
    end
    return 1

fn mpsc_recv ch
    mtx = mem_word_read(ch, 0)
    cv_ne = mem_word_read(ch, 8)
    cv_nf = mem_word_read(ch, 16)
    buf = mem_word_read(ch, 24)
    cap = mem_word_read(ch, 32)
    futex_mutex_lock(mtx)
    while mem_word_read(ch, 56) == 0 and mem_word_read(ch, 64) == 0
        futex_condvar_wait(cv_ne, mtx)
    end
    if mem_word_read(ch, 56) == 0
        futex_mutex_unlock(mtx)
        return 0 - 1
    end
    head = mem_word_read(ch, 40)
    val = mem_word_read(buf, head * 8)
    nhead = head + 1
    if nhead >= cap
        nhead = 0
    end
    mem_word_write(ch, 40, nhead)
    mem_word_write(ch, 56, mem_word_read(ch, 56) - 1)
    futex_mutex_unlock(mtx)
    futex_condvar_signal(cv_nf)
    return val

fn mpsc_try_recv ch out_ptr
    // Returns 1 if popped, 0 if empty (still open), -1 if closed & empty.
    mtx = mem_word_read(ch, 0)
    cv_nf = mem_word_read(ch, 16)
    buf = mem_word_read(ch, 24)
    cap = mem_word_read(ch, 32)
    futex_mutex_lock(mtx)
    cnt = mem_word_read(ch, 56)
    if cnt == 0
        cls = mem_word_read(ch, 64)
        futex_mutex_unlock(mtx)
        if cls == 1
            return 0 - 1
        end
        return 0
    end
    head = mem_word_read(ch, 40)
    val = mem_word_read(buf, head * 8)
    nhead = head + 1
    if nhead >= cap
        nhead = 0
    end
    mem_word_write(ch, 40, nhead)
    mem_word_write(ch, 56, cnt - 1)
    futex_mutex_unlock(mtx)
    futex_condvar_signal(cv_nf)
    if out_ptr > 0
        mem_word_write(out_ptr, 0, val)
    end
    return 1

fn mpsc_len ch
    mtx = mem_word_read(ch, 0)
    futex_mutex_lock(mtx)
    cnt = mem_word_read(ch, 56)
    futex_mutex_unlock(mtx)
    return cnt

fn mpsc_close ch
    mtx = mem_word_read(ch, 0)
    cv_ne = mem_word_read(ch, 8)
    cv_nf = mem_word_read(ch, 16)
    futex_mutex_lock(mtx)
    mem_word_write(ch, 64, 1)
    futex_mutex_unlock(mtx)
    futex_condvar_broadcast(cv_ne)
    futex_condvar_broadcast(cv_nf)
    return 1

fn mpsc_free ch
    if ch <= 0
        return 0
    end
    futex_mutex_free(mem_word_read(ch, 0))
    futex_condvar_free(mem_word_read(ch, 8))
    futex_condvar_free(mem_word_read(ch, 16))
    buf = mem_word_read(ch, 24)
    buf_bytes = mem_word_read(ch, 72)
    if buf > 0 and buf_bytes > 0
        syscall(11, buf, buf_bytes, 0, 0, 0, 0)
    end
    syscall(11, ch, 4096, 0, 0, 0, 0)
    return 0

// ── 5. Joinable OS Worker ThreadPool (CLONE_VM + SYS_futex) ───────────────────
// Control page (4096B anonymous mmap):
//   0:  mtx         8:  cv_task      16: cv_space
//   24: q_buf       32: q_cap        40: q_head
//   48: q_tail      56: q_count      64: shutdown
//   72: num_workers 80: handles_buf  88: q_bytes
//   96: h_bytes
// Each handle in handles_buf is a 24B struct [tid_word, stack_base, stack_sz]
fn _tp_worker_entry pool
    mtx = mem_word_read(pool, 0)
    cv_task = mem_word_read(pool, 8)
    cv_space = mem_word_read(pool, 16)
    q_buf = mem_word_read(pool, 24)
    q_cap = mem_word_read(pool, 32)
    while 1 == 1
        futex_mutex_lock(mtx)
        while mem_word_read(pool, 56) == 0 and mem_word_read(pool, 64) == 0
            futex_condvar_wait(cv_task, mtx)
        end
        if mem_word_read(pool, 56) == 0 and mem_word_read(pool, 64) == 1
            futex_mutex_unlock(mtx)
            return 0
        end
        head = mem_word_read(pool, 40)
        slot_off = head * 16
        task_fn = mem_word_read(q_buf, slot_off)
        task_arg = mem_word_read(q_buf, slot_off + 8)
        nhead = head + 1
        if nhead >= q_cap
            nhead = 0
        end
        mem_word_write(pool, 40, nhead)
        mem_word_write(pool, 56, mem_word_read(pool, 56) - 1)
        futex_mutex_unlock(mtx)
        futex_condvar_signal(cv_space)
        if task_fn != 0
            task_fn(task_arg)
        end
    end
    return 0

fn threadpool_new num_workers
    // WHY: Pre-initializes runtime bump heap before cloning OS workers so all threads share heap state safely.
    _heap_init = list()
    nw = num_workers
    if nw < 1
        nw = 1
    end
    if nw > 128
        nw = 128
    end
    pool = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if pool <= 0
        return 0
    end
    q_cap = 1024
    q_bytes = q_cap * 16
    q_buf = syscall(9, 0, q_bytes, 3, 34, 0 - 1, 0)
    h_bytes = ((nw * 24 + 4095) / 4096) * 4096
    h_buf = syscall(9, 0, h_bytes, 3, 34, 0 - 1, 0)
    if q_buf <= 0 or h_buf <= 0
        if q_buf > 0
            syscall(11, q_buf, q_bytes, 0, 0, 0, 0)
        end
        if h_buf > 0
            syscall(11, h_buf, h_bytes, 0, 0, 0, 0)
        end
        syscall(11, pool, 4096, 0, 0, 0, 0)
        return 0
    end
    mem_word_write(pool, 0, futex_mutex_new())
    mem_word_write(pool, 8, futex_condvar_new())
    mem_word_write(pool, 16, futex_condvar_new())
    mem_word_write(pool, 24, q_buf)
    mem_word_write(pool, 32, q_cap)
    mem_word_write(pool, 40, 0)
    mem_word_write(pool, 48, 0)
    mem_word_write(pool, 56, 0)
    mem_word_write(pool, 64, 0)
    mem_word_write(pool, 72, 0)
    mem_word_write(pool, 80, h_buf)
    mem_word_write(pool, 88, q_bytes)
    mem_word_write(pool, 96, h_bytes)

    stack_sz = 131072
    spawned = 0
    wi = 0
    while wi < nw
        st_base = syscall(9, 0, stack_sz, 3, 34, 0 - 1, 0)
        if st_base <= 0
            break
        end
        h_ptr = h_buf + (spawned * 24)
        mem_word_write(h_ptr, 0, 1)
        mem_word_write(h_ptr, 8, st_base)
        mem_word_write(h_ptr, 16, stack_sz)
        tid = thread_spawn_vm_joinable(fn_ptr(_tp_worker_entry), pool, st_base + stack_sz, h_ptr)
        if tid <= 0
            syscall(11, st_base, stack_sz, 0, 0, 0, 0)
            mem_word_write(h_ptr, 0, 0)
            break
        end
        spawned = spawned + 1
        wi = wi + 1
    end
    mem_word_write(pool, 72, spawned)
    return pool

fn threadpool_submit pool task_fn arg
    mtx = mem_word_read(pool, 0)
    cv_task = mem_word_read(pool, 8)
    cv_space = mem_word_read(pool, 16)
    q_buf = mem_word_read(pool, 24)
    q_cap = mem_word_read(pool, 32)
    futex_mutex_lock(mtx)
    while mem_word_read(pool, 56) >= q_cap and mem_word_read(pool, 64) == 0
        futex_condvar_wait(cv_space, mtx)
    end
    if mem_word_read(pool, 64) == 1
        futex_mutex_unlock(mtx)
        return 0
    end
    tail = mem_word_read(pool, 48)
    slot_off = tail * 16
    mem_word_write(q_buf, slot_off, task_fn)
    mem_word_write(q_buf, slot_off + 8, arg)
    ntail = tail + 1
    if ntail >= q_cap
        ntail = 0
    end
    mem_word_write(pool, 48, ntail)
    mem_word_write(pool, 56, mem_word_read(pool, 56) + 1)
    futex_mutex_unlock(mtx)
    futex_condvar_signal(cv_task)
    return 1

fn threadpool_shutdown pool
    // WHY: Drains all queued tasks, wakes all sleeping workers, joins each OS thread via kernel
    // CLONE_CHILD_CLEARTID futex, unmaps every stack, and frees all control memory cleanly.
    if pool <= 0
        return 0
    end
    mtx = mem_word_read(pool, 0)
    cv_task = mem_word_read(pool, 8)
    cv_space = mem_word_read(pool, 16)
    futex_mutex_lock(mtx)
    mem_word_write(pool, 64, 1)
    futex_mutex_unlock(mtx)
    futex_condvar_broadcast(cv_task)
    futex_condvar_broadcast(cv_space)

    nw = mem_word_read(pool, 72)
    h_buf = mem_word_read(pool, 80)
    wi = 0
    while wi < nw
        h_ptr = h_buf + (wi * 24)
        cur_tid = mem_word_read(h_ptr, 0) & 4294967295
        while cur_tid != 0
            futex_wait(h_ptr, cur_tid)
            cur_tid = mem_word_read(h_ptr, 0) & 4294967295
        end
        st_base = mem_word_read(h_ptr, 8)
        st_sz = mem_word_read(h_ptr, 16)
        if st_base > 0 and st_sz > 0
            syscall(11, st_base, st_sz, 0, 0, 0, 0)
        end
        wi = wi + 1
    end

    futex_mutex_free(mtx)
    futex_condvar_free(cv_task)
    futex_condvar_free(cv_space)
    syscall(11, mem_word_read(pool, 24), mem_word_read(pool, 88), 0, 0, 0, 0)
    syscall(11, h_buf, mem_word_read(pool, 96), 0, 0, 0, 0)
    syscall(11, pool, 4096, 0, 0, 0, 0)
    return 1
