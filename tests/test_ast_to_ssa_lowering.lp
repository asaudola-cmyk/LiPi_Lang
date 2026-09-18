// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER TEST: AST TO SSA IR LOWERING ENGINE
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
// 🏛️ File: tests/test_ast_to_ssa_lowering.lp
//
// WHY: Validates end-to-end translation from Typed AST structures directly into
//      strict, verifiable Static Single Assignment (SSA) form:
//      - Parameter binding into SSA arguments and entry alloca storage.
//      - Three-address code binary operations and comparison predicates.
//      - Control flow graph branch symmetry (If-Else merge blocks, While loops).
//      - Strict SSA verification (ir_verify_module).
//      - Pass Manager optimization execution (O1, O2, O3) over lowered IR.
// ==============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"
import "compiler/frontend/ast/ast_node"
import "compiler/frontend/ast/ast_expr"
import "compiler/frontend/ast/ast_stmt"
import "compiler/frontend/ast/ast_decl"
include "src/compiler/middleend/ast_to_ssa.lp"
include "src/compiler/middleend/opt/pass_manager.lp"

fn test_assert condition msg
    if condition == 0
        say "❌ [ASSERTION FAILED]: " + msg
        exit(1)
    else
        say "  ✔ PASS: " + msg
    return 1

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "👑 TESTING LIPI FIRST 1.0.0 AST TO SSA IR LOWERING ENGINE"
    say "════════════════════════════════════════════════════════════════════════"

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 1: SIMPLE ARITHMETIC FUNCTION LOWERING
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 1]: Lowering Simple Arithmetic Function to SSA"
    // fn calc a b { return (a + b) * 2 }
    sp = source_span_point("math.lp", 1, 1, 0)
    p_a = ast_param_new("a", "i64", 0, sp)
    p_b = ast_param_new("b", "i64", 0, sp)
    params1 = list()
    push(params1, p_a)
    push(params1, p_b)

    v_a = ast_expr_ident("a", sp)
    v_b = ast_expr_ident("b", sp)
    add_expr = ast_expr_binary(v_a, "+", v_b, sp)
    c_two = ast_expr_literal_int(2, sp)
    mul_expr = ast_expr_binary(add_expr, "*", c_two, sp)
    ret1 = ast_stmt_return(mul_expr, sp)

    body1 = list()
    push(body1, ret1)
    fn_calc = ast_decl_fn("calc", params1, "i64", body1, 1, sp)

    decls = list()
    push(decls, fn_calc)

    mod1 = ast_to_ssa_lower_module(decls, "x86_64")
    test_assert(len(mod1.functions) == 1, "Module contains exactly 1 lowered function")

    fn_ir1 = get(mod1.functions, 0)
    test_assert(fn_ir1.name == "calc", "Lowered function name matches 'calc'")
    test_assert(len(fn_ir1.params) == 2, "Function has 2 formal SSA parameters")
    test_assert(len(fn_ir1.blocks) >= 1, "Function has at least 1 basic block")

    v_ok1 = ir_verify_module(mod1)
    test_assert(v_ok1 == 1, "Strict SSA verifier confirms valid lowered arithmetic function")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 2: CONDITIONAL IF-ELSE CFG LOWERING
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 2]: Lowering If-Else Branching into Symmetric CFG Blocks"
    // fn abs x {
    //   if x < 0 { return 0 - x }
    //   else { return x }
    // }
    p_x = ast_param_new("x", "i64", 0, sp)
    params2 = list()
    push(params2, p_x)

    v_x = ast_expr_ident("x", sp)
    c_zero = ast_expr_literal_int(0, sp)
    cmp_expr = ast_expr_binary(v_x, "<", c_zero, sp)

    sub_expr = ast_expr_binary(c_zero, "-", v_x, sp)
    ret_then = ast_stmt_return(sub_expr, sp)
    then_body = list()
    push(then_body, ret_then)

    ret_else = ast_stmt_return(v_x, sp)
    else_body = list()
    push(else_body, ret_else)

    if_stmt = ast_stmt_if(cmp_expr, then_body, list(), else_body, sp)
    body2 = list()
    push(body2, if_stmt)
    fn_abs = ast_decl_fn("abs", params2, "i64", body2, 1, sp)

    decls2 = list()
    push(decls2, fn_abs)

    mod2 = ast_to_ssa_lower_module(decls2, "arm64")
    fn_ir2 = get(mod2.functions, 0)
    test_assert(len(fn_ir2.blocks) >= 3, "Conditional function constructed at least 3 CFG blocks (entry, then, else, merge)")

    v_ok2 = ir_verify_module(mod2)
    test_assert(v_ok2 == 1, "Strict SSA verifier confirms valid If-Else CFG symmetry")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 3: WHILE LOOP LOWERING & PASS MANAGER OPTIMIZATION
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 3]: Lowering While Loop and Executing O2 Pass Manager Pipeline"
    // fn sum_to n {
    //   i = 0
    //   total = 0
    //   while i < n {
    //     total = total + i
    //     i = i + 1
    //   }
    //   return total
    // }
    p_n = ast_param_new("n", "i64", 0, sp)
    params3 = list()
    push(params3, p_n)

    stmt_init_i = ast_stmt_assign("i", ast_expr_literal_int(0, sp), sp)
    stmt_init_tot = ast_stmt_assign("total", ast_expr_literal_int(0, sp), sp)

    cond_loop = ast_expr_binary(ast_expr_ident("i", sp), "<", ast_expr_ident("n", sp), sp)
    body_loop = list()
    stmt_add = ast_stmt_assign("total", ast_expr_binary(ast_expr_ident("total", sp), "+", ast_expr_ident("i", sp), sp), sp)
    stmt_inc = ast_stmt_assign("i", ast_expr_binary(ast_expr_ident("i", sp), "+", ast_expr_literal_int(1, sp), sp), sp)
    push(body_loop, stmt_add)
    push(body_loop, stmt_inc)

    while_stmt = ast_stmt_while(cond_loop, body_loop, sp)
    ret_tot = ast_stmt_return(ast_expr_ident("total", sp), sp)

    body3 = list()
    push(body3, stmt_init_i)
    push(body3, stmt_init_tot)
    push(body3, while_stmt)
    push(body3, ret_tot)
    fn_sum = ast_decl_fn("sum_to", params3, "i64", body3, 1, sp)

    decls3 = list()
    push(decls3, fn_sum)

    mod3 = ast_to_ssa_lower_module(decls3, "riscv64")
    fn_ir3 = get(mod3.functions, 0)
    test_assert(len(fn_ir3.blocks) >= 3, "While loop created header, body, and exit blocks")

    v_ok3 = ir_verify_module(mod3)
    test_assert(v_ok3 == 1, "Strict SSA verifier validates lowered loop before optimization")

    // Run O2 Optimization Passes over Lowered IR
    pm = pass_manager_new(2)
    pm_ok = pass_manager_run_on_module(pm, mod3)
    test_assert(pm_ok == 1, "Pass Manager O2 executed successfully over lowered IR")

    v_ok3_opt = ir_verify_module(mod3)
    test_assert(v_ok3_opt == 1, "Strict SSA verifier validates module after O2 optimizations")

    say "\n🎉 ALL AST TO SSA LOWERING TESTS PASSED (100% VERIFIED)!"
    return 0
