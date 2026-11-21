// ==============================================================================
// 👑 LIPI NATIVE GGUF & AI TENSOR INFERENCE ENGINE (std/gguf.lp)
// ⚡ Zero Python | Zero PyTorch | Direct Silicon GEMV & Quantized LLM Tensor Math
// ==============================================================================

// WHY: To achieve total AI sovereignty, a language must not depend on the Python/C++
// runtime stack (PyTorch, llama.cpp, etc.). std/gguf.lp provides binary parsing of
// GGUF model headers, Q4_0/Q8_0 tensor unpackers, and hardware vector-matrix multiplication.

include "utso/memory.lp"
include "aati/lipi_ai/tensor_engine.lp"
include "utso/cpu/avx512_native.lp"

// ── ১. GGUF ফরম্যাট কনস্ট্যান্টস ──────────────────────────────────────────────
// Magic: 'G' (0x47), 'G' (0x47), 'U' (0x55), 'F' (0x46) -> 0x46554747 (1179993927 little-endian)
GGUF_MAGIC = 1179993927
GGUF_VERSION_3 = 3
জিজিইউএফ_ম্যাজিক = 1179993927
জিজিইউএফ_ভার্সন_৩ = 3
জিজিইউএফ_ভার্সন_3 = 3

// ── ২. GGUF বাইনারি হেডার ও ম্যাজিক যাচাই ─────────────────────────────────────
// WHY: Signed 32-bit integer decoding prevents unsigned 2^31 wraparound on weights/logits.
fn gguf_read_i32 buf offset
    v = mem_read_u32(buf, offset) & 4294967295
    if v >= 2147483648
        return v - 4294967296
    return v

// WHY: Accurate IEEE-754 binary16 (FP16) to binary64 conversion for GGML block scales.
fn gguf_f16_to_f64 bits
    b = bits & 65535
    sign = (b >> 15) & 1
    exp16 = (b >> 10) & 31
    mant16 = b & 1023
    f_bits = 0
    if exp16 == 0
        if mant16 == 0
            f_bits = sign << 63
        else
            sub = mant16
            e = 0 - 14
            while (sub & 1024) == 0
                sub = sub << 1
                e = e - 1
            sub = sub & 1023
            exp64 = e + 1023
            f_bits = (sign << 63) | (exp64 << 52) | (sub << 42)
    elif exp16 == 31
        f_bits = (sign << 63) | (2047 << 52) | (mant16 << 42)
    else
        exp64 = (exp16 - 15) + 1023
        f_bits = (sign << 63) | (exp64 << 52) | (mant16 << 42)
    return f_bits

fn _gguf_f64_mul_bits a_bits b_bits
    return _gguf_fmul_typed(a_bits, b_bits)

fn _gguf_fmul_typed a:f64 b:f64 -> f64
    return a * b

fn _gguf_i_to_f64 v:i64 -> f64
    return v + 0.0

// WHY: Dequantizes a standard 18-byte GGML Q4_0 block (2B FP16 scale + 16B nibbles = 32 f64s).
fn gguf_dequant_q4_0_block block_addr out_f64_addr
    if block_addr == 0 or out_f64_addr == 0
        return 0
    b0 = mem_byte_read(block_addr, 0) & 255
    b1 = mem_byte_read(block_addr, 1) & 255
    d_bits = gguf_f16_to_f64(b0 | (b1 << 8))
    i = 0
    while i < 16
        byte = mem_byte_read(block_addr, 2 + i) & 255
        q0 = (byte & 15) - 8
        q1 = ((byte >> 4) & 15) - 8
        w0 = _gguf_fmul_typed(_gguf_i_to_f64(q0), d_bits)
        w1 = _gguf_fmul_typed(_gguf_i_to_f64(q1), d_bits)
        sys_poke(out_f64_addr + (i * 8), w0)
        sys_poke(out_f64_addr + ((i + 16) * 8), w1)
        i = i + 1
    return 32

