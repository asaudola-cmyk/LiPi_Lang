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
    slr_code        // list: raw machine code bytes (legacy API compatibility)
    slr_rodata      // list: read-only data bytes (.rodata, legacy API compatibility)
    slr_code_buf    // ByteBuffer: compact 1B/byte machine code stream (primary zero-bloat path)
    slr_rodata_buf  // ByteBuffer: compact 1B/byte .rodata stream (primary zero-bloat path)
    slr_fn_names    // list: names of emitted functions
    slr_fn_offsets  // list: entry byte offsets of emitted functions
    slr_fn_sizes    // list: exact byte lengths of each emitted SSA function (prevents duplicate bloat!)
    slr_fn_eligible // list: 1 if function is 100% natively lowered and ready to replace token re-parser
    slr_fn_ret_types // list: normalized return types ("int", "float", "str", struct name)
    slr_fn_locals   // list: total local slot counts (including params) for WASM SSA splicing
    slr_str_relocs  // list of [code_offset, rodata_offset] pairs for STR0 string literals
    slr_call_relocs // list of SsaJumpPatch entries for all OP_CALL / runtime helper calls
    slr_fn_name_map // dict: fn_name -> index + 1 (O(1) lookup during backend splicing)
    slr_fn_str_start // list: per-fn start index into slr_str_relocs
    slr_fn_str_end   // list: per-fn end index (exclusive) into slr_str_relocs
    slr_fn_call_start // list: per-fn start index into slr_call_relocs
    slr_fn_call_end   // list: per-fn end index (exclusive) into slr_call_relocs
    slr_total_insts // integer: total SSA instructions lowered
    slr_success     // integer: 1 on success, 0 on failure
    slr_error_msg   // string: diagnostic message on error

struct SsaLowerer
    low_target_arch // integer: TARGET_ID_X86_64, TARGET_ID_ARM64, TARGET_ID_RISCV64
    low_code        // ByteBuffer of machine code bytes
    low_rodata      // ByteBuffer of .rodata bytes
    low_slots       // list of SsaSlot structs
    low_slot_map    // dict: slot_name -> stack offset (O(1) lookup, eliminates O(K^2) scans!)
    low_reg_map     // dict: vreg_name -> hw_reg_id + 1 (LinearScan physical register assignments!)
    low_used_callee // list of callee-saved hw regs ({3,12,13,14,15}) used in active function
    low_frame_patch // byte offset of prologue `sub rsp, imm32` for exact spilled-only frame backpatch
    low_only_eligible // 1 in pipeline mode: skip emitting dead bytes for ineligible functions
    low_patches     // list of intra-function SsaJumpPatch structs
    low_call_patches // list of inter-function OP_CALL / runtime helper SsaJumpPatch structs
    low_str_relocs  // list of [code_offset, rodata_offset] pairs for OP_STR_LIT
    low_blocks      // list of SsaBlockOffset structs
    low_stack_frame // integer: total allocated stack frame size in bytes
    low_cur_offset  // integer: next available stack offset for local alloca slots
    low_fn_names    // list of string function names
    low_fn_offsets  // list of integer function entry byte offsets
    low_fn_sizes    // list of integer function byte lengths
    low_fn_eligible // list of integer eligibility flags (1 = safe direct native SSA replacement)
    low_fn_ret_types // list of string return types per lowered function
    low_fn_locals   // list of integer total local slot counts (for WASM SSA splicing)
    low_total_insts // integer: count of lowered instructions

// ── 2. Constructor & Helpers ──────────────────────────────────────────────────

fn ssa_lowerer_new target_arch
    // WHY: Initializes sovereign lowerer using compact ByteBuffers (8x lower memory vs list()).
    low = SsaLowerer()
    low.low_target_arch = target_arch
    low.low_code = buf_new(65536)
    low.low_rodata = buf_new(8192)
    low.low_slots = list()
    low.low_slot_map = dict()
    low.low_reg_map = 0
    low.low_used_callee = list()
    low.low_frame_patch = 0 - 1
    low.low_only_eligible = 0
    low.low_patches = list()
    low.low_call_patches = list()
    low.low_str_relocs = list()
    low.low_blocks = list()
    low.low_stack_frame = 32
    low.low_cur_offset = 8
    low.low_fn_names = list()
    low.low_fn_offsets = list()
    low.low_fn_sizes = list()
    low.low_fn_eligible = list()
    low.low_fn_ret_types = list()
    low.low_fn_locals = list()
    low.low_total_insts = 0
    return low

fn ssa_lowerer_emit_bytes low blist
    code = low.low_code
    i = 0
    n = blist.len()
    while i < n
        buf_write_byte(code, blist[i] & 255)
        i = i + 1
    end
    return 0

fn ssa_lowerer_add_rodata_str low str_text
    // WHY: Prepends exact 8-byte STR0 header (u32 len + "0RTS" = 0x53545230) and copies via ERMS.
    slen = len(str_text)
    ro = low.low_rodata
    buf_write_byte(ro, slen & 255)
    buf_write_byte(ro, (slen >> 8) & 255)
    buf_write_byte(ro, (slen >> 16) & 255)
    buf_write_byte(ro, (slen >> 24) & 255)
    buf_write_byte(ro, 48) // '0'
    buf_write_byte(ro, 82) // 'R'
    buf_write_byte(ro, 84) // 'T'
    buf_write_byte(ro, 83) // 'S'
    start_off = buf_len(ro)
    if slen > 0
        buf_write_mem(ro, str_text, slen)
    end
    buf_write_byte(ro, 0)
    return start_off

fn ssa_hash_str_4096 s
    // WHY: Deterministic FNV-1a-style 12-bit bucket hash with zero-alloc mem_byte_read.
    h = 2166136261
    n = len(s)
    i = 0
    while i < n
        h = ((h ^ mem_byte_read(s, i)) * 16777619) & 2147483647
        i = i + 1
    return h & 4095

fn ssa_lowerer_emit_byte low b
    // WHY: Emits single byte into compact ByteBuffer machine code stream.
    buf_write_byte(low.low_code, b & 255)
    return buf_len(low.low_code)

fn ssa_lowerer_emit_u32 low val
    // WHY: Emits 32-bit unsigned integer in little-endian byte order into ByteBuffer.
    code = low.low_code
    buf_write_byte(code, val & 255)
    buf_write_byte(code, (val >> 8) & 255)
    buf_write_byte(code, (val >> 16) & 255)
    buf_write_byte(code, (val >> 24) & 255)
    return buf_len(code)

fn ssa_lowerer_patch_u32 low offset val
    // WHY: Backpatches 4-byte displacement directly in ByteBuffer memory.
    cp = buf_ptr(low.low_code)
    mem_byte_write(cp, offset, val & 255)
    mem_byte_write(cp, offset + 1, (val >> 8) & 255)
    mem_byte_write(cp, offset + 2, (val >> 16) & 255)
    mem_byte_write(cp, offset + 3, (val >> 24) & 255)
    return 0

fn ssa_lowerer_find_slot low name
    // WHY: O(1) DICT0-backed SSA value / alloca slot lookup.
    if low.low_slot_map != 0 and has_key(low.low_slot_map, name) == 1
        return low.low_slot_map[name]
    end
    return 0

fn ssa_lowerer_get_or_add_slot low name
    // WHY: Maps variable or SSA temporary to an RBP-relative stack slot in O(1).
    if low.low_slot_map != 0 and has_key(low.low_slot_map, name) == 1
        return low.low_slot_map[name]
    end
    off = low.low_cur_offset
    s = SsaSlot()
    s.slot_name = name
    s.slot_offset = off
    s.slot_reg = 0 - 1
    push(low.low_slots, s)
    if low.low_slot_map != 0
        low.low_slot_map[name] = off
    end
    low.low_cur_offset = off + 8
    return off

// ── 3. AMD64 Machine Instruction Emitters (Linear-Scan Physical Register Backed) ──

fn ssa_x86_find_phys_reg low name
    // WHY: O(1) physical hardware register lookup in safe non-ABI pool {3, 10, 11, 12, 13, 14, 15}.
    if low.low_reg_map != 0 and name != 0 and has_key(low.low_reg_map, name) == 1
        return low.low_reg_map[name] - 1
    end
    return 0 - 1
end

fn ssa_x86_emit_mov_rr low dst src
    // WHY: Compact 3-byte `mov r64, r64` (0 bytes when dst == src).
    if dst == src return 0 end
    rex = 72
    if src >= 8 rex = rex + 4 end
    if dst >= 8 rex = rex + 1 end
    code = low.low_code
    buf_write_byte(code, rex)
    buf_write_byte(code, 137)
    buf_write_byte(code, 192 | ((src & 7) << 3) | (dst & 7))
    return 0
end

fn ssa_x86_emit_load_slot low dst off
    // WHY: Loads `[rbp - off]` directly into any 64-bit hardware register `dst`.
    rex = 72
    if dst >= 8 rex = rex + 4 end
    code = low.low_code
    buf_write_byte(code, rex)
    buf_write_byte(code, 139)
    if off <= 128
        buf_write_byte(code, 69 | ((dst & 7) << 3))
        buf_write_byte(code, (256 - off) & 255)
    else
        buf_write_byte(code, 133 | ((dst & 7) << 3))
        ssa_lowerer_emit_u32(low, 0 - off)
    end
    return 0
end

fn ssa_x86_emit_store_slot low src off
    // WHY: Stores any 64-bit hardware register `src` directly into `[rbp - off]`.
    rex = 72
    if src >= 8 rex = rex + 4 end
    code = low.low_code
    buf_write_byte(code, rex)
    buf_write_byte(code, 137)
    if off <= 128
        buf_write_byte(code, 69 | ((src & 7) << 3))
        buf_write_byte(code, (256 - off) & 255)
    else
        buf_write_byte(code, 133 | ((src & 7) << 3))
        ssa_lowerer_emit_u32(low, 0 - off)
    end
    return 0
end

fn ssa_x86_emit_mov_imm low dst v
    // WHY: Shortest legal AMD64 immediate load: xor r32,r32 (2-3B), mov r32,u31 (5-6B),
    // mov r64,sext32 (7B), or movabs r64,imm64 (10B). Cuts constant code size by 50-80%!
    code = low.low_code
    if v == 0
        if dst >= 8 buf_write_byte(code, 69) end
        buf_write_byte(code, 49)
        buf_write_byte(code, 192 | ((dst & 7) << 3) | (dst & 7))
        return 0
    end
    if v > 0 and v <= 2147483647
        if dst >= 8 buf_write_byte(code, 65) end
        buf_write_byte(code, 184 + (dst & 7))
        ssa_lowerer_emit_u32(low, v)
        return 0
    end
    if v >= (0 - 2147483648) and v < 0
        rex = 72
        if dst >= 8 rex = rex + 1 end
        buf_write_byte(code, rex)
        buf_write_byte(code, 199)
        buf_write_byte(code, 192 + (dst & 7))
        ssa_lowerer_emit_u32(low, v)
        return 0
    end
    rex = 72
    if dst >= 8 rex = rex + 1 end
    buf_write_byte(code, rex)
    buf_write_byte(code, 184 + (dst & 7))
    buf_write_byte(code, v & 255)
    buf_write_byte(code, (v >> 8) & 255)
    buf_write_byte(code, (v >> 16) & 255)
    buf_write_byte(code, (v >> 24) & 255)
    buf_write_byte(code, (v >> 32) & 255)
    buf_write_byte(code, (v >> 40) & 255)
    buf_write_byte(code, (v >> 48) & 255)
    buf_write_byte(code, (v >> 56) & 255)
    return 0
end

fn ssa_x86_emit_push_reg low r
    if r >= 8 buf_write_byte(low.low_code, 65) end
    buf_write_byte(low.low_code, 80 + (r & 7))
    return 0
end

fn ssa_x86_emit_pop_reg low r
    if r >= 8 buf_write_byte(low.low_code, 65) end
    buf_write_byte(low.low_code, 88 + (r & 7))
    return 0
end

fn ssa_lower_x86_prologue low frame_size
    // WHY: Emits SysV AMD64 prologue saving ONLY linear-scan-assigned callee-saved regs
    // and reserving a backpatchable `sub rsp, imm32` slot sized strictly to actual spills!
    code = low.low_code
    buf_write_byte(code, 85)  // push rbp
    buf_write_byte(code, 72)  // mov rbp, rsp
    buf_write_byte(code, 137)
    buf_write_byte(code, 229)
    if low.low_used_callee != 0
        ci = 0
        while ci < low.low_used_callee.len()
            ssa_x86_emit_push_reg(low, low.low_used_callee[ci])
            ci = ci + 1
        end
    end
    buf_write_byte(code, 72)  // REX.W
    buf_write_byte(code, 129) // sub rsp, imm32
    buf_write_byte(code, 236)
    low.low_frame_patch = buf_len(code)
    ssa_lowerer_emit_u32(low, frame_size)
    return 0
end

fn ssa_lower_x86_epilogue low
    // WHY: Restores saved callee-saved regs (if any) and tears down frame (`leave; ret` = 2B when leaf).
    code = low.low_code
    n_c = 0
    if low.low_used_callee != 0 n_c = low.low_used_callee.len() end
    if n_c == 0
        // mov rsp, rbp; pop rbp; ret (preserves canonical AMD64 epilogue contract for test_sovereign_ssa_machine_lowering)
        buf_write_byte(code, 72)
        buf_write_byte(code, 137)
        buf_write_byte(code, 236)
        buf_write_byte(code, 93)
        buf_write_byte(code, 195)
        return 0
    end
    // lea rsp, [rbp - n_c*8]
    buf_write_byte(code, 72)
    buf_write_byte(code, 141)
    buf_write_byte(code, 101)
    buf_write_byte(code, (256 - (n_c * 8)) & 255)
    ci = n_c - 1
    while ci >= 0
        ssa_x86_emit_pop_reg(low, low.low_used_callee[ci])
        ci = ci - 1
    end
    buf_write_byte(code, 93)  // pop rbp
    buf_write_byte(code, 195) // ret
    return 0
