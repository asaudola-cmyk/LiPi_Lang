@! ============================================================================
@! MAYA ASSIMILATOR — JAVASCRIPT / TYPESCRIPT TO MAYA TRANSPILER
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: JS/TS syntax parsing, type stripping, arrow fn conversion, console.log
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn js_index_of(s, substr, from_pos)
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

@fn js_substring_between(s, start_str, end_str)
  s_len = s.len()
  start_idx = 0
  @if start_str.len() > 0
    idx = js_index_of(s, start_str, 0)
    @if idx == 0 - 1
      return ""
    @end
    start_idx = idx + start_str.len()
  @end
  
  end_idx = s_len
  @if end_str.len() > 0
    idx2 = js_index_of(s, end_str, start_idx)
    @if idx2 != 0 - 1
      end_idx = idx2
    @end
  @end
  
  @if start_idx >= end_idx
    return ""
  @end
  return string_slice(s, start_idx, end_idx)
@end

@fn js_clean_param(p_str)
  trimmed = string_trim(p_str)
  @if string_is_empty(trimmed) == 1
    return ""
  @end
  
  @! Strip TypeScript type annotation: param: Type
  name_part = trimmed
  @if contains(trimmed, ":") == 1
    parts = string_split(trimmed, ":")
    name_part = parts[0]
  @end
  
  @! Strip default value: param = val
  @if contains(name_part, "=") == 1
    parts2 = string_split(name_part, "=")
    name_part = parts2[0]
  @end
  
  return string_trim(name_part)
@end

@fn js_clean_param_list(params_str)
  trimmed = string_trim(params_str)
  @if string_is_empty(trimmed) == 1
    return ""
  @end
  
  raw_params = string_split(trimmed, ",")
  clean_params = []
  i = 0
  len = raw_params.len()
  @while i < len
    p = js_clean_param(raw_params[i])
    @if string_is_empty(p) == 0
      clean_params = clean_params.push(p)
    @end
    i = i + 1
  @end
  
  return join(clean_params, ", ")
@end

@fn js_strip_semicolon(s)
  trimmed = string_trim(s)
  @if ends_with(trimmed, ";") == 1
    return string_slice(trimmed, 0, trimmed.len() - 1)
  @end
  return trimmed
@end

@fn js_clean_expr(expr)
  res = expr
  res = js_strip_semicolon(res)
  res = string_replace(res, "console.log(", "println(")
  res = string_replace(res, "console.error(", "println(")
  res = string_replace(res, "console.warn(", "println(")
  res = string_replace(res, "===", "==")
  res = string_replace(res, "!==", "!=")
  res = string_replace(res, "null", "none")
  res = string_replace(res, "undefined", "none")
  res = string_replace(res, "true", "1")
  res = string_replace(res, "false", "0")
  return res
@end

@fn js_clean_var_decl(stmt)
  trimmed = string_trim(stmt)
  res = trimmed
  @if starts_with(res, "let ") == 1
    res = string_slice(res, 4, res.len())
  @elif starts_with(res, "const ") == 1
    res = string_slice(res, 6, res.len())
  @elif starts_with(res, "var ") == 1
    res = string_slice(res, 4, res.len())
  @end
  
  @! Strip TS type in variable declaration: x: number = 10 -> x = 10
  @if contains(res, ":") == 1 && contains(res, "=") == 1
    eq_parts = string_split(res, "=")
    left_part = eq_parts[0]
    right_part = eq_parts[1]
    
    colon_parts = string_split(left_part, ":")
    clean_left = string_trim(colon_parts[0])
    res = clean_left + " = " + string_trim(right_part)
  @end
  
  return res
@end

@fn js_transpile_to_maya(source_str)
  @! Pre-process: standardize braces and semicolons to newlines
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
      i = i + 1
    @elif trimmed == "}"
      output_lines = output_lines.push("@end")
      i = i + 1
    @else
      @! Strip export keyword
      @if starts_with(trimmed, "export ") == 1
        trimmed = string_trim(string_slice(trimmed, 7, trimmed.len()))
      @end
      @if starts_with(trimmed, "async ") == 1
        trimmed = string_trim(string_slice(trimmed, 6, trimmed.len()))
      @end
      
      @! Function definition: function name(params) or function name(params): ret_type
      @if starts_with(trimmed, "function") == 1
        after_fn = string_trim(string_slice(trimmed, 8, trimmed.len()))
        fn_name = ""
        inside_paren = ""
        
        paren_pos = 0
        @while paren_pos < after_fn.len() && after_fn[paren_pos] != "("
          fn_name = fn_name + after_fn[paren_pos]
          paren_pos = paren_pos + 1
        @end
        
        paren_pos = paren_pos + 1
        @while paren_pos < after_fn.len() && after_fn[paren_pos] != ")"
          inside_paren = inside_paren + after_fn[paren_pos]
          paren_pos = paren_pos + 1
        @end
        
        fn_name = string_trim(fn_name)
        clean_params = js_clean_param_list(inside_paren)
        output_lines = output_lines.push("@fn " + fn_name + "(" + clean_params + ")")
        
      @! Arrow function: const name = (params) =>
      @elif contains(trimmed, "=>") == 1 && contains(trimmed, "(") == 1
        arrow_parts = string_split(trimmed, "=>")
        left_arrow = arrow_parts[0]
        
        fn_name = ""
        inside_paren = ""
        
        @if contains(left_arrow, "=") == 1
          eq_parts = string_split(left_arrow, "=")
          vdecl = js_clean_var_decl(eq_parts[0])
          fn_name = string_trim(vdecl)
          inside_paren = js_substring_between(eq_parts[1], "(", ")")
        @end
        
        clean_params = js_clean_param_list(inside_paren)
        output_lines = output_lines.push("@fn " + fn_name + "(" + clean_params + ")")
        
      @! If statement: if (cond)
      @elif starts_with(trimmed, "if") == 1
        cond = js_substring_between(trimmed, "(", ")")
        output_lines = output_lines.push("@if " + js_clean_expr(cond))
        
      @! Else if statement: else if (cond)
      @elif starts_with(trimmed, "else if") == 1
        cond = js_substring_between(trimmed, "(", ")")
        output_lines = output_lines.push("@elif " + js_clean_expr(cond))
        
      @! Else statement
      @elif trimmed == "else"
        output_lines = output_lines.push("@else")
        
      @! While loop: while (cond)
      @elif starts_with(trimmed, "while") == 1
        cond = js_substring_between(trimmed, "(", ")")
        output_lines = output_lines.push("@while " + js_clean_expr(cond))
        
      @! Return statement: return expr;
      @elif starts_with(trimmed, "return") == 1
        stmt = js_strip_semicolon(trimmed)
        expr = string_trim(string_slice(stmt, 6, stmt.len()))
        @if string_is_empty(expr) == 1
          output_lines = output_lines.push("  return")
        @else
          output_lines = output_lines.push("  return " + js_clean_expr(expr))
        @end
        
      @! Variable declaration or statement
      @else
        stmt = js_strip_semicolon(trimmed)
        stmt = js_clean_var_decl(stmt)
        output_lines = output_lines.push("  " + js_clean_expr(stmt))
      @end
      
      i = i + 1
    @end
  @end
  
  return join(output_lines, "\n") + "\n"
@end
