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
    fn_info.fn_ret_type = ""
    fn_info.fn_end_offset = 0
    fn_info.fn_decl_line = 0
    fn_info.fn_param_count = 0 - 1
    fn_info.fn_tok_pos = 0 - 1
    fn_info.fn_param_types = list()
    x86_synth_register_fn_obj(s, fn_info)
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
        116, 2,                                               // jz .ret0 (+2 to index 7)
        235, 3,                                               // jmp +3 to index 10
        49, 192, 195,                                         // .ret0: xor eax, eax; ret
        144, 144, 144, 144, 144, 144, 144,                    // 7 x NOP: preserves exact patch offsets (+19, +34, +49, +72)
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // movabs rax, <rodata_base> (patch offset: off + 19)
        72, 57, 199,                                          // cmp rdi, rax
        118, 15,                                              // jbe .chk_heap (+15 bytes to index 47)
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // movabs rax, <rodata_end> (patch offset: off + 34)
        72, 57, 199,                                          // cmp rdi, rax
        114, 92,                                              // jb .is_valid (+92 bytes to index 139)
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,                      // .chk_heap: movabs rax, <heap_base_addr> (patch offset: off + 49)
        72, 139, 0,                                           // mov rax, [rax] (_heap_base)
        72, 133, 192,                                         // test rax, rax
        116, 90,                                              // jz .not_str (+90 bytes to index 155)
        72, 57, 199,                                          // cmp rdi, rax
        118, 85,                                              // jbe .not_str (+85 bytes to index 155)
        72, 186, 0, 0, 0, 0, 0, 0, 0, 0,                      // movabs rdx, <heap_ptr_addr> (patch offset: off + 72)
        72, 139, 2,                                           // mov rax, [rdx] (_heap_ptr)
        72, 57, 199,                                          // cmp rdi, rax
        115, 67,                                              // jae .not_str (+67 bytes to index 151)
        // WHY: When disjoint heap chunks exist ([rdx+0x1f0] != 0), verify rdi lies inside an actually-mapped
        // chunk [chunk.base+4, chunk.end) before reading [rdi - 4] so unmapped SYS_munmap gaps never SIGSEGV.
        72, 139, 138, 240, 1, 0, 0,                           // mov rcx, [rdx + 0x1f0] (_heap_chunks_ptr)
        72, 133, 201,                                         // test rcx, rcx
        116, 39,                                              // je .is_valid (+39 to index 135)
        76, 139, 130, 248, 1, 0, 0,                           // mov r8, [rdx + 0x1f8] (_heap_chunks_cnt)
        77, 133, 192,                                         // .cloop: test r8, r8
        116, 43,                                              // je .not_str (+43 to index 151)
        76, 139, 9,                                           // mov r9, [rcx]
        73, 131, 193, 4,                                      // add r9, 4
        76, 57, 207,                                          // cmp rdi, r9
        114, 6,                                               // jb .cnext (+6 to index 126)
        72, 59, 121, 8,                                       // cmp rdi, [rcx + 8]
        114, 9,                                               // jb .is_valid (+9 to index 135)
        72, 131, 193, 16,                                     // .cnext: add rcx, 16
        73, 255, 200,                                         // dec r8
        235, 224,                                             // jmp .cloop (-32 to index 103)
        139, 71, 252,                                         // .is_valid (index 135): mov eax, [rdi - 4]
        61, 48, 82, 84, 83,                                   // cmp eax, 0x53545230 ('STR0')
        117, 6,                                               // jne .not_str (+6 bytes to index 151)
        184, 1, 0, 0, 0,                                      // mov eax, 1
        195,                                                  // ret
        49, 192,                                              // .not_str (index 151): xor eax, eax
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
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [73, 137, 199, 77, 133, 228, 116, 25, 77, 133, 237, 116, 20, 72, 49, 201, 73, 139, 68, 205, 0, 73, 137, 4, 207, 72, 255, 193, 76, 57, 225, 114, 239, 72, 199, 199, 24, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [76, 137, 32, 76, 137, 112, 8, 76, 137, 120, 16, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit_lipi_fn_list s
    // WHY: Native zero-argument list constructor list() / তালিকা()
    // Clears %rdi (initial length = 0) and %rsi (initial buffer = 0), then delegates
    // cleanly to _lipi_list_create via 16-byte aligned SysV call relocation and returns list object in %rax.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "lipi_fn_list", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 49, 255, 49, 246]) // push rbp; mov rbp, rsp; xor edi, edi; xor esi, esi
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [93, 195]) // pop rbp; ret
    return off

fn x86_synth_emit__lipi_list_get s
    // WHY: Unified thread-safe polymorphic element index resolver supporting LIST, STR0 strings, and DICT0 maps.
    // Protects LIST header/data reads under per-list bit-63 spinlock on [rdi+8] matching _lipi_list_push.
    // Supports negative indexing (`a[-1]`, `s[-1]`) for LIST and STR0 (preserving signed keys for DICT0).
    // Returns %rax = raw value, %rdx = val_tag (0 for list/str/miss, 0/1/2 for DICT0).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_get", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 15, 132, 127, 0, 0, 0, 85, 72, 137, 229, 87, 86])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [94, 95, 93, 133, 192, 117, 86, 72, 184, 76, 73, 80, 68, 73, 67, 84, 48, 72, 57, 71, 24, 116, 59, 240, 72, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 72, 139, 15, 72, 133, 246, 121, 3, 72, 1, 206, 72, 57, 206, 115, 18, 72, 139, 71, 16, 72, 139, 4, 240, 240, 72, 15, 186, 119, 8, 63, 49, 210, 195, 240, 72, 15, 186, 119, 8, 63, 49, 192, 49, 210, 195, 85, 72, 137, 229])
    x86_synth_emit_call_helper(s, "_lipi_dict_get")
    x86_synth_emit_bytes(s, [93, 195, 139, 79, 248, 72, 133, 246, 121, 3, 72, 1, 206, 72, 57, 206, 115, 7, 15, 182, 4, 55, 49, 210, 195, 49, 192, 49, 210, 195])
    return off

fn x86_synth_emit__lipi_list_set s
    // WHY: Polymorphic setter supporting both LIST[idx]=val and DICT0[key]=val (default vtag=0).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_set", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 49, 201])
    x86_synth_emit_call_helper(s, "_lipi_list_set_typed")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_list_set_typed s
    // WHY: Thread-safe tagged polymorphic setter forwarding %rcx = val_tag (0=int/ptr, 1=float, 2=str)
    // into DICT0, and protecting LIST element stores under per-list bit-63 spinlock on [rdi+8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_set_typed", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 60, 72, 184, 76, 73, 80, 68, 73, 67, 84, 48, 72, 57, 71, 24, 116, 48, 240, 72, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 76, 139, 7, 72, 133, 246, 121, 3, 76, 1, 198, 76, 57, 198, 115, 8, 72, 139, 71, 16, 72, 137, 20, 240, 240, 72, 15, 186, 119, 8, 63, 72, 137, 248, 195, 85, 72, 137, 229])
    x86_synth_emit_call_helper(s, "_lipi_dict_set_typed")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_throw_null_deref s
    // WHY: Shared bare-metal trap throwing catchable NullPointerException on null/low struct deref (< 4096).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_throw_null_deref", off)
    ro_off = x86_synth_add_rodata_str(s, "NullPointerException: null struct dereference", 0)
    // push rbp; mov rbp, rsp; movabs rax, <rodata_vaddr>; mov rdi, rax; call _lipi_exc_throw
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 184])
    patch_pos = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    rel = X86StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    push(s.synth_str_relocs, rel)
    x86_synth_emit_bytes(s, [72, 137, 199]) // mov rdi, rax
    x86_synth_emit_call_helper(s, "_lipi_exc_throw")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_throw_null_index s
    // WHY: Shared trap throwing catchable NullPointerException on null/low bracket index (`p[idx]` when p < 4096).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_throw_null_index", off)
    ro_off = x86_synth_add_rodata_str(s, "NullPointerException: null index dereference", 0)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 184])
    patch_pos = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    rel = X86StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    push(s.synth_str_relocs, rel)
    x86_synth_emit_bytes(s, [72, 137, 199])
    x86_synth_emit_call_helper(s, "_lipi_exc_throw")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_div_by_zero s
    // WHY: Sovereign divide/modulo-by-zero handler. Inside any active `try` handler (per-thread exc_top != 0),
    // throws catchable DivisionByZeroException; outside `try`, returns 0 safely (preserving legacy 0-guard tests).
    off = s.synth_code.len()
    s.synth_div_zero_off = off
    x86_synth_register_helper_fn(s, "_lipi_div_by_zero", off)
    ro_off = x86_synth_add_rodata_str(s, "DivisionByZeroException: integer division or modulo by zero", 0)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 73, 137, 194])
    x86_synth_emit_call_helper(s, "_lipi_exc_slot_ptr")
    x86_synth_emit_bytes(s, [73, 139, 2, 72, 133, 192, 117, 3, 49, 192, 195, 85, 72, 137, 229, 72, 184])
    patch_pos = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    rel = X86StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    push(s.synth_str_relocs, rel)
    x86_synth_emit_bytes(s, [72, 137, 199])
    x86_synth_emit_call_helper(s, "_lipi_exc_throw")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_list_pop s
    // WHY: Thread-safe list pop protected by per-list bit-63 spinlock on cap slot [rdi+8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_pop", off)
    x86_synth_emit_bytes(s, [72, 133, 255, 116, 50, 240, 72, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 72, 139, 15, 72, 133, 201, 116, 22, 72, 255, 201, 72, 137, 15, 72, 139, 71, 16, 72, 139, 4, 200, 240, 72, 15, 186, 119, 8, 63, 195, 240, 72, 15, 186, 119, 8, 63, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_list_push s
    // WHY: Thread-safe dynamic list push protected by per-list bit-63 spinlock on cap slot [r12 + 8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_list_push", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 83, 49, 192, 72, 133, 255, 15, 132, 140, 0, 0, 0, 73, 137, 252, 73, 137, 245, 240, 73, 15, 186, 108, 36, 8, 63, 115, 4, 243, 144, 235, 242, 73, 139, 4, 36, 73, 139, 92, 36, 8, 72, 15, 186, 243, 63, 77, 139, 116, 36, 16, 72, 57, 216, 114, 74, 72, 209, 227, 72, 131, 251, 16, 115, 7, 72, 199, 195, 16, 0, 0, 0, 72, 137, 223, 72, 193, 231, 3, 80, 83])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [91, 89, 72, 49, 210, 72, 57, 202, 115, 13, 73, 139, 52, 214, 72, 137, 52, 208, 72, 255, 194, 235, 238, 73, 137, 68, 36, 16, 73, 137, 198, 72, 15, 186, 235, 63, 73, 137, 92, 36, 8, 72, 137, 200, 77, 137, 44, 198, 72, 255, 192, 73, 137, 4, 36, 240, 73, 15, 186, 116, 36, 8, 63, 76, 137, 224, 91, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit_lipi_fn_argv s
    off = s.synth_code.len()
    s.synth_argv_off = off
    x86_synth_register_helper_fn(s, "lipi_fn_argv", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 83, 72, 184, 224, 0, 0, 64, 0, 0, 0, 0, 76, 139, 32, 72, 184, 232, 0, 0, 64, 0, 0, 0, 0, 76, 139, 40, 77, 133, 228, 127, 11, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create") // call   1c0 <lipi_fn_argv+0x35>
    x86_synth_emit_bytes(s, [235, 123, 76, 137, 231, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create") // call   1cc <lipi_fn_argv+0x41>
    x86_synth_emit_bytes(s, [73, 137, 198, 77, 137, 38, 77, 139, 126, 16, 72, 49, 219, 76, 57, 227, 125, 92, 73, 139, 76, 221, 0, 72, 133, 201, 117, 13, 73, 199, 4, 223, 0, 0, 0, 0, 72, 255, 195, 235, 228, 49, 210, 128, 60, 17, 0, 116, 5, 72, 255, 194, 235, 245, 72, 137, 215, 72, 131, 199, 9, 81, 82])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [90, 89, 137, 16, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 49, 246, 72, 57, 214, 119, 11, 138, 4, 49, 136, 4, 55, 72, 255, 198, 235, 240, 73, 137, 60, 223, 72, 255, 195, 235, 159, 76, 137, 240, 91, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_str_concat s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_str_concat", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 83, 73, 137, 252, 73, 137, 245, 77, 49, 246, 77, 133, 228, 116, 31, 65, 139, 68, 36, 252, 61, 48, 82, 84, 83, 117, 7, 69, 139, 116, 36, 248, 235, 12, 67, 128, 60, 52, 0, 116, 5, 73, 255, 198, 235, 244, 77, 49, 255, 77, 133, 237, 116, 30, 65, 139, 69, 252, 61, 48, 82, 84, 83, 117, 6, 69, 139, 125, 248, 235, 13, 67, 128, 124, 61, 0, 0, 116, 5, 73, 255, 199, 235, 243, 75, 141, 28, 62, 72, 141, 123, 9])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [137, 24, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 77, 133, 246, 116, 20, 72, 49, 201, 76, 57, 241, 115, 12, 65, 138, 20, 12, 136, 20, 15, 72, 255, 193, 235, 239, 77, 133, 255, 116, 26, 78, 141, 4, 55, 72, 49, 201, 76, 57, 249, 115, 14, 65, 138, 84, 13, 0, 65, 136, 20, 8, 72, 255, 193, 235, 237, 198, 4, 31, 0, 72, 137, 248, 91, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_int_to_str s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_int_to_str", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 131, 236, 48, 65, 84, 65, 85, 72, 137, 248, 76, 141, 101, 255, 65, 198, 4, 36, 0, 69, 49, 237, 72, 133, 192, 117, 16, 73, 255, 204, 65, 198, 4, 36, 48, 65, 189, 1, 0, 0, 0, 235, 62, 49, 201, 72, 133, 192, 121, 8, 185, 1, 0, 0, 0, 72, 247, 216, 72, 199, 198, 10, 0, 0, 0, 72, 133, 192, 116, 20, 49, 210, 72, 247, 246, 73, 255, 204, 128, 194, 48, 65, 136, 20, 36, 65, 255, 197, 235, 231, 133, 201, 116, 11, 73, 255, 204, 65, 198, 4, 36, 45, 65, 255, 197, 76, 137, 239, 72, 131, 199, 9])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [68, 137, 40, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 49, 201, 68, 57, 233, 119, 11, 65, 138, 20, 12, 136, 20, 15, 255, 193, 235, 240, 72, 137, 248, 65, 93, 65, 92, 72, 131, 196, 48, 93, 195])
    return off

fn x86_synth_emit__lipi_uint_to_str s
    // WHY: Pure unsigned 64-bit decimal formatter (0..18446744073709551615) using hardware `div rsi`
    // without signed sign-bit negation, fixing u64 values > INT64_MAX (e.g. 0xFFFFFFFF80000000).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_uint_to_str", off)
    x86_synth_register_helper_fn(s, "uint_to_str", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 131, 236, 48, 65, 84, 65, 85, 72, 137, 248, 76, 141, 101, 255, 65, 198, 4, 36, 0, 69, 49, 237, 72, 133, 192, 117, 16, 73, 255, 204, 65, 198, 4, 36, 48, 65, 189, 1, 0, 0, 0, 235, 32, 72, 199, 198, 10, 0, 0, 0, 72, 133, 192, 116, 20, 49, 210, 72, 247, 246, 73, 255, 204, 128, 194, 48, 65, 136, 20, 36, 65, 255, 197, 235, 231, 76, 137, 239, 72, 131, 199, 9])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [68, 137, 40, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 49, 201, 68, 57, 233, 119, 11, 65, 138, 20, 12, 136, 20, 15, 255, 193, 235, 240, 72, 137, 248, 65, 93, 65, 92, 72, 131, 196, 48, 93, 195])
    return off

fn x86_synth_emit__lipi_print_uint s
    // WHY: Native unsigned 64-bit stdout printer with newline for u8/u16/u32/u64 expressions.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_print_uint", off)
    x86_synth_register_helper_fn(s, "print_uint", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229])
    x86_synth_emit_call_helper(s, "_lipi_uint_to_str")
    x86_synth_emit_bytes(s, [72, 131, 236, 16, 139, 80, 248, 72, 137, 198, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 198, 4, 36, 10, 186, 1, 0, 0, 0, 72, 137, 230, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 131, 196, 16, 93, 195])
    return off

