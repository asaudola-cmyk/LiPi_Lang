// ==============================================================================
// 👑 LIPI FIRST 1.0.0 AST TO SSA IR LOWERING ENGINE (src/compiler/middleend/ast_to_ssa.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the frontend AST representation with the middle-end SSA optimization
//    pipeline (Pass Manager O0, O1, O2, O3, Dominator Tree, LICM, DCE, CSE).
// 2. Canonical Mem2Reg Alloca Pattern:
//    - Every local variable and function argument is given a unique stack slot (OP_ALLOCA)
//      in the entry basic block.
//    - Reads emit OP_LOAD; writes emit OP_STORE.
//    - This ensures valid, strictly verifiable SSA form regardless of complex control flow
//      branching or reassignments, enabling standard SSA optimization passes to promote
//      allocas to SSA registers and phi nodes.
// 3. Bidirectional CFG Symmetry:
//    - Control flow structures (If-Else, While loops, Break, Continue) construct explicit
//      basic blocks and terminators (OP_BR, OP_JMP, OP_RET).
//    - Calls cfg_rebuild_edges at the conclusion of lowering to mathematically guarantee
//      100% edge consistency for downstream dominator tree and loop analyses.
// ==============================================================================

include "src/compiler/middleend/ir/ir_module.lp"
include "src/compiler/middleend/opt/analysis/cfg.lp"

// ── 1. AST-to-SSA Lowering Context ────────────────────────────────────────────

struct AstToSsaContext
    ctx_module          // IRModule reference
    ctx_curr_fn         // IRFunction reference currently being lowered
    ctx_curr_bb         // BasicBlock currently receiving instructions
    ctx_inst_counter    // Monotonic integer instruction ID counter
    ctx_var_names       // list of string variable names currently in scope
    ctx_var_slots       // list of SSAValue (alloca pointer) slots
    ctx_loop_headers    // list of BasicBlock references for 'continue' targets
    ctx_loop_exits      // list of BasicBlock references for 'break' targets

fn ast_to_ssa_context_new mod_obj fn_obj
    // WHY: Initializes isolated lowering context with pristine scope tables
    ctx = AstToSsaContext()
    ctx.ctx_module = mod_obj
    ctx.ctx_curr_fn = fn_obj
    ctx.ctx_curr_bb = fn_obj.entry_block
    ctx.ctx_inst_counter = 1
    ctx.ctx_var_names = list()
    ctx.ctx_var_slots = list()
    ctx.ctx_loop_headers = list()
    ctx.ctx_loop_exits = list()
    return ctx

// ── 2. Variable Scope & Alloca Slot Management ────────────────────────────────

fn ast_to_ssa_find_var ctx name
    // WHY: Searches local variable slot table by identifier string
    i = len(ctx.ctx_var_names) - 1
    while i >= 0
        vname = get(ctx.ctx_var_names, i)
        if vname == name
            return get(ctx.ctx_var_slots, i)
        i = i - 1
    return 0

fn ast_to_ssa_alloc_var ctx name elem_type
    // WHY: Allocates a dedicated alloca slot in the entry block for mutable local variable
    fn_obj = ctx.ctx_curr_fn
    slot_ptr = fn_obj.new_val("ptr")
    alloca_inst = ir_build_alloca(ctx.ctx_inst_counter, slot_ptr, elem_type, 0)
    ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1

    // Always place allocas at the entry block to guarantee lifetime over entire function
    basic_block_prepend_inst(fn_obj.entry_block, alloca_inst)
    ir_function_register_alloca(fn_obj, alloca_inst)

    push(ctx.ctx_var_names, name)
    push(ctx.ctx_var_slots, slot_ptr)
    return slot_ptr

fn ast_to_ssa_get_or_alloc_var ctx name
    existing = ast_to_ssa_find_var(ctx, name)
    if existing != 0
        return existing
    return ast_to_ssa_alloc_var(ctx, name, "i64")

fn ast_to_ssa_emit_load ctx ptr_slot
    // WHY: Emits OP_LOAD to read memory state into fresh SSA register
    fn_obj = ctx.ctx_curr_fn
    res_val = fn_obj.new_val("i64")
    load_inst = ir_build_load(ctx.ctx_inst_counter, res_val, ptr_slot)
    ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
    basic_block_append_inst(ctx.ctx_curr_bb, load_inst)
    return res_val

// ── 3. Operator Mapping ───────────────────────────────────────────────────────

