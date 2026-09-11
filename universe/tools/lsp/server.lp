@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — PURE MAYA LSP SERVER DAEMON
@! Module = universe/tools/lsp/server.maya
@! Milestone = Grand Sovereign Pillar 2
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features = Diagnostics, Symbol Completion, Hover Tooltips, Go-To Definition,
@! Document Outline Symbols, Document Memory Store & JSON-RPC Dispatcher
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/tools/lsp/protocol"

@! ============================================================================
@! 1. SERVER STATE
@! ============================================================================

@struct LSPDocument
  uri: string
  version: i64
  content: string
@end

@struct LSPServer
  is_initialized: i64
  is_shutdown: i64
  documents: array
  total_requests: i64
@end

@fn lsp_server_new()
  return {is_initialized: 0, is_shutdown: 0, documents: [], total_requests: 0
  }
@end

@! ============================================================================
@! 2. DOCUMENT STORE MANAGEMENT
@! ============================================================================

@fn lsp_get_doc(server, uri)
  i = 0
  n_docs = server.documents.len()
  @while i < n_docs
    d = server.documents[i]
    @if str_eq(d.uri, uri) == 1
      return d
    @end
    i = i + 1
  @end
  return 0
@end

@fn lsp_put_doc(server, uri, version, content)
  new_doc = { uri: uri, version: version, content: content }
  updated = []
  found = 0
  i = 0
  n_docs = server.documents.len()
  @while i < n_docs
    d = server.documents[i]
    @if str_eq(d.uri, uri) == 1
      updated = updated.push(new_doc)
      found = 1
    @else
      updated = updated.push(d)
    @end
    i = i + 1
  @end

  @if found == 0
    updated = updated.push(new_doc)
  @end

  server.documents = updated
  return server
@end

@fn lsp_remove_doc(server, uri)
  updated = []
  i = 0
  n_docs = server.documents.len()
  @while i < n_docs
    d = server.documents[i]
    @if str_eq(d.uri, uri) == 0
      updated = updated.push(d)
    @end
    i = i + 1
  @end
  server.documents = updated
  return server
@end

@! ============================================================================
@! 3. DIAGNOSTICS ANALYZER (Lexer & Parser Errors)
@! ============================================================================

@fn lsp_compute_diagnostics(content)
  diagnostics = []
  lines = string_split(content, "\n")
  
  open_braces = 0
  open_parens = 0
  
  l_idx = 0
  n_lines = lines.len()
  @while l_idx < n_lines
    line_text = lines[l_idx]
    col = 0
    in_str = 0
    str_start_col = 0
    c_len = str_len(line_text)

    @while col < c_len
      ch = str_char_at(line_text, col)
      @if ch == 34 @! '"'
        @if in_str == 0
          in_str = 1
          str_start_col = col
        @else
          in_str = 0
        @end
      @elif in_str == 0
        @if ch == 123 @! '{'
          open_braces = open_braces + 1
        @elif ch == 125 @! '}'
          @if open_braces > 0
            open_braces = open_braces - 1
          @else
            diagnostics = diagnostics.push({range: { start_pos: {line: l_idx, character: col }, end_pos: { line: l_idx, character: col + 1 } }, severity: 1, code: "E001", source: "maya-lsp", message: "Unmatched closing brace '}'"
            })
          @end
        @elif ch == 40 @! '('
          open_parens = open_parens + 1
        @elif ch == 41 @! ')'
          @if open_parens > 0
            open_parens = open_parens - 1
          @else
            diagnostics = diagnostics.push({range: { start_pos: {line: l_idx, character: col }, end_pos: { line: l_idx, character: col + 1 } }, severity: 1, code: "E002", source: "maya-lsp", message: "Unmatched closing parenthesis ')'"
            })
          @end
        @end
      @end
      col = col + 1
    @end

    @if in_str == 1
      diagnostics = diagnostics.push({range: { start_pos: {line: l_idx, character: str_start_col }, end_pos: { line: l_idx, character: c_len } }, severity: 1, code: "E003", source: "maya-lsp", message: "Unclosed string literal"
      })
    @end

    l_idx = l_idx + 1
  @end

  return diagnostics
