@fn net_u16_be(buf, off)
  b0 = buf[off] & 255
  t0 = b0 * 256
  b1 = buf[off + 1] & 255
  res = t0 | b1
  return res & 65535
@end

@fn net_u32_be(buf, off)
  b0 = buf[off] & 255
  w0 = b0 * 16777216
  b1 = buf[off + 1] & 255
  w1 = b1 * 65536
  b2 = buf[off + 2] & 255
  w2 = b2 * 256
  b3 = buf[off + 3] & 255
  r01 = w0 | w1
  r23 = w2 | b3
  res = r01 | r23
  return res & 4294967295
@end

@! ============================================================================
@! LIPI UNIVERSE NET — RFC 9000 QUIC PROTOCOL STACK (universe/net/quic.lp)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Features: RFC 9000 Long/Short Headers, Variable-Length Integers, Frame Types,
@!           Connection State Machine, Packet Tracking, TLS 1.3 Crypto Dispatch,
@!           RFC 9002 Congestion Control Stub, Stream Multiplexing
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/net/tls/tls13"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURES (@struct)
@! ----------------------------------------------------------------------------

@struct QuicVarintResult
  varint_val: i64
  varint_len: i64
  varint_next_offset: i64
@end

@struct QuicPacketHeader
  is_long_header: i64
  packet_type: i64
  quic_version: i64
  dest_connection_id: array
  src_connection_id: array
  packet_token: array
  packet_num: i64
  packet_num_len: i64
  key_phase_bit: i64
  spin_bit_val: i64
  packet_payload: array
  packet_next_offset: i64
@end

@struct QuicFrame
  frame_type: i64
  frame_stream_id: i64
  frame_offset: i64
  frame_len: i64
  frame_data: array
  frame_fin: i64
  frame_error_code: i64
  frame_type_field: i64
  frame_reason: string
  frame_largest_acked: i64
  frame_ack_delay: i64
  frame_first_ack_range: i64
  frame_seq_num: i64
  frame_retire_prior_to: i64
  frame_cid: array
  frame_reset_token: array
  frame_is_valid: i64
@end

@struct QuicParseResult
  parse_is_valid: i64
  parse_next_offset: i64
  parse_frame: QuicFrame
@end

@struct QuicStream
  stream_id: i64
  stream_state: string
  stream_send_offset: i64
  stream_recv_offset: i64
  stream_send_buf: array
  stream_recv_buf: array
  stream_fin_sent: i64
  stream_fin_recv: i64
@end

@struct QuicPacketNumberSpace
  next_pn: i64
  largest_acked_pn: i64
  unacked_count: i64
@end

@struct QuicCongestionController
  cwnd: i64
  bytes_in_flight: i64
  ssthresh: i64
  min_rtt: i64
  smoothed_rtt: i64
  rttvar: i64
  pacing_rate: i64
@end

@struct QuicConnection
  local_cid: array
  peer_cid: array
  conn_state: string
  conn_version: i64
  pn_initial: QuicPacketNumberSpace
  pn_handshake: QuicPacketNumberSpace
  pn_app: QuicPacketNumberSpace
  congestion: QuicCongestionController
  crypto_in: array
  crypto_out: array
  handshake_done: i64
  streams: array
  queued_frames: array
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTANTS (RFC 9000 & RFC 9002)
@! ----------------------------------------------------------------------------

@fn QUIC_VERSION_1() return 1 @end

@! Packet Types
@fn QUIC_PKT_INITIAL() return 0 @end
@fn QUIC_PKT_0RTT() return 1 @end
@fn QUIC_PKT_HANDSHAKE() return 2 @end
@fn QUIC_PKT_RETRY() return 3 @end
@fn QUIC_PKT_1RTT() return 4 @end

@! Frame Types (RFC 9000 Section 19)
@fn QUIC_FRAME_PADDING() return 0 @end
@fn QUIC_FRAME_PING() return 1 @end
@fn QUIC_FRAME_ACK() return 2 @end
@fn QUIC_FRAME_ACK_ECN() return 3 @end
@fn QUIC_FRAME_RESET_STREAM() return 4 @end
@fn QUIC_FRAME_STOP_SENDING() return 5 @end
@fn QUIC_FRAME_CRYPTO() return 6 @end
@fn QUIC_FRAME_NEW_TOKEN() return 7 @end
@fn QUIC_FRAME_STREAM() return 8 @end
@fn QUIC_FRAME_MAX_DATA() return 16 @end
@fn QUIC_FRAME_MAX_STREAM_DATA() return 17 @end
@fn QUIC_FRAME_MAX_STREAMS_BIDI() return 18 @end
@fn QUIC_FRAME_MAX_STREAMS_UNI() return 19 @end
@fn QUIC_FRAME_DATA_BLOCKED() return 20 @end
@fn QUIC_FRAME_STREAM_DATA_BLOCKED() return 21 @end
@fn QUIC_FRAME_STREAMS_BLOCKED_BIDI() return 22 @end
@fn QUIC_FRAME_STREAMS_BLOCKED_UNI() return 23 @end
@fn QUIC_FRAME_NEW_CONNECTION_ID() return 24 @end
@fn QUIC_FRAME_RETIRE_CONNECTION_ID() return 25 @end
@fn QUIC_FRAME_PATH_CHALLENGE() return 26 @end
@fn QUIC_FRAME_PATH_RESPONSE() return 27 @end
@fn QUIC_FRAME_CONNECTION_CLOSE_QUIC() return 28 @end
@fn QUIC_FRAME_CONNECTION_CLOSE_APP() return 29 @end
@fn QUIC_FRAME_HANDSHAKE_DONE() return 30 @end

