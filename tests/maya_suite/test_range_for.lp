@fn main()
  total = 0
  @for i in 0..10
    total = total + i
  @end
  println(total)
  @if total == 45
    println("[PASS] range for 0..10 sum = 45")
  @else
    println("[FAIL] range for")
  @end

  @! Nested range for
  count = 0
  @for i in 1..4
    @for j in 1..4
      count = count + 1
    @end
  @end
  @if count == 9
    println("[PASS] nested range for 3x3 = 9")
  @else
    println("[FAIL] nested range for")
  @end

  @! Range for with break
  sum2 = 0
  @for i in 0..100
    @if i == 5
      break
    @end
    sum2 = sum2 + i
  @end
  @if sum2 == 10
    println("[PASS] range for with break")
  @else
    println("[FAIL] range for with break")
  @end

  return 0
@end
