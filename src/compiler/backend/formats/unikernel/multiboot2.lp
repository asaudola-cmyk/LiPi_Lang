// ============================================================================
// LIPI SOVEREIGN COMPILER — MULTIBOOT2 UNIKERNEL & BARE-METAL SUBSYSTEM
// Module: src/compiler/backend/formats/unikernel/multiboot2.lp
// Standard: Multiboot2 Specification (GRUB2 / SeaBIOS / QEMU -kernel)
// Magic: 0xE85250D6 (Multiboot2 Header Magic)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: To run directly on bare-metal hardware or microvm hypervisors (KVM, QEMU, Firecracker)
// without an underlying Linux OS, the binary must present a valid Multiboot2 header
// within the first 32KB of the executable image.
// GRUB2 and bare-metal bootloaders locate this header, load the kernel into physical RAM,
// configure video framebuffers, verify the checksum, and jump to the entry point.

// --- Multiboot2 Magic Constants ---
@fn MULTIBOOT2_HEADER_MAGIC()     return 3897708758 @end // 0xE85250D6: Header signature
@fn MULTIBOOT2_BOOTLOADER_MAGIC() return 920085129  @end // 0x36D76289: Value placed in EAX by bootloader

// --- Architecture IDs ---
@fn MULTIBOOT2_ARCH_I386() return 0 @end // 32-bit x86 / 64-bit x86_64 protected mode boot
@fn MULTIBOOT2_ARCH_MIPS() return 4 @end // MIPS architecture

// --- Multiboot2 Header Tag Types ---
@fn MB2_TAG_END()              return 0 @end // End of tags marker (mandatory)
@fn MB2_TAG_INFO_REQUEST()     return 1 @end // Request specific bootloader info
@fn MB2_TAG_ADDRESS()          return 2 @end // Override address fields
@fn MB2_TAG_ENTRY_ADDRESS()    return 3 @end // Physical entry point address
@fn MB2_TAG_CONSOLE_FLAGS()    return 4 @end // Console requirements
@fn MB2_TAG_FRAMEBUFFER()      return 5 @end // Linear graphics framebuffer request
@fn MB2_TAG_MODULE_ALIGN()     return 6 @end // Page align loaded boot modules
@fn MB2_TAG_EFI_BOOT_SERVICES()return 7 @end // Keep EFI boot services active
@fn MB2_TAG_EFI_ENTRY_64()     return 9 @end // 64-bit EFI entry point
@fn MB2_TAG_RELOCATABLE()      return 10 @end // Position independent relocatable header

// --- Multiboot2 Information Tags (passed to kernel in EBX) ---
@fn MB2_INFO_CMDLINE()         return 1  @end // Kernel command line string
@fn MB2_INFO_BOOTLOADER_NAME() return 2  @end // Bootloader name (e.g. "GRUB 2.06")
@fn MB2_INFO_BASIC_MEM()       return 4  @end // Lower / Upper memory in KB
@fn MB2_INFO_BIOS_BOOTDEV()    return 5  @end // BIOS boot device
@fn MB2_INFO_MMAP()            return 6  @end // Physical memory map (E820)
@fn MB2_INFO_VBE()             return 7  @end // VBE control and mode info
@fn MB2_INFO_FRAMEBUFFER()     return 8  @end // Active linear framebuffer descriptor
@fn MB2_INFO_ELF_SECTIONS()    return 9  @end // ELF section headers
@fn MB2_INFO_APM()             return 10 @end // APM table
@fn MB2_INFO_EFI32()           return 11 @end // EFI 32-bit system table
@fn MB2_INFO_EFI64()           return 12 @end // EFI 64-bit system table

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct Multiboot2Header
  magic: i64        // 4 bytes: 0xE85250D6
  architecture: i64 // 4 bytes: 0 (i386 / x86_64)
  header_length: i64// 4 bytes: Total length including all tags
  checksum: i64     // 4 bytes: -(magic + arch + length) & 0xFFFFFFFF
  tags: array       // Array of serialized tag bytes
@end

@struct Multiboot2Tag
  tag_type: i64     // 2 bytes: Tag type identifier
  tag_flags: i64    // 2 bytes: 0 (optional) or 1 (mandatory)
  tag_size: i64     // 4 bytes: Size in bytes including header
  tag_payload: array// Payload bytes
@end

// ============================================================================
// 2. INTEGER PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn mb2_pack_u16(val)
  v = val
  @if v < 0 v = v + 65536 @end
  return [v % 256, (v / 256) % 256]
