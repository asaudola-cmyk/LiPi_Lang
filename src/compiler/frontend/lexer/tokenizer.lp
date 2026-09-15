// ============================================================================
// LIPI FRONTEND COMPILER — MASTER BILINGUAL LEXER & TOKENIZER
// Module: src/compiler/frontend/lexer/tokenizer.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Unifies all frontend lexical micro-components (char_stream, unicode_bengali,
//    token_kind, token, num_literal, str_literal, comment_doc) into a singular,
//    deterministic scanner engine.
// 2. Bilingual Token Invariant: Bengali source code (`যদি`, `কাজ`, `গঠন`, `ফেরত`)
//    and English source code (`if`, `fn`, `struct`, `return`) produce 100% identical
//    TokenKind integer streams, enabling cross-language AST equivalence with zero overhead.
// 3. High-precision 2D source span calculation provides 100% accurate file, line,
//    column, and offset coordinates for error reporting and IDE diagnostics.
// 4. Zero-Collision Architecture: Respects compiler field offset semantics by using
//    namespaced field accessors across all constituent sub-models.
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

// ── 1. Bilingual Keyword Resolver ─────────────────────────────────────────────

@fn lexer_lookup_keyword(text: string)
  // WHY: Maps both English and Bengali keyword representations to identical canonical TokenKinds.
  // Guarantees zero linguistic bias and ensures seamless bilingual compilation.

  // 1. Functions & Definitions
  @if text == "fn" || text == "কাজ" || text == "ফাংশন" return TOK_KW_FN() @end
  @if text == "struct" || text == "গঠন" || text == "কাঠামো" return TOK_KW_STRUCT() @end
  @if text == "impl" return TOK_KW_IMPL() @end
  @if text == "enum" return TOK_KW_ENUM() @end

  // 2. Variable Declarations & Mutability
  @if text == "let" || text == "var" || text == "ধরি" || text == "চলক" return TOK_KW_LET() @end
  @if text == "mut" return TOK_KW_MUT() @end
  @if text == "const" || text == "ধ্রুবক" return TOK_KW_CONST() @end

  // 3. Conditionals & Branching
  @if text == "if" || text == "যদি" return TOK_KW_IF() @end
  @if text == "elif" || text == "নাহলে_যদি" || text == "নতুবা_যদি" return TOK_KW_ELIF() @end
  @if text == "else" || text == "নাহলে" || text == "অন্যথায়" return TOK_KW_ELSE() @end

  // 4. Loops & Iteration
  @if text == "while" || text == "যতক্ষণ" return TOK_KW_WHILE() @end
  @if text == "for" || text == "প্রতিটি" || text == "জন্য" return TOK_KW_FOR() @end
  @if text == "in" || text == "মধ্যে" return TOK_KW_IN() @end

  // 5. Control Flow & Exit
  @if text == "return" || text == "ফেরত" return TOK_KW_RETURN() @end
  @if text == "break" || text == "থামো" return TOK_KW_BREAK() @end
  @if text == "continue" || text == "চলো" return TOK_KW_CONTINUE() @end
  @if text == "end" || text == "শেষ" return TOK_KW_END() @end

  // 6. Pattern Matching
  @if text == "match" || text == "মেলাও" || text == "মিল" return TOK_KW_MATCH() @end
  @if text == "case" || text == "ক্ষেত্র" return TOK_KW_CASE() @end

  // 7. Modularity & Imports
  @if text == "import" || text == "অন্তর্ভুক্ত" return TOK_KW_IMPORT() @end

  // 8. Error Handling & Deferral
  @if text == "try" return TOK_KW_TRY() @end
  @if text == "catch" return TOK_KW_CATCH() @end
  @if text == "defer" return TOK_KW_DEFER() @end

  // 9. Concurrency & Async
  @if text == "async" return TOK_KW_ASYNC() @end
  @if text == "await" || text == "অপেক্ষা" return TOK_KW_AWAIT() @end

  // 10. Types & IO
  @if text == "type" || text == "ধরন" return TOK_KW_TYPE() @end
  @if text == "print" || text == "println" || text == "দেখাও" return TOK_KW_PRINT() @end
  @if text == "syscall" || text == "সিসকল" return TOK_KW_SYSCALL() @end

  // Not a reserved keyword
  return -1
