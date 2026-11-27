// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/codegen_operators.lp
// ==============================================================================

fn x86_synth_emit_tagged_binop s left_type right_type op_code
    // WHY: Dispatches any binary operator involving a dynamically tagged dict/container element
    // (%rdx = val_tag: 0=int/ptr, 1=float, 2=str) through _lipi_binop_tagged(lhs, rhs, ltag, rtag, op).
    // Stack on entry: if left_type == "dyn_tagged" -> [rsp]=ltag, [rsp+8]=lhs; else [rsp]=lhs.
    // %rax = rhs, %rdx = rtag (when right_type == "dyn_tagged").
    x86_synth_emit_bytes(s, [72, 137, 198]) // mov rsi, rax (rhs)
    if right_type == "dyn_tagged"
        x86_synth_emit_bytes(s, [72, 137, 209]) // mov rcx, rdx (rtag)
    elif right_type == "float"
        x86_synth_emit_bytes(s, [185, 1, 0, 0, 0]) // mov ecx, 1
    elif right_type == "str"
        x86_synth_emit_bytes(s, [185, 2, 0, 0, 0]) // mov ecx, 2
    else
        x86_synth_emit_bytes(s, [49, 201]) // xor ecx, ecx
    end
    if left_type == "dyn_tagged"
        x86_synth_emit_bytes(s, [90, 95]) // pop rdx (ltag); pop rdi (lhs)
    else
        x86_synth_emit_byte(s, 95) // pop rdi (lhs)
        if left_type == "float"
            x86_synth_emit_bytes(s, [186, 1, 0, 0, 0]) // mov edx, 1
        elif left_type == "str"
            x86_synth_emit_bytes(s, [186, 2, 0, 0, 0]) // mov edx, 2
        else
            x86_synth_emit_bytes(s, [49, 210]) // xor edx, edx
        end
    end
    x86_synth_emit_bytes(s, [65, 184]) // mov r8d, op_code
    x86_synth_emit_u32(s, op_code)
    x86_synth_emit_call_helper(s, "_lipi_binop_tagged")
    if op_code >= 5
        s.synth_last_expr_type = "int"
    elif op_code == 0 and (left_type == "str" or right_type == "str")
        s.synth_last_expr_type = "str"
    elif left_type == "float" or right_type == "float"
        s.synth_last_expr_type = "float"
    else
        s.synth_last_expr_type = "dyn_tagged"
    end
    s.synth_last_struct = ""
    return 0

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
        if k == TOK_STAR() or k == TOK_SLASH() or k == TOK_PERCENT() or k == TOK_MATMUL()
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
            elif txt == "@"
                op_kind = TOK_MATMUL()
                is_op = 1

        if is_op == 0
            cont_mul = 0
        else
            // WHY: Sovereign Silicon Fast Reciprocal & Power-of-2 Modulo/Division Optimizer.
            // Eliminates 25-cycle idiv stall when right-hand side is compile-time integer constant.
            next_p = pos + 1
            is_const_rhs = 0
            const_val = 0
            if next_p < toks.len()
                nt = toks[next_p]
                if nt.tok_kind == TOK_INT()
                    after_next = next_p + 1
                    if after_next >= toks.len() or (toks[after_next].tok_kind != TOK_STAR() and toks[after_next].tok_kind != TOK_SLASH() and toks[after_next].tok_kind != TOK_PERCENT() and toks[after_next].tok_kind != TOK_MATMUL() and toks[after_next].tok_kind != TOK_DOT() and toks[after_next].tok_kind != TOK_LBRACKET())
                        is_const_rhs = 1
                        const_val = nt.tok_int_val

            if is_const_rhs == 1 and op_kind != TOK_MATMUL() and s.synth_last_expr_type != "float" and s.synth_last_expr_type != "dyn_tagged"
                mul_left_t = s.synth_last_expr_type
                list_set(pos_box, 0, next_p + 1) // Consume operator and integer literal

                if op_kind == TOK_PERCENT()
                    if const_val == 0
                        if s.synth_freestanding == 0
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                        else
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 192)
                        end
                    elif mul_left_t == "uint"
                        if const_val > 1 and (const_val & (const_val - 1)) == 0 and const_val <= 1073741824
                            // 1-cycle unsigned power-of-2 modulo: and rax, (const_val - 1)
                            x86_synth_emit_bytes(s, [72, 37])
                            x86_synth_emit_u32(s, const_val - 1)
                        else
                            // Exact unsigned hardware modulo: mov rcx, const_val; xor edx, edx; div rcx; mov rax, rdx
                            x86_synth_emit_bytes(s, [72, 185])
                            x86_synth_emit_u64(s, const_val)
                            x86_synth_emit_bytes(s, [49, 210, 72, 247, 241, 72, 137, 208])
                        end
                    elif const_val == 7
                        // WHY: Exact 64-bit Fast Reciprocal Modulo for 7 (Granlund-Montgomery M = ceil(2^65 / 7) = 0x4924924924924925).
                        // Mathematically exact for all non-negative signed 64-bit integers 0 <= rax < 2^63 via post-mul shr rdx, 1.
                        // If rax < 0, branches to hardware signed idiv fallback.
                        // test rax, rax (3 bytes: 48 85 C0)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192)
                        // js +31 (2 bytes: 78 1F) -> jumps over 29-byte fast path + 2-byte jmp
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 31)
                        // Fast path (29 bytes): rcx = rax; rdx = 0x4924924924924925; mul rdx; shr rdx, 1; imul rdx, 7; sub rcx, rdx; rax = rcx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 193) // mov rcx, rax
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 186) // movabs rdx, 0x4924924924924925 (5270498306774157605)
                        x86_synth_emit_u64(s, 5270498306774157605)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 226) // mul rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 209)
                        x86_synth_emit_byte(s, 234) // shr rdx, 1
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 210)
                        x86_synth_emit_byte(s, 7)   // imul rdx, rdx, 7
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 209) // sub rcx, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 200) // mov rax, rcx
                        // jmp +18 (2 bytes: EB 12) -> jumps over fallback
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)
                        // Fallback: mov rcx, 7; cqo; idiv rcx; mov rax, rdx (18 bytes)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, 7)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    elif const_val == 10
                        // WHY: Exact 64-bit Fast Reciprocal Modulo for 10 (10 = 2 * 5, M = ceil(2^64 / 5) = 0x3333333333333334).
                        // Pre-shifts rax >> 1 so y < 2^62 and 4*y < 2^64, guaranteeing 100% exact quotient for all 0 <= rax < 2^63.
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192) // test rax, rax
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 31)  // js +31
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 193) // mov rcx, rax
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 209)
                        x86_synth_emit_byte(s, 232) // shr rax, 1
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 186) // movabs rdx, 3689348814741910324
                        x86_synth_emit_u64(s, 3689348814741910324)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 226) // mul rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 210)
                        x86_synth_emit_byte(s, 10)  // imul rdx, rdx, 10
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 209) // sub rcx, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 200) // mov rax, rcx
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)  // jmp +18
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, 10)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    elif const_val == 100
                        // WHY: Exact 64-bit Fast Reciprocal Modulo for 100 (100 = 4 * 25, M = ceil(2^66 / 25) = 0x28F5C28F5C28F5C3).
                        // Pre-shifts rax >> 2 and post-shifts rdx >> 2, guaranteeing 100% exact quotient for all 0 <= rax < 2^63.
                        // Eliminates overflow at x >= 219,604,096,115,589,900 while keeping 3-cycle reciprocal latency.
                        // test rax, rax (3 bytes: 48 85 C0)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192)
                        // js +36 (2 bytes: 78 24)
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 36)
                        // Fast path (34 bytes)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 193) // mov rcx, rax
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 193)
                        x86_synth_emit_byte(s, 232)
                        x86_synth_emit_byte(s, 2)   // shr rax, 2
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 186) // movabs rdx, 0x28F5C28F5C28F5C3 (2951479051793528259)
                        x86_synth_emit_u64(s, 2951479051793528259)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 226) // mul rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 193)
                        x86_synth_emit_byte(s, 234)
                        x86_synth_emit_byte(s, 2)   // shr rdx, 2
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 210)
                        x86_synth_emit_byte(s, 100) // imul rdx, rdx, 100
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 209) // sub rcx, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 200) // mov rax, rcx
                        // jmp +18 (2 bytes: EB 12)
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)
                        // Fallback (18 bytes): mov rcx, 100; cqo; idiv rcx; mov rax, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, 100)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    elif const_val == 3
                        // WHY: Exact 64-bit Granlund-Montgomery reciprocal modulo for % 3 (M_3 = ceil(2^64 / 3) = 6148914691236517206)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192)
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 28) // js +28
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 193) // mov rcx, rax
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 186)
                        x86_synth_emit_u64(s, 6148914691236517206)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 226) // mul rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 210)
                        x86_synth_emit_byte(s, 3)   // imul rdx, rdx, 3
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 209) // sub rcx, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 200) // mov rax, rcx
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)  // jmp +18
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, 3)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    elif const_val == 5
                        // WHY: Exact 64-bit Granlund-Montgomery reciprocal modulo for % 5 (M_5 = ceil(2^65 / 5) = 7378697629483820647, shr rdx, 1)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192)
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 32) // js +32
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 193) // mov rcx, rax
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 186)
                        x86_synth_emit_u64(s, 7378697629483820647)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 226) // mul rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 193)
                        x86_synth_emit_byte(s, 234)
                        x86_synth_emit_byte(s, 1)   // shr rdx, 1
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 210)
                        x86_synth_emit_byte(s, 5)   // imul rdx, rdx, 5
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 209) // sub rcx, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 200) // mov rax, rcx
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)  // jmp +18
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, 5)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    elif const_val == 9
                        // WHY: Exact 64-bit Granlund-Montgomery reciprocal modulo for % 9 (M_9 = ceil(2^65 / 9) = 4099276460824344804, shr rdx, 1)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192)
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 32) // js +32
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 193) // mov rcx, rax
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 186)
                        x86_synth_emit_u64(s, 4099276460824344804)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 226) // mul rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 193)
                        x86_synth_emit_byte(s, 234)
                        x86_synth_emit_byte(s, 1)   // shr rdx, 1
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 210)
                        x86_synth_emit_byte(s, 9)   // imul rdx, rdx, 9
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 209) // sub rcx, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 200) // mov rax, rcx
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)  // jmp +18
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, 9)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    elif const_val > 1 and (const_val & (const_val - 1)) == 0 and const_val <= 1073741824
                        // WHY: 1-cycle bitwise mask modulo for all positive powers of 2 up to 2^30 with signed negative idiv fallback.
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 133)
                        x86_synth_emit_byte(s, 192) // test rax, rax
                        x86_synth_emit_byte(s, 120)
                        x86_synth_emit_byte(s, 8)   // js +8
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 37)  // and rax, imm32 (const_val - 1)
                        x86_synth_emit_u32(s, const_val - 1)
                        x86_synth_emit_byte(s, 235)
                        x86_synth_emit_byte(s, 18)  // jmp +18
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, const_val)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    else
                        if const_val == 0
                            // Zero divisor guard: xor eax, eax
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 192)
                        elif const_val == -1
                            // WHY: Signed x % -1 is always 0; avoids hardware #DE SIGFPE on INT64_MIN % -1.
                            x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
                        else
                            // Exact signed hardware modulo: mov rcx, const_val; cqo; idiv rcx; mov rax, rdx
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 185)
                            x86_synth_emit_u64(s, const_val)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 153)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 247)
                            x86_synth_emit_byte(s, 249)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 137)
                            x86_synth_emit_byte(s, 208)
                        end
                elif op_kind == TOK_SLASH()
                    if const_val == 0
                        if s.synth_freestanding == 0
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                        else
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 192)
                        end
                    elif mul_left_t == "uint"
                        // Exact unsigned hardware division: mov rcx, const_val; xor edx, edx; div rcx
                        x86_synth_emit_bytes(s, [72, 185])
                        x86_synth_emit_u64(s, const_val)
                        x86_synth_emit_bytes(s, [49, 210, 72, 247, 241])
                    elif const_val == -1
                        // neg rax (handles both normal signs and INT64_MIN / -1 without #DE)
                        x86_synth_emit_bytes(s, [72, 247, 216])
                    else
                        // Exact signed hardware division: mov rcx, const_val; cqo; idiv rcx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, const_val)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                    end
                elif op_kind == TOK_STAR()
                    if const_val == 2 or const_val == 4 or const_val == 8 or const_val == 16 or const_val == 32 or const_val == 64 or const_val == 128 or const_val == 256
                        k_shift = 1
                        if const_val == 4 k_shift = 2
                        elif const_val == 8 k_shift = 3
                        elif const_val == 16 k_shift = 4
                        elif const_val == 32 k_shift = 5
                        elif const_val == 64 k_shift = 6
                        elif const_val == 128 k_shift = 7
                        elif const_val == 256 k_shift = 8
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 193)
                        x86_synth_emit_byte(s, 224)
                        x86_synth_emit_byte(s, k_shift)
                    elif const_val <= 127 and const_val >= -128
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 107)
                        x86_synth_emit_byte(s, 192)
                        x86_synth_emit_byte(s, const_val % 256)
                    else
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, const_val)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 15)
                        x86_synth_emit_byte(s, 175)
                        x86_synth_emit_byte(s, 193)
                if mul_left_t == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
            else
                left_type = s.synth_last_expr_type
                list_set(pos_box, 0, pos + 1) // Consume operator

                // WHY: Syntax error guard against dangling binary operators (*, /, %, @)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                chk_pos = get(pos_box, 0)
                if chk_pos >= toks.len()
                    say "❌ [Syntax Error]: Dangling binary operator without right-hand operand"
                    exit(1)
                end
                chk_tok = toks[chk_pos]
                chk_k = chk_tok.tok_kind
                chk_x = chk_tok.tok_text
                if chk_k != TOK_STR() and (chk_k == TOK_SEMI() or chk_k == TOK_RBRACE() or chk_k == TOK_RPAREN() or chk_k == TOK_EOF() or chk_x == ";" or chk_x == "}" or chk_x == ")")
                    say "❌ [Syntax Error]: Dangling binary operator followed by '" + chk_x + "' at line " + str(chk_tok.tok_span.span_start_line)
                    exit(1)
                end

                // Push left operand (%rax) (and %rdx val_tag if dyn_tagged) to stack
                x86_synth_emit_byte(s, 80) // push rax
                if left_type == "dyn_tagged"
                    x86_synth_emit_byte(s, 82) // push rdx
                end

                // Evaluate right operand into %rax
                x86_synth_expr_primary(s, toks, pos_box)
                right_type = s.synth_last_expr_type

                if (left_type == "dyn_tagged" or right_type == "dyn_tagged") and op_kind != TOK_MATMUL()
                    tag_op_m = 2
                    if op_kind == TOK_SLASH()
                        tag_op_m = 3
                    elif op_kind == TOK_PERCENT()
                        tag_op_m = 4
                    end
                    x86_synth_emit_tagged_binop(s, left_type, right_type, tag_op_m)
                else
                    // Move right operand to %rcx, restore left operand to %rax
                    x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 193)
                    if left_type == "dyn_tagged"
                        x86_synth_emit_byte(s, 90) // pop rdx (discard tag for matmul)
                    end
                    x86_synth_emit_byte(s, 88)  // pop rax

                    if (left_type == "float" or right_type == "float") and (op_kind == TOK_STAR() or op_kind == TOK_SLASH() or op_kind == TOK_PERCENT())
                        // WHY: SSE2 64-bit Double-Precision Floating Point Multiplication & Division.
                        // Transfers 64-bit IEEE-754 bit patterns from GPRs (%rax, %rcx) to SSE2 registers (%xmm0, %xmm1).
                        // Mixed integer-float arithmetic promotes integers to double precision via cvtsi2sd.
                        if left_type == "float"
                            // movq xmm0, rax (66 48 0F 6E C0)
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 110)
                            x86_synth_emit_byte(s, 192)
                        else
                            // cvtsi2sd xmm0, rax (F2 48 0F 2A C0)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 42)
                            x86_synth_emit_byte(s, 192)
                        end

                        if right_type == "float"
                            // movq xmm1, rcx (66 48 0F 6E C9)
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 110)
                            x86_synth_emit_byte(s, 201)
                        else
                            // cvtsi2sd xmm1, rcx (F2 48 0F 2A C9)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 42)
                            x86_synth_emit_byte(s, 201)
                        end

                        if op_kind == TOK_STAR()
                            // mulsd xmm0, xmm1 (F2 0F 59 C1)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 89)
                            x86_synth_emit_byte(s, 193)
                        elif op_kind == TOK_SLASH()
                            // divsd xmm0, xmm1 (F2 0F 5E C1)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 94)
                            x86_synth_emit_byte(s, 193)
                        elif op_kind == TOK_PERCENT()
                            // WHY: IEEE-754 fmod(a, b) = a - trunc(a / b) * b via roundsd imm8=3
                            // movapd xmm2, xmm0 (66 0F 28 D0)
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 40)
                            x86_synth_emit_byte(s, 208)
                            // divsd xmm0, xmm1 (F2 0F 5E C1)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 94)
                            x86_synth_emit_byte(s, 193)
                            // roundsd xmm0, xmm0, 3 (66 0F 3A 0B C0 03)
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 58)
                            x86_synth_emit_byte(s, 11)
                            x86_synth_emit_byte(s, 192)
                            x86_synth_emit_byte(s, 3)
                            // mulsd xmm0, xmm1 (F2 0F 59 C1)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 89)
                            x86_synth_emit_byte(s, 193)
                            // subsd xmm2, xmm0 (F2 0F 5C D0)
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 92)
                            x86_synth_emit_byte(s, 208)
                            // movapd xmm0, xmm2 (66 0F 28 C2)
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 40)
                            x86_synth_emit_byte(s, 194)
                        end

                        // movq rax, xmm0 (66 48 0F 7E C0)
                        x86_synth_emit_byte(s, 102)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 15)
                        x86_synth_emit_byte(s, 126)
                        x86_synth_emit_byte(s, 192)
                        s.synth_last_expr_type = "float"
                    elif op_kind == TOK_STAR()
                        // imul rax, rcx (0x48 0x0F 0xAF 0xC1)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 15)
                        x86_synth_emit_byte(s, 175)
                        x86_synth_emit_byte(s, 193)
                    elif op_kind == TOK_SLASH()
                        // WHY: Unsigned (`div rcx`) vs Signed (`idiv rcx`) division with DivisionByZero guard.
                        if left_type == "uint" or right_type == "uint"
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [235, 5, 49, 210, 72, 247, 241])
                            else
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 5, 49, 210, 72, 247, 241])
                            end
                        elif s.synth_freestanding == 0
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                            x86_synth_emit_bytes(s, [235, 16, 72, 131, 249, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 72, 247, 249])
                        else
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 16, 72, 131, 249, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 72, 247, 249])
                        end
                    elif op_kind == TOK_PERCENT()
                        // WHY: Unsigned (`div rcx; mov rax, rdx`) vs Signed (`idiv rcx`) modulo with DivisionByZero guard.
                        if left_type == "uint" or right_type == "uint"
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [235, 8, 49, 210, 72, 247, 241, 72, 137, 208])
                            else
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 8, 49, 210, 72, 247, 241, 72, 137, 208])
                            end
                        elif s.synth_freestanding == 0
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                            x86_synth_emit_bytes(s, [235, 18, 72, 131, 249, 255, 117, 4, 49, 192, 235, 8, 72, 153, 72, 247, 249, 72, 137, 208])
                        else
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 18, 72, 131, 249, 255, 117, 4, 49, 192, 235, 8, 72, 153, 72, 247, 249, 72, 137, 208])
                        end
                    elif op_kind == TOK_MATMUL()
                        // WHY: Sovereign Silicon Matrix & Tensor Multiplication (@ Operator)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 199)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 206)
                        x86_synth_emit_call_helper(s, "_lipi_matmul")
                        s.synth_last_expr_type = "int"
                    if left_type != "float" and right_type != "float"
                        if left_type == "uint" or right_type == "uint"
                            s.synth_last_expr_type = "uint"
                        else
                            s.synth_last_expr_type = "int"
                        end
                    end
                end
    return 0

