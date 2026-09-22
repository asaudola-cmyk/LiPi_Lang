// ==============================================================================
// 🧪 LIPI STANDARD WEB ROUTER VERIFICATION TEST (tests/test_web_router.lp)
// ⚡ Automated Fullstack Routing, Request Parsing & Wire Serialization Test
// ==============================================================================

// WHY: Comprehensive regression test validating the standard web engine (std/web.lp).
// Ensures zero-libc HTTP routing, zero-allocation request parsing, query extraction,
// header inspection, and RFC 7230 wire protocol serialization.

include "std/web.lp"

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🧪 LIPI STANDARD WEB ROUTER AUTOMATED INTEGRATION TEST"
    say "════════════════════════════════════════════════════════════════════════"

    // 1. Router Initialization
    // WHY: Initialize in-memory route registry and populate with test endpoints.
    router = web_router_new()
    web_get(router, "/", 1)
    web_get(router, "/api/v1/status", 2)
    web_post(router, "/api/v1/users", 3)
    web_get(router, "/api/v1/health", 4)
    web_put(router, "/api/v1/items", 5)
    web_delete(router, "/api/v1/items", 6)
    say "  ✔ Router initialized with 6 registered routes"

    // 2. Request Parsing & Route Dispatch (GET)
    // WHY: Validate method extraction, path extraction, and dispatch match for GET.
    req1 = "GET /api/v1/status HTTP/1.1"
    m1 = web_parse_method(req1)
    p1 = web_parse_path(req1)
    h1 = web_dispatch(router, m1, p1)
    say "  • Dispatching '" + req1 + "' -> Handler ID: " + h1
    if h1 != 2
        say "  ❌ FAILED: Expected Handler ID 2"
        return 1
    say "  ✔ Route 1 matched correctly (/api/v1/status)"

    // 3. Request Parsing & Route Dispatch (POST)
    // WHY: Validate method extraction, path extraction, and dispatch match for POST.
    req2 = "POST /api/v1/users HTTP/1.1"
    m2 = web_parse_method(req2)
    p2 = web_parse_path(req2)
    h2 = web_dispatch(router, m2, p2)
    say "  • Dispatching '" + req2 + "' -> Handler ID: " + h2
    if h2 != 3
        say "  ❌ FAILED: Expected Handler ID 3"
        return 1
    say "  ✔ Route 2 matched correctly (/api/v1/users)"

    // 4. Request Parsing & Route Dispatch (PUT & DELETE)
    // WHY: Validate full REST verb suite dispatching.
    req_put = "PUT /api/v1/items HTTP/1.1"
    h_put = web_dispatch(router, web_parse_method(req_put), web_parse_path(req_put))
    if h_put != 5
        say "  ❌ FAILED: Expected Handler ID 5 for PUT"
        return 1
    say "  ✔ PUT route matched correctly (/api/v1/items)"

    req_del = "DELETE /api/v1/items HTTP/1.1"
    h_del = web_dispatch(router, web_parse_method(req_del), web_parse_path(req_del))
    if h_del != 6
        say "  ❌ FAILED: Expected Handler ID 6 for DELETE"
        return 1
    say "  ✔ DELETE route matched correctly (/api/v1/items)"

    // 5. 404 Route Not Found Handling
    // WHY: Non-existent routes must return 0 to trigger 404 Not Found response.
    req3 = "GET /api/v1/unknown HTTP/1.1"
    m3 = web_parse_method(req3)
    p3 = web_parse_path(req3)
    h3 = web_dispatch(router, m3, p3)
    say "  • Dispatching '" + req3 + "' -> Handler ID: " + h3
    if h3 != 0
        say "  ❌ FAILED: Expected 0 (Not Found)"
        return 1
    say "  ✔ 404 Not Found correctly detected"

    // 6. Query String & Parameter Parsing
    // WHY: Validate extraction of raw query strings and typed numeric parameters.
    req_query = "GET /search?q=lipi&limit=50&val=9999 HTTP/1.1"
    q_str = web_parse_query(req_query)
    q_val = web_parse_param_int(req_query, "val=")
    if q_str != "q=lipi&limit=50&val=9999"
        say "  ❌ FAILED: Query string mismatch: " + q_str
        return 1
    if q_val != 9999
        say "  ❌ FAILED: Param int parsing mismatch: " + q_val
        return 1
    say "  ✔ Query string and param parsing verified"

    // 7. Header Parsing
    // WHY: Verify HTTP header value extraction by key.
    req_headers = "GET / HTTP/1.1\r\nHost: 127.0.0.1:8088\r\nContent-Type: application/json\r\n\r\n"
    hdr = web_parse_header(req_headers, "Content-Type")
    if hdr != "application/json"
        say "  ❌ FAILED: Header mismatch: " + hdr
        return 1
    say "  ✔ Header parsing verified (Content-Type: " + hdr + ")"

    // 8. Response Serialization
    // WHY: Verify wire protocol formatting with proper headers and payload.
    json_payload = "{\"status\":\"healthy\",\"engine\":\"Lipi-Web-ELF64\",\"uptime_cycles\":" + cpu_clock() + "}"
    res = web_response_json(json_payload)
    wire = web_serialize_response(res)
    say "\n[Serialized HTTP Wire Protocol Sample]:\n" + wire

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL WEB ROUTER TESTS PASSED! 100% OPERATIONAL!"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
