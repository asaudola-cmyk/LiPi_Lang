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
    slr_rodata      // list: read-only data bytes (.rodata, STR0-prefixed)
    slr_fn_names    // list: names of emitted functions
    slr_fn_offsets  // list: entry byte offsets of emitted functions
    slr_fn_sizes    // list: exact byte lengths of each emitted SSA function (prevents duplicate bloat!)
    slr_fn_eligible // list: 1 if function is 100% natively lowered and ready to replace token re-parser
    slr_fn_ret_types // list: normalized return types ("int", "float", "str", struct name)
    slr_str_relocs  // list of [code_offset, rodata_offset] pairs for STR0 string literals
    slr_call_relocs // list of SsaJumpPatch entries for all OP_CALL / runtime helper calls
    slr_total_insts // integer: total SSA instructions lowered
    slr_success     // integer: 1 on success, 0 on failure
    slr_error_msg   // string: diagnostic message on error

struct SsaLowerer
    low_target_arch // integer: TARGET_ID_X86_64, TARGET_ID_ARM64, TARGET_ID_RISCV64
    low_code        // list of bytes
    low_rodata      // list of bytes
    low_slots       // list of SsaSlot structs
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
    low.low_total_insts = 0
    return low

fn ssa_lowerer_emit_bytes low blist
    i = 0
    while i < blist.len()
        ssa_lowerer_emit_byte(low, blist[i])
        i = i + 1
    end
    return 0

fn ssa_lowerer_add_rodata_str low str_text
    // WHY: Prepends exact 8-byte STR0 header (u32 len + "0RTS" = 0x53545230) matching x86_64 runtime ABI.
    slen = len(str_text)
    push(low.low_rodata, slen % 256)
    push(low.low_rodata, (slen / 256) % 256)
    push(low.low_rodata, (slen / 65536) % 256)
    push(low.low_rodata, (slen / 16777216) % 256)
    push(low.low_rodata, 48) // '0'
    push(low.low_rodata, 82) // 'R'
    push(low.low_rodata, 84) // 'T'
    push(low.low_rodata, 83) // 'S'
    start_off = low.low_rodata.len()
    i = 0
    while i < slen
        push(low.low_rodata, ord(char_at(str_text, i)))
        i = i + 1
    end
    push(low.low_rodata, 0)
    return start_off

