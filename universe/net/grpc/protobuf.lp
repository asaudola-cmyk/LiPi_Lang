@fn maya_pow2(n)
  @if n <= 0 return 1 @end
  res = 1
  i = 0
  @while i < n
    res = res * 2
    i = i + 1
  @end
  return res
@end

@! ============================================================================
@! MAYA UNIVERSE NETWORKING: PROTOCOL BUFFERS WIRE CODEC
@! Module: universe/net/grpc/protobuf
@! 100% Pure Maya Implementation — Zero External / C Dependencies
@! Features: LEB128 Varint Encoding/Decoding, ZigZag, Wire Types, Zero Synthetic Comments
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! Protocol Buffer Wire Types
@enum ProtoWireType
  Varint
  Fixed64
  LengthDelimited
  StartGroup
  EndGroup
  Fixed32
@end

@struct ProtoField
  field_number: i64
  wire_type: i64
  int_value: i64
  bytes_value: array
  string_value: string
@end

@! ----------------------------------------------------------------------------
@! 1. ZigZag 32-Bit & 64-Bit Encoding / Decoding
@! ----------------------------------------------------------------------------

@fn protobuf_encode_zigzag32(n: i64) -> i64
  @if n < 0
    return ((0 - n) * 2) - 1
  @end
  return n * 2
@end

@fn protobuf_decode_zigzag32(n: i64) -> i64
  @if n & 1 != 0
    return 0 - ((n + 1) / 2)
  @end
  return n / 2
@end

@! ----------------------------------------------------------------------------
@! 2. LEB128 Varint Codec
@! ----------------------------------------------------------------------------

@fn protobuf_encode_varint(val: i64) -> array
  bytes = []
  v = val
  @while v >= 128
    b = v & 127 | 128
    bytes = bytes.push(b)
    v = (v / 128)
  @end
  bytes = bytes.push(v & 127)
  return bytes
@end

@fn protobuf_decode_varint(data: array, offset: i64) -> array
  val = 0
  shift = 0
  consumed = 0
  num_items = data.len()
  curr = offset

  @while curr < num_items
    b = data[curr] & 255
    consumed = consumed + 1
    p = maya_pow2(shift)
    m = b & 127
    term = m * p
    val = val | term
    shift = shift + 7
    curr = curr + 1
    @if b & 128 == 0
      break
    @end
  @end

  return [val, consumed]
@end

@! ----------------------------------------------------------------------------
@! 3. Tag Helpers & Message Serialization
@! ----------------------------------------------------------------------------

@fn protobuf_make_tag(field_number: i64, wire_type: i64) -> i64
  return ((field_number * 8)) | wire_type & 7
@end

@fn protobuf_encode_int64(field_number: i64, val: i64) -> array
  tag = protobuf_make_tag(field_number, 0)
  tag_bytes = protobuf_encode_varint(tag)
  val_bytes = protobuf_encode_varint(val)
  out = []
  i = 0
  @while i < tag_bytes.len()
    out = out.push(tag_bytes[i])
    i = i + 1
  @end
  j = 0
  @while j < val_bytes.len()
    out = out.push(val_bytes[j])
    j = j + 1
  @end
  return out
@end

@fn protobuf_encode_string(field_number: i64, str_val: string) -> array
  tag = protobuf_make_tag(field_number, 2)
  tag_bytes = protobuf_encode_varint(tag)
  str_len_bytes = protobuf_encode_varint(str_len(str_val))

  out = []
  i = 0
  @while i < tag_bytes.len()
    out = out.push(tag_bytes[i])
    i = i + 1
  @end
  j = 0
  @while j < str_len_bytes.len()
    out = out.push(str_len_bytes[j])
    j = j + 1
  @end
  k = 0
  num_items = str_len(str_val)
  @while k < num_items
    out = out.push(str_char_at(str_val, k) & 255)
    k = k + 1
  @end
  return out
@end
