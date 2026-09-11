// ==============================================================================
// 🧠 লিপি LSP — Language Server Protocol Implementation (JSON-RPC 2.0)
// লিপি দ্বিতীয় ২.০ | Lipi Sovereign Language Server
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

include "universe/core/memory.lp"
include "universe/core/io.lp"
include "universe/core/string.lp"

// ─── LSP Identity & Protocol ──────────────────────────────────────────────────
fn lsp_protocol_version = "3.17"
fn lsp_server_version  = "2.0.0"
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
    if sublen == 0 { return start }
    if slen < sublen { return -1 }
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
fn json_extract_str_value json key
    needle = "\"" + key + "\""
    pos = str_find_from(json, needle, 0)
    if pos < 0 { return "" }
    colon = str_find_from(json, ":", pos + len(needle))
    if colon < 0 { return "" }
    q1 = str_find_from(json, "\"", colon + 1)
    if q1 < 0 { return "" }
    
    // Find matching closing quote, respecting backslash escapes
    j = q1 + 1
    jlen = len(json)
    q2 = -1
    while j < jlen and q2 < 0
        c = char_at(json, j)
        if c == "\\"
            j = j + 2
        else
            if c == "\""
                q2 = j
            else
                j = j + 1
                
    if q2 < 0 { return "" }
    return str_sub(json, q1 + 1, q2)

fn json_extract_id json
    needle = "\"id\""
    pos = str_find_from(json, needle, 0)
    if pos < 0 { return "null" }
    colon = str_find_from(json, ":", pos + len(needle))
    if colon < 0 { return "null" }
    
    j = colon + 1
    jlen = len(json)
    while j < jlen and (char_at(json, j) == " " or char_at(json, j) == "\t" or char_at(json, j) == "\r" or char_at(json, j) == "\n")
        j = j + 1
    if j >= jlen { return "null" }
    
    first_c = char_at(json, j)
    if first_c == "\""
        q2 = str_find_from(json, "\"", j + 1)
        if q2 < 0 { return "null" }
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
    if pos < 0 { return 0 }
    colon = str_find_from(json, ":", pos + len(needle))
    if colon < 0 { return 0 }
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
            else
                if next_c == "r"
                    res = res + "\r"
                else
                    if next_c == "t"
                        res = res + "\t"
                    else
                        if next_c == "\""
                            res = res + "\""
                        else
                            if next_c == "\\"
                                res = res + "\\"
                            else
                                res = res + next_c
            i = i + 2
        else
            res = res + c
            i = i + 1
    return res

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
    if code > 127 { return 1 } // Non-ASCII (UTF-8 Bengali characters)
    if code >= 97 and code <= 122 { return 1 } // a-z
    if code >= 65 and code <= 90 { return 1 } // A-Z
    if code >= 48 and code <= 57 { return 1 } // 0-9
    if code == 95 { return 1 } // _
    if code == 47 { return 1 } // /
    if code == 46 { return 1 } // .
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
    
    if cur_line != target_line { return "" }
    
    line_end = line_start
    while line_end < tlen and char_at(text, line_end) != "\n"
        line_end = line_end + 1
        
    cursor = line_start + target_char
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
        
    if w_start >= w_end { return "" }
    return str_sub(text, w_start, w_end)

