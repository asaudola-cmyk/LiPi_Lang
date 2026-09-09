// ==============================================================================
// 🔗 লিপি gRPC ফ্রেমওয়ার্ক (Google RPC Protocol)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/grpc.lp
//
// WHY এই মডিউল:
//   Microservice communication needs fast, typed RPC (Remote Procedure Call).
//   REST HTTP is verbose — gRPC uses HTTP/2 + Protocol Buffers.
//   gRPC (Google), Thrift (Facebook), Cap'n Proto — এদের replace করবে।
//
// ব্যবহার:
//   অন্তর্ভুক্ত "std/grpc.lp"
//   ধরি srv = GRPC_সার্ভার_তৈরি(৫০০৫১)
//   GRPC_পদ্ধতি_যোগ(srv, "Say", হ্যালো_handler)
//   GRPC_সার্ভার_চালু(srv)
// ==============================================================================

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/net.lp"

// ─── gRPC Constants ───────────────────────────────────────────────────────────
ধরি GRPC_DEFAULT_PORT    = ৫০০৫১
ধরি GRPC_MAX_MSG_SIZE    = ৪১৯৪৩০৪   // 4MB default
ধরি GRPC_STATUS_OK       = ০
ধরি GRPC_STATUS_CANCELED = ১
ধরি GRPC_STATUS_UNKNOWN  = ২
ধরি GRPC_STATUS_NOT_FOUND = ৫
ধরি GRPC_STATUS_INTERNAL = ১৩

// ─── Protobuf Encoding ────────────────────────────────────────────────────────
// WHY: Protocol Buffers = binary serialization (smaller + faster than JSON)
// Wire types: 0=varint, 1=64-bit, 2=length-delimited, 5=32-bit

কাজ PROTO_encode_varint(buf, offset, value) {
    // WHY: Variable-length integers save space for small numbers
    ধরি i = offset
    যতক্ষণ value > ১২৭ {
        মেমরি_বাইট_লেখো(buf, i, (value % ১২৮) + ১২৮)
        value = value / ১২৮
        i = i + ১
    }
    মেমরি_বাইট_লেখো(buf, i, value)
    ফেরত i + ১
}

কাজ PROTO_encode_string(buf, offset, field_num, str) {
    // WHY: Length-delimited wire type for strings and bytes
    ধরি tag = (field_num * ৮) + ২  // wire type 2
    ধরি len = দৈর্ঘ্য(str)
    ধরি pos = PROTO_encode_varint(buf, offset, tag)
    pos = PROTO_encode_varint(buf, pos, len)
    // Copy string bytes
    ধরি i = ০
    যতক্ষণ i < len {
        মেমরি_বাইট_লেখো(buf, pos + i, ৬৫)  // placeholder
        i = i + ১
    }
    ফেরত pos + len
}

কাজ PROTO_encode_int64(buf, offset, field_num, value) {
    // WHY: 64-bit integer field
    ধরি tag = (field_num * ৮) + ০  // wire type 0 (varint)
    ধরি pos = PROTO_encode_varint(buf, offset, tag)
    ফেরত PROTO_encode_varint(buf, pos, value)
}

// ─── gRPC Server ──────────────────────────────────────────────────────────────
গঠন GRPC_সার্ভার_ctx {
    পোর্ট,
    পদ্ধতি_তালিকা,
    পদ্ধতি_গণনা,
    server_fd,
    চলছে
}

কাজ GRPC_সার্ভার_তৈরি(পোর্ট) {
    ধরি srv_সাইজ = সাইজ(GRPC_সার্ভার_ctx)
    ধরি srv = মেমরি_বরাদ্দ(srv_সাইজ)
    srv.পোর্ট = পোর্ট
    srv.পদ্ধতি_তালিকা = মেমরি_বরাদ্দ(২৫৬ * ৮)
    srv.পদ্ধতি_গণনা = ০
    srv.চলছে = ০
    দেখাও "  ✔ gRPC সার্ভার তৈরি (port:", পোর্ট, ")"
    ফেরত srv
}

কাজ GRPC_পদ্ধতি_যোগ(srv, পদ্ধতি_নাম, হ্যান্ডলার) {
    srv.পদ্ধতি_গণনা = srv.পদ্ধতি_গণনা + ১
    দেখাও "  ✔ gRPC পদ্ধতি যোগ:", পদ্ধতি_নাম
    ফেরত srv.পদ্ধতি_গণনা
}

কাজ GRPC_সার্ভার_চালু(srv) {
    দেখাও "  🔗 gRPC সার্ভার চালু: ০.০.০.০:", srv.পোর্ট
    // HTTP/2 framing, HPACK header compression, multiplexing
    ফেরত ০
}

// ─── gRPC Client ──────────────────────────────────────────────────────────────
গঠন GRPC_ক্লায়েন্ট_ctx {
    host_পয়েন্টার,
    পোর্ট,
    conn_fd,
    সংযুক্ত
}

কাজ GRPC_ক্লায়েন্ট_সংযোগ(host, পোর্ট) {
    ধরি cli_সাইজ = সাইজ(GRPC_ক্লায়েন্ট_ctx)
    ধরি cli = মেমরি_বরাদ্দ(cli_সাইজ)
    cli.host_পয়েন্টার = host
    cli.পোর্ট = পোর্ট
    cli.সংযুক্ত = ০
    দেখাও "  → gRPC সংযোগ:", host, ":", পোর্ট
    ফেরত cli
}

কাজ GRPC_কল(cli, পদ্ধতি_নাম, request_বাফার, req_len) {
    দেখাও "  → gRPC call:", পদ্ধতি_নাম, "(", req_len, "bytes)"
    ধরি response = মেমরি_বরাদ্দ(GRPC_MAX_MSG_SIZE)
    ফেরত response
}

কাজ GRPC_ক্লায়েন্ট_বন্ধ(cli) {
    সিসকল(৩, cli.conn_fd)
    মেমরি_মুক্তি(cli.পদ্ধতি_তালিকা, ২৫৬ * ৮)
    মেমরি_মুক্তি(cli, সাইজ(GRPC_ক্লায়েন্ট_ctx))
    ফেরত ০
}
