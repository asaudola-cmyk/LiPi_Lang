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

import "universe/core/collections"
import "universe/core/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"

// ── 1. Data Models ────────────────────────────────────────────────────────────

// WHY: Records an absolute 64-bit virtual memory relocation for string constants
struct X86StringReloc
    sr_patch_offset     // Byte index in code_bytes where the 8-byte pointer is written
    sr_rodata_offset    // Byte index in rodata_bytes where the string payload starts

// WHY: Maps a local variable identifier to an RBP-relative negative stack offset
struct X86LocalVar
    lv_name             // Variable name string
    lv_offset           // Positive offset in bytes: accessed as [rbp - lv_offset]
    lv_type             // Inferred struct type name string ("" if untyped)
    lv_prim_type        // Inferred primitive silicon type: "int", "str", or "" if dynamic

// WHY: Records a function definition entry point for call site resolution
struct X86Function
    fn_name             // Function identifier
    fn_entry_offset     // Byte offset in code_bytes where the function prologue starts

// WHY: Records an unresolved 32-bit relative call displacement
struct X86CallReloc
    cr_patch_offset     // Byte index in code_bytes where 4-byte displacement is written
    cr_call_site_end    // Next instruction IP (cr_patch_offset + 4)
    cr_target_name      // Target function identifier or "__print_int"

// WHY: Models struct schema definitions and field member offsets
struct X86StructDef
    sd_name             // Struct type name string
    sd_fields           // List of field name strings

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
    synth_structs       // List of X86StructDef structs
    synth_global_fields // List of global field name strings
    synth_needs_alloc   // Flag: 1 if bump allocator helper must be emitted
    synth_alloc_off     // Byte offset where bump allocator starts
    synth_is_str_off    // Byte offset where _lipi_is_str helper starts
    synth_called_top_level_main // Flag: 1 if main() or মূল() was called in top-level code
    synth_global_names  // List of top-level global / constant identifier names
    synth_global_vals   // List of top-level integer constant values
    synth_last_struct   // Struct type name of most recent constructor or record literal
    synth_last_expr_type // Type of most recent expression ("int", "str", or "")

// ── 2. Constructor & Emitter Primitives ───────────────────────────────────────

fn x86_synth_new
    // WHY: Allocates and initializes clean synthesizer state.
    s = X86Synthesizer()
    s.synth_code = list()
    s.synth_rodata = list()
    s.synth_str_relocs = list()
    s.synth_call_relocs = list()
    s.synth_locals = list()
    s.synth_functions = list()
    s.synth_stack_offset = 8
    s.synth_needs_print_int = 0
    s.synth_print_int_off = 0
    s.synth_loop_starts = list()
    s.synth_loop_breaks = list()
    s.synth_structs = list()
    s.synth_global_fields = list()
    s.synth_needs_alloc = 0
    s.synth_alloc_off = 0
    s.synth_is_str_off = 0
    s.synth_called_top_level_main = 0
    s.synth_global_names = list()
    s.synth_global_vals = list()
    s.synth_last_struct = ""
    s.synth_last_expr_type = ""
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

include "src/compiler/backend/targets/x86_64/runtime_helpers.lp"
include "src/compiler/backend/targets/x86_64/runtime_io.lp"
include "src/compiler/backend/targets/x86_64/avx2_encoder.lp"
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
    // WHY: Sets up standard 16-byte aligned AMD64 stack frame:
    //      push rbp          (0x55)
    //      mov rbp, rsp      (0x48 0x89 0xE5)
    //      sub rsp, 4096     (0x48 0x81 0xEC 0x00 0x10 0x00 0x00) -> 4KB stack frame per activation
    x86_synth_emit_byte(s, 85)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 137)
    x86_synth_emit_byte(s, 229)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 129)
    x86_synth_emit_byte(s, 236)
    x86_synth_emit_u32(s, 4096)
    return 0

