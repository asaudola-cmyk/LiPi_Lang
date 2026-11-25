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
    lv_elem_type        // Inferred list/array element primitive type ("float", "int", "str", "dyn_dict", or "")
    lv_is_boxed         // 1 if local is heap-boxed in an 8-byte GC upvalue cell for mutable closure capture
    lv_tag_off          // Positive RBP-relative offset for runtime val_tag when lv_prim_type == "dyn_tagged" (0 if unused)

// WHY: Records a function definition entry point for call site resolution
struct X86Function
    fn_name             // Function identifier
    fn_entry_offset     // Byte offset in code_bytes where the function prologue starts
    fn_ret_type         // Declared return type name string ("" if untyped)
    fn_end_offset       // Byte offset where the function body ends (for non-overlapping DWARF)
    fn_decl_line        // Source declaration line number (for DWARF DW_AT_decl_line)
    fn_param_count      // Declared parameter count (-1 if helper/unknown, >=0 for user fns)
    fn_tok_pos          // Source token index of `fn` keyword (-1 for runtime helpers / mono clones)
    fn_param_types      // Parallel list of explicit declared parameter type strings ("", "float", ...)
    fn_type_params      // Generic type parameter names (e.g. ["T", "U"]), empty for non-generic fns

// WHY: Records an unresolved 32-bit relative call displacement
struct X86CallReloc
    cr_patch_offset     // Byte index in code_bytes where 4-byte displacement is written
    cr_call_site_end    // Next instruction IP (cr_patch_offset + 4)
    cr_target_name      // Target function identifier or "__print_int"

// WHY: Models struct schema definitions with exact hardware byte offsets, fixed-width sizes,
// packed layout, explicit alignment, and inline fixed-size arrays ([N]T).
struct X86StructDef
    sd_name             // Struct type name string
    sd_fields           // List of field name strings
    sd_field_types      // Parallel list of declared/inferred field type strings
    sd_type_params      // Generic type parameter names (e.g. ["T"]), empty for concrete structs
    sd_field_offsets    // Parallel list of exact byte offsets for each field
    sd_field_sizes      // Parallel list of exact byte sizes (1/2/4/8 or N*elem_sz)
    sd_field_elem_sizes // Parallel list of element byte sizes (0 for scalar, 1/2/4/8 for [N]T)
    sd_field_signed     // Parallel list: 1 for signed (i8/i16/i32/i64), 0 for unsigned (u8/u16/u32/u64)
    sd_is_packed        // 1 if annotated @packed (zero inter-field padding), 0 for natural alignment
    sd_align            // Effective struct alignment in bytes (default 8, or explicit @align(N))
    sd_total_size       // Exact total byte size of struct (used by compile-time sizeof(T) & alloc)

// WHY: Models Algebraic Data Type (Tagged Enum) & C-style Integer Enum schemas
struct X86EnumDef
    ed_name             // Enum type name string ("Result", "Option", "Shape")
    ed_variants         // List of variant name strings (["Ok", "Err"])
    ed_arities          // Parallel list of payload field counts ([1, 1])
    ed_field_types      // Parallel list of lists of payload type strings ([["T"], ["E"]])
    ed_is_adt           // 1 if tagged ADT enum (heap ADT0 cells), 0 if pure integer enum
    ed_type_params      // Generic type parameter names (["T", "E"])

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
    synth_defer_starts     // List of deferred statement start token indices in current function
    synth_defer_ends       // Parallel list of deferred statement end token indices in current function
    synth_emitting_defer   // 1 while replaying deferred statements before function exit
    synth_last_elem_type   // Element primitive or struct type of most recent array/list ("float", "User", "")
    synth_strict_types     // 1 when --strict-types enforces zero ambiguous struct field offsets
    synth_ambiguous_count  // Count of untyped colliding struct field accesses observed
    synth_boxed_vars       // Local variable names boxed into 8B GC upvalue cells for mutable closures
    synth_globals_rw_ptr_patch // Patch offset for movabs rax, <rw_vaddr + 488> (_gc_globals_bytes)
    synth_globals_rw_len_patch // Patch offset for movabs rcx, <globals_byte_span>
    synth_mono_name_override   // Forced mangled function name during call-site float/generic monomorphization
    synth_mono_param_override  // Forced parameter type list during call-site float/generic monomorphization
    synth_mono_ret_override    // Forced return type string during generic monomorphization
    synth_enums                // List of X86EnumDef schemas (tagged ADTs & enums)
    synth_has_defer_unwind     // 1 if current function pushed an exception unwind frame for defer
    synth_defer_mask_off       // Positive RBP-relative offset of 64-bit executed-defer bitmask
    synth_defer_err_off        // Positive RBP-relative offset saving thrown exception across defer replay
    synth_in_defer_unwind_pad  // 1 while emitting Defer Unwind Pad (exc frame already popped by _lipi_exc_throw)
    synth_lsym_ptrs_off        // Byte offset of _lipi_lsym_ptrs helper for zero-overhead LSYM0 stack traces
    synth_freestanding         // 1 in --freestanding / --no-runtime / bare-metal mode (0 Linux syscalls)
    synth_base_vaddr           // Configurable base virtual address (default 0x40000000; supports 0x100000 & 0xFFFFFFFF80000000)
    synth_code_file_off        // File offset where synth_code starts (304 for standard ELF, 0 for raw-bin/freestanding custom)
    synth_pending_fn_naked     // 1 when @naked precedes next fn definition
    synth_pending_fn_interrupt // 1 when @interrupt precedes next fn definition
    synth_in_interrupt_fn      // 1 while compiling inside an @interrupt handler (return emits iretq)
    synth_in_naked_fn          // 1 while compiling inside a @naked function (omits prologue/epilogue)
    synth_pending_struct_packed // 1 when @packed precedes next struct definition
    synth_pending_struct_align  // Explicit alignment (>0) when @align(N) precedes next struct or @bss
    synth_bss_names            // Static @bss buffer variable names
    synth_bss_offs             // Byte offsets relative to RW segment start (placed after mutable globals)
    synth_bss_sizes            // Exact total byte sizes of @bss buffers
    synth_bss_elem_sizes       // Element byte size for [N]T @bss arrays (0 for scalar/struct)
    synth_bss_signed           // Signedness (1=signed, 0=unsigned) for @bss array elements
    synth_bss_structs          // Struct type name if @bss holds a static struct instance
    synth_bss_cursor           // Next available byte offset inside @bss area (relative to bss base)
    synth_bss_patch_offs       // Code patch offsets for movabs imm64 referencing @bss addresses
    synth_bss_patch_idxs       // Parallel index into synth_bss_offs for each patch site
    synth_layout_base          // Optional base address declared in source via @layout(base=0x...)
    synth_layout_stack         // Optional stack size declared in source via @layout(stack=...)
    synth_fn_tag_offs          // Allocated lv_tag_off stack slots in current fn (zeroed by prologue stub)
    synth_fn_dyn_vars          // Multi-write variables prescanned as dyn_tagged candidates in current fn

global g_x86_strict_types = 0
global g_x86_freestanding = 0
global g_x86_base_vaddr = 1073741824
global g_x86_code_file_off = 304
global g_x86_ssa_codegen = 0

fn x86_synth_set_strict_types flag
    g_x86_strict_types = flag
    return flag

fn x86_synth_set_freestanding flag
    g_x86_freestanding = flag
    return flag

fn x86_synth_set_base_vaddr vaddr
    g_x86_base_vaddr = vaddr
    return vaddr

fn x86_synth_set_code_file_off foff
    g_x86_code_file_off = foff
    return foff

fn x86_synth_set_ssa_codegen flag
    g_x86_ssa_codegen = flag
    return flag

fn x86_synth_is_match_start toks pos
    // WHY: Soft-keyword disambiguation for `match` / `মিল` / `মেলাও` / `@match`.
    // Preserves variables named `match` (`match = 1`, `if match == 1`, `return match`)
    // while reliably recognizing both statement and value-returning match expressions.
    if pos < 0 or pos + 1 >= toks.len()
        return 0
    end
    t0 = toks[pos]
    k0 = t0.tok_kind
    txt0 = t0.tok_text
    if k0 != TOK_KW_MATCH() and k0 != TOK_DIR_MATCH() and not (k0 == TOK_IDENT() and (txt0 == "match" or txt0 == "মিল" or txt0 == "মেলাও" or txt0 == "@match"))
        return 0
    end
    t1 = toks[pos + 1]
    k1 = t1.tok_kind
    txt1 = t1.tok_text
    if t1.tok_span.span_start_line != t0.tok_span.span_start_line
        return 0
    end
    // Allowlist valid scrutinee-starting tokens (rejects =, ==, !=, +, -, <, >, ), ], ,, and, or, return, etc.)
    ok_start = 0
    if k1 == TOK_INT() or k1 == TOK_FLOAT() or k1 == TOK_BOOL() or k1 == TOK_STR() or k1 == TOK_INTERP_STR() or k1 == TOK_LPAREN() or k1 == TOK_LBRACKET() or k1 == TOK_BANG() or k1 == TOK_TILDE() or k1 == TOK_MINUS()
        ok_start = 1
    elif x86_synth_is_ident_token(k1) == 1
        if txt1 != "and" and txt1 != "or" and txt1 != "এবং" and txt1 != "অথবা" and txt1 != "return" and txt1 != "break" and txt1 != "continue" and txt1 != "end" and txt1 != "else" and txt1 != "elif" and txt1 != "then" and txt1 != "in"
            ok_start = 1
        end
    end
    if ok_start == 0
        return 0
    end
    // Lookahead past scrutinee: confirm `{` on same line OR `case`/`=>`/`->`/`:` on next arm line
    line0 = t0.tok_span.span_start_line
    si = pos + 1
    while si < toks.len()
        st = toks[si]
        sk = st.tok_kind
        if sk == TOK_NEWLINE() or st.tok_span.span_start_line > line0
            break
        end
        if sk == TOK_LBRACE() or (sk != TOK_STR() and st.tok_text == "{")
            return 1
        end
        si = si + 1
    end
    while si < toks.len()
        sk = toks[si].tok_kind
        if sk == TOK_NEWLINE() or sk == TOK_SEMI() or sk == TOK_COMMENT_LINE() or sk == TOK_COMMENT_BLOCK()
            si = si + 1
        else
            break
        end
    end
    if si >= toks.len()
        return 0
    end
    at0 = toks[si]
    if at0.tok_kind == TOK_LBRACE() or at0.tok_text == "{" or at0.tok_kind == TOK_KW_CASE() or (at0.tok_kind == TOK_IDENT() and (at0.tok_text == "case" or at0.tok_text == "ক্ষেত্র"))
        return 1
    end
    arm_line = at0.tok_span.span_start_line
    steps = 0
    while si < toks.len() and steps < 16
        at = toks[si]
        if at.tok_kind == TOK_NEWLINE() or at.tok_span.span_start_line != arm_line
            break
        end
        if at.tok_kind == TOK_FAT_ARROW() or at.tok_kind == TOK_ARROW() or at.tok_kind == TOK_COLON() or (at.tok_kind != TOK_STR() and (at.tok_text == "=>" or at.tok_text == "->" or at.tok_text == ":"))
            return 1
        end
        si = si + 1
        steps = steps + 1
    end
    return 0
end

fn x86_synth_is_region_start toks pos
    // WHY: Soft-keyword disambiguation for `region` / `অঞ্চল` / `@region`.
    // Only starts a scoped memory region block when followed by newline, `{`, or EOF.
    if pos < 0 or pos >= toks.len()
        return 0
    end
    t0 = toks[pos]
    if t0.tok_kind != TOK_IDENT() or (t0.tok_text != "region" and t0.tok_text != "অঞ্চল" and t0.tok_text != "@region")
        return 0
    end
    if pos + 1 >= toks.len()
        return 1
    end
    t1 = toks[pos + 1]
    if t1.tok_kind == TOK_NEWLINE() or t1.tok_kind == TOK_COMMENT_LINE() or t1.tok_kind == TOK_LBRACE() or (t1.tok_kind != TOK_STR() and t1.tok_text == "{") or t1.tok_span.span_start_line > t0.tok_span.span_start_line
        return 1
    end
    return 0
end

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
    s.synth_defer_starts = list()
    s.synth_defer_ends = list()
    s.synth_emitting_defer = 0
    s.synth_last_elem_type = ""
    s.synth_strict_types = g_x86_strict_types
    s.synth_ambiguous_count = 0
    s.synth_boxed_vars = list()
    s.synth_globals_rw_ptr_patch = 0
    s.synth_globals_rw_len_patch = 0
    s.synth_mono_name_override = ""
    s.synth_mono_param_override = 0
    s.synth_mono_ret_override = ""
    s.synth_enums = list()
    s.synth_has_defer_unwind = 0
    s.synth_defer_mask_off = 0
    s.synth_defer_err_off = 0
    s.synth_in_defer_unwind_pad = 0
    s.synth_lsym_ptrs_off = 0
    s.synth_freestanding = g_x86_freestanding
    s.synth_base_vaddr = g_x86_base_vaddr
    s.synth_code_file_off = g_x86_code_file_off
    s.synth_pending_fn_naked = 0
    s.synth_pending_fn_interrupt = 0
    s.synth_in_interrupt_fn = 0
    s.synth_in_naked_fn = 0
    s.synth_pending_struct_packed = 0
    s.synth_pending_struct_align = 0
    s.synth_bss_names = list()
    s.synth_bss_offs = list()
    s.synth_bss_sizes = list()
    s.synth_bss_elem_sizes = list()
    s.synth_bss_signed = list()
    s.synth_bss_structs = list()
    s.synth_bss_cursor = 0
    s.synth_bss_patch_offs = list()
    s.synth_bss_patch_idxs = list()
    s.synth_layout_base = 0
    s.synth_layout_stack = 0
    s.synth_fn_tag_offs = list()
    s.synth_fn_dyn_vars = list()
    return s

