// ==============================================================================
// 👑 LIPI SOVEREIGN SSA IR & COMPILER OPTIMIZATION ENGINE (src/compiler/ssa_ir.lp)
// ⚡ 100% Pure Lipi 2.0 Indentation Syntax | 0% C | 0% LLVM | Direct Silicon Architecture
//
// WHY: Modern high-performance optimizing compilers rely on an Intermediate
//      Representation (IR) structured as Three-Address Code (TAC) in Static Single
//      Assignment (SSA) form partitioned into Basic Blocks and Control Flow Graphs (CFG).
//      This module provides sovereign AST-to-IR lowering, full constant propagation,
//      algebraic constant folding, dead block pruning, and iterative Dead Code
//      Elimination (DCE) without relying on any external C or LLVM toolchain.
// ==============================================================================

// ==============================================================================
// 🏛️ SECTION 1: TAC & SSA Opcode Constants and Instruction Representation
// ==============================================================================
// WHY: Explicit numeric opcodes allow high-speed integer comparison across the
//      compiler optimization pipeline without expensive string matching overhead.

IR_NOP      = 0    // No-operation (tombstone for eliminated instruction)
IR_CONST    = 1    // dest = const immediate_value
IR_COPY     = 2    // dest = copy src_reg
IR_ADD      = 3    // dest = src1 + src2
IR_SUB      = 4    // dest = src1 - src2
IR_MUL      = 5    // dest = src1 * src2
IR_DIV      = 6    // dest = src1 / src2
IR_MOD      = 7    // dest = src1 % src2
IR_CMP      = 8    // dest = src1 cmp_op src2 (==, !=, <, <=, >, >=)
IR_JMP      = 9    // unconditional control transfer: jmp target_label
IR_BR_COND  = 10   // conditional branch: br_cond cond_reg, true_lbl, false_lbl
IR_CALL     = 11   // function invocation: dest = call func_name, args_list
IR_RET      = 12   // function return: ret val_reg (or empty/void)
IR_PHI      = 13   // SSA confluence selector: dest = phi([v1, bb1], [v2, bb2], ...)

// ── Instruction Object Structure ──────────────────────────────────────────────
// An IR instruction is stored as a 5-element contiguous list:
//   [0]: op    (integer opcode constant)
//   [1]: dest  (string: destination register/temporary name, e.g. "t0", "a")
//   [2]: src1  (string or integer: first source operand or constant value)
//   [3]: src2  (string or integer: second source operand, or true_label)
//   [4]: extra (string or list: operator string, args list, phi pairs, false_label)

fn ir_inst_new op dest src1 src2 extra
    inst = list()
    push(inst, op)
    push(inst, dest)
    push(inst, src1)
    push(inst, src2)
    push(inst, extra)
    return inst

// Instruction field accessors
fn ir_inst_op inst = get(inst, 0)
fn ir_inst_dest inst = get(inst, 1)
fn ir_inst_src1 inst = get(inst, 2)
fn ir_inst_src2 inst = get(inst, 3)
fn ir_inst_extra inst = get(inst, 4)

// Instruction field mutators (for in-place optimization rewriting)
fn ir_inst_set_op inst v = list_set(inst, 0, v)
fn ir_inst_set_dest inst v = list_set(inst, 1, v)
fn ir_inst_set_src1 inst v = list_set(inst, 2, v)
fn ir_inst_set_src2 inst v = list_set(inst, 3, v)
fn ir_inst_set_extra inst v = list_set(inst, 4, v)

// ── Standard Instruction Constructors ─────────────────────────────────────────
// WHY: Ergonomic constructors enforce invariant instruction layouts and prevent
//      manual list manipulation errors across AST lowering and optimization passes.

fn ir_const dest val
    return ir_inst_new(IR_CONST, dest, val, "", "")

fn ir_copy dest src
    return ir_inst_new(IR_COPY, dest, src, "", "")

fn ir_add dest src1 src2
    return ir_inst_new(IR_ADD, dest, src1, src2, "")

fn ir_sub dest src1 src2
    return ir_inst_new(IR_SUB, dest, src1, src2, "")

fn ir_mul dest src1 src2
    return ir_inst_new(IR_MUL, dest, src1, src2, "")

fn ir_div dest src1 src2
    return ir_inst_new(IR_DIV, dest, src1, src2, "")

fn ir_mod dest src1 src2
    return ir_inst_new(IR_MOD, dest, src1, src2, "")

fn ir_cmp dest op_str src1 src2
    return ir_inst_new(IR_CMP, dest, src1, src2, op_str)

fn ir_jmp target_lbl
    return ir_inst_new(IR_JMP, "", "", "", target_lbl)

fn ir_br_cond cond_reg true_lbl false_lbl
    return ir_inst_new(IR_BR_COND, "", cond_reg, true_lbl, false_lbl)

fn ir_call dest func_name args_list
    return ir_inst_new(IR_CALL, dest, func_name, "", args_list)

fn ir_ret val_reg
    return ir_inst_new(IR_RET, "", val_reg, "", "")

fn ir_phi dest incoming_pairs
    return ir_inst_new(IR_PHI, dest, "", "", incoming_pairs)


// ==============================================================================
// 🏛️ SECTION 2: Basic Block and Function CFG Data Structures
// ==============================================================================
// WHY: Basic blocks isolate straight-line execution sequences terminated by
//      branches or returns. Control Flow Graphs model program structure as directed
//      graphs between basic blocks, enabling liveness and reachability analysis.

// A Basic Block is a 5-element list:
//   [0]: label        (string identifier, e.g. "entry", "then_1")
//   [1]: instructions (list of IR instruction objects)
//   [2]: predecessors (list of predecessor block label strings)
//   [3]: successors   (list of successor block label strings)
//   [4]: is_dead      (integer: 0 = reachable/live, 1 = pruned/dead)

fn ir_block_new label
    b = list()
    push(b, label)          // 0: label
    push(b, list())         // 1: instructions
    push(b, list())         // 2: predecessors
    push(b, list())         // 3: successors
    push(b, 0)              // 4: is_dead
    return b

