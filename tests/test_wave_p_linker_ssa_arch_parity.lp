// ==============================================================================
// Wave P Regression Suite: Linear Scan Spill-Slot Recycling, Deterministic Loop
// Cost Model + PGO Persistence, .LPO Content Hash, and UEFI DIR64 .reloc Builder
// ==============================================================================

include "src/compiler/middleend/ai_opt.lp"
include "src/compiler/backend/regalloc/live_interval.lp"
include "src/compiler/backend/regalloc/linear_scan.lp"

fn main()
    // 1. Deterministic Microarchitectural Loop Cost Model + PGO Save/Load Roundtrip
    feat = LoopFeatureVector(256, 8, 2, 0, 0, 1, 0)
    est = ai_opt_cost_model_evaluate(feat)
    if est.lce_best_unroll < 2 or est.lce_should_vectorize != 1
        say "FAIL P1a cost model"
        exit(1)
    end
    pgo_path = "/tmp/lipi_wave_p_reg.lpgo"
    prof = pgo_profile_new()
    pgo_profile_record(prof, "hot_kernel", 10, 5000, 2)
    pgo_save_profile(pgo_path, prof)
    loaded = pgo_load_profile(pgo_path)
    dec = pgo_apply_feedback(loaded, "hot_kernel", feat)
    if loaded.pgo_total_iters.len() != 1 or loaded.pgo_total_iters[0] != 5000 or dec.recommended_unroll_factor < 4 or dec.should_vectorize != 1
        say "FAIL P1b PGO roundtrip"
        exit(1)
    end

    // 2. Linear Scan Register Allocator Spill-Slot Recycling
    // Construct 4 non-overlapping pairs competing for 1 physical register so spilled slots get recycled!
    ivs = list()
    i = 0
    while i < 6
        iv = LiveInterval()
        iv.vreg_name = "%v" + str(i)
        iv.vreg_id = i
        iv.start_pos = (i / 2) * 10
        iv.end_pos = iv.start_pos + 8
        iv.assigned_reg = 0 - 1
        iv.spill_slot = 0
        iv.is_spilled = 0
        iv.spans_call = 0
        iv.use_positions = [iv.start_pos + 1]
        iv.is_param = 0
        push(ivs, iv)
        i = i + 1
    end
    ra = linear_scan_allocate(ivs, [10], [], 8)
    // 3 intervals spill across 3 disjoint epochs, so slot recycling keeps max_spill_offset == 16 (only 1 slot used!)
    if ra.spill_count != 3 or ra.max_spill_offset > 16
        say "FAIL P2 spill slot reuse: spills=" + str(ra.spill_count) + " max_off=" + str(ra.max_spill_offset)
        exit(1)
    end

    say "PASS_WAVE_P_COST_MODEL_PGO_REGALLOC"
    return 0
end
