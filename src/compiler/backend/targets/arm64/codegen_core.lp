// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 (AARCH64) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the Abstract Syntax Tree / Token Stream directly to executable ARM64
//    (AArch64 / ARMv8-A+) silicon instructions, eliminating any dependence on external
//    assemblers or toolchains (as, gas, clang, gcc, llvm).
// 2. High-Throughput Direct Synthesis: Generates raw 32-bit fixed-width instruction words
//    in a single pass with deterministic backpatching for branch targets, string addresses,
//    loops, conditionals, structs, and inter-procedural call sites.
// 3. Implements Standard AAPCS64 (ARM 64-bit Architecture Procedure Call Standard):
//    - Strict 16-byte stack frame alignment (SP mod 16 == 0 at all times).
//    - FP (X29) / LR (X30) frame records.
//    - Fast register parameter passing in X0 through X7.
//    - Primary scalar return values delivered in X0.
// 4. Built-in Sovereign Micro-Runtime Helpers:
//    - Synthesizes high-performance integer-to-decimal ASCII conversion routines on the stack.
//    - Direct Linux AArch64 syscalls (X8=64 for SYS_write, X8=93 for SYS_exit, X8=222 for SYS_mmap).
//    - Pure ARM64 bump arena memory allocator (__alloc) with zero C runtime dependencies.
// 5. Complete Sovereign Control Flow:
//    - Synthesizes hardware jumps for while/for loops, if/elif/else branching trees,
//      break/continue jump targets, struct field manipulation, and Linux system calls.
// 6. Direct ELF64 AArch64 Container Header Generation:
//    - Emits standalone Linux ELF64 binaries with 64KB page alignment, EM_AARCH64 (183),
//      and entry point at 0x400078 with executable permissions (0755).
// ==============================================================================

import "utso/collections"
import "utso/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"

// ── 1. Data Models ────────────────────────────────────────────────────────────

// WHY: Records a 64-bit virtual memory relocation for string constants
struct Arm64StringReloc
    sr_patch_offset     // Byte index in code_bytes where the 4-instruction MOVZ/MOVK quad begins
    sr_rodata_offset    // Byte index in rodata_bytes where the UTF-8 string payload starts
    sr_reg              // Target register index (0 for X0, 1 for X1, etc.)

// WHY: Maps a local variable identifier to an SP-relative positive stack byte offset
struct Arm64LocalVar
    lv_name             // Variable identifier string
    lv_offset           // Positive stack offset in bytes: accessed as [sp, #lv_offset]
    a64_lv_struct_type      // Struct type name string for accurate field offset resolution
    a64_lv_is_boxed         // 1 if heap-boxed in an 8-byte upvalue cell for mutable closure capture
    a64_lv_is_uint          // 1 if unsigned integer type (u8/u16/u32/u64/usize)
    a64_lv_int_type         // Declared narrow int type ("u8","u16","u32","i8","i16","i32","byte") or ""
    a64_lv_prim_type        // Primitive type tag: "int", "float", "str", "dyn_tagged"
    a64_lv_tag_off          // Positive stack offset for runtime val_tag (0 if unused)

// WHY: Records a function definition entry point for inter-procedural call site resolution
struct Arm64Function
    fn_name             // Function identifier string
    fn_entry_offset     // Byte offset in code_bytes where the function prologue starts
    a64_fn_end_offset   // Byte offset in code_bytes where the function body ends (for LSYM0; unique prefix!)
    a64_fn_decl_line    // Source declaration line number (for LSYM0 stack traces; unique prefix!)

// WHY: Records an unresolved 26-bit PC-relative subroutine call displacement
struct Arm64CallReloc
    a64_cr_patch_offset     // Byte index in code_bytes where the 4-byte BL instruction is located
    a64_cr_target_name      // Target function identifier or "__print_int" / "__alloc"

// WHY: Models struct schema definitions and field member offsets
struct Arm64StructDef
    sd_name             // Struct type name string
    sd_fields           // List of field name strings

// WHY: Return container for ELF64 container synthesis results
struct Arm64ElfResult
    ew_success          // 1 on success, 0 on failure
    ew_out_path         // Destination binary path string
    ew_file_size        // Total byte count written to disk
    ew_entry_vaddr      // Absolute virtual memory entry address (0x400078 = 4194424)
    ew_error_msg        // Human-readable error diagnostic

