@fn main()
  println("Testing arrays and structs...")
  arr = [10, 20, 30]
  x = arr[1]
  @if x == 20
    println("Array indexing PASS")
  @else
    println("Array indexing FAIL")
  @end

  st = { key: 100, val: 200 }
  k = st.key
  @if k == 100
    println("Struct access PASS")
  @else
    println("Struct access FAIL")
  @end

  return 0
@end
