// @! RUN: %maya %file -o %out && %out
// @! EXPECT_CONTAINS: PASS: simultaneous rules
// @! EXPECT_EXIT: 0

@infinity_rule "si" => "@if" ;
@infinity_rule "mientras" => "@while" ;
@infinity_rule "retornar" => "return" ;
@infinity_rule "fin" => "@end" ;

@fn test_logic(x)
  si x > 10
    retornar 100
  fin
  retornar 0
@end

@fn main()
  res = test_logic(20)
  @if res == 100
    println("PASS: simultaneous rules")
    return 0
  @else
    println("FAIL: simultaneous rules")
    return 1
  @end
@end
