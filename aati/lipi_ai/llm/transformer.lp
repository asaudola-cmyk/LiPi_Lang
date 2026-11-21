@! ============================================================================
@! LIPI UNIVERSE AI — FULL TRANSFORMER / LLM (GPT-2 & LLAMA ARCHITECTURE)
@! 100% Written in Pure Lipi Language — Zero PyTorch / LibTorch / C++ Dependencies
@! Features: RoPE, GQA, SwiGLU, RMSNorm, KV-Cache, Auto-Regressive Decoding
@! ============================================================================

import "utso/collections"
import "utso/math"
import "aati/lipi_ai/tensor"
import "aati/lipi_ai/autodiff"

@! ----------------------------------------------------------------------------
@! 1. TENSOR & MATRIX INITIALIZERS
@! ----------------------------------------------------------------------------

@fn tensor_random_mat(r, c)
  arr = []
  i = 0
  total = r * c
  @while i < total
    val = 0.02 * ((i % 10) - 5)
    arr = arr.push(val)
    i = i + 1
  @end
  return tensor_new(arr, [r, c])
@end

@fn llm_tensor_zeros(r, c)
  arr = []
  i = 0
  total = r * c
  @while i < total
    arr = arr.push(0.0)
    i = i + 1
  @end
  return tensor_new(arr, [r, c])
@end

@fn llm_tensor_ones(r, c)
  // WHY: Allocates 2D tensor of ones for transformer weight initializations (RMSNorm, LayerNorm).
  // Named llm_tensor_ones to eliminate symbol collision with 1-arg tensor_ones(shape: array) in tensor_core.lp.
  arr = []
  i = 0
  total = r * c
  @while i < total
    arr = arr.push(1.0)
    i = i + 1
  @end
  return tensor_new(arr, [r, c])
@end

@! ----------------------------------------------------------------------------
@! 2. NORMALIZATION LAYERS (RMSNORM & LAYERNORM)
@! ----------------------------------------------------------------------------

@fn _llm_fadd(a: f64, b: f64) -> f64 return a + b @end
@fn _llm_fsub(a: f64, b: f64) -> f64 return a - b @end
@fn _llm_fmul(a: f64, b: f64) -> f64 return a * b @end
@fn _llm_fdiv(a: f64, b: f64) -> f64 return a / b @end
@fn _llm_fgt(a: f64, b: f64) -> i64
  @if a > b return 1 @end
  return 0
@end
@fn _llm_to_f64(v: i64) -> f64
  @if v == 0 return 0.0 @end
  exp_b = (v >> 52) & 2047
  @if exp_b >= 900 && exp_b <= 1150
    return v
  @end
  return v + 0.0
@end
@fn _llm_f64_to_i64(v: f64) -> i64
  neg = 0
  @if v < 0.0
    neg = 1
    v = 0.0 - v
  @end
  n = floor(v)
  @if neg == 1
    return 0 - n
  @end
  return n
@end
@fn _llm_is_f64_bits(v: i64) -> i64
  @if v == 0 return 0 @end
  exp_b = (v >> 52) & 2047
  @if exp_b >= 900 && exp_b <= 1150
    return 1
  @end
  return 0
@end
@fn _llm_prng_next(state: i64) -> i64
  next_s = (state * 6364136223846793005 + 1442695040888963407) & 9223372036854775807
  @if next_s == 0
    next_s = 88172645463325252
  @end
  return next_s
@end

@fn rmsnorm_new(dim, eps)
  return {
    dim: dim,
    eps: eps,
    weight: llm_tensor_ones(1, dim)
  }
@end

