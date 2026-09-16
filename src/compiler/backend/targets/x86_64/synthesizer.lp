// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the Abstract Syntax Tree / Token Stream directly to executable AMD64
//    silicon instructions, eliminating any dependence on external assemblers (nasm,
//    as, clang, gcc).
// 2. High-Throughput Direct Synthesis: Generates raw opcode bytes in a single pass
//    with deterministic backpatching for branch targets, string addresses, and
//    inter-procedural call sites.
// 3. Implements System V AMD64 ABI: Standard 16-byte stack frame alignment, RBP-based
//    local variable layout, and calling conventions (%rdi, %rsi, %rdx, %rcx, %r8, %r9).
// 4. Built-in Micro-Runtime Helpers: Synthesizes high-performance integer-to-ASCII
//    conversion and Linux SYS_write stdout routines directly into the user binary.
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

// WHY: Records a function definition entry point for call site resolution
struct X86Function
    fn_name             // Function identifier
    fn_entry_offset     // Byte offset in code_bytes where the function prologue starts

// WHY: Records an unresolved 32-bit relative call displacement
struct X86CallReloc
    cr_patch_offset     // Byte index in code_bytes where 4-byte displacement is written
    cr_call_site_end    // Next instruction IP (cr_patch_offset + 4)
    cr_target_name      // Target function identifier or "__print_int"

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

// ── 3. Read-Only Data (.rodata) Management ────────────────────────────────────

fn x86_synth_add_rodata_str s str_text with_newline
    // WHY: Stores UTF-8 string payload into rodata_bytes and returns its starting offset.
    start_off = s.synth_rodata.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.synth_rodata, ord(c))
        i = i + 1
    if with_newline == 1
        push(s.synth_rodata, 10) // '\n'
    push(s.synth_rodata, 0)      // Null terminator for safety
    return start_off

// ── 4. AMD64 Instruction Macro Synthesizers ───────────────────────────────────

fn x86_synth_emit_mov_rax_imm64 s imm_val
    // WHY: Loads 64-bit immediate into %rax (REX.W + 0xB8).
    x86_synth_emit_byte(s, 72)  // 0x48 REX.W
    x86_synth_emit_byte(s, 184) // 0xB8 mov rax, imm64
    x86_synth_emit_u64(s, imm_val)
    return 0

fn x86_synth_emit_prologue s
    // WHY: Standard SysV stack frame allocation:
    //      push rbp          (0x55)
    //      mov rbp, rsp      (0x48 0x89 0xE5)
    //      sub rsp, 128      (0x48 0x81 0xEC 0x80 0x00 0x00 0x00) -> 16-byte aligned
    x86_synth_emit_byte(s, 85)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 137)
    x86_synth_emit_byte(s, 229)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 129)
    x86_synth_emit_byte(s, 236)
    x86_synth_emit_u32(s, 128)
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
    push(s.synth_locals, lv)
    return off

// ── 6. Recursive-Descent Expression Synthesizer ────────────────────────────────

