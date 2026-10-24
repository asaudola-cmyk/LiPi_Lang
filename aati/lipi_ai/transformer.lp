// ==============================================================================
// 👑 LIPI SOVEREIGN AI: TRANSFORMER ARCHITECTURE & ROPE (aati/lipi_ai/transformer.lp)
// ⚡ 100% Pure Lipi | RoPE, RMSNorm, LayerNorm, SwiGLU, Multi-Head Attention & Decoder
// ==============================================================================
//
// WHY: Canonical package export for transformer neural network architectures.
// Exposes rotary positional embeddings (RoPE), Root Mean Square normalization (RMSNorm),
// Grouped-Query/Multi-Head Attention (GQA/MHA), SwiGLU MLP feed-forward blocks,
// and autoregressive generative decoders for sovereign AI models.
//
// Architecture Layers:
//   1. Normalization: RMSNorm (rmsnorm_new, rmsnorm_forward) & LayerNorm
//   2. Positional Encoding: RoPE (rope_math_sin_cos, rope_apply_tensor, rope_apply)
//   3. Multi-Head / Grouped Query Attention: self_attention_new, self_attention_forward
//   4. Feed-Forward Networks: SwiGLU (mlp_swiglu_new, mlp_swiglu_forward)
//   5. Transformer Blocks: transformer_block_new, transformer_block_forward
//   6. Generative Decoder: gpt_net_new, gpt_net_forward, gpt_generate_token

include "aati/lipi_ai/llm/transformer.lp"