// WHY: Encapsulates mutable compilation state for ARM64 silicon code generation
struct Arm64Synthesizer
    synth_code          // List of machine code bytes (integers 0..255)
    synth_rodata        // List of read-only data bytes (.rodata segment)
    synth_str_relocs    // List of Arm64StringReloc structs
    synth_call_relocs   // List of Arm64CallReloc structs
    synth_locals        // List of Arm64LocalVar structs for current function frame
    synth_functions     // List of Arm64Function structs
    synth_stack_offset  // Next available local variable stack offset (16, 24, 32...)
    synth_needs_print_int // Flag: 1 if integer printing helper must be emitted
    synth_print_int_off // Byte offset where print_int helper starts
    synth_loop_starts   // Stack of loop header byte offsets for 'continue'
    synth_loop_breaks   // Stack of lists of break patch offsets
    a64_pad_loop_cont   // Padding slot aligning struct indices with X86Synthesizer
    synth_structs       // List of Arm64StructDef structs
    synth_global_fields // List of global field name strings
    synth_needs_alloc   // Flag: 1 if bump allocator helper must be emitted
    synth_alloc_off     // Byte offset where bump allocator starts
    a64_alloc_rw_patch_off // Byte offset of 4-word movz/movk loading RW heap pointer base
    a64_needs_list_create // Flag: 1 if list constructor helper must be emitted
    a64_list_create_off   // Byte offset where list constructor helper starts
    a64_needs_file_write  // Flag: 1 if file_write helper must be emitted
    a64_file_write_off    // Byte offset where file_write helper starts
    a64_in_function   // 1 if currently synthesizing inside a function, 0 if top-level
    a64_try_patches   // Stack of lists of [patch_offset, kind] exception unwind patches (0=B, 1=B.NE)
    a64_sp_delta      // Temporary stack pointer displacement in bytes from push/pop pairs
    a64_for_conts     // Stack of lists of continue patch offsets for for-loop step targets
    a64_needs_list_push   // Flag: 1 if __list_push helper must be emitted
    a64_list_push_off     // Byte offset where __list_push helper starts
    a64_error_count       // Count of backend synthesis/relocation errors
    a64_error_msg         // First error diagnostic message
    a64_called_main       // 1 if top-level main()/মূল() call was emitted
    a64_last_struct       // Tracks struct type of most recently synthesized primary expression
    a64_boxed_vars        // List of local variable names mutated inside nested closures
    a64_defer_starts      // Stack of deferred statement start token indices
    a64_defer_ends        // Stack of deferred statement end token indices
    a64_emitting_defer    // Guard preventing recursive defer replay
    a64_needs_dict        // 1 if DICT0 HashMap / unified container helpers must be emitted
    a64_dict_hash_off     // Byte offset of __dict_hash
    a64_dict_eq_off       // Byte offset of __dict_key_eq
    a64_dict_new_off      // Byte offset of __dict_new
    a64_dict_set_off      // Byte offset of __dict_set
    a64_dict_get_off      // Byte offset of __dict_get
    a64_dict_has_off      // Byte offset of __dict_has
    a64_dict_del_off      // Byte offset of __dict_del
    a64_cont_get_off      // Byte offset of __container_get
    a64_cont_set_off      // Byte offset of __container_set
    a64_needs_buf         // 1 if ByteBuffer helpers must be emitted
    a64_buf_new_off       // Byte offset of __buf_new
    a64_buf_wbyte_off     // Byte offset of __buf_write_byte
    a64_buf_wstr_off      // Byte offset of __buf_write_str
    a64_buf_tostr_off     // Byte offset of __buf_to_str
    a64_freestanding      // 1 when --freestanding / --no-runtime bare-metal mode (0 Linux SVC)
    a64_enum_names        // Registered ADT variant names (Ok, Err, Some, None, + user enums)
    a64_enum_tags         // Parallel ADT integer discriminant tags
    a64_enum_arities      // Parallel ADT payload arities (0 = unit, 1+ = tuple)
    a64_next_enum_tag     // Next auto-assigned custom enum tag (starts at 2000)
    a64_cur_fn_name       // Active function name for stack_trace()
    a64_last_is_uint      // 1 if last evaluated expression is unsigned (u8/u16/u32/u64/usize)
    a64_last_expr_type    // Type of most recently evaluated expression: "int", "float", "str", "dyn_tagged"
    a64_needs_throw_null  // 1 if _lipi_throw_null_deref helper must be emitted
    a64_throw_null_off    // Byte offset of _lipi_throw_null_deref helper
    a64_needs_stack_trace // 1 if _lipi_stack_trace LSYM0 frame walker must be emitted
    a64_stack_trace_off   // Byte offset of _lipi_stack_trace helper
    a64_lsym_patch_lsym   // Code offset of MOVZ/MOVK quad for LSYM0 table vaddr
    a64_lsym_patch_code   // Code offset of MOVZ/MOVK quad for code_base vaddr
    a64_lsym_patch_ro     // Code offset of MOVZ/MOVK quad for rodata_base vaddr
    a64_needs_print_tagged // 1 if __print_str / __print_float / __print_tagged helpers must be emitted
    a64_print_str_off     // Byte offset of __print_str helper
    a64_print_float_off   // Byte offset of __print_float helper
    a64_print_tagged_off  // Byte offset of __print_tagged helper
    a64_needs_print_uint  // 1 if unsigned 64-bit __print_uint helper must be emitted
    a64_print_uint_off    // Byte offset of __print_uint helper
    a64_needs_str_helpers // 1 if __int_to_str / __uint_to_str / __str_concat / __tagged_to_str must be emitted
    a64_int_to_str_off    // Byte offset of __int_to_str helper
    a64_uint_to_str_off   // Byte offset of __uint_to_str helper
    a64_str_concat_off    // Byte offset of __str_concat helper
    a64_tagged_to_str_off // Byte offset of __tagged_to_str helper
    a64_ssa_lower_res     // Attached SsaLowerResult for direct ARM64 SSA CFG replacement
    a64_ssa_replaced_cnt  // Count of functions replaced directly from SSA CFG
    a64_ssa_replaced_bytes // Total native AAPCS64 bytes emitted directly from SSA CFG

fn arm64_is_uint_type tname
    if tname == "u8" or tname == "byte" or tname == "u16" or tname == "u32" or tname == "u64" or tname == "usize" or tname == "uint"
        return 1
    end
    return 0
end

fn arm64_is_narrow_int_type tname
    if tname == "u8" or tname == "byte" or tname == "u16" or tname == "u32" or tname == "i8" or tname == "i16" or tname == "i32"
        return 1
    end
    return 0
end

fn arm64_emit_truncate_int_width s reg tname
    // WHY: Enforces exact ARM64 bit-width wrapping/sign-extension for local u8/u16/u32/i8/i16/i32.
    if tname == "u8" or tname == "byte"
        arm64_synth_emit32(s, 3544194048 | (reg << 5) | reg) // ubfm Xd, Xd, #0, #7 (uxtb)
    elif tname == "u16"
        arm64_synth_emit32(s, 3544202240 | (reg << 5) | reg) // ubfm Xd, Xd, #0, #15 (uxth)
    elif tname == "u32"
        arm64_synth_emit32(s, 3544218624 | (reg << 5) | reg) // ubfm Xd, Xd, #0, #31 (zero-extend 32-bit)
    elif tname == "i8"
        arm64_synth_emit32(s, 2470452224 | (reg << 5) | reg) // sbfm Xd, Xd, #0, #7 (sxtb)
    elif tname == "i16"
        arm64_synth_emit32(s, 2470460416 | (reg << 5) | reg) // sbfm Xd, Xd, #0, #15 (sxth)
    elif tname == "i32"
        arm64_synth_emit32(s, 2470476800 | (reg << 5) | reg) // sbfm Xd, Xd, #0, #31 (sxtw)
    end
    return 0
end

global g_arm64_freestanding = 0
global g_arm64_base_vaddr = 4194304
global g_arm64_code_file_off = 232
global g_arm64_ssa_codegen = 0

fn arm64_synth_set_freestanding flag
    g_arm64_freestanding = flag
    return flag

fn arm64_synth_set_ssa_codegen flag
    g_arm64_ssa_codegen = flag
    return flag

fn arm64_synth_set_base_vaddr vaddr
    g_arm64_base_vaddr = vaddr
    return vaddr

fn arm64_synth_set_code_file_off off
    g_arm64_code_file_off = off
    return off

fn arm64_verify_zero_linux_svcs code_bytes
    // WHY: Bare-Metal Purity Gate for ARM64 --freestanding: scans 32-bit aligned words
    // for Linux `svc #0` (0xD4000001 -> [0x01, 0x00, 0x00, 0xD4]).
    cnt = 0
    i = 0
    n = code_bytes.len()
    while i + 3 < n
        if code_bytes[i] == 1 and code_bytes[i + 1] == 0 and code_bytes[i + 2] == 0 and code_bytes[i + 3] == 212
            cnt = cnt + 1
        end
        i = i + 4
    end
    return cnt

fn arm64_enum_register s vname tag arity
    // WHY: Preserves canonical Result/Option tags (Ok=1001, Err=1002, Some=1003, None=1004)
    // when user code redeclares `enum Res { Ok(T), Err(E) }` so postfix `?` always matches Err/None.
    i = 0
    while i < s.a64_enum_names.len()
        if s.a64_enum_names[i] == vname
            cur_tag = s.a64_enum_tags[i]
            if cur_tag >= 1001 and cur_tag <= 1004
                list_set(s.a64_enum_arities, i, arity)
                return cur_tag
            end
            list_set(s.a64_enum_tags, i, tag)
            list_set(s.a64_enum_arities, i, arity)
            return tag
        end
        i = i + 1
    end
    push(s.a64_enum_names, vname)
    push(s.a64_enum_tags, tag)
    push(s.a64_enum_arities, arity)
    return tag

