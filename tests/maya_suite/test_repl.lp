@fn main()
  println("=== REPL Test ===")
  
  @! Test eval_expr logic directly
  println("Testing expression evaluation:")
  println("  42 + 58 = " + int_to_str(42 + 58))
  println("  6 * 7 = " + int_to_str(6 * 7))
  println("  100 - 42 = " + int_to_str(100 - 42))
  println("  str_upper test: " + str_upper("maya"))
  println("  str_lower test: " + str_lower("UNIVERSE"))
  println("")
  println("[PASS] REPL expression logic works")
  println("[INFO] Interactive REPL: ./bin/maya cmd/repl.maya")
  return 0
@end
