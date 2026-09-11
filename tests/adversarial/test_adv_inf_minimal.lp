@infinity_rule "mientras" => "@while" ;
@infinity_rule "fin" => "@end" ;

@fn main()
  i = 0
  mientras i < 5
    i = i + 1
  fin
  println("i = " + i.to_str())
  return 0
@end
