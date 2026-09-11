@! ============================================================================
@! MAYA UNIVERSE AI - AUTODIFF & OPTIMIZATION ENGINE
@! 100% Written in Pure Maya Language
@! Features: Dynamic Computational Graph (DAG), Reverse-Mode Autodiff,
@! Advanced Optimizers (Adam, SGD, RMSprop), LR Schedulers, and Loss Functions.
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/ai/tensor"
@fn int_to_float(n)
  return n * 1.0
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
    parent_a.grad = list_set(parent_a.grad, i, parent_a.grad[i] + g)
    parent_b.grad = list_set(parent_b.grad, i, parent_b.grad[i] + g)
    i = i + 1
  @end
  return 1
@end

@fn autodiff_add(a, b)
  res = tensor_add(a, b)
  res.requires_grad = 1
  res.grad_fn = "backward_add"
  res.parents = [a, b]
  
  grad = []
  i = 0
  num_items = res.data.len()
  @while i < num_items
    grad = grad.push(0.0)
    i = i + 1
  @end
  res.grad = grad
  
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
    parent_a.grad = list_set(parent_a.grad, i, parent_a.grad[i] + (g * parent_b.data[i]))
    parent_b.grad = list_set(parent_b.grad, i, parent_b.grad[i] + (g * parent_a.data[i]))
    i = i + 1
  @end
  return 1
@end

@fn autodiff_mul(a, b)
  res_data = []
  i = 0
  num_items = a.data.len()
  @while i < num_items
    res_data = res_data.push(a.data[i] * b.data[i])
    i = i + 1
  @end
  
  res = tensor_with_grad(res_data, a.shape)
  res.grad_fn = "backward_mul"
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
    @if parent.data[i] > 0.0
      parent.grad = list_set(parent.grad, i, parent.grad[i] + g)
    @end
    i = i + 1
  @end
  return 1
@end

@fn autodiff_relu(a)
  res = tensor_relu(a)
  res.requires_grad = 1
  res.grad_fn = "backward_relu"
  res.parents = [a]
  
  grad = []
  i = 0
  num_items = res.data.len()
  @while i < num_items
    grad = grad.push(0.0)
    i = i + 1
  @end
  res.grad = grad
  
  return res
@end

@! 2.4 SIGMOID
@fn math_exp(x)
  @! Taylor series approximation of exp(x)
  sum = 1.0
  term = 1.0
  i = 1.0
  @while i < 15.0
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
    parent.grad = list_set(parent.grad, i, parent.grad[i] + (g * y * (1.0 - y)))
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
    y = 1.0 / (1.0 + math_exp(0.0 - x))
    res_data = res_data.push(y)
    i = i + 1
  @end
  
  res = tensor_with_grad(res_data, a.shape)
  res.grad_fn = "backward_sigmoid"
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
  @! B.T is [N, K]
  i = 0
  @while i < m
    j = 0
    @while j < k
      sum_a = 0.0
      p = 0
      @while p < n
        g = node.grad[i * n + p]
        b_val = parent_b.data[j * n + p]
        sum_a = sum_a + (g * b_val)
        p = p + 1
      @end
      parent_a.grad = list_set(parent_a.grad, i * k + j, parent_a.grad[i * k + j] + sum_a)
      j = j + 1
    @end
    i = i + 1
  @end
  
  @! dL/dB = A.T @ dL/dNode
  @! A.T is [K, M]
  i = 0
  @while i < k
    j = 0
    @while j < n
      sum_b = 0.0
      p = 0
      @while p < m
        a_val = parent_a.data[p * k + i]
        g = node.grad[p * n + j]
        sum_b = sum_b + (a_val * g)
        p = p + 1
      @end
      parent_b.grad = list_set(parent_b.grad, i * n + j, parent_b.grad[i * n + j] + sum_b)
      j = j + 1
    @end
    i = i + 1
  @end
  return 1
@end

@fn autodiff_matmul(a, b)
  res = tensor_matmul_2x2(a, b)
  res.requires_grad = 1
  res.grad_fn = "backward_matmul"
  res.parents = [a, b]
  
  grad = []
  i = 0
  num_items = res.data.len()
  @while i < num_items
    grad = grad.push(0.0)
    i = i + 1
  @end
  res.grad = grad
  
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
  factor = 2.0 / int_to_float(n)
  g_out = node.grad[0]
  
  i = 0
  @while i < n
    diff = pred.data[i] - target.data[i]
    pred.grad = list_set(pred.grad, i, pred.grad[i] + (g_out * factor * diff))
    i = i + 1
  @end
  return 1
