// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64 FEATURE PARITY RUNTIME (runtime_parity.lp)
// ⚡ 100% Pure Lipi | Zero C | Zero Libc | Direct RV64G Machine Code Synthesis
// 🏛️ File: src/compiler/backend/targets/riscv64/runtime_parity.lp
//
// WHY THIS MODULE:
// Brings full x86_64 feature parity directly to the RISC-V 64 (RV64G) silicon
// backend and pure-Lipi RV64 VM (--run-rv64):
//   1. First-Class Closures (`CLOS` magic 0x434C4F53, PC-relative AUIPC+ADDI,
//      environment register t5=x30, mutable boxed upvalue cells, indirect JALR).
//   2. Native `DICT0` HashMap Runtime (32B header with magic 0x44494354 at [+24],
//      FNV-1a string & integer hashing, open addressing with linear probing &
//      automatic 2x rehash, unified container indexing for both lists and dicts).
//   3. Native `ByteBuffer` Runtime (growable 24B {data_ptr, len, cap}, buf_new,
//      buf_write_byte, buf_write_str, buf_to_str, buf_len, buf_ptr, buf_clear).
//   4. LIFO `defer` Statement Replay across `return` and function exit.
// ==============================================================================

fn riscv64_emit_bltu s rs1 rs2 imm
    bytes = rv64_encode_b(99, 6, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0
end

fn riscv64_emit_bgeu s rs1 rs2 imm
    bytes = rv64_encode_b(99, 7, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0
end

fn riscv64_synth_emit_call_helper s hname
    call_off = s.rv_code.len()
    riscv64_emit_jal(s, 1, 0)
    cr = Riscv64CallReloc()
    cr.rv_cr_patch_offset = call_off
    cr.rv_cr_target_name = hname
    push(s.rv_call_relocs, cr)
    return 0
end

fn riscv64_is_boxed_name s name
    if s.rv_boxed_vars == 0 return 0 end
    i = 0
    while i < s.rv_boxed_vars.len()
        if s.rv_boxed_vars[i] == name return 1 end
        i = i + 1
    end
    return 0
end

fn riscv64_find_local_var s name
    i = 0
    while i < s.rv_locals.len()
        if s.rv_locals[i].rv_lv_name == name
            return s.rv_locals[i]
        end
        i = i + 1
    end
    return 0
end

fn riscv64_is_block_end toks p
    if p >= toks.len() return 0 end
    t = toks[p]
    k = t.tok_kind
    txt = t.tok_text
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "end" or txt == "শেষ" or txt == "@end"))
        if p + 1 < toks.len() and (toks[p + 1].tok_kind == TOK_ASSIGN() or toks[p + 1].tok_text == "=")
            return 0
        end
        return 1
    end
    return 0
end

fn riscv64_is_compound_assign_tok tok
    k = tok.tok_kind
    tx = tok.tok_text
    if k == TOK_PLUSEQ() or tx == "+=" return TOK_PLUS() end
    if k == TOK_MINUSEQ() or tx == "-=" return TOK_MINUS() end
    if k == TOK_STAREQ() or tx == "*=" return TOK_STAR() end
    if k == TOK_SLASHEQ() or tx == "/=" return TOK_SLASH() end
    if k == TOK_PERCENTEQ() or tx == "%=" return TOK_PERCENT() end
    return 0
end

fn riscv64_prescan_boxed_vars toks start_pos base_col base_line
    // WHY: Identifies outer locals mutated inside nested closures so they are auto-boxed
    // into shared 8-byte heap upvalue cells (zero overhead for non-escaping locals).
    res = list()
    n = toks.len()
    i = start_pos
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF() break end
        if base_line >= 0
            if riscv64_is_block_end(toks, i) == 1 and t.tok_span.span_start_col <= base_col
                break
            end
            if t.tok_span.span_start_line > base_line and t.tok_span.span_start_col <= base_col and k != TOK_NEWLINE() and k != TOK_SEMI() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_DOC() and k != TOK_COMMENT_BLOCK()
                break
            end
        end
        if (k == TOK_KW_FN() or k == TOK_DIR_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn"))) and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            break
        end
        // Detect closure literal: `fn(...)` or `|...|`
        is_clos = 0
        cp = i
        c_params = list()
        if (k == TOK_KW_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ"))) and i + 1 < n and (toks[i + 1].tok_kind == TOK_LPAREN() or toks[i + 1].tok_text == "(")
            is_clos = 1
            cp = i + 2
            while cp < n and toks[cp].tok_kind != TOK_RPAREN() and toks[cp].tok_text != ")"
                if riscv64_is_ident_token(toks[cp].tok_kind) == 1
                    push(c_params, toks[cp].tok_text)
                end
                cp = cp + 1
            end
            if cp < n cp = cp + 1 end
        elif k == TOK_BAR() or (k != TOK_STR() and txt == "|")
            // Confirm `|params| =>` or `|params| {`
            sp = i + 1
            ok_bar = 1
            while sp < n and toks[sp].tok_kind != TOK_BAR() and toks[sp].tok_text != "|"
                if riscv64_is_ident_token(toks[sp].tok_kind) == 1
                    push(c_params, toks[sp].tok_text)
                elif toks[sp].tok_kind != TOK_COMMA() and toks[sp].tok_text != ","
                    ok_bar = 0
                    break
                end
                sp = sp + 1
            end
            if ok_bar == 1 and sp + 1 < n and (toks[sp].tok_kind == TOK_BAR() or toks[sp].tok_text == "|")
                nk_b = toks[sp + 1].tok_kind
                nt_b = toks[sp + 1].tok_text
                if nk_b == TOK_FAT_ARROW() or nt_b == "=>" or nk_b == TOK_LBRACE() or nt_b == "{"
                    is_clos = 1
                    cp = sp + 1
                end
            end
        end
        if is_clos == 1
            while cp < n and (toks[cp].tok_kind == TOK_NEWLINE() or toks[cp].tok_kind == TOK_FAT_ARROW() or toks[cp].tok_text == "=>")
                cp = cp + 1
            end
            b_end = cp
            if cp < n and (toks[cp].tok_kind == TOK_LBRACE() or toks[cp].tok_text == "{")
                bd = 1
                b_end = cp + 1
                while b_end < n and bd > 0
                    if toks[b_end].tok_kind == TOK_LBRACE() or toks[b_end].tok_text == "{"
                        bd = bd + 1
                    elif toks[b_end].tok_kind == TOK_RBRACE() or toks[b_end].tok_text == "}"
                        bd = bd - 1
                    end
                    b_end = b_end + 1
                end
            else
                c_line = t.tok_span.span_start_line
                while b_end < n and toks[b_end].tok_kind != TOK_EOF()
                    if toks[b_end].tok_kind == TOK_NEWLINE() or toks[b_end].tok_kind == TOK_SEMI()
                        break
                    end
                    if riscv64_is_block_end(toks, b_end) == 1
                        b_end = b_end + 1
                        break
                    end
                    b_end = b_end + 1
                end
            end
            // Scan closure body for assignments `v = ...` or `v op= ...` to non-param identifiers
            sc = cp
            while sc + 1 < b_end
                if toks[sc].tok_kind == TOK_IDENT()
                    vn = toks[sc].tok_text
                    nt = toks[sc + 1]
                    if nt.tok_kind == TOK_ASSIGN() or nt.tok_text == "=" or riscv64_is_compound_assign_tok(nt) != 0
                        is_p = 0
                        pi = 0
                        while pi < c_params.len()
                            if c_params[pi] == vn is_p = 1 break end
                            pi = pi + 1
                        end
                        if is_p == 0
                            dup = 0
                            ri = 0
                            while ri < res.len()
                                if res[ri] == vn dup = 1 break end
                                ri = ri + 1
                            end
                            if dup == 0 push(res, vn) end
                        end
                    end
                end
                sc = sc + 1
            end
            i = b_end
            continue
        end
        i = i + 1
    end
    return res
end

// ── 1. LIFO `defer` Replay Helper ─────────────────────────────────────────────
fn riscv64_emit_defers s toks
    if s.rv_emitting_defer == 1 or s.rv_defer_starts.len() == 0
        return 0
    end
    // WHY: Preserve BOTH return value (`a0`/x10) AND dynamic return type tag (`a1`/x11)
    // across deferred statements so cleanup calls like `defer push(log, 1)` cannot clobber `a1`!
    s.rv_emitting_defer = 1
    ret_save_off = riscv64_synth_alloc_var(s, "__rv_defer_ret")
    tag_save_off = riscv64_synth_alloc_var(s, "__rv_defer_tag")
    riscv64_emit_local_sd(s, 10, ret_save_off)
    riscv64_emit_local_sd(s, 11, tag_save_off)
    di = s.rv_defer_starts.len() - 1
    while di >= 0
        d_pos = [s.rv_defer_starts[di]]
        d_end = s.rv_defer_ends[di]
        while get(d_pos, 0) < d_end
            riscv64_synth_skip_whitespace_tokens(toks, d_pos)
            cur_d = get(d_pos, 0)
            if cur_d >= d_end break end
            riscv64_synth_compile_statement(s, toks, d_pos)
            if get(d_pos, 0) <= cur_d list_set(d_pos, 0, cur_d + 1) end
        end
        di = di - 1
    end
    riscv64_emit_local_ld(s, 10, ret_save_off)
    riscv64_emit_local_ld(s, 11, tag_save_off)
    s.rv_emitting_defer = 0
    return 0
end

// ── 2. Indirect Call / Closure Dispatch on t4 (x29) ───────────────────────────
fn riscv64_emit_indirect_call_t4 s
    // WHY: Dispatches BOTH raw function pointers AND heap `CLOS` objects (magic 0x434C4F53 at 0(t4)).
    // If CLOS, passes closure pointer in t5 (x30) and loads code pointer from 8(t4) before JALR ra, t4, 0.
    riscv64_emit_ld(s, 31, 29, 0)             // t6 = [t4 + 0]
    riscv64_emit_li(s, 30, 1129074515)        // t5 = 0x434C4F53 ('CLOS')
    bne_raw = s.rv_code.len()
    riscv64_emit_bne(s, 31, 30, 0)            // if != 'CLOS', raw fn_ptr
    riscv64_emit_mv(s, 30, 29)                // t5 (env reg) = closure_ptr
    riscv64_emit_ld(s, 29, 29, 8)             // t4 = code_ptr
    raw_call_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_raw, 1, 31, 30, raw_call_off)
    riscv64_emit_jalr(s, 1, 29, 0)            // jalr ra, t4, 0
    return 0
end

// ── 3. First-Class Closure Literal Compiler (PC-Relative AUIPC+ADDI) ──────────
fn riscv64_emit_closure_literal s toks pos_box c_params
    // WHY: Compiles `fn(p...) { ... }`, `fn(p...) => expr`, `fn(p...) ... end`, or `|p...| => expr`
    // into an inline skipped RV64 function body + GC/arena-allocated heap `CLOS` object.
    // Captures outer locals (sharing boxed upvalue cells for mutated captures!).
    riscv64_synth_skip_whitespace_tokens(toks, pos_box)
    c_mode = 0 // 0=expr, 1=brace, 2=block-end
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_FAT_ARROW() or toks[get(pos_box, 0)].tok_text == "=>")
        list_set(pos_box, 0, get(pos_box, 0) + 1)
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
    end
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
        c_mode = 1
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end
    body_tok_start = get(pos_box, 0)

    // Snapshot outer locals so we capture every outer variable currently in scope
    cap_names = list()
    cap_offs = list()
    cap_boxed = list()
    li = 0
    while li < s.rv_locals.len()
        lv = s.rv_locals[li]
        is_shadow = 0
        pi = 0
        while pi < c_params.len()
            if c_params[pi] == lv.rv_lv_name is_shadow = 1 break end
            pi = pi + 1
        end
        if is_shadow == 0
            push(cap_names, lv.rv_lv_name)
            push(cap_offs, lv.rv_lv_offset)
            push(cap_boxed, lv.rv_lv_is_boxed)
        end
        li = li + 1
    end

    // Emit jump over closure body
    jmp_over = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    body_entry_off = s.rv_code.len()
    saved_locals = s.rv_locals
    saved_stack_off = s.rv_stack_offset
    saved_sp_delta = s.rv_sp_delta
    saved_in_fn = s.rv_in_function
    saved_try = s.rv_try_patches
    saved_boxed = s.rv_boxed_vars
    saved_ds = s.rv_defer_starts
    saved_de = s.rv_defer_ends
    s.rv_locals = list()
    s.rv_stack_offset = 16
    s.rv_sp_delta = 0
    s.rv_in_function = 1
    s.rv_try_patches = list()
    s.rv_boxed_vars = list()
    s.rv_defer_starts = list()
    s.rv_defer_ends = list()

    riscv64_emit_prologue(s)
    // Save incoming arguments a0..a7 + RV64 LP64 stack arguments pi >= 8 at [s0 + (pi - 8) * 8]
    pi = 0
    while pi < c_params.len()
        poff = riscv64_synth_alloc_var(s, c_params[pi])
        if pi < 8
            riscv64_emit_local_sd(s, 10 + pi, poff)
        else
            riscv64_emit_ld(s, 5, 8, (pi - 8) * 8)
            riscv64_emit_local_sd(s, 5, poff)
        end
        pi = pi + 1
    end
    // Unpack captured outer variables from t5 (x30) closure env pointer
    ci = 0
    while ci < cap_names.len()
        coff = riscv64_synth_alloc_var(s, cap_names[ci])
        clv = riscv64_find_local_var(s, cap_names[ci])
        if clv != 0
            clv.rv_lv_is_boxed = cap_boxed[ci]
        end
        riscv64_emit_ld(s, 5, 30, 24 + (ci * 8)) // ld t0, (24+ci*8)(t5)
        riscv64_emit_local_sd(s, 5, coff)
        ci = ci + 1
    end

    if c_mode == 1
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cp = get(pos_box, 0)
            if cp >= toks.len() break end
            if toks[cp].tok_kind == TOK_RBRACE() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "}")
                list_set(pos_box, 0, cp + 1)
                break
            end
            bp = get(pos_box, 0)
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) <= bp list_set(pos_box, 0, bp + 1) end
        end
        riscv64_emit_addi(s, 10, 0, 0)
    else
        riscv64_synth_compile_expr(s, toks, pos_box)
    end
    riscv64_emit_defers(s, toks)
    riscv64_emit_epilogue(s)

    // Restore outer scope
    s.rv_locals = saved_locals
    s.rv_stack_offset = saved_stack_off
    s.rv_sp_delta = saved_sp_delta
    s.rv_in_function = saved_in_fn
    s.rv_try_patches = saved_try
    s.rv_boxed_vars = saved_boxed
    s.rv_defer_starts = saved_ds
    s.rv_defer_ends = saved_de

    after_body_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_over, 0, after_body_off)

    // Allocate heap CLOS object: (3 + n_caps) * 8 bytes (min 32)
    n_caps = cap_names.len()
    clos_sz = (3 + n_caps) * 8
    if clos_sz < 32 clos_sz = 32 end
    riscv64_emit_li(s, 10, clos_sz)
    riscv64_synth_emit_call_alloc(s)          // a0 = clos_ptr
    riscv64_emit_mv(s, 28, 10)                // t3 = clos_ptr
    // [clos + 0] = 0x434C4F53 ('CLOS')
    riscv64_emit_li(s, 5, 1129074515)
    riscv64_emit_sd(s, 5, 28, 0)
    // [clos + 8] = PC-relative address of body_entry_off via AUIPC + ADDI
    auipc_off = s.rv_code.len()
    delta = body_entry_off - auipc_off
    lo = delta & 4095
    if lo >= 2048 lo = lo - 4096 end
    hi = ((delta - lo) >> 12) & 1048575
    riscv64_emit_auipc(s, 5, hi)
    riscv64_emit_addi(s, 5, 5, lo)
    riscv64_emit_sd(s, 5, 28, 8)
    // [clos + 16] = n_caps
    riscv64_emit_li(s, 5, n_caps)
    riscv64_emit_sd(s, 5, 28, 16)
    // [clos + 24 + ci*8] = outer local value (or boxed cell pointer!)
    ci = 0
    while ci < n_caps
        riscv64_emit_local_ld(s, 5, cap_offs[ci])
        riscv64_emit_sd(s, 5, 28, 24 + (ci * 8))
        ci = ci + 1
    end
    riscv64_emit_mv(s, 10, 28)                // return clos_ptr in a0
    return 0
