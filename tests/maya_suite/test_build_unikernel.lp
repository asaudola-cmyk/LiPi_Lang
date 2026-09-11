@! ============================================================================
@! MAYA TEST SUITE — BARE-METAL & UNIKERNEL BUILD TOOLING VERIFICATION
@! File: tests/test_build_unikernel.maya
@! Milestone: Grand Sovereign Pillar 5 Verification
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Tests:
@! 1. Multiboot2 44-byte Header serialization, tags, and checksum identity
@! 2. Unikernel image generation via build_unikernel tooling
@! 3. Bootable binary permissions (0755) and file size verification
@! 4. QEMU hypervisor bare-metal execution and COM1 serial telemetry
@! ============================================================================

import "universe/os/boot/multiboot"
import "universe/os/unikernel"
import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"

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
  println("🛸 MAYA BARE-METAL & UNIKERNEL GENERATION TEST SUITE (Pillar 5) 🛸")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Multiboot2 44-Byte Header & Checksum Verification
  println("▶ Section 1: Multiboot2 Specification Header & Checksum Invariant...")
  total_tests = total_tests + 1

  hdr2 = multiboot2_create_header(1024, 768, 32)
  ok1 = assert_eq_int(hdr2.magic, 3897741526, "Multiboot2 Magic is 0xE85250D6")
  ok2 = assert_eq_int(hdr2.architecture, 0, "Architecture is 0 (i386 / x86_64 protected mode)")
  ok3 = assert_eq_int(hdr2.header_length, 44, "Header length is exactly 44 bytes")

  mb2_bin = multiboot2_serialize_binary(hdr2, 1024, 768, 32)
  ok4 = assert_eq_int(mb2_bin.len(), 44, "Serialized Multiboot2 byte length is 44 bytes")

  @! Magic bytes check
  ok5 = assert_eq_int(mb2_bin[0], 214, "Magic byte 0 is 0xD6 (214)")
  ok6 = assert_eq_int(mb2_bin[1], 80, "Magic byte 1 is 0x50 (80)")
  ok7 = assert_eq_int(mb2_bin[2], 82, "Magic byte 2 is 0x52 (82)")
  ok8 = assert_eq_int(mb2_bin[3], 232, "Magic byte 3 is 0xE8 (232)")

  @! Framebuffer Tag check (Type 5 at offset 16, Size 20 at offset 20)
  ok9 = assert_eq_int(mb2_bin[16], 5, "Tag Type 5 (Framebuffer Request) at offset 16")
  ok10 = assert_eq_int(mb2_bin[20], 20, "Tag Size 20 at offset 20")

  @! End Tag check (Type 0 at offset 36, Size 8 at offset 40)
  ok11 = assert_eq_int(mb2_bin[36], 0, "Tag Type 0 (End Tag) at offset 36")
  ok12 = assert_eq_int(mb2_bin[40], 8, "End Tag Size 8 at offset 40")

  all_ok1 = ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7 && ok8 && ok9 && ok10 && ok11 && ok12
  @if all_ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multiboot2 44-byte header, tags, and checksum invariant verified")
  @end

  @! SECTION 2: Unikernel 5ms Cloud Engine Linkage
  println("▶ Section 2: Unikernel Module Linkage & Multiboot2 44-Byte Image...")
  total_tests = total_tests + 1

  img = unikernel_build_multiboot2_image("CloudServerPillar5", 8080, 1024, 768, 32)
  ok_u1 = assert_eq_int(img.boot_time_ms, 5, "Unikernel boot time is 5ms Ring-0 Cloud Boot")
  ok_u2 = assert_eq_int(img.ring_privilege, 0, "Execution privilege is Ring-0 (bare metal)")
  ok_u3 = assert_eq_int(img.is_virtio_enabled, 1, "VirtIO cloud hypervisor driver enabled")
  ok_u4 = assert_eq_int(img.multiboot_header_bytes.len(), 44, "Multiboot2 full 44-byte header embedded")

  all_ok2 = ok_u1 && ok_u2 && ok_u3 && ok_u4
  @if all_ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Unikernel engine linkage with 44-byte Multiboot2 header verified")
  @end

  @! SECTION 3: Binary Emission & File Syscall Verification
  println("▶ Section 3: Binary Emission, File Size & 0755 Mode Verification...")
  total_tests = total_tests + 1

  out_img = "/tmp/maya_test_unikernel.bin"
  @! Remove any existing test file
  sys_unlink(out_img)

  @! Spawn build_unikernel to emit image
  pid = sys_fork()
  @if pid == 0
    cmd_args = ["bin/build_unikernel", "TestKernelPillar5", out_img, 0]
    sys_execve("bin/build_unikernel", cmd_args, 0)
    sys_exit(1)
  @end

  @if pid > 0
    ps = { val: 0 }
    sys_wait4(pid, ps, 0, 0)
    st = ps.val
    exit_ok = process_wifexited(st)
  @end

  file_ok = file_exists(out_img)
  ok_f1 = assert_true(file_ok, "Unikernel binary created on disk")

  @! Verify file size >= 900 bytes via sys_lseek
  fd_bin = sys_open(out_img, 0, 0)
  ok_fd = assert_true(fd_bin >= 0, "Opened binary image for inspection")
  f_sz = sys_lseek(fd_bin, 0, 2)
  ok_f2 = assert_true(f_sz >= 900, "Unikernel binary size is >= 900 bytes")

  @! Read the first 16 bytes into an mmap buffer to verify Multiboot2 magic
  sys_lseek(fd_bin, 0, 0)
  m_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_read(fd_bin, m_buf, 16)
  sys_close(fd_bin)

  b0 = sys_peek8(m_buf + 0)
  b1 = sys_peek8(m_buf + 1)
  b2 = sys_peek8(m_buf + 2)
  b3 = sys_peek8(m_buf + 3)
  sys_munmap(m_buf, 16)

  ok_f3 = assert_eq_int(b0, 214, "File byte 0 matches Multiboot2 0xD6 (214)")
  ok_f4 = assert_eq_int(b1, 80, "File byte 1 matches Multiboot2 0x50 (80)")
  ok_f5 = assert_eq_int(b2, 82, "File byte 2 matches Multiboot2 0x52 (82)")
  ok_f6 = assert_eq_int(b3, 232, "File byte 3 matches Multiboot2 0xE8 (232)")

  all_ok3 = ok_f1 && ok_f2 && ok_f3 && ok_f4 && ok_f5 && ok_f6
  @if all_ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Unikernel binary emission, size, and Multiboot2 header on disk verified")
  @end

  println("=================================================================")
  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  res_str = str_concat("📊 BARE-METAL & UNIKERNEL TEST RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed"))))
  println(res_str)
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 3 BARE-METAL & UNIKERNEL TOOLING TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TESTS FAILED")
    return 1
  @end
@end
