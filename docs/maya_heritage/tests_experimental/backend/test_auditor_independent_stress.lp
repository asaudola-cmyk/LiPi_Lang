@! ============================================================================
@! INDEPENDENT AUDITOR ADVERSARIAL STRESS SUITE (auditor_final_2)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/compiler"
import "compiler/backend/maya_ir"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/elf_writer"

@struct AuditState
  passed: 0
  failed: 0
  total: 0
@end

@fn assert_eq(st, actual, expected, msg)
  st.total = st.total + 1
  @if actual == expected
    st.passed = st.passed + 1
    println("  [AUDIT-PASS] " + msg)
  @else
    st.failed = st.failed + 1
    println("  [AUDIT-FAIL] " + msg + " (expected: " + expected.to_str() + ", got: " + actual.to_str() + ")")
  @end
  return st
@end

@fn main()
  st = { passed: 0, failed: 0, total: 0 }
  println("=================================================================")
  println("🔬 FORENSIC AUDITOR INDEPENDENT ADVERSARIAL COMPILER TESTS 🔬")
  println("=================================================================")

  @! Test 1: Complex 10-argument function + Deep Ackermann + Nested Loops
  src_stress = "@fn ack(m, n)\n  @if m == 0 return n + 1 @end\n  @if m == 1 return n + 2 @end\n  @if m == 2 return 2 * n + 3 @end\n  @if n == 0 return ack(m - 1, 1) @end\n  return ack(m - 1, ack(m, n - 1))\n@end\n\n@fn pass_ten_args(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)\n  res = a1 + a2 * 2 + a3 * 3 + a4 * 4 + a5 * 5 + a6 * 6 + a7 * 7 + a8 * 8 + a9 * 9 + a10 * 10\n  return res\n@end\n\n@fn nested_loops_break_continue(limit)\n  sum = 0\n  i = 0\n  @while i < limit\n    i = i + 1\n    @if (i % 2) == 0 continue @end\n    j = 0\n    @while j < 10\n      j = j + 1\n      @if j > 5 break @end\n      sum = sum + i * j\n    @end\n  @end\n  return sum\n@end\n\n@fn main()\n  a_val = ack(3, 2)\n  @if a_val != 29 return 1 @end\n  ten_res = pass_ten_args(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)\n  @if ten_res != 385 return 2 @end\n  nl_res = nested_loops_break_continue(10)\n  @if nl_res != 375 return 3 @end\n  return 42\n@end\n"

  bin_stress = "/tmp/maya_audit_stress_1.elf"
  comp_res1 = compile_source_to_elf(src_stress, bin_stress)
  st = assert_eq(st, comp_res1, 1, "Stress Test 1 (10-args, Ackermann, Break/Continue) compiled successfully")

  @! Test 2: Native Stdout emission using builtin maya_print and println
  src_print = "@fn main()\n  println(\"AUDITOR_NATIVE_PRINT_VERIFIED\")\n  println(123456789)\n  println(-987654321)\n  return 77\n@end\n"

  bin_print = "/tmp/maya_audit_print_2.elf"
  comp_res2 = compile_source_to_elf(src_print, bin_print)
  st = assert_eq(st, comp_res2, 1, "Stress Test 2 (Builtin Println Strings and Ints) compiled successfully")

  @! Test 3: Complex variable mutations and memory reassignments
  src_mem = "@fn mutate_vars()\n  a = 10\n  b = 20\n  c = a + b\n  a = 100\n  b = 200\n  d = a + b + c\n  return d\n@end\n\n@fn main()\n  res = mutate_vars()\n  @if res != 330 return 1 @end\n  return 88\n@end\n"

  bin_mem = "/tmp/maya_audit_mem_3.elf"
  comp_res3 = compile_source_to_elf(src_mem, bin_mem)
  st = assert_eq(st, comp_res3, 1, "Stress Test 3 (Variable Mutations and Reassignments) compiled successfully")

  println("=================================================================")
  println("📊 AUDITOR TEST SUMMARY:")
  println("   Total:  " + st.total.to_str())
  println("   Passed: " + st.passed.to_str())
  println("   Failed: " + st.failed.to_str())
  println("=================================================================")
  @if st.failed > 0 return 1 @end
  return 0
@end
