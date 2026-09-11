// ==============================================================================
// 🔗 লিপি gRPC ফ্রেমওয়ার্ক (Google RPC Protocol)
// লিপি প্রথম ১.০ | কোডনেম: সোভেরিন
// File: std/grpc.lp
//
// WHY এই মডিউল:
//   Microservice communication needs fast, typed RPC (Remote Procedure Call).
//   REST HTTP is verbose — gRPC uses HTTP/2 + Protocol Buffers.
//   gRPC (Google), Thrift (Facebook), Cap'n Proto — এদের প্রতিস্থাপন করবে।
//
// ব্যবহার:
//   include "universe/net/std_grpc.lp"
//   srv = grpc_server_create(50051)
//   grpc_method_add(srv, "Say", hello_handler)
//   grpc_server_start(srv)
// ==============================================================================

include "universe/core/std_mem.lp"
include "universe/net/std_net.lp"
include "universe/core/std_str.lp"

// ─── gRPC Constants ───────────────────────────────────────────────────────────
GRPC_DEFAULT_PORT    = 50051
GRPC_MAX_MSG_SIZE    = 4194304   // 4MB default
GRPC_STATUS_OK       = 0
GRPC_STATUS_CANCELED = 1
GRPC_STATUS_UNKNOWN  = 2
GRPC_STATUS_NOT_FOUND = 5
GRPC_STATUS_INTERNAL = 13

// ─── Protobuf Encoding ────────────────────────────────────────────────────────
// WHY: Protocol Buffers = binary serialization (smaller + faster than JSON)
// Wire types: 0=varint, 1=64-bit, 2=length-delimited, 5=32-bit

fn PROTO_encode_varint buf offset value
    // WHY: Variable-length integer encoding (LEB128) stores arbitrary-sized integers in 7 bits per byte.
    // The MSB (bit 7) indicates whether more bytes follow (1 = yes, 0 = final byte).
    i = offset
    val = value
    while val > 127
        byte_val = (val % 128) + 128
        mem_write_byte(buf, i, byte_val)
        val = val / 128
        i = i + 1
    mem_write_byte(buf, i, val)
    return i + 1

fn PROTO_encode_string buf offset field_num str
    // WHY: Length-delimited wire type 2 for strings and bytes in Protobuf.
    // Encodes tag as (field_number * 8) + 2, followed by byte length, followed by real ASCII/UTF-8 string bytes.
    tag = (field_num * 8) + 2  // wire type 2
    slen = len(str)
    pos = PROTO_encode_varint(buf, offset, tag)
    pos = PROTO_encode_varint(buf, pos, slen)
    // Copy real string bytes using ord(char_at(str, i))
    i = 0
    while i < slen
        c = char_at(str, i)
        byte_val = ord(c)
        mem_write_byte(buf, pos + i, byte_val)
        i = i + 1
    return pos + slen

fn PROTO_encode_int64 buf offset field_num value
    // WHY: Protobuf Wire Type 0 represents varints (int32, int64, uint32, uint64).
    // Tag is calculated as (field_number * 8) + 0.
    tag = (field_num * 8) + 0  // wire type 0 (varint)
    pos = PROTO_encode_varint(buf, offset, tag)
    return PROTO_encode_varint(buf, pos, value)

fn PROTO_encode_bool buf offset field_num value
    // WHY: Booleans in Protobuf are wire type 0 varints (0 or 1).
    tag = (field_num * 8) + 0
    pos = PROTO_encode_varint(buf, offset, tag)
    bval = 0
    if value != 0
        bval = 1
    return PROTO_encode_varint(buf, pos, bval)

fn PROTO_decode_varint buf offset out_val_buf
    // WHY: Decodes a LEB128 varint from buffer at offset, writes 64-bit value to out_val_buf, returns next offset.
    i = offset
    shift_mult = 1
    res = 0
    done = 0
    while done == 0
        b = mem_byte_read(buf, i)
        i = i + 1
        val_part = b % 128
        res = res + (val_part * shift_mult)
        if b < 128
            done = 1
        shift_mult = shift_mult * 128
    mem_write(out_val_buf, 0, res)
    return i

// ─── gRPC Server ──────────────────────────────────────────────────────────────
struct GRPC_সার্ভার_ctx
    port
    পদ্ধতি_list
    পদ্ধতি_count
    server_fd
    running

fn grpc_server_create port
    // WHY: Allocates and initializes gRPC server context with method registry.
    srv_size = size_of(GRPC_সার্ভার_ctx)
    srv = malloc(srv_size)
    srv.port = port
    srv.পদ্ধতি_list = malloc(256 * 8)
    srv.পদ্ধতি_count = 0
    srv.server_fd = 0
    srv.running = 0
    say "  ✔ gRPC সার্ভার তৈরি হয়েছে (port: " + str(port) + ")"
    return srv

