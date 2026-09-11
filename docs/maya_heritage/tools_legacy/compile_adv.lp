import "compiler/backend/compiler"

@fn main()
  println("▶ Compiling tests/test_infinity_syntax.maya...")
  r0 = compile_file_to_elf("tests/test_infinity_syntax.lp", "bin/test_infinity_syntax")
  println("  Result: " + r0.to_str())

  println("▶ Compiling tests/adversarial/test_adv_simultaneous_rules.maya...")
  r1 = compile_file_to_elf("tests/adversarial/test_adv_simultaneous_rules.lp", "bin/test_adv_simultaneous_rules")
  println("  Result: " + r1.to_str())

  println("▶ Compiling tests/adversarial/test_adv_custom_operators.maya...")
  r2 = compile_file_to_elf("tests/adversarial/test_adv_custom_operators.lp", "bin/test_adv_custom_operators")
  println("  Result: " + r2.to_str())

  println("▶ Compiling tests/adversarial/test_adv_large_workload.maya...")
  r3 = compile_file_to_elf("tests/adversarial/test_adv_large_workload.lp", "bin/test_adv_large_workload")
  println("  Result: " + r3.to_str())

  println("▶ Compiling tests/adversarial/test_adv_recursive_depth.maya...")
  r4 = compile_file_to_elf("tests/adversarial/test_adv_recursive_depth.lp", "bin/test_adv_recursive_depth")
  println("  Result: " + r4.to_str())

  println("▶ Compiling tests/adversarial/test_adv_malformed_directives.maya...")
  r5 = compile_file_to_elf("tests/adversarial/test_adv_malformed_directives.lp", "bin/test_adv_malformed_directives")
  println("  Result: " + r5.to_str())

  println("▶ Compiling tests/adversarial/test_adv_inf_syntax_eval.maya...")
  r6 = compile_file_to_elf("tests/adversarial/test_adv_inf_syntax_eval.lp", "bin/test_adv_inf_syntax_eval")
  println("  Result: " + r6.to_str())

  println("▶ Compiling tests/compiler/test_infinity_syntax.maya...")
  r7 = compile_file_to_elf("tests/compiler/test_infinity_syntax.lp", "bin/test_compiler_infinity")
  println("  Result: " + r7.to_str())

  return 0
@end