fn x86_synth_emit_store_imm64_to_var s off imm32
    // WHY: Writes sign-extended 32-bit immediate (e.g. val_tag 0/1/2) directly to [rbp - off]
    // using `mov qword [rbp - off], imm32` (REX.W C7 /0 id) — clobbers ZERO registers and ZERO flags.
    if off <= 128
        disp8 = (256 - (off % 256)) % 256
        x86_synth_emit_bytes(s, [72, 199, 69, disp8])
        x86_synth_emit_u32(s, imm32)
    else
        x86_synth_emit_bytes(s, [72, 199, 133])
        x86_synth_emit_u32(s, 0 - off)
        x86_synth_emit_u32(s, imm32)
    end
    return 0

fn x86_synth_emit_tag_init_stub_if_needed s tag_init_patch
    // WHY: Guarantees zero uninitialized stack garbage in any lazily-allocated lv_tag_off slot.
    // Functions with 0 dyn_tagged slots keep the 5-byte prologue NOP (zero bytes, zero writes);
    // functions with >=1 dyn_tagged slots patch the NOP to `call stub` that zeroes every tag slot.
    if tag_init_patch < 0 or s.synth_fn_tag_offs == 0 or s.synth_fn_tag_offs.len() == 0
        return 0
    end
    stub_off = s.synth_code.len()
    list_set(s.synth_code, tag_init_patch, 232) // 0xE8: call rel32
    x86_synth_patch_u32(s, tag_init_patch + 1, stub_off - (tag_init_patch + 5))
    ti = 0
    tn = s.synth_fn_tag_offs.len()
    while ti < tn
        x86_synth_emit_store_imm64_to_var(s, s.synth_fn_tag_offs[ti], 0)
        ti = ti + 1
    end
    x86_synth_emit_byte(s, 195) // ret
    return 0

fn x86_synth_is_dyn_var s name
    if s.synth_fn_dyn_vars == 0
        return 0
    end
    di = 0
    dn = s.synth_fn_dyn_vars.len()
    while di < dn
        if s.synth_fn_dyn_vars[di] == name
            return 1
        end
        di = di + 1
    end
    return 0

fn x86_synth_dyn_list_has lst name
    i = 0
    n = lst.len()
    while i < n
        if lst[i] == name
            return 1
        end
        i = i + 1
    end
    return 0

fn x86_synth_dyn_bump_write w_names w_counts name
    i = 0
    n = w_names.len()
    while i < n
        if w_names[i] == name
            list_set(w_counts, i, w_counts[i] + 1)
            return 0
        end
        i = i + 1
    end
    push(w_names, name)
    push(w_counts, 1)
    return 0

fn x86_synth_dyn_is_non_assign_kw txt
    if txt == "if" or txt == "elif" or txt == "else" or txt == "while" or txt == "for" or txt == "return" or txt == "fn" or txt == "struct" or txt == "enum" or txt == "end" or txt == "match" or txt == "case" or txt == "try" or txt == "catch" or txt == "finally" or txt == "defer" or txt == "break" or txt == "continue" or txt == "throw" or txt == "say" or txt == "print" or txt == "println" or txt == "import" or txt == "global" or txt == "const" or txt == "let" or txt == "var" or txt == "and" or txt == "or" or txt == "not"
        return 1
    end
    if txt == "@if" or txt == "@elif" or txt == "@else" or txt == "@while" or txt == "@for" or txt == "@fn" or txt == "@struct" or txt == "@enum" or txt == "@end" or txt == "@match" or txt == "@try" or txt == "@defer" or txt == "@let" or txt == "ধরি" or txt == "যদি" or txt == "শেষ" or txt == "ফেরত"
        return 1
    end
    return 0

