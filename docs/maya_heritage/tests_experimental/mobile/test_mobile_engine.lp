// @! RUN: %maya %file
// @! EXPECT: 🎉 ALL 4 MOBILE ENGINE & STORAGE TEST SUITES PASSED! 🎉
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: mobile, android, arm64, elf64, apk, pkzip, storage

@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MOBILE SUBSYSTEM & STORAGE TEST SUITE
@! File: tests/mobile/test_mobile_engine.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/mobile/mobile"
import "universe/mobile/storage"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  println("  [PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("📱 MAYA MOBILE ENGINE & PERSISTENT STORAGE COMPREHENSIVE SUITE 📱")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: ARM64 ELF64 Shared Object (.so) Inspection
  println("▶ Section 1: ARM64 ELF64 Shared Object Generator (libmaya.so)...")
  total_tests = total_tests + 1
  so_bytes = mobile_emit_arm64_libmaya_so()

  @! ELF Magic 0x7F 'E' 'L' 'F'
  e1 = assert_eq_int(so_bytes[0], 127, "ELF magic byte 0 (0x7F)")
  e2 = assert_eq_int(so_bytes[1], 69, "ELF magic byte 1 ('E')")
  e3 = assert_eq_int(so_bytes[2], 76, "ELF magic byte 2 ('L')")
  e4 = assert_eq_int(so_bytes[3], 70, "ELF magic byte 3 ('F')")
  e5 = assert_eq_int(so_bytes[4], 2, "ELFClass = 64-bit (2)")
  e6 = assert_eq_int(so_bytes[5], 1, "ELFData = 2's complement Little Endian (1)")
  @! e_type = ET_DYN (3)
  e7 = assert_eq_int(so_bytes[16], 3, "ELF Type = ET_DYN (3)")
  @! e_machine = EM_AARCH64 (183)
  e8 = assert_eq_int(so_bytes[18], 183, "ELF Machine = EM_AARCH64 (183)")

  @! Check for exported symbols in .dynstr
  so_raw_str = ""
  so_idx = 0
  so_len = so_bytes.len()
  @while so_idx < so_len
    so_raw_str = so_raw_str + str_from_char_code(so_bytes[so_idx] & 255)
    so_idx = so_idx + 1
  @end
  e9 = assert_true(str_index_of(so_raw_str, "Java_com_maya_MayaNativeActivity_nativeInit") >= 0, "Exported JNI symbol present in .dynstr")
  e10 = assert_true(str_index_of(so_raw_str, "ANativeActivity_onCreate") >= 0, "Exported NativeActivity symbol present in .dynstr")
  e11 = assert_true(str_index_of(so_raw_str, "libmaya.so") >= 0, "SONAME present in .dynstr")

  @if e1 == 1 && e2 == 1 && e3 == 1 && e4 == 1 && e5 == 1 && e6 == 1 && e7 == 1 && e8 == 1 && e9 == 1 && e10 == 1 && e11 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 2: PKZip APK Byte-Stream Packager & Alignment
  println("▶ Section 2: PKZip APK Packager, Central Directory & 4096-Byte Alignment...")
  total_tests = total_tests + 1
  apk = mobile_build_android_apk("com.maya.superapp", "Maya SuperApp")
  apk_bytes = apk.apk_raw_bytes

  @! 1. Local File Header signature PK\x03\x04 (80, 75, 3, 4)
  z1 = assert_eq_int(apk_bytes[0], 80, "Local header signature byte 0 (80)")
  z2 = assert_eq_int(apk_bytes[1], 75, "Local header signature byte 1 (75)")
  z3 = assert_eq_int(apk_bytes[2], 3, "Local header signature byte 2 (3)")
  z4 = assert_eq_int(apk_bytes[3], 4, "Local header signature byte 3 (4)")

  @! 2. Check CRC-32 calculation on standard vector "123456789"
  test_crc_vec = [49, 50, 51, 52, 53, 54, 55, 56, 57]
  test_crc_val = crc32_bytes(test_crc_vec)
  z5 = assert_eq_int(test_crc_val, 3421780262, "CRC-32 vector check ('123456789' -> 0xCBF43926)")

  @! 3. Check for Central Directory Header PK\x02\x01 (80, 75, 1, 2) in byte stream
  found_cd = 0
  found_eocd = 0
  so_payload_offset = 0
  scan_i = 0
  scan_limit = apk_bytes.len() - 4
  @while scan_i < scan_limit
    @if apk_bytes[scan_i] == 80 && apk_bytes[scan_i + 1] == 75 && apk_bytes[scan_i + 2] == 1 && apk_bytes[scan_i + 3] == 2
      found_cd = 1
    @end
    @if apk_bytes[scan_i] == 80 && apk_bytes[scan_i + 1] == 75 && apk_bytes[scan_i + 2] == 5 && apk_bytes[scan_i + 3] == 6
      found_eocd = 1
    @end
    @! Find where lib/arm64-v8a/libmaya.so local header starts
    @if apk_bytes[scan_i] == 108 && apk_bytes[scan_i + 1] == 105 && apk_bytes[scan_i + 2] == 98 && apk_bytes[scan_i + 3] == 47
      h_start = scan_i - 30
      @if h_start >= 0 && apk_bytes[h_start] == 80 && apk_bytes[h_start + 1] == 75 && apk_bytes[h_start + 2] == 3 && apk_bytes[h_start + 3] == 4
        fn_len = apk_bytes[h_start + 26] | (apk_bytes[h_start + 27] * 256)
        extra_len = apk_bytes[h_start + 28] | (apk_bytes[h_start + 29] * 256)
        so_payload_offset = h_start + 30 + fn_len + extra_len
      @end
    @end
    scan_i = scan_i + 1
  @end

  z6 = assert_true(found_cd == 1, "Central Directory records PK\\x02\\x01 present in APK")
  z7 = assert_true(found_eocd == 1, "End of Central Directory record PK\\x05\\x06 present in APK")

  @! 4. Check 4096-byte alignment of .so file payload
  is_aligned_4096 = 0
  @if so_payload_offset > 0 && (so_payload_offset % 4096) == 0
    is_aligned_4096 = 1
  @end
  z8 = assert_true(is_aligned_4096 == 1, "libmaya.so payload is aligned to 4096-byte page boundary (offset: " + so_payload_offset.to_str() + ")")

  @if z1 == 1 && z2 == 1 && z3 == 1 && z4 == 1 && z5 == 1 && z6 == 1 && z7 == 1 && z8 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 3: Persistent Key-Value Storage CRUD & Durability
  println("▶ Section 3: File-Backed Persistent Key-Value Storage Engine...")
  total_tests = total_tests + 1
  test_kv_path = "test_sandbox_storage.kv"
  storage_clear_at(test_kv_path)

  @! Basic CRUD
  p1 = assert_eq_str(storage_get_at(test_kv_path, "user_id"), "none", "Get nonexistent key returns 'none'")
  storage_set_at(test_kv_path, "user_id", "10042")
  p2 = assert_eq_int(storage_has_at(test_kv_path, "user_id"), 1, "Has existing key returns 1")
  p3 = assert_eq_str(storage_get_at(test_kv_path, "user_id"), "10042", "Get existing key returns stored value")

  @! Update existing key
  storage_set_at(test_kv_path, "user_id", "20088")
  p4 = assert_eq_str(storage_get_at(test_kv_path, "user_id"), "20088", "Updated key returns new value")

  @! Complex characters (spaces, newlines, colons, equals signs)
  complex_val = "Line 1: data=true\nLine 2: status=active; value=\"ok\""
  storage_set_at(test_kv_path, "session:complex=key", complex_val)
  p5 = assert_eq_str(storage_get_at(test_kv_path, "session:complex=key"), complex_val, "Roundtrips complex keys and values with special characters")

  @! Delete
  storage_delete_at(test_kv_path, "user_id")
  p6 = assert_eq_int(storage_has_at(test_kv_path, "user_id"), 0, "Has deleted key returns 0")
  p7 = assert_eq_str(storage_get_at(test_kv_path, "user_id"), "none", "Get deleted key returns 'none'")

  @! Clear
  storage_clear_at(test_kv_path)
  p8 = assert_eq_str(storage_get_at(test_kv_path, "session:complex=key"), "none", "Clear removes all keys")

  @if p1 == 1 && p2 == 1 && p3 == 1 && p4 == 1 && p5 == 1 && p6 == 1 && p7 == 1 && p8 == 1
    passed_tests = passed_tests + 1
  @end

  @! Clean up test file
  storage_clear_at(test_kv_path)

  @! SECTION 4: Apple iOS IPA Package & 120 FPS Direct Surface
  println("▶ Section 4: Apple iOS IPA Package Generator & 120 FPS Surface...")
  total_tests = total_tests + 1
  ipa = mobile_build_ios_ipa("com.maya.iosapp", "Maya iOS App")
  m1 = assert_true(str_index_of(ipa.mach_o_binary_name, "MayaApp_arm64") >= 0, "Mach-O ARM64 binary targeted")
  m2 = assert_true(str_index_of(ipa.info_plist_xml, "CFBundleIdentifier") >= 0, "Info.plist structure generated")
  m3 = assert_eq_int(ipa.is_ipa_signed, 1, "iOS IPA package signed")

  surf = mobile_surface_new(1080, 2400, "SurfaceFlinger")
  surf = mobile_surface_push_frame(surf, 16711680)
  m4 = assert_eq_int(surf.refresh_rate_hz, 120, "Surface refresh rate 120 FPS")
  m5 = assert_eq_int(surf.pixel_buffer.len(), 4, "Surface frame buffer pixels")

  @if m1 == 1 && m2 == 1 && m3 == 1 && m4 == 1 && m5 == 1
    passed_tests = passed_tests + 1
  @end

  println("=================================================================")
  println("📊 MOBILE ENGINE & STORAGE TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 MOBILE ENGINE & STORAGE TEST SUITES PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MOBILE TESTS FAILED")
    return 1
  @end
@end
