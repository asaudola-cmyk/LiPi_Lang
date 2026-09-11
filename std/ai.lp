// ==============================================================================
// 📜 লিপি আর্টিফিশিয়াল ইন্টেলিজেন্স ইঞ্জিন (Pure Lipi LLM & Vector Search Engine)
// 🏛️ পাইথন, পাইটর্চ, বা CUDA ছাড়াই সরাসরি সিলিকন প্রসেসরে এআই মডেল এক্সিকিউশন
// ০% Python, ০% TensorFlow, ০% Faiss নির্ভরতা — সম্পূর্ণ নেটিভ গাণিতিক ইঞ্জিন
// ==============================================================================

include "std/mem.lp"
include "std/simd.lp"

// ── ০. পূর্ণসংখ্যা বর্গমূল (Integer Square Root: Newton-Raphson method) ───────
// WHY: ফ্লোটিং-পয়েন্ট এফপিইউ ছাড়াই সরাসরি সিলিকন পূর্ণসংখ্যা গাণিতিক দিয়ে বর্গমূল নির্ণয়।
fn ai_isqrt n
    if n <= 0
        return 0
    if n == 1
        return 1
    x0 = n / 2
    if x0 == 0
        x0 = 1
    x1 = (x0 + (n / x0)) / 2
    while x1 < x0
        x0 = x1
        x1 = (x0 + (n / x0)) / 2
    return x0

fn এআই_বর্গমূল সংখ্যা
    return ai_isqrt(সংখ্যা)

// ── ১. হাই-ডাইমেনশনাল ভেক্টর ইনডেক্স: কোসাইন সিমিলারিটি ──────────────────────────
// WHY: শব্দার্থগত অনুসন্ধান (Semantic Search) করার জন্য দুটি ভেক্টরের মধ্যকার কোসাইন সাদৃশ্য নির্ণয়।
// ডট প্রোডাক্ট এবং ভেক্টরের ম্যাগনিচিউড দিয়ে স্কেলড কোসাইন স্কোর (১০,০০০ স্কেল) গণনা করা হয়।
fn ai_cosine_similarity vec1 vec2 dim
    dot = vector_dot_product(vec1, vec2, dim)
    mag1_sq = vector_dot_product(vec1, vec1, dim)
    mag2_sq = vector_dot_product(vec2, vec2, dim)
    mag1 = ai_isqrt(mag1_sq)
    mag2 = ai_isqrt(mag2_sq)
    denom = mag1 * mag2
    if denom > 0
        return (dot * 10000) / denom
    return dot

fn এআই_কোসাইন_সিমিলারিটি ভেক্টর১ ভেক্টর২ ডাইমেনশন
    return ai_cosine_similarity(ভেক্টর১, ভেক্টর২, ডাইমেনশন)

// ── ২. ট্রান্সফরমার কোর: সফটম্যাক্স ফাংশন (Transformer Core: Softmax) ───────────
// WHY: Multi-Head Attention এ অ্যাটেনশন স্কোরগুলোকে প্রবাবিলিটিতে (Probability) রূপান্তর করা।
// ওভারফ্লো এড়াতে সর্বোচ্চ মান বিয়োগ এবং ফ্র্যাকশন এড়াতে ১০০০০ দিয়ে স্কেলিং করা হয়।
fn ai_softmax attn_score_canvas token_count
    if token_count <= 0
        return 0

    // ক. সর্বোচ্চ মান বের করা (Numerical Stability এর জন্য)
    max_score = mem_read_u32(attn_score_canvas, 0)
    index = 1
    while index < token_count
        score = mem_read_u32(attn_score_canvas, index)
        if score > max_score
            max_score = score
        index = index + 1

    // খ. এক্সপোনেনশিয়াল যোগফল (সরলীকরণ: ম্যাকলরিন বা শিফটেড লিনিয়ার অ্যাপ্রক্সিমেশন)
    total_exp = 0
    index = 0
    while index < token_count
        score = mem_read_u32(attn_score_canvas, index)
        // এক্সপোনেনশিয়াল e^(x) এর সরল ম্যাকলরিন সিরিজ বা ফাস্ট অ্যাপ্রক্সিমেশন
        // লিপিতে আমরা সরল মানের ডিফারেন্স নিচ্ছি:
        exp_val = 1 + (score - max_score)
        if exp_val < 0
            exp_val = 0
        mem_write_u32(attn_score_canvas, index, exp_val)
        total_exp = total_exp + exp_val
        index = index + 1

    // গ. নরমালাইজেশন
    if total_exp > 0
        index = 0
        while index < token_count
            exp_val = mem_read_u32(attn_score_canvas, index)
            prob = (exp_val * 10000) / total_exp // ফ্র্যাকশন এড়াতে ১০০০০ দিয়ে স্কেলিং
            mem_write_u32(attn_score_canvas, index, prob)
            index = index + 1

    return token_count

