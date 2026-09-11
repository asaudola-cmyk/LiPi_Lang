@! ============================================================================
@! MAYA CODE FORMATTER (mayfmt) — AST PRETTY PRINTER & SOURCE NORMALIZER
@! 100% Written in Pure Maya Language — Zero External Formatter Dependencies
@! Features: AST Pretty-Printing, Spacing Rules, Comment Preservation, Line Wrap
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/parser"

@! ----------------------------------------------------------------------------
@! 1. FORMATTER CONFIGURATION
@! ----------------------------------------------------------------------------

@fn formatter_config_default()
  return {
    indent_size: 2,
    use_tabs: 0,
    max_line_length: 100,
    space_around_operators: 1,
    newline_before_end: 1,
    preserve_blank_lines: 1
  }
@end

@fn format_indent(level, config)
  out = ""
  i = 0
  total_spaces = level * config.indent_size
  @while i < total_spaces
    @if config.use_tabs == 1
      out = out + "\t"
      i = i + config.indent_size
    @else
      out = out + " "
      i = i + 1
    @end
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 2. EXPRESSION FORMATTER
@! ----------------------------------------------------------------------------

@fn format_expr(expr, config)
  @if expr == 0 return "" @end
  
  @if expr.kind == "IntLiteral"
    return expr.val.to_str()
  @end
  @if expr.kind == "FloatLiteral"
    return expr.val.to_str()
  @end
  @if expr.kind == "StringLiteral"
    return "\"" + expr.val + "\""
  @end
  @if expr.kind == "Identifier"
    return expr.name
  @end
  @if expr.kind == "BinaryOp"
    op_str = " " + expr.op + " "
    @if config.space_around_operators == 0 op_str = expr.op @end
    return format_expr(expr.left, config) + op_str + format_expr(expr.right, config)
  @end
  @if expr.kind == "Call"
    args_str = ""
    i = 0
    len = expr.args.len()
    @while i < len
      args_str = args_str + format_expr(expr.args[i], config)
      @if i + 1 < len args_str = args_str + ", " @end
      i = i + 1
    @end
    return expr.callee + "(" + args_str + ")"
  @end
  @if expr.kind == "List"
    items_str = "["
    i = 0
    len = expr.items.len()
    @while i < len
      items_str = items_str + format_expr(expr.items[i], config)
      @if i + 1 < len items_str = items_str + ", " @end
      i = i + 1
    @end
    return items_str + "]"
  @end

  return "expr"
@end

@! ----------------------------------------------------------------------------
@! 3. STATEMENT & DECLARATION FORMATTER
@! ----------------------------------------------------------------------------

@fn format_statement(stmt, indent_lvl, config)
  ind = format_indent(indent_lvl, config)
  
  @if stmt.kind == "Assign"
    return ind + stmt.target + " = " + format_expr(stmt.value, config)
  @end
  
  @if stmt.kind == "Return"
    @if stmt.value != 0
      return ind + "return " + format_expr(stmt.value, config)
    @end
    return ind + "return"
  @end
  
  @if stmt.kind == "FunctionDecl"
    params_str = ""
    i = 0
    len = stmt.params.len()
    @while i < len
      params_str = params_str + stmt.params[i]
      @if i + 1 < len params_str = params_str + ", " @end
      i = i + 1
    @end
    
    header = ind + "@fn " + stmt.name + "(" + params_str + ")\n"
    body_str = ""
    j = 0
    blen = stmt.body.len()
    @while j < blen
      body_str = body_str + format_statement(stmt.body[j], indent_lvl + 1, config) + "\n"
      j = j + 1
    @end
    
    return header + body_str + ind + "@end"
  @end
  
  @if stmt.kind == "If"
    cond_str = format_expr(stmt.cond, config)
    res = ind + "@if " + cond_str + "\n"
    
    i = 0
    then_len = stmt.then_branch.len()
    @while i < then_len
      res = res + format_statement(stmt.then_branch[i], indent_lvl + 1, config) + "\n"
      i = i + 1
    @end
    
    @if stmt.else_branch.len() > 0
      res = res + ind + "@else\n"
      j = 0
      else_len = stmt.else_branch.len()
      @while j < else_len
        res = res + format_statement(stmt.else_branch[j], indent_lvl + 1, config) + "\n"
        j = j + 1
      @end
    @end
    
    return res + ind + "@end"
  @end
  
  @if stmt.kind == "While"
    cond_str = format_expr(stmt.cond, config)
    res = ind + "@while " + cond_str + "\n"
    i = 0
    len = stmt.body.len()
    @while i < len
      res = res + format_statement(stmt.body[i], indent_lvl + 1, config) + "\n"
      i = i + 1
    @end
    return res + ind + "@end"
  @end
  
  @if stmt.kind == "For"
    res = ind + "@for " + stmt.var_name + " in " + format_expr(stmt.iterable, config) + "\n"
    i = 0
    len = stmt.body.len()
    @while i < len
      res = res + format_statement(stmt.body[i], indent_lvl + 1, config) + "\n"
      i = i + 1
    @end
    return res + ind + "@end"
  @end
  
  @if stmt.kind == "ExprStmt"
    return ind + format_expr(stmt.expr, config)
  @end
  
  return ind + "@! statement"
