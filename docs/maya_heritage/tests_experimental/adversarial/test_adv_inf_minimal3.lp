@infinity_rule "mientras" => "@while" ;
@infinity_rule "fin" => "@end" ;

@fn main()
  i = 0
  mientras i < 5
    i = i + 1
  fin
  @if i == 0
    println("i is still 0!")
  @end
  @if i == 5
    println("i is 5!")
  @end
  return 0
@end
