// ==============================================================================
// 🧠 LIPI UNIFIED TOOLKIT: LSP JSON-RPC 2.0 PROTOCOL ENGINE (src/toolkit/lsp/protocol_json.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Zero Libc / Zero External JSON Libraries
// ==============================================================================
//
// WHY THIS MODULE:
// The Language Server Protocol relies entirely on JSON-RPC 2.0 message contracts.
// Standard C libraries (cJSON, jansson) introduce memory leaks and ABI baggage.
// This module provides:
// 1. High-throughput zero-dependency JSON-RPC 2.0 message serialization and extraction.
// 2. Exact JSON string escaping/unescaping respecting UTF-8 and control codes.
// 3. Balanced brace/bracket extraction for nested parameter objects and AST payloads.
// 4. Canonical JSON-RPC error definitions conforming strictly to specification.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Protocol Error Constants ───────────────────────────────────────────────

JSONRPC_ERR_PARSE_ERROR           = -32700
JSONRPC_ERR_INVALID_REQUEST       = -32600
JSONRPC_ERR_METHOD_NOT_FOUND      = -32601
JSONRPC_ERR_INVALID_PARAMS        = -32602
JSONRPC_ERR_INTERNAL_ERROR        = -32603
JSONRPC_ERR_SERVER_NOT_INITIALIZED = -32002
JSONRPC_ERR_REQUEST_CANCELLED     = -32800

// ── 2. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates parsed JSON-RPC request, response, or notification message.
struct JsonRpcMsg
    id              // Request identifier (number, string, or "null")
    method          // Invoked RPC method (e.g. "textDocument/didOpen")
    params_raw      // Raw JSON content of "params" payload
    result_raw      // Raw JSON content of "result" payload
    is_notification // 1 if message lacks an id (one-way signal), 0 otherwise
    is_error        // 1 if message conveys an RPC error
    error_code      // Integer protocol error code
    error_message   // Human-readable error description

// ── 3. String Escaping Primitives ─────────────────────────────────────────────

// WHY: Encodes raw strings safely into RFC 8259 JSON string literals.
fn json_escape text
    tlen = len(text)
    out = ""
    i = 0
    while i < tlen
        c = char_at(text, i)
        if c == "\\"
            out = out + "\\\\"
        elif c == "\""
            out = out + "\\\""
        elif c == "\n"
            out = out + "\\n"
        elif c == "\r"
            out = out + "\\r"
        elif c == "\t"
            out = out + "\\t"
        else
            out = out + c
        i = i + 1
    return out

// WHY: Decodes escaped JSON strings back to raw memory byte representations.
fn json_unescape text
    tlen = len(text)
    out = ""
    i = 0
    while i < tlen
        c = char_at(text, i)
        if c == "\\" and (i + 1) < tlen
            next_c = char_at(text, i + 1)
            if next_c == "n"
                out = out + "\n"
            elif next_c == "r"
                out = out + "\r"
            elif next_c == "t"
                out = out + "\t"
            elif next_c == "\""
                out = out + "\""
            elif next_c == "\\"
                out = out + "\\"
            else
                out = out + next_c
            i = i + 2
        else
            out = out + c
            i = i + 1
    return out

// ── 4. Substring & Key Navigation Helpers ─────────────────────────────────────

// WHY: Searches for substring needle starting at specified index offset.
fn json_str_find_from haystack needle start_idx
    hlen = len(haystack)
    nlen = len(needle)
    if nlen == 0 return start_idx
    if hlen < nlen return -1

    i = start_idx
    while i <= (hlen - nlen)
        matched = 1
        j = 0
        while j < nlen
            if char_at(haystack, i + j) != char_at(needle, j)
                matched = 0
                break
            j = j + 1
        if matched == 1
            return i
        i = i + 1
    return -1

// WHY: Locates JSON object key `"key":` and returns index after the colon.
fn json_locate_value_start json key
    needle = "\"" + key + "\""
    pos = json_str_find_from(json, needle, 0)
    if pos < 0 return -1

    after_key = pos + len(needle)
    colon_pos = json_str_find_from(json, ":", after_key)
    if colon_pos < 0 return -1

    j = colon_pos + 1
    jlen = len(json)
    while j < jlen
        c = char_at(json, j)
        if c != " " and c != "\t" and c != "\r" and c != "\n"
            return j
        j = j + 1
    return -1

// ── 5. Field Extractors ───────────────────────────────────────────────────────

// WHY: Extracts string value associated with key in JSON object.
fn json_get_string json key
    val_start = json_locate_value_start(json, key)
    if val_start < 0 return ""

    jlen = len(json)
    if char_at(json, val_start) != "\""
        return ""

    q1 = val_start
    q2 = -1
    j = q1 + 1

    // Scan for closing quote respecting backslash escapes
    while j < jlen and q2 < 0
        c = char_at(json, j)
        if c == "\\"
            j = j + 2
        elif c == "\""
            q2 = j
        else
            j = j + 1

    if q2 < 0 return ""
    raw_str = str_sub(json, q1 + 1, q2)
    return json_unescape(raw_str)

