// ==============================================================================
// 🛡️ LIPI SOVEREIGN NETWORK & PROTOCOL ATTACK PENETRATION SUITE (100% Pure Lipi)
// File: benchmarks/security/test_advanced_network_attacks.lp
// ⚡ Zero Python — Tests CRLF response splitting, HTTP smuggling/malformed lines,
//    directory traversal (%2e%2e / backslash), JWT alg:none, and buffer bounds.
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/net/http"
import "aati/lipi_web/context"
import "aati/lipi_web/middleware"
import "aati/lipi_web/auth/jwt"

@fn sec_assert(cond, label)
  @if cond == 0
    println("  ❌ [FAIL] " + label)
    exit(1)
  @end
  println("  ✔ [PASS] " + label)
  return 1
@end

@fn main()
  println("╔════════════════════════════════════════════════════════════════════════╗")
  println("║  🛡️ LIPI SOVEREIGN NETWORK ATTACK & EXPLOIT SUITE (100% Pure Lipi)    ║")
  println("╚════════════════════════════════════════════════════════════════════════╝")

  // 1. CRLF Header Injection / Response Splitting Defense
  res = res_new()
  res_header(res, "X-User", "alice\r\nSet-Cookie: admin=1")
  wire = res_format_http(res)
  sec_assert(contains(wire, "\r\nSet-Cookie: admin=1") == 0, "Attack 1: HTTP CRLF response splitting blocked")

  // 2. Request-Line CRLF Injection Defense in HTTP Client Formatter
  raw_req = http_format_request("GET", "/ok\r\nX-Evil: 1", [], "")
  sec_assert(contains(raw_req, "\r\nX-Evil:") == 0, "Attack 2: HTTP client request-target CRLF blocked")

  // 3. Static Path Traversal (plain .., URL-encoded %2e%2e, Windows backslash)
  mw = middleware_static("/tmp", "/files")
  c1 = http_context_new(req_new("GET", "/files/../../etc/passwd", [], "", "127.0.0.1"), res_new())
  pipeline_run([mw], c1)
  sec_assert(c1.ctx_res.res_status_code == 403, "Attack 3a: Plain '..' path traversal blocked (403)")

  c2 = http_context_new(req_new("GET", "/files/%2e%2e/%2e%2e/etc/shadow", [], "", "127.0.0.1"), res_new())
  pipeline_run([mw], c2)
  sec_assert(c2.ctx_res.res_status_code == 403, "Attack 3b: Percent-encoded '%2e%2e' path traversal blocked (403)")

  c3 = http_context_new(req_new("GET", "/files/..%5csecret", [], "", "127.0.0.1"), res_new())
  pipeline_run([mw], c3)
  sec_assert(c3.ctx_res.res_status_code == 403, "Attack 3c: Encoded backslash '%5c' traversal blocked (403)")

  // 4. Malformed / Binary / Empty HTTP Parser Fuzzing (must never crash)
  p_empty = http_parse_request("")
  p_junk = http_parse_request("\x00\x01\xffMALFORMED_NO_SPACES_NO_CRLF")
  sec_assert(p_empty.method == "GET" && str_len(p_junk.method) > 0, "Attack 4: Malformed & binary HTTP request fuzzing safe")

  // 5. JWT alg:none & Expired Token Rejection
  none_tok = jwt_sign_payload("{\"alg\":\"none\",\"typ\":\"JWT\"}", "{\"sub\":\"root\"}", "k")
  sec_assert(jwt_verify(none_tok, "k") == 0, "Attack 5a: JWT alg:none downgrade rejected")
  exp_tok = jwt_create_token("alice", "lipi", 1000, "k")
  sec_assert(jwt_verify_at(exp_tok, "k", 2000) == 0, "Attack 5b: Expired JWT rejected")

  // 6. XSS HTML Meta-Character Neutralization
  xss = web_html_escape("<img src=x onerror=\"alert('xss')\">")
  sec_assert(contains(xss, "<img") == 0 && contains(xss, "&lt;img") == 1, "Attack 6: XSS payload HTML-escaped")

  println("\n🎉 ALL SOVEREIGN NETWORK SECURITY ATTACK DEFENSES VERIFIED (100% Pure Lipi)!")
  return 0
@end

main()
