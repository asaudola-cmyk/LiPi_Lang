// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 FEATURE PARITY RUNTIME (runtime_parity.lp)
// ⚡ 100% Pure Lipi | Zero C | Zero Libc | Direct AArch64 Silicon Synthesis
// 🏛️ File: src/compiler/backend/targets/arm64/runtime_parity.lp
//
// WHY THIS MODULE:
// Brings full x86_64 feature parity directly to the ARM64 (AArch64) Linux ELF64
// AND macOS Apple Silicon Mach-O backends:
//   1. First-Class Closures (`CLOS` magic 0x434C4F53, PC-relative ADR so code ptrs
//      work identically on Linux 0x4000E8 and macOS 0x100004000, env reg X10,
//      mutable boxed upvalue cells, indirect BLR X11).
//   2. Native `DICT0` HashMap Runtime (32B header with magic 0x44494354 at [+24],
//      FNV-1a string & integer hashing, open addressing with linear probing &
//      automatic 2x rehash, unified container indexing for both lists and dicts).
//   3. Native `ByteBuffer` Runtime (growable 24B {data_ptr, len, cap}, buf_new,
//      buf_write_byte, buf_write_str, buf_to_str, buf_len, buf_ptr, buf_clear).
//   4. LIFO `defer` Statement Replay across `return`, `throw`, and function exit.
// ==============================================================================

fn arm64_emit_blr s rn
    // WHY: `blr x<rn>` (0xD63F0000 | (rn << 5)). Indirect subroutine call.
    arm64_synth_emit32(s, 3594452992 | ((rn & 31) << 5))
    return 0
end

fn arm64_emit_adr s rd byte_delta
    // WHY: PC-relative `adr x<rd>, #byte_delta` (0x10000000 | immlo<<29 | immhi<<5 | rd).
    // Works identically across Linux ELF64 (0x4000E8) and macOS Mach-O (0x100004000).
    d = byte_delta & 2097151
    immlo = d & 3
    immhi = (d >> 2) & 524287
    arm64_synth_emit32(s, 268435456 | (immlo << 29) | (immhi << 5) | (rd & 31))
    return 0
end

fn arm64_emit_ldr_x_off s rt rn byte_off
    scaled = (byte_off / 8) & 4095
    arm64_synth_emit32(s, 4181721088 | (scaled << 10) | ((rn & 31) << 5) | (rt & 31))
    return 0
end

fn arm64_emit_ldr_w_off s rt rn byte_off
    // WHY: `ldr w<rt>, [x<rn>, #byte_off]` (0xB9400000) — unsigned 32-bit zero-extending load for LSYM0.
    scaled = (byte_off / 4) & 4095
    arm64_synth_emit32(s, 3107979264 | (scaled << 10) | ((rn & 31) << 5) | (rt & 31))
    return 0
end

fn arm64_emit_str_x_off s rt rn byte_off
    scaled = (byte_off / 8) & 4095
    arm64_synth_emit32(s, 4177526784 | (scaled << 10) | ((rn & 31) << 5) | (rt & 31))
    return 0
end

fn arm64_emit_ldrb_off s rt rn byte_off
    arm64_synth_emit32(s, 960495616 | ((byte_off & 4095) << 10) | ((rn & 31) << 5) | (rt & 31))
    return 0
end

fn arm64_emit_strb_off s rt rn byte_off
    arm64_synth_emit32(s, 956301312 | ((byte_off & 4095) << 10) | ((rn & 31) << 5) | (rt & 31))
    return 0
end

fn arm64_emit_add_imm s rd rn imm12
    arm64_synth_emit32(s, 2432696320 | ((imm12 & 4095) << 10) | ((rn & 31) << 5) | (rd & 31))
    return 0
end

fn arm64_emit_sub_imm s rd rn imm12
    arm64_synth_emit32(s, 3506438144 | ((imm12 & 4095) << 10) | ((rn & 31) << 5) | (rd & 31))
    return 0
end

fn arm64_patch_b s patch_off target_off
    w = (target_off - patch_off) / 4
    arm64_synth_patch_u32(s, patch_off, 335544320 | (w & 67108863))
    return 0
end

fn arm64_patch_b_cond s patch_off cond target_off
    w = (target_off - patch_off) / 4
    arm64_synth_patch_u32(s, patch_off, 1409286144 | ((w & 524287) << 5) | (cond & 15))
    return 0
end

fn arm64_synth_emit_call_helper s hname
    call_off = s.synth_code.len()
    arm64_emit_bl(s, 0)
    cr = Arm64CallReloc()
    cr.a64_cr_patch_offset = call_off
    cr.a64_cr_target_name = hname
    push(s.synth_call_relocs, cr)
    return 0
end

fn arm64_is_boxed_name s name
    if s.a64_boxed_vars == 0 return 0 end
    i = 0
    while i < s.a64_boxed_vars.len()
        if s.a64_boxed_vars[i] == name return 1 end
        i = i + 1
    end
    return 0
end

fn arm64_find_local_var s name
    i = 0
    while i < s.synth_locals.len()
        if s.synth_locals[i].lv_name == name
            return s.synth_locals[i]
        end
        i = i + 1
    end
    return 0
end

fn arm64_is_block_end toks p
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

fn arm64_is_compound_assign_tok tok
    k = tok.tok_kind
    tx = tok.tok_text
    if k == TOK_PLUSEQ() or tx == "+=" return TOK_PLUS() end
    if k == TOK_MINUSEQ() or tx == "-=" return TOK_MINUS() end
    if k == TOK_STAREQ() or tx == "*=" return TOK_STAR() end
    if k == TOK_SLASHEQ() or tx == "/=" return TOK_SLASH() end
    if k == TOK_PERCENTEQ() or tx == "%=" return TOK_PERCENT() end
    return 0
end

fn arm64_prescan_boxed_vars toks start_pos base_col base_line
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
            if arm64_is_block_end(toks, i) == 1 and t.tok_span.span_start_col <= base_col
                break
            end
            if t.tok_span.span_start_line > base_line and t.tok_span.span_start_col <= base_col and k != TOK_NEWLINE() and k != TOK_SEMI() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_DOC() and k != TOK_COMMENT_BLOCK()
                break
            end
        end
        if (k == TOK_KW_FN() or k == TOK_DIR_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn"))) and i + 1 < n and toks[i + 1].tok_kind == TOK_IDENT()
            break
        end
        is_clos = 0
        cp = i
        c_params = list()
        if (k == TOK_KW_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ"))) and i + 1 < n and (toks[i + 1].tok_kind == TOK_LPAREN() or toks[i + 1].tok_text == "(")
            is_clos = 1
            cp = i + 2
            while cp < n and toks[cp].tok_kind != TOK_RPAREN() and toks[cp].tok_text != ")"
                if arm64_is_ident_token(toks[cp].tok_kind) == 1
                    push(c_params, toks[cp].tok_text)
                end
                cp = cp + 1
            end
            if cp < n cp = cp + 1 end
        elif k == TOK_BAR() or (k != TOK_STR() and txt == "|")
            sp = i + 1
            ok_bar = 1
            while sp < n and toks[sp].tok_kind != TOK_BAR() and toks[sp].tok_text != "|"
                if arm64_is_ident_token(toks[sp].tok_kind) == 1
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
                while b_end < n and toks[b_end].tok_kind != TOK_EOF()
                    if toks[b_end].tok_kind == TOK_NEWLINE() or toks[b_end].tok_kind == TOK_SEMI()
                        break
                    end
                    if arm64_is_block_end(toks, b_end) == 1
                        b_end = b_end + 1
                        break
                    end
                    b_end = b_end + 1
                end
            end
            sc = cp
            while sc + 1 < b_end
                if toks[sc].tok_kind == TOK_IDENT()
                    vn = toks[sc].tok_text
                    nt = toks[sc + 1]
                    if nt.tok_kind == TOK_ASSIGN() or nt.tok_text == "=" or arm64_is_compound_assign_tok(nt) != 0
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
fn arm64_emit_defers s toks
    if s.a64_emitting_defer == 1 or s.a64_defer_starts.len() == 0
        return 0
    end
    // WHY: Preserve BOTH return value (`x0`) AND dynamic return type tag (`x1`) across
    // deferred statements so cleanup calls cannot clobber `x1` before epilogue return!
    s.a64_emitting_defer = 1
    ret_save_off = arm64_synth_alloc_var(s, "__a64_defer_ret")
    tag_save_off = arm64_synth_alloc_var(s, "__a64_defer_tag")
    arm64_emit_str_reg_sp(s, 0, ret_save_off)
    arm64_emit_str_reg_sp(s, 1, tag_save_off)
    di = s.a64_defer_starts.len() - 1
    while di >= 0
        d_pos = [s.a64_defer_starts[di]]
        d_end = s.a64_defer_ends[di]
        while get(d_pos, 0) < d_end
            arm64_synth_skip_whitespace_tokens(toks, d_pos)
            cur_d = get(d_pos, 0)
            if cur_d >= d_end break end
            arm64_synth_compile_statement(s, toks, d_pos)
            if get(d_pos, 0) <= cur_d list_set(d_pos, 0, cur_d + 1) end
        end
        di = di - 1
    end
    arm64_emit_ldr_reg_sp(s, 0, ret_save_off)
    arm64_emit_ldr_reg_sp(s, 1, tag_save_off)
    s.a64_emitting_defer = 0
    return 0
end

// ── 2. Indirect Call / Closure Dispatch on X11 ────────────────────────────────
fn arm64_emit_indirect_call_x11 s
    // WHY: Dispatches BOTH raw function pointers AND heap `CLOS` objects (magic 0x434C4F53 at [X11+0]).
    // If CLOS, passes closure pointer in X10 and loads code pointer from [X11+8] before BLR X11.
    arm64_emit_ldr_x_off(s, 12, 11, 0)       // X12 = [X11 + 0]
    arm64_emit_mov_imm64(s, 13, 1129074515)  // X13 = 0x434C4F53 ('CLOS')
    arm64_emit_cmp_x(s, 12, 13)
    bne_raw = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)               // b.ne raw_call
    arm64_emit_mov_reg(s, 10, 11)            // X10 (env reg) = closure_ptr
    arm64_emit_ldr_x_off(s, 11, 11, 8)       // X11 = code_ptr
    raw_call_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_raw, 1, raw_call_off)
    arm64_emit_blr(s, 11)                    // blr x11
    return 0
end

// ── 3. First-Class Closure Literal Compiler (PC-Relative ADR) ─────────────────
fn arm64_emit_closure_literal s toks pos_box c_params
    // WHY: Compiles `fn(p...) { ... }`, `fn(p...) => expr`, or `|p...| => expr`
    // into an inline skipped AArch64 function body + heap `CLOS` object using PC-relative ADR.
    arm64_synth_skip_whitespace_tokens(toks, pos_box)
    c_mode = 0
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_FAT_ARROW() or toks[get(pos_box, 0)].tok_text == "=>")
        list_set(pos_box, 0, get(pos_box, 0) + 1)
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
    end
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
        c_mode = 1
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end

    cap_names = list()
    cap_offs = list()
    cap_boxed = list()
    li = 0
    while li < s.synth_locals.len()
        lv = s.synth_locals[li]
        is_shadow = 0
        pi = 0
        while pi < c_params.len()
            if c_params[pi] == lv.lv_name is_shadow = 1 break end
            pi = pi + 1
        end
        if is_shadow == 0
            push(cap_names, lv.lv_name)
            push(cap_offs, lv.lv_offset)
            push(cap_boxed, lv.a64_lv_is_boxed)
        end
        li = li + 1
    end

    jmp_over = s.synth_code.len()
    arm64_emit_b(s, 0)

    body_entry_off = s.synth_code.len()
    saved_locals = s.synth_locals
    saved_stack_off = s.synth_stack_offset
    saved_sp_delta = s.a64_sp_delta
    saved_in_fn = s.a64_in_function
    saved_try = s.a64_try_patches
    saved_boxed = s.a64_boxed_vars
    saved_ds = s.a64_defer_starts
    saved_de = s.a64_defer_ends
    s.synth_locals = list()
    s.synth_stack_offset = 16
    s.a64_sp_delta = 0
    s.a64_in_function = 1
    s.a64_try_patches = list()
    s.a64_boxed_vars = list()
    s.a64_defer_starts = list()
    s.a64_defer_ends = list()

    arm64_emit_prologue(s)
    // Save incoming arguments X0..X7 + AAPCS64 stack arguments pi >= 8 at [x29 + 16 + (pi - 8) * 8]
    pi = 0
    while pi < c_params.len()
        poff = arm64_synth_alloc_var(s, c_params[pi])
        if pi < 8
            arm64_emit_str_reg_sp(s, pi, poff)
        else
            arm64_emit_ldr_x_off(s, 9, 29, 16 + ((pi - 8) * 8))
            arm64_emit_str_reg_sp(s, 9, poff)
        end
        pi = pi + 1
    end
    // Unpack captured outer variables from X10 closure env pointer
    ci = 0
    while ci < cap_names.len()
        coff = arm64_synth_alloc_var(s, cap_names[ci])
        clv = arm64_find_local_var(s, cap_names[ci])
        if clv != 0
            clv.a64_lv_is_boxed = cap_boxed[ci]
        end
        arm64_emit_ldr_x_off(s, 9, 10, 24 + (ci * 8))
        arm64_emit_str_reg_sp(s, 9, coff)
        ci = ci + 1
    end

    if c_mode == 1
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cp = get(pos_box, 0)
            if cp >= toks.len() break end
            if toks[cp].tok_kind == TOK_RBRACE() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "}")
                list_set(pos_box, 0, cp + 1)
                break
            end
            bp = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) <= bp list_set(pos_box, 0, bp + 1) end
        end
        arm64_emit_movz_x(s, 0, 0, 0)
    else
        arm64_synth_compile_expr(s, toks, pos_box)
    end
    arm64_emit_defers(s, toks)
    arm64_emit_epilogue(s)

    s.synth_locals = saved_locals
    s.synth_stack_offset = saved_stack_off
    s.a64_sp_delta = saved_sp_delta
    s.a64_in_function = saved_in_fn
    s.a64_try_patches = saved_try
    s.a64_boxed_vars = saved_boxed
    s.a64_defer_starts = saved_ds
    s.a64_defer_ends = saved_de

    after_body_off = s.synth_code.len()
    arm64_patch_b(s, jmp_over, after_body_off)

    // Allocate heap CLOS object: (3 + n_caps) * 8 bytes (min 32)
    n_caps = cap_names.len()
    clos_sz = (3 + n_caps) * 8
    if clos_sz < 32 clos_sz = 32 end
    arm64_emit_mov_imm64(s, 0, clos_sz)
    arm64_synth_emit_call_alloc(s)          // X0 = clos_ptr
    arm64_emit_mov_reg(s, 11, 0)            // X11 = clos_ptr
    // [clos + 0] = 0x434C4F53 ('CLOS')
    arm64_emit_mov_imm64(s, 9, 1129074515)
    arm64_emit_str_x_off(s, 9, 11, 0)
    // [clos + 8] = PC-relative address of body_entry_off via ADR X9, #delta
    adr_off = s.synth_code.len()
    arm64_emit_adr(s, 9, body_entry_off - adr_off)
    arm64_emit_str_x_off(s, 9, 11, 8)
    // [clos + 16] = n_caps
    arm64_emit_mov_imm64(s, 9, n_caps)
    arm64_emit_str_x_off(s, 9, 11, 16)
    // [clos + 24 + ci*8] = outer local value (or boxed cell pointer!)
    ci = 0
    while ci < n_caps
        arm64_emit_ldr_reg_sp(s, 9, cap_offs[ci])
        arm64_emit_str_x_off(s, 9, 11, 24 + (ci * 8))
        ci = ci + 1
    end
    arm64_emit_mov_reg(s, 0, 11)
    return 0