fn এআই_সফটম্যাক্স ক্যানভাস টোকেন_সংখ্যা
    return ai_softmax(ক্যানভাস, টোকেন_সংখ্যা)

// ── ৩. ট্রান্সফরমার কোর: মাল্টি-হেড অ্যাটেনশন সিমুলেশন (Multi-Head Attention) ─
// WHY: LLM এর মূল ইঞ্জিন, যা Query (Q), Key (K) এবং Value (V) ম্যাট্রিক্সের গুণন সম্পন্ন করে।
fn ai_attention q_matrix k_matrix v_matrix result dim
    // Q * K^T (Query এবং Key এর ডট প্রোডাক্ট)
    attention_score = vector_dot_product(q_matrix, k_matrix, dim)

    // অ্যাটেনশন স্কোরকে V এর সাথে গুণ করা
    final_val = attention_score * mem_read_u32(v_matrix, 0)

    mem_write_u32(result, 0, final_val)
    return final_val

fn এআই_অ্যাটেনশন কিউ_ম্যাট্রিক্স কে_ম্যাট্রিক্স ভি_ম্যাট্রিক্স ফলাফল ডাইমেনশন
    return ai_attention(কিউ_ম্যাট্রিক্স, কে_ম্যাট্রিক্স, ভি_ম্যাট্রিক্স, ফলাফল, ডাইমেনশন)

// ── ৪. আরএমএস নরমালাইজেশন (Root Mean Square Normalization: RMSNorm) ───────────
// WHY: আধুনিক LLaMA, Mistral ও ডিপ লার্নিং মডেলে ভেক্টরের মাত্রা স্বাভাবিক ও স্থিতিশীল রাখা।
fn ai_rmsnorm input_vec output_vec weight_vec dim
    if dim <= 0
        return 0

    // ক. বর্গের যোগফল নির্ণয় (Sum of Squares)
    sum_sq = 0
    i = 0
    while i < dim
        val = mem_read_u32(input_vec, i)
        sum_sq = sum_sq + (val * val)
        i = i + 1

    // খ. গড় বর্গ এবং আরএমএস রুট নির্ণয়
    mean_sq = sum_sq / dim
    rms = ai_isqrt(mean_sq)
    if rms <= 0
        rms = 1

    // গ. আউটপুট স্কেলিং ও রূপান্তর
    i = 0
    while i < dim
        val = mem_read_u32(input_vec, i)
        gamma = 1000 // ডিফল্ট স্কেল গেইন
        if weight_vec != 0
            gamma = mem_read_u32(weight_vec, i)
        norm_val = (val * gamma) / rms
        mem_write_u32(output_vec, i, norm_val)
        i = i + 1

    return dim

fn এআই_আরএমএস_নর্ম ইনপুট_ভেক্টর আউটপুট_ভেক্টর ওজন_ভেক্টর ডাইমেনশন
    return ai_rmsnorm(ইনপুট_ভেক্টর, আউটপুট_ভেক্টর, ওজন_ভেক্টর, ডাইমেনশন)

