// ==============================================================================
// 🧠 লিপি LSP — Language Server Protocol Implementation (JSON-RPC 2.0)
// লিপি প্রথম ১.০.০ | Lipi Sovereign Language Server (First 1.0.0)
// File: src/tools/lipilsp.lp
//
// WHY এই মডিউল:
//   IDE support requires LSP (used by VS Code, Neovim, Emacs, Helix, Fleet, etc.).
//   LSP enables auto-complete, hover documentation, syntax formatting, and error diagnostics.
//   Standard I/O communication requires strict JSON-RPC 2.0 Content-Length framing.
//   All debug logs are written to STDERR (fd=2) to maintain a pristine JSON-RPC stream on STDOUT (fd=1).
//
// Protocol:
//   JSON-RPC 2.0 over standard I/O (stdio)
//   Header: Content-Length: <bytes>\r\n\r\n<json-body>
//
// Supported Capabilities:
//   - initialize / initialized
//   - textDocument/didOpen, textDocument/didChange, textDocument/didClose
//   - textDocument/completion (full bilingual keywords & stdlib module suggestions)
//   - textDocument/hover (keyword & stdlib docstrings)
//   - textDocument/formatting (automatic 4-space indentation alignment)
//   - shutdown / exit
// ==============================================================================

include "utso/memory"
include "utso/io"
include "utso/string"

// ─── LSP Identity & Protocol ──────────────────────────────────────────────────
fn lsp_protocol_version = "3.17"
fn lsp_server_version  = "1.0.0"
fn lsp_server_name     = "lipilsp"
CHUNK_READ_SIZE        = 512

// ─── Logging to STDERR (fd 2) ─────────────────────────────────────────────────
// WHY: In stdio LSP mode, STDOUT is strictly reserved for JSON-RPC messages.
// Any extraneous stdout writes would corrupt the client parser framing.
fn lsp_log msg
    line = "[lipilsp] " + msg + "\n"
    syscall(1, 2, line, len(line))
    return 0

// ─── String Search & Slicing Helpers ──────────────────────────────────────────
// WHY: Pure Lipi substring finder for JSON-RPC message routing and parameter extraction.
fn str_find_from s sub start
    slen = len(s)
    sublen = len(sub)
    if sublen == 0 return start
    if slen < sublen return -1
    i = start
    while i <= slen - sublen
        matched = 1
        j = 0
        while j < sublen and matched == 1
            if char_at(s, i + j) != char_at(sub, j)
                matched = 0
            j = j + 1
        if matched == 1
            return i
        i = i + 1
    return -1

// ─── JSON Value Extractors ────────────────────────────────────────────────────
// WHY: Efficiently parses JSON-RPC headers, methods, IDs, URIs, and parameters
// without external C JSON library dependencies (100% Sovereign Lipi).
fn _lsp_hex_digit_val ch
    o = ord(ch)
    if o >= 48 and o <= 57 return o - 48
    if o >= 65 and o <= 70 return o - 55
    if o >= 97 and o <= 102 return o - 87
    return -1

fn _lsp_utf8_encode cp
    if cp < 0 return ""
    if cp < 128 return chr(cp)
    if cp < 2048
        return chr(192 | ((cp >> 6) & 31)) + chr(128 | (cp & 63))
    if cp < 65536
        return chr(224 | ((cp >> 12) & 15)) + chr(128 | ((cp >> 6) & 63)) + chr(128 | (cp & 63))
    return chr(240 | ((cp >> 18) & 7)) + chr(128 | ((cp >> 12) & 63)) + chr(128 | ((cp >> 6) & 63)) + chr(128 | (cp & 63))

fn _lsp_parse_hex4 s pos
    if pos + 4 > len(s) return -1
    v0 = _lsp_hex_digit_val(char_at(s, pos))
    v1 = _lsp_hex_digit_val(char_at(s, pos + 1))
    v2 = _lsp_hex_digit_val(char_at(s, pos + 2))
    v3 = _lsp_hex_digit_val(char_at(s, pos + 3))
    if v0 < 0 or v1 < 0 or v2 < 0 or v3 < 0 return -1
    return (v0 * 4096) + (v1 * 256) + (v2 * 16) + v3

fn json_extract_str_value json key
    needle = "\"" + key + "\""
    nlen = len(needle)
    jlen = len(json)
    search_from = 0
    while search_from < jlen
        pos = str_find_from(json, needle, search_from)
        if pos < 0 return ""
        k = pos + nlen
        while k < jlen and (char_at(json, k) == " " or char_at(json, k) == "\t" or char_at(json, k) == "\r" or char_at(json, k) == "\n")
            k = k + 1
        if k < jlen and char_at(json, k) == ":"
            q1 = k + 1
            while q1 < jlen and (char_at(json, q1) == " " or char_at(json, q1) == "\t" or char_at(json, q1) == "\r" or char_at(json, q1) == "\n")
                q1 = q1 + 1
            if q1 < jlen and char_at(json, q1) == "\""
                j = q1 + 1
                q2 = -1
                while j < jlen and q2 < 0
                    c = char_at(json, j)
                    if c == "\\"
                        j = j + 2
                    elif c == "\""
                        q2 = j
                    else
                        j = j + 1
                if q2 >= 0
                    return str_sub(json, q1 + 1, q2)
        search_from = pos + nlen
    return ""

fn json_extract_id json
    needle = "\"id\""
    pos = str_find_from(json, needle, 0)
    if pos < 0 return "null"
    colon = str_find_from(json, ":", pos + len(needle))
    if colon < 0 return "null"
    
    j = colon + 1
    jlen = len(json)
    while j < jlen and (char_at(json, j) == " " or char_at(json, j) == "\t" or char_at(json, j) == "\r" or char_at(json, j) == "\n")
        j = j + 1
    if j >= jlen return "null"
    
    first_c = char_at(json, j)
    if first_c == "\""
        q2 = str_find_from(json, "\"", j + 1)
        if q2 < 0 return "null"
        return str_sub(json, j, q2 + 1)
    
    k = j
    while k < jlen
        c = char_at(json, k)
        if c == "," or c == "}" or c == " " or c == "\t" or c == "\r" or c == "\n"
            return str_sub(json, j, k)
        k = k + 1
    return str_sub(json, j, k)

fn json_extract_int_value json key
    needle = "\"" + key + "\""
    pos = str_find_from(json, needle, 0)
    if pos < 0 return 0
    colon = str_find_from(json, ":", pos + len(needle))
    if colon < 0 return 0
    k = colon + 1
    jlen = len(json)
    while k < jlen and (char_at(json, k) == " " or char_at(json, k) == "\t" or char_at(json, k) == "\r" or char_at(json, k) == "\n")
        k = k + 1
    val = 0
    while k < jlen
        c = ord(char_at(json, k))
        if c >= 48 and c <= 57
            val = val * 10 + (c - 48)
            k = k + 1
        else
            return val
    return val

