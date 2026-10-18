// ==============================================================================
// 👑 LIPI TEST SUITE: HARDWARE DIVISION-BY-ZERO PROTECTION (tests/test_div_by_zero_guard.lp)
// Milestone: First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi — Zero Foreign Dependencies
// ==============================================================================

include "utso/io.lp"

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

    // 2. Hardware-Guarded Division by Zero (Variable Divisor)
    zero_val = 0
    safe_div = a / zero_val
    if safe_div != 0
        say "FAIL: a / 0 did not return 0"
        exit(1)
    end
    say "✔ Variable division by zero safely trapped and guarded: 1000 / 0 = 0"

    safe_mod = a % zero_val
    if safe_mod != 0
        say "FAIL: a % 0 did not return 0"
        exit(1)
    end
    say "✔ Variable modulo by zero safely trapped and guarded: 1000 % 0 = 0"

    // 3. Hardware-Guarded Division by Zero (Constant Divisor Literal)
    c_div = a / 0
    if c_div != 0
        say "FAIL: constant a / 0 did not return 0"
        exit(1)
    end
    say "✔ Constant literal division by zero safely guarded: 1000 / 0 = 0"

    c_mod = a % 0
    if c_mod != 0
        say "FAIL: constant a % 0 did not return 0"
        exit(1)
    end
    say "✔ Constant literal modulo by zero safely guarded: 1000 % 0 = 0"

    say "PASS: test_div_by_zero_guard"
    return 0
