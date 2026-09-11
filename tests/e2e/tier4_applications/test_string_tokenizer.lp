@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP 4: LEXICAL STRING TOKENIZER
@! File: tests/e2e/tier4_applications/test_string_tokenizer.maya
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@struct Token
  type_id: 0  @! 1=INT, 2=IDENT, 3=PLUS, 4=STAR, 5=ASSIGN, 6=LPAREN, 7=RPAREN, 8=SEMI
  int_val: 0
@end

@fn make_token(t_id, val)
  return { type_id: t_id, int_val: val }
@end

@fn parse_char_token(ch_code)
  @match ch_code
    case 43:  @! '+'
      return make_token(3, 0)
    case 42:  @! '*'
      return make_token(4, 0)
    case 61:  @! '='
      return make_token(5, 0)
    case 40:  @! '('
      return make_token(6, 0)
    case 41:  @! ')'
      return make_token(7, 0)
    case 59:  @! ';'
      return make_token(8, 0)
    case _:
      return make_token(0, 0)
  @end
@end

@fn tokenize_byte_stream(stream, length)
  tokens = []
  i = 0
  @while i < length
    byte_val = stream[i]
    @! Check if whitespace (space = 32)
    @if byte_val == 32
      i = i + 1
    @elif byte_val >= 48 && byte_val <= 57
      @! Single-digit integer token
      digit = byte_val - 48
      tokens.push(make_token(1, digit))
      i = i + 1
    @else
      tok = parse_char_token(byte_val)
      @if tok.type_id != 0
        tokens.push(tok)
      @end
      i = i + 1
    @end
  @end
  return tokens
@end

@fn count_tokens_by_type(tokens, length, target_type)
  count = 0
  i = 0
  @while i < length
    @if tokens[i].type_id == target_type
      count = count + 1
    @end
    i = i + 1
  @end
  return count
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application 4: Lexical Tokenizer in Pure Maya")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.4.1: Tokenization of Operator Character Codes
  total = total + 1
  t_plus = parse_char_token(43)
  t_star = parse_char_token(42)
  t_eq = parse_char_token(61)
  @if t_plus.type_id == 3 && t_star.type_id == 4 && t_eq.type_id == 5
    passed = passed + 1
    println("  [PASS] T4.4.1: Operator character token parsing (PLUS, STAR, ASSIGN)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.1: Operator token parsing")
  @end

  @! T4.4.2: Delimiter Token Parsing
  total = total + 1
  t_lp = parse_char_token(40)
  t_rp = parse_char_token(41)
  t_semi = parse_char_token(59)
  @if t_lp.type_id == 6 && t_rp.type_id == 7 && t_semi.type_id == 8
    passed = passed + 1
    println("  [PASS] T4.4.2: Delimiter token parsing (LPAREN, RPAREN, SEMI)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.2: Delimiter token parsing")
  @end

  @! T4.4.3: Tokenize Expression Stream: "3 + 5 * (2);"
  @! ASCII: 3(51), space(32), +(43), space(32), 5(53), space(32), *(42), space(32), ((40), 2(50), )(41), ;(59)
  total = total + 1
  stream = [51, 32, 43, 32, 53, 32, 42, 32, 40, 50, 41, 59]
  token_list = tokenize_byte_stream(stream, 12)
  @! Expected 7 tokens: INT(3), PLUS, INT(5), STAR, LPAREN, INT(2), RPAREN, SEMI -> 8 tokens total
  int_tokens = count_tokens_by_type(token_list, 8, 1)
  @if token_list[0].type_id == 1 && token_list[0].int_val == 3 && int_tokens == 3
    passed = passed + 1
    println("  [PASS] T4.4.3: Byte stream tokenizer produces structured token stream (3 INTs)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.3: Byte stream tokenizer")
  @end

  @! T4.4.4: Verify Token Sequence and Structure
  total = total + 1
  @! Sequence: [INT(3), PLUS(3), INT(5), STAR(4), LPAREN(6), INT(2), RPAREN(7), SEMI(8)]
  @if token_list[1].type_id == 3 && token_list[3].type_id == 4 && token_list[4].type_id == 6 && token_list[7].type_id == 8
    passed = passed + 1
    println("  [PASS] T4.4.4: Exact sequential token grammar verified (INT + INT * ( INT ) ;)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.4: Sequential token grammar")
  @end

  @! T4.4.5: Token Filtering & Extraction
  total = total + 1
  total_int_val = token_list[0].int_val + token_list[2].int_val + token_list[5].int_val
  @! 3 + 5 + 2 = 10
  @if total_int_val == 10
    passed = passed + 1
    println("  [PASS] T4.4.5: Numerical value extraction from token payloads (3 + 5 + 2 == 10)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4.5: Numerical value extraction from tokens")
  @end

  println("-----------------------------------------------------------------")
  println("App 4 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Application 4 (String Tokenizer) PASSED")
    return 0
  @else
    println("✗ Application 4 (String Tokenizer) FAILED")
    return 1
  @end
@end
