// ============================================================================
// LIPI SOVEREIGN COMPILER — ELF64 SECTION HEADER GENERATOR
// Module: src/compiler/backend/formats/elf/section_header.lp
// Standard: System V AMD64 ABI / Linux ELF64 Section Header (Shdr) Table
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: Section headers provide the linker, debugger (GDB/LLDB/lipidbg), and
// symbol resolution tools with a structured view of the binary.
// While the OS kernel loader uses Program Headers (Phdrs) to load segments into memory,
// linkers and debuggers rely on Section Headers (Shdrs) to inspect functions (.text),
// constants (.rodata), mutable data (.data), zero-initialized bss (.bss),
// symbols (.symtab), and string tables (.strtab, .shstrtab).
// Each Elf64_Shdr entry is strictly 64 bytes in size.

import "universe/core/string"

// --- Section Header Types (sh_type) ---
// WHY: Defines the semantic categorization of the section's contents.
@fn SHT_NULL()          return 0  @end // Inactive section header (index 0 is always SHT_NULL)
@fn SHT_PROGBITS()      return 1  @end // Program-defined data (machine code, rodata, initialized data)
@fn SHT_SYMTAB()        return 2  @end // Static symbol table for linking / debugging
@fn SHT_STRTAB()        return 3  @end // String table (.strtab, .shstrtab) containing null-terminated names
@fn SHT_RELA()          return 4  @end // Relocation entries with explicit addends (standard on x86_64 and AArch64)
@fn SHT_HASH()          return 5  @end // Symbol hash table
@fn SHT_DYNAMIC()       return 6  @end // Dynamic linking information
@fn SHT_NOTE()          return 7  @end // Vendor/system information notes
@fn SHT_NOBITS()        return 8  @end // BSS: occupies no space on disk in file, but allocates memory at runtime
@fn SHT_REL()           return 9  @end // Relocation entries without explicit addends
@fn SHT_SHLIB()         return 10 @end // Reserved
@fn SHT_DYNSYM()        return 11 @end // Dynamic linker minimal symbol table

// --- Section Header Flags (sh_flags) ---
// WHY: Informs memory management and toolchains how the section should be treated.
@fn SHF_WRITE()            return 1  @end // 0x1: Section contains data that should be writable during execution
@fn SHF_ALLOC()            return 2  @end // 0x2: Section occupies memory during process execution
@fn SHF_EXECINSTR()        return 4  @end // 0x4: Section contains executable machine instructions
@fn SHF_MERGE()            return 16 @end // 0x10: Section contains data that may be merged to eliminate duplication
@fn SHF_STRINGS()          return 32 @end // 0x20: Section contains null-terminated character strings
@fn SHF_INFO_LINK()        return 64 @end // 0x40: sh_info field contains a valid section header table index

// Standard combined flags:
@fn SHF_FLAGS_TEXT()   return 6 @end // SHF_ALLOC | SHF_EXECINSTR (Code: 2 | 4 = 6)
@fn SHF_FLAGS_RODATA() return 2 @end // SHF_ALLOC (Read-only data: 2)
@fn SHF_FLAGS_DATA()   return 3 @end // SHF_ALLOC | SHF_WRITE (Mutable data: 2 | 1 = 3)
@fn SHF_FLAGS_BSS()    return 3 @end // SHF_ALLOC | SHF_WRITE (Uninitialized data: 2 | 1 = 3)

@fn ELF64_SHDR_BYTES() return 64 @end

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct Elf64SectionHeader
  sh_name: i64      // 4 bytes: Section name (string index in .shstrtab)
  sh_type: i64      // 4 bytes: SHT_PROGBITS, SHT_SYMTAB, etc.
  sh_flags: i64     // 8 bytes: SHF_ALLOC, SHF_EXECINSTR, SHF_WRITE bitmask
  sh_addr: i64      // 8 bytes: Virtual memory address where section resides (0 if not loaded)
  sh_offset: i64    // 8 bytes: File offset of the section on disk
  sh_size: i64      // 8 bytes: Byte size of the section
  sh_link: i64      // 4 bytes: Section header index link (e.g. symtab -> strtab)
  sh_info: i64      // 4 bytes: Additional section info (e.g. first global symbol index in symtab)
  sh_addralign: i64 // 8 bytes: Address alignment requirement (power of 2, e.g. 1, 8, 16)
  sh_entsize: i64   // 8 bytes: Entry size if section holds fixed-size entries (24 for Sym/Rela)
@end

@struct ElfStrtabBuilder
  data: array       // Array of raw ASCII bytes for string table
  size: i64         // Current total length of string table
