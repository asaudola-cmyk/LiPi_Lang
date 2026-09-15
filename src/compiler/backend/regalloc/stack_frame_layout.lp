// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — STACK FRAME LAYOUT & 16-BYTE ALIGNMENT (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/regalloc/stack_frame_layout.lp
//
// WHY THIS MODULE:
// 1. Hardware ABI standards (System V AMD64, AAPCS64, RISC-V LP64) strictly require
//    16-byte stack alignment (SP % 16 == 0) prior to executing any subroutine call.
// 2. Failure to preserve 16-byte alignment causes fatal hardware alignment faults (#GP)
//    when executing SIMD/AVX/NEON vector instructions (e.g. MOVDQA, MOVAPS) that demand
//    128-bit or 256-bit aligned memory access.
// 3. This module deterministically plans the layout of stack frames:
//    - Return address slot (8 bytes, hardware pushed)
//    - Saved Frame Pointer (RBP/X29/s0, 8 bytes)
//    - Callee-saved register backup slots (8 bytes each)
//    - Local variable storage slots
//    - Register allocator spill slots
//    - Alignment padding bytes (0 to 15) to guarantee clean 16-byte boundary
//    - Incoming stack parameter accessors (above return address)
// ==============================================================================

// ── 1. Stack Frame Layout Descriptor ──────────────────────────────────────────

struct StackFrameLayout
    word_size               // Target machine word size in bytes (8 for 64-bit)
    num_locals              // Count of local stack variables
    num_spills              // Count of register allocator spill slots
    callee_saved_count      // Number of preserved callee-saved registers pushed
    local_area_size         // Total bytes for locals
    spill_area_size         // Total bytes for spills
    padding_bytes           // Bytes added to satisfy 16-byte alignment
    aligned_frame_size      // Stack adjustment emitted in prologue (sub rsp, N)
    total_frame_footprint   // Combined stack delta including saved FP and callee regs

// ── 2. Layout Geometry Constructor ───────────────────────────────────────────

fn stack_frame_layout_new word_size num_locals num_spills callee_saved_count
    // WHY: Computes exact byte boundaries and alignment padding for a function frame.
    layout = StackFrameLayout()
    layout.word_size = word_size
    layout.num_locals = num_locals
    layout.num_spills = num_spills
    layout.callee_saved_count = callee_saved_count

    loc_bytes = num_locals * word_size
    spill_bytes = num_spills * word_size
    layout.local_area_size = loc_bytes
    layout.spill_area_size = spill_bytes

    // Raw payload to be allocated via stack pointer decrement
    raw_payload = loc_bytes + spill_bytes

    // ABI Stack Alignment Math:
    // When CALL executes, the 8-byte return address is pushed -> (RSP % 16 == 8).
    // In prologue: PUSH RBP (8 bytes) -> (RSP % 16 == 0).
    // Pushing each callee-saved register takes 8 bytes.
    // Therefore, callee_pushed_bytes = callee_saved_count * word_size.
    // Total bytes subtracted or pushed below saved RBP = callee_pushed_bytes + raw_payload.
    // To ensure RSP is 0 mod 16 before any subsequent CALL:
    // (callee_pushed_bytes + raw_payload + padding) % 16 == 0.
    total_below_rbp = (callee_saved_count * word_size) + raw_payload
    rem = total_below_rbp % 16
    pad = 0
    if rem != 0
        pad = 16 - rem

    layout.padding_bytes = pad
    layout.aligned_frame_size = raw_payload + pad
    layout.total_frame_footprint = (callee_saved_count * word_size) + layout.aligned_frame_size
    return layout

// ── 3. Displacement Accessors (RBP-Relative Addressing) ────────────────────────

fn stack_frame_get_spill_offset layout spill_idx
    // WHY: Spill slots are allocated below local variables in the negative RBP space.
    //      Offset is negative: e.g. -8, -16, -24.
    offset = 0 - ((layout.num_locals + spill_idx + 1) * layout.word_size)
    return offset

fn stack_frame_get_local_offset layout local_idx
    // WHY: Locals reside directly below the saved frame pointer.
    offset = 0 - ((local_idx + 1) * layout.word_size)
    return offset

fn stack_frame_get_incoming_arg_offset layout arg_idx num_reg_args
    // WHY: In System V and AAPCS64, arguments beyond the register capacity are passed
    //      on the stack by the caller. On entry:
    //      [RBP + 0] = Saved RBP
    //      [RBP + 8] = Return address
    //      [RBP + 16] = 1st stack argument (arg index = num_reg_args)
    //      [RBP + 24] = 2nd stack argument
    if arg_idx < num_reg_args
        return 0 // Passed in register, not on stack
    stack_slot = arg_idx - num_reg_args
    offset = (2 * layout.word_size) + (stack_slot * layout.word_size)
    return offset

fn stack_frame_get_callee_save_offset layout callee_idx
    // WHY: Callee-saved registers are pushed in the prologue right after RBP.
    //      Relative to RBP, each occupies -8, -16, etc.
    offset = 0 - ((callee_idx + 1) * layout.word_size)
    return offset

fn stack_frame_is_aligned layout
    // WHY: Validates that the full frame footprint maintains 16-byte alignment.
    footprint = layout.total_frame_footprint
    if (footprint % 16) == 0
        return 1
    return 0

// ── 4. Verification Self-Test ────────────────────────────────────────────────

fn test_stack_frame_layout_subsystem
    // Scenario 1: 3 locals, 1 spill, 1 callee-saved register (AMD64 64-bit)
    // raw_payload = (3 + 1) * 8 = 32 bytes
    // callee_pushed = 1 * 8 = 8 bytes
    // total_below_rbp = 40 bytes
    // 40 % 16 = 8 -> padding = 8 bytes -> aligned_frame_size = 40 bytes
    // total_footprint = 8 + 40 = 48 bytes (48 % 16 == 0)
    layout1 = stack_frame_layout_new(8, 3, 1, 1)
    if stack_frame_is_aligned(layout1) != 1
        say "FAIL: Layout 1 alignment check failed"
        return 0

    if layout1.padding_bytes != 8
        say "FAIL: Expected 8 bytes padding, got: " + str(layout1.padding_bytes)
        return 0

    // Check spill offset (after 3 locals: local 0=-8, 1=-16, 2=-24 -> spill 0=-32)
    spill0 = stack_frame_get_spill_offset(layout1, 0)
    if spill0 != (0 - 32)
        say "FAIL: Expected spill 0 offset -32, got: " + str(spill0)
        return 0

    // Check incoming 7th arg in System V (num_reg_args = 6, arg_idx = 6) -> RBP + 16
    arg6_off = stack_frame_get_incoming_arg_offset(layout1, 6, 6)
    if arg6_off != 16
        say "FAIL: Expected arg 6 at RBP+16, got: " + str(arg6_off)
        return 0

    // Scenario 2: 2 locals, 0 spills, 0 callee-saved -> raw = 16 -> pad = 0
    layout2 = stack_frame_layout_new(8, 2, 0, 0)
    if layout2.padding_bytes != 0 or layout2.aligned_frame_size != 16
        say "FAIL: Layout 2 zero padding check failed"
        return 0

    return 1

// test_stack_frame_layout_subsystem()
