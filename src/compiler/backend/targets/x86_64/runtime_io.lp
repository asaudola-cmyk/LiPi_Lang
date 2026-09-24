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
    // WHY: Silicon-direct file reader via SYS_open (2), SYS_lseek (8), __alloc, SYS_read (0), SYS_close (3)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_file_read", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 49, 246, 49, 210, 184, 2, 0, 0, 0, 15, 5, 72, 133, 192, 120, 114, 73, 137, 196, 76, 137, 231, 49, 246, 186, 2, 0, 0, 0, 184, 8, 0, 0, 0, 15, 5, 73, 137, 197, 77, 133, 237, 120, 76, 76, 137, 231, 49, 246, 49, 210, 184, 8, 0, 0, 0, 15, 5, 73, 141, 125, 9])
    x86_synth_emit_call_helper(s, "__alloc")
    x86_synth_emit_bytes(s, [73, 137, 198, 69, 137, 46, 65, 199, 70, 4, 48, 82, 84, 83, 76, 137, 231, 73, 141, 118, 8, 76, 137, 234, 184, 0, 0, 0, 0, 15, 5, 67, 198, 68, 46, 8, 0, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 73, 141, 70, 8, 235, 45, 76, 137, 231, 184, 3, 0, 0, 0, 15, 5, 72, 199, 199, 9, 0, 0, 0])
    x86_synth_emit_call_helper(s, "__alloc")
    x86_synth_emit_bytes(s, [199, 0, 0, 0, 0, 0, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 198, 7, 0, 72, 137, 248, 65, 94, 65, 93, 65, 92, 93, 195])
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
    // WHY: User memory allocator with O(1) segregated slab freelist recycling.
    // Inspects slab buckets; pops recycled slots or falls back to bump allocator with size header.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_user_alloc", off)
    x86_synth_register_helper_fn(s, "alloc", off)
    x86_synth_register_helper_fn(s, "sys_alloc", off)
    x86_synth_register_helper_fn(s, "বরাদ্দ", off)
    // Chunk 1: Size classification and bucket lookup
    x86_synth_emit_bytes(s, [83, 65, 84, 65, 85, 73, 137, 252, 185, 0, 0, 0, 0, 186, 16, 0, 0, 0, 73, 131, 252, 16, 15, 142, 135, 0, 0, 0, 185, 8, 0, 0, 0, 186, 32, 0, 0, 0, 73, 131, 252, 32, 126, 119, 185, 16, 0, 0, 0, 186, 64, 0, 0, 0, 73, 131, 252, 64, 126, 103, 185, 24, 0, 0, 0, 186, 128, 0, 0, 0, 73, 129, 252, 128, 0, 0, 0, 126, 84, 185, 32, 0, 0, 0, 186, 0, 1, 0, 0, 73, 129, 252, 0, 1, 0, 0, 126, 65, 185, 40, 0, 0, 0, 186, 0, 2, 0, 0, 73, 129, 252, 0, 2, 0, 0, 126, 46, 185, 48, 0, 0, 0, 186, 0, 4, 0, 0, 73, 129, 252, 0, 4, 0, 0, 126, 27, 185, 56, 0, 0, 0, 186, 0, 8, 0, 0, 73, 129, 252, 0, 8, 0, 0, 126, 8, 185, 255, 255, 255, 255, 76, 137, 226, 131, 249, 0, 124, 43, 65, 137, 205, 82])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    // Chunk 2: Freelist pop or fallback setup
    x86_synth_emit_bytes(s, [90, 72, 137, 199, 76, 1, 239, 72, 139, 7, 72, 133, 192, 116, 16, 72, 139, 48, 72, 137, 55, 76, 137, 96, 248, 65, 93, 65, 92, 91, 195, 73, 137, 212, 73, 141, 124, 36, 16])
    x86_synth_emit_call_helper(s, "__alloc")
    // Chunk 3: Store size header at [rax] and return user ptr at rax + 8
    x86_synth_emit_bytes(s, [76, 137, 32, 72, 131, 192, 8, 65, 93, 65, 92, 91, 195])
    return off

fn x86_synth_emit__lipi_user_free s
    // WHY: User memory deallocator. Reclaims user slot into segregated slab freelist via LIFO push.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_user_free", off)
    x86_synth_register_helper_fn(s, "free", off)
    x86_synth_register_helper_fn(s, "sys_free", off)
    x86_synth_register_helper_fn(s, "মুক্ত", off)
    // Free Chunk 1: Read size header at [rdi - 8] and map to bucket
    x86_synth_emit_bytes(s, [83, 65, 84, 73, 137, 252, 77, 133, 228, 15, 132, 131, 0, 0, 0, 73, 139, 116, 36, 248, 185, 0, 0, 0, 0, 72, 131, 254, 16, 126, 94, 185, 8, 0, 0, 0, 72, 131, 254, 32, 126, 83, 185, 16, 0, 0, 0, 72, 131, 254, 64, 126, 72, 185, 24, 0, 0, 0, 72, 129, 254, 128, 0, 0, 0, 126, 58, 185, 32, 0, 0, 0, 72, 129, 254, 0, 1, 0, 0, 126, 44, 185, 40, 0, 0, 0, 72, 129, 254, 0, 2, 0, 0, 126, 30, 185, 48, 0, 0, 0, 72, 129, 254, 0, 4, 0, 0, 126, 16, 185, 56, 0, 0, 0, 72, 129, 254, 0, 8, 0, 0, 126, 2, 235, 21, 81])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    // Free Chunk 2: LIFO push ptr into bucket head
    x86_synth_emit_bytes(s, [89, 72, 141, 28, 8, 72, 139, 19, 73, 137, 20, 36, 76, 137, 35, 49, 192, 65, 92, 91, 195])
    return off
