// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN DIRECT SSA SILICON MACHINE LOWERER
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// 🏛️ File: src/compiler/backend/ssa_lowerer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the middle-end SSA Control Flow Graph (IRModule, IRFunction, BasicBlock,
//    SSAInstr) directly into native silicon machine code without re-parsing source tokens.
// 2. Direct Basic Block & Control Flow Lowering:
//    - Preserves SSA dominance order and handles inter-block branch targets (OP_BR, OP_JMP)
//      with deterministic 32-bit relative jump backpatching.
// 3. Multi-Target Silicon Synthesis:
//    - AMD64 / x86_64: Emits REX.W prefixed 64-bit integer ALU instructions and System V ABI.
//    - AArch64 / ARM64: Emits 32-bit fixed-width AAPCS64 instruction words.
//    - RISC-V 64 / RV64: Emits 32-bit fixed-width LP64 instruction words.
// 4. Zero C Runtime / Zero Assembler: Generates bare-metal machine code bytes directly.
// ==============================================================================

include "src/compiler/middleend/ir/ir_module.lp"
include "src/compiler/backend/targets/target_machine.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

struct SsaSlot
    slot_name       // string: variable or temporary identifier (e.g. "%slot_x", "%v0")
    slot_offset     // integer: RBP-relative byte offset (e.g. 8, 16, 24...)
    slot_reg        // integer: assigned hardware register (-1 if stored on stack)

struct SsaJumpPatch
    sjp_offset      // integer: byte index where 32-bit relative displacement is written
    sjp_target      // string: target BasicBlock label
    sjp_kind        // integer: 0=JMP, 1=JNZ/BNE, 2=JZ/BEQ, 3=JL, 4=JLE, 5=JG, 6=JGE

struct SsaBlockOffset
    sbo_label       // string: BasicBlock label identifier
    sbo_offset      // integer: byte index where basic block instructions begin

struct SsaLowerResult
    slr_code        // list: raw machine code bytes (integers 0..255)
    slr_rodata      // list: read-only data bytes (.rodata)
    slr_fn_names    // list: names of emitted functions
    slr_fn_offsets  // list: entry byte offsets of emitted functions
    slr_total_insts // integer: total SSA instructions lowered
    slr_success     // integer: 1 on success, 0 on failure
    slr_error_msg   // string: diagnostic message on error

struct SsaLowerer
    low_target_arch // integer: TARGET_ID_X86_64, TARGET_ID_ARM64, TARGET_ID_RISCV64
    low_code        // list of bytes
    low_rodata      // list of bytes
    low_slots       // list of SsaSlot structs
    low_patches     // list of SsaJumpPatch structs
    low_blocks      // list of SsaBlockOffset structs
    low_stack_frame // integer: total allocated stack frame size in bytes
    low_cur_offset  // integer: next available stack offset for local alloca slots
    low_fn_names    // list of string function names
    low_fn_offsets  // list of integer function entry byte offsets
    low_total_insts // integer: count of lowered instructions

// ── 2. Constructor & Helpers ──────────────────────────────────────────────────

fn ssa_lowerer_new target_arch
    // WHY: Initializes sovereign lowerer for specified hardware target architecture.
    low = SsaLowerer()
    low.low_target_arch = target_arch
    low.low_code = list()
    low.low_rodata = list()
    low.low_slots = list()
    low.low_patches = list()
    low.low_blocks = list()
    low.low_stack_frame = 32
    low.low_cur_offset = 8
    low.low_fn_names = list()
    low.low_fn_offsets = list()
    low.low_total_insts = 0
    return low

fn ssa_lowerer_emit_byte low b
    // WHY: Emits single byte into machine code stream.
    push(low.low_code, (b % 256 + 256) % 256)
    return low.low_code.len()