end

// ── 4. Pure AArch64 DICT0 HashMap + Unified Container + ByteBuffer Helpers ────

fn arm64_synth_emit_dict_helpers s
    // WHY: Pure AArch64 DICT0 HashMap (32B header: [0]=count, [8]=cap, [16]=slots, [24]=0x44494354)
    // with 24B slots {[0]=state(0/1/2), [8]=key, [16]=val}, FNV-1a string+int hashing, and 2x rehash.
    // Preserves callee-saved X19..X26 cleanly and NEVER touches exception registers X27/X28.

    // ── Helper A: __dict_hash(X0=key) -> X0=hash ──
    s.a64_dict_hash_off = s.synth_code.len()
    arm64_emit_mov_imm64(s, 9, 4194304)
    arm64_emit_cmp_x(s, 0, 9)
    blt_int_h = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)             // b.lt int_h
    // String FNV-1a hash
    arm64_emit_mov_reg(s, 10, 0)            // X10 = ptr
    arm64_emit_mov_imm64(s, 0, 2166136261)  // X0 = FNV offset basis
    arm64_emit_mov_imm64(s, 11, 16777619)   // X11 = FNV prime
    h_loop = s.synth_code.len()
    arm64_emit_ldrb_off(s, 9, 10, 0)        // W9 = *ptr
    arm64_emit_cmp_x(s, 9, 31)
    beq_h_done = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_eor_x(s, 0, 0, 9)
    arm64_emit_mul_x(s, 0, 0, 11)
    arm64_emit_add_imm(s, 10, 10, 1)
    arm64_emit_b(s, (h_loop - s.synth_code.len()) / 4)
    h_done = s.synth_code.len()
    arm64_patch_b_cond(s, beq_h_done, 0, h_done)
    arm64_emit_ret(s)
    // Integer multiplicative hash
    int_h_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_int_h, 11, int_h_off)
    arm64_emit_mov_imm64(s, 9, 2654435761)
    arm64_emit_mul_x(s, 0, 0, 9)
    arm64_emit_ret(s)

    // ── Helper B: __dict_key_eq(X0=k1, X1=k2) -> X0=(0/1) ──
    s.a64_dict_eq_off = s.synth_code.len()
    arm64_emit_cmp_x(s, 0, 1)
    bne_neq_ptr = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_movz_x(s, 0, 1, 0)
    arm64_emit_ret(s)
    neq_ptr_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_neq_ptr, 1, neq_ptr_off)
    arm64_emit_mov_imm64(s, 9, 4194304)
    arm64_emit_cmp_x(s, 0, 9)
    blt_eq_f1 = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_cmp_x(s, 1, 9)
    blt_eq_f2 = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    eq_loop = s.synth_code.len()
    arm64_emit_ldrb_off(s, 10, 0, 0)
    arm64_emit_ldrb_off(s, 11, 1, 0)
    arm64_emit_cmp_x(s, 10, 11)
    bne_eq_f = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_cmp_x(s, 10, 31)
    beq_eq_t = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_add_imm(s, 0, 0, 1)
    arm64_emit_add_imm(s, 1, 1, 1)
    arm64_emit_b(s, (eq_loop - s.synth_code.len()) / 4)
    eq_t_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_eq_t, 0, eq_t_off)
    arm64_emit_movz_x(s, 0, 1, 0)
    arm64_emit_ret(s)
    eq_f_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_eq_f1, 11, eq_f_off)
    arm64_patch_b_cond(s, blt_eq_f2, 11, eq_f_off)
    arm64_patch_b_cond(s, bne_eq_f, 1, eq_f_off)
    arm64_emit_movz_x(s, 0, 0, 0)
    arm64_emit_ret(s)

    // ── Helper C: __dict_new(X0=init_cap) -> X0=hdr ──
    s.a64_dict_new_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_movz_x(s, 19, 16, 0)         // X19 = cap >= 16
    arm64_emit_cmp_x(s, 19, 0)
    bge_dcap = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_mov_reg(s, 19, 0)
    dcap_ok = s.synth_code.len()
    arm64_patch_b_cond(s, bge_dcap, 10, dcap_ok)
    arm64_emit_movz_x(s, 0, 32, 0)
    arm64_synth_emit_call_alloc(s)          // X0 = hdr
    arm64_emit_mov_reg(s, 20, 0)            // X20 = hdr
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 0, 19, 9)           // cap * 24
    arm64_synth_emit_call_alloc(s)          // X0 = slots
    // Zero slots
    arm64_emit_movz_x(s, 9, 0, 0)
    arm64_emit_movz_x(s, 10, 24, 0)
    arm64_emit_mul_x(s, 10, 19, 10)
    z_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 10)
    bge_z = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 11, 0, 9)
    arm64_emit_str_x_off(s, 31, 11, 0)
    arm64_emit_add_imm(s, 9, 9, 8)
    arm64_emit_b(s, (z_loop - s.synth_code.len()) / 4)
    z_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_z, 10, z_done)
    arm64_emit_str_x_off(s, 31, 20, 0)      // count = 0
    arm64_emit_str_x_off(s, 19, 20, 8)      // cap
    arm64_emit_str_x_off(s, 0, 20, 16)      // slots
    arm64_emit_mov_imm64(s, 9, 1145652052)  // 'DICT'
    arm64_emit_str_x_off(s, 9, 20, 24)
    arm64_emit_mov_reg(s, 0, 20)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)

    // ── Helper D: __dict_set(X0=hdr, X1=key, X2=val, X3=val_tag) -> X0=hdr ──
    s.a64_dict_set_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 96)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_str_x_off(s, 21, 31, 32)
    arm64_emit_str_x_off(s, 22, 31, 40)
    arm64_emit_str_x_off(s, 23, 31, 48)
    arm64_emit_str_x_off(s, 24, 31, 56)
    arm64_emit_str_x_off(s, 25, 31, 64)
    arm64_emit_str_x_off(s, 26, 31, 72)
    arm64_emit_str_x_off(s, 3, 31, 80)      // [sp, #80] = val_tag (0=int, 1=float, 2=str)
    arm64_emit_mov_reg(s, 19, 0)            // X19 = hdr
    arm64_emit_mov_reg(s, 20, 1)            // X20 = key
    arm64_emit_mov_reg(s, 21, 2)            // X21 = val
    arm64_emit_ldr_x_off(s, 22, 19, 0)      // X22 = count
    arm64_emit_ldr_x_off(s, 23, 19, 8)      // X23 = cap
    arm64_emit_add_x(s, 9, 22, 22)          // count * 2
    arm64_emit_cmp_x(s, 9, 23)
    blt_no_rehash = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    // Grow cap * 2 and re-insert preserving val_tag
    arm64_emit_ldr_x_off(s, 24, 19, 16)     // X24 = old_slots
    arm64_emit_mov_reg(s, 25, 23)           // X25 = old_cap
    arm64_emit_add_x(s, 23, 23, 23)         // new_cap = old_cap * 2
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 0, 23, 9)
    arm64_synth_emit_call_alloc(s)          // X0 = new_slots
    arm64_emit_mov_reg(s, 26, 0)            // X26 = new_slots
    arm64_emit_movz_x(s, 9, 0, 0)
    arm64_emit_movz_x(s, 10, 24, 0)
    arm64_emit_mul_x(s, 10, 23, 10)
    rz_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 10)
    bge_rz = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 11, 26, 9)
    arm64_emit_str_x_off(s, 31, 11, 0)
    arm64_emit_add_imm(s, 9, 9, 8)
    arm64_emit_b(s, (rz_loop - s.synth_code.len()) / 4)
    rz_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_rz, 10, rz_done)
    arm64_emit_str_x_off(s, 31, 19, 0)
    arm64_emit_str_x_off(s, 23, 19, 8)
    arm64_emit_str_x_off(s, 26, 19, 16)
    arm64_emit_movz_x(s, 22, 0, 0)          // i = 0
    ri_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 22, 25)
    bge_ri = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 22, 9)
    arm64_emit_add_x(s, 9, 24, 9)
    arm64_emit_ldr_x_off(s, 10, 9, 0)       // raw state | (tag << 8)
    arm64_emit_movz_x(s, 12, 255, 0)
    arm64_emit_and_x(s, 12, 10, 12)         // X12 = state_low
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_cmp_x(s, 12, 11)
    bne_ri_skip = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_mov_reg(s, 0, 19)
    arm64_emit_ldr_x_off(s, 1, 9, 8)
    arm64_emit_ldr_x_off(s, 2, 9, 16)
    arm64_emit_movz_x(s, 13, 8, 0)
    arm64_emit_lsrv_x(s, 3, 10, 13)         // X3 = preserved val_tag
    arm64_synth_emit_call_helper(s, "__dict_set")
    ri_skip = s.synth_code.len()
    arm64_patch_b_cond(s, bne_ri_skip, 1, ri_skip)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_b(s, (ri_loop - s.synth_code.len()) / 4)
    ri_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_ri, 10, ri_done)

    no_rehash_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_no_rehash, 11, no_rehash_off)
    arm64_emit_ldr_x_off(s, 23, 19, 8)      // X23 = cap
    arm64_emit_ldr_x_off(s, 24, 19, 16)     // X24 = slots
    arm64_emit_sub_imm(s, 25, 23, 1)        // X25 = mask
    arm64_emit_mov_reg(s, 0, 20)
    arm64_synth_emit_call_helper(s, "__dict_hash")
    arm64_emit_and_x(s, 22, 0, 25)          // X22 = idx
    arm64_emit_mov_imm64(s, 26, 0 - 1)      // X26 = first_tomb (-1)
    ds_probe = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 22, 9)
    arm64_emit_add_x(s, 9, 24, 9)           // X9 = &slots[idx]
    arm64_emit_ldr_x_off(s, 10, 9, 0)       // X10 = raw state
    arm64_emit_movz_x(s, 11, 255, 0)
    arm64_emit_and_x(s, 10, 10, 11)         // X10 = state_low
    arm64_emit_cmp_x(s, 10, 31)
    beq_empty = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 11, 2, 0)
    arm64_emit_cmp_x(s, 10, 11)
    bne_not_tomb = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_cmp_x(s, 26, 31)
    bge_has_tomb = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_mov_reg(s, 26, 22)
    has_tomb_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_has_tomb, 10, has_tomb_off)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_and_x(s, 22, 22, 25)
    arm64_emit_b(s, (ds_probe - s.synth_code.len()) / 4)
    not_tomb_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_not_tomb, 1, not_tomb_off)
    arm64_emit_ldr_x_off(s, 0, 9, 8)
    arm64_emit_mov_reg(s, 1, 20)
    arm64_synth_emit_call_helper(s, "__dict_key_eq")
    arm64_emit_cmp_x(s, 0, 31)
    beq_ds_next = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    // Update existing in-place (preserving new val_tag in bits 8..15)
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 22, 9)
    arm64_emit_add_x(s, 9, 24, 9)
    arm64_emit_ldr_x_off(s, 10, 31, 80)     // X10 = val_tag
    arm64_emit_movz_x(s, 11, 8, 0)
    arm64_emit_lslv_x(s, 10, 10, 11)
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_orr_x(s, 10, 10, 11)
    arm64_emit_str_x_off(s, 10, 9, 0)
    arm64_emit_str_x_off(s, 21, 9, 16)
    jmp_ds_ret1 = s.synth_code.len()
    arm64_emit_b(s, 0)
    ds_next_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_ds_next, 0, ds_next_off)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_and_x(s, 22, 22, 25)
    arm64_emit_b(s, (ds_probe - s.synth_code.len()) / 4)
    // Insert new key at first_tomb (>= 0) else idx
    empty_ins_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_empty, 0, empty_ins_off)
    arm64_emit_cmp_x(s, 26, 31)
    blt_use_idx = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_mov_reg(s, 22, 26)
    use_idx_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_use_idx, 11, use_idx_off)
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 22, 9)
    arm64_emit_add_x(s, 9, 24, 9)
    arm64_emit_ldr_x_off(s, 10, 31, 80)     // X10 = val_tag
    arm64_emit_movz_x(s, 11, 8, 0)
    arm64_emit_lslv_x(s, 10, 10, 11)
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_orr_x(s, 10, 10, 11)
    arm64_emit_str_x_off(s, 10, 9, 0)
    arm64_emit_str_x_off(s, 20, 9, 8)
    arm64_emit_str_x_off(s, 21, 9, 16)
    arm64_emit_ldr_x_off(s, 10, 19, 0)
    arm64_emit_add_imm(s, 10, 10, 1)
    arm64_emit_str_x_off(s, 10, 19, 0)
    ds_ret_off = s.synth_code.len()
    arm64_patch_b(s, jmp_ds_ret1, ds_ret_off)
    arm64_emit_mov_reg(s, 0, 19)
    arm64_emit_ldr_x_off(s, 26, 31, 72)
    arm64_emit_ldr_x_off(s, 25, 31, 64)
    arm64_emit_ldr_x_off(s, 24, 31, 56)
    arm64_emit_ldr_x_off(s, 23, 31, 48)
    arm64_emit_ldr_x_off(s, 22, 31, 40)
    arm64_emit_ldr_x_off(s, 21, 31, 32)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 96)
    arm64_emit_ret(s)

    // ── Helper E: __dict_get(X0=hdr, X1=key) -> (X0=val, X1=val_tag) ──
    s.a64_dict_get_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_str_x_off(s, 21, 31, 32)
    arm64_emit_str_x_off(s, 22, 31, 40)
    arm64_emit_str_x_off(s, 23, 31, 48)
    arm64_emit_str_x_off(s, 24, 31, 56)
    arm64_emit_mov_reg(s, 19, 0)
    arm64_emit_mov_reg(s, 20, 1)
    arm64_emit_ldr_x_off(s, 21, 19, 8)
    arm64_emit_ldr_x_off(s, 22, 19, 16)
    arm64_emit_sub_imm(s, 23, 21, 1)
    arm64_emit_mov_reg(s, 0, 20)
    arm64_synth_emit_call_helper(s, "__dict_hash")
    arm64_emit_and_x(s, 24, 0, 23)
    dg_loop = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 24, 9)
    arm64_emit_add_x(s, 9, 22, 9)
    arm64_emit_ldr_x_off(s, 10, 9, 0)
    arm64_emit_movz_x(s, 11, 255, 0)
    arm64_emit_and_x(s, 10, 10, 11)
    arm64_emit_cmp_x(s, 10, 31)
    beq_dg_miss = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_cmp_x(s, 10, 11)
    bne_dg_next = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_ldr_x_off(s, 0, 9, 8)
    arm64_emit_mov_reg(s, 1, 20)
    arm64_synth_emit_call_helper(s, "__dict_key_eq")
    arm64_emit_cmp_x(s, 0, 31)
    beq_dg_next2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 24, 9)
    arm64_emit_add_x(s, 9, 22, 9)
    arm64_emit_ldr_x_off(s, 10, 9, 0)
    arm64_emit_movz_x(s, 11, 8, 0)
    arm64_emit_lsrv_x(s, 1, 10, 11)         // X1 = val_tag
    arm64_emit_ldr_x_off(s, 0, 9, 16)       // X0 = val
    jmp_dg_ret = s.synth_code.len()
    arm64_emit_b(s, 0)
    dg_next_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_dg_next, 1, dg_next_off)
    arm64_patch_b_cond(s, beq_dg_next2, 0, dg_next_off)
    arm64_emit_add_imm(s, 24, 24, 1)
    arm64_emit_and_x(s, 24, 24, 23)
    arm64_emit_b(s, (dg_loop - s.synth_code.len()) / 4)
    dg_miss_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_dg_miss, 0, dg_miss_off)
    arm64_emit_movz_x(s, 0, 0, 0)
    arm64_emit_movz_x(s, 1, 0, 0)
    dg_ret_off = s.synth_code.len()
    arm64_patch_b(s, jmp_dg_ret, dg_ret_off)
    arm64_emit_ldr_x_off(s, 24, 31, 56)
    arm64_emit_ldr_x_off(s, 23, 31, 48)
    arm64_emit_ldr_x_off(s, 22, 31, 40)
    arm64_emit_ldr_x_off(s, 21, 31, 32)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── Helper F: __dict_has(X0=hdr, X1=key) -> X0=(0/1) ──
    s.a64_dict_has_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_str_x_off(s, 21, 31, 32)
    arm64_emit_str_x_off(s, 22, 31, 40)
    arm64_emit_str_x_off(s, 23, 31, 48)
    arm64_emit_str_x_off(s, 24, 31, 56)
    arm64_emit_mov_reg(s, 19, 0)
    arm64_emit_mov_reg(s, 20, 1)
    arm64_emit_ldr_x_off(s, 21, 19, 8)
    arm64_emit_ldr_x_off(s, 22, 19, 16)
    arm64_emit_sub_imm(s, 23, 21, 1)
    arm64_emit_mov_reg(s, 0, 20)
    arm64_synth_emit_call_helper(s, "__dict_hash")
    arm64_emit_and_x(s, 24, 0, 23)
    dh_loop = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 24, 9)
    arm64_emit_add_x(s, 9, 22, 9)
    arm64_emit_ldr_x_off(s, 10, 9, 0)
    arm64_emit_movz_x(s, 11, 255, 0)
    arm64_emit_and_x(s, 10, 10, 11)
    arm64_emit_cmp_x(s, 10, 31)
    beq_dh_miss = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_cmp_x(s, 10, 11)
    bne_dh_next = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_ldr_x_off(s, 0, 9, 8)
    arm64_emit_mov_reg(s, 1, 20)
    arm64_synth_emit_call_helper(s, "__dict_key_eq")
    arm64_emit_cmp_x(s, 0, 31)
    beq_dh_next2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 0, 1, 0)
    jmp_dh_ret = s.synth_code.len()
    arm64_emit_b(s, 0)
    dh_next_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_dh_next, 1, dh_next_off)
    arm64_patch_b_cond(s, beq_dh_next2, 0, dh_next_off)
    arm64_emit_add_imm(s, 24, 24, 1)
    arm64_emit_and_x(s, 24, 24, 23)
    arm64_emit_b(s, (dh_loop - s.synth_code.len()) / 4)
    dh_miss_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_dh_miss, 0, dh_miss_off)
    arm64_emit_movz_x(s, 0, 0, 0)
    dh_ret_off = s.synth_code.len()
    arm64_patch_b(s, jmp_dh_ret, dh_ret_off)
    arm64_emit_ldr_x_off(s, 24, 31, 56)
    arm64_emit_ldr_x_off(s, 23, 31, 48)
    arm64_emit_ldr_x_off(s, 22, 31, 40)
    arm64_emit_ldr_x_off(s, 21, 31, 32)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── Helper G: __dict_del(X0=hdr, X1=key) -> X0=(0/1) ──
    s.a64_dict_del_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_str_x_off(s, 21, 31, 32)
    arm64_emit_str_x_off(s, 22, 31, 40)
    arm64_emit_str_x_off(s, 23, 31, 48)
    arm64_emit_str_x_off(s, 24, 31, 56)
    arm64_emit_mov_reg(s, 19, 0)
    arm64_emit_mov_reg(s, 20, 1)
    arm64_emit_ldr_x_off(s, 21, 19, 8)
    arm64_emit_ldr_x_off(s, 22, 19, 16)
    arm64_emit_sub_imm(s, 23, 21, 1)
    arm64_emit_mov_reg(s, 0, 20)
    arm64_synth_emit_call_helper(s, "__dict_hash")
    arm64_emit_and_x(s, 24, 0, 23)
    dd_loop = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 24, 9)
    arm64_emit_add_x(s, 9, 22, 9)
    arm64_emit_ldr_x_off(s, 10, 9, 0)
    arm64_emit_movz_x(s, 11, 255, 0)
    arm64_emit_and_x(s, 10, 10, 11)
    arm64_emit_cmp_x(s, 10, 31)
    beq_dd_miss = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_cmp_x(s, 10, 11)
    bne_dd_next = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_ldr_x_off(s, 0, 9, 8)
    arm64_emit_mov_reg(s, 1, 20)
    arm64_synth_emit_call_helper(s, "__dict_key_eq")
    arm64_emit_cmp_x(s, 0, 31)
    beq_dd_next2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 24, 0)
    arm64_emit_mul_x(s, 9, 24, 9)
    arm64_emit_add_x(s, 9, 22, 9)
    arm64_emit_movz_x(s, 10, 2, 0)
    arm64_emit_str_x_off(s, 10, 9, 0)
    arm64_emit_ldr_x_off(s, 10, 19, 0)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_str_x_off(s, 10, 19, 0)
    arm64_emit_movz_x(s, 0, 1, 0)
    jmp_dd_ret = s.synth_code.len()
    arm64_emit_b(s, 0)
    dd_next_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_dd_next, 1, dd_next_off)
    arm64_patch_b_cond(s, beq_dd_next2, 0, dd_next_off)
    arm64_emit_add_imm(s, 24, 24, 1)
    arm64_emit_and_x(s, 24, 24, 23)
    arm64_emit_b(s, (dd_loop - s.synth_code.len()) / 4)
    dd_miss_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_dd_miss, 0, dd_miss_off)
    arm64_emit_movz_x(s, 0, 0, 0)
    dd_ret_off = s.synth_code.len()
    arm64_patch_b(s, jmp_dd_ret, dd_ret_off)
    arm64_emit_ldr_x_off(s, 24, 31, 56)
    arm64_emit_ldr_x_off(s, 23, 31, 48)
    arm64_emit_ldr_x_off(s, 22, 31, 40)
    arm64_emit_ldr_x_off(s, 21, 31, 32)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── Helper H: __container_get(X0=hdr, X1=key_or_idx) -> (X0=val, X1=tag) ──
    s.a64_cont_get_off = s.synth_code.len()
    if s.a64_freestanding == 0
        s.a64_needs_throw_null = 1
        arm64_emit_movz_x(s, 11, 4096, 0)
        arm64_emit_cmp_x(s, 0, 11)
        bhs_cg_ok = s.synth_code.len()
        arm64_emit_b_cond(s, 2, 0) // b.hs ok (unsigned >= 4096)
        arm64_emit_stp_pre(s, 29, 30, 31, 0 - 16)
        arm64_synth_emit_call_helper(s, "_lipi_throw_null_deref")
        arm64_emit_ldp_post(s, 29, 30, 31, 16)
        arm64_emit_ret(s)
        cg_ok_off = s.synth_code.len()
        arm64_patch_b_cond(s, bhs_cg_ok, 2, cg_ok_off)
    end
    arm64_emit_ldr_x_off(s, 9, 0, 24)
    arm64_emit_mov_imm64(s, 10, 1145652052)
    arm64_emit_cmp_x(s, 9, 10)
    bne_cg_list = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_b(s, (s.a64_dict_get_off - s.synth_code.len()) / 4)
    cg_list_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_cg_list, 1, cg_list_off)
    // Negative list indexing: if idx < 0, idx += hdr[0] (len)
    arm64_emit_cmp_x(s, 1, 31)
    bge_cg_pos = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_ldr_x_off(s, 11, 0, 0)
    arm64_emit_add_x(s, 1, 1, 11)
    cg_pos_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_cg_pos, 10, cg_pos_off)
    arm64_emit_ldr_x_off(s, 2, 0, 16)
    arm64_emit_add_x(s, 1, 1, 1)
    arm64_emit_add_x(s, 1, 1, 1)
    arm64_emit_add_x(s, 1, 1, 1)
    arm64_emit_add_x(s, 0, 2, 1)
    arm64_emit_ldr_x_off(s, 0, 0, 0)
    arm64_emit_movz_x(s, 1, 0, 0)           // X1 = tag 0 for list elements
    arm64_emit_ret(s)

    // ── Helper I: __container_set(X0=hdr, X1=key_or_idx, X2=val, X3=val_tag) -> X0=hdr ──
    s.a64_cont_set_off = s.synth_code.len()
    if s.a64_freestanding == 0
        s.a64_needs_throw_null = 1
        arm64_emit_movz_x(s, 11, 4096, 0)
        arm64_emit_cmp_x(s, 0, 11)
        bhs_cs_ok = s.synth_code.len()
        arm64_emit_b_cond(s, 2, 0)
        arm64_emit_stp_pre(s, 29, 30, 31, 0 - 16)
        arm64_synth_emit_call_helper(s, "_lipi_throw_null_deref")
        arm64_emit_ldp_post(s, 29, 30, 31, 16)
        arm64_emit_ret(s)
        cs_ok_off = s.synth_code.len()
        arm64_patch_b_cond(s, bhs_cs_ok, 2, cs_ok_off)
    end
    arm64_emit_ldr_x_off(s, 9, 0, 24)
    arm64_emit_mov_imm64(s, 10, 1145652052)
    arm64_emit_cmp_x(s, 9, 10)
    bne_cs_list = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_b(s, (s.a64_dict_set_off - s.synth_code.len()) / 4)
    cs_list_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_cs_list, 1, cs_list_off)
    // Negative list indexing: if idx < 0, idx += hdr[0] (len)
    arm64_emit_cmp_x(s, 1, 31)
    bge_cs_pos = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_ldr_x_off(s, 11, 0, 0)
    arm64_emit_add_x(s, 1, 1, 11)
    cs_pos_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_cs_pos, 10, cs_pos_off)
    arm64_emit_ldr_x_off(s, 3, 0, 16)
    arm64_emit_add_x(s, 1, 1, 1)
    arm64_emit_add_x(s, 1, 1, 1)
    arm64_emit_add_x(s, 1, 1, 1)
    arm64_emit_add_x(s, 3, 3, 1)
    arm64_emit_str_x_off(s, 2, 3, 0)
    arm64_emit_ret(s)
    return 0
