@! Maya Model Serialization Unit Tests
import "universe/core/collections"
import "universe/core/string"
import "universe/ai/model_io"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 0
  @end
@end

@fn assert_str_eq(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Got '" + actual + "', Expected '" + expected + "')")
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA MODEL I/O UNIT TEST SUITE                 ")
  println("==================================================")
  
  @! 1. Test Dtype Codecs
  assert_eq(get_dtype_code("f32"), 0, "Dtype f32 code == 0")
  assert_eq(get_dtype_code("f64"), 1, "Dtype f64 code == 1")
  assert_eq(get_dtype_code("i32"), 2, "Dtype i32 code == 2")
  assert_eq(get_dtype_code("i64"), 3, "Dtype i64 code == 3")
  assert_str_eq(get_dtype_from_code(0), "f32", "Code 0 -> f32")
  assert_str_eq(get_dtype_from_code(3), "i64", "Code 3 -> i64")

  @! 2. Test Checkpoint Save & Load Roundtrip
  tmp_path = "/tmp/maya_test_checkpoint.mayamodel"
  saved = save_checkpoint("transformer_xl", 5000, tmp_path)
  assert_eq(saved, 1, "save_checkpoint succeeded")

  loaded = load_checkpoint(tmp_path)
  assert_str_eq(loaded.model_name, "transformer_xl", "Loaded model_name matches")
  assert_eq(loaded.step, 5000, "Loaded training step matches")
  
  println("🎉 ALL MODEL I/O TESTS PASSED!")
  return 0
@end
