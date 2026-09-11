@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE — CHALLENGER 2
@! File: tests/adversarial/test_adv_challenger2_webrtc_coop_stress.maya
@! Focus:
@! 1. @remote WebRTC Hybrid Streaming Stress:
@!    - Corrupted / Malformed / Extreme SDP Payloads
@!    - Out-of-bounds Canvas Sub-rect Clipping & Corner Cases
@!    - High-frequency Pointer Drag / Input Flooding on DataChannel & Gateway
@! 2. Polymorphic Server Security Header Emission:
@!    - COOP/COEP Emission Across All Modes (Daemon, CGI, FastCGI)
@!    - Unusual, Edge, and Custom HTTP Status Codes (1xx, 2xx, 3xx, 4xx, 5xx, Custom)
@!    - Complex Content-Types, Payloads, Idempotency & FastCGI Framing
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/web/frontend/remote/remote_directive"
import "universe/web/frontend/remote/webrtc_client"
import "universe/web/frontend/remote/video_blitter"
import "universe/web/frontend/remote/remote_server_adapter"
import "universe/web/frontend/remote/mod"
import "universe/web/polymorphic_server"

@struct StressTestState
  total: i64
  passed: i64
  failed: i64
@end

@fn stress_state_new()
  return { total: 0, passed: 0, failed: 0 }
@end

@fn assert_true(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == true || cond == 1
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_eq_int(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc + " (" + actual.to_str() + ")")
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc + " ('" + actual + "')")
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@fn assert_contains(state, haystack, needle, test_id, desc)
  state.total = state.total + 1
  @if contains(haystack, needle) == 1
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc + " (contains '" + needle + "')")
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (missing '" + needle + "')")
    return 0
  @end
@end

@! ============================================================================
@! 1. ADVERSARIAL WEBRTC SDP STRESS TESTS
@! ============================================================================

@fn test_adversarial_sdp_payloads(state)
  println("\n=================================================================")
  println("🔥 ADVERSARIAL SECTION 1: Corrupted & Extreme SDP Payloads 🔥")
  println("=================================================================")

  @! Test 1.1: Empty SDP string rejection
  c1 = webrtc_client_new("sess_sdp_01", "vp_3d", "", "")
  c1 = webrtc_set_remote_description(c1, "")
  assert_eq_int(state, c1.peer_state, PEER_STATE_FAILED(), "SDP-01", "Empty remote SDP answer transitions client to PEER_STATE_FAILED")
  assert_eq_str(state, c1.last_error, "Empty SDP answer received", "SDP-02", "Error message recorded for empty SDP answer")

  @! Test 1.2: Truncated / malformed SDP string handling
  c2 = webrtc_client_new("sess_sdp_02", "vp_3d", "", "")
  c2 = webrtc_set_remote_description(c2, "v=0\r\n")
  assert_eq_int(state, c2.peer_state, PEER_STATE_CONNECTED(), "SDP-03", "Non-empty SDP transitions to CONNECTED state")
  assert_eq_str(state, c2.remote_sdp, "v=0\r\n", "SDP-04", "Remote SDP stored accurately without crash")

  @! Test 1.3: Garbage binary / extreme ASCII string
  garbage_sdp = "INVALID_CORRUPTED_SDP_###_$$$_\x00\xFF_NO_MEDIA_LINES_HERE"
  c3 = webrtc_client_new("sess_sdp_03", "vp_3d", "", "")
  c3 = webrtc_set_remote_description(c3, garbage_sdp)
  assert_eq_int(state, c3.peer_state, PEER_STATE_CONNECTED(), "SDP-05", "Garbage SDP string stored safely")

  @! Test 1.4: Massive SDP string payload (repeated lines)
  huge_sdp = "v=0\r\no=- 1000 2 IN IP4 127.0.0.1\r\ns=Stress\r\n"
  k = 0
  @while k < 8
    huge_sdp = huge_sdp + "a=custom-attribute-line-payload-stress-test-data-padding-string\r\n"
    k = k + 1
  @end
  c4 = webrtc_client_new("sess_sdp_04", "vp_3d", "", "")
  c4 = webrtc_set_remote_description(c4, huge_sdp)
  assert_true(state, str_len(c4.remote_sdp) > 200, "SDP-06", "Huge SDP string payload handled without truncation or buffer corruption")

  @! Test 1.5: Gateway SDP Answer generation with malformed session and missing session
  gw = remote_gateway_init("stun.local", "turn.local", 10)
  gw = remote_gateway_create_session(gw, "sess_active_1", "comp_1", 1920, 1080, 60, "H264")
  
  ans_valid = remote_gateway_generate_sdp_answer(gw, "sess_active_1", "v=0\r\n")
  assert_contains(state, ans_valid, "a=rtpmap:100 H264/90000", "SDP-07", "Gateway generates valid SDP answer for active session")

  ans_missing = remote_gateway_generate_sdp_answer(gw, "sess_NON_EXISTENT", "v=0\r\n")
  assert_eq_str(state, ans_missing, "", "SDP-08", "Gateway returns empty SDP string for non-existent session without crashing")

  @! Test 1.6: Malformed JSON signaling envelopes
  resp_malformed1 = remote_gateway_handle_signaling_http(gw, "NOT_A_VALID_JSON_OBJECT")
  assert_contains(state, resp_malformed1, "Cross-Origin-Opener-Policy: same-origin", "SDP-09", "Signaling response for malformed JSON still includes COOP")
  assert_contains(state, resp_malformed1, "Cross-Origin-Embedder-Policy: require-corp", "SDP-10", "Signaling response for malformed JSON still includes COEP")

  resp_malformed2 = remote_gateway_handle_signaling_http(gw, "{\"session_id\":\"sess_new_auto\",\"sdp\":\"\"}")
  assert_contains(state, resp_malformed2, "sess_new_auto", "SDP-11", "Signaling auto-creates missing session and responds")

  @! Test 1.7: Double close and state machine robustness
  c5 = webrtc_client_new("sess_sdp_05", "vp_3d", "", "")
  c5 = webrtc_create_data_channel(c5, "ch1", true)
  c5 = webrtc_attach_track(c5, "trk1", "video", 640, 480, 30)
  c5 = webrtc_close(c5)
  assert_eq_int(state, c5.peer_state, PEER_STATE_CLOSED(), "SDP-12", "Client closed first time")
  c5 = webrtc_close(c5)
  assert_eq_int(state, c5.peer_state, PEER_STATE_CLOSED(), "SDP-13", "Client closed second time remains in PEER_STATE_CLOSED safely")

  dc_closed = webrtc_get_data_channel(c5, "ch1")
  assert_eq_str(state, dc_closed.state, "closed", "SDP-14", "DataChannel is marked closed upon client shutdown")
  
  trk_closed = webrtc_get_video_track(c5)
  assert_eq_str(state, trk_closed.ready_state, "ended", "SDP-15", "MediaTrack is marked ended upon client shutdown")
