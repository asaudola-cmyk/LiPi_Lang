import "compiler/backend/compiler"

@fn main()
  println("=== Maya Self-Hosted Compiler E2E Tests ===")
  tests_pass = 0
  tests_fail = 0
  
  @! Test 1: Hello world
  src1 = "@fn main() println(\"Hello Self!\") return 0 @end"
  r1 = compile_source_to_elf(src1, "/tmp/maya_e2e_test1")
  @if r1 == 1
    tests_pass = tests_pass + 1
    println("[PASS] Test 1: Compiled hello world")
  @else
    tests_fail = tests_fail + 1
    println("[FAIL] Test 1: Could not compile")
  @end
  
  @! Test 2: Math program
  src2 = "@fn main() x = 6 * 7 println(x) return 0 @end"
  r2 = compile_source_to_elf(src2, "/tmp/maya_e2e_test2")
  @if r2 == 1
    tests_pass = tests_pass + 1
    println("[PASS] Test 2: Compiled math program")
  @else
    tests_fail = tests_fail + 1
    println("[FAIL] Test 2")
  @end
  
  @! Test 3: String program
  src3 = "@fn main() s = \"Maya\" println(s) return 0 @end"
  r3 = compile_source_to_elf(src3, "/tmp/maya_e2e_test3")
  @if r3 == 1
    tests_pass = tests_pass + 1
    println("[PASS] Test 3: Compiled string program")
  @else
    tests_fail = tests_fail + 1
    println("[FAIL] Test 3")
  @end
  
  println("")
  println("Results: " + int_to_str(tests_pass) + "/" + int_to_str(tests_pass + tests_fail) + " passed")
  
  @if tests_fail == 0
    println("🎉 ALL SELF-COMPILE TESTS PASSED!")
  @end
  
  return 0
@end