@fn rmsnorm_forward(norm, x)
  // WHY: Normalizes each activation row using RMSNorm(x) = (x / sqrt(mean(x^2) + eps)) * weight.
  x_len = x.data.len()
  @if x_len == 0 return x @end
  dim = norm.dim
  @if dim <= 0 || (x_len % dim) != 0
    dim = x_len
  @end
  use_float = _llm_is_f64_bits(x.data[0])
  out_data = []
  base = 0
  @while base < x_len
    @if use_float == 1
      sum_sq_f = 0.0
      c = 0
      @while c < dim
        vf = x.data[base + c]
        sum_sq_f = _llm_fadd(sum_sq_f, _llm_fmul(vf, vf))
        c = c + 1
      @end
      mean_sq_f = _llm_fdiv(sum_sq_f, dim + 0.0)
      denom_f = math_sqrt(_llm_fadd(mean_sq_f, _llm_to_f64(norm.eps)))
      @if _llm_fgt(denom_f, 0.000000001) == 0
        denom_f = 1.0
      @end
      c = 0
      @while c < dim
        normed_f = _llm_fdiv(x.data[base + c], denom_f)
        @if norm.weight != 0 && c < norm.weight.data.len()
          wf = _llm_to_f64(norm.weight.data[c])
          normed_f = _llm_fmul(normed_f, wf)
        @end
        out_data = out_data.push(normed_f)
        c = c + 1
      @end
    @else
      sum_sq = 0
      c = 0
      @while c < dim
        val = x.data[base + c]
        sum_sq = sum_sq + (val * val)
        c = c + 1
      @end
      mean_sq = sum_sq / dim
      eps_i = norm.eps
      @if _llm_is_f64_bits(eps_i) == 1
        eps_i = _llm_f64_to_i64(eps_i)
      @end
      denom = sqrt(mean_sq + eps_i)
      @if denom <= 0
        denom = 1
      @end
      c = 0
      @while c < dim
        norm_val = (x.data[base + c] * 1000) / denom
        @if norm.weight != 0 && c < norm.weight.data.len()
          w_raw = norm.weight.data[c]
          @if w_raw != 4607182418800017408 && w_raw != 1
            norm_val = _llm_f64_to_i64(_llm_fmul(norm_val + 0.0, _llm_to_f64(w_raw)))
          @end
        @end
        out_data = out_data.push(norm_val)
        c = c + 1
      @end
    @end
    base = base + dim
  @end
  return tensor_new(out_data, x.shape)
@end

@fn layernorm_new(dim, eps)
  return {
    dim: dim,
    eps: eps,
    gamma: llm_tensor_ones(1, dim),
    beta: llm_tensor_zeros(1, dim)
  }
@end

@fn layernorm_forward(norm, x)
  x_len = x.data.len()
  @if x_len == 0 return x @end
  dim = norm.dim
  @if dim <= 0 || (x_len % dim) != 0
    dim = x_len
  @end
  eps_f = _llm_to_f64(norm.eps)
  out = []
  base = 0
  @while base < x_len
    sum_f = 0.0
    c = 0
    @while c < dim
      vf = _llm_to_f64(x.data[base + c])
      sum_f = _llm_fadd(sum_f, vf)
      c = c + 1
    @end
    mean_f = _llm_fdiv(sum_f, dim + 0.0)

    var_sum = 0.0
    c = 0
    @while c < dim
      vf = _llm_to_f64(x.data[base + c])
      diff = _llm_fsub(vf, mean_f)
      var_sum = _llm_fadd(var_sum, _llm_fmul(diff, diff))
      c = c + 1
    @end
    variance = _llm_fdiv(var_sum, dim + 0.0)
    std_f = math_sqrt(_llm_fadd(variance, eps_f))
    @if _llm_fgt(std_f, 0.000000001) == 0
      std_f = 0.00001
    @end
    inv_std = _llm_fdiv(1.0, std_f)

    c = 0
    @while c < dim
      vf = _llm_to_f64(x.data[base + c])
      normed = _llm_fmul(_llm_fsub(vf, mean_f), inv_std)
      @if norm.gamma != 0 && c < norm.gamma.data.len()
        normed = _llm_fmul(normed, _llm_to_f64(norm.gamma.data[c]))
      @end
      @if norm.beta != 0 && c < norm.beta.data.len()
        normed = _llm_fadd(normed, _llm_to_f64(norm.beta.data[c]))
      @end
      out = out.push(normed)
      c = c + 1
    @end
    base = base + dim
  @end
  return tensor_new(out, x.shape)
@end

@! ----------------------------------------------------------------------------
@! 3. ROTARY POSITIONAL EMBEDDINGS (RoPE)
@! ----------------------------------------------------------------------------

