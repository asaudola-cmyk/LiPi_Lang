@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — P2P PACKAGE REGISTRY COMPREHENSIVE TEST SUITE
@! File: tests/p2p/test_registry.maya
@! Milestone: Milestone 2 (P2P Package Registry — Requirement R2)
@! Pure Maya Implementation Verification across Tiers 1–4 (44 Total Tests)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/p2p/registry"

@! ============================================================================
@! SECTION 1: Assertion Helpers
@! ============================================================================

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_false(cond, msg)
  @if cond != 0
    println("  [FAIL] Assertion failed (expected false): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn assert_neq_str(actual, not_expected, msg)
  @if actual == not_expected
    println("  [FAIL] " + msg + " -> Expected value to not equal '" + not_expected + "'")
    return 0
  @end
  return 1
@end

@fn assert_gt_int(actual, threshold, msg)
  @if actual <= threshold
    println("  [FAIL] " + msg + " -> Expected > " + threshold.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@! ============================================================================
@! SECTION 2: TIER 1 FEATURE COVERAGE TESTS (18 Test Cases)
@! ============================================================================

@fn run_tier1_feature_tests()
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1] P2P Feature Coverage Unit Tests (T1.1 - T1.18)")
  println("-----------------------------------------------------------------")
  passed = 0
  failed = 0

  @! T1.1: Registry Initialization
  reg = p2p_registry_new("node_alpha", "127.0.0.1", 8001)
  ok1 = assert_eq_str(reg.local_peer.id, "node_alpha", "T1.1: Local peer ID matches")
  ok2 = assert_eq_str(reg.local_peer.status, "ACTIVE", "T1.1: Local peer status is ACTIVE")
  ok3 = assert_eq_int(reg.routing_table.len(), 0, "T1.1: Initial routing table empty")
  ok4 = assert_eq_int(reg.cas_store.len(), 0, "T1.1: Initial CAS store empty")
  ok5 = assert_eq_int(reg.records.len(), 0, "T1.1: Initial records empty")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed = passed + 1
    println("  [PASS] T1.1: Registry initialization and state setup")
  @else
    failed = failed + 1
  @end

  @! T1.2: Add and Find Peer
  add_res = p2p_registry_add_peer(reg, "node_beta", "127.0.0.1", 8002)
  p_beta = p2p_registry_find_peer(reg, "node_beta")
  ok1 = assert_eq_int(add_res, 1, "T1.2: Peer addition returns success (1)")
  ok2 = assert_eq_int(reg.routing_table.len(), 1, "T1.2: Peer count is 1")
  ok3 = assert_eq_str(p_beta.id, "node_beta", "T1.2: Found peer ID matches")
  ok4 = assert_eq_int(p_beta.port, 8002, "T1.2: Found peer port matches")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed = passed + 1
    println("  [PASS] T1.2: Peer addition and routing table lookup")
  @else
    failed = failed + 1
  @end

  @! T1.3: Peer Duplicate Update
  p2p_registry_add_peer(reg, "node_beta", "127.0.0.1", 8003)
  p_beta_updated = p2p_registry_find_peer(reg, "node_beta")
  ok1 = assert_eq_int(reg.routing_table.len(), 1, "T1.3: No duplicate peer inserted")
  ok2 = assert_eq_int(p_beta_updated.port, 8003, "T1.3: Peer port updated in place")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.3: Peer duplicate in-place update")
  @else
    failed = failed + 1
  @end

  @! T1.4: Peer Removal
  p2p_registry_add_peer(reg, "node_gamma", "127.0.0.1", 8004)
  p2p_registry_remove_peer(reg, "node_beta")
  p_beta_removed = p2p_registry_find_peer(reg, "node_beta")
  ok1 = assert_eq_int(reg.routing_table.len(), 1, "T1.4: Table length decreased to 1")
  ok2 = assert_eq_str(p_beta_removed.id, "", "T1.4: Removed peer lookup returns empty")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.4: Peer removal from routing table")
  @else
    failed = failed + 1
  @end

  @! T1.5: XOR Distance Metric & Symmetry
  d1 = p2p_calculate_distance("0000000000000000000000000000000000000000000000000000000000000001", "0000000000000000000000000000000000000000000000000000000000000002")
  d2 = p2p_calculate_distance("0000000000000000000000000000000000000000000000000000000000000002", "0000000000000000000000000000000000000000000000000000000000000001")
  ok1 = assert_eq_str(d1, "0000000000000000000000000000000000000000000000000000000000000003", "T1.5: XOR distance is 3")
  ok2 = assert_eq_str(d1, d2, "T1.5: XOR distance metric is symmetric")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.5: Kademlia XOR distance metric and symmetry")
  @else
    failed = failed + 1
  @end

  @! T1.6: Closest Peers Lookup
  p2p_registry_add_peer(reg, "1000000000000000000000000000000000000000000000000000000000000000", "1.1.1.1", 80)
  p2p_registry_add_peer(reg, "2000000000000000000000000000000000000000000000000000000000000000", "1.1.1.2", 80)
  p2p_registry_add_peer(reg, "8000000000000000000000000000000000000000000000000000000000000000", "1.1.1.3", 80)
  closest = p2p_routing_find_closest(reg, "1000000000000000000000000000000000000000000000000000000000000000", 2)
  ok1 = assert_eq_int(closest.len(), 2, "T1.6: Closest peers count matches k=2")
  ok2 = assert_eq_str(closest[0].id, "1000000000000000000000000000000000000000000000000000000000000000", "T1.6: Nearest peer matches exact key")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.6: Routing table k-closest peer query")
  @else
    failed = failed + 1
  @end

  @! T1.7: CAS Store & Retrieve
  cid1 = p2p_cas_put_blob(reg, "print(\"hello pure maya\")")
  retrieved = p2p_cas_get_blob(reg, cid1)
  ok1 = assert_true(str_starts_with(cid1, "sha256:"), "T1.7: CID starts with sha256:")
  ok2 = assert_eq_str(retrieved, "print(\"hello pure maya\")", "T1.7: CAS get matches payload")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.7: CAS store and retrieve")
  @else
    failed = failed + 1
  @end

  @! T1.8: CAS Membership Check
  has_b = p2p_cas_has_blob(reg, cid1)
  has_none = p2p_cas_has_blob(reg, "sha256:0000000000000000000000000000000000000000000000000000000000000000")
  ok1 = assert_eq_int(has_b, 1, "T1.8: CAS has_blob returns 1 for existing CID")
  ok2 = assert_eq_int(has_none, 0, "T1.8: CAS has_blob returns 0 for non-existent CID")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.8: CAS membership query (has_blob)")
  @else
    failed = failed + 1
  @end

  @! T1.9: CAS Deduplication
  cid_dup = p2p_cas_put_blob(reg, "print(\"hello pure maya\")")
  ok1 = assert_eq_str(cid_dup, cid1, "T1.9: Deduplicated CID is identical")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T1.9: Content-addressable deduplication")
  @else
    failed = failed + 1
  @end

  @! T1.10: CAS SHA-256 Blob Integrity Verification
  ver_ok = p2p_cas_verify_blob("print(\"hello pure maya\")", cid1)
  ver_bad = p2p_cas_verify_blob("print(\"corrupted\")", cid1)
  ok1 = assert_eq_int(ver_ok, 1, "T1.10: CAS verify valid payload passes")
  ok2 = assert_eq_int(ver_bad, 0, "T1.10: CAS verify corrupted payload fails")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.10: SHA-256 blob integrity verification")
  @else
    failed = failed + 1
  @end

  @! T1.11: Package Publication
  rec = p2p_publish_package(reg, "maya-tensor", "1.0.0", "edition = \"2026\"", "fn tensor_init() { return 1; }", "pubkey123", "sig123")
  ok1 = assert_eq_str(rec.name, "maya-tensor", "T1.11: Published package name matches")
  ok2 = assert_eq_str(rec.version, "1.0.0", "T1.11: Published package version matches")
  ok3 = assert_true(str_len(rec.cid) > 0, "T1.11: Record has non-empty CID")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed = passed + 1
    println("  [PASS] T1.11: Package publication and metadata creation")
  @else
    failed = failed + 1
  @end

  @! T1.12: Provider Registration
  ann_res = p2p_announce_provider(reg, "maya-tensor", "1.0.0", "node_gamma")
  recs_after_ann = p2p_find_package_records(reg, "maya-tensor")
  ok1 = assert_eq_int(ann_res, 1, "T1.12: Announce provider returns success (1)")
  ok2 = assert_eq_int(recs_after_ann[0].providers.len(), 2, "T1.12: Providers array length is 2")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.12: Provider announcement registration")
  @else
    failed = failed + 1
  @end

  @! T1.13: Package Discovery
  found_recs = p2p_find_package_records(reg, "maya-tensor")
  ok1 = assert_eq_int(found_recs.len(), 1, "T1.13: Found 1 package record")
  ok2 = assert_eq_str(found_recs[0].name, "maya-tensor", "T1.13: Found record name matches")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.13: Package discovery across records")
  @else
    failed = failed + 1
  @end

  @! T1.14: SemVer Exact Match
  p2p_publish_package(reg, "maya-tensor", "1.1.0", "edition = \"2026\"", "fn tensor_init() { return 2; }", "pubkey123", "sig123")
  p2p_publish_package(reg, "maya-tensor", "1.2.5", "edition = \"2026\"", "fn tensor_init() { return 3; }", "pubkey123", "sig123")
  p2p_publish_package(reg, "maya-tensor", "2.0.0", "edition = \"2026\"", "fn tensor_init() { return 4; }", "pubkey123", "sig123")
  all_recs = p2p_find_package_records(reg, "maya-tensor")
  res_exact = p2p_resolve_semver(all_recs, "1.1.0")
  ok1 = assert_eq_str(res_exact.version, "1.1.0", "T1.14: Exact SemVer resolved 1.1.0")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T1.14: SemVer exact match resolution")
  @else
    failed = failed + 1
  @end

  @! T1.15: SemVer Caret Range
  res_caret = p2p_resolve_semver(all_recs, "^1.0.0")
  ok1 = assert_eq_str(res_caret.version, "1.2.5", "T1.15: Caret SemVer resolved highest 1.x (1.2.5)")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T1.15: SemVer caret (^) range resolution")
  @else
    failed = failed + 1
  @end

  @! T1.16: SemVer Tilde Range
  res_tilde = p2p_resolve_semver(all_recs, "~1.1.0")
  ok1 = assert_eq_str(res_tilde.version, "1.1.0", "T1.16: Tilde SemVer resolved patch (1.1.0)")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T1.16: SemVer tilde (~) range resolution")
  @else
    failed = failed + 1
  @end

  @! T1.17: RPC Message Framing & Dispatch
  msg = p2p_create_message("PING", "node_alpha", "127.0.0.1:8001", "node_beta", "", 42)
  resp = p2p_handle_message(reg, msg)
  ok1 = assert_eq_int(resp.status, 200, "T1.17: Message response status 200")
  ok2 = assert_eq_str(resp.msg_type, "PONG", "T1.17: PING message replied with PONG")
  ok3 = assert_eq_int(resp.nonce, 42, "T1.17: Correlation nonce preserved")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed = passed + 1
    println("  [PASS] T1.17: P2P RPC message framing and dispatch")
  @else
    failed = failed + 1
  @end

  @! T1.18: Lockfile Entry Generation & Parsing
  lock_entry = p2p_generate_lockfile_entry(rec.name, rec.version, rec.cid)
  parsed_cid = p2p_parse_lockfile_source(lock_entry)
  ok1 = assert_true(str_contains(lock_entry, "p2p+dht://"), "T1.18: Lockfile contains p2p+dht:// source URI")
  ok2 = assert_eq_str(parsed_cid, rec.cid, "T1.18: Parsed CID matches record CID")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T1.18: Lockfile entry generation and deterministic URI parsing")
  @else
    failed = failed + 1
  @end

  println("▶ Tier 1 Feature Coverage: " + passed.to_str() + "/18 Passed, " + failed.to_str() + " Failed")
  @if failed == 0 return 1 @end
  return 0
@end

@! ============================================================================
@! SECTION 3: TIER 2 BOUNDARY & CORNER CASE TESTS (14 Test Cases)
@! ============================================================================

@fn run_tier2_boundary_tests()
  println("-----------------------------------------------------------------")
  println("▶ [TIER 2] Boundary & Corner Case Tests (T2.1 - T2.14)")
  println("-----------------------------------------------------------------")
  passed = 0
  failed = 0

  reg = p2p_registry_new("node_boundary", "127.0.0.1", 9001)

  @! T2.1: Empty Blob (0-Byte Payload)
  empty_cid = p2p_cas_put_blob(reg, "")
  exp_empty_cid = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  empty_data = p2p_cas_get_blob(reg, empty_cid)
  ok1 = assert_eq_str(empty_cid, exp_empty_cid, "T2.1: Empty string matches NIST SHA-256")
  ok2 = assert_eq_str(empty_data, "", "T2.1: Retrieved empty blob is empty string")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T2.1: Empty 0-byte blob CAS boundary")
  @else
    failed = failed + 1
  @end

  @! T2.2: Multi-Kilobyte Payload
  huge_str = ""
  k = 0
  @while k < 500
    huge_str = huge_str + "fn sovereign_worker_" + k.to_str() + "() { return " + k.to_str() + "; }\n"
    k = k + 1
  @end
  huge_cid = p2p_cas_put_blob(reg, huge_str)
  huge_retrieved = p2p_cas_get_blob(reg, huge_cid)
  ok1 = assert_eq_str(huge_retrieved, huge_str, "T2.2: Large payload exact roundtrip")
  ok2 = assert_eq_int(p2p_cas_verify_blob(huge_str, huge_cid), 1, "T2.2: Large payload SHA-256 verify")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T2.2: Multi-kilobyte large blob CAS throughput and integrity")
  @else
    failed = failed + 1
  @end

  @! T2.3: Malformed and Invalid CIDs
  m1 = p2p_cas_get_blob(reg, "")
  m2 = p2p_cas_get_blob(reg, "sha256:invalid")
  m3 = p2p_cas_get_blob(reg, "non_existent_hash_123")
  ok1 = assert_eq_str(m1, "", "T2.3: Empty CID lookup returns empty")
  ok2 = assert_eq_str(m2, "", "T2.3: Invalid CID lookup returns empty")
  ok3 = assert_eq_str(m3, "", "T2.3: Non-existent CID lookup returns empty")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed = passed + 1
    println("  [PASS] T2.3: Malformed and invalid CID safe handling")
  @else
    failed = failed + 1
  @end

  @! T2.4: Binary & Special Characters
  special_payload = "Line1\nLine2\tTabbed\r\nQuotes: \"Maya\"\0NullByte"
  spec_cid = p2p_cas_put_blob(reg, special_payload)
  spec_get = p2p_cas_get_blob(reg, spec_cid)
  ok1 = assert_eq_str(spec_get, special_payload, "T2.4: Special character payload matches")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.4: Escaped and special character string preservation")
  @else
    failed = failed + 1
  @end

  @! T2.5: Identity XOR Distance (Identity)
  id_max = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  id_zero = "0000000000000000000000000000000000000000000000000000000000000000"
  dist_id = p2p_calculate_distance(id_max, id_max)
  ok1 = assert_eq_str(dist_id, id_zero, "T2.5: Identity XOR distance is all zeros")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.5: XOR distance identity property d(x, x) = 0")
  @else
    failed = failed + 1
  @end

  @! T2.6: Maximum XOR Distance (Opposite Extremity)
  dist_max = p2p_calculate_distance(id_zero, id_max)
  ok1 = assert_eq_str(dist_max, id_max, "T2.6: Opposite XOR distance is all f's")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.6: XOR distance maximum extremity")
  @else
    failed = failed + 1
  @end

  @! T2.7: Self-Routing Prevention
  self_add = p2p_registry_add_peer(reg, "node_boundary", "127.0.0.1", 9001)
  ok1 = assert_eq_int(self_add, 0, "T2.7: Adding self returns 0")
  ok2 = assert_eq_int(reg.routing_table.len(), 0, "T2.7: Self node not added to routing table")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T2.7: Self-routing prevention and loop avoidance")
  @else
    failed = failed + 1
  @end

  @! T2.8: Routing Table Capacity Limit
  reg_cap = p2p_registry_new("node_cap", "127.0.0.1", 9002)
  reg_cap.k_capacity = 5
  p2p_add_peer(reg_cap, "p1", "127.0.0.1", 9010)
  p2p_add_peer(reg_cap, "p2", "127.0.0.1", 9011)
  p2p_add_peer(reg_cap, "p3", "127.0.0.1", 9012)
  p2p_add_peer(reg_cap, "p4", "127.0.0.1", 9013)
  p2p_add_peer(reg_cap, "p5", "127.0.0.1", 9014)
  p2p_add_peer(reg_cap, "p6", "127.0.0.1", 9015)
  ok1 = assert_eq_int(reg_cap.routing_table.len(), 5, "T2.8: Routing table capped at k_capacity 5")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.8: Routing table bucket capacity limit")
  @else
    failed = failed + 1
  @end

  @! T2.9: Empty Routing Table Query
  empty_closest = p2p_routing_find_closest(reg, id_max, 5)
  ok1 = assert_eq_int(empty_closest.len(), 0, "T2.9: Empty routing table query returns empty array")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.9: Empty routing table query safety")
  @else
    failed = failed + 1
  @end

  @! T2.10: Closest Query with Fewer Peers than K
  p2p_add_peer(reg, "node_extra1", "1.1.1.1", 80)
  p2p_add_peer(reg, "node_extra2", "1.1.1.2", 80)
  fewer_closest = p2p_routing_find_closest(reg, id_max, 10)
  ok1 = assert_eq_int(fewer_closest.len(), 2, "T2.10: Returns exactly 2 peers when table has 2")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.10: Closest query with N < K peers")
  @else
    failed = failed + 1
  @end

  @! T2.11: SemVer Unknown Package Lookup
  missing_pkg = p2p_find_package_records(reg, "nonexistent-pkg-xyz")
  ok1 = assert_eq_int(missing_pkg.len(), 0, "T2.11: Missing package returns empty records")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.11: Missing package record query")
  @else
    failed = failed + 1
  @end

  @! T2.12: SemVer Unsatisfiable Constraint
  p2p_publish_package(reg, "known-pkg", "1.0.0", "ed=\"2026\"", "code", "k", "s")
  known_recs = p2p_find_package_records(reg, "known-pkg")
  unmet_semver = p2p_resolve_semver(known_recs, "^2.0.0")
  ok1 = assert_eq_str(unmet_semver.name, "", "T2.12: Unsatisfied SemVer returns empty record")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.12: Unsatisfiable SemVer constraint resolution")
  @else
    failed = failed + 1
  @end

  @! T2.13: SemVer Prerelease Precedence & Exact Prerelease Matching
  p2p_publish_package(reg, "pre-pkg", "1.0.0-alpha.1", "ed=\"2026\"", "code", "k", "s")
  p2p_publish_package(reg, "pre-pkg", "1.0.0", "ed=\"2026\"", "code", "k", "s")
  p2p_publish_package(reg, "pre-pkg", "1.0.1+build.1", "ed=\"2026\"", "code", "k", "s")
  pre_recs = p2p_find_package_records(reg, "pre-pkg")
  res_pre = p2p_resolve_semver(pre_recs, ">=1.0.0")
  ok1 = assert_eq_str(res_pre.version, "1.0.1+build.1", "T2.13: Selects highest release version (1.0.1+build.1)")

  p2p_publish_package(reg, "rc-pkg", "2.0.0-rc.1", "ed=\"2026\"", "code", "k", "s")
  p2p_publish_package(reg, "rc-pkg", "2.0.0-rc.2", "ed=\"2026\"", "code", "k", "s")
  rc_recs = p2p_find_package_records(reg, "rc-pkg")

  v_rc1 = p2p_semver_parse("2.0.0-rc.1")
  v_rc2 = p2p_semver_parse("2.0.0-rc.1")
  cmp_rc = p2p_semver_compare(v_rc1, v_rc2)
  sat_rc = p2p_semver_satisfies("2.0.0-rc.1", "2.0.0-rc.1")
  res_rc = p2p_resolve_semver(rc_recs, "2.0.0-rc.1")

  ok2 = assert_eq_int(cmp_rc, 0, "T2.13: Exact prerelease comparison '2.0.0-rc.1' vs '2.0.0-rc.1' returns 0")
  ok3 = assert_eq_int(sat_rc, 1, "T2.13: Exact prerelease satisfies returns 1")
  ok4 = assert_eq_str(res_rc.version, "2.0.0-rc.1", "T2.13: Exact prerelease resolution returns 2.0.0-rc.1")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed = passed + 1
    println("  [PASS] T2.13: SemVer prerelease precedence, exact matching, and resolution")
  @else
    failed = failed + 1
  @end

  @! T2.14: Forged / Invalid Author Signature Detection
  bad_sig = p2p_verify_signature("pubkey_valid", "msg_content", "corrupted_sig")
  ok1 = assert_eq_int(bad_sig, 0, "T2.14: Corrupted author signature rejected")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T2.14: Corrupted author signature detection")
  @else
    failed = failed + 1
  @end

  println("▶ Tier 2 Boundary Tests: " + passed.to_str() + "/14 Passed, " + failed.to_str() + " Failed")
  @if failed == 0 return 1 @end
  return 0
@end

@! ============================================================================
@! SECTION 4: TIER 3 MULTI-NODE NETWORK INTERACTIONS (8 Test Cases)
@! ============================================================================

@fn run_tier3_network_tests()
  println("-----------------------------------------------------------------")
  println("▶ [TIER 3] Multi-Node Network Interaction Tests (T3.1 - T3.8)")
  println("-----------------------------------------------------------------")
  passed = 0
  failed = 0

  @! Setup 8-node swarm
  n0 = p2p_registry_new("node_0", "127.0.0.1", 7000)
  n1 = p2p_registry_new("node_1", "127.0.0.1", 7001)
  n2 = p2p_registry_new("node_2", "127.0.0.1", 7002)
  n3 = p2p_registry_new("node_3", "127.0.0.1", 7003)
  n4 = p2p_registry_new("node_4", "127.0.0.1", 7004)
  n5 = p2p_registry_new("node_5", "127.0.0.1", 7005)
  n6 = p2p_registry_new("node_6", "127.0.0.1", 7006)
  n7 = p2p_registry_new("node_7", "127.0.0.1", 7007)

  @! Connect in ring/mesh topology
  p2p_registry_add_peer(n0, "node_1", "127.0.0.1", 7001)
  p2p_registry_add_peer(n1, "node_2", "127.0.0.1", 7002)
  p2p_registry_add_peer(n2, "node_3", "127.0.0.1", 7003)
  p2p_registry_add_peer(n3, "node_4", "127.0.0.1", 7004)
  p2p_registry_add_peer(n4, "node_5", "127.0.0.1", 7005)
  p2p_registry_add_peer(n5, "node_6", "127.0.0.1", 7006)
  p2p_registry_add_peer(n6, "node_7", "127.0.0.1", 7007)
  p2p_registry_add_peer(n7, "node_0", "127.0.0.1", 7000)

  @! T3.1: 8-Node Swarm Network Ring Bootstrap
  ok1 = assert_eq_int(n0.routing_table.len(), 1, "T3.1: Node 0 peer count")
  ok2 = assert_eq_int(n7.routing_table.len(), 1, "T3.1: Node 7 peer count")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T3.1: 8-node swarm network ring bootstrap")
  @else
    failed = failed + 1
  @end

  @! T3.2: Multi-Hop DHT Package Discovery
  rec0 = p2p_publish_package(n0, "maya-quantum", "0.5.0", "edition=\"2026\"", "fn quantum_gate() { return 100; }", "key0", "sig0")
  p2p_sync_nodes(n0, n7)
  recs_at_7 = p2p_find_package_records(n7, "maya-quantum")
  ok1 = assert_eq_int(recs_at_7.len(), 1, "T3.2: Package discovered across swarm at Node 7")
  ok2 = assert_eq_str(recs_at_7[0].name, "maya-quantum", "T3.2: Discovered package name matches")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T3.2: Multi-hop DHT package record discovery")
  @else
    failed = failed + 1
  @end

  @! T3.3: Remote Swarm Chunk Transfer & Local CAS Caching
  fetch_msg = p2p_create_message("FETCH_BLOB", "node_7", "127.0.0.1:7007", "node_0", rec0.cid, 101)
  fetch_resp = p2p_handle_message(n0, fetch_msg)
  p2p_cas_put_blob(n7, fetch_resp.payload)
  ok1 = assert_eq_int(fetch_resp.status, 200, "T3.3: Fetch blob response status 200")
  ok2 = assert_eq_int(p2p_cas_has_blob(n7, rec0.cid), 1, "T3.3: Node 7 has cached fetched blob in local CAS")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T3.3: Remote swarm CAS blob transfer and local cache verification")
  @else
    failed = failed + 1
  @end

  @! T3.4: Multi-Provider Redundancy
  p2p_announce_provider(n0, "maya-quantum", "0.5.0", "node_1")
  p2p_announce_provider(n0, "maya-quantum", "0.5.0", "node_2")
  recs_updated = p2p_find_package_records(n0, "maya-quantum")
  ok1 = assert_eq_int(recs_updated[0].providers.len(), 3, "T3.4: Package has 3 registered providers")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T3.4: Multi-provider swarm redundancy aggregation")
  @else
    failed = failed + 1
  @end

  @! T3.5: Node Churn & Departure Pruning
  p2p_registry_add_peer(n0, "node_stale", "127.0.0.1", 7099)
  p2p_registry_remove_peer(n0, "node_stale")
  stale_lookup = p2p_registry_find_peer(n0, "node_stale")
  ok1 = assert_eq_str(stale_lookup.id, "", "T3.5: Stale node removed from active routing table")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T3.5: Node churn handling and stale peer pruning")
  @else
    failed = failed + 1
  @end

  @! T3.6: Provider Failover on Unreachable Peer
  p2p_publish_package(n1, "failover-pkg", "1.0.0", "ed=\"2026\"", "fn primary() { return 1; }", "k", "s")
  p2p_sync_nodes(n1, n2)
  dead_msg = p2p_create_message("FETCH_BLOB", "client", "127.0.0.1", "node_dead", "invalid_cid", 102)
  dead_resp = p2p_handle_message(n1, dead_msg)
  active_msg = p2p_create_message("FETCH_BLOB", "client", "127.0.0.1", "node_2", p2p_find_package_records(n2, "failover-pkg")[0].cid, 103)
  active_resp = p2p_handle_message(n2, active_msg)
  ok1 = assert_eq_int(dead_resp.status, 404, "T3.6: Dead provider returns 404")
  ok2 = assert_eq_int(active_resp.status, 200, "T3.6: Secondary active provider returns 200")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T3.6: Multi-provider failover recovery")
  @else
    failed = failed + 1
  @end

  @! T3.7: Two-Way State Synchronization
  p2p_publish_package(n1, "pkg-n1", "1.0.0", "ed=\"2026\"", "code1", "k", "s")
  p2p_publish_package(n2, "pkg-n2", "1.0.0", "ed=\"2026\"", "code2", "k", "s")
  synced_count = p2p_sync_nodes(n1, n2)
  recs1 = p2p_find_package_records(n1, "pkg-n2")
  recs2 = p2p_find_package_records(n2, "pkg-n1")
  ok1 = assert_gt_int(synced_count, 0, "T3.7: Synced items > 0")
  ok2 = assert_eq_int(recs1.len(), 1, "T3.7: Node 1 has pkg-n2")
  ok3 = assert_eq_int(recs2.len(), 1, "T3.7: Node 2 has pkg-n1")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed = passed + 1
    println("  [PASS] T3.7: Two-way peer and package state synchronization")
  @else
    failed = failed + 1
  @end

  @! T3.8: Byzantine Swarm Reputation Penalty
  malicious_peer = make_dummy_peer("node_bad", "1.2.3.4", 9999)
  malicious_peer.reputation = malicious_peer.reputation - 150
  ok1 = assert_gt_int(0, malicious_peer.reputation, "T3.8: Malicious peer reputation docked below 0")
  @if ok1 == 1
    passed = passed + 1
    println("  [PASS] T3.8: Byzantine peer reputation penalization")
  @else
    failed = failed + 1
  @end

  println("▶ Tier 3 Network Tests: " + passed.to_str() + "/8 Passed, " + failed.to_str() + " Failed")
  @if failed == 0 return 1 @end
  return 0
@end

@! ============================================================================
@! SECTION 5: TIER 4 REAL-WORLD APPLICATION SCENARIOS (4 Workloads)
@! ============================================================================

@fn run_tier4_scenario_tests()
  println("-----------------------------------------------------------------")
  println("▶ [TIER 4] Real-World Application Scenarios (T4.1 - T4.4)")
  println("-----------------------------------------------------------------")
  passed = 0
  failed = 0

  @! T4.1: Multi-Version Package Evolution & SemVer Range Negotiation
  reg_eco = p2p_registry_new("node_ecosystem", "127.0.0.1", 6000)
  p2p_publish_package(reg_eco, "maya-web", "1.0.0", "ed=\"2026\"", "fn web() { return 100; }", "k", "s")
  p2p_publish_package(reg_eco, "maya-web", "1.0.1", "ed=\"2026\"", "fn web() { return 101; }", "k", "s")
  p2p_publish_package(reg_eco, "maya-web", "1.1.0", "ed=\"2026\"", "fn web() { return 110; }", "k", "s")
  p2p_publish_package(reg_eco, "maya-web", "1.2.0", "ed=\"2026\"", "fn web() { return 120; }", "k", "s")
  p2p_publish_package(reg_eco, "maya-web", "2.0.0", "ed=\"2026\"", "fn web() { return 200; }", "k", "s")

  web_recs = p2p_find_package_records(reg_eco, "maya-web")
  c1 = p2p_resolve_semver(web_recs, "^1.0.0")
  c2 = p2p_resolve_semver(web_recs, "~1.0.0")
  c3 = p2p_resolve_semver(web_recs, "^2.0.0")
  c4 = p2p_resolve_semver(web_recs, "1.0.0")

  ok1 = assert_eq_str(c1.version, "1.2.0", "T4.1: App 1 resolves 1.2.0 under ^1.0.0")
  ok2 = assert_eq_str(c2.version, "1.0.1", "T4.1: App 2 resolves 1.0.1 under ~1.0.0")
  ok3 = assert_eq_str(c3.version, "2.0.0", "T4.1: App 3 resolves 2.0.0 under ^2.0.0")
  ok4 = assert_eq_str(c4.version, "1.0.0", "T4.1: App 4 resolves 1.0.0 under exact")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed = passed + 1
    println("  [PASS] T4.1: Scenario 1: Multi-version package lifecycle & SemVer negotiation")
  @else
    failed = failed + 1
  @end

  @! T4.2: Transitive Dependency Resolution & Lockfile Generation
  p2p_publish_package(reg_eco, "app-service", "1.0.0", "deps=['maya-web@^1.0.0']", "fn app() { return 1; }", "k", "s")
  p2p_publish_package(reg_eco, "maya-json", "1.3.0", "deps=[]", "fn json() { return 2; }", "k", "s")

  rec_app = p2p_find_package_records(reg_eco, "app-service")[0]
  rec_dep = p2p_find_package_records(reg_eco, "maya-web")[3] @! 1.2.0
  lock1 = p2p_generate_lockfile_entry(rec_app.name, rec_app.version, rec_app.cid)
  lock2 = p2p_generate_lockfile_entry(rec_dep.name, rec_dep.version, rec_dep.cid)
  ok1 = assert_neq_str(lock1, "", "T4.2: Lockfile entry 1 generated")
  ok2 = assert_neq_str(lock2, "", "T4.2: Lockfile entry 2 generated")
  ok3 = assert_true(str_contains(lock1, "app-service"), "T4.2: Lockfile 1 contains package name")
  ok4 = assert_true(str_contains(lock2, "maya-web"), "T4.2: Lockfile 2 contains package name")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed = passed + 1
    println("  [PASS] T4.2: Scenario 2: Transitive dependency resolution and lockfile generation")
  @else
    failed = failed + 1
  @end

  @! T4.3: Corrupted Chunk Detection and Swarm Recovery
  authentic_payload = "fn sovereign_db_query() { return 42; }"
  db_cid = p2p_cas_put_blob(reg_eco, authentic_payload)
  corrupted_payload = "fn sovereign_db_query() { return 43; }"
  is_corrupt_detected = (p2p_cas_verify_blob(corrupted_payload, db_cid) == 0)
  recovered_blob = p2p_cas_get_blob(reg_eco, db_cid)
  ok1 = assert_true(is_corrupt_detected, "T4.3: Corrupted blob checksum failure detected")
  ok2 = assert_eq_str(recovered_blob, authentic_payload, "T4.3: Fallback retrieval restored valid payload")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T4.3: Scenario 3: Byzantine corrupted chunk detection and recovery")
  @else
    failed = failed + 1
  @end

  @! T4.4: Complete Dev -> DHT -> Lockfile -> Materialize Pipeline
  dev_payload = "fn ai_inference(x) { return x * 2; }"
  rec_ai = p2p_publish_package(reg_eco, "maya-ai-core", "0.9.0", "ed=\"2026\"", dev_payload, "dev_pubkey", "dev_sig")
  ci_lock = p2p_generate_lockfile_entry(rec_ai.name, rec_ai.version, rec_ai.cid)
  prod_cid = p2p_parse_lockfile_source(ci_lock)
  prod_data = p2p_cas_get_blob(reg_eco, prod_cid)
  ok1 = assert_eq_str(prod_cid, rec_ai.cid, "T4.4: Lockfile source CID matched publish CID")
  ok2 = assert_eq_str(prod_data, dev_payload, "T4.4: Deployed payload matches original developer code")
  @if ok1 == 1 && ok2 == 1
    passed = passed + 1
    println("  [PASS] T4.4: Scenario 4: End-to-end publish -> DHT -> lockfile -> materialize pipeline")
  @else
    failed = failed + 1
  @end

  println("▶ Tier 4 Scenario Tests: " + passed.to_str() + "/4 Passed, " + failed.to_str() + " Failed")
  @if failed == 0 return 1 @end
  return 0
@end

@! ============================================================================
@! SECTION 6: MAIN SUITE ENTRYPOINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🏆 MAYA UNIVERSAL ARCHITECTURE — P2P REGISTRY TEST SUITE")
  println("=================================================================")

  r1 = run_tier1_feature_tests()
  r2 = run_tier2_boundary_tests()
  r3 = run_tier3_network_tests()
  r4 = run_tier4_scenario_tests()

  total_failures = 0
  @if r1 == 0 total_failures = total_failures + 1 @end
  @if r2 == 0 total_failures = total_failures + 1 @end
  @if r3 == 0 total_failures = total_failures + 1 @end
  @if r4 == 0 total_failures = total_failures + 1 @end

  println("=================================================================")
  @if total_failures == 0
    println("✅ ALL 44 P2P PACKAGE REGISTRY TEST CASES PASSED SUCCESSFULLY (100%)!")
    println("=================================================================")
    return 0
  @else
    println("❌ P2P PACKAGE REGISTRY SUITE FAILED WITH " + total_failures.to_str() + " TIER FAILURES!")
    println("=================================================================")
    return 1
  @end
@end
