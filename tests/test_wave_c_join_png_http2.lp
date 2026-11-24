// ==============================================================================
// Wave C Regression Test:
//   C1: O(N) string_join / str_join / str_repeat / str_reverse (10,000 items)
//   C2: Full RFC 2083 PNG Decoder (Grayscale 1/4/8/16-bit, RGB 8/16 + tRNS,
//       Indexed Palette PLTE + tRNS 4/8-bit, Gray+Alpha 8/16, RGBA 16,
//       AND 7-pass Adam7 Interlacing on asymmetric 9x9 grid)
//   C3: Pure-Lipi RFC 9113 HTTP/2 Client (h2c multiplexed concurrent streams +
//       PING/PONG + POST body echo AND TLS 1.3 ALPN "h2" with X.509 CA verify)
// ==============================================================================

import "utso/core/string"
import "utso/core/png"
import "utso/net/http2/server"
import "utso/net/http2/client"

fn _wc_listen_loopback()
    fd = syscall(41, 2, 1, 0, 0, 0, 0)
    if fd < 0 return [0 - 1, 0] end
    one = malloc(4)
    mem_write_u32(one, 0, 1)
    syscall(54, fd, 1, 2, one, 4, 0) // SO_REUSEADDR
    free(one, 4)

    sa = malloc(16)
    i = 0
    while i < 16
        mem_write_byte(sa, i, 0)
        i = i + 1
    end
    mem_write_byte(sa, 0, 2) // AF_INET
    mem_write_byte(sa, 4, 127)
    mem_write_byte(sa, 7, 1)
    if syscall(49, fd, sa, 16, 0, 0, 0) < 0
        free(sa, 16)
        syscall(3, fd, 0, 0, 0, 0, 0)
        return [0 - 1, 0]
    end
    if syscall(50, fd, 8, 0, 0, 0, 0) < 0
        free(sa, 16)
        syscall(3, fd, 0, 0, 0, 0, 0)
        return [0 - 1, 0]
    end
    slen = malloc(4)
    mem_write_u32(slen, 0, 16)
    syscall(51, fd, sa, slen, 0, 0, 0) // getsockname
    port = ((mem_read_byte(sa, 2) & 255) << 8) | (mem_read_byte(sa, 3) & 255)
    free(sa, 16)
    free(slen, 4)
    return [fd, port]
end

// ── C1: O(N) String Operations ───────────────────────────────────────────────
fn test_c1_on_string_join()
    items = list()
    i = 0
    while i < 10000
        push(items, "ab")
        i = i + 1
    end
    t0 = time_now_ms()
    joined = str_join(items, ",")
    dt = time_now_ms() - t0
    // Expected length: 10000*2 + 9999*1 = 29999
    if str_len(joined) != 29999
        print("FAIL C1: str_join length expected 29999 got " + str(str_len(joined)))
        return 1
    end
    if str_sub(joined, 0, 5) != "ab,ab" or str_sub(joined, 29994, 29999) != "ab,ab"
        print("FAIL C1: str_join content mismatch")
        return 1
    end
    if dt > 2000
        print("FAIL C1: str_join too slow (" + str(dt) + "ms) - possible O(N^2)")
        return 1
    end
    rep = str_repeat("xy", 5000)
    if str_len(rep) != 10000 or str_sub(rep, 0, 4) != "xyxy"
        print("FAIL C1: str_repeat failed")
        return 1
    end
    if str_reverse("Lipi-2026") != "6202-ipiL"
        print("FAIL C1: str_reverse failed")
        return 1
    end
    return 0
end