fn ir_block_label b = get(b, 0)
fn ir_block_insts b = get(b, 1)
fn ir_block_preds b = get(b, 2)
fn ir_block_succs b = get(b, 3)
fn ir_block_is_dead b = get(b, 4)

fn ir_block_set_label b v = list_set(b, 0, v)
fn ir_block_set_insts b v = list_set(b, 1, v)
fn ir_block_set_preds b v = list_set(b, 2, v)
fn ir_block_set_succs b v = list_set(b, 3, v)
fn ir_block_set_dead b v = list_set(b, 4, v)

// Appends an instruction to a basic block
fn ir_block_append block inst
    insts = get(block, 1)
    push(insts, inst)

// ── Function CFG Structure ───────────────────────────────────────────────────
// A Function CFG is a 6-element list:
//   [0]: name          (string function name, e.g. "main")
//   [1]: params        (list of parameter name strings)
//   [2]: blocks        (list of basic block objects)
//   [3]: entry_block   (first basic block object)
//   [4]: temp_counter  (list of 1 int: counter for generating unique t0, t1, ...)
//   [5]: block_counter (list of 1 int: counter for generating unique bb labels)

fn ir_func_new name params
    f = list()
    push(f, name)              // 0: name
    push(f, params)            // 1: params
    push(f, list())            // 2: blocks list
    entry_bb = ir_block_new("entry")
    push(f, entry_bb)          // 3: entry_block
    push(get(f, 2), entry_bb)  // add entry to blocks
    tc = list()
    push(tc, 0)
    push(f, tc)                // 4: temp_counter
    bc = list()
    push(bc, 1)
    push(f, bc)                // 5: block_counter
    return f

fn ir_func_name f = get(f, 0)
fn ir_func_params f = get(f, 1)
fn ir_func_blocks f = get(f, 2)
fn ir_func_entry f = get(f, 3)

// Generates a monotonically increasing fresh temporary register name ("t0", "t1", ...)
fn ir_func_new_temp f
    tc = get(f, 4)
    cnt = get(tc, 0)
    list_set(tc, 0, cnt + 1)
    return "t" + str(cnt)

// Allocates and registers a new basic block with a unique label
fn ir_func_new_block f label_prefix
    bc = get(f, 5)
    cnt = get(bc, 0)
    list_set(bc, 0, cnt + 1)
    lbl = label_prefix + "_" + str(cnt)
    bb = ir_block_new(lbl)
    push(get(f, 2), bb)
    return bb

// Finds a basic block in the function by its label
fn ir_func_find_block f label
    blocks = get(f, 2)
    i = 0
    blen = len(blocks)
    while i < blen
        bb = get(blocks, i)
        if ir_block_label(bb) == label
            return bb
        i = i + 1
    return 0


// ==============================================================================
// 🏛️ SECTION 3: High-Speed Sovereign Symbol Table & Map Utilities
// ==============================================================================
// WHY: We provide a zero-dependency dual-list associative map for tracking constant
//      tables and reference use counts during optimization and execution.

fn ssa_map_new
    m = list()
    push(m, list()) // 0: keys
    push(m, list()) // 1: values
    return m

fn ssa_map_has m k
    keys = get(m, 0)
    i = 0
    klen = len(keys)
    while i < klen
        if get(keys, i) == k
            return 1
        i = i + 1
    return 0

fn ssa_map_get m k default_val
    keys = get(m, 0)
    vals = get(m, 1)
    i = 0
    klen = len(keys)
    while i < klen
        if get(keys, i) == k
            return get(vals, i)
        i = i + 1
    return default_val

fn ssa_map_set m k v
    keys = get(m, 0)
    vals = get(m, 1)
    i = 0
    klen = len(keys)
    while i < klen
        if get(keys, i) == k
            list_set(vals, i, v)
            return 1
        i = i + 1
    push(keys, k)
    push(vals, v)
    return 1

fn ssa_map_remove m k
    keys = get(m, 0)
    vals = get(m, 1)
    new_k = list()
    new_v = list()
    i = 0
    klen = len(keys)
    while i < klen
        if get(keys, i) != k
            push(new_k, get(keys, i))
            push(new_v, get(vals, i))
        i = i + 1
    list_set(m, 0, new_k)
    list_set(m, 1, new_v)
    return 0

// Checks if an ASCII code represents a decimal digit '0'..'9'
fn ssa_is_digit_code c
    return c >= 48 and c <= 57

// Returns 1 if a string represents an integer literal (e.g. "42", "-10"), 0 otherwise
fn ssa_is_numeric_str s
    slen = len(s)
    if slen == 0
        return 0
    i = 0
    if char_at(s, 0) == "-"
        if slen == 1
            return 0
        i = 1
    while i < slen
        c = ord(char_at(s, i))
        if ssa_is_digit_code(c) == 0
            return 0
        i = i + 1
    return 1

// Parses a signed 64-bit integer from a string
fn ssa_parse_int_val s
    slen = len(s)
    if slen == 0
        return 0
    sign = 1
    i = 0
    if char_at(s, 0) == "-"
        sign = 0 - 1
        i = 1
    val = 0
    while i < slen
        c = ord(char_at(s, i))
        if ssa_is_digit_code(c) == 1
            val = (val * 10) + (c - 48)
        i = i + 1
    return val * sign

// Checks if a string list contains a specific string target
fn ssa_list_contains_str lst target
    i = 0
    llen = len(lst)
    while i < llen
        if get(lst, i) == target
            return 1
        i = i + 1
    return 0


// ==============================================================================
// 🏛️ SECTION 4: AST Node Representation & Source Parser
// ==============================================================================
// WHY: Allows constructing programs both programmatically via structured AST nodes
//      and directly from Lipi statement text for end-to-end verification.

