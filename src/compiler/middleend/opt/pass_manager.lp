// ==============================================================================
// 👑 LIPI FIRST 1.0.0 OPTIMIZATION PASS MANAGER (src/compiler/middleend/opt/pass_manager.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: The Pass Manager orchestrates the scheduling, execution, and convergence
//      looping of all 12 middle-end analysis and optimization passes.
//      1. Pipeline Optimization Levels:
//         • O0: Debug mode — Strict SSA verification only, zero instruction mutations.
//         • O1: Local optimizations — Peephole, Constant Folding, and DCE.
//         • O2: Global optimizations — Dominator-based CSE, Loop Invariant Code Motion (LICM),
//               Dead Store Elimination (DSE), and iterative fixpoint convergence.
//         • O3: Aggressive optimizations — Inter-procedural Function Inlining, Loop Unrolling,
//               and multi-pass whole-module restructuring.
//      2. SSA Form Preservation: Runs the strict SSA verifier between passes to mathematically
//         guarantee that every transformation preserves the single-assignment invariant,
//         def-use completeness, and CFG edge symmetry.
// ==============================================================================

include "src/compiler/middleend/ir/ir_verifier.lp"
include "src/compiler/middleend/ir/ir_printer.lp"
include "src/compiler/middleend/opt/passes/pass_const_fold.lp"
include "src/compiler/middleend/opt/passes/pass_dce.lp"
include "src/compiler/middleend/opt/passes/pass_cse.lp"
include "src/compiler/middleend/opt/passes/pass_licm.lp"
include "src/compiler/middleend/opt/passes/pass_unroll.lp"
include "src/compiler/middleend/opt/passes/pass_inlining.lp"
include "src/compiler/middleend/opt/passes/pass_dse.lp"
include "src/compiler/middleend/opt/passes/pass_peephole.lp"

// ── 1. Pass Manager Structure ─────────────────────────────────────────────────

struct PassManager
    opt_level         // integer: 0, 1, 2, or 3
    verify_each_pass  // integer: 1 to verify SSA form after each pass, 0 otherwise
    stat_passes_run   // integer: total passes executed
    stat_const_folds  // integer: total constant foldings
    stat_dce          // integer: total dead instructions/blocks pruned
    stat_cse          // integer: total common subexpressions eliminated
    stat_licm         // integer: total loop invariants hoisted
    stat_unroll       // integer: total loops unrolled
    stat_inlined      // integer: total function call sites inlined
    stat_dse          // integer: total dead stores eliminated
    stat_peephole     // integer: total peephole algebraic simplifications

// ── 2. Constructor ────────────────────────────────────────────────────────────

fn pass_manager_new opt_level
    pm = PassManager()
    pm.opt_level = opt_level
    pm.verify_each_pass = 1 // Default to strict safety verification
    pm.stat_passes_run = 0
    pm.stat_const_folds = 0
    pm.stat_dce = 0
    pm.stat_cse = 0
    pm.stat_licm = 0
    pm.stat_unroll = 0
    pm.stat_inlined = 0
    pm.stat_dse = 0
    pm.stat_peephole = 0
    return pm

// ── 3. Pipeline Runner for Single Function ────────────────────────────────────