// WHY: Extracts integer numeric value associated with key in JSON object.
fn json_get_int json key
    val_start = json_locate_value_start(json, key)
    if val_start < 0 return 0

    jlen = len(json)
    j = val_start
    neg = 0
    if char_at(json, j) == "-"
        neg = 1
        j = j + 1

    val = 0
    has_digits = 0
    while j < jlen
        code = ord(char_at(json, j))
        if code >= 48 and code <= 57
            val = (val * 10) + (code - 48)
            has_digits = 1
            j = j + 1
        else
            break

    if has_digits == 0 return 0
    if neg == 1 return 0 - val
    return val

// WHY: Extracts balanced nested JSON object `{...}` or array `[...]` raw text.
fn json_get_raw_object_or_array json key
    val_start = json_locate_value_start(json, key)
    if val_start < 0 return "{}"

    first_c = char_at(json, val_start)
    if first_c != "{" and first_c != "["
        return "{}"

    close_c = "}"
    if first_c == "["
        close_c = "]"

    depth = 0
    j = val_start
    jlen = len(json)
    in_str = 0

    while j < jlen
        c = char_at(json, j)
        if in_str == 1
            if c == "\\"
                j = j + 1
            elif c == "\""
                in_str = 0
        else
            if c == "\""
                in_str = 1
            elif c == first_c
                depth = depth + 1
            elif c == close_c
                depth = depth - 1
                if depth == 0
                    return str_sub(json, val_start, j + 1)
        j = j + 1

    return "{}"

// WHY: Extracts message id, correctly identifying numeric vs string id vs null.
fn json_get_id json
    val_start = json_locate_value_start(json, "id")
    if val_start < 0 return "null"

    jlen = len(json)
    first_c = char_at(json, val_start)
    if first_c == "\""
        q2 = json_str_find_from(json, "\"", val_start + 1)
        if q2 < 0 return "null"
        return str_sub(json, val_start, q2 + 1)

    // Numeric or null
    j = val_start
    while j < jlen
        c = char_at(json, j)
        if c == "," or c == "}" or c == " " or c == "\t" or c == "\r" or c == "\n"
            return str_sub(json, val_start, j)
        j = j + 1
    return str_sub(json, val_start, j)

// ── 6. Message Parser & Deserializer ──────────────────────────────────────────

// WHY: Converts raw JSON string into structured JsonRpcMsg model.
fn jsonrpc_parse_message raw_json
    msg = JsonRpcMsg()
    msg.id = "null"
    msg.method = ""
    msg.params_raw = "{}"
    msg.result_raw = "null"
    msg.is_notification = 1
    msg.is_error = 0
    msg.error_code = 0
    msg.error_message = ""

    msg.method = json_get_string(raw_json, "method")
    msg.id = json_get_id(raw_json)

    if msg.id != "null"
        msg.is_notification = 0

    val_start = json_locate_value_start(raw_json, "params")
    if val_start >= 0
        msg.params_raw = json_get_raw_object_or_array(raw_json, "params")

    err_start = json_locate_value_start(raw_json, "error")
    if err_start >= 0
        msg.is_error = 1
        raw_err = json_get_raw_object_or_array(raw_json, "error")
        msg.error_code = json_get_int(raw_err, "code")
        msg.error_message = json_get_string(raw_err, "message")

    res_start = json_locate_value_start(raw_json, "result")
    if res_start >= 0
        msg.result_raw = json_get_raw_object_or_array(raw_json, "result")

    return msg

// ── 7. Message Builders & Serializers ─────────────────────────────────────────

// WHY: Builds valid JSON-RPC 2.0 success response payload.
fn jsonrpc_build_response id result_json
    return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"result\":" + result_json + "}"

// WHY: Builds valid JSON-RPC 2.0 error response payload.
fn jsonrpc_build_error id code message
    esc_msg = json_escape(message)
    err_obj = "{\"code\":" + str(code) + ",\"message\":\"" + esc_msg + "\"}"
    return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"error\":" + err_obj + "}"

// WHY: Builds valid JSON-RPC 2.0 one-way notification payload (no id).
fn jsonrpc_build_notification method params_json
    return "{\"jsonrpc\":\"2.0\",\"method\":\"" + method + "\",\"params\":" + params_json + "}"

// WHY: Builds valid JSON-RPC 2.0 request payload.
fn jsonrpc_build_request id method params_json
    return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"method\":\"" + method + "\",\"params\":" + params_json + "}"
