@! ============================================================================
@! 👑 LIPI UNIVERSAL CODE ASSIMILATOR & TRANSPILER: lipiassimilate
@! Module: src/tools/lipiassimilate.lp
@! 100% Pure Lipi Implementation — Zero External / C / Python Dependencies
@! Transpiles Legacy Python & C Source Code into 100% Sovereign Lipi First 1.0.0
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

@fn assimilator_clean_expr(expr)
  // WHY: Normalizes legacy boolean literals and NULL pointers into canonical Lipi integer values
  res = expr
  @if str_contains(res, "True") == 1
    res = str_replace(res, "True", "1")
  @end
  @if str_contains(res, "False") == 1
    res = str_replace(res, "False", "0")
  @end
  @if str_contains(res, "None") == 1
    res = str_replace(res, "None", "0")
  @end
  @if str_contains(res, "NULL") == 1
    res = str_replace(res, "NULL", "0")
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
    @elif (assimilator_starts_with(clean_content, "int ") == 1 || assimilator_starts_with(clean_content, "void ") == 1 || assimilator_starts_with(clean_content, "long ") == 1 || assimilator_starts_with(clean_content, "char* ") == 1) && str_contains(clean_content, "(") == 1 && str_contains(clean_content, "=") == 0
      prefix_len = 4
      @if assimilator_starts_with(clean_content, "void ") == 1
        prefix_len = 5
      @elif assimilator_starts_with(clean_content, "long ") == 1
        prefix_len = 5
      @elif assimilator_starts_with(clean_content, "char* ") == 1
        prefix_len = 6
      @end
      rem = assimilator_trim(str_substr(clean_content, prefix_len, str_len(clean_content)))
      rem = str_replace(rem, "int ", "")
      rem = str_replace(rem, "void ", "")
      rem = str_replace(rem, "void", "")
      rem = str_replace(rem, "char* ", "")
      rem = str_replace(rem, "char *", "")
      rem = str_replace(rem, "long ", "")
      rem = str_replace(rem, "float ", "")
      rem = str_replace(rem, "double ", "")
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
      rem = assimilator_clean_expr(rem)
      lipi_stmt = str_concat("@if ", rem)
      block_levels = block_levels.push(curr_indent)

    @elif assimilator_starts_with(clean_content, "elif ") == 1
      rem = assimilator_trim(str_substr(clean_content, 5, str_len(clean_content)))
      rem = assimilator_clean_expr(rem)
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
      rem = assimilator_clean_expr(rem)
      lipi_stmt = str_concat("@while ", rem)
      block_levels = block_levels.push(curr_indent)

    @! Rule E: Print Statements: print(...) / printf(...) -> println(...)
    @elif assimilator_starts_with(clean_content, "print(") == 1
      rem = str_substr(clean_content, 6, str_len(clean_content) - 1)
      rem = assimilator_clean_expr(rem)
      lipi_stmt = str_concat("println(", str_concat(rem, ")"))

    @elif assimilator_starts_with(clean_content, "printf(") == 1
      rem = str_substr(clean_content, 7, str_len(clean_content) - 1)
      rem = assimilator_clean_expr(rem)
      lipi_stmt = str_concat("println(", str_concat(rem, ")"))

    @! Rule F: Return Statements
    @elif assimilator_starts_with(clean_content, "return") == 1
      lipi_stmt = assimilator_clean_expr(clean_content)

    @! Rule G: Variable Declarations / Assignments / Function Calls
    @else
      clean_assign = clean_content
      @if assimilator_starts_with(clean_assign, "int ") == 1
        clean_assign = str_substr(clean_assign, 4, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "long ") == 1
        clean_assign = str_substr(clean_assign, 5, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "char* ") == 1
        clean_assign = str_substr(clean_assign, 6, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "char ") == 1
        clean_assign = str_substr(clean_assign, 5, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "float ") == 1
        clean_assign = str_substr(clean_assign, 6, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "double ") == 1
        clean_assign = str_substr(clean_assign, 7, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "let ") == 1
        clean_assign = str_substr(clean_assign, 4, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "auto ") == 1
        clean_assign = str_substr(clean_assign, 5, str_len(clean_assign))
      @elif assimilator_starts_with(clean_assign, "const ") == 1
        clean_assign = str_substr(clean_assign, 6, str_len(clean_assign))
      @end

      clean_assign = assimilator_clean_expr(clean_assign)
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

