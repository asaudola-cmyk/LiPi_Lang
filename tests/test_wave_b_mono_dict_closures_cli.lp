// ==============================================================================
// Wave B Regression Test:
//   B1: Untyped Function Float Call-Site Monomorphization (add_untyped(1.25, 2.75))
//   B2: First-Class Silicon Dict Literals ({ "alpha": 10 }, {}, {:}, dict())
//       + Dynamic Auto-Resizing IntMap (utso/core/hashmap.lp)
//   B3a: Closure Mutable Upvalue Capture (outer + inner mutation, function + top-level)
//   B3b: Single-Line `if cond stmt1; stmt2 end` Semicolon Lookahead
//   B3c: CLI Order-Independent Flags (`lipi build --strict-types <f>`, `--kavach`)
// ==============================================================================

import "utso/core/hashmap"

// ── B1: Untyped vs Typed Float Functions ─────────────────────────────────────
fn add_untyped x y
    return x + y
end

fn add_typed(x: float, y: float) -> float
    return x + y
end

fn fma_untyped a b c
    return (a * b) + c
end

fn nested_untyped p q
    return add_untyped(p, q) - 1.5
end

// ── B2: Polymorphic Indexing Through Untyped Function ────────────────────────
fn read_poly container key
    return container[key]
end

// ── B3a: Top-Level Mutable Closure Capture + Cross-Function Global Capture ───
top_k = 10
top_cb = fn(x) => x + top_k
TOP_R1 = top_cb(7)
top_k = 100
TOP_R2 = top_cb(7)

g_top_k = 10
g_top_cb = fn(x) => x + g_top_k

fn test_b1_float_monomorphization()
    u_sum = add_untyped(1.25, 2.75)
    t_sum = add_typed(1.25, 2.75)
    if str(u_sum) != "4.0"
        print("FAIL B1: add_untyped(1.25, 2.75) expected 4.0 got " + str(u_sum))
        return 1
    end
    if str(t_sum) != "4.0"
        print("FAIL B1: add_typed(1.25, 2.75) expected 4.0 got " + str(t_sum))
        return 1
    end
    // Same untyped function must still work for integers!
    i_sum = add_untyped(17, 25)
    if i_sum != 42
        print("FAIL B1: add_untyped(17, 25) expected 42 got " + str(i_sum))
        return 1
    end
    // Mixed float + int promotion + FMA + nested untyped float call
    m_sum = add_untyped(1.25, 2)
    if str(m_sum) != "3.25"
        print("FAIL B1: add_untyped(1.25, 2) expected 3.25 got " + str(m_sum))
        return 1
    end
    f_val = fma_untyped(2.5, 4.0, 0.5)
    if str(f_val) != "10.5"
        print("FAIL B1: fma_untyped expected 10.5 got " + str(f_val))
        return 1
    end
    n_val = nested_untyped(3.25, 2.25)
    if str(n_val) != "4.0"
        print("FAIL B1: nested_untyped expected 4.0 got " + str(n_val))
        return 1
    end
    return 0
end