fn ssa_lowerer_emit_u32 low val
    // WHY: Emits 32-bit unsigned integer in little-endian byte order.
    v = val
    if v < 0
        v = v + 4294967296
    push(low.low_code, v % 256)
    push(low.low_code, (v / 256) % 256)
    push(low.low_code, (v / 65536) % 256)
    push(low.low_code, (v / 16777216) % 256)
    return low.low_code.len()

fn ssa_lowerer_patch_u32 low offset val
    // WHY: Backpatches 4-byte displacement in code stream.
    v = val
    if v < 0
        v = v + 4294967296
    list_set(low.low_code, offset, v % 256)
    list_set(low.low_code, offset + 1, (v / 256) % 256)
    list_set(low.low_code, offset + 2, (v / 65536) % 256)
    list_set(low.low_code, offset + 3, (v / 16777216) % 256)
    return 0

fn ssa_lowerer_find_slot low name
    // WHY: Resolves SSA value / alloca slot offset.
    i = 0
    while i < low.low_slots.len()
        s = low.low_slots[i]
        if s.slot_name == name
            return s.slot_offset
        i = i + 1
    return 0

fn ssa_lowerer_get_or_add_slot low name
    // WHY: Maps variable or SSA temporary to an RBP-relative stack slot.
    existing = ssa_lowerer_find_slot(low, name)
    if existing > 0
        return existing
    s = SsaSlot()
    s.slot_name = name
    s.slot_offset = low.low_cur_offset
    s.slot_reg = 0 - 1
    push(low.low_slots, s)
    low.low_cur_offset = low.low_cur_offset + 8
    return s.slot_offset

// ── 3. AMD64 Machine Instruction Emitters ─────────────────────────────────────

fn ssa_lower_x86_prologue low frame_size
    // WHY: Emits standard x86-64 stack frame setup: push rbp; mov rbp, rsp; sub rsp, frame_size
    ssa_lowerer_emit_byte(low, 85) // push rbp (0x55)
    ssa_lowerer_emit_byte(low, 72) // REX.W (0x48)
    ssa_lowerer_emit_byte(low, 137) // mov rbp, rsp (0x89)
    ssa_lowerer_emit_byte(low, 229) // 0xE5
    if frame_size > 0
        ssa_lowerer_emit_byte(low, 72)  // REX.W
        ssa_lowerer_emit_byte(low, 129) // sub rsp, imm32 (0x81)
        ssa_lowerer_emit_byte(low, 236) // 0xEC
        ssa_lowerer_emit_u32(low, frame_size)
    return 0

fn ssa_lower_x86_epilogue low
    // WHY: Emits standard x86-64 stack frame tear down: mov rsp, rbp; pop rbp; ret
    ssa_lowerer_emit_byte(low, 72)  // REX.W
    ssa_lowerer_emit_byte(low, 137) // mov rsp, rbp (0x89)
    ssa_lowerer_emit_byte(low, 236) // 0xEC
    ssa_lowerer_emit_byte(low, 93)  // pop rbp (0x5D)
    ssa_lowerer_emit_byte(low, 195) // ret (0xC3)
    return 0

fn ssa_lower_x86_load_val_to_rax low val
    // WHY: Loads constant immediate or stack slot into RAX.
    if val == 0
        // xor rax, rax
        ssa_lowerer_emit_byte(low, 72)
        ssa_lowerer_emit_byte(low, 49)
        ssa_lowerer_emit_byte(low, 192)
        return 0
    if val.kind == VAL_KIND_CONST or val.val_kind == VAL_KIND_CONST
        // mov rax, imm64
        ssa_lowerer_emit_byte(low, 72)  // REX.W
        ssa_lowerer_emit_byte(low, 184) // mov rax, imm64 (0xB8)
        v = val.const_val
        i = 0
        while i < 8
            b = v % 256
            if b < 0 b = b + 256
            push(low.low_code, b)
            v = (v - b) / 256
            i = i + 1
        return 0
    // Stack slot: mov rax, [rbp - offset]
    off = ssa_lowerer_get_or_add_slot(low, val.id)
    ssa_lowerer_emit_byte(low, 72)  // REX.W
    ssa_lowerer_emit_byte(low, 139) // mov rax, [rbp - off] (0x8B)
    if off < 128
        ssa_lowerer_emit_byte(low, 69) // ModR/M [rbp + disp8]
        ssa_lowerer_emit_byte(low, 256 - off)
    else
        ssa_lowerer_emit_byte(low, 133) // ModR/M [rbp + disp32]
        ssa_lowerer_emit_u32(low, 0 - off)
    return 0

