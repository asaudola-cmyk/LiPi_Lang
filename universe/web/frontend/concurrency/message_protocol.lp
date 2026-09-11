@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/concurrency/message_protocol.maya
@! Milestone: M3 — Lock-Free WASM Concurrency Engine
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Binary Opcode Protocol, 64-Byte SQE / 16-Byte CQE Framing,
@! High-Level UI / Network / Input / Layout Message Structs & Serialization
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. BINARY OPCODES DEFINITION (SQE COMMANDS)
@! ============================================================================

@fn OP_NOP() return 0 @end
@fn OP_DRAW_RECT() return 1 @end
@fn OP_DRAW_TEXT() return 2 @end
@fn OP_DRAW_IMAGE() return 3 @end
@fn OP_COMPUTE_LAYOUT() return 4 @end
@fn OP_WEBRTC_FRAME() return 5 @end
@fn OP_INPUT_EVENT() return 6 @end
@fn OP_PUSH_CLIP() return 7 @end
@fn OP_POP_CLIP() return 8 @end
@fn OP_PRESENT() return 9 @end
@fn OP_LAYOUT_RESULT() return 10 @end
@fn OP_NETWORK_FETCH() return 11 @end
@fn OP_SYNC_TICK() return 12 @end
@fn OP_SET_TRANSFORM() return 13 @end
@fn OP_CLEAR_CANVAS() return 14 @end

@! ============================================================================
@! 2. SQE & CQE FLAGS DEFINITION
@! ============================================================================

@fn SQE_FLAG_NONE() return 0 @end
@fn SQE_FLAG_DRAIN() return 1 @end
@fn SQE_FLAG_ASYNC() return 2 @end
@fn SQE_FLAG_LINK() return 4 @end
@fn SQE_FLAG_HARDLINK() return 8 @end

@fn CQE_FLAG_NONE() return 0 @end
@fn CQE_FLAG_MORE() return 1 @end
@fn CQE_FLAG_ERROR() return 2 @end

@! Input Event Type Constants
@fn INPUT_EVENT_POINTER_DOWN() return 1 @end
@fn INPUT_EVENT_POINTER_UP() return 2 @end
@fn INPUT_EVENT_POINTER_MOVE() return 3 @end
@fn INPUT_EVENT_KEY_DOWN() return 4 @end
@fn INPUT_EVENT_KEY_UP() return 5 @end
@fn INPUT_EVENT_WHEEL() return 6 @end
@fn INPUT_EVENT_RESIZE() return 7 @end

@! ============================================================================
@! 3. CORE 64-BYTE SQE AND 16-BYTE CQE STRUCTURES
@! ============================================================================

@! 64-byte Submission Queue Entry (SQE) matching io_uring binary layout
@struct FrontendSQE
  opcode: i64      @! u8 opcode (1..14)
  flags: i64       @! u8 flags (DRAIN, ASYNC, LINK)
  user_data: i64   @! u64 transaction correlation tag
  arg0: i64        @! u64 param 0 (e.g. x / ptr / type)
  arg1: i64        @! u64 param 1 (e.g. y / num_items / target_x)
  arg2: i64        @! u64 param 2 (e.g. width / format / target_y)
  arg3: i64        @! u64 param 3 (e.g. height / color / key)
  arg4: i64        @! u64 param 4 (e.g. border_w / radius / modifiers)
  arg5: i64        @! u64 param 5 (e.g. border_color / texture_id / ts)
  arg6: i64        @! u64 param 6 (e.g. clip_id / opt / count)
  arg7: i64         @! u64 param 7 (e.g. payload pointer / extra)
@end

@! 16-byte Completion Queue Entry (CQE)
@struct FrontendCQE
  cqe_pad: i64     @! index 0
  flags: i64       @! index 1 (matches FrontendSQE.flags)
  user_data: i64   @! index 2 (matches FrontendSQE.user_data)
  res: i64          @! index 3 (s32 result code)
@end

@! ============================================================================
@! 4. HIGH-LEVEL TYPED MESSAGE STRUCTURES
@! ============================================================================

@struct DrawRectMessage
  x: i64
  y: i64
  width: i64
  height: i64
  bg_color: i64
  border_color: i64
  border_width: i64
  border_radius: i64
@end

@struct DrawTextMessage
  x: i64
  y: i64
  text_id: i64
  font_size: i64
  color: i64
  length: i64
  align: i64
@end

