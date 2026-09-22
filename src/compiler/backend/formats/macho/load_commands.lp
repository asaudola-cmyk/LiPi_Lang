// ============================================================================
// LIPI SOVEREIGN COMPILER — APPLE MACOS MACH-O 64 LOAD COMMAND SERIALIZER
// Module: src/compiler/backend/formats/macho/load_commands.lp
// Standard: Apple OS X / macOS Mach-O 64-bit ABI Specification
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: macOS kernels (XNU / Darwin) and the Apple dynamic linker (dyld) execute
// Mach-O binaries. Instead of ELF Program Headers, Mach-O uses a variable-length
// sequence of Load Commands following the 32-byte mach_header_64.
// These load commands define the memory map (LC_SEGMENT_64), execution entry
// point (LC_MAIN), runtime dynamic linker path (LC_LOAD_DYLINKER), and code signatures.

import "universe/core/string"

// --- Mach-O 64-Bit Magic Signatures ---
// WHY: 0xFEEDFACF identifies a 64-bit Little-Endian Mach-O binary.
@fn MH_MAGIC_64() return 4277009103 @end // 0xFEEDFACF
@fn MH_CIGAM_64() return 3489328638 @end // 0xCFFAEDFE (Big-Endian byte swapped)

// --- CPU Architecture Types ---
// WHY: In Mach-O, cputype has bit 0x01000000 (CPU_ARCH_ABI64 = 16777216) set for 64-bit.
@fn CPU_TYPE_X86_64()  return 16777223 @end // CPU_TYPE_I386(7) | CPU_ARCH_ABI64(0x01000000)
@fn CPU_TYPE_ARM64()   return 16777228 @end // CPU_TYPE_ARM(12)  | CPU_ARCH_ABI64(0x01000000)

// --- CPU Subtypes ---
@fn CPU_SUBTYPE_LIB64()       return 2147483648 @end // 0x80000000: Feature mask for 64-bit
@fn CPU_SUBTYPE_X86_64_ALL()  return 3          @end
@fn CPU_SUBTYPE_ARM64_ALL()   return 0          @end

// --- Mach-O File Types (filetype) ---
@fn MH_OBJECT()  return 1 @end // Relocatable object file (.o)
@fn MH_EXECUTE() return 2 @end // Demand-paged executable binary
@fn MH_DYLIB()   return 6 @end // Dynamically linked shared library (.dylib)
@fn MH_BUNDLE()  return 8 @end // Dynamically loaded bundle plugin

// --- Mach-O Header Flags ---
@fn MH_NOUNDEFS()   return 1       @end // 0x1: Binary has no undefined references
@fn MH_DYLDLINK()   return 4       @end // 0x4: Binary is input for the dynamic linker
@fn MH_TWOLEVEL()   return 128     @end // 0x80: Two-level namespace bindings
@fn MH_PIE()        return 2097152 @end // 0x200000: Position Independent Executable

// --- Load Command Type Identifiers (cmd) ---
@fn LC_SEGMENT_64()    return 25         @end // 0x19: 64-bit VM segment mapping
@fn LC_SYMTAB()        return 2          @end // 0x02: Symbol table and string table offsets
@fn LC_DYSYMTAB()      return 11         @end // 0x0B: Dynamic symbol table info
@fn LC_LOAD_DYLINKER() return 14         @end // 0x0E: Path to dyld (/usr/lib/dyld)
@fn LC_LOAD_DYLIB()    return 12         @end // 0x0C: Load dynamic library dependency
@fn LC_MAIN()          return 2147483688 @end // 0x80000028: Modern replacement for LC_UNIXTHREAD

// --- VM Protection Flags ---
@fn VM_PROT_NONE()    return 0 @end
@fn VM_PROT_READ()    return 1 @end
@fn VM_PROT_WRITE()   return 2 @end
@fn VM_PROT_EXECUTE() return 4 @end
@fn VM_PROT_RX()      return 5 @end // Read + Execute (Code / __TEXT)
@fn VM_PROT_RW()      return 3 @end // Read + Write (Data / __DATA)
@fn VM_PROT_RWX()     return 7 @end // All permissions

