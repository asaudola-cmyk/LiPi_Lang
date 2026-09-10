// ============================================================
// c_codegen.lp -- Lipi Self-Hosting Compiler (Bootstrap Step 3)
// WHY: This file makes Lipi fully independent from Python.
//      Written entirely in Lipi, compiles .lp -> C -> native binary.
//      When this file can compile itself, Lipi achieves full bootstrap.
//
// Usage:
//   lipi src/compiler/c_codegen.lp input.lp output.c
//   gcc output.c -I src/compiler/ -lm -o myprogram
//   ./myprogram   <- No Python at runtime!
// ============================================================

// Token type constants
TT_NUM    = 1
TT_STR    = 2
TT_IDENT  = 3
TT_KW     = 4
TT_OP     = 5
TT_NL     = 6
TT_INDENT = 7
TT_DEDENT = 8
TT_EOF    = 9

// AST node type constants
NT_ASSIGN    = 1
NT_FNDEF     = 2
NT_FNCALL    = 3
NT_RETURN    = 4
NT_IF        = 5
NT_WHILE     = 6
NT_FOR_RNG   = 7
NT_FOREACH   = 8
NT_REPEAT    = 9
NT_BINOP     = 10
NT_UNARY     = 11
NT_IDENT_N   = 12
NT_NUM_N     = 13
NT_STR_N     = 14
NT_BOOL_N    = 15
NT_NULL_N    = 16
NT_STRUCT    = 17
NT_FIELD_GET = 18
NT_FIELD_SET = 19
NT_BREAK     = 20
NT_CONTINUE  = 21

// Global keyword list -- created once at startup
KEYWORDS = list("fn", "if", "elif", "else", "while", "for", "in", "repeat", "return", "say", "show", "print", "println", "struct", "include", "break", "continue", "and", "or", "not", "null", "nil", "true", "false", "each", "step")

fn is_kw word
    for kw in KEYWORDS
        if kw == word return 1
    return 0

fn is_digit c
    code = ord(c)
    if code >= 48 and code <= 57 return 1
    if code >= 2534 and code <= 2543 return 1
    return 0

fn is_alpha c
    code = ord(c)
    if code >= 65 and code <= 90 return 1
    if code >= 97 and code <= 122 return 1
    if c == "_" return 1
    if code > 127 return 1
    return 0

fn is_alnum c
    if is_alpha(c) == 1 return 1
    if is_digit(c) == 1 return 1
    return 0

fn is_space c
    if c == " " return 1
    if c == "\t" return 1
    return 0

fn c_ident name
    // Convert Lipi identifier to valid C name
    // WHY: Prefix with u_ avoids ALL C stdlib name conflicts.
    //      Non-ASCII chars encoded as _xNNN_.
    result = "u_"
    i = 0
    while i < len(name)
        c = char_at(name, i)
        code = ord(c)
        if code <= 127 and (is_alnum(c) == 1 or c == "_")
            result = result + c
        else
            result = result + "_x" + str(code) + "_"
        i = i + 1
    if len(result) == 2
        result = "u__empty_"
    return result

// Integer stack for indent tracking
// Format: [size, val0, val1, ...]
// WHY: Lists are mutable by reference -- ist_pop/push work in place
fn ist_new
    s = list()
    push(s, 1)
    push(s, 0)
    return s

fn ist_top s
    sz = get(s, 0)
    return get(s, sz)

fn ist_push_v s val
    sz = get(s, 0)
    new_sz = sz + 1
    list_set(s, 0, new_sz)
    if new_sz < len(s)
        list_set(s, new_sz, val)
    else
        push(s, val)

fn ist_pop s
    sz = get(s, 0)
    if sz > 1
        list_set(s, 0, sz - 1)

fn ist_size s = get(s, 0)

// Token: [type, value, line]
fn tok_new tt tv tl
    t = list()
    push(t, tt)
    push(t, tv)
    push(t, tl)
    return t

fn tok_type t = get(t, 0)
fn tok_val  t = get(t, 1)

// Lexer
fn lex_char src p
    if p >= len(src) return ""
    return char_at(src, p)

fn lex_peek2 src p
    if p + 1 >= len(src) return ""
    return char_at(src, p + 1)

fn is_blank_line src p
    slen = len(src)
    while p < slen
        c = char_at(src, p)
        if c == "\n" return 1
        if c == "/" and p + 1 < slen and char_at(src, p + 1) == "/" return 1
        if c == "#" return 1
        if is_space(c) == 0 return 0
        p = p + 1
    return 1

fn count_spaces src p
    count = 0
    slen = len(src)
    while p < slen
        c = char_at(src, p)
        if c == " "
            count = count + 1
            p = p + 1
        elif c == "\t"
            count = count + 4
            p = p + 1
        else
            return count
    return count

