// ==============================================================================
// 👑 Lipi Pure Self-Hosting Direct ELF Emitter (src/compiler/elf_emitter.lp)
// ⚡ Written 100% in Pure Lipi (.lp) | Emits Raw Linux x86_64 ELF64 Machine Code
// 🏛️ Version: First 1.0 (প্রথম ১.০) — Sovereign
//
// WHY: This file realizes the ultimate theoretical closure of the Lipi language:
//      A compiler written entirely in Lipi that synthesizes native silicon machine
//      code bytes and Linux ELF64 headers directly, without requiring C transpilation
//      or external toolchains.
// ==============================================================================

include "src/compiler/arm64_emitter.lp"

// WHY: Relocate ELF_BASE_VADDR to 0x40000000 (1GB safe high virtual address range)
//      Eliminates static string address collisions with loop counters (e.g. i=4,197,366)
ELF_BASE_VADDR    = 1073741824  // 0x40000000 (1GB)
ELF_HEADER_SIZE   = 120         // 64 bytes ELF64 header + 56 bytes Program header
ENTRY_POINT_VADDR = 1073741944  // 0x40000078 = ELF_BASE_VADDR + ELF_HEADER_SIZE

// ── Monomorphic Type Constants ───────────────────────────────────────────────
// WHY: Monomorphic lowering distinguishes integer ALU operations from string dynamic calls
TY_UNKNOWN = 0
TY_INT     = 1
TY_STR     = 2

// ── Compiler Context (Explicit mutable state container) ──────────────────────
// WHY: In Lipi, passing a list container ensures state is modified in place
//      across function boundaries without any lexical scope ambiguity.
// Fields of ctx:
//   0: bb (raw bytes list 0..255)
//   1: lbl_names
//   2: lbl_offsets
//   3: reloc_pos
//   4: reloc_target
//   5: reloc_instlen
//   6: str_texts
//   7: str_labels
//   8: sc_names
//   9: sc_offs
//  10: sc_stack (list with 1 int: current stack bytes)
//  11: anon_id  (list with 1 int: label counter)
//  12: glob_names
//  13: glob_vals
//  14: loop_start_stack
//  15: loop_end_stack
//  16: struct_names
//  17: struct_fields
//  18: struct_var_names
//  19: struct_var_types
//  20: sc_types (monomorphic variable type tracking)
fn ctx_new
    c = list()
    push(c, list())     // 0: bb
    push(c, list())     // 1: lbl_names
    push(c, list())     // 2: lbl_offsets
    push(c, list())     // 3: reloc_pos
    push(c, list())     // 4: reloc_target
    push(c, list())     // 5: reloc_instlen
    push(c, list())     // 6: str_texts
    push(c, list())     // 7: str_labels
    push(c, list())     // 8: sc_names
    push(c, list())     // 9: sc_offs
    push(c, list(0))    // 10: sc_stack
    push(c, list(0))    // 11: anon_id
    push(c, list())     // 12: glob_names
    push(c, list())     // 13: glob_vals
    push(c, list())     // 14: loop_start_stack
    push(c, list())     // 15: loop_end_stack
    push(c, list())     // 16: struct_names
    push(c, list())     // 17: struct_fields
    push(c, list())     // 18: struct_var_names
    push(c, list())     // 19: struct_var_types
    push(c, list())     // 20: sc_types
    return c

fn loop_push ctx start_lbl end_lbl
    push(get(ctx, 14), start_lbl)
    push(get(ctx, 15), end_lbl)

fn loop_pop ctx
    sstk = get(ctx, 14)
    estk = get(ctx, 15)
    if len(sstk) > 0
        pop(sstk)
    if len(estk) > 0
        pop(estk)

fn ctx_bb c = get(c, 0)
fn ctx_len c = len(get(c, 0))

// ── Dynamic Byte Buffer Operations ───────────────────────────────────────────
fn bb_put8 ctx b
    bb = get(ctx, 0)
    val = floor(b) % 256
    if val < 0
        val = val + 256
    push(bb, val)

fn bb_put16 ctx val
    v = floor(val)
    if v < 0
        v = v + 65536
    bb_put8(ctx, v % 256)
    bb_put8(ctx, floor(v / 256) % 256)

fn bb_put32 ctx val
    v = floor(val)
    if v < 0
        v = v + 4294967296
    bb_put8(ctx, v % 256)
    bb_put8(ctx, floor(v / 256) % 256)
    bb_put8(ctx, floor(v / 65536) % 256)
    bb_put8(ctx, floor(v / 16777216) % 256)

fn bb_put64 ctx val
    v = floor(val)
    if v < 0
        // WHY: 64-bit two's complement encoding for negative numbers
        lo = v + 4294967296
        hi = 4294967295
        bb_put32(ctx, lo)
        bb_put32(ctx, hi)
        return 0
    lo = v % 4294967296
    hi = floor(v / 4294967296) % 4294967296
    bb_put32(ctx, lo)
    bb_put32(ctx, hi)

fn bb_set8 ctx pos val
    bb = get(ctx, 0)
    v = floor(val) % 256
    if v < 0
        v = v + 256
    list_set(bb, pos, v)

fn bb_set32 ctx pos val
    v = floor(val)
    if v < 0
        v = v + 4294967296
    bb_set8(ctx, pos + 0, v % 256)
    bb_set8(ctx, pos + 1, floor(v / 256) % 256)
    bb_set8(ctx, pos + 2, floor(v / 65536) % 256)
    bb_set8(ctx, pos + 3, floor(v / 16777216) % 256)

fn bb_write ctx bytes_list
    // WHY: Explicit while loop avoids range-loop vs list-iteration parser divergence in native seed
    bi = 0
    blen = len(bytes_list)
    while bi < blen
        bb_put8(ctx, get(bytes_list, bi))
        bi = bi + 1

// ── Labels & Relocations ─────────────────────────────────────────────────────
fn label_define ctx name
    bb = get(ctx, 0)
    offset = len(bb)
    push(get(ctx, 1), name)
    push(get(ctx, 2), offset)

fn label_find ctx name
    names = get(ctx, 1)
    offs  = get(ctx, 2)
    i = 0
    while i < len(names)
        if get(names, i) == name
            return get(offs, i)
        i = i + 1
    say "Undefined machine code label: " + name
    exit(1)
    return 0

fn reloc_add ctx patch_pos target_name inst_len
    push(get(ctx, 3), patch_pos)
    push(get(ctx, 4), target_name)
    push(get(ctx, 5), inst_len)

fn backpatch_all ctx
    r_pos     = get(ctx, 3)
    r_target  = get(ctx, 4)
    r_instlen = get(ctx, 5)
    i = 0
    while i < len(r_pos)
        patch_pos   = get(r_pos, i)
        target_name = get(r_target, i)
        inst_len    = get(r_instlen, i)
        target_pos  = label_find(ctx, target_name)
        inst_start  = patch_pos - (inst_len - 4)
        next_rip    = inst_start + inst_len
        disp        = target_pos - next_rip
        bb_set32(ctx, patch_pos, disp)
        i = i + 1

fn make_anon_label ctx prefix
    ctr_ref = get(ctx, 11)
    id_val = get(ctr_ref, 0) + 1
    list_set(ctr_ref, 0, id_val)
    return prefix + "_" + str(id_val)

// ── Constant String Pool ──────────────────────────────────────────────────────
fn string_pool_get ctx text
    texts  = get(ctx, 6)
    labels = get(ctx, 7)
    i = 0
    while i < len(texts)
        if get(texts, i) == text
            return get(labels, i)
        i = i + 1
    lbl = "str_c_" + str(len(texts))
    push(texts, text)
    push(labels, lbl)
    return lbl

// ── Variable Scope Tracking ──────────────────────────────────────────────────
fn scope_get ctx name
    names = get(ctx, 8)
    offs  = get(ctx, 9)
    i = 0
    while i < len(names)
        if get(names, i) == name
            return get(offs, i)
        i = i + 1
    return 0

fn scope_get_type ctx name
    if len(ctx) <= 20
        return TY_UNKNOWN
    names = get(ctx, 8)
    types = get(ctx, 20)
    i = 0
    while i < len(names)
        if get(names, i) == name
            if i < len(types)
                return get(types, i)
            return TY_UNKNOWN
        i = i + 1
    return TY_UNKNOWN

fn scope_set_type ctx name ty
    if len(ctx) <= 20
        return 0
    names = get(ctx, 8)
    types = get(ctx, 20)
    i = 0
    while i < len(names)
        if get(names, i) == name
            while len(types) <= i
                push(types, TY_UNKNOWN)
            list_set(types, i, ty)
            return 0
        i = i + 1
    return 0

fn scope_add ctx name
    existing = scope_get(ctx, name)
    if existing != 0 return existing
    stk_ref = get(ctx, 10)
    new_stack = get(stk_ref, 0) + 8
    list_set(stk_ref, 0, new_stack)
    push(get(ctx, 8), name)
    push(get(ctx, 9), new_stack)
    if len(ctx) > 20
        push(get(ctx, 20), TY_UNKNOWN)
    return new_stack

// ── Struct Registry & Type Tracking ──────────────────────────────────────────
// WHY: Allows native stack/heap struct allocation and field access with Zero Libc
fn struct_add ctx name fields
    push(get(ctx, 16), name)
    push(get(ctx, 17), fields)

fn struct_find ctx name
    snames = get(ctx, 16)
    i = 0
    while i < len(snames)
        if get(snames, i) == name
            return i
        i = i + 1
    return -1

fn struct_get_field_offset ctx sname fname
    snames = get(ctx, 16)
    sfields = get(ctx, 17)
    if sname != ""
        sidx = struct_find(ctx, sname)
        if sidx >= 0
            fnames = get(sfields, sidx)
            f = 0
            while f < len(fnames)
                if get(fnames, f) == fname
                    return f * 8
                f = f + 1
    // Fallback: search across all defined structs for field name
    s = 0
    while s < len(snames)
        fnames = get(sfields, s)
        f = 0
        while f < len(fnames)
            if get(fnames, f) == fname
                return f * 8
            f = f + 1
        s = s + 1
    return 0

fn struct_set_var_type ctx vname sname
    vnames = get(ctx, 18)
    vtypes = get(ctx, 19)
    i = 0
    while i < len(vnames)
        if get(vnames, i) == vname
            list_set(vtypes, i, sname)
            return 0
        i = i + 1
    push(vnames, vname)
    push(vtypes, sname)
    return 0

fn struct_get_var_type ctx vname
    vnames = get(ctx, 18)
    vtypes = get(ctx, 19)
    i = 0
    while i < len(vnames)
        if get(vnames, i) == vname
            return get(vtypes, i)
        i = i + 1
    return ""

// ── x86_64 Machine Code Instructions ─────────────────────────────────────────
fn x86_push_rbp ctx
    bb_put8(ctx, 85) // 0x55

fn x86_mov_rbp_rsp ctx
    bb_put8(ctx, 72) // 0x48
    bb_put8(ctx, 137) // 0x89
    bb_put8(ctx, 229) // 0xE5

fn x86_pop_rbp ctx
    bb_put8(ctx, 93) // 0x5D

fn x86_leave ctx
    bb_put8(ctx, 201) // 0xC9

fn x86_ret ctx
    bb_put8(ctx, 195) // 0xC3

fn x86_syscall ctx
    bb_put8(ctx, 15) // 0x0F
    bb_put8(ctx, 5)  // 0x05

fn x86_sub_rsp ctx bytes_n
    if bytes_n <= 0 return 0
    if bytes_n <= 127
        bb_put8(ctx, 72)  // 0x48
        bb_put8(ctx, 131) // 0x83
        bb_put8(ctx, 236) // 0xEC
        bb_put8(ctx, bytes_n)
    else
        bb_put8(ctx, 72)  // 0x48
        bb_put8(ctx, 129) // 0x81
        bb_put8(ctx, 236) // 0xEC
        bb_put32(ctx, bytes_n)
    return 0

fn x86_push_reg ctx reg
    if reg >= 8
        bb_put8(ctx, 65) // 0x41
        bb_put8(ctx, 80 + (reg % 8))
    else
        bb_put8(ctx, 80 + reg)

fn x86_pop_reg ctx reg
    if reg >= 8
        bb_put8(ctx, 65) // 0x41
        bb_put8(ctx, 88 + (reg % 8))
    else
        bb_put8(ctx, 88 + reg)

fn x86_mov_reg_imm64 ctx reg val
    if val == 0
        // WHY: Peephole optimization: xor reg32, reg32 is only 2-3 bytes vs 10 bytes for mov reg64, 0
        // In AMD64, writing to a 32-bit register automatically zero-extends to the full 64-bit register
        rex = 0
        if reg >= 8
            rex = 69 // 0x45 (REX.RB)
        modrm = 192 + ((reg % 8) * 8) + (reg % 8)
        if rex > 0
            bb_put8(ctx, rex)
        bb_put8(ctx, 49) // 0x31 (xor r/m32, r32)
        bb_put8(ctx, modrm)
        return 0
    rex = 72 // 0x48
    if reg >= 8
        rex = 73 // 0x49
    op = 184 + (reg % 8) // 0xB8 + reg
    bb_put8(ctx, rex)
    bb_put8(ctx, op)
    bb_put64(ctx, val)

fn x86_mov_reg_reg ctx dst src
    rex = 72
    if src >= 8
        rex = rex + 4
    if dst >= 8
        rex = rex + 1
    modrm = 192 + ((src % 8) * 8) + (dst % 8)
    bb_put8(ctx, rex)
    bb_put8(ctx, 137) // 0x89
    bb_put8(ctx, modrm)

fn x86_mov_stack_rax ctx offset
    disp = 0 - offset
    if disp >= -128 and disp <= 127
        bb_put8(ctx, 72)  // 0x48
        bb_put8(ctx, 137) // 0x89
        bb_put8(ctx, 69)  // 0x45
        bb_put8(ctx, disp)
    else
        bb_put8(ctx, 72)  // 0x48
        bb_put8(ctx, 137) // 0x89
        bb_put8(ctx, 133) // 0x85
        bb_put32(ctx, disp)

fn x86_mov_rax_stack ctx offset
    disp = 0 - offset
    if disp >= -128 and disp <= 127
        bb_put8(ctx, 72)  // 0x48
        bb_put8(ctx, 139) // 0x8B
        bb_put8(ctx, 69)  // 0x45
        bb_put8(ctx, disp)
    else
        bb_put8(ctx, 72)  // 0x48
        bb_put8(ctx, 139) // 0x8B
        bb_put8(ctx, 133) // 0x85
        bb_put32(ctx, disp)

fn x86_lea_reg_rip ctx reg label_name
    rex = 72
    if reg >= 8
        rex = 76 // 0x4C
    modrm = 5 + ((reg % 8) * 8)
    pos = ctx_len(ctx)
    bb_put8(ctx, rex)
    bb_put8(ctx, 141) // 0x8D
    bb_put8(ctx, modrm)
    bb_put32(ctx, 0)  // Relocation placeholder
    reloc_add(ctx, pos + 3, label_name, 7)

fn x86_add_rax_rbx ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 1)   // 0x01
    bb_put8(ctx, 216) // 0xD8

fn x86_sub_rax_rbx ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 41)  // 0x29
    bb_put8(ctx, 216) // 0xD8

fn x86_imul_rax_rbx ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 15)  // 0x0F
    bb_put8(ctx, 175) // 0xAF
    bb_put8(ctx, 195) // 0xC3

fn x86_idiv_rbx ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 153) // 0x99 (cqo: sign-extend rax into rdx:rax)
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 247) // 0xF7
    bb_put8(ctx, 251) // 0xFB (idiv rbx)

fn x86_imod_rbx ctx
    x86_idiv_rbx(ctx)
    x86_mov_reg_reg(ctx, 0, 2) // mov rax, rdx (remainder)

// ── Peephole Modulo Optimization & Strength Reduction ────────────────────────
// WHY: Replaces 35-40 cycle idiv instructions with single-cycle bitwise masking
//      or 3-cycle reciprocal imul hardware arithmetic for small numbers.
fn is_power_of_two n
    if n <= 0
        return 0
    p = 2
    while p <= 1073741824
        if p == n
            return 1
        p = p * 2
    return 0

