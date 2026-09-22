@! ============================================================================
@! MAYA ASSIMILATOR — C/C++ TO MAYA TRANSPILER (assimilator/c_cpp_parser.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: C/C++ AST/syntax parsing, type stripping, block normalization
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn c_index_of(s, substr, from_pos)
  s_len = s.len()
  sub_len = substr.len()
  @if sub_len == 0
    return from_pos
  @end
  @if from_pos + sub_len > s_len
    return 0 - 1
  @end
  i = from_pos
  @while i <= s_len - sub_len
    @if match_sub_at(s, i, substr) == 1
      return i
    @end
    i = i + 1
  @end
  return 0 - 1
@end

@fn c_substring_between(s, start_str, end_str)
  s_len = s.len()
  start_idx = 0
  @if start_str.len() > 0
    idx = c_index_of(s, start_str, 0)
    @if idx == 0 - 1
      return ""
    @end
    start_idx = idx + start_str.len()
  @end
  
  end_idx = s_len
  @if end_str.len() > 0
    idx2 = c_index_of(s, end_str, start_idx)
    @if idx2 != 0 - 1
      end_idx = idx2
    @end
  @end
  
  @if start_idx >= end_idx
    return ""
  @end
  return string_slice(s, start_idx, end_idx)
@end

@fn c_is_type_keyword(word)
  @if word == "int" || word == "float" || word == "double" || word == "char"
    return 1
  @end
  @if word == "bool" || word == "void" || word == "long" || word == "short"
    return 1
  @end
  @if word == "unsigned" || word == "signed" || word == "size_t" || word == "auto"
    return 1
  @end
  @if word == "const" || word == "static" || word == "inline"
    return 1
  @end
  @if word == "int32_t" || word == "int64_t" || word == "uint32_t" || word == "uint64_t"
    return 1
  @end
  return 0
@end

@fn c_clean_param(p_str)
  trimmed = string_trim(p_str)
  @if string_is_empty(trimmed) == 1
    return ""
  @end
  
  parts = string_split(trimmed, " ")
  last_part = parts[parts.len() - 1]
  
  @! Strip leading pointer asterisks or reference ampersands
  clean_name = ""
  i = 0
  len = last_part.len()
  @while i < len
    ch = last_part[i]
    @if ch != "*" && ch != "&"
      clean_name = clean_name + ch
    @end
    i = i + 1
  @end
  return string_trim(clean_name)
@end

@fn c_clean_param_list(params_str)
  trimmed = string_trim(params_str)
  @if string_is_empty(trimmed) == 1 || trimmed == "void"
    return ""
  @end
  
  raw_params = string_split(trimmed, ",")
  clean_params = []
  i = 0
  len = raw_params.len()
  @while i < len
    p = c_clean_param(raw_params[i])
    @if string_is_empty(p) == 0
      clean_params = clean_params.push(p)
    @end
    i = i + 1
  @end
  
  return join(clean_params, ", ")
@end

@fn c_strip_semicolon(s)
  trimmed = string_trim(s)
  @if ends_with(trimmed, ";") == 1
    return string_slice(trimmed, 0, trimmed.len() - 1)
  @end
  return trimmed
@end

@fn c_clean_expr(expr)
  res = expr
  res = c_strip_semicolon(res)
  res = string_replace(res, "printf(", "println(")
  res = string_replace(res, "std::cout << ", "println(")
  res = string_replace(res, "NULL", "none")
  res = string_replace(res, "nullptr", "none")
  res = string_replace(res, "true", "1")
  res = string_replace(res, "false", "0")
  return res
@end

@fn c_strip_type_decl(stmt)
  trimmed = string_trim(stmt)
  words = string_split(trimmed, " ")
  @if words.len() >= 2 && c_is_type_keyword(words[0]) == 1
    @! If first word is type keyword, strip it
    second_idx = 1
    @while second_idx < words.len() && c_is_type_keyword(words[second_idx]) == 1
      second_idx = second_idx + 1
    @end
    
    remaining = []
    i = second_idx
    @while i < words.len()
      remaining = remaining.push(words[i])
      i = i + 1
    @end
    return join(remaining, " ")
  @end
  return trimmed
@end

@fn c_transpile_to_maya(source_str)
  @! Pre-process: standardize braces to newlines
  normalized = source_str
  normalized = string_replace(normalized, "{", "\n{\n")
  normalized = string_replace(normalized, "}", "\n}\n")
  normalized = string_replace(normalized, ";", ";\n")
  
  lines = string_split(normalized, "\n")
  output_lines = []
  
  i = 0
  num_lines = lines.len()
  
  @while i < num_lines
    raw_line = lines[i]
    trimmed = string_trim(raw_line)
    
    @if string_is_empty(trimmed) == 1
      i = i + 1
    @elif starts_with(trimmed, "//") == 1
      comment = string_slice(trimmed, 2, trimmed.len())
      output_lines = output_lines.push("@!" + comment)
      i = i + 1
    @elif trimmed == "{"
      @! Opening brace, handled by construct
      i = i + 1
    @elif trimmed == "}"
      @! Closing brace
      output_lines = output_lines.push("@end")
      i = i + 1
    @else
      @! Check for function definition: contains '(' and ')'
      has_paren_open = contains(trimmed, "(")
      has_paren_close = contains(trimmed, ")")
      
      @if has_paren_open == 1 && has_paren_close == 1 && starts_with(trimmed, "if") == 0 && starts_with(trimmed, "while") == 0 && starts_with(trimmed, "for") == 0 && starts_with(trimmed, "switch") == 0 && starts_with(trimmed, "return") == 0
        @! Parse function header: [type] name(params)
        before_paren = ""
        inside_paren = ""
        
        paren_pos = 0
        @while paren_pos < trimmed.len() && trimmed[paren_pos] != "("
          before_paren = before_paren + trimmed[paren_pos]
          paren_pos = paren_pos + 1
        @end
        
        paren_pos = paren_pos + 1
        @while paren_pos < trimmed.len() && trimmed[paren_pos] != ")"
          inside_paren = inside_paren + trimmed[paren_pos]
          paren_pos = paren_pos + 1
        @end
        
        header_words = string_split(string_trim(before_paren), " ")
        fn_name = header_words[header_words.len() - 1]
        
        @! Strip pointer prefix from fn_name if any
        clean_fn_name = ""
        fi = 0
        @while fi < fn_name.len()
          @if fn_name[fi] != "*"
            clean_fn_name = clean_fn_name + fn_name[fi]
          @end
          fi = fi + 1
        @end
        
        clean_params = c_clean_param_list(inside_paren)
        output_lines = output_lines.push("@fn " + clean_fn_name + "(" + clean_params + ")")
        
      @! If statement: if (cond)
      @elif starts_with(trimmed, "if") == 1
        cond = c_substring_between(trimmed, "(", ")")
        output_lines = output_lines.push("@if " + c_clean_expr(cond))
        
      @! Else if statement: else if (cond)
      @elif starts_with(trimmed, "else if") == 1
        cond = c_substring_between(trimmed, "(", ")")
        output_lines = output_lines.push("@elif " + c_clean_expr(cond))
        
      @! Else statement
      @elif trimmed == "else"
        output_lines = output_lines.push("@else")
        
      @! While loop: while (cond)
      @elif starts_with(trimmed, "while") == 1
        cond = c_substring_between(trimmed, "(", ")")
        output_lines = output_lines.push("@while " + c_clean_expr(cond))
        
      @! Return statement: return expr;
      @elif starts_with(trimmed, "return") == 1
        stmt = c_strip_semicolon(trimmed)
        expr = string_trim(string_slice(stmt, 6, stmt.len()))
        @if string_is_empty(expr) == 1
          output_lines = output_lines.push("  return")
        @else
          output_lines = output_lines.push("  return " + c_clean_expr(expr))
        @end
        
      @! General statement / variable declaration
      @else
        stmt = c_strip_semicolon(trimmed)
        stmt = c_strip_type_decl(stmt)
        output_lines = output_lines.push("  " + c_clean_expr(stmt))
      @end
      
      i = i + 1
    @end
  @end
  
  return join(output_lines, "\n") + "\n"
@end