fn json_escape s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        if c == "\\"
            res = res + "\\\\"
        else
            if c == "\""
                res = res + "\\\""
            else
                if c == "\n"
                    res = res + "\\n"
                else
                    if c == "\r"
                        res = res + "\\r"
                    else
                        if c == "\t"
                            res = res + "\\t"
                        else
                            res = res + c
        i = i + 1
    return res

fn json_unescape s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        if c == "\\" and i + 1 < slen
            next_c = char_at(s, i + 1)
            if next_c == "n"
                res = res + "\n"
                i = i + 2
            elif next_c == "r"
                res = res + "\r"
                i = i + 2
            elif next_c == "t"
                res = res + "\t"
                i = i + 2
            elif next_c == "\""
                res = res + "\""
                i = i + 2
            elif next_c == "\\"
                res = res + "\\"
                i = i + 2
            elif next_c == "/"
                res = res + "/"
                i = i + 2
            elif next_c == "u" and i + 6 <= slen
                cp = _lsp_parse_hex4(s, i + 2)
                if cp >= 55296 and cp <= 56319 and i + 12 <= slen and char_at(s, i + 6) == "\\" and char_at(s, i + 7) == "u"
                    lo = _lsp_parse_hex4(s, i + 8)
                    if lo >= 56320 and lo <= 57343
                        full_cp = 65536 + ((cp - 55296) * 1024) + (lo - 56320)
                        res = res + _lsp_utf8_encode(full_cp)
                        i = i + 12
                        continue
                if cp >= 0
                    res = res + _lsp_utf8_encode(cp)
                    i = i + 6
                else
                    res = res + next_c
                    i = i + 2
            else
                res = res + next_c
                i = i + 2
        else
            res = res + c
            i = i + 1
    return res

fn _lsp_utf8_step_bytes b
    if b < 128 return 1
    if b < 224 return 2
    if b < 240 return 3
    return 4

fn _lsp_byte_col_to_utf16 text line_start target_byte
    u16 = 0
    p = line_start
    n = len(text)
    while p < target_byte and p < n
        b = ord(char_at(text, p)) & 255
        step = _lsp_utf8_step_bytes(b)
        if b >= 240
            u16 = u16 + 2
        else
            u16 = u16 + 1
        p = p + step
    return u16

fn _lsp_utf16_col_to_byte text line_start line_end target_u16
    u16 = 0
    p = line_start
    while p < line_end and u16 < target_u16
        b = ord(char_at(text, p)) & 255
        step = _lsp_utf8_step_bytes(b)
        if b >= 240
            u16 = u16 + 2
        else
            u16 = u16 + 1
        p = p + step
    return p

// ─── Sovereign Diagnostics & Symbol Collector ─────────────────────────────────
// WHY: Validates literal quote termination, brackets/parens/braces balance, and unmatched block closers with exact UTF-16 LSP columns.
fn lsp_compute_diagnostics text
    n = len(text)
    if n == 0
        return "[]"

    diags = "["
    diag_cnt = 0
    line = 0
    line_start = 0
    in_str = 0
    str_start_byte = 0
    in_comment = 0
    paren_depth = 0
    paren_line = 0
    paren_col = 0
    brace_depth = 0
    brace_line = 0
    brace_col = 0
    bracket_depth = 0
    bracket_line = 0
    bracket_col = 0
    i = 0

    while i < n
        b = ord(char_at(text, i)) & 255
        step = _lsp_utf8_step_bytes(b)
        c = char_at(text, i)
        if in_comment == 1
            if c == "\n"
                in_comment = 0
                line = line + 1
                line_start = i + 1
            i = i + step
            continue

        if in_str == 1
            if c == "\\" and i + 1 < n
                nx = char_at(text, i + 1)
                if nx == "\n"
                    sc_u16 = _lsp_byte_col_to_utf16(text, line_start, str_start_byte)
                    ec_u16 = _lsp_byte_col_to_utf16(text, line_start, i + 1)
                    if diag_cnt > 0 diags = diags + ","
                    diags = diags + "{\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(sc_u16) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(ec_u16) + "}},\"severity\":1,\"source\":\"lipilsp\",\"message\":\"Unterminated string literal\"}"
                    diag_cnt = diag_cnt + 1
                    in_str = 0
                    line = line + 1
                    line_start = i + 2
                i = i + 2
                continue
            if c == "\""
                in_str = 0
                i = i + 1
                continue
            if c == "\n"
                sc_u16 = _lsp_byte_col_to_utf16(text, line_start, str_start_byte)
                ec_u16 = _lsp_byte_col_to_utf16(text, line_start, i)
                if diag_cnt > 0 diags = diags + ","
                diags = diags + "{\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(sc_u16) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(ec_u16) + "}},\"severity\":1,\"source\":\"lipilsp\",\"message\":\"Unterminated string literal\"}"
                diag_cnt = diag_cnt + 1
                in_str = 0
                line = line + 1
                line_start = i + 1
                i = i + 1
                continue
            i = i + step
            continue

        if c == "/" and i + 1 < n and char_at(text, i + 1) == "/"
            in_comment = 1
            i = i + 2
            continue
        if c == "\""
            in_str = 1
            str_start_byte = i
            i = i + 1
            continue
        if c == "("
            if paren_depth == 0
                paren_line = line
                paren_col = _lsp_byte_col_to_utf16(text, line_start, i)
            paren_depth = paren_depth + 1
        elif c == ")"
            if paren_depth <= 0
                c16 = _lsp_byte_col_to_utf16(text, line_start, i)
                if diag_cnt > 0 diags = diags + ","
                diags = diags + "{\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(c16) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(c16 + 1) + "}},\"severity\":1,\"source\":\"lipilsp\",\"message\":\"Unmatched closing parenthesis ')'\"}"
                diag_cnt = diag_cnt + 1
            else
                paren_depth = paren_depth - 1
        elif c == "["
            if bracket_depth == 0
                bracket_line = line
                bracket_col = _lsp_byte_col_to_utf16(text, line_start, i)
            bracket_depth = bracket_depth + 1
        elif c == "]"
            if bracket_depth <= 0
                c16 = _lsp_byte_col_to_utf16(text, line_start, i)
                if diag_cnt > 0 diags = diags + ","
                diags = diags + "{\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(c16) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(c16 + 1) + "}},\"severity\":1,\"source\":\"lipilsp\",\"message\":\"Unmatched closing bracket ']'\"}"
                diag_cnt = diag_cnt + 1
            else
                bracket_depth = bracket_depth - 1
        elif c == "{"
            if brace_depth == 0
                brace_line = line
                brace_col = _lsp_byte_col_to_utf16(text, line_start, i)
            brace_depth = brace_depth + 1
        elif c == "}"
            if brace_depth <= 0
                c16 = _lsp_byte_col_to_utf16(text, line_start, i)
                if diag_cnt > 0 diags = diags + ","
                diags = diags + "{\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(c16) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(c16 + 1) + "}},\"severity\":1,\"source\":\"lipilsp\",\"message\":\"Unmatched closing brace '}'\"}"
                diag_cnt = diag_cnt + 1
            else
                brace_depth = brace_depth - 1

        if c == "\n"
            line = line + 1
            line_start = i + 1
        i = i + step

    if in_str == 1
        sc_u16 = _lsp_byte_col_to_utf16(text, line_start, str_start_byte)
        ec_u16 = _lsp_byte_col_to_utf16(text, line_start, n)
        if diag_cnt > 0 diags = diags + ","
        diags = diags + "{\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(sc_u16) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(ec_u16) + "}},\"severity\":1,\"source\":\"lipilsp\",\"message\":\"Unterminated string literal at EOF\"}"
        diag_cnt = diag_cnt + 1

    if paren_depth > 0
        if diag_cnt > 0 diags = diags + ","
        diags = diags + "{\"range\":{\"start\":{\"line\":" + str(paren_line) + ",\"character\":" + str(paren_col) + "},\"end\":{\"line\":" + str(paren_line) + ",\"character\":" + str(paren_col + 1) + "}},\"severity\":2,\"source\":\"lipilsp\",\"message\":\"Unclosed opening parenthesis '('\"}"
        diag_cnt = diag_cnt + 1

    if bracket_depth > 0
        if diag_cnt > 0 diags = diags + ","
        diags = diags + "{\"range\":{\"start\":{\"line\":" + str(bracket_line) + ",\"character\":" + str(bracket_col) + "},\"end\":{\"line\":" + str(bracket_line) + ",\"character\":" + str(bracket_col + 1) + "}},\"severity\":2,\"source\":\"lipilsp\",\"message\":\"Unclosed opening bracket '['\"}"
        diag_cnt = diag_cnt + 1

    if brace_depth > 0
        if diag_cnt > 0 diags = diags + ","
        diags = diags + "{\"range\":{\"start\":{\"line\":" + str(brace_line) + ",\"character\":" + str(brace_col) + "},\"end\":{\"line\":" + str(brace_line) + ",\"character\":" + str(brace_col + 1) + "}},\"severity\":2,\"source\":\"lipilsp\",\"message\":\"Unclosed opening brace '{'\"}"
        diag_cnt = diag_cnt + 1

    return diags + "]"

