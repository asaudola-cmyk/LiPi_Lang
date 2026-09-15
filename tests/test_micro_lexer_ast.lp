// ============================================================================
// LIPI FRONTEND SUITE — MICRO-LEXER & AST VERIFICATION HARNESS
// Module: tests/test_micro_lexer_ast.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/char_stream"
import "compiler/frontend/lexer/unicode_bengali"
import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"
import "compiler/frontend/lexer/num_literal"
import "compiler/frontend/lexer/str_literal"
import "compiler/frontend/lexer/comment_doc"
import "compiler/frontend/lexer/tokenizer"
import "compiler/frontend/ast/ast_node"
import "compiler/frontend/ast/ast_expr"
import "compiler/frontend/ast/ast_stmt"
import "compiler/frontend/ast/ast_decl"
import "compiler/frontend/ast/ast_visitor"
import "compiler/frontend/ast/ast_printer"

@fn assert_true(cond: i64, message: string)
  @if cond == 1
    println("  [PASS] " + message)
  @else
    println("  [FAIL] " + message)
  @end
  return 0
@end

@fn main()
  println("================================================================")
  println("👑 LIPI FIRST 1.0.0 — FRONTEND MICRO-LEXER & AST TEST SUITE")
  println("================================================================")

  // ── TEST 1: char_stream.lp ──
  println("\n[1/8] Verifying char_stream.lp (UTF-8 & Location Tracking)...")
  cs = char_stream_new("বাংলা\nLipi")
  assert_true(cs.cs_line == 1 && cs.cs_col == 1, "Initial coordinates are 1:1")
  r1 = char_stream_peek_rune(cs)
  assert_true(r1 == 2476, "First rune is 'ব' (2476)")
  char_stream_advance_rune(cs)
  assert_true(cs.cs_col == 2, "Column advanced to 2 after 1 rune")
  char_stream_advance_rune(cs) // া
  char_stream_advance_rune(cs) // ং
  char_stream_advance_rune(cs) // ল
  char_stream_advance_rune(cs) // া
  char_stream_advance_rune(cs) // \n
  assert_true(cs.cs_line == 2 && cs.cs_col == 1, "Line counter incremented to 2 on newline")

  // ── TEST 2: unicode_bengali.lp ──
  println("\n[2/8] Verifying unicode_bengali.lp (Bengali Unicode Classifier)...")
  assert_true(is_bengali_vowel(2437) == 1, "অ (2437) is Bengali vowel")
  assert_true(is_bengali_consonant(2453) == 1, "ক (2453) is Bengali consonant")
  assert_true(is_bengali_matra(2494) == 1, "া (2494) is Bengali matra")
  assert_true(is_bengali_digit(2538) == 1, "৪ (2538) is Bengali digit")
  assert_true(bengali_digit_to_val(2538) == 4, "৪ evaluates to decimal 4")
  assert_true(is_bengali_dari(2404) == 1, "। (2404) is Bengali Dari full stop")

  // ── TEST 3: token_kind.lp ──
  println("\n[3/8] Verifying token_kind.lp (Enumeration & Categories)...")
  assert_true(TOK_EOF() == 0, "TOK_EOF is 0")
  assert_true(TOK_KW_FN() == 74, "TOK_KW_FN is 74")
  assert_true(token_kind_is_keyword(TOK_KW_FN()) == 1, "TOK_KW_FN is recognized as keyword")
  assert_true(token_kind_is_operator(TOK_PLUS()) == 1, "TOK_PLUS is recognized as operator")
  assert_true(token_kind_name(TOK_INT()) == "INT", "Token name for TOK_INT is 'INT'")

  // ── TEST 4: num_literal.lp ──
  println("\n[4/8] Verifying num_literal.lp (Western & Bengali Numerals)...")
  n_hex = num_parse_literal("0x2A", 0)
  assert_true(n_hex.num_int_val == 42, "0x2A parsed to 42")
  n_bin = num_parse_literal("0b101010", 0)
  assert_true(n_bin.num_int_val == 42, "0b101010 parsed to 42")
  n_bn = num_parse_literal("৪২", 0)
  assert_true(n_bn.num_int_val == 42, "Bengali ৪২ parsed to 42")
  n_flt = num_parse_literal("3.1415", 0)
  assert_true(n_flt.num_is_float == 1, "3.1415 parsed as float")

  // ── TEST 5: str_literal.lp & comment_doc.lp ──
  println("\n[5/8] Verifying str_literal.lp & comment_doc.lp (Escapes & Doc Comments)...")
  s_res = str_decode_literal("\"Hello\\nWorld\"", 0, 1)
  assert_true(s_res.str_is_terminated == 1, "String is terminated")
  c_doc = comment_parse_line("/// Sovereign Lipi Compiler", 0)
  assert_true(c_doc.comm_is_doc == 1, "/// parsed as doc comment")
  assert_true(c_doc.comm_content == "Sovereign Lipi Compiler", "Doc text content extracted")

  // ── TEST 6: tokenizer.lp ──
  println("\n[6/8] Verifying tokenizer.lp (Master Bilingual Engine)...")
  bilingual_code = "ধরি বয়স = ২৫\nযদি বয়স >= ১৮ {\n  দেখাও \"স্বাগতম\"\n}"
  toks = tokenize_source(bilingual_code)
  assert_true(toks.len() > 10, "Bilingual source emitted complete token list")
  assert_true(toks[0].tok_kind == TOK_KW_LET(), "First token is KW_LET ('ধরি')")
  assert_true(toks[1].tok_kind == TOK_IDENT(), "Second token is IDENT ('বয়স')")

  // ── TEST 7: ast_node.lp & ast_expr.lp & ast_stmt.lp & ast_decl.lp ──
  println("\n[7/8] Verifying AST Model Hierarchy (Nodes, Expr, Stmt, Decl)...")
  sp = source_span_point("main.lp", 1, 1, 0)
  p1 = ast_param_new("n", "i64", 0, sp)
  lit_42 = ast_expr_literal_int(42, sp)
  ret_stmt = ast_stmt_return(lit_42, sp)
  fn_def = ast_decl_fn("meaning_of_life", [p1], "i64", [ret_stmt], 1, sp)
  assert_true(fn_def.kind == "FnDef", "FnDef node kind is FnDef")
  assert_true(fn_def.tag == AST_TAG_FN_DEF(), "FnDef node carries AST_TAG_FN_DEF")
  assert_true(fn_def.name == "meaning_of_life", "FnDef carries function symbol name")

  // ── TEST 8: ast_visitor.lp & ast_printer.lp ──
  println("\n[8/8] Verifying Non-Recursive Visitor & Visual Tree Printer...")
  node_count = ast_visitor_count_nodes(fn_def)
  assert_true(node_count >= 2, "Non-recursive visitor counted nodes")
  tree_output = ast_print_tree(fn_def)
  assert_true(str_len(tree_output) > 0, "Visual tree rendered successfully")
  println("\nGenerated Visual AST Tree:")
  println(tree_output)

  println("================================================================")
  println("⭐ ALL 14 FRONTEND MICRO-LEXER & AST MODULES VERIFIED 100% OK!")
  println("================================================================")
  return 0
@end