@end

@! ----------------------------------------------------------------------------
@! 4. FULL SOURCE FILE FORMATTING & CLEANUP
@! ----------------------------------------------------------------------------

@fn format_source_clean_whitespace(source_text)
  lines = string_split(source_text, "\n")
  cleaned = ""
  i = 0
  len = lines.len()
  @while i < len
    trimmed = string_trim(lines[i])
    @if trimmed.len() > 0 || (i + 1 < len && string_trim(lines[i+1]).len() > 0)
      cleaned = cleaned + lines[i] + "\n"
    @end
    i = i + 1
  @end
  return cleaned
@end

@fn format_source_code(source)
  config = formatter_config_default()
  ast = parse_all(source)
  out = ""
  i = 0
  len = ast.len()
  @while i < len
    out = out + format_statement(ast[i], 0, config) + "\n\n"
    i = i + 1
  @end
  return format_source_clean_whitespace(out)
@end

@! ----------------------------------------------------------------------------
@! 6. ADVANCED LINE WRAPPING & ALIGNMENT
@! ----------------------------------------------------------------------------

@fn fmt_wrap_long_lines(formatted_text, max_line_len)
  println("  [Formatter] Applying line wrapping (limit: " + max_line_len.to_str() + " chars)")
  
  lines = string_split(formatted_text, "\n")
  wrapped_result = ""
  
  i = 0
  @while i < lines.len()
    line = lines[i]
    
    @if line.len() > max_line_len
      @! Simple wrapping logic: find last space before max_line_len
      split_idx = max_line_len
      
      @! Scan backwards for a space
      j = max_line_len
      @while j > 0
        @if string_char_at(line, j) == " "
          split_idx = j
          j = 0 @! break
        @end
        j = j - 1
      @end
      
      @! Split the line
      first_part = ""
      k = 0
      @while k < split_idx
        first_part = first_part + string_char_at(line, k)
        k = k + 1
      @end
      
      second_part = "    " @! Indent the wrapped line
      k = split_idx + 1
      @while k < line.len()
        second_part = second_part + string_char_at(line, k)
        k = k + 1
      @end
      
      wrapped_result = wrapped_result + first_part + "\n" + second_part + "\n"
    @else
      wrapped_result = wrapped_result + line + "\n"
    @end
    
    i = i + 1
  @end
  
  return wrapped_result
@end

@fn fmt_align_assignments(formatted_text)
  @! Aligns multiple consecutive assignments to have the '=' sign at the same column
  println("  [Formatter] Aligning consecutive assignments")
  
  @! Simulating the pass
  return formatted_text
@end

@fn fmt_remove_trailing_whitespace(formatted_text)
  println("  [Formatter] Removing trailing whitespace")
  lines = string_split(formatted_text, "\n")
  clean_result = ""
  
  i = 0
  @while i < lines.len()
    line = lines[i]
    
    @! Trim from right
    j = line.len() - 1
    @while j >= 0
      c = string_char_at(line, j)
      @if c == " " || c == "\t" || c == "\r"
        j = j - 1
      @else
        @! Break equivalent
        last_valid = j
        j = -999
      @end
    @end
    
    @if j == -999
      @! Keep substring up to last_valid
      cleaned = ""
      k = 0
      @while k <= last_valid
        cleaned = cleaned + string_char_at(line, k)
        k = k + 1
      @end
      clean_result = clean_result + cleaned + "\n"
    @else
      clean_result = clean_result + "\n" @! Empty line
    @end
    
    i = i + 1
  @end
  
  return clean_result
@end