end

// ── 4. Pure RV64G DICT0 HashMap + Unified Container + ByteBuffer Helpers ──────

fn riscv64_synth_emit_dict_helpers s
    // WHY: Pure RV64G DICT0 HashMap (32B header: [0]=count, [8]=cap, [16]=slots, [24]=0x44494354)
    // with 24B slots {[0]=state(0/1/2), [8]=key, [16]=val}, FNV-1a string+int hashing, and 2x rehash.
    // All helpers preserve s1..s9 cleanly and never touch exception registers s10(x26)/s11(x27).

    // ── Helper A: __dict_hash(a0=key) -> a0=hash ──
    s.rv_dict_hash_off = s.rv_code.len()
    riscv64_emit_li(s, 5, 4194304)            // t0 = 0x400000 (string pointer threshold)
    blt_int_h = s.rv_code.len()
    riscv64_emit_blt(s, 10, 5, 0)
    // String FNV-1a hash
    riscv64_emit_mv(s, 6, 10)                 // t1 = ptr
    riscv64_emit_li(s, 10, 2166136261)        // a0 = FNV offset basis
    riscv64_emit_li(s, 7, 16777619)           // t2 = FNV prime
    h_loop = s.rv_code.len()
    riscv64_emit_lbu(s, 5, 6, 0)              // t0 = *ptr
    beq_h_done = s.rv_code.len()
    riscv64_emit_beq(s, 5, 0, 0)
    riscv64_emit_xor(s, 10, 10, 5)
    riscv64_emit_mul(s, 10, 10, 7)
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_jal(s, 0, h_loop - s.rv_code.len())
    h_done = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_h_done, 0, 5, 0, h_done)
    riscv64_emit_ret(s)
    // Integer multiplicative hash
    int_h_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_int_h, 4, 10, 5, int_h_off)
    riscv64_emit_li(s, 5, 2654435761)
    riscv64_emit_mul(s, 10, 10, 5)
    riscv64_emit_ret(s)

    // ── Helper B: __dict_key_eq(a0=k1, a1=k2) -> a0=(1 if equal else 0) ──
    s.rv_dict_eq_off = s.rv_code.len()
    bne_neq_ptr = s.rv_code.len()
    riscv64_emit_bne(s, 10, 11, 0)
    riscv64_emit_addi(s, 10, 0, 1)
    riscv64_emit_ret(s)
    neq_ptr_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_neq_ptr, 1, 10, 11, neq_ptr_off)
    riscv64_emit_li(s, 5, 4194304)
    blt_eq_f1 = s.rv_code.len()
    riscv64_emit_blt(s, 10, 5, 0)
    blt_eq_f2 = s.rv_code.len()
    riscv64_emit_blt(s, 11, 5, 0)
    // Byte-by-byte null-terminated string comparison
    eq_loop = s.rv_code.len()
    riscv64_emit_lbu(s, 6, 10, 0)
    riscv64_emit_lbu(s, 7, 11, 0)
    bne_eq_f = s.rv_code.len()
    riscv64_emit_bne(s, 6, 7, 0)
    beq_eq_t = s.rv_code.len()
    riscv64_emit_beq(s, 6, 0, 0)
    riscv64_emit_addi(s, 10, 10, 1)
    riscv64_emit_addi(s, 11, 11, 1)
    riscv64_emit_jal(s, 0, eq_loop - s.rv_code.len())
    eq_t_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_eq_t, 0, 6, 0, eq_t_off)
    riscv64_emit_addi(s, 10, 0, 1)
    riscv64_emit_ret(s)
    eq_f_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_eq_f1, 4, 10, 5, eq_f_off)
    riscv64_synth_patch_b(s, blt_eq_f2, 4, 11, 5, eq_f_off)
    riscv64_synth_patch_b(s, bne_eq_f, 1, 6, 7, eq_f_off)
    riscv64_emit_addi(s, 10, 0, 0)
    riscv64_emit_ret(s)

    // ── Helper C: __dict_new(a0=init_cap) -> a0=dict_hdr ──
    s.rv_dict_new_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_sd(s, 18, 2, 8)
    riscv64_emit_li(s, 9, 16)                 // s1 = cap = 16
    bge_dcap = s.rv_code.len()
    riscv64_emit_bge(s, 9, 10, 0)
    riscv64_emit_mv(s, 9, 10)
    dcap_ok = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_dcap, 5, 9, 10, dcap_ok)
    riscv64_emit_li(s, 10, 32)
    riscv64_synth_emit_call_alloc(s)          // a0 = hdr (32B)
    riscv64_emit_mv(s, 18, 10)                // s2 = hdr
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 10, 9, 5)             // cap * 24 bytes
    riscv64_synth_emit_call_alloc(s)          // a0 = slots
    // Zero-init slots (state=0)
    riscv64_emit_li(s, 5, 0)
    riscv64_emit_li(s, 6, 24)
    riscv64_emit_mul(s, 6, 9, 6)
    z_loop = s.rv_code.len()
    bge_z_done = s.rv_code.len()
    riscv64_emit_bge(s, 5, 6, 0)
    riscv64_emit_add(s, 7, 10, 5)
    riscv64_emit_sd(s, 0, 7, 0)
    riscv64_emit_addi(s, 5, 5, 8)
    riscv64_emit_jal(s, 0, z_loop - s.rv_code.len())
    z_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_z_done, 5, 5, 6, z_done)
    riscv64_emit_sd(s, 0, 18, 0)              // count = 0
    riscv64_emit_sd(s, 9, 18, 8)              // cap
    riscv64_emit_sd(s, 10, 18, 16)            // slots
    riscv64_emit_li(s, 5, 1145652052)         // 0x44494354 ('DICT')
    riscv64_emit_sd(s, 5, 18, 24)
    riscv64_emit_mv(s, 10, 18)
    riscv64_emit_ld(s, 18, 2, 8)
    riscv64_emit_ld(s, 9, 2, 16)
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)

    // ── Helper D: __dict_set(a0=hdr, a1=key, a2=val, a3=val_tag) -> a0=hdr ──
    s.rv_dict_set_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 80)
    riscv64_emit_sd(s, 1, 2, 72)
    riscv64_emit_sd(s, 9, 2, 64)
    riscv64_emit_sd(s, 18, 2, 56)
    riscv64_emit_sd(s, 19, 2, 48)
    riscv64_emit_sd(s, 20, 2, 40)
    riscv64_emit_sd(s, 21, 2, 32)
    riscv64_emit_sd(s, 22, 2, 24)
    riscv64_emit_sd(s, 23, 2, 16)
    riscv64_emit_sd(s, 24, 2, 8)
    riscv64_emit_sd(s, 25, 2, 0)
    riscv64_emit_mv(s, 9, 10)                 // s1 = hdr
    riscv64_emit_mv(s, 18, 11)                // s2 = key
    riscv64_emit_mv(s, 19, 12)                // s3 = val
    riscv64_emit_mv(s, 25, 13)                // s9 = val_tag (0=int, 1=float, 2=str)
    // Rehash if count * 2 >= cap
    riscv64_emit_ld(s, 20, 9, 0)              // s4 = count
    riscv64_emit_ld(s, 21, 9, 8)              // s5 = cap
    riscv64_emit_slli(s, 5, 20, 1)
    blt_no_rehash = s.rv_code.len()
    riscv64_emit_blt(s, 5, 21, 0)
    // Grow cap = cap * 2 and re-insert occupied entries
    riscv64_emit_ld(s, 22, 9, 16)             // s6 = old_slots
    riscv64_emit_mv(s, 23, 21)                // s7 = old_cap
    riscv64_emit_slli(s, 21, 21, 1)           // new_cap = old_cap * 2
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 10, 21, 5)
    riscv64_synth_emit_call_alloc(s)          // a0 = new_slots
    riscv64_emit_mv(s, 24, 10)                // s8 = new_slots
    // Zero new_slots
    riscv64_emit_li(s, 5, 0)
    riscv64_emit_li(s, 6, 24)
    riscv64_emit_mul(s, 6, 21, 6)
    rz_loop = s.rv_code.len()
    bge_rz = s.rv_code.len()
    riscv64_emit_bge(s, 5, 6, 0)
    riscv64_emit_add(s, 7, 24, 5)
    riscv64_emit_sd(s, 0, 7, 0)
    riscv64_emit_addi(s, 5, 5, 8)
    riscv64_emit_jal(s, 0, rz_loop - s.rv_code.len())
    rz_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_rz, 5, 5, 6, rz_done)
    riscv64_emit_sd(s, 0, 9, 0)               // count = 0
    riscv64_emit_sd(s, 21, 9, 8)              // cap = new_cap
    riscv64_emit_sd(s, 24, 9, 16)             // slots = new_slots
    // Re-insert each occupied slot from old_slots[0..old_cap-1] preserving val_tag
    riscv64_emit_li(s, 20, 0)                 // s4 = i = 0
    ri_loop = s.rv_code.len()
    bge_ri = s.rv_code.len()
    riscv64_emit_bge(s, 20, 23, 0)
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 20, 5)
    riscv64_emit_add(s, 5, 22, 5)
    riscv64_emit_ld(s, 6, 5, 0)               // raw state | (tag << 8)
    riscv64_emit_andi(s, 28, 6, 255)          // t3 = state_low
    riscv64_emit_addi(s, 7, 0, 1)
    bne_ri_skip = s.rv_code.len()
    riscv64_emit_bne(s, 28, 7, 0)
    riscv64_emit_mv(s, 10, 9)
    riscv64_emit_ld(s, 11, 5, 8)              // key
    riscv64_emit_ld(s, 12, 5, 16)             // val
    riscv64_emit_srli(s, 13, 6, 8)            // a3 = preserved val_tag
    riscv64_synth_emit_call_helper(s, "__dict_set")
    ri_skip = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_ri_skip, 1, 28, 7, ri_skip)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_jal(s, 0, ri_loop - s.rv_code.len())
    ri_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_ri, 5, 20, 23, ri_done)

    no_rehash_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_no_rehash, 4, 5, 21, no_rehash_off)
    riscv64_emit_ld(s, 21, 9, 8)              // s5 = cap
    riscv64_emit_ld(s, 22, 9, 16)             // s6 = slots
    riscv64_emit_addi(s, 23, 21, 0 - 1)       // s7 = mask = cap - 1
    riscv64_emit_mv(s, 10, 18)
    riscv64_synth_emit_call_helper(s, "__dict_hash")
    riscv64_emit_and(s, 20, 10, 23)           // s4 = idx = hash & mask
    riscv64_emit_li(s, 24, 0 - 1)             // s8 = first_tomb (-1)
    ds_probe = s.rv_code.len()
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 20, 5)
    riscv64_emit_add(s, 5, 22, 5)             // t0 = &slots[idx]
    riscv64_emit_ld(s, 6, 5, 0)               // t1 = raw state
    riscv64_emit_andi(s, 6, 6, 255)           // t1 = state_low
    beq_empty = s.rv_code.len()
    riscv64_emit_beq(s, 6, 0, 0)              // state == 0 -> insert!
    riscv64_emit_addi(s, 7, 0, 2)
    bne_not_tomb = s.rv_code.len()
    riscv64_emit_bne(s, 6, 7, 0)
    // state == 2 (tombstone): record if first_tomb < 0
    bge_has_tomb = s.rv_code.len()
    riscv64_emit_bge(s, 24, 0, 0)
    riscv64_emit_mv(s, 24, 20)
    has_tomb_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_has_tomb, 5, 24, 0, has_tomb_off)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_and(s, 20, 20, 23)
    riscv64_emit_jal(s, 0, ds_probe - s.rv_code.len())
    not_tomb_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_not_tomb, 1, 6, 7, not_tomb_off)
    // state == 1: compare key
    riscv64_emit_ld(s, 10, 5, 8)
    riscv64_emit_mv(s, 11, 18)
    riscv64_synth_emit_call_helper(s, "__dict_key_eq")
    beq_ds_next = s.rv_code.len()
    riscv64_emit_beq(s, 10, 0, 0)
    // Update existing key in-place (preserving new val_tag in bits 8..15)
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 20, 5)
    riscv64_emit_add(s, 5, 22, 5)
    riscv64_emit_slli(s, 6, 25, 8)
    riscv64_emit_ori(s, 6, 6, 1)
    riscv64_emit_sd(s, 6, 5, 0)
    riscv64_emit_sd(s, 19, 5, 16)
    jmp_ds_ret1 = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    ds_next_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_ds_next, 0, 10, 0, ds_next_off)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_and(s, 20, 20, 23)
    riscv64_emit_jal(s, 0, ds_probe - s.rv_code.len())
    // Insert new key at first_tomb (if >= 0) else idx
    empty_ins_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_empty, 0, 6, 0, empty_ins_off)
    blt_use_idx = s.rv_code.len()
    riscv64_emit_blt(s, 24, 0, 0)
    riscv64_emit_mv(s, 20, 24)
    use_idx_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_use_idx, 4, 24, 0, use_idx_off)
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 20, 5)
    riscv64_emit_add(s, 5, 22, 5)
    riscv64_emit_slli(s, 6, 25, 8)
    riscv64_emit_ori(s, 6, 6, 1)
    riscv64_emit_sd(s, 6, 5, 0)
    riscv64_emit_sd(s, 18, 5, 8)
    riscv64_emit_sd(s, 19, 5, 16)
    riscv64_emit_ld(s, 6, 9, 0)
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_sd(s, 6, 9, 0)
    ds_ret_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_ds_ret1, 0, ds_ret_off)
    riscv64_emit_mv(s, 10, 9)
    riscv64_emit_ld(s, 25, 2, 0)
    riscv64_emit_ld(s, 24, 2, 8)
    riscv64_emit_ld(s, 23, 2, 16)
    riscv64_emit_ld(s, 22, 2, 24)
    riscv64_emit_ld(s, 21, 2, 32)
    riscv64_emit_ld(s, 20, 2, 40)
    riscv64_emit_ld(s, 19, 2, 48)
    riscv64_emit_ld(s, 18, 2, 56)
    riscv64_emit_ld(s, 9, 2, 64)
    riscv64_emit_ld(s, 1, 2, 72)
    riscv64_emit_addi(s, 2, 2, 80)
    riscv64_emit_ret(s)

    // ── Helper E: __dict_get(a0=hdr, a1=key) -> (a0=val, a1=val_tag) ──
    s.rv_dict_get_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 9, 2, 48)
    riscv64_emit_sd(s, 18, 2, 40)
    riscv64_emit_sd(s, 19, 2, 32)
    riscv64_emit_sd(s, 20, 2, 24)
    riscv64_emit_sd(s, 21, 2, 16)
    riscv64_emit_sd(s, 22, 2, 8)
    riscv64_emit_mv(s, 9, 10)                 // s1 = hdr
    riscv64_emit_mv(s, 18, 11)                // s2 = key
    riscv64_emit_ld(s, 19, 9, 8)              // s3 = cap
    riscv64_emit_ld(s, 20, 9, 16)             // s4 = slots
    riscv64_emit_addi(s, 21, 19, 0 - 1)       // s5 = mask
    riscv64_emit_mv(s, 10, 18)
    riscv64_synth_emit_call_helper(s, "__dict_hash")
    riscv64_emit_and(s, 22, 10, 21)           // s6 = idx
    dg_loop = s.rv_code.len()
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 22, 5)
    riscv64_emit_add(s, 5, 20, 5)
    riscv64_emit_ld(s, 6, 5, 0)
    riscv64_emit_andi(s, 6, 6, 255)
    beq_dg_miss = s.rv_code.len()
    riscv64_emit_beq(s, 6, 0, 0)
    riscv64_emit_addi(s, 7, 0, 1)
    bne_dg_next = s.rv_code.len()
    riscv64_emit_bne(s, 6, 7, 0)
    riscv64_emit_ld(s, 10, 5, 8)
    riscv64_emit_mv(s, 11, 18)
    riscv64_synth_emit_call_helper(s, "__dict_key_eq")
    beq_dg_next2 = s.rv_code.len()
    riscv64_emit_beq(s, 10, 0, 0)
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 22, 5)
    riscv64_emit_add(s, 5, 20, 5)
    riscv64_emit_ld(s, 6, 5, 0)
    riscv64_emit_srli(s, 11, 6, 8)            // a1 = val_tag
    riscv64_emit_ld(s, 10, 5, 16)             // a0 = val
    jmp_dg_ret = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    dg_next_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_dg_next, 1, 6, 7, dg_next_off)
    riscv64_synth_patch_b(s, beq_dg_next2, 0, 10, 0, dg_next_off)
    riscv64_emit_addi(s, 22, 22, 1)
    riscv64_emit_and(s, 22, 22, 21)
    riscv64_emit_jal(s, 0, dg_loop - s.rv_code.len())
    dg_miss_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_dg_miss, 0, 6, 0, dg_miss_off)
    riscv64_emit_addi(s, 10, 0, 0)
    riscv64_emit_addi(s, 11, 0, 0)
    dg_ret_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_dg_ret, 0, dg_ret_off)
    riscv64_emit_ld(s, 22, 2, 8)
    riscv64_emit_ld(s, 21, 2, 16)
    riscv64_emit_ld(s, 20, 2, 24)
    riscv64_emit_ld(s, 19, 2, 32)
    riscv64_emit_ld(s, 18, 2, 40)
    riscv64_emit_ld(s, 9, 2, 48)
    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)

    // ── Helper F: __dict_has(a0=hdr, a1=key) -> a0=(0/1) ──
    s.rv_dict_has_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 9, 2, 48)
    riscv64_emit_sd(s, 18, 2, 40)
    riscv64_emit_sd(s, 19, 2, 32)
    riscv64_emit_sd(s, 20, 2, 24)
    riscv64_emit_sd(s, 21, 2, 16)
    riscv64_emit_sd(s, 22, 2, 8)
    riscv64_emit_mv(s, 9, 10)
    riscv64_emit_mv(s, 18, 11)
    riscv64_emit_ld(s, 19, 9, 8)
    riscv64_emit_ld(s, 20, 9, 16)
    riscv64_emit_addi(s, 21, 19, 0 - 1)
    riscv64_emit_mv(s, 10, 18)
    riscv64_synth_emit_call_helper(s, "__dict_hash")
    riscv64_emit_and(s, 22, 10, 21)
    dh_loop = s.rv_code.len()
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 22, 5)
    riscv64_emit_add(s, 5, 20, 5)
    riscv64_emit_ld(s, 6, 5, 0)
    riscv64_emit_andi(s, 6, 6, 255)
    beq_dh_miss = s.rv_code.len()
    riscv64_emit_beq(s, 6, 0, 0)
    riscv64_emit_addi(s, 7, 0, 1)
    bne_dh_next = s.rv_code.len()
    riscv64_emit_bne(s, 6, 7, 0)
    riscv64_emit_ld(s, 10, 5, 8)
    riscv64_emit_mv(s, 11, 18)
    riscv64_synth_emit_call_helper(s, "__dict_key_eq")
    beq_dh_next2 = s.rv_code.len()
    riscv64_emit_beq(s, 10, 0, 0)
    riscv64_emit_addi(s, 10, 0, 1)
    jmp_dh_ret = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    dh_next_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_dh_next, 1, 6, 7, dh_next_off)
    riscv64_synth_patch_b(s, beq_dh_next2, 0, 10, 0, dh_next_off)
    riscv64_emit_addi(s, 22, 22, 1)
    riscv64_emit_and(s, 22, 22, 21)
    riscv64_emit_jal(s, 0, dh_loop - s.rv_code.len())
    dh_miss_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_dh_miss, 0, 6, 0, dh_miss_off)
    riscv64_emit_addi(s, 10, 0, 0)
    dh_ret_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_dh_ret, 0, dh_ret_off)
    riscv64_emit_ld(s, 22, 2, 8)
    riscv64_emit_ld(s, 21, 2, 16)
    riscv64_emit_ld(s, 20, 2, 24)
    riscv64_emit_ld(s, 19, 2, 32)
    riscv64_emit_ld(s, 18, 2, 40)
    riscv64_emit_ld(s, 9, 2, 48)
    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)

    // ── Helper G: __dict_del(a0=hdr, a1=key) -> a0=(1 if deleted else 0) ──
    s.rv_dict_del_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 9, 2, 48)
    riscv64_emit_sd(s, 18, 2, 40)
    riscv64_emit_sd(s, 19, 2, 32)
    riscv64_emit_sd(s, 20, 2, 24)
    riscv64_emit_sd(s, 21, 2, 16)
    riscv64_emit_sd(s, 22, 2, 8)
    riscv64_emit_mv(s, 9, 10)
    riscv64_emit_mv(s, 18, 11)
    riscv64_emit_ld(s, 19, 9, 8)
    riscv64_emit_ld(s, 20, 9, 16)
    riscv64_emit_addi(s, 21, 19, 0 - 1)
    riscv64_emit_mv(s, 10, 18)
    riscv64_synth_emit_call_helper(s, "__dict_hash")
    riscv64_emit_and(s, 22, 10, 21)
    dd_loop = s.rv_code.len()
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 22, 5)
    riscv64_emit_add(s, 5, 20, 5)
    riscv64_emit_ld(s, 6, 5, 0)
    riscv64_emit_andi(s, 6, 6, 255)
    beq_dd_miss = s.rv_code.len()
    riscv64_emit_beq(s, 6, 0, 0)
    riscv64_emit_addi(s, 7, 0, 1)
    bne_dd_next = s.rv_code.len()
    riscv64_emit_bne(s, 6, 7, 0)
    riscv64_emit_ld(s, 10, 5, 8)
    riscv64_emit_mv(s, 11, 18)
    riscv64_synth_emit_call_helper(s, "__dict_key_eq")
    beq_dd_next2 = s.rv_code.len()
    riscv64_emit_beq(s, 10, 0, 0)
    // Mark tombstone (state=2) and decrement count
    riscv64_emit_li(s, 5, 24)
    riscv64_emit_mul(s, 5, 22, 5)
    riscv64_emit_add(s, 5, 20, 5)
    riscv64_emit_addi(s, 6, 0, 2)
    riscv64_emit_sd(s, 6, 5, 0)
    riscv64_emit_ld(s, 6, 9, 0)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_sd(s, 6, 9, 0)
    riscv64_emit_addi(s, 10, 0, 1)
    jmp_dd_ret = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    dd_next_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_dd_next, 1, 6, 7, dd_next_off)
    riscv64_synth_patch_b(s, beq_dd_next2, 0, 10, 0, dd_next_off)
    riscv64_emit_addi(s, 22, 22, 1)
    riscv64_emit_and(s, 22, 22, 21)
    riscv64_emit_jal(s, 0, dd_loop - s.rv_code.len())
    dd_miss_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_dd_miss, 0, 6, 0, dd_miss_off)
    riscv64_emit_addi(s, 10, 0, 0)
    dd_ret_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_dd_ret, 0, dd_ret_off)
    riscv64_emit_ld(s, 22, 2, 8)
    riscv64_emit_ld(s, 21, 2, 16)
    riscv64_emit_ld(s, 20, 2, 24)
    riscv64_emit_ld(s, 19, 2, 32)
    riscv64_emit_ld(s, 18, 2, 40)
    riscv64_emit_ld(s, 9, 2, 48)
    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)

    // ── Helper H: __container_get(a0=hdr, a1=key_or_idx) -> (a0=val, a1=tag) ──
    s.rv_cont_get_off = s.rv_code.len()
    if s.rv_freestanding == 0
        s.rv_needs_throw_null = 1
        riscv64_emit_li(s, 7, 4096)
        bgeu_cg_ok = s.rv_code.len()
        riscv64_emit_bgeu(s, 10, 7, 0)
        riscv64_emit_addi(s, 2, 2, 0 - 16)
        riscv64_emit_sd(s, 1, 2, 8)
        riscv64_synth_emit_call_helper(s, "_lipi_throw_null_deref")
        riscv64_emit_ld(s, 1, 2, 8)
        riscv64_emit_addi(s, 2, 2, 16)
        riscv64_emit_ret(s)
        cg_ok_off = s.rv_code.len()
        riscv64_synth_patch_b(s, bgeu_cg_ok, 7, 10, 7, cg_ok_off)
    end
    riscv64_emit_ld(s, 5, 10, 24)
    riscv64_emit_li(s, 6, 1145652052)         // 'DICT'
    bne_cg_list = s.rv_code.len()
    riscv64_emit_bne(s, 5, 6, 0)
    // Tail-jump directly into __dict_get (returns val in a0, val_tag in a1)
    riscv64_emit_jal(s, 0, s.rv_dict_get_off - s.rv_code.len())
    cg_list_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_cg_list, 1, 5, 6, cg_list_off)
    // Negative list indexing: if idx (a1) < 0, idx += hdr[0] (len)
    bge_cg_pos = s.rv_code.len()
    riscv64_emit_bge(s, 11, 0, 0)
    riscv64_emit_ld(s, 7, 10, 0)
    riscv64_emit_add(s, 11, 11, 7)
    cg_pos_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_cg_pos, 5, 11, 0, cg_pos_off)
    riscv64_emit_ld(s, 12, 10, 16)            // data_ptr
    riscv64_emit_slli(s, 11, 11, 3)
    riscv64_emit_add(s, 10, 12, 11)
    riscv64_emit_ld(s, 10, 10, 0)
    riscv64_emit_addi(s, 11, 0, 0)            // a1 = tag 0 for list elements
    riscv64_emit_ret(s)

    // ── Helper I: __container_set(a0=hdr, a1=key_or_idx, a2=val, a3=val_tag) -> a0=hdr ──
    s.rv_cont_set_off = s.rv_code.len()
    if s.rv_freestanding == 0
        s.rv_needs_throw_null = 1
        riscv64_emit_li(s, 7, 4096)
        bgeu_cs_ok = s.rv_code.len()
        riscv64_emit_bgeu(s, 10, 7, 0)
        riscv64_emit_addi(s, 2, 2, 0 - 16)
        riscv64_emit_sd(s, 1, 2, 8)
        riscv64_synth_emit_call_helper(s, "_lipi_throw_null_deref")
        riscv64_emit_ld(s, 1, 2, 8)
        riscv64_emit_addi(s, 2, 2, 16)
        riscv64_emit_ret(s)
        cs_ok_off = s.rv_code.len()
        riscv64_synth_patch_b(s, bgeu_cs_ok, 7, 10, 7, cs_ok_off)
    end
    riscv64_emit_ld(s, 5, 10, 24)
    riscv64_emit_li(s, 6, 1145652052)         // 'DICT'
    bne_cs_list = s.rv_code.len()
    riscv64_emit_bne(s, 5, 6, 0)
    riscv64_emit_jal(s, 0, s.rv_dict_set_off - s.rv_code.len())
    cs_list_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_cs_list, 1, 5, 6, cs_list_off)
    // Negative list indexing: if idx (a1) < 0, idx += hdr[0] (len)
    bge_cs_pos = s.rv_code.len()
    riscv64_emit_bge(s, 11, 0, 0)
    riscv64_emit_ld(s, 7, 10, 0)
    riscv64_emit_add(s, 11, 11, 7)
    cs_pos_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_cs_pos, 5, 11, 0, cs_pos_off)
    riscv64_emit_ld(s, 13, 10, 16)
    riscv64_emit_slli(s, 11, 11, 3)
    riscv64_emit_add(s, 13, 13, 11)
    riscv64_emit_sd(s, 12, 13, 0)
    riscv64_emit_ret(s)
    return 0