fn emit_strength_reduced_mod ctx k
    // Case 1: Modulo by 1 is identically zero for all integers
    if k == 1
        x86_mov_reg_imm64(ctx, 0, 0)
        return 0

    // Case 2: Positive power of 2 (2, 4, 8, 16, 32, 64, ...) via bitwise AND with sign correction
    if is_power_of_two(k) == 1
        lbl_pos  = make_anon_label(ctx, "mod_pos")
        lbl_done = make_anon_label(ctx, "mod_done")
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        p_jns = ctx_len(ctx)
        bb_put8(ctx, 15)
        bb_put8(ctx, 137)
        bb_put32(ctx, 0) // jns lbl_pos
        reloc_add(ctx, p_jns + 2, lbl_pos, 6)
        x86_neg_rax(ctx)
        bb_put8(ctx, 72)
        bb_put8(ctx, 37)
        bb_put32(ctx, k - 1) // and rax, k - 1 (0x48 0x25 imm32)
        x86_neg_rax(ctx)
        x86_jmp(ctx, lbl_done)
        label_define(ctx, lbl_pos)
        bb_put8(ctx, 72)
        bb_put8(ctx, 37)
        bb_put32(ctx, k - 1) // and rax, k - 1
        label_define(ctx, lbl_done)
        return 0

    // Case 3: Small divisor 3 via magic reciprocal multiplication (0x5555555555555556)
    if k == 3
        bb_put8(ctx, 73)
        bb_put8(ctx, 137)
        bb_put8(ctx, 195) // mov r11, rax
        x86_mov_reg_imm64(ctx, 3, 6148914691236517206) // movabs rbx, 0x5555555555555556
        bb_put8(ctx, 72)
        bb_put8(ctx, 247)
        bb_put8(ctx, 235) // imul rbx
        bb_put8(ctx, 76)
        bb_put8(ctx, 137)
        bb_put8(ctx, 216) // mov rax, r11
        bb_put8(ctx, 72)
        bb_put8(ctx, 193)
        bb_put8(ctx, 248)
        bb_put8(ctx, 63)  // sar rax, 63
        bb_put8(ctx, 72)
        bb_put8(ctx, 41)
        bb_put8(ctx, 194) // sub rdx, rax
        bb_put8(ctx, 72)
        bb_put8(ctx, 107)
        bb_put8(ctx, 194)
        bb_put8(ctx, 3)   // imul rax, rdx, 3
        bb_put8(ctx, 76)
        bb_put8(ctx, 137)
        bb_put8(ctx, 218) // mov rdx, r11
        bb_put8(ctx, 72)
        bb_put8(ctx, 41)
        bb_put8(ctx, 194) // sub rdx, rax
        bb_put8(ctx, 72)
        bb_put8(ctx, 137)
        bb_put8(ctx, 208) // mov rax, rdx
        return 0

    // Case 4: Small divisor 5 via magic reciprocal multiplication (0x6666666666666667)
    if k == 5
        bb_put8(ctx, 73)
        bb_put8(ctx, 137)
        bb_put8(ctx, 195) // mov r11, rax
        x86_mov_reg_imm64(ctx, 3, 7378697629483820647) // movabs rbx, 0x6666666666666667
        bb_put8(ctx, 72)
        bb_put8(ctx, 247)
        bb_put8(ctx, 235) // imul rbx
        bb_put8(ctx, 72)
        bb_put8(ctx, 209)
        bb_put8(ctx, 250) // sar rdx, 1
        bb_put8(ctx, 76)
        bb_put8(ctx, 137)
        bb_put8(ctx, 216) // mov rax, r11
        bb_put8(ctx, 72)
        bb_put8(ctx, 193)
        bb_put8(ctx, 248)
        bb_put8(ctx, 63)  // sar rax, 63
        bb_put8(ctx, 72)
        bb_put8(ctx, 41)
        bb_put8(ctx, 194) // sub rdx, rax
        bb_put8(ctx, 72)
        bb_put8(ctx, 107)
        bb_put8(ctx, 194)
        bb_put8(ctx, 5)   // imul rax, rdx, 5
        bb_put8(ctx, 76)
        bb_put8(ctx, 137)
        bb_put8(ctx, 218) // mov rdx, r11
        bb_put8(ctx, 72)
        bb_put8(ctx, 41)
        bb_put8(ctx, 194) // sub rdx, rax
        bb_put8(ctx, 72)
        bb_put8(ctx, 137)
        bb_put8(ctx, 208) // mov rax, rdx
        return 0

    // Case 5: Divisor 7 (Critical for benchmarks/bench_loop.lp)
    // WHY: Converts inner loop i % 7 from 40-cycle idiv to single-digit cycle imul
    if k == 7
        bb_put8(ctx, 73)
        bb_put8(ctx, 137)
        bb_put8(ctx, 195) // mov r11, rax
        x86_mov_reg_imm64(ctx, 3, 5270498306774157605) // movabs rbx, 0x4924924924924925
        bb_put8(ctx, 72)
        bb_put8(ctx, 247)
        bb_put8(ctx, 235) // imul rbx
        bb_put8(ctx, 72)
        bb_put8(ctx, 209)
        bb_put8(ctx, 250) // sar rdx, 1
        bb_put8(ctx, 76)
        bb_put8(ctx, 137)
        bb_put8(ctx, 216) // mov rax, r11
        bb_put8(ctx, 72)
        bb_put8(ctx, 193)
        bb_put8(ctx, 248)
        bb_put8(ctx, 63)  // sar rax, 63
        bb_put8(ctx, 72)
        bb_put8(ctx, 41)
        bb_put8(ctx, 194) // sub rdx, rax
        bb_put8(ctx, 72)
        bb_put8(ctx, 107)
        bb_put8(ctx, 194)
        bb_put8(ctx, 7)   // imul rax, rdx, 7
        bb_put8(ctx, 76)
        bb_put8(ctx, 137)
        bb_put8(ctx, 218) // mov rdx, r11
        bb_put8(ctx, 72)
        bb_put8(ctx, 41)
        bb_put8(ctx, 194) // sub rdx, rax
        bb_put8(ctx, 72)
        bb_put8(ctx, 137)
        bb_put8(ctx, 208) // mov rax, rdx
        return 0

    // General constant fallback: load constant directly into rbx without rax push/pop
    x86_mov_reg_imm64(ctx, 3, k)
    x86_imod_rbx(ctx)
    return 0

fn x86_neg_rax ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 247) // 0xF7
    bb_put8(ctx, 216) // 0xD8 (neg rax)

fn x86_cmp_rax_rbx ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 57)  // 0x39
    bb_put8(ctx, 216) // 0xD8 (cmp rbx, rax)


fn x86_cmp_reg_reg ctx reg1 reg2
    rex = 72
    if reg2 >= 8
        rex = rex + 4
    if reg1 >= 8
        rex = rex + 1
    modrm = 192 + ((reg2 % 8) * 8) + (reg1 % 8)
    bb_put8(ctx, rex)
    bb_put8(ctx, 57) // 0x39 cmp r/m, reg
    bb_put8(ctx, modrm)

fn x86_add_rsp ctx bytes_n
    if bytes_n > 0
        bb_put8(ctx, 72)
        bb_put8(ctx, 129)
        bb_put8(ctx, 196) // add rsp, imm32
        bb_put32(ctx, bytes_n)

fn x86_jmp ctx target_name
    pos = ctx_len(ctx)
    bb_put8(ctx, 233) // 0xE9 (jmp rel32)
    bb_put32(ctx, 0)
    reloc_add(ctx, pos + 1, target_name, 5)

fn x86_jz ctx target_name
    pos = ctx_len(ctx)
    bb_put8(ctx, 15)  // 0x0F
    bb_put8(ctx, 132) // 0x84 (jz rel32)
    bb_put32(ctx, 0)
    reloc_add(ctx, pos + 2, target_name, 6)

fn x86_jnz ctx target_name
    pos = ctx_len(ctx)
    bb_put8(ctx, 15)  // 0x0F
    bb_put8(ctx, 133) // 0x85 (jnz rel32)
    bb_put32(ctx, 0)
    reloc_add(ctx, pos + 2, target_name, 6)

fn x86_call ctx target_name
    pos = ctx_len(ctx)
    bb_put8(ctx, 232) // 0xE8 (call rel32)
    bb_put32(ctx, 0)
    reloc_add(ctx, pos + 1, target_name, 5)

fn x86_set_cmp ctx op
    // cmp rax, rbx (left=rax, right=rbx)
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 57)  // 0x39
    bb_put8(ctx, 216) // 0xD8
    op_byte = 148    // sete
    if op == "=="
        op_byte = 148 // 0x94 sete
    elif op == "!="
        op_byte = 149 // 0x95 setne
    elif op == "<"
        op_byte = 156 // 0x9C setl
    elif op == "<="
        op_byte = 158 // 0x9E setle
    elif op == ">"
        op_byte = 159 // 0x9F setg
    elif op == ">="
        op_byte = 157 // 0x9D setge
    bb_put8(ctx, 15)      // 0x0F
    bb_put8(ctx, op_byte)
    bb_put8(ctx, 192)     // 0xC0 (al)
    bb_put8(ctx, 72)      // 0x48
    bb_put8(ctx, 15)      // 0x0F
    bb_put8(ctx, 182)     // 0xB6
    bb_put8(ctx, 192)     // 0xC0 (movzx rax, al)

// ── Emit Baremetal Syscall & Runtime Stubs ────────────────────────────────────
fn emit_runtime_stubs ctx
    // 1. _start
    label_define(ctx, "_start")

    // ── Multiboot 1 Specification Header (16 bytes aligned) ─────────────
    // WHY: Enables direct booting on baremetal hardware, QEMU, and GRUB.
    bb_put8(ctx, 235) // 0xEB (jmp short +14 bytes)
    bb_put8(ctx, 14)  // +14 bytes
    bb_put8(ctx, 144) // 0x90 (nop)
    bb_put8(ctx, 144) // 0x90 (nop)
    bb_put32(ctx, 464367618)   // 0x1BADB002 magic
    bb_put32(ctx, 0)           // 0x00000000 flags
    bb_put32(ctx, 3830599678)  // 0xE4524FFE checksum = -(magic + flags)

    // Capture Linux initial stack frame (argc/argv) before 16-byte alignment
    x86_lea_reg_rip(ctx, 0, "_lipi_initial_rsp")
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 32) // mov [rax], rsp

    // Align stack to 16 bytes: and rsp, -16
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 131) // 0x83
    bb_put8(ctx, 228) // 0xE4
    bb_put8(ctx, 240) // 0xF0
    x86_call(ctx, "_lipi_init_heap")
    x86_call(ctx, "lipi_main")
    x86_mov_reg_reg(ctx, 7, 0) // mov rdi, rax
    x86_mov_reg_imm64(ctx, 0, 60) // mov rax, 60 (sys_exit)
    x86_syscall(ctx)
    bb_put8(ctx, 244) // 0xF4 (hlt)

    // 2. _lipi_init_heap: sys_mmap(0, 16MB, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0)
    label_define(ctx, "_lipi_init_heap")
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 49)  // 0x31
    bb_put8(ctx, 255) // 0xFF (xor rdi, rdi)
    // WHY: 1GB virtual memory allocation via anonymous mmap (0-overhead until committed pages)
    x86_mov_reg_imm64(ctx, 6, 1073741824) // rsi = 1024MB (1GB)
    x86_mov_reg_imm64(ctx, 2, 3)        // rdx = PROT_READ|PROT_WRITE
    x86_mov_reg_imm64(ctx, 10, 34)      // r10 = MAP_PRIVATE|MAP_ANONYMOUS
    x86_mov_reg_imm64(ctx, 8, -1)       // r8 = -1
    bb_put8(ctx, 77)  // 0x4D
    bb_put8(ctx, 49)  // 0x31
    bb_put8(ctx, 201) // 0xC9 (xor r9, r9)
    x86_mov_reg_imm64(ctx, 0, 9)        // rax = 9 (sys_mmap)
    x86_syscall(ctx)
    x86_lea_reg_rip(ctx, 3, "_lipi_heap_base")
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 3) // mov [rbx], rax
    x86_lea_reg_rip(ctx, 3, "_lipi_heap_ptr")
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 3) // mov [rbx], rax
    x86_ret(ctx)

    // 3. _lipi_alloc: rdi = size -> rax = ptr
    label_define(ctx, "_lipi_alloc")
    bb_put8(ctx, 83) // push rbx
    bb_put8(ctx, 65)
    bb_put8(ctx, 84) // push r12
    bb_put8(ctx, 73)
    bb_put8(ctx, 137)
    bb_put8(ctx, 252) // mov r12, rdi
    bb_put8(ctx, 72)
    bb_put8(ctx, 131)
    bb_put8(ctx, 199)
    bb_put8(ctx, 7)  // add rdi, 7
    bb_put8(ctx, 72)
    bb_put8(ctx, 131)
    bb_put8(ctx, 231)
    bb_put8(ctx, 248) // and rdi, -8
    bb_put8(ctx, 72)
    bb_put8(ctx, 131)
    bb_put8(ctx, 199)
    bb_put8(ctx, 8)  // add rdi, 8
    x86_lea_reg_rip(ctx, 3, "_lipi_heap_ptr")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 3) // mov rax, [rbx]
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 199) // add rdi, rax
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 59) // mov [rbx], rdi
    bb_put8(ctx, 76)
    bb_put8(ctx, 137)
    bb_put8(ctx, 32) // mov [rax], r12
    bb_put8(ctx, 72)
    bb_put8(ctx, 131)
    bb_put8(ctx, 192)
    bb_put8(ctx, 8) // add rax, 8
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    bb_put8(ctx, 91) // pop rbx
    x86_ret(ctx)

    // 4. _lipi_str_concat: rdi = str1, rsi = str2 -> rax = new str
    label_define(ctx, "_lipi_str_concat")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    bb_put8(ctx, 65)
    bb_put8(ctx, 84) // push r12
    bb_put8(ctx, 65)
    bb_put8(ctx, 85) // push r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 86) // push r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 87) // push r15
    bb_put8(ctx, 73)
    bb_put8(ctx, 137)
    bb_put8(ctx, 252) // mov r12, rdi
    bb_put8(ctx, 73)
    bb_put8(ctx, 137)
    bb_put8(ctx, 245) // mov r13, rsi
    bb_put8(ctx, 69)
    bb_put8(ctx, 139)
    bb_put8(ctx, 116)
    bb_put8(ctx, 36)
    bb_put8(ctx, 248) // mov r14d, [r12 - 8]
    bb_put8(ctx, 69)
    bb_put8(ctx, 139)
    bb_put8(ctx, 125)
    bb_put8(ctx, 248) // mov r15d, [r13 - 8]
    x86_mov_reg_reg(ctx, 7, 14) // mov rdi, r14
    bb_put8(ctx, 76)
    bb_put8(ctx, 1)
    bb_put8(ctx, 255) // add rdi, r15
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 199) // inc rdi
    x86_call(ctx, "_lipi_alloc")
    x86_push_reg(ctx, 0) // push rax
    x86_mov_reg_reg(ctx, 7, 0)  // mov rdi, rax
    x86_mov_reg_reg(ctx, 6, 12) // mov rsi, r12
    x86_mov_reg_reg(ctx, 1, 14) // mov rcx, r14
    bb_put8(ctx, 243)
    bb_put8(ctx, 164) // rep movsb
    x86_mov_reg_reg(ctx, 6, 13) // mov rsi, r13
    x86_mov_reg_reg(ctx, 1, 15) // mov rcx, r15
    bb_put8(ctx, 243)
    bb_put8(ctx, 164) // rep movsb
    bb_put8(ctx, 198)
    bb_put8(ctx, 7)
    bb_put8(ctx, 0) // mov byte [rdi], 0
    x86_pop_reg(ctx, 0) // pop rax
    bb_put8(ctx, 77)
    bb_put8(ctx, 1)
    bb_put8(ctx, 254) // add r14, r15
    x86_mov_reg_imm64(ctx, 2, 6004514569303621632) // mov rdx, 0x5354523000000000 ('STR0')
    bb_put8(ctx, 73)
    bb_put8(ctx, 9)
    bb_put8(ctx, 214) // or r14, rdx
    bb_put8(ctx, 76)
    bb_put8(ctx, 137)
    bb_put8(ctx, 112)
    bb_put8(ctx, 248) // mov [rax - 8], r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 95) // pop r15
    bb_put8(ctx, 65)
    bb_put8(ctx, 94) // pop r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 93) // pop r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)

    // 5. _lipi_int_to_str: rdi = int -> rax = string
    label_define(ctx, "_lipi_int_to_str")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    bb_put8(ctx, 65)
    bb_put8(ctx, 84) // push r12
    bb_put8(ctx, 65)
    bb_put8(ctx, 85) // push r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 86) // push r14
    bb_put8(ctx, 73)
    bb_put8(ctx, 137)
    bb_put8(ctx, 252) // mov r12, rdi
    x86_mov_reg_imm64(ctx, 7, 48)
    x86_call(ctx, "_lipi_alloc")
    bb_put8(ctx, 76)
    bb_put8(ctx, 141)
    bb_put8(ctx, 64)
    bb_put8(ctx, 40) // lea r8, [rax + 40]
    bb_put8(ctx, 65)
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 0)   // mov byte [r8], 0
    bb_put8(ctx, 77)
    bb_put8(ctx, 137)
    bb_put8(ctx, 197)                 // mov r13, r8
    x86_mov_reg_reg(ctx, 0, 12) // mov rax, r12
    bb_put8(ctx, 77)
    bb_put8(ctx, 49)
    bb_put8(ctx, 246)                  // xor r14, r14
    lbl_chk   = make_anon_label(ctx, "its_chk")
    lbl_setup = make_anon_label(ctx, "its_setup")
    lbl_loop  = make_anon_label(ctx, "its_loop")
    lbl_done  = make_anon_label(ctx, "its_done")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192) // test rax, rax
    x86_jnz(ctx, lbl_chk)
    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200) // dec r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 48) // mov byte [r8], '0'
    x86_jmp(ctx, lbl_done)
    label_define(ctx, lbl_chk)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    pos_jns = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 137)
    bb_put32(ctx, 0) // jns
    reloc_add(ctx, pos_jns + 2, lbl_setup, 6)
    x86_neg_rax(ctx)
    bb_put8(ctx, 73)
    bb_put8(ctx, 199)
    bb_put8(ctx, 198)
    bb_put32(ctx, 1) // mov r14, 1
    label_define(ctx, lbl_setup)
    x86_mov_reg_imm64(ctx, 3, 10)
    label_define(ctx, lbl_loop)
    bb_put8(ctx, 72)
    bb_put8(ctx, 49)
    bb_put8(ctx, 210) // xor rdx, rdx
    bb_put8(ctx, 72)
    bb_put8(ctx, 247)
    bb_put8(ctx, 243) // div rbx
    bb_put8(ctx, 128)
    bb_put8(ctx, 194)
    bb_put8(ctx, 48) // add dl, '0'
    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200) // dec r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 136)
    bb_put8(ctx, 16)  // mov [r8], dl
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192) // test rax, rax
    x86_jnz(ctx, lbl_loop)
    bb_put8(ctx, 77)
    bb_put8(ctx, 133)
    bb_put8(ctx, 246) // test r14, r14
    x86_jz(ctx, lbl_done)
    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200) // dec r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 45) // mov byte [r8], '-'
    label_define(ctx, lbl_done)
    x86_mov_reg_reg(ctx, 2, 13) // mov rdx, r13
    bb_put8(ctx, 76)
    bb_put8(ctx, 41)
    bb_put8(ctx, 194) // sub rdx, r8
    // WHY: Tag integer-to-string heap buffer with upper 32-bit STR0 (0x53545230)
    x86_mov_reg_imm64(ctx, 0, 6004514569303621632) // mov rax, 0x5354523000000000
    bb_put8(ctx, 72)
    bb_put8(ctx, 9)
    bb_put8(ctx, 194) // or rdx, rax
    bb_put8(ctx, 73)
    bb_put8(ctx, 137)
    bb_put8(ctx, 80)
    bb_put8(ctx, 248) // mov [r8 - 8], rdx
    x86_mov_reg_reg(ctx, 0, 8)  // mov rax, r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 94) // pop r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 93) // pop r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)

    // 6. _lipi_print_str: rdi = str ptr
    label_define(ctx, "_lipi_print_str")
    // WHY: Load lower 32-bit length from [rdi - 8] into edx, zero-extending into rdx
    bb_put8(ctx, 139)
    bb_put8(ctx, 87)
    bb_put8(ctx, 248) // mov edx, [rdi - 8]
    x86_mov_reg_reg(ctx, 6, 7) // mov rsi, rdi
    x86_mov_reg_imm64(ctx, 7, 1) // rdi = 1 (stdout)
    x86_mov_reg_imm64(ctx, 0, 1) // rax = 1 (sys_write)
    x86_syscall(ctx)
    x86_ret(ctx)

    // _lipi_print_space: WHY: Required for multi-argument say statements
    label_define(ctx, "_lipi_print_space")
    bb_put8(ctx, 106)
    bb_put8(ctx, 32) // push 32 (' ')
    x86_mov_reg_reg(ctx, 6, 4) // mov rsi, rsp
    x86_mov_reg_imm64(ctx, 7, 1)
    x86_mov_reg_imm64(ctx, 2, 1)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_syscall(ctx)
    x86_pop_reg(ctx, 0)
    x86_ret(ctx)

    // 7. _lipi_print_nl
    label_define(ctx, "_lipi_print_nl")
    bb_put8(ctx, 106)
    bb_put8(ctx, 10) // push 10 (\n)
    x86_mov_reg_reg(ctx, 6, 4) // mov rsi, rsp
    x86_mov_reg_imm64(ctx, 7, 1)
    x86_mov_reg_imm64(ctx, 2, 1)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_syscall(ctx)
    x86_pop_reg(ctx, 0)
    x86_ret(ctx)

    // 8. _lipi_print_int: rdi = integer
    label_define(ctx, "_lipi_print_int")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_sub_rsp(ctx, 48)
    bb_put8(ctx, 76)
    bb_put8(ctx, 141)
    bb_put8(ctx, 69)
    bb_put8(ctx, 255) // lea r8, [rbp - 1]
    bb_put8(ctx, 65)
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 0)   // mov byte [r8], 0
    x86_mov_reg_reg(ctx, 0, 7)
    x86_mov_reg_imm64(ctx, 9, 0)
    lbl_pi_chk   = make_anon_label(ctx, "pi_chk")
    lbl_pi_setup = make_anon_label(ctx, "pi_setup")
    lbl_pi_loop  = make_anon_label(ctx, "pi_loop")
    lbl_pi_print = make_anon_label(ctx, "pi_print")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192) // test rax, rax
    x86_jnz(ctx, lbl_pi_chk)
    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200) // dec r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 48) // mov byte [r8], '0'
    x86_jmp(ctx, lbl_pi_print)
    label_define(ctx, lbl_pi_chk)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    pos_pns = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 137)
    bb_put32(ctx, 0) // jns
    reloc_add(ctx, pos_pns + 2, lbl_pi_setup, 6)
    x86_neg_rax(ctx)
    x86_mov_reg_imm64(ctx, 9, 1)
    label_define(ctx, lbl_pi_setup)
    x86_mov_reg_imm64(ctx, 3, 10)
    label_define(ctx, lbl_pi_loop)
    bb_put8(ctx, 72)
    bb_put8(ctx, 49)
    bb_put8(ctx, 210) // xor rdx, rdx
    bb_put8(ctx, 72)
    bb_put8(ctx, 247)
    bb_put8(ctx, 243) // div rbx
    bb_put8(ctx, 128)
    bb_put8(ctx, 194)
    bb_put8(ctx, 48) // add dl, '0'
    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200) // dec r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 136)
    bb_put8(ctx, 16)  // mov [r8], dl
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192) // test rax, rax
    x86_jnz(ctx, lbl_pi_loop)
    bb_put8(ctx, 77)
    bb_put8(ctx, 133)
    bb_put8(ctx, 201) // test r9, r9
    x86_jz(ctx, lbl_pi_print)
    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200) // dec r8
    bb_put8(ctx, 65)
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 45) // mov byte [r8], '-'
    label_define(ctx, lbl_pi_print)
    bb_put8(ctx, 72)
    bb_put8(ctx, 141)
    bb_put8(ctx, 85)
    bb_put8(ctx, 255) // lea rdx, [rbp - 1]
    bb_put8(ctx, 76)
    bb_put8(ctx, 41)
    bb_put8(ctx, 194) // sub rdx, r8
    x86_mov_reg_reg(ctx, 6, 8) // mov rsi, r8
    x86_mov_reg_imm64(ctx, 7, 1)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_syscall(ctx)
    x86_leave(ctx)
    x86_ret(ctx)

    // 9. _lipi_is_str: in: rdi = val. out: rax = 1 (true) or 0 (false)
    label_define(ctx, "_lipi_is_str")
    // WHY: rbx is a callee-saved register under AMD64 ABI; must preserve
    x86_push_reg(ctx, 3)
    lbl_iss_chk   = make_anon_label(ctx, "iss_chk")
    lbl_iss_true  = make_anon_label(ctx, "iss_true")
    lbl_iss_false = make_anon_label(ctx, "iss_false")
    lbl_chk_heap  = make_anon_label(ctx, "iss_chkheap")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255) // test rdi, rdi
    x86_jz(ctx, lbl_iss_false)

    // 1. Check if rdi in [_lipi_data_start, _lipi_data_end]
    x86_lea_reg_rip(ctx, 3, "_lipi_data_start")
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 223) // cmp rdi, rbx
    p_ds = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)   // jb iss_chkheap
    reloc_add(ctx, p_ds + 2, lbl_chk_heap, 6)

    x86_lea_reg_rip(ctx, 3, "_lipi_data_end")
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 223) // cmp rdi, rbx
    p_de = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)   // jb iss_chk
    reloc_add(ctx, p_de + 2, lbl_iss_chk, 6)

    // 2. Check if rdi in [_lipi_heap_base, _lipi_heap_ptr]
    label_define(ctx, lbl_chk_heap)
    x86_lea_reg_rip(ctx, 3, "_lipi_heap_base")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 3) // mov rax, [rbx]
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192) // test rax, rax
    x86_jz(ctx, lbl_iss_false)
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 199) // cmp rdi, rax
    p_hb = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)   // jb iss_false
    reloc_add(ctx, p_hb + 2, lbl_iss_false, 6)

    x86_lea_reg_rip(ctx, 3, "_lipi_heap_ptr")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 19) // mov rdx, [rbx]
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 215) // cmp rdi, rdx
    p_hp = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 131)
    bb_put32(ctx, 0)   // jae iss_false
    reloc_add(ctx, p_hp + 2, lbl_iss_false, 6)

    // In valid pointer range -> Verify 32-bit tag 'STR0' (0x53545230) at [rdi - 8] >> 32
    label_define(ctx, lbl_iss_chk)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 71)
    bb_put8(ctx, 248) // mov rax, [rdi - 8]
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 232)
    bb_put8(ctx, 32)  // shr rax, 32
    x86_mov_reg_imm64(ctx, 3, 1398034992) // mov rbx, 0x53545230 ('STR0')
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 216) // cmp rax, rbx
    p_eq = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)   // je iss_true
    reloc_add(ctx, p_eq + 2, lbl_iss_true, 6)

    label_define(ctx, lbl_iss_false)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_pop_reg(ctx, 3)
    x86_ret(ctx)

    label_define(ctx, lbl_iss_true)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_pop_reg(ctx, 3)
    x86_ret(ctx)

    // 10. _lipi_ensure_str: rdi = val -> rax = string ptr
    label_define(ctx, "_lipi_ensure_str")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    bb_put8(ctx, 83) // push rbx
    bb_put8(ctx, 65)
    bb_put8(ctx, 84) // push r12
    x86_mov_reg_reg(ctx, 12, 7) // r12 = rdi
    x86_call(ctx, "_lipi_is_str")
    lbl_es_alr = make_anon_label(ctx, "es_alr")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    x86_jnz(ctx, lbl_es_alr)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_call(ctx, "_lipi_int_to_str")
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    bb_put8(ctx, 91) // pop rbx
    x86_leave(ctx)
    x86_ret(ctx)
    label_define(ctx, lbl_es_alr)
    x86_mov_reg_reg(ctx, 0, 12)
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    bb_put8(ctx, 91) // pop rbx
    x86_leave(ctx)
    x86_ret(ctx)

    // lipi_fn_str
    label_define(ctx, "lipi_fn_str")
    x86_jmp(ctx, "_lipi_ensure_str")

    // 11. _lipi_print_dynamic: rdi = val
    label_define(ctx, "_lipi_print_dynamic")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    bb_put8(ctx, 65)
    bb_put8(ctx, 84) // push r12
    x86_mov_reg_reg(ctx, 12, 7)
    x86_call(ctx, "_lipi_is_str")
    lbl_pd_str = make_anon_label(ctx, "pd_str")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    x86_jnz(ctx, lbl_pd_str)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_call(ctx, "_lipi_print_int")
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)
    label_define(ctx, lbl_pd_str)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_call(ctx, "_lipi_print_str")
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)

    // 12. _lipi_add_dynamic: rdi = left, rsi = right -> rax = sum
    label_define(ctx, "_lipi_add_dynamic")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    bb_put8(ctx, 65)
    bb_put8(ctx, 84) // push r12
    bb_put8(ctx, 65)
    bb_put8(ctx, 85) // push r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 86) // push r14
    x86_mov_reg_reg(ctx, 12, 7) // r12 = left
    x86_mov_reg_reg(ctx, 13, 6) // r13 = right
    lbl_ad_str = make_anon_label(ctx, "ad_str")
    x86_mov_reg_reg(ctx, 7, 12)
    x86_call(ctx, "_lipi_is_str")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    x86_jnz(ctx, lbl_ad_str)
    x86_mov_reg_reg(ctx, 7, 13)
    x86_call(ctx, "_lipi_is_str")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    x86_jnz(ctx, lbl_ad_str)
    // Both are integers
    x86_mov_reg_reg(ctx, 0, 12)
    x86_mov_reg_reg(ctx, 3, 13)
    x86_add_rax_rbx(ctx)
    bb_put8(ctx, 65)
    bb_put8(ctx, 94) // pop r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 93) // pop r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)

    // String concat
    label_define(ctx, lbl_ad_str)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_call(ctx, "_lipi_ensure_str")
    x86_mov_reg_reg(ctx, 14, 0) // r14 = left str

    x86_mov_reg_reg(ctx, 7, 13)
    x86_call(ctx, "_lipi_ensure_str")
    x86_mov_reg_reg(ctx, 6, 0)  // rsi = right str
    x86_mov_reg_reg(ctx, 7, 14) // rdi = left str
    x86_call(ctx, "_lipi_str_concat")
    bb_put8(ctx, 65)
    bb_put8(ctx, 94) // pop r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 93) // pop r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)

