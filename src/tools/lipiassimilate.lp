@! ============================================================================
@! 👑 LIPI UNIVERSAL CODE ASSIMILATOR & TRANSPILER: lipiassimilate
@! Module: src/tools/lipiassimilate.lp
@! 100% Pure Lipi Implementation — Zero External / C / Python Dependencies
@! Transpiles Legacy Python & C Source Code into 100% Sovereign Lipi 2.0
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. LEXICAL & STRING HELPERS
@! ----------------------------------------------------------------------------

@fn assimilator_is_space(c)
  return c == 32 || c == 9
@end

@fn assimilator_indent_count(line)
  @! WHY: Measures indentation level (4 spaces = 1 level, 1 tab = 1 level)
  n = str_len(line)
  i = 0
  spaces = 0
  @while i < n
    c = str_char_at(line, i)
    @if c == 32
      spaces = spaces + 1
    @elif c == 9
      spaces = spaces + 4
    @else
      break
    @end
    i = i + 1
  @end
  return spaces / 4
@end

@fn assimilator_trim(line)
  n = str_len(line)
  @if n == 0 return "" @end
  start = 0
  @while start < n && assimilator_is_space(str_char_at(line, start)) == 1
    start = start + 1
  @end
  @if start >= n return "" @end
  finish = n - 1
  @while finish >= start && assimilator_is_space(str_char_at(line, finish)) == 1
    finish = finish - 1
  @end
  return str_substr(line, start, finish + 1)
@end

@fn assimilator_strip_trailing_punct(line)
  @! WHY: Strips trailing ':', ';', or '{' characters common in Python/C blocks
  n = str_len(line)
  @if n == 0 return "" @end
  last_c = str_char_at(line, n - 1)
  @if last_c == 58 || last_c == 59 || last_c == 123
    @! 58=':', 59=';', 123='{'
    return assimilator_trim(str_substr(line, 0, n - 1))
  @end
  return line
@end

@fn assimilator_starts_with(line, prefix)
  p_len = str_len(prefix)
  l_len = str_len(line)
  @if l_len < p_len return 0 @end
  sub = str_substr(line, 0, p_len)
  @if str_eq(sub, prefix) == 1 return 1 @end
  return 0
@end

@fn pop_array(arr)
  res = []
  i = 0
  n = arr.len() - 1
  @while i < n
    res = res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@fn make_indent(level)
  res = ""
  i = 0
  @while i < level
    res = str_concat(res, "  ")
    i = i + 1
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 2. LINE TRANSPILATION & INDENTATION-TO-BLOCK LOWERING
@! ----------------------------------------------------------------------------