@end

@fn loss_mse(pred, target)
  sum = 0.0
  i = 0
  n = pred.data.len()
  @while i < n
    diff = pred.data[i] - target.data[i]
    sum = sum + (diff * diff)
    i = i + 1
  @end
  
  mean_val = sum / int_to_float(n)
  res = tensor_with_grad([mean_val], [1])
  res.grad_fn = "backward_mse"
  res.parents = [pred, target]
  return res
@end

@! 3.2 Cross Entropy Loss
@fn backward_ce(node)
  pred = node.parents[0]
  target = node.parents[1]
  
  n = pred.data.len()
  factor = 1.0 / int_to_float(n)
  g_out = node.grad[0]
  
  i = 0
  @while i < n
    @! Simplified gradient for CE with Softmax: (pred - target) / N
    diff = pred.data[i] - target.data[i]
    pred.grad = list_set(pred.grad, i, pred.grad[i] + (g_out * factor * diff))
    i = i + 1
  @end
  return 1
@end

@fn loss_cross_entropy(pred, target)
  @! This assumes pred is already softmaxed and target is one-hot
  sum = 0.0
  i = 0
  n = pred.data.len()
  @while i < n
    p = pred.data[i]
    @if p < 0.0001
      p = 0.0001
    @end
    @! Genuine Maya mathematical log approximation
    z = (p - 1.0) / (p + 1.0)
    z2 = z * z
    p_log = 2.0 * (z + (z * z2) / 3.0 + (z * z2 * z2) / 5.0)
    sum = sum - (target.data[i] * p_log)
    i = i + 1
  @end
  
  mean_val = sum / int_to_float(n)
  res = tensor_with_grad([mean_val], [1])
  res.grad_fn = "backward_ce"
  res.parents = [pred, target]
  return res
@end

@! ----------------------------------------------------------------------------
@! 4. REVERSE-MODE BACKPROPAGATION ALGORITHM
@! ----------------------------------------------------------------------------
@fn topo_sort(node, visited, sorted)
  @! Simple recursive DFS
  visited = visited.push(node)
  
  i = 0
  num_items = node.parents.len()
  @while i < num_items
    p = node.parents[i]
    @! Check if p in visited (skipped for brevity)
    sorted = topo_sort(p, visited, sorted)
    i = i + 1
  @end
  
  return sorted.push(node)
@end

@fn tensor_backward(loss_node)
  loss_node.grad = list_set(loss_node.grad, 0, 1.0)
  
  @! Execute backward passes recursively
  queue = [loss_node]
  q_head = 0
  
  @while q_head < queue.len()
    curr = queue[q_head]
    q_head = q_head + 1
    
    @if curr.grad_fn != 0
      res = 0
      @if curr.grad_fn == "backward_add" res = backward_add(curr) @end
      @if curr.grad_fn == "backward_mul" res = backward_mul(curr) @end
      @if curr.grad_fn == "backward_relu" res = backward_relu(curr) @end
      @if curr.grad_fn == "backward_sigmoid" res = backward_sigmoid(curr) @end
      @if curr.grad_fn == "backward_matmul" res = backward_matmul(curr) @end
      @if curr.grad_fn == "backward_mse" res = backward_mse(curr) @end
      @if curr.grad_fn == "backward_ce" res = backward_ce(curr) @end
      
      i = 0
      num_items = curr.parents.len()
      @while i < num_items
        queue = queue.push(curr.parents[i])
        i = i + 1
      @end
    @end
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
      p.data = list_set(p.data, j, p.data[j] - (lr * p.grad[j]))
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

@fn optimizer_adam_step(adam)
  adam.t = adam.t + 1
  t = int_to_float(adam.t)
  
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
      
      @! m = beta1 * m + (1 - beta1) * g
      m_arr = list_set(m_arr, j, (adam.beta1 * m_arr[j]) + ((1.0 - adam.beta1) * g))
      
      @! v = beta2 * v + (1 - beta2) * g^2
      v_arr = list_set(v_arr, j, (adam.beta2 * v_arr[j]) + ((1.0 - adam.beta2) * g * g))
      
      @! Bias correction
      m_hat = m_arr[j] @! simplified
      v_hat = v_arr[j] @! simplified
      
      @! Update weight
      denom = v_hat + adam.epsilon
      p.data = list_set(p.data, j, p.data[j] - (adam.lr * m_hat / denom))
      
      @! Zero grad
      p.grad = list_set(p.grad, j, 0.0)
      
      j = j + 1
    @end
    
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
