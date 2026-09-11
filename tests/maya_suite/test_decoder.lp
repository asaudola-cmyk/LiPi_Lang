@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — TEST UNIVERSAL DECODER
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/universal_math"

@fn main()
  println("=== Maya Universal Decoder Test ===")
  
  @! Create G from string 67500
  g = bigint_from_string("67500")
  
  @! We know it was exactly 3 bytes
  decoded = decode_universal_number(g, 3)
  
  println("Decoded bytes:")
  i = 0
  @while i < decoded.len()
    println(to_str(decoded[i]))
    i = i + 1
  @end
  
  @if decoded.len() == 3 && decoded[0] == 1 && decoded[1] == 2 && decoded[2] == 3
    println("✅ PASS: Correctly factored Universal Number!")
    return 0
  @else
    println("❌ FAIL: Did not factor correctly!")
    return 1
  @end
@end
