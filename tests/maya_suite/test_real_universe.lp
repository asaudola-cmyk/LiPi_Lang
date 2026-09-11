import "universe/core/math"
import "universe/core/string"
import "universe/core/io"

@fn main()
  @! Test math
  @if abs(-42) == 42
    println("[PASS] abs(-42) == 42")
  @else
    println("[FAIL] abs")
  @end

  @if max(10, 20) == 20
    println("[PASS] max(10, 20)")
  @else
    println("[FAIL] max")
  @end

  @if factorial(5) == 120
    println("[PASS] factorial(5) == 120")
  @else
    println("[FAIL] factorial")
  @end

  @if gcd(12, 8) == 4
    println("[PASS] gcd(12, 8) == 4")
  @else
    println("[FAIL] gcd")
  @end

  @if pow_int(2, 10) == 1024
    println("[PASS] pow_int(2, 10) == 1024")
  @else
    println("[FAIL] pow_int")
  @end

  @if clamp(50, 0, 10) == 10
    println("[PASS] clamp(50, 0, 10) == 10")
  @else
    println("[FAIL] clamp")
  @end

  @! Test string library
  upper = string_upper("hello")
  println(upper)

  lower = string_lower("HELLO")
  println(lower)

  len = string_length("maya")
  @if len == 4
    println("[PASS] string_length")
  @else
    println("[FAIL] string_length")
  @end

  @! Test I/O library
  write_file("/tmp/maya_universe_test.txt", "Maya Universe Works!")
  content = read_file("/tmp/maya_universe_test.txt")
  println(content)

  @if path_exists("/tmp/maya_universe_test.txt") == 1
    println("[PASS] path_exists")
  @else
    println("[FAIL] path_exists")
  @end

  return 0
@end