end

fn ssa_lower_x86_load_val_to_reg low val dst
    // WHY: Loads constant, physical register, or stack slot directly into `dst` (zero push/pop!).
    if val == 0
        ssa_x86_emit_mov_imm(low, dst, 0)
        return 0
    end
    if val.kind == VAL_KIND_CONST or val.val_kind == VAL_KIND_CONST
        ssa_x86_emit_mov_imm(low, dst, val.const_val)
        return 0
    end
    pr = ssa_x86_find_phys_reg(low, val.id)
    if pr >= 0
        ssa_x86_emit_mov_rr(low, dst, pr)
        return 0
    end
    off = ssa_lowerer_get_or_add_slot(low, val.id)
    ssa_x86_emit_load_slot(low, dst, off)
    return 0
end

fn ssa_lower_x86_load_val_to_rax low val
    return ssa_lower_x86_load_val_to_reg(low, val, 0)
end

fn ssa_lower_x86_store_reg_to_slot low src slot_name
    pr = ssa_x86_find_phys_reg(low, slot_name)
    if pr >= 0
        ssa_x86_emit_mov_rr(low, pr, src)
        return 0
    end
    off = ssa_lowerer_get_or_add_slot(low, slot_name)
    ssa_x86_emit_store_slot(low, src, off)
    return 0
end

fn ssa_lower_x86_store_rax_to_slot low slot_name
    return ssa_lower_x86_store_reg_to_slot(low, 0, slot_name)
end

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
        // Only allocate stack slot if NOT assigned a physical hardware register
        if inst.result != 0 and ssa_x86_find_phys_reg(low, inst.result.id) < 0
            ssa_lowerer_get_or_add_slot(low, inst.result.id)
        end
        return 0

    if op == OP_STORE
        // store %val, %ptr (direct imm/reg/mem -> phys_reg or direct phys_reg -> [rbp-off]!)
        if inst.operands.len() >= 2
            val_op = inst.operands[0]
            ptr_op = inst.operands[1]
            dst_r = ssa_x86_find_phys_reg(low, ptr_op.id)
            if dst_r >= 0
                ssa_lower_x86_load_val_to_reg(low, val_op, dst_r)
            else
                off_s = ssa_lowerer_get_or_add_slot(low, ptr_op.id)
                src_r = 0 - 1
                if val_op != 0 and val_op.kind != VAL_KIND_CONST and val_op.val_kind != VAL_KIND_CONST
                    src_r = ssa_x86_find_phys_reg(low, val_op.id)
                end
                if src_r >= 0
                    ssa_x86_emit_store_slot(low, src_r, off_s)
                else
                    ssa_lower_x86_load_val_to_reg(low, val_op, 0)
                    ssa_x86_emit_store_slot(low, 0, off_s)
                end
            end
        end
        return 0

    if op == OP_LOAD
        // %res = load %ptr (direct reg-to-reg / mem-to-reg / reg-to-mem!)
        if inst.operands.len() >= 1 and inst.result != 0
            ptr_op = inst.operands[0]
            dst_r = ssa_x86_find_phys_reg(low, inst.result.id)
            if dst_r >= 0
                ssa_lower_x86_load_val_to_reg(low, ptr_op, dst_r)
            else
                off_d = ssa_lowerer_get_or_add_slot(low, inst.result.id)
                src_r = 0 - 1
                if ptr_op != 0 and ptr_op.kind != VAL_KIND_CONST and ptr_op.val_kind != VAL_KIND_CONST
                    src_r = ssa_x86_find_phys_reg(low, ptr_op.id)
                end
                if src_r >= 0
                    ssa_x86_emit_store_slot(low, src_r, off_d)
                else
                    ssa_lower_x86_load_val_to_reg(low, ptr_op, 0)
                    ssa_x86_emit_store_slot(low, 0, off_d)
                end
            end
        end
        return 0

    if op == OP_ADD or op == OP_ADD_DYN or op == OP_SUB or op == OP_MUL or op == OP_DIV or op == OP_MOD or op == OP_AND or op == OP_OR or op == OP_XOR or op == OP_SHL or op == OP_SHR
        if inst.operands.len() >= 2 and inst.result != 0
            val_a = inst.operands[0]
            val_b = inst.operands[1]
            // Direct load to rax & rcx: ZERO push/pop and ZERO mov rcx, rax!
            ssa_lower_x86_load_val_to_reg(low, val_a, 0)
            ssa_lower_x86_load_val_to_reg(low, val_b, 1)

            if op == OP_ADD
                // add rax, rcx (0x48, 0x01, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 1)
                ssa_lowerer_emit_byte(low, 200)
            elif op == OP_ADD_DYN
                // Dynamic int/str addition: mov rdi, rax; mov rsi, rcx; call _lipi_add_dynamic
                ssa_lowerer_emit_bytes(low, [72, 137, 199, 72, 137, 206, 232])
                p_add = low.low_code.len()
                ssa_lowerer_emit_u32(low, 0)
                jp_add = SsaJumpPatch()
                jp_add.sjp_offset = p_add
                jp_add.sjp_target = "_lipi_add_dynamic"
                jp_add.sjp_kind = 10
                push(low.low_call_patches, jp_add)
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
            elif op == OP_DIV
                // Guarded cqo; idiv rcx: calls _lipi_div_by_zero on rcx==0 (throws inside try, 0 outside) & guards INT64_MIN/-1
                // test rcx, rcx; jnz +7; call _lipi_div_by_zero; jmp +16; cmp rcx, -1; jne +5; neg rax; jmp +5; cqo; idiv rcx
                ssa_lowerer_emit_bytes(low, [72, 133, 201, 117, 7, 232])
                p_dz1 = low.low_code.len()
                ssa_lowerer_emit_u32(low, 0)
                jp_dz1 = SsaJumpPatch()
                jp_dz1.sjp_offset = p_dz1
                jp_dz1.sjp_target = "_lipi_div_by_zero"
                jp_dz1.sjp_kind = 10
                push(low.low_call_patches, jp_dz1)
                ssa_lowerer_emit_bytes(low, [235, 16, 72, 131, 249, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 72, 247, 249])
            elif op == OP_MOD
                // Guarded cqo; idiv rcx; mov rax, rdx with _lipi_div_by_zero guard on rcx==0
                // test rcx, rcx; jnz +7; call _lipi_div_by_zero; jmp +18; cmp rcx, -1; jne +4; xor eax, eax; jmp +8; cqo; idiv rcx; mov rax, rdx
                ssa_lowerer_emit_bytes(low, [72, 133, 201, 117, 7, 232])
                p_dz2 = low.low_code.len()
                ssa_lowerer_emit_u32(low, 0)
                jp_dz2 = SsaJumpPatch()
                jp_dz2.sjp_offset = p_dz2
                jp_dz2.sjp_target = "_lipi_div_by_zero"
                jp_dz2.sjp_kind = 10
                push(low.low_call_patches, jp_dz2)
                ssa_lowerer_emit_bytes(low, [235, 18, 72, 131, 249, 255, 117, 4, 49, 192, 235, 8, 72, 153, 72, 247, 249, 72, 137, 208])
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
            elif op == OP_SHL
                // shl rax, cl (0x48, 0xD3, 0xE0)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 211)
                ssa_lowerer_emit_byte(low, 224)
            elif op == OP_SHR
                // sar rax, cl (0x48, 0xD3, 0xF8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 211)
                ssa_lowerer_emit_byte(low, 248)
            end

            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        return 0

    if op == OP_NEG
        if inst.operands.len() >= 1 and inst.result != 0
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            // neg rax (0x48, 0xF7, 0xD8)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 247)
            ssa_lowerer_emit_byte(low, 216)
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_FNEG
        if inst.operands.len() >= 1 and inst.result != 0
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            // movabs rcx, 0x8000000000000000; xor rax, rcx
            ssa_lowerer_emit_bytes(low, [72, 185, 0, 0, 0, 0, 0, 0, 0, 128, 72, 49, 200])
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_I2F
        if inst.operands.len() >= 1 and inst.result != 0
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            // cvtsi2sd xmm0, rax; movq rax, xmm0
            ssa_lowerer_emit_bytes(low, [242, 72, 15, 42, 192, 102, 72, 15, 126, 192])
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_FADD or op == OP_FSUB or op == OP_FMUL or op == OP_FDIV
        if inst.operands.len() >= 2 and inst.result != 0
            ssa_lower_x86_load_val_to_reg(low, inst.operands[0], 0)
            ssa_lower_x86_load_val_to_reg(low, inst.operands[1], 1)
            // movq xmm0, rax; movq xmm1, rcx (ZERO push/pop!)
            ssa_lowerer_emit_bytes(low, [102, 72, 15, 110, 192, 102, 72, 15, 110, 201])
            if op == OP_FADD
                ssa_lowerer_emit_bytes(low, [242, 15, 88, 193]) // addsd xmm0, xmm1
            elif op == OP_FSUB
                ssa_lowerer_emit_bytes(low, [242, 15, 92, 193]) // subsd xmm0, xmm1
            elif op == OP_FMUL
                ssa_lowerer_emit_bytes(low, [242, 15, 89, 193]) // mulsd xmm0, xmm1
            else
                ssa_lowerer_emit_bytes(low, [242, 15, 94, 193]) // divsd xmm0, xmm1
            end
            // movq rax, xmm0
            ssa_lowerer_emit_bytes(low, [102, 72, 15, 126, 192])
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_FCMP
        if inst.operands.len() >= 2 and inst.result != 0
            ssa_lower_x86_load_val_to_reg(low, inst.operands[0], 0)
            ssa_lower_x86_load_val_to_reg(low, inst.operands[1], 1)
            // movq xmm0, rax; movq xmm1, rcx; ucomisd xmm0, xmm1 (ZERO push/pop!)
            ssa_lowerer_emit_bytes(low, [102, 72, 15, 110, 192, 102, 72, 15, 110, 201, 102, 15, 46, 193])
            pred = inst.extra_int
            if pred == CMP_EQ
                ssa_lowerer_emit_bytes(low, [15, 148, 192]) // sete al
            elif pred == CMP_NE
                ssa_lowerer_emit_bytes(low, [15, 149, 192]) // setne al
            elif pred == CMP_SLT
                ssa_lowerer_emit_bytes(low, [15, 146, 192]) // setb al
            elif pred == CMP_SLE
                ssa_lowerer_emit_bytes(low, [15, 150, 192]) // setbe al
            elif pred == CMP_SGT
                ssa_lowerer_emit_bytes(low, [15, 151, 192]) // seta al
            else
                ssa_lowerer_emit_bytes(low, [15, 147, 192]) // setae al
            end
            ssa_lowerer_emit_bytes(low, [72, 15, 182, 192]) // movzx rax, al
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_STR_LIT
        if inst.result != 0
            ro_off = ssa_lowerer_add_rodata_str(low, inst.extra_str)
            // movabs rax, <str_vaddr> (patched via slr_str_relocs when spliced into x86_64)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 184)
            patch_s = low.low_code.len()
            ssa_lowerer_emit_bytes(low, [0, 0, 0, 0, 0, 0, 0, 0])
            push(low.low_str_relocs, [patch_s, ro_off])
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_STRUCT_NEW
        if inst.result != 0
            alloc_sz = inst.extra_int
            if alloc_sz < 32
                alloc_sz = 32
            end
            // mov edi, alloc_sz; call _lipi_user_alloc
            ssa_x86_emit_mov_imm(low, 7, alloc_sz)
            ssa_lowerer_emit_byte(low, 232)
            p_alloc = low.low_code.len()
            ssa_lowerer_emit_u32(low, 0)
            jp_al = SsaJumpPatch()
            jp_al.sjp_offset = p_alloc
            jp_al.sjp_target = "_lipi_user_alloc"
            jp_al.sjp_kind = 10
            push(low.low_call_patches, jp_al)
            // Initialize fields directly with ptr in %rax and val loaded into %rcx (ZERO push/pop!)
            // Operands have spans_call=1 (guaranteed in callee-saved reg or stack slot).
            fi = 0
            while fi < inst.operands.len()
                ssa_lower_x86_load_val_to_reg(low, inst.operands[fi], 1)
                foff_s = fi * 8
                if foff_s == 0
                    ssa_lowerer_emit_bytes(low, [72, 137, 8]) // mov [rax], rcx
                elif foff_s < 128
                    ssa_lowerer_emit_bytes(low, [72, 137, 72, foff_s]) // mov [rax+disp8], rcx
                else
                    ssa_lowerer_emit_bytes(low, [72, 137, 136])
                    ssa_lowerer_emit_u32(low, foff_s)
                end
                fi = fi + 1
            end
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_FIELD_LOAD
        if inst.operands.len() >= 1 and inst.result != 0
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            // Null-deref guard: cmp rax, 4096; jae +5; call _lipi_throw_null_deref
            ssa_lowerer_emit_bytes(low, [72, 61, 0, 16, 0, 0, 115, 5, 232])
            p_npe = low.low_code.len()
            ssa_lowerer_emit_u32(low, 0)
            jp_npe = SsaJumpPatch()
            jp_npe.sjp_offset = p_npe
            jp_npe.sjp_target = "_lipi_throw_null_deref"
            jp_npe.sjp_kind = 10
            push(low.low_call_patches, jp_npe)
            // Compact mov rax, [rax + byte_off] (3B for 0, 4B for <128, 7B otherwise)
            fl_off = inst.extra_int
            if fl_off == 0
                ssa_lowerer_emit_bytes(low, [72, 139, 0])
            elif fl_off < 128
                ssa_lowerer_emit_bytes(low, [72, 139, 64, fl_off])
            else
                ssa_lowerer_emit_bytes(low, [72, 139, 128])
                ssa_lowerer_emit_u32(low, fl_off)
            end
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_FIELD_STORE
        if inst.operands.len() >= 2
            // Check object pointer FIRST while %rsp is 16-byte aligned before any call to _lipi_throw_null_deref
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            // cmp rax, 4096; jae +5; call _lipi_throw_null_deref
            ssa_lowerer_emit_bytes(low, [72, 61, 0, 16, 0, 0, 115, 5, 232])
            p_npe2 = low.low_code.len()
            ssa_lowerer_emit_u32(low, 0)
            jp_npe2 = SsaJumpPatch()
            jp_npe2.sjp_offset = p_npe2
            jp_npe2.sjp_target = "_lipi_throw_null_deref"
            jp_npe2.sjp_kind = 10
            push(low.low_call_patches, jp_npe2)
            // Load value directly into %rcx without touching %rax (ZERO push/pop!)
            ssa_lower_x86_load_val_to_reg(low, inst.operands[1], 1)
            fs_off = inst.extra_int
            if fs_off == 0
                ssa_lowerer_emit_bytes(low, [72, 137, 8])
            elif fs_off < 128
                ssa_lowerer_emit_bytes(low, [72, 137, 72, fs_off])
            else
                ssa_lowerer_emit_bytes(low, [72, 137, 136])
                ssa_lowerer_emit_u32(low, fs_off)
            end
        end
        return 0

    if op == OP_CMP or op == OP_CMP_DYN
        // cmp pred, %a, %b  (direct rax & rcx loads: ZERO push/pop!)
        if inst.operands.len() >= 2 and inst.result != 0
            val_a = inst.operands[0]
            val_b = inst.operands[1]
            ssa_lower_x86_load_val_to_reg(low, val_a, 0)
            ssa_lower_x86_load_val_to_reg(low, val_b, 1)

            if op == OP_CMP_DYN
                // mov rdi, rax; mov rsi, rcx; call _lipi_cmp_dynamic; test eax, eax
                ssa_lowerer_emit_bytes(low, [72, 137, 199, 72, 137, 206, 232])
                p_cmp = low.low_code.len()
                ssa_lowerer_emit_u32(low, 0)
                jp_cmp = SsaJumpPatch()
                jp_cmp.sjp_offset = p_cmp
                jp_cmp.sjp_target = "_lipi_cmp_dynamic"
                jp_cmp.sjp_kind = 10
                push(low.low_call_patches, jp_cmp)
                ssa_lowerer_emit_bytes(low, [133, 192]) // test eax, eax
            else
                // cmp rax, rcx (0x48, 0x39, 0xC8)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 57)
                ssa_lowerer_emit_byte(low, 200)
            end

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
            cond_pr = 0 - 1
            if cond_val != 0 and cond_val.kind != VAL_KIND_CONST and cond_val.val_kind != VAL_KIND_CONST
                cond_pr = ssa_x86_find_phys_reg(low, cond_val.id)
            end
            if cond_pr >= 0
                // Direct `test cr, cr` (3 bytes — zero register move!)
                rex_t = 72
                if cond_pr >= 8 rex_t = 77 end // REX.W | REX.R | REX.B
                ssa_lowerer_emit_byte(low, rex_t)
                ssa_lowerer_emit_byte(low, 133)
                ssa_lowerer_emit_byte(low, 192 | ((cond_pr & 7) << 3) | (cond_pr & 7))
            else
                ssa_lower_x86_load_val_to_rax(low, cond_val)
                // test rax, rax (0x48, 0x85, 0xC0)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 133)
                ssa_lowerer_emit_byte(low, 192)
            end

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

    if op == OP_CALL
        // WHY: Lowers function invocation under System V AMD64 ABI (up to 16 arguments!):
        // passes args 0..5 in %rdi, %rsi, %rdx, %rcx, %r8, %r9 and args 6..N-1 on 16B-aligned stack.
        nargs = inst.operands.len()
        stack_cleanup = 0
        if nargs > 6
            extra_args = nargs - 6
            pad_bytes = (extra_args % 2) * 8
            stack_cleanup = (extra_args * 8) + pad_bytes
            if pad_bytes > 0
                ssa_lowerer_emit_bytes(low, [72, 131, 236, 8]) // sub rsp, 8
            end
            si_a = nargs - 1
            while si_a >= 6
                ssa_lower_x86_load_val_to_rax(low, inst.operands[si_a])
                ssa_lowerer_emit_byte(low, 80) // push rax
                si_a = si_a - 1
            end
        end
        // Direct SysV arg load into rdi(7), rsi(6), rdx(2), rcx(1), r8(8), r9(9) — disjoint from SSA reg pool!
        arg_i = 0
        while arg_i < nargs and arg_i < 6
            arg_op = inst.operands[arg_i]
            if arg_i == 0
                ssa_lower_x86_load_val_to_reg(low, arg_op, 7)
            elif arg_i == 1
                ssa_lower_x86_load_val_to_reg(low, arg_op, 6)
            elif arg_i == 2
                ssa_lower_x86_load_val_to_reg(low, arg_op, 2)
            elif arg_i == 3
                ssa_lower_x86_load_val_to_reg(low, arg_op, 1)
            elif arg_i == 4
                ssa_lower_x86_load_val_to_reg(low, arg_op, 8)
            elif arg_i == 5
                ssa_lower_x86_load_val_to_reg(low, arg_op, 9)
            end
            arg_i = arg_i + 1
        end
        // Emit call rel32 (0xE8, disp32)
        ssa_lowerer_emit_byte(low, 232)
        patch_call = low.low_code.len()
        ssa_lowerer_emit_u32(low, 0)
        jp_call = SsaJumpPatch()
        jp_call.sjp_offset = patch_call
        jp_call.sjp_target = inst.extra_str
        jp_call.sjp_kind = 10
        push(low.low_call_patches, jp_call)
        if stack_cleanup > 0
            ssa_lowerer_emit_bytes(low, [72, 129, 196]) // add rsp, imm32
            ssa_lowerer_emit_u32(low, stack_cleanup)
        end
        if inst.result != 0
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
        end
        return 0

    if op == OP_RET
        // ret %val
        if inst.operands.len() >= 1
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
        ssa_lower_x86_epilogue(low)
        return 0

    return 0

