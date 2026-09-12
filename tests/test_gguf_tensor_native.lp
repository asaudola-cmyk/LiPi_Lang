// ==============================================================================
// 👑 লিপ টেস্ট: খাঁটি জিজিইউএফ ও এআই সিলিকন টেনসর ইঞ্জিন
// 🏛️ Test: Sovereign GGUF v3 Parser & AVX-512 Silicon GEMV Inference Engine
// ==============================================================================
//
// WHY: কোনো পাইথন, পাইটর্চ বা সি++ নির্ভরতা ছাড়া সরাসরি হার্ডওয়্যার সিলিকনে
// জিজিইউএফ ওপেন-সোর্স এলএলএম মডেলের ওজন ডিকোয়ান্টাইজেশন ও এভিএক্স-৫১২
// ম্যাট্রিক্স-ভেক্টর গুণনের নিখুঁত কার্যকারিতা যাচাইকরণ।

include "universe/core/memory.lp"
include "universe/ai/gguf.lp"

fn assert_eq_int actual expected test_name
    if actual == expected
        say "  ✔ " + test_name + " verified: " + to_str(actual)
        return 1
    say "  ❌ FAILED: " + test_name + " expected " + to_str(expected) + " but got " + to_str(actual)
    exit(1)

fn assert_true cond test_name
    if cond == 1
        say "  ✔ " + test_name + " verified (true)"
        return 1
    say "  ❌ FAILED: " + test_name + " expected true but got false"
    exit(1)

fn main
    say "========================================================"
    say "👑 Testing Lipi Sovereign GGUF & AVX-512 AI Inference"
    say "========================================================"

    // ── ১. জিজিইউএফ বাইনারি হেডার যাচাই ──
    say "[1/5] Testing GGUF v3 Binary Header Verification..."
    hdr = sys_alloc(32)
    sys_poke8(hdr, 71)      // 'G'
    sys_poke8(hdr + 1, 71)  // 'G'
    sys_poke8(hdr + 2, 85)  // 'U'
    sys_poke8(hdr + 3, 70)  // 'F'
    sys_poke(hdr + 4, 3)    // Version 3

    magic_ok = gguf_magic_verify(hdr)
    assert_eq_int(magic_ok, 1, "gguf_magic_verify")

    bn_magic_ok = জিজিইউএফ_ম্যাজিক_যাচাই(hdr)
    assert_eq_int(bn_magic_ok, 1, "Bangla Alias: জিজিইউএফ_ম্যাজিক_যাচাই")

    ver = gguf_version(hdr)
    assert_eq_int(ver, 3, "GGUF Specification Version == 3")

    // ── ২. Q4_0 কোয়ান্টাইজড নিবল ডিকোয়ান্টাইজেশন ──
    say "[2/5] Testing Q4_0 Quantized Weight Unpacking..."
    packed_buf = sys_alloc(4)
    unpacked_buf = sys_alloc(32)
    // 0x9B = 155 (high nibble = 9, low nibble = 11)
    // Low: (11 - 8) * 10 = 30
    // High: (9 - 8) * 10 = 10
    sys_poke8(packed_buf, 155)

    out_count = gguf_q4_unpack(packed_buf, unpacked_buf, 1, 10)
    assert_eq_int(out_count, 2, "Unpacked 2 weights from 1 byte")

    w0 = mem_read_u32(unpacked_buf, 0)
    w1 = mem_read_u32(unpacked_buf, 4)
    assert_eq_int(w0, 30, "Q4_0 Weight 0 (Low Nibble)")
    assert_eq_int(w1, 10, "Q4_0 Weight 1 (High Nibble)")

    // ── ৩. সিলিকন ত্বরান্বিত ম্যাট্রিক্স-ভেক্টর গুণন (AVX-512 GEMV) ──
    say "[3/5] Testing Silicon AVX-512 Accelerated GEMV (gguf_gemv_silicon)..."
    // Row = 4, Column = 8 (Each row matches 512-bit vector width: 8 x u64)
    cols = 8
    rows = 4
    w_mat = sys_alloc(rows * cols * 8)
    in_vec = sys_alloc(cols * 8)
    out_vec = sys_alloc(rows * 8)

    // Fill in_vec = [1, 2, 3, 4, 5, 6, 7, 8]
    ci = 0
    while ci < cols
        sys_poke(in_vec + (ci * 8), ci + 1)
        ci = ci + 1

    // Fill w_mat rows
    ri = 0
    while ri < rows
        cj = 0
        while cj < cols
            // Row 0: all 1s (dot product = 1*1 + 2*1 + ... + 8*1 = 36)
            // Row 1: all 2s (dot product = 72)
            // Row 2: all 3s (dot product = 108)
            // Row 3: all 4s (dot product = 144)
            w_val = ri + 1
            sys_poke(w_mat + (((ri * cols) + cj) * 8), w_val)
            cj = cj + 1
        ri = ri + 1

    res_rows = gguf_gemv_silicon(out_vec, w_mat, in_vec, cols, rows)
    assert_eq_int(res_rows, rows, "Silicon GEMV Processed All Rows")

    y0 = sys_peek(out_vec)
    y1 = sys_peek(out_vec + 8)
    y2 = sys_peek(out_vec + 16)
    y3 = sys_peek(out_vec + 24)

    assert_eq_int(y0, 36, "Row 0 Dot Product (512-bit ZMM)")
    assert_eq_int(y1, 72, "Row 1 Dot Product (512-bit ZMM)")
    assert_eq_int(y2, 108, "Row 2 Dot Product (512-bit ZMM)")
    assert_eq_int(y3, 144, "Row 3 Dot Product (512-bit ZMM)")

    // ── ৪. আর্গম্যাক্স টোকেন স্যাম্পলিং ──
    say "[4/5] Testing Greedy Next-Token ArgMax Sampler..."
    logits = sys_alloc(32)
    mem_write_u32(logits, 0, 12)
    mem_write_u32(logits, 4, 95)  // Highest (offset 4 is index 1)
    mem_write_u32(logits, 8, 42)
    mem_write_u32(logits, 12, 18)

    best_tok = gguf_token_argmax(logits, 4)
    assert_eq_int(best_tok, 1, "Best Logit Token Index == 1")

    // ── ৫. এজ কেস ও সেফটি গার্ড ──
    say "[5/5] Testing Edge Cases & Safety Guards..."
    null_gemv = gguf_gemv_silicon(0, w_mat, in_vec, cols, rows)
    assert_eq_int(null_gemv, 0, "Null-pointer Safety Guard in GEMV")

    zero_vocab = gguf_token_argmax(logits, 0)
    assert_eq_int(zero_vocab, 0, "Zero-vocab Safety Guard in ArgMax")

    say "========================================================"
    say "PASS: Native GGUF & AVX-512 AI Inference Engine Verified!"
    say "========================================================"
    return 0

main()
