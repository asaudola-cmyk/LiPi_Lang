// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/codegen_operators.lp
// ==============================================================================

fn x86_synth_compile_expr_mul s toks pos_box
    // WHY: Pratt precedence level 1 for multiplicative operations (*, /, %)
    // Guarantees that multiplication, division, and modulo bind tighter than additive arithmetic.
    x86_synth_expr_primary(s, toks, pos_box)

    cont_mul = 1
    while cont_mul == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_op = 0
        op_kind = k
        if k == TOK_STAR() or k == TOK_SLASH() or k == TOK_PERCENT()
            is_op = 1
        elif k == TOK_IDENT()
            if txt == "*"
                op_kind = TOK_STAR()
                is_op = 1
            elif txt == "/"
                op_kind = TOK_SLASH()
                is_op = 1
            elif txt == "%"
                op_kind = TOK_PERCENT()
                is_op = 1

        if is_op == 0
            cont_mul = 0
        else
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

            if op_kind == TOK_STAR()
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
    return 0

fn x86_synth_compile_expr_add s toks pos_box
    // WHY: Pratt precedence level 2 for additive operations (+, -)
    // Evaluates multiplicative operands first, then combines via dynamic addition or native subtraction.
    x86_synth_compile_expr_mul(s, toks, pos_box)

    cont_add = 1
    while cont_add == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_op = 0
        op_kind = k
        if k == TOK_PLUS() or k == TOK_MINUS()
            is_op = 1
        elif k == TOK_IDENT()
            if txt == "+"
                op_kind = TOK_PLUS()
                is_op = 1
            elif txt == "-"
                op_kind = TOK_MINUS()
                is_op = 1

        if is_op == 0
            cont_add = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) to stack
            x86_synth_emit_byte(s, 80) // push rax

            // Evaluate right operand with multiplicative precedence into %rax
            x86_synth_compile_expr_mul(s, toks, pos_box)

            // Move right operand to %rcx, restore left operand to %rax
            x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 193)
            x86_synth_emit_byte(s, 88)  // pop rax

            if op_kind == TOK_PLUS()
                // rdi = rax (left), rsi = rcx (right) -> call _lipi_add_dynamic
                x86_synth_emit_byte(s, 72) // mov rdi, rax
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 199)
                x86_synth_emit_byte(s, 72) // mov rsi, rcx
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 206)
                x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
            elif op_kind == TOK_MINUS()
                // sub rax, rcx (0x48 0x29 0xC8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 41)
                x86_synth_emit_byte(s, 200)
    return 0

fn x86_synth_compile_expr_shift s toks pos_box
    // WHY: Pratt precedence level 3 for bitwise shift operations (<<, >>)
    x86_synth_compile_expr_add(s, toks, pos_box)

    cont_shift = 1
    while cont_shift == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_op = 0
        op_kind = k
        if k == TOK_SHL() or k == TOK_SHR()
            is_op = 1
        elif k == TOK_IDENT()
            if txt == "<<"
                op_kind = TOK_SHL()
                is_op = 1
            elif txt == ">>"
                op_kind = TOK_SHR()
                is_op = 1

        if is_op == 0
            cont_shift = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) to stack
            x86_synth_emit_byte(s, 80) // push rax

            // Evaluate right operand with additive precedence into %rax
            x86_synth_compile_expr_add(s, toks, pos_box)

            // Move right operand to %rcx, restore left operand to %rax
            x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 193)
            x86_synth_emit_byte(s, 88)  // pop rax

            if op_kind == TOK_SHL()
                // shl rax, cl (0x48 0xD3 0xE0)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 211)
                x86_synth_emit_byte(s, 224)
            elif op_kind == TOK_SHR()
                // sar rax, cl (0x48 0xD3 0xF8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 211)
                x86_synth_emit_byte(s, 248)
    return 0

