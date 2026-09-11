@! ============================================================================
@! PURE MAYA FRONTEND UNIT & INTEGRATION TESTS: LEXER & SCANNER
@! ============================================================================

import "compiler/frontend/lexer"
import "universe/core/string"

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

@fn main()
  println("=================================================================")
  println("🧪 PURE MAYA LEXER & TOKENIZER COMPREHENSIVE VERIFICATION SUITE 🧪")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! 1. Numeric Literals (Hex, Bin, Float, Dec)
  src_num = "42 0xFF 0b1011 3.14 0x1A2F 0b0 100_000"
  toks = tokenize_source(src_num)

  @if assert_eq_str(toks[0].tok_type, "INT", "Dec int token type") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks[0].tok_int_val, 42, "Dec int value 42") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @if assert_eq_str(toks[1].tok_type, "HEX_INT", "Hex int token type") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks[1].tok_int_val, 255, "Hex int value 0xFF == 255") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @if assert_eq_str(toks[2].tok_type, "BIN_INT", "Bin int token type") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks[2].tok_int_val, 11, "Bin int value 0b1011 == 11") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @if assert_eq_str(toks[3].tok_type, "FLOAT", "Float token type") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @if assert_eq_i64(toks[4].tok_int_val, 6703, "Hex int value 0x1A2F == 6703") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks[5].tok_int_val, 0, "Bin int value 0b0 == 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(toks[6].tok_int_val, 100000, "Digit separator 100_000 == 100000") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2. String Escapes & Decoding
  src_str = "\"Hello\\nWorld\\t\\\"Escaped\\\"\\\\\" 'SingleQuote'"
  toks_str = tokenize_source(src_str)
  @if assert_eq_str(toks_str[0].tok_type, "STR", "String token type") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_str[0].tok_val, "Hello\nWorld\t\"Escaped\"\\", "Decoded escape characters") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_str[1].tok_val, "SingleQuote", "Single quote string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3. String Interpolation Detection
  src_interp = "\"" + "Count: " + str_from_char_code(123) + "count" + str_from_char_code(125) + "\""
  toks_interp = tokenize_source(src_interp)
  @if assert_eq_str(toks_interp[0].tok_type, "INTERP_STR", "Interpolated string detected") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4. Comments Handling (Single-line, Directive, Multi-line block)
  src_comments = "// Single line comment\n@! Directive comment\n/* Multi-line\n   block\n   comment */\nx = 10"
  toks_comm = tokenize_source(src_comments)
  @if assert_eq_str(toks_comm[0].tok_type, "NEWLINE", "Comment newline 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_comm[1].tok_type, "NEWLINE", "Comment newline 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_comm[2].tok_type, "NEWLINE", "Comment newline 3") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_comm[3].tok_type, "IDENT", "Ident after comments") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_comm[3].tok_val, "x", "Ident name is x") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5. Directives & Keywords
  src_dir = "@fn @struct @impl @enum @while @for @parallel_for @if @elif @else @return @match @break @continue @try @catch @defer @end"
  toks_dir = tokenize_source(src_dir)
  @if assert_eq_i64(toks_dir.len(), 19, "18 directives + 1 EOF") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_dir[0].tok_val, "@fn", "Directive @fn") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_dir[1].tok_val, "@struct", "Directive @struct") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_dir[2].tok_val, "@impl", "Directive @impl") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_dir[3].tok_val, "@enum", "Directive @enum") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 6. Operators & Delimiters
  src_ops = "+ - * / % == != < <= > >= && || ! & | ^ ~ << >> |> -> => += -= *= /= %="
  toks_ops = tokenize_source(src_ops)
  @if assert_eq_i64(toks_ops.len(), 29, "28 operators + 1 EOF") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_ops[0].tok_type, "PLUS", "Plus op") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_ops[5].tok_type, "EQ", "Eq op ==") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_ops[11].tok_type, "AND", "Logical AND &&") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_ops[18].tok_type, "SHL", "Shift Left <<") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(toks_ops[20].tok_type, "PIPE", "Pipeline |>") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("=================================================================")
  println("📊 TEST SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ Pure Maya Lexer verification tests passed 100%!")
    return 0
  @else
    return 1
  @end
@end