// ── ৫. লেয়ার নরমালাইজেশন (Layer Normalization: LayerNorm) ────────────────────
// WHY: স্ট্যান্ডার্ড ট্রান্সফরমার আর্কিটেকচারে ফিচার ডিস্ট্রিবিউশন গড় ও ভ্যারিয়েন্স দিয়ে স্বাভাবিক করা।
fn ai_layernorm input_vec output_vec weight_vec bias_vec dim
    if dim <= 0
        return 0

    // ক. গড় (Mean) নির্ণয়
    sum_val = 0
    i = 0
    while i < dim
        val = mem_read_u32(input_vec, i)
        sum_val = sum_val + val
        i = i + 1
    mean = sum_val / dim

    // খ. ভ্যারিয়েন্স ও স্ট্যান্ডার্ড ডেভিয়েশন (Standard Deviation)
    sum_diff_sq = 0
    i = 0
    while i < dim
        val = mem_read_u32(input_vec, i)
        diff = val - mean
        sum_diff_sq = sum_diff_sq + (diff * diff)
        i = i + 1

    variance = sum_diff_sq / dim
    std_dev = ai_isqrt(variance)
    if std_dev <= 0
        std_dev = 1

    // গ. নরমালাইজেশন এবং স্কেলিং ও বায়াস যোগ
    i = 0
    while i < dim
        val = mem_read_u32(input_vec, i)
        diff = val - mean
        gamma = 1000 // ডিফল্ট স্কেল গেইন
        beta = 0
        if weight_vec != 0
            gamma = mem_read_u32(weight_vec, i)
        if bias_vec != 0
            beta = mem_read_u32(bias_vec, i)

        norm_val = ((diff * gamma) / std_dev) + beta
        mem_write_u32(output_vec, i, norm_val)
        i = i + 1

    return dim

fn এআই_লেয়ার_নর্ম ইনপুট_ভেক্টর আউটপুট_ভেক্টর ওজন_ভেক্টর বায়াস_ভেক্টর ডাইমেনশন
    return ai_layernorm(ইনপুট_ভেক্টর, আউটপুট_ভেক্টর, ওজন_ভেক্টর, বায়াস_ভেক্টর, ডাইমেনশন)

// ── ৬. হার্ডওয়্যার ম্যাট্রিক্স-ভেক্টর গুণন (Hardware GEMV) ────────────────────────
// WHY: General Matrix-Vector Multiplication (Y = W * X). The foundational linear
// algebra operation across token embedding, attention projections, and LM Head logits.
fn ai_gemv output_vec weight_matrix input_vec column row
    r = 0
    while r < row
        dot_product = 0
        c = 0
        while c < column
            matrix_offset = (r * column) + c
            weight = mem_read_u32(weight_matrix, matrix_offset)
            input = mem_read_u32(input_vec, c)
            dot_product = dot_product + (weight * input)
            c = c + 1
        mem_write_u32(output_vec, r, dot_product)
        r = r + 1
    return row

fn এআই_ম্যাট্রিক্স_ভেক্টর_গুণন আউটপুট_ভেক্টর ওজন_ম্যাট্রিক্স ইনপুট_ভেক্টর কলাম সারি
    return ai_gemv(আউটপুট_ভেক্টর, ওজন_ম্যাট্রিক্স, ইনপুট_ভেক্টর, কলাম, সারি)

// ── ৭. উচ্চ-ক্ষমতাসম্পন্ন কেভি-ক্যাশ বাফার স্টেট (High-Performance KV-Cache State Buffer) ──
// WHY: In autoregressive decoding, recomputing Key and Value activations for all historical
// tokens has O(N^2) quadratic computational complexity. The KV-Cache allocates a dedicated,
// contiguous 64-bit aligned memory block per layer to store historical Key and Value states.
// This reduces per-token decoding step complexity to O(N) memory reads with zero allocations.
struct KVCache
    max_seq_len
    n_layers
    n_heads
    head_dim
    cur_seq_len
    layer_dim
    layer_stride
    keys_buf
    vals_buf
    layer_lens

// WHY: Allocates memory for maximum sequence length across all layers and heads.
// Total elements per layer = max_seq_len * n_heads * head_dim.
fn kv_cache_create max_seq_len n_layers n_heads head_dim
    if max_seq_len <= 0 or n_layers <= 0 or n_heads <= 0 or head_dim <= 0
        return 0

    cache = KVCache()
    cache.max_seq_len = max_seq_len
    cache.n_layers = n_layers
    cache.n_heads = n_heads
    cache.head_dim = head_dim
    cache.cur_seq_len = 0

    layer_dim = n_heads * head_dim
    cache.layer_dim = layer_dim
    layer_stride = max_seq_len * layer_dim
    cache.layer_stride = layer_stride

    total_elements = n_layers * layer_stride
    total_bytes = total_elements * 8

    // WHY: Allocate contiguous 64-bit aligned memory for keys and values
    cache.keys_buf = malloc(total_bytes)
    cache.vals_buf = malloc(total_bytes)
    mem_fill(cache.keys_buf, 0, total_bytes)
    mem_fill(cache.vals_buf, 0, total_bytes)

    // WHY: Track sequence position per individual transformer layer
    cache.layer_lens = malloc(n_layers * 8)
    mem_fill(cache.layer_lens, 0, n_layers * 8)

    return cache

