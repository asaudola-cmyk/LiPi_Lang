// ==============================================================================
// 🧪 LIPI TEST 233: TIER 1-4 SOVEREIGN ARCHITECTURE END-TO-END VERIFICATION
// ⚡ Tests Static-PIE, Struct Return/Copy Types, fn_ptr/&fn, Capturing Closures,
//    Contextual match, Cross-frame try/catch/throw, W^X FFI, Conservative GC,
//    Mach-O LC_CODE_SIGNATURE, PE32+ 10-API, RFC 6455 WS, QUIC PTO & UDP Gossip.
// ==============================================================================

include "utso/core/ffi_sovereign.lp"
include "utso/net/ws_engine.lp"
include "utso/net/quic.lp"
include "utso/net/p2p_gossip.lp"
include "src/compiler/backend/gc.lp"
include "src/compiler/backend/formats/macho/macho_writer.lp"
include "src/compiler/backend/emulators/macho_runner.lp"
include "src/compiler/backend/formats/pe/pe_writer.lp"
include "src/compiler/backend/emulators/win64_pe_runner.lp"

fn t233_assert actual expected test_name
    if actual != expected
        say "  ❌ FAIL: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

fn t233_assert_str actual expected test_name
    if actual != expected
        say "  ❌ FAIL: " + test_name
        say "     Expected: " + expected
        say "     Actual:   " + actual
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

// ── 1. Type-Aware Struct Return & Copy Propagation With Colliding Fields ──────
struct AlphaBox
    pad0
    val

struct BetaBox
    val
    pad1

fn make_alpha v -> AlphaBox
    a = AlphaBox()
    a.pad0 = 111
    a.val = v
    return a

fn make_beta v -> BetaBox
    b = BetaBox()
    b.val = v
    b.pad1 = 222
    return b

// ── 2. First-Class Functions & Higher-Order Dispatch ──────────────────────────
fn t233_square x
    return x * x

fn t233_apply f x
    return f(x)

// ── 3. Cross-Frame Exception Unwinding ────────────────────────────────────────
fn t233_deep_thrower code
    if code > 0
        throw code + 500
    end
    return 1

fn t233_try_wrapper x
    out = 0
    try
        r = t233_deep_thrower(x)
        out = r
    catch err
        out = err
    end
    return out

say "=== Test 233: Tier 1-4 Sovereign Capabilities ==="

// A. Struct return type & copy propagation
a_obj = make_alpha(42)
b_obj = make_beta(99)
a_copy = a_obj
t233_assert(a_obj.val, 42, "Struct return type resolves AlphaBox.val (offset 8)")
t233_assert(b_obj.val, 99, "Struct return type resolves BetaBox.val (offset 0)")
t233_assert(a_copy.val, 42, "Copy propagation preserves AlphaBox.val")
t233_assert(make_alpha(77).val, 77, "Direct chained make_alpha(77).val == 77")

// B. fn_ptr / &fn / capturing closures
p_sq = fn_ptr(t233_square)
p_amp = &t233_square
t233_assert(t233_apply(p_sq, 7), 49, "fn_ptr(t233_square) indirect call == 49")
t233_assert(t233_apply(p_amp, 8), 64, "&t233_square indirect call == 64")

factor = 10
bias = 5
c1 = |x| => (x * factor) + bias
c2 = fn(x) => (x * factor) - bias
t233_assert(t233_apply(c1, 4), 45, "Capturing pipe closure |x| => (x*factor)+bias == 45")
t233_assert(t233_apply(c2, 4), 35, "Capturing fn closure fn(x) => (x*factor)-bias == 35")

// C. Contextual match & variable coexistence
match = 1
t233_assert(match, 1, "Contextual variable 'match = 1' preserved")
m_out = 0
code_v = 20
match code_v
    case 10 => m_out = 100
    case 20 => m_out = 200
    _ => m_out = 999
end
t233_assert(m_out, 200, "Pattern match dispatches integer case 20 -> 200")

s_out = 0
proto_s = "tcp"
match proto_s
    case "udp" => s_out = 1
    case "tcp" => s_out = 2
    _ => s_out = 3
