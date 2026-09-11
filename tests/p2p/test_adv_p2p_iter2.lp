@! ============================================================================
@! MAYA P2P REGISTRY ITERATION 2 DEEP ADVERSARIAL VERIFICATION HARNESS
@! ============================================================================

import "universe/p2p/registry.maya"

@fn assert_true(cond, msg)
  @if cond == 1
    return 1
  @else
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual == expected
    return 1
  @else
    println("  [FAIL] " + msg + " (expected: " + expected.to_str() + ", actual: " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual == expected
    return 1
  @else
    println("  [FAIL] " + msg + " (expected: '" + expected + "', actual: '" + actual + "')")
    return 0
  @end
@end

@fn test_extended_semver()
  println("-----------------------------------------------------------------")
  println("▶ [TEST 1] Extended SemVer Prerelease & Build Metadata Matrix")
  println("-----------------------------------------------------------------")
  passed = 0
  failed = 0

  @! 1. Equality on identical prereleases
  v1 = p2p_semver_parse("1.0.0-alpha")
  v2 = p2p_semver_parse("1.0.0-alpha")
  cmp1 = p2p_semver_compare(v1, v2)
  ok1 = assert_eq_int(cmp1, 0, "1.0.0-alpha == 1.0.0-alpha")

  @! 2. Ordering between prerelease tags: alpha < beta < rc
  v_alpha = p2p_semver_parse("1.0.0-alpha")
  v_beta  = p2p_semver_parse("1.0.0-beta")
  v_rc    = p2p_semver_parse("1.0.0-rc.1")
  v_rel   = p2p_semver_parse("1.0.0")

  cmp_ab = p2p_semver_compare(v_alpha, v_beta)
  cmp_br = p2p_semver_compare(v_beta, v_rc)
  cmp_rr = p2p_semver_compare(v_rc, v_rel)

  ok2 = assert_eq_int(cmp_ab, -1, "1.0.0-alpha < 1.0.0-beta")
  ok3 = assert_eq_int(cmp_br, -1, "1.0.0-beta < 1.0.0-rc.1")
  ok4 = assert_eq_int(cmp_rr, -1, "1.0.0-rc.1 < 1.0.0 (prerelease < release)")

  @! 3. Build metadata does NOT affect precedence
  v_b1 = p2p_semver_parse("1.0.0+20130313144700")
  v_b2 = p2p_semver_parse("1.0.0+exp.sha.5114f85")
  cmp_build = p2p_semver_compare(v_b1, v_b2)
  ok5 = assert_eq_int(cmp_build, 0, "1.0.0+build1 == 1.0.0+build2 precedence")

  @! 4. Exact satisfiability across various prerelease styles
  sat_a1 = p2p_semver_satisfies("1.0.0-alpha", "1.0.0-alpha")
  sat_a2 = p2p_semver_satisfies("1.0.0-alpha", "=1.0.0-alpha")
  sat_rc1 = p2p_semver_satisfies("3.1.4-beta.99", "3.1.4-beta.99")
  sat_diff = p2p_semver_satisfies("1.0.0-alpha", "1.0.0-beta")

  ok6 = assert_eq_int(sat_a1, 1, "satisfies('1.0.0-alpha', '1.0.0-alpha')")
  ok7 = assert_eq_int(sat_a2, 1, "satisfies('1.0.0-alpha', '=1.0.0-alpha')")
  ok8 = assert_eq_int(sat_rc1, 1, "satisfies('3.1.4-beta.99', '3.1.4-beta.99')")
  ok9 = assert_eq_int(sat_diff, 0, "satisfies('1.0.0-alpha', '1.0.0-beta') == 0")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    println("  [PASS] Extended SemVer Prerelease & Build Metadata Matrix")
    return 1
  @else
    println("  [FAIL] Extended SemVer Prerelease Matrix Failed")
    return 0
  @end
@end

@fn test_dht_extreme_routing()
  println("-----------------------------------------------------------------")
  println("▶ [TEST 2] DHT Boundary Routing & Extreme Distance Properties")
  println("-----------------------------------------------------------------")
  passed = 0
  failed = 0

  reg = p2p_registry_new("extreme_node", "127.0.0.1", 9000)

  @! Empty query
  closest_empty = p2p_routing_find_closest(reg, "0000000000000000000000000000000000000000000000000000000000000000", 5)
  ok1 = assert_eq_int(closest_empty.len(), 0, "Empty routing table returns 0 peers")

  @! Add extremes: 0000... and ffff...
  k_min = "0000000000000000000000000000000000000000000000000000000000000000"
  k_max = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  k_mid = "8000000000000000000000000000000000000000000000000000000000000000"

  p2p_add_peer(reg, k_min, "10.0.0.1", 9001)
  p2p_add_peer(reg, k_max, "10.0.0.2", 9002)
  p2p_add_peer(reg, k_mid, "10.0.0.3", 9003)

  @! Query for near min
  c_min = p2p_routing_find_closest(reg, "0000000000000000000000000000000000000000000000000000000000000001", 1)
  ok2 = assert_eq_str(c_min[0].id, k_min, "Closest to near-min is k_min")

  @! Query for near max
  c_max = p2p_routing_find_closest(reg, "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeee", 1)
  ok3 = assert_eq_str(c_max[0].id, k_max, "Closest to near-max is k_max")

  @! Query for near mid
  c_mid = p2p_routing_find_closest(reg, "8000000000000000000000000000000000000000000000000000000000000001", 1)
  ok4 = assert_eq_str(c_mid[0].id, k_mid, "Closest to near-mid is k_mid")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    println("  [PASS] DHT Boundary Routing & Extreme Distance Properties")
    return 1
  @else
    println("  [FAIL] DHT Boundary Routing Failed")
    return 0
  @end
@end

@fn test_multi_package_prerelease_resolution()
  println("-----------------------------------------------------------------")
  println("▶ [TEST 3] Multi-Package Prerelease & Lockfile Serialization")
  println("-----------------------------------------------------------------")

  reg = p2p_registry_new("pkg_node", "127.0.0.1", 9100)

  @! Publish 4 versions: 1.0.0-alpha, 1.0.0-beta.1, 1.0.0-rc.1, 1.0.0
  p2p_publish_package(reg, "maya-tensor", "1.0.0-alpha", "edition=\"2026\"", "fn tensor_a() {}", "k1", "s1")
  p2p_publish_package(reg, "maya-tensor", "1.0.0-beta.1", "edition=\"2026\"", "fn tensor_b() {}", "k1", "s1")
  p2p_publish_package(reg, "maya-tensor", "1.0.0-rc.1", "edition=\"2026\"", "fn tensor_rc() {}", "k1", "s1")
  p2p_publish_package(reg, "maya-tensor", "1.0.0", "edition=\"2026\"", "fn tensor_stable() {}", "k1", "s1")

  recs = p2p_find_package_records(reg, "maya-tensor")

  @! Resolve exact prerelease 1.0.0-beta.1
  r_beta = p2p_resolve_semver(recs, "1.0.0-beta.1")
  ok1 = assert_eq_str(r_beta.version, "1.0.0-beta.1", "Resolves exact 1.0.0-beta.1")

  @! Resolve exact prerelease 1.0.0-rc.1
  r_rc = p2p_resolve_semver(recs, "1.0.0-rc.1")
  ok2 = assert_eq_str(r_rc.version, "1.0.0-rc.1", "Resolves exact 1.0.0-rc.1")

  @! Resolve range >=1.0.0-alpha (should resolve highest: 1.0.0)
  r_gte = p2p_resolve_semver(recs, ">=1.0.0-alpha")
  ok3 = assert_eq_str(r_gte.version, "1.0.0", "Resolves highest stable 1.0.0")

  @! Lockfile generation and deterministic parsing
  lock_entry = p2p_generate_lockfile_entry(r_beta, "", "")
  ok4 = assert_true(str_index_of(lock_entry, "version = \"1.0.0-beta.1\"") >= 0, "Lockfile contains exact prerelease version")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    println("  [PASS] Multi-Package Prerelease & Lockfile Serialization")
    return 1
  @else
    println("  [FAIL] Multi-Package Prerelease Resolution Failed")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔬 MAYA P2P REGISTRY ITERATION 2 DEEP ADVERSARIAL SUITE")
  println("=================================================================")

  t1 = test_extended_semver()
  t2 = test_dht_extreme_routing()
  t3 = test_multi_package_prerelease_resolution()

  total = t1 + t2 + t3
  @if total == 3
    println("=================================================================")
    println("✅ ALL ITERATION 2 ADVERSARIAL TESTS PASSED (3/3)")
    println("=================================================================")
    return 0
  @else
    println("=================================================================")
    println("❌ FAILURES DETECTED IN ITERATION 2 SUITE")
    println("=================================================================")
    return 1
  @end
@end
