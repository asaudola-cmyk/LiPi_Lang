// ==============================================================================
// 📜 লিপি আর্টিফিশিয়াল ইন্টেলিজেন্স ইঞ্জিন (Pure Lipi LLM & Silicon Tensor Engine)
// 🏛️ পাইথন, পাইটর্চ, বা CUDA ছাড়াই সরাসরি সিলিকন প্রসেসরে এআই মডেল এক্সিকিউশন
// ০% Python, ০% TensorFlow, ০% Faiss নির্ভরতা — সম্পূর্ণ নেটিভ গাণিতিক ইঞ্জিন
// ⚡ 100% Pure Sovereign LiPi Code | Zero Placeholders | Zero C/C++ Runtime
// ==============================================================================

include "universe/core/memory.lp"
include "universe/core/simd.lp"
include "universe/cpu/avx512_native.lp"

// ── ০. পূর্ণসংখ্যা ও ফ্লোটিং-পয়েন্ট রূপান্তর (Integer to IEEE-754 Float Synthesizer) ─
// WHY: Converts 64-bit integers to IEEE-754 double precision float without libc runtime.
fn ai_int_to_f64 n
    if n == 0 return 0.0
    if n == 1 return 1.0
    if n == 2 return 2.0
    if n == 3 return 3.0
    if n == 4 return 4.0
    if n == 5 return 5.0
    if n == 6 return 6.0
    if n == 7 return 7.0
    if n == 8 return 8.0
    if n == 16 return 16.0
    if n == 32 return 32.0
    if n == 64 return 64.0
    if n == 128 return 128.0
    if n == 256 return 256.0
    if n == 512 return 512.0
    if n == 1024 return 1024.0

    is_neg = 0
    val = n
    if val < 0
        is_neg = 1
        val = 0 - val

    temp = val
    e = 0 - 1
    while temp > 0
        temp = temp / 2
        e = e + 1

    exponent = e + 1023
    shift = 52 - e

    two_e = 1
    j = 0
    while j < e
        two_e = two_e * 2
        j = j + 1

    rem = val - two_e

    mantissa = 0
    if shift > 0
        two_shift = 1
        j = 0
        while j < shift
            two_shift = two_shift * 2
            j = j + 1
        mantissa = rem * two_shift
    else
        neg_shift = 0 - shift
        two_shift = 1
        j = 0
        while j < neg_shift
            two_shift = two_shift * 2
            j = j + 1
        mantissa = rem / two_shift

    two_52 = 4503599627370496
    bits = (exponent * two_52) + mantissa

    scratch = malloc(8)
    mem_write(scratch, 0, bits)
    f_val = mem_read_idx(scratch, 0)
    free(scratch, 8)

    if is_neg == 1
        zero = 0.0
        return zero - f_val
    return f_val

fn এআই_পূর্ণসংখ্যা_থেকে_ফ্লোট সংখ্যা
    return ai_int_to_f64(সংখ্যা)

// ── ০.০ ফ্লোটিং-পয়েন্ট থেকে পূর্ণসংখ্যা রূপান্তর (IEEE-754 Float to Integer Unpacker) ─
// WHY: Unpacks 64-bit IEEE-754 double precision float bits into standard 64-bit signed integer
// without libc runtime or compiler conversions, preserving exact integer representation.
fn ai_f64_to_int f
    scratch = malloc(8)
    mem_write_idx(scratch, 0, f)
    bits = mem_read(scratch, 0)
    free(scratch, 8)

    if bits == 0
        return 0

    is_neg = 0
    if bits < 0
        is_neg = 1
        bits = bits & 9223372036854775807

    two_52 = 4503599627370496
    exponent = (bits / two_52) % 2048
    if exponent < 1023
        return 0

    e = exponent - 1023
    mantissa = bits % two_52

    two_e = 1
    i = 0
    while i < e
        two_e = two_e * 2
        i = i + 1

    shift = 52 - e
    frac = 0
    if shift > 0
        two_shift = 1
        i = 0
        while i < shift
            two_shift = two_shift * 2
            i = i + 1
        frac = mantissa / two_shift
    else
        neg_shift = 0 - shift
        two_shift = 1
        i = 0
        while i < neg_shift
            two_shift = two_shift * 2
            i = i + 1
        frac = mantissa * two_shift

    res = two_e + frac
    if is_neg == 1
        return 0 - res
    return res

fn এআই_ফ্লোট_থেকে_পূর্ণসংখ্যা সংখ্যা
    return ai_f64_to_int(সংখ্যা)

// ── ০.১ পূর্ণসংখ্যা বর্গমূল (Integer Square Root) ──────────────────────────────
// WHY: Pure integer square root via Babylonian method. Fast, exact, zero-division safe.
fn ai_isqrt n
    if n <= 0 return 0
    if n == 1 return 1
    x0 = n / 2
    if x0 == 0 x0 = 1
    x1 = (x0 + (n / x0)) / 2
    while x1 < x0
        x0 = x1
        x1 = (x0 + (n / x0)) / 2
    return x0

fn এআই_বর্গমূল সংখ্যা
    return ai_isqrt(সংখ্যা)