fn lsp_sub_eq s start pat
    plen = len(pat)
    if start + plen > len(s)
        return 0
    j = 0
    while j < plen
        if char_at(s, start + j) != char_at(pat, j)
            return 0
        j = j + 1
    return 1

// WHY: Extracts function, struct, and enum DocumentSymbol entries for outline view & breadcrumbs.
fn lsp_collect_document_symbols text
    n = len(text)
    if n == 0
        return "[]"
    out = "["
    sym_cnt = 0
    line = 0
    pos = 0

    while pos < n
        eol = pos
        while eol < n and char_at(text, eol) != "\n"
            eol = eol + 1
        line_len = eol - pos

        p = pos
        while p < eol and (char_at(text, p) == " " or char_at(text, p) == "\t")
            p = p + 1

        kind = 0
        kw_len = 0
        if p < eol
            if lsp_sub_eq(text, p, "fn ") == 1
                kind = 12
                kw_len = 3
            elif lsp_sub_eq(text, p, "@fn ") == 1
                kind = 12
                kw_len = 4
            elif lsp_sub_eq(text, p, "কাজ ") == 1
                kind = 12
                kw_len = len("কাজ ")
            elif lsp_sub_eq(text, p, "struct ") == 1
                kind = 23
                kw_len = 7
            elif lsp_sub_eq(text, p, "@struct ") == 1
                kind = 23
                kw_len = 8
            elif lsp_sub_eq(text, p, "গঠন ") == 1
                kind = 23
                kw_len = len("গঠন ")
            elif lsp_sub_eq(text, p, "কাঠামো ") == 1
                kind = 23
                kw_len = len("কাঠামো ")
            elif lsp_sub_eq(text, p, "enum ") == 1
                kind = 10
                kw_len = 5

        if kind > 0
            ns = p + kw_len
            while ns < eol and (char_at(text, ns) == " " or char_at(text, ns) == "\t")
                ns = ns + 1
            ne = ns
            name = ""
            while ne < eol
                ch = char_at(text, ne)
                if ch == " " or ch == "\t" or ch == "(" or ch == ":" or ch == "=" or ch == "\r"
                    break
                name = name + ch
                ne = ne + 1
            if len(name) > 0
                col_s = _lsp_byte_col_to_utf16(text, pos, ns)
                col_e = _lsp_byte_col_to_utf16(text, pos, ne)
                line_u16_end = _lsp_byte_col_to_utf16(text, pos, eol)
                if sym_cnt > 0
                    out = out + ","
                out = out + "{\"name\":\"" + json_escape(name) + "\",\"kind\":" + str(kind)
                out = out + ",\"range\":{\"start\":{\"line\":" + str(line) + ",\"character\":0},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(line_u16_end) + "}}"
                out = out + ",\"selectionRange\":{\"start\":{\"line\":" + str(line) + ",\"character\":" + str(col_s) + "},\"end\":{\"line\":" + str(line) + ",\"character\":" + str(col_e) + "}}}"
                sym_cnt = sym_cnt + 1

        line = line + 1
        pos = eol + 1

    return out + "]"

// ─── Header Parser ────────────────────────────────────────────────────────────
// WHY: Reads "Content-Length: N\r\n" and extracts byte count for JSON body framing.
fn parse_content_length header
    hlen = len(header)
    pos = str_find_from(header, "Content-Length:", 0)
    if pos < 0
        pos = str_find_from(header, "content-length:", 0)
    if pos < 0
        return 0
    i = pos + 15
    while i < hlen and (char_at(header, i) == " " or char_at(header, i) == "\t")
        i = i + 1
    val = 0
    while i < hlen
        c = ord(char_at(header, i))
        if c >= 48 and c <= 57
            val = val * 10 + (c - 48)
            i = i + 1
        else
            return val
    return val

// ─── JSON-RPC I/O Engine ──────────────────────────────────────────────────────
// WHY: Reads standard JSON-RPC 2.0 framed message from STDIN (fd 0).
fn lsp_read_message byte_buf chunk_buf
    header = ""
    b0 = 0
    b1 = 0
    b2 = 0
    b3 = 0
    header_done = 0
    
    while header_done == 0
        r = syscall(0, 0, byte_buf, 1)
        if r <= 0
            return "" // EOF reached on stdin
        b = mem_byte_read(byte_buf, 0)
        header = header + chr(b)
        b3 = b2
        b2 = b1
        b1 = b0
        b0 = b
        if b1 == 10 and b0 == 10
            header_done = 1
        if b3 == 13 and b2 == 10 and b1 == 13 and b0 == 10
            header_done = 1

    content_len = parse_content_length(header)
    if content_len <= 0
        return ""

    // Read body content in chunks for high-throughput I/O
    body = ""
    read_total = 0
    while read_total < content_len
        to_read = content_len - read_total
        if to_read > CHUNK_READ_SIZE
            to_read = CHUNK_READ_SIZE
        chunk = syscall(0, 0, chunk_buf, to_read)
        if chunk <= 0
            return body
        c_i = 0
        while c_i < chunk
            cb = mem_byte_read(chunk_buf, c_i)
            body = body + chr(cb)
            c_i = c_i + 1
        read_total = read_total + chunk

    return body