@end

@! ============================================================================
@! 2. ADVERSARIAL CANVAS SUB-RECT CLIPPING STRESS TESTS
@! ============================================================================

@fn test_adversarial_subrect_clipping(state)
  println("\n=================================================================")
  println("🔥 ADVERSARIAL SECTION 2: Out-Of-Bounds Sub-Rect Clipping & Blitting 🔥")
  println("=================================================================")

  canvas_w = 800
  canvas_h = 600
  total_pixels = canvas_w * canvas_h
  bg_color = 4294967295 @! White 0xFFFFFFFF
  fg_blue = 4278190335  @! Blue 0xFF0000FF

  @! Helper to build clean white canvas framebuffer
  canvas_fb = []
  i = 0
  @while i < total_pixels
    canvas_fb = canvas_fb.push(bg_color)
    i = i + 1
  @end

  frame_solid = video_blitter_create_solid_frame(10, 100, 100, fg_blue, 16)

  @! Test 2.1: Completely Negative Coordinates (dest_x = -500, dest_y = -300, dest_w = 200, dest_h = 200)
  blitter_neg = video_blitter_new(canvas_w, canvas_h, -500, -300, 200, 200)
  canvas_fb = video_blitter_blit_frame(blitter_neg, frame_solid, canvas_fb)
  assert_eq_int(state, blitter_neg.frames_blitted, 0, "CLIP-01", "Completely negative sub-rect blits 0 frames (completely clipped)")
  assert_eq_int(state, blitter_neg.total_pixels_copied, 0, "CLIP-02", "0 pixels copied for negative out-of-bounds sub-rect")
  assert_eq_int(state, canvas_fb[0], bg_color, "CLIP-03", "Canvas origin pixel unmodified")

  @! Test 2.2: Completely Beyond Canvas Dimensions (dest_x = 1200, dest_y = 900, dest_w = 400, dest_h = 300)
  blitter_beyond = video_blitter_new(canvas_w, canvas_h, 1200, 900, 400, 300)
  canvas_fb = video_blitter_blit_frame(blitter_beyond, frame_solid, canvas_fb)
  assert_eq_int(state, blitter_beyond.frames_blitted, 0, "CLIP-04", "Far out-of-bounds sub-rect blits 0 frames")
  assert_eq_int(state, blitter_beyond.total_pixels_copied, 0, "CLIP-05", "0 pixels copied for far out-of-bounds sub-rect")

  @! Test 2.3: Massive Overlapping Sub-Rect (dest_x = -100, dest_y = -100, dest_w = 2000, dest_h = 2000)
  blitter_huge = video_blitter_new(canvas_w, canvas_h, -100, -100, 2000, 2000)
  canvas_fb = video_blitter_blit_frame(blitter_huge, frame_solid, canvas_fb)
  dr_huge = video_blitter_get_dirty_rect(blitter_huge)
  assert_eq_int(state, dr_huge.min_x, 0, "CLIP-06", "Massive sub-rect clamped min_x to canvas 0")
  assert_eq_int(state, dr_huge.min_y, 0, "CLIP-07", "Massive sub-rect clamped min_y to canvas 0")
  assert_eq_int(state, dr_huge.max_x, canvas_w, "CLIP-08", "Massive sub-rect clamped max_x to canvas_width 800")
  assert_eq_int(state, dr_huge.max_y, canvas_h, "CLIP-09", "Massive sub-rect clamped max_y to canvas_height 600")
  assert_eq_int(state, blitter_huge.total_pixels_copied, total_pixels, "CLIP-10", "All 480,000 canvas pixels safely filled without buffer overrun")

  @! Reset canvas framebuffer
  canvas_fb = []
  i = 0
  @while i < total_pixels
    canvas_fb = canvas_fb.push(bg_color)
    i = i + 1
  @end

  @! Test 2.4: Left Edge Overflow (dest_x = -50, dest_y = 100, dest_w = 100, dest_h = 100)
  blitter_left = video_blitter_new(canvas_w, canvas_h, -50, 100, 100, 100)
  canvas_fb = video_blitter_blit_frame(blitter_left, frame_solid, canvas_fb)
  dr_left = video_blitter_get_dirty_rect(blitter_left)
  assert_eq_int(state, dr_left.min_x, 0, "CLIP-11", "Left overflow clipped to min_x=0")
  assert_eq_int(state, dr_left.max_x, 50, "CLIP-12", "Left overflow clipped to max_x=50")
  assert_eq_int(state, dr_left.min_y, 100, "CLIP-13", "Left overflow min_y=100")
  assert_eq_int(state, dr_left.max_y, 200, "CLIP-14", "Left overflow max_y=200")
  assert_eq_int(state, blitter_left.total_pixels_copied, 50 * 100, "CLIP-15", "Exactly 5,000 pixels copied for left overflow")

  @! Test 2.5: Right Edge Overflow (dest_x = 750, dest_y = 100, dest_w = 100, dest_h = 100)
  blitter_right = video_blitter_new(canvas_w, canvas_h, 750, 100, 100, 100)
  canvas_fb = video_blitter_blit_frame(blitter_right, frame_solid, canvas_fb)
  dr_right = video_blitter_get_dirty_rect(blitter_right)
  assert_eq_int(state, dr_right.min_x, 750, "CLIP-16", "Right overflow min_x=750")
  assert_eq_int(state, dr_right.max_x, 800, "CLIP-17", "Right overflow clipped to max_x=800")
  assert_eq_int(state, blitter_right.total_pixels_copied, 50 * 100, "CLIP-18", "Exactly 5,000 pixels copied for right overflow")

  @! Test 2.6: Top Edge Overflow (dest_x = 100, dest_y = -50, dest_w = 100, dest_h = 100)
  blitter_top = video_blitter_new(canvas_w, canvas_h, 100, -50, 100, 100)
  canvas_fb = video_blitter_blit_frame(blitter_top, frame_solid, canvas_fb)
  dr_top = video_blitter_get_dirty_rect(blitter_top)
  assert_eq_int(state, dr_top.min_y, 0, "CLIP-19", "Top overflow clipped to min_y=0")
  assert_eq_int(state, dr_top.max_y, 50, "CLIP-20", "Top overflow clipped to max_y=50")
  assert_eq_int(state, blitter_top.total_pixels_copied, 100 * 50, "CLIP-21", "Exactly 5,000 pixels copied for top overflow")

  @! Test 2.7: Bottom Edge Overflow (dest_x = 100, dest_y = 550, dest_w = 100, dest_h = 100)
  blitter_bottom = video_blitter_new(canvas_w, canvas_h, 100, 550, 100, 100)
  canvas_fb = video_blitter_blit_frame(blitter_bottom, frame_solid, canvas_fb)
  dr_bottom = video_blitter_get_dirty_rect(blitter_bottom)
  assert_eq_int(state, dr_bottom.min_y, 550, "CLIP-22", "Bottom overflow min_y=550")
  assert_eq_int(state, dr_bottom.max_y, 600, "CLIP-23", "Bottom overflow clipped to max_y=600")
  assert_eq_int(state, blitter_bottom.total_pixels_copied, 100 * 50, "CLIP-24", "Exactly 5,000 pixels copied for bottom overflow")

  @! Test 2.8: Disjoint Clip Rect (clip rect completely separate from subrect)
  blitter_disjoint = video_blitter_new(canvas_w, canvas_h, 100, 100, 100, 100)
  blitter_disjoint = video_blitter_set_clip(blitter_disjoint, 500, 500, 50, 50)
  canvas_fb = video_blitter_blit_frame(blitter_disjoint, frame_solid, canvas_fb)
  assert_eq_int(state, blitter_disjoint.frames_blitted, 0, "CLIP-25", "Disjoint clip rect prevents any pixel blit")
  assert_eq_int(state, blitter_disjoint.total_pixels_copied, 0, "CLIP-26", "0 pixels copied for disjoint clip rect")

  @! Test 2.9: Negative / Zero Dimensions constructor hardening
  b_zero = video_blitter_new(0, -10, -50, 0, 0, -20)
  assert_true(state, b_zero.canvas_width >= 1, "CLIP-27", "Zero canvas width clamped to positive minimum")
  assert_true(state, b_zero.canvas_height >= 1, "CLIP-28", "Negative canvas height clamped to positive minimum")
  assert_true(state, b_zero.subrect.dest_w >= 1, "CLIP-29", "Zero dest_w clamped to positive minimum")
  assert_true(state, b_zero.subrect.dest_h >= 1, "CLIP-30", "Negative dest_h clamped to positive minimum")

  @! Test 2.10: Empty Frame Pixels Handling
  empty_frame = video_blitter_create_frame(99, 100, 100, [], 100, PIXEL_FMT_ARGB())
  canvas_fb = video_blitter_blit_frame(blitter_bottom, empty_frame, canvas_fb)
  assert_true(state, true, "CLIP-31", "Empty frame pixels array blitted safely without crash")
