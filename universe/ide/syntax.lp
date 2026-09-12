@! ============================================================================
@! LIPI SOVEREIGN IDE — SYNTAX HIGHLIGHTING ENGINE & THEME PALETTE
@! Module: universe/ide/syntax.lp
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/frontend/lexer"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct SyntaxSpan
  start_col: i64
  end_col: i64
  color: i64
  token_type: string
@end

@struct SyntaxTheme
  bg_editor: i64        @! 0xFF1E1E1E
  bg_gutter: i64        @! 0xFF252526
  active_line: i64      @! 0xFF282828
  selection: i64        @! 0xFF264F78
  cursor: i64           @! 0xFFFFFFFF
  col_directive: i64    @! 0xFFC586C0 (Purple - @fn, @struct, @if, 
@end)
  col_keyword: i64      @! 0xFF569CD6 (Blue - fn, struct, let, return)
  col_type: i64         @! 0xFF4EC9B0 (Teal - i64, f64, string, bool)
  col_string: i64       @! 0xFFCE9178 (Orange - "string", 'char')
  col_number: i64       @! 0xFFB5CEA8 (Light Green - 123, 0xFF, 3.14)
  col_comment: i64      @! 0xFF6A9955 (Dark Green - //, @!, /* */)
  col_operator: i64     @! 0xFFD4D4D4 (Light Gray - +, -, *, /, |>)
  col_delimiter: i64    @! 0xFFFFD700 (Gold - (), {}, [])
  col_identifier: i64   @! 0xFF9CDCFE (Light Blue - variables, params)
  col_func_call: i64    @! 0xFFDCDCAA (Pale Yellow - println, func)
@end

@! ----------------------------------------------------------------------------
@! 2. THEME CONSTRUCTORS
@! ----------------------------------------------------------------------------

@fn syntax_theme_default()
  return {
    bg_editor: 0xFF1E1E1E,
    bg_gutter: 0xFF252526,
    active_line: 0xFF282828,
    selection: 0xFF264F78,
    cursor: 0xFFFFFFFF,
    col_directive: 0xFFC586C0,
    col_keyword: 0xFF569CD6,
    col_type: 0xFF4EC9B0,
    col_string: 0xFFCE9178,
    col_number: 0xFFB5CEA8,
    col_comment: 0xFF6A9955,
    col_operator: 0xFFD4D4D4,
    col_delimiter: 0xFFFFD700,
    col_identifier: 0xFF9CDCFE,
    col_func_call: 0xFFDCDCAA
  }
@end

@fn syntax_theme_light()
  return {
    bg_editor: 0xFFFFFFFF,
    bg_gutter: 0xFFF3F3F3,
    active_line: 0xFFF0F0F0,
    selection: 0xFFADD6FF,
    cursor: 0xFF000000,
    col_directive: 0xFFAF00DB,
    col_keyword: 0xFF0000FF,
    col_type: 0xFF267F99,
    col_string: 0xFFA31515,
    col_number: 0xFF098658,
    col_comment: 0xFF008000,
    col_operator: 0xFF000000,
    col_delimiter: 0xFF800000,
    col_identifier: 0xFF001080,
    col_func_call: 0xFF795E26
  }
@end

@fn syntax_span_new(start_col, end_col, color, token_type)
  return {
    start_col: start_col,
    end_col: end_col,
    color: color,
    token_type: token_type
  }
@end

@! ----------------------------------------------------------------------------
@! 3. CLASSIFICATION & TOKEN MATCHING HELPERS
@! ----------------------------------------------------------------------------

@fn syntax_is_type(name)
  @if name == "i64" || name == "i32" || name == "i16" || name == "i8"
    return true
  @elif name == "u64" || name == "u32" || name == "u16" || name == "u8"
    return true
  @elif name == "f64" || name == "f32"
    return true
  @elif name == "string" || name == "bool" || name == "array" || name == "void" || name == "any"
    return true
  @elif name == "Canvas" || name == "Widget" || name == "BitmapFont" || name == "Token"
    return true
  @elif name == "SyntaxSpan" || name == "SyntaxTheme" || name == "PID" || name == "LSPDocument"
    return true
  @elif name == "LSPServer" || name == "ProcessRunner" || name == "StudioConsole" || name == "StudioEditor" || name == "MayaStudioApp"
    return true
  @end
  return false
@end

@fn syntax_is_keyword(name)
  @if name == "fn" || name == "struct" || name == "impl" || name == "enum"
    return true
  @elif name == "while" || name == "for" || name == "in" || name == "if" || name == "elif" || name == "else"
    return true
  @elif name == "return" || name == "match" || name == "case" || name == "break" || name == "continue"
    return true
  @elif name == "let" || name == "var" || name == "mut" || name == "const" || name == "unsafe" || name == "as"
    return true
  @elif name == "import" || name == "end" || name == "try" || name == "catch" || name == "defer"
    return true
  @elif name == "async" || name == "await" || name == "handle" || name == "perform"
    return true
  @elif name == "tensor" || name == "model" || name == "type" || name == "trait"
    return true
  @elif name == "actor" || name == "supervisor" || name == "spawn" || name == "effect"
    return true
  @elif name == "true" || name == "false" || name == "none" || name == "nil" || name == "null"
    return true
  @end
  return false
@end

@! ----------------------------------------------------------------------------
@! 4. TOKEN COLOR RESOLVER FOR LEXER TOKENS
@! ----------------------------------------------------------------------------

@fn syntax_color_for_token(tok, theme)
  @if tok == 0 return theme.col_identifier @end
  tt = tok.tok_type
  tv = tok.tok_val

  @if tt == "DIRECTIVE" || str_starts_with(tv, "@")
    return theme.col_directive
  @elif tt == "COMMENT" || tt == "DIRECTIVE_COMMENT"
    return theme.col_comment
  @elif tt == "STR" || tt == "INTERP_STR"
    return theme.col_string
  @elif tt == "INT" || tt == "HEX_INT" || tt == "BIN_INT" || tt == "FLOAT"
    return theme.col_number
  @elif tt == "FN" || tt == "STRUCT" || tt == "IMPL" || tt == "ENUM" || tt == "WHILE" || tt == "FOR" || tt == "IN" || tt == "IF" || tt == "ELIF" || tt == "ELSE" || tt == "RETURN" || tt == "MATCH" || tt == "CASE" || tt == "BREAK" || tt == "CONTINUE" || tt == "LET" || tt == "VAR" || tt == "MUT" || tt == "CONST" || tt == "UNSAFE" || tt == "AS" || tt == "IMPORT" || tt == "END" || tt == "TRY" || tt == "CATCH" || tt == "DEFER" || tt == "ASYNC" || tt == "AWAIT" || tt == "HANDLE" || tt == "PERFORM" || tt == "TENSOR" || tt == "MODEL" || tt == "TYPE" || tt == "TRAIT" || tt == "ACTOR" || tt == "SUPERVISOR" || tt == "SPAWN" || tt == "EFFECT" || tt == "BOOL" || tt == "NONE"
    return theme.col_keyword
  @elif tt == "LPAREN" || tt == "RPAREN" || tt == "LBRACKET" || tt == "RBRACKET" || tt == "LBRACE" || tt == "RBRACE" || tt == "COMMA" || tt == "COLON" || tt == "SEMI" || tt == "DOT" || tt == "DOTDOT"
    return theme.col_delimiter
  @elif tt == "PLUS" || tt == "MINUS" || tt == "STAR" || tt == "SLASH" || tt == "PERCENT" || tt == "PLUSEQ" || tt == "MINUSEQ" || tt == "STAREQ" || tt == "SLASHEQ" || tt == "PERCENTEQ" || tt == "EQ" || tt == "NEQ" || tt == "LT" || tt == "LTE" || tt == "GT" || tt == "GTE" || tt == "AND" || tt == "OR" || tt == "PIPE" || tt == "ARROW" || tt == "FAT_ARROW" || tt == "ASSIGN" || tt == "BANG" || tt == "AMP" || tt == "BAR" || tt == "CARET" || tt == "TILDE" || tt == "QUERY" || tt == "SHL" || tt == "SHR"
    return theme.col_operator
  @elif tt == "IDENT"
    @if syntax_is_type(tv)
      return theme.col_type
    @elif syntax_is_keyword(tv)
      return theme.col_keyword
    @else
      return theme.col_identifier
    @end
  @end

  return theme.col_identifier
@end

@! ----------------------------------------------------------------------------
@! 5. REAL-TIME LINE TOKENIZER & SPAN GENERATOR
@! ----------------------------------------------------------------------------

@fn syntax_tokenize_line(line_text, theme)
  spans = []
  num_items = str_len(line_text)
  @if num_items == 0
    return spans
  @end

  i = 0
  @while i < num_items
    ch = str_char_at(line_text, i)

    @! 1. Skip Whitespace
    @if ch == 32 || ch == 9 || ch == 13
      i = i + 1

    @! 2. Line Comments: // or @!
    @elif (ch == 47 && i + 1 < num_items && str_char_at(line_text, i + 1) == 47) || (ch == 64 && i + 1 < num_items && str_char_at(line_text, i + 1) == 33)
      spans = spans.push(syntax_span_new(i, num_items, theme.col_comment, "COMMENT"))
      i = num_items

    @! 3. Block Comments: /* ... */
    @elif ch == 47 && i + 1 < num_items && str_char_at(line_text, i + 1) == 42
      start_i = i
      i = i + 2
      @while i + 1 < num_items && !(str_char_at(line_text, i) == 42 && str_char_at(line_text, i + 1) == 47)
        i = i + 1
      @end
      @if i + 1 < num_items
        i = i + 2
      @else
        i = num_items
      @end
      spans = spans.push(syntax_span_new(start_i, i, theme.col_comment, "COMMENT"))

    @! 4. Directives: @name
    @elif ch == 64
      start_i = i
      i = i + 1
      @while i < num_items
        c = str_char_at(line_text, i)
        @if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95
          i = i + 1
        @else
          break
        @end
      @end
      spans = spans.push(syntax_span_new(start_i, i, theme.col_directive, "DIRECTIVE"))

    @! 5. Strings: "..." or '...'
    @elif ch == 34 || ch == 39
      quote_c = ch
      start_i = i
      i = i + 1
      @while i < num_items
        c = str_char_at(line_text, i)
        @if c == quote_c
          i = i + 1
          break
        @elif c == 92 && i + 1 < num_items @! Escaped char
          i = i + 2
        @else
          i = i + 1
        @end
      @end
      spans = spans.push(syntax_span_new(start_i, i, theme.col_string, "STRING"))

    @! 6. Hex / Binary / Decimal Numbers
    @elif ch >= 48 && ch <= 57
      start_i = i
      @if ch == 48 && i + 1 < num_items && (str_char_at(line_text, i + 1) == 120 || str_char_at(line_text, i + 1) == 88) @! 0x...
        i = i + 2
        @while i < num_items
          c = str_char_at(line_text, i)
          @if (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102) || c == 95
            i = i + 1
          @else
            break
          @end
        @end
      @elif ch == 48 && i + 1 < num_items && (str_char_at(line_text, i + 1) == 98 || str_char_at(line_text, i + 1) == 66) @! 0b...
        i = i + 2
        @while i < num_items
          c = str_char_at(line_text, i)
          @if c == 48 || c == 49 || c == 95
            i = i + 1
          @else
            break
          @end
        @end
      @else
        @while i < num_items
          c = str_char_at(line_text, i)
          @if (c >= 48 && c <= 57) || c == 95 || (c == 46 && i + 1 < num_items && str_char_at(line_text, i + 1) >= 48 && str_char_at(line_text, i + 1) <= 57)
            i = i + 1
          @else
            break
          @end
        @end
      @end
      spans = spans.push(syntax_span_new(start_i, i, theme.col_number, "NUMBER"))

    @! 7. Identifiers, Keywords, Types, Function Calls
    @elif (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 95
      start_i = i
      @while i < num_items
        c = str_char_at(line_text, i)
        @if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95
          i = i + 1
        @else
          break
        @end
      @end
      word = str_substr(line_text, start_i, i)

      @if syntax_is_keyword(word)
        spans = spans.push(syntax_span_new(start_i, i, theme.col_keyword, "KEYWORD"))
      @elif syntax_is_type(word)
        spans = spans.push(syntax_span_new(start_i, i, theme.col_type, "TYPE"))
      @else
        @! Check if followed by '(' -> function call
        next_k = i
        @while next_k < num_items && (str_char_at(line_text, next_k) == 32 || str_char_at(line_text, next_k) == 9)
          next_k = next_k + 1
        @end
        @if next_k < num_items && str_char_at(line_text, next_k) == 40
          spans = spans.push(syntax_span_new(start_i, i, theme.col_func_call, "FUNC_CALL"))
        @else
          spans = spans.push(syntax_span_new(start_i, i, theme.col_identifier, "IDENTIFIER"))
        @end
      @end

    @! 8. Two-Character Operators: |>, ->, =>, ==, !=, <=, >=, &&, ||, +=, -=, *=, /=, %=, <<, >>, ..
    @elif i + 1 < num_items && ((ch == 124 && str_char_at(line_text, i + 1) == 62) || (ch == 45 && str_char_at(line_text, i + 1) == 62) || (ch == 61 && str_char_at(line_text, i + 1) == 62) || (ch == 61 && str_char_at(line_text, i + 1) == 61) || (ch == 33 && str_char_at(line_text, i + 1) == 61) || (ch == 60 && str_char_at(line_text, i + 1) == 61) || (ch == 62 && str_char_at(line_text, i + 1) == 61) || (ch == 38 && str_char_at(line_text, i + 1) == 38) || (ch == 124 && str_char_at(line_text, i + 1) == 124) || (ch == 43 && str_char_at(line_text, i + 1) == 61) || (ch == 45 && str_char_at(line_text, i + 1) == 61) || (ch == 42 && str_char_at(line_text, i + 1) == 61) || (ch == 47 && str_char_at(line_text, i + 1) == 61) || (ch == 37 && str_char_at(line_text, i + 1) == 61) || (ch == 60 && str_char_at(line_text, i + 1) == 60) || (ch == 62 && str_char_at(line_text, i + 1) == 62) || (ch == 46 && str_char_at(line_text, i + 1) == 46))
      spans = spans.push(syntax_span_new(i, i + 2, theme.col_operator, "OPERATOR"))
      i = i + 2

    @! 9. Delimiters: (), {}, [], ,, :, ;, .
    @elif ch == 40 || ch == 41 || ch == 123 || ch == 125 || ch == 91 || ch == 93 || ch == 44 || ch == 58 || ch == 59 || ch == 46
      spans = spans.push(syntax_span_new(i, i + 1, theme.col_delimiter, "DELIMITER"))
      i = i + 1

    @! 10. Single-Character Operators: +, -, *, /, %, =, <, >, !, &, |, ^, ~, ?
    @elif ch == 43 || ch == 45 || ch == 42 || ch == 47 || ch == 37 || ch == 61 || ch == 60 || ch == 62 || ch == 33 || ch == 38 || ch == 124 || ch == 94 || ch == 126 || ch == 63
      spans = spans.push(syntax_span_new(i, i + 1, theme.col_operator, "OPERATOR"))
      i = i + 1

    @! 11. Fallback Character
    @else
      spans = spans.push(syntax_span_new(i, i + 1, theme.col_identifier, "UNKNOWN"))
      i = i + 1
    @end
  @end

  return spans
@end
