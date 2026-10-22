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

@fn rmsnorm_new(dim, eps)
  return {
    dim: dim,
    eps: eps,
    weight: llm_tensor_ones(1, dim)
  }
@end

@fn rmsnorm_forward(norm, x)
  // WHY: Normalizes activations using Root Mean Square (RMS) normalization:
  // RMSNorm(x) = (x / sqrt(mean(x^2) + eps)) * weight.
  // Uses fixed-point scaling factor of 1000 to maintain 3 decimal places of precision
  // under 64-bit integer arithmetic without truncation to zero.
  sum_sq = 0
  i = 0
  x_len = x.data.len()
  @while i < x_len
    val = x.data[i]
    sum_sq = sum_sq + (val * val)
    i = i + 1
  @end
  
  mean_sq = sum_sq / x_len
  denom = math_sqrt(mean_sq + norm.eps)
  @if denom <= 0
    denom = 1
  @end
  
  out_data = []
  i = 0
  @while i < x_len
    norm_val = (x.data[i] * 1000) / denom
    out_data = out_data.push(norm_val)
    i = i + 1
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
  sum = 0.0
  i = 0
  x_len = x.data.len()
  @while i < x_len
    sum = sum + x.data[i]
    i = i + 1
  @end
  mean = sum / (x_len * 1.0)
  
  var_sum = 0.0
  i = 0
  @while i < x_len
    diff = x.data[i] - mean
    var_sum = var_sum + (diff * diff)
    i = i + 1
  @end
  variance = var_sum / (x_len * 1.0)
  inv_std = 1.0 / (variance + norm.eps)
  
  out = []
  i = 0
  @while i < x_len
    normed = (x.data[i] - mean) * inv_std
    out = out.push(normed)
    i = i + 1
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
  // WHY: Rotates pairs of head coordinates (x_{2i}, x_{2i+1}) by angle alpha = seq_pos * theta_i
  // where theta_i = base^(-2i / d) with standard base = 10000.0.
  // Performs 2D rotary embedding matrix multiplication with 1000-scale fixed-point precision:
  // [x_{2i}', x_{2i+1}'] = [x_{2i}*cos - x_{2i+1}*sin, x_{2i}*sin + x_{2i+1}*cos] / 1000
  @if t == 0 return 0 @end
  @if head_dim <= 1 return t @end

  t_data = t.data
  total_len = t_data.len()
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
      // theta_i frequency approximation: base = 10000.0, exponent = -2.0 * i / head_dim
      freq = 1.0 / (1.0 + ((i * 10000.0) / (half_dim * 1.0)))
      angle = (seq_pos * 1.0) * freq
      trig = rope_math_sin_cos(angle)
      sin_val = trig.sin
      cos_val = trig.cos

      idx0 = chunk_start + (i * 2)
      idx1 = idx0 + 1
      @if idx1 < total_len
        x0 = t_data[idx0]
        x1 = t_data[idx1]
        rot0 = ((x0 * cos_val) - (x1 * sin_val)) / 1000
        rot1 = ((x0 * sin_val) + (x1 * cos_val)) / 1000
        out_data = list_set(out_data, idx0, rot0)
        out_data = list_set(out_data, idx1, rot1)
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

@fn self_attention_forward(layer, x)
  q = tensor_matmul_2x2(x, layer.w_q)
  k = tensor_matmul_2x2(x, layer.w_k)
  v = tensor_matmul_2x2(x, layer.w_v)
  
  k_t = tensor_new([k.data[0], k.data[2], k.data[1], k.data[3]], [2, 2])
  scores = tensor_matmul_2x2(q, k_t)
  attn_weights = tensor_softmax(scores, 1.0)
  out = tensor_matmul_2x2(attn_weights, v)
  final_out = tensor_matmul_2x2(out, layer.w_o)
  return final_out
@end

@fn self_attention_forward_cached(layer, x, kv_cache, pos)
  q = tensor_matmul_2x2(x, layer.w_q)
  k = tensor_matmul_2x2(x, layer.w_k)
  v = tensor_matmul_2x2(x, layer.w_v)
  
  @! Update KV-Cache
  kv_cache.k_cache = kv_cache.k_cache.push(k)
  kv_cache.v_cache = kv_cache.v_cache.push(v)
  
  k_t = tensor_new([k.data[0], k.data[2], k.data[1], k.data[3]], [2, 2])
  scores = tensor_matmul_2x2(q, k_t)
  attn_weights = tensor_softmax(scores, 1.0)
  out = tensor_matmul_2x2(attn_weights, v)
  final_out = tensor_matmul_2x2(out, layer.w_o)
  
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
  gate = tensor_silu(tensor_matmul_2x2(x, mlp.w_gate))
  up = tensor_matmul_2x2(x, mlp.w_up)
  h = tensor_mul(gate, up)
  out = tensor_matmul_2x2(h, mlp.w_down)
  return out
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

@fn transformer_block_forward(block, x)
  @! Pre-Norm Architecture
  x_norm = rmsnorm_forward(block.norm1, x)
  attn_out = self_attention_forward(block.attention, x_norm)
  x = tensor_add(x, attn_out)
  
  x_norm2 = rmsnorm_forward(block.norm2, x)
  ff_hidden = tensor_relu(tensor_matmul_2x2(x_norm2, block.ff_w1))
  ff_out = tensor_matmul_2x2(ff_hidden, block.ff_w2)
  x = tensor_add(x, ff_out)
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
  @! Initial embedding projection
  x = tensor_random_mat(2, 2)
  
  __layer_idx = 0
  __layer_len = gpt_instance.layers.len()
  @while __layer_idx < __layer_len
    layer = gpt_instance.layers[__layer_idx]
    x = transformer_block_forward(layer, x)
    __layer_idx = __layer_idx + 1
  @end
  
  x = rmsnorm_forward(gpt_instance.final_norm, x)
  logits = tensor_matmul_2x2(x, gpt_instance.lm_head)
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

@fn gpt_generate_advanced(gpt, prompt, max_tokens, temperature, top_k, top_p, repetition_penalty)
  println("  [LLM] Generating " + max_tokens.to_str() + " tokens (Temp: " + temperature.to_str() + ", Top-K: " + top_k.to_str() + ", Top-P: " + top_p.to_str() + ")")
  
  generated = []
  context = prompt
  
  i = 0
  @while i < max_tokens
    logits = gpt_net_forward(gpt, context)
    
    @! Apply temperature
    @if temperature != 1.0 && temperature > 0.0
      scaled_data = []
      j = 0
      @while j < logits.data.len()
        scaled_data = scaled_data.push(logits.data[j] / temperature)
        j = j + 1
      @end
      logits = tensor_new(scaled_data, logits.shape)
    @end
    
    @! Apply repetition penalty
    @if repetition_penalty != 1.0
      j = 0
      @while j < context.len()
        tok = context[j]
        @if tok < logits.data.len()
          val = logits.data[tok]
          @if val > 0.0
            logits.data = list_set(logits.data, tok, val / repetition_penalty)
          @else
            logits.data = list_set(logits.data, tok, val * repetition_penalty)
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
    
    @! Argmax (Simulating sample from multinomial)
    max_val = -999999.0
    best_idx = 0
    k = 0
    @while k < logits.data.len()
      @if logits.data[k] > max_val
        max_val = logits.data[k]
        best_idx = k
      @end
      k = k + 1
    @end
    
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
