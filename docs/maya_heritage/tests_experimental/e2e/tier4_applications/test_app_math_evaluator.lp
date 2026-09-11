@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: PRATT CALCULATOR & MATH AST EVALUATOR
@! File: tests/e2e/tier4_applications/test_app_math_evaluator.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct MathASTNode
  kind: 0        @! 1=Num, 2=Var, 3=Binary, 4=Unary, 5=Call
  int_val: 0
  str_val: ""
  op_code: 0     @! 1='+', 2='-', 3='*', 4='/', 5='%', 6='^'
  left: 0
  right: 0
  args: 0
@end

@struct MathScanner
  src: ""
  pos: 0
  len: 0
@end

@struct EvalResult
  val: 0
  is_err: 0
  err_msg: ""
@end

@fn eval_ok(v)
  return { val: v, is_err: 0, err_msg: "" }
@end

@fn eval_err(msg)
  return { val: 0, is_err: 1, err_msg: msg }
@end

@fn math_skip_ws(s)
  @while s.pos < s.len
    c = char_at(s.src, s.pos)
    @if c == char_code(" ") || c == char_code("\t") || c == char_code("\n")
      s.pos = s.pos + 1
    @else
      return s
    @end
  @end
  return s
@end

@fn eval_factorial_int(n)
  @if n <= 1 return 1 @end
  return n * eval_factorial_int(n - 1)
@end

@fn eval_gcd_int(a, b)
  @while b != 0
    t = b
    b = a % b
    a = t
  @end
  return a
@end

@fn eval_pow_int(b, e)
  @if e <= 0 return 1 @end
  res = 1
  i = 0
  @while i < e
    res = res * b
    i = i + 1
  @end
  return res
@end

@fn math_is_alpha(c)
  return (c >= char_code("a") && c <= char_code("z")) || (c >= char_code("A") && c <= char_code("Z")) || c == char_code("_")
@end

@fn math_is_digit(c)
  return c >= char_code("0") && c <= char_code("9")
@end

@fn parse_math_ident(s)
  name = ""
  @while s.pos < s.len
    c = char_at(s.src, s.pos)
    @if math_is_alpha(c) || math_is_digit(c)
      name = name + from_char(c)
      s.pos = s.pos + 1
    @else
      break
    @end
  @end
  return name
@end

@fn parse_math_number(s)
  num = 0
  @while s.pos < s.len
    c = char_at(s.src, s.pos)
    @if math_is_digit(c)
      num = num * 10 + (c - char_code("0"))
      s.pos = s.pos + 1
    @else
      break
    @end
  @end
  return { kind: 1, int_val: num, str_val: "", op_code: 0, left: 0, right: 0, args: [] }
@end

@fn parse_math_primary(s)
  s = math_skip_ws(s)
  @if s.pos >= s.len
    return { kind: 1, int_val: 0, str_val: "", op_code: 0, left: 0, right: 0, args: [] }
  @end

  c = char_at(s.src, s.pos)

  @! Unary minus
  @if c == char_code("-")
    s.pos = s.pos + 1
    child = parse_math_primary(s)
    return { kind: 4, int_val: 0, str_val: "-", op_code: 2, left: child, right: 0, args: [] }
  @end

  @! Parenthesized
  @if c == char_code("(")
    s.pos = s.pos + 1
    inner = parse_math_expr(s, 0)
    s = math_skip_ws(s)
    @if s.pos < s.len && char_at(s.src, s.pos) == char_code(")")
      s.pos = s.pos + 1
    @end
    return inner
  @end

  @! Number
  @if math_is_digit(c)
    return parse_math_number(s)
  @end

  @! Ident or Function Call
  @if math_is_alpha(c)
    id_name = parse_math_ident(s)
    s = math_skip_ws(s)
    @if s.pos < s.len && char_at(s.src, s.pos) == char_code("(")
      s.pos = s.pos + 1
      call_args = []
      @while 1
        s = math_skip_ws(s)
        @if s.pos >= s.len || char_at(s.src, s.pos) == char_code(")")
          @if s.pos < s.len s.pos = s.pos + 1 @end
          break
        @end
        arg = parse_math_expr(s, 0)
        call_args = call_args.push(arg)
        s = math_skip_ws(s)
        @if s.pos < s.len && char_at(s.src, s.pos) == char_code(",")
          s.pos = s.pos + 1
        @end
      @end
      return { kind: 5, int_val: 0, str_val: id_name, op_code: 0, left: 0, right: 0, args: call_args }
    @end
    return { kind: 2, int_val: 0, str_val: id_name, op_code: 0, left: 0, right: 0, args: [] }
  @end

  s.pos = s.pos + 1
  return { kind: 1, int_val: 0, str_val: "", op_code: 0, left: 0, right: 0, args: [] }
