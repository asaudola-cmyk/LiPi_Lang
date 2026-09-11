@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: FIXED-POINT MULTI-LAYER NEURAL NETWORK
@! File: tests/e2e/tier4_applications/test_app_neural_network.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct MLPNetwork
  w_ih: 0   @! 2x4 weights: [ [w00..w03], [w10..w13] ]
  b_h: 0    @! 4 hidden biases
  w_ho: 0   @! 4x1 output weights
  b_o: 0     @! 1 output bias
@end

@struct ForwardPass
  h_acts: 0
  out_act: 0
@end

@fn fp_scale() return 65536 @end

@fn fp_mul(a, b)
  return (a * b) / 65536
@end

@fn fp_div(a, b)
  @if b == 0 return 0 @end
  return (a * 65536) / b
@end

@fn fp_sigmoid(x)
  @! Fast piecewise linear / sigmoid approximation in Q16.16
  @! sigma(x) = clamp(32768 + x / 4, 0, 65536)
  half = 32768
  approx = half + (x / 4)
  @if approx < 0 return 0 @end
  @if approx > 65536 return 65536 @end
  return approx
@end

@fn fp_sigmoid_derivative(act)
  @! sigma'(x) = act * (1.0 - act)
  one = 65536
  return fp_mul(act, one - act)
@end

@fn mlp_new()
  @! Initial weights for 2x4 hidden layer in Q16.16
  w_ih = [
    [32768, -32768, 32768, -32768],
    [32768, 32768, -32768, -32768]
  ]
  b_h = [-16384, 16384, 16384, -49152]

  @! Initial weights for 4x1 output layer
  w_ho = [49152, -49152, -49152, 49152]
  b_o = -16384

  return {
    w_ih: w_ih,
    b_h: b_h,
    w_ho: w_ho,
    b_o: b_o
  }
@end

@fn mlp_forward(net, x0, x1)
  h_acts = []
  j = 0
  @while j < 4
    sum = net.b_h[j] + fp_mul(x0, net.w_ih[0][j]) + fp_mul(x1, net.w_ih[1][j])
    h_acts.push(fp_sigmoid(sum))
    j = j + 1
  @end

  out_sum = net.b_o
  j = 0
  @while j < 4
    out_sum = out_sum + fp_mul(h_acts[j], net.w_ho[j])
    j = j + 1
  @end

  out_act = fp_sigmoid(out_sum)
  return { h_acts: h_acts, out_act: out_act }
@end

@fn mlp_train_epoch(net, lr)
  @! XOR training patterns: [x0, x1, target] in Q16.16 (0=0, 1=65536)
  patterns = [
    [0, 0, 0],
    [0, 65536, 65536],
    [65536, 0, 65536],
    [65536, 65536, 0]
  ]

  p = 0
  @while p < 4
    x0 = patterns[p][0]
    x1 = patterns[p][1]
    target = patterns[p][2]

    @! 1. Forward Pass
    fwd = mlp_forward(net, x0, x1)
    out_act = fwd.out_act
    h_acts = fwd.h_acts

    @! 2. Output Error & Delta
    out_error = target - out_act
    out_delta = fp_mul(out_error, fp_sigmoid_derivative(out_act))

    @! 3. Hidden Layer Errors & Deltas
    h_deltas = []
    j = 0
    @while j < 4
      h_err = fp_mul(out_delta, net.w_ho[j])
      h_del = fp_mul(h_err, fp_sigmoid_derivative(h_acts[j]))
      h_deltas.push(h_del)
      j = j + 1
    @end

    @! 4. Update Output Layer Weights and Bias
    j = 0
    @while j < 4
      net.w_ho[j] = net.w_ho[j] + fp_mul(lr, fp_mul(out_delta, h_acts[j]))
      j = j + 1
    @end
    net.b_o = net.b_o + fp_mul(lr, out_delta)

    @! 5. Update Hidden Layer Weights and Biases
    j = 0
    @while j < 4
      net.w_ih[0][j] = net.w_ih[0][j] + fp_mul(lr, fp_mul(h_deltas[j], x0))
      net.w_ih[1][j] = net.w_ih[1][j] + fp_mul(lr, fp_mul(h_deltas[j], x1))
      net.b_h[j] = net.b_h[j] + fp_mul(lr, h_deltas[j])
      j = j + 1
    @end

    p = p + 1
  @end

  return net
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 7: Fixed-Point Multi-Layer Neural Network")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  net = mlp_new()

  @! T4.7.1: Network Architecture Initialization (2x4x1)
  total = total + 1
  @if net.w_ih.len() == 2 && net.w_ho.len() == 4
    passed = passed + 1
    println("  [PASS] T4.7.1: MLP (2-input, 4-hidden, 1-output) structure initialized with Q16.16 weights")
  @else
    failed = failed + 1
    println("  [FAIL] T4.7.1: Network init failed")
  @end

  @! T4.7.2: Train Neural Network on XOR for 1000 Epochs
  total = total + 1
  lr = 32768  @! Learning rate 0.5 in Q16.16
  epoch = 0
  @while epoch < 1000
    net = mlp_train_epoch(net, lr)
    epoch = epoch + 1
  @end

  passed = passed + 1
  println("  [PASS] T4.7.2: Backpropagation training completed for 1000 epochs (lr=0.5)")

  @! T4.7.3: Predict XOR(0, 0) -> Target 0 (< 0.35 = 22937 in Q16.16)
  total = total + 1
  pred_00 = mlp_forward(net, 0, 0).out_act

  @if pred_00 < 22937
    passed = passed + 1
    println("  [PASS] T4.7.3: XOR(0, 0) prediction = " + int_to_str(pred_00) + "/65536 (< 0.35, Class 0)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.7.3: XOR(0, 0) prediction failed: " + int_to_str(pred_00))
  @end

  @! T4.7.4: Predict XOR(0, 1) and XOR(1, 0) -> Target 1 (> 0.65 = 42598 in Q16.16)
  total = total + 1
  pred_01 = mlp_forward(net, 0, 65536).out_act
  pred_10 = mlp_forward(net, 65536, 0).out_act

  @if pred_01 > 42598 && pred_10 > 42598
    passed = passed + 1
    println("  [PASS] T4.7.4: XOR(0, 1) = " + int_to_str(pred_01) + "/65536, XOR(1, 0) = " + int_to_str(pred_10) + "/65536 (> 0.65, Class 1)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.7.4: XOR(0, 1)/XOR(1, 0) prediction failed: pred_01=" + int_to_str(pred_01) + ", pred_10=" + int_to_str(pred_10))
  @end

  @! T4.7.5: Predict XOR(1, 1) -> Target 0 (< 0.35 = 22937 in Q16.16)
  total = total + 1
  pred_11 = mlp_forward(net, 65536, 65536).out_act

  @if pred_11 < 22937
    passed = passed + 1
    println("  [PASS] T4.7.5: XOR(1, 1) prediction = " + int_to_str(pred_11) + "/65536 (< 0.35, Class 0)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.7.5: XOR(1, 1) prediction failed: " + int_to_str(pred_11))
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 7 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 7 (Neural Network MLP) PASSED")
    return 0
  @else
    println("✗ Scenario 7 (Neural Network MLP) FAILED")
    return 1
  @end
@end
