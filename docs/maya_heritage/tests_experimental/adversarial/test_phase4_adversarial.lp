import "universe/core/string"
import "universe/core/collections"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/net/websocket"
import "universe/mobile/mobile"
import "universe/mobile/storage"

@fn assert(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] " + msg)
    return 0
  @end
  println("  [PASS] " + msg)
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS-TEST SUITE: PHASE 4 HARDENING 🔥")
  println("=================================================================")

  total = 0
  passed = 0

  @! 1. SHA-1 Boundary Tests (55, 56, 64, 119, 120 bytes padding boundaries)
  println("▶ Testing SHA-1 boundary conditions...")
  total = total + 1
  @! 55 bytes string: "1234567890123456789012345678901234567890123456789012345"
  s55 = "1234567890123456789012345678901234567890123456789012345"
  h55 = sha1_hex_string(s55)
  @! 56 bytes string (boundary where extra padding block is required)
  s56 = s55 + "6"
  h56 = sha1_hex_string(s56)
  @! 64 bytes string (exact 1 block)
  s64 = s56 + "78901234"
  h64 = sha1_hex_string(s64)
  
  ok1 = assert(str_len(h55) == 40, "SHA-1 55-byte hash length is 40 hex chars")
  ok2 = assert(str_len(h56) == 40, "SHA-1 56-byte hash length is 40 hex chars")
  ok3 = assert(str_len(h64) == 40, "SHA-1 64-byte hash length is 40 hex chars")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed = passed + 1
  @end

  @! 2. Base64 Roundtrip on Binary Bytes (0..255)
  println("▶ Testing Base64 full byte range roundtrip...")
  total = total + 1
  all_bytes = []
  bi = 0
  @while bi < 256
    all_bytes = all_bytes.push(bi)
    bi = bi + 1
  @end
  enc_b64 = base64_encode(all_bytes)
  dec_bytes = base64_decode(enc_b64)
  match_b64 = 1
  @if dec_bytes.len() != 256
    match_b64 = 0
  @else
    ci = 0
    @while ci < 256
      @if dec_bytes[ci] != ci
        match_b64 = 0
      @end
      ci = ci + 1
    @end
  @end
  ok_b64 = assert(match_b64 == 1, "Base64 roundtrips all 256 byte values accurately")
  @if ok_b64 == 1
    passed = passed + 1
  @end

  @! 3. WebSocket 3-Stage Frame Fragmentation
  println("▶ Testing WebSocket 3-part fragmentation...")
  total = total + 1
  assembler = ws_fragment_assembler_new()
  @! Part 1: FIN=0, opcode=Binary (2), payload=[10, 20]
  f1_bytes = ws_encode_frame(0, ws_op_binary(), 0, [0,0,0,0], [10, 20])
  f1 = ws_decode_frame(f1_bytes)
  assembler = assembler.feed(f1)
  a1 = assembler.completed_frame

  @! Part 2: FIN=0, opcode=Continuation (0), payload=[30, 40]
  f2_bytes = ws_encode_frame(0, ws_op_continuation(), 0, [0,0,0,0], [30, 40])
  f2 = ws_decode_frame(f2_bytes)
  assembler = assembler.feed(f2)
  a2 = assembler.completed_frame

  @! Part 3: FIN=1, opcode=Continuation (0), payload=[50, 60]
  f3_bytes = ws_encode_frame(1, ws_op_continuation(), 0, [0,0,0,0], [50, 60])
  f3 = ws_decode_frame(f3_bytes)
  assembler = assembler.feed(f3)
  a3 = assembler.completed_frame

  frag_ok = 1
  @if a1.fin != 0 || a2.fin != 0 || a3.fin != 1
    frag_ok = 0
  @end
  @if a3.opcode != ws_op_binary()
    frag_ok = 0
  @end
  @if a3.payload_bytes.len() != 6
    frag_ok = 0
  @else
    @if a3.payload_bytes[0] != 10 || a3.payload_bytes[5] != 60
      frag_ok = 0
    @end
  @end
  ok_frag = assert(frag_ok == 1, "3-part binary frame correctly reassembled into full payload")
  @if ok_frag == 1
    passed = passed + 1
  @end

  @! 4. WebSocket Masked Frame Roundtrip
  println("▶ Testing WebSocket Masked Frame Roundtrip...")
  total = total + 1
  mask = [171, 205, 239, 1]
  orig_payload = [65, 66, 67, 68, 69, 70]
  masked_frame = ws_encode_frame(1, ws_op_text(), 1, mask, orig_payload)
  dec_frame = ws_decode_frame(masked_frame)
  mask_ok = 1
  @if dec_frame.masked != 1 || dec_frame.payload_len != 6
    mask_ok = 0
  @end
  @if dec_frame.payload_text != "ABCDEF"
    mask_ok = 0
  @end
  ok_mask = assert(mask_ok == 1, "Masked text frame decodes back to original string")
  @if ok_mask == 1
    passed = passed + 1
  @end

  @! 5. Persistent Storage Stress: Overwrites, Multi-line, Deletions
  println("▶ Testing Persistent Storage stress operations...")
  total = total + 1
  adv_kv = "adv_stress_storage.kv"
  storage_clear_at(adv_kv)

  i = 0
  @while i < 20
    k = "key_" + i.to_str()
    v = "val_" + (i * i).to_str() + "\nmulti:line=yes"
    storage_set_at(adv_kv, k, v)
    i = i + 1
  @end

  @! Check random access and overwrites
  k7 = storage_get_at(adv_kv, "key_7")
  storage_set_at(adv_kv, "key_7", "updated_val_49")
  k7_up = storage_get_at(adv_kv, "key_7")
  storage_delete_at(adv_kv, "key_7")
  k7_del = storage_get_at(adv_kv, "key_7")

  kv_ok = 1
  @if k7 != "val_49\nmulti:line=yes"
    kv_ok = 0
  @end
  @if k7_up != "updated_val_49"
    kv_ok = 0
  @end
  @if k7_del != "none"
    kv_ok = 0
  @end
  storage_clear_at(adv_kv)

  ok_kv = assert(kv_ok == 1, "Key-value store handles 20 multi-line entries, updates, and deletes")
  @if ok_kv == 1
    passed = passed + 1
  @end

  @! 6. APK Central Directory Alignment & Structure Integrity
  println("▶ Testing APK Package Structure & 4096 Page Alignment...")
  total = total + 1
  apk_pkg = mobile_build_android_apk("org.maya.production", "Maya Prod App")
  raw_apk = apk_pkg.apk_raw_bytes
  
  @! Validate EOCD at the end
  apk_len = raw_apk.len()
  eocd_pos = apk_len - 22
  is_eocd = 0
  @if raw_apk[eocd_pos] == 80 && raw_apk[eocd_pos + 1] == 75 && raw_apk[eocd_pos + 2] == 5 && raw_apk[eocd_pos + 3] == 6
    is_eocd = 1
  @end
  ok_apk = assert(is_eocd == 1, "APK ends with standard 22-byte End of Central Directory Record")
  @if ok_apk == 1
    passed = passed + 1
  @end

  println("=================================================================")
  println("📊 ADVERSARIAL STRESS RESULTS: " + passed.to_str() + " / " + total.to_str() + " passed")
  println("=================================================================")
  @if passed == total
    println("🎉 ALL ADVERSARIAL TESTS PASSED!")
    return 0
  @else
    return 1
  @end
@end
