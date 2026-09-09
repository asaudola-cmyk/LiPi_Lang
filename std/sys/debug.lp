// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: SOVEREIGN DEBUGGING & INTROSPECTION (std/debug.lp)
// ⚡ Runtime Assertions | Physical Stack Inspection | Hardware Breakpoint Hooks
// ==============================================================================

// WHY: High-reliability systems programming requires deep runtime diagnostics.
// std/debug.lp provides assertion primitives, stack inspection, and debugging utilities
// without external runtime or libc dependency.

অন্তর্ভুক্ত "std/mem.lp"

// ১. রানটাইম এসার্শন যাচাই (দাবি / assert)
// WHY: Ensures invariant correctness. If condition evaluates to 0 (false),
// immediately reports failure message to console and exits with code 1.
ফাংশন দাবি(শর্ত, ত্রুটি_বার্তা) {
    যদি শর্ত == 0 {
        দেখাও "❌ [দাবি ব্যর্থ / ASSERTION FAILED]: " + ত্রুটি_বার্তা
        সিসকল(60, 1, 0, 0, 0, 0, 0) // SYS_exit 1
    }
}

// ২. বর্তমান স্ট্যাক পয়েন্টার পরিদর্শন
// WHY: Returns the raw %rsp register address at execution time.
ফাংশন বর্তমান_স্ট্যাক() {
    ধরি rsp = স্ট্যাক_পয়েন্টার()
    ফেরত rsp
}

// ৩. র মেমরি হেক্স ডাম্পার (বাইট ভিত্তিক পরিদর্শন)
// WHY: Dumps consecutive bytes from a base memory address for diagnostic verification.
ফাংশন মেমরি_পরিদর্শন(বেস, দৈর্ঘ্য) {
    দেখাও "  [মেমরি পরিদর্শন @ " + বেস + ", সাইজ: " + দৈর্ঘ্য + " বাইট]"
    ধরি i = 0
    যতক্ষণ i < দৈর্ঘ্য {
        ধরি b = মেমরি_বাইট_পড়ো(বেস, i)
        দেখাও "    • অফসেট +" + i + " : " + b
        i = i + 1
    }
}