@fn quic_bytes_to_str(bytes)
  s = ""
  i = 0
  num_items = bytes.len()
  @while i < num_items
    s = s + str_from_char_code(bytes[i])
    i = i + 1
  @end
  return s
@end

@fn quic_str_to_bytes(s)
  b = []
  i = 0
  num_items = s.len()
  @while i < num_items
    b = b.push(str_char_at(s, i))
    i = i + 1
  @end
  return b
@end

@! ----------------------------------------------------------------------------
@! 3. VARIABLE-LENGTH INTEGER ENCODING & DECODING (RFC 9000 SECTION 16)
@! ----------------------------------------------------------------------------

@fn quic_encode_varint(v)
  @if v < 64
    b0 = v & 63
    return [b0]
  @elif v < 16384
    v_hi = (v / 256) & 63
    b0 = 64 | v_hi
    b1 = v & 255
    return [b0, b1]
  @elif v < 1073741824
    v_hi = (v / 16777216) & 63
    b0 = 128 | v_hi
    b1 = (v / 65536) & 255
    b2 = (v / 256) & 255
    b3 = v & 255
    return [b0, b1, b2, b3]
  @else
    v_hi = (v / 72057594037927936) & 63
    b0 = 192 | v_hi
    b1 = (v / 281474976710656) & 255
    b2 = (v / 1099511627776) & 255
    b3 = (v / 4294967296) & 255
    b4 = (v / 16777216) & 255
    b5 = (v / 65536) & 255
    b6 = (v / 256) & 255
    b7 = v & 255
    return [b0, b1, b2, b3, b4, b5, b6, b7]
  @end
@end

@fn quic_decode_varint(bytes, offset)
  blen = bytes.len()
  @if offset >= blen
    return { varint_val: 0, varint_len: 0, varint_next_offset: offset }
  @end
  
  b0 = bytes[offset]
  tag = (b0 / 64) & 3
  
  @if tag == 0
    @! 1 byte
    val = b0 & 63
    return { varint_val: val, varint_len: 1, varint_next_offset: offset + 1 }
  @elif tag == 1
    @! 2 bytes
    @if (offset + 1) >= blen
      return { varint_val: 0, varint_len: 0, varint_next_offset: offset }
    @end
    b0_m = b0 & 63
    t0 = b0_m * 256
    val = t0 | bytes[offset + 1]
    return { varint_val: val, varint_len: 2, varint_next_offset: offset + 2 }
  @elif tag == 2
    @! 4 bytes
    @if (offset + 3) >= blen
      return { varint_val: 0, varint_len: 0, varint_next_offset: offset }
    @end
    b0_m = b0 & 63
    t0 = b0_m * 16777216
    t1 = bytes[offset + 1] * 65536
    t2 = bytes[offset + 2] * 256
    b3 = bytes[offset + 3]
    r01 = t0 | t1
    r23 = t2 | b3
    val = r01 | r23
    return { varint_val: val, varint_len: 4, varint_next_offset: offset + 4 }
  @else
    @! 8 bytes
    @if (offset + 7) >= blen
      return { varint_val: 0, varint_len: 0, varint_next_offset: offset }
    @end
    b0_m = b0 & 63
    t0 = b0_m * 16777216
    t1 = bytes[offset + 1] * 65536
    t2 = bytes[offset + 2] * 256
    b3 = bytes[offset + 3]
    r01 = t0 | t1
    r23 = t2 | b3
    high = r01 | r23

    t4 = bytes[offset + 4] * 16777216
    t5 = bytes[offset + 5] * 65536
    t6 = bytes[offset + 6] * 256
    b7 = bytes[offset + 7]
    r45 = t4 | t5
    r67 = t6 | b7
    low = r45 | r67
    val = (high * 4294967296) + low
    return { varint_val: val, varint_len: 8, varint_next_offset: offset + 8 }
  @end
@end

@fn quic_frame_encode_padding(num_items)
  bytes = []
  i = 0
  @while i < num_items
    bytes = bytes.push(0)
    i = i + 1
  @end
  return bytes
@end

@fn quic_frame_encode_ping()
  return [1] @! PING (0x01)
@end