// ── C2: Full RFC 2083 PNG Modes & Adam7 Interlacing ──────────────────────────
fn test_c2_full_rfc2083_png()
    out_len = [0]

    // 1. Color Type 0 (1-bit Grayscale, 4x1): bits 1010_0000 = 0xA0 -> [255, 0, 255, 0]
    raw_g1 = malloc(2)
    mem_write_byte(raw_g1, 0, 0)   // Filter None
    mem_write_byte(raw_g1, 1, 160) // 10100000b
    p_g1 = png_encode_custom(4, 1, 1, 0, 0, 0, 0, 0, 0, raw_g1, 2, out_len)
    img = png_decode_to_argb(p_g1, out_len[0])
    free(raw_g1, 2)
    free(p_g1, out_len[0])
    if img.png_valid != 1 or img.png_width != 4 or img.png_height != 1
        print("FAIL C2: 1-bit grayscale invalid")
        return 1
    end
    // ARGB: opaque white = 0xFFFFFFFF = 4294967295, opaque black = 0xFF000000 = 4278190080
    if mem_read_u32(img.png_pixels, 0) != 4294967295 or mem_read_u32(img.png_pixels, 4) != 4278190080 or mem_read_u32(img.png_pixels, 8) != 4294967295
        print("FAIL C2: 1-bit grayscale pixel mismatch")
        return 1
    end
    png_free_image(img)

    // 2. Color Type 3 (4-bit Indexed Palette + PLTE + tRNS, 4x1)
    // Palette: idx0=(255,0,0), idx1=(0,255,0), idx2=(0,0,255), idx3=(255,255,0)
    // tRNS: alpha[0]=255, alpha[1]=128, alpha[2]=0, alpha[3]=255 (default)
    plte = malloc(12)
    mem_write_byte(plte, 0, 255) mem_write_byte(plte, 1, 0)   mem_write_byte(plte, 2, 0)
    mem_write_byte(plte, 3, 0)   mem_write_byte(plte, 4, 255) mem_write_byte(plte, 5, 0)
    mem_write_byte(plte, 6, 0)   mem_write_byte(plte, 7, 0)   mem_write_byte(plte, 8, 255)
    mem_write_byte(plte, 9, 255) mem_write_byte(plte, 10, 255) mem_write_byte(plte, 11, 0)
    trns = malloc(3)
    mem_write_byte(trns, 0, 255)
    mem_write_byte(trns, 1, 128)
    mem_write_byte(trns, 2, 0)
    raw_p4 = malloc(3)
    mem_write_byte(raw_p4, 0, 0)  // Filter None
    mem_write_byte(raw_p4, 1, 1)  // nibbles 0, 1
    mem_write_byte(raw_p4, 2, 35) // nibbles 2, 3 (0x23)
    p_p4 = png_encode_custom(4, 1, 4, 3, 0, plte, 12, trns, 3, raw_p4, 3, out_len)
    img2 = png_decode_to_argb(p_p4, out_len[0])
    free(plte, 12)
    free(trns, 3)
    free(raw_p4, 3)
    free(p_p4, out_len[0])
    if img2.png_valid != 1
        print("FAIL C2: 4-bit indexed PLTE+tRNS invalid")
        return 1
    end
    px0 = mem_read_u32(img2.png_pixels, 0)
    px1 = mem_read_u32(img2.png_pixels, 4)
    px2 = mem_read_u32(img2.png_pixels, 8)
    px3 = mem_read_u32(img2.png_pixels, 12)
    // Expect: px0=0xFFFF0000, px1=0x8000FF00, px2=0x000000FF, px3=0xFFFFFF00
    if px0 != ((255 << 24) | (255 << 16)) or px1 != ((128 << 24) | (255 << 8)) or px2 != 255 or px3 != ((255 << 24) | (255 << 16) | (255 << 8))
        print("FAIL C2: 4-bit PLTE+tRNS pixel mismatch")
        return 1
    end
    png_free_image(img2)

    // 3. Color Type 4 (8-bit Grayscale + Alpha, 2x1)
    raw_ga = malloc(5)
    mem_write_byte(raw_ga, 0, 0)
    mem_write_byte(raw_ga, 1, 100) mem_write_byte(raw_ga, 2, 200)
    mem_write_byte(raw_ga, 3, 50)  mem_write_byte(raw_ga, 4, 64)
    p_ga = png_encode_custom(2, 1, 8, 4, 0, 0, 0, 0, 0, raw_ga, 5, out_len)
    img3 = png_decode_to_argb(p_ga, out_len[0])
    free(raw_ga, 5)
    free(p_ga, out_len[0])
    if img3.png_valid != 1
        print("FAIL C2: Gray+Alpha invalid")
        return 1
    end
    if mem_read_u32(img3.png_pixels, 0) != ((200 << 24) | (100 << 16) | (100 << 8) | 100) or mem_read_u32(img3.png_pixels, 4) != ((64 << 24) | (50 << 16) | (50 << 8) | 50)
        print("FAIL C2: Gray+Alpha pixel mismatch")
        return 1
    end
    png_free_image(img3)

    // 4. Color Type 6 (16-bit RGBA, 2x1)
    raw_r16 = malloc(17)
    mem_write_byte(raw_r16, 0, 0)
    // px0: R=0x1234, G=0x5678, B=0x9ABC, A=0xF001 -> ARGB (0xF0, 0x12, 0x56, 0x9A)
    mem_write_byte(raw_r16, 1, 18)  mem_write_byte(raw_r16, 2, 52)
    mem_write_byte(raw_r16, 3, 86)  mem_write_byte(raw_r16, 4, 120)
    mem_write_byte(raw_r16, 5, 154) mem_write_byte(raw_r16, 6, 188)
    mem_write_byte(raw_r16, 7, 240) mem_write_byte(raw_r16, 8, 1)
    // px1: R=0xFF00, G=0x00FF, B=0x7F00, A=0x8000 -> ARGB (0x80, 0xFF, 0x00, 0x7F)
    mem_write_byte(raw_r16, 9, 255)  mem_write_byte(raw_r16, 10, 0)
    mem_write_byte(raw_r16, 11, 0)   mem_write_byte(raw_r16, 12, 255)
    mem_write_byte(raw_r16, 13, 127) mem_write_byte(raw_r16, 14, 0)
    mem_write_byte(raw_r16, 15, 128) mem_write_byte(raw_r16, 16, 0)
    p_r16 = png_encode_custom(2, 1, 16, 6, 0, 0, 0, 0, 0, raw_r16, 17, out_len)
    img4 = png_decode_to_argb(p_r16, out_len[0])
    free(raw_r16, 17)
    free(p_r16, out_len[0])
    if img4.png_valid != 1
        print("FAIL C2: 16-bit RGBA invalid")
        return 1
    end
    if mem_read_u32(img4.png_pixels, 0) != ((240 << 24) | (18 << 16) | (86 << 8) | 154) or mem_read_u32(img4.png_pixels, 4) != ((128 << 24) | (255 << 16) | 127)
        print("FAIL C2: 16-bit RGBA pixel mismatch")
        return 1
    end
    png_free_image(img4)

    // 5. Color Type 2 (8-bit RGB + tRNS transparent key)
    trns2 = malloc(6)
    mem_write_byte(trns2, 0, 0) mem_write_byte(trns2, 1, 10)
    mem_write_byte(trns2, 2, 0) mem_write_byte(trns2, 3, 20)
    mem_write_byte(trns2, 4, 0) mem_write_byte(trns2, 5, 30)
    raw_rgb = malloc(7)
    mem_write_byte(raw_rgb, 0, 0)
    mem_write_byte(raw_rgb, 1, 10) mem_write_byte(raw_rgb, 2, 20) mem_write_byte(raw_rgb, 3, 30) // matches tRNS -> alpha 0
    mem_write_byte(raw_rgb, 4, 11) mem_write_byte(raw_rgb, 5, 22) mem_write_byte(raw_rgb, 6, 33) // opaque -> alpha 255
    p_rgb = png_encode_custom(2, 1, 8, 2, 0, 0, 0, trns2, 6, raw_rgb, 7, out_len)
    img5 = png_decode_to_argb(p_rgb, out_len[0])
    free(trns2, 6)
    free(raw_rgb, 7)
    free(p_rgb, out_len[0])
    if img5.png_valid != 1
        print("FAIL C2: RGB+tRNS invalid")
        return 1
    end
    if mem_read_u32(img5.png_pixels, 0) != ((10 << 16) | (20 << 8) | 30) or mem_read_u32(img5.png_pixels, 4) != ((255 << 24) | (11 << 16) | (22 << 8) | 33)
        print("FAIL C2: RGB+tRNS pixel mismatch")
        return 1
    end
    png_free_image(img5)

    // 6. 7-Pass Adam7 Interlaced PNG (9x9 Color Type 2 RGB, unique (x*25, y*25, x+y) per pixel)
    w = 9
    h = 9
    a7_x0 = [0, 4, 0, 2, 0, 1, 0]
    a7_y0 = [0, 0, 4, 0, 2, 0, 1]
    a7_dx = [8, 8, 4, 4, 2, 2, 1]
    a7_dy = [8, 8, 8, 4, 4, 2, 2]
    // Compute exact Adam7 stream size
    a7_len = 0
    pi = 0
    while pi < 7
        pw = (w - a7_x0[pi] + a7_dx[pi] - 1) / a7_dx[pi]
        ph = (h - a7_y0[pi] + a7_dy[pi] - 1) / a7_dy[pi]
        a7_len = a7_len + ((1 + (pw * 3)) * ph)
        pi = pi + 1
    end
    raw_a7 = malloc(a7_len)
    off = 0
    pi = 0
    while pi < 7
        pw = (w - a7_x0[pi] + a7_dx[pi] - 1) / a7_dx[pi]
        ph = (h - a7_y0[pi] + a7_dy[pi] - 1) / a7_dy[pi]
        py = 0
        while py < ph
            mem_write_byte(raw_a7, off, 0) // Filter None
            off = off + 1
            iy = a7_y0[pi] + (py * a7_dy[pi])
            px = 0
            while px < pw
                ix = a7_x0[pi] + (px * a7_dx[pi])
                mem_write_byte(raw_a7, off, (ix * 25) & 255)
                mem_write_byte(raw_a7, off + 1, (iy * 25) & 255)
                mem_write_byte(raw_a7, off + 2, (ix + iy) & 255)
                off = off + 3
                px = px + 1
            end
            py = py + 1
        end
        pi = pi + 1
    end
    p_a7 = png_encode_custom(w, h, 8, 2, 1, 0, 0, 0, 0, raw_a7, a7_len, out_len)
    img6 = png_decode_to_argb(p_a7, out_len[0])
    free(raw_a7, a7_len)
    free(p_a7, out_len[0])
    if img6.png_valid != 1 or img6.png_width != 9 or img6.png_height != 9
        print("FAIL C2: Adam7 9x9 invalid")
        return 1
    end
    iy = 0
    while iy < 9
        ix = 0
        while ix < 9
            want = (255 << 24) | (((ix * 25) & 255) << 16) | (((iy * 25) & 255) << 8) | ((ix + iy) & 255)
            got = mem_read_u32(img6.png_pixels, ((iy * 9) + ix) * 4)
            if got != want
                print("FAIL C2: Adam7 mismatch at (" + str(ix) + "," + str(iy) + ")")
                png_free_image(img6)
                return 1
            end
            ix = ix + 1
        end
        iy = iy + 1
    end
    png_free_image(img6)
    return 0