@struct DrawImageMessage
  sx: i64
  sy: i64
  sw: i64
  sh: i64
  dx: i64
  dy: i64
  dw: i64
  dh: i64
  texture_id: i64
  opacity_pct: i64
@end

@struct ComputeLayoutMessage
  node_count: i64
  viewport_w: i64
  viewport_h: i64
  buffer_ptr: i64
  root_id: i64
  flags: i64
@end

@struct WebRtcFrameMessage
  frame_id: i64
  timestamp: i64
  width: i64
  height: i64
  pixel_ptr: i64
  format: i64
  dst_x: i64
  dst_y: i64
@end

@struct InputEventMessage
  event_type: i64
  target_x: i64
  target_y: i64
  key_code: i64
  modifiers: i64
  timestamp: i64
  pointer_id: i64
  button: i64
@end

@struct PushClipMessage
  x: i64
  y: i64
  width: i64
  height: i64
  clip_id: i64
@end

@struct PopClipMessage
  clip_id: i64
@end

@struct PresentMessage
  frame_seq: i64
  buffer_index: i64
  timestamp: i64
@end

@struct LayoutResultMessage
  root_id: i64
  computed_nodes_count: i64
  total_width: i64
  total_height: i64
  is_overflow: i64
@end

@! ============================================================================
@! 5. SQE CREATION HELPERS
@! ============================================================================

@fn sqe_new_empty()
  return {
    opcode: OP_NOP(),
    flags: 0,
    user_data: 0,
    arg0: 0, arg1: 0, arg2: 0, arg3: 0,
    arg4: 0, arg5: 0, arg6: 0, arg7: 0
  }
@end

@fn sqe_new(opcode, flags, user_data, a0, a1, a2, a3, a4, a5, a6, a7)
  return {
    opcode: opcode,
    flags: flags,
    user_data: user_data,
    arg0: a0, arg1: a1, arg2: a2, arg3: a3,
    arg4: a4, arg5: a5, arg6: a6, arg7: a7
  }
@end

@fn cqe_new(user_data, res, flags)
  return {
    cqe_pad: 0,
    flags: flags,
    user_data: user_data,
    res: res
  }
@end

@! ============================================================================
@! 6. MESSAGE SERIALIZATION TO SQE
@! ============================================================================

@fn msg_draw_rect_to_sqe(msg, tag)
  return {
    opcode: OP_DRAW_RECT(),
    flags: 0,
    user_data: tag,
    arg0: msg.x,
    arg1: msg.y,
    arg2: msg.width,
    arg3: msg.height,
    arg4: msg.bg_color,
    arg5: msg.border_color,
    arg6: msg.border_width,
    arg7: msg.border_radius
  }
@end

@fn sqe_to_msg_draw_rect(sqe)
  return {
    x: sqe.arg0,
    y: sqe.arg1,
    width: sqe.arg2,
    height: sqe.arg3,
    bg_color: sqe.arg4,
    border_color: sqe.arg5,
    border_width: sqe.arg6,
    border_radius: sqe.arg7
  }
@end

@fn msg_draw_text_to_sqe(msg, tag)
  return {
    opcode: OP_DRAW_TEXT(),
    flags: 0,
    user_data: tag,
    arg0: msg.x,
    arg1: msg.y,
    arg2: msg.text_id,
    arg3: msg.font_size,
    arg4: msg.color,
    arg5: msg.length,
    arg6: msg.align,
    arg7: 0
  }
@end

@fn sqe_to_msg_draw_text(sqe)
  return {
    x: sqe.arg0,
    y: sqe.arg1,
    text_id: sqe.arg2,
    font_size: sqe.arg3,
    color: sqe.arg4,
    length: sqe.arg5,
    align: sqe.arg6
  }
@end

@fn msg_draw_image_to_sqe(msg, tag)
  return {
    opcode: OP_DRAW_IMAGE(),
    flags: 0,
    user_data: tag,
    arg0: msg.dx,
    arg1: msg.dy,
    arg2: msg.dw,
    arg3: msg.dh,
    arg4: msg.texture_id,
    arg5: msg.opacity_pct,
    arg6: msg.sx,
    arg7: msg.sy
  }
@end

@fn sqe_to_msg_draw_image(sqe)
  return {
    sx: sqe.arg6,
    sy: sqe.arg7,
    sw: sqe.arg2,
    sh: sqe.arg3,
    dx: sqe.arg0,
    dy: sqe.arg1,
    dw: sqe.arg2,
    dh: sqe.arg3,
    texture_id: sqe.arg4,
    opacity_pct: sqe.arg5
  }
@end

