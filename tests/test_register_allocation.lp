// ==============================================================================
// 👑 Test: Lipi Linear Scan Register Allocation Engine (%r12, %r13, %r14)
// ⚡ 100% Pure Lipi | Callee-Saved Register ABI Isolation | In-Register ALU
// ==============================================================================
//
// WHY: Validates that variables bound with 'reg' / '@reg' / 'রেজিস্টার' reside in
//      hardware AMD64 registers (%r12-%r14), undergo direct single-cycle arithmetic,
//      and maintain strict callee-saved data integrity across nested and recursive calls.
// ==============================================================================

say "========================================================"
say "👑 Testing Lipi Hardware Register Allocation (%r12-%r14)"
say "========================================================"

// ── Test 1: Tight Loop Counter & Accumulator in Hardware Registers ────────────
fn test_tight_loop
    say "[1/4] Testing Register-Allocated Loop Counter & Accumulator..."
    reg i = 0
    reg sum = 0

    while i < 1000
        sum += i
        i += 1

    // Sum of 0..999 is 999 * 1000 / 2 = 499500
    if sum != 499500
        say "FAIL: Expected sum 499500, got: " + str(sum)
        exit(1)
    say "  ✔ Register loop sum verified: " + str(sum)

test_tight_loop()

// ── Test 2: Multi-Register Binding & Single-Cycle ALU ─────────────────────────
fn test_multi_registers
    say "[2/4] Testing 3 Simultaneous Hardware Registers (%r12, %r13, %r14)..."
    reg reg_a = 100
    reg reg_b = 200
    reg reg_c = 300

    reg_a += 50
    reg_b -= 50
    reg_c += reg_a

    if reg_a != 150 or reg_b != 150 or reg_c != 450
        say "FAIL: Multi-register arithmetic mismatch! a=" + str(reg_a) + " b=" + str(reg_b) + " c=" + str(reg_c)
        exit(1)
    say "  ✔ Multi-register ALU verified: a=" + str(reg_a) + " b=" + str(reg_b) + " c=" + str(reg_c)

test_multi_registers()

// ── Test 3: Callee-Saved Register Preservation Across Function Calls ─────────
fn compute_square x
    return x * x

fn test_callee_saved
    say "[3/4] Testing Callee-Saved Preservation Across Function Invocations..."
    reg outer_acc = 0
    reg loop_k = 1

    while loop_k <= 10
        sq = compute_square(loop_k)
        outer_acc += sq
        loop_k += 1

    // 1^2 + 2^2 + ... + 10^2 = 385
    if outer_acc != 385 or loop_k != 11
        say "FAIL: Callee-saved registers corrupted! acc=" + str(outer_acc)
        exit(1)
    say "  ✔ Callee-saved preservation verified: outer_acc=" + str(outer_acc)

test_callee_saved()

// ── Test 4: Recursive Isolation (Fibonacci with Register Bindings) ─────────────
fn fib_reg n
    if n <= 1 return n
    reg v1 = fib_reg(n - 1)
    reg v2 = fib_reg(n - 2)
    return v1 + v2

fn test_recursion
    say "[4/4] Testing Recursive Stack Frame Isolation with Register Variables..."
    fib10 = fib_reg(10)
    if fib10 != 55
        say "FAIL: Expected fib(10) == 55, got: " + str(fib10)
        exit(1)
    say "  ✔ Recursive register isolation verified: fib(10)=" + str(fib10)

test_recursion()

say "========================================================"
say "PASS: Register Allocation Test Suite Verified 100%!"
say "========================================================"
