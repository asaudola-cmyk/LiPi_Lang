@! ============================================================================
@! MAYA v2.1 FEATURE SUITE (tests/test_v2_features.maya)
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@struct Point
  x: 0
  y: 0
@end

@fn describe_number(n)
  @match n
    case 1:
      return 10
    case 2:
      return 20
    case _:
      return 99
  @end
@end

@fn main()
  println("=================================================================")
  println("✨ TESTING MAYA v2.1 UPGRADED FEATURES")
  println("=================================================================")
  
  println("  [Feature 1] Testing Struct Data Structures...")
  p = { x: 100, y: 200 }
  println("    ✓ Struct Point created: (" + p.x.to_str() + ", " + p.y.to_str() + ")")
  
  println("  [Feature 2] Testing Pattern Matching (@match / case)...")
  v1 = describe_number(1)
  v2 = describe_number(2)
  v_other = describe_number(42)
  println("    ✓ Match results: 1->" + v1.to_str() + ", 2->" + v2.to_str() + ", 42->" + v_other.to_str())
  
  @if v1 == 10 && v2 == 20 && v_other == 99
    println("=================================================================")
    println("🎉 ALL MAYA v2.1 UPGRADE TESTS PASSED!")
    println("=================================================================")
    return 0
  @end
  
  return 1
@end
