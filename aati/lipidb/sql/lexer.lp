@! ============================================================================
@! LIPI UNIVERSE DB - SQL LEXER (aati/lipidb/sql/lexer.lp)
@! Standard: 100% Pure LiPi SQL Tokenizer (Integers, Floats, Escaped Strings,
@!           Comparison Operators =, !=, <>, <, <=, >, >=, Logical Ops)
@! ============================================================================

import "utso/string"
import "utso/collections"

@struct SqlToken
  tok_kind: string
  tok_value: string
  tok_line: i64
  tok_col: i64
@end

@struct SqlLexer
  lex_input: string
  lex_pos: i64
  lex_num_items: i64
  lex_line: i64
  lex_col: i64
@end

@fn _sql_tok(kind, val, line, col) -> SqlToken
  return { tok_kind: kind, tok_value: val, tok_line: line, tok_col: col }
@end

@fn lexer_new(input) -> SqlLexer
  return { lex_input: input, lex_pos: 0, lex_num_items: str_len(input), lex_line: 1, lex_col: 1 }
@end

@fn lexer_peek_at(lex: SqlLexer, offset)
  idx = lex.lex_pos + offset
  @if idx < 0 || idx >= lex.lex_num_items
    return "\0"
  @end
  return str_substr(lex.lex_input, idx, idx + 1)
@end

@fn lexer_peek_char(lex: SqlLexer)
  @if lex.lex_pos >= lex.lex_num_items
    return "\0"
  @end
  return str_substr(lex.lex_input, lex.lex_pos, lex.lex_pos + 1)
@end

@fn lexer_advance(lex: SqlLexer)
  c = lexer_peek_char(lex)
  lex.lex_pos = lex.lex_pos + 1
  @if c == "\n"
    lex.lex_line = lex.lex_line + 1
    lex.lex_col = 1
  @else
    lex.lex_col = lex.lex_col + 1
  @end
  return c
@end

@fn lexer_skip_whitespace(lex: SqlLexer)
  @while 1
    c = lexer_peek_char(lex)
    @if c == " " || c == "\t" || c == "\n" || c == "\r"
      lexer_advance(lex)
    @else
      break
    @end
  @end
@end

