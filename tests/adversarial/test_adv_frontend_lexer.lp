@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: PURE MAYA LEXER & TOKENIZER
@! Exhaustive Edge Cases, Malformed Literals, Escape Sequences, Fuzzing
@! ============================================================================

import "compiler/frontend/lexer"
import "universe/core/string"
import "universe/core/collections"

@fn assert_eq_i64(actual, expected, test_name)
  @if actual == expected
    println("[PASS] " + test_name + " -> got " + int_to_str(actual))
    return 1
  @else
    println("[FAIL] " + test_name + " -> expected " + int_to_str(expected) + ", got " + int_to_str(actual))
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, test_name)
  @if actual == expected
    println("[PASS] " + test_name + " -> got \"" + actual + "\"")
    return 1
  @else
    println("[FAIL] " + test_name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn assert_true(cond, test_name)
  @if cond == 1
    println("[PASS] " + test_name)
    return 1
  @else
    println("[FAIL] " + test_name)
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS SUITE: PURE MAYA LEXER & TOKENIZER 🔥")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: ESCAPE SEQUENCES & MALFORMED ESCAPES
  @! --------------------------------------------------------------------------
  println("\n--- [Section 1] String Escapes & Boundary Decode ---")

  @! 1.1 All standard escape sequences (tested individually and in combination)
  src_esc = "\"\\n\\t\\r\\\\\\\"\\'\""
  toks_esc = tokenize_source(src_esc)
  @if assert_eq_i64(toks_esc.len(), 2, "Escapes token count (STR + EOF)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_esc[0].tok_type, "STR", "Escapes token type") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_esc[0].tok_val, "\n\t\r\\\"\'", "Decoded standard escapes \\n\\t\\r\\\\\\\"\\'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.2 Null escape \\0
  src_null_esc = "\"\\0\""
  toks_null_esc = tokenize_source(src_null_esc)
  @if assert_eq_str(toks_null_esc[0].tok_type, "STR", "\\0 token type is STR") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.3 Hex escape sequences: \x41 -> 'A', \x30 -> '0', \x7F, \xFF
  src_hex_esc = "\"\\x41\\x42\\x43\\x30\\x7E\""
  toks_hex_esc = tokenize_source(src_hex_esc)
  @if assert_eq_str(toks_hex_esc[0].tok_val, "ABC0~", "Decoded \\x41\\x42\\x43\\x30\\x7E to ABC0~") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.4 Incomplete / malformed hex escape: \x at string end, \xG non-hex
  src_mal_hex = "\"\\x\" \"\\x1\" \"\\xGZ\""
  toks_mal_hex = tokenize_source(src_mal_hex)
  @if assert_eq_i64(toks_mal_hex.len(), 4, "Malformed hex escapes scanned without crash (3 STR + EOF)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.5 Trailing backslash at EOF without closing quote
  src_trail_bs = "\"unterminated with backslash\\"
  toks_trail_bs = tokenize_source(src_trail_bs)
  @if assert_true(toks_trail_bs.len() >= 1, "Trailing backslash string handled without crash") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.6 Backslash barrage
  src_bs_barrage = "\"\\\\\\\\\\\\\""
  toks_bs_b = tokenize_source(src_bs_barrage)
  @if assert_eq_str(toks_bs_b[0].tok_val, "\\\\\\", "6 backslashes decode to 3 backslashes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: STRING INTERPOLATION CORNERS
  @! --------------------------------------------------------------------------
  println("\n--- [Section 2] String Interpolation Corners ---")

  @! 2.1 Multiple contiguous interpolations
  src_multi_interp = "\"" + str_from_char_code(123) + "a" + str_from_char_code(125) + str_from_char_code(123) + "b" + str_from_char_code(125) + str_from_char_code(123) + "c" + str_from_char_code(125) + "\""
  toks_mi = tokenize_source(src_multi_interp)
  @if assert_eq_str(toks_mi[0].tok_type, "INTERP_STR", "Contiguous interpolation tokens detected") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.2 Unclosed interpolation brace in string
  src_unclosed_interp = "\"" + "Prefix " + str_from_char_code(123) + "unclosed_var" + "\""
  toks_ui = tokenize_source(src_unclosed_interp)
  @if assert_eq_str(toks_ui[0].tok_type, "INTERP_STR", "Unclosed interpolation tokenizes cleanly") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.3 Single quote string containing braces does not trigger interpolation
  src_sq_interp = "'{not_interpolated}'"
  toks_sq = tokenize_source(src_sq_interp)
  @if assert_eq_str(toks_sq[0].tok_type, "STR", "Single quote with braces is plain STR") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.4 Empty string
  src_empty = "\"\""
  toks_empty = tokenize_source(src_empty)
  @if assert_eq_str(toks_empty[0].tok_val, "", "Empty double-quoted string value is empty") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: NUMERIC LITERALS EXTREMES & BOUNDARIES
  @! --------------------------------------------------------------------------
  println("\n--- [Section 3] Numeric Literals Extremes & Boundaries ---")

  @! 3.1 Hexadecimal edge cases
  src_hex = "0x0 0x0000 0xDEADBEEF 0x7FFFFFFFFFFFFFFF 0x1_2_3_4"
  toks_h = tokenize_source(src_hex)
  @if assert_eq_i64(toks_h[0].tok_int_val, 0, "0x0 == 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_h[1].tok_int_val, 0, "0x0000 == 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_h[2].tok_int_val, 3735928559, "0xDEADBEEF == 3735928559") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_h[3].tok_int_val, 9223372036854775807, "0x7FFFFFFFFFFFFFFF == INT64_MAX") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_h[4].tok_int_val, 4660, "0x1_2_3_4 == 4660") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.2 Binary edge cases
  src_bin = "0b0 0b1 0b11111111 0b1000_0001"
  toks_b = tokenize_source(src_bin)
  @if assert_eq_i64(toks_b[0].tok_int_val, 0, "0b0 == 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_b[1].tok_int_val, 1, "0b1 == 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_b[2].tok_int_val, 255, "0b11111111 == 255") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_b[3].tok_int_val, 129, "0b1000_0001 == 129") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.3 Digit separators and large decimal ints
  src_dec = "0 100_000_000 9_223_372_036_854_775_807"
  toks_d = tokenize_source(src_dec)
  @if assert_eq_i64(toks_d[0].tok_int_val, 0, "0 == 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_d[1].tok_int_val, 100000000, "100_000_000 == 100000000") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_d[2].tok_int_val, 9223372036854775807, "9_223_372_036_854_775_807 == INT64_MAX") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.4 Floating point variations
  src_flt = "3.14159265 0.001 100.0 1.2e+5 3.4e-2"
  toks_f = tokenize_source(src_flt)
  @if assert_eq_str(toks_f[0].tok_type, "FLOAT", "3.14159265 is FLOAT") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_f[1].tok_type, "FLOAT", "0.001 is FLOAT") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_f[2].tok_type, "FLOAT", "100.0 is FLOAT") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_f[3].tok_type, "FLOAT", "1.2e+5 is FLOAT") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_f[4].tok_type, "FLOAT", "3.4e-2 is FLOAT") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.5 Incomplete 0x and 0b at EOF
  src_inc_hex = "0x"
  toks_ih = tokenize_source(src_inc_hex)
  @if assert_eq_str(toks_ih[0].tok_type, "HEX_INT", "0x at EOF parsed without crash") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  src_inc_bin = "0b"
  toks_ib = tokenize_source(src_inc_bin)
  @if assert_eq_str(toks_ib[0].tok_type, "BIN_INT", "0b at EOF parsed without crash") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: COMMENTS & WHITESPACE STRESS
  @! --------------------------------------------------------------------------
  println("\n--- [Section 4] Comments & Whitespace Stress ---")

  @! 4.1 Unclosed multiline comment at EOF
  src_unclosed_comment = "/* unclosed multiline comment at EOF"
  toks_uc = tokenize_source(src_unclosed_comment)
  @if assert_true(toks_uc.len() >= 1, "Unclosed /* comment terminates safely at EOF") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.2 Comments with nested stars and slashes
  src_star_slash = "/* * / ** / *** */ a"
  toks_ss = tokenize_source(src_star_slash)
  @if assert_eq_str(toks_ss[0].tok_val, "a", "Comment with inner stars/slashes skipped to identifier") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.3 Comments at EOF without newline
  src_eof_comment = "x // comment at eof"
  toks_ec = tokenize_source(src_eof_comment)
  @if assert_eq_str(toks_ec[0].tok_val, "x", "// at EOF without newline processed cleanly") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  src_eof_at_comment = "y @! directive comment at eof"
  toks_eac = tokenize_source(src_eof_at_comment)
  @if assert_eq_str(toks_eac[0].tok_val, "y", "@! at EOF without newline processed cleanly") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.4 Windows CRLF line endings
  src_crlf = "a = 1\r\nb = 2\r\n"
  toks_crlf = tokenize_source(src_crlf)
  @if assert_true(toks_crlf.len() >= 6, "CRLF line endings tokenized correctly") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.5 Empty source and whitespace only
  src_empty_str = ""
  toks_es = tokenize_source(src_empty_str)
  @if assert_eq_i64(toks_es.len(), 1, "Empty source produces 1 EOF token") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_es[0].tok_type, "EOF", "Empty source token is EOF") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  src_ws = "   \t\t   \n  \t  \n  "
  toks_ws = tokenize_source(src_ws)
  @if assert_true(toks_ws.len() >= 1, "Whitespace only produces newlines and EOF") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: IDENTIFIERS & KEYWORD PREFIX DISAMBIGUATION
  @! --------------------------------------------------------------------------
  println("\n--- [Section 5] Identifiers & Keyword Prefix Disambiguation ---")

  @! Identifiers starting with keyword names
  src_kw_idents = "fn_ptr struct_name impl_trait enum_val while_true for_each in_bounds if_condition elif_branch else_clause return_val match_pat break_point continue_loop let_mut var_dec const_val unsafe_ptr as_type import_mod end_of_file try_block catch_err defer_call async_fn await_task handle_err perform_act tensor_shape model_layer type_name trait_def actor_sys supervisor_node spawn_proc effect_sys true_val false_flag none_obj"
  toks_kwi = tokenize_source(src_kw_idents)

  all_idents = 1
  k = 0
  @while k < toks_kwi.len() - 1 @! skip EOF
    @if toks_kwi[k].tok_type != "IDENT"
      all_idents = 0
    @end
    k = k + 1
  @end
  @if assert_eq_i64(all_idents, 1, "All 35 keyword-prefixed identifiers classified as IDENT") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 6: LINE & COLUMN NUMBER TRACKING
  @! --------------------------------------------------------------------------
  println("\n--- [Section 6] Line & Column Tracking Precision ---")

  src_pos = "x = 10\ny = 20\n  z = 30"
  toks_pos = tokenize_source(src_pos)

  @! 'x' is at line 1, col 1
  @if assert_eq_i64(toks_pos[0].tok_line, 1, "x tok_line == 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks_pos[0].tok_col, 1, "x tok_col == 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! find 'y'
  tok_y = toks_pos[4]
  @if assert_eq_str(tok_y.tok_val, "y", "Found 'y' token") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tok_y.tok_line, 2, "y tok_line == 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tok_y.tok_col, 1, "y tok_col == 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! find 'z'
  tok_z = toks_pos[8]
  @if assert_eq_str(tok_z.tok_val, "z", "Found 'z' token") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tok_z.tok_line, 3, "z tok_line == 3") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tok_z.tok_col, 3, "z tok_col == 3 (indented)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 7: NOISE & SYMBOLS STORM FUZZING
  @! --------------------------------------------------------------------------
  println("\n--- [Section 7] Noise & Symbols Storm Fuzzing ---")

  src_storm = ";;; ,,, ... .. . :::: ???? !!! $$$ %%% ^^^ &&& *** ((( ))) {{{ }}} [[[ ]]] +++ --- === << >> <= >= == !="
  toks_storm = tokenize_source(src_storm)
  @if assert_true(toks_storm.len() > 30, "Symbols storm tokenized without crashes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("\n=================================================================")
  println("📊 ADVERSARIAL LEXER RESULTS: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ 100% of pure Maya Lexer adversarial stress tests PASSED!")
    return 0
  @else
    println("❌ Failures detected in pure Maya Lexer adversarial tests!")
    return 1
  @end
@end