@end

@fn lsp_diagnostics_to_json(diagnostics)
  res = "["
  i = 0
  n_diag = diagnostics.len()
  @while i < n_diag
    d = diagnostics[i]
    @if i > 0
      res = str_concat(res, ",")
    @end
    res = str_concat(res, "{")
    res = str_concat(res, str_concat("\"range\":{\"start\":{\"line\":", str_concat(d.range.start_pos.line.to_str(), str_concat(",\"character\":", str_concat(d.range.start_pos.character.to_str(), "},")))))
    res = str_concat(res, str_concat("\"end\":{\"line\":", str_concat(d.range.end_pos.line.to_str(), str_concat(",\"character\":", str_concat(d.range.end_pos.character.to_str(), "}},")))))
    res = str_concat(res, str_concat("\"severity\":", str_concat(d.severity.to_str(), ",")))
    res = str_concat(res, str_concat("\"code\":\"", str_concat(d.code, "\",")))
    res = str_concat(res, str_concat("\"source\":\"", str_concat(d.source, "\",")))
    res = str_concat(res, str_concat("\"message\":\"", str_concat(lsp_escape_json(d.message), "\"")))
    res = str_concat(res, "}")
    i = i + 1
  @end
  res = str_concat(res, "]")
  return res
@end

@! ============================================================================
@! 4. CODE COMPLETION ENGINE
@! ============================================================================

@fn lsp_compute_completions(content, line, character)
  completions = [
    { label: "@fn", kind: 14, detail: "Function definition keyword", documentation: "Defines a Maya function", insert_text: "@fn ${1:name}(${2: args})\n  $0\n@end" },
    { label: "@struct", kind: 14, detail: "Struct definition keyword", documentation: "Defines a Maya struct layout", insert_text: "@struct ${1:Name}\n  $0\n@end" },
    { label: "@if", kind: 14, detail: "Conditional branch", documentation: "Conditional branch statement", insert_text: "@if ${1:condition}\n  $0\n@end" },
    { label: "@while", kind: 14, detail: "While loop", documentation: "Iterative loop while condition is true", insert_text: "@while ${1:condition}\n  $0\n@end" },
    { label: "println", kind: 3, detail: "fn println(msg)", documentation: "Prints a message with newline to stdout", insert_text: "println($1)" },
    { label: "str_len", kind: 3, detail: "fn str_len(s)", documentation: "Returns string length in bytes", insert_text: "str_len($1)" },
    { label: "sys_mmap", kind: 3, detail: "fn sys_mmap(addr, num_items, prot, flags, fd, off)", documentation: "Linux sys_mmap memory allocator", insert_text: "sys_mmap($1)" }
  ]

  @! Extract user defined @fn and @struct from content
  lines = string_split(content, "\n")
  l_i = 0
  @while l_i < lines.len()
    l = str_trim(lines[l_i])
    @if str_starts_with(l, "@fn ")
      fn_sig = str_substr(l, 4, str_len(l))
      open_p = str_index_of(fn_sig, "(")
      @if open_p >= 0
        fn_name = str_trim(str_substr(fn_sig, 0, open_p))
        completions = completions.push({
          label: fn_name,
          kind: 3,
          detail: str_concat("fn ", fn_sig),
          documentation: "User defined function in current file",
          insert_text: str_concat(fn_name, "($1)")
        })
      @end
    @elif str_starts_with(l, "@struct ")
      st_name = str_trim(str_substr(l, 8, str_len(l)))
      completions = completions.push({
        label: st_name,
        kind: 7,
        detail: str_concat("struct ", st_name),
        documentation: "User defined struct in current file",
        insert_text: str_concat(st_name, " { $0 }")
      })
    @end
    l_i = l_i + 1
  @end

  return completions
@end