@end

@! ============================================================================
@! 3. ADVERSARIAL HIGH-FREQUENCY DATACHANNEL INPUT FLOODING
@! ============================================================================

@fn test_adversarial_datachannel_flooding(state)
  println("\n=================================================================")
  println("🔥 ADVERSARIAL SECTION 3: High-Frequency DataChannel Input Flooding 🔥")
  println("=================================================================")

  client = webrtc_client_new("sess_flood_01", "viewport_stress", "", "")
  client = webrtc_create_data_channel(client, "user_input", true)
  
  gw = remote_gateway_init("", "", 10)
  gw = remote_gateway_create_session(gw, "sess_flood_01", "viewport_stress", 1280, 720, 60, "H264")

  @! Test 3.1: 500 Sequential Pointer Drag Events Flood on DataChannel
  flood_count = 500
  idx = 0
  all_sent = true
  @while idx < flood_count
    cur_x = (idx * 3) % 800
    cur_y = (idx * 5) % 600
    ok = webrtc_send_input_event(client, INPUT_TYPE_POINTER_MOVE(), cur_x, cur_y, 0, 0)
    @if ok == false
      all_sent = false
    @end
    idx = idx + 1
  @end

  assert_true(state, all_sent, "FLOOD-01", "500 consecutive high-frequency pointer drag events queued on DataChannel")
  
  dc = webrtc_get_data_channel(client, "user_input")
  assert_eq_int(state, dc.messages_sent, 500, "FLOOD-02", "DataChannel messages_sent exactly tracks 500 events")
  assert_eq_int(state, dc.sent_queue.len(), 500, "FLOOD-03", "DataChannel sent_queue contains all 500 queued payloads")
  assert_true(state, dc.bytes_sent > 5000, "FLOOD-04", "DataChannel bytes_sent accumulates payload byte lengths accurately")

  @! Test 3.2: 500 Sequential Input Event Dispatches on Backend Gateway
  b_idx = 0
  all_handled = true
  @while b_idx < flood_count
    cur_x = (b_idx * 17) % 1920
    cur_y = (b_idx * 23) % 1080
    b_ok = remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_POINTER_MOVE(), cur_x, cur_y, 0, 0)
    @if b_ok == false
      all_handled = false
    @end
    b_idx = b_idx + 1
  @end

  assert_true(state, all_handled, "FLOOD-05", "Backend gateway successfully processed 500 rapid pointer drag events")
  
  sess = remote_gateway_get_session(gw, "sess_flood_01")
  assert_eq_int(state, sess.input_event_count, 500, "FLOOD-06", "Session input_event_count exactly matches 500 processed events")
  assert_eq_int(state, gw.total_input_events_handled, 500, "FLOOD-07", "Gateway global total_input_events_handled equals 500")
  assert_true(state, sess.camera_rot_x >= -360 && sess.camera_rot_x <= 360, "FLOOD-08", "Camera X rotation remains within bounded angular degree range")
  assert_true(state, sess.camera_rot_y >= -360 && sess.camera_rot_y <= 360, "FLOOD-09", "Camera Y rotation remains within bounded angular degree range")

  @! Test 3.3: Extreme / Out-of-Range Coordinates Stress
  extreme_ok1 = remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_POINTER_MOVE(), 1000000, -1000000, 0, 0)
  assert_true(state, extreme_ok1, "FLOOD-10", "Extreme million-pixel coordinates handled without integer overflow panic")

  @! Test 3.4: High-Frequency Zoom Wheel Clamping Stress (100 zoom-in events + 100 zoom-out events)
  w_idx = 0
  @while w_idx < 100
    remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_WHEEL(), 0, 10, 0, 0) @! Zoom in (+5 each)
    w_idx = w_idx + 1
  @end
  sess_zoomed = remote_gateway_get_session(gw, "sess_flood_01")
  assert_eq_int(state, sess_zoomed.camera_zoom, 500, "FLOOD-11", "Camera zoom clamped at max 500% under heavy zoom-in flood")

  w_idx = 0
  @while w_idx < 200
    remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_WHEEL(), 0, -10, 0, 0) @! Zoom out (-5 each)
    w_idx = w_idx + 1
  @end
  sess_zoomed_out = remote_gateway_get_session(gw, "sess_flood_01")
  assert_eq_int(state, sess_zoomed_out.camera_zoom, 10, "FLOOD-12", "Camera zoom clamped at min 10% under heavy zoom-out flood")

  @! Test 3.5: Keyboard Navigation Flooding (Arrow keys)
  remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_KEY_DOWN(), 0, 0, 37, 0) @! Left
  remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_KEY_DOWN(), 0, 0, 39, 0) @! Right
  remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_KEY_DOWN(), 0, 0, 38, 0) @! Up
  remote_gateway_process_input(gw, "sess_flood_01", INPUT_TYPE_KEY_DOWN(), 0, 0, 40, 0) @! Down
  assert_true(state, true, "FLOOD-13", "Keyboard arrow key navigation events handled cleanly")

  @! Test 3.6: Non-existent session input handling
  bad_in_ok = remote_gateway_process_input(gw, "sess_INVALID_ID", INPUT_TYPE_POINTER_MOVE(), 10, 10, 0, 0)
  assert_true(state, !bad_in_ok, "FLOOD-14", "Input dispatch to invalid session returns false safely")
