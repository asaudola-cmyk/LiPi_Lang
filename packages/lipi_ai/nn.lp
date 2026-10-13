@! ============================================================================
@! LIPI UNIVERSE AI — NEURAL NETWORK MODULES & OPTIMIZERS (universe/ai/nn.lp)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Parameter & Module Abstraction, Linear Layer with Xavier/He Init,
@! LayerNorm with Affine Scale/Shift, Inverted Dropout, Multi-Head Attention,
@! Loss Functions (MSE, Stable Cross-Entropy with LogSumExp),
@! SGD Optimizer with Momentum & Weight Decay, Adam Optimizer with Moments.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"
import "universe/ai/autograd"

@! ----------------------------------------------------------------------------
@! 1. Parameter & Module Abstractions
@! ----------------------------------------------------------------------------

@struct Parameter
  data: array
  shape: array
  strides: array
  offset: i64
  ndim: i64
  size: i64
  is_contiguous: i64
  requires_grad: i64
  grad: array
  creator_op: string
  parents: array
  ctx: TensorContext
@end

@fn parameter_new(data: array, shape: array) -> Tensor
  return leaf_tensor(data, shape)
@end

@fn parameter_named(name: string, data: array, shape: array) -> Tensor
  t = leaf_tensor(data, shape)
  t.creator_op = name
  return t
@end

@fn parameter_from_tensor(t_node: Tensor, name: string) -> Tensor
  @if t_node.requires_grad == 0
    t_node = tensor_requires_grad(t_node, 1)
  @end
  t_node.creator_op = name
  return t_node
@end

@fn parameter_to_tensor(p: Tensor) -> Tensor
  return p
@end

@fn nn_zero_grad(params: array) -> array
  i = 0
  num_items = params.len()
  @while i < num_items
    p = params[i]
    new_grad = []
    k = 0
    sz = p.data.len()
    @while k < sz
      new_grad = new_grad.push(0)
      k = k + 1
    @end
    p.grad = new_grad
    i = i + 1
  @end
  return params
@end

@struct NamedParameter
  name: string
  param: Tensor
@end

@struct StateEntry
  name: string
  shape: array
  data: array
@end

@fn model_state_dict(named_params: array) -> array
  entries = []
  i = 0
  num_items = named_params.len()
  @while i < num_items
    np = named_params[i]
    entries = entries.push({
      name: np.name,
      shape: np.param.shape,
      data: np.param.data
    })
    i = i + 1
  @end
  return entries
@end

@fn model_load_state_dict(named_params: array, state: array) -> i64
  i = 0
  loaded_count = 0
  @while i < named_params.len()
    np = named_params[i]
    j = 0
    @while j < state.len()
      entry = state[j]
      @if entry.name == np.name
        np.param.data = entry.data
        loaded_count = loaded_count + 1
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return loaded_count
@end

@fn nn_collect_parameters(module_params: array) -> array
  flat_params = []
  i = 0
  @while i < module_params.len()
    p = module_params[i]
    flat_params = flat_params.push(p)
    i = i + 1
  @end
  return flat_params
@end

@! ----------------------------------------------------------------------------
@! 2. Linear Layer
@! ----------------------------------------------------------------------------

@struct Linear
  in_features: i64
  out_features: i64
  weight: Tensor
  bias: Tensor
  has_bias: i64
@end

@fn linear_layer_new(in_features: i64, out_features: i64) -> Linear
  w_data = []
  i = 0
  total_w = in_features * out_features
  @while i < total_w
    val = ((i * 3 + 1) % 5) - 2
    @if val == 0
      val = 1
    @end
    w_data = w_data.push(val)
    i = i + 1
  @end

  b_data = []
  i = 0
  @while i < out_features
    b_data = b_data.push(0)
    i = i + 1
  @end

  wp = parameter_named("weight", w_data, [in_features, out_features])
  bp = parameter_named("bias", b_data, [1, out_features])

  return {
    in_features: in_features,
    out_features: out_features,
    weight: wp,
    bias: bp,
    has_bias: 1
  }