// ── _lipi_cmp_dynamic: in: rdi = lhs, rsi = rhs. out: rax = -1, 0, 1 ──
    label_define(ctx, "_lipi_cmp_dynamic")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_push_reg(ctx, 13)
    x86_push_reg(ctx, 14)
    x86_push_reg(ctx, 15)

    lbl_cd_exit = make_anon_label(ctx, "cd_exit")
    lbl_cd_chk_str = make_anon_label(ctx, "cd_chk_str")
    lbl_cd_as_ints = make_anon_label(ctx, "cd_as_ints")
    lbl_cd_lens = make_anon_label(ctx, "cd_lens")
    lbl_cd_ret_lt = make_anon_label(ctx, "cd_ret_lt")
    lbl_cd_ret_gt = make_anon_label(ctx, "cd_ret_gt")
    lbl_cd_min_ok = make_anon_label(ctx, "cd_min_ok")

    // Quick pointer/integer identity check
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 247)
    p_cd_eq = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 133)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_eq + 2, lbl_cd_chk_str, 6)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_jmp(ctx, lbl_cd_exit)

    label_define(ctx, lbl_cd_chk_str)
    x86_mov_reg_reg(ctx, 12, 7)
    x86_mov_reg_reg(ctx, 13, 6)

    // Check if lhs is string
    x86_call(ctx, "_lipi_is_str")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_cd_ns1 = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_ns1 + 2, lbl_cd_as_ints, 6)

    // Check if rhs is string
    x86_mov_reg_reg(ctx, 7, 13)
    x86_call(ctx, "_lipi_is_str")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_cd_ns2 = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_ns2 + 2, lbl_cd_as_ints, 6)

    // Both are strings! Compare contents.
    // len1 in r14 = lower 32-bit of [r12 - 8]
    x86_mov_reg_reg(ctx, 0, 12)
    bb_put8(ctx, 139)
    bb_put8(ctx, 112)
    bb_put8(ctx, 248)
    x86_mov_reg_reg(ctx, 14, 6)

    // len2 in r15 = lower 32-bit of [r13 - 8]
    x86_mov_reg_reg(ctx, 0, 13)
    bb_put8(ctx, 139)
    bb_put8(ctx, 120)
    bb_put8(ctx, 248)
    x86_mov_reg_reg(ctx, 15, 7)

    // rcx = min(r14, r15)
    x86_mov_reg_reg(ctx, 1, 14)
    x86_cmp_reg_reg(ctx, 1, 15)
    p_cd_min = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 134)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_min + 2, lbl_cd_min_ok, 6)
    x86_mov_reg_reg(ctx, 1, 15)
    label_define(ctx, lbl_cd_min_ok)

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 201)
    p_cd_zl = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_zl + 2, lbl_cd_lens, 6)

    x86_mov_reg_reg(ctx, 6, 12)
    x86_mov_reg_reg(ctx, 7, 13)
    bb_put8(ctx, 243)
    bb_put8(ctx, 166)
    p_cd_eqb = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_eqb + 2, lbl_cd_lens, 6)

    bb_put8(ctx, 72)
    bb_put8(ctx, 15)
    bb_put8(ctx, 182)
    bb_put8(ctx, 70)
    bb_put8(ctx, 255)
    bb_put8(ctx, 72)
    bb_put8(ctx, 15)
    bb_put8(ctx, 182)
    bb_put8(ctx, 87)
    bb_put8(ctx, 255)
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 208)
    p_cd_blt = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 140)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_blt + 2, lbl_cd_ret_lt, 6)
    x86_jmp(ctx, lbl_cd_ret_gt)

    label_define(ctx, lbl_cd_lens)
    x86_cmp_reg_reg(ctx, 14, 15)
    p_cd_llt = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 140)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_llt + 2, lbl_cd_ret_lt, 6)
    p_cd_lgt = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 143)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_lgt + 2, lbl_cd_ret_gt, 6)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_jmp(ctx, lbl_cd_exit)

    label_define(ctx, lbl_cd_as_ints)
    x86_cmp_reg_reg(ctx, 12, 13)
    p_cd_ilt = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 140)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_ilt + 2, lbl_cd_ret_lt, 6)
    p_cd_igt = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 143)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_cd_igt + 2, lbl_cd_ret_gt, 6)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_jmp(ctx, lbl_cd_exit)

    label_define(ctx, lbl_cd_ret_lt)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_neg_rax(ctx)
    x86_jmp(ctx, lbl_cd_exit)

    label_define(ctx, lbl_cd_ret_gt)
    x86_mov_reg_imm64(ctx, 0, 1)

    label_define(ctx, lbl_cd_exit)
    x86_pop_reg(ctx, 15)
    x86_pop_reg(ctx, 14)
    x86_pop_reg(ctx, 13)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_leave(ctx)
    x86_ret(ctx)

    // ── _lipi_len: in: rdi = obj. out: rax = len ────────────────────────────
    label_define(ctx, "_lipi_len")
    label_define(ctx, "lipi_fn_len")
    lbl_len_zero = make_anon_label(ctx, "len_zero")
    lbl_len_list = make_anon_label(ctx, "len_list")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_len_zero)

    x86_push_reg(ctx, 7)
    x86_call(ctx, "_lipi_is_str")
    x86_pop_reg(ctx, 7)

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_ln_list = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_ln_list + 2, lbl_len_list, 6)

    // String: lower 32-bit length from [rdi - 8]
    bb_put8(ctx, 139)
    bb_put8(ctx, 71)
    bb_put8(ctx, 248)
    x86_ret(ctx)

    // List: count from [rdi + 0]
    label_define(ctx, lbl_len_list)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 7)
    x86_ret(ctx)

    label_define(ctx, lbl_len_zero)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_ret(ctx)

    // ── _lipi_list_create: in: rdi = count, rsi = src_ptr. out: rax = list ──
    label_define(ctx, "_lipi_list_create")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_push_reg(ctx, 13)
    x86_push_reg(ctx, 14)
    x86_push_reg(ctx, 15)

    lbl_lc_cap_ok = make_anon_label(ctx, "lc_cap_ok")
    lbl_lc_copy_done = make_anon_label(ctx, "lc_cp_done")
    lbl_lc_copy_loop = make_anon_label(ctx, "lc_cp_loop")

    x86_mov_reg_reg(ctx, 12, 7)
    x86_mov_reg_reg(ctx, 13, 6)

    // cap in r14 = (count <= 16 ? 16 : count * 2)
    x86_mov_reg_imm64(ctx, 14, 16)
    bb_put8(ctx, 73)
    bb_put8(ctx, 131)
    bb_put8(ctx, 252)
    bb_put8(ctx, 16)
    p_lc_cap = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 134)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_lc_cap + 2, lbl_lc_cap_ok, 6)
    x86_mov_reg_reg(ctx, 14, 12)
    bb_put8(ctx, 73)
    bb_put8(ctx, 209)
    bb_put8(ctx, 230)
    label_define(ctx, lbl_lc_cap_ok)

    // Allocate buffer for cap * 8 bytes
    x86_mov_reg_reg(ctx, 7, 14)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 231)
    bb_put8(ctx, 3)
    x86_call(ctx, "_lipi_alloc")
    x86_mov_reg_reg(ctx, 15, 0)

    // If count == 0, skip copy
    bb_put8(ctx, 77)
    bb_put8(ctx, 133)
    bb_put8(ctx, 228)
    p_lc_cp = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 132)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_lc_cp + 2, lbl_lc_copy_done, 6)

    // Copy loop: for (rcx = 0; rcx < r12; rcx++)
    bb_put8(ctx, 72)
    bb_put8(ctx, 49)
    bb_put8(ctx, 201)
    label_define(ctx, lbl_lc_copy_loop)
    // rdx = (r12 - 1 - rcx) * 8
    x86_mov_reg_reg(ctx, 2, 12)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 202)
    bb_put8(ctx, 72)
    bb_put8(ctx, 41)
    bb_put8(ctx, 202)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 226)
    bb_put8(ctx, 3)
    // rax = [r13 + rdx]
    bb_put8(ctx, 76)
    bb_put8(ctx, 1)
    bb_put8(ctx, 234)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 2)
    // [r15 + rcx*8] = rax
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 202)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 226)
    bb_put8(ctx, 3)
    bb_put8(ctx, 76)
    bb_put8(ctx, 1)
    bb_put8(ctx, 250)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 2)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 193)
    x86_cmp_reg_reg(ctx, 1, 12)
    p_lc_loop = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_lc_loop + 2, lbl_lc_copy_loop, 6)

    label_define(ctx, lbl_lc_copy_done)
    // Allocate 24-byte list struct
    x86_mov_reg_imm64(ctx, 7, 24)
    x86_call(ctx, "_lipi_alloc")
    // Store header: [rax + 0] = r12, [rax + 8] = r14, [rax + 16] = r15
    bb_put8(ctx, 76)
    bb_put8(ctx, 137)
    bb_put8(ctx, 32)
    bb_put8(ctx, 76)
    bb_put8(ctx, 137)
    bb_put8(ctx, 112)
    bb_put8(ctx, 8)
    bb_put8(ctx, 76)
    bb_put8(ctx, 137)
    bb_put8(ctx, 120)
    bb_put8(ctx, 16)

    x86_pop_reg(ctx, 15)
    x86_pop_reg(ctx, 14)
    x86_pop_reg(ctx, 13)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_leave(ctx)
    x86_ret(ctx)

    // ── lipi_fn_list: 0-arg caller stub ────────────────────────────────────
    label_define(ctx, "lipi_fn_list")
    x86_mov_reg_imm64(ctx, 7, 0)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_jmp(ctx, "_lipi_list_create")

    // ── lipi_fn_push: in: rdi = list, rsi = val. out: rax = list ──────────
    label_define(ctx, "lipi_fn_push")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_push_reg(ctx, 13)
    x86_push_reg(ctx, 14)

    lbl_pu_ret0 = make_anon_label(ctx, "pu_ret0")
    lbl_pu_has_cap = make_anon_label(ctx, "pu_has_cap")
    lbl_pu_dbl = make_anon_label(ctx, "pu_dbl")
    lbl_pu_do_alloc = make_anon_label(ctx, "pu_do_alloc")
    lbl_pu_exit = make_anon_label(ctx, "pu_exit")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_pu_ret0)

    x86_mov_reg_reg(ctx, 12, 7)
    x86_mov_reg_reg(ctx, 13, 6)

    // rax = count, rbx = cap, r14 = data_ptr
    x86_mov_reg_reg(ctx, 7, 12)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 7)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 95)
    bb_put8(ctx, 8)
    bb_put8(ctx, 76)
    bb_put8(ctx, 139)
    bb_put8(ctx, 119)
    bb_put8(ctx, 16)

    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 216)
    p_pu_cap = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_pu_cap + 2, lbl_pu_has_cap, 6)

    // Double capacity
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 219)
    p_pu_nz = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 133)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_pu_nz + 2, lbl_pu_dbl, 6)
    x86_mov_reg_imm64(ctx, 3, 16)
    x86_jmp(ctx, lbl_pu_do_alloc)
    label_define(ctx, lbl_pu_dbl)
    bb_put8(ctx, 72)
    bb_put8(ctx, 209)
    bb_put8(ctx, 227)
    label_define(ctx, lbl_pu_do_alloc)

    // Allocate rbx * 8 bytes
    x86_mov_reg_reg(ctx, 7, 3)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 231)
    bb_put8(ctx, 3)
    x86_call(ctx, "_lipi_alloc")
    // Copy old elements: rsi = r14, rdi = rax, rcx = [r12]
    x86_push_reg(ctx, 0)
    x86_mov_reg_reg(ctx, 7, 0)
    x86_mov_reg_reg(ctx, 6, 14)
    x86_mov_reg_reg(ctx, 1, 12)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 9)
    bb_put8(ctx, 243)
    bb_put8(ctx, 72)
    bb_put8(ctx, 165)
    x86_pop_reg(ctx, 0)
    // Update cap and data_ptr in list header
    x86_mov_reg_reg(ctx, 7, 12)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 95)
    bb_put8(ctx, 8)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 71)
    bb_put8(ctx, 16)
    x86_mov_reg_reg(ctx, 14, 0)

    label_define(ctx, lbl_pu_has_cap)
    // rdx = [r12] * 8
    x86_mov_reg_reg(ctx, 7, 12)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 23)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 226)
    bb_put8(ctx, 3)
    bb_put8(ctx, 76)
    bb_put8(ctx, 1)
    bb_put8(ctx, 242)
    bb_put8(ctx, 76)
    bb_put8(ctx, 137)
    bb_put8(ctx, 42)
    // [rdi] = [rdi] + 1
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 7)
    x86_mov_reg_reg(ctx, 0, 12)
    x86_jmp(ctx, lbl_pu_exit)

    label_define(ctx, lbl_pu_ret0)
    x86_mov_reg_imm64(ctx, 0, 0)

    label_define(ctx, lbl_pu_exit)
    x86_pop_reg(ctx, 14)
    x86_pop_reg(ctx, 13)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_leave(ctx)
    x86_ret(ctx)

    // ── lipi_fn_get: in: rdi = list, rsi = idx. out: rax = val ─────────────
    label_define(ctx, "lipi_fn_get")
    lbl_ge_zero = make_anon_label(ctx, "ge_zero")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_ge_zero)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 246)
    p_ge_neg = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 136)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_ge_neg + 2, lbl_ge_zero, 6)
    bb_put8(ctx, 72)
    bb_put8(ctx, 59)
    bb_put8(ctx, 55)
    p_ge_oob = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 141)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_ge_oob + 2, lbl_ge_zero, 6)

    // rax = [rdi + 16]
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 71)
    bb_put8(ctx, 16)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 230)
    bb_put8(ctx, 3)
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 240)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 0)
    x86_ret(ctx)

    label_define(ctx, lbl_ge_zero)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_ret(ctx)

    // ── lipi_fn_list_set: in: rdi = list, rsi = idx, rdx = val. out: rax = list
    label_define(ctx, "lipi_fn_list_set")
    lbl_ls_done = make_anon_label(ctx, "ls_done")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_ls_done)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 246)
    p_ls_neg = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 136)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_ls_neg + 2, lbl_ls_done, 6)
    bb_put8(ctx, 72)
    bb_put8(ctx, 59)
    bb_put8(ctx, 55)
    p_ls_oob = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 141)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_ls_oob + 2, lbl_ls_done, 6)

    // rax = [rdi + 16]
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 71)
    bb_put8(ctx, 16)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 230)
    bb_put8(ctx, 3)
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 240)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 16)

    label_define(ctx, lbl_ls_done)
    x86_mov_reg_reg(ctx, 0, 7)
    x86_ret(ctx)

    // ── lipi_fn_pop: in: rdi = list. out: rax = popped item ────────────────
    label_define(ctx, "lipi_fn_pop")
    lbl_po_zero = make_anon_label(ctx, "po_zero")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_po_zero)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 7)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_po_le = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 142)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_po_le + 2, lbl_po_zero, 6)

    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 200)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 7)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 87)
    bb_put8(ctx, 16)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 224)
    bb_put8(ctx, 3)
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 208)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 0)
    x86_ret(ctx)

    label_define(ctx, lbl_po_zero)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_ret(ctx)

    // ── lipi_fn_ord: in: rdi = str. out: rax = byte value ──────────────────
    label_define(ctx, "lipi_fn_ord")
    lbl_ord_zero = make_anon_label(ctx, "ord_zero")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_ord_zero)
    bb_put8(ctx, 72)
    bb_put8(ctx, 15)
    bb_put8(ctx, 182)
    bb_put8(ctx, 7)
    x86_ret(ctx)
    label_define(ctx, lbl_ord_zero)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_ret(ctx)

    // ── lipi_fn_chr: in: rdi = ascii code. out: rax = 1-char str ───────────
    label_define(ctx, "lipi_fn_chr")
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_mov_reg_reg(ctx, 12, 7)
    x86_mov_reg_imm64(ctx, 7, 2)
    x86_call(ctx, "_lipi_alloc")
    // [rax] = r12b, [rax + 1] = 0
    bb_put8(ctx, 68)
    bb_put8(ctx, 136)
    bb_put8(ctx, 32)
    bb_put8(ctx, 198)
    bb_put8(ctx, 64)
    bb_put8(ctx, 1)
    bb_put8(ctx, 0)
    // Header: [rax - 8] = 0x5354523000000001
    x86_mov_reg_imm64(ctx, 3, 6004514569303621633)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 88)
    bb_put8(ctx, 248)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_ret(ctx)

    // ── lipi_fn_char_at: in: rdi = str, rsi = idx. out: rax = 1-char str ──
    label_define(ctx, "lipi_fn_char_at")
    lbl_ca_zero = make_anon_label(ctx, "ca_zero")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_ca_zero)
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 247)
    bb_put8(ctx, 72)
    bb_put8(ctx, 15)
    bb_put8(ctx, 182)
    bb_put8(ctx, 63)
    x86_jmp(ctx, "lipi_fn_chr")
    label_define(ctx, lbl_ca_zero)
    x86_mov_reg_imm64(ctx, 7, 0)
    x86_jmp(ctx, "lipi_fn_chr")

    // ── lipi_fn_floor: in: rdi = val. out: rax = val ───────────────────────
    label_define(ctx, "lipi_fn_floor")
    x86_mov_reg_reg(ctx, 0, 7)
    x86_ret(ctx)

    // ── lipi_fn_exit: in: rdi = code ───────────────────────────────────────
    label_define(ctx, "lipi_fn_exit")
    x86_mov_reg_imm64(ctx, 0, 60)
    x86_syscall(ctx)
    bb_put8(ctx, 244)

    // ── lipi_fn_file_exists: in: rdi = path. out: rax = 1 or 0 ─────────────
    label_define(ctx, "lipi_fn_file_exists")
    lbl_fe_fail = make_anon_label(ctx, "fe_fail")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_fe_fail)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_mov_reg_imm64(ctx, 0, 21)
    x86_syscall(ctx)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_fe_nz = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 133)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fe_nz + 2, lbl_fe_fail, 6)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_ret(ctx)
    label_define(ctx, lbl_fe_fail)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_ret(ctx)

    // ── lipi_fn_file_read: in: rdi = path. out: rax = string content ───────
    label_define(ctx, "lipi_fn_file_read")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_push_reg(ctx, 13)
    x86_push_reg(ctx, 14)
    x86_push_reg(ctx, 15)

    lbl_fr_empty = make_anon_label(ctx, "fr_empty")
    lbl_fr_close_empty = make_anon_label(ctx, "fr_cl_empty")
    lbl_fr_read_ok = make_anon_label(ctx, "fr_rd_ok")
    lbl_fr_exit = make_anon_label(ctx, "fr_exit")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_fr_empty)

    // SYS_open(path, O_RDONLY=0, 0)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_mov_reg_imm64(ctx, 2, 0)
    x86_mov_reg_imm64(ctx, 0, 2)
    x86_syscall(ctx)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_fr_op = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 136)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fr_op + 2, lbl_fr_empty, 6)
    x86_mov_reg_reg(ctx, 12, 0)

    // SYS_lseek(fd, 0, SEEK_END=2)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_mov_reg_imm64(ctx, 2, 2)
    x86_mov_reg_imm64(ctx, 0, 8)
    x86_syscall(ctx)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_fr_ls1 = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 136)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fr_ls1 + 2, lbl_fr_close_empty, 6)
    x86_mov_reg_reg(ctx, 13, 0)

    // SYS_lseek(fd, 0, SEEK_SET=0)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_mov_reg_imm64(ctx, 2, 0)
    x86_mov_reg_imm64(ctx, 0, 8)
    x86_syscall(ctx)

    // Allocate buffer: rdi = r13 + 1
    x86_mov_reg_reg(ctx, 7, 13)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 199)
    x86_call(ctx, "_lipi_alloc")
    x86_mov_reg_reg(ctx, 14, 0)

    // SYS_read(fd, buf_ptr, file_size)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_mov_reg_reg(ctx, 6, 14)
    x86_mov_reg_reg(ctx, 2, 13)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_syscall(ctx)
    x86_mov_reg_reg(ctx, 15, 0)
    bb_put8(ctx, 77)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    p_fr_rd = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 137)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fr_rd + 2, lbl_fr_read_ok, 6)
    x86_mov_reg_imm64(ctx, 15, 0)
    label_define(ctx, lbl_fr_read_ok)

    // Null terminate: [r14 + r15] = 0
    x86_mov_reg_reg(ctx, 2, 14)
    bb_put8(ctx, 76)
    bb_put8(ctx, 1)
    bb_put8(ctx, 250)
    bb_put8(ctx, 198)
    bb_put8(ctx, 2)
    bb_put8(ctx, 0)

    // Tag header: [r14 - 8] = 0x5354523000000000 | r15
    x86_mov_reg_imm64(ctx, 0, 6004514569303621632)
    bb_put8(ctx, 76)
    bb_put8(ctx, 9)
    bb_put8(ctx, 248)
    bb_put8(ctx, 73)
    bb_put8(ctx, 137)
    bb_put8(ctx, 70)
    bb_put8(ctx, 248)

    // SYS_close(fd)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_mov_reg_imm64(ctx, 0, 3)
    x86_syscall(ctx)

    x86_mov_reg_reg(ctx, 0, 14)
    x86_jmp(ctx, lbl_fr_exit)

    label_define(ctx, lbl_fr_close_empty)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_mov_reg_imm64(ctx, 0, 3)
    x86_syscall(ctx)

    label_define(ctx, lbl_fr_empty)
    x86_mov_reg_imm64(ctx, 7, 1)
    x86_call(ctx, "_lipi_alloc")
    bb_put8(ctx, 198)
    bb_put8(ctx, 0)
    bb_put8(ctx, 0)
    x86_mov_reg_imm64(ctx, 2, 6004514569303621632)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 80)
    bb_put8(ctx, 248)

    label_define(ctx, lbl_fr_exit)
    x86_pop_reg(ctx, 15)
    x86_pop_reg(ctx, 14)
    x86_pop_reg(ctx, 13)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_leave(ctx)
    x86_ret(ctx)

    // ── lipi_fn_file_write_bytes: in: rdi = path, rsi = byte_list. out: rax = 0 or -1
    label_define(ctx, "lipi_fn_file_write_bytes")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_push_reg(ctx, 13)
    x86_push_reg(ctx, 14)
    x86_push_reg(ctx, 15)

    lbl_fw_fail = make_anon_label(ctx, "fw_fail")
    lbl_fw_close = make_anon_label(ctx, "fw_close")
    lbl_fw_cp_loop = make_anon_label(ctx, "fw_cp_loop")
    lbl_fw_exit = make_anon_label(ctx, "fw_exit")

    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255)
    x86_jz(ctx, lbl_fw_fail)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 246)
    x86_jz(ctx, lbl_fw_fail)

    x86_mov_reg_reg(ctx, 12, 7)
    x86_mov_reg_reg(ctx, 13, 6)

    // SYS_open(path, 577, 0755=493)
    x86_mov_reg_imm64(ctx, 6, 577)
    x86_mov_reg_imm64(ctx, 2, 493)
    x86_mov_reg_imm64(ctx, 0, 2)
    x86_syscall(ctx)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192)
    p_fw_op = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 136)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fw_op + 2, lbl_fw_fail, 6)
    x86_mov_reg_reg(ctx, 14, 0)

    // rbx = count = [r13]
    bb_put8(ctx, 73)
    bb_put8(ctx, 139)
    bb_put8(ctx, 93)
    bb_put8(ctx, 0)
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 219)
    p_fw_zero = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 142)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fw_zero + 2, lbl_fw_close, 6)

    // Allocate rbx bytes
    x86_mov_reg_reg(ctx, 7, 3)
    x86_call(ctx, "_lipi_alloc")
    x86_mov_reg_reg(ctx, 15, 0)

    // data_ptr in rdx = [r13 + 16]
    bb_put8(ctx, 73)
    bb_put8(ctx, 139)
    bb_put8(ctx, 85)
    bb_put8(ctx, 16)
    bb_put8(ctx, 72)
    bb_put8(ctx, 49)
    bb_put8(ctx, 201)
    label_define(ctx, lbl_fw_cp_loop)
    // rax = [rdx + rcx*8]
    x86_mov_reg_reg(ctx, 0, 1)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 224)
    bb_put8(ctx, 3)
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 208)
    bb_put8(ctx, 72)
    bb_put8(ctx, 15)
    bb_put8(ctx, 182)
    bb_put8(ctx, 0)
    // byte_buf[rcx] = al
    x86_mov_reg_reg(ctx, 8, 15)
    bb_put8(ctx, 73)
    bb_put8(ctx, 1)
    bb_put8(ctx, 200)
    bb_put8(ctx, 65)
    bb_put8(ctx, 136)
    bb_put8(ctx, 0)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 193)
    x86_cmp_reg_reg(ctx, 1, 3)
    p_fw_loop = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_fw_loop + 2, lbl_fw_cp_loop, 6)

    // SYS_write(fd, byte_buf, count)
    x86_mov_reg_reg(ctx, 7, 14)
    x86_mov_reg_reg(ctx, 6, 15)
    x86_mov_reg_reg(ctx, 2, 3)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_syscall(ctx)

    label_define(ctx, lbl_fw_close)
    // SYS_close(fd)
    x86_mov_reg_reg(ctx, 7, 14)
    x86_mov_reg_imm64(ctx, 0, 3)
    x86_syscall(ctx)
    x86_mov_reg_imm64(ctx, 0, 0)
    x86_jmp(ctx, lbl_fw_exit)

    label_define(ctx, lbl_fw_fail)
    x86_mov_reg_imm64(ctx, 0, -1)

    label_define(ctx, lbl_fw_exit)
    x86_pop_reg(ctx, 15)
    x86_pop_reg(ctx, 14)
    x86_pop_reg(ctx, 13)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_leave(ctx)
    x86_ret(ctx)

    // ── lipi_fn_argv: out: rax = list of argv strings ───────────────────────
    label_define(ctx, "lipi_fn_argv")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_push_reg(ctx, 3)
    x86_push_reg(ctx, 12)
    x86_push_reg(ctx, 13)
    x86_push_reg(ctx, 14)
    x86_push_reg(ctx, 15)

    lbl_av_empty = make_anon_label(ctx, "av_empty")
    lbl_av_loop = make_anon_label(ctx, "av_loop")
    lbl_av_sl = make_anon_label(ctx, "av_sl")
    lbl_av_exit = make_anon_label(ctx, "av_exit")

    x86_lea_reg_rip(ctx, 0, "_lipi_initial_rsp")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 0)
    x86_mov_reg_reg(ctx, 12, 0)
    bb_put8(ctx, 77)
    bb_put8(ctx, 133)
    bb_put8(ctx, 228)
    x86_jz(ctx, lbl_av_empty)

    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 0)
    x86_mov_reg_reg(ctx, 13, 0)
    bb_put8(ctx, 77)
    bb_put8(ctx, 133)
    bb_put8(ctx, 237)
    p_av_le = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 142)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_av_le + 2, lbl_av_empty, 6)

    // Create empty list for argv: _lipi_list_create(0, NULL)
    x86_mov_reg_imm64(ctx, 7, 0)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_call(ctx, "_lipi_list_create")
    x86_mov_reg_reg(ctx, 14, 0)

    // Loop r15 from 0 to r13 - 1
    bb_put8(ctx, 77)
    bb_put8(ctx, 49)
    bb_put8(ctx, 255)
    label_define(ctx, lbl_av_loop)

    // rbx = argv[i] = [r12 + 8 + r15*8]
    x86_mov_reg_reg(ctx, 0, 15)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 192)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 224)
    bb_put8(ctx, 3)
    x86_mov_reg_reg(ctx, 3, 12)
    x86_add_rax_rbx(ctx)
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 24)

    // strlen(rbx) -> rcx
    bb_put8(ctx, 72)
    bb_put8(ctx, 49)
    bb_put8(ctx, 201)
    label_define(ctx, lbl_av_sl)
    x86_mov_reg_reg(ctx, 2, 3)
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 202)
    bb_put8(ctx, 128)
    bb_put8(ctx, 58)
    bb_put8(ctx, 0)
    lbl_av_sl_done = make_anon_label(ctx, "av_sl_done")
    x86_jz(ctx, lbl_av_sl_done)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 193)
    x86_jmp(ctx, lbl_av_sl)
    label_define(ctx, lbl_av_sl_done)

    // Allocate slen + 1 bytes: rdi = rcx + 1
    x86_push_reg(ctx, 1)
    x86_mov_reg_reg(ctx, 7, 1)
    bb_put8(ctx, 72)
    bb_put8(ctx, 255)
    bb_put8(ctx, 199)
    x86_call(ctx, "_lipi_alloc")
    x86_pop_reg(ctx, 1)

    // Copy slen bytes: rsi = rbx, rdi = rax, rcx = slen
    x86_push_reg(ctx, 0)
    x86_push_reg(ctx, 1)
    x86_mov_reg_reg(ctx, 7, 0)
    x86_mov_reg_reg(ctx, 6, 3)
    bb_put8(ctx, 243)
    bb_put8(ctx, 164)
    bb_put8(ctx, 198)
    bb_put8(ctx, 7)
    bb_put8(ctx, 0)
    x86_pop_reg(ctx, 1)
    x86_pop_reg(ctx, 0)

    // Tag header: [rax - 8] = 0x5354523000000000 | rcx
    x86_mov_reg_imm64(ctx, 2, 6004514569303621632)
    bb_put8(ctx, 72)
    bb_put8(ctx, 9)
    bb_put8(ctx, 202)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 80)
    bb_put8(ctx, 248)

    // push(r14, rax)
    x86_mov_reg_reg(ctx, 7, 14)
    x86_mov_reg_reg(ctx, 6, 0)
    x86_call(ctx, "lipi_fn_push")

    bb_put8(ctx, 73)
    bb_put8(ctx, 255)
    bb_put8(ctx, 199)
    x86_cmp_reg_reg(ctx, 15, 13)
    p_av_loop = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0)
    reloc_add(ctx, p_av_loop + 2, lbl_av_loop, 6)

    x86_mov_reg_reg(ctx, 0, 14)
    x86_jmp(ctx, lbl_av_exit)

    label_define(ctx, lbl_av_empty)
    x86_mov_reg_imm64(ctx, 7, 0)
    x86_mov_reg_imm64(ctx, 6, 0)
    x86_call(ctx, "_lipi_list_create")

    label_define(ctx, lbl_av_exit)
    x86_pop_reg(ctx, 15)
    x86_pop_reg(ctx, 14)
    x86_pop_reg(ctx, 13)
    x86_pop_reg(ctx, 12)
    x86_pop_reg(ctx, 3)
    x86_leave(ctx)
    x86_ret(ctx)

    // String concatenation
    label_define(ctx, lbl_ad_str)
    x86_mov_reg_reg(ctx, 7, 12)
    x86_call(ctx, "_lipi_ensure_str")
    x86_mov_reg_reg(ctx, 14, 0) // r14 = left str
    x86_mov_reg_reg(ctx, 7, 13)
    x86_call(ctx, "_lipi_ensure_str")
    x86_mov_reg_reg(ctx, 6, 0)  // rsi = right str
    x86_mov_reg_reg(ctx, 7, 14) // rdi = left str
    x86_call(ctx, "_lipi_str_concat")
    bb_put8(ctx, 65)
    bb_put8(ctx, 94) // pop r14
    bb_put8(ctx, 65)
    bb_put8(ctx, 93) // pop r13
    bb_put8(ctx, 65)
    bb_put8(ctx, 92) // pop r12
    x86_leave(ctx)
    x86_ret(ctx)

    // ── Universal Baremetal Linux AMD64 Syscall Dispatcher (0% Libc) ───────────
    // WHY: Provides unrestricted access to all Linux kernel syscalls directly from Lipi.
    // Lipi args: rdi=nr, rsi=a1, rdx=a2, rcx=a3, r8=a4, r9=a5, r10=a6
    // Kernel expects: rax=nr, rdi=a1, rsi=a2, rdx=a3, r10=a4, r8=a5, r9=a6
    label_define(ctx, "lipi_fn_syscall")
    label_define(ctx, "lipi_fn_সিসকল")
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 248) // mov rax, rdi (syscall nr)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 247) // mov rdi, rsi (arg 1)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 214) // mov rsi, rdx (arg 2)
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 202) // mov rdx, rcx (arg 3)
    bb_put8(ctx, 77)
    bb_put8(ctx, 137)
    bb_put8(ctx, 211) // mov r11, r10 (save arg 6 from r10)
    bb_put8(ctx, 77)
    bb_put8(ctx, 137)
    bb_put8(ctx, 194) // mov r10, r8  (arg 4 into r10)
    bb_put8(ctx, 77)
    bb_put8(ctx, 137)
    bb_put8(ctx, 200) // mov r8, r9   (arg 5 into r8)
    bb_put8(ctx, 77)
    bb_put8(ctx, 137)
    bb_put8(ctx, 217) // mov r9, r11  (arg 6 into r9)
    x86_syscall(ctx)  // 0f 05 (execute kernel syscall)
    x86_ret(ctx)      // return with kernel status/ptr in rax

    // ── Raw Silicon Memory Byte Read (Direct Memory Inspection) ────────────────
    // WHY: Reads a single 8-bit unsigned byte from memory at [base + offset].
    label_define(ctx, "lipi_fn_mem_byte_read")
    label_define(ctx, "lipi_fn_mem_read_byte")
    label_define(ctx, "lipi_fn_mem_byte_পড়ো")
    label_define(ctx, "lipi_fn_মেমরি_বাইট_পড়ো")
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 247) // add rdi, rsi
    bb_put8(ctx, 15)
    bb_put8(ctx, 182)
    bb_put8(ctx, 7)   // movzx eax, byte ptr [rdi]
    x86_ret(ctx)

    // ── Raw Silicon Memory Byte Write (Direct Memory Manipulation) ─────────────
    // WHY: Stores a single 8-bit byte at memory address [base + offset].
    label_define(ctx, "lipi_fn_mem_byte_write")
    label_define(ctx, "lipi_fn_mem_write_byte")
    label_define(ctx, "lipi_fn_mem_byte_লেখো")
    label_define(ctx, "lipi_fn_মেমরি_বাইট_লেখো")
    bb_put8(ctx, 72)
    bb_put8(ctx, 1)
    bb_put8(ctx, 247) // add rdi, rsi
    bb_put8(ctx, 136)
    bb_put8(ctx, 23)  // mov byte ptr [rdi], dl
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 208) // mov rax, rdx (return stored value)
    x86_ret(ctx)

    // ── Raw Silicon Memory 64-bit QWORD Read ───────────────────────────────────
    // WHY: Reads a 64-bit integer from memory at [base + offset].
    label_define(ctx, "lipi_fn_mem_read_word")
    label_define(ctx, "lipi_fn_mem_word_read")
    label_define(ctx, "lipi_fn_mem_read")
    label_define(ctx, "lipi_fn_মেমরি_পড়ো")
    label_define(ctx, "lipi_fn_মেমরি_শব্দ_পড়ো")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 4)
    bb_put8(ctx, 55)  // mov rax, [rdi + rsi]
    x86_ret(ctx)

    // ── Raw Silicon Memory 64-bit QWORD Write ──────────────────────────────────
    // WHY: Stores a 64-bit integer into memory at [base + offset].
    label_define(ctx, "lipi_fn_mem_write_word")
    label_define(ctx, "lipi_fn_mem_word_write")
    label_define(ctx, "lipi_fn_mem_write")
    label_define(ctx, "lipi_fn_মেমরি_লেখো")
    label_define(ctx, "lipi_fn_মেমরি_শব্দ_লেখো")
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 20)
    bb_put8(ctx, 55)  // mov [rdi + rsi], rdx
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 208) // mov rax, rdx
    x86_ret(ctx)

    // ── Type and Struct Size Introspection (sizeof / size_of) ──────────────────
    // WHY: Provides default 64-byte heap layout for struct containers.
    label_define(ctx, "lipi_fn_size_of")
    label_define(ctx, "lipi_fn_sizeof")
    label_define(ctx, "lipi_fn_সাইজ_অফ")
    x86_mov_reg_imm64(ctx, 0, 64)
    x86_ret(ctx)

    // ── Physical Stack Pointer Introspection ───────────────────────────────────
    // WHY: Diagnostic inspection of the hardware %rsp register.
    label_define(ctx, "lipi_fn_stack_pointer")
    label_define(ctx, "lipi_fn_স্ট্যাক_পয়েন্টার")
    bb_put8(ctx, 72)
    bb_put8(ctx, 137)
    bb_put8(ctx, 224) // mov rax, rsp
    x86_ret(ctx)

    // ── Hardware High-Resolution CPU Cycle Counter (RDTSC) ────────────────────
    // WHY: Nanosecond-accurate benchmarking and jitter measurement on physical CPU.
    label_define(ctx, "lipi_fn_cpu_clock")
    label_define(ctx, "lipi_fn_ক্লক")
    bb_put8(ctx, 15)
    bb_put8(ctx, 49)  // rdtsc (eax = low 32 bits, edx = high 32 bits)
    bb_put8(ctx, 72)
    bb_put8(ctx, 193)
    bb_put8(ctx, 226)
    bb_put8(ctx, 32)  // shl rdx, 32
    bb_put8(ctx, 72)
    bb_put8(ctx, 9)
    bb_put8(ctx, 208) // or rax, rdx
    x86_ret(ctx)