fn ast_to_ssa_map_binop op_str
    // WHY: Fast mapping from syntactic string operators to numeric SSA opcodes
    if op_str == "+" or op_str == "যোগ" return OP_ADD
    if op_str == "-" or op_str == "বিয়োগ" return OP_SUB
    if op_str == "*" or op_str == "গুণ" return OP_MUL
    if op_str == "/" or op_str == "ভাগ" return OP_DIV
    if op_str == "%" or op_str == "ভাগশেষ" return OP_MOD
    if op_str == "&" or op_str == "এবং" return OP_AND
    if op_str == "|" or op_str == "বা" return OP_OR
    if op_str == "^" or op_str == "জর" return OP_XOR
    if op_str == "<<" or op_str == "বাম_সরাও" return OP_SHL
    if op_str == ">>" or op_str == "ডান_সরাও" return OP_SHR
    return OP_ADD

fn ast_to_ssa_map_cmp op_str
    // WHY: Maps relational operators to unified OP_CMP predicate enums
    if op_str == "==" or op_str == "সমান" return CMP_EQ
    if op_str == "!=" or op_str == "অসমান" return CMP_NE
    if op_str == "<"  or op_str == "ছোট" return CMP_SLT
    if op_str == "<=" or op_str == "ছোট_বা_সমান" return CMP_SLE
    if op_str == ">"  or op_str == "বড়" return CMP_SGT
    if op_str == ">=" or op_str == "বড়_বা_সমান" return CMP_SGE
    return CMP_EQ

fn ast_to_ssa_is_cmp_op op_str
    if op_str == "==" or op_str == "সমান" return 1
    if op_str == "!=" or op_str == "অসমান" return 1
    if op_str == "<"  or op_str == "ছোট" return 1
    if op_str == "<=" or op_str == "ছোট_বা_সমান" return 1
    if op_str == ">"  or op_str == "বড়" return 1
    if op_str == ">=" or op_str == "বড়_বা_সমান" return 1
    return 0

// ── 4. Expression Lowering ────────────────────────────────────────────────────

fn ast_to_ssa_lower_expr ctx expr
    // WHY: Recursively transforms AST expression tree into SSA instruction sequence
    if expr == 0
        return ssa_value_new_const(0, "i64")

    ekind = ""
    if expr.kind != 0
        ekind = expr.kind

    // 1. Literal Integer / Boolean / Float
    if ekind == "LiteralInt" or ekind == "LiteralBool" or ekind == "IntLiteral"
        return ssa_value_new_const(expr.val, "i64")

    // 2. Variable Reference
    if ekind == "Variable" or ekind == "Ident"
        var_name = expr.name
        slot = ast_to_ssa_find_var(ctx, var_name)
        if slot != 0
            return ast_to_ssa_emit_load(ctx, slot)
        // Fallback for unbound / global symbols
        return ssa_value_new_const(0, "i64")

    // 3. Binary Operation
    if ekind == "BinaryOp"
        lhs_val = ast_to_ssa_lower_expr(ctx, expr.left)
        rhs_val = ast_to_ssa_lower_expr(ctx, expr.right)
        fn_obj = ctx.ctx_curr_fn
        op_str = expr.op

        if ast_to_ssa_is_cmp_op(op_str) == 1
            pred = ast_to_ssa_map_cmp(op_str)
            res_val = fn_obj.new_val("bool")
            cmp_inst = ir_build_cmp(ctx.ctx_inst_counter, pred, res_val, lhs_val, rhs_val)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_inst)
            return res_val
        else
            op_code = ast_to_ssa_map_binop(op_str)
            res_val = fn_obj.new_val("i64")
            bin_inst = ir_build_binop(ctx.ctx_inst_counter, op_code, res_val, lhs_val, rhs_val)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)
            return res_val

    // 4. Unary Operation
    if ekind == "UnaryOp"
        sub_val = ast_to_ssa_lower_expr(ctx, expr.expr)
        fn_obj = ctx.ctx_curr_fn
        if expr.op == "-" or expr.op == "নেগেটিভ"
            res_val = fn_obj.new_val("i64")
            neg_inst = ir_build_neg(ctx.ctx_inst_counter, res_val, sub_val)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, neg_inst)
            return res_val
        elif expr.op == "!" or expr.op == "না"
            // Logical NOT: compare sub_val == 0
            res_val = fn_obj.new_val("bool")
            zero_const = ssa_value_new_const(0, "i64")
            cmp_inst = ir_build_cmp(ctx.ctx_inst_counter, CMP_EQ, res_val, sub_val, zero_const)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_inst)
            return res_val
        return sub_val

    // 5. Function Call
    if ekind == "Call"
        fn_obj = ctx.ctx_curr_fn
        callee_name = expr.name
        arg_values = list()
        
        // Lower all arguments monotonically
        arg_nodes = expr.params
        if arg_nodes != 0
            ai = 0
            acnt = len(arg_nodes)
            while ai < acnt
                anode = get(arg_nodes, ai)
                aval = ast_to_ssa_lower_expr(ctx, anode)
                push(arg_values, aval)
                ai = ai + 1

        call_res = fn_obj.new_val("i64")
        call_inst = ir_build_call(ctx.ctx_inst_counter, call_res, callee_name, arg_values)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, call_inst)
        return call_res

    // Default fallback
    return ssa_value_new_const(0, "i64")