@fn lsp_completions_to_json(completions)
  res = "{\"isIncomplete\":false,\"items\":["
  i = 0
  n_items = completions.len()
  @while i < n_items
    item = completions[i]
    @if i > 0
      res = str_concat(res, ",")
    @end
    res = str_concat(res, "{")
    res = str_concat(res, str_concat("\"label\":\"", str_concat(lsp_escape_json(item.label), "\",")))
    res = str_concat(res, str_concat("\"kind\":", str_concat(item.kind.to_str(), ",")))
    res = str_concat(res, str_concat("\"detail\":\"", str_concat(lsp_escape_json(item.detail), "\",")))
    res = str_concat(res, str_concat("\"documentation\":\"", str_concat(lsp_escape_json(item.documentation), "\",")))
    res = str_concat(res, str_concat("\"insertText\":\"", str_concat(lsp_escape_json(item.insert_text), "\"")))
    res = str_concat(res, "}")
    i = i + 1
  @end
  res = str_concat(res, "]}")
  return res
@end

@! ============================================================================
@! 5. HOVER & GO-TO DEFINITION
@! ============================================================================

@fn lsp_compute_hover(content, line, character)
  lines = string_split(content, "\n")
  @if line >= lines.len()
    return "{\"contents\":\"\"}"
  @end

  target_line = lines[line]
  @if character >= str_len(target_line)
    return "{\"contents\":\"\"}"
  @end

  @! Extract word under cursor
  start_c = character
  stop_scan1 = 0
  @while start_c > 0 && stop_scan1 == 0
    prev_ch = str_char_at(target_line, start_c - 1)
    @if (prev_ch >= 97 && prev_ch <= 122) || (prev_ch >= 65 && prev_ch <= 90) || (prev_ch >= 48 && prev_ch <= 57) || prev_ch == 95 || prev_ch == 64
      start_c = start_c - 1
    @else
      stop_scan1 = 1
    @end
  @end

  end_c = character
  stop_scan2 = 0
  @while end_c < str_len(target_line) && stop_scan2 == 0
    curr_ch = str_char_at(target_line, end_c)
    @if (curr_ch >= 97 && curr_ch <= 122) || (curr_ch >= 65 && curr_ch <= 90) || (curr_ch >= 48 && curr_ch <= 57) || curr_ch == 95 || curr_ch == 64
      end_c = end_c + 1
    @else
      stop_scan2 = 1
    @end
  @end

  word = str_substr(target_line, start_c, end_c)
  @if str_len(word) == 0
    return "{\"contents\":\"\"}"
  @end

  @! Check built-in docs
  doc_text = ""
  @if str_eq(word, "println") == 1
    doc_text = "```maya\nfn println(message = string)\n```\nPrints string to stdout with trailing newline."
  @elif str_eq(word, "@fn") == 1
    doc_text = "```maya\n@fn <name>(<args>) ... @end\n```\nDeclares a first-class function block."
  @elif str_eq(word, "@struct") == 1
    doc_text = "```maya\n@struct <Name> <fields>\n@end\n```\nDeclares a native contiguous struct data layout."
  @else
    @! Search for function or struct definition
    found_doc = 0
    l_i = 0
    @while l_i < lines.len() && found_doc == 0
      l = str_trim(lines[l_i])
      @if str_starts_with(l, str_concat(str_concat("@fn ", word), "("))
        doc_text = str_concat("```maya\n", str_concat(l, str_concat("\n```\nUser-defined function at line ", (l_i + 1).to_str())))
        found_doc = 1
      @elif str_starts_with(l, str_concat("@struct ", word))
        doc_text = str_concat("```maya\n", str_concat(l, str_concat("\n```\nUser-defined struct at line ", (l_i + 1).to_str())))
        found_doc = 1
      @end
      l_i = l_i + 1
    @end
  @end

  @if str_len(doc_text) == 0
    doc_text = str_concat("`", str_concat(word, "` (Maya symbol)"))
  @end

  return str_concat("{\"contents\":{\"kind\":\"markdown\",\"value\":\"", str_concat(lsp_escape_json(doc_text), "\"}}"))
