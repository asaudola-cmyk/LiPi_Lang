@fn main()
  i = 5
  x = i * i
  println("x = " + x.to_str())
  @! Test (i * i).to_str()
  println("direct = " + (i * i).to_str())
  return 0
@end
