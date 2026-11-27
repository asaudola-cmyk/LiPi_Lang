// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64-BIT (RV64) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/riscv64/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Direct Silicon RV64 Synthesis:
//    Compiles LiPi AST / token streams directly into native 64-bit RISC-V (RV64I/M)
//    machine instructions, bypassing GCC, Clang, LLVM, GNU as, or any external toolchain.
// 2. 100% Sovereign Invariant:
//    Zero C, Zero Libc, Zero External Toolchains. Pure LiPi First 1.0.0 implementation.
// 3. Implements Standard RISC-V LP64 ABI:
//    - Strict 16-byte stack frame alignment (sp mod 16 == 0 at all times).
//    - Preserved Frame Pointer (s0/fp = x8) and Return Address (ra = x1).
//    - Standard register parameter passing in a0..a7 (x10..x17).
//    - Scalar return values delivered in a0 (x10).
// 4. Built-in Sovereign Micro-Runtime Helpers:
//    - Pure RV64 assembly routine for integer-to-decimal ASCII conversion with trailing newline.
//    - Direct Linux RISC-V syscalls (a7=64 for SYS_write, a7=93 for SYS_exit, a7=222 for SYS_mmap).
//    - Pure RISC-V bump arena memory allocator (__alloc) with 1GB virtual memory arena.
// 5. Complete Sovereign Control Flow:
//    - Synthesizes hardware jumps for while/for loops, if/elif/else branching trees,
//      break/continue jump targets, struct field manipulation, and Linux system calls.
// 6. Direct ELF64 RISC-V Container Header Generation:
//    - Emits standalone Linux ELF64 binaries with 64KB page alignment, EM_RISCV (243 = 0x00F3),
//      and entry point at 0x400078 with executable permissions (0755).
// 7. Namespaced Structural Isolation:
//    - All struct fields use strict unique prefixes ('rv_*') to completely avoid
//      global struct field offset collisions with X86Synthesizer and Arm64Synthesizer.
// ==============================================================================

import "utso/collections"
import "utso/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"
import "compiler/frontend/lexer/tokenizer"

include "src/compiler/backend/targets/riscv64/registers.lp"
include "src/compiler/backend/targets/riscv64/r_i_s_u_b_formats.lp"

// ── 1. Data Models ────────────────────────────────────────────────────────────

// WHY: Records a 64-bit virtual memory relocation for string constants
struct Riscv64StringReloc
    rv_sr_patch_offset     // Byte index in rv_code where the 2-instruction LUI/ADDI pair begins
    rv_sr_rodata_offset    // Byte index in rv_rodata where the UTF-8 string payload starts
    rv_sr_reg              // Target register index (10 for a0, 11 for a1, etc.)

// WHY: Maps a local variable identifier to an SP-relative positive stack byte offset
struct Riscv64LocalVar
    rv_lv_name             // Variable identifier string
    rv_lv_offset           // Positive stack offset in bytes: accessed as [sp + rv_lv_offset]
    rv_lv_is_boxed         // 1 if heap-boxed in an 8-byte upvalue cell for mutable closure capture
    rv_lv_is_uint          // 1 if unsigned integer type (u8/u16/u32/u64/usize)
    rv_lv_int_type         // Declared narrow int type ("u8","u16","u32","i8","i16","i32","byte") or ""
    rv_lv_prim_type        // Primitive type tag: "int", "float", "str", "dyn_tagged"
    rv_lv_tag_off          // Positive stack offset for runtime val_tag (0 if unused)
    rv_lv_struct_type      // Struct/union type name string for accurate field & method resolution

// WHY: Records a function definition entry point for inter-procedural call site resolution
struct Riscv64Function
    rv_fn_name             // Function identifier string
    rv_fn_entry_offset     // Byte offset in rv_code where the function prologue starts
    rv_fn_end_offset       // Byte offset in rv_code where the function body ends (for LSYM0)
    rv_fn_decl_line        // Source declaration line number (for LSYM0 stack traces)

// WHY: Records an unresolved 20-bit PC-relative subroutine call displacement
struct Riscv64CallReloc
    rv_cr_patch_offset     // Byte index in rv_code where the 4-byte JAL instruction is located
    rv_cr_target_name      // Target function identifier or "__print_int" / "__alloc"

// WHY: Models struct/union schema definitions, field types, union layout flag, and runtime type tag ID
struct Riscv64StructDef
    rv_sd_name             // Struct/union type name string
    rv_sd_fields           // List of field name strings
    rv_sd_is_union         // 1 if union (all fields share offset 0), 0 if struct
    rv_sd_type_id          // Unique 1..N runtime type tag for sovereign dyn Trait dispatch
    rv_sd_field_types      // Parallel list of field type strings (e.g. "f64", "u64", "str", "")

// WHY: Return container for ELF64 container synthesis results
struct Riscv64ElfResult
    rv_ew_success          // 1 on success, 0 on failure
    rv_ew_out_path         // Destination binary path string
    rv_ew_file_size        // Total byte count written to disk
    rv_ew_entry_vaddr      // Absolute virtual memory entry address (0x400078 = 4194424)
    rv_ew_error_msg        // Human-readable error diagnostic

// WHY: Encapsulates mutable compilation state for RISC-V 64 silicon code generation
struct Riscv64Synthesizer
    rv_code                // List of machine code bytes (integers 0..255)
    rv_rodata              // List of read-only data bytes (.rodata segment)
    rv_str_relocs          // List of Riscv64StringReloc structs
    rv_call_relocs         // List of Riscv64CallReloc structs
    rv_locals              // List of Riscv64LocalVar structs for current function frame
    rv_functions           // List of Riscv64Function structs
    rv_stack_offset        // Next available local variable stack offset (16, 24, 32...)
    rv_needs_print_int     // Flag: 1 if integer printing helper must be emitted
    rv_print_int_off       // Byte offset where print_int helper starts
    rv_loop_starts         // Stack of loop header byte offsets for 'continue'
    rv_loop_breaks         // Stack of lists of break patch offsets
    rv_structs             // List of Riscv64StructDef structs
    rv_global_fields       // List of global field name strings
    rv_needs_alloc         // Flag: 1 if bump allocator helper must be emitted
    rv_alloc_off           // Byte offset where bump allocator starts
    rv_needs_list_create   // Flag: 1 if list constructor helper must be emitted
    rv_list_create_off     // Byte offset where list constructor helper starts
    rv_needs_file_write    // Flag: 1 if file_write helper must be emitted
    rv_file_write_off      // Byte offset where file_write helper starts
    rv_in_function         // 1 if currently synthesizing inside a function, 0 if top-level
    rv_try_patches         // Stack of lists of [patch_offset, kind] exception unwind patches (0=JAL, 1=BNE)
    rv_sp_delta            // Net stack bytes pushed since statement entry
    rv_for_conts           // Stack of continue patch lists for for-loops (to target step increment)
    rv_alloc_rw_patch_off  // Code offset of LUI+ADDI for _heap_ptr in RW .data segment
    rv_needs_list_push     // Flag: 1 if __list_push helper must be emitted
    rv_list_push_off       // Byte offset where __list_push helper starts
    rv_error_count         // Count of backend synthesis/relocation errors
    rv_error_msg           // First error diagnostic message
    rv_called_main         // 1 if explicit top-level main()/মূল() call was emitted
    rv_boxed_vars          // Local variable names auto-boxed into 8B upvalue cells for mutable closures
    rv_defer_starts        // List of deferred statement start token indices in current function
    rv_defer_ends          // Parallel list of deferred statement end token indices in current function
    rv_emitting_defer      // 1 while replaying deferred statements before function exit
    rv_needs_dict          // Flag: 1 if DICT0 HashMap + unified container helpers must be emitted
    rv_dict_hash_off       // Byte offset of __dict_hash helper
    rv_dict_eq_off         // Byte offset of __dict_key_eq helper
    rv_dict_new_off        // Byte offset of __dict_new helper
    rv_dict_set_off        // Byte offset of __dict_set helper
    rv_dict_get_off        // Byte offset of __dict_get helper
    rv_dict_has_off        // Byte offset of __dict_has helper
    rv_dict_del_off        // Byte offset of __dict_del helper
    rv_cont_get_off        // Byte offset of __container_get helper
    rv_cont_set_off        // Byte offset of __container_set helper
    rv_needs_buf           // Flag: 1 if ByteBuffer helpers must be emitted
    rv_buf_new_off         // Byte offset of __buf_new helper
    rv_buf_wbyte_off       // Byte offset of __buf_write_byte helper
    rv_buf_wstr_off        // Byte offset of __buf_write_str helper
    rv_buf_tostr_off       // Byte offset of __buf_to_str helper
    rv_freestanding        // 1 when --freestanding / --no-runtime bare-metal mode (0 Linux ECALL)
    rv_enum_names          // Registered ADT variant names (Ok, Err, Some, None, + user enums)
    rv_enum_tags           // Parallel ADT integer discriminant tags
    rv_enum_arities        // Parallel ADT payload arities
    rv_next_enum_tag       // Next auto-assigned custom enum tag (starts at 2000)
    rv_cur_fn_name         // Active function name for stack_trace()
    rv_last_is_uint        // 1 if last evaluated expression is unsigned (u8/u16/u32/u64/usize)
    rv_last_expr_type      // Type of most recently evaluated expression: "int", "float", "str", "dyn_tagged"
    rv_needs_throw_null    // 1 if _lipi_throw_null_deref helper must be emitted
    rv_throw_null_off      // Byte offset of _lipi_throw_null_deref helper
    rv_needs_stack_trace   // 1 if _lipi_stack_trace LSYM0 frame walker must be emitted
    rv_stack_trace_off     // Byte offset of _lipi_stack_trace helper
    rv_lsym_patch_lsym     // Code offset of LUI+ADDI for LSYM0 table vaddr
    rv_lsym_patch_code     // Code offset of LUI+ADDI for code_base vaddr
    rv_lsym_patch_ro       // Code offset of LUI+ADDI for rodata_base vaddr
    rv_needs_print_tagged  // 1 if __print_str / __print_float / __print_tagged helpers must be emitted
    rv_print_str_off       // Byte offset of __print_str helper
    rv_print_float_off     // Byte offset of __print_float helper
    rv_print_tagged_off    // Byte offset of __print_tagged helper
    rv_needs_print_uint    // 1 if unsigned 64-bit __print_uint helper must be emitted
    rv_print_uint_off      // Byte offset of __print_uint helper
    rv_needs_str_helpers   // 1 if __int_to_str / __uint_to_str / __str_concat / __tagged_to_str must be emitted
    rv_int_to_str_off      // Byte offset of __int_to_str helper
    rv_uint_to_str_off     // Byte offset of __uint_to_str helper
    rv_float_to_str_off    // Byte offset of __float_to_str helper
    rv_str_concat_off      // Byte offset of __str_concat helper
    rv_tagged_to_str_off   // Byte offset of __tagged_to_str helper
    rv_needs_uncaught_throw // 1 if __uncaught_throw top-level handler must be emitted
    rv_uncaught_throw_off   // Byte offset of __uncaught_throw helper
    rv_ssa_lower_res       // Attached SsaLowerResult for direct RISC-V 64 SSA CFG replacement
    rv_ssa_replaced_cnt    // Count of functions replaced directly from SSA CFG
    rv_ssa_replaced_bytes  // Total native RV64IM bytes emitted directly from SSA CFG
    rv_last_struct         // Tracks struct/union type of most recently synthesized primary expression
    rv_impl_type           // Active impl target struct/union name ("" outside impl blocks)
    rv_next_type_id        // Next unique runtime type ID (1..N) for struct/union tags
    rv_impl_methods        // Prescanned list of [TargetType, method_name] pairs for dispatch
    rv_fn_sigs             // Prescanned Riscv64FnSig list for variadic & default-param calls
    rv_source_toks         // Full module token stream for default-arg evaluation

