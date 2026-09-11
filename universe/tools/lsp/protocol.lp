@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — PURE MAYA LSP PROTOCOL
@! Module: universe/tools/lsp/protocol.maya
@! Milestone: Grand Sovereign Pillar 2
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: JSON-RPC 2.0 Framing, Wire Codec, LSP Data Structures & Helpers
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"

@! ============================================================================
@! 1. LSP DATA STRUCTURES
@! ============================================================================

@struct LSPPosition
  line: i64
  character: i64
@end

@struct LSPRange
  start_pos: LSPPosition
  end_pos: LSPPosition
@end

@struct LSPLocation
  uri: string
  range: LSPRange
@end

@struct LSPDiagnostic
  range: LSPRange
  severity: i64 @! 1
  code: string
  source: string
  message: string
@end

@struct LSPCompletionItem
  label: string
  kind: i64 @! 1
  detail: string
  documentation: string
  insert_text: string
@end

@struct LSPHover
  contents: string
  range: LSPRange
@end

@struct LSPDocumentSymbol
  name: string
  kind: i64 @! 5
  range: LSPRange
  selection_range: LSPRange
  detail: string
@end

@struct LSPRawMessage
  id: string
  method: string
  params_raw: string
  is_notification: i64
@end

@! ============================================================================
@! 2. JSON UTILITIES
@! ============================================================================

@fn lsp_json_two_bytes(b1, b2)
  buf = sys_mmap(0, 3, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b1)
  sys_poke8(buf + 1, b2)
  sys_poke8(buf + 2, 0)
  return buf
@end

@fn lsp_escape_json(s)
  res = ""
  i = 0
  n = str_len(s)
  @while i < n
    ch = str_char_at(s, i)
    @if ch == 34 @! '"'
      res = str_concat(res, lsp_json_two_bytes(92, 34))
    @elif ch == 92 @! '\'
      res = str_concat(res, lsp_json_two_bytes(92, 92))
    @elif ch == 10 @! '\n'
      res = str_concat(res, lsp_json_two_bytes(92, 110))
    @elif ch == 13 @! '\r'
      res = str_concat(res, lsp_json_two_bytes(92, 114))
    @elif ch == 9 @! '\t'
      res = str_concat(res, lsp_json_two_bytes(92, 116))
    @else
      res = str_concat(res, str_substr(s, i, i + 1))
    @end
    i = i + 1
  @end
  return res
@end

@fn lsp_unescape_json(s)
  res = ""
  i = 0
  n = str_len(s)
  @while i < n
    ch = str_char_at(s, i)
    @if ch == 92 @! '\'
      @if i + 1 < n
        next_ch = str_char_at(s, i + 1)
        @if next_ch == 110 @! 'n'
          res = str_concat(res, "\n")
          i = i + 2
        @elif next_ch == 114 @! 'r'
          res = str_concat(res, "\r")
          i = i + 2
        @elif next_ch == 116 @! 't'
          res = str_concat(res, "\t")
          i = i + 2
        @elif next_ch == 34 @! '"'
          res = str_concat(res, "\"")
          i = i + 2
        @elif next_ch == 92 @! '\'
          buf_slash = sys_mmap(0, 2, 3, 34, 0 - 1, 0)
          sys_poke8(buf_slash, 92)
          sys_poke8(buf_slash + 1, 0)
          res = str_concat(res, buf_slash)
          i = i + 2
        @else
          res = str_concat(res, str_substr(s, i, i + 1))
          i = i + 1
        @end
      @else
        res = str_concat(res, str_substr(s, i, i + 1))
        i = i + 1
      @end
    @else
      res = str_concat(res, str_substr(s, i, i + 1))
      i = i + 1
    @end
  @end
  return res
@end