// WHY: Dequantizes a standard 34-byte GGML Q8_0 block (2B FP16 scale + 32 x int8 = 32 f64s).
fn gguf_dequant_q8_0_block block_addr out_f64_addr
    if block_addr == 0 or out_f64_addr == 0
        return 0
    b0 = mem_byte_read(block_addr, 0) & 255
    b1 = mem_byte_read(block_addr, 1) & 255
    d_bits = gguf_f16_to_f64(b0 | (b1 << 8))
    i = 0
    while i < 32
        qv = mem_byte_read(block_addr, 2 + i) & 255
        if qv >= 128 qv = qv - 256
        wv = _gguf_fmul_typed(_gguf_i_to_f64(qv), d_bits)
        sys_poke(out_f64_addr + (i * 8), wv)
        i = i + 1
    return 32

fn _gguf_read_u64_le buf off
    res = 0
    bi = 0
    while bi < 8
        res = res | ((mem_byte_read(buf, off + bi) & 255) << (bi * 8))
        bi = bi + 1
    return res

fn _gguf_read_string buf pos_box limit
    p = get(pos_box, 0)
    if p + 8 > limit return ""
    slen = _gguf_read_u64_le(buf, p)
    p = p + 8
    if slen < 0 or p + slen > limit
        list_set(pos_box, 0, limit)
        return ""
    s = ""
    i = 0
    while i < slen
        s = s + chr(mem_byte_read(buf, p + i) & 255)
        i = i + 1
    list_set(pos_box, 0, p + slen)
    return s

fn _gguf_skip_value buf pos_box vtype limit depth
    if depth > 8 return 0
    p = get(pos_box, 0)
    if vtype == 0 or vtype == 1 or vtype == 7
        list_set(pos_box, 0, p + 1)
    elif vtype == 2 or vtype == 3
        list_set(pos_box, 0, p + 2)
    elif vtype == 4 or vtype == 5 or vtype == 6
        list_set(pos_box, 0, p + 4)
    elif vtype == 10 or vtype == 11 or vtype == 12
        list_set(pos_box, 0, p + 8)
    elif vtype == 8
        _gguf_read_string(buf, pos_box, limit)
    elif vtype == 9
        if p + 12 > limit
            list_set(pos_box, 0, limit)
            return 0
        elem_t = mem_read_u32(buf, p) & 4294967295
        cnt = _gguf_read_u64_le(buf, p + 4)
        list_set(pos_box, 0, p + 12)
        ai = 0
        while ai < cnt and get(pos_box, 0) < limit
            _gguf_skip_value(buf, pos_box, elem_t, limit, depth + 1)
            ai = ai + 1
    else
        list_set(pos_box, 0, limit)
    return 1

