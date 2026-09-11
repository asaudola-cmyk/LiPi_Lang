@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: ENUMS + PATTERN MATCHING IN LOOPS
@! File: tests/e2e/tier3_combinations/test_enum_match_in_loops.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@enum TokenKind
  Number
  Ident
  Plus
  Minus
  Star
  Slash
  LParen
  RParen
  Semi
  EOF
@end

@struct Token
  kind: 0
  val: 0
  text: ""
@end

@struct ScannerStats
  num_count: 0
  ident_count: 0
  op_count: 0
  paren_count: 0
  total_num_sum: 0
@end

@fn process_token_stream(tokens, len)
  stats = { num_count: 0, ident_count: 0, op_count: 0, paren_count: 0, total_num_sum: 0 }
  i = 0
  @while i < len
    tok = tokens[i]
    k = tok.kind
    @if k == 0
      stats.num_count = stats.num_count + 1
      stats.total_num_sum = stats.total_num_sum + tok.val
    @elif k == 1
      stats.ident_count = stats.ident_count + 1
    @elif k == 2 || k == 3 || k == 4 || k == 5
      stats.op_count = stats.op_count + 1
    @elif k == 6 || k == 7
      stats.paren_count = stats.paren_count + 1
    @elif k == 9
      i = len
    @end
    i = i + 1
  @end
  return stats
@end

@fn filter_statements_by_match(tokens, len)
  statements_count = 0
  curr_stmt_ops = 0
  i = 0
  @while i < len
    tok = tokens[i]
    k = tok.kind
    @if k == 8
      statements_count = statements_count + 1
    @elif k == 2 || k == 3 || k == 4 || k == 5
      curr_stmt_ops = curr_stmt_ops + 1
    @elif k == 9
      i = len
    @end
    i = i + 1
  @end
  return { stmt_cnt: statements_count, op_cnt: curr_stmt_ops }
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 4: Enums & Pattern Matching in Loops")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Build token stream:
  @! ( a + 10 ) * ( b - 20 ) / c ;
  @! x = 50 * y + 100 ;
  @! EOF
  stream = [
    { kind: TokenKind_LParen, val: 0, text: "(" },
    { kind: TokenKind_Ident, val: 0, text: "a" },
    { kind: TokenKind_Plus, val: 0, text: "+" },
    { kind: TokenKind_Number, val: 10, text: "10" },
    { kind: TokenKind_RParen, val: 0, text: ")" },
    { kind: TokenKind_Star, val: 0, text: "*" },
    { kind: TokenKind_LParen, val: 0, text: "(" },
    { kind: TokenKind_Ident, val: 0, text: "b" },
    { kind: TokenKind_Minus, val: 0, text: "-" },
    { kind: TokenKind_Number, val: 20, text: "20" },
    { kind: TokenKind_RParen, val: 0, text: ")" },
    { kind: TokenKind_Slash, val: 0, text: "/" },
    { kind: TokenKind_Ident, val: 0, text: "c" },
    { kind: TokenKind_Semi, val: 0, text: ";" },
    { kind: TokenKind_Ident, val: 0, text: "x" },
    { kind: TokenKind_Ident, val: 0, text: "=" },
    { kind: TokenKind_Number, val: 50, text: "50" },
    { kind: TokenKind_Star, val: 0, text: "*" },
    { kind: TokenKind_Ident, val: 0, text: "y" },
    { kind: TokenKind_Plus, val: 0, text: "+" },
    { kind: TokenKind_Number, val: 100, text: "100" },
    { kind: TokenKind_Semi, val: 0, text: ";" },
    { kind: TokenKind_EOF, val: 0, text: "" }
  ]

  @! T3.4.1: Process Token Stream with Loop Match
  total = total + 1
  stats = process_token_stream(stream, stream.len())
  @! Numbers: 10, 20, 50, 100 -> count = 4, sum = 180
  @if stats.num_count == 4 && stats.total_num_sum == 180
    passed = passed + 1
    println("  [PASS] T3.4.1: Enum match in loop accumulated 4 numbers with sum == 180")
  @else
    failed = failed + 1
    println("  [FAIL] T3.4.1: Numbers count expected 4, got " + int_to_str(stats.num_count) + "; sum=" + int_to_str(stats.total_num_sum))
  @end

  @! T3.4.2: Operator & Identifier Counts
  total = total + 1
  @! Identifiers: a, b, c, x, =, y -> 6
  @! Operators: +, *, -, /, *, + -> 6
  @if stats.ident_count == 6 && stats.op_count == 6
    passed = passed + 1
    println("  [PASS] T3.4.2: Enum match accurately categorized 6 identifiers and 6 operators")
  @else
    failed = failed + 1
    println("  [FAIL] T3.4.2: Expected 6 idents, 6 ops; got idents=" + int_to_str(stats.ident_count) + ", ops=" + int_to_str(stats.op_count))
  @end

  @! T3.4.3: Parentheses Balanced Detection
  total = total + 1
  @! 2 LParen + 2 RParen = 4
  @if stats.paren_count == 4
    passed = passed + 1
    println("  [PASS] T3.4.3: Parentheses tokens detected correctly (4 total)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.4.3: Parentheses count mismatch: " + int_to_str(stats.paren_count))
  @end

  @! T3.4.4: Statement Boundary Delimiting via Semi & Early Break on EOF
  total = total + 1
  stmt_res = filter_statements_by_match(stream, stream.len())
  @if stmt_res.stmt_cnt == 2 && stmt_res.op_cnt == 6
    passed = passed + 1
    println("  [PASS] T3.4.4: Multi-statement segmentation (2 statements, 6 operators)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.4.4: Statement segmentation failed")
  @end

  @! T3.4.5: Direct Enum Variant Constant Equality
  total = total + 1
  @if TokenKind_Number == 0 && TokenKind_Ident == 1 && TokenKind_Plus == 2 && TokenKind_EOF == 9
    passed = passed + 1
    println("  [PASS] T3.4.5: Enum discriminant constants match sequential ordinal values (0..9)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.4.5: Enum constants ordinal mismatch")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 4 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 4 (Enums & Pattern Matching in Loops) PASSED")
    return 0
  @else
    println("✗ Combination 4 (Enums & Pattern Matching in Loops) FAILED")
    return 1
  @end
@end