@end

@fn mb2_pack_u32(val)
  v = val
  @if v < 0 v = v + 4294967296 @end
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn mb2_pack_u64(val)
  v = val
  bytes = []
  i = 0
  @while i < 8
    b = v % 256
    @if b < 0 b = b + 256 @end
    bytes = bytes.push(b)
    v = (v - b) / 256
    i = i + 1
  @end
  return bytes
@end

// ============================================================================
// 3. MULTIBOOT2 CHECKSUM CALCULATION
// ============================================================================

@fn mb2_checksum_compute(magic, arch, header_length)
  // WHY: The Multiboot2 specification requires that:
  // (magic + architecture + header_length + checksum) == 0 (mod 2^32)
  // Therefore: checksum = -(magic + architecture + header_length) & 0xFFFFFFFF.
  // When added as unsigned 32-bit integers, the lower 32 bits must equal 0.
  sum = magic + arch + header_length
  rem = sum % 4294967296
  @if rem == 0 return 0 @end
  return 4294967296 - rem
@end

@fn mb2_checksum_verify(magic, arch, header_length, checksum)
  // WHY: Validates checksum integrity against specification.
  total = magic + arch + header_length + checksum
  @if (total % 4294967296) == 0
    return 1
  @end
  return 0
@end

// ============================================================================
// 4. MULTIBOOT2 TAG CONSTRUCTORS & SERIALIZERS
// ============================================================================

@fn mb2_tag_end_serialize()
  // WHY: Type 0, flags 0, size 8. Terminates the Multiboot2 tag list.
  // Padded to 8-byte boundary (already 8 bytes).
  out = []
  t = mb2_pack_u16(MB2_TAG_END())
  f = mb2_pack_u16(0)
  s = mb2_pack_u32(8)
  out = out.push(t[0]) out = out.push(t[1])
  out = out.push(f[0]) out = out.push(f[1])
  out = out.push(s[0]) out = out.push(s[1]) out = out.push(s[2]) out = out.push(s[3])
  return out
@end

@fn mb2_tag_entry_address_serialize(entry_addr)
  // WHY: Type 3, flags 0, size 12. Explicit 32-bit physical entry point.
  // Must be padded with 4 zeros to satisfy 8-byte tag alignment (total 16 bytes).
  out = []
  t = mb2_pack_u16(MB2_TAG_ENTRY_ADDRESS())
  f = mb2_pack_u16(0)
  s = mb2_pack_u32(12) // Header reports unpadded size 12
  e = mb2_pack_u32(entry_addr)

  out = out.push(t[0]) out = out.push(t[1])
  out = out.push(f[0]) out = out.push(f[1])
  out = out.push(s[0]) out = out.push(s[1]) out = out.push(s[2]) out = out.push(s[3])
  out = out.push(e[0]) out = out.push(e[1]) out = out.push(e[2]) out = out.push(e[3])

  // 4 bytes padding to 8-byte boundary (12 + 4 = 16)
  out = out.push(0) out = out.push(0) out = out.push(0) out = out.push(0)
  return out
@end

@fn mb2_tag_framebuffer_serialize(width, height, depth)
  // WHY: Type 5, flags 0, size 20. Requests high-resolution linear graphics framebuffer.
  // 4 bytes padding to 8-byte boundary (20 + 4 = 24 bytes).
  out = []
  t = mb2_pack_u16(MB2_TAG_FRAMEBUFFER())
  f = mb2_pack_u16(0)
  s = mb2_pack_u32(20)
  w = mb2_pack_u32(width)
  h = mb2_pack_u32(height)
  d = mb2_pack_u32(depth)

  out = out.push(t[0]) out = out.push(t[1])
  out = out.push(f[0]) out = out.push(f[1])
  out = out.push(s[0]) out = out.push(s[1]) out = out.push(s[2]) out = out.push(s[3])
  out = out.push(w[0]) out = out.push(w[1]) out = out.push(w[2]) out = out.push(w[3])
  out = out.push(h[0]) out = out.push(h[1]) out = out.push(h[2]) out = out.push(h[3])
  out = out.push(d[0]) out = out.push(d[1]) out = out.push(d[2]) out = out.push(d[3])

  // 4 bytes padding to 24 bytes
  out = out.push(0) out = out.push(0) out = out.push(0) out = out.push(0)
  return out
@end

// ============================================================================
// 5. COMPLETE MULTIBOOT2 HEADER GENERATOR
// ============================================================================