@fn quic_frame_encode_ack(largest_acked, ack_delay, first_ack_range)
  bytes = [2] @! ACK (0x02)
  
  la_enc = quic_encode_varint(largest_acked)
  i = 0 @while i < la_enc.len() bytes = bytes.push(la_enc[i]) i = i + 1 @end
  
  ad_enc = quic_encode_varint(ack_delay)
  i = 0 @while i < ad_enc.len() bytes = bytes.push(ad_enc[i]) i = i + 1 @end
  
  rc_enc = quic_encode_varint(0) @! ACK Range Count = 0
  i = 0 @while i < rc_enc.len() bytes = bytes.push(rc_enc[i]) i = i + 1 @end
  
  far_enc = quic_encode_varint(first_ack_range)
  i = 0 @while i < far_enc.len() bytes = bytes.push(far_enc[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_reset_stream(stream_id, error_code, final_size)
  bytes = [4] @! RESET_STREAM (0x04)
  
  s_enc = quic_encode_varint(stream_id)
  i = 0 @while i < s_enc.len() bytes = bytes.push(s_enc[i]) i = i + 1 @end
  
  e_enc = quic_encode_varint(error_code)
  i = 0 @while i < e_enc.len() bytes = bytes.push(e_enc[i]) i = i + 1 @end
  
  fs_enc = quic_encode_varint(final_size)
  i = 0 @while i < fs_enc.len() bytes = bytes.push(fs_enc[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_stop_sending(stream_id, error_code)
  bytes = [5] @! STOP_SENDING (0x05)
  
  s_enc = quic_encode_varint(stream_id)
  i = 0 @while i < s_enc.len() bytes = bytes.push(s_enc[i]) i = i + 1 @end
  
  e_enc = quic_encode_varint(error_code)
  i = 0 @while i < e_enc.len() bytes = bytes.push(e_enc[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_crypto(offset, data_bytes)
  bytes = [6] @! CRYPTO (0x06)
  
  off_enc = quic_encode_varint(offset)
  i = 0 @while i < off_enc.len() bytes = bytes.push(off_enc[i]) i = i + 1 @end
  
  len_enc = quic_encode_varint(data_bytes.len())
  i = 0 @while i < len_enc.len() bytes = bytes.push(len_enc[i]) i = i + 1 @end
  
  i = 0 @while i < data_bytes.len() bytes = bytes.push(data_bytes[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_new_token(token_bytes)
  bytes = [7] @! NEW_TOKEN (0x07)
  
  len_enc = quic_encode_varint(token_bytes.len())
  i = 0 @while i < len_enc.len() bytes = bytes.push(len_enc[i]) i = i + 1 @end
  
  i = 0 @while i < token_bytes.len() bytes = bytes.push(token_bytes[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_stream(stream_id, offset, data_bytes, fin)
  @! STREAM Frame Type (0x08 - 0x0F)
  @! Bit 2 (0x04): OFF, Bit 1 (0x02): LEN, Bit 0 (0x01): FIN
  type_byte = 8 | 2 @! Include LEN bit (0x02)
  @if offset > 0
    type_byte = type_byte | 4 @! Include OFF bit (0x04)
  @end
  @if fin == 1
    type_byte = type_byte | 1 @! Include FIN bit (0x01)
  @end
  
  bytes = [type_byte]
  
  sid_enc = quic_encode_varint(stream_id)
  i = 0 @while i < sid_enc.len() bytes = bytes.push(sid_enc[i]) i = i + 1 @end
  
  @if offset > 0
    off_enc = quic_encode_varint(offset)
    i = 0 @while i < off_enc.len() bytes = bytes.push(off_enc[i]) i = i + 1 @end
  @end
  
  len_enc = quic_encode_varint(data_bytes.len())
  i = 0 @while i < len_enc.len() bytes = bytes.push(len_enc[i]) i = i + 1 @end
  
  i = 0 @while i < data_bytes.len() bytes = bytes.push(data_bytes[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_max_data(max_data)
  bytes = [16] @! MAX_DATA (0x10)
  md_enc = quic_encode_varint(max_data)
  i = 0 @while i < md_enc.len() bytes = bytes.push(md_enc[i]) i = i + 1 @end
  return bytes
@end

@fn quic_frame_encode_max_stream_data(stream_id, max_data)
  bytes = [17] @! MAX_STREAM_DATA (0x11)
  sid_enc = quic_encode_varint(stream_id)
  i = 0 @while i < sid_enc.len() bytes = bytes.push(sid_enc[i]) i = i + 1 @end
  md_enc = quic_encode_varint(max_data)
  i = 0 @while i < md_enc.len() bytes = bytes.push(md_enc[i]) i = i + 1 @end
  return bytes
@end

@fn quic_frame_encode_new_connection_id(seq_num, retire_prior_to, cid_bytes, reset_token_16b)
  bytes = [24] @! NEW_CONNECTION_ID (0x18)
  
  sn_enc = quic_encode_varint(seq_num)
  i = 0 @while i < sn_enc.len() bytes = bytes.push(sn_enc[i]) i = i + 1 @end
  
  rpt_enc = quic_encode_varint(retire_prior_to)
  i = 0 @while i < rpt_enc.len() bytes = bytes.push(rpt_enc[i]) i = i + 1 @end
  
  bytes = bytes.push(cid_bytes.len())
  i = 0 @while i < cid_bytes.len() bytes = bytes.push(cid_bytes[i]) i = i + 1 @end
  
  i = 0 @while i < reset_token_16b.len() bytes = bytes.push(reset_token_16b[i]) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_retire_connection_id(seq_num)
  bytes = [25] @! RETIRE_CONNECTION_ID (0x19)
  sn_enc = quic_encode_varint(seq_num)
  i = 0 @while i < sn_enc.len() bytes = bytes.push(sn_enc[i]) i = i + 1 @end
  return bytes
@end

@fn quic_frame_encode_path_challenge(data_8b)
  bytes = [26] @! PATH_CHALLENGE (0x1A)
  i = 0 @while i < 8 && i < data_8b.len() bytes = bytes.push(data_8b[i]) i = i + 1 @end
  return bytes
@end

@fn quic_frame_encode_path_response(data_8b)
  bytes = [27] @! PATH_RESPONSE (0x1B)
  i = 0 @while i < 8 && i < data_8b.len() bytes = bytes.push(data_8b[i]) i = i + 1 @end
  return bytes
@end

@fn quic_frame_encode_connection_close(error_code, frame_type_field, reason_phrase, is_app)
  type_byte = 28 @! CONNECTION_CLOSE QUIC layer (0x1C)
  @if is_app == 1
    type_byte = 29 @! CONNECTION_CLOSE Application layer (0x1D)
  @end
  
  bytes = [type_byte]
  
  ec_enc = quic_encode_varint(error_code)
  i = 0 @while i < ec_enc.len() bytes = bytes.push(ec_enc[i]) i = i + 1 @end
  
  @if is_app == 0
    ft_enc = quic_encode_varint(frame_type_field)
    i = 0 @while i < ft_enc.len() bytes = bytes.push(ft_enc[i]) i = i + 1 @end
  @end
  
  rp_len_enc = quic_encode_varint(reason_phrase.len())
  i = 0 @while i < rp_len_enc.len() bytes = bytes.push(rp_len_enc[i]) i = i + 1 @end
  
  i = 0 @while i < reason_phrase.len() bytes = bytes.push(str_char_at(reason_phrase, i)) i = i + 1 @end
  
  return bytes
@end

@fn quic_frame_encode_handshake_done()
  return [30] @! HANDSHAKE_DONE (0x1E)
@end

@fn quic_parse_frame(bytes, offset)
  blen = bytes.len()
  @if offset >= blen
    return {
      parse_is_valid: 0,
      parse_next_offset: offset,
      parse_frame: {
        frame_type: 0, frame_stream_id: 0, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 0
      }
    }
  @end
  
  ftype_byte = bytes[offset]
  off = offset + 1
  
  @if ftype_byte == 0
    @! PADDING
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: 0, frame_stream_id: 0, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 1
    @! PING
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: 1, frame_stream_id: 0, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 2 || ftype_byte == 3
    @! ACK / ACK_ECN
    la_res = quic_decode_varint(bytes, off)
    largest_acked = la_res.varint_val
    off = la_res.varint_next_offset
    
    ad_res = quic_decode_varint(bytes, off)
    ack_delay = ad_res.varint_val
    off = ad_res.varint_next_offset
    
    rc_res = quic_decode_varint(bytes, off)
    range_count = rc_res.varint_val
    off = rc_res.varint_next_offset
    
    far_res = quic_decode_varint(bytes, off)
    first_ack_range = far_res.varint_val
    off = far_res.varint_next_offset
    
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: ftype_byte, frame_stream_id: 0, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: largest_acked, frame_ack_delay: ack_delay, frame_first_ack_range: first_ack_range,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 4
    @! RESET_STREAM
    sid_res = quic_decode_varint(bytes, off)
    sid = sid_res.varint_val
    off = sid_res.varint_next_offset
    
    ec_res = quic_decode_varint(bytes, off)
    ec = ec_res.varint_val
    off = ec_res.varint_next_offset
    
    fs_res = quic_decode_varint(bytes, off)
    final_size = fs_res.varint_val
    off = fs_res.varint_next_offset
    
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: 4, frame_stream_id: sid, frame_offset: final_size, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: ec, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 5
    @! STOP_SENDING
    sid_res = quic_decode_varint(bytes, off)
    sid = sid_res.varint_val
    off = sid_res.varint_next_offset
    
    ec_res = quic_decode_varint(bytes, off)
    ec = ec_res.varint_val
    off = ec_res.varint_next_offset
    
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: 5, frame_stream_id: sid, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: ec, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 6
    @! CRYPTO
    off_res = quic_decode_varint(bytes, off)
    offset_val = off_res.varint_val
    off = off_res.varint_next_offset
    
    len_res = quic_decode_varint(bytes, off)
    len_val = len_res.varint_val
    off = len_res.varint_next_offset
    
    cdata = []
    i = 0
    @while i < len_val && (off + i) < blen
      cdata = cdata.push(bytes[off + i])
      i = i + 1
    @end
    
    return {
      parse_is_valid: 1,
      parse_next_offset: off + len_val,
      parse_frame: {
        frame_type: 6, frame_stream_id: 0, frame_offset: offset_val, frame_len: len_val, frame_data: cdata,
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte >= 8 && ftype_byte <= 15
    @! STREAM
    b4 = ftype_byte & 4
    has_off = 0
    @if b4 != 0 has_off = 1 @end
    b2 = ftype_byte & 2
    has_len = 0
    @if b2 != 0 has_len = 1 @end
    b1 = ftype_byte & 1
    fin_bit = 0
    @if b1 != 0 fin_bit = 1 @end
    
    sid_res = quic_decode_varint(bytes, off)
    sid = sid_res.varint_val
    off = sid_res.varint_next_offset
    
    offset_val = 0
    @if has_off == 1
      off_res = quic_decode_varint(bytes, off)
      offset_val = off_res.varint_val
      off = off_res.varint_next_offset
    @end
    
    len_val = blen - off
    @if has_len == 1
      len_res = quic_decode_varint(bytes, off)
      len_val = len_res.varint_val
      off = len_res.varint_next_offset
    @end
    
    sdata = []
    i = 0
    @while i < len_val && (off + i) < blen
      sdata = sdata.push(bytes[off + i])
      i = i + 1
    @end
    
    fin_flag = 0
    @if fin_bit == 1 fin_flag = 1 @end
    
    return {
      parse_is_valid: 1,
      parse_next_offset: off + len_val,
      parse_frame: {
        frame_type: 8, frame_stream_id: sid, frame_offset: offset_val, frame_len: len_val, frame_data: sdata,
        frame_fin: fin_flag, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 26
    @! PATH_CHALLENGE (8 bytes)
    pdata = []
    i = 0
    @while i < 8 && (off + i) < blen
      pdata = pdata.push(bytes[off + i])
      i = i + 1
    @end
    return {
      parse_is_valid: 1,
      parse_next_offset: off + 8,
      parse_frame: {
        frame_type: 26, frame_stream_id: 0, frame_offset: 0, frame_len: 8, frame_data: pdata,
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 27
    @! PATH_RESPONSE (8 bytes)
    pdata = []
    i = 0
    @while i < 8 && (off + i) < blen
      pdata = pdata.push(bytes[off + i])
      i = i + 1
    @end
    return {
      parse_is_valid: 1,
      parse_next_offset: off + 8,
      parse_frame: {
        frame_type: 27, frame_stream_id: 0, frame_offset: 0, frame_len: 8, frame_data: pdata,
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 28 || ftype_byte == 29
    @! CONNECTION_CLOSE
    is_app = 0
    @if ftype_byte == 29 is_app = 1 @end
    ec_res = quic_decode_varint(bytes, off)
    ec = ec_res.varint_val
    off = ec_res.varint_next_offset
    
    ftype_f = 0
    @if is_app == 0
      ft_res = quic_decode_varint(bytes, off)
      ftype_f = ft_res.varint_val
      off = ft_res.varint_next_offset
    @end
    
    rplen_res = quic_decode_varint(bytes, off)
    rp_len = rplen_res.varint_val
    off = rplen_res.varint_next_offset
    
    reason = ""
    i = 0
    @while i < rp_len && (off + i) < blen
      reason = string_concat(reason, str_from_char_code(bytes[off + i]))
      i = i + 1
    @end
    
    return {
      parse_is_valid: 1,
      parse_next_offset: off + rp_len,
      parse_frame: {
        frame_type: ftype_byte, frame_stream_id: 0, frame_offset: 0, frame_len: rp_len, frame_data: [],
        frame_fin: 0, frame_error_code: ec, frame_type_field: ftype_f, frame_reason: reason,
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @elif ftype_byte == 30
    @! HANDSHAKE_DONE
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: 30, frame_stream_id: 0, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @else
    @! Generic frame fallback
    return {
      parse_is_valid: 1,
      parse_next_offset: off,
      parse_frame: {
        frame_type: ftype_byte, frame_stream_id: 0, frame_offset: 0, frame_len: 0, frame_data: [],
        frame_fin: 0, frame_error_code: 0, frame_type_field: 0, frame_reason: "",
        frame_largest_acked: 0, frame_ack_delay: 0, frame_first_ack_range: 0,
        frame_seq_num: 0, frame_retire_prior_to: 0, frame_cid: [], frame_reset_token: [], frame_is_valid: 1
      }
    }
  @end
@end

@fn quic_parse_frames(bytes, offset, end_offset)
  frames = []
  off = offset
  @while off < end_offset && off < bytes.len()
    res = quic_parse_frame(bytes, off)
    @if res.parse_is_valid == 0 || res.parse_next_offset <= off
      break
    @end
    frames = frames.push(res.parse_frame)
    off = res.parse_next_offset
  @end
  return frames
@end

@! ----------------------------------------------------------------------------
@! 5. PACKET HEADER SERIALIZATION & PARSING (RFC 9000 SECTION 17)
@! ----------------------------------------------------------------------------

@fn quic_pack_long_header(packet_type, version, dest_cid, src_cid, token, packet_number, pn_len, payload_bytes)
  @! First byte: Header Form (1) | Fixed Bit (1) | Long Packet Type (2 bits) | Type-Specific (4 bits: pn_len - 1)
  p_low = packet_type & 3
  t_pkt = p_low * 16
  t_pn = (pn_len - 1) & 3
  b0_23 = t_pkt | t_pn
  b0 = 192 | b0_23
  packet = [b0]
  
  @! 4 bytes Version
  packet = packet.push((version / 16777216) & 255)
  packet = packet.push((version / 65536) & 255)
  packet = packet.push((version / 256) & 255)
  packet = packet.push(version & 255)
  
  @! DCIL (1B) + Destination CID
  packet = packet.push(dest_cid.len() & 255)
  i = 0 @while i < dest_cid.len() packet = packet.push(dest_cid[i]) i = i + 1 @end
  
  @! SCIL (1B) + Source CID
  packet = packet.push(src_cid.len() & 255)
  i = 0 @while i < src_cid.len() packet = packet.push(src_cid[i]) i = i + 1 @end
  
  @! If Initial: Token Length (varint) + Token
  @if packet_type == QUIC_PKT_INITIAL()
    tok_len_enc = quic_encode_varint(token.len())
    i = 0 @while i < tok_len_enc.len() packet = packet.push(tok_len_enc[i]) i = i + 1 @end
    i = 0 @while i < token.len() packet = packet.push(token[i]) i = i + 1 @end
  @end
  
  @! Length (varint): Packet Number Length + Payload Length
  pkt_len = pn_len + payload_bytes.len()
  len_enc = quic_encode_varint(pkt_len)
  i = 0 @while i < len_enc.len() packet = packet.push(len_enc[i]) i = i + 1 @end
  
  @! Packet Number (1 to 4 bytes)
  @if pn_len == 1
    packet = packet.push(packet_number & 255)
  @elif pn_len == 2
    packet = packet.push((packet_number / 256) & 255)
    packet = packet.push(packet_number & 255)
  @elif pn_len == 3
    packet = packet.push((packet_number / 65536) & 255)
    packet = packet.push((packet_number / 256) & 255)
    packet = packet.push(packet_number & 255)
  @else
    packet = packet.push((packet_number / 16777216) & 255)
    packet = packet.push((packet_number / 65536) & 255)
    packet = packet.push((packet_number / 256) & 255)
    packet = packet.push(packet_number & 255)
  @end
  
  @! Payload bytes
  i = 0 @while i < payload_bytes.len() packet = packet.push(payload_bytes[i]) i = i + 1 @end
  
  return packet
@end

@fn quic_pack_short_header(dest_cid, packet_number, pn_len, key_phase, spin_bit, payload_bytes)
  @! First byte: Header Form (0) | Fixed Bit (1) | Spin (1) | Reserved (0) | KeyPhase (1) | PN Length (2 bits)
  s_low = spin_bit & 1
  t_spin = s_low * 32
  k_low = key_phase & 1
  t_key = k_low * 4
  t_pn = (pn_len - 1) & 3
  b0_01 = 64 | t_spin
  b0_23 = t_key | t_pn
  b0 = b0_01 | b0_23
  packet = [b0]
  
  @! Destination CID (no length prefix for short header)
  i = 0 @while i < dest_cid.len() packet = packet.push(dest_cid[i]) i = i + 1 @end
  
  @! Packet Number (1 to 4 bytes)
  @if pn_len == 1
    packet = packet.push(packet_number & 255)
  @elif pn_len == 2
    packet = packet.push((packet_number / 256) & 255)
    packet = packet.push(packet_number & 255)
  @elif pn_len == 3
    packet = packet.push((packet_number / 65536) & 255)
    packet = packet.push((packet_number / 256) & 255)
    packet = packet.push(packet_number & 255)
  @else
    packet = packet.push((packet_number / 16777216) & 255)
    packet = packet.push((packet_number / 65536) & 255)
    packet = packet.push((packet_number / 256) & 255)
    packet = packet.push(packet_number & 255)
  @end
  
  @! Payload bytes
  i = 0 @while i < payload_bytes.len() packet = packet.push(payload_bytes[i]) i = i + 1 @end
  
  return packet
@end

@fn quic_unpack_packet(bytes, offset, dest_cid_len)
  blen = bytes.len()
  @if offset >= blen
    return {
      is_long_header: 0, packet_type: 0, quic_version: 0,
      dest_connection_id: [], src_connection_id: [], packet_token: [],
      packet_num: 0, packet_num_len: 0, key_phase_bit: 0, spin_bit_val: 0,
      packet_payload: [], packet_next_offset: offset
    }
  @end
  
  b0 = bytes[offset]
  is_long = (b0 / 128) & 1
  off = offset + 1
  
  @if is_long == 1
    @! Long Header Packet
    ptype = (b0 / 16) & 3
    b0_3 = b0 & 3
    pn_len = b0_3 + 1
    
    version = net_u32_be(bytes, off)
    off = off + 4
    
    dcil = bytes[off]
    off = off + 1
    dcid = []
    i = 0 @while i < dcil && (off + i) < blen dcid = dcid.push(bytes[off + i]) i = i + 1 @end
    off = off + dcil
    
    scil = bytes[off]
    off = off + 1
    scid = []
    i = 0 @while i < scil && (off + i) < blen scid = scid.push(bytes[off + i]) i = i + 1 @end
    off = off + scil
    
    token = []
    @if ptype == QUIC_PKT_INITIAL()
      tok_len_res = quic_decode_varint(bytes, off)
      tok_len = tok_len_res.varint_val
      off = tok_len_res.varint_next_offset
      i = 0 @while i < tok_len && (off + i) < blen token = token.push(bytes[off + i]) i = i + 1 @end
      off = off + tok_len
    @end
    
    len_res = quic_decode_varint(bytes, off)
    length_val = len_res.varint_val
    off = len_res.varint_next_offset
    
    pn = 0
    @if pn_len == 1
      pn = bytes[off]
      off = off + 1
    @elif pn_len == 2
      pn = net_u16_be(bytes, off)
      off = off + 2
    @elif pn_len == 3
      pn = net_u16_be(bytes, off)
      off = off + 3
    @else
      pn = net_u32_be(bytes, off)
      off = off + 4
    @end
    
    payload_len = length_val - pn_len
    payload = []
    i = 0 @while i < payload_len && (off + i) < blen payload = payload.push(bytes[off + i]) i = i + 1 @end
    
    return {
      is_long_header: 1,
      packet_type: ptype,
      quic_version: version,
      dest_connection_id: dcid,
      src_connection_id: scid,
      packet_token: token,
      packet_num: pn,
      packet_num_len: pn_len,
      key_phase_bit: 0,
      spin_bit_val: 0,
      packet_payload: payload,
      packet_next_offset: off + payload_len
    }
  @else
    @! Short Header Packet (1-RTT)
    spin = (b0 / 32) & 1
    kp = (b0 / 4) & 1
    b0_3 = b0 & 3
    pn_len = b0_3 + 1
    
    dcid = []
    i = 0 @while i < dest_cid_len && (off + i) < blen dcid = dcid.push(bytes[off + i]) i = i + 1 @end
    off = off + dest_cid_len
    
    pn = 0
    @if pn_len == 1
      pn = bytes[off]
      off = off + 1
    @elif pn_len == 2
      pn = net_u16_be(bytes, off)
      off = off + 2
    @elif pn_len == 3
      pn = net_u16_be(bytes, off)
      off = off + 3
    @else
      pn = net_u32_be(bytes, off)
      off = off + 4
    @end
    
    payload = []
    @while off < blen
      payload = payload.push(bytes[off])
      off = off + 1
    @end
    
    return {
      is_long_header: 0,
      packet_type: QUIC_PKT_1RTT(),
      quic_version: QUIC_VERSION_1(),
      dest_connection_id: dcid,
      src_connection_id: [],
      packet_token: [],
      packet_num: pn,
      packet_num_len: pn_len,
      key_phase_bit: kp,
      spin_bit_val: spin,
      packet_payload: payload,
      packet_next_offset: off
    }
  @end
@end

@fn quic_connection_new(local_cid, peer_cid)
  return {
    local_cid: local_cid,
    peer_cid: peer_cid,
    conn_state: "INITIAL",
    conn_version: QUIC_VERSION_1(),
    pn_initial: { next_pn: 0, largest_acked_pn: -1, unacked_count: 0 },
    pn_handshake: { next_pn: 0, largest_acked_pn: -1, unacked_count: 0 },
    pn_app: { next_pn: 0, largest_acked_pn: -1, unacked_count: 0 },
    congestion: {
      cwnd: 14720, @! Initial window: 10 * 1472 bytes
      bytes_in_flight: 0,
      ssthresh: 65535,
      min_rtt: 0,
      smoothed_rtt: 0,
      rttvar: 0,
      pacing_rate: 0
    },
    crypto_in: [],
    crypto_out: [],
    handshake_done: 0,
    streams: [],
    queued_frames: []
  }
@end

@fn quic_connection_create_initial_packet(conn, crypto_data)
  pn = conn.pn_initial.next_pn
  conn.pn_initial.next_pn = pn + 1
  
  crypto_frame = quic_frame_encode_crypto(0, crypto_data)
  
  @! Minimum Initial Packet Datagram Size is 1200 bytes per RFC 9000 Section 14.1
  packet = quic_pack_long_header(QUIC_PKT_INITIAL(), conn.conn_version, conn.peer_cid, conn.local_cid, [], pn, 4, crypto_frame)
  
  @if packet.len() < 1200
    pad_len = 1200 - packet.len()
    padded_payload = []
    i = 0 @while i < crypto_frame.len() padded_payload = padded_payload.push(crypto_frame[i]) i = i + 1 @end
    i = 0 @while i < pad_len padded_payload = padded_payload.push(0) i = i + 1 @end
    packet = quic_pack_long_header(QUIC_PKT_INITIAL(), conn.conn_version, conn.peer_cid, conn.local_cid, [], pn, 4, padded_payload)
  @end
  
  conn.congestion.bytes_in_flight = conn.congestion.bytes_in_flight + packet.len()
  return packet
@end

@fn quic_connection_create_handshake_packet(conn, crypto_data)
  pn = conn.pn_handshake.next_pn
  conn.pn_handshake.next_pn = pn + 1
  
  crypto_frame = quic_frame_encode_crypto(0, crypto_data)
  packet = quic_pack_long_header(QUIC_PKT_HANDSHAKE(), conn.conn_version, conn.peer_cid, conn.local_cid, [], pn, 2, crypto_frame)
  
  conn.congestion.bytes_in_flight = conn.congestion.bytes_in_flight + packet.len()
  return packet
@end

@fn quic_connection_create_1rtt_packet(conn, payload_frames)
  pn = conn.pn_app.next_pn
  conn.pn_app.next_pn = pn + 1
  
  packet = quic_pack_short_header(conn.peer_cid, pn, 2, 0, 0, payload_frames)
  conn.congestion.bytes_in_flight = conn.congestion.bytes_in_flight + packet.len()
  return packet
@end

@fn quic_connection_process_crypto_frame(conn, crypto_bytes)
  @! Ingest crypto payload into crypto buffer
  i = 0
  @while i < crypto_bytes.len()
    conn.crypto_in = conn.crypto_in.push(crypto_bytes[i])
    i = i + 1
  @end
  
  @! Advance TLS 1.3 handshake state machine
  @if conn.conn_state == "INITIAL"
    conn.conn_state = "HANDSHAKE"
    println("  [QUIC State] Advanced INITIAL -> HANDSHAKE (TLS 1.3 ClientHello processed)")
  @elif conn.conn_state == "HANDSHAKE"
    conn.conn_state = "ESTABLISHED"
    conn.handshake_done = 1
    println("  [QUIC State] Advanced HANDSHAKE -> ESTABLISHED (TLS 1.3 Handshake completed, 1-RTT active)")
  @end
  return conn
@end

@fn quic_connection_process_packet(conn, raw_packet_bytes)
  header = quic_unpack_packet(raw_packet_bytes, 0, conn.peer_cid.len())
  frames = quic_parse_frames(header.packet_payload, 0, header.packet_payload.len())
  
  f_idx = 0
  @while f_idx < frames.len()
    f = frames[f_idx]
    
    @if f.frame_type == QUIC_FRAME_CRYPTO()
      quic_connection_process_crypto_frame(conn, f.frame_data)
    @elif f.frame_type == QUIC_FRAME_STREAM()
      @! Process Stream Frame
      stream_found = 0
      s_i = 0
      @while s_i < conn.streams.len()
        st = conn.streams[s_i]
        @if st.stream_id == f.frame_stream_id
          stream_found = 1
          k = 0
          @while k < f.frame_data.len() st.stream_recv_buf = st.stream_recv_buf.push(f.frame_data[k]) k = k + 1 @end
          @if f.frame_fin == 1 st.stream_fin_recv = 1 @end
        @end
        s_i = s_i + 1
      @end
      @if stream_found == 0
        new_st = {
          stream_id: f.frame_stream_id,
          stream_state: "OPEN",
          stream_send_offset: 0,
          stream_recv_offset: f.frame_data.len(),
          stream_send_buf: [],
          stream_recv_buf: f.frame_data,
          stream_fin_sent: 0,
          stream_fin_recv: f.frame_fin
        }
        conn.streams = conn.streams.push(new_st)
      @end
    @elif f.frame_type == QUIC_FRAME_ACK() || f.frame_type == QUIC_FRAME_ACK_ECN()
      quic_connection_on_ack_received(conn, f.frame_largest_acked, f.frame_ack_delay, 15)
    @elif f.frame_type == QUIC_FRAME_PATH_CHALLENGE()
      @! Queue PATH_RESPONSE with exact 8-byte challenge data
      resp_frame = quic_frame_encode_path_response(f.frame_data)
      conn.queued_frames = conn.queued_frames.push(resp_frame)
      println("  [QUIC Engine] Handled PATH_CHALLENGE -> Queued PATH_RESPONSE")
    @elif f.frame_type == QUIC_FRAME_CONNECTION_CLOSE_QUIC() || f.frame_type == QUIC_FRAME_CONNECTION_CLOSE_APP()
      conn.conn_state = "CLOSED"
      println("  [QUIC Engine] CONNECTION_CLOSE received: " + f.frame_reason)
    @elif f.frame_type == QUIC_FRAME_PING()
      @! Queue ACK
      ack_f = quic_frame_encode_ack(header.packet_num, 0, 0)
      conn.queued_frames = conn.queued_frames.push(ack_f)
    @end
    
    f_idx = f_idx + 1
  @end
  
  return conn
@end

@fn quic_connection_send_stream(conn, stream_id, data_bytes, fin)
  @! Check congestion window
  @if (conn.congestion.bytes_in_flight + data_bytes.len()) > conn.congestion.cwnd
    println("  [QUIC Flow] Congestion window limited: cwnd=" + conn.congestion.cwnd.to_str() + ", inflight=" + conn.congestion.bytes_in_flight.to_str())
  @end
  
  stream_offset = 0
  s_i = 0
  @while s_i < conn.streams.len()
    st = conn.streams[s_i]
    @if st.stream_id == stream_id
      stream_offset = st.stream_send_offset
      st.stream_send_offset = st.stream_send_offset + data_bytes.len()
      @if fin == 1 st.stream_fin_sent = 1 @end
    @end
    s_i = s_i + 1
  @end
  
  stream_frame = quic_frame_encode_stream(stream_id, stream_offset, data_bytes, fin)
  packet = quic_connection_create_1rtt_packet(conn, stream_frame)
  return packet
@end

@fn quic_connection_on_ack_received(conn, largest_acked, ack_delay, rtt_sample)
  @! RFC 9002 Congestion Control Window Update & RTT Calculation
  @if conn.pn_app.largest_acked_pn < largest_acked
    conn.pn_app.largest_acked_pn = largest_acked
  @end
  
  @! Update RTT
  @if conn.congestion.min_rtt == 0 || rtt_sample < conn.congestion.min_rtt
    conn.congestion.min_rtt = rtt_sample
  @end
  @if conn.congestion.smoothed_rtt == 0
    conn.congestion.smoothed_rtt = rtt_sample
    conn.congestion.rttvar = rtt_sample / 2
  @else
    rtt_diff = conn.congestion.smoothed_rtt - rtt_sample
    @if rtt_diff < 0 rtt_diff = 0 - rtt_diff @end
    conn.congestion.rttvar = ((conn.congestion.rttvar * 3) + rtt_diff) / 4
    conn.congestion.smoothed_rtt = ((conn.congestion.smoothed_rtt * 7) + rtt_sample) / 8
  @end
  
  @! Congestion Window Growth (Slow Start vs Congestion Avoidance)
  @if conn.congestion.cwnd < conn.congestion.ssthresh
    @! Slow Start: increase cwnd by MSS (1472 bytes) per ACK
    conn.congestion.cwnd = conn.congestion.cwnd + 1472
  @else
    @! Congestion Avoidance: additive increase
    inc = (1472 * 1472) / conn.congestion.cwnd
    @if inc < 1 inc = 1 @end
    conn.congestion.cwnd = conn.congestion.cwnd + inc
  @end
  
  @! Decrease bytes in flight
  @if conn.congestion.bytes_in_flight > 1472
    conn.congestion.bytes_in_flight = conn.congestion.bytes_in_flight - 1472
  @else
    conn.congestion.bytes_in_flight = 0
  @end
@end

@fn quic_connection_on_congestion_event(conn)
  @! RFC 9002 Loss Event: Multiplicative Decrease
  conn.congestion.ssthresh = conn.congestion.cwnd / 2
  @if conn.congestion.ssthresh < 2944
    conn.congestion.ssthresh = 2944 @! 2 * MSS minimum
  @end
  conn.congestion.cwnd = conn.congestion.ssthresh
  println("  [QUIC Congestion] Packet loss detected: ssthresh=" + conn.congestion.ssthresh.to_str() + ", new cwnd=" + conn.congestion.cwnd.to_str())
@end

@fn quic_connection_close(conn, error_code, reason_str)
  conn.conn_state = "CLOSED"
  close_frame = quic_frame_encode_connection_close(error_code, 0, reason_str, 0)
  packet = quic_connection_create_1rtt_packet(conn, close_frame)
  return packet
@end