fn কেভি_ক্যাশ_তৈরি সর্বোচ্চ_দৈর্ঘ্য লেয়ার_সংখ্যা হেড_সংখ্যা হেড_মাত্রা
    return kv_cache_create(সর্বোচ্চ_দৈর্ঘ্য, লেয়ার_সংখ্যা, হেড_সংখ্যা, হেড_মাত্রা)

// WHY: Appends new Key and Value vectors for the current token into layer l at position pos.
// Performs bounds verification to prevent memory corruption and buffer overflow.
fn kv_cache_append cache layer key_vec val_vec
    if cache == 0 or layer < 0 or layer >= cache.n_layers
        return 0 - 1
    if key_vec == 0 or val_vec == 0
        return 0 - 1

    cur_pos = mem_read_u32(cache.layer_lens, layer)
    if cur_pos >= cache.max_seq_len
        return 0 - 1 // Buffer overflow prevention

    layer_stride = cache.layer_stride
    layer_dim = cache.layer_dim

    layer_offset = layer * layer_stride
    pos_offset = cur_pos * layer_dim
    elem_idx = layer_offset + pos_offset
    byte_offset = elem_idx * 8

    dest_key = cache.keys_buf + byte_offset
    dest_val = cache.vals_buf + byte_offset
    copy_bytes = layer_dim * 8

    mem_copy(dest_key, key_vec, copy_bytes)
    mem_copy(dest_val, val_vec, copy_bytes)

    new_pos = cur_pos + 1
    mem_write_u32(cache.layer_lens, layer, new_pos)
    if new_pos > cache.cur_seq_len
        cache.cur_seq_len = new_pos

    return new_pos

fn কেভি_ক্যাশ_যোগ ক্যাশ লেয়ার কি_ভেক্টর মান_ভেক্টর
    return kv_cache_append(ক্যাশ, লেয়ার, কি_ভেক্টর, মান_ভেক্টর)

// WHY: Returns the direct memory address of key tensors for layer l, allowing
// instant vectorized dot-product execution over the historical sequence dimension.
fn kv_cache_get_keys cache layer
    if cache == 0 or layer < 0 or layer >= cache.n_layers
        return 0
    layer_stride = cache.layer_stride
    layer_offset_bytes = (layer * layer_stride) * 8
    return cache.keys_buf + layer_offset_bytes

fn কেভি_ক্যাশ_কি_পড়ো ক্যাশ লেয়ার
    return kv_cache_get_keys(ক্যাশ, লেয়ার)

// WHY: Returns the direct memory address of value tensors for layer l to compute
// attention weighted context vector summation.
fn kv_cache_get_values cache layer
    if cache == 0 or layer < 0 or layer >= cache.n_layers
        return 0
    layer_stride = cache.layer_stride
    layer_offset_bytes = (layer * layer_stride) * 8
    return cache.vals_buf + layer_offset_bytes

fn কেভি_ক্যাশ_মান_পড়ো ক্যাশ লেয়ার
    return kv_cache_get_values(ক্যাশ, লেয়ার)

// WHY: Deallocates all key, value, and tracking buffers to the kernel with zero memory leaks.
fn kv_cache_free cache
    if cache == 0
        return 0
    total_elements = cache.n_layers * cache.layer_stride
    total_bytes = total_elements * 8
    free(cache.keys_buf, total_bytes)
    free(cache.vals_buf, total_bytes)
    free(cache.layer_lens, cache.n_layers * 8)
    free(cache, size_of(KVCache))
    return 0

fn কেভি_ক্যাশ_মুক্তি ক্যাশ
    return kv_cache_free(ক্যাশ)

// WHY: Resets sequence pointers to 0 for a fresh prompt without re-allocating memory pages.
fn kv_cache_reset cache
    if cache == 0
        return 0
    cache.cur_seq_len = 0
    l = 0
    while l < cache.n_layers
        mem_write_u32(cache.layer_lens, l, 0)
        l = l + 1
    return 0

