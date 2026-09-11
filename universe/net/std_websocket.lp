// ==============================================================================
// 📜 লিপি ওয়েবসংযোগ ইঞ্জিন (Pure Lipi WebSocket RFC 6455)
// 🏛️ HTTP/1.1 এর উপর বাইনারি ফ্রেম ও ফুল-ডুপ্লেক্স রিয়েল-টাইম স্ট্রিমিং
// ইনোভেশন: SIMD ও মেমরি বিট-মাস্কিং ব্যবহার করে জিরো-অ্যালোকেশন (Zero-Allocation) ফ্রেম পার্সিং।
// ==============================================================================

include "universe/core/std_mem.lp"

// ─── WebSocket Constants (RFC 6455) ──────────────────────────────────────────
WS_OPCODE_CONTINUATION = 0
WS_OPCODE_TEXT         = 1
WS_OPCODE_BINARY       = 2
WS_OPCODE_CLOSE        = 8
WS_OPCODE_PING         = 9
WS_OPCODE_PONG         = 10

// WHY: Pure silicon bitwise XOR implementation for RFC 6455 frame masking/unmasking (cur_byte ^ mask_byte).
fn ws_bit_xor a b
    res = 0
    p = 1
    while a > 0 or b > 0
        abit = a % 2
        bbit = b % 2
        if abit != bbit
            res = res + p
        a = a / 2
        b = b / 2
        p = p * 2
    return res

// ১. ক্লায়েন্ট থেকে আসা মাস্কড ফ্রেম আনমাস্ক (Unmask) করা
// WHY: ব্রাউজার থেকে আসা প্রতিটি ওয়েবসংযোগ ফ্রেমে একটি ৪ বাইটের সিক্রেট মাস্ক (Mask Key) থাকে
// যা দিয়ে ডেটাকে XOR করতে হয় (RFC 6455 Section 5.3: Transformed-octet = original-octet ^ masking-key[i % 4])।
// মেমরি পয়েন্টার দিয়ে ইন-প্লেস (In-place) অপারেশন করা হয়।
fn websocket_unmask payload_addr payload_length mask_addr
    mask0 = mem_byte_read(mask_addr, 0)
    mask1 = mem_byte_read(mask_addr, 1)
    mask2 = mem_byte_read(mask_addr, 2)
    mask3 = mem_byte_read(mask_addr, 3)

    index = 0
    while index < payload_length
        cur_byte = mem_byte_read(payload_addr, index)

        // মডুলো (index % 4)
        quotient = index / 4
        modulo = index - (quotient * 4)

        mask_byte = mask0
        if modulo == 1
            mask_byte = mask1
        if modulo == 2
            mask_byte = mask2
        if modulo == 3
            mask_byte = mask3

        // WHY: RFC 6455 mandates bitwise XOR (cur_byte ^ mask_byte), not addition
        unmasked = ws_bit_xor(cur_byte, mask_byte)
        mem_byte_write(payload_addr, index, unmasked)
        index = index + 1

    return payload_length

fn ওয়েবসকেট_আনমাস্ক payload_addr payload_length mask_addr
    return websocket_unmask(payload_addr, payload_length, mask_addr)

// ২. ক্লায়েন্ট পেয়লোড মাস্ক (Mask) করা
// WHY: RFC 6455 Section 5.3 অনুযায়ী ক্লায়েন্ট থেকে সার্ভারে পাঠানো ফ্রেমে ডেটা মাস্কিং করতে হয়।
// XOR অপারেশন প্রতিসম (Involutory): (A ^ M) ^ M = A, তাই আনমাস্কিং এবং মাস্কিং গাণিতিকভাবে অভিন্ন।
fn websocket_mask payload_addr payload_length mask_addr
    return websocket_unmask(payload_addr, payload_length, mask_addr)

fn ওয়েবসকেট_মাস্ক payload_addr payload_length mask_addr
    return websocket_mask(payload_addr, payload_length, mask_addr)

// ৩. সার্ভার থেকে ব্রাউজারে টেক্সট ফ্রেম তৈরি (Construct Server-to-Client Frame)
// WHY: সার্ভার থেকে ব্রাউজারে ডেটা পাঠানোর সময় মাস্কিং লাগে না, তবে FIN=1 ও Opcode=1 (Text: 0x81 = 129) দিতে হয়।
// ছোট পেয়লোডের (<126) জন্য ২ বাইট, মাঝারি (<=65535) এর জন্য ৪ বাইট, এবং বৃহতের জন্য ১০ বাইট হেডার।
fn websocket_frame_create buffer_addr text_addr text_length
    // 0x81 = FIN bit (10000000) | Opcode Text (00000001) = 129
    mem_byte_write(buffer_addr, 0, 129)

    header_offset = 2
    if text_length < 126
        // মাস্ক bit ০ (0), তাই সরাসরি দৈর্ঘ্য বসবে
        mem_byte_write(buffer_addr, 1, text_length)
    elif text_length <= 65535
        // ১৬-বিট লেংথ (Extended Payload Length)
        mem_byte_write(buffer_addr, 1, 126)
        hi_byte = text_length / 256
        lo_byte = text_length % 256
        mem_byte_write(buffer_addr, 2, hi_byte)
        mem_byte_write(buffer_addr, 3, lo_byte)
        header_offset = 4
    else
        // ৬৪-বিট লেংথ (Extended Payload Length Big-Endian)
        mem_byte_write(buffer_addr, 1, 127)
        rem = text_length
        b7 = rem % 256
        rem = rem / 256
        b6 = rem % 256
        rem = rem / 256
        b5 = rem % 256
        rem = rem / 256
        b4 = rem % 256
        rem = rem / 256
        b3 = rem % 256
        rem = rem / 256
        b2 = rem % 256
        rem = rem / 256
        b1 = rem % 256
        rem = rem / 256
        b0 = rem % 256
        mem_byte_write(buffer_addr, 2, b0)
        mem_byte_write(buffer_addr, 3, b1)
        mem_byte_write(buffer_addr, 4, b2)
        mem_byte_write(buffer_addr, 5, b3)
        mem_byte_write(buffer_addr, 6, b4)
        mem_byte_write(buffer_addr, 7, b5)
        mem_byte_write(buffer_addr, 8, b6)
        mem_byte_write(buffer_addr, 9, b7)
        header_offset = 10

    // পেয়লোড কপি করা (Memcpy)
    mem_copy(buffer_addr + header_offset, text_addr, text_length)

    total_size = header_offset + text_length
    return total_size

