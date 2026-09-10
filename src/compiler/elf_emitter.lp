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

ELF_BASE_VADDR    = 4194304  // 0x400000
ELF_HEADER_SIZE   = 120      // 64 bytes ELF64 header + 56 bytes Program header
ENTRY_POINT_VADDR = 4194424  // 0x400078 = 0x400000 + 120

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
    return c

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

fn scope_add ctx name
    existing = scope_get(ctx, name)
    if existing != 0 return existing
    stk_ref = get(ctx, 10)
    new_stack = get(stk_ref, 0) + 8
    list_set(stk_ref, 0, new_stack)
    push(get(ctx, 8), name)
    push(get(ctx, 9), new_stack)
    return new_stack

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

fn x86_neg_rax ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 247) // 0xF7
    bb_put8(ctx, 216) // 0xD8 (neg rax)

fn x86_cmp_rax_rbx ctx
    bb_put8(ctx, 72)  // 0x48
    bb_put8(ctx, 57)  // 0x39
    bb_put8(ctx, 216) // 0xD8 (cmp rbx, rax)

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
    x86_mov_reg_imm64(ctx, 6, 16777216) // rsi = 16MB
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
    bb_put8(ctx, 77)
    bb_put8(ctx, 139)
    bb_put8(ctx, 116)
    bb_put8(ctx, 36)
    bb_put8(ctx, 248) // mov r14, [r12 - 8]
    bb_put8(ctx, 77)
    bb_put8(ctx, 139)
    bb_put8(ctx, 125)
    bb_put8(ctx, 248) // mov r15, [r13 - 8]
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
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 87)
    bb_put8(ctx, 248) // mov rdx, [rdi - 8]
    x86_mov_reg_reg(ctx, 6, 7) // mov rsi, rdi
    x86_mov_reg_imm64(ctx, 7, 1) // rdi = 1 (stdout)
    x86_mov_reg_imm64(ctx, 0, 1) // rax = 1 (sys_write)
    x86_syscall(ctx)
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

    // 9. _lipi_is_str: rdi = val -> rax = 1 (true) or 0 (false)
    label_define(ctx, "_lipi_is_str")
    lbl_is_heap  = make_anon_label(ctx, "is_heap")
    lbl_is_true  = make_anon_label(ctx, "is_true")
    lbl_is_false = make_anon_label(ctx, "is_false")
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 255) // test rdi, rdi
    x86_jz(ctx, lbl_is_false)
    x86_lea_reg_rip(ctx, 0, "_lipi_data_start")
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 199) // cmp rdi, rax
    p_ish = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0) // jb is_heap
    reloc_add(ctx, p_ish + 2, lbl_is_heap, 6)
    x86_lea_reg_rip(ctx, 2, "_lipi_data_end")
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 215) // cmp rdi, rdx
    p_ist = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0) // jb is_true
    reloc_add(ctx, p_ist + 2, lbl_is_true, 6)
    label_define(ctx, lbl_is_heap)
    x86_lea_reg_rip(ctx, 3, "_lipi_heap_base")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 3) // mov rax, [rbx]
    bb_put8(ctx, 72)
    bb_put8(ctx, 133)
    bb_put8(ctx, 192) // test rax, rax
    x86_jz(ctx, lbl_is_false)
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 199) // cmp rdi, rax
    p_isf = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 130)
    bb_put32(ctx, 0) // jb is_false
    reloc_add(ctx, p_isf + 2, lbl_is_false, 6)
    x86_lea_reg_rip(ctx, 3, "_lipi_heap_ptr")
    bb_put8(ctx, 72)
    bb_put8(ctx, 139)
    bb_put8(ctx, 19) // mov rdx, [rbx]
    bb_put8(ctx, 72)
    bb_put8(ctx, 57)
    bb_put8(ctx, 215) // cmp rdi, rdx
    p_isf2 = ctx_len(ctx)
    bb_put8(ctx, 15)
    bb_put8(ctx, 131)
    bb_put32(ctx, 0) // jae is_false
    reloc_add(ctx, p_isf2 + 2, lbl_is_false, 6)
    label_define(ctx, lbl_is_true)
    x86_mov_reg_imm64(ctx, 0, 1)
    x86_ret(ctx)
    label_define(ctx, lbl_is_false)
    x86_mov_reg_imm64(ctx, 0, 0)
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
                if next_c == "\n" or next_c == "#" or (next_c == "/" and p + 1 < slen and char_at(src, p + 1) == "/")
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
        if c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "=" or c == "<" or c == ">" or c == "!"
            push(tokens, tok_new(TOK_OP, c, 0))
            p = p + 1
            continue

        // Identifiers and Keywords
        is_ident_char = 0
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or c == "_" or code > 127
            is_ident_char = 1

        if is_ident_char == 1
            id_acc = ""
            while p < slen
                ic = char_at(src, p)
                icode = ord(ic)
                if (icode >= 65 and icode <= 90) or (icode >= 97 and icode <= 122) or (icode >= 48 and icode <= 57) or ic == "_" or icode > 127
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
    if tt == TOK_INT or tt == TOK_STR or tt == TOK_LPAREN return 1
    if tt == TOK_IDENT
        txt = ps_cur_text(ps)
        if txt == "if" or txt == "যদি" or txt == "while" or txt == "যতক্ষণ" return 0
        if txt == "for" or txt == "প্রতিটি" or txt == "return" or txt == "ফেরত" return 0
        if txt == "say" or txt == "বলো" or txt == "show" or txt == "দেখাও" or txt == "print" or txt == "println" return 0
        return 1
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
        return 0

    if tt == TOK_STR
        lbl = string_pool_get(ctx, txt)
        ps_adv(ps)
        x86_lea_reg_rip(ctx, 0, lbl) // lea rax, [rip + lbl]
        return 0

    if tt == TOK_LPAREN
        ps_adv(ps)
        compile_pure_expr(ctx, ps)
        if ps_cur_type(ps) == TOK_RPAREN
            ps_adv(ps)
        return 0

    if tt == TOK_IDENT
        name = txt
        ps_adv(ps)

        if name == "true" or name == "সত্য"
            x86_mov_reg_imm64(ctx, 0, 1)
            return 0
        if name == "false" or name == "মিথ্যা" or name == "null" or name == "nil" or name == "শূন্য"
            x86_mov_reg_imm64(ctx, 0, 0)
            return 0

        // Function call: name(...)
        if ps_cur_type(ps) == TOK_LPAREN
            ps_adv(ps)
            arg_count = 0
            arg_regs = list(7, 6, 2, 1, 8, 9) // rdi, rsi, rdx, rcx, r8, r9
            while ps_cur_type(ps) != TOK_RPAREN and ps_cur_type(ps) != TOK_EOF
                compile_pure_expr(ctx, ps)
                x86_push_reg(ctx, 0)
                arg_count = arg_count + 1
                if ps_cur_type(ps) == TOK_COMMA
                    ps_adv(ps)
            if ps_cur_type(ps) == TOK_RPAREN
                ps_adv(ps)

            // Pop args into registers in reverse
            ai = arg_count - 1
            while ai >= 0
                if ai < 6
                    x86_pop_reg(ctx, get(arg_regs, ai))
                else
                    x86_pop_reg(ctx, 0)
                ai = ai - 1

            if name == "len" or name == "length" or name == "দৈর্ঘ্য"
                bb_put8(ctx, 72)
                bb_put8(ctx, 139)
                bb_put8(ctx, 71)
                bb_put8(ctx, 248) // mov rax, [rdi - 8]
                return 0
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
                return 0

            x86_call(ctx, "lipi_fn_" + name)
            return 0

        // Bare function call: len x, abs x
        if name == "len" or name == "length" or name == "দৈর্ঘ্য"
            compile_pure_primary(ctx, ps)
            bb_put8(ctx, 72)
            bb_put8(ctx, 139)
            bb_put8(ctx, 64)
            bb_put8(ctx, 248) // mov rax, [rax - 8]
            return 0
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
            return 0

        // Local variable lookup
        off = scope_get(ctx, name)
        if off > 0
            x86_mov_rax_stack(ctx, off)
            return 0

        // WHY: Handle space-separated function calls without parentheses (e.g., fibonacci i, say sum 10 20)
        if is_pure_arg_start(ps) == 1
            arg_count = 0
            arg_regs = list(7, 6, 2, 1, 8, 9)
            while is_pure_arg_start(ps) == 1 and ps_cur_type(ps) != TOK_NL and ps_cur_type(ps) != TOK_EOF
                compile_pure_primary(ctx, ps)
                x86_push_reg(ctx, 0)
                arg_count = arg_count + 1
            ai = arg_count - 1
            while ai >= 0
                if ai < 6
                    x86_pop_reg(ctx, get(arg_regs, ai))
                else
                    x86_pop_reg(ctx, 0)
                ai = ai - 1
            x86_call(ctx, "lipi_fn_" + name)
            return 0

        x86_mov_reg_imm64(ctx, 0, 0)
        return 0

    return 0