AST_LIT     = 1    // Literal integer value
AST_VAR     = 2    // Variable identifier
AST_BINOP   = 3    // Binary operator: op, left, right
AST_ASSIGN  = 4    // Variable assignment: name, expr
AST_LET     = 5    // Variable declaration: name, expr
AST_RET     = 6    // Return statement: expr
AST_IF      = 7    // Conditional branch: cond, then_body, else_body
AST_CALL    = 8    // Function call: func_name, args_list
AST_BLOCK   = 9    // Sequential block of statements

fn ast_lit val
    n = list()
    push(n, AST_LIT)
    push(n, val)
    return n

fn ast_var name
    n = list()
    push(n, AST_VAR)
    push(n, name)
    return n

fn ast_binop op left right
    n = list()
    push(n, AST_BINOP)
    push(n, op)
    push(n, left)
    push(n, right)
    return n

fn ast_assign name expr
    n = list()
    push(n, AST_ASSIGN)
    push(n, name)
    push(n, expr)
    return n

fn ast_let name expr
    n = list()
    push(n, AST_LET)
    push(n, name)
    push(n, expr)
    return n

fn ast_ret expr
    n = list()
    push(n, AST_RET)
    push(n, expr)
    return n

fn ast_if cond then_body else_body
    n = list()
    push(n, AST_IF)
    push(n, cond)
    push(n, then_body)
    push(n, else_body)
    return n

fn ast_call name args
    n = list()
    push(n, AST_CALL)
    push(n, name)
    push(n, args)
    return n

fn ast_block stmts
    n = list()
    push(n, AST_BLOCK)
    push(n, stmts)
    return n

// ── Lightweight Lexer for SSA Parser ─────────────────────────────────────────
// WHY: Tokenizes Lipi expression and assignment syntax with zero external overhead.

TOK_EOF    = 0
TOK_IDENT  = 1
TOK_INT    = 2
TOK_OP     = 3
TOK_SEMI   = 4

fn ssa_tok_new type text val
    t = list()
    push(t, type)
    push(t, text)
    push(t, val)
    return t

fn ssa_tokenize src
    tokens = list()
    p = 0
    slen = len(src)

    while p < slen
        c = char_at(src, p)

        // Skip whitespace
        if c == " " or c == "\t" or c == "\r" or c == "\n"
            p = p + 1
            continue

        // Semicolon delimiter
        if c == ";"
            push(tokens, ssa_tok_new(TOK_SEMI, ";", 0))
            p = p + 1
            continue

        // Integer literal
        if ssa_is_digit_code(ord(c)) == 1
            start_p = p
            while p < slen and ssa_is_digit_code(ord(char_at(src, p))) == 1
                p = p + 1
            num_str = ""
            k = start_p
            while k < p
                num_str = num_str + char_at(src, k)
                k = k + 1
            push(tokens, ssa_tok_new(TOK_INT, num_str, ssa_parse_int_val(num_str)))
            continue

        // Identifier or keyword
        c_ord = ord(c)
        if (c_ord >= 65 and c_ord <= 90) or (c_ord >= 97 and c_ord <= 122) or c == "_"
            start_p = p
            while p < slen
                cur = ord(char_at(src, p))
                is_letter = (cur >= 65 and cur <= 90) or (cur >= 97 and cur <= 122) or cur == 95
                is_digit = cur >= 48 and cur <= 57
                if is_letter == 0 and is_digit == 0
                    break
                p = p + 1
            ident_str = ""
            k = start_p
            while k < p
                ident_str = ident_str + char_at(src, k)
                k = k + 1
            push(tokens, ssa_tok_new(TOK_IDENT, ident_str, 0))
            continue

        // Multi-char operators: ==, !=, <=, >=
        if p + 1 < slen
            c2 = char_at(src, p + 1)
            if (c == "=" and c2 == "=") or (c == "!" and c2 == "=") or (c == "<" and c2 == "=") or (c == ">" and c2 == "=")
                op_str = c + c2
                push(tokens, ssa_tok_new(TOK_OP, op_str, 0))
                p = p + 2
                continue

        // Single character operators: +, -, *, /, %, =, <, >, (, )
        if c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "=" or c == "<" or c == ">" or c == "(" or c == ")" or c == ","
            push(tokens, ssa_tok_new(TOK_OP, c, 0))
            p = p + 1
            continue

        p = p + 1

    push(tokens, ssa_tok_new(TOK_EOF, "", 0))
    return tokens

// ── Recursive Descent Parser for SSA Source Code ──────────────────────────────
// WHY: Parses statements of the form:
//        let a = 10 + 20; let dead = 99 * 3; let b = a * 2; return b
//      directly into structured AST nodes.

fn ssa_parse_source src
    tokens = ssa_tokenize(src)
    pos_ref = list()
    push(pos_ref, 0)

    stmts = list()
    while get(pos_ref, 0) < len(tokens)
        cur_tok = get(tokens, get(pos_ref, 0))
        if get(cur_tok, 0) == TOK_EOF
            break
        if get(cur_tok, 0) == TOK_SEMI
            list_set(pos_ref, 0, get(pos_ref, 0) + 1)
            continue

        stmt = ssa_parse_stmt(tokens, pos_ref)
        if stmt != 0
            push(stmts, stmt)

    return stmts

fn ssa_parse_stmt tokens pos_ref
    cur = get(tokens, get(pos_ref, 0))
    if get(cur, 0) == TOK_EOF
        return 0

    // Optional 'let' keyword
    if get(cur, 0) == TOK_IDENT and get(cur, 1) == "let"
        list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        cur = get(tokens, get(pos_ref, 0))

    // 'return' statement
    if get(cur, 0) == TOK_IDENT and get(cur, 1) == "return"
        list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        expr = ssa_parse_expr(tokens, pos_ref)
        if get(pos_ref, 0) < len(tokens) and get(get(tokens, get(pos_ref, 0)), 0) == TOK_SEMI
            list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        return ast_ret(expr)

    // Assignment: ident = expr
    if get(cur, 0) == TOK_IDENT
        var_name = get(cur, 1)
        list_set(pos_ref, 0, get(pos_ref, 0) + 1)

        // Expect '=' operator
        if get(pos_ref, 0) < len(tokens)
            next_t = get(tokens, get(pos_ref, 0))
            if get(next_t, 0) == TOK_OP and get(next_t, 1) == "="
                list_set(pos_ref, 0, get(pos_ref, 0) + 1)
                expr = ssa_parse_expr(tokens, pos_ref)
                if get(pos_ref, 0) < len(tokens) and get(get(tokens, get(pos_ref, 0)), 0) == TOK_SEMI
                    list_set(pos_ref, 0, get(pos_ref, 0) + 1)
                return ast_assign(var_name, expr)

    return 0

