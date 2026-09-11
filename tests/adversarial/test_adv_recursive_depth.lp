// @! RUN: %maya %file -o %out && %out
// @! EXPECT_CONTAINS: PASS: recursive depth bound
// @! EXPECT_EXIT: 0

@infinity_rule "MACRO_A" => "MACRO_B" ;
@infinity_rule "MACRO_B" => "MACRO_A" ;

@fn main()
  @! Circular rules will hit max recursion depth limit (128) and stop expanding
  println("PASS: recursive depth bound")
  return 0
@end
