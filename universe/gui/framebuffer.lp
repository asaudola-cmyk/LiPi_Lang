// ==============================================================================
// 🖥️ লিপি ডিরেক্ট লিনাক্স ফ্রেমবাফার জিইউআই ইঞ্জিন (Lipi Linux Framebuffer GUI Engine)
// Module: universe/gui/framebuffer.lp
// Standard: Linux Framebuffer (/dev/fb0) & FBIOGET_VSCREENINFO / FSCREENINFO ABI
// 100% Pure Lipi Implementation — 0% C | 0% Libc | 0% X11 | 0% Wayland | 0% GTK
// ==============================================================================
//
// WHY: কোনো উইন্ডো সার্ভার (X11 বা Wayland) বা কোনো সি লাইব্রেরি ছাড়াই সরাসরি
// কার্নেলের /dev/fb0 ওপেন করে মেমরি ম্যাপ (mmap) করা এবং ডাইরেক্ট মেশিন কোড দিয়ে
// ফুল-স্ক্রিন উইন্ডো ম্যানেজার, বাটন, টেক্সট এবং গ্রাফিক্স রেন্ডার করা।

import "universe/os/syscalls"
import "universe/core/memory"
import "universe/core/string"

// ── ১. লিনাক্স ফ্রেমবাফার আইওসিটিএল (ioctl) কনস্ট্যান্টস ─────────────────────────
@fn FBIOGET_VSCREENINFO()       return 17920 @end      // 0x4600
@fn FBIOPUT_VSCREENINFO()       return 17921 @end      // 0x4601
@fn FBIOGET_FSCREENINFO()       return 17922 @end      // 0x4602

// ── ২. ফ্রেমবাফার ও ক্যানভাস ডাটা স্ট্রাকচার ───────────────────────────────────
@struct LipiFramebuffer
  fb_fd: i64
  width: i64
  height: i64
  bpp: i64             // Bits per pixel (usually 32 for ARGB8888)
  line_length: i64     // Hardware stride in bytes (মরণ ফাঁদ প্রতিরোধ)
  smem_len: i64        // Total video memory length
  front_ptr: i64       // mmap'd /dev/fb0 memory or VFB
  back_ptr: i64        // Double-buffered backbuffer
  is_virtual: i64      // 1 if running in headless/fallback VFB mode
  is_active: i64
@end

// ── ৩. ফ্রেমবাফার ইনিশিয়ালাইজেশন ও হার্ডওয়্যার স্টপ/স্টার্ট ──────────────────
// WHY: /dev/fb0 ওপেন করে ioctl দিয়ে স্ক্রিন সাইজ ও মেমোরি স্ট্রাইড বের করা।
// মরণ ফাঁদ ডিফেন্স: যদি /dev/fb0 এক্সেসযোগ্য না থাকে (যেমন হেডলেস সিআই বা ডকার),
// তবে স্বয়ংক্রিয়ভাবে ভার্চুয়াল ফ্রেমবাফার (VFB) সক্রিয় করে ক্র্যাশ প্রতিরোধ করা।
@fn lipi_fb_open(req_w: i64, req_h: i64)
  // Try opening /dev/fb0 with O_RDWR (2)
  fb_fd = sys_open("/dev/fb0", 2, 0)
  is_vfb = 0
  front_ptr = 0
  line_len = req_w * 4
  smem_len = req_w * req_h * 4
  bpp = 32
  actual_w = req_w
  actual_h = req_h

  @if fb_fd >= 0
    // Query screen info using ioctl
    // fb_var_screeninfo struct is 160 bytes
    vinfo_buf = lipi_alloc(160)
    // fb_fix_screeninfo struct is 64 bytes
    finfo_buf = lipi_alloc(64)

    r_v = sys_ioctl(fb_fd, FBIOGET_VSCREENINFO(), vinfo_buf)
    r_f = sys_ioctl(fb_fd, FBIOGET_FSCREENINFO(), finfo_buf)

    @if r_v == 0 && r_f == 0
      actual_w = mem_read_u32(vinfo_buf, 0)       // xres
      actual_h = mem_read_u32(vinfo_buf, 4)       // yres
      bpp = mem_read_u32(vinfo_buf, 24)           // bits_per_pixel
      smem_len = mem_read_u32(finfo_buf, 24)      // smem_len
      line_len = mem_read_u32(finfo_buf, 48)      // line_length (Hardware Stride)
      
      // Memory map hardware video RAM: MAP_SHARED (1)
      front_ptr = sys_mmap(0, smem_len, 3, 1, fb_fd, 0)
    @end

    @if front_ptr <= 0
      // If mmap failed, fallback to VFB
      is_vfb = 1
      front_ptr = lipi_alloc(smem_len)
    @end
  @else
    // Headless CI/Sandbox Fallback: Virtual Framebuffer
    is_vfb = 1
    front_ptr = lipi_alloc(smem_len)
  @end

  // Allocate double-buffered backbuffer
  back_ptr = lipi_alloc(smem_len)

  return {
    fb_fd: fb_fd,
    width: actual_w,
    height: actual_h,
    bpp: bpp,
    line_length: line_len,
    smem_len: smem_len,
    front_ptr: front_ptr,
    back_ptr: back_ptr,
    is_virtual: is_vfb,
    is_active: 1
  }
