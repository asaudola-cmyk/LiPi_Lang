@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP 5: ARITHMETIC EXPRESSION EVALUATOR
@! File: tests/e2e/tier4_applications/test_expression_evaluator.maya
@! ============================================================================

import "universe/core/collections"

@! AST Node Types for Expression Tree:
@! 1 = Number, 2 = BinaryOp (+, -, *, /)

@struct ExprAST
  kind: 0
  num_val: 0
  op_code: 0  @! 1=+, 2=-, 3=*, 4=/
  left: 0
  right: 0
@end

@fn make_num_node(val)
  return { kind: 1, num_val: val, op_code: 0, left: 0, right: 0 }
@end

@fn make_binop_node(op, left, right)
  return { kind: 2, num_val: 0, op_code: op, left: left, right: right }
@end

@fn eval_ast(node)
  @if node.kind == 1
    return node.num_val
  @end

  left_val = eval_ast(node.left)
  right_val = eval_ast(node.right)

  @match node.op_code
    case 1: @! +
      return left_val + right_val
    case 2: @! -
      return left_val - right_val
    case 3: @! *
      return left_val * right_val
    case 4: @! /
      return left_val / right_val
    case _:
      return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application 5: Mathematical Expression AST Evaluator")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.5.1: Evaluate Simple Addition Node: 15 + 27 = 42
  total = total + 1
  n15 = make_num_node(15)
  n27 = make_num_node(27)
  plus_node = make_binop_node(1, n15, n27)
  res_42 = eval_ast(plus_node)
  @if res_42 == 42
    passed = passed + 1
    println("  [PASS] T4.5.1: Single binary addition node evaluated (15 + 27 == 42)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.1: Single binary addition node")
  @end

  @! T4.5.2: Precedence Tree: 2 + (3 * 4) = 14
  total = total + 1
  n2 = make_num_node(2)
  n3 = make_num_node(3)
  n4 = make_num_node(4)
  mul_node = make_binop_node(3, n3, n4)
  tree_prec = make_binop_node(1, n2, mul_node)
  res_14 = eval_ast(tree_prec)
  @if res_14 == 14
    passed = passed + 1
    println("  [PASS] T4.5.2: Precedence expression AST evaluation: 2 + (3 * 4) == 14")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.2: Precedence expression AST evaluation")
  @end

  @! T4.5.3: Grouped Parentheses Tree: (2 + 3) * 4 = 20
  total = total + 1
  add_grp = make_binop_node(1, n2, n3)
  tree_grp = make_binop_node(3, add_grp, n4)
  res_20 = eval_ast(tree_grp)
  @if res_20 == 20
    passed = passed + 1
    println("  [PASS] T4.5.3: Parenthesized grouped AST evaluation: (2 + 3) * 4 == 20")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.3: Parenthesized grouped AST evaluation")
  @end

  @! T4.5.4: Complex Nested Expression: ((10 + 2) * 5 - 4) / 8 = 7
  total = total + 1
  n10 = make_num_node(10)
  n5 = make_num_node(5)
  n8 = make_num_node(8)
  step1 = make_binop_node(1, n10, n2)     @! 10 + 2 = 12
  step2 = make_binop_node(3, step1, n5)    @! 12 * 5 = 60
  step3 = make_binop_node(2, step2, n4)    @! 60 - 4 = 56
  step4 = make_binop_node(4, step3, n8)    @! 56 / 8 = 7
  res_complex = eval_ast(step4)
  @if res_complex == 7
    passed = passed + 1
    println("  [PASS] T4.5.4: Multi-tier nested expression AST: ((10 + 2) * 5 - 4) / 8 == 7")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.4: Multi-tier nested expression AST")
  @end

  @! T4.5.5: Expression with Negative Outcome: (10 - 25) * 2 = -30
  total = total + 1
  n25 = make_num_node(25)
  sub_neg = make_binop_node(2, n10, n25)  @! 10 - 25 = -15
  mul_neg = make_binop_node(3, sub_neg, n2) @! -15 * 2 = -30
  res_neg = eval_ast(mul_neg)
  @if res_neg == -30
    passed = passed + 1
    println("  [PASS] T4.5.5: Negative result expression evaluation: (10 - 25) * 2 == -30")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.5: Negative result expression evaluation")
  @end

  println("-----------------------------------------------------------------")
  println("App 5 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Application 5 (Expression Evaluator) PASSED")
    return 0
  @else
    println("✗ Application 5 (Expression Evaluator) FAILED")
    return 1
  @end
@end
