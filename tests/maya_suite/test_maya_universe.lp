@! ============================================================================
@! MAYA UNIVERSE INTEGRATION TEST
@! ============================================================================

import "universe/maya_universe"
import "universe/core/error"
import "universe/os/process"
import "universe/os/fs"
import "universe/crypto/crypto"

@struct Planet
  name: string
  mass: i64
@end

@impl Planet
  @fn describe(self)
    return "{self.name} has mass {self.mass}"
  @end
@end

@fn main()
  passed = 0
  failed = 0
  
  println("=================================================================")
  println("▶ MAYA UNIVERSE INTEGRATION TEST")
  println("=================================================================")

  @! 1. Tests @impl struct methods and 2. string interpolation
  p = { name: "Earth", mass: 5972 }
  desc = p.describe()
  @if contains(desc, "has mass 5972") == 1
    println("  [PASS] Struct methods and string interpolation")
    passed = passed + 1
  @else
    println("  [FAIL] Struct methods and string interpolation, got: " + desc)
    failed = failed + 1
  @end

  @! 3. Tests error/result types
  res = ok(42)
  @if is_ok(res) && unwrap(res) == 42
    println("  [PASS] Error/Result types (ok/is_ok/unwrap)")
    passed = passed + 1
  @else
    println("  [FAIL] Error/Result types")
    failed = failed + 1
  @end
  
  @! 4. Tests int_to_str
  i = 1234
  s = i.to_str()
  @if s == "1234"
    println("  [PASS] Integer to string conversion")
    passed = passed + 1
  @else
    println("  [FAIL] Integer to string conversion, got: " + s)
    failed = failed + 1
  @end

  @! 5. Tests file I/O
  fs_write_file("/tmp/maya_universe_test.txt", "maya is everything")
  content = fs_read_file("/tmp/maya_universe_test.txt")
  @if content == "maya is everything"
    println("  [PASS] File I/O operations")
    passed = passed + 1
  @else
    println("  [FAIL] File I/O operations, got: " + content)
    failed = failed + 1
  @end
  fs_remove("/tmp/maya_universe_test.txt")

  @! 6. Tests syscall (getpid)
  pid = process_getpid()
  @if pid > 0
    println("  [PASS] Syscall process_getpid() -> " + pid.to_str())
    passed = passed + 1
  @else
    println("  [FAIL] Syscall process_getpid()")
    failed = failed + 1
  @end
  
  @! 7. Crypto hash
  hash = crypto_sha256_hex("maya")
  @if hash.len() == 64
    println("  [PASS] Crypto SHA-256 hash length verified")
    passed = passed + 1
  @else
    println("  [FAIL] Crypto SHA-256")
    failed = failed + 1
  @end

  println("-----------------------------------------------------------------")
  println("Universe Test Summary: " + passed.to_str() + " passed, " + failed.to_str() + " failed")
  @if failed == 0
    println("✓ MAYA UNIVERSE TEST SUITE PASSED")
  @else
    println("✗ MAYA UNIVERSE TEST SUITE FAILED")
  @end
  
  println("")
  maya_universe_stats()
  
  @if failed > 0 return 1 @end
  return 0
@end