fn arm64_enum_find_idx s vname
    i = 0
    while i < s.a64_enum_names.len()
        if s.a64_enum_names[i] == vname
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn arm64_emit_load_rodata_str s reg str_text
    ro_off = arm64_synth_add_rodata_str(s, str_text, 0)
    p_off = s.synth_code.len()
    arm64_emit_movz_x(s, reg, 0, 0)
    arm64_emit_movk_x(s, reg, 0, 16)
    arm64_emit_movk_x(s, reg, 0, 32)
    arm64_emit_movk_x(s, reg, 0, 48)
    srel = Arm64StringReloc()
    srel.sr_patch_offset = p_off
    srel.sr_rodata_offset = ro_off
    srel.sr_reg = reg
    push(s.synth_str_relocs, srel)
    return 0

// ── 2. Constructor & Emitter Primitives ───────────────────────────────────────

fn arm64_synth_new
    // WHY: Allocates and initializes clean ARM64 synthesizer state.
    s = Arm64Synthesizer()
    s.synth_code = list()
    s.synth_rodata = list()
    s.synth_str_relocs = list()
    s.synth_call_relocs = list()
    s.synth_locals = list()
    s.synth_functions = list()
    s.synth_stack_offset = 16
    s.synth_needs_print_int = 0
    s.synth_print_int_off = 0
    s.synth_loop_starts = list()
    s.synth_loop_breaks = list()
    s.a64_pad_loop_cont = 0
    s.synth_structs = list()
    s.synth_global_fields = list()
    s.synth_needs_alloc = 0
    s.synth_alloc_off = 0
    s.a64_alloc_rw_patch_off = 0 - 1
    s.a64_needs_list_create = 0
    s.a64_list_create_off = 0
    s.a64_needs_file_write = 0
    s.a64_file_write_off = 0
    s.a64_in_function = 0
    s.a64_try_patches = list()
    s.a64_sp_delta = 0
    s.a64_for_conts = list()
    s.a64_needs_list_push = 0
    s.a64_list_push_off = 0
    s.a64_error_count = 0
    s.a64_error_msg = ""
    s.a64_called_main = 0
    s.a64_last_struct = ""
    s.a64_boxed_vars = list()
    s.a64_defer_starts = list()
    s.a64_defer_ends = list()
    s.a64_emitting_defer = 0
    s.a64_needs_dict = 0
    s.a64_dict_hash_off = 0
    s.a64_dict_eq_off = 0
    s.a64_dict_new_off = 0
    s.a64_dict_set_off = 0
    s.a64_dict_get_off = 0
    s.a64_dict_has_off = 0
    s.a64_dict_del_off = 0
    s.a64_cont_get_off = 0
    s.a64_cont_set_off = 0
    s.a64_needs_buf = 0
    s.a64_buf_new_off = 0
    s.a64_buf_wbyte_off = 0
    s.a64_buf_wstr_off = 0
    s.a64_buf_tostr_off = 0
    s.a64_freestanding = g_arm64_freestanding
    s.a64_enum_names = list()
    s.a64_enum_tags = list()
    s.a64_enum_arities = list()
    s.a64_next_enum_tag = 2000
    s.a64_cur_fn_name = "_start"
    s.a64_last_is_uint = 0
    s.a64_last_expr_type = "int"
    s.a64_needs_throw_null = 0
    s.a64_throw_null_off = 0
    s.a64_needs_stack_trace = 0
    s.a64_stack_trace_off = 0
    s.a64_lsym_patch_lsym = 0 - 1
    s.a64_lsym_patch_code = 0 - 1
    s.a64_lsym_patch_ro = 0 - 1
    s.a64_needs_print_tagged = 0
    s.a64_print_str_off = 0
    s.a64_print_float_off = 0
    s.a64_print_tagged_off = 0
    s.a64_needs_print_uint = 0
    s.a64_print_uint_off = 0
    s.a64_needs_str_helpers = 0
    s.a64_int_to_str_off = 0
    s.a64_uint_to_str_off = 0
    s.a64_str_concat_off = 0
    s.a64_tagged_to_str_off = 0
    s.a64_ssa_lower_res = 0
    s.a64_ssa_replaced_cnt = 0
    s.a64_ssa_replaced_bytes = 0
    arm64_enum_register(s, "Ok", 1001, 1)
    arm64_enum_register(s, "Err", 1002, 1)
    arm64_enum_register(s, "Some", 1003, 1)
    arm64_enum_register(s, "None", 1004, 0)
    return s

fn arm64_synth_emit_byte s byte_val
    // WHY: Emits a single raw machine instruction byte into code_bytes.
    push(s.synth_code, (byte_val % 256 + 256) % 256)
    return s.synth_code.len()

fn arm64_synth_emit_bytes s byte_list
    // WHY: Appends an array of byte values sequentially.
    i = 0
    n = byte_list.len()
    while i < n
        push(s.synth_code, (byte_list[i] % 256 + 256) % 256)
        i = i + 1
    return s.synth_code.len()

fn arm64_synth_emit32 s inst_word
    // WHY: Emits 4 bytes in little-endian byte order for 32-bit fixed-width AArch64 instruction word.
    // In AArch64 architecture, all machine instructions are strictly 4 bytes, aligned to 4-byte boundaries.
    b0 = inst_word & 255
    b1 = (inst_word >> 8) & 255
    b2 = (inst_word >> 16) & 255
    b3 = (inst_word >> 24) & 255
    push(s.synth_code, b0)
    push(s.synth_code, b1)
    push(s.synth_code, b2)
    push(s.synth_code, b3)
    return s.synth_code.len()

fn arm64_synth_patch_u32 s offset val
    // WHY: Backpatches 4 bytes at a predetermined location in code_bytes.
    v = val
    if v < 0
        v = v + 4294967296
    list_set(s.synth_code, offset, v & 255)
    list_set(s.synth_code, offset + 1, (v >> 8) & 255)
    list_set(s.synth_code, offset + 2, (v >> 16) & 255)
    list_set(s.synth_code, offset + 3, (v >> 24) & 255)
    return 0

fn arm64_synth_patch_mov_imm64 s offset reg val
    // WHY: Patches a 4-instruction (16-byte) MOVZ + 3x MOVK sequence to load any 64-bit absolute address.
    // Resolves virtual memory relocations for string literals and global addresses.
    c0 = val & 65535
    c1 = (val >> 16) & 65535
    c2 = (val >> 32) & 65535
    c3 = (val >> 48) & 65535
    r = reg & 31
    w0 = 3531603968 | (0 << 21) | (c0 << 5) | r  // movz x<r>, #c0, lsl #0
    w1 = 4068474880 | (1 << 21) | (c1 << 5) | r  // movk x<r>, #c1, lsl #16
    w2 = 4068474880 | (2 << 21) | (c2 << 5) | r  // movk x<r>, #c2, lsl #32
    w3 = 4068474880 | (3 << 21) | (c3 << 5) | r  // movk x<r>, #c3, lsl #48
    arm64_synth_patch_u32(s, offset, w0)
    arm64_synth_patch_u32(s, offset + 4, w1)
    arm64_synth_patch_u32(s, offset + 8, w2)
    arm64_synth_patch_u32(s, offset + 12, w3)
    return 0