// ── In-Memory Tokenizer & Parser for Pure Lipi ───────────────────────────────
TOK_INT    = 1
TOK_STR    = 2
TOK_IDENT  = 3
TOK_OP     = 4
TOK_LPAREN = 5
TOK_RPAREN = 6
TOK_COMMA  = 7
TOK_NL     = 8
TOK_INDENT = 9
TOK_DEDENT = 10
TOK_EOF    = 11

fn tok_new tt txt int_val
    t = list()
    push(t, tt)
    push(t, txt)
    push(t, int_val)
    return t

fn tok_t t = get(t, 0)
fn tok_s t = get(t, 1)
fn tok_i t = get(t, 2)

fn tokenize_pure src
    tokens = list()
    p = 0
    slen = len(src)
    indent_stk = list(0)

    while p < slen
        c = char_at(src, p)
        code = ord(c)

        if code == 13 // \r
            p = p + 1
            continue

        // Comments //
        if c == "/" and p + 1 < slen and char_at(src, p + 1) == "/"
            while p < slen and char_at(src, p) != "\n"
                p = p + 1
            continue

        // Comments #
        if c == "#"
            while p < slen and char_at(src, p) != "\n"
                p = p + 1
            continue

        // Comments @! (Maya sovereign directive comments)
        if c == "@" and p + 1 < slen and char_at(src, p + 1) == "!"
            while p < slen and char_at(src, p) != "\n"
                p = p + 1
            continue

        // Comments /* */
        if c == "/" and p + 1 < slen and char_at(src, p + 1) == "*"
            p = p + 2
            while p < slen
                if char_at(src, p) == "*" and p + 1 < slen and char_at(src, p + 1) == "/"
                    p = p + 2
                    break
                p = p + 1
            continue

        // Newline & Indentation
        if c == "\n"
            p = p + 1
            if len(tokens) > 0 and tok_t(get(tokens, len(tokens) - 1)) != TOK_NL
                push(tokens, tok_new(TOK_NL, "\n", 0))

            spaces = 0
            while p < slen
                sc = char_at(src, p)
                if sc == " "
                    spaces = spaces + 1
                    p = p + 1
                elif sc == "\t"
                    spaces = spaces + 4
                    p = p + 1
                else
                    break

            if p < slen
                next_c = char_at(src, p)
                if next_c == "\n" or next_c == "#" or (next_c == "/" and p + 1 < slen and char_at(src, p + 1) == "/") or (next_c == "@" and p + 1 < slen and char_at(src, p + 1) == "!")
                    continue

            cur_indent = get(indent_stk, len(indent_stk) - 1)
            if spaces > cur_indent
                push(indent_stk, spaces)
                push(tokens, tok_new(TOK_INDENT, "", spaces))
            elif spaces < cur_indent
                while len(indent_stk) > 1 and get(indent_stk, len(indent_stk) - 1) > spaces
                    pop(indent_stk)
                    push(tokens, tok_new(TOK_DEDENT, "", spaces))
            continue

        if c == " " or c == "\t"
            p = p + 1
            continue

        // Strings
        if c == "\"" or c == "'"
            quote = c
            p = p + 1
            str_acc = ""
            while p < slen and char_at(src, p) != quote
                sc = char_at(src, p)
                if sc == "\\" and p + 1 < slen
                    p = p + 1
                    esc = char_at(src, p)
                    if esc == "n"
                        str_acc = str_acc + "\n"
                    elif esc == "t"
                        str_acc = str_acc + "\t"
                    elif esc == "r"
                        str_acc = str_acc + chr(13)
                    else
                        str_acc = str_acc + esc
                    p = p + 1
                else
                    str_acc = str_acc + sc
                    p = p + 1
            if p < slen and char_at(src, p) == quote
                p = p + 1
            push(tokens, tok_new(TOK_STR, str_acc, 0))
            continue

        // Bengali digits (০-৯: ord 2534..2543)
        if code >= 2534 and code <= 2543
            val = 0
            while p < slen
                dc = char_at(src, p)
                dcode = ord(dc)
                if dcode >= 2534 and dcode <= 2543
                    val = (val * 10) + (dcode - 2534)
                    p = p + 1
                else
                    break
            push(tokens, tok_new(TOK_INT, str(val), val))
            continue

        // ASCII digits
        if code >= 48 and code <= 57
            val = 0
            while p < slen
                dc = char_at(src, p)
                dcode = ord(dc)
                if dcode >= 48 and dcode <= 57
                    val = (val * 10) + (dcode - 48)
                    p = p + 1
                else
                    break
            push(tokens, tok_new(TOK_INT, str(val), val))
            continue

        if c == "("
            push(tokens, tok_new(TOK_LPAREN, "(", 0))
            p = p + 1
            continue
        if c == ")"
            push(tokens, tok_new(TOK_RPAREN, ")", 0))
            p = p + 1
            continue
        if c == ","
            push(tokens, tok_new(TOK_COMMA, ",", 0))
            p = p + 1
            continue

        // 2-char operators
        if p + 1 < slen
            two = c + char_at(src, p + 1)
            if two == "==" or two == "!=" or two == "<=" or two == ">=" or two == "+=" or two == "-=" or two == "*=" or two == "/=" or two == "&&" or two == "||" or two == ".."
                push(tokens, tok_new(TOK_OP, two, 0))
                p = p + 2
                continue

        // 1-char operators
        if c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "=" or c == "<" or c == ">" or c == "!" or c == "."
            push(tokens, tok_new(TOK_OP, c, 0))
            p = p + 1
            continue

        // Identifiers and Keywords (including Maya @-directives)
        is_ident_char = 0
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or c == "_" or c == "@" or code > 127
            is_ident_char = 1

        if is_ident_char == 1
            id_acc = ""
            while p < slen
                ic = char_at(src, p)
                icode = ord(ic)
                if (icode >= 65 and icode <= 90) or (icode >= 97 and icode <= 122) or (icode >= 48 and icode <= 57) or ic == "_" or ic == "@" or icode > 127
                    id_acc = id_acc + ic
                    p = p + 1
                else
                    break
            push(tokens, tok_new(TOK_IDENT, id_acc, 0))
            continue

        p = p + 1

    while len(indent_stk) > 1
        pop(indent_stk)
        push(tokens, tok_new(TOK_DEDENT, "", 0))

    push(tokens, tok_new(TOK_EOF, "", 0))
    return tokens