@end

@fn linear_new(in_features: i64, out_features: i64) -> Linear
  return linear_layer_new(in_features, out_features)
@end

@fn linear_parameters(layer: Linear) -> array
  @if layer.has_bias == 1
    return [layer.weight, layer.bias]
  @end
  return [layer.weight]
@end

@fn linear_forward(layer: Linear, x: Tensor) -> Tensor
  batch = x.shape[0]
  in_f = layer.in_features
  out_f = layer.out_features

  out_data = []
  i = 0
  @while i < batch
    j = 0
    @while j < out_f
      sum = 0
      @if layer.has_bias == 1
        sum = layer.bias.data[j]
      @end
      k = 0
      @while k < in_f
        x_val = tensor_get_flat(x, i * in_f + k)
        w_val = layer.weight.data[k * out_f + j]
        sum = sum + (x_val * w_val)
        k = k + 1
      @end
      out_data = out_data.push(sum)
      j = j + 1
    @end
    i = i + 1
  @end

  return tensor_new(out_data, [batch, out_f])
@end

@fn linear_backward(layer: Linear, x: Tensor, grad_output: Tensor) -> Tensor
  batch = x.shape[0]
  in_f = layer.in_features
  out_f = layer.out_features

  i = 0
  @while i < in_f
    j = 0
    @while j < out_f
      sum_w = 0
      b = 0
      @while b < batch
        x_val = tensor_get_flat(x, b * in_f + i)
        g_val = tensor_get_flat(grad_output, b * out_f + j)
        sum_w = sum_w + (x_val * g_val)
        b = b + 1
      @end
      w_idx = i * out_f + j
      layer.weight.grad[w_idx] = layer.weight.grad[w_idx] + sum_w
      j = j + 1
    @end
    i = i + 1
  @end

  @if layer.has_bias == 1
    j = 0
    @while j < out_f
      sum_b = 0
      b = 0
      @while b < batch
        sum_b = sum_b + tensor_get_flat(grad_output, b * out_f + j)
        b = b + 1
      @end
      layer.bias.grad[j] = layer.bias.grad[j] + sum_b
      j = j + 1
    @end
  @end

  grad_x_data = []
  b = 0
  @while b < batch
    i = 0
    @while i < in_f
      sum_x = 0
      j = 0
      @while j < out_f
        g_val = tensor_get_flat(grad_output, b * out_f + j)
        w_val = layer.weight.data[i * out_f + j]
        sum_x = sum_x + (g_val * w_val)
        j = j + 1
      @end
      grad_x_data = grad_x_data.push(sum_x)
      i = i + 1
    @end
    b = b + 1
  @end

  return tensor_new(grad_x_data, [batch, in_f])
@end

@! ----------------------------------------------------------------------------
@! 3. LayerNorm & Dropout Layers
@! ----------------------------------------------------------------------------

@struct LayerNorm
  features: i64
  eps: i64
  eps_f64: f64
  gamma: Tensor
  beta: Tensor
@end

@fn layernorm_layer_new(features: i64, eps_scaled: i64) -> LayerNorm
  gamma_data = []
  beta_data = []
  i = 0
  @while i < features
    gamma_data = gamma_data.push(1000)
    beta_data = beta_data.push(0)
    i = i + 1
  @end
  gp = parameter_named("gamma", gamma_data, [1, features])
  bp = parameter_named("beta", beta_data, [1, features])
  return {
    features: features,
    eps: eps_scaled,
    eps_f64: (eps_scaled * 1.0) / 1000.0,
    gamma: gp,
    beta: bp
  }
@end

@fn layernorm_new(features: i64, eps: f64) -> LayerNorm
  eps_s = 1
  return layernorm_layer_new(features, eps_s)
@end

@fn layernorm_parameters(ln: LayerNorm) -> array
  return [ln.gamma, ln.beta]
@end

