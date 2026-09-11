@! ============================================================================
@! MAYA E2E TIER 1 — F03.3: Dispatcher Pipeline Parser & Execution
@! File: tests/e2e/tier1_features/os/test_f03_dispatcher_pipe_redirection.maya
@! ============================================================================

import "universe/os/dispatcher"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F03.3: Dispatcher Pipeline Parser")

  tokens = dispatcher_tokenize("cat file.txt | grep sovereign")
  pipeline = dispatcher_parse_pipeline(tokens)
  stages = pipeline.stages
  assert_eq(stages.len(), 2, "2 pipeline stages parsed")
  assert_str_eq(stages[0].command, "cat", "Stage 0 is 'cat'")
  assert_str_eq(stages[1].command, "grep", "Stage 1 is 'grep'")

  println("✓ PASS: F03.3 Dispatcher Pipeline Parser")
  return 0
@end
