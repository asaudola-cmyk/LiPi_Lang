@! ============================================================================
@! MAYA UNIVERSE NETWORKING: HTTP/2 STREAM STATE MACHINE
@! Module: universe/net/http2/stream
@! 100% Pure Maya Implementation — RFC 7540
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn HTTP2_STREAM_STATE_IDLE() return 0 @end
@fn HTTP2_STREAM_STATE_OPEN() return 1 @end
@fn HTTP2_STREAM_STATE_HALF_CLOSED_LOCAL() return 2 @end
@fn HTTP2_STREAM_STATE_HALF_CLOSED_REMOTE() return 3 @end
@fn HTTP2_STREAM_STATE_CLOSED() return 4 @end

@struct Http2Stream
  id: i64
  state: i64
  window_size: i64
@end

@fn http2_stream_new(id: i64) -> Http2Stream
  return {
    id: id,
    state: 0, @! Idle
    window_size: 65535
  }
@end

@fn http2_stream_receive_data(stream: Http2Stream, num_items: i64) -> Http2Stream
  stream.window_size = stream.window_size - num_items
  return stream
@end

@fn http2_stream_send_window_update(stream: Http2Stream, increment: i64) -> Http2Stream
  stream.window_size = stream.window_size + increment
  return stream
@end