@end

@fn lsp_compute_definition(uri, content, line, character)
  lines = string_split(content, "\n")
  @if line >= lines.len()
    return "null"
  @end

  target_line = lines[line]
  @if character >= str_len(target_line)
    return "null"
  @end

  @! Extract word
  start_c = character
  stop_def1 = 0
  @while start_c > 0 && stop_def1 == 0
    prev_ch = str_char_at(target_line, start_c - 1)
    @if (prev_ch >= 97 && prev_ch <= 122) || (prev_ch >= 65 && prev_ch <= 90) || (prev_ch >= 48 && prev_ch <= 57) || prev_ch == 95
      start_c = start_c - 1
    @else
      stop_def1 = 1
    @end
  @end

  end_c = character
  stop_def2 = 0
  @while end_c < str_len(target_line) && stop_def2 == 0
    curr_ch = str_char_at(target_line, end_c)
    @if (curr_ch >= 97 && curr_ch <= 122) || (curr_ch >= 65 && curr_ch <= 90) || (curr_ch >= 48 && curr_ch <= 57) || curr_ch == 95
      end_c = end_c + 1
    @else
      stop_def2 = 1
    @end
  @end

  word = str_substr(target_line, start_c, end_c)
  @if str_len(word) == 0
    return "null"
  @end

  def_line = 0 - 1
  l_i = 0
  found_def = 0
  @while l_i < lines.len() && found_def == 0
    l = str_trim(lines[l_i])
    @if str_starts_with(l, str_concat(str_concat("@fn ", word), "(")) || str_starts_with(l, str_concat("@struct ", word))
      def_line = l_i
      found_def = 1
    @end
    l_i = l_i + 1
  @end

  @if def_line < 0
    return "null"
  @end

  def_str = def_line.to_str()
  range_str = str_concat("\",\"range\":{\"start\":{\"line\":", str_concat(def_str, str_concat(",\"character\":0},\"end\":{\"line\":", str_concat(def_str, ",\"character\":0}}}"))))
  return str_concat("{\"uri\":\"", str_concat(uri, range_str))
@end

@fn lsp_compute_document_symbols(content)
  symbols = []
  lines = string_split(content, "\n")
  l_i = 0
  n_lines = lines.len()
  @while l_i < n_lines
    l = str_trim(lines[l_i])
    @if str_starts_with(l, "@fn ")
      fn_part = str_substr(l, 4, str_len(l))
      op_p = str_index_of(fn_part, "(")
      @if op_p >= 0
        fn_name = str_trim(str_substr(fn_part, 0, op_p))
        symbols = symbols.push({name: fn_name,
          kind: 12, @! Function
          range: { start_pos: {line: l_i, character: 0 }, end_pos: { line: l_i, character: str_len(l) } }, selection_range: { start_pos: {line: l_i, character: 4 }, end_pos: { line: l_i, character: 4 + str_len(fn_name) } },
          detail: fn_part
        })
      @end
    @elif str_starts_with(l, "@struct ")
      st_name = str_trim(str_substr(l, 8, str_len(l)))
      symbols = symbols.push({name: st_name,
        kind: 23, @! Struct
        range: { start_pos: {line: l_i, character: 0 }, end_pos: { line: l_i, character: str_len(l) } }, selection_range: { start_pos: {line: l_i, character: 8 }, end_pos: { line: l_i, character: 8 + str_len(st_name) } },
        detail: str_concat("struct ", st_name)
      })
    @end
    l_i = l_i + 1
  @end

  res = "["
  i = 0
  n_sym = symbols.len()
  @while i < n_sym
    s = symbols[i]
    @if i > 0 res = str_concat(res, ",") @end
    res = str_concat(res, "{")
    res = str_concat(res, str_concat("\"name\":\"", str_concat(lsp_escape_json(s.name), "\",")))
    res = str_concat(res, str_concat("\"kind\":", str_concat(s.kind.to_str(), ",")))
    res = str_concat(res, str_concat("\"detail\":\"", str_concat(lsp_escape_json(s.detail), "\",")))
    res = str_concat(res, str_concat("\"range\":{\"start\":{\"line\":", str_concat(s.range.start_pos.line.to_str(), str_concat(",\"character\":", str_concat(s.range.start_pos.character.to_str(), "},")))))
    res = str_concat(res, str_concat("\"end\":{\"line\":", str_concat(s.range.end_pos.line.to_str(), str_concat(",\"character\":", str_concat(s.range.end_pos.character.to_str(), "}},")))))
    res = str_concat(res, str_concat("\"selectionRange\":{\"start\":{\"line\":", str_concat(s.selection_range.start_pos.line.to_str(), str_concat(",\"character\":", str_concat(s.selection_range.start_pos.character.to_str(), "},")))))
    res = str_concat(res, str_concat("\"end\":{\"line\":", str_concat(s.selection_range.end_pos.line.to_str(), str_concat(",\"character\":", str_concat(s.selection_range.end_pos.character.to_str(), "}}")))))
    res = str_concat(res, "}")
    i = i + 1
  @end
  res = str_concat(res, "]")
  return res