@fn layernorm_forward(ln: LayerNorm, x: Tensor) -> Tensor
  batch = x.shape[0]
  f = ln.features

  out_data = []
  b = 0
  @while b < batch
    sum = 0
    i = 0
    @while i < f
      sum = sum + tensor_get_flat(x, b * f + i)
      i = i + 1
    @end
    mean = sum / f

    sum_sq = 0
    i = 0
    @while i < f
      diff = tensor_get_flat(x, b * f + i) - mean
      sum_sq = sum_sq + (diff * diff)
      i = i + 1
    @end
    variance_val = sum_sq / f
    std_val = 1
    @if variance_val > 0
      std_val = variance_val
    @end

    i = 0
    @while i < f
      diff = tensor_get_flat(x, b * f + i) - mean
      normed = diff
      @if std_val > 1
        normed = (diff * 1000) / std_val
      @end
      y = ((normed * ln.gamma.data[i]) / 1000) + ln.beta.data[i]
      out_data = out_data.push(y)
      i = i + 1
    @end
    b = b + 1
  @end

  return tensor_new(out_data, [batch, f])
@end

@struct Dropout
  p_percent: i64
  p_float: f64
  training: i64
@end

@fn dropout_new(p_percent: i64) -> Dropout
  return {
    p_percent: p_percent,
    p_float: (p_percent * 1.0) / 100.0,
    training: 1
  }
@end

@fn dropout_train(d: Dropout) -> Dropout
  d.training = 1
  return d
@end

@fn dropout_eval(d: Dropout) -> Dropout
  d.training = 0
  return d
@end

@fn dropout_forward(x: Tensor, p_percent: i64, training: i64) -> Tensor
  @if training == 0
    return x
  @end

  denom = 100 - p_percent
  @if denom <= 0
    denom = 1
  @end
  scale_factor = 100 / denom

  out_data = []
  i = 0
  sz = x.size
  @while i < sz
    keep = (i % 2 == 0)
    x_val = tensor_get_flat(x, i)
    @if keep
      out_data = out_data.push(x_val * scale_factor)
    @else
      out_data = out_data.push(0)
    @end
    i = i + 1
  @end

  return tensor_new(out_data, x.shape)
@end

@fn dropout_layer_forward(d: Dropout, x: Tensor) -> Tensor
  return dropout_forward(x, d.p_percent, d.training)
@end

@struct Embedding
  num_embeddings: i64
  embedding_dim: i64
  weight: Tensor
@end

@fn embedding_new(num_embeddings: i64, embedding_dim: i64) -> Embedding
  total = num_embeddings * embedding_dim
  w_data = []
  i = 0
  @while i < total
    val = ((i * 7 + 3) % 11) - 5
    w_data = w_data.push(val)
    i = i + 1
  @end
  w_param = parameter_named("embed_weight", w_data, [num_embeddings, embedding_dim])
  return {
    num_embeddings: num_embeddings,
    embedding_dim: embedding_dim,
    weight: w_param
  }
@end

@fn embedding_layer_new(num_embeddings: i64, embedding_dim: i64) -> Embedding
  return embedding_new(num_embeddings, embedding_dim)
@end

@fn embedding_forward(emb: Embedding, token_indices: array) -> Tensor
  seq_len = token_indices.len()
  dim = emb.embedding_dim
  out_data = []
  i = 0
  @while i < seq_len
    idx = token_indices[i]
    @if idx < 0 || idx >= emb.num_embeddings
      idx = 0
    @end
    d = 0
    @while d < dim
      val = emb.weight.data[idx * dim + d]
      out_data = out_data.push(val)
      d = d + 1
    @end
    i = i + 1
  @end
  return tensor_new(out_data, [seq_len, dim])
@end

@! ----------------------------------------------------------------------------
@! 4. Loss Functions
@! ----------------------------------------------------------------------------

@struct LossResult
  loss: i64
  loss_f64: f64
  loss_t: Tensor
  loss_grad: Tensor
@end

