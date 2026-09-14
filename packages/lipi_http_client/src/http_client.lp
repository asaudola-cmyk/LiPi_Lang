// ==============================================================================
// 👑 LIPI SOVEREIGN HTTP/1.1 CLIENT (packages/lipi_http_client/src/http_client.lp)
// ⚡ Zero Libc | Zero cURL | Direct Kernel Syscalls & Wire Framing
// ==============================================================================
//
// WHY: Enterprise microservices, webhook dispatchers, and mesh proxies require
// lightweight, zero-dependency HTTP client capabilities directly from the runtime.
// lipi_http_client implements RFC 7230 compliant HTTP/1.1 wire framing, response
// status parsing, and header/body demultiplexing directly over Linux socket syscalls.

include "universe/core/memory.lp"

// Syscall constants
HTTP_SYS_READ    = 0
HTTP_SYS_WRITE   = 1
HTTP_SYS_CLOSE   = 3
HTTP_SYS_SOCKET  = 41
HTTP_SYS_CONNECT = 42

// Response Descriptor (48 bytes)
// Offset 0:  status_code (i64, e.g. 200, 404)
// Offset 8:  body_offset (i64)
// Offset 16: body_len (i64)
// Offset 24: raw_buf (i64 pointer)
// Offset 32: raw_len (i64 total response bytes read)
// Offset 40: capacity (i64 buffer capacity)

fn http_parse_status_code buf buf_len
    // RFC 7230: HTTP/1.1 <status_code> <reason>
    // e.g. "HTTP/1.1 200 OK"
    if buf == 0
        return 0
    if buf_len < 12
        return 0

    // Search for first space after HTTP/1.x
    idx = 0
    while idx < buf_len
        if mem_byte_read(buf, idx) == 32 // ' '
            // Next 3 bytes should be digits
            d0 = mem_byte_read(buf, idx + 1) - 48
            d1 = mem_byte_read(buf, idx + 2) - 48
            d2 = mem_byte_read(buf, idx + 3) - 48
            if d0 >= 0
                if d0 <= 9
                    if d1 >= 0
                        if d1 <= 9
                            if d2 >= 0
                                if d2 <= 9
                                    return (d0 * 100) + (d1 * 10) + d2
        idx = idx + 1
    return 0

fn http_find_body_offset buf buf_len
    // Looks for "\r\n\r\n" (13, 10, 13, 10)
    if buf == 0
        return 0
    if buf_len < 4
        return 0

    limit = buf_len - 3
    i = 0
    while i < limit
        if mem_byte_read(buf, i) == 13
            if mem_byte_read(buf, i + 1) == 10
                if mem_byte_read(buf, i + 2) == 13
                    if mem_byte_read(buf, i + 3) == 10
                        return i + 4 // Start of body
        i = i + 1
    return 0

fn http_parse_response raw_buf raw_len
    if raw_buf == 0
        return 0
    if raw_len <= 0
        return 0

    status = http_parse_status_code(raw_buf, raw_len)
    body_off = http_find_body_offset(raw_buf, raw_len)

    body_len = 0
    if body_off > 0
        if raw_len >= body_off
            body_len = raw_len - body_off

    res = sys_alloc(48)
    mem_write(res, 0, status)
    mem_write(res, 8, body_off)
    mem_write(res, 16, body_len)
    mem_write(res, 24, raw_buf)
    mem_write(res, 32, raw_len)
    mem_write(res, 40, raw_len)
    return res

fn http_response_status res
    if res == 0
        return 0
    return mem_read(res, 0)

fn http_response_body_len res
    if res == 0
        return 0
    return mem_read(res, 16)

fn http_response_body_ptr res
    if res == 0
        return 0
    raw_buf = mem_read(res, 24)
    body_off = mem_read(res, 8)
    return raw_buf + body_off

fn http_response_free res
    if res == 0
        return 0
    raw_buf = mem_read(res, 24)
    cap = mem_read(res, 40)
    if raw_buf > 0
        if cap > 0
            mem_free(raw_buf, cap)
    mem_free(res, 48)
    return 0

// Client Networking: connect to IP and execute request
fn http_client_execute ip0 ip1 ip2 ip3 port req_buf req_len
    // Create socket AF_INET (2), SOCK_STREAM (1)
    fd = syscall(HTTP_SYS_SOCKET, 2, 1, 0, 0, 0, 0)
    if fd < 0
        return 0

    // Prepare sockaddr_in (16 bytes)
    addr = sys_alloc(16)
    mem_zero(addr, 16)
    hi_port = port / 256
    lo_port = port % 256
    mem_byte_write(addr, 0, 2) // AF_INET
    mem_byte_write(addr, 2, hi_port)
    mem_byte_write(addr, 3, lo_port)
    mem_byte_write(addr, 4, ip0)
    mem_byte_write(addr, 5, ip1)
    mem_byte_write(addr, 6, ip2)
    mem_byte_write(addr, 7, ip3)

    // Connect
    c_res = syscall(HTTP_SYS_CONNECT, fd, addr, 16, 0, 0, 0)
    mem_free(addr, 16)
    if c_res < 0
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0

    // Send request
    bytes_sent = syscall(HTTP_SYS_WRITE, fd, req_buf, req_len, 0, 0, 0)
    if bytes_sent < 0
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0

    // Read response (up to 8192 bytes)
    resp_buf = sys_alloc(8192)
    mem_zero(resp_buf, 8192)
    bytes_read = syscall(HTTP_SYS_READ, fd, resp_buf, 8192, 0, 0, 0)
    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)

    if bytes_read <= 0
        mem_free(resp_buf, 8192)
        return 0

    // Wrap in response descriptor
    return http_parse_response(resp_buf, bytes_read)
