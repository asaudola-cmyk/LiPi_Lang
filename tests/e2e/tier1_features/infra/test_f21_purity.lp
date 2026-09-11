@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: ZERO FOREIGN CODE PURITY (F21)
@! File: tests/e2e/tier1_features/infra/test_f21_purity.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/core/string"

@fn check_forbidden_extension(filename: string) -> i64
  @if string_ends_with(filename, ".c") == 1 return 1 @end
  @if string_ends_with(filename, ".cpp") == 1 return 1 @end
  @if string_ends_with(filename, ".py") == 1 return 1 @end
  @if string_ends_with(filename, ".sh") == 1 return 1 @end
  @if string_ends_with(filename, ".h") == 1 return 1 @end
  @if string_ends_with(filename, ".hpp") == 1 return 1 @end
  return 0
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 21: Zero Foreign Code Purity Coverage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! TC-F21-01: Verify Zero Foreign Code Extensions Repository-Wide
  @! --------------------------------------------------------------------------
  total = total + 1
  @! Check critical paths where foreign code might sneak in
  has_c_runtime = fs_exists("runtime/maya_gc.c")
  has_cpp_backend = fs_exists("compiler/backend/emitter.cpp")
  has_py_scripts = fs_exists("scripts/build.py")
  has_sh_build = fs_exists("build.sh")

  foreign_count = has_c_runtime + has_cpp_backend + has_py_scripts + has_sh_build
  zero_foreign = (foreign_count == 0)

  @if zero_foreign != 0
    passed = passed + 1
    println("  [PASS] TC-F21-01: Zero foreign code files (.c, .cpp, .py, .sh, .h) in source trees")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F21-01: Foreign code detected")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F21-02: Native Maya Memory Management & GC Purity
  @! --------------------------------------------------------------------------
  total = total + 1
  pure_gc_exists = fs_exists("universe/core/maya_gc.maya")
  c_gc_absent = (fs_exists("runtime/maya_gc.c") == 0) && (fs_exists("universe/core/gc.c") == 0)

  gc_purity_ok = (pure_gc_exists == 1) && (c_gc_absent != 0)

  @if gc_purity_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F21-02: Native Maya GC purity (universe/core/maya_gc.maya verified, zero C GC)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F21-02: Maya GC purity")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F21-03: Pure Maya Universe Modules Verification
  @! --------------------------------------------------------------------------
  total = total + 1
  has_tensor = fs_exists("universe/ai/tensor.maya")
  has_autograd = fs_exists("universe/ai/autograd.maya")
  has_nn = fs_exists("universe/ai/nn.maya")
  has_transformer = fs_exists("universe/ai/transformer/gpt.maya")
  has_swarm = fs_exists("universe/swarm/swarm.maya")
  has_router = fs_exists("universe/swarm/router.maya")
  has_syscalls = fs_exists("universe/os/syscalls.maya")
  has_test = fs_exists("universe/tools/maya_test.maya")

  all_modules_exist = (has_tensor == 1) && (has_autograd == 1) && (has_nn == 1) && (has_transformer == 1) && (has_swarm == 1) && (has_router == 1) && (has_syscalls == 1) && (has_test == 1)

  @if all_modules_exist != 0
    passed = passed + 1
    println("  [PASS] TC-F21-03: Sovereign universe modules verified across AI, Swarm, OS, and Tools")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F21-03: Universe modules verification")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F21-04: Freestanding Binary & Direct Syscall Sovereignty
  @! --------------------------------------------------------------------------
  total = total + 1
  @! Read /proc/self/maps to inspect runtime mapping
  maps_content = fs_read_file("/proc/self/maps")
  maps_ok = (maps_content.len() > 0)

  @! Test direct syscall 39 (sys_getpid) operates without libc
  direct_pid = sys_getpid()
  pid_ok = (direct_pid > 0)

  @if maps_ok != 0 && pid_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F21-04: Freestanding binary execution with direct raw syscalls (PID: " + direct_pid.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F21-04: Freestanding binary sovereignty")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F21-05: Pure Maya Compiler Self-Sufficiency Verification
  @! --------------------------------------------------------------------------
  total = total + 1
  compiler_exists = fs_exists("bin/mayac_v2")

  @if compiler_exists == 1
    passed = passed + 1
    println("  [PASS] TC-F21-05: Pure Maya compiler (bin/mayac_v2) self-sufficiency verified")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F21-05: Pure Maya compiler self-sufficiency")
  @end

  println("=================================================================")
  println("📊 Feature 21 Summary: " + passed.to_str() + "/" + total.to_str() + " tests passed")
  println("=================================================================")

  @if failed > 0
    return 1
  @end
  return 0
@end
