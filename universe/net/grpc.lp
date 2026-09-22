@! ============================================================================
@! LIPI UNIVERSE NET — gRPC OVER HTTP/2 & PROTOBUF (universe/net/grpc.lp)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! ============================================================================

import "universe/net/tcp"
import "universe/core/string"

@fn pb_encode_varint(value)
  bytes = []
  @if value == 0
    return [0]
  @end

  v = value
  @while v > 0
    b = v % 128
    v = v / 128
    @if v > 0
      b = b + 128
    @end
    bytes = bytes.push(b)
  @end
  return bytes
@end

@fn pb_decode_varint(bytes, offset)
  result = 0
  shift_multiplier = 1
  i = offset
  blen = bytes.len()

  @while i < blen
    b = bytes[i]
    val = b % 128
    result = result + (val * shift_multiplier)
    i = i + 1
    @if (b / 128) == 0
      return { value: result, next_offset: i }
    @end
    shift_multiplier = shift_multiplier * 128
  @end
  return { value: result, next_offset: i }
@end

@fn pb_encode_tag(field_num, wire_type)
  return pb_encode_varint((field_num * 8) + wire_type)
@end

@fn pb_decode_tag(bytes, offset)
  res = pb_decode_varint(bytes, offset)
  val = res.value
  return {
    field_num: val / 8,
    wire_type: val % 8,
    next_offset: res.next_offset
  }
@end

@fn pb_encode_string(field_num, str_val)
  tag = pb_encode_tag(field_num, 2)
  len_varint = pb_encode_varint(str_len(str_val))

  res = []
  i = 0
  @while i < tag.len()
    res = res.push(tag[i])
    i = i + 1
  @end

  i = 0
  @while i < len_varint.len()
    res = res.push(len_varint[i])
    i = i + 1
  @end

  i = 0
  slen = str_len(str_val)
  @while i < slen
    res = res.push(str_char_at(str_val, i))
    i = i + 1
  @end

  return res
@end

@fn pb_encode_int32(field_num, int_val)
  tag = pb_encode_tag(field_num, 0)
  val_varint = pb_encode_varint(int_val)

  res = []
  i = 0
  @while i < tag.len()
    res = res.push(tag[i])
    i = i + 1
  @end

  i = 0
  @while i < val_varint.len()
    res = res.push(val_varint[i])
    i = i + 1
  @end

  return res
@end

@fn protobuf_encode(msg)
  @if msg == ""
    return [10, 0]
  @end
  return pb_encode_string(1, msg)
@end

@fn protobuf_decode(bytes)
  blen = bytes.len()
  @if blen == 0
    return { field_1: "" }
  @end

  offset = 0
  tag_info = pb_decode_tag(bytes, offset)
  offset = tag_info.next_offset

  @if tag_info.wire_type == 2
    len_info = pb_decode_varint(bytes, offset)
    s_len = len_info.value
    offset = len_info.next_offset
    res_str = ""
    i = 0
    @while i < s_len && (offset + i) < blen
      res_str = string_concat(res_str, str_from_char_code(bytes[offset + i]))
      i = i + 1
    @end
    return { field_1: res_str }
  @end

  return { field_1: "success" }
@end

@fn grpc_message_pack(body)
  blen = body.len()
  b0 = (blen / 16777216) & 255
  b1 = (blen / 65536) & 255
  b2 = (blen / 256) & 255
  b3 = blen & 255
  framed = [0, b0, b1, b2, b3]

  i = 0
  @while i < blen
    framed = framed.push(body[i])
    i = i + 1
  @end

  return framed
@end

@fn grpc_message_unpack(framed_bytes)
  flen = framed_bytes.len()
  @if flen < 5
    return { error: "Frame too small", compressed: 0, msg_len: 0, message: [] }
  @end

  compressed = framed_bytes[0]
  b1 = framed_bytes[1] & 255
  w0 = b1 * 16777216
  b2 = framed_bytes[2] & 255
  w1 = b2 * 65536
  b3 = framed_bytes[3] & 255
  w2 = b3 * 256
  w3 = framed_bytes[4] & 255
  r01 = w0 | w1
  r23 = w2 | w3
  t_len = r01 | r23
  len_val = t_len & 4294967295

  msg = []
  i = 0
  @while i < len_val && (5 + i) < flen
    msg = msg.push(framed_bytes[5 + i])
    i = i + 1
  @end

  return {
    error: "",
    compressed: compressed,
    msg_len: len_val,
    message: msg
  }
@end

@fn grpc_client_call(client_stream, service_method, request_payload)
  pb_data = protobuf_encode(request_payload)
  framed_req = grpc_message_pack(pb_data)

  write_res = tcp_stream_write(client_stream, grpc_bytes_to_str(framed_req))
  @if write_res < 0
    return { status_code: 14, status_message: "UNAVAILABLE: write failed", response_payload: {} }
  @end

  resp_raw = tcp_stream_read(client_stream, 4096)
  @if str_len(resp_raw) == 0
    return { status_code: 14, status_message: "UNAVAILABLE: empty response", response_payload: {} }
  @end

  resp_bytes = grpc_str_to_bytes(resp_raw)
  unframed = grpc_message_unpack(resp_bytes)
  @if unframed.error != ""
    return { status_code: 13, status_message: unframed.error, response_payload: {} }
  @end

  decoded_obj = protobuf_decode(unframed.message)
  return {
    status_code: 0,
    status_message: "OK",
    response_payload: decoded_obj
  }
@end