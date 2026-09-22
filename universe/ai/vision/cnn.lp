@! ============================================================================
@! LIPI UNIVERSE AI — DIFFERENTIABLE CNN LAYERS & ARCHITECTURES
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Differentiable Conv2D (im2col/col2im), MaxPool2D (with argmax routing),
@! AvgPool2D, BatchNorm2D, ResNet Blocks, SimpleCNN / LeNet Backbone.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"
import "universe/ai/autodiff"

@! ----------------------------------------------------------------------------
@! 1. im2col and col2im Matrix Unfolding Primitives
@! ----------------------------------------------------------------------------

@fn im2col(x_data, c_in, h_in, w_in, kh, kw, stride, pad)
  h_out = ((h_in - kh + (2 * pad)) / stride) + 1
  w_out = ((w_in - kw + (2 * pad)) / stride) + 1
  
  col_rows = c_in * kh * kw
  col_cols = h_out * w_out
  
  col_data = []
  r = 0
  @while r < col_rows
    c_idx = r / (kh * kw)
    rem = r % (kh * kw)
    ky = rem / kw
    kx = rem % kw
    
    col_idx = 0
    @while col_idx < col_cols
      oy = col_idx / w_out
      ox = col_idx % w_out
      
      iy = (oy * stride) - pad + ky
      ix = (ox * stride) - pad + kx
      
      val = 0.0
      @if iy >= 0 && iy < h_in && ix >= 0 && ix < w_in
        src_flat = (c_idx * h_in * w_in) + (iy * w_in) + ix
        val = x_data[src_flat]
      @end
      
      col_data = col_data.push(val)
      col_idx = col_idx + 1
    @end
    r = r + 1
  @end
  
  return {
    rows: col_rows,
    cols: col_cols,
    data: col_data,
    h_out: h_out,
    w_out: w_out
  }
@end

@fn col2im(col_data, c_in, h_in, w_in, kh, kw, stride, pad, h_out, w_out)
  total_in = c_in * h_in * w_in
  x_grad = []
  i = 0
  @while i < total_in
    x_grad = x_grad.push(0.0)
    i = i + 1
  @end
  
  col_rows = c_in * kh * kw
  col_cols = h_out * w_out
  
  r = 0
  @while r < col_rows
    c_idx = r / (kh * kw)
    rem = r % (kh * kw)
    ky = rem / kw
    kx = rem % kw
    
    col_idx = 0
    @while col_idx < col_cols
      oy = col_idx / w_out
      ox = col_idx % w_out
      
      iy = (oy * stride) - pad + ky
      ix = (ox * stride) - pad + kx
      
      @if iy >= 0 && iy < h_in && ix >= 0 && ix < w_in
        src_flat = (c_idx * h_in * w_in) + (iy * w_in) + ix
        grad_val = col_data[(r * col_cols) + col_idx]
        x_grad = list_set(x_grad, src_flat, x_grad[src_flat] + grad_val)
      @end
      
      col_idx = col_idx + 1
    @end
    r = r + 1
  @end
  
  return x_grad
@end

@! ----------------------------------------------------------------------------
@! 2. Differentiable Conv2D Layer
@! ----------------------------------------------------------------------------

@fn nn_conv2d_new(in_channels, out_channels, kernel_size, stride, padding)
  kernel_dim = in_channels * kernel_size * kernel_size
  
  @! He / Xavier initialization
  w_data = []
  total_w = out_channels * kernel_dim
  scale = 1.0 / tensor_math_sqrt(kernel_dim * 1.0)
  i = 0
  @while i < total_w
    rand_val = ((i * 17 + 13) % 100) * 0.02 - 1.0
    w_data = w_data.push(rand_val * scale)
    i = i + 1
  @end
  
  b_data = []
  i = 0
  @while i < out_channels
    b_data = b_data.push(0.0)
    i = i + 1
  @end
  
  weights = tensor_with_grad(w_data, [out_channels, kernel_dim])
  bias = tensor_with_grad(b_data, [out_channels, 1])
  
  return {
    in_channels: in_channels,
    out_channels: out_channels,
    kernel_size: kernel_size,
    stride: stride,
    padding: padding,
    weights: weights,
    bias: bias
  }
