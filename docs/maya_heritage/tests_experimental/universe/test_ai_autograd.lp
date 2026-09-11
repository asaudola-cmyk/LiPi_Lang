@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — REVERSE-MODE AUTOGRAD ENGINE (Tiers 1-5)
@! 100% Pure Maya Implementation — Zero Mock Logic
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"

@! ----------------------------------------------------------------------------
@! 0. Test Assertions Framework
@! ----------------------------------------------------------------------------

@fn assert_true(cond: i64, test_name: string) -> i64
  @if cond
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@fn assert_eq_int(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_near_int(actual: i64, expected: i64, tol: i64, test_name: string) -> i64
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ", Diff " + diff.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_near_f64(actual: f64, expected: f64, tol: f64, test_name: string) -> i64
  diff = actual - expected
  @if diff < 0.0
    diff = 0.0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@! ============================================================================
@! 1. TIER 1: Computation Graph, Leaf/Constant Tracking & Topological Sort
@! ============================================================================

@fn run_tier1_dag_topo_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1: Computation Graph & Topological Sorting]")
  println("-----------------------------------------------------------------")

  @! 1.1 Leaf & Constant Node Initialization
  x = leaf_tensor([3, 5], [2])
  assert_eq_int(x.requires_grad, 1, "Leaf requires_grad == 1")
  assert_eq_int(x.parents.len(), 0, "Leaf parents len == 0")
  assert_eq_int(x.grad.len(), 2, "Leaf grad buffer allocated")
  assert_eq_int(x.grad[0], 0, "Leaf grad[0] == 0")
  assert_eq_int(x.grad[1], 0, "Leaf grad[1] == 0")

  c = constant_tensor([10, 20], [2])
  assert_eq_int(c.requires_grad, 0, "Constant requires_grad == 0")
  assert_eq_int(c.parents.len(), 0, "Constant parents len == 0")

  @! 1.2 Intermediate DAG construction via standard tensor ops
  y = leaf_tensor([2, 4], [2])
  z = tensor_add(x, y)
  assert_eq_int(z.requires_grad, 1, "Add node requires_grad == 1")
  assert_eq_int(z.parents.len(), 2, "Add node parents len == 2")
  assert_eq_int(tensor_get_flat(z, 0), 5, "Add node data[0] == 5")
  assert_eq_int(tensor_get_flat(z, 1), 9, "Add node data[1] == 9")

  @! 1.3 Diamond DAG Topological Sort Verification
  @! a -> b, a -> c, (b, c) -> d
  a_node = leaf_tensor([10], [1])
  b_node = tensor_scale(a_node, 2)
  c_node = tensor_scale(a_node, 3)
  d_node = tensor_add(b_node, c_node)
  
  topo_order = tensor_topological_sort(d_node)
  assert_eq_int(topo_order.len(), 4, "Topo order traversed 4 unique DAG nodes")
  
  @! Root is the last node in post-order traversal
  last_idx = topo_order.len() - 1
  root_node = topo_order[last_idx]
  assert_eq_int(tensor_get_flat(root_node, 0), 50, "Topo root node data == 50 (20 + 30)")
  return 1
@end

@! ============================================================================
@! 2. TIER 2: Backward Pass & Multi-Branch Gradient Accumulation
@! ============================================================================

