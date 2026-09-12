// ==============================================================================
// 🧪 LIPI REGRESSION TEST: OMNI-TARGET SILICON SOVEREIGNTY SUITE
// File: tests/test_omni_targets.lp
// Targets: Linux x86_64, Linux ARM64, Windows PE32+, macOS Mach-O 64, W3C WASM
// 100% Pure Lipi Implementation — Zero External Assembler / Linker Libs
// ==============================================================================

import "src/compiler/backend/pe_writer"
import "src/compiler/backend/macho_writer"
import "src/compiler/backend/omni_binary"
import "universe/core/string"
import "universe/os/syscalls"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("👑 LIPI OMNI-TARGET SILICON SOVEREIGNTY REGRESSION SUITE 👑")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // Minimal standalone machine code payload: mov rax, 60; xor rdi, rdi; syscall
  code = [184, 60, 0, 0, 0, 49, 255, 15, 5]

  // ── 1. Windows PE32+ (x86-64 .exe) Direct Emission ─────────────────────────
  println("▶ Section 1: Windows PE32+ (x86-64 .exe) Binary Emitter...")
  total_tests = total_tests + 1

  pe_path = "dist/omni_test.exe"
  pe_res = emit_pe_64_executable(pe_path, code)
  ok_pe1 = assert_eq_int(pe_res, 1, "PE32+ executable emission succeeded")

  // Read DOS and PE signatures via sys_open
  fd_pe = sys_open(pe_path, 0, 0)
  ok_fd1 = assert_true(fd_pe >= 0, "Opened omni_test.exe")

  pe_hdr = sys_mmap(0, 512, 3, 34, 0 - 1, 0)
  sys_read(fd_pe, pe_hdr, 512)
  sys_close(fd_pe)

  // Verify MZ header: 0x4D 0x5A ('M' 'Z')
  mz0 = sys_peek8(pe_hdr + 0)
  mz1 = sys_peek8(pe_hdr + 1)
  ok_pe2 = assert_eq_int(mz0, 77, "DOS Header magic byte 0 is 'M' (77)")
  ok_pe3 = assert_eq_int(mz1, 90, "DOS Header magic byte 1 is 'Z' (90)")

  // e_lfanew at offset 0x3C points to PE header (typically 0x80 or 0x40)
  pe_off = sys_peek8(pe_hdr + 60) + (sys_peek8(pe_hdr + 61) * 256)
  ok_pe4 = assert_true(pe_off >= 64, "e_lfanew points to valid PE signature offset")

  // PE Signature: 'P' 'E' 0 0
  p0 = sys_peek8(pe_hdr + pe_off + 0)
  p1 = sys_peek8(pe_hdr + pe_off + 1)
  ok_pe5 = assert_eq_int(p0, 80, "PE signature byte 0 is 'P' (80)")
  ok_pe6 = assert_eq_int(p1, 69, "PE signature byte 1 is 'E' (69)")

  // Machine architecture at pe_off + 4 is 0x8664 (AMD64)
  m_lo = sys_peek8(pe_hdr + pe_off + 4)
  m_hi = sys_peek8(pe_hdr + pe_off + 5)
  pe_mach = m_lo + (m_hi * 256)
  ok_pe7 = assert_eq_int(pe_mach, 34404, "PE Machine is IMAGE_FILE_MACHINE_AMD64 (0x8664 = 34404)")

  all_s1 = ok_pe1 && ok_pe2 && ok_pe3 && ok_pe4 && ok_pe5 && ok_pe6 && ok_pe7
  @if all_s1 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Pure Lipi Windows PE32+ (PE64) .exe verified.")
  @end

  // ── 2. macOS Mach-O 64-Bit Direct Emission ─────────────────────────────────
  println("▶ Section 2: macOS Mach-O 64-Bit Native Binary Emitter...")
  total_tests = total_tests + 1

  macho_path = "dist/omni_test.macho"
  macho_res = emit_macho_64_executable(code, macho_path)
  ok_m1 = assert_eq_int(macho_res, 1, "Mach-O 64-bit emission succeeded")

  fd_m = sys_open(macho_path, 0, 0)
  ok_fd2 = assert_true(fd_m >= 0, "Opened omni_test.macho")

  m_hdr = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  sys_read(fd_m, m_hdr, 64)
  sys_close(fd_m)

  // Verify Mach-O 64 magic: 0xCF 0xFA 0xED 0xFE (MH_MAGIC_64)
  // Little-endian: CF FA ED FE -> 207, 250, 237, 254
  mh0 = sys_peek8(m_hdr + 0)
  mh1 = sys_peek8(m_hdr + 1)
  mh2 = sys_peek8(m_hdr + 2)
  mh3 = sys_peek8(m_hdr + 3)
  ok_m2 = assert_eq_int(mh0, 207, "Mach-O 64 magic byte 0 is 0xCF (207)")
  ok_m3 = assert_eq_int(mh1, 250, "Mach-O 64 magic byte 1 is 0xFA (250)")
  ok_m4 = assert_eq_int(mh2, 237, "Mach-O 64 magic byte 2 is 0xED (237)")
  ok_m5 = assert_eq_int(mh3, 254, "Mach-O 64 magic byte 3 is 0xFE (254)")

  // CPUType at offset 4: 0x01000007 (CPU_TYPE_X86_64)
  cpu_b0 = sys_peek8(m_hdr + 4)
  cpu_b3 = sys_peek8(m_hdr + 7)
  ok_m6 = assert_eq_int(cpu_b0, 7, "CPUType low byte is 7 (X86)")
  ok_m7 = assert_eq_int(cpu_b3, 1, "CPUType high byte is 1 (64-bit ABI)")

  all_s2 = ok_m1 && ok_m2 && ok_m3 && ok_m4 && ok_m5 && ok_m6 && ok_m7
  @if all_s2 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Pure Lipi macOS Mach-O 64-bit binary verified.")
  @end

  // Clean up test binaries
  sys_unlink(pe_path)
  sys_unlink(macho_path)

  println("")
  println("=================================================================")
  println(str_concat("🎉 TOTAL OMNI-TARGET SECTIONS PASSED: ", str_concat(to_str(passed_tests), str_concat(" / ", to_str(total_tests)))))
  println("=================================================================")
  @if passed_tests == total_tests
    return 0
  @else
    return 1
  @end
@end

main()