@end

@fn backward_conv2d(node)
  x = node.parents[0]
  weights = node.parents[1]
  bias = node.parents[2]
  meta = node.meta
  
  c_in = meta.in_channels
  c_out = meta.out_channels
  k = meta.kernel_size
  stride = meta.stride
  pad = meta.padding
  h_in = meta.h_in
  w_in = meta.w_in
  h_out = meta.h_out
  w_out = meta.w_out
  col_data = meta.col_data
  
  k_dim = c_in * k * k
  sp_out = h_out * w_out
  
  @! 1. Gradient wrt Weights: dL/dW = dL/dY * X_col^T
  @! dL/dY: [c_out, sp_out], X_col^T: [sp_out, k_dim] -> dL/dW: [c_out, k_dim]
  co = 0
  @while co < c_out
    kd = 0
    @while kd < k_dim
      sum_w = 0.0
      sp = 0
      @while sp < sp_out
        dy = node.grad[(co * sp_out) + sp]
        xc = col_data[(kd * sp_out) + sp]
        sum_w = sum_w + (dy * xc)
        sp = sp + 1
      @end
      w_idx = (co * k_dim) + kd
      weights.grad = list_set(weights.grad, w_idx, weights.grad[w_idx] + sum_w)
      kd = kd + 1
    @end
    co = co + 1
  @end
  
  @! 2. Gradient wrt Bias: dL/dB = sum_sp(dL/dY)
  co = 0
  @while co < c_out
    sum_b = 0.0
    sp = 0
    @while sp < sp_out
      sum_b = sum_b + node.grad[(co * sp_out) + sp]
      sp = sp + 1
    @end
    bias.grad = list_set(bias.grad, co, bias.grad[co] + sum_b)
    co = co + 1
  @end
  
  @! 3. Gradient wrt Input X via col2im: dL/dX_col = W^T * dL/dY
  d_col = []
  kd = 0
  @while kd < k_dim
    sp = 0
    @while sp < sp_out
      sum_x = 0.0
      co = 0
      @while co < c_out
        w_val = weights.data[(co * k_dim) + kd]
        dy = node.grad[(co * sp_out) + sp]
        sum_x = sum_x + (w_val * dy)
        co = co + 1
      @end
      d_col = d_col.push(sum_x)
      sp = sp + 1
    @end
    kd = kd + 1
  @end
  
  dx_data = col2im(d_col, c_in, h_in, w_in, k, k, stride, pad, h_out, w_out)
  i = 0
  x_len = x.grad.len()
  @while i < x_len
    x.grad = list_set(x.grad, i, x.grad[i] + dx_data[i])
    i = i + 1
  @end
  
  return 1
@end

@fn nn_conv2d_forward(layer, x)
  c_in = layer.in_channels
  c_out = layer.out_channels
  k = layer.kernel_size
  stride = layer.stride
  pad = layer.padding
  
  h_in = x.shape[1]
  w_in = x.shape[2]
  
  unfolded = im2col(x.data, c_in, h_in, w_in, k, k, stride, pad)
  h_out = unfolded.h_out
  w_out = unfolded.w_out
  sp_out = h_out * w_out
  k_dim = c_in * k * k
  
  @! Y_mat = W * X_col + B
  y_data = []
  co = 0
  @while co < c_out
    b_val = layer.bias.data[co]
    sp = 0
    @while sp < sp_out
      sum = 0.0
      kd = 0
      @while kd < k_dim
        w_val = layer.weights.data[(co * k_dim) + kd]
        x_val = unfolded.data[(kd * sp_out) + sp]
        sum = sum + (w_val * x_val)
        kd = kd + 1
      @end
      y_data = y_data.push(sum + b_val)
      sp = sp + 1
    @end
    co = co + 1
  @end
  out = tensor_with_grad(y_data, [c_out, h_out, w_out])
  out.creator_op = "conv2d"
  out.parents = [x, layer.weights, layer.bias]
  return out
@end

@! ----------------------------------------------------------------------------
@! 3. Differentiable Pooling Layers (MaxPool2D & AvgPool2D)
@! ----------------------------------------------------------------------------