// --- Section Attributes & Types ---
@fn S_REGULAR()                   return 0          @end // Standard data or code
@fn S_ZEROFILL()                  return 1          @end // Uninitialized BSS memory
@fn S_CSTRING_LITERALS()          return 2          @end // Null-terminated literal strings
@fn S_ATTR_SOME_INSTRUCTIONS()    return 1024       @end // 0x00000400: Contains instructions
@fn S_ATTR_PURE_INSTRUCTIONS()    return 2147483648 @end // 0x80000000: Pure machine code

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct MachOHeader64
  mh_magic: i64      // 4 bytes: MH_MAGIC_64 (0xFEEDFACF)
  mh_cputype: i64    // 4 bytes: CPU_TYPE_X86_64 or CPU_TYPE_ARM64
  mh_cpusubtype: i64 // 4 bytes: Subtype
  mh_filetype: i64   // 4 bytes: MH_EXECUTE (2)
  mh_ncmds: i64      // 4 bytes: Number of load commands
  mh_sizeofcmds: i64 // 4 bytes: Total byte size of all load commands
  mh_flags: i64      // 4 bytes: Flags (MH_NOUNDEFS | MH_DYLDLINK | MH_PIE)
  mh_reserved: i64   // 4 bytes: Reserved (must be 0)
@end

@struct MachOSegment64
  seg_cmd: i64      // 4 bytes: LC_SEGMENT_64 (0x19)
  seg_cmdsize: i64  // 4 bytes: 72 + (80 * nsects)
  seg_name: string  // 16 bytes: Segment name (e.g. "__PAGEZERO", "__TEXT", "__DATA")
  seg_vmaddr: i64   // 8 bytes: Virtual address
  seg_vmsize: i64   // 8 bytes: Memory footprint
  seg_fileoff: i64  // 8 bytes: File offset
  seg_filesize: i64 // 8 bytes: Size in file on disk
  seg_maxprot: i64  // 4 bytes: Maximum VM protection
  seg_initprot: i64 // 4 bytes: Initial VM protection
  seg_nsects: i64   // 4 bytes: Number of sections following
  seg_flags: i64    // 4 bytes: Flags
@end

@struct MachOSection64
  sec_sectname: string // 16 bytes: Section name (e.g. "__text", "__cstring", "__data", "__bss")
  sec_segname: string  // 16 bytes: Segment name (e.g. "__TEXT", "__DATA")
  sec_addr: i64        // 8 bytes: Virtual address
  sec_size: i64        // 8 bytes: Byte size
  sec_offset: i64      // 4 bytes: File offset
  sec_align: i64       // 4 bytes: 2^align exponent (e.g. 4 for 16-byte alignment)
  sec_reloff: i64      // 4 bytes: File offset of relocations
  sec_nreloc: i64      // 4 bytes: Count of relocations
  sec_flags: i64       // 4 bytes: Section type and attributes
  sec_reserved1: i64   // 4 bytes: Reserved
  sec_reserved2: i64   // 4 bytes: Reserved
  sec_reserved3: i64   // 4 bytes: Reserved
@end

@struct MachOLcMain
  main_cmd: i64       // 4 bytes: LC_MAIN (0x80000028)
  main_cmdsize: i64   // 4 bytes: 24 bytes
  main_entryoff: i64  // 8 bytes: Entry point file offset relative to __TEXT
  main_stacksize: i64 // 8 bytes: Initial stack size (0 for default)
@end

// ============================================================================
// 2. INTEGER PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn macho_pack_u32_le(val)
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

@fn macho_pack_u64_le(val)
  v = val
  bytes = []
  i = 0
  @while i < 8
    b = v % 256
    @if b < 0
      b = b + 256
    @end
    bytes = bytes.push(b)
    v = (v - b) / 256
    i = i + 1
  @end
  return bytes
@end

@fn macho_pack_str16(name_str)
  // WHY: Encodes an ASCII string into exactly 16 bytes, padded with trailing zeros.
  bytes = []
  i = 0
  len_str = name_str.len()
  @while i < 16
    @if i < len_str
      bytes = bytes.push(str_char_at(name_str, i))
    @else
      bytes = bytes.push(0)
    @end
    i = i + 1
  @end
  return bytes
@end

// ============================================================================
// 3. FACTORY BUILDERS
// ============================================================================

