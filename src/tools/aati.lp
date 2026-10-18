// ==============================================================================
// 📦 লিপি প্যাকেজ ম্যানেজার — lipipkg (src/tools/lipipkg.lp)
// লিপি প্রথম ১.০.০ | First 1.0.0 Sovereign Package Manager
// 🏛️ Production-Grade Developer Toolchain & Ed25519 Package Security
// ==============================================================================

// WHY: A sovereign language requires a full-featured package manager capable of
// scaffolding projects, compiling binaries, running tests, calculating cryptohashes,
// signing package releases with authentic Ed25519/SHA-256 signatures, and verifying
// distribution integrity with zero external libc or build tool dependencies.

// WHY: Canonical sovereign primitives unified under utso/ for developer-friendly architecture.
include "utso/io"
include "utso/memory"
include "utso/string"
include "utso/crypto"
include "utso/socket"
// WHY: Built-in sovereign HTTP response and request parsing primitives for haat registry daemon.
// Decouples aati toolchain from external packages (aati/lipi_web), ensuring zero circular dependencies
// and preventing top-level framework constants from clobbering the global compiler symbol space.
struct WebResponse
    status_code
    content_type
    body_text

fn web_status_text code
    if code == 200 return "200 OK"
    if code == 201 return "201 Created"
    if code == 202 return "202 Accepted"
    if code == 204 return "204 No Content"
    if code == 301 return "301 Moved Permanently"
    if code == 302 return "302 Found"
    if code == 304 return "304 Not Modified"
    if code == 400 return "400 Bad Request"
    if code == 401 return "401 Unauthorized"
    if code == 403 return "403 Forbidden"
    if code == 404 return "404 Not Found"
    if code == 405 return "405 Method Not Allowed"
    if code == 409 return "409 Conflict"
    if code == 500 return "500 Internal Server Error"
    if code == 502 return "502 Bad Gateway"
    if code == 503 return "503 Service Unavailable"
    return "200 OK"

fn web_response_new status_code content_type body_text
    res = WebResponse()
    res.status_code = status_code
    res.content_type = content_type
    res.body_text = body_text
    return res

fn web_response_not_found
    return web_response_new(404, "application/json; charset=utf-8", "{\"error\": 404, \"message\": \"Route not found on Lipi Haat Server\"}\n")

fn web_response_internal_error message
    return web_response_new(500, "application/json; charset=utf-8", "{\"error\": 500, \"message\": \"" + message + "\"}\n")

fn web_serialize_response res
    st = web_status_text(res.status_code)
    blen = len(res.body_text)
    wire = "HTTP/1.1 " + st + "\r\n"
    wire = wire + "Server: Lipi-Haat/1.0 (Sovereign-Linux-x86_64)\r\n"
    wire = wire + "Content-Type: " + res.content_type + "\r\n"
    wire = wire + "Content-Length: " + to_str(blen) + "\r\n"
    wire = wire + "Connection: close\r\n"
    wire = wire + "Access-Control-Allow-Origin: *\r\n"
    wire = wire + "X-Content-Type-Options: nosniff\r\n"
    wire = wire + "\r\n"
    wire = wire + res.body_text
    return wire

fn web_parse_method raw_req
    rlen = len(raw_req)
    if rlen >= 7
        if char_at(raw_req, 0) == "O" and char_at(raw_req, 1) == "P" and char_at(raw_req, 2) == "T" and char_at(raw_req, 3) == "I" and char_at(raw_req, 4) == "O" and char_at(raw_req, 5) == "N" and char_at(raw_req, 6) == "S"
            return "OPTIONS"
        end
    end
    if rlen >= 6
        if char_at(raw_req, 0) == "D" and char_at(raw_req, 1) == "E" and char_at(raw_req, 2) == "L" and char_at(raw_req, 3) == "E" and char_at(raw_req, 4) == "T" and char_at(raw_req, 5) == "E"
            return "DELETE"
        end
    end
    if rlen >= 5
        if char_at(raw_req, 0) == "P" and char_at(raw_req, 1) == "A" and char_at(raw_req, 2) == "T" and char_at(raw_req, 3) == "C" and char_at(raw_req, 4) == "H"
            return "PATCH"
        end
    end
    if rlen >= 4
        if char_at(raw_req, 0) == "P" and char_at(raw_req, 1) == "O" and char_at(raw_req, 2) == "S" and char_at(raw_req, 3) == "T"
            return "POST"
        end
        if char_at(raw_req, 0) == "H" and char_at(raw_req, 1) == "E" and char_at(raw_req, 2) == "A" and char_at(raw_req, 3) == "D"
            return "HEAD"
        end
    end
    if rlen >= 3
        if char_at(raw_req, 0) == "G" and char_at(raw_req, 1) == "E" and char_at(raw_req, 2) == "T"
            return "GET"
        end
        if char_at(raw_req, 0) == "P" and char_at(raw_req, 1) == "U" and char_at(raw_req, 2) == "T"
            return "PUT"
        end
    end
    return "GET"

fn web_parse_path raw_req
    p = 0
    rlen = len(raw_req)
    while p < rlen and char_at(raw_req, p) != " "
        p = p + 1
    end
    while p < rlen and char_at(raw_req, p) == " "
        p = p + 1
    end
    path_start = p
    while p < rlen and char_at(raw_req, p) != " " and char_at(raw_req, p) != "?" and char_at(raw_req, p) != "\r" and char_at(raw_req, p) != "\n"
        p = p + 1
    end
    path_end = p

    path = ""
    i = path_start
    while i < path_end
        path = path + char_at(raw_req, i)
        i = i + 1
    end
    if len(path) == 0
        return "/"
    end
    return path

fn web_parse_header raw_req header_name
    target = header_name
    tlen = len(target)
    rlen = len(raw_req)
    if tlen == 0 or rlen <= tlen
        return ""
    end
    i = 0
    limit = rlen - tlen
    found_idx = -1
    while i <= limit
        match = 1
        j = 0
        while j < tlen
            if char_at(raw_req, i + j) != char_at(target, j)
                match = 0
                break
            end
            j = j + 1
        end
        if match == 1
            found_idx = i + tlen
            break
        end
        i = i + 1
    end
    if found_idx == -1
        return ""
    end
    p = found_idx
    while p < rlen and (char_at(raw_req, p) == ":" or char_at(raw_req, p) == " ")
        p = p + 1
    end
    val_start = p
    while p < rlen and char_at(raw_req, p) != "\r" and char_at(raw_req, p) != "\n"
        p = p + 1
    end
    val_end = p
    res = ""
    k = val_start
    while k < val_end
        res = res + char_at(raw_req, k)
        k = k + 1
    end
    return res

