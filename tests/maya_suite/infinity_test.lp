@infinity_rule "universe" => "while" "1" ;

@fn main()
  println("Entering the infinite universe...")
  
  i = 0
  @universe
    @if i > 2
      println("Escaping the universe!")
      return 0
    @end
    println("Infinity " + i.to_str())
    i = i + 1
  @end
  
  return 0
@end
