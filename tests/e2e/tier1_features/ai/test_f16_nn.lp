@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: NEURAL NETWORK ARCHITECTURE (F16)
@! File: tests/e2e/tier1_features/ai/test_f16_nn.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"
import "universe/ai/autograd"
import "universe/ai/nn"

@fn run_all_f16_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature 16: Neural Network Architecture Coverage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! TC-F16-01: Linear Layer Forward & Backward Pass
  @! --------------------------------------------------------------------------
  total = total + 1
  lin = linear_new(3, 2)
  lin.weight.data = [1, 2, 3, 4, 5, 6] @! shape [3, 2]
  lin.bias.data = [10, 20]             @! shape [2]

  x_in = tensor_new([1, 1, 1], [1, 3])
  y_out = linear_forward(lin, x_in)

  @! y[0] = 1*1 + 1*3 + 1*5 + 10 = 19
  @! y[1] = 1*2 + 1*4 + 1*6 + 20 = 32
  fwd_shape_ok = (y_out.shape.len() == 2) && (y_out.shape[0] == 1) && (y_out.shape[1] == 2)
  y0 = tensor_get(y_out, [0, 0])
  y1 = tensor_get(y_out, [0, 1])
  fwd_vals_ok = (y0 == 19) && (y1 == 32)

  @! Backward pass with grad_out [1, 1]
  grad_out = tensor_new([1, 1], [1, 2])
  dx = linear_backward(lin, x_in, grad_out)
  bwd_shape_ok = (dx.shape.len() == 2) && (dx.shape[0] == 1) && (dx.shape[1] == 3)
  params = linear_parameters(lin)
  params_ok = (params.len() == 2)

  @if fwd_shape_ok != 0 && fwd_vals_ok != 0 && bwd_shape_ok != 0 && params_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F16-01: Linear layer forward [1,3]->[1,2], backward dx [1,3], and params")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F16-01: Linear layer forward & backward")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F16-02: LayerNorm Normalization & Stabilization
  @! --------------------------------------------------------------------------
  total = total + 1
  ln = layernorm_new(4, 1.0)
  ln_params = layernorm_parameters(ln)
  ln_params_ok = (ln_params.len() == 2) @! gamma, beta

  ln_x = tensor_new([10, 20, 30, 40], [1, 4])
  ln_y = layernorm_forward(ln, ln_x)
  ln_shape_ok = (ln_y.shape.len() == 2) && (ln_y.shape[0] == 1) && (ln_y.shape[1] == 4)

  @! LayerNorm centers around 0: y0 < 0 and y3 > 0
  ly0 = tensor_get(ln_y, [0, 0])
  ly3 = tensor_get(ln_y, [0, 3])
  norm_props_ok = (ly0 < 0) && (ly3 > 0)

  @if ln_params_ok != 0 && ln_shape_ok != 0 && norm_props_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F16-02: LayerNorm forward normalization and centering")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F16-02: LayerNorm normalization")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F16-03: MultiHeadAttention (MHA) QKV Projections & Causal Masking
  @! --------------------------------------------------------------------------
  total = total + 1
  mha = multihead_attention_new(8, 2)
  mha_p = multihead_attention_parameters(mha)
  mha_p_ok = (mha_p.len() == 8) @! Q, K, V, Out weights and biases

  @! x: [batch=1, seq=4, embed=8]
  x_seq_data = []
  i = 0
  @while i < 32
    x_seq_data = x_seq_data.push(i + 1)
    i = i + 1
  @end
  x_seq = tensor_new(x_seq_data, [1, 4, 8])
  mha_out = multihead_attention_forward(mha, x_seq, 1) @! with causal mask
  mha_shape_ok = (mha_out.shape.len() == 3) && (mha_out.shape[0] == 1) && (mha_out.shape[1] == 4) && (mha_out.shape[2] == 8)

  @if mha_p_ok != 0 && mha_shape_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F16-03: MultiHeadAttention causal masked forward [1,4,8]->[1,4,8] (8 params)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F16-03: MultiHeadAttention")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F16-04: Loss Functions (MSE & Cross-Entropy)
  @! --------------------------------------------------------------------------
  total = total + 1
  pred = tensor_new([2, 4, 6], [1, 3])
  target = tensor_new([2, 5, 4], [1, 3])
  res_mse = loss_mse(pred, target)
  @! MSE loss: ((2-2)^2 + (4-5)^2 + (6-4)^2) / 3 = (0 + 1 + 4) / 3 = 1
  mse_ok = (res_mse.loss.data.len() > 0) && (res_mse.grad.shape.len() == 2) && (res_mse.grad.shape[1] == 3)

  logits = tensor_new([10, 50, 100], [1, 3])
  target_oh = tensor_new([0, 0, 1000], [1, 3])
  res_ce = loss_cross_entropy(logits, target_oh)
  ce_ok = (res_ce.loss.data.len() > 0) && (res_ce.grad.shape[1] == 3)

  @if mse_ok != 0 && ce_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F16-04: Loss functions (MSE loss and CrossEntropy loss)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F16-04: Loss functions")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F16-05: Optimizers (SGD with Momentum & AdamW Step Updates)
  @! --------------------------------------------------------------------------
  total = total + 1
  p_sgd = leaf_tensor([100, 200], [2])
  p_sgd.grad = [10, 20]
  sgd = optimizer_sgd_create([p_sgd], 10, 90, 0)
  optimizer_sgd_step([p_sgd], 10, 90, 0, sgd.velocities)
  @! After step with positive grad, parameter values decrease
  sgd_ok = (p_sgd.data[0] < 100) && (p_sgd.data[1] < 200)

  p_adam = leaf_tensor([1000, 2000], [2])
  p_adam.grad = [50, 100]
  adamw = optimizer_adamw_create([p_adam], 100, 900, 999, 1, 10)
  optimizer_adamw_step(adamw, [p_adam], 100, 900, 999, 1, 10)
  adamw_ok = (p_adam.data[0] < 1000) && (p_adam.data[1] < 2000) && (adamw.t == 1)

  @if sgd_ok != 0 && adamw_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F16-05: Optimizer steps (SGD momentum & AdamW moment updates)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F16-05: Optimizers")
  @end

  println("=================================================================")
  println("📊 Feature 16 Summary: " + passed.to_str() + "/" + total.to_str() + " tests passed")
  println("=================================================================")

  @if failed > 0
    return 1
  @end
  return 0
@end

@fn main()
  return run_all_f16_tests()
@end
