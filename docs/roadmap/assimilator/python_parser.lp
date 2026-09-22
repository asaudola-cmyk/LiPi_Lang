@! ============================================================================
@! MAYA ASSIMILATOR — PYTHON TO MAYA TRANSPILER (assimilator/python_parser.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Python AST/syntax parsing, indentation analysis, keyword mapping
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn py_list_pop(arr)
  len = arr.len()
  @if len <= 1
    return []
  @end
  res = []
  i = 0
  @while i < len - 1
    res = res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@fn py_count_indent(line)
  len = line.len()
  count = 0
  i = 0
  @while i < len
    ch = line[i]
    @if ch == " "
      count = count + 1
    @elif ch == "\t"
      count = count + 4
    @else
      return count
    @end
    i = i + 1
  @end
  return count
@end

@fn py_translate_expr(expr)
  res = expr
  res = string_replace(res, "True", "1")
  res = string_replace(res, "False", "0")
  res = string_replace(res, "None", "none")
  res = string_replace(res, " and ", " && ")
  res = string_replace(res, " or ", " || ")
  res = string_replace(res, "print(", "println(")
  return res
@end

@fn py_strip_colon(s)
  trimmed = string_trim(s)
  @if ends_with(trimmed, ":") == 1
    return string_slice(trimmed, 0, trimmed.len() - 1)
  @end
  return trimmed
@end

@fn py_transpile_to_maya(source_str)
  lines = string_split(source_str, "\n")
  output_lines = []
  
  indent_stack = [0]
  block_stack = []
  
  i = 0
  num_lines = lines.len()
  
  @while i < num_lines
    raw_line = lines[i]
    trimmed = string_trim(raw_line)
    
    @if string_is_empty(trimmed) == 1
      i = i + 1
    @else
      curr_indent = py_count_indent(raw_line)
      
      @! Close blocks when indent decreases
      @while indent_stack.len() > 1 && curr_indent < indent_stack[indent_stack.len() - 1]
        indent_stack = py_list_pop(indent_stack)
        block_stack = py_list_pop(block_stack)
        output_lines = output_lines.push("@end")
      @end
      
      @! Comments
      @if starts_with(trimmed, "#") == 1
        comment_text = string_slice(trimmed, 1, trimmed.len())
        output_lines = output_lines.push("@!" + comment_text)
        
      @! Function definitions: def func_name(args):
      @elif starts_with(trimmed, "def ") == 1
        fn_header = py_strip_colon(trimmed)
        fn_decl = string_slice(fn_header, 4, fn_header.len())
        output_lines = output_lines.push("@fn " + fn_decl)
        indent_stack = indent_stack.push(curr_indent + 4)
        block_stack = block_stack.push("fn")
        
      @! If statement: if cond:
      @elif starts_with(trimmed, "if ") == 1
        cond = py_strip_colon(string_slice(trimmed, 3, trimmed.len()))
        output_lines = output_lines.push("@if " + py_translate_expr(cond))
        indent_stack = indent_stack.push(curr_indent + 4)
        block_stack = block_stack.push("if")
        
      @! Elif statement: elif cond:
      @elif starts_with(trimmed, "elif ") == 1
        cond = py_strip_colon(string_slice(trimmed, 5, trimmed.len()))
        output_lines = output_lines.push("@elif " + py_translate_expr(cond))
        
      @! Else statement: else:
      @elif trimmed == "else:" || trimmed == "else"
        output_lines = output_lines.push("@else")
        
      @! While loop: while cond:
      @elif starts_with(trimmed, "while ") == 1
        cond = py_strip_colon(string_slice(trimmed, 6, trimmed.len()))
        output_lines = output_lines.push("@while " + py_translate_expr(cond))
        indent_stack = indent_stack.push(curr_indent + 4)
        block_stack = block_stack.push("while")
        
      @! For loop: for var in iterable:
      @elif starts_with(trimmed, "for ") == 1
        for_stmt = py_strip_colon(string_slice(trimmed, 4, trimmed.len()))
        output_lines = output_lines.push("@for " + py_translate_expr(for_stmt))
        indent_stack = indent_stack.push(curr_indent + 4)
        block_stack = block_stack.push("for")
        
      @! Return statement
      @elif starts_with(trimmed, "return ") == 1
        expr = string_slice(trimmed, 7, trimmed.len())
        output_lines = output_lines.push("  return " + py_translate_expr(expr))
      @elif trimmed == "return"
        output_lines = output_lines.push("  return")
        
      @! Pass / Break / Continue
      @elif trimmed == "pass"
        output_lines = output_lines.push("  @! pass")
      @elif trimmed == "break"
        output_lines = output_lines.push("  break")
      @elif trimmed == "continue"
        output_lines = output_lines.push("  continue")
        
      @! General statements / assignments
      @else
        output_lines = output_lines.push("  " + py_translate_expr(trimmed))
      @end
      
      i = i + 1
    @end
  @end
  
  @! Close remaining open blocks at EOF
  @while indent_stack.len() > 1
    indent_stack = py_list_pop(indent_stack)
    output_lines = output_lines.push("@end")
  @end
  
  return join(output_lines, "\n") + "\n"
@end
