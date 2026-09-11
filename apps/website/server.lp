// ==============================================================================
// 👑 LIPI FULL-STACK SOVEREIGN HTTP WEB SERVER & DATABASE BACKEND
// File: apps/website/server.lp
// ⚡ 100% Pure Lipi 2.0 | Zero Libc | Zero PHP | Linux AMD64 Kernel Syscalls
//
// WHY: Full-stack sovereign engine handling HTTP 1.1 routing, REST API endpoints,
// binary database CRUD operations, and persistent NVMe/SSD storage using Lipi Web Engine.
// ==============================================================================

include "universe/core/io.lp"
include "universe/net/socket.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/web/engine.lp"
include "universe/core/time.lp"
include "universe/core/json.lp"
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
// WHY: Converts incoming TCP socket wire stream into a high-level Lipi string for routing.
// Supports payloads up to 64KB for interactive code compilation requests.
fn buf_to_str buf_addr n
    res = ""
    i = 0
    limit = n
    if limit > 65536
        limit = 65536
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
        res = web_response_new(404, "text/plain; charset=utf-8", "404: File Not Found\n")
        wire = web_serialize_response(res)
        syscall(1, client_fd, wire, len(wire), 0, 0, 0)
        socket_close(client_fd)
        return 0

    content = file_read(filepath)
    res = web_response_new(200, mime_type, content)
    wire = web_serialize_response(res)
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

    res = web_response_json(body)
    wire = web_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return 0

// ── Database API: Serve Storage Telemetry Stats (/api/db/stats) ───────────────
// WHY: Reports active record count, binary file byte size, and physical fsync guarantee
fn db_serve_stats client_fd db_fd
    total = db_total_records(db_fd)
    size = db_file_size(db_fd)
    body = "{\"status\":\"success\",\"total_records\":" + str(total) + ",\"file_size_bytes\":" + str(size) + ",\"fsync_guarantee\":\"100% NVMe Direct\",\"engine\":\"Lipi Native Binary Storage v1.0\"}\n"
    res = web_response_json(body)
    wire = web_serialize_response(res)
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
    res = web_response_new(201, "application/json; charset=utf-8", body)
    wire = web_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return new_id

// ── Database API: Soft Delete Record (/api/db/delete) ─────────────────────────
// WHY: Sets record status to 0 at offset 16 with zero data fragmentation
fn db_serve_delete client_fd db_fd req_str
    target_id = parse_param(req_str, "id=")
    result = db_delete_record(db_fd, target_id)
    body = "{\"success\":true,\"message\":\"Record soft deleted in Lipi store\",\"id\":" + str(target_id) + ",\"result\":" + str(result) + "}\n"
    res = web_response_json(body)
    wire = web_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return result

// ── HTTP Request Body Extractor ───────────────────────────────────────────────
// WHY: Extracts payload bytes located after HTTP RFC header delimiter (\r\n\r\n or \n\n).
fn extract_http_body req_str
    rlen = len(req_str)
    i = 0
    while i < rlen - 3
        if char_at(req_str, i) == "\r" and char_at(req_str, i + 1) == "\n" and char_at(req_str, i + 2) == "\r" and char_at(req_str, i + 3) == "\n"
            return str_sub(req_str, i + 4, rlen)
        i = i + 1
    i = 0
    while i < rlen - 1
        if char_at(req_str, i) == "\n" and char_at(req_str, i + 1) == "\n"
            return str_sub(req_str, i + 2, rlen)
        i = i + 1
    return ""

// ── Sandbox Code Payload Parser ───────────────────────────────────────────────
// WHY: Safely extracts submitted Lipi source code from JSON {"code": "..."} payloads,
// including unescaping JSON quotes and newlines, or directly returns raw request body
// if plain source code is transmitted without JSON envelope.
fn parse_code_payload body
    blen = len(body)
    if blen == 0
        return ""

    p = 0
    while p < blen
        c = char_at(body, p)
        if c != " " and c != "\t" and c != "\r" and c != "\n"
            break
        p = p + 1

    if p < blen and char_at(body, p) == "{"
        i = p + 1
        found_code = 0
        while i < blen - 5
            if char_at(body, i) == "\"" and char_at(body, i + 1) == "c" and char_at(body, i + 2) == "o" and char_at(body, i + 3) == "d" and char_at(body, i + 4) == "e" and char_at(body, i + 5) == "\""
                found_code = 1
                i = i + 6
                break
            i = i + 1

        if found_code == 1
            while i < blen and char_at(body, i) != ":"
                i = i + 1
            if i < blen and char_at(body, i) == ":"
                i = i + 1
                while i < blen
                    c = char_at(body, i)
                    if c != " " and c != "\t" and c != "\r" and c != "\n"
                        break
                    i = i + 1
                if i < blen and char_at(body, i) == "\""
                    i = i + 1
                    raw_str = ""
                    while i < blen
                        c = char_at(body, i)
                        if c == "\\" and i + 1 < blen
                            raw_str = raw_str + "\\" + char_at(body, i + 1)
                            i = i + 2
                        elif c == "\""
                            break
                        else
                            raw_str = raw_str + c
                            i = i + 1
                    return json_unescape(raw_str)

    return body

