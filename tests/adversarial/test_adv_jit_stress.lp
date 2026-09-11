import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/jit/mod"

@fn assert_eq(actual: i64, expected: i64, test_name: string)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got " + actual.to_str())
  @else
    println("  [FAIL] " + test_name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    sys_exit(1)
  @end
@end

@fn assert_true(cond: bool, test_name: string)
  @if cond == true
    println("  [PASS] " + test_name)
  @else
    println("  [FAIL] " + test_name)
    sys_exit(1)
  @end
@end

@fn main()
  println("=================================================================")
  println("⚡ ADVERSARIAL JIT STRESS & COMPILATION TEST HARNESS ⚡")
  println("=================================================================")

  engine = jit_engine_new()
  assert_true(engine != 0, "ADV-JIT-01: Engine allocation")

  @! ---------------------------------------------------------------------------
  @! SECTION 1: Deep Nested Arithmetic & Operator Precedence Stress
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 1: Complex Arithmetic & Precedence...")
  
  @! Test 1: Complex precedence: (10 + 20 * 30 - 40 / 5) * 2 + 100
  res1 = jit_eval_expression(engine, "(10 + 20 * 30 - 40 / 5) * 2 + 100")
  assert_eq(res1.success, 1, "ADV-JIT-02: Expression 1 compiled")
  assert_eq(res1.value, 1304, "ADV-JIT-03: Expression 1 evaluated")

  @! Test 2: Bitwise manipulation: ((pow2(10)) | 512) ^ (pow2(9))
  res2 = jit_eval_expression(engine, "((pow2(10)) | 512) ^ (pow2(9))")
  assert_eq(res2.success, 1, "ADV-JIT-04: Bitwise expression compiled")
  assert_eq(res2.value, 1024, "ADV-JIT-05: Bitwise expression evaluated")

  @! Test 3: Deeply parenthesized expression
  res3 = jit_eval_expression(engine, "((((((1 + 2) + 3) + 4) + 5) + 6) + 7)")
  assert_eq(res3.success, 1, "ADV-JIT-06: Deeply parenthesized compiled")
  assert_eq(res3.value, 28, "ADV-JIT-07: Deeply parenthesized evaluated")

  @! ---------------------------------------------------------------------------
  @! SECTION 2: Multi-Argument Functions & Loops in JIT
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 2: JIT Multi-Argument Function Invocation & Iteration...")

  @! 4-argument arithmetic combiner function
  poly4_src = "@fn poly4(a, b, c, d)\n  return a * 1000 + b * 100 + c * 10 + d\n@end\n"
  c_res1 = jit_compile_source(engine, poly4_src)
  assert_eq(c_res1.success, 1, "ADV-JIT-08: poly4 compiled")

  fn_ptr = jit_lookup_symbol(engine, "poly4")
  assert_true(fn_ptr != 0, "ADV-JIT-09: poly4 symbol lookup")

  res_poly = jit_invoke_fn4(fn_ptr, 7, 8, 9, 5)
  assert_eq(res_poly, 7895, "ADV-JIT-10: poly4(7, 8, 9, 5) == 7895")

  @! Iterative loop function: sum of 1..N
  sum_src = "@fn sum_n(n)\n  total = 0\n  i = 1\n  @while i <= n\n    total = total + i\n    i = i + 1\n  @end\n  return total\n@end\n"
  c_res2 = jit_compile_source(engine, sum_src)
  assert_eq(c_res2.success, 1, "ADV-JIT-11: sum_n compiled")

  fn_sum = jit_lookup_symbol(engine, "sum_n")
  res_sum = jit_invoke_fn1(fn_sum, 100)
  assert_eq(res_sum, 5050, "ADV-JIT-12: sum_n(100) == 5050 (Gauss sum)")

  @! Recursive Collatz function in RAM
  collatz_src = "@fn collatz_jit(n, steps)\n  @if n <= 1 return steps @end\n  @if n % 2 == 0 return collatz_jit(n / 2, steps + 1) @end\n  return collatz_jit(n * 3 + 1, steps + 1)\n@end\n"
  c_res3 = jit_compile_source(engine, collatz_src)
  assert_eq(c_res3.success, 1, "ADV-JIT-13: collatz_jit compiled")

  fn_collatz = jit_lookup_symbol(engine, "collatz_jit")
  res_collatz = jit_invoke_fn2(fn_collatz, 27, 0)
  assert_eq(res_collatz, 111, "ADV-JIT-14: collatz_jit(27, 0) == 111 steps")

  @! ---------------------------------------------------------------------------
  @! SECTION 3: JIT RAM Memory Stress & Allocation Cycling
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 3: JIT Memory Stress Allocation Cycling (50 blocks)...")
  
  alloc_count = 50
  k = 0
  @while k < alloc_count
    blk = jit_mem_alloc(4096)
    @if blk.addr == 0
      println("  [FAIL] Failed to allocate block " + k.to_str())
      sys_exit(1)
    @end

    @! Write simple x86-64 return 42: mov eax, 42; ret -> B8 2A 00 00 00 C3
    code_bytes = [184, 42, 0, 0, 0, 195]
    jit_mem_write_bytes(blk, 0, code_bytes)
    jit_mem_protect_rx(blk)

    val = jit_invoke_fn0(blk.addr)
    @if val != 42
      println("  [FAIL] Block " + k.to_str() + " returned " + val.to_str() + " expected 42")
      sys_exit(1)
    @end

    jit_mem_free(blk)
    k = k + 1
  @end
  println("  [PASS] ADV-JIT-15: Successfully cycled 50 JIT memory blocks via mmap/munmap")

  @! ---------------------------------------------------------------------------
  @! SECTION 4: Persistent Environment State & Variables
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 4: Persistent Environment Variables...")

  jit_env_set_var(engine, "base_cost", 500, 0, "")
  jit_env_set_var(engine, "tax_rate", 15, 0, "")
  jit_env_set_var(engine, "discount", 50, 0, "")

  res_env = jit_eval_expression(engine, "base_cost + (base_cost * tax_rate / 100) - discount")
  assert_eq(res_env.success, 1, "ADV-JIT-16: Env expression compiled")
  @! 500 + 75 - 50 = 525
  assert_eq(res_env.value, 525, "ADV-JIT-17: Env expression evaluated (525)")

  jit_engine_free(engine)
  println("  [PASS] ADV-JIT-18: JIT Engine cleanly deallocated")

  println("\n=================================================================")
  println("🎉 ALL 18 ADVERSARIAL JIT STRESS TESTS PASSED SUCCESSFULLY! 🎉")
  println("=================================================================")
  return 0
@end