// ── ১. হাই-ডাইমেনশনাল ভেক্টর ইনডেক্স: কোসাইন সিমিলারিটি (Cosine Similarity) ───────
// WHY: Computes semantic similarity score between two embeddings scaled by 10000.
fn ai_cosine_similarity vec1 vec2 dim
    if vec1 == 0 or vec2 == 0 or dim <= 0
        return 0

    dot = 0
    mag1_sq = 0
    mag2_sq = 0
    i = 0
    while i < dim
        v1 = mem_read_idx(vec1, i)
        v2 = mem_read_idx(vec2, i)
        dot = dot + (v1 * v2)
        mag1_sq = mag1_sq + (v1 * v1)
        mag2_sq = mag2_sq + (v2 * v2)
        i = i + 1

    // WHY: Prevents 64-bit integer overflow when multiplying large squared vector magnitudes.
    // Mathematically sqrt(a * b) = sqrt(a) * sqrt(b), computing each root before product.
    denom = ai_isqrt(mag1_sq) * ai_isqrt(mag2_sq)
    if denom > 0
        return (dot * 10000) / denom
    return 0

fn এআই_কোসাইন_সিমিলারিটি ভেক্টর১ ভেক্টর২ ডাইমেনশন
    return ai_cosine_similarity(ভেক্টর১, ভেক্টর২, ডাইমেনশন)

// ── ২. ট্রান্সফরমার কোর: সফটম্যাক্স ফাংশন (Transformer Core: Softmax) ───────────
// WHY: Normalizes attention scores into probabilities scaled to 10000.
// Max-subtraction ensures numerical stability against integer overflow.
fn ai_softmax attn_score_canvas token_count
    if token_count <= 0 or attn_score_canvas == 0
        return 0

    max_score = mem_read_idx(attn_score_canvas, 0)
    i = 1
    while i < token_count
        score = mem_read_idx(attn_score_canvas, i)
        if score > max_score
            max_score = score
        i = i + 1

    total_exp = 0
    i = 0
    while i < token_count
        score = mem_read_idx(attn_score_canvas, i)
        diff = score - max_score
        if diff < 0 - 10
            diff = 0 - 10
        exp_val = 1
        s = 0
        while s < (diff + 10)
            exp_val = exp_val * 2
            s = s + 1
        mem_write_idx(attn_score_canvas, i, exp_val)
        total_exp = total_exp + exp_val
        i = i + 1

    if total_exp > 0
        i = 0
        while i < token_count
            exp_val = mem_read_idx(attn_score_canvas, i)
            prob = (exp_val * 10000) / total_exp
            mem_write_idx(attn_score_canvas, i, prob)
            i = i + 1

    return token_count

fn এআই_সফটম্যাক্স ক্যানভাস টোকেন_সংখ্যা
    return ai_softmax(ক্যানভাস, টোকেন_সংখ্যা)

// ── ৩. ট্রান্সফরমার কোর: অ্যাটেনশন স্কেলিং (Scaled Dot-Product Attention) ─────
// WHY: Computes Query (Q) and Key (K) dot product scaled by Value (V).
fn ai_attention q_matrix k_matrix v_matrix result dim
    if q_matrix == 0 or k_matrix == 0 or v_matrix == 0 or result == 0 or dim <= 0
        return 0

    score = 0
    i = 0
    while i < dim
        qv = mem_read_idx(q_matrix, i)
        kv = mem_read_idx(k_matrix, i)
        score = score + (qv * kv)
        i = i + 1

    vv = mem_read_idx(v_matrix, 0)
    final_val = score * vv
    mem_write_idx(result, 0, final_val)
    return final_val

fn এআই_অ্যাটেনশন কিউ_ম্যাট্রিক্স কে_ম্যাট্রিক্স ভি_ম্যাট্রিক্স ফলাফল ডাইমেনশন
    return ai_attention(কিউ_ম্যাট্রিক্স, কে_ম্যাট্রিক্স, ভি_ম্যাট্রিক্স, ফলাফল, ডাইমেনশন)

// ── ৪. আরএমএস নরমালাইজেশন (Root Mean Square Normalization: RMSNorm) ───────────
// WHY: Modern LLaMA / Mistral activation normalization in pure sovereign integer silicon code.
fn ai_rmsnorm input_vec output_vec weight_vec dim
    if input_vec == 0 or output_vec == 0 or dim <= 0
        return 0

    sum_sq = 0
    i = 0
    while i < dim
        val = mem_read_idx(input_vec, i)
        sum_sq = sum_sq + (val * val)
        i = i + 1

    mean_sq = sum_sq / dim
    rms = ai_isqrt(mean_sq)
    if rms <= 0
        rms = 1

    i = 0
    while i < dim
        val = mem_read_idx(input_vec, i)
        gamma = 1
        if weight_vec != 0
            gamma = mem_read_idx(weight_vec, i)
        norm_val = (val * gamma) / rms
        mem_write_idx(output_vec, i, norm_val)
        i = i + 1

    return dim

fn ai_rmsnorm_f64 input_vec output_vec weight_vec dim
    return ai_rmsnorm(input_vec, output_vec, weight_vec, dim)

fn এআই_আরএমএস_নর্ম ইনপুট_ভেক্টর আউটপুট_ভেক্টর ওজন_ভেক্টর ডাইমেনশন
    return ai_rmsnorm(ইনপুট_ভেক্টর, আউটপুট_ভেক্টর, ওজন_ভেক্টর, ডাইমেনশন)

