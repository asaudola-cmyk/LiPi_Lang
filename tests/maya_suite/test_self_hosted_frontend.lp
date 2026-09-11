import "compiler/frontend/lexer"

@fn main()
  src = "@fn add(a, b)\n  return a + b\n@end\n"
  toks = tokenize_source(src)
  count = toks.len()
  println(count)
  
  @if count > 0
    println("[PASS] Pure Maya Self-Hosted Lexer successfully tokenized code!")
  @else
    println("[FAIL] Pure Maya Lexer failed")
  @end
  return 0
@end
