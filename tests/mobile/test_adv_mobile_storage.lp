@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE — MAYA MOBILE & PERSISTENT STORAGE
@! File: tests/mobile/test_adv_mobile_storage.maya
@! Milestone: Phase 4 Challenger 2 Verification
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/mobile/mobile"
import "universe/mobile/storage"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  [FAIL] " + msg)
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

@! ============================================================================
@! 1. PERSISTENT STORAGE 120+ KEYS STRESS TEST
@! ============================================================================

@fn test_storage_stress(db_path: string) -> i64
  println("-----------------------------------------------------------------")
  println("TEST 1: Persistent Storage 120+ Keys with Special Characters")
  println("-----------------------------------------------------------------")

  storage_clear_at(db_path)

  passed = 1
  total_keys = 120

  @! Phase 1: Write 120 keys with various special character combinations
  k_idx = 0
  @while k_idx < total_keys
    key_name = ""
    val_data = ""

    @if k_idx < 20
      @! Category A: Standard alpha-numeric with spaces and colons
      key_name = "user:" + k_idx.to_str() + ":profile_key with spaces"
      val_data = "Profile Value #" + k_idx.to_str() + " (status: active, level: " + (k_idx * 5).to_str() + ")"
    @elif k_idx < 40
      @! Category B: Equals signs, quotes, and punctuation
      key_name = "config:env=" + k_idx.to_str() + ";token=\"xyz_" + k_idx.to_str() + "\";flag=true"
      val_data = "value=\"quoted value with 'single' and `backticks` and = equals\"; num=" + k_idx.to_str()
    @elif k_idx < 60
      @! Category C: Multiline strings with newlines and indentation
      key_name = "multiline:doc:" + k_idx.to_str()
      val_data = "Line 1: Header for key " + k_idx.to_str() + "\n  Line 2: Indented content [index=" + k_idx.to_str() + "]\nLine 3: Final line with colon: end;"
    @elif k_idx < 80
      @! Category D: Binary hex strings and byte markers
      key_name = "bin:hex:0x00ff" + k_idx.to_str() + "_deadbeef"
      val_data = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f_" + k_idx.to_str()
    @elif k_idx < 100
      @! Category E: Slashes, brackets, mathematical symbols, JSON-like structures
      key_name = "path/to/resource/item[" + k_idx.to_str() + "]/field{sub_id}"
      val_data = "{\"item_id\": " + k_idx.to_str() + ", \"tags\": [\"alpha\", \"beta\", \"gamma\"], \"nested\": {\"valid\": true, \"score\": 99.85}}"
    @else
      @! Category F: Heavy punctuation, delimiters, and edge cases
      key_name = "edge::===:::;;;@@@###$$$%%%^^^&&&***((()))___+++" + k_idx.to_str()
      val_data = "!@#$%^&*()_+-=[]{}|;':,./<>?~`\n\tSpecial Payload " + k_idx.to_str()
    @end

    res = storage_set_at(db_path, key_name, val_data)
    @if res != 1
      println("  [FAIL] Failed to set key: " + key_name)
      passed = 0
    @end

    k_idx = k_idx + 1
  @end

  @! Phase 2: Verify all 120 keys exist and match exactly
  k_idx = 0
  read_errors = 0
  @while k_idx < total_keys
    key_name = ""
    expected_val = ""

    @if k_idx < 20
      key_name = "user:" + k_idx.to_str() + ":profile_key with spaces"
      expected_val = "Profile Value #" + k_idx.to_str() + " (status: active, level: " + (k_idx * 5).to_str() + ")"
    @elif k_idx < 40
      key_name = "config:env=" + k_idx.to_str() + ";token=\"xyz_" + k_idx.to_str() + "\";flag=true"
      expected_val = "value=\"quoted value with 'single' and `backticks` and = equals\"; num=" + k_idx.to_str()
    @elif k_idx < 60
      key_name = "multiline:doc:" + k_idx.to_str()
      expected_val = "Line 1: Header for key " + k_idx.to_str() + "\n  Line 2: Indented content [index=" + k_idx.to_str() + "]\nLine 3: Final line with colon: end;"
    @elif k_idx < 80
      key_name = "bin:hex:0x00ff" + k_idx.to_str() + "_deadbeef"
      expected_val = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f_" + k_idx.to_str()
    @elif k_idx < 100
      key_name = "path/to/resource/item[" + k_idx.to_str() + "]/field{sub_id}"
      expected_val = "{\"item_id\": " + k_idx.to_str() + ", \"tags\": [\"alpha\", \"beta\", \"gamma\"], \"nested\": {\"valid\": true, \"score\": 99.85}}"
    @else
      key_name = "edge::===:::;;;@@@###$$$%%%^^^&&&***((()))___+++" + k_idx.to_str()
      expected_val = "!@#$%^&*()_+-=[]{}|;':,./<>?~`\n\tSpecial Payload " + k_idx.to_str()
    @end

    has_k = storage_has_at(db_path, key_name)
    actual_val = storage_get_at(db_path, key_name)

    @if has_k != 1
      println("  [FAIL] Missing key: " + key_name)
      read_errors = read_errors + 1
    @end
    @if actual_val != expected_val
      println("  [FAIL] Value mismatch for key: " + key_name)
      read_errors = read_errors + 1
    @end

    k_idx = k_idx + 1
  @end

  p1 = assert_eq_int(read_errors, 0, "120/120 keys inserted and retrieved with exact value fidelity")

  @! Phase 3: Overwrite 40 keys (keys 0..39)
  ow_idx = 0
  ow_errors = 0
  @while ow_idx < 40
    key_name = ""
    @if ow_idx < 20
      key_name = "user:" + ow_idx.to_str() + ":profile_key with spaces"
    @else
      key_name = "config:env=" + ow_idx.to_str() + ";token=\"xyz_" + ow_idx.to_str() + "\";flag=true"
    @end
    new_val = "OVERWRITTEN_VALUE_FOR_KEY_" + ow_idx.to_str() + "_NEW_VERSION_2.0"
    storage_set_at(db_path, key_name, new_val)
    val_check = storage_get_at(db_path, key_name)
    @if val_check != new_val
      ow_errors = ow_errors + 1
    @end
    ow_idx = ow_idx + 1
  @end
  p2 = assert_eq_int(ow_errors, 0, "40 keys overwritten and verified")

  @! Phase 4: Delete 30 keys (keys 40..69)
  del_idx = 40
  del_errors = 0
  @while del_idx < 70
    key_name = ""
    @if del_idx < 60
      key_name = "multiline:doc:" + del_idx.to_str()
    @else
      key_name = "bin:hex:0x00ff" + del_idx.to_str() + "_deadbeef"
    @end
    storage_delete_at(db_path, key_name)
    @if storage_has_at(db_path, key_name) != 0
      del_errors = del_errors + 1
    @end
    @if storage_get_at(db_path, key_name) != "none"
      del_errors = del_errors + 1
    @end
    del_idx = del_idx + 1
  @end
  p3 = assert_eq_int(del_errors, 0, "30 keys deleted and verified as 'none' and has=0")

  @! Phase 5: Check remaining keys (keys 70..119) are completely intact
  rem_idx = 70
  rem_errors = 0
  @while rem_idx < total_keys
    key_name = ""
    expected_val = ""
    @if rem_idx < 80
      key_name = "bin:hex:0x00ff" + rem_idx.to_str() + "_deadbeef"
      expected_val = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f_" + rem_idx.to_str()
    @elif rem_idx < 100
      key_name = "path/to/resource/item[" + rem_idx.to_str() + "]/field{sub_id}"
      expected_val = "{\"item_id\": " + rem_idx.to_str() + ", \"tags\": [\"alpha\", \"beta\", \"gamma\"], \"nested\": {\"valid\": true, \"score\": 99.85}}"
    @else
      key_name = "edge::===:::;;;@@@###$$$%%%^^^&&&***((()))___+++" + rem_idx.to_str()
      expected_val = "!@#$%^&*()_+-=[]{}|;':,./<>?~`\n\tSpecial Payload " + rem_idx.to_str()
    @end

    if_has = storage_has_at(db_path, key_name)
    val_cur = storage_get_at(db_path, key_name)
    @if if_has != 1 || val_cur != expected_val
      rem_errors = rem_errors + 1
    @end
    rem_idx = rem_idx + 1
  @end
  p4 = assert_eq_int(rem_errors, 0, "Remaining 50 untouched keys preserved with zero data corruption")

  @! Phase 6: Clear all
  storage_clear_at(db_path)
  p5 = assert_eq_str(storage_get_at(db_path, "user:0:profile_key with spaces"), "none", "Storage clear removes all records")
  p6 = assert_eq_int(storage_has_at(db_path, "edge::===:::;;;@@@###$$$%%%^^^&&&***((()))___+++119"), 0, "Storage clear verified empty")

  @if p1 == 1 && p2 == 1 && p3 == 1 && p4 == 1 && p5 == 1 && p6 == 1
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 2. ELF64 BINARY STRUCTURE & DYNAMIC SYMBOL IN-DEPTH VERIFICATION
@! ============================================================================

