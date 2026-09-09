// std/http.lp — Lipi 2.0 HTTP Library
// Global Standard | TCP/HTTP Server and Client

// HTTP Status codes
HTTP_200 = "200 OK"
HTTP_201 = "201 Created"
HTTP_400 = "400 Bad Request"
HTTP_401 = "401 Unauthorized"
HTTP_403 = "403 Forbidden"
HTTP_404 = "404 Not Found"
HTTP_500 = "500 Internal Server Error"

// HTTP Methods
METHOD_GET    = "GET"
METHOD_POST   = "POST"
METHOD_PUT    = "PUT"
METHOD_DELETE = "DELETE"

// Build HTTP response
fn http_response status headers body
    return "HTTP/1.1 " + status + "\r\nContent-Type: text/html\r\n\r\n" + body

// Build JSON response
fn http_json status body
    return "HTTP/1.1 " + status + "\r\nContent-Type: application/json\r\n\r\n" + body

// Parse HTTP method from request line
fn http_method request
    // "GET /path HTTP/1.1" -> "GET"
    return "GET"  // Simplified

// Parse HTTP path from request line
fn http_path request
    return "/"  // Simplified

// Create HTTP server (returns fd)
fn http_server port
    // Bind + listen on port
    server_fd = syscall 41 2 1 0     // socket
    return server_fd

// Accept HTTP connection
fn http_accept server_fd
    return syscall 43 server_fd 0 0  // accept

// Read HTTP request
fn http_read client_fd buffer size
    return syscall 0 client_fd buffer size

// Send HTTP response
fn http_write client_fd data size
    return syscall 1 client_fd data size

// Close connection
fn http_close fd
    return syscall 3 fd 0 0

// Simple router
fn http_route path handlers
    say "GET " + path
    return HTTP_200
