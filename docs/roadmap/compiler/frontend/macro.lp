@! ============================================================================
@! MAYA COMPILER STAGE 1 — ADVANCED MACRO SYSTEM
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! Represents a Macro Definition
@fn macro_def_new(name, args, body_tokens)
  return {
    name: name,
    args: args,
    body: body_tokens
  }
@end

@! The Macro Expander state
@fn macro_expander_new()
  return {
    macros: []
  }
@end

@! Register a new macro
@fn macro_register(expander, def)
  expander.macros = expander.macros.push(def)
  return expander
@end

@! Expand a macro invocation
@fn macro_expand(expander, macro_name, call_args)
  @! Find the macro
  target_macro = 0
  @for m in expander.macros
    @if m.name == macro_name
      target_macro = m
    @end
  @end
  
  @if target_macro == 0
    return { error: "Macro not found" }
  @end
  
  @! Map arguments
  arg_map = { entries: [] }
  idx = 0
  @for arg_name in target_macro.args
    @if idx < call_args.len()
      arg_map_set(arg_map, arg_name, call_args[idx])
    @end
    idx = idx + 1
  @end
  
  @! Substitute tokens
  expanded_tokens = []
  @for token in target_macro.body
    tok_name = ""
    @if token.val != 0 && token.val != "none"
      tok_name = token.val
    @elif token.value != 0 && token.value != "none"
      tok_name = token.value
    @elif token.name != 0 && token.name != "none"
      tok_name = token.name
    @end
    
    @if token.type == "Identifier" || token.type == "IDENT" || token.kind == "Variable"
      @! Check if it's a macro argument
      val = arg_map_get(arg_map, tok_name)
      @if val != 0
        expanded_tokens = expanded_tokens.push(val)
      @else
        expanded_tokens = expanded_tokens.push(token)
      @end
    @else
      expanded_tokens = expanded_tokens.push(token)
    @end
  @end
  
  return expanded_tokens
@end

@! Helper for map operations
@fn arg_map_set(map, key, val)
  new_entries = []
  found = 0
  @for e in map.entries
    @if e.key == key
      new_entries = new_entries.push({ key: key, val: val })
      found = 1
    @else
      new_entries = new_entries.push(e)
    @end
  @end
  @if found == 0
    new_entries = new_entries.push({ key: key, val: val })
  @end
  map.entries = new_entries
  return map
@end

@fn arg_map_get(map, key)
  @for e in map.entries
    @if e.key == key
      return e.val
    @end
  @end
  return 0
@end
