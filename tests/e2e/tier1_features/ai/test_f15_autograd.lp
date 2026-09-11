@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: REVERSE-MODE AUTOGRAD ENGINE (F15)
@! File: tests/e2e/tier1_features/ai/test_f15_autograd.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"
import "universe/ai/autograd"

@fn run_all_f15_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature 15: Reverse-Mode Autograd Engine Coverage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! TC-F15-01: Leaf Tensor Initialization & requires_grad Configuration
  @! --------------------------------------------------------------------------
  total = total + 1
  l_t = leaf_tensor([2, 3], [2])
  c_t = constant_tensor([4, 5], [2])

  leaf_ok = (l_t.requires_grad == 1) && (l_t.creator_op == "leaf") && (l_t.grad.len() == 2) && (l_t.grad[0] == 0) && (l_t.grad[1] == 0)
  const_ok = (c_t.requires_grad == 0) && (c_t.creator_op == "constant")

  @if leaf_ok != 0 && const_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F15-01: Leaf tensor requires_grad & constant tensor creation")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F15-01: Leaf tensor initialization")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F15-02: Forward Computational DAG Tracking
  @! --------------------------------------------------------------------------
  total = total + 1
  t_a = leaf_tensor([2], [1])
  t_b = leaf_tensor([3], [1])
  t_c = tensor_mul(t_a, t_b) @! c = a * b
  t_d = tensor_add(t_c, t_a) @! d = c + a

  dag_c_ok = (t_c.requires_grad == 1) && (t_c.creator_op == "mul") && (t_c.parents.len() == 2)
  dag_d_ok = (t_d.requires_grad == 1) && (t_d.creator_op == "add") && (t_d.parents.len() == 2)

  @if dag_c_ok != 0 && dag_d_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F15-02: Forward DAG tracking with parents and creator_op")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F15-02: Forward DAG tracking")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F15-03: Polynomial Topological Backward Pass (dy/dx = 6x + 2)
  @! --------------------------------------------------------------------------
  total = total + 1
  @! y = 3*x^2 + 2*x + 1 with x = 2 -> dy/dx = 6(2) + 2 = 14
  px = leaf_tensor([2], [1])
  px2 = tensor_mul(px, px)
  p_term1 = tensor_scale(px2, 3)
  p_term2 = tensor_scale(px, 2)
  p_sum = tensor_add(p_term1, p_term2)
  p_one = constant_tensor([1], [1])
  py = tensor_add(p_sum, p_one)

  tensor_backward(py)

  grad_x = px.grad[0]
  @if grad_x == 14
    passed = passed + 1
    println("  [PASS] TC-F15-03: Topological backward pass on y = 3x^2 + 2x + 1 -> dy/dx = 14")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F15-03: Polynomial backward pass (Expected: 14, Got: " + grad_x.to_str() + ")")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F15-04: Matrix Multiplication (GEMM) Backprop Gradients
  @! --------------------------------------------------------------------------
  total = total + 1
  mA = leaf_tensor([1, 2, 3, 4], [2, 2])
  mB = leaf_tensor([5, 6, 7, 8], [2, 2])
  mC = tensor_matmul(mA, mB)
  mLoss = tensor_sum(mC, 0 - 1, 0) @! Scalar sum reduction

  tensor_backward(mLoss)

  @! dA = [[11, 15], [11, 15]]
  @! dB = [[4, 4], [6, 6]]
  da00 = mA.grad[0]
  da01 = mA.grad[1]
  da10 = mA.grad[2]
  da11 = mA.grad[3]

  db00 = mB.grad[0]
  db01 = mB.grad[1]
  db10 = mB.grad[2]
  db11 = mB.grad[3]

  da_ok = (da00 == 11) && (da01 == 15) && (da10 == 11) && (da11 == 15)
  db_ok = (db00 == 4) && (db01 == 4) && (db10 == 6) && (db11 == 6)

  @if da_ok != 0 && db_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F15-04: MatMul GEMM backprop gradients for dA and dB")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F15-04: MatMul GEMM backprop")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F15-05: Unbroadcasting Gradients & MSE Loss Autograd
  @! --------------------------------------------------------------------------
  total = total + 1
  nW = leaf_tensor([2, 3], [2, 1])
  nB = leaf_tensor([1], [1])
  nX = constant_tensor([1, 1], [1, 2])

  nY_pred = tensor_matmul(nX, nW) @! [1, 1] with val 5
  nY_pred_b = tensor_add(nY_pred, nB) @! [1, 1] with val 6
  nTarget = constant_tensor([10], [1, 1])
  nMSE = tensor_mse_loss(nY_pred_b, nTarget) @! (6 - 10)^2 = 16

  tensor_backward(nMSE)

  mse_loss_val = nMSE.data[0]
  loss_val_ok = (mse_loss_val == 16)
  w_grad_non_zero = (nW.grad[0] != 0) && (nW.grad[1] != 0)
  b_grad_non_zero = (nB.grad[0] != 0)

  @! Verify tensor_zero_grad resets gradient buffers
  tensor_zero_grad(nW)
  tensor_zero_grad(nB)
  w_zero_ok = (nW.grad[0] == 0) && (nW.grad[1] == 0)
  b_zero_ok = (nB.grad[0] == 0)

  @if loss_val_ok != 0 && w_grad_non_zero != 0 && b_grad_non_zero != 0 && w_zero_ok != 0 && b_zero_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F15-05: Unbroadcast gradient accumulation, MSE loss & zero_grad reset")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F15-05: MSE Loss autograd & zero_grad")
  @end

  println("=================================================================")
  println("📊 Feature 15 Summary: " + passed.to_str() + "/" + total.to_str() + " tests passed")
  println("=================================================================")

  @if failed > 0
    return 1
  @end
  return 0
@end

@fn main()
  return run_all_f15_tests()
@end
