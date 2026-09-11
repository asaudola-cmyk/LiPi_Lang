@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: PRATT PARSER & AST EVALUATOR
@! File: tests/e2e/tier3_combinations/test_pratt_parser_evaluator.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/core/string"

@struct ASTNode
  node_kind: 0  @! 1=Number, 2=Binary, 3=Unary
  int_val: 0
  op_code: 0    @! 1='+', 2='-', 3='*', 4='/', 5='%', 6='^'
  left_child: 0
  right_child: 0
@end

@struct ParserState
  src: ""
  pos: 0
  len: 0
@end

@fn make_num_node(v)
  return {
    node_kind: 1,
    int_val: v,
    op_code: 0,
    left_child: 0,
    right_child: 0
  }
@end

@fn make_bin_node(op, left, right)
  return {
    node_kind: 2,
    int_val: 0,
    op_code: op,
    left_child: left,
    right_child: right
  }
@end

@fn make_un_node(op, child)
  return {
    node_kind: 3,
    int_val: 0,
    op_code: op,
    left_child: child,
    right_child: 0
  }
@end

@fn skip_whitespace(p)
  @while p.pos < p.len
    c = char_at(p.src, p.pos)
    @if c == char_code(" ") || c == char_code("\t") || c == char_code("\n")
      p.pos = p.pos + 1
    @else
      return p
    @end
  @end
  return p
@end

@fn power_int(b, e)
  @if e <= 0 return 1 @end
  res = 1
  i = 0
  @while i < e
    res = res * b
    i = i + 1
  @end
  return res
@end

@fn parse_number(p)
  num = 0
  @while p.pos < p.len
    c = char_at(p.src, p.pos)
    @if c >= char_code("0") && c <= char_code("9")
      num = num * 10 + (c - char_code("0"))
      p.pos = p.pos + 1
    @else
      return make_num_node(num)
    @end
  @end
  return make_num_node(num)
@end

@fn get_precedence(op)
  @if op == 1 || op == 2  @! '+' or '-'
    return 10
  @elif op == 3 || op == 4 || op == 5  @! '*', '/', '%'
    return 20
  @elif op == 6  @! '^'
    return 30
  @end
  return 0
@end

@fn parse_primary(p)
  skip_whitespace(p)
  @if p.pos >= p.len
    return make_num_node(0)
  @end

  c = char_at(p.src, p.pos)

  @! Unary minus
  @if c == char_code("-")
    p.pos = p.pos + 1
    child = parse_primary(p)
    return make_un_node(2, child)
  @end

  @! Parenthesized expression
  @if c == char_code("(")
    p.pos = p.pos + 1
    expr = parse_expression(p, 0)
    skip_whitespace(p)
    @if p.pos < p.len && char_at(p.src, p.pos) == char_code(")")
      p.pos = p.pos + 1
    @end
    return expr
  @end

  @! Number
  @if c >= char_code("0") && c <= char_code("9")
    return parse_number(p)
  @end

  p.pos = p.pos + 1
  return make_num_node(0)
@end

@fn parse_expression(p, min_prec)
  left = parse_primary(p)

  @while 1
    skip_whitespace(p)
    @if p.pos >= p.len
      return left
    @end

    c = char_at(p.src, p.pos)
    op = 0
    @if c == char_code("+")
      op = 1
    @elif c == char_code("-")
      op = 2
    @elif c == char_code("*")
      op = 3
    @elif c == char_code("/")
      op = 4
    @elif c == char_code("%")
      op = 5
    @elif c == char_code("^")
      op = 6
    @else
      return left
    @end

    prec = get_precedence(op)
    @if prec < min_prec
      return left
    @end

    p.pos = p.pos + 1  @! consume operator

    @! Exponentiation is right-associative (next_min_prec = prec), others left (prec + 1)
    next_min = prec + 1
    @if op == 6
      next_min = prec
    @end

    right = parse_expression(p, next_min)
    left = make_bin_node(op, left, right)
  @end

  return left
@end

@fn evaluate_ast(node)
  @if node == 0
    return 0
  @end

  @if node.node_kind == 1  @! Number
    return node.int_val
  @elif node.node_kind == 3  @! Unary
    child_v = evaluate_ast(node.left_child)
    @if node.op_code == 2
      return 0 - child_v
    @end
    return child_v
  @elif node.node_kind == 2  @! Binary
    lv = evaluate_ast(node.left_child)
    rv = evaluate_ast(node.right_child)
    @match node.op_code
      case 1:
        return lv + rv
      case 2:
        return lv - rv
      case 3:
        return lv * rv
      case 4:
        @if rv == 0 return 0 @end
        return lv / rv
      case 5:
        @if rv == 0 return 0 @end
        return lv % rv
      case 6:
        return power_int(lv, rv)
      case _:
        return 0
    @end
  @end
  return 0
@end

@fn eval_expr_str(expr_str)
  p = { src: expr_str, pos: 0, len: str_len(expr_str) }
  ast = parse_expression(p, 0)
  return evaluate_ast(ast)
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 13: Pratt Parser & AST Evaluator")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.13.1: Standard Precedence (10 + 5 * 2 - 8 / 4 == 18)
  total = total + 1
  r1 = eval_expr_str("10 + 5 * 2 - 8 / 4")
  @if r1 == 18
    passed = passed + 1
    println("  [PASS] T3.13.1: Standard arithmetic operator precedence (10 + 5*2 - 8/4 == 18)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.13.1: Expected 18, got " + int_to_str(r1))
  @end

  @! T3.13.2: Parentheses Overriding Precedence ((15 + 5) * (10 - 2) / 4 == 40)
  total = total + 1
  r2 = eval_expr_str("(15 + 5) * (10 - 2) / 4")
  @if r2 == 40
    passed = passed + 1
    println("  [PASS] T3.13.2: Parenthesized sub-expressions ((15+5)*(10-2)/4 == 40)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.13.2: Expected 40, got " + int_to_str(r2))
  @end

  @! T3.13.3: Exponentiation Operator (2 ^ 10 + 24 == 1048)
  total = total + 1
  r3 = eval_expr_str("2 ^ 10 + 24")
  @if r3 == 1048
    passed = passed + 1
    println("  [PASS] T3.13.3: Power exponentiation (2^10 + 24 == 1048)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.13.3: Expected 1048, got " + int_to_str(r3))
  @end

  @! T3.13.4: Right-Associativity of Exponentiation (2 ^ 3 ^ 2 == 2 ^ 9 == 512)
  total = total + 1
  r4 = eval_expr_str("2 ^ 3 ^ 2")
  @if r4 == 512
    passed = passed + 1
    println("  [PASS] T3.13.4: Right-associative exponentiation (2 ^ 3 ^ 2 == 512)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.13.4: Expected 512, got " + int_to_str(r4))
  @end

  @! T3.13.5: Unary Negation (-5 + 20 * 2 == 35)
  total = total + 1
  r5 = eval_expr_str("-5 + 20 * 2")
  @if r5 == 35
    passed = passed + 1
    println("  [PASS] T3.13.5: Unary negation prefix evaluation (-5 + 20*2 == 35)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.13.5: Expected 35, got " + int_to_str(r5))
  @end

  println("-----------------------------------------------------------------")
  println("Combination 13 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 13 (Pratt Parser & AST Evaluator) PASSED")
    return 0
  @else
    println("✗ Combination 13 (Pratt Parser & AST Evaluator) FAILED")
    return 1
  @end
@end
