// ==============================================================================
// 📜 লিপি খাঁটি কার্নেল মাল্টি-থ্রেডিং ও কনকারেন্সি লাইব্রেরি (Pure Lipi Native Multithreading Library)
// 🏛️ সরাসরি লিনাক্স কার্নেল পেজ-শেয়ার্ড মাল্টি-থ্রেডিং (Linux AMD64 Kernel SYS_clone ABI)
// ০% Libc, ০% pthreads নির্ভরতা — সরাসরি SYS_clone (56), SYS_sched_yield (24), SYS_exit (60)
// ==============================================================================
//
// WHY: আধুনিক মাল্টি-কোর সিলিকন প্রসেসরের পূর্ণ শক্তি ব্যবহারের জন্য সরাসরি কার্নেল থ্রেড সৃষ্টি করা।
// CLONE_VM (256) | CLONE_FS (512) | CLONE_FILES (1024) | CLONE_SIGHAND (2048) | CLONE_THREAD (65536) = 69376 (0x10f00)

include "utso/core/memory.lp"
include "utso/core/sync.lp"

// ── ১. নেটিভ লিনাক্স কার্নেল থ্রেড সৃষ্টি (Spawn Real Linux Thread via SYS_clone: syscall 56) ──
// WHY: নতুন থ্রেডের জন্য কার্নেল স্পেসে এক্সিকিউশন কন্টেক্সট তৈরি করা।
// Uses real Linux CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND (0x00000F00 = 3840) and passes
// caller-supplied stack_top (with relocated active activation frame + RBP so child runs on
// stack_top without clobbering parent's stack). Note: CLONE_THREAD (0x00010000) is intentionally
// omitted in fork-style thread_create so wait4(tid, ..., __WCLONE) (e.g. test 21) waits cleanly
// instead of returning -ECHILD; for CLONE_THREAD (0x00010F00) + GC-tracked threads use
// thread_spawn / thread_spawn_shared / thread_spawn_joinable below.
// When stack_top == 0, falls back to SYS_fork (57).
// চাইল্ড থ্রেডে ০ রিটার্ন করে, প্যারেন্ট থ্রেডে চাইল্ড থ্রেড আইডি (TID > 0) রিটার্ন করে।
@naked
fn thread_create stack_top
    // WHY: @naked avoids prologue/epilogue so parent RBP/RSP stay untouched and child atomically
    // pivots both RSP (via kernel clone child_stack) and RBP (via syscall-preserved r9) onto stack_top.
    @asm [
        72, 133, 255,                   // test rdi, rdi
        117, 8,                         // jnz .do_clone (+8)
        184, 57, 0, 0, 0,               // mov eax, 57 (SYS_fork)
        15, 5,                          // syscall
        195,                            // ret
        72, 137, 233,                   // mov rcx, rbp
        72, 41, 225,                    // sub rcx, rsp
        72, 129, 249, 0, 128, 0, 0,     // cmp rcx, 32768 (covers top-level 4KB+ frames & wrappers)
        118, 7,                         // jbe +7
        185, 0, 2, 0, 0,                // mov ecx, 512
        235, 7,                         // jmp +7
        72, 129, 193, 0, 2, 0, 0,       // add rcx, 512
        72, 131, 193, 15,               // add rcx, 15
        72, 131, 225, 240,              // and rcx, -16
        72, 131, 231, 240,              // and rdi, -16
        72, 41, 207,                    // sub rdi, rcx
        72, 131, 239, 16,               // sub rdi, 16
        72, 137, 224,                   // mov rax, rsp
        72, 131, 224, 15,               // and rax, 15
        72, 9, 199,                     // or rdi, rax
        73, 137, 248,                   // mov r8, rdi (child_sp)
        77, 137, 195,                   // mov r11, r8
        73, 41, 227,                    // sub r11, rsp (delta)
        73, 137, 233,                   // mov r9, rbp
        77, 1, 217,                     // add r9, r11 (child_rbp)
        72, 137, 230,                   // mov rsi, rsp
        252,                            // cld
        243, 164,                       // rep movsb
        77, 139, 17,                    // mov r10, [r9]
        73, 57, 226,                    // cmp r10, rsp
        114, 11,                        // jb +11
        73, 57, 242,                    // cmp r10, rsi
        115, 6,                         // jae +6
        77, 1, 218,                     // add r10, r11
        77, 137, 17,                    // mov [r9], r10
        191, 0, 15, 0, 0,               // mov edi, 0x00000F00 (CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND)
        76, 137, 198,                   // mov rsi, r8 (child_stack)
        49, 210,                        // xor edx, edx
        69, 49, 210,                    // xor r10d, r10d
        69, 49, 192,                    // xor r8d, r8d
        184, 56, 0, 0, 0,               // mov eax, 56 (SYS_clone)
        15, 5,                          // syscall
        72, 133, 192,                   // test rax, rax
        117, 4,                         // jnz .parent_ret (+4)
        76, 137, 205,                   // mov rbp, r9 (child pivots RBP onto stack_top)
        195,                            // ret (child returns 0)
        195                             // ret (parent returns child TID)
    ]