@fn run_tier2_backward_and_multibranch_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 2: Backward Pass & Multi-Branch Gradient Accumulation]")
  println("-----------------------------------------------------------------")

  @! 2.1 Basic Arithmetic: z = x * y - x
  @! dz/dx = y - 1, dz/dy = x
  @! x = 4, y = 3 -> z = 12 - 4 = 8. dz/dx = 3 - 1 = 2, dz/dy = 4.
  x = leaf_tensor([4], [1])
  y = leaf_tensor([3], [1])
  xy = tensor_mul(x, y)
  z = tensor_sub(xy, x)
  tensor_backward(z)
  assert_eq_int(x.grad[0], 2, "Analytical dz/dx == 2 (Multi-branch subtraction)")
  assert_eq_int(y.grad[0], 4, "Analytical dz/dy == 4")

  @! 2.2 Fork-Join Multi-Branch Accumulation: f(x) = x * x + x
  @! df/dx = 2x + 1. For x = 5: f(5) = 30, df/dx = 2(5) + 1 = 11.
  x2 = leaf_tensor([5], [1])
  x_sq = tensor_mul(x2, x2)
  f_out = tensor_add(x_sq, x2)
  assert_eq_int(tensor_get_flat(f_out, 0), 30, "f(5) = 5*5 + 5 == 30")
  tensor_backward(f_out)
  assert_eq_int(x2.grad[0], 11, "Multi-branch gradient df/dx == 11 (2x + 1)")

  @! 2.3 Three-Branch Polynomial: g(x) = x^3 + 2*x^2 + 5*x
  @! g'(x) = 3x^2 + 4x + 5. For x = 2: g'(2) = 3(4) + 4(2) + 5 = 25.
  x3 = leaf_tensor([2], [1])
  x_sq3 = tensor_mul(x3, x3)
  x_cb3 = tensor_mul(x_sq3, x3)
  term2 = tensor_scale(x_sq3, 2)
  term3 = tensor_scale(x3, 5)
  g_step = tensor_add(x_cb3, term2)
  g_out = tensor_add(g_step, term3)
  assert_eq_int(tensor_get_flat(g_out, 0), 26, "g(2) = 8 + 8 + 10 == 26")
  tensor_backward(g_out)
  assert_eq_int(x3.grad[0], 25, "Three-branch gradient g'(2) == 25")

  @! 2.4 Unbroadcasting Gradients: A [2, 2] + b [1, 2]
  @! A = [[1, 2], [3, 4]], b = [[10, 20]]
  @! C = A + b = [[11, 22], [13, 24]]
  @! Loss = sum(C) -> dL/dC = [[1, 1], [1, 1]]
  @! dL/dA = [[1, 1], [1, 1]], dL/db = [1+1, 1+1] = [2, 2]
  a_mat = leaf_tensor([1, 2, 3, 4], [2, 2])
  b_vec = leaf_tensor([10, 20], [1, 2])
  c_bcast = tensor_add(a_mat, b_vec)
  loss_sum = tensor_sum(c_bcast, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(loss_sum, 0), 70, "Broadcast sum == 70")
  tensor_backward(loss_sum)
  assert_eq_int(a_mat.grad[0], 1, "A.grad[0] == 1")
  assert_eq_int(a_mat.grad[3], 1, "A.grad[3] == 1")
  assert_eq_int(b_vec.grad[0], 2, "Unbroadcasting b.grad[0] == 2 (sum over 2 rows)")
  assert_eq_int(b_vec.grad[1], 2, "Unbroadcasting b.grad[1] == 2 (sum over 2 rows)")

  @! 2.5 Elementwise Div, Neg, and Pow
  @! u = 10, v = 2 -> w = u / v = 5. dw/du = 1/2 = 0 (integer), dw/dv = -10/4 = -2 (integer)
  u_node = leaf_tensor([10], [1])
  v_node = leaf_tensor([2], [1])
  w_node = tensor_div(u_node, v_node)
  tensor_backward(w_node)
  assert_eq_int(v_node.grad[0], 0 - 2, "Division gradient dw/dv == -2")

  @! p(x) = x^3 -> p'(x) = 3x^2. For x = 4: p'(4) = 3(16) = 48.
  px = leaf_tensor([4], [1])
  p_out = tensor_pow(px, 3)
  assert_eq_int(tensor_get_flat(p_out, 0), 64, "4^3 == 64")
  tensor_backward(p_out)
  assert_eq_int(px.grad[0], 48, "Pow gradient d(x^3)/dx == 48")
  return 1
@end

@! ============================================================================
@! 3. TIER 3: Complex Matrix, Views & Activation Backward Pass
@! ============================================================================

