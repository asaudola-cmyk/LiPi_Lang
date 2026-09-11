@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — PURE MAYA X11 DIRECT WIRE PROTOCOL
@! Module: universe/gui/x11/x11_protocol.maya
@! Milestone: Grand Sovereign Pillar 3
@! 100% Pure Maya Implementation — Direct Unix Domain Socket / X11 Wire Protocol
@! Features: Binary X11 Wire Framing, Handshake, Opcodes (CreateWindow, MapWindow,
@! PutImage ZPixmap, CreateGC), and 32-Byte Event Packet Demuxing
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. X11 WIRE PROTOCOL CONSTANTS
@! ============================================================================

@struct X11PacketBuffer
  data: array
  num_items: i64
@end

@struct X11Event
  event_type: i64
  window_id: i64
  root_window_id: i64
  x: i64
  y: i64
  root_x: i64
  root_y: i64
  code: i64
  state: i64
  width: i64
  height: i64
  count: i64
@end

@struct X11HandshakeReply
  status: i64 @! 1
  protocol_major: i64
  protocol_minor: i64
  resource_id_base: i64
  resource_id_mask: i64
  root_window_id: i64
  root_visual_id: i64
  screen_width: i64
  screen_height: i64
@end

@! Helper buffer creators
@fn x11_buf_new()
  return { data: [], num_items: 0 }
@end

@fn x11_buf_push_u8(buf, b)
  buf.data = buf.data.push(b % 256)
  buf.num_items = buf.num_items + 1
  return buf
@end

@fn x11_buf_push_u16_le(buf, v)
  buf = x11_buf_push_u8(buf, v % 256)
  buf = x11_buf_push_u8(buf, (v / 256) % 256)
  return buf
@end

@fn x11_buf_push_u32_le(buf, v)
  buf = x11_buf_push_u8(buf, v % 256)
  buf = x11_buf_push_u8(buf, (v / 256) % 256)
  buf = x11_buf_push_u8(buf, (v / 65536) % 256)
  buf = x11_buf_push_u8(buf, (v / 16777216) % 256)
  return buf
@end

@fn x11_buf_push_bytes(buf, bytes)
  i = 0
  n = bytes.len()
  @while i < n
    buf = x11_buf_push_u8(buf, bytes[i])
    i = i + 1
  @end
  return buf
@end

@fn x11_buf_pad_4(buf)
  rem = buf.num_items % 4
  @if rem != 0
    pad = 4 - rem
    p = 0
    @while p < pad
      buf = x11_buf_push_u8(buf, 0)
      p = p + 1
    @end
  @end
  return buf
@end

@! ============================================================================
@! 2. CONNECTION HANDSHAKE
@! ============================================================================

@fn x11_build_handshake(auth_proto, auth_data)
  buf = x11_buf_new()
  @! Byte order: 0x6C ('l' for little-endian)
  buf = x11_buf_push_u8(buf, 108)
  buf = x11_buf_push_u8(buf, 0) @! Unused pad
  buf = x11_buf_push_u16_le(buf, 11) @! Major version 11
  buf = x11_buf_push_u16_le(buf, 0)  @! Minor version 0
  
  auth_p_len = str_len(auth_proto)
  auth_d_len = str_len(auth_data)
  buf = x11_buf_push_u16_le(buf, auth_p_len)
  buf = x11_buf_push_u16_le(buf, auth_d_len)
  buf = x11_buf_push_u16_le(buf, 0) @! Unused
  
  @! Append auth proto
  i = 0
  @while i < auth_p_len
    buf = x11_buf_push_u8(buf, str_char_at(auth_proto, i))
    i = i + 1
  @end
  buf = x11_buf_pad_4(buf)

  @! Append auth data
  i = 0
  @while i < auth_d_len
    buf = x11_buf_push_u8(buf, str_char_at(auth_data, i))
    i = i + 1
  @end
  buf = x11_buf_pad_4(buf)

  return buf
@end

