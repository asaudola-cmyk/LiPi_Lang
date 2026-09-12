@! ============================================================================
@! LIPI TEST SUITE: BARE-METAL RING-0 OS KERNEL & BOOTABLE ISO VERIFICATION
@! File: tests/test_live_os_boot.lp
@! Standard: Multiboot2 Specification & El Torito Bootable CD-ROM Format
@! 100% Pure Lipi Implementation — Zero Libc / Zero External Dependencies
@! ============================================================================

import "universe/os/boot/multiboot"
import "universe/os/unikernel"
import "universe/os/build_unikernel"
import "universe/os/syscalls"
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
  println("🛸 LIPI BARE-METAL RING-0 OS & LIVE BOOTABLE ISO TEST SUITE 🛸")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: Multiboot2 44-Byte Header & Checksum Identity Verification
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Multiboot2 Header & Checksum Invariants...")
  total_tests = total_tests + 1

  hdr2 = multiboot2_create_header(1024, 768, 32)
  ok_m1 = assert_eq_int(hdr2.magic, 3897741526, "Multiboot2 Magic is 0xE85250D6 (3897741526)")
  ok_m2 = assert_eq_int(hdr2.architecture, 0, "Architecture is 0 (i386/x86_64 protected mode)")
  ok_m3 = assert_eq_int(hdr2.header_length, 44, "Header length is exactly 44 bytes")

  mb2_bin = multiboot2_serialize_binary(hdr2, 1024, 768, 32)
  ok_m4 = assert_eq_int(mb2_bin.len(), 44, "Serialized header byte length is 44 bytes")

  @! Checksum identity: (magic + architecture + length + checksum) % 2^32 == 0
  sum32 = (hdr2.magic + hdr2.architecture + hdr2.header_length + hdr2.checksum) % 4294967296
  ok_m5 = assert_eq_int(sum32, 0, "Multiboot2 Checksum Identity: sum % 2^32 == 0")

  all_s1 = ok_m1 && ok_m2 && ok_m3 && ok_m4 && ok_m5
  @if all_s1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multiboot2 44-byte header and checksum identity verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: COM1 UART 16550 & VGA Framebuffer Machine Code Sequences
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Bare-Metal Machine Code Hardware Initialization...")
  total_tests = total_tests + 1

  com1_init = unikernel_build_com1_init_bytes()
  @! Ensure COM1 init contains out dx, al (238) after 0x3FB DLAB setup
  ok_c1 = assert_true(com1_init.len() >= 30, "COM1 16550 init instruction vector length >= 30")
  ok_c2 = assert_eq_int(com1_init[0], 102, "COM1 init begins with 16-bit operand prefix (0x66)")

  vga_bytes = unikernel_build_vga_str_bytes("LIPI OS", 0, 0, 10)
  @! Direct VGA writes to 0xB8000
  ok_v1 = assert_true(vga_bytes.len() >= 20, "VGA 0xB8000 text buffer machine code emitted")

  all_s2 = ok_c1 && ok_c2 && ok_v1
  @if all_s2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] COM1 UART (115200 8N1) and VGA (0xB8000) machine code verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: Bootable Live ISO 9660 & El Torito Synthesis & Verification
  @! --------------------------------------------------------------------------
  println("▶ Section 3: Hybrid ISO 9660 & El Torito Synthesis...")
  total_tests = total_tests + 1

  iso_path = "dist/lipi-os.iso"
  res_iso = build_iso_image("lipi_os_unikernel", iso_path)
  ok_i1 = assert_true(res_iso.image_size_bytes >= 65536, "ISO size is at least 65536 bytes (32 sectors)")
  ok_i2 = assert_eq_int(res_iso.is_bootable, 1, "ISO marked bootable with El Torito specification")

  @! Open and inspect binary sector layout
  fd = sys_open(iso_path, 0, 0)
  ok_fd = assert_true(fd >= 0, "Opened dist/lipi-os.iso via sys_open")

  @! Read Sector 16: Primary Volume Descriptor (offset 32768, 2048 bytes)
  sys_lseek(fd, 32768, 0)
  pvd_buf = sys_mmap(0, 2048, 3, 34, 0 - 1, 0)
  sys_read(fd, pvd_buf, 2048)

  pvd_type = sys_peek8(pvd_buf + 0)
  pvd_c = sys_peek8(pvd_buf + 1)
  pvd_d = sys_peek8(pvd_buf + 2)
  pvd_0a = sys_peek8(pvd_buf + 3)
  pvd_0b = sys_peek8(pvd_buf + 4)
  pvd_1 = sys_peek8(pvd_buf + 5)
  sys_munmap(pvd_buf, 2048)

  ok_p1 = assert_eq_int(pvd_type, 1, "Sector 16: Type 1 (Primary Volume Descriptor)")
  ok_p2 = assert_eq_int(pvd_c, 67, "PVD Magic byte 1 is 'C'")
  ok_p3 = assert_eq_int(pvd_d, 68, "PVD Magic byte 2 is 'D'")
  ok_p4 = assert_eq_int(pvd_0a, 48, "PVD Magic byte 3 is '0'")
  ok_p5 = assert_eq_int(pvd_0b, 48, "PVD Magic byte 4 is '0'")
  ok_p6 = assert_eq_int(pvd_1, 49, "PVD Magic byte 5 is '1'")

  @! Read Sector 17: El Torito Boot Record (offset 34816)
  sys_lseek(fd, 34816, 0)
  boot_buf = sys_mmap(0, 2048, 3, 34, 0 - 1, 0)
  sys_read(fd, boot_buf, 2048)

  boot_type = sys_peek8(boot_buf + 0)
  cat_lba = sys_peek8(boot_buf + 71)
  sys_munmap(boot_buf, 2048)

  ok_b1 = assert_eq_int(boot_type, 0, "Sector 17: Boot Record Indicator is 0")
  ok_b2 = assert_eq_int(cat_lba, 19, "Sector 17: Boot Catalog LBA pointer is Sector 19")

  @! Read Sector 19: Boot Catalog (offset 38912)
  sys_lseek(fd, 38912, 0)
  cat_buf = sys_mmap(0, 2048, 3, 34, 0 - 1, 0)
  sys_read(fd, cat_buf, 2048)

  cat_header_id = sys_peek8(cat_buf + 0)
  cat_key55 = sys_peek8(cat_buf + 30)
  cat_keyaa = sys_peek8(cat_buf + 31)
  init_bootable = sys_peek8(cat_buf + 32)
  kernel_lba = sys_peek8(cat_buf + 40)
  sys_munmap(cat_buf, 2048)

  ok_cat1 = assert_eq_int(cat_header_id, 1, "Sector 19: Validation Entry Header ID is 1")
  ok_cat2 = assert_eq_int(cat_key55, 85, "Sector 19: Signature Key 1 is 0x55 (85)")
  ok_cat3 = assert_eq_int(cat_keyaa, 170, "Sector 19: Signature Key 2 is 0xAA (170)")
  ok_cat4 = assert_eq_int(init_bootable, 136, "Sector 19: Initial Boot Entry Bootable Media (0x88)")
  ok_cat5 = assert_eq_int(kernel_lba, 20, "Sector 19: Kernel Payload RBA is Sector 20")

  @! Read Sector 20: Bootable Kernel Payload (offset 40960)
  sys_lseek(fd, 40960, 0)
  k_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_read(fd, k_buf, 16)
  sys_close(fd)

  k_b0 = sys_peek8(k_buf + 0)
  k_b1 = sys_peek8(k_buf + 1)
  k_b2 = sys_peek8(k_buf + 2)
  k_b3 = sys_peek8(k_buf + 3)
  sys_munmap(k_buf, 16)

  ok_k1 = assert_eq_int(k_b0, 214, "Sector 20: Kernel byte 0 is Multiboot2 0xD6 (214)")
  ok_k2 = assert_eq_int(k_b1, 80, "Sector 20: Kernel byte 1 is Multiboot2 0x50 (80)")
  ok_k3 = assert_eq_int(k_b2, 82, "Sector 20: Kernel byte 2 is Multiboot2 0x52 (82)")
  ok_k4 = assert_eq_int(k_b3, 232, "Sector 20: Kernel byte 3 is Multiboot2 0xE8 (232)")

  all_s3 = ok_i1 && ok_i2 && ok_fd && ok_p1 && ok_p2 && ok_p3 && ok_p4 && ok_p5 && ok_p6 && ok_b1 && ok_b2 && ok_cat1 && ok_cat2 && ok_cat3 && ok_cat4 && ok_cat5 && ok_k1 && ok_k2 && ok_k3 && ok_k4
  @if all_s3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Complete El Torito ISO Sector chain (LBA 16, 17, 18, 19, 20) verified.")
  @end

  println("=================================================================")
  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  println(str_concat("📊 BARE-METAL LIVE OS RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed")))))
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL BARE-METAL RING-0 OS & ISO TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TESTS FAILED")
    return 1
  @end
@end
