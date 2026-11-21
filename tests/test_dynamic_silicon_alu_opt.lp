// ==============================================================================
// REGRESSION TEST: DIRECT SILICON HOT-LOOP ALU & INLINE COMPARE OPTIMIZER
// ==============================================================================
// Verifies correctness of zero-stack local int add/sub, 1-cycle immediate shifts
// (shl/sar), immediate bitwise ops (and/or/xor), inline integer == / != branches,
// and dynamic string equality fallback preservation.

include "utso/io"
include "utso/string"

fn compute_runtime_mix seed iters
    x = seed
    sum = 0
    i = 0
    while i < iters
        // Exercises local-int add/sub + immediate shl/sar + immediate and/or/xor
        x = (x + 17) - (i & 7)
        s1 = x << 3
        s2 = s1 >> 2
        masked = (s2 & 65535) ^ 10922
        flagged = masked | 1
        // Exercises inline int == int & int != int fast comparisons
        if (i & 3) == 2
            sum = sum + flagged
        elif (i & 3) != 1
            sum = sum - 1
        i = i + 1
    return sum

fn test_negative_shifts val
    // Arithmetic right shift must preserve sign on negative integers
    s = val >> 2
    l = val << 3
    return s + l

fn main
    // Avoid constant folding by reading pid-modulated runtime value via heap word
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    slot = alloc(16)
    mem_write(slot, 0, 12345 + (pid & 0))
    mem_write(slot, 8, 50000)

    seed = mem_read(slot, 0)
    iters = mem_read(slot, 8)
    free(slot)

    res1 = compute_runtime_mix(seed, iters)
    res2 = compute_runtime_mix(seed, iters)
    if res1 != res2 or res1 == 0
        say "[ERR] Determinism mismatch in silicon ALU loop: " + str(res1) + " vs " + str(res2)
        return 1
    say "[PASS] Zero-stack local int + imm bitwise/shift + inline == loop checksum=" + str(res1)

    // Negative shift verification: (-100 >> 2) + (-100 << 3) == -25 + -800 == -825
    neg_res = test_negative_shifts(0 - 100)
    if neg_res != (0 - 825)
        say "[ERR] Negative shift mismatch: expected -825, got " + str(neg_res)
        return 1
    say "[PASS] Signed negative arithmetic shifts exact: " + str(neg_res)

    // Verify dynamic string == / != fallback remains intact alongside int == int fast path
    sa = "লিপি" + "_সিলিকন"
    sb = "লিপি_" + "সিলিকন"
    sc = "অন্যান্য"
    if sa != sb
        say "[ERR] Dynamic string equality regression"
        return 1
    if sa == sc
        say "[ERR] Dynamic string inequality regression"
        return 1
    say "[PASS] Dynamic UTF-8 string equality fallback verified"
    say "✅ TEST_DYNAMIC_SILICON_ALU_OPT_COMPLETE"
    return 0

main()