end

fn থ্রেড_তৈরি স্ট্যাক_টপ
    return thread_create(স্ট্যাক_টপ)

fn thread_spawn fn_ptr arg stack_size
    // WHY: High-level VM-shared thread launcher using anonymous mmap stack and native CLONE_VM thread_spawn_vm trampoline.
    _heap_init = list()
    sz = stack_size
    if sz < 65536
        sz = 65536
    end
    st_base = syscall(9, 0, sz, 3, 34, 0 - 1, 0)
    if st_base <= 0
        return 0
    end
    _thr_tid = thread_spawn_vm(fn_ptr, arg, st_base + sz)
    if _thr_tid <= 0
        syscall(11, st_base, sz, 0, 0, 0, 0)
        return 0
    end
    return _thr_tid

// ── ২. সিপিউ সময় ছেড়ে দেওয়া (Yield CPU Timeslice via SYS_sched_yield: syscall 24) ──
// WHY: বিজি-লুপে সিপিউ অপচয় না করে অন্যান্য থ্রেডকে তাত্ক্ষণিক রান করার সুযোগ দেওয়া।
fn thread_yield
    result = syscall(24)
    return result

fn থ্রেড_ছেড়ে_দাও
    return thread_yield()

// ── ৩. থ্রেড প্রস্থান বা সমাপ্তি (Terminate Calling Thread via SYS_exit: syscall 60) ──
// WHY: চাইল্ড থ্রেডের কাজ সমাপ্ত হলে প্যারেন্ট প্রসেসকে অক্ষত রেখে কেবলমাত্র কলিং থ্রেডটি নিষ্ক্রিয় করা।
// সতর্কতা: exit_group (231) পুরো প্রসেস বন্ধ করে দেয়, কিন্তু SYS_exit (60) শুধু বর্তমান থ্রেড সমাপ্ত করে।
fn thread_exit status
    _lipi_thread_exit(status)

fn থ্রেড_প্রস্থান status
    thread_exit(status)

// ── ৪. খাঁটি সিলিকন পরমাণু স্পিনলক আটকানো (Hardware Silicon Atomic Spinlock via lock bts) ──
// WHY: সরাসরি সিলিকন বাস সিরিয়ালাইজেশন ও মেমরি ব্যারিয়ার দিয়ে মাল্টি-কোর রেস কন্ডিশন সম্পূর্ণ নির্মূল করা।
// ০% pthreads নির্ভরতা — সরাসরি ফিজিক্যাল সিপিইউ অ্যাটমিক অপকোড এক্সিকিউট করে।
fn spinlock_lock lock_addr
    atomic_lock(lock_addr)
    return 1

fn স্পিনলক_আটকা লক_ঠিকানা
    return spinlock_lock(লক_ঠিকানা)

fn স্পিনলক_আটক লক_ঠিকানা
    return spinlock_lock(লক_ঠিকানা)

// ── ৫. পরমাণু স্পিনলক অবমুক্তি (Hardware Silicon Atomic Spinlock Release via lock btr) ──
// WHY: ক্রিটিক্যাল সেকশনের কাজ শেষে অ্যাটমিকভাবে বিট ০ ক্লিয়ার করে অন্যান্য থ্রেডকে তাত্ক্ষণিক অ্যাক্সেস প্রদান করা।
fn spinlock_unlock lock_addr
    atomic_unlock(lock_addr)
    return 0

