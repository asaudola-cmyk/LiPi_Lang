// ==============================================================================
// Wave S Sovereign Regression Suite (End-to-End 100% Pure LiPi Verification):
//   1. Live QEMU ARM64 (qemu-aarch64) & RISC-V 64 (qemu-riscv64) 12-Feature Parity
//   2. `lipi link` `.init_array` (`SHT_INIT_ARRAY=14`) Cross-Object Global Initializers
//      in Both Link Orders
//   3. macOS x86-64 Mach-O Hardening (Scoped Darwin `open` Flags 0x601/0x209 &
//      0..4-Arg Raw Linux `syscall(...)` -> `-ENOSYS (-78)` + User Constant Safety)
//   4. Scope-Aware Canonical Module Isolation (Diamond Shared `global` + `pub global`,
//      Same Alias Across Files, Struct Field / Param / `let` Shadowing, `/* */` & `@!`)
//   5. Expanded `--ssa-codegen` (Short-Circuit `if`/`while` `and`/`or`, `~`, `not`,
//      SysV Runtime Builtins `list`/`push`/`list_set`/`get`/`len`/`str`)
//   6. Production Server (`server_production.lp` + `server_production_tls.lp`):
//      TLS 1.3 Epoll Wiring, `413 Payload Too Large` DoS Cap, Automatic Slowloris
//      Idle Timeout Reaper, and `SO_REUSEPORT` Multi-Process Worker Pool
// ==============================================================================

import "utso/io"
import "utso/string"
include "utso/net/server_production.lp"

