// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the Abstract Syntax Tree / Token Stream directly to executable AMD64
//    silicon instructions, eliminating any dependence on external assemblers (nasm,
//    as, clang, gcc).
// 2. High-Throughput Direct Synthesis: Generates raw opcode bytes in a single pass
//    with deterministic backpatching for branch targets, string addresses, loops,
//    conditionals, structs, and inter-procedural call sites.
// 3. Implements System V AMD64 ABI: Standard 16-byte stack frame alignment, RBP-based
//    local variable layout, and calling conventions (%rdi, %rsi, %rdx, %rcx, %r8, %r9).
// 4. Built-in Micro-Runtime Helpers: Synthesizes high-performance integer-to-ASCII
//    conversion and Linux SYS_write stdout routines directly into the user binary.
// 5. Complete Sovereign Control Flow: Emits direct silicon jumps for while/for loops,
//    if/elif/else branching trees, break/continue jump targets, struct field manipulation,
//    and Linux kernel SYS_mmap/SYS_exit/SYS_write syscalls with zero C runtime.
// ==============================================================================

import "utso/collections"
import "utso/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"

// ── 1. Data Models ────────────────────────────────────────────────────────────

// WHY: Records an absolute 64-bit virtual memory relocation for string constants
struct X86StringReloc
    sr_patch_offset     // Byte index in code_bytes where the 8-byte pointer is written
    sr_rodata_offset    // Byte index in rodata_bytes where the string payload starts

// WHY: Maps a local variable identifier to an RBP-relative stack offset or hardware register
struct X86LocalVar
    lv_name             // Variable name string
    lv_offset           // Positive offset in bytes: accessed as [rbp - lv_offset]
    lv_type             // Inferred struct type name string ("" if untyped)
    lv_prim_type        // Inferred primitive silicon type: "int", "str", or "" if dynamic
    lv_reg              // Assigned physical register ID (-1 if none or spilled)
    lv_is_spilled       // 1 if spilled to stack frame slot, 0 if held in physical register

// WHY: Records a function definition entry point for call site resolution
struct X86Function
    fn_name             // Function identifier
    fn_entry_offset     // Byte offset in code_bytes where the function prologue starts
    fn_ret_type         // Declared return type name string ("" if untyped)
    fn_end_offset       // Byte offset where the function body ends (for non-overlapping DWARF)
    fn_decl_line        // Source declaration line number (for DWARF DW_AT_decl_line)

// WHY: Records an unresolved 32-bit relative call displacement
struct X86CallReloc
    cr_patch_offset     // Byte index in code_bytes where 4-byte displacement is written
    cr_call_site_end    // Next instruction IP (cr_patch_offset + 4)
    cr_target_name      // Target function identifier or "__print_int"

// WHY: Models struct schema definitions and field member offsets
struct X86StructDef
    sd_name             // Struct type name string
    sd_fields           // List of field name strings
    sd_field_types      // Parallel list of declared/inferred field type strings

// WHY: Encapsulates mutable compilation state for AMD64 silicon code generation
struct X86Synthesizer
    synth_code          // List of machine code bytes (integers 0..255)
    synth_rodata        // List of read-only data bytes (.rodata segment)
    synth_str_relocs    // List of X86StringReloc structs
    synth_call_relocs   // List of X86CallReloc structs
    synth_locals        // List of X86LocalVar structs for current function frame
    synth_functions     // List of X86Function structs
    synth_stack_offset  // Next available local variable stack offset (8, 16, 24...)
    synth_needs_print_int // Flag: 1 if integer printing helper must be emitted
    synth_print_int_off // Byte offset where print_int helper is located
    synth_loop_starts   // Stack of loop header byte offsets for 'continue'
    synth_loop_breaks   // Stack of lists of break patch offsets
    synth_loop_continues // Stack of lists of continue patch offsets
    synth_structs       // List of X86StructDef structs
    synth_global_fields // List of global field name strings
    synth_needs_alloc   // Flag: 1 if bump allocator helper must be emitted
    synth_alloc_off     // Byte offset where bump allocator starts
    synth_is_str_off    // Byte offset where _lipi_is_str helper starts
    synth_argv_off      // Byte offset where lipi_fn_argv helper starts
    synth_slab_off      // Byte offset where _lipi_slab_buckets_ptr helper starts
    synth_called_top_level_main // Flag: 1 if main() or মূল() was called in top-level code
    synth_global_names  // List of top-level global / constant identifier names
    synth_global_vals   // List of top-level integer constant values
    synth_last_struct   // Struct type name of most recent constructor or record literal
    synth_last_expr_type // Type of most recent expression ("int", "str", or "")
    synth_regalloc_names // List of variable names mapped by SSA register allocation
    synth_regalloc_regs  // List of physical register IDs assigned by SSA register allocation
    synth_in_function   // 1 if currently compiling inside a function body, 0 at top level
    synth_current_fn    // Name string of currently compiling function ("" at top level)
    synth_ssa_lower_res // SsaLowerResult attached from Phase 6b SSA lowering
    synth_peep_offsets  // Verified basic-block instruction offsets eligible for peephole opt
    synth_peep_kinds    // Peephole pattern kinds (2=redundant disp8 load, 3=redundant disp32 load)
    synth_last_store_end // End offset of immediately preceding mov [rbp-off], rax in same basic block
    synth_last_store_off // Stack offset of immediately preceding mov [rbp-off], rax
    synth_rw_patch_offs // Byte offsets of u64 movabs immediates for RW globals & _is_str bounds
    synth_rw_patch_targets // File-relative (base 0) target offsets for Static-PIE RIP-relative conversion
    synth_exc_push_off  // Byte offset where _lipi_exc_push helper starts
    synth_exc_pop_off   // Byte offset where _lipi_exc_pop helper starts
    synth_exc_throw_off // Byte offset where _lipi_exc_throw helper starts
    synth_stack_bottom_off // Byte offset where _lipi_stack_bottom helper starts
    synth_heap_base_fn_off // Byte offset where _lipi_heap_base helper starts
    synth_heap_ptr_fn_off  // Byte offset where _lipi_heap_ptr helper starts
    synth_exc_slot_off     // Byte offset where _lipi_exc_slot_ptr per-thread helper starts
    synth_thread_spawn_j_off // Byte offset where _lipi_thread_spawn_joinable helper starts
    synth_mutable_globals  // List of mutable global variable names
    synth_mutable_global_offs // Parallel RW .data offsets (>= 512)
    synth_mutable_global_prims // Parallel primitive type strings ("int", "float", "str", "")
    synth_mutable_global_structs // Parallel struct type strings
    synth_global_rw_patch_offs // Code patch offsets of mutable global movabs imm64 instructions
    synth_global_rw_slot_offs  // Matching RW .data offsets (>= 512)
    synth_try_depth        // Current active nested try depth inside enclosing function/top-level
    synth_try_frames       // Stack of active try-finally unwind frames [flag_off, val_off, ret_patches, entry_depth]
    synth_loop_try_depths  // Stack of try depths captured on entry to enclosing loops
    synth_line_pcs         // Monotonic code byte offsets paired with DWARF source lines
    synth_line_nums        // Parallel 1-based source line numbers for .debug_line
    synth_current_fn_idx   // Index of active X86Function in synth_functions (-1 at top-level)
    synth_regalloc_buckets // 4096-bucket hash index over synth_regalloc_names
    synth_global_buckets   // 4096-bucket hash index over synth_global_names
    synth_fn_buckets       // 4096-bucket hash index over synth_functions

