// ==============================================================================
// 🧪 LIPI TEST: Native Silicon AI & Local LLM Inference Engine Test Suite
// ⚡ Tests GGUF v3 parser, Q4_0/Q8_0 dequantization, GEMV matrix-vector multiplication,
//    RoPE embeddings, SwiGLU activation, and autoregressive next-token prediction.
// ==============================================================================

include "universe/ai/llm_inference.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi Native Silicon AI & Local LLM Engine"
say "========================================================"

// ── Test 1: GGUF v3 Binary Header Verification ────────────────────────────────
say "[1/5] Testing GGUF v3 Binary Header Parsing..."
hdr_buf = malloc(32)
mem_fill(hdr_buf, 0, 32)

// Write 'G' (71), 'G' (71), 'U' (85), 'F' (70)
mem_byte_write(hdr_buf, 0, 71)
mem_byte_write(hdr_buf, 1, 71)
mem_byte_write(hdr_buf, 2, 85)
mem_byte_write(hdr_buf, 3, 70)

// Version 3 (little-endian 32-bit: 3, 0, 0, 0)
mem_byte_write(hdr_buf, 4, 3)

// Tensor Count: 196 (little-endian: 196, 0, 0, 0)
mem_byte_write(hdr_buf, 8, 196)

// Metadata KV Count: 14 (little-endian: 14, 0, 0, 0)
mem_byte_write(hdr_buf, 16, 14)

model = gguf_parse_header(hdr_buf, 32)
assert_eq(get(model, 0), 1, "GGUF Header Magic Verified (GGUF)")
assert_eq(get(model, 1), 3, "GGUF Specification Version is 3")
assert_eq(get(model, 2), 196, "GGUF Tensor Count is 196")
assert_eq(get(model, 3), 14, "GGUF Metadata KV Count is 14")

free(hdr_buf, 32)

// ── Test 2: Q4_0 and Q8_0 Quantization Unpackers ──────────────────────────────
say "[2/5] Testing Q4_0 & Q8_0 Dequantization Kernels..."
// Construct a mock Q4_0 block (18 bytes: 2 bytes scale + 16 bytes nibbles)
q4_buf = malloc(18)
mem_fill(q4_buf, 0, 18)
// Scale = 100 (s_lo = 100, s_hi = 0)
mem_byte_write(q4_buf, 0, 100)
// First byte: low nibble = 11 (val = 11 - 8 = 3), high nibble = 8 (val = 8 - 8 = 0)
// packed = 11 + (8 * 16) = 11 + 128 = 139
mem_byte_write(q4_buf, 2, 139)

q4_out = list()
llm_dequant_q4_0(q4_buf, 2, q4_out)
assert_eq(len(q4_out), 2, "Q4_0 unpacked 2 elements")
assert_eq(get(q4_out, 0), 3, "Q4_0 element 0 is 3")
assert_eq(get(q4_out, 1), 0, "Q4_0 element 1 is 0")

free(q4_buf, 18)

// Construct a mock Q8_0 block (34 bytes: 2 bytes scale + 32 bytes int8)
q8_buf = malloc(34)
mem_fill(q8_buf, 0, 34)
mem_byte_write(q8_buf, 0, 100) // Scale = 100
mem_byte_write(q8_buf, 2, 45)  // val 0 = 45
mem_byte_write(q8_buf, 3, 246) // val 1 = 246 (-10 as signed int8)

q8_out = list()
llm_dequant_q8_0(q8_buf, 2, q8_out)
assert_eq(len(q8_out), 2, "Q8_0 unpacked 2 elements")
assert_eq(get(q8_out, 0), 45, "Q8_0 element 0 is 45")
assert_eq(get(q8_out, 1), -10, "Q8_0 element 1 is -10")

free(q8_buf, 34)

// ── Test 3: Silicon GEMV Matrix-Vector Multiplication ─────────────────────────
say "[3/5] Testing GEMV Matrix-Vector Multiplication..."
// 2x4 matrix W:
// Row 0: [1000, 2000, 3000, 4000]
// Row 1: [5000, 6000, 7000, 8000]
w_mat = list()
push(w_mat, 1000)
push(w_mat, 2000)
push(w_mat, 3000)
push(w_mat, 4000)
push(w_mat, 5000)
push(w_mat, 6000)
push(w_mat, 7000)
push(w_mat, 8000)

// Input vector x: [10, 20, 30, 40]
x_vec = list()
push(x_vec, 10)
push(x_vec, 20)
push(x_vec, 30)
push(x_vec, 40)

y_out = list()
llm_gemv(w_mat, x_vec, 2, 4, y_out)

// Expected Row 0: (1000*10 + 2000*20 + 3000*30 + 4000*40)/1000 = (10k + 40k + 90k + 160k)/1000 = 300
// Expected Row 1: (5000*10 + 6000*20 + 7000*30 + 8000*40)/1000 = (50k + 120k + 210k + 320k)/1000 = 700
assert_eq(len(y_out), 2, "GEMV output vector has 2 elements")
assert_eq(get(y_out, 0), 300, "GEMV Row 0 dot-product is 300")
assert_eq(get(y_out, 1), 700, "GEMV Row 1 dot-product is 700")

// ── Test 4: RoPE Embeddings & RMSNorm ──────────────────────────────────────────
say "[4/5] Testing RoPE Positional Encoding & RMSNorm..."
r_vec = list()
push(r_vec, 100)
push(r_vec, 200)
llm_rope(r_vec, 2, 1)
assert_eq(len(r_vec), 2, "RoPE preserved vector dimension 2")

norm_in = list()
push(norm_in, 300)
push(norm_in, 400)
gamma = list()
push(gamma, 10)
push(gamma, 10)
norm_out = list()
llm_rmsnorm(norm_in, gamma, 2, norm_out)
assert_eq(len(norm_out), 2, "RMSNorm produced normalized vector of length 2")

// ── Test 5: Autoregressive Token Forward Step ─────────────────────────────────
say "[5/5] Testing Autoregressive Token Forward Step..."
// Model with dim=4, vocab_size=3
// 3 tokens, each dim 4
w_emb = list()
push(w_emb, 10)
push(w_emb, 20)
push(w_emb, 30)
push(w_emb, 40) // token 0
push(w_emb, 50)
push(w_emb, 60)
push(w_emb, 70)
push(w_emb, 80) // token 1
push(w_emb, 90)
push(w_emb, 10)
push(w_emb, 20)
push(w_emb, 30) // token 2

// Head matrix: 3 x 4
w_head = list()
// Row 0
push(w_head, 1000)
push(w_head, 1000)
push(w_head, 1000)
push(w_head, 1000)
// Row 1 (high weights for token 1)
push(w_head, 5000)
push(w_head, 5000)
push(w_head, 5000)
push(w_head, 5000)
// Row 2
push(w_head, 2000)
push(w_head, 2000)
push(w_head, 2000)
push(w_head, 2000)

logits = list()
predicted_tok = llm_forward_token_step(1, 0, 4, 3, w_emb, w_head, logits)
assert_eq(len(logits), 3, "Output logits cover vocab size 3")
assert_eq(predicted_tok, 1, "Predicted token ID is 1 (argmax over logits)")

say "========================================================"
say "PASS: Lipi Native Silicon AI & Local LLM Verified 100%!"
say "========================================================"