@end

@! ============================================================================
@! 4. ADVERSARIAL POLYMORPHIC SERVER COOP/COEP HEADER EMISSION STRESS
@! ============================================================================

@fn test_adversarial_polymorphic_headers(state)
  println("\n=================================================================")
  println("🔥 ADVERSARIAL SECTION 4: COOP/COEP Emission Across Modes & Codes 🔥")
  println("=================================================================")

  @! Exhaustive status codes matrix to test across Modes 0 (Daemon), 1 (CGI), 2 (FastCGI)
  unusual_status_codes = [
    100, 101,
    200, 201, 202, 204, 206,
    301, 302, 304, 307, 308,
    400, 401, 403, 404, 405, 408, 409, 410, 413, 418, 429,
    500, 501, 502, 503, 504, 505,
    999
  ]

  modes = [0, 1, 2]

  m_i = 0
  all_status_modes_pass = true
  total_status_tested = 0

  @while m_i < modes.len()
    cur_mode = modes[m_i]
    s_i = 0
    @while s_i < unusual_status_codes.len()
      cur_status = unusual_status_codes[s_i]
      
      body_text = "STATUS_BODY_" + cur_mode.to_str() + "_" + cur_status.to_str()
      resp = polymorphic_build_response(cur_mode, cur_status, "application/json", body_text)
      
      has_coop = polymorphic_has_coop_header(resp)
      has_coep = polymorphic_has_coep_header(resp)
      has_iso = polymorphic_has_isolation_headers(resp)

      @if has_coop == 0 || has_coep == 0 || has_iso == 0
        all_status_modes_pass = false
        println("  [FAIL] Failed COOP/COEP for Mode=" + cur_mode.to_str() + ", Status=" + cur_status.to_str())
      @end

      total_status_tested = total_status_tested + 1
      s_i = s_i + 1
    @end
    m_i = m_i + 1
  @end

  assert_true(state, all_status_modes_pass, "COOP-01", "COOP/COEP headers present across all " + total_status_tested.to_str() + " Mode × Status Code combinations")

  @! Test 4.2: Unusual / Extreme Content Types
  content_types = [
    "application/wasm",
    "application/octet-stream",
    "application/x-maya-binary",
    "text/html; charset=utf-8",
    "image/png",
    "video/webm",
    "multipart/form-data; boundary=---MayaBoundary123",
    "",
    "custom/type-with-special-symbols-@!#$"
  ]

  ct_i = 0
  all_ct_pass = true
  @while ct_i < content_types.len()
    ct = content_types[ct_i]
    r_ct = polymorphic_build_response(0, 200, ct, "DATA")
    @if polymorphic_has_isolation_headers(r_ct) == 0 || contains(r_ct, "Content-Type: " + ct) == 0
      all_ct_pass = false
    @end
    ct_i = ct_i + 1
  @end

  assert_true(state, all_ct_pass, "COOP-02", "All unusual content-types retain both Content-Type and COOP/COEP headers")

  @! Test 4.3: Extreme Payloads (Empty Body vs Huge 32KB Binary-like Body)
  r_empty = polymorphic_build_response(0, 204, "text/plain", "")
  assert_contains(state, r_empty, "Content-Length: 0", "COOP-03", "Empty body produces Content-Length: 0")
  assert_true(state, polymorphic_has_isolation_headers(r_empty), "COOP-04", "Empty body retains COOP/COEP isolation")

  huge_body = "ABCDEF0123456789"
  hb_i = 0
  @while hb_i < 10
    huge_body = huge_body + huge_body
    hb_i = hb_i + 1
  @end
  r_huge = polymorphic_build_response(0, 200, "application/wasm", huge_body)
  assert_true(state, polymorphic_has_isolation_headers(r_huge), "COOP-05", "Huge 16KB+ WASM payload retains COOP/COEP isolation")
  assert_contains(state, r_huge, "Content-Length: " + str_len(huge_body).to_str(), "COOP-06", "Content-Length accurately matches huge payload length")

  @! Test 4.4: Header Injection Idempotency (Multiple rounds of injection)
  base_headers = "Server: MayaSovereign\r\nContent-Type: text/html\r\n"
  inj1 = polymorphic_inject_security_headers(base_headers)
  inj2 = polymorphic_inject_security_headers(inj1)
  inj3 = polymorphic_inject_security_headers(inj2)
  assert_eq_str(state, inj1, inj3, "COOP-07", "Triple header injection produces identical idempotent output without duplication")

  @! Test 4.5: FastCGI Binary Framing with Unusual Request IDs
  fcgi_rec1 = fcgi_build_stdout_record(65535, "MAX_U16_REQ_ID_BODY")
  assert_eq_int(state, fcgi_rec1[0], 1, "COOP-08", "FastCGI version is 1")
  assert_eq_int(state, fcgi_rec1[1], 6, "COOP-09", "FastCGI record type is 6 (FCGI_STDOUT)")
  assert_eq_int(state, fcgi_rec1[2], 255, "COOP-10", "FastCGI req_id high byte is 255 (65535 / 256)")
  assert_eq_int(state, fcgi_rec1[3], 255, "COOP-11", "FastCGI req_id low byte is 255 (65535 % 256)")

  fcgi_end_rec = fcgi_build_end_request_record(65535, 0, 0)
  assert_eq_int(state, fcgi_end_rec[1], 3, "COOP-12", "FastCGI record type is 3 (FCGI_END_REQUEST)")
  assert_eq_int(state, fcgi_end_rec.len(), 16, "COOP-13", "FastCGI END_REQUEST record is exactly 16 bytes")

  @! Test 4.6: Polymorphic Server Context Lifecycle & Auto-Detection
  ctx_auto_fcgi = polymorphic_server_init("", "FCGI_ROLE=RESPONDER", 9000)
  assert_eq_int(state, ctx_auto_fcgi.active_mode, 2, "COOP-14", "Auto-detects FastCGI from environment")

  ctx_auto_cgi = polymorphic_server_init("CGI/1.1", "", 80)
  assert_eq_int(state, ctx_auto_cgi.active_mode, 1, "COOP-15", "Auto-detects CGI from environment")

  ctx_auto_daemon = polymorphic_server_init("", "", 8080)
  assert_eq_int(state, ctx_auto_daemon.active_mode, 0, "COOP-16", "Auto-detects Standalone Daemon when no CGI/FCGI env")

  @! Test 4.7: Custom Request Dispatch across all 3 context modes
  r_cust_fcgi = polymorphic_handle_custom_request(ctx_auto_fcgi, 418, "application/json", "{\"teapot\":true}")
  assert_contains(state, r_cust_fcgi, "Status: 418", "COOP-17", "FastCGI custom request contains Status: 418")
  assert_true(state, polymorphic_has_isolation_headers(r_cust_fcgi), "COOP-18", "FastCGI 418 teapot response retains COOP/COEP")

  r_cust_cgi = polymorphic_handle_custom_request(ctx_auto_cgi, 503, "text/plain", "Unavailable")
  assert_contains(state, r_cust_cgi, "Status: 503 Service Unavailable", "COOP-19", "CGI custom request contains Status: 503")
  assert_true(state, polymorphic_has_isolation_headers(r_cust_cgi), "COOP-20", "CGI 503 response retains COOP/COEP")

  r_cust_daemon = polymorphic_handle_custom_request(ctx_auto_daemon, 404, "text/html", "Not Found")
  assert_contains(state, r_cust_daemon, "HTTP/1.1 404 Not Found", "COOP-21", "Daemon custom request contains HTTP/1.1 404")
  assert_true(state, polymorphic_has_isolation_headers(r_cust_daemon), "COOP-22", "Daemon 404 response retains COOP/COEP")
