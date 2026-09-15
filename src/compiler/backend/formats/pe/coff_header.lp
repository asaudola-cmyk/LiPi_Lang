// ============================================================================
// LIPI SOVEREIGN COMPILER — WINDOWS COFF HEADER & SECTION TABLE SERIALIZER
// Module: src/compiler/backend/formats/pe/coff_header.lp
// Standard: Microsoft PE/COFF Specification (PE32+ / 64-bit Windows)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "universe/core/string"

// WHY: The COFF (Common Object File Format) header and PE32+ Optional Header
// define the target CPU architecture, execution entry point RVA (Relative Virtual Address),
// virtual memory layout, section alignments, and data directories.
// Following the Optional Header is the Section Table: an array of 40-byte
// IMAGE_SECTION_HEADER entries describing memory sections (.text, .rdata, .data, .bss).

// --- Machine Architecture Identifiers ---
@fn IMAGE_FILE_MACHINE_AMD64() return 34404 @end // 0x8664: x86-64 / AMD64
@fn IMAGE_FILE_MACHINE_ARM64() return 43620 @end // 0xAA64: ARM64 Little Endian

// --- COFF Characteristics ---
@fn IMAGE_FILE_RELOCS_STRIPPED()         return 1     @end // 0x0001
@fn IMAGE_FILE_EXECUTABLE_IMAGE()        return 2     @end // 0x0002: File is executable
@fn IMAGE_FILE_LINE_NUMS_STRIPPED()      return 4     @end // 0x0004
@fn IMAGE_FILE_LOCAL_SYMS_STRIPPED()     return 8     @end // 0x0008
@fn IMAGE_FILE_LARGE_ADDRESS_AWARE()     return 32    @end // 0x0020: Application can handle >2GB addresses
@fn IMAGE_FILE_DLL()                     return 8192  @end // 0x2000: File is a dynamic-link library (.dll)

// --- Optional Header Magic ---
@fn PE32_MAGIC()     return 267 @end // 0x010B: 32-bit executable
@fn PE32PLUS_MAGIC() return 523 @end // 0x020B: 64-bit executable (PE32+)

// --- Windows Subsystem ---
@fn IMAGE_SUBSYSTEM_WINDOWS_GUI() return 2 @end // Windows graphical user interface (GUI)
@fn IMAGE_SUBSYSTEM_WINDOWS_CUI() return 3 @end // Windows character user interface (Console)
@fn IMAGE_SUBSYSTEM_EFI_APPLICATION() return 10 @end // UEFI application

// --- DLL Characteristics (Security Mitigations) ---
@fn IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE()          return 64    @end // 0x0040: ASLR enabled
@fn IMAGE_DLLCHARACTERISTICS_NX_COMPAT()             return 256   @end // 0x0100: DEP / Data Execution Prevention
@fn IMAGE_DLLCHARACTERISTICS_NO_SEH()                return 1024  @end // 0x0400: Image does not use SEH
@fn IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE() return 32768 @end // 0x8000: Terminal Server aware

// --- Section Characteristics Flags ---
@fn IMAGE_SCN_CNT_CODE()               return 32         @end // 0x00000020: Contains executable code
@fn IMAGE_SCN_CNT_INITIALIZED_DATA()   return 64         @end // 0x00000040: Contains initialized data
@fn IMAGE_SCN_CNT_UNINITIALIZED_DATA() return 128        @end // 0x00000080: Contains uninitialized data (.bss)
@fn IMAGE_SCN_MEM_DISCARDABLE()        return 33554432   @end // 0x02000000: Discardable as needed
@fn IMAGE_SCN_MEM_EXECUTE()            return 536870912  @end // 0x20000000: Executable
@fn IMAGE_SCN_MEM_READ()               return 1073741824 @end // 0x40000000: Readable
@fn IMAGE_SCN_MEM_WRITE()              return 2147483648 @end // 0x80000000: Writable

// Standard section characteristics:
@fn PE_FLAGS_TEXT()  return 1610612768 @end // CNT_CODE | MEM_EXECUTE | MEM_READ (0x60000020)
@fn PE_FLAGS_RDATA() return 1073741888 @end // CNT_INITIALIZED_DATA | MEM_READ (0x40000040)
@fn PE_FLAGS_DATA()  return 3221225536 @end // CNT_INITIALIZED_DATA | MEM_READ | MEM_WRITE (0xC0000040)
@fn PE_FLAGS_BSS()   return 3221225600 @end // CNT_UNINITIALIZED_DATA | MEM_READ | MEM_WRITE (0xC0000080)