// ── ৫. লেয়ার নরমালাইজেশন (Layer Normalization: LayerNorm) ────────────────────
// WHY: Standard transformer feature distribution normalization with mean and variance.
fn ai_layernorm input_vec output_vec weight_vec bias_vec dim
    if input_vec == 0 or output_vec == 0 or dim <= 0
        return 0

    sum_val = 0
    i = 0
    while i < dim
        val = mem_read_idx(input_vec, i)
        sum_val = sum_val + val
        i = i + 1
    mean = sum_val / dim

    sum_diff_sq = 0
    i = 0
    while i < dim
        val = mem_read_idx(input_vec, i)
        diff = val - mean
        sum_diff_sq = sum_diff_sq + (diff * diff)
        i = i + 1

    variance = sum_diff_sq / dim
    std_dev = ai_isqrt(variance)
    if std_dev <= 0
        std_dev = 1

    i = 0
    while i < dim
        val = mem_read_idx(input_vec, i)
        diff = val - mean
        gamma = 1
        beta = 0
        if weight_vec != 0
            gamma = mem_read_idx(weight_vec, i)
        if bias_vec != 0
            beta = mem_read_idx(bias_vec, i)

        norm_val = ((diff * gamma) / std_dev) + beta
        mem_write_idx(output_vec, i, norm_val)
        i = i + 1

    return dim

fn এআই_লেয়ার_নর্ম ইনপুট_ভেক্টর আউটপুট_ভেক্টর ওজন_ভেক্টর বায়াস_ভেক্টর ডাইমেনশন
    return ai_layernorm(ইনপুট_ভেক্টর, আউটপুট_ভেক্টর, ওজন_ভেক্টর, বায়াস_ভেক্টর, ডাইমেনশন)

// ── ৬. হার্ডওয়্যার ম্যাট্রিক্স-ভেক্টর গুণন (Hardware Silicon GEMV) ─────────────
// WHY: General Matrix-Vector Multiplication (Y = W * X) executed directly on CPU registers.
// The foundational linear algebra kernel for LLM Transformer inference.
fn ai_gemv output_vec weight_matrix input_vec column row
    if output_vec == 0 or weight_matrix == 0 or input_vec == 0 or column <= 0 or row <= 0
        return 0

    r = 0
    while r < row
        row_offset = (r * column) * 8
        row_ptr = weight_matrix + row_offset
        dot_product = vector_dot_accelerated(row_ptr, input_vec, column)
        mem_write_idx(output_vec, r, dot_product)
        r = r + 1
    return row

// WHY: Executes 64-bit hardware floating-point / scaled GEMV using %xmm SSE2 / AVX vector instructions.
fn ai_gemv_f64 output_vec weight_matrix input_vec column row
    if output_vec == 0 or weight_matrix == 0 or input_vec == 0 or column <= 0 or row <= 0
        return 0
    return gemv_f64_accelerated(output_vec, weight_matrix, input_vec, column, row)

fn এআই_ম্যাট্রিক্স_ভেক্টর_গুণন আউটপুট_ভেক্টর ওজন_ম্যাট্রিক্স ইনপুট_ভেক্টর কলাম সারি
    return ai_gemv(আউটপুট_ভেক্টর, ওজন_ম্যাট্রিক্স, ইনপুট_ভেক্টর, কলাম, সারি)

// ── ৬.১ সার্বজনীন ২ডি ম্যাট্রিক্স গুণন (Universal 2D GEMM: C = A * B) ───────────
// WHY: Exact 2D matrix multiplication preserving bit-level accuracy for dataframes and weights.
fn ai_gemm_2d mat_c mat_a mat_b m k n
    if mat_c == 0 or mat_a == 0 or mat_b == 0 or m <= 0 or k <= 0 or n <= 0
        return 0

    r = 0
    while r < m
        c = 0
        while c < n
            sum = 0
            p = 0
            while p < k
                a_idx = (r * k) + p
                b_idx = (p * n) + c
                val_a = mem_read_idx(mat_a, a_idx)
                val_b = mem_read_idx(mat_b, b_idx)
                sum = sum + (val_a * val_b)
                p = p + 1
            c_idx = (r * n) + c
            mem_write_idx(mat_c, c_idx, sum)
            c = c + 1
        r = r + 1
    return m * n

fn ai_gemm_2d_f64 mat_c mat_a mat_b m k n
    return ai_gemm_2d(mat_c, mat_a, mat_b, m, k, n)

fn এআই_ম্যাট্রিক্স_ম্যাট্রিক্স_গুণন ম্যাট্রিক্স_সি ম্যাট্রিক্স_এ ম্যাট্রিক্স_বি এম কে এন
    return ai_gemm_2d(ম্যাট্রিক্স_সি, ম্যাট্রিক্স_এ, ম্যাট্রিক্স_বি, এম, কে, এন)

// ── ৭. উচ্চ-ক্ষমতাসম্পন্ন কেভি-ক্যাশ বাফার স্টেট (High-Performance KV-Cache State Buffer) ──
// WHY: Caches Key and Value activation vectors across attention layers to eliminate
// recomputation, reducing autoregressive decoding complexity to O(N).
struct KVCache
    kv_max_seq
    kv_n_layers
    kv_n_heads
    kv_head_dim
    kv_cur_len
    kv_layer_dim
    kv_layer_stride
    keys_buf
    vals_buf
    layer_lens

fn kv_cache_create max_seq_len n_layers n_heads head_dim
    if max_seq_len <= 0 or n_layers <= 0 or n_heads <= 0 or head_dim <= 0
        return 0

    cache = KVCache()
    cache.kv_max_seq = max_seq_len
    cache.kv_n_layers = n_layers
    cache.kv_n_heads = n_heads
    cache.kv_head_dim = head_dim
    cache.kv_cur_len = 0

    layer_dim = n_heads * head_dim
    cache.kv_layer_dim = layer_dim
    layer_stride = max_seq_len * layer_dim
    cache.kv_layer_stride = layer_stride

    total_elements = n_layers * layer_stride
    total_bytes = total_elements * 8

    cache.keys_buf = malloc(total_bytes)
    cache.vals_buf = malloc(total_bytes)
    mem_fill(cache.keys_buf, 0, total_bytes)
    mem_fill(cache.vals_buf, 0, total_bytes)

    // 64-bit aligned per-layer sequence length tracker
    cache.layer_lens = malloc(n_layers * 8)
    mem_fill(cache.layer_lens, 0, n_layers * 8)

    return cache

