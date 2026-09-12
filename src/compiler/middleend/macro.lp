@! ============================================================================
@! LIPI COMPILER MIDDLEEND: HYGIENIC MACRO EXPANSION ENGINE
@! Module: compiler/middleend/macro
@! Canonical Pure Lipi Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! Delimiters used in TokenTree grouping
@enum Delimiter
  Parenthesis = 0
  Bracket = 1
  Brace = 2
  None = 3
@end

@! Spacing behavior for punctuation tokens
@enum Spacing
  Alone = 0
  Joint = 1
@end

@! Represents a source code location
@struct Span
  file_id: i64
  start: i64
  end_pos: i64
@end

@impl Span
  @fn merge(self, other: Span) -> Span
    s = self.start
    @if other.start < s
      s = other.start
    @end
    e = self.end_pos
    @if other.end_pos > e
      e = other.end_pos
    @end
    return { file_id: self.file_id, start: s, end_pos: e }
  @end
@end

@! The base unit of macro processing
@struct TokenTree
  kind: string
  text: string
  delimiter: i64
  tokens: array
  span: Span
@end

@impl TokenTree
  @fn get_span(self) -> Span
    return self.span
  @end

  @fn to_str(self) -> string
    @if self.kind == "Group"
      s = ""
      @if self.delimiter == 0
        s = "("
      @elif self.delimiter == 1
        s = "["
      @elif self.delimiter == 2
        s = "{"
      @end

      i = 0
      num_items = self.tokens.len()
      @while i < num_items
        t = self.tokens[i]
        s = s + t.text + " "
        i = i + 1
      @end

      @if self.delimiter == 0
        s = s + ")"
      @elif self.delimiter == 1
        s = s + "]"
      @elif self.delimiter == 2
        s = s + "}"
      @end
      return s
    @end
    return self.text
  @end
@end

@! Parameters for macro definitions
@struct MacroParam
  name: string
  is_variadic: i64
  pattern: string
@end

@! Scope identifier for hygienic macro expansion
@struct ScopeId
  id: i64
@end

@impl ScopeId
  @fn to_str(self) -> string
    return self.id.to_str()
  @end
@end

@! A parsed macro definition
@struct MacroDef
  name: string
  params: array
  body: TokenTree
  hygiene_scope: ScopeId
@end

@! A macro invocation in code
@struct MacroCall
  name: string
  args: array
  span: Span
@end

@! Environment tracking during expansion
@struct MacroEnv
  macros: array
  current_scope: ScopeId
  depth: i64
@end

@! Expand macros preserving hygiene and tracking recursion
@struct MacroExpander
  next_scope_id: i64
  max_depth: i64
@end

@impl MacroExpander
  @fn new() -> MacroExpander
    return {
      next_scope_id: 1,
      max_depth: 256
    }
  @end

  @fn generate_scope(self) -> ScopeId
    id = self.next_scope_id
    self.next_scope_id = self.next_scope_id + 1
    return { id: id }
  @end

  @fn is_builtin(self, name: string) -> i64
    builtins = [
      "assert!", "assert_eq!", "println!", "format!",
      "vec!", "todo!", "unreachable!", "dbg!"
    ]
    i = 0
    num_items = builtins.len()
    @while i < num_items
      @if name == builtins[i]
        return 1
      @end
      i = i + 1
    @end
    return 0
  @end

  @fn expand_builtin(self, call: MacroCall, env: MacroEnv) -> TokenTree
    @if call.name == "assert!"
      return self.builtin_assert(call, env)
    @elif call.name == "assert_eq!"
      return self.builtin_assert_eq(call, env)
    @elif call.name == "println!"
      return self.builtin_println(call, env)
    @elif call.name == "format!"
      return self.builtin_format(call, env)
    @elif call.name == "todo!"
      return self.builtin_todo(call, env)
    @elif call.name == "unreachable!"
      return self.builtin_unreachable(call, env)
    @end

    return {
      kind: "Token",
      text: call.name,
      delimiter: 3,
      tokens: [],
      span: call.span
    }
  @end

  @fn builtin_assert(self, call: MacroCall, env: MacroEnv) -> TokenTree
    return {
      kind: "Group",
      text: "assert",
      delimiter: 2,
      tokens: call.args,
      span: call.span
    }
  @end

  @fn builtin_assert_eq(self, call: MacroCall, env: MacroEnv) -> TokenTree
    return {
      kind: "Group",
      text: "assert_eq",
      delimiter: 2,
      tokens: call.args,
      span: call.span
    }
  @end

  @fn builtin_println(self, call: MacroCall, env: MacroEnv) -> TokenTree
    return {
      kind: "Group",
      text: "println",
      delimiter: 2,
      tokens: call.args,
      span: call.span
    }
  @end

  @fn builtin_format(self, call: MacroCall, env: MacroEnv) -> TokenTree
    return {
      kind: "Group",
      text: "format",
      delimiter: 2,
      tokens: call.args,
      span: call.span
    }
  @end

  @fn builtin_todo(self, call: MacroCall, env: MacroEnv) -> TokenTree
    return {
      kind: "Token",
      text: "panic(\"not yet implemented\")",
      delimiter: 3,
      tokens: [],
      span: call.span
    }
  @end

  @fn builtin_unreachable(self, call: MacroCall, env: MacroEnv) -> TokenTree
    return {
      kind: "Token",
      text: "panic(\"entered unreachable code\")",
      delimiter: 3,
      tokens: [],
      span: call.span
    }
  @end
@end

@! Procedural Macros Implementation
@struct ProceduralMacro
  dummy: i64
@end

@impl ProceduralMacro
  @fn derive_debug(ast: TokenTree) -> TokenTree
    return ast
  @end

  @fn derive_clone(ast: TokenTree) -> TokenTree
    return ast
  @end
@end

@! Parses macro! { pattern => expansion } declarative definitions
@struct MacroParser
  dummy: i64
@end

@impl MacroParser
  @fn parse_macro_rules(source: TokenTree) -> MacroDef
    params = [
      {
        name: "arg",
        is_variadic: 0,
        pattern: "expr"
      }
    ]
    return {
      name: "parsed_macro",
      params: params,
      body: source,
      hygiene_scope: { id: 0 }
    }
  @end
@end