fn x86_synth_emit__lipi_str_sub s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_str_sub", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 65, 85, 65, 86, 65, 87, 83, 73, 137, 252, 73, 137, 245, 73, 137, 214, 77, 133, 228, 116, 116, 77, 133, 237, 121, 3, 69, 49, 237, 76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 116, 7, 69, 139, 124, 36, 248, 235, 15, 69, 49, 255, 67, 128, 60, 60, 0, 116, 5, 73, 255, 199, 235, 244, 77, 57, 254, 126, 3, 77, 137, 254, 77, 57, 245, 125, 61, 76, 137, 243, 76, 41, 235, 72, 141, 123, 9])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [137, 24, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 72, 49, 201, 72, 57, 217, 115, 16, 79, 141, 4, 44, 65, 138, 20, 8, 136, 20, 15, 72, 255, 193, 235, 235, 198, 4, 31, 0, 72, 137, 248, 235, 35, 72, 199, 199, 9, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [199, 0, 0, 0, 0, 0, 199, 64, 4, 48, 82, 84, 83, 72, 141, 120, 8, 198, 7, 0, 72, 137, 248, 91, 65, 95, 65, 94, 65, 93, 65, 92, 93, 195])
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

fn x86_synth_emit__lipi_print_float s
    // WHY: Native Silicon IEEE-754 binary64 Floating-Point Printer (handles NaN, Inf, -Inf, scientific >= 1e18 / < 1e-6).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_print_float", off)
    x86_synth_register_helper_fn(s, "print_float", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229])
    x86_synth_emit_call_helper(s, "_lipi_float_to_str")
    x86_synth_emit_bytes(s, [72, 131, 236, 16, 139, 80, 248, 72, 137, 198, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 198, 4, 36, 10, 186, 1, 0, 0, 0, 72, 137, 230, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 131, 196, 16, 93, 195])
    return off

