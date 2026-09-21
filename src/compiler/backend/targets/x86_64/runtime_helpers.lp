// ==============================================================================
// 👑 LIPI FIRST 1.0.0 NATIVE RUNTIME SILICON HELPERS (runtime_helpers.lp)
// ⚡ 100% Pure Silicon AMD64 Machine Code | 0% C | 0% Libc | Sovereign Engine
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the decoupled micro-compiler to bare metal by providing bit-exact
//    implementations of high-level language intrinsics (argv, string concat, lists).
// 2. Zero-Runtime Guarantee: Emitted directly into .text alongside user instructions;
//    requires no external libc, CRT, or shared libraries.
// 3. Inter-procedural call relocations are resolved automatically by synthesizer.
// ==============================================================================

fn x86_synth_emit_call_helper s target_name
    // WHY: Emits standard call rel32 (0xE8) and queues relocation for later patching
    x86_synth_emit_byte(s, 232)
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 0)
    call_rel = X86CallReloc()
    call_rel.cr_patch_offset = patch_pos
    call_rel.cr_call_site_end = patch_pos + 4
    call_rel.cr_target_name = target_name
    push(s.synth_call_relocs, call_rel)
    return 0

fn x86_synth_register_helper_fn s name off
    // WHY: Registers helper entry point so callers can resolve relative displacements
    fn_info = X86Function()
    fn_info.fn_name = name
    fn_info.fn_entry_offset = off
    push(s.synth_functions, fn_info)
    return 0

fn x86_synth_emit__lipi_is_str s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_is_str", off)
    s.synth_is_str_off = off
    // WHY: Valid string pointers can only reside in two address regions:
    // 1. Binary Image Read-Only Data (.rodata): [rodata_base_vaddr, rodata_end_vaddr)
    // 2. Linux mmap Heap Arena: [_heap_base, _heap_ptr)
    // Bounds are backpatched at link time with 100% mathematical precision.
    // Any value outside these valid mapped readable ranges (integers, stack pointers, unmapped memory)
    // is safely rejected before any memory dereference, guaranteeing zero SEGV_MAPERR.
    x86_synth_emit_bytes(s, [
        72, 133, 255,                                         // test rdi, rdi
        116, 99,                                              // jz .not_str (+99 bytes to index 104)
        144, 144, 144, 144, 144, 144, 144, 144, 144, 144, 144, 144, // 12 x NOP (0x90): replaces page check, preserves offsets
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // movabs rax, <rodata_base> (patch offset: off + 19)
        72, 57, 199,                                          // cmp rdi, rax
        118, 15,                                              // jbe .chk_heap (+15 bytes to index 47): strictly > rodata_base required
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // movabs rax, <rodata_end> (patch offset: off + 34)
        72, 57, 199,                                          // cmp rdi, rax
        114, 41,                                              // jb .is_valid (+41 bytes to index 88)
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // .chk_heap: movabs rax, <heap_base_addr> (patch offset: off + 49)
        72, 139, 0,                                           // mov rax, [rax] (_heap_base)
        72, 133, 192,                                         // test rax, rax
        116, 39,                                              // jz .not_str (+39 bytes to index 104)
        72, 57, 199,                                          // cmp rdi, rax
        118, 34,                                              // jbe .not_str (+34 bytes to index 104): strictly > heap_base required to safely read [rdi - 4]
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // movabs rax, <heap_ptr_addr> (patch offset: off + 72)
        72, 139, 0,                                           // mov rax, [rax] (_heap_ptr)
        72, 57, 199,                                          // cmp rdi, rax
        115, 16,                                              // jae .not_str (+16 bytes to index 104)
        139, 71, 252,                                         // .is_valid: mov eax, [rdi - 4]
        61, 48, 82, 84, 83,                                   // cmp eax, 0x53545230 ('STR0')
        117, 6,                                               // jne .not_str (+6 bytes to index 104)
        184, 1, 0, 0, 0,                                      // mov eax, 1
        195,                                                  // ret
        49, 192,                                              // .not_str: xor eax, eax
        195                                                   // ret
    ])
    return off