// WHY: Full GGUF v2/v3 metadata & tensor info directory parser with aligned data offset.
fn gguf_parse_buffer buf buf_len
    if buf == 0 or buf_len < 24
        return { ok: 0, version: 0, tensor_count: 0, kv_count: 0, alignment: 32, data_offset: 0, metadata: list(), tensors: list() }
    if gguf_magic_verify(buf) == 0
        return { ok: 0, version: 0, tensor_count: 0, kv_count: 0, alignment: 32, data_offset: 0, metadata: list(), tensors: list() }
    ver = gguf_version(buf)
    if ver < 2 or ver > 3
        return { ok: 0, version: ver, tensor_count: 0, kv_count: 0, alignment: 32, data_offset: 0, metadata: list(), tensors: list() }
    t_count = gguf_tensor_count(buf)
    kv_count = gguf_metadata_kv_count(buf)
    pos_box = [24]
    meta = list()
    alignment = 32
    ki = 0
    while ki < kv_count and get(pos_box, 0) < buf_len
        k = _gguf_read_string(buf, pos_box, buf_len)
        vp = get(pos_box, 0)
        if vp + 4 > buf_len break
        vt = mem_read_u32(buf, vp) & 4294967295
        list_set(pos_box, 0, vp + 4)
        if vt == 4 and k == "general.alignment" and vp + 8 <= buf_len
            alignment = mem_read_u32(buf, vp + 4) & 4294967295
            if alignment <= 0 alignment = 32
            list_set(pos_box, 0, vp + 8)
            push(meta, { key: k, vtype: vt, val: alignment })
        elif vt == 8
            sv = _gguf_read_string(buf, pos_box, buf_len)
            push(meta, { key: k, vtype: vt, val: sv })
        elif vt == 4 or vt == 5
            if vp + 8 <= buf_len
                iv = mem_read_u32(buf, vp + 4) & 4294967295
                if vt == 5 and iv >= 2147483648 iv = iv - 4294967296
                list_set(pos_box, 0, vp + 8)
                push(meta, { key: k, vtype: vt, val: iv })
        else
            _gguf_skip_value(buf, pos_box, vt, buf_len, 0)
            push(meta, { key: k, vtype: vt, val: 0 })
        ki = ki + 1

    tensors = list()
    ti = 0
    while ti < t_count and get(pos_box, 0) < buf_len
        t_name = _gguf_read_string(buf, pos_box, buf_len)
        tp = get(pos_box, 0)
        if tp + 4 > buf_len break
        n_dims = mem_read_u32(buf, tp) & 4294967295
        tp = tp + 4
        dims = list()
        di = 0
        while di < n_dims and tp + 8 <= buf_len
            push(dims, _gguf_read_u64_le(buf, tp))
            tp = tp + 8
            di = di + 1
        if tp + 12 > buf_len break
        ggml_type = mem_read_u32(buf, tp) & 4294967295
        t_off = _gguf_read_u64_le(buf, tp + 4)
        list_set(pos_box, 0, tp + 12)
        push(tensors, { name: t_name, n_dims: n_dims, dims: dims, ggml_type: ggml_type, offset: t_off })
        ti = ti + 1

    raw_end = get(pos_box, 0)
    rem = raw_end % alignment
    data_off = raw_end
    if rem != 0
        data_off = raw_end + (alignment - rem)
    return { ok: 1, version: ver, tensor_count: t_count, kv_count: kv_count, alignment: alignment, data_offset: data_off, metadata: meta, tensors: tensors }

// WHY: মডেল ফাইলের বৈধতা এবং মেটাডাটা সরাসরি বাফার থেকে যাচাই করা।
fn gguf_magic_verify header_buffer
    b0 = mem_byte_read(header_buffer, 0) // 'G' (71)
    b1 = mem_byte_read(header_buffer, 1) // 'G' (71)
    b2 = mem_byte_read(header_buffer, 2) // 'U' (85)
    b3 = mem_byte_read(header_buffer, 3) // 'F' (70)

    if b0 != 71
        return 0
    if b1 != 71
        return 0
    if b2 != 85
        return 0
    if b3 != 70
        return 0

    return 1

// ── ৩. GGUF ভার্সন এক্সট্রাকশন ────────────────────────────────────────────────
// WHY: GGUF ফাইলের সংস্করণ নম্বর (Offset 4, 32-bit integer) পড়া।
fn gguf_version header_buffer
    v0 = mem_byte_read(header_buffer, 4)
    v1 = mem_byte_read(header_buffer, 5)
    v2 = mem_byte_read(header_buffer, 6)
    v3 = mem_byte_read(header_buffer, 7)
    version = v0 + (v1 * 256) + (v2 * 65536) + (v3 * 16777216)
    return version

// ── ৪. GGUF টেনসর ও মেটাডাটা কাউন্ট ──────────────────────────────────────────
// WHY: মডেলের মোট টেনসর সংখ্যা (Offset 8, 64-bit integer) ও কেভি পেয়ার সংখ্যা লোড করা।
fn gguf_tensor_count header_buffer
    if header_buffer == 0
        return 0
    tensor_count = mem_read_idx(header_buffer, 1) // QWORD 1 (Offset 8)
    return tensor_count