@fn macho_header_create(cputype, ncmds, sizeofcmds)
  // WHY: Builds the standard 32-byte mach_header_64.
  subtype = CPU_SUBTYPE_X86_64_ALL()
  @if cputype == CPU_TYPE_ARM64()
    subtype = CPU_SUBTYPE_ARM64_ALL()
  @end

  flags = MH_NOUNDEFS() | MH_DYLDLINK() | MH_TWOLEVEL() | MH_PIE()

  return {
    mh_magic: MH_MAGIC_64(),
    mh_cputype: cputype,
    mh_cpusubtype: subtype,
    mh_filetype: MH_EXECUTE(),
    mh_ncmds: ncmds,
    mh_sizeofcmds: sizeofcmds,
    mh_flags: flags,
    mh_reserved: 0
  }
@end

@fn macho_segment_pagezero()
  // WHY: macOS 64-bit binaries mandate a 4GB __PAGEZERO segment starting at address 0.
  // Any dereference within [0..0xFFFFFFFF] triggers an immediate kernel MMU bus error/segfault,
  // preventing null pointer and low-memory privilege escalation exploits.
  return {
    seg_cmd: LC_SEGMENT_64(),
    seg_cmdsize: 72,
    seg_name: "__PAGEZERO",
    seg_vmaddr: 0,
    seg_vmsize: 4294967296, // 0x100000000 = 4GB
    seg_fileoff: 0,
    seg_filesize: 0,
    seg_maxprot: VM_PROT_NONE(),
    seg_initprot: VM_PROT_NONE(),
    seg_nsects: 0,
    seg_flags: 0
  }
@end

@fn macho_segment_text(vmsize, filesize, nsects)
  // WHY: __TEXT segment contains Mach-O headers, load commands, code, and string constants.
  // It is mapped at 0x100000000 (4GB base, right after __PAGEZERO).
  // initprot = RX (5), maxprot = RWX (7).
  return {
    seg_cmd: LC_SEGMENT_64(),
    seg_cmdsize: 72 + (80 * nsects),
    seg_name: "__TEXT",
    seg_vmaddr: 4294967296, // 0x100000000
    seg_vmsize: vmsize,
    seg_fileoff: 0,
    seg_filesize: filesize,
    seg_maxprot: VM_PROT_RWX(),
    seg_initprot: VM_PROT_RX(),
    seg_nsects: nsects,
    seg_flags: 0
  }
@end

@fn macho_section_text(addr, size, offset)
  // WHY: __text section inside __TEXT segment holds machine code instructions.
  // Flags mark it as containing pure instructions: S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS.
  flags = S_ATTR_PURE_INSTRUCTIONS() | S_ATTR_SOME_INSTRUCTIONS()
  return {
    sec_sectname: "__text",
    sec_segname: "__TEXT",
    sec_addr: addr,
    sec_size: size,
    sec_offset: offset,
    sec_align: 4, // 2^4 = 16-byte alignment
    sec_reloff: 0,
    sec_nreloc: 0,
    sec_flags: flags,
    sec_reserved1: 0,
    sec_reserved2: 0,
    sec_reserved3: 0
  }
@end

@fn macho_section_cstring(addr, size, offset)
  // WHY: __cstring section inside __TEXT holds literal C-string characters.
  return {
    sec_sectname: "__cstring",
    sec_segname: "__TEXT",
    sec_addr: addr,
    sec_size: size,
    sec_offset: offset,
    sec_align: 3, // 2^3 = 8-byte alignment
    sec_reloff: 0,
    sec_nreloc: 0,
    sec_flags: S_CSTRING_LITERALS(),
    sec_reserved1: 0,
    sec_reserved2: 0,
    sec_reserved3: 0
  }
@end

@fn macho_segment_data(vmaddr, vmsize, fileoff, filesize, nsects)
  // WHY: __DATA segment contains initialized globals and BSS.
  // initprot = RW (3), maxprot = RWX (7).
  return {
    seg_cmd: LC_SEGMENT_64(),
    seg_cmdsize: 72 + (80 * nsects),
    seg_name: "__DATA",
    seg_vmaddr: vmaddr,
    seg_vmsize: vmsize,
    seg_fileoff: fileoff,
    seg_filesize: filesize,
    seg_maxprot: VM_PROT_RWX(),
    seg_initprot: VM_PROT_RW(),
    seg_nsects: nsects,
    seg_flags: 0
  }