fn tokenize src
    tokens = list()
    slen = len(src)
    p_ref = list(0)
    ln_ref = list(1)
    indent_stk = ist_new()


    while get(p_ref, 0) < slen
        p = get(p_ref, 0)
        c = lex_char(src, p)

        if c == "\r"
            list_set(p_ref, 0, p + 1)
            continue

        if c == "\n"
            list_set(p_ref, 0, p + 1)
            list_set(ln_ref, 0, get(ln_ref, 0) + 1)
            np = get(p_ref, 0)
            if is_blank_line(src, np) == 1
                continue
            push(tokens, tok_new(TT_NL, "\n", get(ln_ref, 0)))
            new_lvl = count_spaces(src, np)
            cur_lvl = ist_top(indent_stk)
            if new_lvl > cur_lvl
                ist_push_v(indent_stk, new_lvl)
                push(tokens, tok_new(TT_INDENT, "", get(ln_ref, 0)))
            elif new_lvl < cur_lvl
                while ist_top(indent_stk) > new_lvl and ist_size(indent_stk) > 1
                    ist_pop(indent_stk)
                    push(tokens, tok_new(TT_DEDENT, "", get(ln_ref, 0)))
            continue

        if is_space(c) == 1
            list_set(p_ref, 0, p + 1)
            continue

        if c == "/" and lex_peek2(src, p) == "/"
            while get(p_ref, 0) < slen and lex_char(src, get(p_ref, 0)) != "\n"
                list_set(p_ref, 0, get(p_ref, 0) + 1)
            continue

        if c == "#"
            while get(p_ref, 0) < slen and lex_char(src, get(p_ref, 0)) != "\n"
                list_set(p_ref, 0, get(p_ref, 0) + 1)
            continue

        if c == "\""
            list_set(p_ref, 0, p + 1)
            sv = ""
            while get(p_ref, 0) < slen
                sc = lex_char(src, get(p_ref, 0))
                if sc == "\\"
                    list_set(p_ref, 0, get(p_ref, 0) + 1)
                    esc = lex_char(src, get(p_ref, 0))
                    if esc == "n" sv = sv + "\n"
                    elif esc == "t" sv = sv + "\t"
                    elif esc == "\\" sv = sv + "\\"
                    elif esc == "\"" sv = sv + "\""
                    else sv = sv + esc
                    list_set(p_ref, 0, get(p_ref, 0) + 1)
                elif sc == "\""
                    list_set(p_ref, 0, get(p_ref, 0) + 1)
                    break
                else
                    sv = sv + sc
                    list_set(p_ref, 0, get(p_ref, 0) + 1)
            push(tokens, tok_new(TT_STR, sv, get(ln_ref, 0)))
            continue

        if is_digit(c) == 1
            nv = ""
            while get(p_ref, 0) < slen
                nc = lex_char(src, get(p_ref, 0))
                // WHY: Stop at '..' — range operator, not decimal point
                // e.g. "2..50" → NUM "2", OP "..", NUM "50"
                if nc == "." and lex_peek2(src, get(p_ref, 0)) == "."
                    break
                if is_digit(nc) == 1 or nc == "."
                    nc_code = ord(nc)
                    if nc_code >= 2534 and nc_code <= 2543
                        nv = nv + str(nc_code - 2534)
                    else
                        nv = nv + nc
                    list_set(p_ref, 0, get(p_ref, 0) + 1)
                else
                    break
            push(tokens, tok_new(TT_NUM, nv, get(ln_ref, 0)))
            continue


        if is_alpha(c) == 1
            word = ""
            while get(p_ref, 0) < slen and is_alnum(lex_char(src, get(p_ref, 0))) == 1
                word = word + lex_char(src, get(p_ref, 0))
                list_set(p_ref, 0, get(p_ref, 0) + 1)
            if word == "null" or word == "nil"
                push(tokens, tok_new(TT_KW, "null", get(ln_ref, 0)))
            elif word == "true"
                push(tokens, tok_new(TT_KW, "true", get(ln_ref, 0)))
            elif word == "false"
                push(tokens, tok_new(TT_KW, "false", get(ln_ref, 0)))
            elif is_kw(word) == 1
                push(tokens, tok_new(TT_KW, word, get(ln_ref, 0)))
            else
                push(tokens, tok_new(TT_IDENT, word, get(ln_ref, 0)))
            continue

        if c == "=" and lex_peek2(src, p) == "="
            list_set(p_ref, 0, p + 2)
            push(tokens, tok_new(TT_OP, "==", get(ln_ref, 0)))
            continue
        if c == "!" and lex_peek2(src, p) == "="
            list_set(p_ref, 0, p + 2)
            push(tokens, tok_new(TT_OP, "!=", get(ln_ref, 0)))
            continue
        if c == "<" and lex_peek2(src, p) == "="
            list_set(p_ref, 0, p + 2)
            push(tokens, tok_new(TT_OP, "<=", get(ln_ref, 0)))
            continue
        if c == ">" and lex_peek2(src, p) == "="
            list_set(p_ref, 0, p + 2)
            push(tokens, tok_new(TT_OP, ">=", get(ln_ref, 0)))
            continue
        if c == "." and lex_peek2(src, p) == "."
            list_set(p_ref, 0, p + 2)
            push(tokens, tok_new(TT_OP, "..", get(ln_ref, 0)))
            continue

        if contains("+-*/%=<>()[]{}.,;:", c) == 1
            list_set(p_ref, 0, p + 1)
            push(tokens, tok_new(TT_OP, c, get(ln_ref, 0)))
            continue

        list_set(p_ref, 0, p + 1)

    while ist_size(indent_stk) > 1
        ist_pop(indent_stk)
        push(tokens, tok_new(TT_DEDENT, "", get(ln_ref, 0)))

    push(tokens, tok_new(TT_EOF, "", get(ln_ref, 0)))
    return tokens

// Parser state: [pos, tokens_list]
// WHY: List is mutable by reference -- ps_adv mutates pos in place globally
fn ps_new tokens
    s = list()
    push(s, 0)
    push(s, tokens)
    return s

fn ps_pos s = get(s, 0)
fn ps_toks s = get(s, 1)
fn ps_len s = len(ps_toks(s))

fn ps_cur s
    p = ps_pos(s)
    if p >= ps_len(s) return null
    return get(ps_toks(s), p)

fn ps_peek_n s n
    p = ps_pos(s) + n
    if p >= ps_len(s) return null
    return get(ps_toks(s), p)

fn ps_adv s
    list_set(s, 0, ps_pos(s) + 1)

fn ps_skip_nl s
    while ps_cur(s) != null and tok_type(ps_cur(s)) == TT_NL
        ps_adv(s)

