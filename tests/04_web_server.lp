// Test 04: Web Server — Lipi 2.0 Minimal Syntax Demo
// Demonstrates: functions as route handlers, string return values, dispatch pattern

fn handle_root req
    return "200 OK: Hello from Lipi!"

fn handle_about req
    return "200 OK: Lipi 2.0 Web Server"

fn handle_not_found req
    return "404 Not Found"

// Route dispatch — maps paths to handlers
fn dispatch path req
    if path == "/"
        return handle_root req
    elif path == "/about"
        return handle_about req
    else
        return handle_not_found req

// Simulate HTTP requests
result1 = dispatch "/" ""
result2 = dispatch "/about" ""
result3 = dispatch "/unknown" ""

say result1
say result2
say result3

say "PASS: Test 04 Web Server"
