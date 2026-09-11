@! ============================================================================
@! MAYA CLI: INTERACTIVE REPL
@! Module: cmd/repl/main
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct CompletionCandidate
  val: string,
  kind: string
@end

@struct Repl
  history: array,
  variables: array,
  functions: array,
  keywords: array,
  is_running: i64
@end

@fn repl_new() -> Repl
  return Repl {
    history: [],
    variables: ["x", "my_var"],
    functions: ["print", "println", "str_len"],
    keywords: ["@fn", "@struct", "@impl", "@if", "@while", "@for", "@end", "return"],
    is_running: 1
  }
@end

@fn repl_eval(repl: Repl, input: string) -> string
  trimmed = string_trim(input)
  @if trimmed == ":quit" || trimmed == ":q"
    repl.is_running = 0
    return "Goodbye!"
  @elif trimmed == ":help"
    return "Maya REPL Help:\n  :quit, :q     Exit REPL\n  :help         Show this help"
  @end
  return "=> " + trimmed
@end

@fn repl_get_completions(repl: Repl, prefix: string) -> array
  candidates = []
  i = 0
  len_k = repl.keywords.len()
  @while i < len_k
    k = repl.keywords[i]
    @if string_starts_with(k, prefix)
      candidates = candidates.push(CompletionCandidate { val: k, kind: "keyword" })
    @end
    i = i + 1
  @end
  return candidates
@end

@fn main()
  println("Welcome to Maya REPL v1.0.0 (canonical)")
  repl = repl_new()
  res = repl_eval(repl, "1 + 1")
  println(res)
  return 0
@end