end

fn riscv64_synth_emit_buf_helpers s
    // WHY: Native RV64G ByteBuffer {data_ptr, len, cap} with amortized O(1) growth.

    // ── __buf_new(a0=init_cap) -> a0=buf_hdr ──
    s.rv_buf_new_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_sd(s, 18, 2, 8)
    riscv64_emit_li(s, 9, 64)                 // s1 = cap >= 64
    bge_bcap = s.rv_code.len()
    riscv64_emit_bge(s, 9, 10, 0)
    riscv64_emit_mv(s, 9, 10)
    bcap_ok = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_bcap, 5, 9, 10, bcap_ok)
    riscv64_emit_li(s, 10, 24)
    riscv64_synth_emit_call_alloc(s)
    riscv64_emit_mv(s, 18, 10)                // s2 = hdr
    riscv64_emit_mv(s, 10, 9)
    riscv64_synth_emit_call_alloc(s)          // a0 = data
    riscv64_emit_sb(s, 0, 10, 0)              // null-terminate empty buf
    riscv64_emit_sd(s, 10, 18, 0)             // [hdr+0] = data
    riscv64_emit_sd(s, 0, 18, 8)              // [hdr+8] = len = 0
    riscv64_emit_sd(s, 9, 18, 16)             // [hdr+16] = cap
    riscv64_emit_mv(s, 10, 18)
    riscv64_emit_ld(s, 18, 2, 8)
    riscv64_emit_ld(s, 9, 2, 16)
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)

    // ── __buf_write_byte(a0=buf, a1=byte) -> a0=buf ──
    s.rv_buf_wbyte_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 48)
    riscv64_emit_sd(s, 1, 2, 40)
    riscv64_emit_sd(s, 9, 2, 32)
    riscv64_emit_sd(s, 18, 2, 24)
    riscv64_emit_sd(s, 19, 2, 16)
    riscv64_emit_sd(s, 20, 2, 8)
    riscv64_emit_sd(s, 21, 2, 0)
    riscv64_emit_mv(s, 9, 10)                 // s1 = buf
    riscv64_emit_mv(s, 18, 11)                // s2 = byte
    riscv64_emit_ld(s, 19, 9, 0)              // s3 = data
    riscv64_emit_ld(s, 20, 9, 8)              // s4 = len
    riscv64_emit_ld(s, 21, 9, 16)             // s5 = cap
    riscv64_emit_addi(s, 5, 20, 1)            // len + 1
    blt_bw_ok = s.rv_code.len()
    riscv64_emit_blt(s, 5, 21, 0)
    // Grow cap = cap * 2
    riscv64_emit_slli(s, 21, 21, 1)
    riscv64_emit_mv(s, 10, 21)
    riscv64_synth_emit_call_alloc(s)          // a0 = new_data
    riscv64_emit_li(s, 5, 0)
    bw_cp = s.rv_code.len()
    bge_bw_cp = s.rv_code.len()
    riscv64_emit_bge(s, 5, 20, 0)
    riscv64_emit_add(s, 6, 19, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 6, 10, 5)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, bw_cp - s.rv_code.len())
    bw_cp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_bw_cp, 5, 5, 20, bw_cp_done)
    riscv64_emit_mv(s, 19, 10)
    riscv64_emit_sd(s, 19, 9, 0)
    riscv64_emit_sd(s, 21, 9, 16)
    bw_ok_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_bw_ok, 4, 5, 21, bw_ok_off)
    riscv64_emit_add(s, 5, 19, 20)
    riscv64_emit_sb(s, 18, 5, 0)
    riscv64_emit_sb(s, 0, 5, 1)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_sd(s, 20, 9, 8)
    riscv64_emit_mv(s, 10, 9)
    riscv64_emit_ld(s, 21, 2, 0)
    riscv64_emit_ld(s, 20, 2, 8)
    riscv64_emit_ld(s, 19, 2, 16)
    riscv64_emit_ld(s, 18, 2, 24)
    riscv64_emit_ld(s, 9, 2, 32)
    riscv64_emit_ld(s, 1, 2, 40)
    riscv64_emit_addi(s, 2, 2, 48)
    riscv64_emit_ret(s)

    // ── __buf_write_str(a0=buf, a1=cstr_ptr) -> a0=buf ──
    s.rv_buf_wstr_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_sd(s, 18, 2, 8)
    riscv64_emit_mv(s, 9, 10)                 // s1 = buf
    riscv64_emit_mv(s, 18, 11)                // s2 = cstr_ptr
    bws_loop = s.rv_code.len()
    riscv64_emit_lbu(s, 11, 18, 0)
    beq_bws_done = s.rv_code.len()
    riscv64_emit_beq(s, 11, 0, 0)
    riscv64_emit_mv(s, 10, 9)
    riscv64_emit_jal(s, 1, s.rv_buf_wbyte_off - s.rv_code.len())
    riscv64_emit_addi(s, 18, 18, 1)
    riscv64_emit_jal(s, 0, bws_loop - s.rv_code.len())
    bws_done = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_bws_done, 0, 11, 0, bws_done)
    riscv64_emit_mv(s, 10, 9)
    riscv64_emit_ld(s, 18, 2, 8)
    riscv64_emit_ld(s, 9, 2, 16)
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)

    // ── __buf_to_str(a0=buf) -> a0=new_cstr_ptr ──
    s.rv_buf_tostr_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_sd(s, 18, 2, 8)
    riscv64_emit_ld(s, 9, 10, 0)              // s1 = data
    riscv64_emit_ld(s, 18, 10, 8)             // s2 = len
    riscv64_emit_addi(s, 10, 18, 1)
    riscv64_synth_emit_call_alloc(s)          // a0 = out_str
    riscv64_emit_li(s, 5, 0)
    bts_loop = s.rv_code.len()
    bge_bts = s.rv_code.len()
    riscv64_emit_bge(s, 5, 18, 0)
    riscv64_emit_add(s, 6, 9, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 6, 10, 5)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, bts_loop - s.rv_code.len())
    bts_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_bts, 5, 5, 18, bts_done)
    riscv64_emit_add(s, 6, 10, 18)
    riscv64_emit_sb(s, 0, 6, 0)
    riscv64_emit_ld(s, 18, 2, 8)
    riscv64_emit_ld(s, 9, 2, 16)
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)
    return 0
