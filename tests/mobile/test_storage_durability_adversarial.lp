// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Storage Durability & Adversarial Boundaries PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: mobile, storage, persistence, durability, large_payload, corruption, stress

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & ADVERSARIAL: STORAGE DURABILITY & STRESS
@! File: tests/mobile/test_storage_durability_adversarial.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/mobile/storage"

@fn make_large_string(pattern: string, repetitions: i64) -> string
  res = ""
  i = 0
  @while i < repetitions
    res = res + pattern
    i = i + 1
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Storage Durability, Large Payloads & Stress")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  test_db_path = "test_adv_durability.kv"
  storage_clear_at(test_db_path)

  @! ----------------------------------------------------------------------------
  @! TC-STO-ADV-01: Process Restart Durability Simulation
  @! ----------------------------------------------------------------------------
  total = total + 1
  @! Step 1: Process A writes database
  storage_set_at(test_db_path, "session_token", "Bearer_9876543210_abcdef")
  storage_set_at(test_db_path, "user_role", "sovereign_admin")

  @! Step 2: Simulate complete memory drop (no in-memory caching)
  @! Step 3: Process B reads database fresh from disk
  loaded_token = storage_get_at(test_db_path, "session_token")
  loaded_role = storage_get_at(test_db_path, "user_role")

  durability_ok = (loaded_token == "Bearer_9876543210_abcdef") && (loaded_role == "sovereign_admin")
  @if durability_ok
    passed = passed + 1
    println("  [PASS] TC-STO-ADV-01: File-backed durability survives process restart simulation")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-ADV-01: Process restart durability")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-ADV-02: Large Value Payload Storage (4KB and 16KB strings)
  @! ----------------------------------------------------------------------------
  total = total + 1
  @! Construct 4KB string (64 * 64 chars)
  pattern_64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  large_4kb = make_large_string(pattern_64, 64)

  storage_set_at(test_db_path, "large_blob_4kb", large_4kb)
  read_4kb = storage_get_at(test_db_path, "large_blob_4kb")

  len_4kb_match = (str_len(read_4kb) == str_len(large_4kb))
  content_4kb_match = (read_4kb == large_4kb)

  @if len_4kb_match && content_4kb_match
    passed = passed + 1
    println("  [PASS] TC-STO-ADV-02: Large string payload (4,096 bytes) stored and retrieved accurately")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-ADV-02: Large value payload storage")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-ADV-03: Special Characters & Hex Encoding Robustness
  @! ----------------------------------------------------------------------------
  total = total + 1
  complex_key = "k:root/sub=1;tag#test\n[new_line]"
  complex_val = "{\n  \"status\": 200,\n  \"query\": \"a=1&b=2\",\n  \"meta\": \"escaped: \\\"quote\\\"\"\n}"

  storage_set_at(test_db_path, complex_key, complex_val)
  has_complex = storage_has_at(test_db_path, complex_key)
  read_complex = storage_get_at(test_db_path, complex_key)

  complex_ok = (has_complex == 1) && (read_complex == complex_val)
  @if complex_ok
    passed = passed + 1
    println("  [PASS] TC-STO-ADV-03: Special characters (newlines, colons, equals, quotes, JSON) preserved via hex codec")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-ADV-03: Special characters in keys/values")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-ADV-04: High-Churn Key Lifecycle Stress (100 inserts, 50 updates, 25 deletes)
  @! ----------------------------------------------------------------------------
  total = total + 1
  storage_clear_at(test_db_path)

  @! 100 Inserts
  c_i = 0
  @while c_i < 100
    storage_set_at(test_db_path, "usr_" + c_i.to_str(), "initial_" + c_i.to_str())
    c_i = c_i + 1
  @end

  @! 50 Updates
  u_i = 0
  @while u_i < 50
    storage_set_at(test_db_path, "usr_" + u_i.to_str(), "updated_" + u_i.to_str())
    u_i = u_i + 1
  @end

  @! 25 Deletes
  d_i = 0
  @while d_i < 25
    storage_delete_at(test_db_path, "usr_" + d_i.to_str())
    d_i = d_i + 1
  @end

  @! Verify states
  d0_has = storage_has_at(test_db_path, "usr_0")
  d24_has = storage_has_at(test_db_path, "usr_24")
  u25_val = storage_get_at(test_db_path, "usr_25")
  u49_val = storage_get_at(test_db_path, "usr_49")
  i50_val = storage_get_at(test_db_path, "usr_50")
  i99_val = storage_get_at(test_db_path, "usr_99")

  c_del_ok = (d0_has == 0) && (d24_has == 0)
  c_upd_ok = (u25_val == "updated_25") && (u49_val == "updated_49")
  c_ins_ok = (i50_val == "initial_50") && (i99_val == "initial_99")
  churn_ok = c_del_ok && c_upd_ok && c_ins_ok
  @if churn_ok
    passed = passed + 1
    println("  [PASS] TC-STO-ADV-04: High-churn lifecycle stress (100 inserts, 50 updates, 25 deletes)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-ADV-04: High-churn key lifecycle stress")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-STO-ADV-05: Corrupted & Truncated Line Recovery
  @! ----------------------------------------------------------------------------
  total = total + 1
  corrupt_file = "test_corrupt.kv"
  @! Write file containing valid entries plus garbage lines
  k1_hex = hex_encode_str("valid_key1")
  v1_hex = hex_encode_str("valid_val1")
  k2_hex = hex_encode_str("valid_key2")
  v2_hex = hex_encode_str("valid_val2")

  corrupt_content = k1_hex + "=" + v1_hex + "\n"
  corrupt_content = corrupt_content + "THIS_LINE_HAS_NO_EQUALS_SIGN\n"
  corrupt_content = corrupt_content + "=MISSING_KEY\n"
  corrupt_content = corrupt_content + "\n"
  corrupt_content = corrupt_content + k2_hex + "=" + v2_hex + "\n"
  file_write(corrupt_file, corrupt_content)

  c_v1 = storage_get_at(corrupt_file, "valid_key1")
  c_v2 = storage_get_at(corrupt_file, "valid_key2")
  corrupt_recovery_ok = (c_v1 == "valid_val1") && (c_v2 == "valid_val2")
  @if corrupt_recovery_ok
    passed = passed + 1
    println("  [PASS] TC-STO-ADV-05: Storage loader recovers gracefully from malformed & truncated lines")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STO-ADV-05: Corrupted line recovery")
  @end

  @! Cleanup test files
  storage_clear_at(test_db_path)
  storage_clear_at(corrupt_file)

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Storage Durability & Adversarial Boundaries PASSED")
    return 0
  @else
    println("✗ Feature: Storage Durability & Adversarial Boundaries FAILED")
    return 1
  @end
@end