end

fn arm64_synth_emit_buf_helpers s
    // WHY: Native AArch64 ByteBuffer {data_ptr, len, cap} with amortized O(1) growth.

    // ── __buf_new(X0=init_cap) -> X0=buf_hdr ──
    s.a64_buf_new_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_movz_x(s, 19, 64, 0)
    arm64_emit_cmp_x(s, 19, 0)
    bge_bcap = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_mov_reg(s, 19, 0)
    bcap_ok = s.synth_code.len()
    arm64_patch_b_cond(s, bge_bcap, 10, bcap_ok)
    arm64_emit_movz_x(s, 0, 24, 0)
    arm64_synth_emit_call_alloc(s)
    arm64_emit_mov_reg(s, 20, 0)
    arm64_emit_mov_reg(s, 0, 19)
    arm64_synth_emit_call_alloc(s)
    arm64_emit_strb_off(s, 31, 0, 0)
    arm64_emit_str_x_off(s, 0, 20, 0)
    arm64_emit_str_x_off(s, 31, 20, 8)
    arm64_emit_str_x_off(s, 19, 20, 16)
    arm64_emit_mov_reg(s, 0, 20)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)

    // ── __buf_write_byte(X0=buf, X1=byte) -> X0=buf ──
    s.a64_buf_wbyte_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_str_x_off(s, 21, 31, 32)
    arm64_emit_str_x_off(s, 22, 31, 40)
    arm64_emit_str_x_off(s, 23, 31, 48)
    arm64_emit_mov_reg(s, 19, 0)
    arm64_emit_mov_reg(s, 20, 1)
    arm64_emit_ldr_x_off(s, 21, 19, 0)
    arm64_emit_ldr_x_off(s, 22, 19, 8)
    arm64_emit_ldr_x_off(s, 23, 19, 16)
    arm64_emit_add_imm(s, 9, 22, 1)
    arm64_emit_cmp_x(s, 9, 23)
    blt_bw_ok = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_add_x(s, 23, 23, 23)
    arm64_emit_mov_reg(s, 0, 23)
    arm64_synth_emit_call_alloc(s)
    arm64_emit_movz_x(s, 9, 0, 0)
    bw_cp = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 22)
    bge_bw_cp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 10, 21, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 10, 0, 9)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (bw_cp - s.synth_code.len()) / 4)
    bw_cp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_bw_cp, 10, bw_cp_done)
    arm64_emit_mov_reg(s, 21, 0)
    arm64_emit_str_x_off(s, 21, 19, 0)
    arm64_emit_str_x_off(s, 23, 19, 16)
    bw_ok_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_bw_ok, 11, bw_ok_off)
    arm64_emit_add_x(s, 9, 21, 22)
    arm64_emit_strb_off(s, 20, 9, 0)
    arm64_emit_strb_off(s, 31, 9, 1)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_str_x_off(s, 22, 19, 8)
    arm64_emit_mov_reg(s, 0, 19)
    arm64_emit_ldr_x_off(s, 23, 31, 48)
    arm64_emit_ldr_x_off(s, 22, 31, 40)
    arm64_emit_ldr_x_off(s, 21, 31, 32)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── __buf_write_str(X0=buf, X1=cstr_ptr) -> X0=buf ──
    s.a64_buf_wstr_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_mov_reg(s, 19, 0)
    arm64_emit_mov_reg(s, 20, 1)
    bws_loop = s.synth_code.len()
    arm64_emit_ldrb_off(s, 1, 20, 0)
    arm64_emit_cmp_x(s, 1, 31)
    beq_bws_done = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_mov_reg(s, 0, 19)
    arm64_emit_bl(s, (s.a64_buf_wbyte_off - s.synth_code.len()) / 4)
    arm64_emit_add_imm(s, 20, 20, 1)
    arm64_emit_b(s, (bws_loop - s.synth_code.len()) / 4)
    bws_done = s.synth_code.len()
    arm64_patch_b_cond(s, beq_bws_done, 0, bws_done)
    arm64_emit_mov_reg(s, 0, 19)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)

    // ── __buf_to_str(X0=buf) -> X0=new_cstr_ptr ──
    s.a64_buf_tostr_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 0, 0)
    arm64_emit_ldr_x_off(s, 20, 0, 8)
    arm64_emit_add_imm(s, 0, 20, 1)
    arm64_synth_emit_call_alloc(s)
    arm64_emit_movz_x(s, 9, 0, 0)
    bts_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 20)
    bge_bts = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 10, 19, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 10, 0, 9)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (bts_loop - s.synth_code.len()) / 4)
    bts_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_bts, 10, bts_done)
    arm64_emit_add_x(s, 10, 0, 20)
    arm64_emit_strb_off(s, 31, 10, 0)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)
    return 0