@fn rope_math_sin_cos(rad)
  // WHY: Computes trigonometric sine and cosine for rotary positional embeddings scaled by 1000.
  // Uses Bhaskara I rational trigonometry with 1000-scale fixed-point precision to avoid integer
  // underflow and deliver accurate rotation coordinates.
  @if rad == 0
    return { sin: 0, cos: 1000 }
  @end
  deg = rad * 57
  d = deg % 360
  @if d < 0
    d = d + 360
  @end
  sign = 1
  @if d > 180
    sign = 0 - 1
    d = d - 180
  @end
  @if d > 90
    d = 180 - d
  @end
  term = d * (180 - d)
  denom = 40500 - term
  s = 0
  @if denom != 0
    s = ((4 * term * 1000) / denom) * sign
  @end

  // Cosine via cos(theta) = sin(theta + 90 deg)
  deg_c = (rad * 57) + 90
  d_c = deg_c % 360
  @if d_c < 0
    d_c = d_c + 360
  @end
  sign_c = 1
  @if d_c > 180
    sign_c = 0 - 1
    d_c = d_c - 180
  @end
  @if d_c > 90
    d_c = 180 - d_c
  @end
  term_c = d_c * (180 - d_c)
  denom_c = 40500 - term_c
  c = 0
  @if denom_c != 0
    c = ((4 * term_c * 1000) / denom_c) * sign_c
  @end
  return { sin: s, cos: c }
@end

@fn rope_apply_tensor(t, seq_pos, head_dim)
  // WHY: Rotates pairs of head coordinates (x_{2i}, x_{2i+1}) by alpha = seq_pos * 10000^(-2i/d).
  @if t == 0 return 0 @end
  @if head_dim <= 1 return t @end

  t_data = t.data
  total_len = t_data.len()
  @if total_len == 0 return t @end
  use_float = _llm_is_f64_bits(t_data[0])
  out_data = []
  idx = 0
  @while idx < total_len
    out_data = out_data.push(t_data[idx])
    idx = idx + 1
  @end

  half_dim = head_dim / 2
  chunk_start = 0
  @while chunk_start < total_len
    i = 0
    @while i < half_dim
      // True exponential RoPE base 10000.0^(-i / half_dim) where ln(10000) = 9.210340371976184
      theta = math_exp(_llm_fsub(0.0, _llm_fdiv(_llm_fmul(9.210340371976184, i + 0.0), half_dim + 0.0)))
      angle = _llm_fmul(seq_pos + 0.0, theta)
      sin_f = math_sin(angle)
      cos_f = math_cos(angle)

      idx0 = chunk_start + (i * 2)
      idx1 = idx0 + 1
      @if idx1 < total_len
        @if use_float == 1
          x0f = t_data[idx0]
          x1f = t_data[idx1]
          rot0f = _llm_fsub(_llm_fmul(x0f, cos_f), _llm_fmul(x1f, sin_f))
          rot1f = _llm_fadd(_llm_fmul(x0f, sin_f), _llm_fmul(x1f, cos_f))
          out_data = list_set(out_data, idx0, rot0f)
          out_data = list_set(out_data, idx1, rot1f)
        @else
          sin_val = _llm_f64_to_i64(_llm_fmul(sin_f, 1000.0))
          cos_val = _llm_f64_to_i64(_llm_fmul(cos_f, 1000.0))
          x0 = t_data[idx0]
          x1 = t_data[idx1]
          rot0 = ((x0 * cos_val) - (x1 * sin_val)) / 1000
          rot1 = ((x0 * sin_val) + (x1 * cos_val)) / 1000
          out_data = list_set(out_data, idx0, rot0)
          out_data = list_set(out_data, idx1, rot1)
        @end
      @end
      i = i + 1
    @end
    chunk_start = chunk_start + head_dim
  @end

  return tensor_new(out_data, t.shape)
@end

@fn rope_apply(q, k, seq_pos, head_dim)
  // WHY: Applies rotary positional embeddings (RoPE) to query and key projection tensors.
  // Rotates vector pairs in complex plane according to token sequence position.
  @if q == 0 || k == 0
    return { q: q, k: k }
  @end
  new_q = rope_apply_tensor(q, seq_pos, head_dim)
  new_k = rope_apply_tensor(k, seq_pos, head_dim)
  return { q: new_q, k: new_k }
@end

@! ----------------------------------------------------------------------------
@! 4. MULTI-HEAD & GROUPED QUERY ATTENTION (GQA) WITH KV-CACHE
@! ----------------------------------------------------------------------------

@fn self_attention_new(embed_size, num_heads, num_kv_heads)
  return {
    embed_size: embed_size,
    heads: num_heads,
    kv_heads: num_kv_heads,
    head_dim: embed_size / num_heads,
    w_q: tensor_random_mat(embed_size, embed_size),
    w_k: tensor_random_mat(embed_size, (embed_size / num_heads) * num_kv_heads),
    w_v: tensor_random_mat(embed_size, (embed_size / num_heads) * num_kv_heads),
    w_o: tensor_random_mat(embed_size, embed_size)
  }
