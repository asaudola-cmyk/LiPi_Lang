// ==============================================================================
// Wave Q Regression Suite: Real utso/silicon/* (ACPI, PCIe, APIC, Multiboot2,
// NVMe, AHCI, xHCI, HDA, UEFI), Real utso/bare/* (GPT CRC32, FAT32, ISO 9660,
// no_std string & fmt), Buffered IO (BufReader/BufWriter), FS (dir_walk/glob/
// temp/inotify), Option/Result Closure Map & Auto-Rehash HashMap, Production
// Server Radix Router, HTTP ByteBuffer/Pool, QUIC RFC 9001 AEAD+HP, HTTP/3 QPACK
// ==============================================================================

import "utso/core/io.lp"
import "utso/core/option.lp"
import "utso/core/result.lp"
import "utso/core/hashmap.lp"
import "utso/os/fs.lp"
import "utso/silicon/acpi.lp"
import "utso/silicon/pcie.lp"
import "utso/silicon/apic.lp"
import "utso/silicon/multiboot2.lp"
import "utso/silicon/nvme.lp"
import "utso/silicon/ahci.lp"
import "utso/silicon/xhci.lp"
import "utso/silicon/hda.lp"
import "utso/silicon/uefi.lp"
import "utso/bare/gpt.lp"
import "utso/bare/fat32.lp"
import "utso/bare/iso9660.lp"
import "utso/bare/string.lp"
import "utso/bare/fmt.lp"
import "utso/net/server_production.lp"
import "utso/net/http.lp"
import "utso/net/quic.lp"
import "utso/net/http3.lp"

fn dummy_route_handler(req)
    return "OK"
end

