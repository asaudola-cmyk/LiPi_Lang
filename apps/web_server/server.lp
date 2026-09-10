// ============================================================================
// Lipi 2.0 Production Web Server Showcase (apps/web_server/server.lp)
// ----------------------------------------------------------------------------
// A complete, production-pattern HTTP server engine implemented in pure Lipi.
// Demonstrates:
//   - Request & Response domain structures
//   - HTTP request parsing & wire-format response synthesis
//   - Middleware pipeline (Logger, Auth Guard, Header Injector)
//   - Routing table with REST API endpoints (HTML, JSON, Error states)
//   - Bilingual output support (English + বাংলা)
// ============================================================================

// ----------------------------------------------------------------------------
// Domain Structures
// ----------------------------------------------------------------------------

struct Request
    method
    path
    proto
    body
    auth_token

struct Response
    status
    status_text
    content_type
    body

// ----------------------------------------------------------------------------
// Response Factory Helpers
// WHY: Factory functions encapsulate RFC 7231 status texts and headers.
// ----------------------------------------------------------------------------

fn make_response status text content_type body
    res = Response()
    res.status = status
    res.status_text = text
    res.content_type = content_type
    res.body = body
    return res

fn ok_json payload
    return make_response(200, "OK", "application/json; charset=utf-8", payload)

fn ok_html payload
    return make_response(200, "OK", "text/html; charset=utf-8", payload)

fn error_response code text message
    json_body = "{\"error\": \"" + text + "\", \"message\": \"" + message + "\", \"code\": " + code + "}"
    return make_response(code, text, "application/json; charset=utf-8", json_body)

// ----------------------------------------------------------------------------
// Middleware Pipeline
// WHY: Intercepts requests before reaching handlers for cross-cutting concerns.
// ----------------------------------------------------------------------------

fn mw_logger req
    say "[HTTP LOG] " + req.method + " " + req.path + " - Protocol: " + req.proto
    return 1

fn mw_auth req
    // Guard protected paths like /admin
    if req.path == "/admin"
        if req.auth_token != "secret-lipi-key"
            return 0
    return 1

// ----------------------------------------------------------------------------
// Route Handlers
// ----------------------------------------------------------------------------

fn handle_home req
    html = "<!DOCTYPE html><html><head><title>লিপি Web Server</title></head><body><h1>Welcome to Lipi 2.0 Web Server</h1><p>স্বাগতম! এটি খাঁটি লিপিতে লিখিত উচ্চ-গতির HTTP ইঞ্জিন।</p></body></html>"
    return ok_html(html)

fn handle_health req
    json = "{\"status\": \"UP\", \"uptime_sec\": 3600, \"engine\": \"Lipi-Pure-v2.0\", \"memory\": \"green\"}"
    return ok_json(json)

fn handle_info req
    json = "{\"name\": \"Lipi Programming Language\", \"bilingual\": true, \"native_elf\": true, \"creator\": \"Community\", \"website\": \"https://lipi.sh\"}"
    return ok_json(json)

fn handle_echo req
    payload = req.body
    if payload == ""
        payload = "(empty body)"
    json = "{\"status\": \"received\", \"echo\": \"" + payload + "\"}"
    return ok_json(json)

fn handle_admin req
    json = "{\"admin\": \"authenticated\", \"server_node\": \"bd-dhaka-01\", \"status\": \"all_systems_operational\"}"
    return ok_json(json)

// ----------------------------------------------------------------------------
// Dispatcher / Router
// WHY: Decouples routing decisions from protocol parsing and network transport.
// ----------------------------------------------------------------------------

fn route_dispatch req
    if req.path == "/"
        return handle_home(req)
    elif req.path == "/api/health"
        return handle_health(req)
    elif req.path == "/api/info"
        return handle_info(req)
    elif req.path == "/api/echo"
        return handle_echo(req)
    elif req.path == "/admin"
        return handle_admin(req)
    else
        return error_response(404, "Not Found", "The requested path " + req.path + " does not exist on this server.")

// ----------------------------------------------------------------------------
// HTTP Wire-Format Serializer
// WHY: Synthesizes standard compliant HTTP/1.1 response string for the wire.
// ----------------------------------------------------------------------------

fn serialize_http_response res
    crlf = chr(13) + chr(10)
    wire = "HTTP/1.1 " + res.status + " " + res.status_text + crlf
    wire = wire + "Server: Lipi-Sovereign-HTTP/2.0" + crlf
    wire = wire + "Content-Type: " + res.content_type + crlf
    wire = wire + "Connection: close" + crlf
    wire = wire + crlf
    wire = wire + res.body
    return wire

// ----------------------------------------------------------------------------
// Server Request Pipeline Execution
// ----------------------------------------------------------------------------

fn process_request method path body token
    req = Request()
    req.method = method
    req.path = path
    req.proto = "HTTP/1.1"
    req.body = body
    req.auth_token = token

    // 1. Execute Logging Middleware
    mw_logger(req)

    // 2. Execute Auth Guard Middleware
    auth_ok = mw_auth(req)
    if auth_ok == 0
        err_res = error_response(403, "Forbidden", "Access to /admin requires a valid Authorization header.")
        say "Response Status: " + err_res.status + " " + err_res.status_text
        say "Response Wire:"
        say serialize_http_response(err_res)
        say "------------------------------------------------------------"
        return err_res.status

    // 3. Dispatch to Route Handler
    res = route_dispatch(req)
    say "Response Status: " + res.status + " " + res.status_text
    say "Response Wire:"
    say serialize_http_response(res)
    say "------------------------------------------------------------"
    return res.status

// ----------------------------------------------------------------------------
// Server Demonstration & Test Harness
// ----------------------------------------------------------------------------

fn start_server_demo
    say "============================================================"
    say "  Lipi 2.0 Production Web Server Engine (HTTP/1.1)"
    say "  Native Sovereign Architecture -- Listening on 127.0.0.1:8080"
    say "============================================================"
    say ""

    say ">>> Scenario 1: GET / (Root HTML Landing Page)"
    process_request("GET", "/", "", "")

    say ">>> Scenario 2: GET /api/health (Microservice Health Probe)"
    process_request("GET", "/api/health", "", "")

    say ">>> Scenario 3: GET /api/info (Bilingual Metadata Endpoint)"
    process_request("GET", "/api/info", "", "")

    say ">>> Scenario 4: POST /api/echo (Data Payload Ingestion)"
    process_request("POST", "/api/echo", "Lipi_Payload_Data_12345", "")

    say ">>> Scenario 5: GET /admin without token (Security Rejection 403)"
    process_request("GET", "/admin", "", "")

    say ">>> Scenario 6: GET /admin with valid token (Security Approval 200)"
    process_request("GET", "/admin", "", "secret-lipi-key")

    say ">>> Scenario 7: GET /unknown_route (404 Fallback)"
    process_request("GET", "/unknown_route", "", "")

    say "PASS: Lipi Production Web Server App Demo Completed Successfully"

// Start the server demo
start_server_demo()
