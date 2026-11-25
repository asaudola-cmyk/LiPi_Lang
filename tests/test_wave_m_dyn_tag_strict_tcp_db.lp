// ==============================================================================
// WAVE M REGRESSION TEST: dyn_tagged Flow Sensitivity + Strict Anonymous Struct
// Collision Detection + Named TcpStream/TcpListener/UdpSocket/LipiDatabase Fields
// ==============================================================================

import "utso/core/db"
import "utso/net/tcp"
import "utso/net/udp"
import "utso/net/http"

fn wm_assert cond msg
    if cond == 0
        say "FAIL [Wave M]: " + msg
        exit(1)
    end
    return 0

fn dirty_stack
    // WHY: Pollutes stack memory below caller's %rbp with qword value 1 (float val_tag)
    // to catch any uninitialized [rbp - lv_tag_off] slot deterministically.
    a1 = 1
    a2 = 1
    a3 = 1
    a4 = 1
    a5 = 1
    a6 = 1
    a7 = 1
    a8 = 1
    a9 = 1
    a10 = 1
    a11 = 1
    a12 = 1
    a13 = 1
    a14 = 1
    a15 = 1
    a16 = 1
    a17 = 1
    a18 = 1
    a19 = 1
    a20 = 1
    a21 = 1
    a22 = 1
    a23 = 1
    a24 = 1
    return a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12 + a13 + a14 + a15 + a16 + a17 + a18 + a19 + a20 + a21 + a22 + a23 + a24

fn parse_price cond t
    whole = 80
    frac = 0
    if cond == 1
        c = t[0]
        frac = frac + (c - 48)
    end
    res = (whole * 100) + frac
    return res

fn parse_price_dict cond d
    whole = 80
    frac = 0
    if cond == 1
        c = d["c"]
        frac = frac + (c - 48)
    end
    res = (whole * 100) + frac
    return res

fn float_before_untaken_if cond d
    x = 1.5
    if cond == 1
        x = d["v"]
    end
    return x + 1.0

fn branch_merge_sync cond d
    if cond == 1
        x = d["pi"]
    else
        x = 42
    end
    return x + 1

fn sum_dyn_while d keys n
    acc = 0
    i = 0
    while i < n
        k = keys[i]
        v = d[k]
        acc = acc + v
        i = i + 1
    end
    return acc

fn compound_dyn_float d
    acc = 0
    acc += d["pi"]
    acc += 1.0
    return acc

fn compound_dyn_int d
    k = d["n"]
    k += 8
    k *= 2
    k -= 4
    return k

fn param_dyn_rebind x: f64 cond d
    if cond == 1
        x = d["n"]
    end
    return x + 0.5

fn check_stream_fd_typed s: TcpStream
    return s.tcp_fd

