// ==============================================================================
// 🌐 LIPI BILINGUAL SYNTAX SHOWCASE: 100% ENGLISH INTEROPERABILITY (examples/42_bilingual_english_syntax.lp)
// ⚡ Writing Lipi using standard international syntax (let, fn, while, print, return)
// ==============================================================================

// WHY: To replace C, Rust, Go, Python and JS globally, international developers
// must be able to use standard programming vocabulary (let, fn, if, while, print, return)
// seamlessly, alongside Lipi's native Bengali keywords (, fn, if, while, say, return).

include "std/io.lp"

fn compute_sum limit
    let total = 0
    let i = 1
    while i <= limit
        total = total + (i % 7)
        i = i + 1
    return total

fn main
    show "======================================================="
    show "👑 BILINGUAL LIPI SYNTAX TEST: 100% INTERNATIONAL MODE"
    show "======================================================="

    let result = compute_sum(100)
    show "Sum of (i % 7) for 1..100: " + result

    let val = 42
    if val > 40
        show "Value is greater than 40: " + val
    else
        show "Value is small"

    show "✔ International developers can now write Lipi natively!"
    return 0

main()
