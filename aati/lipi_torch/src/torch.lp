// ==============================================================================
// 👑 LIPI TORCH: SOVEREIGN DEEP LEARNING FRAMEWORK (aati/lipi_torch/src/torch.lp)
// ⚡ 100% Pure Lipi Architecture | Zero Python | Zero PyTorch C++ Libs | Pure Silicon
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Provides an ergonomic, sovereign deep learning tensor framework modeled after
//    PyTorch, running 100% natively on bare-metal silicon without Python or LibTorch.
// 2. Full computational DAG with automatic reverse-mode differentiation (autograd).
// 3. Native Layer Primitives (Linear, MSELoss, ReLU, Sigmoid) and Optimizers (SGD).
// ==============================================================================

import "utso/collections"
import "utso/math"
import "aati/lipi_ai/tensor"
import "aati/lipi_ai/autograd"

// ── 1. Linear Neural Network Layer Struct ────────────────────────────────────
@struct TorchLinear
  in_features: i64
  out_features: i64
  weight: Tensor
  bias: Tensor
@end

@struct TorchSGD
  learning_rate: f64
  params: array
@end

// ── 2. Tensor Factory Constructors ───────────────────────────────────────────

@fn torch_tensor(data: array, shape: array) -> Tensor
  // WHY: Allocates and wraps an N-dimensional tensor with reverse-mode gradient tracking.
  t = leaf_tensor(data, shape)
  return t
@end

@fn torch_constant(data: array, shape: array) -> Tensor
  // WHY: Non-trainable input/target tensor with requires_grad = 0.
  return constant_tensor(data, shape)
@end

@fn torch_zeros(shape: array) -> Tensor
  // WHY: Initializes zero-filled tensor for accumulator buffers.
  total_elements = 1
  i = 0
  @while i < shape.len()
    total_elements = total_elements * shape[i]
    i = i + 1
  @end
  data = []
  i = 0
  @while i < total_elements
    data = data.push(0.0)
    i = i + 1
  @end
  return leaf_tensor(data, shape)
@end

@fn torch_ones(shape: array) -> Tensor
  // WHY: Initializes unit-filled tensor for scaling and bias vectors.
  total_elements = 1
  i = 0
  @while i < shape.len()
    total_elements = total_elements * shape[i]
    i = i + 1
  @end
  data = []
  i = 0
  @while i < total_elements
    data = data.push(1.0)
    i = i + 1
  @end
  return leaf_tensor(data, shape)
@end

// ── 2b. IEEE-754 f64 Scalar & Reverse-Mode Autograd Kernels ───────────────────

@fn torch_fadd(a: f64, b: f64) -> f64 return a + b @end
@fn torch_fsub(a: f64, b: f64) -> f64 return a - b @end
@fn torch_fmul(a: f64, b: f64) -> f64 return a * b @end
@fn torch_fdiv(a: f64, b: f64) -> f64 return a / b @end
@fn torch_fgt0(a: f64) -> i64
  @if a > 0.0 return 1 @end
  return 0
@end

@fn torch_accumulate_f64_grad(p: Tensor, d_grad: array) -> i64
  @if p.grad.len() < p.size
    tensor_ensure_grad(p)
  @end
  g = p.grad
  i = 0
  @while i < p.size && i < d_grad.len()
    g[i] = torch_fadd(g[i], d_grad[i])
    i = i + 1
  @end
  p.grad = g
  return 1
@end

// ── 3. Math & Autograd Forward Operations (True IEEE-754 f64 Kernels) ────────

@fn torch_matmul(a: Tensor, b: Tensor) -> Tensor
  @if a.ndim != 2 || b.ndim != 2
    return tensor_matmul(a, b)
  @end
  m = a.shape[0]
  k = a.shape[1]
  n = b.shape[1]
  res_data = []
  i = 0
  @while i < m
    j = 0
    @while j < n
      acc = 0.0
      p = 0
      @while p < k
        va = a.data[(i * k) + p]
        vb = b.data[(p * n) + j]
        acc = torch_fadd(acc, torch_fmul(va, vb))
        p = p + 1
      @end
      res_data = res_data.push(acc)
      j = j + 1
    @end
    i = i + 1
  @end
  out = tensor_new(res_data, [m, n])
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "matmul"
    out.parents = [a, b]
  @end
  return out
@end

@fn torch_add(a: Tensor, b: Tensor) -> Tensor
  // Supports same-shape addition and [M, N] + [1, N] bias row broadcasting in f64
  res_data = []
  @if a.ndim == 2 && b.ndim == 2 && a.shape[1] == b.shape[1] && b.shape[0] == 1 && a.shape[0] > 1
    m = a.shape[0]
    n = a.shape[1]
    i = 0
    @while i < m
      j = 0
      @while j < n
        res_data = res_data.push(torch_fadd(a.data[(i * n) + j], b.data[j]))
        j = j + 1
      @end
      i = i + 1
    @end
    out = tensor_new(res_data, a.shape)
    @if a.requires_grad == 1 || b.requires_grad == 1
      out.requires_grad = 1
      out.creator_op = "add_bcast"
      out.parents = [a, b]
    @end
    return out
  @end
  i = 0
  sz = a.size
  @while i < sz
    res_data = res_data.push(torch_fadd(a.data[i], b.data[i % b.size]))
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "add"
    out.parents = [a, b]
  @end
  return out