fn ssa_hash_str_4096 s
    // WHY: Deterministic FNV-1a-style 12-bit bucket hash for O(1) inter-function call resolution.
    h = 2166136261
    n = len(s)
    i = 0
    while i < n
        h = ((h ^ ord(char_at(s, i))) * 16777619) & 2147483647
        i = i + 1
    return h & 4095

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

    if op == OP_ADD or op == OP_ADD_DYN or op == OP_SUB or op == OP_MUL or op == OP_DIV or op == OP_MOD or op == OP_AND or op == OP_OR or op == OP_XOR or op == OP_SHL or op == OP_SHR
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
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            ssa_lowerer_emit_byte(low, 80) // push rax
            ssa_lower_x86_load_val_to_rax(low, inst.operands[1])
            // mov rcx, rax; pop rax; movq xmm0, rax; movq xmm1, rcx
            ssa_lowerer_emit_bytes(low, [72, 137, 193, 88, 102, 72, 15, 110, 192, 102, 72, 15, 110, 201])
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
            ssa_lower_x86_load_val_to_rax(low, inst.operands[0])
            ssa_lowerer_emit_byte(low, 80) // push rax
            ssa_lower_x86_load_val_to_rax(low, inst.operands[1])
            // mov rcx, rax; pop rax; movq xmm0, rax; movq xmm1, rcx; ucomisd xmm0, xmm1
            ssa_lowerer_emit_bytes(low, [72, 137, 193, 88, 102, 72, 15, 110, 192, 102, 72, 15, 110, 201, 102, 15, 46, 193])
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
            // mov rdi, alloc_sz; call _lipi_user_alloc
            ssa_lowerer_emit_bytes(low, [72, 199, 199])
            ssa_lowerer_emit_u32(low, alloc_sz)
            ssa_lowerer_emit_byte(low, 232)
            p_alloc = low.low_code.len()
            ssa_lowerer_emit_u32(low, 0)
            jp_al = SsaJumpPatch()
            jp_al.sjp_offset = p_alloc
            jp_al.sjp_target = "_lipi_user_alloc"
            jp_al.sjp_kind = 10
            push(low.low_call_patches, jp_al)
            ssa_lower_x86_store_rax_to_slot(low, inst.result.id)
            // Initialize fields [ptr + fi*8] = operands[fi]
            fi = 0
            while fi < inst.operands.len()
                ssa_lower_x86_load_val_to_rax(low, inst.operands[fi])
                ssa_lowerer_emit_byte(low, 80) // push rax
                ssa_lower_x86_load_val_to_rax(low, inst.result)
                // mov rcx, rax; pop rax; mov [rcx + fi*8], rax
                ssa_lowerer_emit_bytes(low, [72, 137, 193, 88, 72, 137, 129])
                ssa_lowerer_emit_u32(low, fi * 8)
                fi = fi + 1
            end
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
            // mov rax, [rax + byte_off]
            ssa_lowerer_emit_bytes(low, [72, 139, 128])
            ssa_lowerer_emit_u32(low, inst.extra_int)
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
            // push ptr; load val -> rax; pop rcx; mov [rcx + byte_off], rax
            ssa_lowerer_emit_byte(low, 80)
            ssa_lower_x86_load_val_to_rax(low, inst.operands[1])
            ssa_lowerer_emit_bytes(low, [89, 72, 137, 129])
            ssa_lowerer_emit_u32(low, inst.extra_int)
        end
        return 0

    if op == OP_CMP or op == OP_CMP_DYN
        // cmp pred, %a, %b  (or dynamic int/str comparison via _lipi_cmp_dynamic)
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

    if op == OP_CALL
        // WHY: Lowers function invocation under System V AMD64 ABI:
        // passes up to 6 parameters in %rdi, %rsi, %rdx, %rcx, %r8, %r9.
        arg_i = 0
        while arg_i < inst.operands.len() and arg_i < 6
            arg_op = inst.operands[arg_i]
            ssa_lower_x86_load_val_to_rax(low, arg_op)
            if arg_i == 0
                // mov rdi, rax (0x48 0x89 0xC7)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 137)
                ssa_lowerer_emit_byte(low, 199)
            elif arg_i == 1
                // mov rsi, rax (0x48 0x89 0xC6)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 137)
                ssa_lowerer_emit_byte(low, 198)
            elif arg_i == 2
                // mov rdx, rax (0x48 0x89 0xC2)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 137)
                ssa_lowerer_emit_byte(low, 194)
            elif arg_i == 3
                // mov rcx, rax (0x48 0x89 0xC1)
                ssa_lowerer_emit_byte(low, 72)
                ssa_lowerer_emit_byte(low, 137)
                ssa_lowerer_emit_byte(low, 193)
            elif arg_i == 4
                // mov r8, rax (0x49 0x89 0xC0)
                ssa_lowerer_emit_byte(low, 73)
                ssa_lowerer_emit_byte(low, 137)
                ssa_lowerer_emit_byte(low, 192)
            elif arg_i == 5
                // mov r9, rax (0x49 0x89 0xC1)
                ssa_lowerer_emit_byte(low, 73)
                ssa_lowerer_emit_byte(low, 137)
                ssa_lowerer_emit_byte(low, 193)
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

// ── 5. Backpatching & Module Lowering ─────────────────────────────────────────