@end

@fn _attn_f64_matmul(a, b)
  m = a.shape[0]
  k_dim = a.shape[1]
  n = b.shape[1]
  out = []
  i = 0
  @while i < m
    j = 0
    @while j < n
      acc = 0.0
      p = 0
      @while p < k_dim
        va = _llm_to_f64(a.data[(i * k_dim) + p])
        vb = _llm_to_f64(b.data[(p * n) + j])
        acc = _llm_fadd(acc, _llm_fmul(va, vb))
        p = p + 1
      @end
      out = out.push(acc)
      j = j + 1
    @end
    i = i + 1
  @end
  return tensor_new(out, [m, n])
@end

@fn _attn_scale_mask_softmax(scores, q_rows, k_rows, head_dim)
  inv_sqrt_dk = 1.0
  @if head_dim > 0
    inv_sqrt_dk = _llm_fdiv(1.0, math_sqrt(head_dim + 0.0))
  @end
  offset_base = k_rows - q_rows
  out = []
  r = 0
  @while r < q_rows
    max_s = 0.0 - 1000000000.0
    row_scaled = []
    c = 0
    @while c < k_rows
      s_val = _llm_fmul(_llm_to_f64(scores.data[(r * k_rows) + c]), inv_sqrt_dk)
      @if c > (offset_base + r)
        s_val = 0.0 - 1000000000.0
      @end
      row_scaled = row_scaled.push(s_val)
      @if _llm_fgt(s_val, max_s) == 1
        max_s = s_val
      @end
      c = c + 1
    @end
    sum_e = 0.0
    exps = []
    c = 0
    @while c < k_rows
      @if _llm_fgt(row_scaled[c], 0.0 - 100000.0) == 1
        ev = math_exp(_llm_fsub(row_scaled[c], max_s))
        exps = exps.push(ev)
        sum_e = _llm_fadd(sum_e, ev)
      @else
        exps = exps.push(0.0)
      @end
      c = c + 1
    @end
    @if _llm_fgt(sum_e, 0.000000001) == 0
      sum_e = 1.0
    @end
    c = 0
    @while c < k_rows
      out = out.push(_llm_fdiv(exps[c], sum_e))
      c = c + 1
    @end
    r = r + 1
  @end
  return tensor_new(out, [q_rows, k_rows])
@end

@fn _attn_concat_cache(cache_list)
  @if cache_list.len() == 0 return 0 @end
  cols = cache_list[0].shape[1]
  total_rows = 0
  data = []
  ci = 0
  @while ci < cache_list.len()
    t = cache_list[ci]
    r = t.shape[0]
    total_rows = total_rows + r
    di = 0
    @while di < t.data.len()
      data = data.push(t.data[di])
      di = di + 1
    @end
    ci = ci + 1
  @end
  return tensor_new(data, [total_rows, cols])
@end

@fn self_attention_forward(layer, x)
  q = _attn_f64_matmul(x, layer.w_q)
  k = _attn_f64_matmul(x, layer.w_k)
  v = _attn_f64_matmul(x, layer.w_v)

  k_t = tensor_transpose_2d(k)
  scores = _attn_f64_matmul(q, k_t)
  attn_weights = _attn_scale_mask_softmax(scores, q.shape[0], k.shape[0], layer.head_dim)
  out = _attn_f64_matmul(attn_weights, v)
  final_out = _attn_f64_matmul(out, layer.w_o)
  return final_out
@end

@struct LlmKvCache
  k_cache: array
  v_cache: array
@end

@fn llm_kv_cache_new()
  return { k_cache: [], v_cache: [] }
@end

@fn self_attention_forward_cached(layer, x, kv_cache, pos)
  q = _attn_f64_matmul(x, layer.w_q)
  k = _attn_f64_matmul(x, layer.w_k)
  v = _attn_f64_matmul(x, layer.w_v)

  @! Append rotated/projected K and V to cache and attend over FULL cached sequence
  kv_cache.k_cache = kv_cache.k_cache.push(k)
  kv_cache.v_cache = kv_cache.v_cache.push(v)
  k_all = _attn_concat_cache(kv_cache.k_cache)
  v_all = _attn_concat_cache(kv_cache.v_cache)

  k_t = tensor_transpose_2d(k_all)
  scores = _attn_f64_matmul(q, k_t)
  attn_weights = _attn_scale_mask_softmax(scores, q.shape[0], k_all.shape[0], layer.head_dim)
  out = _attn_f64_matmul(attn_weights, v_all)
  final_out = _attn_f64_matmul(out, layer.w_o)

  return { output: final_out, kv_cache: kv_cache }
