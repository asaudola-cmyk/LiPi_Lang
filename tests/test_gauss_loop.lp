// tests/test_gauss_loop.lp
// Validates O(1) Gauss Closed-Form Symbolic Loop Induction & Modulo Folding
include "universe/core/io.lp"

fn test_gauss_basic
    total = 0
    i = 1
    while i <= 10
        total = total + i
        i = i + 1
    if total == 55
        say "PASS: Gauss Basic (1..10 = 55)"
    else
        say "FAIL: Gauss Basic expected 55, got " + total

fn test_gauss_hundred
    total = 0
    i = 1
    while i <= 100
        total += i
        i += 1
    if total == 5050
        say "PASS: Gauss Hundred (1..100 = 5050)"
    else
        say "FAIL: Gauss Hundred expected 5050, got " + total

fn test_gauss_offset
    total = 0
    i = 4
    while i <= 10
        total = total + i
        i = i + 1
    if total == 49
        say "PASS: Gauss Offset (4..10 = 49)"
    else
        say "FAIL: Gauss Offset expected 49, got " + total

fn test_gauss_million
    total = 0
    i = 1
    while i <= 1000000
        total += i
        i += 1
    // Sum = 1000000 * 1000001 / 2 = 500000500000
    if total == 500000500000
        say "PASS: Gauss Million (1..1000000 = 500000500000)"
    else
        say "FAIL: Gauss Million expected 500000500000, got " + total

fn test_modulo_periodic
    total = 0
    i = 1
    while i <= 10000000
        total += (i % 7)
        i += 1
    if total == 29999997
        say "PASS: Modulo Periodic (1..10000000 mod 7 = 29999997)"
    else
        say "FAIL: Modulo Periodic expected 29999997, got " + total

fn main
    test_gauss_basic()
    test_gauss_hundred()
    test_gauss_offset()
    test_gauss_million()
    test_modulo_periodic()

main()

fn test_side_effect_fallback
    total = 0
    count = 0
    i = 1
    while i <= 5
        total += i
        count += 1
        i += 1
    if total == 15 and count == 5
        say "PASS: Side-Effect Fallback (total=15, count=5)"
    else
        say "FAIL: Side-Effect Fallback"

test_side_effect_fallback()