// ── 4b. Native ARM64 (AAPCS64) Direct SSA CFG Lowering ────────────────────────

fn ssa_a64_emit_imm64 low rd val
    // WHY: Loads any 64-bit signed/unsigned constant into ARM64 register Xd via MOVZ + MOVK quad.
    ssa_lowerer_emit_u32(low, 3531603968 | ((val & 65535) << 5) | rd) // movz Xd, lo16
    w1 = (val >> 16) & 65535
    w2 = (val >> 32) & 65535
    w3 = (val >> 48) & 65535
    if w1 != 0
        ssa_lowerer_emit_u32(low, 4068474880 | (1 << 21) | (w1 << 5) | rd) // movk Xd, w1, lsl #16
    end
    if w2 != 0
        ssa_lowerer_emit_u32(low, 4068474880 | (2 << 21) | (w2 << 5) | rd) // movk Xd, w2, lsl #32
    end
    if w3 != 0
        ssa_lowerer_emit_u32(low, 4068474880 | (3 << 21) | (w3 << 5) | rd) // movk Xd, w3, lsl #48
    end
    return 0

fn ssa_a64_find_phys_reg low name
    // WHY: O(1) ARM64 physical register lookup in safe non-ABI pool {x12..x15, x19..x28}.
    if low.low_reg_map != 0 and name != 0 and has_key(low.low_reg_map, name) == 1
        return low.low_reg_map[name] - 1
    end
    return 0 - 1
end

fn ssa_a64_emit_mov_rr low dst src
    if dst == src return 0 end
    ssa_lowerer_emit_u32(low, 2852127712 | ((src & 31) << 16) | (dst & 31)) // mov Xd, Xs
    return 0
end

fn ssa_a64_emit_load_slot low dst off
    if off <= 256
        simm9 = (0 - off) & 511
        ssa_lowerer_emit_u32(low, 4164943872 | (simm9 << 12) | (29 << 5) | (dst & 31)) // ldur Xd, [x29, #-off]
        return 0
    end
    ssa_a64_emit_imm64(low, 9, off)
    ssa_lowerer_emit_u32(low, 3406365610) // sub x10, x29, x9
    ssa_lowerer_emit_u32(low, 4181721408 | (dst & 31)) // ldr Xd, [x10, #0]
    return 0
end

fn ssa_a64_emit_store_slot low src off
    if off <= 256
        simm9 = (0 - off) & 511
        ssa_lowerer_emit_u32(low, 4160749568 | (simm9 << 12) | (29 << 5) | (src & 31)) // stur Xs, [x29, #-off]
        return 0
    end
    ssa_a64_emit_imm64(low, 9, off)
    ssa_lowerer_emit_u32(low, 3406365610) // sub x10, x29, x9
    ssa_lowerer_emit_u32(low, 4177527104 | (src & 31)) // str Xs, [x10, #0]
    return 0
end

fn ssa_a64_load_val_to_reg low val dst
    if val == 0
        ssa_lowerer_emit_u32(low, 3531603968 | (dst & 31)) // movz Xd, #0
        return 0
    end
    if val.kind == VAL_KIND_CONST or val.val_kind == VAL_KIND_CONST
        ssa_a64_emit_imm64(low, dst, val.const_val)
        return 0
    end
    pr = ssa_a64_find_phys_reg(low, val.id)
    if pr >= 0
        ssa_a64_emit_mov_rr(low, dst, pr)
        return 0
    end
    off = ssa_lowerer_get_or_add_slot(low, val.id)
    ssa_a64_emit_load_slot(low, dst, off)
    return 0
end

fn ssa_a64_resolve_val_reg low val scratch_reg
    // WHY: Returns physical register directly if allocated (0 instructions!), else loads into scratch_reg.
    if val != 0 and val.kind != VAL_KIND_CONST and val.val_kind != VAL_KIND_CONST
        pr = ssa_a64_find_phys_reg(low, val.id)
        if pr >= 0 return pr end
    end
    ssa_a64_load_val_to_reg(low, val, scratch_reg)
    return scratch_reg
end

fn ssa_a64_load_val_to_x0 low val
    return ssa_a64_load_val_to_reg(low, val, 0)
end

fn ssa_a64_store_reg_to_slot low rs slot_name
    pr = ssa_a64_find_phys_reg(low, slot_name)
    if pr >= 0
        ssa_a64_emit_mov_rr(low, pr, rs)
        return 0
    end
    off = ssa_lowerer_get_or_add_slot(low, slot_name)
    ssa_a64_emit_store_slot(low, rs, off)
    return 0
end

fn ssa_a64_epilogue low
    if low.low_used_callee != 0
        ci = low.low_used_callee.len() - 1
        while ci >= 0
            ssa_a64_emit_load_slot(low, low.low_used_callee[ci], (ci + 1) * 8)
            ci = ci - 1
        end
    end
    ssa_lowerer_emit_u32(low, 3531603969) // movz x1, #0 (pure int tag for ARM64 dyn callers)
    ssa_lowerer_emit_u32(low, 2432697279) // mov sp, x29
    ssa_lowerer_emit_u32(low, 2831252477) // ldp x29, x30, [sp], #16
    ssa_lowerer_emit_u32(low, 3596551104) // ret
    return 0
end

