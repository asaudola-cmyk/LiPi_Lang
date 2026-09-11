@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — PURE MAYA MPM CLI TEST SUITE
@! File: tests/pkg/test_mpm_pure_cli.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/crypto/sha256"
import "universe/p2p/registry"
import "universe/p2p/mpm_server"
import "universe/pkg/mpm_cli"

@fn assert_true(cond, msg)
  @! WHY: Validates boolean condition with safe string concatenation error logging.
  @if cond == 0 || cond == false
    err = str_concat("  [FAIL] Assertion failed: ", msg)
    println(err)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @! WHY: Validates integer equality using to_str and str_concat with zero pointer bugs.
  @if actual != expected
    err = str_concat("  [FAIL] ", msg)
    err = str_concat(err, " -> Expected ")
    err = str_concat(err, to_str(expected))
    err = str_concat(err, ", got ")
    err = str_concat(err, to_str(actual))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("📦 MAYA PURE MPM CLI & DEPENDENCY SOLVER TEST SUITE 📦")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Manifest Initialization (mpm init)
  println("▶ Section 1: Project Initialization & Manifest Generator (mpm init)...")
  total_tests = total_tests + 1
  init_res = mpm_cmd_init("super-math", "1.0.0", "Fast Math Library", "Pythagoras", "MIT")
  ok1 = assert_eq_int(init_res.success, 1, "Init succeeded")
  ok2 = assert_true(str_contains(init_res.output, "\"name\": \"super-math\""), "Contains name")
  ok3 = assert_true(str_contains(init_res.output, "\"version\": \"1.0.0\""), "Contains version")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Manifest generation & JSON formatting verified")
  @end

  @! SECTION 2: Dependency Addition (mpm add)
  println("▶ Section 2: Adding Dependency to Manifest (mpm add)...")
  total_tests = total_tests + 1
  add_res = mpm_cmd_add(init_res.output, "maya-tensor", "^2.1.0")
  ok1 = assert_eq_int(add_res.success, 1, "Add dependency succeeded")
  ok2 = assert_true(str_contains(add_res.output, "\"maya-tensor\": \"^2.1.0\""), "Contains dependency entry")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Dependency addition & JSON serialization verified")
  @end

  @! SECTION 3: Dependency Resolution & Lockfile Generation (mpm install)
  println("▶ Section 3: Dependency Solver & Deterministic Lockfile (mpm install)...")
  total_tests = total_tests + 1
  cfg = mpm_server_config_default()
  srv = mpm_server_new(cfg)
  
  install_res = mpm_cmd_install(add_res.output, srv)
  ok1 = assert_eq_int(install_res.success, 1, "Install succeeded")
  ok2 = assert_true(str_contains(install_res.output, "\"lockfile_version\": 1"), "Contains lockfile version")
  ok3 = assert_true(str_contains(install_res.output, "\"name\": \"maya-tensor\""), "Contains locked package")
  ok4 = assert_true(str_contains(install_res.output, "sha256:"), "Contains content address CID")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Dependency graph resolution & lockfile verified")
  @end

  @! SECTION 4: Lockfile Verification (mpm_lockfile_verify)
  println("▶ Section 4: Lockfile Cryptographic Verification (mpm_lockfile_verify)...")
  total_tests = total_tests + 1
  m_parsed = mpm_manifest_parse_json(add_res.output)
  m_resolved = mpm_resolve_dependency_tree(m_parsed, srv)
  lf = mpm_lockfile_create(m_parsed, m_resolved)
  verify_ok = mpm_lockfile_verify(lf, m_parsed)
  ok1 = assert_eq_int(verify_ok, 1, "Lockfile root manifest hash matches parsed manifest")

  @! Verify tamper detection / out-of-date manifest detection
  m_tampered = mpm_manifest_add_dep(m_parsed, "tampered-pkg", "9.9.9")
  verify_tampered = mpm_lockfile_verify(lf, m_tampered)
  ok2 = assert_eq_int(verify_tampered, 0, "Lockfile verification rejects modified/out-of-date manifest")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Deterministic lockfile verification & tamper detection verified")
  @end

  @! SECTION 5: Package Publication & Live Registry Flow (mpm publish)
  println("▶ Section 5: Publishing Package to Registry (mpm publish)...")
  total_tests = total_tests + 1
  pub_res = mpm_cmd_publish(add_res.output, "let math_kernel = 42;", srv)
  ok1 = assert_eq_int(pub_res.success, 1, "Publish succeeded")
  ok2 = assert_true(str_contains(pub_res.output, "super-math"), "Contains published package name")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Package publish to CAS & P2P registry verified")
  @end

  @! SECTION 6: Registry Query Search (mpm search)
  println("▶ Section 6: Querying Package Registry (mpm search)...")
  total_tests = total_tests + 1
  search_res = mpm_cmd_search(srv, "super-math")
  ok1 = assert_eq_int(search_res.success, 1, "Search succeeded")
  ok2 = assert_true(str_contains(search_res.output, "super-math"), "Found matching published package")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Registry search & query response verified")
  @end

  @! SECTION 7: Custom Script Execution (mpm run)
  println("▶ Section 7: Manifest Script Execution (mpm run)...")
  total_tests = total_tests + 1
  run_res = mpm_cmd_run(init_res.output, "build")
  ok1 = assert_eq_int(run_res.success, 1, "Run build script succeeded")
  ok2 = assert_true(str_contains(run_res.output, "maya build src/main.maya"), "Contains mapped command")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Script execution & command mapping verified")
  @end

  @! SECTION 8: Complete CLI Dispatcher Command Flow
  println("▶ Section 8: CLI Dispatcher Arguments Simulation...")
  total_tests = total_tests + 1
  cli1 = mpm_cli_dispatch(["mpm", "init", "cool-pkg", "0.2.0"], srv)
  cli2 = mpm_cli_dispatch(["mpm", "search", "cool-pkg"], srv)
  ok1 = assert_eq_int(cli1.success, 1, "CLI init dispatch succeeded")
  ok2 = assert_eq_int(cli2.success, 1, "CLI search dispatch succeeded")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] CLI dispatcher argument handling verified")
  @end

  println("=================================================================")
  summary = str_concat("📊 MPM CLI TEST RESULTS: ", to_str(passed_tests))
  summary = str_concat(summary, " / ")
  summary = str_concat(summary, to_str(total_tests))
  summary = str_concat(summary, " passed")
  println(summary)
  println("=================================================================")
  @if passed_tests == total_tests
    win_msg = str_concat("🎉 ALL ", to_str(total_tests))
    win_msg = str_concat(win_msg, " PURE MAYA MPM TESTS PASSED! 🎉")
    println(win_msg)
    return 0
  @else
    println("❌ SOME MPM TESTS FAILED")
    return 1
  @end
@end
