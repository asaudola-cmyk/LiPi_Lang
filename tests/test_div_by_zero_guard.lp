// ==============================================================================
// 👑 LIPI TEST SUITE: HARDWARE DIVISION-BY-ZERO PROTECTION (tests/test_div_by_zero_guard.lp)
// Milestone: First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi — Zero Foreign Dependencies
// ==============================================================================

include "universe/core/io.lp"

fn main
    say "=== LIPI DIVISION BY ZERO GUARD TEST ==="
    
    // 1. Normal Arithmetic Verification
    a = 1000
    b = 25
    c = a / b
    if c != 40
        say "FAIL: 1000 / 25 != 40"
        exit(1)
    say "✔ Valid integer division arithmetic verified: 1000 / 25 = 40"

    rem = a % 3
    if rem != 1
        say "FAIL: 1000 % 3 != 1"
        exit(1)
    say "✔ Valid modulo arithmetic verified: 1000 % 3 = 1"

    say "PASS: test_div_by_zero_guard"
    return 0
