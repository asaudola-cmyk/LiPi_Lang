@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — TEST UNIVERSAL NUMBER
@! File: tests/test_universal_number.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/universal_math"

@fn main()
  println("=== Maya Universal Number Generator Test ===")
  
  @! A tiny instruction stream (e.g. 1, 2, 3)
  @! Gödel representation:
  @! prime 0 = 2, exp = 1+1 = 2 -> 2^2 = 4
  @! prime 1 = 3, exp = 2+1 = 3 -> 3^3 = 27
  @! prime 2 = 5, exp = 3+1 = 4 -> 5^4 = 625
  @! Total Universal Number = 4 * 27 * 625 = 67500
  
  instructions = [1, 2, 3]
  
  println("Original Byte Stream: [1, 2, 3]")
  
  u_num = generate_universal_number(instructions)
  u_str = bigint_to_string(u_num)
  
  println("Generated Universal Number:")
  println(u_str)
  
  @if str_eq(u_str, "67500") == 1
    println("✅ PASS: Correct Universal Number generated!")
    return 0
  @else
    println("❌ FAIL: Incorrect Universal Number!")
    return 1
  @end
@end