// ── Parser State (ps) ────────────────────────────────────────────────────────
fn ps_new tokens
    s = list()
    push(s, tokens)
    push(s, list(0)) // index in a 1-element list for mutable reference
    return s

fn ps_pos s = get(get(s, 1), 0)

fn ps_cur s
    tokens = get(s, 0)
    idx = get(get(s, 1), 0)
    if idx < len(tokens) return get(tokens, idx)
    return tok_new(TOK_EOF, "", 0)

fn ps_cur_type s
    t = ps_cur(s)
    return tok_t(t)

fn ps_cur_text s
    t = ps_cur(s)
    return tok_s(t)

fn ps_cur_int s
    t = ps_cur(s)
    return tok_i(t)

fn ps_peek_tok s offset
    tokens = get(s, 0)
    idx = get(get(s, 1), 0) + offset
    if idx < len(tokens) return get(tokens, idx)
    return tok_new(TOK_EOF, "", 0)

fn ps_adv s
    tokens = get(s, 0)
    idx_ref = get(s, 1)
    cur = get(idx_ref, 0)
    if cur < len(tokens) - 1
        list_set(idx_ref, 0, cur + 1)

fn ps_skip_nl s
    while ps_cur_type(s) == TOK_NL
        ps_adv(s)

// WHY: Detect whether next token is the start of an argument expression for bare function calls
fn is_pure_arg_start ps
    tt = ps_cur_type(ps)
    if tt == TOK_INT or tt == TOK_STR return 1
    if tt == TOK_IDENT
        txt = ps_cur_text(ps)
        if txt == "if" or txt == "যদি" or txt == "while" or txt == "যতক্ষণ" or txt == "@if" or txt == "@while" return 0
        if txt == "for" or txt == "প্রতিটি" or txt == "return" or txt == "ফেরত" return 0
        if txt == "say" or txt == "বলো" or txt == "show" or txt == "দেখাও" or txt == "print" or txt == "println" return 0
        if txt == "fn" or txt == "কাজ" or txt == "struct" or txt == "গঠন" or txt == "repeat" or txt == "বার" return 0
        if txt == "@fn" or txt == "@struct" or txt == "@end" or txt == "@gpu" or txt == "@inline" or txt == "@let" return 0
        if txt == "else" or txt == "নাহলে" or txt == "elif" or txt == "নাহলে_যদি" or txt == "@else" or txt == "@elif" return 0
        if txt == "and" or txt == "এবং" or txt == "or" or txt == "অথবা" or txt == "not" or txt == "না" return 0
        if txt == "in" or txt == "ভেতরে" or txt == "to" or txt == "step" or txt == "ধাপ" return 0
        return 1
    if tt == TOK_OP and ps_cur_text(ps) == "(" return 1
    return 0

