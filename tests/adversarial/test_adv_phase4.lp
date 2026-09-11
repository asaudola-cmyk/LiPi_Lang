@! ============================================================================
@! MAYA PHASE 4 ADVERSARIAL & EDGE-CASE HARDENING SUITE
@! File: tests/adversarial/test_adv_phase4.maya
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/net/websocket"
import "universe/mobile/mobile"
import "universe/mobile/storage"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  [ADV FAIL] " + msg)
    return 0
  @end
  println("  [ADV PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  [ADV PASS] " + msg)
    return 1
  @else
    println("  [ADV FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  [ADV PASS] " + msg)
    return 1
  @else
    println("  [ADV FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS TEST: PHASE 4 HARDENING 🔥")
  println("=================================================================")

  total_adv = 0
  passed_adv = 0

  @! --- 1. SHA-1 Boundary Stress Tests ---
  println("▶ [1/5] Testing SHA-1 Block Boundary Conditions...")
  @! 55 bytes: fits in one block before padding byte (55 + 1 + 8 = 64 bytes)
  s55 = "1234567890123456789012345678901234567890123456789012345"
  h55 = sha1_hex_string(s55)
  @! 56 bytes: forces 2-block transform (56 + 1 + 8 = 65 bytes > 64)
  s56 = "12345678901234567890123456789012345678901234567890123456"
  h56 = sha1_hex_string(s56)
  @! 64 bytes: exactly one block
  s64 = "1234567890123456789012345678901234567890123456789012345678901234"
  h64 = sha1_hex_string(s64)

  r1 = assert_eq_str(h55, "827a683fdfdbef225a2421078b7789b134c7eafa", "SHA-1 55-byte boundary vector")
  r2 = assert_eq_str(h56, "0a84666b66e843a4146088fb46aabaa998b4c2b1", "SHA-1 56-byte 2-block spill boundary vector")
  r3 = assert_eq_str(h64, "c71490fc24aa3d19e11282da77032dd9cdb33103", "SHA-1 64-byte block boundary vector")
  total_adv = total_adv + 3
  passed_adv = passed_adv + r1 + r2 + r3

  @! --- 2. Base64 RFC Stress Tests ---
  println("▶ [2/5] Testing Base64 Boundary & Padding...")
  @! 1 byte: 2 padding '='
  b_1 = base64_encode_string("M")
  d_1 = base64_decode_to_string("TQ==")
  @! 2 bytes: 1 padding '='
  b_2 = base64_encode_string("Ma")
  d_2 = base64_decode_to_string("TWE=")
  @! 3 bytes: 0 padding '='
  b_3 = base64_encode_string("May")
  d_3 = base64_decode_to_string("TWF5")

  r4 = assert_eq_str(b_1, "TQ==", "Base64 'M' -> 'TQ=='")
  r5 = assert_eq_str(d_1, "M", "Base64 'TQ==' -> 'M'")
  r6 = assert_eq_str(b_2, "TWE=", "Base64 'Ma' -> 'TWE='")
  r7 = assert_eq_str(d_2, "Ma", "Base64 'TWE=' -> 'Ma'")
  r8 = assert_eq_str(b_3, "TWF5", "Base64 'May' -> 'TWF5'")
  r9 = assert_eq_str(d_3, "May", "Base64 'TWF5' -> 'May'")
  total_adv = total_adv + 6
  passed_adv = passed_adv + r4 + r5 + r6 + r7 + r8 + r9

  @! --- 3. WebSocket Complex Framing & Error Handling ---
  println("▶ [3/5] Testing WebSocket Framing, Masking & Fragments...")
  @! Decode truncated frame (< 2 bytes)
  tr1 = ws_decode_frame([129])
  r10 = assert_eq_int(tr1.is_valid, 0, "Decode rejects truncated frame < 2 bytes")

  @! Decode truncated 16-bit payload length
  tr2 = ws_decode_frame([129, 126, 1])
  r11 = assert_eq_int(tr2.is_valid, 0, "Decode rejects truncated 16-bit length")

  @! Test 3-step fragmented message with interleaved Pong frame
  asm = ws_fragment_assembler_new()
  @! Chunk 1 (Text, FIN=0): "The "
  c1_f = ws_decode_frame(ws_encode_frame(0, ws_op_text(), 0, [0,0,0,0], [84, 104, 101, 32]))
  asm = asm.feed(c1_f)
  r12 = assert_eq_int(asm.in_progress, 1, "Assembler in_progress == 1 after chunk 1")

  @! Interleaved Pong control frame
  pong_f = ws_decode_frame(ws_build_pong_frame([1, 2], 0, [0,0,0,0]))
  asm = asm.feed(pong_f)
  r13 = assert_eq_int(asm.completed_frame.opcode, ws_op_pong(), "Interleaved Pong passed through")
  r14 = assert_eq_int(asm.in_progress, 1, "Assembler stays in_progress during control frame")

  @! Chunk 2 (Continuation, FIN=0): "Quick "
  c2_f = ws_decode_frame(ws_encode_frame(0, ws_op_continuation(), 0, [0,0,0,0], [81, 117, 105, 99, 107, 32]))
  asm = asm.feed(c2_f)

  @! Chunk 3 (Continuation, FIN=1): "Fox!"
  c3_f = ws_decode_frame(ws_encode_frame(1, ws_op_continuation(), 0, [0,0,0,0], [70, 111, 120, 33]))
  asm = asm.feed(c3_f)
  res_final = asm.completed_frame
  r15 = assert_eq_int(res_final.fin, 1, "3-step assembly completed with FIN=1")
  r16 = assert_eq_int(res_final.opcode, ws_op_text(), "3-step assembly restored original opcode Text (1)")
  r17 = assert_eq_str(res_final.payload_text, "The Quick Fox!", "3-step assembly payload text matches")
  total_adv = total_adv + 8
  passed_adv = passed_adv + r10 + r11 + r12 + r13 + r14 + r15 + r16 + r17

  @! --- 4. Mobile ARM64 ELF64 & PKZip Central Directory Integrity ---
  println("▶ [4/5] Testing Mobile ARM64 ELF64 & PKZip Architecture...")
  apk = mobile_build_android_apk("org.maya.testapp", "Adversarial App")
  raw_apk = apk.apk_raw_bytes
  r18 = assert_true(raw_apk.len() > 1000, "APK total byte size > 1000 bytes")

  @! Verify EOCD record points to valid CD start
  eocd_pos = raw_apk.len() - 22
  r19 = assert_eq_int(raw_apk[eocd_pos], 80, "EOCD byte 0 == 'P'")
  r20 = assert_eq_int(raw_apk[eocd_pos + 1], 75, "EOCD byte 1 == 'K'")
  r21 = assert_eq_int(raw_apk[eocd_pos + 2], 5, "EOCD byte 2 == 5")
  r22 = assert_eq_int(raw_apk[eocd_pos + 3], 6, "EOCD byte 3 == 6")

  cd_offset = raw_apk[eocd_pos + 16] | (raw_apk[eocd_pos + 17] * 256) | (raw_apk[eocd_pos + 18] * 65536) | (raw_apk[eocd_pos + 19] * 16777216)
  r23 = assert_eq_int(raw_apk[cd_offset], 80, "CD start byte 0 == 'P'")
  r24 = assert_eq_int(raw_apk[cd_offset + 1], 75, "CD start byte 1 == 'K'")
  r25 = assert_eq_int(raw_apk[cd_offset + 2], 1, "CD start byte 2 == 1")
  r26 = assert_eq_int(raw_apk[cd_offset + 3], 2, "CD start byte 3 == 2")
  total_adv = total_adv + 9
  passed_adv = passed_adv + r18 + r19 + r20 + r21 + r22 + r23 + r24 + r25 + r26

  @! --- 5. Persistent Storage Durability Stress ---
  println("▶ [5/5] Testing Persistent Storage Edge Cases & Multiple Keys...")
  adv_kv = "test_adv_storage.kv"
  storage_clear_at(adv_kv)

  @! Write 10 distinct keys
  k_i = 0
  @while k_i < 10
    k_name = "key_" + k_i.to_str()
    k_val = "val_" + (k_i * 37).to_str()
    storage_set_at(adv_kv, k_name, k_val)
    k_i = k_i + 1
  @end

  @! Verify all 10 keys persisted
  all_ok = 1
  k_i = 0
  @while k_i < 10
    k_name = "key_" + k_i.to_str()
    exp_val = "val_" + (k_i * 37).to_str()
    act_val = storage_get_at(adv_kv, k_name)
    @if act_val != exp_val
      all_ok = 0
    @end
    k_i = k_i + 1
  @end
  r27 = assert_eq_int(all_ok, 1, "Persisted 10 keys accurately")

  @! Overwrite keys
  k_i = 0
  @while k_i < 5
    k_name = "key_" + k_i.to_str()
    storage_set_at(adv_kv, k_name, "updated_" + k_i.to_str())
    k_i = k_i + 1
  @end
  @! Delete keys
  k_i = 5
  @while k_i < 10
    k_name = "key_" + k_i.to_str()
    storage_delete_at(adv_kv, k_name)
    k_i = k_i + 2
  @end

  r28 = assert_eq_str(storage_get_at(adv_kv, "key_3"), "updated_3", "Key 3 updated properly")
  r29 = assert_eq_str(storage_get_at(adv_kv, "key_5"), "none", "Key 5 deleted properly")
  r30 = assert_eq_str(storage_get_at(adv_kv, "key_6"), "val_222", "Key 6 intact")

  storage_clear_at(adv_kv)
  total_adv = total_adv + 4
  passed_adv = passed_adv + r27 + r28 + r29 + r30

  println("=================================================================")
  println("📊 ADVERSARIAL TEST RESULTS: " + passed_adv.to_str() + " / " + total_adv.to_str() + " passed")
  println("=================================================================")
  @if passed_adv == total_adv
    println("🎉 ALL ADVERSARIAL STRESS TESTS PASSED WITH 100% SUCCESS! 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL TESTS DETECTED FAILURES!")
    return 1
  @end
@end
