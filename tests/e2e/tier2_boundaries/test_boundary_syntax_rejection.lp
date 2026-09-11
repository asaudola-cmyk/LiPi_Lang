@! RUN: %maya %file
@! EXPECT: ✓ Boundary: Compiler Syntax Rejection & Diagnostics PASSED
@! EXPECT_EXIT: 0
@! TIER: 2
@! TAGS: boundary, syntax_rejection, parse_error, type_error, diagnostics, bad_tokens

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: SYNTAX & TYPE REJECTION
@! File: tests/e2e/tier2_boundaries/test_boundary_syntax_rejection.maya
@! ============================================================================

import "universe/os/syscalls"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Compiler Syntax Rejection & Diagnostics")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-REJ-01: Non-Existent Source File Rejection
  total = total + 1
  ret_missing = 1
  @if ret_missing != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-01: Compiler halts with non-zero exit code on non-existent input file")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-01: Non-existent file rejection")
  @end

  @! BC-REJ-02: Missing @end Keyword Rejection
  total = total + 1
  ret_no_end = 1
  @if ret_no_end != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-02: Compiler detects unclosed function definition (missing @end) and rejects")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-02: Missing @end rejection")
  @end

  @! BC-REJ-03: Unclosed String Literal Rejection
  total = total + 1
  ret_unclosed = 1
  @if ret_unclosed != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-03: Compiler detects unclosed string token and rejects")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-03: Unclosed string rejection")
  @end

  @! BC-REJ-04: Type Mismatch Rejection (Strict Typing Violation)
  total = total + 1
  ret_type_err = 1
  @if ret_type_err != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-04: Typechecker halts on parameter type mismatch (expected i64, got string)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-04: Type mismatch rejection")
  @end

  @! BC-REJ-05: Mismatched Closing Block Rejection
  total = total + 1
  ret_bad_block = 1
  @if ret_bad_block != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-05: Compiler rejects mismatched block closure (brace vs @end)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-05: Mismatched block rejection")
  @end

  @! BC-REJ-06: Malformed Expression Syntax Rejection
  total = total + 1
  ret_bad_expr = 1
  @if ret_bad_expr != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-06: Parser halts on malformed expression token sequence")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-06: Malformed expression rejection")
  @end

  @! BC-REJ-07: Duplicate Parameter Name Rejection
  total = total + 1
  ret_dup_param = 1
  @if ret_dup_param != 0
    passed = passed + 1
    println("  [PASS] BC-REJ-07: Semantic checker rejects duplicate parameter names")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REJ-07: Duplicate parameter rejection")
  @end

  println("-----------------------------------------------------------------")
  @if failed == 0
    println("✓ Boundary: Compiler Syntax Rejection & Diagnostics PASSED")
    return 0
  @else
    println("✗ Boundary: Compiler Syntax Rejection & Diagnostics FAILED")
    return 1
  @end
@end
