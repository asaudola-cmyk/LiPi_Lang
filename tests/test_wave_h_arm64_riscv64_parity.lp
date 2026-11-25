// ==============================================================================
// Wave H Verification Suite: ARM64 + RISC-V 64 Full Feature Parity
// Tests:
//   H1. Mutable capturing closures (heap-boxed upvalues, independent instances,
//       compound assignment inside closure, inline lambda, chained calls).
//   H2. Native DICT0 HashMap (literals, index get/set, overwrite, len, has_key,
//       del_key tombstone reuse, negative & positive int keys, 2x auto-rehash).
//   H3. Native ByteBuffer (buf_new, buf_write_str, buf_write_byte, buf_len,
//       buf_to_str + cross-heap/rodata string key equality in DICT0).
//   H4. LIFO `defer` execution on function return.
// Designed to compile & execute identically across x86_64, RISC-V 64 (--run-rv64),
// ARM64 ELF64, macOS ARM64 Mach-O, and Windows PE32+.
// ==============================================================================

fn make_ctr(start)
    n = start
    return fn(dx) { n += dx; return n }
end

fn test_defer_lifo(log)
    defer push(log, 1)
    defer push(log, 2)
    return 42
end

fn main()
    // ── H1: Mutable Capturing Closures & Inline Lambdas ──────────────────────
    f = make_ctr(5)
    g = make_ctr(100)
    r1 = f(3)
    r2 = f(4)
    r3 = g(1)
    r4 = f(1)
    if r1 != 8
        say "FAIL H1.1"
        return 1
    end
    if r2 != 12
        say "FAIL H1.2"
        return 2
    end
    if r3 != 101
        say "FAIL H1.3"
        return 3
    end
    if r4 != 13
        say "FAIL H1.4"
        return 4
    end

    r5 = (|x| => x * 3)(7)
    if r5 != 21
        say "FAIL H1.5"
        return 5
    end

    r6 = make_ctr(20)(5)
    if r6 != 25
        say "FAIL H1.6"
        return 6
    end
    say "PASS H1: Mutable closures & inline lambdas verified"

    // ── H2: Native DICT0 HashMap + Rehash + Tombstones + List Coexistence ────
    d = { "a": 10, "b": 20 }
    d["c"] = 30
    d["a"] = 99
    if d["a"] != 99 or d["b"] != 20 or d["c"] != 30
        say "FAIL H2.1"
        return 7
    end
    if len(d) != 3 or has_key(d, "b") != 1
        say "FAIL H2.2"
        return 8
    end
    del_ok = del_key(d, "b")
    if del_ok != 1 or len(d) != 2 or has_key(d, "b") != 0 or d["b"] != 0
        say "FAIL H2.3"
        return 9
    end

    // List coexistence (32B header magic=0 never collides with DICT0)
    arr = [11, 22, 33]
    arr[1] = 222
    if len(arr) != 3 or arr[0] != 11 or arr[1] != 222 or arr[2] != 33
        say "FAIL H2.4"
        return 10
    end

    // Rehash stress + negative integer keys (18 keys forces 16 -> 32 -> 64 rehash)
    m = dict()
    i = 0
    while i < 18
        m[i - 5] = i * 7
        i += 1
    end
    if len(m) != 18 or m[0 - 5] != 0 or m[0] != 35 or m[12] != 119
        say "FAIL H2.5"
        return 11
    end
    say "PASS H2: DICT0 HashMap (literals, tombstones, rehash, int keys) verified"

    // ── H3: Native ByteBuffer + Heap-vs-Rodata String Key Equality ───────────
    b = buf_new(8)
    buf_write_str(b, "Lipi")
    buf_write_byte(b, 33)
    if buf_len(b) != 5
        say "FAIL H3.1"
        return 12
    end
    s = buf_to_str(b)
    if mem_byte_read(s, 0) != 76 or mem_byte_read(s, 4) != 33
        say "FAIL H3.2"
        return 13
    end
    d["Lipi!"] = 777
    if d[s] != 777 or has_key(d, s) != 1
        say "FAIL H3.3"
        return 14
    end
    say "PASS H3: ByteBuffer + cross-heap string dict lookup verified"

    // ── H4: LIFO defer Replay ────────────────────────────────────────────────
    log = list()
    rv = test_defer_lifo(log)
    if rv != 42 or len(log) != 2 or log[0] != 2 or log[1] != 1
        say "FAIL H4.1"
        return 15
    end
    say "PASS H4: LIFO defer replay verified"

    say "ALL WAVE H PARITY TESTS PASSED!"
    return 0
end
