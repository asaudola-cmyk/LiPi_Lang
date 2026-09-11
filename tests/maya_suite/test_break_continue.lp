@fn test_break()
  total = 0
  i = 0
  @while i < 100
    @if i == 5
      break
    @end
    total = total + i
    i = i + 1
  @end
  return total
@end

@fn test_continue()
  total = 0
  i = 0
  @while i < 10
    i = i + 1
    @if i % 2 == 0
      continue
    @end
    total = total + i
  @end
  return total
@end

@fn main()
  b = test_break()
  println(b)
  @if b == 10
    println("[PASS] break works: 0+1+2+3+4 = 10")
  @else
    println("[FAIL] break")
  @end

  c = test_continue()
  println(c)
  @if c == 25
    println("[PASS] continue works: 1+3+5+7+9 = 25")
  @else
    println("[FAIL] continue")
  @end

  return 0
@end
