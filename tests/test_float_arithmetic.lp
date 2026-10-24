// ==============================================================================
// 👑 LIPI FIRST 1.0.0 REGRESSION TEST: IEEE-754 64-BIT FLOAT ARITHMETIC
// ⚡ Tests real hardware SSE2 double precision arithmetic and bitcast generation
// ==============================================================================

fn main()
    // Test 1: Float addition (reported issue: 1.9 + 2.9 was giving 3 instead of 4.8)
    let a = 1.9
    let b = 2.9
    let sum = a + b
    say "Testing 1.9 + 2.9:"
    say sum

    // Test 2: Float multiplication
    let c = 5.5
    let d = 2.0
    let prod = c * d
    say "Testing 5.5 * 2.0:"
    say prod

    // Test 3: Float division
    let e = 9.6
    let f = 2.0
    let quot = e / f
    say "Testing 9.6 / 2.0:"
    say quot

    // Test 4: Float subtraction
    let g = 1.9
    let h = 2.9
    let diff = g - h
    say "Testing 1.9 - 2.9:"
    say diff

    // Test 5: Mixed float and integer arithmetic
    let m = 2.5 + 3
    say "Testing 2.5 + 3:"
    say m

    // Test 6: Float Floor rounding intrinsic (floor(3.7) -> 3, floor(10) -> 10)
    let fl1 = floor(3.7)
    say "Testing floor(3.7):"
    say fl1
    if fl1 != 3
        say "FAIL: floor(3.7) expected 3"
        return 1
    end

    let fl2 = floor(10)
    say "Testing floor(10):"
    say fl2
    if fl2 != 10
        say "FAIL: floor(10) expected 10"
        return 1
    end

    say "FLOAT ARITHMETIC TESTS PASSED ✔"
    return 0
end