// WHY: Writes JSON-RPC 2.0 framed message to STDOUT (fd 1).
fn lsp_send_raw body
    body_len = len(body)
    header = "Content-Length: " + str(body_len) + "\r\n\r\n"
    syscall(1, 1, header, len(header))
    syscall(1, 1, body, body_len)
    return 0

fn lsp_send_response id result_json
    body = "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"result\":" + result_json + "}"
    lsp_send_raw(body)
    return 0

fn lsp_send_notification method params_json
    body = "{\"jsonrpc\":\"2.0\",\"method\":\"" + method + "\",\"params\":" + params_json + "}"
    lsp_send_raw(body)
    return 0

// ─── Workspace File Store ─────────────────────────────────────────────────────
// WHY: Tracks open documents in memory for hover lookups and source formatting.
fn workspace_find_file tracked_uris uri
    n = len(tracked_uris)
    i = 0
    while i < n
        if get(tracked_uris, i) == uri
            return i
        i = i + 1
    return -1

fn workspace_set_file tracked_uris tracked_texts uri text
    idx = workspace_find_file(tracked_uris, uri)
    if idx >= 0
        list_set(tracked_texts, idx, text)
    else
        push(tracked_uris, uri)
        push(tracked_texts, text)
    return 0

fn workspace_get_file tracked_uris tracked_texts uri
    idx = workspace_find_file(tracked_uris, uri)
    if idx >= 0
        return get(tracked_texts, idx)
    return ""

fn workspace_close_file tracked_uris tracked_texts uri
    idx = workspace_find_file(tracked_uris, uri)
    if idx >= 0
        list_set(tracked_uris, idx, "")
        list_set(tracked_texts, idx, "")
    return 0

// ─── Token & Word Extraction ──────────────────────────────────────────────────
// WHY: Identifies the token under the editor cursor for hover and completion lookups.
fn is_token_char ch
    code = ord(ch)
    if code > 127 return 1 // Non-ASCII (UTF-8 Bengali characters)
    if code >= 97 and code <= 122 return 1 // a-z
    if code >= 65 and code <= 90 return 1 // A-Z
    if code >= 48 and code <= 57 return 1 // 0-9
    if code == 95 return 1 // _
    if code == 47 return 1 // /
    if code == 46 return 1 // .
    return 0

fn get_word_at_pos text target_line target_char
    tlen = len(text)
    cur_line = 0
    line_start = 0
    i = 0
    while i < tlen and cur_line < target_line
        if char_at(text, i) == "\n"
            cur_line = cur_line + 1
            line_start = i + 1
        i = i + 1
    
    if cur_line != target_line return ""
    
    line_end = line_start
    while line_end < tlen and char_at(text, line_end) != "\n"
        line_end = line_end + 1

    cursor = _lsp_utf16_col_to_byte(text, line_start, line_end, target_char)
    if cursor >= line_end and cursor > line_start
        cursor = line_end - 1
    if cursor >= tlen or cursor < line_start
        return ""
        
    w_start = cursor
    while w_start > line_start and is_token_char(char_at(text, w_start - 1)) == 1
        w_start = w_start - 1
        
    w_end = cursor
    while w_end < line_end and is_token_char(char_at(text, w_end)) == 1
        w_end = w_end + 1
        
    if w_start >= w_end return ""
    return str_sub(text, w_start, w_end)

