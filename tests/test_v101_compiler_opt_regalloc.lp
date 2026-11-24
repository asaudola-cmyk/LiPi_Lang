// ==============================================================================
// Lipi v1.0.1 Compiler Middle-End & Linear-Scan Register Allocation Test Suite
// File: tests/test_v101_compiler_opt_regalloc.lp
// Covers:
//   1. Strict interior call-crossing analysis (start_pos < call_pos < end_pos)
//   2. ABI-safe register eviction (call-spanning intervals never steal caller regs)
//   3. SSA peephole constant-chain reassociation, shift-chain folding, % 1, & -1
// ==============================================================================

include "src/compiler/backend/regalloc/live_interval.lp"
include "src/compiler/backend/regalloc/linear_scan.lp"
include "src/compiler/middleend/opt/passes/pass_peephole.lp"

fn c101_assert_eq actual expected msg
    if actual != expected
        say "  [FAIL] " + msg + " (expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    end
    say "  [PASS] " + msg + ": " + str(actual)
    return 1

fn main
    say "========================================================================"
    say "Lipi v1.0.1 Compiler Middle-End & Regalloc Verification Suite"
    say "========================================================================"

    // 1. Strict interior call-crossing analysis (start_pos < cp < end_pos)
    ivs = list()
    live_interval_record_def(ivs, "arg_only", 1, 0)
    live_interval_record_use(ivs, "arg_only", 4)
    live_interval_record_def(ivs, "call_ret", 4, 0)
    live_interval_record_use(ivs, "call_ret", 7)
    live_interval_record_def(ivs, "across", 2, 0)
    live_interval_record_use(ivs, "across", 8)
    calls = [4]
    live_interval_mark_calls(ivs, calls)
    iv0 = get(ivs, 0)
    iv1 = get(ivs, 1)
    iv2 = get(ivs, 2)
    c101_assert_eq(iv0.spans_call, 0, "arg_only ending at call pos does not span call")
    c101_assert_eq(iv1.spans_call, 0, "call_ret defined at call pos does not span call")
    c101_assert_eq(iv2.spans_call, 1, "across (2..8) crossing call at 4 spans call")

    // 2. ABI eviction safety: call-spanning interval MUST NOT steal caller-saved register
    callers = [7]
    callees = [12]
    a_ivs = list()
    push(a_ivs, create_test_interval("leaf_long", 0, 50, 0))
    push(a_ivs, create_test_interval("callee_a", 1, 20, 1))
    push(a_ivs, create_test_interval("callee_b", 2, 10, 1))
    ra = linear_scan_allocate(a_ivs, callers, callees, 8)
    a0 = get(a_ivs, 0)
    a1 = get(a_ivs, 1)
    a2 = get(a_ivs, 2)
    c101_assert_eq(ra.spill_count, 1, "exactly 1 interval spilled under register contention")
    c101_assert_eq(a0.assigned_reg, 7, "leaf_long retained caller-saved register 7")
    c101_assert_eq(a2.assigned_reg, 12, "callee_b evicted callee-saved reg 12 (never stole caller reg 7)")
    c101_assert_eq(a1.is_spilled, 1, "callee_a (furthest compatible callee interval) spilled cleanly")

    // 3. SSA Peephole: (x + 10) + 25 -> x + 35, (y << 2) << 3 -> y << 5, z & -1 -> z, x % 1 -> 0
    fn_obj = ir_function_new("v101_peep", "i64")
    bb = fn_obj.entry_block
    px = ssa_value_new_arg("%x", "i64")
    fn_obj.add_param(px)
    c10 = ssa_value_new_const(10, "i64")
    c25 = ssa_value_new_const(25, "i64")
    c2 = ssa_value_new_const(2, "i64")
    c3 = ssa_value_new_const(3, "i64")
    c1 = ssa_value_new_const(1, "i64")
    cm1 = ssa_value_new_const(0 - 1, "i64")

    v1 = fn_obj.new_val("i64")
    basic_block_append_inst(bb, ir_build_binop(1, OP_ADD, v1, px, c10))
    v2 = fn_obj.new_val("i64")
    i_add2 = ir_build_binop(2, OP_ADD, v2, v1, c25)
    basic_block_append_inst(bb, i_add2)

    v3 = fn_obj.new_val("i64")
    basic_block_append_inst(bb, ir_build_binop(3, OP_SHL, v3, v2, c2))
    v4 = fn_obj.new_val("i64")
    i_shl2 = ir_build_binop(4, OP_SHL, v4, v3, c3)
    basic_block_append_inst(bb, i_shl2)

    v5 = fn_obj.new_val("i64")
    basic_block_append_inst(bb, ir_build_binop(5, OP_AND, v5, v4, cm1))

    v6 = fn_obj.new_val("i64")
    basic_block_append_inst(bb, ir_build_binop(6, OP_MOD, v6, px, c1))

    v7 = fn_obj.new_val("i64")
    basic_block_append_inst(bb, ir_build_binop(7, OP_ADD, v7, v5, v6))
    basic_block_append_inst(bb, ir_build_ret(8, v7))

    hits = pass_peephole_run(fn_obj)
    op_add_r = get(i_add2.operands, 1)
    op_shl_r = get(i_shl2.operands, 1)
    c101_assert_eq(hits >= 4, 1, "peephole applied >= 4 rewrites (chain add, chain shl, & -1, % 1)")
    c101_assert_eq(op_add_r.const_val, 35, "constant chain (x + 10) + 25 folded to x + 35")
    c101_assert_eq(op_shl_r.const_val, 5, "shift chain (y << 2) << 3 folded to y << 5")

    say "========================================================================"
    say "ALL LIPI v1.0.1 COMPILER OPT & REGALLOC TESTS PASSED!"
    say "========================================================================"
    return 0

main()
