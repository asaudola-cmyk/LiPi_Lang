// ============================================================================
// LIPI SOVEREIGN COMPILER — WINDOWS PE32+ DOS HEADER & STUB SERIALIZER
// Module: src/compiler/backend/formats/pe/dos_header.lp
// Standard: Microsoft Portable Executable and Common Object File Format (PE/COFF)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: Every valid Microsoft Windows Portable Executable (PE/COFF) binary
// begins with a legacy MS-DOS 2.0 compatible header (IMAGE_DOS_HEADER).
// This preserves backward compatibility: if run on real-mode MS-DOS, it executes
// a tiny 16-bit stub displaying "This program cannot be run in DOS mode."
// Crucially, offset 0x3C (e_lfanew) stores a 32-bit pointer to the true 64-bit
// PE signature ("PE\0\0" = 0x00004550).

// --- DOS Magic & PE Signature Constants ---
@fn IMAGE_DOS_SIGNATURE() return 23117      @end // 0x5A4D ('MZ' Little-Endian: 77 + 90*256)
@fn IMAGE_NT_SIGNATURE()  return 17744      @end // 0x4550 ('PE\0\0' Little-Endian: 80 + 69*256)
@fn PE_LFANEW_OFFSET()    return 128        @end // 0x80: Standard file offset to PE signature
@fn DOS_HEADER_SIZE()     return 64         @end // 64 bytes (0x00..0x3F)
@fn DOS_STUB_TOTAL_SIZE() return 128        @end // 128 bytes (0x00..0x7F)

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct ImageDosHeader
  e_magic: i64    // 2 bytes: Magic number (0x5A4D = "MZ")
  e_cblp: i64     // 2 bytes: Bytes on last page of file (0x0090 = 144)
  e_cp: i64       // 2 bytes: Pages in file (0x0003 = 3)
  e_crlc: i64     // 2 bytes: Relocations (0)
  e_cparhdr: i64  // 2 bytes: Size of header in paragraphs (0x0004 = 4 paragraphs = 64 bytes)
  e_minalloc: i64 // 2 bytes: Minimum extra paragraphs needed (0)
  e_maxalloc: i64 // 2 bytes: Maximum extra paragraphs needed (0xFFFF = 65535)
  e_ss: i64       // 2 bytes: Initial relative SS value (0)
  e_sp: i64       // 2 bytes: Initial SP value (0x00B8 = 184)
  e_csum: i64     // 2 bytes: Checksum (0)
  e_ip: i64       // 2 bytes: Initial IP value (0)
  e_cs: i64       // 2 bytes: Initial relative CS value (0)
  e_lfarlc: i64   // 2 bytes: File address of relocation table (0x0040 = 64)
  e_ovno: i64     // 2 bytes: Overlay number (0)
  e_lfanew: i64   // 4 bytes: File address of new exe header (0x80 = 128)
@end

// ============================================================================
// 2. INTEGER PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn pe_pack_u16_le(val)
  v = val
  @if v < 0
    v = v + 65536
  @end
  return [v % 256, (v / 256) % 256]
@end

