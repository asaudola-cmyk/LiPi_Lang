// ==============================================================================
// 🎨 LIPI SOVEREIGN BRANDING RASTERIZER & PNG SYNTHESIZER (scripts/rasterize_branding.lp)
// ⚡ 100% Pure Lipi Implementation — 0% Python | 0% Pillow | 0% Chrome | 0% Libc
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Replaces legacy Python/Pillow/Chrome rasterize_branding.py with a direct
//    machine-code PNG encoder and branding asset integrity verifier written in Lipi.
// 2. Implements RFC 1950 zlib + RFC 1951 stored DEFLATE + IEEE 802.3 CRC-32 +
//    RGBA PNG encoding over the bare-metal LipiFramebuffer engine.
// 3. Usage:
//      ./bin/lipc scripts/rasterize_branding.lp -o /tmp/brand_tool
//      /tmp/brand_tool                  # Verifies docs/branding assets + live PNG synthesis
//      /tmp/brand_tool --out icon.png   # Synthesizes a 64x64 RGBA PNG icon directly to disk

import "utso/io"
import "utso/memory"
import "utso/string"
import "utso/syscalls"
import "aati/lipi_gui/framebuffer"

@fn _brand_write_u32_be(buf: i64, off: i64, val: i64)
  v = val & 4294967295
  mem_byte_write(buf, off + 0, (v / 16777216) & 255)
  mem_byte_write(buf, off + 1, (v / 65536) & 255)
  mem_byte_write(buf, off + 2, (v / 256) & 255)
  mem_byte_write(buf, off + 3, v & 255)
  return 4
@end

@fn brand_crc32_chunk(c0: i64, c1: i64, c2: i64, c3: i64, data_ptr: i64, data_len: i64)
  // WHY: Computes standard IEEE 802.3 CRC-32 over PNG 4-byte chunk type + payload.
  crc = 4294967295
  hdr = [c0 & 255, c1 & 255, c2 & 255, c3 & 255]
  hi = 0
  @while hi < 4
    crc = crc ^ hdr[hi]
    bit = 0
    @while bit < 8
      lsb = crc & 1
      crc = crc / 2
      @if lsb == 1
        crc = crc ^ 3988292384
      @end
      bit = bit + 1
    @end
    hi = hi + 1
  @end

  di = 0
  @while di < data_len
    b = mem_byte_read(data_ptr, di) & 255
    crc = crc ^ b
    bit = 0
    @while bit < 8
      lsb = crc & 1
      crc = crc / 2
      @if lsb == 1
        crc = crc ^ 3988292384
      @end
      bit = bit + 1
    @end
    di = di + 1
  @end

  return (crc ^ 4294967295) & 4294967295
@end

@fn brand_adler32_bytes(data_ptr: i64, data_len: i64)
  // WHY: RFC 1950 zlib trailer checksum over uncompressed PNG scanlines.
  s1 = 1
  s2 = 0
  i = 0
  @while i < data_len
    b = mem_byte_read(data_ptr, i) & 255
    s1 = (s1 + b) % 65521
    s2 = (s2 + s1) % 65521
    i = i + 1
  @end
  return ((s2 * 65536) + s1) & 4294967295
@end

@fn _brand_append_chunk(out_buf: i64, out_pos: i64, c0: i64, c1: i64, c2: i64, c3: i64, data_ptr: i64, data_len: i64)
  _brand_write_u32_be(out_buf, out_pos, data_len)
  mem_byte_write(out_buf, out_pos + 4, c0 & 255)
  mem_byte_write(out_buf, out_pos + 5, c1 & 255)
  mem_byte_write(out_buf, out_pos + 6, c2 & 255)
  mem_byte_write(out_buf, out_pos + 7, c3 & 255)
  i = 0
  @while i < data_len
    mem_byte_write(out_buf, out_pos + 8 + i, mem_byte_read(data_ptr, i) & 255)
    i = i + 1
  @end
  crc = brand_crc32_chunk(c0, c1, c2, c3, data_ptr, data_len)
  _brand_write_u32_be(out_buf, out_pos + 8 + data_len, crc)
  return out_pos + 12 + data_len
@end