fn ssa_lower_instruction_arm64 low inst
    if inst.is_dead == 1 return 0 end
    low.low_total_insts = low.low_total_insts + 1
    op = inst.op

    if op == OP_NOP
        ssa_lowerer_emit_u32(low, 3573751839) // nop (0xD503201F)
        return 0
    end
    if op == OP_ALLOCA
        if inst.result != 0 and ssa_a64_find_phys_reg(low, inst.result.id) < 0
            ssa_lowerer_get_or_add_slot(low, inst.result.id)
        end
        return 0
    end
    if op == OP_STORE
        if inst.operands.len() >= 2
            dst_p = ssa_a64_find_phys_reg(low, inst.operands[1].id)
            if dst_p >= 0
                ssa_a64_load_val_to_reg(low, inst.operands[0], dst_p)
            else
                sr = ssa_a64_resolve_val_reg(low, inst.operands[0], 0)
                off_s = ssa_lowerer_get_or_add_slot(low, inst.operands[1].id)
                ssa_a64_emit_store_slot(low, sr, off_s)
            end
        end
        return 0
    end
    if op == OP_LOAD
        if inst.operands.len() >= 1 and inst.result != 0
            dst_p = ssa_a64_find_phys_reg(low, inst.result.id)
            if dst_p >= 0
                ssa_a64_load_val_to_reg(low, inst.operands[0], dst_p)
            else
                sr = ssa_a64_resolve_val_reg(low, inst.operands[0], 0)
                off_d = ssa_lowerer_get_or_add_slot(low, inst.result.id)
                ssa_a64_emit_store_slot(low, sr, off_d)
            end
        end
        return 0
    end
    if op == OP_ADD or op == OP_SUB or op == OP_MUL or op == OP_DIV or op == OP_MOD or op == OP_AND or op == OP_OR or op == OP_XOR or op == OP_SHL or op == OP_SHR
        if inst.operands.len() >= 2 and inst.result != 0
            if op == OP_MOD
                ssa_a64_load_val_to_reg(low, inst.operands[0], 0)
                ssa_a64_load_val_to_reg(low, inst.operands[1], 1)
                // cbnz x1, +3; movz x0, #0; b +3; sdiv x2, x0, x1; msub x0, x2, x1, x0
                ssa_lowerer_emit_u32(low, 3036676097 | (3 << 5))
                ssa_lowerer_emit_u32(low, 3531603968)
                ssa_lowerer_emit_u32(low, 335544323)
                ssa_lowerer_emit_u32(low, 2596342786) // sdiv x2, x0, x1
                ssa_lowerer_emit_u32(low, 2600566848) // msub x0, x2, x1, x0
                ssa_a64_store_reg_to_slot(low, 0, inst.result.id)
            else
                // Direct 3-address AAPCS64 ALU using linear-scan physical registers (1 instruction = 4B!)
                ra = ssa_a64_resolve_val_reg(low, inst.operands[0], 0)
                rb = ssa_a64_resolve_val_reg(low, inst.operands[1], 1)
                dst_p = ssa_a64_find_phys_reg(low, inst.result.id)
                rd = dst_p
                if rd < 0 rd = 0 end
                if op == OP_ADD
                    ssa_lowerer_emit_u32(low, 2332033024 | (rb << 16) | (ra << 5) | rd) // add Xd, Xa, Xb
                elif op == OP_SUB
                    ssa_lowerer_emit_u32(low, 3405774848 | (rb << 16) | (ra << 5) | rd) // sub Xd, Xa, Xb
                elif op == OP_MUL
                    ssa_lowerer_emit_u32(low, 2600500224 | (rb << 16) | (ra << 5) | rd) // mul Xd, Xa, Xb
                elif op == OP_DIV
                    ssa_lowerer_emit_u32(low, 2596277248 | (rb << 16) | (ra << 5) | rd) // sdiv Xd, Xa, Xb
                elif op == OP_AND
                    ssa_lowerer_emit_u32(low, 2315255808 | (rb << 16) | (ra << 5) | rd) // and Xd, Xa, Xb
                elif op == OP_OR
                    ssa_lowerer_emit_u32(low, 2852126720 | (rb << 16) | (ra << 5) | rd) // orr Xd, Xa, Xb
                elif op == OP_XOR
                    ssa_lowerer_emit_u32(low, 3388997632 | (rb << 16) | (ra << 5) | rd) // eor Xd, Xa, Xb
                elif op == OP_SHL
                    ssa_lowerer_emit_u32(low, 2596282368 | (rb << 16) | (ra << 5) | rd) // lslv Xd, Xa, Xb
                elif op == OP_SHR
                    ssa_lowerer_emit_u32(low, 2596284416 | (rb << 16) | (ra << 5) | rd) // asrv Xd, Xa, Xb
                end
                if dst_p < 0
                    ssa_a64_store_reg_to_slot(low, 0, inst.result.id)
                end
            end
        end
        return 0
    end
    if op == OP_NEG
        if inst.operands.len() >= 1 and inst.result != 0
            ra = ssa_a64_resolve_val_reg(low, inst.operands[0], 0)
            dst_p = ssa_a64_find_phys_reg(low, inst.result.id)
            rd = dst_p
            if rd < 0 rd = 0 end
            ssa_lowerer_emit_u32(low, 3405775840 | (ra << 16) | rd) // sub Xd, xzr, Xa
            if dst_p < 0
                ssa_a64_store_reg_to_slot(low, 0, inst.result.id)
            end
        end
        return 0
    end
    if op == OP_CMP
        if inst.operands.len() >= 2 and inst.result != 0
            ra = ssa_a64_resolve_val_reg(low, inst.operands[0], 0)
            rb = ssa_a64_resolve_val_reg(low, inst.operands[1], 1)
            ssa_lowerer_emit_u32(low, 3942645791 | (rb << 16) | (ra << 5)) // cmp Xa, Xb (subs xzr, Xa, Xb)
            dst_p = ssa_a64_find_phys_reg(low, inst.result.id)
            rd = dst_p
            if rd < 0 rd = 0 end
            pred = inst.extra_int
            if pred == CMP_EQ
                ssa_lowerer_emit_u32(low, 2594117600 | rd) // cset Xd, eq
            elif pred == CMP_NE
                ssa_lowerer_emit_u32(low, 2594113504 | rd) // cset Xd, ne
            elif pred == CMP_SLT
                ssa_lowerer_emit_u32(low, 2594154464 | rd) // cset Xd, lt
            elif pred == CMP_SLE
                ssa_lowerer_emit_u32(low, 2594162656 | rd) // cset Xd, le
            elif pred == CMP_SGT
                ssa_lowerer_emit_u32(low, 2594166752 | rd) // cset Xd, gt
            else
                ssa_lowerer_emit_u32(low, 2594158560 | rd) // cset Xd, ge
            end
            if dst_p < 0
                ssa_a64_store_reg_to_slot(low, 0, inst.result.id)
            end
        end
        return 0
    end
    if op == OP_JMP
        p_j = buf_len(low.low_code)
        ssa_lowerer_emit_u32(low, 335544320) // b 0 placeholder
        jp = SsaJumpPatch()
        jp.sjp_offset = p_j
        jp.sjp_target = inst.extra_str
        jp.sjp_kind = 0
        push(low.low_patches, jp)
        return 0
    end
    if op == OP_BR
        if inst.operands.len() >= 1
            rc = ssa_a64_resolve_val_reg(low, inst.operands[0], 0)
            target_then = inst.extra_str
            target_else = ""
            if inst.extra_list.len() > 0
                target_then = inst.extra_list[0]
                if inst.extra_list.len() > 1
                    target_else = inst.extra_list[1]
                end
            end
            p_t = buf_len(low.low_code)
            ssa_lowerer_emit_u32(low, 3036676096 | (rc & 31)) // cbnz Xc, 0 placeholder
            jp_t = SsaJumpPatch()
            jp_t.sjp_offset = p_t
            jp_t.sjp_target = target_then
            jp_t.sjp_kind = 1
            push(low.low_patches, jp_t)
            if len(target_else) > 0
                p_e = buf_len(low.low_code)
                ssa_lowerer_emit_u32(low, 335544320) // b 0 placeholder
                jp_e = SsaJumpPatch()
                jp_e.sjp_offset = p_e
                jp_e.sjp_target = target_else
                jp_e.sjp_kind = 0
                push(low.low_patches, jp_e)
            end
        end
        return 0
    end
    if op == OP_CALL
        // AAPCS64 argument marshaling: up to 16 args (X0..X7 + 16B-aligned stack args [sp+0], [sp+8], ...)
        nargs = inst.operands.len()
        if nargs > 16 nargs = 16 end
        n_stack_a = 0
        stack_pad_a = 0
        if nargs > 8
            n_stack_a = nargs - 8
            stack_pad_a = ((n_stack_a + 1) / 2) * 16
            ssa_lowerer_emit_u32(low, 3506438144 | ((stack_pad_a & 4095) << 10) | (31 << 5) | 31) // sub sp, sp, #stack_pad_a
            sj_a = 0
            while sj_a < n_stack_a
                sr_a = ssa_a64_resolve_val_reg(low, inst.operands[8 + sj_a], 0)
                ssa_lowerer_emit_u32(low, 4177526784 | ((sj_a & 4095) << 10) | (31 << 5) | (sr_a & 31)) // str Xsr, [sp, #sj_a*8]
                sj_a = sj_a + 1
            end
        end
        n_reg_a = nargs
        if n_reg_a > 8 n_reg_a = 8 end
        ai = 0
        while ai < n_reg_a
            // Safe non-ABI pool {x12..x15, x19..x28} is completely disjoint from X0..X7!
            ssa_a64_load_val_to_reg(low, inst.operands[ai], ai)
            ai = ai + 1
        end
        p_bl = buf_len(low.low_code)
        ssa_lowerer_emit_u32(low, 2483027968) // bl 0 placeholder
        jp_c = SsaJumpPatch()
        jp_c.sjp_offset = p_bl
        jp_c.sjp_target = inst.extra_str
        jp_c.sjp_kind = 10
        push(low.low_call_patches, jp_c)
        if stack_pad_a > 0
            ssa_lowerer_emit_u32(low, 2432696320 | ((stack_pad_a & 4095) << 10) | (31 << 5) | 31) // add sp, sp, #stack_pad_a
        end
        if inst.result != 0
            ssa_a64_store_reg_to_slot(low, 0, inst.result.id)
        end
        return 0
    end
    if op == OP_RET
        if inst.operands.len() >= 1
            ssa_a64_load_val_to_x0(low, inst.operands[0])
        else
            ssa_lowerer_emit_u32(low, 3531603968)
        end
        ssa_a64_epilogue(low)
        return 0
    end
    return 0

// ── 4c. Native RISC-V 64 (LP64 / RV64IM) Direct SSA CFG Lowering ──────────────