// ── 2. Constructor & Emitter Primitives ───────────────────────────────────────

fn x86_synth_hash4096 name
    // WHY: Deterministic FNV-1a-style 12-bit hash avoiding O(N) scans across 80k symbols.
    h = 2166136261
    n = len(name)
    i = 0
    while i < n
        h = ((h ^ ord(char_at(name, i))) * 16777619) & 2147483647
        i = i + 1
    return h & 4095

fn x86_synth_make_buckets_4096
    // WHY: Pre-allocates 4096 zero slots lazily populated on first bucket collision.
    b = list()
    i = 0
    while i < 4096
        push(b, 0)
        i = i + 1
    return b

fn x86_synth_bucket_insert buckets key idx
    h = x86_synth_hash4096(key)
    entry = buckets[h]
    if entry == 0
        entry = list()
        list_set(buckets, h, entry)
    push(entry, idx)
    return 0

fn x86_synth_register_fn_obj s fn_obj
    // WHY: Registers an X86Function in synth_functions AND its 4096-bucket O(1) hash index.
    idx = s.synth_functions.len()
    push(s.synth_functions, fn_obj)
    if s.synth_fn_buckets.len() == 4096
        x86_synth_bucket_insert(s.synth_fn_buckets, fn_obj.fn_name, idx)
    return idx

fn x86_synth_find_fn_first s name
    if s.synth_fn_buckets.len() == 4096
        ent = s.synth_fn_buckets[x86_synth_hash4096(name)]
        if ent == 0
            return 0
        bi = 0
        while bi < ent.len()
            idx = ent[bi]
            fn_item = s.synth_functions[idx]
            if fn_item.fn_name == name
                return fn_item
            bi = bi + 1
        return 0
    k = 0
    while k < s.synth_functions.len()
        fn_item = s.synth_functions[k]
        if fn_item.fn_name == name
            return fn_item
        k = k + 1
    return 0

fn x86_synth_find_fn_last_idx s name
    if s.synth_fn_buckets.len() == 4096
        ent = s.synth_fn_buckets[x86_synth_hash4096(name)]
        if ent == 0
            return 0 - 1
        bi = ent.len() - 1
        while bi >= 0
            idx = ent[bi]
            if s.synth_functions[idx].fn_name == name
                return idx
            bi = bi - 1
        return 0 - 1
    k = s.synth_functions.len() - 1
    while k >= 0
        if s.synth_functions[k].fn_name == name
            return k
        k = k - 1
    return 0 - 1

fn x86_synth_new
    // WHY: Allocates and initializes clean synthesizer state.
    s = X86Synthesizer()
    s.synth_code = list()
    s.synth_rodata = list()
    s.synth_str_relocs = list()
    s.synth_call_relocs = list()
    s.synth_locals = list()
    s.synth_functions = list()
    s.synth_stack_offset = 64
    s.synth_needs_print_int = 0
    s.synth_print_int_off = 0
    s.synth_loop_starts = list()
    s.synth_loop_breaks = list()
    s.synth_loop_continues = list()
    s.synth_structs = list()
    s.synth_global_fields = list()
    s.synth_needs_alloc = 0
    s.synth_alloc_off = 0
    s.synth_is_str_off = 0
    s.synth_argv_off = 0
    s.synth_slab_off = 0
    s.synth_called_top_level_main = 0
    s.synth_global_names = list()
    s.synth_global_vals = list()
    s.synth_last_struct = ""
    s.synth_last_expr_type = ""
    s.synth_regalloc_names = list()
    s.synth_regalloc_regs = list()
    s.synth_in_function = 0
    s.synth_current_fn = ""
    s.synth_ssa_lower_res = 0
    s.synth_peep_offsets = list()
    s.synth_peep_kinds = list()
    s.synth_last_store_end = 0 - 1
    s.synth_last_store_off = 0
    s.synth_rw_patch_offs = list()
    s.synth_rw_patch_targets = list()
    s.synth_exc_push_off = 0
    s.synth_exc_pop_off = 0
    s.synth_exc_throw_off = 0
    s.synth_stack_bottom_off = 0
    s.synth_heap_base_fn_off = 0
    s.synth_heap_ptr_fn_off = 0
    s.synth_exc_slot_off = 0
    s.synth_thread_spawn_j_off = 0
    s.synth_mutable_globals = list()
    s.synth_mutable_global_offs = list()
    s.synth_mutable_global_prims = list()
    s.synth_mutable_global_structs = list()
    s.synth_global_rw_patch_offs = list()
    s.synth_global_rw_slot_offs = list()
    s.synth_try_depth = 0
    s.synth_try_frames = list()
    s.synth_loop_try_depths = list()
    s.synth_line_pcs = list()
    s.synth_line_nums = list()
    s.synth_current_fn_idx = 0 - 1
    s.synth_regalloc_buckets = list()
    s.synth_global_buckets = x86_synth_make_buckets_4096()
    s.synth_fn_buckets = x86_synth_make_buckets_4096()
    return s

fn x86_synth_emit_byte s byte_val
    // WHY: Emits a single raw machine instruction byte into code_bytes.
    push(s.synth_code, (byte_val % 256 + 256) % 256)
    return s.synth_code.len()

fn x86_synth_emit_bytes s byte_list
    // WHY: Appends an array of byte values sequentially.
    i = 0
    n = byte_list.len()
    while i < n
        push(s.synth_code, (byte_list[i] % 256 + 256) % 256)
        i = i + 1
    return s.synth_code.len()

fn x86_synth_emit_u32 s val
    // WHY: Emits 32-bit unsigned integer in little-endian byte order.
    v = val
    if v < 0
        v = v + 4294967296
    push(s.synth_code, v % 256)
    push(s.synth_code, (v / 256) % 256)
    push(s.synth_code, (v / 65536) % 256)
    push(s.synth_code, (v / 16777216) % 256)
    return s.synth_code.len()

fn x86_synth_emit_u64 s val
    // WHY: Emits 64-bit integer in little-endian byte order.
    v = val
    i = 0
    while i < 8
        b = v % 256
        if b < 0
            b = b + 256
        push(s.synth_code, b)
        v = (v - b) / 256
        i = i + 1
    return s.synth_code.len()

fn x86_synth_patch_u32 s offset val
    // WHY: Backpatches 4 bytes at a predetermined location in code_bytes.
    // Also invalidates basic-block store-forwarding state since a jump target was bound here.
    s.synth_last_store_end = 0 - 1
    v = val
    if v < 0
        v = v + 4294967296
    list_set(s.synth_code, offset, v % 256)
    list_set(s.synth_code, offset + 1, (v / 256) % 256)
    list_set(s.synth_code, offset + 2, (v / 65536) % 256)
    list_set(s.synth_code, offset + 3, (v / 16777216) % 256)
    return 0

fn x86_synth_patch_u64 s offset val
    // WHY: Backpatches 8 bytes for 64-bit absolute virtual address relocations.
    v = val
    i = 0
    while i < 8
        b = v % 256
        if b < 0
            b = b + 256
        list_set(s.synth_code, offset + i, b)
        v = (v - b) / 256
        i = i + 1
    return 0

