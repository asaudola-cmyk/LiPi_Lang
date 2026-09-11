@! ============================================================================
@! ADVERSARIAL TEST SUITE: OMNI-BINARY TRAMPOLINE EXECUTION & HEADER INTEGRITY
@! File: tests/adversarial/test_phase2_omni_adversarial.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/omni_binary"

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] " + msg)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("💿 ADVERSARIAL OMNI-BINARY TRAMPOLINE & HEADER OFFSETS SUITE 💿")
  println("=================================================================")

  total = 0
  passed = 0

  @! SECTION 1: Offsets and Bit-Exact Header Layout Verification
  println("▶ Section 1: Bit-Exact Header Offsets Verification...")
  total = total + 1

  pe_dummy = [80, 69, 1, 2, 3, 4]
  elf_dummy = [127, 69, 76, 70, 2, 1, 1, 0]
  macho_dummy = [207, 250, 237, 254, 7, 0, 0, 1]

  pkg = omni_binary_pack(pe_dummy, elf_dummy, macho_dummy, "TEST_KEY_ADVERSARIAL")
  raw = pkg.polyglot_raw_bytes

  ok1 = assert_eq_int(raw[0], 77, "Byte 0 is 'M'")
  ok2 = assert_eq_int(raw[1], 90, "Byte 1 is 'Z'")
  ok3 = assert_eq_int(raw[2], 113, "Byte 2 is 'q'")
  ok4 = assert_eq_int(raw[3], 70, "Byte 3 is 'F'")
  ok5 = assert_eq_int(raw[4], 112, "Byte 4 is 'p'")
  ok6 = assert_eq_int(raw[5], 68, "Byte 5 is 'D'")
  ok7 = assert_eq_int(raw[6], 61, "Byte 6 is '='")
  ok8 = assert_eq_int(raw[7], 39, "Byte 7 is '\''")

  @! e_lfanew at 0x3C = 60
  ok9 = assert_eq_int(raw[60], 0, "e_lfanew byte 0 is 0x00")
  ok10 = assert_eq_int(raw[61], 1, "e_lfanew byte 1 is 0x01 (256 / 0x100)")
  ok11 = assert_eq_int(raw[62], 0, "e_lfanew byte 2 is 0x00")
  ok12 = assert_eq_int(raw[63], 0, "e_lfanew byte 3 is 0x00")

  @! ELF at 0x40 = 64
  ok13 = assert_eq_int(raw[64], 127, "ELF magic byte 0 is 0x7F")
  ok14 = assert_eq_int(raw[65], 69, "ELF magic byte 1 is 'E'")
  ok15 = assert_eq_int(raw[66], 76, "ELF magic byte 2 is 'L'")
  ok16 = assert_eq_int(raw[67], 70, "ELF magic byte 3 is 'F'")

  @! Mach-O at 0x80 = 128
  ok17 = assert_eq_int(raw[128], 207, "Mach-O magic byte 0 is 0xCF")
  ok18 = assert_eq_int(raw[129], 250, "Mach-O magic byte 1 is 0xFA")
  ok19 = assert_eq_int(raw[130], 237, "Mach-O magic byte 2 is 0xED")
  ok20 = assert_eq_int(raw[131], 254, "Mach-O magic byte 3 is 0xFE")

  @! PE at 0x100 = 256
  ok21 = assert_eq_int(raw[256], 80, "PE magic byte 0 is 'P'")
  ok22 = assert_eq_int(raw[257], 69, "PE magic byte 1 is 'E'")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1 && ok12 == 1 && ok13 == 1 && ok14 == 1 && ok15 == 1 && ok16 == 1 && ok17 == 1 && ok18 == 1 && ok19 == 1 && ok20 == 1 && ok21 == 1 && ok22 == 1
    passed = passed + 1
    println("  [PASS] Polyglot header offsets (0x3C=256, 0x40=ELF, 0x80=Mach-O, 0x100=PE) verified")
  @end

  @! SECTION 2: Emission to Disk
  println("▶ Section 2: Disk Emission of Omni-Binary...")
  total = total + 1
  out_path = "/tmp/test_omni_adversarial"
  status = omni_write_executable(out_path, pkg)
  ok_disk = assert_true(status > 0, "Omni-Binary emitted to disk")
  @if ok_disk == 1
    passed = passed + 1
    println("  [PASS] Binary written to disk successfully")
  @end

  println("=================================================================")
  println("📊 OMNI-BINARY STRUCTURAL RESULTS: " + passed.to_str() + " / " + total.to_str() + " passed")
  println("=================================================================")
  return 0
@end
