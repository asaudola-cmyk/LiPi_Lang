// Test 09: Web Framework — Lipi 2.0
// Demonstrates: router pattern, HTTP response builder, struct for routes

struct Route
    path
    method
    status

// Build a text/plain HTTP response string
fn text_response code body
    return "HTTP/1.1 " + code + "\r\nContent-Type: text/plain\r\n\r\n" + body

// Build a JSON HTTP response string
fn json_response code body
    return "HTTP/1.1 " + code + "\r\nContent-Type: application/json\r\n\r\n" + body

// Match a path+method pair and return the appropriate response
fn match_route path method
    if path == "/" and method == "GET"
        return text_response "200 OK" "Hello from Lipi!"
    elif path == "/api" and method == "GET"
        return json_response "200 OK" "{\"status\": \"ok\"}"
    elif path == "/health" and method == "GET"
        return json_response "200 OK" "{\"alive\": true}"
    else
        return text_response "404 Not Found" "Not found"

// Simulate several HTTP requests
say match_route "/" "GET"
say match_route "/api" "GET"
say match_route "/health" "GET"
say match_route "/xyz" "GET"

// Record a route struct for logging
r = Route()
r.path = "/api"
r.method = "GET"
r.status = 200
say r.status

say "PASS: Test 09 Web Framework"
