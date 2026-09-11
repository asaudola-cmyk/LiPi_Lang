@! ============================================================================
@! MAYA UNIVERSE NETWORKING: gRPC CLIENT & CHANNELS
@! Module: universe/net/grpc/grpc_client
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct GrpcChannel
  host: string
  port: i64
  is_connected: i64
@end

@struct GrpcStub
  channel: GrpcChannel
  service_name: string
@end

@fn grpc_channel_new(host: string, port: i64) -> GrpcChannel
  return {
    host: host,
    port: port,
    is_connected: 1
  }
@end

@fn grpc_stub_new(channel: GrpcChannel, service_name: string) -> GrpcStub
  return {
    channel: channel,
    service_name: service_name
  }
@end

@fn grpc_frame_unary_request(payload_bytes: array) -> array
  out = [0] @! Compression flag = 0
  num_items = payload_bytes.len()
  out = out.push((num_items / 16777216) & 255)
  out = out.push((num_items / 65536) & 255)
  out = out.push((num_items / 256) & 255)
  out = out.push(len & 255)

  i = 0
  @while i < num_items
    out = out.push(payload_bytes[i] & 255)
    i = i + 1
  @end
  return out
@end

@fn main()
  return 0
@end
