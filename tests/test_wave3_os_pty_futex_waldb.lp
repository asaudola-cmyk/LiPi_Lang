// ==============================================================================
// LIPI PERMANENT REGRESSION TEST: WAVE 3 OS + PTY + IPC + FUTEX + CRASH-SAFE WAL DB
// Verifies:
//   1. Mutable StrDict Env + Real Child Process Inheritance
//   2. process_capture_full (stdout, stderr, stdin, exit code, SIGKILL timeout)
//   3. fs_write_atomic (fsync+rename), fs_lock/unlock (SYS_flock), O(N) fs_read_lines
//   4. Live /dev/ptmx Linux PTY (pty_spawn, pty_resize, pty_read, pty_close)
//   5. Real Linux Kernel IPC (SYS_pipe2, AF_UNIX socketpair, memfd MAP_SHARED)
//   6. Linux SYS_futex Sync Suite (Mutex trylock, RwLock, Blocking MPSC, ThreadPool)
//   7. Pure-Lipi Crash-Safe Binary CRC-32 WAL KV DB (db_open, torn-tail healing, db_compact)
// ==============================================================================

include "utso/os/env.lp"
include "utso/os/process.lp"
include "utso/os/fs.lp"
include "utso/os/pty.lp"
include "utso/os/ipc.lp"
include "utso/os/thread.lp"
include "utso/core/db.lp"

fn w3_assert cond msg
    if cond == 0
        say "FAIL W3: " + msg
        syscall(231, 1, 0, 0, 0, 0, 0)
    end
    return 0

fn w3_mpsc_producer arg
    ch = mem_word_read(arg, 0)
    base = mem_word_read(arg, 8)
    i = 0
    while i < 100
        mpsc_send(ch, base + i)
        i = i + 1
    end
    return 0

fn w3_tp_task counter_ptr
    atomic_add(counter_ptr, 1)
    return 0

fn w3_rw_worker ctrl
    rw = mem_word_read(ctrl, 0)
    val_ptr = ctrl + 8
    i = 0
    while i < 50
        futex_rwlock_wrlock(rw)
        cur = mem_word_read(val_ptr, 0)
        mem_word_write(val_ptr, 0, cur + 1)
        futex_rwlock_wrunlock(rw)
        futex_rwlock_rdlock(rw)
        _r = mem_word_read(val_ptr, 0)
        futex_rwlock_rdunlock(rw)
        i = i + 1
    end
    return 0