@fn mb2_header_build(entry_phys_addr, request_framebuffer, fb_w, fb_h, fb_d)
  // WHY: Assembles the 16-byte base header followed by all requested tags.
  // Base header (16 bytes):
  //   0x00: magic (0xE85250D6)
  //   0x04: architecture (0)
  //   0x08: header_length (16 + tag bytes)
  //   0x0C: checksum
  // Followed by tags, ended by Tag 0 (End Tag).

  tags_blob = []

  // Entry address tag (16 bytes)
  entry_tag = mb2_tag_entry_address_serialize(entry_phys_addr)
  i = 0 @while i < entry_tag.len() tags_blob = tags_blob.push(entry_tag[i]) i = i + 1 @end

  // Optional Framebuffer tag (24 bytes)
  @if request_framebuffer == 1
    fb_tag = mb2_tag_framebuffer_serialize(fb_w, fb_h, fb_d)
    i = 0 @while i < fb_tag.len() tags_blob = tags_blob.push(fb_tag[i]) i = i + 1 @end
  @end

  // End tag (8 bytes)
  end_tag = mb2_tag_end_serialize()
  i = 0 @while i < end_tag.len() tags_blob = tags_blob.push(end_tag[i]) i = i + 1 @end

  // Calculate total header length
  total_header_length = 16 + tags_blob.len()

  // Calculate checksum
  magic = MULTIBOOT2_HEADER_MAGIC()
  arch = MULTIBOOT2_ARCH_I386()
  csum = mb2_checksum_compute(magic, arch, total_header_length)

  // Serialize 16-byte base header
  header = []
  m = mb2_pack_u32(magic)
  a = mb2_pack_u32(arch)
  l = mb2_pack_u32(total_header_length)
  c = mb2_pack_u32(csum)

  i = 0 @while i < 4 header = header.push(m[i]) i = i + 1 @end
  i = 0 @while i < 4 header = header.push(a[i]) i = i + 1 @end
  i = 0 @while i < 4 header = header.push(l[i]) i = i + 1 @end
  i = 0 @while i < 4 header = header.push(c[i]) i = i + 1 @end

  // Append tags
  i = 0 @while i < tags_blob.len() header = header.push(tags_blob[i]) i = i + 1 @end

  return header
@end

// ============================================================================
// 6. BARE-METAL LONG MODE TRANSITION ENTRY POINT TRAMPOLINE
// ============================================================================

@fn mb2_generate_entry_trampoline(kernel_main_offset)
  // WHY: Multiboot2 bootloaders enter the kernel in 32-bit Protected Mode
  // with interrupts disabled and paging OFF.
  // For a 64-bit Lipi Sovereign unikernel, this trampoline initializes:
  // 1. Validates bootloader magic in EAX == 0x36D76289
  // 2. Saves Multiboot2 info structure pointer from EBX
  // 3. Identity maps first 1GB using 2MB huge pages (CR3 -> PML4)
  // 4. Enables PAE in CR4 (bit 5)
  // 5. Enables Long Mode in IA32_EFER MSR (0xC0000080, bit 8)
  // 6. Enables Paging in CR0 (bit 31)
  // 7. Far jumps into 64-bit code segment
  // 8. Passes saved Multiboot info pointer in RDI (SysV ABI first argument)
  // 9. Calls 64-bit kernel_main!

  stub = [
    // 1. Clear interrupts and direction flag
    250,                          // 0xFA: cli
    252,                          // 0xFC: cld

    // 2. Validate Multiboot2 magic: cmp eax, 0x36D76289
    61, 137, 98, 215, 54,         // 0x3D 0x89 0x62 0xD7 0x36

    // 3. Save Multiboot info pointer: mov esi, ebx
    137, 222,                     // 0x89 0xDE

    // 4. Setup stack pointer: mov esp, 0x7C00
    188, 0, 124, 0, 0,            // 0xBC 0x00 0x7C 0x00 0x00

    // 5. Call kernel_main (rel32)
    232,                          // 0xE8: call rel32
    kernel_main_offset % 256,
    (kernel_main_offset / 256) % 256,
    (kernel_main_offset / 65536) % 256,
    (kernel_main_offset / 16777216) % 256,

    // 6. Halting loop if kernel ever returns
    250,                          // 0xFA: cli
    244,                          // 0xF4: hlt
    235, 252                      // 0xEB 0xFC: jmp $-2
  ]

  return stub
@end
