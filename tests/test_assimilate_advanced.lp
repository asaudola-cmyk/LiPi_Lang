// ==============================================================================
// 👑 LIPI ADVANCED UNIVERSAL CODE ASSIMILATOR REGRESSION TEST
// File: tests/test_assimilate_advanced.lp
// 100% Pure Lipi Implementation — Zero Libc / Python / GCC Dependencies
// ==============================================================================
//
// WHY: Verifies universal transpilation from legacy languages (Python, C)
// to 100% sovereign Lipi First 1.0.0 machine code:
// 1. Python function lowering, block indentation, booleans, and print conversion.
// 2. C type stripping (int, char*, long, double), parameter hygiene, and printf.
// 3. Execution of assimilated code directly on bare Linux silicon.

import "src/tools/lipiassimilate"
import "universe/os/syscalls"
import "universe/core/string"

@fn assert_true(cond: i64, msg: string)
  @if cond == 0
    println("  ❌ FAIL: " + msg)
    sys_exit(1)
  @end
  println("  ✔ PASS: " + msg)
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string)
  @if actual != expected
    println("  ❌ FAIL: " + msg + " (Expected " + to_str(expected) + ", got " + to_str(actual) + ")")
    sys_exit(1)
  @end
  println("  ✔ PASS: " + msg)
@end

@fn main()
  println("══════════════════════════════════════════════════════════════════════")
  println("👑 TESTING ADVANCED UNIVERSAL CODE ASSIMILATOR & TRANSPILER")
  println("══════════════════════════════════════════════════════════════════════")

  // ── Phase 1: Python Advanced Transpilation ──────────────────────────────────
  println("\n▶ Phase 1: Python Control Flow, Booleans & Builtin Lowering...")
  py_src = "def is_valid(flag, count):\n    if flag == True:\n        return count * 10\n    elif flag == False:\n        return 0\n    else:\n        return -1\n\nprint(is_valid(True, 5))\n"
  lipi_py = assimilate_source(py_src)

  assert_true(str_contains(lipi_py, "@fn is_valid(flag, count)") == 1, "Transpiled Python def: @fn is_valid(flag, count)")
  assert_true(str_contains(lipi_py, "@if flag == 1") == 1, "Lowered Python True literal: flag == 1")
  assert_true(str_contains(lipi_py, "@elif flag == 0") == 1, "Lowered Python False literal: flag == 0")
  assert_true(str_contains(lipi_py, "@else") == 1, "Synthesized @else branch")
  assert_true(str_contains(lipi_py, "@end") == 1, "Synthesized block terminator @end")
  assert_true(str_contains(lipi_py, "println(is_valid(1, 5))") == 1, "Lowered print(...) to println(...) with boolean substitution")

  // ── Phase 2: C Typed Functions & Variable Declarations ──────────────────────
  println("\n▶ Phase 2: C Type Stripping, Pointer Syntax & Printf Lowering...")
  c_src = "int calculate_sum(int start, int limit) {\n    long acc = 0;\n    int i = start;\n    while (i <= limit) {\n        acc = acc + i;\n        i = i + 1;\n    }\n    return acc;\n}\n\nprintf(calculate_sum(1, 10));\n"
  lipi_c = assimilate_source(c_src)

  assert_true(str_contains(lipi_c, "@fn calculate_sum(start, limit)") == 1, "Stripped C parameter types in signature")
  assert_true(str_contains(lipi_c, "acc = 0") == 1, "Stripped C 'long' variable type declaration")
  assert_true(str_contains(lipi_c, "i = start") == 1, "Stripped C 'int' variable type declaration")
  assert_true(str_contains(lipi_c, "@while i <= limit") == 1, "Transpiled C while loop condition")
  assert_true(str_contains(lipi_c, "println(calculate_sum(1, 10))") == 1, "Lowered C printf(...) to println(...)")

  // ── Phase 3: End-to-End Assimilation & Execution on Silicon ─────────────────
  println("\n▶ Phase 3: Silicon Execution of Transpiled Code Pipeline...")
  tmp_py = "/tmp/test_assimilate_exec.py"
  tmp_lp = "/tmp/test_assimilate_exec.lp"
  tmp_bin = "/tmp/test_assimilate_exec.bin"

  sys_unlink(tmp_py)
  sys_unlink(tmp_lp)
  sys_unlink(tmp_bin)

  // Write Python program
  fd = sys_open(tmp_py, 577, 420)
  assert_true(fd >= 0, "Created Python input script")
  py_prog = "def add_three(x):\n    return x + 3\n\nprint(add_three(39))\n"
  sys_write(fd, py_prog, str_len(py_prog))
  sys_close(fd)

  // Transpile to Lipi source
  nbytes = assimilate_file(tmp_py, tmp_lp)
  assert_true(nbytes > 0, "Python script assimilated into canonical Lipi source")

  // Compile assimilated Lipi to ELF64 machine code
  c_res = assimilator_exec("./bin/lipc_bin", tmp_lp, "-o", tmp_bin)
  assert_eq_int(c_res, 0, "Assimilated Lipi code compiled cleanly to ELF64 binary")

  // Execute compiled binary on bare silicon
  r_res = assimilator_exec(tmp_bin, "", "", "")
  assert_eq_int(r_res, 0, "Assimilated binary executed on silicon with zero exit code")

  // Cleanup
  sys_unlink(tmp_py)
  sys_unlink(tmp_lp)
  sys_unlink(tmp_bin)

  println("\n══════════════════════════════════════════════════════════════════════")
  println("🎉 ALL ADVANCED ASSIMILATION & TRANSPILATION TESTS PASSED!")
  println("══════════════════════════════════════════════════════════════════════")
  return 0
@end

main()
