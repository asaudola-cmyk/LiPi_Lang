// ==============================================================================
// 🧪 WAVE E CORE COMPILER & RUNTIME VERIFICATION SUITE
// 🏛️ File: tests/test_wave_e_core_fixes.lp
// Verifies:
//   E1: Dict float preservation (homogeneous & heterogeneous dicts, str(), arithmetic,
//       comparisons, unary -, compound +=, rehash tag preservation, local binding)
//   E2: defer LIFO execution on cross-frame throw unwinding + conditional defer + try/catch
//   E3: Catchable NullPointerException on null struct field read & write (zero SIGSEGV!)
//   E4: Clean Stage 3 undefined-function error (verified by negative self-compile check)
// ==============================================================================

struct NodeE
    v: int
    next: NodeE
end

G_DEFER_LOG = []

fn check_assert(cond, label)
    if cond == 0
        print("FAIL: " + label)
        exit(1)
    end
    return 0
end

fn e2_inner_throw(do_second)
    defer push(G_DEFER_LOG, "inner_1")
    if do_second == 1
        defer push(G_DEFER_LOG, "inner_2_cond")
    end
    throw "err_from_inner"
end

fn e2_mid_frame(do_second)
    defer push(G_DEFER_LOG, "mid_cleanup")
    e2_inner_throw(do_second)
    return 99
end

fn e2_early_return(flag)
    if flag == 1
        return 7
    end
    defer push(G_DEFER_LOG, "late_defer_should_not_run_on_early")
    return 8
end

fn e2_normal_lifo()
    defer push(G_DEFER_LOG, "norm_first")
    defer push(G_DEFER_LOG, "norm_second")
    return 42
end

fn e3_deref_read(p: NodeE)
    return p.v
end

fn e3_deref_write(p: NodeE)
    p.v = 123
    return 0
end

fn main()
    // ── E1: Dict Float Preservation (Exact Reproducer + Deep Torture) ─────────
    d = { "pi": 3.14, "n": 42, "s": "lipi" }
    arr = [2.5, 3.5]
    check_assert(str(arr[0]) == "2.5", "E1: float array str")
    check_assert(str(d["pi"]) == "3.14", "E1: dict float str")
    check_assert(str(d["n"]) == "42", "E1: mixed dict int str")
    check_assert(d["s"] == "lipi", "E1: mixed dict string")

    // Float arithmetic & comparisons directly on dict lookup
    sum_f = d["pi"] + 1.0
    check_assert(str(sum_f) == "4.14", "E1: d[pi] + 1.0 == 4.14")
    mul_f = d["pi"] * 2.0
    check_assert(str(mul_f) == "6.28", "E1: d[pi] * 2.0 == 6.28")
    check_assert(d["pi"] > 3.0 and d["pi"] < 3.2, "E1: dict float relational compare")
    check_assert(d["pi"] == 3.14, "E1: dict float == 3.14")
    neg_f = -d["pi"]
    check_assert(str(neg_f) == "-3.14", "E1: unary -d[pi]")

    // Local variable binding preserves dynamic tag
    v_pi = d["pi"]
    check_assert(str(v_pi) == "3.14", "E1: local copy str(v_pi)")
    check_assert(str(v_pi + 2.0) == "5.14", "E1: local copy v_pi + 2.0")

    // Index assignment + compound += + dict rehash (>16 entries) preserve float tags!
    d["e"] = 2.718
    check_assert(str(d["e"]) == "2.718", "E1: assigned float tag")
    d["e"] += 1.0
    check_assert(str(d["e"]) == "3.718", "E1: compound += on dict float")
    d["n"] += 8
    check_assert(d["n"] == 50, "E1: compound += on dict int")

    // Force multiple rehashes (64 keys) and verify float & int tags survive intact
    ri = 0
    while ri < 64
        d["k_" + str(ri)] = 1.5
        ri = ri + 1
    end
    check_assert(str(d["pi"]) == "3.14", "E1: float tag survives rehash (pi)")
    check_assert(str(d["k_63"]) == "1.5", "E1: float tag survives rehash (k_63)")
    check_assert(str(d["k_0"] + d["k_63"]) == "3.0", "E1: dyn_float + dyn_float == 3.0")
    check_assert(d["n"] == 50, "E1: int tag survives rehash")

    // Delete & backward-shift preserves adjacent float tags
    del_key(d, "k_10")
    check_assert(str(d["k_11"]) == "1.5", "E1: float tag survives backward-shift delete")
    print("PASS E1: Dict float preservation verified")

    // ── E2: defer on throw / Multi-Frame Exception Unwinding ──────────────────
    caught = ""
    try
        e2_mid_frame(1)
    catch e
        caught = e
    end
    check_assert(caught == "err_from_inner", "E2: outer caught err_from_inner")
    check_assert(G_DEFER_LOG.len() == 3, "E2: all 3 defers ran on unwind")
    check_assert(G_DEFER_LOG[0] == "inner_2_cond", "E2: LIFO 0 == inner_2_cond")
    check_assert(G_DEFER_LOG[1] == "inner_1", "E2: LIFO 1 == inner_1")
    check_assert(G_DEFER_LOG[2] == "mid_cleanup", "E2: LIFO 2 == mid_cleanup")

    // Conditional defer NOT executed must NOT run on throw!
    G_DEFER_LOG = []
    caught2 = ""
    try
        e2_mid_frame(0)
    catch e2
        caught2 = e2
    end
    check_assert(caught2 == "err_from_inner", "E2: cond caught")
    check_assert(G_DEFER_LOG.len() == 2, "E2: skipped cond defer did NOT run")
    check_assert(G_DEFER_LOG[0] == "inner_1" and G_DEFER_LOG[1] == "mid_cleanup", "E2: cond LIFO order")

    // Early return before defer must pop unwind frame cleanly and NOT run unreached defer!
    G_DEFER_LOG = []
    check_assert(e2_early_return(1) == 7, "E2: early return before defer")
    check_assert(G_DEFER_LOG.len() == 0, "E2: unreached defer did not run on early return")

    // Normal return LIFO still works
    check_assert(e2_normal_lifo() == 42, "E2: normal return value")
    check_assert(G_DEFER_LOG.len() == 2 and G_DEFER_LOG[0] == "norm_second" and G_DEFER_LOG[1] == "norm_first", "E2: normal LIFO")
    print("PASS E2: defer unwind on throw & normal return verified")

    // ── E3: Catchable NullPointerException on Null Struct Deref ───────────────
    p_null: NodeE = 0
    npe_read = ""
    try
        x_bad = e3_deref_read(p_null)
        check_assert(0 == 1, "E3: null read must throw")
    catch err_r
        npe_read = err_r
    end
    check_assert(npe_read == "NullPointerException: null struct dereference", "E3: null struct read caught cleanly")

    npe_write = ""
    try
        e3_deref_write(p_null)
        check_assert(0 == 1, "E3: null write must throw")
    catch err_w
        npe_write = err_w
    end
    check_assert(npe_write == "NullPointerException: null struct dereference", "E3: null struct write caught cleanly")

    // Valid struct read/write remains fast and unaffected
    ok_node = NodeE(77, 0)
    check_assert(ok_node.v == 77, "E3: valid struct read")
    ok_node.v = 88
    check_assert(ok_node.v == 88, "E3: valid struct write")
    print("PASS E3: NullPointerException guard verified")

    print("ALL WAVE E CORE FIXES PASSED!")
    return 0
end