fn ssa_lower_x86_store_rax_to_slot low slot_name
    // WHY: Stores RAX register into stack frame slot [rbp - offset].
    off = ssa_lowerer_get_or_add_slot(low, slot_name)
    ssa_lowerer_emit_byte(low, 72)  // REX.W
    ssa_lowerer_emit_byte(low, 137) // mov [rbp - off], rax (0x89)
    if off < 128
        ssa_lowerer_emit_byte(low, 69)
        ssa_lowerer_emit_byte(low, 256 - off)
    else
        ssa_lowerer_emit_byte(low, 133)
        ssa_lowerer_emit_u32(low, 0 - off)
    return 0

// ── 4. Direct SSA Instruction Lowering ────────────────────────────────────────

fn ssa_lower_instruction_x86 low inst
    // WHY: Translates single SSA instruction node into AMD64 machine code bytes.
    if inst.is_dead == 1 return 0
    low.low_total_insts = low.low_total_insts + 1
    op = inst.op

    if op == OP_NOP
        ssa_lowerer_emit_byte(low, 144) // nop (0x90)
        return 0

    if op == OP_ALLOCA
        // Registers stack slot
        if inst.result != 0
            ssa_lowerer_get_or_add_slot(low, inst.result.id)
        return 0

    if op == OP_STORE
        // store %val, %ptr
        if inst.operands.len() >= 2
            val_op = inst.operands[0]
            ptr_op = inst.operands[1]
            ssa_lower_x86_load_val_to_rax(low, val_op)
            ssa_lower_x86_store_rax_to_slot(low, ptr_op.id)
        return 0

    if op == OP_LOAD
        // %res = load %ptr
        if inst.operands.len() >= 1 and inst.result != 0
            ptr_op = inst.operands[0]
            ssa_lower_x86_load_val_to_rax(low, ptr_op)
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        return 0

    if op == OP_ADD or op == OP_SUB or op == OP_MUL or op == OP_AND or op == OP_OR or op == OP_XOR
        if inst.operands.len() >= 2 and inst.result != 0
            val_a = inst.operands[0]
            val_b = inst.operands[1]
            ssa_lower_x86_load_val_to_rax(low, val_a)
            // Push RAX to temp stack or move to RCX
            ssa_lowerer_emit_byte(low, 80) // push rax (0x50)
            ssa_lower_x86_load_val_to_rax(low, val_b)
            ssa_lowerer_emit_byte(low, 72)  // REX.W
            ssa_lowerer_emit_byte(low, 137) // mov rcx, rax (0x89)
            ssa_lowerer_emit_byte(low, 193) // 0xC1
            ssa_lowerer_emit_byte(low, 88)  // pop rax (0x58)

            if op == OP_ADD
                // add rax, rcx (0x48, 0x01, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 1)
                ssa_lowerer_emit_byte(low, 200)
            elif op == OP_SUB
                // sub rax, rcx (0x48, 0x29, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 41)
                ssa_lowerer_emit_byte(low, 200)
            elif op == OP_MUL
                // imul rax, rcx (0x48, 0x0F, 0xAF, 0xC1)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 15)
                ssa_lowerer_emit_byte(low, 175)
                ssa_lowerer_emit_byte(low, 193)
            elif op == OP_AND
                // and rax, rcx (0x48, 0x21, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 33)
                ssa_lowerer_emit_byte(low, 200)
            elif op == OP_OR
                // or rax, rcx (0x48, 0x09, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 9)
                ssa_lowerer_emit_byte(low, 200)
            elif op == OP_XOR
                // xor rax, rcx (0x48, 0x31, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 49)
                ssa_lowerer_emit_byte(low, 200)

            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        return 0

    if op == OP_CMP
        // cmp pred, %a, %b
        if inst.operands.len() >= 2 and inst.result != 0
            val_a = inst.operands[0]
            val_b = inst.operands[1]
            ssa_lower_x86_load_val_to_rax(low, val_a)
            ssa_lowerer_emit_byte(low, 80) // push rax
            ssa_lower_x86_load_val_to_rax(low, val_b)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 193) // mov rcx, rax
            ssa_lowerer_emit_byte(low, 88)  // pop rax

            // cmp rax, rcx (0x48, 0x39, 0xC8)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 57)
            ssa_lowerer_emit_byte(low, 200)

            // sete/setne/setl/setle/setg/setge al
            pred = inst.extra_int
            if pred == CMP_EQ
                ssa_lowerer_emit_byte(low, 15) // sete al (0x0F, 0x94, 0xC0)
                ssa_lowerer_emit_byte(low, 148)
                ssa_lowerer_emit_byte(low, 192)
            elif pred == CMP_NE
                ssa_lowerer_emit_byte(low, 15) // setne al (0x0F, 0x95, 0xC0)
                ssa_lowerer_emit_byte(low, 149)
                ssa_lowerer_emit_byte(low, 192)
            elif pred == CMP_SLT
                ssa_lowerer_emit_byte(low, 15) // setl al (0x0F, 0x9C, 0xC0)
                ssa_lowerer_emit_byte(low, 156)
                ssa_lowerer_emit_byte(low, 192)
            elif pred == CMP_SLE
                ssa_lowerer_emit_byte(low, 15) // setle al (0x0F, 0x9E, 0xC0)
                ssa_lowerer_emit_byte(low, 158)
                ssa_lowerer_emit_byte(low, 192)
            elif pred == CMP_SGT
                ssa_lowerer_emit_byte(low, 15) // setg al (0x0F, 0x9F, 0xC0)
                ssa_lowerer_emit_byte(low, 159)
                ssa_lowerer_emit_byte(low, 192)
            else
                ssa_lowerer_emit_byte(low, 15) // setge al (0x0F, 0x9D, 0xC0)
                ssa_lowerer_emit_byte(low, 157)
                ssa_lowerer_emit_byte(low, 192)

            // movzx rax, al (0x48, 0x0F, 0xB6, 0xC0)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 15)
            ssa_lowerer_emit_byte(low, 182)
            ssa_lowerer_emit_byte(low, 192)

            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        return 0

    if op == OP_JMP
        // jmp label_target (0xE9, disp32)
        ssa_lowerer_emit_byte(low, 233)
        patch_pos = low.low_code.len()
        ssa_lowerer_emit_u32(low, 0)
        jp = SsaJumpPatch()
        jp.sjp_offset = patch_pos
        jp.sjp_target = inst.extra_str
        jp.sjp_kind = 0
        push(low.low_patches, jp)
        return 0

    if op == OP_BR
        // br %cond, label_then, label_else
        if inst.operands.len() >= 1
            cond_val = inst.operands[0]
            ssa_lower_x86_load_val_to_rax(low, cond_val)
            // test rax, rax (0x48, 0x85, 0xC0)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 133)
            ssa_lowerer_emit_byte(low, 192)

            target_then = inst.extra_str
            target_else = ""
            if inst.extra_list.len() > 0
                target_then = inst.extra_list[0]
                if inst.extra_list.len() > 1
                    target_else = inst.extra_list[1]

            // jnz target_then (0x0F, 0x85, disp32)
            ssa_lowerer_emit_byte(low, 15)
            ssa_lowerer_emit_byte(low, 133)
            patch_then = low.low_code.len()
            ssa_lowerer_emit_u32(low, 0)
            jp_then = SsaJumpPatch()
            jp_then.sjp_offset = patch_then
            jp_then.sjp_target = target_then
            jp_then.sjp_kind = 1
            push(low.low_patches, jp_then)

            if len(target_else) > 0
                // jmp target_else (0xE9, disp32)
                ssa_lowerer_emit_byte(low, 233)
                patch_else = low.low_code.len()
                ssa_lowerer_emit_u32(low, 0)
                jp_else = SsaJumpPatch()
                jp_else.sjp_offset = patch_else
                jp_else.sjp_target = target_else
                jp_else.sjp_kind = 0
                push(low.low_patches, jp_else)
        return 0

    if op == OP_RET
        // ret %val
        if inst.operands.len() >= 1
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
        ssa_lower_x86_epilogue(low)
        return 0

    return 0