// ── 3. Read-Only Data (.rodata) Management ────────────────────────────────────

fn arm64_synth_add_rodata_str s str_text with_newline
    // WHY: Stores UTF-8 string payload into rodata_bytes and returns its starting offset.
    start_off = s.synth_rodata.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.synth_rodata, ord(c))
        i = i + 1
    if with_newline == 1
        push(s.synth_rodata, 10) // '\n' (ASCII 10)
    push(s.synth_rodata, 0)      // Null-terminator (ASCII 0)
    return start_off

// ── 4. ARM64 Instruction Encoders (Pure Mathematical Synthesis) ───────────────

fn arm64_emit_movz_x s reg imm16 shift
    // WHY: Emits `movz x<reg>, #<imm16>, lsl #<shift>` (0xD2800000 | (hw << 21) | (imm16 << 5) | reg).
    // Zeroes out all 64 bits of destination register and loads the 16-bit immediate into selected halfword lane.
    hw = (shift / 16) & 3
    imm = imm16 & 65535
    r = reg & 31
    word = 3531603968 | (hw << 21) | (imm << 5) | r
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_movk_x s reg imm16 shift
    // WHY: Emits `movk x<reg>, #<imm16>, lsl #<shift>` (0xF2800000 | (hw << 21) | (imm16 << 5) | reg).
    // Keeps existing register contents intact while modifying the targeted 16-bit halfword lane.
    hw = (shift / 16) & 3
    imm = imm16 & 65535
    r = reg & 31
    word = 4068474880 | (hw << 21) | (imm << 5) | r
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_mov_imm64 s reg val
    // WHY: Full 64-bit constant load using movz and movk chunks.
    // Deconstructs the 64-bit value into 4 16-bit halfwords (hw 0..3).
    // Uses MOVZ for chunk 0, and MOVK only for non-zero higher chunks to minimize code size.
    c0 = val & 65535
    c1 = (val >> 16) & 65535
    c2 = (val >> 32) & 65535
    c3 = (val >> 48) & 65535
    arm64_emit_movz_x(s, reg, c0, 0)
    if c1 != 0
        arm64_emit_movk_x(s, reg, c1, 16)
    if c2 != 0
        arm64_emit_movk_x(s, reg, c2, 32)
    if c3 != 0
        arm64_emit_movk_x(s, reg, c3, 48)
    return 0

fn arm64_emit_mov_reg s rd rm
    // WHY: MOV Xd, Xm (Hardware alias for ORR Xd, XZR, Xm: 0xAA0003E0 | (rm << 16) | rd).
    d = rd & 31
    m = rm & 31
    word = 2852127712 | (m << 16) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_add_x s rd rn rm
    // WHY: `add x<rd>, x<rn>, x<rm>` (0x8B000000 | (rm << 16) | (rn << 5) | rd).
    // Performs 64-bit integer addition without flags update.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2332033024 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_sub_x s rd rn rm
    // WHY: `sub x<rd>, x<rn>, x<rm>` (0xCB000000 | (rm << 16) | (rn << 5) | rd).
    // Performs 64-bit integer subtraction without flags update.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 3405774848 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_mul_x s rd rn rm
    // WHY: `mul x<rd>, x<rn>, x<rm>` (0x9B007C00 | (rm << 16) | (rn << 5) | rd).
    // Hardware alias for MADD Xd, Xn, Xm, XZR. Multiplies two 64-bit integers.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2600500224 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_sdiv_x s rd rn rm
    // WHY: `sdiv x<rd>, x<rn>, x<rm>` (0x9AC00C00 | (rm << 16) | (rn << 5) | rd).
    // Hardware signed 64-bit integer division. Truncates towards zero.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2596277248 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_udiv_x s rd rn rm
    // WHY: `udiv x<rd>, x<rn>, x<rm>` (0x9AC00800 | (rm << 16) | (rn << 5) | rd).
    // Hardware unsigned 64-bit integer division for u8/u16/u32/u64.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2596276224 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_and_x s rd rn rm
    // WHY: `and x<rd>, x<rn>, x<rm>` (0x8A000000).
    word = 2315255808 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_orr_x s rd rn rm
    // WHY: `orr x<rd>, x<rn>, x<rm>` (0xAA000000).
    word = 2852126720 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_orn_x s rd rn rm
    // WHY: `orn x<rd>, x<rn>, x<rm>` (0xAA200000) — use rn=31 (XZR) for bitwise NOT (`mvn`).
    word = 2854223872 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_eor_x s rd rn rm
    // WHY: `eor x<rd>, x<rn>, x<rm>` (0xCA000000).
    word = 3388997632 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_lslv_x s rd rn rm
    // WHY: `lslv x<rd>, x<rn>, x<rm>` (0x9AC02000).
    word = 2596282368 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_asrv_x s rd rn rm
    // WHY: `asrv x<rd>, x<rn>, x<rm>` (0x9AC02800).
    word = 2596284416 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_lsrv_x s rd rn rm
    // WHY: `lsrv x<rd>, x<rn>, x<rm>` (0x9AC02400) — logical right shift for unsigned types.
    word = 2596283392 | ((rm & 31) << 16) | ((rn & 31) << 5) | (rd & 31)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_cmp_x s rn rm
    // WHY: `subs xzr, x<rn>, x<rm>` (0xEB00001F | (rm << 16) | (rn << 5)).
    // Subtracts Rm from Rn, updates NZCV flags, and discards arithmetic result via XZR.
    n = rn & 31
    m = rm & 31
    word = 3942645791 | (m << 16) | (n << 5)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_b_cond s cond offset_words
    // WHY: `b.<cond>` (0x54000000 | ((offset_words & 0x7FFFF) << 5) | (cond & 0xF)).
    // Conditional branch with 19-bit signed word displacement (+/- 1MB range).
    // Conditions: EQ=0, NE=1, GE=10, LT=11, GT=12, LE=13.
    off = offset_words & 524287
    c = cond & 15
    word = 1409286144 | (off << 5) | c
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_b s offset_words
    // WHY: `b <imm26>` (0x14000000 | (offset_words & 0x3FFFFFF)).
    // Unconditional branch with 26-bit signed word displacement (+/- 128MB range).
    off = offset_words & 67108863
    word = 335544320 | off
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_bl s offset_words
    // WHY: `bl <imm26>` (0x94000000 | (offset_words & 0x3FFFFFF)).
    // Subroutine procedure call: branches and records next instruction address into Link Register (X30).
    off = offset_words & 67108863
    word = 2483027968 | off
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_ret s
    // WHY: `ret x30` (0xD65F03C0).
    // Returns control flow to subroutine caller using Link Register address in X30.
    arm64_synth_emit32(s, 3596551104)
    return 0

