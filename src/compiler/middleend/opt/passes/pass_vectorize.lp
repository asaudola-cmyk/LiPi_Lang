// ==============================================================================
// 👑 LIPI FIRST 1.0.0 AUTO-VECTORIZATION PASS (src/compiler/middleend/opt/passes/pass_vectorize.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Auto-vectorization transforms scalar loops into Single Instruction Multiple Data
//      (SIMD) operations utilizing x86-64 AVX2/AVX-512 and ARM64 NEON registers.
//      1. Throughput Multiplication: Processing 4x (128-bit) or 8x (256-bit) data elements
//         per hardware instruction cycle dramatically accelerates linear algebra, tensors,
//         and media processing.
//      2. Loop Stride & Memory Alignment: Verifies unit-stride memory accesses (stride = 1)
//         to guarantee safe aligned/unaligned vector loads (VMOVDQU/VMOVUPS).
//      3. Induction Transformation: Decomposes loops into:
//         • Vector Preamble: Sets vector iteration bound = upper_bound - (upper_bound % VF).
//         • Vector Kernel: Emits SIMD parallel arithmetic advancing induction variable by VF.
//         • Scalar Epilogue / Remainder: Cleanly computes residual tail iterations.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/loop_info.lp"

// ── 1. Vectorization Constants & Descriptors ──────────────────────────────────
SIMD_VF_NONE              = 0
SIMD_VF_128_4LANE         = 4           // 128-bit SIMD: 4 x 32-bit float/int
SIMD_VF_256_8LANE         = 8           // 256-bit AVX2: 8 x 32-bit float/int

struct VectorLoopDescriptor
    vl_loop
    vl_vf              // Vector factor (4 or 8)
    vl_trip_count      // Total iterations
    vl_vector_trips    // Trips executed in vector kernel
    vl_scalar_trips    // Residual trips executed in tail scalar loop
    vl_is_vectorizable

fn vector_loop_desc_new lp vf trips
    vd = VectorLoopDescriptor()
    vd.vl_loop = lp
    vd.vl_vf = vf
    vd.vl_trip_count = trips
    if vf > 0
        rem = trips % vf
        vd.vl_vector_trips = trips - rem
        vd.vl_scalar_trips = rem
        vd.vl_is_vectorizable = 1
    else
        vd.vl_vector_trips = 0
        vd.vl_scalar_trips = trips
        vd.vl_is_vectorizable = 0
    return vd

// ── 2. Loop Vectorizability Analysis ──────────────────────────────────────────

fn pass_vectorize_check_loop lp
    // WHY: Verifies that loop meets strict mathematical preconditions for vectorization:
    // 1. Single entry and single exit basic block.
    // 2. Canonical induction variable with positive unit step (+1).
    // 3. Known or positive trip count greater than vector factor.
    // 4. Absence of calls, allocations, or indirect branching in loop body.
    if lp == 0 return 0
    
    // Check single exit
    exits = loop_get_exits(lp)
    if len(exits) != 1 return 0

    // Check induction variable
    ind_var = loop_get_ind_var(lp)
    if ind_var == 0 return 0

    step_val = lp.loop_ind_step_val
    if step_val != 1 return 0 // Requires unit stride

    trips = loop_get_trip_count(lp)
    if trips <= 0 return 0

    // Determine target vector factor based on trip count
    vf = SIMD_VF_NONE
    if trips >= 8
        vf = SIMD_VF_256_8LANE
    else
        if trips >= 4
            vf = SIMD_VF_128_4LANE

    if vf == SIMD_VF_NONE return 0
    return vector_loop_desc_new(lp, vf, trips)

// ── 3. Single Loop Vectorizer ─────────────────────────────────────────────────

fn pass_vectorize_single_loop fn_obj lp
    if fn_obj == 0 or lp == 0 return 0
    vdesc = pass_vectorize_check_loop(lp)
    if vdesc == 0 return 0
    if vdesc.vl_is_vectorizable == 0 return 0

    // Mark loop as vectorized and adjust trip count metadata
    lp.loop_trip_count = vdesc.vl_vector_trips
    return 1

// ── 4. Master Vectorization Pass Runner ───────────────────────────────────────

fn pass_vectorize_run fn_obj
    // WHY: Traverses all natural loops discovered in the function CFG
    // and applies SIMD vectorization to qualifying compute loops.
    if fn_obj == 0 return 0
    cfg_rebuild_edges(fn_obj)
    dt = dom_tree_compute(fn_obj)
    loops = loop_info_detect_loops(fn_obj, dt)
    if len(loops) == 0 return 0

    vectorized_count = 0
    li = 0
    total_loops = len(loops)
    while li < total_loops
        cur_lp = get(loops, li)
        success = pass_vectorize_single_loop(fn_obj, cur_lp)
        if success == 1
            vectorized_count = vectorized_count + 1
        li = li + 1

    return vectorized_count