fn ssa_parse_expr tokens pos_ref
    return ssa_parse_relational(tokens, pos_ref)

fn ssa_parse_relational tokens pos_ref
    left = ssa_parse_additive(tokens, pos_ref)
    while get(pos_ref, 0) < len(tokens)
        cur = get(tokens, get(pos_ref, 0))
        if get(cur, 0) == TOK_OP
            op_text = get(cur, 1)
            if op_text == "==" or op_text == "!=" or op_text == "<" or op_text == "<=" or op_text == ">" or op_text == ">="
                list_set(pos_ref, 0, get(pos_ref, 0) + 1)
                right = ssa_parse_additive(tokens, pos_ref)
                left = ast_binop(op_text, left, right)
                continue
        break
    return left

fn ssa_parse_additive tokens pos_ref
    left = ssa_parse_multiplicative(tokens, pos_ref)
    while get(pos_ref, 0) < len(tokens)
        cur = get(tokens, get(pos_ref, 0))
        if get(cur, 0) == TOK_OP
            op_text = get(cur, 1)
            if op_text == "+" or op_text == "-"
                list_set(pos_ref, 0, get(pos_ref, 0) + 1)
                right = ssa_parse_multiplicative(tokens, pos_ref)
                left = ast_binop(op_text, left, right)
                continue
        break
    return left

fn ssa_parse_multiplicative tokens pos_ref
    left = ssa_parse_primary(tokens, pos_ref)
    while get(pos_ref, 0) < len(tokens)
        cur = get(tokens, get(pos_ref, 0))
        if get(cur, 0) == TOK_OP
            op_text = get(cur, 1)
            if op_text == "*" or op_text == "/" or op_text == "%"
                list_set(pos_ref, 0, get(pos_ref, 0) + 1)
                right = ssa_parse_primary(tokens, pos_ref)
                left = ast_binop(op_text, left, right)
                continue
        break
    return left

fn ssa_parse_primary tokens pos_ref
    cur = get(tokens, get(pos_ref, 0))
    t_type = get(cur, 0)

    // Integer constant
    if t_type == TOK_INT
        list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        return ast_lit(get(cur, 2))

    // Variable identifier
    if t_type == TOK_IDENT
        name = get(cur, 1)
        list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        return ast_var(name)

    // Parenthesized sub-expression
    if t_type == TOK_OP and get(cur, 1) == "("
        list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        e = ssa_parse_expr(tokens, pos_ref)
        if get(pos_ref, 0) < len(tokens) and get(get(tokens, get(pos_ref, 0)), 1) == ")"
            list_set(pos_ref, 0, get(pos_ref, 0) + 1)
        return e

    return ast_lit(0)


// ==============================================================================
// 🏛️ SECTION 5: AST-to-IR Lowering Engine (Linear TAC Sequences)
// ==============================================================================
// WHY: Recursively traverses AST expression trees and flattens nested operations
//      into atomic Three-Address Code instructions utilizing temporary registers.

fn ast_to_ir_expr func cur_block expr
    node_type = get(expr, 0)

    // 1. Literal Integer
    if node_type == AST_LIT
        val = get(expr, 1)
        t = ir_func_new_temp(func)
        ir_block_append(cur_block, ir_const(t, val))
        return t

    // 2. Variable Identifier
    if node_type == AST_VAR
        return get(expr, 1)

    // 3. Binary Arithmetic & Comparison Operator
    if node_type == AST_BINOP
        op = get(expr, 1)
        left_res = ast_to_ir_expr(func, cur_block, get(expr, 2))
        right_res = ast_to_ir_expr(func, cur_block, get(expr, 3))
        t = ir_func_new_temp(func)

        if op == "+"
            ir_block_append(cur_block, ir_add(t, left_res, right_res))
        elif op == "-"
            ir_block_append(cur_block, ir_sub(t, left_res, right_res))
        elif op == "*"
            ir_block_append(cur_block, ir_mul(t, left_res, right_res))
        elif op == "/"
            ir_block_append(cur_block, ir_div(t, left_res, right_res))
        elif op == "%"
            ir_block_append(cur_block, ir_mod(t, left_res, right_res))
        else
            // Relational operator: ==, !=, <, <=, >, >=
            ir_block_append(cur_block, ir_cmp(t, op, left_res, right_res))

        return t

    // 4. Function Call
    if node_type == AST_CALL
        fn_name = get(expr, 1)
        raw_args = get(expr, 2)
        arg_regs = list()
        i = 0
        alen = len(raw_args)
        while i < alen
            r = ast_to_ir_expr(func, cur_block, get(raw_args, i))
            push(arg_regs, r)
            i = i + 1
        t = ir_func_new_temp(func)
        ir_block_append(cur_block, ir_call(t, fn_name, arg_regs))
        return t

    return ""

