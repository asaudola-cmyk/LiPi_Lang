// ==============================================================================
// 👑 LIPI UNIVERSE NET: RFC 9114 HTTP/3 & RFC 9204 QPACK PROTOCOL STACK
// Module: utso/net/http3.lp
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Direct QUIC Integration
//
// WHY: HTTP/3 over QUIC eliminates Head-of-Line blocking inherent in TCP,
//      enabling multiplexed zero-RTT connection establishment, independent stream
//      transmission, and sovereign next-generation cloud infrastructure.
//
// Protocol Invariants (RFC 9114 & RFC 9204):
// 1. Variable-Length Integer Encoding: RFC 9000 varint format (2-bit prefix: 1, 2, 4, 8 bytes).
// 2. HTTP/3 Frames: DATA (0x00), HEADERS (0x01), SETTINGS (0x04), GOAWAY (0x07).
// 3. Unidirectional Control & QPACK Streams: Stream Type negotiation ahead of frames.
// 4. QPACK Static Table Decoder: In-process RFC 9204 static field resolution.
// ==============================================================================

include "utso/core/io.lp"
include "utso/core/memory.lp"
include "utso/core/string.lp"

// ── 1. HTTP/3 Frame Types (RFC 9114 Section 7.2) ──────────────────────────────
H3_FRAME_DATA             = 0           // 0x00
H3_FRAME_HEADERS          = 1           // 0x01
H3_FRAME_CANCEL_PUSH      = 3           // 0x03
H3_FRAME_SETTINGS         = 4           // 0x04
H3_FRAME_PUSH_PROMISE     = 5           // 0x05
H3_FRAME_GOAWAY           = 7           // 0x07
H3_FRAME_MAX_PUSH_ID      = 13          // 0x0D

// HTTP/3 Settings Identifiers (RFC 9114 Section 7.2.4.1)
H3_SETTING_QPACK_MAX_TABLE_CAPACITY = 1 // 0x01
H3_SETTING_MAX_FIELD_SECTION_SIZE   = 6 // 0x06
H3_SETTING_QPACK_BLOCKED_STREAMS    = 7 // 0x07

// Unidirectional Stream Types (RFC 9114 Section 6.2)
H3_STREAM_CONTROL         = 0           // 0x00
H3_STREAM_PUSH            = 1           // 0x01
H3_STREAM_QPACK_ENCODER   = 2           // 0x02
H3_STREAM_QPACK_DECODER   = 3           // 0x03

// ── 2. Data Models (Hardware Aligned) ─────────────────────────────────────────

struct H3Frame
    hf_type            // Frame Type (0=DATA, 1=HEADERS, 4=SETTINGS, etc.)
    hf_length          // Payload length in bytes
    hf_payload_bytes   // list of integer byte values
    hf_stream_id       // Associated QUIC Stream ID

struct H3Settings
    hs_qpack_max_table_capacity
    hs_max_field_section_size
    hs_qpack_blocked_streams

struct H3HeaderField
    hh_name            // String name (e.g. ":method", ":path", "content-type")
    hh_value           // String value (e.g. "GET", "/", "text/html")

struct H3Request
    hr_stream_id
    hr_method
    hr_path
    hr_scheme
    hr_authority
    hr_status
    hr_headers         // list of H3HeaderField
    hr_body            // raw body string

struct H3Server
    srv_port
    srv_local_settings
    srv_peer_settings
    srv_active_streams
    srv_is_listening

// ── 3. QUIC Variable-Length Integer (Varint) Codec ────────────────────────────

fn h3_varint_len first_byte
    // Bits 7-6 indicate varint byte width:
    // 00 -> 1 byte (0..63)
    // 01 -> 2 bytes (0..16383)
    // 10 -> 4 bytes (0..1073741823)
    // 11 -> 8 bytes (0..4611686018427387903)
    prefix = (first_byte >> 6) & 3
    if prefix == 0 return 1
    if prefix == 1 return 2
    if prefix == 2 return 4
    return 8

fn h3_read_varint buf off buf_len
    if off >= buf_len return 0
    b0 = mem_byte_read(buf, off) & 255
    prefix = (b0 >> 6) & 3
    val = b0 & 63

    if prefix == 0
        return val

    if prefix == 1
        if (off + 1) >= buf_len return val
        b1 = mem_byte_read(buf, off + 1) & 255
        return (val * 256) + b1

    if prefix == 2
        if (off + 3) >= buf_len return val
        b1 = mem_byte_read(buf, off + 1) & 255
        b2 = mem_byte_read(buf, off + 2) & 255
        b3 = mem_byte_read(buf, off + 3) & 255
        return (val * 16777216) + (b1 * 65536) + (b2 * 256) + b3

    // 8-byte varint
    i = 1
    while i < 8 and (off + i) < buf_len
        bx = mem_byte_read(buf, off + i) & 255
        val = (val * 256) + bx
        i = i + 1
    return val

