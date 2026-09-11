@! ============================================================================
@! MAYA STANDARD LIBRARY — FILE SYSTEM MODULE (std.fs)
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@! Reads the entire content of a file as a string
@fn read_file(path)
  return file_read(path)
@end

@! Writes content to a file, overwriting existing content
@fn write_file(path, content)
  return file_write(path, content)
@end

@! Checks if a file exists
@fn file_exists(path)
  content = file_read(path)
  @if content == "" || content == "none"
    return 0
  @end
  return 1
@end

@! Appends content to an existing file
@fn append_file(path, content)
  existing = file_read(path)
  @if existing == "none"
    existing = ""
  @end
  return file_write(path, existing + content)
@end

@! Reads a file and splits its contents into lines
@fn read_lines(path)
  content = file_read(path)
  lines = []
  len = content.len()
  curr_line = ""
  i = 0
  @while i < len
    ch = content[i]
    @if ch == "\n"
      lines = lines.push(curr_line)
      curr_line = ""
    @elif ch != "\r"
      curr_line = curr_line + ch
    @end
    i = i + 1
  @end
  @if curr_line.len() > 0
    lines = lines.push(curr_line)
  @end
  return lines
@end