@fn COFF_HEADER_SIZE()        return 20  @end // 20 bytes
@fn PE_OPT_HEADER64_SIZE()    return 240 @end // 240 bytes
@fn PE_SECTION_HEADER_SIZE()  return 40  @end // 40 bytes

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct ImageFileHeader
  machine: i64               // 2 bytes: Target machine architecture (IMAGE_FILE_MACHINE_AMD64)
  num_sections: i64          // 2 bytes: Count of sections in Section Table
  time_date_stamp: i64       // 4 bytes: Low 32 bits of UTC timestamp
  pointer_to_symbol_table: i64 // 4 bytes: File offset of COFF symbol table (0 for stripped)
  num_symbols: i64           // 4 bytes: Number of symbols in table (0 for stripped)
  size_of_optional_header: i64 // 2 bytes: Size of optional header (240 for PE32+)
  characteristics: i64       // 2 bytes: Flags (IMAGE_FILE_EXECUTABLE_IMAGE | IMAGE_FILE_LARGE_ADDRESS_AWARE)
@end

@struct ImageOptionalHeader64
  magic: i64                       // 2 bytes: 0x020B (PE32+)
  major_linker_version: i64        // 1 byte: 1
  minor_linker_version: i64        // 1 byte: 0
  size_of_code: i64                // 4 bytes: Size of executable code (.text)
  size_of_initialized_data: i64    // 4 bytes: Size of initialized data (.rdata + .data)
  size_of_uninitialized_data: i64  // 4 bytes: Size of uninitialized data (.bss)
  address_of_entry_point: i64      // 4 bytes: RVA of entry point
  base_of_code: i64                // 4 bytes: RVA of code section (.text)
  image_base: i64                  // 8 bytes: Preferred image base address (0x140000000)
  section_alignment: i64           // 4 bytes: Section alignment in memory (4096 = 0x1000)
  file_alignment: i64              // 4 bytes: Section alignment on disk (512 = 0x200)
  major_os_version: i64            // 2 bytes: Minimum OS version (6 = Vista / Windows 7+)
  minor_os_version: i64            // 2 bytes: 0
  major_subsystem_version: i64     // 2 bytes: 6
  minor_subsystem_version: i64     // 2 bytes: 0
  size_of_image: i64               // 4 bytes: Total virtual size of image aligned to section_alignment
  size_of_headers: i64             // 4 bytes: Size of all headers aligned to file_alignment
  checksum: i64                    // 4 bytes: Checksum (0 for non-driver binaries)
  subsystem: i64                   // 2 bytes: Console (3) or GUI (2)
  dll_characteristics: i64         // 2 bytes: ASLR | DEP | TerminalServer (0x8140)
  size_of_stack_reserve: i64       // 8 bytes: Stack reserve size (1MB = 1048576)
  size_of_stack_commit: i64        // 8 bytes: Stack commit size (4KB = 4096)
  size_of_heap_reserve: i64        // 8 bytes: Heap reserve size (1MB = 1048576)
  size_of_heap_commit: i64         // 8 bytes: Heap commit size (4KB = 4096)
@end

@struct ImageSectionHeader
  name: string                 // 8 bytes: Section name ASCII (".text\0\0\0")
  virtual_size: i64            // 4 bytes: Total size of section when loaded in memory
  virtual_address: i64         // 4 bytes: Relative Virtual Address (RVA) in memory
  size_of_raw_data: i64        // 4 bytes: Size of section data in disk file (multiple of file_align)
  pointer_to_raw_data: i64     // 4 bytes: File pointer to section's first page on disk
  pointer_to_relocations: i64  // 4 bytes: 0
  pointer_to_linenumbers: i64  // 4 bytes: 0
  num_relocations: i64         // 2 bytes: 0
  num_linenumbers: i64         // 2 bytes: 0
  characteristics: i64         // 4 bytes: PE_FLAGS_TEXT, PE_FLAGS_DATA, etc.
@end

// ============================================================================
// 2. INTEGER & STRING PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn pe_pack_u16(val)
  v = val
  @if v < 0 v = v + 65536 @end
  return [v % 256, (v / 256) % 256]
@end

@fn pe_pack_u32(val)
  v = val
  @if v < 0 v = v + 4294967296 @end
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn pe_pack_u64(val)
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