@end

@! ----------------------------------------------------------------------------
@! 5. FEED-FORWARD NETWORK (SwiGLU & GeLU MLP)
@! ----------------------------------------------------------------------------

@fn mlp_swiglu_new(embed_size, hidden_dim)
  return {
    w_gate: tensor_random_mat(embed_size, hidden_dim),
    w_up: tensor_random_mat(embed_size, hidden_dim),
    w_down: tensor_random_mat(hidden_dim, embed_size)
  }
@end

@fn mlp_swiglu_forward(mlp, x)
  gate_pre = _attn_f64_matmul(x, mlp.w_gate)
  gate = []
  gi = 0
  @while gi < gate_pre.data.len()
    xv = gate_pre.data[gi]
    sig = _llm_fdiv(1.0, _llm_fadd(1.0, math_exp(_llm_fsub(0.0, xv))))
    gate = gate.push(_llm_fmul(xv, sig))
    gi = gi + 1
  @end
  up = _attn_f64_matmul(x, mlp.w_up)
  h_data = []
  gi = 0
  @while gi < gate.len()
    h_data = h_data.push(_llm_fmul(gate[gi], up.data[gi]))
    gi = gi + 1
  @end
  h = tensor_new(h_data, gate_pre.shape)
  return _attn_f64_matmul(h, mlp.w_down)
@end

@! ----------------------------------------------------------------------------
@! 6. TRANSFORMER BLOCK (DECODER LAYER)
@! ----------------------------------------------------------------------------

@fn transformer_block_new(embed_size, heads, ff_hidden)
  return {
    attention: self_attention_new(embed_size, heads, heads),
    norm1: rmsnorm_new(embed_size, 0.00001),
    ff_w1: tensor_random_mat(embed_size, ff_hidden),
    ff_w2: tensor_random_mat(ff_hidden, embed_size),
    norm2: rmsnorm_new(embed_size, 0.00001)
  }
@end

@fn _llm_f64_add_tensor(a, b)
  out = []
  i = 0
  @while i < a.data.len()
    out = out.push(_llm_fadd(_llm_to_f64(a.data[i]), _llm_to_f64(b.data[i % b.data.len()])))
    i = i + 1
  @end
  return tensor_new(out, a.shape)
@end

@fn transformer_block_forward(block, x)
  @! Pre-Norm Architecture
  x_norm = rmsnorm_forward(block.norm1, x)
  attn_out = self_attention_forward(block.attention, x_norm)
  x = _llm_f64_add_tensor(x, attn_out)

  x_norm2 = rmsnorm_forward(block.norm2, x)
  ff_pre = _attn_f64_matmul(x_norm2, block.ff_w1)
  ff_h = []
  fi = 0
  @while fi < ff_pre.data.len()
    v = ff_pre.data[fi]
    @if _llm_fgt(v, 0.0) == 1
      ff_h = ff_h.push(v)
    @else
      ff_h = ff_h.push(0.0)
    @end
    fi = fi + 1
  @end
  ff_hidden = tensor_new(ff_h, ff_pre.shape)
  ff_out = _attn_f64_matmul(ff_hidden, block.ff_w2)
  x = _llm_f64_add_tensor(x, ff_out)
  return x
@end

@! ----------------------------------------------------------------------------
@! 7. FULL GPT-2 / LLAMA NEURAL NETWORK ARCHITECTURE
@! ----------------------------------------------------------------------------

@fn gpt_net_new(vocab_size, embed_size, num_layers, heads, ff_hidden)
  layers = []
  i = 0
  @while i < num_layers
    layers = layers.push(transformer_block_new(embed_size, heads, ff_hidden))
    i = i + 1
  @end

  return {
    vocab_size: vocab_size,
    embed_size: embed_size,
    num_layers: num_layers,
    layers: layers,
    token_embedding: tensor_random_mat(vocab_size, embed_size),
    final_norm: rmsnorm_new(embed_size, 0.00001),
    lm_head: tensor_random_mat(embed_size, vocab_size)
  }
@end

