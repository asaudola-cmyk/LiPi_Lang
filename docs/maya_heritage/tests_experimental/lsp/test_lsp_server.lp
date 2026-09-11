@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — PURE MAYA LSP SERVER TEST SUITE
@! File: tests/lsp/test_lsp_server.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/tools/lsp/protocol"
import "universe/tools/lsp/server"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(expected.to_str(), str_concat(", got ", actual.to_str()))))))
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if str_eq(actual, expected) == 0
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'")))))))
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🧠 MAYA LANGUAGE SERVER PROTOCOL (LSP) TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Wire Protocol Framing (Content-Length)
  println("▶ Section 1: JSON-RPC 2.0 Wire Protocol Framing...")
  total_tests = total_tests + 1
  raw_body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}"
  framed = lsp_frame_message(raw_body)
  ok1 = assert_true(str_starts_with(framed, "Content-Length: "), "Framed message contains Content-Length header")
  parsed_body = lsp_parse_frame(framed)
  ok2 = assert_eq_str(parsed_body, raw_body, "Parsed wire frame matches original body")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] LSP Wire framing & Content-Length parser verified")
  @end

  @! SECTION 2: Server Initialization (initialize request)
  println("▶ Section 2: LSP Server Handshake & Capabilities (initialize)...")
  total_tests = total_tests + 1
  srv = lsp_server_new()
  init_req = "{\"jsonrpc\":\"2.0\",\"id\":100,\"method\":\"initialize\",\"params\":{}}"
  init_resp = lsp_server_dispatch(srv, init_req)
  ok1 = assert_eq_int(srv.is_initialized, 1, "Server state marked initialized")
  ok2 = assert_true(str_contains(init_resp, "\"completionProvider\""), "Advertises code completion capability")
  ok3 = assert_true(str_contains(init_resp, "\"hoverProvider\":true"), "Advertises hover capability")
  ok4 = assert_true(str_contains(init_resp, "\"definitionProvider\":true"), "Advertises go-to-definition capability")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] LSP Handshake & capability matrix verified")
  @end

  @! SECTION 3: Document Synchronization & Real-Time Diagnostics (didOpen / didChange)
  println("▶ Section 3: Document Sync & Error Diagnostics (textDocument/didOpen)...")
  total_tests = total_tests + 1
  sample_code_err = "@fn broken_code()\n  println(\"Unclosed string\n  a = (1 + 2}}\n@end"
  open_req = str_concat("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"uri\":\"file:///test.maya\",\"text\":\"", str_concat(lsp_escape_json(sample_code_err), "\"}}"))
  diag_notif = lsp_server_dispatch(srv, open_req)
  ok1 = assert_true(str_contains(diag_notif, "textDocument/publishDiagnostics"), "Emits diagnostics notification")
  ok2 = assert_true(str_contains(diag_notif, "E003"), "Detects unclosed string literal (E003)")
  ok3 = assert_true(str_contains(diag_notif, "E001"), "Detects unmatched closing brace (E001)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Real-time lexer & parser error diagnostics verified")
  @end

  @! SECTION 4: Code Completion Engine (textDocument/completion)
  println("▶ Section 4: Code Completion & Symbol Inference (textDocument/completion)...")
  total_tests = total_tests + 1
  valid_code = "@struct Point\n  x: i64,\n  y: i64\n@end\n\n@fn compute_distance(p1, p2)\n  return 42\n@end"
  open_valid = str_concat("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"uri\":\"file:///valid.maya\",\"text\":\"", str_concat(lsp_escape_json(valid_code), "\"}}"))
  lsp_server_dispatch(srv, open_valid)
  
  comp_req = "{\"jsonrpc\":\"2.0\",\"id\":101,\"method\":\"textDocument/completion\",\"params\":{\"uri\":\"file:///valid.maya\"}}"
  comp_resp = lsp_server_dispatch(srv, comp_req)
  ok1 = assert_true(str_contains(comp_resp, "\"@fn\""), "Includes keyword '@fn'")
  ok2 = assert_true(str_contains(comp_resp, "\"@struct\""), "Includes keyword '@struct'")
  ok3 = assert_true(str_contains(comp_resp, "\"println\""), "Includes built-in 'println'")
  ok4 = assert_true(str_contains(comp_resp, "\"compute_distance\""), "Infers user defined function 'compute_distance'")
  ok5 = assert_true(str_contains(comp_resp, "\"Point\""), "Infers user defined struct 'Point'")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Keyword, built-in & user symbol completions verified")
  @end

  @! SECTION 5: Hover Tooltip Preview (textDocument/hover)
  println("▶ Section 5: Hover Documentation Tooltip (textDocument/hover)...")
  total_tests = total_tests + 1
  hover_req = "{\"jsonrpc\":\"2.0\",\"id\":102,\"method\":\"textDocument/hover\",\"params\":{\"uri\":\"file:///valid.maya\"}}"
  hover_resp = lsp_server_dispatch(srv, hover_req)
  ok1 = assert_true(str_contains(hover_resp, "\"contents\""), "Returns hover markdown contents")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hover symbol documentation preview verified")
  @end

  @! SECTION 6: Go-To Definition Navigation (textDocument/definition)
  println("▶ Section 6: Go-to-Definition Navigation (textDocument/definition)...")
  total_tests = total_tests + 1
  def_req = "{\"jsonrpc\":\"2.0\",\"id\":103,\"method\":\"textDocument/definition\",\"params\":{\"uri\":\"file:///valid.maya\"}}"
  def_resp = lsp_server_dispatch(srv, def_req)
  ok1 = assert_true(str_contains(def_resp, "file:///valid.maya"), "Returns URI location of symbol definition")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Symbol jump-to-definition location verified")
  @end

  @! SECTION 7: Document Outline Symbols (textDocument/documentSymbol)
  println("▶ Section 7: Document Outline Hierarchy (textDocument/documentSymbol)...")
  total_tests = total_tests + 1
  sym_req = "{\"jsonrpc\":\"2.0\",\"id\":104,\"method\":\"textDocument/documentSymbol\",\"params\":{\"uri\":\"file:///valid.maya\"}}"
  sym_resp = lsp_server_dispatch(srv, sym_req)
  ok1 = assert_true(str_contains(sym_resp, "\"name\":\"Point\""), "Outlines struct symbol 'Point'")
  ok2 = assert_true(str_contains(sym_resp, "\"name\":\"compute_distance\""), "Outlines function symbol 'compute_distance'")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Document symbol outline tree verified")
  @end

  @! SECTION 8: Server Shutdown Lifecycle
  println("▶ Section 8: Server Shutdown Lifecycle (shutdown / exit)...")
  total_tests = total_tests + 1
  shut_req = "{\"jsonrpc\":\"2.0\",\"id\":105,\"method\":\"shutdown\"}"
  shut_resp = lsp_server_dispatch(srv, shut_req)
  ok1 = assert_eq_int(srv.is_shutdown, 1, "Server marked as shut down")
  ok2 = assert_true(str_contains(shut_resp, "\"result\":null"), "Returns null result for shutdown")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Server shutdown lifecycle verified")
  @end

  println("=================================================================")
  res_msg = str_concat("📊 LSP SERVER TEST RESULTS: ", str_concat(passed_tests.to_str(), str_concat(" / ", str_concat(total_tests.to_str(), " passed"))))
  println(res_msg)
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 8 PURE MAYA LSP TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME LSP TESTS FAILED")
    return 1
  @end
@end
