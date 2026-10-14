// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Sovereign gRPC & Protobuf Protocol Unit Test
// ==============================================================================

include "packages/lipi_grpc/src/grpc.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI gRPC: BINARY WIRE & PROTOBUF ENGINE TEST 👑"
say "================================================================="

// ── ১. Varint এনকোডিং ও ডিকোডিং পরীক্ষা ──
v_buf = sys_alloc(32)
mem_zero(v_buf, 32)
meta = sys_alloc(24)

// Value 0
len0 = grpc_varint_encode(v_buf, 0, 0)
assert_eq(len0, 1, "Varint 0 takes 1 byte")
dec0 = grpc_varint_decode(v_buf, 0, meta)
assert_eq(dec0, 0, "Decoded varint 0 matches")
assert_eq(mem_read(meta, 8), 1, "Consumed 1 byte for 0")

// Value 300 (0x12C -> 0xAC 0x02)
len300 = grpc_varint_encode(v_buf, 0, 300)
assert_eq(len300, 2, "Varint 300 takes 2 bytes")
dec300 = grpc_varint_decode(v_buf, 0, meta)
assert_eq(dec300, 300, "Decoded varint 300 matches")
assert_eq(mem_read(meta, 8), 2, "Consumed 2 bytes for 300")

// Value 1,000,000
len1m = grpc_varint_encode(v_buf, 0, 1000000)
assert_eq(len1m, 3, "Varint 1,000,000 takes 3 bytes")
dec1m = grpc_varint_decode(v_buf, 0, meta)
assert_eq(dec1m, 1000000, "Decoded varint 1,000,000 matches")
assert_eq(mem_read(meta, 8), 3, "Consumed 3 bytes for 1,000,000")

// ── ২. Protobuf ফিল্ড ট্যাগ এনকোডিং ও ডিকোডিং পরীক্ষা ──
// Field 1, VARINT (0) -> (1 * 8) + 0 = 8
tag1_len = grpc_tag_encode(v_buf, 0, 1, GRPC_WIRE_VARINT)
assert_eq(tag1_len, 1, "Tag for field 1 (varint) is 1 byte")
f1 = grpc_tag_decode(v_buf, 0, meta)
assert_eq(f1, 1, "Decoded field number is 1")
assert_eq(mem_read(meta, 8), GRPC_WIRE_VARINT, "Decoded wire type is VARINT (0)")

// Field 2, LENGTH_DELIMITED (2) -> (2 * 8) + 2 = 18
tag2_len = grpc_tag_encode(v_buf, 0, 2, GRPC_WIRE_LENGTH_DELIMITED)
assert_eq(tag2_len, 1, "Tag for field 2 (len-delimited) is 1 byte")
f2 = grpc_tag_decode(v_buf, 0, meta)
assert_eq(f2, 2, "Decoded field number is 2")
assert_eq(mem_read(meta, 8), GRPC_WIRE_LENGTH_DELIMITED, "Decoded wire type is LENGTH_DELIMITED (2)")

// ── ৩. ফিল্ড সিরিয়ালাইজেশন (Field Serialization) ──
msg_buf = sys_alloc(64)
mem_zero(msg_buf, 64)

// Write field 1 = 8888
w1 = grpc_write_int64(msg_buf, 0, 1, 8888)
assert_true(w1 > 0, "Field 1 serialized")

// ── ৪. gRPC ৫-বাইট লেন্থ-প্রিফিক্সড ফ্রেম পরীক্ষা (5-Byte Framing) ──
// Create payload: 10 bytes
raw_payload = sys_alloc(10)
mem_fill(raw_payload, 65, 10) // Ten 'A's

frame_buf = sys_alloc(32)
mem_zero(frame_buf, 32)

framed_len = grpc_frame_message(frame_buf, raw_payload, 10)
assert_eq(framed_len, 15, "Framed gRPC message length is 15 (5 + 10)")

// Check Byte 0: compression flag (0)
assert_eq(mem_byte_read(frame_buf, 0), 0, "Frame compression flag is 0")

// Check Byte 4: length is 10
assert_eq(mem_byte_read(frame_buf, 4), 10, "Frame length least-significant byte is 10")

// Unframe message
unframe_meta = sys_alloc(24)
extracted_len = grpc_unframe_message(frame_buf, framed_len, unframe_meta)
assert_eq(extracted_len, 10, "Unframed payload length is 10")
assert_eq(mem_read(unframe_meta, 0), 0, "Unframed compression flag is 0")
assert_eq(mem_read(unframe_meta, 8), 10, "Unframed metadata payload length is 10")

p_ptr = mem_read(unframe_meta, 16)
assert_eq(mem_byte_read(p_ptr, 0), 65, "First payload byte is 'A'")
assert_eq(mem_byte_read(p_ptr, 9), 65, "Tenth payload byte is 'A'")

// ── ৫. স্ট্যাটাস কোড কনস্ট্যান্টস যাচাই ──
assert_eq(GRPC_STATUS_OK, 0, "GRPC_STATUS_OK is 0")
assert_eq(GRPC_STATUS_NOT_FOUND, 5, "GRPC_STATUS_NOT_FOUND is 5")
assert_eq(GRPC_STATUS_UNAUTHENTICATED, 16, "GRPC_STATUS_UNAUTHENTICATED is 16")

mem_free(v_buf, 32)
mem_free(meta, 24)
mem_free(msg_buf, 64)
mem_free(raw_payload, 10)
mem_free(frame_buf, 32)
mem_free(unframe_meta, 24)

say "🎉 ALL SOVEREIGN gRPC & PROTOBUF TESTS PASSED!"
