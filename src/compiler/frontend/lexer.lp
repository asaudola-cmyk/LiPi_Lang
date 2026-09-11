@! ============================================================================
@! MAYA COMPILER STAGE 1 — 100% PURE MAYA ADVANCED DFA SCANNER & LEXER
@! Zero External Dependencies — Complete 64-Token Set
@! Native Byte-Level Character Scanner
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/ast"

@! ============================================================================
@! 1. TOKEN CREATION & HELPER FUNCTIONS
@! ============================================================================

@struct EscResult
  char_str: string
  next_pos: i64
@end

@struct Token
  tok_type: string
  tok_val: string
  tok_text: string
  tok_id: i64
  tok_line: i64
  tok_col: i64
  tok_int_val: i64
  tok_float_val: f64
@end

@fn lexer_make_token_full(token_type, val, text, type_id, line, col, int_val, float_val)
  return {
    tok_type: token_type,
    tok_val: val,
    tok_text: text,
    tok_id: type_id,
    tok_line: line,
    tok_col: col,
    tok_int_val: int_val,
    tok_float_val: float_val
  }
@end

@fn lexer_make_token(token_type, value, line, col)
  return {
    tok_type: token_type,
    tok_val: value,
    tok_text: value,
    tok_id: 0,
    tok_line: line,
    tok_col: col,
    tok_int_val: 0,
    tok_float_val: 0
  }
@end

@fn tok_type(tok)
  @if tok == 0 return "EOF" @end
  return tok.tok_type
@end

@fn tok_val(tok)
  @if tok == 0 return "" @end
  return tok.tok_val
@end

@fn tok_int_val(tok)
  @if tok == 0 return 0 @end
  return tok.tok_int_val
@end

@fn tok_line(tok)
  @if tok == 0 return 0 @end
  return tok.tok_line
@end

@fn tok_col(tok)
  @if tok == 0 return 0 @end
  return tok.tok_col
@end

@! ASCII Classification Helpers
@fn lex_is_space(c)
  @if c == 32 || c == 9 || c == 13 return 1 @end
  return 0
@end

@fn lex_is_newline(c)
  @if c == 10 return 1 @end
  return 0
@end

@fn lex_is_digit(c)
  @if c >= 48 && c <= 57 return 1 @end
  return 0
@end

@fn lex_is_hex_digit(c)
  @if (c >= 48 && c <= 57) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70) return 1 @end
  return 0
@end

@fn lex_is_alpha(c)
  @if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 return 1 @end
  return 0
@end

@fn lex_is_alnum(c)
  @if lex_is_alpha(c) == 1 || lex_is_digit(c) == 1 return 1 @end
  return 0
@end

@fn hex_char_to_val(c)
  @if c >= 48 && c <= 57 return c - 48 @end
  @if c >= 97 && c <= 102 return c - 97 + 10 @end
  @if c >= 65 && c <= 70 return c - 65 + 10 @end
  return 0
@end

@! ============================================================================
@! 2. STRING ESCAPE DECODER
@! ============================================================================

@fn lex_decode_escape(source, pos, num_items)
  @if pos >= num_items
    return { char_str: "", next_pos: pos }
  @end
  esc_c = str_char_at(source, pos)
  @if esc_c == 110 @! 'n'
    return { char_str: "", next_pos: pos + 1 }
  @elif esc_c == 116 @! 't'
    return { char_str: "", next_pos: pos + 1 }
  @elif esc_c == 114 @! 'r'
    return { char_str: "", next_pos: pos + 1 }
  @elif esc_c == 48 @! '0'
    return { char_str: "", next_pos: pos + 1 }
  @elif esc_c == 92 @! '\\'
    return { char_str: "", next_pos: pos + 1 }
  @elif esc_c == 34 @! '"'
    return { char_str: "", next_pos: pos + 1 }
  @elif esc_c == 39 @! '\''
    return { char_str: "'", next_pos: pos + 1 }
  @elif esc_c == 120 && pos + 2 < num_items @! 'x'
    h1 = str_char_at(source, pos + 1)
    h2 = str_char_at(source, pos + 2)
    @if lex_is_hex_digit(h1) == 1 && lex_is_hex_digit(h2) == 1
      byte_val = hex_char_to_val(h1) * 16 + hex_char_to_val(h2)
      return { char_str: str_from_char_code(byte_val), next_pos: pos + 3 }
    @end
  @end
  return { char_str: str_from_char_code(esc_c), next_pos: pos + 1 }
