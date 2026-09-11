@infinity_rule "mientras" => "@while" ;
@infinity_rule "fin" => "@end" ;

@fn main()
  i = 0
  mientras i < 5
    i = i + 1
  fin
  @if i == 5
    println("SUCCESS")
    return 0
  @else
    println("FAIL")
    return 1
  @end
@end
