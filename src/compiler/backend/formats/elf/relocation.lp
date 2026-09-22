// ============================================================================
// LIPI SOVEREIGN COMPILER — ELF64 SYMBOL RELOCATION RESOLVER
// Module: src/compiler/backend/formats/elf/relocation.lp
// Standard: System V AMD64 ABI Relocation Types & Symbol Encoding
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: Relocations are the mechanism by which compiler code generation and
// linker symbol resolution connect symbolic references (function calls, global
// data pointers, jump tables) to concrete virtual memory addresses.
// In ELF64, relocations with explicit addends (Elf64_Rela) are 24 bytes each,
// and symbols (Elf64_Sym) are 24 bytes each.

// --- Relocation Types: x86_64 (r_type) ---
// Standard System V AMD64 ABI relocations:
// S = Symbol virtual address
// A = Addend specified in Elf64_Rela
// P = Place (virtual address of the storage unit being relocated: base_vaddr + r_offset)
@fn R_X86_64_NONE()      return 0  @end // No relocation
@fn R_X86_64_64()        return 1  @end // Direct 64-bit absolute address: S + A
@fn R_X86_64_PC32()      return 2  @end // PC-relative 32-bit signed displacement: S + A - P (Calls/Jumps/RIP-relative)
@fn R_X86_64_GOT32()     return 3  @end // 32-bit GOT entry offset: G + A
@fn R_X86_64_PLT32()     return 4  @end // 32-bit PLT address: L + A - P
@fn R_X86_64_COPY()      return 5  @end // Copy symbol at runtime
@fn R_X86_64_GLOB_DAT()  return 6  @end // Create GOT entry: S
@fn R_X86_64_JUMP_SLOT() return 7  @end // Create PLT entry: S
@fn R_X86_64_RELATIVE()  return 8  @end // Adjust by program base: B + A
@fn R_X86_64_GOTPCREL()  return 9  @end // 32-bit signed PC-relative to GOT entry: G + GOT + A - P
@fn R_X86_64_32()        return 10 @end // Direct 32-bit zero-extended: S + A
@fn R_X86_64_32S()       return 11 @end // Direct 32-bit sign-extended: S + A
@fn R_X86_64_16()        return 12 @end // Direct 16-bit: S + A
@fn R_X86_64_PC16()      return 13 @end // 16-bit signed PC-relative: S + A - P
@fn R_X86_64_8()         return 14 @end // Direct 8-bit: S + A
@fn R_X86_64_PC8()       return 15 @end // 8-bit signed PC-relative: S + A - P
@fn R_X86_64_PC64()      return 24 @end // 64-bit signed PC-relative: S + A - P

// --- Relocation Types: AArch64 (ARM64) ---
@fn R_AARCH64_NONE()   return 0   @end
@fn R_AARCH64_ABS64()  return 257 @end // Direct 64-bit address: S + A
@fn R_AARCH64_PREL32() return 261 @end // 32-bit PC-relative: S + A - P
@fn R_AARCH64_CALL26() return 283 @end // 26-bit PC-relative branch (B / BL): S + A - P >> 2
@fn R_AARCH64_JUMP26() return 282 @end // 26-bit PC-relative jump

// --- Symbol Binding (STB) ---
// WHY: Controls linkage visibility.
@fn STB_LOCAL()  return 0  @end // Local symbol, invisible outside the object file
@fn STB_GLOBAL() return 1  @end // Global symbol, visible across compilation units
@fn STB_WEAK()   return 2  @end // Weak global symbol, can be overridden

// --- Symbol Types (STT) ---
// WHY: Classifies the entity referenced by the symbol.
@fn STT_NOTYPE()  return 0 @end // Unspecified type
@fn STT_OBJECT()  return 1 @end // Data object (variable, array)
@fn STT_FUNC()    return 2 @end // Executable function / code procedure
@fn STT_SECTION() return 3 @end // Section reference
@fn STT_FILE()    return 4 @end // Source filename
@fn STT_COMMON()  return 5 @end // Common unallocated data block
@fn STT_TLS()     return 6 @end // Thread local storage

// --- Special Section Indices ---
@fn SHN_UNDEF()  return 0     @end // Undefined symbol (external reference)
@fn SHN_ABS()    return 65521 @end // 0xFFF1: Absolute symbol (value will not change during relocation)
@fn SHN_COMMON() return 65522 @end // 0xFFF2: Common symbol