fn main()
    // 1. Real ACPI RSDP + Checksum Validation on memory-backed buffer
    rsdp = malloc(64)
    i = 0
    while i < 64 mmio_w8(rsdp + i, 0) i = i + 1 end
    mmio_w8(rsdp + 0, 82) mmio_w8(rsdp + 1, 83) mmio_w8(rsdp + 2, 68) mmio_w8(rsdp + 3, 32)
    mmio_w8(rsdp + 4, 80) mmio_w8(rsdp + 5, 84) mmio_w8(rsdp + 6, 82) mmio_w8(rsdp + 7, 32)
    mmio_w8(rsdp + 15, 0) // ACPI 1.0
    mmio_w32(rsdp + 16, 1048576)
    s1 = 0
    i = 0
    while i < 20 s1 = (s1 + mmio_r8(rsdp + i)) & 255 i = i + 1 end
    mmio_w8(rsdp + 8, (256 - s1) & 255)
    if silicon_acpi_validate_rsdp(rsdp) != 1 or silicon_acpi_rsdp_rsdt_addr(rsdp) != 1048576
        say "FAIL Q1 ACPI RSDP"
        exit(1)
    end
    free(rsdp, 64)

    // 2. Real Multiboot2 Tag Parser (Framebuffer Tag 8 + End Tag 0)
    mb = malloc(64)
    i = 0
    while i < 64 mmio_w8(mb + i, 0) i = i + 1 end
    mmio_w32(mb + 0, 48)  // total_size
    mmio_w32(mb + 8, 8)   // Tag 8 = Framebuffer
    mmio_w32(mb + 12, 32) // size = 32
    mmio_w64(mb + 16, 4244635648) // 0xFD000000
    mmio_w32(mb + 24, 5120)       // pitch
    mmio_w32(mb + 28, 1280)       // width
    mmio_w32(mb + 32, 720)        // height
    mmio_w8(mb + 36, 32)          // bpp
    mmio_w32(mb + 40, 0) mmio_w32(mb + 44, 8) // End tag
    fbt = silicon_mb2_find_tag(mb, 8)
    if silicon_mb2_magic_valid(919036553) != 1 or fbt == 0 or silicon_mb2_fb_width(fbt) != 1280 or silicon_mb2_fb_bpp(fbt) != 32
        say "FAIL Q2 Multiboot2 parser"
        exit(1)
    end
    free(mb, 64)

    // 3. Real GPT CRC32 + FAT32 BPB + ISO 9660 PVD & El Torito + bare/string & bare/fmt
    lba0 = malloc(512)
    lba1 = malloc(512)
    ents = malloc(16384)
    bare_gpt_write_pmbr(lba0, 65536)
    bare_gpt_write_efi_part_entry(ents, 2048, 65000)
    bare_gpt_write_header(lba1, ents, 65536, 128)
    if bare_gpt_validate_header(lba1) != 1 or mmio_r8(lba0 + 448) != 2 or mmio_r32(lba1 + 56) == 0
        say "FAIL Q3a GPT CRC32/CHS/DiskGUID validation"
        exit(1)
    end
    bare_fat32_write_bpb(lba0, 65536, 512)
    if bare_fat32_data_start_lba(lba0) != 1056
        say "FAIL Q3b FAT32 BPB"
        exit(1)
    end
    iso = malloc(2048)
    bare_iso_write_pvd(iso, 1024, 20, 2048)
    if bare_iso_validate_pvd(iso) != 1
        say "FAIL Q3c ISO 9660 PVD"
        exit(1)
    end
    fbuf = malloc(64)
    fp = bare_fmt_write_dec(fbuf, 0, 64, 0 - 1234)
    if fp != 5 or bare_str_len(fbuf) != 5
        say "FAIL Q3d bare/fmt"
        exit(1)
    end
    free(lba0, 512) free(lba1, 512) free(ents, 16384) free(iso, 2048) free(fbuf, 64)

    // 4. Buffered BufWriter & BufReader + fs_temp_file + fs_glob_match + inotify
    tf = fs_temp_file("wave_q_io")
    if len(tf) == 0
        say "FAIL Q4a fs_temp_file"
        exit(1)
    end
    wfd = file_open(tf, 577)
    bw = buf_writer_new(wfd, 512)
    buf_writer_write(bw, "line_one\n")
    buf_writer_write(bw, "line_two\n")
    buf_writer_free(bw)
    file_close(wfd)
    rfd = file_open(tf, 0)
    br = buf_reader_new(rfd, 512)
    l1 = buf_reader_read_line(br)
    l2 = buf_reader_read_line(br)
    l3 = buf_reader_read_line(br)
    buf_reader_free(br)
    file_close(rfd)
    if l1 != "line_one" or l2 != "line_two" or l3 != ":EOF:"
        say "FAIL Q4b BufReader/BufWriter"
        exit(1)
    end
    if fs_glob_match("test_*.lp", "test_wave_q.lp") != 1 or fs_glob_match("test_*.lp", "other.txt") != 0
        say "FAIL Q4c fs_glob_match"
        exit(1)
    end
    ifd = fs_inotify_init()
    if ifd >= 0
        wd = fs_inotify_add_watch(ifd, tf, 2)
        fs_write_file(tf, "modified")
        ev_m = fs_inotify_read_event(ifd)
        fs_close(ifd)
        if wd < 0 or ev_m == 0
            say "FAIL Q4d inotify"
            exit(1)
        end
    end
    syscall(87, tf, 0, 0, 0, 0, 0) // unlink temp file

    // 5. Option/Result tagged disambiguation + real closure map + auto-rehash HashMap
    opt0 = option_some(0)
    if is_some(opt0) != 1 or option_is_valid(opt0) != 1 or unwrap_option(opt0) != 0
        say "FAIL Q5a Option(0) disambiguation"
        exit(1)
    end
    opt_m = option_map_fn(option_some(21), fn(v) { return v * 2 })
    if unwrap_option(opt_m) != 42
        say "FAIL Q5b option_map_fn"
        exit(1)
    end
    res_m = result_map_fn(ok(10), fn(v) { return v + 5 })
    if unwrap(res_m) != 15
        say "FAIL Q5c result_map_fn"
        exit(1)
    end
    hm = robin_map_new(4)
    k = 0
    while k < 50
        robin_map_put(hm, k, k * 3)
        k = k + 1
    end
    if robin_map_len(hm) != 50 or robin_map_get(hm, 49) != 147 or robin_map_has(hm, 0) != 1
        say "FAIL Q5d robin_map auto-rehash"
        exit(1)
    end
    robin_map_free(hm)

    // 6. Production Server Radix Router + HTTP ByteBuffer + Pool + CancelToken
    rroot = prod_radix_node_new("", 0, 0)
    prod_radix_insert(rroot, "GET", "/api/users/:id/profile", dummy_route_handler)
    if prod_radix_match(rroot, "GET", "/api/users/42/profile") == 0 or prod_radix_match(rroot, "POST", "/api/users/42/profile") != 0
        say "FAIL Q6a Radix router"
        exit(1)
    end
    hresp = http_format_response(200, "application/json", "{\"ok\":true}")
    if str_contains(hresp, "HTTP/1.1 200 OK") != 1 or str_contains(hresp, "{\"ok\":true}") != 1
        say "FAIL Q6b HTTP ByteBuffer response"
        exit(1)
    end
    ctok = http_cancel_token_new(5000)
    http_cancel_trigger(ctok)
    cres = http_request_cancellable("GET", "http://127.0.0.1:1/", [], "", ctok)
    if cres.status_code != 499
        say "FAIL Q6c HTTP cancel token"
        exit(1)
    end

    // 7. QUIC RFC 9001 Real ChaCha20-Poly1305 AEAD + Header Protection + Tamper Reject
    secret = []
    si = 0
    while si < 32 secret = secret.push((si * 7 + 13) & 255) si = si + 1 end
    qkeys = quic_derive_packet_keys(secret)
    hdr = [65, 1, 2, 3, 4, 0, 7] // 1-RTT short header (pn_len=2, pn=7 at offset 5)
    pt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    prot = quic_aead_protect_packet(qkeys.qk_key, qkeys.qk_iv, qkeys.qk_hp, hdr, 7, 5, 2, pt)
    unp = quic_aead_unprotect_packet(qkeys.qk_key, qkeys.qk_iv, qkeys.qk_hp, prot, 5)
    if unp.ok != 1 or unp.pn != 7 or unp.plaintext.len() != 20 or unp.plaintext[0] != 1 or unp.plaintext[19] != 20
        say "FAIL Q7a QUIC RFC 9001 AEAD/HP roundtrip"
        exit(1)
    end
    // Flip 1 bit in ciphertext -> MUST fail Poly1305 authentication!
    list_set(prot, prot.len() - 1, prot[prot.len() - 1] ^ 1)
    unp_bad = quic_aead_unprotect_packet(qkeys.qk_key, qkeys.qk_iv, qkeys.qk_hp, prot, 5)
    // Forged empty-payload packet (16B bogus tag) -> MUST fail authentication!
    forged_empty = [65, 1, 2, 3, 4, 0, 1, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9]
    unp_empty = quic_aead_unprotect_packet(qkeys.qk_key, qkeys.qk_iv, qkeys.qk_hp, forged_empty, 5)
    if unp_bad.ok != 0 or unp_empty.ok != 0
        say "FAIL Q7b QUIC tamper/empty-payload not rejected!"
        exit(1)
    end

    // 8. HTTP/3 RFC 9204 QPACK Prefix-Int Codec & HEADERS Decoder
    qbuf = list()
    qpack_encode_prefixed_int(qbuf, 6, 192, 98)
    qdec = qpack_decode_prefixed_int(qbuf, 0, 6)
    if get(qdec, 0) != 98 or qpack_static_lookup(98) != "x-forwarded-for"
        say "FAIL Q8a QPACK prefix-int/static table"
        exit(1)
    end
    h3_blk = [0, 0, 192 | 24, 192 | 48] // :status:200 + content-type:application/json
    h3_flds = h3_decode_headers_block(h3_blk)
    if h3_flds.len() != 2 or h3_flds[0].hh_name != ":status" or h3_flds[0].hh_value != "200"
        say "FAIL Q8b HTTP/3 QPACK HEADERS decode"
        exit(1)
    end

    say "PASS_WAVE_Q_SILICON_FS_NET_PRODUCTION"
    return 0
end
