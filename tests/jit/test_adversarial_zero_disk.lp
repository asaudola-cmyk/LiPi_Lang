import "compiler/backend/jit/mod"

@fn main()
  println(">>> START JIT ZERO DISK ADVERSARIAL TEST <<<")
  engine = jit_engine_new()

  @! Complex math expression
  res1 = jit_eval_expression(engine, "1000 * 20 + (500 / 5) - 300 & 255 + (1 * 256)")
  println("Result 1: " + res1.value.to_str())

  @! Recursive function compilation in RAM
  fact_src = "@fn fact(n: i64) -> i64\n  @if n <= 1 return 1 @end\n  return n * fact(n - 1)\n@end"
  jit_compile_function(engine, "fact", fact_src)

  res2 = jit_eval_expression(engine, "fact(7)")
  println("Result 2 (fact 7): " + res2.value.to_str())

  @! Persistent variables
  jit_env_set_var(engine, "alpha", 12345, 0, "")
  jit_env_set_var(engine, "beta", 67890, 0, "")
  res3 = jit_eval_expression(engine, "alpha + beta * 2")
  println("Result 3 (alpha + beta*2): " + res3.value.to_str())

  jit_engine_free(engine)
  println(">>> END JIT ZERO DISK ADVERSARIAL TEST <<<")
  return 0
@end