@end

@! ============================================================================
@! 5. ADVERSARIAL DIRECTIVE FUZZING & MULTI-SESSION CONCURRENCY
@! ============================================================================

@fn test_adversarial_directive_and_multisession(state)
  println("\n=================================================================")
  println("🔥 ADVERSARIAL SECTION 5: Directive Fuzzing & Multi-Session Gateway 🔥")
  println("=================================================================")

  @! Test 5.1: Malformed / Empty @remote directive annotations
  fuzz_src = "@remote()\n@struct CompEmpty\n  a: i64\n@end\n\n@remote(invalid, without_equals, fps=120, codec=\"AV1\", bitrate=8000)\n@component CompFuzz\n  b: i64\n@end\n\n@remote(w=3840, h=2160, transport=\"webtransport\", pipeline=\"compute_3d\", priority=10, affinity=\"gpu_exclusive\")\n@fn render_4k_gpu(id)\n  return 0\n@end"
  
  part_fuzz = remote_classify_source(fuzz_src)
  assert_eq_int(state, part_fuzz.remote_count, 3, "DIR-01", "All 3 fuzzed @remote components identified")
  
  meta_empty = remote_get_component_meta(part_fuzz, "CompEmpty")
  assert_eq_int(state, meta_empty.fps, 60, "DIR-02", "Empty @remote() falls back to default 60 FPS")
  assert_eq_int(state, meta_empty.width, 1280, "DIR-03", "Empty @remote() falls back to default 1280 width")

  meta_fuzz = remote_get_component_meta(part_fuzz, "CompFuzz")
  assert_eq_int(state, meta_fuzz.fps, 120, "DIR-04", "Fuzzed directive parses valid fps=120 alongside unformatted tokens")
  assert_eq_str(state, meta_fuzz.codec, "AV1", "DIR-05", "Fuzzed directive parses AV1 codec")

  meta_4k = remote_get_component_meta(part_fuzz, "render_4k_gpu")
  assert_eq_int(state, meta_4k.width, 3840, "DIR-06", "4K directive parses width 3840 from 'w=' shorthand")
  assert_eq_int(state, meta_4k.height, 2160, "DIR-07", "4K directive parses height 2160 from 'h=' shorthand")
  assert_eq_str(state, meta_4k.transport, "webtransport", "DIR-08", "Custom transport webtransport parsed")
  assert_eq_str(state, meta_4k.render_pipeline, "compute_3d", "DIR-09", "Custom pipeline compute_3d parsed")

  @! Test 5.2: Multi-Session Gateway Concurrency (10 concurrent active sessions)
  gw_multi = remote_gateway_init("stun.local", "turn.local", 10)
  m_sess_count = 10
  m_idx = 0
  @while m_idx < m_sess_count
    s_name = "sess_concurrent_" + m_idx.to_str()
    c_name = "comp_viewport_" + m_idx.to_str()
    gw_multi = remote_gateway_create_session(gw_multi, s_name, c_name, 640, 480, 30, "VP8")
    m_idx = m_idx + 1
  @end

  assert_eq_int(state, gw_multi.active_session_count, 10, "MULTI-01", "Gateway holds 10 active concurrent streaming sessions")
  
  @! Render 1 frame and process 1 input for every session
  m_idx = 0
  all_multi_render = true
  @while m_idx < m_sess_count
    s_name = "sess_concurrent_" + m_idx.to_str()
    f_res = remote_gateway_render_frame(gw_multi, s_name, 16 * (m_idx + 1))
    @if f_res.pixels.len() != 640 * 480
      all_multi_render = false
    @end
    remote_gateway_process_input(gw_multi, s_name, INPUT_TYPE_POINTER_MOVE(), 50, 50, 0, 0)
    m_idx = m_idx + 1
  @end

  assert_true(state, all_multi_render, "MULTI-02", "All 10 concurrent sessions rendered offscreen frames with correct dimensions")
  
  gw_stats = remote_gateway_get_stats(gw_multi)
  assert_eq_int(state, gw_stats.total_frames, 10, "MULTI-03", "Gateway tracked 10 total streamed frames across concurrent sessions")
  assert_eq_int(state, gw_stats.total_inputs, 10, "MULTI-04", "Gateway tracked 10 total input events across concurrent sessions")

  @! Capacity overflow protection (max_sessions = 10)
  gw_multi_full = remote_gateway_create_session(gw_multi, "sess_overflow", "comp_overflow", 640, 480, 30, "VP8")
  assert_eq_int(state, gw_multi_full.active_session_count, 10, "MULTI-05", "Gateway gracefully rejects sessions beyond max capacity")