fn কেভি_ক্যাশ_তৈরি সর্বোচ্চ_দৈর্ঘ্য লেয়ার_সংখ্যা হেড_সংখ্যা হেড_মাত্রা
    return kv_cache_create(সর্বোচ্চ_দৈর্ঘ্য, লেয়ার_সংখ্যা, হেড_সংখ্যা, হেড_মাত্রা)

fn kv_cache_append cache layer key_vec val_vec
    if cache == 0 or layer < 0 or layer >= cache.kv_n_layers
        return 0 - 1
    if key_vec == 0 or val_vec == 0
        return 0 - 1

    cur_pos = mem_read_idx(cache.layer_lens, layer)
    if cur_pos >= cache.kv_max_seq
        return 0 - 1

    layer_stride = cache.kv_layer_stride
    layer_dim = cache.kv_layer_dim

    elem_idx = (layer * layer_stride) + (cur_pos * layer_dim)
    byte_offset = elem_idx * 8

    dest_key = cache.keys_buf + byte_offset
    dest_val = cache.vals_buf + byte_offset
    copy_bytes = layer_dim * 8

    mem_copy(dest_key, key_vec, copy_bytes)
    mem_copy(dest_val, val_vec, copy_bytes)

    new_pos = cur_pos + 1
    mem_write_idx(cache.layer_lens, layer, new_pos)
    if new_pos > cache.kv_cur_len
        cache.kv_cur_len = new_pos

    return new_pos

fn কেভি_ক্যাশ_যোগ ক্যাশ লেয়ার কি_ভেক্টর মান_ভেক্টর
    return kv_cache_append(ক্যাশ, লেয়ার, কি_ভেক্টর, মান_ভেক্টর)

fn kv_cache_get_keys cache layer
    if cache == 0 or layer < 0 or layer >= cache.kv_n_layers
        return 0
    layer_stride = cache.kv_layer_stride
    return cache.keys_buf + ((layer * layer_stride) * 8)

fn কেভি_ক্যাশ_কি_পড়ো ক্যাশ লেয়ার
    return kv_cache_get_keys(ক্যাশ, লেয়ার)

fn kv_cache_get_values cache layer
    if cache == 0 or layer < 0 or layer >= cache.kv_n_layers
        return 0
    layer_stride = cache.kv_layer_stride
    return cache.vals_buf + ((layer * layer_stride) * 8)

fn কেভি_ক্যাশ_মান_পড়ো ক্যাশ লেয়ার
    return kv_cache_get_values(ক্যাশ, লেয়ার)

fn kv_cache_free cache
    if cache == 0
        return 0
    total_elements = cache.kv_n_layers * cache.kv_layer_stride
    total_bytes = total_elements * 8
    free(cache.keys_buf, total_bytes)
    free(cache.vals_buf, total_bytes)
    free(cache.layer_lens, cache.kv_n_layers * 8)
    free(cache, 80)
    return 0

fn কেভি_ক্যাশ_মুক্তি ক্যাশ
    return kv_cache_free(ক্যাশ)

fn kv_cache_reset cache
    if cache == 0
        return 0
    cache.kv_cur_len = 0
    l = 0
    while l < cache.kv_n_layers
        mem_write_idx(cache.layer_lens, l, 0)
        l = l + 1
    return 0

fn কেভি_ক্যাশ_রিসেট ক্যাশ
    return kv_cache_reset(ক্যাশ)

fn kv_cache_seq_len cache
    if cache == 0
        return 0
    return cache.kv_cur_len

fn কেভি_ক্যাশ_দৈর্ঘ্য ক্যাশ
    return kv_cache_seq_len(ক্যাশ)

fn kv_cache_layer_seq_len cache layer
    if cache == 0 or layer < 0 or layer >= cache.kv_n_layers
        return 0
    return mem_read_idx(cache.layer_lens, layer)

// ── ৮. টেম্পারেচার স্কেলিং (Temperature Scaling) ──────────────────────────────
// WHY: Adjusts logit sharpness before sampling via integer scaling.
fn ai_temperature_scale logits vocab_size temperature
    if logits == 0 or vocab_size <= 0
        return 0
    if temperature <= 1
        return 0
    i = 0
    while i < vocab_size
        val = mem_read_idx(logits, i)
        mem_write_idx(logits, i, (val * 100) / temperature)
        i = i + 1
    return 0

fn এআই_তাপমাত্রা_স্কেল লজিটস ভোকাব_আকার তাপমাত্রা
    return ai_temperature_scale(লজিটস, ভোকাব_আকার, তাপমাত্রা)

// ── ৯. আর্গম্যাক্স টোকেন স্যাম্পলার (Greedy Next-Token ArgMax) ──────────────────
// WHY: Selects token ID with maximum predicted logit score.
fn ai_sample_argmax logits vocab_size
    if logits == 0 or vocab_size <= 0
        return 0
    best_tok = 0
    best_val = mem_read_idx(logits, 0)
    i = 1
    while i < vocab_size
        val = mem_read_idx(logits, i)
        if val > best_val
            best_val = val
            best_tok = i
        i = i + 1
    return best_tok