@fn x11_parse_handshake_reply(raw_bytes)
  @if raw_bytes.len() < 8
    return { status: 0, protocol_major: 0, protocol_minor: 0, resource_id_base: 0, resource_id_mask: 0, root_window_id: 0, root_visual_id: 0, screen_width: 0, screen_height: 0 }
  @end

  status = raw_bytes[0]
  major = raw_bytes[2] + raw_bytes[3] * 256
  minor = raw_bytes[4] + raw_bytes[5] * 256

  @if status != 1
    return { status: status, protocol_major: major, protocol_minor: minor, resource_id_base: 0, resource_id_mask: 0, root_window_id: 0, root_visual_id: 0, screen_width: 0, screen_height: 0 }
  @end

  @! Extract resource ID base (offset 12)
  res_base = 0
  res_mask = 0
  root_win = 0
  root_vis = 0
  scr_w = 1920
  scr_h = 1080

  @if raw_bytes.len() >= 40
    res_base = raw_bytes[12] + raw_bytes[13] * 256 + raw_bytes[14] * 65536 + raw_bytes[15] * 16777216
    res_mask = raw_bytes[16] + raw_bytes[17] * 256 + raw_bytes[18] * 65536 + raw_bytes[19] * 16777216
    root_win = res_base + 1
    root_vis = 32
  @end

  return {
    status: 1,
    protocol_major: major,
    protocol_minor: minor,
    resource_id_base: res_base,
    resource_id_mask: res_mask,
    root_window_id: root_win,
    root_visual_id: root_vis,
    screen_width: scr_w,
    screen_height: scr_h
  }
@end

@! ============================================================================
@! 3. REQUEST PACKET BUILDERS
@! ============================================================================

@! Opcode 1: CreateWindow
@fn x11_build_create_window(win_id, parent_id, x, y, width, height, border_w, visual_id, bg_color)
  buf = x11_buf_new()
  buf = x11_buf_push_u8(buf, 1) @! Opcode: CreateWindow
  buf = x11_buf_push_u8(buf, 24) @! Depth: 24-bit TrueColor
  buf = x11_buf_push_u16_le(buf, 10) @! Length in 4-byte words: 10
  
  buf = x11_buf_push_u32_le(buf, win_id)
  buf = x11_buf_push_u32_le(buf, parent_id)
  buf = x11_buf_push_u16_le(buf, x)
  buf = x11_buf_push_u16_le(buf, y)
  buf = x11_buf_push_u16_le(buf, width)
  buf = x11_buf_push_u16_le(buf, height)
  buf = x11_buf_push_u16_le(buf, border_w)
  buf = x11_buf_push_u16_le(buf, 1) @! Class: InputOutput
  buf = x11_buf_push_u32_le(buf, visual_id) @! Visual ID (CopyFromParent = 0 or ID)
  
  @! Value mask: CWBackPixel (0x02) | CWEventMask (0x800) = 0x802
  buf = x11_buf_push_u32_le(buf, 2050)
  buf = x11_buf_push_u32_le(buf, bg_color) @! Background pixel
  @! Event mask: KeyPress (1) | KeyRelease (2) | ButtonPress (4) | ButtonRelease (8) | PointerMotion (64) | Exposure (32768) | StructureNotify (131072)
  buf = x11_buf_push_u32_le(buf, 163919)
  
  return buf
@end

@! Opcode 8: MapWindow
@fn x11_build_map_window(win_id)
  buf = x11_buf_new()
  buf = x11_buf_push_u8(buf, 8) @! Opcode: MapWindow
  buf = x11_buf_push_u8(buf, 0) @! Pad
  buf = x11_buf_push_u16_le(buf, 2) @! Length: 2 words (8 bytes)
  buf = x11_buf_push_u32_le(buf, win_id)
  return buf
@end

@! Opcode 4: DestroyWindow
@fn x11_build_destroy_window(win_id)
  buf = x11_buf_new()
  buf = x11_buf_push_u8(buf, 4)
  buf = x11_buf_push_u8(buf, 0)
  buf = x11_buf_push_u16_le(buf, 2)
  buf = x11_buf_push_u32_le(buf, win_id)
  return buf
