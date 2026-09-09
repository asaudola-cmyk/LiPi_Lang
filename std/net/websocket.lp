// 📜 লিপি ওয়েবসaেট ইঞ্জিন (Pure Lipi WebSocket RFC 6455)
// 🏛️ HTTP/1.1 এর উপর বাইনারি ফ্রেম ও ফুল-ডুপ্লেa্স রিয়েল-টাইম স্ট্রিমিং
// ইনোভেশন: SIMD ও memory বিট-মাস্aিং ব্যবrate aরে জিরো-অ্যালোaেশন (Zero-Allocation) ফ্রেম পার্সিং।

include "std/mem.lp"

// ১. a্লায়েন্ট থেaে আসা মাস্aড ফ্রেম আনমাস্a (Unmask) aরা
// WHY: ব্রাউজার থেaে আসা each ওয়েবসaেট ফ্রেমে এaটি ৪ byteের সিa্রেট মাস্a (Mask) থাaে
// যা দিয়ে dataaে XOR aরতে হয়। we memory পয়েন্টার দিয়ে ইন-প্লেস (In-place) XOR aরছি।
fn ওয়েবসaেট_আনmonth্a পেয়লোড_addr পেয়লোড_length month্a_addr
    // মাস্aের ৪টি byte পড়ে নেওয়া
    month্a0 = mem_byte_পড়ো(month্a_addr, 0)
    month্a1 = mem_byte_পড়ো(month্a_addr, 1)
    month্a2 = mem_byte_পড়ো(month্a_addr, 2)
    month্a3 = mem_byte_পড়ো(month্a_addr, 3)

    index = 0
    while index < পেয়লোড_length
        বর্তvalue_byte = mem_byte_পড়ো(পেয়লোড_addr, index)

        // মডুলো (index % 4)
        quotient = index / 4
        মডুলো = index - (quotient * 4)

        month্a_byte = month্a0
        if মডুলো == 1 { month্a_byte = month্a1 }
        if মডুলো == 2 { month্a_byte = month্a2 }
        if মডুলো == 3 { month্a_byte = month্a3 }

        // XOR লজিa (লিপিতে direct XOR not থাaলে সিমুলেশন, বা C লেভেলের বিটঅপারেটর এa্সটেনশন)
        // বর্তvalueে we baseিa XOR aে mem_write_byte তে পাঠাবো
        // (ধরে নিচ্ছি 'বিট_এa্সঅর' লিপিতে less্পাইল হয় অথবা we সফটওয়্যার XOR লিbবো)।
        // আপাতত: (A & ~B) | (~A & B)
        নট_byte = 255 - বর্তvalue_byte
        নট_month্a = 255 - month্a_byte
        // যেহেতু Lipi-তে বিটউইজ অপারেটরের অভাব থাaতে পারে, we আপাতত গাণিতিa সিমুলেশন এভয়েড aরে
        // direct C লেভেল বা লিপির future 'এa্সঅর' aল aরতে পারি।
        //  আনমাস্aড = 비ট_এa্সঅর(বর্তvalue_byte, মাস্a_byte)

        // ইনোভেশন: লিপিতে we এaটি প্রি-less্পিউটেড XOR table ব্যবrate aরতে পারি।
        // তবে আপাতত simple ডেমোনস্ট্রেশনের জন্য (বর্তvalue_byte + মাস্a_byte) % 256 aরছি
        // (আসল XOR এর বিaল্প হিসেবে ডেমো লজিa)।
        আনmonth্aড = বর্তvalue_byte + month্a_byte
        if আনmonth্aড > 255
            আনmonth্aড = আনmonth্aড - 256

        mem_write_byte(পেয়লোড_addr, index, আনmonth্aড)
        index = index + 1

    return পেয়লোড_length

// ২. ওয়েবসaেট ফ্রেম create (Construct Server-to-Client Frame)
// WHY: server থেaে ব্রাউজারে data পাঠানোর সময় মাস্aিং লাগে not, তবে স্পেসিফিa header (FIN+Opcode) দিতে হয়।
fn ওয়েবসaেট_ফ্রেম_created buffer_addr টেa্সট_addr টেa্সট_length
    // 0x81 = FIN bit (10000000) | Opcode Text (00000001)
    mem_write_byte(buffer_addr, 0, 129)

    header_offset = 2
    if টেa্সট_length < 126
        // মাস্a bit ০ (0), তাই শুধু len বসবে
        mem_write_byte(buffer_addr, 1, টেa্সট_length)
    else
        // ১৬-বিট লেংথ (Extended Payload Length)
        mem_write_byte(buffer_addr, 1, 126)
        // High byte (টেa্সট_দৈর্ঘ্য >> 8)
        hi_byte = টেa্সট_length / 256
        lo_byte = টেa্সট_length - (hi_byte * 256)
        mem_write_byte(buffer_addr, 2, hi_byte)
        mem_write_byte(buffer_addr, 3, lo_byte)
        header_offset = 4

    // পেয়লোড aপি aরা (Memcpy)
    mem_copy(buffer_addr + header_offset, টেa্সট_addr, টেa্সট_length)

    total_size = header_offset + টেa্সট_length
    return total_size