@fn msg_compute_layout_to_sqe(msg, tag)
  return {
    opcode: OP_COMPUTE_LAYOUT(),
    flags: 0,
    user_data: tag,
    arg0: msg.node_count,
    arg1: msg.viewport_w,
    arg2: msg.viewport_h,
    arg3: msg.buffer_ptr,
    arg4: msg.root_id,
    arg5: msg.flags,
    arg6: 0,
    arg7: 0
  }
@end

@fn sqe_to_msg_compute_layout(sqe)
  return {
    node_count: sqe.arg0,
    viewport_w: sqe.arg1,
    viewport_h: sqe.arg2,
    buffer_ptr: sqe.arg3,
    root_id: sqe.arg4,
    flags: sqe.arg5
  }
@end

@fn msg_webrtc_frame_to_sqe(msg, tag)
  return {
    opcode: OP_WEBRTC_FRAME(),
    flags: 0,
    user_data: tag,
    arg0: msg.frame_id,
    arg1: msg.timestamp,
    arg2: msg.width,
    arg3: msg.height,
    arg4: msg.pixel_ptr,
    arg5: msg.format,
    arg6: msg.dst_x,
    arg7: msg.dst_y
  }
@end

@fn sqe_to_msg_webrtc_frame(sqe)
  return {
    frame_id: sqe.arg0,
    timestamp: sqe.arg1,
    width: sqe.arg2,
    height: sqe.arg3,
    pixel_ptr: sqe.arg4,
    format: sqe.arg5,
    dst_x: sqe.arg6,
    dst_y: sqe.arg7
  }
@end

@fn msg_input_event_to_sqe(msg, tag)
  return {
    opcode: OP_INPUT_EVENT(),
    flags: 0,
    user_data: tag,
    arg0: msg.event_type,
    arg1: msg.target_x,
    arg2: msg.target_y,
    arg3: msg.key_code,
    arg4: msg.modifiers,
    arg5: msg.timestamp,
    arg6: msg.pointer_id,
    arg7: msg.button
  }
@end

@fn sqe_to_msg_input_event(sqe)
  return {
    event_type: sqe.arg0,
    target_x: sqe.arg1,
    target_y: sqe.arg2,
    key_code: sqe.arg3,
    modifiers: sqe.arg4,
    timestamp: sqe.arg5,
    pointer_id: sqe.arg6,
    button: sqe.arg7
  }
@end

@fn msg_push_clip_to_sqe(msg, tag)
  return {
    opcode: OP_PUSH_CLIP(),
    flags: 0,
    user_data: tag,
    arg0: msg.x,
    arg1: msg.y,
    arg2: msg.width,
    arg3: msg.height,
    arg4: msg.clip_id,
    arg5: 0,
    arg6: 0,
    arg7: 0
  }
@end

@fn sqe_to_msg_push_clip(sqe)
  return {
    x: sqe.arg0,
    y: sqe.arg1,
    width: sqe.arg2,
    height: sqe.arg3,
    clip_id: sqe.arg4
  }
@end

@fn msg_pop_clip_to_sqe(msg, tag)
  return {
    opcode: OP_POP_CLIP(),
    flags: 0,
    user_data: tag,
    arg0: msg.clip_id,
    arg1: 0,
    arg2: 0,
    arg3: 0,
    arg4: 0,
    arg5: 0,
    arg6: 0,
    arg7: 0
  }
@end

@fn sqe_to_msg_pop_clip(sqe)
  return {
    clip_id: sqe.arg0
  }
@end

@fn msg_present_to_sqe(msg, tag)
  return {
    opcode: OP_PRESENT(),
    flags: 0,
    user_data: tag,
    arg0: msg.frame_seq,
    arg1: msg.buffer_index,
    arg2: msg.timestamp,
    arg3: 0,
    arg4: 0,
    arg5: 0,
    arg6: 0,
    arg7: 0
  }
@end

@fn sqe_to_msg_present(sqe)
  return {
    frame_seq: sqe.arg0,
    buffer_index: sqe.arg1,
    timestamp: sqe.arg2
  }
@end

@! ============================================================================
@! 7. 64-BYTE SQE & 16-BYTE CQE BINARY SERIALIZATION (BYTE ARRAYS)
@! ============================================================================

@fn u64_to_bytes_le(val)
  b = []
  v = val
  i = 0
  @while i < 8
    b_byte = v & 255
    b = b.push(b_byte)
    v = v / 256
    i = i + 1
  @end
  return b
@end