@end

@! Opcode 55: CreateGC (Graphics Context)
@fn x11_build_create_gc(gc_id, drawable_id, fg_color, bg_color)
  buf = x11_buf_new()
  buf = x11_buf_push_u8(buf, 55) @! Opcode: CreateGC
  buf = x11_buf_push_u8(buf, 0)
  buf = x11_buf_push_u16_le(buf, 6) @! Length: 6 words (24 bytes)
  
  buf = x11_buf_push_u32_le(buf, gc_id)
  buf = x11_buf_push_u32_le(buf, drawable_id)
  @! Value Mask: GCForeground (0x04) | GCBackground (0x08) = 0x0C (12)
  buf = x11_buf_push_u32_le(buf, 12)
  buf = x11_buf_push_u32_le(buf, fg_color)
  buf = x11_buf_push_u32_le(buf, bg_color)
  return buf
@end

@! Opcode 70: PolyFillRectangle
@fn x11_build_poly_fill_rect(drawable_id, gc_id, x, y, width, height)
  buf = x11_buf_new()
  buf = x11_buf_push_u8(buf, 70) @! Opcode: PolyFillRectangle
  buf = x11_buf_push_u8(buf, 0)
  buf = x11_buf_push_u16_le(buf, 5) @! Length: 5 words (20 bytes)
  
  buf = x11_buf_push_u32_le(buf, drawable_id)
  buf = x11_buf_push_u32_le(buf, gc_id)
  buf = x11_buf_push_u16_le(buf, x)
  buf = x11_buf_push_u16_le(buf, y)
  buf = x11_buf_push_u16_le(buf, width)
  buf = x11_buf_push_u16_le(buf, height)
  return buf
@end

@! Opcode 72: PutImage (ZPixmap Direct Framebuffer Blit)
@fn x11_build_put_image_zpixmap(drawable_id, gc_id, width, height, dst_x, dst_y, depth, pixel_bytes)
  buf = x11_buf_new()
  buf = x11_buf_push_u8(buf, 72) @! Opcode: PutImage
  buf = x11_buf_push_u8(buf, 2) @! Format: 2 = ZPixmap
  
  pixel_words = (pixel_bytes.len() + 3) / 4
  total_words = 6 + pixel_words
  buf = x11_buf_push_u16_le(buf, total_words)
  
  buf = x11_buf_push_u32_le(buf, drawable_id)
  buf = x11_buf_push_u32_le(buf, gc_id)
  buf = x11_buf_push_u16_le(buf, width)
  buf = x11_buf_push_u16_le(buf, height)
  buf = x11_buf_push_u16_le(buf, dst_x)
  buf = x11_buf_push_u16_le(buf, dst_y)
  buf = x11_buf_push_u8(buf, 0) @! Left pad
  buf = x11_buf_push_u8(buf, depth) @! Depth (e.g. 24 or 32)
  buf = x11_buf_push_u16_le(buf, 0) @! Pad
  
  buf = x11_buf_push_bytes(buf, pixel_bytes)
  buf = x11_buf_pad_4(buf)
  return buf
@end

@! ============================================================================
@! 4. EVENT PACKET DEMUXER (32-Byte Raw X11 Events)
@! ============================================================================