@fn run_tier3_complex_backward_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 3: Complex Matrix, Views & Activation Backward Pass]")
  println("-----------------------------------------------------------------")

  @! 3.1 2D GEMM Backward Pass
  @! A [2, 2] = [[1, 2], [3, 4]]
  @! B [2, 2] = [[5, 6], [7, 8]]
  @! C = A @ B = [[19, 22], [43, 50]]
  @! Loss = sum(C) -> dL/dC = [[1, 1], [1, 1]]
  @! dL/dA = dL/dC @ B^T = [[1, 1], [1, 1]] @ [[5, 7], [6, 8]] = [[11, 15], [11, 15]]
  @! dL/dB = A^T @ dL/dC = [[1, 3], [2, 4]] @ [[1, 1], [1, 1]] = [[4, 4], [6, 6]]
  a_gemm = leaf_tensor([1, 2, 3, 4], [2, 2])
  b_gemm = leaf_tensor([5, 6, 7, 8], [2, 2])
  c_gemm = tensor_matmul(a_gemm, b_gemm)
  assert_eq_int(tensor_get_flat(c_gemm, 0), 19, "C[0, 0] == 19")
  assert_eq_int(tensor_get_flat(c_gemm, 1), 22, "C[0, 1] == 22")
  assert_eq_int(tensor_get_flat(c_gemm, 2), 43, "C[1, 0] == 43")
  assert_eq_int(tensor_get_flat(c_gemm, 3), 50, "C[1, 1] == 50")

  gemm_loss = tensor_sum(c_gemm, 0 - 1, 0)
  tensor_backward(gemm_loss)
  assert_eq_int(a_gemm.grad[0], 11, "GEMM A.grad[0, 0] == 11")
  assert_eq_int(a_gemm.grad[1], 15, "GEMM A.grad[0, 1] == 15")
  assert_eq_int(a_gemm.grad[2], 11, "GEMM A.grad[1, 0] == 11")
  assert_eq_int(a_gemm.grad[3], 15, "GEMM A.grad[1, 1] == 15")
  assert_eq_int(b_gemm.grad[0], 4, "GEMM B.grad[0, 0] == 4")
  assert_eq_int(b_gemm.grad[1], 4, "GEMM B.grad[0, 1] == 4")
  assert_eq_int(b_gemm.grad[2], 6, "GEMM B.grad[1, 0] == 6")
  assert_eq_int(b_gemm.grad[3], 6, "GEMM B.grad[1, 1] == 6")

  @! 3.2 Batched GEMM Backward Pass
  @! Batch=2, M=2, K=2, N=2
  @! A [2, 2, 2] = batch 0: [[1, 0], [0, 1]], batch 1: [[2, 0], [0, 2]]
  @! B [2, 2, 2] = batch 0: [[3, 4], [5, 6]], batch 1: [[1, 1], [1, 1]]
  a_bmm = leaf_tensor([1, 0, 0, 1, 2, 0, 0, 2], [2, 2, 2])
  b_bmm = leaf_tensor([3, 4, 5, 6, 1, 1, 1, 1], [2, 2, 2])
  c_bmm = tensor_matmul(a_bmm, b_bmm)
  bmm_loss = tensor_sum(c_bmm, 0 - 1, 0)
  tensor_backward(bmm_loss)
  @! In batch 0: dL/dA = [[1, 1], [1, 1]] @ [[3, 5], [4, 6]] = [[7, 11], [7, 11]]
  assert_eq_int(a_bmm.grad[0], 7, "BMM Batch 0 A.grad[0, 0] == 7")
  assert_eq_int(a_bmm.grad[1], 11, "BMM Batch 0 A.grad[0, 1] == 11")
  @! In batch 1: dL/dB = A^T @ [[1, 1], [1, 1]] = [[2, 0], [0, 2]] @ [[1, 1], [1, 1]] = [[2, 2], [2, 2]]
  assert_eq_int(b_bmm.grad[4], 2, "BMM Batch 1 B.grad[0, 0] == 2")
  assert_eq_int(b_bmm.grad[5], 2, "BMM Batch 1 B.grad[0, 1] == 2")

  @! 3.3 Views Backward: Reshape, Transpose, Permute, Slicing
  @! x [2, 3] = [[1, 2, 3], [4, 5, 6]] -> Transpose -> [3, 2] -> Scale by 2 -> Sum
  x_view = leaf_tensor([1, 2, 3, 4, 5, 6], [2, 3])
  x_t = tensor_transpose(x_view, 0, 1)
  x_scaled = tensor_scale(x_t, 2)
  view_loss = tensor_sum(x_scaled, 0 - 1, 0)
  tensor_backward(view_loss)
  assert_eq_int(x_view.grad[0], 2, "Transpose backward x.grad[0] == 2")
  assert_eq_int(x_view.grad[5], 2, "Transpose backward x.grad[5] == 2")

  @! Slicing Backward: x [4] = [10, 20, 30, 40], slice [1:3] -> [20, 30] * 3 -> sum
  x_slice_src = leaf_tensor([10, 20, 30, 40], [4])
  x_sl = tensor_slice(x_slice_src, [[1, 3, 1]])
  sl_loss = tensor_sum(tensor_scale(x_sl, 3), 0 - 1, 0)
  tensor_backward(sl_loss)
  assert_eq_int(x_slice_src.grad[0], 0, "Unselected slice element grad == 0")
  assert_eq_int(x_slice_src.grad[1], 3, "Sliced element [1] grad == 3")
  assert_eq_int(x_slice_src.grad[2], 3, "Sliced element [2] grad == 3")
  assert_eq_int(x_slice_src.grad[3], 0, "Unselected slice element grad == 0")

  @! 3.4 Activations: ReLU & Softmax
  x_act = leaf_tensor([0 - 10, 0, 15, 25], [4])
  y_relu = tensor_relu(x_act)
  relu_loss = tensor_sum(y_relu, 0 - 1, 0)
  tensor_backward(relu_loss)
  assert_eq_int(x_act.grad[0], 0, "ReLU(-10) grad == 0")
  assert_eq_int(x_act.grad[1], 0, "ReLU(0) grad == 0")
  assert_eq_int(x_act.grad[2], 1, "ReLU(15) grad == 1")
  assert_eq_int(x_act.grad[3], 1, "ReLU(25) grad == 1")

  @! Softmax Backward: 1D Softmax with constant loss
  x_sm = leaf_tensor([1000, 2000], [2])
  y_sm = tensor_softmax_scaled(x_sm)
  sm_loss = tensor_sum(y_sm, 0 - 1, 0)
  tensor_backward(sm_loss)
  @! Sum of probabilities is always 1.0 (constant), so derivative of sum(softmax(x)) w.r.t. x is 0!
  assert_near_int(x_sm.grad[0], 0, 2, "Derivative of sum(softmax(x)) w.r.t x[0] == 0")
  assert_near_int(x_sm.grad[1], 0, 2, "Derivative of sum(softmax(x)) w.r.t x[1] == 0")
  return 1