fn main
    // 1. Exact dirty-stack untaken-if dyn_tagged bug (parse_price)
    dirty_stack()
    r0 = parse_price(0, [53])
    wm_assert(r0 == 8000, "parse_price(0, [53]) expected 8000, got " + str(r0))
    wm_assert(str(r0) == "8000", "str(parse_price(0)) expected '8000', got " + str(r0))

    dirty_stack()
    r1 = parse_price(1, [53])
    wm_assert(r1 == 8005, "parse_price(1, [53]) expected 8005, got " + str(r1))
    wm_assert(str(r1) == "8005", "str(parse_price(1,[53])) expected '8005'")

    dirty_stack()
    df = { "c": 53.5 }
    r2 = parse_price_dict(1, df)
    wm_assert(r2 > 8005.4 and r2 < 8005.6, "parse_price_dict(1, {c:53.5}) expected 8005.5, got " + str(r2))
    dirty_stack()
    r2z = parse_price_dict(0, df)
    wm_assert(r2z == 8000 and str(r2z) == "8000", "parse_price_dict(0, df) expected 8000, got " + str(r2z))

    // 2. Float initialized before untaken if that assigns dyn_tagged
    d_int = { "v": 10 }
    dirty_stack()
    f0 = float_before_untaken_if(0, d_int)
    wm_assert(f0 > 2.49 and f0 < 2.51, "float_before_untaken_if(0) expected 2.5, got " + str(f0))
    dirty_stack()
    f1 = float_before_untaken_if(1, d_int)
    wm_assert(f1 > 10.99 and f1 < 11.01, "float_before_untaken_if(1, {v:10}) expected 11.0, got " + str(f1))

    // 3. if/else branch merge stale-tag sync
    d = { "pi": 3.14, "n": 42 }
    dirty_stack()
    m1 = branch_merge_sync(1, d)
    wm_assert(m1 > 4.13 and m1 < 4.15, "branch_merge_sync(1) expected 4.14, got " + str(m1))
    dirty_stack()
    m0 = branch_merge_sync(0, d)
    wm_assert(m0 == 43, "branch_merge_sync(0) expected 43, got " + str(m0))
    wm_assert(str(m0) == "43", "str(branch_merge_sync(0)) expected '43'")

    // 4. Loop-carried indirect dyn_tagged accumulator in while loop
    df_sum = { "a": 1.5, "b": 2.5, "c": 3.0 }
    di_sum = { "a": 10, "b": 20, "c": 30 }
    ks = ["a", "b", "c"]
    dirty_stack()
    sf = sum_dyn_while(df_sum, ks, 3)
    wm_assert(sf > 6.99 and sf < 7.01, "sum_dyn_while floats expected 7.0, got " + str(sf))
    dirty_stack()
    si = sum_dyn_while(di_sum, ks, 3)
    wm_assert(si == 60 and str(si) == "60", "sum_dyn_while ints expected 60, got " + str(si))

    // 5. Compound assignment (+=, -=, *=) on dyn_tagged variables
    dirty_stack()
    cf = compound_dyn_float(d)
    wm_assert(cf > 4.13 and cf < 4.15, "compound_dyn_float expected 4.14")
    dirty_stack()
    ci = compound_dyn_int(d)
    wm_assert(ci == 96 and str(ci) == "96", "compound_dyn_int expected 96")

    // 6. Typed parameter reassigned to dyn_tagged inside conditional branch
    dirty_stack()
    p0 = param_dyn_rebind(2.0, 0, d)
    wm_assert(p0 > 2.49 and p0 < 2.51, "param_dyn_rebind(2.0, 0) expected 2.5")
    dirty_stack()
    p1 = param_dyn_rebind(2.0, 1, d)
    wm_assert(p1 > 42.49 and p1 < 42.51, "param_dyn_rebind(2.0, 1) expected 42.5")

    // 7. Zero field-offset collision across LipiDatabase + TcpListener + TcpStream + UdpSocket + HTTP
    db_path = "/tmp/lipi_wave_m_wal.db"
    syscall(87, db_path, 0, 0, 0, 0, 0)
    db = db_open(db_path)
    wm_assert(db.wdb_fd >= 3, "db.wdb_fd must be valid open fd >= 3")
    db = db_insert(db, "k_wave_m", "v_sovereign")
    wm_assert(db_get(db, "k_wave_m") == "v_sovereign", "db_get must return stored value")

    lst = tcp_listener_bind("127.0.0.1", 0)
    raw_lst_fd = mem_word_read(lst, 0)
    wm_assert(lst.tcpl_fd >= 3, "lst.tcpl_fd must be valid open socket fd >= 3")
    wm_assert(lst.tcpl_fd == raw_lst_fd, "lst.tcpl_fd must read offset 0, not LipiDatabase offset 64")
    tcp_listener_close(lst)
    wm_assert(lst.tcpl_fd == -1, "tcp_listener_close must reset tcpl_fd to -1")

    fake_st = TcpStream(77, "127.0.0.1", 8080, "")
    wm_assert(check_stream_fd_typed(fake_st) == 77, "TcpStream.tcp_fd typed accessor must read 77")
    wm_assert(mem_word_read(fake_st, 0) == 77, "TcpStream.tcp_fd must reside at offset 0")

    u = udp_socket_bind("127.0.0.1", 0, 0)
    wm_assert(u.udp_fd >= 3 and u.udp_fd == mem_word_read(u, 0), "UdpSocket.udp_fd must be valid fd at offset 0")
    udp_socket_close(u)
    wm_assert(u.udp_fd == -1, "udp_socket_close must reset udp_fd to -1")

    db_close(db)
    wm_assert(db.wdb_fd == -1, "db_close must reset wdb_fd to -1")
    syscall(87, db_path, 0, 0, 0, 0, 0)

    resp_wire = http_format_response(200, "text/plain", "WAVE_M_OK")
    parsed_resp = http_parse_response(resp_wire)
    wm_assert(parsed_resp.status_code == 200 and parsed_resp.body == "WAVE_M_OK", "HTTP format/parse alongside DB+TCP+UDP")

    say "PASS: test_wave_m_dyn_tag_strict_tcp_db (dyn_tagged flow+loop+compound + strict_types + tcp/udp/db/http)"
    return 0