end

// ── 5. Null-Deref Trap, Tagged Printing & Real LSYM0 Stack Trace (ARM64 Parity) ─

fn arm64_synth_emit_throw_null_helper s
    // WHY: Shared AArch64 trap throwing catchable NullPointerException (X27=3 [str tag], X28=msg)
    // on null/low (< 4096) struct or container dereference, matching x86_64 _lipi_throw_null_deref.
    s.a64_throw_null_off = s.synth_code.len()
    arm64_emit_load_rodata_str(s, 28, "NullPointerException: null struct dereference")
    arm64_emit_movz_x(s, 27, 3, 0)          // flag=1 + str_tag(2) = 3
    arm64_emit_movz_x(s, 0, 0, 0)
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_ret(s)
    return 0
end

fn arm64_emit_null_guard_reg s toks reg
    // WHY: Guards struct/pointer deref in register `reg` against < 4096 in hosted mode.
    // Skipped in --freestanding bare-metal mode where low physical addresses may be valid MMIO.
    if s.a64_freestanding == 1
        return 0
    end
    s.a64_needs_throw_null = 1
    arm64_emit_movz_x(s, 11, 4096, 0)
    arm64_emit_cmp_x(s, reg, 11)
    bhs_ok = s.synth_code.len()
    arm64_emit_b_cond(s, 2, 0)              // b.hs ok (unsigned >= 4096)
    arm64_synth_emit_call_helper(s, "_lipi_throw_null_deref")
    if s.a64_try_patches.len() > 0
        jmp_c = s.synth_code.len()
        arm64_emit_b(s, 0)
        push(s.a64_try_patches[s.a64_try_patches.len() - 1], [jmp_c, 0])
    elif s.a64_in_function == 1
        arm64_emit_defers(s, toks)
        arm64_emit_epilogue(s)
    else
        s.a64_needs_uncaught_throw = 1
        arm64_synth_emit_call_helper(s, "__uncaught_throw")
    end
    ok_off = s.synth_code.len()
    arm64_patch_b_cond(s, bhs_ok, 2, ok_off)
    return 0
end