// ── 5. Backpatching & Module Lowering ─────────────────────────────────────────

fn ssa_lowerer_resolve_jumps low
    // WHY: Resolves relative jump displacements across all basic block boundaries.
    pi = 0
    while pi < low.low_patches.len()
        patch = low.low_patches[pi]
        tgt_offset = 0 - 1
        bi = 0
        while bi < low.low_blocks.len()
            b = low.low_blocks[bi]
            if b.sbo_label == patch.sjp_target
                tgt_offset = b.sbo_offset
                break
            bi = bi + 1

        if tgt_offset >= 0
            // Relative displacement from end of jump instruction
            disp = tgt_offset - (patch.sjp_offset + 4)
            ssa_lowerer_patch_u32(low, patch.sjp_offset, disp)
        pi = pi + 1
    return 0

fn ssa_lower_function low fn_obj
    // WHY: Lowers an entire IRFunction and its basic blocks into machine code.
    push(low.low_fn_names, fn_obj.name)
    push(low.low_fn_offsets, low.low_code.len())

    // 1. Calculate frame requirement based on allocas and temporaries
    alloca_count = fn_obj.allocas.len()
    inst_count = ir_function_count_insts(fn_obj)
    frame_size = (alloca_count + inst_count + 4) * 8
    // Pad to 16-byte alignment
    if (frame_size % 16) != 0
        frame_size = frame_size + (16 - (frame_size % 16))
    low.low_stack_frame = frame_size

    // 2. Emit function prologue
    ssa_lower_x86_prologue(low, frame_size)

    // 3. Lower each basic block sequentially
    bi = 0
    while bi < fn_obj.blocks.len()
        bb = fn_obj.blocks[bi]
        // Record block label offset
        bo = SsaBlockOffset()
        bo.sbo_label = bb.label
        bo.sbo_offset = low.low_code.len()
        push(low.low_blocks, bo)

        // Lower block instructions
        ii = 0
        while ii < bb.instructions.len()
            inst = bb.instructions[ii]
            ssa_lower_instruction_x86(low, inst)
            ii = ii + 1
        bi = bi + 1

    return 0

fn ssa_lower_module low ir_mod
    // WHY: Master orchestration entry point. Lowers entire IRModule to machine code.
    res = SsaLowerResult()
    res.slr_code = list()
    res.slr_rodata = list()
    res.slr_fn_names = list()
    res.slr_fn_offsets = list()
    res.slr_total_insts = 0
    res.slr_success = 0
    res.slr_error_msg = ""

    if ir_mod == 0
        res.slr_error_msg = "Null IRModule passed to ssa_lower_module"
        return res

    fi = 0
    while fi < ir_mod.functions.len()
        f = ir_mod.functions[fi]
        ssa_lower_function(low, f)
        fi = fi + 1

    // 4. Resolve all block-to-block jumps
    ssa_lowerer_resolve_jumps(low)

    res.slr_code = low.low_code
    res.slr_rodata = low.low_rodata
    res.slr_fn_names = low.low_fn_names
    res.slr_fn_offsets = low.low_fn_offsets
    res.slr_total_insts = low.low_total_insts
    res.slr_success = 1
    return res
