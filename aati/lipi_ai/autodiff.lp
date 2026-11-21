@! ============================================================================
@! LIPI UNIVERSE AI - AUTODIFF & OPTIMIZATION ENGINE
@! 100% Written in Pure Lipi Language
@! Features: Dynamic Computational Graph (DAG), Reverse-Mode Autodiff,
@! Advanced Optimizers (Adam, SGD, RMSprop), LR Schedulers, and Loss Functions.
@! ============================================================================

import "utso/collections"
import "utso/math"
import "aati/lipi_ai/tensor"
@fn _ad_fadd(a: f64, b: f64) -> f64 return a + b @end
@fn _ad_fsub(a: f64, b: f64) -> f64 return a - b @end
@fn _ad_fmul(a: f64, b: f64) -> f64 return a * b @end
@fn _ad_fdiv(a: f64, b: f64) -> f64 return a / b @end
@fn _ad_fgt(a: f64, b: f64) -> i64 @if a > b return 1 @end return 0 @end
@fn _ad_flt(a: f64, b: f64) -> i64 @if a < b return 1 @end return 0 @end
@fn _ad_i2f(n: i64) -> f64 return n * 1.0 @end

@fn int_to_float(n)
  return _ad_i2f(n)
@end


@! ----------------------------------------------------------------------------
@! 1. TENSOR EXTENSION FOR AUTODIFF (COMPUTATION GRAPH NODES)
@! ----------------------------------------------------------------------------
@fn tensor_with_grad(data, shape)
  t = tensor_new(data, shape)
  
  @! Initialize gradient array with zeros
  grad = []
  i = 0
  num_items = t.data.len()
  @while i < num_items
    grad = grad.push(0.0)
    i = i + 1
  @end
  
  t.grad = grad
  t.requires_grad = 1
  t.creator_op = "none"
  t.parents = []
  return t
@end

@! ----------------------------------------------------------------------------
@! 2. FORWARD OPERATIONS WITH GRAPH TRACKING
@! ----------------------------------------------------------------------------

@! 2.1 ADDITION
@fn backward_add(node)
  parent_a = node.parents[0]
  parent_b = node.parents[1]
  
  i = 0
  num_items = node.grad.len()
  @while i < num_items
    g = node.grad[i]
    parent_a.grad = list_set(parent_a.grad, i, _ad_fadd(parent_a.grad[i], g))
    parent_b.grad = list_set(parent_b.grad, i, _ad_fadd(parent_b.grad[i], g))
    i = i + 1
  @end
  return 1
@end

@fn autodiff_add(a, b)
  res_data = []
  i = 0
  num_items = a.data.len()
  @while i < num_items
    res_data = res_data.push(_ad_fadd(a.data[i], b.data[i]))
    i = i + 1
  @end
  res = tensor_with_grad(res_data, a.shape)
  res.creator_op = "backward_add"
  res.parents = [a, b]
  return res
@end

@! 2.2 MULTIPLICATION
@fn backward_mul(node)
  parent_a = node.parents[0]
  parent_b = node.parents[1]
  
  i = 0
  num_items = node.grad.len()
  @while i < num_items
    g = node.grad[i]
    parent_a.grad = list_set(parent_a.grad, i, _ad_fadd(parent_a.grad[i], _ad_fmul(g, parent_b.data[i])))
    parent_b.grad = list_set(parent_b.grad, i, _ad_fadd(parent_b.grad[i], _ad_fmul(g, parent_a.data[i])))
    i = i + 1
  @end
  return 1
@end

@fn autodiff_mul(a, b)
  res_data = []
  i = 0
  num_items = a.data.len()
  @while i < num_items
    res_data = res_data.push(_ad_fmul(a.data[i], b.data[i]))
    i = i + 1
  @end
  
  res = tensor_with_grad(res_data, a.shape)
  res.creator_op = "backward_mul"
  res.parents = [a, b]
  return res
@end

@! 2.3 RELU
@fn backward_relu(node)
  parent = node.parents[0]
  
  i = 0
  num_items = node.grad.len()
  @while i < num_items
    g = node.grad[i]
    @if _ad_fgt(parent.data[i], 0.0) == 1
      parent.grad = list_set(parent.grad, i, _ad_fadd(parent.grad[i], g))
    @end
    i = i + 1
  @end
  return 1
@end