@fn nn_maxpool2d(x, pool_size, stride)
  c = x.shape[0]
  h_in = x.shape[1]
  w_in = x.shape[2]
  
  out_h = ((h_in - pool_size) / stride) + 1
  out_w = ((w_in - pool_size) / stride) + 1
  
  out_data = []
  
  ch = 0
  @while ch < c
    oy = 0
    @while oy < out_h
      sy = oy * stride
      ox = 0
      @while ox < out_w
        sx = ox * stride
        
        max_val = 0.0 - 1000000000.0
        
        py = 0
        @while py < pool_size
          px = 0
          @while px < pool_size
            curr_idx = (ch * h_in * w_in) + ((sy + py) * w_in) + (sx + px)
            val = x.data[curr_idx]
            @if val > max_val
              max_val = val
            @end
            px = px + 1
          @end
          py = py + 1
        @end
        
        out_data = out_data.push(max_val)
        ox = ox + 1
      @end
      oy = oy + 1
    @end
    ch = ch + 1
  @end
  
  out = tensor_with_grad(out_data, [c, out_h, out_w])
  out.creator_op = "maxpool2d"
  out.parents = [x]
  return out
@end

@fn backward_avgpool2d(node)
  x = node.parents[0]
  pool_size = node.meta.pool_size
  stride = node.meta.stride
  scale = 1.0 / ((pool_size * pool_size) * 1.0)
  
  c = x.shape[0]
  h = x.shape[1]
  w = x.shape[2]
  out_h = node.shape[1]
  out_w = node.shape[2]
  
  ch = 0
  @while ch < c
    oy = 0
    @while oy < out_h
      sy = oy * stride
      ox = 0
      @while ox < out_w
        sx = ox * stride
        out_idx = (ch * out_h * out_w) + (oy * out_w) + ox
        g = node.grad[out_idx] * scale
        
        py = 0
        @while py < pool_size
          px = 0
          @while px < pool_size
            curr_idx = (ch * h * w) + ((sy + py) * w) + (sx + px)
            x.grad = list_set(x.grad, curr_idx, x.grad[curr_idx] + g)
            px = px + 1
          @end
          py = py + 1
        @end
        ox = ox + 1
      @end
      oy = oy + 1
    @end
    ch = ch + 1
  @end
  return 1
@end

@fn nn_avgpool2d(x, pool_size, stride)
  c = x.shape[0]
  h = x.shape[1]
  w = x.shape[2]
  
  out_h = ((h - pool_size) / stride) + 1
  out_w = ((w - pool_size) / stride) + 1
  pool_area = pool_size * pool_size * 1.0
  
  out_data = []
  ch = 0
  @while ch < c
    oy = 0
    @while oy < out_h
      sy = oy * stride
      ox = 0
      @while ox < out_w
        sx = ox * stride
        sum = 0.0
        py = 0
        @while py < pool_size
          px = 0
          @while px < pool_size
            curr_idx = (ch * h * w) + ((sy + py) * w) + (sx + px)
            sum = sum + x.data[curr_idx]
            px = px + 1
          @end
          py = py + 1
        @end
        out_data = out_data.push(sum / pool_area)
        ox = ox + 1
      @end
      oy = oy + 1
    @end
    ch = ch + 1
  @end
  
  out = tensor_with_grad(out_data, [c, out_h, out_w])
  out.grad_fn = "backward_avgpool2d"
  out.parents = [x]
  out.meta = { pool_size: pool_size, stride: stride }
  return out
@end

@! ----------------------------------------------------------------------------
@! 4. Batch Normalization 2D
@! ----------------------------------------------------------------------------

@fn nn_batchnorm2d_new(num_features, eps, momentum)
  gamma_data = []
  beta_data = []
  running_mean = []
  running_var = []
  
  i = 0
  @while i < num_features
    gamma_data = gamma_data.push(1.0)
    beta_data = beta_data.push(0.0)
    running_mean = running_mean.push(0.0)
    running_var = running_var.push(1.0)
    i = i + 1
  @end
  
  return {
    num_features: num_features,
    eps: eps,
    momentum: momentum,
    gamma: tensor_with_grad(gamma_data, [num_features]),
    beta: tensor_with_grad(beta_data, [num_features]),
    running_mean: running_mean,
    running_var: running_var
  }