fn ps_is_kw s kw
    t = ps_cur(s)
    if t == null return 0
    if tok_type(t) == TT_KW and tok_val(t) == kw return 1
    return 0

fn ps_is_op s op
    t = ps_cur(s)
    if t == null return 0
    if tok_type(t) == TT_OP and tok_val(t) == op return 1
    return 0

fn ps_is_tt s tt
    t = ps_cur(s)
    if t == null return 0
    if tok_type(t) == tt return 1
    return 0

fn ps_eat_kw s kw
    t = ps_cur(s)
    if t == null return 0
    if tok_type(t) == TT_KW and tok_val(t) == kw
        ps_adv(s)
        return 1
    return 0

fn ps_eat_op s op
    t = ps_cur(s)
    if t == null return 0
    if tok_type(t) == TT_OP and tok_val(t) == op
        ps_adv(s)
        return 1
    return 0

fn ps_eat_ident s
    t = ps_cur(s)
    if t == null return ""
    if tok_type(t) == TT_IDENT
        ps_adv(s)
        return tok_val(t)
    return ""

fn ps_is_ident s
    t = ps_cur(s)
    if t == null return 0
    if tok_type(t) == TT_IDENT return 1
    return 0

// AST node kind accessor
fn n_kind node
    if node == null return 0
    return get(node, 0)

// Parse a block -- returns list of statement nodes
fn parse_block ps
    ps_skip_nl(ps)
    stmts = list()
    if ps_is_tt(ps, TT_INDENT) == 1
        ps_adv(ps)
        while ps_cur(ps) != null
            ps_skip_nl(ps)
            t = ps_cur(ps)
            if t == null break
            if tok_type(t) == TT_DEDENT
                ps_adv(ps)
                break
            if tok_type(t) == TT_EOF break
            stmt = parse_stmt(ps)
            if stmt != null push(stmts, stmt)
    else
        stmt = parse_stmt(ps)
        if stmt != null push(stmts, stmt)
    return stmts

fn parse_stmt ps
    ps_skip_nl(ps)
    t = ps_cur(ps)
    if t == null return null
    if tok_type(t) == TT_EOF return null
    if tok_type(t) == TT_DEDENT return null

    tt = tok_type(t)
    tv = tok_val(t)

    // struct definition
    if tt == TT_KW and tv == "struct"
        ps_adv(ps)
        name = ps_eat_ident(ps)
        fields = list()
        ps_skip_nl(ps)
        if ps_is_tt(ps, TT_INDENT) == 1
            ps_adv(ps)
            while ps_cur(ps) != null and ps_is_tt(ps, TT_DEDENT) == 0
                ps_skip_nl(ps)
                if ps_is_ident(ps) == 1
                    push(fields, ps_eat_ident(ps))
                else
                    ps_adv(ps)
            if ps_is_tt(ps, TT_DEDENT) == 1 ps_adv(ps)
        return list(NT_STRUCT, name, fields)

    // fn definition
    if tt == TT_KW and tv == "fn"
        ps_adv(ps)
        name = ps_eat_ident(ps)
        params = list()
        while ps_is_ident(ps) == 1
            push(params, ps_eat_ident(ps))
        if ps_eat_op(ps, "=") == 1
            body_expr = parse_expr(ps)
            body = list(list(NT_RETURN, body_expr))
            return list(NT_FNDEF, name, params, body)
        body = parse_block(ps)
        return list(NT_FNDEF, name, params, body)

    // return
    if tt == TT_KW and tv == "return"
        ps_adv(ps)
        if ps_is_tt(ps, TT_NL) == 1 or ps_is_tt(ps, TT_EOF) == 1
            return list(NT_RETURN, list(NT_NULL_N))
        val = parse_expr(ps)
        return list(NT_RETURN, val)

    // if / elif / else
    if tt == TT_KW and tv == "if"
        ps_adv(ps)
        cond = parse_expr(ps)
        then_b = parse_block(ps)
        elifs = list()
        else_b = null
        while ps_is_kw(ps, "elif") == 1
            ps_adv(ps)
            ec = parse_expr(ps)
            eb = parse_block(ps)
            push(elifs, list(ec, eb))
        if ps_is_kw(ps, "else") == 1
            ps_adv(ps)
            else_b = parse_block(ps)
        return list(NT_IF, cond, then_b, elifs, else_b)

    // while
    if tt == TT_KW and tv == "while"
        ps_adv(ps)
        cond = parse_expr(ps)
        body = parse_block(ps)
        return list(NT_WHILE, cond, body)

    // repeat N
    if tt == TT_KW and tv == "repeat"
        ps_adv(ps)
        cnt = parse_expr(ps)
        body = parse_block(ps)
        return list(NT_REPEAT, cnt, body)

    // for / each
    if tt == TT_KW and (tv == "for" or tv == "each")
        ps_adv(ps)
        var_nm = ps_eat_ident(ps)
        ps_eat_kw(ps, "in")
        start_e = parse_add(ps)
        if ps_is_op(ps, "..") == 1
            ps_adv(ps)
            end_e = parse_add(ps)
            step_e = null
            if ps_is_kw(ps, "step") == 1
                ps_adv(ps)
                step_e = parse_primary(ps)
            body = parse_block(ps)
            return list(NT_FOR_RNG, var_nm, start_e, end_e, step_e, body)
        else
            body = parse_block(ps)
            return list(NT_FOREACH, var_nm, start_e, body)

    // break
    if tt == TT_KW and tv == "break"
        ps_adv(ps)
        return list(NT_BREAK)

    // continue
    if tt == TT_KW and tv == "continue"
        ps_adv(ps)
        return list(NT_CONTINUE)

    // say / print / show
    if tt == TT_KW and (tv == "say" or tv == "print" or tv == "println" or tv == "show")
        ps_adv(ps)
        if ps_is_tt(ps, TT_NL) == 1 or ps_is_tt(ps, TT_EOF) == 1
            return list(NT_FNCALL, "say", list())
        arg = parse_expr(ps)
        return list(NT_FNCALL, "say", list(arg))

    // include -- skip
    if tt == TT_KW and tv == "include"
        while ps_cur(ps) != null and ps_is_tt(ps, TT_NL) == 0 and ps_is_tt(ps, TT_EOF) == 0
            ps_adv(ps)
        return null

    // Assignment: IDENT =
    if tt == TT_IDENT
        next = ps_peek_n(ps, 1)
        if next != null and tok_type(next) == TT_OP and tok_val(next) == "="
            name = tok_val(t)
            ps_adv(ps)
            ps_adv(ps)
            val = parse_expr(ps)
            return list(NT_ASSIGN, name, val)

    // Expression statement or field assignment
    expr = parse_expr(ps)
    if expr == null return null
    if n_kind(expr) == NT_FIELD_GET and ps_is_op(ps, "=") == 1
        ps_adv(ps)
        val = parse_expr(ps)
        return list(NT_FIELD_SET, get(expr, 1), get(expr, 2), val)
    return expr

