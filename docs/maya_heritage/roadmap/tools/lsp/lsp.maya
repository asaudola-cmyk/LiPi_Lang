@! ============================================================================
@! MAYA LANGUAGE SERVER PROTOCOL (LSP) ENGINE
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! LSP Workspace State
@fn lsp_workspace_new()
  return {
    files: {},
    symbol_table: [],
    diagnostics: []
  }
@end

@! Index symbols from a source string
@fn lsp_index_symbols(source_code)
  symbols = []
  lines = string_split(source_code, "\n")
  
  line_no = 0
  @for line in lines
    trimmed = string_trim(line)
    
    @if starts_with(trimmed, "@fn ")
      @! Extract function name
      name = string_substring_between(trimmed, "@fn ", "(")
      sym = { type: "Function", name: name, line: line_no }
      symbols = symbols.push(sym)
    @elif starts_with(trimmed, "@struct ")
      name = string_substring_between(trimmed, "@struct ", " ")
      sym = { type: "Struct", name: name, line: line_no }
      symbols = symbols.push(sym)
    @end
    
    line_no = line_no + 1
  @end
  
  return symbols
@end

@! Go To Definition logic
@fn lsp_go_to_definition(workspace, symbol_name)
  @for sym in workspace.symbol_table
    @if sym.name == symbol_name
      return { file: sym.file, line: sym.line }
    @end
  @end
  return { error: "Symbol not found" }
@end

@! Find References logic
@fn lsp_find_references(workspace, symbol_name)
  refs = []
  @! Deep scan ASTs in workspace
  return refs
@end

@fn lsp_index_of(s, substr, from_pos)
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

@fn string_substring_between(s, start_str, end_str)
  s_len = s.len()
  start_idx = 0
  @if start_str.len() > 0
    idx = lsp_index_of(s, start_str, 0)
    @if idx == 0 - 1
      return ""
    @end
    start_idx = idx + start_str.len()
  @end
  
  end_idx = s_len
  @if end_str.len() > 0
    idx2 = lsp_index_of(s, end_str, start_idx)
    @if idx2 != 0 - 1
      end_idx = idx2
    @end
  @end
  
  @if start_idx >= end_idx
    return ""
  @end
  return string_slice(s, start_idx, end_idx)
@end