fn x86_synth_record_reloc_patch s u64_patch_off file_target_off
    // WHY: Records exact relocated movabs imm64 sites (RW globals & .rodata bounds)
    // so Static-PIE conversion transforms ONLY verified relocations, never literal constants.
    push(s.synth_rw_patch_offs, u64_patch_off)
    push(s.synth_rw_patch_targets, file_target_off)
    return 0

fn x86_synth_patch_lea_rip s u64_patch_off target_file_off text_file_off
    // WHY: Rewrites a 10-byte movabs r64, imm64 (48/49 B8..BF <u64>) into an ASLR-safe
    // 10-byte RIP-relative lea r64, [rip + disp32]; nop; nop; nop sequence for Static-PIE.
    inst_off = u64_patch_off - 2
    if inst_off < 0 or u64_patch_off + 8 > s.synth_code.len()
        return 0
    end
    rex = s.synth_code[inst_off]
    op = s.synth_code[inst_off + 1]
    if (rex == 72 or rex == 73) and op >= 184 and op <= 191
        reg = op - 184
        new_rex = 72
        if rex == 73
            new_rex = 76
        end
        disp32 = target_file_off - (text_file_off + inst_off + 7)
        list_set(s.synth_code, inst_off + 0, new_rex)
        list_set(s.synth_code, inst_off + 1, 141)
        list_set(s.synth_code, inst_off + 2, 5 + (reg * 8))
        x86_synth_patch_u32(s, inst_off + 3, disp32)
        list_set(s.synth_code, inst_off + 7, 144)
        list_set(s.synth_code, inst_off + 8, 144)
        list_set(s.synth_code, inst_off + 9, 144)
    end
    return 0

fn x86_synth_convert_to_pie s
    // WHY: Converts all recorded .rodata and RW global relocations in s.synth_code to
    // position-independent RIP-relative addressing for strict W^X ET_DYN (Static-PIE) ASLR.
    text_file_off = 304
    ro_file_off = text_file_off + s.synth_code.len()
    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        x86_synth_patch_lea_rip(s, rel.sr_patch_offset, ro_file_off + rel.sr_rodata_offset, text_file_off)
        ri = ri + 1
    end
    gi = 0
    while gi < s.synth_rw_patch_offs.len()
        p_off = s.synth_rw_patch_offs[gi]
        t_off = s.synth_rw_patch_targets[gi]
        x86_synth_patch_lea_rip(s, p_off, t_off, text_file_off)
        gi = gi + 1
    end
    return 0

fn x86_synth_lookup_fn_ret_type s fn_name
    // WHY: Returns the declared return type name of fn_name via O(1) bucket index.
    fn_item = x86_synth_find_fn_first(s, fn_name)
    if fn_item != 0
        rt = fn_item.fn_ret_type
        if rt != 0 and rt != ""
            return rt
        end
    end
    return ""

include "src/compiler/backend/targets/x86_64/runtime_helpers.lp"
include "src/compiler/backend/targets/x86_64/runtime_io.lp"
include "src/compiler/backend/targets/x86_64/avx2_encoder.lp"
include "src/compiler/backend/targets/x86_64/amx_vnni_encoder.lp"
include "src/compiler/backend/targets/x86_64/runtime_arena.lp"
include "src/compiler/backend/targets/x86_64/silicon_opt.lp"

// ── 3. Read-Only Data (.rodata) Management ────────────────────────────────────

fn x86_synth_add_rodata_str s str_text with_newline
    // WHY: Prepend 8-byte STR0 header (lower 32-bit length, upper 32-bit 0x53545230 'STR0')
    // so all emitted string literals are instantly recognized by runtime helpers in 1 CPU cycle.
    slen = len(str_text)
    if with_newline == 1
        slen = slen + 1
    push(s.synth_rodata, slen % 256)
    push(s.synth_rodata, (slen / 256) % 256)
    push(s.synth_rodata, (slen / 65536) % 256)
    push(s.synth_rodata, (slen / 16777216) % 256)
    push(s.synth_rodata, 48)  // '0'
    push(s.synth_rodata, 82)  // 'R'
    push(s.synth_rodata, 84)  // 'T'
    push(s.synth_rodata, 83)  // 'S'

    start_off = s.synth_rodata.len()
    i = 0
    raw_len = len(str_text)
    while i < raw_len
        c = char_at(str_text, i)
        push(s.synth_rodata, ord(c))
        i = i + 1
    if with_newline == 1
        push(s.synth_rodata, 10) // '\n'
    push(s.synth_rodata, 0)      // Null-terminator
    return start_off

// ── 4. AMD64 Machine Instruction Primitives ───────────────────────────────────

fn x86_synth_emit_mov_reg_reg s dst_reg src_reg
    // WHY: Emits native AMD64 64-bit register-to-register move (mov r64_dst, r64_src).
    // Calculates REX prefix for extended registers (r8..r15) and standard ModR/M byte.
    // Self-moves (dst_reg == src_reg) are eliminated as 0-cycle no-ops.
    if dst_reg == src_reg
        return 0
    rex = 72 // 0x48 (REX.W)
    if src_reg >= 8
        rex = rex + 4 // REX.R (bit 2) extends ModR/M reg field
    if dst_reg >= 8
        rex = rex + 1 // REX.B (bit 0) extends ModR/M r/m field
    raw_src = src_reg % 8
    raw_dst = dst_reg % 8
    modrm = 192 + (raw_src * 8) + raw_dst // 0xC0 + (src * 8) + dst
    x86_synth_emit_byte(s, rex)
    x86_synth_emit_byte(s, 137) // 0x89: mov r/m64, r64
    x86_synth_emit_byte(s, modrm)
    return 0

fn x86_synth_emit_mov_rax_imm64 s val
    // WHY: Emits 64-bit immediate load into %rax: movabs rax, imm64 (0x48 0xB8 <u64>)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 184)
    x86_synth_emit_u64(s, val)
    return 0

fn x86_synth_emit_mov_rdi_imm64 s val
    // WHY: Emits 64-bit immediate load into %rdi: movabs rdi, imm64 (0x48 0xBF <u64>)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 191)
    x86_synth_emit_u64(s, val)
    return 0

fn x86_synth_emit_prologue s
    // WHY: Sets up standard 16-byte aligned AMD64 stack frame with full callee-saved register preservation:
    s.synth_last_store_end = 0 - 1
    //      push rbp          (0x55)
    //      mov rbp, rsp      (0x48 0x89 0xE5)
    //      push r12          (0x41 0x54) - Callee-saved register 12
    //      push r13          (0x41 0x55) - Callee-saved register 13
    //      push r14          (0x41 0x56) - Callee-saved register 14
    //      push r15          (0x41 0x57) - Callee-saved register 15
    //      push rbx          (0x53)       - Callee-saved register 3
    //      sub rsp, 8        (0x48 0x83 0xEC 0x08) - 16-byte stack alignment (6 * 8 = 48 bytes pushed)
    //      sub rsp, 4096     (0x48 0x81 0xEC <disp32>) -> Per-activation local frame space
    x86_synth_emit_byte(s, 85)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 137)
    x86_synth_emit_byte(s, 229)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 84)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 85)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 86)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 87)
    x86_synth_emit_byte(s, 83)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 131)
    x86_synth_emit_byte(s, 236)
    x86_synth_emit_byte(s, 8)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 129)
    x86_synth_emit_byte(s, 236)
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 4096)
    return patch_pos

