// ==============================================================================
// 👑 LIPI SOVEREIGN gRPC & PROTOBUF PROTOCOL ENGINE (packages/lipi_grpc/src/grpc.lp)
// ⚡ Zero Libc | Zero Protoc | Sovereign Binary Wire Framing & Varint Engine
// ==============================================================================
//
// WHY: Enterprise microservices, Kubernetes control planes, and distributed databases
// communicate using binary gRPC frames and Protobuf serialization.
// lipi_grpc provides zero-dependency wire serialization, varint encoding/decoding,
// length-delimited byte framing, and RFC-compliant 5-byte gRPC message envelopes.

include "universe/core/memory.lp"

// Protobuf Wire Type Enums
GRPC_WIRE_VARINT           = 0
GRPC_WIRE_FIXED64          = 1
GRPC_WIRE_LENGTH_DELIMITED = 2
GRPC_WIRE_FIXED32          = 5

// gRPC Canonical Status Codes (RFC / Google gRPC Core)
GRPC_STATUS_OK                  = 0
GRPC_STATUS_CANCELLED           = 1
GRPC_STATUS_UNKNOWN             = 2
GRPC_STATUS_INVALID_ARGUMENT    = 3
GRPC_STATUS_DEADLINE_EXCEEDED   = 4
GRPC_STATUS_NOT_FOUND           = 5
GRPC_STATUS_ALREADY_EXISTS      = 6
GRPC_STATUS_PERMISSION_DENIED   = 7
GRPC_STATUS_RESOURCE_EXHAUSTED  = 8
GRPC_STATUS_FAILED_PRECONDITION = 9
GRPC_STATUS_ABORTED             = 10
GRPC_STATUS_OUT_OF_RANGE        = 11
GRPC_STATUS_UNIMPLEMENTED       = 12
GRPC_STATUS_INTERNAL            = 13
GRPC_STATUS_UNAVAILABLE         = 14
GRPC_STATUS_DATA_LOSS           = 15
GRPC_STATUS_UNAUTHENTICATED     = 16

// Encodes a 64-bit unsigned integer using Variable-Byte (Varint) encoding.
// 7 bits payload per byte, MSB set (0x80 = 128) if continuation follows.
// Returns count of bytes written.
fn grpc_varint_encode buf offset val
    if buf == 0
        return 0

    if val == 0
        mem_byte_write(buf, offset, 0)
        return 1

    cur = val
    written = 0
    while cur > 0
        b = cur % 128
        cur = cur / 128
        if cur > 0
            b = b + 128 // Set continuation bit
        mem_byte_write(buf, offset + written, b)
        written = written + 1

    return written

// Decodes a Varint from buf at offset.
// Writes decoded 64-bit value to out_meta[0] and bytes consumed to out_meta[1].
// Returns decoded value.
fn grpc_varint_decode buf offset out_meta
    if buf == 0
        return 0

    result = 0
    multiplier = 1
    i = 0
    done = 0

    while done == 0
        b = mem_byte_read(buf, offset + i)
        val = b % 128
        result = result + (val * multiplier)
        i = i + 1

        if (b / 128) == 0
            done = 1
        else
            multiplier = multiplier * 128

    if out_meta > 0
        mem_write(out_meta, 0, result)
        mem_write(out_meta, 8, i)

    return result

// Encodes field tag: (field_number << 3) | wire_type
fn grpc_tag_encode buf offset field_num wire_type
    tag = (field_num * 8) + wire_type
    return grpc_varint_encode(buf, offset, tag)

// Decodes field tag: returns field_number, writes wire_type and consumed bytes to out_meta
// out_meta[0] = field_num
// out_meta[8] = wire_type
// out_meta[16] = consumed_bytes
fn grpc_tag_decode buf offset out_meta
    meta = sys_alloc(16)
    tag = grpc_varint_decode(buf, offset, meta)
    consumed = mem_read(meta, 8)
    mem_free(meta, 16)

    field_num = tag / 8
    wire_type = tag % 8

    if out_meta > 0
        mem_write(out_meta, 0, field_num)
        mem_write(out_meta, 8, wire_type)
        mem_write(out_meta, 16, consumed)

    return field_num

// Serializes a Varint Protobuf Field: Tag + Varint Value
fn grpc_write_int64 buf offset field_num val
    tag_len = grpc_tag_encode(buf, offset, field_num, GRPC_WIRE_VARINT)
    val_len = grpc_varint_encode(buf, offset + tag_len, val)
    return tag_len + val_len

// Serializes a Length-Delimited Protobuf Field: Tag + Length + Raw Bytes
fn grpc_write_bytes buf offset field_num data_ptr data_len
    tag_len = grpc_tag_encode(buf, offset, field_num, GRPC_WIRE_LENGTH_DELIMITED)
    len_len = grpc_varint_encode(buf, offset + tag_len, data_len)
    base = offset + tag_len + len_len

    i = 0
    while i < data_len
        b = mem_byte_read(data_ptr, i)
        mem_byte_write(buf, base + i, b)
        i = i + 1

    return tag_len + len_len + data_len

// ── gRPC 5-Byte Message Framing (gRPC Wire Protocol) ─────────────────────────
// Byte 0:    Compression Flag (0 = uncompressed, 1 = compressed)
// Bytes 1-4: Message Length (Big-Endian 32-bit unsigned integer)
// Bytes 5-N: Serialized Protocol Buffer message
fn grpc_frame_message frame_buf payload_buf payload_len
    if frame_buf == 0
        return 0
    if payload_buf == 0
        return 0

    // Byte 0: 0 (uncompressed)
    mem_byte_write(frame_buf, 0, 0)

    // Bytes 1..4: Big-endian 32-bit length
    b0 = (payload_len / 16777216) % 256
    b1 = (payload_len / 65536) % 256
    b2 = (payload_len / 256) % 256
    b3 = payload_len % 256

    mem_byte_write(frame_buf, 1, b0)
    mem_byte_write(frame_buf, 2, b1)
    mem_byte_write(frame_buf, 3, b2)
    mem_byte_write(frame_buf, 4, b3)

    // Copy payload
    i = 0
    while i < payload_len
        b = mem_byte_read(payload_buf, i)
        mem_byte_write(frame_buf, 5 + i, b)
        i = i + 1

    return 5 + payload_len

// Unframes gRPC message
// out_meta layout:
// out_meta[0]:  compressed flag (0 or 1)
// out_meta[8]:  payload length
// out_meta[16]: payload buffer pointer (frame_buf + 5)
// Returns payload length if valid, -1 if invalid or truncated
fn grpc_unframe_message frame_buf frame_len out_meta
    if frame_buf == 0
        return 0 - 1
    if frame_len < 5
        return 0 - 1

    comp_flag = mem_byte_read(frame_buf, 0)

    b0 = mem_byte_read(frame_buf, 1)
    b1 = mem_byte_read(frame_buf, 2)
    b2 = mem_byte_read(frame_buf, 3)
    b3 = mem_byte_read(frame_buf, 4)

    payload_len = (b0 * 16777216) + (b1 * 65536) + (b2 * 256) + b3

    if frame_len < (5 + payload_len)
        return 0 - 1 // Incomplete or truncated frame

    if out_meta > 0
        mem_write(out_meta, 0, comp_flag)
        mem_write(out_meta, 8, payload_len)
        mem_write(out_meta, 16, frame_buf + 5)

    return payload_len
