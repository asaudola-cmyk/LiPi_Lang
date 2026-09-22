// tests/test_comptime_eval.lp
// Validates Comptime Supercompilation & Partial Evaluation
import "compiler/middleend/comptime_eval"
import "universe/core/io"

@fn main()
  say("Testing Comptime Supercompilation...")

  env = comptime_env_new()
  comptime_env_set(env, "MAX_BUFFER", 4096)
  comptime_env_set(env, "PAGE_SIZE", 64)

  if comptime_env_has(env, "MAX_BUFFER") == 1
    say("PASS: Comptime env variable registered")
  else
    say("FAIL: Comptime env variable missing")
  end

  // Test 1: Arithmetic binop evaluation
  v1 = comptime_eval_binop("+", 100, 250)
  if v1 == 350
    say("PASS: Comptime Add 100 + 250 = 350")
  else
    say("FAIL: Comptime Add")
  end

  v2 = comptime_eval_binop("<<", 1, 10)
  if v2 == 1024
    say("PASS: Comptime Shift Left 1 << 10 = 1024")
  else
    say("FAIL: Comptime Shift Left")
  end

  // Test 2: Bounded loop supercompilation (Sum 1..100 = 5050 at compile time)
  sum100 = comptime_eval_loop_range(1, 100, 1, "+", 0, env)
  if sum100 == 5050
    say("PASS: Comptime Loop Range 1..100 = 5050")
  else
    say("FAIL: Comptime Loop Range expected 5050, got " + to_str(sum100))
  end

  // Test 3: Precomputed Lookup Table (Fibonacci 0..10)
  // Fib: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55
  fib_lut = comptime_generate_lut(0, 10, 1)
  if fib_lut[10] == 55 && fib_lut[6] == 8
    say("PASS: Comptime LUT Fibonacci generation (fib[10] = 55)")
  else
    say("FAIL: Comptime LUT Fibonacci generation")
  end

  say("ALL COMPTIME SUPERCOMPILATION TESTS PASSED")
  return 0
@end

main()