fn x86_synth_emit_epilogue s
    // WHY: Restores stack pointer, callee-saved registers, and caller frame:
    //      lea rsp, [rbp - 40] (0x48 0x8D 0x65 0xD8) - Points rsp to saved rbx without clobbering rax
    //      pop rbx             (0x5B)
    //      pop r15             (0x41 0x5F)
    //      pop r14             (0x41 0x5E)
    //      pop r13             (0x41 0x5D)
    //      pop r12             (0x41 0x5C)
    //      pop rbp             (0x5D)
    //      ret                 (0xC3)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 141)
    x86_synth_emit_byte(s, 101)
    x86_synth_emit_byte(s, 216)
    x86_synth_emit_byte(s, 91)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 95)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 94)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 93)
    x86_synth_emit_byte(s, 65)
    x86_synth_emit_byte(s, 92)
    x86_synth_emit_byte(s, 93)
    x86_synth_emit_byte(s, 195)
    return 0

fn x86_synth_emit_print_string s str_val
    // WHY: Emits Linux SYS_write(1, &str, len) for string literals:
    //      mov eax, 1         (0xB8 0x01 0x00 0x00 0x00) -> 5 bytes
    //      mov edi, 1         (0xBF 0x01 0x00 0x00 0x00) -> 5 bytes
    //      movabs rsi, imm64  (0x48 0xBE [8 bytes vaddr]) -> 10 bytes
    //      mov edx, len       (0xBA [4 bytes len])       -> 5 bytes
    //      syscall            (0x0F 0x05)                -> 2 bytes
    ro_off = x86_synth_add_rodata_str(s, str_val, 1)
    str_len = len(str_val) + 1 // Includes appended newline

    // mov eax, 1
    x86_synth_emit_byte(s, 184)
    x86_synth_emit_u32(s, 1)

    // mov edi, 1
    x86_synth_emit_byte(s, 191)
    x86_synth_emit_u32(s, 1)

    // movabs rsi, imm64
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 190)
    patch_pos = s.synth_code.len()
    x86_synth_emit_u64(s, 0) // Placeholder to be resolved during ELF packaging

    // Record string relocation
    rel = X86StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    push(s.synth_str_relocs, rel)

    // mov edx, len
    x86_synth_emit_byte(s, 186)
    x86_synth_emit_u32(s, str_len)

    // syscall
    x86_synth_emit_byte(s, 15)
    x86_synth_emit_byte(s, 5)
    return 0

fn x86_synth_emit_call_print_int s
    // WHY: Calls the centralized _print_int_helper routine to format and display %rax.
    s.synth_needs_print_int = 1
    call_off = s.synth_code.len()
    x86_synth_emit_byte(s, 232) // CALL rel32
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 0)    // Placeholder

    call_rel = X86CallReloc()
    call_rel.cr_patch_offset = patch_pos
    call_rel.cr_call_site_end = patch_pos + 4
    call_rel.cr_target_name = "__print_int"
    push(s.synth_call_relocs, call_rel)
    return 0

fn x86_synth_emit_print_int_helper s
    // WHY: Pure AMD64 assembly routine converting 64-bit signed integer in %rax
    // to ASCII decimal string on the stack and writing to stdout with trailing newline.
    // Preserves zero-dependency sovereign execution standard.
    s.synth_print_int_off = s.synth_code.len()

    helper_bytes = [
        85,                                  // push rbp
        72, 137, 229,                        // mov rbp, rsp
        72, 131, 236, 48,                    // sub rsp, 48
        198, 69, 255, 10,                    // mov byte [rbp - 1], 10 (newline)
        76, 141, 69, 255,                    // lea r8, [rbp - 1]
        65, 185, 1, 0, 0, 0,                 // mov r9d, 1 (len = 1)
        72, 133, 192,                        // test rax, rax
        117, 12,                             // jne .check_neg (+12)
        73, 255, 200,                        // dec r8
        65, 198, 0, 48,                      // mov byte [r8], '0'
        73, 255, 193,                        // inc r9
        235, 63,                             // jmp .do_write (+63)
        69, 49, 210,                         // .check_neg: xor r10d, r10d
        72, 131, 248, 0,                     // cmp rax, 0
        125, 9,                              // jge .loop_digits (+9)
        65, 186, 1, 0, 0, 0,                 // mov r10d, 1
        72, 247, 216,                        // neg rax
        72, 133, 192,                        // .loop_digits: test rax, rax
        116, 24,                             // jz .finish_digits (+24)
        49, 210,                             // xor edx, edx
        185, 10, 0, 0, 0,                    // mov ecx, 10
        72, 247, 241,                        // div rcx
        128, 194, 48,                        // add dl, '0'
        73, 255, 200,                        // dec r8
        65, 136, 16,                         // mov byte [r8], dl
        73, 255, 193,                        // inc r9
        235, 227,                            // jmp .loop_digits (-29)
        65, 131, 250, 1,                     // .finish_digits: cmp r10d, 1
        117, 10,                             // jne .do_write (+10)
        73, 255, 200,                        // dec r8
        65, 198, 0, 45,                      // mov byte [r8], '-'
        73, 255, 193,                        // inc r9
        184, 1, 0, 0, 0,                     // .do_write: mov eax, 1 (SYS_write)
        191, 1, 0, 0, 0,                     // mov edi, 1 (STDOUT)
        76, 137, 198,                        // mov rsi, r8 (buf pointer)
        76, 137, 202,                        // mov rdx, r9 (length)
        15, 5,                               // syscall
        72, 137, 236,                        // mov rsp, rbp
        93,                                  // pop rbp
        195                                  // ret
    ]

    x86_synth_emit_bytes(s, helper_bytes)
    return 0

fn x86_synth_emit_call_alloc s
    // WHY: Emits a near call to the native _lipi_alloc_helper bump allocator.
    s.synth_needs_alloc = 1
    call_off = s.synth_code.len()
    x86_synth_emit_byte(s, 232) // CALL rel32
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 0)

    call_rel = X86CallReloc()
    call_rel.cr_patch_offset = patch_pos
    call_rel.cr_call_site_end = patch_pos + 4
    call_rel.cr_target_name = "__alloc"
    push(s.synth_call_relocs, call_rel)
    return 0