@fn test_elf64_binary_in_depth() -> i64
  println("-----------------------------------------------------------------")
  println("TEST 2: AArch64 ELF64 Shared Library Detailed Structural Audit")
  println("-----------------------------------------------------------------")

  so = mobile_emit_arm64_libmaya_so()
  so_len = so.len()

  @! 1. Header checks
  c1 = assert_eq_int(so_len, 1040, "libmaya.so total binary size = 1040 bytes")
  c2 = assert_eq_int(so[0], 127, "e_ident[EI_MAG0] = 0x7f")
  c3 = assert_eq_int(so[1], 69, "e_ident[EI_MAG1] = 'E'")
  c4 = assert_eq_int(so[2], 76, "e_ident[EI_MAG2] = 'L'")
  c5 = assert_eq_int(so[3], 70, "e_ident[EI_MAG3] = 'F'")
  c6 = assert_eq_int(so[4], 2, "e_ident[EI_CLASS] = ELFCLASS64 (2)")
  c7 = assert_eq_int(so[5], 1, "e_ident[EI_DATA] = ELFDATA2LSB (1)")
  c8 = assert_eq_int(so[6], 1, "e_ident[EI_VERSION] = EV_CURRENT (1)")
  c9 = assert_eq_int(so[7], 0, "e_ident[EI_OSABI] = ELFOSABI_NONE/SYSV (0)")

  @! e_type = ET_DYN (3) at offset 16
  e_type = so[16] | (so[17] * 256)
  c10 = assert_eq_int(e_type, 3, "e_type = ET_DYN (3)")

  @! e_machine = EM_AARCH64 (183) at offset 18
  e_mach = so[18] | (so[19] * 256)
  c11 = assert_eq_int(e_mach, 183, "e_machine = EM_AARCH64 (183)")

  @! e_entry = 240 (0xF0) at offset 24
  e_entry = so[24] | (so[25] * 256) | (so[26] * 65536) | (so[27] * 16777216)
  c12 = assert_eq_int(e_entry, 240, "e_entry = 240 (offset of .text instructions)")

  @! e_phoff = 64, e_shoff = 592
  e_phoff = so[32] | (so[33] * 256)
  e_shoff = so[40] | (so[41] * 256)
  c13 = assert_eq_int(e_phoff, 64, "e_phoff = 64 bytes")
  c14 = assert_eq_int(e_shoff, 592, "e_shoff = 592 bytes")

  @! e_phnum = 3, e_shnum = 7
  e_phnum = so[56] | (so[57] * 256)
  e_shnum = so[60] | (so[61] * 256)
  c15 = assert_eq_int(e_phnum, 3, "e_phnum = 3 program headers")
  c16 = assert_eq_int(e_shnum, 7, "e_shnum = 7 section headers")

  @! 2. Check program headers: PT_PHDR (6), PT_LOAD (1), PT_DYNAMIC (2)
  p0_type = so[64] | (so[65] * 256)
  p1_type = so[120] | (so[121] * 256)
  p2_type = so[176] | (so[177] * 256)
  c17 = assert_eq_int(p0_type, 6, "Phdr 0 = PT_PHDR (6)")
  c18 = assert_eq_int(p1_type, 1, "Phdr 1 = PT_LOAD (1)")
  c19 = assert_eq_int(p2_type, 2, "Phdr 2 = PT_DYNAMIC (2)")

  @! 3. Check Dynamic tags (.dynamic at offset 432):
  @! Tag 1: DT_SONAME (14), Tag 2: DT_HASH (4), Tag 3: DT_STRTAB (5), Tag 4: DT_SYMTAB (6), Tag 5: DT_STRSZ (10), Tag 6: DT_SYMENT (11), Tag 7: DT_NULL (0)
  dyn_tag1 = so[432] | (so[433] * 256)
  dyn_tag2 = so[448] | (so[449] * 256)
  dyn_tag3 = so[464] | (so[465] * 256)
  dyn_tag4 = so[480] | (so[481] * 256)
  dyn_tag5 = so[496] | (so[497] * 256)
  dyn_tag6 = so[512] | (so[513] * 256)
  dyn_tag7 = so[528] | (so[529] * 256)

  c20 = assert_eq_int(dyn_tag1, 14, "DT_SONAME (14) dynamic tag present")
  c21 = assert_eq_int(dyn_tag2, 4, "DT_HASH (4) dynamic tag present")
  c22 = assert_eq_int(dyn_tag3, 5, "DT_STRTAB (5) dynamic tag present")
  c23 = assert_eq_int(dyn_tag4, 6, "DT_SYMTAB (6) dynamic tag present")
  c24 = assert_eq_int(dyn_tag5, 10, "DT_STRSZ (10) dynamic tag present")
  c25 = assert_eq_int(dyn_tag6, 11, "DT_SYMENT (11) dynamic tag present")
  c26 = assert_eq_int(dyn_tag7, 0, "DT_NULL (0) dynamic tag present")

  @! 4. Check instructions in .text: mov x0, #0; ret; mov x0, #0; ret
  c27 = assert_eq_int(so[240], 0, ".text inst 1 byte 0 (0x00)")
  c28 = assert_eq_int(so[241], 0, ".text inst 1 byte 1 (0x00)")
  c29 = assert_eq_int(so[242], 128, ".text inst 1 byte 2 (0x80)")
  c30 = assert_eq_int(so[243], 210, ".text inst 1 byte 3 (0xD2 -> mov x0, #0)")
  c31 = assert_eq_int(so[244], 192, ".text inst 2 byte 0 (0xC0)")
  c32 = assert_eq_int(so[245], 3, ".text inst 2 byte 1 (0x03)")
  c33 = assert_eq_int(so[246], 95, ".text inst 2 byte 2 (0x5F)")
  c34 = assert_eq_int(so[247], 214, ".text inst 2 byte 3 (0xD6 -> ret)")

  @if c1 == 1 && c2 == 1 && c3 == 1 && c4 == 1 && c5 == 1 && c6 == 1 && c7 == 1 && c8 == 1 && c9 == 1 && c10 == 1 && c11 == 1 && c12 == 1 && c13 == 1 && c14 == 1 && c15 == 1 && c16 == 1 && c17 == 1 && c18 == 1 && c19 == 1 && c20 == 1 && c21 == 1 && c22 == 1 && c23 == 1 && c24 == 1 && c25 == 1 && c26 == 1 && c27 == 1 && c28 == 1 && c29 == 1 && c30 == 1 && c31 == 1 && c32 == 1 && c33 == 1 && c34 == 1
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 3. PKZIP APK PAGE ALIGNMENT & INTEGRITY AUDIT
@! ============================================================================