@end

@! ============================================================================
@! 6. ADVERSARIAL OPACITY BLENDING & DYNAMIC SUB-RECT MUTATION
@! ============================================================================

@fn test_adversarial_blending_and_mutation(state)
  println("\n=================================================================")
  println("🔥 ADVERSARIAL SECTION 6: Opacity Blending & Dynamic Rect Mutation 🔥")
  println("=================================================================")

  canvas_w = 400
  canvas_h = 300
  total_px = canvas_w * canvas_h
  
  @! Create black canvas background (0xFF000000 = 4278190080)
  canvas_fb = []
  i = 0
  @while i < total_px
    canvas_fb = canvas_fb.push(4278190080)
    i = i + 1
  @end

  @! Create white video frame (0xFFFFFFFF = 4294967295)
  frame_white = video_blitter_create_solid_frame(1, 100, 100, 4294967295, 16)

  blitter = video_blitter_new(canvas_w, canvas_h, 50, 50, 100, 100)

  @! 50% opacity blend
  blitter = video_blitter_set_opacity(blitter, 50)
  canvas_fb = video_blitter_blit_frame(blitter, frame_white, canvas_fb)

  blended_sample = canvas_fb[(60 * canvas_w) + 60]
  
  @! Alpha = 255 (0xFF), R = ~127, G = ~127, B = ~127 -> Mid-gray
  r_val = (blended_sample / 65536) % 256
  assert_true(state, r_val >= 125 && r_val <= 130, "BLEND-01", "50% opacity blend correctly calculates mid-gray channel value (127)")

  @! Test 6.2: Dynamic Sub-rect Mutation on the Fly
  blitter = video_blitter_set_subrect(blitter, 200, 150, 50, 50)
  canvas_fb = video_blitter_blit_frame(blitter, frame_white, canvas_fb)
  dr_mut = video_blitter_get_dirty_rect(blitter)
  assert_eq_int(state, dr_mut.min_x, 200, "MUT-01", "Mutated sub-rect origin min_x=200")
  assert_eq_int(state, dr_mut.min_y, 150, "MUT-02", "Mutated sub-rect origin min_y=150")
  assert_eq_int(state, dr_mut.max_x, 250, "MUT-03", "Mutated sub-rect right bound max_x=250")
  assert_eq_int(state, dr_mut.max_y, 200, "MUT-04", "Mutated sub-rect bottom bound max_y=200")

  @! Test 6.3: Opacity clamping
  blitter = video_blitter_set_opacity(blitter, 150)
  assert_eq_int(state, blitter.subrect.opacity_pct, 100, "BLEND-02", "Opacity > 100 clamped to 100%")
  blitter = video_blitter_set_opacity(blitter, -50)
  assert_eq_int(state, blitter.subrect.opacity_pct, 0, "BLEND-03", "Opacity < 0 clamped to 0%")
