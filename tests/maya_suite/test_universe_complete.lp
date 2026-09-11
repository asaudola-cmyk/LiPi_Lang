import "universe/core/math"
import "universe/core/string"
import "universe/core/error"
import "universe/crypto/sha256"

println("--- Universe Complete Test ---")
passes = 0

@! math test
m = clamp(10, 0, 5)
@if m == 5
  println("PASS: math clamp")
  passes = passes + 1
@else
  println("FAIL: math clamp")
@end

@! string test
s = string_upper("hello")
@if s == "HELLO"
  println("PASS: string upper")
  passes = passes + 1
@else
  println("FAIL: string upper")
@end

@! error test
e = ok(42)
@if is_ok(e) == 1 && e.value == 42
  println("PASS: error ok")
  passes = passes + 1
@else
  println("FAIL: error ok")
@end

@! crypto test
hash = sha256_hash_bytes("hello")
@if hash.len() > 0
  println("PASS: sha256 hash")
  passes = passes + 1
@else
  println("FAIL: sha256 hash")
@end
