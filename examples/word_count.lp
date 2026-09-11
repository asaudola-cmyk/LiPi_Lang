@! Word counter and text analyzer in Maya

@fn count_chars(text)
  return str_len(text)
@end

@fn count_words(text)
  count = 0
  in_word = 0
  i = 0
  @while i < str_len(text)
    c = char_at(text, i)
    @if c == 32 || c == 10 || c == 9
      @if in_word == 1
        count = count + 1
        in_word = 0
      @end
    @else
      in_word = 1
    @end
    i = i + 1
  @end
  @if in_word == 1
    count = count + 1
  @end
  return count
@end

@fn count_lines(text)
  count = 1
  i = 0
  @while i < str_len(text)
    @if char_at(text, i) == 10
      count = count + 1
    @end
    i = i + 1
  @end
  return count
@end

@fn most_common_char(text)
  counts = []
  i = 0
  @while i < 128
    counts = counts.push(0)
    i = i + 1
  @end
  i = 0
  @while i < str_len(text)
    code = char_at(text, i)
    @if code >= 0 && code < 128
      counts[code] = counts[code] + 1
    @end
    i = i + 1
  @end
  max_count = 0
  max_char = 32
  i = 33
  @while i < 128
    @if counts[i] > max_count
      max_count = counts[i]
      max_char = i
    @end
    i = i + 1
  @end
  return max_char
@end

@fn main()
  text = "Maya is the Universe. Maya is free.\nMaya karo help ney na.\nMaya r help sobai ney. Even C."
  
  println("=== Maya Word Counter ===")
  println("")
  println("Text: " + text)
  println("")
  println("Statistics:")
  println("  Characters: " + int_to_str(count_chars(text)))
  println("  Words: " + int_to_str(count_words(text)))
  println("  Lines: " + int_to_str(count_lines(text)))
  println("  Most common char code: " + int_to_str(most_common_char(text)))
  println("  Contains 'Maya': " + int_to_str(str_contains(text, "Maya")))
  println("  Uppercase: " + str_upper(text))
  return 0
@end