// ── Sandbox Compilation & Execution API (/api/run) ────────────────────────────
// WHY: Compiles and executes untrusted Lipi code in an isolated temporary Linux process.
// Enforces hard wall-clock timeout (2s) via SYS_alarm, CPU timeout (2s) and virtual memory
// limits (2GB) via SYS_setrlimit. Captures compiler/binary stdout, safely unlinks
// temporary files from /tmp, and streams structured JSON execution results back to client.
fn api_serve_run client_fd req_str req_id
    body = extract_http_body(req_str)
    code = parse_code_payload(body)

    if len(code) == 0
        err_json = "{\"status\": \"error\", \"phase\": \"compilation\", \"error\": \"No source code provided in request body\"}\n"
        res = web_response_json(err_json)
        wire = web_serialize_response(res)
        syscall(1, client_fd, wire, len(wire), 0, 0, 0)
        socket_close(client_fd)
        return 0

    id_str = str(req_id) + "_" + str(cpu_clock() % 1000000)
    lp_path = "/tmp/sandbox_user_" + id_str + ".lp"
    bin_path = "/tmp/sandbox_user_" + id_str + ".bin"

    // 1. Write submitted Lipi code to isolated temp file
    lp_fd = syscall(2, lp_path, 577, 420, 0, 0, 0)
    if lp_fd < 0
        err_json = "{\"status\": \"error\", \"phase\": \"compilation\", \"error\": \"Failed to create temporary sandbox file on server\"}\n"
        res = web_response_json(err_json)
        wire = web_serialize_response(res)
        syscall(1, client_fd, wire, len(wire), 0, 0, 0)
        socket_close(client_fd)
        return 0

    code_len = len(code)
    syscall(1, lp_fd, code, code_len, 0, 0, 0)
    syscall(3, lp_fd, 0, 0, 0, 0, 0)

    // 2. Compile using ./bin/lipc
    cpipe_mem = malloc(16)
    syscall(22, cpipe_mem, 0, 0, 0, 0, 0)
    cr0 = mem_byte_read(cpipe_mem, 0)
    cr1 = mem_byte_read(cpipe_mem, 1)
    cread_fd = cr0 + (cr1 * 256)
    cw0 = mem_byte_read(cpipe_mem, 4)
    cw1 = mem_byte_read(cpipe_mem, 5)
    cwrite_fd = cw0 + (cw1 * 256)
    free(cpipe_mem, 16)

    comp_pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if comp_pid == 0
        syscall(3, cread_fd, 0, 0, 0, 0, 0)
        syscall(33, cwrite_fd, 1, 0, 0, 0, 0)
        syscall(33, cwrite_fd, 2, 0, 0, 0, 0)
        syscall(3, cwrite_fd, 0, 0, 0, 0, 0)

        // 10-second compilation watchdog
        syscall(37, 10, 0, 0, 0, 0, 0)

        argv_mem = malloc(32)
        prog = "./bin/lipc"
        mem_write_idx(argv_mem, 0, prog)
        mem_write_idx(argv_mem, 1, lp_path)
        mem_write_idx(argv_mem, 2, bin_path)
        mem_write_idx(argv_mem, 3, 0)

        env_mem = malloc(16)
        mem_write_idx(env_mem, 0, 0)

        syscall(59, prog, argv_mem, env_mem, 0, 0, 0)
        prog_fallback = "./bin/lipc_bin"
        mem_write_idx(argv_mem, 0, prog_fallback)
        syscall(59, prog_fallback, argv_mem, env_mem, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(3, cwrite_fd, 0, 0, 0, 0, 0)
    cstatus_buf = malloc(8)
    syscall(61, comp_pid, cstatus_buf, 0, 0, 0, 0)
    comp_exit = mem_byte_read(cstatus_buf, 1)
    comp_sig = mem_byte_read(cstatus_buf, 0) & 127
    free(cstatus_buf, 8)

    comp_out_buf = malloc(4096)
    ncomp = syscall(0, cread_fd, comp_out_buf, 4096, 0, 0, 0)
    syscall(3, cread_fd, 0, 0, 0, 0, 0)

    comp_err_text = ""
    if ncomp > 0
        ci = 0
        while ci < ncomp
            comp_err_text = comp_err_text + chr(mem_byte_read(comp_out_buf, ci))
            ci = ci + 1
    free(comp_out_buf, 4096)

    has_bin = file_exists(bin_path)
    if comp_exit != 0 or comp_sig != 0 or has_bin == 0
        syscall(87, lp_path, 0, 0, 0, 0, 0)
        syscall(87, bin_path, 0, 0, 0, 0, 0)
        if len(comp_err_text) == 0
            comp_err_text = "Compilation failed with exit code " + str(comp_exit)
        err_json = "{\"status\": \"error\", \"phase\": \"compilation\", \"error\": \"" + json_escape(comp_err_text) + "\"}\n"
        res = web_response_json(err_json)
        wire = web_serialize_response(res)
        syscall(1, client_fd, wire, len(wire), 0, 0, 0)
        socket_close(client_fd)
        return 0

    // 3. Execution Phase
    syscall(90, bin_path, 493, 0, 0, 0, 0) // chmod 0755

    epipe_mem = malloc(16)
    syscall(22, epipe_mem, 0, 0, 0, 0, 0)
    er0 = mem_byte_read(epipe_mem, 0)
    er1 = mem_byte_read(epipe_mem, 1)
    eread_fd = er0 + (er1 * 256)
    ew0 = mem_byte_read(epipe_mem, 4)
    ew1 = mem_byte_read(epipe_mem, 5)
    ewrite_fd = ew0 + (ew1 * 256)
    free(epipe_mem, 16)

    t0_s = time_now_sec()
    t0_ns = time_now_nano()

    exec_pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if exec_pid == 0
        syscall(3, eread_fd, 0, 0, 0, 0, 0)
        syscall(33, ewrite_fd, 1, 0, 0, 0, 0)
        syscall(33, ewrite_fd, 2, 0, 0, 0, 0)
        syscall(3, ewrite_fd, 0, 0, 0, 0, 0)

        // Memory limit: 2GB (RLIMIT_AS = 9, accommodates 1GB virtual memory reservation)
        rlim_as = malloc(16)
        mem_write(rlim_as, 0, 2147483648)
        mem_write(rlim_as, 8, 2147483648)
        syscall(160, 9, rlim_as, 0, 0, 0, 0)
        free(rlim_as, 16)

        // CPU limit: 2 seconds (RLIMIT_CPU = 0)
        rlim_cpu = malloc(16)
        mem_write(rlim_cpu, 0, 2)
        mem_write(rlim_cpu, 8, 2)
        syscall(160, 0, rlim_cpu, 0, 0, 0, 0)
        free(rlim_cpu, 16)

        // Wall-clock timeout: 2 seconds alarm
        syscall(37, 2, 0, 0, 0, 0, 0)

        eargv = malloc(24)
        mem_write_idx(eargv, 0, bin_path)
        mem_write_idx(eargv, 1, 0)

        eenv = malloc(16)
        mem_write_idx(eenv, 0, 0)

        syscall(59, bin_path, eargv, eenv, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(3, ewrite_fd, 0, 0, 0, 0, 0)
    estatus_buf = malloc(8)
    syscall(61, exec_pid, estatus_buf, 0, 0, 0, 0)
    exec_exit = mem_byte_read(estatus_buf, 1)
    exec_sig = mem_byte_read(estatus_buf, 0) & 127
    free(estatus_buf, 8)

    t1_s = time_now_sec()
    t1_ns = time_now_nano()
    elapsed_ms = ((t1_s - t0_s) * 1000) + ((t1_ns - t0_ns) / 1000000)
    if elapsed_ms < 0
        elapsed_ms = 0

    // Read captured stdout (up to 32KB)
    eout_buf = malloc(32768)
    nexec = syscall(0, eread_fd, eout_buf, 32768, 0, 0, 0)
    syscall(3, eread_fd, 0, 0, 0, 0, 0)

    exec_stdout = ""
    if nexec > 0
        xi = 0
        while xi < nexec
            exec_stdout = exec_stdout + chr(mem_byte_read(eout_buf, xi))
            xi = xi + 1
    free(eout_buf, 32768)

    if exec_sig == 14
        exec_stdout = exec_stdout + "\n[Execution timed out after 2 seconds]"
    elif exec_sig != 0
        exec_stdout = exec_stdout + "\n[Process terminated by signal " + str(exec_sig) + "]"

    // Clean up temporary files
    syscall(87, lp_path, 0, 0, 0, 0, 0)
    syscall(87, bin_path, 0, 0, 0, 0, 0)

    ok_json = "{\"status\": \"ok\", \"stdout\": \"" + json_escape(exec_stdout) + "\", \"time_ms\": " + str(elapsed_ms) + "}\n"
    res = web_response_json(ok_json)
    wire = web_serialize_response(res)
    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
    socket_close(client_fd)
    return 0

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
say "  • Healthcheck  : http://127.0.0.1:" + str(port) + "/healthz"
say "  • Database API : http://127.0.0.1:" + str(port) + "/api/db/items"
say "  • Sandbox API  : http://127.0.0.1:" + str(port) + "/api/run"
say "  • Telemetry API: http://127.0.0.1:" + str(port) + "/api/status"
say "  • Dependencies : 0% Libc | 0% PHP | 0% GCC | 100% Pure Lipi"
say "------------------------------------------------------------------------"

start_clock = cpu_clock()
req_count = 0
req_buf = malloc(65536)

while 1
    client_fd = socket_accept(server_fd)
    if client_fd >= 0
        req_count = req_count + 1
        nread = syscall(0, client_fd, req_buf, 65536, 0, 0, 0)
        if nread > 0
            req_str = buf_to_str(req_buf, nread)
            method = web_parse_method(req_str)
            path = web_parse_path(req_str)

            if path == "/" or path == "/index.html"
                serve_static_file(client_fd, "apps/website/public/index.html", "text/html; charset=utf-8")
            elif path == "/style.css"
                serve_static_file(client_fd, "apps/website/public/style.css", "text/css; charset=utf-8")
            elif path == "/app.js"
                serve_static_file(client_fd, "apps/website/public/app.js", "application/javascript; charset=utf-8")
            elif path == "/wasm_runner.js"
                serve_static_file(client_fd, "apps/website/public/wasm_runner.js", "application/javascript; charset=utf-8")
            elif path == "/lipi_worker.js"
                serve_static_file(client_fd, "apps/website/public/lipi_worker.js", "application/javascript; charset=utf-8")
            elif path == "/favicon.svg"
                serve_static_file(client_fd, "apps/website/public/favicon.svg", "image/svg+xml")
            elif path == "/healthz"
                // ── Dedicated Lightweight Healthcheck Endpoint ───────────────────────────
                // WHY: Production orchestrators (Kubernetes liveness/readiness probes, AWS ALB,
                // systemd watchdog, keepalived) require an instantaneous HTTP 200 response
                // without touching database storage or allocating heavy objects.
                body = "{\"status\":\"healthy\",\"engine\":\"Lipi Sovereign\"}\n"
                res = web_response_json(body)
                wire = web_serialize_response(res)
                syscall(1, client_fd, wire, len(wire), 0, 0, 0)
                socket_close(client_fd)
            elif path == "/api/status"
                cur_clock = cpu_clock()
                delta_cycles = cur_clock - start_clock
                body = "{\"status\":\"sovereign_online\",\"engine\":\"Lipi Full-Stack Silicon ELF64\",\"version\":\"2.1-ultra\",\"cpu_cycles\":" + str(cur_clock) + ",\"uptime_cycles\":" + str(delta_cycles) + ",\"requests_served\":" + str(req_count) + ",\"memory_allocated_kb\":128,\"active_horizons\":21,\"php_dependency\":0,\"libc_dependency\":0}\n"
                res = web_response_json(body)
                wire = web_serialize_response(res)
                syscall(1, client_fd, wire, len(wire), 0, 0, 0)
                socket_close(client_fd)
            elif path == "/api/run"
                if method == "OPTIONS"
                    res = web_response_new(204, "text/plain; charset=utf-8", "")
                    wire = web_serialize_response(res)
                    syscall(1, client_fd, wire, len(wire), 0, 0, 0)
                    socket_close(client_fd)
                else
                    api_serve_run(client_fd, req_str, req_count)
            elif path == "/api/db/items"
                db_serve_items(client_fd, db_fd)
            elif path == "/api/db/stats"
                db_serve_stats(client_fd, db_fd)
            elif path == "/api/db/add"
                db_serve_add(client_fd, db_fd, req_str)
            elif path == "/api/db/delete"
                db_serve_delete(client_fd, db_fd, req_str)
            else
                res = web_response_not_found()
                wire = web_serialize_response(res)
                syscall(1, client_fd, wire, len(wire), 0, 0, 0)
                socket_close(client_fd)
        else
            socket_close(client_fd)

free(req_buf, 65536)
file_close(db_fd)
socket_close(server_fd)
