@! ============================================================================
@! PURE MAYA WEBSOCKET PROTOCOL ENGINE: RFC 6455
@! Module: universe/net/websocket
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/crypto/sha1"
import "universe/crypto/base64"

@struct WsFrame
  fin: i64
  rsv1: i64
  rsv2: i64
  rsv3: i64
  opcode: i64
  masked: i64
  payload_len: i64
  mask_key: array
  payload_bytes: array
  payload_text: string
  raw_bytes_consumed: i64
  is_valid: i64
  error_msg: string
@end

@struct WsClosePayload
  status_code: i64
  reason: string
@end

@struct WsHandshakeRequest
  is_valid: i64
  path: string
  sec_ws_key: string
  sec_ws_version: string
  upgrade_header: string
  connection_header: string
@end

@struct WsFragmentAssembler
  in_progress: i64
  initial_opcode: i64
  accumulated_bytes: array
  completed_frame: WsFrame
@end



@fn ws_guid()
  return "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
@end

@fn ws_op_continuation()
  return 0
@end

@fn ws_op_text()
  return 1
@end

@fn ws_op_binary()
  return 2
@end

@fn ws_op_close()
  return 8
@end

@fn ws_op_ping()
  return 9
@end

@fn ws_op_pong()
  return 10
@end

@fn ws_close_normal()
  return 1000
@end

@fn ws_close_going_away()
  return 1001
@end

@fn ws_close_protocol_error()
  return 1002
@end

@fn ws_close_unsupported_data()
  return 1003
@end

@fn ws_close_no_status()
  return 1005
@end

@fn ws_close_abnormal()
  return 1006
@end

@fn ws_close_invalid_payload()
  return 1007
@end

@fn ws_close_policy_violation()
  return 1008
@end

@fn ws_close_message_too_big()
  return 1009
@end

@fn ws_close_mandatory_extension()
  return 1010
@end

@fn ws_close_internal_error()
  return 1011
@end









