// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: WebSocket & Persistent Storage Pipeline PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 3
// @! TAGS: net, websocket, storage, combination, json, framing, persistence

@! ============================================================================
@! MAYA E2E TIER 3 — COMBINATORIAL: WEBSOCKET + PERSISTENT STORAGE
@! File: tests/e2e/tier3_combinations/test_net_websocket_storage.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/net/websocket"
import "universe/mobile/storage"

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination: WebSocket Protocol + Persistent Storage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  ws_storage_path = "ws_pipeline_storage.kv"
  storage_clear_at(ws_storage_path)

  @! ----------------------------------------------------------------------------
  @! TC-WS-STO-01: WebSocket Handshake & Session Initialization
  @! ----------------------------------------------------------------------------
  total = total + 1
  client_ws_key = "dGhlIHNhbXBsZSBub25jZQ=="
  accept_key = generate_accept_key(client_ws_key)
  handshake_resp = ws_build_handshake_response(client_ws_key)
  hs_key_ok = (accept_key == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
  hs_r1 = (str_index_of(handshake_resp, "101 Switching Protocols") >= 0)
  hs_r2 = (str_index_of(handshake_resp, "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") >= 0)
  hs_resp_ok = hs_r1 && hs_r2
  @if hs_key_ok && hs_resp_ok
    passed = passed + 1
    println("  [PASS] TC-WS-STO-01: RFC 6455 WebSocket Handshake established successfully")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WS-STO-01: WebSocket Handshake")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-WS-STO-02: Client Masked JSON Payload Ingestion -> Persistent Store Write
  @! ----------------------------------------------------------------------------
  total = total + 1
  json_payload = "{\"action\":\"store_profile\",\"user_id\":\"user_999\",\"role\":\"admin\",\"token\":\"abc123xyz\"}"
  mask_key = [18, 52, 86, 120] @! [0x12, 0x34, 0x56, 0x78]
  masked_frame_bytes = ws_build_text_frame(json_payload, 1, mask_key)

  @! Server receives and decodes client frame
  decoded_frame = ws_decode_frame(masked_frame_bytes)
  dec_ok = (decoded_frame.is_valid == 1) && (decoded_frame.opcode == ws_op_text()) && (decoded_frame.payload_text == json_payload)

  @! Server extracts key/value and commits to persistent store
  storage_set_at(ws_storage_path, "user:999:profile", decoded_frame.payload_text)
  stored_val = storage_get_at(ws_storage_path, "user:999:profile")
  store_ok = (stored_val == json_payload)

  @if dec_ok && store_ok
    passed = passed + 1
    println("  [PASS] TC-WS-STO-02: Masked WebSocket frame decoded and written to disk storage")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WS-STO-02: Frame decoding and storage write")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-WS-STO-03: Storage Lookup -> Server WebSocket Response Frame Generation
  @! ----------------------------------------------------------------------------
  total = total + 1
  @! Server looks up key in storage and packages response frame
  fetched_profile = storage_get_at(ws_storage_path, "user:999:profile")
  resp_json = "{\"status\":\"ok\",\"record\":" + fetched_profile + "}"
  server_resp_frame_bytes = ws_build_text_frame(resp_json, 0, [0, 0, 0, 0])

  @! Client receives and decodes unmasked server response
  client_dec_frame = ws_decode_frame(server_resp_frame_bytes)
  resp_ok = (client_dec_frame.is_valid == 1) && (client_dec_frame.masked == 0) && (client_dec_frame.payload_text == resp_json)
  @if resp_ok
    passed = passed + 1
    println("  [PASS] TC-WS-STO-03: Storage record packaged into unmasked WebSocket response frame")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WS-STO-03: Server response frame generation")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-WS-STO-04: Multi-Message Stream with Storage CRUD Pipeline
  @! ----------------------------------------------------------------------------
  total = total + 1
  msg_count = 5
  all_stream_ok = 1
  m_idx = 0
  @while m_idx < msg_count
    item_key = "device:sensor:" + m_idx.to_str()
    item_val = "{\"temp\":" + (20 + m_idx).to_str() + ",\"humidity\":55}"
    msg_bytes = ws_build_text_frame(item_val, 1, [7, 14, 21, 28])
    msg_dec = ws_decode_frame(msg_bytes)
    @if msg_dec.is_valid == 0
      all_stream_ok = 0
    @end
    storage_set_at(ws_storage_path, item_key, msg_dec.payload_text)
    m_idx = m_idx + 1
  @end

  @! Verify all 5 sensor records in storage
  chk_idx = 0
  @while chk_idx < msg_count
    s_val = storage_get_at(ws_storage_path, "device:sensor:" + chk_idx.to_str())
    @if str_index_of(s_val, "temp") < 0
      all_stream_ok = 0
    @end
    chk_idx = chk_idx + 1
  @end

  @if all_stream_ok == 1
    passed = passed + 1
    println("  [PASS] TC-WS-STO-04: 5-message continuous WebSocket data ingestion persisted to disk")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WS-STO-04: Multi-message stream persistence")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-WS-STO-05: WebSocket Close Protocol & Session Storage Cleanup
  @! ----------------------------------------------------------------------------
  total = total + 1
  close_frame_bytes = ws_build_close_frame(ws_close_normal(), "Session Finished", 1, [1, 2, 3, 4])
  dec_close = ws_decode_frame(close_frame_bytes)
  close_info = ws_parse_close_payload(dec_close.payload_bytes)

  close_ok = (dec_close.opcode == ws_op_close()) && (close_info.status_code == 1000)
  @if close_ok
    passed = passed + 1
    println("  [PASS] TC-WS-STO-05: WebSocket connection closed cleanly with status 1000")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WS-STO-05: WebSocket close protocol")
  @end

  @! Cleanup test file
  storage_clear_at(ws_storage_path)

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: WebSocket & Persistent Storage Pipeline PASSED")
    return 0
  @else
    println("✗ Feature: WebSocket & Persistent Storage Pipeline FAILED")
    return 1
  @end
@end