@fn ELF64_SYM_BYTES()  return 24 @end
@fn ELF64_RELA_BYTES() return 24 @end

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct Elf64Symbol
  st_name: i64  // 4 bytes: Symbol name offset into .strtab
  st_info: i64  // 1 byte:  (bind << 4) | (type & 0xF)
  st_other: i64 // 1 byte:  Symbol visibility (0 for default)
  st_shndx: i64 // 2 bytes: Relevant section header index (e.g. .text = 1)
  st_value: i64 // 8 bytes: Symbol virtual address or section offset
  st_size: i64  // 8 bytes: Symbol size in bytes
@end

@struct Elf64Rela
  r_offset: i64 // 8 bytes: Location at which to apply relocation action (section offset)
  r_info: i64   // 8 bytes: (symbol_index << 32) | (relocation_type & 0xFFFFFFFF)
  r_addend: i64 // 8 bytes: Explicit signed constant addend
@end

@struct RelocRecord
  target_name: string // Symbolic target identifier (e.g. "my_function")
  reloc_type: i64     // R_X86_64_PC32 or R_X86_64_64
  code_offset: i64    // Byte offset in code buffer where the patch must be applied
  addend: i64         // Addend (usually -4 for x86_64 relative call rip displacement)
@end

// ============================================================================
// 2. INTEGER PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn reloc_pack_u16_le(val)
  v = val
  @if v < 0
    v = v + 65536
  @end
  return [v % 256, (v / 256) % 256]
@end

@fn reloc_pack_u32_le(val)
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

@fn reloc_pack_u64_le(val)
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
// 3. SYMBOL AND RELA FACTORY
// ============================================================================

@fn elf_symbol_create(name_offset, value, size, bind, sym_type, shndx)
  // WHY: Constructs an Elf64_Sym entry.
  // st_info packs binding in the upper nibble (bits 4-7) and type in the lower nibble (bits 0-3).
  info = ((bind & 15) * 16) + (sym_type & 15)
  return {
    st_name: name_offset,
    st_info: info,
    st_other: 0, // STV_DEFAULT
    st_shndx: shndx,
    st_value: value,
    st_size: size
  }
@end

@fn elf_rela_create(offset, symbol_index, reloc_type, addend)
  // WHY: Constructs an Elf64_Rela entry.
  // r_info packs symbol table index in upper 32 bits and relocation type in lower 32 bits.
  info = (symbol_index * 4294967296) + (reloc_type & 4294967295)
  return {
    r_offset: offset,
    r_info: info,
    r_addend: addend
  }
@end

// ============================================================================
// 4. SERIALIZATION (Elf64_Sym: 24 Bytes, Elf64_Rela: 24 Bytes)
// ============================================================================

@fn elf_symbol_serialize(sym)
  // WHY: Serializes an Elf64_Sym structure to exactly 24 bytes:
  // Offset 0x00: st_name  (Elf64_Word,  4 bytes)
  // Offset 0x04: st_info  (unsigned char, 1 byte)
  // Offset 0x05: st_other (unsigned char, 1 byte)
  // Offset 0x06: st_shndx (Elf64_Section, 2 bytes)
  // Offset 0x08: st_value (Elf64_Addr,  8 bytes)
  // Offset 0x10: st_size  (Elf64_Xword, 8 bytes)
  // Total: 24 bytes.
  out = []

  // 1. st_name (4 bytes)
  n_bytes = reloc_pack_u32_le(sym.st_name)
  out = out.push(n_bytes[0])
  out = out.push(n_bytes[1])
  out = out.push(n_bytes[2])
  out = out.push(n_bytes[3])

  // 2. st_info (1 byte)
  out = out.push(sym.st_info % 256)

  // 3. st_other (1 byte)
  out = out.push(sym.st_other % 256)

  // 4. st_shndx (2 bytes)
  sx_bytes = reloc_pack_u16_le(sym.st_shndx)
  out = out.push(sx_bytes[0])
  out = out.push(sx_bytes[1])

  // 5. st_value (8 bytes)
  v_bytes = reloc_pack_u64_le(sym.st_value)
  i = 0
  @while i < 8
    out = out.push(v_bytes[i])
    i = i + 1
  @end

  // 6. st_size (8 bytes)
  s_bytes = reloc_pack_u64_le(sym.st_size)
  i = 0
  @while i < 8
    out = out.push(s_bytes[i])
    i = i + 1
  @end

  return out