@end

@fn parse_math_expr(s, min_prec)
  left = parse_math_primary(s)

  @while 1
    s = math_skip_ws(s)
    @if s.pos >= s.len
      return left
    @end

    c = char_at(s.src, s.pos)
    op = 0
    prec = 0
    @if c == char_code("+")
      op = 1; prec = 10
    @elif c == char_code("-")
      op = 2; prec = 10
    @elif c == char_code("*")
      op = 3; prec = 20
    @elif c == char_code("/")
      op = 4; prec = 20
    @elif c == char_code("%")
      op = 5; prec = 20
    @elif c == char_code("^")
      op = 6; prec = 30
    @else
      return left
    @end

    @if prec < min_prec
      return left
    @end

    s.pos = s.pos + 1  @! consume op

    next_prec = prec + 1
    @if op == 6
      next_prec = prec  @! Right associative exponentiation
    @end

    right = parse_math_expr(s, next_prec)
    left = { kind: 3, int_val: 0, str_val: "", op_code: op, left: left, right: right, args: [] }
  @end

  return left
@end

@fn eval_math_ast(node, env_keys, env_vals)
  @if node == 0
    return eval_ok(0)
  @end

  @if node.kind == 1  @! Number
    return eval_ok(node.int_val)
  @elif node.kind == 2  @! Variable
    i = 0
    len = env_keys.len()
    @while i < len
      @if env_keys[i] == node.str_val
        return eval_ok(env_vals[i])
      @end
      i = i + 1
    @end
    return eval_err("Undefined variable '" + node.str_val + "'")
  @elif node.kind == 4  @! Unary
    child_res = eval_math_ast(node.left, env_keys, env_vals)
    @if child_res.is_err == 1 return child_res @end
    @if node.op_code == 2
      return eval_ok(0 - child_res.val)
    @end
    return child_res
  @elif node.kind == 3  @! Binary
    l_res = eval_math_ast(node.left, env_keys, env_vals)
    @if l_res.is_err == 1 return l_res @end
    r_res = eval_math_ast(node.right, env_keys, env_vals)
    @if r_res.is_err == 1 return r_res @end

    lv = l_res.val
    rv = r_res.val

    @match node.op_code
      case 1:
        return eval_ok(lv + rv)
      case 2:
        return eval_ok(lv - rv)
      case 3:
        return eval_ok(lv * rv)
      case 4:
        @if rv == 0
          return eval_err("Division by zero error")
        @end
        return eval_ok(lv / rv)
      case 5:
        @if rv == 0
          return eval_err("Modulo by zero error")
        @end
        return eval_ok(lv % rv)
      case 6:
        return eval_ok(eval_pow_int(lv, rv))
      case _:
        return eval_err("Unknown operator")
    @end
  @elif node.kind == 5  @! Function Call
    @if node.str_val == "factorial"
      @if node.args.len() < 1 return eval_err("factorial expects 1 argument") @end
      a1 = eval_math_ast(node.args[0], env_keys, env_vals)
      @if a1.is_err == 1 return a1 @end
      return eval_ok(eval_factorial_int(a1.val))
    @elif node.str_val == "gcd"
      @if node.args.len() < 2 return eval_err("gcd expects 2 arguments") @end
      a1 = eval_math_ast(node.args[0], env_keys, env_vals)
      @if a1.is_err == 1 return a1 @end
      a2 = eval_math_ast(node.args[1], env_keys, env_vals)
      @if a2.is_err == 1 return a2 @end
      return eval_ok(eval_gcd_int(a1.val, a2.val))
    @elif node.str_val == "abs"
      @if node.args.len() < 1 return eval_err("abs expects 1 argument") @end
      a1 = eval_math_ast(node.args[0], env_keys, env_vals)
      @if a1.is_err == 1 return a1 @end
      v = a1.val
      @if v < 0 v = 0 - v @end
      return eval_ok(v)
    @elif node.str_val == "pow"
      @if node.args.len() < 2 return eval_err("pow expects 2 arguments") @end
      a1 = eval_math_ast(node.args[0], env_keys, env_vals)
      @if a1.is_err == 1 return a1 @end
      a2 = eval_math_ast(node.args[1], env_keys, env_vals)
      @if a2.is_err == 1 return a2 @end
      return eval_ok(eval_pow_int(a1.val, a2.val))
    @else
      return eval_err("Unknown function '" + node.str_val + "'")
    @end
  @end

  return eval_err("Invalid AST node")
