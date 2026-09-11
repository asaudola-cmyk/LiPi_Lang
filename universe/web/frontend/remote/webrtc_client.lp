@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/remote/webrtc_client.maya
@! Milestone: M5 — Adaptive WebRTC Hybrid Rendering
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features: WebRTC Client Peer Connection, SDP Negotiation,
@! ICE Candidate Handshake, DataChannel Interaction & MediaStream Tracking
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. CONSTANTS & ENUMS
@! ============================================================================

@! PeerConnection States
@fn PEER_STATE_NEW() return 0 @end
@fn PEER_STATE_CONNECTING() return 1 @end
@fn PEER_STATE_CONNECTED() return 2 @end
@fn PEER_STATE_STREAMING() return 3 @end
@fn PEER_STATE_DISCONNECTED() return 4 @end
@fn PEER_STATE_FAILED() return 5 @end
@fn PEER_STATE_CLOSED() return 6 @end

@! Signaling States
@fn SIGNALING_STABLE() return 0 @end
@fn SIGNALING_HAVE_LOCAL_OFFER() return 1 @end
@fn SIGNALING_HAVE_REMOTE_OFFER() return 2 @end
@fn SIGNALING_HAVE_LOCAL_PRANSWER() return 3 @end
@fn SIGNALING_HAVE_REMOTE_PRANSWER() return 4 @end
@fn SIGNALING_CLOSED() return 5 @end

@! ICE Connection States
@fn ICE_STATE_NEW() return 0 @end
@fn ICE_STATE_CHECKING() return 1 @end
@fn ICE_STATE_CONNECTED() return 2 @end
@fn ICE_STATE_COMPLETED() return 3 @end
@fn ICE_STATE_FAILED() return 4 @end
@fn ICE_STATE_DISCONNECTED() return 5 @end
@fn ICE_STATE_CLOSED() return 6 @end

@! Input Event Type Codes
@fn INPUT_TYPE_POINTER_DOWN() return 1 @end
@fn INPUT_TYPE_POINTER_UP() return 2 @end
@fn INPUT_TYPE_POINTER_MOVE() return 3 @end
@fn INPUT_TYPE_KEY_DOWN() return 4 @end
@fn INPUT_TYPE_KEY_UP() return 5 @end
@fn INPUT_TYPE_WHEEL() return 6 @end
@fn INPUT_TYPE_RESIZE() return 7 @end

@! ============================================================================
@! 2. DATA STRUCTURES
@! ============================================================================

@struct IceCandidate
  candidate_str: string
  sdp_mid: string
  sdp_mline_index: i64
  protocol: string
  ip: string
  port: i64
  cand_type: string
@end

@struct MediaTrack
  track_id: string
  kind: string                 @! "video", "audio"
  enabled: bool
  muted: bool
  width: i64
  height: i64
  frame_rate: i64
  total_frames_received: i64
  ready_state: string           @! "live", "ended"
@end

@struct DataChannel
  id: i64
  label: string
  ordered: bool
  state: string                @! "connecting", "open", "closing", "closed"
  buffered_amount: i64
  messages_sent: i64
  bytes_sent: i64
  messages_received: i64
  bytes_received: i64
  sent_queue: array
  received_queue: array
@end

@struct WebRtcClientStats
  rtt_ms: i64
  jitter_ms: i64
  packets_received: i64
  packets_lost: i64
  bytes_received: i64
  frames_decoded: i64
  frames_dropped: i64
  bitrate_kbps: i64
@end

@struct WebRtcPeerClient
  session_id: string
  component_id: string
  peer_state: i64
  signaling_state: i64
  ice_state: i64
  local_sdp: string
  remote_sdp: string
  local_ice_candidates: array
  remote_ice_candidates: array
  data_channels: array
  media_tracks: array
  stats: WebRtcClientStats
  config_stun_server: string
  config_turn_server: string
  last_error: string
@end

@! ============================================================================
@! 3. CONSTRUCTOR & INITIALIZATION
@! ============================================================================

@fn webrtc_client_new(session_id, component_id, stun_server, turn_server)
  init_stats = {
    rtt_ms: 0,
    jitter_ms: 0,
    packets_received: 0,
    packets_lost: 0,
    bytes_received: 0,
    frames_decoded: 0,
    frames_dropped: 0,
    bitrate_kbps: 0
  }

  return {
    session_id: session_id,
    component_id: component_id,
    peer_state: PEER_STATE_NEW(),
    signaling_state: SIGNALING_STABLE(),
    ice_state: ICE_STATE_NEW(),
    local_sdp: "",
    remote_sdp: "",
    local_ice_candidates: [],
    remote_ice_candidates: [],
    data_channels: [],
    media_tracks: [],
    stats: init_stats,
    config_stun_server: stun_server,
    config_turn_server: turn_server,
    last_error: ""
  }
