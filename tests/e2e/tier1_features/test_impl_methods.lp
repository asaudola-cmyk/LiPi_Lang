// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Impl Blocks & Methods PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: impl, methods, self, receiver, mutation, chaining

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: IMPL BLOCKS & STRUCT METHODS
@! File: tests/e2e/tier1_features/test_impl_methods.maya
@! ============================================================================

@struct Point
  x: i64
  y: i64
@end

@impl Point
  @fn get_x(self)
    return self.x
  @end

  @fn get_y(self)
    return self.y
  @end

  @fn dist_squared(self, other)
    dx = self.x - other.x
    dy = self.y - other.y
    return dx * dx + dy * dy
  @end
@end

@struct Counter
  count: i64
  steps: i64
@end

@impl Counter
  @fn inc(self, step)
    self.count = self.count + step
    self.steps = self.steps + 1
    return self.count
  @end

  @fn reset(self)
    self.count = 0
    self.steps = 0
    return self.count
  @end
@end

@struct Calc
  base: i64
@end

@impl Calc
  @fn add(self, a, b)
    return self.base + a + b
  @end

  @fn sub(self, a, b)
    return (self.base + a) - b
  @end
@end

@struct ValueBuilder
  val_a: i64
  val_b: i64
@end

@impl ValueBuilder
  @fn set_a(self, a)
    self.val_a = a
    return self
  @end

  @fn set_b(self, b)
    self.val_b = b
    return self
  @end

  @fn sum(self)
    return self.val_a + self.val_b
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Impl Blocks & Struct Methods")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-IM-01: Member method definition and field access via self
  total = total + 1
  p1 = { x: 10, y: 20 }
  px = p1.get_x()
  py = p1.get_y()
  @if px == 10 && py == 20
    passed = passed + 1
    println("  [PASS] TC-IM-01: Point.get_x() == 10, Point.get_y() == 20")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IM-01: Point member methods")
  @end

  @! TC-IM-02: Method mutating self state
  total = total + 1
  c = { count: 0, steps: 0 }
  c.inc(5)
  c.inc(10)
  @if c.count == 15 && c.steps == 2
    passed = passed + 1
    println("  [PASS] TC-IM-02: Counter.inc(5), inc(10) -> count=15, steps=2")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IM-02: Counter mutating self")
  @end

  @! TC-IM-03: Multiple methods in same @impl block
  total = total + 1
  calc = { base: 100 }
  r_add = calc.add(20, 5)
  r_sub = calc.sub(20, 5)
  @if r_add == 125 && r_sub == 115
    passed = passed + 1
    println("  [PASS] TC-IM-03: Calc.add == 125, Calc.sub == 115")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IM-03: Multiple methods in @impl block")
  @end

  @! TC-IM-04: Method taking another struct parameter
  total = total + 1
  pa = { x: 0, y: 0 }
  pb = { x: 3, y: 4 }
  dsq = pa.dist_squared(pb)
  @if dsq == 25
    passed = passed + 1
    println("  [PASS] TC-IM-04: Point.dist_squared(pb) == 25")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IM-04: Method taking struct parameter")
  @end

  @! TC-IM-05: Chained method invocations
  total = total + 1
  builder = { val_a: 0, val_b: 0 }
  builder.set_a(30).set_b(70)
  b_sum = builder.sum()
  @if builder.val_a == 30 && builder.val_b == 70 && b_sum == 100
    passed = passed + 1
    println("  [PASS] TC-IM-05: Chained builder calls -> sum == 100")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IM-05: Chained method calls")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Impl Blocks & Methods PASSED")
    return 0
  @else
    println("✗ Feature: Impl Blocks & Methods FAILED")
    return 1
  @end
@end
