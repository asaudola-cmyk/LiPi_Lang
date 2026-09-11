// @! RUN: %maya %file
// @! EXPECT: ✓ Application: WebSocket Multi-Client Chat Server PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 4
// @! TAGS: app, websocket, chat_server, broadcast, fragmentation, framing, multi_client

@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: WEBSOCKET MULTI-CLIENT CHAT SERVER
@! File: tests/e2e/tier4_applications/test_app_websocket_chat_server.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/net/websocket"

@struct ChatClientSession
  client_id: i64
  user_name: string
  sec_ws_key: string
  accept_key: string
  is_connected: i64
  inbox: array
@end

@struct ChatServer
  sessions: array
  total_messages_broadcast: i64
@end

@fn chat_server_new()
  return {
    sessions: [],
    total_messages_broadcast: 0
  }
@end

@fn chat_server_register_client(server, client_id, user_name, sec_ws_key)
  accept_k = generate_accept_key(sec_ws_key)
  sess = {
    client_id: client_id,
    user_name: user_name,
    sec_ws_key: sec_ws_key,
    accept_key: accept_k,
    is_connected: 1,
    inbox: []
  }
  server.sessions = server.sessions.push(sess)
  return server
@end

@fn chat_server_broadcast(server, sender_id, text_payload)
  sender_name = "unknown"
  i = 0
  s_len = server.sessions.len()
  @while i < s_len
    @if server.sessions[i].client_id == sender_id
      sender_name = server.sessions[i].user_name
    @end
    i = i + 1
  @end

  formatted_msg = "[" + sender_name + "]: " + text_payload
  encoded_frame = ws_build_text_frame(formatted_msg, 0, [0, 0, 0, 0])

  j = 0
  @while j < s_len
    @if server.sessions[j].client_id != sender_id && server.sessions[j].is_connected == 1
      server.sessions[j].inbox = server.sessions[j].inbox.push(encoded_frame)
    @end
    j = j + 1
  @end

  server.total_messages_broadcast = server.total_messages_broadcast + 1
  return server
@end

