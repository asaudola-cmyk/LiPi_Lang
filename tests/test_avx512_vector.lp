// ==============================================================================
// 👑 লিপ টেস্ট: এভিএক্স-৫১২ সিলিকন ভেক্টর ইঞ্জিন ও ডায়নামিক সিপিইউআইডি গার্ড
// 🏛️ Test: Sovereign AVX-512 Silicon Vector Engine with Dynamic CPUID Guard
// ==============================================================================
//
// WHY: আধুনিক সুপারকম্পিউটার ও এআই ম্যাট্রিক্স মাল্টিপ্লিকেশন যাতে সরাসরি হার্ডওয়্যার
// সিলিকনে ৫১২-বিট জেডএমএম (ZMM) রেজিস্টারে শূন্য-সি লাইব্রেরি ছাড়া খাঁটি লিপি
// মেশিন কোডে দ্রুততম গতিতে চলে, এবং অসঙ্গত প্রসেসরে SIGILL ছাড়া স্বয়ংক্রিয়
// নিরাপদ ফলব্যাক নিশ্চিত করে।

include "universe/cpu/avx512_native.lp"

fn assert_eq_int actual expected test_name
    if actual == expected
        say "  ✔ " + test_name + " verified: " + to_str(actual)
        return 1
    say "  ❌ FAILED: " + test_name + " expected " + to_str(expected) + " but got " + to_str(actual)
    exit(1)

fn main
    say "========================================================"
    say "👑 Testing Lipi Sovereign AVX-512 Silicon Vector Engine"
    say "========================================================"

    // [Step 1] Dynamic Hardware CPUID Discovery
    say "[1/6] Probing Native Silicon via CPUID..."
    has_a512 = cpu_has_avx512()
    has_a2 = cpu_has_avx2()
    say "  CPUID AVX-512F Feature Flag: " + to_str(has_a512)
    say "  CPUID AVX2 Feature Flag: " + to_str(has_a2)
    assert_eq_int(has_a512, 1, "Native AVX-512 Silicon Presence")
    assert_eq_int(has_a2, 1, "Native AVX2 Silicon Presence")

    // [Step 2] Native 512-Bit Vector Sum (ZMM 64-byte chunks)
    say "[2/6] Testing Native 512-Bit Vector Sum (simd_avx512_sum_u64)..."
    // Allocate 16 elements (128 bytes = 2x 512-bit ZMM iterations)
    buf_a = sys_alloc(128)
    expected_sum = 0
    i = 0
    while i < 16
        val = i + 10
        sys_poke(buf_a + (i * 8), val)
        expected_sum = expected_sum + val
        i = i + 1

    actual_sum = simd_avx512_sum_u64(buf_a, 16)
    assert_eq_int(actual_sum, expected_sum, "512-bit ZMM Vector Sum (16 elements)")

    // [Step 3] Vector Remainder Handling (Tail Elements < 8)
    say "[3/6] Testing 512-Bit Vector Tail & Remainder Handling..."
    // 21 elements = 2x 512-bit chunks (16 elements) + 5 remainder elements
    buf_rem = sys_alloc(200)
    expected_rem_sum = 0
    k = 0
    while k < 21
        v = (k * 3) + 1
        sys_poke(buf_rem + (k * 8), v)
        expected_rem_sum = expected_rem_sum + v
        k = k + 1

    actual_rem_sum = simd_avx512_sum_u64(buf_rem, 21)
    assert_eq_int(actual_rem_sum, expected_rem_sum, "512-bit ZMM Tail Handling (21 elements)")

    // [Step 4] Native 512-Bit Vector Dot Product (ZMM vpmullq)
    say "[4/6] Testing Native 512-Bit Vector Dot Product (simd_avx512_dot_u64)..."
    buf_v1 = sys_alloc(128)
    buf_v2 = sys_alloc(128)
    expected_dot = 0
    j = 0
    while j < 12
        v1 = j + 1
        v2 = 12 - j
        sys_poke(buf_v1 + (j * 8), v1)
        sys_poke(buf_v2 + (j * 8), v2)
        expected_dot = expected_dot + (v1 * v2)
        j = j + 1

    actual_dot = simd_avx512_dot_u64(buf_v1, buf_v2, 12)
    assert_eq_int(actual_dot, expected_dot, "512-bit ZMM Dot Product (12 elements)")

    // [Step 5] Dynamic Accelerated API with Fallback Guard
    say "[5/6] Testing Sovereign Accelerated API (vector_sum_accelerated & vector_dot_accelerated)..."
    acc_sum = vector_sum_accelerated(buf_rem, 21)
    assert_eq_int(acc_sum, expected_rem_sum, "Accelerated Vector Sum API")

    acc_dot = vector_dot_accelerated(buf_v1, buf_v2, 12)
    assert_eq_int(acc_dot, expected_dot, "Accelerated Vector Dot API")

    // Test zero count & null safety edge cases
    zero_sum = vector_sum_accelerated(buf_a, 0)
    assert_eq_int(zero_sum, 0, "Zero-count Sum Safety Guard")

    null_sum = vector_sum_accelerated(0, 10)
    assert_eq_int(null_sum, 0, "Null-pointer Sum Safety Guard")

    zero_dot = vector_dot_accelerated(buf_v1, buf_v2, 0)
    assert_eq_int(zero_dot, 0, "Zero-count Dot Safety Guard")

    // [Step 6] Hardware Silicon Discovery Report
    say "[6/6] Emitting Sovereign Silicon Discovery Report..."
    cpu_feature_report()

    say "========================================================"
    say "PASS: AVX-512 Silicon Vector Engine 100% Verified!"
    say "========================================================"
    return 0

main()
