// @! RUN: %maya %file -o %out && %out
// @! EXPECT_CONTAINS: PASS: malformed directives recovery
// @! EXPECT_EXIT: 0

@infinity_rule "broken" => 
@infinity_rule
@infinity_rule 123 => ;
@custom_op "@@@" ;

@fn main()
  println("PASS: malformed directives recovery")
  return 0
@end