@fn brand_export_rgba_png(fb: LipiFramebuffer, w: i64, h: i64, out_path: string)
  // WHY: Encodes an uncompressed 32-bit RGBA PNG directly from a LipiFramebuffer
  // (up to 65,535 raw scanline bytes per single stored DEFLATE block; 64x64 = 16,448 B).
  stride = 1 + (w * 4)
  raw_len = h * stride
  @if raw_len <= 0 || raw_len > 65535
    return 0
  @end

  raw_buf = sys_mmap(0, raw_len + 64, 3, 34, 0 - 1, 0)
  @if raw_buf <= 0
    return 0
  @end

  // Assemble PNG scanlines: filter_byte(0) + w * [R, G, B, A]
  y = 0
  @while y < h
    row_base = y * stride
    mem_byte_write(raw_buf, row_base, 0)
    x = 0
    @while x < w
      px = fb_read_pixel(fb, x, y)
      px_off = row_base + 1 + (x * 4)
      mem_byte_write(raw_buf, px_off + 0, (px >> 16) & 255)
      mem_byte_write(raw_buf, px_off + 1, (px >> 8) & 255)
      mem_byte_write(raw_buf, px_off + 2, px & 255)
      mem_byte_write(raw_buf, px_off + 3, 255)
      x = x + 1
    @end
    y = y + 1
  @end

  // Zlib stream: 2B CMF/FLG + 5B stored DEFLATE header + raw_len + 4B Adler-32
  zlib_len = 2 + 5 + raw_len + 4
  zlib_buf = sys_mmap(0, zlib_len + 64, 3, 34, 0 - 1, 0)
  @if zlib_buf <= 0
    sys_munmap(raw_buf, raw_len + 64)
    return 0
  @end
  mem_byte_write(zlib_buf, 0, 120) // 0x78
  mem_byte_write(zlib_buf, 1, 1)   // 0x01 (FCHECK valid: 0x7801 % 31 == 0)
  mem_byte_write(zlib_buf, 2, 1)   // BFINAL=1, BTYPE=00 (stored)
  mem_byte_write(zlib_buf, 3, raw_len & 255)
  mem_byte_write(zlib_buf, 4, (raw_len / 256) & 255)
  nlen = 65535 ^ raw_len
  mem_byte_write(zlib_buf, 5, nlen & 255)
  mem_byte_write(zlib_buf, 6, (nlen / 256) & 255)

  zi = 0
  @while zi < raw_len
    mem_byte_write(zlib_buf, 7 + zi, mem_byte_read(raw_buf, zi) & 255)
    zi = zi + 1
  @end
  adler = brand_adler32_bytes(raw_buf, raw_len)
  _brand_write_u32_be(zlib_buf, 7 + raw_len, adler)

  // PNG output buffer: 8B sig + 25B IHDR + (12 + zlib_len) IDAT + 12B IEND
  png_cap = 8 + 25 + 12 + zlib_len + 12 + 64
  png_buf = sys_mmap(0, png_cap, 3, 34, 0 - 1, 0)
  @if png_buf <= 0
    sys_munmap(zlib_buf, zlib_len + 64)
    sys_munmap(raw_buf, raw_len + 64)
    return 0
  @end

  // PNG file signature: 89 50 4E 47 0D 0A 1A 0A
  mem_byte_write(png_buf, 0, 137)
  mem_byte_write(png_buf, 1, 80)
  mem_byte_write(png_buf, 2, 78)
  mem_byte_write(png_buf, 3, 71)
  mem_byte_write(png_buf, 4, 13)
  mem_byte_write(png_buf, 5, 10)
  mem_byte_write(png_buf, 6, 26)
  mem_byte_write(png_buf, 7, 10)

  // IHDR payload (13 bytes)
  ihdr = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  _brand_write_u32_be(ihdr, 0, w)
  _brand_write_u32_be(ihdr, 4, h)
  mem_byte_write(ihdr, 8, 8)   // bit depth 8
  mem_byte_write(ihdr, 9, 6)   // color type 6 (RGBA)
  mem_byte_write(ihdr, 10, 0)  // compression 0
  mem_byte_write(ihdr, 11, 0)  // filter 0
  mem_byte_write(ihdr, 12, 0)  // interlace 0

  pos = 8
  pos = _brand_append_chunk(png_buf, pos, 73, 72, 68, 82, ihdr, 13)      // IHDR
  pos = _brand_append_chunk(png_buf, pos, 73, 68, 65, 84, zlib_buf, zlib_len) // IDAT
  pos = _brand_append_chunk(png_buf, pos, 73, 69, 78, 68, ihdr, 0)       // IEND

  fd = sys_open(out_path, 577, 420)
  written_ok = 0
  @if fd >= 0
    off = 0
    written_ok = 1
    @while off < pos
      nw = sys_write(fd, png_buf + off, pos - off)
      @if nw <= 0
        written_ok = 0
        @break
      @end
      off = off + nw
    @end
    sys_close(fd)
  @end

  sys_munmap(ihdr, 64)
  sys_munmap(png_buf, png_cap)
  sys_munmap(zlib_buf, zlib_len + 64)
  sys_munmap(raw_buf, raw_len + 64)

  @if written_ok == 1
    return pos
  @end
  return 0
@end

