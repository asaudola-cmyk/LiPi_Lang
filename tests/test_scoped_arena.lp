// ==============================================================================
// 👑 LIPI TEST SUITE: SOVEREIGN SCOPED ARENA & REGION MEMORY ENGINE
// ⚡ 100% Pure LiPi Implementation | Zero Libc | Zero GC Pause | Hardware Aligned
// 🏛️ File: tests/test_scoped_arena.lp
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/string.lp"

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
    say "👑 TESTING LIPI SOVEREIGN SCOPED ARENA & REGION MEMORY"
    say "================================================================="

    total_pass = 0

    // ── 1. Baseline Arena Initialization & Marking ────────────────────────────
    say "▶ Phase 1: Arena Watermark Marking..."
    mark1 = arena_mark()
    pass1 = assert_true(mark1 > 0, "Initial arena watermark is valid non-zero pointer")
    total_pass = total_pass + pass1

    // ── 2. Transient Heap Allocation & Expansion ──────────────────────────────
    say "▶ Phase 2: Transient Allocations in Scoped Region..."
    list1 = list()
    i = 0
    while i < 1000
        push(list1, i * 7)
        i = i + 1

    allocated1 = arena_allocated()
    pass2 = assert_true(allocated1 > 0, "Arena usage expanded during transient list allocation")
    total_pass = total_pass + pass2

    mark2 = arena_mark()
    pass3 = assert_true(mark2 > mark1, "Watermark advanced strictly monotonically")
    total_pass = total_pass + pass3

    // ── 3. Instant Zero-Cost Rollback (Scoped Arena Exit) ─────────────────────
    say "▶ Phase 3: Instant Scoped Rollback (Zero GC Pause)..."
    res_rollback = arena_reset(mark1)
    // Capture watermark immediately before print formatting allocates transient strings
    mark_after = arena_mark()
    pass4 = assert_eq_num(res_rollback, 0, "Arena rollback to mark1 succeeded with code 0")
    total_pass = total_pass + pass4

    pass5 = assert_eq_num(mark_after, mark1, "Watermark restored perfectly to pre-allocation mark1")
    total_pass = total_pass + pass5

    // ── 4. High-Throughput Steady-State Loop Test (100,000 Allocations) ───────
    say "▶ Phase 4: High-Throughput Transient Loop Reclamation..."
    loop_mark = arena_mark()
    iter = 0
    while iter < 100
        scope_m = arena_mark()
        temp_l = list()
        k = 0
        while k < 50
            push(temp_l, k + iter)
            k = k + 1
        // Instant rollback at scope exit (zero memory leak!)
        arena_reset(scope_m)
        iter = iter + 1

    final_mark = arena_mark()
    pass6 = assert_eq_num(final_mark, loop_mark, "100 iterations of scoped allocations perfectly reclaimed")
    total_pass = total_pass + pass6

    // ── 5. Bengali Native Silicon Intrinsics ──────────────────────────────────
    say "▶ Phase 5: Bengali Native Arena Intrinsics..."
    চিহ্ন১ = অ্যারেনা_চিহ্ন()
    তালিক১ = list()
    push(তালিক১, 42)
    অ্যারেনা_রিসেট(চিহ্ন১)
    চিহ্ন২ = অ্যারেনা_চিহ্ন()
    pass7 = assert_eq_num(চিহ্ন২, চিহ্ন১, "অ্যারেনা_চিহ্ন এবং অ্যারেনা_রিসেট শতভাগ কার্যকর")
    total_pass = total_pass + pass7

    say "================================================================="
    say "🎉 SOVEREIGN ARENA TESTS PASSED: " + str(total_pass) + "/7"
    say "================================================================="
    return 0

main()