@end

@fn elf_rela_serialize(rela)
  // WHY: Serializes an Elf64_Rela structure to exactly 24 bytes:
  // Offset 0x00: r_offset (Elf64_Addr, 8 bytes)
  // Offset 0x08: r_info   (Elf64_Xword, 8 bytes)
  // Offset 0x10: r_addend (Elf64_Sxword, 8 bytes)
  // Total: 24 bytes.
  out = []

  // 1. r_offset (8 bytes)
  o_bytes = reloc_pack_u64_le(rela.r_offset)
  i = 0
  @while i < 8
    out = out.push(o_bytes[i])
    i = i + 1
  @end

  // 2. r_info (8 bytes)
  inf_bytes = reloc_pack_u64_le(rela.r_info)
  i = 0
  @while i < 8
    out = out.push(inf_bytes[i])
    i = i + 1
  @end

  // 3. r_addend (8 bytes signed)
  add_bytes = reloc_pack_u64_le(rela.r_addend)
  i = 0
  @while i < 8
    out = out.push(add_bytes[i])
    i = i + 1
  @end

  return out
@end

// ============================================================================
// 5. RELOCATION CALCULATION & IN-MEMORY RESOLUTION ENGINE
// ============================================================================

@fn elf_resolve_pc32(target_vaddr, addend, place_vaddr)
  // WHY: Evaluates R_X86_64_PC32 formula: S + A - P
  // In x86_64 machine code, RIP is updated to the address of the NEXT instruction
  // before the displacement is added. Thus, for an instruction like `call rel32`
  // (opcode E8, 5 bytes total: 1 byte opcode + 4 bytes displacement),
  // place_vaddr is the address of the displacement field, and addend is typically -4
  // so that (target_vaddr + (-4) - place_vaddr) = target_vaddr - (place_vaddr + 4).
  disp = (target_vaddr + addend) - place_vaddr
  return disp
@end

@fn elf_resolve_abs64(target_vaddr, addend)
  // WHY: Evaluates R_X86_64_64 direct 64-bit absolute address: S + A
  return target_vaddr + addend
@end

@fn elf_apply_relocation_pc32(code_buf, offset, target_vaddr, addend, place_vaddr)
  // WHY: Patches a 32-bit signed relative displacement into code_buf at offset.
  disp = elf_resolve_pc32(target_vaddr, addend, place_vaddr)
  disp_bytes = reloc_pack_u32_le(disp)
  code_buf = list_set(code_buf, offset, disp_bytes[0])
  code_buf = list_set(code_buf, offset + 1, disp_bytes[1])
  code_buf = list_set(code_buf, offset + 2, disp_bytes[2])
  code_buf = list_set(code_buf, offset + 3, disp_bytes[3])
  return code_buf
@end

@fn elf_apply_relocation_64(code_buf, offset, target_vaddr, addend)
  // WHY: Patches an 8-byte 64-bit absolute address into code_buf at offset.
  val = elf_resolve_abs64(target_vaddr, addend)
  val_bytes = reloc_pack_u64_le(val)
  i = 0
  @while i < 8
    code_buf = list_set(code_buf, offset + i, val_bytes[i])
    i = i + 1
  @end
  return code_buf
@end

@fn elf_resolve_all_relocations(code_buf, relocs_list, sym_name_map, base_code_vaddr)
  // WHY: Performs batch in-memory link-time resolution of all relocations in code_buf.
  // relocs_list: list of RelocRecord structs
  // sym_name_map: dictionary/hash map of { name: symbol_vaddr }
  // base_code_vaddr: base virtual address of the .text section (e.g. 0x401000)
  i = 0
  count = relocs_list.len()
  @while i < count
    rec = relocs_list[i]
    target_addr = sym_name_map[rec.target_name]
    @if target_addr != 0
      place = base_code_vaddr + rec.code_offset
      @if rec.reloc_type == R_X86_64_PC32()
        code_buf = elf_apply_relocation_pc32(code_buf, rec.code_offset, target_addr, rec.addend, place)
      @elif rec.reloc_type == R_X86_64_64()
        code_buf = elf_apply_relocation_64(code_buf, rec.code_offset, target_addr, rec.addend)
      @end
    @end
    i = i + 1
  @end
  return code_buf
@end
