// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Hash Maps & Dictionaries PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: maps, dictionaries, hash_table, key_value, collections

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: HASH MAPS & KEY-VALUE STORAGE
@! File: tests/e2e/tier1_features/test_maps.maya
@! ============================================================================

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Hash Maps & Key-Value Storage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-MAP-01: Map Creation & Key-Value Insertion
  total = total + 1
  m = map_new()
  map_set(m, "alpha", 100)
  map_set(m, "beta", 200)
  v_a = map_get(m, "alpha")
  v_b = map_get(m, "beta")
  @if v_a == 100 && v_b == 200
    passed = passed + 1
    println("  [PASS] TC-MAP-01: map_new, map_set, map_get (\"alpha\": 100, \"beta\": 200)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MAP-01: map_get key retrieval")
  @end

  @! TC-MAP-02: Key Value Overwrite
  total = total + 1
  map_set(m, "alpha", 999)
  v_a2 = map_get(m, "alpha")
  @if v_a2 == 999
    passed = passed + 1
    println("  [PASS] TC-MAP-02: Key value overwrite (map_get(\"alpha\") == 999)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MAP-02: Key value overwrite")
  @end

  @! TC-MAP-03: Membership Check (map_has)
  total = total + 1
  has_beta = map_has(m, "beta")
  has_gamma = map_has(m, "gamma")
  @if has_beta == 1 && has_gamma == 0
    passed = passed + 1
    println("  [PASS] TC-MAP-03: map_has check (beta == 1, gamma == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MAP-03: map_has membership check")
  @end

  @! TC-MAP-04: Element Deletion & Map Size
  total = total + 1
  sz_before = map_size(m)
  map_delete(m, "beta")
  sz_after = map_size(m)
  has_beta_after = map_has(m, "beta")
  @if sz_before == 2 && sz_after == 1 && has_beta_after == 0
    passed = passed + 1
    println("  [PASS] TC-MAP-04: map_delete and map_size (size 2 -> 1)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MAP-04: map_delete and map_size")
  @end

  @! TC-MAP-05: Map Keys Enumeration
  total = total + 1
  map_set(m, "k1", 10)
  map_set(m, "k2", 20)
  map_set(m, "k3", 30)
  keys = map_keys(m)
  k_len = keys.len()
  @! map had alpha, plus k1, k2, k3 -> total 4 keys
  @if k_len == 4
    passed = passed + 1
    println("  [PASS] TC-MAP-05: map_keys returns all 4 active keys")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MAP-05: map_keys")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Hash Maps & Dictionaries PASSED")
    return 0
  @else
    println("✗ Feature: Hash Maps & Dictionaries FAILED")
    return 1
  @end
@end