@fn bytes_le_to_u64(bytes, offset)
  res = 0
  i = 7
  @while i >= 0
    idx = offset + i
    b_val = bytes[idx] & 255
    res = (res * 256) | b_val
    i = i - 1
  @end
  return res
@end

@fn sqe_serialize_binary(sqe)
  bytes = []
  
  @! Word 0: opcode (u8) | flags (u8) * 256 | (0)
  op = sqe.opcode & 255
  fl_b = sqe.flags & 255
  fl = fl_b * 256
  w0 = op | fl
  b0 = u64_to_bytes_le(w0)
  
  b_tag = u64_to_bytes_le(sqe.user_data)
  ba0 = u64_to_bytes_le(sqe.arg0)
  ba1 = u64_to_bytes_le(sqe.arg1)
  ba2 = u64_to_bytes_le(sqe.arg2)
  ba3 = u64_to_bytes_le(sqe.arg3)
  ba4 = u64_to_bytes_le(sqe.arg4)
  ba5 = u64_to_bytes_le(sqe.arg5)

  i = 0
  @while i < 8 bytes = bytes.push(b0[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(b_tag[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(ba0[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(ba1[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(ba2[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(ba3[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(ba4[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(ba5[i]) i = i + 1 @end

  return bytes @! Exactly 64 bytes
@end

@fn sqe_deserialize_binary(bytes, offset)
  w0 = bytes_le_to_u64(bytes, offset + 0)
  opcode = w0 & 255
  flags = (w0 / 256) & 255
  
  user_data = bytes_le_to_u64(bytes, offset + 8)
  a0 = bytes_le_to_u64(bytes, offset + 16)
  a1 = bytes_le_to_u64(bytes, offset + 24)
  a2 = bytes_le_to_u64(bytes, offset + 32)
  a3 = bytes_le_to_u64(bytes, offset + 40)
  a4 = bytes_le_to_u64(bytes, offset + 48)
  a5 = bytes_le_to_u64(bytes, offset + 56)

  return {
    opcode: opcode,
    flags: flags,
    user_data: user_data,
    arg0: a0, arg1: a1, arg2: a2, arg3: a3,
    arg4: a4, arg5: a5, arg6: 0, arg7: 0
  }
@end

@fn cqe_serialize_binary(cqe)
  bytes = []
  b_tag = u64_to_bytes_le(cqe.user_data)
  
  @! Word 1: res (s32 / u32) | ((flags * (82)))
  r_val = cqe.res & 4294967295
  f_b = cqe.flags & 4294967295
  f_val = f_b * 4294967296
  w1 = r_val | f_val
  b_res = u64_to_bytes_le(w1)

  i = 0
  @while i < 8 bytes = bytes.push(b_tag[i]) i = i + 1 @end
  i = 0
  @while i < 8 bytes = bytes.push(b_res[i]) i = i + 1 @end

  return bytes @! Exactly 16 bytes
@end

@fn cqe_deserialize_binary(bytes, offset)
  user_data = bytes_le_to_u64(bytes, offset + 0)
  w1 = bytes_le_to_u64(bytes, offset + 8)
  res = w1 & 4294967295
  flags = (w1 / 4294967296) & 4294967295

  return {
    cqe_pad: 0,
    flags: flags,
    user_data: user_data,
    res: res
  }
@end

@! ============================================================================
@! 8. OPCODES TO STRING HELPER
@! ============================================================================

@fn opcode_to_string(opcode)
  @if opcode == 0 return "OP_NOP" @end
  @if opcode == 1 return "OP_DRAW_RECT" @end
  @if opcode == 2 return "OP_DRAW_TEXT" @end
  @if opcode == 3 return "OP_DRAW_IMAGE" @end
  @if opcode == 4 return "OP_COMPUTE_LAYOUT" @end
  @if opcode == 5 return "OP_WEBRTC_FRAME" @end
  @if opcode == 6 return "OP_INPUT_EVENT" @end
  @if opcode == 7 return "OP_PUSH_CLIP" @end
  @if opcode == 8 return "OP_POP_CLIP" @end
  @if opcode == 9 return "OP_PRESENT" @end
  @if opcode == 10 return "OP_LAYOUT_RESULT" @end
  @if opcode == 11 return "OP_NETWORK_FETCH" @end
  @if opcode == 12 return "OP_SYNC_TICK" @end
  @if opcode == 13 return "OP_SET_TRANSFORM" @end
  @if opcode == 14 return "OP_CLEAR_CANVAS" @end
  return "OP_UNKNOWN"
@end