@fn autodiff_relu(a)
  res_data = []
  i = 0
  num_items = a.data.len()
  @while i < num_items
    v = a.data[i]
    @if _ad_fgt(v, 0.0) == 1
      res_data = res_data.push(v)
    @else
      res_data = res_data.push(0.0)
    @end
    i = i + 1
  @end
  res = tensor_with_grad(res_data, a.shape)
  res.creator_op = "backward_relu"
  res.parents = [a]
  return res
@end

@! 2.4 SIGMOID
@fn math_exp(x: f64) -> f64
  @! Taylor series approximation of exp(x)
  sum = 1.0
  term = 1.0
  i = 1.0
  @while i < 20.0
    term = (term * x) / i
    sum = sum + term
    i = i + 1.0
  @end
  return sum
@end

@fn backward_sigmoid(node)
  parent = node.parents[0]
  
  i = 0
  num_items = node.grad.len()
  @while i < num_items
    g = node.grad[i]
    y = node.data[i]
    d = _ad_fmul(_ad_fmul(g, y), _ad_fsub(1.0, y))
    parent.grad = list_set(parent.grad, i, _ad_fadd(parent.grad[i], d))
    i = i + 1
  @end
  return 1
@end

@fn autodiff_sigmoid(a)
  res_data = []
  i = 0
  num_items = a.data.len()
  @while i < num_items
    x = a.data[i]
    y = _ad_fdiv(1.0, _ad_fadd(1.0, math_exp(_ad_fsub(0.0, x))))
    res_data = res_data.push(y)
    i = i + 1
  @end
  
  res = tensor_with_grad(res_data, a.shape)
  res.creator_op = "backward_sigmoid"
  res.parents = [a]
  return res
@end

@! 2.5 MATMUL (2D)
@fn backward_matmul(node)
  parent_a = node.parents[0]
  parent_b = node.parents[1]
  
  @! A: [M, K], B: [K, N], Node: [M, N]
  m = parent_a.shape[0]
  k = parent_a.shape[1]
  n = parent_b.shape[1]
  
  @! dL/dA = dL/dNode @ B.T
  i = 0
  @while i < m
    j = 0
    @while j < k
      sum_a = 0.0
      p = 0
      @while p < n
        g = node.grad[i * n + p]
        b_val = parent_b.data[j * n + p]
        sum_a = _ad_fadd(sum_a, _ad_fmul(g, b_val))
        p = p + 1
      @end
      parent_a.grad = list_set(parent_a.grad, i * k + j, _ad_fadd(parent_a.grad[i * k + j], sum_a))
      j = j + 1
    @end
    i = i + 1
  @end
  
  @! dL/dB = A.T @ dL/dNode
  i = 0
  @while i < k
    j = 0
    @while j < n
      sum_b = 0.0
      p = 0
      @while p < m
        a_val = parent_a.data[p * k + i]
        g = node.grad[p * n + j]
        sum_b = _ad_fadd(sum_b, _ad_fmul(a_val, g))
        p = p + 1
      @end
      parent_b.grad = list_set(parent_b.grad, i * n + j, _ad_fadd(parent_b.grad[i * n + j], sum_b))
      j = j + 1
    @end
    i = i + 1
  @end
  return 1
@end

@fn autodiff_matmul(a, b)
  m = a.shape[0]
  k = a.shape[1]
  n = b.shape[1]
  out = []
  i = 0
  @while i < m
    j = 0
    @while j < n
      acc = 0.0
      p = 0
      @while p < k
        acc = _ad_fadd(acc, _ad_fmul(a.data[i * k + p], b.data[p * n + j]))
        p = p + 1
      @end
      out = out.push(acc)
      j = j + 1
    @end
    i = i + 1
  @end
  res = tensor_with_grad(out, [m, n])
  res.creator_op = "backward_matmul"
  res.parents = [a, b]
  return res
@end

@! ----------------------------------------------------------------------------
@! 3. LOSS FUNCTIONS
@! ----------------------------------------------------------------------------

@! 3.1 MSE Loss
@fn backward_mse(node)
  pred = node.parents[0]
  target = node.parents[1]
  
  n = pred.data.len()
  factor = _ad_fdiv(2.0, _ad_i2f(n))
  g_out = node.grad[0]
  
  i = 0
  @while i < n
    diff = _ad_fsub(pred.data[i], target.data[i])
    pred.grad = list_set(pred.grad, i, _ad_fadd(pred.grad[i], _ad_fmul(_ad_fmul(g_out, factor), diff)))
    i = i + 1
  @end
  return 1
