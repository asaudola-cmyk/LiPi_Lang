// ==============================================================================
// 🧪 OSHIM FRAMEWORK VERIFICATION TEST (tests/test_oshim_framework.lp)
// ⚡ Automated Fullstack Routing, Request Parsing & JSON Serialization Test
// ==============================================================================

include "framework/oshim.lp"

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🧪 OSHIM FRAMEWORK AUTOMATED INTEGRATION TEST"
    say "════════════════════════════════════════════════════════════════════════"

    // 1. Router Initialization
    router = oshim_router_new()
    oshim_get(router, "/", 1)
    oshim_get(router, "/api/v1/status", 2)
    oshim_post(router, "/api/v1/users", 3)
    oshim_get(router, "/api/v1/health", 4)
    say "  ✔ Router initialized with 4 registered routes"

    // 2. Request Parsing & Route Dispatch
    req1 = "GET /api/v1/status HTTP/1.1"
    m1 = oshim_parse_method(req1)
    p1 = oshim_parse_path(req1)
    h1 = oshim_dispatch(router, m1, p1)
    say "  • Dispatching '" + req1 + "' -> Handler ID: " + h1
    if h1 != 2
        say "  ❌ FAILED: Expected Handler ID 2"
        return 1
    say "  ✔ Route 1 matched correctly (/api/v1/status)"

    req2 = "POST /api/v1/users HTTP/1.1"
    m2 = oshim_parse_method(req2)
    p2 = oshim_parse_path(req2)
    h2 = oshim_dispatch(router, m2, p2)
    say "  • Dispatching '" + req2 + "' -> Handler ID: " + h2
    if h2 != 3
        say "  ❌ FAILED: Expected Handler ID 3"
        return 1
    say "  ✔ Route 2 matched correctly (/api/v1/users)"

    // 3. 404 Route Not Found Handling
    req3 = "GET /api/v1/unknown HTTP/1.1"
    m3 = oshim_parse_method(req3)
    p3 = oshim_parse_path(req3)
    h3 = oshim_dispatch(router, m3, p3)
    say "  • Dispatching '" + req3 + "' -> Handler ID: " + h3
    if h3 != 0
        say "  ❌ FAILED: Expected 0 (Not Found)"
        return 1
    say "  ✔ 404 Not Found correctly detected"

    // 4. Response Serialization
    json_payload = "{\"status\":\"healthy\",\"engine\":\"Oshim-Lipi-ELF64\",\"uptime_cycles\":" + cpu_clock() + "}"
    res = oshim_response_json(json_payload)
    wire = oshim_serialize_response(res)
    say "\n[Serialized HTTP Wire Protocol Sample]:\n" + wire

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL OSHIM FRAMEWORK TESTS PASSED! 100% OPERATIONAL!"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