fn x86_synth_emit__lipi_len s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_len", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 19, 87])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   32 <_lipi_len+0xb>
    x86_synth_emit_bytes(s, [95, 133, 192, 116, 4, 139, 71, 248, 195, 72, 139, 7, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_list_create s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_create", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 73, 137, 252, 73, 137, 245, 73, 199, 198, 16, 0, 0, 0, 73, 131, 252, 16, 118, 6, 77, 137, 230, 73, 209, 230, 76, 137, 247, 72, 193, 231, 3])
    x86_synth_emit_call_helper(s, "__alloc") // call   73 <_lipi_list_create+0x31>
    x86_synth_emit_bytes(s, [73, 137, 199, 77, 133, 228, 116, 25, 77, 133, 237, 116, 20, 72, 49, 201, 73, 139, 68, 205, 0, 73, 137, 4, 207, 72, 255, 193, 76, 57, 225, 114, 239, 72, 199, 199, 24, 0, 0, 0])
    x86_synth_emit_call_helper(s, "__alloc") // call   a0 <_lipi_list_create+0x5e>
    x86_synth_emit_bytes(s, [76, 137, 32, 76, 137, 112, 8, 76, 137, 120, 16, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit_lipi_fn_list s
    // WHY: Native zero-argument list constructor list() / তালিকা()
    // Clears %rdi (initial length = 0) and %rsi (initial buffer = 0), then delegates
    // cleanly to _lipi_list_create via SysV call relocation and returns list object in %rax.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "lipi_fn_list", off)
    x86_synth_emit_bytes(s, [49, 255, 49, 246]) // xor edi, edi (0x31 0xFF); xor esi, esi (0x31 0xF6)
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_byte(s, 195) // ret (0xC3)
    return off

fn x86_synth_emit__lipi_list_get s
    // WHY: Unified polymorphic element index resolver.
    // Handles both list access (arr[i]) and string character access (str[i]) dynamically.
    // When applied to strings, extracts the byte/character codepoint without crash.
    // When applied to lists, dereferences the 64-bit element array.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_get", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 45, 87, 86])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [94, 95, 133, 192, 116, 18, 72, 133, 246, 120, 27, 139, 79, 248, 72, 57, 206, 115, 19, 15, 182, 4, 55, 195, 72, 59, 55, 115, 9, 72, 139, 71, 16, 72, 139, 4, 240, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_list_set s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_set", off)
    // WHY: Returns rdi (the mutated list pointer) in rax, matching lipi_fn_list_set ABI so chained or assignment updates preserve list identity.
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 13, 72, 59, 55, 115, 8, 72, 139, 71, 16, 72, 137, 20, 240, 72, 137, 248, 195])
    return off

fn x86_synth_emit__lipi_list_pop s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_pop", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 23, 72, 139, 15, 72, 133, 201, 116, 15, 72, 255, 201, 72, 137, 15, 72, 139, 71, 16, 72, 139, 4, 200, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_list_push s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_push", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 83, 72, 133, 255, 116, 105, 73, 137, 252, 73, 137, 245, 73, 139, 4, 36, 73, 139, 92, 36, 8, 77, 139, 116, 36, 16, 72, 57, 216, 114, 69, 72, 209, 227, 72, 131, 251, 16, 115, 7, 72, 199, 195, 16, 0, 0, 0, 73, 137, 92, 36, 8, 72, 137, 223, 72, 193, 231, 3, 80, 83])
    x86_synth_emit_call_helper(s, "__alloc") // call   152 <_lipi_list_push+0x4c>
    x86_synth_emit_bytes(s, [91, 89, 72, 49, 210, 72, 57, 202, 115, 13, 73, 139, 52, 214, 72, 137, 52, 208, 72, 255, 194, 235, 238, 73, 137, 68, 36, 16, 73, 137, 198, 72, 137, 200, 77, 137, 44, 198, 72, 255, 192, 73, 137, 4, 36, 76, 137, 224, 91, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit_lipi_fn_argv s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "lipi_fn_argv", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 83, 72, 184, 224, 0, 0, 64, 0, 0, 0, 0, 76, 139, 32, 72, 184, 232, 0, 0, 64, 0, 0, 0, 0, 76, 139, 40, 77, 133, 228, 127, 11, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create") // call   1c0 <lipi_fn_argv+0x35>
    x86_synth_emit_bytes(s, [235, 123, 76, 137, 231, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create") // call   1cc <lipi_fn_argv+0x41>
    x86_synth_emit_bytes(s, [73, 137, 198, 77, 137, 38, 77, 139, 126, 16, 72, 49, 219, 76, 57, 227, 125, 92, 73, 139, 76, 221, 0, 72, 133, 201, 117, 13, 73, 199, 4, 223, 0, 0, 0, 0, 72, 255, 195, 235, 228, 49, 210, 128, 60, 17, 0, 116, 5, 72, 255, 194, 235, 245, 72, 137, 215, 72, 131, 199, 9, 81, 82])
    x86_synth_emit_call_helper(s, "__alloc") // call   210 <.av_slen+0x19>
    x86_synth_emit_bytes(s, [90, 89, 137, 16, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 49, 246, 72, 57, 214, 119, 11, 138, 4, 49, 136, 4, 55, 72, 255, 198, 235, 240, 73, 137, 60, 223, 72, 255, 195, 235, 159, 76, 137, 240, 91, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_str_concat s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_str_concat", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 83, 73, 137, 252, 73, 137, 245, 77, 49, 246, 77, 133, 228, 116, 31, 65, 139, 68, 36, 252, 61, 48, 82, 84, 83, 117, 7, 69, 139, 116, 36, 248, 235, 12, 67, 128, 60, 52, 0, 116, 5, 73, 255, 198, 235, 244, 77, 49, 255, 77, 133, 237, 116, 30, 65, 139, 69, 252, 61, 48, 82, 84, 83, 117, 6, 69, 139, 125, 248, 235, 13, 67, 128, 124, 61, 0, 0, 116, 5, 73, 255, 199, 235, 243, 75, 141, 28, 62, 72, 141, 123, 9])
    x86_synth_emit_call_helper(s, "__alloc") // call   2b5 <.s2_scan+0x1a>
    x86_synth_emit_bytes(s, [137, 24, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 77, 133, 246, 116, 20, 72, 49, 201, 76, 57, 241, 115, 12, 65, 138, 20, 12, 136, 20, 15, 72, 255, 193, 235, 239, 77, 133, 255, 116, 26, 78, 141, 4, 55, 72, 49, 201, 76, 57, 249, 115, 14, 65, 138, 84, 13, 0, 65, 136, 20, 8, 72, 255, 193, 235, 237, 198, 4, 31, 0, 72, 137, 248, 91, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_int_to_str s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_int_to_str", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 131, 236, 48, 65, 84, 65, 85, 72, 137, 248, 76, 141, 101, 255, 65, 198, 4, 36, 0, 69, 49, 237, 72, 133, 192, 117, 16, 73, 255, 204, 65, 198, 4, 36, 48, 65, 189, 1, 0, 0, 0, 235, 62, 49, 201, 72, 133, 192, 121, 8, 185, 1, 0, 0, 0, 72, 247, 216, 72, 199, 198, 10, 0, 0, 0, 72, 133, 192, 116, 20, 49, 210, 72, 247, 246, 73, 255, 204, 128, 194, 48, 65, 136, 20, 36, 65, 255, 197, 235, 231, 133, 201, 116, 11, 73, 255, 204, 65, 198, 4, 36, 45, 65, 255, 197, 76, 137, 239, 72, 131, 199, 9])
    x86_synth_emit_call_helper(s, "__alloc") // call   386 <.is_alloc+0xc>
    x86_synth_emit_bytes(s, [68, 137, 40, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 49, 201, 68, 57, 233, 119, 11, 65, 138, 20, 12, 136, 20, 15, 255, 193, 235, 240, 72, 137, 248, 65, 93, 65, 92, 72, 131, 196, 48, 93, 195])
    return off

fn x86_synth_emit__lipi_str_sub s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_str_sub", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 83, 73, 137, 252, 73, 137, 245, 73, 137, 214, 77, 133, 228, 116, 65, 77, 57, 245, 125, 60, 76, 137, 243, 76, 41, 235, 72, 141, 123, 9])
    x86_synth_emit_call_helper(s, "__alloc") // call   3e0 <_lipi_str_sub+0x2d>
    x86_synth_emit_bytes(s, [137, 24, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 72, 49, 201, 72, 57, 217, 115, 15, 75, 141, 4, 44, 138, 20, 8, 136, 20, 15, 72, 255, 193, 235, 236, 198, 4, 31, 0, 72, 137, 248, 235, 35, 72, 199, 199, 9, 0, 0, 0])
    x86_synth_emit_call_helper(s, "__alloc") // call   419 <.ss_em+0xc>
    x86_synth_emit_bytes(s, [199, 0, 0, 0, 0, 0, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 198, 7, 0, 72, 137, 248, 91, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

// File I/O helpers (_lipi_file_exists, _lipi_file_write, _lipi_file_read, _lipi_file_write_bytes)
// are defined in runtime_io.lp to maintain strict compliance with the 35KB Golden Invariant.


fn x86_synth_emit__lipi_add_dynamic s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_add_dynamic", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 73, 137, 252, 73, 137, 245, 65, 84])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   59c <_lipi_add_dynamic+0x15>
    x86_synth_emit_bytes(s, [65, 92, 133, 192, 117, 28, 65, 84, 76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   5ac <_lipi_add_dynamic+0x25>
    x86_synth_emit_bytes(s, [65, 92, 133, 192, 117, 12, 76, 137, 224, 76, 1, 232, 65, 93, 65, 92, 93, 195, 65, 85, 76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   5c8 <.ad_s+0xa>
    x86_synth_emit_bytes(s, [65, 93, 133, 192, 117, 15, 76, 137, 231, 65, 85])
    x86_synth_emit_call_helper(s, "_lipi_int_to_str") // call   5d8 <.ad_s+0x1a>
    x86_synth_emit_bytes(s, [65, 93, 73, 137, 196, 76, 137, 239, 65, 84])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   5e7 <.ad_s+0x29>
    x86_synth_emit_bytes(s, [65, 92, 133, 192, 117, 15, 76, 137, 239, 65, 84])
    x86_synth_emit_call_helper(s, "_lipi_int_to_str") // call   5f7 <.ad_s+0x39>
    x86_synth_emit_bytes(s, [65, 92, 73, 137, 197, 76, 137, 231, 76, 137, 238])
    x86_synth_emit_call_helper(s, "_lipi_str_concat") // call   607 <.ad_s+0x49>
    x86_synth_emit_bytes(s, [65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_cmp_dynamic s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_cmp_dynamic", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 83, 73, 137, 252, 73, 137, 245, 77, 57, 236, 117, 4, 49, 192, 235, 125, 65, 84, 65, 85, 76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   635 <.cd_chk+0xc>
    x86_synth_emit_bytes(s, [65, 93, 65, 92, 133, 192, 116, 93, 65, 84, 65, 85, 76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call   649 <.cd_chk+0x20>
    x86_synth_emit_bytes(s, [65, 93, 65, 92, 133, 192, 116, 73, 69, 139, 116, 36, 248, 69, 139, 125, 248, 76, 137, 243, 76, 57, 251, 118, 3, 76, 137, 251, 72, 49, 201, 72, 57, 217, 115, 20, 65, 138, 4, 12, 65, 138, 84, 13, 0, 56, 208, 114, 18, 119, 23, 72, 255, 193, 235, 231, 77, 57, 254, 114, 6, 119, 11, 49, 192, 235, 26, 184, 255, 255, 255, 255, 235, 19, 184, 1, 0, 0, 0, 235, 12, 77, 57, 236, 124, 237, 184, 1, 0, 0, 0, 235, 0, 91, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_print_dynamic s
    // WHY: Dynamic output dispatcher. Inspects STR0 header; formats and writes strings or
    // integers directly to stdout with trailing newline in pure machine code (zero libc).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_print_dynamic", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 73, 137, 252, 76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_is_str") // call _lipi_is_str
    x86_synth_emit_bytes(s, [133, 192, 116, 56, 65, 139, 84, 36, 248, 76, 137, 230, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 131, 236, 16, 198, 4, 36, 10, 191, 1, 0, 0, 0, 72, 137, 230, 186, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 131, 196, 16, 65, 92, 93, 195, 76, 137, 224])
    x86_synth_emit_call_helper(s, "__print_int") // call __print_int with rax = integer
    x86_synth_emit_bytes(s, [65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_print_nl s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_print_nl", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 131, 236, 16, 198, 4, 36, 10, 191, 1, 0, 0, 0, 72, 137, 230, 186, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 131, 196, 16, 93, 195])
    return off

fn x86_synth_emit__lipi_floor s
    // WHY: Floor rounding intrinsic (identity for integers)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_floor", off)
    x86_synth_emit_bytes(s, [72, 137, 248, 195]) // mov rax, rdi; ret
    return off

fn x86_synth_emit__lipi_ord s
    // WHY: String byte / ASCII ordinal inspector
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_ord", off)
    // test rdi, rdi; jz .zero; movzx eax, byte ptr [rdi]; ret; .zero: xor eax, eax; ret
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 6, 15, 182, 7, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_chr s
    // WHY: ASCII byte code to 1-character STR0 string converter
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_chr", off)
    // push r12; mov r12, rdi; mov rdi, 10
    x86_synth_emit_bytes(s, [65, 84, 73, 137, 252, 72, 199, 199, 10, 0, 0, 0])
    x86_synth_emit_call_helper(s, "__alloc")
    // [rax] = 1, [rax+4] = STR0, [rax+8] = r12b, [rax+9] = 0; add rax, 8; pop r12; ret
    x86_synth_emit_bytes(s, [199, 0, 1, 0, 0, 0, 199, 64, 4, 48, 82, 84, 83, 68, 136, 96, 8, 198, 64, 9, 0, 72, 131, 192, 8, 65, 92, 195])
    return off

fn x86_synth_emit__lipi_char_at s
    // WHY: Native 1-character substring extractor char_at(str, idx)
    // Computes end = idx + 1 into %rdx and delegates to _lipi_str_sub
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_char_at", off)
    x86_synth_emit_bytes(s, [72, 141, 86, 1]) // lea rdx, [rsi + 1]
    x86_synth_emit_call_helper(s, "_lipi_str_sub")
    x86_synth_emit_byte(s, 195) // ret
    return off

fn x86_synth_emit__lipi_mem_byte_read s
    // WHY: Silicon-direct memory byte inspector mem_byte_read / str_char_at(base, offset)
    // Reads an 8-bit unsigned byte at [rdi + rsi] and returns it zero-extended in %rax.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_mem_byte_read", off)
    // test rdi, rdi; jz .zero; add rdi, rsi; movzx eax, byte ptr [rdi]; ret; .zero: xor eax, eax; ret
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 8, 72, 1, 247, 15, 182, 7, 195, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_mem_byte_write s
    // WHY: Silicon-direct memory byte mutator mem_byte_write / sys_poke8(base, offset, val)
    // Stores the lowest 8 bits of %rdx into memory address [rdi + rsi].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_mem_byte_write", off)
    // test rdi, rdi; jz .zero; add rdi, rsi; mov [rdi], dl; ret; .zero: ret
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 7, 72, 1, 247, 136, 23, 195, 195])
    return off

fn x86_synth_emit__lipi_sys_exit s
    // WHY: Native Linux sys_exit (syscall nr 60) terminates calling process with code in %rdi
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_sys_exit", off)
    // mov eax, 60; syscall; hlt; ret
    x86_synth_emit_bytes(s, [184, 60, 0, 0, 0, 15, 5, 244, 195])
    return off

fn x86_synth_emit__lipi_sys_mmap s
    // WHY: Native Linux mmap (syscall nr 9) mapping virtual pages into memory
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_sys_mmap", off)
    // mov r10, rcx; mov eax, 9; syscall; ret (49 CA, B8 09 00 00 00, 0F 05, C3)
    x86_synth_emit_bytes(s, [73, 137, 202, 184, 9, 0, 0, 0, 15, 5, 195])
    return off

fn x86_synth_emit__lipi_mem_word_read s
    // WHY: 64-bit QWORD memory read at [rdi + rsi] (SysV: rdi=base, rsi=offset)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_mem_word_read", off)
    // mov rax, [rdi + rsi]; ret
    x86_synth_emit_bytes(s, [72, 139, 4, 55, 195])
    return off

fn x86_synth_emit__lipi_mem_word_write s
    // WHY: 64-bit QWORD memory write at [rdi + rsi] (SysV: rdi=base, rsi=offset, rdx=val)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_mem_word_write", off)
    // mov [rdi + rsi], rdx; mov rax, rdx; ret
    x86_synth_emit_bytes(s, [72, 137, 20, 55, 72, 137, 208, 195])
    return off

fn x86_synth_emit__lipi_sys_peek s
    // WHY: 64-bit direct memory dereference at [rdi]
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_sys_peek", off)
    // mov rax, [rdi]; ret
    x86_synth_emit_bytes(s, [72, 139, 7, 195])
    return off

fn x86_synth_emit__lipi_sys_poke s
    // WHY: 64-bit direct memory store at [rdi] = rsi
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_sys_poke", off)
    // mov [rdi], rsi; mov rax, rsi; ret
    x86_synth_emit_bytes(s, [72, 137, 55, 72, 137, 240, 195])
    return off

fn x86_synth_emit__lipi_slab_buckets_ptr s
    // WHY: Returns static 64-byte QWORD table address for segregated slab freelists in 1 CPU cycle
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_slab_buckets_ptr", off)
    // lea rax, [rip + 1]; ret
    x86_synth_emit_bytes(s, [72, 141, 5, 1, 0, 0, 0, 195])
    zi = 0
    while zi < 64
        x86_synth_emit_byte(s, 0)
        zi = zi + 1
    return off

fn x86_synth_emit__lipi_cpu_clock s
    // WHY: Hardware high-resolution CPU cycle counter via RDTSC instruction
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_cpu_clock", off)
    // rdtsc; shl rdx, 32; or rax, rdx; ret
    x86_synth_emit_bytes(s, [15, 49, 72, 193, 226, 32, 72, 9, 208, 195])
    return off

fn x86_synth_emit__lipi_clock_ms s
    // WHY: Realtime millisecond clock via Linux SYS_clock_gettime (syscall nr 228)
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_clock_ms", off)
    x86_synth_emit_bytes(s, [
        85, 72, 137, 229, 72, 131, 236, 32, 72, 199, 192, 228, 0, 0, 0,
        72, 49, 255, 72, 137, 230, 15, 5, 72, 139, 4, 36, 72, 105, 192,
        232, 3, 0, 0, 72, 139, 84, 36, 8, 73, 199, 193, 64, 66, 15, 0,
        80, 72, 137, 208, 72, 49, 210, 73, 247, 241, 90, 72, 1, 208, 201, 195
    ])
    return off

fn x86_synth_emit__lipi_size_of s
    // WHY: Intrinsic sizeof returning 64 bytes for general heap cells
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_size_of", off)
    // mov rax, 64; ret
    x86_synth_emit_bytes(s, [72, 199, 192, 64, 0, 0, 0, 195])
    return off

fn x86_synth_emit__lipi_stack_pointer s
    // WHY: Introspect hardware %rsp stack pointer
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_stack_pointer", off)
    // mov rax, rsp; ret
    x86_synth_emit_bytes(s, [72, 137, 224, 195])
    return off

fn x86_synth_emit__lipi_atomic_lock s
    // WHY: Hardware silicon atomic spinlock via lock bts with pause
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_atomic_lock", off)
    x86_synth_emit_bytes(s, [
        240, 72, 15, 186, 47, 0, 115, 11, 243, 144, 72, 131, 63, 0,
        117, 248, 235, 239, 72, 199, 192, 1, 0, 0, 0, 195
    ])
    return off

fn x86_synth_emit__lipi_atomic_unlock s
    // WHY: Hardware silicon atomic spinlock unlock via lock btr
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_atomic_unlock", off)
    x86_synth_emit_bytes(s, [240, 72, 15, 186, 55, 0, 72, 49, 192, 195])
    return off

fn x86_synth_emit_all_runtime_helpers s
    // WHY: Emits all fundamental runtime helpers and registers their primary and alias names
    off__lipi_is_str = x86_synth_emit__lipi_is_str(s)
    off__lipi_len = x86_synth_emit__lipi_len(s)
    off__lipi_list_create = x86_synth_emit__lipi_list_create(s)
    off_lipi_fn_list = x86_synth_emit_lipi_fn_list(s)
    off__lipi_list_get = x86_synth_emit__lipi_list_get(s)
    off__lipi_list_set = x86_synth_emit__lipi_list_set(s)
    off__lipi_list_pop = x86_synth_emit__lipi_list_pop(s)
    off__lipi_list_push = x86_synth_emit__lipi_list_push(s)
    off_lipi_fn_argv = x86_synth_emit_lipi_fn_argv(s)
    off__lipi_str_concat = x86_synth_emit__lipi_str_concat(s)
    off__lipi_int_to_str = x86_synth_emit__lipi_int_to_str(s)
    off__lipi_str_sub = x86_synth_emit__lipi_str_sub(s)
    off__lipi_char_at = x86_synth_emit__lipi_char_at(s)
    off__lipi_ord = x86_synth_emit__lipi_ord(s)
    off__lipi_chr = x86_synth_emit__lipi_chr(s)
    off__lipi_floor = x86_synth_emit__lipi_floor(s)
    off__lipi_file_exists = x86_synth_emit__lipi_file_exists(s)
    off__lipi_file_write = x86_synth_emit__lipi_file_write(s)
    off__lipi_file_read = x86_synth_emit__lipi_file_read(s)
    off__lipi_file_write_bytes = x86_synth_emit__lipi_file_write_bytes(s)
    off__lipi_ensure_str = x86_synth_emit__lipi_ensure_str(s)
    off__lipi_malloc = x86_synth_emit__lipi_malloc(s)
    off__lipi_add_dynamic = x86_synth_emit__lipi_add_dynamic(s)
    off__lipi_cmp_dynamic = x86_synth_emit__lipi_cmp_dynamic(s)
    off__lipi_print_dynamic = x86_synth_emit__lipi_print_dynamic(s)
    off__lipi_print_nl = x86_synth_emit__lipi_print_nl(s)
    off__lipi_mem_byte_read = x86_synth_emit__lipi_mem_byte_read(s)
    off__lipi_mem_byte_write = x86_synth_emit__lipi_mem_byte_write(s)
    off__lipi_sys_exit = x86_synth_emit__lipi_sys_exit(s)
    off__lipi_sys_mmap = x86_synth_emit__lipi_sys_mmap(s)
    off__lipi_mem_word_read = x86_synth_emit__lipi_mem_word_read(s)
    off__lipi_mem_word_write = x86_synth_emit__lipi_mem_word_write(s)
    off__lipi_sys_peek = x86_synth_emit__lipi_sys_peek(s)
    off__lipi_sys_poke = x86_synth_emit__lipi_sys_poke(s)
    off__lipi_slab_buckets_ptr = x86_synth_emit__lipi_slab_buckets_ptr(s)
    off__lipi_cpu_clock = x86_synth_emit__lipi_cpu_clock(s)
    off__lipi_clock_ms = x86_synth_emit__lipi_clock_ms(s)
    off__lipi_size_of = x86_synth_emit__lipi_size_of(s)
    off__lipi_stack_pointer = x86_synth_emit__lipi_stack_pointer(s)
    off__lipi_atomic_lock = x86_synth_emit__lipi_atomic_lock(s)
    off__lipi_atomic_unlock = x86_synth_emit__lipi_atomic_unlock(s)
    off__lipi_pass_thru = x86_synth_emit__lipi_pass_thru(s)
    off__lipi_atomic_cas = x86_synth_emit__lipi_atomic_cas(s)
    off__lipi_atomic_add = x86_synth_emit__lipi_atomic_add(s)
    off__lipi_user_alloc = x86_synth_emit__lipi_user_alloc(s)
    off__lipi_user_free = x86_synth_emit__lipi_user_free(s)

    // Register bilingual and standard aliases
    x86_synth_register_helper_fn(s, "argv", off_lipi_fn_argv)
    x86_synth_register_helper_fn(s, "আর্গস", off_lipi_fn_argv)
    x86_synth_register_helper_fn(s, "len", off__lipi_len)
    x86_synth_register_helper_fn(s, "দৈর্ঘ্য", off__lipi_len)
    x86_synth_register_helper_fn(s, "length", off__lipi_len)
    x86_synth_register_helper_fn(s, "str_len", off__lipi_len)
    x86_synth_register_helper_fn(s, "list", off_lipi_fn_list)
    x86_synth_register_helper_fn(s, "তালিকা", off_lipi_fn_list)
    x86_synth_register_helper_fn(s, "get", off__lipi_list_get)
    x86_synth_register_helper_fn(s, "নাও", off__lipi_list_get)
    x86_synth_register_helper_fn(s, "list_set", off__lipi_list_set)
    x86_synth_register_helper_fn(s, "সেট", off__lipi_list_set)
    x86_synth_register_helper_fn(s, "push", off__lipi_list_push)
    x86_synth_register_helper_fn(s, "যোগ_করো", off__lipi_list_push)
    x86_synth_register_helper_fn(s, "pop", off__lipi_list_pop)
    x86_synth_register_helper_fn(s, "বাদ_দাও", off__lipi_list_pop)
    x86_synth_register_helper_fn(s, "str", off__lipi_ensure_str)
    x86_synth_register_helper_fn(s, "স্ট্রিং", off__lipi_ensure_str)
    x86_synth_register_helper_fn(s, "_lipi_ensure_str", off__lipi_ensure_str)
    x86_synth_register_helper_fn(s, "lipi_fn_str", off__lipi_ensure_str)

    x86_synth_register_helper_fn(s, "str_sub", off__lipi_str_sub)
    x86_synth_register_helper_fn(s, "char_at", off__lipi_char_at)
    x86_synth_register_helper_fn(s, "অক্ষর", off__lipi_char_at)
    x86_synth_register_helper_fn(s, "str_char_at", off__lipi_mem_byte_read)
    x86_synth_register_helper_fn(s, "mem_byte_read", off__lipi_mem_byte_read)
    x86_synth_register_helper_fn(s, "mem_read_byte", off__lipi_mem_byte_read)
    x86_synth_register_helper_fn(s, "মেমরি_বাইট_পড়ো", off__lipi_mem_byte_read)
    x86_synth_register_helper_fn(s, "mem_byte_পড়ো", off__lipi_mem_byte_read)
    x86_synth_register_helper_fn(s, "sys_peek8", off__lipi_mem_byte_read)
    x86_synth_register_helper_fn(s, "mem_byte_write", off__lipi_mem_byte_write)
    x86_synth_register_helper_fn(s, "mem_write_byte", off__lipi_mem_byte_write)
    x86_synth_register_helper_fn(s, "মেমরি_বাইট_লেখো", off__lipi_mem_byte_write)
    x86_synth_register_helper_fn(s, "mem_byte_লেখো", off__lipi_mem_byte_write)
    x86_synth_register_helper_fn(s, "sys_poke8", off__lipi_mem_byte_write)
    x86_synth_register_helper_fn(s, "sys_exit", off__lipi_sys_exit)
    x86_synth_register_helper_fn(s, "sys_exit_group", off__lipi_sys_exit)
    x86_synth_register_helper_fn(s, "exit", off__lipi_sys_exit)
    x86_synth_register_helper_fn(s, "প্রস্থান", off__lipi_sys_exit)
    x86_synth_register_helper_fn(s, "sys_mmap", off__lipi_sys_mmap)
    x86_synth_register_helper_fn(s, "ord", off__lipi_ord)
    x86_synth_register_helper_fn(s, "কোড", off__lipi_ord)
    x86_synth_register_helper_fn(s, "ascii", off__lipi_ord)
    x86_synth_register_helper_fn(s, "chr", off__lipi_chr)
    x86_synth_register_helper_fn(s, "অক্ষর_চিহ্ন", off__lipi_chr)
    x86_synth_register_helper_fn(s, "floor", off__lipi_floor)
    x86_synth_register_helper_fn(s, "মেঝে", off__lipi_floor)
    x86_synth_register_helper_fn(s, "file_exists", off__lipi_file_exists)
    x86_synth_register_helper_fn(s, "file_read", off__lipi_file_read)
    x86_synth_register_helper_fn(s, "file_write", off__lipi_file_write)
    x86_synth_register_helper_fn(s, "file_write_bytes", off__lipi_file_write_bytes)
    x86_synth_register_helper_fn(s, "println", off__lipi_print_dynamic)
    x86_synth_register_helper_fn(s, "is_str", off__lipi_is_str)
    x86_synth_register_helper_fn(s, "is_string", off__lipi_is_str)

    // Builtin Memory Allocator Stubs
    x86_synth_register_helper_fn(s, "malloc", off__lipi_malloc)
    x86_synth_register_helper_fn(s, "mem_alloc", off__lipi_malloc)
    x86_synth_register_helper_fn(s, "মেমরি_বরাদ্দ", off__lipi_malloc)

    // 64-bit Memory word read / write
    x86_synth_register_helper_fn(s, "mem_word_read", off__lipi_mem_word_read)
    x86_synth_register_helper_fn(s, "mem_read_word", off__lipi_mem_word_read)
    x86_synth_register_helper_fn(s, "mem_read", off__lipi_mem_word_read)
    x86_synth_register_helper_fn(s, "মেমরি_পড়ো", off__lipi_mem_word_read)
    x86_synth_register_helper_fn(s, "মেমরি_শব্দ_পড়ো", off__lipi_mem_word_read)
    x86_synth_register_helper_fn(s, "mem_word_write", off__lipi_mem_word_write)
    x86_synth_register_helper_fn(s, "mem_write_word", off__lipi_mem_word_write)
    x86_synth_register_helper_fn(s, "mem_write", off__lipi_mem_word_write)
    x86_synth_register_helper_fn(s, "মেমরি_লেখো", off__lipi_mem_word_write)
    x86_synth_register_helper_fn(s, "মেমরি_শব্দ_লেখো", off__lipi_mem_word_write)
    x86_synth_register_helper_fn(s, "sys_peek", off__lipi_sys_peek)
    x86_synth_register_helper_fn(s, "sys_poke", off__lipi_sys_poke)

    // Slab Allocator & Sizeof
    x86_synth_register_helper_fn(s, "slab_buckets_ptr", off__lipi_slab_buckets_ptr)
    x86_synth_register_helper_fn(s, "স্ল্যাব_বাকেট_পয়েন্টার", off__lipi_slab_buckets_ptr)
    x86_synth_register_helper_fn(s, "sizeof", off__lipi_size_of)
    x86_synth_register_helper_fn(s, "size_of", off__lipi_size_of)
    x86_synth_register_helper_fn(s, "সাইজ_অফ", off__lipi_size_of)

    // Timing & Clocks
    x86_synth_register_helper_fn(s, "cpu_clock", off__lipi_cpu_clock)
    x86_synth_register_helper_fn(s, "ক্লক", off__lipi_cpu_clock)
    x86_synth_register_helper_fn(s, "clock_ms", off__lipi_clock_ms)
    x86_synth_register_helper_fn(s, "time_now_ms", off__lipi_clock_ms)
    x86_synth_register_helper_fn(s, "time_now", off__lipi_clock_ms)
    x86_synth_register_helper_fn(s, "সময়_মিলি", off__lipi_clock_ms)

    // Stack pointer & Atomics
    x86_synth_register_helper_fn(s, "stack_pointer", off__lipi_stack_pointer)
    x86_synth_register_helper_fn(s, "স্ট্যাক_পয়েন্টার", off__lipi_stack_pointer)
    x86_synth_register_helper_fn(s, "atomic_lock", off__lipi_atomic_lock)
    x86_synth_register_helper_fn(s, "অ্যাটমিক_লক", off__lipi_atomic_lock)
    x86_synth_register_helper_fn(s, "atomic_unlock", off__lipi_atomic_unlock)
    x86_synth_register_helper_fn(s, "অ্যাটমিক_আনলক", off__lipi_atomic_unlock)
    return 0