fn arm64_emit_format_float_to_stack s append_nl
    // WHY: Formats IEEE-754 binary64 bits in X19 into stack buffer starting at X20 (sp+16..sp+47),
    // using sp+48..sp+79 as digit scratch, leaving X20 pointing past the last written byte.
    // Properly handles NaN (never "-NaN"), Inf, -Inf, 0.0, -0.0, subnormals, and normal values
    // using pure integer instructions (0 FP instructions in the formatter itself).
    // abs_bits -> X10, exp_raw -> X21, mant_raw -> X22
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_lslv_x(s, 10, 19, 11)
    arm64_emit_lsrv_x(s, 10, 10, 11)        // X10 = abs_bits
    arm64_emit_movz_x(s, 11, 52, 0)
    arm64_emit_lsrv_x(s, 21, 10, 11)        // X21 = exp_raw (0..2047)
    arm64_emit_movz_x(s, 12, 1, 0)
    arm64_emit_lslv_x(s, 12, 12, 11)        // X12 = 1 << 52
    arm64_emit_sub_imm(s, 9, 12, 1)         // X9 = (1 << 52) - 1
    arm64_emit_and_x(s, 22, 10, 9)          // X22 = mant_raw

    // Special case: exp_raw == 2047 -> NaN (mant != 0) or +/-Inf (mant == 0)
    arm64_emit_movz_x(s, 9, 2047, 0)
    arm64_emit_cmp_x(s, 21, 9)
    bne_pf_finite = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_cmp_x(s, 22, 31)
    beq_pf_inf = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    // Emit "NaN" (always unsigned)
    arm64_emit_movz_x(s, 9, 78, 0)          // 'N'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_movz_x(s, 9, 97, 0)          // 'a'
    arm64_emit_strb_off(s, 9, 20, 1)
    arm64_emit_movz_x(s, 9, 78, 0)          // 'N'
    arm64_emit_strb_off(s, 9, 20, 2)
    arm64_emit_add_imm(s, 20, 20, 3)
    jmp_pf_done_nan = s.synth_code.len()
    arm64_emit_b(s, 0)
    // Emit "Inf" or "-Inf"
    pf_inf_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_pf_inf, 0, pf_inf_off)
    arm64_emit_movz_x(s, 11, 63, 0)
    arm64_emit_lsrv_x(s, 9, 19, 11)
    arm64_emit_cmp_x(s, 9, 31)
    beq_pf_pinf = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 45, 0)          // '-'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    pf_pinf_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_pf_pinf, 0, pf_pinf_off)
    arm64_emit_movz_x(s, 9, 73, 0)          // 'I'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_movz_x(s, 9, 110, 0)         // 'n'
    arm64_emit_strb_off(s, 9, 20, 1)
    arm64_emit_movz_x(s, 9, 102, 0)         // 'f'
    arm64_emit_strb_off(s, 9, 20, 2)
    arm64_emit_add_imm(s, 20, 20, 3)
    jmp_pf_done_inf = s.synth_code.len()
    arm64_emit_b(s, 0)

    // Finite value: check sign bit
    pf_finite_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_pf_finite, 1, pf_finite_off)
    arm64_emit_movz_x(s, 11, 63, 0)
    arm64_emit_lsrv_x(s, 9, 19, 11)
    arm64_emit_cmp_x(s, 9, 31)
    beq_pf_pos = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 45, 0)          // '-'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    pf_pos_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_pf_pos, 0, pf_pos_off)

    // Exact zero (exp_raw == 0 && mant_raw == 0) -> "0.0"; subnormal (exp_raw == 0 && mant_raw != 0) -> scientific
    arm64_emit_cmp_x(s, 21, 31)
    bne_pf_nz = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_cmp_x(s, 22, 31)
    bne_pf_subnorm = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_movz_x(s, 9, 48, 0)
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_movz_x(s, 9, 46, 0)
    arm64_emit_strb_off(s, 9, 20, 1)
    arm64_emit_movz_x(s, 9, 48, 0)
    arm64_emit_strb_off(s, 9, 20, 2)
    arm64_emit_add_imm(s, 20, 20, 3)
    jmp_pf_done_zero = s.synth_code.len()
    arm64_emit_b(s, 0)

    // Subnormal entry into pure-integer scientific path: m = mant_raw (X23), b = -1074 (X21)
    pf_subnorm_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_pf_subnorm, 1, pf_subnorm_off)
    arm64_emit_mov_reg(s, 23, 22)
    arm64_emit_mov_imm64(s, 21, 0 - 1074)
    jmp_pf_sci_sub = s.synth_code.len()
    arm64_emit_b(s, 0)

    pf_nz_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_pf_nz, 1, pf_nz_off)
    // exp = exp_raw - 1023 -> X21, full_mant = mant_raw | (1 << 52) -> X22
    arm64_emit_sub_imm(s, 21, 21, 1023)
    arm64_emit_orr_x(s, 22, 22, 12)
    // WHY: Route extreme magnitudes (exp >= 60 -> >=1.15e18, or exp <= -20 -> <1.9e-6) through
    // pure-integer scientific notation so `full_mant << (exp-52)` never overflows 64 bits and
    // tiny doubles like 1e-8 format identically to x86_64 (`1.0e-8`) with zero FP instructions!
    arm64_emit_movz_x(s, 9, 60, 0)
    arm64_emit_cmp_x(s, 21, 9)
    bge_pf_sci_hi = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_mov_imm64(s, 9, 0 - 20)
    arm64_emit_cmp_x(s, 21, 9)
    ble_pf_sci_lo = s.synth_code.len()
    arm64_emit_b_cond(s, 13, 0)

    // Split into int_part (X23) and f32 (X19) for fixed-point range (-19 <= exp <= 59)
    arm64_emit_movz_x(s, 9, 52, 0)
    arm64_emit_cmp_x(s, 21, 9)
    blt_pf_lt52 = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_sub_x(s, 10, 21, 9)
    arm64_emit_lslv_x(s, 23, 22, 10)
    arm64_emit_movz_x(s, 19, 0, 0)
    jmp_pf_have1 = s.synth_code.len()
    arm64_emit_b(s, 0)
    pf_lt52_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_pf_lt52, 11, pf_lt52_off)
    arm64_emit_movz_x(s, 9, 20, 0)
    arm64_emit_cmp_x(s, 21, 9)
    blt_pf_lt20 = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_movz_x(s, 9, 52, 0)
    arm64_emit_sub_x(s, 10, 9, 21)          // shift = 52 - exp
    arm64_emit_lsrv_x(s, 23, 22, 10)
    arm64_emit_movz_x(s, 11, 32, 0)
    arm64_emit_sub_x(s, 12, 11, 10)
    arm64_emit_lslv_x(s, 19, 22, 12)
    arm64_emit_lslv_x(s, 19, 19, 11)
    arm64_emit_lsrv_x(s, 19, 19, 11)
    jmp_pf_have2 = s.synth_code.len()
    arm64_emit_b(s, 0)
    pf_lt20_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_pf_lt20, 11, pf_lt20_off)
    arm64_emit_cmp_x(s, 21, 31)
    blt_pf_neg = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_movz_x(s, 9, 52, 0)
    arm64_emit_sub_x(s, 10, 9, 21)
    arm64_emit_lsrv_x(s, 23, 22, 10)
    arm64_emit_movz_x(s, 11, 32, 0)
    arm64_emit_sub_x(s, 12, 10, 11)
    arm64_emit_lsrv_x(s, 19, 22, 12)
    arm64_emit_lslv_x(s, 19, 19, 11)
    arm64_emit_lsrv_x(s, 19, 19, 11)
    jmp_pf_have3 = s.synth_code.len()
    arm64_emit_b(s, 0)
    pf_neg_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_pf_neg, 11, pf_neg_off)
    arm64_emit_movz_x(s, 23, 0, 0)
    arm64_emit_mov_imm64(s, 9, 0 - 32)
    arm64_emit_cmp_x(s, 21, 9)
    blt_pf_tiny = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_movz_x(s, 9, 20, 0)
    arm64_emit_sub_x(s, 10, 9, 21)
    arm64_emit_lsrv_x(s, 19, 22, 10)
    arm64_emit_movz_x(s, 11, 32, 0)
    arm64_emit_lslv_x(s, 19, 19, 11)
    arm64_emit_lsrv_x(s, 19, 19, 11)
    jmp_pf_have4 = s.synth_code.len()
    arm64_emit_b(s, 0)
    pf_tiny_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_pf_tiny, 11, pf_tiny_off)
    arm64_emit_movz_x(s, 19, 0, 0)
    pf_have_off = s.synth_code.len()
    arm64_patch_b(s, jmp_pf_have1, pf_have_off)
    arm64_patch_b(s, jmp_pf_have2, pf_have_off)
    arm64_patch_b(s, jmp_pf_have3, pf_have_off)
    arm64_patch_b(s, jmp_pf_have4, pf_have_off)
    // dec6 = ((f32 * 1000000) + 2^31) >> 32
    arm64_emit_mov_imm64(s, 9, 1000000)
    arm64_emit_mul_x(s, 19, 19, 9)
    arm64_emit_mov_imm64(s, 10, 2147483648)
    arm64_emit_add_x(s, 19, 19, 10)
    arm64_emit_movz_x(s, 11, 32, 0)
    arm64_emit_lsrv_x(s, 19, 19, 11)
    arm64_emit_cmp_x(s, 19, 9)
    blt_pf_nc = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_add_imm(s, 23, 23, 1)
    arm64_emit_movz_x(s, 19, 0, 0)
    pf_nc_off = s.synth_code.len()
    arm64_patch_b_cond(s, blt_pf_nc, 11, pf_nc_off)
    arm64_emit_movz_x(s, 22, 0, 0)          // X22 = sci_flag = 0 (fixed-point)
    jmp_pf_to_digits = s.synth_code.len()
    arm64_emit_b(s, 0)

    // ── Pure-Integer Scientific Notation Path (X23=m, X21=b, X22=d) ──────────
    pf_sci_norm_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_pf_sci_hi, 10, pf_sci_norm_off)
    arm64_patch_b_cond(s, ble_pf_sci_lo, 13, pf_sci_norm_off)
    arm64_emit_mov_reg(s, 23, 22)           // X23 = full_mant
    arm64_emit_sub_imm(s, 21, 21, 52)       // X21 = b = exp - 52
    pf_sci_entry_off = s.synth_code.len()
    arm64_patch_b(s, jmp_pf_sci_sub, pf_sci_entry_off)
    arm64_emit_movz_x(s, 22, 0, 0)          // X22 = d = 0
    arm64_emit_movz_x(s, 12, 10, 0)         // X12 = 10
    arm64_emit_movz_x(s, 13, 1, 0)          // X13 = 1
    // While b > 0: if m >= 2^62 -> m=(m+5)/10, d++ else m<<=1, b--
    arm64_emit_movz_x(s, 10, 16384, 48)     // X10 = 1 << 62
    pf_sb_pos = s.synth_code.len()
    arm64_emit_cmp_x(s, 21, 31)
    ble_pf_sb_pos = s.synth_code.len()
    arm64_emit_b_cond(s, 13, 0)
    arm64_emit_cmp_x(s, 23, 10)
    blo_pf_sb_shl = s.synth_code.len()
    arm64_emit_b_cond(s, 3, 0)
    arm64_emit_add_imm(s, 23, 23, 5)
    arm64_emit_udiv_x(s, 23, 23, 12)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_b(s, (pf_sb_pos - s.synth_code.len()) / 4)
    pf_sb_shl_off = s.synth_code.len()
    arm64_patch_b_cond(s, blo_pf_sb_shl, 3, pf_sb_shl_off)
    arm64_emit_add_x(s, 23, 23, 23)
    arm64_emit_sub_imm(s, 21, 21, 1)
    arm64_emit_b(s, (pf_sb_pos - s.synth_code.len()) / 4)
    pf_sb_pos_done = s.synth_code.len()
    arm64_patch_b_cond(s, ble_pf_sb_pos, 13, pf_sb_pos_done)
    // While b < 0: if m < 2^59 -> m*=10, d-- else m=(m+1)>>1, b++
    arm64_emit_movz_x(s, 10, 2048, 48)      // X10 = 1 << 59
    pf_sb_neg = s.synth_code.len()
    arm64_emit_cmp_x(s, 21, 31)
    bge_pf_sb_neg = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_cmp_x(s, 23, 10)
    bhs_pf_sb_shr = s.synth_code.len()
    arm64_emit_b_cond(s, 2, 0)
    arm64_emit_mul_x(s, 23, 23, 12)
    arm64_emit_sub_imm(s, 22, 22, 1)
    arm64_emit_b(s, (pf_sb_neg - s.synth_code.len()) / 4)
    pf_sb_shr_off = s.synth_code.len()
    arm64_patch_b_cond(s, bhs_pf_sb_shr, 2, pf_sb_shr_off)
    arm64_emit_add_imm(s, 23, 23, 1)
    arm64_emit_lsrv_x(s, 23, 23, 13)
    arm64_emit_add_imm(s, 21, 21, 1)
    arm64_emit_b(s, (pf_sb_neg - s.synth_code.len()) / 4)
    pf_sb_neg_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_pf_sb_neg, 10, pf_sb_neg_done)
    // Normalize m into [1000000, 9999999]
    arm64_emit_mov_imm64(s, 10, 10000000)
    pf_sn_hi = s.synth_code.len()
    arm64_emit_cmp_x(s, 23, 10)
    blo_pf_sn_hi = s.synth_code.len()
    arm64_emit_b_cond(s, 3, 0)
    arm64_emit_add_imm(s, 23, 23, 5)
    arm64_emit_udiv_x(s, 23, 23, 12)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_b(s, (pf_sn_hi - s.synth_code.len()) / 4)
    pf_sn_hi_done = s.synth_code.len()
    arm64_patch_b_cond(s, blo_pf_sn_hi, 3, pf_sn_hi_done)
    arm64_emit_mov_imm64(s, 11, 1000000)
    pf_sn_lo = s.synth_code.len()
    arm64_emit_cmp_x(s, 23, 11)
    bhs_pf_sn_lo = s.synth_code.len()
    arm64_emit_b_cond(s, 2, 0)
    arm64_emit_mul_x(s, 23, 23, 12)
    arm64_emit_sub_imm(s, 22, 22, 1)
    arm64_emit_b(s, (pf_sn_lo - s.synth_code.len()) / 4)
    pf_sn_lo_done = s.synth_code.len()
    arm64_patch_b_cond(s, bhs_pf_sn_lo, 2, pf_sn_lo_done)
    // X21 = sci_exp10 = d + 6; X22 = sci_flag = 1; X23 = m / 1000000; X19 = m % 1000000
    arm64_emit_add_imm(s, 21, 22, 6)
    arm64_emit_movz_x(s, 22, 1, 0)
    arm64_emit_udiv_x(s, 9, 23, 11)
    arm64_emit_mul_x(s, 10, 9, 11)
    arm64_emit_sub_x(s, 19, 23, 10)
    arm64_emit_mov_reg(s, 23, 9)

    pf_emit_digits_off = s.synth_code.len()
    arm64_patch_b(s, jmp_pf_to_digits, pf_emit_digits_off)
    // Emit int_part (X23) backwards into sp+48..sp+79
    arm64_emit_add_imm(s, 10, 31, 79)
    arm64_emit_movz_x(s, 11, 10, 0)
    pf_idig = s.synth_code.len()
    arm64_emit_udiv_x(s, 12, 23, 11)
    arm64_emit_mul_x(s, 13, 12, 11)
    arm64_emit_sub_x(s, 9, 23, 13)
    arm64_emit_add_imm(s, 9, 9, 48)
    arm64_emit_strb_off(s, 9, 10, 0)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_mov_reg(s, 23, 12)
    arm64_emit_cmp_x(s, 23, 31)
    arm64_emit_b_cond(s, 1, (pf_idig - s.synth_code.len()) / 4)
    // Copy int digits forward into X20
    arm64_emit_add_imm(s, 10, 10, 1)
    arm64_emit_add_imm(s, 11, 31, 80)
    pf_icp = s.synth_code.len()
    arm64_emit_cmp_x(s, 10, 11)
    bge_pf_icp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_ldrb_off(s, 9, 10, 0)
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    arm64_emit_add_imm(s, 10, 10, 1)
    arm64_emit_b(s, (pf_icp - s.synth_code.len()) / 4)
    pf_icp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_pf_icp, 10, pf_icp_done)
    // Decimal point '.'
    arm64_emit_movz_x(s, 9, 46, 0)
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    // Emit 6 fractional digits into sp+48..sp+53
    arm64_emit_movz_x(s, 10, 5, 0)
    arm64_emit_movz_x(s, 11, 10, 0)
    arm64_emit_add_imm(s, 14, 31, 48)
    pf_fdig = s.synth_code.len()
    arm64_emit_cmp_x(s, 10, 31)
    blt_pf_fdig = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)
    arm64_emit_udiv_x(s, 12, 19, 11)
    arm64_emit_mul_x(s, 13, 12, 11)
    arm64_emit_sub_x(s, 9, 19, 13)
    arm64_emit_add_imm(s, 9, 9, 48)
    arm64_emit_add_x(s, 15, 14, 10)
    arm64_emit_strb_off(s, 9, 15, 0)
    arm64_emit_mov_reg(s, 19, 12)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_b(s, (pf_fdig - s.synth_code.len()) / 4)
    pf_fdig_done = s.synth_code.len()
    arm64_patch_b_cond(s, blt_pf_fdig, 11, pf_fdig_done)
    // Trim trailing '0' down to minimum length 1
    arm64_emit_movz_x(s, 10, 6, 0)
    arm64_emit_movz_x(s, 11, 1, 0)
    arm64_emit_movz_x(s, 12, 48, 0)
    arm64_emit_add_imm(s, 14, 31, 47)
    pf_trim = s.synth_code.len()
    arm64_emit_cmp_x(s, 10, 11)
    ble_pf_trim = s.synth_code.len()
    arm64_emit_b_cond(s, 13, 0)
    arm64_emit_add_x(s, 15, 14, 10)
    arm64_emit_ldrb_off(s, 9, 15, 0)
    arm64_emit_cmp_x(s, 9, 12)
    bne_pf_trim = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_b(s, (pf_trim - s.synth_code.len()) / 4)
    pf_trim_done = s.synth_code.len()
    arm64_patch_b_cond(s, ble_pf_trim, 13, pf_trim_done)
    arm64_patch_b_cond(s, bne_pf_trim, 1, pf_trim_done)
    // Copy trimmed frac digits into X20
    arm64_emit_movz_x(s, 11, 0, 0)
    arm64_emit_add_imm(s, 14, 31, 48)
    pf_fcp = s.synth_code.len()
    arm64_emit_cmp_x(s, 11, 10)
    bge_pf_fcp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 15, 14, 11)
    arm64_emit_ldrb_off(s, 9, 15, 0)
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    arm64_emit_add_imm(s, 11, 11, 1)
    arm64_emit_b(s, (pf_fcp - s.synth_code.len()) / 4)
    pf_fcp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_pf_fcp, 10, pf_fcp_done)

    // Emit scientific exponent suffix "e+<exp>" / "e-<exp>" when X22 != 0
    arm64_emit_cmp_x(s, 22, 31)
    beq_pf_no_exp = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 101, 0)         // 'e'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    arm64_emit_cmp_x(s, 21, 31)
    bge_pf_epos = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_movz_x(s, 9, 45, 0)          // '-'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    arm64_emit_sub_x(s, 21, 31, 21)         // X21 = -X21
    jmp_pf_esign = s.synth_code.len()
    arm64_emit_b(s, 0)
    pf_epos_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_pf_epos, 10, pf_epos_off)
    arm64_emit_movz_x(s, 9, 43, 0)          // '+'
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    pf_esign_off = s.synth_code.len()
    arm64_patch_b(s, jmp_pf_esign, pf_esign_off)
    // Emit unsigned exponent digits (X21) backwards into sp+48..sp+79, then copy forward
    arm64_emit_add_imm(s, 10, 31, 79)
    arm64_emit_movz_x(s, 11, 10, 0)
    pf_edig = s.synth_code.len()
    arm64_emit_udiv_x(s, 12, 21, 11)
    arm64_emit_mul_x(s, 13, 12, 11)
    arm64_emit_sub_x(s, 9, 21, 13)
    arm64_emit_add_imm(s, 9, 9, 48)
    arm64_emit_strb_off(s, 9, 10, 0)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_mov_reg(s, 21, 12)
    arm64_emit_cmp_x(s, 21, 31)
    arm64_emit_b_cond(s, 1, (pf_edig - s.synth_code.len()) / 4)
    arm64_emit_add_imm(s, 10, 10, 1)
    arm64_emit_add_imm(s, 11, 31, 80)
    pf_ecp = s.synth_code.len()
    arm64_emit_cmp_x(s, 10, 11)
    bge_pf_ecp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_ldrb_off(s, 9, 10, 0)
    arm64_emit_strb_off(s, 9, 20, 0)
    arm64_emit_add_imm(s, 20, 20, 1)
    arm64_emit_add_imm(s, 10, 10, 1)
    arm64_emit_b(s, (pf_ecp - s.synth_code.len()) / 4)
    pf_ecp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_pf_ecp, 10, pf_ecp_done)
    arm64_patch_b_cond(s, beq_pf_no_exp, 0, pf_ecp_done)

    pf_done_off = s.synth_code.len()
    arm64_patch_b(s, jmp_pf_done_nan, pf_done_off)
    arm64_patch_b(s, jmp_pf_done_inf, pf_done_off)
    arm64_patch_b(s, jmp_pf_done_zero, pf_done_off)
    if append_nl == 1
        arm64_emit_movz_x(s, 9, 10, 0)
        arm64_emit_strb_off(s, 9, 20, 0)
        arm64_emit_add_imm(s, 20, 20, 1)
    end
    return 0
