@fn main()
  println("Testing recursion...")
  f = fact(5)
  println("Factorial 5 result:")
  println(f)
  return 0
@end

@fn fact(n)
  @if n <= 1
    return 1
  @else
    prev = fact(n - 1)
    return n * prev
  @end
@end