end

// ── 5. Null-Deref Trap, Tagged Printing & Real LSYM0 Stack Trace (RV64 Parity) ─

fn riscv64_synth_emit_throw_null_helper s
    // WHY: Shared RV64 trap throwing catchable NullPointerException (x26=3 [str tag], x27=msg)
    // on null/low (< 4096) struct or container dereference, matching x86_64 _lipi_throw_null_deref.
    s.rv_throw_null_off = s.rv_code.len()
    riscv64_emit_load_rodata_str(s, 27, "NullPointerException: null struct dereference")
    riscv64_emit_addi(s, 26, 0, 3)            // flag=1 + str_tag(2) = 3
    riscv64_emit_addi(s, 10, 0, 0)
    riscv64_emit_addi(s, 11, 0, 0)
    riscv64_emit_ret(s)
    return 0
end

fn riscv64_emit_null_guard_reg s toks reg
    // WHY: Guards struct/pointer deref in register `reg` against < 4096 in hosted mode.
    // Skipped in --freestanding bare-metal mode where low physical addresses may be valid MMIO.
    if s.rv_freestanding == 1
        return 0
    end
    s.rv_needs_throw_null = 1
    riscv64_emit_li(s, 7, 4096)
    bgeu_ok = s.rv_code.len()
    riscv64_emit_bgeu(s, reg, 7, 0)
    riscv64_synth_emit_call_helper(s, "_lipi_throw_null_deref")
    if s.rv_try_patches.len() > 0
        jmp_c = s.rv_code.len()
        riscv64_emit_jal(s, 0, 0)
        push(s.rv_try_patches[s.rv_try_patches.len() - 1], [jmp_c, 0])
    elif s.rv_in_function == 1
        riscv64_emit_addi(s, 2, 8, 0 - 1024)
        riscv64_emit_defers(s, toks)
        riscv64_emit_epilogue(s)
    else
        s.rv_needs_uncaught_throw = 1
        riscv64_synth_emit_call_helper(s, "__uncaught_throw")
    end
    ok_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bgeu_ok, 7, reg, 7, ok_off)
    return 0