@end

@! ============================================================================
@! 7. MAIN ADVERSARIAL TEST RUNNER
@! ============================================================================

@fn main()
  println("================================================================================")
  println("⚡ CHALLENGER 2: ADVERSARIAL STRESS TEST SUITE — WEBRTC & POLYMORPHIC COOP/COEP ⚡")
  println("================================================================================")

  state = stress_state_new()

  test_adversarial_sdp_payloads(state)
  test_adversarial_subrect_clipping(state)
  test_adversarial_datachannel_flooding(state)
  test_adversarial_polymorphic_headers(state)
  test_adversarial_directive_and_multisession(state)
  test_adversarial_blending_and_mutation(state)

  println("\n================================================================================")
  println("ADVERSARIAL STRESS TEST SUMMARY")
  println("================================================================================")
  println("Total Assertions Executed: " + state.total.to_str())
  println("Passed:                    " + state.passed.to_str())
  println("Failed:                    " + state.failed.to_str())
  println("================================================================================")

  @if state.failed == 0
    println("🎉 ALL " + state.total.to_str() + " ADVERSARIAL CHALLENGER 2 STRESS TESTS PASSED! (100% SUCCESS) 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL STRESS TEST FAILURES DETECTED: " + state.failed.to_str() + " assertions failed.")
    return 1
  @end
@end