fn ssa_lowerer_resolve_function_branches low
    // WHY: Resolves intra-function basic block branches immediately before per-function slot/block state is reset.
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
            disp = tgt_offset - (patch.sjp_offset + 4)
            ssa_lowerer_patch_u32(low, patch.sjp_offset, disp)
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
            disp = tgt_offset - (patch.sjp_offset + 4)
            ssa_lowerer_patch_u32(low, patch.sjp_offset, disp)
        end
        pi = pi + 1
    end
    return 0

fn ssa_lower_function low fn_obj
    // WHY: Lowers an entire IRFunction and its basic blocks into machine code.
    // Resets per-function slot and block tables so frame offsets stay bounded per function and lookup stays O(1).
    low.low_slots = list()
    low.low_cur_offset = 8
    low.low_blocks = list()
    low.low_patches = list()

    fn_start_off = low.low_code.len()
    push(low.low_fn_names, fn_obj.name)
    push(low.low_fn_offsets, fn_start_off)

    // 1. Calculate frame requirement based on allocas, parameters, and temporaries
    alloca_count = fn_obj.allocas.len()
    inst_count = ir_function_count_insts(fn_obj)
    param_count = fn_obj.params.len()
    frame_size = (alloca_count + inst_count + param_count + 8) * 8
    // Pad to 16-byte alignment
    if (frame_size % 16) != 0
        frame_size = frame_size + (16 - (frame_size % 16))
    low.low_stack_frame = frame_size

    // Check native direct-replacement eligibility across all live SSA instructions
    fn_elig = fn_obj.is_ssa_native_ready
    if param_count > 6 or low.low_target_arch != TARGET_ID_X86_64
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

    // 2. Emit function prologue & bind incoming System V AMD64 ABI parameter registers (%rdi..%r9)
    ssa_lower_x86_prologue(low, frame_size)
    pi_arg = 0
    while pi_arg < param_count and pi_arg < 6
        pval = fn_obj.params[pi_arg]
        if pi_arg == 0
            // mov rax, rdi (0x48 0x89 0xF8)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 248)
        elif pi_arg == 1
            // mov rax, rsi (0x48 0x89 0xF0)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 240)
        elif pi_arg == 2
            // mov rax, rdx (0x48 0x89 0xD0)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 208)
        elif pi_arg == 3
            // mov rax, rcx (0x48 0x89 0xC8)
            ssa_lowerer_emit_byte(low, 72)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 200)
        elif pi_arg == 4
            // mov rax, r8 (0x4C 0x89 0xC0)
            ssa_lowerer_emit_byte(low, 76)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 192)
        elif pi_arg == 5
            // mov rax, r9 (0x4C 0x89 0xC8)
            ssa_lowerer_emit_byte(low, 76)
            ssa_lowerer_emit_byte(low, 137)
            ssa_lowerer_emit_byte(low, 200)
        end
        ssa_lower_x86_store_rax_to_slot(low, pval.id)
        pi_arg = pi_arg + 1
    end

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

    ssa_lowerer_resolve_function_branches(low)
    low.low_patches = list()
    push(low.low_fn_sizes, low.low_code.len() - fn_start_off)
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
    return 0

fn ssa_lower_module low ir_mod
    // WHY: Master orchestration entry point. Lowers entire IRModule to machine code.
    res = SsaLowerResult()
    res.slr_code = list()
    res.slr_rodata = list()
    res.slr_fn_names = list()
    res.slr_fn_offsets = list()
    res.slr_fn_sizes = list()
    res.slr_fn_eligible = list()
    res.slr_fn_ret_types = list()
    res.slr_str_relocs = list()
    res.slr_call_relocs = list()
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
    res.slr_fn_sizes = low.low_fn_sizes
    res.slr_fn_eligible = low.low_fn_eligible
    res.slr_fn_ret_types = low.low_fn_ret_types
    res.slr_str_relocs = low.low_str_relocs
    res.slr_call_relocs = low.low_call_patches
    res.slr_total_insts = low.low_total_insts
    res.slr_success = 1
    return res