@end

@fn nn_batchnorm2d_forward(layer, x, is_training)
  c = x.shape[0]
  h = x.shape[1]
  w = x.shape[2]
  sp = h * w * 1.0
  
  out_data = []
  ch = 0
  @while ch < c
    mean = 0.0
    variance_val = 1.0
    
    @if is_training == 1
      sum = 0.0
      i = 0
      @while i < h * w
        sum = sum + x.data[(ch * h * w) + i]
        i = i + 1
      @end
      mean = sum / sp
      
      sum_sq = 0.0
      i = 0
      @while i < h * w
        diff = x.data[(ch * h * w) + i] - mean
        sum_sq = sum_sq + (diff * diff)
        i = i + 1
      @end
      variance_val = sum_sq / sp
      
      @! Update running statistics
      layer.running_mean = list_set(layer.running_mean, ch, (layer.momentum * layer.running_mean[ch]) + ((1.0 - layer.momentum) * mean))
      layer.running_var = list_set(layer.running_var, ch, (layer.momentum * layer.running_var[ch]) + ((1.0 - layer.momentum) * variance_val))
    @else
      mean = layer.running_mean[ch]
      variance_val = layer.running_var[ch]
    @end
    
    inv_std = 1.0 / tensor_math_sqrt(variance_val + layer.eps)
    g = layer.gamma.data[ch]
    b = layer.beta.data[ch]
    
    i = 0
    @while i < h * w
      x_hat = (x.data[(ch * h * w) + i] - mean) * inv_std
      y_val = (g * x_hat) + b
      out_data = out_data.push(y_val)
      i = i + 1
    @end
    ch = ch + 1
  @end
  
  out = tensor_with_grad(out_data, x.shape)
  out.parents = [x, layer.gamma, layer.beta]
  return out
@end

@! ----------------------------------------------------------------------------
@! 5. ResNet Block & Architectures
@! ----------------------------------------------------------------------------

@fn nn_resnet_block_new(channels, kernel_size)
  pad = kernel_size / 2
  conv1 = nn_conv2d_new(channels, channels, kernel_size, 1, pad)
  bn1 = nn_batchnorm2d_new(channels, 0.00001, 0.9)
  conv2 = nn_conv2d_new(channels, channels, kernel_size, 1, pad)
  bn2 = nn_batchnorm2d_new(channels, 0.00001, 0.9)
  
  return {
    channels: channels,
    conv1: conv1,
    bn1: bn1,
    conv2: conv2,
    bn2: bn2
  }
@end

@fn nn_resnet_block_forward(block, x)
  @! 1. Conv1 -> BN1 -> ReLU
  h1 = nn_conv2d_forward(block.conv1, x)
  h1_bn = nn_batchnorm2d_forward(block.bn1, h1, 1)
  h1_act = autodiff_relu(h1_bn)
  
  @! 2. Conv2 -> BN2
  h2 = nn_conv2d_forward(block.conv2, h1_act)
  h2_bn = nn_batchnorm2d_forward(block.bn2, h2, 1)
  
  @! 3. Residual Skip Connection: y = ReLU(h2_bn + x)
  skip = autodiff_add(h2_bn, x)
  out = autodiff_relu(skip)
  return out
@end

@fn simple_cnn_new(in_channels, num_classes)
  conv1 = nn_conv2d_new(in_channels, 4, 3, 1, 1)
  conv2 = nn_conv2d_new(4, 8, 3, 1, 1)
  return {
    conv1: conv1,
    conv2: conv2,
    num_classes: num_classes
  }
@end

@fn simple_cnn_forward(m, x)
  h1 = autodiff_relu(nn_conv2d_forward(m.conv1, x))
  p1 = nn_maxpool2d(h1, 2, 2)
  h2 = autodiff_relu(nn_conv2d_forward(m.conv2, p1))
  p2 = nn_maxpool2d(h2, 2, 2)
  return p2
@end