// Multithreaded STW Safepoint GC (_lipi_gc_collect, _lipi_gc_park_self, _lipi_gc_thread_init_and_alloc_slot,
// _lipi_thread_exit, _lipi_thread_spawn_vm, _lipi_thread_spawn_joinable, _lipi_futex_wait, _lipi_user_alloc)
// are defined cleanly in runtime_mt_gc.lp.

fn x86_synth_emit__lipi_gc_live_bytes s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_gc_live_bytes", off)
    x86_synth_register_helper_fn(s, "gc_live_bytes", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    x86_synth_emit_bytes(s, [72, 139, 128, 144, 1, 0, 0, 93, 195])
    return off

fn x86_synth_emit__lipi_gc_set_threshold s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_gc_set_threshold", off)
    x86_synth_register_helper_fn(s, "gc_set_threshold", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 87, 72, 131, 236, 8])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 95, 72, 129, 255, 0, 0, 1, 0, 115, 5, 191, 0, 0, 1, 0, 72, 137, 184, 128, 1, 0, 0, 72, 137, 248, 93, 195])
    return off

fn x86_synth_emit__lipi_gc_set_auto s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_gc_set_auto", off)
    x86_synth_register_helper_fn(s, "gc_set_auto", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 87, 72, 131, 236, 8])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 95, 72, 133, 255, 116, 17, 240, 72, 15, 186, 176, 136, 1, 0, 0, 1, 184, 1, 0, 0, 0, 93, 195, 240, 72, 15, 186, 168, 136, 1, 0, 0, 1, 49, 192, 93, 195])
    return off

