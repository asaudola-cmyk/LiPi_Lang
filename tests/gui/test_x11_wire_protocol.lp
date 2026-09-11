@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — PURE MAYA DIRECT X11 WIRE PROTOCOL TEST SUITE
@! File: tests/gui/test_x11_wire_protocol.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/widget"
import "universe/gui/x11/x11_protocol"
import "universe/gui/x11/x11_window"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🖥️ MAYA DIRECT WIRE X11 GUI PROTOCOL & WINDOW ENGINE TEST SUITE 🖥️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: X11 Handshake Packet Encoding
  println("▶ Section 1: X11 Handshake Packet Construction...")
  total_tests = total_tests + 1
  hs_pkt = x11_build_handshake("", "")
  ok1 = assert_eq_int(hs_pkt.data[0], 108, "Byte order is 'l' (0x6C Little Endian)")
  ok2 = assert_eq_int(hs_pkt.data[2], 11, "Protocol Major version is 11")
  ok3 = assert_eq_int(hs_pkt.data[4], 0, "Protocol Minor version is 0")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] X11 Little-Endian handshake packet encoding verified")
  @end

  @! SECTION 2: X11 Handshake Reply Decoding
  println("▶ Section 2: X11 Handshake Server Reply Parser...")
  total_tests = total_tests + 1
  @! Mock 40-byte success reply: status 1, major 11, minor 0, res_base 0x00200000, res_mask 0x001FFFFF
  mock_reply = [
    1, 0, 11, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 32, 0,
    255, 255, 31, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
  ]
  hs_res = x11_parse_handshake_reply(mock_reply)
  ok1 = assert_eq_int(hs_res.status, 1, "Handshake status is Success (1)")
  ok2 = assert_eq_int(hs_res.protocol_major, 11, "Parsed major version 11")
  ok3 = assert_eq_int(hs_res.resource_id_base, 2097152, "Parsed resource ID base (0x200000)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Handshake reply decoder & resource base extraction verified")
  @end

  @! SECTION 3: CreateWindow & CreateGC Request Packet Framing
  println("▶ Section 3: CreateWindow & CreateGC Request Encoding...")
  total_tests = total_tests + 1
  conn = x11_connection_new(hs_res)
  win = x11_window_create(conn, "Maya Pure Window", 100, 100, 800, 600, 16777215)
  cw_pkt = x11_build_create_window(win.window_id, hs_res.root_window_id, 100, 100, 800, 600, 0, hs_res.root_visual_id, 16777215)
  ok1 = assert_eq_int(cw_pkt.data[0], 1, "Opcode is CreateWindow (1)")
  ok2 = assert_eq_int(cw_pkt.data[1], 24, "Depth is 24-bit TrueColor")
  ok3 = assert_eq_int(cw_pkt.data.len(), 40, "Packet length is 40 bytes (10 32-bit words)")

  gc_pkt = x11_build_create_gc(win.gc_id, win.window_id, 0, 16777215)
  ok4 = assert_eq_int(gc_pkt.data[0], 55, "Opcode is CreateGC (55)")
  ok5 = assert_eq_int(gc_pkt.data.len(), 24, "GC packet length is 24 bytes (6 32-bit words)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] CreateWindow & CreateGC packet framing verified")
  @end

  @! SECTION 4: MapWindow & PolyFillRectangle Request Packet Framing
  println("▶ Section 4: MapWindow & PolyFillRectangle Encoding...")
  total_tests = total_tests + 1
  map_pkt = x11_window_map(conn, win)
  ok1 = assert_eq_int(win.is_mapped, 1, "Window state updated to mapped")
  ok2 = assert_eq_int(map_pkt.data[0], 8, "Opcode is MapWindow (8)")
  ok3 = assert_eq_int(map_pkt.data.len(), 8, "MapWindow length is 8 bytes (2 words)")

  fill_pkt = x11_build_poly_fill_rect(win.window_id, win.gc_id, 10, 20, 100, 50)
  ok4 = assert_eq_int(fill_pkt.data[0], 70, "Opcode is PolyFillRectangle (70)")
  ok5 = assert_eq_int(fill_pkt.data.len(), 20, "PolyFillRectangle length is 20 bytes (5 words)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] MapWindow & PolyFillRectangle framing verified")
  @end

  @! SECTION 5: Direct Canvas Framebuffer to PutImage (ZPixmap) Blit
  println("▶ Section 5: Native Framebuffer Canvas -> X11 ZPixmap Presentation...")
  total_tests = total_tests + 1
  @! Draw something onto Canvas
  canvas_fill_rect(win.canvas, 0, 0, 50, 50, 4294901760) @! Red square
  canvas_fill_rect(win.canvas, 50, 0, 50, 50, 4278255360) @! Green square
  
  put_pkt = x11_window_present_canvas(conn, win)
  ok1 = assert_eq_int(put_pkt.data[0], 72, "Opcode is PutImage (72)")
  ok2 = assert_eq_int(put_pkt.data[1], 2, "Format is ZPixmap (2)")
  ok3 = assert_eq_int(put_pkt.data[21], 24, "Image depth is 24-bit")
  ok4 = assert_true(put_pkt.data.len() > 24, "Contains serialized pixel bytes")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Canvas to X11 PutImage ZPixmap pixel presentation verified")
  @end

  @! SECTION 6: 32-Byte Event Demuxer & Mouse/Key Event Parsing
  println("▶ Section 6: 32-Byte Raw X11 Event Packet Demuxer...")
  total_tests = total_tests + 1
  @! Construct mock 32-byte ButtonPress event (opcode 4, button 1, x 350, y 220)
  mock_btn_press = [
    4, 1, 0, 0, 10, 0, 32, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    94, 1, 220, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
  ]
  ev_btn = x11_parse_event(mock_btn_press)
  ok1 = assert_eq_int(ev_btn.event_type, 4, "Event type is ButtonPress (4)")
  ok2 = assert_eq_int(ev_btn.code, 1, "Button code is Left Click (1)")
  ok3 = assert_eq_int(ev_btn.x, 350, "Mouse X coordinate is 350")
  ok4 = assert_eq_int(ev_btn.y, 220, "Mouse Y coordinate is 220")

  @! Construct mock 32-byte KeyPress event (opcode 2, keycode 65 = 'A', x 0, y 0)
  mock_key_press = [
    2, 65, 0, 0, 10, 0, 32, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
  ]
  ev_key = x11_parse_event(mock_key_press)
  ok5 = assert_eq_int(ev_key.event_type, 2, "Event type is KeyPress (2)")
  ok6 = assert_eq_int(ev_key.code, 65, "Keycode is 65 ('A')")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 32-byte X11 event packet demuxer verified")
  @end

  @! SECTION 7: Event Translation to Maya Native GUI Widgets
  println("▶ Section 7: X11 Event to Native GUI Widget Event Translation...")
  total_tests = total_tests + 1
  gui_mouse_ev = x11_translate_event(mock_btn_press)
  ok1 = assert_eq_int(gui_mouse_ev.event_type, 1, "Translated to MOUSE_DOWN (1)")
  ok2 = assert_eq_int(gui_mouse_ev.mouse_x, 350, "Widget mouse_x is 350")
  ok3 = assert_eq_int(gui_mouse_ev.mouse_y, 220, "Widget mouse_y is 220")

  gui_key_ev = x11_translate_event(mock_key_press)
  ok4 = assert_eq_int(gui_key_ev.event_type, 4, "Translated to KEY_DOWN (4)")
  ok5 = assert_eq_int(gui_key_ev.key_code, 65, "Widget key_code is 65")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Event translation pipeline to Maya Widget suite verified")
  @end

  println("=================================================================")
  println("📊 X11 WIRE PROTOCOL TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 7 PURE MAYA DIRECT X11 TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME X11 TESTS FAILED")
    return 1
  @end
@end