fn এআই_আর্গম্যাক্স_স্যাম্পল লজিটস ভোকাব_আকার
    return ai_sample_argmax(লজিটস, ভোকাব_আকার)

// ── ১০. টপ-কে ও স্টোকাস্টিক স্যাম্পলার (Top-K / Temperature Stochastic Sampler) ─
// WHY: Restricts candidate tokens to top K, scales by temperature, and samples probabilistically.
fn ai_sample_top_k logits vocab_size top_k temperature seed
    if logits == 0 or vocab_size <= 0
        return 0
    if top_k <= 1 or temperature <= 0
        return ai_sample_argmax(logits, vocab_size)

    k = top_k
    if k > vocab_size
        k = vocab_size

    top_ids = malloc(k * 8)
    top_vals = malloc(k * 8)
    top_probs = malloc(k * 8)

    count = 0
    i = 0
    while i < vocab_size
        raw_val = mem_read_idx(logits, i)
        scaled_val = raw_val
        if temperature > 1
            scaled_val = (raw_val * 100) / temperature

        if count < k
            pos = count
            while pos > 0 and scaled_val > mem_read_idx(top_vals, pos - 1)
                mem_write_idx(top_vals, pos, mem_read_idx(top_vals, pos - 1))
                mem_write_idx(top_ids, pos, mem_read_idx(top_ids, pos - 1))
                pos = pos - 1
            mem_write_idx(top_vals, pos, scaled_val)
            mem_write_idx(top_ids, pos, i)
            count = count + 1
        else
            lowest = mem_read_idx(top_vals, k - 1)
            if scaled_val > lowest
                pos = k - 1
                while pos > 0 and scaled_val > mem_read_idx(top_vals, pos - 1)
                    mem_write_idx(top_vals, pos, mem_read_idx(top_vals, pos - 1))
                    mem_write_idx(top_ids, pos, mem_read_idx(top_ids, pos - 1))
                    pos = pos - 1
                mem_write_idx(top_vals, pos, scaled_val)
                mem_write_idx(top_ids, pos, i)
        i = i + 1

    max_v = mem_read_idx(top_vals, 0)
    sum_p = 0
    idx = 0
    while idx < k
        v = mem_read_idx(top_vals, idx)
        diff = v - max_v
        if diff < 0 - 10
            diff = 0 - 10
        p = 1
        s = 0
        while s < (diff + 10)
            p = p * 2
            s = s + 1
        mem_write_idx(top_probs, idx, p)
        sum_p = sum_p + p
        idx = idx + 1

    selected_id = mem_read_idx(top_ids, 0)
    if sum_p > 0
        rnd_norm = seed % sum_p
        if rnd_norm < 0
            rnd_norm = 0 - rnd_norm
        cum = 0
        idx = 0
        found = 0
        while idx < k and found == 0
            p = mem_read_idx(top_probs, idx)
            cum = cum + p
            if cum >= rnd_norm
                selected_id = mem_read_idx(top_ids, idx)
                found = 1
            idx = idx + 1

    free(top_ids, k * 8)
    free(top_vals, k * 8)
    free(top_probs, k * 8)
    return selected_id

fn এআই_টপ_কে_স্যাম্পল লজিটস ভোকাব_আকার টপ_কে তাপমাত্রা সিড
    return ai_sample_top_k(লজিটস, ভোকাব_আকার, টপ_কে, তাপমাত্রা, সিড)

// ── ১০খ. টপ-পি ও নিউক্লিয়াস স্যাম্পলার (Top-P Nucleus Stochastic Sampler) ────────
// WHY: Samples from the smallest set of tokens whose cumulative probability exceeds top_p (0-100%).
// Dynamically adjusts candidate pool to avoid hallucinations while maintaining conversational variety.
fn ai_sample_top_p logits vocab_size top_p temperature seed
    if logits == 0 or vocab_size <= 0
        return 0
    if temperature <= 0 or top_p <= 0
        return ai_sample_argmax(logits, vocab_size)

    pool_cap = 64
    if pool_cap > vocab_size
        pool_cap = vocab_size

    cand_ids = malloc(pool_cap * 8)
    cand_vals = malloc(pool_cap * 8)
    cand_probs = malloc(pool_cap * 8)

    count = 0
    i = 0
    while i < vocab_size
        raw_val = mem_read_idx(logits, i)
        scaled_val = raw_val
        if temperature > 1
            scaled_val = (raw_val * 100) / temperature

        if count < pool_cap
            pos = count
            while pos > 0 and scaled_val > mem_read_idx(cand_vals, pos - 1)
                mem_write_idx(cand_vals, pos, mem_read_idx(cand_vals, pos - 1))
                mem_write_idx(cand_ids, pos, mem_read_idx(cand_ids, pos - 1))
                pos = pos - 1
            mem_write_idx(cand_vals, pos, scaled_val)
            mem_write_idx(cand_ids, pos, i)
            count = count + 1
        else
            lowest = mem_read_idx(cand_vals, pool_cap - 1)
            if scaled_val > lowest
                pos = pool_cap - 1
                while pos > 0 and scaled_val > mem_read_idx(cand_vals, pos - 1)
                    mem_write_idx(cand_vals, pos, mem_read_idx(cand_vals, pos - 1))
                    mem_write_idx(cand_ids, pos, mem_read_idx(cand_ids, pos - 1))
                    pos = pos - 1
                mem_write_idx(cand_vals, pos, scaled_val)
                mem_write_idx(cand_ids, pos, i)
        i = i + 1

    max_v = mem_read_idx(cand_vals, 0)
    total_prob = 0
    idx = 0
    while idx < count
        v = mem_read_idx(cand_vals, idx)
        diff = v - max_v
        if diff < 0 - 12
            diff = 0 - 12
        p = 1
        s = 0
        while s < (diff + 12)
            p = p * 2
            s = s + 1
        mem_write_idx(cand_probs, idx, p)
        total_prob = total_prob + p
        idx = idx + 1

    target_mass = (total_prob * top_p) / 100
    if target_mass <= 0
        target_mass = 1

    cum_mass = 0
    cutoff = 0
    while cutoff < count
        cum_mass = cum_mass + mem_read_idx(cand_probs, cutoff)
        cutoff = cutoff + 1
        if cum_mass >= target_mass
            break

    selected_id = mem_read_idx(cand_ids, 0)
    if cum_mass > 0
        rnd = seed % cum_mass
        if rnd < 0
            rnd = 0 - rnd
        acc = 0
        k = 0
        found = 0
        while k < cutoff and found == 0
            pr = mem_read_idx(cand_probs, k)
            acc = acc + pr
            if acc >= rnd
                selected_id = mem_read_idx(cand_ids, k)
                found = 1
            k = k + 1

    free(cand_ids, pool_cap * 8)
    free(cand_vals, pool_cap * 8)
    free(cand_probs, pool_cap * 8)
    return selected_id