fn x86_synth_prescan_dyn_vars toks start_pos base_col base_line param_names
    // WHY: Flow-sensitive fixpoint prescan for single-pass codegen. Identifies every multi-write
    // local/parameter that can hold a dynamically-tagged value (from subscript indexing, `?`,
    // `match`, or transitive arithmetic/assignment propagation) across untaken branches, if/else
    // merges, and loop-carried accumulators so its tag slot is allocated and synced from write #1.
    res = list()
    w_names = list()
    w_counts = list()
    a_lhs = list()
    a_rs = list()
    a_re = list()
    dyn_set = list()
    if param_names != 0
        pi = 0
        while pi < param_names.len()
            x86_synth_dyn_bump_write(w_names, w_counts, param_names[pi])
            pi = pi + 1
        end
    end
    n = toks.len()
    i = start_pos
    while i < n and (toks[i].tok_kind == TOK_NEWLINE() or toks[i].tok_kind == TOK_SEMI() or toks[i].tok_kind == TOK_COMMENT_LINE() or toks[i].tok_kind == TOK_COMMENT_DOC() or toks[i].tok_kind == TOK_COMMENT_BLOCK())
        i = i + 1
    end
    fn_braced = 0
    fn_bd = 0
    if i < n and (toks[i].tok_kind == TOK_LBRACE() or (toks[i].tok_kind != TOK_STR() and toks[i].tok_text == "{"))
        fn_braced = 1
        fn_bd = 1
        i = i + 1
    end
    pd = 0
    bd = 0
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF()
            break
        end
        if fn_braced == 1
            if k == TOK_LBRACE() or (k != TOK_STR() and txt == "{")
                fn_bd = fn_bd + 1
                i = i + 1
                continue
            elif k == TOK_RBRACE() or (k != TOK_STR() and txt == "}")
                fn_bd = fn_bd - 1
                if fn_bd <= 0
                    break
                end
                i = i + 1
                continue
            end
        elif base_line >= 0
            if x86_synth_is_block_end(toks, i) == 1 and t.tok_span.span_start_col <= base_col
                break
            end
            if t.tok_span.span_start_line > base_line and t.tok_span.span_start_col <= base_col and k != TOK_NEWLINE() and k != TOK_SEMI() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_DOC() and k != TOK_COMMENT_BLOCK()
                break
            end
        end
        // Skip nested named fn/struct/enum definitions
        is_nested = 0
        if (k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component"))) and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            is_nested = 1
        elif k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT() or k == TOK_KW_ENUM() or k == TOK_DIR_ENUM() or (k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct" or txt == "enum" or txt == "@enum"))
            is_nested = 1
        end
        if is_nested == 1
            nf_col = t.tok_span.span_start_col
            nf_line = t.tok_span.span_start_line
            i = i + 1
            nf_bd = 0
            while i < n
                ntf = toks[i]
                nkf = ntf.tok_kind
                ntxf = ntf.tok_text
                if nkf == TOK_EOF()
                    break
                end
                if nkf == TOK_LBRACE() or (nkf != TOK_STR() and ntxf == "{")
                    nf_bd = nf_bd + 1
                elif nkf == TOK_RBRACE() or (nkf != TOK_STR() and ntxf == "}")
                    if nf_bd > 0
                        nf_bd = nf_bd - 1
                        if nf_bd == 0
                            i = i + 1
                            break
                        end
                    end
                end
                if nf_bd == 0
                    if x86_synth_is_block_end(toks, i) == 1 and ntf.tok_span.span_start_col <= nf_col
                        i = i + 1
                        break
                    end
                    if ntf.tok_span.span_start_line > nf_line and ntf.tok_span.span_start_col <= nf_col and nkf != TOK_NEWLINE() and nkf != TOK_SEMI() and nkf != TOK_COMMENT_LINE() and nkf != TOK_COMMENT_DOC() and nkf != TOK_COMMENT_BLOCK()
                        if nkf != TOK_KW_ELIF() and nkf != TOK_KW_ELSE() and nkf != TOK_DIR_ELIF() and nkf != TOK_DIR_ELSE() and nkf != TOK_DIR_END() and nkf != TOK_KW_END() and ntxf != "elif" and ntxf != "else" and ntxf != "অথবা" and ntxf != "নাহলে"
                            break
                        end
                    end
                end
                i = i + 1
            end
            continue
        end
        if k == TOK_LPAREN() or (k != TOK_STR() and txt == "(")
            pd = pd + 1
            i = i + 1
            continue
        elif k == TOK_RPAREN() or (k != TOK_STR() and txt == ")")
            if pd > 0
                pd = pd - 1
            end
            i = i + 1
            continue
        elif k == TOK_LBRACKET() or (k != TOK_STR() and txt == "[")
            bd = bd + 1
            i = i + 1
            continue
        elif k == TOK_RBRACKET() or (k != TOK_STR() and txt == "]")
            if bd > 0
                bd = bd - 1
            end
            i = i + 1
            continue
        end
        // Detect untyped assignment / compound assignment: `v = rhs` or `v += rhs`
        if pd == 0 and bd == 0 and x86_synth_is_ident_token(k) == 1 and x86_synth_dyn_is_non_assign_kw(txt) == 0 and i + 1 < n
            prev_is_dot = 0
            if i > start_pos and (toks[i - 1].tok_kind == TOK_DOT() or (toks[i - 1].tok_kind != TOK_STR() and toks[i - 1].tok_text == "."))
                prev_is_dot = 1
            end
            if prev_is_dot == 0
                nt = toks[i + 1]
                nk = nt.tok_kind
                ntx = nt.tok_text
                is_asgn = 0
                if nk == TOK_ASSIGN() or nk == TOK_PLUSEQ() or nk == TOK_MINUSEQ() or nk == TOK_STAREQ() or nk == TOK_SLASHEQ() or nk == TOK_PERCENTEQ()
                    is_asgn = 1
                elif nk != TOK_STR() and (ntx == "=" or ntx == "+=" or ntx == "-=" or ntx == "*=" or ntx == "/=" or ntx == "%=")
                    is_asgn = 1
                end
                if is_asgn == 1
                    x86_synth_dyn_bump_write(w_names, w_counts, txt)
                    rs = i + 2
                    re = rs
                    rpd = 0
                    rbd = 0
                    rcd = 0
                    while re < n
                        rt = toks[re]
                        rk = rt.tok_kind
                        rtx = rt.tok_text
                        if rk == TOK_EOF()
                            break
                        end
                        if rpd == 0 and rbd == 0 and rcd == 0
                            if rk == TOK_NEWLINE() or rk == TOK_SEMI() or rk == TOK_COMMENT_LINE() or rk == TOK_COMMENT_DOC() or rk == TOK_COMMENT_BLOCK() or rk == TOK_RBRACE() or (rk != TOK_STR() and rtx == "}") or x86_synth_is_block_end(toks, re) == 1
                                break
                            end
                        end
                        if rk == TOK_LPAREN() or (rk != TOK_STR() and rtx == "(")
                            rpd = rpd + 1
                        elif rk == TOK_RPAREN() or (rk != TOK_STR() and rtx == ")")
                            if rpd > 0
                                rpd = rpd - 1
                            end
                        elif rk == TOK_LBRACKET() or (rk != TOK_STR() and rtx == "[")
                            rbd = rbd + 1
                        elif rk == TOK_RBRACKET() or (rk != TOK_STR() and rtx == "]")
                            if rbd > 0
                                rbd = rbd - 1
                            end
                        elif rk == TOK_LBRACE() or (rk != TOK_STR() and rtx == "{")
                            rcd = rcd + 1
                        elif rk == TOK_RBRACE() or (rk != TOK_STR() and rtx == "}")
                            if rcd > 0
                                rcd = rcd - 1
                            end
                        end
                        re = re + 1
                    end
                    push(a_lhs, txt)
                    push(a_rs, rs)
                    push(a_re, re)
                    // Direct dyn source check: unprojected subscript `obj[idx]`, `?`, or value `match`
                    is_dir = 0
                    if rs < re
                        if x86_synth_is_match_start(toks, rs) == 1
                            is_dir = 1
                        end
                        sj = rs
                        c_depth = 0
                        while sj < re and is_dir == 0
                            st = toks[sj]
                            sk = st.tok_kind
                            stx = st.tok_text
                            if c_depth > 0
                                if sk == TOK_LPAREN() or (sk != TOK_STR() and stx == "(")
                                    c_depth = c_depth + 1
                                elif sk == TOK_RPAREN() or (sk != TOK_STR() and stx == ")")
                                    c_depth = c_depth - 1
                                end
                                sj = sj + 1
                                continue
                            end
                            // Skip function/method call arguments: `ident(...)`
                            if (sk == TOK_LPAREN() or (sk != TOK_STR() and stx == "(")) and sj > rs
                                pk0 = toks[sj - 1].tok_kind
                                ptx0 = toks[sj - 1].tok_text
                                if x86_synth_is_ident_token(pk0) == 1 and x86_synth_dyn_is_non_assign_kw(ptx0) == 0
                                    c_depth = 1
                                    sj = sj + 1
                                    continue
                                end
                            end
                            if sk == TOK_QUERY() or (sk != TOK_STR() and stx == "?")
                                is_dir = 1
                                break
                            end
                            if (sk == TOK_LBRACKET() or (sk != TOK_STR() and stx == "[")) and sj > rs
                                pk1 = toks[sj - 1].tok_kind
                                ptx1 = toks[sj - 1].tok_text
                                if x86_synth_is_ident_token(pk1) == 1 or pk1 == TOK_RPAREN() or pk1 == TOK_RBRACKET() or pk1 == TOK_STR() or (pk1 != TOK_STR() and (ptx1 == ")" or ptx1 == "]"))
                                    // Find matching ']'
                                    mj = sj + 1
                                    mb = 1
                                    while mj < re and mb > 0
                                        if toks[mj].tok_kind == TOK_LBRACKET() or (toks[mj].tok_kind != TOK_STR() and toks[mj].tok_text == "[")
                                            mb = mb + 1
                                        elif toks[mj].tok_kind == TOK_RBRACKET() or (toks[mj].tok_kind != TOK_STR() and toks[mj].tok_text == "]")
                                            mb = mb - 1
                                            if mb == 0
                                                break
                                            end
                                        end
                                        mj = mj + 1
                                    end
                                    // Subscript is direct dyn iff NOT followed immediately by `.` or `(`
                                    if mj < re
                                        proj_after = 0
                                        if mj + 1 < re
                                            ak2 = toks[mj + 1].tok_kind
                                            atx2 = toks[mj + 1].tok_text
                                            if ak2 == TOK_DOT() or ak2 == TOK_LPAREN() or (ak2 != TOK_STR() and (atx2 == "." or atx2 == "("))
                                                proj_after = 1
                                            end
                                        end
                                        if proj_after == 0
                                            is_dir = 1
                                            break
                                        end
                                        sj = mj + 1
                                        continue
                                    end
                                end
                            end
                            sj = sj + 1
                        end
                    end
                    if is_dir == 1 and x86_synth_dyn_list_has(dyn_set, txt) == 0
                        push(dyn_set, txt)
                    end
                    i = re
                    continue
                end
            end
        end
        i = i + 1
    end
    // Fixpoint propagation: if `lhs` RHS uses any bare dyn variable (not in call args, index, or `.field`)
    if dyn_set.len() > 0
        changed = 1
        pass_n = 0
        while changed == 1 and pass_n < 8
            changed = 0
            pass_n = pass_n + 1
            ai = 0
            an = a_lhs.len()
            while ai < an
                lv_n = a_lhs[ai]
                if x86_synth_dyn_list_has(dyn_set, lv_n) == 0
                    rs = a_rs[ai]
                    re = a_re[ai]
                    sj = rs
                    c_depth = 0
                    b_depth = 0
                    while sj < re
                        st = toks[sj]
                        sk = st.tok_kind
                        stx = st.tok_text
                        if c_depth > 0
                            if sk == TOK_LPAREN() or (sk != TOK_STR() and stx == "(")
                                c_depth = c_depth + 1
                            elif sk == TOK_RPAREN() or (sk != TOK_STR() and stx == ")")
                                c_depth = c_depth - 1
                            end
                            sj = sj + 1
                            continue
                        end
                        if b_depth > 0
                            if sk == TOK_LBRACKET() or (sk != TOK_STR() and stx == "[")
                                b_depth = b_depth + 1
                            elif sk == TOK_RBRACKET() or (sk != TOK_STR() and stx == "]")
                                b_depth = b_depth - 1
                            end
                            sj = sj + 1
                            continue
                        end
                        if sk == TOK_LBRACKET() or (sk != TOK_STR() and stx == "[")
                            b_depth = 1
                            sj = sj + 1
                            continue
                        end
                        if (sk == TOK_LPAREN() or (sk != TOK_STR() and stx == "(")) and sj > rs
                            pk0 = toks[sj - 1].tok_kind
                            ptx0 = toks[sj - 1].tok_text
                            if x86_synth_is_ident_token(pk0) == 1 and x86_synth_dyn_is_non_assign_kw(ptx0) == 0
                                c_depth = 1
                                sj = sj + 1
                                continue
                            end
                        end
                        if x86_synth_is_ident_token(sk) == 1 and x86_synth_dyn_list_has(dyn_set, stx) == 1
                            prev_dot = 0
                            if sj > rs and (toks[sj - 1].tok_kind == TOK_DOT() or (toks[sj - 1].tok_kind != TOK_STR() and toks[sj - 1].tok_text == "."))
                                prev_dot = 1
                            end
                            next_proj = 0
                            if sj + 1 < re
                                nk2 = toks[sj + 1].tok_kind
                                ntx2 = toks[sj + 1].tok_text
                                if nk2 == TOK_DOT() or nk2 == TOK_LPAREN() or nk2 == TOK_LBRACKET() or (nk2 != TOK_STR() and (ntx2 == "." or ntx2 == "(" or ntx2 == "["))
                                    next_proj = 1
                                end
                            end
                            if prev_dot == 0 and next_proj == 0
                                push(dyn_set, lv_n)
                                changed = 1
                                break
                            end
                        end
                        sj = sj + 1
                    end
                end
                ai = ai + 1
            end
        end
        // Emit only multi-write dyn variables (count >= 2): single-write locals never have stale prior tag
        wi = 0
        wn = w_names.len()
        while wi < wn
            if w_counts[wi] >= 2 and x86_synth_dyn_list_has(dyn_set, w_names[wi]) == 1
                push(res, w_names[wi])
            end
            wi = wi + 1
        end
    end
    return res

fn x86_synth_emit_null_check_rax s
    // WHY: Guards struct field reads on %rax against NULL / low unmapped page (< 4096),
    // throwing catchable NullPointerException in hosted mode. Disabled in --freestanding
    // where zero Linux exception runtime exists and low physical addresses are valid.
    if s.synth_freestanding == 1
        return 0
    end
    // cmp rax, 4096 (6B); jae +5 (2B); call _lipi_throw_null_deref (5B)
    x86_synth_emit_bytes(s, [72, 61, 0, 16, 0, 0, 115, 5])
    x86_synth_emit_call_helper(s, "_lipi_throw_null_deref")
    return 0

fn x86_synth_emit_null_check_rcx s
    // WHY: Guards struct field writes / chain walks on %rcx against NULL / low page (< 4096).
    if s.synth_freestanding == 1
        return 0
    end
    // cmp rcx, 4096 (7B); jae +5 (2B); call _lipi_throw_null_deref (5B)
    x86_synth_emit_bytes(s, [72, 129, 249, 0, 16, 0, 0, 115, 5])
    x86_synth_emit_call_helper(s, "_lipi_throw_null_deref")
    return 0

fn x86_synth_body_has_defer toks start_pos base_col base_line
    // WHY: Zero-overhead prescan: returns 1 iff current function body contains a defer statement
    // (ignoring nested fn definitions). Functions without defer emit 0 unwind instructions.
    n = toks.len()
    i = start_pos
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF()
            break
        end
        if base_line >= 0
            if x86_synth_is_block_end(toks, i) == 1 and t.tok_span.span_start_col <= base_col
                break
            end
            if t.tok_span.span_start_line > base_line and t.tok_span.span_start_col <= base_col and k != TOK_NEWLINE() and k != TOK_SEMI() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_DOC() and k != TOK_COMMENT_BLOCK()
                break
            end
        end
        if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান"))
            if i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
                break
            end
        end
        if k == TOK_KW_DEFER() or (k == TOK_IDENT() and (txt == "defer" or txt == "@defer" or txt == "বিলম্ব"))
            if i + 1 >= n
                return 1
            else
                dn = toks[i + 1]
                if dn.tok_kind != TOK_ASSIGN() and dn.tok_text != "=" and dn.tok_kind != TOK_LPAREN() and dn.tok_text != "(" and dn.tok_kind != TOK_DOT() and dn.tok_text != "."
                    return 1
                end
            end
        end
        i = i + 1
    end
    return 0

fn x86_synth_is_boxed_name s name
    if s.synth_boxed_vars == 0
        return 0
    end
    bi = 0
    bn = s.synth_boxed_vars.len()
    while bi < bn
        if s.synth_boxed_vars[bi] == name
            return 1
        end
        bi = bi + 1
    end
    return 0
end

fn x86_synth_prescan_boxed_vars toks start_pos base_col base_line
    // WHY: True 2-pass upvalue escape & mutation analysis across ALL closure forms
    // (single-expression `fn(x) => expr`, brace block `{ ... }`, multiline block, `|x| => ...`).
    // Boxes any outer variable v into a shared 8-byte GC upvalue cell iff:
    //   (v is captured by any nested closure in this scope) AND
    //   (v is mutated inside a closure OR reassigned/compound-mutated in the enclosing scope).
    res = list()
    captured = list()
    inner_mut = list()
    outer_writes = list()
    outer_counts = list()
    outer_comp = list()
    n = toks.len()
    i = start_pos
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF()
            break
        end
        if base_line >= 0
            if x86_synth_is_block_end(toks, i) == 1 and t.tok_span.span_start_col <= base_col
                break
            end
            if t.tok_span.span_start_line > base_line and t.tok_span.span_start_col <= base_col and k != TOK_NEWLINE() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_BLOCK()
                break
            end
        end
        // Skip nested named `fn name ...` / `struct` definitions so their locals don't mix with enclosing scope
        is_named_fn = 0
        if (k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component"))) and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            is_named_fn = 1
        elif k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT() or k == TOK_DIR_ENUM() or (k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct" or txt == "enum" or txt == "@enum"))
            is_named_fn = 1
        end
        if is_named_fn == 1
            nf_col = t.tok_span.span_start_col
            nf_line = t.tok_span.span_start_line
            i = i + 1
            nf_bd = 0
            while i < n
                ntf = toks[i]
                nkf = ntf.tok_kind
                ntxf = ntf.tok_text
                if nkf == TOK_EOF() break end
                if nkf == TOK_LBRACE() or (nkf != TOK_STR() and ntxf == "{")
                    nf_bd = nf_bd + 1
                elif nkf == TOK_RBRACE() or (nkf != TOK_STR() and ntxf == "}")
                    if nf_bd > 0
                        nf_bd = nf_bd - 1
                        if nf_bd == 0
                            i = i + 1
                            break
                        end
                    end
                end
                if nf_bd == 0
                    if x86_synth_is_block_end(toks, i) == 1 and ntf.tok_span.span_start_col <= nf_col
                        i = i + 1
                        break
                    end
                    if ntf.tok_span.span_start_line > nf_line and ntf.tok_span.span_start_col <= nf_col and nkf != TOK_NEWLINE() and nkf != TOK_SEMI() and nkf != TOK_COMMENT_LINE() and nkf != TOK_COMMENT_DOC() and nkf != TOK_COMMENT_BLOCK()
                        if nkf != TOK_KW_ELIF() and nkf != TOK_KW_ELSE() and nkf != TOK_DIR_ELIF() and nkf != TOK_DIR_ELSE() and nkf != TOK_DIR_END() and nkf != TOK_KW_END() and ntxf != "elif" and ntxf != "else" and ntxf != "অথবা" and ntxf != "নাহলে"
                            break
                        end
                    end
                end
                i = i + 1
            end
            continue
        end

        // Check if this token starts a closure: `fn(...) => ...` or `|...| => ...`
        is_clos = 0
        c_end_hdr = i
        c_params = list()
        if (k == TOK_KW_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ"))) and i + 1 < n and (toks[i + 1].tok_kind == TOK_LPAREN() or toks[i + 1].tok_text == "(")
            j = i + 2
            while j < n
                if toks[j].tok_kind == TOK_RPAREN() or (toks[j].tok_kind != TOK_STR() and toks[j].tok_text == ")")
                    c_end_hdr = j + 1
                    is_clos = 1
                    break
                elif toks[j].tok_kind == TOK_COLON() or (toks[j].tok_kind != TOK_STR() and toks[j].tok_text == ":")
                    j = j + 2
                    continue
                elif x86_synth_is_ident_token(toks[j].tok_kind) == 1
                    push(c_params, toks[j].tok_text)
                end
                j = j + 1
            end
        elif k == TOK_BAR() or (k != TOK_STR() and txt == "|")
            j = i + 1
            ok_bar = 0
            while j < n and (j - i) < 32
                if toks[j].tok_kind == TOK_BAR() or (toks[j].tok_kind != TOK_STR() and toks[j].tok_text == "|")
                    if j + 1 < n and (toks[j + 1].tok_kind == TOK_FAT_ARROW() or toks[j + 1].tok_text == "=>" or toks[j + 1].tok_kind == TOK_ARROW() or toks[j + 1].tok_text == "->" or toks[j + 1].tok_kind == TOK_LBRACE() or toks[j + 1].tok_text == "{")
                        c_end_hdr = j + 1
                        ok_bar = 1
                    end
                    break
                elif toks[j].tok_kind == TOK_NEWLINE() or toks[j].tok_kind == TOK_SEMI()
                    break
                elif toks[j].tok_kind == TOK_COLON() or (toks[j].tok_kind != TOK_STR() and toks[j].tok_text == ":")
                    j = j + 2
                    continue
                elif x86_synth_is_ident_token(toks[j].tok_kind) == 1
                    push(c_params, toks[j].tok_text)
                end
                j = j + 1
            end
            is_clos = ok_bar
        end
        if is_clos == 1
            j = c_end_hdr
            if j < n and (toks[j].tok_kind == TOK_FAT_ARROW() or toks[j].tok_text == "=>" or toks[j].tok_kind == TOK_ARROW() or toks[j].tok_text == "->")
                j = j + 1
            end
            b_mode = 0
            if j < n and (toks[j].tok_kind == TOK_LBRACE() or (toks[j].tok_kind != TOK_STR() and toks[j].tok_text == "{"))
                b_mode = 1
                j = j + 1
            elif j < n and toks[j].tok_kind == TOK_NEWLINE()
                b_mode = 2
                j = j + 1
            end
            depth = 1
            ep_d = 0
            while j < n and depth > 0
                ct = toks[j]
                ck = ct.tok_kind
                ctxt = ct.tok_text
                if ck == TOK_EOF() break end
                if b_mode == 1
                    if ck == TOK_LBRACE() or (ck != TOK_STR() and ctxt == "{")
                        depth = depth + 1
                    elif ck == TOK_RBRACE() or (ck != TOK_STR() and ctxt == "}")
                        depth = depth - 1
                        if depth == 0
                            j = j + 1
                            break
                        end
                    end
                elif b_mode == 2
                    if ck == TOK_KW_IF() or ck == TOK_KW_WHILE() or ck == TOK_KW_FOR() or ck == TOK_KW_TRY() or (ck == TOK_IDENT() and (ctxt == "if" or ctxt == "while" or ctxt == "for" or ctxt == "try" or ctxt == "region" or ctxt == "অঞ্চল"))
                        depth = depth + 1
                    elif x86_synth_is_block_end(toks, j) == 1
                        depth = depth - 1
                        if depth == 0
                            j = j + 1
                            break
                        end
                    end
                else
                    // b_mode == 0: single-expression closure (`fn(x) => expr` / `|x| => expr`)
                    if ck == TOK_LPAREN() or ck == TOK_LBRACKET() or ck == TOK_LBRACE() or (ck != TOK_STR() and (ctxt == "(" or ctxt == "[" or ctxt == "{"))
                        ep_d = ep_d + 1
                    elif ck == TOK_RPAREN() or ck == TOK_RBRACKET() or ck == TOK_RBRACE() or (ck != TOK_STR() and (ctxt == ")" or ctxt == "]" or ctxt == "}"))
                        if ep_d == 0
                            break
                        end
                        ep_d = ep_d - 1
                    elif ep_d == 0 and (ck == TOK_NEWLINE() or ck == TOK_SEMI() or ck == TOK_COMMA() or (ck != TOK_STR() and (ctxt == ";" or ctxt == ",")))
                        break
                    end
                end
                if x86_synth_is_ident_token(ck) == 1
                    is_dot_prev = 0
                    if j > 0 and (toks[j - 1].tok_kind == TOK_DOT() or toks[j - 1].tok_text == ".")
                        is_dot_prev = 1
                    end
                    is_cp = 0
                    pi = 0
                    while pi < c_params.len()
                        if c_params[pi] == ctxt
                            is_cp = 1
                            break
                        end
                        pi = pi + 1
                    end
                    if is_dot_prev == 0 and is_cp == 0
                        // Record into captured set
                        dup_c = 0
                        ci = 0
                        while ci < captured.len()
                            if captured[ci] == ctxt
                                dup_c = 1
                                break
                            end
                            ci = ci + 1
                        end
                        if dup_c == 0
                            push(captured, ctxt)
                        end
                        // Check if mutated directly inside closure
                        if j + 1 < n
                            nk = toks[j + 1].tok_kind
                            nt = toks[j + 1].tok_text
                            is_mut = 0
                            if nk == TOK_ASSIGN() or nk == TOK_PLUSEQ() or nk == TOK_MINUSEQ() or nk == TOK_STAREQ() or nk == TOK_SLASHEQ() or nk == TOK_PERCENTEQ()
                                is_mut = 1
                            elif nk != TOK_STR() and (nt == "=" or nt == "+=" or nt == "-=" or nt == "*=" or nt == "/=" or nt == "%=")
                                is_mut = 1
                            end
                            if is_mut == 1
                                dup_m = 0
                                mi = 0
                                while mi < inner_mut.len()
                                    if inner_mut[mi] == ctxt
                                        dup_m = 1
                                        break
                                    end
                                    mi = mi + 1
                                end
                                if dup_m == 0
                                    push(inner_mut, ctxt)
                                end
                            end
                        end
                    end
                end
                j = j + 1
            end
            i = j
            continue
        end

        // Track assignments in the enclosing scope (outside closure bodies!)
        if x86_synth_is_ident_token(k) == 1 and i + 1 < n
            is_dot_o = 0
            if i > 0 and (toks[i - 1].tok_kind == TOK_DOT() or toks[i - 1].tok_text == ".")
                is_dot_o = 1
            end
            if is_dot_o == 0
                np_o = i + 1
                if np_o + 2 < n and (toks[np_o].tok_kind == TOK_COLON() or (toks[np_o].tok_kind != TOK_STR() and toks[np_o].tok_text == ":"))
                    np_o = np_o + 2
                end
                if np_o < n
                    onk = toks[np_o].tok_kind
                    ont = toks[np_o].tok_text
                    ow_kind = 0
                    if onk == TOK_ASSIGN() or (onk != TOK_STR() and ont == "=")
                        ow_kind = 1
                    elif onk == TOK_PLUSEQ() or onk == TOK_MINUSEQ() or onk == TOK_STAREQ() or onk == TOK_SLASHEQ() or onk == TOK_PERCENTEQ() or (onk != TOK_STR() and (ont == "+=" or ont == "-=" or ont == "*=" or ont == "/=" or ont == "%="))
                        ow_kind = 2
                    end
                    if ow_kind > 0
                        oi = 0
                        found_o = 0 - 1
                        while oi < outer_writes.len()
                            if outer_writes[oi] == txt
                                found_o = oi
                                break
                            end
                            oi = oi + 1
                        end
                        if found_o < 0
                            push(outer_writes, txt)
                            push(outer_counts, 1)
                            if ow_kind == 2
                                push(outer_comp, 1)
                            else
                                push(outer_comp, 0)
                            end
                        else
                            list_set(outer_counts, found_o, outer_counts[found_o] + 1)
                            if ow_kind == 2
                                list_set(outer_comp, found_o, 1)
                            end
                        end
                    end
                end
            end
        end
        i = i + 1
    end

    // Intersect captured vars with (inner_mut OR outer_counts >= 2 OR outer_comp == 1)
    ci = 0
    while ci < captured.len()
        cname = captured[ci]
        should_box = 0
        mi = 0
        while mi < inner_mut.len()
            if inner_mut[mi] == cname
                should_box = 1
                break
            end
            mi = mi + 1
        end
        if should_box == 0
            oi = 0
            while oi < outer_writes.len()
                if outer_writes[oi] == cname
                    if outer_counts[oi] >= 2 or outer_comp[oi] == 1
                        should_box = 1
                    end
                    break
                end
                oi = oi + 1
            end
        end
        if should_box == 1
            push(res, cname)
        end
        ci = ci + 1
    end
    return res
end

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
    // WHY: Converts all recorded .rodata, @bss, and RW global relocations in s.synth_code to
    // position-independent RIP-relative addressing for Static-PIE ASLR, UEFI PE32+, raw-bin, & higher-half kernels.
    text_file_off = s.synth_code_file_off
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
include "src/compiler/backend/targets/x86_64/runtime_mt_gc.lp"
include "src/compiler/backend/targets/x86_64/runtime_dict.lp"
include "src/compiler/backend/targets/x86_64/runtime_trace.lp"
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
    // WHY: Restores stack pointer, callee-saved registers, and caller frame.
    // Inside @interrupt functions, restores ALL 15 GPRs and emits `iretq` (48 CF).
    // Inside @naked functions, emits no epilogue bytes (user controls return/iretq/hlt).
    if s.synth_in_naked_fn == 1
        return 0
    end
    if s.synth_in_interrupt_fn == 1
        return x86_synth_emit_interrupt_epilogue(s)
    end
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

fn x86_synth_emit_interrupt_prologue s
    // WHY: Hardware x86-64 Ring-0 @interrupt handler prologue.
    // Saves ALL 15 general-purpose registers so the interrupted context is preserved bit-for-bit,
    // establishes rbp, loads hardware interrupt frame pointer [rbp + 120] into %rdi, and aligns stack.
    s.synth_last_store_end = 0 - 1
    // push rax, rcx, rdx, rsi, rdi, r8..r15, rbx, rbp (15 * 8 = 120 bytes)
    x86_synth_emit_bytes(s, [
        80, 81, 82, 86, 87,
        65, 80, 65, 81, 65, 82, 65, 83, 65, 84, 65, 85, 65, 86, 65, 87,
        83, 85,
        72, 137, 229,         // mov rbp, rsp
        72, 141, 125, 120,    // lea rdi, [rbp + 120] (hardware TrapFrame: rip, cs, rflags, rsp, ss)
        72, 131, 228, 240,    // and rsp, -16 (guarantee 16-byte ABI alignment for calls inside ISR)
        72, 129, 236          // sub rsp, imm32
    ])
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 512)
    return patch_pos

fn x86_synth_emit_interrupt_epilogue s
    // WHY: Hardware x86-64 Ring-0 @interrupt handler epilogue — restores all 15 GPRs and executes `iretq`.
    x86_synth_emit_bytes(s, [
        72, 137, 236,         // mov rsp, rbp
        93, 91,               // pop rbp; pop rbx
        65, 95, 65, 94, 65, 93, 65, 92, 65, 91, 65, 90, 65, 89, 65, 88, // pop r15..r8
        95, 94, 90, 89, 88,   // pop rdi, rsi, rdx, rcx, rax
        72, 207               // iretq (0x48 0xCF)
    ])
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
    // WHY: Routes struct/closure allocations through GC-tracked slab allocator (_lipi_user_alloc)
    // for zero-initialized reuse, full interior pointer tracing, and deterministic OS page return.
    s.synth_needs_alloc = 1
    call_off = s.synth_code.len()
    x86_synth_emit_byte(s, 232) // CALL rel32
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 0)

    call_rel = X86CallReloc()
    call_rel.cr_patch_offset = patch_pos
    call_rel.cr_call_site_end = patch_pos + 4
    call_rel.cr_target_name = "_lipi_user_alloc"
    push(s.synth_call_relocs, call_rel)
    return 0

fn x86_synth_emit_alloc_helper s
    // WHY: Emits lock-free CAS bump-arena memory allocator with automatic heap overflow expansion.
    // Fast path uses lock cmpxchg [rdx+8] bounded by _heap_end ([rdx+384] == rw+400).
    // Slow path acquires [rdx+104] (rw+120), expands via SYS_mmap (with _heap_end hint), and aborts (137) on OOM/negative sizes.
    s.synth_alloc_off = s.synth_code.len()
    alloc_bytes = [72, 133, 255, 15, 136, 228, 0, 0, 0, 72, 131, 199, 15, 72, 131, 231, 240, 72, 186, 136, 119, 102, 85, 68, 51, 34, 17, 72, 139, 66, 8, 72, 133, 192, 116, 26, 72, 137, 193, 72, 1, 249, 114, 18, 72, 59, 138, 128, 1, 0, 0, 119, 9, 240, 72, 15, 177, 74, 8, 117, 222, 195, 240, 72, 15, 186, 106, 104, 0, 114, 247, 72, 139, 66, 8, 72, 133, 192, 116, 29, 72, 137, 193, 72, 1, 249, 114, 21, 72, 59, 138, 128, 1, 0, 0, 119, 12, 72, 137, 74, 8, 240, 72, 15, 186, 114, 104, 0, 195, 72, 141, 183, 255, 15, 0, 0, 72, 129, 230, 0, 240, 255, 255, 185, 0, 240, 255, 255, 72, 57, 206, 115, 3, 72, 137, 206, 87, 82, 86, 72, 139, 186, 128, 1, 0, 0, 186, 3, 0, 0, 0, 65, 186, 34, 0, 0, 0, 73, 199, 192, 255, 255, 255, 255, 69, 49, 201, 184, 9, 0, 0, 0, 15, 5, 94, 90, 95, 72, 133, 192, 120, 48, 72, 139, 10, 72, 133, 201, 117, 5, 72, 137, 2, 235, 8, 72, 57, 200, 115, 3, 72, 137, 2, 72, 141, 12, 48, 72, 137, 138, 128, 1, 0, 0, 72, 141, 12, 56, 72, 137, 74, 8, 240, 72, 15, 186, 114, 104, 0, 195, 240, 72, 15, 186, 114, 104, 0, 191, 137, 0, 0, 0, 184, 231, 0, 0, 0, 15, 5]
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
    // WHY: Requires exact field count and key set equality against declared/anonymous structs,
    // ranking exact ordered named structs highest to eliminate field-offset collisions on partial matches.
    if keys.len() == 0
        return ""
    best_name = ""
    best_score = 0
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        if sd.sd_fields.len() == keys.len()
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
                order_match = 1
                oi = 0
                while oi < keys.len()
                    if sd.sd_fields[oi] != keys[oi]
                        order_match = 0
                        break
                    end
                    oi = oi + 1
                end
                score = 1
                if is_anon == 0 and order_match == 1
                    score = 4
                elif is_anon == 0
                    score = 3
                elif order_match == 1
                    score = 2
                end
                if score > best_score
                    best_score = score
                    best_name = sd.sd_name
                end
            end
        end
        i = i + 1
    return best_name

fn x86_synth_parse_decimal_int str_val
    n = len(str_val)
    if n == 0 return 0 end
    acc = 0
    i = 0
    while i < n
        b = mem_byte_read(str_val, i)
        if b >= 48 and b <= 57
            acc = acc * 10 + (b - 48)
        else
            break
        end
        i = i + 1
    end
    return acc

fn x86_synth_type_layout_info s ftype
    // WHY: Computes exact hardware layout [byte_size, align, elem_size, is_signed] for scalar
    // fixed-width types (u8/i8/u16/i16/u32/i32/u64/i64/f32/f64/ptr), inline fixed-size arrays
    // `[N]T`, and dynamic/untyped 64-bit Lipi slots (8-byte aligned by default).
    if ftype == "" or ftype == "i64" or ftype == "int" or ftype == "f64" or ftype == "float" or ftype == "str" or ftype == "string" or ftype == "array" or ftype == "bool" or ftype == "any"
        return [8, 8, 0, 1]
    elif ftype == "u64" or ftype == "ptr" or (len(ftype) >= 4 and str_sub(ftype, 0, 4) == "ptr<")
        return [8, 8, 0, 0]
    elif ftype == "u8" or ftype == "byte"
        return [1, 1, 0, 0]
    elif ftype == "i8"
        return [1, 1, 0, 1]
    elif ftype == "u16"
        return [2, 2, 0, 0]
    elif ftype == "i16"
        return [2, 2, 0, 1]
    elif ftype == "u32"
        return [4, 4, 0, 0]
    elif ftype == "i32" or ftype == "f32"
        return [4, 4, 0, 1]
    elif len(ftype) >= 4 and mem_byte_read(ftype, 0) == 91
        // Fixed-size inline array syntax: `[N]T` (e.g. `[512]u8`, `[16]u32`, `[512]u64`)
        rb = 0 - 1
        ci = 1
        fl = len(ftype)
        while ci < fl
            if mem_byte_read(ftype, ci) == 93
                rb = ci
                break
            end
            ci = ci + 1
        end
        if rb > 1 and rb + 1 < fl
            arr_cnt = x86_synth_parse_decimal_int(str_sub(ftype, 1, rb))
            elem_t = str_sub(ftype, rb + 1, fl)
            el_info = x86_synth_type_layout_info(s, elem_t)
            el_sz = el_info[0]
            el_al = el_info[1]
            el_sgn = el_info[3]
            if arr_cnt < 1 arr_cnt = 1 end
            return [arr_cnt * el_sz, el_al, el_sz, el_sgn]
        end
    end
    // Nested named struct pointer (reference in Lipi) is 8 bytes
    return [8, 8, 0, 0]

fn x86_synth_compute_struct_layout s sdef
    // WHY: Computes deterministic exact byte offsets, field widths, and aligned/packed total byte size
    // for X86StructDef, replacing legacy hardcoded `fi * 8`. Untyped/i64 structs keep exact 8B slots.
    offs = list()
    sizes = list()
    elems = list()
    signs = list()
    is_packed = sdef.sd_is_packed
    explicit_align = sdef.sd_align
    max_align = 1
    cursor = 0
    fi = 0
    n = sdef.sd_fields.len()
    while fi < n
        ft = ""
        if sdef.sd_field_types != 0 and fi < sdef.sd_field_types.len()
            ft = sdef.sd_field_types[fi]
        end
        info = x86_synth_type_layout_info(s, ft)
        fsz = info[0]
        fal = info[1]
        fel = info[2]
        fsgn = info[3]
        eff_al = fal
        if is_packed == 1
            eff_al = 1
        end
        if eff_al > 1
            rem = cursor % eff_al
            if rem != 0
                cursor = cursor + (eff_al - rem)
            end
        end
        if eff_al > max_align
            max_align = eff_al
        end
        push(offs, cursor)
        push(sizes, fsz)
        push(elems, fel)
        push(signs, fsgn)
        cursor = cursor + fsz
        fi = fi + 1
    end
    final_align = max_align
    if explicit_align > final_align
        final_align = explicit_align
    end
    total_sz = cursor
    if final_align > 1 and total_sz > 0
        rem_t = total_sz % final_align
        if rem_t != 0
            total_sz = total_sz + (final_align - rem_t)
        end
    end
    sdef.sd_field_offsets = offs
    sdef.sd_field_sizes = sizes
    sdef.sd_field_elem_sizes = elems
    sdef.sd_field_signed = signs
    sdef.sd_align = final_align
    sdef.sd_total_size = total_sz
    return total_sz

fn x86_synth_get_field_meta s sname fname
    // WHY: Returns [offset, size, is_signed, elem_size, field_type] for struct field access.
    if sname != ""
        i = s.synth_structs.len() - 1
        while i >= 0
            sd = s.synth_structs[i]
            if sd.sd_name == sname
                fi = 0
                while fi < sd.sd_fields.len()
                    if sd.sd_fields[fi] == fname
                        fo = fi * 8
                        fs = 8
                        fg = 1
                        fe = 0
                        ft = ""
                        if sd.sd_field_offsets != 0 and fi < sd.sd_field_offsets.len()
                            fo = sd.sd_field_offsets[fi]
                            fs = sd.sd_field_sizes[fi]
                            fg = sd.sd_field_signed[fi]
                            fe = sd.sd_field_elem_sizes[fi]
                        end
                        if sd.sd_field_types != 0 and fi < sd.sd_field_types.len()
                            ft = sd.sd_field_types[fi]
                        end
                        return [fo, fs, fg, fe, ft]
                    end
                    fi = fi + 1
                end
            end
            i = i - 1
        end
    end
    f_off = x86_synth_get_field_offset(s, sname, fname)
    f_ft = x86_synth_get_field_type(s, sname, fname)
    info = x86_synth_type_layout_info(s, f_ft)
    return [f_off, info[0], info[3], info[2], f_ft]

fn x86_synth_emit_field_load_rax s f_off f_sz f_signed f_elem_sz
    // WHY: Emits exact-width hardware load from [rax + f_off] into %rax (1/2/4/8B signed/unsigned),
    // or `lea rax, [rax + f_off]` for inline fixed-size arrays `[N]T` inside structs.
    if f_elem_sz > 0
        // Inline fixed array: return pointer &struct + f_off
        if f_off == 0
            return 0
        elif f_off < 128
            x86_synth_emit_bytes(s, [72, 141, 64, f_off]) // lea rax, [rax + disp8]
        else
            x86_synth_emit_bytes(s, [72, 141, 128])       // lea rax, [rax + disp32]
            x86_synth_emit_u32(s, f_off)
        end
        return 0
    end
    if f_sz == 1
        op2 = 182 // movzx (0xB6)
        if f_signed == 1 op2 = 190 end // movsx (0xBE)
        if f_off < 128
            x86_synth_emit_bytes(s, [72, 15, op2, 64, f_off])
        else
            x86_synth_emit_bytes(s, [72, 15, op2, 128])
            x86_synth_emit_u32(s, f_off)
        end
    elif f_sz == 2
        op2 = 183 // movzx (0xB7)
        if f_signed == 1 op2 = 191 end // movsx (0xBF)
        if f_off < 128
            x86_synth_emit_bytes(s, [72, 15, op2, 64, f_off])
        else
            x86_synth_emit_bytes(s, [72, 15, op2, 128])
            x86_synth_emit_u32(s, f_off)
        end
    elif f_sz == 4
        if f_signed == 1
            // movsxd rax, dword ptr [rax + f_off]: 48 63 40 disp8 / 48 63 80 disp32
            if f_off < 128
                x86_synth_emit_bytes(s, [72, 99, 64, f_off])
            else
                x86_synth_emit_bytes(s, [72, 99, 128])
                x86_synth_emit_u32(s, f_off)
            end
        else
            // mov eax, dword ptr [rax + f_off] (zero-extends to rax): 8B 40 disp8 / 8B 80 disp32
            if f_off < 128
                x86_synth_emit_bytes(s, [139, 64, f_off])
            else
                x86_synth_emit_bytes(s, [139, 128])
                x86_synth_emit_u32(s, f_off)
            end
        end
    else
        // 8-byte qword load: mov rax, [rax + f_off]
        if f_off < 128
            x86_synth_emit_bytes(s, [72, 139, 64, f_off])
        else
            x86_synth_emit_bytes(s, [72, 139, 128])
            x86_synth_emit_u32(s, f_off)
        end
    end
    return 0

fn x86_synth_emit_field_store_rcx_rax s f_off f_sz
    // WHY: Emits exact-width hardware store from %rax into [rcx + f_off] (1/2/4/8B)
    // without clobbering adjacent packed fields.
    if f_sz == 1
        if f_off < 128
            x86_synth_emit_bytes(s, [136, 65, f_off]) // mov byte [rcx + disp8], al
        else
            x86_synth_emit_bytes(s, [136, 129])
            x86_synth_emit_u32(s, f_off)
        end
    elif f_sz == 2
        if f_off < 128
            x86_synth_emit_bytes(s, [102, 137, 65, f_off]) // mov word [rcx + disp8], ax
        else
            x86_synth_emit_bytes(s, [102, 137, 129])
            x86_synth_emit_u32(s, f_off)
        end
    elif f_sz == 4
        if f_off < 128
            x86_synth_emit_bytes(s, [137, 65, f_off]) // mov dword [rcx + disp8], eax
        else
            x86_synth_emit_bytes(s, [137, 129])
            x86_synth_emit_u32(s, f_off)
        end
    else
        if f_off < 128
            x86_synth_emit_bytes(s, [72, 137, 65, f_off]) // mov qword [rcx + disp8], rax
        else
            x86_synth_emit_bytes(s, [72, 137, 129])
            x86_synth_emit_u32(s, f_off)
        end
    end
    return 0

fn x86_synth_emit_raw_array_load s elem_sz is_signed
    // WHY: Direct inline scaled load `[rdi + rsi * elem_sz]` -> `%rax` for @bss and struct [N]T arrays.
    // Zero runtime heap calls — 100% freestanding Ring-0 safe.
    if elem_sz == 1
        if is_signed == 1
            x86_synth_emit_bytes(s, [72, 15, 190, 4, 55]) // movsx rax, byte [rdi + rsi]
        else
            x86_synth_emit_bytes(s, [72, 15, 182, 4, 55]) // movzx rax, byte [rdi + rsi]
        end
    elif elem_sz == 2
        if is_signed == 1
            x86_synth_emit_bytes(s, [72, 15, 191, 4, 119]) // movsx rax, word [rdi + rsi*2] (SIB=0x77)
        else
            x86_synth_emit_bytes(s, [72, 15, 183, 4, 119]) // movzx rax, word [rdi + rsi*2]
        end
    elif elem_sz == 4
        if is_signed == 1
            x86_synth_emit_bytes(s, [72, 99, 4, 183]) // movsxd rax, dword [rdi + rsi*4] (SIB=0xB7)
        else
            x86_synth_emit_bytes(s, [139, 4, 183])    // mov eax, dword [rdi + rsi*4]
        end
    else
        x86_synth_emit_bytes(s, [72, 139, 4, 247])    // mov rax, qword [rdi + rsi*8] (SIB=0xF7)
    end
    return 0

fn x86_synth_emit_raw_array_store s elem_sz
    // WHY: Direct inline scaled store `%rdx` -> `[rdi + rsi * elem_sz]` for @bss and struct [N]T arrays.
    if elem_sz == 1
        x86_synth_emit_bytes(s, [136, 20, 55])        // mov byte [rdi + rsi], dl
    elif elem_sz == 2
        x86_synth_emit_bytes(s, [102, 137, 20, 119])  // mov word [rdi + rsi*2], dx
    elif elem_sz == 4
        x86_synth_emit_bytes(s, [137, 20, 183])       // mov dword [rdi + rsi*4], edx
    else
        x86_synth_emit_bytes(s, [72, 137, 20, 247])   // mov qword [rdi + rsi*8], rdx
    end
    return 0

fn x86_synth_raw_elem_tag elem_sz is_signed
    if elem_sz == 1
        if is_signed == 1 return "raw_i8" end
        return "raw_u8"
    elif elem_sz == 2
        if is_signed == 1 return "raw_i16" end
        return "raw_u16"
    elif elem_sz == 4
        if is_signed == 1 return "raw_i32" end
        return "raw_u32"
    elif elem_sz == 8
        if is_signed == 1 return "raw_i64" end
        return "raw_u64"
    end
    return ""

fn x86_synth_parse_raw_elem_tag tag
    // Returns [elem_sz, is_signed] or [0, 0] if not a raw fixed-array tag
    if tag == "raw_u8" return [1, 0] end
    if tag == "raw_i8" return [1, 1] end
    if tag == "raw_u16" return [2, 0] end
    if tag == "raw_i16" return [2, 1] end
    if tag == "raw_u32" return [4, 0] end
    if tag == "raw_i32" return [4, 1] end
    if tag == "raw_u64" return [8, 0] end
    if tag == "raw_i64" return [8, 1] end
    return [0, 0]

fn x86_synth_find_bss s name
    // Returns index into synth_bss_* lists, or -1 if not found
    bi = 0
    while bi < s.synth_bss_names.len()
        if s.synth_bss_names[bi] == name
            return bi
        end
        bi = bi + 1
    end
    return 0 - 1

fn x86_synth_alloc_bss s name byte_size align elem_sz is_signed struct_t
    // WHY: Reserves zero-initialized static aligned storage directly in ELF SHT_NOBITS .bss
    // (GDT/IDT/Page Tables/DMA rings — zero file bloat, zero runtime heap/mmap).
    ex = x86_synth_find_bss(s, name)
    if ex >= 0
        return ex
    end
    al = align
    if al < 16 al = 16 end
    cur = s.synth_bss_cursor
    rem = cur % al
    if rem != 0
        cur = cur + (al - rem)
    end
    idx = s.synth_bss_names.len()
    push(s.synth_bss_names, name)
    push(s.synth_bss_offs, cur)
    push(s.synth_bss_sizes, byte_size)
    push(s.synth_bss_elem_sizes, elem_sz)
    push(s.synth_bss_signed, is_signed)
    push(s.synth_bss_structs, struct_t)
    s.synth_bss_cursor = cur + byte_size
    return idx

fn x86_synth_emit_bss_addr s bss_idx
    // WHY: Loads static @bss buffer address into %rax via movabs imm64 (patched at link time
    // and auto-converted to RIP-relative LEA in Static-PIE / higher-half kernels).
    x86_synth_emit_bytes(s, [72, 184]) // movabs rax, imm64
    p_off = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    push(s.synth_bss_patch_offs, p_off)
    push(s.synth_bss_patch_idxs, bss_idx)
    return 0

fn x86_synth_get_field_offset s sname fname
    // WHY: Determines exact hardware byte offset for struct field access (packed or aligned).
    // Detects offset collisions across distinct named structs on untyped receivers.
    if sname != ""
        matched_struct = 0
        i = s.synth_structs.len() - 1
        while i >= 0
            sd = s.synth_structs[i]
            if sd.sd_name == sname
                matched_struct = 1
                fi = 0
                while fi < sd.sd_fields.len()
                    if sd.sd_fields[fi] == fname
                        if sd.sd_field_offsets != 0 and fi < sd.sd_field_offsets.len()
                            return sd.sd_field_offsets[fi]
                        end
                        return fi * 8
                    end
                    fi = fi + 1
                end
            end
            i = i - 1
        end
        if matched_struct == 1 and s.synth_strict_types == 1
            say "❌ [Strict Type Error]: Struct '" + sname + "' has no field '." + fname + "' (in '" + s.synth_current_fn + "')"
            exit(1)
        end
    end

    // Fallback pass 1: search declared named structs first (skip _anon_s_*) and detect offset collisions
    first_off = 0 - 1
    first_sname = ""
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
                    cand_off = fi * 8
                    if sd.sd_field_offsets != 0 and fi < sd.sd_field_offsets.len()
                        cand_off = sd.sd_field_offsets[fi]
                    end
                    if first_off < 0
                        first_off = cand_off
                        first_sname = sd.sd_name
                    elif cand_off != first_off
                        s.synth_ambiguous_count = s.synth_ambiguous_count + 1
                        if s.synth_strict_types == 1
                            say "❌ [Strict Type Error]: Ambiguous field '." + fname + "' on untyped receiver in '" + s.synth_current_fn + "' — struct '" + first_sname + "' (offset " + str(first_off) + ") collides with struct '" + sd.sd_name + "' (offset " + str(cand_off) + "). Annotate variable or parameter type."
                            exit(1)
                        end
                    end
                    break
                end
                fi = fi + 1
            end
        end
        i = i + 1
    end
    if first_off >= 0
        // WHY: Also detect collisions between a named @struct and any anonymous record literal (_anon_s_*)
        // that defines the same field name at a different offset (e.g. LipiDatabase.fd@64 vs {fd:...}@0).
        ai = 0
        while ai < s.synth_structs.len()
            asd = s.synth_structs[ai]
            if len(asd.sd_name) > 8 and str_sub(asd.sd_name, 0, 8) == "_anon_s_"
                afi = 0
                while afi < asd.sd_fields.len()
                    if asd.sd_fields[afi] == fname
                        acand_off = afi * 8
                        if asd.sd_field_offsets != 0 and afi < asd.sd_field_offsets.len()
                            acand_off = asd.sd_field_offsets[afi]
                        end
                        if acand_off != first_off
                            s.synth_ambiguous_count = s.synth_ambiguous_count + 1
                            if s.synth_strict_types == 1
                                say "❌ [Strict Type Error]: Ambiguous field '." + fname + "' on untyped receiver in '" + s.synth_current_fn + "' — struct '" + first_sname + "' (offset " + str(first_off) + ") collides with anonymous struct '" + asd.sd_name + "' (offset " + str(acand_off) + "). Define a named @struct or annotate variable/parameter type."
                                exit(1)
                            end
                        end
                        break
                    end
                    afi = afi + 1
                end
            end
            ai = ai + 1
        end
        return first_off
    end

    // Fallback pass 2: search across all registered struct schemas (including anonymous) and detect collisions
    anon_first_off = 0 - 1
    anon_first_sname = ""
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        fi = 0
        while fi < sd.sd_fields.len()
            if sd.sd_fields[fi] == fname
                cand_off2 = fi * 8
                if sd.sd_field_offsets != 0 and fi < sd.sd_field_offsets.len()
                    cand_off2 = sd.sd_field_offsets[fi]
                end
                if anon_first_off < 0
                    anon_first_off = cand_off2
                    anon_first_sname = sd.sd_name
                elif cand_off2 != anon_first_off
                    s.synth_ambiguous_count = s.synth_ambiguous_count + 1
                    if s.synth_strict_types == 1
                        say "❌ [Strict Type Error]: Ambiguous field '." + fname + "' on untyped receiver in '" + s.synth_current_fn + "' — anonymous struct '" + anon_first_sname + "' (offset " + str(anon_first_off) + ") collides with anonymous struct '" + sd.sd_name + "' (offset " + str(cand_off2) + "). Define a named @struct or annotate variable/parameter type."
                        exit(1)
                    end
                end
                break
            end
            fi = fi + 1
        end
        i = i + 1
    end
    if anon_first_off >= 0
        return anon_first_off
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
    // Fallback pass 2: search anonymous struct literals (_anon_s_*) if named structs had no match
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        is_anon = 0
        if len(sd.sd_name) > 8 and str_sub(sd.sd_name, 0, 8) == "_anon_s_"
            is_anon = 1
        end
        if is_anon == 1
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
    // WHY: Treats top-level `g_*` and `G_*` variables as cross-function mutable RW globals.
    if len(name) >= 2 and (char_at(name, 0) == "g" or char_at(name, 0) == "G") and char_at(name, 1) == "_"
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
    // WHY: Allocates an 8-byte RW .data/.bss slot starting at offset 512 (auto-expanding PT_LOAD[1] beyond 4KB).
    existing = x86_synth_find_mutable_global(s, name)
    if existing >= 512
        return existing
    end
    slot_off = 512 + (s.synth_mutable_globals.len() * 8)
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
    lv.lv_is_boxed = 0
    lv.lv_tag_off = 0

    // WHY: Boxed upvalue cells stay in their dedicated stack slot so closures capture the heap cell address.
    if x86_synth_is_boxed_name(s, name) == 1
        lv.lv_is_boxed = 1
        push(s.synth_locals, lv)
        return off
    end

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

fn x86_synth_set_elem_type s name elem_type
    // WHY: Tracks primitive element types of local lists/arrays ("float", etc.) for typed indexing.
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            v.lv_elem_type = elem_type
            return 0
        i = i + 1
    return 0

fn x86_synth_get_elem_type s name
    // WHY: Returns inferred list/array element primitive type ("float", or "").
    i = 0
    n = s.synth_locals.len()
    while i < n
        v = s.synth_locals[i]
        if v.lv_name == name
            if v.lv_elem_type != 0
                return v.lv_elem_type
            return ""
        i = i + 1
    return ""

fn x86_synth_bind_reg_var s var_name is_reg
    // WHY: Binds expression result in %rax to local variable. Supports register-allocated locals,
    // stack slots, and 8-byte GC upvalue cells for mutable closure captures.
    ex_lv = x86_synth_find_local_var(s, var_name)
    off = x86_synth_alloc_reg_var(s, var_name, is_reg)
    lv = x86_synth_find_local_var(s, var_name)
    if lv != 0
        if s.synth_last_expr_type == "dyn_tagged"
            if lv.lv_tag_off == 0
                lv.lv_tag_off = s.synth_stack_offset
                s.synth_stack_offset = s.synth_stack_offset + 8
                push(s.synth_fn_tag_offs, lv.lv_tag_off)
            end
            x86_synth_emit_store_var(s, 2, lv.lv_tag_off) // mov [rbp - lv_tag_off], rdx
        elif lv.lv_tag_off > 0 or (s.synth_freestanding == 0 and x86_synth_is_dyn_var(s, var_name) == 1)
            if lv.lv_tag_off == 0
                lv.lv_tag_off = s.synth_stack_offset
                s.synth_stack_offset = s.synth_stack_offset + 8
                push(s.synth_fn_tag_offs, lv.lv_tag_off)
            end
            st_tag = 0
            if s.synth_last_expr_type == "float"
                st_tag = 1
            elif s.synth_last_expr_type == "str"
                st_tag = 2
            end
            x86_synth_emit_store_imm64_to_var(s, lv.lv_tag_off, st_tag)
        end
    end
    if lv != 0 and lv.lv_is_boxed == 1
        if ex_lv == 0
            // First declaration of boxed variable: allocate 8B GC cell, store initial %rax inside, save cell ptr to slot
            x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
            x86_synth_emit_mov_rdi_imm64(s, 8)
            x86_synth_emit_call_alloc(s)
            x86_synth_emit_store_var(s, 0, off)
            x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 72, 137, 8, 72, 137, 200]) // add rsp, 8; pop rcx; mov [rax], rcx; mov rax, rcx
        else
            // Subsequent mutation of existing boxed cell: load cell ptr into %rcx, store %rax into [rcx]
            x86_synth_emit_load_var(s, 1, off)
            x86_synth_emit_bytes(s, [72, 137, 1]) // mov [rcx], rax
        end
        s.synth_last_store_end = 0 - 1
    elif lv != 0 and lv.lv_is_spilled == 0 and lv.lv_reg >= 0
        // WHY: When allocated to a hardware register (%r12-%r15, %rbx) and unspilled,
        // move directly into physical register without redundant shadow stack writes.
        x86_synth_emit_mov_reg_reg(s, lv.lv_reg, 0)
    else
        x86_synth_emit_store_var(s, 0, off)
    end
    if s.synth_last_struct != ""
        x86_synth_set_var_type(s, var_name, s.synth_last_struct)
        s.synth_last_struct = ""
    end
    if s.synth_last_elem_type != ""
        x86_synth_set_elem_type(s, var_name, s.synth_last_elem_type)
        s.synth_last_elem_type = ""
    else
        x86_synth_set_elem_type(s, var_name, "")
    end
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

fn x86_synth_line_has_inline_end toks start_pos start_line
    // WHY: Detects explicit single-line block terminators (`if cond s1; s2 end`) on start_line
    // so semicolons separate statements inside the inline block instead of prematurely closing it.
    n = toks.len()
    i = start_pos
    depth = 0
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF() or k == TOK_NEWLINE() or t.tok_span.span_start_line > start_line
            return 0
        end
        if k == TOK_KW_IF() or k == TOK_DIR_IF() or k == TOK_KW_WHILE() or k == TOK_DIR_WHILE() or k == TOK_KW_FOR() or k == TOK_DIR_FOR() or (k == TOK_IDENT() and (txt == "if" or txt == "যদি" or txt == "@if" or txt == "while" or txt == "যতক্ষণ" or txt == "@while" or txt == "for" or txt == "জন্য" or txt == "@for"))
            depth = depth + 1
        elif x86_synth_is_block_end(toks, i) == 1
            if depth == 0
                return 1
            end
            depth = depth - 1
        end
        i = i + 1
    end
    return 0
end

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

// ── Wave G Helpers: Generic Type Params/Args, Struct Specialization, Tagged ADTs ──

fn x86_synth_norm_type_name t
    if t == "f64" or t == "f32" or t == "float" or t == "দশমিক"
        return "float"
    elif t == "i64" or t == "i32" or t == "u64" or t == "u32" or t == "int" or t == "সংখ্যা" or t == "পূর্ণসংখ্যা"
        return "int"
    elif t == "str" or t == "string" or t == "স্ট্রিং"
        return "str"
    end
    return t
end

fn x86_synth_parse_type_list toks pos_box require_lparen
    // WHY: Parses `<T, U>` or `<Box<float>, int>` without colliding with `<` comparisons.
    // When require_lparen == 1 (call sites), requires `(` immediately after closing `>`.
    // Returns list of type strings (e.g. ["float"] or ["Box<float>", "int"]), or 0 if not a type list.
    p = get(pos_box, 0)
    if p >= toks.len() return 0 end
    if toks[p].tok_kind != TOK_LT() and not (toks[p].tok_kind != TOK_STR() and toks[p].tok_text == "<")
        return 0
    end
    scan = p + 1
    depth = 1
    items = list()
    cur_item = ""
    while scan < toks.len() and depth > 0
        tk = toks[scan].tok_kind
        tx = toks[scan].tok_text
        if tk == TOK_LT() or (tk != TOK_STR() and tx == "<")
            depth = depth + 1
            cur_item = cur_item + "<"
        elif tk == TOK_GT() or (tk != TOK_STR() and tx == ">")
            depth = depth - 1
            if depth == 0
                if cur_item != "" push(items, cur_item) end
                scan = scan + 1
                break
            else
                cur_item = cur_item + ">"
            end
        elif tk == TOK_SHR() or (tk != TOK_STR() and tx == ">>")
            if depth == 2
                cur_item = cur_item + ">"
                depth = 0
                if cur_item != "" push(items, cur_item) end
                scan = scan + 1
                break
            elif depth > 2
                cur_item = cur_item + ">>"
                depth = depth - 2
            else
                return 0
            end
        elif (tk == TOK_COMMA() or (tk != TOK_STR() and tx == ",")) and depth == 1
            if cur_item == "" return 0 end
            push(items, cur_item)
            cur_item = ""
        elif tk == TOK_COMMA() or (tk != TOK_STR() and tx == ",")
            cur_item = cur_item + ","
        elif tk == TOK_NEWLINE()
            // skip whitespace inside multi-line type list
        elif x86_synth_is_ident_token(tk) == 1
            cur_item = cur_item + tx
        else
            return 0
        end
        scan = scan + 1
    end
    if depth != 0 or items.len() == 0
        return 0
    end
    if require_lparen == 1
        if scan >= toks.len() return 0 end
        if toks[scan].tok_kind != TOK_LPAREN() and not (toks[scan].tok_kind != TOK_STR() and toks[scan].tok_text == "(")
            return 0
        end
    end
    list_set(pos_box, 0, scan)
    return items
end

fn x86_synth_parse_type_expr toks pos_box
    // WHY: Parses a type annotation `Name`, `Name<Arg1, Arg2>`, or fixed-size array `[N]T` (e.g. `[512]u8`).
    p = get(pos_box, 0)
    if p >= toks.len() return "" end
    if toks[p].tok_kind == TOK_LBRACKET() or (toks[p].tok_kind != TOK_STR() and toks[p].tok_text == "[")
        if p + 3 < toks.len() and toks[p + 1].tok_kind == TOK_INT() and (toks[p + 2].tok_kind == TOK_RBRACKET() or toks[p + 2].tok_text == "]")
            arr_n = str(toks[p + 1].tok_int_val)
            list_set(pos_box, 0, p + 3)
            el_t = x86_synth_parse_type_expr(toks, pos_box)
            if el_t != ""
                return "[" + arr_n + "]" + el_t
            end
        end
        return ""
    end
    if x86_synth_is_ident_token(toks[p].tok_kind) == 0 return "" end
    base_t = toks[p].tok_text
    list_set(pos_box, 0, p + 1)
    targs = x86_synth_parse_type_list(toks, pos_box, 0)
    if targs != 0 and targs.len() > 0
        res = base_t + "<"
        ti = 0
        while ti < targs.len()
            if ti > 0 res = res + "," end
            res = res + targs[ti]
            ti = ti + 1
        end
        res = res + ">"
        return res
    end
    return base_t
end

fn x86_synth_specialize_struct s base_sdef targs
    // WHY: Compile-time monomorphizes `struct Box<T>` into cached `Box__g_float` with concrete field types & layout.
    if base_sdef == 0 or targs == 0 or targs.len() == 0
        return base_sdef
    end
    mangled = base_sdef.sd_name + "__g"
    ti = 0
    while ti < targs.len()
        mangled = mangled + "_" + x86_synth_norm_type_name(targs[ti])
        ti = ti + 1
    end
    existing = x86_synth_find_struct(s, mangled)
    if existing != 0
        return existing
    end
    ns = X86StructDef()
    ns.sd_name = mangled
    ns.sd_fields = base_sdef.sd_fields
    ns.sd_type_params = list()
    new_ftypes = list()
    fi = 0
    while fi < base_sdef.sd_field_types.len()
        raw_ft = base_sdef.sd_field_types[fi]
        sub_ft = x86_synth_subst_type(s, raw_ft, base_sdef.sd_type_params, targs)
        push(new_ftypes, sub_ft)
        fi = fi + 1
    end
    ns.sd_field_types = new_ftypes
    ns.sd_is_packed = base_sdef.sd_is_packed
    ns.sd_align = base_sdef.sd_align
    x86_synth_compute_struct_layout(s, ns)
    push(s.synth_structs, ns)
    return ns
end

fn x86_synth_subst_type s raw_t tparams targs
    // WHY: Substitutes generic type parameters `T` -> `float` and generic struct refs `Box<T>` -> `Box__g_float`.
    if raw_t == "" return "" end
    if tparams != 0 and targs != 0
        pi = 0
        while pi < tparams.len() and pi < targs.len()
            if raw_t == tparams[pi]
                return x86_synth_norm_type_name(targs[pi])
            end
            pi = pi + 1
        end
    end
    // Check if raw_t contains '<' (e.g. "Box<T>" or "Box<float>")
    lt_idx = 0 - 1
    n_rt = len(raw_t)
    ci = 0
    while ci < n_rt
        if char_at(raw_t, ci) == "<"
            lt_idx = ci
            break
        end
        ci = ci + 1
    end
    if lt_idx > 0 and char_at(raw_t, n_rt - 1) == ">"
        base_nm = str_sub(raw_t, 0, lt_idx)
        inner = str_sub(raw_t, lt_idx + 1, n_rt - 1)
        // Split top-level commas in inner
        sub_args = list()
        seg_s = 0
        dep = 0
        ii = 0
        ilen = len(inner)
        while ii < ilen
            ch = char_at(inner, ii)
            if ch == "<" dep = dep + 1
            elif ch == ">" dep = dep - 1
            elif ch == "," and dep == 0
                push(sub_args, x86_synth_subst_type(s, str_sub(inner, seg_s, ii), tparams, targs))
                seg_s = ii + 1
            end
            ii = ii + 1
        end
        if seg_s < ilen
            push(sub_args, x86_synth_subst_type(s, str_sub(inner, seg_s, ilen), tparams, targs))
        end
        base_sd = x86_synth_find_struct(s, base_nm)
        if base_sd != 0 and base_sd.sd_type_params != 0 and base_sd.sd_type_params.len() > 0
            spec_sd = x86_synth_specialize_struct(s, base_sd, sub_args)
            return spec_sd.sd_name
        end
        return base_nm
    end
    return raw_t
end

fn x86_synth_find_enum s ename
    ei = 0
    while ei < s.synth_enums.len()
        if s.synth_enums[ei].ed_name == ename
            return s.synth_enums[ei]
        end
        ei = ei + 1
    end
    return 0
end

fn x86_synth_find_adt_variant s enum_qual var_name
    // WHY: Looks up an enum variant across all registered X86EnumDefs.
    // Returns [ed, variant_idx] if found, else 0.
    ei = s.synth_enums.len() - 1
    while ei >= 0
        ed = s.synth_enums[ei]
        if enum_qual == "" or ed.ed_name == enum_qual
            vi = 0
            while vi < ed.ed_variants.len()
                if ed.ed_variants[vi] == var_name
                    return [ed, vi]
                end
                vi = vi + 1
            end
        end
        ei = ei - 1
    end
    return 0
end

fn x86_synth_register_enum_from_tokens s toks pos_box e_col e_line
    // WHY: Unified parser for BOTH Tagged ADTs (`enum Result<T, E> { Ok(T), Err(E) }`)
    // and C-style integer enums (`enum Color { RED, GREEN = 5 }`).
    pos = get(pos_box, 0)
    list_set(pos_box, 0, pos + 1) // Consume enum keyword
    ename = ""
    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
        ename = toks[get(pos_box, 0)].tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end
    tparams = x86_synth_parse_type_list(toks, pos_box, 0)
    if tparams == 0 tparams = list() end
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    en_braced = 0
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
        en_braced = 1
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end
    v_names = list()
    v_arities = list()
    v_ftypes = list()
    v_int_vals = list()
    has_payload = 0
    e_val = 0
    while get(pos_box, 0) < toks.len()
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        ep = get(pos_box, 0)
        if ep >= toks.len() break end
        et = toks[ep]
        ek = et.tok_kind
        etx = et.tok_text
        if en_braced == 1
            if ek == TOK_RBRACE() or (ek != TOK_STR() and etx == "}")
                list_set(pos_box, 0, ep + 1)
                break
            end
            if ek == TOK_COMMA() or (ek != TOK_STR() and etx == ",")
                list_set(pos_box, 0, ep + 1)
                continue
            end
        else
            if ek == TOK_KW_END() or ek == TOK_DIR_END() or (ek == TOK_IDENT() and (etx == "end" or etx == "শেষ" or etx == "@end"))
                list_set(pos_box, 0, ep + 1)
                break
            end
            if ek == TOK_KW_FN() or ek == TOK_DIR_FN() or ek == TOK_KW_STRUCT() or ek == TOK_DIR_STRUCT() or ek == TOK_KW_ENUM() or ek == TOK_DIR_ENUM()
                break
            end
            if ek == TOK_IDENT() and (etx == "fn" or etx == "কাজ" or etx == "@fn" or etx == "struct" or etx == "গঠন" or etx == "@struct" or etx == "enum" or etx == "@enum" or etx == "গণনা")
                break
            end
            if et.tok_span.span_start_line > e_line and et.tok_span.span_start_col <= e_col
                break
            end
            if ek == TOK_COMMA() or (ek != TOK_STR() and etx == ",")
                list_set(pos_box, 0, ep + 1)
                continue
            end
        end
        if x86_synth_is_ident_token(ek) == 1
            vname = etx
            list_set(pos_box, 0, ep + 1)
            f_list = list()
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                has_payload = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    vp = get(pos_box, 0)
                    if vp >= toks.len() break end
                    if toks[vp].tok_kind == TOK_RPAREN() or (toks[vp].tok_kind != TOK_STR() and toks[vp].tok_text == ")")
                        list_set(pos_box, 0, vp + 1)
                        break
                    elif toks[vp].tok_kind == TOK_COMMA() or (toks[vp].tok_kind != TOK_STR() and toks[vp].tok_text == ",")
                        list_set(pos_box, 0, vp + 1)
                    else
                        ft_v = x86_synth_parse_type_expr(toks, pos_box)
                        if ft_v == ""
                            list_set(pos_box, 0, vp + 1)
                        else
                            push(f_list, ft_v)
                        end
                    end
                end
            elif get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN() or toks[get(pos_box, 0)].tok_text == "=")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len()
                    v_tok = toks[get(pos_box, 0)]
                    if v_tok.tok_kind == TOK_INT()
                        e_val = v_tok.tok_int_val
                    end
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            push(v_names, vname)
            push(v_arities, f_list.len())
            push(v_ftypes, f_list)
            push(v_int_vals, e_val)
            e_val = e_val + 1
        else
            list_set(pos_box, 0, ep + 1)
        end
    end
    is_adt = 0
    if has_payload == 1 or tparams.len() > 0
        is_adt = 1
    end
    if is_adt == 0
        vi = 0
        while vi < v_names.len()
            x86_synth_set_global_const(s, v_names[vi], v_int_vals[vi])
            vi = vi + 1
        end
    end
    if ename != "" and x86_synth_find_enum(s, ename) == 0
        ed = X86EnumDef()
        ed.ed_name = ename
        ed.ed_variants = v_names
        ed.ed_arities = v_arities
        ed.ed_field_types = v_ftypes
        ed.ed_is_adt = is_adt
        ed.ed_type_params = tparams
        push(s.synth_enums, ed)
    end
    return 0
end

fn x86_synth_emit_adt_alloc s tag arity arg_expr_types
    // WHY: Allocates a GC-traced ADT0 cell: [0]=tag, [8]=arity, [16]=0x41445430|(tag_mask<<32), [24+]=payloads.
    // Preserves dynamic float/str payload tags with 0 bytes of extra memory overhead.
    single_dyn = 0
    if arity == 1 and arg_expr_types != 0 and arg_expr_types.len() >= 1 and arg_expr_types[0] == "dyn_tagged"
        single_dyn = 1
        // Save live %rdx tag across __alloc while keeping stack 16-byte aligned: sub rsp, 8; push rdx
        x86_synth_emit_bytes(s, [72, 131, 236, 8, 82])
    end
    alloc_sz = (3 + arity) * 8
    if alloc_sz < 32 alloc_sz = 32 end
    x86_synth_emit_mov_rdi_imm64(s, alloc_sz)
    x86_synth_emit_call_alloc(s)
    // mov r10, rax
    x86_synth_emit_bytes(s, [73, 137, 194])
    // mov qword ptr [r10 + 0], tag
    x86_synth_emit_bytes(s, [73, 199, 2])
    x86_synth_emit_u32(s, tag)
    // mov qword ptr [r10 + 8], arity
    x86_synth_emit_bytes(s, [73, 199, 66, 8])
    x86_synth_emit_u32(s, arity)
    if single_dyn == 1
        // pop rdx; add rsp, 8; and edx, 3; shl rdx, 32; mov eax, 0x41445430; or rax, rdx; mov [r10+16], rax
        x86_synth_emit_bytes(s, [90, 72, 131, 196, 8, 131, 226, 3, 72, 193, 226, 32, 184, 48, 84, 68, 65, 72, 9, 208, 73, 137, 66, 16])
    else
        tag_mask = 0
        if arg_expr_types != 0
            ti = 0
            shift_mul = 1
            while ti < arity and ti < arg_expr_types.len() and ti < 16
                at = arg_expr_types[ti]
                tbits = 0
                if at == "float" tbits = 1
                elif at == "str" tbits = 2
                end
                tag_mask = tag_mask + (tbits * shift_mul)
                shift_mul = shift_mul * 4
                ti = ti + 1
            end
        end
        hdr_word = 1094997040 + (tag_mask * 4294967296)
        x86_synth_emit_mov_rax_imm64(s, hdr_word)
        x86_synth_emit_bytes(s, [73, 137, 66, 16]) // mov [r10 + 16], rax
    end
    ai = arity - 1
    while ai >= 0
        x86_synth_emit_byte(s, 89) // pop rcx
        off = 24 + (ai * 8)
        if off < 128
            x86_synth_emit_bytes(s, [73, 137, 74, off]) // mov [r10 + off], rcx
        else
            x86_synth_emit_bytes(s, [73, 137, 138])
            x86_synth_emit_u32(s, off)
        end
        ai = ai - 1
    end
    // Restore cell pointer to %rax: mov rax, r10
    x86_synth_emit_bytes(s, [76, 137, 208])
    s.synth_last_store_end = 0 - 1
    return 0
end

fn x86_synth_try_compile_adt_pattern s toks pos_box scrut_off
    // WHY: Compiles ADT destructuring patterns `[Enum::]Variant[(b0, b1, ...)]` in match arms.
    // Returns a list of jump patch offsets (miss_patches) if matched as an ADT pattern, else 0.
    p = get(pos_box, 0)
    if p >= toks.len() or x86_synth_is_ident_token(toks[p].tok_kind) == 0
        return 0
    end
    scan = p
    enum_qual = ""
    var_name = toks[scan].tok_text
    scan = scan + 1
    if scan + 2 < toks.len() and (toks[scan].tok_kind == TOK_COLON() or toks[scan].tok_text == ":") and (toks[scan + 1].tok_kind == TOK_COLON() or toks[scan + 1].tok_text == ":") and x86_synth_is_ident_token(toks[scan + 2].tok_kind) == 1
        enum_qual = var_name
        var_name = toks[scan + 2].tok_text
        scan = scan + 3
    end
    vinfo = x86_synth_find_adt_variant(s, enum_qual, var_name)
    if vinfo == 0
        return 0
    end
    ed = vinfo[0]
    v_idx = vinfo[1]
    if ed.ed_is_adt == 0
        return 0
    end
    binds = list()
    if scan < toks.len() and (toks[scan].tok_kind == TOK_LPAREN() or toks[scan].tok_text == "(")
        scan = scan + 1
        while scan < toks.len()
            sk = toks[scan].tok_kind
            stx = toks[scan].tok_text
            if sk == TOK_RPAREN() or (sk != TOK_STR() and stx == ")")
                scan = scan + 1
                break
            elif sk == TOK_COMMA() or (sk != TOK_STR() and stx == ",") or sk == TOK_NEWLINE()
                scan = scan + 1
            elif x86_synth_is_ident_token(sk) == 1
                push(binds, stx)
                scan = scan + 1
            else
                return 0
            end
        end
    end
    list_set(pos_box, 0, scan)

    // Emit tag & ADT0 magic verification on scrutinee
    miss_patches = list()
    x86_synth_emit_load_var(s, 0, scrut_off)
    x86_synth_emit_bytes(s, [72, 61, 0, 16, 0, 0, 15, 130]) // cmp rax, 4096; jb miss
    m1 = s.synth_code.len()
    x86_synth_emit_u32(s, 0)
    push(miss_patches, m1)
    x86_synth_emit_bytes(s, [129, 120, 16, 48, 84, 68, 65, 15, 133]) // cmp dword [rax+16], 'ADT0'; jne miss
    m2 = s.synth_code.len()
    x86_synth_emit_u32(s, 0)
    push(miss_patches, m2)
    x86_synth_emit_bytes(s, [72, 129, 56]) // cmp qword [rax+0], v_idx
    x86_synth_emit_u32(s, v_idx)
    x86_synth_emit_bytes(s, [15, 133]) // jne miss
    m3 = s.synth_code.len()
    x86_synth_emit_u32(s, 0)
    push(miss_patches, m3)

    // Destructure & bind payload variables into current arm scope
    v_ft_list = ed.ed_field_types[v_idx]
    bi = 0
    while bi < binds.len()
        bname = binds[bi]
        if bname != "_"
            x86_synth_emit_load_var(s, 1, scrut_off) // mov rcx, [rbp - scrut_off]
            poff = 24 + (bi * 8)
            if poff < 128
                x86_synth_emit_bytes(s, [72, 139, 65, poff]) // mov rax, [rcx + poff]
            else
                x86_synth_emit_bytes(s, [72, 139, 129])
                x86_synth_emit_u32(s, poff)
            end
            decl_ft = ""
            if v_ft_list != 0 and bi < v_ft_list.len()
                decl_ft = x86_synth_norm_type_name(v_ft_list[bi])
            end
            if decl_ft == "float" or decl_ft == "int" or decl_ft == "str"
                s.synth_last_expr_type = decl_ft
                s.synth_last_struct = ""
                x86_synth_bind_var(s, bname)
                x86_synth_set_prim_type(s, bname, decl_ft)
            else
                // Generic / dynamic payload: extract 2-bit runtime tag from [rcx + 20] into %rdx!
                x86_synth_emit_bytes(s, [139, 81, 20]) // mov edx, dword ptr [rcx + 20]
                if bi > 0
                    x86_synth_emit_bytes(s, [193, 234, bi * 2]) // shr edx, bi*2
                end
                x86_synth_emit_bytes(s, [131, 226, 3]) // and edx, 3
                s.synth_last_expr_type = "dyn_tagged"
                s.synth_last_struct = ""
                x86_synth_bind_var(s, bname)
                x86_synth_set_prim_type(s, bname, "dyn_tagged")
                if decl_ft != "" and x86_synth_find_struct(s, decl_ft) != 0
                    x86_synth_set_var_type(s, bname, decl_ft)
                end
            end
        end
        bi = bi + 1
    end
    s.synth_last_store_end = 0 - 1
    return miss_patches
end

fn x86_synth_compile_struct_def s toks pos_box base_col base_line
    // WHY: Registers user-defined struct schemas (including generic `struct Box<T>`) with ordered field offsets.
    pos = get(pos_box, 0)
    list_set(pos_box, 0, pos + 1) // Consume 'struct'

    sname_tok = toks[get(pos_box, 0)]
    sname = sname_tok.tok_text
    list_set(pos_box, 0, get(pos_box, 0) + 1)

    tparams = x86_synth_parse_type_list(toks, pos_box, 0)
    if tparams == 0 tparams = list() end

    x86_synth_skip_whitespace_tokens(toks, pos_box)
    st_braced = 0
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
        st_braced = 1
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end

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

        if st_braced == 1
            if cur_k == TOK_RBRACE() or (cur_k != TOK_STR() and cur_txt == "}")
                list_set(pos_box, 0, cur_p + 1)
                break
            end
            if cur_k == TOK_COMMA() or (cur_k != TOK_STR() and cur_txt == ",")
                list_set(pos_box, 0, cur_p + 1)
                continue
            end
        else
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)
                break
            if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_STRUCT() or cur_k == TOK_DIR_STRUCT() or cur_k == TOK_KW_ENUM() or cur_k == TOK_DIR_ENUM()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "struct" or cur_txt == "গঠন" or cur_txt == "enum" or cur_txt == "@enum" or cur_txt == "গণনা")
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break
        end

        if cur_k == TOK_IDENT()
            push(fields, cur_txt)
            ftype = ""
            list_set(pos_box, 0, cur_p + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            np = get(pos_box, 0)
            if np < toks.len() and (toks[np].tok_kind == TOK_COLON() or (toks[np].tok_kind != TOK_STR() and toks[np].tok_text == ":"))
                list_set(pos_box, 0, np + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                ftype = x86_synth_parse_type_expr(toks, pos_box)
            end
            push(field_types, ftype)
        else
            list_set(pos_box, 0, cur_p + 1)

    sdef = X86StructDef()
    sdef.sd_name = sname
    sdef.sd_fields = fields
    sdef.sd_field_types = field_types
    sdef.sd_type_params = tparams
    sdef.sd_is_packed = s.synth_pending_struct_packed
    sdef.sd_align = s.synth_pending_struct_align
    s.synth_pending_struct_packed = 0
    s.synth_pending_struct_align = 0
    x86_synth_compute_struct_layout(s, sdef)
    push(s.synth_structs, sdef)
    return 0

fn x86_synth_emit_store_param s pi off
    // WHY: Standard System V AMD64 ABI parameter ingress (unlimited argument count!):
    // Params 0..5 arrive in %rdi, %rsi, %rdx, %rcx, %r8, %r9;
    // Params 6..N-1 arrive on caller's stack at [rbp + 16 + (pi - 6)*8] without touching %r12-%r15.
    if pi == 0
        x86_synth_emit_store_var(s, 7, off) // %rdi
    elif pi == 1
        x86_synth_emit_store_var(s, 6, off) // %rsi
    elif pi == 2
        x86_synth_emit_store_var(s, 2, off) // %rdx
    elif pi == 3
        x86_synth_emit_store_var(s, 1, off) // %rcx
    elif pi == 4 or pi == 5
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
        end
    else
        // Stack argument: mov rax, [rbp + 16 + (pi - 6) * 8]; store rax -> [rbp - off]
        s_disp = 16 + ((pi - 6) * 8)
        x86_synth_emit_bytes(s, [72, 139, 133]) // mov rax, [rbp + disp32]
        x86_synth_emit_u32(s, s_disp)
        x86_synth_emit_store_var(s, 0, off)
    end
    return 0

fn x86_synth_emit_pop_args s arg_count
    // WHY: Standard System V AMD64 ABI argument marshal supporting UNLIMITED arguments
    // with strict 16-byte stack alignment and zero clobbering of %rax or callee-saved %r12-%r15.
    // Returns cleanup_bytes (0 if arg_count <= 6, else 16B-aligned stack arg bytes to add back after call).
    if arg_count <= 6
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
            elif ai == 4
                x86_synth_emit_bytes(s, [65, 88]) // pop r8
            elif ai == 5
                x86_synth_emit_bytes(s, [65, 89]) // pop r9
            end
            ai = ai - 1
        end
        if arg_count == 1
            x86_synth_emit_bytes(s, [49, 246]) // xor esi, esi
        end
        return 0
    end

    // arg_count > 6: Stack currently holds [rsp+0]=a_{n-1} .. [rsp+(extra-1)*8]=a6, [rsp+extra*8]=a5 .. [rsp+(n-1)*8]=a0.
    // Step 1: Load a0..a5 into rdi, rsi, rdx, rcx, r8, r9 directly from stack without modifying %rax or %r12-%r15.
    extra = arg_count - 6
    aligned_bytes = ((extra + 1) / 2) * 16
    shift = (arg_count * 8) - aligned_bytes
    x86_synth_emit_bytes(s, [72, 139, 188, 36]) // mov rdi, [rsp + (extra+5)*8]
    x86_synth_emit_u32(s, (extra + 5) * 8)
    x86_synth_emit_bytes(s, [72, 139, 180, 36]) // mov rsi, [rsp + (extra+4)*8]
    x86_synth_emit_u32(s, (extra + 4) * 8)
    x86_synth_emit_bytes(s, [72, 139, 148, 36]) // mov rdx, [rsp + (extra+3)*8]
    x86_synth_emit_u32(s, (extra + 3) * 8)
    x86_synth_emit_bytes(s, [72, 139, 140, 36]) // mov rcx, [rsp + (extra+2)*8]
    x86_synth_emit_u32(s, (extra + 2) * 8)
    x86_synth_emit_bytes(s, [76, 139, 132, 36]) // mov r8,  [rsp + (extra+1)*8]
    x86_synth_emit_u32(s, (extra + 1) * 8)
    x86_synth_emit_bytes(s, [76, 139, 140, 36]) // mov r9,  [rsp + extra*8]
    x86_synth_emit_u32(s, extra * 8)

    // Step 2: Reverse a6..a_{n-1} in-place at [rsp+0 .. (extra-1)*8] using scratch %r10, %r11.
    half = extra / 2
    ri = 0
    while ri < half
        o1 = ri * 8
        o2 = (extra - 1 - ri) * 8
        x86_synth_emit_bytes(s, [76, 139, 148, 36]) // mov r10, [rsp + o1]
        x86_synth_emit_u32(s, o1)
        x86_synth_emit_bytes(s, [76, 139, 156, 36]) // mov r11, [rsp + o2]
        x86_synth_emit_u32(s, o2)
        x86_synth_emit_bytes(s, [76, 137, 156, 36]) // mov [rsp + o1], r11
        x86_synth_emit_u32(s, o1)
        x86_synth_emit_bytes(s, [76, 137, 148, 36]) // mov [rsp + o2], r10
        x86_synth_emit_u32(s, o2)
        ri = ri + 1
    end

    // Step 3: Shift forward-ordered a6..a_{n-1} upward by `shift` bytes (non-overlapping backward copy).
    ki = extra - 1
    while ki >= 0
        src_o = ki * 8
        dst_o = shift + (ki * 8)
        x86_synth_emit_bytes(s, [76, 139, 148, 36]) // mov r10, [rsp + src_o]
        x86_synth_emit_u32(s, src_o)
        x86_synth_emit_bytes(s, [76, 137, 148, 36]) // mov [rsp + dst_o], r10
        x86_synth_emit_u32(s, dst_o)
        ki = ki - 1
    end

    // Step 4: Advance %rsp by `shift` -> %rsp is 16B aligned with [rsp+0]=a6, [rsp+8]=a7, ...
    x86_synth_emit_bytes(s, [72, 129, 196]) // add rsp, imm32
    x86_synth_emit_u32(s, shift)
    return aligned_bytes

fn x86_synth_emit_cleanup_stack_args s cleanup_bytes
    if cleanup_bytes > 0
        x86_synth_emit_bytes(s, [72, 129, 196]) // add rsp, imm32
        x86_synth_emit_u32(s, cleanup_bytes)
    end
    return 0

fn x86_synth_emit_save_r12_r15 s
    // WHY: Lipi passes args 9..12 in %r12..%r15, which are also callee-saved registers.
    // Call sites with arg_count >= 9 spill caller %r12..%r15 before pop_args and restore after call.
    offs = list()
    r = 12
    while r <= 15
        off = x86_synth_alloc_var(s, "__abi_save_r" + str(r))
        push(offs, off)
        x86_synth_emit_byte(s, 76)  // REX.W + REX.R (0x4C)
        x86_synth_emit_byte(s, 137) // mov [rbp + disp32], r64
        x86_synth_emit_byte(s, 133 + (r - 8) * 8)
        x86_synth_emit_u32(s, 0 - off)
        r = r + 1
    end
    return offs

fn x86_synth_emit_restore_r12_r15 s offs
    if offs == 0 or offs.len() < 4
        return 0
    end
    i = 0
    while i < 4
        r = 12 + i
        off = offs[i]
        x86_synth_emit_byte(s, 76)  // REX.W + REX.R (0x4C)
        x86_synth_emit_byte(s, 139) // mov r64, [rbp + disp32]
        x86_synth_emit_byte(s, 133 + (r - 8) * 8)
        x86_synth_emit_u32(s, 0 - off)
        i = i + 1
    end
    return 0

fn x86_synth_parse_float_bits s_text
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

    // Split into integer, fractional, and optional scientific exponent parts
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
    num = (int_part * 1)
    k = 0
    while k < frac_digits
        num = num * 10
        k = k + 1
    end
    num = num + frac_part
    den = 1
    exp = 1023

    // Overflow to +/-inf or underflow to +/-0 bounds for extreme exponents
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



