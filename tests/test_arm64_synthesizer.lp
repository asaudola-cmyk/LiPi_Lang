// ==============================================================================
// 🧪 LIPI SOVEREIGN ARM64 (AARCH64) SYNTHESIZER TEST SUITE
// ⚡ Tests fixed 32-bit machine instruction encoders, AST/token stream synthesis,
//    inter-procedural relocations, AAPCS64 calling convention, and ELF64 packaging.
// 🏛️ File: tests/test_arm64_synthesizer.lp
// ==============================================================================

include "compiler/frontend/lexer/tokenizer"
include "src/compiler/backend/targets/arm64/synthesizer.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name
    return 1

fn test_instruction_encoders
    say "\n── [Phase 1]: Validating ARM64 Instruction Encoders ──"

    // 1. arm64_synth_emit32
    s = arm64_synth_new()
    arm64_synth_emit32(s, 3596551104) // RET: 0xD65F03C0 -> [192, 3, 95, 214]
    test_assert_eq(s.synth_code.len(), 4, "arm64_synth_emit32 length is 4")
    test_assert_eq(s.synth_code[0], 192, "RET byte 0 == 0xC0")
    test_assert_eq(s.synth_code[1], 3, "RET byte 1 == 0x03")
    test_assert_eq(s.synth_code[2], 95, "RET byte 2 == 0x5F")
    test_assert_eq(s.synth_code[3], 214, "RET byte 3 == 0xD6")

    // 2. arm64_emit_movz_x(s, reg, imm16, shift)
    s2 = arm64_synth_new()
    arm64_emit_movz_x(s2, 0, 42, 0) // MOVZ X0, #42 -> 0xD2800540 (3531605312)
    test_assert_eq(s2.synth_code.len(), 4, "movz length is 4")
    w_movz = s2.synth_code[0] | (s2.synth_code[1] << 8) | (s2.synth_code[2] << 16) | (s2.synth_code[3] << 24)
    test_assert_eq(w_movz, 3531605312, "arm64_emit_movz_x(0, 42, 0) -> 0xD2800540")

    // 3. arm64_emit_movk_x(s, reg, imm16, shift)
    s3 = arm64_synth_new()
    arm64_emit_movk_x(s3, 0, 1, 16) // MOVK X0, #1, LSL #16 -> 0xF2A00020 (4070572064)
    w_movk = s3.synth_code[0] | (s3.synth_code[1] << 8) | (s3.synth_code[2] << 16) | (s3.synth_code[3] << 24)
    test_assert_eq(w_movk, 4070572064, "arm64_emit_movk_x(0, 1, 16) -> 0xF2A00020")

    // 4. arm64_emit_mov_imm64(s, reg, val)
    s4 = arm64_synth_new()
    arm64_emit_mov_imm64(s4, 1, 4194424) // 0x00400078: c0=120, c1=64
    test_assert_eq(s4.synth_code.len(), 8, "mov_imm64 0x400078 takes 2 instructions (8 bytes)")

    // 5. arm64_emit_add_x(s, rd, rn, rm)
    s5 = arm64_synth_new()
    arm64_emit_add_x(s5, 0, 1, 2) // ADD X0, X1, X2 -> 0x8B020020 (2332164128)
    w_add = s5.synth_code[0] | (s5.synth_code[1] << 8) | (s5.synth_code[2] << 16) | (s5.synth_code[3] << 24)
    test_assert_eq(w_add, 2332164128, "arm64_emit_add_x(0, 1, 2) -> 0x8B020020")

    // 6. arm64_emit_sub_x(s, rd, rn, rm)
    s6 = arm64_synth_new()
    arm64_emit_sub_x(s6, 0, 1, 2) // SUB X0, X1, X2 -> 0xCB020020 (3405905952)
    w_sub = s6.synth_code[0] | (s6.synth_code[1] << 8) | (s6.synth_code[2] << 16) | (s6.synth_code[3] << 24)
    test_assert_eq(w_sub, 3405905952, "arm64_emit_sub_x(0, 1, 2) -> 0xCB020020")

    // 7. arm64_emit_mul_x(s, rd, rn, rm)
    s7 = arm64_synth_new()
    arm64_emit_mul_x(s7, 0, 1, 2) // MUL X0, X1, X2 -> 0x9B027C20 (2600631328)
    w_mul = s7.synth_code[0] | (s7.synth_code[1] << 8) | (s7.synth_code[2] << 16) | (s7.synth_code[3] << 24)
    test_assert_eq(w_mul, 2600631328, "arm64_emit_mul_x(0, 1, 2) -> 0x9B027C20")

    // 8. arm64_emit_sdiv_x(s, rd, rn, rm)
    s8 = arm64_synth_new()
    arm64_emit_sdiv_x(s8, 0, 1, 2) // SDIV X0, X1, X2 -> 0x9AC20C20 (2596408352)
    w_sdiv = s8.synth_code[0] | (s8.synth_code[1] << 8) | (s8.synth_code[2] << 16) | (s8.synth_code[3] << 24)
    test_assert_eq(w_sdiv, 2596408352, "arm64_emit_sdiv_x(0, 1, 2) -> 0x9AC20C20")

    // 9. arm64_emit_cmp_x(s, rn, rm)
    s9 = arm64_synth_new()
    arm64_emit_cmp_x(s9, 0, 1) // SUBS XZR, X0, X1 -> 0xEB01001F (3942711327)
    w_cmp = s9.synth_code[0] | (s9.synth_code[1] << 8) | (s9.synth_code[2] << 16) | (s9.synth_code[3] << 24)
    test_assert_eq(w_cmp, 3942711327, "arm64_emit_cmp_x(0, 1) -> 0xEB01001F")

    // 10. arm64_emit_b_cond(s, cond, offset_words)
    s10 = arm64_synth_new()
    arm64_emit_b_cond(s10, 0, 4) // B.EQ +4 -> 0x54000080 (1409286272)
    w_beq = s10.synth_code[0] | (s10.synth_code[1] << 8) | (s10.synth_code[2] << 16) | (s10.synth_code[3] << 24)
    test_assert_eq(w_beq, 1409286272, "arm64_emit_b_cond(EQ, 4) -> 0x54000080")

    arm64_emit_b_cond(s10, 1, 4) // B.NE +4 -> 0x54000081 (1409286273)
    w_bne = s10.synth_code[4] | (s10.synth_code[5] << 8) | (s10.synth_code[6] << 16) | (s10.synth_code[7] << 24)
    test_assert_eq(w_bne, 1409286273, "arm64_emit_b_cond(NE, 4) -> 0x54000081")

    // 11. arm64_emit_b(s, offset_words)
    s11 = arm64_synth_new()
    arm64_emit_b(s11, 4) // B +4 (16 bytes) -> 0x14000004 (335544324)
    w_b = s11.synth_code[0] | (s11.synth_code[1] << 8) | (s11.synth_code[2] << 16) | (s11.synth_code[3] << 24)
    test_assert_eq(w_b, 335544324, "arm64_emit_b(4) -> 0x14000004")

    arm64_emit_b(s11, 0 - 4) // B -4 (-16 bytes) -> 0x17FFFFFC (402653180)
    w_bneg = s11.synth_code[4] | (s11.synth_code[5] << 8) | (s11.synth_code[6] << 16) | (s11.synth_code[7] << 24)
    test_assert_eq(w_bneg, 402653180, "arm64_emit_b(-4) -> 0x17FFFFFC")

    // 12. arm64_emit_bl(s, offset_words)
    s12 = arm64_synth_new()
    arm64_emit_bl(s12, 10) // BL +10 -> 0x9400000A (2483027978)
    w_bl = s12.synth_code[0] | (s12.synth_code[1] << 8) | (s12.synth_code[2] << 16) | (s12.synth_code[3] << 24)
    test_assert_eq(w_bl, 2483027978, "arm64_emit_bl(10) -> 0x9400000A")

    // 13. arm64_emit_ret(s)
    s13 = arm64_synth_new()
    arm64_emit_ret(s13) // RET X30 -> 0xD65F03C0 (3596551104)
    w_ret = s13.synth_code[0] | (s13.synth_code[1] << 8) | (s13.synth_code[2] << 16) | (s13.synth_code[3] << 24)
    test_assert_eq(w_ret, 3596551104, "arm64_emit_ret() -> 0xD65F03C0")

    // 14. arm64_emit_stp_pre(s, rt1, rt2, rn, imm7)
    s14 = arm64_synth_new()
    arm64_emit_stp_pre(s14, 29, 30, 31, 0 - 16) // STP X29, X30, [SP, #-16]! -> 0xA9BF7BFD (2847898621)
    w_stp = s14.synth_code[0] | (s14.synth_code[1] << 8) | (s14.synth_code[2] << 16) | (s14.synth_code[3] << 24)
    test_assert_eq(w_stp, 2847898621, "arm64_emit_stp_pre(29, 30, 31, -16) -> 0xA9BF7BFD")

    // 15. arm64_emit_ldp_post(s, rt1, rt2, rn, imm7)
    s15 = arm64_synth_new()
    arm64_emit_ldp_post(s15, 29, 30, 31, 16) // LDP X29, X30, [SP], #16 -> 0xA8C17BFD (2831252477)
    w_ldp = s15.synth_code[0] | (s15.synth_code[1] << 8) | (s15.synth_code[2] << 16) | (s15.synth_code[3] << 24)
    test_assert_eq(w_ldp, 2831252477, "arm64_emit_ldp_post(29, 30, 31, 16) -> 0xA8C17BFD")

    // 16. arm64_emit_str_reg_sp(s, rt, sp_offset)
    s16 = arm64_synth_new()
    arm64_emit_str_reg_sp(s16, 0, 16) // STR X0, [SP, #16] -> 0xF9000BE0 (4177529824)
    w_str = s16.synth_code[0] | (s16.synth_code[1] << 8) | (s16.synth_code[2] << 16) | (s16.synth_code[3] << 24)
    test_assert_eq(w_str, 4177529824, "arm64_emit_str_reg_sp(0, 16) -> 0xF9000BE0")

    // 17. arm64_emit_ldr_reg_sp(s, rt, sp_offset)
    s17 = arm64_synth_new()
    arm64_emit_ldr_reg_sp(s17, 0, 16) // LDR X0, [SP, #16] -> 0xF9400BE0 (4181724128)
    w_ldr = s17.synth_code[0] | (s17.synth_code[1] << 8) | (s17.synth_code[2] << 16) | (s17.synth_code[3] << 24)
    test_assert_eq(w_ldr, 4181724128, "arm64_emit_ldr_reg_sp(0, 16) -> 0xF9400BE0")

    // 18. arm64_emit_svc(s, imm16)
    s18 = arm64_synth_new()
    arm64_emit_svc(s18, 0) // SVC #0 -> 0xD4000001 (3556769793)
    w_svc = s18.synth_code[0] | (s18.synth_code[1] << 8) | (s18.synth_code[2] << 16) | (s18.synth_code[3] << 24)
    test_assert_eq(w_svc, 3556769793, "arm64_emit_svc(0) -> 0xD4000001")
    return 1