@end

// ── ৪. পিক্সেল ও জ্যামিতিক র‍্যাস্টারাইজার (Double-Buffered Rasterizer) ─────────
// WHY: ব্যাক-বাফারে পিক্সেল ড্র করা যাতে কোনো স্ক্রিন ফ্লিকারিং না হয়।
@fn fb_draw_pixel(fb: LipiFramebuffer, x: i64, y: i64, color: i64)
  @if fb == 0 || fb.is_active == 0 return 0 @end
  @if x < 0 || x >= fb.width || y < 0 || y >= fb.height return 0 @end

  // 🛡️ DYNAMIC HARDWARE STRIDE CALCULATION DEFENSE:
  // Using line_length instead of width * 4 prevents diagonal screen distortion!
  offset = (y * fb.line_length) + (x * 4)
  mem_write_u32(fb.back_ptr, offset, color)
  return 1
@end

@fn fb_read_pixel(fb: LipiFramebuffer, x: i64, y: i64)
  @if fb == 0 || fb.is_active == 0 return 0 @end
  @if x < 0 || x >= fb.width || y < 0 || y >= fb.height return 0 @end
  offset = (y * fb.line_length) + (x * 4)
  return mem_read_u32(fb.back_ptr, offset)
@end

@fn fb_fill_rect(fb: LipiFramebuffer, x: i64, y: i64, w: i64, h: i64, color: i64)
  @if fb == 0 || fb.is_active == 0 return 0 @end
  
  // Boundary clipping
  x1 = x
  y1 = y
  x2 = x + w
  y2 = y + h
  @if x1 < 0 x1 = 0 @end
  @if y1 < 0 y1 = 0 @end
  @if x2 > fb.width x2 = fb.width @end
  @if y2 > fb.height y2 = fb.height @end

  curr_y = y1
  @while curr_y < y2
    row_offset = curr_y * fb.line_length
    curr_x = x1
    @while curr_x < x2
      mem_write_u32(fb.back_ptr, row_offset + (curr_x * 4), color)
      curr_x = curr_x + 1
    @end
    curr_y = curr_y + 1
  @end
  return 1
@end

// ── ৫. লিপির অফিশিয়াল লোগোমার্ক রাস্টারাইজার (Official Lipi Brand Icon) ─────────
// WHY: ফ্রেমবাফার জিইউআইতে উইন্ডো টাইটেল বার বা সিস্টেম মেনুতে লিপির নিজস্ব L+P
// মিনিম্যালিস্ট আইকন (সায়ান স্টেম, পিঙ্ক বেস ও গোল্ডেন লুপ) সরাসরি রাস্টারাইজ করা।
@fn fb_draw_lipi_icon(fb, x, y)
  @if fb == 0 || fb.is_active == 0 return 0 @end
  
  // ব্যাকগ্রাউন্ড অফ-হোয়াইট ক্যানভাস (0x00F4F4F9 = 16053497)
  fb_fill_rect(fb, x, y, 12, 12, 16053497)

  // স্টেম: L এবং P এর কমন ভার্টিক্যাল বার (সায়ান: #00C2FF = 49919)
  fb_fill_rect(fb, x + 2, y + 2, 2, 8, 49919)

  // বেস: L-এর অনুভূমিক বেস বার (ম্যাজেন্টা/পিঙ্ক: #FF007A = 16711802)
  fb_fill_rect(fb, x + 2, y + 8, 6, 2, 16711802)

  // লুপ: P-এর বৃত্তাকার লুপ (গোল্ড/হলুদ: #FFD700 = 16766720)
  fb_fill_rect(fb, x + 4, y + 2, 4, 2, 16766720)
  fb_fill_rect(fb, x + 6, y + 4, 2, 2, 16766720)
  fb_fill_rect(fb, x + 4, y + 5, 3, 1, 16766720)

  return 1
