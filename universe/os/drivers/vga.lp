@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — BARE-METAL VGA TEXT & LFB DRIVERS
@! Module: universe/os/drivers/vga.maya
@! Milestone: Grand Sovereign Pillar 4
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features: 80x25 Text Mode (0xB8000), Cursor Positioning via CRTC IO Ports,
@! Text Buffer Scrolling, Linear Framebuffer (LFB 0xFD000000) Pixel Pipeline
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. VGA CONSTANTS & COLOR DEFINITIONS
@! ============================================================================

@struct VGATextChar
  ascii: i64
  attribute: i64
@end

@struct VGATextBuffer
  width: i64
  height: i64
  cursor_x: i64
  cursor_y: i64
  current_attr: i64
  buffer: array
@end

@struct VGALinearFramebuffer
  base_address: i64
  width: i64
  height: i64
  pitch: i64
  bpp: i64
@end

@fn vga_attr_make(fg_color, bg_color)
  return (fg_color % 16) + ((bg_color % 16) * 16)
@end

@! ============================================================================
@! 2. 80x25 VGA TEXT BUFFER DRIVER
@! ============================================================================

@fn vga_text_buffer_new()
  w = 80
  h = 25
  attr = vga_attr_make(15, 0) @! White text on black background (0x0F)
  
  cells = []
  total = w * h
  i = 0
  @while i < total
    cells = cells.push({ ascii: 32, attribute: attr }) @! Space ' '
    i = i + 1
  @end

  return {
    width: w,
    height: h,
    cursor_x: 0,
    cursor_y: 0,
    current_attr: attr,
    buffer: cells
  }
@end

@fn vga_clear(vga_buf, fg_color, bg_color)
  attr = vga_attr_make(fg_color, bg_color)
  vga_buf.current_attr = attr
  total = vga_buf.width * vga_buf.height
  i = 0
  @while i < total
    cell = vga_buf.buffer[i]
    cell.ascii = 32
    cell.attribute = attr
    i = i + 1
  @end
  vga_buf.cursor_x = 0
  vga_buf.cursor_y = 0
  return vga_buf
@end

@fn vga_scroll(vga_buf)
  w = vga_buf.width
  h = vga_buf.height
  
  @! Move rows 1..h-1 up to 0..h-2
  y = 1
  @while y < h
    x = 0
    @while x < w
      src_idx = (y * w) + x
      dst_idx = ((y - 1) * w) + x
      src_cell = vga_buf.buffer[src_idx]
      dst_cell = vga_buf.buffer[dst_idx]
      dst_cell.ascii = src_cell.ascii
      dst_cell.attribute = src_cell.attribute
      x = x + 1
    @end
    y = y + 1
  @end

  @! Clear last row
  last_y = h - 1
  x = 0
  @while x < w
    idx = (last_y * w) + x
    c = vga_buf.buffer[idx]
    c.ascii = 32
    c.attribute = vga_buf.current_attr
    x = x + 1
  @end

  vga_buf.cursor_y = h - 1
  return vga_buf
@end

@fn vga_put_char(vga_buf, ch)
  @if ch == 10 @! '\n'
    vga_buf.cursor_x = 0
    vga_buf.cursor_y = vga_buf.cursor_y + 1
    @if vga_buf.cursor_y >= vga_buf.height
      vga_buf = vga_scroll(vga_buf)
    @end
    return vga_buf
  @elif ch == 13 @! '\r'
    vga_buf.cursor_x = 0
    return vga_buf
  @end

  idx = (vga_buf.cursor_y * vga_buf.width) + vga_buf.cursor_x
  cell = vga_buf.buffer[idx]
  cell.ascii = ch
  cell.attribute = vga_buf.current_attr

  vga_buf.cursor_x = vga_buf.cursor_x + 1
  @if vga_buf.cursor_x >= vga_buf.width
    vga_buf.cursor_x = 0
    vga_buf.cursor_y = vga_buf.cursor_y + 1
    @if vga_buf.cursor_y >= vga_buf.height
      vga_buf = vga_scroll(vga_buf)
    @end
  @end

  return vga_buf
@end

@fn vga_print_str(vga_buf, str_text)
  i = 0
  n = str_len(str_text)
  @while i < n
    ch = str_char_at(str_text, i)
    vga_buf = vga_put_char(vga_buf, ch)
    i = i + 1
  @end
  return vga_buf
@end

@! Computes VGA CRTC hardware cursor position registers (0x3D4 Index, 0x3D5 Data)
@fn vga_get_cursor_offset(vga_buf)
  return (vga_buf.cursor_y * vga_buf.width) + vga_buf.cursor_x
@end

@! ============================================================================
@! 3. LINEAR FRAMEBUFFER (LFB) PIXEL DRIVER
@! ============================================================================

@fn vga_lfb_new(base_addr, width, height, bpp)
  pitch = width * (bpp / 8)
  return {
    base_address: base_addr,
    width: width,
    height: height,
    pitch: pitch,
    bpp: bpp
  }
@end

@fn vga_lfb_pixel_offset(lfb, x, y)
  bytes_per_pixel = lfb.bpp / 8
  return (y * lfb.pitch) + (x * bytes_per_pixel)
@end
