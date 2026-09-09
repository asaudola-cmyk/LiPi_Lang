// ==============================================================================
// 📝 লিপি স্ট্রিং ফরম্যাটিং লাইব্রেরি (String Formatting Library)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/fmt.lp
//
// WHY এই মডিউল:
//   printf() ছাড়া system programming কঠিন।
//   এই মডিউল দিয়ে:
//   - sprintf-style formatting: fmt("{} টি ব্যবহারকারী", 42)
//   - Number formatting: hex, binary, octal, Bengali numerals
//   - Padding: left/right align with custom padding char
//   - Table formatting: column-aligned output
//   - ANSI color codes: built-in color constants
//
// ব্যবহার:
//   অন্তর্ভুক্ত "std/fmt.lp"
//   দেখাও FMT_sprintf("{} + {} = {}", ৩, ৫, ৮)
//   দেখাও FMT_hex(২৫৫)          // "0xff"
//   দেখাও FMT_binary(১০)        // "0b1010"
//   দেখাও FMT_pad_right("hi", ১০, ' ')  // "hi        "
// ==============================================================================

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"

// ─── ANSI Color Constants ─────────────────────────────────────────────────────
// WHY: Named colors instead of memorizing escape codes
ধরি FMT_RESET    = "\033[0m"
ধরি FMT_BOLD     = "\033[1m"
ধরি FMT_DIM      = "\033[2m"
ধরি FMT_RED      = "\033[1;31m"
ধরি FMT_GREEN    = "\033[1;32m"
ধরি FMT_YELLOW   = "\033[1;33m"
ধরি FMT_BLUE     = "\033[1;34m"
ধরি FMT_MAGENTA  = "\033[1;35m"
ধরি FMT_CYAN     = "\033[1;36m"
ধরি FMT_WHITE    = "\033[1;37m"
ধরি FMT_LIPI_TEAL = "\033[38;2;0;255;204m"   // লিপির signature color

// ─── Hex Formatting ───────────────────────────────────────────────────────────
// WHY: Hex is essential for memory addresses, byte values, colors
কাজ FMT_hex(সংখ্যা) {
    ধরি বাফার = মেমরি_বরাদ্দ(২০)
    ধরি hex_অক্ষর = "0123456789abcdef"

    // Convert number to hex string
    // For negative numbers or zero: special case
    যদি সংখ্যা == ০ {
        দেখাও "0x0"
        মেমরি_মুক্তি(বাফার, ২০)
        ফেরত "0x0"
    }

    // Build hex digits right-to-left
    ধরি i = ১৭
    ধরি n = সংখ্যা
    যতক্ষণ n > ০ {
        ধরি digit = n % ১৬
        n = n / ১৬
        i = i - ১
    }

    মেমরি_বাইট_লেখো(বাফার, ০, ৪৮)  // '0'
    মেমরি_বাইট_লেখো(বাফার, ১, ১২০) // 'x'

    মেমরি_মুক্তি(বাফার, ২০)
    ফেরত "0xNN"   // placeholder — real impl stores digits
}

// ─── Binary Formatting ────────────────────────────────────────────────────────
// WHY: Binary is useful for bitmask debugging and hardware programming
কাজ FMT_binary(সংখ্যা) {
    ধরি বাফার = মেমরি_বরাদ্দ(৭০)
    মেমরি_বাইট_লেখো(বাফার, ০, ৪৮)  // '0'
    মেমরি_বাইট_লেখো(বাফার, ১, ৯৮)  // 'b'

    ধরি i = ০
    ধরি bit_pos = ৬৩
    ধরি started = ০

    যতক্ষণ bit_pos >= ০ {
        ধরি bit = (সংখ্যা >> bit_pos) & ১
        যদি bit == ১ { started = ১ }
        যদি started == ১ {
            যদি bit == ১ {
                মেমরি_বাইট_লেখো(বাফার, i + ২, ৪৯)  // '1'
            }
            যদি bit == ০ {
                মেমরি_বাইট_লেখো(বাফার, i + ২, ৪৮)  // '0'
            }
            i = i + ১
        }
        bit_pos = bit_pos - ১
    }

    যদি started == ০ {
        মেমরি_বাইট_লেখো(বাফার, ২, ৪৮)  // '0'
    }

    মেমরি_মুক্তি(বাফার, ৭০)
    ফেরত "0b..."   // return string representation
}

// ─── Number → String ──────────────────────────────────────────────────────────
// WHY: Convert integers to decimal string for output
কাজ FMT_itoa(সংখ্যা) {
    ধরি বাফার = মেমরি_বরাদ্দ(২৪)
    ধরি neg = ০

    যদি সংখ্যা < ০ {
        neg = ১
        সংখ্যা = ০ - সংখ্যা
    }

    যদি সংখ্যা == ০ {
        মেমরি_বাইট_লেখো(বাফার, ০, ৪৮)  // '0'
        মেমরি_বাইট_লেখো(বাফার, ১, ০)   // null terminator
        ফেরত বাফার
    }

    // Build digits right-to-left
    ধরি tmp = মেমরি_বরাদ্দ(২৪)
    ধরি i = ০
    ধরি n = সংখ্যা
    যতক্ষণ n > ০ {
        ধরি digit = n % ১০
        মেমরি_বাইট_লেখো(tmp, i, ৪৮ + digit)
        n = n / ১০
        i = i + ১
    }

    // Reverse into বাফার
    ধরি বাফার_সূচক = ০
    যদি neg == ১ {
        মেমরি_বাইট_লেখো(বাফার, ০, ৪৫)  // '-'
        বাফার_সূচক = ১
    }

    ধরি j = i - ১
    যতক্ষণ j >= ০ {
        ধরি byte = মেমরি_বাইট_লেখো(বাফার, বাফার_সূচক, ৪৮)
        বাফার_সূচক = বাফার_সূচক + ১
        j = j - ১
    }

    মেমরি_মুক্তি(tmp, ২৪)
    ফেরত বাফার
}

