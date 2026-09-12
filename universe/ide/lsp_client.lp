@! ============================================================================
@! LIPI SOVEREIGN IDE — NATIVE IN-PROCESS LSP CLIENT ENGINE
@! Module: universe/ide/lsp_client.lp
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/tools/lsp/protocol"
import "universe/tools/lsp/server"

@! ----------------------------------------------------------------------------
@! 1. LSP CLIENT DATA STRUCTURE
@! ----------------------------------------------------------------------------

@struct LSPClient
  server: LSPServer
  doc_uri: string
  doc_version: i64
  diagnostics: array
  completion_items: array
  completion_active: bool
  completion_selected_idx: i64
  hover_text: string
  hover_active: bool
  hover_line: i64
  hover_col: i64
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTRUCTOR & PROTOCOL HANDSHAKE
@! ----------------------------------------------------------------------------

@fn lsp_client_new()
  srv = lsp_server_new()
  
  @! Perform JSON-RPC 2.0 initialize handshake
  init_req = "{\"jsonrpc\":\"2.0\",\"id\":\"init-1\",\"method\":\"initialize\",\"params\":{\"rootUri\":\"file:///workspace\"}}"
  resp = lsp_server_dispatch(srv, init_req)

  @! Send initialized notification
  init_notif = "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}"
  resp2 = lsp_server_dispatch(srv, init_notif)

  return {
    server: srv,
    doc_uri: "",
    doc_version: 0,
    diagnostics: [],
    completion_items: [],
    completion_active: false,
    completion_selected_idx: 0,
    hover_text: "",
    hover_active: false,
    hover_line: 0,
    hover_col: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 3. DOCUMENT SYNCHRONIZATION (didOpen & didChange)
@! ----------------------------------------------------------------------------

@fn lsp_client_open(client, uri, content)
  open_req = "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"" + uri + "\",\"languageId\":\"maya\",\"version\":1,\"text\":\"" + lsp_escape_json(content) + "\"}}}"
  notif_resp = lsp_server_dispatch(client.server, open_req)

  diags = lsp_compute_diagnostics(content)

  client.doc_uri = uri
  client.doc_version = 1
  client.diagnostics = diags
  return client
@end

@fn lsp_client_change(client, uri, content)
  next_v = client.doc_version + 1
  change_req = "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"" + uri + "\",\"version\":" + next_v.to_str() + "},\"contentChanges\":[{\"text\":\"" + lsp_escape_json(content) + "\"}]}}"
  notif_resp = lsp_server_dispatch(client.server, change_req)

  diags = lsp_compute_diagnostics(content)

  client.doc_uri = uri
  client.doc_version = next_v
  client.diagnostics = diags
  return client
@end

@! ----------------------------------------------------------------------------
@! 4. CODE COMPLETION (Ctrl+Space, Trigger Chars)
@! ----------------------------------------------------------------------------

@fn lsp_client_request_completions(client, uri, line, col)
  comp_req = "{\"jsonrpc\":\"2.0\",\"id\":\"comp-1\",\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"" + uri + "\"},\"position\":{\"line\":" + line.to_str() + ",\"character\":" + col.to_str() + "}}}"
  resp = lsp_server_dispatch(client.server, comp_req)

  content = ""
  i = 0
  n_docs = client.server.documents.len()
  @while i < n_docs
    d = client.server.documents[i]
    @if d.uri == uri
      content = d.content
      break
    @end
    i = i + 1
  @end

  items = lsp_compute_completions(content, line, col)
  client.completion_items = items
  @if items.len() > 0
    client.completion_active = true
    client.completion_selected_idx = 0
  @else
    client.completion_active = false
  @end
  return client
@end

@fn lsp_client_next_completion(client)
  @if client.completion_active == true && client.completion_items.len() > 0
    client.completion_selected_idx = (client.completion_selected_idx + 1) % client.completion_items.len()
  @end
  return client
@end

@fn lsp_client_prev_completion(client)
  @if client.completion_active == true && client.completion_items.len() > 0
    n = client.completion_items.len()
    client.completion_selected_idx = (client.completion_selected_idx - 1 + n) % n
  @end
  return client
@end

@fn lsp_client_get_selected_label(client)
  @if client.completion_active == true && client.completion_items.len() > 0
    idx = client.completion_selected_idx
    @if idx >= 0 && idx < client.completion_items.len()
      it = client.completion_items[idx]
      d = it.detail
      return it.label
    @end
  @end
  return ""
@end

@fn lsp_client_get_selected_completion(client)
  @if client.completion_active == true && client.completion_items.len() > 0
    idx = client.completion_selected_idx
    @if idx >= 0 && idx < client.completion_items.len()
      return client.completion_items[idx]
    @end
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. HOVER TOOLTIPS & GO-TO DEFINITION
@! ----------------------------------------------------------------------------

@fn lsp_client_request_hover(client, uri, line, col)
  hov_req = "{\"jsonrpc\":\"2.0\",\"id\":\"hov-1\",\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"" + uri + "\"},\"position\":{\"line\":" + line.to_str() + ",\"character\":" + col.to_str() + "}}}"
  resp = lsp_server_dispatch(client.server, hov_req)

  content = ""
  i = 0
  n_docs = client.server.documents.len()
  @while i < n_docs
    d = client.server.documents[i]
    @if d.uri == uri
      content = d.content
      break
    @end
    i = i + 1
  @end

  h_json = lsp_compute_hover(content, line, col)
  
  @! Parse contents value
  val = lsp_extract_json_string(h_json, "value")
  @if str_len(val) == 0
    val = lsp_extract_json_string(h_json, "contents")
  @end

  @if str_len(val) > 0
    client.hover_text = val
    client.hover_active = true
    client.hover_line = line
    client.hover_col = col
  @else
    client.hover_text = ""
    client.hover_active = false
  @end
  return client
@end

@fn lsp_client_request_definition(client, uri, line, col)
  def_req = "{\"jsonrpc\":\"2.0\",\"id\":\"def-1\",\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"" + uri + "\"},\"position\":{\"line\":" + line.to_str() + ",\"character\":" + col.to_str() + "}}}"
  resp = lsp_server_dispatch(client.server, def_req)

  content = ""
  i = 0
  n_docs = client.server.documents.len()
  @while i < n_docs
    d = client.server.documents[i]
    @if d.uri == uri
      content = d.content
      break
    @end
    i = i + 1
  @end

  return lsp_compute_definition(uri, content, line, col)
@end

@fn lsp_client_dismiss_popups(client)
  client.completion_active = false
  client.completion_items = []
  client.completion_selected_idx = 0
  client.hover_active = false
  client.hover_text = ""
  return client
@end