struct Riscv64FnSig
    rv_sig_name
    rv_sig_param_count
    rv_sig_is_variadic
    rv_sig_def_starts
    rv_sig_ret_type

fn riscv64_is_float_type tname
    if tname == "f64" or tname == "f32" or tname == "float" or tname == "double" or tname == "দশমিক"
        return 1
    end
    return 0
end

fn riscv64_is_uint_type tname
    if tname == "u8" or tname == "byte" or tname == "u16" or tname == "u32" or tname == "u64" or tname == "usize" or tname == "uint"
        return 1
    end
    return 0
end

fn riscv64_is_narrow_int_type tname
    if tname == "u8" or tname == "byte" or tname == "u16" or tname == "u32" or tname == "i8" or tname == "i16" or tname == "i32"
        return 1
    end
    return 0
end

global g_rv64_freestanding = 0
global g_rv64_base_vaddr = 4194304
global g_rv64_code_file_off = 232
global g_rv64_ssa_codegen = 0

fn riscv64_synth_set_freestanding flag
    g_rv64_freestanding = flag
    return flag

fn riscv64_synth_set_ssa_codegen flag
    g_rv64_ssa_codegen = flag
    return flag

fn riscv64_synth_set_base_vaddr vaddr
    g_rv64_base_vaddr = vaddr
    return vaddr

fn riscv64_synth_set_code_file_off off
    g_rv64_code_file_off = off
    return off

fn riscv64_verify_zero_linux_ecalls code_bytes
    // WHY: Bare-Metal Purity Gate for RISC-V 64 --freestanding: scans 32-bit aligned words
    // for forbidden Linux `ecall` (0x00000073 -> [115, 0, 0, 0]).
    // Distinguishes OpenSBI S-mode traps from Linux syscalls:
    //   1. Legitimate OpenSBI S-mode `sbi_ecall*` intrinsics are immediately preceded by the
    //      canonical RISC-V architectural HINT `addi x0, x0, 0x5B1` (0x5B100013 = [19, 0, 16, 91]).
    //   2. Any unmarked `ecall` (e.g. Linux `syscall(...)` / `exit(...)`) is strictly rejected!
    //   3. Even on a HINT-marked `ecall`, if a preceding `addi a7, x0, imm12` loads a Linux
    //      syscall number in [56..290] (e.g. write=64, exit=93, exit_group=94, mmap=222) instead
    //      of an OpenSBI EID (0..16 or 4-byte ASCII >= 0x10000), it is STILL rejected!
    cnt = 0
    i = 0
    n = code_bytes.len()
    while i + 3 < n
        if code_bytes[i] == 115 and code_bytes[i + 1] == 0 and code_bytes[i + 2] == 0 and code_bytes[i + 3] == 0
            is_valid_sbi = 0
            if i >= 4 and code_bytes[i - 4] == 19 and code_bytes[i - 3] == 0 and code_bytes[i - 2] == 16 and code_bytes[i - 1] == 91
                is_valid_sbi = 1
                // Inspect preceding window (up to 6 instructions) for static Linux syscall number in a7 (x17)
                // Pattern: `addi x17, x0, imm12` -> low 20 bits == 0x00893 (b0=0x93=147, b1=0x08=8, b2&0x0F==0)
                k = i - 8
                k_min = i - 28
                if k_min < 0 k_min = 0 end
                while k >= k_min
                    b0 = code_bytes[k] & 255
                    b1 = code_bytes[k + 1] & 255
                    b2 = code_bytes[k + 2] & 255
                    b3 = code_bytes[k + 3] & 255
                    if b0 == 147 and b1 == 8 and (b2 & 15) == 0
                        imm12 = ((b2 >> 4) & 15) | (b3 << 4)
                        if imm12 >= 2048
                            imm12 = imm12 - 4096
                        end
                        if imm12 >= 56 and imm12 <= 290
                            is_valid_sbi = 0
                        end
                        break
                    end
                    k = k - 4
                end
            end
            if is_valid_sbi == 0
                cnt = cnt + 1
            end
        end
        i = i + 4
    end
    return cnt

fn riscv64_enum_register s vname tag arity
    // WHY: Preserves canonical Result/Option tags (Ok=1001, Err=1002, Some=1003, None=1004)
    // when user code redeclares `enum Res { Ok(T), Err(E) }` so postfix `?` always matches Err/None.
    i = 0
    while i < s.rv_enum_names.len()
        if s.rv_enum_names[i] == vname
            cur_tag = s.rv_enum_tags[i]
            if cur_tag >= 1001 and cur_tag <= 1004
                list_set(s.rv_enum_arities, i, arity)
                return cur_tag
            end
            list_set(s.rv_enum_tags, i, tag)
            list_set(s.rv_enum_arities, i, arity)
            return tag
        end
        i = i + 1
    end
    push(s.rv_enum_names, vname)
    push(s.rv_enum_tags, tag)
    push(s.rv_enum_arities, arity)
    return tag

fn riscv64_enum_find_idx s vname
    i = 0
    while i < s.rv_enum_names.len()
        if s.rv_enum_names[i] == vname
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn riscv64_emit_load_rodata_str s reg str_text
    ro_off = riscv64_synth_add_rodata_str(s, str_text, 0)
    p_off = s.rv_code.len()
    riscv64_emit_lui(s, reg, 0)
    riscv64_emit_addi(s, reg, reg, 0)
    srel = Riscv64StringReloc()
    srel.rv_sr_patch_offset = p_off
    srel.rv_sr_rodata_offset = ro_off
    srel.rv_sr_reg = reg
    push(s.rv_str_relocs, srel)
    return 0

// ── 2. Constructor & Emitter Primitives ───────────────────────────────────────

fn riscv64_synth_new
    // WHY: Allocates and initializes clean RISC-V 64 synthesizer state.
    s = Riscv64Synthesizer()
    s.rv_code = list()
    s.rv_rodata = list()
    s.rv_str_relocs = list()
    s.rv_call_relocs = list()
    s.rv_locals = list()
    s.rv_functions = list()
    s.rv_stack_offset = 16
    s.rv_needs_print_int = 0
    s.rv_print_int_off = 0
    s.rv_loop_starts = list()
    s.rv_loop_breaks = list()
    s.rv_structs = list()
    s.rv_global_fields = list()
    s.rv_needs_alloc = 0
    s.rv_alloc_off = 0
    s.rv_needs_list_create = 0
    s.rv_list_create_off = 0
    s.rv_needs_file_write = 0
    s.rv_file_write_off = 0
    s.rv_in_function = 0
    s.rv_try_patches = list()
    s.rv_sp_delta = 0
    s.rv_for_conts = list()
    s.rv_alloc_rw_patch_off = 0 - 1
    s.rv_needs_list_push = 0
    s.rv_list_push_off = 0
    s.rv_error_count = 0
    s.rv_error_msg = ""
    s.rv_called_main = 0
    s.rv_boxed_vars = list()
    s.rv_defer_starts = list()
    s.rv_defer_ends = list()
    s.rv_emitting_defer = 0
    s.rv_needs_dict = 0
    s.rv_dict_hash_off = 0
    s.rv_dict_eq_off = 0
    s.rv_dict_new_off = 0
    s.rv_dict_set_off = 0
    s.rv_dict_get_off = 0
    s.rv_dict_has_off = 0
    s.rv_dict_del_off = 0
    s.rv_cont_get_off = 0
    s.rv_cont_set_off = 0
    s.rv_needs_buf = 0
    s.rv_buf_new_off = 0
    s.rv_buf_wbyte_off = 0
    s.rv_buf_wstr_off = 0
    s.rv_buf_tostr_off = 0
    s.rv_freestanding = g_rv64_freestanding
    s.rv_enum_names = list()
    s.rv_enum_tags = list()
    s.rv_enum_arities = list()
    s.rv_next_enum_tag = 2000
    s.rv_cur_fn_name = "_start"
    s.rv_last_is_uint = 0
    s.rv_last_expr_type = "int"
    s.rv_needs_throw_null = 0
    s.rv_throw_null_off = 0
    s.rv_needs_stack_trace = 0
    s.rv_stack_trace_off = 0
    s.rv_lsym_patch_lsym = 0 - 1
    s.rv_lsym_patch_code = 0 - 1
    s.rv_lsym_patch_ro = 0 - 1
    s.rv_needs_print_tagged = 0
    s.rv_print_str_off = 0
    s.rv_print_float_off = 0
    s.rv_print_tagged_off = 0
    s.rv_needs_print_uint = 0
    s.rv_print_uint_off = 0
    s.rv_needs_str_helpers = 0
    s.rv_int_to_str_off = 0
    s.rv_uint_to_str_off = 0
    s.rv_float_to_str_off = 0
    s.rv_str_concat_off = 0
    s.rv_tagged_to_str_off = 0
    s.rv_needs_uncaught_throw = 0
    s.rv_uncaught_throw_off = 0
    s.rv_ssa_lower_res = 0
    s.rv_ssa_replaced_cnt = 0
    s.rv_ssa_replaced_bytes = 0
    s.rv_last_struct = ""
    s.rv_impl_type = ""
    s.rv_next_type_id = 1
    s.rv_impl_methods = list()
    s.rv_fn_sigs = list()
    s.rv_source_toks = 0
    riscv64_enum_register(s, "Ok", 1001, 1)
    riscv64_enum_register(s, "Err", 1002, 1)
    riscv64_enum_register(s, "Some", 1003, 1)
    riscv64_enum_register(s, "None", 1004, 0)
    return s