@fn test_pkzip_apk_integrity() -> i64
  println("-----------------------------------------------------------------")
  println("TEST 3: PKZip APK File Integrity, Central Directory & Alignment")
  println("-----------------------------------------------------------------")

  apk = mobile_build_android_apk("com.maya.challenger", "ChallengerMobileApp")
  raw_bytes = apk.apk_raw_bytes
  raw_len = raw_bytes.len()

  z1 = assert_true(raw_len > 5000, "APK total size exceeds 5KB (actual: " + raw_len.to_str() + " bytes)")

  @! Verify all 4 local file headers
  found_manifest = 0
  found_dex = 0
  found_so = 0
  found_arsc = 0

  manifest_offset = -1
  dex_offset = -1
  so_payload_offset = -1
  arsc_offset = -1

  i = 0
  limit = raw_len - 30
  @while i < limit
    @if raw_bytes[i] == 80 && raw_bytes[i+1] == 75 && raw_bytes[i+2] == 3 && raw_bytes[i+3] == 4
      fn_len = raw_bytes[i + 26] | (raw_bytes[i + 27] * 256)
      ex_len = raw_bytes[i + 28] | (raw_bytes[i + 29] * 256)
      name_start = i + 30
      
      fname = ""
      n_i = 0
      @while n_i < fn_len
        fname = fname + str_from_char_code(raw_bytes[name_start + n_i] & 255)
        n_i = n_i + 1
      @end

      payload_start = name_start + fn_len + ex_len

      @if fname == "AndroidManifest.xml"
        found_manifest = 1
        manifest_offset = payload_start
      @elif fname == "classes.dex"
        found_dex = 1
        dex_offset = payload_start
      @elif fname == "lib/arm64-v8a/libmaya.so"
        found_so = 1
        so_payload_offset = payload_start
      @elif fname == "resources.arsc"
        found_arsc = 1
        arsc_offset = payload_start
      @end
    @end
    i = i + 1
  @end

  z2 = assert_eq_int(found_manifest, 1, "AndroidManifest.xml local header found")
  z3 = assert_eq_int(found_dex, 1, "classes.dex local header found")
  z4 = assert_eq_int(found_so, 1, "lib/arm64-v8a/libmaya.so local header found")
  z5 = assert_eq_int(found_arsc, 1, "resources.arsc local header found")

  @! Exact 4096-byte page alignment check
  z6 = assert_eq_int(so_payload_offset, 4096, "libmaya.so payload start offset is EXACTLY 4096 (4KB page aligned)")
  z7 = assert_eq_int(so_payload_offset % 4096, 0, "libmaya.so payload start offset modulo 4096 is 0")

  @if z1 == 1 && z2 == 1 && z3 == 1 && z4 == 1 && z5 == 1 && z6 == 1 && z7 == 1
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 4. MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("⚔️  MAYA PHASE 4 ADVERSARIAL STRESS TEST HARNESS — CHALLENGER 2 ⚔️")
  println("=================================================================")

  t1 = test_storage_stress("test_adv_sandbox_storage.kv")
  t2 = test_elf64_binary_in_depth()
  t3 = test_pkzip_apk_integrity()

  total = 3
  passed = t1 + t2 + t3

  println("=================================================================")
  println("📊 ADVERSARIAL CHALLENGER SUITE SUMMARY: " + passed.to_str() + " / " + total.to_str() + " suites passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL 3 ADVERSARIAL TEST SUITES PASSED! 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL SUITE DETECTED FAILURES!")
    return 1
  @end
@end