fn x86_synth_compile_expr_add s toks pos_box
    // WHY: Pratt precedence level 2 for additive operations (+, -)
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
            left_type = s.synth_last_expr_type
            left_ptr_t = s.synth_last_struct
            is_left_ptr = x86_synth_is_ptr_type(left_ptr_t)

            // Check if right operand is a small constant integer
            next_p = pos + 1
            is_const_int_rhs = 0
            const_add_val = 0
            if is_left_ptr == 0 and next_p < toks.len()
                nt = toks[next_p]
                if nt.tok_kind == TOK_INT()
                    after_next = next_p + 1
                    if after_next >= toks.len() or (toks[after_next].tok_kind != TOK_STAR() and toks[after_next].tok_kind != TOK_SLASH() and toks[after_next].tok_kind != TOK_PERCENT() and toks[after_next].tok_kind != TOK_MATMUL() and toks[after_next].tok_kind != TOK_PLUS() and toks[after_next].tok_kind != TOK_MINUS() and toks[after_next].tok_kind != TOK_DOT() and toks[after_next].tok_kind != TOK_LBRACKET())
                        is_const_int_rhs = 1
                        const_add_val = nt.tok_int_val

            is_local_int_fast = 0
            lv_add_rhs = 0
            if is_left_ptr == 0 and is_const_int_rhs == 0 and x86_synth_is_int_like(left_type) == 1 and next_p < toks.len()
                nt_id = toks[next_p]
                if nt_id.tok_kind == TOK_IDENT()
                    af_id = next_p + 1
                    af_ok = 0
                    if af_id >= toks.len()
                        af_ok = 1
                    else
                        ak = toks[af_id].tok_kind
                        atx = toks[af_id].tok_text
                        if ak != TOK_STAR() and ak != TOK_SLASH() and ak != TOK_PERCENT() and ak != TOK_MATMUL() and ak != TOK_DOT() and ak != TOK_LBRACKET() and ak != TOK_LPAREN() and atx != "*" and atx != "/" and atx != "%" and atx != "@" and atx != "." and atx != "[" and atx != "("
                            af_ok = 1
                        end
                    end
                    if af_ok == 1
                        lv_add_rhs = x86_synth_find_local_var(s, nt_id.tok_text)
                        if lv_add_rhs != 0 and x86_synth_is_int_like(lv_add_rhs.lv_prim_type) == 1
                            is_local_int_fast = 1
                        end
                    end
                end
            end

            if is_const_int_rhs == 1 and (op_kind == TOK_MINUS() or x86_synth_is_int_like(left_type) == 1) and left_type != "float" and left_type != "dyn_tagged"
                // WHY: 1-cycle direct silicon arithmetic for constant additions/subtractions (e.g. i + 1, i - 1)
                // Zero function calls, zero stack traffic, zero heap allocations.
                list_set(pos_box, 0, next_p + 1)
                if op_kind == TOK_PLUS()
                    if const_add_val == 1
                        // inc rax (0x48 0xFF 0xC0)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 255)
                        x86_synth_emit_byte(s, 192)
                    elif const_add_val <= 127 and const_add_val >= -128
                        // add rax, imm8 (0x48 0x83 0xC0 imm8)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 131)
                        x86_synth_emit_byte(s, 192)
                        x86_synth_emit_byte(s, const_add_val % 256)
                    elif const_add_val <= 2147483647
                        // add rax, imm32 (0x48 0x05 imm32)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 5)
                        x86_synth_emit_u32(s, const_add_val)
                    else
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, const_add_val)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 1)
                        x86_synth_emit_byte(s, 200)
                else
                    // TOK_MINUS
                    if const_add_val == 1
                        // dec rax (0x48 0xFF 0xC8)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 255)
                        x86_synth_emit_byte(s, 200)
                    elif const_add_val <= 127 and const_add_val >= -128
                        // sub rax, imm8 (0x48 0x83 0xE8 imm8)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 131)
                        x86_synth_emit_byte(s, 232)
                        x86_synth_emit_byte(s, const_add_val % 256)
                    else
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 185)
                        x86_synth_emit_u64(s, const_add_val)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 200)
                if left_type == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
            elif is_local_int_fast == 1
                // WHY: Direct register/frame load to %rcx followed by 1-cycle add/sub without stack push/pop
                list_set(pos_box, 0, next_p + 1)
                if lv_add_rhs.lv_is_spilled == 0 and lv_add_rhs.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 1, lv_add_rhs.lv_reg)
                else
                    x86_synth_emit_load_var(s, 1, lv_add_rhs.lv_offset)
                end
                if op_kind == TOK_PLUS()
                    x86_synth_emit_bytes(s, [72, 1, 200]) // add rax, rcx
                else
                    x86_synth_emit_bytes(s, [72, 41, 200]) // sub rax, rcx
                end
                if left_type == "uint" or lv_add_rhs.lv_prim_type == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
            else
                list_set(pos_box, 0, pos + 1) // Consume operator

                // WHY: Syntax error guard against dangling binary operators (+, -)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                chk_pos = get(pos_box, 0)
                if chk_pos >= toks.len()
                    say "❌ [Syntax Error]: Dangling binary operator without right-hand operand"
                    exit(1)
                end
                chk_tok = toks[chk_pos]
                chk_k = chk_tok.tok_kind
                chk_x = chk_tok.tok_text
                if chk_k != TOK_STR() and (chk_k == TOK_SEMI() or chk_k == TOK_RBRACE() or chk_k == TOK_RPAREN() or chk_k == TOK_EOF() or chk_x == ";" or chk_x == "}" or chk_x == ")")
                    say "❌ [Syntax Error]: Dangling binary operator '" + txt + "' followed by '" + chk_x + "' at line " + str(chk_tok.tok_span.span_start_line)
                    exit(1)
                end

                // Push left operand (%rax) (and %rdx val_tag if dyn_tagged) to stack
                x86_synth_emit_byte(s, 80) // push rax
                if left_type == "dyn_tagged"
                    x86_synth_emit_byte(s, 82) // push rdx
                end

                // Evaluate right operand with multiplicative precedence into %rax
                x86_synth_compile_expr_mul(s, toks, pos_box)
                right_type = s.synth_last_expr_type
                right_ptr_t = s.synth_last_struct

                if left_type == "dyn_tagged" or right_type == "dyn_tagged"
                    tag_op_a = 0
                    if op_kind == TOK_MINUS()
                        tag_op_a = 1
                    end
                    x86_synth_emit_tagged_binop(s, left_type, right_type, tag_op_a)
                else
                    // Move right operand to %rcx, restore left operand to %rax
                    x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 193)
                    x86_synth_emit_byte(s, 88)  // pop rax

                    if is_left_ptr == 1
                        // WHY: Typed pointer arithmetic (`*T + n`, `*T - n`, `p2 - p1`) scales by exact `sizeof(T)`!
                        ptr_elem_sz = x86_synth_sizeof_type(s, x86_synth_ptr_pointee(left_ptr_t))
                        if ptr_elem_sz < 1 ptr_elem_sz = 1 end
                        if op_kind == TOK_PLUS()
                            if ptr_elem_sz > 1
                                // imul rcx, rcx, ptr_elem_sz (48 69 C9 <u32>)
                                x86_synth_emit_bytes(s, [72, 105, 201])
                                x86_synth_emit_u32(s, ptr_elem_sz)
                            end
                            x86_synth_emit_bytes(s, [72, 1, 200]) // add rax, rcx
                            s.synth_last_struct = left_ptr_t
                            s.synth_last_expr_type = "uint"
                        else
                            if x86_synth_is_ptr_type(right_ptr_t) == 1
                                // Pointer difference: (p2 - p1) / sizeof(T)
                                x86_synth_emit_bytes(s, [72, 41, 200]) // sub rax, rcx
                                if ptr_elem_sz > 1
                                    x86_synth_emit_bytes(s, [72, 199, 193]) // mov rcx, ptr_elem_sz
                                    x86_synth_emit_u32(s, ptr_elem_sz)
                                    x86_synth_emit_bytes(s, [72, 153, 72, 247, 249]) // cqo; idiv rcx
                                end
                                s.synth_last_struct = ""
                                s.synth_last_expr_type = "int"
                            else
                                if ptr_elem_sz > 1
                                    x86_synth_emit_bytes(s, [72, 105, 201])
                                    x86_synth_emit_u32(s, ptr_elem_sz)
                                end
                                x86_synth_emit_bytes(s, [72, 41, 200]) // sub rax, rcx
                                s.synth_last_struct = left_ptr_t
                                s.synth_last_expr_type = "uint"
                            end
                        end
                    elif left_type == "float" or right_type == "float"
                        // WHY: SSE2 64-bit Double-Precision Floating Point Addition & Subtraction.
                        if left_type == "float"
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 110)
                            x86_synth_emit_byte(s, 192)
                        else
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 42)
                            x86_synth_emit_byte(s, 192)
                        end

                        if right_type == "float"
                            x86_synth_emit_byte(s, 102)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 110)
                            x86_synth_emit_byte(s, 201)
                        else
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 42)
                            x86_synth_emit_byte(s, 201)
                        end

                        if op_kind == TOK_PLUS()
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 88)
                            x86_synth_emit_byte(s, 193)
                        elif op_kind == TOK_MINUS()
                            x86_synth_emit_byte(s, 242)
                            x86_synth_emit_byte(s, 15)
                            x86_synth_emit_byte(s, 92)
                            x86_synth_emit_byte(s, 193)
                        end

                        x86_synth_emit_byte(s, 102)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 15)
                        x86_synth_emit_byte(s, 126)
                        x86_synth_emit_byte(s, 192)
                        s.synth_last_expr_type = "float"
                    elif op_kind == TOK_PLUS()
                        if s.synth_freestanding == 1 or ((x86_synth_is_int_like(left_type) == 1 or x86_synth_is_int_like(right_type) == 1) and left_type != "str" and right_type != "str")
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 1)
                            x86_synth_emit_byte(s, 200) // add rax, rcx
                            if left_type == "uint" or right_type == "uint"
                                s.synth_last_expr_type = "uint"
                            else
                                s.synth_last_expr_type = "int"
                            end
                        elif left_type == "str" and right_type == "uint"
                            // Convert unsigned RHS via _lipi_uint_to_str then concat
                            x86_synth_emit_bytes(s, [80, 72, 131, 236, 8, 72, 137, 207]) // push rax; sub rsp, 8; mov rdi, rcx
                            x86_synth_emit_call_helper(s, "_lipi_uint_to_str")
                            x86_synth_emit_bytes(s, [72, 137, 198, 72, 131, 196, 8, 95]) // mov rsi, rax; add rsp, 8; pop rdi
                            x86_synth_emit_call_helper(s, "_lipi_str_concat")
                            s.synth_last_expr_type = "str"
                        elif left_type == "uint" and right_type == "str"
                            x86_synth_emit_bytes(s, [81, 72, 131, 236, 8, 72, 137, 199]) // push rcx; sub rsp, 8; mov rdi, rax
                            x86_synth_emit_call_helper(s, "_lipi_uint_to_str")
                            x86_synth_emit_bytes(s, [72, 137, 199, 72, 131, 196, 8, 94]) // mov rdi, rax; add rsp, 8; pop rsi
                            x86_synth_emit_call_helper(s, "_lipi_str_concat")
                            s.synth_last_expr_type = "str"
                        else
                            x86_synth_emit_byte(s, 72) // mov rdi, rax
                            x86_synth_emit_byte(s, 137)
                            x86_synth_emit_byte(s, 199)
                            x86_synth_emit_byte(s, 72) // mov rsi, rcx
                            x86_synth_emit_byte(s, 137)
                            x86_synth_emit_byte(s, 206)
                            x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                            if left_type == "str" or right_type == "str"
                                s.synth_last_expr_type = "str"
                            else
                                s.synth_last_expr_type = ""
                            end
                        end
                    elif op_kind == TOK_MINUS()
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 200)
                        if left_type == "uint" or right_type == "uint"
                            s.synth_last_expr_type = "uint"
                        else
                            s.synth_last_expr_type = "int"
                        end
                    end
                end
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
            sh_left_t = s.synth_last_expr_type
            next_ps = pos + 1
            is_imm_shift = 0
            sh_imm = 0
            if next_ps < toks.len() and toks[next_ps].tok_kind == TOK_INT()
                sh_cand = toks[next_ps].tok_int_val
                if sh_cand >= 0 and sh_cand < 64
                    afs = next_ps + 1
                    afs_ok = 0
                    if afs >= toks.len()
                        afs_ok = 1
                    else
                        ask = toks[afs].tok_kind
                        astx = toks[afs].tok_text
                        if ask != TOK_STAR() and ask != TOK_SLASH() and ask != TOK_PERCENT() and ask != TOK_MATMUL() and ask != TOK_PLUS() and ask != TOK_MINUS() and ask != TOK_DOT() and ask != TOK_LBRACKET() and astx != "+" and astx != "-" and astx != "*" and astx != "/" and astx != "%" and astx != "@" and astx != "."
                            afs_ok = 1
                        end
                    end
                    if afs_ok == 1
                        is_imm_shift = 1
                        sh_imm = sh_cand
                    end
                end
            end

            if is_imm_shift == 1
                // WHY: 1-cycle immediate shift: logical `shr` for unsigned u8/u16/u32/u64, arithmetic `sar` for signed.
                list_set(pos_box, 0, next_ps + 1)
                if op_kind == TOK_SHL()
                    x86_synth_emit_bytes(s, [72, 193, 224, sh_imm])
                elif sh_left_t == "uint"
                    x86_synth_emit_bytes(s, [72, 193, 232, sh_imm]) // shr rax, imm8
                else
                    x86_synth_emit_bytes(s, [72, 193, 248, sh_imm]) // sar rax, imm8
                end
                if sh_left_t == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
                s.synth_last_struct = ""
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
                    if sh_left_t == "uint"
                        // shr rax, cl (0x48 0xD3 0xE8) — logical zero-fill right shift
                        x86_synth_emit_bytes(s, [72, 211, 232])
                    else
                        // sar rax, cl (0x48 0xD3 0xF8) — arithmetic sign-extending right shift
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 211)
                        x86_synth_emit_byte(s, 248)
                    end
                end
                if sh_left_t == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
                s.synth_last_struct = ""
            end
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
            left_type = s.synth_last_expr_type
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) (and %rdx val_tag if dyn_tagged) to stack
            x86_synth_emit_byte(s, 80) // push rax
            if left_type == "dyn_tagged"
                x86_synth_emit_byte(s, 82) // push rdx
            end

            // Evaluate right operand with shift precedence into %rax
            x86_synth_compile_expr_shift(s, toks, pos_box)
            right_type = s.synth_last_expr_type

            if left_type == "dyn_tagged" or right_type == "dyn_tagged"
                tag_op_r = 5
                if op_kind == TOK_LTE()
                    tag_op_r = 6
                elif op_kind == TOK_GT()
                    tag_op_r = 7
                elif op_kind == TOK_GTE()
                    tag_op_r = 8
                end
                x86_synth_emit_tagged_binop(s, left_type, right_type, tag_op_r)
            else
                // Move right operand to %rcx, restore left operand to %rax
                x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 193)
                x86_synth_emit_byte(s, 88)  // pop rax

                if left_type == "float" or right_type == "float"
                    if left_type == "float"
                        x86_synth_emit_bytes(s, [102, 72, 15, 110, 192]) // movq xmm0, rax
                    else
                        x86_synth_emit_bytes(s, [242, 72, 15, 42, 192])  // cvtsi2sd xmm0, rax
                    end
                    if right_type == "float"
                        x86_synth_emit_bytes(s, [102, 72, 15, 110, 201]) // movq xmm1, rcx
                    else
                        x86_synth_emit_bytes(s, [242, 72, 15, 42, 201])  // cvtsi2sd xmm1, rcx
                    end
                    if op_kind == TOK_LT()
                        x86_synth_emit_bytes(s, [102, 15, 46, 200, 15, 151, 192, 72, 15, 182, 192])
                    elif op_kind == TOK_LTE()
                        x86_synth_emit_bytes(s, [102, 15, 46, 200, 15, 147, 192, 72, 15, 182, 192])
                    elif op_kind == TOK_GT()
                        x86_synth_emit_bytes(s, [102, 15, 46, 193, 15, 151, 192, 72, 15, 182, 192])
                    elif op_kind == TOK_GTE()
                        x86_synth_emit_bytes(s, [102, 15, 46, 193, 15, 147, 192, 72, 15, 182, 192])
                    end
                elif left_type == "uint" or right_type == "uint"
                    // WHY: Unsigned 64-bit relational comparison using setb/setbe/seta/setae (CF/ZF)
                    // so u64 values >= 2^63 (e.g. 0xFFFFFFFF80000000 > 4096) evaluate accurately.
                    if op_kind == TOK_LT()
                        x86_synth_emit_bytes(s, [72, 57, 200, 15, 146, 192, 72, 15, 182, 192]) // setb
                    elif op_kind == TOK_LTE()
                        x86_synth_emit_bytes(s, [72, 57, 200, 15, 150, 192, 72, 15, 182, 192]) // setbe
                    elif op_kind == TOK_GT()
                        x86_synth_emit_bytes(s, [72, 57, 200, 15, 151, 192, 72, 15, 182, 192]) // seta
                    elif op_kind == TOK_GTE()
                        x86_synth_emit_bytes(s, [72, 57, 200, 15, 147, 192, 72, 15, 182, 192]) // setae
                    end
                elif op_kind == TOK_LT()
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
                end
                s.synth_last_expr_type = "int"
                s.synth_last_struct = ""
            end
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
            left_type = s.synth_last_expr_type
            list_set(pos_box, 0, pos + 1) // Consume operator

            // Push left operand (%rax) (and %rdx val_tag if dyn_tagged) to stack
            x86_synth_emit_byte(s, 80) // push rax
            if left_type == "dyn_tagged"
                x86_synth_emit_byte(s, 82) // push rdx
            end

            // Evaluate right operand with relational precedence into %rax
            x86_synth_compile_expr_rel(s, toks, pos_box)
            right_type = s.synth_last_expr_type

            if left_type == "dyn_tagged" or right_type == "dyn_tagged"
                tag_op_e = 9
                if op_kind == TOK_NEQ()
                    tag_op_e = 10
                end
                x86_synth_emit_tagged_binop(s, left_type, right_type, tag_op_e)
            else
                // Move right operand to %rcx, restore left operand to %rax
                x86_synth_emit_byte(s, 72)  // mov rcx, rax (0x48 0x89 0xC1)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 193)
                x86_synth_emit_byte(s, 88)  // pop rax

                if left_type == "float" or right_type == "float"
                    if left_type == "float"
                        x86_synth_emit_bytes(s, [102, 72, 15, 110, 192]) // movq xmm0, rax
                    else
                        x86_synth_emit_bytes(s, [242, 72, 15, 42, 192])  // cvtsi2sd xmm0, rax
                    end
                    if right_type == "float"
                        x86_synth_emit_bytes(s, [102, 72, 15, 110, 201]) // movq xmm1, rcx
                    else
                        x86_synth_emit_bytes(s, [242, 72, 15, 42, 201])  // cvtsi2sd xmm1, rcx
                    end
                    if op_kind == TOK_EQ()
                        x86_synth_emit_bytes(s, [102, 15, 46, 193, 15, 148, 192, 15, 155, 193, 32, 200, 72, 15, 182, 192])
                    elif op_kind == TOK_NEQ()
                        x86_synth_emit_bytes(s, [102, 15, 46, 193, 15, 149, 192, 15, 154, 193, 8, 200, 72, 15, 182, 192])
                    end
                elif (s.synth_freestanding == 1 or (x86_synth_is_int_like(left_type) == 1 and x86_synth_is_int_like(right_type) == 1)) and op_kind == TOK_EQ()
                    x86_synth_emit_bytes(s, [72, 57, 200, 15, 148, 192, 72, 15, 182, 192])
                elif (s.synth_freestanding == 1 or (x86_synth_is_int_like(left_type) == 1 and x86_synth_is_int_like(right_type) == 1)) and op_kind == TOK_NEQ()
                    x86_synth_emit_bytes(s, [72, 57, 200, 15, 149, 192, 72, 15, 182, 192])
                elif op_kind == TOK_EQ()
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 199)
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 206)
                    x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
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
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 199)
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 206)
                    x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
                    x86_synth_emit_byte(s, 133)
                    x86_synth_emit_byte(s, 192)
                    x86_synth_emit_byte(s, 15)
                    x86_synth_emit_byte(s, 149)
                    x86_synth_emit_byte(s, 192)
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 15)
                    x86_synth_emit_byte(s, 182)
                    x86_synth_emit_byte(s, 192)
                end
                s.synth_last_expr_type = "int"
                s.synth_last_struct = ""
            end
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
            bit_left_t = s.synth_last_expr_type
            next_pb = pos + 1
            is_imm_bit = 0
            bit_imm = 0
            if next_pb < toks.len() and toks[next_pb].tok_kind == TOK_INT()
                b_cand = toks[next_pb].tok_int_val
                if b_cand >= -128 and b_cand <= 2147483647
                    afb = next_pb + 1
                    afb_ok = 0
                    if afb >= toks.len()
                        afb_ok = 1
                    else
                        abk = toks[afb].tok_kind
                        abtx = toks[afb].tok_text
                        if abk != TOK_STAR() and abk != TOK_SLASH() and abk != TOK_PERCENT() and abk != TOK_MATMUL() and abk != TOK_PLUS() and abk != TOK_MINUS() and abk != TOK_SHL() and abk != TOK_SHR() and abk != TOK_LT() and abk != TOK_LTE() and abk != TOK_GT() and abk != TOK_GTE() and abk != TOK_EQ() and abk != TOK_NEQ() and abk != TOK_DOT() and abk != TOK_LBRACKET() and abtx != "==" and abtx != "!=" and abtx != "<" and abtx != ">" and abtx != "<=" and abtx != ">=" and abtx != "<<" and abtx != ">>" and abtx != "+" and abtx != "-" and abtx != "*" and abtx != "/" and abtx != "%" and abtx != "@" and abtx != "."
                            afb_ok = 1
                        end
                    end
                    if afb_ok == 1
                        is_imm_bit = 1
                        bit_imm = b_cand
                    end
                end
            end

            if is_imm_bit == 1
                // WHY: 1-cycle immediate bitwise and/or/xor directly on %rax without stack push/pop
                list_set(pos_box, 0, next_pb + 1)
                if bit_imm >= -128 and bit_imm <= 127
                    b_i8 = (bit_imm + 256) % 256
                    if op_kind == TOK_AMP()
                        x86_synth_emit_bytes(s, [72, 131, 224, b_i8]) // and rax, imm8
                    elif op_kind == TOK_BAR()
                        x86_synth_emit_bytes(s, [72, 131, 200, b_i8]) // or rax, imm8
                    else
                        x86_synth_emit_bytes(s, [72, 131, 240, b_i8]) // xor rax, imm8
                    end
                else
                    if op_kind == TOK_AMP()
                        x86_synth_emit_bytes(s, [72, 37]) // and rax, imm32
                    elif op_kind == TOK_BAR()
                        x86_synth_emit_bytes(s, [72, 13]) // or rax, imm32
                    else
                        x86_synth_emit_bytes(s, [72, 53]) // xor rax, imm32
                    end
                    x86_synth_emit_u32(s, bit_imm)
                end
                if bit_left_t == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
                s.synth_last_struct = ""
            else
                list_set(pos_box, 0, pos + 1) // Consume operator

                // Push left operand (%rax) to stack
                x86_synth_emit_byte(s, 80) // push rax

                // Evaluate right operand with equality precedence into %rax
                x86_synth_compile_expr_eq(s, toks, pos_box)
                bit_right_t = s.synth_last_expr_type

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
                end
                if bit_left_t == "uint" or bit_right_t == "uint"
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
                s.synth_last_struct = ""
            end
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