fn parse_expr ps = parse_or(ps)

fn parse_or ps
    left = parse_and(ps)
    while ps_is_kw(ps, "or") == 1
        ps_adv(ps)
        right = parse_and(ps)
        left = list(NT_BINOP, "or", left, right)
    return left

fn parse_and ps
    left = parse_not(ps)
    while ps_is_kw(ps, "and") == 1
        ps_adv(ps)
        right = parse_not(ps)
        left = list(NT_BINOP, "and", left, right)
    return left

fn parse_not ps
    if ps_is_kw(ps, "not") == 1
        ps_adv(ps)
        operand = parse_not(ps)
        return list(NT_UNARY, "not", operand)
    return parse_cmp(ps)

fn parse_cmp ps
    left = parse_add(ps)
    while ps_cur(ps) != null and tok_type(ps_cur(ps)) == TT_OP
        op = tok_val(ps_cur(ps))
        if op == "==" or op == "!=" or op == "<" or op == "<=" or op == ">" or op == ">="
            ps_adv(ps)
            right = parse_add(ps)
            left = list(NT_BINOP, op, left, right)
        else
            break
    return left

fn parse_add ps
    left = parse_mul(ps)
    while ps_cur(ps) != null and tok_type(ps_cur(ps)) == TT_OP
        op = tok_val(ps_cur(ps))
        if op == "+" or op == "-"
            ps_adv(ps)
            right = parse_mul(ps)
            left = list(NT_BINOP, op, left, right)
        else
            break
    return left

fn parse_mul ps
    left = parse_unary(ps)
    while ps_cur(ps) != null and tok_type(ps_cur(ps)) == TT_OP
        op = tok_val(ps_cur(ps))
        if op == "*" or op == "/" or op == "%"
            ps_adv(ps)
            right = parse_unary(ps)
            left = list(NT_BINOP, op, left, right)
        else
            break
    return left

fn parse_unary ps
    if ps_is_op(ps, "-") == 1
        ps_adv(ps)
        operand = parse_unary(ps)
        return list(NT_UNARY, "-", operand)
    return parse_postfix(ps)

fn parse_postfix ps
    node = parse_primary(ps)
    while ps_cur(ps) != null
        t = ps_cur(ps)
        if tok_type(t) == TT_OP and tok_val(t) == "."
            ps_adv(ps)
            field = ps_eat_ident(ps)
            node = list(NT_FIELD_GET, node, field)
        else
            break
    return node

fn parse_primary ps
    t = ps_cur(ps)
    if t == null return list(NT_NULL_N)
    tt = tok_type(t)
    tv = tok_val(t)

    if tt == TT_NUM
        ps_adv(ps)
        return list(NT_NUM_N, tv)
    if tt == TT_STR
        ps_adv(ps)
        return list(NT_STR_N, tv)
    if tt == TT_KW and tv == "true"
        ps_adv(ps)
        return list(NT_BOOL_N, 1)
    if tt == TT_KW and tv == "false"
        ps_adv(ps)
        return list(NT_BOOL_N, 0)
    if tt == TT_KW and (tv == "null" or tv == "nil")
        ps_adv(ps)
        return list(NT_NULL_N)
    if tt == TT_OP and tv == "("
        ps_adv(ps)
        expr = parse_expr(ps)
        ps_eat_op(ps, ")")
        return expr
    if tt == TT_IDENT
        name = tv
        ps_adv(ps)
        if ps_is_op(ps, "(") == 1
            ps_adv(ps)
            args = list()
            if ps_is_op(ps, ")") == 0
                push(args, parse_expr(ps))
                while ps_eat_op(ps, ",") == 1
                    push(args, parse_expr(ps))
            ps_eat_op(ps, ")")
            return list(NT_FNCALL, name, args)
        return list(NT_IDENT_N, name)
    // Built-in keyword used as expression
    if tt == TT_KW
        bkw_list = list("len", "push", "pop", "get", "set", "list", "sort", "sum", "join", "str", "int", "float", "abs", "sqrt", "floor", "ceil", "round", "min", "max", "upper", "lower", "trim", "split", "contains", "starts_with", "ends_with", "replace", "char_at", "index_of", "ord", "chr", "file_read", "file_write", "file_append", "file_exists", "argv", "type", "exit", "list_set", "list_get", "pow", "log", "bool", "append", "env", "time_ms", "log2", "log10", "tan", "sin", "cos")
        found = 0
        for bkw in bkw_list
            if bkw == tv
                found = 1
                break
        if found == 1
            ps_adv(ps)
            if ps_is_op(ps, "(") == 1
                ps_adv(ps)
                args = list()
                if ps_is_op(ps, ")") == 0
                    push(args, parse_expr(ps))
                    while ps_eat_op(ps, ",") == 1
                        push(args, parse_expr(ps))
                ps_eat_op(ps, ")")
                return list(NT_FNCALL, tv, args)
            return list(NT_FNCALL, tv, list())
    ps_adv(ps)
    return list(NT_NULL_N)