fn x86_synth_emit_epilogue s
    // WHY: Restores stack pointer and caller frame:
    //      mov rsp, rbp      (0x48 0x89 0xEC)
    //      pop rbp           (0x5D)
    //      ret               (0xC3)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 137)
    x86_synth_emit_byte(s, 236)
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
    // Preserves both _heap_base (offset 78) and _heap_ptr (offset 86) so runtime helpers
    // like _lipi_is_str can verify pointer validity with 100% mathematical precision.
    // Inputs: %rdi = requested byte size. Output: %rax = pointer to allocated memory.
    s.synth_alloc_off = s.synth_code.len()
    alloc_bytes = [
        72, 131, 199, 15,                     // add rdi, 15 (align up to 16 bytes)
        72, 131, 231, 240,                    // and rdi, -16
        72, 141, 21, 63, 0, 0, 0,             // lea rdx, [rip + 63] (points to _heap_base at index 78)
        72, 139, 2,                           // mov rax, [rdx]
        72, 133, 192,                         // test rax, rax
        117, 46,                              // jnz .allocated (+46 bytes to index 69)
        87,                                   // push rdi
        82,                                   // push rdx
        49, 255,                              // xor edi, edi (addr = 0)
        190, 0, 0, 0, 64,                     // mov esi, 1073741824 (1GB virtual memory arena)
        186, 3, 0, 0, 0,                      // mov edx, 3 (PROT_READ | PROT_WRITE)
        65, 186, 34, 0, 0, 0,                 // mov r10d, 34 (MAP_PRIVATE | MAP_ANON)
        73, 199, 192, 255, 255, 255, 255,     // mov r8, -1
        69, 49, 201,                          // xor r9d, r9d
        184, 9, 0, 0, 0,                      // mov eax, 9 (sys_mmap)
        15, 5,                                // syscall
        90,                                   // pop rdx
        95,                                   // pop rdi
        72, 137, 2,                           // mov [rdx], rax (save arena base to _heap_base)
        72, 137, 66, 8,                       // mov [rdx + 8], rax (initialize _heap_ptr)
        72, 139, 66, 8,                       // .allocated: mov rax, [rdx + 8]
        72, 1, 122, 8,                        // add [rdx + 8], rdi (bump pointer)
        195,                                  // ret
        0, 0, 0, 0, 0, 0, 0, 0,               // _heap_base: 8 bytes zero-initialized storage (index 78)
        0, 0, 0, 0, 0, 0, 0, 0                // _heap_ptr: 8 bytes zero-initialized storage (index 86)
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
    // WHY: Matches a set of field names against all declared struct schemas to deduce the exact struct type
    if keys.len() == 0
        return ""
    best_name = ""
    best_match_count = 0
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
        if match_count == keys.len() and match_count > best_match_count
            best_match_count = match_count
            best_name = sd.sd_name
        i = i + 1
    return best_name

fn x86_synth_get_field_offset s sname fname
    // WHY: Determines the 8-byte aligned memory offset for struct field access.
    if sname != ""
        i = 0
        while i < s.synth_structs.len()
            sd = s.synth_structs[i]
            if sd.sd_name == sname
                fi = 0
                while fi < sd.sd_fields.len()
                    if sd.sd_fields[fi] == fname
                        return fi * 8
                    fi = fi + 1
            i = i + 1

    // Fallback: search across all registered struct schemas
    i = 0
    while i < s.synth_structs.len()
        sd = s.synth_structs[i]
        fi = 0
        while fi < sd.sd_fields.len()
            if sd.sd_fields[fi] == fname
                return fi * 8
            fi = fi + 1
        i = i + 1

    // Fallback: search or allocate in global fields
    fi = 0
    while fi < s.synth_global_fields.len()
        if s.synth_global_fields[fi] == fname
            return fi * 8
        fi = fi + 1
    push(s.synth_global_fields, fname)
    return (s.synth_global_fields.len() - 1) * 8

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

fn x86_synth_alloc_var s name
    // WHY: Allocates next 8-byte stack slot for variable name or returns existing offset.
    existing = x86_synth_lookup_var(s, name)
    if existing > 0
        return existing
    off = s.synth_stack_offset
    s.synth_stack_offset = s.synth_stack_offset + 8
    lv = X86LocalVar()
    lv.lv_name = name
    lv.lv_offset = off
    lv.lv_type = ""
    lv.lv_prim_type = ""
    push(s.synth_locals, lv)
    return off

fn x86_synth_emit_load_var s reg_id off
    // WHY: Emits machine code to load a 64-bit local variable from [rbp - off] into specified register.
    // Seamlessly handles arbitrary stack frame sizes via ModR/M disp8 (off <= 128) or disp32 (off > 128).
    // Register mapping: 0=%rax, 1=%rcx, 2=%rdx, 6=%rsi, 7=%rdi
    if off <= 128
        disp8 = (256 - (off % 256)) % 256
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 139)
        modrm = 64 + (reg_id * 8) + 5
        x86_synth_emit_byte(s, modrm)
        x86_synth_emit_byte(s, disp8)
    else
        disp32 = 0 - off
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 139)
        modrm = 128 + (reg_id * 8) + 5
        x86_synth_emit_byte(s, modrm)
        x86_synth_emit_u32(s, disp32)
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

fn x86_synth_bind_var s var_name
    // WHY: Binds expression result in %rax to local variable and records struct type if known
    off = x86_synth_alloc_var(s, var_name)
    x86_synth_emit_store_var(s, 0, off)
    if s.synth_last_struct != ""
        x86_synth_set_var_type(s, var_name, s.synth_last_struct)
        s.synth_last_struct = ""
    return off

// ── 6. Global Constant Registry ───────────────────────────────────────────────

fn x86_synth_set_global_const s name val
    // WHY: Registers a top-level constant or global identifier binding so nested functions can resolve it in O(1)
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
    // WHY: Fast linear scan for registered top-level compile-time integer constants
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
        if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_STRUCT() or cur_k == TOK_DIR_STRUCT()
            break
        if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "struct" or cur_txt == "গঠন")
            break
        if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
            break

        if cur_k == TOK_IDENT()
            push(fields, cur_txt)
            list_set(pos_box, 0, cur_p + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            np = get(pos_box, 0)
            if np < toks.len() and (toks[np].tok_kind == TOK_COLON() or (toks[np].tok_kind != TOK_STR() and toks[np].tok_text == ":"))
                list_set(pos_box, 0, np + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_IDENT() or toks[get(pos_box, 0)].tok_text == "string" or toks[get(pos_box, 0)].tok_text == "i64" or toks[get(pos_box, 0)].tok_text == "f64")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
        else
            list_set(pos_box, 0, cur_p + 1)

    sdef = X86StructDef()
    sdef.sd_name = sname
    sdef.sd_fields = fields
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
    return 0