fn x86_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, identifiers, grouping).
    // Result is always computed into %rax.
    pos = get(pos_box, 0)
    if pos >= toks.len()
        x86_synth_emit_byte(s, 49)  // xor eax, eax
        x86_synth_emit_byte(s, 192)
        return 0

    t = toks[pos]
    k = t.tok_kind

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_mov_rax_imm64(s, t.tok_int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = x86_synth_add_rodata_str(s, t.tok_text, 0)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 184) // mov rax, imm64
        patch_pos = s.synth_code.len()
        x86_synth_emit_u64(s, 0)
        rel = X86StringReloc()
        rel.sr_patch_offset = patch_pos
        rel.sr_rodata_offset = ro_off
        push(s.synth_str_relocs, rel)
        return 0

    // 3. Identifier (Variable lookup or Function Call)
    if k == TOK_IDENT()
        list_set(pos_box, 0, pos + 1)
        var_name = t.tok_text
        next_pos = get(pos_box, 0)

        // Function call: name(...)
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_LPAREN()
            list_set(pos_box, 0, next_pos + 1) // Consume '('
            // Parse arguments into caller registers (%rdi, %rsi, %rdx, %rcx, %r8, %r9)
            arg_count = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                x86_synth_compile_expr(s, toks, pos_box)
                x86_synth_emit_byte(s, 80) // push rax (save argument)
                arg_count = arg_count + 1
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_pos + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // Pop arguments in reverse into calling convention registers
            if arg_count >= 6
                x86_synth_emit_byte(s, 65)
                x86_synth_emit_byte(s, 89) // pop r9
            if arg_count >= 5
                x86_synth_emit_byte(s, 65)
                x86_synth_emit_byte(s, 88) // pop r8
            if arg_count >= 4
                x86_synth_emit_byte(s, 89) // pop rcx
            if arg_count >= 3
                x86_synth_emit_byte(s, 90) // pop rdx
            if arg_count >= 2
                x86_synth_emit_byte(s, 94) // pop rsi
            if arg_count >= 1
                x86_synth_emit_byte(s, 95) // pop rdi (0x5F)

            // Emit call rel32
            call_off = s.synth_code.len()
            x86_synth_emit_byte(s, 232)
            patch_pos = s.synth_code.len()
            x86_synth_emit_u32(s, 0)

            call_rel = X86CallReloc()
            call_rel.cr_patch_offset = patch_pos
            call_rel.cr_call_site_end = patch_pos + 4
            call_rel.cr_target_name = var_name
            push(s.synth_call_relocs, call_rel)
            return 0

        // Variable load: mov rax, [rbp - off]
        off = x86_synth_lookup_var(s, var_name)
        if off > 0
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 139)
            x86_synth_emit_byte(s, 69)
            disp8 = (256 - (off % 256)) % 256
            x86_synth_emit_byte(s, disp8)
        else
            // Unbound identifier defaults to 0
            x86_synth_emit_byte(s, 49)
            x86_synth_emit_byte(s, 192)
        return 0

    // 4. Parenthesized expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        x86_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        return 0

    // Fallback: advance and clear %rax
    list_set(pos_box, 0, pos + 1)
    x86_synth_emit_byte(s, 49)
    x86_synth_emit_byte(s, 192)
    return 0

fn x86_synth_compile_expr s toks pos_box
    // WHY: Pratt / Precedence climbing binary expression evaluator.
    // Handles arithmetic (+, -, *, /, %) and comparisons (==, !=, <, <=, >, >=).
    x86_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind

        is_op = 0
        if k == TOK_PLUS() or k == TOK_MINUS() or k == TOK_STAR() or k == TOK_SLASH() or k == TOK_PERCENT()
            is_op = 1
        if k == TOK_EQ() or k == TOK_NEQ() or k == TOK_LT() or k == TOK_LTE() or k == TOK_GT() or k == TOK_GTE()
            is_op = 1

        if is_op == 0
            break

        op_kind = k
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (%rax) to stack
        x86_synth_emit_byte(s, 80) // push rax

        // Evaluate right operand into %rax
        x86_synth_expr_primary(s, toks, pos_box)

        // Move right operand to %rcx, restore left operand to %rax
        x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
        x86_synth_emit_byte(s, 137)
        x86_synth_emit_byte(s, 193)
        x86_synth_emit_byte(s, 88)  // pop rax

        // Synthesize ALU operation
        if op_kind == TOK_PLUS()
            // add rax, rcx (0x48 0x01 0xC8)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 1)
            x86_synth_emit_byte(s, 200)
        elif op_kind == TOK_MINUS()
            // sub rax, rcx (0x48 0x29 0xC8)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 41)
            x86_synth_emit_byte(s, 200)
        elif op_kind == TOK_STAR()
            // imul rax, rcx (0x48 0x0F 0xAF 0xC1)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 175)
            x86_synth_emit_byte(s, 193)
        elif op_kind == TOK_SLASH()
            // cqo; idiv rcx (0x48 0x99, 0x48 0xF7 0xF9)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 153)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 247)
            x86_synth_emit_byte(s, 249)
        elif op_kind == TOK_PERCENT()
            // cqo; idiv rcx; mov rax, rdx (0x48 0x99, 0x48 0xF7 0xF9, 0x48 0x89 0xD0)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 153)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 247)
            x86_synth_emit_byte(s, 249)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 208)
        elif op_kind == TOK_EQ()
            // cmp rax, rcx; sete al; movzx rax, al
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 57)
            x86_synth_emit_byte(s, 200)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 148)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 182)
            x86_synth_emit_byte(s, 192)
        elif op_kind == TOK_NEQ()
            // cmp rax, rcx; setne al; movzx rax, al
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 57)
            x86_synth_emit_byte(s, 200)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 149)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 182)
            x86_synth_emit_byte(s, 192)
        elif op_kind == TOK_LT()
            // cmp rax, rcx; setl al; movzx rax, al
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 57)
            x86_synth_emit_byte(s, 200)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 156)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 182)
            x86_synth_emit_byte(s, 192)
        elif op_kind == TOK_LTE()
            // cmp rax, rcx; setle al; movzx rax, al
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 57)
            x86_synth_emit_byte(s, 200)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 158)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 182)
            x86_synth_emit_byte(s, 192)
        elif op_kind == TOK_GT()
            // cmp rax, rcx; setg al; movzx rax, al
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 57)
            x86_synth_emit_byte(s, 200)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 159)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 182)
            x86_synth_emit_byte(s, 192)
        elif op_kind == TOK_GTE()
            // cmp rax, rcx; setge al; movzx rax, al
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 57)
            x86_synth_emit_byte(s, 200)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 157)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 182)
            x86_synth_emit_byte(s, 192)

    return 0