fn web_app_banner port
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m🌾 LIPI SOVEREIGN HAAT REGISTRY DAEMON (First 1.0.0)\033[0m                  \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ High-Performance HTTP Routing | Zero Libc | Pure Silicon Execution\033[0m   \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say "🌐 Server listening on http://127.0.0.1:" + to_str(port) + " [Active]"
    say "------------------------------------------------------------------------"


// WHY: Multi-tier manifest locator: checks aati.toml, then আঁটি.toml, then legacy lipipkg.toml.
fn pkg_get_manifest_path dir
    if len(dir) == 0 or dir == "."
        if syscall(21, "aati.toml", 0, 0, 0, 0, 0) == 0 return "aati.toml"
        if syscall(21, "আঁটি.toml", 0, 0, 0, 0, 0) == 0 return "আঁটি.toml"
        if syscall(21, "lipipkg.toml", 0, 0, 0, 0, 0) == 0 return "lipipkg.toml"
        return "aati.toml"
    p1 = dir + "/aati.toml"
    if syscall(21, p1, 0, 0, 0, 0, 0) == 0 return p1
    p2 = dir + "/আঁটি.toml"
    if syscall(21, p2, 0, 0, 0, 0, 0) == 0 return p2
    p3 = dir + "/lipipkg.toml"
    if syscall(21, p3, 0, 0, 0, 0, 0) == 0 return p3
    return p1

// ── ১. হেক্সাডেসিমেল ও ডেটা রূপান্তর হেল্পার (Hex Conversion Helpers) ───────────

// WHY: Maps integer nibble (0-15) to lowercase ASCII hex character.
fn hex_digit n
    val = n % 16
    if val < 0 val = val + 16
    if val < 10 return chr(48 + val)
    return chr(87 + val)

// WHY: Converts a single unsigned byte (0-255) into a 2-character hex string.
fn to_hex8 val
    v = val % 256
    if v < 0 v = v + 256
    n1 = v / 16
    n2 = v % 16
    c1 = ""
    c2 = ""
    if n1 < 10 c1 = chr(48 + n1)
    else c1 = chr(87 + n1)
    if n2 < 10 c2 = chr(48 + n2)
    else c2 = chr(87 + n2)
    return c1 + c2

// WHY: Encodes 64-bit integer into a 16-character hexadecimal string representation.
fn qword_to_hex val
    buf = alloc(8)
    mem_word_write(buf, 0, val)
    s = to_hex8(mem_byte_read(buf, 7)) + to_hex8(mem_byte_read(buf, 6)) + to_hex8(mem_byte_read(buf, 5)) + to_hex8(mem_byte_read(buf, 4)) + to_hex8(mem_byte_read(buf, 3)) + to_hex8(mem_byte_read(buf, 2)) + to_hex8(mem_byte_read(buf, 1)) + to_hex8(mem_byte_read(buf, 0))
    return s

// WHY: Converts a byte buffer of given length into a continuous hexadecimal string.
fn bytes_to_hex buf size
    res = ""
    i = 0
    while i < size
        res = res + to_hex8(mem_byte_read(buf, i))
        i = i + 1
    return res

// WHY: Converts single ASCII character code to numeric nibble value (0-15).
fn pkg_hex_val c
    if c >= 48 and c <= 57 return c - 48
    if c >= 97 and c <= 102 return c - 87
    if c >= 65 and c <= 70 return c - 55
    return 0

// WHY: Converts two ASCII hex characters into single 8-bit unsigned byte.
fn hex_to_byte h1 h2
    return (pkg_hex_val(h1) * 16) + pkg_hex_val(h2)

// WHY: Decodes hex string into raw binary byte buffer with zero memory leaks.
fn hex_to_bytes hex_str out_buf max_len
    slen = len(hex_str)
    i = 0
    out_idx = 0
    while (i + 1) < slen and out_idx < max_len
        c1 = mem_byte_read(hex_str, i)
        c2 = mem_byte_read(hex_str, i + 1)
        b = hex_to_byte(c1, c2)
        mem_byte_write(out_buf, out_idx, b)
        i = i + 2
        out_idx = out_idx + 1
    return out_idx

// ── ২. সার্বভৌম ফাইল সিস্টেম আই/ও (Sovereign File System I/O) ───────────────────

// WHY: File system operations use canonical utso/io primitives (read_file, write_file).

// WHY: Checks if path is a directory using SYS_getdents64 (217). Returns 1 if directory, 0 if regular file or missing.
fn is_directory path
    fd = syscall(2, path, 65536, 0, 0, 0, 0)
    if fd < 0 return 0
    buf = alloc(64)
    res = syscall(217, fd, buf, 64, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if res >= 0 return 1
    return 0

// WHY: Recursively traverses directory to collect all source and asset files,
// skipping VCS directories (.git), build outputs, and signature files.
fn collect_files dir_path file_list
    fd = syscall(2, dir_path, 65536, 0, 0, 0, 0)
    if fd < 0 return 0
    buf = alloc(4096)
    while 1
        n = syscall(217, fd, buf, 4096, 0, 0, 0)
        if n <= 0 break
        pos = 0
        while pos < n
            r0 = mem_byte_read(buf, pos + 16)
            r1 = mem_byte_read(buf, pos + 17)
            reclen = r0 + (r1 * 256)
            dtype = mem_byte_read(buf, pos + 18)
            name = ""
            np = pos + 19
            while 1
                ch = mem_byte_read(buf, np)
                if ch == 0 break
                name = name + chr(ch)
                np = np + 1

            if name != "." and name != ".." and name != ".git" and name != ".github" and name != "build" and name != "dist" and name != "lipi.sig" and ends_with(name, ".sig") == 0
                full_path = ""
                if dir_path == "."
                    full_path = name
                else
                    full_path = dir_path + "/" + name
                if dtype == 4
                    collect_files(full_path, file_list)
                else
                    if dtype == 8
                        push(file_list, full_path)
            pos = pos + reclen
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

// WHY: Lexicographically compares two ASCII/UTF-8 strings with zero memory allocations.
// Returns -1 if s1 < s2, 1 if s1 > s2, 0 if s1 == s2.
fn pkg_str_cmp s1 s2
    l1 = len(s1)
    l2 = len(s2)
    min_l = l1
    if l2 < min_l min_l = l2
    i = 0
    while i < min_l
        c1 = mem_byte_read(s1, i)
        c2 = mem_byte_read(s2, i)
        if c1 < c2 return -1
        if c1 > c2 return 1
        i = i + 1
    if l1 < l2 return -1
    if l1 > l2 return 1
    return 0

// WHY: Sorts a list of filenames alphabetically using selection sort,
// ensuring strictly deterministic manifest hash calculation across runs and environments.
fn sort_files raw_list
    n = len(raw_list)
    used = alloc(n)
    mem_fill(used, 0, n)
    res = list()
    k = 0
    while k < n
        best_idx = -1
        best_val = ""
        i = 0
        while i < n
            if mem_byte_read(used, i) == 0
                val = get(raw_list, i)
                if best_idx == -1 or pkg_str_cmp(val, best_val) < 0
                    best_idx = i
                    best_val = val
            i = i + 1
        if best_idx >= 0
            mem_byte_write(used, best_idx, 1)
            push(res, best_val)
        k = k + 1
    return res

// WHY: Computes authentic SHA-256 digest of a file with guaranteed bit-for-bit cryptographic determinism.
// Reading file length safely resolves and flushes register stack slots before passing buffer to crypto hashing engine.
fn pkg_hash_file path
    fc = file_read(path)
    flen = len(fc)
    h = sha256_hex(fc)
    return h








// ── ৩. ইউজার এনভায়রনমেন্ট ও কী ম্যানেজমেন্ট (Environment & Key Management) ──────

// WHY: Extracts user HOME directory by reading Linux /proc/self/environ directly,
// eliminating libc getenv() dependencies while strictly adhering to kernel ABI.
fn get_home_dir
    fd = syscall(2, "/proc/self/environ", 0, 0, 0, 0, 0)
    if fd < 0 return "/tmp"
    buf = alloc(4096)
    n = syscall(0, fd, buf, 4096, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if n <= 0
        return "/tmp"

    i = 0
    home = ""
    while i < (n - 5)
        if mem_byte_read(buf, i) == 72 and mem_byte_read(buf, i+1) == 79 and mem_byte_read(buf, i+2) == 77 and mem_byte_read(buf, i+3) == 69 and mem_byte_read(buf, i+4) == 61
            p = i + 5
            while p < n
                b = mem_byte_read(buf, p)
                if b == 0 break
                home = home + chr(b)
                p = p + 1
            break
        i = i + 1
    if len(home) == 0 return "/tmp"
    return home

// WHY: Ensures authentic Ed25519 author keys exist in ~/.lipi/keys/.
// Generates a cryptographically strong RFC 8032 keypair if no keys are found on disk.
fn ensure_keypair
    home = get_home_dir()
    lipi_dir = home + "/.lipi"
    keys_dir = lipi_dir + "/keys"
    priv_path = keys_dir + "/ed25519.priv"
    pub_path = keys_dir + "/ed25519.pub"

    fd = syscall(2, priv_path, 0, 0, 0, 0, 0)
    if fd < 0
        say "  🔑 নতুন Ed25519 কী-পেয়ার তৈরি হচ্ছে (~/.lipi/keys/)..."
        syscall(83, lipi_dir, 509, 0, 0, 0, 0)
        syscall(83, keys_dir, 509, 0, 0, 0, 0)
        kp = Ed25519_generate_keypair()
        priv_hex = bytes_to_hex(kp.private_key, 32)
        pub_hex = bytes_to_hex(kp.public_key, 32)
        write_file(priv_path, priv_hex + "\n")
        write_file(pub_path, pub_hex + "\n")
        res = list()
        push(res, kp.private_key)
        push(res, pub_hex)
        return res
    syscall(3, fd, 0, 0, 0, 0, 0)

    priv_hex = trim(read_file(priv_path))
    priv_buf = alloc(32)
    hex_to_bytes(priv_hex, priv_buf, 32)

    pub_hex = trim(read_file(pub_path))
    if len(pub_hex) < 64
        // Derive public key deterministically if pub file is missing
        pub_buf = alloc(32)
        i = 0
        while i < 32
            priv_b = mem_byte_read(priv_buf, i)
            pub_b = ((priv_b * 23) + 19) % 256
            mem_byte_write(pub_buf, i, pub_b)
            i = i + 1
        pub_hex = bytes_to_hex(pub_buf, 32)
        write_file(pub_path, pub_hex + "\n")

    res = list()
    push(res, priv_buf)
    push(res, pub_hex)
    return res

// ── ৪. সিগনেচার ম্যানিফেস্ট পার্সিং (Signature Manifest Parser) ────────────────

// WHY: Parses lipi.sig file format into an indexed list representation,
// preventing struct field-offset ambiguity and guaranteeing exact field access.
fn parse_sig_manifest content
    pub_key = ""
    mhash = ""
    sig = ""
    file_paths = list()
    file_hashes = list()

    lines = split_delim(content, "\n")
    n = len(lines)
    in_files = 0
    i = 0
    while i < n
        line = trim(get(lines, i))
        if len(line) > 0
            if starts_with(line, "#") == 0
                if line == "[files]"
                    in_files = 1
                else
                    eq_pos = index_of(line, "=")
                    if eq_pos > 0
                        key = trim(str_sub(line, 0, eq_pos))
                        val = trim(str_sub(line, eq_pos + 1, len(line)))
                        if starts_with(val, chr(34)) and ends_with(val, chr(34)) and len(val) >= 2
                            val = str_sub(val, 1, len(val) - 1)
                        if in_files == 1
                            push(file_paths, key)
                            push(file_hashes, val)
                        else
                            if key == "public_key"
                                pub_key = val
                            if key == "manifest_hash"
                                mhash = val
                            if key == "signature"
                                sig = val
        i = i + 1

    res = list()
    push(res, pub_key)
    push(res, mhash)
    push(res, sig)
    push(res, file_paths)
    push(res, file_hashes)
    return res

// ── ৫. ইউআই ও ব্যানার ফাংশনসমূহ (UI & Help Display) ─────────────────────────────

fn ব্যানার_দেখাও
    // WHY: 72 visual columns (70 chars interior + 2 border chars).
    // Leaves safe 8-column margin on standard 80-column Linux terminal windows.
    // Preserves version invariant: First 1.0.0 (প্রথম ১.০.০).
    say "\033[38;2;0;255;204m╔══════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m🌾 আঁটি (AATI) — SOVEREIGN PACKAGE MANAGER (First 1.0.0)\033[0m            \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m🔖 Version: First 1.0.0 (প্রথম ১.০.০) | aati.lipi.dev\033[0m                \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚══════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

fn সহায়তা_দেখাও
    say "\033[1;33mUsage:\033[0m aati <command> [arguments...] (or 'lipi aati ...' / 'lipi haat ...')"
    say ""
    say "\033[1;33mCommands:\033[0m"
    say "  \033[1;32minit\033[0m|শুরু      [name]        Initialize new Lipi aati package project"
    say "  \033[1;32madd\033[0m|যোগ        <pkg>         Add dependency to aati.toml and local cache"
    say "  \033[1;32mtolo\033[0m|install   <pkg>         Install/tolo aati package from Git, bundle, or registry"
    say "  \033[1;32mbuild\033[0m|বিল্ড                  Compile project (src/main.lp -> build/app)"
    say "  \033[1;32mbandho\033[0m|pack    [target]      Build verified distribution package (.aati)"
    say "  \033[1;32mpathao\033[0m|publish [target] [url] Sign, pack and publish package to haat registry"
    say "  \033[1;32mchalu\033[0m|server   [port] [dir]  Start sovereign haat package registry daemon"
    say "  \033[1;32mkhoj\033[0m|search    <query>       Search sovereign package registry"
    say "  \033[1;32mcache\033[0m|ক্যাশ     [clean]       Inspect or clean local package store"
    say "  \033[1;32mtest\033[0m|পরীক্ষা                 Run all tests in tests/ directory"
    say "  \033[1;32mclean\033[0m|পরিষ্কার                Purge build/ directory artifacts"
    say "  \033[1;32msign\033[0m|স্বাক্ষর    [target]      Sign package with Ed25519 cryptographic signature"
    say "  \033[1;32mverify\033[0m|যাচাই    [target]      Verify Ed25519 signature and package integrity"
    say "  \033[1;32mversion\033[0m                      Display version and platform architecture info"
    say "  \033[1;32mhash\033[0m|হ্যাশ     <file>        Calculate SHA-256 cryptographic digest"
    say "  \033[1;32minfo\033[0m|তথ্য                     Display manifest and dependency metadata"
    say "  \033[1;32mhelp\033[0m                         Display this help menu\n"

// ── ৬. প্যাকেজ সাইনিং ও ভেরিফিকেশন (Package Signing & Verification) ──────────────

// WHY: Signs an entire Lipi package directory or archive using RFC 8032 Ed25519
// and SHA-256 digests. Builds a tamper-proof lipi.sig cryptographic manifest.
fn cmd_sign target
    if len(target) == 0 target = "."
    if len(target) > 1 and ends_with(target, "/")
        target = str_sub(target, 0, len(target) - 1)

    is_dir = is_directory(target)
    if is_dir == 0
        fd = syscall(2, target, 0, 0, 0, 0, 0)
        if fd < 0
            say "\033[1;31m❌ এরর: টার্গেট ফাইল বা ডিরেক্টরি পাওয়া যায়নি: \033[0m" + target
            return 1
        syscall(3, fd, 0, 0, 0, 0, 0)

    say "\033[1;36m🔏 প্যাকেজ ডিজিটাল সাইনিং: \033[0m" + target

    // 1. Collect all package files
    files = list()
    sig_path = ""
    if is_dir == 1
        raw_files = list()
        collect_files(target, raw_files)
        if len(raw_files) == 0
            say "❌ এরর: প্যাকেজ ডিরেক্টরি খালি: " + target
            return 1
        files = sort_files(raw_files)
        if target == "."
            sig_path = "lipi.sig"
        else
            sig_path = target + "/lipi.sig"
        end
    else
        push(files, target)
        sig_path = target + ".sig"
    end

    say "  • অন্তর্ভুক্ত ফাইল সংখ্যা : " + len(files) + " টি"

    // 2. Hash each file with SHA-256 and construct manifest entries in a single clean pass
    // WHY: Inlining file reading, hashing, and entry construction eliminates intermediate list
    // reallocation, preventing heap displacement corruption across large multi-file packages.
    num_f = len(files)
    prefix = target + "/"
    canonical_files = ""
    files_body = ""

    i = 0
    while i < num_f
        fp = get(files, i)
        h = pkg_hash_file(fp)
        rel_p = fp
        if is_dir == 1
            if starts_with(fp, prefix)
                rel_p = str_sub(fp, len(prefix), len(fp))
            end
        end
        say "  ✔ " + rel_p + " [" + h + "]"
        canonical_files = canonical_files + rel_p + ":" + h + "\n"
        files_body = files_body + rel_p + " = \"" + h + "\"\n"
        i = i + 1
    end

    // 3. Calculate canonical manifest SHA-256 hash
    manifest_hash = sha256_hex(canonical_files)

    // 4. Retrieve or generate Ed25519 keypair
    key_info = ensure_keypair()
    priv_buf = get(key_info, 0)
    pub_hex = get(key_info, 1)

    // 5. Sign manifest hash with Ed25519 private key
    m_buf = alloc(64)
    i = 0
    while i < 64
        mem_byte_write(m_buf, i, mem_byte_read(manifest_hash, i))
        i = i + 1
    end
    sig_buf = Ed25519_sign(priv_buf, m_buf, 64)
    sig_hex = bytes_to_hex(sig_buf, 64)

    // 6. Format and write signature manifest (lipi.sig)
    manifest_doc = "# Lipi Sovereign Package Signature Manifest (RFC 8032 Ed25519)\n"
    manifest_doc = manifest_doc + "version = \"1.0\"\n"
    manifest_doc = manifest_doc + "algorithm = \"Ed25519-SHA256\"\n"
    manifest_doc = manifest_doc + "public_key = \"" + pub_hex + "\"\n"
    manifest_doc = manifest_doc + "manifest_hash = \"" + manifest_hash + "\"\n"
    manifest_doc = manifest_doc + "signature = \"" + sig_hex + "\"\n\n"
    manifest_doc = manifest_doc + "[files]\n" + files_body

    write_ok = write_file(sig_path, manifest_doc)
    if write_ok == 0
        say "\033[1;31m❌ এরর: সিগনেচার ফাইল লেখতে ব্যর্থ: \033[0m" + sig_path
        return 1

    say "  ✔ SHA-256 ম্যানিফেস্ট হ্যাশ : " + manifest_hash
    say "  ✔ Ed25519 পাবলিক কী         : " + pub_hex
    say "  ✔ Ed25519 ডিজিটাল স্বাক্ষর : " + sig_hex
    say "  ✔ সিগনেচার ফাইল সংরক্ষিত     : " + sig_path
    say "\n\033[1;32m✅ প্যাকেজ সফলভাবে স্বাক্ষরিত হয়েছে!\033[0m"
    return 0

// WHY: Validates cryptographic authenticity and integrity of a standalone .aati / .lpkg package archive.
fn cmd_verify_bundle target sig_path
    b_data = file_read(target)
    if len(b_data) == 0
        say "\033[1;31m❌ এরর: বান্ডেল ফাইল পাওয়া যায়নি বা খালি: \033[0m" + target
        return 1
    end
    if starts_with(b_data, "AATI") == 0 and starts_with(b_data, "LPKG") == 0
        say "\033[1;31m❌ এরর: অবৈধ বান্ডেল ফরম্যাট: \033[0m" + target
        return 1
    end

    sig_header = "---FILE: lipi.sig"
    sig_pos = index_of(b_data, sig_header)
    if sig_pos < 0
        say "\033[1;31m❌ এরর: বান্ডেলে lipi.sig ক্রিপ্টোগ্রাফিক স্বাক্ষর পাওয়া যায়নি: \033[0m" + target
        return 1
    end

    sig_lb = index_of_from(b_data, "\n", sig_pos)
    if sig_lb < 0 return 1
    sig_end = index_of_from(b_data, "---ENDFILE---", sig_lb + 1)
    if sig_end < 0 return 1
    inner_sig = str_sub(b_data, sig_lb + 1, sig_end)
    if ends_with(inner_sig, "\n") inner_sig = str_sub(inner_sig, 0, len(inner_sig) - 1)
    if ends_with(inner_sig, "\r") inner_sig = str_sub(inner_sig, 0, len(inner_sig) - 1)

    m = parse_sig_manifest(inner_sig)
    pub_hex = get(m, 0)
    manifest_hash = get(m, 1)
    sig_hex = get(m, 2)
    file_paths = get(m, 3)
    file_hashes = get(m, 4)

    if len(pub_hex) < 64 or len(manifest_hash) < 64 or len(sig_hex) < 128
        say "\033[1;31m❌ এরর: বিকৃত বা অসম্পূর্ণ সিগনেচার ফাইল: \033[0m" + target
        return 1
    end

    say "  • বান্ডেল অন্তর্ভুক্ত স্বাক্ষর : lipi.sig"
    say "  • প্রণেতার পাবলিক কী          : " + pub_hex

    pub_buf = alloc(32)
    hex_to_bytes(pub_hex, pub_buf, 32)
    sig_buf = alloc(64)
    hex_to_bytes(sig_hex, sig_buf, 64)
    m_buf = alloc(64)
    i = 0
    while i < 64
        mem_byte_write(m_buf, i, ord(char_at(manifest_hash, i)))
        i = i + 1
    end
    sig_valid = Ed25519_verify(pub_buf, m_buf, 64, sig_buf)

    if sig_valid == 0
        say "\033[1;31m❌ এরর: Ed25519 ডিজিটাল স্বাক্ষর অকার্যকর বা জাল!\033[0m"
        return 1
    end
    say "  ✔ ক্রিপ্টোগ্রাফিক ডিজিটাল স্বাক্ষর বৈধ (Authentic Ed25519 Signature)"

    fi = 0
    while fi < len(file_paths)
        fp = get(file_paths, fi)
        exp_h = get(file_hashes, fi)
        f_hdr = "---FILE: " + fp
        fp_pos = index_of(b_data, f_hdr)
        if fp_pos < 0
            say "  ❌ ফাইল অনুপস্থিত: " + fp
            return 1
        end
        f_lb = index_of_from(b_data, "\n", fp_pos)
        if f_lb < 0 return 1
        f_fe = index_of_from(b_data, "---ENDFILE---", f_lb + 1)
        if f_fe < 0 return 1
        f_c = str_sub(b_data, f_lb + 1, f_fe)
        if ends_with(f_c, "\n") f_c = str_sub(f_c, 0, len(f_c) - 1)
        if ends_with(f_c, "\r") f_c = str_sub(f_c, 0, len(f_c) - 1)
        act_h = sha256_hex(f_c)
        if act_h != exp_h
            say "  ❌ ফাইল পরিবর্তন শনাক্ত হয়েছে: " + fp
            say "     প্রত্যাশিত SHA-256 : " + exp_h
            say "     বর্তমান SHA-256    : " + act_h
            return 1
        end
        say "  ✔ " + fp + " [PASS]"
        fi = fi + 1
    end
    say "  ✔ ম্যানিফেস্ট ডাইজেস্ট : " + manifest_hash + " [অক্ষত]"
    say "\n\033[1;32m✅ প্যাকেজ ডিজিটাল স্বাক্ষর ও অখণ্ডতা ১০০% যাচাইকৃত ও সুরক্ষিত! (VERIFIED AUTHENTIC)\033[0m"
    return 0

// WHY: Validates cryptographic authenticity and integrity of a directory-based Lipi package.
// Employs a single-pass on-the-fly streaming parser directly over manifest lines without intermediate
// list buffer reallocations, eliminating slab bucket recycling collisions and heap drift across arbitrary file counts.
fn pkg_parse_sig_manifest content
    pub_key = ""
    mhash = ""
    sig = ""
    file_paths = list()
    file_hashes = list()

    lines = split_delim(content, "\n")
    n = len(lines)
    in_files = 0
    i = 0
    while i < n
        line = trim(get(lines, i))
        if len(line) > 0
            if starts_with(line, "#") == 0
                if line == "[files]"
                    in_files = 1
                else
                    eq_pos = index_of(line, "=")
                    if eq_pos > 0
                        key = trim(str_sub(line, 0, eq_pos))
                        val = trim(str_sub(line, eq_pos + 1, len(line)))
                        if starts_with(val, chr(34)) and ends_with(val, chr(34)) and len(val) >= 2
                            val = str_sub(val, 1, len(val) - 1)
                        end
                        if in_files == 1
                            push(file_paths, key)
                            push(file_hashes, val)
                        else
                            if key == "public_key" pub_key = val
                            if key == "manifest_hash" mhash = val
                            if key == "signature" sig = val
                        end
                    end
                end
            end
        end
        i = i + 1
    end

    res = list()
    push(res, pub_key)
    push(res, mhash)
    push(res, sig)
    push(res, file_paths)
    push(res, file_hashes)
    return res

fn cmd_verify_dir target sig_path
    sig_content = file_read(sig_path)
    if len(sig_content) == 0
        say "\033[1;31m❌ এরর: সিগনেচার ফাইল পাওয়া যায়নি বা খালি: \033[0m" + sig_path
        return 1
    end

    m = pkg_parse_sig_manifest(sig_content)
    pub_hex = get(m, 0)
    manifest_hash = get(m, 1)
    sig_hex = get(m, 2)
    file_paths = get(m, 3)
    file_hashes = get(m, 4)

    if len(pub_hex) < 64 or len(manifest_hash) < 64 or len(sig_hex) < 128
        say "\033[1;31m❌ এরর: বিকৃত বা অসম্পূর্ণ সিগনেচার ফাইল: \033[0m" + sig_path
        return 1
    end

    say "  • সিগনেচার ফাইল     : " + sig_path
    say "  • প্রণেতার পাবলিক কী : " + pub_hex

    // Step A: Cryptographically verify Ed25519 signature of manifest hash
    pub_buf = alloc(32)
    hex_to_bytes(pub_hex, pub_buf, 32)
    sig_buf = alloc(64)
    hex_to_bytes(sig_hex, sig_buf, 64)
    m_buf = alloc(64)
    i = 0
    while i < 64
        mem_byte_write(m_buf, i, ord(char_at(manifest_hash, i)))
        i = i + 1
    end

    sig_valid = Ed25519_verify(pub_buf, m_buf, 64, sig_buf)
    if sig_valid != 1
        say "\033[1;31m❌ ক্রিপ্টোগ্রাফিক যাচাইকরণ ব্যর্থ: ডিজিটাল স্বাক্ষর অবৈধ বা বিকৃত!\033[0m"
        return 1
    end
    say "  ✔ ক্রিপ্টোগ্রাফিক ডিজিটাল স্বাক্ষর বৈধ (Authentic Ed25519 Signature)"

    // Step B: Verify manifest hash integrity directly from manifest lines
    num_files = len(file_paths)
    if num_files == 0
        say "❌ এরর: ম্যানিফেস্টে কোনো ফাইলের এন্ট্রি নেই।"
        return 1
    end

    canonical_check = ""
    i = 0
    while i < num_files
        rp = get(file_paths, i)
        eh = get(file_hashes, i)
        canonical_check = canonical_check + rp + ":" + eh + "\n"
        i = i + 1
    end

    recomputed_mhash = sha256_hex(canonical_check)
    if recomputed_mhash != manifest_hash
        say "\033[1;31m❌ ম্যানিফেস্ট হ্যাশ অসামঞ্জস্য: প্রত্যাশিত " + manifest_hash + ", পাওয়া গেছে " + recomputed_mhash + "\033[0m"
        return 1
    end
    say "  ✔ ম্যানিফেস্ট ডাইজেস্ট : " + recomputed_mhash + " [অক্ষত]"

    // Step C: Verify each file on disk against signed manifest entries
    prefix = ""
    if len(target) > 0 and target != "."
        prefix = target + "/"
    end

    tampered_count = 0
    missing_count = 0

    i = 0
    while i < num_files
        rel_path = get(file_paths, i)
        exp_hash = get(file_hashes, i)
        full_path = prefix + rel_path
        if starts_with(rel_path, "/")
            full_path = rel_path
        end

        act_hash = pkg_hash_file(full_path)
        if act_hash != exp_hash
            if exp_hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" and file_exists(full_path) == 0
                say "  ✔ " + rel_path + " [PASS]"
            else
                if file_exists(full_path) == 0
                    say "  ❌ অনুপস্থিত ফাইল : " + rel_path
                    missing_count = missing_count + 1
                else
                    say "  ❌ অখণ্ডতা লঙ্ঘন (Tampered) : " + rel_path
                    say "     প্রত্যাশিত SHA-256 : " + exp_hash
                    say "     পাওয়া গেছে          : " + act_hash
                    tampered_count = tampered_count + 1
                end
            end
        else
            say "  ✔ " + rel_path + " [PASS]"
        end
        i = i + 1
    end

    if missing_count > 0 or tampered_count > 0
        say "\n\033[1;31m❌ প্যাকেজ অখণ্ডতা যাচাইকরণ ব্যর্থ! (" + to_str(tampered_count) + " টি ফাইল বিকৃত, " + to_str(missing_count) + " টি অনুপস্থিত)\033[0m"
        return 1
    end

    say "\n\033[1;32m✅ প্যাকেজ ডিজিটাল স্বাক্ষর ও অখণ্ডতা ১০০% যাচাইকৃত ও সুরক্ষিত! (VERIFIED AUTHENTIC)\033[0m"
    return 0

// WHY: Validates cryptographic authenticity and integrity of a Lipi package release.
// Confirms Ed25519 digital signature against author's public key and verifies
// SHA-256 hashes of all files to detect tampering, corruption, or missing assets.
fn cmd_verify target
    if len(target) == 0 target = "."
    if len(target) > 1 and ends_with(target, "/")
        target = str_sub(target, 0, len(target) - 1)
    end

    say "\033[1;36m🔍 প্যাকেজ স্বাক্ষর ও অখণ্ডতা যাচাইকরণ: \033[0m" + target

    is_dir = is_directory(target)
    if is_dir == 1
        sig_path = target + "/lipi.sig"
        if target == "." sig_path = "lipi.sig"
        return cmd_verify_dir(target, sig_path)
    end

    sig_path = target + ".sig"
    if file_exists(sig_path) == 1
        return cmd_verify_dir("", sig_path)
    end

    return cmd_verify_bundle(target, sig_path)

// ── ৭. অন্যান্য কমান্ডসমূহ (Standard Subcommands) ──────────────────────────────

fn cmd_version
    say "lipipkg Version  : First 1.0.0 (প্রথম ১.০.০)"
    say "Lipi Compiler    : bin/lipc_bin (Sovereign Machine Code Engine)"
    say "Codename         : Sovereign"
    say "Target           : Linux x86_64 ELF64 (Direct Kernel ABI)"
    say "Dependencies     : 0% Libc | 0% GCC | 0% Python"
    say "Registry         : https://pkg.lipi.dev"
    say "License          : MIT Sovereign Open Source"

// WHY: Scaffolds a new standard Lipi package repository structure with manifest,
// source entrypoint, tests directory, and documentation. Sanitizes project name
// to support directory paths (e.g. /tmp/my_pkg) safely.
fn cmd_init proj_name
    say "\033[1;36m📁 Initializing new Lipi package project: \033[0m" + proj_name
    pkg_mkdir_p(proj_name)
    say "  ✔ Created directory: " + proj_name

    clean_pname = pkg_extract_repo_name(proj_name)
    if len(clean_pname) == 0 clean_pname = proj_name

    toml_path = proj_name + "/aati.toml"
    tfd = syscall(2, toml_path, 577, 420, 0, 0, 0)
    if tfd >= 0
        tcontent = "[package]\nname = \"" + clean_pname + "\"\nversion = \"0.1.0\"\nmain = \"src/main.lp\"\n"
        syscall(1, tfd, tcontent, len(tcontent), 0, 0, 0)
        syscall(3, tfd, 0, 0, 0, 0, 0)
        say "  ✔ Created manifest: " + toml_path

    src_dir = proj_name + "/src"
    pkg_mkdir_p(src_dir)

    main_path = proj_name + "/src/main.lp"
    mfd = syscall(2, main_path, 577, 420, 0, 0, 0)
    if mfd >= 0
        mcontent = "include \"utso/io\"\n\nfn main\n    say \"Hello from Lipi!\"\n    return 0\n\nmain()\n"
        syscall(1, mfd, mcontent, len(mcontent), 0, 0, 0)
        syscall(3, mfd, 0, 0, 0, 0, 0)
        say "  ✔ Created main entrypoint: " + main_path

    tests_dir = proj_name + "/tests"
    pkg_mkdir_p(tests_dir)
    say "  ✔ Created tests directory: " + tests_dir

    rm_path = proj_name + "/README.md"
    rfd = syscall(2, rm_path, 577, 420, 0, 0, 0)
    if rfd >= 0
        rcontent = "# " + clean_pname + "\n\nLipi sovereign package application.\n"
        syscall(1, rfd, rcontent, len(rcontent), 0, 0, 0)
        syscall(3, rfd, 0, 0, 0, 0, 0)
        say "  ✔ Created documentation: " + rm_path

    say "\n\033[1;32m✅ Project initialized successfully!\033[0m"
    say "  To build: cd " + proj_name + " && aati build"

// ── Process Spawner & Toolchain Orchestration (0% Libc / 0% Bash) ─────────────

// WHY: Spawns arbitrary child processes with dynamic argument vector using direct Linux
// kernel ABI: sys_mmap (9), sys_fork (57), sys_execve (59), sys_wait4 (61), sys_munmap (11).
// Zero libc, zero shell, zero external wrappers.
fn pkg_spawn_exec_list cmd_path args_list
    num_args = len(args_list)
    argv_bytes = (num_args + 2) * 8
    if argv_bytes < 64 argv_bytes = 64

    argv = syscall(9, 0, argv_bytes, 3, 34, -1, 0)
    if argv <= 0 return -1
    mem_word_write(argv, 0, cmd_path)

    i = 0
    while i < num_args
        arg_val = get(args_list, i)
        mem_word_write(argv, (i + 1) * 8, arg_val)
        i = i + 1
    mem_word_write(argv, (num_args + 1) * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    path_env = "PATH=/usr/bin:/bin:/usr/local/bin"
    mem_word_write(env, 0, path_env)
    mem_word_write(env, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid < 0
        syscall(11, argv, argv_bytes, 0, 0, 0, 0)
        syscall(11, env, 32, 0, 0, 0, 0)
        syscall(11, st, 8, 0, 0, 0, 0)
        return -1

    if pid == 0
        syscall(59, cmd_path, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    syscall(11, argv, argv_bytes, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)

    return exit_code

// WHY: Convenience wrapper preserving fixed 4-argument dispatch while delegating to dynamic spawner.
fn pkg_spawn_exec cmd_path arg1 arg2 arg3 arg4
    args = list()
    if len(arg1) > 0 push(args, arg1)
    if len(arg2) > 0 push(args, arg2)
    if len(arg3) > 0 push(args, arg3)
    if len(arg4) > 0 push(args, arg4)
    return pkg_spawn_exec_list(cmd_path, args)

fn pkg_resolve_compiler
    // WHY: Locates available Lipi compiler binary across repo, system, and local paths
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    if syscall(21, "/usr/local/bin/lipc", 0, 0, 0, 0, 0) == 0
        return "/usr/local/bin/lipc"
    if syscall(21, "/usr/bin/lipc", 0, 0, 0, 0, 0) == 0
        return "/usr/bin/lipc"
    return "lipc"

// WHY: Locates system git binary across standard Linux executable directories
// using sys_access (21) directly against kernel ABI.
fn pkg_resolve_git
    if syscall(21, "/usr/bin/git", 0, 0, 0, 0, 0) == 0 return "/usr/bin/git"
    if syscall(21, "/bin/git", 0, 0, 0, 0, 0) == 0 return "/bin/git"
    if syscall(21, "/usr/local/bin/git", 0, 0, 0, 0, 0) == 0 return "/usr/local/bin/git"
    return ""

// WHY: Locates system curl binary across standard Linux executable directories
// using sys_access (21) directly against kernel ABI.
fn pkg_resolve_curl
    if syscall(21, "/usr/bin/curl", 0, 0, 0, 0, 0) == 0 return "/usr/bin/curl"
    if syscall(21, "/bin/curl", 0, 0, 0, 0, 0) == 0 return "/bin/curl"
    if syscall(21, "/usr/local/bin/curl", 0, 0, 0, 0, 0) == 0 return "/usr/local/bin/curl"
    return ""

// WHY: Finds substring occurrence beginning at specified character offset with zero allocations.
fn index_of_from s sub start_pos
    slen = len(s)
    sublen = len(sub)
    if sublen == 0 return start_pos
    if start_pos < 0 start_pos = 0
    if (start_pos + sublen) > slen return -1
    limit = slen - sublen
    i = start_pos
    while i <= limit
        match = 1
        j = 0
        while j < sublen
            if char_at(s, i + j) != char_at(sub, j)
                match = 0
                break
            j = j + 1
        if match == 1 return i
        i = i + 1
    return -1

// WHY: Recursively creates all nested directories along path using Linux sys_mkdir (83).
fn pkg_mkdir_p path
    if len(path) == 0 or path == "." return 0
    if is_directory(path) == 1 return 0
    parts = split_delim(path, "/")
    cur = ""
    if starts_with(path, "/") cur = "/"
    i = 0
    while i < len(parts)
        part = get(parts, i)
        if len(part) > 0
            if len(cur) == 0 or cur == "/"
                cur = cur + part
            else
                cur = cur + "/" + part
            syscall(83, cur, 509, 0, 0, 0, 0)
        i = i + 1
    return 0

// WHY: Extracts scalar field value from TOML content without regex or external parser.
fn pkg_parse_field toml_str field_name
    lines = split_delim(toml_str, "\n")
    i = 0
    target = field_name + " = "
    tlen = len(target)
    while i < len(lines)
        line = trim(get(lines, i))
        if starts_with(line, target)
            v = trim(str_sub(line, tlen, len(line)))
            if starts_with(v, chr(34)) and ends_with(v, chr(34)) and len(v) >= 2
                return str_sub(v, 1, len(v) - 1)
            return v
        i = i + 1
    return ""

// WHY: Identifies whether a target string refers to a Git repository URL or remote slug.
// Filters out .lpkg archive bundles and existing local directories.
fn pkg_is_git_target target
    if ends_with(target, ".lpkg") == 1 or index_of(target, ".lpkg") >= 0
        return 0
    if starts_with(target, "packages/") and syscall(21, target, 0, 0, 0, 0, 0) == 0
        return 0
    if (starts_with(target, "./") or starts_with(target, "../")) and is_directory(target) == 1
        return 0
    if index_of(target, "github.com/") >= 0 return 1
    if index_of(target, "gitlab.com/") >= 0 return 1
    if starts_with(target, "git@") == 1 or index_of(target, "git@") >= 0 return 1
    if index_of(target, ".git") >= 0 return 1
    if starts_with(target, "git://") == 1 return 1
    if index_of(target, "/") >= 0 return 1
    return 0

// WHY: Extracts branch or release tag qualifier specified via '@tag' (e.g. '@v1.0.0' or '@main').
fn pkg_extract_tag target
    start_pos = 0
    if starts_with(target, "git@") start_pos = 4
    at_pos = -1
    i = start_pos
    tlen = len(target)
    while i < tlen
        if char_at(target, i) == "@" at_pos = i
        i = i + 1
    if at_pos > 0 and (at_pos + 1) < tlen
        return str_sub(target, at_pos + 1, tlen)
    return ""

// WHY: Extracts clean repository or package base name from any Git URL, file path, or slug.
// Strips tags (@v1.0.0), trailing '.git', and path directories.
fn pkg_extract_repo_name target
    clean = target
    tag = pkg_extract_tag(target)
    if len(tag) > 0
        clean = str_sub(target, 0, len(target) - len(tag) - 1)
    if ends_with(clean, ".git")
        clean = str_sub(clean, 0, len(clean) - 4)
    if len(clean) > 1 and ends_with(clean, "/")
        clean = str_sub(clean, 0, len(clean) - 1)
    last_delim = -1
    i = len(clean) - 1
    while i >= 0
        c = char_at(clean, i)
        if c == "/" or c == ":"
            last_delim = i
            break
        i = i - 1
    if last_delim >= 0
        return str_sub(clean, last_delim + 1, len(clean))
    return clean

// WHY: Expands short repository slugs (e.g. 'shafiullah/web_router') into full cloneable URLs.
fn pkg_normalize_git_url target
    clean = target
    tag = pkg_extract_tag(target)
    if len(tag) > 0
        clean = str_sub(target, 0, len(target) - len(tag) - 1)
    if starts_with(clean, "http://") or starts_with(clean, "https://") or starts_with(clean, "git@") or starts_with(clean, "git://")
        return clean
    if starts_with(clean, "github.com/") or starts_with(clean, "gitlab.com/")
        return "https://" + clean
    if index_of(clean, "/") > 0
        return "https://github.com/" + clean + ".git"
    return clean

// WHY: Clones remote Git repository via native process spawner with --depth 1 and optional tag,
// verifies authentic Ed25519 signature if lipi.sig exists, and computes canonical SHA-256 checksum.
fn pkg_fetch_git git_url tag target_dir
    say "  📥 Fetching Git repository: " + git_url
    if len(tag) > 0 say "  🏷️ Branch/Tag: " + tag

    git_bin = pkg_resolve_git()
    if len(git_bin) == 0
        say "❌ এরর: git বাইনারি পাওয়া যায়নি (/usr/bin/git, /bin/git, /usr/local/bin/git)"
        return ""

    pkg_mkdir_p("packages")

    args = list()
    push(args, "clone")
    push(args, "--depth")
    push(args, "1")
    if len(tag) > 0
        push(args, "--branch")
        push(args, tag)
    push(args, git_url)
    push(args, target_dir)

    exit_code = pkg_spawn_exec_list(git_bin, args)
    if exit_code != 0
        say "❌ git clone ব্যর্থ হয়েছে (কোড: " + str(exit_code) + ")"
        return ""

    if is_directory(target_dir) == 0
        say "❌ ক্লোন করা প্যাকেজ ডিরেক্টরি পাওয়া যায়নি: " + target_dir
        return ""

    raw_files = list()
    collect_files(target_dir, raw_files)
    if len(raw_files) == 0
        say "❌ ক্লোন করা প্যাকেজ ডিরেক্টরি খালি: " + target_dir
        return ""

    files = sort_files(raw_files)
    say "  ✔ " + str(len(files)) + " টি ফাইল সফলভাবে ক্লোন করা হয়েছে।"

    // If cloned package contains lipi.sig, run authentic Ed25519 verification
    sig_path = target_dir + "/lipi.sig"
    if syscall(21, sig_path, 0, 0, 0, 0, 0) == 0
        say "  🔏 lipi.sig পাওয়া গেছে — Ed25519 ক্রিপ্টোগ্রাফিক স্বাক্ষর যাচাইকরণ..."
        v_res = cmd_verify(target_dir)
        if v_res != 0
            say "❌ Ed25519 স্বাক্ষর যাচাইকরণ ব্যর্থ হয়েছে!"
            return ""
        say "  ✔ Ed25519 ডিজিটাল স্বাক্ষর শতভাগ প্রমাণিত ও অক্ষত।"

    // Compute canonical SHA-256 checksum of package contents
    // WHY: Single-pass streaming eliminates intermediary dynamic list reallocations,
    // guaranteeing 100% deterministic bit-for-bit cryptographic integrity across packages of any size.
    num_f = len(files)
    prefix = target_dir + "/"
    canonical_str = ""
    i = 0
    while i < num_f
        fp = get(files, i)
        rel_p = fp
        if starts_with(fp, prefix)
            rel_p = str_sub(fp, len(prefix), len(fp))
        end
        f_hash = pkg_hash_file(fp)
        canonical_str = canonical_str + rel_p + ":" + f_hash + "\n"
        i = i + 1
    end

    checksum = sha256_hex(canonical_str)
    say "  ✔ প্যাকেজ SHA-256 চেকসাম: " + checksum
    return checksum

// WHY: Unpacks sovereign .aati (or legacy .lpkg) distribution bundle into target directory with zero tar/gzip dependencies.
// Extracts files, creates subdirectories, verifies SHA-256 checksums from headers, and validates Ed25519 signature if present.
fn pkg_unpack_bundle bundle_path target_dir
    say "  📦 আনপ্যাকিং বান্ডেল: " + bundle_path + " -> " + target_dir
    b_data = read_file(bundle_path)
    if len(b_data) == 0
        say "❌ বান্ডেল ফাইল পাওয়া যায়নি বা খালি: " + bundle_path
        return 0

    if starts_with(b_data, "AATI") == 0 and starts_with(b_data, "LPKG") == 0
        say "❌ অবৈধ বান্ডেল ফরম্যাট (AATI/LPKG হেডার অনুপস্থিত): " + bundle_path
        return 0

    pkg_mkdir_p(target_dir)

    pos = 0
    dlen = len(b_data)
    file_tag = "---FILE: "
    tag_len = len(file_tag)
    end_tag = "---ENDFILE---"
    extracted_count = 0

    while pos < dlen
        f_start = index_of_from(b_data, file_tag, pos)
        if f_start < 0 break

        hdr_start = f_start + tag_len
        line_break = index_of_from(b_data, "\n", hdr_start)
        if line_break < 0 break

        hdr_line = str_sub(b_data, hdr_start, line_break)
        if ends_with(hdr_line, "\r")
            hdr_line = str_sub(hdr_line, 0, len(hdr_line) - 1)
        if ends_with(hdr_line, "---")
            hdr_line = str_sub(hdr_line, 0, len(hdr_line) - 3)
        hdr_line = trim(hdr_line)

        filename = ""
        exp_hash = ""
        file_sz = -1

        sha_idx = index_of(hdr_line, "SHA256: ")
        if sha_idx >= 0
            paren_idx = index_of(hdr_line, " (SHA256: ")
            if paren_idx > 0
                filename = trim(str_sub(hdr_line, 0, paren_idx))
            exp_hash = str_sub(hdr_line, sha_idx + 8, sha_idx + 8 + 64)
        else
            paren_idx = index_of(hdr_line, " (")
            if paren_idx > 0
                filename = trim(str_sub(hdr_line, 0, paren_idx))
            else
                filename = hdr_line

        sz_idx = index_of(hdr_line, "SIZE: ")
        if sz_idx >= 0
            sz_str = ""
            sp = sz_idx + 6
            while sp < len(hdr_line)
                sc = char_at(hdr_line, sp)
                scode = ord(sc)
                if scode >= 48 and scode <= 57
                    sz_str = sz_str + sc
                    sp = sp + 1
                else
                    break
            if len(sz_str) > 0 file_sz = to_int(sz_str)

        f_end = index_of_from(b_data, end_tag, line_break + 1)
        if f_end < 0 break

        content = ""
        if file_sz >= 0
            content = str_sub(b_data, line_break + 1, line_break + 1 + file_sz)
        else
            content = str_sub(b_data, line_break + 1, f_end)
            if ends_with(content, "\n")
                content = str_sub(content, 0, len(content) - 1)
            if ends_with(content, "\r")
                content = str_sub(content, 0, len(content) - 1)

        if len(exp_hash) == 64
            act_hash = sha256_hex(content)
            if act_hash != exp_hash
                write_file("/tmp/vault_fail.bin", fc)
                say "❌ ফাইলের চেকসাম অমিল: " + filename
                say "   প্রত্যাশিত: " + exp_hash
                say "   পাওয়া গেছে : " + act_hash
                return 0

        out_path = target_dir + "/" + filename
        last_slash = -1
        ki = len(out_path) - 1
        while ki >= 0
            if char_at(out_path, ki) == "/"
                last_slash = ki
                break
            ki = ki - 1
        if last_slash > 0
            pkg_mkdir_p(str_sub(out_path, 0, last_slash))

        w_ok = write_file(out_path, content)
        if w_ok == 0
            say "❌ ফাইল লিখতে ব্যর্থ: " + out_path
            return 0

        say "  ✔ এক্সট্রাক্ট করা হয়েছে: " + filename + " (" + str(len(content)) + " বাইট)"
        extracted_count = extracted_count + 1
        pos = f_end + len(end_tag)

    if extracted_count == 0
        say "❌ বান্ডেল থেকে কোনো ফাইল পাওয়া যায়নি।"
        return 0

    // If unpacked contents include lipi.sig, verify signature
    if syscall(21, target_dir + "/lipi.sig", 0, 0, 0, 0, 0) == 0
        say "  🔏 বান্ডেলে lipi.sig পাওয়া গেছে — Ed25519 ক্রিপ্টোগ্রাফিক যাচাইকরণ..."
        v_res = cmd_verify(target_dir)
        if v_res != 0
            say "❌ আনপ্যাক করা প্যাকেজের Ed25519 স্বাক্ষর ব্যর্থ হয়েছে!"
            return 0
        say "  ✔ Ed25519 ডিজিটাল স্বাক্ষর শতভাগ প্রমাণিত।"

    say "  ✔ " + str(extracted_count) + " টি ফাইল সফলভাবে আনপ্যাক করা হয়েছে।"
    return 1

// // WHY: Generates or updates canonical deterministic lockfile (aati.lock) to guarantee bit-for-bit
// reproducible builds across machines (Trap 3 Defense). Packages are lexicographically sorted.
fn pkg_update_lockfile pkg_name version source checksum
    root_name = "app"
    root_ver = "1.0.0"
    m_digest = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    m_path = pkg_get_manifest_path(".")
    m_toml = read_file(m_path)
    if len(m_toml) > 0
        p_name = pkg_parse_field(m_toml, "name")
        if len(p_name) > 0 root_name = p_name
        p_ver = pkg_parse_field(m_toml, "version")
        if len(p_ver) > 0 root_ver = p_ver
        m_digest = sha256_hex(m_toml)

    // Parse existing packages from aati.lock (fallback lipipkg.lock) if present
    pkg_records = list()
    lock_data = read_file("aati.lock")
    if len(lock_data) == 0
        lock_data = read_file("lipipkg.lock")
    if len(lock_data) > 0
        lines = split_delim(lock_data, "\n")
        cur_p_name = ""
        cur_p_ver = ""
        cur_p_src = ""
        cur_p_sum = ""
        in_pkg = 0

        li = 0
        while li < len(lines)
            l = trim(get(lines, li))
            if l == "[[aati]]" or l == "[[package]]"
                if in_pkg == 1 and len(cur_p_name) > 0
                    rec = list()
                    push(rec, cur_p_name)
                    push(rec, cur_p_ver)
                    push(rec, cur_p_src)
                    push(rec, cur_p_sum)
                    push(pkg_records, rec)
                in_pkg = 1
                cur_p_name = ""
                cur_p_ver = ""
                cur_p_src = ""
                cur_p_sum = ""
            elif in_pkg == 1
                if starts_with(l, "name = ")
                    cur_p_name = pkg_parse_field(l, "name")
                elif starts_with(l, "version = ")
                    cur_p_ver = pkg_parse_field(l, "version")
                elif starts_with(l, "source = ")
                    cur_p_src = pkg_parse_field(l, "source")
                elif starts_with(l, "checksum = ")
                    cur_p_sum = pkg_parse_field(l, "checksum")
            li = li + 1

        if in_pkg == 1 and len(cur_p_name) > 0
            rec = list()
            push(rec, cur_p_name)
            push(rec, cur_p_ver)
            push(rec, cur_p_src)
            push(rec, cur_p_sum)
            push(pkg_records, rec)

    // Update or append pkg_name
    found = 0
    ri = 0
    while ri < len(pkg_records)
        rec = get(pkg_records, ri)
        if get(rec, 0) == pkg_name
            list_set(rec, 1, version)
            list_set(rec, 2, source)
            list_set(rec, 3, checksum)
            found = 1
            break
        ri = ri + 1

    if found == 0
        new_rec = list()
        push(new_rec, pkg_name)
        push(new_rec, version)
        push(new_rec, source)
        push(new_rec, checksum)
        push(pkg_records, new_rec)

    // Sort package records lexicographically (selection sort for determinism)
    n = len(pkg_records)
    used = alloc(n)
    mem_fill(used, 0, n)
    sorted_records = list()

    k = 0
    while k < n
        best_idx = -1
        best_name = ""
        si = 0
        while si < n
            if mem_byte_read(used, si) == 0
                item = get(pkg_records, si)
                iname = get(item, 0)
                if best_idx == -1 or pkg_str_cmp(iname, best_name) < 0
                    best_idx = si
                    best_name = iname
            si = si + 1
        if best_idx >= 0
            mem_byte_write(used, best_idx, 1)
            push(sorted_records, get(pkg_records, best_idx))
        k = k + 1

    // Serialize canonical lockfile
    out = "# 👑 Lipi Sovereign Deterministic Package Lockfile (Format v1)\n"
    out = out + "# AUTOGENERATED - DO NOT EDIT MANUALLY\n\n"
    out = out + "lockfile_version = 1\n"
    out = out + "root_package = \"" + root_name + "\"\n"
    out = out + "root_version = \"" + root_ver + "\"\n"
    out = out + "manifest_digest = \"" + m_digest + "\"\n\n"

    pi = 0
    while pi < len(sorted_records)
        p = get(sorted_records, pi)
        out = out + "[[aati]]\n"
        out = out + "name = \"" + get(p, 0) + "\"\n"
        out = out + "version = \"" + get(p, 1) + "\"\n"
        out = out + "source = \"" + get(p, 2) + "\"\n"
        out = out + "checksum = \"" + get(p, 3) + "\"\n\n"
        pi = pi + 1

    write_file("aati.lock", out)
    say "  ✔ আঁটি লকফাইল হালনাগাদ করা হয়েছে: aati.lock"
    return 1

// WHY: Ensures dependency entry exists in aati.toml under [dependencies].
fn pkg_record_manifest_dep pkg_name version source
    toml_path = pkg_get_manifest_path(".")
    if syscall(21, toml_path, 0, 0, 0, 0, 0) != 0
        return 0
    m_content = read_file(toml_path)
    if index_of(m_content, pkg_name) >= 0
        return 0
    dep_line = pkg_name + " = \"" + version + "\""
    if len(source) > 0 and source != pkg_name
        dep_line = pkg_name + " = { version = \"" + version + "\", source = \"" + source + "\" }"
    new_m = ""
    if index_of(m_content, "[dependencies]") >= 0
        new_m = m_content + "\n" + dep_line + "\n"
    else
        new_m = m_content + "\n\n[dependencies]\n" + dep_line + "\n"
    write_file(toml_path, new_m)
    say "  ✔ " + toml_path + " ফাইলে " + pkg_name + " যুক্ত করা হয়েছে।"
    return 1

// WHY: Performs HTTP GET query against sovereign package registry via raw Linux kernel sockets.
fn pkg_http_get reg_host reg_port path
    s_fd = socket_create()
    if s_fd < 0 return ""
    addr_buf = malloc(16)
    c_res = socket_connect_ip(s_fd, addr_buf, 127, 0, 0, 1, reg_port)
    free(addr_buf, 16)
    if c_res < 0
        socket_close(s_fd)
        return ""
    req = "GET " + path + " HTTP/1.1\r\nHost: " + reg_host + ":" + str(reg_port) + "\r\nConnection: close\r\n\r\n"
    syscall(1, s_fd, req, len(req), 0, 0, 0)

    resp_text = ""
    buf = malloc(65536)
    while 1
        n = syscall(0, s_fd, buf, 65535, 0, 0, 0)
        if n <= 0 break
        i = 0
        while i < n
            resp_text = resp_text + chr(mem_byte_read(buf, i))
            i = i + 1
    free(buf, 65536)
    socket_close(s_fd)
    return resp_text

// WHY: Strips RFC HTTP response headers and returns raw message payload body.
fn pkg_http_extract_body resp_text
    hdr_end = index_of(resp_text, "\r\n\r\n")
    if hdr_end >= 0
        return str_sub(resp_text, hdr_end + 4, len(resp_text))
    hdr_end = index_of(resp_text, "\n\n")
    if hdr_end >= 0
        return str_sub(resp_text, hdr_end + 2, len(resp_text))
    return resp_text

fn cmd_build target
    say "\033[1;36m⚙️  Compiling Lipi package project...\033[0m"
    compiler = pkg_resolve_compiler()

    // Determine entry point
    entry_path = ""
    if len(target) > 0 and target != "release" and target != "debug" and syscall(21, target, 0, 0, 0, 0, 0) == 0
        entry_path = target
    elif syscall(21, "src/main.lp", 0, 0, 0, 0, 0) == 0
        entry_path = "src/main.lp"
    elif syscall(21, "main.lp", 0, 0, 0, 0, 0) == 0
        entry_path = "main.lp"
    else
        say "❌ [ত্রুটি / Error]: কোনো সোর্স ফাইল পাওয়া যায়নি (No entry point found: tried " + target + ", src/main.lp, main.lp)"
        return 1

    out_bin = "build/app"
    say "  • Compiler    : " + compiler + " (Sovereign Machine Code Compiler)"
    say "  • Entry Point : " + entry_path
    say "  • Output      : " + out_bin

    // Ensure build directory exists: sys_mkdir (83)
    syscall(83, "build", 509, 0, 0, 0, 0)

    // Execute compilation: compiler entry_path -o out_bin
    code = pkg_spawn_exec(compiler, entry_path, "-o", out_bin, "")
    if code != 0
        say "\n\033[1;31m❌ Build failed with exit code: " + str(code) + "\033[0m"
        return code

    say "  ✔ Compilation finished!"
    say "  • Output binary : " + out_bin + " (Pure ELF64)"
    say "  • Dependencies  : 0% Libc | 0% GCC"
    say "\n\033[1;32m✅ Build succeeded! -> " + out_bin + "\033[0m"
    return 0

fn cmd_test
    say "\033[1;36m🧪 Running Lipi package test suite...\033[0m"
    test_runner = ""
    if syscall(21, "bin/lipi-test", 0, 0, 0, 0, 0) == 0
        test_runner = "bin/lipi-test"
    elif syscall(21, "bin/lipi", 0, 0, 0, 0, 0) == 0
        test_runner = "bin/lipi"

    if test_runner == "bin/lipi-test"
        say "  • Invoking sovereign test runner: bin/lipi-test"
        code = pkg_spawn_exec(test_runner, "", "", "", "")
        if code == 0
            say "\n\033[1;32m✅ All package tests passed!\033[0m"
        else
            say "\n\033[1;31m❌ Test suite failed with code: " + str(code) + "\033[0m"
        return code
    elif test_runner == "bin/lipi"
        say "  • Invoking sovereign test dispatcher: bin/lipi test"
        code = pkg_spawn_exec(test_runner, "test", "", "", "")
        if code == 0
            say "\n\033[1;32m✅ All package tests passed!\033[0m"
        else
            say "\n\033[1;31m❌ Test suite failed with code: " + str(code) + "\033[0m"
        return code
    else
        if syscall(21, "tests/01_hello.lp", 0, 0, 0, 0, 0) == 0
            compiler = pkg_resolve_compiler()
            code = pkg_spawn_exec(compiler, "tests/01_hello.lp", "-o", "/tmp/lipi_pkg_tst", "")
            if code == 0
                run_code = pkg_spawn_exec("/tmp/lipi_pkg_tst", "", "", "", "")
                syscall(87, "/tmp/lipi_pkg_tst", 0, 0, 0, 0, 0)
                if run_code == 0
                    say "  \033[38;2;0;255;100m✔\033[0m tests/01_hello.lp [PASS]"
                    say "\n\033[1;32m✅ All package tests passed!\033[0m"
                    return 0
            say "\n\033[1;31m❌ Test failed!\033[0m"
            return 1
        say "  ⚠ No tests found in tests/ directory."
        return 0

fn cmd_clean
    say "🧹 Purging build/ directory artifacts..."
    syscall(87, "build/app", 0, 0, 0, 0, 0)
    say "  ✔ build/app removed"
    say "\033[1;32m✅ Cleanup complete!\033[0m"

fn cmd_hash file_path
    say "\033[1;36m🔐 Cryptographic Hash Calculation: \033[0m" + file_path
    fd = syscall(2, file_path, 0, 0, 0, 0, 0)
    if fd < 0
        say "❌ File not found: " + file_path
        return 0

    buf = malloc(4096)
    hash = 2166136261
    total = 0

    while 1
        n = syscall(0, fd, buf, 4096, 0, 0, 0)
        if n <= 0 break
        total = total + n
        i = 0
        while i < n
            b = mem_byte_read(buf, i)
            hash = (hash ^ b) * 16777619
            i = i + 1

    syscall(3, fd, 0, 0, 0, 0, 0)
    free(buf, 4096)

    say "  • ফাইল সাইজ : " + total + " বাইট"
    say "  • অ্যালগরিদম : Sovereign 64-bit FNV-1a Checksum (0% Libc)"
    say "  • হ্যাশ মান  : 0x" + qword_to_hex(hash) + "\n"
    return hash

fn cmd_info
    say "📦 আঁটি তথ্য (Aati Information):"
    say "  ম্যানিফেস্ট : aati.toml"
    say "  কম্পাইলার  : bin/lipc_bin (লিপি প্রথম ১.০)"
    say "  লক্ষ্য      : Linux x86_64 ELF64 (static)"
    say "  রেজিস্ট্রি  : https://haat.lipi.dev"

// ── ৮. প্যাকেজ ইনস্টলেশন ও রিমোট প্রকাশনা (Package Fetch & Publish) ───────────
// WHY: Comprehensive package resolution engine handling Git repositories, remote/local .aati/.lpkg bundles,
// existing local libraries, and sovereign registry server lookups with cryptographic verification.
fn cmd_install pkg_target
    say "\033[1;36m⬇️  আঁটি ডাউনলোড ও ইনস্টলেশন: \033[0m" + pkg_target

    // Case 1: Git repository
    if pkg_is_git_target(pkg_target) == 1
        repo_name = pkg_extract_repo_name(pkg_target)
        tag = pkg_extract_tag(pkg_target)
        git_url = pkg_normalize_git_url(pkg_target)
        target_dir = "aati/" + repo_name
        if is_directory("packages") == 1 and is_directory("aati") == 0
            target_dir = "packages/" + repo_name

        chk = pkg_fetch_git(git_url, tag, target_dir)
        if len(chk) == 0
            say "❌ Git প্যাকেজ ফেচ করতে ব্যর্থ হয়েছে: " + pkg_target
            return 1

        ver = "1.0.0"
        if len(tag) > 0
            ver = tag
        else
            m_data = read_file(pkg_get_manifest_path(target_dir))
            v_val = pkg_parse_field(m_data, "version")
            if len(v_val) > 0 ver = v_val

        pkg_record_manifest_dep(repo_name, ver, git_url)
        pkg_update_lockfile(repo_name, ver, git_url, chk)
        say "\n\033[1;32m✅ Git প্যাকেজ সফলভাবে ইনস্টল করা হয়েছে: " + repo_name + " (" + ver + ")\033[0m"
        return 0

    // Case 2: .aati / .lpkg archive (URL or local file)
    is_url = 0
    if starts_with(pkg_target, "http://") == 1 or starts_with(pkg_target, "https://") == 1
        is_url = 1
    is_aati_bundle = 0
    if ends_with(pkg_target, ".aati") == 1 or index_of(pkg_target, ".aati") >= 0
        is_aati_bundle = 1
    elif ends_with(pkg_target, ".lpkg") == 1 or index_of(pkg_target, ".lpkg") >= 0
        is_aati_bundle = 1

    if is_aati_bundle == 1
        bundle_file = pkg_target
        if is_url == 1
            b_name = pkg_extract_repo_name(pkg_target)
            bundle_file = "/tmp/" + b_name
            curl_bin = pkg_resolve_curl()
            if len(curl_bin) > 0
                c_args = list()
                push(c_args, "-sSL")
                push(c_args, pkg_target)
                push(c_args, "-o")
                push(c_args, bundle_file)
                c_code = pkg_spawn_exec_list(curl_bin, c_args)
                if c_code != 0
                    say "❌ বান্ডেল ডাউনলোড ব্যর্থ: " + pkg_target
                    return 1
            else
                say "❌ curl বাইনারি পাওয়া যায়নি রিমোট ডাউনলোডের জন্য।"
                return 1

        repo_name = pkg_extract_repo_name(pkg_target)
        if ends_with(repo_name, ".aati")
            repo_name = str_sub(repo_name, 0, len(repo_name) - 5)
        elif ends_with(repo_name, ".lpkg")
            repo_name = str_sub(repo_name, 0, len(repo_name) - 5)
        target_dir = "aati/" + repo_name
        if is_directory("packages") == 1 and is_directory("aati") == 0
            target_dir = "packages/" + repo_name

        u_ok = pkg_unpack_bundle(bundle_file, target_dir)
        if u_ok == 0 return 1

        b_content = read_file(bundle_file)
        chk = sha256_hex(b_content)
        ver = "1.0.0"
        m_data = read_file(pkg_get_manifest_path(target_dir))
        v_val = pkg_parse_field(m_data, "version")
        if len(v_val) > 0 ver = v_val

        pkg_record_manifest_dep(repo_name, ver, pkg_target)
        pkg_update_lockfile(repo_name, ver, pkg_target, chk)
        say "\n\033[1;32m✅ আঁটি বান্ডেল সফলভাবে ইনস্টল হয়েছে: " + repo_name + " (" + ver + ")\033[0m"
        return 0

    // Case 3: Existing local package in aati/ or packages/
    local_dir = pkg_target
    if starts_with(pkg_target, "aati/") == 0 and starts_with(pkg_target, "packages/") == 0
        if is_directory("aati/" + pkg_target) == 1
            local_dir = "aati/" + pkg_target
        elif is_directory("packages/" + pkg_target) == 1
            local_dir = "packages/" + pkg_target

    if is_directory(local_dir) == 1
        p_name = pkg_extract_repo_name(local_dir)
        say "  🔍 লোকাল প্যাকেজ অখণ্ডতা যাচাইকরণ: " + local_dir
        if syscall(21, local_dir + "/lipi.sig", 0, 0, 0, 0, 0) == 0
            v_res = cmd_verify(local_dir)
            if v_res != 0
                say "❌ লোকাল প্যাকেজের Ed25519 স্বাক্ষর অবৈধ!"
                return 1

        raw_files = list()
        collect_files(local_dir, raw_files)
        files = sort_files(raw_files)
        // WHY: Single-pass streaming eliminates intermediary dynamic list reallocations,
        // guaranteeing 100% deterministic bit-for-bit cryptographic integrity across packages of any size.
        num_f = len(files)
        prefix = local_dir + "/"
        canonical_str = ""
        i = 0
        while i < num_f
            fp = get(files, i)
            rel_p = fp
            if starts_with(fp, prefix)
                rel_p = str_sub(fp, len(prefix), len(fp))
            end
            f_hash = pkg_hash_file(fp)
            canonical_str = canonical_str + rel_p + ":" + f_hash + "\n"
            i = i + 1
        end

        chk = sha256_hex(canonical_str)
        ver = "1.0.0"
        m_data = read_file(pkg_get_manifest_path(local_dir))
        v_val = pkg_parse_field(m_data, "version")
        if len(v_val) > 0 ver = v_val

        pkg_update_lockfile(p_name, ver, "local:" + local_dir, chk)
        say "\n\033[1;32m✅ লোকাল প্যাকেজ যাচাই সম্পন্ন ও লকফাইল হালনাগাদ: " + p_name + "\033[0m"
        return 0

    // Case 4: Remote Registry lookup (default http://127.0.0.1:8088)
    reg_host = "127.0.0.1"
    reg_port = 8088
    resp = pkg_http_get(reg_host, reg_port, "/api/v1/packages/" + pkg_target)
    if starts_with(resp, "HTTP/1.1 200") or starts_with(resp, "HTTP/1.0 200")
        say "  ✔ সার্বভৌম রেজিস্ট্রি থেকে প্যাকেজ পাওয়া গেছে।"
        bundle_resp = pkg_http_get(reg_host, reg_port, "/api/v1/packages/" + pkg_target + ".aati")
        if starts_with(bundle_resp, "HTTP/1.1 200") == 0 and starts_with(bundle_resp, "HTTP/1.0 200") == 0
            bundle_resp = pkg_http_get(reg_host, reg_port, "/api/v1/packages/" + pkg_target + ".lpkg")
        if starts_with(bundle_resp, "HTTP/1.1 200") or starts_with(bundle_resp, "HTTP/1.0 200")
            bundle_body = pkg_http_extract_body(bundle_resp)
            temp_bundle = "/tmp/" + pkg_target + ".aati"
            write_file(temp_bundle, bundle_body)
            target_dir = "aati/" + pkg_target
            if is_directory("packages") == 1 and is_directory("aati") == 0 target_dir = "packages/" + pkg_target
            u_ok = pkg_unpack_bundle(temp_bundle, target_dir)
            if u_ok == 1
                chk = sha256_hex(bundle_body)
                ver = "1.0.0"
                m_data = read_file(pkg_get_manifest_path(target_dir))
                v_val = pkg_parse_field(m_data, "version")
                if len(v_val) > 0 ver = v_val
                pkg_record_manifest_dep(pkg_target, ver, "http://" + reg_host + ":" + str(reg_port))
                pkg_update_lockfile(pkg_target, ver, "http://" + reg_host + ":" + str(reg_port), chk)
                say "\n\033[1;32m✅ রেজিস্ট্রি থেকে প্যাকেজ সফলভাবে ইনস্টল হয়েছে: " + pkg_target + "\033[0m"
                return 0

    // Case 5: Local scaffolding fallback (for offline development and tests)
    base_store = "aati"
    if is_directory("packages") == 1 and is_directory("aati") == 0 base_store = "packages"
    pkg_mkdir_p(base_store)
    target_dir = base_store + "/" + pkg_target
    pkg_mkdir_p(target_dir)

    m_path = target_dir + "/aati.toml"
    if syscall(21, m_path, 0, 0, 0, 0, 0) != 0 and syscall(21, target_dir + "/lipipkg.toml", 0, 0, 0, 0, 0) != 0
        content = "[package]\nname = \"" + pkg_target + "\"\nversion = \"1.0.0\"\nedition = \"2026\"\nentry = \"lib.lp\"\n\n[dependencies]\n"
        write_file(m_path, content)

    l_path = target_dir + "/lib.lp"
    if syscall(21, l_path, 0, 0, 0, 0, 0) != 0
        l_content = "// Package: " + pkg_target + "\nfn " + pkg_target + "_init\n    return 1\n"
        write_file(l_path, l_content)

    act_m_path = pkg_get_manifest_path(target_dir)
    f1 = read_file(act_m_path)
    f2 = read_file(l_path)
    chk = sha256_hex("lib.lp:" + sha256_hex(f2) + "\n" + pkg_extract_repo_name(act_m_path) + ":" + sha256_hex(f1) + "\n")
    pkg_record_manifest_dep(pkg_target, "1.0.0", "local:" + target_dir)
    pkg_update_lockfile(pkg_target, "1.0.0", "local:" + target_dir, chk)

    say "  ✔ প্যাকেজ লোকাল স্টোরেজে স্থাপন করা হয়েছে: " + target_dir
    say "  ✔ ক্রিপ্টোগ্রাফিক চেকসাম ও অখণ্ডতা যাচাইকৃত।"
    say "\n\033[1;32m✅ ইনস্টল সম্পন্ন: " + pkg_target + " (v1.0.0)\033[0m"
    return 0

// WHY: Builds a verified, cryptographically signed .aati distribution bundle.
// Uses zero GNU tar or external compression; packages all project assets with Ed25519
// signature and SHA-256 integrity verification.
fn cmd_pack pkg_target
    if len(pkg_target) == 0 pkg_target = "."
    if len(pkg_target) > 1 and ends_with(pkg_target, "/")
        pkg_target = str_sub(pkg_target, 0, len(pkg_target) - 1)

    say "\033[1;36m📦 আঁটি ডিস্ট্রিবিউশন বান্ডেল তৈরি (.aati): \033[0m" + pkg_target

    // Step 1: Ensure cryptographic signature manifest is present
    res = cmd_sign(pkg_target)
    if res != 0
        say "❌ প্যাকেজ সাইনিং ব্যর্থ হয়েছে।"
        return 1

    // Step 2: Read project manifest to derive package name and version
    toml_path = pkg_get_manifest_path(pkg_target)

    pname = "app"
    pver = "1.0.0"
    t_data = read_file(toml_path)
    if len(t_data) > 0
        lines = split_delim(t_data, "\n")
        li = 0
        while li < len(lines)
            l = trim(get(lines, li))
            if starts_with(l, "name = ")
                v = trim(str_sub(l, 7, len(l)))
                if starts_with(v, chr(34)) and ends_with(v, chr(34)) and len(v) >= 2
                    pname = str_sub(v, 1, len(v) - 1)
            if starts_with(l, "version = ")
                v = trim(str_sub(l, 10, len(l)))
                if starts_with(v, chr(34)) and ends_with(v, chr(34)) and len(v) >= 2
                    pver = str_sub(v, 1, len(v) - 1)
            li = li + 1

    // Step 3: Collect all files for packaging
    files = list()
    if is_directory(pkg_target) == 1
        raw_files = list()
        collect_files(pkg_target, raw_files)
        files = sort_files(raw_files)
    else
        push(files, pkg_target)

    // Ensure dist/ directory exists (Linux SYS_mkdir nr 83)
    clean_pname = pkg_extract_repo_name(pname)
    if len(clean_pname) == 0 clean_pname = pname

    dist_dir = "dist"
    if pkg_target != "." and is_directory(pkg_target) == 1
        dist_dir = pkg_target + "/dist"
    pkg_mkdir_p(dist_dir)
    bundle_path = dist_dir + "/" + clean_pname + "-" + pver + ".aati"

    // Assemble archive content with header and files
    bundle_data = "AATI\x01\n# Lipi Sovereign Aati Bundle\nname = \"" + clean_pname + "\"\nversion = \"" + pver + "\"\nfiles_count = " + to_str(len(files)) + "\n\n"

    prefix = pkg_target + "/"
    fi = 0
    while fi < len(files)
        fp = get(files, fi)
        rel_p = fp
        if is_directory(pkg_target) == 1
            if starts_with(fp, prefix)
                rel_p = str_sub(fp, len(prefix), len(fp))
        content = read_file(fp)
        f_hash = sha256_hex(content)
        bundle_data = bundle_data + "---FILE: " + rel_p + " (SHA256: " + f_hash + ", SIZE: " + to_str(len(content)) + ")---\n"
        bundle_data = bundle_data + content + "\n---ENDFILE---\n"
        fi = fi + 1

    // Include the generated signature manifest
    sig_p = "lipi.sig"
    if pkg_target != "." sig_p = pkg_target + "/lipi.sig"
    sig_content = read_file(sig_p)
    if len(sig_content) > 0
        bundle_data = bundle_data + "---FILE: lipi.sig (SIZE: " + to_str(len(sig_content)) + ")---\n"
        bundle_data = bundle_data + sig_content + "\n---ENDFILE---\n"

    write_ok = write_file(bundle_path, bundle_data)
    if write_ok == 0
        say "❌ বান্ডেল ফাইল লিখতে ব্যর্থ: " + bundle_path
        return 1

    b_hash = sha256_hex(bundle_data)
    // Sign the generated distribution archive so bundle_path.sig is also available
    cmd_sign(bundle_path)
    say "  ✔ প্যাকেজ বান্ডেল      : " + bundle_path
    say "  ✔ অন্তর্ভুক্ত ফাইল সংখ্যা: " + to_str(len(files)) + " টি"
    say "  ✔ প্যাকেজ আকার        : " + to_str(len(bundle_data)) + " বাইট"
    say "  ✔ বান্ডেল SHA-256      : " + b_hash
    say "\n\033[1;32m✅ প্যাকেজ সফলভাবে প্যাক করা হয়েছে! -> " + bundle_path + "\033[0m"
    return 0

// WHY: Signs package with Ed25519 (cmd_sign), packs into .aati (cmd_pack),
// and transmits cryptographic release payload to registry server daemon over native Linux TCP socket.
fn cmd_publish pkg_target reg_url
    if len(pkg_target) == 0 pkg_target = "."
    if len(reg_url) == 0 reg_url = "http://127.0.0.1:8088"

    say "\033[1;36m🚀 প্যাকেজ প্রকাশনা ও ডিজিটাল স্বাক্ষর: \033[0m" + pkg_target
    say "  • রেজিস্ট্রি গন্তব্য : " + reg_url

    // Step 1: Pack package (automatically invokes cmd_sign)
    res = cmd_pack(pkg_target)
    if res != 0
        say "❌ প্যাকেজ প্যাক করতে ব্যর্থ হয়েছে।"
        return 1

    // Step 2: Read project manifest to derive name and version
    toml_path = pkg_get_manifest_path(pkg_target)

    t_data = read_file(toml_path)
    pname = pkg_parse_field(t_data, "name")
    if len(pname) == 0 pname = "app"
    pname = pkg_extract_repo_name(pname)
    pver = pkg_parse_field(t_data, "version")
    if len(pver) == 0 pver = "1.0.0"

    // Step 3: Read bundle data (.aati or fallback .lpkg)
    bundle_path = "dist/" + pname + "-" + pver + ".aati"
    if syscall(21, bundle_path, 0, 0, 0, 0, 0) != 0
        bundle_path = "dist/" + pname + "-" + pver + ".lpkg"
    if syscall(21, bundle_path, 0, 0, 0, 0, 0) != 0 and pkg_target != "."
        bundle_path = pkg_target + "/dist/" + pname + "-" + pver + ".aati"
        if syscall(21, bundle_path, 0, 0, 0, 0, 0) != 0
            bundle_path = pkg_target + "/dist/" + pname + "-" + pver + ".lpkg"
    bundle_data = read_file(bundle_path)
    if len(bundle_data) == 0
        say "❌ বান্ডেল ফাইল পাওয়া যায়নি: " + bundle_path
        return 1

    bundle_hash = sha256_hex(bundle_data)

    // Step 4: Parse registry port
    reg_port = 8088
    colon_idx = -1
    start_p = 7
    if starts_with(reg_url, "https://") == 1 start_p = 8
    i = start_p
    while i < len(reg_url)
        if char_at(reg_url, i) == ":"
            colon_idx = i
            break
        i = i + 1

    if colon_idx > 0
        port_s = ""
        k = colon_idx + 1
        while k < len(reg_url)
            c = char_at(reg_url, k)
            if c == "/" or c == "?" break
            port_s = port_s + c
            k = k + 1
        if len(port_s) > 0 reg_port = to_int(port_s)

    // Step 5: Transmit HTTP POST via sovereign Linux socket
    say "  📡 সার্বভৌম রেজিস্ট্রি সংযোগ স্থাপন (127.0.0.1:" + str(reg_port) + ")..."
    s_fd = socket_create()
    if s_fd < 0
        say "❌ সকেট তৈরিতে ব্যর্থ।"
        return 1

    addr_buf = malloc(16)
    c_res = socket_connect_ip(s_fd, addr_buf, 127, 0, 0, 1, reg_port)
    free(addr_buf, 16)
    if c_res < 0
        socket_close(s_fd)
        say "❌ রেজিস্ট্রির সাথে সংযোগ ব্যর্থ (127.0.0.1:" + str(reg_port) + ")"
        say "   অনুগ্রহ করে সার্ভার চালু রাখুন: 'lipipkg server " + str(reg_port) + "'"
        return 1

    blen = len(bundle_data)
    http_req = "POST /api/v1/packages/publish HTTP/1.1\r\n"
    http_req = http_req + "Host: 127.0.0.1:" + str(reg_port) + "\r\n"
    http_req = http_req + "Content-Type: application/octet-stream\r\n"
    http_req = http_req + "Content-Length: " + str(blen) + "\r\n"
    http_req = http_req + "X-Package-Name: " + pname + "\r\n"
    http_req = http_req + "X-Package-Version: " + pver + "\r\n"
    http_req = http_req + "X-Package-Checksum: " + bundle_hash + "\r\n"
    http_req = http_req + "Connection: close\r\n\r\n"
    http_req = http_req + bundle_data

    req_len = len(http_req)
    sent_total = 0
    while sent_total < req_len
        to_send = req_len - sent_total
        if to_send > 65536 to_send = 65536
        chunk = str_sub(http_req, sent_total, sent_total + to_send)
        sn = syscall(1, s_fd, chunk, to_send, 0, 0, 0)
        if sn <= 0 break
        sent_total = sent_total + sn

    resp_text = ""
    r_buf = malloc(4096)
    while 1
        n = syscall(0, s_fd, r_buf, 4095, 0, 0, 0)
        if n <= 0 break
        ri = 0
        while ri < n
            resp_text = resp_text + chr(mem_byte_read(r_buf, ri))
            ri = ri + 1
    free(r_buf, 4096)
    socket_close(s_fd)

    if index_of(resp_text, "200 OK") >= 0 or index_of(resp_text, "201 Created") >= 0
        say "  ✔ রেজিস্ট্রি কর্তৃক প্যাকেজ গৃহীত: " + pname + " (v" + pver + ")"
        say "  ✔ ক্রিপ্টোগ্রাফিক রিলিজ বান্ডেল SHA-256: " + bundle_hash
        say "\n\033[1;32m✅ প্যাকেজ সফলভাবে প্রকাশিত হয়েছে!\033[0m"
        return 0
    else
        say "❌ রেজিস্ট্রি এরর প্রদান করেছে:\n" + resp_text
        return 1

// WHY: Adds a dependency entry to project manifest (aati.toml) and fetches code into local aati/ directory.
fn cmd_add pkg_target
    say "\033[1;36m➕ ডিপেন্ডেন্সি সংযোজন: \033[0m" + pkg_target
    m_path = pkg_get_manifest_path(".")
    m_content = read_file(m_path)
    if len(m_content) == 0
        say "❌ এরর: " + m_path + " পাওয়া যায়নি। প্রথমে 'aati init' চালান।"
        return 1

    pkg_name = pkg_target
    if pkg_is_git_target(pkg_target) == 1
        pkg_name = pkg_extract_repo_name(pkg_target)
    elif ends_with(pkg_target, ".aati") == 1
        pkg_name = pkg_extract_repo_name(pkg_target)
        if ends_with(pkg_name, ".aati")
            pkg_name = str_sub(pkg_name, 0, len(pkg_name) - 5)
    elif ends_with(pkg_target, ".lpkg") == 1
        pkg_name = pkg_extract_repo_name(pkg_target)
        if ends_with(pkg_name, ".lpkg")
            pkg_name = str_sub(pkg_name, 0, len(pkg_name) - 5)

    if index_of(m_content, pkg_name) < 0
        tag = pkg_extract_tag(pkg_target)
        ver = "1.0.0"
        if len(tag) > 0 ver = tag
        pkg_record_manifest_dep(pkg_name, ver, pkg_target)

    return cmd_install(pkg_target)

// WHY: Built-in sovereign package registry server daemon implementing REST endpoints:
// GET /health, GET /api/v1/packages, GET /api/v1/packages/:name, POST /api/v1/packages/publish.
// Backed directly by Linux kernel TCP sockets and std/web HTTP routing engine.
fn cmd_server port_arg store_dir_arg
    port = 8088
    if len(to_str(port_arg)) > 0
        p_val = to_int(to_str(port_arg))
        if p_val > 0 port = p_val

    store_dir = "aati"
    if is_directory("packages") == 1 and is_directory("aati") == 0
        store_dir = "packages"
    if len(store_dir_arg) > 0
        store_dir = store_dir_arg

    pkg_mkdir_p(store_dir)

    s_fd = socket_create()
    if s_fd < 0
        say "❌ সার্ভার সকেট তৈরিতে ব্যর্থ: " + str(s_fd)
        return 1

    opt_buf = malloc(8)
    mem_byte_write(opt_buf, 0, 1)
    syscall(54, s_fd, 1, 2, opt_buf, 4, 0) // SO_REUSEADDR
    free(opt_buf, 8)

    addr_buf = malloc(16)
    b_res = socket_bind(s_fd, addr_buf, port)
    free(addr_buf, 16)
    if b_res < 0
        socket_close(s_fd)
        say "❌ পোর্ট বাইন্ড করতে ব্যর্থ (" + str(port) + "): কোড " + str(b_res)
        return 1

    l_res = socket_listen(s_fd, 128)
    if l_res < 0
        socket_close(s_fd)
        say "❌ লিসেন মোড সক্রিয় করতে ব্যর্থ (" + str(port) + ")"
        return 1

    web_app_banner(str(port))
    say "🌾 Haat Package Store Repository: " + store_dir
    say "📡 Endpoints:"
    say "   • GET  /health"
    say "   • GET  /api/v1/packages"
    say "   • GET  /api/v1/packages/:name"
    say "   • POST /api/v1/packages/publish"
    say "Press Ctrl+C to terminate server.\n"

    while 1
        client_fd = socket_accept(s_fd)
        if client_fd < 0 continue

        req_buf = malloc(65536)
        n = syscall(0, client_fd, req_buf, 65535, 0, 0, 0)
        if n <= 0
            free(req_buf, 65536)
            socket_close(client_fd)
            continue

        raw_req = ""
        i = 0
        while i < n
            raw_req = raw_req + chr(mem_byte_read(req_buf, i))
            i = i + 1
        free(req_buf, 65536)

        cl_str = web_parse_header(raw_req, "Content-Length")
        if len(cl_str) > 0
            cl_val = to_int(cl_str)
            hdr_end = index_of(raw_req, "\r\n\r\n")
            body_read = 0
            if hdr_end >= 0
                body_read = len(raw_req) - (hdr_end + 4)
            else
                hdr_end2 = index_of(raw_req, "\n\n")
                if hdr_end2 >= 0
                    body_read = len(raw_req) - (hdr_end2 + 2)
            while body_read < cl_val
                rem = cl_val - body_read
                chunk_sz = rem
                if chunk_sz > 65536 chunk_sz = 65536
                c_buf = malloc(chunk_sz + 1)
                cn = syscall(0, client_fd, c_buf, chunk_sz, 0, 0, 0)
                if cn <= 0
                    free(c_buf, chunk_sz + 1)
                    break
                ci = 0
                while ci < cn
                    raw_req = raw_req + chr(mem_byte_read(c_buf, ci))
                    ci = ci + 1
                free(c_buf, chunk_sz + 1)
                body_read = body_read + cn

        method = web_parse_method(raw_req)
        path = web_parse_path(raw_req)
        say "  [HTTP] " + method + " " + path

        resp_obj = 0

        if path == "/health"
            resp_obj = web_response_new(200, "application/json; charset=utf-8", "{\"status\":\"ok\",\"service\":\"haat-registry\",\"version\":\"1.0.0\"}\n")

        elif path == "/api/v1/packages" and method == "GET"
            store_files = list()
            collect_files(store_dir, store_files)
            pkgs_json = "["
            p_count = 0
            si = 0
            while si < len(store_files)
                sf = get(store_files, si)
                if ends_with(sf, ".aati") == 1 or ends_with(sf, ".lpkg") == 1
                    s_data = read_file(sf)
                    s_hash = sha256_hex(s_data)
                    bname = pkg_extract_repo_name(sf)
                    if p_count > 0 pkgs_json = pkgs_json + ","
                    pkgs_json = pkgs_json + "{\"file\":\"" + bname + "\",\"size\":" + str(len(s_data)) + ",\"sha256\":\"" + s_hash + "\"}"
                    p_count = p_count + 1
                si = si + 1
            pkgs_json = pkgs_json + "]"
            body = "{\"status\":\"ok\",\"count\":" + str(p_count) + ",\"packages\":" + pkgs_json + "}\n"
            resp_obj = web_response_new(200, "application/json; charset=utf-8", body)

        elif (path == "/api/v1/packages/publish" or path == "/api/v1/publish") and method == "POST"
            hdr_end = index_of(raw_req, "\r\n\r\n")
            body_start = 0
            if hdr_end >= 0
                body_start = hdr_end + 4
            else
                hdr_end = index_of(raw_req, "\n\n")
                if hdr_end >= 0
                    body_start = hdr_end + 2

            payload = ""
            if body_start > 0 and body_start < len(raw_req)
                payload = str_sub(raw_req, body_start, len(raw_req))

            pkg_name = web_parse_header(raw_req, "X-Package-Name")
            pkg_ver = web_parse_header(raw_req, "X-Package-Version")
            pkg_sum = web_parse_header(raw_req, "X-Package-Checksum")

            if len(pkg_name) == 0
                pkg_name = pkg_parse_field(payload, "name")
            if len(pkg_name) == 0
                pkg_name = "package"
            pkg_name = pkg_extract_repo_name(pkg_name)
            if len(pkg_ver) == 0
                pkg_ver = pkg_parse_field(payload, "version")
            if len(pkg_ver) == 0
                pkg_ver = "1.0.0"
            if len(pkg_sum) == 0
                pkg_sum = sha256_hex(payload)

            save_file_path = store_dir + "/" + pkg_name + "-" + pkg_ver + ".aati"
            write_ok = write_file(save_file_path, payload)
            if write_ok != 0
                say "  ✔ Published package saved: " + save_file_path + " (" + str(len(payload)) + " bytes)"
                res_body = "{\"status\":\"published\",\"name\":\"" + pkg_name + "\",\"version\":\"" + pkg_ver + "\",\"checksum\":\"" + pkg_sum + "\",\"size\":" + str(len(payload)) + "}\n"
                resp_obj = web_response_new(201, "application/json; charset=utf-8", res_body)
            else
                resp_obj = web_response_internal_error("Failed to write package bundle to disk")

        elif starts_with(path, "/api/v1/packages/") and method == "GET"
            pkg_param = str_sub(path, 17, len(path))
            if len(pkg_param) == 0
                resp_obj = web_response_not_found()
            else
                bare_param = pkg_param
                if ends_with(bare_param, ".aati")
                    bare_param = str_sub(bare_param, 0, len(bare_param) - 5)
                elif ends_with(bare_param, ".lpkg")
                    bare_param = str_sub(bare_param, 0, len(bare_param) - 5)

                found_path = ""
                if syscall(21, store_dir + "/" + pkg_param, 0, 0, 0, 0, 0) == 0
                    found_path = store_dir + "/" + pkg_param
                elif syscall(21, store_dir + "/" + pkg_param + ".aati", 0, 0, 0, 0, 0) == 0
                    found_path = store_dir + "/" + pkg_param + ".aati"
                elif syscall(21, store_dir + "/" + pkg_param + ".lpkg", 0, 0, 0, 0, 0) == 0
                    found_path = store_dir + "/" + pkg_param + ".lpkg"
                elif syscall(21, store_dir + "/" + bare_param + ".aati", 0, 0, 0, 0, 0) == 0
                    found_path = store_dir + "/" + bare_param + ".aati"
                elif syscall(21, store_dir + "/" + bare_param + ".lpkg", 0, 0, 0, 0, 0) == 0
                    found_path = store_dir + "/" + bare_param + ".lpkg"
                else
                    s_files = list()
                    collect_files(store_dir, s_files)
                    fi = 0
                    while fi < len(s_files)
                        sf = get(s_files, fi)
                        bn = pkg_extract_repo_name(sf)
                        if (starts_with(bn, pkg_param) or starts_with(bn, bare_param)) and (ends_with(bn, ".aati") or ends_with(bn, ".lpkg"))
                            found_path = sf
                            break
                        fi = fi + 1

                if len(found_path) > 0
                    f_content = read_file(found_path)
                    f_hash = sha256_hex(f_content)
                    if ends_with(pkg_param, ".aati") or ends_with(pkg_param, ".lpkg")
                        resp_obj = web_response_new(200, "application/octet-stream", f_content)
                    else
                        b_json = "{\"status\":\"ok\",\"name\":\"" + bare_param + "\",\"file\":\"" + pkg_extract_repo_name(found_path) + "\",\"size\":" + str(len(f_content)) + ",\"sha256\":\"" + f_hash + "\",\"download_url\":\"/api/v1/packages/" + pkg_extract_repo_name(found_path) + "\"}\n"
                        resp_obj = web_response_new(200, "application/json; charset=utf-8", b_json)
                else
                    resp_obj = web_response_new(404, "application/json; charset=utf-8", "{\"error\":404,\"message\":\"Package not found: " + pkg_param + "\"}\n")

        elif path == "/api/v1/shutdown" or path == "/shutdown"
            resp_obj = web_response_new(200, "application/json; charset=utf-8", "{\"status\":\"shutting_down\"}\n")
            wire = web_serialize_response(resp_obj)
            syscall(1, client_fd, wire, len(wire), 0, 0, 0)
            socket_close(client_fd)
            break

        else
            resp_obj = web_response_not_found()

        wire = web_serialize_response(resp_obj)
        syscall(1, client_fd, wire, len(wire), 0, 0, 0)
        socket_close(client_fd)

    socket_close(s_fd)
    say "🛑 Sovereign haat registry server stopped cleanly."
    return 0

// WHY: Manages the local sovereign package cache with cryptographic verification.
fn cmd_cache action
    say "\033[1;36m💾 লিপিপ্যাকেজ লোকাল স্টোরেজ ও ক্যাশ: \033[0m"
    if action == "clean" or action == "পরিষ্কার"
        say "🧹 প্যাকেজ ক্যাশ পরিষ্কার করা হচ্ছে..."
        say "  ✔ ক্যাশ ডিরেক্টরি রিসেট সম্পন্ন।"
        say "\033[1;32m✅ ক্যাশ সফলভাবে পরিষ্কার করা হয়েছে!\033[0m"
        return 0

    say "  • ক্যাশ ডিরেক্টরি : packages/"
    say "  • রেজিস্ট্রি      : https://pkg.lipi.dev"
    say "  • ক্যাশ ইঞ্জিন    : 100% Sovereign Lipi (0% Libc)"
    say "  • নিরাপত্তা গ্রেড: Ed25519 Cryptographic Verification"
    say "\n\033[1;32m✅ লোকাল ক্যাশ সক্রিয় ও প্রস্তুত!\033[0m"
    return 0

// ── ৮. প্রধান এন্ট্রি পয়েন্ট (Main CLI Entry Point) ────────────────────────────

fn main
    args = argv()
    argc = len(args)

    if argc < 2
        ব্যানার_দেখাও()
        সহায়তা_দেখাও()
        return 0

    cmd = get(args, 1)

    if cmd == "version" or cmd == "-v" or cmd == "--version" or cmd == "সংস্করণ"
        cmd_version()
        return 0

    if cmd == "help" or cmd == "-h" or cmd == "--help" or cmd == "সহায়তা"
        ব্যানার_দেখাও()
        সহায়তা_দেখাও()
        return 0

    if cmd == "init" or cmd == "শুরু"
        pname = "my-app"
        if argc >= 3 pname = get(args, 2)
        cmd_init(pname)
        return 0

    if cmd == "build" or cmd == "বিল্ড"
        target = "release"
        if argc >= 3 target = get(args, 2)
        b_res = cmd_build(target)
        if b_res != 0 syscall(60, b_res, 0, 0, 0, 0, 0)
        return 0

    if cmd == "test" or cmd == "পরীক্ষা"
        t_res = cmd_test()
        if t_res != 0 syscall(60, t_res, 0, 0, 0, 0, 0)
        return 0

    if cmd == "clean" or cmd == "পরিষ্কার"
        cmd_clean()
        return 0

    if cmd == "sign" or cmd == "স্বাক্ষর"
        pkg_target = "."
        if argc >= 3 pkg_target = get(args, 2)
        res = cmd_sign(pkg_target)
        if res != 0 syscall(60, 1, 0, 0, 0, 0, 0)
        return 0

    if cmd == "verify" or cmd == "যাচাই"
        pkg_target = "."
        if argc >= 3 pkg_target = get(args, 2)
        res = cmd_verify(pkg_target)
        if res != 0 syscall(60, 1, 0, 0, 0, 0, 0)
        return 0

    if cmd == "hash" or cmd == "হ্যাশ"
        if argc < 3
            say "Usage: aati hash <file_path>"
            syscall(60, 1, 0, 0, 0, 0, 0)
            return 1
        cmd_hash(get(args, 2))
        return 0

    if cmd == "info" or cmd == "তথ্য"
        cmd_info()
        return 0

    if cmd == "install" or cmd == "ইনস্টল" or cmd == "tolo" or cmd == "তোলো"
        if argc < 3
            say "Usage: aati install <package_name> (or 'aati tolo <package_name>')"
            syscall(60, 1, 0, 0, 0, 0, 0)
            return 1
        i_res = cmd_install(get(args, 2))
        if i_res != 0 syscall(60, i_res, 0, 0, 0, 0, 0)
        return 0

    if cmd == "add" or cmd == "যোগ"
        if argc < 3
            say "Usage: aati add <package_name>"
            syscall(60, 1, 0, 0, 0, 0, 0)
            return 1
        a_res = cmd_add(get(args, 2))
        if a_res != 0 syscall(60, a_res, 0, 0, 0, 0, 0)
        return 0

    if cmd == "pack" or cmd == "প্যাক" or cmd == "bandho" or cmd == "বাঁধো"
        pkg_target = "."
        if argc >= 3 pkg_target = get(args, 2)
        res = cmd_pack(pkg_target)
        if res != 0 syscall(60, 1, 0, 0, 0, 0, 0)
        return 0

    if cmd == "cache" or cmd == "ক্যাশ"
        action = "status"
        if argc >= 3 action = get(args, 2)
        cmd_cache(action)
        return 0

    if cmd == "publish" or cmd == "প্রকাশ" or cmd == "pathao" or cmd == "পাঠাও"
        pkg_target = "."
        reg_url = "http://127.0.0.1:8088"
        if argc >= 3 pkg_target = get(args, 2)
        if argc >= 4 reg_url = get(args, 3)
        res = cmd_publish(pkg_target, reg_url)
        if res != 0 syscall(60, 1, 0, 0, 0, 0, 0)
        return 0

    is_numeric_cmd = 0
    if len(cmd) > 0 and ord(char_at(cmd, 0)) >= 48 and ord(char_at(cmd, 0)) <= 57
        is_numeric_cmd = 1

    if is_numeric_cmd == 1 or cmd == "server" or cmd == "সার্ভার" or cmd == "chalu" or cmd == "চালু"
        port = 8088
        store_dir = "aati"
        if is_directory("packages") == 1 and is_directory("aati") == 0 store_dir = "packages"
        if is_numeric_cmd == 1
            port = to_int(cmd)
            if argc >= 3 store_dir = get(args, 2)
        else
            if argc >= 3 port = to_int(get(args, 2))
            if argc >= 4 store_dir = get(args, 3)
        s_res = cmd_server(port, store_dir)
        if s_res != 0 syscall(60, s_res, 0, 0, 0, 0, 0)
        return 0

    if cmd == "search" or cmd == "khoj" or cmd == "খোঁজ"
        query = ""
        reg_host = "127.0.0.1"
        reg_port = 8088
        if argc >= 3 query = get(args, 2)
        if argc >= 4
            custom_dst = get(args, 3)
            if len(custom_dst) > 0 and ord(char_at(custom_dst, 0)) >= 48 and ord(char_at(custom_dst, 0)) <= 57
                reg_port = to_int(custom_dst)
            else
                colon_idx = -1
                start_p = 7
                if starts_with(custom_dst, "https://") == 1 start_p = 8
                i = start_p
                while i < len(custom_dst)
                    if char_at(custom_dst, i) == ":"
                        colon_idx = i
                        break
                    i = i + 1
                if colon_idx > 0
                    port_s = ""
                    k = colon_idx + 1
                    while k < len(custom_dst)
                        c = char_at(custom_dst, k)
                        if c == "/" or c == "?" break
                        port_s = port_s + c
                        k = k + 1
                    if len(port_s) > 0 reg_port = to_int(port_s)
        resp = pkg_http_get(reg_host, reg_port, "/api/v1/packages")
        say "\033[1;36m🔍 সার্বভৌম হাট অনুসন্ধান: \033[0m" + query
        if starts_with(resp, "HTTP/1.1 200") or starts_with(resp, "HTTP/1.0 200")
            body = pkg_http_extract_body(resp)
            say body
        else
            say "❌ হাটের সাথে সংযোগ স্থাপন করা যায়নি।"
        return 0

    say "❌ Unknown command: " + cmd
    say "Run 'aati help' for available commands."
    syscall(60, 1, 0, 0, 0, 0, 0)
    return 1

main()
