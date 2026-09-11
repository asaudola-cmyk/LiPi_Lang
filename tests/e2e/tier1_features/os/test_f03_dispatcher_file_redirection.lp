@! ============================================================================
@! MAYA E2E TIER 1 — F03.4: Dispatcher File Redirection Tokenization
@! File: tests/e2e/tier1_features/os/test_f03_dispatcher_file_redirection.maya
@! ============================================================================

import "universe/os/dispatcher"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F03.4: Dispatcher File Redirection")

  tokens = dispatcher_tokenize("mycmd < input.txt > output.txt")
  pipeline = dispatcher_parse_pipeline(tokens)
  stg = pipeline.stages[0]
  assert_eq(stg.redirections.len(), 2, "2 redirections parsed (< and >)")
  assert_eq(stg.redirections[0].redir_type, 1, "Redir 0 is REDIR_IN (1)")
  assert_eq(stg.redirections[1].redir_type, 2, "Redir 1 is REDIR_OUT (2)")

  println("✓ PASS: F03.4 Dispatcher File Redirection")
  return 0
@end
