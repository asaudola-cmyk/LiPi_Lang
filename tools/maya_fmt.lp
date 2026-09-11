@! ============================================================================
@! MAYA CANONICAL CODE FORMATTER (tools/maya_fmt.maya)
@! Module = tools/maya_fmt.maya
@! Milestone = Milestone 1: Developer Experience & IDE Engine
@! 100% Pure Maya Implementation — Zero External / Libc Dependencies
@! Canonical style: 2 spaces per block indentation level
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Indentation & Spacing Helpers
@! ----------------------------------------------------------------------------

@fn fmt_make_indent(level)
  @! Produces a string with 2 spaces per indent level
  @! WHY: Canonical Maya indentation standard is strictly 2 spaces per block.
  res = ""
  i = 0
  @while i < level
    res = str_concat(res, "  ")
    i = i + 1
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 2. Canonical Formatter Core Logic
@! ----------------------------------------------------------------------------

@fn maya_fmt_format_source(source_code)
  @! Formats Maya source code line by line with 2-space canonical block indentation
  @! WHY: Pure freestanding implementation ensuring consistent formatting across all editors.
  lines = string_split(source_code, "\n")
  formatted_lines = []
  indent_level = 0
  i = 0
  n_lines = lines.len()

  @while i < n_lines
    raw_line = lines[i]
    trimmed = str_trim(raw_line)

    @if str_len(trimmed) == 0
      @! Blank lines are preserved without trailing whitespace
      formatted_lines = formatted_lines.push("")
    @else
      line_indent = indent_level

      @! If line starts with @end, dedent before outputting this line
      @if str_starts_with(trimmed, "@end") == 1
        @if indent_level > 0
          indent_level = indent_level - 1
        @end
        line_indent = indent_level
      @elif str_starts_with(trimmed, "@elif") == 1 || str_starts_with(trimmed, "@else") == 1
        @! Dedent by 1 level for this line only
        @if line_indent > 0
          line_indent = line_indent - 1
        @end
      @end

      indent_str = fmt_make_indent(line_indent)
      formatted_line = str_concat(indent_str, trimmed)
      formatted_lines = formatted_lines.push(formatted_line)

      @! If line starts with @fn, @struct, @if, @while, @for, increase indent for subsequent lines
      @! Single-line blocks containing @end on the same line are not indented further
      @if str_contains(trimmed, "@end") == 0
        is_block_start = 0
        @if str_starts_with(trimmed, "@fn") == 1
          is_block_start = 1
        @elif str_starts_with(trimmed, "@struct") == 1
          is_block_start = 1
        @elif str_starts_with(trimmed, "@if") == 1
          is_block_start = 1
        @elif str_starts_with(trimmed, "@while") == 1
          is_block_start = 1
        @elif str_starts_with(trimmed, "@for") == 1
          is_block_start = 1
        @end

        @if is_block_start == 1
          indent_level = indent_level + 1
        @end
      @end
    @end

    i = i + 1
  @end

  res = string_join(formatted_lines, "\n")
  @if str_len(res) > 0
    @if str_ends_with(res, "\n") == 0
      res = str_concat(res, "\n")
    @end
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 3. Freestanding File I/O Helpers
@! ----------------------------------------------------------------------------

@fn fmt_read_file(filepath)
  @! Reads an entire .maya source file using direct kernel syscalls
  fd = sys_open(filepath, 0, 0) @! O_RDONLY = 0
  @if fd < 0
    return ""
  @end
  max_sz = 10485760 @! 10MB limit for source files
  buf = sys_mmap(0, max_sz + 1, 3, 34, 0 - 1, 0)
  @if buf <= 0
    sys_close(fd)
    return ""
  @end
  n = sys_read(fd, buf, max_sz)
  sys_close(fd)
  @if n <= 0
    return ""
  @end
  sys_poke8(buf + n, 0)
  return buf
@end

@fn fmt_write_file(filepath, content)
  @! Writes content back to file using direct kernel syscalls
  @! Flags: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, Mode: 0644 (420) / 0755 (493)
  fd = sys_open(filepath, 577, 493)
  @if fd < 0
    return 0
  @end
  sz = str_len(content)
  @if sz > 0
    sys_write(fd, content, sz)
  @end
  sys_close(fd)
  return 1
@end

@! ----------------------------------------------------------------------------
@! 4. File Formatter Driver
@! ----------------------------------------------------------------------------

@fn maya_fmt_file(filepath, write_back)
  @! Formats a single Maya source file
  @! If write_back == 1, writes formatted content back to the file
  @! If write_back == 0, writes formatted content to stdout
  content = fmt_read_file(filepath)
  @if str_len(content) == 0
    println(str_concat("❌ Error: Cannot read or empty file: ", filepath))
    return 1
  @end

  formatted = maya_fmt_format_source(content)

  @if write_back == 1
    ok = fmt_write_file(filepath, formatted)
    @if ok == 1
      return 0
    @else
      println(str_concat("❌ Error: Failed writing to file: ", filepath))
      return 1
    @end
  @else
    @! Output cleanly to stdout
    sys_write(1, formatted, str_len(formatted))
    return 0
  @end
@end

@! ----------------------------------------------------------------------------
@! 5. Standalone CLI Entry Point
@! ----------------------------------------------------------------------------

@fn maya_fmt_cli(argc, argv)
  @if argc < 2
    println("Usage: maya fmt [-w] <file.maya>")
    return 1
  @end

  write_back = 0
  target_file = ""

  @if str_eq(argv[1], "-w") == 1
    @if argc < 3
      println("Usage: maya fmt [-w] <file.maya>")
      return 1
    @end
    write_back = 1
    target_file = argv[2]
  @else
    target_file = argv[1]
    @if argc >= 3 && str_eq(argv[2], "-w") == 1
      write_back = 1
    @end
  @end

  return maya_fmt_file(target_file, write_back)
@end