fn arm64_emit_stp_pre s rt1 rt2 rn imm7
    // WHY: `stp x<rt1>, x<rt2>, [x<rn>, #imm7]!` (0xA9800000 | (((imm7 / 8) & 0x7F) << 15) | (rt2 << 10) | (rn << 5) | rt1).
    // Pre-indexed store pair with writeback. Decrements base pointer and stores register pair.
    t1 = rt1 & 31
    t2 = rt2 & 31
    n = rn & 31
    scaled = (imm7 / 8) & 127
    word = 2843738112 | (scaled << 15) | (t2 << 10) | (n << 5) | t1
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_ldp_post s rt1 rt2 rn imm7
    // WHY: `ldp x<rt1>, x<rt2>, [x<rn>], #imm7` (0xA8C00000 | (((imm7 / 8) & 0x7F) << 15) | (rt2 << 10) | (rn << 5) | rt1).
    // Post-indexed load pair with writeback. Loads register pair and increments base pointer.
    t1 = rt1 & 31
    t2 = rt2 & 31
    n = rn & 31
    scaled = (imm7 / 8) & 127
    word = 2831155200 | (scaled << 15) | (t2 << 10) | (n << 5) | t1
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_str_reg_sp s rt sp_offset
    // WHY: `str x<rt>, [sp, #<sp_offset + a64_sp_delta>]` adjusting automatically for pushed temporaries.
    t = rt & 31
    eff_off = sp_offset + s.a64_sp_delta
    scaled = (eff_off / 8) & 4095
    word = 4177526784 | (scaled << 10) | (31 << 5) | t
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_ldr_reg_sp s rt sp_offset
    // WHY: `ldr x<rt>, [sp, #<sp_offset + a64_sp_delta>]` adjusting automatically for pushed temporaries.
    t = rt & 31
    eff_off = sp_offset + s.a64_sp_delta
    scaled = (eff_off / 8) & 4095
    word = 4181721088 | (scaled << 10) | (31 << 5) | t
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_svc s imm16
    // WHY: `svc #<imm16>` (0xD4000001 | ((imm16 & 0xFFFF) << 5)).
    // Supervisor Call instruction triggering hardware exception to enter Linux kernel syscall handler.
    imm = imm16 & 65535
    word = 3556769793 | (imm << 5)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_push_reg s reg
    // WHY: Pushes 64-bit register Xt onto stack (pre-index: str Xt, [sp, #-16]!).
    // Maintains mandatory AAPCS64 16-byte stack alignment and tracks SP shift.
    r = reg & 31
    arm64_synth_emit32(s, 4162785248 | r)
    s.a64_sp_delta = s.a64_sp_delta + 16
    return 0

fn arm64_pop_reg s reg
    // WHY: Pops 64-bit register Xt from stack (post-index: ldr Xt, [sp], #16).
    // Restores register operand and reverses tracked SP shift.
    r = reg & 31
    arm64_synth_emit32(s, 4165011424 | r)
    if s.a64_sp_delta >= 16
        s.a64_sp_delta = s.a64_sp_delta - 16
    else
        s.a64_sp_delta = 0
    end
    return 0

fn arm64_emit_prologue s
    // WHY: Standard AAPCS64 Procedure Call Standard stack frame setup:
    // 1. stp x29, x30, [sp, #-16]!  (0xA9BF7BFD = 2847898621) - Saves FP & LR on stack
    // 2. mov x29, sp                (0x910003FD = 2432697341) - Establishes new Frame Pointer
    // 3. sub sp, sp, #2048          (0xD12003FF = 3508536319) - Allocates 2KB local stack space
    arm64_synth_emit32(s, 2847898621)
    arm64_synth_emit32(s, 2432697341)
    arm64_synth_emit32(s, 3508536319)
    return 0

fn arm64_emit_epilogue s
    // WHY: Standard AAPCS64 stack frame teardown:
    // 1. mov sp, x29                (0x910003BF = 2432697279) - Collapses local variable frame
    // 2. ldp x29, x30, [sp], #16    (0xA8C17BFD = 2831252477) - Restores Frame Pointer and Link Register
    // 3. ret                        (0xD65F03C0 = 3596551104) - Returns to caller via Link Register X30
    arm64_synth_emit32(s, 2432697279)
    arm64_emit_ldp_post(s, 29, 30, 31, 16)
    arm64_emit_ret(s)
    return 0

fn arm64_emit_print_string s str_val
    // WHY: Emits Linux AArch64 SYS_write(1, &str, len) for string literals:
    //      - X0 = 1 (STDOUT_FILENO)
    //      - X1 = Virtual address of UTF-8 string payload in .rodata
    //      - X2 = Byte length including appended newline
    //      - X8 = 64 (Linux AArch64 SYS_write)
    //      - SVC #0
    ro_off = arm64_synth_add_rodata_str(s, str_val, 1)
    str_len = len(str_val) + 1 // Includes appended newline

    // mov x0, 1 (STDOUT)
    arm64_emit_movz_x(s, 0, 1, 0)

    // mov x1, <rodata_vaddr> (16-byte MOVZ/MOVK quad, backpatched after code assembly)
    patch_pos = s.synth_code.len()
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_movk_x(s, 1, 0, 16)
    arm64_emit_movk_x(s, 1, 0, 32)
    arm64_emit_movk_x(s, 1, 0, 48)

    rel = Arm64StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    rel.sr_reg = 1
    push(s.synth_str_relocs, rel)

    // mov x2, str_len
    arm64_emit_mov_imm64(s, 2, str_len)

    // mov x8, 64 (SYS_write on Linux AArch64)
    arm64_emit_movz_x(s, 8, 64, 0)

    // svc #0
    arm64_emit_svc(s, 0)
    return 0

// ── 5. Micro-Runtime Helpers ──────────────────────────────────────────────────

fn arm64_synth_emit_call_print_int s
    // WHY: Emits subroutine call to the centralized __print_int helper to display integer in X0.
    s.synth_needs_print_int = 1
    call_off = s.synth_code.len()
    arm64_emit_bl(s, 0) // Placeholder 26-bit call displacement

    call_rel = Arm64CallReloc()
    call_rel.a64_cr_patch_offset = call_off
    call_rel.a64_cr_target_name = "__print_int"
    push(s.synth_call_relocs, call_rel)
    return 0

fn arm64_synth_emit_call_print_uint s
    // WHY: Emits subroutine call to the centralized __print_uint helper to display unsigned u64 in X0.
    s.a64_needs_print_uint = 1
    call_off = s.synth_code.len()
    arm64_emit_bl(s, 0)
    call_rel = Arm64CallReloc()
    call_rel.a64_cr_patch_offset = call_off
    call_rel.a64_cr_target_name = "__print_uint"
    push(s.synth_call_relocs, call_rel)
    return 0

