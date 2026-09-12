// ==============================================================================
// 🧪 LIPI TEST: Universal Number Architecture & Gödel Synthesis Verification
// ⚡ Tests prime factorization coordinates, algebraic state reducer execution,
//    register storage transitions, and mathematical program fingerprinting.
// ==============================================================================

include "src/compiler/backend/unum_synthesizer.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi Universal Number (Gödel) Synthesis Engine"
say "========================================================"

// ── Test 1: Mathematical Prime Sequence ───────────────────────────────────────
say "[1/5] Testing Prime Sequence Coordinates..."
assert_eq(unum_prime(0), 2, "Prime index 0 is 2")
assert_eq(unum_prime(1), 3, "Prime index 1 is 3")
assert_eq(unum_prime(2), 5, "Prime index 2 is 5")
assert_eq(unum_prime(3), 7, "Prime index 3 is 7")
assert_eq(unum_prime(4), 11, "Prime index 4 is 11")
assert_eq(unum_prime(9), 29, "Prime index 9 is 29")

// ── Test 2: Gödel Program Synthesis ───────────────────────────────────────────
say "[2/5] Testing Gödel Program Synthesis..."
synth = unum_synthesizer_new()

// Program:
// 0: LOAD_CONST 10
// 1: ADD 25
// 2: STORE_REG 0
// 3: MUL 2
// 4: PRINT_ACC
// 5: HALT 0
unum_emit_op(synth, UNUM_OP_LOAD_CONST, 10)
unum_emit_op(synth, UNUM_OP_ADD, 25)
unum_emit_op(synth, UNUM_OP_STORE_REG, 0)
unum_emit_op(synth, UNUM_OP_MUL, 2)
unum_emit_op(synth, UNUM_OP_PRINT_ACC, 0)
unum_emit_op(synth, UNUM_OP_HALT, 0)

assert_eq(get(synth, 3), 6, "Synthesizer contains 6 statements")

// Generate prime factor coordinates
n_coords = unum_synthesize_godel(synth)
assert_eq(n_coords, 24, "Generated 24 prime coordinate pairs (6 * 4)")

// Verify first statement (LOAD_CONST 10 -> p0=2, op=2, p1=3, arg=10)
coords = get(synth, 2)
assert_eq(get(coords, 0), 2, "First factor base is prime 2")
assert_eq(get(coords, 1), 2, "First factor exponent is OP_LOAD_CONST (2)")
assert_eq(get(coords, 2), 3, "Second factor base is prime 3")
assert_eq(get(coords, 3), 10, "Second factor exponent is operand 10")

// ── Test 3: Algebraic State Transformation Execution ─────────────────────────
say "[3/5] Testing Algebraic State Reducer Execution..."
state = unum_state_new()
steps = unum_state_run_all(synth, state, 100)

assert_eq(steps, 6, "Program executed in exactly 6 transformation steps")
assert_eq(get(state, 4), 1, "Program state reached HALT (1)")

// Initial = 10, + 25 = 35, * 2 = 70
acc = get(state, 0)
assert_eq(acc, 70, "Final accumulator state is 70 (10 + 25) * 2")

// Register 0 should have captured value 35 before multiplication
regs = get(state, 1)
r0 = get(regs, 0)
assert_eq(r0, 35, "Register 0 state captured 35")

// Output log should contain printed value 70
out_log = get(state, 3)
assert_eq(len(out_log), 1, "Output log captured 1 printed value")
assert_eq(get(out_log, 0), 70, "Printed value is 70")

// ── Test 4: Mathematical Program Fingerprint ──────────────────────────────────
say "[4/5] Testing Mathematical Program Fingerprint..."
fp1 = unum_compute_fingerprint(synth)
assert_eq(fp1 != 0, 1, "Generated non-zero 64-bit Gödel fingerprint")

// Fingerprint must be 100% deterministic and reproducible
fp2 = unum_compute_fingerprint(synth)
assert_eq(fp1, fp2, "Fingerprint is 100% bit-for-bit deterministic")

// ── Test 5: Mathematical Formula Rendering ────────────────────────────────────
say "[5/5] Testing Gödel Formula Representation..."
formula = unum_format_formula(synth)
say "  Formula: " + formula
assert_eq(len(formula) > 10, 1, "Rendered valid Gödel prime factorization formula")

say "========================================================"
say "PASS: Lipi Universal Number (Gödel) Synthesis Verified 100%!"
say "========================================================"
