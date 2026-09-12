@! ============================================================================
@! LIPI UNIVERSE DB - SQL LEXER (universe/db/sql/lexer.lp)
@! Standard: 100% Pure Maya SQL Tokenizer
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@struct Token
  kind: string
  value: string
  line: i64
  col: i64
@end

@struct Lexer
  input: string
  pos: i64
  num_items: i64
  line: i64
  col: i64
@end

@fn lexer_new(input)
  return { input: input, pos: 0, num_items: str_len(input), line: 1, col: 1 }
@end

@fn lexer_peek_char(lex)
  @if lex.pos >= lex.num_items
    return "\0"
  @end
  return str_substr(lex.input, lex.pos, lex.pos + 1)
@end

@fn lexer_advance(lex)
  c = lexer_peek_char(lex)
  lex.pos = lex.pos + 1
  @if c == "\n"
    lex.line = lex.line + 1
    lex.col = 1
  @else
    lex.col = lex.col + 1
  @end
  return c
@end

@fn lexer_skip_whitespace(lex)
  @while 1
    c = lexer_peek_char(lex)
    @if c == " " || c == "\t" || c == "\n" || c == "\r"
      lexer_advance(lex)
    @else
      break
    @end
  @end
@end

@fn lexer_next_token(lex)
  lexer_skip_whitespace(lex)
  @if lex.pos >= lex.num_items
    return { kind: "EOF", value: "", line: lex.line, col: lex.col }
  @end
  
  start_col = lex.col
  start_line = lex.line
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
    @if upper_ident == "SELECT" return { kind: "SELECT", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "FROM" return { kind: "FROM", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "WHERE" return { kind: "WHERE", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "INSERT" return { kind: "INSERT", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "INTO" return { kind: "INTO", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "VALUES" return { kind: "VALUES", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "UPDATE" return { kind: "UPDATE", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "SET" return { kind: "SET", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "DELETE" return { kind: "DELETE", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "CREATE" return { kind: "CREATE", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "TABLE" return { kind: "TABLE", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "DROP" return { kind: "DROP", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "JOIN" return { kind: "JOIN", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "GROUP" return { kind: "GROUP", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "BY" return { kind: "BY", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "ORDER" return { kind: "ORDER", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "LIMIT" return { kind: "LIMIT", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "AND" return { kind: "AND", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "OR" return { kind: "OR", value: ident, line: start_line, col: start_col } @end
    @if upper_ident == "NOT" return { kind: "NOT", value: ident, line: start_line, col: start_col } @end
    
    return { kind: "IDENT", value: ident, line: start_line, col: start_col }
  @end
  
  @! Numbers
  @if string_is_digit(c)
    num_str = c
    @while 1
      nc = lexer_peek_char(lex)
      @if string_is_digit(nc)
        num_str = num_str + lexer_advance(lex)
      @else
        break
      @end
    @end
    return { kind: "NUMBER", value: num_str, line: start_line, col: start_col }
  @end
  
  @! String literals
  @if c == "'" || c == "\""
    quote = c
    str_val = ""
    @while 1
      nc = lexer_peek_char(lex)
      @if nc == "\0" || nc == quote
        break
      @end
      str_val = str_val + lexer_advance(lex)
    @end
    @if lexer_peek_char(lex) == quote
      lexer_advance(lex)
    @end
    return { kind: "STRING", value: str_val, line: start_line, col: start_col }
  @end
  
  @! Punctuation & Operators
  @if c == "(" return { kind: "LPAREN", value: "(", line: start_line, col: start_col } @end
  @if c == ")" return { kind: "RPAREN", value: ")", line: start_line, col: start_col } @end
  @if c == "," return { kind: "COMMA", value: ",", line: start_line, col: start_col } @end
  @if c == ";" return { kind: "SEMICOLON", value: ";", line: start_line, col: start_col } @end
  @if c == "=" return { kind: "EQ", value: "=", line: start_line, col: start_col } @end
  @if c == "*" return { kind: "STAR", value: "*", line: start_line, col: start_col } @end
  @if c == ">"
    @if lexer_peek_char(lex) == "="
      lexer_advance(lex)
      return { kind: "GTE", value: ">=", line: start_line, col: start_col }
    @end
    return { kind: "GT", value: ">", line: start_line, col: start_col }
  @end
  @if c == "<"
    @if lexer_peek_char(lex) == "="
      lexer_advance(lex)
      return { kind: "LTE", value: "<=", line: start_line, col: start_col }
    @end
    return { kind: "LT", value: "<", line: start_line, col: start_col }
  @end
  
  return { kind: "CHAR", value: c, line: start_line, col: start_col }
@end
