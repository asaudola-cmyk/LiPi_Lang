@! ============================================================================
@! LIPI TEST SUITE: UNIVERSAL CODE ASSIMILATOR & TRANSPILER VERIFICATION
@! File: tests/test_assimilate.lp
@! Standard: Python & C to Canonical Lipi 2.0 AST / Source Lowering
@! 100% Pure Lipi Implementation — Zero External Libc / Python Dependencies
@! ============================================================================

import "src/tools/lipiassimilate"
import "universe/os/syscalls"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("👑 LIPI UNIVERSAL CODE ASSIMILATOR TEST SUITE 👑")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: Python Recursive Fibonacci Transpilation
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Python Fibonacci Function Assimilation...")
  total_tests = total_tests + 1

  py_fib = "def fib(n):\n    if n <= 1:\n        return n\n    return fib(n - 1) + fib(n - 2)\n"
  lipi_fib = assimilate_source(py_fib)

  ok_f1 = assert_true(str_contains(lipi_fib, "@fn fib(n)") == 1, "Transpiled function header: @fn fib(n)")
  ok_f2 = assert_true(str_contains(lipi_fib, "@if n <= 1") == 1, "Transpiled branch condition: @if n <= 1")
  ok_f3 = assert_true(str_contains(lipi_fib, "return n") == 1, "Transpiled base case return")
  ok_f4 = assert_true(str_contains(lipi_fib, "return fib(n - 1) + fib(n - 2)") == 1, "Transpiled recursive return")
  ok_f5 = assert_true(str_contains(lipi_fib, "@end") == 1, "Emitted block terminator: @end")

  all_s1 = ok_f1 && ok_f2 && ok_f3 && ok_f4 && ok_f5
  @if all_s1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Python recursive function successfully assimilated.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: Python Collatz Loop & Branch Assimilation
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Python Nested While/If/Else Loop Assimilation...")
  total_tests = total_tests + 1

  py_collatz = "def collatz(n):\n    curr = n\n    while curr > 1:\n        if curr % 2 == 0:\n            curr = curr / 2\n        else:\n            curr = curr * 3 + 1\n    return curr\n"
  lipi_collatz = assimilate_source(py_collatz)

  ok_c1 = assert_true(str_contains(lipi_collatz, "@fn collatz(n)") == 1, "Transpiled function header: @fn collatz(n)")
  ok_c2 = assert_true(str_contains(lipi_collatz, "@while curr > 1") == 1, "Transpiled loop: @while curr > 1")
  ok_c3 = assert_true(str_contains(lipi_collatz, "@if curr % 2 == 0") == 1, "Transpiled even branch: @if curr % 2 == 0")
  ok_c4 = assert_true(str_contains(lipi_collatz, "@else") == 1, "Transpiled odd branch: @else")

  all_s2 = ok_c1 && ok_c2 && ok_c3 && ok_c4
  @if all_s2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Python while loop and if/else branch successfully assimilated.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: C-Style GCD Function & Type Stripping
  @! --------------------------------------------------------------------------
  println("▶ Section 3: C-Style Function & Type Stripping Assimilation...")
  total_tests = total_tests + 1

  c_gcd = "int gcd(int a, int b) {\n    while (b != 0) {\n        int t = b;\n        b = a % b;\n        a = t;\n    }\n    return a;\n}\n"
  lipi_gcd = assimilate_source(c_gcd)

  ok_g1 = assert_true(str_contains(lipi_gcd, "@fn gcd(a, b)") == 1, "C signature stripped types: @fn gcd(a, b)")
  ok_g2 = assert_true(str_contains(lipi_gcd, "@while b != 0") == 1, "C while condition converted: @while b != 0")
  ok_g3 = assert_true(str_contains(lipi_gcd, "b = a % b") == 1, "C modulo arithmetic preserved")
  ok_g4 = assert_true(str_contains(lipi_gcd, "return a") == 1, "C return statement preserved")

  all_s3 = ok_g1 && ok_g2 && ok_g3 && ok_g4
  @if all_s3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] C-style function and block braces successfully assimilated.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: End-to-End File Assimilation & Syscall I/O
  @! --------------------------------------------------------------------------
  println("▶ Section 4: End-to-End File Assimilation via Direct Syscalls...")
  total_tests = total_tests + 1

  test_py_file = "/tmp/lipi_test_input.py"
  test_lp_file = "/tmp/lipi_test_output.lp"
  sys_unlink(test_py_file)
  sys_unlink(test_lp_file)

  @! Write sample input file
  fd = sys_open(test_py_file, 577, 420)
  ok_fd = assert_true(fd >= 0, "Created temporary Python test file")
  sys_write(fd, "def square(x):\n    return x * x\n", 33)
  sys_close(fd)

  nbytes = assimilate_file(test_py_file, test_lp_file)
  ok_nb = assert_true(nbytes > 0, "Assimilate file emitted > 0 bytes")

  fd_read = sys_open(test_lp_file, 0, 0)
  ok_fdr = assert_true(fd_read >= 0, "Successfully opened generated .lp file")
  sys_close(fd_read)

  sys_unlink(test_py_file)
  sys_unlink(test_lp_file)

  all_s4 = ok_fd && ok_nb && ok_fdr
  @if all_s4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] End-to-end file assimilation pipeline verified.")
  @end

  println("=================================================================")
  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  println(str_concat("📊 ASSIMILATOR TEST RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed")))))
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL CODE ASSIMILATION & TRANSPILER TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TESTS FAILED")
    return 1
  @end
@end
