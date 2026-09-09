// Test 45: HTTP Framework — Lipi 2.0 Global Standard

struct Context
    method
    path
    status
    body

fn ctx_new method path
    c = Context()
    c.method = method
    c.path = path
    c.status = 200
    c.body = ""
    return c

fn log_request c
    say "[LOG] " + c.method + " " + c.path
    return 1

fn auth_check c
    if c.path == "/admin"
        c.status = 403
        c.body = "Forbidden"
    return c

fn route_request c
    if c.path == "/"
        c.body = "Welcome to Lipi!"
    elif c.path == "/api"
        c.body = "{\"api\":\"v2\"}"
    else
        c.status = 404
        c.body = "Not Found"
    return c

fn handle_request method path
    c = ctx_new(method, path)
    log_request(c)
    c = auth_check(c)
    if c.status != 200
        say c.status + " " + c.body
        return c
    c = route_request(c)
    say c.status + " " + c.body
    return c

say "=== HTTP Framework ==="
handle_request("GET", "/")
handle_request("GET", "/api")
handle_request("GET", "/admin")
handle_request("GET", "/unknown")

say "PASS: Test 45 HTTP Framework"
