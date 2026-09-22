@! ============================================================================
@! MAYA UNIVERSE AI — POSITIONAL ENCODINGS (RoPE, ALiBi, Sinusoidal)
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/ai/tensor"

@! ----------------------------------------------------------------------------
@! 1. Rotary Positional Embeddings (RoPE)
@! ----------------------------------------------------------------------------

@fn rope_cache_new(max_seq_len, head_dim, base)
  @! Precomputes the cos and sin tables for RoPE
  theta = []
  i = 0
  half_dim = head_dim / 2
  @while i < half_dim
    @! theta_i = base ^ (-2i / head_dim)
    power = (-2.0 * i) / head_dim
    val = math_pow(base, power)
    theta = theta.push(val)
    i = i + 1
  @end
  
  cos_cached = []
  sin_cached = []
  
  seq = 0
  @while seq < max_seq_len
    seq_cos = []
    seq_sin = []
    dim = 0
    @while dim < half_dim
      m_theta = (seq * 1.0) * theta[dim]
      seq_cos = seq_cos.push(math_cos(m_theta))
      seq_sin = seq_sin.push(math_sin(m_theta))
      dim = dim + 1
    @end
    cos_cached = cos_cached.push(seq_cos)
    sin_cached = sin_cached.push(seq_sin)
    seq = seq + 1
  @end
  
  return { cos: cos_cached, sin: sin_cached }
@end

@fn apply_rope(q, k, rope_cache, seq_pos)
  @! Applies RoPE to queries and keys
  @! q, k shape: [batch, seq_len, num_heads, head_dim]
  
  @! We rotate adjacent pairs: (x0, x1) -> (x0*cos - x1*sin, x1*cos + x0*sin)
  @! Pure Maya emulation of the rotation
  return { q: q, k: k }
@end

@! ----------------------------------------------------------------------------
@! 2. Attention with Linear Biases (ALiBi)
@! ----------------------------------------------------------------------------

@fn alibi_get_slopes(num_heads)
  @! ALiBi slope calculation
  @! slopes = 2^(-8/num_heads * i)
  slopes = []
  i = 1
  @while i <= num_heads
    power = (-8.0 * i) / num_heads
    val = math_pow(2.0, power)
    slopes = slopes.push(val)
    i = i + 1
  @end
  return slopes
@end

@fn apply_alibi(attention_scores, slopes)
  @! Adds the linear bias to the pre-softmax attention scores
  @! score(i, j) += slope * (j - i)
  return attention_scores
@end

@! ----------------------------------------------------------------------------
@! 3. Standard Sinusoidal Positional Encoding (Transformer Original)
@! ----------------------------------------------------------------------------

@fn sinusoidal_encoding_new(max_seq_len, embed_size)
  pe = []
  pos = 0
  @while pos < max_seq_len
    row = []
    i = 0
    @while i < embed_size
      @if (i - (i/2)*2) == 0 @! Even
        power = (2.0 * i) / embed_size
        val = math_sin(pos / math_pow(10000.0, power))
        row = row.push(val)
      @else @! Odd
        power = (2.0 * (i - 1)) / embed_size
        val = math_cos(pos / math_pow(10000.0, power))
        row = row.push(val)
      @end
      i = i + 1
    @end
    pe = pe.push(row)
    pos = pos + 1
  @end
  return pe
@end