@fn brand_render_64x64_mark(out_path: string)
  // WHY: Renders Lipi's canonical 64x64 dark-slate brand emblem with framed L+P mark.
  fb = lipi_fb_open(64, 64)
  @if fb == 0 || fb.is_active == 0
    return 0
  @end
  fb_fill_rect(fb, 0, 0, 64, 64, 856343)     // Dark Slate #0D1117
  fb_fill_rect(fb, 6, 6, 52, 52, 1118499)    // Inner Card #111123
  fb_fill_rect(fb, 6, 6, 52, 2, 49919)       // Top Cyan Accent #00C2FF
  fb_fill_rect(fb, 6, 56, 52, 2, 16711802)   // Bottom Pink Accent #FF007A

  // Scaled crisp Lipi L+P vector mark (2x scale in center)
  fb_fill_rect(fb, 18, 16, 6, 32, 49919)     // Cyan vertical stem
  fb_fill_rect(fb, 18, 42, 20, 6, 16711802)  // Pink L horizontal base
  fb_fill_rect(fb, 24, 16, 18, 6, 16766720)  // Gold P top loop
  fb_fill_rect(fb, 36, 22, 6, 8, 16766720)   // Gold P right loop
  fb_fill_rect(fb, 24, 28, 14, 5, 16766720)  // Gold P mid bar

  // Also stamp corner native 12x12 mini-icon via official fb_draw_lipi_icon
  fb_draw_lipi_icon(fb, 44, 42)

  written = brand_export_rgba_png(fb, 64, 64, out_path)
  lipi_fb_close(fb)
  return written
@end

@fn _brand_get_file_size(path: string)
  st = lipi_alloc(144)
  rc = sys_stat(path, st)
  @if rc < 0
    lipi_free(st)
    return 0 - 1
  @end
  sz = mem_read_u64(st, 48)
  lipi_free(st)
  return sz
@end

@fn _brand_verify_png_header(path: string)
  fd = sys_open(path, 0, 0)
  @if fd < 0 return 0 @end
  buf = lipi_alloc(16)
  nr = sys_read(fd, buf, 8)
  sys_close(fd)
  ok = 0
  @if nr == 8
    @if mem_byte_read(buf, 0) == 137 && mem_byte_read(buf, 1) == 80 && mem_byte_read(buf, 2) == 78 && mem_byte_read(buf, 3) == 71
      ok = 1
    @end
  @end
  lipi_free(buf)
  return ok
@end

@fn main()
  args = argv()
  out_arg = ""
  ai = 1
  @while ai + 1 < args.len()
    @if args[ai] == "--out"
      out_arg = args[ai + 1]
    @end
    ai = ai + 1
  @end

  @if str_len(out_arg) > 0
    bytes_written = brand_render_64x64_mark(out_arg)
    @if bytes_written <= 0 || _brand_verify_png_header(out_arg) != 1
      println("❌ Failed to synthesize RGBA PNG to: " + out_arg)
      return 1
    @end
    println("✔ Synthesized pure-Lipi 64x64 RGBA PNG: " + out_arg + " (" + to_str(bytes_written) + " bytes)")
    return 0
  @end

  println("=================================================================")
  println("🎨 LIPI PURE-SILICON BRANDING SYNTHESIZER & VERIFIER (0% Python)")
  println("=================================================================")

  req_paths = [
    "docs/branding/lipi_logo.svg",
    "docs/branding/lipi_mark.svg",
    "docs/branding/favicon.ico",
    "docs/branding/png/lipi_icon_256x256.png",
    "docs/branding/png/lipi_icon_512x512.png"
  ]
  ri = 0
  @while ri < req_paths.len()
    p = req_paths[ri]
    sz = _brand_get_file_size(p)
    @if sz <= 100
      println("  ❌ [FAIL] Missing or invalid branding asset: " + p)
      return 1
    @end
    println("  ✔ [ASSET] " + p + " (" + to_str(sz) + " bytes)")
    ri = ri + 1
  @end

  probe_path = "/tmp/lipi_brand_probe_" + to_str(sys_getpid()) + ".png"
  bytes_written = brand_render_64x64_mark(probe_path)
  hdr_ok = _brand_verify_png_header(probe_path)
  probe_sz = _brand_get_file_size(probe_path)
  sys_unlink(probe_path)

  @if bytes_written <= 200 || hdr_ok != 1 || probe_sz != bytes_written
    println("  ❌ [FAIL] Live RGBA PNG synthesis verification failed")
    return 1
  @end
  println("  ✔ [PASS] Live 64x64 RGBA PNG synthesis & \\x89PNG header verified (" + to_str(bytes_written) + " bytes)")
  println("✅ PURE-LIPI BRANDING ENGINE COMPLETE (0% Python / 0% Pillow)")
  return 0
@end

main()
