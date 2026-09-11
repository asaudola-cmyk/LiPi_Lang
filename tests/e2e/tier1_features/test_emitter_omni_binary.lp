// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Omni-Binary APE Polyglot Emitter PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: compiler, backend, omni_binary, ape, polyglot, emitter

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: OMNI-BINARY APE POLYGLOT FAT EMITTER
@! File: tests/e2e/tier1_features/test_emitter_omni_binary.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/os/syscalls"
import "compiler/backend/omni_binary"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 6: Omni-Binary Cosmopolitan APE Polyglot Emitter")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Construct sample payload slices
  pe_payload = [1, 2, 3, 4, 5, 6, 7, 8]
  elf_payload = [10, 20, 30, 40, 50, 60, 70, 80]
  macho_payload = [100, 101, 102, 103, 104, 105, 106, 107]
  dev_key = "maya_sovereign_dev_key_2026"

  omni_pkg = omni_pack_binary(pe_payload, elf_payload, macho_payload, dev_key)
  raw = omni_pkg.polyglot_raw_bytes

  @! T1.1: Cosmopolitan APE Shell Trampoline Magic String ("MZqFpD='")
  total = total + 1
  @! Bytes 0..7: [77, 90, 113, 70, 112, 68, 61, 39]
  is_mz_ape = raw[0] == 77 && raw[1] == 90 && raw[2] == 113 && raw[3] == 70 && raw[4] == 112 && raw[5] == 68 && raw[6] == 61 && raw[7] == 39
  @if is_mz_ape
    passed = passed + 1
    println("  [PASS] T1.1: Cosmopolitan APE shell trampoline ASCII header ('MZqFpD=\\'')")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: APE shell trampoline header")
  @end

  @! T1.2: Embedded Shell Trampoline Script
  total = total + 1
  @! Offset 8..14: "\n'\nexit 0" (10, 39, 10, 101, 120, 105, 116)
  is_shell_script = raw[8] == 10 && raw[9] == 39 && raw[10] == 10 && raw[11] == 101 && raw[12] == 120
  @if is_shell_script
    passed = passed + 1
    println("  [PASS] T1.2: Shell script trampoline payload (\\n'\\nexit 0)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Shell script trampoline")
  @end

  @! T1.3: DOS Header e_lfanew Pointer at Offset 0x3C
  total = total + 1
  @! Offset 60..63: [0, 1, 0, 0] = 256 (0x100)
  e_lfanew_val = raw[60] | (raw[61] * 256) | (raw[62] * 65536) | (raw[63] * 16777216)
  @if e_lfanew_val == 256 && omni_pkg.header.e_lfanew == 256
    passed = passed + 1
    println("  [PASS] T1.3: DOS Header e_lfanew pointer at offset 0x3C pointing to 0x100 (256)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: DOS e_lfanew pointer")
  @end

  @! T1.4: Linux ELF64 Header Offset (0x40 = 64) & Mach-O Header Offset (0x80 = 128)
  total = total + 1
  @! Offset 64: \x7F, 'E', 'L', 'F' = [127, 69, 76, 70]
  is_elf = raw[64] == 127 && raw[65] == 69 && raw[66] == 76 && raw[67] == 70
  @! Offset 128: 0xFEEDFACF = [207, 250, 237, 254]
  is_macho = raw[128] == 207 && raw[129] == 250 && raw[130] == 237 && raw[131] == 254
  @! Offset 256: 'P', 'E', 0, 0 = [80, 69, 0, 0]
  is_pe = raw[256] == 80 && raw[257] == 69 && raw[258] == 0 && raw[259] == 0
  @if is_elf && is_macho && is_pe
    passed = passed + 1
    println("  [PASS] T1.4: Polyglot Multi-OS headers (ELF64 at 0x40, Mach-O at 0x80, PE at 0x100)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: Polyglot Multi-OS headers")
  @end

  @! T1.5: Authenticode Code Signature Verification
  total = total + 1
  sig_valid = omni_binary_verify_signature(omni_pkg)
  @if sig_valid == 1 && str_len(omni_pkg.header.code_signature_sha256) == 64
    passed = passed + 1
    println("  [PASS] T1.5: Authenticode SHA-256 signature verification and header integrity")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Code signature verification")
  @end

  @! T1.6: Executable Binary File Emission to Disk
  total = total + 1
  pid = sys_getpid()
  omni_path = "/tmp/maya_t1_omni_" + maya_int_to_str(pid) + ".bin"
  status = omni_write_executable(omni_path, omni_pkg)
  
  fd = sys_open(omni_path, 0, 0)
  sys_close(fd)
  sys_unlink(omni_path)

  @if status > 0 && fd > 0
    passed = passed + 1
    println("  [PASS] T1.6: Complete Omni-Binary polyglot package serialization (bytes written=" + status.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: Executable file emission")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 6 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Omni-Binary APE Polyglot Emitter PASSED")
    return 0
  @else
    println("✗ Feature: Omni-Binary APE Polyglot Emitter FAILED")
    return 1
  @end
@end
