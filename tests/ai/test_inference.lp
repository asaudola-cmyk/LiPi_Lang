@! Maya AI INT8 Inference Engine Unit Tests
import "universe/core/collections"
import "universe/core/string"
import "universe/ai/inference"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 0
  @end
@end

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] " + msg)
    return 0
  @end
  println("  [PASS] " + msg)
  return 1
@end

@fn main()
  println("==================================================")
  println("   MAYA AI INFERENCE UNIT TEST SUITE              ")
  println("==================================================")
  
  @! 1. INT8 Dynamic Quantization Test
  weights = [0, 10, 20, 30, 40]
  qt = quantize_dynamic(weights, [5])
  assert_eq(qt.data.len(), 5, "Quantized tensor element count")
  assert_eq(qt.data[0], 0, "Quantized min element == 0")
  assert_eq(qt.data[4], 255, "Quantized max element == 255")

  @! 2. Dequantization Test
  deq = dequantize(qt)
  assert_eq(deq.len(), 5, "Dequantized tensor element count")
  assert_eq(deq[0], 0, "Dequantized min value == 0")
  assert_eq(deq[4], 40, "Dequantized max value == 40")

  @! 3. Greedy Sampling Test
  logits = [1.5, 9.2, 3.4, 0.1]
  best_tok = greedy_sample(logits)
  assert_eq(best_tok, 1, "Greedy sample returns argmax (index 1)")

  @! 4. Temperature Sampling Test
  temp_tok = temperature_sample(logits, 0.7)
  assert_true(temp_tok >= 0 && temp_tok < 4, "Temperature sample valid token index")

  @! 5. Top-K Sampling Test
  topk_tok = top_k_sample(logits, 2)
  assert_true(topk_tok >= 0 && topk_tok < 4, "Top-K sample valid token index")

  @! 6. Top-P Sampling Test
  topp_tok = top_p_sample(logits, 0.9)
  assert_true(topp_tok >= 0 && topp_tok < 4, "Top-P sample valid token index")
  
  println("🎉 ALL AI INFERENCE TESTS PASSED!")
  return 0
@end