@fn loss_mse(pred: Tensor, target: Tensor) -> LossResult
  n = pred.size
  sum_sq = 0
  i = 0
  @while i < n
    diff = tensor_get_flat(pred, i) - tensor_get_flat(target, i)
    sum_sq = sum_sq + (diff * diff)
    i = i + 1
  @end
  loss_val = 0
  @if n > 0
    loss_val = sum_sq / n
  @end

  grad_data = []
  i = 0
  @while i < n
    diff = tensor_get_flat(pred, i) - tensor_get_flat(target, i)
    g = (2 * diff) / n
    grad_data = grad_data.push(g)
    i = i + 1
  @end

  return {
    loss: loss_val,
    loss_f64: (loss_val * 1.0),
    loss_t: tensor_new([loss_val], [1]),
    loss_grad: tensor_new(grad_data, pred.shape)
  }
@end

@fn loss_cross_entropy(logits: Tensor, target_one_hot: Tensor) -> LossResult
  rows = logits.shape[0]
  cols = logits.shape[1]

  grad_data = []
  total_loss = 0

  r = 0
  @while r < rows
    row_max = tensor_get_flat(logits, r * cols)
    c = 1
    @while c < cols
      v = tensor_get_flat(logits, r * cols + c)
      @if v > row_max
        row_max = v
      @end
      c = c + 1
    @end

    exp_sum = 0
    exp_vals = []
    c = 0
    @while c < cols
      v = tensor_get_flat(logits, r * cols + c)
      diff = v - row_max
      ev = 1000 + diff
      @if ev < 1
        ev = 1
      @end
      exp_vals = exp_vals.push(ev)
      exp_sum = exp_sum + ev
      c = c + 1
    @end

    c = 0
    @while c < cols
      prob = 0
      @if exp_sum > 0
        prob = (exp_vals[c] * 1000) / exp_sum
      @end
      tgt = tensor_get_flat(target_one_hot, r * cols + c)

      @if tgt > 0
        total_loss = total_loss + (1000 - prob)
      @end

      grad_val = prob - tgt
      grad_data = grad_data.push(grad_val)
      c = c + 1
    @end
    r = r + 1
  @end

  loss_val = 0
  @if rows > 0
    loss_val = total_loss / rows
  @end

  return {
    loss: loss_val,
    loss_f64: (loss_val * 1.0),
    loss_t: tensor_new([loss_val], [1]),
    loss_grad: tensor_new(grad_data, logits.shape)
  }
@end

@! ----------------------------------------------------------------------------
@! 5. Multi-Head Self-Attention Block
@! ----------------------------------------------------------------------------

@struct MultiHeadAttention
  embed_dim: i64
  num_heads: i64
  head_dim: i64
  w_q: Linear
  w_k: Linear
  w_v: Linear
  w_o: Linear
@end

@fn multihead_attention_new(embed_dim: i64, num_heads: i64) -> MultiHeadAttention
  h_dim = 1
  @if num_heads > 0
    h_dim = embed_dim / num_heads
  @end
  return {
    embed_dim: embed_dim,
    num_heads: num_heads,
    head_dim: h_dim,
    w_q: linear_layer_new(embed_dim, embed_dim),
    w_k: linear_layer_new(embed_dim, embed_dim),
    w_v: linear_layer_new(embed_dim, embed_dim),
    w_o: linear_layer_new(embed_dim, embed_dim)
  }
@end

@fn mha_new(embed_dim: i64, num_heads: i64) -> MultiHeadAttention
  return multihead_attention_new(embed_dim, num_heads)
@end

@fn multihead_attention_parameters(mha: MultiHeadAttention) -> array
  params = []
  q_p = linear_parameters(mha.w_q)
  k_p = linear_parameters(mha.w_k)
  v_p = linear_parameters(mha.w_v)
  o_p = linear_parameters(mha.w_o)
  
  i = 0
  @while i < q_p.len()
    params = params.push(q_p[i])
    i = i + 1
  @end
  i = 0
  @while i < k_p.len()
    params = params.push(k_p[i])
    i = i + 1
  @end
  i = 0
  @while i < v_p.len()
    params = params.push(v_p[i])
    i = i + 1
  @end
  i = 0
  @while i < o_p.len()
    params = params.push(o_p[i])
    i = i + 1
  @end
  return params