@end

@fn calc_eval(expr_str, env_keys, env_vals)
  s = { src: expr_str, pos: 0, len: str_len(expr_str) }
  ast = parse_math_expr(s, 0)
  return eval_math_ast(ast, env_keys, env_vals)
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 4: Pratt Calculator & AST Evaluator")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  env_keys = ["x", "y", "rate"]
  env_vals = [48, 18, 5]

  @! T4.4.1: Complex Arithmetic Precedence: 10 + 5 * 2 - 8 / 4 == 18
  total = total + 1
  r1 = calc_eval("10 + 5 * 2 - 8 / 4", env_keys, env_vals)
  @if r1.is_err == 0 && r1.val == 18
    passed = passed + 1
    println("  [PASS] T4.4.1: Evaluated 10 + 5 * 2 - 8 / 4 == 18")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.1: Failed: " + int_to_str(r1.val))
  @end

  @! T4.4.2: Parentheses Nested Expression: ((15 + 5) * (10 - 2)) / 4 == 40
  total = total + 1
  r2 = calc_eval("((15 + 5) * (10 - 2)) / 4", env_keys, env_vals)
  @if r2.is_err == 0 && r2.val == 40
    passed = passed + 1
    println("  [PASS] T4.4.2: Evaluated ((15 + 5) * (10 - 2)) / 4 == 40")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.2: Failed: " + int_to_str(r2.val))
  @end

  @! T4.4.3: Exponentiation Power: 2 ^ 10 + 24 == 1048
  total = total + 1
  r3 = calc_eval("2 ^ 10 + 24", env_keys, env_vals)
  @if r3.is_err == 0 && r3.val == 1048
    passed = passed + 1
    println("  [PASS] T4.4.3: Evaluated 2 ^ 10 + 24 == 1048")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.3: Failed: " + int_to_str(r3.val))
  @end

  @! T4.4.4: Builtin Math Functions (factorial, gcd, variables)
  total = total + 1
  @! factorial(6) / (factorial(3) * factorial(3)) = 720 / 36 = 20
  r4_fact = calc_eval("factorial(6) / (factorial(3) * factorial(3))", env_keys, env_vals)
  @! gcd(x, y) with x=48, y=18 = 6
  r4_gcd = calc_eval("gcd(x, y)", env_keys, env_vals)

  @if r4_fact.is_err == 0 && r4_fact.val == 20 && r4_gcd.is_err == 0 && r4_gcd.val == 6
    passed = passed + 1
    println("  [PASS] T4.4.4: Factorial combinations (20) & variable-bound GCD(48, 18) == 6")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.4: Functions/variables evaluation failed")
  @end

  @! T4.4.5: Division by Zero & Undefined Variable Handling
  total = total + 1
  r_div0 = calc_eval("100 / 0", env_keys, env_vals)
  r_undef = calc_eval("z + 10", env_keys, env_vals)

  @if r_div0.is_err == 1 && r_div0.err_msg == "Division by zero error" && r_undef.is_err == 1
    passed = passed + 1
    println("  [PASS] T4.4.5: Division by zero and undefined variable gracefully returned error Result")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.5: Error handling failed")
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 4 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 4 (Pratt Calculator & AST Evaluator) PASSED")
    return 0
  @else
    println("✗ Scenario 4 (Pratt Calculator & AST Evaluator) FAILED")
    return 1
  @end
@end