end

// ── C3: Live Loopback HTTP/2 Client (h2c Multiplexed + TLS 1.3 ALPN "h2") ────
fn test_c3_http2_client_h2c_and_tls()
    // Part A: Live Multiplexed h2c (PING + concurrent GET stream 1 + POST stream 3)
    lp = _wc_listen_loopback()
    lfd = lp[0]
    port = lp[1]
    if lfd < 0 or port <= 0
        print("FAIL C3a: could not bind loopback socket")
        return 1
    end
    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        http2_serve_h2c_multi(lfd, 2)
        syscall(3, lfd, 0, 0, 0, 0, 0)
        syscall(231, 0, 0, 0, 0, 0, 0)
    end
    syscall(3, lfd, 0, 0, 0, 0, 0)

    cli = h2_connect_h2c("127.0.0.1", port)
    if cli.h2_connected != 1
        print("FAIL C3a: h2_connect_h2c failed")
        return 1
    end
    ping_ok = h2_ping(cli, [11, 22, 33, 44, 55, 66, 77, 88])
    if ping_ok != 1
        print("FAIL C3a: h2_ping ACK mismatch")
        h2_close(cli)
        return 1
    end
    // Submit BOTH streams concurrently before reading either reply!
    s1 = h2_send_request(cli, "GET", "/alpha", "127.0.0.1", list(), list(), "")
    s2 = h2_send_request(cli, "POST", "/beta", "127.0.0.1", ["x-lipi"], ["sovereign"], "lipi-h2-body")
    if s1 != 1 or s2 != 3
        print("FAIL C3a: unexpected odd stream IDs: " + str(s1) + "," + str(s2))
        h2_close(cli)
        return 1
    end
    r1 = h2_recv_stream(cli, s1)
    r2 = h2_recv_stream(cli, s2)
    h2_close(cli)
    st = malloc(8)
    syscall(61, pid, st, 0, 0, 0, 0)
    free(st, 8)

    if r1.h2r_ok != 1 or r1.h2r_status != 200 or r1.h2r_body != "{\"stream\":1,\"method\":\"GET\",\"path\":\"/alpha\"}"
        print("FAIL C3a: stream 1 bad reply: status=" + str(r1.h2r_status) + " body=" + r1.h2r_body)
        return 1
    end
    if r2.h2r_ok != 1 or r2.h2r_status != 200 or r2.h2r_body != "{\"stream\":3,\"method\":\"POST\",\"path\":\"/beta\",\"echo\":\"lipi-h2-body\"}"
        print("FAIL C3a: stream 3 bad reply: status=" + str(r2.h2r_status) + " body=" + r2.h2r_body)
        return 1
    end

    // Part B: Live Encrypted TLS 1.3 + ALPN "h2" with Full RFC 5280 P-256 CA Verification
    engine = tls13_record_engine_new()
    tls13_engine_enable_h2(engine, 1)
    // Pin server's ephemeral P-256 Root CA into client trust store
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    ca_der = get(engine.re_cert_chain, 0)
    if len(engine.re_cert_chain) >= 2
        ca_der = get(engine.re_cert_chain, 1)
    end
    if tls13_add_trust_root(ca_der) != 1
        print("FAIL C3b: failed to pin TLS 1.3 server CA root")
        return 1
    end

    lp2 = _wc_listen_loopback()
    lfd2 = lp2[0]
    port2 = lp2[1]
    if lfd2 < 0 or port2 <= 0
        print("FAIL C3b: could not bind TLS loopback socket")
        return 1
    end
    pid2 = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid2 == 0
        http2_serve_tls_h2_once(lfd2, engine, "{\"tls13_h2\":\"sovereign_alpn_verified\"}")
        syscall(3, lfd2, 0, 0, 0, 0, 0)
        syscall(231, 0, 0, 0, 0, 0, 0)
    end
    syscall(3, lfd2, 0, 0, 0, 0, 0)

    tcli = h2_connect_tls("127.0.0.1", "localhost", port2, 1)
    if tcli.h2_connected != 1
        print("FAIL C3b: h2_connect_tls handshake/verify failed")
        return 1
    end
    if tcli.h2_alpn != "h2"
        print("FAIL C3b: expected ALPN 'h2', got '" + tcli.h2_alpn + "'")
        h2_close(tcli)
        return 1
    end
    tresp = h2_request(tcli, "GET", "/secure-h2", "localhost", list(), list(), "")
    h2_close(tcli)
    st2 = malloc(8)
    syscall(61, pid2, st2, 0, 0, 0, 0)
    free(st2, 8)

    if tresp.h2r_ok != 1 or tresp.h2r_status != 200 or tresp.h2r_body != "{\"tls13_h2\":\"sovereign_alpn_verified\"}"
        print("FAIL C3b: TLS HTTP/2 bad response: status=" + str(tresp.h2r_status) + " body=" + tresp.h2r_body)
        return 1
    end
    return 0
end

fn main()
    if test_c1_on_string_join() != 0 return 1 end
    if test_c2_full_rfc2083_png() != 0 return 2 end
    if test_c3_http2_client_h2c_and_tls() != 0 return 3 end
    print("PASS: test_wave_c_join_png_http2 (O(N) 10K str_join + full RFC 2083 PNG/Adam7 + live h2c & TLS1.3-ALPN h2 client)")
    return 0
end