fn ssa_rv_r low opcode rd f3 rs1 rs2 f7
    w = ((f7 & 127) << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | ((f3 & 7) << 12) | ((rd & 31) << 7) | (opcode & 127)
    ssa_lowerer_emit_u32(low, w)
    return 0

fn ssa_rv_i low opcode rd f3 rs1 imm12
    w = ((imm12 & 4095) << 20) | ((rs1 & 31) << 15) | ((f3 & 7) << 12) | ((rd & 31) << 7) | (opcode & 127)
    ssa_lowerer_emit_u32(low, w)
    return 0

fn ssa_rv_s low opcode f3 rs1 rs2 imm12
    w = (((imm12 >> 5) & 127) << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | ((f3 & 7) << 12) | ((imm12 & 31) << 7) | (opcode & 127)
    ssa_lowerer_emit_u32(low, w)
    return 0

fn ssa_rv_b_word f3 rs1 rs2 rel
    b12 = (rel >> 12) & 1
    b11 = (rel >> 11) & 1
    b10_5 = (rel >> 5) & 63
    b4_1 = (rel >> 1) & 15
    return (b12 << 31) | (b10_5 << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | ((f3 & 7) << 12) | (b4_1 << 8) | (b11 << 7) | 99

fn ssa_rv_j_word rd rel
    b20 = (rel >> 20) & 1
    b10_1 = (rel >> 1) & 1023
    b11 = (rel >> 11) & 1
    b19_12 = (rel >> 12) & 255
    return (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | ((rd & 31) << 7) | 111

fn ssa_rv_emit_li low rd val
    if val >= (0 - 2048) and val <= 2047
        ssa_rv_i(low, 19, rd, 0, 0, val)
        return 0
    end
    if val >= (0 - 2147483648) and val <= 2147483647
        lo = val & 4095
        if lo >= 2048 lo = lo - 4096 end
        hi = ((val - lo) >> 12) & 1048575
        ssa_lowerer_emit_u32(low, (hi << 12) | ((rd & 31) << 7) | 55) // lui rd, hi
        if lo != 0
            ssa_rv_i(low, 19, rd, 0, rd, lo)
        end
        return 0
    end
    c5 = val >> 55
    ssa_rv_i(low, 19, rd, 0, 0, c5)
    ssa_rv_i(low, 19, rd, 1, rd, 11)
    c4 = (val >> 44) & 2047
    if c4 != 0 ssa_rv_i(low, 19, rd, 6, rd, c4) end
    ssa_rv_i(low, 19, rd, 1, rd, 11)
    c3 = (val >> 33) & 2047
    if c3 != 0 ssa_rv_i(low, 19, rd, 6, rd, c3) end
    ssa_rv_i(low, 19, rd, 1, rd, 11)
    c2 = (val >> 22) & 2047
    if c2 != 0 ssa_rv_i(low, 19, rd, 6, rd, c2) end
    ssa_rv_i(low, 19, rd, 1, rd, 11)
    c1 = (val >> 11) & 2047
    if c1 != 0 ssa_rv_i(low, 19, rd, 6, rd, c1) end
    ssa_rv_i(low, 19, rd, 1, rd, 11)
    c0 = val & 2047
    if c0 != 0 ssa_rv_i(low, 19, rd, 6, rd, c0) end
    return 0

fn ssa_rv_find_phys_reg low name
    // WHY: O(1) RISC-V 64 physical register lookup in safe non-ABI pool {t3..t6, s1..s11}.
    if low.low_reg_map != 0 and name != 0 and has_key(low.low_reg_map, name) == 1
        return low.low_reg_map[name] - 1
    end
    return 0 - 1
end

fn ssa_rv_emit_mv low dst src
    if dst == src return 0 end
    ssa_rv_i(low, 19, dst, 0, src, 0) // addi dst, src, 0
    return 0
end

fn ssa_rv_emit_load_slot low dst off
    full_off = 16 + off
    if full_off <= 2048
        ssa_rv_i(low, 3, dst, 3, 8, 0 - full_off) // ld dst, -(16+off)(s0) (1 instruction!)
        return 0
    end
    ssa_rv_emit_li(low, 5, full_off)  // li t0, 16+off
    ssa_rv_r(low, 51, 6, 0, 8, 5, 32) // sub t1, s0, t0
    ssa_rv_i(low, 3, dst, 3, 6, 0)    // ld dst, 0(t1)
    return 0
end

fn ssa_rv_emit_store_slot low src off
    full_off = 16 + off
    if full_off <= 2048
        ssa_rv_s(low, 35, 3, 8, src, 0 - full_off) // sd src, -(16+off)(s0) (1 instruction!)
        return 0
    end
    ssa_rv_emit_li(low, 5, full_off)  // li t0, 16+off
    ssa_rv_r(low, 51, 6, 0, 8, 5, 32) // sub t1, s0, t0
    ssa_rv_s(low, 35, 3, 6, src, 0)   // sd src, 0(t1)
    return 0
end

fn ssa_rv_load_val_to_reg low val dst
    if val == 0
        ssa_rv_i(low, 19, dst, 0, 0, 0) // li dst, 0
        return 0
    end
    if val.kind == VAL_KIND_CONST or val.val_kind == VAL_KIND_CONST
        ssa_rv_emit_li(low, dst, val.const_val)
        return 0
    end
    pr = ssa_rv_find_phys_reg(low, val.id)
    if pr >= 0
        ssa_rv_emit_mv(low, dst, pr)
        return 0
    end
    off = ssa_lowerer_get_or_add_slot(low, val.id)
    ssa_rv_emit_load_slot(low, dst, off)
    return 0
end

fn ssa_rv_resolve_val_reg low val scratch_reg
    // WHY: Returns physical register directly if allocated (0 instructions!), else loads into scratch_reg.
    if val != 0 and val.kind != VAL_KIND_CONST and val.val_kind != VAL_KIND_CONST
        pr = ssa_rv_find_phys_reg(low, val.id)
        if pr >= 0 return pr end
    end
    ssa_rv_load_val_to_reg(low, val, scratch_reg)
    return scratch_reg
end

fn ssa_rv_load_val_to_a0 low val
    return ssa_rv_load_val_to_reg(low, val, 10)
end

fn ssa_rv_store_reg_to_slot low rs slot_name
    pr = ssa_rv_find_phys_reg(low, slot_name)
    if pr >= 0
        ssa_rv_emit_mv(low, pr, rs)
        return 0
    end
    off = ssa_lowerer_get_or_add_slot(low, slot_name)
    ssa_rv_emit_store_slot(low, rs, off)
    return 0
end

fn ssa_rv_epilogue low
    if low.low_used_callee != 0
        ci = low.low_used_callee.len() - 1
        while ci >= 0
            ssa_rv_emit_load_slot(low, low.low_used_callee[ci], (ci + 1) * 8)
            ci = ci - 1
        end
    end
    ssa_rv_i(low, 19, 11, 0, 0, 0)        // li a1, 0 (pure int tag for RV64 dyn callers)
    ssa_rv_i(low, 19, 2, 0, 8, 0 - 16)    // addi sp, s0, -16
    ssa_rv_i(low, 3, 1, 3, 2, 8)          // ld ra, 8(sp)
    ssa_rv_i(low, 3, 8, 3, 2, 0)          // ld s0, 0(sp)
    ssa_rv_i(low, 19, 2, 0, 2, 16)        // addi sp, sp, 16
    ssa_rv_i(low, 103, 0, 0, 1, 0)        // jalr x0, ra, 0 (ret)
    return 0
end

fn ssa_lower_instruction_riscv64 low inst
    if inst.is_dead == 1 return 0 end
    low.low_total_insts = low.low_total_insts + 1
    op = inst.op

    if op == OP_NOP
        ssa_rv_i(low, 19, 0, 0, 0, 0) // nop
        return 0
    end
    if op == OP_ALLOCA
        if inst.result != 0 and ssa_rv_find_phys_reg(low, inst.result.id) < 0
            ssa_lowerer_get_or_add_slot(low, inst.result.id)
        end
        return 0
    end
    if op == OP_STORE
        if inst.operands.len() >= 2
            dst_p = ssa_rv_find_phys_reg(low, inst.operands[1].id)
            if dst_p >= 0
                ssa_rv_load_val_to_reg(low, inst.operands[0], dst_p)
            else
                sr = ssa_rv_resolve_val_reg(low, inst.operands[0], 10)
                off_s = ssa_lowerer_get_or_add_slot(low, inst.operands[1].id)
                ssa_rv_emit_store_slot(low, sr, off_s)
            end
        end
        return 0
    end
    if op == OP_LOAD
        if inst.operands.len() >= 1 and inst.result != 0
            dst_p = ssa_rv_find_phys_reg(low, inst.result.id)
            if dst_p >= 0
                ssa_rv_load_val_to_reg(low, inst.operands[0], dst_p)
            else
                sr = ssa_rv_resolve_val_reg(low, inst.operands[0], 10)
                off_d = ssa_lowerer_get_or_add_slot(low, inst.result.id)
                ssa_rv_emit_store_slot(low, sr, off_d)
            end
        end
        return 0
    end
    if op == OP_ADD or op == OP_SUB or op == OP_MUL or op == OP_DIV or op == OP_MOD or op == OP_AND or op == OP_OR or op == OP_XOR or op == OP_SHL or op == OP_SHR
        if inst.operands.len() >= 2 and inst.result != 0
            if op == OP_DIV or op == OP_MOD
                ssa_rv_load_val_to_reg(low, inst.operands[0], 10)
                ssa_rv_load_val_to_reg(low, inst.operands[1], 11)
                if op == OP_DIV
                    // bne a1, x0, +12; li a0, 0; jal x0, +8; div a0, a0, a1
                    ssa_lowerer_emit_u32(low, ssa_rv_b_word(1, 11, 0, 12))
                    ssa_rv_i(low, 19, 10, 0, 0, 0)
                    ssa_lowerer_emit_u32(low, ssa_rv_j_word(0, 8))
                    ssa_rv_r(low, 51, 10, 4, 10, 11, 1)  // div a0, a0, a1
                else
                    // bne a1, x0, +12; li a0, 0; jal x0, +8; rem a0, a0, a1
                    ssa_lowerer_emit_u32(low, ssa_rv_b_word(1, 11, 0, 12))
                    ssa_rv_i(low, 19, 10, 0, 0, 0)
                    ssa_lowerer_emit_u32(low, ssa_rv_j_word(0, 8))
                    ssa_rv_r(low, 51, 10, 6, 10, 11, 1)  // rem a0, a0, a1
                end
                ssa_rv_store_reg_to_slot(low, 10, inst.result.id)
            else
                // Direct 3-address RV64IM ALU using linear-scan physical registers (1 instruction = 4B!)
                ra = ssa_rv_resolve_val_reg(low, inst.operands[0], 10)
                rb = ssa_rv_resolve_val_reg(low, inst.operands[1], 11)
                dst_p = ssa_rv_find_phys_reg(low, inst.result.id)
                rd = dst_p
                if rd < 0 rd = 10 end
                if op == OP_ADD
                    ssa_rv_r(low, 51, rd, 0, ra, rb, 0)  // add rd, ra, rb
                elif op == OP_SUB
                    ssa_rv_r(low, 51, rd, 0, ra, rb, 32) // sub rd, ra, rb
                elif op == OP_MUL
                    ssa_rv_r(low, 51, rd, 0, ra, rb, 1)  // mul rd, ra, rb
                elif op == OP_AND
                    ssa_rv_r(low, 51, rd, 7, ra, rb, 0)  // and
                elif op == OP_OR
                    ssa_rv_r(low, 51, rd, 6, ra, rb, 0)  // or
                elif op == OP_XOR
                    ssa_rv_r(low, 51, rd, 4, ra, rb, 0)  // xor
                elif op == OP_SHL
                    ssa_rv_r(low, 51, rd, 1, ra, rb, 0)  // sll
                elif op == OP_SHR
                    ssa_rv_r(low, 51, rd, 5, ra, rb, 32) // sra
                end
                if dst_p < 0
                    ssa_rv_store_reg_to_slot(low, 10, inst.result.id)
                end
            end
        end
        return 0
    end
    if op == OP_NEG
        if inst.operands.len() >= 1 and inst.result != 0
            ra = ssa_rv_resolve_val_reg(low, inst.operands[0], 10)
            dst_p = ssa_rv_find_phys_reg(low, inst.result.id)
            rd = dst_p
            if rd < 0 rd = 10 end
            ssa_rv_r(low, 51, rd, 0, 0, ra, 32) // sub rd, x0, ra
            if dst_p < 0
                ssa_rv_store_reg_to_slot(low, 10, inst.result.id)
            end
        end
        return 0
    end
    if op == OP_CMP
        if inst.operands.len() >= 2 and inst.result != 0
            ra = ssa_rv_resolve_val_reg(low, inst.operands[0], 10)
            rb = ssa_rv_resolve_val_reg(low, inst.operands[1], 11)
            dst_p = ssa_rv_find_phys_reg(low, inst.result.id)
            rd = dst_p
            if rd < 0 rd = 10 end
            pred = inst.extra_int
            if pred == CMP_EQ
                ssa_rv_r(low, 51, rd, 0, ra, rb, 32) // sub rd, ra, rb
                ssa_rv_i(low, 19, rd, 3, rd, 1)      // sltiu rd, rd, 1 (seqz)
            elif pred == CMP_NE
                ssa_rv_r(low, 51, rd, 0, ra, rb, 32) // sub rd, ra, rb
                ssa_rv_r(low, 51, rd, 3, 0, rd, 0)   // sltu rd, x0, rd (snez)
            elif pred == CMP_SLT
                ssa_rv_r(low, 51, rd, 2, ra, rb, 0)  // slt rd, ra, rb
            elif pred == CMP_SLE
                ssa_rv_r(low, 51, rd, 2, rb, ra, 0)  // slt rd, rb, ra (rb < ra)
                ssa_rv_i(low, 19, rd, 4, rd, 1)      // xori rd, rd, 1
            elif pred == CMP_SGT
                ssa_rv_r(low, 51, rd, 2, rb, ra, 0)  // slt rd, rb, ra
            else
                ssa_rv_r(low, 51, rd, 2, ra, rb, 0)  // slt rd, ra, rb
                ssa_rv_i(low, 19, rd, 4, rd, 1)      // xori rd, rd, 1
            end
            if dst_p < 0
                ssa_rv_store_reg_to_slot(low, 10, inst.result.id)
            end
        end
        return 0
    end
    if op == OP_JMP
        p_j = buf_len(low.low_code)
        ssa_lowerer_emit_u32(low, ssa_rv_j_word(0, 0)) // jal x0, 0 placeholder
        jp = SsaJumpPatch()
        jp.sjp_offset = p_j
        jp.sjp_target = inst.extra_str
        jp.sjp_kind = 0
        push(low.low_patches, jp)
        return 0
    end
    if op == OP_BR
        if inst.operands.len() >= 1
            rc = ssa_rv_resolve_val_reg(low, inst.operands[0], 10)
            target_then = inst.extra_str
            target_else = ""
            if inst.extra_list.len() > 0
                target_then = inst.extra_list[0]
                if inst.extra_list.len() > 1
                    target_else = inst.extra_list[1]
                end
            end
            // beq rc, x0, +8; jal x0, target_then; jal x0, target_else (full ±1MB JAL range!)
            ssa_lowerer_emit_u32(low, ssa_rv_b_word(0, rc, 0, 8))
            p_t = buf_len(low.low_code)
            ssa_lowerer_emit_u32(low, ssa_rv_j_word(0, 0))
            jp_t = SsaJumpPatch()
            jp_t.sjp_offset = p_t
            jp_t.sjp_target = target_then
            jp_t.sjp_kind = 0
            push(low.low_patches, jp_t)
            if len(target_else) > 0
                p_e = buf_len(low.low_code)
                ssa_lowerer_emit_u32(low, ssa_rv_j_word(0, 0))
                jp_e = SsaJumpPatch()
                jp_e.sjp_offset = p_e
                jp_e.sjp_target = target_else
                jp_e.sjp_kind = 0
                push(low.low_patches, jp_e)
            end
        end
        return 0
    end
    if op == OP_CALL
        // LP64 argument marshaling: up to 16 args (a0..a7 + 16B-aligned stack args [sp+0], [sp+8], ...)
        nargs = inst.operands.len()
        if nargs > 16 nargs = 16 end
        n_stack_r = 0
        stack_pad_r = 0
        if nargs > 8
            n_stack_r = nargs - 8
            stack_pad_r = ((n_stack_r + 1) / 2) * 16
            ssa_rv_i(low, 19, 2, 0, 2, 0 - stack_pad_r) // addi sp, sp, -stack_pad_r
            sj_r = 0
            while sj_r < n_stack_r
                sr_r = ssa_rv_resolve_val_reg(low, inst.operands[8 + sj_r], 10)
                ssa_rv_s(low, 35, 3, 2, sr_r, sj_r * 8) // sd sr_r, (sj_r*8)(sp)
                sj_r = sj_r + 1
            end
        end
        n_reg_r = nargs
        if n_reg_r > 8 n_reg_r = 8 end
        ai = 0
        while ai < n_reg_r
            // Safe non-ABI pool {t3..t6, s1..s11} is completely disjoint from a0..a7!
            ssa_rv_load_val_to_reg(low, inst.operands[ai], 10 + ai)
            ai = ai + 1
        end
        p_jal = buf_len(low.low_code)
        ssa_lowerer_emit_u32(low, ssa_rv_j_word(1, 0)) // jal ra, 0 placeholder
        jp_c = SsaJumpPatch()
        jp_c.sjp_offset = p_jal
        jp_c.sjp_target = inst.extra_str
        jp_c.sjp_kind = 10
        push(low.low_call_patches, jp_c)
        if stack_pad_r > 0
            ssa_rv_i(low, 19, 2, 0, 2, stack_pad_r) // addi sp, sp, stack_pad_r
        end
        if inst.result != 0
            ssa_rv_store_reg_to_slot(low, 10, inst.result.id)
        end
        return 0
    end
    if op == OP_RET
        if inst.operands.len() >= 1
            ssa_rv_load_val_to_a0(low, inst.operands[0])
        else
            ssa_rv_i(low, 19, 10, 0, 0, 0)
        end
        ssa_rv_epilogue(low)
        return 0
    end
    return 0

// ── 4d. Native WASM MVP Bytecode SSA Lowering (Single-Block Pure Functions) ──

fn ssa_wasm_emit_sleb64 low val
    v = val
    more = 1
    while more == 1
        b = v & 127
        v = v >> 7
        if (v == 0 and (b & 64) == 0) or (v == (0 - 1) and (b & 64) != 0)
            more = 0
            ssa_lowerer_emit_byte(low, b)
        else
            ssa_lowerer_emit_byte(low, b | 128)
        end
    end
    return 0

fn ssa_wasm_emit_uleb low val
    v = val
    while 1 == 1
        b = v & 127
        v = v >> 7
        if v != 0
            ssa_lowerer_emit_byte(low, b | 128)
        else
            ssa_lowerer_emit_byte(low, b)
            break
        end
    end
    return 0

fn ssa_wasm_slot_idx low name
    if low.low_slot_map != 0 and has_key(low.low_slot_map, name) == 1
        return low.low_slot_map[name]
    end
    idx = low.low_slots.len()
    s = SsaSlot()
    s.slot_name = name
    s.slot_offset = idx
    s.slot_reg = 0 - 1
    push(low.low_slots, s)
    if low.low_slot_map != 0
        low.low_slot_map[name] = idx
    end
    return idx

fn ssa_wasm_emit_val low val
    if val == 0
        ssa_lowerer_emit_byte(low, 66) // i64.const 0
        ssa_lowerer_emit_byte(low, 0)
        return 0
    end
    if val.kind == VAL_KIND_CONST or val.val_kind == VAL_KIND_CONST
        ssa_lowerer_emit_byte(low, 66) // i64.const
        ssa_wasm_emit_sleb64(low, val.const_val)
        return 0
    end
    lidx = ssa_wasm_slot_idx(low, val.id)
    ssa_lowerer_emit_byte(low, 32) // local.get
    ssa_wasm_emit_uleb(low, lidx)
    return 0

// ── 5. Backpatching & Module Lowering ─────────────────────────────────────────

fn ssa_lowerer_resolve_function_branches low
    // WHY: Resolves intra-function basic block branches for x86_64, ARM64, and RISC-V 64.
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
            end
            bi = bi + 1
        end
        if tgt_offset >= 0
            if low.low_target_arch == TARGET_ID_ARM64()
                rel_w = (tgt_offset - patch.sjp_offset) / 4
                if patch.sjp_kind == 1
                    cbnz_reg = mem_byte_read(buf_ptr(low.low_code), patch.sjp_offset) & 31
                    ssa_lowerer_patch_u32(low, patch.sjp_offset, 3036676096 | ((rel_w & 524287) << 5) | cbnz_reg) // cbnz Xr, rel19
                else
                    ssa_lowerer_patch_u32(low, patch.sjp_offset, 335544320 | (rel_w & 67108863)) // b rel26
                end
            elif low.low_target_arch == TARGET_ID_RISCV64()
                ssa_lowerer_patch_u32(low, patch.sjp_offset, ssa_rv_j_word(0, tgt_offset - patch.sjp_offset))
            else
                disp = tgt_offset - (patch.sjp_offset + 4)
                ssa_lowerer_patch_u32(low, patch.sjp_offset, disp)
            end
        end
        pi = pi + 1
    return 0

fn ssa_lowerer_resolve_jumps low
    // WHY: Builds a 4096-bucket hash index over emitted functions and resolves inter-function OP_CALL patches in O(1).
    ssa_lowerer_resolve_function_branches(low)

    buckets = list()
    bi = 0
    while bi < 4096
        push(buckets, 0)
        bi = bi + 1
    end

    fi = 0
    fcount = low.low_fn_names.len()
    while fi < fcount
        fname = low.low_fn_names[fi]
        h = ssa_hash_str_4096(fname)
        ent = buckets[h]
        if ent == 0
            ent = list()
            list_set(buckets, h, ent)
        end
        push(ent, fi)
        fi = fi + 1
    end

    pi = 0
    pcount = low.low_call_patches.len()
    while pi < pcount
        patch = low.low_call_patches[pi]
        tgt_offset = 0 - 1
        h = ssa_hash_str_4096(patch.sjp_target)
        cand = buckets[h]
        if cand != 0
            ci = 0
            while ci < cand.len()
                fidx = cand[ci]
                if low.low_fn_names[fidx] == patch.sjp_target
                    tgt_offset = low.low_fn_offsets[fidx]
                    break
                end
                ci = ci + 1
            end
        end
        if tgt_offset >= 0
            if low.low_target_arch == TARGET_ID_ARM64()
                rel_w = (tgt_offset - patch.sjp_offset) / 4
                ssa_lowerer_patch_u32(low, patch.sjp_offset, 2483027968 | (rel_w & 67108863)) // bl rel26
            elif low.low_target_arch == TARGET_ID_RISCV64()
                ssa_lowerer_patch_u32(low, patch.sjp_offset, ssa_rv_j_word(1, tgt_offset - patch.sjp_offset)) // jal ra, rel20
            elif low.low_target_arch == TARGET_ID_WASM()
                // WHY: WASM calls use W3C function-table indices patched in wasm_synth_compile_program_ssa.
                _wasm_defer_patch = 0
            else
                disp = tgt_offset - (patch.sjp_offset + 4)
                ssa_lowerer_patch_u32(low, patch.sjp_offset, disp)
            end
        end
        pi = pi + 1
    end
    return 0

fn ssa_lower_function_ra low fn_obj mod_fn_set ra_res
    // WHY: Lowers an entire IRFunction and its basic blocks into target-native machine code
    // (AMD64 / AArch64 / RISC-V 64 / WebAssembly MVP) using LinearScan physical registers.
    low.low_slots = list()
    low.low_slot_map = dict()
    low.low_reg_map = 0
    low.low_used_callee = list()
    low.low_frame_patch = 0 - 1
    low.low_cur_offset = 8
    low.low_blocks = list()
    low.low_patches = list()

    fn_start_off = buf_len(low.low_code)
    push(low.low_fn_names, fn_obj.name)
    push(low.low_fn_offsets, fn_start_off)

    alloca_count = fn_obj.allocas.len()
    inst_count = ir_function_count_insts(fn_obj)
    param_count = fn_obj.params.len()
    frame_size = (alloca_count + inst_count + param_count + 8) * 8
    if (frame_size % 16) != 0
        frame_size = frame_size + (16 - (frame_size % 16))
    end
    low.low_stack_frame = frame_size

    // ── ARM64 (AAPCS64) Native SSA CFG Lowering (up to 16 params/args!) ─────
    if low.low_target_arch == TARGET_ID_ARM64()
        fn_elig_a = fn_obj.is_ssa_native_ready
        if param_count > 16 or frame_size > 60000 or fn_obj.return_type == "str" or fn_obj.return_type == "string" or fn_obj.return_type == "f64" or fn_obj.return_type == "float"
            fn_elig_a = 0
        end
        if fn_elig_a == 1
            ebi = 0
            while ebi < fn_obj.blocks.len() and fn_elig_a == 1
                ebb = fn_obj.blocks[ebi]
                eii = 0
                while eii < ebb.instructions.len()
                    ei = ebb.instructions[eii]
                    if ei.is_dead == 0
                        eop = ei.op
                        if eop != OP_NOP and eop != OP_ALLOCA and eop != OP_STORE and eop != OP_LOAD and eop != OP_ADD and eop != OP_SUB and eop != OP_MUL and eop != OP_DIV and eop != OP_MOD and eop != OP_AND and eop != OP_OR and eop != OP_XOR and eop != OP_SHL and eop != OP_SHR and eop != OP_NEG and eop != OP_CMP and eop != OP_JMP and eop != OP_BR and eop != OP_RET and eop != OP_CALL
                            fn_elig_a = 0
                            break
                        end
                        if eop == OP_CALL
                            if ei.operands.len() > 16 or mod_fn_set == 0 or has_key(mod_fn_set, ei.extra_str) == 0 or mod_fn_set[ei.extra_str] != 1
                                fn_elig_a = 0
                                break
                            end
                            if ei.result != 0 and (ei.result.vtype == "str" or ei.result.vtype == "f64")
                                fn_elig_a = 0
                                break
                            end
                        end
                    end
                    eii = eii + 1
                end
                ebi = ebi + 1
            end
        end
        if fn_elig_a == 0 and low.low_only_eligible == 1
            push(low.low_fn_sizes, 0)
            push(low.low_fn_eligible, 0)
            push(low.low_fn_ret_types, "int")
            push(low.low_fn_locals, 0)
            return 0
        end
        // Ingest Linear-Scan physical registers for ARM64: caller {x12..x15}, callee {x19..x28}
        if ra_res != 0 and ra_res.intervals != 0
            rmap_a = dict()
            used_ca = list()
            seen_ca = dict()
            rii_a = 0
            while rii_a < ra_res.intervals.len()
                riv_a = ra_res.intervals[rii_a]
                if riv_a.is_spilled == 0 and riv_a.assigned_reg >= 0
                    rr_a = riv_a.assigned_reg
                    if (rr_a >= 12 and rr_a <= 15) or (rr_a >= 19 and rr_a <= 28)
                        rmap_a[riv_a.vreg_name] = rr_a + 1
                        if rr_a >= 19 and rr_a <= 28
                            rkey_a = str(rr_a)
                            if has_key(seen_ca, rkey_a) == 0
                                seen_ca[rkey_a] = 1
                                push(used_ca, rr_a)
                            end
                        end
                    end
                end
                rii_a = rii_a + 1
            end
            low.low_reg_map = rmap_a
            low.low_used_callee = used_ca
        end
        n_callee_a = low.low_used_callee.len()
        low.low_cur_offset = (n_callee_a * 8) + 8

        // Prologue: stp x29, x30, [sp, #-16]!; mov x29, sp; movz x9, #exact_frame (patched); sub sp, sp, x9, uxtx
        ssa_lowerer_emit_u32(low, 2847898621) // stp x29, x30, [sp, #-16]!
        ssa_lowerer_emit_u32(low, 2432697341) // mov x29, sp
        low.low_frame_patch = buf_len(low.low_code)
        ssa_lowerer_emit_u32(low, 3531603977) // movz x9, #0 (backpatched to exact spilled frame!)
        ssa_lowerer_emit_u32(low, 3408487423) // sub sp, sp, x9, uxtx (0xCB2963FF)
        ci_a = 0
        while ci_a < n_callee_a
            ssa_a64_emit_store_slot(low, low.low_used_callee[ci_a], (ci_a + 1) * 8)
            ci_a = ci_a + 1
        end
        pi_a = 0
        while pi_a < param_count and pi_a < 16
            if pi_a < 8
                ssa_a64_store_reg_to_slot(low, pi_a, fn_obj.params[pi_a].id)
            else
                // AAPCS64 stack param pi_a >= 8 at [x29 + 16 + (pi_a - 8) * 8]
                scaled_pa = (16 + ((pi_a - 8) * 8)) / 8
                ssa_lowerer_emit_u32(low, 4181721088 | ((scaled_pa & 4095) << 10) | (29 << 5) | 11) // ldr x11, [x29, #off]
                ssa_a64_store_reg_to_slot(low, 11, fn_obj.params[pi_a].id)
            end
            pi_a = pi_a + 1
        end
        bi_a = 0
        while bi_a < fn_obj.blocks.len()
            bb_a = fn_obj.blocks[bi_a]
            bo_a = SsaBlockOffset()
            bo_a.sbo_label = bb_a.label
            bo_a.sbo_offset = buf_len(low.low_code)
            push(low.low_blocks, bo_a)
            ii_a = 0
            while ii_a < bb_a.instructions.len()
                ssa_lower_instruction_arm64(low, bb_a.instructions[ii_a])
                ii_a = ii_a + 1
            end
            bi_a = bi_a + 1
        end
        // Backpatch exact 16-byte aligned ARM64 frame size strictly to used callee saves + spilled slots!
        if low.low_frame_patch >= 0
            used_a = low.low_cur_offset - 8
            if (used_a % 16) != 0
                used_a = used_a + (16 - (used_a % 16))
            end
            ssa_lowerer_patch_u32(low, low.low_frame_patch, 3531603968 | ((used_a & 65535) << 5) | 9)
        end
        ssa_lowerer_resolve_function_branches(low)
        low.low_patches = list()
        push(low.low_fn_sizes, buf_len(low.low_code) - fn_start_off)
        push(low.low_fn_eligible, fn_elig_a)
        push(low.low_fn_ret_types, "int")
        push(low.low_fn_locals, 0)
        return 0
    end

    // ── RISC-V 64 (LP64 / RV64IM) Native SSA CFG Lowering (up to 16 params/args!) ─
    if low.low_target_arch == TARGET_ID_RISCV64()
        fn_elig_r = fn_obj.is_ssa_native_ready
        if param_count > 16 or frame_size > 60000 or fn_obj.return_type == "str" or fn_obj.return_type == "string" or fn_obj.return_type == "f64" or fn_obj.return_type == "float"
            fn_elig_r = 0
        end
        if fn_elig_r == 1
            ebi = 0
            while ebi < fn_obj.blocks.len() and fn_elig_r == 1
                ebb = fn_obj.blocks[ebi]
                eii = 0
                while eii < ebb.instructions.len()
                    ei = ebb.instructions[eii]
                    if ei.is_dead == 0
                        eop = ei.op
                        if eop != OP_NOP and eop != OP_ALLOCA and eop != OP_STORE and eop != OP_LOAD and eop != OP_ADD and eop != OP_SUB and eop != OP_MUL and eop != OP_DIV and eop != OP_MOD and eop != OP_AND and eop != OP_OR and eop != OP_XOR and eop != OP_SHL and eop != OP_SHR and eop != OP_NEG and eop != OP_CMP and eop != OP_JMP and eop != OP_BR and eop != OP_RET and eop != OP_CALL
                            fn_elig_r = 0
                            break
                        end
                        if eop == OP_CALL
                            if ei.operands.len() > 16 or mod_fn_set == 0 or has_key(mod_fn_set, ei.extra_str) == 0 or mod_fn_set[ei.extra_str] != 1
                                fn_elig_r = 0
                                break
                            end
                            if ei.result != 0 and (ei.result.vtype == "str" or ei.result.vtype == "f64")
                                fn_elig_r = 0
                                break
                            end
                        end
                    end
                    eii = eii + 1
                end
                ebi = ebi + 1
            end
        end
        if fn_elig_r == 0 and low.low_only_eligible == 1
            push(low.low_fn_sizes, 0)
            push(low.low_fn_eligible, 0)
            push(low.low_fn_ret_types, "int")
            push(low.low_fn_locals, 0)
            return 0
        end
        // Ingest Linear-Scan physical registers for RISC-V 64: caller {t3..t6 = 28..31}, callee {s1=9, s2..s11=18..27}
        if ra_res != 0 and ra_res.intervals != 0
            rmap_r = dict()
            used_cr = list()
            seen_cr = dict()
            rii_r = 0
            while rii_r < ra_res.intervals.len()
                riv_r = ra_res.intervals[rii_r]
                if riv_r.is_spilled == 0 and riv_r.assigned_reg >= 0
                    rr_r = riv_r.assigned_reg
                    if (rr_r >= 28 and rr_r <= 31) or rr_r == 9 or (rr_r >= 18 and rr_r <= 27)
                        rmap_r[riv_r.vreg_name] = rr_r + 1
                        if rr_r == 9 or (rr_r >= 18 and rr_r <= 27)
                            rkey_r = str(rr_r)
                            if has_key(seen_cr, rkey_r) == 0
                                seen_cr[rkey_r] = 1
                                push(used_cr, rr_r)
                            end
                        end
                    end
                end
                rii_r = rii_r + 1
            end
            low.low_reg_map = rmap_r
            low.low_used_callee = used_cr
        end
        n_callee_r = low.low_used_callee.len()
        low.low_cur_offset = (n_callee_r * 8) + 8

        // Prologue: addi sp, sp, -16; sd ra, 8(sp); sd s0, 0(sp); addi s0, sp, 16; lui t0, hi; addi t0, t0, lo; sub sp, sp, t0
        ssa_rv_i(low, 19, 2, 0, 2, 0 - 16)
        ssa_rv_s(low, 35, 3, 2, 1, 8)
        ssa_rv_s(low, 35, 3, 2, 8, 0)
        ssa_rv_i(low, 19, 8, 0, 2, 16)
        low.low_frame_patch = buf_len(low.low_code)
        ssa_lowerer_emit_u32(low, (5 << 7) | 55) // lui t0, 0 (backpatched to exact spilled frame!)
        ssa_rv_i(low, 19, 5, 0, 5, 0)            // addi t0, t0, 0
        ssa_rv_r(low, 51, 2, 0, 2, 5, 32)        // sub sp, sp, t0
        ci_r = 0
        while ci_r < n_callee_r
            ssa_rv_emit_store_slot(low, low.low_used_callee[ci_r], (ci_r + 1) * 8)
            ci_r = ci_r + 1
        end
        pi_r = 0
        while pi_r < param_count and pi_r < 16
            if pi_r < 8
                ssa_rv_store_reg_to_slot(low, 10 + pi_r, fn_obj.params[pi_r].id)
            else
                // RV64 LP64 stack param pi_r >= 8 at [s0 + (pi_r - 8) * 8] (note: use t2=x7 since store_reg clobbers t0/t1!)
                ssa_rv_i(low, 3, 7, 3, 8, (pi_r - 8) * 8) // ld t2, ((pi_r-8)*8)(s0)
                ssa_rv_store_reg_to_slot(low, 7, fn_obj.params[pi_r].id)
            end
            pi_r = pi_r + 1
        end
        bi_r = 0
        while bi_r < fn_obj.blocks.len()
            bb_r = fn_obj.blocks[bi_r]
            bo_r = SsaBlockOffset()
            bo_r.sbo_label = bb_r.label
            bo_r.sbo_offset = buf_len(low.low_code)
            push(low.low_blocks, bo_r)
            ii_r = 0
            while ii_r < bb_r.instructions.len()
                ssa_lower_instruction_riscv64(low, bb_r.instructions[ii_r])
                ii_r = ii_r + 1
            end
            bi_r = bi_r + 1
        end
        // Backpatch exact 16-byte aligned RV64 frame size strictly to used callee saves + spilled slots!
        if low.low_frame_patch >= 0
            used_r = low.low_cur_offset - 8
            if (used_r % 16) != 0
                used_r = used_r + (16 - (used_r % 16))
            end
            lo_r = used_r & 4095
            if lo_r >= 2048 lo_r = lo_r - 4096 end
            hi_r = ((used_r - lo_r) >> 12) & 1048575
            ssa_lowerer_patch_u32(low, low.low_frame_patch, (hi_r << 12) | (5 << 7) | 55)
            ssa_lowerer_patch_u32(low, low.low_frame_patch + 4, ((lo_r & 4095) << 20) | (5 << 15) | (5 << 7) | 19)
        end
        ssa_lowerer_resolve_function_branches(low)
        low.low_patches = list()
        push(low.low_fn_sizes, buf_len(low.low_code) - fn_start_off)
        push(low.low_fn_eligible, fn_elig_r)
        push(low.low_fn_ret_types, "int")
        push(low.low_fn_locals, 0)
        return 0
    end

    // ── WebAssembly MVP Native Multi-Block CFG SSA Lowering ──────────────────
    if low.low_target_arch == TARGET_ID_WASM()
        fn_elig_w = fn_obj.is_ssa_native_ready
        n_blks = fn_obj.blocks.len()
        if n_blks <= 0
            fn_elig_w = 0
        end
        // Pre-validate all instructions across all basic blocks before emitting
        if fn_elig_w == 1
            ebi_w = 0
            while ebi_w < n_blks and fn_elig_w == 1
                ebb_w = fn_obj.blocks[ebi_w]
                eii_w = 0
                while eii_w < ebb_w.instructions.len()
                    ei_w = ebb_w.instructions[eii_w]
                    if ei_w.is_dead == 0
                        wop_v = ei_w.op
                        if wop_v != OP_NOP and wop_v != OP_ALLOCA and wop_v != OP_STORE and wop_v != OP_LOAD and wop_v != OP_ADD and wop_v != OP_SUB and wop_v != OP_MUL and wop_v != OP_DIV and wop_v != OP_MOD and wop_v != OP_AND and wop_v != OP_OR and wop_v != OP_XOR and wop_v != OP_SHL and wop_v != OP_SHR and wop_v != OP_NEG and wop_v != OP_CMP and wop_v != OP_JMP and wop_v != OP_BR and wop_v != OP_RET and wop_v != OP_CALL
                            fn_elig_w = 0
                            break
                        end
                        if wop_v == OP_CALL
                            if mod_fn_set == 0 or has_key(mod_fn_set, ei_w.extra_str) == 0
                                fn_elig_w = 0
                                break
                            end
                        end
                    end
                    eii_w = eii_w + 1
                end
                ebi_w = ebi_w + 1
            end
        end

        // Parameters MUST occupy WASM local indices 0 .. param_count-1
        pi_w = 0
        while pi_w < param_count
            ssa_wasm_slot_idx(low, fn_obj.params[pi_w].id)
            pi_w = pi_w + 1
        end

        if fn_elig_w == 1
            // Build block-label -> integer index map
            blk_idx_map = dict()
            bm_i = 0
            while bm_i < n_blks
                blk_idx_map[fn_obj.blocks[bm_i].label] = bm_i
                bm_i = bm_i + 1
            end

            pc_slot = 0 - 1
            if n_blks > 1
                // WHY: Structured W3C WebAssembly MVP state-machine CFG dispatcher:
                //   pc = 0; loop { block b_{N-1} { ... block b_0 { local.get $pc; i32.wrap_i64; br_table 0..N-1 0 } <b0> } ... <b_{N-1}> }
                pc_slot = ssa_wasm_slot_idx(low, "__wasm_cfg_pc")
                ssa_lowerer_emit_byte(low, 66) // i64.const 0
                ssa_lowerer_emit_byte(low, 0)
                ssa_lowerer_emit_byte(low, 33) // local.set $pc
                ssa_wasm_emit_uleb(low, pc_slot)
                ssa_lowerer_emit_byte(low, 3)  // loop (void)
                ssa_lowerer_emit_byte(low, 64)
                nb_k = 0
                while nb_k < n_blks
                    ssa_lowerer_emit_byte(low, 2)  // block (void)
                    ssa_lowerer_emit_byte(low, 64)
                    nb_k = nb_k + 1
                end
                ssa_lowerer_emit_byte(low, 32) // local.get $pc
                ssa_wasm_emit_uleb(low, pc_slot)
                ssa_lowerer_emit_byte(low, 167) // i32.wrap_i64 (0xA7)
                ssa_lowerer_emit_byte(low, 14)  // br_table (0x0E)
                ssa_wasm_emit_uleb(low, n_blks)
                nb_k = 0
                while nb_k < n_blks
                    ssa_wasm_emit_uleb(low, nb_k)
                    nb_k = nb_k + 1
                end
                ssa_wasm_emit_uleb(low, 0) // default label = 0
            end

            bi_w = 0
            while bi_w < n_blks
                if n_blks > 1
                    ssa_lowerer_emit_byte(low, 11) // end block b_{bi_w} -> lands here when $pc == bi_w
                end
                bb_w = fn_obj.blocks[bi_w]
                loop_br_depth = (n_blks - 1) - bi_w
                ii_w = 0
                while ii_w < bb_w.instructions.len()
                    iw = bb_w.instructions[ii_w]
                    if iw.is_dead == 0
                        low.low_total_insts = low.low_total_insts + 1
                        wop = iw.op
                        if wop == OP_ALLOCA and iw.result != 0
                            ssa_wasm_slot_idx(low, iw.result.id)
                        elif wop == OP_STORE and iw.operands.len() >= 2
                            ssa_wasm_emit_val(low, iw.operands[0])
                            ssa_lowerer_emit_byte(low, 33) // local.set
                            ssa_wasm_emit_uleb(low, ssa_wasm_slot_idx(low, iw.operands[1].id))
                        elif wop == OP_LOAD and iw.operands.len() >= 1 and iw.result != 0
                            ssa_wasm_emit_val(low, iw.operands[0])
                            ssa_lowerer_emit_byte(low, 33)
                            ssa_wasm_emit_uleb(low, ssa_wasm_slot_idx(low, iw.result.id))
                        elif (wop == OP_ADD or wop == OP_SUB or wop == OP_MUL or wop == OP_DIV or wop == OP_MOD or wop == OP_AND or wop == OP_OR or wop == OP_XOR or wop == OP_SHL or wop == OP_SHR) and iw.operands.len() >= 2 and iw.result != 0
                            ssa_wasm_emit_val(low, iw.operands[0])
                            ssa_wasm_emit_val(low, iw.operands[1])
                            if wop == OP_ADD ssa_lowerer_emit_byte(low, 124)     // i64.add (0x7C)
                            elif wop == OP_SUB ssa_lowerer_emit_byte(low, 125)   // i64.sub (0x7D)
                            elif wop == OP_MUL ssa_lowerer_emit_byte(low, 126)   // i64.mul (0x7E)
                            elif wop == OP_DIV ssa_lowerer_emit_byte(low, 127)   // i64.div_s (0x7F)
                            elif wop == OP_MOD ssa_lowerer_emit_byte(low, 129)   // i64.rem_s (0x81)
                            elif wop == OP_AND ssa_lowerer_emit_byte(low, 131)   // i64.and (0x83)
                            elif wop == OP_OR ssa_lowerer_emit_byte(low, 132)    // i64.or (0x84)
                            elif wop == OP_XOR ssa_lowerer_emit_byte(low, 133)   // i64.xor (0x85)
                            elif wop == OP_SHL ssa_lowerer_emit_byte(low, 134)   // i64.shl (0x86)
                            else ssa_lowerer_emit_byte(low, 135) end             // i64.shr_s (0x87)
                            ssa_lowerer_emit_byte(low, 33)
                            ssa_wasm_emit_uleb(low, ssa_wasm_slot_idx(low, iw.result.id))
                        elif wop == OP_CMP and iw.operands.len() >= 2 and iw.result != 0
                            ssa_wasm_emit_val(low, iw.operands[0])
                            ssa_wasm_emit_val(low, iw.operands[1])
                            wp = iw.extra_int
                            if wp == CMP_EQ ssa_lowerer_emit_byte(low, 81)       // i64.eq (0x51)
                            elif wp == CMP_NE ssa_lowerer_emit_byte(low, 82)     // i64.ne (0x52)
                            elif wp == CMP_SLT ssa_lowerer_emit_byte(low, 83)    // i64.lt_s (0x53)
                            elif wp == CMP_SGT ssa_lowerer_emit_byte(low, 85)    // i64.gt_s (0x55)
                            elif wp == CMP_SLE ssa_lowerer_emit_byte(low, 87)    // i64.le_s (0x57)
                            else ssa_lowerer_emit_byte(low, 89) end              // i64.ge_s (0x59)
                            ssa_lowerer_emit_byte(low, 173) // i64.extend_i32_u (0xAD)
                            ssa_lowerer_emit_byte(low, 33)
                            ssa_wasm_emit_uleb(low, ssa_wasm_slot_idx(low, iw.result.id))
                        elif wop == OP_NEG and iw.operands.len() >= 1 and iw.result != 0
                            ssa_lowerer_emit_byte(low, 66)
                            ssa_lowerer_emit_byte(low, 0)
                            ssa_wasm_emit_val(low, iw.operands[0])
                            ssa_lowerer_emit_byte(low, 125) // i64.sub
                            ssa_lowerer_emit_byte(low, 33)
                            ssa_wasm_emit_uleb(low, ssa_wasm_slot_idx(low, iw.result.id))
                        elif wop == OP_CALL
                            cai_w = 0
                            while cai_w < iw.operands.len()
                                ssa_wasm_emit_val(low, iw.operands[cai_w])
                                cai_w = cai_w + 1
                            end
                            ssa_lowerer_emit_byte(low, 16) // call (0x10)
                            p_wcall = buf_len(low.low_code)
                            // Fixed 5-byte padded ULEB128 placeholder (legal W3C §5.2.2) patched by wasm_synth
                            ssa_lowerer_emit_bytes(low, [128, 128, 128, 128, 0])
                            jp_wc = SsaJumpPatch()
                            jp_wc.sjp_offset = p_wcall
                            jp_wc.sjp_target = iw.extra_str
                            jp_wc.sjp_kind = 20
                            push(low.low_call_patches, jp_wc)
                            if iw.result != 0
                                ssa_lowerer_emit_byte(low, 33) // local.set
                                ssa_wasm_emit_uleb(low, ssa_wasm_slot_idx(low, iw.result.id))
                            else
                                ssa_lowerer_emit_byte(low, 26) // drop (0x1A)
                            end
                        elif wop == OP_JMP and n_blks > 1
                            tgt_bi = 0
                            if has_key(blk_idx_map, iw.extra_str) == 1
                                tgt_bi = blk_idx_map[iw.extra_str]
                            end
                            ssa_lowerer_emit_byte(low, 66) // i64.const tgt_bi
                            ssa_wasm_emit_sleb64(low, tgt_bi)
                            ssa_lowerer_emit_byte(low, 33) // local.set $pc
                            ssa_wasm_emit_uleb(low, pc_slot)
                            ssa_lowerer_emit_byte(low, 12) // br loop_br_depth
                            ssa_wasm_emit_uleb(low, loop_br_depth)
                        elif wop == OP_BR and iw.operands.len() >= 1 and n_blks > 1
                            t_lbl = iw.extra_str
                            f_lbl = ""
                            if iw.extra_list.len() > 0
                                t_lbl = iw.extra_list[0]
                                if iw.extra_list.len() > 1
                                    f_lbl = iw.extra_list[1]
                                end
                            end
                            t_bi = 0
                            f_bi = 0
                            if has_key(blk_idx_map, t_lbl) == 1 t_bi = blk_idx_map[t_lbl] end
                            if has_key(blk_idx_map, f_lbl) == 1 f_bi = blk_idx_map[f_lbl] end
                            ssa_wasm_emit_val(low, iw.operands[0])
                            ssa_lowerer_emit_byte(low, 66) // i64.const 0
                            ssa_lowerer_emit_byte(low, 0)
                            ssa_lowerer_emit_byte(low, 82) // i64.ne -> i32
                            ssa_lowerer_emit_byte(low, 4)  // if (result i64)
                            ssa_lowerer_emit_byte(low, 126)
                            ssa_lowerer_emit_byte(low, 66) // i64.const t_bi
                            ssa_wasm_emit_sleb64(low, t_bi)
                            ssa_lowerer_emit_byte(low, 5)  // else
                            ssa_lowerer_emit_byte(low, 66) // i64.const f_bi
                            ssa_wasm_emit_sleb64(low, f_bi)
                            ssa_lowerer_emit_byte(low, 11) // end if
                            ssa_lowerer_emit_byte(low, 33) // local.set $pc
                            ssa_wasm_emit_uleb(low, pc_slot)
                            ssa_lowerer_emit_byte(low, 12) // br loop_br_depth
                            ssa_wasm_emit_uleb(low, loop_br_depth)
                        elif wop == OP_RET
                            if iw.operands.len() >= 1
                                ssa_wasm_emit_val(low, iw.operands[0])
                            else
                                ssa_lowerer_emit_byte(low, 66)
                                ssa_lowerer_emit_byte(low, 0)
                            end
                            ssa_lowerer_emit_byte(low, 15) // return (0x0F)
                        end
                    end
                    ii_w = ii_w + 1
                end
                bi_w = bi_w + 1
            end

            if n_blks > 1
                ssa_lowerer_emit_byte(low, 11) // end loop
            end
            // Guaranteed fallback i64 value for W3C validator (Section 10 appends final 0x0B END!)
            ssa_lowerer_emit_byte(low, 66) // i64.const 0
            ssa_lowerer_emit_byte(low, 0)
        end
        push(low.low_fn_sizes, buf_len(low.low_code) - fn_start_off)
        push(low.low_fn_eligible, fn_elig_w)
        push(low.low_fn_ret_types, "int")
        push(low.low_fn_locals, low.low_slots.len())
        return 0
    end

    // ── AMD64 / x86_64 Native SSA CFG Lowering (up to 16 params/args!) ──────
    fn_elig = fn_obj.is_ssa_native_ready
    if param_count > 16 or low.low_target_arch != TARGET_ID_X86_64()
        fn_elig = 0
    end
    if fn_elig == 1
        ebi = 0
        while ebi < fn_obj.blocks.len() and fn_elig == 1
            ebb = fn_obj.blocks[ebi]
            eii = 0
            while eii < ebb.instructions.len()
                ei = ebb.instructions[eii]
                if ei.is_dead == 0
                    eop = ei.op
                    if eop != OP_NOP and eop != OP_ALLOCA and eop != OP_STORE and eop != OP_LOAD and eop != OP_ADD and eop != OP_ADD_DYN and eop != OP_SUB and eop != OP_MUL and eop != OP_DIV and eop != OP_MOD and eop != OP_AND and eop != OP_OR and eop != OP_XOR and eop != OP_SHL and eop != OP_SHR and eop != OP_NEG and eop != OP_CMP and eop != OP_CMP_DYN and eop != OP_JMP and eop != OP_BR and eop != OP_RET and eop != OP_CALL and eop != OP_FADD and eop != OP_FSUB and eop != OP_FMUL and eop != OP_FDIV and eop != OP_FCMP and eop != OP_I2F and eop != OP_FNEG and eop != OP_STR_LIT and eop != OP_STRUCT_NEW and eop != OP_FIELD_LOAD and eop != OP_FIELD_STORE
                        fn_elig = 0
                        break
                    end
                end
                eii = eii + 1
            end
            ebi = ebi + 1
        end
    end

    if fn_elig == 0 and low.low_only_eligible == 1
        push(low.low_fn_sizes, 0)
        push(low.low_fn_eligible, 0)
        push(low.low_fn_ret_types, "int")
        push(low.low_fn_locals, 0)
        return 0
    end

    // 1b. Ingest Linear-Scan physical register assignments for AMD64 (disjoint from scratch/SysV-arg regs!)
    if ra_res != 0 and ra_res.intervals != 0
        rmap = dict()
        used_c = list()
        seen_c = dict()
        rii = 0
        rcnt = ra_res.intervals.len()
        while rii < rcnt
            riv = ra_res.intervals[rii]
            if riv.is_spilled == 0 and riv.assigned_reg >= 0
                rr = riv.assigned_reg
                // Safe non-ABI pool: caller {r10=10, r11=11}, callee {rbx=3, r12=12, r13=13, r14=14, r15=15}
                if rr == 10 or rr == 11 or rr == 12 or rr == 13 or rr == 14 or rr == 15 or rr == 3
                    rmap[riv.vreg_name] = rr + 1
                    if rr == 12 or rr == 13 or rr == 14 or rr == 15 or rr == 3
                        rkey = str(rr)
                        if has_key(seen_c, rkey) == 0
                            seen_c[rkey] = 1
                            push(used_c, rr)
                        end
                    end
                end
            end
            rii = rii + 1
        end
        low.low_reg_map = rmap
        low.low_used_callee = used_c
    end
    n_callee_x = low.low_used_callee.len()
    low.low_cur_offset = (n_callee_x * 8) + 8

    // 2. Emit function prologue & bind incoming System V AMD64 ABI params (%rdi..%r9 + [rbp+16+...])
    ssa_lower_x86_prologue(low, frame_size)
    pi_arg = 0
    while pi_arg < param_count and pi_arg < 16
        pval = fn_obj.params[pi_arg]
        if pi_arg == 0
            ssa_lower_x86_store_reg_to_slot(low, 7, pval.id)
        elif pi_arg == 1
            ssa_lower_x86_store_reg_to_slot(low, 6, pval.id)
        elif pi_arg == 2
            ssa_lower_x86_store_reg_to_slot(low, 2, pval.id)
        elif pi_arg == 3
            ssa_lower_x86_store_reg_to_slot(low, 1, pval.id)
        elif pi_arg == 4
            ssa_lower_x86_store_reg_to_slot(low, 8, pval.id)
        elif pi_arg == 5
            ssa_lower_x86_store_reg_to_slot(low, 9, pval.id)
        else
            // mov rax, [rbp + 16 + (pi_arg - 6) * 8]
            s_disp = 16 + ((pi_arg - 6) * 8)
            if s_disp < 128
                ssa_lowerer_emit_bytes(low, [72, 139, 69, s_disp])
            else
                ssa_lowerer_emit_bytes(low, [72, 139, 133])
                ssa_lowerer_emit_u32(low, s_disp)
            end
            ssa_lower_x86_store_rax_to_slot(low, pval.id)
        end
        pi_arg = pi_arg + 1
    end

    // 3. Lower each basic block sequentially
    bi = 0
    while bi < fn_obj.blocks.len()
        bb = fn_obj.blocks[bi]
        // Record block label offset
        bo = SsaBlockOffset()
        bo.sbo_label = bb.label
        bo.sbo_offset = buf_len(low.low_code)
        push(low.low_blocks, bo)

        // Lower block instructions
        ii = 0
        while ii < bb.instructions.len()
            inst = bb.instructions[ii]
            ssa_lower_instruction_x86(low, inst)
            ii = ii + 1
        bi = bi + 1

    // 4. Backpatch prologue `sub rsp, imm32` strictly to actual spilled slots with 16-byte SysV ABI alignment!
    if low.low_frame_patch >= 0
        used_below_rbp = low.low_cur_offset - 8
        total_below_rbp = used_below_rbp
        if (total_below_rbp % 16) != 0
            total_below_rbp = total_below_rbp + (16 - (total_below_rbp % 16))
        end
        sub_amt = total_below_rbp - (n_callee_x * 8)
        if sub_amt < 0 sub_amt = 0 end
        ssa_lowerer_patch_u32(low, low.low_frame_patch, sub_amt)
    end

    ssa_lowerer_resolve_function_branches(low)
    low.low_patches = list()
    push(low.low_fn_sizes, buf_len(low.low_code) - fn_start_off)
    push(low.low_fn_eligible, fn_elig)
    rt_out = "int"
    if fn_obj.return_type == "f64" or fn_obj.return_type == "float"
        rt_out = "f64"
    elif fn_obj.return_type == "str" or fn_obj.return_type == "string"
        rt_out = "string"
    elif fn_obj.return_type != "" and fn_obj.return_type != "i64" and fn_obj.return_type != "int"
        rt_out = fn_obj.return_type
    end
    push(low.low_fn_ret_types, rt_out)
    push(low.low_fn_locals, 0)
    return 0

fn ssa_lower_function_ex low fn_obj mod_fn_set
    return ssa_lower_function_ra(low, fn_obj, mod_fn_set, 0)

fn ssa_lower_function low fn_obj
    return ssa_lower_function_ra(low, fn_obj, 0, 0)

fn ssa_lower_buf_to_list b
    out = list()
    if b == 0
        return out
    end
    n = buf_len(b)
    p = buf_ptr(b)
    i = 0
    while i < n
        push(out, mem_byte_read(p, i))
        i = i + 1
    end
    return out
end

fn ssa_lower_module_buf low ir_mod
    // WHY: Zero-bloat primary pipeline entry point returning compact ByteBuffers directly.
    res = SsaLowerResult()
    res.slr_code = list()
    res.slr_rodata = list()
    res.slr_code_buf = 0
    res.slr_rodata_buf = 0
    res.slr_fn_names = list()
    res.slr_fn_offsets = list()
    res.slr_fn_sizes = list()
    res.slr_fn_eligible = list()
    res.slr_fn_ret_types = list()
    res.slr_fn_locals = list()
    res.slr_str_relocs = list()
    res.slr_call_relocs = list()
    res.slr_fn_name_map = dict()
    res.slr_fn_str_start = list()
    res.slr_fn_str_end = list()
    res.slr_fn_call_start = list()
    res.slr_fn_call_end = list()
    res.slr_total_insts = 0
    res.slr_success = 0
    res.slr_error_msg = ""

    if ir_mod == 0
        res.slr_error_msg = "Null IRModule passed to ssa_lower_module"
        return res
    end

    mod_fn_set = dict()
    mfi = 0
    while mfi < ir_mod.functions.len()
        mod_fn_set[ir_mod.functions[mfi].name] = 1
        mfi = mfi + 1
    end

    fi = 0
    while fi < ir_mod.functions.len()
        f = ir_mod.functions[fi]
        sr_s = low.low_str_relocs.len()
        cr_s = low.low_call_patches.len()
        ssa_lower_function_ex(low, f, mod_fn_set)
        sr_e = low.low_str_relocs.len()
        cr_e = low.low_call_patches.len()
        push(res.slr_fn_str_start, sr_s)
        push(res.slr_fn_str_end, sr_e)
        push(res.slr_fn_call_start, cr_s)
        push(res.slr_fn_call_end, cr_e)
        if has_key(res.slr_fn_name_map, f.name) == 0
            res.slr_fn_name_map[f.name] = fi + 1
        end
        fi = fi + 1
    end

    // 4. Resolve all block-to-block jumps
    ssa_lowerer_resolve_jumps(low)

    res.slr_code_buf = low.low_code
    res.slr_rodata_buf = low.low_rodata
    res.slr_fn_names = low.low_fn_names
    res.slr_fn_offsets = low.low_fn_offsets
    res.slr_fn_sizes = low.low_fn_sizes
    res.slr_fn_eligible = low.low_fn_eligible
    res.slr_fn_ret_types = low.low_fn_ret_types
    res.slr_fn_locals = low.low_fn_locals
    res.slr_str_relocs = low.low_str_relocs
    res.slr_call_relocs = low.low_call_patches
    res.slr_total_insts = low.low_total_insts
    res.slr_success = 1
    return res
end

fn ssa_lower_module low ir_mod
    // WHY: Legacy compatibility entry point that also populates slr_code/slr_rodata integer lists.
    res = ssa_lower_module_buf(low, ir_mod)
    if res.slr_success == 1
        res.slr_code = ssa_lower_buf_to_list(res.slr_code_buf)
        res.slr_rodata = ssa_lower_buf_to_list(res.slr_rodata_buf)
    end
    return res
end
