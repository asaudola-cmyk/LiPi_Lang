@fn math_abs(n)
  @if n < 0
    return 0 - n
  @end
  return n
@end

@fn math_max(a, b)
  @if a > b return a @end
  return b
@end
