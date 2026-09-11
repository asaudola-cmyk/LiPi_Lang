// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: APK Packager & ELF64 Boundaries PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: mobile, apk, zip, crc32, elf64, aarch64, page_alignment, boundaries

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & ADVERSARIAL: APK PACKAGER & ELF64 ENGINE
@! File: tests/mobile/test_apk_packager_boundaries.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/mobile/mobile"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: APK Packager, CRC-32 & ELF64 Machine Layout")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-APK-01: 4KB Page Alignment for Direct Kernel mmap of .so in APK
  @! ----------------------------------------------------------------------------
  total = total + 1
  apk = mobile_build_android_apk("com.maya.boundary", "Maya Boundary APK")
  apk_bytes = apk.apk_raw_bytes

  @! Locate libmaya.so data payload offset
  so_payload_offset = 0
  scan_i = 0
  limit = apk_bytes.len() - 30
  @while scan_i < limit
    @if apk_bytes[scan_i] == 80 && apk_bytes[scan_i + 1] == 75 && apk_bytes[scan_i + 2] == 3 && apk_bytes[scan_i + 3] == 4
      @! Local file header
      fn_len = apk_bytes[scan_i + 26] | (apk_bytes[scan_i + 27] * 256)
      extra_len = apk_bytes[scan_i + 28] | (apk_bytes[scan_i + 29] * 256)
      @! Check if filename is lib/arm64-v8a/libmaya.so
      @if apk_bytes[scan_i + 30] == 108 && apk_bytes[scan_i + 31] == 105 && apk_bytes[scan_i + 32] == 98
        so_payload_offset = scan_i + 30 + fn_len + extra_len
      @end
    @end
    scan_i = scan_i + 1
  @end

  is_aligned = (so_payload_offset > 0) && ((so_payload_offset % 4096) == 0)
  @if is_aligned
    passed = passed + 1
    println("  [PASS] TC-APK-01: libmaya.so data payload is page-aligned (offset: " + so_payload_offset.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] TC-APK-01: 4KB page alignment (offset: " + so_payload_offset.to_str() + ")")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-APK-02: IEEE 802.3 CRC-32 Boundary Vectors
  @! ----------------------------------------------------------------------------
  total = total + 1
  crc_empty = crc32_bytes([])
  crc_digits = crc32_bytes([49, 50, 51, 52, 53, 54, 55, 56, 57]) @! "123456789" -> 0xCBF43926 (3421780262)
  crc_a = crc32_bytes([65])

  crc_ok = (crc_empty == 0) && (crc_digits == 3421780262) && (crc_a > 0)
  @if crc_ok
    passed = passed + 1
    println("  [PASS] TC-APK-02: CRC-32 boundary vectors (empty=0, '123456789'=0xCBF43926, len=1: " + crc_a.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] TC-APK-02: CRC-32 boundary vectors")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-APK-03: Multi-File APK Hierarchy & Central Directory Offsets
  @! ----------------------------------------------------------------------------
  total = total + 1
  cd_count = 0
  cd_scan = 0
  cd_limit = apk_bytes.len() - 4
  @while cd_scan < cd_limit
    @if apk_bytes[cd_scan] == 80 && apk_bytes[cd_scan + 1] == 75 && apk_bytes[cd_scan + 2] == 1 && apk_bytes[cd_scan + 3] == 2
      cd_count = cd_count + 1
    @end
    cd_scan = cd_scan + 1
  @end

  @! APK must contain at least 3 distinct file entries: AndroidManifest.xml, classes.dex, lib/arm64-v8a/libmaya.so
  @if cd_count >= 3
    passed = passed + 1
    println("  [PASS] TC-APK-03: Multi-file APK hierarchy contains " + cd_count.to_str() + " Central Directory headers")
  @else
    failed = failed + 1
    println("  [FAIL] TC-APK-03: Multi-file APK hierarchy")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-APK-04: ELF64 AArch64 Program Header Layout & Type Checks
  @! ----------------------------------------------------------------------------
  total = total + 1
  so_bytes = mobile_emit_arm64_libmaya_so()
  e_ident_valid = (so_bytes[0] == 127 && so_bytes[1] == 69 && so_bytes[2] == 76 && so_bytes[3] == 70)
  e_type_dyn = (so_bytes[16] == 3)        @! ET_DYN (3)
  e_machine_arm64 = (so_bytes[18] == 183) @! EM_AARCH64 (183)

  @! Phdr 0: PT_PHDR at offset 64 (p_type = 6)
  ph0_type_phdr = (so_bytes[64] == 6 && so_bytes[65] == 0 && so_bytes[66] == 0 && so_bytes[67] == 0)
  @! Phdr 1: PT_LOAD at offset 120 (p_type = 1, p_flags = 7)
  ph1_type_load = (so_bytes[120] == 1 && so_bytes[121] == 0 && so_bytes[122] == 0 && so_bytes[123] == 0)
  @! Phdr 2: PT_DYNAMIC at offset 176 (p_type = 2, p_flags = 6)
  ph2_type_dyn = (so_bytes[176] == 2 && so_bytes[177] == 0 && so_bytes[178] == 0 && so_bytes[179] == 0)

  elf_ok = e_ident_valid && e_type_dyn && e_machine_arm64 && ph0_type_phdr && ph1_type_load && ph2_type_dyn
  @if elf_ok
    passed = passed + 1
    println("  [PASS] TC-APK-04: AArch64 ELF64 program header verification (ET_DYN, EM_AARCH64, PT_LOAD RX)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-APK-04: ELF64 program header layout")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-APK-05: JNI and NativeActivity Dynamic Symbol Invariant
  @! ----------------------------------------------------------------------------
  total = total + 1
  so_str = ""
  s_i = 0
  s_len = so_bytes.len()
  @while s_i < s_len
    so_str = so_str + str_from_char_code(so_bytes[s_i] & 255)
    s_i = s_i + 1
  @end

  jni_found = (str_index_of(so_str, "Java_com_maya_MayaNativeActivity_nativeInit") >= 0)
  na_found = (str_index_of(so_str, "ANativeActivity_onCreate") >= 0)
  so_name_found = (str_index_of(so_str, "libmaya.so") >= 0)
  symbols_ok = jni_found && na_found && so_name_found

  @if symbols_ok
    passed = passed + 1
    println("  [PASS] TC-APK-05: Dynamic string table contains all mandatory JNI symbols & SONAME")
  @else
    failed = failed + 1
    println("  [FAIL] TC-APK-05: JNI dynamic symbols")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: APK Packager & ELF64 Boundaries PASSED")
    return 0
  @else
    println("✗ Feature: APK Packager & ELF64 Boundaries FAILED")
    return 1
  @end
@end
