// ==============================================================================
// Wave Y Sovereign Compiler, Runtime & Multi-Target Regression Suite:
//   Y1: CLI Multi-Target Combo (`lipc` & `lipi build` with `--target=arm64 --target=elf-kernel`,
//       `--target=arm64 --target=obj`, `--target=riscv64 --target=elf-kernel`, `--target=riscv64 --target=obj`)
//   Y2: `--kavach` Twin Verification (Authentic `utso/` Passes + User-Space Spoofed `file_open` Blocked)
//   Y3: Coroutine / Hardware Fiber (`coro_spawn_fiber`) + `gc_collect()` Safety & Root Retention
//   Y4: Multi-Target (`arm64`, `riscv64`, `wasm`) Live Parity (`union`, `trait`/`impl`, `dyn Trait`,
//       `async fn`/`await`, braced & indented `try`/`catch`/`throw`, `"{x}"` + `"${x + 1}"`)
//   Y5: `--strict-types` Nominal Soundness (Struct/Enum/List/Dict Mismatches Rejected; Valid Record/Trait Passes)
//   Y6: Expanded `--ssa-codegen` Coverage (`for a..b`, `for x in arr`, `MapLit`, `region`,
//       `arr[i] += v`, `LiteralNone`, non-interp `"{}"`, per-fn float container isolation)
//   Y7: Frontend & x86_64 Language Features + Strict Syntax Rejection (`dyn Trait`, variadics,
//       default params, tuple destructuring/swap, `${expr}`, and fail-fast syntax/lexer errors)
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/os/env"
import "src/runtime/async/coroutine"