fn gguf_metadata_kv_count header_buffer
    if header_buffer == 0
        return 0
    kv_count = mem_read_idx(header_buffer, 2) // QWORD 2 (Offset 16)
    return kv_count

// ── ৫. GGUF হেডার সার্বিক যাচাই ────────────────────────────────────────────────
// WHY: সিগনেচার যাচাইপূর্বক টেনসর সংখ্যা রিটার্ন করে, ভুল হেডারে ০ প্রদান করে।
fn gguf_header_verify header_buffer
    is_valid = gguf_magic_verify(header_buffer)
    if is_valid == 0
        return 0
    return gguf_tensor_count(header_buffer)

// ── ৬. Q4_0 কোয়ান্টাইজড ওয়েটস আনপ্যাকিং ও ডিকোয়ান্টাইজেশন ───────────────────────
// WHY: 4-bit weights pack 2 numbers per byte (low nibble, high nibble).
// This function unpacks the nibbles into full integers scaled by a scaling factor.
fn gguf_q4_unpack packed_addr unpacked_addr byte_count scale
    index = 0
    out_index = 0

    while index < byte_count
        byte = mem_byte_read(packed_addr, index)

        // Low 4-bit nibble ও High 4-bit nibble এক্সট্রাকশন
        high_nibble = byte / 16
        low_nibble = byte - (high_nibble * 16)

        // সিমেট্রিক ৪-বিট স্কেলিং (-8 to +7 offset)
        val_low = (low_nibble - 8) * scale
        val_high = (high_nibble - 8) * scale

        mem_write_u32(unpacked_addr, out_index * 4, val_low)
        mem_write_u32(unpacked_addr, (out_index + 1) * 4, val_high)

        out_index = out_index + 2
        index = index + 1

    return out_index

// ── ৭. Q8_0 কোয়ান্টাইজড ওয়েটস আনপ্যাকিং ও ডিকোয়ান্টাইজেশন ───────────────────────
// WHY: 8-bit quantized weights pack signed int8 values (-128 to 127).
// Unpacks signed bytes into scaled 64-bit integer words.
fn gguf_q8_unpack packed_addr unpacked_addr byte_count scale
    index = 0
    out_index = 0

    while index < byte_count
        byte = mem_byte_read(packed_addr, index)

        // আনসাইন্ড বাইট (0-255) থেকে সাইন্ড int8 (-128 to 127) এ রূপান্তর
        signed_val = byte
        if byte >= 128
            signed_val = byte - 256

        scaled_val = signed_val * scale

        mem_write_u32(unpacked_addr, out_index * 4, scaled_val)

        out_index = out_index + 1
        index = index + 1

    return out_index

// ── ৮. ম্যাট্রিক্স-ভেক্টর গুণন (GEMV: General Matrix-Vector Multiplication) ────
// WHY: The core computational bottleneck of LLM Transformer inference.
// Computes Y = W * X where W is the weight matrix and X is the token embedding vector.
fn gguf_gemv output_vec weight_matrix input_vec column row
    r = 0
    while r < row
        dot_product = 0
        c = 0

        while c < column
            matrix_offset = ((r * column) + c) * 4
            weight = gguf_read_i32(weight_matrix, matrix_offset)
            input = gguf_read_i32(input_vec, c * 4)

            dot_product = dot_product + (weight * input)
            c = c + 1

        mem_write_u32(output_vec, r * 4, dot_product)
        r = r + 1

    return row

fn gguf_matmul weight_matrix input_vec output_vec row column
    return gguf_gemv(output_vec, weight_matrix, input_vec, column, row)

