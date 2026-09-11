@! ============================================================================
@! MAYA E2E TIER 1 — F03.1: Dispatcher Command Tokenizer
@! File: tests/e2e/tier1_features/os/test_f03_dispatcher_tokenize.maya
@! ============================================================================

import "universe/os/dispatcher"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F03.1: Dispatcher Tokenizer")

  tokens = dispatcher_tokenize("echo 'hello world' 123")
  assert_eq(tokens.len(), 3, "3 tokens parsed")
  assert_str_eq(tokens[0].val, "echo", "Token 0 is 'echo'")
  assert_str_eq(tokens[1].val, "hello world", "Token 1 preserves string")
  assert_str_eq(tokens[2].val, "123", "Token 2 is '123'")

  println("✓ PASS: F03.1 Dispatcher Tokenizer")
  return 0
@end