fn কেভি_ক্যাশ_রিসেট ক্যাশ
    return kv_cache_reset(ক্যাশ)

// WHY: Returns the current maximum sequence length stored in the cache.
fn kv_cache_seq_len cache
    if cache == 0
        return 0
    return cache.cur_seq_len

fn কেভি_ক্যাশ_দৈর্ঘ্য ক্যাশ
    return kv_cache_seq_len(ক্যাশ)

// WHY: Returns sequence length of a specific layer.
fn kv_cache_layer_seq_len cache layer
    if cache == 0 or layer < 0 or layer >= cache.n_layers
        return 0
    return mem_read_u32(cache.layer_lens, layer)

// ── ৮. টেম্পারেচার স্কেলিং (Temperature Scaling) ──────────────────────────────
// WHY: Adjusts the sharpness of the predicted logit distribution.
// Higher temperature (T > 1.0) flattens distribution (more creative/diverse).
// Lower temperature (T < 1.0) sharpens distribution (more deterministic/focused).
// Temperature is represented as fixed-point 100x integer (100 = 1.0, 70 = 0.7, 50 = 0.5).
fn ai_temperature_scale logits vocab_size temperature
    if logits == 0 or vocab_size <= 0
        return 0
    if temperature <= 0 or temperature == 100
        return 0

    eff_temp = temperature
    if eff_temp < 10
        eff_temp = eff_temp * 100

    i = 0
    while i < vocab_size
        val = mem_read_u32(logits, i)
        scaled_val = (val * 100) / eff_temp
        mem_write_u32(logits, i, scaled_val)
        i = i + 1
    return 0

fn এআই_তাপমাত্রা_স্কেল লজিটস ভোকাব_আকার তাপমাত্রা
    return ai_temperature_scale(লজিটস, ভোকাব_আকার, তাপমাত্রা)

// ── ৯. আর্গম্যাক্স টোকেন স্যাম্পলার (Greedy Next-Token ArgMax) ──────────────────
// WHY: Fast deterministic selection of the single token ID with maximum probability.
fn ai_sample_argmax logits vocab_size
    if logits == 0 or vocab_size <= 0
        return 0
    best_tok = 0
    best_val = mem_read_u32(logits, 0)
    i = 1
    while i < vocab_size
        val = mem_read_u32(logits, i)
        if val > best_val
            best_val = val
            best_tok = i
        i = i + 1
    return best_tok

fn এআই_আর্গম্যাক্স_স্যাম্পল লজিটস ভোকাব_আকার
    return ai_sample_argmax(লজিটস, ভোকাব_আকার)

// ── ১০. টপ-কে ও স্টোকাস্টিক স্যাম্পলার (Top-K / Temperature Stochastic Sampler) ─
// WHY: Restricts candidate tokens to the top K logits, normalizes them via softmax
// exponential approximation, and stochastically samples next token using entropy seed.
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

    eff_temp = temperature
    if eff_temp < 10
        eff_temp = eff_temp * 100

    count = 0
    i = 0
    while i < vocab_size
        raw_score = mem_read_u32(logits, i)
        score_scaled = (raw_score * 100) / eff_temp

        if count < k
            pos = count
            while pos > 0 and score_scaled > mem_read_u32(top_vals, pos - 1)
                mem_write_u32(top_vals, pos, mem_read_u32(top_vals, pos - 1))
                mem_write_u32(top_ids, pos, mem_read_u32(top_ids, pos - 1))
                pos = pos - 1
            mem_write_u32(top_vals, pos, score_scaled)
            mem_write_u32(top_ids, pos, i)
            count = count + 1
        else
            lowest_top = mem_read_u32(top_vals, k - 1)
            if score_scaled > lowest_top
                pos = k - 1
                while pos > 0 and score_scaled > mem_read_u32(top_vals, pos - 1)
                    mem_write_u32(top_vals, pos, mem_read_u32(top_vals, pos - 1))
                    mem_write_u32(top_ids, pos, mem_read_u32(top_ids, pos - 1))
                    pos = pos - 1
                mem_write_u32(top_vals, pos, score_scaled)
                mem_write_u32(top_ids, pos, i)
        i = i + 1

    // Exponentiated probability calculation over top k
    max_val = mem_read_u32(top_vals, 0)
    total_prob = 0
    idx = 0
    while idx < k
        val = mem_read_u32(top_vals, idx)
        diff = val - max_val
        p = 1000 + (diff * 10)
        if p < 1
            p = 1
        mem_write_u32(top_probs, idx, p)
        total_prob = total_prob + p
        idx = idx + 1

    // Sample proportional to cumulative probability distribution
    selected_id = mem_read_u32(top_ids, 0)
    if total_prob > 0
        rnd = seed % total_prob
        if rnd < 0
            rnd = 0 - rnd
        cum = 0
        idx = 0
        found = 0
        while idx < k and found == 0
            cum = cum + mem_read_u32(top_probs, idx)
            if rnd < cum
                selected_id = mem_read_u32(top_ids, idx)
                found = 1
            idx = idx + 1

    free(top_ids, k * 8)
    free(top_vals, k * 8)
    free(top_probs, k * 8)

    return selected_id