fn x86_synth_emit_alloc_helper s
    // WHY: Emits pure AMD64 silicon bump-arena memory allocator with zero libc dependency.
    // Thread-safe: guards lazy 4GB SYS_mmap initialization with spinlock at [rdx + 104] (rw+120)
    // and double-checked [rdx], then bumps [rdx + 8] atomically via lock xadd.
    // Inputs: %rdi = requested byte size. Output: %rax = pointer to allocated memory.
    s.synth_alloc_off = s.synth_code.len()
    alloc_bytes = [
        72, 131, 199, 15,                     // add rdi, 15 (align up to 16 bytes)
        72, 131, 231, 240,                    // and rdi, -16
        72, 186, 0, 0, 0, 0, 0, 0, 0, 0,      // movabs rdx, <rw_vaddr + 16> (patched at +10)
        72, 139, 2,                           // mov rax, [rdx]
        72, 133, 192,                         // test rax, rax
        117, 69,                              // jnz .allocated (+69 to index 95)
        240, 72, 15, 186, 106, 104, 0,        // .spin: lock bts qword [rdx + 104], 0
        114, 247,                             // jc .spin
        72, 139, 2,                           // mov rax, [rdx]
        72, 133, 192,                         // test rax, rax
        117, 45,                              // jnz .unlock (+45 to index 88)
        87,                                   // push rdi
        82,                                   // push rdx
        49, 255,                              // xor edi, edi (addr = 0)
        190, 0, 240, 255, 255,                // mov esi, 4294963200 (4GB virtual memory arena, 0xfffff000)
        106, 3, 90, 144,                      // push 3; pop rdx; nop (PROT_READ | PROT_WRITE = 3)
        65, 186, 34, 0, 0, 0,                 // mov r10d, 34 (MAP_PRIVATE | MAP_ANON)
        73, 199, 192, 255, 255, 255, 255,     // mov r8, -1
        69, 49, 201,                          // xor r9d, r9d
        184, 9, 0, 0, 0,                      // mov eax, 9 (sys_mmap)
        15, 5,                                // syscall
        90,                                   // pop rdx
        95,                                   // pop rdi
        72, 137, 2,                           // mov [rdx], rax (save arena base to _heap_base)
        72, 137, 66, 8,                       // mov [rdx + 8], rax (initialize _heap_ptr)
        240, 72, 15, 186, 114, 104, 0,        // .unlock: lock btr qword [rdx + 104], 0
        72, 137, 248,                         // .allocated: mov rax, rdi (index 95)
        240, 72, 15, 193, 66, 8,              // lock xadd [rdx + 8], rax (atomic bump allocation)
        195                                   // ret
    ]
    x86_synth_emit_bytes(s, alloc_bytes)
    return 0

fn x86_synth_skip_whitespace_tokens toks pos_box
    // WHY: Advances token pointer across all non-semantic tokens (newlines, semicolons, comments).
    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        tk = toks[p]
        k = tk.tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, p + 1)
        else
            break
    return 0

fn x86_synth_find_struct s sname
    // WHY: Returns X86StructDef if sname is a registered struct, or 0 if not.
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        if sd.sd_name == sname
            return sd
        i = i + 1
    return 0

fn x86_synth_scan_brace_keys toks start_pos
    // WHY: Forward-scans an anonymous or struct literal { key: val, ... } to extract top-level field names for schema deduction
    keys = list()
    scan_p = start_pos
    depth = 1
    while scan_p < toks.len()
        st = toks[scan_p]
        st_k = st.tok_kind
        st_txt = st.tok_text
        if st_k == TOK_LBRACE() or (st_k == TOK_IDENT() and st_txt == "{") or st_txt == "{"
            depth = depth + 1
        elif st_k == TOK_RBRACE() or (st_k == TOK_IDENT() and st_txt == "}") or st_txt == "}"
            depth = depth - 1
            if depth == 0
                break
        elif depth == 1 and (st_k == TOK_IDENT() or st_k == TOK_STR())
            np = scan_p + 1
            while np < toks.len()
                ntk = toks[np]
                if ntk.tok_kind == TOK_NEWLINE() or ntk.tok_kind == TOK_SEMI() or ntk.tok_kind == TOK_COMMENT_DOC() or ntk.tok_kind == TOK_COMMENT_LINE() or ntk.tok_kind == TOK_COMMENT_BLOCK() or ntk.tok_text == "\n" or ntk.tok_text == ";"
                    np = np + 1
                else
                    break
            if np < toks.len() and (toks[np].tok_kind == TOK_COLON() or toks[np].tok_text == ":")
                push(keys, st_txt)
        scan_p = scan_p + 1
    return keys

fn x86_synth_find_matching_struct s keys
    // WHY: Matches a set of field names against all declared struct schemas.
    // Prefers exact field-count matches on declared named structs while preserving
    // forward schema order for unified anonymous AST node layouts.
    if keys.len() == 0
        return ""
    best_name = ""
    best_match_count = 0
    best_exact_named = 0
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        match_count = 0
        k = 0
        while k < keys.len()
            key = keys[k]
            f = 0
            while f < sd.sd_fields.len()
                if sd.sd_fields[f] == key
                    match_count = match_count + 1
                    break
                f = f + 1
            k = k + 1
        if match_count == keys.len()
            is_anon = 0
            if len(sd.sd_name) > 8 and str_sub(sd.sd_name, 0, 8) == "_anon_s_"
                is_anon = 1
            end
            is_exact_named = 0
            if is_anon == 0 and sd.sd_fields.len() == keys.len()
                is_exact_named = 1
            end
            if (is_exact_named == 1 and best_exact_named == 0) or (is_exact_named == best_exact_named and match_count > best_match_count)
                best_match_count = match_count
                best_exact_named = is_exact_named
                best_name = sd.sd_name
            end
        i = i + 1
    return best_name

fn x86_synth_get_field_offset s sname fname
    // WHY: Determines the 8-byte aligned memory offset for struct field access.
    if sname != ""
        i = s.synth_structs.len() - 1
        while i >= 0
            sd = s.synth_structs[i]
            if sd.sd_name == sname
                fi = 0
                while fi < sd.sd_fields.len()
                    if sd.sd_fields[fi] == fname
                        return fi * 8
                    end
                    fi = fi + 1
                end
            end
            i = i - 1
        end
    end

    // Fallback pass 1: search declared named structs first (skip _anon_s_*)
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        is_anon = 0
        if len(sd.sd_name) > 8 and str_sub(sd.sd_name, 0, 8) == "_anon_s_"
            is_anon = 1
        end
        if is_anon == 0
            fi = 0
            while fi < sd.sd_fields.len()
                if sd.sd_fields[fi] == fname
                    return fi * 8
                fi = fi + 1
            end
        end
        i = i + 1
    end

    // Fallback pass 2: search across all registered struct schemas (including anonymous)
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        fi = 0
        while fi < sd.sd_fields.len()
            if sd.sd_fields[fi] == fname
                return fi * 8
            fi = fi + 1
        end
        i = i + 1
    end

    // Fallback: search or allocate in global fields
    fi = 0
    while fi < s.synth_global_fields.len()
        if s.synth_global_fields[fi] == fname
            return fi * 8
        fi = fi + 1
    push(s.synth_global_fields, fname)
    return (s.synth_global_fields.len() - 1) * 8

fn x86_synth_get_field_type s sname fname
    // WHY: Resolves declared/inferred field type name for nested struct & float type propagation.
    if sname != ""
        i = s.synth_structs.len() - 1
        while i >= 0
            sd = s.synth_structs[i]
            if sd.sd_name == sname
                fi = 0
                while fi < sd.sd_fields.len()
                    if sd.sd_fields[fi] == fname
                        if fi < sd.sd_field_types.len()
                            return sd.sd_field_types[fi]
                        end
                        return ""
                    end
                    fi = fi + 1
                end
            end
            i = i - 1
        end
    end
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        is_anon = 0
        if len(sd.sd_name) > 8 and str_sub(sd.sd_name, 0, 8) == "_anon_s_"
            is_anon = 1
        end
        if is_anon == 0
            fi = 0
            while fi < sd.sd_fields.len()
                if sd.sd_fields[fi] == fname
                    if fi < sd.sd_field_types.len()
                        return sd.sd_field_types[fi]
                    end
                    return ""
                end
                fi = fi + 1
            end
        end
        i = i + 1
    end
    return ""

fn x86_synth_is_mutable_global_name name
    // WHY: Treats top-level `g_*` variables as cross-function mutable RW globals.
    if len(name) >= 2 and char_at(name, 0) == "g" and char_at(name, 1) == "_"
        return 1
    end
    return 0