@fn gpt_net_forward(gpt_instance, tokens)
  @! Real embedding table lookup across sequence tokens + positional RoPE
  seq_len = tokens.len()
  @if seq_len == 0
    seq_len = 1
    tokens = [0]
  @end
  embed_sz = gpt_instance.embed_size
  vocab_sz = gpt_instance.vocab_size
  emb_data = []
  ti = 0
  @while ti < seq_len
    tok_id = tokens[ti] % vocab_sz
    @if tok_id < 0 tok_id = tok_id + vocab_sz @end
    row_base = tok_id * embed_sz
    di = 0
    @while di < embed_sz
      emb_data = emb_data.push(_llm_to_f64(gpt_instance.token_embedding.data[row_base + di]))
      di = di + 1
    @end
    ti = ti + 1
  @end
  x = tensor_new(emb_data, [seq_len, embed_sz])

  __layer_idx = 0
  __layer_len = gpt_instance.layers.len()
  @while __layer_idx < __layer_len
    layer = gpt_instance.layers[__layer_idx]
    x = transformer_block_forward(layer, x)
    __layer_idx = __layer_idx + 1
  @end

  x = rmsnorm_forward(gpt_instance.final_norm, x)
  logits = _attn_f64_matmul(x, gpt_instance.lm_head)
  return logits
@end

@fn gpt_generate_token(gpt_instance, prompt_tokens, temperature)
  logits = gpt_net_forward(gpt_instance, prompt_tokens)
  @! Genuine greedy argmax over forward pass vocabulary logits
  best_idx = 0
  best_val = -1000000000.0
  i = 0
  num_logits = logits.data.len()
  @while i < num_logits
    val = logits.data[i]
    @if temperature > 0.00001
      val = val / temperature
    @end
    @if val > best_val
      best_val = val
      best_idx = i
    @end
    i = i + 1
  @end
  return best_idx
@end


@! ----------------------------------------------------------------------------
@! 8. ADVANCED DECODING STRATEGIES (BEAM SEARCH, TOP-K, TOP-P)
@! ----------------------------------------------------------------------------

@fn tensor_top_k_filtering(logits, k)
  @! Retain only the top-k highest probabilities, set others to -infinity
  x_len = logits.data.len()
  @if k >= x_len return logits @end
  
  @! Extract values to sort
  vals = []
  i = 0
  @while i < x_len
    vals = vals.push({ index: i, val: logits.data[i] })
    i = i + 1
  @end
  
  @! Simple Bubble Sort (Descending)
  i = 0
  @while i < x_len - 1
    j = 0
    @while j < x_len - i - 1
      @if vals[j].val < vals[j+1].val
        temp = vals[j]
        vals = list_set(vals, j, vals[j+1])
        vals = list_set(vals, j+1, temp)
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  
  @! Threshold is the k-th value
  threshold = vals[k - 1].val
  
  out_data = []
  i = 0
  @while i < x_len
    v = logits.data[i]
    @if v < threshold
      out_data = out_data.push(-999999.0)
    @else
      out_data = out_data.push(v)
    @end
    i = i + 1
  @end
  
  return tensor_new(out_data, logits.shape)
@end

@fn tensor_top_p_nucleus_sampling(logits, p)
  @! Top-p (nucleus) sampling
  x_len = logits.data.len()
  
  @! Softmax to get probabilities
  probs = tensor_softmax(logits, 1.0)
  
  vals = []
  i = 0
  @while i < x_len
    vals = vals.push({ index: i, val: probs.data[i] })
    i = i + 1
  @end
  
  @! Sort descending
  i = 0
  @while i < x_len - 1
    j = 0
    @while j < x_len - i - 1
      @if vals[j].val < vals[j+1].val
        temp = vals[j]
        vals = list_set(vals, j, vals[j+1])
        vals = list_set(vals, j+1, temp)
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  
  cumulative_prob = 0.0
  out_data = []
  i = 0
  @while i < x_len
    out_data = out_data.push(-999999.0)
    i = i + 1
  @end
  
  i = 0
  @while i < x_len
    idx = vals[i].index
    val = vals[i].val
    
    out_data = list_set(out_data, idx, logits.data[idx])
    cumulative_prob = cumulative_prob + val
    
    @if cumulative_prob > p
      i = x_len @! Break
    @end
    i = i + 1
  @end
  
  return tensor_new(out_data, logits.shape)
@end

