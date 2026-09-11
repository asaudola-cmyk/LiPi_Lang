import "universe/core/collections"
import "universe/core/string"

@fn fib_iterative(n)
  @if n <= 1
    return n
  @end
  a = 0
  b = 1
  i = 2
  @while i <= n
    c = a + b
    a = b
    b = c
    i = i + 1
  @end
  return b
@end

@fn fib_memoized(n)
  memo = []
  i = 0
  @while i <= n
    memo = memo.push(0)
    i = i + 1
  @end
  memo[0] = 0
  @if n >= 1
    memo[1] = 1
  @end
  i = 2
  @while i <= n
    memo[i] = memo[i - 1] + memo[i - 2]
    i = i + 1
  @end
  return memo[n]
@end

@fn main()
  println("=== Fibonacci in Maya ===")
  println("")
  i = 0
  @while i <= 15
    println(str_concat("fib(", str_concat(to_str(i), str_concat(") = ", to_str(fib_iterative(i))))))
    i = i + 1
  @end
  println("")
  println(str_concat("fib(50) = ", to_str(fib_memoized(50))))
  return 0
@end
