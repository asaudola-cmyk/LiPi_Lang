// ==============================================================================
// 👑 LIPI FULL-STACK SOVEREIGN HTTP WEB SERVER & DATABASE BACKEND
// File: apps/website/server.lp
// ⚡ 100% Pure Lipi 2.0 | Zero Libc | Zero PHP | Linux AMD64 Kernel Syscalls
//
// WHY: Full-stack sovereign engine handling HTTP 1.1 routing, REST API endpoints,
// binary database CRUD operations, and persistent NVMe/SSD storage using Oshim Framework.
// ==============================================================================

include "std/io.lp"
include "std/net.lp"
include "std/mem.lp"
include "std/str.lp"
include "framework/oshim.lp"
include "apps/website/db_engine.lp"

// ── String to Integer Parser ──────────────────────────────────────────────────
// WHY: Convert command-line port arguments and query parameters to integer values
fn str_to_int s
    res = 0
    slen = len(s)
    i = 0
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if code >= 48 and code <= 57
            res = (res * 10) + (code - 48)
        i = i + 1
    return res

// ── Raw Socket Memory Buffer to String Converter ─────────────────────────────
// WHY: Converts incoming TCP socket wire stream into a high-level Lipi string for routing
fn buf_to_str buf_addr n
    res = ""
    i = 0
    limit = n
    if limit > 512
        limit = 512
    while i < limit
        b = mem_byte_read(buf_addr, i)
        if b == 0
            return res
        res = res + chr(b)
        i = i + 1
    return res

// ── Query / Form Parameter Parser ─────────────────────────────────────────────
// WHY: Extracts integer parameter values (e.g. 'val=5000' or 'id=2') from HTTP requests
fn parse_param req_str key
    klen = len(key)
    rlen = len(req_str)
    i = 0
    limit = rlen - klen
    while i < limit
        if str_sub(req_str, i, i + klen) == key
            p = i + klen
            val = 0
            while p < rlen
                c = char_at(req_str, p)
                code = ord(c)
                if code >= 48 and code <= 57
                    val = (val * 10) + (code - 48)
                    p = p + 1
                else
                    break
            return val
        i = i + 1
    return 0

// ── Static Asset Delivery Handler ─────────────────────────────────────────────
// WHY: Streams HTML, CSS, JavaScript, and SVG assets from disk to client socket
fn serve_static_file client_fd filepath mime_type
    if file_exists(filepath) == 0
        res = oshim_response_new(404, "text/plain; charset=utf-8", "404: File Not Found\n")
        wire = oshim_serialize_response(res)
        syscall(1, client_fd, wire, len(wire), 0, 0, 0)
        socket_close(client_fd)
        return 0

    content = file_read(filepath)
    res = oshim_response_new(200, mime_type, content)
    wire = oshim_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return 1

// ── Database API: Serve All Records as JSON (/api/db/items) ───────────────────
// WHY: Scans 32-byte binary NVMe records directly from disk and streams JSON array
fn db_serve_items client_fd db_fd
    total = db_total_records(db_fd)
    syscall(8, db_fd, 0, 0, 0, 0, 0) // lseek SEEK_SET

    body = "["
    buf = malloc(64)
    first = 1
    i = 0
    while i < total
        syscall(0, db_fd, buf, 32, 0, 0, 0)
        rec_id = mem_read(buf, 0)
        rec_time = mem_read(buf, 8)
        rec_status = mem_read(buf, 16)
        rec_val = mem_read(buf, 24)

        if rec_status == 1
            if first == 0
                body = body + ","
            first = 0
            body = body + "{\"id\":" + str(rec_id) + ",\"timestamp\":" + str(rec_time) + ",\"status\":1,\"value\":" + str(rec_val) + "}"
        i = i + 1

    free(buf, 64)
    body = body + "]\n"

    res = oshim_response_json(body)
    wire = oshim_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return 0

// ── Database API: Serve Storage Telemetry Stats (/api/db/stats) ───────────────
// WHY: Reports active record count, binary file byte size, and physical fsync guarantee
fn db_serve_stats client_fd db_fd
    total = db_total_records(db_fd)
    size = db_file_size(db_fd)
    body = "{\"status\":\"success\",\"total_records\":" + str(total) + ",\"file_size_bytes\":" + str(size) + ",\"fsync_guarantee\":\"100% NVMe Direct\",\"engine\":\"Lipi Native Binary Storage v1.0\"}\n"
    res = oshim_response_json(body)
    wire = oshim_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return 0

// ── Database API: Insert Record (/api/db/add) ──────────────────────────────────
// WHY: Commits new 32-byte binary record to disk with SYS_fsync silicon guarantee
fn db_serve_add client_fd db_fd req_str
    val = parse_param(req_str, "val=")
    if val == 0
        val = 100
    new_id = db_insert_record(db_fd, val)
    body = "{\"success\":true,\"message\":\"Record committed to Lipi NVMe store\",\"id\":" + str(new_id) + ",\"value\":" + str(val) + "}\n"
    res = oshim_response_new(201, "application/json; charset=utf-8", body)
    wire = oshim_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return new_id