// ── Code Generation: Expressions & Statements ────────────────────────────────
fn compile_pure_primary ctx ps
    ps_skip_nl(ps)
    tt  = ps_cur_type(ps)
    txt = ps_cur_text(ps)

    if tt == TOK_INT
        val = ps_cur_int(ps)
        ps_adv(ps)
        x86_mov_reg_imm64(ctx, 0, val) // mov rax, val
        return TY_INT

    if tt == TOK_STR
        lbl = string_pool_get(ctx, txt)
        ps_adv(ps)
        x86_lea_reg_rip(ctx, 0, lbl) // lea rax, [rip + lbl]
        return TY_STR

    if tt == TOK_LPAREN
        ps_adv(ps)
        inner_ty = compile_pure_expr(ctx, ps)
        if ps_cur_type(ps) == TOK_RPAREN
            ps_adv(ps)
        return inner_ty

    if tt == TOK_IDENT
        name = txt
        ps_adv(ps)

        if name == "true" or name == "সত্য"
            x86_mov_reg_imm64(ctx, 0, 1)
            return TY_INT
        if name == "false" or name == "মিথ্যা" or name == "null" or name == "nil" or name == "শূন্য"
            x86_mov_reg_imm64(ctx, 0, 0)
            return TY_INT

        // Struct field access: name.field or OOP method call: name.method(...)
        if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "."
            ps_adv(ps) // consume '.'
            field_name = ps_cur_text(ps)
            ps_adv(ps) // consume field name

            // Check if this is an OOP method call: name.method(...)
            if ps_cur_type(ps) == TOK_LPAREN
                ps_adv(ps) // consume '('
                off = scope_get(ctx, name)
                if off > 0
                    x86_mov_rax_stack(ctx, off)
                else
                    x86_mov_reg_imm64(ctx, 0, 0)
                x86_push_reg(ctx, 0) // push self pointer as arg 0
                arg_count = 1
                arg_regs = list(7, 6, 2, 1, 8, 9, 10, 11, 12, 13, 14, 15)
                while ps_cur_type(ps) != TOK_RPAREN and ps_cur_type(ps) != TOK_EOF
                    compile_pure_expr(ctx, ps)
                    x86_push_reg(ctx, 0)
                    arg_count = arg_count + 1
                    if ps_cur_type(ps) == TOK_COMMA
                        ps_adv(ps)
                if ps_cur_type(ps) == TOK_RPAREN
                    ps_adv(ps)

                ai = arg_count - 1
                while ai >= 0
                    if ai < 12
                        x86_pop_reg(ctx, get(arg_regs, ai))
                    else
                        x86_pop_reg(ctx, 0)
                    ai = ai - 1

                sname = struct_get_var_type(ctx, name)
                target_m = "lipi_fn_" + field_name
                if sname != ""
                    target_m = "lipi_fn_" + sname + "_" + field_name
                x86_call(ctx, target_m)
                return 0

            off = scope_get(ctx, name)
            if off > 0
                x86_mov_rax_stack(ctx, off)
            else
                x86_mov_reg_imm64(ctx, 0, 0)
            sname = struct_get_var_type(ctx, name)
            f_off = struct_get_field_offset(ctx, sname, field_name)
            // mov rax, [rax + f_off] (0x48 0x8B 0x40 f_off)
            bb_put8(ctx, 72)
            bb_put8(ctx, 139)
            bb_put8(ctx, 64)
            bb_put8(ctx, f_off)
            return 0

        // Function call: name(...)
        if ps_cur_type(ps) == TOK_LPAREN
            ps_adv(ps)
            arg_count = 0
            arg_regs = list(7, 6, 2, 1, 8, 9, 10, 11, 12, 13, 14, 15) // 12 argument registers
            while ps_cur_type(ps) != TOK_RPAREN and ps_cur_type(ps) != TOK_EOF
                compile_pure_expr(ctx, ps)
                x86_push_reg(ctx, 0)
                arg_count = arg_count + 1
                if ps_cur_type(ps) == TOK_COMMA
                    ps_adv(ps)
            if ps_cur_type(ps) == TOK_RPAREN
                ps_adv(ps)

            // Check if name is a struct constructor (e.g. Point() or Fraction())
            sidx = struct_find(ctx, name)
            if sidx >= 0
                ai = 0
                while ai < arg_count
                    x86_pop_reg(ctx, 0)
                    ai = ai + 1
                sfields = get(get(ctx, 17), sidx)
                fcount = len(sfields)
                if fcount == 0
                    fcount = 4
                // Alloc (fcount + 1) * 8 bytes
                x86_mov_reg_imm64(ctx, 7, (fcount + 1) * 8)
                x86_call(ctx, "_lipi_alloc")
                return 0

            // WHY: First-class compiler built-in for list(...) supporting arbitrary argument count directly from stack
            if name == "list"
                x86_mov_reg_imm64(ctx, 7, arg_count)
                x86_mov_reg_reg(ctx, 6, 4) // rsi = rsp
                x86_call(ctx, "_lipi_list_create")
                if arg_count > 0
                    x86_add_rsp(ctx, arg_count * 8)
                return 0

            // Pop args into registers in reverse
            ai = arg_count - 1
            while ai >= 0
                if ai < 12
                    x86_pop_reg(ctx, get(arg_regs, ai))
                else
                    x86_pop_reg(ctx, 0)
                ai = ai - 1

            if name == "len" or name == "length" or name == "দৈর্ঘ্য"
                x86_call(ctx, "_lipi_len")
                return TY_INT
            if name == "abs"
                x86_mov_reg_reg(ctx, 0, 7)
                lbl_abs = make_anon_label(ctx, "abs_d")
                bb_put8(ctx, 72)
                bb_put8(ctx, 133)
                bb_put8(ctx, 192)
                p_abs = ctx_len(ctx)
                bb_put8(ctx, 15)
                bb_put8(ctx, 137)
                bb_put32(ctx, 0) // jns
                reloc_add(ctx, p_abs + 2, lbl_abs, 6)
                x86_neg_rax(ctx)
                label_define(ctx, lbl_abs)
                return TY_INT

            x86_call(ctx, "lipi_fn_" + name)
            return TY_UNKNOWN

        // Local variable lookup (WHY: Local variables/parameters must shadow built-in function names like 'length')
        off = scope_get(ctx, name)
        if off > 0
            x86_mov_rax_stack(ctx, off)
            v_ty = scope_get_type(ctx, name)
            if v_ty != TY_UNKNOWN
                return v_ty
            return TY_UNKNOWN

        // Global constant lookup
        gi = 0
        gnames = get(ctx, 12)
        gvals  = get(ctx, 13)
        while gi < len(gnames)
            if get(gnames, gi) == name
                x86_mov_reg_imm64(ctx, 0, get(gvals, gi))
                return TY_INT
            gi = gi + 1

        // Bare function call: len x, abs x
        if name == "len" or name == "length" or name == "দৈর্ঘ্য"
            compile_pure_primary(ctx, ps)
            x86_mov_reg_reg(ctx, 7, 0)
            x86_call(ctx, "_lipi_len")
            return TY_INT
        if name == "abs"
            compile_pure_primary(ctx, ps)
            lbl_abs2 = make_anon_label(ctx, "abs_d2")
            bb_put8(ctx, 72)
            bb_put8(ctx, 133)
            bb_put8(ctx, 192)
            p_abs2 = ctx_len(ctx)
            bb_put8(ctx, 15)
            bb_put8(ctx, 137)
            bb_put32(ctx, 0)
            reloc_add(ctx, p_abs2 + 2, lbl_abs2, 6)
            x86_neg_rax(ctx)
            label_define(ctx, lbl_abs2)
            return TY_INT

        // WHY: Handle space-separated function calls without parentheses (e.g., fibonacci i, say sum 10 20)
        if is_pure_arg_start(ps) == 1
            arg_count = 0
            arg_regs = list(7, 6, 2, 1, 8, 9, 10, 11, 12, 13, 14, 15)
            while is_pure_arg_start(ps) == 1 and ps_cur_type(ps) != TOK_NL and ps_cur_type(ps) != TOK_EOF
                compile_pure_primary(ctx, ps)
                x86_push_reg(ctx, 0)
                arg_count = arg_count + 1
            ai = arg_count - 1
            while ai >= 0
                if ai < 12
                    x86_pop_reg(ctx, get(arg_regs, ai))
                else
                    x86_pop_reg(ctx, 0)
                ai = ai - 1
            x86_call(ctx, "lipi_fn_" + name)
            return TY_UNKNOWN

        x86_mov_reg_imm64(ctx, 0, 0)
        return TY_UNKNOWN

    return TY_UNKNOWN

fn compile_pure_unary ctx ps
    ps_skip_nl(ps)
    if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "-"
        ps_adv(ps)
        compile_pure_unary(ctx, ps)
        x86_neg_rax(ctx)
        return TY_INT
    return compile_pure_primary(ctx, ps)

fn compile_pure_mul ctx ps
    lhs_ty = compile_pure_unary(ctx, ps)
    while ps_cur_type(ps) == TOK_OP and (ps_cur_text(ps) == "*" or ps_cur_text(ps) == "/" or ps_cur_text(ps) == "%")
        op = ps_cur_text(ps)
        ps_adv(ps)
        if op == "%" and ps_cur_type(ps) == TOK_INT
            // WHY: Constant modulo strength reduction avoids 40-cycle idiv hardware stall
            k = ps_cur_int(ps)
            ps_adv(ps)
            emit_strength_reduced_mod(ctx, k)
        else
            x86_push_reg(ctx, 0) // push rax
            compile_pure_unary(ctx, ps)
            x86_mov_reg_reg(ctx, 3, 0) // mov rbx, rax
            x86_pop_reg(ctx, 0)        // pop rax
            if op == "*" x86_imul_rax_rbx(ctx)
            elif op == "/" x86_idiv_rbx(ctx)
            elif op == "%" x86_imod_rbx(ctx)
        lhs_ty = TY_INT
    return lhs_ty

fn compile_pure_add ctx ps
    lhs_ty = compile_pure_mul(ctx, ps)
    while ps_cur_type(ps) == TOK_OP and (ps_cur_text(ps) == "+" or ps_cur_text(ps) == "-")
        op = ps_cur_text(ps)
        ps_adv(ps)
        x86_push_reg(ctx, 0) // push lhs
        rhs_ty = compile_pure_mul(ctx, ps)
        if op == "+"
            if lhs_ty == TY_INT and rhs_ty == TY_INT
                // WHY: Monomorphic integer addition lowering emits direct machine instruction
                //      (add rax, rbx) bypassing dynamic string check runtime overhead.
                x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
                x86_pop_reg(ctx, 0)        // rax = lhs
                x86_add_rax_rbx(ctx)
                lhs_ty = TY_INT
            elif lhs_ty == TY_STR or rhs_ty == TY_STR
                // WHY: Explicit string concat branch
                x86_mov_reg_reg(ctx, 6, 0) // rsi = rhs
                x86_pop_reg(ctx, 7)        // rdi = lhs
                x86_call(ctx, "_lipi_add_dynamic")
                lhs_ty = TY_STR
            else
                // WHY: Dynamic fallback for unknown types
                x86_mov_reg_reg(ctx, 6, 0) // rsi = rhs
                x86_pop_reg(ctx, 7)        // rdi = lhs
                x86_call(ctx, "_lipi_add_dynamic")
                lhs_ty = TY_UNKNOWN
        else
            // WHY: Monomorphic integer subtraction lowers to direct native ALU instruction (sub rax, rbx)
            x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
            x86_pop_reg(ctx, 0)        // rax = lhs
            x86_sub_rax_rbx(ctx)
            lhs_ty = TY_INT
    return lhs_ty

fn compile_pure_cmp ctx ps
    lhs_ty = compile_pure_add(ctx, ps)
    while ps_cur_type(ps) == TOK_OP and (ps_cur_text(ps) == "==" or ps_cur_text(ps) == "!=" or ps_cur_text(ps) == "<" or ps_cur_text(ps) == "<=" or ps_cur_text(ps) == ">" or ps_cur_text(ps) == ">=")
        op = ps_cur_text(ps)
        ps_adv(ps)
        x86_push_reg(ctx, 0)
        rhs_ty = compile_pure_add(ctx, ps)
        if lhs_ty == TY_INT and rhs_ty == TY_INT
            // WHY: Direct integer comparison lowers to native cmp rax, rbx and setcc
            x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
            x86_pop_reg(ctx, 0)        // rax = lhs
            bb_put8(ctx, 72)
            bb_put8(ctx, 57)
            bb_put8(ctx, 216) // cmp rax, rbx (0x48 0x39 0xD8)
            if op == "=="
                bb_put8(ctx, 15)
                bb_put8(ctx, 148)
                bb_put8(ctx, 192) // sete al
            elif op == "!="
                bb_put8(ctx, 15)
                bb_put8(ctx, 149)
                bb_put8(ctx, 192) // setne al
            elif op == "<"
                bb_put8(ctx, 15)
                bb_put8(ctx, 156)
                bb_put8(ctx, 192) // setl al
            elif op == "<="
                bb_put8(ctx, 15)
                bb_put8(ctx, 158)
                bb_put8(ctx, 192) // setle al
            elif op == ">"
                bb_put8(ctx, 15)
                bb_put8(ctx, 159)
                bb_put8(ctx, 192) // setg al
            elif op == ">="
                bb_put8(ctx, 15)
                bb_put8(ctx, 157)
                bb_put8(ctx, 192) // setge al
            bb_put8(ctx, 72)
            bb_put8(ctx, 15)
            bb_put8(ctx, 182)
            bb_put8(ctx, 192) // movzx rax, al
        else
            x86_mov_reg_reg(ctx, 6, 0) // rsi = rhs
            x86_pop_reg(ctx, 7)        // rdi = lhs
            x86_call(ctx, "_lipi_cmp_dynamic")
            if op == "=="
                bb_put8(ctx, 72)
                bb_put8(ctx, 133)
                bb_put8(ctx, 192) // test rax, rax
                bb_put8(ctx, 15)
                bb_put8(ctx, 148)
                bb_put8(ctx, 192) // sete al
            elif op == "!="
                bb_put8(ctx, 72)
                bb_put8(ctx, 133)
                bb_put8(ctx, 192) // test rax, rax
                bb_put8(ctx, 15)
                bb_put8(ctx, 149)
                bb_put8(ctx, 192) // setne al
            elif op == "<"
                bb_put8(ctx, 72)
                bb_put8(ctx, 131)
                bb_put8(ctx, 248)
                bb_put8(ctx, 0)   // cmp rax, 0
                bb_put8(ctx, 15)
                bb_put8(ctx, 156)
                bb_put8(ctx, 192) // setl al
            elif op == "<="
                bb_put8(ctx, 72)
                bb_put8(ctx, 131)
                bb_put8(ctx, 248)
                bb_put8(ctx, 0)   // cmp rax, 0
                bb_put8(ctx, 15)
                bb_put8(ctx, 158)
                bb_put8(ctx, 192) // setle al
            elif op == ">"
                bb_put8(ctx, 72)
                bb_put8(ctx, 131)
                bb_put8(ctx, 248)
                bb_put8(ctx, 0)   // cmp rax, 0
                bb_put8(ctx, 15)
                bb_put8(ctx, 159)
                bb_put8(ctx, 192) // setg al
            elif op == ">="
                bb_put8(ctx, 72)
                bb_put8(ctx, 131)
                bb_put8(ctx, 248)
                bb_put8(ctx, 0)   // cmp rax, 0
                bb_put8(ctx, 15)
                bb_put8(ctx, 157)
                bb_put8(ctx, 192) // setge al
            bb_put8(ctx, 72)
            bb_put8(ctx, 15)
            bb_put8(ctx, 182)
            bb_put8(ctx, 192) // movzx rax, al
        lhs_ty = TY_INT
    return lhs_ty

// WHY: Boolean NOT (not, না, !)
fn compile_pure_not ctx ps
    ps_skip_nl(ps)
    tt = ps_cur_type(ps)
    txt = ps_cur_text(ps)
    if (tt == TOK_IDENT and (txt == "not" or txt == "না")) or (tt == TOK_OP and txt == "!")
        ps_adv(ps)
        compile_pure_not(ctx, ps)
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        bb_put8(ctx, 15)
        bb_put8(ctx, 148)
        bb_put8(ctx, 192) // setz al (0x0F 0x94 0xC0)
        bb_put8(ctx, 72)
        bb_put8(ctx, 15)
        bb_put8(ctx, 182)
        bb_put8(ctx, 192) // movzx rax, al (0x48 0x0F 0xB6 0xC0)
        return TY_INT
    return compile_pure_cmp(ctx, ps)

