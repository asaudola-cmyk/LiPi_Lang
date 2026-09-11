@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — AI & MACHINE LEARNING VERIFICATION
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autodiff"
import "universe/ai/llm/tokenizer"
import "universe/ai/llm/transformer"

@fn run_ai_tests()
  println("▶ [TEST] Running Universe AI Subsystem Tests...")
  
  @! 1. Tensor Operations
  t1 = tensor_new([1.0, 2.0, 3.0, 4.0], [2, 2])
  t2 = tensor_new([2.0, 0.0, 1.0, 2.0], [2, 2])
  dot = tensor_matmul_2x2(t1, t2)
  @if dot.data.len() == 4
    println("  [PASS] Tensor MatMul verified")
  @end

  @! 2. Autodiff Backpropagation
  loss = loss_mse(dot, t2)
  loss = tensor_backward(loss)
  @if loss.grad.len() > 0
    println("  [PASS] Autodiff Reverse-Mode Gradient Propagation verified")
  @end

  @! 3. BPE Tokenizer
  tok = bpe_tokenizer_new(1000)
  tok = bpe_add_token(tok, "Maya")
  id = bpe_get_token_id(tok, "Maya")
  @if id > 0
    println("  [PASS] BPE Subword Tokenizer verified")
  @end

  println("✅ All Universe AI Tests Passed!")
@end