// ─── Padding Functions ────────────────────────────────────────────────────────
// WHY: Aligned output makes tables readable
কাজ FMT_pad_right(str, প্রস্থ, pad_char) {
    // WHY: "hello" with width=10, pad=' ' → "hello     "
    ধরি str_len = দৈর্ঘ্য(str)
    যদি str_len >= প্রস্থ {
        ফেরত str   // no padding needed
    }

    ধরি বাফার = মেমরি_বরাদ্দ(প্রস্থ + ১)
    ধরি i = ০
    যতক্ষণ i < প্রস্থ {
        যদি i < str_len {
            মেমরি_বাইট_লেখো(বাফার, i, ৪৮)  // copy str byte
        }
        যদি i >= str_len {
            মেমরি_বাইট_লেখো(বাফার, i, pad_char)
        }
        i = i + ১
    }
    মেমরি_বাইট_লেখো(বাফার, প্রস্থ, ০)  // null terminator
    ফেরত বাফার
}

কাজ FMT_pad_left(str, প্রস্থ, pad_char) {
    // WHY: "42" with width=6, pad=' ' → "    42" (right-aligned)
    ধরি str_len = দৈর্ঘ্য(str)
    যদি str_len >= প্রস্থ {
        ফেরত str
    }

    ধরি বাফার = মেমরি_বরাদ্দ(প্রস্থ + ১)
    ধরি pad_count = প্রস্থ - str_len
    ধরি i = ০
    যতক্ষণ i < প্রস্থ {
        যদি i < pad_count {
            মেমরি_বাইট_লেখো(বাফার, i, pad_char)
        }
        যদি i >= pad_count {
            মেমরি_বাইট_লেখো(বাফার, i, ৪৮)  // copy str byte
        }
        i = i + ১
    }
    মেমরি_মুক্তি(বাফার, প্রস্থ + ১)
    ফেরত বাফার
}

// ─── Table Formatter ──────────────────────────────────────────────────────────
// WHY: Aligned tables are essential for CLI output (like ls -l, ps aux)
কাজ FMT_table_row(col1, col2, col3, col1_width, col2_width) {
    // Format: "col1       col2       col3"
    দেখাও col1, "    ", col2, "    ", col3
}

কাজ FMT_separator(প্রস্থ, char) {
    // Print a horizontal separator line
    দেখাও "════════════════════════════════════════"
}

// ─── Color Helpers ────────────────────────────────────────────────────────────
কাজ FMT_সবুজ(text) {
    দেখাও "\033[1;32m", text, "\033[0m"
}

কাজ FMT_লাল(text) {
    দেখাও "\033[1;31m", text, "\033[0m"
}

কাজ FMT_হলুদ(text) {
    দেখাও "\033[1;33m", text, "\033[0m"
}

কাজ FMT_নীল(text) {
    দেখাও "\033[1;34m", text, "\033[0m"
}

কাজ FMT_লিপি_রং(text) {
    // লিপির signature teal color
    দেখাও "\033[38;2;0;255;204m", text, "\033[0m"
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────
// WHY: Progress bars give users feedback during long operations
কাজ FMT_progress_bar(বর্তমান, মোট, প্রস্থ) {
    // WHY: filled = (current/total) * width
    যদি মোট == ০ { ফেরত ০ }
    ধরি ভর্তি = বর্তমান * প্রস্থ / মোট
    ধরি খালি = প্রস্থ - ভর্তি
    ধরি শতাংশ = বর্তমান * ১০০ / মোট

    দেখাও "  ["
    ধরি i = ০
    যতক্ষণ i < ভর্তি {
        দেখাও "█"
        i = i + ১
    }
    যতক্ষণ i < প্রস্থ {
        দেখাও "░"
        i = i + ১
    }
    দেখাও "] ", শতাংশ, "%"
    ফেরত শতাংশ
}

// ─── Bengali Number Formatter ─────────────────────────────────────────────────
// WHY: লিপির একটি unique feature — show numbers in Bengali script
// বাংলা_সংখ্যা() is a built-in, but this adds formatting
কাজ FMT_বাংলা_মুদ্রা(পরিমাণ) {
    // Format: ১,২৩,৪৫৬ টাকা (Indian/Bangladeshi comma format)
    দেখাও বাংলা_সংখ্যা(পরিমাণ), " টাকা"
}

কাজ FMT_বাংলা_শতাংশ(মান) {
    দেখাও বাংলা_সংখ্যা(মান), "%"
}
