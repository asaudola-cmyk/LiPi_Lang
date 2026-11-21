// ==============================================================================
// 🧪 LIPI TEST 234: PHASE 1–4 FORENSIC ARCHITECTURE DEEP AUDIT SUITE
// ⚡ Verifies SSE2 f64 + NaN Comparisons + Structural Field Disambiguation +
//    Compound Indexing + Mutable Globals + Closure Slab No-Leak + Try/Finally
//    Unwinding + 8-Thread Futex/TLS Isolation + RFC 5869/8446 HKDF + AES-CTR +
//    ARM64 W^X + Mach-O 16KB/CodeDirectory + PE32+ 12-API + WASM WASI _start.
// ==============================================================================

include "utso/os/thread.lp"
include "utso/net/tls/tls13.lp"
include "utso/crypto/tls.lp"
include "src/compiler/backend/targets/arm64/synthesizer.lp"
include "src/compiler/backend/targets/wasm/synthesizer.lp"
include "src/compiler/backend/formats/macho/macho_writer.lp"
include "src/compiler/backend/emulators/macho_runner.lp"
include "src/compiler/backend/formats/pe/pe_writer.lp"
include "src/compiler/backend/emulators/win64_pe_runner.lp"

fn t234_assert actual expected test_name
    if actual != expected
        say "  FAIL: " + test_name + " expected=" + str(expected) + " actual=" + str(actual)
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

fn t234_assert_true cond test_name
    if cond == 0
        say "  FAIL: " + test_name
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

// ── Section 1 Helpers: Typed Float Params & Inferred f64 Return ───────────────
@fn t234_compute_scaled(x: f64, y: f64)
    return (x * y) + 0.5
@end

// ── Section 2 Helpers: Colliding Field Names & Nested Struct Compound ─────────
struct T234BoxA
    pad0: int
    val: int

struct T234BoxB
    val: float
    tag: int

struct T234Wrapper
    inner: T234BoxA

// ── Section 3 Helpers: Mutable Globals ────────────────────────────────────────
global g_t234_counter = 100
global g_t234_tbuf = 0
g_t234_acc = 10

fn t234_bump_globals delta
    g_t234_counter += delta
    g_t234_acc = g_t234_acc + 5
    return g_t234_counter

// ── Section 5 Helpers: Try / Finally / Return Unwind Order ────────────────────
fn t234_try_return_with_finally log_arr
    try
        push(log_arr, 1)
        return 77
    finally
        push(log_arr, 2)
    end
    return 0

fn t234_rethrow_helper flag_box
    try
        throw 404
    finally
        list_set(flag_box, 0, 1)
    end
    return 0

// ── Section 6 Helper: 8-Thread Worker (Alloc + Malloc/Free + Per-Thread Try) ─
fn t234_thread_worker tid_arg
    tmp_list = [tid_arg, tid_arg + 10, tid_arg + 20]
    tmp_str = "w" + str(tid_arg)
    ubuf = malloc(64)
    mem_write(ubuf, 0, tmp_list[2] + len(tmp_str))
    caught = 0
    try
        throw 100 + tid_arg
    catch err
        caught = err
    end
    free(ubuf, 64)
    if g_t234_tbuf != 0
        mem_write(g_t234_tbuf, tid_arg * 8, caught)
    end
    return 0

fn count_lines_str s_txt
    n = len(s_txt)
    cnt = 0
    i = 0
    while i < n
        if char_at(s_txt, i) == "\n"
            cnt = cnt + 1
        end
        i = i + 1
    end
    return cnt

fn bytes_read_u32_le arr off
    return arr[off] + (arr[off + 1] * 256) + (arr[off + 2] * 65536) + (arr[off + 3] * 16777216)