fn x86_synth_find_mutable_global s name
    // WHY: Returns RW .data offset (>= 512) if name is registered as a mutable global, or 0 otherwise.
    i = 0
    n = s.synth_mutable_globals.len()
    while i < n
        if s.synth_mutable_globals[i] == name
            return s.synth_mutable_global_offs[i]
        end
        i = i + 1
    end
    return 0

fn x86_synth_alloc_mutable_global s name
    // WHY: Allocates an 8-byte RW .data slot at offset 512..4088 for cross-function mutable globals.
    existing = x86_synth_find_mutable_global(s, name)
    if existing >= 512
        return existing
    end
    slot_off = 512 + (s.synth_mutable_globals.len() * 8)
    if slot_off >= 4096
        return 0
    end
    push(s.synth_mutable_globals, name)
    push(s.synth_mutable_global_offs, slot_off)
    push(s.synth_mutable_global_prims, "")
    push(s.synth_mutable_global_structs, "")
    return slot_off

fn x86_synth_set_mutable_global_types s name ptype stype
    i = 0
    n = s.synth_mutable_globals.len()
    while i < n
        if s.synth_mutable_globals[i] == name
            if ptype != ""
                list_set(s.synth_mutable_global_prims, i, ptype)
            end
            if stype != ""
                list_set(s.synth_mutable_global_structs, i, stype)
            end
            return 1
        end
        i = i + 1
    end
    return 0

fn x86_synth_get_mutable_global_prim s name
    i = 0
    n = s.synth_mutable_globals.len()
    while i < n
        if s.synth_mutable_globals[i] == name
            return s.synth_mutable_global_prims[i]
        end
        i = i + 1
    end
    return ""

fn x86_synth_get_mutable_global_struct s name
    i = 0
    n = s.synth_mutable_globals.len()
    while i < n
        if s.synth_mutable_globals[i] == name
            return s.synth_mutable_global_structs[i]
        end
        i = i + 1
    end
    return ""

fn x86_synth_emit_mutable_global_read s slot_off
    // WHY: Emits movabs rax, <rw+slot_off>; mov rax, [rax] and records relocation for Static-PIE / PE / Mach-O.
    if slot_off < 512
        return 0
    end
    x86_synth_emit_bytes(s, [72, 184])
    p_off = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    push(s.synth_global_rw_patch_offs, p_off)
    push(s.synth_global_rw_slot_offs, slot_off)
    x86_synth_emit_bytes(s, [72, 139, 0]) // mov rax, [rax]
    return 1

fn x86_synth_emit_mutable_global_write s slot_off
    // WHY: Emits movabs rcx, <rw+slot_off>; mov [rcx], rax (value in %rax preserved) with RW relocation.
    if slot_off < 512
        return 0
    end
    x86_synth_emit_bytes(s, [72, 185])
    p_off = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    push(s.synth_global_rw_patch_offs, p_off)
    push(s.synth_global_rw_slot_offs, slot_off)
    x86_synth_emit_bytes(s, [72, 137, 1]) // mov [rcx], rax
    return 1

// ── 5. Local Variable & Scope Management ──────────────────────────────────────

fn x86_synth_lookup_var s name
    // WHY: Searches current frame's local variable table. Returns offset or 0 if not found.
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            return v.lv_offset
        i = i + 1
    return 0

fn x86_synth_find_local_var s name
    // WHY: Searches current frame's local variable table and returns X86LocalVar object or 0
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            return v
        i = i + 1
    return 0

fn x86_synth_set_var_reg s name reg_id
    // WHY: Associates variable with physical hardware register from linear scan allocator
    v = x86_synth_find_local_var(s, name)
    if v != 0
        v.lv_reg = reg_id
        if reg_id >= 0
            v.lv_is_spilled = 0
        else
            v.lv_is_spilled = 1
        return 1
    return 0

fn x86_synth_lookup_var_reg s name
    // WHY: Returns assigned physical register ID for variable, or -1 if spilled/unmapped
    v = x86_synth_find_local_var(s, name)
    if v != 0
        return v.lv_reg
    return 0 - 1

fn x86_synth_alloc_reg_var s name is_reg_hint
    // WHY: Allocates next 8-byte stack slot for variable name or returns existing offset.
    // Assigns an authentic AMD64 callee-saved hardware register (%r12-%r15, %rbx) if:
    // 1. Matched to an SSA linear scan register allocation interval.
    // 2. Explicitly requested via 'reg', '@reg', or 'রেজিস্টার' declaration keywords.
    existing = x86_synth_find_local_var(s, name)
    if existing != 0
        if is_reg_hint == 1 and existing.lv_reg < 0
            cand_regs = [12, 13, 14, 15, 3]
            ci = 0
            while ci < cand_regs.len()
                cr = cand_regs[ci]
                reg_conflict = 0
                li = 0
                while li < s.synth_locals.len()
                    other = s.synth_locals[li]
                    if other.lv_is_spilled == 0 and other.lv_reg == cr
                        reg_conflict = 1
                    end
                    li = li + 1
                end
                if reg_conflict == 0
                    existing.lv_reg = cr
                    existing.lv_is_spilled = 0
                    break
                end
                ci = ci + 1
            end
        end
        return existing.lv_offset
    end

    off = s.synth_stack_offset
    s.synth_stack_offset = s.synth_stack_offset + 8
    lv = X86LocalVar()
    lv.lv_name = name
    lv.lv_offset = off
    lv.lv_type = ""
    lv.lv_prim_type = ""
    lv.lv_reg = 0 - 1
    lv.lv_is_spilled = 1

    // 1. Check if variable was assigned a physical register by SSA linear scan allocation
    target_key = name
    if s.synth_in_function == 1 and len(s.synth_current_fn) > 0
        target_key = s.synth_current_fn + "::" + name
    end
    if s.synth_regalloc_names.len() > 0
        if s.synth_regalloc_buckets.len() == 4096
            ra_ent = s.synth_regalloc_buckets[x86_synth_hash4096(target_key)]
            if ra_ent != 0
                rbi = 0
                while rbi < ra_ent.len()
                    ri = ra_ent[rbi]
                    if s.synth_regalloc_names[ri] == target_key
                        assigned_r = s.synth_regalloc_regs[ri]
                        if assigned_r == 12 or assigned_r == 13 or assigned_r == 14 or assigned_r == 15 or assigned_r == 3
                            reg_conflict = 0
                            ci = 0
                            while ci < s.synth_locals.len()
                                other_lv = s.synth_locals[ci]
                                if other_lv.lv_is_spilled == 0 and other_lv.lv_reg == assigned_r
                                    reg_conflict = 1
                                end
                                ci = ci + 1
                            end
                            if reg_conflict == 0
                                lv.lv_reg = assigned_r
                                lv.lv_is_spilled = 0
                                break
                            end
                        end
                    end
                    rbi = rbi + 1
                end
            end
        else
            ri = 0
            while ri < s.synth_regalloc_names.len()
                rname = s.synth_regalloc_names[ri]
                if rname == target_key
                    assigned_r = s.synth_regalloc_regs[ri]
                    if assigned_r == 12 or assigned_r == 13 or assigned_r == 14 or assigned_r == 15 or assigned_r == 3
                        reg_conflict = 0
                        ci = 0
                        while ci < s.synth_locals.len()
                            other_lv = s.synth_locals[ci]
                            if other_lv.lv_is_spilled == 0 and other_lv.lv_reg == assigned_r
                                reg_conflict = 1
                            end
                            ci = ci + 1
                        end
                        if reg_conflict == 0
                            lv.lv_reg = assigned_r
                            lv.lv_is_spilled = 0
                            break
                        end
                    end
                end
                ri = ri + 1
            end
        end
    end

    // 2. If explicitly declared as register variable or pinned induction variable,
    // allocate next available callee-saved register (%r12-%r15, %rbx)
    if lv.lv_reg < 0 and is_reg_hint == 1
        cand_regs = [12, 13, 14, 15, 3]
        ci = 0
        while ci < cand_regs.len()
            cr = cand_regs[ci]
            reg_conflict = 0
            li = 0
            while li < s.synth_locals.len()
                other = s.synth_locals[li]
                if other.lv_is_spilled == 0 and other.lv_reg == cr
                    reg_conflict = 1
                end
                li = li + 1
            end
            if reg_conflict == 0
                lv.lv_reg = cr
                lv.lv_is_spilled = 0
                break
            end
            ci = ci + 1
        end
    end

    push(s.synth_locals, lv)
    return off

