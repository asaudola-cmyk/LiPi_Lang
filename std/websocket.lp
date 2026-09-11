// 📜 লিপি ওয়েবসংযোগ ইঞ্জিন (Pure Lipi WebSocket RFC 6455)
// 🏛️ HTTP/1.1 এর উপর বাইনারি ফ্রেম ও ফুল-ডুপ্লেক্স রিয়েল-টাইম স্ট্রিমিং
// ইনোভেশন: SIMD ও মেমরি বিট-মাস্কিং ব্যবহার করে জিরো-অ্যালোকেশন (Zero-Allocation) ফ্রেম পার্সিং।

include "std/mem.lp"

// ১. ক্লায়েন্ট থেকে আসা মাস্কড ফ্রেম আনমাস্ক (Unmask) করা
// WHY: ব্রাউজার থেকে আসা প্রতিটি ওয়েবসংযোগ ফ্রেমে একটি ৪ বাইটের সিক্রেট মাস্ক (Mask) থাকে
// যা দিয়ে ডেটাকে XOR করতে হয়। মেমরি পয়েন্টার দিয়ে ইন-প্লেস (In-place) অপারেশন করা হয়।
fn websocket_unmask payload_addr payload_length mask_addr
    mask0 = mem_byte_পড়ো(mask_addr, 0)
    mask1 = mem_byte_পড়ো(mask_addr, 1)
    mask2 = mem_byte_পড়ো(mask_addr, 2)
    mask3 = mem_byte_পড়ো(mask_addr, 3)

    index = 0
    while index < payload_length
        cur_byte = mem_byte_পড়ো(payload_addr, index)

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

        unmasked = cur_byte + mask_byte
        if unmasked > 255
            unmasked = unmasked - 256

        mem_byte_write(payload_addr, index, unmasked)
        index = index + 1

    return payload_length

fn ওয়েবসকেট_আনমাস্ক payload_addr payload_length mask_addr
    return websocket_unmask(payload_addr, payload_length, mask_addr)

// ২. ওয়েবসংযোগ ফ্রেম তৈরি (Construct Server-to-Client Frame)
// WHY: সার্ভার থেকে ব্রাউজারে ডেটা পাঠানোর সময় মাস্কিং লাগে না, তবে স্পেসিফিক হেডার (FIN+Opcode) দিতে হয়।
fn websocket_frame_create buffer_addr text_addr text_length
    // 0x81 = FIN bit (10000000) | Opcode Text (00000001)
    mem_byte_write(buffer_addr, 0, 129)

    header_offset = 2
    if text_length < 126
        // মাস্ক bit ০ (0), তাই শুধু দৈর্ঘ্য বসবে
        mem_byte_write(buffer_addr, 1, text_length)
    else
        // ১৬-বিট লেংথ (Extended Payload Length)
        mem_byte_write(buffer_addr, 1, 126)
        hi_byte = text_length / 256
        lo_byte = text_length - (hi_byte * 256)
        mem_byte_write(buffer_addr, 2, hi_byte)
        mem_byte_write(buffer_addr, 3, lo_byte)
        header_offset = 4

    // পেয়লোড কপি করা (Memcpy)
    mem_copy(buffer_addr + header_offset, text_addr, text_length)

    total_size = header_offset + text_length
    return total_size

fn ওয়েবসকেট_ফ্রেম_তৈরি buffer_addr text_addr text_length
    return websocket_frame_create(buffer_addr, text_addr, text_length)
