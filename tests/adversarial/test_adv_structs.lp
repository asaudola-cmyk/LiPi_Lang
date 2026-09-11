@! ============================================================================
@! ADVERSARIAL STRESS TEST: STRUCT EDGE CASES (test_adv_structs.maya)
@! Tests:
@! 1. Empty structs
@! 2. Single-element structs
@! 3. Structs with arrays as fields
@! 4. Arrays of structs
@! 5. Mutating struct fields and nested array mutations
@! ============================================================================

@struct Empty
@end

@struct SingleVal
  val: 0
@end

@struct ArrayHolder
  id: 0
  items: 0
@end

@struct Vector2
  x: 0
  y: 0
@end

@struct Vector3
  x: 0
  y: 0
  z: 0
@end

@fn pass_empty(e)
  return e
@end

@fn double_single_val(s)
  s.val = s.val * 2
  return s
@end

@fn sum_array_holder(h)
  let sum = 0
  let i = 0
  let arr = h.items
  let n = arr.len()
  @while i < n
    sum = sum + arr[i]
    i = i + 1
  @end
  return sum
@end

@fn sum_struct_array(arr)
  let sum = 0
  let i = 0
  let n = arr.len()
  @while i < n
    let elem = arr[i]
    sum = sum + elem.val
    i = i + 1
  @end
  return sum
@end

@fn main()
  println("=================================================================")
  println("ADVERSARIAL SUITE: STRUCT EDGE CASES")
  println("=================================================================")

  let passed = 0
  let total = 0

  @! -------------------------------------------------------------
  @! 1. Empty Structs
  @! -------------------------------------------------------------
  println("▶ Section 1: Empty Structs")

  total = total + 1
  let e1 = {}
  let e2 = pass_empty(e1)
  @if e1 != 0 && e2 != 0
    passed = passed + 1
    println("  [PASS] S1.1: Empty struct instantiated and passed through function")
  @else
    println("  [FAIL] S1.1: Empty struct failure")
  @end

  total = total + 1
  let anon_empty = {}
  @if anon_empty != 0
    passed = passed + 1
    println("  [PASS] S1.2: Anonymous empty struct instantiation")
  @else
    println("  [FAIL] S1.2: Anonymous empty struct failure")
  @end

  @! -------------------------------------------------------------
  @! 2. Single-element Structs
  @! -------------------------------------------------------------
  println("▶ Section 2: Single-element Structs")

  total = total + 1
  let s1 = { val: 42 }
  @if s1.val == 42
    passed = passed + 1
    println("  [PASS] S2.1: Single-element struct field read")
  @else
    println("  [FAIL] S2.1: Single-element struct field read")
  @end

  total = total + 1
  s1.val = 999
  @if s1.val == 999
    passed = passed + 1
    println("  [PASS] S2.2: Single-element struct field write / mutation")
  @else
    println("  [FAIL] S2.2: Single-element struct field mutation")
  @end

  total = total + 1
  let s2 = double_single_val(s1)
  @if s2.val == 1998 && s1.val == 1998
    passed = passed + 1
    println("  [PASS] S2.3: Single-element struct mutation via function")
  @else
    println("  [FAIL] S2.3: Single-element struct mutation via function")
  @end

  @! -------------------------------------------------------------
  @! 3. Structs with Arrays as Fields
  @! -------------------------------------------------------------
  println("▶ Section 3: Structs with Arrays as Fields")

  total = total + 1
  let list = [10, 20, 30, 40, 50]
  let holder = { id: 101, items: list }
  @if holder.id == 101 && holder.items.len() == 5
    passed = passed + 1
    println("  [PASS] S3.1: Struct holding array initialization and len()")
  @else
    println("  [FAIL] S3.1: Struct holding array failure")
  @end

  total = total + 1
  let h_items = holder.items
  @if h_items[0] == 10 && h_items[2] == 30 && h_items[4] == 50
    passed = passed + 1
    println("  [PASS] S3.2: Struct array field element indexing")
  @else
    println("  [FAIL] S3.2: Struct array field element indexing")
  @end

  total = total + 1
  h_items[2] = 333
  @if h_items[2] == 333
    passed = passed + 1
    println("  [PASS] S3.3: Struct array element in-place mutation")
  @else
    println("  [FAIL] S3.3: Struct array element in-place mutation")
  @end

  total = total + 1
  h_items.push(60)
  @if h_items.len() == 6 && h_items[5] == 60
    passed = passed + 1
    println("  [PASS] S3.4: Struct array field push and growth")
  @else
    println("  [FAIL] S3.4: Struct array field push and growth")
  @end

  total = total + 1
  let h_sum = sum_array_holder(holder)
  @! 10 + 20 + 333 + 40 + 50 + 60 = 513
  @if h_sum == 513
    passed = passed + 1
    println("  [PASS] S3.5: Function traversal over struct array field (sum = 513)")
  @else
    println("  [FAIL] S3.5: Function traversal over struct array field")
  @end

  @! -------------------------------------------------------------
  @! 4. Arrays of Structs
  @! -------------------------------------------------------------
  println("▶ Section 4: Arrays of Structs")

  total = total + 1
  let st_arr = [{ val: 100 }, { val: 200 }, { val: 300 }]
  @if st_arr.len() == 3
    passed = passed + 1
    println("  [PASS] S4.1: Array of structs length")
  @else
    println("  [FAIL] S4.1: Array of structs length")
  @end

  total = total + 1
  let elem0 = st_arr[0]
  let elem1 = st_arr[1]
  let elem2 = st_arr[2]
  @if elem0.val == 100 && elem1.val == 200 && elem2.val == 300
    passed = passed + 1
    println("  [PASS] S4.2: Accessing fields of structs inside array")
  @else
    println("  [FAIL] S4.2: Accessing fields of structs inside array")
  @end

  total = total + 1
  elem1.val = 250
  @if elem1.val == 250
    passed = passed + 1
    println("  [PASS] S4.3: Mutating struct field inside array")
  @else
    println("  [FAIL] S4.3: Mutating struct field inside array")
  @end

  total = total + 1
  st_arr.push({ val: 400 })
  @if st_arr.len() == 4
    let elem3 = st_arr[3]
    @if elem3.val == 400
      passed = passed + 1
      println("  [PASS] S4.4: Pushing new struct into array of structs")
    @else
      println("  [FAIL] S4.4: Pushed struct value mismatch")
    @end
  @else
    println("  [FAIL] S4.4: Array push length mismatch")
  @end

  total = total + 1
  let arr_total = sum_struct_array(st_arr)
  @! 100 + 250 + 300 + 400 = 1050
  @if arr_total == 1050
    passed = passed + 1
    println("  [PASS] S4.5: Summing array of structs in function (sum = 1050)")
  @else
    println("  [FAIL] S4.5: Summing array of structs in function")
  @end

  @! -------------------------------------------------------------
  @! 5. Multi-field and Vector Structs
  @! -------------------------------------------------------------
  println("▶ Section 5: Multi-field Structs")

  total = total + 1
  let v2 = { x: 15, y: 25 }
  let v3 = { x: 10, y: 20, z: 30 }
  @if v2.x == 15 && v2.y == 25 && v3.x == 10 && v3.y == 20 && v3.z == 30
    passed = passed + 1
    println("  [PASS] S5.1: Multiple distinct struct layout resolution")
  @else
    println("  [FAIL] S5.1: Multi-field struct layout resolution")
  @end

  println("=================================================================")
  println("STRUCT TESTS SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    return 0
  @else
    return 1
  @end
@end