end

fn riscv64_emit_format_float_to_stack s append_nl
    // WHY: Formats IEEE-754 binary64 bits in s1 (x9) into stack buffer starting at s2 (x18 = sp+0..sp+31),
    // using sp+32..sp+63 as digit scratch, leaving s2 pointing past the last written byte.
    // Properly handles NaN (never "-NaN"), Inf, -Inf, 0.0, -0.0, subnormals, and normal values
    // using pure RV64IM integer instructions.
    // abs_bits -> t1 (x6), exp_raw -> s3 (x19), mant_raw -> s4 (x20), bit52 -> t2 (x7)
    riscv64_emit_slli(s, 6, 9, 1)
    riscv64_emit_srli(s, 6, 6, 1)
    riscv64_emit_srli(s, 19, 6, 52)           // s3 = exp_raw (0..2047)
    riscv64_emit_li(s, 7, 1)
    riscv64_emit_slli(s, 7, 7, 52)            // t2 = 1 << 52
    riscv64_emit_addi(s, 5, 7, 0 - 1)         // t0 = (1 << 52) - 1
    riscv64_emit_and(s, 20, 6, 5)             // s4 = mant_raw

    // Special case: exp_raw == 2047 -> NaN (mant != 0) or +/-Inf (mant == 0)
    riscv64_emit_li(s, 5, 2047)
    bne_pf_finite = s.rv_code.len()
    riscv64_emit_bne(s, 19, 5, 0)
    beq_pf_inf = s.rv_code.len()
    riscv64_emit_beq(s, 20, 0, 0)
    // Emit "NaN" (always unsigned)
    riscv64_emit_li(s, 5, 78)                 // 'N'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_li(s, 5, 97)                 // 'a'
    riscv64_emit_sb(s, 5, 18, 1)
    riscv64_emit_li(s, 5, 78)                 // 'N'
    riscv64_emit_sb(s, 5, 18, 2)
    riscv64_emit_addi(s, 18, 18, 3)
    jmp_pf_done_nan = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    // Emit "Inf" or "-Inf"
    pf_inf_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_pf_inf, 0, 20, 0, pf_inf_off)
    riscv64_emit_srli(s, 5, 9, 63)
    beq_pf_pinf = s.rv_code.len()
    riscv64_emit_beq(s, 5, 0, 0)
    riscv64_emit_li(s, 5, 45)                 // '-'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    pf_pinf_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_pf_pinf, 0, 5, 0, pf_pinf_off)
    riscv64_emit_li(s, 5, 73)                 // 'I'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_li(s, 5, 110)                // 'n'
    riscv64_emit_sb(s, 5, 18, 1)
    riscv64_emit_li(s, 5, 102)                // 'f'
    riscv64_emit_sb(s, 5, 18, 2)
    riscv64_emit_addi(s, 18, 18, 3)
    jmp_pf_done_inf = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    // Finite value: check sign bit
    pf_finite_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_pf_finite, 1, 19, 5, pf_finite_off)
    riscv64_emit_srli(s, 5, 9, 63)
    beq_pf_pos = s.rv_code.len()
    riscv64_emit_beq(s, 5, 0, 0)
    riscv64_emit_li(s, 5, 45)                 // '-'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    pf_pos_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_pf_pos, 0, 5, 0, pf_pos_off)

    // Exact zero (exp_raw == 0 && mant_raw == 0) -> "0.0"; subnormal -> pure-integer scientific
    bne_pf_nz = s.rv_code.len()
    riscv64_emit_bne(s, 19, 0, 0)
    bne_pf_subnorm = s.rv_code.len()
    riscv64_emit_bne(s, 20, 0, 0)
    riscv64_emit_li(s, 5, 48)
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_li(s, 5, 46)
    riscv64_emit_sb(s, 5, 18, 1)
    riscv64_emit_li(s, 5, 48)
    riscv64_emit_sb(s, 5, 18, 2)
    riscv64_emit_addi(s, 18, 18, 3)
    jmp_pf_done_zero = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    // Subnormal entry into pure-integer scientific path: m = mant_raw (s5=21), b = -1074 (s3=19)
    pf_subnorm_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_pf_subnorm, 1, 20, 0, pf_subnorm_off)
    riscv64_emit_mv(s, 21, 20)
    riscv64_emit_li(s, 19, 0 - 1074)
    jmp_pf_sci_sub = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    pf_nz_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_pf_nz, 1, 19, 0, pf_nz_off)
    // exp -> s3 (x19), full_mant -> s4 (x20)
    riscv64_emit_addi(s, 19, 19, 0 - 1023)
    riscv64_emit_or(s, 20, 20, 7)
    // WHY: Route extreme magnitudes (exp >= 60 -> >=1.15e18, or exp <= -20 -> <1.9e-6) through
    // pure-integer scientific notation so `full_mant << (exp-52)` never overflows 64 bits and
    // tiny doubles like 1e-8 format identically to x86_64 (`1.0e-8`) with zero FP instructions!
    riscv64_emit_li(s, 5, 60)
    bge_pf_sci_hi = s.rv_code.len()
    riscv64_emit_bge(s, 19, 5, 0)
    riscv64_emit_li(s, 5, 0 - 19)
    blt_pf_sci_lo = s.rv_code.len()
    riscv64_emit_blt(s, 19, 5, 0)
    // Split into int_part (s5=x21) and 32-bit frac (s1=x9) for fixed-point range (-19 <= exp <= 59)
    riscv64_emit_li(s, 5, 52)
    blt_pf_lt52 = s.rv_code.len()
    riscv64_emit_blt(s, 19, 5, 0)
    riscv64_emit_sub(s, 6, 19, 5)
    riscv64_emit_sll(s, 21, 20, 6)
    riscv64_emit_li(s, 9, 0)
    jmp_pf_have1 = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    pf_lt52_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_pf_lt52, 4, 19, 5, pf_lt52_off)
    riscv64_emit_li(s, 5, 20)
    blt_pf_lt20 = s.rv_code.len()
    riscv64_emit_blt(s, 19, 5, 0)
    riscv64_emit_li(s, 5, 52)
    riscv64_emit_sub(s, 6, 5, 19)             // shift = 52 - exp (<= 32)
    riscv64_emit_srl(s, 21, 20, 6)
    riscv64_emit_li(s, 7, 32)
    riscv64_emit_sub(s, 7, 7, 6)
    riscv64_emit_sll(s, 9, 20, 7)
    riscv64_emit_slli(s, 9, 9, 32)
    riscv64_emit_srli(s, 9, 9, 32)
    jmp_pf_have2 = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    pf_lt20_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_pf_lt20, 4, 19, 5, pf_lt20_off)
    blt_pf_neg = s.rv_code.len()
    riscv64_emit_blt(s, 19, 0, 0)
    riscv64_emit_li(s, 5, 52)
    riscv64_emit_sub(s, 6, 5, 19)             // shift = 52 - exp (> 32)
    riscv64_emit_srl(s, 21, 20, 6)
    riscv64_emit_addi(s, 7, 6, 0 - 32)
    riscv64_emit_srl(s, 9, 20, 7)
    riscv64_emit_slli(s, 9, 9, 32)
    riscv64_emit_srli(s, 9, 9, 32)
    jmp_pf_have3 = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    pf_neg_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_pf_neg, 4, 19, 0, pf_neg_off)
    riscv64_emit_li(s, 21, 0)
    riscv64_emit_li(s, 5, 0 - 32)
    blt_pf_tiny = s.rv_code.len()
    riscv64_emit_blt(s, 19, 5, 0)
    riscv64_emit_li(s, 6, 20)
    riscv64_emit_sub(s, 6, 6, 19)             // 20 - exp
    riscv64_emit_srl(s, 9, 20, 6)
    riscv64_emit_slli(s, 9, 9, 32)
    riscv64_emit_srli(s, 9, 9, 32)
    jmp_pf_have4 = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    pf_tiny_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_pf_tiny, 4, 19, 5, pf_tiny_off)
    riscv64_emit_li(s, 9, 0)
    pf_have_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_pf_have1, 0, pf_have_off)
    riscv64_synth_patch_jal(s, jmp_pf_have2, 0, pf_have_off)
    riscv64_synth_patch_jal(s, jmp_pf_have3, 0, pf_have_off)
    riscv64_synth_patch_jal(s, jmp_pf_have4, 0, pf_have_off)
    // dec6 = ((f32 * 1000000) + 2^31) >> 32
    riscv64_emit_li(s, 5, 1000000)
    riscv64_emit_mul(s, 9, 9, 5)
    riscv64_emit_li(s, 6, 1)
    riscv64_emit_slli(s, 6, 6, 31)
    riscv64_emit_add(s, 9, 9, 6)
    riscv64_emit_srli(s, 9, 9, 32)
    blt_pf_nc = s.rv_code.len()
    riscv64_emit_blt(s, 9, 5, 0)
    riscv64_emit_addi(s, 21, 21, 1)
    riscv64_emit_li(s, 9, 0)
    pf_nc_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_pf_nc, 4, 9, 5, pf_nc_off)
    riscv64_emit_li(s, 20, 0)                 // s4 = sci_flag = 0 (fixed-point)
    jmp_pf_to_digits = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)

    // ── Pure-Integer Scientific Notation Path (s5=m, s3=b, s4=d) ────────────
    pf_sci_norm_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_sci_hi, 5, 19, 5, pf_sci_norm_off)
    riscv64_synth_patch_b(s, blt_pf_sci_lo, 4, 19, 5, pf_sci_norm_off)
    riscv64_emit_mv(s, 21, 20)                // s5 = full_mant
    riscv64_emit_addi(s, 19, 19, 0 - 52)      // s3 = b = exp - 52
    pf_sci_entry_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_pf_sci_sub, 0, pf_sci_entry_off)
    riscv64_emit_li(s, 20, 0)                 // s4 = d = 0
    riscv64_emit_li(s, 7, 10)                 // t2 = 10
    // While b > 0: if m >= 2^62 -> m=(m+5)/10, d++ else m<<=1, b--
    riscv64_emit_li(s, 6, 1)
    riscv64_emit_slli(s, 6, 6, 62)            // t1 = 1 << 62
    pf_sb_pos = s.rv_code.len()
    bge_pf_sb_pos = s.rv_code.len()
    riscv64_emit_bge(s, 0, 19, 0)             // if 0 >= b (b <= 0), done
    bltu_pf_sb_shl = s.rv_code.len()
    riscv64_emit_bltu(s, 21, 6, 0)
    riscv64_emit_addi(s, 21, 21, 5)
    riscv64_emit_divu(s, 21, 21, 7)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_jal(s, 0, pf_sb_pos - s.rv_code.len())
    pf_sb_shl_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bltu_pf_sb_shl, 6, 21, 6, pf_sb_shl_off)
    riscv64_emit_slli(s, 21, 21, 1)
    riscv64_emit_addi(s, 19, 19, 0 - 1)
    riscv64_emit_jal(s, 0, pf_sb_pos - s.rv_code.len())
    pf_sb_pos_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_sb_pos, 5, 0, 19, pf_sb_pos_done)
    // While b < 0: if m < 2^59 -> m*=10, d-- else m=(m+1)>>1, b++
    riscv64_emit_li(s, 6, 1)
    riscv64_emit_slli(s, 6, 6, 59)            // t1 = 1 << 59
    pf_sb_neg = s.rv_code.len()
    bge_pf_sb_neg = s.rv_code.len()
    riscv64_emit_bge(s, 19, 0, 0)             // if b >= 0, done
    bgeu_pf_sb_shr = s.rv_code.len()
    riscv64_emit_bgeu(s, 21, 6, 0)
    riscv64_emit_mul(s, 21, 21, 7)
    riscv64_emit_addi(s, 20, 20, 0 - 1)
    riscv64_emit_jal(s, 0, pf_sb_neg - s.rv_code.len())
    pf_sb_shr_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bgeu_pf_sb_shr, 7, 21, 6, pf_sb_shr_off)
    riscv64_emit_addi(s, 21, 21, 1)
    riscv64_emit_srli(s, 21, 21, 1)
    riscv64_emit_addi(s, 19, 19, 1)
    riscv64_emit_jal(s, 0, pf_sb_neg - s.rv_code.len())
    pf_sb_neg_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_sb_neg, 5, 19, 0, pf_sb_neg_done)
    // Normalize m into [1000000, 9999999]
    riscv64_emit_li(s, 6, 10000000)
    pf_sn_hi = s.rv_code.len()
    bltu_pf_sn_hi = s.rv_code.len()
    riscv64_emit_bltu(s, 21, 6, 0)
    riscv64_emit_addi(s, 21, 21, 5)
    riscv64_emit_divu(s, 21, 21, 7)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_jal(s, 0, pf_sn_hi - s.rv_code.len())
    pf_sn_hi_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bltu_pf_sn_hi, 6, 21, 6, pf_sn_hi_done)
    riscv64_emit_li(s, 6, 1000000)
    pf_sn_lo = s.rv_code.len()
    bgeu_pf_sn_lo = s.rv_code.len()
    riscv64_emit_bgeu(s, 21, 6, 0)
    riscv64_emit_mul(s, 21, 21, 7)
    riscv64_emit_addi(s, 20, 20, 0 - 1)
    riscv64_emit_jal(s, 0, pf_sn_lo - s.rv_code.len())
    pf_sn_lo_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bgeu_pf_sn_lo, 7, 21, 6, pf_sn_lo_done)
    // s3 = sci_exp10 = d + 6; s4 = sci_flag = 1; s1 = m % 1000000; s5 = m / 1000000
    riscv64_emit_addi(s, 19, 20, 6)
    riscv64_emit_li(s, 20, 1)
    riscv64_emit_remu(s, 9, 21, 6)
    riscv64_emit_divu(s, 21, 21, 6)

    pf_emit_digits_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_pf_to_digits, 0, pf_emit_digits_off)
    // Convert int_part (s5) into reverse digits at sp+32..sp+63
    riscv64_emit_addi(s, 6, 2, 63)            // t1 = tmp ptr
    riscv64_emit_li(s, 7, 10)
    pf_idig = s.rv_code.len()
    riscv64_emit_remu(s, 5, 21, 7)
    riscv64_emit_addi(s, 5, 5, 48)
    riscv64_emit_sb(s, 5, 6, 0)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_divu(s, 21, 21, 7)
    riscv64_emit_bne(s, 21, 0, pf_idig - s.rv_code.len())
    // Copy int digits forward into s2
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_addi(s, 7, 2, 64)
    pf_icp = s.rv_code.len()
    bge_pf_icp = s.rv_code.len()
    riscv64_emit_bge(s, 6, 7, 0)
    riscv64_emit_lbu(s, 5, 6, 0)
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_jal(s, 0, pf_icp - s.rv_code.len())
    pf_icp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_icp, 5, 6, 7, pf_icp_done)
    // Decimal point '.'
    riscv64_emit_li(s, 5, 46)
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    // Emit 6 fractional digits into sp+32..sp+37
    riscv64_emit_li(s, 6, 5)                  // idx = 5..0
    riscv64_emit_li(s, 7, 10)
    pf_fdig = s.rv_code.len()
    blt_pf_fdig = s.rv_code.len()
    riscv64_emit_blt(s, 6, 0, 0)
    riscv64_emit_remu(s, 5, 9, 7)
    riscv64_emit_addi(s, 5, 5, 48)
    riscv64_emit_addi(s, 28, 2, 32)
    riscv64_emit_add(s, 28, 28, 6)
    riscv64_emit_sb(s, 5, 28, 0)
    riscv64_emit_divu(s, 9, 9, 7)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_jal(s, 0, pf_fdig - s.rv_code.len())
    pf_fdig_done = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_pf_fdig, 4, 6, 0, pf_fdig_done)
    // Trim trailing '0' down to minimum length 1
    riscv64_emit_li(s, 6, 6)                  // len = 6
    riscv64_emit_li(s, 7, 1)
    riscv64_emit_li(s, 29, 48)                // '0'
    pf_trim = s.rv_code.len()
    bge_pf_trim_done = s.rv_code.len()
    riscv64_emit_bge(s, 7, 6, 0)              // if 1 >= len, stop
    riscv64_emit_addi(s, 28, 2, 31)
    riscv64_emit_add(s, 28, 28, 6)
    riscv64_emit_lbu(s, 5, 28, 0)
    bne_pf_trim_done = s.rv_code.len()
    riscv64_emit_bne(s, 5, 29, 0)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_jal(s, 0, pf_trim - s.rv_code.len())
    pf_trim_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_trim_done, 5, 7, 6, pf_trim_done)
    riscv64_synth_patch_b(s, bne_pf_trim_done, 1, 5, 29, pf_trim_done)
    // Copy trimmed frac digits into s2
    riscv64_emit_li(s, 7, 0)
    pf_fcp = s.rv_code.len()
    bge_pf_fcp = s.rv_code.len()
    riscv64_emit_bge(s, 7, 6, 0)
    riscv64_emit_addi(s, 28, 2, 32)
    riscv64_emit_add(s, 28, 28, 7)
    riscv64_emit_lbu(s, 5, 28, 0)
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    riscv64_emit_addi(s, 7, 7, 1)
    riscv64_emit_jal(s, 0, pf_fcp - s.rv_code.len())
    pf_fcp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_fcp, 5, 7, 6, pf_fcp_done)

    // Emit scientific exponent suffix "e+<exp>" / "e-<exp>" when s4 (x20) != 0
    beq_pf_no_exp = s.rv_code.len()
    riscv64_emit_beq(s, 20, 0, 0)
    riscv64_emit_li(s, 5, 101)                // 'e'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    bge_pf_epos = s.rv_code.len()
    riscv64_emit_bge(s, 19, 0, 0)
    riscv64_emit_li(s, 5, 45)                 // '-'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    riscv64_emit_sub(s, 19, 0, 19)            // s3 = -s3
    jmp_pf_esign = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    pf_epos_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_epos, 5, 19, 0, pf_epos_off)
    riscv64_emit_li(s, 5, 43)                 // '+'
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    pf_esign_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_pf_esign, 0, pf_esign_off)
    // Emit unsigned exponent digits (s3) backwards into sp+32..sp+63, then copy forward
    riscv64_emit_addi(s, 6, 2, 63)
    riscv64_emit_li(s, 7, 10)
    pf_edig = s.rv_code.len()
    riscv64_emit_remu(s, 5, 19, 7)
    riscv64_emit_addi(s, 5, 5, 48)
    riscv64_emit_sb(s, 5, 6, 0)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_divu(s, 19, 19, 7)
    riscv64_emit_bne(s, 19, 0, pf_edig - s.rv_code.len())
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_addi(s, 7, 2, 64)
    pf_ecp = s.rv_code.len()
    bge_pf_ecp = s.rv_code.len()
    riscv64_emit_bge(s, 6, 7, 0)
    riscv64_emit_lbu(s, 5, 6, 0)
    riscv64_emit_sb(s, 5, 18, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    riscv64_emit_addi(s, 6, 6, 1)
    riscv64_emit_jal(s, 0, pf_ecp - s.rv_code.len())
    pf_ecp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_pf_ecp, 5, 6, 7, pf_ecp_done)
    riscv64_synth_patch_b(s, beq_pf_no_exp, 0, 20, 0, pf_ecp_done)

    pf_done_off = s.rv_code.len()
    riscv64_synth_patch_jal(s, jmp_pf_done_nan, 0, pf_done_off)
    riscv64_synth_patch_jal(s, jmp_pf_done_inf, 0, pf_done_off)
    riscv64_synth_patch_jal(s, jmp_pf_done_zero, 0, pf_done_off)
    if append_nl == 1
        riscv64_emit_li(s, 5, 10)
        riscv64_emit_sb(s, 5, 18, 0)
        riscv64_emit_addi(s, 18, 18, 1)
    end
    return 0
