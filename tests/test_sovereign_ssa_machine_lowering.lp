// ==============================================================================
// 👑 LIPI TEST 207: SOVEREIGN DIRECT SSA LOWERING & MULTI-SILICON HARDWARE ENGINE
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// 🏛️ File: tests/test_sovereign_ssa_machine_lowering.lp
// ==============================================================================
//
// WHY THIS TEST:
// 1. Validates the Sovereign Direct SSA-to-Machine Silicon Lowering Engine:
//    - Constructs an authentic SSA module with control flow graph (CFG) and basic blocks.
//    - Lowers OP_ALLOCA, OP_STORE, OP_LOAD, OP_ADD, OP_MUL, OP_CMP, OP_BR, OP_RET
//      directly into executable AMD64 machine code bytes without token re-parsing.
//    - Verifies deterministic jump displacement backpatching between basic blocks.
// 2. Hardware Direct Rendering Manager (DRM) GPU Engine:
//    - Tests direct kernel GPU node discovery (/dev/dri/renderD128, /dev/dri/card0)
//      with resilient fallback for sandboxed/unprivileged container environments.
// 3. Multi-Silicon Vector Instruction Encoders:
//    - Verifies ARM64 128-bit NEON SIMD vector instruction words (ADD.4S, SUB.4S, MUL.4S, LD1, ST1).
//    - Verifies RISC-V RV64V Vector Extension 1.0 instruction words (vsetvli, vle32.v, vadd.vv, vmul.vv, vse32.v).
// ==============================================================================

include "src/compiler/backend/ssa_lowerer.lp"
include "src/compiler/backend/targets/arm64/synthesizer.lp"
include "src/compiler/backend/targets/riscv64/synthesizer.lp"
include "aati/lipi_gpu/compute.lp"
include "utso/io.lp"

fn test_assert cond msg
    if cond == 0
        say "❌ [ASSERTION FAILED]: " + msg
        exit(1)
    end
    say "  ✔ PASS: " + msg
    return 1

fn find_subseq haystack needle
    if needle.len() == 0 return 1
    if haystack.len() < needle.len() return 0
    limit = haystack.len() - needle.len()
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < needle.len()
            if haystack[i + j] != needle[j]
                match = 0
                break
            end
            j = j + 1
        end
        if match == 1 return 1
        i = i + 1
    end
    return 0

