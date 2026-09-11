@! ============================================================================
@! INDEPENDENT AUDITOR ADVERSARIAL STRESS SUITE — PART 3 (ALGORITHMS)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/compiler"

@fn main()
  src = "@fn gcd(a, b)\n  x = a\n  y = b\n  @while y != 0\n    t = y\n    y = x % y\n    x = t\n  @end\n  return x\n@end\n\n@fn lcm(a, b)\n  g = gcd(a, b)\n  return (a / g) * b\n@end\n\n@fn fast_fib(n)\n  @if n <= 0 return 0 @end\n  @if n == 1 return 1 @end\n  a = 0\n  b = 1\n  i = 2\n  @while i <= n\n    c = a + b\n    a = b\n    b = c\n    i = i + 1\n  @end\n  return b\n@end\n\n@fn main()\n  g1 = gcd(48, 18)\n  @if g1 != 6 return 1 @end\n  l1 = lcm(12, 15)\n  @if l1 != 60 return 2 @end\n  f20 = fast_fib(20)\n  @if f20 != 6765 return 3 @end\n  println(\"ALGORITHMS_STANDALONE_PASSED\")\n  println(f20)\n  return 99\n@end\n"

  bin = "/tmp/maya_audit_algo.elf"
  res = compile_source_to_elf(src, bin)
  println("Algo Compile Result: " + res.to_str())
  return 0
@end