// ── ৮খ. সিলিকন ত্বরান্বিত ম্যাট্রিক্স-ভেক্টর গুণন (Silicon AVX-512 Accelerated GEMV) ────
// WHY: Uses 512-bit ZMM hardware vector dot-products for 8x parallel throughput per CPU cycle.
fn gguf_gemv_silicon output_vec weight_matrix input_vec column row
    if output_vec == 0 or weight_matrix == 0 or input_vec == 0 or row <= 0 or column <= 0
        return 0

    r = 0
    while r < row
        row_offset = (r * column) * 8
        row_ptr = weight_matrix + row_offset
        dot_product = vector_dot_accelerated(row_ptr, input_vec, column)
        sys_poke(output_vec + (r * 8), dot_product)
        r = r + 1
    return row

fn জিজিইউএফ_সিলিকন_ম্যাট্রিক্স_ভেক্টর_গুণন output_vec weight_matrix input_vec column row
    return gguf_gemv_silicon(output_vec, weight_matrix, input_vec, column, row)

// ── ৮গ. হার্ডওয়্যার সিলিকন ফ্লোট ম্যাট্রিক্স-ভেক্টর গুণন (Silicon SSE2 Float GEMV) ────
// WHY: Executes 64-bit hardware floating-point GEMV using %xmm SSE2 instructions (mulsd, addsd).
fn gguf_gemv_f64 output_vec weight_matrix input_vec column row
    return ai_gemv_f64(output_vec, weight_matrix, input_vec, column, row)

fn জিজিইউএফ_সিলিকন_ফ্লোট_ম্যাট্রিক্স_ভেক্টর_গুণন output_vec weight_matrix input_vec column row
    return ai_gemv_f64(output_vec, weight_matrix, input_vec, column, row)

// ── ৯. আর্গম্যাক্স গ্রিডি টোকেন স্যাম্পলার (Greedy Next-Token ArgMax) ─────────────
// WHY: Selects the token ID with the highest computed logit probability.
fn gguf_token_argmax logit_addr vocab_size
    if vocab_size <= 0
        return 0

    highest_val = gguf_read_i32(logit_addr, 0)
    best_token = 0
    i = 1

    while i < vocab_size
        current_val = gguf_read_i32(logit_addr, i * 4)
        if current_val > highest_val
            highest_val = current_val
            best_token = i
        i = i + 1

    return best_token

// WHY: Hardware SSE2 float argmax comparator for 64-bit float logits.
fn gguf_token_argmax_f64 logit_addr vocab_size
    return ai_sample_argmax(logit_addr, vocab_size)

fn জিজিইউএফ_টোকেন_আর্গম্যাক্স_ফ্লোট logit_addr vocab_size
    return ai_sample_argmax(logit_addr, vocab_size)

// ── ১০. সার্বজনীন বাংলা ও কম্প্যাটিবিলিটি এলিয়াসসমূহ (Bilingual Aliases) ─────────
// WHY: বাংলা ও ইংরেজি উভয় ভাষায় মডেল লোডিং এবং ইনফারেন্স ফাংশন নির্বিঘ্নে কল করার সুবিধা।
fn জিজিইউএফ_ম্যাজিক_যাচাই header_buffer
    return gguf_magic_verify(header_buffer)

fn জিজিইউএফ_ম্যাজিক_verify header_buffer
    return gguf_magic_verify(header_buffer)


fn জিজিইউএফ_ভার্সন header_buffer
    return gguf_version(header_buffer)

fn জিজিইউএফ_টেনসর_সংখ্যা header_buffer
    return gguf_tensor_count(header_buffer)

fn জিজিইউএফ_টেনসর_count header_buffer
    return gguf_tensor_count(header_buffer)

fn জিজিইউএফ_টেনসর_num header_buffer
    return gguf_tensor_count(header_buffer)

fn জিজিইউএফ_মেটাডাটা_কেভি_সংখ্যা header_buffer
    return gguf_metadata_kv_count(header_buffer)

