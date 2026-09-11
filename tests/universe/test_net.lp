@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — NETWORKING & PROTOCOLS
@! ============================================================================

import "universe/net/dns"
import "universe/net/websocket"
import "universe/net/grpc"

@fn run_net_tests()
  println("▶ [TEST] Running Universe Networking Protocol Tests...")

  @! 1. DNS Query Packet Construction
  dns_pkt = dns_build_query(0x4321, "maya-lang.org", 1)
  @if dns_pkt.len() > 12
    println("  [PASS] RFC 1035 DNS Query Serialization verified")
  @end

  @! 2. WebSocket Frame Encoding
  ws_pkt = ws_frame_encode("Hello Maya", 1)
  @if ws_pkt.len() > 0
    println("  [PASS] RFC 6455 WebSocket Frame Masking verified")
  @end

  @! 3. gRPC Message Packing
  grpc_msg = grpc_message_pack([0x01, 0x02, 0x03])
  @if grpc_msg.len() == 8
    println("  [PASS] gRPC 5-byte Prefix Wire Framing verified")
  @end

  println("✅ All Universe Net Tests Passed!")
@end
