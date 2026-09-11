// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Persistent Key-Value Storage PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: mobile, storage, kv, persistence, crud, database

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: PERSISTENT KEY-VALUE STORAGE
@! File: tests/mobile/test_persistent_storage.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/mobile/storage"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Persistent Key-Value Storage CRUD Engine")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  test_file = "test_tier1_store.kv"
  storage_clear_at(test_file)

  @! ----------------------------------------------------------------------------
  @! TC-STO-01: Key-Value Set & Get
  @! ----------------------------------------------------------------------------
  total = total + 1
  storage_set_at(test_file, "app_version", "2.0.0-sovereign")
  storage_set_at(test_file, "user_name", "shafiullah")
  v1 = storage_get_at(test_file, "app_version")
  v2 = storage_get_at(test_file, "user_name")
  v_none = storage_get_at(test_file, "nonexistent_key")

  crud_ok = (v1 == "2.0.0-sovereign") && (v2 == "shafiullah") && (v_none == "none")
  @if crud_ok
    passed = passed + 1
    println("  [PASS] TC-STO-01: Key-value write & read (app_version='2.0.0-sovereign', missing='none')")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-01: Key-value write & read")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-02: Key Existence Check (storage_has)
  @! ----------------------------------------------------------------------------
  total = total + 1
  has_present = storage_has_at(test_file, "user_name")
  has_absent = storage_has_at(test_file, "unseen_token")
  has_ok = (has_present == 1) && (has_absent == 0)
  @if has_ok
    passed = passed + 1
    println("  [PASS] TC-STO-02: Key existence checks (storage_has present=1, absent=0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-02: Key existence checks")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-03: Overwrite Existing Key
  @! ----------------------------------------------------------------------------
  total = total + 1
  storage_set_at(test_file, "counter", "100")
  before_val = storage_get_at(test_file, "counter")
  storage_set_at(test_file, "counter", "101")
  after_val = storage_get_at(test_file, "counter")
  overwrite_ok = (before_val == "100") && (after_val == "101")
  @if overwrite_ok
    passed = passed + 1
    println("  [PASS] TC-STO-03: Overwriting existing key updates value in-place without duplicates")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-03: Overwriting existing key")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-04: Key Deletion (storage_delete)
  @! ----------------------------------------------------------------------------
  total = total + 1
  storage_set_at(test_file, "temp_token", "jwt_secret_xyz")
  had_before = storage_has_at(test_file, "temp_token")
  storage_delete_at(test_file, "temp_token")
  has_after = storage_has_at(test_file, "temp_token")
  get_after = storage_get_at(test_file, "temp_token")
  delete_ok = (had_before == 1) && (has_after == 0) && (get_after == "none")
  @if delete_ok
    passed = passed + 1
    println("  [PASS] TC-STO-04: Deleting key removes it completely from database")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-04: Deleting key")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-05: Multi-Key Retention & Batch Retrieval
  @! ----------------------------------------------------------------------------
  total = total + 1
  storage_clear_at(test_file)
  k_i = 0
  @while k_i < 10
    storage_set_at(test_file, "key_" + k_i.to_str(), "val_" + (k_i * 10).to_str())
    k_i = k_i + 1
  @end

  all_retrieved = 1
  chk_i = 0
  @while chk_i < 10
    v = storage_get_at(test_file, "key_" + chk_i.to_str())
    @if v != ("val_" + (chk_i * 10).to_str())
      all_retrieved = 0
    @end
    chk_i = chk_i + 1
  @end
  @if all_retrieved == 1
    passed = passed + 1
    println("  [PASS] TC-STO-05: Batch insertion and retrieval of 10 distinct key-value pairs")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-05: Multi-key retention")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-06: Storage Clear (storage_clear)
  @! ----------------------------------------------------------------------------
  total = total + 1
  storage_clear_at(test_file)
  has_k0 = storage_has_at(test_file, "key_0")
  has_k9 = storage_has_at(test_file, "key_9")
  clear_ok = (has_k0 == 0) && (has_k9 == 0)
  @if clear_ok
    passed = passed + 1
    println("  [PASS] TC-STO-06: Storage clear empties database completely")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-06: Storage clear")
  @end

  @! Cleanup test file
  storage_clear_at(test_file)

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Persistent Key-Value Storage PASSED")
    return 0
  @else
    println("✗ Feature: Persistent Key-Value Storage FAILED")
    return 1
  @end
@end
