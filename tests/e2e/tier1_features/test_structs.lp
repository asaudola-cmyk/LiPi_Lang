// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Structs & Data Structures PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: structs, records, nested_structs, mutation, factory

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: STRUCTS & DATA STRUCTURES
@! File: tests/e2e/tier1_features/test_structs.maya
@! ============================================================================

@struct Point
  x: i64
  y: i64
@end

@struct ColorPoint
  x: i64
  y: i64
  r: i64
  g: i64
  b: i64
@end

@struct InnerNode
  node_id: i64
  payload: i64
@end

@struct OuterEnvelope
  inner: InnerNode
  envelope_id: i64
  tag: string
@end

@struct Rectangle
  x: i64
  y: i64
  width: i64
  height: i64
@end

@fn make_point(x, y)
  return { x: x, y: y }
@end

@fn translate_point(p, dx, dy)
  return { x: p.x + dx, y: p.y + dy }
@end

@fn calc_area(r)
  return r.width * r.height
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Structs & Data Structures")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-ST-01: Struct Declaration & Field Instantiation
  total = total + 1
  pt = { x: 15, y: 25 }
  @if pt.x == 15 && pt.y == 25
    passed = passed + 1
    println("  [PASS] TC-ST-01: Point instantiation (x=15, y=25)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ST-01: Point instantiation")
  @end

  @! TC-ST-02: Struct Field Mutation
  total = total + 1
  pt.x = 100
  pt.y = 200
  @if pt.x == 100 && pt.y == 200
    passed = passed + 1
    println("  [PASS] TC-ST-02: Point field mutation (x=100, y=200)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ST-02: Point field mutation")
  @end

  @! TC-ST-03: Multi-field Struct (5 fields)
  total = total + 1
  cp = { x: 5, y: 10, r: 255, g: 128, b: 64 }
  sum_rgb = cp.r + cp.g + cp.b
  @if cp.x == 5 && cp.y == 10 && sum_rgb == 447
    passed = passed + 1
    println("  [PASS] TC-ST-03: ColorPoint multi-field struct (sum_rgb == 447)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ST-03: ColorPoint multi-field struct")
  @end

  @! TC-ST-04: Nested Structs
  total = total + 1
  inner_obj = { node_id: 101, payload: 777 }
  outer_obj = { inner: inner_obj, envelope_id: 9999, tag: "MSG_INIT" }
  @if outer_obj.inner.node_id == 101 && outer_obj.inner.payload == 777 && outer_obj.envelope_id == 9999
    passed = passed + 1
    println("  [PASS] TC-ST-04: Nested structs traversal (inner.payload == 777)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ST-04: Nested structs traversal")
  @end

  @! TC-ST-05: Struct Passed to and Returned from Functions
  total = total + 1
  p_orig = make_point(10, 20)
  p_moved = translate_point(p_orig, 5, -8)
  rect = { x: p_moved.x, y: p_moved.y, width: 30, height: 20 }
  area = calc_area(rect)
  @if p_moved.x == 15 && p_moved.y == 12 && area == 600
    passed = passed + 1
    println("  [PASS] TC-ST-05: Struct passing, returning and area calculation (area == 600)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ST-05: Struct passing and returning")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Structs & Data Structures PASSED")
    return 0
  @else
    println("✗ Feature: Structs & Data Structures FAILED")
    return 1
  @end
@end