fn parse_program tokens
    ps = ps_new(tokens)
    stmts = list()
    while ps_cur(ps) != null and ps_is_tt(ps, TT_EOF) == 0
        ps_skip_nl(ps)
        if ps_is_tt(ps, TT_EOF) == 1 break
        if ps_cur(ps) == null break
        stmt = parse_stmt(ps)
        if stmt != null push(stmts, stmt)
    return stmts

// C Code Generator
// cg state: [struct_names_list, fn_names_list, declared_vars_list]
fn cg_new
    s = list()
    push(s, list())
    push(s, list())
    push(s, list())
    return s

fn cg_structs cg = get(cg, 0)
fn cg_fns cg = get(cg, 1)
fn cg_dvars cg = get(cg, 2)

fn cg_has_struct cg name
    for sn in cg_structs(cg)
        if sn == name return 1
    return 0

fn cg_has_var cg name
    for vn in cg_dvars(cg)
        if vn == name return 1
    return 0

fn cg_add_var cg name
    push(cg_dvars(cg), name)

fn cg_save_scope cg
    saved = list()
    for vn in cg_dvars(cg)
        push(saved, vn)
    return saved

fn cg_restore_scope cg saved
    list_set(cg, 2, saved)

fn ind_str n
    result = ""
    i = 0
    while i < n
        result = result + "    "
        i = i + 1
    return result

fn escape_str s
    BSLASH = chr(92)
    DQUOTE = chr(34)
    result = ""
    i = 0
    while i < len(s)
        c = char_at(s, i)
        if c == BSLASH
            result = result + BSLASH + BSLASH
        elif c == DQUOTE
            result = result + BSLASH + DQUOTE
        elif ord(c) == 10
            result = result + BSLASH + "n"
        elif ord(c) == 13
            result = result + BSLASH + "r"
        elif ord(c) == 9
            result = result + BSLASH + "t"
        else
            result = result + c
        i = i + 1
    return result
fn is_builtin name
    blist = list("say", "print", "println", "show", "echo", "len", "length", "push", "append", "pop", "get", "set", "list_get", "list_set", "list", "sort", "sum", "join", "str", "int", "float", "bool", "abs", "sqrt", "floor", "ceil", "round", "min", "max", "pow", "log", "sin", "cos", "upper", "lower", "trim", "strip", "split", "contains", "starts_with", "ends_with", "replace", "char_at", "index_of", "ord", "chr", "file_read", "file_write", "file_append", "file_exists", "argv", "type", "exit", "time_ms", "log2", "log10", "tan", "env")
    for b in blist
        if b == name return 1
    return 0

fn gen_builtin name args_c
    n = len(args_c)
    a0 = "lv_null()"
    a1 = "lv_null()"
    a2 = "lv_null()"
    if n >= 1 a0 = get(args_c, 0)
    if n >= 2 a1 = get(args_c, 1)
    if n >= 3 a2 = get(args_c, 2)
    if name == "say" or name == "print" or name == "println" or name == "show" or name == "echo"
        if n == 0 return "lipi_say(lv_str(\"\"))"
        if n == 1 return "lipi_say(" + a0 + ")"
        acc = a0
        i = 1
        while i < n
            acc = "lv_add(" + acc + ", " + get(args_c, i) + ")"
            i = i + 1
        return "lipi_say(" + acc + ")"
    if name == "len" or name == "length"  return "lv_len(" + a0 + ")"
    if name == "abs"    return "lipi_abs(" + a0 + ")"
    if name == "sqrt"   return "lipi_sqrt(" + a0 + ")"
    if name == "floor"  return "lipi_floor(" + a0 + ")"
    if name == "ceil"   return "lipi_ceil(" + a0 + ")"
    if name == "push" or name == "append" return "lv_push(" + a0 + ", " + a1 + ")"
    if name == "pop"    return "lv_pop(" + a0 + ")"
    if name == "get" or name == "list_get" return "lv_get(" + a0 + ", " + a1 + ")"
    if name == "list_set" or name == "set" return "lv_list_set_ret(" + a0 + ", " + a1 + ", " + a2 + ")"
    if name == "list"
        if n == 0 return "lv_list_make(0)"
        joined = a0
        i = 1
        while i < n
            joined = joined + ", " + get(args_c, i)
            i = i + 1
        return "lv_list_make(" + str(n) + ", " + joined + ")"
    if name == "sort"   return "lv_sort(" + a0 + ")"
    if name == "sum"    return "lv_sum(" + a0 + ")"
    if name == "join"
        if n == 1 return "lv_join(" + a0 + ", lv_str(\"\"))"
        return "lv_join(" + a0 + ", " + a1 + ")"
    if name == "str"    return "lv_str(lv_to_str(" + a0 + "))"
    if name == "int"    return "lv_num((long long)" + a0 + ".num)"
    if name == "float"  return a0
    if name == "bool"   return "lv_bool(lv_truthy(" + a0 + "))"
    if name == "upper"  return "lv_str_upper(" + a0 + ")"
    if name == "lower"  return "lv_str_lower(" + a0 + ")"
    if name == "trim" or name == "strip" return "lv_str_trim(" + a0 + ")"
    if name == "contains"    return "lv_contains(" + a0 + ", " + a1 + ")"
    if name == "starts_with" return "lv_starts_with(" + a0 + ", " + a1 + ")"
    if name == "ends_with"   return "lv_ends_with(" + a0 + ", " + a1 + ")"
    if name == "replace"     return "lv_replace(" + a0 + ", " + a1 + ", " + a2 + ")"
    if name == "char_at"     return "lv_char_at(" + a0 + ", " + a1 + ")"
    if name == "index_of"    return "lv_index_of(" + a0 + ", " + a1 + ")"
    if name == "split"
        if n == 1 return "lv_split(" + a0 + ", lv_null())"
        return "lv_split(" + a0 + ", " + a1 + ")"
    if name == "ord"         return "lv_ord(" + a0 + ")"
    if name == "chr"         return "lv_chr(" + a0 + ")"
    if name == "file_read"   return "lv_file_read(" + a0 + ")"
    if name == "file_write"  return "lv_file_write(" + a0 + ", " + a1 + ")"
    if name == "file_append" return "lv_file_append(" + a0 + ", " + a1 + ")"
    if name == "file_exists" return "lv_file_exists(" + a0 + ")"
    if name == "argv"        return "lv_argv()"
    if name == "type"        return "lv_type_str(" + a0 + ")"
    if name == "exit"        return "lv_exit(" + a0 + ")"
    if name == "min"         return "lv_min(" + a0 + ", " + a1 + ")"
    if name == "max"         return "lv_max(" + a0 + ", " + a1 + ")"
    if name == "pow"         return "lv_pow(" + a0 + ", " + a1 + ")"
    if name == "log"         return "lv_log(" + a0 + ")"
    if name == "sin"         return "lv_sin(" + a0 + ")"
    if name == "cos"         return "lv_cos(" + a0 + ")"
    if name == "round"       return "lv_round(" + a0 + ")"
    if name == "time_ms"     return "lv_time_ms()"
    if name == "env"         return "lv_env(" + a0 + ")"
    if name == "log2"        return "lv_log2(" + a0 + ")"
    if name == "log10"       return "lv_log10(" + a0 + ")"
    if name == "tan"         return "lv_tan(" + a0 + ")"
    return "lipi_say(lv_str(\"builtin error\"))"