@end

@fn macho_section_data(addr, size, offset)
  // WHY: __data section inside __DATA segment.
  return {
    sec_sectname: "__data",
    sec_segname: "__DATA",
    sec_addr: addr,
    sec_size: size,
    sec_offset: offset,
    sec_align: 3,
    sec_reloff: 0,
    sec_nreloc: 0,
    sec_flags: S_REGULAR(),
    sec_reserved1: 0,
    sec_reserved2: 0,
    sec_reserved3: 0
  }
@end

@fn macho_section_bss(addr, size)
  // WHY: __bss section inside __DATA segment. S_ZEROFILL occupies 0 bytes on disk.
  return {
    sec_sectname: "__bss",
    sec_segname: "__DATA",
    sec_addr: addr,
    sec_size: size,
    sec_offset: 0,
    sec_align: 3,
    sec_reloff: 0,
    sec_nreloc: 0,
    sec_flags: S_ZEROFILL(),
    sec_reserved1: 0,
    sec_reserved2: 0,
    sec_reserved3: 0
  }
@end

@fn macho_lc_main_create(entry_offset, stack_size)
  // WHY: Modern LC_MAIN load command introduced in OS X 10.8 (Mountain Lion).
  // Replaced older thread-state registers LC_UNIXTHREAD with a clean 24-byte struct.
  return {
    main_cmd: LC_MAIN(),
    main_cmdsize: 24,
    main_entryoff: entry_offset,
    main_stacksize: stack_size
  }
@end

// ============================================================================
// 4. SERIALIZERS
// ============================================================================

@fn macho_append_bytes(out, src, count)
  // WHY: Appends count elements from src array into out without fragile single-line while loops
  i = 0
  @while i < count
    out = out.push(src[i])
    i = i + 1
  @end
  return out
@end

@fn macho_header_serialize(hdr)
  // WHY: Serializes mach_header_64 to exactly 32 bytes.
  out = []
  m_bytes = macho_pack_u32_le(hdr.mh_magic)
  ct_bytes = macho_pack_u32_le(hdr.mh_cputype)
  cs_bytes = macho_pack_u32_le(hdr.mh_cpusubtype)
  ft_bytes = macho_pack_u32_le(hdr.mh_filetype)
  nc_bytes = macho_pack_u32_le(hdr.mh_ncmds)
  sc_bytes = macho_pack_u32_le(hdr.mh_sizeofcmds)
  fl_bytes = macho_pack_u32_le(hdr.mh_flags)
  res_bytes = macho_pack_u32_le(hdr.mh_reserved)

  out = macho_append_bytes(out, m_bytes, 4)
  out = macho_append_bytes(out, ct_bytes, 4)
  out = macho_append_bytes(out, cs_bytes, 4)
  out = macho_append_bytes(out, ft_bytes, 4)
  out = macho_append_bytes(out, nc_bytes, 4)
  out = macho_append_bytes(out, sc_bytes, 4)
  out = macho_append_bytes(out, fl_bytes, 4)
  out = macho_append_bytes(out, res_bytes, 4)

  return out
@end

@fn macho_segment_header_serialize(seg)
  // WHY: Serializes the 72-byte base of LC_SEGMENT_64 (before any section_64 structs).
  out = []

  // 1. cmd (4 bytes)
  c_bytes = macho_pack_u32_le(seg.seg_cmd)
  out = macho_append_bytes(out, c_bytes, 4)

  // 2. cmdsize (4 bytes)
  cs_bytes = macho_pack_u32_le(seg.seg_cmdsize)
  out = macho_append_bytes(out, cs_bytes, 4)

  // 3. segname (16 bytes)
  s_bytes = macho_pack_str16(seg.seg_name)
  out = macho_append_bytes(out, s_bytes, 16)

  // 4. vmaddr (8 bytes)
  va_bytes = macho_pack_u64_le(seg.seg_vmaddr)
  out = macho_append_bytes(out, va_bytes, 8)

  // 5. vmsize (8 bytes)
  vs_bytes = macho_pack_u64_le(seg.seg_vmsize)
  out = macho_append_bytes(out, vs_bytes, 8)

  // 6. fileoff (8 bytes)
  fo_bytes = macho_pack_u64_le(seg.seg_fileoff)
  out = macho_append_bytes(out, fo_bytes, 8)

  // 7. filesize (8 bytes)
  fs_bytes = macho_pack_u64_le(seg.seg_filesize)
  out = macho_append_bytes(out, fs_bytes, 8)

  // 8. maxprot (4 bytes)
  mp_bytes = macho_pack_u32_le(seg.seg_maxprot)
  out = macho_append_bytes(out, mp_bytes, 4)

  // 9. initprot (4 bytes)
  ip_bytes = macho_pack_u32_le(seg.seg_initprot)
  out = macho_append_bytes(out, ip_bytes, 4)

  // 10. nsects (4 bytes)
  ns_bytes = macho_pack_u32_le(seg.seg_nsects)
  out = macho_append_bytes(out, ns_bytes, 4)

  // 11. flags (4 bytes)
  fl_bytes = macho_pack_u32_le(seg.seg_flags)
  out = macho_append_bytes(out, fl_bytes, 4)

  return out