@end

@! ============================================================================
@! 4. DATACHANNEL MANAGEMENT
@! ============================================================================

@fn webrtc_create_data_channel(client, label, ordered)
  next_id = client.data_channels.len()
  dc = {
    id: next_id,
    label: label,
    ordered: ordered,
    state: "open",
    buffered_amount: 0,
    messages_sent: 0,
    bytes_sent: 0,
    messages_received: 0,
    bytes_received: 0,
    sent_queue: [],
    received_queue: []
  }
  client.data_channels = client.data_channels.push(dc)
  return client
@end

@fn webrtc_get_data_channel(client, label)
  i = 0
  @while i < client.data_channels.len()
    dc = client.data_channels[i]
    @if dc.label == label
      return dc
    @end
    i = i + 1
  @end
  
  return {
    id: -1,
    label: "none",
    ordered: false,
    state: "closed",
    buffered_amount: 0,
    messages_sent: 0,
    bytes_sent: 0,
    messages_received: 0,
    bytes_received: 0,
    sent_queue: [],
    received_queue: []
  }
@end

@fn webrtc_send_data(client, channel_label, payload)
  i = 0
  @while i < client.data_channels.len()
    dc = client.data_channels[i]
    @if dc.label == channel_label && dc.state == "open"
      dc.messages_sent = dc.messages_sent + 1
      dc.bytes_sent = dc.bytes_sent + str_len(payload)
      dc.sent_queue = dc.sent_queue.push(payload)
      client.data_channels[i] = dc
      return true
    @end
    i = i + 1
  @end
  return false
@end

@fn webrtc_receive_data(client, channel_label, payload)
  i = 0
  @while i < client.data_channels.len()
    dc = client.data_channels[i]
    @if dc.label == channel_label && dc.state == "open"
      dc.messages_received = dc.messages_received + 1
      dc.bytes_received = dc.bytes_received + str_len(payload)
      dc.received_queue = dc.received_queue.push(payload)
      client.data_channels[i] = dc
      return true
    @end
    i = i + 1
  @end
  return false
@end

@fn webrtc_send_input_event(client, event_type, x, y, key_code, modifiers)
  payload = "EVENT:" + event_type.to_str() + "," + x.to_str() + "," + y.to_str() + "," + key_code.to_str() + "," + modifiers.to_str()
  return webrtc_send_data(client, "user_input", payload)
@end

@! ============================================================================
@! 5. MEDIA TRACK MANAGEMENT
@! ============================================================================

@fn webrtc_attach_track(client, track_id, kind, width, height, fps)
  track = {
    track_id: track_id,
    kind: kind,
    enabled: true,
    muted: false,
    width: width,
    height: height,
    frame_rate: fps,
    total_frames_received: 0,
    ready_state: "live"
  }
  client.media_tracks = client.media_tracks.push(track)
  return client
@end

@fn webrtc_get_video_track(client)
  i = 0
  @while i < client.media_tracks.len()
    t = client.media_tracks[i]
    @if t.kind == "video"
      return t
    @end
    i = i + 1
  @end
  return {
    track_id: "none",
    kind: "none",
    enabled: false,
    muted: true,
    width: 0,
    height: 0,
    frame_rate: 0,
    total_frames_received: 0,
    ready_state: "ended"
  }
@end

@! ============================================================================
@! 6. SDP OFFER CREATION & NEGOTIATION
@! ============================================================================

@fn webrtc_create_offer(client, width, height, fps, codec)
  codec_upper = str_to_upper(codec)
  pt = 96
  @if codec_upper == "VP8" pt = 96
  @elif codec_upper == "VP9" pt = 98
  @elif codec_upper == "H264" pt = 100
  @elif codec_upper == "AV1" pt = 102
  @end

  sdp = "v=0\r\n"
  sdp = sdp + "o=- " + client.session_id + " 2 IN IP4 127.0.0.1\r\n"
  sdp = sdp + "s=Lipi WebRTC Hybrid Streaming\r\n"
  sdp = sdp + "t=0 0\r\n"
  sdp = sdp + "a=group:BUNDLE 0 1\r\n"
  sdp = sdp + "m=video 9 UDP/TLS/RTP/SAVPF " + pt.to_str() + "\r\n"
  sdp = sdp + "c=IN IP4 0.0.0.0\r\n"
  sdp = sdp + "a=rtcp:9 IN IP4 0.0.0.0\r\n"
  sdp = sdp + "a=rtpmap:" + pt.to_str() + " " + codec_upper + "/90000\r\n"
  sdp = sdp + "a=fmtp:" + pt.to_str() + " width=" + width.to_str() + ";height=" + height.to_str() + ";fps=" + fps.to_str() + "\r\n"
  sdp = sdp + "a=sendrecv\r\n"
  sdp = sdp + "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n"
  sdp = sdp + "c=IN IP4 0.0.0.0\r\n"
  sdp = sdp + "a=sctp-port:5000\r\n"
  
  client.local_sdp = sdp
  client.signaling_state = SIGNALING_HAVE_LOCAL_OFFER()
  client.peer_state = PEER_STATE_CONNECTING()
  return sdp