fn gen_expr node cg
    if node == null return "lv_null()"
    k = n_kind(node)
    if k == NT_NULL_N  return "lv_null()"
    if k == NT_BOOL_N
        if get(node, 1) == 1 return "lv_bool(1)"
        return "lv_bool(0)"
    if k == NT_NUM_N   return "lv_num(" + get(node, 1) + ")"
    if k == NT_STR_N   return "lv_str(\"" + escape_str(get(node, 1)) + "\")"
    if k == NT_IDENT_N return c_ident(get(node, 1))
    if k == NT_BINOP
        op = get(node, 1)
        l  = gen_expr(get(node, 2), cg)
        r  = gen_expr(get(node, 3), cg)
        if op == "+"   return "lv_add(" + l + ", " + r + ")"
        if op == "-"   return "lv_sub(" + l + ", " + r + ")"
        if op == "*"   return "lv_mul(" + l + ", " + r + ")"
        if op == "/"   return "lv_div(" + l + ", " + r + ")"
        if op == "%"   return "lv_mod(" + l + ", " + r + ")"
        if op == "=="  return "lv_bool(lv_equal(" + l + ", " + r + "))"
        if op == "!="  return "lv_bool(!lv_equal(" + l + ", " + r + "))"
        if op == "<"   return "lv_bool(lv_lt(" + l + ", " + r + "))"
        if op == "<="  return "lv_bool(lv_le(" + l + ", " + r + "))"
        if op == ">"   return "lv_bool(lv_gt(" + l + ", " + r + "))"
        if op == ">="  return "lv_bool(lv_ge(" + l + ", " + r + "))"
        if op == "and" return "lv_bool(lv_truthy(" + l + ") && lv_truthy(" + r + "))"
        if op == "or"  return "lv_bool(lv_truthy(" + l + ") || lv_truthy(" + r + "))"
        return "lv_null()"
    if k == NT_UNARY
        op  = get(node, 1)
        opr = gen_expr(get(node, 2), cg)
        if op == "-"   return "lv_neg(" + opr + ")"
        if op == "not" return "lv_bool(!lv_truthy(" + opr + "))"
        return opr
    if k == NT_FIELD_GET
        obj   = gen_expr(get(node, 1), cg)
        field = get(node, 2)
        return "lv_field_get(" + obj + ", \"" + field + "\")"
    if k == NT_FNCALL
        name = get(node, 1)
        args = get(node, 2)
        args_c = list()
        for arg in args
            push(args_c, gen_expr(arg, cg))
        if is_builtin(name) == 1
            return gen_builtin(name, args_c)
        if cg_has_struct(cg, name) == 1
            return c_ident(name) + "_new()"
        n = len(args_c)
        if n == 0 return c_ident(name) + "(NULL, 0)"
        joined = get(args_c, 0)
        i = 1
        while i < n
            joined = joined + ", " + get(args_c, i)
            i = i + 1
        return c_ident(name) + "((LipiVal[" + str(n) + "]){" + joined + "}, " + str(n) + ")"

    return "lv_null()"