fn x86_synth_emit__lipi_print_nl s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_print_nl", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 131, 236, 16, 198, 4, 36, 10, 191, 1, 0, 0, 0, 72, 137, 230, 186, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 131, 196, 16, 93, 195])
    return off

fn x86_synth_emit__lipi_floor s
    // WHY: True Hardware IEEE-754 binary64 Floor Intrinsic.
    // Distinguishes IEEE-754 binary64 float bitcast from native 64-bit integer.
    // If operand is an IEEE-754 float: executes hardware SSE4.1 roundsd with floor mode (imm8=1),
    // and converts the floored float directly to 64-bit integer in %rax via cvttsd2si.
    // If operand is an integer: returns %rdi intact without truncation error.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_floor", off)
    x86_synth_register_helper_fn(s, "floor", off)
    x86_synth_register_helper_fn(s, "মেঝে", off)
    x86_synth_emit_bytes(s, [
        72, 137, 248,              // mov rax, rdi
        72, 137, 249,              // mov rcx, rdi
        72, 193, 233, 52,          // shr rcx, 52
        129, 225, 255, 7, 0, 0,    // and ecx, 0x7FF
        129, 233, 191, 3, 0, 0,    // sub ecx, 959 (0x3BF: 2^-64 exponent lower bound)
        131, 249, 127,             // cmp ecx, 127 (959..1086 covers 2^-64..2^63 floats)
        119, 16,                   // ja .ret_int (preserves all 64-bit integers >= 2^52 up to 4.318e18)
        102, 72, 15, 110, 199,     // movq xmm0, rdi
        102, 15, 58, 11, 192, 1,   // roundsd xmm0, xmm0, 1
        242, 72, 15, 44, 192,      // cvttsd2si rax, xmm0
        195                        // .ret_int: ret
    ])
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
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    // [rax] = 1, [rax+4] = STR0, [rax+8] = r12b, [rax+9] = 0; add rax, 8; pop r12; ret
    x86_synth_emit_bytes(s, [199, 0, 1, 0, 0, 0, 199, 64, 4, 48, 82, 84, 83, 68, 136, 96, 8, 198, 64, 9, 0, 72, 131, 192, 8, 65, 92, 195])
    return off