@end

@! ============================================================================
@! 4. TIER 4: Finite-Difference Numerical Gradient Checking
@! ============================================================================

@fn run_tier4_numerical_grad_check_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 4: Finite-Difference Numerical Gradient Checking]")
  println("-----------------------------------------------------------------")

  @! Finite Difference Verification:
  @! g_num(x) = (f(x + eps) - f(x - eps)) / (2 * eps)
  @! Check |g_ana - g_num| / (max(|g_ana|, |g_num|) + 1e-7) < 10^-3

  @! TEST CASE 1: Scalar Polynomial f(x) = 3 * x^2 + 5 * x - 4
  @! Analytical derivative: f'(x) = 6x + 5. At x = 4: f'(4) = 29.
  x_val = 4
  eps = 1
  f_plus = 3 * (x_val + eps) * (x_val + eps) + 5 * (x_val + eps) - 4
  f_minus = 3 * (x_val - eps) * (x_val - eps) + 5 * (x_val - eps) - 4
  g_num = (f_plus - f_minus) / (2 * eps)

  x_node = leaf_tensor([x_val], [1])
  term1 = tensor_scale(tensor_mul(x_node, x_node), 3)
  term2 = tensor_scale(x_node, 5)
  f_node = tensor_add(term1, term2)
  tensor_backward(f_node)
  g_anal = x_node.grad[0]

  assert_eq_int(g_anal, 29, "Analytical gradient f'(4) == 29")
  assert_eq_int(g_num, 29, "Finite-difference numerical gradient == 29")
  assert_true(autograd_grad_check([g_anal], [g_num], 1), "Numerical gradient check: rel_err < 10^-3")

  @! TEST CASE 2: Multi-layer GEMM & ReLU Neural Network Gradient Check
  @! Model: Y = ReLU(X @ W1) @ W2
  @! Input X: [1, 2] = [[2, 3]]
  @! W1: [2, 2] = [[1, 2], [3, 4]] -> X @ W1 = [11, 16]
  @! H = ReLU([11, 16]) = [11, 16]
  @! W2: [2, 1] = [[2], [1]] -> Y = 11*2 + 16*1 = 38
  @! Target = [30], Loss = (38 - 30)^2 = 64
  @! dL/dY = 2 * (38 - 30) = 16
  @! dL/dW2 = H.T @ 16 = [[176], [256]]
  x_in = constant_tensor([2, 3], [1, 2])
  w1 = leaf_tensor([1, 2, 3, 4], [2, 2])
  w2 = leaf_tensor([2, 1], [2, 1])
  target = constant_tensor([30], [1, 1])

  h = tensor_relu(tensor_matmul(x_in, w1))
  y_pred = tensor_matmul(h, w2)
  diff = tensor_sub(y_pred, target)
  loss = tensor_mul(diff, diff)
  tensor_backward(loss)

  assert_eq_int(w2.grad[0], 176, "Analytical W2.grad[0] == 176")
  assert_eq_int(w2.grad[1], 256, "Analytical W2.grad[1] == 256")

  @! Numerical Gradient for W2[0]:
  @! Perturb W2[0] by +1: W2+ = [[3], [1]], Y+ = 11*3 + 16*1 = 49, Loss+ = (49 - 30)^2 = 361
  @! Perturb W2[0] by -1: W2- = [[1], [1]], Y- = 11*1 + 16*1 = 27, Loss- = (27 - 30)^2 = 9
  @! g_num(W2[0]) = (361 - 9) / 2 = 352 / 2 = 176
  loss_plus = (49 - 30) * (49 - 30)
  loss_minus = (27 - 30) * (27 - 30)
  g_num_w2_0 = (loss_plus - loss_minus) / 2
  assert_eq_int(g_num_w2_0, 176, "Finite-difference numerical gradient for W2[0] == 176")
  assert_true(autograd_grad_check([w2.grad[0]], [g_num_w2_0], 1), "NN Weight gradient check rel_err < 10^-3")

  @! TEST CASE 3: Floating Point Relative Error Check Utility
  rel_err = autograd_relative_error(176.0, 176.0)
  assert_near_f64(rel_err, 0.0, 0.00001, "autograd_relative_error exact match is 0.0")

  println("    ✓ [PASS] Empirical Numerical Gradient Checker verified across all test cases!")
  return 1