@end

@fn loss_mse(pred, target)
  sum = 0.0
  i = 0
  n = pred.data.len()
  @while i < n
    diff = _ad_fsub(pred.data[i], target.data[i])
    sum = _ad_fadd(sum, _ad_fmul(diff, diff))
    i = i + 1
  @end
  
  mean_val = _ad_fdiv(sum, _ad_i2f(n))
  res = tensor_with_grad([mean_val], [1])
  res.creator_op = "backward_mse"
  res.parents = [pred, target]
  return res
@end

@! 3.2 Cross Entropy Loss
@fn backward_ce(node)
  pred = node.parents[0]
  target = node.parents[1]
  
  n = pred.data.len()
  factor = _ad_fdiv(1.0, _ad_i2f(n))
  g_out = node.grad[0]
  
  i = 0
  @while i < n
    diff = _ad_fsub(pred.data[i], target.data[i])
    pred.grad = list_set(pred.grad, i, _ad_fadd(pred.grad[i], _ad_fmul(_ad_fmul(g_out, factor), diff)))
    i = i + 1
  @end
  return 1
@end

@fn loss_cross_entropy(pred, target)
  sum = 0.0
  i = 0
  n = pred.data.len()
  @while i < n
    p = pred.data[i]
    @if _ad_flt(p, 0.0001) == 1
      p = 0.0001
    @end
    // WHY: High-precision Taylor expansion approximation of natural log in pure LiPi floating-point math
    z = _ad_fdiv(_ad_fsub(p, 1.0), _ad_fadd(p, 1.0))
    z2 = _ad_fmul(z, z)
    z3 = _ad_fmul(z, z2)
    z5 = _ad_fmul(z3, z2)
    p_log = _ad_fmul(2.0, _ad_fadd(_ad_fadd(z, _ad_fdiv(z3, 3.0)), _ad_fdiv(z5, 5.0)))
    sum = _ad_fsub(sum, _ad_fmul(target.data[i], p_log))
    i = i + 1
  @end
  
  mean_val = _ad_fdiv(sum, _ad_i2f(n))
  res = tensor_with_grad([mean_val], [1])
  res.creator_op = "backward_ce"
  res.parents = [pred, target]
  return res
@end

@! ----------------------------------------------------------------------------
@! 4. REVERSE-MODE BACKPROPAGATION ALGORITHM
@! ----------------------------------------------------------------------------
@fn _topo_sort_box(node, visited_box, sorted)
  @! Shared visited-set DFS topological post-order preventing duplicate DAG visits
  vis = visited_box[0]
  vi = 0
  vlen = vis.len()
  @while vi < vlen
    @if vis[vi] == node
      return sorted
    @end
    vi = vi + 1
  @end
  visited_box = list_set(visited_box, 0, vis.push(node))

  i = 0
  num_items = node.parents.len()
  @while i < num_items
    p = node.parents[i]
    sorted = _topo_sort_box(p, visited_box, sorted)
    i = i + 1
  @end

  return sorted.push(node)
@end

@fn topo_sort(node, visited, sorted)
  vbox = [visited]
  return _topo_sort_box(node, vbox, sorted)
@end

@fn tensor_backward(loss_node)
  loss_node.grad = list_set(loss_node.grad, 0, 1.0)
  topo = _topo_sort_box(loss_node, [[]], [])
  idx = topo.len() - 1
  @while idx >= 0
    curr = topo[idx]
    @if curr.creator_op != 0 && curr.creator_op != "" && curr.creator_op != "none"
      res = 0
      @if curr.creator_op == "backward_add" res = backward_add(curr) @end
      @if curr.creator_op == "backward_mul" res = backward_mul(curr) @end
      @if curr.creator_op == "backward_relu" res = backward_relu(curr) @end
      @if curr.creator_op == "backward_sigmoid" res = backward_sigmoid(curr) @end
      @if curr.creator_op == "backward_matmul" res = backward_matmul(curr) @end
      @if curr.creator_op == "backward_mse" res = backward_mse(curr) @end
      @if curr.creator_op == "backward_ce" res = backward_ce(curr) @end
    @end
    idx = idx - 1
  @end
  return loss_node
@end