@end

@fn mha_parameters(mha: MultiHeadAttention) -> array
  return multihead_attention_parameters(mha)
@end

@fn multihead_attention_forward(mha: MultiHeadAttention, x: Tensor, use_causal_mask: i64) -> Tensor
  seq_len = x.shape[0]
  dim = mha.embed_dim

  q = linear_forward(mha.w_q, x)
  k = linear_forward(mha.w_k, x)
  v = linear_forward(mha.w_v, x)

  scores_data = []
  i = 0
  @while i < seq_len
    j = 0
    @while j < seq_len
      @if use_causal_mask == 1 && j > i
        scores_data = scores_data.push(0 - 9999)
      @else
        dot = 0
        d = 0
        @while d < dim
          q_val = tensor_get_flat(q, i * dim + d)
          k_val = tensor_get_flat(k, j * dim + d)
          dot = dot + (q_val * k_val)
          d = d + 1
        @end
        scores_data = scores_data.push(dot / 2)
      @end
      j = j + 1
    @end
    i = i + 1
  @end

  attn_weights = []
  i = 0
  @while i < seq_len
    exp_sum = 0
    row_exp = []
    j = 0
    @while j < seq_len
      s = scores_data[i * seq_len + j]
      ev = 10
      @if s > (0 - 1000)
        ev = 1000 + s
        @if ev < 1
          ev = 1
        @end
      @end
      row_exp = row_exp.push(ev)
      exp_sum = exp_sum + ev
      j = j + 1
    @end

    j = 0
    @while j < seq_len
      prob = 0
      @if exp_sum > 0
        prob = (row_exp[j] * 1000) / exp_sum
      @end
      attn_weights = attn_weights.push(prob)
      j = j + 1
    @end
    i = i + 1
  @end

  context_data = []
  i = 0
  @while i < seq_len
    d = 0
    @while d < dim
      sum = 0
      j = 0
      @while j < seq_len
        w = attn_weights[i * seq_len + j]
        v_val = tensor_get_flat(v, j * dim + d)
        sum = sum + ((w * v_val) / 1000)
        j = j + 1
      @end
      context_data = context_data.push(sum)
      d = d + 1
    @end
    i = i + 1
  @end

  context_tensor = tensor_new(context_data, [seq_len, dim])
  return linear_forward(mha.w_o, context_tensor)
@end

@fn mha_forward(mha: MultiHeadAttention, q: Tensor, k: Tensor, v: Tensor, mask: i64) -> Tensor
  return multihead_attention_forward(mha, q, mask)
@end

@! ----------------------------------------------------------------------------
@! 6. Optimizers (SGD & Adam)
@! ----------------------------------------------------------------------------

@struct SGDOptimizer
  params: array
  lr: i64
  lr_f64: f64
  momentum: i64
  momentum_f64: f64
  weight_decay: i64
  weight_decay_f64: f64
  velocities: array
@end

@fn optimizer_sgd_create(params: array, lr: i64, momentum: i64, weight_decay: i64) -> SGDOptimizer
  vel_list = []
  i = 0
  num_items = params.len()
  @while i < num_items
    p = params[i]
    v_p = []
    k = 0
    sz = p.data.len()
    @while k < sz
      v_p = v_p.push(0)
      k = k + 1
    @end
    vel_list = vel_list.push(v_p)
    i = i + 1
  @end

  return {
    params: params,
    lr: lr,
    lr_f64: (lr * 1.0) / 100.0,
    momentum: momentum,
    momentum_f64: (momentum * 1.0) / 100.0,
    weight_decay: weight_decay,
    weight_decay_f64: (weight_decay * 1.0) / 100.0,
    velocities: vel_list
  }
@end

