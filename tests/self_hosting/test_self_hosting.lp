@fn fibonacci(n)
  @if n <= 1
    return n
  @end
  return fibonacci(n - 1) + fibonacci(n - 2)
@end

@fn main()
  println("=== Maya Self-Hosting Test ===")
  fib10 = fibonacci(10)
  @if fib10 == 55
    println("PASS: fibonacci(10) == 55")
  @else
    println("FAIL: fibonacci result wrong")
  @end
  fib0 = fibonacci(0)
  @if fib0 == 0
    println("PASS: fibonacci(0) == 0")
  @else
    println("FAIL: fibonacci(0) wrong")
  @end
  println("Maya is Self-Hosting!")
@end
