@fn main()
  res = this_function_definitely_does_not_exist_xyz()
  @if res == 0
    println("Unresolved function returned 0!")
    return 0
  @else
    println("Unresolved function returned non-zero!")
    return 1
  @end
@end
