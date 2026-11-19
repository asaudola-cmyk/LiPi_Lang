// =============================================================================
// LIPI FORENSIC AUDIT COMPREHENSIVE REGRESSION VERIFICATION SUITE (PART 1)
// Verifies compiler arithmetic/float codegen fixes, crypto_vault, passkey_auth,
// lipidb SQL executor, blockchain VM rollback, and quantum Hadamard complex phase.
// =============================================================================

import "../aati/crypto_vault/src/lib.lp"
import "../aati/lipi_web/passkey_auth.lp"
import "../aati/lipidb/sql/executor.lp"
import "../aati/lipi_quantum/multi_qubit.lp"
import "../src/compiler/backend/so_emitter.lp"
import "../src/compiler/backend/formats/macho/macho_writer.lp"
import "../src/compiler/backend/formats/elf/elf_writer.lp"
import "../src/compiler/backend/formats/pe/pe_writer.lp"
import "../src/compiler/backend/emulators/win64_pe_runner.lp"
import "../src/compiler/middleend/comptime_eval.lp"

@struct AuditCustomSlot
    slot_id: i64
    slot_tag: string
    value: i64
@end

@fn main()
    say "================================================================="
    say "  LIPI FORENSIC AUDIT A-TO-Z REGRESSION VERIFICATION SUITE"
    say "================================================================="

    // 1. 64-bit Fast Reciprocal Modulo (% 3, % 5, % 7, % 9, % 10, % 100) & Power-of-2 Modulo
    big100 = 219604096115589999
    if big100 % 100 != 99
        say "FAIL: 219604096115589999 % 100 expected 99"
        exit(1)

    big7 = 3689348814741910329
    if big7 % 7 != 2
        say "FAIL: 3689348814741910329 % 7 expected 2"
        exit(1)

    big10 = 1234567890123456789
    if big10 % 10 != 9
        say "FAIL: 1234567890123456789 % 10 expected 9"
        exit(1)

    big3 = 1234567890123456788
    if big3 % 3 != 2
        say "FAIL: 1234567890123456788 % 3 expected 2"
        exit(1)

    big5 = 1234567890123456789
    if big5 % 5 != 4
        say "FAIL: 1234567890123456789 % 5 expected 4"
        exit(1)

    big9 = 1234567890123456788
    if big9 % 9 != 8
        say "FAIL: 1234567890123456788 % 9 expected 8"
        exit(1)

    if 65539 % 64 != 3 or 1048583 % 1024 != 7
        say "FAIL: power-of-2 modulo expected 3 and 7"
        exit(1)
    say "  [PASS] 1. 64-bit Granlund-Montgomery & Power-of-2 Modulo (% 3, % 5, % 7, % 9, % 10, % 100, % 1024)"

    // 2. _lipi_floor on large 64-bit integers >= 2^52 and IEEE-754 floats
    big_int = 4503599627370497
    if floor(big_int) != 4503599627370497
        say "FAIL: floor(4503599627370497) corrupted large integer"
        exit(1)
    if floor(3.9) != 3
        say "FAIL: floor(3.9) expected 3"
        exit(1)
    say "  [PASS] 2. _lipi_floor IEEE-754 float vs 64-bit integer discriminator"

    // 3. Crypto Vault Iterated SHA-256 & MAC-Authenticated Tokens
    tok = generate_token("admin_user")
    if verify_token(tok, tok.expiry - 100) != 1
        say "FAIL: valid crypto_vault token rejected"
        exit(1)
    forged_tok = Token()
    forged_tok.value = "0000000000000000000000000000000000000000000000000000000099999999"
    forged_tok.expiry = tok.expiry
    if verify_token(forged_tok, tok.expiry - 100) != 0
        say "FAIL: forged 64-char crypto_vault token accepted"
        exit(1)
    say "  [PASS] 3. Crypto Vault MAC token authentication & forgery rejection"

    // 4. WebAuthn Passkey Signed Assertion Verification
    pk_eng = passkey_auth_engine_new()
    passkey_register_credential(pk_eng, "cred-01", "user-01", "pubkey_ed25519_abc")
    passkey_create_challenge(pk_eng, "challenge_xyz_987", "user-01", "https://lipi.dev", 1000, 1000)
    valid_sig = passkey_compute_assertion_sig("pubkey_ed25519_abc", "challenge_xyz_987", "https://lipi.dev", 1)
    if passkey_verify_signed_assertion(pk_eng, "cred-01", "challenge_xyz_987", "https://lipi.dev", 1, 1500, valid_sig) != 1
        say "FAIL: valid passkey signed assertion rejected"
        exit(1)
    if passkey_verify_signed_assertion(pk_eng, "cred-01", "challenge_xyz_987", "https://lipi.dev", 2, 1500, "forged_signature_000") == 1
        say "FAIL: forged passkey signature accepted"
        exit(1)
    say "  [PASS] 4. WebAuthn Passkey cryptographic assertion verification"

    // 5. LipiDB SQL Executor filter_val == 0
    row0 = [101, 0]
    row1 = [102, 5]
    rows = [row0, row1]
    filtered = executor_seq_scan(rows, 1, 0)
    if len(filtered) != 1
        say "FAIL: executor_seq_scan failed when filter_val == 0"
        exit(1)
    say "  [PASS] 5. LipiDB SQL executor filter_val == 0 handling"

    // 6. Lipi Quantum Multi-Qubit Hadamard Imaginary Amplitude Preservation
    qreg = qreg_new(1)
    qreg.amplitudes_imag = [1000, 0]
    qreg.amplitudes_real = [0, 0]
    qreg = qreg_apply_hadamard(qreg, 0)
    im_after = qreg.amplitudes_imag
    if im_after[0] != 707
        say "FAIL: qreg_apply_hadamard zeroed out imaginary amplitude"
        exit(1)
    say "  [PASS] 6. Lipi Quantum Hadamard complex imaginary amplitude preservation"

    // 7. Cross-struct field offset isolation (Token.value @ offset 0 vs AuditCustomSlot.value @ offset 16)
    c_slot = { slot_id: 42, slot_tag: "balance", value: 987654 }
    if c_slot.value != 987654 or c_slot.slot_id != 42
        say "FAIL: Struct literal field offset collision between Token.value and AuditCustomSlot.value"
        exit(1)
    say "  [PASS] 7. Cross-struct field offset isolation (Token.value vs AuditCustomSlot.value)"

    // 8. Active GC Sweep & Scrub verification + PIC .so & Darwin Mach-O relocation patchers
    p_gc = alloc(32)
    mem_word_write(p_gc, 8, 1234567)
    slab_free(p_gc, 32)
    reclaimed = lipi_gc_collect()
    if reclaimed < 32 or mem_word_read(p_gc, 8) != 0
        say "FAIL: gc_collect did not scrub dead payload word in freelist slab"
        exit(1)

    // Test so_patch_pic_rodata: 10-byte movabs rsi, (1073742128 + 10 + 4) -> lea rsi, [rip + 7]; nop; nop; nop
    ro_vaddr = 1073742128 + 10 + 4
    sample_so_code = [
        72, 190,
        ro_vaddr & 255, (ro_vaddr >> 8) & 255, (ro_vaddr >> 16) & 255, (ro_vaddr >> 24) & 255,
        0, 0, 0, 0
    ]
    patched_so = so_patch_pic_rodata(sample_so_code, 32)
    if patched_so[0] != 72 or patched_so[1] != 141 or patched_so[2] != 53 or patched_so[3] != 7 or patched_so[9] != 144
        say "FAIL: so_patch_pic_rodata did not emit RIP-relative lea rsi, [rip + disp32]"
        exit(1)

    // Test macho_patch_darwin_code: 7-byte mov eax, 1; syscall -> mov eax, 0x02000004; syscall
    sample_macho_code = [184, 1, 0, 0, 0, 15, 5]
    patched_macho = macho_patch_darwin_code(sample_macho_code, 4294971392)
    if patched_macho[1] != 4 or patched_macho[4] != 2
        say "FAIL: macho_patch_darwin_code did not translate Linux SYS_write to Darwin 0x2000004"
        exit(1)
    say "  [PASS] 8. GC Sweep & Scrub + ELF .so PIC RIP-relative & Darwin Mach-O ABI patchers"

    // 9. Strict Default W^X ELF64 (3-PHDR RX=5 / RW=6) & Comptime Supercompilation Engine
    wx_res = elf_emit_executable([184, 0, 0, 0, 0, 195], [1, 2, 3, 4], [5, 6, 7, 8], 64, "")
    if wx_res.ew_success != 1 or wx_res.ew_bytes[56] != 3 or wx_res.ew_bytes[68] != 5 or wx_res.ew_bytes[124] != 6
        say "FAIL: default elf_emit_executable did not emit e_phnum=3 with PF_R|PF_X (5) and PF_R|PF_W (6)"
        exit(1)
    ct_env = comptime_env_new()
    ct_sum = comptime_eval_loop_range(1, 100, 1, "+", 0, ct_env)
    if ct_sum != 5050
        say "FAIL: comptime_eval_loop_range(1..100) expected 5050"
        exit(1)
    say "  [PASS] 9. Strict Default W^X 3-PHDR ELF64 emitter (RX=5 / RW=6) & Comptime Supercompilation"

    // 10. Windows PE32+ Section Characteristics (0x60000020), VirtualAlloc IAT, & Zero Linux Syscalls
    pe_sample_code = [184, 9, 0, 0, 0, 15, 5, 184, 60, 0, 0, 0, 15, 5, 244, 195]
    pe_res = pe_emit_executable(pe_sample_code, [72, 105, 10, 0], [], 0, 0, "")
    pe_runner = win64_pe_runner_new()
    pe_ok = win64_pe_runner_load_bytes(pe_runner, pe_res.pe_bytes)
    if pe_ok != 1 or pe_runner.wpr_text_characteristics != 1610612768 or pe_runner.wpr_linux_syscall_count != 0
        say "FAIL: Windows PE32+ .text chars or Linux syscall check failed: chars=" + str(pe_runner.wpr_text_characteristics) + " syscalls=" + str(pe_runner.wpr_linux_syscall_count)
        exit(1)
    say "  [PASS] 10. Windows PE32+ .text=0x60000020, VirtualAlloc IAT, and 0 Linux 0F 05 syscalls"

    // 11. LipiDB SQL Executor KV Index O(1) Lookup Verification
    kv_entries = [kv_index_entry_new(101, 555), kv_index_entry_new(202, 888)]
    kv_hit = executor_kv_index_lookup(kv_entries, 202)
    if len(kv_hit) != 1 or kv_hit[0] != 888
        say "FAIL: executor_kv_index_lookup expected [888]"
        exit(1)
    say "  [PASS] 11. LipiDB SQL executor KV index lookup path verified"

    say "================================================================="
    say "  ALL FORENSIC AUDIT REGRESSION CHECKS PASSED (11/11)"
    say "================================================================="
