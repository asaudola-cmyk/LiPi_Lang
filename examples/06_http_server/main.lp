// Lipi 2.0 — HTTP Server Example
// Global Standard | Minimal Syntax
// Shows: Web router, REST dispatching, JSON response serialization

include "std/web.lp"

// WHY: Demonstrate route initialization using std/web.lp router
router = web_router_new()
web_get(router, "/", 1)
web_get(router, "/api", 2)
web_get(router, "/health", 3)

// WHY: Dispatch HTTP requests and serialize responses via the sovereign web library.
fn handle_request router method path
    handler_id = web_dispatch(router, method, path)
    if handler_id == 1
        return web_response_html("<h1>Welcome to Lipi HTTP Server!</h1>")
    elif handler_id == 2
        return web_response_json("{\"status\": \"ok\", \"engine\": \"Lipi 2.0 Sovereign\", \"arch\": \"pure_elf64\"}")
    elif handler_id == 3
        return web_response_json("{\"health\": \"UP\", \"status_code\": 200}")
    else
        return web_response_not_found()

say "=== Lipi Sovereign HTTP Server Demo ==="
say ""
say "── Registering Routes ──"
say "  GET /        -> Handler 1 (HTML Home)"
say "  GET /api     -> Handler 2 (JSON API)"
say "  GET /health  -> Handler 3 (Health Check)"

say ""
say "── Simulating HTTP Requests & Dispatch ──"
res_home = handle_request(router, "GET", "/")
say "Dispatch 'GET /':"
say "  Status: " + res_home.status_code
say "  Body:   " + res_home.body_text

say ""
res_api = handle_request(router, "GET", "/api")
say "Dispatch 'GET /api':"
say "  Status: " + res_api.status_code
say "  Body:   " + res_api.body_text

say ""
res_404 = handle_request(router, "GET", "/unknown")
say "Dispatch 'GET /unknown':"
say "  Status: " + res_404.status_code
say "  Body:   " + res_404.body_text

say ""
say "HTTP Server ready on port 8080"