fn collect_vars stmts result
    // Recursively collect all assigned variable names in a body
    // WHY: We pre-declare all locals at top of C function to avoid
    //      C block-scoping issues where `if { LipiVal x = ...; }` limits scope.
    for stmt in stmts
        if stmt != null
            k = n_kind(stmt)
            if k == NT_ASSIGN
                // WHY: Store raw Lipi name, c_ident() applied later in gen_fn_node/gen_c
                vn = get(stmt, 1)
                found = 0
                for rv in result
                    if rv == vn
                        found = 1

                if found == 0
                    push(result, vn)
            elif k == NT_IF
                collect_vars(get(stmt, 2), result)
                for ep in get(stmt, 3)
                    collect_vars(get(ep, 1), result)
                if get(stmt, 4) != null
                    collect_vars(get(stmt, 4), result)
            elif k == NT_WHILE
                collect_vars(get(stmt, 2), result)
            elif k == NT_REPEAT
                collect_vars(get(stmt, 2), result)
            elif k == NT_FOR_RNG
                collect_vars(get(stmt, 5), result)
            elif k == NT_FOREACH
                collect_vars(get(stmt, 3), result)

fn gen_stmts stmts cg buf ind
    for stmt in stmts
        gen_stmt(stmt, cg, buf, ind)

fn gen_stmt node cg buf ind
    if node == null return
    k = n_kind(node)
    prefix = ind_str(ind)

    if k == NT_ASSIGN
        name  = get(node, 1)
        val_c = gen_expr(get(node, 2), cg)
        cn    = c_ident(name)
        if cg_has_var(cg, cn) == 1
            push(buf, prefix + cn + " = " + val_c + ";")
        else
            cg_add_var(cg, cn)
            push(buf, prefix + "LipiVal " + cn + " = " + val_c + ";")
        return

    if k == NT_FNCALL
        push(buf, prefix + gen_expr(node, cg) + ";")
        return

    if k == NT_RETURN
        vn = get(node, 1)
        if vn == null or n_kind(vn) == NT_NULL_N
            push(buf, prefix + "return lv_null();")
        else
            push(buf, prefix + "return " + gen_expr(vn, cg) + ";")
        return

    if k == NT_BREAK
        push(buf, prefix + "break;")
        return

    if k == NT_CONTINUE
        push(buf, prefix + "continue;")
        return

    if k == NT_FIELD_SET
        obj   = gen_expr(get(node, 1), cg)
        field = get(node, 2)
        val_c = gen_expr(get(node, 3), cg)
        push(buf, prefix + "lv_field_set(" + obj + ", \"" + field + "\", " + val_c + ");")
        return

    if k == NT_IF
        cond   = gen_expr(get(node, 1), cg)
        then_l = get(node, 2)
        elifs  = get(node, 3)
        else_l = get(node, 4)
        push(buf, prefix + "if (lv_truthy(" + cond + ")) {")
        gen_stmts(then_l, cg, buf, ind + 1)
        for ep in elifs
            ec = gen_expr(get(ep, 0), cg)
            push(buf, prefix + "} else if (lv_truthy(" + ec + ")) {")
            gen_stmts(get(ep, 1), cg, buf, ind + 1)
        if else_l != null
            push(buf, prefix + "} else {")
            gen_stmts(else_l, cg, buf, ind + 1)
        push(buf, prefix + "}")
        return

    if k == NT_WHILE
        cond = gen_expr(get(node, 1), cg)
        push(buf, prefix + "while (lv_truthy(" + cond + ")) {")
        gen_stmts(get(node, 2), cg, buf, ind + 1)
        push(buf, prefix + "}")
        return

    if k == NT_REPEAT
        cnt = gen_expr(get(node, 1), cg)
        lbl = "_r" + str(len(buf))
        push(buf, prefix + "{ LipiVal " + lbl + "=" + cnt + ";")
        push(buf, prefix + "for (long long " + lbl + "_i=0; " + lbl + "_i<(long long)" + lbl + ".num; " + lbl + "_i++) {")
        gen_stmts(get(node, 2), cg, buf, ind + 1)
        push(buf, prefix + "}}")
        return

    if k == NT_FOR_RNG
        var    = c_ident(get(node, 1))
        sc     = gen_expr(get(node, 2), cg)
        ec     = gen_expr(get(node, 3), cg)
        step_n = get(node, 4)
        if step_n == null
            stc = "lv_num(1)"
        else
            stc = gen_expr(step_n, cg)
        lbl = "_f" + str(len(buf))
        push(buf, prefix + "{ LipiVal " + lbl + "_s=" + sc + ", " + lbl + "_e=" + ec + ", " + lbl + "_st=" + stc + ";")
        push(buf, prefix + "for (LipiVal " + var + "=" + lbl + "_s; lv_le(" + var + "," + lbl + "_e); " + var + "=lv_num(" + var + ".num+" + lbl + "_st.num)) {")
        cg_add_var(cg, var)
        gen_stmts(get(node, 5), cg, buf, ind + 1)
        push(buf, prefix + "}}")
        return

    if k == NT_FOREACH
        var    = c_ident(get(node, 1))
        iter_c = gen_expr(get(node, 2), cg)
        lbl = "_e" + str(len(buf))
        push(buf, prefix + "{ LipiVal " + lbl + "_it=" + iter_c + ";")
        push(buf, prefix + "if (" + lbl + "_it.type==LV_LIST) { for (int " + lbl + "_i=0; " + lbl + "_i<" + lbl + "_it.list->count; " + lbl + "_i++) {")
        push(buf, prefix + "    LipiVal " + var + "=" + lbl + "_it.list->items[" + lbl + "_i];")
        gen_stmts(get(node, 3), cg, buf, ind + 1)
        push(buf, prefix + "}}}")
        return

    if k == NT_STRUCT or k == NT_FNDEF
        return

    push(buf, prefix + gen_expr(node, cg) + ";")

