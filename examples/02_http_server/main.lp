// Lipi 2.0 — HTTP Server Example
// Global Standard | Minimal Syntax
// Shows: functions, structs, routing pattern

include "std/http"
include "std/fmt"

struct Route
    path
    status

fn handle_home req
    return "Welcome to Lipi HTTP Server!"

fn handle_api req
    return "{\"status\": \"ok\", \"version\": \"2.0\"}"

fn handle_404 req
    return "404 — Page Not Found"

fn dispatch path req
    if path == "/"
        return handle_home req
    elif path == "/api"
        return handle_api req
    else
        return handle_404 req

// Demonstrate routing
paths = "/"
say dispatch "/" ""
say dispatch "/api" ""
say dispatch "/unknown" ""

say "HTTP Server ready on port 8080"