@end

// ── ৬. উইন্ডো ম্যানেজার প্রিমিটিভস (Window Chrome & UI Controls) ────────────────
// WHY: অপারেটিং সিস্টেমের মতো টাইটেল বার, ক্লোজ বাটন ও উইন্ডো ফ্রেম তৈরি।
@fn fb_window_create(fb: LipiFramebuffer, x: i64, y: i64, w: i64, h: i64, title: string)
  @if fb == 0 || fb.is_active == 0 return 0 @end

  // Color Palette (ARGB):
  // Dark Background: 0xFF1E1E2E (Catppuccin Mocha Base)
  // Window Header:   0xFF181825 (Mantle)
  // Accent Border:   0xFF89B4FA (Blue)
  // Close Button:    0xFFF38BA8 (Red)
  col_bg = 2002734     // 0x001E1E2E
  col_hdr = 1579045    // 0x00181825
  col_border = 9024762 // 0x0089B4FA
  col_close = 15961000 // 0x00F38BA8

  // 1. Draw outer window border
  fb_fill_rect(fb, x - 1, y - 1, w + 2, h + 2, col_border)

  // 2. Draw window body background
  fb_fill_rect(fb, x, y, w, h, col_bg)

  // 3. Draw header/title bar (height = 24 pixels)
  header_height = 24
  fb_fill_rect(fb, x, y, w, header_height, col_hdr)

  // 4. Draw official Lipi Brand Icon at top left of title bar
  fb_draw_lipi_icon(fb, x + 6, y + 6)

  // 5. Draw close button (12x12 red box at top right)
  close_x = (x + w) - 18
  close_y = y + 6
  fb_fill_rect(fb, close_x, close_y, 12, 12, col_close)

  return 1
@end

@fn fb_button_create(fb: LipiFramebuffer, x: i64, y: i64, w: i64, h: i64, label: string, is_pressed: i64)
  @if fb == 0 || fb.is_active == 0 return 0 @end
  
  col_btn = 3289650   // Normal Button
  col_press = 5592405 // Pressed state
  col_border = 10066329

  // Outer border
  fb_fill_rect(fb, x, y, w, h, col_border)

  // Inner button body
  btn_col = col_btn
  @if is_pressed == 1
    btn_col = col_press
  @end
  fb_fill_rect(fb, x + 1, y + 1, w - 2, h - 2, btn_col)

  return 1
@end

// ── ৬. ডাবল-বাফার পেজ ফ্লিপ (Double-Buffer Blit) ─────────────────────────────
// WHY: ব্যাক-বাফার থেকে ফ্রন্ট-বাফারে সমস্ত পিক্সেল সিঙ্ক করা (Tear-free rendering)।
@fn fb_flip(fb: LipiFramebuffer)
  @if fb == 0 || fb.is_active == 0 return 0 @end

  y = 0
  @while y < fb.height
    row_offset = y * fb.line_length
    x = 0
    @while x < fb.width
      pix_off = row_offset + (x * 4)
      color = mem_read_u32(fb.back_ptr, pix_off)
      mem_write_u32(fb.front_ptr, pix_off, color)
      x = x + 1
    @end
    y = y + 1
  @end

  return 1
@end

// ── ৭. ক্লিনআপ ও রিসোর্স অবমুক্তি ─────────────────────────────────────────────
@fn lipi_fb_close(fb: LipiFramebuffer)
  @if fb == 0 || fb.is_active == 0 return 0 @end

  @if fb.fb_fd >= 0
    sys_close(fb.fb_fd)
    fb.fb_fd = 0 - 1
  @end

  fb.is_active = 0
  return 1
@end
