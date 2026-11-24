@! ============================================================================
@! 👑 LIPI UNIVERSAL CODE ASSIMILATOR & TRANSPILER: lipiassimilate
@! Module: src/tools/lipiassimilate.lp
@! 100% Pure Lipi Implementation — Zero External / C / Python Dependencies
@! Transpiles Legacy Python & C Source Code into 100% Sovereign Lipi First 1.0.0
@! ============================================================================

import "utso/syscalls"
import "utso/string"
import "utso/collections"

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
  return spaces
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

@fn _assim_is_ident_byte(b)
  @if (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || (b >= 48 && b <= 57) || b == 95 || b >= 128
    return 1
  @end
  return 0
@end

@fn assimilator_clean_expr(expr)
  // WHY: Normalizes boolean/null literals at identifier boundaries ONLY outside string literals.
  res = ""
  n = str_len(expr)
  i = 0
  in_str = 0
  @while i < n
    c = str_char_at(expr, i) & 255
    @if in_str == 1
      res = str_concat(res, str_substr(expr, i, i + 1))
      @if c == 92 && i + 1 < n
        res = str_concat(res, str_substr(expr, i + 1, i + 2))
        i = i + 2
        continue
      @end
      @if c == 34
        in_str = 0
      @end
      i = i + 1
      continue
    @end
    @if c == 34
      in_str = 1
      res = str_concat(res, "\"")
      i = i + 1
      continue
    @end
    @if _assim_is_ident_byte(c) == 1
      start_i = i
      @while i < n && _assim_is_ident_byte(str_char_at(expr, i) & 255) == 1
        i = i + 1
      @end
      tok = str_substr(expr, start_i, i)
      @if str_eq(tok, "True") == 1 || str_eq(tok, "true") == 1
        res = str_concat(res, "1")
      @elif str_eq(tok, "False") == 1 || str_eq(tok, "false") == 1 || str_eq(tok, "None") == 1 || str_eq(tok, "NULL") == 1 || str_eq(tok, "null") == 1
        res = str_concat(res, "0")
      @else
        res = str_concat(res, tok)
      @end
    @else
      res = str_concat(res, str_substr(expr, i, i + 1))
      i = i + 1
    @end
  @end
  return res
@end

@fn _assim_pop_step(steps_arr)
  out = []
  i = 0
  @while i < steps_arr.len() - 1
    out = out.push(steps_arr[i])
    i = i + 1
  @end
  return out
@end

@fn assimilate_source(src_text)
  lines = string_split(src_text, "\n")
  total_lines = lines.len()

  out_lines = []
  block_levels = []
  block_steps = []
  block_is_brace = []

  line_idx = 0
  @while line_idx < total_lines
    raw_line = lines[line_idx]
    trimmed = assimilator_trim(raw_line)

    @if str_len(trimmed) == 0 || assimilator_starts_with(trimmed, "#") == 1 || assimilator_starts_with(trimmed, "//") == 1
      line_idx = line_idx + 1
      continue
    @end

    curr_indent = assimilator_indent_count(raw_line)
    has_open_brace = str_ends_with(trimmed, "{")
    clean_content = assimilator_strip_trailing_punct(trimmed)

    @! C-Style block closure: standalone '}'
    @if str_eq(clean_content, "}") == 1
      @if block_levels.len() > 0
        closed_level = block_levels[block_levels.len() - 1]
        closed_step = block_steps[block_steps.len() - 1]
        block_levels = pop_array(block_levels)
        block_steps = _assim_pop_step(block_steps)
        block_is_brace = pop_array(block_is_brace)
        out_depth = block_levels.len()
        @if str_len(closed_step) > 0
          out_lines = out_lines.push(str_concat(make_indent(out_depth + 1), closed_step))
        @end
        out_lines = out_lines.push(str_concat(make_indent(out_depth), "@end"))
      @end
      line_idx = line_idx + 1
      continue
    @end

    @! Strip leading '} else if' / '} else' safely
    @if assimilator_starts_with(clean_content, "} else") == 1
      clean_content = assimilator_trim(str_substr(clean_content, 1, str_len(clean_content)))
    @end

    is_elif_or_else = (str_eq(clean_content, "else") == 1) || (assimilator_starts_with(clean_content, "elif ") == 1) || (assimilator_starts_with(clean_content, "else if") == 1)

    @if is_elif_or_else == 1
      @while block_levels.len() > 0 && block_is_brace[block_is_brace.len() - 1] == 0 && curr_indent < block_levels[block_levels.len() - 1]
        closed_level = block_levels[block_levels.len() - 1]
        closed_step = block_steps[block_steps.len() - 1]
        block_levels = pop_array(block_levels)
        block_steps = _assim_pop_step(block_steps)
        block_is_brace = pop_array(block_is_brace)
        out_depth = block_levels.len()
        @if str_len(closed_step) > 0
          out_lines = out_lines.push(str_concat(make_indent(out_depth + 1), closed_step))
        @end
        out_lines = out_lines.push(str_concat(make_indent(out_depth), "@end"))
      @end
    @else
      @while block_levels.len() > 0 && block_is_brace[block_is_brace.len() - 1] == 0 && curr_indent <= block_levels[block_levels.len() - 1]
        closed_level = block_levels[block_levels.len() - 1]
        closed_step = block_steps[block_steps.len() - 1]
        block_levels = pop_array(block_levels)
        block_steps = _assim_pop_step(block_steps)
        block_is_brace = pop_array(block_is_brace)
        out_depth = block_levels.len()
        @if str_len(closed_step) > 0
          out_lines = out_lines.push(str_concat(make_indent(out_depth + 1), closed_step))
        @end
        out_lines = out_lines.push(str_concat(make_indent(out_depth), "@end"))
      @end
    @end

    stmt_depth = block_levels.len()
    lipi_stmt = ""

    @! Rule A: Python def
    @if assimilator_starts_with(clean_content, "def ") == 1
      rem = assimilator_trim(str_substr(clean_content, 4, str_len(clean_content)))
      lipi_stmt = str_concat("@fn ", rem)
      block_levels = block_levels.push(curr_indent)
      block_steps = block_steps.push("")
      block_is_brace = block_is_brace.push(has_open_brace)

    @! Rule B: C fn
    @elif (assimilator_starts_with(clean_content, "int ") == 1 || assimilator_starts_with(clean_content, "void ") == 1 || assimilator_starts_with(clean_content, "long ") == 1 || assimilator_starts_with(clean_content, "char* ") == 1) && str_contains(clean_content, "(") == 1 && str_contains(clean_content, "=") == 0
      prefix_len = 4
      @if assimilator_starts_with(clean_content, "void ") == 1 || assimilator_starts_with(clean_content, "long ") == 1
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
      block_steps = block_steps.push("")
      block_is_brace = block_is_brace.push(has_open_brace)

    @! Rule C: Conditionals (if, else if, elif, else)
    @elif assimilator_starts_with(clean_content, "else if") == 1
      rem = assimilator_trim(str_substr(clean_content, 7, str_len(clean_content)))
      @if assimilator_starts_with(rem, "(") == 1 && str_ends_with(rem, ")") == 1
        rem = str_substr(rem, 1, str_len(rem) - 1)
      @end
      lipi_stmt = str_concat("@elif ", assimilator_clean_expr(rem))
      @if stmt_depth > 0
        stmt_depth = stmt_depth - 1
      @end

    @elif assimilator_starts_with(clean_content, "if ") == 1 || assimilator_starts_with(clean_content, "if(") == 1
      rem = assimilator_trim(str_substr(clean_content, 2, str_len(clean_content)))
      @if assimilator_starts_with(rem, "(") == 1 && str_ends_with(rem, ")") == 1
        rem = str_substr(rem, 1, str_len(rem) - 1)
      @end
      lipi_stmt = str_concat("@if ", assimilator_clean_expr(rem))
      block_levels = block_levels.push(curr_indent)
      block_steps = block_steps.push("")
      block_is_brace = block_is_brace.push(has_open_brace)

    @elif assimilator_starts_with(clean_content, "elif ") == 1
      rem = assimilator_trim(str_substr(clean_content, 5, str_len(clean_content)))
      lipi_stmt = str_concat("@elif ", assimilator_clean_expr(rem))
      @if stmt_depth > 0
        stmt_depth = stmt_depth - 1
      @end

    @elif str_eq(clean_content, "else") == 1
      lipi_stmt = "@else"
      @if stmt_depth > 0
        stmt_depth = stmt_depth - 1
      @end

    @! Rule D: Loops (while, C for, Python for)
    @elif assimilator_starts_with(clean_content, "while ") == 1 || assimilator_starts_with(clean_content, "while(") == 1
      rem = assimilator_trim(str_substr(clean_content, 5, str_len(clean_content)))
      @if assimilator_starts_with(rem, "(") == 1 && str_ends_with(rem, ")") == 1
        rem = str_substr(rem, 1, str_len(rem) - 1)
      @end
      lipi_stmt = str_concat("@while ", assimilator_clean_expr(rem))
      block_levels = block_levels.push(curr_indent)
      block_steps = block_steps.push("")
      block_is_brace = block_is_brace.push(has_open_brace)

    @elif assimilator_starts_with(clean_content, "for ") == 1 || assimilator_starts_with(clean_content, "for(") == 1
      rem = assimilator_trim(str_substr(clean_content, 3, str_len(clean_content)))
      @if assimilator_starts_with(rem, "(") == 1 && str_ends_with(rem, ")") == 1
        inner = str_substr(rem, 1, str_len(rem) - 1)
        parts = string_split(inner, ";")
        @if parts.len() == 3
          f_init = assimilator_trim(parts[0])
          @if assimilator_starts_with(f_init, "int ") == 1 f_init = str_substr(f_init, 4, str_len(f_init)) @end
          f_cond = assimilator_clean_expr(assimilator_trim(parts[1]))
          f_step = assimilator_trim(parts[2])
          @if str_ends_with(f_step, "++") == 1
            vn = assimilator_trim(str_substr(f_step, 0, str_len(f_step) - 2))
            f_step = str_concat(vn, str_concat(" = ", str_concat(vn, " + 1")))
          @elif str_ends_with(f_step, "--") == 1
            vn = assimilator_trim(str_substr(f_step, 0, str_len(f_step) - 2))
            f_step = str_concat(vn, str_concat(" = ", str_concat(vn, " - 1")))
          @end
          @if str_len(f_init) > 0
            out_lines = out_lines.push(str_concat(make_indent(stmt_depth), assimilator_clean_expr(f_init)))
          @end
          lipi_stmt = str_concat("@while ", f_cond)
          block_levels = block_levels.push(curr_indent)
          block_steps = block_steps.push(assimilator_clean_expr(f_step))
          block_is_brace = block_is_brace.push(has_open_brace)
        @else
          lipi_stmt = str_concat("@for ", assimilator_clean_expr(inner))
          block_levels = block_levels.push(curr_indent)
          block_steps = block_steps.push("")
          block_is_brace = block_is_brace.push(has_open_brace)
        @end
      @else
        lipi_stmt = str_concat("@for ", assimilator_clean_expr(rem))
        block_levels = block_levels.push(curr_indent)
        block_steps = block_steps.push("")
        block_is_brace = block_is_brace.push(has_open_brace)
      @end

    @! Rule E: Print Statements
    @elif assimilator_starts_with(clean_content, "print(") == 1
      rem = str_substr(clean_content, 6, str_len(clean_content) - 1)
      lipi_stmt = str_concat("println(", str_concat(assimilator_clean_expr(rem), ")"))

    @elif assimilator_starts_with(clean_content, "printf(") == 1
      rem = str_substr(clean_content, 7, str_len(clean_content) - 1)
      lipi_stmt = str_concat("println(", str_concat(assimilator_clean_expr(rem), ")"))

    @! Rule F: Return
    @elif assimilator_starts_with(clean_content, "return") == 1
      lipi_stmt = assimilator_clean_expr(clean_content)

    @! Rule G: Declarations / Assignments / Calls
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
      lipi_stmt = assimilator_clean_expr(clean_assign)
    @end

    out_lines = out_lines.push(str_concat(make_indent(stmt_depth), lipi_stmt))
    line_idx = line_idx + 1
  @end

  @while block_levels.len() > 0
    closed_level = block_levels[block_levels.len() - 1]
    closed_step = block_steps[block_steps.len() - 1]
    block_levels = pop_array(block_levels)
    block_steps = _assim_pop_step(block_steps)
    block_is_brace = pop_array(block_is_brace)
    out_depth = block_levels.len()
    @if str_len(closed_step) > 0
      out_lines = out_lines.push(str_concat(make_indent(out_depth + 1), closed_step))
    @end
    out_lines = out_lines.push(str_concat(make_indent(out_depth), "@end"))
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
    sys_exit_group(127)
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
    comp_bin = "./bin/lipc"
    @if sys_access("./bin/lipc_bin", 0) == 0
      comp_bin = "./bin/lipc_bin"
    @end
    c_status = assimilator_exec(comp_bin, out_path, "-o", tmp_bin)
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