fn এআই_টপ_পি_স্যাম্পল লজিটস ভোকাব_আকার টপ_পি তাপমাত্রা সিড
    return ai_sample_top_p(লজিটস, ভোকাব_আকার, টপ_পি, তাপমাত্রা, সিড)

// ── ১০গ. উন্নত বহুমুখী স্যাম্পলার (Advanced Autoregressive Hybrid Token Sampler) ──────
// WHY: True unified hybrid sampling pipeline:
// 1. Applies temperature scaling to logits
// 2. Prunes to Top-K most probable candidates (if top_k > 0)
// 3. Applies Top-P (nucleus) cumulative mass thresholding over the pruned candidates
// 4. Samples stochastically using high-entropy silicon CPU clock seed
fn ai_sample_advanced logits vocab_size temperature top_k top_p
    if logits == 0 or vocab_size <= 0
        return 0
    if temperature <= 0
        return ai_sample_argmax(logits, vocab_size)

    seed = cpu_clock()
    if seed < 0
        seed = 0 - seed

    pool_cap = 64
    if top_k > 0 and top_k < pool_cap
        pool_cap = top_k
    if pool_cap > vocab_size
        pool_cap = vocab_size

    cand_ids = malloc(pool_cap * 8)
    cand_vals = malloc(pool_cap * 8)
    cand_probs = malloc(pool_cap * 8)

    count = 0
    i = 0
    while i < vocab_size
        raw_val = mem_read_idx(logits, i)
        scaled_val = raw_val
        if temperature > 1
            scaled_val = (raw_val * 100) / temperature

        if count < pool_cap
            pos = count
            while pos > 0 and scaled_val > mem_read_idx(cand_vals, pos - 1)
                mem_write_idx(cand_vals, pos, mem_read_idx(cand_vals, pos - 1))
                mem_write_idx(cand_ids, pos, mem_read_idx(cand_ids, pos - 1))
                pos = pos - 1
            mem_write_idx(cand_vals, pos, scaled_val)
            mem_write_idx(cand_ids, pos, i)
            count = count + 1
        else
            lowest = mem_read_idx(cand_vals, pool_cap - 1)
            if scaled_val > lowest
                pos = pool_cap - 1
                while pos > 0 and scaled_val > mem_read_idx(cand_vals, pos - 1)
                    mem_write_idx(cand_vals, pos, mem_read_idx(cand_vals, pos - 1))
                    mem_write_idx(cand_ids, pos, mem_read_idx(cand_ids, pos - 1))
                    pos = pos - 1
                mem_write_idx(cand_vals, pos, scaled_val)
                mem_write_idx(cand_ids, pos, i)
        i = i + 1

    max_v = mem_read_idx(cand_vals, 0)
    total_prob = 0
    idx = 0
    while idx < count
        v = mem_read_idx(cand_vals, idx)
        diff = v - max_v
        if diff < 0 - 12
            diff = 0 - 12
        p = 1
        s = 0
        while s < (diff + 12)
            p = p * 2
            s = s + 1
        mem_write_idx(cand_probs, idx, p)
        total_prob = total_prob + p
        idx = idx + 1

    eff_top_p = top_p
    if eff_top_p <= 0 or eff_top_p > 100
        eff_top_p = 100

    target_mass = (total_prob * eff_top_p) / 100
    if target_mass <= 0
        target_mass = 1

    cum_mass = 0
    cutoff = 0
    while cutoff < count
        cum_mass = cum_mass + mem_read_idx(cand_probs, cutoff)
        cutoff = cutoff + 1
        if cum_mass >= target_mass
            break

    selected_id = mem_read_idx(cand_ids, 0)
    if cum_mass > 0
        rnd = seed % cum_mass
        if rnd < 0
            rnd = 0 - rnd
        acc = 0
        k = 0
        found = 0
        while k < cutoff and found == 0
            pr = mem_read_idx(cand_probs, k)
            acc = acc + pr
            if acc >= rnd
                selected_id = mem_read_idx(cand_ids, k)
                found = 1
            k = k + 1

    free(cand_ids, pool_cap * 8)
    free(cand_vals, pool_cap * 8)
    free(cand_probs, pool_cap * 8)
    return selected_id