@fn pe_pack_name8(name_str)
  // WHY: Encodes an ASCII section name into strictly 8 bytes, padded with trailing zeroes.
  bytes = []
  i = 0
  n = name_str.len()
  @while i < 8
    @if i < n
      bytes = bytes.push(str_char_at(name_str, i))
    @else
      bytes = bytes.push(0)
    @end
    i = i + 1
  @end
  return bytes
@end

@fn pe_align_to(val, alignment)
  // WHY: Aligns val up to the nearest multiple of alignment.
  @if alignment <= 0 return val @end
  rem = val % alignment
  @if rem == 0 return val @end
  return val + (alignment - rem)
@end

// ============================================================================
// 3. FACTORY BUILDERS
// ============================================================================

@fn pe_coff_header_create(machine, num_sections)
  // WHY: Constructs the 20-byte COFF file header.
  // Characteristics 0x0022 = IMAGE_FILE_EXECUTABLE_IMAGE | IMAGE_FILE_LARGE_ADDRESS_AWARE
  return {
    machine: machine,
    num_sections: num_sections,
    time_date_stamp: 1718000000, // Fixed canonical timestamp
    pointer_to_symbol_table: 0,
    num_symbols: 0,
    size_of_optional_header: PE_OPT_HEADER64_SIZE(), // 240 bytes
    characteristics: IMAGE_FILE_EXECUTABLE_IMAGE() | IMAGE_FILE_LARGE_ADDRESS_AWARE()
  }
@end

@fn pe_optional_header64_create(entry_rva, code_base_rva, code_sz, data_sz, bss_sz, img_sz, hdr_sz, is_gui)
  // WHY: Constructs the 240-byte PE32+ Optional Header.
  subsystem = IMAGE_SUBSYSTEM_WINDOWS_CUI()
  @if is_gui == 1
    subsystem = IMAGE_SUBSYSTEM_WINDOWS_GUI()
  @end

  dll_chars = IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE() | IMAGE_DLLCHARACTERISTICS_NX_COMPAT() | IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE()

  return {
    magic: PE32PLUS_MAGIC(), // 0x020B (64-bit)
    major_linker_version: 1,
    minor_linker_version: 0,
    size_of_code: code_sz,
    size_of_initialized_data: data_sz,
    size_of_uninitialized_data: bss_sz,
    address_of_entry_point: entry_rva,
    base_of_code: code_base_rva,
    image_base: 5368709120, // 0x140000000: Windows standard 64-bit default image base
    section_alignment: 4096, // 0x1000 (4KB page)
    file_alignment: 512,    // 0x200 (512-byte sector)
    major_os_version: 6,
    minor_os_version: 0,
    major_subsystem_version: 6,
    minor_subsystem_version: 0,
    size_of_image: img_sz,
    size_of_headers: hdr_sz,
    checksum: 0,
    subsystem: subsystem,
    dll_characteristics: dll_chars,
    size_of_stack_reserve: 1048576, // 1MB
    size_of_stack_commit: 4096,     // 4KB
    size_of_heap_reserve: 1048576,  // 1MB
    size_of_heap_commit: 4096       // 4KB
  }
@end

@fn pe_section_text_create(vsize, rva, raw_size, raw_ptr)
  return {
    name: ".text",
    virtual_size: vsize,
    virtual_address: rva,
    size_of_raw_data: raw_size,
    pointer_to_raw_data: raw_ptr,
    pointer_to_relocations: 0,
    pointer_to_linenumbers: 0,
    num_relocations: 0,
    num_linenumbers: 0,
    characteristics: PE_FLAGS_TEXT()
  }
@end

@fn pe_section_rdata_create(vsize, rva, raw_size, raw_ptr)
  return {
    name: ".rdata",
    virtual_size: vsize,
    virtual_address: rva,
    size_of_raw_data: raw_size,
    pointer_to_raw_data: raw_ptr,
    pointer_to_relocations: 0,
    pointer_to_linenumbers: 0,
    num_relocations: 0,
    num_linenumbers: 0,
    characteristics: PE_FLAGS_RDATA()
  }
@end

@fn pe_section_data_create(vsize, rva, raw_size, raw_ptr)
  return {
    name: ".data",
    virtual_size: vsize,
    virtual_address: rva,
    size_of_raw_data: raw_size,
    pointer_to_raw_data: raw_ptr,
    pointer_to_relocations: 0,
    pointer_to_linenumbers: 0,
    num_relocations: 0,
    num_linenumbers: 0,
    characteristics: PE_FLAGS_DATA()
  }
@end