fn test_b2_silicon_dict_and_intmap()
    // 1. Exact user reproducer: built-in dict literal + string indexing + mutation
    d = { "alpha": 10, "beta": 20 }
    d["gamma"] = 30
    if d["alpha"] != 10 or d["beta"] != 20 or d["gamma"] != 30
        print("FAIL B2: dict literal lookup failed: " + str(d["alpha"]) + "," + str(d["gamma"]))
        return 1
    end
    if len(d) != 3
        print("FAIL B2: dict len expected 3 got " + str(len(d)))
        return 1
    end
    if has_key(d, "beta") != 1 or has_key(d, "missing") != 0
        print("FAIL B2: has_key failed")
        return 1
    end
    // Polymorphic read through untyped function + list compatibility
    if read_poly(d, "gamma") != 30
        print("FAIL B2: polymorphic dict read failed")
        return 1
    end
    arr = [111, 222, 333]
    if read_poly(arr, 1) != 222
        print("FAIL B2: polymorphic list read broken")
        return 1
    end
    // Overwrite + delete (backward-shift) + keys/values
    d["beta"] = 200
    if d["beta"] != 200 or len(d) != 3
        print("FAIL B2: dict overwrite failed")
        return 1
    end
    del_ok = del_key(d, "alpha")
    if del_ok != 1 or has_key(d, "alpha") != 0 or len(d) != 2
        print("FAIL B2: del_key failed")
        return 1
    end
    ks = keys(d)
    vs = values(d)
    if len(ks) != 2 or len(vs) != 2
        print("FAIL B2: keys/values len mismatch")
        return 1
    end
    vsum = vs[0] + vs[1]
    if vsum != 230
        print("FAIL B2: values sum expected 230 got " + str(vsum))
        return 1
    end

    // 2. Empty dict forms: {}, {:}, dict() + dynamic 400-key grow/rehash + GC survival
    e1 = {}
    e2 = {:}
    e3 = dict()
    e1["x"] = "hello"
    e2[42] = 999
    if e1["x"] != "hello" or e2[42] != 999
        print("FAIL B2: empty dict forms failed")
        return 1
    end
    i = 0
    while i < 400
        kstr = "key_" + str(i)
        e3[kstr] = i * 7
        i = i + 1
    end
    gc_collect()
    if len(e3) != 400
        print("FAIL B2: 400-key rehash len expected 400 got " + str(len(e3)))
        return 1
    end
    i = 0
    while i < 400
        kstr = "key_" + str(i)
        if e3[kstr] != i * 7
            print("FAIL B2: 400-key lookup mismatch at " + str(i))
            return 1
        end
        i = i + 1
    end

    // 3. Dynamic Auto-Resizing IntMap in utso/core/hashmap.lp (>256 entries, zero fixed cap)
    im = intmap_new(16)
    j = 0
    while j < 500
        intmap_set(im, j * 13 + 5, j * j + 1)
        j = j + 1
    end
    if intmap_len(im) != 500
        print("FAIL B2: IntMap len expected 500 got " + str(intmap_len(im)))
        return 1
    end
    j = 0
    while j < 500
        if intmap_get(im, j * 13 + 5) != j * j + 1
            print("FAIL B2: IntMap get mismatch at " + str(j))
            return 1
        end
        j = j + 1
    end
    if intmap_del(im, 5) != 1 or intmap_has(im, 5) != 0 or intmap_len(im) != 499
        print("FAIL B2: IntMap delete failed")
        return 1
    end
    intmap_free(im)
    return 0
end

fn test_b3_closures_and_inline_if()
    // 1. Exact user reproducer inside function: outer mutation seen by closure
    k = 10
    cb = fn(x) => x + k
    r1 = cb(5)
    k = 50
    r2 = cb(5)
    if r1 != 15 or r2 != 55
        print("FAIL B3a: closure mutable capture expected 15,55 got " + str(r1) + "," + str(r2))
        return 1
    end

    // 2. Top-level mutable closure capture (script-level reassignment)
    if TOP_R1 != 17 or TOP_R2 != 107
        print("FAIL B3a: top-level mutable closure expected 17,107 got " + str(TOP_R1) + "," + str(TOP_R2))
        return 1
    end
    // 2b. Cross-function mutable global captured by top-level closure
    gr1 = g_top_cb(7)
    g_top_k = 100
    gr2 = g_top_cb(7)
    if gr1 != 17 or gr2 != 107
        print("FAIL B3a: cross-fn global closure expected 17,107 got " + str(gr1) + "," + str(gr2))
        return 1
    end

    // 3. Inner mutation inside block closure persists across calls & reflects outside
    cnt = 0
    inc = fn(step) { cnt = cnt + step; return cnt }
    a = inc(3)
    b = inc(4)
    if a != 3 or b != 7 or cnt != 7
        print("FAIL B3a: inner-mutated closure expected 3,7,7 got " + str(a) + "," + str(b) + "," + str(cnt))
        return 1
    end

    // 4. Exact user reproducer: single-line `if 1 == 2 x = 1; x = 2 end`
    x = 0
    if 1 == 2 x = 1; x = 2 end
    if x != 0
        print("FAIL B3b: false single-line if leaked x=" + str(x))
        return 1
    end
    if 1 == 1 x = 1; x = x + 4 end
    if x != 5
        print("FAIL B3b: true single-line if expected x=5 got " + str(x))
        return 1
    end
    y = 0
    if 1 == 2 y = 1; y = 2 else y = 10; y = y + 7 end
    if y != 17
        print("FAIL B3b: single-line if/else expected y=17 got " + str(y))
        return 1
    end
    return 0
