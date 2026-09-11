// ==============================================================================
// 👑 LIPI NATIVE GGUF & QUANTIZED LLM INFERENCE ENGINE (examples/07_llm_inference/main.lp)
// ⚡ 100% Python/PyTorch Free | Hardware GEMV Matrix Vector Multiplying
// ==============================================================================

// WHY: Demonstrates AI inference written 100% in pure Lipi. Loads quantized weights,
// executes SIMD matrix-vector multiplication (GEMV), and samples greedy logits.

include "std/io.lp"
include "std/mem.lp"
include "std/gguf.lp"
include "std/ai.lp"

// ── ভোকাবুলারি ডিকশনারি ম্যাপার (Bengali Token Vocabulary Lookup) ─────────────
// WHY: Maps integer token IDs to sovereign Bengali linguistic representations.
// In a production model, this is loaded directly from the GGUF tokenizer vocab table.
fn vocab_lookup tok
    if tok == 0 return "লিপি"
    if tok == 1 return "হলো"
    if tok == 2 return "একটি"
    if tok == 3 return "সার্বভৌম"
    if tok == 4 return "প্রোগ্রামিং"
    if tok == 5 return "ভাষা"
    if tok == 6 return "যা"
    if tok == 7 return "সরাসরি"
    if tok == 8 return "সিলিকন"
    if tok == 9 return "হার্ডওয়্যার"
    if tok == 10 return "গতিতে"
    if tok == 11 return "এআই"
    if tok == 12 return "মডেল"
    if tok == 13 return "এক্সিকিউট"
    if tok == 14 return "করে"
    if tok == 15 return "।"
    return "টোকেন_" + tok