// ─── Symbol Definition Locator ────────────────────────────────────────────────
// WHY: Enables textDocument/definition (Go-to-Definition) for LSP clients (e.g. VS Code).
// Scans lines in document for function, struct, or variable bindings matching the queried identifier.
fn find_symbol_definition_in_text text symbol
    if len(symbol) == 0 return -1
    tlen = len(text)
    cur_line = 0
    line_start = 0
    i = 0
    while i <= tlen
        is_eol = 0
        if i == tlen
            is_eol = 1
        elif char_at(text, i) == "\n"
            is_eol = 1
            
        if is_eol == 1
            line = str_sub(text, line_start, i)
            trimmed = str_trim(line)
            t_len = len(trimmed)
            s_len = len(symbol)
            matched = 0
            
            // 1. Function declarations: fn, @fn, কাজ
            if starts_with_keyword(trimmed, "fn") == 1
                rem = str_trim(str_sub(trimmed, 2, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "@fn") == 1
                rem = str_trim(str_sub(trimmed, 3, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "কাজ") == 1
                rem = str_trim(str_sub(trimmed, len("কাজ"), t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            // 2. Struct declarations: struct, @struct, কাঠামো, দল
            elif starts_with_keyword(trimmed, "struct") == 1
                rem = str_trim(str_sub(trimmed, 6, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "@struct") == 1
                rem = str_trim(str_sub(trimmed, 7, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "কাঠামো") == 1
                rem = str_trim(str_sub(trimmed, len("কাঠামো"), t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            // 3. Variable declarations: let, @let, চলক, ধরি
            elif starts_with_keyword(trimmed, "let") == 1
                rem = str_trim(str_sub(trimmed, 3, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "@let") == 1
                rem = str_trim(str_sub(trimmed, 4, t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            elif starts_with_keyword(trimmed, "চলক") == 1
                rem = str_trim(str_sub(trimmed, len("চলক"), t_len))
                if starts_with_keyword(rem, symbol) == 1
                    matched = 1
            // 4. Assignment bindings: symbol = ...
            elif starts_with_keyword(trimmed, symbol) == 1
                rem = str_trim(str_sub(trimmed, s_len, t_len))
                if len(rem) > 0 and char_at(rem, 0) == "="
                    matched = 1

            if matched == 1
                return cur_line
                
            cur_line = cur_line + 1
            line_start = i + 1
        i = i + 1
        
    return -1

// ─── Completion Provider ──────────────────────────────────────────────────────
// WHY: Supplies full autocompletion items for English keywords, Bengali keywords,
// and Standard Library modules.
fn make_item label kind detail doc
    return "{\"label\":\"" + label + "\",\"kind\":" + str(kind) + ",\"detail\":\"" + detail + "\",\"documentation\":\"" + doc + "\"}"

fn build_completion_items
    items = list()
    
    // English Keywords
    push(items, make_item("fn", 14, "Function Definition", "fn name(params)"))
    push(items, make_item("struct", 14, "Structure Definition", "struct Name"))
    push(items, make_item("let", 14, "Variable Declaration", "let x = val"))
    push(items, make_item("if", 14, "Conditional Branch", "if cond"))
    push(items, make_item("elif", 14, "Else If Branch", "elif cond"))
    push(items, make_item("else", 14, "Fallback Branch", "else"))
    push(items, make_item("while", 14, "While Loop", "while cond"))
    push(items, make_item("for", 14, "For Loop", "for i in 1..10"))
    push(items, make_item("in", 14, "Loop Membership", "for x in coll"))
    push(items, make_item("return", 14, "Return Statement", "return val"))
    push(items, make_item("say", 14, "Console Print", "say expr"))
    push(items, make_item("include", 14, "Module Inclusion", "include path"))
    push(items, make_item("type", 14, "Type Definition", "type alias"))
    push(items, make_item("asm", 14, "Inline Assembly", "asm { }"))
    push(items, make_item("match", 14, "Pattern Match", "match val"))
    push(items, make_item("case", 14, "Match Case", "case val"))
    push(items, make_item("break", 14, "Loop Break", "break"))
    push(items, make_item("continue", 14, "Loop Continue", "continue"))

    // Bengali Keywords
    push(items, make_item("কাজ", 14, "ফাংশন সংজ্ঞা", "কাজ নাম(প্যারামিটার)"))
    push(items, make_item("কাঠামো", 14, "কাঠামো তৈরি", "কাঠামো নাম"))
    push(items, make_item("চলক", 14, "চলক ঘোষণা", "চলক মান = ১০"))
    push(items, make_item("যদি", 14, "যদি শর্ত", "যদি শর্ত"))
    push(items, make_item("নাহলে_যদি", 14, "নাহলে যদি", "নাহলে_যদি শর্ত"))
    push(items, make_item("নাহলে", 14, "নাহলে শাখা", "নাহলে"))
    push(items, make_item("যতক্ষণ", 14, "যতক্ষণ লুপ", "যতক্ষণ শর্ত"))
    push(items, make_item("প্রতিটি", 14, "প্রতিটি লুপ", "প্রতিটি i মধ্যে ১..১০"))
    push(items, make_item("মধ্যে", 14, "লুপ মেম্বারশিপ", "প্রতিটি x মধ্যে তালিকা"))
    push(items, make_item("ফেরত", 14, "মান ফেরত", "ফেরত মান"))
    push(items, make_item("বলো", 14, "কনসোলে বলো", "বলো বার্তা"))
    push(items, make_item("অন্তর্ভুক্ত", 14, "মডিউল অন্তর্ভুক্ত", "অন্তর্ভুক্ত পথ"))
    push(items, make_item("ধরন", 14, "ধরন সংজ্ঞা", "ধরন নাম = ধরন"))
    push(items, make_item("মিল", 14, "প্যাটার্ন মিল", "মিল মান"))
    push(items, make_item("ঘটনা", 14, "মিল ঘটনা", "ঘটনা মান => কোড"))
    push(items, make_item("থামো", 14, "লুপ থামো", "থামো"))
    push(items, make_item("চলো", 14, "লুপ চলো", "চলো"))

    // Standard Library Modules
    push(items, make_item("aati/lipi_web/router.lp", 9, "Web Framework", "HTTP Router & Server"))
    push(items, make_item("utso/concurrency", 9, "Native Threads", "Linux Clone Syscall Multithreading"))
    push(items, make_item("utso/hashmap", 9, "Hash Map", "Hash Map"))
    push(items, make_item("utso/arena", 9, "Arena Allocator", "Bump Arena Allocator"))
    push(items, make_item("utso/io", 9, "Direct Syscall I/O", "Linux AMD64 Kernel Syscalls"))
    push(items, make_item("utso/string", 9, "Unicode String", "String Utilities & Slicing"))
    push(items, make_item("utso/memory", 9, "Kernel Allocator", "Virtual Memory & Slab Operations"))
    push(items, make_item("utso/math", 9, "Math", "Mathematical Operations"))
    push(items, make_item("utso/core/simd.lp", 9, "SIMD", "AVX2 & SSE Vector Math"))
    push(items, make_item("utso/crypto", 9, "Cryptography", "AES-GCM, ChaCha20-Poly1305, SHA-256, Ed25519, P-256/P-384, RSA, X.509"))
    push(items, make_item("aati/lipi_sql/src/sql.lp", 9, "SQL Engine", "WAL-backed Embedded SQL Store"))
    push(items, make_item("--kavach", 14, "Kavach Static Safety", "Static ownership proof + silicon_* hardware boundary isolation"))
    push(items, make_item("alloc", 3, "Segregated Slab Allocator", "alloc(size) -> O(1) tracked slab block"))
    push(items, make_item("বরাদ্দ", 3, "বরাদ্দ (Slab Alloc)", "বরাদ্দ(size) -> স্ল্যাব মেমরি বরাদ্দ"))
    push(items, make_item("free", 3, "Memory Free", "free(ptr) for slab / free(addr, size) in utso/memory"))
    push(items, make_item("মুক্ত", 3, "মুক্ত (Slab Free)", "মুক্ত(ptr) দ্বারা মেমরি মুক্তি"))
    push(items, make_item("arena_mark", 3, "Arena Snapshot Mark", "mark = arena_mark() for O(1) scoped arena unwind"))
    push(items, make_item("arena_reset", 3, "Arena Snapshot Reset", "arena_reset(mark) frees all transient blocks cleanly"))
    push(items, make_item("arena_allocated", 3, "Arena Bytes Counter", "Returns active allocated heap bytes"))
    push(items, make_item("silicon_seal", 14, "Kavach Hardware Boundary", "Prefix silicon_* / সিলিকন_* required for syscall/mem_write under --kavach"))

    res = "["
    i = 0
    n = len(items)
    while i < n
        res = res + get(items, i)
        if i < n - 1
            res = res + ","
        i = i + 1
    res = res + "]"
    return res

// ─── Hover Provider ───────────────────────────────────────────────────────────
// WHY: Provides rich markdown docstrings when hovering over keywords or stdlib functions.
fn get_hover_documentation word
    if word == "fn" or word == "কাজ"
        return "### Function Definition (`fn` / `কাজ`)\nDeclares a callable function or method in Lipi.\n```lipi\nfn add(a, b)\n    return a + b\n```"
    if word == "struct" or word == "কাঠামো" or word == "গঠন"
        return "### Structure Definition (`struct` / `কাঠামো`)\nDeclares an object structure with named fields.\n```lipi\nstruct Point\n    x\n    y\n```"
    if word == "let" or word == "চলক" or word == "ধরি"
        return "### Variable Declaration (`let` / `চলক`)\nDeclares a variable binding in current scope.\n```lipi\nlet x = 10\n```"
    if word == "if" or word == "যদি"
        return "### Conditional Branch (`if` / `যদি`)\nExecutes block if condition is true (non-zero).\n```lipi\nif x > 0\n    say \"positive\"\n```"
    if word == "elif" or word == "নাহলে_যদি"
        return "### Alternative Branch (`elif` / `নাহলে_যদি`)\nChains alternative condition if preceding `if` is false."
    if word == "else" or word == "নাহলে"
        return "### Fallback Branch (`else` / `নাহলে`)\nExecutes block when all preceding condition branches evaluate to false."
    if word == "while" or word == "যতক্ষণ"
        return "### While Loop (`while` / `যতক্ষণ`)\nRepeats block while condition evaluates to true.\n```lipi\nwhile i < 10\n    i = i + 1\n```"
    if word == "for" or word == "প্রতিটি"
        return "### Range Loop (`for` / `প্রতিটি`)\nIterates over a range or collection.\n```lipi\nfor i in 1..10\n    say i\n```"
    if word == "in" or word == "মধ্যে"
        return "### Loop Range Membership (`in` / `মধ্যে`)\nSpecifies iterator collection or range in a loop."
    if word == "return" or word == "ফেরত"
        return "### Return Statement (`return` / `ফেরত`)\nReturns a value from current function to caller."
    if word == "say" or word == "বলো"
        return "### Console Output (`say` / `বলো`)\nPrints values and strings to stdout followed by newline.\n```lipi\nsay \"Hello, Lipi!\"\n```"
    if word == "include" or word == "অন্তর্ভুক্ত"
        return "### Module Inclusion (`include` / `অন্তর্ভুক্ত`)\nImports definitions from standard library or local file.\n```lipi\ninclude \"std/io.lp\"\n```"
    if word == "type" or word == "ধরন"
        return "### Type Definition (`type` / `ধরন`)\nDefines a custom type alias or data type annotation."
    if word == "asm"
        return "### Inline Assembly (`asm`)\nDirect AMD64 or AArch64 machine instructions on bare silicon."
    if word == "match" or word == "মিল"
        return "### Pattern Matching (`match` / `মিল`)\nMatches an expression against multiple cases."
    if word == "case" or word == "ঘটনা"
        return "### Match Case Arm (`case` / `ঘটনা`)\nBranch arm within a pattern match statement."
    if word == "break" or word == "থামো"
        return "### Loop Break (`break` / `থামো`)\nTerminates current loop execution immediately."
    if word == "continue" or word == "চলো"
        return "### Loop Continue (`continue` / `চলো`)\nProceeds directly to next loop iteration."
    if word == "aati/lipi_web/router.lp" or word == "web_router_create"
        return "### `aati/lipi_web/router.lp` (Web Framework)\nHTTP server, JSON routing, and WebSocket engine.\n- `web_router_create()`\n- `web_server_start(port)`"
    if word == "utso/concurrency" or word == "thread_create"
        return "### `utso/concurrency` (Multithreading)\nNative Linux clone syscall threads, mutexes, and atomics.\n- `thread_create(fn_ptr, arg)`\n- `thread_join(th)`"
    if word == "utso/hashmap" or word == "hashmap_new"
        return "### `utso/hashmap` (Hash Map)\nKey-value hash map data structure.\n- `hashmap_new()`\n- `hashmap_set(hm, key, val)`\n- `hashmap_get(hm, key)`"
    if word == "utso/arena" or word == "arena_create"
        return "### `utso/arena` (Arena Allocator)\nBump memory allocator for batch allocations.\n- `arena_create(size)`\n- `arena_alloc(ar, size)`\n- `arena_reset(ar)`"
    if word == "utso/io" or word == "utso/core/io.lp" or word == "syscall"
        return "### `utso/io` (Direct Syscall I/O)\nLow-level I/O via direct Linux AMD64 kernel syscalls (0% Libc).\n- `write_out(msg)`\n- `file_open(path, flags)`"
    if word == "utso/string" or word == "utso/core/string.lp"
        return "### `utso/string` (Unicode String Library)\nString manipulation, padding, repeat, and substring slicing.\n- `str_repeat(s, n)`\n- `str_sub(s, start, end)`"
    if word == "utso/memory"
        return "### `utso/memory` (Kernel Memory Allocator)\nPage-aligned virtual memory via direct SYS_mmap & SYS_munmap.\n- `malloc(size)`\n- `free(addr, size)`\n- `mem_copy(dest, src, len)`"
    if word == "utso/math"
        return "### `utso/math` (Math Library)\nInteger and float arithmetic utilities.\n- `abs(x)`, `min(a, b)`, `max(a, b)`"
    if word == "utso/core/simd.lp"
        return "### `utso/core/simd.lp` (Hardware SIMD)\nAVX2 / SSE vector arithmetic operations."
    if word == "utso/crypto"
        return "### `utso/crypto` (Cryptography)\nSHA-256/384/512, AES-GCM, ChaCha20-Poly1305, X25519, Ed25519, P-256/P-384, RSA, X.509."
    if word == "aati/lipi_sql/src/sql.lp"
        return "### `aati/lipi_sql/src/sql.lp` (Embedded SQL)\nDynamic relational SQL engine with CRC-32 fsync WAL."
    if word == "malloc" or word == "free" or word == "alloc" or word == "বরাদ্দ" or word == "মুক্ত"
        return "### Memory Management (`alloc` / `free` / `malloc`)\n- `alloc(size)` / `free(ptr)`: O(1) bounds- & double-free-checked segregated slab allocator.\n- `malloc(size)` / `free(addr, size)` (`utso/memory`): Direct kernel `SYS_mmap` / `SYS_munmap`."

    if word == "--kavach" or word == "silicon_" or word == "সিলিকন_"
        return "### Kavach Static Safety (`--kavach` / `--কবচ`)\nEnforces compile-time leak/use-after-free checks AND restricts raw hardware primitives (`syscall`, `mem_write`) exclusively to functions prefixed with `silicon_` or `সিলিকন_`."

    if word == "arena_mark" or word == "arena_reset" or word == "arena_allocated"
        return "### Scoped Arena Snapshots\n`mark = arena_mark()`, run allocations, then `arena_reset(mark)` in O(1) with `arena_allocated()` accounting."
    
    return "### Lipi Programming Language (1.0.1)\nSelf-hosted bilingual native compiler (English & Bengali, zero libc/LLVM)"

// ─── Source Formatter ─────────────────────────────────────────────────────────
// WHY: Provides 4-space indentation alignment for functions, structs, conditionals, and loops.
fn str_trim_start s
    slen = len(s)
    i = 0
    while i < slen and (char_at(s, i) == " " or char_at(s, i) == "\t" or char_at(s, i) == "\r")
        i = i + 1
    if i == 0
        return s
    return str_sub(s, i, slen)

fn str_trim_end s
    slen = len(s)
    if slen == 0
        return ""
    i = slen
    while i > 0 and (char_at(s, i - 1) == " " or char_at(s, i - 1) == "\t" or char_at(s, i - 1) == "\r")
        i = i - 1
    return str_sub(s, 0, i)

fn str_trim s
    return str_trim_end(str_trim_start(s))

fn starts_with_keyword s word
    wlen = len(word)
    slen = len(s)
    if slen < wlen
        return 0
    i = 0
    while i < wlen
        if char_at(s, i) != char_at(word, i)
            return 0
        i = i + 1
    if slen == wlen
        return 1
    c = char_at(s, wlen)
    if c == " " or c == "(" or c == "{" or c == ":" or c == "\n" or c == "\t" or c == "="
        return 1
    return 0

fn count_newlines text
    count = 0
    i = 0
    tlen = len(text)
    while i < tlen
        if char_at(text, i) == "\n"
            count = count + 1
        i = i + 1
    return count

fn format_lipi_code text
    tlen = len(text)
    result = ""
    indent = 0
    line_start = 0
    i = 0

    while i <= tlen
        is_eol = 0
        if i == tlen
            is_eol = 1
        elif char_at(text, i) == "\n"
            is_eol = 1

        if is_eol == 1
            raw_line = str_sub(text, line_start, i)
            line = str_trim(raw_line)

            if len(line) == 0
                result = result + "\n"
            else
                is_dedent = 0
                is_full_close = 0
                if starts_with_keyword(line, "else") or starts_with_keyword(line, "@else") or starts_with_keyword(line, "নাহলে") or starts_with_keyword(line, "elif") or starts_with_keyword(line, "@elif") or starts_with_keyword(line, "নাহলে_যদি")
                    is_dedent = 1
                elif line == "end" or line == "@end" or line == "শেষ" or char_at(line, 0) == "}"
                    is_dedent = 1
                    is_full_close = 1

                print_indent = indent
                if is_dedent == 1 and print_indent > 0
                    print_indent = print_indent - 1

                sp = ""
                s_i = 0
                while s_i < print_indent * 4
                    sp = sp + " "
                    s_i = s_i + 1

                result = result + sp + line + "\n"

                is_indent = 0
                if is_full_close == 0
                    if starts_with_keyword(line, "fn") or starts_with_keyword(line, "@fn") or starts_with_keyword(line, "কাজ") or starts_with_keyword(line, "if") or starts_with_keyword(line, "@if") or starts_with_keyword(line, "যদি") or starts_with_keyword(line, "while") or starts_with_keyword(line, "@while") or starts_with_keyword(line, "যতক্ষণ") or starts_with_keyword(line, "for") or starts_with_keyword(line, "@for") or starts_with_keyword(line, "প্রতিটি") or starts_with_keyword(line, "struct") or starts_with_keyword(line, "@struct") or starts_with_keyword(line, "গঠন") or starts_with_keyword(line, "কাঠামো") or starts_with_keyword(line, "else") or starts_with_keyword(line, "@else") or starts_with_keyword(line, "নাহলে") or starts_with_keyword(line, "elif") or starts_with_keyword(line, "@elif") or starts_with_keyword(line, "নাহলে_যদি")
                        is_indent = 1
                    if char_at(line, len(line) - 1) == "{"
                        is_indent = 1

                if is_dedent == 1
                    indent = print_indent
                if is_indent == 1
                    indent = indent + 1

            line_start = i + 1
        i = i + 1

    return result

fn _lsp_resolve_include_paths text
    paths = list()
    tlen = len(text)
    pos = 0
    while pos < tlen
        eol = pos
        while eol < tlen and char_at(text, eol) != "\n"
            eol = eol + 1
        line = str_trim(str_sub(text, pos, eol))
        if starts_with_keyword(line, "import") == 1 or starts_with_keyword(line, "include") == 1
            q1 = str_find_from(line, "\"", 0)
            if q1 >= 0
                q2 = str_find_from(line, "\"", q1 + 1)
                if q2 > q1 + 1
                    raw_p = str_sub(line, q1 + 1, q2)
                    if str_find_from(raw_p, ".lp", 0) < 0
                        raw_p = raw_p + ".lp"
                    push(paths, raw_p)
        pos = eol + 1
    return paths

fn _lsp_collect_refs_in_text text symbol uri
    out = ""
    if len(symbol) == 0 or len(text) == 0 return ""
    tlen = len(text)
    slen = len(symbol)
    cur_line = 0
    line_start = 0
    i = 0
    while i < tlen
        if char_at(text, i) == "\n"
            cur_line = cur_line + 1
            line_start = i + 1
            i = i + 1
            continue
        if i + slen <= tlen and lsp_sub_eq(text, i, symbol) == 1
            left_ok = 1
            if i > line_start and is_token_char(char_at(text, i - 1)) == 1
                left_ok = 0
            right_ok = 1
            if i + slen < tlen and is_token_char(char_at(text, i + slen)) == 1
                right_ok = 0
            if left_ok == 1 and right_ok == 1
                cs = _lsp_byte_col_to_utf16(text, line_start, i)
                ce = _lsp_byte_col_to_utf16(text, line_start, i + slen)
                if len(out) > 0 out = out + ","
                out = out + "{\"uri\":\"" + json_escape(uri) + "\",\"range\":{\"start\":{\"line\":" + str(cur_line) + ",\"character\":" + str(cs) + "},\"end\":{\"line\":" + str(cur_line) + ",\"character\":" + str(ce) + "}}}"
                i = i + slen
                continue
        i = i + 1
    return out

// ─── Main LSP Event Loop ──────────────────────────────────────────────────────
fn lsp_main_loop
    sname = lsp_server_name()
    sver  = lsp_server_version()
    sprot = lsp_protocol_version()

    lsp_log("Starting Lipi Language Server (" + sname + ") v" + sver)
    lsp_log("Protocol: JSON-RPC 2.0 over standard I/O | LSP v" + sprot)

    byte_buf  = malloc(16)
    chunk_buf = malloc(CHUNK_READ_SIZE + 16)
    
    tracked_uris  = list()
    tracked_texts = list()
    completion_items = build_completion_items()
    
    running = 1
    server_initialized = 0

    while running == 1
        raw_msg = lsp_read_message(byte_buf, chunk_buf)
        if len(raw_msg) == 0
            lsp_log("STDIN EOF reached. Terminating.")
            running = 0
        else
            method = json_extract_str_value(raw_msg, "method")
            req_id = json_extract_id(raw_msg)
            
            // ── 1. initialize ──
            if method == "initialize"
                lsp_log("Received initialize request (id: " + req_id + ")")
                resp = "{\"capabilities\":{\"textDocumentSync\":1,\"completionProvider\":{\"resolveProvider\":false,\"triggerCharacters\":[\".\",\"/\",\"\\\"\",\":\",\" \"]},\"hoverProvider\":true,\"documentFormattingProvider\":true,\"definitionProvider\":true,\"referencesProvider\":true,\"documentSymbolProvider\":true},\"serverInfo\":{\"name\":\"" + sname + "\",\"version\":\"" + sver + "\"}}"
                lsp_send_response(req_id, resp)

            // ── 2. initialized ──
            elif method == "initialized"
                lsp_log("Client confirmed initialized.")
                server_initialized = 1

            // ── 3. textDocument/didOpen ──
            elif method == "textDocument/didOpen"
                uri = json_extract_str_value(raw_msg, "uri")
                raw_text = json_extract_str_value(raw_msg, "text")
                doc_text = json_unescape(raw_text)
                workspace_set_file(tracked_uris, tracked_texts, uri, doc_text)
                lsp_log("didOpen tracked file: " + uri)
                diags_json = lsp_compute_diagnostics(doc_text)
                diag_params = "{\"uri\":\"" + uri + "\",\"diagnostics\":" + diags_json + "}"
                lsp_send_notification("textDocument/publishDiagnostics", diag_params)

            // ── 4. textDocument/didChange ──
            elif method == "textDocument/didChange"
                uri = json_extract_str_value(raw_msg, "uri")
                raw_text = json_extract_str_value(raw_msg, "text")
                doc_text = json_unescape(raw_text)
                workspace_set_file(tracked_uris, tracked_texts, uri, doc_text)
                lsp_log("didChange updated file: " + uri)
                diags_json = lsp_compute_diagnostics(doc_text)
                diag_params = "{\"uri\":\"" + uri + "\",\"diagnostics\":" + diags_json + "}"
                lsp_send_notification("textDocument/publishDiagnostics", diag_params)

            // ── 4b. textDocument/documentSymbol ──
            elif method == "textDocument/documentSymbol"
                uri = json_extract_str_value(raw_msg, "uri")
                doc_text = workspace_get_file(tracked_uris, tracked_texts, uri)
                syms_json = lsp_collect_document_symbols(doc_text)
                lsp_send_response(req_id, syms_json)

            // ── 5. textDocument/didClose ──
            elif method == "textDocument/didClose"
                uri = json_extract_str_value(raw_msg, "uri")
                workspace_close_file(tracked_uris, tracked_texts, uri)
                lsp_log("didClose untracked file: " + uri)

            // ── 6. textDocument/completion ──
            elif method == "textDocument/completion"
                lsp_log("Completion request (id: " + req_id + ")")
                resp = "{\"isIncomplete\":false,\"items\":" + completion_items + "}"
                lsp_send_response(req_id, resp)

            // ── 7. textDocument/hover ──
            elif method == "textDocument/hover"
                uri = json_extract_str_value(raw_msg, "uri")
                line = json_extract_int_value(raw_msg, "line")
                char_pos = json_extract_int_value(raw_msg, "character")
                
                doc_text = workspace_get_file(tracked_uris, tracked_texts, uri)
                word = get_word_at_pos(doc_text, line, char_pos)
                docstring = get_hover_documentation(word)
                
                lsp_log("Hover at L" + str(line) + ":C" + str(char_pos) + " word: [" + word + "]")
                resp = "{\"contents\":{\"kind\":\"markdown\",\"value\":\"" + json_escape(docstring) + "\"}}"
                lsp_send_response(req_id, resp)

            // ── 8. textDocument/definition (Go-to-Definition + Include Resolution) ──
            elif method == "textDocument/definition"
                uri = json_extract_str_value(raw_msg, "uri")
                line = json_extract_int_value(raw_msg, "line")
                char_pos = json_extract_int_value(raw_msg, "character")

                doc_text = workspace_get_file(tracked_uris, tracked_texts, uri)
                word = get_word_at_pos(doc_text, line, char_pos)
                lsp_log("Definition lookup for: [" + word + "] in " + uri)

                found_line = find_symbol_definition_in_text(doc_text, word)
                found_uri = uri

                if found_line < 0
                    t_idx = 0
                    num_tracked = len(tracked_uris)
                    while t_idx < num_tracked and found_line < 0
                        other_u = get(tracked_uris, t_idx)
                        if other_u != uri
                            other_t = get(tracked_texts, t_idx)
                            other_l = find_symbol_definition_in_text(other_t, word)
                            if other_l >= 0
                                found_line = other_l
                                found_uri = other_u
                        t_idx = t_idx + 1

                if found_line < 0
                    inc_paths = _lsp_resolve_include_paths(doc_text)
                    ii = 0
                    while ii < len(inc_paths) and found_line < 0
                        ip = get(inc_paths, ii)
                        if file_exists(ip) == 1
                            inc_txt = file_read(ip)
                            il = find_symbol_definition_in_text(inc_txt, word)
                            if il >= 0
                                found_line = il
                                found_uri = "file://" + ip
                        ii = ii + 1

                if found_line >= 0
                    resp = "{\"uri\":\"" + found_uri + "\",\"range\":{\"start\":{\"line\":" + str(found_line) + ",\"character\":0},\"end\":{\"line\":" + str(found_line) + ",\"character\":0}}}"
                    lsp_send_response(req_id, resp)
                else
                    lsp_send_response(req_id, "null")

            // ── 8b. textDocument/references ──
            elif method == "textDocument/references"
                uri = json_extract_str_value(raw_msg, "uri")
                line = json_extract_int_value(raw_msg, "line")
                char_pos = json_extract_int_value(raw_msg, "character")
                doc_text = workspace_get_file(tracked_uris, tracked_texts, uri)
                word = get_word_at_pos(doc_text, line, char_pos)
                refs = _lsp_collect_refs_in_text(doc_text, word, uri)
                t_idx = 0
                while t_idx < len(tracked_uris)
                    other_u = get(tracked_uris, t_idx)
                    if other_u != uri
                        other_t = get(tracked_texts, t_idx)
                        r2 = _lsp_collect_refs_in_text(other_t, word, other_u)
                        if len(r2) > 0
                            if len(refs) > 0 refs = refs + ","
                            refs = refs + r2
                    t_idx = t_idx + 1
                lsp_send_response(req_id, "[" + refs + "]")

            // ── 9. textDocument/formatting ──
            elif method == "textDocument/formatting"
                uri = json_extract_str_value(raw_msg, "uri")
                doc_text = workspace_get_file(tracked_uris, tracked_texts, uri)
                lsp_log("Formatting request for: " + uri)
                
                if len(doc_text) > 0
                    formatted_text = format_lipi_code(doc_text)
                    total_lines = count_newlines(doc_text)
                    resp = "[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":" + str(total_lines + 1) + ",\"character\":9999}},\"newText\":\"" + json_escape(formatted_text) + "\"}]"
                    lsp_send_response(req_id, resp)
                else
                    lsp_send_response(req_id, "[]")

            // ── 9. shutdown ──
            elif method == "shutdown"
                lsp_log("Shutdown requested.")
                lsp_send_response(req_id, "null")

            // ── 10. exit ──
            elif method == "exit"
                lsp_log("Exit notification received. Exiting.")
                running = 0

            // ── 11. Unhandled request fallback ──
            else
                if req_id != "null"
                    lsp_log("Unhandled request method: " + method + " (id: " + req_id + ")")
                    lsp_send_response(req_id, "null")

    free(byte_buf, 16)
    free(chunk_buf, CHUNK_READ_SIZE + 16)
    return 0

// ─── Entry Point ──────────────────────────────────────────────────────────────
fn main
    lsp_main_loop()
    return 0

main()