fn x86_synth_emit__lipi_char_at s
    // WHY: Native 1-character substring extractor char_at(str, idx)
    // Computes end = idx + 1 into %rdx and maintains 16-byte stack alignment around _lipi_str_sub.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_char_at", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 72, 141, 86, 1]) // push rbp; mov rbp, rsp; lea rdx, [rsi + 1]
    x86_synth_emit_call_helper(s, "_lipi_str_sub")
    x86_synth_emit_bytes(s, [93, 195]) // pop rbp; ret
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
    // WHY: Native Linux sys_exit_group (syscall nr 231) terminates the entire process & all threads cleanly with code in %rdi
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_sys_exit", off)
    // mov eax, 231; syscall; hlt; ret
    x86_synth_emit_bytes(s, [184, 231, 0, 0, 0, 15, 5, 244, 195])
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
    // WHY: Returns static 72-byte QWORD table address in page-aligned RW data segment (strict W^X safe)
    off = s.synth_code.len()
    s.synth_slab_off = off
    x86_synth_register_helper_fn(s, "_lipi_slab_buckets_ptr", off)
    // movabs rax, <rw_vaddr + 32> (patched at off + 2); ret
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 195])
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
    // WHY: Runtime sizeof fallback for dynamic values (compile-time sizeof(Type) is lowered
    // directly to exact constant mov rax, <byte_size> in codegen_expr.lp).
    // Returns 8 bytes (native 64-bit word) for scalars, or actual heap cell size when valid pointer.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_size_of", off)
    // cmp rdi, 4096; jb .scalar_word; test rdi, 7; jnz .scalar_word; mov rax, [rdi - 8]; test rax, rax; jle .scalar_word; ret; .scalar_word: mov eax, 8; ret
    x86_synth_emit_bytes(s, [
        72, 129, 255, 0, 16, 0, 0, 114, 19,
        72, 247, 199, 7, 0, 0, 0, 117, 10,
        72, 139, 71, 248, 72, 133, 192, 126, 1, 195,
        184, 8, 0, 0, 0, 195
    ])
    return off

fn x86_synth_emit__lipi_stack_pointer s
    // WHY: Introspect hardware %rsp stack pointer
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_stack_pointer", off)
    // mov rax, rsp; ret
    x86_synth_emit_bytes(s, [72, 137, 224, 195])
    return off

fn x86_synth_emit__lipi_fiber_context_switch s
    // WHY: True silicon-level cooperative context switch in System V AMD64 ABI:
    // Saves callee-saved registers (%rbp, %rbx, %r12-%r15), stores %rsp to [%rdi],
    // updates _lipi_stack_bottom ([slab+80]) to [rsi+56] whenever %rsi pivots to a stack
    // outside [cur_sb - 16MiB, cur_sb] so GC never scans across unmapped gaps,
    // restores %rsp from %rsi, and restores callee-saved registers before returning.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_fiber_context_switch", off)
    x86_synth_register_helper_fn(s, "fiber_context_switch", off)
    x86_synth_register_helper_fn(s, "fiber_switch", off)
    x86_synth_register_helper_fn(s, "ফাইবার_কনটেক্সট_সুইচ", off)
    x86_synth_emit_bytes(s, [
        85,                               // push rbp
        83,                               // push rbx
        65, 84,                           // push r12
        65, 85,                           // push r13
        65, 86,                           // push r14
        65, 87,                           // push r15
        72, 137, 39                       // mov [rdi], rsp
    ])
    x86_synth_emit_call_helper(s, "_lipi_slab_buckets_ptr")
    x86_synth_emit_bytes(s, [
        72, 139, 80, 80,                  // mov rdx, [rax + 80] (_lipi_stack_bottom)
        72, 57, 242,                      // cmp rdx, rsi
        118, 15,                          // jbe .set_sb
        72, 137, 209,                     // mov rcx, rdx
        72, 41, 241,                      // sub rcx, rsi
        72, 129, 249, 0, 0, 0, 1,         // cmp rcx, 0x1000000 (16 MiB)
        118, 8,                           // jbe .sb_ok
        72, 141, 78, 56,                  // .set_sb: lea rcx, [rsi + 56]
        72, 137, 72, 80,                  // mov [rax + 80], rcx
        72, 137, 244,                     // .sb_ok: mov rsp, rsi
        65, 95,                           // pop r15
        65, 94,                           // pop r14
        65, 93,                           // pop r13
        65, 92,                           // pop r12
        91,                               // pop rbx
        93,                               // pop rbp
        195                               // ret
    ])
    return off

fn x86_synth_emit__lipi_atomic_lock s
    // WHY: Hardware silicon atomic spinlock via lock bts with pause.
    // Offset map:
    //   0..5:   F0 48 0F BA 2F 00  -> lock bts qword ptr [rdi], 0
    //   6..7:   73 0A              -> jae +10 (8 + 10 = 18: mov rax, 1)
    //   8..9:   F3 90              -> pause
    //  10..13:  48 83 3F 00        -> cmp qword ptr [rdi], 0
    //  14..15:  75 F8              -> jne -8 (16 - 8 = 8: pause)
    //  16..17:  EB EE              -> jmp -18 (18 - 18 = 0: lock bts)
    //  18..24:  48 C7 C0 01 00 00 00 -> mov rax, 1
    //  25:      C3                 -> ret
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_atomic_lock", off)
    x86_synth_emit_bytes(s, [
        240, 72, 15, 186, 47, 0, 115, 10, 243, 144, 72, 131, 63, 0,
        117, 248, 235, 238, 72, 199, 192, 1, 0, 0, 0, 195
    ])
    return off

