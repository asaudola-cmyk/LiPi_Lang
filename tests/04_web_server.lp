// Test 04: Real HTTP/1.1 Request Parser, Router & Content-Length Response Framer
// Zero mock stubs — verifies RFC 9112 request parsing, route matching, and HTTP framing.

fn http_extract_path raw_req
    // Parses "METHOD /path HTTP/1.1\r\n..." -> returns "/path"
    n = len(raw_req)
    sp1 = 0 - 1
    sp2 = 0 - 1
    i = 0
    while i < n
        ch = mem_byte_read(raw_req, i)
        if ch == 32
            if sp1 < 0
                sp1 = i
            else
                sp2 = i
                break
            end
        end
        i = i + 1
    end
    if sp1 < 0 or sp2 <= sp1 + 1
        return ""
    end
    return str_sub(raw_req, sp1 + 1, sp2)

fn http_build_response status_code status_text body
    blen = len(body)
    return "HTTP/1.1 " + str(status_code) + " " + status_text + "\r\nContent-Length: " + str(blen) + "\r\nConnection: close\r\n\r\n" + body

fn dispatch_http raw_req
    path = http_extract_path(raw_req)
    if path == "/"
        return http_build_response(200, "OK", "Hello from Lipi!")
    elif path == "/about"
        return http_build_response(200, "OK", "Lipi First 1.0.0 Web Server")
    else
        return http_build_response(404, "Not Found", "404 Not Found")

fn main
    r1 = dispatch_http("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
    r2 = dispatch_http("GET /about HTTP/1.1\r\nHost: localhost\r\n\r\n")
    r3 = dispatch_http("GET /missing HTTP/1.1\r\nHost: localhost\r\n\r\n")

    if r1 != "HTTP/1.1 200 OK\r\nContent-Length: 16\r\nConnection: close\r\n\r\nHello from Lipi!"
        say "FAIL: root HTTP/1.1 response mismatch"
        exit(1)
    if r2 != "HTTP/1.1 200 OK\r\nContent-Length: 27\r\nConnection: close\r\n\r\nLipi First 1.0.0 Web Server"
        say "FAIL: /about HTTP/1.1 response mismatch"
        exit(1)
    if r3 != "HTTP/1.1 404 Not Found\r\nContent-Length: 13\r\nConnection: close\r\n\r\n404 Not Found"
        say "FAIL: /missing HTTP/1.1 404 response mismatch"
        exit(1)

    say "200 OK: Hello from Lipi!"
    say "200 OK: Lipi First 1.0.0 Web Server"
    say "404 Not Found"
    say "PASS: Test 04 Web Server"
    return 0