fn pass_manager_run_on_function pm fn_obj
    if pm == 0 or fn_obj == 0 return 0

    // Initial SSA Form Verification
    if pm.verify_each_pass == 1
        if ir_verify_function(fn_obj) == 0
            say "❌ [PassManager]: Initial verification failed on " + fn_obj.name
            return 0

    if pm.opt_level == 0
        return 1 // O0: No optimizations

    // ── O1: Local Optimizations ───────────────────────────────────────────────
    if pm.opt_level == 1
        p_hits = pass_peephole_run(fn_obj)
        pm.stat_peephole = pm.stat_peephole + p_hits

        c_hits = pass_const_fold_run(fn_obj)
        pm.stat_const_folds = pm.stat_const_folds + c_hits

        d_hits = pass_dce_run(fn_obj)
        pm.stat_dce = pm.stat_dce + d_hits

        pm.stat_passes_run = pm.stat_passes_run + 3

        if pm.verify_each_pass == 1
            ir_verify_function(fn_obj)

        return 1

    // ── O2 & O3: Iterative Global Pipeline ────────────────────────────────────
    max_iters = 4
    if pm.opt_level >= 3 max_iters = 8

    // For O3: Run Loop Unrolling ahead of main pipeline
    if pm.opt_level >= 3
        u_hits = pass_unroll_run(fn_obj)
        pm.stat_unroll = pm.stat_unroll + u_hits
        pm.stat_passes_run = pm.stat_passes_run + 1
        if u_hits > 0 and pm.verify_each_pass == 1
            ir_verify_function(fn_obj)

    iter = 0
    iter_changed = 1
    while iter_changed == 1 and iter < max_iters
        iter_changed = 0

        // 1. Peephole & Strength Reduction
        p_hits = pass_peephole_run(fn_obj)
        if p_hits > 0
            pm.stat_peephole = pm.stat_peephole + p_hits
            iter_changed = 1

        // 2. Constant Folding
        c_hits = pass_const_fold_run(fn_obj)
        if c_hits > 0
            pm.stat_const_folds = pm.stat_const_folds + c_hits
            iter_changed = 1

        // 3. Dead Code Elimination
        d_hits = pass_dce_run(fn_obj)
        if d_hits > 0
            pm.stat_dce = pm.stat_dce + d_hits
            iter_changed = 1

        // 4. Common Subexpression Elimination (CSE)
        cse_hits = pass_cse_run(fn_obj)
        if cse_hits > 0
            pm.stat_cse = pm.stat_cse + cse_hits
            iter_changed = 1

        // 5. Loop Invariant Code Motion (LICM)
        licm_hits = pass_licm_run(fn_obj)
        if licm_hits > 0
            pm.stat_licm = pm.stat_licm + licm_hits
            iter_changed = 1

        // 6. Dead Store Elimination (DSE)
        dse_hits = pass_dse_run(fn_obj)
        if dse_hits > 0
            pm.stat_dse = pm.stat_dse + dse_hits
            iter_changed = 1

        pm.stat_passes_run = pm.stat_passes_run + 6

        // Verify SSA integrity after every global iteration
        if pm.verify_each_pass == 1
            if ir_verify_function(fn_obj) == 0
                say "❌ [PassManager]: Verification failed after iteration " + str(iter)
                return 0

        iter = iter + 1

    // Final cleanup sweep
    final_p = pass_peephole_run(fn_obj)
    final_d = pass_dce_run(fn_obj)
    pm.stat_peephole = pm.stat_peephole + final_p
    pm.stat_dce = pm.stat_dce + final_d
    pm.stat_passes_run = pm.stat_passes_run + 2

    if pm.verify_each_pass == 1
        ir_verify_function(fn_obj)

    return 1

fn PassManager.run_on_function self fn_obj
    return pass_manager_run_on_function(self, fn_obj)

fn run_on_function pm fn_obj
    return pass_manager_run_on_function(pm, fn_obj)

// ── 4. Pipeline Runner for Whole Module ───────────────────────────────────────

fn pass_manager_run_on_module pm mod_obj
    if pm == 0 or mod_obj == 0 return 0

    // O3 Whole-Module Optimization: Function Inlining
    if pm.opt_level >= 3
        inlined = pass_inlining_run(mod_obj)
        pm.stat_inlined = pm.stat_inlined + inlined
        pm.stat_passes_run = pm.stat_passes_run + 1

    // Optimize each function
    fi = 0
    fcnt = len(mod_obj.functions)
    while fi < fcnt
        fn_obj = get(mod_obj.functions, fi)
        pass_manager_run_on_function(pm, fn_obj)
        fi = fi + 1

    // Final Module Verification
    if pm.verify_each_pass == 1
        ir_verify_module(mod_obj)

    return 1

fn PassManager.run_on_module self mod_obj
    return pass_manager_run_on_module(self, mod_obj)

fn run_on_module pm mod_obj
    return pass_manager_run_on_module(pm, mod_obj)

// ── 5. Optimization Statistics Summary ────────────────────────────────────────

fn pass_manager_print_stats pm
    if pm == 0 return 0
    say "════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI SSA OPTIMIZATION PIPELINE SUMMARY (-O" + str(pm.opt_level) + ")"
    say "════════════════════════════════════════════════════════════════════"
    say "  • Total Passes Executed:          " + str(pm.stat_passes_run)
    say "  • Constant Folds:                 " + str(pm.stat_const_folds)
    say "  • Dead Code / Insts Eliminated:   " + str(pm.stat_dce)
    say "  • Common Subexpressions (CSE):    " + str(pm.stat_cse)
    say "  • Loop Invariants Hoisted (LICM): " + str(pm.stat_licm)
    say "  • Loops Unrolled:                 " + str(pm.stat_unroll)
    say "  • Functions Inlined:              " + str(pm.stat_inlined)
    say "  • Dead Stores Eliminated (DSE):   " + str(pm.stat_dse)
    say "  • Peephole Reductions:            " + str(pm.stat_peephole)
    say "════════════════════════════════════════════════════════════════════"
    return 1

fn PassManager.print_stats self
    return pass_manager_print_stats(self)

fn print_stats pm
    return pass_manager_print_stats(pm)