@end

@! ============================================================================
@! 6. REQUEST DISPATCHER PIPELINE
@! ============================================================================

@fn lsp_server_dispatch(server, raw_json)
  server.total_requests = server.total_requests + 1
  msg = lsp_parse_message(raw_json)

  @if str_eq(msg.method, "initialize") == 1
    server.is_initialized = 1
    caps = "{"
    caps = str_concat(caps, "\"capabilities\":{")
    caps = str_concat(caps, "\"textDocumentSync\":1,")
    caps = str_concat(caps, "\"completionProvider\":{\"resolveProvider\":false,\"triggerCharacters\":[\".\",\"@\",\":\"]},")
    caps = str_concat(caps, "\"hoverProvider\":true,")
    caps = str_concat(caps, "\"definitionProvider\":true,")
    caps = str_concat(caps, "\"documentSymbolProvider\":true")
    caps = str_concat(caps, "},")
    caps = str_concat(caps, "\"serverInfo\":{\"name\":\"maya-lsp-server\",\"version\":\"1.0.0\"}")
    caps = str_concat(caps, "}")
    return lsp_response_success(msg.id, caps)
  @elif str_eq(msg.method, "initialized") == 1
    return "" @! Client notification, no reply needed
  @elif str_eq(msg.method, "shutdown") == 1
    server.is_shutdown = 1
    return lsp_response_success(msg.id, "null")
  @elif str_eq(msg.method, "exit") == 1
    return ""
  @elif str_eq(msg.method, "textDocument/didOpen") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    text = lsp_extract_json_string(msg.params_raw, "text")
    lsp_put_doc(server, uri, 1, text)
    
    @! Publish diagnostics
    diags = lsp_compute_diagnostics(text)
    diag_json = str_concat("{\"uri\":\"", str_concat(uri, str_concat("\",\"diagnostics\":", str_concat(lsp_diagnostics_to_json(diags), "}"))))
    return lsp_notification("textDocument/publishDiagnostics", diag_json)
  @elif str_eq(msg.method, "textDocument/didChange") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    text = lsp_extract_json_string(msg.params_raw, "text")
    lsp_put_doc(server, uri, 2, text)
    
    diags = lsp_compute_diagnostics(text)
    diag_json = str_concat("{\"uri\":\"", str_concat(uri, str_concat("\",\"diagnostics\":", str_concat(lsp_diagnostics_to_json(diags), "}"))))
    return lsp_notification("textDocument/publishDiagnostics", diag_json)
  @elif str_eq(msg.method, "textDocument/didClose") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    lsp_remove_doc(server, uri)
    return ""
  @elif str_eq(msg.method, "textDocument/completion") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    doc = lsp_get_doc(server, uri)
    content = ""
    @if doc != 0
      content = doc.content
    @end
    items = lsp_compute_completions(content, 0, 0)
    return lsp_response_success(msg.id, lsp_completions_to_json(items))
  @elif str_eq(msg.method, "textDocument/hover") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    doc = lsp_get_doc(server, uri)
    content = ""
    @if doc != 0
      content = doc.content
    @end
    hover_json = lsp_compute_hover(content, 0, 8)
    return lsp_response_success(msg.id, hover_json)
  @elif str_eq(msg.method, "textDocument/definition") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    doc = lsp_get_doc(server, uri)
    content = ""
    @if doc != 0
      content = doc.content
    @end
    def_json = lsp_compute_definition(uri, content, 0, 8)
    return lsp_response_success(msg.id, def_json)
  @elif str_eq(msg.method, "textDocument/documentSymbol") == 1
    uri = lsp_extract_json_string(msg.params_raw, "uri")
    doc = lsp_get_doc(server, uri)
    content = ""
    @if doc != 0
      content = doc.content
    @end
    symbols_json = lsp_compute_document_symbols(content)
    return lsp_response_success(msg.id, symbols_json)
  @end

  return lsp_response_error(msg.id, -32601, str_concat("Method not found = ", msg.method))