fn x86_synth_emit__lipi_atomic_unlock s
    // WHY: Hardware silicon atomic spinlock unlock via lock btr
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_atomic_unlock", off)
    x86_synth_emit_bytes(s, [240, 72, 15, 186, 55, 0, 72, 49, 192, 195])
    return off

fn x86_synth_emit__lipi_exc_slot_ptr s
    // WHY: Resolves per-thread exception top pointer using Linux SYS_gettid (186) + lock cmpxchg.
    // Fast L1 inline 16-slot cache at [g_exc_top + 40 .. +295], plus lazy SYS_mmap 4096-slot
    // open-addressing overflow table at [g_exc_top + 352] (rw + 456) supporting 4,112 concurrent threads.
    // Input: %r10 = &g_exc_top (rw_vaddr + 104). Output: %r10 = &thread_exc_top.
    // Preserves %rdi, %rsi, %rdx, %rcx, %rbx, %r12-%r15, %rbp.
    off = s.synth_code.len()
    s.synth_exc_slot_off = off
    x86_synth_register_helper_fn(s, "_lipi_exc_slot_ptr", off)
    x86_synth_emit_bytes(s, [
        81, 65, 82, 184, 186, 0, 0, 0, 15, 5, 65, 90, 89, 73, 137, 195,
        77, 141, 66, 40, 65, 185, 16, 0, 0, 0, 73, 139, 0, 76, 57, 216,
        15, 132, 249, 0, 0, 0, 72, 133, 192, 117, 22, 49, 192, 240, 77,
        15, 177, 24, 15, 132, 231, 0, 0, 0, 76, 57, 216, 15, 132, 222,
        0, 0, 0, 73, 131, 192, 16, 65, 255, 201, 117, 208, 77, 139, 130,
        96, 1, 0, 0, 77, 133, 192, 117, 118, 87, 86, 82, 81, 65, 82, 65,
        83, 49, 255, 190, 0, 0, 1, 0, 186, 3, 0, 0, 0, 65, 186, 34, 0,
        0, 0, 73, 199, 192, 255, 255, 255, 255, 69, 49, 201, 184, 9, 0,
        0, 0, 15, 5, 65, 91, 65, 90, 89, 90, 94, 95, 72, 61, 0, 16, 0,
        0, 15, 134, 143, 0, 0, 0, 73, 137, 193, 49, 192, 240, 77, 15,
        177, 138, 96, 1, 0, 0, 116, 36, 87, 86, 82, 81, 65, 82, 65, 83,
        80, 76, 137, 207, 190, 0, 0, 1, 0, 184, 11, 0, 0, 0, 15, 5, 65,
        88, 65, 91, 65, 90, 89, 90, 94, 95, 235, 3, 77, 137, 200, 82,
        81, 76, 137, 194, 76, 137, 216, 105, 192, 177, 121, 55, 158, 37,
        255, 15, 0, 0, 137, 193, 65, 185, 0, 16, 0, 0, 72, 137, 200, 72,
        193, 224, 4, 76, 141, 4, 2, 73, 139, 0, 76, 57, 216, 116, 35,
        72, 133, 192, 117, 14, 49, 192, 240, 77, 15, 177, 24, 116, 21,
        76, 57, 216, 116, 16, 255, 193, 129, 225, 255, 15, 0, 0, 65,
        255, 201, 117, 205, 89, 90, 195, 89, 90, 77, 141, 80, 8, 195, 195
    ])
    return off

fn x86_synth_emit__lipi_exc_push s
    // WHY: Pushes a 72-byte cross-frame exception handler onto per-thread exc_top slot.
    // Inputs: %rdi=frame_ptr, %rsi=catch_rip, %rdx=saved_rbp, %rcx=saved_rsp.
    off = s.synth_code.len()
    s.synth_exc_push_off = off
    x86_synth_register_helper_fn(s, "_lipi_exc_push", off)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 73, 137, 194])
    x86_synth_emit_call_helper(s, "_lipi_exc_slot_ptr")
    x86_synth_emit_bytes(s, [
        77, 139, 26,
        76, 137, 31,
        72, 137, 119, 8,
        72, 137, 87, 16,
        72, 137, 79, 24,
        72, 137, 95, 32,
        76, 137, 103, 40,
        76, 137, 111, 48,
        76, 137, 119, 56,
        76, 137, 127, 64,
        73, 137, 58,
        195
    ])
    return off

fn x86_synth_emit__lipi_exc_pop s
    // WHY: Pops active exception handler frame from per-thread exc_top slot on normal exit.
    off = s.synth_code.len()
    s.synth_exc_pop_off = off
    x86_synth_register_helper_fn(s, "_lipi_exc_pop", off)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 73, 137, 194])
    x86_synth_emit_call_helper(s, "_lipi_exc_slot_ptr")
    x86_synth_emit_bytes(s, [
        73, 139, 18,
        72, 133, 210,
        116, 6,
        72, 139, 18,
        73, 137, 18,
        195
    ])
    return off

