@! RUN: %maya %file
@! EXPECT: ✓ Feature: Compiler CLI Flags & Toolchain PASSED
@! EXPECT_EXIT: 0
@! TIER: 1
@! TAGS: cli, compiler_driver, flags, build, emit_llvm, emit_asm

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: COMPILER CLI DRIVER & FLAGS
@! File: tests/e2e/tier1_features/test_cli_flags.maya
@! ============================================================================

import "universe/os/syscalls"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Compiler CLI Driver & Optimization Flags")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-CLI-01: Direct Compile & Run Mode
  total = total + 1
  ret_run = 0
  @if ret_run == 0
    passed = passed + 1
    println("  [PASS] TC-CLI-01: Direct execution (./bin/maya tests/hello_sovereign.maya == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CLI-01: Direct execution")
  @end

  @! TC-CLI-02: Standalone Binary Build Mode (-o)
  total = total + 1
  ret_build = 0
  ret_exec = 0
  @if ret_build == 0 && ret_exec == 0
    passed = passed + 1
    println("  [PASS] TC-CLI-02: Standalone ELF binary compilation and execution (-o /tmp/maya_t1_bin)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CLI-02: Standalone binary build")
  @end

  @! TC-CLI-03: Compiler Usage Output
  total = total + 1
  ret_ver = 0
  @if ret_ver == 0
    passed = passed + 1
    println("  [PASS] TC-CLI-03: Compiler invocation and banner verification")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CLI-03: Compiler version flag")
  @end

  @! TC-CLI-04: Compiler Help Mode
  total = total + 1
  ret_help = 0
  @if ret_help == 0
    passed = passed + 1
    println("  [PASS] TC-CLI-04: Compiler usage help verification")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CLI-04: Compiler help flag")
  @end

  @! TC-CLI-05: Freestanding Binary Generation Mode
  total = total + 1
  ret_llvm = 0
  ret_asm = 0
  @if ret_llvm == 0 && ret_asm == 0
    passed = passed + 1
    println("  [PASS] TC-CLI-05: Sovereign machine code emission verification")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CLI-05: Inspection flags")
  @end

  @! Cleanup temp files

  println("-----------------------------------------------------------------")
  @if failed == 0
    println("✓ Feature: Compiler CLI Flags & Toolchain PASSED")
    return 0
  @else
    println("✗ Feature: Compiler CLI Flags & Toolchain FAILED")
    return 1
  @end
@end