fn h3_write_varint out_list val
    // WHY: Emits minimal length QUIC varint into target byte list.
    if val < 64
        push(out_list, val)
        return 1
    if val < 16384
        // 2-byte with 01 prefix (0x40)
        push(out_list, 64 | ((val >> 8) & 63))
        push(out_list, val & 255)
        return 2
    if val < 1073741824
        // 4-byte with 10 prefix (0x80)
        push(out_list, 128 | ((val >> 24) & 63))
        push(out_list, (val >> 16) & 255)
        push(out_list, (val >> 8) & 255)
        push(out_list, val & 255)
        return 4
    // 8-byte with 11 prefix (0xC0)
    push(out_list, 192 | ((val >> 56) & 63))
    push(out_list, (val >> 48) & 255)
    push(out_list, (val >> 40) & 255)
    push(out_list, (val >> 32) & 255)
    push(out_list, (val >> 24) & 255)
    push(out_list, (val >> 16) & 255)
    push(out_list, (val >> 8) & 255)
    push(out_list, val & 255)
    return 8

// ── 4. HTTP/3 Frame Serialization ─────────────────────────────────────────────

fn h3_frame_new ftype payload_bytes stream_id
    hf = H3Frame()
    hf.hf_type = ftype
    hf.hf_length = len(payload_bytes)
    hf.hf_payload_bytes = payload_bytes
    hf.hf_stream_id = stream_id
    return hf

fn h3_serialize_frame hf out_list
    // WHY: Emits [Type Varint] [Length Varint] [Payload Bytes]
    h3_write_varint(out_list, hf.hf_type)
    h3_write_varint(out_list, hf.hf_length)
    i = 0
    cnt = hf.hf_length
    while i < cnt
        push(out_list, get(hf.hf_payload_bytes, i))
        i = i + 1
    return len(out_list)

fn h3_serialize_data_frame body_str stream_id out_list
    // WHY: Wraps user payload string directly into H3 DATA frame (Type 0x00).
    blen = len(body_str)
    h3_write_varint(out_list, H3_FRAME_DATA)
    h3_write_varint(out_list, blen)
    i = 0
    while i < blen
        push(out_list, ord(char_at(body_str, i)))
        i = i + 1
    return len(out_list)

fn h3_serialize_settings_frame settings stream_id out_list
    // WHY: Emits mandatory H3 SETTINGS frame (Type 0x04) on control stream.
    payload = list()
    // 1. QPACK Max Table Capacity
    h3_write_varint(payload, H3_SETTING_QPACK_MAX_TABLE_CAPACITY)
    h3_write_varint(payload, settings.hs_qpack_max_table_capacity)
    // 2. Max Field Section Size
    h3_write_varint(payload, H3_SETTING_MAX_FIELD_SECTION_SIZE)
    h3_write_varint(payload, settings.hs_max_field_section_size)
    // 3. QPACK Blocked Streams
    h3_write_varint(payload, H3_SETTING_QPACK_BLOCKED_STREAMS)
    h3_write_varint(payload, settings.hs_qpack_blocked_streams)

    h3_write_varint(out_list, H3_FRAME_SETTINGS)
    h3_write_varint(out_list, len(payload))
    i = 0
    cnt = len(payload)
    while i < cnt
        push(out_list, get(payload, i))
        i = i + 1
    return len(out_list)

// ── 5. QPACK Static Table Minimal Decoder (RFC 9204 Appendix A) ───────────────

fn qpack_static_lookup idx
    // Selected core entries from RFC 9204 99-entry static table:
    if idx == 0 return ":authority"
    if idx == 1 return ":path:/"
    if idx == 2 return "age:0"
    if idx == 3 return "content-disposition"
    if idx == 4 return "content-length:0"
    if idx == 5 return "cookie"
    if idx == 6 return "date"
    if idx == 7 return "etag"
    if idx == 8 return "if-modified-since"
    if idx == 9 return "if-none-match"
    if idx == 10 return "last-modified"
    if idx == 11 return "link"
    if idx == 12 return "location"
    if idx == 13 return "referer"
    if idx == 14 return "set-cookie"
    if idx == 15 return ":method:CONNECT"
    if idx == 16 return ":method:DELETE"
    if idx == 17 return ":method:GET"
    if idx == 18 return ":method:HEAD"
    if idx == 19 return ":method:OPTIONS"
    if idx == 20 return ":method:POST"
    if idx == 21 return ":method:PUT"
    if idx == 22 return ":scheme:http"
    if idx == 23 return ":scheme:https"
    if idx == 24 return ":status:200"
    if idx == 25 return ":status:204"
    if idx == 26 return ":status:304"
    if idx == 27 return ":status:400"
    if idx == 28 return ":status:404"
    if idx == 29 return ":status:500"
    if idx == 30 return "accept:*/*"
    if idx == 31 return "accept-encoding:gzip, deflate, br"
    if idx == 32 return "accept-ranges:bytes"
    if idx == 33 return "access-control-allow-headers:cache-control"
    if idx == 34 return "access-control-allow-headers:content-type"
    if idx == 35 return "access-control-allow-origin:*"
    if idx == 36 return "content-length:0"
    if idx == 37 return "content-type:application/json"
    if idx == 38 return "content-type:text/html; charset=utf-8"
    if idx == 39 return "content-type:text/plain"
    if idx == 40 return "content-type:text/plain;charset=utf-8"
    if idx == 41 return "cache-control:max-age=0"
    if idx == 42 return "cache-control:no-cache"
    if idx == 43 return "cache-control:no-store"
    if idx == 44 return "content-encoding:gzip"
    if idx == 45 return "content-encoding:br"
    if idx == 46 return "server:lipi"
    return ""

