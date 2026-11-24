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
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")

    // Chunk 2: Read loop until all bytes read, null-terminate, update header len, close fd
    x86_synth_emit_bytes(s, [73, 137, 198, 69, 137, 46, 65, 199, 70, 4, 48, 82, 84, 83, 77, 49, 255, 77, 57, 239, 115, 31, 76, 137, 231, 75, 141, 116, 62, 8, 76, 137, 234, 76, 41, 250, 184, 0, 0, 0, 0, 15, 5, 72, 133, 192, 126, 5, 73, 1, 199, 235, 220, 67, 198, 68, 62, 8, 0, 69, 137, 62, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 73, 141, 70, 8, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 191, 9, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")

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
    // call _lipi_user_alloc (allocates rbx bytes for byte buffer)
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
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

// _lipi_user_alloc, _lipi_thread_spawn_joinable, _lipi_thread_spawn_vm, and _lipi_futex_wait
// are defined in runtime_mt_gc.lp with full multithreaded STW safepoint and thread-stack registration.

fn x86_synth_emit__lipi_user_free s
    // WHY: Sovereign bounds-guarded, Magic-XOR validated & double-free-shielded deallocator.
    // Small blocks (<=4KB) recycle in O(1) LIFO slabs; large blocks (>4KB) push to large freelist
    // and return interior 4KB physical pages to Linux immediately via SYS_madvise(MADV_DONTNEED).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_user_free", off)
    x86_synth_register_helper_fn(s, "free", off)
    x86_synth_register_helper_fn(s, "sys_free", off)
    x86_synth_register_helper_fn(s, "mem_free", off)
    x86_synth_register_helper_fn(s, "মুক্ত", off)
    x86_synth_register_helper_fn(s, "মেমরি_মুক্তি", off)
    // Chunk 1: Guard ptr > 4096 and 8-byte alignment, query _lipi_heap_base
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 252, 73, 129, 252, 0, 16, 0, 0, 15, 134, 105, 1, 0, 0, 73, 247, 196, 7, 0, 0, 0, 15, 133, 92, 1, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_heap_base")
    // Chunk 2: Require ptr >= _heap_base + 24, query _lipi_heap_ptr
    x86_synth_emit_bytes(s, [72, 133, 192, 15, 132, 78, 1, 0, 0, 72, 131, 192, 24, 73, 57, 196, 15, 130, 65, 1, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_heap_ptr")
    // Chunk 3: Require ptr < _heap_ptr, validate Magic-XOR [ptr-24], read & zero [ptr-8]
    x86_synth_emit_bytes(s, [73, 57, 196, 15, 131, 51, 1, 0, 0, 72, 184, 165, 90, 90, 165, 49, 67, 71, 76, 76, 49, 224, 73, 57, 68, 36, 232, 15, 133, 27, 1, 0, 0, 77, 139, 108, 36, 248, 73, 131, 253, 0, 15, 142, 12, 1, 0, 0, 73, 199, 68, 36, 248, 0, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    // Chunk 4: Push to 9 slab buckets OR large freelist + SYS_madvise(MADV_DONTNEED) >= 8KB
    x86_synth_emit_bytes(s, [73, 137, 199, 73, 129, 253, 0, 16, 0, 0, 15, 143, 142, 0, 0, 0, 49, 219, 73, 131, 253, 16, 126, 97, 187, 8, 0, 0, 0, 73, 131, 253, 32, 126, 86, 187, 16, 0, 0, 0, 73, 131, 253, 64, 126, 75, 187, 24, 0, 0, 0, 73, 129, 253, 128, 0, 0, 0, 126, 61, 187, 32, 0, 0, 0, 73, 129, 253, 0, 1, 0, 0, 126, 47, 187, 40, 0, 0, 0, 73, 129, 253, 0, 2, 0, 0, 126, 33, 187, 48, 0, 0, 0, 73, 129, 253, 0, 4, 0, 0, 126, 19, 187, 56, 0, 0, 0, 73, 129, 253, 0, 8, 0, 0, 126, 5, 187, 64, 0, 0, 0, 73, 141, 12, 31, 240, 73, 15, 186, 111, 96, 0, 114, 247, 72, 139, 17, 76, 57, 226, 116, 7, 73, 137, 20, 36, 76, 137, 33, 240, 73, 15, 186, 119, 96, 0, 235, 96, 73, 129, 253, 0, 32, 0, 0, 114, 43, 73, 141, 188, 36, 15, 16, 0, 0, 72, 129, 231, 0, 240, 255, 255, 75, 141, 52, 44, 72, 129, 230, 0, 240, 255, 255, 72, 41, 254, 118, 12, 186, 4, 0, 0, 0, 184, 28, 0, 0, 0, 15, 5, 77, 137, 108, 36, 8, 240, 73, 15, 186, 111, 96, 0, 114, 247, 73, 139, 151, 160, 1, 0, 0, 76, 57, 226, 116, 11, 73, 137, 20, 36, 77, 137, 167, 160, 1, 0, 0, 240, 73, 15, 186, 119, 96, 0, 49, 192, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
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
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
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

// ── Native O(N) ERMS ByteBuffer & Binary-Safe ByteSlice Intrinsics ────────────
// WHY: Eliminates O(N^2) string concat loops across TCP, HTTP/SSE, JSON, FS,
// and process capture while preserving embedded NUL (0x00) binary payloads safely.
// Layout (24B GC-tracked header): [0]=len, [8]=cap, [16]=data_ptr (GC-tracked).

fn x86_synth_emit__lipi_buf_new s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_new", off)
    x86_synth_register_helper_fn(s, "buf_new", off)
    x86_synth_register_helper_fn(s, "byte_buf_new", off)
    x86_synth_register_helper_fn(s, "বাফার_তৈরি", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 72, 137, 251, 72, 131, 251, 64, 125, 5, 187, 64, 0, 0, 0, 191, 24, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [73, 137, 196, 72, 137, 223])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [73, 199, 4, 36, 0, 0, 0, 0, 73, 137, 92, 36, 8, 73, 137, 68, 36, 16, 76, 137, 224, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_buf_write_mem s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_write_mem", off)
    x86_synth_register_helper_fn(s, "buf_write_mem", off)
    x86_synth_register_helper_fn(s, "buf_append_mem", off)
    x86_synth_register_helper_fn(s, "বাফার_লেখো_মেম", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 252, 73, 137, 245, 73, 137, 214, 77, 133, 228, 15, 132, 158, 0, 0, 0, 73, 139, 4, 36, 77, 133, 237, 15, 132, 130, 0, 0, 0, 73, 131, 254, 0, 126, 124, 77, 139, 124, 36, 8, 74, 141, 28, 48, 76, 57, 251, 126, 85, 73, 209, 231, 73, 131, 255, 64, 125, 6, 65, 191, 64, 0, 0, 0, 73, 57, 223, 125, 3, 73, 137, 223, 76, 137, 255])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [73, 137, 192, 77, 139, 76, 36, 16, 73, 139, 12, 36, 72, 133, 201, 116, 14, 77, 133, 201, 116, 9, 76, 137, 199, 76, 137, 206, 252, 243, 164, 77, 137, 68, 36, 16, 77, 137, 124, 36, 8, 77, 133, 201, 116, 8, 76, 137, 207])
    x86_synth_emit_call_helper(s, "_lipi_user_free")
    x86_synth_emit_bytes(s, [73, 139, 124, 36, 16, 73, 3, 60, 36, 76, 137, 238, 76, 137, 241, 252, 243, 164, 73, 137, 28, 36, 72, 137, 216, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195, 49, 192, 235, 237])
    return off

fn x86_synth_emit__lipi_buf_write_byte s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_write_byte", off)
    x86_synth_register_helper_fn(s, "buf_write_byte", off)
    x86_synth_register_helper_fn(s, "buf_append_byte", off)
    x86_synth_register_helper_fn(s, "buf_push", off)
    x86_synth_register_helper_fn(s, "বাফার_বাইট", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 27, 72, 139, 7, 72, 139, 79, 8, 72, 57, 200, 115, 18, 72, 139, 87, 16, 64, 136, 52, 2, 72, 255, 192, 72, 137, 7, 195, 49, 192, 195, 85, 72, 137, 229, 72, 131, 236, 16, 64, 136, 117, 248, 72, 141, 117, 248, 186, 1, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_mem")
    x86_synth_emit_bytes(s, [72, 131, 196, 16, 93, 195])
    return off

fn x86_synth_emit__lipi_buf_write_str s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_write_str", off)
    x86_synth_register_helper_fn(s, "buf_write_str", off)
    x86_synth_register_helper_fn(s, "buf_append", off)
    x86_synth_register_helper_fn(s, "buf_append_str", off)
    x86_synth_register_helper_fn(s, "বাফার_স্ট্রিং", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 73, 137, 252, 73, 137, 245, 77, 133, 228, 116, 57, 77, 133, 237, 116, 46, 76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 116, 6, 65, 139, 85, 248, 235, 15, 49, 210, 65, 128, 124, 21, 0, 0, 116, 5, 72, 255, 194, 235, 243, 76, 137, 231, 76, 137, 238])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_mem")
    x86_synth_emit_bytes(s, [235, 8, 73, 139, 4, 36, 235, 2, 49, 192, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_bytes_to_str s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_bytes_to_str", off)
    x86_synth_register_helper_fn(s, "bytes_to_str", off)
    x86_synth_register_helper_fn(s, "mem_to_str", off)
    x86_synth_register_helper_fn(s, "বাইট_থেকে_স্ট্রিং", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 73, 137, 252, 72, 137, 243, 72, 131, 251, 0, 125, 2, 49, 219, 72, 141, 123, 9])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [137, 24, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 72, 133, 219, 116, 14, 77, 133, 228, 116, 9, 76, 137, 230, 72, 137, 217, 252, 243, 164, 198, 68, 24, 8, 0, 72, 131, 192, 8, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_buf_to_str s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_to_str", off)
    x86_synth_register_helper_fn(s, "buf_to_str", off)
    x86_synth_register_helper_fn(s, "বাফার_স্ট্রিংয়ে", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 133, 255, 116, 14, 72, 139, 55, 72, 139, 127, 16])
    x86_synth_emit_call_helper(s, "_lipi_bytes_to_str")
    x86_synth_emit_bytes(s, [93, 195, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_bytes_to_str")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_buf_len s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_len", off)
    x86_synth_register_helper_fn(s, "buf_len", off)
    x86_synth_register_helper_fn(s, "বাফার_দৈর্ঘ্য", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 4, 72, 139, 7, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_buf_ptr s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_ptr", off)
    x86_synth_register_helper_fn(s, "buf_ptr", off)
    x86_synth_register_helper_fn(s, "বাফার_পয়েন্টার", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 5, 72, 139, 71, 16, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_buf_clear s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_clear", off)
    x86_synth_register_helper_fn(s, "buf_clear", off)
    x86_synth_register_helper_fn(s, "বাফার_মুছো", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 7, 72, 199, 7, 0, 0, 0, 0, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_buf_get_byte s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_get_byte", off)
    x86_synth_register_helper_fn(s, "buf_get_byte", off)
    x86_synth_register_helper_fn(s, "বাইট_পড়ো", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 20, 72, 131, 254, 0, 124, 14, 72, 59, 55, 115, 9, 72, 139, 87, 16, 15, 182, 4, 50, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_buf_free s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_free", off)
    x86_synth_register_helper_fn(s, "buf_free", off)
    x86_synth_register_helper_fn(s, "বাফার_মুক্তি", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 72, 131, 236, 8, 73, 137, 252, 77, 133, 228, 116, 49, 73, 139, 124, 36, 16, 73, 199, 4, 36, 0, 0, 0, 0, 73, 199, 68, 36, 8, 0, 0, 0, 0, 73, 199, 68, 36, 16, 0, 0, 0, 0, 72, 133, 255, 116, 5])
    x86_synth_emit_call_helper(s, "_lipi_user_free")
    x86_synth_emit_bytes(s, [76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_user_free")
    x86_synth_emit_bytes(s, [49, 192, 72, 131, 196, 8, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_buf_slice s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_buf_slice", off)
    x86_synth_register_helper_fn(s, "buf_slice", off)
    x86_synth_register_helper_fn(s, "bytes_slice", off)
    x86_synth_register_helper_fn(s, "বাইট_স্লাইস", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 73, 137, 252, 73, 137, 245, 73, 137, 214, 77, 133, 228, 116, 30, 73, 139, 4, 36, 73, 131, 253, 0, 125, 3, 69, 49, 237, 73, 57, 198, 126, 3, 73, 137, 198, 77, 41, 238, 73, 131, 254, 0, 127, 12, 191, 64, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_new")
    x86_synth_emit_bytes(s, [235, 33, 76, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_buf_new")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 223, 73, 139, 116, 36, 16, 76, 1, 238, 76, 137, 242])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_mem")
    x86_synth_emit_bytes(s, [72, 137, 216, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off
