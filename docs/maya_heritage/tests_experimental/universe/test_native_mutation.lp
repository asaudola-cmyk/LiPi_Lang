@fn main()
  println("▶ [NATIVE V5] Testing Array Mutation...")
  
  arr = [100, 200, 300]
  
  arr[1] = 999
  
  @if arr[1] == 999
    println("✅ SUCCESS: Array Mutation Works Natively!")
  @else
    println("❌ FAIL: Mutation did not stick.")
  @end
  return 0
@end