fn gen_fn_node node cg
    fn_name = get(node, 1)
    params  = get(node, 2)
    body    = get(node, 3)
    cn      = c_ident(fn_name)
    lines   = list()
    push(lines, "/* fn " + fn_name + " */")
    push(lines, "static LipiVal " + cn + "(LipiVal* _args, int _nargs) {")
    saved = cg_save_scope(cg)
    cg_restore_scope(cg, list())
    i = 0
    while i < len(params)
        pn = c_ident(get(params, i))
        cg_add_var(cg, pn)
        push(lines, "    LipiVal " + pn + " = (_nargs > " + str(i) + ") ? _args[" + str(i) + "] : lv_null();")
        i = i + 1
    // Pre-declare all locals to avoid C block-scoping issues
    locals = list()
    collect_vars(body, locals)
    for lv_nm in locals
        lv_cn = c_ident(lv_nm)
        already = 0
        for pn_chk in cg_dvars(cg)
            if pn_chk == lv_cn
                already = 1

        if already == 0
            cg_add_var(cg, lv_cn)
            push(lines, "    LipiVal " + lv_cn + " = lv_null();")

    gen_stmts(body, cg, lines, 1)
    push(lines, "    return lv_null();")
    push(lines, "}")
    push(lines, "")
    cg_restore_scope(cg, saved)
    return lines

fn collect_defs ast cg
    for stmt in ast
        if stmt != null
            k = n_kind(stmt)
            if k == NT_STRUCT
                push(cg_structs(cg), get(stmt, 1))
            elif k == NT_FNDEF
                push(cg_fns(cg), get(stmt, 1))


fn gen_struct_node node
    name   = get(node, 1)
    fields = get(node, 2)
    cn     = c_ident(name)
    lines  = list()
    push(lines, "/* struct " + name + " */")
    fa = ""
    i = 0
    while i < len(fields)
        if i > 0 fa = fa + ", "
        fa = fa + "\"" + get(fields, i) + "\""
        i = i + 1
    push(lines, "static const char* __" + cn + "_flds[] = {" + fa + "};")
    push(lines, "static inline LipiVal " + cn + "_new() {")
    push(lines, "    LipiVal v; v.type=LV_STRUCT;")
    push(lines, "    v.strct=lv_struct_new(\"" + name + "\",__" + cn + "_flds," + str(len(fields)) + ");")
    push(lines, "    return v;")
    push(lines, "}")
    return lines

fn gen_c ast
    cg = cg_new()
    collect_defs(ast, cg)

    decl_buf = list()
    fn_buf   = list()
    main_buf = list()

    push(decl_buf, "/* Generated by c_codegen.lp -- Lipi Self-Hosting Compiler */")
    push(decl_buf, "/* Lipi First 1.0 -- Sovereign */")
    push(decl_buf, "")
    push(decl_buf, "#include \"lipi_runtime.h\"")
    push(decl_buf, "")

    for stmt in ast
        if stmt != null and n_kind(stmt) == NT_STRUCT
            sls = gen_struct_node(stmt)
            for sl in sls
                push(decl_buf, sl)
            push(decl_buf, "")

    push(decl_buf, "/* Forward declarations */")
    for fn_nm in cg_fns(cg)
        push(decl_buf, "static LipiVal " + c_ident(fn_nm) + "(LipiVal*, int);")
    push(decl_buf, "")

    for stmt in ast
        if stmt != null and n_kind(stmt) == NT_FNDEF
            fls = gen_fn_node(stmt, cg)
            for fl in fls
                push(fn_buf, fl)

    // Pre-collect all main-body statements
    main_stmts = list()
    for stmt in ast
        if stmt != null
            k = n_kind(stmt)
            if k != NT_FNDEF and k != NT_STRUCT
                push(main_stmts, stmt)

    // WHY: Global variables (assigned at top level) must be C-static globals.
    //      If declared only inside main(), functions defined BEFORE main() can't see them.
    //      E.g., KEYWORDS = list(...) used by is_kw() — which is before main() in C output.
    //      Solution: emit as "static LipiVal u_X = {0};" at file scope,
    //      then assign in main() as "u_X = value;" (not re-declaring).
    main_locals = list()
    collect_vars(main_stmts, main_locals)
    for ml in main_locals
        ml_cn = c_ident(ml)
        cg_add_var(cg, ml_cn)
        // Emit as file-scope static (so ALL functions can see them)
        push(decl_buf, "static LipiVal " + ml_cn + ";  /* global: " + ml + " */")
    push(decl_buf, "")

    push(main_buf, "int main(void) {")
    for stmt in ast
        if stmt != null
            k = n_kind(stmt)
            if k != NT_FNDEF and k != NT_STRUCT
                gen_stmt(stmt, cg, main_buf, 1)
    push(main_buf, "    return 0;")
    push(main_buf, "}")


    result = ""
    for line in decl_buf
        result = result + line + "\n"
    for line in fn_buf
        result = result + line + "\n"
    for line in main_buf
        result = result + line + "\n"
    return result

// Main entry point
args = argv()
if len(args) < 3
    say "Usage: lipi c_codegen.lp input.lp output.c"
    say "  Compiles a Lipi .lp file to C source code"
    say "  Then: gcc output.c -I src/compiler/ -lm -o prog && ./prog"
else
    input_file  = get(args, 1)
    output_file = get(args, 2)
    say "Lipi Self-Hosting Compiler -- c_codegen.lp"
    say "-> Reading: " + input_file
    source = file_read(input_file)
    say "-> Tokenizing..."
    tokens = tokenize(source)
    say "   Tokens: " + len(tokens)
    say "-> Parsing..."
    ast = parse_program(tokens)
    say "   AST nodes: " + len(ast)
    say "-> Generating C code..."
    c_code = gen_c(ast)
    say "-> Writing: " + output_file
    file_write(output_file, c_code)
    say "DONE: " + input_file + " -> " + output_file
    say "Next: gcc " + output_file + " -I src/compiler/ -lm -o program"
