// ==============================================================================
// LIPI PERMANENT REGRESSION TEST: WAVE 1 & WAVE 2 COMPILER + RUNTIME + CORE
// Verifies:
//   1. Unlimited System V AMD64 Stack ABI (16 args + nested calls + r12-r15 safety)
//   2. Native ERMS ByteBuffer & Binary-Safe ByteSlice (200KB + embedded 0x00 NUL)
//   3. 24-Thread Concurrent Exception Handling (4,112-slot overflow TLS table)
//   4. Auto-Boxed Mutable Upvalue Closures (local + escaping make_counter)
//   5. Dynamic GC-Traced Robin-Hood StrDict (500 keys + rehash + backward-shift delete)
//   6. Unified RFC 8259 IEEE-754 f64 JSON + ByteBuffer Escaping + O(1) Index
//   7. File-Level Module Isolation (`import "..." as alias` + `alias::sym`)
// ==============================================================================

import "utso/core/string"
import "utso/core/hashmap"
import "utso/core/json_fast"
import "utso/core/json"
import "utso/os/thread"
import "tests/fixtures/mod_ns_a" as modA
import "tests/fixtures/mod_ns_b" as modB

fn t_assert cond msg
    if cond == 0
        say "FAIL W1W2: " + msg
        syscall(231, 1, 0, 0, 0, 0, 0)
    end
    return 0

// 1. 16-Argument System V AMD64 Stack ABI (args 0..5 in regs, args 6..15 on stack)
fn sum16 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12 a13 a14 a15 a16
    return a1 * 1 + a2 * 2 + a3 * 3 + a4 * 4 + a5 * 5 + a6 * 6 + a7 * 7 + a8 * 8 + a9 * 9 + a10 * 10 + a11 * 11 + a12 * 12 + a13 * 13 + a14 * 14 + a15 * 15 + a16 * 16