@end

@fn webrtc_set_local_description(client, sdp_offer)
  client.local_sdp = sdp_offer
  client.signaling_state = SIGNALING_HAVE_LOCAL_OFFER()
  @if client.peer_state == PEER_STATE_NEW()
    client.peer_state = PEER_STATE_CONNECTING()
  @end
  return client
@end

@fn webrtc_set_remote_description(client, sdp_answer)
  @if str_len(sdp_answer) == 0
    client.last_error = "Empty SDP answer received"
    client.peer_state = PEER_STATE_FAILED()
    return client
  @end

  client.remote_sdp = sdp_answer
  client.signaling_state = SIGNALING_STABLE()
  client.peer_state = PEER_STATE_CONNECTED()
  client.ice_state = ICE_STATE_CONNECTED()
  return client
@end

@! ============================================================================
@! 7. ICE CANDIDATE HANDLING
@! ============================================================================

@fn webrtc_create_local_candidate(client, ip, port, cand_type)
  cand_str = "candidate:maya" + client.local_ice_candidates.len().to_str() + " 1 udp 2122260223 " + ip + " " + port.to_str() + " typ " + cand_type + " generation 0"
  c = {
    candidate_str: cand_str,
    sdp_mid: "0",
    sdp_mline_index: 0,
    protocol: "udp",
    ip: ip,
    port: port,
    cand_type: cand_type
  }
  client.local_ice_candidates = client.local_ice_candidates.push(c)
  return c
@end

@fn webrtc_add_ice_candidate(client, candidate_obj)
  client.remote_ice_candidates = client.remote_ice_candidates.push(candidate_obj)
  @if client.peer_state == PEER_STATE_CONNECTED()
    client.peer_state = PEER_STATE_STREAMING()
    client.ice_state = ICE_STATE_COMPLETED()
  @end
  return client
@end

@! ============================================================================
@! 8. STATS & TELEMETRY
@! ============================================================================

@fn webrtc_update_stats(client, rtt_ms, jitter_ms, packets_rx, packets_lost, frames_dec, frames_drop, bitrate)
  client.stats.rtt_ms = rtt_ms
  client.stats.jitter_ms = jitter_ms
  client.stats.packets_received = client.stats.packets_received + packets_rx
  client.stats.packets_lost = client.stats.packets_lost + packets_lost
  client.stats.frames_decoded = client.stats.frames_decoded + frames_dec
  client.stats.frames_dropped = client.stats.frames_dropped + frames_drop
  client.stats.bitrate_kbps = bitrate
  return client
@end

@fn webrtc_build_signal_request_json(client, msg_type)
  sdp_escaped = str_replace(client.local_sdp, "\r\n", "\\r\\n")
  sdp_escaped = str_replace(sdp_escaped, "\"", "\\\"")
  
  json = "{\"session_id\":\"" + client.session_id + "\","
  json = json + "\"component_id\":\"" + client.component_id + "\","
  json = json + "\"type\":\"" + msg_type + "\","
  json = json + "\"sdp\":\"" + sdp_escaped + "\"}"
  return json
@end

@fn webrtc_close(client)
  client.peer_state = PEER_STATE_CLOSED()
  client.signaling_state = SIGNALING_CLOSED()
  client.ice_state = ICE_STATE_CLOSED()
  
  i = 0
  @while i < client.data_channels.len()
    dc = client.data_channels[i]
    dc.state = "closed"
    client.data_channels[i] = dc
    i = i + 1
  @end

  j = 0
  @while j < client.media_tracks.len()
    mt = client.media_tracks[j]
    mt.ready_state = "ended"
    mt.enabled = false
    client.media_tracks[j] = mt
    j = j + 1
  @end
  
  return client
@end