fn arm64_synth_emit_print_int_helper s
    // WHY: Pure ARM64 assembly routine converting 64-bit signed integer in X0
    // to ASCII decimal string on the stack and writing to STDOUT with trailing newline.
    // Uses dynamic branch patching + udiv so positive, zero, negative, and INT64_MIN all print accurately.
    s.synth_print_int_off = s.synth_code.len()

    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 48)
    arm64_synth_emit32(s, 2432697341) // mov x29, sp

    // Buffer is built backwards starting at [sp + 47]
    arm64_emit_movz_x(s, 1, 10, 0)    // '\n'
    arm64_synth_emit32(s, 2432745442) // add x2, sp, #47
    arm64_synth_emit32(s, 956301377)  // strb w1, [x2, #0]
    arm64_emit_mov_reg(s, 1, 2)       // X1 = buffer cursor
    arm64_emit_movz_x(s, 2, 1, 0)     // X2 = byte count (1)

    arm64_emit_cmp_x(s, 0, 31)
    bne_check_neg = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)        // b.ne .check_neg

    // Special case: X0 == 0
    arm64_synth_emit32(s, 3506439201) // sub x1, x1, #1
    arm64_emit_movz_x(s, 3, 48, 0)    // '0'
    arm64_synth_emit32(s, 956301347)  // strb w3, [x1, #0]
    arm64_synth_emit32(s, 2432697410) // add x2, x2, #1
    b_zero_write = s.synth_code.len()
    arm64_emit_b(s, 0)                // b .do_write

    // .check_neg:
    check_neg_off = s.synth_code.len()
    arm64_synth_patch_u32(s, bne_check_neg, 1409286144 | ((((check_neg_off - bne_check_neg) / 4) & 524287) << 5) | 1)
    arm64_emit_movz_x(s, 9, 0, 0)     // negative flag = 0
    arm64_emit_cmp_x(s, 0, 31)
    bge_loop_dig = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)       // b.ge .loop_digits
    arm64_emit_movz_x(s, 9, 1, 0)     // negative flag = 1
    arm64_synth_emit32(s, 3405775840) // sub x0, xzr, x0 (negate; INT64_MIN becomes 2^63 unsigned)

    // .loop_digits:
    loop_dig_off = s.synth_code.len()
    arm64_synth_patch_u32(s, bge_loop_dig, 1409286144 | ((((loop_dig_off - bge_loop_dig) / 4) & 524287) << 5) | 10)
    arm64_emit_cmp_x(s, 0, 31)
    beq_finish_dig = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)        // b.eq .finish_digits
    arm64_emit_movz_x(s, 10, 10, 0)   // divisor = 10
    arm64_emit_udiv_x(s, 11, 0, 10)   // unsigned quotient (handles 2^63 for INT64_MIN!)
    arm64_emit_mul_x(s, 12, 11, 10)
    arm64_emit_sub_x(s, 12, 0, 12)    // remainder = X0 % 10
    arm64_synth_emit32(s, 2432745868) // add x12, x12, #48
    arm64_synth_emit32(s, 3506439201) // sub x1, x1, #1
    arm64_synth_emit32(s, 956301356)  // strb w12, [x1, #0]
    arm64_synth_emit32(s, 2432697410) // add x2, x2, #1
    arm64_emit_mov_reg(s, 0, 11)      // X0 = quotient
    arm64_emit_b(s, (loop_dig_off - s.synth_code.len()) / 4)

    // .finish_digits:
    finish_dig_off = s.synth_code.len()
    arm64_synth_patch_u32(s, beq_finish_dig, 1409286144 | ((((finish_dig_off - beq_finish_dig) / 4) & 524287) << 5) | 0)
    arm64_emit_movz_x(s, 3, 1, 0)
    arm64_emit_cmp_x(s, 9, 3)
    bne_do_write = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)        // b.ne .do_write
    arm64_synth_emit32(s, 3506439201) // sub x1, x1, #1
    arm64_emit_movz_x(s, 3, 45, 0)    // '-'
    arm64_synth_emit32(s, 956301347)  // strb w3, [x1, #0]
    arm64_synth_emit32(s, 2432697410) // add x2, x2, #1

    // .do_write:
    do_write_off = s.synth_code.len()
    arm64_synth_patch_u32(s, b_zero_write, 335544320 | (((do_write_off - b_zero_write) / 4) & 67108863))
    arm64_synth_patch_u32(s, bne_do_write, 1409286144 | ((((do_write_off - bne_do_write) / 4) & 524287) << 5) | 1)
    arm64_emit_movz_x(s, 0, 1, 0)     // STDOUT_FILENO = 1
    arm64_emit_movz_x(s, 8, 64, 0)    // SYS_write on Linux AArch64
    arm64_emit_svc(s, 0)

    // Epilogue:
    arm64_synth_emit32(s, 2432697279) // mov sp, x29
    arm64_emit_ldp_post(s, 29, 30, 31, 48)
    arm64_emit_ret(s)
    return 0

fn arm64_synth_emit_print_uint_helper s
    // WHY: Pure ARM64 unsigned 64-bit integer decimal printer (0 .. 18446744073709551615) via UDIV.
    s.a64_print_uint_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 48)
    arm64_synth_emit32(s, 2432697341) // mov x29, sp

    arm64_emit_movz_x(s, 1, 10, 0)    // '\n'
    arm64_synth_emit32(s, 2432745442) // add x2, sp, #47
    arm64_synth_emit32(s, 956301377)  // strb w1, [x2, #0]
    arm64_emit_mov_reg(s, 1, 2)
    arm64_emit_movz_x(s, 2, 1, 0)

    arm64_emit_cmp_x(s, 0, 31)
    bne_u_loop = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_synth_emit32(s, 3506439201) // sub x1, x1, #1
    arm64_emit_movz_x(s, 3, 48, 0)    // '0'
    arm64_synth_emit32(s, 956301347)  // strb w3, [x1, #0]
    arm64_synth_emit32(s, 2432697410) // add x2, x2, #1
    b_u_write = s.synth_code.len()
    arm64_emit_b(s, 0)

    u_loop_off = s.synth_code.len()
    arm64_synth_patch_u32(s, bne_u_loop, 1409286144 | ((((u_loop_off - bne_u_loop) / 4) & 524287) << 5) | 1)
    arm64_emit_cmp_x(s, 0, 31)
    beq_u_write = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 10, 10, 0)
    arm64_emit_udiv_x(s, 11, 0, 10)
    arm64_emit_mul_x(s, 12, 11, 10)
    arm64_emit_sub_x(s, 12, 0, 12)
    arm64_synth_emit32(s, 2432745868) // add x12, x12, #48
    arm64_synth_emit32(s, 3506439201) // sub x1, x1, #1
    arm64_synth_emit32(s, 956301356)  // strb w12, [x1, #0]
    arm64_synth_emit32(s, 2432697410) // add x2, x2, #1
    arm64_emit_mov_reg(s, 0, 11)
    arm64_emit_b(s, (u_loop_off - s.synth_code.len()) / 4)

    u_write_off = s.synth_code.len()
    arm64_synth_patch_u32(s, b_u_write, 335544320 | (((u_write_off - b_u_write) / 4) & 67108863))
    arm64_synth_patch_u32(s, beq_u_write, 1409286144 | ((((u_write_off - beq_u_write) / 4) & 524287) << 5) | 0)
    arm64_emit_movz_x(s, 0, 1, 0)
    arm64_emit_movz_x(s, 8, 64, 0)
    arm64_emit_svc(s, 0)

    arm64_synth_emit32(s, 2432697279)
    arm64_emit_ldp_post(s, 29, 30, 31, 48)
    arm64_emit_ret(s)
    return 0