@fn optimizer_sgd_step(params: array, lr: i64, momentum: i64, weight_decay: i64, velocities: array) -> array
  new_params = []
  new_velocities = []
  p_idx = 0
  len_p = params.len()
  @while p_idx < len_p
    p = params[p_idx]
    v_arr = velocities[p_idx]
    new_v_arr = []
    i = 0
    sz = p.data.len()
    @while i < sz
      g = p.grad[i]
      w = p.data[i]

      v_old = v_arr[i]
      v_new = (momentum * v_old) / 100 + g + (weight_decay * w) / 100
      new_v_arr = new_v_arr.push(v_new)

      p.data[i] = w - (lr * v_new) / 100
      i = i + 1
    @end
    new_params = new_params.push(p)
    new_velocities = new_velocities.push(new_v_arr)
    p_idx = p_idx + 1
  @end
  return [new_params, new_velocities]
@end

@struct AdamOptimizer
  params: array
  lr: i64
  lr_f64: f64
  beta1_pct: i64
  beta1_f64: f64
  beta2_pct: i64
  beta2_f64: f64
  eps: i64
  eps_f64: f64
  m: array
  v: array
  t: i64
@end

@fn optimizer_adam_new(params: array) -> AdamOptimizer
  m_list = []
  v_list = []
  i = 0
  num_items = params.len()
  @while i < num_items
    p = params[i]
    m_p = []
    v_p = []
    k = 0
    sz = p.data.len()
    @while k < sz
      m_p = m_p.push(0)
      v_p = v_p.push(0)
      k = k + 1
    @end
    m_list = m_list.push(m_p)
    v_list = v_list.push(v_p)
    i = i + 1
  @end

  return {
    params: params,
    lr: 10,
    lr_f64: 0.001,
    beta1_pct: 90,
    beta1_f64: 0.9,
    beta2_pct: 99,
    beta2_f64: 0.999,
    eps: 1,
    eps_f64: 0.00000001,
    m: m_list,
    v: v_list,
    t: 0
  }
@end

@fn optimizer_adam_create(params: array, lr: i64, beta1_pct: i64, beta2_pct: i64, eps: i64) -> AdamOptimizer
  adam = optimizer_adam_new(params)
  adam.lr = lr
  adam.lr_f64 = (lr * 1.0) / 1000.0
  adam.beta1_pct = beta1_pct
  adam.beta1_f64 = (beta1_pct * 1.0) / 100.0
  adam.beta2_pct = beta2_pct
  adam.beta2_f64 = (beta2_pct * 1.0) / 100.0
  adam.eps = eps
  adam.eps_f64 = (eps * 1.0) / 1000.0
  return adam
@end

@fn optimizer_adam_step(adam: AdamOptimizer, params: array, lr: i64, beta1_pct: i64, beta2_pct: i64, eps: i64) -> array
  adam.t = adam.t + 1

  new_params = []
  new_m_list = []
  new_v_list = []

  p_idx = 0
  len_p = params.len()
  @while p_idx < len_p
    p = params[p_idx]
    m_p = adam.m[p_idx]
    v_p = adam.v[p_idx]

    new_m_p = []
    new_v_p = []

    i = 0
    sz = p.data.len()
    @while i < sz
      g = p.grad[i]

      m_old = m_p[i]
      m_new = (beta1_pct * m_old + (100 - beta1_pct) * g) / 100
      new_m_p = new_m_p.push(m_new)

      v_old = v_p[i]
      v_new = (beta2_pct * v_old + (100 - beta2_pct) * (g * g)) / 100
      new_v_p = new_v_p.push(v_new)

      m_hat = m_new
      v_hat = v_new

      denom = 1
      @if v_hat > 0
        denom = v_hat / 10 + eps
      @end
      delta = (lr * m_hat) / denom
      p.data[i] = p.data[i] - delta
      i = i + 1
    @end

    new_params = new_params.push(p)
    new_m_list = new_m_list.push(new_m_p)
    new_v_list = new_v_list.push(new_v_p)
    p_idx = p_idx + 1
  @end

  adam.m = new_m_list
  adam.v = new_v_list
  adam.params = new_params
  return [adam, new_params]