@fn lexer_next_token(lex: SqlLexer) -> SqlToken
  lexer_skip_whitespace(lex)
  @if lex.lex_pos >= lex.lex_num_items
    return _sql_tok("EOF", "", lex.lex_line, lex.lex_col)
  @end

  start_col = lex.lex_col
  start_line = lex.lex_line
  c = lexer_advance(lex)

  @! Identifiers and Keywords
  @if string_is_alpha(c) || c == "_"
    ident = c
    @while 1
      nc = lexer_peek_char(lex)
      @if string_is_alphanum(nc) || nc == "_"
        ident = ident + lexer_advance(lex)
      @else
        break
      @end
    @end

    upper_ident = string_to_upper(ident)
    @if upper_ident == "SELECT" return _sql_tok("SELECT", ident, start_line, start_col) @end
    @if upper_ident == "FROM" return _sql_tok("FROM", ident, start_line, start_col) @end
    @if upper_ident == "WHERE" return _sql_tok("WHERE", ident, start_line, start_col) @end
    @if upper_ident == "INSERT" return _sql_tok("INSERT", ident, start_line, start_col) @end
    @if upper_ident == "INTO" return _sql_tok("INTO", ident, start_line, start_col) @end
    @if upper_ident == "VALUES" return _sql_tok("VALUES", ident, start_line, start_col) @end
    @if upper_ident == "UPDATE" return _sql_tok("UPDATE", ident, start_line, start_col) @end
    @if upper_ident == "SET" return _sql_tok("SET", ident, start_line, start_col) @end
    @if upper_ident == "DELETE" return _sql_tok("DELETE", ident, start_line, start_col) @end
    @if upper_ident == "CREATE" return _sql_tok("CREATE", ident, start_line, start_col) @end
    @if upper_ident == "TABLE" return _sql_tok("TABLE", ident, start_line, start_col) @end
    @if upper_ident == "DROP" return _sql_tok("DROP", ident, start_line, start_col) @end
    @if upper_ident == "JOIN" return _sql_tok("JOIN", ident, start_line, start_col) @end
    @if upper_ident == "GROUP" return _sql_tok("GROUP", ident, start_line, start_col) @end
    @if upper_ident == "BY" return _sql_tok("BY", ident, start_line, start_col) @end
    @if upper_ident == "ORDER" return _sql_tok("ORDER", ident, start_line, start_col) @end
    @if upper_ident == "LIMIT" return _sql_tok("LIMIT", ident, start_line, start_col) @end
    @if upper_ident == "AND" return _sql_tok("AND", ident, start_line, start_col) @end
    @if upper_ident == "OR" return _sql_tok("OR", ident, start_line, start_col) @end
    @if upper_ident == "NOT" return _sql_tok("NOT", ident, start_line, start_col) @end

    return _sql_tok("IDENT", ident, start_line, start_col)
  @end

  @! Numbers (integers & IEEE-754 decimal floats)
  @if string_is_digit(c)
    num_str = c
    seen_dot = 0
    @while 1
      nc = lexer_peek_char(lex)
      @if string_is_digit(nc)
        num_str = num_str + lexer_advance(lex)
      @elif nc == "." && seen_dot == 0 && string_is_digit(lexer_peek_at(lex, 1))
        seen_dot = 1
        num_str = num_str + lexer_advance(lex)
      @else
        break
      @end
    @end
    return _sql_tok("NUMBER", num_str, start_line, start_col)
  @end

  @! String literals with backslash escapes and SQL doubled quotes ('')
  @if c == "'" || c == "\""
    quote = c
    str_val = ""
    @while 1
      nc = lexer_peek_char(lex)
      @if nc == "\0"
        break
      @end
      @if nc == "\\"
        lexer_advance(lex)
        esc = lexer_advance(lex)
        @if esc == "n"
          str_val = str_val + "\n"
        @elif esc == "t"
          str_val = str_val + "\t"
        @elif esc == "r"
          str_val = str_val + "\r"
        @elif esc != "\0"
          str_val = str_val + esc
        @end
      @elif nc == quote
        lexer_advance(lex)
        @if lexer_peek_char(lex) == quote
          lexer_advance(lex)
          str_val = str_val + quote
        @else
          break
        @end
      @else
        str_val = str_val + lexer_advance(lex)
      @end
    @end
    return _sql_tok("STRING", str_val, start_line, start_col)
  @end

  @! Punctuation & Operators
  @if c == "(" return _sql_tok("LPAREN", "(", start_line, start_col) @end
  @if c == ")" return _sql_tok("RPAREN", ")", start_line, start_col) @end
  @if c == "," return _sql_tok("COMMA", ",", start_line, start_col) @end
  @if c == ";" return _sql_tok("SEMICOLON", ";", start_line, start_col) @end
  @if c == "=" return _sql_tok("EQ", "=", start_line, start_col) @end
  @if c == "!"
    @if lexer_peek_char(lex) == "="
      lexer_advance(lex)
      return _sql_tok("NEQ", "!=", start_line, start_col)
    @end
    return _sql_tok("CHAR", "!", start_line, start_col)
  @end
  @if c == "*" return _sql_tok("STAR", "*", start_line, start_col) @end
  @if c == ">"
    @if lexer_peek_char(lex) == "="
      lexer_advance(lex)
      return _sql_tok("GTE", ">=", start_line, start_col)
    @end
    return _sql_tok("GT", ">", start_line, start_col)
  @end
  @if c == "<"
    @if lexer_peek_char(lex) == "="
      lexer_advance(lex)
      return _sql_tok("LTE", "<=", start_line, start_col)
    @elif lexer_peek_char(lex) == ">"
      lexer_advance(lex)
      return _sql_tok("NEQ", "<>", start_line, start_col)
    @end
    return _sql_tok("LT", "<", start_line, start_col)
  @end

  return _sql_tok("CHAR", c, start_line, start_col)
@end