fn compile_pure_unary ctx ps
    ps_skip_nl(ps)
    if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "-"
        ps_adv(ps)
        compile_pure_unary(ctx, ps)
        x86_neg_rax(ctx)
        return 0
    compile_pure_primary(ctx, ps)

fn compile_pure_mul ctx ps
    compile_pure_unary(ctx, ps)
    while ps_cur_type(ps) == TOK_OP and (ps_cur_text(ps) == "*" or ps_cur_text(ps) == "/" or ps_cur_text(ps) == "%")
        op = ps_cur_text(ps)
        ps_adv(ps)
        x86_push_reg(ctx, 0) // push rax
        compile_pure_unary(ctx, ps)
        x86_mov_reg_reg(ctx, 3, 0) // mov rbx, rax
        x86_pop_reg(ctx, 0)        // pop rax
        if op == "*" x86_imul_rax_rbx(ctx)
        elif op == "/" x86_idiv_rbx(ctx)
        elif op == "%" x86_imod_rbx(ctx)

fn compile_pure_add ctx ps
    compile_pure_mul(ctx, ps)
    while ps_cur_type(ps) == TOK_OP and (ps_cur_text(ps) == "+" or ps_cur_text(ps) == "-")
        op = ps_cur_text(ps)
        ps_adv(ps)
        x86_push_reg(ctx, 0) // push lhs
        compile_pure_mul(ctx, ps)
        if op == "+"
            x86_mov_reg_reg(ctx, 6, 0) // rsi = rhs
            x86_pop_reg(ctx, 7)        // rdi = lhs
            x86_call(ctx, "_lipi_add_dynamic")
        else
            x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
            x86_pop_reg(ctx, 0)        // rax = lhs
            x86_sub_rax_rbx(ctx)