fn test_high_level_synthesis
    say "\n── [Phase 2]: Validating High-Level Token Stream Compilation ──"

    // Test 1: Simple Top-level return 42
    toks1 = tokenize_source("return 42\n")
    synth1 = arm64_synth_compile_program(toks1)
    test_assert_eq(synth1.synth_code.len() > 0, 1, "Synthesized code not empty for return 42")

    // Test 2: Arithmetic expression and variables
    src2 = "x = 10\ny = 32\nreturn x + y\n"
    toks2 = tokenize_source(src2)
    synth2 = arm64_synth_compile_program(toks2)
    test_assert_eq(synth2.synth_code.len() > 0, 1, "Synthesized code for variables and arithmetic")

    // Test 3: Functions and AAPCS64 parameter calls
    src3 = "fn add a b\n    return a + b\nfn main\n    return add(20, 22)\n"
    toks3 = tokenize_source(src3)
    synth3 = arm64_synth_compile_program(toks3)
    test_assert_eq(synth3.synth_functions.len(), 2, "2 functions recognized")
    test_assert_eq(synth3.synth_call_relocs.len() > 0, 1, "Call relocations recorded and resolved")

    // Test 4: Conditionals: if / elif / else
    src4 = "x = 15\nif x > 10\n    say 1\nelif x == 10\n    say 2\nelse\n    say 3\n"
    toks4 = tokenize_source(src4)
    synth4 = arm64_synth_compile_program(toks4)
    test_assert_eq(synth4.synth_needs_print_int, 1, "print_int helper requested")
    test_assert_eq(synth4.synth_print_int_off > 0, 1, "print_int helper emitted")

    // Test 5: Loops: while and for
    src5 = "i = 0\nwhile i < 10\n    i = i + 1\nfor j in 0..5\n    say j\n"
    toks5 = tokenize_source(src5)
    synth5 = arm64_synth_compile_program(toks5)
    test_assert_eq(synth5.synth_code.len() > 0, 1, "Loops compiled successfully")

    // Test 6: Bengali syntax: কাজ, যদি, ফেরত, বলো
    src6 = "কাজ যোগ ক খ\n    ফেরত ক + খ\nবলো \"স্বাগতম লিপি!\"\n"
    toks6 = tokenize_source(src6)
    synth6 = arm64_synth_compile_program(toks6)
    test_assert_eq(synth6.synth_functions.len(), 1, "Bengali function recognized")
    test_assert_eq(synth6.synth_rodata.len() > 0, 1, "Bengali string in rodata")

    // Test 7: Struct definition, instantiation, and field access
    src7 = "struct Point\n    x\n    y\np = Point(10, 20)\np.x = 30\nreturn p.x\n"
    toks7 = tokenize_source(src7)
    synth7 = arm64_synth_compile_program(toks7)
    test_assert_eq(synth7.synth_structs.len(), 1, "Struct Point defined")
    test_assert_eq(synth7.synth_needs_alloc, 1, "Bump allocator __alloc requested")
    test_assert_eq(synth7.synth_alloc_off > 0, 1, "Bump allocator __alloc emitted")
    return 1

