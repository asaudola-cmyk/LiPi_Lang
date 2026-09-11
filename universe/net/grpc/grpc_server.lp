@! ============================================================================
@! LIPI UNIVERSE NETWORKING: gRPC SERVER
@! Module: universe/net/grpc/grpc_server
@! 100% Pure Lipi Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct GrpcMethodDef
  name: string
  service_name: string
@end

@struct GrpcServer
  methods: array
  is_running: i64
@end

@fn grpc_server_new() -> GrpcServer
  return {
    methods: [],
    is_running: 0
  }
@end

@fn grpc_server_register_method(server: GrpcServer, service_name: string, method_name: string) -> GrpcServer
  server.methods = server.methods.push({
    name: method_name,
    service_name: service_name
  })
  return server
@end

@fn grpc_server_frame_response(payload_bytes: array) -> array
  out = [0] @! Not compressed
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