// ─── Symbol Definition Locator ────────────────────────────────────────────────
// WHY: Enables textDocument/definition (Go-to-Definition) for LSP clients (e.g. VS Code).
// Scans lines in document for function, struct, or variable bindings matching the queried identifier.
fn find_symbol_definition_in_text text symbol
    if len(symbol) == 0 { return -1 }
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
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            elif starts_with_keyword(trimmed, "@fn") == 1
                rem = str_trim(str_sub(trimmed, 3, t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            elif starts_with_keyword(trimmed, "কাজ") == 1
                rem = str_trim(str_sub(trimmed, len("কাজ"), t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            // 2. Struct declarations: struct, @struct, কাঠামো, দল
            elif starts_with_keyword(trimmed, "struct") == 1
                rem = str_trim(str_sub(trimmed, 6, t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            elif starts_with_keyword(trimmed, "@struct") == 1
                rem = str_trim(str_sub(trimmed, 7, t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            elif starts_with_keyword(trimmed, "কাঠামো") == 1
                rem = str_trim(str_sub(trimmed, len("কাঠামো"), t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            // 3. Variable declarations: let, @let, চলক, ধরি
            elif starts_with_keyword(trimmed, "let") == 1
                rem = str_trim(str_sub(trimmed, 3, t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            elif starts_with_keyword(trimmed, "@let") == 1
                rem = str_trim(str_sub(trimmed, 4, t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
            elif starts_with_keyword(trimmed, "চলক") == 1
                rem = str_trim(str_sub(trimmed, len("চলক"), t_len))
                if starts_with_keyword(rem, symbol) == 1 { matched = 1 }
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
    push(items, make_item("std/web.lp", 9, "Web Framework", "Sovereign HTTP Router & Server"))
    push(items, make_item("std/thread.lp", 9, "Native Threads", "Linux Clone Syscall Multithreading"))
    push(items, make_item("std/hashmap.lp", 9, "Hash Map", "Fast Robin-Hood Hash Map"))
    push(items, make_item("std/arena.lp", 9, "Arena Allocator", "High-speed Bump Allocator"))
    push(items, make_item("universe/core/io.lp", 9, "Direct Syscall I/O", "Linux AMD64 Kernel Syscalls"))
    push(items, make_item("universe/core/string.lp", 9, "Unicode String", "String Utilities & Slicing"))
    push(items, make_item("std/math.lp", 9, "Fast Math", "Mathematical Operations"))
    push(items, make_item("std/simd.lp", 9, "SIMD Acceleration", "AVX2 & SSE Vector Math"))
    push(items, make_item("std/crypto.lp", 9, "Sovereign Cryptography", "AES-256-GCM & SHA-256"))
    push(items, make_item("std/db.lp", 9, "Embedded Database", "Embedded Key-Value ACID Store"))

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
    if word == "std/web.lp" or word == "web_router_create"
        return "### `std/web.lp` (Web Framework)\nSovereign HTTP server, JSON routing, and WebSocket engine.\n- `web_router_create()`\n- `web_server_start(port)`"
    if word == "std/thread.lp" or word == "thread_create"
        return "### `std/thread.lp` (Multithreading)\nNative Linux clone syscall threads, mutexes, and atomics.\n- `thread_create(fn_ptr, arg)`\n- `thread_join(th)`"
    if word == "std/hashmap.lp" or word == "hashmap_new"
        return "### `std/hashmap.lp` (Robin Hood Hash Map)\nFast O(1) key-value hash map data structure.\n- `hashmap_new()`\n- `hashmap_set(hm, key, val)`\n- `hashmap_get(hm, key)`"
    if word == "std/arena.lp" or word == "arena_create"
        return "### `std/arena.lp` (Arena Allocator)\nUltra-fast bump memory allocator for batch allocations.\n- `arena_create(size)`\n- `arena_alloc(ar, size)`\n- `arena_reset(ar)`"
    if word == "universe/core/io.lp" or word == "syscall"
        return "### `std/io.lp` (Direct Syscall I/O)\nLow-level I/O via direct Linux AMD64 kernel syscalls (0% Libc).\n- `write_out(msg)`\n- `file_open(path, flags)`"
    if word == "universe/core/string.lp"
        return "### `std/str.lp` (Unicode String Library)\nString manipulation, padding, repeat, and substring slicing.\n- `str_repeat(s, n)`\n- `str_sub(s, start, end)`"
    if word == "std/math.lp"
        return "### `std/math.lp` (Mathematical Library)\nFast integer and float arithmetic, powers, and trigonometry.\n- `abs(x)`, `min(a, b)`, `max(a, b)`"
    if word == "std/simd.lp"
        return "### `std/simd.lp` (Hardware SIMD)\nAVX2 / SSE vector arithmetic operations."
    if word == "std/crypto.lp"
        return "### `std/crypto.lp` (Sovereign Cryptography)\nHardware-accelerated AES-256-GCM and SHA-256."
    if word == "std/db.lp"
        return "### `std/db.lp` (Embedded Database)\nEmbedded key-value storage engine with ACID transactions."
    if word == "malloc" or word == "free"
        return "### Memory Management (`malloc` / `free`)\nDirect kernel memory allocation via SYS_mmap / SYS_munmap."
    
    return "### 👑 Lipi Sovereign Programming Language (লিপি ২.০)\n**Direct Silicon Execution** | 0% Libc | 0% LLVM | Bilingual (English & Bengali)"

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
        else
            if char_at(text, i) == "\n"
                is_eol = 1
                
        if is_eol == 1
            raw_line = str_sub(text, line_start, i)
            line = str_trim(raw_line)
            
            if len(line) == 0
                result = result + "\n"
            else
                // Dedent for closing blocks
                is_dedent = 0
                if starts_with_keyword(line, "else") or starts_with_keyword(line, "নাহলে") or starts_with_keyword(line, "elif") or starts_with_keyword(line, "নাহলে_যদি") or char_at(line, 0) == "}"
                    is_dedent = 1
                    
                print_indent = indent
                if is_dedent == 1 and print_indent > 0
                    print_indent = print_indent - 1
                    
                sp = ""
                s_i = 0
                while s_i < print_indent * 4
                    sp = sp + " "
                    s_i = s_i + 1
                    
                result = result + sp + line + "\n"
                
                // Indent for block openers
                is_indent = 0
                if starts_with_keyword(line, "fn") or starts_with_keyword(line, "কাজ") or starts_with_keyword(line, "if") or starts_with_keyword(line, "যদি") or starts_with_keyword(line, "while") or starts_with_keyword(line, "যতক্ষণ") or starts_with_keyword(line, "for") or starts_with_keyword(line, "প্রতিটি") or starts_with_keyword(line, "struct") or starts_with_keyword(line, "গঠন") or starts_with_keyword(line, "কাঠামো") or starts_with_keyword(line, "else") or starts_with_keyword(line, "নাহলে") or starts_with_keyword(line, "elif") or starts_with_keyword(line, "নাহলে_যদি")
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
                resp = "{\"capabilities\":{\"textDocumentSync\":1,\"completionProvider\":{\"resolveProvider\":false,\"triggerCharacters\":[\".\",\"/\",\"\\\"\",\":\",\" \"]},\"hoverProvider\":true,\"documentFormattingProvider\":true,\"definitionProvider\":true,\"referencesProvider\":true},\"serverInfo\":{\"name\":\"" + sname + "\",\"version\":\"" + sver + "\"}}"
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
                diag_params = "{\"uri\":\"" + uri + "\",\"diagnostics\":[]}"
                lsp_send_notification("textDocument/publishDiagnostics", diag_params)

            // ── 4. textDocument/didChange ──
            elif method == "textDocument/didChange"
                uri = json_extract_str_value(raw_msg, "uri")
                raw_text = json_extract_str_value(raw_msg, "text")
                doc_text = json_unescape(raw_text)
                workspace_set_file(tracked_uris, tracked_texts, uri, doc_text)
                lsp_log("didChange updated file: " + uri)
                diag_params = "{\"uri\":\"" + uri + "\",\"diagnostics\":[]}"
                lsp_send_notification("textDocument/publishDiagnostics", diag_params)

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

            // ── 8. textDocument/definition (Go-to-Definition) ──
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
                    // Search in other tracked workspace files
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
                        
                if found_line >= 0
                    resp = "{\"uri\":\"" + found_uri + "\",\"range\":{\"start\":{\"line\":" + str(found_line) + ",\"character\":0},\"end\":{\"line\":" + str(found_line) + ",\"character\":0}}}"
                    lsp_send_response(req_id, resp)
                else
                    lsp_send_response(req_id, "null")

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