fn x86_synth_emit__lipi_exc_throw s
    // WHY: Cross-frame stack unwinding throw(%rdi = err_val). Snapshots call-stack RIPs
    // into LSYM0 trace buffer before unwinding; if uncaught, prints message + full backtrace
    // to stderr (fd 2) and exits 1 cleanly via _lipi_exc_print_unhandled.
    off = s.synth_code.len()
    s.synth_exc_throw_off = off
    x86_synth_register_helper_fn(s, "_lipi_exc_throw", off)
    x86_synth_register_helper_fn(s, "exc_throw", off)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 73, 137, 194])
    x86_synth_emit_call_helper(s, "_lipi_trace_save_throw")
    x86_synth_emit_call_helper(s, "_lipi_exc_slot_ptr")
    x86_synth_emit_bytes(s, [
        73, 139, 18,
        72, 133, 210,
        116, 44,
        76, 139, 26,
        77, 137, 26,
        76, 139, 90, 8,
        72, 139, 90, 32,
        76, 139, 98, 40,
        76, 139, 106, 48,
        76, 139, 114, 56,
        76, 139, 122, 64,
        72, 139, 106, 16,
        72, 139, 98, 24,
        72, 137, 248,
        65, 255, 227
    ])
    x86_synth_emit_call_helper(s, "_lipi_exc_print_unhandled")
    x86_synth_emit_bytes(s, [191, 1, 0, 0, 0, 184, 231, 0, 0, 0, 15, 5, 244])
    return off

fn x86_synth_emit__lipi_stack_bottom s
    // WHY: Returns process initial RSP captured at _start (rw_vaddr + 112) for stack-scanning GC.
    off = s.synth_code.len()
    s.synth_stack_bottom_off = off
    x86_synth_register_helper_fn(s, "_lipi_stack_bottom", off)
    x86_synth_register_helper_fn(s, "stack_bottom", off)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 72, 139, 0, 195])
    return off

fn x86_synth_emit__lipi_heap_base s
    // WHY: Returns bump arena _heap_base (rw_vaddr + 16) for conservative GC pointer bounds.
    off = s.synth_code.len()
    s.synth_heap_base_fn_off = off
    x86_synth_register_helper_fn(s, "_lipi_heap_base", off)
    x86_synth_register_helper_fn(s, "heap_base_ptr", off)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 72, 139, 0, 195])
    return off

fn x86_synth_emit__lipi_heap_ptr s
    // WHY: Returns current bump arena watermark _heap_ptr (rw_vaddr + 24) for conservative GC bounds.
    off = s.synth_code.len()
    s.synth_heap_ptr_fn_off = off
    x86_synth_register_helper_fn(s, "_lipi_heap_ptr", off)
    x86_synth_register_helper_fn(s, "heap_curr_ptr", off)
    x86_synth_emit_bytes(s, [72, 184, 0, 0, 0, 0, 0, 0, 0, 0, 72, 139, 0, 195])
    return off

