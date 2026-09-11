import "universe/core/time"
import "universe/core/fmt"

@fn bench_fibonacci(n)
  a = 0
  b = 1
  i = 0
  @while i < n
    c = a + b
    a = b
    b = c
    i = i + 1
  @end
  return b
@end

@fn bench_primes_count(limit)
  count = 0
  i = 2
  @while i <= limit
    is_p = 1
    j = 2
    @while j * j <= i
      @if i % j == 0
        is_p = 0
      @end
      j = j + 1
    @end
    @if is_p == 1
      count = count + 1
    @end
    i = i + 1
  @end
  return count
@end

@fn bench_string_ops(n)
  s = ""
  i = 0
  @while i < n
    s = s + "x"
    i = i + 1
  @end
  return str_len(s)
@end

@fn bench_array_ops(n)
  arr = []
  i = 0
  @while i < n
    arr = arr.push(i)
    i = i + 1
  @end
  total = 0
  i = 0
  @while i < arr.len()
    total = total + arr[i]
    i = i + 1
  @end
  return total
@end

@fn main()
  fmt_box("Maya Performance Benchmark", 40)
  println("")
  
  t1 = timer_start("Fibonacci(1000000)")
  result1 = bench_fibonacci(1000000)
  elapsed1 = timer_stop(t1)
  println("  Result: fib(1000000) last digit = " + int_to_str(result1 % 10))
  println("")
  
  t2 = timer_start("Primes up to 10000")
  result2 = bench_primes_count(10000)
  elapsed2 = timer_stop(t2)
  println("  Result: " + int_to_str(result2) + " primes found")
  println("")
  
  t3 = timer_start("String concat x1000")
  result3 = bench_string_ops(1000)
  elapsed3 = timer_stop(t3)
  println("  Result: string length = " + int_to_str(result3))
  println("")
  
  t4 = timer_start("Array push+sum x10000")
  result4 = bench_array_ops(10000)
  elapsed4 = timer_stop(t4)
  println("  Result: sum = " + int_to_str(result4))
  println("")
  
  total_ms = elapsed1 + elapsed2 + elapsed3 + elapsed4
  println("Total benchmark time: " + time_format_ms(total_ms))
  println("Maya is FAST.")
  return 0
@end
