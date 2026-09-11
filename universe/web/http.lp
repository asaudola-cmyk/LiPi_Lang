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

// WHY: Extracts HTTP method (e.g. "GET", "POST", "PUT", "DELETE") from the request line.
// Reads characters up to the first ASCII space (0x20 = 32). Handles leading whitespace
// and gracefully falls back to METHOD_GET if request string is empty or ill-formed.
fn http_method request
    rlen = len(request)
    if rlen == 0
        return METHOD_GET

    // Skip leading whitespace if present
    start = 0
    while start < rlen
        c = char_at(request, start)
        if c != " " and c != "\r" and c != "\n" and c != "\t"
            break
        start = start + 1

    if start >= rlen
        return METHOD_GET

    // Extract method characters until next delimiter (space, \r, \n, \t)
    method_str = ""
    i = start
    while i < rlen
        c = char_at(request, i)
        if c == " " or c == "\r" or c == "\n" or c == "\t"
            break
        method_str = method_str + c
        i = i + 1

    if len(method_str) == 0
        return METHOD_GET
    return method_str

// WHY: Extracts the request URI path (e.g. "/", "/api/v1/users", "/index.html") from HTTP request line.
// Locates the first space separating method from URI, then extracts up to the second space (or \r, \n).
// Defaults safely to "/" if the path cannot be resolved.
fn http_path request
    rlen = len(request)
    if rlen == 0
        return "/"

    // 1. Locate first space
    i = 0
    while i < rlen
        if char_at(request, i) == " "
            break
        i = i + 1

    // Skip spaces between method and URI
    while i < rlen
        if char_at(request, i) != " "
            break
        i = i + 1

    if i >= rlen
        return "/"

    // 2. Extract path until next space, carriage return, newline, or tab
    path_str = ""
    while i < rlen
        c = char_at(request, i)
        if c == " " or c == "\r" or c == "\n" or c == "\t"
            break
        path_str = path_str + c
        i = i + 1

    if len(path_str) == 0
        return "/"
    return path_str

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