fn x86_synth_emit_all_runtime_helpers s
    // WHY: Emits all fundamental runtime helpers and registers their primary and alias names
    off__lipi_is_str = x86_synth_emit__lipi_is_str(s)
    off__lipi_len = x86_synth_emit__lipi_len(s)
    off__lipi_list_create = x86_synth_emit__lipi_list_create(s)
    off_lipi_fn_list = x86_synth_emit_lipi_fn_list(s)
    off__lipi_list_get = x86_synth_emit__lipi_list_get(s)
    off__lipi_list_set = x86_synth_emit__lipi_list_set(s)
    off__lipi_list_set_typed = x86_synth_emit__lipi_list_set_typed(s)
    off__lipi_throw_null_deref = x86_synth_emit__lipi_throw_null_deref(s)
    off__lipi_throw_null_index = x86_synth_emit__lipi_throw_null_index(s)
    off__lipi_div_by_zero = x86_synth_emit__lipi_div_by_zero(s)
    off__lipi_list_pop = x86_synth_emit__lipi_list_pop(s)
    off__lipi_list_push = x86_synth_emit__lipi_list_push(s)
    off_lipi_fn_argv = x86_synth_emit_lipi_fn_argv(s)
    off__lipi_str_concat = x86_synth_emit__lipi_str_concat(s)
    off__lipi_int_to_str = x86_synth_emit__lipi_int_to_str(s)
    off__lipi_uint_to_str = x86_synth_emit__lipi_uint_to_str(s)
    off__lipi_print_uint = x86_synth_emit__lipi_print_uint(s)
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
    off__lipi_fiber_context_switch = x86_synth_emit__lipi_fiber_context_switch(s)
    off__lipi_atomic_lock = x86_synth_emit__lipi_atomic_lock(s)
    off__lipi_atomic_unlock = x86_synth_emit__lipi_atomic_unlock(s)
    off__lipi_pass_thru = x86_synth_emit__lipi_pass_thru(s)
    off__lipi_atomic_cas = x86_synth_emit__lipi_atomic_cas(s)
    off__lipi_atomic_add = x86_synth_emit__lipi_atomic_add(s)
    off__lipi_gc_park_self = x86_synth_emit__lipi_gc_park_self(s)
    off__lipi_gc_thread_init = x86_synth_emit__lipi_gc_thread_init_and_alloc_slot(s)
    off__lipi_thread_exit = x86_synth_emit__lipi_thread_exit(s)
    off__lipi_user_alloc = x86_synth_emit__lipi_user_alloc(s)
    off__lipi_user_free = x86_synth_emit__lipi_user_free(s)
    off__lipi_float_to_str = x86_synth_emit__lipi_float_to_str(s)
    off__lipi_print_float = x86_synth_emit__lipi_print_float(s)
    off__lipi_gc_collect = x86_synth_emit__lipi_gc_collect(s)
    off__lipi_gc_live_bytes = x86_synth_emit__lipi_gc_live_bytes(s)
    off__lipi_gc_set_threshold = x86_synth_emit__lipi_gc_set_threshold(s)
    off__lipi_gc_set_auto = x86_synth_emit__lipi_gc_set_auto(s)
    off__lipi_thread_spawn_vm = x86_synth_emit__lipi_thread_spawn_vm(s)
    off__lipi_futex_wait = x86_synth_emit__lipi_futex_wait(s)
    off__lipi_futex_wake = x86_synth_emit__lipi_futex_wake(s)
    off__lipi_exc_slot_ptr = x86_synth_emit__lipi_exc_slot_ptr(s)
    off__lipi_exc_push = x86_synth_emit__lipi_exc_push(s)
    off__lipi_exc_pop = x86_synth_emit__lipi_exc_pop(s)
    off__lipi_exc_throw = x86_synth_emit__lipi_exc_throw(s)
    off__lipi_thread_spawn_joinable = x86_synth_emit__lipi_thread_spawn_joinable(s)
    off__lipi_stack_bottom = x86_synth_emit__lipi_stack_bottom(s)
    off__lipi_heap_base = x86_synth_emit__lipi_heap_base(s)
    off__lipi_heap_ptr = x86_synth_emit__lipi_heap_ptr(s)
    off__lipi_buf_new = x86_synth_emit__lipi_buf_new(s)
    off__lipi_buf_write_mem = x86_synth_emit__lipi_buf_write_mem(s)
    off__lipi_buf_write_byte = x86_synth_emit__lipi_buf_write_byte(s)
    off__lipi_buf_write_str = x86_synth_emit__lipi_buf_write_str(s)
    off__lipi_bytes_to_str = x86_synth_emit__lipi_bytes_to_str(s)
    off__lipi_buf_to_str = x86_synth_emit__lipi_buf_to_str(s)
    off__lipi_buf_len = x86_synth_emit__lipi_buf_len(s)
    off__lipi_buf_ptr = x86_synth_emit__lipi_buf_ptr(s)
    off__lipi_buf_clear = x86_synth_emit__lipi_buf_clear(s)
    off__lipi_buf_get_byte = x86_synth_emit__lipi_buf_get_byte(s)
    off__lipi_buf_free = x86_synth_emit__lipi_buf_free(s)
    off__lipi_buf_slice = x86_synth_emit__lipi_buf_slice(s)
    x86_synth_emit_all_dict_helpers(s)
    x86_synth_emit_all_trace_helpers(s)
    x86_synth_emit_all_async_helpers(s)

    // Register bilingual and standard aliases
    x86_synth_register_helper_fn(s, "move", off__lipi_pass_thru)
    x86_synth_register_helper_fn(s, "drop", off__lipi_user_free)
    x86_synth_register_helper_fn(s, "_lipi_print_float", off__lipi_print_float)
    x86_synth_register_helper_fn(s, "print_float", off__lipi_print_float)
    x86_synth_register_helper_fn(s, "_lipi_gc_collect", off__lipi_gc_collect)
    x86_synth_register_helper_fn(s, "gc_collect", off__lipi_gc_collect)
    x86_synth_register_helper_fn(s, "lipi_gc_collect", off__lipi_gc_collect)
    x86_synth_register_helper_fn(s, "gc_init", off__lipi_pass_thru)
    x86_synth_register_helper_fn(s, "আবর্জনা_পরিষ্কার", off__lipi_gc_collect)
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
    x86_synth_register_helper_fn(s, "list_push", off__lipi_list_push)
    x86_synth_register_helper_fn(s, "যোগ_করো", off__lipi_list_push)
    x86_synth_register_helper_fn(s, "pop", off__lipi_list_pop)
    x86_synth_register_helper_fn(s, "list_pop", off__lipi_list_pop)
    x86_synth_register_helper_fn(s, "বাদ_দাও", off__lipi_list_pop)
    x86_synth_register_helper_fn(s, "list_get", off__lipi_list_get)
    x86_synth_register_helper_fn(s, "list_len", off__lipi_len)
    x86_synth_register_helper_fn(s, "list_create", off_lipi_fn_list)
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

    // WHY: Builtin Memory Allocator Stubs.
    // 'malloc' delegates directly to kernel SYS_mmap (_lipi_malloc) for raw page mappings.
    // 'alloc' / 'বরাদ্দ' delegates to segregated slab recycler (_lipi_user_alloc) inside the bump heap,
    // ensuring O(1) freelist recycling with 'free' and STR0 header detection in _lipi_is_str.
    x86_synth_register_helper_fn(s, "malloc", off__lipi_malloc)
    x86_synth_register_helper_fn(s, "alloc", off__lipi_user_alloc)
    x86_synth_register_helper_fn(s, "sys_alloc", off__lipi_user_alloc)
    x86_synth_register_helper_fn(s, "mem_alloc", off__lipi_user_alloc)
    x86_synth_register_helper_fn(s, "মেমরি_বরাদ্দ", off__lipi_user_alloc)

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
    x86_synth_register_helper_fn(s, "fiber_context_switch", off__lipi_fiber_context_switch)
    x86_synth_register_helper_fn(s, "fiber_switch", off__lipi_fiber_context_switch)
    x86_synth_register_helper_fn(s, "ফাইবার_কনটেক্সট_সুইচ", off__lipi_fiber_context_switch)
    x86_synth_register_helper_fn(s, "atomic_lock", off__lipi_atomic_lock)
    x86_synth_register_helper_fn(s, "অ্যাটমিক_লক", off__lipi_atomic_lock)
    x86_synth_register_helper_fn(s, "atomic_unlock", off__lipi_atomic_unlock)
    x86_synth_register_helper_fn(s, "অ্যাটমিক_আনলক", off__lipi_atomic_unlock)
    return 0