fn riscv64_synth_emit_byte s byte_val
    // WHY: Emits a single raw machine instruction byte into rv_code.
    push(s.rv_code, (byte_val % 256 + 256) % 256)
    return s.rv_code.len()

fn riscv64_synth_emit_bytes s byte_list
    // WHY: Appends an array of byte values sequentially.
    i = 0
    n = byte_list.len()
    while i < n
        push(s.rv_code, (byte_list[i] % 256 + 256) % 256)
        i = i + 1
    return s.rv_code.len()

fn riscv64_synth_emit32 s inst_word
    // WHY: Emits 4 bytes in little-endian byte order for 32-bit fixed-width RISC-V instruction word.
    b0 = inst_word % 256
    if b0 < 0 b0 = b0 + 256
    w1 = inst_word / 256
    b1 = w1 % 256
    if b1 < 0 b1 = b1 + 256
    w2 = w1 / 256
    b2 = w2 % 256
    if b2 < 0 b2 = b2 + 256
    w3 = w2 / 256
    b3 = w3 % 256
    if b3 < 0 b3 = b3 + 256
    push(s.rv_code, b0)
    push(s.rv_code, b1)
    push(s.rv_code, b2)
    push(s.rv_code, b3)
    return s.rv_code.len()

fn riscv64_synth_patch_u32 s offset val
    // WHY: Backpatches 4 bytes at a predetermined byte offset in rv_code.
    b0 = val % 256
    if b0 < 0 b0 = b0 + 256
    w1 = val / 256
    b1 = w1 % 256
    if b1 < 0 b1 = b1 + 256
    w2 = w1 / 256
    b2 = w2 % 256
    if b2 < 0 b2 = b2 + 256
    w3 = w2 / 256
    b3 = w3 % 256
    if b3 < 0 b3 = b3 + 256
    list_set(s.rv_code, offset, b0)
    list_set(s.rv_code, offset + 1, b1)
    list_set(s.rv_code, offset + 2, b2)
    list_set(s.rv_code, offset + 3, b3)
    return 0

// ── 3. Read-Only Data (.rodata) Management ────────────────────────────────────

fn riscv64_synth_add_rodata_str s str_text with_newline
    // WHY: Stores UTF-8 string payload into rv_rodata and returns its starting offset.
    start_off = s.rv_rodata.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.rv_rodata, ord(c))
        i = i + 1
    if with_newline == 1
        push(s.rv_rodata, 10) // '\n' (ASCII 10)
    push(s.rv_rodata, 0)      // Null-terminator (ASCII 0)
    return start_off

// ── 4. RISC-V 64 Canonical Instruction Emitters ───────────────────────────────