fn wy_spawn(cmd_path, args, log_path)
    argv = syscall(9, 0, 192, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < args.len() and i < 20
        mem_word_write(argv, (i + 1) * 8, args[i])
        i = i + 1
    end
    mem_word_write(argv, (i + 1) * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(env, 0, "PATH=/usr/bin:/bin:/usr/local/bin")
    mem_word_write(env, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        if len(log_path) > 0
            fd = syscall(2, log_path, 577, 420)
            if fd >= 0
                syscall(33, fd, 1, 0, 0, 0, 0)
                syscall(33, fd, 2, 0, 0, 0, 0)
                syscall(3, fd, 0, 0, 0, 0, 0)
            end
        end
        syscall(59, cmd_path, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)
    end

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_st = mem_word_read(st, 0)
    sig = raw_st & 127
    rc = 0
    if sig != 0
        rc = 128 + sig
    else
        rc = (raw_st / 256) % 256
    end
    syscall(11, argv, 192, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn wy_unlink(path)
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0
end

fn wy_read_elf_machine(path)
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0 return 0 - 1 end
    hdr = malloc(64)
    n = syscall(0, fd, hdr, 64, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if n < 24
        free(hdr, 64)
        return 0 - 2
    end
    if (mem_byte_read(hdr, 0) & 255) != 127 or (mem_byte_read(hdr, 1) & 255) != 69 or (mem_byte_read(hdr, 2) & 255) != 76 or (mem_byte_read(hdr, 3) & 255) != 70
        free(hdr, 64)
        return 0 - 3
    end
    em = (mem_byte_read(hdr, 18) & 255) | ((mem_byte_read(hdr, 19) & 255) << 8)
    free(hdr, 64)
    return em
end

fn wy_find_node()
    if syscall(21, "/usr/bin/node", 1, 0, 0, 0, 0) == 0 return "/usr/bin/node" end
    if syscall(21, "/usr/local/bin/node", 1, 0, 0, 0, 0) == 0 return "/usr/local/bin/node" end
    pv = env_get("PATH")
    if len(pv) == 0 return "" end
    pos = 0
    plen = len(pv)
    while pos < plen
        cpos = pos
        while cpos < plen and str_char_at(pv, cpos) != 58
            cpos = cpos + 1
        end
        dir = str_sub(pv, pos, cpos)
        if len(dir) > 0
            cand = dir + "/node"
            if syscall(21, cand, 1, 0, 0, 0, 0) == 0
                return cand
            end
        end
        pos = cpos + 1
    end
    return ""
end

// ── Y3 Hardware Fiber Workers (gc_collect & exception-unwind safety) ─────────
fn wy_gc_fiber_worker(arg)
    acc = arg
    s1 = "fiber_root_alpha_" + str(arg)
    items = [10, 20, 30, 40]
    i = 0
    while i < 4
        junk = "temp_garbage_" + str(i) + "_" + str(arg)
        gc_collect()
        acc = acc + items[i]
        coro_yield_value(acc)
        i = i + 1
    end
    gc_collect()
    if s1 != "fiber_root_alpha_" + str(arg)
        return 0 - 999
    end
    return acc + len(s1)
end

fn wy_throw_fiber_worker(arg)
    s = "throw_root_" + str(arg)
    gc_collect()
    throw "wy_fiber_boom"
    return len(s)
end

fn main()
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    base = "/tmp/lipi_wy_" + str(pid)
    log_p = base + ".log"

    compiler = "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        compiler = "bin/lipc_bin"
    end

    // ── Y1: CLI Multi-Target Architecture + Format Combinations ──────────────
    y1_src = base + "_y1.lp"
    file_write(y1_src, "fn main\n    return 0\nend\n")
    y1_a64_k = base + "_y1_a64_k.elf"
    y1_a64_o = base + "_y1_a64.o"
    y1_rv_k = base + "_y1_rv_k.elf"
    y1_rv_o = base + "_y1_rv.o"

    if wy_spawn(compiler, [y1_src, y1_a64_k, "--target=arm64", "--target=elf-kernel"], log_p) != 0 or wy_read_elf_machine(y1_a64_k) != 183
        say "FAIL Y1a: lipc --target=arm64 --target=elf-kernel expected EM_AARCH64(183), got " + str(wy_read_elf_machine(y1_a64_k))
        exit(1)
    end
    if wy_spawn(compiler, [y1_src, y1_a64_o, "--target=arm64", "--target=obj"], log_p) != 0 or wy_read_elf_machine(y1_a64_o) != 183
        say "FAIL Y1b: lipc --target=arm64 --target=obj expected EM_AARCH64(183), got " + str(wy_read_elf_machine(y1_a64_o))
        exit(1)
    end
    if wy_spawn(compiler, [y1_src, y1_rv_k, "--target=riscv64", "--target=elf-kernel"], log_p) != 0 or wy_read_elf_machine(y1_rv_k) != 243
        say "FAIL Y1c: lipc --target=riscv64 --target=elf-kernel expected EM_RISCV(243), got " + str(wy_read_elf_machine(y1_rv_k))
        exit(1)
    end
    if wy_spawn(compiler, [y1_src, y1_rv_o, "--target=riscv64", "--target=obj"], log_p) != 0 or wy_read_elf_machine(y1_rv_o) != 243
        say "FAIL Y1d: lipc --target=riscv64 --target=obj expected EM_RISCV(243), got " + str(wy_read_elf_machine(y1_rv_o))
        exit(1)
    end
    if syscall(21, "bin/lipi", 1, 0, 0, 0, 0) == 0
        y1_cli_k = base + "_y1_cli_k.elf"
        if wy_spawn("bin/lipi", ["build", "--target=arm64", "--target=elf-kernel", y1_src, "-o", y1_cli_k], log_p) != 0 or wy_read_elf_machine(y1_cli_k) != 183
            say "FAIL Y1e: lipi build --target=arm64 --target=elf-kernel failed or overwrote arch"
            exit(1)
        end
        wy_unlink(y1_cli_k)
    end
    // Verify .lpo cache isolates target architectures (never poisons arm64 with x86_64 cached .o)
    y1_cdir = base + "_lpo_cache"
    syscall(83, y1_cdir, 493, 0, 0, 0, 0)
    y1_cx = base + "_y1_cx.o"
    y1_ca = base + "_y1_ca.o"
    if wy_spawn(compiler, [y1_src, y1_cx, "--cache-dir=" + y1_cdir, "--target=x86_64", "--target=obj"], log_p) != 0 or wy_read_elf_machine(y1_cx) != 62
        say "FAIL Y1f: cached x86_64 obj expected EM_X86_64(62)"
        exit(1)
    end
    if wy_spawn(compiler, [y1_src, y1_ca, "--cache-dir=" + y1_cdir, "--target=arm64", "--target=obj"], log_p) != 0 or wy_read_elf_machine(y1_ca) != 183
        say "FAIL Y1g: shared cache-dir poisoned arm64 obj with wrong arch: " + str(wy_read_elf_machine(y1_ca))
        exit(1)
    end
    wy_unlink(y1_cx)
    wy_unlink(y1_ca)
    wy_unlink(y1_src)
    wy_unlink(y1_a64_k)
    wy_unlink(y1_a64_o)
    wy_unlink(y1_rv_k)
    wy_unlink(y1_rv_o)
    say "  [PASS] Y1. CLI multi-target arch + format preservation & .lpo cache arch isolation (62/183/243)"

    // ── Y2: --kavach Twin Verification (Authentic utso/ OK + Spoof Blocked) ──
    y2_pos = base + "_y2_pos.lp"
    y2_pos_bin = base + "_y2_pos"
    file_write(y2_pos, "import \"utso/os/syscalls\"\nimport \"utso/core/fs\"\nimport \"utso/core/time\"\nimport \"utso/core/deflate\"\nfn main\n    t = time_now_utc()\n    gz = gzip_compress(\"kv_ok\")\n    d = gzip_decompress(gz)\n    if d.dr_ok != 1 or d.dr_data != \"kv_ok\" exit(1) end\n    say time_format_iso8601(t)\n    return 0\nend\n")
    if wy_spawn(compiler, [y2_pos, y2_pos_bin, "--kavach", "--strict-types"], log_p) != 0
        say "FAIL Y2a: authentic utso/ imports rejected under --kavach --strict-types: " + file_read(log_p)
        exit(1)
    end
    if wy_spawn(y2_pos_bin, [], log_p) != 0
        say "FAIL Y2b: --kavach stdlib binary failed execution"
        exit(1)
    end

    y2_spoof1 = base + "_y2_sp1.lp"
    y2_spoof1_bin = base + "_y2_sp1"
    file_write(y2_spoof1, "fn file_open()\n    return syscall(60, 42, 0, 0, 0, 0, 0)\nend\nfn main\n    return file_open()\nend\n")
    if wy_spawn(compiler, [y2_spoof1, y2_spoof1_bin, "--kavach"], log_p) == 0
        say "FAIL Y2c: --kavach security bypass! Spoofed user fn file_open() compiled!"
        exit(1)
    end

    y2_spoof2 = base + "_y2_sp2.lp"
    y2_spoof2_bin = base + "_y2_sp2"
    file_write(y2_spoof2, "fn _lipi_spoof()\n    return syscall(60, 42, 0, 0, 0, 0, 0)\nend\nfn main\n    return _lipi_spoof()\nend\n")
    if wy_spawn(compiler, [y2_spoof2, y2_spoof2_bin, "--kavach"], log_p) == 0
        say "FAIL Y2d: --kavach security bypass! Spoofed user fn _lipi_spoof() compiled!"
        exit(1)
    end
    lb = "{"
    y2_spoof3 = base + "_y2_sp3.lp"
    y2_spoof3_bin = base + "_y2_sp3"
    file_write(y2_spoof3, "fn evil(x = syscall(60, 42, 0, 0, 0, 0, 0)) { return x }\nfn main() { return evil() }\n")
    if wy_spawn(compiler, [y2_spoof3, y2_spoof3_bin, "--kavach"], log_p) == 0
        say "FAIL Y2e: --kavach security bypass! Default param syscall compiled!"
        exit(1)
    end
    y2_spoof4 = base + "_y2_sp4.lp"
    y2_spoof4_bin = base + "_y2_sp4"
    file_write(y2_spoof4, "fn main() {\n    s = \"$" + lb + "syscall(60, 42, 0, 0, 0, 0, 0)}\"\n    say s\n}\n")
    if wy_spawn(compiler, [y2_spoof4, y2_spoof4_bin, "--kavach"], log_p) == 0
        say "FAIL Y2f: --kavach security bypass! Interpolated string syscall compiled!"
        exit(1)
    end
    y2_spoof5 = base + "_y2_sp5.lp"
    y2_spoof5_bin = base + "_y2_sp5"
    file_write(y2_spoof5, "fn main() { throw syscall(60, 42, 0, 0, 0, 0, 0) }\n")
    if wy_spawn(compiler, [y2_spoof5, y2_spoof5_bin, "--kavach"], log_p) == 0
        say "FAIL Y2g: --kavach security bypass! Throw expression syscall compiled!"
        exit(1)
    end
    wy_unlink(y2_pos)
    wy_unlink(y2_pos_bin)
    wy_unlink(y2_spoof1)
    wy_unlink(y2_spoof1_bin)
    wy_unlink(y2_spoof2)
    wy_unlink(y2_spoof2_bin)
    wy_unlink(y2_spoof3)
    wy_unlink(y2_spoof3_bin)
    wy_unlink(y2_spoof4)
    wy_unlink(y2_spoof4_bin)
    wy_unlink(y2_spoof5)
    wy_unlink(y2_spoof5_bin)
    say "  [PASS] Y2. --kavach twin check (utso/ provenance passes + 5/5 spoof/default/interp/throw bypasses blocked)"

    // ── Y3: Hardware Fiber (coro_spawn_fiber) + gc_collect() & Unwind Safety ──
    fib_h = coro_spawn_fiber(fn_ptr(wy_gc_fiber_worker), 5, 65536)
    y3_v1 = coro_resume_fiber(fib_h)
    gc_collect()
    y3_v2 = coro_resume_fiber(fib_h)
    y3_v3 = coro_resume_fiber(fib_h)
    y3_v4 = coro_resume_fiber(fib_h)
    y3_v5 = coro_resume_fiber(fib_h)
    coro_destroy_fiber(fib_h)
    // 5+10=15, +20=35, +30=65, +40=105, final=105+len("fiber_root_alpha_5")(18)=123
    if y3_v1 != 15 or y3_v2 != 35 or y3_v3 != 65 or y3_v4 != 105 or y3_v5 != 123
        say "FAIL Y3a: fiber+gc values mismatch: " + str(y3_v1) + "," + str(y3_v2) + "," + str(y3_v3) + "," + str(y3_v4) + "," + str(y3_v5)
        exit(1)
    end
    // Exception unwind inside hardware fiber MUST restore _lipi_stack_bottom & G_CORO_ACTIVE_FIBER
    sb_before = mem_word_read(slab_buckets_ptr(), 80)
    fib_t = coro_spawn_fiber(fn_ptr(wy_throw_fiber_worker), 9, 65536)
    caught_fib = ""
    try
        coro_resume_fiber(fib_t)
    catch fe
        caught_fib = fe
    end
    sb_after = mem_word_read(slab_buckets_ptr(), 80)
    coro_destroy_fiber(fib_t)
    gc_collect()
    if caught_fib != "wy_fiber_boom" or sb_after != sb_before or G_CORO_ACTIVE_FIBER != 0
        say "FAIL Y3b: fiber exception unwind corrupted GC state: caught=" + caught_fib + " sb_eq=" + str(sb_after == sb_before) + " active=" + str(G_CORO_ACTIVE_FIBER)
        exit(1)
    end
    say "  [PASS] Y3. Hardware fiber (coro_spawn_fiber) + gc_collect() + exception-unwind stack_bottom safety"

    // ── Y4: Multi-Target (ARM64, RISC-V 64, WASM) Live Execution Parity ──────
    y4_src = base + "_y4.lp"
    y4_code = "union U32 { i: i64, u: u64 }\n"
    y4_code = y4_code + "trait Greet { fn hi(self) }\n"
    y4_code = y4_code + "struct SA { v: i64 }\n"
    y4_code = y4_code + "struct SB { v: i64 }\n"
    y4_code = y4_code + "impl Greet for SA {\n    fn hi(self) { return self.v + 1 }\n}\n"
    y4_code = y4_code + "impl Greet for SB {\n    fn hi(self) { return self.v + 20 }\n}\n"
    y4_code = y4_code + "async fn work()\n    return 42\nend\n"
    y4_code = y4_code + "fn catcher_braced() {\n    try {\n        throw 99\n    } catch e {\n        return e\n    }\n    return 0\n}\n"
    y4_code = y4_code + "fn catcher_indent()\n    try\n        throw 77\n    catch e\n        return e\n    end\n    return 0\nend\n"
    y4_code = y4_code + "fn sum_v(nums: ...int) {\n    s = 0\n    for v in nums { s = s + v }\n    return s\n}\n"
    y4_code = y4_code + "fn add_d(a, b = 10) { return a + b }\n"
    y4_code = y4_code + "fn mk_pair(n) { return n + 1, n + 2 }\n"
    y4_code = y4_code + "fn main() {\n"
    y4_code = y4_code + "    u = U32(55)\n"
    y4_code = y4_code + "    a = SA(10)\n"
    y4_code = y4_code + "    b = SB(10)\n"
    y4_code = y4_code + "    items: list<dyn Greet> = [a, b]\n"
    y4_code = y4_code + "    r_dyn = items[0].hi() + items[1].hi()\n"
    y4_code = y4_code + "    r_async = await work()\n"
    y4_code = y4_code + "    r_try = catcher_braced() + catcher_indent()\n"
    y4_code = y4_code + "    r_var = sum_v(10, 20, 30)\n"
    y4_code = y4_code + "    r_def = add_d(5) + add_d(5, 20)\n"
    y4_code = y4_code + "    ta, tb = 10, 20\n"
    y4_code = y4_code + "    ta, tb = tb, ta\n"
    y4_code = y4_code + "    tp, tq = mk_pair(10)\n"
    y4_code = y4_code + "    r_tup = ta * 1000 + tb * 100 + tp + tq\n"
    y4_code = y4_code + "    x = 7\n"
    y4_code = y4_code + "    say \"x=" + lb + "x},sum=$" + lb + "x + 1},v=$" + lb + "r_var},d=$" + lb + "r_def},t=$" + lb + "r_tup}\"\n"
    y4_code = y4_code + "    tot = u.i + r_dyn + r_async + r_try + r_var + r_def\n"
    y4_code = y4_code + "    say tot\n"
    y4_code = y4_code + "    return tot\n"
    y4_code = y4_code + "}\n"
    // Expected: u.i=55, r_dyn=41, r_async=42, r_try=176, r_var=60, r_def=40 -> tot=414; r_tup=20*1000+10*100+11+12=21023
    file_write(y4_src, y4_code)
    y4_a64 = base + "_y4_a64"
    y4_rv = base + "_y4_rv64"
    y4_wasm = base + "_y4.wasm"
    y4_out = base + "_y4.out"

    if wy_spawn(compiler, [y4_src, y4_a64, "--target=arm64"], log_p) != 0
        say "FAIL Y4a: arm64 compile failed: " + file_read(log_p)
        exit(1)
    end
    if wy_spawn(compiler, [y4_src, y4_rv, "--target=riscv64"], log_p) != 0
        say "FAIL Y4b: riscv64 compile failed: " + file_read(log_p)
        exit(1)
    end
    if wy_spawn(compiler, [y4_src, y4_wasm, "--target=wasm"], log_p) != 0
        say "FAIL Y4c: wasm compile failed: " + file_read(log_p)
        exit(1)
    end

    if syscall(21, "/usr/bin/qemu-aarch64", 1, 0, 0, 0, 0) == 0
        wy_spawn("/usr/bin/qemu-aarch64", [y4_a64], y4_out)
        o_a64 = file_read(y4_out)
        if str_contains(o_a64, "x=7,sum=8,v=60,d=40,t=21023") != 1 or str_contains(o_a64, "414") != 1
            say "FAIL Y4d: qemu-aarch64 output mismatch: " + o_a64
            exit(1)
        end
    end
    if syscall(21, "/usr/bin/qemu-riscv64", 1, 0, 0, 0, 0) == 0
        wy_spawn("/usr/bin/qemu-riscv64", [y4_rv], y4_out)
        o_rv = file_read(y4_out)
        if str_contains(o_rv, "x=7,sum=8,v=60,d=40,t=21023") != 1 or str_contains(o_rv, "414") != 1
            say "FAIL Y4e: qemu-riscv64 output mismatch: " + o_rv
            exit(1)
        end
    end
    node_bin = wy_find_node()
    if len(node_bin) > 0
        y4_js = base + "_y4_run.mjs"
        js_src = "import fs from 'fs';\n"
        js_src = js_src + "const bytes = fs.readFileSync(process.argv[2]);\n"
        js_src = js_src + "let mem; let out = '';\n"
        js_src = js_src + "const imp = { wasi_snapshot_preview1: { fd_write(fd, iovs, len, nwritten) {\n"
        js_src = js_src + "  const dv = new DataView(mem.buffer); let total = 0;\n"
        js_src = js_src + "  for (let i = 0; i < len; i++) {\n"
        js_src = js_src + "    const p = dv.getUint32(iovs + i*8, true); const l = dv.getUint32(iovs + i*8 + 4, true);\n"
        js_src = js_src + "    out += new TextDecoder().decode(new Uint8Array(mem.buffer, p, l)); total += l;\n"
        js_src = js_src + "  }\n"
        js_src = js_src + "  dv.setUint32(nwritten, total, true); return 0;\n"
        js_src = js_src + "} } };\n"
        js_src = js_src + "const { instance } = await WebAssembly.instantiate(bytes, imp);\n"
        js_src = js_src + "mem = instance.exports.memory;\n"
        js_src = js_src + "const ret = instance.exports.main();\n"
        js_src = js_src + "process.stdout.write(out + 'RET=' + String(ret) + '\\n');\n"
        file_write(y4_js, js_src)
        if wy_spawn(node_bin, [y4_js, y4_wasm], y4_out) != 0
            say "FAIL Y4f: node V8 wasm execution failed: " + file_read(y4_out)
            exit(1)
        end
        o_ws = file_read(y4_out)
        if str_contains(o_ws, "x=7,sum=8,v=60,d=40,t=21023") != 1 or str_contains(o_ws, "414") != 1 or str_contains(o_ws, "RET=414") != 1
            say "FAIL Y4g: node V8 wasm output mismatch: " + o_ws
            exit(1)
        end
        wy_unlink(y4_js)
    end
    wy_unlink(y4_src)
    wy_unlink(y4_a64)
    wy_unlink(y4_rv)
    wy_unlink(y4_wasm)
    wy_unlink(y4_out)
    say "  [PASS] Y4. Multi-target (ARM64 + RISC-V 64 + WASM V8) union/trait/dyn/async/try/interp/varargs/defaults/tuples/for-in parity"

    // ── Y5: --strict-types Nominal Soundness ─────────────────────────────────
    y5_neg_cases = [
        "struct User { id: i64 }\nfn ret_u() -> User { return 123 }\nfn main() { u = ret_u() }\n",
        "struct User { id: i64 }\nfn main() { u: User = 123 }\n",
        "struct User { id: i64 }\nfn ret_u() -> User { return {} }\nfn main() { u = ret_u() }\n",
        "struct User { id: i64 }\nfn ret_u() -> User { return {\"id\": 1} }\nfn main() { u = ret_u() }\n",
        "fn ret_l() -> list { return 123 }\nfn main() { x = ret_l() }\n",
        "fn ret_d() -> dict { return 123 }\nfn main() { x = ret_d() }\n",
        "enum Color { Red, Blue }\nfn ret_c() -> Color { return 123 }\nfn main() { c = ret_c() }\n",
        "struct User { id: i64 }\nfn ret_u() -> User { return { id: \"wrong\" } }\nfn main() { u = ret_u() }\n",
        "struct User { id: i64 }\nfn ret_lu() -> list<User> { return [123] }\nfn main() { x = ret_lu() }\n",
        "struct User { id: i64 }\nfn main() { xs: list<User> = [123] }\n",
        "trait Greet { fn hi(self) }\nstruct Dog { id: i64 }\nfn f(g: dyn Greet) { say g.hi() }\nfn main() { d = Dog(1); f(d) }\n",
        "trait Greet { fn hi(self) }\nstruct A { id: i64 }\nstruct Dog { id: i64 }\nimpl Greet for A { fn hi(self) { return \"A\" } }\nfn main() { xs: list<dyn Greet> = [A(1), Dog(2)] }\n",
        "struct User { id: i64 }\nfn main() { u: User = User(1); u, y = 123, 456 }\n"
    ]
    yi = 0
    while yi < y5_neg_cases.len()
        f_lp = base + "_y5_" + str(yi) + ".lp"
        f_bn = base + "_y5_" + str(yi)
        file_write(f_lp, y5_neg_cases[yi])
        rc_n = wy_spawn(compiler, [f_lp, f_bn, "--strict-types"], log_p)
        wy_unlink(f_lp)
        wy_unlink(f_bn)
        if rc_n == 0
            say "FAIL Y5: --strict-types accepted invalid typed case #" + str(yi)
            exit(1)
        end
        yi = yi + 1
    end
    y5_pos = base + "_y5_pos.lp"
    y5_pos_bin = base + "_y5_pos"
    file_write(y5_pos, "struct User { id: i64 }\nfn ok_rec() -> User { return { id: 7 } }\nfn main() {\n    u: User = ok_rec()\n    if u.id != 7 exit(1) end\n}\n")
    if wy_spawn(compiler, [y5_pos, y5_pos_bin, "--strict-types"], log_p) != 0 or wy_spawn(y5_pos_bin, [], log_p) != 0
        say "FAIL Y5p: valid structural record return failed --strict-types: " + file_read(log_p)
        exit(1)
    end
    wy_unlink(y5_pos)
    wy_unlink(y5_pos_bin)
    say "  [PASS] Y5. --strict-types nominal soundness (13/13 invalid rejected, valid record passed)"

    // ── Y6: Expanded --ssa-codegen Coverage & Float Container Isolation ──────
    y6_src = base + "_y6.lp"
    y6_bin = base + "_y6"
    y6_code = "fn ssa_for_range(n)\n    s = 0\n    for i in 1..n\n        s = s + i\n    end\n    return s\nend\n"
    y6_code = y6_code + "fn ssa_for_list()\n    arr = [1, 2, 3, 4]\n    s = 0\n    for x in arr\n        if x == 2 continue end\n        s = s + x\n    end\n    return s\nend\n"
    y6_code = y6_code + "fn ssa_map_braces()\n    d = {\"k\": 40}\n    a = [1, 2, 3]\n    a[1] += 5\n    s = \"body {margin:0}\"\n    return d[\"k\"] + a[1] + len(s)\nend\n"
    y6_code = y6_code + "fn main()\n    fd = {\"pi\": 3.5}\n    say fd[\"pi\"]\n    say ssa_for_range(5)\n    say ssa_for_list()\n    say ssa_map_braces()\nend\n"
    file_write(y6_src, y6_code)
    if wy_spawn(compiler, [y6_src, y6_bin], log_p) != 0
        say "FAIL Y6a: SSA test compile failed: " + file_read(log_p)
        exit(1)
    end
    y6_clog = file_read(log_p)
    if str_contains(y6_clog, "replaced 3/") != 1 and str_contains(y6_clog, "replaced 4/") != 1
        say "FAIL Y6b: expected >=3 SSA-lowered functions even with float dict in main: " + y6_clog
        exit(1)
    end
    y6_out = base + "_y6.out"
    if wy_spawn(y6_bin, [], y6_out) != 0
        say "FAIL Y6c: SSA binary failed execution"
        exit(1)
    end
    // ssa_for_range(5)=15, ssa_for_list([1,2,3,4])=8, ssa_map_braces()=40+7+15=62
    if file_read(y6_out) != "3.5\n15\n8\n62\n"
        say "FAIL Y6d: SSA runtime mismatch: " + file_read(y6_out)
        exit(1)
    end
    wy_unlink(y6_src)
    wy_unlink(y6_bin)
    wy_unlink(y6_out)
    say "  [PASS] Y6. Expanded --ssa-codegen (for range/list, MapLit, idx +=, non-interp braces, float isolation)"

    // ── Y7: Frontend Features + Strict Syntax & Arity Validation ─────────────
    y7_src = base + "_y7.lp"
    y7_bin = base + "_y7"
    y7_out = base + "_y7.out"
    y7_code = "trait Greet { fn hi(self) }\n"
    y7_code = y7_code + "struct A { x: i64 }\nstruct B { x: i64 }\n"
    y7_code = y7_code + "impl Greet for A { fn hi(self) { return self.x + 1 } }\n"
    y7_code = y7_code + "impl Greet for B { fn hi(self) { return self.x + 100 } }\n"
    y7_code = y7_code + "fn sum_v(nums: ...int) {\n    s = 0\n    i = 0\n    while i < nums.len() { s = s + nums[i]; i = i + 1 }\n    return s\n}\n"
    y7_code = y7_code + "fn f_def(a, b = 10, c = 5) { return a + b + c }\n"
    y7_code = y7_code + "fn pair(n) { return n * 2, n * 3 }\n"
    y7_code = y7_code + "fn main() {\n"
    y7_code = y7_code + "    items: list<dyn Greet> = [A(5), B(5)]\n"
    y7_code = y7_code + "    say items[0].hi()\n"
    y7_code = y7_code + "    say items[1].hi()\n"
    y7_code = y7_code + "    say sum_v()\n"
    y7_code = y7_code + "    say sum_v(1, 2, 3, 4)\n"
    y7_code = y7_code + "    say f_def(3)\n"
    y7_code = y7_code + "    say f_def(3, 20)\n"
    y7_code = y7_code + "    a, b = 10, 20\n"
    y7_code = y7_code + "    a, b = b, a\n"
    y7_code = y7_code + "    u, v = pair(7)\n"
    dlr = "$" + lb
    y7_code = y7_code + "    say \"a=" + dlr + "a},b=" + dlr + "b},u=" + dlr + "u},v=" + dlr + "v},expr=" + dlr + "f_def(3) * 2}\"\n"
    y7_code = y7_code + "    say \"${1:name}\"\n"
    y7_code = y7_code + "}\n"
    file_write(y7_src, y7_code)
    if wy_spawn(compiler, [y7_src, y7_bin, "--strict-types"], log_p) != 0
        say "FAIL Y7a: frontend features failed compile: " + file_read(log_p)
        exit(1)
    end
    if wy_spawn(y7_bin, [], y7_out) != 0
        say "FAIL Y7b: frontend features binary failed execution"
        exit(1)
    end
    if file_read(y7_out) != "6\n105\n0\n10\n18\n28\na=20,b=10,u=14,v=21,expr=36\n${1:name}\n"
        say "FAIL Y7c: frontend features output mismatch: " + file_read(y7_out)
        exit(1)
    end
    wy_unlink(y7_src)
    wy_unlink(y7_bin)
    wy_unlink(y7_out)

    // Negative strict syntax & arity rejection checks
    y7_bad = [
        "fn main() { x = \"unterminated }\n",
        "fn main() { x = (1 + 2 }\n",
        "fn main() { x = 1 + 2) }\n",
        "fn main() { = 5 }\n",
        "fn main() { 123 = 5 }\n",
        "fn main() { let = 5 }\n",
        "fn main() { x = }\n",
        "fn main() { a, = 1, 2 }\n",
        "fn f(a, b = 10) { return a + b }\nfn main() { say f() }\n",
        "fn f(a, b = 10) { return a + b }\nfn main() { say f(1, 2, 3) }\n",
        "fn f(a: ...int, b: int) { return b }\nfn main() { say f(1, 2) }\n",
        "fn f(a = 10, b) { return a + b }\nfn main() { say f(1, 2) }\n",
        "fn f(a b) { return a + b }\nfn main() { say f(1, 2) }\n",
        "fn main() { a, b, c = 1, 2 }\n",
        "fn main() { x = 1 +\nsay x }\n",
        "fn main() { x = 1; say \"v=$" + lb + "x\" }\n"
    ]
    bi = 0
    while bi < y7_bad.len()
        b_lp = base + "_y7b_" + str(bi) + ".lp"
        b_bn = base + "_y7b_" + str(bi)
        file_write(b_lp, y7_bad[bi])
        rc_b = wy_spawn(compiler, [b_lp, b_bn], log_p)
        if bi == 4 and rc_b != 0
            // Also verify literal-LHS inside `{ ... }` is rejected at Stage 1 on cross-targets (arm64)
            rc_b2 = wy_spawn(compiler, [b_lp, b_bn, "--target=arm64"], log_p)
            if rc_b2 == 0
                wy_unlink(b_lp)
                wy_unlink(b_bn)
                say "FAIL Y7d: malformed literal-LHS accepted on arm64 target!"
                exit(1)
            end
        end
        wy_unlink(b_lp)
        wy_unlink(b_bn)
        if rc_b == 0
            say "FAIL Y7d: malformed syntax case #" + str(bi) + " was silently accepted!"
            exit(1)
        end
        bi = bi + 1
    end
    wy_unlink(log_p)
    say "  [PASS] Y7. Frontend language features (dyn Trait, variadics, defaults, tuples, $" + lb + "expr}) + 16/16 strict syntax rejections"
    say "PASS: test_wave_y_sovereign_compiler_parity"
    return 0
end