end

fn _wb_exec4 bin_p a1 a2 a3 a4
    argv = syscall(9, 0, 64, 3, 34, 0 - 1, 0)
    mem_word_write(argv, 0, bin_p)
    mem_word_write(argv, 8, a1)
    mem_word_write(argv, 16, a2)
    mem_word_write(argv, 24, a3)
    mem_word_write(argv, 32, a4)
    mem_word_write(argv, 40, 0)
    env = syscall(9, 0, 32, 3, 34, 0 - 1, 0)
    mem_word_write(env, 0, "PATH=/usr/local/bin:/usr/bin:/bin")
    mem_word_write(env, 8, 0)
    st = syscall(9, 0, 8, 3, 34, 0 - 1, 0)
    mem_word_write(st, 0, 0)
    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        // Silence child stdout/stderr during regression run
        dn = syscall(2, "/dev/null", 1, 0, 0, 0, 0)
        if dn >= 0
            syscall(33, dn, 1, 0, 0, 0, 0)
            syscall(33, dn, 2, 0, 0, 0, 0)
            syscall(3, dn, 0, 0, 0, 0, 0)
        end
        syscall(59, bin_p, argv, env, 0, 0, 0)
        syscall(231, 127, 0, 0, 0, 0, 0)
    end
    syscall(61, pid, st, 0, 0, 0, 0)
    raw = mem_word_read(st, 0)
    rc = (raw / 256) % 256
    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn test_b3c_cli_flag_order()
    // Verify `lipi build --strict-types <file>` and `lipi build --kavach <file>` when ./bin/lipi exists
    if syscall(21, "./bin/lipi", 1, 0, 0, 0, 0) != 0
        return 0
    end
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    src_p = "/tmp/lipi_wb_cli_" + str(pid) + ".lp"
    out1 = "/tmp/lipi_wb_out1_" + str(pid) + ".bin"
    out2 = "/tmp/lipi_wb_out2_" + str(pid) + ".bin"
    fd = syscall(2, src_p, 577, 420, 0, 0, 0)
    if fd < 0 return 1 end
    code_s = "fn main()\n    x = 40 + 2\n    if x == 42 return 0 end\n    return 1\nend\n"
    syscall(1, fd, code_s, str_len(code_s), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)

    // Invoke flags BEFORE filename: ./bin/lipi build --strict-types <src> <out>
    rc1 = _wb_exec4("./bin/lipi", "build", "--strict-types", src_p, out1)
    rc2 = _wb_exec4("./bin/lipi", "build", "--kavach", src_p, out2)
    ex1 = 0
    ex2 = 0
    if rc1 == 0 ex1 = _wb_exec4(out1, "", "", "", "") end
    if rc2 == 0 ex2 = _wb_exec4(out2, "", "", "", "") end
    syscall(87, src_p, 0, 0, 0, 0, 0)
    syscall(87, out1, 0, 0, 0, 0, 0)
    syscall(87, out2, 0, 0, 0, 0, 0)
    if rc1 != 0 or ex1 != 0
        print("FAIL B3c: lipi build --strict-types <file> failed rc=" + str(rc1) + " ex=" + str(ex1))
        return 1
    end
    if rc2 != 0 or ex2 != 0
        print("FAIL B3c: lipi build --kavach <file> failed rc=" + str(rc2) + " ex=" + str(ex2))
        return 1
    end
    return 0
end

fn main()
    if test_b1_float_monomorphization() != 0 return 1 end
    if test_b2_silicon_dict_and_intmap() != 0 return 2 end
    if test_b3_closures_and_inline_if() != 0 return 3 end
    if test_b3c_cli_flag_order() != 0 return 4 end
    print("PASS: test_wave_b_mono_dict_closures_cli (B1 float mono + B2 DICT0/IntMap + B3 mutable closures, inline if & CLI flag order)")
    return 0
end