fn x86_synth_alloc_var s name
    return x86_synth_alloc_reg_var(s, name, 0)

fn x86_synth_emit_load_var s reg_id off
    // WHY: Emits machine code to load a 64-bit local variable from [rbp - off] into specified register.
    // Seamlessly handles arbitrary stack frame sizes via ModR/M disp8 (off <= 128) or disp32 (off > 128).
    // Records basic-block-verified redundant store-to-load pairs for silicon_opt.lp O(K) elimination.
    load_start = s.synth_code.len()
    is_redundant = 0
    if reg_id == 0 and s.synth_last_store_end == load_start and s.synth_last_store_off == off
        is_redundant = 1
    end
    s.synth_last_store_end = 0 - 1
    if off <= 128
        disp8 = (256 - (off % 256)) % 256
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 139)
        modrm = 64 + (reg_id * 8) + 5
        x86_synth_emit_byte(s, modrm)
        x86_synth_emit_byte(s, disp8)
        if is_redundant == 1
            push(s.synth_peep_offsets, load_start)
            push(s.synth_peep_kinds, 2)
        end
    else
        disp32 = 0 - off
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 139)
        modrm = 128 + (reg_id * 8) + 5
        x86_synth_emit_byte(s, modrm)
        x86_synth_emit_u32(s, disp32)
        if is_redundant == 1
            push(s.synth_peep_offsets, load_start)
            push(s.synth_peep_kinds, 3)
        end
    return 0

fn x86_synth_emit_store_var s reg_id off
    // WHY: Emits machine code to store a 64-bit register into local variable stack slot [rbp - off].
    // Seamlessly handles arbitrary stack frame sizes via ModR/M disp8 (off <= 128) or disp32 (off > 128).
    // Register mapping: 0=%rax, 1=%rcx, 2=%rdx, 6=%rsi, 7=%rdi
    if off <= 128
        disp8 = (256 - (off % 256)) % 256
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 137)
        modrm = 64 + (reg_id * 8) + 5
        x86_synth_emit_byte(s, modrm)
        x86_synth_emit_byte(s, disp8)
    else
        disp32 = 0 - off
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 137)
        modrm = 128 + (reg_id * 8) + 5
        x86_synth_emit_byte(s, modrm)
        x86_synth_emit_u32(s, disp32)
    if reg_id == 0
        s.synth_last_store_end = s.synth_code.len()
        s.synth_last_store_off = off
    else
        s.synth_last_store_end = 0 - 1
    return 0

fn x86_synth_set_var_type s name type_name
    // WHY: Associates a local variable with a struct schema type for deterministic field offset lookup
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            v.lv_type = type_name
            return 0
        i = i + 1
    return 0

fn x86_synth_get_var_type s name
    // WHY: Resolves the struct type name of a local variable for struct-aware member access
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            if v.lv_type != 0
                return v.lv_type
            return ""
        i = i + 1
    return ""

fn x86_synth_set_prim_type s name prim_type
    // WHY: Tracks primitive silicon types ("int", "str") for register allocation and 1-cycle ALU emission
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            v.lv_prim_type = prim_type
            return 0
        i = i + 1
    return 0

fn x86_synth_get_prim_type s name
    // WHY: Returns the known primitive type of a variable, or "" if dynamic/unknown
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            if v.lv_prim_type != 0
                return v.lv_prim_type
            return ""
        i = i + 1
    return ""

fn x86_synth_bind_reg_var s var_name is_reg
    // WHY: Binds expression result in %rax to local variable. If variable is assigned a physical
    // register by SSA linear scan or explicit register declaration, emits 1-cycle direct mov into that register;
    // otherwise stores to stack frame slot.
    off = x86_synth_alloc_reg_var(s, var_name, is_reg)
    lv = x86_synth_find_local_var(s, var_name)
    if lv != 0 and lv.lv_is_spilled == 0 and lv.lv_reg >= 0
        // WHY: When allocated to a hardware register (%r12-%r15, %rbx) and unspilled,
        // move directly into physical register without redundant shadow stack writes.
        x86_synth_emit_mov_reg_reg(s, lv.lv_reg, 0)
    else
        x86_synth_emit_store_var(s, 0, off)
    end
    if s.synth_last_struct != ""
        x86_synth_set_var_type(s, var_name, s.synth_last_struct)
        s.synth_last_struct = ""
    return off

fn x86_synth_bind_var s var_name
    return x86_synth_bind_reg_var(s, var_name, 0)

// ── 6. Global Constant Registry ───────────────────────────────────────────────

fn x86_synth_set_global_const s name val
    // WHY: Registers top-level constant in O(1) via 4096-bucket hash index.
    if s.synth_global_buckets.len() == 4096
        ent = s.synth_global_buckets[x86_synth_hash4096(name)]
        if ent != 0
            bi = 0
            while bi < ent.len()
                idx = ent[bi]
                if s.synth_global_names[idx] == name
                    list_set(s.synth_global_vals, idx, val)
                    return 0
                bi = bi + 1
        new_idx = s.synth_global_names.len()
        push(s.synth_global_names, name)
        push(s.synth_global_vals, val)
        x86_synth_bucket_insert(s.synth_global_buckets, name, new_idx)
        return 0
    i = 0
    while i < s.synth_global_names.len()
        if s.synth_global_names[i] == name
            list_set(s.synth_global_vals, i, val)
            return 0
        i = i + 1
    push(s.synth_global_names, name)
    push(s.synth_global_vals, val)
    return 0

fn x86_synth_lookup_global_const s name
    // WHY: O(1) hashed lookup for registered top-level compile-time integer constants.
    if s.synth_global_buckets.len() == 4096
        ent = s.synth_global_buckets[x86_synth_hash4096(name)]
        if ent == 0
            return 0 - 999999999
        bi = 0
        while bi < ent.len()
            idx = ent[bi]
            if s.synth_global_names[idx] == name
                return s.synth_global_vals[idx]
            bi = bi + 1
        return 0 - 999999999
    i = 0
    while i < s.synth_global_names.len()
        if s.synth_global_names[i] == name
            return s.synth_global_vals[i]
        i = i + 1
    return 0 - 999999999