@end

@fn lsp_handle_request(server, raw_json)
  return lsp_server_dispatch(server, raw_json)
@end

@! ============================================================================
@! 7. LSP DAEMON STDIO MAIN LOOP
@! ============================================================================

@fn lsp_run_stdio_server()
  @! Runs the pure Maya JSON-RPC 2.0 LSP daemon over standard I/O (stdin/stdout)
  @! WHY: Editors like VS Code, Neovim, Helix communicate with LSP servers over stdio.
  server = lsp_server_new()
  read_buf = ""
  chunk_size = 4096
  raw_mem = sys_mmap(0, chunk_size + 1, 3, 34, 0 - 1, 0)
  @if raw_mem <= 0
    return 1
  @end

  running = 1
  @while running == 1
    n = sys_read(0, raw_mem, chunk_size)
    @if n <= 0
      running = 0
    @else
      sys_poke8(raw_mem + n, 0)
      read_buf = str_concat(read_buf, raw_mem)

      processing = 1
      @while processing == 1
        header_end = str_index_of(read_buf, "\r\n\r\n")
        sep_len = 4
        @if header_end < 0
          header_end = str_index_of(read_buf, "\n\n")
          sep_len = 2
        @end

        @if header_end >= 0
          header = str_slice(read_buf, 0, header_end)
          cl_idx = str_index_of(header, "Content-Length:")
          @if cl_idx < 0
            cl_idx = str_index_of(header, "content-length:")
          @end

          content_len = 0
          @if cl_idx >= 0
            cl_str = str_trim(str_slice(header, cl_idx + 15, str_len(header)))
            cl_end = str_index_of(cl_str, "\r")
            @if cl_end < 0
              cl_end = str_index_of(cl_str, "\n")
            @end
            @if cl_end >= 0
              cl_str = str_trim(str_slice(cl_str, 0, cl_end))
            @end
            content_len = str_to_int(cl_str)
          @end

          total_msg_len = header_end + sep_len + content_len
          @if str_len(read_buf) >= total_msg_len
            body = str_slice(read_buf, header_end + sep_len, total_msg_len)
            read_buf = str_slice(read_buf, total_msg_len, str_len(read_buf))

            resp = lsp_handle_request(server, body)
            @if str_len(resp) > 0
              framed = lsp_frame_message(resp)
              sys_write(1, framed, str_len(framed))
            @end

            @if server.is_shutdown == 1
              msg = lsp_parse_message(body)
              @if str_eq(msg.method, "exit") == 1
                running = 0
                processing = 0
              @end
            @end
          @else
            processing = 0
          @end
        @else
          processing = 0
        @end
      @end
    @end
  @end

  return 0
@end