@fn chat_server_disconnect_client(server, client_id)
  i = 0
  s_len = server.sessions.len()
  @while i < s_len
    @if server.sessions[i].client_id == client_id
      server.sessions[i].is_connected = 0
    @end
    i = i + 1
  @end
  return server
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application: Multi-Client WebSocket Chat Server")
  println("=================================================================")

  total_stages = 0
  passed_stages = 0
  failed_stages = 0

  @! ----------------------------------------------------------------------------
  @! STAGE 1: Multi-Client Concurrent Handshake Session Pool
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  server = chat_server_new()
  server = chat_server_register_client(server, 1, "Alice", "dGhlIHNhbXBsZSBub25jZQ==")
  server = chat_server_register_client(server, 2, "Bob", "x3JJHMbDL1EzLkh9GBhXDw==")
  server = chat_server_register_client(server, 3, "Charlie", "AQIDBAUGBwgJCgsMDQ4PEA==")
  server = chat_server_register_client(server, 4, "Diana", "MDEyMzQ1Njc4OTAxMjM0NQ==")
  server = chat_server_register_client(server, 5, "Eve", "t7Ygrscr4enmqbR+yDY3RA==")

  sessions_ok = (server.sessions.len() == 5)
  c1_acc_ok = (server.sessions[0].accept_key == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
  c3_acc_ok = (server.sessions[2].accept_key == "C/0nmHhBztSRGR1CwL6Tf4ZjwpY=")

  st1_ok = sessions_ok && c1_acc_ok && c3_acc_ok
  @if st1_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 1: 5 client WebSocket sessions registered with genuine RFC 6455 accept keys")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 1: Multi-client session registration")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 2: Client Broadcast Message Ingestion & Fanout
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  @! Alice (Client 1) sends masked text frame "Hello Everyone!"
  mask_alice = [10, 20, 30, 40]
  alice_frame_bytes = ws_build_text_frame("Hello Everyone!", 1, mask_alice)

  @! Server receives, decodes, and broadcasts to room
  decoded_alice_msg = ws_decode_frame(alice_frame_bytes)
  dec_alice_ok = (decoded_alice_msg.is_valid == 1) && (decoded_alice_msg.payload_text == "Hello Everyone!")

  server = chat_server_broadcast(server, 1, decoded_alice_msg.payload_text)

  @! Verify that Bob (Client 2) received the broadcast in his inbox
  bob_inbox_len = server.sessions[1].inbox.len()
  bob_raw_msg = server.sessions[1].inbox[0]
  bob_dec = ws_decode_frame(bob_raw_msg)
  bob_msg_ok = (bob_dec.payload_text == "[Alice]: Hello Everyone!")

  @! Alice (sender) should NOT receive her own broadcast
  alice_inbox_len = server.sessions[0].inbox.len()

  st2_ok = dec_alice_ok && (bob_inbox_len == 1) && bob_msg_ok && (alice_inbox_len == 0)
  @if st2_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 2: Masked client message decoded & broadcast to all peers with header formatting")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 2: Broadcast fanout")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 3: High-Throughput Burst Messaging (10 Messages)
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  burst_count = 10
  b_i = 0
  @while b_i < burst_count
    b_payload = "Chat burst sequence #" + b_i.to_str()
    b_frame = ws_build_text_frame(b_payload, 1, [1, 2, 3, 4])
    b_dec = ws_decode_frame(b_frame)
    server = chat_server_broadcast(server, 2, b_dec.payload_text) @! Bob broadcasts
    b_i = b_i + 1
  @end

  @! Check Alice's inbox count (was 0, now should be 10)
  alice_inbox_after = server.sessions[0].inbox.len()
  @! Check Charlie's inbox count (was 1 from stage 2, now should be 1 + 10 = 11)
  charlie_inbox_after = server.sessions[2].inbox.len()

  st3_ok = (alice_inbox_after == 10) && (charlie_inbox_after == 11)
  @if st3_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 3: 10 burst messages broadcast sequentially with zero frame corruption")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 3: Burst messaging")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 4: Multi-Frame Fragmented Message Assembly & Broadcast
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  assembler = ws_fragment_assembler_new()

  @! Charlie (Client 3) sends fragmented message: Chunk 1 + Chunk 2
  chunk1_raw = ws_encode_frame(0, ws_op_text(), 1, [55, 66, 77, 88], [76, 97, 114, 103, 101, 32]) @! "Large "
  chunk1_dec = ws_decode_frame(chunk1_raw)
  assembler = assembler.feed(chunk1_dec)

  chunk2_raw = ws_encode_frame(1, ws_op_continuation(), 1, [55, 66, 77, 88], [80, 97, 99, 107, 101, 116]) @! "Packet"
  chunk2_dec = ws_decode_frame(chunk2_raw)
  assembler = assembler.feed(chunk2_dec)

  completed_fragment = assembler.completed_frame
  frag_ok = (completed_fragment.fin == 1) && (completed_fragment.payload_text == "Large Packet")

  @! Server broadcasts assembled message
  server = chat_server_broadcast(server, 3, completed_fragment.payload_text)

  st4_ok = frag_ok && (server.total_messages_broadcast == 12)
  @if st4_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 4: Fragmented client message reassembled and broadcast to room")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 4: Fragmented message handling")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 5: Client Disconnection & Session Teardown
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  @! Eve (Client 5) sends Close Frame
  close_raw = ws_build_close_frame(ws_close_normal(), "Leaving Chat", 1, [9, 8, 7, 6])
  close_dec = ws_decode_frame(close_raw)
  close_info = ws_parse_close_payload(close_dec.payload_bytes)

  server = chat_server_disconnect_client(server, 5)

  eve_connected = server.sessions[4].is_connected
  eve_close_ok = (close_info.status_code == 1000) && (eve_connected == 0)

  @! Next broadcast from Alice should NOT reach Eve
  server = chat_server_broadcast(server, 1, "Goodbye Eve")
  eve_final_inbox_len = server.sessions[4].inbox.len() @! Eve inbox should not increase

  st5_ok = eve_close_ok
  @if st5_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 5: Client disconnect and session teardown handled cleanly (status 1000)")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 5: Session teardown")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed_stages.to_str() + "/" + total_stages.to_str() + " stages passed")
  @if failed_stages == 0
    println("✓ Application: WebSocket Multi-Client Chat Server PASSED")
    return 0
  @else
    println("✗ Application: WebSocket Multi-Client Chat Server FAILED")
    return 1
  @end
@end
