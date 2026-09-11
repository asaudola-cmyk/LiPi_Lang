// ==============================================================================
// 🧪 LIPI TEST 62: Pure ARM64 (AArch64) Native Silicon Emitter Verification
// ⚡ Tests fixed 32-bit machine instruction encoders, Linux AArch64 syscall ABI,
//    standalone ELF64 executable synthesis, and structural header validation.
// ==============================================================================

include "src/compiler/arm64_emitter.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI SOVEREIGN ARM64 (AARCH64) EMITTER VERIFICATION SUITE"
    say "════════════════════════════════════════════════════════════════════════"

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 1]: Fixed 32-Bit Instruction Encoder Verification
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 1]: Validating Fixed 32-Bit ARM64 Machine Instruction Encoders..."

    // 1. MOVZ X0, #42, LSL #0 -> 0xD2800540 (3531605312)
    w_movz = arm64_movz(0, 42, 0)
    test_assert_eq(w_movz, 3531605312, "arm64_movz(0, 42, 0) -> 0xD2800540")

    // 2. MOVK X0, #1, LSL #16 -> 0xF2A00020 (4070572064)
    w_movk = arm64_movk(0, 1, 16)
    test_assert_eq(w_movk, 4070572064, "arm64_movk(0, 1, 16) -> 0xF2A00020")

    // 3. ADD X0, X1, X2 -> 0x8B020020 (2332164128)
    w_add = arm64_add(0, 1, 2)
    test_assert_eq(w_add, 2332164128, "arm64_add(0, 1, 2) -> 0x8B020020")

    // 4. SUB X0, X1, X2 -> 0xCB020020 (3405905952)
    w_sub = arm64_sub(0, 1, 2)
    test_assert_eq(w_sub, 3405905952, "arm64_sub(0, 1, 2) -> 0xCB020020")

    // 5. LDR X0, [X1, #8] (imm12=1) -> 0xF9400420 (4181722144)
    w_ldr = arm64_ldr_imm(0, 1, 1)
    test_assert_eq(w_ldr, 4181722144, "arm64_ldr_imm(0, 1, 1) -> 0xF9400420")

    // 6. STR X0, [X1, #8] (imm12=1) -> 0xF9000420 (4177527840)
    w_str = arm64_str_imm(0, 1, 1)
    test_assert_eq(w_str, 4177527840, "arm64_str_imm(0, 1, 1) -> 0xF9000420")

    // 7. SVC #0 -> 0xD4000001 (3556769793)
    w_svc = arm64_svc(0)
    test_assert_eq(w_svc, 3556769793, "arm64_svc(0) -> 0xD4000001")

    // 8. RET (X30) -> 0xD65F03C0 (3596551104)
    w_ret = arm64_ret()
    test_assert_eq(w_ret, 3596551104, "arm64_ret() -> 0xD65F03C0")

    // 9. B #16 (disp=16 => imm26=4) -> 0x14000004 (335544324)
    w_b = arm64_b(16)
    test_assert_eq(w_b, 335544324, "arm64_b(16) -> 0x14000004")

    // 10. CBZ X0, #16 (disp=16 => imm19=4) -> 0xB4000080 (3019899008)
    w_cbz = arm64_cbz(0, 16)
    test_assert_eq(w_cbz, 3019899008, "arm64_cbz(0, 16) -> 0xB4000080")

    // 11. Extended: CBNZ X0, #16 -> 0xB5000080 (3036676224)
    w_cbnz = arm64_cbnz(0, 16)
    test_assert_eq(w_cbnz, 3036676224, "arm64_cbnz(0, 16) -> 0xB5000080")

    // 12. Extended: MOV X0, X1 -> 0xAA0103E0 (2852193248)
    w_movreg = arm64_mov_reg(0, 1)
    test_assert_eq(w_movreg, 2852193248, "arm64_mov_reg(0, 1) -> 0xAA0103E0")

    // 13. Negative branch displacement: B -16 -> 0x17FFFFFC (402653180)
    w_b_neg = arm64_b(0 - 16)
    test_assert_eq(w_b_neg, 402653180, "arm64_b(-16) -> 0x17FFFFFC")

    // 14. Negative CBZ displacement: CBZ X0, -16 -> 0xB4FFFF80 (3036675968)
    w_cbz_neg = arm64_cbz(0, 0 - 16)
    test_assert_eq(w_cbz_neg, 3036675968, "arm64_cbz(0, -16) -> 0xB4FFFF80")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 2]: Linux AArch64 Syscall Convention Verification
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 2]: Validating Linux AArch64 Syscall Calling Convention..."
    test_assert_eq(ARM64_SYS_WRITE, 64, "Linux AArch64 sys_write == 64")
    test_assert_eq(ARM64_SYS_EXIT, 93, "Linux AArch64 sys_exit == 93")
    test_assert_eq(ARM64_SYS_READ, 63, "Linux AArch64 sys_read == 63")
    test_assert_eq(ARM64_REG_X8, 8, "Linux AArch64 syscall number register == X8")
    test_assert_eq(ARM64_REG_X0, 0, "Linux AArch64 arg1 register == X0")
    test_assert_eq(ARM64_REG_X1, 1, "Linux AArch64 arg2 register == X1")
    test_assert_eq(ARM64_REG_X2, 2, "Linux AArch64 arg3 register == X2")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 3]: Standalone Linux ARM64 Executable Generation
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 3]: Synthesizing Standalone Linux AArch64 ELF64 Executable..."
    ctx = arm64_ctx_new()

    // Entry Point _start
    arm64_label_define(ctx, "_start")

    // Register greeting string literal in pool
    greeting = "Hello from Sovereign Pure Lipi ARM64 Silicon!\n"
    g_lbl = arm64_string_add(ctx, greeting)
    g_len = len(greeting)

    // Syscall write(1, buf, len)
    // X0 = 1 (stdout)
    // X1 = buf address (via ADR)
    // X2 = length
    // X8 = 64 (sys_write)
    // SVC #0
    arm64_emit_sys_write(ctx, 1, g_lbl, g_len)

    // Hardware Register Arithmetic Verification sequence
    // X0 = 10
    // X1 = 32
    // X2 = X0 + X1 (42)
    // X3 = X2 - X0 (32)
    arm64_emit_movz(ctx, ARM64_REG_X0, 10, 0)
    arm64_emit_movz(ctx, ARM64_REG_X1, 32, 0)
    arm64_emit_add(ctx, ARM64_REG_X2, ARM64_REG_X0, ARM64_REG_X1)
    arm64_emit_sub(ctx, ARM64_REG_X3, ARM64_REG_X2, ARM64_REG_X0)

    // Conditional Control Flow: CBZ on X4 (starts at 0, should branch over NOP)
    arm64_emit_movz(ctx, ARM64_REG_X4, 0, 0)
    arm64_emit_cbz_label(ctx, ARM64_REG_X4, "lbl_calc_done")
    arm64_emit_nop(ctx)
    arm64_label_define(ctx, "lbl_calc_done")

    // Syscall exit(0)
    // X0 = 0 (exit status)
    // X8 = 93 (sys_exit)
    // SVC #0
    arm64_emit_sys_exit(ctx, 0)

    out_elf_path = "/tmp/test_arm64_executable.elf"
    write_res = arm64_write_elf(ctx, out_elf_path)
    say "  • Output binary emitted to: " + out_elf_path
    test_assert_eq(write_res, 0, "arm64_write_elf succeeded")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 4]: Byte-Level Structural ELF64 Header Diagnostics
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 4]: Validating ELF64 Header & Program Header on Disk..."
    content = file_read(out_elf_path)
    file_len = len(content)
    say "  • Total generated ELF size: " + str(file_len) + " bytes"
    if file_len < 120
        say "  ❌ FAILED: File size less than ELF header size!"
        exit(1)

    // 1. ELF Magic: 0x7F, 'E', 'L', 'F'
    m0 = ord(char_at(content, 0))
    m1 = ord(char_at(content, 1))
    m2 = ord(char_at(content, 2))
    m3 = ord(char_at(content, 3))
    test_assert_eq(m0, 127, "ELF Magic [0] == 0x7F")
    test_assert_eq(m1, 69,  "ELF Magic [1] == 'E'")
    test_assert_eq(m2, 76,  "ELF Magic [2] == 'L'")
    test_assert_eq(m3, 70,  "ELF Magic [3] == 'F'")

    // 2. Class & Endianness
    elf_class = ord(char_at(content, 4))
    elf_data  = ord(char_at(content, 5))
    elf_ver   = ord(char_at(content, 6))
    elf_osabi = ord(char_at(content, 7))
    test_assert_eq(elf_class, 2, "ELFCLASS64 (64-bit architecture)")
    test_assert_eq(elf_data,  1, "ELFDATA2LSB (Little-endian byte order)")
    test_assert_eq(elf_ver,   1, "ELF Version == 1")
    test_assert_eq(elf_osabi, 0, "ELF OS/ABI == System V")

    // 3. e_type: ET_EXEC (2)
    e_type = ord(char_at(content, 16)) + (ord(char_at(content, 17)) * 256)
    test_assert_eq(e_type, 2, "e_type == ET_EXEC (2)")

    // 4. e_machine: EM_AARCH64 (183 / 0x00B7)
    e_machine = ord(char_at(content, 18)) + (ord(char_at(content, 19)) * 256)
    test_assert_eq(e_machine, 183, "e_machine == EM_AARCH64 (183 / 0x00B7)")

    // 5. e_entry: 0x400078 (4194424)
    e_entry = ord(char_at(content, 24)) + (ord(char_at(content, 25)) * 256) + (ord(char_at(content, 26)) * 65536) + (ord(char_at(content, 27)) * 16777216)
    test_assert_eq(e_entry, 4194424, "e_entry == 0x400078 (0x400000 + 120)")

    // 6. Header sizes and Program Header counts
    e_ehsize = ord(char_at(content, 52)) + (ord(char_at(content, 53)) * 256)
    e_phentsize = ord(char_at(content, 54)) + (ord(char_at(content, 55)) * 256)
    e_phnum = ord(char_at(content, 56)) + (ord(char_at(content, 57)) * 256)
    test_assert_eq(e_ehsize, 64, "e_ehsize == 64 bytes")
    test_assert_eq(e_phentsize, 56, "e_phentsize == 56 bytes")
    test_assert_eq(e_phnum, 1, "e_phnum == 1 Program Header")

    // 7. Program Header: PT_LOAD (1) & Flags (PF_R | PF_W | PF_X = 7)
    p_type = ord(char_at(content, 64)) + (ord(char_at(content, 65)) * 256) + (ord(char_at(content, 66)) * 65536) + (ord(char_at(content, 67)) * 16777216)
    p_flags = ord(char_at(content, 68)) + (ord(char_at(content, 69)) * 256) + (ord(char_at(content, 70)) * 65536) + (ord(char_at(content, 71)) * 16777216)
    p_vaddr = ord(char_at(content, 80)) + (ord(char_at(content, 81)) * 256) + (ord(char_at(content, 82)) * 65536) + (ord(char_at(content, 83)) * 16777216)
    test_assert_eq(p_type, 1, "Program Header p_type == PT_LOAD (1)")
    test_assert_eq(p_flags, 7, "Program Header p_flags == PF_R | PF_W | PF_X (7)")
    test_assert_eq(p_vaddr, 4194304, "Program Header p_vaddr == 0x400000")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 5]: End-to-End AST Program Compilation to Standalone ARM64 Binary
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 5]: Validating Full AST Compilation Pipeline to ARM64 Binary..."
    p5_src_path = "/tmp/test_arm64_p5_input.lp"
    p5_elf_path = "/tmp/test_arm64_p5_output.elf"

    p5_code = "fn calc a b\n    return (a * 2) + b\n\nlet x = 10\nlet y = 22\nlet res = calc(x, y)\nif res == 42\n    say \"PASS: res == 42\"\nelse\n    say \"FAIL\"\n"

    // Convert string to bytes list
    p5_bytes = list()
    p5_i = 0
    p5_len = len(p5_code)
    while p5_i < p5_len
        push(p5_bytes, ord(char_at(p5_code, p5_i)))
        p5_i = p5_i + 1

    file_write_bytes(p5_src_path, p5_bytes)

    compile_res = arm64_compile_source_to_elf(p5_src_path, p5_elf_path)
    test_assert_eq(compile_res, 0, "arm64_compile_source_to_elf returned 0 (success)")

    p5_content = file_read(p5_elf_path)
    p5_elf_len = len(p5_content)
    say "  • AST-compiled ARM64 ELF size: " + str(p5_elf_len) + " bytes"
    if p5_elf_len < 120
        say "  ❌ FAILED: Compiled ELF file size too small!"
        exit(1)

    // Verify ARM64 ELF Magic and Machine ID
    test_assert_eq(ord(char_at(p5_content, 0)), 127, "AST ELF Magic [0] == 0x7F")
    test_assert_eq(ord(char_at(p5_content, 1)), 69,  "AST ELF Magic [1] == 'E'")
    test_assert_eq(ord(char_at(p5_content, 2)), 76,  "AST ELF Magic [2] == 'L'")
    test_assert_eq(ord(char_at(p5_content, 3)), 70,  "AST ELF Magic [3] == 'F'")

    p5_machine = ord(char_at(p5_content, 18)) + (ord(char_at(p5_content, 19)) * 256)
    test_assert_eq(p5_machine, 183, "AST ELF Machine == EM_AARCH64 (183)")

    p5_entry = ord(char_at(p5_content, 24)) + (ord(char_at(p5_content, 25)) * 256) + (ord(char_at(p5_content, 26)) * 65536) + (ord(char_at(p5_content, 27)) * 16777216)
    test_assert_eq(p5_entry, 4194424, "AST ELF Entry == 0x400078 (4194424)")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL ARM64 SILICON EMITTER INVARIANTS VALIDATED SUCCESSFULLY!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 62 ARM64 Emitter"
    return 0

main()
