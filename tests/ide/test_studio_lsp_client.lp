@! ============================================================================
@! MAYA SOVEREIGN IDE — NATIVE LSP CLIENT COMPREHENSIVE TEST SUITE
@! File: tests/ide/test_studio_lsp_client.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/tools/lsp/protocol"
import "universe/tools/lsp/server"
import "universe/ide/lsp_client"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_false(cond, msg)
  @if cond != 0
    println("  [FAIL] Assertion failed (expected false): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🧠 MAYA STUDIO IN-PROCESS LSP CLIENT TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Client Initialization & JSON-RPC Handshake
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: LSP Client Initialization & Handshake...")
  total_tests = total_tests + 1

  client = lsp_client_new()
  ok1 = assert_eq_int(client.server.is_initialized, 1, "Underlying LSP server initialized")
  ok2 = assert_eq_int(client.doc_version, 0, "Initial document version is 0")
  ok3 = assert_false(client.completion_active, "Initial completion popup is inactive")
  ok4 = assert_false(client.hover_active, "Initial hover popup is inactive")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] LSP client initialized and handshaked successfully")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Document Synchronization & Error Diagnostics (didOpen)
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Document Synchronization & Syntax Error Diagnostics...")
  total_tests = total_tests + 1

  err_code = "@fn main()\n  println(\"Unclosed string\n@end"
  client = lsp_client_open(client, "file:///app.maya", err_code)

  ok1 = assert_eq_str(client.doc_uri, "file:///app.maya", "Document URI stored")
  ok2 = assert_eq_int(client.doc_version, 1, "Document version is 1")
  ok3 = assert_true(client.diagnostics.len() > 0, "Diagnostic error emitted for unclosed string")
  
  diag0 = client.diagnostics[0]
  ok4 = assert_eq_int(diag0.severity, 1, "Diagnostic severity is Error (1)")
  ok5 = assert_eq_str(diag0.code, "E003", "Diagnostic error code is E003")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Real-time diagnostic error detection verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Document Mutation & Diagnostic Resolution (didChange)
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Document Mutation & Error Resolution...")
  total_tests = total_tests + 1

  clean_code = "@struct Vector3\n  x: f64\n  y: f64\n  z: f64\n@end\n\n@fn compute_norm(v: Vector3) -> f64\n  return 1.0\n@end"
  client = lsp_client_change(client, "file:///app.maya", clean_code)

  ok1 = assert_eq_int(client.doc_version, 2, "Document version bumped to 2")
  ok2 = assert_eq_int(client.diagnostics.len(), 0, "All diagnostic errors cleared on valid code")

  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Document mutation and diagnostic resolution verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Autocompletion Query & Popup Navigation
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Autocompletion Inference & Navigation...")
  total_tests = total_tests + 1

  client = lsp_client_request_completions(client, "file:///app.maya", 7, 2)
  ok1 = assert_true(client.completion_active, "Completion popup activated")
  ok2 = assert_true(client.completion_items.len() >= 8, "Completions contain keywords and user symbols")
  ok3 = assert_eq_int(client.completion_selected_idx, 0, "Initial completion selected index is 0")

  item0 = lsp_client_get_selected_completion(client)
  ok4 = assert_true(item0 != 0, "First completion item is valid")

  @! Navigate down
  client = lsp_client_next_completion(client)
  ok5 = assert_eq_int(client.completion_selected_idx, 1, "Next completion moves index to 1")

  @! Navigate up
  client = lsp_client_prev_completion(client)
  ok6 = assert_eq_int(client.completion_selected_idx, 0, "Prev completion moves index back to 0")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Autocompletion engine & navigation verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Hover Tooltip & Go-To Definition
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Hover Documentation & Go-to Definition Navigation...")
  total_tests = total_tests + 1

  client = lsp_client_request_hover(client, "file:///app.maya", 6, 6)
  ok1 = assert_true(client.hover_active, "Hover popup activated")
  ok2 = assert_true(str_len(client.hover_text) > 0, "Hover documentation text extracted")

  def_res = lsp_client_request_definition(client, "file:///app.maya", 6, 20)
  ok3 = assert_true(str_index_of(def_res, "file:///app.maya") >= 0, "Go-to definition resolves location")

  client = lsp_client_dismiss_popups(client)
  ok4 = assert_false(client.completion_active, "Completion dismissed")
  ok5 = assert_false(client.hover_active, "Hover dismissed")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hover documentation, definition & dismissal verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 LSP CLIENT TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " LSP CLIENT TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME LSP CLIENT TESTS FAILED")
    return 1
  @end
@end