fn স্পিনলক_মুক্ত লক_ঠিকানা
    return spinlock_unlock(লক_ঠিকানা)

// ── ৬. থ্রেড-সেফ চ্যানেল (Thread-Safe Channel Primitives) ──
// WHY: লক-সুরক্ষিত সার্কুলার চ্যানেলের মাধ্যমে একাধিক থ্রেডের মধ্যে নিরাপদ ও সিনক্রোনাস বার্তা আদান-প্রদান।
// মেমরি কাঠামো (Header: 64 Bytes):
//   Offset 0:  spinlock লক (০ = আনলকড, ১ = লকড)
//   Offset 8:  ক্যাপাসিটি (ডিফল্ট ১৬)
//   Offset 16: বর্তমান আইটেম কাউন্ট
//   Offset 24: হেড সূচক (পড়ার ইনডেক্স)
//   Offset 32: টেইল সূচক (লেখার ইনডেক্স)
//   Offset 40: চ্যানেল বন্ধের ফ্ল্যাগ (০ = সক্রিয়, ১ = বন্ধ)
//   Offset 48: বাফার পয়েন্টার (ক্যাপাসিটি * ৮ বাইট)

fn channel_create
    // WHY: চ্যানেলের হেডার ও মেসেজ বাফার মেমরি বরাদ্দ ও প্রাথমিকীকরণ।
    chan = malloc(64)
    cap = 16
    buf = malloc(cap * 8)
    মেমরি_লেখো(chan, 0, 0)       // লক = ০ (আনলকড)
    মেমরি_লেখো(chan, 8, cap)     // ক্যাপাসিটি = ১৬
    মেমরি_লেখো(chan, 16, 0)      // আইটেম কাউন্ট = ০
    মেমরি_লেখো(chan, 24, 0)      // হেড = ০
    মেমরি_লেখো(chan, 32, 0)      // টেইল = ০
    মেমরি_লেখো(chan, 40, 0)      // বন্ধ = ০
    মেমরি_লেখো(chan, 48, buf)    // বাফার অ্যাড্রেস
    return chan

fn চ্যানেল_তৈরি
    return channel_create()

fn channel_send chan val
    // WHY: চ্যানেলে নিরাপদভাবে মান প্রেরণ; চ্যানেল পূর্ণ থাকলে লক ছেড়ে দিয়ে অপেক্ষা।
    cap = মেমরি_পড়ো(chan, 8)
    buf = মেমরি_পড়ো(chan, 48)
    sent = 0
    while sent == 0
        spinlock_lock(chan)
        count = মেমরি_পড়ো(chan, 16)
        if count < cap
            tail = মেমরি_পড়ো(chan, 32)
            মেমরি_লেখো(buf, tail * 8, val)
            next_tail = (tail + 1) % cap
            মেমরি_লেখো(chan, 32, next_tail)
            মেমরি_লেখো(chan, 16, count + 1)
            spinlock_unlock(chan)
            sent = 1
            return 1
        spinlock_unlock(chan)
        thread_yield()
    return 1

fn চ্যানেল_পাঠাও chan val
    return channel_send(chan, val)

fn channel_recv chan
    // WHY: চ্যানেল থেকে নিরাপদভাবে মান গ্রহণ; চ্যানেল খালি থাকলে লক ছেড়ে দিয়ে অপেক্ষা।
    cap = মেমরি_পড়ো(chan, 8)
    buf = মেমরি_পড়ো(chan, 48)
    recvd = 0
    while recvd == 0
        spinlock_lock(chan)
        count = মেমরি_পড়ো(chan, 16)
        if count > 0
            head = মেমরি_পড়ো(chan, 24)
            val = মেমরি_পড়ো(buf, head * 8)
            next_head = (head + 1) % cap
            মেমরি_লেখো(chan, 24, next_head)
            মেমরি_লেখো(chan, 16, count - 1)
            spinlock_unlock(chan)
            recvd = 1
            return val
        closed = মেমরি_পড়ো(chan, 40)
        if closed == 1
            spinlock_unlock(chan)
            return 0
        spinlock_unlock(chan)
        thread_yield()
    return 0

