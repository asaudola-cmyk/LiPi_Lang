@! ============================================================================
@! LIPI UNIVERSE AI: CONVOLUTIONAL NEURAL NETWORK LAYERS
@! Module: universe/ai/cnn
@! 100% Pure Lipi Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"

@struct Conv2D
  in_channels: i64
  out_channels: i64
  kernel_h: i64
  kernel_w: i64
  stride_h: i64
  stride_w: i64
  pad_h: i64
  pad_w: i64
  weight_data: array
  bias_data: array
@end

@fn conv2d_new(in_c: i64, out_c: i64, kh: i64, kw: i64) -> Conv2D
  return {
    in_channels: in_c,
    out_channels: out_c,
    kernel_h: kh,
    kernel_w: kw,
    stride_h: 1,
    stride_w: 1,
    pad_h: 0,
    pad_w: 0,
    weight_data: [],
    bias_data: []
  }
@end

@struct MaxPool2D
  kernel_h: i64
  kernel_w: i64
  stride_h: i64
  stride_w: i64
@end

@fn maxpool2d_new(kh: i64, kw: i64, sh: i64, sw: i64) -> MaxPool2D
  return {
    kernel_h: kh,
    kernel_w: kw,
    stride_h: sh,
    stride_w: sw
  }
@end

@struct AvgPool2D
  kernel_h: i64
  kernel_w: i64
  stride_h: i64
  stride_w: i64
@end

@fn avgpool2d_new(kh: i64, kw: i64, sh: i64, sw: i64) -> AvgPool2D
  return {
    kernel_h: kh,
    kernel_w: kw,
    stride_h: sh,
    stride_w: sw
  }
@end

@struct BatchNorm2D
  num_features: i64
  eps: f64
  momentum: f64
  gamma: array
  beta: array
  running_mean: array
  running_var: array
@end

@fn batchnorm2d_new(num_features: i64) -> BatchNorm2D
  return {
    num_features: num_features,
    eps: 0.00001,
    momentum: 0.1,
    gamma: [],
    beta: [],
    running_mean: [],
    running_var: []
  }
@end

@struct Flatten
  start_dim: i64
  end_dim: i64
@end

@fn flatten_new() -> Flatten
  return { start_dim: 1, end_dim: -1 }
@end

@struct ResidualBlock
  conv1: Conv2D
  bn1: BatchNorm2D
  conv2: Conv2D
  bn2: BatchNorm2D
  has_shortcut: i64
@end

@fn residual_block_new(channels: i64) -> ResidualBlock
  return {
    conv1: conv2d_new(channels, channels, 3, 3),
    bn1: batchnorm2d_new(channels),
    conv2: conv2d_new(channels, channels, 3, 3),
    bn2: batchnorm2d_new(channels),
    has_shortcut: 0
  }
@end

@fn relu(x: f64) -> f64
  @if x < 0.0
    return 0.0
  @end
  return x
@end

@fn main()
  return 0
@end