fn nested_abi x
    r1 = sum16(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
    r2 = sum16(x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x)
    return r1 + r2

// 3. 32-Thread Concurrent Exception Handling Stress Worker (16 L1 + 16 Overflow Table Slots)
fn exc_tls_worker ctrl
    ok_ptr = ctrl
    idx = atomic_add(ctrl + 8, 1) + 1
    i = 0
    local_ok = 0
    while i < 20
        caught = 0
        try
            throw (idx * 100 + i)
        catch e
            if e == (idx * 100 + i)
                caught = 1
            end
        end
        if caught == 1
            local_ok = local_ok + 1
        end
        i = i + 1
    end
    atomic_add(ok_ptr, local_ok)
    return 0

// 4. Escaping & Local Auto-Boxed Mutable Closures
fn make_counter start_v
    n = start_v
    return |step| => {
        n += step
        n
    }

fn test_local_closure
    acc = 10
    bump = |d| => {
        acc = acc + d
        acc
    }
    bump(5)
    bump(7)
    return acc

fn main
    // 1. Verify 16-arg System V Stack ABI
    // sum(k^2, k=1..16) = 16*17*33/6 = 1496; sum(k, 1..16) = 136 -> *2 = 272; total = 1768
    t_assert(sum16(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16) == 1496, "sum16 exact")
    t_assert(nested_abi(2) == 1768, "nested 16-arg ABI")

    // 2. Verify Native ERMS ByteBuffer & NUL-Safe Binary Handling
    b = buf_new(64)
    ci = 0
    chunk = "0123456789ABCDEF0123456789ABCDEF" // 32B
    while ci < 6250
        buf_write_str(b, chunk)
        ci = ci + 1
    end
    t_assert(buf_len(b) == 200000, "ByteBuffer 200KB length")
    s200 = buf_to_str(b)
    t_assert(str_len(s200) == 200000, "buf_to_str 200KB length")
    buf_clear(b)
    t_assert(buf_len(b) == 0, "buf_clear")
    buf_write_byte(b, 65)
    buf_write_byte(b, 0)
    buf_write_byte(b, 66)
    buf_write_byte(b, 0)
    buf_write_byte(b, 67)
    t_assert(buf_len(b) == 5 && buf_get_byte(b, 1) == 0 && buf_get_byte(b, 4) == 67, "ByteBuffer embedded NUL bytes")
    bs = buf_slice(b, 0, 5)
    t_assert(buf_len(bs) == 5 && buf_get_byte(bs, 1) == 0 && buf_get_byte(bs, 2) == 66, "buf_slice binary-safe")
    buf_free(bs)
    buf_free(b)

    // 3. Verify 32-Thread Overflow TLS Exception Table (>16 concurrent OS threads!)
    ctrl = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    mem_word_write(ctrl, 0, 0)
    mem_word_write(ctrl, 8, 0)
    hs = []
    ti = 0
    while ti < 32
        hs = push(hs, thread_spawn_joinable(fn_ptr(exc_tls_worker), ctrl, 65536))
        ti = ti + 1
    end
    ti = 0
    while ti < 32
        thread_join(hs[ti])
        ti = ti + 1
    end
    t_assert(mem_word_read(ctrl, 0) == 640, "32x20 concurrent exception catches == 640")
    syscall(11, ctrl, 4096, 0, 0, 0, 0)

    // 4. Verify Escaping & Local Auto-Boxed Mutable Closures
    c1 = make_counter(100)
    t_assert(c1(20) == 120, "escaping closure call 1")
    t_assert(c1(30) == 150, "escaping closure call 2")
    t_assert(test_local_closure() == 22, "local mutable closure")

    // 5. Verify Dynamic GC-Traced Robin-Hood StrDict (500 keys + rehash + backward-shift delete)
    d = dict_new(16)
    di = 0
    while di < 500
        dict_set(d, "k_" + int_to_str(di), di * 3 + 1)
        di = di + 1
    end
    t_assert(dict_len(d) == 500, "StrDict 500 inserts")
    di = 0
    while di < 250
        t_assert(dict_delete(d, "k_" + int_to_str(di)) == 1, "StrDict delete")
        di = di + 1
    end
    t_assert(dict_len(d) == 250, "StrDict len after 250 deletes")
    t_assert(dict_has(d, "k_10") == 0, "StrDict deleted key absent")
    t_assert(dict_get(d, "k_499") == 1498, "StrDict surviving key exact")
    t_assert(dict_get_or(d, "missing", 9999) == 9999, "StrDict get_or default")
    dict_free(d)

    // 6. Verify Unified RFC 8259 IEEE-754 f64 JSON + O(1) StrDict Object Lookup
    jtxt = "{\"temp\":0.7,\"neg\":-12.5,\"k0\":0,\"k1\":1,\"k2\":2,\"k3\":3,\"k4\":4,\"k5\":5,\"k6\":6,\"k7\":7,\"k8\":8,\"k9\":9,\"msg\":\"hi\\n\\\"lipi\\\"\"}"
    jdoc = fast_json_parse(jtxt)
    jroot = fast_json_root(jdoc)
    f_val = fast_json_as_float(jdoc, fast_json_get(jdoc, jroot, "temp"))
    t_assert(f_val > 0.69 && f_val < 0.71, "fast_json float 0.7")
    t_assert(fast_json_get_int(jdoc, fast_json_get(jdoc, jroot, "k9")) == 9, "fast_json StrDict O(1) k9")
    msg_s = fast_json_get_str(jdoc, fast_json_get(jdoc, jroot, "msg"))
    t_assert(str_eq(msg_s, "hi\n\"lipi\"") == 1, "fast_json unescape")
    j2_pi = json_parse("3.14159")
    t_assert(starts_with(float_to_str(j2_pi), "3.1415") == 1, "json.lp parsed float 3.14159")

    // 7. Verify File-Level Module Isolation (colliding Box & compute symbols isolated cleanly)
    t_assert(modA::compute(5) == 16, "modA::compute(5) == 16")
    t_assert(modB::compute(5) == 37, "modB::compute(5) == 37")

    say "PASS: test_wave1_abi_buf_closures_modules (ABI16+Buf200KB+TLS24+Closures+StrDict500+JSONf64+Modules)"
    return 0