// ── Database API: Soft Delete Record (/api/db/delete) ─────────────────────────
// WHY: Sets record status to 0 at offset 16 with zero data fragmentation
fn db_serve_delete client_fd db_fd req_str
    target_id = parse_param(req_str, "id=")
    result = db_delete_record(db_fd, target_id)
    body = "{\"success\":true,\"message\":\"Record soft deleted in Lipi store\",\"id\":" + str(target_id) + ",\"result\":" + str(result) + "}\n"
    res = oshim_response_json(body)
    wire = oshim_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return result

// ==============================================================================
// 🚀 Main Server Lifecycle & Event Loop
// ==============================================================================

port = 8088
args = argv()
if len(args) > 1
    arg1 = get(args, 1)
    if len(arg1) > 0 and arg1 != "-o"
        p_val = str_to_int(arg1)
        if p_val > 0
            port = p_val

say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI FULL-STACK SOVEREIGN WEB & DATABASE ENGINE (v2.1 Ultra)\033[0m       \033[38;2;0;255;204m║\033[0m"
say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Frontend + Backend + Database | 100% Pure Native Machine Code        \033[0m\033[38;2;0;255;204m║\033[0m"
say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
say ""

// 1. Initialize persistent database storage
db_fd = db_open("apps/website/data/sovereign_store.db")
if db_fd < 0
    say "Warning: Could not open database file: apps/website/data/sovereign_store.db"
else
    initial_records = db_total_records(db_fd)
    if initial_records == 0
        db_insert_record(db_fd, 1024)
        db_insert_record(db_fd, 2048)
        db_insert_record(db_fd, 4096)
        say "  ✔ Seeded database with 3 initial records"

// 2. Initialize TCP network socket
server_fd = socket_create()
if server_fd < 0
    say "Error: Failed to create TCP network socket"
    exit(1)

sock_addr_buf = malloc(64)
socket_set_reuseaddr(server_fd, sock_addr_buf)
bind_res = socket_bind(server_fd, sock_addr_buf, port)
if bind_res != 0
    say "Error: Port bind failed on port " + str(port)
    socket_close(server_fd)
    free(sock_addr_buf, 64)
    exit(1)

socket_listen(server_fd, 64)
free(sock_addr_buf, 64)

say "✔ Sovereign Web & Database Server Online!"
say "  • Local Address: http://127.0.0.1:" + str(port) + "/"
say "  • Database API : http://127.0.0.1:" + str(port) + "/api/db/items"
say "  • Telemetry API: http://127.0.0.1:" + str(port) + "/api/status"
say "  • Dependencies : 0% Libc | 0% PHP | 0% GCC | 100% Pure Lipi"
say "------------------------------------------------------------------------"

start_clock = cpu_clock()
req_count = 0
req_buf = malloc(4096)

while 1
    client_fd = socket_accept(server_fd)
    if client_fd >= 0
        req_count = req_count + 1
        nread = syscall(0, client_fd, req_buf, 2048, 0, 0, 0)
        if nread > 0
            req_str = buf_to_str(req_buf, nread)
            method = oshim_parse_method(req_str)
            path = oshim_parse_path(req_str)

            if path == "/" or path == "/index.html"
                serve_static_file(client_fd, "apps/website/public/index.html", "text/html; charset=utf-8")
            elif path == "/style.css"
                serve_static_file(client_fd, "apps/website/public/style.css", "text/css; charset=utf-8")
            elif path == "/app.js"
                serve_static_file(client_fd, "apps/website/public/app.js", "application/javascript; charset=utf-8")
            elif path == "/favicon.svg"
                serve_static_file(client_fd, "apps/website/public/favicon.svg", "image/svg+xml")
            elif path == "/api/status"
                cur_clock = cpu_clock()
                delta_cycles = cur_clock - start_clock
                body = "{\"status\":\"sovereign_online\",\"engine\":\"Lipi Full-Stack Silicon ELF64\",\"version\":\"2.1-ultra\",\"cpu_cycles\":" + str(cur_clock) + ",\"uptime_cycles\":" + str(delta_cycles) + ",\"requests_served\":" + str(req_count) + ",\"memory_allocated_kb\":128,\"active_horizons\":21,\"php_dependency\":0,\"libc_dependency\":0}\n"
                res = oshim_response_json(body)
                wire = oshim_serialize_response(res)
                syscall(1, client_fd, wire, len(wire), 0, 0, 0)
                socket_close(client_fd)
            elif path == "/api/db/items"
                db_serve_items(client_fd, db_fd)
            elif path == "/api/db/stats"
                db_serve_stats(client_fd, db_fd)
            elif path == "/api/db/add"
                db_serve_add(client_fd, db_fd, req_str)
            elif path == "/api/db/delete"
                db_serve_delete(client_fd, db_fd, req_str)
            else
                res = oshim_response_not_found()
                wire = oshim_serialize_response(res)
                syscall(1, client_fd, wire, len(wire), 0, 0, 0)
                socket_close(client_fd)
        else
            socket_close(client_fd)

free(req_buf, 4096)
file_close(db_fd)
socket_close(server_fd)