// ============================================================================
// 4. SERIALIZATION
// ============================================================================

@fn pe_coff_header_serialize(chdr)
  // WHY: Serializes IMAGE_FILE_HEADER to exactly 20 bytes.
  out = []

  m = pe_pack_u16(chdr.machine)
  out = out.push(m[0]) out = out.push(m[1])

  ns = pe_pack_u16(chdr.num_sections)
  out = out.push(ns[0]) out = out.push(ns[1])

  ts = pe_pack_u32(chdr.time_date_stamp)
  out = out.push(ts[0]) out = out.push(ts[1]) out = out.push(ts[2]) out = out.push(ts[3])

  ps = pe_pack_u32(chdr.pointer_to_symbol_table)
  out = out.push(ps[0]) out = out.push(ps[1]) out = out.push(ps[2]) out = out.push(ps[3])

  sym = pe_pack_u32(chdr.num_symbols)
  out = out.push(sym[0]) out = out.push(sym[1]) out = out.push(sym[2]) out = out.push(sym[3])

  soh = pe_pack_u16(chdr.size_of_optional_header)
  out = out.push(soh[0]) out = out.push(soh[1])

  c = pe_pack_u16(chdr.characteristics)
  out = out.push(c[0]) out = out.push(c[1])

  return out
@end

@fn pe_optional_header64_serialize(opthdr)
  // WHY: Serializes IMAGE_OPTIONAL_HEADER64 to exactly 240 bytes.
  // Base header: 112 bytes
  // Data directories: 16 entries * 8 bytes = 128 bytes
  // Total: 240 bytes exactly.
  out = []

  // 1. Standard Fields (24 bytes)
  mg = pe_pack_u16(opthdr.magic)
  out = out.push(mg[0]) out = out.push(mg[1])
  out = out.push(opthdr.major_linker_version % 256)
  out = out.push(opthdr.minor_linker_version % 256)

  sc = pe_pack_u32(opthdr.size_of_code)
  out = out.push(sc[0]) out = out.push(sc[1]) out = out.push(sc[2]) out = out.push(sc[3])

  sid = pe_pack_u32(opthdr.size_of_initialized_data)
  out = out.push(sid[0]) out = out.push(sid[1]) out = out.push(sid[2]) out = out.push(sid[3])

  sud = pe_pack_u32(opthdr.size_of_uninitialized_data)
  out = out.push(sud[0]) out = out.push(sud[1]) out = out.push(sud[2]) out = out.push(sud[3])

  ep = pe_pack_u32(opthdr.address_of_entry_point)
  out = out.push(ep[0]) out = out.push(ep[1]) out = out.push(ep[2]) out = out.push(ep[3])

  bc = pe_pack_u32(opthdr.base_of_code)
  out = out.push(bc[0]) out = out.push(bc[1]) out = out.push(bc[2]) out = out.push(bc[3])

  // 2. Windows-Specific Fields (88 bytes)
  ib = pe_pack_u64(opthdr.image_base)
  k = 0 @while k < 8 out = out.push(ib[k]) k = k + 1 @end

  sa = pe_pack_u32(opthdr.section_alignment)
  out = out.push(sa[0]) out = out.push(sa[1]) out = out.push(sa[2]) out = out.push(sa[3])

  fa = pe_pack_u32(opthdr.file_alignment)
  out = out.push(fa[0]) out = out.push(fa[1]) out = out.push(fa[2]) out = out.push(fa[3])

  mos = pe_pack_u16(opthdr.major_os_version)
  out = out.push(mos[0]) out = out.push(mos[1])

  minos = pe_pack_u16(opthdr.minor_os_version)
  out = out.push(minos[0]) out = out.push(minos[1])

  mimg = pe_pack_u16(1) // MajorImageVersion
  out = out.push(mimg[0]) out = out.push(mimg[1])

  minimg = pe_pack_u16(0) // MinorImageVersion
  out = out.push(minimg[0]) out = out.push(minimg[1])

  msub = pe_pack_u16(opthdr.major_subsystem_version)
  out = out.push(msub[0]) out = out.push(msub[1])

  minsub = pe_pack_u16(opthdr.minor_subsystem_version)
  out = out.push(minsub[0]) out = out.push(minsub[1])

  // Win32VersionValue (4 bytes zero)
  k = 0 @while k < 4 out = out.push(0) k = k + 1 @end

  si = pe_pack_u32(opthdr.size_of_image)
  out = out.push(si[0]) out = out.push(si[1]) out = out.push(si[2]) out = out.push(si[3])

  sh = pe_pack_u32(opthdr.size_of_headers)
  out = out.push(sh[0]) out = out.push(sh[1]) out = out.push(sh[2]) out = out.push(sh[3])

  cs = pe_pack_u32(opthdr.checksum)
  out = out.push(cs[0]) out = out.push(cs[1]) out = out.push(cs[2]) out = out.push(cs[3])

  sub = pe_pack_u16(opthdr.subsystem)
  out = out.push(sub[0]) out = out.push(sub[1])

  dll = pe_pack_u16(opthdr.dll_characteristics)
  out = out.push(dll[0]) out = out.push(dll[1])

  ssr = pe_pack_u64(opthdr.size_of_stack_reserve)
  k = 0 @while k < 8 out = out.push(ssr[k]) k = k + 1 @end

  ssc = pe_pack_u64(opthdr.size_of_stack_commit)
  k = 0 @while k < 8 out = out.push(ssc[k]) k = k + 1 @end

  shr = pe_pack_u64(opthdr.size_of_heap_reserve)
  k = 0 @while k < 8 out = out.push(shr[k]) k = k + 1 @end

  shc = pe_pack_u64(opthdr.size_of_heap_commit)
  k = 0 @while k < 8 out = out.push(shc[k]) k = k + 1 @end

  // LoaderFlags (4 bytes zero)
  k = 0 @while k < 4 out = out.push(0) k = k + 1 @end

  // NumberOfRvaAndSizes (4 bytes: 16)
  nrv = pe_pack_u32(16)
  out = out.push(nrv[0]) out = out.push(nrv[1]) out = out.push(nrv[2]) out = out.push(nrv[3])

  // 3. 16 Data Directories (16 * 8 = 128 bytes of zero for freestanding binary)
  k = 0
  @while k < 128
    out = out.push(0)
    k = k + 1
  @end

  return out