fn জিজিইউএফ_কেভি_সংখ্যা header_buffer
    return gguf_metadata_kv_count(header_buffer)

fn জিজিইউএফ_হেডার_যাচাই header_buffer
    return gguf_header_verify(header_buffer)

fn জিজিইউএফ_কিউ৪_আনপ্যাক packed_addr unpacked_addr byte_count scale
    return gguf_q4_unpack(packed_addr, unpacked_addr, byte_count, scale)

fn জিজিইউএফ_কিউ৮_আনপ্যাক packed_addr unpacked_addr byte_count scale
    return gguf_q8_unpack(packed_addr, unpacked_addr, byte_count, scale)

fn জিজিইউএফ_ম্যাট্রিক্স_ভেক্টর_গুণন আউটপুট_ভেক্টর ওজন_ম্যাট্রিক্স ইনপুট_ভেক্টর কলাম সারি
    return gguf_gemv(আউটপুট_ভেক্টর, ওজন_ম্যাট্রিক্স, ইনপুট_ভেক্টর, কলাম, সারি)

fn জিজিইউএফ_ম্যাট্রিক্স_ভেক্টর_multiply আউটপুট_ভেক্টর ওজন_ম্যাট্রিক্স ইনপুট_ভেক্টর কলাম সারি
    return gguf_gemv(আউটপুট_ভেক্টর, ওজন_ম্যাট্রিক্স, ইনপুট_ভেক্টর, কলাম, সারি)


fn জিজিইউএফ_টোকেন_আর্গম্যাক্স logit_addr vocab_size
    return gguf_token_argmax(logit_addr, vocab_size)

// ── ১১. জিজিইউএফ টেম্পারেচার স্কেলিং (GGUF Temperature Scaling) ───────────────
// WHY: Adjusts predicted logit distribution before sampling.
fn gguf_temperature_scale logits vocab_size temperature
    return ai_temperature_scale(logits, vocab_size, temperature)

fn জিজিইউএফ_তাপমাত্রা_স্কেল লজিটস ভোকাব_আকার তাপমাত্রা
    return ai_temperature_scale(লজিটস, ভোকাব_আকার, তাপমাত্রা)

// ── ১২. জিজিইউএফ টপ-কে স্যাম্পলার (GGUF Top-K Sampling) ───────────────────────
// WHY: Truncates logits to the top K most probable candidates and samples using PRNG seed.
fn gguf_sample_top_k logits vocab_size top_k temperature seed
    return ai_sample_top_k(logits, vocab_size, top_k, temperature, seed)

fn জিজিইউএফ_টপ_কে_স্যাম্পল লজিটস ভোকাব_আকার টপ_কে তাপমাত্রা সিড
    return ai_sample_top_k(লজিটস, ভোকাব_আকার, টপ_কে, তাপমাত্রা, সিড)

// ── ১২খ. জিজিইউএফ টপ-পি স্যাম্পলার (GGUF Top-P Nucleus Sampling) ───────────────
// WHY: Dynamically truncates logits to smallest nucleus with cumulative probability >= top_p.
fn gguf_sample_top_p logits vocab_size top_p temperature seed
    return ai_sample_top_p(logits, vocab_size, top_p, temperature, seed)

fn জিজিইউএফ_টপ_পি_স্যাম্পল লজিটস ভোকাব_আকার টপ_পি তাপমাত্রা সিড
    return ai_sample_top_p(লজিটস, ভোকাব_আকার, টপ_পি, তাপমাত্রা, সিড)

// ── ১২গ. জিজিইউএফ উন্নত বহুমুখী স্যাম্পলার (GGUF Advanced Sampler) ─────────────
// WHY: Unified sampler combining temperature, Top-K, and Top-P nucleus filtering.
fn gguf_sample_advanced logits vocab_size temperature top_k top_p
    return ai_sample_advanced(logits, vocab_size, temperature, top_k, top_p)