fn test_elf_container_emission
    say "\n── [Phase 3]: Validating ARM64 ELF64 Binary Container Emission ──"

    out_path = "/tmp/test_arm64_synth_exec.elf"
    src = "বলো \"লিপি সার্বভৌম ARM64\"\nreturn 0\n"
    toks = tokenize_source(src)
    synth = arm64_synth_compile_program(toks)

    res = arm64_elf_emit_executable(synth.synth_code, synth.synth_rodata, out_path)
    test_assert_eq(res.ew_success, 1, "arm64_elf_emit_executable success == 1")
    test_assert_eq(res.ew_entry_vaddr, 4194424, "Entry point is 0x400078 (4194424)")
    test_assert_eq(res.ew_file_size > 120, 1, "File size greater than 120 bytes")

    // Read back content from disk to verify headers
    content = file_read(out_path)
    test_assert_eq(len(content), res.ew_file_size, "Read bytes matches written size")

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

    // 7. Program Header: PT_LOAD
    p_type = ord(char_at(content, 64)) + (ord(char_at(content, 65)) * 256) + (ord(char_at(content, 66)) * 65536) + (ord(char_at(content, 67)) * 16777216)
    p_flags = ord(char_at(content, 68)) + (ord(char_at(content, 69)) * 256) + (ord(char_at(content, 70)) * 65536) + (ord(char_at(content, 71)) * 16777216)
    test_assert_eq(p_type, 1, "Program Header p_type == PT_LOAD (1)")
    test_assert_eq(p_flags, 7, "Program Header p_flags == PF_R | PF_W | PF_X (7)")
    return 1

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI SOVEREIGN ARM64 DIRECT MACHINE CODE SYNTHESIZER TEST SUITE"
    say "════════════════════════════════════════════════════════════════════════"

    test_instruction_encoders()
    test_high_level_synthesis()
    test_elf_container_emission()

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL ARM64 MACHINE CODE SYNTHESIS INVARIANTS 100% VALIDATED!"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