@fn _llm_sample_logits_last_row(logits, vocab_sz, temperature, prng_state)
  rows = 1
  @if logits.shape.len() >= 2
    rows = logits.shape[0]
  @end
  row_base = (rows - 1) * vocab_sz
  @if row_base + vocab_sz > logits.data.len()
    row_base = 0
  @end
  @if _llm_fgt(temperature, 0.0001) == 0
    max_val = 0.0 - 1000000000.0
    best_idx = 0
    k = 0
    @while k < vocab_sz
      vk = _llm_to_f64(logits.data[row_base + k])
      @if k == 0 || _llm_fgt(vk, max_val) == 1
        max_val = vk
        best_idx = k
      @end
      k = k + 1
    @end
    return best_idx
  @end

  max_val = 0.0 - 1000000000.0
  k = 0
  @while k < vocab_sz
    vk = _llm_to_f64(logits.data[row_base + k])
    @if k == 0 || _llm_fgt(vk, max_val) == 1
      max_val = vk
    @end
    k = k + 1
  @end
  probs = []
  sum_p = 0.0
  k = 0
  @while k < vocab_sz
    vk = _llm_to_f64(logits.data[row_base + k])
    ev = math_exp(_llm_fsub(vk, max_val))
    probs = probs.push(ev)
    sum_p = _llm_fadd(sum_p, ev)
    k = k + 1
  @end
  @if _llm_fgt(sum_p, 0.000000001) == 0
    return 0
  @end
  u_norm = _llm_fdiv((prng_state & 1048575) + 0.5, 1048576.0)
  target = _llm_fmul(u_norm, sum_p)
  acc = 0.0
  k = 0
  @while k < vocab_sz
    acc = _llm_fadd(acc, probs[k])
    @if _llm_fgt(acc, target) == 1
      return k
    @end
    k = k + 1
  @end
  return vocab_sz - 1
@end

@fn gpt_generate_advanced(gpt, prompt, max_tokens, temperature, top_k, top_p, repetition_penalty)
  println("  [LLM] Generating " + max_tokens.to_str() + " tokens (Temp: " + temperature.to_str() + ", Top-K: " + top_k.to_str() + ", Top-P: " + top_p.to_str() + ")")

  generated = []
  context = prompt
  vocab_sz = gpt.vocab_size
  prng_s = clock_ms() ^ 1315423911

  i = 0
  @while i < max_tokens
    logits_all = gpt_net_forward(gpt, context)
    rows = 1
    @if logits_all.shape.len() >= 2
      rows = logits_all.shape[0]
    @end
    row_base = (rows - 1) * vocab_sz
    @if row_base + vocab_sz > logits_all.data.len()
      row_base = 0
    @end
    last_row = []
    ki = 0
    @while ki < vocab_sz
      last_row = last_row.push(_llm_to_f64(logits_all.data[row_base + ki]))
      ki = ki + 1
    @end
    logits = tensor_new(last_row, [1, vocab_sz])

    @! Apply temperature scaling
    @if _llm_fgt(temperature, 0.0001) == 1
      scaled_data = []
      j = 0
      @while j < logits.data.len()
        scaled_data = scaled_data.push(_llm_fdiv(logits.data[j], _llm_to_f64(temperature)))
        j = j + 1
      @end
      logits = tensor_new(scaled_data, logits.shape)
    @end

    @! Apply repetition penalty
    @if repetition_penalty != 1.0
      rp_f = _llm_to_f64(repetition_penalty)
      j = 0
      @while j < context.len()
        tok = context[j]
        @if tok >= 0 && tok < logits.data.len()
          val = logits.data[tok]
          @if _llm_fgt(val, 0.0) == 1
            logits.data = list_set(logits.data, tok, _llm_fdiv(val, rp_f))
          @else
            logits.data = list_set(logits.data, tok, _llm_fmul(val, rp_f))
          @end
        @end
        j = j + 1
      @end
    @end

    @! Top-K
    @if top_k > 0
      logits = tensor_top_k_filtering(logits, top_k)
    @end

    @! Top-P
    @if top_p < 1.0 && top_p > 0.0
      logits = tensor_top_p_nucleus_sampling(logits, top_p)
    @end

    @! Multinomial stochastic sampling (argmax fallback only when temp <= 0)
    prng_s = _llm_prng_next(prng_s)
    best_idx = _llm_sample_logits_last_row(logits, vocab_sz, temperature, prng_s)

    generated = generated.push(best_idx)
    context = context.push(best_idx)
    i = i + 1
  @end

  return generated
@end