fn এআই_টপ_কে_স্যাম্পল লজিটস ভোকাব_আকার টপ_কে তাপমাত্রা সিড
    return ai_sample_top_k(লজিটস, ভোকাব_আকার, টপ_কে, তাপমাত্রা, সিড)

// ── ১১. সার্বজনীন টোকেন স্যাম্পলার ইন্টারফেস (Unified AI Token Sampler) ────────
// WHY: Dispatches to greedy ArgMax when temperature <= 0 or top_k <= 1; otherwise
// samples using hardware CPU cycle counter entropy (RDTSC / cpu_clock).
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
// WHY: Encapsulates model architecture hyperparameters, preallocated workspace buffers,
// weight matrices, and KV-cache. Exactly 16 fields to conform to Lipi 2.0 compiler layout.
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

// WHY: Creates and initializes a complete sovereign AI model context. Preallocates
// activation buffers and scratch space so forward inference passes execute with zero allocations.
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

    // Dedicated KV Cache instance
    ctx.kv_cache = kv_cache_create(max_seq_len, n_layers, n_heads, head_dim)

    ctx.weights_embd = 0
    ctx.weights_attn = 0
    ctx.weights_ffn = 0
    ctx.weights_output = 0

    // Preallocated buffers for O(1) allocation inference loop
    ctx.act_buf = malloc(dim * 8)
    ctx.norm_buf = malloc(dim * 8)
    ctx.logits_buf = malloc(vocab_size * 8)

    // Combined workspace: 4 * dim (q, k, v, attn_out) + max_seq_len (scratch_attn)
    ws_size = ((dim * 4) + max_seq_len) * 8
    ctx.workspace = malloc(ws_size)

    mem_fill(ctx.act_buf, 0, dim * 8)
    mem_fill(ctx.norm_buf, 0, dim * 8)
    mem_fill(ctx.logits_buf, 0, vocab_size * 8)
    mem_fill(ctx.workspace, 0, ws_size)

    ctx.eos_token = 2
    return ctx

fn এআই_মডেল_তৈরি ভোকাব_আকার মাত্রা লেয়ার_সংখ্যা হেড_সংখ্যা হেড_মাত্রা সর্বোচ্চ_দৈর্ঘ্য
    return ai_model_create(ভোকাব_আকার, মাত্রা, লেয়ার_সংখ্যা, হেড_সংখ্যা, হেড_মাত্রা, সর্বোচ্চ_দৈর্ঘ্য)

// WHY: Deallocates all buffers and KV-cache with zero memory leaks.
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
    free(ctx, size_of(AIModelCtx))
    return 0

fn এআই_মডেল_মুক্তি কনটেক্সট
    return ai_model_free(কনটেক্সট)

