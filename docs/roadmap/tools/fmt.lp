@! ============================================================================
@! MAYA CODE FORMATTER & LINTER — tools/fmt.maya
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/fs"

@fn format_source_code(source_code)
  lines = string_split(source_code, "\n")
  formatted_lines = []
  indent_level = 0
  
  @for line in lines
    trimmed = string_trim(line)
    @if trimmed == ""
      formatted_lines = formatted_lines.push("")
    @else
      @if string_starts_with(trimmed, "@end") || string_starts_with(trimmed, "@elif") || string_starts_with(trimmed, "@else")
        @if indent_level > 0 indent_level = indent_level - 1 @end
      @end
      
      indent_str = string_repeat("  ", indent_level)
      formatted_lines = formatted_lines.push(indent_str + trimmed)
      
      @if string_starts_with(trimmed, "@fn") || string_starts_with(trimmed, "@if") || string_starts_with(trimmed, "@while") || string_starts_with(trimmed, "@for") || string_starts_with(trimmed, "@struct") || string_starts_with(trimmed, "@match") || string_starts_with(trimmed, "@elif") || string_starts_with(trimmed, "@else")
        indent_level = indent_level + 1
      @end
    @end
  @end
  
  return string_join(formatted_lines, "\n")
@end
