// Test 18: HTTP Server Pattern — Lipi 2.0
// Demonstrates: middleware chain, request/response structs, routing

struct Request
    method
    path

struct Response
    status
    body

// Build response structs with explicit field setting
fn make_home_resp
    res = Response()
    res.status = 200
    res.body = "Home page"
    return res

fn make_api_resp
    res = Response()
    res.status = 200
    res.body = "API ok"
    return res

fn make_404_resp
    res = Response()
    res.status = 404
    res.body = "Not Found"
    return res

fn make_403_resp
    res = Response()
    res.status = 403
    res.body = "Forbidden"
    return res

// Middleware: log and continue (returns 1)
fn mw_log req
    say "LOG: " + req.method + " " + req.path
    return 1

// Middleware: block /admin paths (returns 0 to deny)
fn mw_auth req
    if req.path == "/admin"
        return 0
    return 1

// Route handler: call no-arg constructors with ()
fn handle req
    if req.path == "/"
        return make_home_resp()
    elif req.path == "/api"
        return make_api_resp()
    else
        return make_404_resp()

// Full request pipeline
fn process method path
    req = Request()
    req.method = method
    req.path = path
    ok = mw_log req
    if ok == 0
        say "Blocked by log"
        return 403
    ok = mw_auth req
    if ok == 0
        res = make_403_resp()
        say res.status
        say res.body
        return 403
    res = handle req
    say res.status
    say res.body
    return res.status

say "--- GET / ---"
process("GET", "/")

say "--- GET /api ---"
process("GET", "/api")

say "--- GET /admin ---"
process("GET", "/admin")

say "--- GET /unknown ---"
process("GET", "/unknown")

say "PASS: Test 18 HTTP Server"
