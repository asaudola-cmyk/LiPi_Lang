// ==============================================================================
// 🧪 LIPI TEST: SOVEREIGN LIPI-TORCH DEEP LEARNING SUITE
// File: aati/lipi_torch/tests/test_torch.lp
// 100% Pure Lipi — Zero External Python/C Dependencies
// ==============================================================================

import "utso/io"
import "utso/string"
import "aati/lipi_torch/src/torch"

@fn assert_true(cond: i64, msg: string) -> i64
  @if cond == 0
    println(str_concat("  ❌ FAIL: ", msg))
    exit(1)
  @end
  println(str_concat("  ✔ ", msg))
  return 1
@end

@fn main() -> i64
  println("=================================================================")
  println("🧠 LIPI-TORCH SOVEREIGN DEEP LEARNING FRAMEWORK TEST SUITE 🧠")
  println("=================================================================")

  // 1. Tensor Allocation & Dimensions
  println("▶ [1/4] Testing Torch Tensor Constructors...")
  x = torch_tensor([1.0, 2.0, 3.0, 4.0], [2, 2])
  assert_true(x.size == 4, "2x2 Tensor size is 4")
  assert_true(x.ndim == 2, "Tensor rank is 2")
  assert_true(x.requires_grad == 1, "Requires grad is active")

  // 2. Linear Layer & Forward Pass
  println("▶ [2/4] Testing Linear Layer Forward Transformation...")
  linear = torch_linear_new(2, 2)
  out = torch_linear_forward(linear, x)
  assert_true(out.size == 4, "Output tensor size is 4")

  // 3. Loss & Reverse-Mode Differentiation (Autograd)
  println("▶ [3/4] Testing Loss Computation & Reverse-Mode Autograd Backward...")
  target = torch_constant([1.0, 1.0, 1.0, 1.0], [2, 2])
  loss = torch_mse_loss(out, target)
  assert_true(loss.size == 1, "Scalar MSE loss has size 1")

  torch_backward(loss)
  assert_true(linear.weight.grad.len() == 4, "Weight gradient allocated and accumulated")
  assert_true(linear.bias.grad.len() == 2, "Bias gradient allocated and accumulated")

  // 4. SGD Optimization Step & Gradient Zeroing
  println("▶ [4/4] Testing SGD Parameter Descent & Zero-Grad...")
  w_before = linear.weight.data[0]
  params = [linear.weight, linear.bias]
  opt = torch_sgd_new(params, 1)
  torch_sgd_step(opt)
  w_after = linear.weight.data[0]
  
  // Weight should change after gradient step
  assert_true(w_before != w_after, "Weight updated by SGD optimizer")

  torch_zero_grad(params)
  assert_true(linear.weight.grad[0] == 0.0, "Weight gradient flushed to 0.0")

  println("\n🎉 ALL LIPI-TORCH DEEP LEARNING TESTS PASSED SUCCESSFULLY!")
  return 0
@end