end

fn arm64_synth_emit_print_tagged_helpers s
    // WHY: Pure AArch64 integer-only runtime printing for strings, IEEE-754 f64 floats, and dyn_tagged (X0=val, X1=tag).

    // ── __print_str(X0=cstr_ptr) ──
    s.a64_print_str_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_mov_reg(s, 19, 0)            // X19 = ptr
    arm64_emit_cmp_x(s, 19, 31)
    beq_ps_nl = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 0, 0)           // X9 = len
    ps_loop = s.synth_code.len()
    arm64_emit_add_x(s, 10, 19, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_cmp_x(s, 11, 31)
    beq_ps_w = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (ps_loop - s.synth_code.len()) / 4)
    ps_w_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_ps_w, 0, ps_w_off)
    arm64_emit_cmp_x(s, 9, 31)
    beq_ps_nl2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 0, 1, 0)
    arm64_emit_mov_reg(s, 1, 19)
    arm64_emit_mov_reg(s, 2, 9)
    arm64_emit_movz_x(s, 8, 64, 0)
    arm64_emit_svc(s, 0)
    ps_nl_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_ps_nl, 0, ps_nl_off)
    arm64_patch_b_cond(s, beq_ps_nl2, 0, ps_nl_off)
    arm64_emit_movz_x(s, 9, 10, 0)
    arm64_emit_strb_off(s, 9, 31, 24)
    arm64_emit_movz_x(s, 0, 1, 0)
    arm64_emit_add_imm(s, 1, 31, 24)        // X1 = sp + 24
    arm64_emit_movz_x(s, 2, 1, 0)
    arm64_emit_movz_x(s, 8, 64, 0)
    arm64_emit_svc(s, 0)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)

    // ── __print_float(X0=ieee754_f64_bits) ──
    s.a64_print_float_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 128)
    arm64_emit_str_x_off(s, 19, 31, 80)
    arm64_emit_str_x_off(s, 20, 31, 88)
    arm64_emit_str_x_off(s, 21, 31, 96)
    arm64_emit_str_x_off(s, 22, 31, 104)
    arm64_emit_str_x_off(s, 23, 31, 112)
    arm64_emit_mov_reg(s, 19, 0)            // X19 = bits
    arm64_emit_add_imm(s, 20, 31, 16)       // X20 = out cursor (sp + 16 .. sp + 47)
    arm64_emit_format_float_to_stack(s, 1)
    arm64_emit_add_imm(s, 1, 31, 16)        // X1 = sp + 16
    arm64_emit_sub_x(s, 2, 20, 1)           // X2 = len
    arm64_emit_movz_x(s, 0, 1, 0)           // X0 = stdout
    arm64_emit_movz_x(s, 8, 64, 0)          // SYS_write
    arm64_emit_svc(s, 0)
    arm64_emit_ldr_x_off(s, 23, 31, 112)
    arm64_emit_ldr_x_off(s, 22, 31, 104)
    arm64_emit_ldr_x_off(s, 21, 31, 96)
    arm64_emit_ldr_x_off(s, 20, 31, 88)
    arm64_emit_ldr_x_off(s, 19, 31, 80)
    arm64_emit_ldp_post(s, 29, 30, 31, 128)
    arm64_emit_ret(s)

    // ── __print_tagged(X0=val, X1=tag) -> dispatches to __print_str/float/int ──
    s.a64_print_tagged_off = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 2, 0)
    arm64_emit_cmp_x(s, 1, 9)
    bne_pt_not_str = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_b(s, (s.a64_print_str_off - s.synth_code.len()) / 4)
    pt_not_str_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_pt_not_str, 1, pt_not_str_off)
    arm64_emit_movz_x(s, 9, 1, 0)
    arm64_emit_cmp_x(s, 1, 9)
    bne_pt_not_flt = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_b(s, (s.a64_print_float_off - s.synth_code.len()) / 4)
    pt_not_flt_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_pt_not_flt, 1, pt_not_flt_off)
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 16)
    arm64_synth_emit_call_print_int(s)
    arm64_emit_ldp_post(s, 29, 30, 31, 16)
    arm64_emit_ret(s)
    return 0