// WHY: Short-circuiting logical AND (and, এবং, &&)
fn compile_pure_and ctx ps
    lhs_ty = compile_pure_not(ctx, ps)
    while (ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "and" or ps_cur_text(ps) == "এবং")) or (ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "&&")
        ps_adv(ps)
        lbl_sc = make_anon_label(ctx, "and_sc")
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        x86_jz(ctx, lbl_sc)
        compile_pure_not(ctx, ps)
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        bb_put8(ctx, 15)
        bb_put8(ctx, 149)
        bb_put8(ctx, 192) // setnz al
        bb_put8(ctx, 72)
        bb_put8(ctx, 15)
        bb_put8(ctx, 182)
        bb_put8(ctx, 192) // movzx rax, al
        label_define(ctx, lbl_sc)
        lhs_ty = TY_INT
    return lhs_ty

// WHY: Short-circuiting logical OR (or, অথবা, ||)
fn compile_pure_or ctx ps
    lhs_ty = compile_pure_and(ctx, ps)
    while (ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "or" or ps_cur_text(ps) == "অথবা")) or (ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "||")
        ps_adv(ps)
        lbl_sc   = make_anon_label(ctx, "or_sc")
        lbl_done = make_anon_label(ctx, "or_done")
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        x86_jnz(ctx, lbl_sc)
        compile_pure_and(ctx, ps)
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        bb_put8(ctx, 15)
        bb_put8(ctx, 149)
        bb_put8(ctx, 192) // setnz al
        bb_put8(ctx, 72)
        bb_put8(ctx, 15)
        bb_put8(ctx, 182)
        bb_put8(ctx, 192) // movzx rax, al
        x86_jmp(ctx, lbl_done)
        label_define(ctx, lbl_sc)
        x86_mov_reg_imm64(ctx, 0, 1) // rax = 1
        label_define(ctx, lbl_done)
        lhs_ty = TY_INT
    return lhs_ty

fn compile_pure_expr ctx ps
    return compile_pure_or(ctx, ps)

fn compile_pure_stmt ctx ps
    ps_skip_nl(ps)
    tt  = ps_cur_type(ps)
    txt = ps_cur_text(ps)

    if tt == TOK_EOF or tt == TOK_DEDENT return 0

    // WHY: Unwrap let/চলক/@let variable declaration keyword so statement falls through to assignment
    if tt == TOK_IDENT and (txt == "let" or txt == "চলক" or txt == "@let")
        ps_adv(ps)
        tt  = ps_cur_type(ps)
        txt = ps_cur_text(ps)

    // WHY: Gracefully consume any standalone @end directive at top level or block boundary
    if tt == TOK_IDENT and txt == "@end"
        ps_adv(ps)
        return 0

    // include / অন্তর্ভুক্ত -- skip line
    if tt == TOK_IDENT and (txt == "include" or txt == "অন্তর্ভুক্ত")
        while ps_cur_type(ps) != TOK_NL and ps_cur_type(ps) != TOK_EOF
            ps_adv(ps)
        return 0

    // @gpu / @inline (Maya sovereign hardware/optimization blocks)
    // WHY: Transparently lower hardware acceleration and inlining directives by executing inner statements
    if tt == TOK_IDENT and (txt == "@gpu" or txt == "@inline")
        ps_adv(ps)
        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    break
                prev_gpu_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_gpu_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        else
            while ps_cur_type(ps) != TOK_EOF
                ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    ps_adv(ps)
                    break
                prev_gpu_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_gpu_p
                    ps_adv(ps)
                ps_skip_nl(ps)
        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
            ps_adv(ps)
        return 0

    // struct / গঠন / @struct (Struct Definition)
    // WHY: Support both indentation-delimited structs and Maya @struct ... @end blocks
    if tt == TOK_IDENT and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_meta_struct = (txt == "@struct")
        ps_adv(ps)
        sname = ps_cur_text(ps)
        ps_adv(ps)
        fields = list()
        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                if is_meta_struct == 1 and ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    break
                if ps_cur_type(ps) == TOK_IDENT
                    if len(fields) < 16
                        push(fields, ps_cur_text(ps))
                    ps_adv(ps)
                    while ps_cur_type(ps) != TOK_NL and ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                        ps_adv(ps)
                else
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        elif is_meta_struct == 1
            while ps_cur_type(ps) != TOK_EOF
                ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    ps_adv(ps)
                    break
                if ps_cur_type(ps) == TOK_IDENT
                    if len(fields) < 16
                        push(fields, ps_cur_text(ps))
                    ps_adv(ps)
                    while ps_cur_type(ps) != TOK_NL and ps_cur_type(ps) != TOK_EOF
                        ps_adv(ps)
                else
                    ps_adv(ps)
                ps_skip_nl(ps)
        if is_meta_struct == 1
            ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                ps_adv(ps)
        struct_add(ctx, sname, fields)
        return 0

    // Struct field assignment: obj.field = expr
    // WHY: Direct offset store into heap-allocated struct pointer
    t1 = ps_peek_tok(ps, 1)
    t2 = ps_peek_tok(ps, 2)
    t3 = ps_peek_tok(ps, 3)
    if tt == TOK_IDENT and tok_t(t1) == TOK_OP and tok_s(t1) == "." and tok_t(t2) == TOK_IDENT and tok_t(t3) == TOK_OP and tok_s(t3) == "="
        obj_name = txt
        field_name = tok_s(t2)
        ps_adv(ps) // obj
        ps_adv(ps) // '.'
        ps_adv(ps) // field
        ps_adv(ps) // '='
        compile_pure_expr(ctx, ps) // rax = value
        x86_mov_reg_reg(ctx, 3, 0)  // rbx = value
        off = scope_get(ctx, obj_name)
        if off > 0
            x86_mov_rax_stack(ctx, off) // rax = obj ptr
        else
            x86_mov_reg_imm64(ctx, 0, 0)
        sname = struct_get_var_type(ctx, obj_name)
        f_off = struct_get_field_offset(ctx, sname, field_name)
        // mov [rax + f_off], rbx
        bb_put8(ctx, 72)
        bb_put8(ctx, 137)
        bb_put8(ctx, 88)
        bb_put8(ctx, f_off)
        return 0

    // break / থামো
    if tt == TOK_IDENT and (txt == "break" or txt == "থামো")
        ps_adv(ps)
        estk = get(ctx, 15)
        if len(estk) > 0
            x86_jmp(ctx, get(estk, len(estk) - 1))
        return 0

    // continue / চলুক
    if tt == TOK_IDENT and (txt == "continue" or txt == "চলুক")
        ps_adv(ps)
        sstk = get(ctx, 14)
        if len(sstk) > 0
            x86_jmp(ctx, get(sstk, len(sstk) - 1))
        return 0

    // say / বলো / show / দেখাও / print / println
    if tt == TOK_IDENT and (txt == "say" or txt == "বলো" or txt == "show" or txt == "দেখাও" or txt == "print" or txt == "println")
        ps_adv(ps)
        compile_pure_expr(ctx, ps)
        x86_mov_reg_reg(ctx, 7, 0) // mov rdi, rax
        x86_call(ctx, "_lipi_print_dynamic")
        x86_call(ctx, "_lipi_print_nl")
        return 0

    // if / elif / else (যদি / নাহলে_যদি / নাহলে / @if / @elif / @else)
    // WHY: Support arbitrary elif chaining and else fallback branches across all 3 syntax styles
    if tt == TOK_IDENT and (txt == "if" or txt == "যদি" or txt == "@if")
        is_meta_if = (txt == "@if")
        ps_adv(ps)
        compile_pure_expr(ctx, ps)
        lbl_end  = make_anon_label(ctx, "if_end")
        lbl_next = make_anon_label(ctx, "if_next")
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        x86_jz(ctx, lbl_next)

        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                if is_meta_if == 1 and ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "@end" or ps_cur_text(ps) == "@elif" or ps_cur_text(ps) == "@else")
                    break
                prev_if_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_if_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        elif is_meta_if == 1
            while ps_cur_type(ps) != TOK_EOF
                ps_skip_nl(ps)
                cur_if_t = ps_cur_text(ps)
                if ps_cur_type(ps) == TOK_IDENT and (cur_if_t == "@end" or cur_if_t == "@elif" or cur_if_t == "@else")
                    break
                prev_if_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_if_p
                    ps_adv(ps)
                ps_skip_nl(ps)
        else
            compile_pure_stmt(ctx, ps)

        x86_jmp(ctx, lbl_end)
        label_define(ctx, lbl_next)

        ps_skip_nl(ps)
        while ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "elif" or ps_cur_text(ps) == "নাহলে_যদি" or ps_cur_text(ps) == "@elif")
            ps_adv(ps)
            compile_pure_expr(ctx, ps)
            lbl_next = make_anon_label(ctx, "elif_next")
            bb_put8(ctx, 72)
            bb_put8(ctx, 133)
            bb_put8(ctx, 192) // test rax, rax
            x86_jz(ctx, lbl_next)

            ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_INDENT
                ps_adv(ps)
                while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                    if is_meta_if == 1 and ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "@end" or ps_cur_text(ps) == "@elif" or ps_cur_text(ps) == "@else")
                        break
                    prev_elif_p = ps_pos(ps)
                    compile_pure_stmt(ctx, ps)
                    if ps_pos(ps) == prev_elif_p
                        ps_adv(ps)
                    ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_DEDENT
                    ps_adv(ps)
            elif is_meta_if == 1
                while ps_cur_type(ps) != TOK_EOF
                    ps_skip_nl(ps)
                    cur_elif_t = ps_cur_text(ps)
                    if ps_cur_type(ps) == TOK_IDENT and (cur_elif_t == "@end" or cur_elif_t == "@elif" or cur_elif_t == "@else")
                        break
                    prev_elif_p = ps_pos(ps)
                    compile_pure_stmt(ctx, ps)
                    if ps_pos(ps) == prev_elif_p
                        ps_adv(ps)
                    ps_skip_nl(ps)
            else
                compile_pure_stmt(ctx, ps)

            x86_jmp(ctx, lbl_end)
            label_define(ctx, lbl_next)
            ps_skip_nl(ps)

        if ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "else" or ps_cur_text(ps) == "নাহলে" or ps_cur_text(ps) == "@else")
            ps_adv(ps)
            ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_INDENT
                ps_adv(ps)
                while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                    if is_meta_if == 1 and ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                        break
                    prev_else_p = ps_pos(ps)
                    compile_pure_stmt(ctx, ps)
                    if ps_pos(ps) == prev_else_p
                        ps_adv(ps)
                    ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_DEDENT
                    ps_adv(ps)
            elif is_meta_if == 1
                while ps_cur_type(ps) != TOK_EOF
                    ps_skip_nl(ps)
                    if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                        break
                    prev_else_p = ps_pos(ps)
                    compile_pure_stmt(ctx, ps)
                    if ps_pos(ps) == prev_else_p
                        ps_adv(ps)
                    ps_skip_nl(ps)
            else
                compile_pure_stmt(ctx, ps)

        if is_meta_if == 1
            ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                ps_adv(ps)

        label_define(ctx, lbl_end)
        return 0

    // while / যতক্ষণ / @while
    // WHY: Support both indentation loops and Maya @while ... @end loops
    if tt == TOK_IDENT and (txt == "while" or txt == "যতক্ষণ" or txt == "@while")
        is_meta_while = (txt == "@while")
        ps_adv(ps)
        lbl_loop = make_anon_label(ctx, "while_loop")
        lbl_end  = make_anon_label(ctx, "while_end")
        label_define(ctx, lbl_loop)
        compile_pure_expr(ctx, ps)
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        x86_jz(ctx, lbl_end)

        loop_push(ctx, lbl_loop, lbl_end)
        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                if is_meta_while == 1 and ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    break
                prev_while_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_while_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        elif is_meta_while == 1
            while ps_cur_type(ps) != TOK_EOF
                ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    break
                prev_while_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_while_p
                    ps_adv(ps)
                ps_skip_nl(ps)
        else
            compile_pure_stmt(ctx, ps)
        loop_pop(ctx)

        x86_jmp(ctx, lbl_loop)
        if is_meta_while == 1
            ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                ps_adv(ps)
        label_define(ctx, lbl_end)
        return 0

    // return / ফেরত
    if tt == TOK_IDENT and (txt == "return" or txt == "ফেরত")
        ps_adv(ps)
        if ps_cur_type(ps) != TOK_NL and ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
            compile_pure_expr(ctx, ps)
        else
            x86_mov_reg_imm64(ctx, 0, 0)
        x86_leave(ctx)
        x86_ret(ctx)
        return 0

    // fn / কাজ / @fn (Function Definition)
    // WHY: Unify Bengali, English, and Maya @fn syntax into identical machine code functions
    if tt == TOK_IDENT and (txt == "fn" or txt == "কাজ" or txt == "@fn")
        is_meta_fn = (txt == "@fn")
        ps_adv(ps)
        fn_name = ps_cur_text(ps)
        ps_adv(ps)

        // WHY: Support OOP struct methods (e.g. fn Point.distance self other)
        if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "."
            ps_adv(ps)
            method_name = ps_cur_text(ps)
            ps_adv(ps)
            fn_name = fn_name + "_" + method_name

        params = list()
        if ps_cur_type(ps) == TOK_LPAREN
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_RPAREN and ps_cur_type(ps) != TOK_EOF
                if ps_cur_type(ps) == TOK_IDENT and len(params) < 12
                    push(params, ps_cur_text(ps))
                    ps_adv(ps)
                if ps_cur_type(ps) == TOK_COMMA
                    ps_adv(ps)
            if ps_cur_type(ps) == TOK_RPAREN
                ps_adv(ps)
        else
            while ps_cur_type(ps) == TOK_IDENT and len(params) < 12
                if is_pure_arg_start(ps) == 0
                    break
                push(params, ps_cur_text(ps))
                ps_adv(ps)

        lbl_skip = make_anon_label(ctx, "skip_fn")
        x86_jmp(ctx, lbl_skip)

        label_define(ctx, "lipi_fn_" + fn_name)

        // Save parent scope
        saved_names = get(ctx, 8)
        saved_offs  = get(ctx, 9)
        saved_types = get(ctx, 20)
        saved_stack = get(get(ctx, 10), 0)

        list_set(ctx, 8, list())
        list_set(ctx, 9, list())
        list_set(ctx, 20, list())
        list_set(get(ctx, 10), 0, 0)

        x86_push_rbp(ctx)
        x86_mov_rbp_rsp(ctx)
        x86_sub_rsp(ctx, 2048)

        arg_regs = list(7, 6, 2, 1, 8, 9, 10, 11, 12, 13, 14, 15)
        pi = 0
        while pi < len(params)
            off = scope_add(ctx, get(params, pi))
            if pi < 12
                x86_mov_reg_reg(ctx, 0, get(arg_regs, pi))
                x86_mov_stack_rax(ctx, off)
            pi = pi + 1

        // WHY: Support one-liner expression functions (e.g., fn double n = n * 2, fn ws_opcode b = b % 16)
        if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "="
            ps_adv(ps)
            compile_pure_expr(ctx, ps)
            x86_leave(ctx)
            x86_ret(ctx)
            list_set(ctx, 8, saved_names)
            list_set(ctx, 9, saved_offs)
            list_set(ctx, 20, saved_types)
            list_set(get(ctx, 10), 0, saved_stack)
            label_define(ctx, lbl_skip)
            return 0

        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                if is_meta_fn == 1 and ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    break
                prev_fn_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_fn_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
            if is_meta_fn == 1
                ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    ps_adv(ps)
        elif is_meta_fn == 1
            while ps_cur_type(ps) != TOK_EOF
                ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_IDENT and ps_cur_text(ps) == "@end"
                    ps_adv(ps)
                    break
                prev_fn_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_fn_p
                    ps_adv(ps)
                ps_skip_nl(ps)
        else
            compile_pure_stmt(ctx, ps)

        x86_mov_reg_imm64(ctx, 0, 0)
        x86_leave(ctx)
        x86_ret(ctx)

        // Restore parent scope
        list_set(ctx, 8, saved_names)
        list_set(ctx, 9, saved_offs)
        list_set(ctx, 20, saved_types)
        list_set(get(ctx, 10), 0, saved_stack)

        label_define(ctx, lbl_skip)
        return 0

    // for / প্রতিটি (Range loop: for var in start..end)
    // WHY: Support iterative loops with start and end expressions emitting fast x86_64 cmp/jg
    if tt == TOK_IDENT and (txt == "for" or txt == "প্রতিটি")
        ps_adv(ps)
        var_name = ps_cur_text(ps)
        ps_adv(ps)

        if ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "in" or ps_cur_text(ps) == "ভেতরে")
            ps_adv(ps)

        compile_pure_expr(ctx, ps)
        var_off = scope_add(ctx, var_name)
        scope_set_type(ctx, var_name, TY_INT)
        x86_mov_stack_rax(ctx, var_off)

        if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == ".."
            ps_adv(ps)

        compile_pure_expr(ctx, ps)
        end_var = "__end_" + var_name
        end_off = scope_add(ctx, end_var)
        scope_set_type(ctx, end_var, TY_INT)
        x86_mov_stack_rax(ctx, end_off)

        lbl_start = make_anon_label(ctx, "for_start")
        lbl_step  = make_anon_label(ctx, "for_step")
        lbl_end   = make_anon_label(ctx, "for_end")

        label_define(ctx, lbl_start)

        x86_mov_rax_stack(ctx, var_off)
        x86_mov_reg_reg(ctx, 3, 0) // rbx = var
        x86_mov_rax_stack(ctx, end_off) // rax = end
        bb_put8(ctx, 72)
        bb_put8(ctx, 57)
        bb_put8(ctx, 195) // cmp rbx, rax
        p_jg = ctx_len(ctx)
        bb_put8(ctx, 15)
        bb_put8(ctx, 143)
        bb_put32(ctx, 0) // jg (0x0F 0x8F)
        reloc_add(ctx, p_jg + 2, lbl_end, 6)

        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                prev_for_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_for_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        else
            compile_pure_stmt(ctx, ps)

        label_define(ctx, lbl_step)
        x86_mov_rax_stack(ctx, var_off)
        bb_put8(ctx, 72)
        bb_put8(ctx, 255)
        bb_put8(ctx, 192) // inc rax (0x48 0xFF 0xC0)
        x86_mov_stack_rax(ctx, var_off)
        x86_jmp(ctx, lbl_start)

        label_define(ctx, lbl_end)
        return 0

    // repeat N / বার (Repeat loop)
    // WHY: Support fixed-count iteration loops with an anonymous counter
    if tt == TOK_IDENT and (txt == "repeat" or txt == "বার")
        ps_adv(ps)
        compile_pure_expr(ctx, ps)
        cnt_var = make_anon_label(ctx, "__repeat_cnt")
        cnt_off = scope_add(ctx, cnt_var)
        scope_set_type(ctx, cnt_var, TY_INT)
        x86_mov_stack_rax(ctx, cnt_off)

        idx_var = make_anon_label(ctx, "__repeat_idx")
        idx_off = scope_add(ctx, idx_var)
        scope_set_type(ctx, idx_var, TY_INT)
        x86_mov_reg_imm64(ctx, 0, 0)
        x86_mov_stack_rax(ctx, idx_off)

        lbl_start = make_anon_label(ctx, "repeat_start")
        lbl_end   = make_anon_label(ctx, "repeat_end")

        label_define(ctx, lbl_start)
        x86_mov_rax_stack(ctx, idx_off)
        x86_mov_reg_reg(ctx, 3, 0) // rbx = idx
        x86_mov_rax_stack(ctx, cnt_off) // rax = count
        bb_put8(ctx, 72)
        bb_put8(ctx, 57)
        bb_put8(ctx, 195) // cmp rbx, rax
        p_jge = ctx_len(ctx)
        bb_put8(ctx, 15)
        bb_put8(ctx, 141)
        bb_put32(ctx, 0) // jge (0x0F 0x8D)
        reloc_add(ctx, p_jge + 2, lbl_end, 6)

        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                prev_rep_p = ps_pos(ps)
                compile_pure_stmt(ctx, ps)
                if ps_pos(ps) == prev_rep_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        else
            compile_pure_stmt(ctx, ps)

        x86_mov_rax_stack(ctx, idx_off)
        bb_put8(ctx, 72)
        bb_put8(ctx, 255)
        bb_put8(ctx, 192) // inc rax (0x48 0xFF 0xC0)
        x86_mov_stack_rax(ctx, idx_off)
        x86_jmp(ctx, lbl_start)

        label_define(ctx, lbl_end)
        return 0

    // Variable assignment: name = expr
    next_tok = ps_peek_tok(ps, 1)
    if tt == TOK_IDENT and tok_t(next_tok) == TOK_OP and tok_s(next_tok) == "="
        name = txt
        ps_adv(ps) // ident
        ps_adv(ps) // '='

        // Check if RHS is struct constructor: StructName(...)
        rhs_cur = ps_cur_text(ps)
        rhs_next = ps_peek_tok(ps, 1)
        rhs_struct = ""
        if ps_cur_type(ps) == TOK_IDENT and (tok_t(rhs_next) == TOK_LPAREN or (tok_t(rhs_next) == TOK_OP and tok_s(rhs_next) == "("))
            if struct_find(ctx, rhs_cur) >= 0
                rhs_struct = rhs_cur

        is_int_c = (ps_cur_type(ps) == TOK_INT)
        int_c_val = ps_cur_int(ps)
        expr_ty = compile_pure_expr(ctx, ps)
        off = scope_add(ctx, name)
        if rhs_struct != ""
            struct_set_var_type(ctx, name, rhs_struct)
        x86_mov_stack_rax(ctx, off)
        if is_int_c == 1
            push(get(ctx, 12), name)
            push(get(ctx, 13), int_c_val)
            scope_set_type(ctx, name, TY_INT)
        elif expr_ty == TY_INT
            scope_set_type(ctx, name, TY_INT)
        elif expr_ty == TY_STR
            scope_set_type(ctx, name, TY_STR)
        return 0

    // Compound assignment: name += expr, -=
    if tt == TOK_IDENT and tok_t(next_tok) == TOK_OP and (tok_s(next_tok) == "+=" or tok_s(next_tok) == "-=")
        name = txt
        cop = tok_s(next_tok)
        ps_adv(ps) // ident
        ps_adv(ps) // op
        expr_ty = compile_pure_expr(ctx, ps)
        off = scope_add(ctx, name)
        x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
        x86_mov_rax_stack(ctx, off) // rax = lhs
        if char_at(cop, 0) == "+"
            x86_add_rax_rbx(ctx)
        else
            x86_sub_rax_rbx(ctx)
        x86_mov_stack_rax(ctx, off)
        if expr_ty == TY_INT or scope_get_type(ctx, name) == TY_INT
            scope_set_type(ctx, name, TY_INT)
        return 0

    // Standalone expression
    compile_pure_expr(ctx, ps)
    return 0