@end

@! ============================================================================
@! 3. MAIN TOKENIZER / LEXER ENGINE
@! ============================================================================

@fn tokenize_source(source)
  return lexer_tokenize(source, "")
@end

@fn lexer_tokenize(source, filename)
  tokens = []
  num_items = str_len(source)
  i = 0
  line = 1
  col = 1

  @while i < num_items
    c = str_char_at(source, i)

    @! 1. Whitespace
    @if lex_is_space(c) == 1
      i = i + 1
      col = col + 1

    @! 2. Newline
    @elif lex_is_newline(c) == 1
      tokens = tokens.push(lexer_make_token_full("NEWLINE", "", "", 1, line, col, 0, 0))
      i = i + 1
      line = line + 1
      col = 1

    @! 3. Comments (//, @!, /* ... */)
    @elif c == 47 && i + 1 < num_items && str_char_at(source, i + 1) == 47 @! //
      @while i < num_items && str_char_at(source, i) != 10
        i = i + 1
      @end
    @elif c == 64 && i + 1 < num_items && str_char_at(source, i + 1) == 33 @! @!
      @while i < num_items && str_char_at(source, i) != 10
        i = i + 1
      @end
    @elif c == 47 && i + 1 < num_items && str_char_at(source, i + 1) == 42 @! /*
      i = i + 2
      col = col + 2
      @while i + 1 < num_items && (str_char_at(source, i) != 42 || str_char_at(source, i + 1) != 47)
        @if str_char_at(source, i) == 10
          line = line + 1
          col = 1
        @else
          col = col + 1
        @end
        i = i + 1
      @end
      @if i + 1 < num_items
        i = i + 2
        col = col + 2
      @end

    @! 4. Arithmetic & Assignment Operators (+, -, *, /, %)
    @elif c == 43 @! '+'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61
        tokens = tokens.push(lexer_make_token_full("PLUSEQ", "+=", "+=", 15, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("PLUS", "+", "+", 10, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 45 @! '-'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 62 @! '->'
        tokens = tokens.push(lexer_make_token_full("ARROW", "->", "->", 7, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && str_char_at(source, i + 1) == 61 @! '-='
        tokens = tokens.push(lexer_make_token_full("MINUSEQ", "-=", "-=", 16, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("MINUS", "-", "-", 11, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 42 @! '*'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61
        tokens = tokens.push(lexer_make_token_full("STAREQ", "*=", "*=", 17, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("STAR", "*", "*", 12, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 47 @! '/'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61
        tokens = tokens.push(lexer_make_token_full("SLASHEQ", "/=", "/=", 18, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("SLASH", "/", "/", 13, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 37 @! '%'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61
        tokens = tokens.push(lexer_make_token_full("PERCENTEQ", "%=", "%=", 19, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("PERCENT", "%", "%", 14, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end

    @! 5. Relational & Equality Operators (=, ==, =>, !, !=, <, <=, <<, >, >=, >>)
    @elif c == 61 @! '='
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61 @! '=='
        tokens = tokens.push(lexer_make_token_full("EQ", "==", "==", 20, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && str_char_at(source, i + 1) == 62 @! '=>'
        tokens = tokens.push(lexer_make_token_full("FAT_ARROW", "=>", "=>", 8, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("ASSIGN", "=", "=", 36, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 33 @! '!'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61 @! '!='
        tokens = tokens.push(lexer_make_token_full("NEQ", "!=", "!=", 21, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("BANG", "!", "!", 28, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 60 @! '<'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61 @! '<='
        tokens = tokens.push(lexer_make_token_full("LTE", "<=", "<=", 23, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && str_char_at(source, i + 1) == 60 @! '<<'
        tokens = tokens.push(lexer_make_token_full("SHL", "<<", "<<", 33, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("LT", "<", "<", 22, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 62 @! '>'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 61 @! '>='
        tokens = tokens.push(lexer_make_token_full("GTE", ">=", ">=", 25, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && str_char_at(source, i + 1) == 62 @! '>>'
        tokens = tokens.push(lexer_make_token_full("SHR", ">>", ">>", 34, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("GT", ">", ">", 24, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end

    @! 6. Logical & Bitwise Operators (&, &&, |, ||, |>, ^, ~, ?)
    @elif c == 38 @! '&'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 38 @! '&&'
        tokens = tokens.push(lexer_make_token_full("AND", "&&", "&&", 26, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("AMP", "&", "&", 29, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 124 @! '|'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 124 @! '||'
        tokens = tokens.push(lexer_make_token_full("OR", "||", "||", 27, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && str_char_at(source, i + 1) == 62 @! '|>'
        tokens = tokens.push(lexer_make_token_full("PIPE", "|>", "|>", 35, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("BAR", "|", "|", 30, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end
    @elif c == 94 @! '^'
      tokens = tokens.push(lexer_make_token_full("CARET", "^", "^", 31, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 126 @! '~'
      tokens = tokens.push(lexer_make_token_full("TILDE", "~", "~", 32, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 63 @! '?'
      tokens = tokens.push(lexer_make_token_full("QUERY", "?", "?", 9, line, col, 0, 0))
      i = i + 1
      col = col + 1

    @! 7. Delimiters ((), [], {}, ,, :, ;, .)
    @elif c == 40 @! '('
      tokens = tokens.push(lexer_make_token_full("LPAREN", "(", "(", 37, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 41 @! ')'
      tokens = tokens.push(lexer_make_token_full("RPAREN", ")", ")", 38, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 91 @! '['
      tokens = tokens.push(lexer_make_token_full("LBRACKET", "[", "[", 39, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 93 @! ']'
      tokens = tokens.push(lexer_make_token_full("RBRACKET", "]", "]", 40, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 123 @! '{'
      tokens = tokens.push(lexer_make_token_full("LBRACE", "{", "{", 41, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 125 @! '}'
      tokens = tokens.push(lexer_make_token_full("RBRACE", "}", "}", 42, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 44 @! ','
      tokens = tokens.push(lexer_make_token_full("COMMA", ",", ",", 3, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 58 @! ':'
      tokens = tokens.push(lexer_make_token_full("COLON", ":", ":", 4, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 59 @! ';'
      tokens = tokens.push(lexer_make_token_full("SEMI", ";", ";", 2, line, col, 0, 0))
      i = i + 1
      col = col + 1
    @elif c == 46 @! '.'
      @if i + 1 < num_items && str_char_at(source, i + 1) == 46 @! '..'
        tokens = tokens.push(lexer_make_token_full("DOTDOT", "..", "..", 6, line, col, 0, 0))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(lexer_make_token_full("DOT", ".", ".", 5, line, col, 0, 0))
        i = i + 1
        col = col + 1
      @end

    @! 8. Strings & String Interpolation (", ')
    @elif c == 34 || c == 39
      quote_c = c
      quote_str = str_from_char_code(quote_c)
      start_col = col
      str_val = ""
      raw_text = quote_str
      i = i + 1
      col = col + 1
      has_interp = 0

      @while i < num_items && str_char_at(source, i) != quote_c
        cur_c = str_char_at(source, i)
        raw_text = str_concat(raw_text, str_from_char_code(cur_c))
        @if cur_c == 92 && i + 1 < num_items @! '\\'
          raw_text = str_concat(raw_text, str_from_char_code(str_char_at(source, i + 1)))
          esc_res = lex_decode_escape(source, i + 1, num_items)
          str_val = str_concat(str_val, esc_res.char_str)
          adv = esc_res.next_pos - (i + 1)
          i = esc_res.next_pos
          col = col + 1 + adv
        @else
          @if cur_c == 10
            line = line + 1
            col = 1
          @else
            col = col + 1
          @end
          @if quote_c == 34 && cur_c == 123 && i + 1 < num_items && lex_is_alpha(str_char_at(source, i + 1)) == 1
            has_interp = 1
          @end
          str_val = str_concat(str_val, str_from_char_code(cur_c))
          i = i + 1
        @end
      @end

      @if i < num_items && str_char_at(source, i) == quote_c
        raw_text = str_concat(raw_text, quote_str)
        i = i + 1
        col = col + 1
      @end

      @if has_interp == 1
        tokens = tokens.push(lexer_make_token_full("INTERP_STR", str_val, raw_text, 46, line, start_col, 0, 0))
      @else
        tokens = tokens.push(lexer_make_token_full("STR", str_val, raw_text, 45, line, start_col, 0, 0))
      @end

    @! 9. Numeric Literals (Hex, Binary, Float, Decimal)
    @elif lex_is_digit(c) == 1
      start_col = col
      num_str = ""

      @! 9a. Hexadecimal: 0x / 0X
      @if c == 48 && i + 1 < num_items && (str_char_at(source, i + 1) == 120 || str_char_at(source, i + 1) == 88)
        num_str = "0x"
        i = i + 2
        col = col + 2
        hex_val = 0
        @while i < num_items && (lex_is_hex_digit(str_char_at(source, i)) == 1 || str_char_at(source, i) == 95)
          cur_c = str_char_at(source, i)
          @if cur_c != 95
            num_str = str_concat(num_str, str_from_char_code(cur_c))
            hex_val = hex_val * 16 + hex_char_to_val(cur_c)
          @end
          i = i + 1
          col = col + 1
        @end
        tokens = tokens.push(lexer_make_token_full("HEX_INT", num_str, num_str, 43, line, start_col, hex_val, 0))

      @! 9b. Binary: 0b / 0B
      @elif c == 48 && i + 1 < num_items && (str_char_at(source, i + 1) == 98 || str_char_at(source, i + 1) == 66)
        num_str = "0b"
        i = i + 2
        col = col + 2
        bin_val = 0
        @while i < num_items && (str_char_at(source, i) == 48 || str_char_at(source, i) == 49 || str_char_at(source, i) == 95)
          cur_c = str_char_at(source, i)
          @if cur_c != 95
            num_str = str_concat(num_str, str_from_char_code(cur_c))
            bit = 0
            @if cur_c == 49 bit = 1 @end
            bin_val = bin_val * 2 + bit
          @end
          i = i + 1
          col = col + 1
        @end
        tokens = tokens.push(lexer_make_token_full("BIN_INT", num_str, num_str, 43, line, start_col, bin_val, 0))

      @! 9c. Decimal Integer & Floating Point
      @else
        is_float = 0
        int_val = 0
        @while i < num_items && (lex_is_digit(str_char_at(source, i)) == 1 || str_char_at(source, i) == 95 || (str_char_at(source, i) == 46 && i + 1 < num_items && lex_is_digit(str_char_at(source, i + 1)) == 1) || (is_float == 1 && (str_char_at(source, i) == 101 || str_char_at(source, i) == 69)))
          cur_c = str_char_at(source, i)
          @if cur_c == 46 @! '.'
            is_float = 1
            num_str = str_concat(num_str, ".")
          @elif cur_c == 101 || cur_c == 69 @! 'e', 'E'
            is_float = 1
            num_str = str_concat(num_str, str_from_char_code(cur_c))
            @if i + 1 < num_items && (str_char_at(source, i + 1) == 43 || str_char_at(source, i + 1) == 45)
              i = i + 1
              col = col + 1
              num_str = str_concat(num_str, str_from_char_code(str_char_at(source, i)))
            @end
          @elif cur_c != 95 @! not '_'
            num_str = str_concat(num_str, str_from_char_code(cur_c))
            @if is_float == 0
              int_val = int_val * 10 + (cur_c - 48)
            @end
          @end
          i = i + 1
          col = col + 1
        @end

        @if is_float == 1
          tokens = tokens.push(lexer_make_token_full("FLOAT", num_str, num_str, 44, line, start_col, 0, 0))
        @else
          tokens = tokens.push(lexer_make_token_full("INT", num_str, num_str, 43, line, start_col, int_val, 0))
        @end
      @end

    @! 10. Directives (@...)
    @elif c == 64 @! '@'
      start_col = col
      dir_name = "@"
      i = i + 1
      col = col + 1
      @while i < num_items && (lex_is_alnum(str_char_at(source, i)) == 1)
        dir_name = str_concat(dir_name, str_from_char_code(str_char_at(source, i)))
        i = i + 1
        col = col + 1
      @end

      dir_id = 50
      @if dir_name == "@fn" dir_id = 50
      @elif dir_name == "@struct" dir_id = 51
      @elif dir_name == "@impl" dir_id = 52
      @elif dir_name == "@enum" dir_id = 53
      @elif dir_name == "@while" dir_id = 54
      @elif dir_name == "@for" dir_id = 55
      @elif dir_name == "@parallel_for" dir_id = 56
      @elif dir_name == "@if" dir_id = 57
      @elif dir_name == "@elif" dir_id = 58
      @elif dir_name == "@else" dir_id = 59
      @elif dir_name == "@return" dir_id = 60
      @elif dir_name == "@match" dir_id = 61
      @elif dir_name == "@break" dir_id = 62
      @elif dir_name == "@continue" dir_id = 63
      @elif dir_name == "@try" dir_id = 64
      @elif dir_name == "@catch" dir_id = 65
      @elif dir_name == "@defer" dir_id = 66
      @elif dir_name == "@type" dir_id = 67
      @elif dir_name == "@trait" dir_id = 68
      @elif dir_name == "@actor" dir_id = 69
      @elif dir_name == "@supervisor" dir_id = 70
      @elif dir_name == "@spawn" dir_id = 71
      @elif dir_name == "@effect" dir_id = 72
      @elif dir_name == "@shader" dir_id = 73
      @elif dir_name == "@gpu" dir_id = 74
      @elif dir_name == "@end" dir_id = 75
      @end

      tokens = tokens.push(lexer_make_token_full("DIRECTIVE", dir_name, dir_name, dir_id, line, start_col, 0, 0))

    @! 11. Identifiers & Keywords
    @elif lex_is_alpha(c) == 1
      start_col = col
      ident_str = ""
      @while i < num_items && (lex_is_alnum(str_char_at(source, i)) == 1)
        ident_str = str_concat(ident_str, str_from_char_code(str_char_at(source, i)))
        i = i + 1
        col = col + 1
      @end

      @if ident_str == "fn"
        tokens = tokens.push(lexer_make_token_full("FN", ident_str, ident_str, 76, line, start_col, 0, 0))
      @elif ident_str == "struct"
        tokens = tokens.push(lexer_make_token_full("STRUCT", ident_str, ident_str, 77, line, start_col, 0, 0))
      @elif ident_str == "impl"
        tokens = tokens.push(lexer_make_token_full("IMPL", ident_str, ident_str, 78, line, start_col, 0, 0))
      @elif ident_str == "enum"
        tokens = tokens.push(lexer_make_token_full("ENUM", ident_str, ident_str, 79, line, start_col, 0, 0))
      @elif ident_str == "while"
        tokens = tokens.push(lexer_make_token_full("WHILE", ident_str, ident_str, 80, line, start_col, 0, 0))
      @elif ident_str == "for"
        tokens = tokens.push(lexer_make_token_full("FOR", ident_str, ident_str, 81, line, start_col, 0, 0))
      @elif ident_str == "in"
        tokens = tokens.push(lexer_make_token_full("IN", ident_str, ident_str, 82, line, start_col, 0, 0))
      @elif ident_str == "if"
        tokens = tokens.push(lexer_make_token_full("IF", ident_str, ident_str, 83, line, start_col, 0, 0))
      @elif ident_str == "elif"
        tokens = tokens.push(lexer_make_token_full("ELIF", ident_str, ident_str, 84, line, start_col, 0, 0))
      @elif ident_str == "else"
        tokens = tokens.push(lexer_make_token_full("ELSE", ident_str, ident_str, 85, line, start_col, 0, 0))
      @elif ident_str == "return"
        tokens = tokens.push(lexer_make_token_full("RETURN", ident_str, ident_str, 86, line, start_col, 0, 0))
      @elif ident_str == "match"
        tokens = tokens.push(lexer_make_token_full("MATCH", ident_str, ident_str, 87, line, start_col, 0, 0))
      @elif ident_str == "case"
        tokens = tokens.push(lexer_make_token_full("CASE", ident_str, ident_str, 88, line, start_col, 0, 0))
      @elif ident_str == "break"
        tokens = tokens.push(lexer_make_token_full("BREAK", ident_str, ident_str, 89, line, start_col, 0, 0))
      @elif ident_str == "continue"
        tokens = tokens.push(lexer_make_token_full("CONTINUE", ident_str, ident_str, 90, line, start_col, 0, 0))
      @elif ident_str == "let"
        tokens = tokens.push(lexer_make_token_full("LET", ident_str, ident_str, 91, line, start_col, 0, 0))
      @elif ident_str == "var"
        tokens = tokens.push(lexer_make_token_full("VAR", ident_str, ident_str, 92, line, start_col, 0, 0))
      @elif ident_str == "mut"
        tokens = tokens.push(lexer_make_token_full("MUT", ident_str, ident_str, 93, line, start_col, 0, 0))
      @elif ident_str == "const"
        tokens = tokens.push(lexer_make_token_full("CONST", ident_str, ident_str, 94, line, start_col, 0, 0))
      @elif ident_str == "unsafe"
        tokens = tokens.push(lexer_make_token_full("UNSAFE", ident_str, ident_str, 95, line, start_col, 0, 0))
      @elif ident_str == "as"
        tokens = tokens.push(lexer_make_token_full("AS", ident_str, ident_str, 96, line, start_col, 0, 0))
      @elif ident_str == "import"
        tokens = tokens.push(lexer_make_token_full("IMPORT", ident_str, ident_str, 97, line, start_col, 0, 0))
      @elif ident_str == "end"
        tokens = tokens.push(lexer_make_token_full("END", ident_str, ident_str, 98, line, start_col, 0, 0))
      @elif ident_str == "try"
        tokens = tokens.push(lexer_make_token_full("TRY", ident_str, ident_str, 99, line, start_col, 0, 0))
      @elif ident_str == "catch"
        tokens = tokens.push(lexer_make_token_full("CATCH", ident_str, ident_str, 100, line, start_col, 0, 0))
      @elif ident_str == "defer"
        tokens = tokens.push(lexer_make_token_full("DEFER", ident_str, ident_str, 101, line, start_col, 0, 0))
      @elif ident_str == "async"
        tokens = tokens.push(lexer_make_token_full("ASYNC", ident_str, ident_str, 102, line, start_col, 0, 0))
      @elif ident_str == "await"
        tokens = tokens.push(lexer_make_token_full("AWAIT", ident_str, ident_str, 103, line, start_col, 0, 0))
      @elif ident_str == "handle"
        tokens = tokens.push(lexer_make_token_full("HANDLE", ident_str, ident_str, 104, line, start_col, 0, 0))
      @elif ident_str == "perform"
        tokens = tokens.push(lexer_make_token_full("PERFORM", ident_str, ident_str, 105, line, start_col, 0, 0))
      @elif ident_str == "tensor"
        tokens = tokens.push(lexer_make_token_full("TENSOR", ident_str, ident_str, 106, line, start_col, 0, 0))
      @elif ident_str == "model"
        tokens = tokens.push(lexer_make_token_full("MODEL", ident_str, ident_str, 107, line, start_col, 0, 0))
      @elif ident_str == "type"
        tokens = tokens.push(lexer_make_token_full("TYPE", ident_str, ident_str, 67, line, start_col, 0, 0))
      @elif ident_str == "trait"
        tokens = tokens.push(lexer_make_token_full("TRAIT", ident_str, ident_str, 68, line, start_col, 0, 0))
      @elif ident_str == "actor"
        tokens = tokens.push(lexer_make_token_full("ACTOR", ident_str, ident_str, 69, line, start_col, 0, 0))
      @elif ident_str == "supervisor"
        tokens = tokens.push(lexer_make_token_full("SUPERVISOR", ident_str, ident_str, 70, line, start_col, 0, 0))
      @elif ident_str == "spawn"
        tokens = tokens.push(lexer_make_token_full("SPAWN", ident_str, ident_str, 71, line, start_col, 0, 0))
      @elif ident_str == "effect"
        tokens = tokens.push(lexer_make_token_full("EFFECT", ident_str, ident_str, 72, line, start_col, 0, 0))
      @elif ident_str == "true"
        tokens = tokens.push(lexer_make_token_full("BOOL", "true", "true", 47, line, start_col, 1, 0))
      @elif ident_str == "false"
        tokens = tokens.push(lexer_make_token_full("BOOL", "false", "false", 47, line, start_col, 0, 0))
      @elif ident_str == "none" || ident_str == "nil" || ident_str == "null"
        tokens = tokens.push(lexer_make_token_full("NONE", "none", ident_str, 48, line, start_col, 0, 0))
      @else
        tokens = tokens.push(lexer_make_token_full("IDENT", ident_str, ident_str, 49, line, start_col, 0, 0))
      @end

    @! 12. Fallback / Skip
    @else
      i = i + 1
      col = col + 1
    @end
  @end

  tokens = tokens.push(lexer_make_token_full("EOF", "", "", 0, line, col, 0, 0))
  return tokens
@end