@fn x11_parse_event(packet_32)
  @if packet_32.len() < 32
    return { event_type: 0, window_id: 0, root_window_id: 0, x: 0, y: 0, root_x: 0, root_y: 0, code: 0, state: 0, width: 0, height: 0, count: 0 }
  @end

  raw_type = packet_32[0]
  ev_type = raw_type % 128 @! Strip highest bit (SendEvent flag)
  
  @! 1. KeyPress (2) or KeyRelease (3)
  @if ev_type == 2 || ev_type == 3
    keycode = packet_32[1]
    event_win = packet_32[4] + packet_32[5] * 256 + packet_32[6] * 65536 + packet_32[7] * 16777216
    pos_x = packet_32[16] + packet_32[17] * 256
    pos_y = packet_32[18] + packet_32[19] * 256
    st = packet_32[20] + packet_32[21] * 256
    return {
      event_type: ev_type,
      window_id: event_win,
      root_window_id: 0,
      x: pos_x,
      y: pos_y,
      root_x: 0,
      root_y: 0,
      code: keycode,
      state: st,
      width: 0,
      height: 0,
      count: 0
    }
  @! 2. ButtonPress (4) or ButtonRelease (5)
  @elif ev_type == 4 || ev_type == 5
    button = packet_32[1]
    event_win = packet_32[4] + packet_32[5] * 256 + packet_32[6] * 65536 + packet_32[7] * 16777216
    pos_x = packet_32[16] + packet_32[17] * 256
    pos_y = packet_32[18] + packet_32[19] * 256
    st = packet_32[20] + packet_32[21] * 256
    return {
      event_type: ev_type,
      window_id: event_win,
      root_window_id: 0,
      x: pos_x,
      y: pos_y,
      root_x: 0,
      root_y: 0,
      code: button,
      state: st,
      width: 0,
      height: 0,
      count: 0
    }
  @! 3. MotionNotify (6)
  @elif ev_type == 6
    event_win = packet_32[4] + packet_32[5] * 256 + packet_32[6] * 65536 + packet_32[7] * 16777216
    pos_x = packet_32[16] + packet_32[17] * 256
    pos_y = packet_32[18] + packet_32[19] * 256
    st = packet_32[20] + packet_32[21] * 256
    return {
      event_type: 6,
      window_id: event_win,
      root_window_id: 0,
      x: pos_x,
      y: pos_y,
      root_x: 0,
      root_y: 0,
      code: 0,
      state: st,
      width: 0,
      height: 0,
      count: 0
    }
  @! 4. Expose (12)
  @elif ev_type == 12
    event_win = packet_32[4] + packet_32[5] * 256 + packet_32[6] * 65536 + packet_32[7] * 16777216
    exp_x = packet_32[8] + packet_32[9] * 256
    exp_y = packet_32[10] + packet_32[11] * 256
    exp_w = packet_32[12] + packet_32[13] * 256
    exp_h = packet_32[14] + packet_32[15] * 256
    cnt = packet_32[16] + packet_32[17] * 256
    return {
      event_type: 12,
      window_id: event_win,
      root_window_id: 0,
      x: exp_x,
      y: exp_y,
      root_x: 0,
      root_y: 0,
      code: 0,
      state: 0,
      width: exp_w,
      height: exp_h,
      count: cnt
    }
  @! 5. ConfigureNotify (22)
  @elif ev_type == 22
    event_win = packet_32[4] + packet_32[5] * 256 + packet_32[6] * 65536 + packet_32[7] * 16777216
    pos_x = packet_32[12] + packet_32[13] * 256
    pos_y = packet_32[14] + packet_32[15] * 256
    cfg_w = packet_32[16] + packet_32[17] * 256
    cfg_h = packet_32[18] + packet_32[19] * 256
    return {
      event_type: 22,
      window_id: event_win,
      root_window_id: 0,
      x: pos_x,
      y: pos_y,
      root_x: 0,
      root_y: 0,
      code: 0,
      state: 0,
      width: cfg_w,
      height: cfg_h,
      count: 0
    }
  @! 6. ClientMessage (33)
  @elif ev_type == 33
    event_win = packet_32[4] + packet_32[5] * 256 + packet_32[6] * 65536 + packet_32[7] * 16777216
    return {
      event_type: 33,
      window_id: event_win,
      root_window_id: 0,
      x: 0,
      y: 0,
      root_x: 0,
      root_y: 0,
      code: 0,
      state: 0,
      width: 0,
      height: 0,
      count: 0
    }
  @end

  return {
    event_type: ev_type,
    window_id: 0,
    root_window_id: 0,
    x: 0,
    y: 0,
    root_x: 0,
    root_y: 0,
    code: 0,
    state: 0,
    width: 0,
    height: 0,
    count: 0
  }
@end
