@! ============================================================================
@! MAYA E2E TIER 1 — F20: Test Assert Primitives
@! File: tests/e2e/tier1_features/infra/test_f20_test_assert_primitives.maya
@! ============================================================================

import "universe/tools/maya_test"

@fn main()
  assert_true(1 == 1, "true check")
  assert_false(0 == 1, "false check")
  assert_eq(100, 100, "eq check")
  assert_ne(100, 200, "ne check")
  assert_str_eq("maya", "maya", "str_eq check")
  assert_near(50, 52, 5, "near check")
  assert_ge(10, 5, "ge check")
  assert_gt(10, 9, "gt check")
  assert_le(5, 10, "le check")
  assert_lt(4, 5, "lt check")
  assert_str_contains("maya test framework", "test", "contains check")
  println("✓ PASS: test_f20_test_assert_primitives")
  return 0
@end