fn ast_to_ir_stmt func cur_block stmt
    node_type = get(stmt, 0)

    // 1. Variable Assignment or Let
    if node_type == AST_ASSIGN or node_type == AST_LET
        var_name = get(stmt, 1)
        val_reg = ast_to_ir_expr(func, cur_block, get(stmt, 2))
        ir_block_append(cur_block, ir_copy(var_name, val_reg))
        return cur_block

    // 2. Return Statement
    if node_type == AST_RET
        val_reg = ast_to_ir_expr(func, cur_block, get(stmt, 1))
        ir_block_append(cur_block, ir_ret(val_reg))
        return cur_block

    // 3. Conditional Branch (If-Else)
    if node_type == AST_IF
        cond_expr = get(stmt, 1)
        then_stmts = get(stmt, 2)
        else_stmts = get(stmt, 3)

        cond_reg = ast_to_ir_expr(func, cur_block, cond_expr)
        then_bb = ir_func_new_block(func, "then")
        else_bb = ir_func_new_block(func, "else")
        merge_bb = ir_func_new_block(func, "merge")

        ir_block_append(cur_block, ir_br_cond(cond_reg, ir_block_label(then_bb), ir_block_label(else_bb)))

        // Populate then branch
        ast_to_ir_stmt_list(func, then_bb, then_stmts)
        ir_block_append(then_bb, ir_jmp(ir_block_label(merge_bb)))

        // Populate else branch
        ast_to_ir_stmt_list(func, else_bb, else_stmts)
        ir_block_append(else_bb, ir_jmp(ir_block_label(merge_bb)))

        return merge_bb

    return cur_block

fn ast_to_ir_stmt_list func cur_block stmts
    i = 0
    slen = len(stmts)
    active_bb = cur_block
    while i < slen
        active_bb = ast_to_ir_stmt(func, active_bb, get(stmts, i))
        i = i + 1
    return active_bb

// Compiles a parsed statement list into a complete IR Function CFG
fn ast_to_ir_program func stmts
    entry_bb = ir_func_entry(func)
    ast_to_ir_stmt_list(func, entry_bb, stmts)
    return func


// ==============================================================================
// 🏛️ SECTION 6: Constant Propagation & Algebraic Folding Optimization Pass
// ==============================================================================
// WHY: Evaluates compile-time known arithmetic operations at IR level and propagates
//      literal values forward across copies and binary expressions until reaching a
//      fixpoint, drastically reducing runtime instruction count and CPU cycles.

fn ir_opt_const_fold func
    changed = 1
    iterations = 0
    total_folded = 0
    const_map = ssa_map_new()

    while changed == 1 and iterations < 30
        changed = 0
        iterations = iterations + 1

        blocks = ir_func_blocks(func)
        b_idx = 0
        blen = len(blocks)
        while b_idx < blen
            bb = get(blocks, b_idx)
            insts = ir_block_insts(bb)
            i_idx = 0
            ilen = len(insts)
            while i_idx < ilen
                inst = get(insts, i_idx)
                op = ir_inst_op(inst)
                dest = ir_inst_dest(inst)
                s1 = ir_inst_src1(inst)
                s2 = ir_inst_src2(inst)
                ext = ir_inst_extra(inst)

                // ── IR_CONST: Register known constant value ───────────────────
                if op == IR_CONST
                    val = ssa_parse_int_val(str(s1))
                    if ssa_map_has(const_map, dest) == 0 or ssa_map_get(const_map, dest, 0) != val
                        ssa_map_set(const_map, dest, val)
                        changed = 1

                // ── IR_COPY: Propagate constant through register copy ─────────
                elif op == IR_COPY
                    src_str = str(s1)
                    if ssa_map_has(const_map, src_str) == 1
                        cval = ssa_map_get(const_map, src_str, 0)
                        ir_inst_set_op(inst, IR_CONST)
                        ir_inst_set_src1(inst, cval)
                        ir_inst_set_src2(inst, "")
                        ssa_map_set(const_map, dest, cval)
                        changed = 1
                        total_folded = total_folded + 1
                    elif ssa_is_numeric_str(src_str) == 1
                        cval = ssa_parse_int_val(src_str)
                        ir_inst_set_op(inst, IR_CONST)
                        ir_inst_set_src1(inst, cval)
                        ir_inst_set_src2(inst, "")
                        ssa_map_set(const_map, dest, cval)
                        changed = 1
                        total_folded = total_folded + 1

                // ── IR_ADD, IR_SUB, IR_MUL, IR_DIV, IR_MOD: Fold Binary Math ─
                elif op == IR_ADD or op == IR_SUB or op == IR_MUL or op == IR_DIV or op == IR_MOD
                    has_v1 = 0
                    v1 = 0
                    s1_str = str(s1)
                    if ssa_is_numeric_str(s1_str) == 1
                        v1 = ssa_parse_int_val(s1_str)
                        has_v1 = 1
                    elif ssa_map_has(const_map, s1_str) == 1
                        v1 = ssa_map_get(const_map, s1_str, 0)
                        has_v1 = 1

                    has_v2 = 0
                    v2 = 0
                    s2_str = str(s2)
                    if ssa_is_numeric_str(s2_str) == 1
                        v2 = ssa_parse_int_val(s2_str)
                        has_v2 = 1
                    elif ssa_map_has(const_map, s2_str) == 1
                        v2 = ssa_map_get(const_map, s2_str, 0)
                        has_v2 = 1

                    if has_v1 == 1 and has_v2 == 1
                        res = 0
                        if op == IR_ADD
                            res = v1 + v2
                        elif op == IR_SUB
                            res = v1 - v2
                        elif op == IR_MUL
                            res = v1 * v2
                        elif op == IR_DIV
                            if v2 != 0
                                res = v1 / v2
                            else
                                res = 0
                        elif op == IR_MOD
                            if v2 != 0
                                res = v1 % v2
                            else
                                res = 0

                        // Fold instruction into direct IR_CONST dest, res
                        ir_inst_set_op(inst, IR_CONST)
                        ir_inst_set_src1(inst, res)
                        ir_inst_set_src2(inst, "")
                        ssa_map_set(const_map, dest, res)
                        changed = 1
                        total_folded = total_folded + 1

                // ── IR_CMP: Fold Comparison Predicates ────────────────────────
                elif op == IR_CMP
                    has_v1 = 0
                    v1 = 0
                    s1_str = str(s1)
                    if ssa_is_numeric_str(s1_str) == 1
                        v1 = ssa_parse_int_val(s1_str)
                        has_v1 = 1
                    elif ssa_map_has(const_map, s1_str) == 1
                        v1 = ssa_map_get(const_map, s1_str, 0)
                        has_v1 = 1

                    has_v2 = 0
                    v2 = 0
                    s2_str = str(s2)
                    if ssa_is_numeric_str(s2_str) == 1
                        v2 = ssa_parse_int_val(s2_str)
                        has_v2 = 1
                    elif ssa_map_has(const_map, s2_str) == 1
                        v2 = ssa_map_get(const_map, s2_str, 0)
                        has_v2 = 1

                    if has_v1 == 1 and has_v2 == 1
                        cmp_op = str(ext)
                        res = 0
                        if cmp_op == "==" and v1 == v2
                            res = 1
                        elif cmp_op == "!=" and v1 != v2
                            res = 1
                        elif cmp_op == "<" and v1 < v2
                            res = 1
                        elif cmp_op == "<=" and v1 <= v2
                            res = 1
                        elif cmp_op == ">" and v1 > v2
                            res = 1
                        elif cmp_op == ">=" and v1 >= v2
                            res = 1

                        ir_inst_set_op(inst, IR_CONST)
                        ir_inst_set_src1(inst, res)
                        ir_inst_set_src2(inst, "")
                        ir_inst_set_extra(inst, "")
                        ssa_map_set(const_map, dest, res)
                        changed = 1
                        total_folded = total_folded + 1

                // ── IR_BR_COND: Simplify Static Conditional Branches ──────────
                elif op == IR_BR_COND
                    cond_str = str(s1)
                    if ssa_map_has(const_map, cond_str) == 1
                        cval = ssa_map_get(const_map, cond_str, 0)
                        true_lbl = str(s2)
                        false_lbl = str(ext)
                        if cval != 0
                            // Condition always true: unconditional jump to true branch
                            ir_inst_set_op(inst, IR_JMP)
                            ir_inst_set_dest(inst, "")
                            ir_inst_set_src1(inst, "")
                            ir_inst_set_src2(inst, "")
                            ir_inst_set_extra(inst, true_lbl)
                        else
                            // Condition always false: unconditional jump to false branch
                            ir_inst_set_op(inst, IR_JMP)
                            ir_inst_set_dest(inst, "")
                            ir_inst_set_src1(inst, "")
                            ir_inst_set_src2(inst, "")
                            ir_inst_set_extra(inst, false_lbl)
                        changed = 1
                        total_folded = total_folded + 1

                i_idx = i_idx + 1
            b_idx = b_idx + 1

    return total_folded


