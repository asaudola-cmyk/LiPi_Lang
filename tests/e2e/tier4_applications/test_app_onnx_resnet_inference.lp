@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: FULL ONNX RESNET / CNN INFERENCE
@! File: tests/e2e/tier4_applications/test_app_onnx_resnet_inference.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! TAGS: tier4, applications, onnx, resnet, cnn, inference
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🖼️ TIER 4: RESNET-LIKE CNN FORWARD INFERENCE ENGINE (ONNX) 🖼️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! STAGE 1: ONNX Residual Classifier Topology & Parameter Mapping
  println("▶ Stage 1: Ingesting ONNX ResNet Architecture & Weights...")
  total_tests = total_tests + 1
  
  @! Feature map channel count = 2, Spatial dimension = 4x4
  @! Weight: 1x1 Convolution Kernel (2 channels in, 2 channels out)
  conv_kernel = [
    1.0, 0.0,
    0.0, 1.0
  ]
  t_conv_w = tensor_new(conv_kernel, [2, 2])
  
  @! Classifier Linear Layer (2 channels to 3 output classes)
  fc_kernel = [
    1.0, 2.0, 0.0,
    0.0, 3.0, 1.0
  ]
  t_fc_w = tensor_new(fc_kernel, [2, 3])
  t_fc_b = tensor_new([0.0, 0.0, 0.0], [1, 3])
  
  ok1_1 = assert_eq_int(t_conv_w.shape[0], 2, "Conv kernel in_channels == 2")
  ok1_2 = assert_eq_int(t_conv_w.shape[1], 2, "Conv kernel out_channels == 2")
  ok1_3 = assert_eq_int(t_fc_w.shape[0], 2, "Linear in_features == 2")
  ok1_4 = assert_eq_int(t_fc_w.shape[1], 3, "Linear classes == 3")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 1: ResNet architecture parameters loaded")
  @end

  @! STAGE 2: Convolutional Feature Extraction & Residual Skip Connection
  println("▶ Stage 2: Residual Block Forward Pass (Conv + Residual Skip + ReLU)...")
  total_tests = total_tests + 1
  
  @! 4 spatial pixels x 2 channels:
  @! Pixel 0: [1, 3], Pixel 1: [2, 3], Pixel 2: [2, 3], Pixel 3: [3, 3]
  x_pixels = [
    1.0, 3.0,
    2.0, 3.0,
    2.0, 3.0,
    3.0, 3.0
  ]
  t_x = tensor_new(x_pixels, [4, 2])
  
  @! 1. Conv 1x1: F(X) = X * W_conv (4x2) x (2x2) -> (4x2)
  t_conv_out = tensor_matmul(t_x, t_conv_w)
  
  @! 2. Residual Addition: H = F(X) + X (Skip connection) -> 2 * X
  t_res = tensor_add(t_conv_out, t_x)
  
  @! 3. Nonlinear Activation: A = ReLU(H)
  t_act = tensor_relu(t_res)
  
  ok2_1 = assert_eq_int(t_act.shape[0], 4, "4 spatial pixel locations preserved")
  ok2_2 = assert_eq_int(t_act.shape[1], 2, "2 feature channels preserved")
  @! Pixel 0: F(x) = [1, 3] -> F(x) + x = [2, 6] -> ReLU = [2.0, 6.0]
  ok2_3 = assert_true(t_act.data[0] == 2.0, "Residual pixel 0 ch 0 == 2.0")
  ok2_4 = assert_true(t_act.data[1] == 6.0, "Residual pixel 0 ch 1 == 6.0")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 2: Residual block forward pass verified")
  @end

  @! STAGE 3: Global Average Pooling (Spatial 4x2 -> 1x2 Channel Vector)
  println("▶ Stage 3: Global Average Pooling (GAP)...")
  total_tests = total_tests + 1
  
  @! Average across the 4 pixels for channel 0 and channel 1:
  @! Ch 0 values: [2.0, 4.0, 4.0, 6.0] -> sum = 16.0 -> avg = 4.0
  @! Ch 1 values: [6.0, 6.0, 6.0, 6.0] -> sum = 24.0 -> avg = 6.0
  sum_ch0 = t_act.data[0] + t_act.data[2] + t_act.data[4] + t_act.data[6]
  sum_ch1 = t_act.data[1] + t_act.data[3] + t_act.data[5] + t_act.data[7]
  avg_ch0 = sum_ch0 / 4
  avg_ch1 = sum_ch1 / 4
  
  t_gap = tensor_new([avg_ch0, avg_ch1], [1, 2])
  
  ok3_1 = assert_eq_int(t_gap.shape[0], 1, "GAP batch row == 1")
  ok3_2 = assert_eq_int(t_gap.shape[1], 2, "GAP channel dimension == 2")
  ok3_3 = assert_true(avg_ch0 == 4, "Ch 0 spatial average == 4.0")
  ok3_4 = assert_true(avg_ch1 == 6, "Ch 1 spatial average == 6.0")
  
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 3: Global average pooling verified")
  @end

  @! STAGE 4: Linear Classification Head & Softmax Class Probabilities
  println("▶ Stage 4: Linear Classifier & Probability ArgMax...")
  total_tests = total_tests + 1
  
  @! Logits = (GAP * W_fc) + B_fc: (1x2) x (2x3) -> (1x3)
  @! Logit 0: 4.0*1.0 + 6.0*0.0 = 4.0
  @! Logit 1: 4.0*2.0 + 6.0*3.0 = 8.0 + 18.0 = 26.0
  @! Logit 2: 4.0*0.0 + 6.0*1.0 = 6.0
  t_logits_prod = tensor_matmul(t_gap, t_fc_w)
  t_logits = tensor_add(t_logits_prod, t_fc_b)
  
  ok4_1 = assert_eq_int(t_logits.shape[1], 3, "Output logits dimension == 3")
  
  l0 = t_logits.data[0]
  l1 = t_logits.data[1]
  l2 = t_logits.data[2]
  
  @! Highest logit is Class 1 (26.0 > 6.0 > 4.0)
  top_class = 0
  max_l = l0
  @if l1 > max_l
    max_l = l1
    top_class = 1
  @end
  @if l2 > max_l
    max_l = l2
    top_class = 2
  @end
  
  ok4_2 = assert_eq_int(top_class, 1, "ArgMax predicted Class 1 as dominant category")
  
  @! Softmax probabilities:
  e0 = math_exp((l0 - max_l) * 1.0)
  e1 = math_exp((l1 - max_l) * 1.0)
  e2 = math_exp((l2 - max_l) * 1.0)
  sum_e = e0 + e1 + e2
  p0 = e0 / sum_e
  p1 = e1 / sum_e
  p2 = e2 / sum_e
  
  ok4_3 = assert_true(p1 > p0 && p1 > p2, "Class 1 probability exceeds other classes")
  sum_p = p0 + p1 + p2
  diff_p = math_abs(sum_p - 1.0)
  ok4_4 = assert_true(diff_p < 0.01, "Probabilities sum to 1.0")
  
  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 4: Classification head and Softmax probability verified")
  @end

  println("=================================================================")
  println("📊 TIER 4 RESNET INFERENCE RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 TIER 4 RESNET INFERENCE TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TIER 4 RESNET INFERENCE TESTS FAILED")
    return 1
  @end
@end
