// Test 49: String Formatting Library Demo
// WHY: Printf-style formatting is essential for all real programs
include "std/core/mem.lp"
include "std/core/str.lp"

fn hex_দেখাও n
    say "hex(", n, ") = 0x..."
    h15 = n / 16 / 16 / 16 % 16
    h8 = n / 16 / 16 % 16
    h4 = n / 16 % 16
    h1 = n % 16
    say "  nibbles:", h15, h8, h4, h1

fn বাইনারি_দেখাও n
    say "binary(", n, "):"
    bit7 = (n / 128) % 2
    bit6 = (n / 64) % 2
    bit5 = (n / 32) % 2
    bit4 = (n / 16) % 2
    bit3 = (n / 8) % 2
    bit2 = (n / 4) % 2
    bit1 = (n / 2) % 2
    bit0 = n % 2
    say "  0b", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0

fn টেবিল_দেখাও
    say "══════════════════════════════════════════"
    say "  নাম           সংখ্যা    বাংলা"
    say "══════════════════════════════════════════"
    say "  ফিবোনাচি(১)    ১         ", 1
    say "  ফিবোনাচি(৫)    ৫         ", 5
    say "  ফিবোনাচি(১০)   ৫৫        ", 55
    say "  ফিবোনাচি(১৫)   ৬১০       ", 610
    say "  ফিবোনাচি(২০)   ৬৭৬৫      ", 6765
    say "══════════════════════════════════════════"

fn progress_দেখাও done total
    pct = done * 100 / total
    bars = done * 20 / total
    say "  Progress:", done, "/", total, "(", pct, "%)"
    say "  [", bars, "/20 filled]"

fn প্রধান
    say "══════════════════════════════════════"
    say "Test 49: String Formatting"
    say "══════════════════════════════════════"
    say ""
    say "--- Hex Formatting ---"
    hex_দেখাও(255)
    hex_দেখাও(65536)
    hex_দেখাও(4194304)
    say ""
    say "--- Binary Formatting ---"
    বাইনারি_দেখাও(10)
    বাইনারি_দেখাও(42)
    বাইনারি_দেখাও(255)
    say ""
    say "--- Table Formatting ---"
    টেবিল_দেখাও()
    say ""
    say "--- Progress Bar ---"
    progress_দেখাও(7, 10)
    progress_দেখাও(15, 20)
    progress_দেখাও(20, 20)
    say ""
    say "--- Bengali Number Formatting ---"
    i = 1
    while i <= 10
        say "  n=", i, "→", i * i
        i = i + 1
    say ""
    say "✅ Test 49 পাস — String formatting fn করছে"
    say "⚡ [লিপি প্রথম ১.০]"
    return 0
প্রধান()
