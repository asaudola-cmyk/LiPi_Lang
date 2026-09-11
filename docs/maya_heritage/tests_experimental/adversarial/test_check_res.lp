import "compiler/infinity_syntax"

@fn main()
  res = infinity_syntax_self_test()
  println("res is: " + res.to_str())
  return 0
@end