fn x86_synth_compile_expr_rel s toks pos_box
    // WHY: Pratt precedence level 4 for relational comparisons (<, <=, >, >=)
    // Ensures relational operators bind looser than arithmetic (e.g. `i < len - 2` parses as `i < (len - 2)`).
    x86_synth_compile_expr_shift(s, toks, pos_box)

    cont_rel = 1
    while cont_rel == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_op = 0
        op_kind = k
        if k == TOK_LT() or k == TOK_LTE() or k == TOK_GT() or k == TOK_GTE()
            is_op = 1
        elif k == TOK_IDENT()
            if txt == "<"
                op_kind = TOK_LT()
                is_op = 1
            elif txt == "<="
                op_kind = TOK_LTE()
                is_op = 1
            elif txt == ">"
                op_kind = TOK_GT()
                is_op = 1
            elif txt == ">="
                op_kind = TOK_GTE()
                is_op = 1

        if is_op == 0
            cont_rel = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) to stack
            x86_synth_emit_byte(s, 80) // push rax

            // Evaluate right operand with shift precedence into %rax
            x86_synth_compile_expr_shift(s, toks, pos_box)

            // Move right operand to %rcx, restore left operand to %rax
            x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 193)
            x86_synth_emit_byte(s, 88)  // pop rax

            if op_kind == TOK_LT()
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

fn x86_synth_compile_expr_eq s toks pos_box
    // WHY: Pratt precedence level 5 for equality comparisons (==, !=)
    x86_synth_compile_expr_rel(s, toks, pos_box)

    cont_eq = 1
    while cont_eq == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_op = 0
        op_kind = k
        if k == TOK_EQ() or k == TOK_NEQ()
            is_op = 1
        elif k == TOK_IDENT()
            if txt == "=="
                op_kind = TOK_EQ()
                is_op = 1
            elif txt == "!="
                op_kind = TOK_NEQ()
                is_op = 1

        if is_op == 0
            cont_eq = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) to stack
            x86_synth_emit_byte(s, 80) // push rax

            // Evaluate right operand with relational precedence into %rax
            x86_synth_compile_expr_rel(s, toks, pos_box)

            // Move right operand to %rcx, restore left operand to %rax
            x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 193)
            x86_synth_emit_byte(s, 88)  // pop rax

            if op_kind == TOK_EQ()
                // rdi = rax (left), rsi = rcx (right) -> call _lipi_cmp_dynamic
                x86_synth_emit_byte(s, 72) // mov rdi, rax
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 199)
                x86_synth_emit_byte(s, 72) // mov rsi, rcx
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 206)
                x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
                // test eax, eax; sete al; movzx rax, al
                x86_synth_emit_byte(s, 133)
                x86_synth_emit_byte(s, 192)
                x86_synth_emit_byte(s, 15)
                x86_synth_emit_byte(s, 148)
                x86_synth_emit_byte(s, 192)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 15)
                x86_synth_emit_byte(s, 182)
                x86_synth_emit_byte(s, 192)
            elif op_kind == TOK_NEQ()
                // rdi = rax (left), rsi = rcx (right) -> call _lipi_cmp_dynamic
                x86_synth_emit_byte(s, 72) // mov rdi, rax
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 199)
                x86_synth_emit_byte(s, 72) // mov rsi, rcx
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 206)
                x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
                // test eax, eax; setne al; movzx rax, al
                x86_synth_emit_byte(s, 133)
                x86_synth_emit_byte(s, 192)
                x86_synth_emit_byte(s, 15)
                x86_synth_emit_byte(s, 149)
                x86_synth_emit_byte(s, 192)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 15)
                x86_synth_emit_byte(s, 182)
                x86_synth_emit_byte(s, 192)
    return 0

fn x86_synth_compile_expr_bitwise s toks pos_box
    // WHY: Pratt precedence level 6 for bitwise binary operators (&, ^, |)
    x86_synth_compile_expr_eq(s, toks, pos_box)

    cont_bit = 1
    while cont_bit == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_op = 0
        op_kind = k
        if k == TOK_AMP() or k == TOK_BAR() or k == TOK_CARET()
            is_op = 1
        elif k == TOK_IDENT()
            if txt == "&"
                op_kind = TOK_AMP()
                is_op = 1
            elif txt == "|"
                op_kind = TOK_BAR()
                is_op = 1
            elif txt == "^"
                op_kind = TOK_CARET()
                is_op = 1

        if is_op == 0
            cont_bit = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) to stack
            x86_synth_emit_byte(s, 80) // push rax

            // Evaluate right operand with equality precedence into %rax
            x86_synth_compile_expr_eq(s, toks, pos_box)

            // Move right operand to %rcx, restore left operand to %rax
            x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 193)
            x86_synth_emit_byte(s, 88)  // pop rax

            if op_kind == TOK_AMP()
                // and rax, rcx (0x48 0x21 0xC8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 33)
                x86_synth_emit_byte(s, 200)
            elif op_kind == TOK_BAR()
                // or rax, rcx (0x48 0x09 0xC8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 9)
                x86_synth_emit_byte(s, 200)
            elif op_kind == TOK_CARET()
                // xor rax, rcx (0x48 0x31 0xC8)
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 49)
                x86_synth_emit_byte(s, 200)
    return 0

