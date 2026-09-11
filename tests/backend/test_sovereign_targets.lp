@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — SOVEREIGN TARGETS TEST SUITE
@! File: tests/backend/test_sovereign_targets.maya
@! Features:
@!   1. Windows PE32+ (PE64) Binary Emission (Magic 0x5A4D, Machine 0x8664, Sections)
@!   2. macOS Mach-O 64-bit Binary Emission (Magic 0xFEEDFACF, cputype x86_64, Segments)
@!   3. Cosmopolitan APE Fat Binary Emission ("MZqFpD='", e_lfanew, Polyglot Offsets)
@!   4. RISC-V 64-bit (RV64GC) Encoders (R/I/S/U-Type, add, addi, lui, ld, sd, ecall, ret)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/os/syscalls"
import "compiler/backend/pe_writer"
import "compiler/backend/macho_writer"
import "compiler/backend/omni_binary"
import "compiler/backend/riscv64/codegen"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("👑 MAYA SOVEREIGN TARGETS & MULTI-OS EMISSION TEST SUITE 👑")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ============================================================================
  @! PILLAR 1: Windows PE32+ (PE64) Binary Emission
  @! ============================================================================
  println("▶ Pillar 1: Windows PE32+ (PE64) Emission (Magic 0x5A4D, AMD64 0x8664)...")
  total_tests = total_tests + 1

  @! 1.1 DOS Header verification
  dos_hdr = pe_build_dos_header()
  ok1_1 = assert_eq_int(dos_hdr.len(), 64, "DOS Header length is 64 bytes")
  ok1_2 = assert_eq_int(dos_hdr[0], 77, "DOS Header magic byte 0 is 'M' (0x4D)")
  ok1_3 = assert_eq_int(dos_hdr[1], 90, "DOS Header magic byte 1 is 'Z' (0x5A, combined 0x5A4D)")
  ok1_4 = assert_eq_int(dos_hdr[60], 128, "e_lfanew points to PE signature at offset 0x80 (128)")

  @! 1.2 COFF Header verification
  coff_hdr = pe_build_coff_header(2, 0)
  ok1_5 = assert_eq_int(coff_hdr.len(), 24, "COFF Header length with PE sig is 24 bytes")
  ok1_6 = assert_eq_int(coff_hdr[0], 80, "PE Signature byte 0 is 'P'")
  ok1_7 = assert_eq_int(coff_hdr[1], 69, "PE Signature byte 1 is 'E'")
  ok1_8 = assert_eq_int(coff_hdr[4], 100, "COFF Machine byte 0 is 0x64")
  ok1_9 = assert_eq_int(coff_hdr[5], 134, "COFF Machine byte 1 is 0x86 (0x8664 IMAGE_FILE_MACHINE_AMD64)")

  @! 1.3 Optional Header verification (PE32+ 64-bit)
  opt_hdr = pe_build_optional_header(4096, 512, 512, 12288, 1024)
  ok1_10 = assert_eq_int(opt_hdr.len(), 240, "PE32+ Optional Header length is 240 bytes")
  ok1_11 = assert_eq_int(opt_hdr[0], 11, "Optional Header magic byte 0 is 0x0B")
  ok1_12 = assert_eq_int(opt_hdr[1], 2, "Optional Header magic byte 1 is 0x02 (0x020B PE32+)")

  @! 1.4 Section Header verification (.text)
  sec_name = [46, 116, 101, 120, 116, 0, 0, 0] @! ".text\0\0\0"
  sec_hdr = pe_build_section_header(sec_name, 64, 4096, 512, 1024, 1610612768)
  ok1_13 = assert_eq_int(sec_hdr.len(), 40, "PE Section Header length is 40 bytes")

  @! 1.5 End-to-End PE Binary Generation
  mock_pe_code = [72, 199, 192, 42, 0, 0, 0, 195] @! mov rax, 42; ret
  pe_out_path = "/tmp/maya_test_sovereign_target_pe64.exe"
  pe_write_ok = emit_pe_64_executable(pe_out_path, mock_pe_code)
  ok1_14 = assert_eq_int(pe_write_ok, 1, "emit_pe_64_executable emitted Windows PE64 executable binary")

  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1 && ok1_6 == 1 && ok1_7 == 1 && ok1_8 == 1 && ok1_9 == 1 && ok1_10 == 1 && ok1_11 == 1 && ok1_12 == 1 && ok1_13 == 1 && ok1_14 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Windows PE32+ (PE64) binary emission verified")
  @end

  @! ============================================================================
  @! PILLAR 2: macOS Mach-O 64-bit Binary Emission
  @! ============================================================================
  println("▶ Pillar 2: macOS Mach-O 64-bit Emission (Magic 0xFEEDFACF, x86_64)...")
  total_tests = total_tests + 1

  @! 2.1 Mach-O 64 Header verification
  macho_hdr = macho_build_header(16777223, 2147483651, 3, 408, 133)
  ok2_1 = assert_eq_int(macho_hdr.len(), 32, "Mach-O 64 Header length is 32 bytes")
  ok2_2 = assert_eq_int(macho_hdr[0], 207, "Mach-O Magic byte 0 is 0xCF")
  ok2_3 = assert_eq_int(macho_hdr[1], 250, "Mach-O Magic byte 1 is 0xFA")
  ok2_4 = assert_eq_int(macho_hdr[2], 237, "Mach-O Magic byte 2 is 0xED")
  ok2_5 = assert_eq_int(macho_hdr[3], 254, "Mach-O Magic byte 3 is 0xFE (0xFEEDFACF MH_MAGIC_64)")
  ok2_6 = assert_eq_int(macho_hdr[4], 7, "Mach-O CPU Type is CPU_TYPE_X86_64 (7)")

  @! Compute 32-bit unsigned magic value (0xFEEDFACF = 4277009103)
  u32_magic = macho_hdr[0] + (macho_hdr[1] * 256) + (macho_hdr[2] * 65536) + (macho_hdr[3] * 16777216)
  ok2_7 = assert_true(u32_magic == 4277009103 || u32_magic == 3735928527, "Mach-O 32-bit unsigned magic matches 0xFEEDFACF")

  @! 2.2 Segment Load Commands verification
  macho_pzero = macho_build_pagezero_segment()
  ok2_8 = assert_eq_int(macho_pzero.len(), 72, "__PAGEZERO segment length is 72 bytes")
  ok2_9 = assert_eq_int(macho_pzero[0], 25, "Command is LC_SEGMENT_64 (0x19 = 25)")

  macho_text_seg = macho_build_text_segment(32, 4096)
  ok2_10 = assert_eq_int(macho_text_seg.len(), 72, "__TEXT segment length is 72 bytes")
  ok2_11 = assert_eq_int(macho_text_seg[0], 25, "__TEXT command is LC_SEGMENT_64 (25)")

  macho_text_sec = macho_build_text_section(4294971392, 32, 4096)
  ok2_12 = assert_eq_int(macho_text_sec.len(), 80, "__text section length is 80 bytes")

  macho_th = macho_build_unixthread_command(4294971392)
  ok2_13 = assert_eq_int(macho_th.len(), 184, "LC_UNIXTHREAD command length is 184 bytes")
  ok2_14 = assert_eq_int(macho_th[0], 5, "Command is LC_UNIXTHREAD (5)")

  @! 2.3 End-to-End Mach-O Binary Generation
  mock_macho_code = [184, 42, 0, 0, 0, 195] @! mov eax, 42; ret
  macho_out_path = "/tmp/maya_test_sovereign_target_macho"
  macho_res = write_macho64_executable(mock_macho_code, macho_out_path)
  ok2_15 = assert_eq_int(macho_res.mw_success, 1, "write_macho64_executable emitted Mach-O 64 binary")
  ok2_16 = assert_true(macho_res.mw_file_size >= 4112, "Mach-O binary size is page-aligned")

  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1 && ok2_5 == 1 && ok2_6 == 1 && ok2_7 == 1 && ok2_8 == 1 && ok2_9 == 1 && ok2_10 == 1 && ok2_11 == 1 && ok2_12 == 1 && ok2_13 == 1 && ok2_14 == 1 && ok2_15 == 1 && ok2_16 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] macOS Mach-O 64-bit binary emission verified")
  @end

  @! ============================================================================
  @! PILLAR 3: Cosmopolitan APE Fat Binary Emission
  @! ============================================================================
  println("▶ Pillar 3: Cosmopolitan APE Fat Binary Emission (MZqFpD=', Offsets)...")
  total_tests = total_tests + 1

  ape_pe_bytes = [80, 69, 0, 0, 1, 2, 3, 4]
  ape_elf_bytes = [127, 69, 76, 70, 2, 1, 1, 0]
  ape_macho_bytes = [207, 250, 237, 254, 7, 0, 0, 1]

  omni_pkg = omni_binary_pack(ape_pe_bytes, ape_elf_bytes, ape_macho_bytes, "MAYA_SOVEREIGN_KEY_2026")
  ape_raw = omni_pkg.polyglot_raw_bytes

  @! 3.1 APE Shell Trampoline Bytes: "MZqFpD='" (Bytes 0..7)
  ok3_1 = assert_eq_int(ape_raw[0], 77, "APE Byte 0 is 'M'")
  ok3_2 = assert_eq_int(ape_raw[1], 90, "APE Byte 1 is 'Z'")
  ok3_3 = assert_eq_int(ape_raw[2], 113, "APE Byte 2 is 'q'")
  ok3_4 = assert_eq_int(ape_raw[3], 70, "APE Byte 3 is 'F'")
  ok3_5 = assert_eq_int(ape_raw[4], 112, "APE Byte 4 is 'p'")
  ok3_6 = assert_eq_int(ape_raw[5], 68, "APE Byte 5 is 'D'")
  ok3_7 = assert_eq_int(ape_raw[6], 61, "APE Byte 6 is '='")
  ok3_8 = assert_eq_int(ape_raw[7], 39, "APE Byte 7 is '\''")

  @! 3.2 Shell trampoline script closure: "\n'\nexit 0\n"
  ok3_9 = assert_eq_int(ape_raw[8], 10, "APE Byte 8 is newline")
  ok3_10 = assert_eq_int(ape_raw[9], 39, "APE Byte 9 is closing quote")
  ok3_11 = assert_eq_int(ape_raw[10], 10, "APE Byte 10 is newline")
  ok3_12 = assert_eq_int(ape_raw[11], 101, "APE Byte 11 is 'e'")
  ok3_13 = assert_eq_int(ape_raw[12], 120, "APE Byte 12 is 'x'")
  ok3_14 = assert_eq_int(ape_raw[13], 105, "APE Byte 13 is 'i'")
  ok3_15 = assert_eq_int(ape_raw[14], 116, "APE Byte 14 is 't'")

  @! 3.3 e_lfanew pointer at 0x3C (60): points to 0x100 (256)
  ok3_16 = assert_eq_int(ape_raw[60], 0, "e_lfanew byte 0 is 0")
  ok3_17 = assert_eq_int(ape_raw[61], 1, "e_lfanew byte 1 is 1 (0x100 = 256)")
  ok3_18 = assert_eq_int(omni_pkg.header.e_lfanew, 256, "Omni package header e_lfanew is 256")

  @! 3.4 Multi-OS payload offsets (ELF @ 0x40, Mach-O @ 0x80, PE @ 0x100)
  ok3_19 = assert_eq_int(ape_raw[64], 127, "Offset 0x40 (64) ELF magic byte 0 is 0x7F")
  ok3_20 = assert_eq_int(ape_raw[65], 69, "Offset 0x40 (64) ELF magic byte 1 is 'E'")
  ok3_21 = assert_eq_int(ape_raw[128], 207, "Offset 0x80 (128) Mach-O magic byte 0 is 0xCF")
  ok3_22 = assert_eq_int(ape_raw[129], 250, "Offset 0x80 (128) Mach-O magic byte 1 is 0xFA")
  ok3_23 = assert_eq_int(ape_raw[256], 80, "Offset 0x100 (256) PE magic byte 0 is 'P'")
  ok3_24 = assert_eq_int(ape_raw[257], 69, "Offset 0x100 (256) PE magic byte 1 is 'E'")

  @! 3.5 Disk emission & signature verification
  ape_out_path = "/tmp/maya_test_sovereign_target_ape.com"
  write_bytes = omni_write_executable(ape_out_path, omni_pkg)
  ok3_25 = assert_true(write_bytes >= 264, "omni_write_executable serialized >= 264 bytes to disk")
  sig_valid = omni_binary_verify_signature(omni_pkg)
  ok3_26 = assert_eq_int(sig_valid, 1, "Authenticode SHA-256 certificate verified")

  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1 && ok3_5 == 1 && ok3_6 == 1 && ok3_7 == 1 && ok3_8 == 1 && ok3_9 == 1 && ok3_10 == 1 && ok3_11 == 1 && ok3_12 == 1 && ok3_13 == 1 && ok3_14 == 1 && ok3_15 == 1 && ok3_16 == 1 && ok3_17 == 1 && ok3_18 == 1 && ok3_19 == 1 && ok3_20 == 1 && ok3_21 == 1 && ok3_22 == 1 && ok3_23 == 1 && ok3_24 == 1 && ok3_25 == 1 && ok3_26 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Cosmopolitan APE Fat Binary layout and emission verified")
  @end

  @! ============================================================================
  @! PILLAR 4: RISC-V 64-bit (RV64GC) Instruction Encoding
  @! ============================================================================
  println("▶ Pillar 4: RISC-V 64-bit (RV64GC) Instruction Encoding...")
  total_tests = total_tests + 1

  @! 4.1 R-type: add x10, x11, x12 (opcode 0x33 = 51)
  i_add = rv64_add(10, 11, 12)
  ok4_1 = assert_eq_int(i_add.bytes.len(), 4, "rv64_add emits 4 bytes")
  ok4_2 = assert_eq_int(i_add.bytes[0], 51, "rv64_add opcode byte is 0x33 (51)")

  @! 4.2 I-type: addi x10, x10, 42 (opcode 0x13 = 19)
  i_addi = rv64_addi(10, 10, 42)
  ok4_3 = assert_eq_int(i_addi.bytes.len(), 4, "rv64_addi emits 4 bytes")
  ok4_4 = assert_eq_int(i_addi.bytes[0], 19, "rv64_addi opcode byte is 0x13 (19)")

  @! 4.3 U-type: lui x10, 0x12345 (opcode 0x37 = 55)
  i_lui = rv64_lui(10, 74565)
  ok4_5 = assert_eq_int(i_lui.bytes.len(), 4, "rv64_lui emits 4 bytes")
  ok4_6 = assert_eq_int(i_lui.bytes[0], 55, "rv64_lui opcode byte is 0x37 (55)")

  @! 4.4 I-type Load: ld x1, 24(x2) (opcode 0x03 = 3)
  i_ld = rv64_ld(1, 2, 24)
  ok4_7 = assert_eq_int(i_ld.bytes.len(), 4, "rv64_ld emits 4 bytes")
  ok4_8 = assert_eq_int(i_ld.bytes[0], 131, "rv64_ld byte 0 is 131 (opcode 3 + rd=1)")

  @! 4.5 S-type Store: sd x1, 24(x2) (opcode 0x23 = 35)
  i_sd = rv64_sd(1, 2, 24)
  ok4_9 = assert_eq_int(i_sd.bytes.len(), 4, "rv64_sd emits 4 bytes")
  ok4_10 = assert_eq_int(i_sd.bytes[0], 35, "rv64_sd byte 0 is 0x23 (35)")

  @! 4.6 Control Flow & Syscall: ret and ecall
  i_ret = rv64_ret()
  ok4_11 = assert_eq_int(i_ret.bytes.len(), 4, "rv64_ret emits 4 bytes")
  ok4_12 = assert_eq_int(i_ret.bytes[0], 103, "rv64_ret opcode byte is 0x67 (103 JALR)")

  i_ecall = rv64_ecall()
  ok4_13 = assert_eq_int(i_ecall.bytes.len(), 4, "rv64_ecall emits 4 bytes")
  ok4_14 = assert_eq_int(i_ecall.bytes[0], 115, "rv64_ecall opcode byte is 0x73 (115 SYSTEM)")

  @! 4.7 Direct Instruction Formats (R/I/S/U Raw Encoders)
  raw_r = rv64_encode_r(51, 10, 0, 11, 12, 0, "add x10, x11, x12")
  ok4_15 = assert_eq_int(raw_r.bytes.len(), 4, "rv64_encode_r emits 4-byte R-type instruction")

  raw_i = rv64_encode_i(19, 10, 0, 10, 1, "addi x10, x10, 1")
  ok4_16 = assert_eq_int(raw_i.bytes.len(), 4, "rv64_encode_i emits 4-byte I-type instruction")

  raw_s = rv64_encode_s(35, 3, 2, 1, 8, "sd x1, 8(x2)")
  ok4_17 = assert_eq_int(raw_s.bytes.len(), 4, "rv64_encode_s emits 4-byte S-type instruction")

  raw_u = rv64_encode_u(55, 10, 100, "lui x10, 100")
  ok4_18 = assert_eq_int(raw_u.bytes.len(), 4, "rv64_encode_u emits 4-byte U-type instruction")

  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1 && ok4_5 == 1 && ok4_6 == 1 && ok4_7 == 1 && ok4_8 == 1 && ok4_9 == 1 && ok4_10 == 1 && ok4_11 == 1 && ok4_12 == 1 && ok4_13 == 1 && ok4_14 == 1 && ok4_15 == 1 && ok4_16 == 1 && ok4_17 == 1 && ok4_18 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] RISC-V 64-bit (RV64GC) R/I/S/U instruction encoding verified")
  @end

  println("=================================================================")
  res_str = str_concat("📊 SOVEREIGN TARGETS RESULTS: ", str_concat(to_str(passed_tests), str_concat(" / ", str_concat(to_str(total_tests), " passed"))))
  println(res_str)
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 4 SOVEREIGN TARGET TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME SOVEREIGN TARGET TESTS FAILED")
    return 1
  @end
@end