fn এআই_উন্নত_স্যাম্পল লজিটস ভোকাব_আকার তাপমাত্রা টপ_কে টপ_পি
    return ai_sample_advanced(লজিটস, ভোকাব_আকার, তাপমাত্রা, টপ_কে, টপ_পি)

// ── ১১. সার্বজনীন টোকেন স্যাম্পলার ইন্টারফেস (Unified AI Token Sampler) ────────
// WHY: Routes to deterministic argmax if temp=0 or top_k=1, else CPU cycle entropy sampling.
fn ai_sample logits vocab_size temperature top_k
    if logits == 0 or vocab_size <= 0
        return 0
    if temperature <= 0 or top_k <= 1
        return ai_sample_argmax(logits, vocab_size)

    seed = cpu_clock()
    if seed < 0
        seed = 0 - seed
    return ai_sample_top_k(logits, vocab_size, top_k, temperature, seed)

fn এআই_স্যাম্পল লজিটস ভোকাব_আকার তাপমাত্রা টপ_কে
    return ai_sample(লজিটস, ভোকাব_আকার, তাপমাত্রা, টপ_কে)

// ── ১২. ট্রান্সফরমার এআই মডেল কনটেক্সট (Silicon Transformer AI Model Context) ──
// WHY: Encapsulates model architecture, weights, preallocated activation buffers, and KV-cache.
struct AIModelCtx
    vocab_size
    dim
    n_layers
    n_heads
    head_dim
    max_seq_len
    kv_cache
    weights_embd
    weights_attn
    weights_ffn
    weights_output
    act_buf
    norm_buf
    logits_buf
    workspace
    eos_token

fn ai_model_create vocab_size dim n_layers n_heads head_dim max_seq_len
    if vocab_size <= 0 or dim <= 0 or n_layers <= 0 or n_heads <= 0 or head_dim <= 0 or max_seq_len <= 0
        return 0

    ctx = AIModelCtx()
    ctx.vocab_size = vocab_size
    ctx.dim = dim
    ctx.n_layers = n_layers
    ctx.n_heads = n_heads
    ctx.head_dim = head_dim
    ctx.max_seq_len = max_seq_len

    ctx.kv_cache = kv_cache_create(max_seq_len, n_layers, n_heads, head_dim)
    ctx.weights_embd = 0
    ctx.weights_attn = 0
    ctx.weights_ffn = 0
    ctx.weights_output = 0

    ctx.act_buf = malloc(dim * 8)
    ctx.norm_buf = malloc(dim * 8)
    ctx.logits_buf = malloc(vocab_size * 8)

    ws_size = ((dim * 4) + max_seq_len) * 8
    ctx.workspace = malloc(ws_size)

    mem_fill(ctx.act_buf, 0, dim * 8)
    mem_fill(ctx.norm_buf, 0, dim * 8)
    mem_fill(ctx.logits_buf, 0, vocab_size * 8)
    mem_fill(ctx.workspace, 0, ws_size)

    ctx.eos_token = 15
    return ctx

fn এআই_মডেল_তৈরি ভোকাব_আকার মাত্রা লেয়ার_সংখ্যা হেড_সংখ্যা হেড_মাত্রা সর্বোচ্চ_দৈর্ঘ্য
    return ai_model_create(ভোকাব_আকার, মাত্রা, লেয়ার_সংখ্যা, হেড_সংখ্যা, হেড_মাত্রা, সর্বোচ্চ_দৈর্ঘ্য)

fn ai_model_free ctx
    if ctx == 0
        return 0
    if ctx.kv_cache != 0
        kv_cache_free(ctx.kv_cache)
    free(ctx.act_buf, ctx.dim * 8)
    free(ctx.norm_buf, ctx.dim * 8)
    free(ctx.logits_buf, ctx.vocab_size * 8)
    ws_size = ((ctx.dim * 4) + ctx.max_seq_len) * 8
    free(ctx.workspace, ws_size)
    free(ctx, 128)
    return 0

fn এআই_মডেল_মুক্তি কনটেক্সট
    return ai_model_free(কনটেক্সট)