end

fn riscv64_synth_emit_print_tagged_helpers s
    // WHY: Pure RV64I+M runtime printing for strings, IEEE-754 f64 floats, and dyn_tagged (a0=val, a1=tag).
    // Uses zero FP instructions so binaries execute identically on hardware RV64 and riscv64_vm.lp.

    // ── __print_str(a0=cstr_ptr) ──
    s.rv_print_str_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_mv(s, 9, 10)                 // s1 = ptr
    beq_ps_nl = s.rv_code.len()
    riscv64_emit_beq(s, 9, 0, 0)
    riscv64_emit_li(s, 5, 0)                  // t0 = len
    ps_loop = s.rv_code.len()
    riscv64_emit_add(s, 6, 9, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    beq_ps_w = s.rv_code.len()
    riscv64_emit_beq(s, 7, 0, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, ps_loop - s.rv_code.len())
    ps_w_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_ps_w, 0, 7, 0, ps_w_off)
    beq_ps_nl2 = s.rv_code.len()
    riscv64_emit_beq(s, 5, 0, 0)
    riscv64_emit_li(s, 10, 1)
    riscv64_emit_mv(s, 11, 9)
    riscv64_emit_mv(s, 12, 5)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)
    ps_nl_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_ps_nl, 0, 9, 0, ps_nl_off)
    riscv64_synth_patch_b(s, beq_ps_nl2, 0, 5, 0, ps_nl_off)
    riscv64_emit_li(s, 5, 10)
    riscv64_emit_sb(s, 5, 2, 0)
    riscv64_emit_li(s, 10, 1)
    riscv64_emit_mv(s, 11, 2)
    riscv64_emit_li(s, 12, 1)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)
    riscv64_emit_ld(s, 9, 2, 16)
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)

    // ── __print_float(a0=ieee754_f64_bits) ──
    s.rv_print_float_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 112)
    riscv64_emit_sd(s, 1, 2, 104)
    riscv64_emit_sd(s, 9, 2, 96)
    riscv64_emit_sd(s, 18, 2, 88)
    riscv64_emit_sd(s, 19, 2, 80)
    riscv64_emit_sd(s, 20, 2, 72)
    riscv64_emit_sd(s, 21, 2, 64)
    riscv64_emit_mv(s, 9, 10)                 // s1 = bits
    riscv64_emit_mv(s, 18, 2)                 // s2 = out cursor (starts at sp+0)
    riscv64_emit_format_float_to_stack(s, 1)
    riscv64_emit_sub(s, 12, 18, 2)            // a2 = len
    riscv64_emit_mv(s, 11, 2)                 // a1 = sp
    riscv64_emit_li(s, 10, 1)                 // a0 = stdout
    riscv64_emit_li(s, 17, 64)                // SYS_write
    riscv64_emit_ecall(s)
    riscv64_emit_ld(s, 21, 2, 64)
    riscv64_emit_ld(s, 20, 2, 72)
    riscv64_emit_ld(s, 19, 2, 80)
    riscv64_emit_ld(s, 18, 2, 88)
    riscv64_emit_ld(s, 9, 2, 96)
    riscv64_emit_ld(s, 1, 2, 104)
    riscv64_emit_addi(s, 2, 2, 112)
    riscv64_emit_ret(s)

    // ── __print_tagged(a0=val, a1=tag) -> tail-dispatches to __print_str/float/int ──
    s.rv_print_tagged_off = s.rv_code.len()
    riscv64_emit_li(s, 5, 2)
    bne_pt_not_str = s.rv_code.len()
    riscv64_emit_bne(s, 11, 5, 0)
    riscv64_emit_jal(s, 0, s.rv_print_str_off - s.rv_code.len())
    pt_not_str_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_pt_not_str, 1, 11, 5, pt_not_str_off)
    riscv64_emit_li(s, 5, 1)
    bne_pt_not_flt = s.rv_code.len()
    riscv64_emit_bne(s, 11, 5, 0)
    riscv64_emit_jal(s, 0, s.rv_print_float_off - s.rv_code.len())
    pt_not_flt_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_pt_not_flt, 1, 11, 5, pt_not_flt_off)
    riscv64_emit_addi(s, 2, 2, 0 - 16)
    riscv64_emit_sd(s, 1, 2, 8)
    riscv64_synth_emit_call_print_int(s)
    riscv64_emit_ld(s, 1, 2, 8)
    riscv64_emit_addi(s, 2, 2, 16)
    riscv64_emit_ret(s)
    return 0