@fn assimilate_source(src_text)
  @! WHY: Parses line-by-line, tracks indentation depth, and synthesizes Lipi AST/source
  lines = string_split(src_text, "\n")
  total_lines = lines.len()

  out_lines = []
  block_levels = []  @! Stack of active indent levels
  
  line_idx = 0
  @while line_idx < total_lines
    raw_line = lines[line_idx]
    trimmed = assimilator_trim(raw_line)

    @! Skip empty lines and comment lines (# in Python, // in C)
    @if str_len(trimmed) == 0 || assimilator_starts_with(trimmed, "#") == 1 || assimilator_starts_with(trimmed, "//") == 1
      line_idx = line_idx + 1
      continue
    @end

    curr_indent = assimilator_indent_count(raw_line)
    clean_content = assimilator_strip_trailing_punct(trimmed)

    @! C-Style block closure: standalone '}'
    @if str_eq(clean_content, "}") == 1
      @if block_levels.len() > 0
        closed_level = block_levels[block_levels.len() - 1]
        block_levels = pop_array(block_levels)
        out_lines = out_lines.push(str_concat(make_indent(closed_level), "@end"))
      @end
      line_idx = line_idx + 1
      continue
    @end

    is_elif_or_else = (str_eq(clean_content, "else") == 1) || (assimilator_starts_with(clean_content, "elif ") == 1) || (assimilator_starts_with(clean_content, "else if") == 1)

    @! Pop block levels: if current line is elif/else, do not pop the matching @if block
    @if is_elif_or_else == 1
      @while block_levels.len() > 0 && curr_indent < block_levels[block_levels.len() - 1]
        closed_level = block_levels[block_levels.len() - 1]
        block_levels = pop_array(block_levels)
        out_lines = out_lines.push(str_concat(make_indent(closed_level), "@end"))
      @end
    @else
      @while block_levels.len() > 0 && curr_indent <= block_levels[block_levels.len() - 1]
        closed_level = block_levels[block_levels.len() - 1]
        block_levels = pop_array(block_levels)
        out_lines = out_lines.push(str_concat(make_indent(closed_level), "@end"))
      @end
    @end

    lipi_stmt = ""

    @! Rule A: Python Function Definition: def name(args):
    @if assimilator_starts_with(clean_content, "def ") == 1
      rem = assimilator_trim(str_substr(clean_content, 4, str_len(clean_content)))
      lipi_stmt = str_concat("@fn ", rem)
      block_levels = block_levels.push(curr_indent)

    @! Rule B: C Function Definition: int name(a, b) or void name(...)
    @elif (assimilator_starts_with(clean_content, "int ") == 1 || assimilator_starts_with(clean_content, "void ") == 1) && str_contains(clean_content, "(") == 1 && str_contains(clean_content, "=") == 0
      prefix_len = 4
      @if assimilator_starts_with(clean_content, "void ") == 1
        prefix_len = 5
      @end
      rem = assimilator_trim(str_substr(clean_content, prefix_len, str_len(clean_content)))
      rem = str_replace(rem, "int ", "")
      rem = str_replace(rem, "void ", "")
      lipi_stmt = str_concat("@fn ", rem)
      block_levels = block_levels.push(curr_indent)

    @! Rule C: Conditionals (if, elif, else)
    @elif assimilator_starts_with(clean_content, "if ") == 1 || assimilator_starts_with(clean_content, "if(") == 1
      rem = clean_content
      @if assimilator_starts_with(clean_content, "if ") == 1
        rem = assimilator_trim(str_substr(clean_content, 3, str_len(clean_content)))
      @else
        rem = assimilator_trim(str_substr(clean_content, 2, str_len(clean_content)))
      @end
      @if assimilator_starts_with(rem, "(") == 1 && str_ends_with(rem, ")") == 1
        rem = str_substr(rem, 1, str_len(rem) - 1)
      @end
      lipi_stmt = str_concat("@if ", rem)
      block_levels = block_levels.push(curr_indent)

    @elif assimilator_starts_with(clean_content, "elif ") == 1
      rem = assimilator_trim(str_substr(clean_content, 5, str_len(clean_content)))
      lipi_stmt = str_concat("@elif ", rem)

    @elif str_eq(clean_content, "else") == 1
      lipi_stmt = "@else"

    @! Rule D: Loops (while)
    @elif assimilator_starts_with(clean_content, "while ") == 1 || assimilator_starts_with(clean_content, "while(") == 1
      rem = clean_content
      @if assimilator_starts_with(clean_content, "while ") == 1
        rem = assimilator_trim(str_substr(clean_content, 6, str_len(clean_content)))
      @else
        rem = assimilator_trim(str_substr(clean_content, 5, str_len(clean_content)))
      @end
      @if assimilator_starts_with(rem, "(") == 1 && str_ends_with(rem, ")") == 1
        rem = str_substr(rem, 1, str_len(rem) - 1)
      @end
      lipi_stmt = str_concat("@while ", rem)
      block_levels = block_levels.push(curr_indent)

    @! Rule E: Print Statements: print(...) -> println(...)
    @elif assimilator_starts_with(clean_content, "print(") == 1
      rem = str_substr(clean_content, 6, str_len(clean_content) - 1)
      lipi_stmt = str_concat("println(", str_concat(rem, ")"))

    @! Rule F: Return Statements
    @elif assimilator_starts_with(clean_content, "return") == 1
      lipi_stmt = clean_content

    @! Rule G: Variable Declarations / Assignments / Function Calls
    @else
      clean_assign = clean_content
      @if assimilator_starts_with(clean_assign, "int ") == 1
        clean_assign = str_substr(clean_assign, 4, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "let ") == 1
        clean_assign = str_substr(clean_assign, 4, str_len(clean_assign))
      @end

      @if str_contains(clean_assign, "True") == 1
        clean_assign = str_replace(clean_assign, "True", "1")
      @end
      @if str_contains(clean_assign, "False") == 1
        clean_assign = str_replace(clean_assign, "False", "0")
      @end

      lipi_stmt = clean_assign
    @end

    out_lines = out_lines.push(str_concat(make_indent(curr_indent), lipi_stmt))
    line_idx = line_idx + 1
  @end

  @! Close any remaining blocks
  @while block_levels.len() > 0
    closed_level = block_levels[block_levels.len() - 1]
    block_levels = pop_array(block_levels)
    out_lines = out_lines.push(str_concat(make_indent(closed_level), "@end"))
  @end

  return string_join(out_lines, "\n")
@end

@! ----------------------------------------------------------------------------
@! 3. FILE I/O & CLI RUNNER
@! ----------------------------------------------------------------------------

@fn assimilate_file(input_path, output_path)
  fd_in = sys_open(input_path, 0, 0)
  @if fd_in < 0
    return 0
  @end

  f_sz = sys_lseek(fd_in, 0, 2)
  sys_lseek(fd_in, 0, 0)

  raw_buf = sys_mmap(0, f_sz + 16, 3, 34, 0 - 1, 0)
  sys_read(fd_in, raw_buf, f_sz)
  sys_close(fd_in)

  src = ""
  i = 0
  @while i < f_sz
    b = sys_peek8(raw_buf + i) & 255
    src = str_concat(src, str_from_char_code(b))
    i = i + 1
  @end
  sys_munmap(raw_buf, f_sz + 16)

  lipi_code = assimilate_source(src)

  fd_out = sys_open(output_path, 577, 420)
  @if fd_out < 0
    return 0
  @end

  out_len = str_len(lipi_code)
  out_buf = sys_mmap(0, out_len + 16, 3, 34, 0 - 1, 0)
  j = 0
  @while j < out_len
    sys_poke8(out_buf + j, str_char_at(lipi_code, j) & 255)
    j = j + 1
  @end

  sys_write(fd_out, out_buf, out_len)
  sys_munmap(out_buf, out_len + 16)
  sys_close(fd_out)

  return out_len
@end

@fn main(argc, argv)
  @if argc < 2
    println("================================================================================")
    println("👑 LIPI UNIVERSAL CODE ASSIMILATOR & TRANSPILER (lipiassimilate)")
    println("================================================================================")
    println("Usage: lipiassimilate <input_file.py | input_file.c> [output_file.lp]")
    println("Transpiles Python & C control flow, recursion, and arithmetic into pure Lipi.")
    return 1
  @end

  in_path = argv[1]
  out_path = ""
  @if argc >= 3
    out_path = argv[2]
  @else
    out_path = str_concat(in_path, ".lp")
  @end

  println("👑 Transpiling legacy code to Sovereign Lipi 2.0...")
  println(str_concat("  • Source : ", in_path))
  println(str_concat("  • Target : ", out_path))

  nbytes = assimilate_file(in_path, out_path)
  @if nbytes > 0
    println(str_concat("✔ Successfully assimilated ", str_concat(to_str(nbytes), " bytes of canonical Lipi code!")))
    return 0
  @else
    println("❌ Error: Failed to assimilate source file.")
    return 1
  @end
@end