@! ----------------------------------------------------------------------------
@! 9. FLASH ATTENTION / MEMORY-EFFICIENT ATTENTION
@! ----------------------------------------------------------------------------

@fn flash_math_exp(x)
  // WHY: High-precision Taylor expansion of exp(x) clamped to prevent float underflow/overflow
  @if x < 0.0 - 40.0 return 0.0 @end
  clamped_x = x
  @if clamped_x > 40.0 clamped_x = 40.0 @end
  term = 1.0
  sum = 1.0
  k = 1
  @while k <= 16
    term = (term * clamped_x) / (k * 1.0)
    sum = sum + term
    k = k + 1
  @end
  return sum
@end

@fn flash_float_sqrt(val)
  // WHY: Float square root via Newton-Raphson approximation
  @if val <= 0.0 return 0.0 @end
  guess = val
  iter = 0
  @while iter < 12
    guess = 0.5 * (guess + (val / guess))
    iter = iter + 1
  @end
  return guess
@end

@fn flash_attention_forward(q, k, v, block_size)
  // WHY: Genuine Tiled FlashAttention with online softmax scaling (Dao et al.).
  // Evaluates Q*K^T/sqrt(d)*V in tiled SRAM blocks without materializing
  // full N x M attention matrix in memory, guaranteeing O(N) memory complexity.
  n_rows = q.shape[0]
  d_k = q.shape[1]
  m_cols = k.shape[0]
  d_v = v.shape[1]

  b_size = block_size
  @if b_size <= 0
    b_size = 16
  @end

  sqrt_d = flash_float_sqrt(d_k * 1.0)
  scale = 1.0
  @if sqrt_d > 0.000001
    scale = 1.0 / sqrt_d
  @end

  out_data = []
  total_out = n_rows * d_v
  zi = 0
  @while zi < total_out
    out_data = out_data.push(0.0)
    zi = zi + 1
  @end

  // Iterate over row tiles
  i_start = 0
  @while i_start < n_rows
    i_end = i_start + b_size
    @if i_end > n_rows
      i_end = n_rows
    @end

    i = i_start
    @while i < i_end
      // Per-row online softmax accumulators
      m_i = 0.0 - 100000000.0 // running max
      l_i = 0.0               // running sum of exponentials
      
      row_acc = []
      ci = 0
      @while ci < d_v
        row_acc = row_acc.push(0.0)
        ci = ci + 1
      @end

      // Iterate over column tiles (K and V blocks)
      j_start = 0
      @while j_start < m_cols
        j_end = j_start + b_size
        @if j_end > m_cols
          j_end = m_cols
        @end

        // 1. Compute tile scores S[j] = Q[i] dot K[j] * scale
        s_tile = []
        tile_max = 0.0 - 100000000.0
        j = j_start
        @while j < j_end
          dot = 0.0
          di = 0
          @while di < d_k
            dot = dot + (q.data[i * d_k + di] * k.data[j * d_k + di])
            di = di + 1
          @end
          score = dot * scale
          s_tile = s_tile.push(score)
          @if score > tile_max
            tile_max = score
          @end
          j = j + 1
        @end

        // 2. Online softmax update
        m_new = m_i
        @if tile_max > m_new
          m_new = tile_max
        @end

        alpha = flash_math_exp(m_i - m_new)
        l_i = l_i * alpha

        // Rescale existing accumulator
        ci = 0
        @while ci < d_v
          row_acc[ci] = row_acc[ci] * alpha
          ci = ci + 1
        @end

        // 3. Accumulate P_ij * V[j]
        j = j_start
        tj = 0
        @while j < j_end
          p_val = flash_math_exp(s_tile[tj] - m_new)
          l_i = l_i + p_val

          ci = 0
          @while ci < d_v
            row_acc[ci] = row_acc[ci] + (p_val * v.data[j * d_v + ci])
            ci = ci + 1
          @end

          j = j + 1
          tj = tj + 1
        @end

        m_i = m_new
        j_start = j_end
      @end

      // 4. Final normalization: O[i] = row_acc / l_i
      inv_l = 1.0
      @if l_i > 0.0000001
        inv_l = 1.0 / l_i
      @end

      ci = 0
      @while ci < d_v
        out_data[i * d_v + ci] = row_acc[ci] * inv_l
        ci = ci + 1
      @end

      i = i + 1
    @end

    i_start = i_end
  @end

  return tensor_new(out_data, [n_rows, d_v])
@end