end

fn arm64_synth_emit_str_helpers s
    // WHY: Sovereign pure-AArch64 string conversion & concatenation helpers (zero libc):
    //   __uint_to_str(X0=u64) -> X0=cstr
    //   __int_to_str(X0=i64)  -> X0=cstr (handles 0, negatives, INT64_MIN cleanly via udiv)
    //   __str_concat(X0=s1, X1=s2) -> X0=cstr
    //   __tagged_to_str(X0=val, X1=tag) -> X0=cstr

    // ── __uint_to_str(X0=uval) -> X0=cstr ──
    s.a64_uint_to_str_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 48)
    arm64_emit_str_x_off(s, 20, 31, 56)
    arm64_emit_mov_reg(s, 19, 0)              // X19 = uval
    arm64_emit_movz_x(s, 11, 10, 0)           // X11 = 10
    arm64_emit_movz_x(s, 12, 0, 0)            // X12 = digit count
    arm64_emit_add_imm(s, 13, 31, 16)         // X13 = sp + 16 (scratch digits)
    arm64_emit_cmp_x(s, 19, 31)
    bne_uts_nz = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_movz_x(s, 15, 48, 0)           // '0'
    arm64_emit_strb_off(s, 15, 13, 0)
    arm64_emit_movz_x(s, 12, 1, 0)
    jmp_uts_alloc = s.synth_code.len()
    arm64_emit_b(s, 0)
    uts_nz_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_uts_nz, 1, uts_nz_off)
    uts_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 19, 31)
    beq_uts_done = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_udiv_x(s, 14, 19, 11)
    arm64_emit_mul_x(s, 15, 14, 11)
    arm64_emit_sub_x(s, 15, 19, 15)
    arm64_emit_add_imm(s, 15, 15, 48)
    arm64_emit_add_x(s, 10, 13, 12)
    arm64_emit_strb_off(s, 15, 10, 0)
    arm64_emit_add_imm(s, 12, 12, 1)
    arm64_emit_mov_reg(s, 19, 14)
    arm64_emit_b(s, (uts_loop - s.synth_code.len()) / 4)
    uts_alloc_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_uts_done, 0, uts_alloc_off)
    arm64_patch_b(s, jmp_uts_alloc, uts_alloc_off)
    arm64_emit_mov_reg(s, 20, 12)             // X20 = count (callee-saved across __alloc)
    arm64_emit_add_imm(s, 0, 20, 1)
    arm64_synth_emit_call_alloc(s)            // X0 = out_ptr
    arm64_emit_add_imm(s, 13, 31, 16)         // X13 = sp + 16
    arm64_emit_movz_x(s, 9, 0, 0)             // X9 = i
    uts_cp = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 20)
    bge_uts_cp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_sub_x(s, 10, 20, 9)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_add_x(s, 10, 13, 10)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 10, 0, 9)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (uts_cp - s.synth_code.len()) / 4)
    uts_cp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_uts_cp, 10, uts_cp_done)
    arm64_emit_add_x(s, 10, 0, 20)
    arm64_emit_strb_off(s, 31, 10, 0)         // NUL terminator
    arm64_emit_ldr_x_off(s, 20, 31, 56)
    arm64_emit_ldr_x_off(s, 19, 31, 48)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── __int_to_str(X0=val) -> X0=cstr ──
    s.a64_int_to_str_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 48)
    arm64_emit_str_x_off(s, 20, 31, 56)
    arm64_emit_movz_x(s, 20, 0, 0)            // X20 = is_neg (0)
    arm64_emit_mov_reg(s, 19, 0)              // X19 = uval
    arm64_emit_cmp_x(s, 0, 31)
    bge_its_pos = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)               // b.ge positive
    arm64_emit_movz_x(s, 20, 1, 0)            // X20 = 1 (negative)
    arm64_emit_sub_x(s, 19, 31, 0)            // X19 = 0 - X0 (exact unsigned abs even for INT64_MIN)
    its_pos_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_its_pos, 10, its_pos_off)
    arm64_emit_movz_x(s, 11, 10, 0)           // X11 = 10
    arm64_emit_movz_x(s, 12, 0, 0)            // X12 = count
    arm64_emit_add_imm(s, 13, 31, 16)         // X13 = sp + 16
    arm64_emit_cmp_x(s, 19, 31)
    bne_its_nz = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_movz_x(s, 15, 48, 0)
    arm64_emit_strb_off(s, 15, 13, 0)
    arm64_emit_movz_x(s, 12, 1, 0)
    jmp_its_alloc = s.synth_code.len()
    arm64_emit_b(s, 0)
    its_nz_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_its_nz, 1, its_nz_off)
    its_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 19, 31)
    beq_its_done = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_udiv_x(s, 14, 19, 11)
    arm64_emit_mul_x(s, 15, 14, 11)
    arm64_emit_sub_x(s, 15, 19, 15)
    arm64_emit_add_imm(s, 15, 15, 48)
    arm64_emit_add_x(s, 10, 13, 12)
    arm64_emit_strb_off(s, 15, 10, 0)
    arm64_emit_add_imm(s, 12, 12, 1)
    arm64_emit_mov_reg(s, 19, 14)
    arm64_emit_b(s, (its_loop - s.synth_code.len()) / 4)
    its_alloc_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_its_done, 0, its_alloc_off)
    arm64_patch_b(s, jmp_its_alloc, its_alloc_off)
    arm64_emit_mov_reg(s, 19, 12)             // X19 = digit count
    arm64_emit_add_x(s, 0, 19, 20)
    arm64_emit_add_imm(s, 0, 0, 1)
    arm64_synth_emit_call_alloc(s)            // X0 = out_ptr
    arm64_emit_movz_x(s, 14, 0, 0)            // X14 = write offset
    arm64_emit_cmp_x(s, 20, 31)
    beq_its_nosign = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 15, 45, 0)           // '-'
    arm64_emit_strb_off(s, 15, 0, 0)
    arm64_emit_movz_x(s, 14, 1, 0)
    its_nosign_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_its_nosign, 0, its_nosign_off)
    arm64_emit_add_imm(s, 13, 31, 16)         // X13 = sp + 16
    arm64_emit_movz_x(s, 9, 0, 0)             // X9 = i
    its_cp = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 19)
    bge_its_cp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_sub_x(s, 10, 19, 9)
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_add_x(s, 10, 13, 10)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 12, 14, 9)
    arm64_emit_add_x(s, 10, 0, 12)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (its_cp - s.synth_code.len()) / 4)
    its_cp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_its_cp, 10, its_cp_done)
    arm64_emit_add_x(s, 12, 14, 19)
    arm64_emit_add_x(s, 10, 0, 12)
    arm64_emit_strb_off(s, 31, 10, 0)         // NUL terminator
    arm64_emit_ldr_x_off(s, 20, 31, 56)
    arm64_emit_ldr_x_off(s, 19, 31, 48)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── __str_concat(X0=s1, X1=s2) -> X0=cstr ──
    s.a64_str_concat_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_str_x_off(s, 20, 31, 24)
    arm64_emit_str_x_off(s, 21, 31, 32)
    arm64_emit_str_x_off(s, 22, 31, 40)
    arm64_emit_mov_reg(s, 19, 0)              // X19 = s1
    arm64_emit_mov_reg(s, 20, 1)              // X20 = s2
    arm64_emit_movz_x(s, 21, 0, 0)            // X21 = len1
    arm64_emit_cmp_x(s, 19, 31)
    beq_sc_l1d = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    sc_l1 = s.synth_code.len()
    arm64_emit_add_x(s, 10, 19, 21)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_cmp_x(s, 11, 31)
    beq_sc_l1d2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_add_imm(s, 21, 21, 1)
    arm64_emit_b(s, (sc_l1 - s.synth_code.len()) / 4)
    sc_l1_done = s.synth_code.len()
    arm64_patch_b_cond(s, beq_sc_l1d, 0, sc_l1_done)
    arm64_patch_b_cond(s, beq_sc_l1d2, 0, sc_l1_done)
    arm64_emit_movz_x(s, 22, 0, 0)            // X22 = len2
    arm64_emit_cmp_x(s, 20, 31)
    beq_sc_l2d = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    sc_l2 = s.synth_code.len()
    arm64_emit_add_x(s, 10, 20, 22)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_cmp_x(s, 11, 31)
    beq_sc_l2d2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_add_imm(s, 22, 22, 1)
    arm64_emit_b(s, (sc_l2 - s.synth_code.len()) / 4)
    sc_l2_done = s.synth_code.len()
    arm64_patch_b_cond(s, beq_sc_l2d, 0, sc_l2_done)
    arm64_patch_b_cond(s, beq_sc_l2d2, 0, sc_l2_done)
    arm64_emit_add_x(s, 0, 21, 22)
    arm64_emit_add_imm(s, 0, 0, 1)
    arm64_synth_emit_call_alloc(s)            // X0 = out
    arm64_emit_movz_x(s, 9, 0, 0)
    sc_cp1 = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 21)
    bge_sc_cp1 = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 10, 19, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 10, 0, 9)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (sc_cp1 - s.synth_code.len()) / 4)
    sc_cp1_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_sc_cp1, 10, sc_cp1_done)
    arm64_emit_movz_x(s, 9, 0, 0)
    sc_cp2 = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 22)
    bge_sc_cp2 = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 10, 20, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 12, 21, 9)
    arm64_emit_add_x(s, 10, 0, 12)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (sc_cp2 - s.synth_code.len()) / 4)
    sc_cp2_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_sc_cp2, 10, sc_cp2_done)
    arm64_emit_add_x(s, 12, 21, 22)
    arm64_emit_add_x(s, 10, 0, 12)
    arm64_emit_strb_off(s, 31, 10, 0)
    arm64_emit_ldr_x_off(s, 22, 31, 40)
    arm64_emit_ldr_x_off(s, 21, 31, 32)
    arm64_emit_ldr_x_off(s, 20, 31, 24)
    arm64_emit_ldr_x_off(s, 19, 31, 16)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)

    // ── __float_to_str(X0=ieee754_f64_bits) -> X0=cstr ──
    s.a64_float_to_str_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 128)
    arm64_emit_str_x_off(s, 19, 31, 80)
    arm64_emit_str_x_off(s, 20, 31, 88)
    arm64_emit_str_x_off(s, 21, 31, 96)
    arm64_emit_str_x_off(s, 22, 31, 104)
    arm64_emit_str_x_off(s, 23, 31, 112)
    arm64_emit_mov_reg(s, 19, 0)
    arm64_emit_add_imm(s, 20, 31, 16)
    arm64_emit_format_float_to_stack(s, 0)
    arm64_emit_add_imm(s, 19, 31, 16)         // X19 = sp + 16
    arm64_emit_sub_x(s, 21, 20, 19)           // X21 = formatted byte len
    arm64_emit_add_imm(s, 0, 21, 1)
    arm64_synth_emit_call_alloc(s)            // X0 = out_ptr
    arm64_emit_movz_x(s, 9, 0, 0)
    fts_cp = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 21)
    bge_fts_cp = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_add_x(s, 10, 19, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_add_x(s, 10, 0, 9)
    arm64_emit_strb_off(s, 11, 10, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (fts_cp - s.synth_code.len()) / 4)
    fts_cp_done = s.synth_code.len()
    arm64_patch_b_cond(s, bge_fts_cp, 10, fts_cp_done)
    arm64_emit_add_x(s, 10, 0, 21)
    arm64_emit_strb_off(s, 31, 10, 0)
    arm64_emit_ldr_x_off(s, 23, 31, 112)
    arm64_emit_ldr_x_off(s, 22, 31, 104)
    arm64_emit_ldr_x_off(s, 21, 31, 96)
    arm64_emit_ldr_x_off(s, 20, 31, 88)
    arm64_emit_ldr_x_off(s, 19, 31, 80)
    arm64_emit_ldp_post(s, 29, 30, 31, 128)
    arm64_emit_ret(s)

    // ── __tagged_to_str(X0=val, X1=tag) -> X0=cstr ──
    s.a64_tagged_to_str_off = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 2, 0)
    arm64_emit_cmp_x(s, 1, 9)
    bne_tts_chk_flt = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_ret(s)                         // tag == 2: already a cstr in X0!
    tts_chk_flt_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_tts_chk_flt, 1, tts_chk_flt_off)
    arm64_emit_movz_x(s, 9, 1, 0)
    arm64_emit_cmp_x(s, 1, 9)
    bne_tts_int = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_b(s, (s.a64_float_to_str_off - s.synth_code.len()) / 4)
    tts_int_off = s.synth_code.len()
    arm64_patch_b_cond(s, bne_tts_int, 1, tts_int_off)
    arm64_emit_b(s, (s.a64_int_to_str_off - s.synth_code.len()) / 4)
    return 0