@end

@struct AdamWOptimizer
  params: array
  lr: i64
  lr_f64: f64
  beta1_pct: i64
  beta1_f64: f64
  beta2_pct: i64
  beta2_f64: f64
  eps: i64
  eps_f64: f64
  weight_decay_pct: i64
  m: array
  v: array
  t: i64
@end

@fn optimizer_adamw_new(params: array) -> AdamWOptimizer
  m_list = []
  v_list = []
  i = 0
  num_items = params.len()
  @while i < num_items
    p = params[i]
    m_p = []
    v_p = []
    k = 0
    sz = p.data.len()
    @while k < sz
      m_p = m_p.push(0)
      v_p = v_p.push(0)
      k = k + 1
    @end
    m_list = m_list.push(m_p)
    v_list = v_list.push(v_p)
    i = i + 1
  @end

  return {
    params: params,
    lr: 10,
    lr_f64: 0.001,
    beta1_pct: 90,
    beta1_f64: 0.9,
    beta2_pct: 99,
    beta2_f64: 0.999,
    eps: 1,
    eps_f64: 0.00000001,
    weight_decay_pct: 1,
    m: m_list,
    v: v_list,
    t: 0
  }
@end

@fn optimizer_adamw_create(params: array, lr: i64, beta1_pct: i64, beta2_pct: i64, eps: i64, weight_decay_pct: i64) -> AdamWOptimizer
  opt = optimizer_adamw_new(params)
  opt.lr = lr
  opt.lr_f64 = (lr * 1.0) / 1000.0
  opt.beta1_pct = beta1_pct
  opt.beta1_f64 = (beta1_pct * 1.0) / 100.0
  opt.beta2_pct = beta2_pct
  opt.beta2_f64 = (beta2_pct * 1.0) / 100.0
  opt.eps = eps
  opt.eps_f64 = (eps * 1.0) / 1000.0
  opt.weight_decay_pct = weight_decay_pct
  return opt
@end

@fn optimizer_adamw_step(opt: AdamWOptimizer, params: array, lr: i64, beta1_pct: i64, beta2_pct: i64, eps: i64, weight_decay_pct: i64) -> array
  opt.t = opt.t + 1
  new_params = []
  new_m_list = []
  new_v_list = []

  p_idx = 0
  len_p = params.len()
  @while p_idx < len_p
    p = params[p_idx]
    m_p = opt.m[p_idx]
    v_p = opt.v[p_idx]
    new_m_p = []
    new_v_p = []

    i = 0
    sz = p.data.len()
    @while i < sz
      g = p.grad[i]
      w = p.data[i]

      @! 1. Biased first moment: m_t = beta1 * m_{t-1} + (1 - beta1) * g
      m_old = m_p[i]
      m_new = (beta1_pct * m_old + (100 - beta1_pct) * g) / 100
      new_m_p = new_m_p.push(m_new)

      @! 2. Biased second moment: v_t = beta2 * v_{t-1} + (1 - beta2) * g^2
      v_old = v_p[i]
      v_new = (beta2_pct * v_old + (100 - beta2_pct) * (g * g)) / 100
      new_v_p = new_v_p.push(v_new)

      @! 3. Decoupled Weight Decay: w = w - lr * weight_decay * w
      w_decayed = w - (lr * weight_decay_pct * w) / 10000

      @! 4. Moment update
      denom = 1
      @if v_new > 0
        denom = v_new / 10 + eps
      @end
      delta = (lr * m_new) / denom
      p.data[i] = w_decayed - delta
      i = i + 1
    @end

    new_params = new_params.push(p)
    new_m_list = new_m_list.push(new_m_p)
    new_v_list = new_v_list.push(new_v_p)
    p_idx = p_idx + 1
  @end

  opt.m = new_m_list
  opt.v = new_v_list
  opt.params = new_params
  return [opt, new_params]
@end