fn x86_synth_compile_expr_and s toks pos_box
    // WHY: Pratt precedence level 7 for logical AND (and, এবং, &&) with short-circuiting.
    // If LHS is 0, execution branches directly to fail target without evaluating RHS.
    x86_synth_compile_expr_bitwise(s, toks, pos_box)

    fail_patches = list()
    cont_and = 1
    while cont_and == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_and = 0
        if k == TOK_AND()
            is_and = 1
        elif k == TOK_IDENT() and (txt == "and" or txt == "এবং" or txt == "&&")
            is_and = 1

        if is_and == 0
            cont_and = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume 'and'

            // Short-circuit: test rax, rax; jz fail_target (0x0F 0x84 rel32)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 133)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 132)
            p = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(fail_patches, p)

            x86_synth_compile_expr_bitwise(s, toks, pos_box)

    if fail_patches.len() > 0
        // Normalize trailing RHS operand to boolean (1 if non-zero, 0 if zero)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 133)
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 149) // setne al
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 182) // movzx rax, al
        x86_synth_emit_byte(s, 192)

        // jmp done (0xE9 rel32)
        x86_synth_emit_byte(s, 233)
        jmp_done = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        // fail_target: (patch all jz branches here)
        fail_target = s.synth_code.len()
        fi = 0
        while fi < fail_patches.len()
            fp = fail_patches[fi]
            rel32 = fail_target - (fp + 4)
            x86_synth_patch_u32(s, fp, rel32)
            fi = fi + 1

        // xor eax, eax (set %rax to 0 on short-circuit fail)
        x86_synth_emit_byte(s, 49)
        x86_synth_emit_byte(s, 192)

        // done_target: (patch completion jump here)
        done_target = s.synth_code.len()
        rel_done = done_target - (jmp_done + 4)
        x86_synth_patch_u32(s, jmp_done, rel_done)

    return 0

fn x86_synth_compile_expr s toks pos_box
    // WHY: Pratt precedence level for logical OR (or, বা, অথবা, ||) with short-circuiting.
    // If LHS is non-zero, execution branches directly to success target without evaluating RHS.
    x86_synth_compile_expr_and(s, toks, pos_box)

    sc_patches = list()
    cont_or = 1
    while cont_or == 1 and get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text

        is_or = 0
        if k == TOK_OR()
            is_or = 1
        elif k == TOK_IDENT() and (txt == "or" or txt == "বা" or txt == "অথবা" or txt == "||")
            is_or = 1

        if is_or == 0
            cont_or = 0
        else
            list_set(pos_box, 0, pos + 1) // Consume 'or'

            // Short-circuit: test rax, rax; jnz sc_target (0x0F 0x85 rel32)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 133)
            x86_synth_emit_byte(s, 192)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 133)
            p = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(sc_patches, p)

            x86_synth_compile_expr_and(s, toks, pos_box)

    if sc_patches.len() > 0
        // Normalize trailing RHS operand to boolean (1 if non-zero, 0 if zero)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 133)
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 149) // setne al
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 182) // movzx rax, al
        x86_synth_emit_byte(s, 192)

        // jmp done (0xE9 rel32)
        x86_synth_emit_byte(s, 233)
        jmp_done = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        // sc_target: (patch all jnz branches here)
        sc_target = s.synth_code.len()
        si = 0
        while si < sc_patches.len()
            sp = sc_patches[si]
            rel32 = sc_target - (sp + 4)
            x86_synth_patch_u32(s, sp, rel32)
            si = si + 1

        // mov rax, 1 (0x48 0xC7 0xC0 0x01 0x00 0x00 0x00: set %rax to 1 on short-circuit match)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 199)
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_u32(s, 1)

        // done_target: (patch completion jump here)
        done_target = s.synth_code.len()
        rel_done = done_target - (jmp_done + 4)
        x86_synth_patch_u32(s, jmp_done, rel_done)

    return 0

