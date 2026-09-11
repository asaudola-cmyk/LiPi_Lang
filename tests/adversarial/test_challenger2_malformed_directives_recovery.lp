@! ============================================================================
@! CHALLENGER 2 ADVERSARIAL TEST SUITE: MALFORMED DIRECTIVE ERROR RECOVERY
@! File: tests/adversarial/test_challenger2_malformed_directives_recovery.maya
@! Architecture: Pure Maya Token Boundary & Lexical Directive Recovery
@! ============================================================================

@! 1. Directives with whitespace and newline separations
@infinity_rule
  "si_alt"
  =>
  "@if"
;

@! 2. Directive with duplicate / chained rules
@infinity_rule "fin_alt" => "@end" ;
@infinity_rule "fin_alt" => "@end" ;

@! 3. Directive with immediate valid code
@infinity_rule "mientras_alt" => "@while" ;

@fn test_malformed_recovery()
  count = 0
  mientras_alt count < 5
    count = count + 1
  fin_alt
  return count
@end

@fn main()
  println("=================================================================")
  println("  CHALLENGER 2: MALFORMED DIRECTIVE RECOVERY TEST SUITE")
  println("=================================================================")

  passed = 0
  total = 0

  total = total + 1
  res = test_malformed_recovery()
  @if res == 5
    println("  [PASS] C2.MAL.1: Compiler recovered from multi-line & duplicate directives cleanly")
    passed = passed + 1
  @else
    println("  [FAIL] C2.MAL.1: Directive error recovery failed")
  @end

  println("-----------------------------------------------------------------")
  println("  Summary: " + passed.to_str() + "/" + total.to_str() + " assertions passed.")

  @if passed == total && total > 0
    println("🏆 VERDICT: ALL MALFORMED DIRECTIVE RECOVERY TESTS PASSED!")
    return 0
  @else
    println("💥 VERDICT: SOME MALFORMED DIRECTIVE RECOVERY TESTS FAILED!")
    return 1
  @end
@end