@end

@fn pe_section_header_serialize(sec)
  // WHY: Serializes IMAGE_SECTION_HEADER to exactly 40 bytes.
  // 0x00: Name (8 bytes)
  // 0x08: VirtualSize (4 bytes)
  // 0x0C: VirtualAddress (4 bytes)
  // 0x10: SizeOfRawData (4 bytes)
  // 0x14: PointerToRawData (4 bytes)
  // 0x18: PointerToRelocations (4 bytes)
  // 0x1C: PointerToLinenumbers (4 bytes)
  // 0x20: NumberOfRelocations (2 bytes)
  // 0x22: NumberOfLinenumbers (2 bytes)
  // 0x24: Characteristics (4 bytes)
  out = []

  // 1. Name (8 bytes)
  nb = pe_pack_name8(sec.name)
  k = 0 @while k < 8 out = out.push(nb[k]) k = k + 1 @end

  // 2. VirtualSize (4 bytes)
  vs = pe_pack_u32(sec.virtual_size)
  out = out.push(vs[0]) out = out.push(vs[1]) out = out.push(vs[2]) out = out.push(vs[3])

  // 3. VirtualAddress (4 bytes)
  va = pe_pack_u32(sec.virtual_address)
  out = out.push(va[0]) out = out.push(va[1]) out = out.push(va[2]) out = out.push(va[3])

  // 4. SizeOfRawData (4 bytes)
  sr = pe_pack_u32(sec.size_of_raw_data)
  out = out.push(sr[0]) out = out.push(sr[1]) out = out.push(sr[2]) out = out.push(sr[3])

  // 5. PointerToRawData (4 bytes)
  pr = pe_pack_u32(sec.pointer_to_raw_data)
  out = out.push(pr[0]) out = out.push(pr[1]) out = out.push(pr[2]) out = out.push(pr[3])

  // 6. PointerToRelocations (4 bytes zero)
  k = 0 @while k < 4 out = out.push(0) k = k + 1 @end

  // 7. PointerToLinenumbers (4 bytes zero)
  k = 0 @while k < 4 out = out.push(0) k = k + 1 @end

  // 8. NumberOfRelocations (2 bytes zero)
  out = out.push(0) out = out.push(0)

  // 9. NumberOfLinenumbers (2 bytes zero)
  out = out.push(0) out = out.push(0)

  // 10. Characteristics (4 bytes)
  ch = pe_pack_u32(sec.characteristics)
  out = out.push(ch[0]) out = out.push(ch[1]) out = out.push(ch[2]) out = out.push(ch[3])

  return out
@end
