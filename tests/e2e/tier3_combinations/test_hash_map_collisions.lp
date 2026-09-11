@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: HASH MAP COLLISIONS & DYNAMIC REHASHING
@! File: tests/e2e/tier3_combinations/test_hash_map_collisions.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@struct HashNode
  key: ""
  val: 0
  next: 0
@end

@struct HashMap
  buckets: 0
  capacity: 0
  count: 0
@end

@fn djb2_hash(str_key)
  hash = 5381
  len = str_len(str_key)
  i = 0
  @while i < len
    c = char_at(str_key, i)
    hash = ((hash * 32) + hash) + c  @! hash * 33 + c
    i = i + 1
  @end
  @if hash < 0
    hash = 0 - hash
  @end
  return hash
@end

@fn hashmap_new(cap)
  b = []
  i = 0
  @while i < cap
    b.push(0)
    i = i + 1
  @end
  return { buckets: b, capacity: cap, count: 0 }
@end

@fn hashmap_put(hm, key, val)
  h = djb2_hash(key)
  idx = h % hm.capacity
  curr = hm.buckets[idx]

  @! Check if key already exists in bucket chain
  @while curr != 0
    @if curr.key == key
      curr.val = val
      return hm
    @end
    curr = curr.next
  @end

  @! Insert new node at head of bucket chain
  new_head = { key: key, val: val, next: hm.buckets[idx] }
  hm.buckets[idx] = new_head
  hm.count = hm.count + 1

  return hm
@end

@fn hashmap_get(hm, key, default_val)
  h = djb2_hash(key)
  idx = h % hm.capacity
  curr = hm.buckets[idx]
  @while curr != 0
    @if curr.key == key
      return curr.val
    @end
    curr = curr.next
  @end
  return default_val
@end

@fn hashmap_contains(hm, key)
  h = djb2_hash(key)
  idx = h % hm.capacity
  curr = hm.buckets[idx]
  @while curr != 0
    @if curr.key == key
      return 1
    @end
    curr = curr.next
  @end
  return 0
@end

@fn hashmap_rehash(hm, new_cap)
  new_hm = hashmap_new(new_cap)
  i = 0
  @while i < hm.capacity
    curr = hm.buckets[i]
    @while curr != 0
      new_hm = hashmap_put(new_hm, curr.key, curr.val)
      curr = curr.next
    @end
    i = i + 1
  @end
  return new_hm
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 10: Hash Map Collisions & Rehashing")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.10.1: Initialize small hashmap with 16 buckets
  total = total + 1
  hm = hashmap_new(16)
  @if hm.capacity == 16 && hm.count == 0
    passed = passed + 1
    println("  [PASS] T3.10.1: HashMap initialized with 16 initial bucket slots")
  @else
    failed = failed + 1
    println("  [FAIL] T3.10.1: HashMap initialization failed")
  @end

  @! T3.10.2: Insert 200 keys causing massive intentional collisions
  total = total + 1
  i = 0
  @while i < 200
    k = "user_key_" + int_to_str(i)
    v = i * 10 + 5
    hm = hashmap_put(hm, k, v)
    i = i + 1
  @end

  @if hm.count == 200
    passed = passed + 1
    println("  [PASS] T3.10.2: Inserted 200 entries into 16 collision buckets (avg 12.5 chain depth)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.10.2: Insert count expected 200, got " + int_to_str(hm.count))
  @end

  @! T3.10.3: Verify 100% of 200 keys retrieve exact values before rehashing
  total = total + 1
  all_matched_pre = 1
  j = 0
  @while j < 200
    k = "user_key_" + int_to_str(j)
    expected_v = j * 10 + 5
    actual_v = hashmap_get(hm, k, -1)
    @if actual_v != expected_v
      all_matched_pre = 0
    @end
    j = j + 1
  @end

  @if all_matched_pre == 1
    passed = passed + 1
    println("  [PASS] T3.10.3: Verified 200/200 key lookups through chained collision lists")
  @else
    failed = failed + 1
    println("  [FAIL] T3.10.3: Key lookups failed before rehashing")
  @end

  @! T3.10.4: Dynamic Rehashing from 16 to 128 buckets
  total = total + 1
  hm_rehashed = hashmap_rehash(hm, 128)
  all_matched_post = 1
  j = 0
  @while j < 200
    k = "user_key_" + int_to_str(j)
    expected_v = j * 10 + 5
    actual_v = hashmap_get(hm_rehashed, k, -1)
    @if actual_v != expected_v
      all_matched_post = 0
    @end
    j = j + 1
  @end

  @if hm_rehashed.capacity == 128 && hm_rehashed.count == 200 && all_matched_post == 1
    passed = passed + 1
    println("  [PASS] T3.10.4: Rehashed to 128 buckets with 100% data fidelity preserved")
  @else
    failed = failed + 1
    println("  [FAIL] T3.10.4: Rehash verification failed")
  @end

  @! T3.10.5: In-Place Key Value Mutation and Missing Key Check
  total = total + 1
  hm_rehashed = hashmap_put(hm_rehashed, "user_key_42", 999999)
  updated_v = hashmap_get(hm_rehashed, "user_key_42", -1)
  missing_v = hashmap_get(hm_rehashed, "nonexistent_key", -1)
  has_missing = hashmap_contains(hm_rehashed, "nonexistent_key")

  @if updated_v == 999999 && missing_v == -1 && has_missing == 0
    passed = passed + 1
    println("  [PASS] T3.10.5: Key update in place (user_key_42 -> 999999) and missing key fallback")
  @else
    failed = failed + 1
    println("  [FAIL] T3.10.5: Key mutation/missing check failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 10 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 10 (Hash Map Collisions & Rehashing) PASSED")
    return 0
  @else
    println("✗ Combination 10 (Hash Map Collisions & Rehashing) FAILED")
    return 1
  @end
@end
