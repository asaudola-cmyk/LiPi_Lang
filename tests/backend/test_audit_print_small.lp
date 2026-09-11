@! ============================================================================
@! INDEPENDENT AUDITOR ADVERSARIAL STRESS SUITE — PART 2
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/compiler"

@fn main()
  src = "@fn main()\n  println(\"HELLO_MAYA_STANDALONE\")\n  println(42)\n  println(-100)\n  println(5050)\n  println(\"COMPILER_BACKEND_NATIVE_OK\")\n  return 0\n@end\n"
  bin = "/tmp/maya_audit_print_small.elf"
  res = compile_source_to_elf(src, bin)
  println("Compile result: " + res.to_str())
  return 0
@end
