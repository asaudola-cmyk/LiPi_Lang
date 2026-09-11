@fn main()
  i = 0
  @while i < 5
    i = i + 1
  @end
  @if i == 5
    println("SUCCESS")
    return 0
  @else
    println("FAIL")
    return 1
  @end
@end