@fn lsp_extract_json_string(body, key)
  @! Extracts a JSON string or numeric literal for the specified key
  @! WHY: Standard JSON-RPC 2.0 requests may use string or integer identifiers (e.g., "id": 1)
  target = str_concat("\"", str_concat(key, "\""))
  pos = str_index_of(body, target)
  @if pos < 0
    return ""
  @end

  colon_pos = str_index_of(str_substr(body, pos + str_len(target), str_len(body)), ":")
  @if colon_pos < 0
    return ""
  @end

  start_scan = pos + str_len(target) + colon_pos + 1
  blen = str_len(body)

  @! Skip whitespace
  i = start_scan
  @while i < blen && (str_char_at(body, i) == 32 || str_char_at(body, i) == 9 || str_char_at(body, i) == 10 || str_char_at(body, i) == 13)
    i = i + 1
  @end

  @if i >= blen
    return ""
  @end

  ch = str_char_at(body, i)
  @if ch == 34 @! Starts with quote '"'
    first_quote = i
    second_quote = -1
    j = i + 1
    @while j < blen
      c = str_char_at(body, j)
      @if c == 34 && str_char_at(body, j - 1) != 92
        second_quote = j
        j = blen
      @end
      j = j + 1
    @end
    @if second_quote > first_quote
      val_raw = str_substr(body, first_quote + 1, second_quote)
      return lsp_unescape_json(val_raw)
    @end
    return ""
  @end

  @! If numeric literal (e.g. 1, 100) or null
  @if (ch >= 48 && ch <= 57) || ch == 45
    val_start = i
    @while i < blen
      c = str_char_at(body, i)
      @if c < 48 || c > 57
        val_raw = str_substr(body, val_start, i)
        return val_raw
      @end
      i = i + 1
    @end
    return str_substr(body, val_start, blen)
  @end

  return ""
@end

@! ============================================================================
@! 3. WIRE PROTOCOL FRAMING
@! ============================================================================

@fn lsp_frame_message(json_content)
  len_bytes = str_len(json_content)
  header = str_concat("Content-Length: ", str_concat(len_bytes.to_str(), "\r\n\r\n"))
  return str_concat(header, json_content)
@end

@fn lsp_unframe_message(raw_buffer)
  header_end = str_index_of(raw_buffer, "\r\n\r\n")
  @if header_end < 0
    return ""
  @end

  content_start = header_end + 4
  return str_substr(raw_buffer, content_start, str_len(raw_buffer))
@end

@fn lsp_parse_frame(raw_buffer)
  return lsp_unframe_message(raw_buffer)
@end

@fn lsp_parse_message(json_str)
  id = lsp_extract_json_string(json_str, "id")
  method = lsp_extract_json_string(json_str, "method")
  
  is_notif = 0
  @if str_len(id) == 0
    is_notif = 1
  @end

  return {
    id: id,
    method: method,
    params_raw: json_str,
    is_notification: is_notif
  }
@end

@! ============================================================================
@! 4. JSON-RPC BUILDERS
@! ============================================================================

@fn lsp_response_success(id, result_json)
  is_num = 1
  k = 0
  klen = str_len(id)
  @if klen == 0
    is_num = 0
  @end
  @while k < klen
    kc = str_char_at(id, k)
    @if kc < 48 || kc > 57
      is_num = 0
    @end
    k = k + 1
  @end

  id_val = ""
  @if is_num == 1
    id_val = id
  @elif str_eq(id, "null") == 1
    id_val = "null"
  @else
    id_val = str_concat("\"", str_concat(lsp_escape_json(id), "\""))
  @end

  return str_concat("{\"jsonrpc\":\"2.0\",\"id\":", str_concat(id_val, str_concat(",\"result\":", str_concat(result_json, "}"))))
@end

@fn lsp_response_error(id, code, message)
  is_num = 1
  k = 0
  klen = str_len(id)
  @if klen == 0
    is_num = 0
  @end
  @while k < klen
    kc = str_char_at(id, k)
    @if kc < 48 || kc > 57
      is_num = 0
    @end
    k = k + 1
  @end

  id_val = ""
  @if is_num == 1
    id_val = id
  @elif str_eq(id, "null") == 1
    id_val = "null"
  @else
    id_val = str_concat("\"", str_concat(lsp_escape_json(id), "\""))
  @end

  return str_concat("{\"jsonrpc\":\"2.0\",\"id\":", str_concat(id_val, str_concat(",\"error\":{\"code\":", str_concat(code.to_str(), str_concat(",\"message\":\"", str_concat(lsp_escape_json(message), "\"}}"))))))
@end

@fn lsp_notification(method, params_json)
  return str_concat("{\"jsonrpc\":\"2.0\",\"method\":\"", str_concat(method, str_concat("\",\"params\":", str_concat(params_json, "}"))))
@end
