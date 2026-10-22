// ==============================================================================
// 🧪 LIPI REGRESSION TEST: LOOP CONTROL & RECURRENCE EDGE CASES
// ⚡ Tests continue in for/repeat, negative repeat limits, nested break/continue,
//    algebraic residue folding boundaries, and register release across sequential loops.
// ==============================================================================

fn test_for_continue
    // Sum numbers 1..10 skipping multiples of 3
    sum = 0
    for i in 1..10
        if i % 3 == 0
            continue
        sum = sum + i
    // Expected: 1+2+4+5+7+8+10 = 37
    if sum != 37
        say "FAIL: test_for_continue expected 37, got " + sum
        exit(1)
    say "✔ PASS: for loop continue (sum = 37)"
    return 1

fn test_repeat_continue
    // Count iterations in repeat 5 when continue is invoked on iteration 2
    executed = 0
    total_passes = 0
    repeat 5
        total_passes = total_passes + 1
        if total_passes == 2
            continue
        executed = executed + 1
    // Loop must execute exactly 5 passes, skipping the body on pass 2 -> executed = 4
    if total_passes != 5 or executed != 4
        say "FAIL: test_repeat_continue expected total=5 executed=4, got total=" + total_passes + " executed=" + executed
        exit(1)
    say "✔ PASS: repeat loop continue (total=5, executed=4)"
    return 1

fn test_repeat_limits
    // repeat 0
    c0 = 0
    repeat 0
        c0 = c0 + 1
    if c0 != 0
        say "FAIL: repeat 0 executed " + c0 + " times"
        exit(1)

    // repeat negative
    c_neg = 0
    repeat (0 - 10)
        c_neg = c_neg + 1
    if c_neg != 0
        say "FAIL: repeat -10 executed " + c_neg + " times"
        exit(1)
    say "✔ PASS: repeat 0 and repeat negative limits"
    return 1

fn test_repeat_break
    c_brk = 0
    repeat 10
        c_brk = c_brk + 1
        if c_brk == 4
            break
    if c_brk != 4
        say "FAIL: repeat break expected 4, got " + c_brk
        exit(1)
    say "✔ PASS: repeat loop break"
    return 1

fn test_fold_boundaries
    // 1. Folded sum with start = 1: 1..10 mod 3
    acc1 = 0
    for i in 1..10
        acc1 = acc1 + (i % 3)
    // 1:1, 2:2, 3:0, 4:1, 5:2, 6:0, 7:1, 8:2, 9:0, 10:1 -> sum = 10
    if acc1 != 10
        say "FAIL: test_fold_boundaries start=1 expected 10, got " + acc1
        exit(1)

    // 2. Unfolded sum with start != 1: 5..10 mod 3
    acc2 = 0
    for i in 5..10
        acc2 = acc2 + (i % 3)
    // 5:2, 6:0, 7:1, 8:2, 9:0, 10:1 -> sum = 6
    if acc2 != 6
        say "FAIL: test_fold_boundaries start=5 expected 6, got " + acc2
        exit(1)
    say "✔ PASS: algebraic residue folding boundaries (start=1 vs start=5)"
    return 1

fn test_nested_break_continue
    total = 0
    outer_count = 0
    while outer_count < 3
        outer_count = outer_count + 1
        if outer_count == 2
            continue
        // For outer_count 1 and 3:
        repeat 4
            inner_sum = 0
            for k in 1..6
                if k == 2
                    continue
                if k == 5
                    break
                inner_sum = inner_sum + k
            // inner_sum = 1 + 3 + 4 = 8
            total = total + inner_sum
    // outer_count runs 2 valid passes (1 and 3)
    // each repeat runs 4 times -> 4 * 8 = 32 per outer pass
    // 2 * 32 = 64
    if total != 64
        say "FAIL: test_nested_break_continue expected 64, got " + total
        exit(1)
    say "✔ PASS: deeply nested while/repeat/for with scoped break/continue (total = 64)"
    return 1

fn test_sequential_repeat_registers
    // Run 8 sequential repeat loops to exceed the 5 callee-saved registers (%r12-%r15, %rbx)
    // and verify that registers are properly recycled without spilling or exhaustion.
    s1 = 0
    repeat 2
        s1 = s1 + 1
    s2 = 0
    repeat 2
        s2 = s2 + 1
    s3 = 0
    repeat 2
        s3 = s3 + 1
    s4 = 0
    repeat 2
        s4 = s4 + 1
    s5 = 0
    repeat 2
        s5 = s5 + 1
    s6 = 0
    repeat 2
        s6 = s6 + 1
    s7 = 0
    repeat 2
        s7 = s7 + 1
    s8 = 0
    repeat 2
        s8 = s8 + 1
    total_seq = s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8
    if total_seq != 16
        say "FAIL: sequential repeat registers expected 16, got " + total_seq
        exit(1)
    say "✔ PASS: 8 sequential repeat loops register recycling (total = 16)"
    return 1

fn main
    say "========================================================================"
    say "  🧪 LIPI SUITE: LOOP CONTROL & ALGEBRAIC RECURRENCE EDGE CASES"
    say "========================================================================"
    test_for_continue()
    test_repeat_continue()
    test_repeat_limits()
    test_repeat_break()
    test_fold_boundaries()
    test_nested_break_continue()
    test_sequential_repeat_registers()
    say "🎉 ALL LOOP CONTROL EDGE CASES PASSED!"
    return 0

main()
