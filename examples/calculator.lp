import "universe/os/syscalls"
import "universe/core/string"


@fn math_sqrt(n)
  @if n <= 0 return 0 @end
  x = n
  y = (x + 1) / 2
  @while y < x
    x = y
    y = (x + n / x) / 2
  @end
  return x
@end

@fn add(a, b) return a + b @end
@fn sub(a, b) return a - b @end
@fn mul(a, b) return a * b @end
@fn div_safe(a, b)
  @if b == 0
    println("Error: division by zero")
    return 0
  @end
  return a / b
@end
@fn mod_op(a, b)
  @if b == 0
    return 0
  @end
  return a % b
@end
@fn power(base, exp)
  @if exp == 0 return 1 @end
  result = 1
  i = 0
  @while i < exp
    result = result * base
    i = i + 1
  @end
  return result
@end
@fn factorial(n)
  @if n <= 1 return 1 @end
  return n * factorial(n - 1)
@end
@fn gcd(a, b)
  @while b != 0
    t = b
    b = a % b
    a = t
  @end
  return a
@end
@fn lcm(a, b)
  return a / gcd(a, b) * b
@end
@fn is_prime(n)
  @if n < 2 return 0 @end
  @if n == 2 return 1 @end
  @if n % 2 == 0 return 0 @end
  i = 3
  @while i * i <= n
    @if n % i == 0 return 0 @end
    i = i + 2
  @end
  return 1
@end

@fn main()
  println("=== Maya Calculator ===")
  println("")
  println("Basic Operations:")
  println(str_concat("  10 + 5 = ", int_to_str(add(10, 5))))
  println(str_concat("  10 - 5 = ", int_to_str(sub(10, 5))))
  println(str_concat("  10 * 5 = ", int_to_str(mul(10, 5))))
  println(str_concat("  10 / 3 = ", int_to_str(div_safe(10, 3))))
  println(str_concat("  10 % 3 = ", int_to_str(mod_op(10, 3))))
  println("")
  println("Advanced:")
  println(str_concat("  2^10 = ", int_to_str(power(2, 10))))
  println(str_concat("  10! = ", int_to_str(factorial(10))))
  println(str_concat("  GCD(48, 18) = ", int_to_str(gcd(48, 18))))
  println(str_concat("  LCM(12, 8) = ", int_to_str(lcm(12, 8))))
  println(str_concat("  sqrt(144) = ", int_to_str(math_sqrt(144))))
  println("")
  println("Prime Numbers up to 50:")
  primes = ""
  i = 2
  count = 0
  @while i <= 50
    @if is_prime(i) == 1
      @if count > 0
        primes = str_concat(primes, ", ")
      @end
      primes = str_concat(primes, int_to_str(i))
      count = count + 1
    @end
    i = i + 1
  @end
  println(str_concat("  ", primes))
  return 0
@end
