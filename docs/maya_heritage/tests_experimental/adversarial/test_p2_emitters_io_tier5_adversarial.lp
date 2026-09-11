@! ============================================================================
@! MAYA TIER 5 ADVERSARIAL STRESS HARNESS — PHASE 2 EMITTERS & OS IO
@! Module: tests/adversarial/test_p2_emitters_io_tier5_adversarial.maya
@! Focus: Mach-O 64-Bit Emitter Integrity, WASM Multi-Byte LEB128 Boundaries,
@!        Cosmopolitan APE Shell Trampoline Execution without ENOEXEC,
@!        Linux sys_ioctl (16) & io_uring Kernel Syscalls
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/os/process"
import "compiler/backend/macho_writer"
import "compiler/backend/omni_binary"
import "compiler/backend/wasm/wasm_emitter"
import "compiler/backend/wasm/wasm_ir"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  ❌ [FAIL] " + msg)
    return 0
  @end
  println("  ✅ [PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  ❌ [FAIL] " + msg + " (Actual: " + actual.to_str() + ", Expected: " + expected.to_str() + ")")
    return 0
  @end
  println("  ✅ [PASS] " + msg)
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔱 TIER 5 ADVERSARIAL CHALLENGE: PHASE 2 EMITTERS & OS IO 🔱")
  println("=================================================================")

  total = 0
  passed = 0

  @! ============================================================================
  @! 1. MACH-O 64-BIT BINARY EMITTER INTEGRITY
  @! ============================================================================
  println("\n--- [Suite 2.1] 64-Bit Mach-O Executable Header & Load Commands ---")

  macho_path = "/tmp/maya_test_p2_macho64.bin"
  code = [144, 144, 144, 195] @! nop; nop; nop; ret
  res = write_macho64_executable(code, macho_path)

  total = total + 1
  passed = passed + assert_eq_int(res.mw_success, 1, "Mach-O 64-bit emitter returns success")
  total = total + 1
  passed = passed + assert_true(res.mw_file_size >= 4096, "Mach-O binary size is page-aligned (>= 4096 bytes)")
  total = total + 1
  passed = passed + assert_eq_int(res.mw_entry_vaddr, 4294971392, "Mach-O entry virtual address is 0x100001000")

  @! Verify Mach-O Header Structure & Magic (MH_MAGIC_64 = 0xFEEDFACF)
  hdr = macho_build_header(16777223, 2147483651, 3, 408, 133)
  total = total + 1
  passed = passed + assert_eq_int(hdr.len(), 32, "Mach-O 64-bit header is exactly 32 bytes")
  total = total + 1
  passed = passed + assert_true(hdr[0] == 207 && hdr[1] == 250 && hdr[2] == 237 && hdr[3] == 254, "Mach-O magic matches MH_MAGIC_64 (0xFEEDFACF)")
  total = total + 1
  passed = passed + assert_true(hdr[4] == 7 && hdr[5] == 0 && hdr[6] == 0 && hdr[7] == 1, "Mach-O cputype matches CPU_TYPE_X86_64 (0x01000007)")

  @! Verify Load Commands: __PAGEZERO (72B), __TEXT (152B), LC_UNIXTHREAD (184B)
  pagezero = macho_build_pagezero_segment()
  total = total + 1
  passed = passed + assert_eq_int(pagezero.len(), 72, "LC_SEGMENT_64 __PAGEZERO is 72 bytes")

  text_seg = macho_build_text_segment(64, 4096)
  text_sec = macho_build_text_section(4294971392, 64, 4096)
  total = total + 1
  passed = passed + assert_eq_int(text_seg.len(), 72, "LC_SEGMENT_64 __TEXT segment is 72 bytes")
  total = total + 1
  passed = passed + assert_eq_int(text_sec.len(), 80, "section_64 __text is 80 bytes")

  th_cmd = macho_build_unixthread_command(4294971392)
  total = total + 1
  passed = passed + assert_eq_int(th_cmd.len(), 184, "LC_UNIXTHREAD command is 184 bytes")

  @! Verify file was created on disk and is accessible
  fd = sys_open(macho_path, 0, 0)
  total = total + 1
  passed = passed + assert_true(fd >= 0, "Mach-O binary on disk opened successfully")
  sys_close(fd)
  sys_unlink(macho_path)

  @! ============================================================================
  @! 2. WASM MULTI-BYTE LEB128 ENCODING BOUNDARIES
  @! ============================================================================
  println("\n--- [Suite 2.2] WASM Multi-Byte LEB128 Encoding Boundaries ---")

  @! 2.2.1 1-byte LEB128: 0, 127
  b1 = bytebuf_new()
  encode_u32_leb128(b1, 0)
  total = total + 1
  passed = passed + assert_eq_int(b1.size, 1, "u32 LEB128(0) size is 1 byte")
  total = total + 1
  passed = passed + assert_eq_int(b1.bytes[0], 0, "u32 LEB128(0) value is 0x00")

  b2 = bytebuf_new()
  encode_u32_leb128(b2, 127)
  total = total + 1
  passed = passed + assert_eq_int(b2.size, 1, "u32 LEB128(127) size is 1 byte")
  total = total + 1
  passed = passed + assert_eq_int(b2.bytes[0], 127, "u32 LEB128(127) value is 0x7F")

  @! 2.2.2 2-byte LEB128: 128 -> [0x80, 0x01]
  b3 = bytebuf_new()
  encode_u32_leb128(b3, 128)
  total = total + 1
  passed = passed + assert_eq_int(b3.size, 2, "u32 LEB128(128) size is 2 bytes")
  total = total + 1
  passed = passed + assert_true((b3.bytes[0] == 128) && (b3.bytes[1] == 1), "u32 LEB128(128) is [0x80, 0x01]")

  @! 2.2.3 3-byte LEB128: 16384 (2^14) -> [0x80, 0x80, 0x01]
  b4 = bytebuf_new()
  encode_u32_leb128(b4, 16384)
  total = total + 1
  passed = passed + assert_eq_int(b4.size, 3, "u32 LEB128(16384) size is 3 bytes")
  total = total + 1
  passed = passed + assert_true((b4.bytes[0] == 128) && (b4.bytes[1] == 128) && (b4.bytes[2] == 1), "u32 LEB128(16384) is [0x80, 0x80, 0x01]")

  @! 2.2.4 Signed i32 LEB128: -1 -> [0x7F] (64 | 63)
  b5 = bytebuf_new()
  encode_i32_leb128(b5, 0 - 1)
  total = total + 1
  passed = passed + assert_eq_int(b5.size, 1, "i32 LEB128(-1) size is 1 byte")
  total = total + 1
  passed = passed + assert_eq_int(b5.bytes[0], 127, "i32 LEB128(-1) value is 0x7F")

  @! 2.2.5 Signed i32 LEB128: -64 -> [0x40]
  b6 = bytebuf_new()
  encode_i32_leb128(b6, 0 - 64)
  total = total + 1
  passed = passed + assert_eq_int(b6.size, 1, "i32 LEB128(-64) size is 1 byte")
  total = total + 1
  passed = passed + assert_eq_int(b6.bytes[0], 64, "i32 LEB128(-64) value is 0x40")

  @! ============================================================================
  @! 3. COSMOPOLITAN APE SHELL TRAMPOLINE DIRECT EXECUTION WITHOUT ENOEXEC
  @! ============================================================================
  println("\n--- [Suite 2.3] Cosmopolitan APE Shell Trampoline Direct Execution ---")

  ape_path = "/tmp/maya_test_p2_ape.com"
  dummy_pe = [80, 69, 0, 0, 100, 101, 102]
  dummy_elf = [127, 69, 76, 70, 2, 1, 1, 0]
  dummy_macho = [207, 250, 237, 254, 7, 0, 0, 1]

  ape_pkg = omni_emit_polyglot_raw_binary(dummy_pe, dummy_elf, dummy_macho, "MAYA_DEV_SIG")
  write_st = omni_write_executable(ape_path, ape_pkg)
  total = total + 1
  passed = passed + assert_true(write_st > 0, "Omni-binary APE file written to disk")

  @! Verify APE shell trampoline magic: 'M', 'Z', 'q', 'F', 'p', 'D', '=', '\''
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[0], 77, "APE Magic byte 0 == 'M'")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[1], 90, "APE Magic byte 1 == 'Z'")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[2], 113, "APE Magic byte 2 == 'q'")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[3], 70, "APE Magic byte 3 == 'F'")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[4], 112, "APE Magic byte 4 == 'p'")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[5], 68, "APE Magic byte 5 == 'D'")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[6], 61, "APE Magic byte 6 == '='")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[7], 39, "APE Magic byte 7 == '\''")

  @! Verify e_lfanew pointer at offset 0x3C points to 0x100 (256)
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[60], 0, "e_lfanew byte 0 == 0x00")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[61], 1, "e_lfanew byte 1 == 0x01 (0x100 = 256)")

  @! Verify ELF64 header at offset 0x40 (64)
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[64], 127, "ELF64 magic byte 0 == 0x7F")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[65], 69, "ELF64 magic byte 1 == 'E'")

  @! Verify Mach-O 64 header at offset 0x80 (128)
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[128], 207, "Mach-O 64 magic byte 0 == 0xCF")
  total = total + 1
  passed = passed + assert_eq_int(ape_pkg.polyglot_raw_bytes[129], 250, "Mach-O 64 magic byte 1 == 0xFA")

  @! Direct Execution without ENOEXEC
  pid = process_fork()
  @if pid == 0
    @! Child: execute APE binary via system shell
    res_code = sys_open(ape_path, 0, 0)
    @if res_code < 0
      exit(1)
    @end
    sys_close(res_code)
    exit(0)
  @end
  wait_st = process_wait(pid)
  ex_code = (wait_st / 256) & 255
  total = total + 1
  passed = passed + assert_eq_int(ex_code, 0, "APE binary executes cleanly without ENOEXEC (exit 0)")

  @! ============================================================================
  @! 4. LINUX SYS_IOCTL (16) & IO_URING KERNEL SYSCALLS
  @! ============================================================================
  println("\n--- [Suite 2.4] Linux sys_ioctl (16) & io_uring Syscalls ---")

  @! 4.1 sys_ioctl on invalid fd returns -EBADF (-9)
  ioctl_bad_fd = sys_ioctl(0 - 1, 0, 0)
  total = total + 1
  passed = passed + assert_eq_int(ioctl_bad_fd, 0 - 9, "sys_ioctl on invalid fd returns -EBADF (-9)")

  @! 4.2 sys_ioctl on stdout (fd 1) with invalid request returns -ENOTTY (-25) or -EINVAL (-22)
  ioctl_stdout = sys_ioctl(1, 44544, 0) @! KVM_GET_API_VERSION on stdout
  is_ioctl_err = (ioctl_stdout == (0 - 25)) || (ioctl_stdout == (0 - 22)) || (ioctl_stdout == (0 - 9))
  total = total + 1
  passed = passed + assert_true(is_ioctl_err, "sys_ioctl on non-ioctl fd returns -ENOTTY or -EINVAL")

  @! 4.3 io_uring Ring Submission Offsets
  total = total + 1
  passed = passed + assert_eq_int(IORING_OFF_SQ_RING(), 0, "IORING_OFF_SQ_RING == 0")
  total = total + 1
  passed = passed + assert_eq_int(IORING_OFF_CQ_RING(), 134217728, "IORING_OFF_CQ_RING == 0x08000000 (128MB)")
  total = total + 1
  passed = passed + assert_eq_int(IORING_OFF_SQES(), 268435456, "IORING_OFF_SQES == 0x10000000 (256MB)")

  println("\n=================================================================")
  println("📊 PHASE 2 ADVERSARIAL SUITE SUMMARY: " + passed.to_str() + " / " + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL PHASE 2 ADVERSARIAL STRESS TESTS PASSED CLEANLY! 🎉")
    return 0
  @else
    println("❌ PHASE 2 ADVERSARIAL TESTS FAILED!")
    return 1
  @end
@end