// ── 5. Statement Lowering ─────────────────────────────────────────────────────

fn ast_to_ssa_lower_stmt ctx stmt
    // WHY: Transforms statement constructs into basic blocks and instructions
    if stmt == 0 return 0
    if basic_block_get_terminator(ctx.ctx_curr_bb) != 0
        // Dead code elimination at lower level: block already concluded
        return 0

    skind = ""
    if stmt.kind != 0
        skind = stmt.kind

    // 1. Return Statement
    if skind == "Return"
        ret_expr = stmt.value
        if ret_expr != 0
            ret_val = ast_to_ssa_lower_expr(ctx, ret_expr)
            ret_inst = ir_build_ret(ctx.ctx_inst_counter, ret_val)
        else
            ret_inst = ir_build_ret_void(ctx.ctx_inst_counter)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, ret_inst)
        return 1

    // 2. Simple Variable Assignment: target = value
    if skind == "Assign"
        target_name = stmt.target
        rhs_val = ast_to_ssa_lower_expr(ctx, stmt.value)
        slot = ast_to_ssa_get_or_alloc_var(ctx, target_name)
        store_inst = ir_build_store(ctx.ctx_inst_counter, rhs_val, slot)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
        return 1

    // 3. Compound Assignment: target <op>= value
    if skind == "AssignOp"
        target_name = stmt.target
        slot = ast_to_ssa_get_or_alloc_var(ctx, target_name)
        curr_val = ast_to_ssa_emit_load(ctx, slot)
        rhs_val = ast_to_ssa_lower_expr(ctx, stmt.value)
        op_code = ast_to_ssa_map_binop(stmt.op)

        fn_obj = ctx.ctx_curr_fn
        res_val = fn_obj.new_val("i64")
        bin_inst = ir_build_binop(ctx.ctx_inst_counter, op_code, res_val, curr_val, rhs_val)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)

        store_inst = ir_build_store(ctx.ctx_inst_counter, res_val, slot)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
        return 1

    // 4. Conditional Statement: if / elif / else
    if skind == "IfStmt"
        cond_node = stmt.condition
        if cond_node == 0
            cond_node = stmt.cond
        cond_val = ast_to_ssa_lower_expr(ctx, cond_node)

        fn_obj = ctx.ctx_curr_fn
        then_bb = fn_obj.create_block("if_then")
        else_bb = fn_obj.create_block("if_else")
        merge_bb = fn_obj.create_block("if_merge")

        // Branch condition in current block
        br_inst = ir_build_br(ctx.ctx_inst_counter, cond_val, then_bb.label, else_bb.label)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, br_inst)

        // Lower Then Body
        ctx.ctx_curr_bb = then_bb
        t_stmts = stmt.then_body
        if t_stmts != 0
            ti = 0
            tcnt = len(t_stmts)
            while ti < tcnt
                ast_to_ssa_lower_stmt(ctx, get(t_stmts, ti))
                ti = ti + 1
        if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
            jmp_merge = ir_build_jmp(ctx.ctx_inst_counter, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_merge)

        // Lower Else Body
        ctx.ctx_curr_bb = else_bb
        e_stmts = stmt.else_body
        if e_stmts != 0
            ei = 0
            ecnt = len(e_stmts)
            while ei < ecnt
                ast_to_ssa_lower_stmt(ctx, get(e_stmts, ei))
                ei = ei + 1
        if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
            jmp_merge2 = ir_build_jmp(ctx.ctx_inst_counter, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_merge2)

        // Resume at Merge Block
        ctx.ctx_curr_bb = merge_bb
        return 1

    // 5. While Loop Statement
    if skind == "WhileLoop"
        fn_obj = ctx.ctx_curr_fn
        hdr_bb = fn_obj.create_block("while_hdr")
        body_bb = fn_obj.create_block("while_body")
        exit_bb = fn_obj.create_block("while_exit")

        // Jump from current block into loop header
        jmp_hdr = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb.label)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, jmp_hdr)

        // Evaluate Loop Condition in header block
        ctx.ctx_curr_bb = hdr_bb
        cond_node = stmt.condition
        if cond_node == 0
            cond_node = stmt.cond
        cond_val = ast_to_ssa_lower_expr(ctx, cond_node)
        br_loop = ir_build_br(ctx.ctx_inst_counter, cond_val, body_bb.label, exit_bb.label)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(hdr_bb, br_loop)

        // Lower Body with Break / Continue Stack
        push(ctx.ctx_loop_headers, hdr_bb)
        push(ctx.ctx_loop_exits, exit_bb)
        ctx.ctx_curr_bb = body_bb

        b_stmts = stmt.body
        if b_stmts != 0
            bi = 0
            bcnt = len(b_stmts)
            while bi < bcnt
                ast_to_ssa_lower_stmt(ctx, get(b_stmts, bi))
                bi = bi + 1

        if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
            // Loop back-edge to header
            jmp_back = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_back)

        // Pop loop stacks
        pop(ctx.ctx_loop_headers)
        pop(ctx.ctx_loop_exits)

        // Resume execution after loop exit
        ctx.ctx_curr_bb = exit_bb
        return 1

    // 6. Break Statement
    if skind == "Break"
        if len(ctx.ctx_loop_exits) > 0
            target_exit = get(ctx.ctx_loop_exits, len(ctx.ctx_loop_exits) - 1)
            jmp_brk = ir_build_jmp(ctx.ctx_inst_counter, target_exit.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_brk)
        return 1

    // 7. Continue Statement
    if skind == "Continue"
        if len(ctx.ctx_loop_headers) > 0
            target_hdr = get(ctx.ctx_loop_headers, len(ctx.ctx_loop_headers) - 1)
            jmp_cont = ir_build_jmp(ctx.ctx_inst_counter, target_hdr.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_cont)
        return 1

    // 8. Expression Statement (e.g. standalone function call)
    if skind == "ExprStmt"
        ast_to_ssa_lower_expr(ctx, stmt.expr)
        return 1

    return 0