fn arm64_synth_emit_call_alloc s
    // WHY: Emits subroutine call to the native __alloc bump allocator.
    s.synth_needs_alloc = 1
    call_off = s.synth_code.len()
    arm64_emit_bl(s, 0) // Placeholder

    call_rel = Arm64CallReloc()
    call_rel.a64_cr_patch_offset = call_off
    call_rel.a64_cr_target_name = "__alloc"
    push(s.synth_call_relocs, call_rel)
    return 0

fn arm64_synth_emit_alloc_helper s
    // WHY: Emits pure W^X ARM64 silicon bump-arena memory allocator (0% RWE, zero self-modifying code).
    // Reads/writes _heap_ptr inside the RW .data segment patched via s.a64_alloc_rw_patch_off.
    // Inputs: X0 = requested byte size. Output: X0 = pointer to allocated memory.
    s.synth_alloc_off = s.synth_code.len()

    // 0: add x0, x0, #15 (0x91003C00 = 2432711680) -> round up for 16-byte alignment (fixes <13B zero-bump!)
    arm64_synth_emit32(s, 2432711680)
    // 1: movz x1, 15, 0
    arm64_emit_movz_x(s, 1, 15, 0)
    // 2: bic x0, x0, x1 (0x8A210000 = 2317418496) -> align to 16 bytes (rm=1, NOT rm=2!)
    arm64_synth_emit32(s, 2317418496)
    // 3..6: movz/movk x1, RW_DATA_VADDR (_heap_ptr slot in strict RW segment, patched by linker)
    s.a64_alloc_rw_patch_off = s.synth_code.len()
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_movk_x(s, 1, 0, 16)
    arm64_emit_movk_x(s, 1, 0, 32)
    arm64_emit_movk_x(s, 1, 0, 48)
    // 7: ldr x2, [x1, #0]
    arm64_synth_emit32(s, 4181721122)
    // 8: cmp x2, xzr
    arm64_emit_cmp_x(s, 2, 31)
    // 9: b.ne .bump (patched dynamically)
    bne_patch_off = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)

    // Heap initialization via Linux sys_mmap(NULL, 64MB, PROT_READ|WRITE, MAP_ANON|PRIVATE, -1, 0)
    arm64_emit_stp_pre(s, 0, 1, 31, 0 - 16)
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 16)
    arm64_emit_movz_x(s, 0, 0, 0)
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_movk_x(s, 1, 1024, 16) // 64MB virtual memory arena
    arm64_emit_movz_x(s, 2, 3, 0)     // PROT_READ | PROT_WRITE
    arm64_emit_movz_x(s, 3, 34, 0)    // MAP_PRIVATE | MAP_ANONYMOUS
    arm64_synth_emit32(s, 2457862148) // MOVN X4, #0 (fd = -1)
    arm64_emit_movz_x(s, 5, 0, 0)     // offset = 0
    arm64_emit_movz_x(s, 8, 222, 0)   // Linux AArch64 SYS_mmap = 222
    arm64_emit_svc(s, 0)
    arm64_emit_ldp_post(s, 29, 30, 31, 16)
    arm64_emit_ldp_post(s, 3, 1, 31, 16)
    // str x0, [x1, #0]
    arm64_synth_emit32(s, 4177526816)
    arm64_emit_mov_reg(s, 2, 0)
    arm64_emit_mov_reg(s, 0, 3)

    // .bump:
    bump_off = s.synth_code.len()
    rel_words = (bump_off - bne_patch_off) / 4
    arm64_synth_patch_u32(s, bne_patch_off, 1409286144 | ((rel_words & 524287) << 5) | 1)

    // ldr x2, [x1, #0]; add x3, x2, x0; str x3, [x1, #0]; mov x0, x2; ret
    arm64_synth_emit32(s, 4181721122)
    arm64_emit_add_x(s, 3, 2, 0)
    arm64_synth_emit32(s, 4177526819)
    arm64_emit_mov_reg(s, 0, 2)
    arm64_emit_ret(s)
    return 0

// ── 6. Parser Utilities, Symbol Table & Scoping ───────────────────────────────

fn arm64_synth_skip_whitespace_tokens toks pos_box
    // WHY: Advances token pointer past any empty newlines or comments.
    while get(pos_box, 0) < toks.len()
        k = toks[get(pos_box, 0)].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        else
            break
    return 0

fn arm64_synth_find_fn s fname
    // WHY: Checks whether a user-defined function shadows an optional DICT0 map_* intrinsic.
    i = 0
    while i < s.synth_functions.len()
        if s.synth_functions[i].fn_name == fname
            return s.synth_functions[i]
        i = i + 1
    return 0

fn arm64_synth_find_struct s sname
    // WHY: Finds struct definition metadata by struct type name.
    i = 0
    while i < s.synth_structs.len()
        if s.synth_structs[i].sd_name == sname
            return s.synth_structs[i]
        i = i + 1
    return 0

fn arm64_synth_get_field_offset s sname fname
    // WHY: Resolves the 8-byte scaled offset of struct field fname.
    if sname != ""
        sdef = arm64_synth_find_struct(s, sname)
        if sdef != 0
            f = 0
            while f < sdef.sd_fields.len()
                if sdef.sd_fields[f] == fname
                    return f * 8
                f = f + 1

    // Fallback: search across all defined structs
    i = 0
    while i < s.synth_structs.len()
        cur_def = s.synth_structs[i]
        f = 0
        while f < cur_def.sd_fields.len()
            if cur_def.sd_fields[f] == fname
                return f * 8
            f = f + 1
        i = i + 1

    // Fallback 2: search global fields registry
    gi = 0
    while gi < s.synth_global_fields.len()
        if s.synth_global_fields[gi] == fname
            return gi * 8
        gi = gi + 1
    push(s.synth_global_fields, fname)
    return (s.synth_global_fields.len() - 1) * 8

fn arm64_synth_lookup_var s name
    // WHY: Finds SP-relative stack offset for variable identifier. Returns 0 if not found.
    i = 0
    while i < s.synth_locals.len()
        lv = s.synth_locals[i]
        if lv.lv_name == name
            return lv.lv_offset
        i = i + 1
    return 0

fn arm64_synth_alloc_var s name
    // WHY: Allocates next 8-byte stack slot for variable name or returns existing offset.
    existing = arm64_synth_lookup_var(s, name)
    if existing > 0
        return existing
    off = s.synth_stack_offset
    s.synth_stack_offset = s.synth_stack_offset + 8
    lv = Arm64LocalVar()
    lv.lv_name = name
    lv.lv_offset = off
    lv.a64_lv_struct_type = ""
    lv.a64_lv_is_boxed = arm64_is_boxed_name(s, name)
    lv.a64_lv_is_uint = 0
    lv.a64_lv_int_type = ""
    lv.a64_lv_prim_type = "int"
    lv.a64_lv_tag_off = 0
    push(s.synth_locals, lv)
    return off

fn arm64_synth_alloc_tag_slot s lv
    // WHY: Lazily allocates an 8-byte runtime val_tag stack slot for dyn_tagged variables.
    if lv == 0
        return 0
    end
    if lv.a64_lv_tag_off > 0
        return lv.a64_lv_tag_off
    end
    off = s.synth_stack_offset
    s.synth_stack_offset = s.synth_stack_offset + 8
    lv.a64_lv_tag_off = off
    return off

