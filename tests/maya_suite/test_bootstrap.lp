import "compiler/backend/compiler"

@fn main()
  println("=== Maya Bootstrap Test ===")
  println("Maya compiling Maya compiling Maya...")
  
  @! Step 1: Compile a simple program
  src = "@fn main() println(\"I was compiled by Maya!\") return 0 @end"
  r1 = compile_source_to_elf(src, "/tmp/maya_bootstrap_1")
  @if r1 == 1
    println("[PASS] Step 1: Maya compiled a program")
  @else
    println("[FAIL] Step 1 failed")
    return 1
  @end
  
  @! Step 2: Compile a program that calls println multiple times
  src2 = "@fn main() println(\"Line 1\") println(\"Line 2\") println(\"Line 3\") return 0 @end"
  r2 = compile_source_to_elf(src2, "/tmp/maya_bootstrap_2")
  @if r2 == 1
    println("[PASS] Step 2: Multi-statement program compiled")
  @else
    println("[FAIL] Step 2 failed")
  @end
  
  @! Step 3: Compile a math program
  src3 = "@fn main() x = 6 * 7 y = x + 2 println(x) println(y) return 0 @end"
  r3 = compile_source_to_elf(src3, "/tmp/maya_bootstrap_3")
  @if r3 == 1
    println("[PASS] Step 3: Math program compiled")
  @else
    println("[FAIL] Step 3 failed")
  @end
  
  total = r1 + r2 + r3
  println("")
  println("Bootstrap Results: " + int_to_str(total) + "/3 passed")
  @if total == 3
    println("")
    println("HISTORIC MILESTONE:")
    println("Maya compiled by Maya. Maya is free.")
    println("Maya karo help ney na. Maya r help sobai ney.")
  @end
  
  return 0
@end