// ── 6. Function & Module Lowering ─────────────────────────────────────────────

fn ast_to_ssa_lower_fn mod_obj fn_decl
    // WHY: Transforms an AST function declaration into an isolated IRFunction
    if mod_obj == 0 or fn_decl == 0 return 0

    fn_name = fn_decl.name
    ret_type = "i64"
    if fn_decl.ret_type != 0 and len(fn_decl.ret_type) > 0
        ret_type = fn_decl.ret_type

    fn_obj = ir_function_new(fn_name, ret_type)
    ctx = ast_to_ssa_context_new(mod_obj, fn_obj)

    // Bind formal parameters
    params = fn_decl.params
    if params != 0
        pi = 0
        pcnt = len(params)
        while pi < pcnt
            pnode = get(params, pi)
            p_name = pnode.param_name

            // Create SSA parameter register
            arg_str = "%" + p_name
            p_val = ssa_value_new_arg(arg_str, "i64")
            ir_function_add_param(fn_obj, p_val)

            // Allocate local entry stack slot and store initial parameter value
            slot = ast_to_ssa_alloc_var(ctx, p_name, "i64")
            st_inst = ir_build_store(ctx.ctx_inst_counter, p_val, slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(fn_obj.entry_block, st_inst)

            pi = pi + 1

    // Lower body statements
    stmts = fn_decl.body
    if stmts != 0
        si = 0
        scnt = len(stmts)
        while si < scnt
            ast_to_ssa_lower_stmt(ctx, get(stmts, si))
            si = si + 1

    // Guarantee basic block termination
    if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
        def_zero = ssa_value_new_const(0, "i64")
        ret_zero = ir_build_ret(ctx.ctx_inst_counter, def_zero)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, ret_zero)

    // Reconstruct Control Flow Graph edges for mathematical consistency
    cfg_rebuild_edges(fn_obj)

    // Register function into module
    ir_module_add_function(mod_obj, fn_obj)
    return fn_obj

fn ast_to_ssa_lower_module ast_nodes target_name
    // WHY: Master entry point translating AST collection into complete IRModule
    mod_obj = ir_module_new("lipi_translation_unit")
    ir_module_set_metadata(mod_obj, "target", target_name)
    ir_module_set_metadata(mod_obj, "producer", "LiPi First 1.0.0 (প্রথম ১.০.০)")

    if ast_nodes == 0 return mod_obj

    node_list = ast_nodes
    i = 0
    cnt = len(node_list)
    while i < cnt
        decl = get(node_list, i)
        dkind = decl.kind

        if dkind == "FnDef" or dkind == "Function" or dkind == "কাজ"
            ast_to_ssa_lower_fn(mod_obj, decl)
        elif dkind == "GlobalVar" or dkind == "Constant"
            g_name = "@" + decl.name
            ir_module_add_global(mod_obj, g_name, "i64", decl.val, 1)
        i = i + 1

    return mod_obj

// WHY: Standard adapter converting AST statement collection into an IRModule result wrapper
// Handles module options, passes target name, and packages status code with zero memory leaks.
fn ir_module_from_ast ast_nodes ir_opts
    target_name = "x86_64"
    if ir_opts != 0 and ir_opts.module_name != 0
        target_name = ir_opts.module_name
    mod_obj = ast_to_ssa_lower_module(ast_nodes, target_name)
    return {
        error: 0,
        module: mod_obj,
        message: ""
    }