end
t233_assert(s_out, 2, "Pattern match dispatches string case 'tcp' -> 2")

// D. Cross-frame try/catch/throw
t233_assert(t233_try_wrapper(7), 507, "Cross-frame throw(507) unwound and caught in err")
t233_assert(t233_try_wrapper(0), 1, "Normal try path pops exception handler cleanly")

// E. W^X mprotect FFI native trampoline
ffi_ret = ffi_call_native(&t233_square, 9, 0, 0, 0, 0)
t233_assert(ffi_ret, 81, "W^X SYS_mprotect FFI trampoline invokes &t233_square(9) == 81")

// F. Conservative hardware stack-scanning GC
sb = stack_bottom()
sp_now = stack_pointer()
hb = heap_base_ptr()
hp = heap_curr_ptr()
t233_assert(sb > sp_now, 1, "Runtime stack_bottom() > stack_pointer()")
t233_assert(hb > 65536 and hp >= hb, 1, "Runtime heap_base_ptr() & heap_curr_ptr() valid")
gc_inst = new_generational_gc()
live_eden = gc_inst.eden_start + 128
mem_write(live_eden, 0, 12345)
mem_write(gc_inst.eden_start + 512, 0, 54321)
roots_found = gc_scan_stack_roots(gc_inst, [live_eden])
t233_assert(roots_found >= 1, 1, "gc_scan_stack_roots discovers live stack pointer")
recl = gc_collect_conservative(gc_inst, [live_eden, gc_inst.eden_start + 512])
t233_assert(recl >= 64, 1, "gc_collect_conservative sweeps unmarked slot while keeping live stack root")

// G. RFC 6455 WebSocket SHA-1 + Base64 test vector
ws_acc = ws_compute_accept_key("dGhlIHNhbXBsZSBub25jZQ==")
t233_assert_str(ws_acc, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "RFC 6455 Sec-WebSocket-Accept SHA-1+Base64 verified")

// H. QUIC RFC 9002 pacing rate & PTO calculation
qconn = quic_connection_new([1, 2, 3, 4], [5, 6, 7, 8])
quic_connection_on_ack_received(qconn, 1, 5, 40)
qpto = quic_connection_compute_pto(qconn)
t233_assert(qpto > 40 and qconn.congestion.pacing_rate > 0, 1, "QUIC RFC 9002 PTO & pacing_rate active")

// I. Real UDP P2P Gossip datagram transmission
g_sent = _send_gossip_udp("127.0.0.1:19999", "msg1", "nodeA", "ping", 3)
t233_assert(g_sent > 0, 1, "Real UDP SYS_sendto gossip transmission returns bytes > 0")

// J. Mach-O __LINKEDIT + LC_CODE_SIGNATURE SHA-256 SuperBlob verification
sample_code = [184, 0, 0, 0, 0, 195]
m_res = macho_emit_executable(sample_code, [], 0, CPU_TYPE_ARM64(), "")
m_runner = macho_runner_new()
macho_runner_load_bytes(m_runner, m_res.mw_bytes)
t233_assert(m_runner.mor_is_valid_macho, 1, "Mach-O ARM64 binary valid")
t233_assert(m_runner.mor_has_codesig, 1, "Mach-O embeds __LINKEDIT + LC_CODE_SIGNATURE (0xFADE0CC0)")

// K. Windows PE32+ 10-API KERNEL32.dll IAT verification
p_res = pe_emit_executable(sample_code, [], [], 0, 0, "")
p_runner = win64_pe_runner_new()
win64_pe_runner_load_bytes(p_runner, p_res.pe_bytes)
t233_assert(p_runner.wpr_is_valid_pe, 1, "PE32+ Windows binary valid")
t233_assert(p_runner.wpr_linux_syscall_count, 0, "PE32+ .text contains 0 Linux syscalls")
t233_assert(p_runner.wpr_import_functions.len(), 10, "PE32+ IAT imports all 10 KERNEL32.dll APIs")

say "PASS: Test 233 Tier 1-4 Sovereign Verification"
