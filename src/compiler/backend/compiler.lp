
import "compiler/infinity_syntax"
import "compiler/backend/lipi_ir"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/elf_writer"
import "compiler/backend/omni_binary"

@fn lex_is_space(c)
  // WHY: Returns 1 if character is ASCII space, tab, or carriage return
  @if c == 32 || c == 9 || c == 13 return 1 @end
  return 0
@end

@fn lex_is_newline(c)
  // WHY: Returns 1 if character is ASCII newline (LF)
  @if c == 10 return 1 @end
  return 0
@end

@fn lex_is_digit(c)
  // WHY: Returns 1 if character is ASCII decimal digit '0'..'9'
  @if c >= 48 && c <= 57 return 1 @end
  return 0
@end

@fn lex_is_alpha(c)
  // WHY: Returns 1 if character is ASCII alphabetic ('a'..'z', 'A'..'Z') or underscore '_'
  @if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 return 1 @end
  return 0
@end

@fn ast_node(kind)
  // WHY: Construct uniform ASTNode with default fields for compiler AST representation
  return {
    kind: kind,
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn is_elif_tok_safe(tokens, p)
  @if p >= tokens.len() return 0 @end
  return is_elif_tok(tokens[p])
@end


@fn is_else_tok_safe(tokens, p)
  @if p >= tokens.len() return 0 @end
  return is_else_tok(tokens[p])
@end


@fn is_end_tok_safe(tokens, p)
  @if p >= tokens.len() return 0 @end
  return is_end_tok(tokens[p])
@end


@fn get_tok_kind(tokens, p)
  @if p >= tokens.len() return "EOF" @end
  t = tokens[p]
  return t[0]
@end

@fn get_tok_name(tokens, p)
  @if p >= tokens.len() return "EOF" @end
  t = tokens[p]
  return t[1]
@end

@! Module: compiler/backend/compiler.maya
@! Architecture: 100% Pure Maya Self-Contained Native Compiler Pipeline
@! Standard: Zero Foreign Dependencies (No gcc, clang, ld, or external tools)
@! ============================================================================


@! ============================================================================
@! 1. COMPILER SYSTEM CALLS & MEMORY HELPERS
@! ============================================================================

@fn sys_open(path, flags, mode)
  return syscall(2, path, flags, mode, 0, 0, 0)
@end

@fn sys_write(fd, buf, count)
  return syscall(1, fd, buf, count, 0, 0, 0)
@end

@fn sys_close(fd)
  return syscall(3, fd, 0, 0, 0, 0, 0)
@end

@fn sys_chmod(path, mode)
  return syscall(90, path, mode, 0, 0, 0, 0)
@end

@fn file_write(path, content)
  fd = syscall(2, path, 577, 493, 0, 0, 0)
  @if fd < 0 return 0 @end
  sz = str_len(content)
  @if sz > 0
    syscall(1, fd, content, sz, 0, 0, 0)
  @end
  syscall(3, fd, 0, 0, 0, 0, 0)
  return 1
@end

@fn file_read(path)
  @! Direct raw Linux syscalls for reading file into memory buffer
  @! sys_open (2) O_RDONLY (0)
  fd = syscall(2, path, 0, 0, 0, 0, 0)
  @if fd < 0 return "" @end
  
  @! sys_lseek (8) to SEEK_END (2)
  size = syscall(8, fd, 0, 2, 0, 0, 0)
  @! sys_lseek (8) to SEEK_SET (0)
  syscall(8, fd, 0, 0, 0, 0, 0)
  
  @if size <= 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return ""
  @end
  
  @! sys_mmap (9) allocator
  buf = syscall(9, 0, size + 1, 3, 34, 0 - 1, 0)
  @if buf <= 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return ""
  @end
  
  read_bytes = syscall(0, fd, buf, size, 0, 0, 0)
  syscall(3, fd, 0, 0, 0, 0, 0)
  @if read_bytes <= 0 return "" @end
  maya_mem_write_u8(buf + read_bytes, 0)
  return buf
@end

@fn maya_gc_alloc(size)
  return syscall(9, 0, size, 3, 34, 0 - 1, 0)
@end

@fn gc_alloc(size)
  return syscall(9, 0, size, 3, 34, 0 - 1, 0)
@end

@fn maya_alloc(size)
  return syscall(9, 0, size, 3, 34, 0 - 1, 0)
@end

@fn compiler_get_char(s, k)
  // WHY: Bound-checked character retrieval using native str_char_at avoiding pointer dynamic concat
  @if s == "" || k < 0
    return 0
  @end
  @if k >= str_len(s)
    return 0
  @end
  return str_char_at(s, k)
@end

@fn compiler_str_eq(s1, s2)
  // WHY: Native string equality check leveraging zero-overhead CPU string compare (lipi_fn_str_eq)
  return str_eq(s1, s2)
@end

@fn str_substr(s, start, end_pos)
  return string_slice(s, start, end_pos)
@end

@fn make_token(kind, name, line, col)
  return [kind, name, int_to_str(line), int_to_str(col)]
@end

@fn tok_kind(t)
  @if t.len() == 0 return "EOF" @end
  return t[0]
@end

@fn tok_name(t)
  @if t.len() < 2 return "" @end
  return t[1]
@end

@fn is_end_tok(t)
  @if t.len() == 0 return 0 @end
  k = tok_kind(t)
  n = tok_name(t)
  return compiler_str_eq(k, "END") == 1 || compiler_str_eq(n, "end") == 1 || compiler_str_eq(n, "@end") == 1 || (compiler_str_eq(k, "DIRECTIVE") == 1 && compiler_str_eq(n, "@end") == 1)
@end

@fn is_else_tok(t)
  @if t.len() == 0 return 0 @end
  k = tok_kind(t)
  n = tok_name(t)
  return compiler_str_eq(k, "ELSE") == 1 || compiler_str_eq(n, "else") == 1 || compiler_str_eq(n, "@else") == 1 || (compiler_str_eq(k, "DIRECTIVE") == 1 && compiler_str_eq(n, "@else") == 1)
@end

@fn is_elif_tok(t)
  @if t.len() == 0 return 0 @end
  k = tok_kind(t)
  n = tok_name(t)
  return compiler_str_eq(k, "ELIF") == 1 || compiler_str_eq(n, "elif") == 1 || compiler_str_eq(n, "@elif") == 1 || (compiler_str_eq(k, "DIRECTIVE") == 1 && compiler_str_eq(n, "@elif") == 1)
@end

@struct CompilerOptions
  opt_dump_tokens: i64
  opt_dump_ast: i64
  opt_dump_ir: i64
  opt_dump_asm: i64
  opt_module_name: string
  opt_opt_level: i64
  opt_base_dir: string
@end

@struct TokenizerContext
  tokens: array
  source: string
  pos: i64
  line: i64
  col: i64
  num_items: i64
@end

@struct ParseResult
  parse_node: map
  parse_next: i64
@end

@struct ParseProgramResult
  ast_statements: array
  ast_tokens: array
  inf_engine: map
@end

@struct ExpandImportsResult
  ast: array
  visited: array
@end

@struct CompilerResult
  cr_success: i64
  cr_out_path: string
  cr_file_size: i64
  cr_entry_vaddr: i64
  cr_tokens_count: i64
  cr_ast_count: i64
  cr_ir_funcs: i64
  cr_error_msg: string
@end

@fn is_alpha_char(c)
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
@end

@fn is_digit_char(c)
  return c >= 48 && c <= 57
@end

@fn is_alphanumeric_char(c)
  return is_alpha_char(c) || is_digit_char(c)
@end

@fn is_whitespace_char(c)
  return c == 32 || c == 9 || c == 13 || c == 10
@end

@! ============================================================================
@! 2. PURE MAYA LEXICAL ANALYZER / TOKENIZER
@! ============================================================================

@fn parse_int_val(s)
  res = 0
  sign = 1
  k = 0
  s_bytes = []
  c = str_char_at(s, k)
  @while c != 0
    s_bytes = s_bytes.push(c)
    k = k + 1
    c = str_char_at(s, k)
  @end
  num_items = s_bytes.len()
  @if num_items == 0 return 0 @end
  k = 0
  @if s_bytes[0] == 45 @! '-'
    sign = 0 - 1
    k = 1
  @elif s_bytes[0] == 43 @! '+'
    k = 1
  @end
  @if k + 1 < num_items && s_bytes[k] == 48 && (s_bytes[k + 1] == 120 || s_bytes[k + 1] == 88) @! 0x Hexadecimal
    k = k + 2
    @while k < num_items
      c = s_bytes[k]
      digit = 0
      @if c >= 48 && c <= 57 digit = c - 48
      @elif c >= 97 && c <= 102 digit = c - 97 + 10
      @elif c >= 65 && c <= 70 digit = c - 65 + 10 @end
      res = res * 16 + digit
      k = k + 1
    @end
    return res * sign
  @elif k + 1 < num_items && s_bytes[k] == 48 && (s_bytes[k + 1] == 98 || s_bytes[k + 1] == 66) @! 0b Binary
    k = k + 2
    @while k < num_items
      c = s_bytes[k]
      digit = 0
      @if c == 49 digit = 1 @end
      res = res * 2 + digit
      k = k + 1
    @end
    return res * sign
  @end
  @while k < num_items
    c = s_bytes[k]
    @if c >= 48 && c <= 57
      res = res * 10 + (c - 48)
    @end
    k = k + 1
  @end
  return res * sign
@end

@fn parse_float_val(s)
  return 0
@end

@fn lex_tokenize(source)
  tokens = []
  src_bytes = []
  s_k = 0
  c = str_char_at(source, s_k)
  @while c != 0
    src_bytes = src_bytes.push(c)
    s_k = s_k + 1
    c = str_char_at(source, s_k)
  @end
  num_items = src_bytes.len()
  i = 0
  line = 1
  col = 1

  @while i < num_items
    c = src_bytes[i]

    @if lex_is_space(c)
      i = i + 1
      col = col + 1
    @elif c == 10 @! newline
      tokens = tokens.push(make_token("NEWLINE", "\n", line, col))
      i = i + 1
      line = line + 1
      col = 1
    @elif c == 47 && i + 1 < num_items && src_bytes[i + 1] == 47 @! // Single-line comment
      @while i < num_items && src_bytes[i] != 10
        i = i + 1
      @end
    @elif c == 64 && i + 1 < num_items && src_bytes[i + 1] == 33 @! @! Maya Directive comment
      @while i < num_items && src_bytes[i] != 10
        i = i + 1
      @end
    @elif c == 47 && i + 1 < num_items && src_bytes[i + 1] == 42 @! /* Block comment */
      i = i + 2
      col = col + 2
      @while i + 1 < num_items && src_bytes[i] != 42 || src_bytes[i + 1] != 47
        @if src_bytes[i] == 10
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
    @elif c == 64 @! @directive
      start_col = col
      d_str = "@"
      i = i + 1
      col = col + 1
      @while i < num_items && (lex_is_alpha(src_bytes[i]) || lex_is_digit(src_bytes[i]))
        d_str = str_concat(d_str, str_from_char_code(src_bytes[i]))
        i = i + 1
        col = col + 1
      @end
      tokens = tokens.push(make_token("DIRECTIVE", d_str, line, start_col))
    @elif lex_is_alpha(c)
      start_col = col
      id_str = ""
      @while i < num_items && (lex_is_alpha(src_bytes[i]) || lex_is_digit(src_bytes[i]))
        id_str = str_concat(id_str, str_from_char_code(src_bytes[i]))
        i = i + 1
        col = col + 1
      @end

      @if compiler_str_eq(id_str, "fn") == 1
        tokens = tokens.push(make_token("FN", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "return") == 1
        tokens = tokens.push(make_token("RETURN", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "if") == 1
        tokens = tokens.push(make_token("IF", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "elif") == 1
        tokens = tokens.push(make_token("ELIF", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "else") == 1
        tokens = tokens.push(make_token("ELSE", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "while") == 1
        tokens = tokens.push(make_token("WHILE", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "for") == 1
        tokens = tokens.push(make_token("FOR", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "in") == 1
        tokens = tokens.push(make_token("IN", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "break") == 1
        tokens = tokens.push(make_token("BREAK", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "continue") == 1
        tokens = tokens.push(make_token("CONTINUE", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "let") == 1 || compiler_str_eq(id_str, "var") == 1
        tokens = tokens.push(make_token("LET", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "end") == 1
        tokens = tokens.push(make_token("END", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "true") == 1 || compiler_str_eq(id_str, "false") == 1
        tokens = tokens.push(make_token("BOOL", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "none") == 1 || compiler_str_eq(id_str, "nil") == 1
        tokens = tokens.push(make_token("NONE", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "import") == 1
        tokens = tokens.push(make_token("IMPORT", id_str, line, start_col))
      @elif compiler_str_eq(id_str, "struct") == 1 || compiler_str_eq(id_str, "type") == 1
        tokens = tokens.push(make_token("STRUCT", id_str, line, start_col))
      @else
        tokens = tokens.push(make_token("IDENT", id_str, line, start_col))
      @end
    @elif lex_is_digit(c)
      start_col = col
      num_str = ""
      @if c == 48 && i + 1 < num_items && (src_bytes[i + 1] == 120 || src_bytes[i + 1] == 88) @! 0x
        num_str = "0x"
        i = i + 2
        col = col + 2
        @while i < num_items && (lex_is_digit(src_bytes[i]) || (src_bytes[i] >= 97 && src_bytes[i] <= 102) || (src_bytes[i] >= 65 && src_bytes[i] <= 70) || src_bytes[i] == 95)
          @if src_bytes[i] != 95
            num_str = str_concat(num_str, str_from_char_code(src_bytes[i]))
          @end
          i = i + 1
          col = col + 1
        @end
        tokens = tokens.push(make_token("HEX_INT", num_str, line, start_col))
      @elif c == 48 && i + 1 < num_items && (src_bytes[i + 1] == 98 || src_bytes[i + 1] == 66) @! 0b
        num_str = "0b"
        i = i + 2
        col = col + 2
        @while i < num_items && (src_bytes[i] == 48 || src_bytes[i] == 49 || src_bytes[i] == 95)
          @if src_bytes[i] != 95
            num_str = str_concat(num_str, str_from_char_code(src_bytes[i]))
          @end
          i = i + 1
          col = col + 1
        @end
        tokens = tokens.push(make_token("BIN_INT", num_str, line, start_col))
      @else
        is_float = 0
        @while i < num_items && (lex_is_digit(src_bytes[i]) || src_bytes[i] == 95 || (src_bytes[i] == 46 && i + 1 < num_items && lex_is_digit(src_bytes[i + 1])))
          @if src_bytes[i] == 46
            is_float = 1
          @end
          @if src_bytes[i] != 95
            num_str = str_concat(num_str, str_from_char_code(src_bytes[i]))
          @end
          i = i + 1
          col = col + 1
        @end
        @if is_float == 1
          tokens = tokens.push(make_token("FLOAT", num_str, line, start_col))
        @else
          tokens = tokens.push(make_token("INT", num_str, line, start_col))
        @end
      @end
    @elif c == 34 || c == 39 @! " or '
      quote = c
      start_col = col
      str_val = ""
      i = i + 1
      col = col + 1
      @while i < num_items && src_bytes[i] != quote
        @if src_bytes[i] == 92 && i + 1 < num_items @! Escape characters
          i = i + 1
          col = col + 1
          esc = src_bytes[i]
          @if esc == 110 str_val = str_concat(str_val, "\n")
          @elif esc == 116 str_val = str_concat(str_val, "\t")
          @elif esc == 114 str_val = str_concat(str_val, "\r")
          @elif esc == 48 str_val = str_concat(str_val, "\0")
          @elif esc == 92 str_val = str_concat(str_val, "\\")
          @elif esc == 34 str_val = str_concat(str_val, "\"")
          @elif esc == 39 str_val = str_concat(str_val, "'")
          @else str_val = str_concat(str_val, str_from_char_code(esc)) @end
        @else
          @if src_bytes[i] == 10
            line = line + 1
            col = 1
          @end
          str_val = str_concat(str_val, str_from_char_code(src_bytes[i]))
        @end
        i = i + 1
        col = col + 1
      @end
      @if i < num_items && src_bytes[i] == quote
        i = i + 1
        col = col + 1
      @end
      tokens = tokens.push(make_token("STR", str_val, line, start_col))
    @elif c == 43 @! +
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("PLUSEQ", "+=", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("PLUS", "+", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 45 @! -
      @if i + 1 < num_items && src_bytes[i + 1] == 62
        tokens = tokens.push(make_token("ARROW", "->", line, col))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("MINUSEQ", "-=", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("MINUS", "-", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 42 @! *
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("STAREQ", "*=", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("STAR", "*", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 47 @! /
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("SLASHEQ", "/=", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("SLASH", "/", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 37 @! %
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("PERCENTEQ", "%=", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("PERCENT", "%", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 61 @! =
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("EQ", "==", line, col))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && src_bytes[i + 1] == 62
        tokens = tokens.push(make_token("FATARROW", "=>", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("ASSIGN", "=", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 33 @! excl
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("NEQ", "!=", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("BANG", "!", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 60 @! <
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("LTE", "<=", line, col))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && src_bytes[i + 1] == 60
        tokens = tokens.push(make_token("LSHIFT", "<<", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("LT", "<", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 62 @! >
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(make_token("GTE", ">=", line, col))
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && src_bytes[i + 1] == 62
        tokens = tokens.push(make_token("RSHIFT", ">>", line, col))
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(make_token("GT", ">", line, col))
        i = i + 1
        col = col + 1
      @end
    @elif c == 38 && i + 1 < num_items && src_bytes[i + 1] == 38 @! &&
      tokens = tokens.push(make_token("AND", "&&", line, col))
      i = i + 2
      col = col + 2
    @elif c == 124 && i + 1 < num_items && src_bytes[i + 1] == 124 @! ||
      tokens = tokens.push(make_token("OR", "||", line, col))
      i = i + 2
      col = col + 2
    @elif c == 38 @! &
      tokens = tokens.push(make_token("AMP", "&", line, col))
      i = i + 1
      col = col + 1
    @elif c == 124 @! |
      tokens = tokens.push(make_token("PIPE", "|", line, col))
      i = i + 1
      col = col + 1
    @elif c == 94 @! ^
      tokens = tokens.push(make_token("CARET", "^", line, col))
      i = i + 1
      col = col + 1
    @elif c == 126 @! ~
      tokens = tokens.push(make_token("TILDE", "~", line, col))
      i = i + 1
      col = col + 1
    @elif c == 40 @! (
      tokens = tokens.push(make_token("LPAREN", "(", line, col))
      i = i + 1
      col = col + 1
    @elif c == 41 @! )
      tokens = tokens.push(make_token("RPAREN", ")", line, col))
      i = i + 1
      col = col + 1
    @elif c == 91 @! [
      tokens = tokens.push(make_token("LBRACKET", "[", line, col))
      i = i + 1
      col = col + 1
    @elif c == 93 @! ]
      tokens = tokens.push(make_token("RBRACKET", "]", line, col))
      i = i + 1
      col = col + 1
    @elif c == 123 @! {
      tokens = tokens.push(make_token("LBRACE", "{", line, col))
      i = i + 1
      col = col + 1
    @elif c == 125 @! }
      tokens = tokens.push(make_token("RBRACE", "}", line, col))
      i = i + 1
      col = col + 1
    @elif c == 44 @! ,
      tokens = tokens.push(make_token("COMMA", ",", line, col))
      i = i + 1
      col = col + 1
    @elif c == 58 @! :
      tokens = tokens.push(make_token("COLON", ":", line, col))
      i = i + 1
      col = col + 1
    @elif c == 59 @! ;
      tokens = tokens.push(make_token("SEMI", ";", line, col))
      i = i + 1
      col = col + 1
    @elif c == 46 @! .
      tokens = tokens.push(make_token("DOT", ".", line, col))
      i = i + 1
      col = col + 1
    @else
      i = i + 1
      col = col + 1
    @end
  @end

  tokens = tokens.push(make_token("EOF", "EOF", line, col))
  return tokens
@end

@! ============================================================================
@! 3. PURE MAYA RECURSIVE DESCENT PRATT AST PARSER
@! ============================================================================

@fn parser_skip_newlines(tokens, pos)
  p = pos
  num_items = tokens.len()
  @while p < num_items && (compiler_str_eq(get_tok_kind(tokens, p), "NEWLINE") == 1 || compiler_str_eq(get_tok_kind(tokens, p), "SEMI") == 1)
    p = p + 1
  @end
  return p
@end

@fn parser_parse_primary(tokens, pos)
  tok = tokens[pos]
  ttype = tok_kind(tok)
  tval = tok_name(tok)

  @if compiler_str_eq(ttype, "INT") == 1 || compiler_str_eq(ttype, "HEX_INT") == 1 || compiler_str_eq(ttype, "BIN_INT") == 1
    ival = parse_int_val(tval)
    node = ast_node("LiteralInt")
    node.val = ival
    return { parse_node: node, parse_next: pos + 1 }
  @elif compiler_str_eq(ttype, "FLOAT") == 1
    fval = parse_float_val(tval)
    node = ast_node("LiteralFloat")
    node.val = fval
    return { parse_node: node, parse_next: pos + 1 }
  @elif compiler_str_eq(ttype, "STR") == 1
    node = ast_node("LiteralStr")
    node.name = tval
    node.val = tval
    node.value = tval
    return { parse_node: node, parse_next: pos + 1 }
  @elif compiler_str_eq(ttype, "BOOL") == 1
    bval = 0
    @if compiler_str_eq(tval, "true") == 1 bval = 1 @end
    node = ast_node("LiteralBool")
    node.val = bval
    return { parse_node: node, parse_next: pos + 1 }
  @elif compiler_str_eq(ttype, "NONE") == 1
    node = ast_node("LiteralNone")
    return { parse_node: node, parse_next: pos + 1 }
  @elif compiler_str_eq(ttype, "IDENT") == 1
    @! Check if struct literal initialization (e.g. { kind: "x", name: "y" })
    @if pos + 1 < tokens.len() && compiler_str_eq(get_tok_kind(tokens, pos + 1), "LBRACE") == 1
      p = pos + 2
      elements = []
      break_struct = 0
      @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACE") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0 && break_struct == 0
        p = parser_skip_newlines(tokens, p)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACE") == 1
          break_struct = 1
        @end
        @if break_struct == 0
        f_name = get_tok_name(tokens, p)
        p = p + 1 @! skip field name
        p = parser_skip_newlines(tokens, p)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COLON") == 1
          p = p + 1
        @end
        p = parser_skip_newlines(tokens, p)
        f_val_res = parser_parse_expr(tokens, p, 0)
        f_entry = ast_node("FieldInit")
        f_entry.name = f_name
        f_entry.expr = f_val_res.parse_node
        f_entry.value = f_val_res.parse_node
        elements = elements.push(f_entry)
        p = parser_skip_newlines(tokens, f_val_res.parse_next)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
          p = p + 1
        @end
        p = parser_skip_newlines(tokens, p)
        @end
      @end
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACE") == 1
        p = p + 1
      @end
      st_node = ast_node("StructLit")
      st_node.name = tval
      st_node.elements = elements
      return { parse_node: st_node, parse_next: p }
    @elif pos + 1 < tokens.len() && compiler_str_eq(get_tok_kind(tokens, pos + 1), "LPAREN") == 1
      p = pos + 2
      args = []
      arg_cont = 1
      @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0 && arg_cont == 1
        p = parser_skip_newlines(tokens, p)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
          arg_cont = 0
        @else
          arg_res = parser_parse_expr(tokens, p, 0)
          args = args.push(arg_res.parse_node)
          p = parser_skip_newlines(tokens, arg_res.parse_next)
          @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
            p = p + 1
          @end
        @end
      @end
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
        p = p + 1
      @end
      c_node = ast_node("Call")
      c_node.name = tval
      c_node.args = args
      fn_v = ast_node("Variable")
      fn_v.name = tval
      c_node.func = fn_v
      return { parse_node: c_node, parse_next: p }
    @else
      v_node = ast_node("Variable")
      v_node.name = tval
      return { parse_node: v_node, parse_next: pos + 1 }
    @end
  @elif compiler_str_eq(ttype, "LPAREN") == 1
    res = parser_parse_expr(tokens, pos + 1, 0)
    p = parser_skip_newlines(tokens, res.parse_next)
    @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
      p = p + 1
    @end
    return { parse_node: res.parse_node, parse_next: p }
  @elif compiler_str_eq(ttype, "LBRACKET") == 1
    p = pos + 1
    elems = []
    @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACKET") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      p = parser_skip_newlines(tokens, p)
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACKET") == 1
        break
      @end
      e_res = parser_parse_expr(tokens, p, 0)
      elems = elems.push(e_res.parse_node)
      p = parser_skip_newlines(tokens, e_res.parse_next)
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
        p = p + 1
      @end
    @end
    @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACKET") == 1
      p = p + 1
    @end
    arr_node = ast_node("ArrayLit")
    arr_node.elements = elems
    return { parse_node: arr_node, parse_next: p }
  @elif compiler_str_eq(ttype, "LBRACE") == 1
    @! Anonymous struct literal initialization (e.g. { x: 100, y: 200 })
    @! WHY: test_comprehensive Suite 4 creates Point as { x: 100, y: 200 }.
    @! Parsing LBRACE produces a StructLit AST node with FieldInit elements for GEP lowering.
    p = pos + 1
    elements = []
    break_struct = 0
    @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACE") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0 && break_struct == 0
      p = parser_skip_newlines(tokens, p)
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACE") == 1
        break_struct = 1
      @end
      @if break_struct == 0
        f_name = get_tok_name(tokens, p)
        p = p + 1 @! skip field name
        p = parser_skip_newlines(tokens, p)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COLON") == 1
          p = p + 1
        @end
        p = parser_skip_newlines(tokens, p)
        f_val_res = parser_parse_expr(tokens, p, 0)
        f_entry = ast_node("FieldInit")
        f_entry.name = f_name
        f_entry.expr = f_val_res.parse_node
        f_entry.value = f_val_res.parse_node
        elements = elements.push(f_entry)
        p = parser_skip_newlines(tokens, f_val_res.parse_next)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
          p = p + 1
        @end
        p = parser_skip_newlines(tokens, p)
      @end
    @end
    @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACE") == 1
      p = p + 1
    @end
    st_node = ast_node("StructLit")
    st_node.name = ""
    st_node.elements = elements
    return { parse_node: st_node, parse_next: p }
  @elif compiler_str_eq(ttype, "BANG") == 1 || compiler_str_eq(ttype, "MINUS") == 1 || compiler_str_eq(ttype, "TILDE") == 1
    u_op = tval
    u_res = parser_parse_primary(tokens, pos + 1)
    un_node = ast_node("UnaryOp")
    un_node.op = u_op
    un_node.expr = u_res.parse_node
    return { parse_node: un_node, parse_next: u_res.parse_next }
  @end

  return { parse_node: ast_node("LiteralNone"), parse_next: pos + 1 }
@end

@fn parser_op_precedence(op_type)
  @if compiler_str_eq(op_type, "OR") == 1 return 1 @end
  @if compiler_str_eq(op_type, "AND") == 1 return 2 @end
  @if compiler_str_eq(op_type, "PIPE") == 1 return 3 @end
  @if compiler_str_eq(op_type, "CARET") == 1 return 4 @end
  @if compiler_str_eq(op_type, "AMP") == 1 return 5 @end
  @if compiler_str_eq(op_type, "EQ") == 1 || compiler_str_eq(op_type, "NEQ") == 1 return 6 @end
  @if compiler_str_eq(op_type, "LT") == 1 || compiler_str_eq(op_type, "LTE") == 1 || compiler_str_eq(op_type, "GT") == 1 || compiler_str_eq(op_type, "GTE") == 1 return 7 @end
  @if compiler_str_eq(op_type, "LSHIFT") == 1 || compiler_str_eq(op_type, "RSHIFT") == 1 return 8 @end
  @if compiler_str_eq(op_type, "PLUS") == 1 || compiler_str_eq(op_type, "MINUS") == 1 return 9 @end
  @if compiler_str_eq(op_type, "STAR") == 1 || compiler_str_eq(op_type, "SLASH") == 1 || compiler_str_eq(op_type, "PERCENT") == 1 return 10 @end
  return 0
@end

@fn parser_parse_expr(tokens, pos, min_prec)
  pos = parser_skip_newlines(tokens, pos)
  prim = parser_parse_primary(tokens, pos)
  left = prim.parse_node
  p = prim.parse_next
  expr_cont = 1

  @while p < tokens.len() && expr_cont == 1
    p = parser_skip_newlines(tokens, p)
    @if p >= tokens.len()
      expr_cont = 0
    @else
      tok = tokens[p]
      ttype = tok_kind(tok)
      @! Suffix member access or method call: left.field or left.method(args)
      @! WHY: Member access (p.x, p.y) and method calls (arr.len()) require parsing
      @! the DOT token with highest precedence following an expression.
      @if compiler_str_eq(ttype, "DOT") == 1
        p = p + 1
        p = parser_skip_newlines(tokens, p)
        field_name = get_tok_name(tokens, p)
        p = p + 1
        @! Check if method call: left.method(args)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "LPAREN") == 1
          p = p + 1
          m_args = []
          m_cont = 1
          @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0 && m_cont == 1
            p = parser_skip_newlines(tokens, p)
            @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
              m_cont = 0
            @else
              m_arg_res = parser_parse_expr(tokens, p, 0)
              m_args = m_args.push(m_arg_res.parse_node)
              p = parser_skip_newlines(tokens, m_arg_res.parse_next)
              @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
                p = p + 1
              @end
            @end
          @end
          @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
            p = p + 1
          @end
          call_node = ast_node("MemberAccess")
          call_node.left = left
          call_node.target = left
          call_node.name = field_name
          call_node.args = m_args
          left = call_node
        @else
          ma_node = ast_node("MemberAccess")
          ma_node.left = left
          ma_node.target = left
          ma_node.name = field_name
          left = ma_node
        @end
      @elif compiler_str_eq(ttype, "LBRACKET") == 1
        p = p + 1
        p = parser_skip_newlines(tokens, p)
        idx_res = parser_parse_expr(tokens, p, 0)
        p = parser_skip_newlines(tokens, idx_res.parse_next)
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RBRACKET") == 1
          p = p + 1
        @end
        idx_node = ast_node("Index")
        idx_node.target = left
        idx_node.left = left
        idx_node.index = idx_res.parse_node
        left = idx_node
      @elif compiler_str_eq(ttype, "CUSTOM_OP") == 1
        op_sym = tok_name(tok)
        op_prec = str_to_int(tok[4])
        op_fn = tok[5]
        op_fix = tok[6]
        
        @if op_prec == 0 || op_prec < min_prec
          expr_cont = 0
        @else
          p = parser_skip_newlines(tokens, p + 1)
          next_prec = op_prec + 1
          @if compiler_str_eq(op_fix, "INFIX_RIGHT") == 1
            next_prec = op_prec
          @end
          
          right_res = parser_parse_expr(tokens, p, next_prec)
          
          call_node = ast_node("Call")
          call_node.name = op_fn
          call_node.args = [left, right_res.parse_node]
          fn_v = ast_node("Variable")
          fn_v.name = op_fn
          call_node.func = fn_v
          left = call_node
          p = right_res.parse_next
        @end
      @else
        prec = parser_op_precedence(ttype)
        @if prec == 0 || prec < min_prec
          expr_cont = 0
        @else
          op_str = tok_name(tok)
          p = parser_skip_newlines(tokens, p + 1)
          right_res = parser_parse_expr(tokens, p, prec + 1)

          bin_node = ast_node("BinaryOp")
          bin_node.op = op_str
          bin_node.left = left
          bin_node.right = right_res.parse_node
          left = bin_node
          p = right_res.parse_next
        @end
      @end
    @end
  @end

  return { parse_node: left, parse_next: p }
@end

@fn parser_parse_statement(tokens, pos)
  p = parser_skip_newlines(tokens, pos)
  @if p >= tokens.len() || compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 1
    return { parse_node: ast_node("LiteralNone"), parse_next: tokens.len() }
  @end

  tok = tokens[p]
  ttype = tok_kind(tok)
  tval = tok_name(tok)

  @! 1. Function Definition: @fn name(params) or fn name(params)
  @if (compiler_str_eq(ttype, "DIRECTIVE") == 1 && compiler_str_eq(tval, "@fn") == 1) || compiler_str_eq(ttype, "FN") == 1 || compiler_str_eq(tval, "fn") == 1
    p = p + 1
    name_tok = tokens[p]
    fn_name = tok_name(name_tok)
    p = p + 2 @! consume name and LPAREN
    params = []
    @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      @if compiler_str_eq(get_tok_kind(tokens, p), "IDENT") == 1
        params = params.push(get_tok_name(tokens, p))
        p = p + 1
        @! Skip optional parameter type annotation (e.g., : string, : array, : Map[K, V])
        @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COLON") == 1
          p = p + 1
          bracket_depth = 0
          paren_depth = 0
          break_p = 0
          @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0 && break_p == 0
            @if compiler_str_eq(get_tok_kind(tokens, p), "LBRACKET") == 1
              bracket_depth = bracket_depth + 1
            @elif compiler_str_eq(get_tok_kind(tokens, p), "RBRACKET") == 1
              @if bracket_depth > 0 bracket_depth = bracket_depth - 1 @end
            @elif compiler_str_eq(get_tok_kind(tokens, p), "LPAREN") == 1
              paren_depth = paren_depth + 1
            @elif compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
              @if paren_depth > 0
                paren_depth = paren_depth - 1
              @else
                break_p = 1
              @end
            @elif compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
              @if bracket_depth == 0 && paren_depth == 0
                break_p = 1
              @end
            @end
            @if break_p == 0
            p = p + 1
            @end
          @end
        @end
      @else
        p = p + 1
      @end
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
        p = p + 1
      @end
    @end
    @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "RPAREN") == 1
      p = p + 1
    @end
    @! Skip optional return type annotation (e.g., -> ASTNode or : i64)
    @if p < tokens.len() && (compiler_str_eq(get_tok_kind(tokens, p), "ARROW") == 1 || compiler_str_eq(get_tok_kind(tokens, p), "COLON") == 1)
      p = p + 1
      @while p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "NEWLINE") == 0 && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
        p = p + 1
      @end
    @end
    p = parser_skip_newlines(tokens, p)

    body = []
    @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      s_res = parser_parse_statement(tokens, p)
      body = body.push(s_res.parse_node)
      p = parser_skip_newlines(tokens, s_res.parse_next)
    @end
    @if p < tokens.len() && is_end_tok_safe(tokens, p)
      p = p + 1
    @end

    f_node = ast_node("FnDef")
    f_node.name = fn_name
    f_node.params = params
    f_node.ret_type = "i64"
    f_node.body = body
    return { parse_node: f_node, parse_next: p }
  @end

  @! 2. Return Statement
  @if compiler_str_eq(ttype, "RETURN") == 1 || compiler_str_eq(tval, "return") == 1
    p = p + 1
    r_res = parser_parse_expr(tokens, p, 0)
    ret_node = ast_node("Return")
    ret_node.expr = r_res.parse_node
    ret_node.value = r_res.parse_node
    return { parse_node: ret_node, parse_next: r_res.parse_next }
  @end

  @! 3. While Loop: @while cond ... @end or while cond
  @if (compiler_str_eq(ttype, "DIRECTIVE") == 1 && compiler_str_eq(tval, "@while") == 1) || compiler_str_eq(ttype, "WHILE") == 1 || compiler_str_eq(tval, "while") == 1
    p = p + 1
    c_res = parser_parse_expr(tokens, p, 0)
    p = parser_skip_newlines(tokens, c_res.parse_next)
    w_body = []
    @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      s_res = parser_parse_statement(tokens, p)
      w_body = w_body.push(s_res.parse_node)
      p = parser_skip_newlines(tokens, s_res.parse_next)
    @end
    @if p < tokens.len() && is_end_tok_safe(tokens, p)
      p = p + 1
    @end
    w_node = ast_node("WhileLoop")
    w_node.condition = c_res.parse_node
    w_node.body = w_body
    return { parse_node: w_node, parse_next: p }
  @end

  @! 4. For Loop: @for_var in iterable ... @end or for_var in iterable
  @if (compiler_str_eq(ttype, "DIRECTIVE") == 1 && (compiler_str_eq(tval, "@for") == 1 || compiler_str_eq(tval, "@parallel_for") == 1)) || compiler_str_eq(ttype, "FOR") == 1 || compiler_str_eq(tval, "for") == 1
    p = p + 1
    var_tok = tokens[p]
    var_name = tok_name(var_tok)
    p = p + 2 @! skip var and 'in'
    it_res = parser_parse_expr(tokens, p, 0)
    p = parser_skip_newlines(tokens, it_res.parse_next)
    f_body = []
    @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      s_res = parser_parse_statement(tokens, p)
      f_body = f_body.push(s_res.parse_node)
      p = parser_skip_newlines(tokens, s_res.parse_next)
    @end
    @if p < tokens.len() && is_end_tok_safe(tokens, p)
      p = p + 1
    @end
    for_node = ast_node("ForLoop")
    for_node.variable = var_name
    for_node.iterable = it_res.parse_node
    for_node.body = f_body
    return { parse_node: for_node, parse_next: p }
  @end

  @! 5. If Statement: @if cond ... @elif cond ... @else ... @end
  @if (compiler_str_eq(ttype, "DIRECTIVE") == 1 && compiler_str_eq(tval, "@if") == 1) || compiler_str_eq(ttype, "IF") == 1 || compiler_str_eq(tval, "if") == 1
    p = p + 1
    if_c = parser_parse_expr(tokens, p, 0)
    p = parser_skip_newlines(tokens, if_c.parse_next)
    then_body = []
    @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && 0 == is_else_tok_safe(tokens, p) && 0 == is_elif_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      s_res = parser_parse_statement(tokens, p)
      then_body = then_body.push(s_res.parse_node)
      p = parser_skip_newlines(tokens, s_res.parse_next)
    @end

    elif_branches = []
    @while p < tokens.len() && is_elif_tok_safe(tokens, p)
      p = p + 1
      elif_c = parser_parse_expr(tokens, p, 0)
      p = parser_skip_newlines(tokens, elif_c.parse_next)
      elif_body = []
      @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && 0 == is_else_tok_safe(tokens, p) && 0 == is_elif_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
        s_res = parser_parse_statement(tokens, p)
        elif_body = elif_body.push(s_res.parse_node)
        p = parser_skip_newlines(tokens, s_res.parse_next)
      @end
      e_branch = ast_node("ElifBranch")
      e_branch.cond = elif_c.parse_node
      e_branch.body = elif_body
      elif_branches = elif_branches.push(e_branch)
    @end

    else_body = []
    @if p < tokens.len() && is_else_tok_safe(tokens, p)
      p = p + 1
      p = parser_skip_newlines(tokens, p)
      @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
        s_res = parser_parse_statement(tokens, p)
        else_body = else_body.push(s_res.parse_node)
        p = parser_skip_newlines(tokens, s_res.parse_next)
      @end
    @end

    @if p < tokens.len() && is_end_tok_safe(tokens, p)
      p = p + 1
    @end

    if_node = ast_node("IfStmt")
    if_node.condition = if_c.parse_node
    if_node.then_body = then_body
    if_node.elif_branches = elif_branches
    if_node.else_body = else_body
    return { parse_node: if_node, parse_next: p }
  @end

  @! 6. Break & Continue
  @if compiler_str_eq(ttype, "BREAK") == 1 || compiler_str_eq(tval, "break") == 1
    return { parse_node: ast_node("Break"), parse_next: p + 1 }
  @elif compiler_str_eq(ttype, "CONTINUE") == 1 || compiler_str_eq(tval, "continue") == 1
    return { parse_node: ast_node("Continue"), parse_next: p + 1 }
  @end

  @! 7. Import statement
  @if compiler_str_eq(ttype, "IMPORT") == 1 || compiler_str_eq(tval, "import") == 1
    p = p + 1
    p = parser_skip_newlines(tokens, p)
    imp_path = get_tok_name(tokens, p)
    imp_node = ast_node("Import")
    imp_node.name = imp_path
    return { parse_node: imp_node, parse_next: p + 1 }
  @end

  @! 7b. Struct Definition: @struct Name ... @end
  @if (compiler_str_eq(ttype, "DIRECTIVE") == 1 && (compiler_str_eq(tval, "@struct") == 1 || compiler_str_eq(tval, "@type") == 1)) || compiler_str_eq(ttype, "STRUCT") == 1 || compiler_str_eq(tval, "struct") == 1 || compiler_str_eq(tval, "type") == 1
    p = p + 1
    s_name = get_tok_name(tokens, p)
    p = p + 1
    p = parser_skip_newlines(tokens, p)
    fields = []
    f_idx = 0
    @while p < tokens.len() && 0 == is_end_tok_safe(tokens, p) && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      f_name = get_tok_name(tokens, p)
      p = p + 1
      f_type = "i64"
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COLON") == 1
        p = p + 1
        f_type = get_tok_name(tokens, p)
        p = p + 1
      @end
      @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "COMMA") == 1
        p = p + 1
      @end
      f_node = ast_node("Field")
      f_node.name = f_name
      f_node.ret_type = f_type
      fields = fields.push(f_node)
      f_idx = f_idx + 1
      p = parser_skip_newlines(tokens, p)
    @end
    @if p < tokens.len() && is_end_tok_safe(tokens, p)
      p = p + 1
    @end
    st_node = ast_node("StructDef")
    st_node.name = s_name
    st_node.params = fields
    st_node.elements = fields
    return { parse_node: st_node, parse_next: p }
  @end

  @! 8. Variable Assignment: var = expr, let var = expr, var += expr
  @if compiler_str_eq(ttype, "LET") == 1 || compiler_str_eq(tval, "let") == 1 || compiler_str_eq(tval, "var") == 1
    p = p + 1
  @end
  @if p < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p), "IDENT") == 1 && p + 1 < tokens.len()
    v_name = get_tok_name(tokens, p)
    op_t = get_tok_kind(tokens, p + 1)
    @if compiler_str_eq(op_t, "ASSIGN") == 1
      res = parser_parse_expr(tokens, p + 2, 0)
      as_node = ast_node("Assign")
      as_node.target = v_name
      as_node.expr = res.parse_node
      as_node.value = res.parse_node
      return { parse_node: as_node, parse_next: res.parse_next }
    @elif compiler_str_eq(op_t, "PLUSEQ") == 1
      res = parser_parse_expr(tokens, p + 2, 0)
      v_ref = ast_node("Variable")
      v_ref.name = v_name
      b_add = ast_node("BinaryOp")
      b_add.op = "+"
      b_add.left = v_ref
      b_add.right = res.parse_node
      as_node = ast_node("Assign")
      as_node.target = v_name
      as_node.value = b_add
      return { parse_node: as_node, parse_next: res.parse_next }
    @elif compiler_str_eq(op_t, "MINUSEQ") == 1
      res = parser_parse_expr(tokens, p + 2, 0)
      v_ref = ast_node("Variable")
      v_ref.name = v_name
      b_sub = ast_node("BinaryOp")
      b_sub.op = "-"
      b_sub.left = v_ref
      b_sub.right = res.parse_node
      as_node = ast_node("Assign")
      as_node.target = v_name
      as_node.value = b_sub
      return { parse_node: as_node, parse_next: res.parse_next }
    @elif compiler_str_eq(op_t, "STAREQ") == 1
      res = parser_parse_expr(tokens, p + 2, 0)
      v_ref = ast_node("Variable")
      v_ref.name = v_name
      b_mul = ast_node("BinaryOp")
      b_mul.op = "*"
      b_mul.left = v_ref
      b_mul.right = res.parse_node
      as_node = ast_node("Assign")
      as_node.target = v_name
      as_node.value = b_mul
      return { parse_node: as_node, parse_next: res.parse_next }
    @elif compiler_str_eq(op_t, "SLASHEQ") == 1
      res = parser_parse_expr(tokens, p + 2, 0)
      v_ref = ast_node("Variable")
      v_ref.name = v_name
      b_div = ast_node("BinaryOp")
      b_div.op = "/"
      b_div.left = v_ref
      b_div.right = res.parse_node
      as_node = ast_node("Assign")
      as_node.target = v_name
      as_node.value = b_div
      return { parse_node: as_node, parse_next: res.parse_next }
    @end
  @end

  @! 9. Expression Statement or Target Assignment (e.g. target.field = expr, target[index] = expr)
  @! WHY: Target assignments on struct fields and array elements parse as an expression on the LHS
  @! followed by ASSIGN (=) and the RHS value expression.
  res = parser_parse_expr(tokens, p, 0)
  p_after = parser_skip_newlines(tokens, res.parse_next)
  @if p_after < tokens.len() && compiler_str_eq(get_tok_kind(tokens, p_after), "ASSIGN") == 1
    as_val_res = parser_parse_expr(tokens, p_after + 1, 0)
    as_node = ast_node("Assign")
    as_node.target = res.parse_node
    as_node.left = res.parse_node
    as_node.value = as_val_res.parse_node
    as_node.expr = as_val_res.parse_node
    return { parse_node: as_node, parse_next: as_val_res.parse_next }
  @end
  ex_node = ast_node("ExpressionStmt")
  ex_node.expr = res.parse_node
  return { parse_node: ex_node, parse_next: res.parse_next }
@end

@fn parser_parse_program(source)
  inf_eng = infinity_engine_new()
  trans_src = infinity_transform_source(inf_eng, source)
  raw_tokens = lex_tokenize(trans_src)
  tokens = infinity_transform_tokens(inf_eng, raw_tokens)
  
  statements = []
  p = 0
  num_items = tokens.len()

  @while p < num_items && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
    p = parser_skip_newlines(tokens, p)
    @if p < num_items && compiler_str_eq(get_tok_kind(tokens, p), "EOF") == 0
      s_res = parser_parse_statement(tokens, p)
      statements = statements.push(s_res.parse_node)
      p = parser_skip_newlines(tokens, s_res.parse_next)
    @end
  @end

  return { ast_statements: statements, ast_tokens: tokens, inf_engine: inf_eng }
@end

@! ============================================================================
@! 4. PRIMARY COMPILER PIPELINE INTEGRATION
@! ============================================================================

@fn get_dir_of_filepath(filepath)
  num_items = str_len(filepath)
  last_slash = -1
  i = num_items - 1
  @while i >= 0
    @if str_char_at(filepath, i) == 47 @! '/'
      last_slash = i
      break
    @end
    i = i - 1
  @end
  @if last_slash < 0
    return "."
  @end
  return str_substr(filepath, 0, last_slash)
@end

@fn resolve_file_import_path(base_dir, imp_path)
  p = imp_path
  @if str_ends_with(p, ".maya") == 0
    p = str_concat(p, ".maya")
  @end
  
  @! 1. Direct path / Absolute path
  @if str_starts_with(p, "/") == 1
    c = file_read(p)
    @if compiler_str_eq(c, "") == 0 return p @end
  @end
  
  @! 2. Relative to base_dir
  @if base_dir != "" && compiler_str_eq(base_dir, "") == 0 && compiler_str_eq(base_dir, ".") == 0
    cand = string_concat(base_dir, string_concat("/", p))
    c = file_read(cand)
    @if compiler_str_eq(c, "") == 0 return cand @end
  @end
  
  @! 3. Relative to workspace root / current dir
  c = file_read(p)
  @if compiler_str_eq(c, "") == 0 return p @end
  
  @! 4. Standard library prefixes
  cand = string_concat("universe/", p)
  c = file_read(cand)
  @if compiler_str_eq(c, "") == 0 return cand @end
  
  cand = string_concat("compiler/", p)
  c = file_read(cand)
  @if compiler_str_eq(c, "") == 0 return cand @end

  return p
@end

@fn resolve_and_expand_ast_imports(ast, base_dir, visited)
  expanded = []
  i = 0
  num_items = ast.len()
  @while i < num_items
    stmt = ast[i]
    @if stmt != 0 && compiler_str_eq(stmt.kind, "Import") == 1
      imp_target = stmt.name
      resolved_path = resolve_file_import_path(base_dir, imp_target)
      
      is_visited = 0
      v_i = 0
      @while v_i < visited.len()
        @if compiler_str_eq(visited[v_i], resolved_path) == 1
          is_visited = 1
        @end
        v_i = v_i + 1
      @end
      
      @if is_visited == 0
        visited = visited.push(resolved_path)
        content = file_read(resolved_path)
        @if compiler_str_eq(content, "") == 0
          sub_base = get_dir_of_filepath(resolved_path)
          sub_parsed = parser_parse_program(content)
          sub_res = resolve_and_expand_ast_imports(sub_parsed.ast_statements, sub_base, visited)
          visited = sub_res.visited
          sub_stmts = sub_res.ast
          
          s_i = 0
          @while s_i < sub_stmts.len()
            expanded = expanded.push(sub_stmts[s_i])
            s_i = s_i + 1
          @end
        @end
      @end
    @else
      expanded = expanded.push(stmt)
    @end
    i = i + 1
  @end
  return { ast: expanded, visited: visited }
@end

@! Compiles Maya source code into standalone Linux ELF64 binary with options
@fn compile_source_with_options(source_code, output_filepath, options)
  mod_name = "maya_program"
  dump_ir = 0
  base_dir = "."
  @if options != 0
    @if options.opt_module_name != "" && options.opt_module_name != ""
      mod_name = options.opt_module_name
    @end
    @if options.opt_dump_ir != 0
      dump_ir = options.opt_dump_ir
    @end
    @if options.opt_base_dir != "" && options.opt_base_dir != ""
      base_dir = options.opt_base_dir
    @end
  @end

  inf_engine = infinity_engine_new()
  parsed = parser_parse_program(source_code)
  initial_ast = parsed.ast_statements
  tokens = parsed.ast_tokens
  @if parsed.inf_engine != 0
    inf_engine = parsed.inf_engine
  @end

  @! Expand and resolve imports recursively
  exp_res = resolve_and_expand_ast_imports(initial_ast, base_dir, [])
  ast = exp_res.ast

  @! Apply Infinity Syntax dynamic AST transformation passes
  ast = infinity_apply_ast_transforms(ast, inf_engine)

  @if options != 0 && options.opt_dump_tokens == 1
    println(str_concat("--- TOKEN STREAM (", str_concat(int_to_str(tokens.len()), " tokens) ---")))
    t_i = 0
    @while t_i < tokens.len()
      tok_item = tokens[t_i]
      println(str_concat("  [", str_concat(int_to_str(t_i), str_concat("] kind=", str_concat(tok_item[0], str_concat(" val='", str_concat(tok_item[1], "'")))))))
      t_i = t_i + 1
    @end
  @end

  @if options != 0 && options.opt_dump_ast == 1
    println(str_concat("--- AST STATEMENTS (", str_concat(int_to_str(ast.len()), " nodes) ---")))
    a_i = 0
    @while a_i < ast.len()
      a_node = ast[a_i]
      println(str_concat("  [", str_concat(int_to_str(a_i), str_concat("] ", str_concat(a_node.kind, str_concat(" name=", a_node.name))))))
      a_i = a_i + 1
    @end
  @end

  @if ast.len() == 0
    return {
      cr_success: 0,
      cr_out_path: output_filepath,
      cr_file_size: 0,
      cr_entry_vaddr: 0,
      cr_tokens_count: tokens.len(),
      cr_ast_count: 0,
      cr_ir_funcs: 0,
      cr_error_msg: "Syntax Error: Parser produced 0 AST statements"
    }
  @end

  @! Lower AST to Maya IR Module
  ir_opts = { module_name: mod_name, dump_ir: dump_ir }
  ir_res = ir_module_from_ast(ast, ir_opts)
  @if ir_res.error == 1
    return {
      cr_success: 0,
      cr_out_path: output_filepath,
      cr_file_size: 0,
      cr_entry_vaddr: 0,
      cr_tokens_count: tokens.len(),
      cr_ast_count: ast.len(),
      cr_ir_funcs: 0,
      cr_error_msg: ir_res.message
    }
  @end

  ir_mod = ir_res.module

  @! Lower IR Module to x86-64 Machine Code
  x86_res = x86_codegen_module(ir_mod)

  @if options != 0 && options.opt_dump_asm == 1
    println("--- x86-64 CODEGEN RESULT ---")
    println(str_concat("  Text bytes: ", int_to_str(x86_res.text_bytes.len())))
    println(str_concat("  Rodata bytes: ", int_to_str(x86_res.rodata_bytes.len())))
    println(str_concat("  Entry offset: ", int_to_str(x86_res.entry_offset)))
  @end

  @! Assemble & Write Standalone Linux ELF64 Executable
  elf_res = elf_write_executable(x86_res, output_filepath)

  @if elf_res.ew_success == 0
    return {
      cr_success: 0,
      cr_out_path: output_filepath,
      cr_file_size: 0,
      cr_entry_vaddr: 0,
      cr_tokens_count: tokens.len(),
      cr_ast_count: ast.len(),
      cr_ir_funcs: ir_mod.functions.len(),
      cr_error_msg: elf_res.ew_error_msg
    }
  @end

  @if options != 0
    @if options.backend == 3
      sys_write(1, "[7] Sovereign start\n", 20)
      written_bytes = omni_write_sovereign_executable(output_filepath, elf_res.ew_bytes)
      sys_write(1, "[8] Sovereign done\n", 19)
      @if written_bytes <= 0
        println("FAILED TO WRITE SOVEREIGN UNIVERSAL BINARY")
        return {
          cr_success: 0,
          cr_out_path: output_filepath,
          cr_file_size: 0,
          cr_entry_vaddr: 0,
          cr_tokens_count: tokens.len(),
          cr_ast_count: ast.len(),
          cr_ir_funcs: ir_mod.functions.len(),
          cr_error_msg: "Failed to write Sovereign Universal Binary"
        }
      @end
      println(str_concat("Sovereign Universal Binary successfully generated: ", output_filepath))
      return {
        cr_success: 1,
        cr_out_path: output_filepath,
        cr_file_size: written_bytes,
        cr_entry_vaddr: elf_res.ew_entry_vaddr,
        cr_tokens_count: tokens.len(),
        cr_ast_count: ast.len(),
        cr_ir_funcs: ir_mod.functions.len(),
        cr_error_msg: ""
      }
    @end
  @end

  return {
    cr_success: 1,
    cr_out_path: output_filepath,
    cr_file_size: elf_res.ew_file_size,
    cr_entry_vaddr: elf_res.ew_entry_vaddr,
    cr_tokens_count: tokens.len(),
    cr_ast_count: ast.len(),
    cr_ir_funcs: ir_mod.functions.len(),
    cr_error_msg: ""
  }
@end

@! Compiles Maya source file into standalone Linux ELF64 binary with options
@fn compile_file_with_options(input_filepath, output_filepath, options) 
 
  src = file_read(input_filepath)
  @if src == 0 || compiler_str_eq(src, "") == 1
    return {
      cr_success: 0,
      cr_out_path: output_filepath,
      cr_file_size: 0,
      cr_entry_vaddr: 0,
      cr_tokens_count: 0,
      cr_ast_count: 0,
      cr_ir_funcs: 0,
      cr_error_msg: str_concat("I/O Error: Cannot read source file or file is empty: ", input_filepath)
    }
  @end

  file_dir = get_dir_of_filepath(input_filepath)
  opts = options
  @if opts == 0
    opts = {
      opt_dump_tokens: 0,
      opt_dump_ast: 0,
      opt_dump_ir: 0,
      opt_dump_asm: 0,
      opt_module_name: "maya_program",
      opt_opt_level: 0,
      opt_base_dir: file_dir
    }
  @else
    opts.opt_base_dir = file_dir
  @end

  return compile_source_with_options(src, output_filepath, opts)
@end

@! Compiles Maya source code string directly to ELF binary; returns 1 on success, 0 on failure
@fn compile_source_to_elf(source_code, output_filepath)
  res = compile_source_with_options(source_code, output_filepath, 0)
  @if res.cr_success == 1
    return 1
  @end
  return 0
@end

@! Compiles Maya source file path directly to ELF binary; returns 1 on success, 0 on failure
@fn compile_file_to_elf(input_filepath, output_filepath)
  src = file_read(input_filepath)
  @if src == 0 || compiler_str_eq(src, "") == 1
    return 0
  @end
  return compile_source_to_elf(src, output_filepath)
@end


@fn main(argc, argv)
  @if argc < 2
    println("Usage: maya_univ <input.maya> [-o output_binary] [--sovereign] [--elf]")
    return 1
  @end
  
  input_file = argv[1]
  output_file = "a.out"
  backend_mode = 3
  dump_ast = 0
  dump_tok = 0
  
  arg_i = 2
  @while arg_i < argc
    @if str_eq(argv[arg_i], "-o") == 1
      arg_i = arg_i + 1
      @if arg_i < argc
        output_file = argv[arg_i]
      @end
    @end
    @if str_eq(argv[arg_i], "--elf") == 1
      backend_mode = 1
    @end
    @if str_eq(argv[arg_i], "--sovereign") == 1
      backend_mode = 3
    @end
    @if str_eq(argv[arg_i], "--dump-ast") == 1
      dump_ast = 1
    @end
    @if str_eq(argv[arg_i], "--dump-tokens") == 1
      dump_tok = 1
    @end
    arg_i = arg_i + 1
  @end
  
  println("Maya Sovereign Universal Compiler v2026")
  
  options = {
    backend: backend_mode,
    opt_dump_ast: dump_ast,
    opt_dump_tokens: dump_tok
  }
  
  compile_file_with_options(input_file, output_file, options)
  println("Compilation Finished Successfully!")
  return 0
@end