// ==============================================================================
// 🏛️ SECTION 7: Dead Code Elimination (DCE) & Reachability Pass
// ==============================================================================
// WHY: Eliminates unused variables, dead temporary registers, and unreachable
//      basic blocks created by static branch folding, yielding compact IR.

fn ir_opt_dce func
    // Step 1: Eliminate dead, unreachable basic blocks
    ir_opt_eliminate_dead_blocks(func)

    // Step 2: Iterative instruction-level Dead Code Elimination
    changed = 1
    total_eliminated = 0

    while changed == 1
        changed = 0

        // Build use-count reference map across all live basic blocks
        use_counts = ssa_map_new()
        blocks = ir_func_blocks(func)
        b_idx = 0
        blen = len(blocks)
        while b_idx < blen
            bb = get(blocks, b_idx)
            insts = ir_block_insts(bb)
            i_idx = 0
            ilen = len(insts)
            while i_idx < ilen
                inst = get(insts, i_idx)
                op = ir_inst_op(inst)
                s1 = str(ir_inst_src1(inst))
                s2 = str(ir_inst_src2(inst))
                ext = ir_inst_extra(inst)

                if op == IR_RET
                    if s1 != "" and ssa_is_numeric_str(s1) == 0
                        cur = ssa_map_get(use_counts, s1, 0)
                        ssa_map_set(use_counts, s1, cur + 1)

                elif op == IR_CALL
                    if len(ext) > 0
                        k = 0
                        klen = len(ext)
                        while k < klen
                            arg_name = str(get(ext, k))
                            if arg_name != "" and ssa_is_numeric_str(arg_name) == 0
                                cur = ssa_map_get(use_counts, arg_name, 0)
                                ssa_map_set(use_counts, arg_name, cur + 1)
                            k = k + 1

                elif op == IR_BR_COND
                    if s1 != "" and ssa_is_numeric_str(s1) == 0
                        cur = ssa_map_get(use_counts, s1, 0)
                        ssa_map_set(use_counts, s1, cur + 1)

                elif op == IR_COPY
                    if s1 != "" and ssa_is_numeric_str(s1) == 0
                        cur = ssa_map_get(use_counts, s1, 0)
                        ssa_map_set(use_counts, s1, cur + 1)

                elif op == IR_ADD or op == IR_SUB or op == IR_MUL or op == IR_DIV or op == IR_MOD or op == IR_CMP
                    if s1 != "" and ssa_is_numeric_str(s1) == 0
                        cur = ssa_map_get(use_counts, s1, 0)
                        ssa_map_set(use_counts, s1, cur + 1)
                    if s2 != "" and ssa_is_numeric_str(s2) == 0
                        cur = ssa_map_get(use_counts, s2, 0)
                        ssa_map_set(use_counts, s2, cur + 1)

                elif op == IR_PHI
                    if len(ext) > 0
                        k = 0
                        klen = len(ext)
                        while k < klen
                            pair = get(ext, k)
                            val_name = str(get(pair, 0))
                            if val_name != "" and ssa_is_numeric_str(val_name) == 0
                                cur = ssa_map_get(use_counts, val_name, 0)
                                ssa_map_set(use_counts, val_name, cur + 1)
                            k = k + 1

                i_idx = i_idx + 1
            b_idx = b_idx + 1

        // Prune instructions with destination register having 0 uses and no side-effects
        b_idx = 0
        while b_idx < blen
            bb = get(blocks, b_idx)
            insts = ir_block_insts(bb)
            live_insts = list()
            i_idx = 0
            ilen = len(insts)
            while i_idx < ilen
                inst = get(insts, i_idx)
                op = ir_inst_op(inst)
                dest = ir_inst_dest(inst)

                // Critical instructions with observable side-effects must NEVER be pruned
                is_critical = (op == IR_RET) or (op == IR_CALL) or (op == IR_JMP) or (op == IR_BR_COND)
                if is_critical == 1
                    push(live_insts, inst)
                else
                    uses = ssa_map_get(use_counts, dest, 0)
                    if uses > 0
                        push(live_insts, inst)
                    else
                        // Instruction destination is never read: ELIMINATE DEAD CODE!
                        changed = 1
                        total_eliminated = total_eliminated + 1

                i_idx = i_idx + 1

            ir_block_set_insts(bb, live_insts)
            b_idx = b_idx + 1

    return total_eliminated

