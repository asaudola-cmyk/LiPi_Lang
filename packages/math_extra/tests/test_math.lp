import "packages/math_extra/src/lib"

@fn main()
  println("--- Math Extra Test ---")
  
  c1 = Complex { real: 1, imag: 2 }
  c2 = Complex { real: 3, imag: 4 }
  
  c3 = complex_add(c1, c2)
  @if c3.real == 4 && c3.imag == 6
    println("PASS: complex_add")
  @else
    println("FAIL: complex_add")
  @end
  
  v = clamp(10, 0, 5)
  @if v == 5
    println("PASS: clamp")
  @else
    println("FAIL: clamp")
  @end
  
  return 0
@end