@fn pe_pack_u32_le(val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

// ============================================================================
// 3. DOS HEADER BUILDER & SERIALIZER
// ============================================================================

@fn pe_dos_header_create(pe_header_offset)
  // WHY: Constructs the canonical 64-byte MS-DOS header.
  // e_lfanew points to the start of the PE signature (default: 128 / 0x80).
  lfanew = pe_header_offset
  @if lfanew <= 0
    lfanew = PE_LFANEW_OFFSET()
  @end

  return {
    e_magic: 23117, // 'M', 'Z' (0x5A4D)
    e_cblp: 144,
    e_cp: 3,
    e_crlc: 0,
    e_cparhdr: 4,   // 4 * 16 = 64 bytes
    e_minalloc: 0,
    e_maxalloc: 65535,
    e_ss: 0,
    e_sp: 184,      // 0xB8
    e_csum: 0,
    e_ip: 0,
    e_cs: 0,
    e_lfarlc: 64,   // 0x40
    e_ovno: 0,
    e_lfanew: lfanew
  }
@end

@fn pe_dos_header_serialize(dhdr)
  // WHY: Serializes IMAGE_DOS_HEADER to exactly 64 bytes.
  // Critical offsets:
  //   0x00: 'M', 'Z' (0x4D, 0x5A)
  //   0x3C: e_lfanew (4 bytes pointing to PE signature)
  out = []

  // 0x00: e_magic
  m = pe_pack_u16_le(dhdr.e_magic)
  out = out.push(m[0]) out = out.push(m[1])

  // 0x02: e_cblp
  cblp = pe_pack_u16_le(dhdr.e_cblp)
  out = out.push(cblp[0]) out = out.push(cblp[1])

  // 0x04: e_cp
  cp = pe_pack_u16_le(dhdr.e_cp)
  out = out.push(cp[0]) out = out.push(cp[1])

  // 0x06: e_crlc
  crlc = pe_pack_u16_le(dhdr.e_crlc)
  out = out.push(crlc[0]) out = out.push(crlc[1])

  // 0x08: e_cparhdr
  cpar = pe_pack_u16_le(dhdr.e_cparhdr)
  out = out.push(cpar[0]) out = out.push(cpar[1])

  // 0x0A: e_minalloc
  mina = pe_pack_u16_le(dhdr.e_minalloc)
  out = out.push(mina[0]) out = out.push(mina[1])

  // 0x0C: e_maxalloc
  maxa = pe_pack_u16_le(dhdr.e_maxalloc)
  out = out.push(maxa[0]) out = out.push(maxa[1])

  // 0x0E: e_ss
  ss = pe_pack_u16_le(dhdr.e_ss)
  out = out.push(ss[0]) out = out.push(ss[1])

  // 0x10: e_sp
  sp = pe_pack_u16_le(dhdr.e_sp)
  out = out.push(sp[0]) out = out.push(sp[1])

  // 0x12: e_csum
  csum = pe_pack_u16_le(dhdr.e_csum)
  out = out.push(csum[0]) out = out.push(csum[1])

  // 0x14: e_ip
  ip = pe_pack_u16_le(dhdr.e_ip)
  out = out.push(ip[0]) out = out.push(ip[1])

  // 0x16: e_cs
  cs = pe_pack_u16_le(dhdr.e_cs)
  out = out.push(cs[0]) out = out.push(cs[1])

  // 0x18: e_lfarlc
  lfar = pe_pack_u16_le(dhdr.e_lfarlc)
  out = out.push(lfar[0]) out = out.push(lfar[1])

  // 0x1A: e_ovno
  ovno = pe_pack_u16_le(dhdr.e_ovno)
  out = out.push(ovno[0]) out = out.push(ovno[1])

  // 0x1C..0x23: e_res[4] (8 bytes zero)
  k = 0 @while k < 8 out = out.push(0) k = k + 1 @end

  // 0x24: e_oemid (2 bytes)
  out = out.push(0) out = out.push(0)

  // 0x26: e_oeminfo (2 bytes)
  out = out.push(0) out = out.push(0)

  // 0x28..0x3B: e_res2[10] (20 bytes zero)
  k = 0 @while k < 20 out = out.push(0) k = k + 1 @end

  // 0x3C: e_lfanew (4 bytes)
  lfn = pe_pack_u32_le(dhdr.e_lfanew)
  out = out.push(lfn[0])
  out = out.push(lfn[1])
  out = out.push(lfn[2])
  out = out.push(lfn[3])

  return out
@end

// ============================================================================
// 4. REAL-MODE 16-BIT MS-DOS COMPATIBILITY STUB (64 Bytes)
// ============================================================================

@fn pe_build_dos_stub()
  // WHY: The standard 64-byte MS-DOS stub placed from offset 0x40 to 0x7F.
  // Disassembly (16-bit real mode):
  // 0x0E: push cs
  // 0x1F: pop ds
  // 0xBA 0x0E 0x00: mov dx, 0x000E (points to string at offset 0x0E in stub)
  // 0xB4 0x09: mov ah, 0x09 (DOS print string terminated by '$')
  // 0xCD 0x21: int 0x21
  // 0xB8 0x01 0x4C: mov ax, 0x4C01 (DOS terminate with exit code 1)
  // 0xCD 0x21: int 0x21
  // Followed by: "This program cannot be run in DOS mode.\r\r\n$"
  // Followed by zero padding to exactly 64 bytes.

  stub = [
    14,                                     // 0x0E: push cs
    31,                                     // 0x1F: pop ds
    186, 14, 0,                             // 0xBA 0x0E 0x00: mov dx, 0x000E
    180, 9,                                 // 0xB4 0x09: mov ah, 0x09
    205, 33,                                // 0xCD 0x21: int 0x21
    184, 1, 76,                             // 0xB8 0x01 0x4C: mov ax, 0x4C01
    205, 33,                                // 0xCD 0x21: int 0x21
    // String: "This program cannot be run in DOS mode.\r\r\n$"
    84, 104, 105, 115, 32, 112, 114, 111, 103, 114, 97, 109, 32, // "This program "
    99, 97, 110, 110, 111, 116, 32,                               // "cannot "
    98, 101, 32,                                                  // "be "
    114, 117, 110, 32,                                            // "run "
    105, 110, 32,                                                 // "in "
    68, 79, 83, 32,                                               // "DOS "
    109, 111, 100, 101, 46,                                       // "mode."
    13, 13, 10, 36                                                // "\r\r\n$"
  ]

  // Pad stub to exactly 64 bytes
  @while stub.len() < 64
    stub = stub.push(0)
  @end

  return stub
@end

// ============================================================================
// 5. PE SIGNATURE SERIALIZER (4 Bytes at e_lfanew)
// ============================================================================

@fn pe_signature_bytes()
  // WHY: The 4-byte signature 'P', 'E', 0, 0 (0x00004550) marks the start of the COFF header.
  // The Windows NT PE loader validates these exact 4 bytes.
  return [80, 69, 0, 0] // 0x50, 0x45, 0x00, 0x00
@end

// ============================================================================
// 6. COMPOSITE DOS STUB GENERATOR (128 Bytes Out)
// ============================================================================

@fn pe_dos_block_serialize()
  // WHY: Generates the full 128-byte DOS preamble (64 bytes DOS Header + 64 bytes DOS Stub).
  // Next byte immediately following this block will be offset 0x80 (PE Signature).
  dhdr = pe_dos_header_create(128)
  dhdr_bytes = pe_dos_header_serialize(dhdr) // 64 bytes
  stub_bytes = pe_build_dos_stub()           // 64 bytes

  out = []
  i = 0 @while i < 64 out = out.push(dhdr_bytes[i]) i = i + 1 @end
  i = 0 @while i < 64 out = out.push(stub_bytes[i]) i = i + 1 @end
  return out
@end
