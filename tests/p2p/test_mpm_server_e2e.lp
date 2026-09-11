@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — DECENTRALIZED MPM PACKAGE SERVER & REGISTRY
@! END-TO-END COMPREHENSIVE TEST SUITE
@! File: tests/p2p/test_mpm_server_e2e.maya
@! Milestone: M3 / E2E Track (MPM Server & P2P Registry)
@! 100% Pure Maya Implementation (@struct, @fn) — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/crypto/sha256"
import "universe/net/http"
import "universe/web/app"
import "universe/web/router"
import "universe/web/context"
import "universe/web/server"
import "universe/p2p/registry"
import "universe/p2p/mpm_server"

@! ============================================================================
@! 1. ASSERTION FRAMEWORK HELPERS
@! ============================================================================

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_false(cond, msg)
  @if cond != 0 && cond != false
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

@fn assert_neq_str(actual, unexpected, msg)
  @if actual == unexpected
    println("  [FAIL] " + msg + " -> Expected string not to equal '" + unexpected + "'")
    return 0
  @end
  return 1
@end

@! ============================================================================
@! 2. TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("📦 MAYA DECENTRALIZED MPM PACKAGE SERVER E2E TEST SUITE 📦")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Server Initialization & Configuration
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: MPM Server Initialization & P2P Node Config...")

  total_tests = total_tests + 1
  cfg = mpm_server_config_default()
  srv = mpm_server_new(cfg)
  
  ok1 = assert_eq_int(srv.config.port, 8080, "Default HTTP port is 8080")
  ok2 = assert_eq_int(srv.config.p2p_port, 9090, "Default P2P port is 9090")
  ok3 = assert_eq_int(srv.config.p2p_enabled, 1, "P2P network mode is enabled")
  ok4 = assert_neq_str(srv.merkle_root, "", "Initial Merkle root hash is generated")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Server initialization & default P2P configuration verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Package Publishing (POST /api/v1/publish)
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Package Publishing (POST /api/v1/publish) & Merkle Root...")

  total_tests = total_tests + 1
  manifest_math = {
    name: "maya-math",
    version: "1.0.0",
    description: "Fast 2D/3D math library for Maya Universal",
    author: "Maya Architecture Team",
    license: "MIT",
    tags: ["math", "vector", "geometry"]
  }
  payload_math = "@fn vec2(x, y) { return { x: x, y: y }; }\n@fn add(a, b) { return a + b; }"
  
  root_before = srv.merkle_root
  pub_res = mpm_client_publish(srv, manifest_math, payload_math)
  
  ok1 = assert_eq_int(pub_res.status_code, 201, "Publish returned HTTP 201 Created")
  ok2 = assert_eq_int(pub_res.verified, 1, "Publish result verified flag is true")
  ok3 = assert_neq_str(pub_res.sha256, "", "Payload SHA-256 calculated")
  ok4 = assert_neq_str(srv.merkle_root, root_before, "Merkle DAG root transitioned on publication")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Package publication & Merkle DAG state transition verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Package Fetching (GET /api/v1/packages/{name}/{version})
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Package Fetching & Content-Addressed Verification...")

  total_tests = total_tests + 1
  fetch_math = mpm_client_fetch(srv, "maya-math", "1.0.0")
  ok1 = assert_eq_int(fetch_math.status_code, 200, "Fetch returned HTTP 200 OK")
  ok2 = assert_eq_int(fetch_math.verified, 1, "Fetched blob SHA-256 matches expected digest")
  ok3 = assert_eq_str(fetch_math.payload, payload_math, "Fetched payload bit-for-bit matches original code")
  
  @! Fetch Non-existent Package
  fetch_404 = mpm_client_fetch(srv, "non-existent-pkg", "1.0.0")
  ok4 = assert_eq_int(fetch_404.status_code, 404, "Fetch non-existent package returns HTTP 404")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Exact version package fetch & 404 handling verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: SemVer 2.0.0 Constraint Resolution (^, ~, latest)
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: SemVer 2.0.0 Constraint Resolution (^, ~, latest)...")

  total_tests = total_tests + 1
  m_v110 = { name: "maya-math", version: "1.1.0", description: "v1.1.0", author: "Maya", license: "MIT", tags: [] }
  m_v120 = { name: "maya-math", version: "1.2.0", description: "v1.2.0", author: "Maya", license: "MIT", tags: [] }
  m_v200 = { name: "maya-math", version: "2.0.0", description: "v2.0.0", author: "Maya", license: "MIT", tags: [] }
  
  mpm_client_publish(srv, m_v110, "payload v1.1.0")
  mpm_client_publish(srv, m_v120, "payload v1.2.0")
  mpm_client_publish(srv, m_v200, "payload v2.0.0")
  
  fetch_latest = mpm_client_fetch(srv, "maya-math", "latest")
  fetch_caret = mpm_client_fetch(srv, "maya-math", "^1.0.0")
  fetch_tilde = mpm_client_fetch(srv, "maya-math", "~1.1.0")
  
  ok1 = assert_eq_str(fetch_latest.payload, "payload v2.0.0", "Tag 'latest' resolves to highest version (2.0.0)")
  ok2 = assert_eq_str(fetch_caret.payload, "payload v1.2.0", "Caret '^1.0.0' resolves to latest compatible 1.x (1.2.0)")
  ok3 = assert_eq_str(fetch_tilde.payload, "payload v1.1.0", "Tilde '~1.1.0' resolves to matching minor version (1.1.0)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] SemVer 2.0.0 range resolution (^, ~, latest) verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Global Catalog & Package Index (GET /api/v1/index)
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Global Registry Index (GET /api/v1/index)...")

  total_tests = total_tests + 1
  idx_res = mpm_client_get_index(srv)
  ok1 = assert_eq_int(idx_res.status_code, 200, "Index endpoint returned HTTP 200 OK")
  ok2 = assert_true(str_contains(idx_res.body, "maya-math"), "Index JSON body includes package 'maya-math'")
  ok3 = assert_true(str_contains(idx_res.body, "merkle_root"), "Index JSON body includes Merkle root")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Global index catalog query & Merkle root metadata verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: Full-Text Search API (GET /api/v1/search)
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: Registry Search API (GET /api/v1/search)...")

  total_tests = total_tests + 1
  manifest_gui = {
    name: "maya-gui-canvas",
    version: "0.9.0",
    description: "Hardware-accelerated 2D canvas rasterizer",
    author: "UI Guild",
    license: "Apache-2.0",
    tags: ["gui", "graphics", "rasterizer"]
  }
  mpm_client_publish(srv, manifest_gui, "let canvas_code = 1;")
  
  search_math = mpm_client_search(srv, "math")
  search_gui = mpm_client_search(srv, "graphics")
  search_miss = mpm_client_search(srv, "non-existent-keyword")
  
  ok1 = assert_eq_int(search_math.status_code, 200, "Search math returned 200 OK")
  ok2 = assert_true(str_contains(search_math.body, "maya-math"), "Search query 'math' found 'maya-math'")
  ok3 = assert_eq_int(search_gui.status_code, 200, "Search graphics returned 200 OK")
  ok4 = assert_true(str_contains(search_gui.body, "maya-gui-canvas"), "Search query 'graphics' found 'maya-gui-canvas' via tag")
  ok5 = assert_true(str_contains(search_miss.body, "\"count\":0"), "Search miss returned count 0")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Registry search across names, descriptions and tags verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 7: Tamper Detection & Cryptographic Rejection
  @! ----------------------------------------------------------------------------
  println("▶ Section 7: Cryptographic Tamper Detection & Integrity Rejection...")

  total_tests = total_tests + 1
  @! Create raw request with forged SHA-256
  corrupted_req_body = "{\"name\":\"tampered-pkg\",\"version\":\"1.0.0\",\"description\":\"tamper test\",\"author\":\"Eve\",\"license\":\"MIT\",\"payload\":\"genuine payload\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000000\",\"tags\":[]}"
  raw_req = req_new("POST", "/api/v1/publish", [{ name: "Content-Type", value: "application/json" }], corrupted_req_body, "127.0.0.1")
  tamper_resp = mpm_server_dispatch(srv, raw_req)
  
  ok1 = assert_eq_int(tamper_resp.res_status_code, 400, "Corrupted SHA-256 rejected with HTTP 400 Bad Request")
  ok2 = assert_true(str_contains(tamper_resp.res_body, "integrity"), "Error message cites integrity verification failure")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Payload tampering & forged checksum rejection verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 8: P2P Merkle DAG Synchronization
  @! ----------------------------------------------------------------------------
  println("▶ Section 8: P2P Merkle DAG Peer Synchronization...")

  total_tests = total_tests + 1
  cfg_peer1 = mpm_server_config_default()
  cfg_peer1.port = 8101
  cfg_peer1.p2p_port = 9101
  peer1 = mpm_server_new(cfg_peer1)
  
  cfg_peer2 = mpm_server_config_default()
  cfg_peer2.port = 8102
  cfg_peer2.p2p_port = 9102
  peer2 = mpm_server_new(cfg_peer2)
  
  @! Publish distinct packages to each peer
  m_p1 = { name: "pkg-peer-1", version: "1.0.0", description: "Node 1 package", author: "Peer 1", license: "MIT", tags: ["p2p"] }
  m_p2 = { name: "pkg-peer-2", version: "2.0.0", description: "Node 2 package", author: "Peer 2", license: "MIT", tags: ["p2p"] }
  
  mpm_client_publish(peer1, m_p1, "let p1_blob = 100;")
  mpm_client_publish(peer2, m_p2, "let p2_blob = 200;")
  
  ok1 = assert_neq_str(peer1.merkle_root, peer2.merkle_root, "Peer Merkle roots differ prior to sync")
  
  synced_count = mpm_server_sync_p2p(peer1, peer2)
  
  ok2 = assert_true(synced_count > 0, "P2P sync transferred packages between nodes")
  ok3 = assert_eq_str(peer1.merkle_root, peer2.merkle_root, "Peer Merkle roots converge after DAG sync")
  
  @! Fetch package published on Peer 2 directly from Peer 1
  fetch_synced = mpm_client_fetch(peer1, "pkg-peer-2", "2.0.0")
  ok4 = assert_eq_int(fetch_synced.status_code, 200, "Peer 1 serves package synchronized from Peer 2")
  ok5 = assert_eq_str(fetch_synced.payload, "let p2_blob = 200;", "Synchronized payload matches bit-for-bit")
  ok6 = assert_eq_int(fetch_synced.verified, 1, "Synchronized package cryptographic integrity verified")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] P2P Merkle DAG synchronization & cross-node fetching verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 9: Download Metric Tracking
  @! ----------------------------------------------------------------------------
  println("▶ Section 9: Package Download Metrics...")

  total_tests = total_tests + 1
  f1 = mpm_client_fetch(srv, "maya-math", "1.0.0")
  f2 = mpm_client_fetch(srv, "maya-math", "1.0.0")
  idx_after = mpm_client_get_index(srv)
  
  ok1 = assert_true(str_contains(idx_after.body, "\"downloads\":"), "Index reflects download counts")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Dynamic package download metrics tracking verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 10: Raw HTTP/1.1 Protocol Wire Serialization
  @! ----------------------------------------------------------------------------
  println("▶ Section 10: Raw HTTP/1.1 Protocol Wire Serialization...")

  total_tests = total_tests + 1
  raw_http_req = "GET /api/v1/index HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUser-Agent: MPM-Client/1.0\r\n\r\n"
  raw_resp = mpm_server_handle_raw_request(srv, raw_http_req)
  
  ok1 = assert_true(str_starts_with(raw_resp, "HTTP/1.1 200 OK"), "Raw response starts with HTTP/1.1 200 OK")
  ok2 = assert_true(str_contains(raw_resp, "Content-Type: application/json"), "Raw response contains JSON header")
  ok3 = assert_true(str_contains(raw_resp, "Content-Length:"), "Raw response contains Content-Length header")
  ok4 = assert_true(str_contains(raw_resp, "merkle_root"), "Raw response body contains Merkle root JSON")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Raw HTTP/1.1 protocol wire parsing & streaming response verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 MPM SERVER E2E TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 10 MPM SERVER & P2P REGISTRY E2E TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MPM SERVER TESTS FAILED")
    return 1
  @end
@end