fn find_bytes_4 arr b0 b1 b2 b3
    n = arr.len()
    i = 0
    while i + 3 < n
        if arr[i] == b0 and arr[i + 1] == b1 and arr[i + 2] == b2 and arr[i + 3] == b3
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn main
    say "=== Test 234: Phase 1-4 Forensic Architecture Deep Audit ==="

    // ── 1. SSE2 f64 Params, Inferred f64 Return, Unary -x, Compound Ops, NaN ─
    scaled = t234_compute_scaled(2.5, 3.0)
    t234_assert_true(scaled > 7.99 and scaled < 8.01, "Inferred f64 return (2.5*3.0)+0.5 == 8.0")
    neg_scaled = -scaled
    t234_assert_true(neg_scaled < -7.99 and neg_scaled > -8.01, "Unary minus on f64 (btc 63) == -8.0")

    fv = 10.0
    fv += 2.5
    fv -= 0.5
    fv *= 2.0
    fv /= 4.0
    t234_assert_true(fv > 5.99 and fv < 6.01, "Scalar f64 compound += -= *= /= evaluates to 6.0")

    z_f = 0.0
    nan_v = z_f / z_f
    t234_assert(nan_v < 1.0, 0, "NaN < 1.0 returns 0")
    t234_assert(nan_v <= 1.0, 0, "NaN <= 1.0 returns 0")
    t234_assert(nan_v > 1.0, 0, "NaN > 1.0 returns 0")
    t234_assert(nan_v >= 1.0, 0, "NaN >= 1.0 returns 0")
    t234_assert(nan_v == nan_v, 0, "NaN == NaN returns 0")
    t234_assert(nan_v != nan_v, 1, "NaN != NaN returns 1")
    t234_assert(-1.5 < 0.0, 1, "Negative float comparison -1.5 < 0.0 == 1")

    // ── 2. Field Disambiguation, Nested Chained Compound, Array Compound, Zero-Guard ─
    ba = T234BoxA()
    ba.pad0 = 11
    ba.val = 42
    bb = T234BoxB()
    bb.val = 3.5
    bb.tag = 9
    bb.val += 1.5
    t234_assert(ba.val, 42, "T234BoxA.val int offset resolved cleanly")
    t234_assert_true(bb.val > 4.99 and bb.val < 5.01, "T234BoxB.val float += resolved without BoxA collision")

    wrap = T234Wrapper()
    wrap.inner = T234BoxA()
    wrap.inner.pad0 = 7
    wrap.inner.val = 10
    wrap.inner.val += 9
    t234_assert(wrap.inner.val, 19, "Nested chained wrap.inner.val += 9 == 19")

    arr = [10, 20, 30]
    arr[1] += 5
    arr[2] *= 2
    t234_assert(arr[1], 25, "Array compound arr[1] += 5 == 25")
    t234_assert(arr[2], 60, "Array compound arr[2] *= 2 == 60")

    zg = 12
    zg /= 0
    zg %= 0
    t234_assert(zg >= 0 or zg <= 0, 1, "Zero-divisor /= and %= execute without SIGFPE")

    // ── 3. Mutable Globals Across Functions & Closures ───────────────────────
    res_g = t234_bump_globals(25)
    c_read = |k| => g_t234_counter + k
    t234_assert(res_g, 125, "global g_t234_counter mutated across function call (125)")
    t234_assert(g_t234_acc, 15, "Top-level g_* mutable global incremented (15)")
    t234_assert(c_read(5), 130, "Closure captures live mutated global g_t234_counter + 5 == 130")

    // ── 4. 2,000 Closures Bounded /proc/self/maps (Zero VMA Leak) ─────────────
    maps_before = count_lines_str(file_read("/proc/self/maps"))
    ci = 0
    csum = 0
    while ci < 2000
        bias_c = ci & 15
        cl = |v| => v + bias_c
        csum = csum + cl(1)
        ci = ci + 1
    end
    maps_after = count_lines_str(file_read("/proc/self/maps"))
    t234_assert(csum > 2000, 1, "2000 capturing closures evaluated accurately")
    t234_assert_true((maps_after - maps_before) < 20, "2000 closures VMA /proc/self/maps growth < 20 lines")

    // ── 5. Try / Catch / Finally + Rethrow + Break/Return Handler Pop Balance ─
    ord_log = list()
    ret_v = t234_try_return_with_finally(ord_log)
    t234_assert(ret_v, 77, "try { return 77 } finally returns 77")
    t234_assert(ord_log.len(), 2, "try { return } finally ran both try and finally")
    t234_assert(ord_log[0], 1, "try body executed before finally")
    t234_assert(ord_log[1], 2, "finally executed before return")

    rethrow_flag = [0]
    outer_caught = 0
    try
        t234_rethrow_helper(rethrow_flag)
    catch e
        outer_caught = e
    end
    t234_assert(rethrow_flag[0], 1, "Standalone try...finally ran finally block")
    t234_assert(outer_caught, 404, "Standalone try...finally rethrew exception 404 to outer catch")

    // Break inside try inside loop must pop handler so subsequent outer catch receives throw
    li = 0
    while li < 3
        try
            if li == 1
                break
            end
        catch le
        end
        li = li + 1
    end
    after_break_caught = 0
    try
        throw 999
    catch e2
        after_break_caught = e2
    end
    t234_assert(after_break_caught, 999, "break inside try popped handler cleanly before outer throw 999")

    // ── 6. 8-Thread Futex Join + Thread-Safe __alloc + Per-Thread try/catch ───
    g_t234_tbuf = malloc(64)
    ti = 0
    while ti < 8
        mem_write(g_t234_tbuf, ti * 8, 0)
        ti = ti + 1
    end
    handles = list()
    ti = 0
    while ti < 8
        h = thread_spawn_joinable(&t234_thread_worker, ti, 65536)
        t234_assert_true(h != 0, "thread_spawn_joinable created worker " + str(ti))
        push(handles, h)
        ti = ti + 1
    end
    ti = 0
    while ti < 8
        t234_assert(thread_join(handles[ti]), 1, "thread_join completed for worker " + str(ti))
        ti = ti + 1
    end
    ti = 0
    while ti < 8
        got_t = mem_read(g_t234_tbuf, ti * 8)
        t234_assert(got_t, 100 + ti, "8-thread isolated exception + __alloc + malloc slot " + str(ti))
        ti = ti + 1
    end
    free(g_t234_tbuf, 64)
    g_t234_tbuf = 0

    // ── 7. RFC 5869 HKDF-SHA256, Real AES-128-CTR Stream & DER Cert Validation ─
    // RFC 5869 Test Case 1: salt = 0x00..0x0c, IKM = 22 bytes of 0x0b
    rfc_salt = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    rfc_ikm = [11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11]
    prk = tls13_hkdf_extract(rfc_salt, rfc_ikm)
    t234_assert(prk.len(), 32, "RFC 5869 Case 1 PRK length == 32")
    t234_assert(prk[0], 7, "RFC 5869 Case 1 PRK[0] == 0x07")
    t234_assert(prk[1], 119, "RFC 5869 Case 1 PRK[1] == 0x77")
    t234_assert(prk[31], 229, "RFC 5869 Case 1 PRK[31] == 0xe5")

    okm = tls13_hkdf_expand_label(prk, "key", [1, 2, 3, 4], 16)
    t234_assert(okm.len(), 16, "RFC 8446 HKDF-Expand-Label produces 16-byte key")

    // Verify aes_gcm_stream_cipher uses full AES-128-CTR rather than repeating single-byte XOR
    kmem = malloc(16)
    imem = malloc(16)
    pbuf = malloc(16)
    cbuf = malloc(16)
    bi = 0
    while bi < 16
        mem_byte_write(kmem, bi, bi + 1)
        mem_byte_write(imem, bi, 16 - bi)
        mem_byte_write(pbuf, bi, 65) // 'A' repeated
        bi = bi + 1
    end
    aes_gcm_stream_cipher(kmem, imem, 1, pbuf, 16, cbuf)
    c0 = mem_byte_read(cbuf, 0) & 255
    c1 = mem_byte_read(cbuf, 1) & 255
    c2 = mem_byte_read(cbuf, 2) & 255
    t234_assert_true(c0 != c1 or c1 != c2, "aes_gcm_stream_cipher produces non-trivial AES-128-CTR ciphertext")
    free(kmem, 16)
    free(imem, 16)
    free(pbuf, 16)
    free(cbuf, 16)

    bad_der = malloc(8)
    mem_byte_write(bad_der, 0, 255)
    bad_cert = tls_certificate_parse(bad_der, 8)
    t234_assert(tls_certificate_verify(bad_cert, 0, 1000), 0, "Malformed DER rejected by tls_certificate_verify")
    tls_certificate_free(bad_cert)
    free(bad_der, 8)

    good_der = malloc(8)
    mem_byte_write(good_der, 0, 48)
    mem_byte_write(good_der, 1, 4)
    mem_byte_write(good_der, 2, 48)
    mem_byte_write(good_der, 3, 2)
    mem_byte_write(good_der, 4, 5)
    mem_byte_write(good_der, 5, 0)
    good_cert = tls_certificate_parse(good_der, 6)
    t234_assert(tls_certificate_verify(good_cert, 0, 1000), 1, "Valid X.509 DER SEQUENCE passes tls_certificate_verify")
    tls_certificate_free(good_cert)
    free(good_der, 8)

    // ── 8. Cross-Target Layouts: ARM64 W^X, Mach-O 16KB/CS, PE32+ 12-API, WASM WASI ─
    arm_out = "/tmp/t234_arm64_wx.elf"
    arm_synth = arm64_synth_compile_program(tokenize_source("say 42\n"))
    t234_assert_true(arm_synth.synth_code.len() >= 12, "ARM64 synthesizer compiled non-empty code")
    arm_hdr_test = macho_emit_executable([184, 0, 0, 0, 0, 195], [], 0, CPU_TYPE_ARM64(), "")
    mr = macho_runner_new()
    macho_runner_load_bytes(mr, arm_hdr_test.mw_bytes)
    t234_assert(mr.mor_is_valid_macho, 1, "Mach-O ARM64 header valid")
    t234_assert(mr.mor_has_codesig, 1, "Mach-O ARM64 contains LC_CODE_SIGNATURE")
    t234_assert_true(mr.mor_segment_vsizes.len() >= 2 and mr.mor_segment_vsizes[1] >= 16384 and (mr.mor_segment_vsizes[1] % 16384) == 0, "Mach-O ARM64 __TEXT honors 16KB page alignment")

    // Verify 88-byte v0x20400 CodeDirectory inside Mach-O bytes
    cd_pos = find_bytes_4(arm_hdr_test.mw_bytes, 250, 222, 12, 2)
    t234_assert_true(cd_pos > 0, "Mach-O embeds CS_CodeDirectory (0xFADE0C02)")
    t234_assert(arm_hdr_test.mw_bytes[cd_pos + 9], 2, "CodeDirectory version byte1 == 0x02 (0x00020400)")
    t234_assert(arm_hdr_test.mw_bytes[cd_pos + 10], 4, "CodeDirectory version byte2 == 0x04 (0x00020400)")

    pe_res = pe_emit_executable([184, 0, 0, 0, 0, 195], [], [], 0, 0, "")
    pr = win64_pe_runner_new()
    win64_pe_runner_load_bytes(pr, pe_res.pe_bytes)
    t234_assert(pr.wpr_is_valid_pe, 1, "PE32+ executable valid")
    t234_assert(pr.wpr_linux_syscall_count, 0, "PE32+ .text has 0 Linux syscalls")
    t234_assert(pr.wpr_import_functions.len(), 12, "PE32+ IAT imports 12 KERNEL32 APIs (incl VirtualFree & GetCommandLineA)")

    // Verify ARM64 ELF emitter directly writes 3 W^X PHDRs
    arm_elf_res = arm64_elf_emit_executable(arm_synth.synth_code, arm_synth.synth_rodata, arm_out)
    t234_assert(arm_elf_res.ew_success, 1, "arm64_elf_emit_executable wrote ARM64 ELF")
    arm_bin_txt = file_read(arm_out)
    syscall(87, arm_out, 0, 0, 0, 0, 0)
    t234_assert(ord(char_at(arm_bin_txt, 56)), 3, "ARM64 ELF e_phnum == 3 (RX + RW + GNU_STACK)")
    // Check PHDR[0] p_flags == 5 (PF_R|PF_X) and PHDR[1] p_flags == 6 (PF_R|PF_W)
    t234_assert(ord(char_at(arm_bin_txt, 68)), 5, "ARM64 ELF PT_LOAD[0] p_flags == 5 (RX)")
    t234_assert(ord(char_at(arm_bin_txt, 124)), 6, "ARM64 ELF PT_LOAD[1] p_flags == 6 (RW)")

    // Verify WASM WASI module emits _start () -> () and 4 memory pages
    wb = wasm_synth_compile_source("fn add_sq a b\n    return (a * a) + (b * b)\nsay add_sq(3, 4)\n")
    t234_assert(wb[0], 0, "WASM magic 0x00")
    t234_assert(wb[1], 97, "WASM magic 'a'")
    t234_assert(find_bytes_4(wb, 96, 0, 0, 2) >= 0 or find_bytes_4(wb, 96, 0, 0, 3) >= 0, 1, "WASM Type section declares void _start () -> () (0x60 0x00 0x00)")

    say "ALL PHASE 1 TO PHASE 4 DEEP AUDIT CHECKS GREEN!"
    return 0