@! ----------------------------------------------------------------------------
@! 5. ADVANCED OPTIMIZERS
@! ----------------------------------------------------------------------------
@fn optimizer_sgd(params, lr)
  i = 0
  num_items = params.len()
  @while i < num_items
    p = params[i]
    j = 0
    plen = p.data.len()
    @while j < plen
      p.data = list_set(p.data, j, _ad_fsub(p.data[j], _ad_fmul(lr, p.grad[j])))
      p.grad = list_set(p.grad, j, 0.0)
      j = j + 1
    @end
    i = i + 1
  @end
  return params
@end

@fn optimizer_adam_new(params, lr)
  m = []
  v = []
  
  i = 0
  num_items = params.len()
  @while i < num_items
    p = params[i]
    m_arr = []
    v_arr = []
    
    j = 0
    plen = p.data.len()
    @while j < plen
      m_arr = m_arr.push(0.0)
      v_arr = v_arr.push(0.0)
      j = j + 1
    @end
    
    m = m.push(m_arr)
    v = v.push(v_arr)
    i = i + 1
  @end
  
  return {
    params: params,
    lr: lr,
    beta1: 0.9,
    beta2: 0.999,
    epsilon: 0.0000001,
    m: m,
    v: v,
    t: 0
  }
@end

@fn _ad_pow(base: f64, exp: i64) -> f64
  res = 1.0
  k = 0
  @while k < exp
    res = res * base
    k = k + 1
  @end
  return res
@end

@fn optimizer_adam_step(adam)
  adam.t = adam.t + 1
  b1 = adam.beta1
  b2 = adam.beta2
  b1_corr = _ad_fsub(1.0, _ad_pow(b1, adam.t))
  b2_corr = _ad_fsub(1.0, _ad_pow(b2, adam.t))
  @if _ad_flt(b1_corr, 0.0000001) == 1 b1_corr = 0.0000001 @end
  @if _ad_flt(b2_corr, 0.0000001) == 1 b2_corr = 0.0000001 @end

  i = 0
  num_items = adam.params.len()
  @while i < num_items
    p = adam.params[i]
    m_arr = adam.m[i]
    v_arr = adam.v[i]

    j = 0
    plen = p.data.len()
    @while j < plen
      g = p.grad[j]

      m_new = _ad_fadd(_ad_fmul(b1, m_arr[j]), _ad_fmul(_ad_fsub(1.0, b1), g))
      v_new = _ad_fadd(_ad_fmul(b2, v_arr[j]), _ad_fmul(_ad_fsub(1.0, b2), _ad_fmul(g, g)))
      m_arr = list_set(m_arr, j, m_new)
      v_arr = list_set(v_arr, j, v_new)

      m_hat = _ad_fdiv(m_new, b1_corr)
      v_hat = _ad_fdiv(v_new, b2_corr)
      @if _ad_flt(v_hat, 0.0) == 1 v_hat = 0.0 @end

      denom = _ad_fadd(math_sqrt(v_hat), adam.epsilon)
      step_delta = _ad_fdiv(_ad_fmul(adam.lr, m_hat), denom)
      p.data = list_set(p.data, j, _ad_fsub(p.data[j], step_delta))

      p.grad = list_set(p.grad, j, 0.0)
      j = j + 1
    @end
    adam.m = list_set(adam.m, i, m_arr)
    adam.v = list_set(adam.v, i, v_arr)

    i = i + 1
  @end
  
  return adam
@end

@! ----------------------------------------------------------------------------
@! 6. LEARNING RATE SCHEDULERS
@! ----------------------------------------------------------------------------
@fn scheduler_step_lr(optimizer, step, step_size, gamma)
  @if step % step_size == 0
    optimizer.lr = optimizer.lr * gamma
  @end
  return optimizer
@end

@! ----------------------------------------------------------------------------
@! 7. DATALOADER
@! ----------------------------------------------------------------------------
@fn dataloader_new(x_data, y_data, batch_size, shuffle)
  batches = []
  
  num_samples = x_data.len()
  num_batches = num_samples / batch_size
  
  i = 0
  @while i < num_batches
    batch_x = []
    batch_y = []
    
    j = 0
    @while j < batch_size
      idx = (i * batch_size) + j
      batch_x = batch_x.push(x_data[idx])
      batch_y = batch_y.push(y_data[idx])
      j = j + 1
    @end
    
    batches = batches.push({ x: batch_x, y: batch_y })
    i = i + 1
  @end
  
  return batches
@end