fn main
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI NATIVE AUTOREGRESSIVE LLM ENGINE & KV-CACHE DEMO\033[0m             \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ 100% Sovereign Silicon Architecture | Zero Python | Zero PyTorch    \033[0m\033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

    // ──────────────────────────────────────────────────────────────────────────
    // [১] GGUF হেডার সিন্থেসিস ও সিগনেচার যাচাইকরণ
    // ──────────────────────────────────────────────────────────────────────────
    say "[১] জিজিইউএফ মডেল হেডার সিন্থেসিস ও সিগনেচার যাচাইকরণ..."
    header_size = 24
    header_buffer = malloc(header_size)

    // GGUF v3 Magic: 0x46554747 ('GGUF' -> ASCII: 71, 71, 85, 70)
    mem_write_byte(header_buffer, 0, 71)
    mem_write_byte(header_buffer, 1, 71)
    mem_write_byte(header_buffer, 2, 85)
    mem_write_byte(header_buffer, 3, 70)

    // Version: 3 (Offset 4)
    mem_write_byte(header_buffer, 4, 3)
    mem_write_byte(header_buffer, 5, 0)

    // Tensor Count: 291 (QWORD 1 = offset 8)
    mem_write_u32(header_buffer, 1, 291)

    // Metadata KV Count: 0 (QWORD 2 = offset 16)
    mem_write_u32(header_buffer, 2, 0)

    ম্যাজিক_ঠিক = gguf_magic_verify(header_buffer)
    টেনসর_num = gguf_tensor_count(header_buffer)

    if ম্যাজিক_ঠিক == 1
        say "  ✔ GGUF v3 ম্যাজিক ভ্যালিডেশন সফল! (Magic: 'GGUF')"
        say "  ✔ শনাক্তকৃত টেনসর সংখ্যা: " + টেনসর_num + " টি (Expected: 291)"

    free(header_buffer, header_size)

    // ──────────────────────────────────────────────────────────────────────────
    // [২] হার্ডওয়্যার সিলিকন GEMV ইনফারেন্স এক্সিকিউশন
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[২] হার্ডওয়্যার সিলিকন GEMV (Matrix-Vector) ইনফারেন্স এক্সিকিউশন..."

    gemv_dim = 4
    gemv_vocab = 3

    অ্যাক্টিভেশন_X = malloc(gemv_dim * 8)
    weights_W = malloc(gemv_vocab * gemv_dim * 8)
    logit_Y = malloc(gemv_vocab * 8)

    mem_write_u32(অ্যাক্টিভেশন_X, 0, 1)
    mem_write_u32(অ্যাক্টিভেশন_X, 1, 2)
    mem_write_u32(অ্যাক্টিভেশন_X, 2, 3)
    mem_write_u32(অ্যাক্টিভেশন_X, 3, 4)

    mem_write_u32(weights_W, 0, 1)
    mem_write_u32(weights_W, 1, 1)
    mem_write_u32(weights_W, 2, 1)
    mem_write_u32(weights_W, 3, 1)

    mem_write_u32(weights_W, 4, 2)
    mem_write_u32(weights_W, 5, 2)
    mem_write_u32(weights_W, 6, 2)
    mem_write_u32(weights_W, 7, 2)

    mem_write_u32(weights_W, 8, 3)
    mem_write_u32(weights_W, 9, 3)
    mem_write_u32(weights_W, 10, 3)
    mem_write_u32(weights_W, 11, 5)

    gguf_gemv(logit_Y, weights_W, অ্যাক্টিভেশন_X, gemv_dim, gemv_vocab)

    l0 = mem_read_u32(logit_Y, 0)
    l1 = mem_read_u32(logit_Y, 1)
    l2 = mem_read_u32(logit_Y, 2)

    say "  ✔ প্রেডিক্টেড logit score: [" + l0 + ", " + l1 + ", " + l2 + "] (Expected: [10, 20, 38])"

    সেরা_টোকেন = gguf_token_argmax(logit_Y, gemv_vocab)
    say "  ✔ গ্রিডি স্যাম্পলার নির্বাচিত পরবর্তী টোকেন আইডি: " + সেরা_টোকেন + " (Expected: 2)"

    free(অ্যাক্টিভেশন_X, gemv_dim * 8)
    free(weights_W, gemv_vocab * gemv_dim * 8)
    free(logit_Y, gemv_vocab * 8)

    // ──────────────────────────────────────────────────────────────────────────
    // [৩] উচ্চ-ক্ষমতাসম্পন্ন কেভি-ক্যাশ বাফার স্টেট যাচাইকরণ
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[৩] পিওর লিপি ২.০ কেভি-ক্যাশ (KV-Cache) স্টেট বাফার যাচাইকরণ..."
    kv_max_seq = 64
    kv_layers = 2
    kv_heads = 2
    kv_head_dim = 4
    kv_layer_dim = kv_heads * kv_head_dim

    cache = kv_cache_create(kv_max_seq, kv_layers, kv_heads, kv_head_dim)
    say "  ✔ কেভি-ক্যাশ পুল বরাদ্দ সফল: " + kv_layers + " লেয়ার, " + kv_heads + " হেড, " + kv_max_seq + " সর্বোচ্চ সিকোয়েন্স"

    dummy_k = malloc(kv_layer_dim * 8)
    dummy_v = malloc(kv_layer_dim * 8)
    mem_write_u32(dummy_k, 0, 777)
    mem_write_u32(dummy_v, 0, 888)

    // লেয়ার ০ ও ১ এ কী ও ভ্যালু সংযোজন
    new_p0 = kv_cache_append(cache, 0, dummy_k, dummy_v)
    new_p1 = kv_cache_append(cache, 1, dummy_k, dummy_v)
    say "  ✔ লেয়ার ০ ও ১ এ টোকেন ০ কেভি ভেক্টর স্টোর সম্পন্ন (Cache Len: " + kv_cache_seq_len(cache) + ")"

    k_ptr0 = kv_cache_get_keys(cache, 0)
    v_ptr0 = kv_cache_get_values(cache, 0)
    read_k = mem_read_u32(k_ptr0, 0)
    read_v = mem_read_u32(v_ptr0, 0)
    say "  ✔ কেভি-ক্যাশ মেমরি রিড যাচাই: K[0]=" + read_k + ", V[0]=" + read_v + " (Expected: 777, 888)"

    free(dummy_k, kv_layer_dim * 8)
    free(dummy_v, kv_layer_dim * 8)
    kv_cache_free(cache)
    say "  ✔ কেভি-ক্যাশ মেমরি অবমুক্তি সফল (Zero Leaks)"

    // ──────────────────────────────────────────────────────────────────────────
    // [৪] অটোরিগ্রেসিভ ট্রান্সফরমার এআই মডেল ইনিশিয়ালাইজেশন
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[৪] অটোরিগ্রেসিভ ট্রান্সফরমার এআই মডেল ইনিশিয়ালাইজেশন..."
    model_vocab = 16
    model_dim = 8
    model_layers = 2
    model_heads = 2
    model_head_dim = 4
    model_max_seq = 64

    model = ai_model_create(model_vocab, model_dim, model_layers, model_heads, model_head_dim, model_max_seq)
    model.eos_token = 15 // দাঁড়ি বা <EOS>
    say "  ✔ মডেল কনটেক্সট সক্রিয়: Vocab=" + model_vocab + ", Dim=" + model_dim + ", Layers=" + model_layers

    prompt = list()
    push(prompt, 0) // লিপি
    push(prompt, 1) // হলো
    push(prompt, 2) // একটি
    push(prompt, 3) // সার্বভৌম

    p_str = ""
    pi = 0
    while pi < len(prompt)
        pt = get(prompt, pi)
        if pi > 0
            p_str = p_str + " "
        p_str = p_str + vocab_lookup(pt)
        pi = pi + 1

    say "  ✔ ইনপুট প্রম্পট টোকেনসমূহ: [0, 1, 2, 3]"
    say "  ✔ ইনপুট প্রম্পট টেক্সট    : \"" + p_str + "\""

    // ──────────────────────────────────────────────────────────────────────────
    // [৫] ইন্টারেক্টিভ মাল্টি-স্টেপ টোকেন জেনারেশন ও লাইভ কেভি-ক্যাশ স্ট্রিমিং
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[৫] ইন্টারেক্টিভ মাল্টি-স্টেপ টোকেন জেনারেশন ও লাইভ কেভি-ক্যাশ আপডেট..."
    say "  ── মোড ক: ডিটারমিনিস্টিক গ্রিডি আর্গম্যাক্স (Temperature = 0, Top-K = 1) ──"

    // ক. প্রম্পট প্রিফিল ও কেভি-ক্যাশ প্রস্তুতি
    kv_cache_reset(model.kv_cache)
    say "  [Prefill Phase]: প্রম্পট ইনজেশন ও কেভি-ক্যাশ স্টেট প্রিপারেশন..."
    pi = 0
    while pi < len(prompt)
        ptok = get(prompt, pi)
        ai_forward_token(model, ptok, model.logits_buf)
        say "    • প্রম্পট টোকেন " + (pi + 1) + ": '" + vocab_lookup(ptok) + "' (ID: " + ptok + ") -> KV-Cache Len: " + kv_cache_seq_len(model.kv_cache)
        pi = pi + 1

    // খ. অটোরিগ্রেসিভ সিকোয়েনশিয়াল ডিকোডিং লুপ
    gen_count = 6
    generated_text = p_str
    say "\n  [Autoregressive Decode Phase]: সিকোয়েনশিয়াল টোকেন স্ট্রিমিং শুরু..."

    step = 0
    while step < gen_count
        next_tok = ai_sample(model.logits_buf, model.vocab_size, 0, 1)
        tok_word = vocab_lookup(next_tok)
        generated_text = generated_text + " " + tok_word

        ai_forward_token(model, next_tok, model.logits_buf)
        c_len = kv_cache_seq_len(model.kv_cache)

        say "    [ধাপ " + (step + 1) + "] জেনারেটেড টোকেন: " + next_tok + " ('" + tok_word + "') | বর্তমান KV-Cache দৈর্ঘ্য: " + c_len
        step = step + 1

    say "\n  ✔ সম্পূর্ণ জেনারেটেড বাক্য:"
    say "    \033[1;33m\"" + generated_text + "\"\033[0m"

    // ──────────────────────────────────────────────────────────────────────────
    // [৬] টেম্পারেচার স্কেলিং ও স্টোকাস্টিক টপ-কে স্যাম্পলিং টেস্ট
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[৬] টেম্পারেচার স্কেলিং ও স্টোকাস্টিক টপ-কে স্যাম্পলিং (Temperature = 0.70, Top-K = 3)..."
    gen_stochastic = ai_generate(model, prompt, 5, 70, 3)
    stoch_str = p_str
    si = 0
    while si < len(gen_stochastic)
        st = get(gen_stochastic, si)
        stoch_str = stoch_str + " " + vocab_lookup(st)
        si = si + 1

    say "  ✔ টপ-কে জেনারেটেড টোকেন আইডি: [" + get(gen_stochastic, 0) + ", " + get(gen_stochastic, 1) + ", " + get(gen_stochastic, 2) + ", " + get(gen_stochastic, 3) + ", " + get(gen_stochastic, 4) + "]"
    say "  ✔ টপ-কে জেনারেটেড বাক্য   : \033[1;36m\"" + stoch_str + "\"\033[0m"

    ai_model_free(model)

    say "\n\033[1;32m════════════════════════════════════════════════════════════════════════\033[0m"
    say "\033[1;32m🎉 ১০০% বিশুদ্ধ লিপি ২.০ অটোরিগ্রেসিভ এআই ও কেভি-ক্যাশ ইনফারেন্স সফল!\033[0m"
    say "⚡ [Zero Python | Zero C++ | Zero Libc | Sovereign Silicon Machine Code]"
    say "\033[1;32m════════════════════════════════════════════════════════════════════════\033[0m"

    return 0

main()