end

fn riscv64_synth_emit_str_helpers s
    // WHY: Sovereign pure-RV64IM string conversion & concatenation helpers (zero libc):
    //   __uint_to_str(a0=u64) -> a0=cstr
    //   __int_to_str(a0=i64)  -> a0=cstr (handles 0, negatives, INT64_MIN via divu/remu)
    //   __str_concat(a0=s1, a1=s2) -> a0=cstr
    //   __tagged_to_str(a0=val, a1=tag) -> a0=cstr

    // ── __uint_to_str(a0=uval) -> a0=cstr ──
    s.rv_uint_to_str_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 9, 2, 48)              // s1
    riscv64_emit_sd(s, 18, 2, 40)             // s2
    riscv64_emit_mv(s, 9, 10)                 // s1 = uval
    riscv64_emit_li(s, 28, 10)                // t3 = 10
    riscv64_emit_li(s, 18, 0)                 // s2 = digit count
    bne_ruts_nz = s.rv_code.len()
    riscv64_emit_bne(s, 9, 0, 0)
    riscv64_emit_li(s, 5, 48)                 // '0'
    riscv64_emit_sb(s, 5, 2, 0)
    riscv64_emit_li(s, 18, 1)
    jmp_ruts_alloc = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    ruts_nz_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_ruts_nz, 1, 9, 0, ruts_nz_off)
    ruts_loop = s.rv_code.len()
    beq_ruts_done = s.rv_code.len()
    riscv64_emit_beq(s, 9, 0, 0)
    riscv64_emit_remu(s, 5, 9, 28)
    riscv64_emit_divu(s, 9, 9, 28)
    riscv64_emit_addi(s, 5, 5, 48)
    riscv64_emit_add(s, 6, 2, 18)
    riscv64_emit_sb(s, 5, 6, 0)
    riscv64_emit_addi(s, 18, 18, 1)
    riscv64_emit_jal(s, 0, ruts_loop - s.rv_code.len())
    ruts_alloc_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_ruts_done, 0, 9, 0, ruts_alloc_off)
    riscv64_synth_patch_jal(s, jmp_ruts_alloc, 0, ruts_alloc_off)
    riscv64_emit_addi(s, 10, 18, 1)
    riscv64_synth_emit_call_alloc(s)          // a0 = out_ptr (s2 preserved!)
    riscv64_emit_li(s, 5, 0)                  // t0 = i
    ruts_cp = s.rv_code.len()
    bge_ruts_cp = s.rv_code.len()
    riscv64_emit_bge(s, 5, 18, 0)
    riscv64_emit_sub(s, 6, 18, 5)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_add(s, 6, 2, 6)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 6, 10, 5)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, ruts_cp - s.rv_code.len())
    ruts_cp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_ruts_cp, 5, 5, 18, ruts_cp_done)
    riscv64_emit_add(s, 6, 10, 18)
    riscv64_emit_sb(s, 0, 6, 0)
    riscv64_emit_ld(s, 18, 2, 40)
    riscv64_emit_ld(s, 9, 2, 48)
    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)

    // ── __int_to_str(a0=val) -> a0=cstr ──
    s.rv_int_to_str_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 9, 2, 48)              // s1 = uval / count
    riscv64_emit_sd(s, 18, 2, 40)             // s2 = is_neg
    riscv64_emit_li(s, 18, 0)
    riscv64_emit_mv(s, 9, 10)
    bge_rits_pos = s.rv_code.len()
    riscv64_emit_bge(s, 10, 0, 0)
    riscv64_emit_li(s, 18, 1)
    riscv64_emit_sub(s, 9, 0, 10)             // s1 = 0 - a0 (exact unsigned abs even for INT64_MIN)
    rits_pos_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_rits_pos, 5, 10, 0, rits_pos_off)
    riscv64_emit_li(s, 28, 10)                // t3 = 10
    riscv64_emit_li(s, 29, 0)                 // t4 = digit count
    bne_rits_nz = s.rv_code.len()
    riscv64_emit_bne(s, 9, 0, 0)
    riscv64_emit_li(s, 5, 48)
    riscv64_emit_sb(s, 5, 2, 0)
    riscv64_emit_li(s, 29, 1)
    jmp_rits_alloc = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    rits_nz_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_rits_nz, 1, 9, 0, rits_nz_off)
    rits_loop = s.rv_code.len()
    beq_rits_done = s.rv_code.len()
    riscv64_emit_beq(s, 9, 0, 0)
    riscv64_emit_remu(s, 5, 9, 28)
    riscv64_emit_divu(s, 9, 9, 28)
    riscv64_emit_addi(s, 5, 5, 48)
    riscv64_emit_add(s, 6, 2, 29)
    riscv64_emit_sb(s, 5, 6, 0)
    riscv64_emit_addi(s, 29, 29, 1)
    riscv64_emit_jal(s, 0, rits_loop - s.rv_code.len())
    rits_alloc_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_rits_done, 0, 9, 0, rits_alloc_off)
    riscv64_synth_patch_jal(s, jmp_rits_alloc, 0, rits_alloc_off)
    riscv64_emit_mv(s, 9, 29)                 // s1 = digit count (preserved across __alloc!)
    riscv64_emit_add(s, 10, 9, 18)
    riscv64_emit_addi(s, 10, 10, 1)
    riscv64_synth_emit_call_alloc(s)          // a0 = out_ptr
    riscv64_emit_li(s, 28, 0)                 // t3 = write offset
    beq_rits_nosign = s.rv_code.len()
    riscv64_emit_beq(s, 18, 0, 0)
    riscv64_emit_li(s, 5, 45)                 // '-'
    riscv64_emit_sb(s, 5, 10, 0)
    riscv64_emit_li(s, 28, 1)
    rits_nosign_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_rits_nosign, 0, 18, 0, rits_nosign_off)
    riscv64_emit_li(s, 5, 0)                  // t0 = i
    rits_cp = s.rv_code.len()
    bge_rits_cp = s.rv_code.len()
    riscv64_emit_bge(s, 5, 9, 0)
    riscv64_emit_sub(s, 6, 9, 5)
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_add(s, 6, 2, 6)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 6, 28, 5)
    riscv64_emit_add(s, 6, 10, 6)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, rits_cp - s.rv_code.len())
    rits_cp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_rits_cp, 5, 5, 9, rits_cp_done)
    riscv64_emit_add(s, 6, 28, 9)
    riscv64_emit_add(s, 6, 10, 6)
    riscv64_emit_sb(s, 0, 6, 0)
    riscv64_emit_ld(s, 18, 2, 40)
    riscv64_emit_ld(s, 9, 2, 48)
    riscv64_emit_ld(s, 1, 2, 56)
    riscv64_emit_addi(s, 2, 2, 64)
    riscv64_emit_ret(s)

    // ── __str_concat(a0=s1, a1=s2) -> a0=cstr ──
    s.rv_str_concat_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 48)
    riscv64_emit_sd(s, 1, 2, 40)
    riscv64_emit_sd(s, 9, 2, 32)              // s1 = str1
    riscv64_emit_sd(s, 18, 2, 24)             // s2 = str2
    riscv64_emit_sd(s, 19, 2, 16)             // s3 = len1
    riscv64_emit_sd(s, 20, 2, 8)              // s4 = len2
    riscv64_emit_mv(s, 9, 10)
    riscv64_emit_mv(s, 18, 11)
    riscv64_emit_li(s, 19, 0)
    beq_rsc_l1d = s.rv_code.len()
    riscv64_emit_beq(s, 9, 0, 0)
    rsc_l1 = s.rv_code.len()
    riscv64_emit_add(s, 6, 9, 19)
    riscv64_emit_lbu(s, 7, 6, 0)
    beq_rsc_l1d2 = s.rv_code.len()
    riscv64_emit_beq(s, 7, 0, 0)
    riscv64_emit_addi(s, 19, 19, 1)
    riscv64_emit_jal(s, 0, rsc_l1 - s.rv_code.len())
    rsc_l1_done = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_rsc_l1d, 0, 9, 0, rsc_l1_done)
    riscv64_synth_patch_b(s, beq_rsc_l1d2, 0, 7, 0, rsc_l1_done)
    riscv64_emit_li(s, 20, 0)
    beq_rsc_l2d = s.rv_code.len()
    riscv64_emit_beq(s, 18, 0, 0)
    rsc_l2 = s.rv_code.len()
    riscv64_emit_add(s, 6, 18, 20)
    riscv64_emit_lbu(s, 7, 6, 0)
    beq_rsc_l2d2 = s.rv_code.len()
    riscv64_emit_beq(s, 7, 0, 0)
    riscv64_emit_addi(s, 20, 20, 1)
    riscv64_emit_jal(s, 0, rsc_l2 - s.rv_code.len())
    rsc_l2_done = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_rsc_l2d, 0, 18, 0, rsc_l2_done)
    riscv64_synth_patch_b(s, beq_rsc_l2d2, 0, 7, 0, rsc_l2_done)
    riscv64_emit_add(s, 10, 19, 20)
    riscv64_emit_addi(s, 10, 10, 1)
    riscv64_synth_emit_call_alloc(s)          // a0 = out
    riscv64_emit_li(s, 5, 0)
    rsc_cp1 = s.rv_code.len()
    bge_rsc_cp1 = s.rv_code.len()
    riscv64_emit_bge(s, 5, 19, 0)
    riscv64_emit_add(s, 6, 9, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 6, 10, 5)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, rsc_cp1 - s.rv_code.len())
    rsc_cp1_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_rsc_cp1, 5, 5, 19, rsc_cp1_done)
    riscv64_emit_li(s, 5, 0)
    rsc_cp2 = s.rv_code.len()
    bge_rsc_cp2 = s.rv_code.len()
    riscv64_emit_bge(s, 5, 20, 0)
    riscv64_emit_add(s, 6, 18, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 28, 19, 5)
    riscv64_emit_add(s, 6, 10, 28)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, rsc_cp2 - s.rv_code.len())
    rsc_cp2_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_rsc_cp2, 5, 5, 20, rsc_cp2_done)
    riscv64_emit_add(s, 28, 19, 20)
    riscv64_emit_add(s, 6, 10, 28)
    riscv64_emit_sb(s, 0, 6, 0)
    riscv64_emit_ld(s, 20, 2, 8)
    riscv64_emit_ld(s, 19, 2, 16)
    riscv64_emit_ld(s, 18, 2, 24)
    riscv64_emit_ld(s, 9, 2, 32)
    riscv64_emit_ld(s, 1, 2, 40)
    riscv64_emit_addi(s, 2, 2, 48)
    riscv64_emit_ret(s)

    // ── __float_to_str(a0=ieee754_f64_bits) -> a0=cstr ──
    s.rv_float_to_str_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 112)
    riscv64_emit_sd(s, 1, 2, 104)
    riscv64_emit_sd(s, 9, 2, 96)
    riscv64_emit_sd(s, 18, 2, 88)
    riscv64_emit_sd(s, 19, 2, 80)
    riscv64_emit_sd(s, 20, 2, 72)
    riscv64_emit_sd(s, 21, 2, 64)
    riscv64_emit_mv(s, 9, 10)                 // s1 = bits
    riscv64_emit_mv(s, 18, 2)                 // s2 = sp+0
    riscv64_emit_format_float_to_stack(s, 0)
    riscv64_emit_sub(s, 19, 18, 2)            // s3 = formatted byte len
    riscv64_emit_addi(s, 10, 19, 1)
    riscv64_synth_emit_call_alloc(s)          // a0 = out_ptr
    riscv64_emit_li(s, 5, 0)
    rfts_cp = s.rv_code.len()
    bge_rfts_cp = s.rv_code.len()
    riscv64_emit_bge(s, 5, 19, 0)
    riscv64_emit_add(s, 6, 2, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    riscv64_emit_add(s, 6, 10, 5)
    riscv64_emit_sb(s, 7, 6, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, rfts_cp - s.rv_code.len())
    rfts_cp_done = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_rfts_cp, 5, 5, 19, rfts_cp_done)
    riscv64_emit_add(s, 6, 10, 19)
    riscv64_emit_sb(s, 0, 6, 0)
    riscv64_emit_ld(s, 21, 2, 64)
    riscv64_emit_ld(s, 20, 2, 72)
    riscv64_emit_ld(s, 19, 2, 80)
    riscv64_emit_ld(s, 18, 2, 88)
    riscv64_emit_ld(s, 9, 2, 96)
    riscv64_emit_ld(s, 1, 2, 104)
    riscv64_emit_addi(s, 2, 2, 112)
    riscv64_emit_ret(s)

    // ── __tagged_to_str(a0=val, a1=tag) -> a0=cstr ──
    s.rv_tagged_to_str_off = s.rv_code.len()
    riscv64_emit_li(s, 5, 2)
    bne_rtts_chk_flt = s.rv_code.len()
    riscv64_emit_bne(s, 11, 5, 0)
    riscv64_emit_ret(s)                       // tag == 2: already cstr in a0
    rtts_chk_flt_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_rtts_chk_flt, 1, 11, 5, rtts_chk_flt_off)
    riscv64_emit_li(s, 5, 1)
    bne_rtts_int = s.rv_code.len()
    riscv64_emit_bne(s, 11, 5, 0)
    riscv64_emit_jal(s, 0, s.rv_float_to_str_off - s.rv_code.len())
    rtts_int_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bne_rtts_int, 1, 11, 5, rtts_int_off)
    riscv64_emit_jal(s, 0, s.rv_int_to_str_off - s.rv_code.len())
    return 0