@end

// ── 2. Directive Resolver (@...) ──────────────────────────────────────────────

@fn lexer_lookup_directive(dir_name: string)
  // WHY: Maps @-prefixed compiler directives to their respective TokenKinds
  @if dir_name == "@fn" return TOK_DIR_FN() @end
  @if dir_name == "@struct" return TOK_DIR_STRUCT() @end
  @if dir_name == "@impl" return TOK_DIR_IMPL() @end
  @if dir_name == "@enum" return TOK_DIR_ENUM() @end
  @if dir_name == "@while" return TOK_DIR_WHILE() @end
  @if dir_name == "@for" return TOK_DIR_FOR() @end
  @if dir_name == "@if" return TOK_DIR_IF() @end
  @if dir_name == "@elif" return TOK_DIR_ELIF() @end
  @if dir_name == "@else" return TOK_DIR_ELSE() @end
  @if dir_name == "@return" return TOK_DIR_RETURN() @end
  @if dir_name == "@match" return TOK_DIR_MATCH() @end
  @if dir_name == "@break" return TOK_DIR_BREAK() @end
  @if dir_name == "@continue" return TOK_DIR_CONTINUE() @end
  @if dir_name == "@try" return TOK_DIR_TRY() @end
  @if dir_name == "@catch" return TOK_DIR_CATCH() @end
  @if dir_name == "@defer" return TOK_DIR_DEFER() @end
  @if dir_name == "@type" return TOK_DIR_TYPE() @end
  @if dir_name == "@trait" return TOK_DIR_TRAIT() @end
  @if dir_name == "@actor" return TOK_DIR_ACTOR() @end
  @if dir_name == "@supervisor" return TOK_DIR_SUPERVISOR() @end
  @if dir_name == "@spawn" return TOK_DIR_SPAWN() @end
  @if dir_name == "@effect" return TOK_DIR_EFFECT() @end
  @if dir_name == "@end" return TOK_DIR_END() @end
  return -1
@end

// ── 3. Master Tokenizer Engine ────────────────────────────────────────────────

@fn tokenize_source(source: string)
  // WHY: Convenience entry point for compiling a raw source string
  return lexer_tokenize(source, "")
@end