@fn assimilator_exec(cmd_path, arg1, arg2, arg3)
  // WHY: Native process spawn via Linux syscalls 57 (fork), 59 (execve), and 61 (wait4) with zero libc
  argv = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  sys_poke(argv + 0, cmd_path)
  idx = 1
  @if str_len(arg1) > 0
    sys_poke(argv + (idx * 8), arg1)
    idx = idx + 1
  @end
  @if str_len(arg2) > 0
    sys_poke(argv + (idx * 8), arg2)
    idx = idx + 1
  @end
  @if str_len(arg3) > 0
    sys_poke(argv + (idx * 8), arg3)
    idx = idx + 1
  @end
  sys_poke(argv + (idx * 8), 0)

  st = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke(st, 0)

  pid = sys_fork()
  @if pid == 0
    sys_execve(cmd_path, argv, 0)
    sys_exit(127)
  @end

  sys_wait4(pid, st, 0, 0)
  raw_st = sys_peek(st)
  exit_code = (raw_st / 256) & 255

  sys_munmap(argv, 64)
  sys_munmap(st, 8)
  return exit_code
@end

@fn main()
  args = argv()
  argc = len(args)

  @if argc < 2
    println("================================================================================")
    println("👑 LIPI UNIVERSAL CODE ASSIMILATOR & TRANSPILER (lipiassimilate)")
    println("================================================================================")
    println("Usage: lipiassimilate <input_file.py | input_file.c> [-o output.lp] [--run]")
    println("Transpiles Python & C control flow, recursion, and arithmetic into pure Lipi.")
    return 1
  @end

  in_path = ""
  out_path = ""
  run_after = 0

  i = 1
  @while i < argc
    a = args[i]
    @if str_eq(a, "--run") == 1
      run_after = 1
    @elif str_eq(a, "-o") == 1
      i = i + 1
      @if i < argc
        out_path = args[i]
      @end
    @elif str_len(in_path) == 0
      in_path = a
    @else
      @if str_len(out_path) == 0
        out_path = a
      @end
    @end
    i = i + 1
  @end

  @if str_len(in_path) == 0
    println("❌ Error: No input file specified.")
    return 1
  @end

  @if str_len(out_path) == 0
    out_path = str_concat(in_path, ".lp")
  @end

  println("👑 Transpiling legacy code to Sovereign Lipi First 1.0.0...")
  println(str_concat("  • Source : ", in_path))
  println(str_concat("  • Target : ", out_path))

  nbytes = assimilate_file(in_path, out_path)
  @if nbytes <= 0
    println("❌ Error: Failed to assimilate source file.")
    return 1
  @end

  println(str_concat("✔ Successfully assimilated ", str_concat(to_str(nbytes), " bytes of canonical Lipi code!")))

  @if run_after == 1
    tmp_bin = str_concat(out_path, ".bin")
    println(str_concat("⚙️ Compiling assimilated source to ELF64: ", tmp_bin))
    c_status = assimilator_exec("./bin/lipc_bin", out_path, "-o", tmp_bin)
    @if c_status != 0
      println("❌ Compilation of assimilated code failed.")
      return 1
    @end
    println("🚀 Executing assimilated binary on bare silicon:")
    println("──────────────────────────────────────────────────────────────────────")
    r_status = assimilator_exec(tmp_bin, "", "", "")
    println("──────────────────────────────────────────────────────────────────────")
    sys_unlink(tmp_bin)
    return r_status
  @end

  return 0
@end