@end

@fn macho_section_serialize(sec)
  // WHY: Serializes a single section_64 struct to exactly 80 bytes.
  out = []

  // 1. sectname (16 bytes)
  sn_bytes = macho_pack_str16(sec.sec_sectname)
  out = macho_append_bytes(out, sn_bytes, 16)

  // 2. segname (16 bytes)
  sgn_bytes = macho_pack_str16(sec.sec_segname)
  out = macho_append_bytes(out, sgn_bytes, 16)

  // 3. addr (8 bytes)
  a_bytes = macho_pack_u64_le(sec.sec_addr)
  out = macho_append_bytes(out, a_bytes, 8)

  // 4. size (8 bytes)
  sz_bytes = macho_pack_u64_le(sec.sec_size)
  out = macho_append_bytes(out, sz_bytes, 8)

  // 5. offset (4 bytes)
  off_bytes = macho_pack_u32_le(sec.sec_offset)
  out = macho_append_bytes(out, off_bytes, 4)

  // 6. align (4 bytes)
  al_bytes = macho_pack_u32_le(sec.sec_align)
  out = macho_append_bytes(out, al_bytes, 4)

  // 7. reloff (4 bytes)
  ro_bytes = macho_pack_u32_le(sec.sec_reloff)
  out = macho_append_bytes(out, ro_bytes, 4)

  // 8. nreloc (4 bytes)
  nr_bytes = macho_pack_u32_le(sec.sec_nreloc)
  out = macho_append_bytes(out, nr_bytes, 4)

  // 9. flags (4 bytes)
  fl_bytes = macho_pack_u32_le(sec.sec_flags)
  out = macho_append_bytes(out, fl_bytes, 4)

  // 10. reserved1 (4 bytes)
  r1_bytes = macho_pack_u32_le(sec.sec_reserved1)
  out = macho_append_bytes(out, r1_bytes, 4)

  // 11. reserved2 (4 bytes)
  r2_bytes = macho_pack_u32_le(sec.sec_reserved2)
  out = macho_append_bytes(out, r2_bytes, 4)

  // 12. reserved3 (4 bytes)
  r3_bytes = macho_pack_u32_le(sec.sec_reserved3)
  out = macho_append_bytes(out, r3_bytes, 4)

  return out
@end

@fn macho_lc_main_serialize(main_cmd)
  // WHY: Serializes LC_MAIN load command to exactly 24 bytes:
  // Offset 0x00: cmd       (4 bytes: 0x80000028)
  // Offset 0x04: cmdsize   (4 bytes: 24)
  // Offset 0x08: entryoff  (8 bytes: offset of main code from __TEXT vmaddr)
  // Offset 0x10: stacksize (8 bytes: stack size or 0)
  out = []

  c_bytes = macho_pack_u32_le(main_cmd.main_cmd)
  out = macho_append_bytes(out, c_bytes, 4)

  cs_bytes = macho_pack_u32_le(main_cmd.main_cmdsize)
  out = macho_append_bytes(out, cs_bytes, 4)

  eo_bytes = macho_pack_u64_le(main_cmd.main_entryoff)
  out = macho_append_bytes(out, eo_bytes, 8)

  ss_bytes = macho_pack_u64_le(main_cmd.main_stacksize)
  out = macho_append_bytes(out, ss_bytes, 8)

  return out
@end