fn main
    say "========================================================================"
    say "👑 TEST 207: SOVEREIGN DIRECT SSA LOWERING & MULTI-SILICON HARDWARE ENGINE"
    say "========================================================================"

    // ── Phase 1: Direct SSA Graph Construction & Lowering ────────────────────
    say "\n▶ [Phase 1]: Constructing SSA IR Module with CFG & Operations..."
    ir_mod = ir_module_new("test_direct_ssa", "x86_64")
    fn_compute = ir_function_new("compute_total", "i64")
    ir_module_add_function(ir_mod, fn_compute)

    // Entry Block (bb0)
    bb0 = fn_compute.entry_block
    bb0.label = "bb0"

    // Then Block (bb1)
    bb1 = basic_block_new("bb1", fn_compute)
    ir_function_add_block(fn_compute, bb1)

    // Construct SSA instructions in bb0:
    // %slot_a = alloca i64
    slot_a = ssa_value_new_inst("%slot_a", "ptr", 0)
    inst_alloca = ir_build_alloca(1, slot_a, "i64", 0)
    basic_block_append_inst(bb0, inst_alloca)

    // store 10, %slot_a
    val_10 = ssa_value_new_const(10, "i64")
    inst_store = ir_build_store(2, val_10, slot_a)
    basic_block_append_inst(bb0, inst_store)

    // %v0 = load %slot_a
    v0 = ssa_value_new_inst("%v0", "i64", 0)
    inst_load = ir_build_load(3, v0, slot_a)
    basic_block_append_inst(bb0, inst_load)

    // %v1 = add %v0, 5
    val_5 = ssa_value_new_const(5, "i64")
    v1 = ssa_value_new_inst("%v1", "i64", 0)
    inst_add = ir_build_binop(4, OP_ADD, v1, v0, val_5)
    basic_block_append_inst(bb0, inst_add)

    // %cond = cmp CMP_SLT, %v1, 20
    val_20 = ssa_value_new_const(20, "i64")
    v_cond = ssa_value_new_inst("%cond", "i1", 0)
    inst_cmp = ssa_instr_new(5, OP_CMP, v_cond, bb0)
    push(inst_cmp.operands, v1)
    push(inst_cmp.operands, val_20)
    inst_cmp.extra_int = CMP_SLT
    basic_block_append_inst(bb0, inst_cmp)

    // br %cond, bb1
    inst_br = ssa_instr_new(6, OP_BR, 0, bb0)
    push(inst_br.operands, v_cond)
    inst_br.extra_str = "bb1"
    basic_block_append_inst(bb0, inst_br)

    // Construct bb1: %v2 = mul %v1, 2; ret %v2
    val_2 = ssa_value_new_const(2, "i64")
    v2 = ssa_value_new_inst("%v2", "i64", 0)
    inst_mul = ir_build_binop(7, OP_MUL, v2, v1, val_2)
    basic_block_append_inst(bb1, inst_mul)

    inst_ret = ir_build_ret(8, v2)
    basic_block_append_inst(bb1, inst_ret)

    test_assert(fn_compute.blocks.len() == 2, "SSA function contains 2 basic blocks")
    test_assert(ir_function_count_insts(fn_compute) == 8, "SSA function contains 8 instructions")

    // ── Phase 2: Direct Silicon Machine Code Lowering ─────────────────────────
    say "\n▶ [Phase 2]: Lowering SSA IR directly into AMD64 Silicon Machine Code..."
    lowerer = ssa_lowerer_new(TARGET_ID_X86_64())
    res = ssa_lower_module(lowerer, ir_mod)

    test_assert(res.slr_success == 1, "SSA machine lowering succeeded")
    test_assert(res.slr_total_insts == 8, "All 8 SSA instructions lowered")
    test_assert(res.slr_code.len() > 30, "Generated non-trivial AMD64 machine code (" + str(res.slr_code.len()) + " bytes)")

    // Verify AMD64 prologue: push rbp; mov rbp, rsp (85, 72, 137, 229)
    prologue_bytes = [85, 72, 137, 229]
    test_assert(find_subseq(res.slr_code, prologue_bytes) == 1, "AMD64 stack frame prologue verified")

    // Verify AMD64 epilogue: mov rsp, rbp; pop rbp; ret (72, 137, 236, 93, 195)
    epilogue_bytes = [72, 137, 236, 93, 195]
    test_assert(find_subseq(res.slr_code, epilogue_bytes) == 1, "AMD64 epilogue and return verified")

    // ── Phase 3: Hardware DRM GPU Subsystem Engine ───────────────────────────
    say "\n▶ [Phase 3]: Testing Linux DRM GPU Subsystem Discovery..."
    gpu_prof = gpu_probe_drm_hardware()
    test_assert(gpu_prof.compute_cores >= 2048, "GPU core count verified (" + str(gpu_prof.compute_cores) + " cores)")
    test_assert(len(gpu_prof.driver_name) > 0, "GPU driver profile identified: " + gpu_prof.driver_name)

    cores_detected = gpu_detect_hardware_compute_cores()
    test_assert(cores_detected >= 2048, "gpu_detect_hardware_compute_cores returns active capacity")

    // ── Phase 4: ARM64 NEON Vector Instruction Encoders ───────────────────────
    say "\n▶ [Phase 4]: Testing ARM64 NEON SIMD Vector Encoders..."
    s_arm = arm64_synth_new()
    arm64_emit_neon_add_4s(s_arm, 0, 1, 2)
    arm64_emit_neon_sub_4s(s_arm, 3, 4, 5)
    arm64_emit_neon_mul_4s(s_arm, 6, 7, 8)
    arm64_emit_neon_ld1_4s(s_arm, 0, 1)
    arm64_emit_neon_st1_4s(s_arm, 0, 2)

    test_assert(s_arm.synth_code.len() == 20, "Emitted 5 ARM64 32-bit NEON vector instructions (20 bytes)")
    // Check first instruction: add v0.4s, v1.4s, v2.4s -> 0x4E228420 -> [32, 132, 34, 78]
    w0_b0 = s_arm.synth_code[0]
    w0_b1 = s_arm.synth_code[1]
    w0_b2 = s_arm.synth_code[2]
    w0_b3 = s_arm.synth_code[3]
    test_assert(w0_b0 == 32 and w0_b1 == 132 and w0_b2 == 34 and w0_b3 == 78, "ARM64 'add v0.4s, v1.4s, v2.4s' binary word verified (0x4E228420)")

    // ── Phase 5: RISC-V RV64V Vector Extension Encoders ───────────────────────
    say "\n▶ [Phase 5]: Testing RISC-V RV64V Vector Extension Encoders..."
    s_rv = riscv64_synth_new()
    riscv64_emit_vsetvli(s_rv, 10, 11, 0)
    riscv64_emit_vle32_v(s_rv, 0, 10)
    riscv64_emit_vadd_vv(s_rv, 0, 1, 2)
    riscv64_emit_vmul_vv(s_rv, 3, 4, 5)
    riscv64_emit_vse32_v(s_rv, 0, 10)

    test_assert(s_rv.rv_code.len() == 20, "Emitted 5 RISC-V 32-bit RV64V vector instructions (20 bytes)")
    // Check vle32.v v0, (a0/x10) -> opcode 0x07, funct3=6 (24583 + 10*32768 = 352263 -> [7, 96, 5, 0])
    rv_b0 = s_rv.rv_code[4]
    rv_b1 = s_rv.rv_code[5]
    rv_b2 = s_rv.rv_code[6]
    rv_b3 = s_rv.rv_code[7]
    test_assert(rv_b0 == 7 and rv_b1 == 96 and rv_b2 == 5 and rv_b3 == 0, "RISC-V 'vle32.v v0, (x10)' binary word verified")

    say "\n🎉 TEST 207 COMPLETE: ALL SOVEREIGN LOWERING & HARDWARE TESTS PASSED (100% SUCCESS)!"
    return 0
end

main()