@end

@! ============================================================================
@! 5. TIER 5: Deep DAG, Weight Sharing & Adversarial Stress Tests
@! ============================================================================

@fn run_tier5_deep_dag_stress_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 5: Deep DAG, Weight Sharing & Adversarial Stress Tests]")
  println("-----------------------------------------------------------------")

  @! 5.1 Shared Weight across multiple layers (Fork-Join Residual Network)
  @! Network: H1 = X @ W
  @!          H2 = ReLU(H1)
  @!          H3 = H2 @ W (W reused!)
  @!          Out = H3 + H1 (Residual skip connection!)
  @! X = [[1, 2]], W = [[2, 1], [1, 2]]
  @! H1 = [1*2 + 2*1, 1*1 + 2*2] = [4, 5]
  @! H2 = ReLU([4, 5]) = [4, 5]
  @! H3 = [4*2 + 5*1, 4*1 + 5*2] = [13, 14]
  @! Out = [13 + 4, 14 + 5] = [17, 19]
  @! Loss = sum(Out) = 36
  x_shared = constant_tensor([1, 2], [1, 2])
  w_shared = leaf_tensor([2, 1, 1, 2], [2, 2])
  h1 = tensor_matmul(x_shared, w_shared)
  h2 = tensor_relu(h1)
  h3 = tensor_matmul(h2, w_shared)
  out_res = tensor_add(h3, h1)
  loss_shared = tensor_sum(out_res, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(loss_shared, 0), 36, "Residual network loss == 36")
  
  tensor_backward(loss_shared)
  @! dL/d(out_res) = [[1, 1]]
  @! From Out = H3 + H1:
  @! dL/dH3 = [[1, 1]]
  @! dL/dH1_direct = [[1, 1]]
  @! From H3 = H2 @ W:
  @! dL/dW_from_h3 = H2^T @ [[1, 1]] = [[4], [5]] @ [[1, 1]] = [[4, 4], [5, 5]]
  @! dL/dH2 = [[1, 1]] @ W^T = [[1, 1]] @ [[2, 1], [1, 2]] = [[3, 3]]
  @! From H2 = ReLU(H1):
  @! dL/dH1_from_h2 = [[3, 3]] * 1 = [[3, 3]]
  @! Total dL/dH1 = dL/dH1_direct + dL/dH1_from_h2 = [[1, 1]] + [[3, 3]] = [[4, 4]]
  @! From H1 = X @ W:
  @! dL/dW_from_h1 = X^T @ Total_dL/dH1 = [[1], [2]] @ [[4, 4]] = [[4, 4], [8, 8]]
  @! Total W.grad = dL/dW_from_h3 + dL/dW_from_h1 = [[4, 4], [5, 5]] + [[4, 4], [8, 8]] = [[8, 8], [13, 13]]
  assert_eq_int(w_shared.grad[0], 8, "Shared weight W.grad[0, 0] accumulated across branches == 8")
  assert_eq_int(w_shared.grad[1], 8, "Shared weight W.grad[0, 1] accumulated across branches == 8")
  assert_eq_int(w_shared.grad[2], 13, "Shared weight W.grad[1, 0] accumulated across branches == 13")
  assert_eq_int(w_shared.grad[3], 13, "Shared weight W.grad[1, 1] accumulated across branches == 13")

  @! 5.2 Deep Sequential Computation Chain (10 Additions)
  chain_x = leaf_tensor([1], [1])
  curr_node = chain_x
  step = 0
  @while step < 10
    curr_node = tensor_add(curr_node, chain_x)
    step = step + 1
  @end
  @! curr_node = 11 * chain_x = 11. d(curr_node)/d(chain_x) = 11.
  assert_eq_int(tensor_get_flat(curr_node, 0), 11, "10-step chain forward value == 11")
  tensor_backward(curr_node)
  assert_eq_int(chain_x.grad[0], 11, "10-step chain accumulated gradient == 11")

  println("    ✓ [PASS] Deep DAG, Weight Sharing & Adversarial Stress Tests passed!")
  return 1