// ── Dead Block Elimination Algorithm ──────────────────────────────────────────
// WHY: Traverses basic block control flow edges from entry block using a worklist;
//      unvisited basic blocks are unreachable and pruned from the CFG.

fn ir_opt_eliminate_dead_blocks func
    blocks = ir_func_blocks(func)
    if len(blocks) <= 1
        return 0

    entry_bb = ir_func_entry(func)
    visited_labels = list()
    worklist = list()

    push(visited_labels, ir_block_label(entry_bb))
    push(worklist, ir_block_label(entry_bb))

    while len(worklist) > 0
        cur_lbl = pop(worklist)
        cur_bb = ir_func_find_block(func, cur_lbl)
        if cur_bb != 0
            insts = ir_block_insts(cur_bb)
            i = 0
            ilen = len(insts)
            while i < ilen
                inst = get(insts, i)
                op = ir_inst_op(inst)
                if op == IR_JMP
                    tgt = str(ir_inst_extra(inst))
                    if ssa_list_contains_str(visited_labels, tgt) == 0
                        push(visited_labels, tgt)
                        push(worklist, tgt)
                elif op == IR_BR_COND
                    tgt_t = str(ir_inst_src2(inst))
                    tgt_f = str(ir_inst_extra(inst))
                    if ssa_list_contains_str(visited_labels, tgt_t) == 0
                        push(visited_labels, tgt_t)
                        push(worklist, tgt_t)
                    if ssa_list_contains_str(visited_labels, tgt_f) == 0
                        push(visited_labels, tgt_f)
                        push(worklist, tgt_f)
                i = i + 1

    // Prune unreachable blocks from function CFG
    new_blocks = list()
    elim_count = 0
    b_idx = 0
    blen = len(blocks)
    while b_idx < blen
        bb = get(blocks, b_idx)
        lbl = ir_block_label(bb)
        if ssa_list_contains_str(visited_labels, lbl) == 1
            push(new_blocks, bb)
        else
            ir_block_set_dead(bb, 1)
            elim_count = elim_count + 1
        b_idx = b_idx + 1

    list_set(func, 2, new_blocks)
    return elim_count

// Complete multi-pass optimizer pipeline
fn ir_optimize func
    folds = ir_opt_const_fold(func)
    dead_insts = ir_opt_dce(func)
    // Run second pass to clean up cascading dead temporaries revealed by folding
    ir_opt_const_fold(func)
    ir_opt_dce(func)
    return folds + dead_insts


// ==============================================================================
// 🏛️ SECTION 8: SSA IR Execution Engine / Direct Interpreter
// ==============================================================================
// WHY: Executes TAC and SSA IR instructions directly in pure Lipi, enabling
//      rigorous mathematical validation of optimized vs unoptimized program outputs.