@end

// ============================================================================
// 2. INTEGER PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn shdr_pack_u32_le(val)
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

@fn shdr_pack_u64_le(val)
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

// ============================================================================
// 3. STRING TABLE BUILDER (.shstrtab / .strtab)
// ============================================================================

@fn elf_strtab_new()
  // WHY: ELF specification mandates that offset 0 in any string table must be a null byte (0x00).
  // An index of 0 indicates an empty string or no name.
  return {
    data: [0],
    size: 1
  }
@end

@fn elf_strtab_add(builder, name_str)
  // WHY: Appends a string followed by a null terminator (0) into the string table.
  // Returns the byte offset of the string within the table for use in sh_name or st_name.
  offset = builder.size
  len_str = name_str.len()
  i = 0
  @while i < len_str
    builder.data = builder.data.push(str_char_at(name_str, i))
    i = i + 1
  @end
  // Append mandatory terminating null byte
  builder.data = builder.data.push(0)
  builder.size = builder.size + len_str + 1
  return offset
@end

@fn elf_strtab_get_bytes(builder)
  return builder.data
@end

@fn elf_strtab_get_size(builder)
  return builder.size
@end

// ============================================================================
// 4. CANONICAL SECTION FACTORY CONSTRUCTORS
// ============================================================================

@fn elf_sh_null()
  // WHY: The ELF specification strictly reserves section index 0 (SHN_UNDEF).
  // All fields must be exactly zero.
  return {
    sh_name: 0,
    sh_type: SHT_NULL(),
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: 0,
    sh_size: 0,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 0,
    sh_entsize: 0
  }
@end

@fn elf_sh_text(name_offset, vaddr, file_offset, byte_size)
  // WHY: .text section contains executable machine code instructions.
  // Requires SHF_ALLOC | SHF_EXECINSTR and 16-byte CPU instruction cache alignment.
  return {
    sh_name: name_offset,
    sh_type: SHT_PROGBITS(),
    sh_flags: SHF_FLAGS_TEXT(),
    sh_addr: vaddr,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 16,
    sh_entsize: 0
  }
@end

@fn elf_sh_rodata(name_offset, vaddr, file_offset, byte_size)
  // WHY: .rodata contains immutable constant strings and jump tables.
  // Requires SHF_ALLOC, but NOT SHF_WRITE or SHF_EXECINSTR. Aligned to 8 bytes.
  return {
    sh_name: name_offset,
    sh_type: SHT_PROGBITS(),
    sh_flags: SHF_FLAGS_RODATA(),
    sh_addr: vaddr,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 8,
    sh_entsize: 0
  }
@end

@fn elf_sh_data(name_offset, vaddr, file_offset, byte_size)
  // WHY: .data contains pre-initialized mutable global and static variables.
  // Requires SHF_ALLOC | SHF_WRITE. Aligned to 8 bytes.
  return {
    sh_name: name_offset,
    sh_type: SHT_PROGBITS(),
    sh_flags: SHF_FLAGS_DATA(),
    sh_addr: vaddr,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 8,
    sh_entsize: 0
  }
@end

@fn elf_sh_bss(name_offset, vaddr, file_offset, byte_size)
  // WHY: .bss contains uninitialized global variables that are zeroed by kernel at load time.
  // SHT_NOBITS ensures it takes 0 bytes in the disk file, but allocates memory in RAM.
  return {
    sh_name: name_offset,
    sh_type: SHT_NOBITS(),
    sh_flags: SHF_FLAGS_BSS(),
    sh_addr: vaddr,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 8,
    sh_entsize: 0
  }
@end

@fn elf_sh_symtab(name_offset, file_offset, byte_size, strtab_idx, num_local_symbols)
  // WHY: .symtab holds Elf64_Sym symbol descriptors for debugging and static linking.
  // sh_link points to the associated .strtab string table section index.
  // sh_info specifies the symbol table index of the first global (non-local) symbol.
  // sh_entsize is 24 bytes (exact size of Elf64_Sym).
  return {
    sh_name: name_offset,
    sh_type: SHT_SYMTAB(),
    sh_flags: 0, // Not loaded into process memory space in stripped/final binaries
    sh_addr: 0,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: strtab_idx,
    sh_info: num_local_symbols,
    sh_addralign: 8,
    sh_entsize: 24
  }
@end

@fn elf_sh_strtab(name_offset, file_offset, byte_size)
  // WHY: .strtab holds symbol names referenced by .symtab.
  return {
    sh_name: name_offset,
    sh_type: SHT_STRTAB(),
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 1,
    sh_entsize: 0
  }