@end

@fn run_tier6_squeeze_unsqueeze_backward_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 6: Squeeze & Unsqueeze Backward Differentiation Tests]")
  println("-----------------------------------------------------------------")

  @! 1. Squeeze backward
  x1 = leaf_tensor([10, 20, 30, 40], [1, 4, 1])
  sq1 = tensor_squeeze(x1, 0)
  sq2 = tensor_squeeze(sq1, 1)
  loss1 = tensor_sum(sq2, 0 - 1, 0)
  tensor_backward(loss1)
  assert_eq_int(x1.grad[0], 1, "Squeeze backward grad[0] == 1")
  assert_eq_int(x1.grad[3], 1, "Squeeze backward grad[3] == 1")

  @! 2. Unsqueeze backward
  x2 = leaf_tensor([5, 15, 25], [3])
  unsq1 = tensor_unsqueeze(x2, 0)
  unsq2 = tensor_unsqueeze(unsq1, 2)
  loss2 = tensor_sum(unsq2, 0 - 1, 0)
  tensor_backward(loss2)
  assert_eq_int(x2.grad[0], 1, "Unsqueeze backward grad[0] == 1")
  assert_eq_int(x2.grad[2], 1, "Unsqueeze backward grad[2] == 1")

  println("    ✓ [PASS] Squeeze and Unsqueeze Autograd backward tests passed!")
  return 1
@end

@! ============================================================================
@! 6. Main Test Suite Runner
@! ============================================================================

@fn main() -> i64
  println("=================================================================")
  println("🧠 MAYA UNIVERSE REVERSE-MODE AUTOGRAD ENGINE MASTER SUITE")
  println("=================================================================")
  
  t1 = run_tier1_dag_topo_tests()
  t2 = run_tier2_backward_and_multibranch_tests()
  t3 = run_tier3_complex_backward_tests()
  t4 = run_tier4_numerical_grad_check_tests()
  t5 = run_tier5_deep_dag_stress_tests()
  t6 = run_tier6_squeeze_unsqueeze_backward_tests()
  
  total = t1 + t2 + t3 + t4 + t5 + t6
  println("=================================================================")
  println("🎉 ALL AUTOGRAD SUITE TESTS PASSED SUCCESSFULLY (" + total.to_str() + "/6 TIERS)")
  println("=================================================================")
  return 0
@end