fn riscv64_emit_lui s rd imm20
    // WHY: LUI rd, imm20 (opcode 0x37 = 55). Loads upper 20 bits into destination register.
    bytes = rv64_encode_u(55, rd, imm20)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_auipc s rd imm20
    // WHY: AUIPC rd, imm20 (opcode 0x17 = 23). Adds upper 20-bit imm to PC.
    bytes = rv64_encode_u(23, rd, imm20)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_jal s rd imm
    // WHY: JAL rd, imm (opcode 0x6F = 111). Jump and link with 20-bit relative byte displacement.
    bytes = rv64_encode_j(111, rd, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_jalr s rd rs1 imm12
    // WHY: JALR rd, rs1, imm12 (opcode 0x67 = 103, funct3=0). Indirect register jump and link.
    bytes = rv64_encode_i(103, rd, 0, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_beq s rs1 rs2 imm
    // WHY: BEQ rs1, rs2, imm (opcode 0x63 = 99, funct3=0). Branch if equal.
    bytes = rv64_encode_b(99, 0, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_bne s rs1 rs2 imm
    // WHY: BNE rs1, rs2, imm (opcode 0x63 = 99, funct3=1). Branch if not equal.
    bytes = rv64_encode_b(99, 1, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_blt s rs1 rs2 imm
    // WHY: BLT rs1, rs2, imm (opcode 0x63 = 99, funct3=4). Branch if signed less than.
    bytes = rv64_encode_b(99, 4, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_bge s rs1 rs2 imm
    // WHY: BGE rs1, rs2, imm (opcode 0x63 = 99, funct3=5). Branch if signed greater/equal.
    bytes = rv64_encode_b(99, 5, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_add s rd rs1 rs2
    // WHY: ADD rd, rs1, rs2 (opcode 0x33 = 51, funct3=0, funct7=0). 64-bit integer addition.
    bytes = rv64_emit_add(rd, rs1, rs2)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sub s rd rs1 rs2
    // WHY: SUB rd, rs1, rs2 (opcode 0x33 = 51, funct3=0, funct7=32). 64-bit integer subtraction.
    bytes = rv64_emit_sub(rd, rs1, rs2)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_addi s rd rs1 imm12
    // WHY: ADDI rd, rs1, imm12 (opcode 0x13 = 19, funct3=0). 64-bit addition with 12-bit signed immediate.
    bytes = rv64_emit_addi(rd, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_mul s rd rs1 rs2
    // WHY: MUL rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=0, funct7=1). 64-bit signed multiplication.
    bytes = rv64_encode_r(51, rd, 0, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_div s rd rs1 rs2
    // WHY: DIV rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=4, funct7=1). 64-bit signed integer division.
    bytes = rv64_encode_r(51, rd, 4, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_divu s rd rs1 rs2
    // WHY: DIVU rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=5, funct7=1). 64-bit unsigned integer division.
    bytes = rv64_encode_r(51, rd, 5, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_rem s rd rs1 rs2
    // WHY: REM rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=6, funct7=1). 64-bit signed remainder.
    bytes = rv64_encode_r(51, rd, 6, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_remu s rd rs1 rs2
    // WHY: REMU rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=7, funct7=1). 64-bit unsigned remainder.
    bytes = rv64_encode_r(51, rd, 7, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_srl s rd rs1 rs2
    // WHY: SRL rd, rs1, rs2 (RV64I: opcode 0x33 = 51, funct3=5, funct7=0). Logical right shift.
    bytes = rv64_encode_r(51, rd, 5, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_slt s rd rs1 rs2
    // WHY: SLT rd, rs1, rs2 (opcode 0x33 = 51, funct3=2, funct7=0). Signed set less than.
    bytes = rv64_encode_r(51, rd, 2, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sltu s rd rs1 rs2
    // WHY: SLTU rd, rs1, rs2 (opcode 0x33 = 51, funct3=3, funct7=0). Unsigned set less than.
    bytes = rv64_encode_r(51, rd, 3, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sltiu s rd rs1 imm12
    // WHY: SLTIU rd, rs1, imm12 (opcode 0x13 = 19, funct3=3). Unsigned set less than immediate.
    bytes = rv64_encode_i(19, rd, 3, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_xori s rd rs1 imm12
    // WHY: XORI rd, rs1, imm12 (opcode 0x13 = 19, funct3=4). Bitwise XOR immediate.
    bytes = rv64_encode_i(19, rd, 4, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_andi s rd rs1 imm12
    // WHY: ANDI rd, rs1, imm12 (opcode 0x13 = 19, funct3=7). Bitwise AND immediate.
    bytes = rv64_encode_i(19, rd, 7, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_ld s rd rs1 offset12
    // WHY: LD rd, offset12(rs1) (opcode 0x03 = 3, funct3=3). 64-bit memory load.
    bytes = rv64_emit_ld(rd, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_lwu s rd rs1 offset12
    // WHY: LWU rd, offset12(rs1) (opcode 0x03 = 3, funct3=6). Unsigned 32-bit load (LSYM0 table).
    bytes = rv64_encode_i(3, rd, 6, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_srli s rd rs1 shamt
    // WHY: SRLI rd, rs1, shamt (opcode 0x13 = 19, funct3=5). Logical right shift immediate.
    bytes = rv64_encode_i(19, rd, 5, rs1, shamt & 63)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_srai s rd rs1 shamt
    // WHY: SRAI rd, rs1, shamt (opcode 0x13 = 19, funct3=5, bit30=1 -> imm12=1024|shamt). Arithmetic right shift immediate.
    bytes = rv64_encode_i(19, rd, 5, rs1, 1024 | (shamt & 63))
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_truncate_int_width s reg tname
    // WHY: Enforces exact RV64I bit-width wrapping/sign-extension for local u8/u16/u32/i8/i16/i32.
    if tname == "u8" or tname == "byte"
        riscv64_emit_andi(s, reg, reg, 255)
    elif tname == "u16"
        riscv64_emit_slli(s, reg, reg, 48)
        riscv64_emit_srli(s, reg, reg, 48)
    elif tname == "u32"
        riscv64_emit_slli(s, reg, reg, 32)
        riscv64_emit_srli(s, reg, reg, 32)
    elif tname == "i8"
        riscv64_emit_slli(s, reg, reg, 56)
        riscv64_emit_srai(s, reg, reg, 56)
    elif tname == "i16"
        riscv64_emit_slli(s, reg, reg, 48)
        riscv64_emit_srai(s, reg, reg, 48)
    elif tname == "i32"
        riscv64_emit_slli(s, reg, reg, 32)
        riscv64_emit_srai(s, reg, reg, 32)
    end
    return 0
end

fn riscv64_emit_sd s rs2 rs1 offset12
    // WHY: SD rs2, offset12(rs1) (opcode 0x23 = 35, funct3=3). 64-bit memory store.
    bytes = rv64_emit_sd(rs2, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_lb s rd rs1 offset12
    // WHY: LB rd, offset12(rs1) (opcode 0x03 = 3, funct3=0). 8-bit signed memory load.
    bytes = rv64_encode_i(3, rd, 0, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_lbu s rd rs1 offset12
    // WHY: LBU rd, offset12(rs1) (opcode 0x03 = 3, funct3=4). 8-bit unsigned memory load.
    bytes = rv64_encode_i(3, rd, 4, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sb s rs2 rs1 offset12
    // WHY: SB rs2, offset12(rs1) (opcode 0x23 = 35, funct3=0). 8-bit byte memory store.
    bytes = rv64_encode_s(35, 0, rs1, rs2, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_ecall s
    // WHY: ECALL (opcode 0x73 = 115, funct3=0). Triggers hardware environment trap for Linux syscalls.
    bytes = rv64_emit_ecall()
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_ret s
    // WHY: RET pseudoinstruction (JALR x0, x1, 0: opcode 0x67, rd=0, rs1=1, funct3=0). Returns to caller.
    bytes = rv64_emit_ret()
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_mv s rd rs
    // WHY: MV rd, rs (Pseudoinstruction: ADDI rd, rs, 0). Copies register contents.
    riscv64_emit_addi(s, rd, rs, 0)
    return 0

fn riscv64_emit_ori s rd rs1 imm12
    // WHY: ORI rd, rs1, imm12 (opcode 0x13 = 19, funct3=6). Bitwise OR immediate.
    bytes = rv64_encode_i(19, rd, 6, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_slli s rd rs1 shamt
    // WHY: SLLI rd, rs1, shamt (opcode 0x13 = 19, funct3=1). Shift left logical immediate.
    bytes = rv64_encode_i(19, rd, 1, rs1, shamt & 63)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_and s rd rs1 rs2
    // WHY: AND rd, rs1, rs2 (opcode 0x33 = 51, funct3=7, funct7=0).
    bytes = rv64_encode_r(51, rd, 7, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_or s rd rs1 rs2
    // WHY: OR rd, rs1, rs2 (opcode 0x33 = 51, funct3=6, funct7=0).
    bytes = rv64_encode_r(51, rd, 6, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_xor s rd rs1 rs2
    // WHY: XOR rd, rs1, rs2 (opcode 0x33 = 51, funct3=4, funct7=0).
    bytes = rv64_encode_r(51, rd, 4, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sll s rd rs1 rs2
    // WHY: SLL rd, rs1, rs2 (opcode 0x33 = 51, funct3=1, funct7=0).
    bytes = rv64_encode_r(51, rd, 1, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sra s rd rs1 rs2
    // WHY: SRA rd, rs1, rs2 (opcode 0x33 = 51, funct3=5, funct7=32).
    bytes = rv64_encode_r(51, rd, 5, rs1, rs2, 32)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

// ── 4b. Hardware IEEE-754 Double-Precision (RV64D) FP Instruction Emitters ───
fn riscv64_emit_fmv_d_x s fd rs1
    // WHY: FMV.D.X fd, rs1 (OP-FP=83, funct7=121, rs2=0, funct3=0) — bitwise GP64 -> f64.
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, rs1, 0, 121))
    return 0

fn riscv64_emit_fmv_x_d s rd fs1
    // WHY: FMV.X.D rd, fs1 (OP-FP=83, funct7=113, rs2=0, funct3=0) — bitwise f64 -> GP64.
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, rd, 0, fs1, 0, 113))
    return 0

fn riscv64_emit_fcvt_d_l s fd rs1
    // WHY: FCVT.D.L fd, rs1, RNE (OP-FP=83, funct7=105, rs2=2, funct3=0) — signed i64 -> f64.
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, rs1, 2, 105))
    return 0

fn riscv64_emit_fcvt_d_lu s fd rs1
    // WHY: FCVT.D.LU fd, rs1, RNE (OP-FP=83, funct7=105, rs2=3, funct3=0) — unsigned u64 -> f64.
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, rs1, 3, 105))
    return 0

fn riscv64_emit_fcvt_l_d_rtz s rd fs1
    // WHY: FCVT.L.D rd, fs1, RTZ (OP-FP=83, funct7=97, rs2=2, funct3=1) — f64 -> signed i64 trunc.
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, rd, 1, fs1, 2, 97))
    return 0

fn riscv64_emit_fadd_d s fd fs1 fs2
    // WHY: FADD.D fd, fs1, fs2, RNE (OP-FP=83, funct7=1, funct3=0).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, fs1, fs2, 1))
    return 0

fn riscv64_emit_fsub_d s fd fs1 fs2
    // WHY: FSUB.D fd, fs1, fs2, RNE (OP-FP=83, funct7=5, funct3=0).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, fs1, fs2, 5))
    return 0

fn riscv64_emit_fmul_d s fd fs1 fs2
    // WHY: FMUL.D fd, fs1, fs2, RNE (OP-FP=83, funct7=9, funct3=0).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, fs1, fs2, 9))
    return 0

fn riscv64_emit_fdiv_d s fd fs1 fs2
    // WHY: FDIV.D fd, fs1, fs2, RNE (OP-FP=83, funct7=13, funct3=0).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, fd, 0, fs1, fs2, 13))
    return 0

fn riscv64_emit_feq_d s rd fs1 fs2
    // WHY: FEQ.D rd, fs1, fs2 (OP-FP=83, funct7=81, funct3=2) — IEEE-754 ordered equal (0 on NaN).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, rd, 2, fs1, fs2, 81))
    return 0

fn riscv64_emit_flt_d s rd fs1 fs2
    // WHY: FLT.D rd, fs1, fs2 (OP-FP=83, funct7=81, funct3=1) — IEEE-754 ordered < (0 on NaN).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, rd, 1, fs1, fs2, 81))
    return 0

fn riscv64_emit_fle_d s rd fs1 fs2
    // WHY: FLE.D rd, fs1, fs2 (OP-FP=83, funct7=81, funct3=0) — IEEE-754 ordered <= (0 on NaN).
    riscv64_synth_emit_bytes(s, rv64_encode_r(83, rd, 0, fs1, fs2, 81))
    return 0

fn riscv64_emit_load_fp_reg s fd xreg expr_t is_u tag_reg
    // WHY: Transfers f64 bits via FMV.D.X or promotes int/uint/dyn_tagged to f64 via FCVT.D.L/LU.
    if expr_t == "float"
        riscv64_emit_fmv_d_x(s, fd, xreg)
    elif expr_t == "dyn_tagged"
        riscv64_emit_li(s, 30, 1)
        beq_isf = s.rv_code.len()
        riscv64_emit_beq(s, tag_reg, 30, 0)
        riscv64_emit_fcvt_d_l(s, fd, xreg)
        jmp_done = s.rv_code.len()
        riscv64_emit_jal(s, 0, 0)
        riscv64_synth_patch_b(s, beq_isf, 0, tag_reg, 30, s.rv_code.len())
        riscv64_emit_fmv_d_x(s, fd, xreg)
        riscv64_synth_patch_jal(s, jmp_done, 0, s.rv_code.len())
    elif is_u == 1
        riscv64_emit_fcvt_d_lu(s, fd, xreg)
    else
        riscv64_emit_fcvt_d_l(s, fd, xreg)
    end
    return 0

fn riscv64_emit_li s rd val
    // WHY: LI rd, val. Loads arbitrary signed 64-bit constant into rd using minimal instructions.
    // Small values (-2048..2047) take 1 instruction (ADDI rd, x0, val).
    // 32-bit signed values take 2 instructions (LUI + ADDI).
    // Full 64-bit values (e.g. IEEE-754 f64 bits) pack cleanly via 9+5*11 bit chunks with SLLI+ORI.
    if val >= 0 - 2048 and val <= 2047
        riscv64_emit_addi(s, rd, 0, val)
        return 0
    if val >= 0 - 2147483648 and val <= 2147483647
        lo = val & 4095
        if lo >= 2048
            lo = lo - 4096
        hi = ((val - lo) >> 12) & 1048575
        riscv64_emit_lui(s, rd, hi)
        if lo != 0
            riscv64_emit_addi(s, rd, rd, lo)
        return 0

    top9 = (val >> 55) & 511
    if (top9 & 256) != 0
        top9 = top9 - 512
    riscv64_emit_addi(s, rd, 0, top9)
    c4 = (val >> 44) & 2047
    riscv64_emit_slli(s, rd, rd, 11)
    if c4 != 0
        riscv64_emit_ori(s, rd, rd, c4)
    c3 = (val >> 33) & 2047
    riscv64_emit_slli(s, rd, rd, 11)
    if c3 != 0
        riscv64_emit_ori(s, rd, rd, c3)
    c2 = (val >> 22) & 2047
    riscv64_emit_slli(s, rd, rd, 11)
    if c2 != 0
        riscv64_emit_ori(s, rd, rd, c2)
    c1 = (val >> 11) & 2047
    riscv64_emit_slli(s, rd, rd, 11)
    if c1 != 0
        riscv64_emit_ori(s, rd, rd, c1)
    c0 = val & 2047
    riscv64_emit_slli(s, rd, rd, 11)
    if c0 != 0
        riscv64_emit_ori(s, rd, rd, c0)
    return 0

// ── 5. Backpatching & Relocation Utilities ─────────────────────────────────────

fn riscv64_synth_patch_lui_addi s offset rd target_vaddr
    // WHY: Patches a 2-instruction (8-byte) LUI + ADDI sequence to load a 32-bit virtual memory address.
    lo = target_vaddr & 4095
    if lo >= 2048
        lo = lo - 4096
    hi = ((target_vaddr - lo) >> 12) & 1048575
    w_lui_bytes = rv64_encode_u(55, rd, hi)
    w_addi_bytes = rv64_encode_i(19, rd, 0, rd, lo)
    list_set(s.rv_code, offset, get(w_lui_bytes, 0))
    list_set(s.rv_code, offset + 1, get(w_lui_bytes, 1))
    list_set(s.rv_code, offset + 2, get(w_lui_bytes, 2))
    list_set(s.rv_code, offset + 3, get(w_lui_bytes, 3))
    list_set(s.rv_code, offset + 4, get(w_addi_bytes, 0))
    list_set(s.rv_code, offset + 5, get(w_addi_bytes, 1))
    list_set(s.rv_code, offset + 6, get(w_addi_bytes, 2))
    list_set(s.rv_code, offset + 7, get(w_addi_bytes, 3))
    return 0

fn riscv64_synth_patch_auipc_addi s offset rd delta
    // WHY: Patches an 8-byte AUIPC+ADDI pair with PC-relative signed delta (works at any 64-bit base address!).
    lo = delta & 4095
    if lo >= 2048
        lo = lo - 4096
    end
    hi = ((delta - lo) >> 12) & 1048575
    w_auipc_bytes = rv64_encode_u(23, rd, hi)
    w_addi_bytes = rv64_encode_i(19, rd, 0, rd, lo)
    list_set(s.rv_code, offset, get(w_auipc_bytes, 0))
    list_set(s.rv_code, offset + 1, get(w_auipc_bytes, 1))
    list_set(s.rv_code, offset + 2, get(w_auipc_bytes, 2))
    list_set(s.rv_code, offset + 3, get(w_auipc_bytes, 3))
    list_set(s.rv_code, offset + 4, get(w_addi_bytes, 0))
    list_set(s.rv_code, offset + 5, get(w_addi_bytes, 1))
    list_set(s.rv_code, offset + 6, get(w_addi_bytes, 2))
    list_set(s.rv_code, offset + 7, get(w_addi_bytes, 3))
    return 0

fn riscv64_synth_patch_jal s patch_offset rd target_offset
    // WHY: Patches a 4-byte JAL instruction with 20-bit relative byte displacement.
    rel_bytes = target_offset - patch_offset
    j_bytes = rv64_encode_j(111, rd, rel_bytes)
    list_set(s.rv_code, patch_offset, get(j_bytes, 0))
    list_set(s.rv_code, patch_offset + 1, get(j_bytes, 1))
    list_set(s.rv_code, patch_offset + 2, get(j_bytes, 2))
    list_set(s.rv_code, patch_offset + 3, get(j_bytes, 3))
    return 0

fn riscv64_synth_patch_b s patch_offset funct3 rs1 rs2 target_offset
    // WHY: Patches a 4-byte B-type conditional branch instruction with 12-bit relative byte displacement.
    rel_bytes = target_offset - patch_offset
    b_bytes = rv64_encode_b(99, funct3, rs1, rs2, rel_bytes)
    list_set(s.rv_code, patch_offset, get(b_bytes, 0))
    list_set(s.rv_code, patch_offset + 1, get(b_bytes, 1))
    list_set(s.rv_code, patch_offset + 2, get(b_bytes, 2))
    list_set(s.rv_code, patch_offset + 3, get(b_bytes, 3))
    return 0

// ── 6. Stack Frame & Register Push/Pop Primitives ─────────────────────────────

fn riscv64_push_reg s reg
    // WHY: Pushes 64-bit register onto stack:
    //      addi sp, sp, -16
    //      sd reg, 0(sp)
    // Preserves mandatory LP64 16-byte stack alignment at all times.
    riscv64_emit_addi(s, 2, 2, 0 - 16)
    riscv64_emit_sd(s, reg, 2, 0)
    s.rv_sp_delta = s.rv_sp_delta + 16
    return 0

fn riscv64_pop_reg s reg
    // WHY: Pops 64-bit register from stack:
    //      ld reg, 0(sp)
    //      addi sp, sp, 16
    riscv64_emit_ld(s, reg, 2, 0)
    riscv64_emit_addi(s, 2, 2, 16)
    s.rv_sp_delta = s.rv_sp_delta - 16
    return 0

fn riscv64_emit_local_ld s rd off
    // WHY: Reads local variable slot accounting for transiently pushed expression stack operands.
    eff = off + s.rv_sp_delta
    if eff >= 0 - 2048 and eff <= 2047
        riscv64_emit_ld(s, rd, 2, eff)
    else
        riscv64_emit_li(s, 31, eff)
        riscv64_emit_add(s, 31, 2, 31)
        riscv64_emit_ld(s, rd, 31, 0)
    end
    return 0

fn riscv64_emit_local_sd s rs2 off
    // WHY: Writes local variable slot accounting for transiently pushed expression stack operands.
    eff = off + s.rv_sp_delta
    if eff >= 0 - 2048 and eff <= 2047
        riscv64_emit_sd(s, rs2, 2, eff)
    else
        riscv64_emit_li(s, 31, eff)
        riscv64_emit_add(s, 31, 2, 31)
        riscv64_emit_sd(s, rs2, 31, 0)
    end
    return 0

fn riscv64_emit_prologue s
    // WHY: Standard LP64 ABI procedure frame setup:
    // 1. addi sp, sp, -1024       (Allocates 1KB stack space, 16-byte aligned)
    // 2. sd ra, 1016(sp)          (Preserves Return Address x1)
    // 3. sd s0, 1008(sp)          (Preserves Frame Pointer x8)
    // 4. addi s0, sp, 1024        (Establishes new Frame Pointer at caller's SP)
    riscv64_emit_addi(s, 2, 2, 0 - 1024)
    riscv64_emit_sd(s, 1, 2, 1016)
    riscv64_emit_sd(s, 8, 2, 1008)
    riscv64_emit_addi(s, 8, 2, 1024)
    return 0

fn riscv64_emit_epilogue s
    // WHY: Standard LP64 ABI procedure frame teardown:
    // 1. ld ra, 1016(sp)          (Restores Return Address x1)
    // 2. ld s0, 1008(sp)          (Restores Frame Pointer x8)
    // 3. addi sp, sp, 1024        (Deallocates stack frame)
    // 4. ret                      (Returns to caller via x1)
    riscv64_emit_ld(s, 1, 2, 1016)
    riscv64_emit_ld(s, 8, 2, 1008)
    riscv64_emit_addi(s, 2, 2, 1024)
    riscv64_emit_ret(s)
    return 0

// ── 7. String Printing Primitive ──────────────────────────────────────────────

fn riscv64_emit_print_string s str_val
    // WHY: Emits Linux RISC-V SYS_write(1, &str, len) for string literals:
    //      - a0 = 1 (STDOUT_FILENO)
    //      - a1 = Virtual address of UTF-8 string payload in .rodata
    //      - a2 = Byte length including appended newline
    //      - a7 = 64 (Linux RISC-V SYS_write)
    //      - ECALL
    ro_off = riscv64_synth_add_rodata_str(s, str_val, 1)
    str_len = len(str_val) + 1 // Includes appended newline

    // a0 = 1 (STDOUT)
    riscv64_emit_li(s, 10, 1)

    // a1 = <rodata_vaddr> (8-byte LUI + ADDI pair, backpatched after code assembly)
    patch_pos = s.rv_code.len()
    riscv64_emit_lui(s, 11, 0)
    riscv64_emit_addi(s, 11, 11, 0)

    rel = Riscv64StringReloc()
    rel.rv_sr_patch_offset = patch_pos
    rel.rv_sr_rodata_offset = ro_off
    rel.rv_sr_reg = 11
    push(s.rv_str_relocs, rel)

    // a2 = str_len
    riscv64_emit_li(s, 12, str_len)

    // a7 = 64 (SYS_write on Linux RISC-V)
    riscv64_emit_li(s, 17, 64)

    // ecall
    riscv64_emit_ecall(s)
    return 0

// ── 8. Micro-Runtime Helpers ──────────────────────────────────────────────────

fn riscv64_synth_emit_call_print_int s
    // WHY: Emits subroutine call to native __print_int helper to display integer in a0 (x10).
    s.rv_needs_print_int = 1
    call_off = s.rv_code.len()
    riscv64_emit_jal(s, 1, 0) // Placeholder JAL ra, 0

    call_rel = Riscv64CallReloc()
    call_rel.rv_cr_patch_offset = call_off
    call_rel.rv_cr_target_name = "__print_int"
    push(s.rv_call_relocs, call_rel)
    return 0

fn riscv64_synth_emit_call_print_uint s
    // WHY: Emits subroutine call to native __print_uint helper to display unsigned u64 in a0 (x10).
    s.rv_needs_print_uint = 1
    call_off = s.rv_code.len()
    riscv64_emit_jal(s, 1, 0)
    call_rel = Riscv64CallReloc()
    call_rel.rv_cr_patch_offset = call_off
    call_rel.rv_cr_target_name = "__print_uint"
    push(s.rv_call_relocs, call_rel)
    return 0

fn riscv64_synth_emit_print_int_helper s
    // WHY: Pure RISC-V assembly routine converting 64-bit signed integer in a0 (x10)
    // to ASCII decimal string on the stack and writing to STDOUT with trailing newline.
    // Uses divu/remu after negation so positive, zero, negative, and INT64_MIN all print accurately.
    s.rv_print_int_off = s.rv_code.len()

    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 8, 2, 48)

    riscv64_emit_addi(s, 5, 2, 47)
    riscv64_emit_addi(s, 6, 0, 10)
    riscv64_emit_sb(s, 6, 5, 0)
    riscv64_emit_addi(s, 6, 0, 1)

    bne_zero_off = s.rv_code.len()
    riscv64_emit_bne(s, 10, 0, 0)

    // Special case: a0 == 0
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    riscv64_emit_addi(s, 7, 0, 48)
    riscv64_emit_sb(s, 7, 5, 0)
    riscv64_emit_addi(s, 6, 6, 1)
    j_zero_write = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    // .check_neg:
    check_neg_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_zero_off, 1, 10, 0, check_neg_off)
    riscv64_emit_addi(s, 28, 0, 0)
    bge_pos_off = s.rv_code.len()
    riscv64_emit_bge(s, 10, 0, 0)
    riscv64_emit_addi(s, 28, 0, 1)
    riscv64_emit_sub(s, 10, 0, 10)

    // .loop_digits:
    loop_dig_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pos_off, 5, 10, 0, loop_dig_off)
    beq_fin_off = s.rv_code.len()
    riscv64_emit_beq(s, 10, 0, 0)
    riscv64_emit_addi(s, 29, 0, 10)
    riscv64_emit_remu(s, 30, 10, 29)
    riscv64_emit_divu(s, 10, 10, 29)
    riscv64_emit_addi(s, 30, 30, 48)
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    riscv64_emit_sb(s, 30, 5, 0)
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_jal(s, 0, loop_dig_off - s.rv_code.len())

    // .finish_digits:
    fin_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_fin_off, 0, 10, 0, fin_off)
    beq_write_off = s.rv_code.len()
    riscv64_emit_beq(s, 28, 0, 0)
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    riscv64_emit_addi(s, 7, 0, 45)
    riscv64_emit_sb(s, 7, 5, 0)
    riscv64_emit_addi(s, 6, 6, 1)

    // .do_write:
    do_write_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, j_zero_write, 0, do_write_off)
    riscv64_synth_patch_b(s, beq_write_off, 0, 28, 0, do_write_off)
    riscv64_emit_li(s, 10, 1)
    riscv64_emit_mv(s, 11, 5)
    riscv64_emit_mv(s, 12, 6)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)

    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_ld(s, 8, 2, 48)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)
    return 0

fn riscv64_synth_emit_print_uint_helper s
    // WHY: Pure RISC-V unsigned 64-bit integer decimal printer (0 .. 18446744073709551615) via DIVU/REMU.
    s.rv_print_uint_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 8, 2, 48)

    riscv64_emit_addi(s, 5, 2, 47)
    riscv64_emit_addi(s, 6, 0, 10)
    riscv64_emit_sb(s, 6, 5, 0)
    riscv64_emit_addi(s, 6, 0, 1)

    bne_u_loop = s.rv_code.len()
    riscv64_emit_bne(s, 10, 0, 0)
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    riscv64_emit_addi(s, 7, 0, 48)
    riscv64_emit_sb(s, 7, 5, 0)
    riscv64_emit_addi(s, 6, 6, 1)
    j_u_write = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    u_loop_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_u_loop, 1, 10, 0, u_loop_off)
    beq_u_write = s.rv_code.len()
    riscv64_emit_beq(s, 10, 0, 0)
    riscv64_emit_addi(s, 29, 0, 10)
    riscv64_emit_remu(s, 30, 10, 29)
    riscv64_emit_divu(s, 10, 10, 29)
    riscv64_emit_addi(s, 30, 30, 48)
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    riscv64_emit_sb(s, 30, 5, 0)
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_jal(s, 0, u_loop_off - s.rv_code.len())

    u_write_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, j_u_write, 0, u_write_off)
    riscv64_synth_patch_b(s, beq_u_write, 0, 10, 0, u_write_off)
    riscv64_emit_li(s, 10, 1)
    riscv64_emit_mv(s, 11, 5)
    riscv64_emit_mv(s, 12, 6)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)

    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_ld(s, 8, 2, 48)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)
    return 0

fn riscv64_synth_emit_call_alloc s
    // WHY: Emits subroutine call to native __alloc bump allocator.
    s.rv_needs_alloc = 1
    call_off = s.rv_code.len()
    riscv64_emit_jal(s, 1, 0) // Placeholder JAL ra, 0

    call_rel = Riscv64CallReloc()
    call_rel.rv_cr_patch_offset = call_off
    call_rel.rv_cr_target_name = "__alloc"
    push(s.rv_call_relocs, call_rel)
    return 0

fn riscv64_synth_emit_alloc_helper s
    // WHY: Emits pure RISC-V silicon bump-arena memory allocator storing _heap_ptr in RW .data
    // segment (strict W^X compliance, zero writes to executable .text pages).
    // Inputs: a0 (x10) = requested byte size. Output: a0 (x10) = pointer to allocated memory.
    s.rv_alloc_off = s.rv_code.len()

    // 0: Round requested size up to 16 bytes (minimum 16):
    riscv64_emit_addi(s, 10, 10, 15)
    riscv64_emit_andi(s, 10, 10, 0 - 16)

    // 1: Load address of _heap_ptr in RW .data segment into t0 (x5) (patched before ELF emit)
    s.rv_alloc_rw_patch_off = s.rv_code.len()
    riscv64_emit_lui(s, 5, 0)
    riscv64_emit_addi(s, 5, 5, 0)

    // Load current _heap_ptr from 0(t0) into t1 (x6)
    riscv64_emit_ld(s, 6, 5, 0)

    // bne t1, x0, .bump
    bne_bump_off = s.rv_code.len()
    riscv64_emit_bne(s, 6, 0, 0)

    // ── Heap initialization via Linux sys_mmap(NULL, 16MB, PROT_READ|WRITE, MAP_ANON|PRIVATE, -1, 0) ──
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 10, 2, 16)
    riscv64_emit_sd(s, 5, 2, 8)

    riscv64_emit_addi(s, 10, 0, 0)
    riscv64_emit_lui(s, 11, 4096) // 16MB virtual memory arena (4096 * 4096)
    riscv64_emit_addi(s, 12, 0, 3)
    riscv64_emit_addi(s, 13, 0, 34)
    riscv64_emit_addi(s, 14, 0, 0 - 1)
    riscv64_emit_addi(s, 15, 0, 0)
    riscv64_emit_li(s, 17, 222)
    riscv64_emit_ecall(s)

    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_ld(s, 12, 2, 16)
    riscv64_emit_ld(s, 5, 2, 8)
    riscv64_emit_addi(s, 2, 2, 32)

    // Store arena base address into _heap_ptr at 0(t0)
    riscv64_emit_sd(s, 10, 5, 0)
    riscv64_emit_mv(s, 6, 10)
    riscv64_emit_mv(s, 10, 12)

    // .bump:
    bump_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_bump_off, 1, 6, 0, bump_off)
    riscv64_emit_add(s, 7, 6, 10)
    riscv64_emit_sd(s, 7, 5, 0)
    riscv64_emit_mv(s, 10, 6)
    riscv64_emit_ret(s)
    return 0

// ── 9. Parser Utilities, Symbol Table & Scoping ───────────────────────────────

fn riscv64_synth_skip_whitespace_tokens toks pos_box
    // WHY: Advances token pointer past any empty newlines or comments.
    while get(pos_box, 0) < toks.len()
        k = toks[get(pos_box, 0)].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        else
            break
    return 0

fn riscv64_synth_find_fn s fname
    // WHY: Checks whether a user-defined function shadows an optional DICT0 map_* intrinsic.
    i = 0
    while i < s.rv_functions.len()
        if s.rv_functions[i].rv_fn_name == fname
            return s.rv_functions[i]
        i = i + 1
    return 0

fn riscv64_synth_find_struct s sname
    // WHY: Finds struct definition metadata by struct type name.
    i = 0
    while i < s.rv_structs.len()
        if s.rv_structs[i].rv_sd_name == sname
            return s.rv_structs[i]
        i = i + 1
    return 0

fn riscv64_synth_add_impl_method s tname mname
    i = 0
    while i < s.rv_impl_methods.len()
        ent = s.rv_impl_methods[i]
        if ent[0] == tname and ent[1] == mname
            return 0
        end
        i = i + 1
    end
    push(s.rv_impl_methods, [tname, mname])
    return 0

fn riscv64_synth_has_impl_method s tname mname
    i = 0
    while i < s.rv_impl_methods.len()
        ent = s.rv_impl_methods[i]
        if ent[0] == tname and ent[1] == mname
            return 1
        end
        i = i + 1
    end
    if riscv64_synth_find_fn(s, tname + "_" + mname) != 0
        return 1
    end
    return 0

fn riscv64_synth_find_method_candidates s mname
    out = list()
    i = 0
    while i < s.rv_impl_methods.len()
        ent = s.rv_impl_methods[i]
        if ent[1] == mname
            sd = riscv64_synth_find_struct(s, ent[0])
            tid = 0
            if sd != 0
                tid = sd.rv_sd_type_id
            end
            push(out, [tid, ent[0] + "_" + mname])
        end
        i = i + 1
    end
    return out

fn riscv64_synth_set_var_struct s name sname
    i = 0
    while i < s.rv_locals.len()
        if s.rv_locals[i].rv_lv_name == name
            s.rv_locals[i].rv_lv_struct_type = sname
            return 0
        end
        i = i + 1
    end
    return 0

fn riscv64_synth_get_var_struct s name
    i = 0
    while i < s.rv_locals.len()
        if s.rv_locals[i].rv_lv_name == name
            return s.rv_locals[i].rv_lv_struct_type
        end
        i = i + 1
    end
    return ""

fn riscv64_synth_find_fn_sig s fname
    if s.rv_fn_sigs == 0 return 0 end
    i = 0
    while i < s.rv_fn_sigs.len()
        if s.rv_fn_sigs[i].rv_sig_name == fname
            return s.rv_fn_sigs[i]
        end
        i = i + 1
    end
    return 0
end

fn riscv64_synth_prescan_decls s toks
    // WHY: Pre-populates struct/union schemas, impl/Type.method pairs, and function variadic/default
    // signatures before RV64 codegen so forward instantiation, dyn Trait, variadic, and default calls resolve.
    s.rv_source_toks = toks
    n = toks.len()
    i = 0
    impl_ctx = ""
    impl_col = 0
    impl_braced = 0
    impl_bd = 0
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF() break end
        if (k == TOK_DIR_TRAIT() or (k == TOK_IDENT() and (txt == "trait" or txt == "বৈশিষ্ট্য" or txt == "@trait"))) and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            tr_col = t.tok_span.span_start_col
            tr_line = t.tok_span.span_start_line
            i = i + 2
            tr_bd = 0
            tr_saw = 0
            while i < n
                tt = toks[i]
                if tt.tok_kind == TOK_EOF() break end
                if tt.tok_kind == TOK_LBRACE() or (tt.tok_kind != TOK_STR() and tt.tok_text == "{")
                    tr_bd = tr_bd + 1
                    tr_saw = 1
                elif tt.tok_kind == TOK_RBRACE() or (tt.tok_kind != TOK_STR() and tt.tok_text == "}")
                    if tr_bd > 0
                        tr_bd = tr_bd - 1
                        if tr_bd == 0 and tr_saw == 1
                            i = i + 1
                            break
                        end
                    end
                elif tr_saw == 0
                    if (tt.tok_kind == TOK_KW_END() or tt.tok_kind == TOK_DIR_END() or (tt.tok_kind == TOK_IDENT() and (tt.tok_text == "end" or tt.tok_text == "শেষ" or tt.tok_text == "@end"))) and tt.tok_span.span_start_col <= tr_col
                        i = i + 1
                        break
                    end
                    if tt.tok_span.span_start_line > tr_line and tt.tok_span.span_start_col <= tr_col and tt.tok_kind != TOK_NEWLINE()
                        break
                    end
                end
                i = i + 1
            end
            continue
        end
        is_su = 0
        is_u = 0
        if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT() or (k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct"))
            is_su = 1
        elif k == TOK_IDENT() and (txt == "union" or txt == "ইউনিয়ন" or txt == "@union")
            is_su = 1
            is_u = 1
        end
        if is_su == 1 and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            su_col = t.tok_span.span_start_col
            su_line = t.tok_span.span_start_line
            sname = toks[i + 1].tok_text
            sp = i + 2
            while sp < n and (toks[sp].tok_kind == TOK_NEWLINE() or toks[sp].tok_kind == TOK_COMMENT_LINE() or toks[sp].tok_kind == TOK_COMMENT_DOC() or toks[sp].tok_kind == TOK_COMMENT_BLOCK())
                sp = sp + 1
            end
            su_braced = 0
            if sp < n and (toks[sp].tok_kind == TOK_LBRACE() or toks[sp].tok_text == "{")
                su_braced = 1
                sp = sp + 1
            end
            flds = list()
            ftypes = list()
            while sp < n
                while sp < n and (toks[sp].tok_kind == TOK_NEWLINE() or toks[sp].tok_kind == TOK_SEMI() or toks[sp].tok_kind == TOK_COMMENT_LINE() or toks[sp].tok_kind == TOK_COMMENT_DOC() or toks[sp].tok_kind == TOK_COMMENT_BLOCK())
                    sp = sp + 1
                end
                if sp >= n break end
                ft = toks[sp]
                fk = ft.tok_kind
                fx = ft.tok_text
                if fk == TOK_EOF() break end
                if su_braced == 1
                    if fk == TOK_RBRACE() or fx == "}"
                        sp = sp + 1
                        break
                    end
                    if fk == TOK_COMMA() or fx == ","
                        sp = sp + 1
                        continue
                    end
                else
                    if fk == TOK_KW_END() or fk == TOK_DIR_END() or (fk == TOK_IDENT() and (fx == "end" or fx == "শেষ" or fx == "@end"))
                        sp = sp + 1
                        break
                    end
                    if ft.tok_span.span_start_line > su_line and ft.tok_span.span_start_col <= su_col
                        break
                    end
                end
                if fk == TOK_IDENT()
                    push(flds, fx)
                    ftype_nm = ""
                    sp = sp + 1
                    if sp < n and (toks[sp].tok_kind == TOK_COLON() or (toks[sp].tok_kind != TOK_STR() and toks[sp].tok_text == ":"))
                        sp = sp + 1
                        if sp < n and toks[sp].tok_kind == TOK_IDENT()
                            ftype_nm = toks[sp].tok_text
                            sp = sp + 1
                        end
                    end
                    push(ftypes, ftype_nm)
                else
                    sp = sp + 1
                end
            end
            if riscv64_synth_find_struct(s, sname) == 0
                sd_new = Riscv64StructDef()
                sd_new.rv_sd_name = sname
                sd_new.rv_sd_fields = flds
                sd_new.rv_sd_is_union = is_u
                sd_new.rv_sd_type_id = s.rv_next_type_id
                sd_new.rv_sd_field_types = ftypes
                s.rv_next_type_id = s.rv_next_type_id + 1
                push(s.rv_structs, sd_new)
            end
            i = sp
            continue
        end
        if (k == TOK_KW_IMPL() or k == TOK_DIR_IMPL() or (k == TOK_IDENT() and (txt == "impl" or txt == "বাস্তবায়ন" or txt == "@impl"))) and i + 1 < n
            ip = i + 1
            if ip < n and toks[ip].tok_text == "<"
                gd = 1
                ip = ip + 1
                while ip < n and gd > 0
                    if toks[ip].tok_text == "<" gd = gd + 1
                    elif toks[ip].tok_text == ">" gd = gd - 1 end
                    ip = ip + 1
                end
            end
            if ip < n and toks[ip].tok_kind == TOK_IDENT()
                imp_t = toks[ip].tok_text
                ip = ip + 1
                if ip < n and toks[ip].tok_text == "<"
                    gd = 1
                    ip = ip + 1
                    while ip < n and gd > 0
                        if toks[ip].tok_text == "<" gd = gd + 1
                        elif toks[ip].tok_text == ">" gd = gd - 1 end
                        ip = ip + 1
                    end
                end
                if ip < n and (toks[ip].tok_kind == TOK_KW_FOR() or toks[ip].tok_text == "for" or toks[ip].tok_text == "জন্য")
                    ip = ip + 1
                    if ip < n and toks[ip].tok_kind == TOK_IDENT()
                        imp_t = toks[ip].tok_text
                        ip = ip + 1
                    end
                    if ip < n and toks[ip].tok_text == "<"
                        gd = 1
                        ip = ip + 1
                        while ip < n and gd > 0
                            if toks[ip].tok_text == "<" gd = gd + 1
                            elif toks[ip].tok_text == ">" gd = gd - 1 end
                            ip = ip + 1
                        end
                    end
                end
                impl_ctx = imp_t
                impl_col = t.tok_span.span_start_col
                impl_braced = 0
                impl_bd = 0
                while ip < n and (toks[ip].tok_kind == TOK_NEWLINE() or toks[ip].tok_kind == TOK_COMMENT_LINE())
                    ip = ip + 1
                end
                if ip < n and (toks[ip].tok_kind == TOK_LBRACE() or toks[ip].tok_text == "{")
                    impl_braced = 1
                    impl_bd = 1
                    ip = ip + 1
                end
                i = ip
                continue
            end
        end
        if impl_ctx != ""
            if impl_braced == 1
                if k == TOK_LBRACE() or (k != TOK_STR() and txt == "{")
                    impl_bd = impl_bd + 1
                elif k == TOK_RBRACE() or (k != TOK_STR() and txt == "}")
                    impl_bd = impl_bd - 1
                    if impl_bd <= 0
                        impl_ctx = ""
                        impl_braced = 0
                        i = i + 1
                        continue
                    end
                end
            else
                if (k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "end" or txt == "শেষ" or txt == "@end"))) and t.tok_span.span_start_col <= impl_col
                    impl_ctx = ""
                    i = i + 1
                    continue
                elif t.tok_span.span_start_col <= impl_col and k != TOK_NEWLINE() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_BLOCK()
                    impl_ctx = ""
                end
            end
        end
        is_mfn = 0
        if k == TOK_KW_FN() or k == TOK_DIR_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn"))
            is_mfn = 1
        end
        if is_mfn == 1 and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            fn_nm = toks[i + 1].tok_text
            sig_full_nm = fn_nm
            sp_fn = i + 2
            if i + 3 < n and (toks[i + 2].tok_kind == TOK_DOT() or toks[i + 2].tok_text == ".") and toks[i + 3].tok_kind == TOK_IDENT()
                riscv64_synth_add_impl_method(s, fn_nm, toks[i + 3].tok_text)
                sig_full_nm = fn_nm + "_" + toks[i + 3].tok_text
                sp_fn = i + 4
            elif impl_ctx != ""
                riscv64_synth_add_impl_method(s, impl_ctx, fn_nm)
                sig_full_nm = impl_ctx + "_" + fn_nm
            end
            if sp_fn < n and toks[sp_fn].tok_text == "<"
                fgd = 1
                sp_fn = sp_fn + 1
                while sp_fn < n and fgd > 0
                    if toks[sp_fn].tok_text == "<" fgd = fgd + 1
                    elif toks[sp_fn].tok_text == ">" fgd = fgd - 1 end
                    sp_fn = sp_fn + 1
                end
            end
            if sp_fn < n and (toks[sp_fn].tok_kind == TOK_LPAREN() or toks[sp_fn].tok_text == "(")
                sp_fn = sp_fn + 1
                p_cnt = 0
                p_var = 0
                def_starts = list()
                cur_def = 0 - 1
                p_dep = 1
                in_p = 0
                while sp_fn < n and p_dep > 0
                    fk = toks[sp_fn].tok_kind
                    fx = toks[sp_fn].tok_text
                    if fk == TOK_LPAREN() or fk == TOK_LBRACKET() or fk == TOK_LBRACE()
                        p_dep = p_dep + 1
                        sp_fn = sp_fn + 1
                        continue
                    end
                    if fk == TOK_RPAREN() or fk == TOK_RBRACKET() or fk == TOK_RBRACE()
                        p_dep = p_dep - 1
                        if p_dep == 0
                            if in_p == 1
                                p_cnt = p_cnt + 1
                                push(def_starts, cur_def)
                            end
                            sp_fn = sp_fn + 1
                            break
                        end
                        sp_fn = sp_fn + 1
                        continue
                    end
                    if p_dep == 1
                        if fk == TOK_COMMA()
                            if in_p == 1
                                p_cnt = p_cnt + 1
                                push(def_starts, cur_def)
                            end
                            in_p = 0
                            cur_def = 0 - 1
                        elif in_p == 0
                            if fk == TOK_DOTDOT() and sp_fn + 1 < n and toks[sp_fn + 1].tok_kind == TOK_DOT()
                                p_var = 1
                                sp_fn = sp_fn + 2
                                if sp_fn < n and toks[sp_fn].tok_kind == TOK_IDENT()
                                    in_p = 1
                                end
                            elif fk == TOK_KW_MUT() or (fk == TOK_IDENT() and fx == "mut")
                                // skip mut
                            elif fk == TOK_IDENT()
                                in_p = 1
                            end
                        elif fk == TOK_COLON()
                            if sp_fn + 2 < n and toks[sp_fn + 1].tok_kind == TOK_DOTDOT() and toks[sp_fn + 2].tok_kind == TOK_DOT()
                                p_var = 1
                            end
                        elif fk == TOK_ASSIGN() and cur_def < 0
                            cur_def = sp_fn + 1
                        end
                    end
                    sp_fn = sp_fn + 1
                end
                sig_ret_t = ""
                if sp_fn < n and (toks[sp_fn].tok_kind == TOK_ARROW() or (toks[sp_fn].tok_kind != TOK_STR() and toks[sp_fn].tok_text == "->"))
                    sp_fn = sp_fn + 1
                    if sp_fn < n and toks[sp_fn].tok_kind == TOK_IDENT()
                        rt_nm = toks[sp_fn].tok_text
                        if riscv64_is_float_type(rt_nm) == 1
                            sig_ret_t = "float"
                        elif riscv64_is_uint_type(rt_nm) == 1
                            sig_ret_t = "uint"
                        elif rt_nm == "str" or rt_nm == "string"
                            sig_ret_t = "str"
                        end
                        sp_fn = sp_fn + 1
                    end
                end
                if p_var == 1 or p_cnt > 0 or sig_ret_t != ""
                    has_any_def = 0
                    di_s = 0
                    while di_s < def_starts.len()
                        if def_starts[di_s] >= 0 has_any_def = 1 end
                        di_s = di_s + 1
                    end
                    if p_var == 1 or has_any_def == 1 or sig_ret_t != ""
                        fs = Riscv64FnSig()
                        fs.rv_sig_name = sig_full_nm
                        fs.rv_sig_param_count = p_cnt
                        fs.rv_sig_is_variadic = p_var
                        fs.rv_sig_def_starts = def_starts
                        fs.rv_sig_ret_type = sig_ret_t
                        push(s.rv_fn_sigs, fs)
                    end
                end
                i = sp_fn
                continue
            end
            i = sp_fn
            continue
        end
        i = i + 1
    end
    return 0

fn riscv64_synth_get_field_offset s sname fname
    // WHY: Resolves the 8-byte scaled offset of struct field fname (unions always return offset 0).
    if sname != ""
        sdef = riscv64_synth_find_struct(s, sname)
        if sdef != 0
            f = 0
            while f < sdef.rv_sd_fields.len()
                if sdef.rv_sd_fields[f] == fname
                    if sdef.rv_sd_is_union == 1
                        return 0
                    end
                    return f * 8
                end
                f = f + 1
            end

    // Fallback 1: search across all defined structs
    i = 0
    while i < s.rv_structs.len()
        cur_def = s.rv_structs[i]
        f = 0
        while f < cur_def.rv_sd_fields.len()
            if cur_def.rv_sd_fields[f] == fname
                if cur_def.rv_sd_is_union == 1
                    return 0
                end
                return f * 8
            end
            f = f + 1
        end
        i = i + 1
    end

    // Fallback 2: search global fields registry
    gi = 0
    while gi < s.rv_global_fields.len()
        if s.rv_global_fields[gi] == fname
            return gi * 8
        gi = gi + 1
    push(s.rv_global_fields, fname)
    return (s.rv_global_fields.len() - 1) * 8

fn riscv64_synth_get_field_type s sname fname
    // WHY: Resolves declared field type (e.g. "f64", "u64", "str") so `.field` loads propagate FP/uint types.
    if sname != ""
        sdef = riscv64_synth_find_struct(s, sname)
        if sdef != 0 and sdef.rv_sd_field_types != 0
            f = 0
            while f < sdef.rv_sd_fields.len() and f < sdef.rv_sd_field_types.len()
                if sdef.rv_sd_fields[f] == fname
                    return sdef.rv_sd_field_types[f]
                end
                f = f + 1
            end
        end
    end
    i = 0
    while i < s.rv_structs.len()
        cur_def = s.rv_structs[i]
        if cur_def.rv_sd_field_types != 0
            f = 0
            while f < cur_def.rv_sd_fields.len() and f < cur_def.rv_sd_field_types.len()
                if cur_def.rv_sd_fields[f] == fname and cur_def.rv_sd_field_types[f] != ""
                    return cur_def.rv_sd_field_types[f]
                end
                f = f + 1
            end
        end
        i = i + 1
    end
    return ""

fn riscv64_synth_lookup_var s name
    // WHY: Finds SP-relative stack offset for variable identifier. Returns 0 if not found.
    i = 0
    while i < s.rv_locals.len()
        lv = s.rv_locals[i]
        if lv.rv_lv_name == name
            return lv.rv_lv_offset
        i = i + 1
    return 0

fn riscv64_synth_alloc_var s name
    // WHY: Allocates next 8-byte stack slot for variable name or returns existing offset.
    existing = riscv64_synth_lookup_var(s, name)
    if existing > 0
        return existing
    off = s.rv_stack_offset
    s.rv_stack_offset = s.rv_stack_offset + 8
    lv = Riscv64LocalVar()
    lv.rv_lv_name = name
    lv.rv_lv_offset = off
    lv.rv_lv_is_boxed = riscv64_is_boxed_name(s, name)
    lv.rv_lv_is_uint = 0
    lv.rv_lv_int_type = ""
    lv.rv_lv_prim_type = "int"
    lv.rv_lv_tag_off = 0
    lv.rv_lv_struct_type = ""
    push(s.rv_locals, lv)
    return off

fn riscv64_synth_alloc_tag_slot s lv
    // WHY: Lazily allocates an 8-byte runtime val_tag stack slot for dyn_tagged variables.
    if lv == 0
        return 0
    end
    if lv.rv_lv_tag_off > 0
        return lv.rv_lv_tag_off
    end
    off = s.rv_stack_offset
    s.rv_stack_offset = s.rv_stack_offset + 8
    lv.rv_lv_tag_off = off
    return off

fn riscv64_synth_rodata_push_u32 s val
    v = val
    if v < 0
        v = v + 4294967296
    end
    push(s.rv_rodata, v % 256)
    push(s.rv_rodata, (v / 256) % 256)
    push(s.rv_rodata, (v / 65536) % 256)
    push(s.rv_rodata, (v / 16777216) % 256)
    return 0

fn riscv64_synth_emit_lsym_rodata s
    // WHY: Serializes x86_64-identical LSYM0 symbol table ("LIPLSYM0") into RV64 .rodata
    // so stack_trace()/backtrace() resolves full call chains with real function names & line numbers.
    fn_starts = list()
    fn_ends = list()
    fn_name_offs = list()
    fn_lines = list()
    fi = 0
    while fi < s.rv_functions.len()
        fobj = s.rv_functions[fi]
        if fobj.rv_fn_entry_offset >= 0 and fobj.rv_fn_end_offset > fobj.rv_fn_entry_offset and fobj.rv_fn_name != ""
            n_ro = riscv64_synth_add_rodata_str(s, fobj.rv_fn_name, 0)
            push(fn_starts, fobj.rv_fn_entry_offset)
            push(fn_ends, fobj.rv_fn_end_offset)
            push(fn_name_offs, n_ro)
            push(fn_lines, fobj.rv_fn_decl_line)
        end
        fi = fi + 1
    end
    while (s.rv_rodata.len() % 8) != 0
        push(s.rv_rodata, 0)
    end
    lsym_off = s.rv_rodata.len()
    // Magic: "LIPLSYM0"
    push(s.rv_rodata, 76)
    push(s.rv_rodata, 73)
    push(s.rv_rodata, 80)
    push(s.rv_rodata, 76)
    push(s.rv_rodata, 83)
    push(s.rv_rodata, 89)
    push(s.rv_rodata, 77)
    push(s.rv_rodata, 48)
    fcnt = fn_starts.len()
    riscv64_synth_rodata_push_u32(s, fcnt)
    riscv64_synth_rodata_push_u32(s, 0)
    i = 0
    while i < fcnt
        riscv64_synth_rodata_push_u32(s, fn_starts[i])
        riscv64_synth_rodata_push_u32(s, fn_ends[i])
        riscv64_synth_rodata_push_u32(s, fn_name_offs[i])
        riscv64_synth_rodata_push_u32(s, fn_lines[i])
        riscv64_synth_rodata_push_u32(s, 0)
        riscv64_synth_rodata_push_u32(s, 0)
        i = i + 1
    end
    return lsym_off

fn riscv64_is_ident_token kind
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

fn riscv64_parse_float_bits s_text
    // WHY: Converts floating-point string literal (including scientific notation like 1.5e-4 or 2E10)
    // directly into standard IEEE-754 binary64 64-bit integer bit representation.
    // Pure integer arithmetic: zero libc, zero external dependencies, bit-exact.
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