fn ir_exec_func func args
    env = ssa_map_new()
    params = ir_func_params(func)
    p_i = 0
    plen = len(params)
    alen = len(args)
    while p_i < plen and p_i < alen
        ssa_map_set(env, get(params, p_i), get(args, p_i))
        p_i = p_i + 1

    cur_bb = ir_func_entry(func)
    prev_bb_label = ""
    step_limit = 1000000
    steps = 0

    while cur_bb != 0 and steps < step_limit
        steps = steps + 1
        insts = ir_block_insts(cur_bb)
        pc = 0
        jumped = 0
        ilen = len(insts)

        while pc < ilen
            inst = get(insts, pc)
            op = ir_inst_op(inst)
            dest = ir_inst_dest(inst)
            s1 = ir_inst_src1(inst)
            s2 = ir_inst_src2(inst)
            ext = ir_inst_extra(inst)

            if op == IR_CONST
                val = ssa_parse_int_val(str(s1))
                ssa_map_set(env, dest, val)

            elif op == IR_COPY
                val = 0
                s1_str = str(s1)
                if ssa_is_numeric_str(s1_str) == 1
                    val = ssa_parse_int_val(s1_str)
                else
                    val = ssa_map_get(env, s1_str, 0)
                ssa_map_set(env, dest, val)

            elif op == IR_ADD or op == IR_SUB or op == IR_MUL or op == IR_DIV or op == IR_MOD
                v1 = 0
                s1_str = str(s1)
                if ssa_is_numeric_str(s1_str) == 1
                    v1 = ssa_parse_int_val(s1_str)
                else
                    v1 = ssa_map_get(env, s1_str, 0)

                v2 = 0
                s2_str = str(s2)
                if ssa_is_numeric_str(s2_str) == 1
                    v2 = ssa_parse_int_val(s2_str)
                else
                    v2 = ssa_map_get(env, s2_str, 0)

                res = 0
                if op == IR_ADD
                    res = v1 + v2
                elif op == IR_SUB
                    res = v1 - v2
                elif op == IR_MUL
                    res = v1 * v2
                elif op == IR_DIV
                    if v2 != 0
                        res = v1 / v2
                    else
                        res = 0
                elif op == IR_MOD
                    if v2 != 0
                        res = v1 % v2
                    else
                        res = 0

                ssa_map_set(env, dest, res)

            elif op == IR_CMP
                v1 = 0
                s1_str = str(s1)
                if ssa_is_numeric_str(s1_str) == 1
                    v1 = ssa_parse_int_val(s1_str)
                else
                    v1 = ssa_map_get(env, s1_str, 0)

                v2 = 0
                s2_str = str(s2)
                if ssa_is_numeric_str(s2_str) == 1
                    v2 = ssa_parse_int_val(s2_str)
                else
                    v2 = ssa_map_get(env, s2_str, 0)

                cmp_op = str(ext)
                res = 0
                if cmp_op == "==" and v1 == v2
                    res = 1
                elif cmp_op == "!=" and v1 != v2
                    res = 1
                elif cmp_op == "<" and v1 < v2
                    res = 1
                elif cmp_op == "<=" and v1 <= v2
                    res = 1
                elif cmp_op == ">" and v1 > v2
                    res = 1
                elif cmp_op == ">=" and v1 >= v2
                    res = 1

                ssa_map_set(env, dest, res)

            elif op == IR_JMP
                prev_bb_label = ir_block_label(cur_bb)
                cur_bb = ir_func_find_block(func, str(ext))
                jumped = 1
                break

            elif op == IR_BR_COND
                cval = 0
                s1_str = str(s1)
                if ssa_is_numeric_str(s1_str) == 1
                    cval = ssa_parse_int_val(s1_str)
                else
                    cval = ssa_map_get(env, s1_str, 0)

                prev_bb_label = ir_block_label(cur_bb)
                if cval != 0
                    cur_bb = ir_func_find_block(func, str(s2))
                else
                    cur_bb = ir_func_find_block(func, str(ext))
                jumped = 1
                break

            elif op == IR_RET
                ret_val = 0
                s1_str = str(s1)
                if s1_str != ""
                    if ssa_is_numeric_str(s1_str) == 1
                        ret_val = ssa_parse_int_val(s1_str)
                    else
                        ret_val = ssa_map_get(env, s1_str, 0)
                return ret_val

            elif op == IR_PHI
                chosen_val = 0
                k = 0
                klen = len(ext)
                while k < klen
                    pair = get(ext, k)
                    val_opnd = str(get(pair, 0))
                    from_lbl = str(get(pair, 1))
                    if from_lbl == prev_bb_label or from_lbl == ""
                        if ssa_is_numeric_str(val_opnd) == 1
                            chosen_val = ssa_parse_int_val(val_opnd)
                        else
                            chosen_val = ssa_map_get(env, val_opnd, 0)
                        break
                    k = k + 1
                ssa_map_set(env, dest, chosen_val)

            pc = pc + 1

        if jumped == 0
            cur_bb = 0

    return 0


// ==============================================================================
// 🏛️ SECTION 9: Diagnostic Printers & Stringifiers
// ==============================================================================
// WHY: Facilitates human-readable inspection and automated test assertion verification.

fn ir_inst_to_str inst
    op = ir_inst_op(inst)
    dest = ir_inst_dest(inst)
    s1 = str(ir_inst_src1(inst))
    s2 = str(ir_inst_src2(inst))
    ext = ir_inst_extra(inst)

    if op == IR_CONST
        return dest + " = const " + s1
    elif op == IR_COPY
        return dest + " = copy " + s1
    elif op == IR_ADD
        return dest + " = " + s1 + " + " + s2
    elif op == IR_SUB
        return dest + " = " + s1 + " - " + s2
    elif op == IR_MUL
        return dest + " = " + s1 + " * " + s2
    elif op == IR_DIV
        return dest + " = " + s1 + " / " + s2
    elif op == IR_MOD
        return dest + " = " + s1 + " % " + s2
    elif op == IR_CMP
        return dest + " = " + s1 + " " + str(ext) + " " + s2
    elif op == IR_JMP
        return "jmp " + str(ext)
    elif op == IR_BR_COND
        return "br_cond " + s1 + ", true=" + s2 + ", false=" + str(ext)
    elif op == IR_CALL
        arg_str = ""
        j = 0
        jlen = len(ext)
        while j < jlen
            if j > 0
                arg_str = arg_str + ", "
            arg_str = arg_str + str(get(ext, j))
            j = j + 1
        if dest != ""
            return dest + " = call " + s1 + "(" + arg_str + ")"
        return "call " + s1 + "(" + arg_str + ")"
    elif op == IR_RET
        if s1 != ""
            return "ret " + s1
        return "ret"
    elif op == IR_PHI
        phi_str = ""
        j = 0
        jlen = len(ext)
        while j < jlen
            pair = get(ext, j)
            if j > 0
                phi_str = phi_str + ", "
            phi_str = phi_str + "[" + str(get(pair, 0)) + ", " + str(get(pair, 1)) + "]"
            j = j + 1
        return dest + " = phi(" + phi_str + ")"

    return "nop"

// Counts total instructions across all basic blocks in a function
fn ir_func_count_insts func
    cnt = 0
    blocks = ir_func_blocks(func)
    i = 0
    blen = len(blocks)
    while i < blen
        bb = get(blocks, i)
        cnt = cnt + len(ir_block_insts(bb))
        i = i + 1
    return cnt

// Checks if any instruction in the function targets or reads a given variable name
fn ir_func_has_symbol func sym
    blocks = ir_func_blocks(func)
    b_idx = 0
    blen = len(blocks)
    while b_idx < blen
        bb = get(blocks, b_idx)
        insts = ir_block_insts(bb)
        i_idx = 0
        ilen = len(insts)
        while i_idx < ilen
            inst = get(insts, i_idx)
            if ir_inst_dest(inst) == sym
                return 1
            if str(ir_inst_src1(inst)) == sym
                return 1
            if str(ir_inst_src2(inst)) == sym
                return 1
            i_idx = i_idx + 1
        b_idx = b_idx + 1
    return 0
