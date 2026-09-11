@fn main()
  println("Testing while loop...")
  i = 0
  sum = 0
  @while i < 10
    sum = sum + i
    i = i + 1
  @end
  println("Sum 0..9:")
  println(sum)
  return 0
@end