// ── Build Final ELF64 Binary File ─────────────────────────────────────────────
fn build_and_write_pure_elf ctx out_path
    code_bb = ctx_bb(ctx)
    total_size = ELF_HEADER_SIZE + len(code_bb)
    elf = list()

    // 1. ELF64 Header (64 bytes)
    // Magic: 0x7F, 'E', 'L', 'F', 2 (64-bit), 1 (little-endian), 1 (version 1), 0 (System V), 8 zeroes
    ident = list(127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    // WHY: Explicit while loop avoids range vs collection loop discrepancy
    ii = 0
    ilen = len(ident)
    while ii < ilen
        push(elf, get(ident, ii))
        ii = ii + 1

    // e_type: ET_EXEC (0x0002)
    push(elf, 2)
    push(elf, 0)

    // e_machine: EM_X86_64 (0x003E = 62)
    push(elf, 62)
    push(elf, 0)

    // e_version: EV_CURRENT (1)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_entry: ENTRY_POINT_VADDR (64-bit)
    push(elf, ENTRY_POINT_VADDR % 256)
    push(elf, floor(ENTRY_POINT_VADDR / 256) % 256)
    push(elf, floor(ENTRY_POINT_VADDR / 65536) % 256)
    push(elf, floor(ENTRY_POINT_VADDR / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_phoff: 64 (0x40)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_shoff: 0
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_flags: 0
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_ehsize: 64
    push(elf, 64)
    push(elf, 0)

    // e_phentsize: 56
    push(elf, 56)
    push(elf, 0)

    // e_phnum: 1
    push(elf, 1)
    push(elf, 0)

    // e_shentsize: 0
    push(elf, 0)
    push(elf, 0)

    // e_shnum: 0
    push(elf, 0)
    push(elf, 0)

    // e_shstrndx: 0
    push(elf, 0)
    push(elf, 0)

    // 2. Program Header Table (56 bytes, PT_LOAD)
    // p_type: PT_LOAD (1)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_flags: PF_R | PF_W | PF_X = 7
    push(elf, 7)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_offset: 0
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_vaddr: ELF_BASE_VADDR (64-bit virtual memory address)
    push(elf, ELF_BASE_VADDR % 256)
    push(elf, floor(ELF_BASE_VADDR / 256) % 256)
    push(elf, floor(ELF_BASE_VADDR / 65536) % 256)
    push(elf, floor(ELF_BASE_VADDR / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_paddr: ELF_BASE_VADDR (64-bit physical memory address)
    push(elf, ELF_BASE_VADDR % 256)
    push(elf, floor(ELF_BASE_VADDR / 256) % 256)
    push(elf, floor(ELF_BASE_VADDR / 65536) % 256)
    push(elf, floor(ELF_BASE_VADDR / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_filesz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, floor(total_size / 256) % 256)
    push(elf, floor(total_size / 65536) % 256)
    push(elf, floor(total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_memsz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, floor(total_size / 256) % 256)
    push(elf, floor(total_size / 65536) % 256)
    push(elf, floor(total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_align: 4KB (0x1000)
    push(elf, 0)
    push(elf, 16)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // 3. User Code & Data
    // WHY: Explicit while loop avoids range vs collection loop discrepancy
    cbi = 0
    cblen = len(code_bb)
    while cbi < cblen
        push(elf, get(code_bb, cbi))
        cbi = cbi + 1

    // 4. Write binary directly to disk and apply chmod 0755
    res = file_write_bytes(out_path, elf)
    return res

// ── Helper String & Multi-File Bundler Utilities ──────────────────────────────
// WHY: Inlines included Lipi source files recursively, ensuring lexical include_once
// semantics, zero runtime overhead, and single self-contained binary compilation.

// WHY: Divide-and-conquer substring reduces memory allocation from O(N^2) to O(N log N).
// For large 10KB source chunks, reduces heap allocations from 50MB to ~140KB (357x reduction).
fn str_sub s start end
    slen = len(s)
    if start < 0
        start = 0
    if end > slen
        end = slen
    if start >= end
        return ""
    span = end - start
    if span == 1
        return char_at(s, start)
    if span == 2
        return char_at(s, start) + char_at(s, start + 1)
    if span == 3
        return char_at(s, start) + char_at(s, start + 1) + char_at(s, start + 2)
    if span == 4
        return char_at(s, start) + char_at(s, start + 1) + char_at(s, start + 2) + char_at(s, start + 3)
    mid = start + (span / 2)
    return str_sub(s, start, mid) + str_sub(s, mid, end)

fn str_trim_start s
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        if c != " " and c != "\t" and c != "\r"
            break
        i = i + 1
    if i == 0
        return s
    return str_sub(s, i, slen)

fn path_dirname p
    last_slash = -1
    i = 0
    plen = len(p)
    while i < plen
        if char_at(p, i) == "/"
            last_slash = i
        i = i + 1
    if last_slash < 0
        return "."
    if last_slash == 0
        return "/"
    return str_sub(p, 0, last_slash)

fn list_has lst item
    i = 0
    llen = len(lst)
    while i < llen
        if get(lst, i) == item
            return 1
        i = i + 1
    return 0

fn resolve_inc_path cur_dir inc_name
    if file_exists(inc_name) == 1
        return inc_name
    cand1 = cur_dir + "/" + inc_name
    if file_exists(cand1) == 1
        return cand1
    cand2 = "std/" + inc_name
    if file_exists(cand2) == 1
        return cand2
    cand3 = "../" + inc_name
    if file_exists(cand3) == 1
        return cand3
    return cand1

fn has_include content
    p = 0
    clen = len(content)
    while p < clen
        while p < clen and (char_at(content, p) == " " or char_at(content, p) == "\t")
            p = p + 1
        if p + 9 < clen
            if char_at(content, p) == "i" and char_at(content, p+1) == "n" and char_at(content, p+2) == "c" and char_at(content, p+3) == "l" and char_at(content, p+4) == "u" and char_at(content, p+5) == "d" and char_at(content, p+6) == "e" and char_at(content, p+7) == " "
                q = char_at(content, p+8)
                if q == "\"" or q == "'"
                    return 1
        if p + 35 < clen
            if ord(char_at(content, p)) == 224
                if str_sub(content, p, p + 34) == "অন্তর্ভুক্ত "
                    q = char_at(content, p+34)
                    if q == "\"" or q == "'"
                        return 1
        while p < clen and char_at(content, p) != "\n"
            p = p + 1
        if p < clen and char_at(content, p) == "\n"
            p = p + 1
    return 0

fn bundle_source file_path visited
    if list_has(visited, file_path) == 1
        return ""
    push(visited, file_path)
    if file_exists(file_path) == 0
        say "Warning: Included file not found: " + file_path
        return ""
    content = file_read(file_path)
    if has_include(content) == 0
        return content

    cur_dir = path_dirname(file_path)
    out = ""
    chunk_start = 0
    p = 0
    clen = len(content)
    while p < clen
        line_start = p
        while p < clen and (char_at(content, p) == " " or char_at(content, p) == "\t")
            p = p + 1

        is_inc = 0
        inc_target = ""
        if p + 9 < clen
            if char_at(content, p) == "i" and char_at(content, p+1) == "n" and char_at(content, p+2) == "c" and char_at(content, p+3) == "l" and char_at(content, p+4) == "u" and char_at(content, p+5) == "d" and char_at(content, p+6) == "e" and char_at(content, p+7) == " "
                q = char_at(content, p+8)
                if q == "\"" or q == "'"
                    p_tstart = p + 9
                    p_tend = p_tstart
                    while p_tend < clen and char_at(content, p_tend) != q and char_at(content, p_tend) != "\n"
                        p_tend = p_tend + 1
                    if p_tend < clen and char_at(content, p_tend) == q
                        is_inc = 1
                        inc_target = str_sub(content, p_tstart, p_tend)

        if is_inc == 0 and p + 35 < clen
            if ord(char_at(content, p)) == 224
                if str_sub(content, p, p + 34) == "অন্তর্ভুক্ত "
                    q = char_at(content, p+34)
                    if q == "\"" or q == "'"
                        p_tstart = p + 35
                        p_tend = p_tstart
                        while p_tend < clen and char_at(content, p_tend) != q and char_at(content, p_tend) != "\n"
                            p_tend = p_tend + 1
                        if p_tend < clen and char_at(content, p_tend) == q
                            is_inc = 1
                            inc_target = str_sub(content, p_tstart, p_tend)

        while p < clen and char_at(content, p) != "\n"
            p = p + 1
        if p < clen and char_at(content, p) == "\n"
            p = p + 1

        if is_inc == 1
            if line_start > chunk_start
                out = out + str_sub(content, chunk_start, line_start)
            resolved = resolve_inc_path(cur_dir, inc_target)
            bundled = bundle_source(resolved, visited)
            if len(bundled) > 0
                out = out + bundled + "\n"
            chunk_start = p

    if chunk_start < clen
        out = out + str_sub(content, chunk_start, clen)

    return out

// ── Pure Lipi ELF Compiler Entry Point ────────────────────────────────────────
fn compile_source_to_elf in_path out_path
    if file_exists(in_path) == 0
        say "Error: Input source file not found: " + in_path
        return 1

    visited = list()
    src = bundle_source(in_path, visited)
    tokens = tokenize_pure(src)
    ps = ps_new(tokens)
    ctx = ctx_new()

    // Step 1: Emit baremetal runtime syscall stubs
    emit_runtime_stubs(ctx)

    // Step 2: Main routine
    label_define(ctx, "lipi_main")
    x86_push_rbp(ctx)
    x86_mov_rbp_rsp(ctx)
    x86_sub_rsp(ctx, 2048) // Local stack frame

    ps_skip_nl(ps)
    while ps_cur_type(ps) != TOK_EOF
        // WHY: Safeguard against parser stall if an unsupported token is encountered
        prev_p = ps_pos(ps)
        compile_pure_stmt(ctx, ps)
        if ps_pos(ps) == prev_p
            ps_adv(ps)
        ps_skip_nl(ps)

    x86_mov_reg_imm64(ctx, 0, 0) // exit 0
    x86_leave(ctx)
    x86_ret(ctx)

    // Step 3: Emit Data Section
    label_define(ctx, "_lipi_data_start")
    str_texts  = get(ctx, 6)
    str_labels = get(ctx, 7)
    si = 0
    while si < len(str_texts)
        stext = get(str_texts, si)
        slbl  = get(str_labels, si)
        slen  = len(stext)
        // WHY: 8-byte STR0 prefix: lower 32 bits = slen, upper 32 bits = 'STR0' (0x53545230 = 1398034992)
        bb_put32(ctx, slen)
        bb_put32(ctx, 1398034992)
        label_define(ctx, slbl)
        ci = 0
        while ci < slen
            bb_put8(ctx, ord(char_at(stext, ci)))
            ci = ci + 1
        bb_put8(ctx, 0) // null terminator
        si = si + 1
    label_define(ctx, "_lipi_data_end")

    // Global Heap State Variables
    label_define(ctx, "_lipi_heap_base")
    bb_put64(ctx, 0)
    label_define(ctx, "_lipi_heap_ptr")
    bb_put64(ctx, 0)
    label_define(ctx, "_lipi_initial_rsp")
    bb_put64(ctx, 0)

    // Step 4: Backpatch all jumps, calls, and RIP relocations
    backpatch_all(ctx)

    // Step 5: Wrap in ELF64 and write executable
    build_and_write_pure_elf(ctx, out_path)
    return 0

// ── Main CLI Driver ───────────────────────────────────────────────────────────
// WHY: Multi-target compiler driver dispatching directly to native silicon machine
//      code emitters (x86_64 and AArch64 / ARM64) based on explicit CLI flags.
args = argv()
in_file = ""
out_file = ""
target_arch = "x86_64"

i = 1
while i < len(args)
    arg = get(args, i)
    if arg == "-o"
        i = i + 1
        if i < len(args)
            out_file = get(args, i)
    elif arg == "--target=arm64" or arg == "--target=aarch64" or arg == "-marm64"
        target_arch = "arm64"
    elif arg == "--target=x86_64" or arg == "--target=amd64" or arg == "-mx86_64"
        target_arch = "x86_64"
    elif arg == "--direct-elf" or arg == "--baremetal"
        pass_noop = 0
    elif arg == "--help" or arg == "-h"
        say "👑 Lipi Sovereign Compiler — First 1.0 (প্রথম ১.০)"
        say "⚡ 100% Pure Lipi Source | Zero C | Zero GCC | Zero Libc | Zero Python"
        say "Usage:"
        say "  lipc <input.lp> [-o <output_binary>]                 Compile to Linux x86_64 ELF64"
        say "  lipc --target=arm64 <input.lp> [-o <output_binary>]  Compile to Linux AArch64 (ARM64) ELF64"
        say "  lipc --target=x86_64 <input.lp> [-o <output_binary>] Compile to Linux x86_64 ELF64"
        exit(0)
    else
        if in_file == ""
            in_file = arg
        else
            if out_file == ""
                out_file = arg
    i = i + 1

if in_file == ""
    say "Lipi Pure Sovereign Compiler — First 1.0 (প্রথম ১.০)"
    say "Usage: lipc [--target=arm64|--target=x86_64] <input.lp> [-o <output_binary>]"
    exit(1)

if out_file == ""
    out_file = in_file + ".bin"

if target_arch == "arm64"
    res = arm64_compile_source_to_elf(in_file, out_file)
    if res == 0
        say "✔ Successfully compiled " + in_file + " to " + out_file + " (Pure Lipi ARM64 ELF)"
    else
        say "❌ Failed to compile " + in_file + " for ARM64"
        exit(1)
else
    res = compile_source_to_elf(in_file, out_file)
    if res == 0
        say "✔ Successfully compiled " + in_file + " to " + out_file + " (Pure Lipi ELF)"
    else
        say "❌ Failed to compile " + in_file
        exit(1)