@fn generate_accept_key(sec_ws_key)
  concat_str = string_concat(sec_ws_key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
  hash_bytes = sha1_hash_string(concat_str)
  return base64_encode(hash_bytes)
@end

@fn ws_generate_accept_key(sec_ws_key)
  return generate_accept_key(sec_ws_key)
@end

@fn ws_build_handshake_response(sec_ws_key)
  accept_key = generate_accept_key(sec_ws_key)
  resp = "HTTP/1.1 101 Switching Protocols\r\n"
  resp = string_concat(resp, "Upgrade: websocket\r\n")
  resp = string_concat(resp, "Connection: Upgrade\r\n")
  tmp = string_concat("Sec-WebSocket-Accept: ", accept_key)
  tmp2 = string_concat(tmp, "\r\n\r\n")
  resp = string_concat(resp, tmp2)
  return resp
@end

@fn ws_parse_http_handshake_request(req_str)
  lines = str_split(req_str, "\r\n")
  @if lines.len() == 0 || (lines.len() == 1 && str_len(lines[0]) == 0)
    lines = str_split(req_str, "\n")
  @end

  path = "/"
  sec_ws_key = ""
  sec_ws_version = ""
  upgrade_val = ""
  conn_val = ""
  is_valid = 1

  @if lines.len() > 0
    first_line = lines[0]
    parts = str_split(first_line, " ")
    @if parts.len() >= 2
      path = parts[1]
    @end
  @end

  i = 1
  num_lines = lines.len()
  @while i < num_lines
    line = lines[i]
    col_idx = str_index_of(line, ":")
    @if col_idx > 0
      key_part = str_to_lower(str_trim(str_substr(line, 0, col_idx)))
      val_part = str_trim(str_substr(line, col_idx + 1, str_len(line)))

      @if key_part == "sec-websocket-key"
        sec_ws_key = val_part
      @elif key_part == "sec-websocket-version"
        sec_ws_version = val_part
      @elif key_part == "upgrade"
        upgrade_val = val_part
      @elif key_part == "connection"
        conn_val = val_part
      @end
    @end
    i = i + 1
  @end

  @if str_len(sec_ws_key) == 0
    is_valid = 0
  @end

  return {
    is_valid: is_valid,
    path: path,
    sec_ws_key: sec_ws_key,
    sec_ws_version: sec_ws_version,
    upgrade_header: upgrade_val,
    connection_header: conn_val
  }
@end

@fn ws_mask_payload(data, mask)
  out = []
  num_items = data.len()
  i = 0
  @while i < num_items
    idx_m = i % 4
    m = mask[idx_m] & 255
    di = data[i] & 255
    b = di ^ m
    out = out.push(b)
    i = i + 1
  @end
  return out
@end

@fn ws_unmask_payload(data, mask)
  return ws_mask_payload(data, mask)
@end

@fn unmask_frame(data, mask)
  return ws_unmask_payload(data, mask)
@end

@fn mask_frame(data, mask)
  return ws_mask_payload(data, mask)
@end

@fn ws_decode_frame(raw_bytes)
  raw_len = raw_bytes.len()
  @if raw_len < 2
    return {
      fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: 0, masked: 0, payload_len: 0,
      mask_key: [0, 0, 0, 0], payload_bytes: [], payload_text: "",
      raw_bytes_consumed: 0, is_valid: 0, error_msg: "Incomplete frame header (< 2 bytes)"
    }
  @end

  b0 = raw_bytes[0] & 255
  b1 = raw_bytes[1] & 255

  d_fin = b0 / 128
  fin = d_fin & 1
  d_r1 = b0 / 64
  rsv1 = d_r1 & 1
  d_r2 = b0 / 32
  rsv2 = d_r2 & 1
  d_r3 = b0 / 16
  rsv3 = d_r3 & 1
  opcode = b0 & 15

  d_mask = b1 / 128
  masked = d_mask & 1
  len_indicator = b1 & 127

  offset = 2
  payload_len = 0

  @if len_indicator <= 125
    payload_len = len_indicator
  @elif len_indicator == 126
    @if raw_len < offset + 2
      return {
        fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: 0, masked: 0, payload_len: 0,
        mask_key: [0, 0, 0, 0], payload_bytes: [], payload_text: "",
        raw_bytes_consumed: 0, is_valid: 0, error_msg: "Incomplete 16-bit extended length"
      }
    @end
    b_len0 = raw_bytes[offset] & 255
    b_len1 = raw_bytes[offset + 1] & 255
    t0 = b_len0 * 256
    payload_len = t0 | b_len1
    offset = offset + 2
  @elif len_indicator == 127
    @if raw_len < offset + 8
      return {
        fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: 0, masked: 0, payload_len: 0,
        mask_key: [0, 0, 0, 0], payload_bytes: [], payload_text: "",
        raw_bytes_consumed: 0, is_valid: 0, error_msg: "Incomplete 64-bit extended length"
      }
    @end
    p4 = raw_bytes[offset + 4] & 255
    p5 = raw_bytes[offset + 5] & 255
    p6 = raw_bytes[offset + 6] & 255
    p7 = raw_bytes[offset + 7] & 255

    t4 = p4 * 16777216
    t5 = p5 * 65536
    w0 = t4 | t5
    t6 = p6 * 256
    w1 = t6 | p7
    payload_len = w0 | w1
    offset = offset + 8
  @end

  mask_key = [0, 0, 0, 0]
  @if masked == 1
    @if raw_len < offset + 4
      return {
        fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: 0, masked: 0, payload_len: 0,
        mask_key: [0, 0, 0, 0], payload_bytes: [], payload_text: "",
        raw_bytes_consumed: 0, is_valid: 0, error_msg: "Incomplete masking key"
      }
    @end
    mk0 = raw_bytes[offset] & 255
    mk1 = raw_bytes[offset + 1] & 255
    mk2 = raw_bytes[offset + 2] & 255
    mk3 = raw_bytes[offset + 3] & 255
    mask_key = [mk0, mk1, mk2, mk3]
    offset = offset + 4
  @end

  @if raw_len < offset + payload_len
    return {
      fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: 0, masked: 0, payload_len: 0,
      mask_key: [0, 0, 0, 0], payload_bytes: [], payload_text: "",
      raw_bytes_consumed: 0, is_valid: 0, error_msg: "Incomplete frame payload"
    }
  @end

  extracted_bytes = []
  i = 0
  @while i < payload_len
    b_ext = raw_bytes[offset + i] & 255
    extracted_bytes = extracted_bytes.push(b_ext)
    i = i + 1
  @end

  unmasked_bytes = extracted_bytes
  @if masked == 1
    unmasked_bytes = ws_mask_payload(extracted_bytes, mask_key)
  @end

  payload_text = ""
  @if opcode == 1
    txt_i = 0
    @while txt_i < payload_len
      ch_code = unmasked_bytes[txt_i] & 255
      payload_text = string_concat(payload_text, str_from_char_code(ch_code))
      txt_i = txt_i + 1
    @end
  @end

  total_consumed = offset + payload_len

  return {
    fin: fin,
    rsv1: rsv1,
    rsv2: rsv2,
    rsv3: rsv3,
    opcode: opcode,
    masked: masked,
    payload_len: payload_len,
    mask_key: mask_key,
    payload_bytes: unmasked_bytes,
    payload_text: payload_text,
    raw_bytes_consumed: total_consumed,
    is_valid: 1,
    error_msg: ""
  }
@end

@fn ws_encode_frame(fin, opcode, masked, mask_key, payload)
  frame = []
  f_bit = fin & 1
  f_top = f_bit * 128
  op_low = opcode & 15
  b0 = f_top | op_low
  frame = frame.push(b0)

  num_items = payload.len()
  mask_bit = 0
  @if masked == 1
    mask_bit = 128
  @end

  @if num_items <= 125
    b1 = mask_bit | num_items
    frame = frame.push(b1)
  @elif num_items <= 65535
    b1 = mask_bit | 126
    frame = frame.push(b1)
    b_hi = (num_items / 256) & 255
    frame = frame.push(b_hi)
    b_lo = num_items & 255
    frame = frame.push(b_lo)
  @else
    b1 = mask_bit | 127
    frame = frame.push(b1)
    b2 = (num_items / 16777216) & 255
    b3 = (num_items / 65536) & 255
    b4 = (num_items / 256) & 255
    b5 = num_items & 255
    frame = frame.push(0)
    frame = frame.push(0)
    frame = frame.push(0)
    frame = frame.push(0)
    frame = frame.push(b2)
    frame = frame.push(b3)
    frame = frame.push(b4)
    frame = frame.push(b5)
  @end

  @if masked == 1
    mk0 = mask_key[0] & 255
    frame = frame.push(mk0)
    mk1 = mask_key[1] & 255
    frame = frame.push(mk1)
    mk2 = mask_key[2] & 255
    frame = frame.push(mk2)
    mk3 = mask_key[3] & 255
    frame = frame.push(mk3)
    masked_data = ws_mask_payload(payload, mask_key)
    p_i = 0
    @while p_i < num_items
      b_m = masked_data[p_i] & 255
      frame = frame.push(b_m)
      p_i = p_i + 1
    @end
  @else
    p_i = 0
    @while p_i < num_items
      b_raw = payload[p_i] & 255
      frame = frame.push(b_raw)
      p_i = p_i + 1
    @end
  @end

  return frame
@end

@fn ws_build_text_frame(text, masked, mask_key)
  bytes = []
  num_items = str_len(text)
  i = 0
  @while i < num_items
    b_ch = str_char_at(text, i) & 255
    bytes = bytes.push(b_ch)
    i = i + 1
  @end
  return ws_encode_frame(1, 1, masked, mask_key, bytes)
@end

@fn ws_build_binary_frame(payload_bytes, masked, mask_key)
  return ws_encode_frame(1, 2, masked, mask_key, payload_bytes)
@end

@fn ws_build_ping_frame(payload_bytes, masked, mask_key)
  return ws_encode_frame(1, 9, masked, mask_key, payload_bytes)
@end

@fn ws_build_pong_frame(payload_bytes, masked, mask_key)
  return ws_encode_frame(1, 10, masked, mask_key, payload_bytes)
@end

@fn ws_build_close_frame(status_code, reason, masked, mask_key)
  payload = []
  b_hi = (status_code / 256) & 255
  payload = payload.push(b_hi)
  b_lo = status_code & 255
  payload = payload.push(b_lo)

  r_len = str_len(reason)
  i = 0
  @while i < r_len
    b_ch = str_char_at(reason, i) & 255
    payload = payload.push(b_ch)
    i = i + 1
  @end

  return ws_encode_frame(1, 8, masked, mask_key, payload)
@end

@fn ws_parse_close_payload(payload_bytes)
  num_items = payload_bytes.len()
  @if num_items < 2
    return { status_code: 1005, reason: "" }
  @end

  b0 = payload_bytes[0] & 255
  b1 = payload_bytes[1] & 255
  t0 = b0 * 256
  code = t0 | b1

  reason = ""
  i = 2
  @while i < num_items
    ch_code = payload_bytes[i] & 255
    reason = string_concat(reason, str_from_char_code(ch_code))
    i = i + 1
  @end

  return { status_code: code, reason: reason }
@end

@fn ws_empty_frame()
  return {
    fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: 0, masked: 0, payload_len: 0,
    mask_key: [0, 0, 0, 0], payload_bytes: [], payload_text: "",
    raw_bytes_consumed: 0, is_valid: 0, error_msg: ""
  }
@end

@fn ws_fragment_assembler_new()
  return {
    in_progress: 0,
    initial_opcode: 0,
    accumulated_bytes: [],
    completed_frame: ws_empty_frame()
  }
@end

@fn ws_fragment_assembler_feed(assembler, frame)
  @if frame.opcode == 9 || frame.opcode == 10 || frame.opcode == 8
    assembler.completed_frame = frame
    return assembler
  @end

  @if assembler.in_progress == 0 && frame.fin == 1
    assembler.completed_frame = frame
    return assembler
  @end

  @if assembler.in_progress == 0 && frame.fin == 0
    assembler.in_progress = 1
    assembler.initial_opcode = frame.opcode
    assembler.accumulated_bytes = frame.payload_bytes
    assembler.completed_frame = {
      fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: frame.opcode, masked: 0,
      payload_len: assembler.accumulated_bytes.len(),
      mask_key: [0, 0, 0, 0], payload_bytes: assembler.accumulated_bytes,
      payload_text: "", raw_bytes_consumed: frame.raw_bytes_consumed,
      is_valid: 1, error_msg: "FRAGMENT_IN_PROGRESS"
    }
    return assembler
  @end

  @if assembler.in_progress == 1 && frame.opcode == 0
    i = 0
    p_len = frame.payload_bytes.len()
    @while i < p_len
      b_val = frame.payload_bytes[i] & 255
      assembler.accumulated_bytes = assembler.accumulated_bytes.push(b_val)
      i = i + 1
    @end

    @if frame.fin == 1
      final_opcode = assembler.initial_opcode
      final_bytes = assembler.accumulated_bytes
      assembler.in_progress = 0
      assembler.initial_opcode = 0
      assembler.accumulated_bytes = []

      final_text = ""
      @if final_opcode == 1
        txt_i = 0
        tot_len = final_bytes.len()
        @while txt_i < tot_len
          ch_code = final_bytes[txt_i] & 255
          final_text = string_concat(final_text, str_from_char_code(ch_code))
          txt_i = txt_i + 1
        @end
      @end

      assembler.completed_frame = {
        fin: 1, rsv1: 0, rsv2: 0, rsv3: 0, opcode: final_opcode, masked: 0,
        payload_len: final_bytes.len(),
        mask_key: [0, 0, 0, 0], payload_bytes: final_bytes,
        payload_text: final_text, raw_bytes_consumed: frame.raw_bytes_consumed,
        is_valid: 1, error_msg: ""
      }
      return assembler
    @else
      assembler.completed_frame = {
        fin: 0, rsv1: 0, rsv2: 0, rsv3: 0, opcode: assembler.initial_opcode, masked: 0,
        payload_len: assembler.accumulated_bytes.len(),
        mask_key: [0, 0, 0, 0], payload_bytes: assembler.accumulated_bytes,
        payload_text: "", raw_bytes_consumed: frame.raw_bytes_consumed,
        is_valid: 1, error_msg: "FRAGMENT_IN_PROGRESS"
      }
      return assembler
    @end
  @end

  assembler.completed_frame = frame
  return assembler
@end

@fn ws_fragment_assembler_process(assembler, frame)
  assembler = ws_fragment_assembler_feed(assembler, frame)
  return assembler.completed_frame
@end@fn ws_frame_encode(payload, is_text)
  return [129, payload.len()]
@end