fn জিজিইউএফ_উন্নত_স্যাম্পল লজিটস ভোকাব_আকার তাপমাত্রা টপ_কে টপ_পি
    return ai_sample_advanced(লজিটস, ভোকাব_আকার, তাপমাত্রা, টপ_কে, টপ_পি)

// ── ১৩. জিজিইউএফ সার্বজনীন স্যাম্পলার (Unified GGUF Sampler) ───────────────────
// WHY: Automatically chooses greedy ArgMax (T <= 0 or K <= 1) or hardware entropy Top-K.
fn gguf_sample logits vocab_size temperature top_k
    return ai_sample(logits, vocab_size, temperature, top_k)

fn জিজিইউএফ_স্যাম্পল লজিটস ভোকাব_আকার তাপমাত্রা টপ_কে
    return ai_sample(লজিটস, ভোকাব_আকার, তাপমাত্রা, টপ_কে)

// ── ১৪. জিজিইউএফ কেভি-ক্যাশ ইন্টারফেস (GGUF KV-Cache Bindings) ─────────────────
// WHY: Provides direct GGUF-namespaced bindings to pure Lipi First 1.0.0 silicon KV-cache state buffer.
fn gguf_kv_cache_create max_seq_len n_layers n_heads head_dim
    return kv_cache_create(max_seq_len, n_layers, n_heads, head_dim)

fn জিজিইউএফ_কেভি_ক্যাশ_তৈরি সর্বোচ্চ_দৈর্ঘ্য লেয়ার_সংখ্যা হেড_সংখ্যা হেড_মাত্রা
    return kv_cache_create(সর্বোচ্চ_দৈর্ঘ্য, লেয়ার_সংখ্যা, হেড_সংখ্যা, হেড_মাত্রা)

fn gguf_kv_cache_append cache layer key_vec val_vec
    return kv_cache_append(cache, layer, key_vec, val_vec)

fn জিজিইউএফ_কেভি_ক্যাশ_যোগ ক্যাশ লেয়ার কি_ভেক্টর মান_ভেক্টর
    return kv_cache_append(ক্যাশ, লেয়ার, কি_ভেক্টর, মান_ভেক্টর)

fn gguf_kv_cache_get_keys cache layer
    return kv_cache_get_keys(cache, layer)

fn জিজিইউএফ_কেভি_ক্যাশ_কি_পড়ো ক্যাশ লেয়ার
    return kv_cache_get_keys(ক্যাশ, লেয়ার)

fn gguf_kv_cache_get_values cache layer
    return kv_cache_get_values(cache, layer)

fn জিজিইউএফ_কেভি_ক্যাশ_মান_পড়ো ক্যাশ লেয়ার
    return kv_cache_get_values(ক্যাশ, লেয়ার)

fn gguf_kv_cache_free cache
    return kv_cache_free(cache)

fn জিজিইউএফ_কেভি_ক্যাশ_মুক্তি ক্যাশ
    return kv_cache_free(ক্যাশ)

// ── ১৫. জিজিইউএফ অটোরিগ্রেসিভ জেনারেশন (GGUF Autoregressive Token Generation) ─
// WHY: High-level token generation driver orchestrating prompt ingestion and iterative decoding.
fn gguf_generate model_ctx prompt_token_ids max_new_tokens temperature top_k
    return ai_generate(model_ctx, prompt_token_ids, max_new_tokens, temperature, top_k)

fn জিজিইউএফ_জেনারেট মডেল_কনটেক্সট প্রম্পট_টোকেনসমূহ সর্বোচ্চ_নতুন_টোকেন তাপমাত্রা টপ_কে
    return ai_generate(মডেল_কনটেক্সট, প্রম্পট_টোকেনসমূহ, সর্বোচ্চ_নতুন_টোকেন, তাপমাত্রা, টপ_কে)