@end

@fn elf_sh_shstrtab(name_offset, file_offset, byte_size)
  // WHY: .shstrtab holds section names (.text, .rodata, etc.) referenced by sh_name.
  return {
    sh_name: name_offset,
    sh_type: SHT_STRTAB(),
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: file_offset,
    sh_size: byte_size,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 1,
    sh_entsize: 0
  }
@end

// ============================================================================
// 5. SERIALIZATION (64 Bytes per Shdr)
// ============================================================================

@fn elf_section_header_serialize(shdr)
  // WHY: Serializes a single Elf64_Shdr struct to exactly 64 bytes.
  // System V AMD64 ABI layout:
  // Offset 0x00: sh_name      (Elf64_Word,  4 bytes)
  // Offset 0x04: sh_type      (Elf64_Word,  4 bytes)
  // Offset 0x08: sh_flags     (Elf64_Xword, 8 bytes)
  // Offset 0x10: sh_addr      (Elf64_Addr,  8 bytes)
  // Offset 0x18: sh_offset    (Elf64_Off,   8 bytes)
  // Offset 0x20: sh_size      (Elf64_Xword, 8 bytes)
  // Offset 0x28: sh_link      (Elf64_Word,  4 bytes)
  // Offset 0x2C: sh_info      (Elf64_Word,  4 bytes)
  // Offset 0x30: sh_addralign (Elf64_Xword, 8 bytes)
  // Offset 0x38: sh_entsize   (Elf64_Xword, 8 bytes)
  // Total: 64 bytes exactly.
  out = []

  // 1. sh_name (4 bytes)
  n_bytes = shdr_pack_u32_le(shdr.sh_name)
  out = out.push(n_bytes[0])
  out = out.push(n_bytes[1])
  out = out.push(n_bytes[2])
  out = out.push(n_bytes[3])

  // 2. sh_type (4 bytes)
  t_bytes = shdr_pack_u32_le(shdr.sh_type)
  out = out.push(t_bytes[0])
  out = out.push(t_bytes[1])
  out = out.push(t_bytes[2])
  out = out.push(t_bytes[3])

  // 3. sh_flags (8 bytes)
  f_bytes = shdr_pack_u64_le(shdr.sh_flags)
  i = 0
  @while i < 8
    out = out.push(f_bytes[i])
    i = i + 1
  @end

  // 4. sh_addr (8 bytes)
  a_bytes = shdr_pack_u64_le(shdr.sh_addr)
  i = 0
  @while i < 8
    out = out.push(a_bytes[i])
    i = i + 1
  @end

  // 5. sh_offset (8 bytes)
  o_bytes = shdr_pack_u64_le(shdr.sh_offset)
  i = 0
  @while i < 8
    out = out.push(o_bytes[i])
    i = i + 1
  @end

  // 6. sh_size (8 bytes)
  s_bytes = shdr_pack_u64_le(shdr.sh_size)
  i = 0
  @while i < 8
    out = out.push(s_bytes[i])
    i = i + 1
  @end

  // 7. sh_link (4 bytes)
  l_bytes = shdr_pack_u32_le(shdr.sh_link)
  out = out.push(l_bytes[0])
  out = out.push(l_bytes[1])
  out = out.push(l_bytes[2])
  out = out.push(l_bytes[3])

  // 8. sh_info (4 bytes)
  inf_bytes = shdr_pack_u32_le(shdr.sh_info)
  out = out.push(inf_bytes[0])
  out = out.push(inf_bytes[1])
  out = out.push(inf_bytes[2])
  out = out.push(inf_bytes[3])

  // 9. sh_addralign (8 bytes)
  al_bytes = shdr_pack_u64_le(shdr.sh_addralign)
  i = 0
  @while i < 8
    out = out.push(al_bytes[i])
    i = i + 1
  @end

  // 10. sh_entsize (8 bytes)
  es_bytes = shdr_pack_u64_le(shdr.sh_entsize)
  i = 0
  @while i < 8
    out = out.push(es_bytes[i])
    i = i + 1
  @end

  return out
@end

@fn elf_section_headers_serialize(shdrs)
  // WHY: Serializes the entire section header table sequentially.
  out = []
  i = 0
  count = shdrs.len()
  @while i < count
    hdr_bytes = elf_section_header_serialize(shdrs[i])
    j = 0
    @while j < 64
      out = out.push(hdr_bytes[j])
      j = j + 1
    @end
    i = i + 1
  @end
  return out
@end