// ── Helper: Spawn process capturing stdout+stderr into a file ─────────────────
fn ws_spawn cmd_path args log_path
    argv = syscall(9, 0, 160, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < args.len() and i < 18
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
    syscall(11, argv, 160, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc

fn ws_unlink path
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0

fn ws_sleep_ms ms
    req = malloc(16)
    mem_word_write(req, 0, ms / 1000)
    mem_word_write(req, 8, (ms % 1000) * 1000000)
    syscall(35, req, 0, 0, 0, 0, 0)
    free(req, 16)
    return 0

fn ws_read_u16_le buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    return b0 | (b1 << 8)

fn ws_read_u32_le buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    b2 = mem_byte_read(buf, off + 2) & 255
    b3 = mem_byte_read(buf, off + 3) & 255
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

fn ws_read_u64_le buf off
    lo = ws_read_u32_le(buf, off)
    hi = ws_read_u32_le(buf, off + 4)
    return lo | (hi << 32)

fn ws_read_raw_file path sz_out_box
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        list_set(sz_out_box, 0, 0)
        return 0
    end
    fsize = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(8, fd, 0, 0, 0, 0, 0)
    if fsize <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        list_set(sz_out_box, 0, 0)
        return 0
    end
    buf = malloc(fsize + 8)
    got = 0
    while got < fsize
        n = syscall(0, fd, buf + got, fsize - got, 0, 0, 0)
        if n <= 0 break end
        got = got + n
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    list_set(sz_out_box, 0, got)
    return buf

fn ws_find_seq buf blen pat
    plen = pat.len()
    if plen <= 0 or blen < plen return 0 - 1 end
    i = 0
    lim = blen - plen
    while i <= lim
        if (mem_byte_read(buf, i) & 255) == pat[0]
            ok = 1
            j = 1
            while j < plen
                if (mem_byte_read(buf, i + j) & 255) != pat[j]
                    ok = 0
                    break
                end
                j = j + 1
            end
            if ok == 1
                return i
            end
        end
        i = i + 1
    end
    return 0 - 1

// ── Pure LiPi TCP Loopback Client Helper for S6 ──────────────────────────────
fn ws_tcp_connect_loopback port
    fd = syscall(41, 2, 1, 0, 0, 0, 0)
    if fd < 0 return 0 - 1 end
    addr = malloc(16)
    i = 0
    while i < 16
        mem_byte_write(addr, i, 0)
        i = i + 1
    end
    mem_byte_write(addr, 0, 2)
    mem_byte_write(addr, 1, 0)
    mem_byte_write(addr, 2, (port >> 8) & 255)
    mem_byte_write(addr, 3, port & 255)
    mem_byte_write(addr, 4, 127)
    mem_byte_write(addr, 5, 0)
    mem_byte_write(addr, 6, 0)
    mem_byte_write(addr, 7, 1)
    rc = syscall(42, fd, addr, 16, 0, 0, 0)
    free(addr, 16)
    if rc < 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return 0 - 1
    end
    return fd

fn ws_tcp_send_and_recv port payload
    fd = ws_tcp_connect_loopback(port)
    if fd < 0 return "" end
    plen = len(payload)
    sent = 0
    while sent < plen
        n = syscall(1, fd, payload + sent, plen - sent, 0, 0, 0)
        if n <= 0 break end
        sent = sent + n
    end
    rbuf = malloc(4096)
    out_b = buf_new(512)
    while 1 == 1
        nr = syscall(0, fd, rbuf, 4096, 0, 0, 0)
        if nr > 0
            buf_write_mem(out_b, rbuf, nr)
        else
            break
        end
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    free(rbuf, 4096)
    res = buf_to_str(out_b)
    buf_free(out_b)
    return res

// ── Section S6 Route Handlers ────────────────────────────────────────────────
fn ws_prod_ping req: ProdReq
    return "WORKER_OK:" + req.preq_path
end

fn ws_prod_setup srv
    prod_server_set_max_read_bytes(srv, 256)
    prod_server_set_idle_timeout(srv, 250)
    prod_route_add(srv, "GET", "/ping", ws_prod_ping)
    prod_route_add(srv, "POST", "/ping", ws_prod_ping)
    return 1
end

fn main
    compiler = "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        compiler = "bin/lipc_bin"
    end

    // ── S1. Live ARM64 (qemu-aarch64) & RISC-V 64 (qemu-riscv64) Parity ──────
    arch_src = "enum Res { Ok(int), Err(int) }\n"
    arch_src = arch_src + "struct Pt { x: int, y: int }\n"
    arch_src = arch_src + "fn fib n\n    if n <= 1 return n end\n    return fib(n - 1) + fib(n - 2)\nend\n"
    arch_src = arch_src + "fn unwrap_add x\n    v = x?\n    return Ok(v + 5)\nend\n"
    arch_src = arch_src + "fn trace_leaf\n    return stack_trace()\nend\n"
    arch_src = arch_src + "fn trace_top\n    return trace_leaf()\nend\n"
    arch_src = arch_src + "fn main\n"
    arch_src = arch_src + "    say 0\n    say -42\n    say fib(10)\n"
    arch_src = arch_src + "    a: u64 = 18446744071562067968\n    b: u64 = 4096\n"
    arch_src = arch_src + "    say a\n    if a > b\n        say 1\n    else\n        say 0\n    end\n"
    arch_src = arch_src + "    c: u64 = 18446744073709551614\n    d: u64 = 2\n    say (c / d)\n"
    arch_src = arch_src + "    p = Pt(11, 22)\n    say p.x + p.y\n"
    arch_src = arch_src + "    r = unwrap_add(Ok(37))\n    match r { Ok(k) => say k, Err(e) => say e }\n"
    arch_src = arch_src + "    m = dict()\n    m[\"k\"] = 99\n    say m[\"k\"]\n"
    arch_src = arch_src + "    if (3 > 2) and (1 < 4) and not (5 == 6)\n        say 77\n    end\n"
    arch_src = arch_src + "    caught = 0\n    try\n        np: Pt = 0\n        say np.x\n    catch e\n        caught = 1\n    end\n    say caught\n"
    arch_src = arch_src + "    tr = trace_top()\n    say tr\n"
    arch_src = arch_src + "    xs = [10, 20, 30]\n    say xs[-1]\n"
    arch_src = arch_src + "end\n"
    file_write("/tmp/lipi_ws_arch.lp", arch_src)
    expected_prefix = "0\n-42\n55\n18446744071562067968\n1\n9223372036854775807\n33\n42\n99\n77\n1\n"

    if ws_spawn(compiler, ["/tmp/lipi_ws_arch.lp", "/tmp/lipi_ws_arm64", "--target=arm64"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S1a arm64 compile"
        exit(1)
    end
    if ws_spawn(compiler, ["/tmp/lipi_ws_arch.lp", "/tmp/lipi_ws_rv64", "--target=riscv64"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S1b riscv64 compile"
        exit(1)
    end
    if syscall(21, "/usr/bin/qemu-aarch64", 1, 0, 0, 0, 0) == 0
        if ws_spawn("/usr/bin/qemu-aarch64", ["/tmp/lipi_ws_arm64"], "/tmp/lipi_ws_a64_out.txt") != 0
            say "FAIL S1c qemu-aarch64 run"
            exit(1)
        end
        a64_out = file_read("/tmp/lipi_ws_a64_out.txt")
        if str_contains(a64_out, expected_prefix) != 1 or str_contains(a64_out, "trace_leaf") != 1 or str_contains(a64_out, "trace_top") != 1 or str_contains(a64_out, "\n30\n") != 1
            say "FAIL S1d qemu-aarch64 output mismatch: " + a64_out
            exit(1)
        end
    end
    if syscall(21, "/usr/bin/qemu-riscv64", 1, 0, 0, 0, 0) == 0
        if ws_spawn("/usr/bin/qemu-riscv64", ["/tmp/lipi_ws_rv64"], "/tmp/lipi_ws_rv64_out.txt") != 0
            say "FAIL S1e qemu-riscv64 run"
            exit(1)
        end
        rv64_out = file_read("/tmp/lipi_ws_rv64_out.txt")
        if str_contains(rv64_out, expected_prefix) != 1 or str_contains(rv64_out, "trace_leaf") != 1 or str_contains(rv64_out, "trace_top") != 1 or str_contains(rv64_out, "\n30\n") != 1
            say "FAIL S1f qemu-riscv64 output mismatch: " + rv64_out
            exit(1)
        end
    end
    ws_unlink("/tmp/lipi_ws_arch.lp")
    ws_unlink("/tmp/lipi_ws_arm64")
    ws_unlink("/tmp/lipi_ws_rv64")
    ws_unlink("/tmp/lipi_ws_a64_out.txt")
    ws_unlink("/tmp/lipi_ws_rv64_out.txt")

    // ── S2. `lipi link` `.init_array` Cross-Object Global Initializers ────────
    file_write("/tmp/lipi_ws_lib1.lp", "global g_magic = 42\nglobal g_items = [10, 20, 30]\nfn get_magic\n    return g_magic + g_items[0] + g_items[2]\nend\n")
    file_write("/tmp/lipi_ws_lib2.lp", "global g_mult = 3\nfn scale_val x\n    return x * g_mult\nend\n")
    file_write("/tmp/lipi_ws_app.lp", "extern fn get_magic()\nextern fn scale_val(x)\nfn main\n    m = get_magic()\n    say m\n    say scale_val(m)\nend\n")
    if ws_spawn(compiler, ["-c", "/tmp/lipi_ws_lib1.lp", "/tmp/lipi_ws_lib1.o"], "/tmp/lipi_ws_log.txt") != 0 or ws_spawn(compiler, ["-c", "/tmp/lipi_ws_lib2.lp", "/tmp/lipi_ws_lib2.o"], "/tmp/lipi_ws_log.txt") != 0 or ws_spawn(compiler, ["-c", "/tmp/lipi_ws_app.lp", "/tmp/lipi_ws_app.o"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S2a compile .o files"
        exit(1)
    end
    // Verify lib1.o contains a real ELF64 SHT_INIT_ARRAY (type == 14) section header
    sz_box = [0]
    obj_buf = ws_read_raw_file("/tmp/lipi_ws_lib1.o", sz_box)
    obj_sz = sz_box[0]
    if obj_buf == 0 or obj_sz < 64
        say "FAIL S2b read lib1.o"
        exit(1)
    end
    e_shoff = ws_read_u64_le(obj_buf, 40)
    e_shentsize = ws_read_u16_le(obj_buf, 58)
    e_shnum = ws_read_u16_le(obj_buf, 60)
    found_init_array = 0
    shi = 0
    while shi < e_shnum
        sh_type = ws_read_u32_le(obj_buf, e_shoff + (shi * e_shentsize) + 4)
        if sh_type == 14
            found_init_array = 1
            break
        end
        shi = shi + 1
    end
    free(obj_buf, obj_sz + 8)
    if found_init_array != 1
        say "FAIL S2c SHT_INIT_ARRAY missing from lib1.o"
        exit(1)
    end
    if ws_spawn(compiler, ["link", "/tmp/lipi_ws_lib1.o", "/tmp/lipi_ws_lib2.o", "/tmp/lipi_ws_app.o", "-o", "/tmp/lipi_ws_lnk1"], "/tmp/lipi_ws_log.txt") != 0 or ws_spawn(compiler, ["link", "/tmp/lipi_ws_app.o", "/tmp/lipi_ws_lib2.o", "/tmp/lipi_ws_lib1.o", "-o", "/tmp/lipi_ws_lnk2"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S2d link .o files in both orders"
        exit(1)
    end
    if ws_spawn("/tmp/lipi_ws_lnk1", [], "/tmp/lipi_ws_out1.txt") != 0 or ws_spawn("/tmp/lipi_ws_lnk2", [], "/tmp/lipi_ws_out2.txt") != 0
        say "FAIL S2e run linked binaries"
        exit(1)
    end
    if file_read("/tmp/lipi_ws_out1.txt") != "82\n246\n" or file_read("/tmp/lipi_ws_out2.txt") != "82\n246\n"
        say "FAIL S2f init_array output mismatch"
        exit(1)
    end
    ws_unlink("/tmp/lipi_ws_lib1.lp")
    ws_unlink("/tmp/lipi_ws_lib2.lp")
    ws_unlink("/tmp/lipi_ws_app.lp")
    ws_unlink("/tmp/lipi_ws_lib1.o")
    ws_unlink("/tmp/lipi_ws_lib2.o")
    ws_unlink("/tmp/lipi_ws_app.o")
    ws_unlink("/tmp/lipi_ws_lnk1")
    ws_unlink("/tmp/lipi_ws_lnk2")

    // ── S3. macOS x86-64 Mach-O Hardening (Darwin open flags + -ENOSYS) ──────
    file_write("/tmp/lipi_ws_mac.lp", "import \"utso/io\"\nfn main\n    u_const = 577\n    file_write(\"/tmp/t.txt\", \"hi\")\n    file_append(\"/tmp/t.txt\", \"!\")\n    r1 = syscall(39)\n    r2 = syscall(1, 1, 0, 0)\n    say u_const + r1 + r2\nend\n")
    if ws_spawn(compiler, ["/tmp/lipi_ws_mac.lp", "/tmp/lipi_ws_mac", "--target=macos-x86_64"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S3a macos-x86_64 compile"
        exit(1)
    end
    msz_box = [0]
    mbuf = ws_read_raw_file("/tmp/lipi_ws_mac", msz_box)
    msz = msz_box[0]
    if mbuf == 0 or msz < 4096 or ws_read_u32_le(mbuf, 0) != 4277009103
        say "FAIL S3b invalid Mach-O 64 magic"
        exit(1)
    end
    // Check Darwin O_CREAT|O_TRUNC|O_WRONLY (0x601: 0xBE 01 06 00 00) & O_APPEND (0x209: 0xBE 09 02 00 00) & -ENOSYS (push -78; pop rax = 6A B2 58)
    has_601 = ws_find_seq(mbuf, msz, [190, 1, 6, 0, 0])
    has_209 = ws_find_seq(mbuf, msz, [190, 9, 2, 0, 0])
    has_enosys = ws_find_seq(mbuf, msz, [106, 178, 88])
    // Ensure user constant 577 (0x0241 = 0x41 0x02) in movabs rax, 577 (48 B8 41 02 00 00 00 00 00 00) was NOT corrupted to 0x601
    has_user_577 = ws_find_seq(mbuf, msz, [72, 184, 65, 2, 0, 0, 0, 0, 0, 0])
    free(mbuf, msz + 8)
    if has_601 < 0 or has_209 < 0 or has_enosys < 0 or has_user_577 < 0
        say "FAIL S3c Mach-O Darwin translation markers missing"
        exit(1)
    end
    ws_unlink("/tmp/lipi_ws_mac.lp")
    ws_unlink("/tmp/lipi_ws_mac")

    // ── S4. Scope-Aware Canonical Module Isolation + Shared Diamond Global ───
    file_write("/tmp/lipi_ws_shared.lp", "pub global g_hits = 0\nglobal counter = 10\npub fn bump() {\n    g_hits = g_hits + 1\n    counter = counter + 5\n    return g_hits * 100 + counter\n}\n")
    file_write("/tmp/lipi_ws_m1.lp", "import \"lipi_ws_shared\" as s\npub struct Box { val: int }\nlet val = 999\npub fn make_val(val: int) -> int {\n    /* block comment mentioning m.foo and s.bump */\n    @! doc comment mentioning val\n    b = Box(val + 1)\n    let x = b.val\n    return x + s.bump()\n}\n")
    file_write("/tmp/lipi_ws_m2.lp", "import \"lipi_ws_shared\" as s\npub fn compute(k: int) -> int {\n    return k * 2 + s.bump()\n}\n")
    file_write("/tmp/lipi_ws_moda.lp", "import \"lipi_ws_m1\" as m\npub fn run_a() -> int { return m.make_val(10) }\n")
    file_write("/tmp/lipi_ws_modb.lp", "import \"lipi_ws_m2\" as m\npub fn run_b() -> int { return m.compute(5) }\n")
    file_write("/tmp/lipi_ws_modmain.lp", "import \"lipi_ws_moda\" as a\nimport \"lipi_ws_modb\" as b\nfn main() {\n    say a.run_a()\n    say b.run_b()\n    say a.run_a()\n}\n")
    if ws_spawn(compiler, ["/tmp/lipi_ws_modmain.lp", "/tmp/lipi_ws_modbin"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S4a canonical module compile"
        exit(1)
    end
    if ws_spawn("/tmp/lipi_ws_modbin", [], "/tmp/lipi_ws_out1.txt") != 0 or file_read("/tmp/lipi_ws_out1.txt") != "126\n230\n336\n"
        say "FAIL S4b canonical module output mismatch: " + file_read("/tmp/lipi_ws_out1.txt")
        exit(1)
    end
    ws_unlink("/tmp/lipi_ws_shared.lp")
    ws_unlink("/tmp/lipi_ws_m1.lp")
    ws_unlink("/tmp/lipi_ws_m2.lp")
    ws_unlink("/tmp/lipi_ws_moda.lp")
    ws_unlink("/tmp/lipi_ws_modb.lp")
    ws_unlink("/tmp/lipi_ws_modmain.lp")
    ws_unlink("/tmp/lipi_ws_modbin")

    // ── S5. Expanded `--ssa-codegen` (Short-Circuit `if`/`while` + `~` + Builtins) ──
    ssa_s = "struct Node { v: int }\n"
    ssa_s = ssa_s + "fn sc_guard(n: Node) -> int {\n    if n != 0 and n.v > 5 { return n.v }\n    return 0\n}\n"
    ssa_s = ssa_s + "fn while_sc(limit: int) -> int {\n    i = 0\n    s = 0\n    while i < limit and s < 20 {\n        s = s + i\n        i = i + 1\n    }\n    return s * 100 + i\n}\n"
    ssa_s = ssa_s + "fn logic_and_list(a: int, b: int) -> int {\n    if a == 0 or b == 0 { return (~0) + 2 }\n    xs = list()\n    push(xs, a)\n    push(xs, b)\n    list_set(xs, 0, a + 10)\n    return get(xs, 0) + get(xs, 1) + len(xs) + len(str(12345))\n}\n"
    ssa_s = ssa_s + "fn main() {\n    say sc_guard(0)\n    say sc_guard(Node(42))\n    say logic_and_list(0, 5)\n    say logic_and_list(3, 7)\n    say while_sc(100)\n}\n"
    file_write("/tmp/lipi_ws_ssa.lp", ssa_s)
    if ws_spawn(compiler, ["/tmp/lipi_ws_ssa.lp", "/tmp/lipi_ws_ssabin", "--ssa-codegen"], "/tmp/lipi_ws_ssalog.txt") != 0
        say "FAIL S5a --ssa-codegen compile"
        exit(1)
    end
    ssa_log = file_read("/tmp/lipi_ws_ssalog.txt")
    if str_contains(ssa_log, "replaced 3/4 functions directly from SSA CFG") != 1
        say "FAIL S5b expected 3/4 SSA CFG replacement"
        exit(1)
    end
    if ws_spawn("/tmp/lipi_ws_ssabin", [], "/tmp/lipi_ws_out1.txt") != 0 or file_read("/tmp/lipi_ws_out1.txt") != "0\n42\n1\n27\n2107\n"
        say "FAIL S5c --ssa-codegen output mismatch"
        exit(1)
    end
    ws_unlink("/tmp/lipi_ws_ssa.lp")
    ws_unlink("/tmp/lipi_ws_ssabin")
    ws_unlink("/tmp/lipi_ws_ssalog.txt")

    // ── S6. Production Server TLS 1.3 Wiring + 413 DoS Cap + Slowloris Reaper + Workers ──
    file_write("/tmp/lipi_ws_tls_chk.lp", "include \"utso/net/server_production_tls.lp\"\nfn h req: ProdReq\n    return \"OK\"\nend\nfn main\n    eng = tls13_record_engine_new()\n    srv = prod_server_create(19459, 16)\n    prod_server_enable_tls13(srv, eng)\n    prod_route_add(srv, \"GET\", \"/\", h)\n    say \"TLS_WIRED\"\nend\n")
    if ws_spawn(compiler, ["/tmp/lipi_ws_tls_chk.lp", "/tmp/lipi_ws_tls_bin"], "/tmp/lipi_ws_log.txt") != 0
        say "FAIL S6a server_production_tls.lp compile"
        exit(1)
    end
    if ws_spawn("/tmp/lipi_ws_tls_bin", [], "/tmp/lipi_ws_out1.txt") != 0 or file_read("/tmp/lipi_ws_out1.txt") != "TLS_WIRED\n"
        say "FAIL S6b server_production_tls.lp smoke"
        exit(1)
    end
    ws_unlink("/tmp/lipi_ws_tls_chk.lp")
    ws_unlink("/tmp/lipi_ws_tls_bin")

    // Live SO_REUSEPORT 2-worker epoll server + 200 OK + 413 DoS Cap + Slowloris Idle Reaper
    srv_pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if srv_pid == 0
        prod_server_run_workers(19458, 32, 2, ws_prod_setup, 45, 25)
        syscall(60, 0, 0, 0, 0, 0, 0)
    end
    ws_sleep_ms(120)

    r_ok = ws_tcp_send_and_recv(19458, "GET /ping HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    if str_contains(r_ok, "200 OK") != 1 or str_contains(r_ok, "WORKER_OK:/ping") != 1
        say "FAIL S6c worker 200 OK failed: " + r_ok
        syscall(62, srv_pid, 9, 0, 0, 0, 0)
        exit(1)
    end

    // Oversized POST > 256 bytes -> must return 413 Payload Too Large
    big_body = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    big_body = big_body + big_body + big_body + big_body + big_body
    r_413 = ws_tcp_send_and_recv(19458, "POST /ping HTTP/1.1\r\nHost: localhost\r\nContent-Length: 320\r\n\r\n" + big_body)
    if str_contains(r_413, "413 Payload Too Large") != 1
        say "FAIL S6d expected 413 Payload Too Large, got: " + r_413
        syscall(62, srv_pid, 9, 0, 0, 0, 0)
        exit(1)
    end

    // Slowloris half-sent request -> idle timeout 250ms must auto-reap connection (EOF)
    sfd = ws_tcp_connect_loopback(19458)
    if sfd < 0
        say "FAIL S6e slowloris connect"
        syscall(62, srv_pid, 9, 0, 0, 0, 0)
        exit(1)
    end
    half_req = "GET /slow "
    syscall(1, sfd, half_req, len(half_req), 0, 0, 0)
    ws_sleep_ms(450)
    sbuf = malloc(64)
    sn = syscall(0, sfd, sbuf, 64, 0, 0, 0)
    free(sbuf, 64)
    syscall(3, sfd, 0, 0, 0, 0, 0)
    if sn != 0
        say "FAIL S6f Slowloris socket not reaped (read=" + str(sn) + ")"
        syscall(62, srv_pid, 9, 0, 0, 0, 0)
        exit(1)
    end

    // Wait cleanly for worker pool to finish its ticks & reap child
    wst = malloc(8)
    syscall(61, srv_pid, wst, 0, 0, 0, 0)
    free(wst, 8)

    ws_unlink("/tmp/lipi_ws_log.txt")
    ws_unlink("/tmp/lipi_ws_out1.txt")
    ws_unlink("/tmp/lipi_ws_out2.txt")

    say "PASS: Wave S (ARM64/RV64 QEMU + .init_array + Mach-O + Canonical Modules + SSA + TLS/Workers)"
    return 0
end

main()
