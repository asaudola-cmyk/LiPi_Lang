@! ============================================================================
@! MAYA E2E TIER 1 RUNNER — AI NEURAL SWARM SUITE (F14 – F19)
@! File: tests/e2e/tier1_features/test_tier1_ai.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"
import "universe/core/collections"

@struct SuiteStatus
  total: i64
  passed: i64
  failed: i64
@end

@fn run_feature_test(suite: SuiteStatus, name: string, file_path: string) -> SuiteStatus
  suite.total = suite.total + 1
  println("-----------------------------------------------------------------")
  println("▶ [SUITE] Running " + name + " (" + file_path + ")...")
  
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
  println("🔱 MAYA E2E TIER 1: AI NEURAL SWARM TEST SUITE RUNNER 🔱")
  println("=================================================================")

  suite = { total: 0, passed: 0, failed: 0 }

  suite = run_feature_test(suite, "Feature 14: N-D Tensor Engine", "tests/e2e/tier1_features/ai/test_f14_tensor.lp")
  suite = run_feature_test(suite, "Feature 15: Autograd Engine", "tests/e2e/tier1_features/ai/test_f15_autograd.lp")
  suite = run_feature_test(suite, "Feature 16: Neural Network Architecture", "tests/e2e/tier1_features/ai/test_f16_nn.lp")
  suite = run_feature_test(suite, "Feature 17: Transformer & LLM Engine", "tests/e2e/tier1_features/ai/test_f17_transformer.lp")
  suite = run_feature_test(suite, "Feature 18: Autonomous Multi-Agent Swarm", "tests/e2e/tier1_features/ai/test_f18_swarm.lp")
  suite = run_feature_test(suite, "Feature 19: Autonomous Task Routing", "tests/e2e/tier1_features/ai/test_f19_router.lp")

  println("=================================================================")
  println("📊 TIER 1 AI SUITE EXECUTION SUMMARY:")
  println("   Total Feature Suites : " + suite.total.to_str())
  println("   Passed               : " + suite.passed.to_str())
  println("   Failed               : " + suite.failed.to_str())
  println("=================================================================")

  @if suite.failed > 0
    println("❌ TIER 1 AI SUITE DETECTED FAILURES!")
    return 1
  @end

  println("🎉 ALL TIER 1 AI NEURAL SWARM FEATURES PASSED CLEANLY!")
  return 0
@end