end

fn arm64_synth_emit_uncaught_throw_helper s
    // WHY: Hosted-mode uncaught exception handler (X27=tag+1, X28=val): formats payload via
    // __tagged_to_str, writes "Uncaught exception: <val>\n" to stderr (fd 2), and exits with code 1
    // (exact x86_64 parity; never exits 0 on `throw 0`).
    s.a64_uncaught_throw_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_str_x_off(s, 19, 31, 16)
    arm64_emit_mov_reg(s, 0, 28)
    arm64_emit_sub_imm(s, 1, 27, 1)           // X1 = tag (0=int, 1=float, 2=str)
    arm64_synth_emit_call_helper(s, "__tagged_to_str")
    arm64_emit_mov_reg(s, 19, 0)              // X19 = formatted cstr
    // Write prefix "Uncaught exception: " (20 bytes) to stderr (fd 2)
    arm64_emit_movz_x(s, 0, 2, 0)
    arm64_emit_load_rodata_str(s, 1, "Uncaught exception: ")
    arm64_emit_movz_x(s, 2, 20, 0)
    arm64_emit_movz_x(s, 8, 64, 0)
    arm64_emit_svc(s, 0)
    // Compute strlen(X19) in X9 and write value to stderr (fd 2)
    arm64_emit_cmp_x(s, 19, 31)
    beq_ut_nl = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 0, 0)
    ut_len_loop = s.synth_code.len()
    arm64_emit_add_x(s, 10, 19, 9)
    arm64_emit_ldrb_off(s, 11, 10, 0)
    arm64_emit_cmp_x(s, 11, 31)
    beq_ut_write = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (ut_len_loop - s.synth_code.len()) / 4)
    ut_write_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_ut_write, 0, ut_write_off)
    arm64_emit_cmp_x(s, 9, 31)
    beq_ut_nl2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 0, 2, 0)
    arm64_emit_mov_reg(s, 1, 19)
    arm64_emit_mov_reg(s, 2, 9)
    arm64_emit_movz_x(s, 8, 64, 0)
    arm64_emit_svc(s, 0)
    ut_nl_off = s.synth_code.len()
    arm64_patch_b_cond(s, beq_ut_nl, 0, ut_nl_off)
    arm64_patch_b_cond(s, beq_ut_nl2, 0, ut_nl_off)
    // Write trailing '\n' to stderr (fd 2)
    arm64_emit_movz_x(s, 9, 10, 0)
    arm64_emit_strb_off(s, 9, 31, 24)
    arm64_emit_movz_x(s, 0, 2, 0)
    arm64_emit_add_imm(s, 1, 31, 24)
    arm64_emit_movz_x(s, 2, 1, 0)
    arm64_emit_movz_x(s, 8, 64, 0)
    arm64_emit_svc(s, 0)
    // Exit process with status code 1 via Linux SYS_exit_group (94)
    arm64_emit_movz_x(s, 0, 1, 0)
    arm64_emit_movz_x(s, 8, 94, 0)
    arm64_emit_svc(s, 0)
    return 0
end

fn arm64_synth_emit_stack_trace_helper s
    // WHY: Real AArch64 frame-pointer walker resolving live call chain against LSYM0 .rodata table
    // into "  at <fn_name> (line <decl_line>)\n" — exact x86_64 stack_trace() parity!
    s.a64_stack_trace_off = s.synth_code.len()
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 128)
    arm64_emit_str_x_off(s, 19, 31, 64)
    arm64_emit_str_x_off(s, 20, 31, 72)
    arm64_emit_str_x_off(s, 21, 31, 80)
    arm64_emit_str_x_off(s, 22, 31, 88)
    arm64_emit_str_x_off(s, 23, 31, 96)
    arm64_emit_str_x_off(s, 24, 31, 104)
    arm64_emit_str_x_off(s, 25, 31, 112)
    arm64_emit_str_x_off(s, 26, 31, 120)
    // Capture immediate caller PC (X30) and frame pointer (X29)
    arm64_emit_mov_reg(s, 19, 30)           // X19 = cur_pc
    arm64_emit_mov_reg(s, 20, 29)           // X20 = cur_fp
    arm64_emit_movz_x(s, 0, 256, 0)
    arm64_synth_emit_call_helper(s, "__buf_new")
    arm64_emit_mov_reg(s, 21, 0)            // X21 = buf
    // Load patched LSYM0 table, code_base, rodata_base virtual addresses
    s.a64_lsym_patch_lsym = s.synth_code.len()
    arm64_emit_movz_x(s, 22, 0, 0)
    arm64_emit_movk_x(s, 22, 0, 16)
    arm64_emit_movk_x(s, 22, 0, 32)
    arm64_emit_movk_x(s, 22, 0, 48)
    // Compute code_base PC-relatively via ADR so stack_trace() works under macOS PIE ASLR AND Linux ELF64!
    adr_code_off = s.synth_code.len()
    arm64_emit_adr(s, 23, 0 - adr_code_off)
    s.a64_lsym_patch_ro = s.synth_code.len()
    arm64_emit_movz_x(s, 24, 0, 0)
    arm64_emit_movk_x(s, 24, 0, 16)
    arm64_emit_movk_x(s, 24, 0, 32)
    arm64_emit_movk_x(s, 24, 0, 48)
    arm64_emit_movz_x(s, 25, 0, 0)          // X25 = depth = 0
    st_frame_loop = s.synth_code.len()
    arm64_emit_movz_x(s, 9, 16, 0)
    arm64_emit_cmp_x(s, 25, 9)
    bge_st_done1 = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_cmp_x(s, 19, 23)
    blo_st_skip = s.synth_code.len()
    arm64_emit_b_cond(s, 3, 0)              // b.lo skip (unsigned < code_base)
    arm64_emit_sub_x(s, 26, 19, 23)
    arm64_emit_sub_imm(s, 26, 26, 4)        // X26 = rel_pc of call site
    arm64_emit_ldr_w_off(s, 10, 22, 8)      // X10 = fcnt
    arm64_emit_movz_x(s, 9, 0, 0)           // X9 = i = 0
    st_sym_loop = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 10)
    bge_st_sym_done = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)
    arm64_emit_movz_x(s, 11, 24, 0)
    arm64_emit_mul_x(s, 11, 9, 11)
    arm64_emit_add_imm(s, 11, 11, 16)
    arm64_emit_add_x(s, 11, 22, 11)         // X11 = &entry[i]
    arm64_emit_ldr_w_off(s, 12, 11, 0)      // start_off
    arm64_emit_cmp_x(s, 26, 12)
    blo_st_sym_next1 = s.synth_code.len()
    arm64_emit_b_cond(s, 3, 0)
    arm64_emit_ldr_w_off(s, 12, 11, 4)      // end_off
    arm64_emit_cmp_x(s, 26, 12)
    bhs_st_sym_next2 = s.synth_code.len()
    arm64_emit_b_cond(s, 2, 0)
    // Matched function! Save name_ptr at [sp,#48], decl_line at X26
    arm64_emit_ldr_w_off(s, 12, 11, 8)
    arm64_emit_add_x(s, 12, 24, 12)
    arm64_emit_str_x_off(s, 12, 31, 48)
    arm64_emit_ldr_w_off(s, 26, 11, 12)
    // Append "  at " + name + " (line " + dec(decl_line) + ")\n"
    arm64_emit_mov_reg(s, 0, 21)
    arm64_emit_load_rodata_str(s, 1, "  at ")
    arm64_synth_emit_call_helper(s, "__buf_write_str")
    arm64_emit_mov_reg(s, 0, 21)
    arm64_emit_ldr_x_off(s, 1, 31, 48)
    arm64_synth_emit_call_helper(s, "__buf_write_str")
    arm64_emit_mov_reg(s, 0, 21)
    arm64_emit_load_rodata_str(s, 1, " (line ")
    arm64_synth_emit_call_helper(s, "__buf_write_str")
    // Format decl_line (X26) backwards into sp+16..sp+47 (null-terminated at sp+47)
    arm64_emit_add_imm(s, 10, 31, 47)
    arm64_emit_strb_off(s, 31, 10, 0)
    arm64_emit_movz_x(s, 11, 10, 0)
    st_ldig = s.synth_code.len()
    arm64_emit_sub_imm(s, 10, 10, 1)
    arm64_emit_udiv_x(s, 12, 26, 11)
    arm64_emit_mul_x(s, 13, 12, 11)
    arm64_emit_sub_x(s, 9, 26, 13)
    arm64_emit_add_imm(s, 9, 9, 48)
    arm64_emit_strb_off(s, 9, 10, 0)
    arm64_emit_mov_reg(s, 26, 12)
    arm64_emit_cmp_x(s, 26, 31)
    arm64_emit_b_cond(s, 1, (st_ldig - s.synth_code.len()) / 4)
    arm64_emit_mov_reg(s, 0, 21)
    arm64_emit_mov_reg(s, 1, 10)
    arm64_synth_emit_call_helper(s, "__buf_write_str")
    arm64_emit_mov_reg(s, 0, 21)
    arm64_emit_load_rodata_str(s, 1, ")\n")
    arm64_synth_emit_call_helper(s, "__buf_write_str")
    jmp_st_next_frame = s.synth_code.len()
    arm64_emit_b(s, 0)
    st_sym_next_off = s.synth_code.len()
    arm64_patch_b_cond(s, blo_st_sym_next1, 3, st_sym_next_off)
    arm64_patch_b_cond(s, bhs_st_sym_next2, 2, st_sym_next_off)
    arm64_emit_add_imm(s, 9, 9, 1)
    arm64_emit_b(s, (st_sym_loop - s.synth_code.len()) / 4)
    st_next_frame_off = s.synth_code.len()
    arm64_patch_b_cond(s, blo_st_skip, 3, st_next_frame_off)
    arm64_patch_b_cond(s, bge_st_sym_done, 10, st_next_frame_off)
    arm64_patch_b(s, jmp_st_next_frame, st_next_frame_off)
    // Advance to caller frame: pc = [fp + 8], fp = [fp + 0]
    arm64_emit_cmp_x(s, 20, 31)
    beq_st_done2 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_movz_x(s, 9, 7, 0)
    arm64_emit_and_x(s, 9, 20, 9)
    arm64_emit_cmp_x(s, 9, 31)
    bne_st_done3 = s.synth_code.len()
    arm64_emit_b_cond(s, 1, 0)
    arm64_emit_ldr_x_off(s, 19, 20, 8)
    arm64_emit_ldr_x_off(s, 10, 20, 0)
    arm64_emit_cmp_x(s, 10, 20)
    beq_st_done4 = s.synth_code.len()
    arm64_emit_b_cond(s, 0, 0)
    arm64_emit_mov_reg(s, 20, 10)
    arm64_emit_add_imm(s, 25, 25, 1)
    arm64_emit_b(s, (st_frame_loop - s.synth_code.len()) / 4)
    st_done_off = s.synth_code.len()
    arm64_patch_b_cond(s, bge_st_done1, 10, st_done_off)
    arm64_patch_b_cond(s, beq_st_done2, 0, st_done_off)
    arm64_patch_b_cond(s, bne_st_done3, 1, st_done_off)
    arm64_patch_b_cond(s, beq_st_done4, 0, st_done_off)
    arm64_emit_mov_reg(s, 0, 21)
    arm64_synth_emit_call_helper(s, "__buf_to_str")
    arm64_emit_ldr_x_off(s, 26, 31, 120)
    arm64_emit_ldr_x_off(s, 25, 31, 112)
    arm64_emit_ldr_x_off(s, 24, 31, 104)
    arm64_emit_ldr_x_off(s, 23, 31, 96)
    arm64_emit_ldr_x_off(s, 22, 31, 88)
    arm64_emit_ldr_x_off(s, 21, 31, 80)
    arm64_emit_ldr_x_off(s, 20, 31, 72)
    arm64_emit_ldr_x_off(s, 19, 31, 64)
    arm64_emit_ldp_post(s, 29, 30, 31, 128)
    arm64_emit_ret(s)
    return 0
end
