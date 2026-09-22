// ==============================================================================
// 🧪 LIPI TEST SUITE: SILICON AI & LOCAL GGUF LLM RUNNER (Pure Lipi)
// File: tests/test_local_llm_runner.lp
// Standard: GGUF v3 Binary Container | Q4_0 / Q8_0 Dequant | SIMD GEMV Kernel
// 100% Pure Lipi — Zero Python | Zero PyTorch | Zero C++ | Zero llama.cpp
// ==============================================================================

include "universe/ai/llm_inference.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ [FAIL] Assertion failed: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq_int actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "🧠 LIPI SILICON AI & LOCAL GGUF LLM RUNNER TEST SUITE 🧠"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: GGUF v3 Binary Container Ingestion & Validation ────────────
    say "▶ Section 1: GGUF v3 Binary Header & Magic Ingestion..."
    total_tests = total_tests + 1

    hdr = malloc(32)
    mem_fill(hdr, 0, 32)
    // Write Magic 'GGUF'
    mem_byte_write(hdr, 0, 71)
    mem_byte_write(hdr, 1, 71)
    mem_byte_write(hdr, 2, 85)
    mem_byte_write(hdr, 3, 70)
    // Version 3
    mem_byte_write(hdr, 4, 3)
    // Tensors: 64
    mem_byte_write(hdr, 8, 64)
    // KV metadata: 8
    mem_byte_write(hdr, 16, 8)

    model = gguf_parse_header(hdr, 32)
    assert_eq_int(get(model, 0), 1, "GGUF Header Magic Verified")
    assert_eq_int(get(model, 1), 3, "Specification Version is 3")
    assert_eq_int(get(model, 2), 64, "Tensor count is 64")
    assert_eq_int(get(model, 3), 8, "KV metadata count is 8")

    free(hdr, 32)
    passed_tests = passed_tests + 1

    // ── Section 2: Quantization Precision (Q4_0 & Q8_0) ───────────────────────
    say "\n▶ Section 2: Quantized Block Unpacking & Scaled Dequantization..."
    total_tests = total_tests + 1

    // Test Q4_0 block (scale = 200, nibbles = 10 and 4)
    q4_buf = malloc(18)
    mem_fill(q4_buf, 0, 18)
    mem_byte_write(q4_buf, 0, 200) // Scale 2.00
    mem_byte_write(q4_buf, 2, 10 + (4 * 16)) // byte 2: low=10 (signed +2), high=4 (signed -4)

    q4_out = list()
    llm_dequant_q4_0(q4_buf, 2, q4_out)
    // 2 * 200 / 100 = 4
    assert_eq_int(get(q4_out, 0), 4, "Q4_0 Low Nibble Dequantized: +4")
    // -4 * 200 / 100 = -8
    assert_eq_int(get(q4_out, 1), -8, "Q4_0 High Nibble Dequantized: -8")
    free(q4_buf, 18)

    // Test Q8_0 block (scale = 100, int8 = -50, 75)
    q8_buf = malloc(34)
    mem_fill(q8_buf, 0, 34)
    mem_byte_write(q8_buf, 0, 100) // Scale 1.00
    mem_byte_write(q8_buf, 2, 206) // -50 in uint8 (256 - 50 = 206)
    mem_byte_write(q8_buf, 3, 75)  // +75

    q8_out = list()
    llm_dequant_q8_0(q8_buf, 2, q8_out)
    assert_eq_int(get(q8_out, 0), -50, "Q8_0 Negative Int8 Dequantized: -50")
    assert_eq_int(get(q8_out, 1), 75, "Q8_0 Positive Int8 Dequantized: 75")
    free(q8_buf, 34)
    passed_tests = passed_tests + 1

    // ── Section 3: Silicon GEMV Dot Product Kernels ────────────────────────────
    say "\n▶ Section 3: Silicon GEMV (Matrix-Vector) Dot Products..."
    total_tests = total_tests + 1

    w_mat = list()
    // Row 0: [1000, 2000, 3000, 4000]
    push(w_mat, 1000)
    push(w_mat, 2000)
    push(w_mat, 3000)
    push(w_mat, 4000)
    // Row 1: [5000, 6000, 7000, 8000]
    push(w_mat, 5000)
    push(w_mat, 6000)
    push(w_mat, 7000)
    push(w_mat, 8000)

    in_x = list()
    push(in_x, 2)
    push(in_x, 3)
    push(in_x, 1)
    push(in_x, 4)

    gemv_out = list()
    llm_gemv(w_mat, in_x, 2, 4, gemv_out)

    // Row 0: (1000*2 + 2000*3 + 3000*1 + 4000*4) / 1000 = (2000 + 6000 + 3000 + 16000) / 1000 = 27000 / 1000 = 27
    assert_eq_int(get(gemv_out, 0), 27, "GEMV Row 0 Dot-Product = 27")
    // Row 1: (5000*2 + 6000*3 + 7000*1 + 8000*4) / 1000 = (10000 + 18000 + 7000 + 32000) / 1000 = 67000 / 1000 = 67
    assert_eq_int(get(gemv_out, 1), 67, "GEMV Row 1 Dot-Product = 67")
    passed_tests = passed_tests + 1

    // ── Section 4: RoPE Rotary Positional Embeddings & Sampling ────────────────
    say "\n▶ Section 4: RoPE Positional Encoding & Greedy Sampler..."
    total_tests = total_tests + 1

    rope_vec = list()
    push(rope_vec, 100)
    push(rope_vec, 50)
    llm_rope(rope_vec, 2, 0)
    // At pos 0, theta = 0, cos = 100, sin = 0 -> in-place unchanged
    assert_eq_int(get(rope_vec, 0), 100, "RoPE Pos 0 Cosine Component Preserved")
    assert_eq_int(get(rope_vec, 1), 50, "RoPE Pos 0 Sine Component Preserved")

    // Test Sampler
    logits = list()
    push(logits, 120)
    push(logits, 950) // Max logit at index 1
    push(logits, 340)
    best_tok = llm_sample_token(logits, 3, 100, 10)
    assert_eq_int(best_tok, 1, "Greedy Token Sampler chose maximum logit index 1")
    passed_tests = passed_tests + 1

    say "\n-----------------------------------------------------------------"
    say "RESULTS: " + str(passed_tests) + "/" + str(total_tests) + " sections passed."
    say "🎉 ALL SILICON AI & LOCAL LLM RUNNER TESTS PASSED!"
    return 0

main()