fn compile_pure_cmp ctx ps
    compile_pure_add(ctx, ps)
    while ps_cur_type(ps) == TOK_OP and (ps_cur_text(ps) == "==" or ps_cur_text(ps) == "!=" or ps_cur_text(ps) == "<" or ps_cur_text(ps) == "<=" or ps_cur_text(ps) == ">" or ps_cur_text(ps) == ">=")
        op = ps_cur_text(ps)
        ps_adv(ps)
        x86_push_reg(ctx, 0)
        compile_pure_add(ctx, ps)
        x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
        x86_pop_reg(ctx, 0)        // rax = lhs
        x86_set_cmp(ctx, op)

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
        return 0
    compile_pure_cmp(ctx, ps)
    return 0

// WHY: Short-circuiting logical AND (and, এবং, &&)
fn compile_pure_and ctx ps
    compile_pure_not(ctx, ps)
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

// WHY: Short-circuiting logical OR (or, অথবা, ||)
fn compile_pure_or ctx ps
    compile_pure_and(ctx, ps)
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

fn compile_pure_expr ctx ps
    compile_pure_or(ctx, ps)

fn compile_pure_stmt ctx ps
    ps_skip_nl(ps)
    tt  = ps_cur_type(ps)
    txt = ps_cur_text(ps)

    if tt == TOK_EOF or tt == TOK_DEDENT return 0

    // say / বলো / show / দেখাও / print / println
    if tt == TOK_IDENT and (txt == "say" or txt == "বলো" or txt == "show" or txt == "দেখাও" or txt == "print" or txt == "println")
        ps_adv(ps)
        compile_pure_expr(ctx, ps)
        x86_mov_reg_reg(ctx, 7, 0) // mov rdi, rax
        x86_call(ctx, "_lipi_print_dynamic")
        x86_call(ctx, "_lipi_print_nl")
        return 0

    // if / elif / else (যদি / নাহলে_যদি / নাহলে)
    // WHY: Support arbitrary elif chaining and else fallback branches
    if tt == TOK_IDENT and (txt == "if" or txt == "যদি")
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
                prev_if_p = get(ps, 0)
                compile_pure_stmt(ctx, ps)
                if get(ps, 0) == prev_if_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        else
            compile_pure_stmt(ctx, ps)

        x86_jmp(ctx, lbl_end)
        label_define(ctx, lbl_next)

        ps_skip_nl(ps)
        while ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "elif" or ps_cur_text(ps) == "নাহলে_যদি")
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
                    prev_elif_p = get(ps, 0)
                    compile_pure_stmt(ctx, ps)
                    if get(ps, 0) == prev_elif_p
                        ps_adv(ps)
                    ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_DEDENT
                    ps_adv(ps)
            else
                compile_pure_stmt(ctx, ps)

            x86_jmp(ctx, lbl_end)
            label_define(ctx, lbl_next)
            ps_skip_nl(ps)

        if ps_cur_type(ps) == TOK_IDENT and (ps_cur_text(ps) == "else" or ps_cur_text(ps) == "নাহলে")
            ps_adv(ps)
            ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_INDENT
                ps_adv(ps)
                while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                    prev_else_p = get(ps, 0)
                    compile_pure_stmt(ctx, ps)
                    if get(ps, 0) == prev_else_p
                        ps_adv(ps)
                    ps_skip_nl(ps)
                if ps_cur_type(ps) == TOK_DEDENT
                    ps_adv(ps)
            else
                compile_pure_stmt(ctx, ps)

        label_define(ctx, lbl_end)
        return 0

    // while / যতক্ষণ
    if tt == TOK_IDENT and (txt == "while" or txt == "যতক্ষণ")
        ps_adv(ps)
        lbl_loop = make_anon_label(ctx, "while_loop")
        lbl_end  = make_anon_label(ctx, "while_end")
        label_define(ctx, lbl_loop)
        compile_pure_expr(ctx, ps)
        bb_put8(ctx, 72)
        bb_put8(ctx, 133)
        bb_put8(ctx, 192) // test rax, rax
        x86_jz(ctx, lbl_end)

        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                compile_pure_stmt(ctx, ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        else
            compile_pure_stmt(ctx, ps)

        x86_jmp(ctx, lbl_loop)
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

    // fn / কাজ (Function Definition)
    // WHY: Support top-level and nested function definitions with up to 6 register arguments (AMD64 ABI)
    if tt == TOK_IDENT and (txt == "fn" or txt == "কাজ")
        ps_adv(ps)
        fn_name = ps_cur_text(ps)
        ps_adv(ps)

        params = list()
        if ps_cur_type(ps) == TOK_LPAREN
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_RPAREN and ps_cur_type(ps) != TOK_EOF
                if ps_cur_type(ps) == TOK_IDENT and len(params) < 6
                    push(params, ps_cur_text(ps))
                    ps_adv(ps)
                if ps_cur_type(ps) == TOK_COMMA
                    ps_adv(ps)
            if ps_cur_type(ps) == TOK_RPAREN
                ps_adv(ps)
        else
            while ps_cur_type(ps) == TOK_IDENT and len(params) < 6
                push(params, ps_cur_text(ps))
                ps_adv(ps)

        lbl_skip = make_anon_label(ctx, "skip_fn")
        x86_jmp(ctx, lbl_skip)

        label_define(ctx, "lipi_fn_" + fn_name)

        // Save parent scope
        saved_names = get(ctx, 8)
        saved_offs  = get(ctx, 9)
        saved_stack = get(get(ctx, 10), 0)

        list_set(ctx, 8, list())
        list_set(ctx, 9, list())
        list_set(get(ctx, 10), 0, 0)

        x86_push_rbp(ctx)
        x86_mov_rbp_rsp(ctx)
        x86_sub_rsp(ctx, 2048)

        arg_regs = list(7, 6, 2, 1, 8, 9)
        pi = 0
        while pi < len(params)
            off = scope_add(ctx, get(params, pi))
            x86_mov_reg_reg(ctx, 0, get(arg_regs, pi))
            x86_mov_stack_rax(ctx, off)
            pi = pi + 1

        // WHY: Support one-liner expression functions (e.g., fn double n = n * 2, fn add a b = a + b)
        if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == "="
            ps_adv(ps)
            compile_pure_expr(ctx, ps)
            x86_leave(ctx)
            x86_ret(ctx)
            list_set(ctx, 8, saved_names)
            list_set(ctx, 9, saved_offs)
            list_set(get(ctx, 10), 0, saved_stack)
            label_define(ctx, lbl_skip)
            return 0

        ps_skip_nl(ps)
        if ps_cur_type(ps) == TOK_INDENT
            ps_adv(ps)
            while ps_cur_type(ps) != TOK_DEDENT and ps_cur_type(ps) != TOK_EOF
                prev_fn_p = get(ps, 0)
                compile_pure_stmt(ctx, ps)
                if get(ps, 0) == prev_fn_p
                    ps_adv(ps)
                ps_skip_nl(ps)
            if ps_cur_type(ps) == TOK_DEDENT
                ps_adv(ps)
        else
            compile_pure_stmt(ctx, ps)

        x86_mov_reg_imm64(ctx, 0, 0)
        x86_leave(ctx)
        x86_ret(ctx)

        // Restore parent scope
        list_set(ctx, 8, saved_names)
        list_set(ctx, 9, saved_offs)
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
        x86_mov_stack_rax(ctx, var_off)

        if ps_cur_type(ps) == TOK_OP and ps_cur_text(ps) == ".."
            ps_adv(ps)

        compile_pure_expr(ctx, ps)
        end_var = "__end_" + var_name
        end_off = scope_add(ctx, end_var)
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
                prev_for_p = get(ps, 0)
                compile_pure_stmt(ctx, ps)
                if get(ps, 0) == prev_for_p
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
        x86_mov_stack_rax(ctx, cnt_off)

        idx_var = make_anon_label(ctx, "__repeat_idx")
        idx_off = scope_add(ctx, idx_var)
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
                prev_rep_p = get(ps, 0)
                compile_pure_stmt(ctx, ps)
                if get(ps, 0) == prev_rep_p
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
        compile_pure_expr(ctx, ps)
        off = scope_add(ctx, name)
        x86_mov_stack_rax(ctx, off)
        return 0

    // Compound assignment: name += expr, -=
    if tt == TOK_IDENT and tok_t(next_tok) == TOK_OP and (tok_s(next_tok) == "+=" or tok_s(next_tok) == "-=")
        name = txt
        cop = tok_s(next_tok)
        ps_adv(ps) // ident
        ps_adv(ps) // op
        compile_pure_expr(ctx, ps)
        off = scope_add(ctx, name)
        x86_mov_reg_reg(ctx, 3, 0) // rbx = rhs
        x86_mov_rax_stack(ctx, off) // rax = lhs
        if char_at(cop, 0) == "+"
            x86_add_rax_rbx(ctx)
        else
            x86_sub_rax_rbx(ctx)
        x86_mov_stack_rax(ctx, off)
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

    // e_entry: 0x400078 (64-bit)
    push(elf, 120)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
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

    // p_vaddr: 0x400000
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_paddr: 0x400000
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
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

// ── Pure Lipi ELF Compiler Entry Point ────────────────────────────────────────
fn compile_source_to_elf in_path out_path
    if file_exists(in_path) == 0
        say "Error: Input source file not found: " + in_path
        return 1

    src = file_read(in_path)
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
        prev_p = get(ps, 0)
        compile_pure_stmt(ctx, ps)
        if get(ps, 0) == prev_p
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
        bb_put64(ctx, slen) // 8-byte length prefix
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

    // Step 4: Backpatch all jumps, calls, and RIP relocations
    backpatch_all(ctx)

    // Step 5: Wrap in ELF64 and write executable
    build_and_write_pure_elf(ctx, out_path)
    return 0

// ── Main CLI Driver ───────────────────────────────────────────────────────────
args = argv()
if len(args) < 3
    say "Lipi Pure ELF Compiler — First 1.0 (প্রথম ১.০)"
    say "100% Pure Lipi Source | Zero C | Zero GCC | Zero Python Output"
    say "Usage: lipi elf_emitter.lp <input.lp> <output_binary>"
    exit(1)

in_file  = get(args, 1)
out_file = get(args, 2)

res = compile_source_to_elf(in_file, out_file)
if res == 0
    say "✔ Successfully compiled " + in_file + " to " + out_file + " (Pure Lipi ELF)"
else
    say "❌ Failed to compile " + in_file
    exit(1)
