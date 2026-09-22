// ==============================================================================
// 👑 LIPI TEST SUITE: FIRST-CLASS CLOSURES & STRUCTURAL TRAIT PROTOCOLS
// ⚡ 100% Pure LiPi Implementation | Zero C | Zero OOP Inheritance Hell
// 🏛️ File: tests/test_closure_and_traits.lp
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/string.lp"
include "universe/core/closure.lp"
include "universe/core/trait.lp"

fn assert_eq_num actual expected msg
    if actual != expected
        say "  [FAIL] " + msg + " (Expected: " + str(expected) + ", Got: " + str(actual) + ")"
        return 0
    say "  [PASS] " + msg
    return 1

fn assert_true cond msg
    if cond == 0
        say "  [FAIL] " + msg
        return 0
    say "  [PASS] " + msg
    return 1

fn main
    say "================================================================="
    say "👑 TESTING LIPI SOVEREIGN CLOSURES & STRUCTURAL TRAITS"
    say "================================================================="

    total_pass = 0

    // ── 1. Lexical Closure Environment Capture ────────────────────────────────
    say "▶ Phase 1: Lexical Closure Environment Binding..."
    env = list()
    push(env, 10) // Captured factor = 10
    cl_mul10 = closure_new(1, env, 1)

    captured_val = closure_env_get(cl_mul10, 0)
    pass1 = assert_eq_num(captured_val, 10, "Captured environment variable correctly retrieved (10)")
    total_pass = total_pass + pass1

    // ── 2. Higher-Order Functional Map Pipeline ───────────────────────────────
    say "▶ Phase 2: Higher-Order Functional Map Pipeline..."
    src_list = list()
    push(src_list, 1)
    push(src_list, 2)
    push(src_list, 3)
    push(src_list, 4)

    mapped = closure_map(src_list, cl_mul10)
    ok_len = mapped.len() == 4
    ok_vals = mapped[0] == 10 && mapped[1] == 20 && mapped[2] == 30 && mapped[3] == 40
    pass2 = assert_true(ok_len && ok_vals, "closure_map successfully transformed [1,2,3,4] -> [10,20,30,40]")
    total_pass = total_pass + pass2

    // ── 3. Higher-Order Functional Filter Pipeline ────────────────────────────
    say "▶ Phase 3: Higher-Order Functional Filter Pipeline..."
    filter_env = list()
    push(filter_env, 15) // Keep elements > 15
    cl_filter = closure_new(10, filter_env, 1)

    filtered = closure_filter(mapped, cl_filter)
    ok_filt = filtered.len() == 3 && filtered[0] == 20 && filtered[1] == 30 && filtered[2] == 40
    pass3 = assert_true(ok_filt, "closure_filter successfully retained elements > 15 -> [20,30,40]")
    total_pass = total_pass + pass3

    // ── 4. Higher-Order Functional Fold/Reduce ─────────────────────────────────
    say "▶ Phase 4: Higher-Order Functional Reduce Pipeline..."
    cl_sum = closure_new(20, list(), 2)
    sum_res = closure_reduce(filtered, cl_sum, 0)
    pass4 = assert_eq_num(sum_res, 90, "closure_reduce computed correct accumulator sum (20+30+40 == 90)")
    total_pass = total_pass + pass4

    // ── 5. Structural Trait Protocol Satisfaction ─────────────────────────────
    say "▶ Phase 5: Structural Trait Protocol Verification..."
    req_methods = list()
    push(req_methods, "to_json")
    push(req_methods, "validate")
    trait_serializable = trait_def_new("Serializable", req_methods)

    struct_methods = list()
    push(struct_methods, "save")
    push(struct_methods, "to_json")
    push(struct_methods, "validate")
    push(struct_methods, "delete")

    satisfies = trait_check_satisfies(trait_serializable, struct_methods)
    pass5 = assert_eq_num(satisfies, 1, "Struct methods structurally satisfy Trait 'Serializable'")
    total_pass = total_pass + pass5

    // ── 6. Structural Trait Protocol Rejection & Diagnostics ──────────────────
    say "▶ Phase 6: Trait Protocol Failure Diagnostics..."
    bad_methods = list()
    push(bad_methods, "save")
    push(bad_methods, "delete")

    satisfies_bad = trait_check_satisfies(trait_serializable, bad_methods)
    pass6 = assert_eq_num(satisfies_bad, 0, "Missing required methods correctly triggers trait violation (0)")
    total_pass = total_pass + pass6

    err_msg = trait_format_error(trait_serializable, "UserRecord", bad_methods)
    pass7 = assert_true(len(err_msg) > 0, "Trait violation diagnostic emitted cleanly")
    total_pass = total_pass + pass7

    say "================================================================="
    say "🎉 CLOSURE & TRAIT TESTS PASSED: " + str(total_pass) + "/7"
    say "================================================================="
    return 0

main()