fn x86_synth_is_ident_token kind
    // WHY: In Lipi grammar, contextual keywords such as 'end', 'in', 'type', 'case', 'match',
    // 'mut', 'async', 'await', 'try', 'catch', 'defer', 'print', and 'syscall' are valid identifier
    // names when used in parameter declarations, local variables, struct fields, and assignment targets.
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

fn x86_synth_should_stop_inline toks pos_box start_line
    // WHY: Allows single-line multi-statement directive blocks (`@while cond s1 s2 @end`)
    // to continue consuming statements on start_line until `@end` or line end.
    np = get(pos_box, 0)
    if np >= toks.len()
        return 1
    end
    nt = toks[np]
    nk = nt.tok_kind
    if nk == TOK_NEWLINE() or nk == TOK_SEMI() or nk == TOK_COMMENT_LINE() or nk == TOK_EOF()
        return 1
    end
    if nt.tok_span.span_start_line > start_line
        return 1
    end
    return 0

fn x86_synth_is_block_end toks p
    // WHY: Distinguishes between block-terminating keyword ('end', 'শেষ', '@end') and
    // contextual identifiers / assignments to variables named 'end' (e.g. 'end = slen', 'end > slen').
    if p >= toks.len() return 0
    t = toks[p]
    k = t.tok_kind
    txt = t.tok_text
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "end" or txt == "শেষ" or txt == "@end"))
        next_p = p + 1
        if next_p < toks.len()
            nt = toks[next_p]
            if nt.tok_kind == TOK_ASSIGN() or nt.tok_text == "="
                return 0
        return 1
    return 0

fn x86_synth_compile_struct_def s toks pos_box base_col base_line
    // WHY: Registers user-defined struct schemas with ordered field offsets in compiler state.
    pos = get(pos_box, 0)
    list_set(pos_box, 0, pos + 1) // Consume 'struct'

    sname_tok = toks[get(pos_box, 0)]
    sname = sname_tok.tok_text
    list_set(pos_box, 0, get(pos_box, 0) + 1)

    fields = list()
    field_types = list()
    while get(pos_box, 0) < toks.len()
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p >= toks.len()
            break
        cur_t = toks[cur_p]
        cur_k = cur_t.tok_kind
        cur_txt = cur_t.tok_text

        if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
            list_set(pos_box, 0, cur_p + 1)
            break
        if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_STRUCT() or cur_k == TOK_DIR_STRUCT() or cur_k == TOK_DIR_ENUM()
            break
        if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "struct" or cur_txt == "গঠন" or cur_txt == "enum" or cur_txt == "@enum" or cur_txt == "গণনা")
            break
        if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
            break

        if cur_k == TOK_IDENT()
            push(fields, cur_txt)
            ftype = ""
            list_set(pos_box, 0, cur_p + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            np = get(pos_box, 0)
            if np < toks.len() and (toks[np].tok_kind == TOK_COLON() or (toks[np].tok_kind != TOK_STR() and toks[np].tok_text == ":"))
                list_set(pos_box, 0, np + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_IDENT() or toks[get(pos_box, 0)].tok_text == "string" or toks[get(pos_box, 0)].tok_text == "i64" or toks[get(pos_box, 0)].tok_text == "f64" or toks[get(pos_box, 0)].tok_text == "array" or toks[get(pos_box, 0)].tok_text == "bool")
                    ftype = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            push(field_types, ftype)
        else
            list_set(pos_box, 0, cur_p + 1)

    sdef = X86StructDef()
    sdef.sd_name = sname
    sdef.sd_fields = fields
    sdef.sd_field_types = field_types
    push(s.synth_structs, sdef)
    return 0

fn x86_synth_emit_store_param s pi off
    // WHY: Stores incoming argument register (0..11) to local stack slot [rbp - off]
    // Follows LiPi 12-register calling convention (rdi, rsi, rdx, rcx, r8, r9, r10, r11, r12, r13, r14, r15)
    if pi == 0
        x86_synth_emit_store_var(s, 7, off) // %rdi
    elif pi == 1
        x86_synth_emit_store_var(s, 6, off) // %rsi
    elif pi == 2
        x86_synth_emit_store_var(s, 2, off) // %rdx
    elif pi == 3
        x86_synth_emit_store_var(s, 1, off) // %rcx
    elif pi >= 4 and pi < 12
        modrm_disp8 = 69 + (pi - 4) * 8
        modrm_disp32 = 133 + (pi - 4) * 8
        if off <= 128
            disp8 = (256 - (off % 256)) % 256
            x86_synth_emit_byte(s, 76)  // REX.R (0x4C)
            x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
            x86_synth_emit_byte(s, modrm_disp8)
            x86_synth_emit_byte(s, disp8)
        else
            disp32 = 0 - off
            x86_synth_emit_byte(s, 76)  // REX.R (0x4C)
            x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
            x86_synth_emit_byte(s, modrm_disp32)
            x86_synth_emit_u32(s, disp32)
    return 0

fn x86_synth_emit_pop_args s arg_count
    // WHY: Pops up to 12 arguments in reverse LIFO order into LiPi calling convention registers
    ai = arg_count - 1
    while ai >= 0
        if ai == 0
            x86_synth_emit_byte(s, 95) // pop rdi (0x5F)
        elif ai == 1
            x86_synth_emit_byte(s, 94) // pop rsi (0x5E)
        elif ai == 2
            x86_synth_emit_byte(s, 90) // pop rdx (0x5A)
        elif ai == 3
            x86_synth_emit_byte(s, 89) // pop rcx (0x59)
        elif ai >= 4 and ai < 12
            x86_synth_emit_byte(s, 65) // REX.B prefix (0x41)
            x86_synth_emit_byte(s, 88 + (ai - 4)) // pop r8..r15 (0x58..0x5F)
        else
            x86_synth_emit_byte(s, 88) // pop rax (discard extra stack arguments)
        ai = ai - 1
    if arg_count == 1
        // WHY: For single-argument function calls, explicitly zero %rsi (xor esi, esi: 0x31, 0xF6).
        // This guarantees that functions supporting optional second arguments (like free(ptr [, size]))
        // or varargs don't inherit non-zero garbage in %rsi from previous computations.
        x86_synth_emit_byte(s, 49) // xor esi, esi (0x31)
        x86_synth_emit_byte(s, 246) // 0xF6
    return 0

fn x86_synth_parse_float_bits s_text
    // WHY: Converts floating-point string literal (e.g. "1.9", "2.9", "100.5", "-0.25")
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

    // Split into integer and fractional parts
    int_part = 0
    frac_part = 0
    frac_digits = 0
    dot_seen = 0

    idx = start
    while idx < s_len
        c = char_at(s_text, idx)
        if c == "."
            dot_seen = 1
        else
            code = ord(c)
            if code >= 48 and code <= 57
                d = code - 48
                if dot_seen == 0
                    int_part = (int_part * 10) + d
                else
                    frac_part = (frac_part * 10) + d
                    frac_digits = frac_digits + 1
                end
            end
        end
        idx = idx + 1
    end

    if int_part == 0 and frac_part == 0
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end

    // Compute denominator = 10^frac_digits
    den = 1
    k = 0
    while k < frac_digits
        den = den * 10
        k = k + 1
    end

    num = (int_part * den) + frac_part

    exp = 1023
    while num >= (den * 2)
        den = den * 2
        exp = exp + 1
    end
    while num < den
        num = num * 2
        exp = exp - 1
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

    // Rounding: check guard bit
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



