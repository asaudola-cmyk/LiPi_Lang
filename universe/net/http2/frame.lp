@! ============================================================================
@! LIPI UNIVERSE NETWORKING: HTTP/2 FRAME CODEC
@! Module: universe/net/http2/frame
@! 100% Pure Lipi Implementation — RFC 7540
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn HTTP2_FRAME_DATA() return 0 @end
@fn HTTP2_FRAME_HEADERS() return 1 @end
@fn HTTP2_FRAME_PRIORITY() return 2 @end
@fn HTTP2_FRAME_RST_STREAM() return 3 @end
@fn HTTP2_FRAME_SETTINGS() return 4 @end
@fn HTTP2_FRAME_PUSH_PROMISE() return 5 @end
@fn HTTP2_FRAME_PING() return 6 @end
@fn HTTP2_FRAME_GOAWAY() return 7 @end
@fn HTTP2_FRAME_WINDOW_UPDATE() return 8 @end
@fn HTTP2_FRAME_CONTINUATION() return 9 @end

@struct Http2Frame
  length: i64
  frame_type: i64
  flags: i64
  stream_id: i64
  payload: array
@end

@fn http2_parse_frame_header(bytes)
  @if bytes.len() < 9
    return { length: 0, frame_type: 0, flags: 0, stream_id: 0, payload: [] }
  @end

  b0 = bytes[0] & 255
  b1 = bytes[1] & 255
  b2 = bytes[2] & 255
  t0 = b0 * 65536
  t1 = b1 * 256
  t01 = t0 | t1
  num_items = t01 | b2

  ftype = bytes[3] & 255
  flags = bytes[4] & 255

  s0 = bytes[5] & 127
  s1 = bytes[6] & 255
  s2 = bytes[7] & 255
  s3 = bytes[8] & 255
  w0 = s0 * 16777216
  w1 = s1 * 65536
  w2 = s2 * 256
  r01 = w0 | w1
  r23 = w2 | s3
  stream_id = r01 | r23

  return {
    length: num_items,
    frame_type: ftype,
    flags: flags,
    stream_id: stream_id,
    payload: []
  }
@end

@fn http2_encode_frame_header(frame_type, flags, stream_id, payload_len)
  hdr = []
  b0 = (payload_len / 65536) & 255
  hdr = hdr.push(b0)
  b1 = (payload_len / 256) & 255
  hdr = hdr.push(b1)
  b2 = payload_len & 255
  hdr = hdr.push(b2)
  b3 = frame_type & 255
  hdr = hdr.push(b3)
  b4 = flags & 255
  hdr = hdr.push(b4)
  b5 = (stream_id / 16777216) & 127
  hdr = hdr.push(b5)
  b6 = (stream_id / 65536) & 255
  hdr = hdr.push(b6)
  b7 = (stream_id / 256) & 255
  hdr = hdr.push(b7)
  b8 = stream_id & 255
  hdr = hdr.push(b8)
  return hdr
@end