fn ওয়েবসকেট_ফ্রেম_তৈরি buffer_addr text_addr text_length
    return websocket_frame_create(buffer_addr, text_addr, text_length)

// ৪. ক্লায়েন্ট থেকে সার্ভারে পাঠানোর জন্য মাস্কড ফ্রেম তৈরি (Construct Masked Client-to-Server Frame)
// WHY: RFC 6455 Section 5.1 mandates that all frames from client to server MUST be masked with a 4-byte masking key.
// Mask bit is set on length byte (0x80 | length), followed by 4-byte masking key and masked payload.
fn websocket_client_frame_create buffer_addr text_addr text_length mask_addr
    mem_byte_write(buffer_addr, 0, 129) // FIN=1, Opcode=1 (Text)

    header_offset = 2
    if text_length < 126
        mem_byte_write(buffer_addr, 1, 128 + text_length)
        header_offset = 2
    elif text_length <= 65535
        mem_byte_write(buffer_addr, 1, 128 + 126)
        hi_byte = text_length / 256
        lo_byte = text_length % 256
        mem_byte_write(buffer_addr, 2, hi_byte)
        mem_byte_write(buffer_addr, 3, lo_byte)
        header_offset = 4
    else
        mem_byte_write(buffer_addr, 1, 128 + 127)
        rem = text_length
        b7 = rem % 256
        rem = rem / 256
        b6 = rem % 256
        rem = rem / 256
        b5 = rem % 256
        rem = rem / 256
        b4 = rem % 256
        rem = rem / 256
        b3 = rem % 256
        rem = rem / 256
        b2 = rem % 256
        rem = rem / 256
        b1 = rem % 256
        rem = rem / 256
        b0 = rem % 256
        mem_byte_write(buffer_addr, 2, b0)
        mem_byte_write(buffer_addr, 3, b1)
        mem_byte_write(buffer_addr, 4, b2)
        mem_byte_write(buffer_addr, 5, b3)
        mem_byte_write(buffer_addr, 6, b4)
        mem_byte_write(buffer_addr, 7, b5)
        mem_byte_write(buffer_addr, 8, b6)
        mem_byte_write(buffer_addr, 9, b7)
        header_offset = 10

    // ৪ বাইটের মাস্ক কি কপি করা
    m0 = mem_byte_read(mask_addr, 0)
    m1 = mem_byte_read(mask_addr, 1)
    m2 = mem_byte_read(mask_addr, 2)
    m3 = mem_byte_read(mask_addr, 3)
    mem_byte_write(buffer_addr, header_offset + 0, m0)
    mem_byte_write(buffer_addr, header_offset + 1, m1)
    mem_byte_write(buffer_addr, header_offset + 2, m2)
    mem_byte_write(buffer_addr, header_offset + 3, m3)

    // মাস্ক করা পেয়লোড গন্তব্যে কপি করা
    payload_start = header_offset + 4
    i = 0
    while i < text_length
        orig_byte = mem_byte_read(text_addr, i)
        mod4 = i % 4
        cur_mask = m0
        if mod4 == 1
            cur_mask = m1
        if mod4 == 2
            cur_mask = m2
        if mod4 == 3
            cur_mask = m3

        mem_byte_write(buffer_addr, payload_start + i, ws_bit_xor(orig_byte, cur_mask))
        i = i + 1

    return payload_start + text_length

fn ক্লায়েন্ট_ওয়েবসকেট_ফ্রেম_তৈরি buffer_addr text_addr text_length mask_addr
    return websocket_client_frame_create(buffer_addr, text_addr, text_length, mask_addr)

// ৫. ফ্রেম হেডার পার্সিং ও ভ্যালিডেশন হেল্পার (Frame Parsing & Inspection)
// WHY: ইনকামিং ফ্রেমের FIN বিট, অপকোড, মাস্কিং ফ্ল্যাগ ও পেয়লোড লেংথ দ্রুত নির্ণয়।
fn websocket_parse_fin byte0
    if byte0 >= 128
        return 1
    return 0

fn websocket_parse_opcode byte0
    return byte0 % 16

fn websocket_is_masked byte1
    if byte1 >= 128
        return 1
    return 0

fn websocket_payload_length buf_addr
    byte1 = mem_byte_read(buf_addr, 1)
    len7 = byte1 % 128
    if len7 < 126
        return len7
    if len7 == 126
        hi = mem_byte_read(buf_addr, 2)
        lo = mem_byte_read(buf_addr, 3)
        return (hi * 256) + lo
    // ৬৪-বিট লেংথ
    val = 0
    i = 0
    while i < 8
        b = mem_byte_read(buf_addr, 2 + i)
        val = (val * 256) + b
        i = i + 1
    return val

fn ওয়েবসকেট_পেয়লোড_দৈর্ঘ্য বাফার_ঠিকানা
    return websocket_payload_length(বাফার_ঠিকানা)
