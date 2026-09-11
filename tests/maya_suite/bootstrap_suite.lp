@! ============================================================================
@! MAYA BOOTSTRAP TEST SUITE — tests/bootstrap_suite.maya
@! Comprehensive test runner. All tests use bootstrap-compatible syntax only.
@! Zero arrays, zero structs, zero imports. Pure Maya + syscalls.
@! ============================================================================

@fn fibonacci(n)
  @if n <= 1
    return n
  @end
  return fibonacci(n - 1) + fibonacci(n - 2)
@end

@fn factorial(n)
  @if n <= 1
    return 1
  @end
  return n * factorial(n - 1)
@end

@fn mod_pow(base, exp, modulus)
  result = 1
  b = base
  e = exp
  @while e > 0
    remainder = e & 1
    @if remainder == 1
      result = result * b
      result = result - (result / modulus) * modulus
    @end
    b = b * b
    b = b - (b / modulus) * modulus
    e = e >> 1
  @end
  return result
@end

@fn sum_to(n)
  i = 1
  s = 0
  @while i <= n
    s = s + i
    i = i + 1
  @end
  return s
@end

@fn main()
  println("=== Maya Bootstrap Test Suite ===")

  @if 2 + 3 == 5
    println("PASS: 2+3=5")
  @else
    println("FAIL: 2+3=5")
  @end

  @if 10 - 3 == 7
    println("PASS: 10-3=7")
  @else
    println("FAIL: 10-3=7")
  @end

  @if 4 * 5 == 20
    println("PASS: 4*5=20")
  @else
    println("FAIL: 4*5=20")
  @end

  @if 20 / 4 == 5
    println("PASS: 20/4=5")
  @else
    println("FAIL: 20/4=5")
  @end

  @if 17 % 5 == 2
    println("PASS: 17 mod 5=2")
  @else
    println("FAIL: 17 mod 5=2")
  @end

  @if 8 >> 1 == 4
    println("PASS: 8>>1=4")
  @else
    println("FAIL: 8>>1=4")
  @end

  @if 2 << 2 == 8
    println("PASS: 2<<2=8")
  @else
    println("FAIL: 2<<2=8")
  @end

  @if 5 & 3 == 1
    println("PASS: 5 AND 3=1")
  @else
    println("FAIL: 5 AND 3=1")
  @end

  @if 5 == 5
    println("PASS: 5==5")
  @else
    println("FAIL: 5==5")
  @end

  @if 5 != 3
    println("PASS: 5!=3")
  @else
    println("FAIL: 5!=3")
  @end

  @if 3 < 5
    println("PASS: 3<5")
  @else
    println("FAIL: 3<5")
  @end

  @if 5 > 3
    println("PASS: 5>3")
  @else
    println("FAIL: 5>3")
  @end

  @if 3 <= 3
    println("PASS: 3<=3")
  @else
    println("FAIL: 3<=3")
  @end

  @if 5 >= 5
    println("PASS: 5>=5")
  @else
    println("FAIL: 5>=5")
  @end

  fib10 = fibonacci(10)
  @if fib10 == 55
    println("PASS: fibonacci(10)=55")
  @else
    println("FAIL: fibonacci(10) wrong")
  @end

  fib7 = fibonacci(7)
  @if fib7 == 13
    println("PASS: fibonacci(7)=13")
  @else
    println("FAIL: fibonacci(7) wrong")
  @end

  fib0 = fibonacci(0)
  @if fib0 == 0
    println("PASS: fibonacci(0)=0")
  @else
    println("FAIL: fibonacci(0) wrong")
  @end

  fib1 = fibonacci(1)
  @if fib1 == 1
    println("PASS: fibonacci(1)=1")
  @else
    println("FAIL: fibonacci(1) wrong")
  @end

  fact5 = factorial(5)
  @if fact5 == 120
    println("PASS: factorial(5)=120")
  @else
    println("FAIL: factorial(5) wrong")
  @end

  fact0 = factorial(0)
  @if fact0 == 1
    println("PASS: factorial(0)=1")
  @else
    println("FAIL: factorial(0) wrong")
  @end

  s = sum_to(10)
  @if s == 55
    println("PASS: sum(1..10)=55")
  @else
    println("FAIL: sum(1..10) wrong")
  @end

  s100 = sum_to(100)
  @if s100 == 5050
    println("PASS: sum(1..100)=5050")
  @else
    println("FAIL: sum(1..100) wrong")
  @end

  mp1 = mod_pow(5, 3, 23)
  @if mp1 == 10
    println("PASS: mod_pow(5,3,23)=10")
  @else
    println("FAIL: mod_pow(5,3,23) wrong")
  @end

  mp2 = mod_pow(2, 10, 1000)
  @if mp2 == 24
    println("PASS: mod_pow(2,10,1000)=24")
  @else
    println("FAIL: mod_pow(2,10,1000) wrong")
  @end

  commit = mod_pow(5, 7, 23)
  @if commit == 17
    println("PASS: ZKP g^x mod p=17")
  @else
    println("FAIL: ZKP commitment wrong")
  @end

  x = 42
  @if x > 100
    println("FAIL: elif branch 1")
  @elif x > 50
    println("FAIL: elif branch 2")
  @elif x > 40
    println("PASS: nested elif x>40")
  @else
    println("FAIL: elif else")
  @end

  count = 0
  i = 0
  @while i < 10
    count = count + 1
    i = i + 1
  @end
  @if count == 10
    println("PASS: while loop count=10")
  @else
    println("FAIL: while loop count wrong")
  @end

  outer = 0
  i = 0
  @while i < 3
    j = 0
    @while j < 3
      outer = outer + 1
      j = j + 1
    @end
    i = i + 1
  @end
  @if outer == 9
    println("PASS: nested while 3x3=9")
  @else
    println("FAIL: nested while wrong")
  @end

  fd = sys_open_write("/tmp/maya_test_output.bin")
  @if fd > 0
    sys_write_byte(fd, 77)
    sys_write_byte(fd, 65)
    sys_write_byte(fd, 89)
    sys_write_byte(fd, 65)
    sys_close(fd)
    println("PASS: sys_write_byte to file")
  @else
    println("FAIL: sys_open_write returned <=0")
  @end

  println("=== Maya is Sovereign ===")
@end