end

fn riscv64_synth_emit_uncaught_throw_helper s
    // WHY: Hosted-mode uncaught exception handler (x26=tag+1, x27=val): formats payload via
    // __tagged_to_str, writes "Uncaught exception: <val>\n" to stderr (fd 2), and exits with code 1
    // (exact x86_64 parity; never exits 0 on `throw 0`).
    s.rv_uncaught_throw_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_mv(s, 10, 27)
    riscv64_emit_addi(s, 11, 26, 0 - 1)       // a1 = tag (0=int, 1=float, 2=str)
    riscv64_synth_emit_call_helper(s, "__tagged_to_str")
    riscv64_emit_mv(s, 9, 10)                 // s1 = formatted cstr
    // Write prefix "Uncaught exception: " (20 bytes) to stderr (fd 2)
    riscv64_emit_li(s, 10, 2)
    riscv64_emit_load_rodata_str(s, 11, "Uncaught exception: ")
    riscv64_emit_li(s, 12, 20)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)
    // Compute strlen(s1) in t0 (x5) and write value to stderr (fd 2)
    beq_rut_nl = s.rv_code.len()
    riscv64_emit_beq(s, 9, 0, 0)
    riscv64_emit_li(s, 5, 0)
    rut_len_loop = s.rv_code.len()
    riscv64_emit_add(s, 6, 9, 5)
    riscv64_emit_lbu(s, 7, 6, 0)
    beq_rut_write = s.rv_code.len()
    riscv64_emit_beq(s, 7, 0, 0)
    riscv64_emit_addi(s, 5, 5, 1)
    riscv64_emit_jal(s, 0, rut_len_loop - s.rv_code.len())
    rut_write_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_rut_write, 0, 7, 0, rut_write_off)
    beq_rut_nl2 = s.rv_code.len()
    riscv64_emit_beq(s, 5, 0, 0)
    riscv64_emit_li(s, 10, 2)
    riscv64_emit_mv(s, 11, 9)
    riscv64_emit_mv(s, 12, 5)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)
    rut_nl_off = s.rv_code.len()
    riscv64_synth_patch_b(s, beq_rut_nl, 0, 9, 0, rut_nl_off)
    riscv64_synth_patch_b(s, beq_rut_nl2, 0, 5, 0, rut_nl_off)
    // Write trailing '\n' to stderr (fd 2)
    riscv64_emit_li(s, 5, 10)
    riscv64_emit_sb(s, 5, 2, 0)
    riscv64_emit_li(s, 10, 2)
    riscv64_emit_mv(s, 11, 2)
    riscv64_emit_li(s, 12, 1)
    riscv64_emit_li(s, 17, 64)
    riscv64_emit_ecall(s)
    // Exit process with status code 1 via Linux SYS_exit_group (94)
    riscv64_emit_li(s, 10, 1)
    riscv64_emit_li(s, 17, 94)
    riscv64_emit_ecall(s)
    return 0
end

fn riscv64_synth_emit_stack_trace_helper s
    // WHY: Real RV64 frame-pointer walker resolving live call chain against LSYM0 .rodata table
    // into "  at <fn_name> (line <decl_line>)\n" — exact x86_64 stack_trace() parity!
    s.rv_stack_trace_off = s.rv_code.len()
    riscv64_emit_addi(s, 2, 2, 0 - 128)
    riscv64_emit_sd(s, 1, 2, 120)
    riscv64_emit_sd(s, 8, 2, 112)
    riscv64_emit_sd(s, 9, 2, 104)
    riscv64_emit_sd(s, 18, 2, 96)
    riscv64_emit_sd(s, 19, 2, 88)
    riscv64_emit_sd(s, 20, 2, 80)
    riscv64_emit_sd(s, 21, 2, 72)
    riscv64_emit_sd(s, 22, 2, 64)
    riscv64_emit_sd(s, 23, 2, 56)
    riscv64_emit_sd(s, 24, 2, 48)
    riscv64_emit_sd(s, 25, 2, 40)
    // Capture immediate caller PC (ra) and frame pointer (s0)
    riscv64_emit_mv(s, 9, 1)                  // s1 = cur_pc
    riscv64_emit_mv(s, 18, 8)                 // s2 = cur_fp
    // Allocate ByteBuffer for trace string
    riscv64_emit_li(s, 10, 256)
    riscv64_synth_emit_call_helper(s, "__buf_new")
    riscv64_emit_mv(s, 19, 10)                // s3 = buf
    // Load patched LSYM0 table, code_base, rodata_base virtual addresses
    s.rv_lsym_patch_lsym = s.rv_code.len()
    riscv64_emit_lui(s, 20, 0)
    riscv64_emit_addi(s, 20, 20, 0)           // s4 = lsym_vaddr
    s.rv_lsym_patch_code = s.rv_code.len()
    riscv64_emit_lui(s, 21, 0)
    riscv64_emit_addi(s, 21, 21, 0)           // s5 = code_base_vaddr
    s.rv_lsym_patch_ro = s.rv_code.len()
    riscv64_emit_lui(s, 22, 0)
    riscv64_emit_addi(s, 22, 22, 0)           // s6 = rodata_base_vaddr
    riscv64_emit_li(s, 23, 0)                 // s7 = depth = 0
    // Walk up to 16 stack frames
    st_frame_loop = s.rv_code.len()
    riscv64_emit_li(s, 5, 16)
    bge_st_done1 = s.rv_code.len()
    riscv64_emit_bge(s, 23, 5, 0)
    bltu_st_skip = s.rv_code.len()
    riscv64_emit_bltu(s, 9, 21, 0)            // skip if pc < code_base
    riscv64_emit_sub(s, 24, 9, 21)
    riscv64_emit_addi(s, 24, 24, 0 - 4)       // s8 = rel_pc of call site
    // Linear scan LSYM0 entries: fcnt = lwu 8(s4), entries start at s4 + 16, stride 24
    riscv64_emit_lwu(s, 5, 20, 8)             // t0 = fcnt
    riscv64_emit_li(s, 25, 0)                 // s9 = i = 0
    st_sym_loop = s.rv_code.len()
    bge_st_sym_done = s.rv_code.len()
    riscv64_emit_bge(s, 25, 5, 0)
    riscv64_emit_li(s, 6, 24)
    riscv64_emit_mul(s, 6, 25, 6)
    riscv64_emit_addi(s, 6, 6, 16)
    riscv64_emit_add(s, 6, 20, 6)             // t1 = &entry[i]
    riscv64_emit_lwu(s, 7, 6, 0)              // start_off
    bltu_st_sym_next1 = s.rv_code.len()
    riscv64_emit_bltu(s, 24, 7, 0)
    riscv64_emit_lwu(s, 7, 6, 4)              // end_off
    bgeu_st_sym_next2 = s.rv_code.len()
    riscv64_emit_bgeu(s, 24, 7, 0)
    // Matched function! Extract name_ptr (s9) and decl_line (s8)
    riscv64_emit_lwu(s, 7, 6, 8)              // name_ro_off
    riscv64_emit_add(s, 25, 22, 7)            // s9 = rodata_base + name_ro_off
    riscv64_emit_lwu(s, 24, 6, 12)            // s8 = decl_line
    // Append "  at " + name + " (line " + dec(decl_line) + ")\n"
    riscv64_emit_mv(s, 10, 19)
    riscv64_emit_load_rodata_str(s, 11, "  at ")
    riscv64_synth_emit_call_helper(s, "__buf_write_str")
    riscv64_emit_mv(s, 10, 19)
    riscv64_emit_mv(s, 11, 25)
    riscv64_synth_emit_call_helper(s, "__buf_write_str")
    riscv64_emit_mv(s, 10, 19)
    riscv64_emit_load_rodata_str(s, 11, " (line ")
    riscv64_synth_emit_call_helper(s, "__buf_write_str")
    // Format decl_line (s8) backwards into sp+0..sp+31 (null-terminated at sp+31)
    riscv64_emit_addi(s, 6, 2, 31)
    riscv64_emit_sb(s, 0, 6, 0)
    riscv64_emit_li(s, 7, 10)
    st_ldig = s.rv_code.len()
    riscv64_emit_addi(s, 6, 6, 0 - 1)
    riscv64_emit_remu(s, 5, 24, 7)
    riscv64_emit_addi(s, 5, 5, 48)
    riscv64_emit_sb(s, 5, 6, 0)
    riscv64_emit_divu(s, 24, 24, 7)
    riscv64_emit_bne(s, 24, 0, st_ldig - s.rv_code.len())
    riscv64_emit_mv(s, 10, 19)
    riscv64_emit_mv(s, 11, 6)
    riscv64_synth_emit_call_helper(s, "__buf_write_str")
    riscv64_emit_mv(s, 10, 19)
    riscv64_emit_load_rodata_str(s, 11, ")\n")
    riscv64_synth_emit_call_helper(s, "__buf_write_str")
    jmp_st_next_frame = s.rv_code.len()
    riscv64_emit_jal(s, 0, 0)
    st_sym_next_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bltu_st_sym_next1, 6, 24, 7, st_sym_next_off)
    riscv64_synth_patch_b(s, bgeu_st_sym_next2, 7, 24, 7, st_sym_next_off)
    riscv64_emit_addi(s, 25, 25, 1)
    riscv64_emit_jal(s, 0, st_sym_loop - s.rv_code.len())
    st_next_frame_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bltu_st_skip, 6, 9, 21, st_next_frame_off)
    riscv64_synth_patch_b(s, bge_st_sym_done, 5, 25, 5, st_next_frame_off)
    riscv64_synth_patch_jal(s, jmp_st_next_frame, 0, st_next_frame_off)
    // Advance to caller frame: pc = [fp - 8], fp = [fp - 16]
    beq_st_done2 = s.rv_code.len()
    riscv64_emit_beq(s, 18, 0, 0)
    riscv64_emit_andi(s, 5, 18, 7)
    bne_st_done3 = s.rv_code.len()
    riscv64_emit_bne(s, 5, 0, 0)
    riscv64_emit_ld(s, 9, 18, 0 - 8)
    riscv64_emit_ld(s, 6, 18, 0 - 16)
    beq_st_done4 = s.rv_code.len()
    riscv64_emit_beq(s, 6, 18, 0)
    riscv64_emit_mv(s, 18, 6)
    riscv64_emit_addi(s, 23, 23, 1)
    riscv64_emit_jal(s, 0, st_frame_loop - s.rv_code.len())
    st_done_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_st_done1, 5, 23, 5, st_done_off)
    riscv64_synth_patch_b(s, beq_st_done2, 0, 18, 0, st_done_off)
    riscv64_synth_patch_b(s, bne_st_done3, 1, 5, 0, st_done_off)
    riscv64_synth_patch_b(s, beq_st_done4, 0, 6, 18, st_done_off)
    riscv64_emit_mv(s, 10, 19)
    riscv64_synth_emit_call_helper(s, "__buf_to_str")
    riscv64_emit_ld(s, 25, 2, 40)
    riscv64_emit_ld(s, 24, 2, 48)
    riscv64_emit_ld(s, 23, 2, 56)
    riscv64_emit_ld(s, 22, 2, 64)
    riscv64_emit_ld(s, 21, 2, 72)
    riscv64_emit_ld(s, 20, 2, 80)
    riscv64_emit_ld(s, 19, 2, 88)
    riscv64_emit_ld(s, 18, 2, 96)
    riscv64_emit_ld(s, 9, 2, 104)
    riscv64_emit_ld(s, 8, 2, 112)
    riscv64_emit_ld(s, 1, 2, 120)
    riscv64_emit_addi(s, 2, 2, 128)
    riscv64_emit_ret(s)
    return 0
end