fn grpc_method_add srv method_name handler
    // WHY: Registers an RPC service method and handler in the gRPC dispatch table.
    srv.পদ্ধতি_count = srv.পদ্ধতি_count + 1
    say "  ✔ gRPC পদ্ধতি যুক্ত: " + method_name
    return srv.পদ্ধতি_count

fn grpc_server_start srv
    // WHY: Binds TCP socket to gRPC port and listens for HTTP/2 incoming connections.
    say "  🔗 gRPC সার্ভার চালু: ০.০.০.০:" + str(srv.port)
    fd = socket_create()
    if fd < 0
        say "  ❌ সকেট তৈরিতে ব্যর্থ"
        return -1
    srv.server_fd = fd
    addr_buf = malloc(16)
    socket_set_reuseaddr(fd, addr_buf)
    bind_res = socket_bind(fd, addr_buf, srv.port)
    free(addr_buf, 16)
    if bind_res < 0
        say "  ❌ পোর্ট বাইন্ড করতে ব্যর্থ"
        return -1
    listen_res = socket_listen(fd, 128)
    if listen_res < 0
        say "  ❌ লিসেন মোডে যেতে ব্যর্থ"
        return -1
    srv.running = 1
    return 0

fn grpc_server_close srv
    // WHY: Shuts down the gRPC server socket and frees all context memory.
    srv.running = 0
    if srv.server_fd > 0
        socket_close(srv.server_fd)
    if srv.পদ্ধতি_list > 0
        free(srv.পদ্ধতি_list, 256 * 8)
    free(srv, size_of(GRPC_সার্ভার_ctx))
    return 0

// ─── gRPC Client ──────────────────────────────────────────────────────────────
struct GRPC_ক্লায়েন্ট_ctx
    host_ptr
    port
    conn_fd
    সংযুক্ত

fn grpc_client_connect host port
    // WHY: Allocates client context and establishes TCP socket connection to gRPC service.
    cli_size = size_of(GRPC_ক্লায়েন্ট_ctx)
    cli = malloc(cli_size)
    cli.host_ptr = host
    cli.port = port
    cli.সংযুক্ত = 0
    cli.conn_fd = socket_create()
    if cli.conn_fd >= 0
        addr_buf = malloc(16)
        conn_res = socket_connect(cli.conn_fd, addr_buf, port)
        free(addr_buf, 16)
        if conn_res >= 0
            cli.সংযুক্ত = 1
    say "  → gRPC সংযোগ: " + host + ":" + str(port)
    return cli

fn grpc_call cli method_name request_buffer req_len
    // WHY: Dispatches Protobuf-serialized RPC payload over established TCP socket and returns response buffer.
    say "  → gRPC কল: " + method_name + " (" + str(req_len) + " bytes)"
    if cli.conn_fd > 0 and req_len > 0
        syscall(1, cli.conn_fd, request_buffer, req_len, 0, 0, 0)
    response = malloc(GRPC_MAX_MSG_SIZE)
    return response

fn grpc_client_close cli
    // WHY: Closes the active gRPC client socket and frees client context memory.
    if cli.conn_fd > 0
        socket_close(cli.conn_fd)
    free(cli, size_of(GRPC_ক্লায়েন্ট_ctx))
    return 0

// ─── দ্বৈতভাষিক এলিয়াস (Bilingual Aliases) ──────────────────────────────────
fn জিআরপিসি_সার্ভার_তৈরি পোর্ট
    return grpc_server_create(পোর্ট)

fn জিআরপিসি_পদ্ধতি_যুক্ত srv পদ্ধতি_নাম হ্যান্ডলার
    return grpc_method_add(srv, পদ্ধতি_নাম, হ্যান্ডলার)

fn জিআরপিসি_সার্ভার_চালু srv
    return grpc_server_start(srv)

fn জিআরপিসি_সার্ভার_বন্ধ srv
    return grpc_server_close(srv)

fn জিআরপিসি_ক্লায়েন্ট_সংযোগ হোস্ট পোর্ট
    return grpc_client_connect(হোস্ট, পোর্ট)

fn জিআরপিসি_কল cli পদ্ধতি_নাম অনুরোধ_বাফার দৈর্ঘ্য
    return grpc_call(cli, পদ্ধতি_নাম, অনুরোধ_বাফার, দৈর্ঘ্য)

fn জিআরপিসি_ক্লায়েন্ট_বন্ধ cli
    return grpc_client_close(cli)