fn main
    // 1. Env + Process inheritance + process_capture_full + timeout
    env_set("LIPI_W3_TOKEN", "SOVEREIGN_99")
    w3_assert(str_eq(env_get("LIPI_W3_TOKEN"), "SOVEREIGN_99") == 1, "env_set/get")
    w3_assert(env_has("LIPI_W3_TOKEN") == 1, "env_has true")
    c_res = process_capture("/bin/sh", ["-c", "printf '%s' \"$LIPI_W3_TOKEN\""])
    w3_assert(c_res.exit_code == 0 && str_eq(c_res.output, "SOVEREIGN_99") == 1, "child inherited env_set")
    env_unset("LIPI_W3_TOKEN")
    w3_assert(env_has("LIPI_W3_TOKEN") == 0, "env_unset")

    r_full = process_capture_full("/bin/sh", ["-c", "cat; printf 'ERR_OK' >&2; exit 7"], "IN_DATA_42", 5000)
    w3_assert(str_eq(r_full.stdout, "IN_DATA_42") == 1, "capture_full stdout")
    w3_assert(str_eq(r_full.stderr, "ERR_OK") == 1, "capture_full stderr")
    w3_assert(r_full.exit_code == 7 && r_full.timed_out == 0, "capture_full exit_code")

    r_to = process_capture_full("/bin/sh", ["-c", "sleep 3"], "", 120)
    w3_assert(r_to.timed_out == 1, "capture_full timeout enforced")

    // 2. FS atomic + flock + O(N) read_lines
    at_path = "/tmp/lipi_tst_w3_atomic_" + str(process_getpid()) + ".txt"
    w3_assert(fs_write_atomic(at_path, "alpha\nbeta\ngamma\n") == 1, "fs_write_atomic")
    lines = fs_read_lines(at_path)
    w3_assert(lines.len() == 3 && str_eq(lines[1], "beta") == 1, "fs_read_lines O(N)")
    lfd = syscall(2, at_path, 2, 0, 0, 0, 0)
    w3_assert(fs_lock(lfd, 1) == 0 && fs_unlock(lfd) == 0, "fs_lock/unlock")
    syscall(3, lfd, 0, 0, 0, 0, 0)
    syscall(87, at_path, 0, 0, 0, 0, 0)

    // 3. Real Linux PTY (/dev/ptmx)
    p = pty_spawn("/bin/sh", ["-c", "echo PTY_SOVEREIGN_OK"], 24, 80)
    w3_assert(p.pty_master_fd >= 0 && p.pty_child_pid > 0, "pty_spawn")
    pty_resize(p, 30, 100)
    pty_acc = buf_new(256)
    tries = 0
    while tries < 20
        chunk = pty_read(p, 256, 100)
        if str_len(chunk) > 0
            buf_write_str(pty_acc, chunk)
            if str_contains(buf_to_str(pty_acc), "PTY_SOVEREIGN_OK") == 1
                break
            end
        end
        tries = tries + 1
    end
    pty_out = buf_to_str(pty_acc)
    buf_free(pty_acc)
    pty_close(p)
    w3_assert(str_contains(pty_out, "PTY_SOVEREIGN_OK") == 1, "pty output verified")

    // 4. Real Kernel IPC (SYS_pipe2, AF_UNIX socketpair, memfd MAP_SHARED)
    kp = ipc_pipe_open()
    w3_assert(kp.open == 1 && ipc_pipe_write(kp, "PIPE_OK_123") == 11, "ipc_pipe_write")
    w3_assert(str_eq(ipc_pipe_read(kp, 64), "PIPE_OK_123") == 1, "ipc_pipe_read")
    ipc_pipe_close(kp)

    up = ipc_unix_pair()
    w3_assert(up.open == 1 && ipc_unix_send(up.fd0, "UNIX_PAIR_OK") == 12, "ipc_unix_send")
    w3_assert(str_eq(ipc_unix_recv(up.fd1, 64), "UNIX_PAIR_OK") == 1, "ipc_unix_recv")
    ipc_unix_close(up.fd0)
    ipc_unix_close(up.fd1)

    kshm = ipc_shm_kernel_create("lipi_w3_shm", 4096)
    w3_assert(kshm.shm_fd >= 0 && kshm.shm_ptr > 0, "ipc_shm_kernel_create")
    w3_assert(ipc_shm_kernel_write(kshm, 64, "MEMFD_SHARED_OK") == 15, "ipc_shm_kernel_write")
    w3_assert(str_eq(ipc_shm_kernel_read(kshm, 64, 15), "MEMFD_SHARED_OK") == 1, "ipc_shm_kernel_read")
    ipc_shm_kernel_close(kshm)

    // 5. FutexMutex trylock + FutexRwLock + Blocking MPSC + ThreadPool
    mtx = futex_mutex_new()
    w3_assert(futex_mutex_trylock(mtx) == 1 && futex_mutex_trylock(mtx) == 0, "futex_mutex_trylock")
    futex_mutex_unlock(mtx)
    futex_mutex_free(mtx)

    rw = futex_rwlock_new()
    rw_ctrl = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    mem_word_write(rw_ctrl, 0, rw)
    mem_word_write(rw_ctrl, 8, 0)
    rwh = []
    ri = 0
    while ri < 4
        rwh = push(rwh, thread_spawn_joinable(fn_ptr(w3_rw_worker), rw_ctrl, 65536))
        ri = ri + 1
    end
    ri = 0
    while ri < 4
        thread_join(rwh[ri])
        ri = ri + 1
    end
    w3_assert(mem_word_read(rw_ctrl, 8) == 200, "4x50 FutexRwLock == 200")
    futex_rwlock_free(rw)
    syscall(11, rw_ctrl, 4096, 0, 0, 0, 0)

    ch = mpsc_new(16)
    p_args = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    ph = []
    pi = 0
    while pi < 4
        pa = p_args + (pi * 16)
        mem_word_write(pa, 0, ch)
        mem_word_write(pa, 8, pi * 100)
        ph = push(ph, thread_spawn_joinable(fn_ptr(w3_mpsc_producer), pa, 65536))
        pi = pi + 1
    end
    mpsc_sum = 0
    rec_cnt = 0
    out_slot = alloc(8)
    while rec_cnt < 400
        w3_assert(mpsc_recv_ok(ch, out_slot) == 1, "mpsc_recv_ok")
        mpsc_sum = mpsc_sum + mem_word_read(out_slot, 0)
        rec_cnt = rec_cnt + 1
    end
    pi = 0
    while pi < 4
        thread_join(ph[pi])
        pi = pi + 1
    end
    mpsc_close(ch)
    w3_assert(mpsc_recv_ok(ch, out_slot) == 0, "mpsc closed == 0")
    free(out_slot)
    mpsc_free(ch)
    syscall(11, p_args, 4096, 0, 0, 0, 0)
    w3_assert(mpsc_sum == 79800, "4-producer MPSC sum == 79800")

    tp_cnt = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    mem_word_write(tp_cnt, 0, 0)
    pool = threadpool_new(4)
    ti = 0
    while ti < 200
        threadpool_submit(pool, fn_ptr(w3_tp_task), tp_cnt)
        ti = ti + 1
    end
    threadpool_shutdown(pool)
    w3_assert(mem_word_read(tp_cnt, 0) == 200, "ThreadPool 200 tasks")
    syscall(11, tp_cnt, 4096, 0, 0, 0, 0)

    // 6. Crash-Safe Binary CRC-32 WAL KV DB
    db_path = "/tmp/lipi_tst_w3_wal_" + str(process_getpid()) + ".ldb"
    syscall(87, db_path, 0, 0, 0, 0, 0)
    db = db_open(db_path)
    db_set_sync(db, 0)
    di = 0
    while di < 200
        db = db_insert(db, "key_" + int_to_str(di), "val_" + int_to_str(di * 10))
        di = di + 1
    end
    db_sync(db)
    db_set_sync(db, 1)
    di = 0
    while di < 20
        db = db_delete(db, "key_" + int_to_str(di))
        di = di + 1
    end
    db = db_insert(db, "null_literal", "NULL")
    o1 = db_get_opt(db, "null_literal")
    o2 = db_get_opt(db, "never_existed")
    w3_assert(o1.found == 1 && str_eq(o1.value, "NULL") == 1 && o2.found == 0, "db_get_opt")

    db = db_begin_tx(db)
    db = db_insert(db, "tx_key", "committed_val")
    db = db_commit_tx(db)
    db = db_begin_tx(db)
    db = db_insert(db, "tx_rb_key", "should_vanish")
    db = db_rollback_tx(db)
    w3_assert(db_count(db) == 182 && db_has(db, "tx_key") == 1 && db_has(db, "tx_rb_key") == 0, "db tx")
    db_close(db)

    // Simulate 19-byte torn crash tail
    cfd = syscall(2, db_path, 1025, 420, 0, 0, 0)
    syscall(1, cfd, "TORN_CRASH_GARBAGE!", 19, 0, 0, 0)
    syscall(3, cfd, 0, 0, 0, 0, 0)

    db2 = db_open(db_path)
    w3_assert(db2.recovered_truncated == 19 && db_count(db2) == 182, "WAL torn-tail healing")
    w3_assert(str_eq(db_get(db2, "tx_key"), "committed_val") == 1 && db_has(db2, "key_5") == 0, "WAL replay")
    sz_before = syscall(8, db2.fd, 0, 2, 0, 0, 0)
    compacted_n = db_compact(db2)
    sz_after = syscall(8, db2.fd, 0, 2, 0, 0, 0)
    w3_assert(compacted_n == 182 && sz_after < sz_before, "db_compact")
    db_close(db2)

    db3 = db_open(db_path)
    w3_assert(db_count(db3) == 182 && str_eq(db_get(db3, "key_150"), "val_1500") == 1, "post-compact reopen")
    db_close(db3)
    syscall(87, db_path, 0, 0, 0, 0, 0)

    say "PASS: test_wave3_os_pty_futex_waldb (env+proc+fs+pty+ipc+futex+mpsc+tp+waldb)"
    return 0