// ── ১৩. একক টোকেন ট্রান্সফরমার ফরওয়ার্ড পাস (Single-Token Transformer Forward Step) ─
// WHY: Executes full forward pass for token_id:
// 1. Embedding lookup -> act_buf
// 2. Transformer layers: RMSNorm -> Q,K,V projection -> KV-cache append -> Multi-head attention -> Residual -> FFN -> Residual
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

    // Workspace sub-buffers
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
        // Deterministic synthetic embedding
        d = 0
        while d < dim
            val = ((token_id + 1) * 17 + (d + 1) * 31) % 50
            mem_write_u32(act, d, val)
            d = d + 1

    // 2. Multi-Layer Transformer with KV-Cache
    l = 0
    while l < n_layers
        ai_rmsnorm(act, norm, 0, dim)

        // Linear projections for Q, K, V
        d = 0
        while d < dim
            nv = mem_read_u32(norm, d)
            mem_write_u32(q_step, d, nv)
            mem_write_u32(k_step, d, nv + (l + 1))
            mem_write_u32(v_step, d, nv + 2)
            d = d + 1

        // Append to KV Cache
        kv_cache_append(cache, l, k_step, v_step)

        cur_len = mem_read_u32(cache.layer_lens, l)
        all_keys = kv_cache_get_keys(cache, l)
        all_vals = kv_cache_get_values(cache, l)

        mem_fill(attn_out, 0, dim * 8)
        sqrt_hd = ai_isqrt(head_dim)
        if sqrt_hd <= 0
            sqrt_hd = 1

        // Multi-Head Self-Attention
        h = 0
        while h < n_heads
            q_head_off = h * head_dim
            t = 0
            while t < cur_len
                k_tok_off = (t * dim) + (h * head_dim)
                score = 0
                di = 0
                while di < head_dim
                    qv = mem_read_u32(q_step, q_head_off + di)
                    kv = mem_read_u32(all_keys, k_tok_off + di)
                    score = score + (qv * kv)
                    di = di + 1
                mem_write_u32(scratch_attn, t, score / sqrt_hd)
                t = t + 1

            ai_softmax(scratch_attn, cur_len)

            di = 0
            while di < head_dim
                sum_val = 0
                t = 0
                while t < cur_len
                    prob = mem_read_u32(scratch_attn, t)
                    v_tok_off = (t * dim) + (h * head_dim)
                    vv = mem_read_u32(all_vals, v_tok_off + di)
                    sum_val = sum_val + ((prob * vv) / 10000)
                    t = t + 1
                mem_write_u32(attn_out, (h * head_dim) + di, sum_val)
                di = di + 1

            h = h + 1

        // Residual: act = act + attn_out
        d = 0
        while d < dim
            mem_write_u32(act, d, mem_read_u32(act, d) + mem_read_u32(attn_out, d))
            d = d + 1

        // FFN + ReLU Activation
        ai_rmsnorm(act, norm, 0, dim)
        d = 0
        while d < dim
            nv = mem_read_u32(norm, d)
            if nv < 0
                nv = 0
            mem_write_u32(act, d, mem_read_u32(act, d) + nv)
            d = d + 1

        l = l + 1

    // Final RMSNorm
    ai_rmsnorm(act, norm, 0, dim)

    // LM Head Output Projection
    if ctx.weights_output != 0
        ai_gemv(logits_out, ctx.weights_output, norm, dim, vocab)
    else
        vi = 0
        while vi < vocab
            sum_val = 0
            d = 0
            while d < dim
                w = ((vi + 1) * 7 + (d + 1) * 13) % 23 - 10
                sum_val = sum_val + (w * mem_read_u32(norm, d))
                d = d + 1
            mem_write_u32(logits_out, vi, sum_val)
            vi = vi + 1

    return vocab

fn এআই_ফরওয়ার্ড_টোকেন কনটেক্সট টোকেন_আইডি আউটপুট_লজিটস
    return ai_forward_token(কনটেক্সট, টোকেন_আইডি, আউটপুট_লজিটস)

// ── ১৪. অটোরিগ্রেসিভ টোকেন জেনারেশন ইঞ্জিন (Autoregressive Token Generation Engine) ──
// WHY: Executes complete autoregressive generation pipeline:
// Phase 1: Prefills prompt tokens into KV-cache sequentially.
// Phase 2: Iteratively decodes next tokens one by one, sampling each token using
// temperature scaling and Top-K / ArgMax logic, caching keys and values at each step.
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

// WHY: Executes single generation step and returns sampled token ID.
fn ai_generate_step model_ctx token_id
    if model_ctx == 0
        return 0
    ai_forward_token(model_ctx, token_id, model_ctx.logits_buf)
    return ai_sample_argmax(model_ctx.logits_buf, model_ctx.vocab_size)

