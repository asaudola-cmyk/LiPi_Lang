@! ============================================================================
@! MAYA FMT — String formatting utilities
@! ============================================================================

@fn fmt_int(n, width)
  s = int_to_str(n)
  @while str_len(s) < width
    s = " " + s
  @end
  return s
@end

@fn fmt_left(s, width)
  @while str_len(s) < width
    s = s + " "
  @end
  return s
@end

@fn fmt_right(s, width)
  @while str_len(s) < width
    s = " " + s
  @end
  return s
@end

@fn fmt_repeat(s, n)
  result = ""
  i = 0
  @while i < n
    result = result + s
    i = i + 1
  @end
  return result
@end

@fn fmt_separator(width)
  return fmt_repeat("-", width)
@end

@fn fmt_box(title, width)
  top = "+" + fmt_repeat("-", width - 2) + "+"
  padding = width - 2 - str_len(title)
  left_pad = padding / 2
  right_pad = padding - left_pad
  middle = "|" + fmt_repeat(" ", left_pad) + title + fmt_repeat(" ", right_pad) + "|"
  println(top)
  println(middle)
  println(top)
@end

@fn fmt_table_row(cols, widths)
  row = "|"
  i = 0
  @while i < cols.len()
    col = cols[i]
    w = widths[i]
    row = row + " " + fmt_left(col, w) + " |"
    i = i + 1
  @end
  return row
@end

@fn fmt_bytes(n)
  @if n < 1024
    return int_to_str(n) + " B"
  @end
  @if n < 1024 * 1024
    return int_to_str(n / 1024) + " KB"
  @end
  @if n < 1024 * 1024 * 1024
    return int_to_str(n / (1024 * 1024)) + " MB"
  @end
  return int_to_str(n / (1024 * 1024 * 1024)) + " GB"
@end

@fn fmt_duration_ms(ms)
  @if ms < 1000
    return int_to_str(ms) + "ms"
  @end
  @if ms < 60000
    return int_to_str(ms / 1000) + "s"
  @end
  return int_to_str(ms / 60000) + "m " + int_to_str((ms % 60000) / 1000) + "s"
@end

@fn fmt_percent(n, total)
  @if total == 0
    return "0%"
  @end
  return int_to_str(n * 100 / total) + "%"
@end
