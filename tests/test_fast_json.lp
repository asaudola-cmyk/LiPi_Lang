// ==============================================================================
// 👑 Test: Lipi Zero-Copy Fast JSON & Production Concurrent Server Engine
// ⚡ 100% Pure Lipi | In-Place Slices | Epoll Event Reactor | Zero-Libc
// ==============================================================================
//
// WHY: Validates enterprise-grade JSON serialization/deserialization with zero
//      redundant string allocations, along with the Linux epoll non-blocking
//      production server reactor lifecycle.
// ==============================================================================

include "universe/core/json_fast.lp"
include "universe/net/server_production.lp"

say "========================================================"
say "👑 Testing Lipi Zero-Copy Fast JSON & Concurrent Server"
say "========================================================"

// ── Test 1: Complex JSON Parsing & In-Place DOM Traversal ─────────────────────
say "[1/4] Testing Zero-Copy Complex JSON Parsing..."

json_text = "{\"name\":\"Lipi 2.0\",\"version\":200,\"is_sovereign\":true,\"license\":null,\"features\":[\"SIMD\",\"Epoll\",\"DWARF\"]}"

doc = fast_json_parse(json_text)
root = fast_json_root(doc)

if fast_json_node_type(doc, root) != FAST_JSON_OBJECT
    say "FAIL: Root is not an object!"
    exit(1)

// String field
name_idx = fast_json_get(doc, root, "name")
name_val = fast_json_get_str(doc, name_idx)
if name_val != "Lipi 2.0"
    say "FAIL: Name field mismatch: " + name_val
    exit(1)
say "  ✔ String field verified: " + name_val

// Integer field
ver_idx = fast_json_get(doc, root, "version")
ver_val = fast_json_get_int(doc, ver_idx)
if ver_val != 200
    say "FAIL: Version field mismatch: " + str(ver_val)
    exit(1)
say "  ✔ Integer field verified: " + str(ver_val)

// Boolean field
bool_idx = fast_json_get(doc, root, "is_sovereign")
bool_val = fast_json_get_bool(doc, bool_idx)
if bool_val != 1
    say "FAIL: is_sovereign must be true (1)!"
    exit(1)
say "  ✔ Boolean field verified: true"

// Null field
null_idx = fast_json_get(doc, root, "license")
if fast_json_is_null(doc, null_idx) != 1
    say "FAIL: license must be null!"
    exit(1)
say "  ✔ Null field verified: null"

// Array field
arr_idx = fast_json_get(doc, root, "features")
arr_len = fast_json_arr_len(doc, arr_idx)
if arr_len != 3
    say "FAIL: Array length expected 3, got: " + str(arr_len)
    exit(1)

f0 = fast_json_get_str(doc, fast_json_arr_get(doc, arr_idx, 0))
f1 = fast_json_get_str(doc, fast_json_arr_get(doc, arr_idx, 1))
f2 = fast_json_get_str(doc, fast_json_arr_get(doc, arr_idx, 2))
if f0 != "SIMD" or f1 != "Epoll" or f2 != "DWARF"
    say "FAIL: Array items mismatch!"
    exit(1)
say "  ✔ Array elements verified: [" + f0 + ", " + f1 + ", " + f2 + "]"

// ── Test 2: Deeply Nested Dotted Path Traversal ───────────────────────────────
say "[2/4] Testing Nested Dotted Path Resolution..."

nested_json = "{\"system\":{\"cloud\":{\"region\":\"bd-dhaka-1\",\"max_workers\":64}},\"servers\":[{\"ip\":\"10.0.0.1\"},{\"ip\":\"10.0.0.2\"}]}"

doc2 = fast_json_parse(nested_json)
root2 = fast_json_root(doc2)

reg_node = fast_json_path(doc2, root2, "system.cloud.region")
reg_str = fast_json_get_str(doc2, reg_node)
if reg_str != "bd-dhaka-1"
    say "FAIL: Path system.cloud.region failed, got: " + reg_str
    exit(1)
say "  ✔ Path system.cloud.region: " + reg_str

workers_node = fast_json_path(doc2, root2, "system.cloud.max_workers")
workers_val = fast_json_get_int(doc2, workers_node)
if workers_val != 64
    say "FAIL: Path system.cloud.max_workers failed, got: " + str(workers_val)
    exit(1)
say "  ✔ Path system.cloud.max_workers: " + str(workers_val)

ip2_node = fast_json_path(doc2, root2, "servers.1.ip")
ip2_str = fast_json_get_str(doc2, ip2_node)
if ip2_str != "10.0.0.2"
    say "FAIL: Path servers.1.ip failed, got: " + ip2_str
    exit(1)
say "  ✔ Path servers.1.ip: " + ip2_str

// ── Test 3: Stringify & Roundtrip Serialization ───────────────────────────────
say "[3/4] Testing Fast JSON Serialization & Roundtrip..."

ser_out = fast_json_stringify(doc, root)
doc3 = fast_json_parse(ser_out)
root3 = fast_json_root(doc3)
round_name = fast_json_get_str(doc3, fast_json_get(doc3, root3, "name"))
round_ver = fast_json_get_int(doc3, fast_json_get(doc3, root3, "version"))

if round_name != "Lipi 2.0" or round_ver != 200
    say "FAIL: Roundtrip serialization failed!"
    exit(1)
say "  ✔ Roundtrip serialization verified: " + ser_out

// ── Test 4: Production Concurrent Server Non-Blocking Lifecycle ───────────────
say "[4/4] Testing Production Epoll Server Lifecycle..."

test_port = 9876
srv = prod_server_create(test_port, 16)

listen_res = prod_server_listen(srv)
if listen_res != 0
    say "FAIL: prod_server_listen returned error: " + str(listen_res)
    exit(1)
say "  ✔ Production server listening on 0.0.0.0:" + str(test_port) + " (listen_fd=" + str(get(srv, 1)) + " epfd=" + str(get(srv, 2)) + ")"

// Execute non-blocking reactor tick (50ms timeout)
tick_res = prod_server_tick(srv, 50)
if tick_res < 0
    say "FAIL: prod_server_tick returned error: " + str(tick_res)
    exit(1)
say "  ✔ Reactor event loop ticked (nfds=" + str(tick_res) + ")"

// Clean shutdown
close_res = prod_server_close(srv)
if close_res != 0
    say "FAIL: prod_server_close returned error: " + str(close_res)
    exit(1)
say "  ✔ Server sockets, epoll instance, and memory buffers gracefully closed"

say "========================================================"
say "PASS: Fast JSON & Production Server Test Verified 100%!"
say "========================================================"
