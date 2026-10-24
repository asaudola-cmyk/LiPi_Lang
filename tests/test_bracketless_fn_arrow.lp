// ==============================================================================
// 👑 LIPI FIRST 1.0.0 REGRESSION TEST: BRACKETLESS FUNCTION RETURN ARROW (->)
// ⚡ Tests bracketless function declarations with parameter type annotations & ->
// ==============================================================================

fn add a: i64 b: i64 -> i64
    return a + b
end

fn mul_sub a: i64 b: i64 c: i64 -> i64
    return (a * b) - c
end

fn main()
    let r1 = add(15, 25)
    say "Testing add 15 25:"
    say r1
    if r1 != 40
        say "FAIL: add result mismatch"
        return 1
    end

    let r2 = mul_sub(6, 7, 2)
    say "Testing mul_sub 6 7 2:"
    say r2
    if r2 != 40
        say "FAIL: mul_sub result mismatch"
        return 1
    end

    say "BRACKETLESS FUNCTION ARROW TESTS PASSED ✔"
    return 0
end
