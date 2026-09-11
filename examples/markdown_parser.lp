@! Markdown parser to ANSI/ASCII output
@! Parses # (H1), ## (H2), ** (bold), ` (code), and - (lists)

@fn parse_inline(line)
  out = ""
  i = 0
  len = str_len(line)
  in_bold = 0
  in_code = 0
  
  @while i < len
    matched = 0
    @if i + 1 < len
      c2 = str_substr(line, i, i + 2)
      @if c2 == "**"
        @if in_bold == 0
          out = out + "\x1b[1m"
          in_bold = 1
        @else
          out = out + "\x1b[0m"
          in_bold = 0
        @end
        i = i + 2
        matched = 1
      @end
    @end
    
    @if matched == 0
      c1 = str_substr(line, i, i + 1)
      @if c1 == "`"
        @if in_code == 0
          out = out + "\x1b[33m"
          in_code = 1
        @else
          out = out + "\x1b[0m"
          in_code = 0
        @end
        i = i + 1
        matched = 1
      @end
    @end
    
    @if matched == 0
      out = out + str_substr(line, i, i + 1)
      i = i + 1
    @end
  @end
  
  @! clean up any unclosed tags just in case
  @if in_bold == 1
    out = out + "\x1b[0m"
  @end
  @if in_code == 1
    out = out + "\x1b[0m"
  @end
  
  return out
@end

@fn parse_markdown(doc)
  len = str_len(doc)
  i = 0
  start_idx = 0
  
  @while i <= len
    is_eol = 0
    @if i == len
      is_eol = 1
    @elif str_substr(doc, i, i + 1) == "\n"
      is_eol = 1
    @end
    
    @if is_eol == 1
      line = str_substr(doc, start_idx, i)
      
      @if str_starts_with(line, "# ") == 1
        inner = str_substr(line, 2, str_len(line))
        println("\x1b[1;34m" + parse_inline(inner) + "\x1b[0m")
      @elif str_starts_with(line, "## ") == 1
        inner = str_substr(line, 3, str_len(line))
        println("\x1b[1;36m" + parse_inline(inner) + "\x1b[0m")
      @elif str_starts_with(line, "- ") == 1
        inner = str_substr(line, 2, str_len(line))
        println("\x1b[32m•\x1b[0m " + parse_inline(inner))
      @else
        println(parse_inline(line))
      @end
      
      start_idx = i + 1
    @end
    
    i = i + 1
  @end
@end

@fn main()
  println("=== Markdown Parser ===")
  
  doc = "# Maya Language\n"
  doc = doc + "\n"
  doc = doc + "Maya is a **statically typed** programming language.\n"
  doc = doc + "It has several cool features:\n"
  doc = doc + "\n"
  doc = doc + "## Features\n"
  doc = doc + "- **Type Inference** for simpler code\n"
  doc = doc + "- Built-in `str_substr` and strings\n"
  doc = doc + "- Structs and Enums\n"
  doc = doc + "\n"
  doc = doc + "## Examples\n"
  doc = doc + "You can define a struct using `@struct` and methods with `@impl`.\n"
  
  parse_markdown(doc)
  return 0
@end
