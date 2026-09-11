@! ============================================================================
@! MAYA E2E TIER 1 MASTER RUNNER — COMPLETE FEATURE COVERAGE (F14 – F21)
@! File: tests/e2e/tier1_features/test_tier1_all.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"
import "universe/core/collections"

@struct MasterSuiteStatus
  total: i64
  passed: i64
  failed: i64
@end

@fn run_feature_test(suite: MasterSuiteStatus, name: string, file_path: string) -> MasterSuiteStatus
  suite.total = suite.total + 1
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1 MASTER] Executing: " + name + " (" + file_path + ")...")
  
  pid = sys_fork()
  @if pid == 0
    @! Child process executes the test via mayac_v2
    args = [file_path]
    process_execve("./bin/mayac_v2", args, 0)
    sys_exit(1)
  @end

  @if pid > 0
    st = process_wait(pid)
    @if process_wifexited(st) == 1
      ec = process_wexitstatus(st)
      @if ec == 0
        suite.passed = suite.passed + 1
        println("✓ [PASS] " + name)
      @else
        suite.failed = suite.failed + 1
        println("❌ [FAIL] " + name + " (Exit code: " + ec.to_str() + ")")
      @end
    @else
      suite.failed = suite.failed + 1
      sig = process_wtermsig(st)
      println("❌ [CRASH] " + name + " (Terminated by signal: " + sig.to_str() + ")")
    @end
  @else
    suite.failed = suite.failed + 1
    println("❌ [FORK_ERROR] " + name)
  @end

  return suite
@end

@fn main()
  println("=================================================================")
  println("🔱 MAYA E2E TIER 1 MASTER TEST RUNNER: ALL FEATURES 🔱")
  println("=================================================================")

  suite = { total: 0, passed: 0, failed: 0 }

  @! AI Neural Swarm Tier 1 Feature Suites (F14 - F19)
  suite = run_feature_test(suite, "Feature 14: N-D Tensor Engine", "tests/e2e/tier1_features/ai/test_f14_tensor.lp")
  suite = run_feature_test(suite, "Feature 15: Autograd Engine", "tests/e2e/tier1_features/ai/test_f15_autograd.lp")
  suite = run_feature_test(suite, "Feature 16: Neural Network Architecture", "tests/e2e/tier1_features/ai/test_f16_nn.lp")
  suite = run_feature_test(suite, "Feature 17: Transformer & LLM Engine", "tests/e2e/tier1_features/ai/test_f17_transformer.lp")
  suite = run_feature_test(suite, "Feature 18: Autonomous Multi-Agent Swarm", "tests/e2e/tier1_features/ai/test_f18_swarm.lp")
  suite = run_feature_test(suite, "Feature 19: Autonomous Task Routing", "tests/e2e/tier1_features/ai/test_f19_router.lp")

  @! Sovereign Infrastructure & Purity Suites (F20 - F21)
  suite = run_feature_test(suite, "Feature 20: Sovereign Test Framework", "tests/e2e/tier1_features/infra/test_f20_test_framework.lp")
  suite = run_feature_test(suite, "Feature 21: Zero Foreign Code Purity", "tests/e2e/tier1_features/infra/test_f21_purity.lp")

  println("=================================================================")
  println("📊 TIER 1 MASTER EXECUTION SUMMARY:")
  println("   Total Feature Suites : " + suite.total.to_str())
  println("   Passed               : " + suite.passed.to_str())
  println("   Failed               : " + suite.failed.to_str())
  println("=================================================================")

  @if suite.failed > 0
    println("❌ TIER 1 MASTER DETECTED FAILURES!")
    return 1
  @end

  println("🎉 ALL TIER 1 FEATURES (F14–F21) PASSED WITH 100% SOVEREIGN PURITY!")
  return 0
@end
