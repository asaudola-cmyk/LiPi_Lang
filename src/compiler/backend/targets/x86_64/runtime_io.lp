// ==============================================================================
// 👑 LIPI FIRST 1.0.0 NATIVE FILE I/O RUNTIME SILICON HELPERS (runtime_io.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Linux Syscall Binary Generation
// ==============================================================================

fn x86_synth_emit__lipi_file_exists s
    // WHY: Silicon-direct file existence probe via SYS_access (syscall 21)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_file_exists", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 49, 246, 184, 21, 0, 0, 0, 15, 5, 133, 192, 15, 148, 192, 15, 182, 192, 93, 195])
    return off

fn x86_synth_emit__lipi_file_write s
    // WHY: Silicon-direct string file writer via SYS_open (2), SYS_write (1), SYS_close (3)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_file_write", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 73, 137, 252, 73, 137, 245, 77, 49, 246, 77, 133, 237, 116, 30, 65, 139, 69, 252, 61, 48, 82, 84, 83, 117, 6, 69, 139, 117, 248, 235, 13, 67, 128, 124, 53, 0, 0, 116, 5, 73, 255, 198, 235, 243, 76, 137, 231, 190, 65, 2, 0, 0, 186, 237, 1, 0, 0, 184, 2, 0, 0, 0, 15, 5, 72, 133, 192, 120, 39, 73, 137, 196, 77, 133, 246, 116, 16, 76, 137, 231, 76, 137, 238, 76, 137, 242, 184, 1, 0, 0, 0, 15, 5, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 76, 137, 240, 235, 2, 49, 192, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_file_read s
    // WHY: Silicon-direct file reader via SYS_open (2), SYS_lseek (8), __alloc, robust multi-chunk SYS_read (0) loop, SYS_close (3).
    // Maintains 16-byte stack alignment across calls and handles arbitrary file sizes with zero uninitialized memory.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_file_read", off)
    x86_synth_register_helper_fn(s, "file_read", off)
    x86_synth_register_helper_fn(s, "read_file", off)
    x86_synth_register_helper_fn(s, "ফাইল_পড়ো", off)
    x86_synth_register_helper_fn(s, "ফাইল_পড়ো", off)

    // Chunk 1: Open, get file size via lseek, rewind, allocate file_size + 9 bytes
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 49, 246, 49, 210, 184, 2, 0, 0, 0, 15, 5, 72, 133, 192, 15, 136, 147, 0, 0, 0, 73, 137, 196, 76, 137, 231, 49, 246, 186, 2, 0, 0, 0, 184, 8, 0, 0, 0, 15, 5, 73, 137, 197, 77, 133, 237, 120, 109, 76, 137, 231, 49, 246, 49, 210, 184, 8, 0, 0, 0, 15, 5, 73, 141, 125, 9])
    x86_synth_emit_call_helper(s, "__alloc")

    // Chunk 2: Read loop until all bytes read, null-terminate, update header len, close fd
    x86_synth_emit_bytes(s, [73, 137, 198, 69, 137, 46, 65, 199, 70, 4, 48, 82, 84, 83, 77, 49, 255, 77, 57, 239, 115, 31, 76, 137, 231, 75, 141, 116, 62, 8, 76, 137, 234, 76, 41, 250, 184, 0, 0, 0, 0, 15, 5, 72, 133, 192, 126, 5, 73, 1, 199, 235, 220, 67, 198, 68, 62, 8, 0, 69, 137, 62, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 73, 141, 70, 8, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 191, 9, 0, 0, 0])
    x86_synth_emit_call_helper(s, "__alloc")

    // Chunk 3: Fallback empty string if open/read fails
    x86_synth_emit_bytes(s, [199, 0, 0, 0, 0, 0, 199, 64, 4, 48, 82, 84, 83, 198, 64, 8, 0, 72, 141, 64, 8, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_file_write_bytes s
    // WHY: Writes a list of raw integer bytes to an executable output file (0755 permissions), returning 0 on success
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_file_write_bytes", off)
    // Prologue: push rbp; mov rbp, rsp; push rbx, r12, r13, r14, r15
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87])
    // mov r12, rdi (path); mov r13, rsi (byte list)
    x86_synth_emit_bytes(s, [73, 137, 252, 73, 137, 245])
    // SYS_open(path, 577, 493)
    x86_synth_emit_bytes(s, [76, 137, 231, 72, 199, 198, 65, 2, 0, 0, 72, 199, 194, 237, 1, 0, 0, 72, 199, 192, 2, 0, 0, 0, 15, 5])
    // Guard negative fd from SYS_open and return -1 cleanly
    x86_synth_emit_bytes(s, [72, 133, 192, 121, 18, 72, 199, 192, 255, 255, 255, 255, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    // mov r14, rax (fd); mov rbx, [r13] (count); mov rdi, rbx
    x86_synth_emit_bytes(s, [73, 137, 198, 73, 139, 93, 0, 72, 137, 223])
    // call __alloc (allocates rbx bytes for byte buffer)
    x86_synth_emit_call_helper(s, "__alloc")
    // mov r15, rax (byte buffer); mov rdx, [r13 + 16] (list buffer); xor rcx, rcx
    x86_synth_emit_bytes(s, [73, 137, 199, 73, 139, 85, 16, 72, 49, 201])
    // .loop: mov rax, [rdx + rcx*8]; mov [r15 + rcx], al; inc rcx; cmp rcx, rbx; jb .loop
    x86_synth_emit_bytes(s, [72, 139, 4, 202, 65, 136, 4, 15, 72, 255, 193, 72, 57, 217, 114, 240])
    // SYS_write(fd, r15, rbx)
    x86_synth_emit_bytes(s, [76, 137, 247, 76, 137, 254, 72, 137, 218, 72, 199, 192, 1, 0, 0, 0, 15, 5])
    // SYS_close(fd)
    x86_synth_emit_bytes(s, [76, 137, 247, 72, 199, 192, 3, 0, 0, 0, 15, 5])
    // xor eax, eax (return 0); epilogue & ret
    x86_synth_emit_bytes(s, [49, 192, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_ensure_str s
    // WHY: Ensures argument in %rdi is a valid string; returns pointer unmodified if string,
    // or converts integer to newly allocated decimal string if not a string pointer.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_ensure_str", off)
    x86_synth_register_helper_fn(s, "to_str", off)
    // push rbp; mov rbp, rsp; push rbx; push r12; mov r12, rdi
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 73, 137, 252])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    // test rax, rax; jnz .already_str (+13 bytes)
    x86_synth_emit_bytes(s, [72, 133, 192, 117, 13])
    // mov rdi, r12; call _lipi_int_to_str
    x86_synth_emit_bytes(s, [76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_int_to_str")
    // pop r12; pop rbx; leave; ret
    x86_synth_emit_bytes(s, [65, 92, 91, 201, 195])
    // .already_str: mov rax, r12; pop r12; pop rbx; leave; ret
    x86_synth_emit_bytes(s, [76, 137, 224, 65, 92, 91, 201, 195])
    return off

fn x86_synth_emit__lipi_malloc s
    // WHY: Kernel-direct mmap memory allocator for standalone heap allocations (size in %rdi).
    // Prevents colliding with or unmapping the compiler's internal 1GB bump arena.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_malloc", off)
    x86_synth_register_helper_fn(s, "lipi_alloc", off)
    x86_synth_register_helper_fn(s, "lipi_gc_alloc", off)
    // mov rsi, rdi; xor edi, edi; mov edx, 3; mov r10d, 34
    // mov r8, -1; xor r9d, r9d; mov eax, 9; syscall; ret
    x86_synth_emit_bytes(s, [72, 137, 254, 49, 255, 186, 3, 0, 0, 0, 65, 186, 34, 0, 0, 0, 73, 199, 192, 255, 255, 255, 255, 69, 49, 201, 184, 9, 0, 0, 0, 15, 5, 195])
    return off


fn x86_synth_emit__lipi_pass_thru s
    // WHY: Identity function returning %rdi in %rax (mov rax, rdi; ret).
    // Provides zero-overhead pointer passthrough for str_ptr, lipi_str_ptr, lipi_str_new.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_pass_thru", off)
    x86_synth_register_helper_fn(s, "str_ptr", off)
    x86_synth_register_helper_fn(s, "lipi_str_ptr", off)
    x86_synth_register_helper_fn(s, "lipi_str_new", off)
    // mov rax, rdi; ret
    x86_synth_emit_bytes(s, [72, 137, 248, 195])
    return off

fn x86_synth_emit__lipi_atomic_cas s
    // WHY: Hardware silicon atomic compare-and-swap (lock cmpxchg)
    // %rdi = memory ptr, %rsi = expected val, %rdx = new val
    // Returns 1 if swapped, 0 if mismatch
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_atomic_cas", off)
    x86_synth_register_helper_fn(s, "atomic_cas", off)
    x86_synth_register_helper_fn(s, "atomic_compare_swap", off)
    x86_synth_register_helper_fn(s, "অ্যাটমিক_ক্যাস", off)
    // mov rax, rsi; lock cmpxchg [rdi], rdx; sete al; movzx rax, al; ret
    x86_synth_emit_bytes(s, [72, 137, 240, 240, 72, 15, 177, 23, 15, 148, 192, 72, 15, 182, 192, 195])
    return off

fn x86_synth_emit__lipi_atomic_add s
    // WHY: Hardware silicon atomic fetch-and-add (lock xadd)
    // %rdi = memory ptr, %rsi = delta
    // Returns previous value in %rax, memory updated atomically
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_atomic_add", off)
    x86_synth_register_helper_fn(s, "atomic_add", off)
    x86_synth_register_helper_fn(s, "অ্যাটমিক_যোগ", off)
    // mov rax, rsi; lock xadd [rdi], rax; ret
    x86_synth_emit_bytes(s, [72, 137, 240, 240, 72, 15, 193, 7, 195])
    return off

fn x86_synth_emit__lipi_user_alloc s
    // WHY: Thread-safe O(1) segregated slab freelist allocator.
    // Acquires _slab_spinlock [slab_base + 96] (rw + 128) around freelist pop and always
    // releases before falling through to __alloc on empty buckets.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_user_alloc", off)
    x86_synth_register_helper_fn(s, "alloc", off)
    x86_synth_register_helper_fn(s, "sys_alloc", off)
    x86_synth_register_helper_fn(s, "বরাদ্দ", off)
    // Chunk 1: Size classification and bucket lookup across 9 geometric size classes (guarding size <= 16..4096)
    x86_synth_emit_bytes(s, [83, 65, 84, 65, 85, 73, 137, 252, 185, 0, 0, 0, 0, 186, 16, 0, 0, 0, 73, 131, 252, 16, 15, 142, 158, 0, 0, 0, 185, 8, 0, 0, 0, 186, 32, 0, 0, 0, 73, 131, 252, 32, 15, 142, 138, 0, 0, 0, 185, 16, 0, 0, 0, 186, 64, 0, 0, 0, 73, 131, 252, 64, 126, 122, 185, 24, 0, 0, 0, 186, 128, 0, 0, 0, 73, 129, 252, 128, 0, 0, 0, 126, 103, 185, 32, 0, 0, 0, 186, 0, 1, 0, 0, 73, 129, 252, 0, 1, 0, 0, 126, 84, 185, 40, 0, 0, 0, 186, 0, 2, 0, 0, 73, 129, 252, 0, 2, 0, 0, 126, 65, 185, 48, 0, 0, 0, 186, 0, 4, 0, 0, 73, 129, 252, 0, 4, 0, 0, 126, 46, 185, 56, 0, 0, 0, 186, 0, 8, 0, 0, 73, 129, 252, 0, 8, 0, 0, 126, 27, 185, 64, 0, 0, 0, 186, 0, 16, 0, 0, 73, 129, 252, 0, 16, 0, 0, 126, 8, 185, 255, 255, 255, 255, 76, 137, 226, 131, 249, 0, 124, 69, 65, 137, 205, 82])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    // Chunk 2: Spinlock-protected freelist pop or unlocked fallback to __alloc(32+size) with GC metadata header
    x86_synth_emit_bytes(s, [90, 73, 137, 192, 72, 137, 199, 76, 1, 239, 240, 73, 15, 186, 104, 96, 0, 114, 247, 72, 139, 7, 72, 133, 192, 116, 23, 72, 139, 48, 72, 137, 55, 240, 73, 15, 186, 112, 96, 0, 76, 137, 96, 248, 65, 93, 65, 92, 91, 195, 240, 73, 15, 186, 112, 96, 0, 73, 137, 212, 73, 141, 124, 36, 31, 72, 131, 231, 248, 65, 84])
    x86_synth_emit_call_helper(s, "__alloc")
    // Chunk 3: Store size header, query _lipi_slab_buckets_ptr for GC list insertion
    x86_synth_emit_bytes(s, [65, 92, 76, 137, 96, 8, 72, 141, 88, 16, 83])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    // Chunk 4: Link block into _gc_alloc_head under lock and return rax + 16
    x86_synth_emit_bytes(s, [91, 240, 72, 15, 186, 104, 96, 0, 114, 247, 72, 139, 72, 104, 72, 137, 75, 240, 72, 137, 88, 104, 240, 72, 15, 186, 112, 96, 0, 72, 137, 216, 65, 93, 65, 92, 91, 195])
    return off

fn x86_synth_emit__lipi_user_free s
    // WHY: Sovereign bounds-guarded & double-free-shielded deallocator.
    // 1. Safely ignores NULL/small pointers (ptr <= 4096).
    // 2. Calls _lipi_heap_base and _lipi_heap_ptr to prove (_heap_base < ptr < _heap_ptr)
    //    BEFORE dereferencing [ptr - 8], eliminating SEGV_MAPERR if a non-slab pointer is passed.
    // 3. Prevents immediate freelist head double-free cycles (cmp rdx, r12; je .unlock) under _slab_spinlock.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_user_free", off)
    x86_synth_register_helper_fn(s, "free", off)
    x86_synth_register_helper_fn(s, "sys_free", off)
    x86_synth_register_helper_fn(s, "mem_free", off)
    x86_synth_register_helper_fn(s, "মুক্ত", off)
    x86_synth_register_helper_fn(s, "মেমরি_মুক্তি", off)
    // Chunk 1: Save callee-saved rbx/r12/r13, check ptr > 4096, query _lipi_heap_base
    x86_synth_emit_bytes(s, [83, 65, 84, 65, 85, 73, 137, 252, 73, 129, 252, 0, 16, 0, 0, 15, 134, 228, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_heap_base")
    // Chunk 2: Require _heap_base != 0 and ptr > _heap_base, query _lipi_heap_ptr
    x86_synth_emit_bytes(s, [72, 133, 192, 15, 132, 214, 0, 0, 0, 73, 57, 196, 15, 134, 205, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_heap_ptr")
    // Chunk 3: Require ptr < _heap_ptr, zero [ptr-8] after use, classify size <= 4096 into 9 slab buckets
    x86_synth_emit_bytes(s, [73, 57, 196, 15, 131, 191, 0, 0, 0, 73, 139, 116, 36, 248, 72, 133, 246, 15, 142, 177, 0, 0, 0, 187, 0, 0, 0, 0, 72, 131, 254, 16, 126, 117, 187, 8, 0, 0, 0, 72, 131, 254, 32, 126, 106, 187, 16, 0, 0, 0, 72, 131, 254, 64, 126, 95, 187, 24, 0, 0, 0, 72, 129, 254, 128, 0, 0, 0, 126, 81, 187, 32, 0, 0, 0, 72, 129, 254, 0, 1, 0, 0, 126, 67, 187, 40, 0, 0, 0, 72, 129, 254, 0, 2, 0, 0, 126, 53, 187, 48, 0, 0, 0, 72, 129, 254, 0, 4, 0, 0, 126, 39, 187, 56, 0, 0, 0, 72, 129, 254, 0, 8, 0, 0, 126, 25, 187, 64, 0, 0, 0, 72, 129, 254, 0, 16, 0, 0, 126, 11, 73, 199, 68, 36, 248, 0, 0, 0, 0, 235, 49, 73, 199, 68, 36, 248, 0, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    // Chunk 4: Acquire _slab_spinlock, guard against double-free head cycle, push & unlock
    x86_synth_emit_bytes(s, [72, 141, 12, 24, 240, 72, 15, 186, 104, 96, 0, 114, 247, 72, 139, 17, 76, 57, 226, 116, 7, 73, 137, 20, 36, 76, 137, 33, 240, 72, 15, 186, 112, 96, 0, 49, 192, 65, 93, 65, 92, 91, 195])
    return off

fn x86_synth_emit__lipi_thread_spawn_joinable s
    // WHY: Joinable OS thread via Linux SYS_clone (56) with CLONE_VM|CLONE_FS|CLONE_FILES|
    // CLONE_SIGHAND|CLONE_THREAD|CLONE_PARENT_SETTID|CLONE_CHILD_CLEARTID (0x00310F00).
    // Inputs: %rdi=fn_ptr, %rsi=arg, %rdx=stack_top, %rcx=ctid_ptr.
    // On child exit, kernel atomically zeroes *ctid_ptr and issues FUTEX_WAKE.
    off = s.synth_code.len()
    s.synth_thread_spawn_j_off = off
    x86_synth_register_helper_fn(s, "_lipi_thread_spawn_joinable", off)
    x86_synth_register_helper_fn(s, "thread_spawn_vm_joinable", off)
    x86_synth_emit_bytes(s, [
        72, 131, 226, 240, 72, 131, 234, 16, 72, 137, 50, 72, 137, 122, 8,
        72, 137, 214, 72, 137, 202, 73, 137, 202, 69, 49, 192,
        191, 0, 15, 49, 0, 184, 56, 0, 0, 0, 15, 5,
        72, 133, 192, 117, 16, 49, 237, 95, 88, 255, 208,
        72, 137, 199, 184, 60, 0, 0, 0, 15, 5, 195
    ])
    return off

fn x86_synth_emit__lipi_thread_spawn_vm s
    // WHY: True shared-memory OS thread spawner via Linux SYS_clone (56) with
    // CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD (0x10F00 = 69376).
    // Inputs: %rdi = fn_ptr, %rsi = arg, %rdx = stack_top. Parent returns child TID in %rax;
    // child executes fn_ptr(arg) on isolated aligned stack and exits via SYS_exit (60).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_thread_spawn_vm", off)
    x86_synth_register_helper_fn(s, "thread_spawn_vm", off)
    x86_synth_register_helper_fn(s, "থ্রেড_চালু_ভিএম", off)
    x86_synth_emit_bytes(s, [
        72, 131, 226, 240,
        72, 131, 234, 16,
        72, 137, 50,
        72, 137, 122, 8,
        72, 137, 214,
        191, 0, 15, 1, 0,
        49, 210,
        69, 49, 210,
        69, 49, 192,
        184, 56, 0, 0, 0,
        15, 5,
        72, 133, 192,
        117, 16,
        49, 237,
        95,
        88,
        255, 208,
        72, 137, 199,
        184, 60, 0, 0, 0,
        15, 5,
        195
    ])
    return off

fn x86_synth_emit__lipi_futex_wait s
    // WHY: Linux kernel zero-spin futex wait via SYS_futex(addr, FUTEX_WAIT=0, expected, NULL, NULL, 0)
    // Shared FUTEX_WAIT (0) matches Linux CLONE_CHILD_CLEARTID kernel mm_release wakeup semantics reliably.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_futex_wait", off)
    x86_synth_register_helper_fn(s, "futex_wait", off)
    x86_synth_register_helper_fn(s, "ফিউটেক্স_অপেক্ষা", off)
    x86_synth_emit_bytes(s, [
        72, 137, 242,
        190, 0, 0, 0, 0,
        69, 49, 210,
        69, 49, 192,
        69, 49, 201,
        184, 202, 0, 0, 0,
        15, 5,
        195
    ])
    return off

fn x86_synth_emit__lipi_float_to_str s
    // WHY: Formats IEEE-754 binary64 float bits in %rdi into a heap STR0 string (%rax).
    // Handles NaN, +Inf, -Inf, scientific exponent notation for |x| >= 1e18 or 0 < |x| < 1e-6,
    // and fixed-point decimal formatting up to 6 fractional digits with trailing zeros trimmed.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_float_to_str", off)
    x86_synth_register_helper_fn(s, "float_to_str", off)
    c1 = [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 72, 129, 236, 128, 0, 0, 0, 76, 141, 133, 112, 255, 255, 255, 69, 49, 201, 72, 184, 255, 255, 255, 255, 255, 255, 255, 127, 73, 137, 254, 73, 33, 198, 72, 185, 0, 0, 0, 0, 0, 0, 240, 127, 73, 57, 206, 119, 41, 114, 64, 72, 133, 255, 121, 8, 67, 198, 4, 8, 45, 73, 255, 193, 67, 198, 4, 8, 73, 67, 198, 68, 8, 1, 110, 67, 198, 68, 8, 2, 102, 73, 131, 193, 3, 233, 128, 2, 0, 0, 65, 198, 0, 78, 65, 198, 64, 1, 97, 65, 198, 64, 2, 78, 65, 185, 3, 0, 0, 0, 233, 103, 2, 0, 0, 72, 133, 255, 121, 8, 67, 198, 4, 8, 45, 73, 255, 193, 76, 137, 247, 102, 72, 15, 110, 199, 69, 49, 228, 69, 49, 237, 72, 133, 255, 15, 132, 194, 0, 0, 0, 72, 184, 0, 200, 78, 103, 109, 193, 171, 67, 72, 57, 199, 114, 67, 65, 188, 1, 0, 0, 0, 72, 185, 0, 128, 224, 55, 121, 195, 65, 67, 102, 72, 15, 110, 225, 72, 185, 0, 0, 0, 0, 0, 0, 36, 64, 102, 72, 15, 110, 233, 102, 15, 46, 196, 114, 10, 242, 15, 94, 196, 73, 131, 197, 16, 235, 240, 102, 15, 46, 197, 114, 121, 242, 15, 94, 197, 73, 255, 197, 235, 241, 72, 184, 141, 237, 181, 160, 247, 198, 176, 62, 72, 57, 199, 115, 97, 65, 188, 255, 255, 255, 255, 72, 185, 0, 128, 224, 55, 121, 195, 65, 67, 102, 72, 15, 110, 225, 72, 185, 0, 0, 0, 0, 0, 0, 36, 64, 102, 72, 15, 110, 233, 72, 184, 0, 0, 0, 0, 0, 0, 240, 63, 102, 72, 15, 110, 240, 72, 184, 188, 137, 216, 151, 178, 210, 156, 60, 102, 72, 15, 110, 248, 102, 15, 46, 199, 115, 10, 242, 15, 89, 196, 73, 131, 197, 16, 235, 240, 102, 15, 46, 198, 115, 9, 242, 15, 89, 197, 73, 255, 197, 235, 241, 242, 72, 15, 44, 192, 242, 72, 15, 42, 200, 242, 15, 92, 193, 72, 186, 0, 0, 0, 0, 128, 132, 46, 65, 102, 72, 15, 110, 210, 242, 15, 89, 194, 72, 186, 0, 0, 0, 0, 0, 0, 224, 63, 102, 72, 15, 110, 218, 242, 15, 88, 195, 242, 72, 15, 44, 240, 72, 129, 254, 64, 66, 15, 0, 124, 5, 72, 255, 192, 49, 246, 72, 141, 93, 216, 72, 137, 217, 69, 49, 210, 72, 133, 192, 117, 11, 198, 1, 48, 72, 255, 201, 73, 255, 194, 235, 29, 72, 133, 192, 116, 24, 49, 210, 65, 187, 10, 0, 0, 0, 73, 247, 243, 128, 194, 48, 136, 17, 72, 255, 201, 73, 255, 194, 235, 227, 77, 133, 210, 116, 17, 72, 255, 193, 138, 1, 67, 136, 4, 8, 73, 255, 193, 73, 255, 202, 235, 234, 67, 198, 4, 8, 46, 73, 255, 193, 72, 137, 240, 72, 133, 192, 116, 105, 190, 6, 0, 0, 0, 49, 210, 65, 187, 10, 0, 0, 0, 73, 247, 243, 72, 133, 210, 117, 4, 255, 206, 235, 236, 72, 107, 192, 10, 72, 1, 208, 72, 137, 217, 69, 49, 210, 72, 133, 192, 116, 24, 49, 210, 65, 187, 10, 0, 0, 0, 73, 247, 243, 128, 194, 48, 136, 17, 72, 255, 201, 73, 255, 194, 235, 227, 73, 57, 242, 125, 11, 198, 1, 48, 72, 255, 201, 73, 255, 194, 235, 240, 77, 133, 210, 116, 25, 72, 255, 193, 138, 1, 67, 136, 4, 8, 73, 255, 193, 73, 255, 202, 235, 234, 67, 198, 4, 8, 48, 73, 255, 193, 69, 133, 228, 116, 103, 67, 198, 4, 8, 101, 73, 255, 193, 67, 198, 4, 8, 43, 65, 131, 252, 0, 125, 5, 67, 198, 4, 8, 45, 73, 255, 193, 76, 137, 232, 72, 137, 217, 69, 49, 210, 72, 133, 192, 117, 11, 198, 1, 48, 72, 255, 201, 73, 255, 194, 235, 29, 72, 133, 192, 116, 24, 49, 210, 65, 187, 10, 0, 0, 0, 73, 247, 243, 128, 194, 48, 136, 17, 72, 255, 201, 73, 255, 194, 235, 227, 77, 133, 210, 116, 17, 72, 255, 193, 138, 1, 67, 136, 4, 8, 73, 255, 193, 73, 255, 202, 235, 234, 73, 141, 121, 9, 65, 80, 65, 81]
    c2 = [65, 89, 65, 88, 68, 137, 8, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 49, 201, 76, 57, 201, 115, 12, 65, 138, 20, 8, 136, 20, 15, 72, 255, 193, 235, 239, 198, 4, 15, 0, 72, 137, 248, 72, 129, 196, 128, 0, 0, 0, 65, 94, 65, 93, 65, 92, 91, 93, 195]
    x86_synth_emit_bytes(s, c1)
    x86_synth_emit_call_helper(s, "__alloc")
    x86_synth_emit_bytes(s, c2)
    return off

fn x86_synth_emit__lipi_futex_wake s
    // WHY: Linux kernel futex wakeup via SYS_futex(addr, FUTEX_WAKE=1, count, NULL, NULL, 0)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_futex_wake", off)
    x86_synth_register_helper_fn(s, "futex_wake", off)
    x86_synth_register_helper_fn(s, "ফিউটেক্স_জাগাও", off)
    x86_synth_emit_bytes(s, [
        72, 137, 242,
        190, 1, 0, 0, 0,
        69, 49, 210,
        69, 49, 192,
        69, 49, 201,
        184, 202, 0, 0, 0,
        15, 5,
        195
    ])
    return off
