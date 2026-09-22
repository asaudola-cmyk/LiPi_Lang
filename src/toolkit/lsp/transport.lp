// ==============================================================================
// 🧠 LIPI UNIFIED TOOLKIT: LSP TRANSPORT STREAM ENGINE (src/toolkit/lsp/transport.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | LSP 3.17 Base Framing | Zero Libc / Zero C
// ==============================================================================
//
// WHY THIS MODULE:
// The Language Server Protocol (LSP) operates over standard input/output (stdio)
// streams using strict HTTP-like Content-Length header framing.
// Architectural imperatives:
// 1. Reading from STDIN (fd 0) must parse "Content-Length: <N>\r\n\r\n" cleanly.
// 2. Reading payload must consume exact byte quantities, avoiding buffer overruns.
// 3. Writing to STDOUT (fd 1) must emit valid Content-Length framing.
// 4. All diagnostic logs MUST be routed strictly to STDERR (fd 2) to avoid
//    corrupting the IDE client's JSON-RPC frame parser.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Header Parsing Utilities ───────────────────────────────────────────────

// WHY: Case-insensitive search helper to identify "Content-Length:" header field.
fn lsp_find_header_key header_text key
    hlen = len(header_text)
    klen = len(key)
    if klen > hlen return -1

    i = 0
    while i <= (hlen - klen)
        matched = 1
        j = 0
        while j < klen
            ch1 = ord(char_at(header_text, i + j))
            ch2 = ord(char_at(key, j))
            // Case-insensitive ASCII normalization (A-Z -> a-z)
            if ch1 >= 65 and ch1 <= 90 ch1 = ch1 + 32
            if ch2 >= 65 and ch2 <= 90 ch2 = ch2 + 32
            if ch1 != ch2
                matched = 0
                break
            j = j + 1

        if matched == 1
            return i
        i = i + 1
    return -1

// WHY: Extracts integer byte count following "Content-Length: " header token.
fn lsp_parse_content_length header_str
    pos = lsp_find_header_key(header_str, "content-length:")
    if pos < 0 return 0

    hlen = len(header_str)
    i = pos + 15 // Length of "content-length:"

    // Skip horizontal whitespace
    while i < hlen and (char_at(header_str, i) == " " or char_at(header_str, i) == "\t")
        i = i + 1

    val = 0
    has_digits = 0
    while i < hlen
        code = ord(char_at(header_str, i))
        if code >= 48 and code <= 57
            val = (val * 10) + (code - 48)
            has_digits = 1
            i = i + 1
        else
            break

    if has_digits == 0 return 0
    return val

// ── 2. Standard Input Framing Reader ──────────────────────────────────────────

// WHY: Reads single JSON-RPC frame from STDIN (fd 0) enforcing strict Content-Length.
// Returns JSON payload string, or empty string on EOF / fatal stream termination.
fn lsp_transport_read_frame
    byte_buf = malloc(8)
    header = ""

    b0 = 0
    b1 = 0
    b2 = 0
    b3 = 0
    header_done = 0

    // Stream header byte-by-byte until delimiter (\r\n\r\n or \n\n)
    while header_done == 0
        // Linux SYS_read (syscall 0) from STDIN (fd 0)
        n = syscall(0, 0, byte_buf, 1, 0, 0, 0)
        if n <= 0
            free(byte_buf, 8)
            return "" // EOF reached

        b = mem_byte_read(byte_buf, 0)
        header = header + chr(b)

        b3 = b2
        b2 = b1
        b1 = b0
        b0 = b

        // Check for \r\n\r\n (13, 10, 13, 10)
        if b3 == 13 and b2 == 10 and b1 == 13 and b0 == 10
            header_done = 1
        // Check for \n\n (10, 10)
        elif b1 == 10 and b0 == 10
            header_done = 1

    free(byte_buf, 8)

    content_length = lsp_parse_content_length(header)
    if content_length <= 0
        return ""

    // Read body content in chunks
    chunk_size = 4096
    chunk_buf = malloc(chunk_size)
    body = ""
    bytes_read = 0

    while bytes_read < content_length
        remaining = content_length - bytes_read
        to_read = chunk_size
        if remaining < chunk_size
            to_read = remaining

        n = syscall(0, 0, chunk_buf, to_read, 0, 0, 0)
        if n <= 0
            break

        i = 0
        while i < n
            b = mem_byte_read(chunk_buf, i)
            body = body + chr(b)
            i = i + 1

        bytes_read = bytes_read + n

    free(chunk_buf, chunk_size)
    return body

// ── 3. Standard Output Framing Writer ─────────────────────────────────────────

// WHY: Wraps arbitrary JSON body with LSP Content-Length header and emits to STDOUT (fd 1).
fn lsp_transport_send_frame body_json
    body_len = len(body_json)
    header = "Content-Length: " + str(body_len) + "\r\n\r\n"

    // Linux SYS_write (syscall 1) to STDOUT (fd 1)
    syscall(1, 1, header, len(header), 0, 0, 0)
    syscall(1, 1, body_json, body_len, 0, 0, 0)
    return 0

// ── 4. Isolated Diagnostic Logging (STDERR) ───────────────────────────────────

// WHY: Writes server logs exclusively to STDERR (fd 2).
// Writing to STDOUT would corrupt JSON-RPC 2.0 communication with IDEs (VS Code, Neovim).
fn lsp_transport_log msg
    line = "[lipilsp] " + msg + "\n"
    syscall(1, 2, line, len(line), 0, 0, 0)
    return 0