fn চ্যানেল_গ্রহণ chan
    return channel_recv(chan)

fn channel_close chan
    // WHY: চ্যানেল সমাপ্তি ঘোষণা যাতে অপেক্ষারত গ্রাহক থ্রেড বের হয়ে আসতে পারে।
    spinlock_lock(chan)
    মেমরি_লেখো(chan, 40, 1)
    spinlock_unlock(chan)
    return 1

fn চ্যানেল_বন্ধ chan
    return channel_close(chan)

fn channel_destroy chan
    // WHY: চ্যানেলের বাফার ও হেডার মেমরি কার্নেলে সফলভাবে ফিরিয়ে দেওয়া।
    buf = মেমরি_পড়ো(chan, 48)
    cap = মেমরি_পড়ো(chan, 8)
    free(buf, cap * 8)
    free(chan, 64)
    return 0

fn চ্যানেল_ধ্বংস chan
    return channel_destroy(chan)

// ── ৭. শেয়ার্ড-মেমরি থ্রেড ও কার্নেল ফিউটেক্স মিউটেক্স (CLONE_VM + SYS_futex) ──────
fn thread_spawn_shared fn_entry arg
    // WHY: Ensures bump heap is initialized before spawning a CLONE_VM OS thread
    // with an isolated 64KB anonymous stack executing fn_entry(arg).
    _heap_init = list()
    stack_sz = 65536
    stack_base = syscall(9, 0, stack_sz, 3, 34, 0 - 1, 0)
    if stack_base <= 0
        return 0 - 1
    end
    _thr_tid = thread_spawn_vm(fn_entry, arg, stack_base + stack_sz)
    return _thr_tid

fn থ্রেড_শেয়ার্ড_চালু fn_entry arg
    return thread_spawn_shared(fn_entry, arg)

// NOTE: futex_mutex_*, futex_condvar_*, futex_rwlock_*, mpsc_*, and threadpool_*
// are provided via `include "utso/core/sync.lp"` above.

fn thread_wait_counter counter_ptr target
    // WHY: Cooperatively waits until worker threads reach the target completion count.
    while মেমরি_পড়ো(counter_ptr, 0) < target
        thread_yield()
    end
    return target

fn thread_spawn_joinable fn_entry arg stack_size
    // WHY: Spawns an OS thread using CLONE_PARENT_SETTID | CLONE_CHILD_CLEARTID so parent can block
    // on kernel SYS_futex without polling or leaking stack memory. Returns handle [tid_slot, stack_base, stack_sz].
    _heap_init = list()
    sz = stack_size
    if sz < 65536
        sz = 65536
    end
    stack_base = syscall(9, 0, sz, 3, 34, 0 - 1, 0)
    if stack_base <= 0
        return 0
    end
    handle = malloc(24)
    মেমরি_লেখো(handle, 0, 1)
    মেমরি_লেখো(handle, 8, stack_base)
    মেমরি_লেখো(handle, 16, sz)
    _thr_tid = thread_spawn_vm_joinable(fn_entry, arg, stack_base + sz, handle)
    if _thr_tid <= 0
        syscall(11, stack_base, sz, 0, 0, 0, 0)
        free(handle, 24)
        return 0
    end
    return handle

fn thread_join handle
    // WHY: Zero-spin kernel futex join waiting until child thread exits and kernel zeroes *ctid_ptr.
    if handle == 0
        return 0
    end
    cur_tid = মেমরি_পড়ো(handle, 0) & 4294967295
    while cur_tid != 0
        futex_wait(handle, cur_tid)
        cur_tid = মেমরি_পড়ো(handle, 0) & 4294967295
    end
    stack_base = মেমরি_পড়ো(handle, 8)
    sz = মেমরি_পড়ো(handle, 16)
    if stack_base > 0 and sz > 0
        syscall(11, stack_base, sz, 0, 0, 0, 0)
    end
    free(handle, 24)
    return 1

fn থ্রেড_স্পন_জয়েনযোগ্য fn_entry arg stack_size
    return thread_spawn_joinable(fn_entry, arg, stack_size)

fn থ্রেড_যোগদান handle
    return thread_join(handle)

fn থ্রেড_অপেক্ষা handle
    return thread_join(handle)