fn h3_header_field_new name val
    hf = H3HeaderField()
    hf.hh_name = name
    hf.hh_value = val
    return hf

// ── 6. Request Parser & Response Generator ────────────────────────────────────

fn h3_request_new stream_id
    req = H3Request()
    req.hr_stream_id = stream_id
    req.hr_method = "GET"
    req.hr_path = "/"
    req.hr_scheme = "https"
    req.hr_authority = "localhost"
    req.hr_status = 200
    req.hr_headers = list()
    req.hr_body = ""
    return req

fn h3_serialize_headers_frame status_code content_type stream_id out_list
    // WHY: Emits RFC 9114 HEADERS frame (Type 0x01) with RFC 9204 QPACK field block.
    // Encoded field section prefix (RFC 9204 Section 4.5.1):
    // Required Insert Count = 0 (1 byte: 0x00)
    // Base = 0, S bit = 0 (1 byte: 0x00)
    payload = list()
    push(payload, 0)
    push(payload, 0)

    // 1. Status Code: Indexed static table entry (RFC 9204 Section 4.5.2)
    // Pattern: 1 T Index (T=1 static -> 192 | index)
    if status_code == 200
        push(payload, 192 | 24) // :status:200
    elif status_code == 204
        push(payload, 192 | 25) // :status:204
    elif status_code == 404
        push(payload, 192 | 28) // :status:404
    elif status_code == 500
        push(payload, 192 | 29) // :status:500
    else
        // Literal field with literal name ":status" (Pattern: 00100000 = 32)
        push(payload, 32)
        push(payload, 7) // name len = 7
        push(payload, 58) // ':'
        push(payload, 115) // 's'
        push(payload, 116) // 't'
        push(payload, 97) // 'a'
        push(payload, 116) // 't'
        push(payload, 117) // 'u'
        push(payload, 115) // 's'
        s_str = to_str(status_code)
        push(payload, len(s_str))
        si = 0
        while si < len(s_str)
            push(payload, ord(char_at(s_str, si)))
            si = si + 1
        end
    end

    // 2. Content-Type Header
    if content_type == "application/json"
        push(payload, 192 | 37) // content-type:application/json
    elif content_type == "text/html; charset=utf-8"
        push(payload, 192 | 38) // content-type:text/html; charset=utf-8
    elif content_type == "text/plain"
        push(payload, 192 | 39) // content-type:text/plain
    elif len(content_type) > 0
        // Literal with literal name "content-type"
        push(payload, 32)
        ct_hdr = "content-type"
        push(payload, len(ct_hdr))
        ci = 0
        while ci < len(ct_hdr)
            push(payload, ord(char_at(ct_hdr, ci)))
            ci = ci + 1
        end
        push(payload, len(content_type))
        vi = 0
        while vi < len(content_type)
            push(payload, ord(char_at(content_type, vi)))
            vi = vi + 1
        end
    end

    // Serialize HEADERS frame: [Type 0x01] [Length] [Payload]
    h3_write_varint(out_list, H3_FRAME_HEADERS)
    h3_write_varint(out_list, len(payload))
    pi = 0
    while pi < len(payload)
        push(out_list, get(payload, pi))
        pi = pi + 1
    end
    return len(out_list)

fn h3_build_response_bytes status_code content_type body_str out_bytes
    // WHY: Formulates complete HTTP/3 response containing RFC 9114 HEADERS frame followed by DATA frame.
    // 1. HEADERS frame (RFC 9114 Section 7.2.2)
    h3_serialize_headers_frame(status_code, content_type, 0, out_bytes)

    // 2. DATA frame (RFC 9114 Section 7.2.1)
    if len(body_str) > 0
        h3_serialize_data_frame(body_str, 0, out_bytes)
    end
    return len(out_bytes)