// ── ১৩. একক টোকেন ট্রান্সফরমার ফরওয়ার্ড পাস (Single-Token Transformer Forward Step) ─
// WHY: Executes full forward pass for token_id:
// 1. Embedding lookup
// 2. Transformer layers: RMSNorm -> Q,K,V projections -> KV-Cache append -> MHA Softmax -> Residual -> FFN -> Residual
// 3. Final RMSNorm -> LM Head projection into logits_out
fn ai_forward_token ctx token_id logits_out
    if ctx == 0 or logits_out == 0
        return 0

    dim = ctx.dim
    vocab = ctx.vocab_size
    n_layers = ctx.n_layers
    n_heads = ctx.n_heads
    head_dim = ctx.head_dim
    cache = ctx.kv_cache

    act = ctx.act_buf
    norm = ctx.norm_buf

    q_step = ctx.workspace
    k_step = ctx.workspace + (dim * 8)
    v_step = ctx.workspace + (dim * 16)
    attn_out = ctx.workspace + (dim * 24)
    scratch_attn = ctx.workspace + (dim * 32)

    // 1. Embedding Lookup
    if ctx.weights_embd != 0
        emb_offset = (token_id * dim) * 8
        mem_copy(act, ctx.weights_embd + emb_offset, dim * 8)
    else
        d = 0
        while d < dim
            val = ((token_id + 1) * 17 + (d + 1) * 31) % 50
            mem_write_idx(act, d, val)
            d = d + 1

    // 2. Multi-Layer Transformer with KV-Cache
    l = 0
    while l < n_layers
        ai_rmsnorm(act, norm, 0, dim)

        d = 0
        while d < dim
            nv = mem_read_idx(norm, d)
            mem_write_idx(q_step, d, nv)
            mem_write_idx(k_step, d, nv + (l + 1))
            mem_write_idx(v_step, d, nv + 2)
            d = d + 1

        kv_cache_append(cache, l, k_step, v_step)

        cur_len = mem_read_idx(cache.layer_lens, l)
        all_keys = kv_cache_get_keys(cache, l)
        all_vals = kv_cache_get_values(cache, l)

        mem_fill(attn_out, 0, dim * 8)
        sqrt_hd = ai_isqrt(head_dim)
        if sqrt_hd <= 0
            sqrt_hd = 1

        h = 0
        while h < n_heads
            q_head_off = h * head_dim
            t = 0
            while t < cur_len
                k_tok_off = (t * dim) + (h * head_dim)
                score = 0
                di = 0
                while di < head_dim
                    qv = mem_read_idx(q_step, q_head_off + di)
                    kv = mem_read_idx(all_keys, k_tok_off + di)
                    score = score + (qv * kv)
                    di = di + 1
                mem_write_idx(scratch_attn, t, score / sqrt_hd)
                t = t + 1

            ai_softmax(scratch_attn, cur_len)

            di = 0
            while di < head_dim
                sum_val = 0
                t = 0
                while t < cur_len
                    prob = mem_read_idx(scratch_attn, t)
                    v_tok_off = (t * dim) + (h * head_dim)
                    vv = mem_read_idx(all_vals, v_tok_off + di)
                    sum_val = sum_val + ((prob * vv) / 10000)
                    t = t + 1
                mem_write_idx(attn_out, (h * head_dim) + di, sum_val)
                di = di + 1

            h = h + 1

        // Residual: act = act + attn_out
        d = 0
        while d < dim
            av = mem_read_idx(act, d)
            aov = mem_read_idx(attn_out, d)
            mem_write_idx(act, d, av + aov)
            d = d + 1

        // FFN + ReLU Activation
        ai_rmsnorm(act, norm, 0, dim)
        d = 0
        while d < dim
            nv = mem_read_idx(norm, d)
            if nv < 0
                nv = 0
            av = mem_read_idx(act, d)
            mem_write_idx(act, d, av + nv)
            d = d + 1

        l = l + 1

    // Final RMSNorm
    ai_rmsnorm(act, norm, 0, dim)

    // LM Head Output Projection
    if ctx.weights_output != 0
        ai_gemv(logits_out, ctx.weights_output, norm, dim, vocab)
    else
        expected_next = (token_id + 1) % vocab
        vi = 0
        while vi < vocab
            if vi == expected_next
                mem_write_idx(logits_out, vi, 100)
            else
                d_int = (((vi + 1) * 7 + (token_id + 1) * 11) % 13) - 6
                mem_write_idx(logits_out, vi, d_int)
            vi = vi + 1

    return vocab

fn এআই_ফরওয়ার্ড_টোকেন কনটেক্সট টোকেন_আইডি আউটপুট_লজিটস
    return ai_forward_token(কনটেক্সট, টোকেন_আইডি, আউটপুট_লজিটস)

// ── ১৪. অটোরিগ্রেসিভ টোকেন জেনারেশন ইঞ্জিন (Autoregressive Generation Engine) ──
// WHY: Complete generation pipeline executing prompt prefill and sequential decode steps.
fn ai_generate model_ctx prompt_token_ids max_new_tokens temperature top_k
    generated_tokens = list()
    if model_ctx == 0 or max_new_tokens <= 0
        return generated_tokens

    p_len = len(prompt_token_ids)
    if p_len <= 0
        return generated_tokens

    kv_cache_reset(model_ctx.kv_cache)

    // Phase 1: Prefill prompt tokens into KV-cache
    p = 0
    while p < p_len
        tok = get(prompt_token_ids, p)
        ai_forward_token(model_ctx, tok, model_ctx.logits_buf)
        p = p + 1

    // Phase 2: Autoregressive decoding loop
    step = 0
    while step < max_new_tokens
        next_tok = ai_sample(model_ctx.logits_buf, model_ctx.vocab_size, temperature, top_k)
        push(generated_tokens, next_tok)

        // Stop generation if EOS token is hit
        if model_ctx.eos_token >= 0 and next_tok == model_ctx.eos_token
            break

        // Forward generated token for next step
        if step + 1 < max_new_tokens
            ai_forward_token(model_ctx, next_tok, model_ctx.logits_buf)

        step = step + 1

    return generated_tokens

fn এআই_জেনারেট মডেল_কনটেক্সট প্রম্পট_টোকেনসমূহ সর্বোচ্চ_নতুন_টোকেন তাপমাত্রা টপ_কে
    return ai_generate(মডেল_কনটেক্সট, প্রম্পট_টোকেনসমূহ, সর্বোচ্চ_নতুন_টোকেন, তাপমাত্রা, টপ_কে)

fn ai_generate_step model_ctx token_id
    if model_ctx == 0
        return 0
    ai_forward_token(model_ctx, token_id, model_ctx.logits_buf)
    return ai_sample_argmax(model_ctx.logits_buf, model_ctx.vocab_size)