// ── 7. Statement Synthesizer ──────────────────────────────────────────────────

fn x86_synth_compile_statement s toks pos_box
    // WHY: Synthesizes execution bytes for statements (say, print, return, assignments, fn).
    pos = get(pos_box, 0)
    if pos >= toks.len()
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // Skip redundant newlines and semicolons
    if k == TOK_NEWLINE() or k == TOK_SEMI()
        list_set(pos_box, 0, pos + 1)
        return 0

    // ── 1. Output Statement: say / বলো / print / println / show / দেখাও ──────────
    is_print = 0
    if k == TOK_KW_PRINT()
        is_print = 1
    if k == TOK_IDENT() and (txt == "say" or txt == "বলো" or txt == "print" or txt == "println" or txt == "show" or txt == "দেখাও")
        is_print = 1

    if is_print == 1
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        if next_pos < toks.len()
            next_tok = toks[next_pos]
            // Direct string constant print optimization:
            after_next = next_pos + 1
            is_simple_str = 0
            if next_tok.tok_kind == TOK_STR()
                if after_next >= toks.len() or toks[after_next].tok_kind == TOK_NEWLINE() or toks[after_next].tok_kind == TOK_SEMI() or toks[after_next].tok_kind == TOK_EOF()
                    is_simple_str = 1

            if is_simple_str == 1
                list_set(pos_box, 0, next_pos + 1)
                x86_synth_emit_print_string(s, next_tok.tok_text)
                return 0

        // General expression print (numbers, variables, calculations):
        x86_synth_compile_expr(s, toks, pos_box)
        x86_synth_emit_call_print_int(s)
        return 0

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF()
                has_expr = 1

        if has_expr == 1
            x86_synth_compile_expr(s, toks, pos_box)
        else
            // Default 0 return
            x86_synth_emit_byte(s, 49)
            x86_synth_emit_byte(s, 192)

        x86_synth_emit_epilogue(s)
        return 0

    // ── 3. Variable Declaration: let / চলক / ধরি / var ─────────────────────────
    is_let = 0
    if k == TOK_KW_LET()
        is_let = 1
    if k == TOK_IDENT() and (txt == "let" or txt == "চলক" or txt == "ধরি" or txt == "var")
        is_let = 1

    if is_let == 1
        list_set(pos_box, 0, pos + 1) // Consume let
        var_pos = get(pos_box, 0)
        if var_pos < toks.len() and toks[var_pos].tok_kind == TOK_IDENT()
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)
            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and toks[eq_pos].tok_kind == TOK_ASSIGN()
                list_set(pos_box, 0, eq_pos + 1)
                x86_synth_compile_expr(s, toks, pos_box)
                off = x86_synth_alloc_var(s, var_name)
                // mov [rbp - off], rax (0x48 0x89 0x45 disp8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 69)
                disp8 = (256 - (off % 256)) % 256
                x86_synth_emit_byte(s, disp8)
        return 0

    // ── 4. Assignment: <var> = <expr> ──────────────────────────────────────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
            x86_synth_compile_expr(s, toks, pos_box)
            off = x86_synth_alloc_var(s, var_name)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 69)
            disp8 = (256 - (off % 256)) % 256
            x86_synth_emit_byte(s, disp8)
            return 0

    // ── 5. Function Definition: fn / কাজ / @fn ─────────────────────────────────
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN()
        is_fn = 1
    if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn")
        is_fn = 1

    if is_fn == 1
        list_set(pos_box, 0, pos + 1) // Consume fn
        name_pos = get(pos_box, 0)
        fn_name = ""
        if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
            fn_name = toks[name_pos].tok_text
            list_set(pos_box, 0, name_pos + 1)

        // Emit jump over function so top-level execution doesn't fall through into it!
        x86_synth_emit_byte(s, 233) // jmp rel32 (0xE9)
        fn_jmp_patch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        // Record function entry point (immediately after the skip jump)
        fn_entry = X86Function()
        fn_entry.fn_name = fn_name
        fn_entry.fn_entry_offset = s.synth_code.len()
        push(s.synth_functions, fn_entry)

        // Reset frame locals
        s.synth_locals = list()
        s.synth_stack_offset = 8

        // Parse parameter names until newline
        params = list()
        while get(pos_box, 0) < toks.len()
            p_tok = toks[get(pos_box, 0)]
            if p_tok.tok_kind == TOK_NEWLINE() or p_tok.tok_kind == TOK_SEMI()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                break
            if p_tok.tok_kind == TOK_IDENT()
                push(params, p_tok.tok_text)
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Emit function prologue
        x86_synth_emit_prologue(s)

        // Save incoming argument registers to local stack slots
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = x86_synth_alloc_var(s, pname)
            disp8 = (256 - (off % 256)) % 256
            if pi == 0
                // mov [rbp - off], rdi (0x48 0x89 0x7D disp8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 125)
                x86_synth_emit_byte(s, disp8)
            elif pi == 1
                // mov [rbp - off], rsi (0x48 0x89 0x75 disp8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 117)
                x86_synth_emit_byte(s, disp8)
            elif pi == 2
                // mov [rbp - off], rdx (0x48 0x89 0x55 disp8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 85)
                x86_synth_emit_byte(s, disp8)
            elif pi == 3
                // mov [rbp - off], rcx (0x48 0x89 0x4D disp8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 77)
                x86_synth_emit_byte(s, disp8)
            elif pi == 4
                // mov [rbp - off], r8 (0x4C 0x89 0x45 disp8)
                x86_synth_emit_byte(s, 76)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 69)
                x86_synth_emit_byte(s, disp8)
            elif pi == 5
                // mov [rbp - off], r9 (0x4C 0x89 0x4D disp8)
                x86_synth_emit_byte(s, 76)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 77)
                x86_synth_emit_byte(s, disp8)
            pi = pi + 1

        // Parse function body statements until next function or EOF
        while get(pos_box, 0) < toks.len()
            cur_pos = get(pos_box, 0)
            ct = toks[cur_pos]
            if ct.tok_kind == TOK_KW_FN() or ct.tok_kind == TOK_DIR_FN()
                break
            if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "fn" or ct.tok_text == "কাজ" or ct.tok_text == "@fn")
                break
            x86_synth_compile_statement(s, toks, pos_box)

        // Default epilogue at end of function
        x86_synth_emit_byte(s, 49)
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_epilogue(s)

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.synth_code.len()
        rel32 = after_fn_offset - (fn_jmp_patch + 4)
        x86_synth_patch_u32(s, fn_jmp_patch, rel32)
        return 0

    // Default: evaluate expression or advance token
    x86_synth_compile_expr(s, toks, pos_box)
    return 0

