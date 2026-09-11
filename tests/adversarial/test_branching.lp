@fn main()
  println("Testing branching...")
  x = 2
  @if x == 1
    println("Branch 1")
  @elif x == 2
    println("Branch 2 PASS")
  @elif x == 3
    println("Branch 3")
  @else
    println("Branch Else")
  @end

  y = 5
  @if y > 10
    println("Branch Y > 10 FAIL")
  @else
    println("Branch Y <= 10 PASS")
  @end
  return 0
@end