@fn lexer_tokenize(source: string, filename: string)
  // WHY: Main scanner loop converting source text into a sequential array of Tokens
  tokens = []
  stream = char_stream_new(source)
  num_items = stream.cs_len

  @while char_stream_is_eof(stream) == 0
    start_pos = stream.cs_pos
    start_line = stream.cs_line
    start_col = stream.cs_col
    b = char_stream_peek_byte(stream)

    // ── 1. Whitespace (Space, Tab, Carriage Return) ──
    @if b == 32 || b == 9 || b == 13
      char_stream_advance_byte(stream)

    // ── 2. Newline (LF) ──
    @elif b == 10
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, start_line, start_col, stream.cs_pos)
      tok = token_new(TOK_NEWLINE(), "NEWLINE", "\n", 0, 0.0, span)
      tokens = tokens.push(tok)

    // ── 3. Comments (Line //, ///, @!, and Block /*, /**) ──
    @elif (b == 47 && char_stream_peek_byte_ahead(stream, 1) == 47) || (b == 64 && char_stream_peek_byte_ahead(stream, 1) == 33)
      comm_res = comment_parse_line(source, start_pos)
      @if comm_res.comm_is_doc == 1
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, start_col + comm_res.comm_consumed, start_pos + comm_res.comm_consumed)
        tok = token_new(TOK_COMMENT_DOC(), "COMMENT_DOC", comm_res.comm_content, 0, 0.0, span)
        tokens = tokens.push(tok)
      @end
      stream.cs_pos = stream.cs_pos + comm_res.comm_consumed
      stream.cs_col = stream.cs_col + comm_res.comm_consumed

    @elif b == 47 && char_stream_peek_byte_ahead(stream, 1) == 42 // '/*'
      comm_res = comment_parse_block(source, start_pos)
      @if comm_res.comm_is_doc == 1
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line + comm_res.comm_lines_consumed, stream.cs_col, start_pos + comm_res.comm_consumed)
        tok = token_new(TOK_COMMENT_DOC(), "COMMENT_DOC", comm_res.comm_content, 0, 0.0, span)
        tokens = tokens.push(tok)
      @end
      stream.cs_pos = stream.cs_pos + comm_res.comm_consumed
      stream.cs_line = stream.cs_line + comm_res.comm_lines_consumed
      @if comm_res.comm_lines_consumed > 0
        stream.cs_col = 1
      @else
        stream.cs_col = stream.cs_col + comm_res.comm_consumed
      @end

    // ── 4. Numeric Literals (Western 0..9 and Bengali ০..৯) ──
    @elif (b >= 48 && b <= 57) || (b == 224 && num_is_bengali_digit_at(source, start_pos, num_items) == 1)
      num_res = num_parse_literal(source, start_pos)
      @if num_res.num_is_valid == 1
        stream.cs_pos = stream.cs_pos + num_res.num_consumed
        stream.cs_col = stream.cs_col + num_res.num_consumed
        span = source_span_new(filename, start_line, start_col, start_pos, start_line, stream.cs_col, stream.cs_pos)
        kind = TOK_INT()
        kind_name = "INT"
        @if num_res.num_is_float == 1
          kind = TOK_FLOAT()
          kind_name = "FLOAT"
        @end
        tok = token_new(kind, kind_name, num_res.num_text, num_res.num_int_val, num_res.num_float_val, span)
        tokens = tokens.push(tok)
      @else
        char_stream_advance_byte(stream)
      @end

    // ── 5. String Literals ("..." and '...') ──
    @elif b == 34 || b == 39 // '"' or '\''
      str_res = str_decode_literal(source, start_pos, start_col)
      @if str_res.str_consumed > 0
        stream.cs_pos = stream.cs_pos + str_res.str_consumed
        stream.cs_line = stream.cs_line + str_res.str_lines_consumed
        stream.cs_col = str_res.str_end_col
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        kind = TOK_STR()
        kind_name = "STR"
        @if str_res.str_has_interp == 1
          kind = TOK_INTERP_STR()
          kind_name = "INTERP_STR"
        @end
        tok = token_new(kind, kind_name, str_res.str_decoded_text, 0, 0.0, span)
        tokens = tokens.push(tok)
      @else
        // Guard against zero advancement
        char_stream_advance_byte(stream)
      @end

    // ── 6. Directives (@fn, @struct, etc.) ──
    @elif b == 64 // '@'
      dir_name = "@"
      char_stream_advance_byte(stream)
      dir_cont = 1
      @while char_stream_is_eof(stream) == 0 && dir_cont == 1
        cur = char_stream_peek_byte(stream)
        @if (cur >= 65 && cur <= 90) || (cur >= 97 && cur <= 122) || (cur >= 48 && cur <= 57) || cur == 95
          dir_name = dir_name + chr(cur)
          char_stream_advance_byte(stream)
        @else
          dir_cont = 0
        @end
      @end
      dir_kind = lexer_lookup_directive(dir_name)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      @if dir_kind >= 0
        tok = token_new(dir_kind, token_kind_name(dir_kind), dir_name, 0, 0.0, span)
        tokens = tokens.push(tok)
      @else
        tok = token_new(TOK_IDENT(), "IDENT", dir_name, 0, 0.0, span)
        tokens = tokens.push(tok)
      @end

    // ── 7. Multi-Byte & Single-Byte Operators / Symbols ──
    @elif b == 43 // '+'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '+='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_PLUSEQ(), "PLUSEQ", "+=", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_PLUS(), "PLUS", "+", 0, 0.0, span))
      @end

    @elif b == 45 // '-'
      @if char_stream_peek_byte_ahead(stream, 1) == 62 // '->'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_ARROW(), "ARROW", "->", 0, 0.0, span))
      @elif char_stream_peek_byte_ahead(stream, 1) == 61 // '-='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_MINUSEQ(), "MINUSEQ", "-=", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_MINUS(), "MINUS", "-", 0, 0.0, span))
      @end

    @elif b == 42 // '*'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '*='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_STAREQ(), "STAREQ", "*=", 0, 0.0, span))
      @elif char_stream_peek_byte_ahead(stream, 1) == 42 // '**'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_STARSTAR(), "STARSTAR", "**", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_STAR(), "STAR", "*", 0, 0.0, span))
      @end

    @elif b == 47 // '/'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '/='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_SLASHEQ(), "SLASHEQ", "/=", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_SLASH(), "SLASH", "/", 0, 0.0, span))
      @end

    @elif b == 37 // '%'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '%='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_PERCENTEQ(), "PERCENTEQ", "%=", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_PERCENT(), "PERCENT", "%", 0, 0.0, span))
      @end

    @elif b == 61 // '='
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '=='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_EQ(), "EQ", "==", 0, 0.0, span))
      @elif char_stream_peek_byte_ahead(stream, 1) == 62 // '=>'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_FAT_ARROW(), "FAT_ARROW", "=>", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_ASSIGN(), "ASSIGN", "=", 0, 0.0, span))
      @end

    @elif b == 33 // '!'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '!='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_NEQ(), "NEQ", "!=", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_BANG(), "BANG", "!", 0, 0.0, span))
      @end

    @elif b == 60 // '<'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '<='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_LTE(), "LTE", "<=", 0, 0.0, span))
      @elif char_stream_peek_byte_ahead(stream, 1) == 60 // '<<'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_SHL(), "SHL", "<<", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_LT(), "LT", "<", 0, 0.0, span))
      @end

    @elif b == 62 // '>'
      @if char_stream_peek_byte_ahead(stream, 1) == 61 // '>='
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_GTE(), "GTE", ">=", 0, 0.0, span))
      @elif char_stream_peek_byte_ahead(stream, 1) == 62 // '>>'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_SHR(), "SHR", ">>", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_GT(), "GT", ">", 0, 0.0, span))
      @end

    @elif b == 38 // '&'
      @if char_stream_peek_byte_ahead(stream, 1) == 38 // '&&'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_AND(), "AND", "&&", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_AMP(), "AMP", "&", 0, 0.0, span))
      @end

    @elif b == 124 // '|'
      @if char_stream_peek_byte_ahead(stream, 1) == 124 // '||'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_OR(), "OR", "||", 0, 0.0, span))
      @elif char_stream_peek_byte_ahead(stream, 1) == 62 // '|>'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_PIPE(), "PIPE", "|>", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_BAR(), "BAR", "|", 0, 0.0, span))
      @end

    @elif b == 94 // '^'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_CARET(), "CARET", "^", 0, 0.0, span))

    @elif b == 126 // '~'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_TILDE(), "TILDE", "~", 0, 0.0, span))

    @elif b == 63 // '?'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_QUERY(), "QUERY", "?", 0, 0.0, span))

    @elif b == 40 // '('
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_LPAREN(), "LPAREN", "(", 0, 0.0, span))

    @elif b == 41 // ')'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_RPAREN(), "RPAREN", ")", 0, 0.0, span))

    @elif b == 91 // '['
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_LBRACKET(), "LBRACKET", "[", 0, 0.0, span))

    @elif b == 93 // ']'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_RBRACKET(), "RBRACKET", "]", 0, 0.0, span))

    @elif b == 123 // '{'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_LBRACE(), "LBRACE", "{", 0, 0.0, span))

    @elif b == 125 // '}'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_RBRACE(), "RBRACE", "}", 0, 0.0, span))

    @elif b == 44 // ','
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_COMMA(), "COMMA", ",", 0, 0.0, span))

    @elif b == 58 // ':'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_COLON(), "COLON", ":", 0, 0.0, span))

    @elif b == 59 // ';'
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_SEMI(), "SEMI", ";", 0, 0.0, span))

    @elif b == 46 // '.'
      @if char_stream_peek_byte_ahead(stream, 1) == 46 // '..'
        char_stream_advance_byte(stream)
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_DOTDOT(), "DOTDOT", "..", 0, 0.0, span))
      @else
        char_stream_advance_byte(stream)
        span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
        tokens = tokens.push(token_new(TOK_DOT(), "DOT", ".", 0, 0.0, span))
      @end

    // ── 8. Bengali Dari '।' (U+0964 -> 0xE0, 0xA5, 0xA4 = 224, 165, 164) ──
    @elif b == 224 && char_stream_peek_byte_ahead(stream, 1) == 165 && char_stream_peek_byte_ahead(stream, 2) == 164
      char_stream_advance_byte(stream)
      char_stream_advance_byte(stream)
      char_stream_advance_byte(stream)
      span = source_span_new(filename, start_line, start_col, start_pos, stream.cs_line, stream.cs_col, stream.cs_pos)
      tokens = tokens.push(token_new(TOK_DARI(), "DARI", "।", 0, 0.0, span))

    // ── 9. Identifiers & Bilingual Keywords (Bengali runes & ASCII) ──
    @else
      rune = char_stream_peek_rune(stream)
      @if is_bengali_ident_start(rune) == 1
        ident_start = stream.cs_pos
        ident_start_col = stream.cs_col
        char_stream_advance_rune(stream)

        ident_cont = 1
        @while char_stream_is_eof(stream) == 0 && ident_cont == 1
          next_rune = char_stream_peek_rune(stream)
          @if is_bengali_ident_continue(next_rune) == 1
            char_stream_advance_rune(stream)
          @else
            ident_cont = 0
          @end
        @end

        ident_text = char_stream_slice(stream, ident_start, stream.cs_pos)
        span = source_span_new(filename, start_line, ident_start_col, ident_start, stream.cs_line, stream.cs_col, stream.cs_pos)

        // Boolean & Null literals
        @if ident_text == "true" || ident_text == "সত্য"
          tokens = tokens.push(token_new(TOK_BOOL(), "BOOL", ident_text, 1, 0.0, span))
        @elif ident_text == "false" || ident_text == "মিথ্যা"
          tokens = tokens.push(token_new(TOK_BOOL(), "BOOL", ident_text, 0, 0.0, span))
        @elif ident_text == "none" || ident_text == "nil" || ident_text == "null" || ident_text == "শূন্য"
          tokens = tokens.push(token_new(TOK_NONE(), "NONE", ident_text, 0, 0.0, span))
        @else
          // Keyword or generic Identifier
          kw_kind = lexer_lookup_keyword(ident_text)
          @if kw_kind >= 0
            tokens = tokens.push(token_new(kw_kind, token_kind_name(kw_kind), ident_text, 0, 0.0, span))
          @else
            tokens = tokens.push(token_new(TOK_IDENT(), "IDENT", ident_text, 0, 0.0, span))
          @end
        @end

      // Fallback: unrecognized character
      @else
        char_stream_advance_byte(stream)
      @end
    @end
  @end

  // Emits terminal EOF token
  eof_span = source_span_point(filename, stream.cs_line, stream.cs_col, stream.cs_pos)
  tokens = tokens.push(token_new(TOK_EOF(), "EOF", "", 0, 0.0, eof_span))
  return tokens
@end
