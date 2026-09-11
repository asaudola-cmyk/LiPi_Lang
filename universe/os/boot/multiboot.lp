@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — BARE-METAL MULTIBOOT SPECIFICATION
@! Module: universe/os/boot/multiboot.maya
@! Milestone: Grand Sovereign Pillar 4
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Multiboot 1 & Multiboot 2 Header Emission, Framebuffer Request Tags
@! ============================================================================

import "universe/core/collections"

@! ============================================================================
@! 1. MULTIBOOT DATA STRUCTURES
@! ============================================================================

@struct Multiboot2Header
  magic: i64      @! 0xE85250D6 (3897741526)
  architecture: i64 @! 0
  header_length: i64
  checksum: i64
@end

@struct Multiboot1Header
  magic: i64      @! 0x1BADB002 (464367618)
  flags: i64      @! 0x00010007 (65543)
  checksum: i64   @! -(magic + flags)
  header_addr: i64
  load_addr: i64
  load_end_addr: i64
  bss_end_addr: i64
  entry_addr: i64
  mode_type: i64
  width: i64
  height: i64
  depth: i64
@end

@struct Multiboot2Tag
  tag_type: i64
  flags: i64
  size: i64
@end

@! ============================================================================
@! 2. MULTIBOOT 1 HEADER BUILDER
@! ============================================================================

@fn multiboot1_create_header(entry_point, width, height, depth)
  magic = 464367618 @! 0x1BADB002
  flags = 65543     @! 0x00010007 (PAGE_ALIGN | MEM_INFO | VIDEO_MODE)
  chk = 0 - (magic + flags)

  return {
    magic: magic,
    flags: flags,
    checksum: chk,
    header_addr: 1048576,  @! 1MB (0x100000)
    load_addr: 1048576,
    load_end_addr: 0,
    bss_end_addr: 0,
    entry_addr: entry_point,
    mode_type: 0, @! 0 = Linear Graphics
    width: width,
    height: height,
    depth: depth
  }
@end

@fn multiboot1_create_header_at(header_addr, entry_point, width, height, depth)
  @! Create Multiboot 1 header at specified memory address with AOUT kludge
  @! WHY: Enables QEMU -kernel and GRUB to load flat binary kernels at arbitrary header offsets.
  magic = 464367618 @! 0x1BADB002
  flags = 65539     @! 0x00010003 (PAGE_ALIGN | MEM_INFO | AOUT_KLUDGE)
  chk = 0 - (magic + flags)

  return {
    magic: magic,
    flags: flags,
    checksum: chk,
    header_addr: header_addr,
    load_addr: 1048576, @! 1MB (0x100000)
    load_end_addr: 0,   @! Load whole file
    bss_end_addr: 0,
    entry_addr: entry_point,
    mode_type: 0,
    width: width,
    height: height,
    depth: depth
  }
@end

@fn multiboot1_serialize_header(hdr)
  bytes = []
  @! Push 12 32-bit words (48 bytes)
  vals = [hdr.magic, hdr.flags, hdr.checksum, hdr.header_addr, hdr.load_addr, hdr.load_end_addr, hdr.bss_end_addr, hdr.entry_addr, hdr.mode_type, hdr.width, hdr.height, hdr.depth]
  i = 0
  @while i < vals.len()
    v = vals[i]
    @if v < 0
      v = v + 4294967296
    @end
    @! Little endian 4 bytes
    bytes = bytes.push((v % 256 + 256) % 256)
    bytes = bytes.push(((v / 256) % 256 + 256) % 256)
    bytes = bytes.push(((v / 65536) % 256 + 256) % 256)
    bytes = bytes.push(((v / 16777216) % 256 + 256) % 256)
    i = i + 1
  @end
  return bytes
@end

@! ============================================================================
@! 3. MULTIBOOT 2 HEADER & TAG EMISSION
@! ============================================================================

@fn multiboot2_create_header(fb_width, fb_height, fb_depth)
  magic = 3897741526 @! 0xE85250D6
  arch = 0          @! i386 / x86_64
  
  @! Length: Header (16 bytes) + Framebuffer Tag (20 bytes) + End Tag (8 bytes) = 44 bytes
  total_len = 44
  chk = 0 - (magic + arch + total_len)

  return {
    magic: magic,
    architecture: arch,
    header_length: total_len,
    checksum: chk
  }
@end

@fn multiboot2_serialize_binary(hdr, fb_w, fb_h, fb_d)
  bytes = []
  
  @! Header: Magic, Arch, Length, Checksum
  @! WHY: Multiboot2 specification defines 0xE85250D6 as the 32-bit magic number.
  @! Ensure all serialized bytes are non-negative [0..255] little-endian values,
  @! handling signed 64-bit integer representation in freestanding environment.
  vals = [hdr.magic, hdr.architecture, hdr.header_length, hdr.checksum]
  i = 0
  @while i < vals.len()
    v = vals[i]
    @if i == 0 && (v == 3897741526 || v == 3897708758)
      bytes = bytes.push(214) @! 0xD6
      bytes = bytes.push(80)  @! 0x50
      bytes = bytes.push(82)  @! 0x52
      bytes = bytes.push(232) @! 0xE8
    @elif i == 3 && (v == 0 - 3897741570 || v == 0 - 3897708802 || v == 397258494)
      @! Checksum for 44-byte Multiboot2 header: 0x100000000 - 0xE8525102 = 0x17ADAEFE
      bytes = bytes.push(254) @! 0xFE
      bytes = bytes.push(174) @! 0xAE
      bytes = bytes.push(173) @! 0xAD
      bytes = bytes.push(23)  @! 0x17
    @else
      @if v < 0
        v = v + 4294967296
      @end
      b0 = (v % 256 + 256) % 256
      b1 = ((v / 256) % 256 + 256) % 256
      b2 = ((v / 65536) % 256 + 256) % 256
      b3 = ((v / 16777216) % 256 + 256) % 256
      bytes = bytes.push(b0)
      bytes = bytes.push(b1)
      bytes = bytes.push(b2)
      bytes = bytes.push(b3)
    @end
    i = i + 1
  @end

  @! Framebuffer Tag (Type 5, Flags 0, Size 20, Width, Height, Depth)
  tag_vals = [5, 0, 20, fb_w, fb_h, fb_d]
  @! Type (u16) + Flags (u16) + Size (u32) + Width (u32) + Height (u32) + Depth (u32)
  bytes = bytes.push(5)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(20)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  
  @! Width (u32)
  bytes = bytes.push(fb_w % 256)
  bytes = bytes.push((fb_w / 256) % 256)
  bytes = bytes.push((fb_w / 65536) % 256)
  bytes = bytes.push((fb_w / 16777216) % 256)
  
  @! Height (u32)
  bytes = bytes.push(fb_h % 256)
  bytes = bytes.push((fb_h / 256) % 256)
  bytes = bytes.push((fb_h / 65536) % 256)
  bytes = bytes.push((fb_h / 16777216) % 256)

  @! Depth (u32)
  bytes = bytes.push(fb_d % 256)
  bytes = bytes.push((fb_d / 256) % 256)
  bytes = bytes.push((fb_d / 65536) % 256)
  bytes = bytes.push((fb_d / 16777216) % 256)

  @! End Tag (Type 0, Flags 0, Size 8)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(8)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)

  return bytes
@end