fn arm64_synth_rodata_push_u32 s val
    v = val
    if v < 0
        v = v + 4294967296
    end
    push(s.synth_rodata, v % 256)
    push(s.synth_rodata, (v / 256) % 256)
    push(s.synth_rodata, (v / 65536) % 256)
    push(s.synth_rodata, (v / 16777216) % 256)
    return 0

fn arm64_synth_emit_lsym_rodata s
    // WHY: Serializes x86_64-identical LSYM0 symbol table ("LIPLSYM0") into ARM64 .rodata
    // so stack_trace()/backtrace() resolves full call chains with real function names & line numbers.
    fn_starts = list()
    fn_ends = list()
    fn_name_offs = list()
    fn_lines = list()
    fi = 0
    while fi < s.synth_functions.len()
        fobj = s.synth_functions[fi]
        if fobj.fn_entry_offset >= 0 and fobj.a64_fn_end_offset > fobj.fn_entry_offset and fobj.fn_name != ""
            n_ro = arm64_synth_add_rodata_str(s, fobj.fn_name, 0)
            push(fn_starts, fobj.fn_entry_offset)
            push(fn_ends, fobj.a64_fn_end_offset)
            push(fn_name_offs, n_ro)
            push(fn_lines, fobj.a64_fn_decl_line)
        end
        fi = fi + 1
    end
    while (s.synth_rodata.len() % 8) != 0
        push(s.synth_rodata, 0)
    end
    lsym_off = s.synth_rodata.len()
    // Magic: "LIPLSYM0"
    push(s.synth_rodata, 76)
    push(s.synth_rodata, 73)
    push(s.synth_rodata, 80)
    push(s.synth_rodata, 76)
    push(s.synth_rodata, 83)
    push(s.synth_rodata, 89)
    push(s.synth_rodata, 77)
    push(s.synth_rodata, 48)
    fcnt = fn_starts.len()
    arm64_synth_rodata_push_u32(s, fcnt)
    arm64_synth_rodata_push_u32(s, 0)
    i = 0
    while i < fcnt
        arm64_synth_rodata_push_u32(s, fn_starts[i])
        arm64_synth_rodata_push_u32(s, fn_ends[i])
        arm64_synth_rodata_push_u32(s, fn_name_offs[i])
        arm64_synth_rodata_push_u32(s, fn_lines[i])
        arm64_synth_rodata_push_u32(s, 0)
        arm64_synth_rodata_push_u32(s, 0)
        i = i + 1
    end
    return lsym_off

fn arm64_synth_set_var_struct s name sname
    i = 0
    while i < s.synth_locals.len()
        if s.synth_locals[i].lv_name == name
            s.synth_locals[i].a64_lv_struct_type = sname
            return 0
        i = i + 1
    return 0

fn arm64_synth_get_var_struct s name
    i = 0
    while i < s.synth_locals.len()
        if s.synth_locals[i].lv_name == name
            return s.synth_locals[i].a64_lv_struct_type
        i = i + 1
    return ""

fn arm64_is_ident_token kind
    if kind == TOK_IDENT() return 1
    if kind == TOK_KW_END() return 1
    if kind == TOK_KW_IN() return 1
    if kind == TOK_KW_TYPE() return 1
    if kind == TOK_KW_CASE() return 1
    if kind == TOK_KW_MATCH() return 1
    if kind == TOK_KW_MUT() return 1
    if kind == TOK_KW_ASYNC() return 1
    if kind == TOK_KW_AWAIT() return 1
    if kind == TOK_KW_TRY() return 1
    if kind == TOK_KW_CATCH() return 1
    if kind == TOK_KW_DEFER() return 1
    if kind == TOK_KW_PRINT() return 1
    if kind == TOK_KW_SYSCALL() return 1
    return 0

fn arm64_parse_float_bits s_text
    // WHY: Converts floating-point string literal (including scientific notation like 1.5e-4 or 2E10)
    // directly into standard IEEE-754 binary64 64-bit integer bit representation.
    s_len = len(s_text)
    if s_len == 0
        return 0
    end

    sign = 0
    start = 0
    c0 = char_at(s_text, 0)
    if c0 == "-"
        sign = 1
        start = 1
    elif c0 == "+"
        start = 1
    end

    int_part = 0
    frac_part = 0
    frac_digits = 0
    dot_seen = 0
    exp_seen = 0
    exp_neg = 0
    exp_val = 0

    idx = start
    while idx < s_len
        c = char_at(s_text, idx)
        if c == "." and exp_seen == 0
            dot_seen = 1
        elif c == "e" or c == "E"
            exp_seen = 1
            if idx + 1 < s_len
                nc = char_at(s_text, idx + 1)
                if nc == "-"
                    exp_neg = 1
                    idx = idx + 1
                elif nc == "+"
                    idx = idx + 1
                end
            end
        else
            code = ord(c)
            if code >= 48 and code <= 57
                d = code - 48
                if exp_seen == 1
                    if exp_val < 1000
                        exp_val = (exp_val * 10) + d
                    end
                elif dot_seen == 0
                    if int_part < 90000000000000000
                        int_part = (int_part * 10) + d
                    else
                        exp_val = exp_val + 1
                    end
                else
                    if frac_digits < 17 and frac_part < 90000000000000000
                        frac_part = (frac_part * 10) + d
                        frac_digits = frac_digits + 1
                    end
                end
            end
        end
        idx = idx + 1
    end

    if exp_neg == 1
        exp_val = 0 - exp_val
    end

    if int_part == 0 and frac_part == 0
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end

    exp10 = exp_val - frac_digits
    num = int_part
    k = 0
    while k < frac_digits
        num = num * 10
        k = k + 1
    end
    num = num + frac_part
    den = 1
    exp = 1023

    if exp10 > 320
        res = 2047 * 4503599627370496
        if sign == 1
            res = res + 9223372036854775808
        end
        return res
    end
    if exp10 < (0 - 340)
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end

    while exp10 > 0
        while num >= 450359962737049600
            num = num / 2
            exp = exp + 1
        end
        num = num * 10
        exp10 = exp10 - 1
    end
    while exp10 < 0
        while den >= 450359962737049600
            den = den / 2
            exp = exp - 1
        end
        den = den * 10
        exp10 = exp10 + 1
    end

    while num >= (den * 2)
        den = den * 2
        exp = exp + 1
    end
    while num < den
        num = num * 2
        exp = exp - 1
    end

    if exp >= 2047
        res = 2047 * 4503599627370496
        if sign == 1
            res = res + 9223372036854775808
        end
        return res
    end
    if exp <= 0
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end

    rem = num - den
    mantissa = 0
    b = 0
    while b < 52
        rem = rem * 2
        bit = 0
        if rem >= den
            bit = 1
            rem = rem - den
        end
        mantissa = (mantissa * 2) + bit
        b = b + 1
    end

    rem = rem * 2
    if rem >= den
        mantissa = mantissa + 1
        if mantissa >= 4503599627370496
            mantissa = 0
            exp = exp + 1
        end
    end

    res = (exp * 4503599627370496) + mantissa
    if sign == 1
        res = res + 9223372036854775808
    end
    return res

