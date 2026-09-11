@! Maya AI CNN Layers Unit Tests
import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"
import "universe/ai/vision/cnn"

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
  println("   MAYA AI CNN LAYERS UNIT TEST SUITE             ")
  println("==================================================")
  
  @! 1. Test im2col unfolding primitive (1 channel, 3x3 image, 2x2 kernel, stride 1, pad 0)
  x_img = [
    1.0, 2.0, 3.0,
    4.0, 5.0, 6.0,
    7.0, 8.0, 9.0
  ]
  unfolded = im2col(x_img, 1, 3, 3, 2, 2, 1, 0)
  assert_eq(unfolded.rows, 4, "im2col output rows (C_in * kh * kw = 1 * 2 * 2)")
  assert_eq(unfolded.cols, 4, "im2col output cols (h_out * w_out = 2 * 2)")
  assert_eq(unfolded.h_out, 2, "im2col output height")
  assert_eq(unfolded.w_out, 2, "im2col output width")

  @! 2. Test nn_conv2d_new layer initialization
  conv_layer = nn_conv2d_new(1, 2, 2, 1, 0)
  assert_eq(conv_layer.in_channels, 1, "Conv2D in_channels")
  assert_eq(conv_layer.out_channels, 2, "Conv2D out_channels")
  assert_eq(conv_layer.kernel_size, 2, "Conv2D kernel_size")

  @! 3. Test nn_conv2d_forward
  x_tensor = tensor_with_grad(x_img, [1, 3, 3])
  out_conv = nn_conv2d_forward(conv_layer, x_tensor)
  assert_eq(out_conv.shape[0], 2, "Conv2D output channels")
  assert_eq(out_conv.shape[1], 2, "Conv2D output height")
  assert_eq(out_conv.shape[2], 2, "Conv2D output width")

  @! 4. Test nn_maxpool2d
  pool_out = nn_maxpool2d(x_tensor, 2, 1)
  assert_eq(pool_out.shape[0], 1, "MaxPool2D channels")
  assert_eq(pool_out.shape[1], 2, "MaxPool2D output height")
  assert_eq(pool_out.shape[2], 2, "MaxPool2D output width")
  @! Top-left 2x2 max of [1,2; 4,5] is 5.0
  assert_eq(pool_out.data[0], 5.0, "MaxPool2D top-left element is 5.0")
  
  println("🎉 ALL CNN LAYERS TESTS PASSED!")
  return 0
@end