// ── 8. Master Program Synthesizer Entry Point ──────────────────────────────────

fn x86_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable AMD64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = x86_synth_new()

    // 1. Emit top-level stack frame prologue at entry point (offset 0)
    x86_synth_emit_prologue(s)

    // 2. Synthesize all functions and statements
    pos_box = [0]
    has_top_level = 0
    while get(pos_box, 0) < tokens.len()
        cur_pos = get(pos_box, 0)
        cur_k = tokens[cur_pos].tok_kind
        if cur_k == TOK_EOF()
            break

        tok_item = tokens[cur_pos]
        is_fn_tok = 0
        if tok_item.tok_kind == TOK_KW_FN() or tok_item.tok_kind == TOK_DIR_FN()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "fn" or tok_item.tok_text == "কাজ" or tok_item.tok_text == "@fn")
            is_fn_tok = 1

        if is_fn_tok == 0 and tok_item.tok_kind != TOK_NEWLINE() and tok_item.tok_kind != TOK_SEMI()
            has_top_level = 1

        x86_synth_compile_statement(s, tokens, pos_box)

    // 3. If there were NO top-level statements, but 'main' exists, call main() automatically!
    has_main = 0
    if has_top_level == 0
        fi = 0
        while fi < s.synth_functions.len()
            if s.synth_functions[fi].fn_name == "main"
                has_main = 1
            fi = fi + 1
        if has_main == 1
            call_off = s.synth_code.len()
            x86_synth_emit_byte(s, 232)
            patch_pos = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            call_rel = X86CallReloc()
            call_rel.cr_patch_offset = patch_pos
            call_rel.cr_call_site_end = patch_pos + 4
            call_rel.cr_target_name = "main"
            push(s.synth_call_relocs, call_rel)

    // 4. Top-level exit epilogue
    if has_top_level == 1 or has_main == 0
        x86_synth_emit_byte(s, 49)  // xor eax, eax (default exit code 0)
        x86_synth_emit_byte(s, 192)
    x86_synth_emit_epilogue(s)

    // 5. Emit print_int helper if required
    if s.synth_needs_print_int == 1
        x86_synth_emit_print_int_helper(s)

    // 6. Resolve Inter-Procedural Call Relocations
    ci = 0
    while ci < s.synth_call_relocs.len()
        cr = s.synth_call_relocs[ci]
        resolved_addr = 0
        if cr.cr_target_name == "__print_int"
            resolved_addr = s.synth_print_int_off
        else
            k = 0
            while k < s.synth_functions.len()
                fn_item = s.synth_functions[k]
                if fn_item.fn_name == cr.cr_target_name
                    resolved_addr = fn_item.fn_entry_offset
                k = k + 1

        rel32 = resolved_addr - cr.cr_call_site_end
        x86_synth_patch_u32(s, cr.cr_patch_offset, rel32)
        ci = ci + 1

    // 7. Resolve 64-Bit Virtual Memory String Relocations
    // Formula per elf_writer.lp:
    // base_vaddr = 4194304 (0x400000)
    // code_file_offset = 176 (64 bytes ElfHeader + 112 bytes ProgramHeaders)
    // start_stub length = 64 bytes
    // rodata_base_vaddr = 4194304 + 176 + 64 + total_code_size = 4194544 + total_code_size
    total_code_size = s.synth_code.len()
    rodata_base_vaddr = 4194544 + total_code_size

    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        target_vaddr = rodata_base_vaddr + rel.sr_rodata_offset
        x86_synth_patch_u64(s, rel.sr_patch_offset, target_vaddr)
        ri = ri + 1

    return s