@end

@fn torch_sub(a: Tensor, b: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    res_data = res_data.push(torch_fsub(a.data[i], b.data[i % b.size]))
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "sub"
    out.parents = [a, b]
  @end
  return out
@end

@fn torch_mul(a: Tensor, b: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    res_data = res_data.push(torch_fmul(a.data[i], b.data[i % b.size]))
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "mul"
    out.parents = [a, b]
  @end
  return out
@end

@fn torch_relu(a: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    v = a.data[i]
    @if torch_fgt0(v) == 1
      res_data = res_data.push(v)
    @else
      res_data = res_data.push(0.0)
    @end
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "relu"
    out.parents = [a]
  @end
  return out
@end

@fn torch_fexp(x: f64) -> f64
  @if x > 40.0 return math_exp(40.0) @end
  @if x < (0.0 - 40.0) return 0.0 @end
  return math_exp(x)
@end

@fn torch_sigmoid(a: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    x = a.data[i]
    neg_x = torch_fsub(0.0, x)
    sig = torch_fdiv(1.0, torch_fadd(1.0, torch_fexp(neg_x)))
    res_data = res_data.push(sig)
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "sigmoid"
    out.parents = [a]
  @end
  return out
@end

@fn torch_backward(root: Tensor) -> i64
  // WHY: Full IEEE-754 reverse-mode topological DAG differentiation pass.
  @if root.grad.len() < root.size
    tensor_ensure_grad(root)
  @end
  rg = root.grad
  ri = 0
  @while ri < root.size
    @if rg[ri] == 0
      rg[ri] = 1.0
    @end
    ri = ri + 1
  @end
  root.grad = rg

  topo_nodes = tensor_topological_sort(root)
  idx = topo_nodes.len() - 1
  @while idx >= 0
    curr = topo_nodes[idx]
    @if curr.requires_grad == 1 && curr.creator_op != "none" && curr.creator_op != "leaf" && curr.creator_op != "constant"
      op = curr.creator_op
      @if op == "add"
        pa = curr.parents[0]
        pb = curr.parents[1]
        @if pa.requires_grad == 1 torch_accumulate_f64_grad(pa, curr.grad) @end
        @if pb.requires_grad == 1 torch_accumulate_f64_grad(pb, curr.grad) @end
      @elif op == "sub"
        pa = curr.parents[0]
        pb = curr.parents[1]
        @if pa.requires_grad == 1 torch_accumulate_f64_grad(pa, curr.grad) @end
        @if pb.requires_grad == 1
          neg_g = []
          k = 0
          @while k < curr.grad.len()
            neg_g = neg_g.push(torch_fsub(0.0, curr.grad[k]))
            k = k + 1
          @end
          torch_accumulate_f64_grad(pb, neg_g)
        @end
      @elif op == "mul"
        pa = curr.parents[0]
        pb = curr.parents[1]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          @while k < curr.grad.len()
            ga = ga.push(torch_fmul(curr.grad[k], pb.data[k % pb.size]))
            k = k + 1
          @end
          torch_accumulate_f64_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          gb = []
          k = 0
          @while k < curr.grad.len()
            gb = gb.push(torch_fmul(curr.grad[k], pa.data[k % pa.size]))
            k = k + 1
          @end
          torch_accumulate_f64_grad(pb, gb)
        @end
      @elif op == "add_bcast"
        pa = curr.parents[0]
        pb = curr.parents[1]
        m = pa.shape[0]
        n = pa.shape[1]
        @if pa.requires_grad == 1 torch_accumulate_f64_grad(pa, curr.grad) @end
        @if pb.requires_grad == 1
          gb = []
          j = 0
          @while j < n
            col_sum = 0.0
            k = 0
            @while k < m
              col_sum = torch_fadd(col_sum, curr.grad[(k * n) + j])
              k = k + 1
            @end
            gb = gb.push(col_sum)
            j = j + 1
          @end
          torch_accumulate_f64_grad(pb, gb)
        @end
      @elif op == "matmul"
        pa = curr.parents[0]
        pb = curr.parents[1]
        m = pa.shape[0]
        k_dim = pa.shape[1]
        n = pb.shape[1]
        @if pa.requires_grad == 1
          ga = []
          i = 0
          @while i < m
            p = 0
            @while p < k_dim
              acc = 0.0
              j = 0
              @while j < n
                acc = torch_fadd(acc, torch_fmul(curr.grad[(i * n) + j], pb.data[(p * n) + j]))
                j = j + 1
              @end
              ga = ga.push(acc)
              p = p + 1
            @end
            i = i + 1
          @end
          torch_accumulate_f64_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          gb = []
          p = 0
          @while p < k_dim
            j = 0
            @while j < n
              acc = 0.0
              i = 0
              @while i < m
                acc = torch_fadd(acc, torch_fmul(pa.data[(i * k_dim) + p], curr.grad[(i * n) + j]))
                i = i + 1
              @end
              gb = gb.push(acc)
              j = j + 1
            @end
            p = p + 1
          @end
          torch_accumulate_f64_grad(pb, gb)
        @end
      @elif op == "relu"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          @while k < pa.size
            @if torch_fgt0(pa.data[k]) == 1
              ga = ga.push(curr.grad[k])
            @else
              ga = ga.push(0.0)
            @end
            k = k + 1
          @end
          torch_accumulate_f64_grad(pa, ga)
        @end
      @elif op == "sigmoid"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          @while k < curr.size
            y = curr.data[k]
            ds = torch_fmul(y, torch_fsub(1.0, y))
            ga = ga.push(torch_fmul(curr.grad[k], ds))
            k = k + 1
          @end
          torch_accumulate_f64_grad(pa, ga)
        @end
      @elif op == "mse_loss"
        pa = curr.parents[0]
        pb = curr.parents[1]
        n_elem = pa.size
        n_f = n_elem + 0.0
        g_loss = curr.grad[0]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          @while k < n_elem
            diff = torch_fsub(pa.data[k], pb.data[k % pb.size])
            ga = ga.push(torch_fdiv(torch_fmul(torch_fmul(2.0, diff), g_loss), n_f))
            k = k + 1
          @end
          torch_accumulate_f64_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          gb = []
          k = 0
          @while k < n_elem
            diff = torch_fsub(pa.data[k], pb.data[k % pb.size])
            gb = gb.push(torch_fdiv(torch_fmul(torch_fmul(0.0 - 2.0, diff), g_loss), n_f))
            k = k + 1
          @end
          torch_accumulate_f64_grad(pb, gb)
        @end
      @end
    @end
    idx = idx - 1
  @end
  return 1
@end

// ── 4. Neural Network Modules & Optimizers ───────────────────────────────────

@fn torch_linear_new(in_f: i64, out_f: i64) -> TorchLinear
  // WHY: Initializes fully-connected affine layer with Xavier/Kaiming 1/sqrt(fan_in) variance scaling.
  fan_in_f = in_f + 0.0
  @if in_f <= 0 fan_in_f = 1.0 @end
  scale = torch_fdiv(1.0, math_sqrt(fan_in_f))
  w_init_vals = [0.0 - 0.6, 0.4, 0.0 - 0.2, 0.5, 0.0 - 0.3, 0.2, 0.7]
  w_data = []
  total_w = in_f * out_f
  i = 0
  @while i < total_w
    w_data = w_data.push(torch_fmul(w_init_vals[i % 7], scale))
    i = i + 1
  @end
  w_tensor = leaf_tensor(w_data, [in_f, out_f])

  b_data = []
  i = 0
  @while i < out_f
    b_data = b_data.push(0.0)
    i = i + 1
  @end
  b_tensor = leaf_tensor(b_data, [1, out_f])

  return {
    in_features: in_f,
    out_features: out_f,
    weight: w_tensor,
    bias: b_tensor
  }
@end

@fn torch_linear_forward(layer: TorchLinear, x: Tensor) -> Tensor
  xw = torch_matmul(x, layer.weight)
  return torch_add(xw, layer.bias)
@end

@fn torch_mse_loss(pred: Tensor, target: Tensor) -> Tensor
  // WHY: Mean Squared Error Loss in true IEEE-754 f64 using autograd graph
  n = pred.size
  n_f = n + 0.0
  sum_sq = 0.0
  i = 0
  @while i < n
    diff = torch_fsub(pred.data[i], target.data[i % target.size])
    sum_sq = torch_fadd(sum_sq, torch_fmul(diff, diff))
    i = i + 1
  @end
  mean_loss = torch_fdiv(sum_sq, n_f)
  out = tensor_new([mean_loss], [1])
  @if pred.requires_grad == 1 || target.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "mse_loss"
    out.parents = [pred, target]
  @end
  return out
@end

@fn torch_sgd_new(params: array, lr: f64) -> TorchSGD
  return {
    learning_rate: lr,
    params: params
  }
@end

@fn torch_sgd_step(optimizer: TorchSGD) -> i64
  // WHY: Performs parameter gradient descent update: W = W - lr * dW.
  p_idx = 0
  p_count = optimizer.params.len()
  lr = optimizer.learning_rate

  @while p_idx < p_count
    param: Tensor = optimizer.params[p_idx]
    @if param.requires_grad == 1 && param.grad.len() >= param.size
      d = param.data
      i = 0
      @while i < param.size
        curr_w = d[i]
        curr_g = param.grad[i]
        d[i] = torch_fsub(curr_w, torch_fmul(lr, curr_g))
        i = i + 1
      @end
      param.data = d
    @end
    p_idx = p_idx + 1
  @end
  return 1
@end

@fn torch_zero_grad(params: array) -> i64
  // WHY: Flushes accumulated gradients before next forward-backward flight.
  p_idx = 0
  p_count = params.len()
  @while p_idx < p_count
    p: Tensor = params[p_idx]
    tensor_zero_grad(p)
    p_idx = p_idx + 1
  @end
  return 1
@end
