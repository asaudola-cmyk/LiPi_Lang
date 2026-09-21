// ============================================================================
// LIPI SOVEREIGN COMPILER — DWARF INFO & ABBREV EMITTER (.debug_info, .debug_abbrev)
// Module: src/compiler/backend/formats/debug/dwarf_info.lp
// Standard: DWARF Debugging Information Format v4 / v5
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: The .debug_info section contains the structural metadata tree of the program
// represented as Debugging Information Entries (DIEs).
// Each DIE describes a semantic construct: compilation units, functions, variables,
// types, and parameters.
// To conserve space, each DIE references an abbreviation code in the .debug_abbrev
// section which defines its tag, whether it has child DIEs, and the schema of its attributes.

import "universe/core/string"

// --- DWARF Tags (DW_TAG) ---
@fn DW_TAG_formal_parameter() return 5  @end // 0x05: Function argument
@fn DW_TAG_pointer_type()     return 15 @end // 0x0F: Pointer type descriptor
@fn DW_TAG_compile_unit()     return 17 @end // 0x11: Compilation Unit root DIE
@fn DW_TAG_base_type()        return 36 @end // 0x24: Fundamental primitive type (i64, f64, bool)
@fn DW_TAG_subprogram()       return 46 @end // 0x2E: Executable procedure / function
@fn DW_TAG_variable()         return 52 @end // 0x34: Global or local variable

// --- Children Flag ---
@fn DW_CHILDREN_no()  return 0 @end // DIE has no child entries
@fn DW_CHILDREN_yes() return 1 @end // DIE has a sequence of child entries terminated by 0

// --- DWARF Attributes (DW_AT) ---
@fn DW_AT_sibling()   return 1  @end // 0x01: Reference to next sibling DIE
@fn DW_AT_name()      return 3  @end // 0x03: String name of entity
@fn DW_AT_byte_size() return 11 @end // 0x0B: Size of type in bytes
@fn DW_AT_stmt_list() return 16 @end // 0x10: Offset into .debug_line table
@fn DW_AT_low_pc()    return 17 @end // 0x11: Beginning virtual address of code
@fn DW_AT_high_pc()   return 18 @end // 0x12: Ending virtual address or length
@fn DW_AT_language()  return 19 @end // 0x13: Source language identifier
@fn DW_AT_comp_dir()  return 27 @end // 0x1B: Compilation working directory
@fn DW_AT_producer()  return 37 @end // 0x25: Compiler identity string
@fn DW_AT_decl_file() return 58 @end // 0x3A: Source file where entity was declared
@fn DW_AT_decl_line() return 59 @end // 0x3B: Source line where entity was declared
@fn DW_AT_type()      return 73 @end // 0x49: Reference to type DIE
@fn DW_AT_encoding()  return 62 @end // 0x3E: Base type encoding (signed, float, bool)

// --- DWARF Attribute Forms (DW_FORM) ---
@fn DW_FORM_addr()       return 1  @end // 0x01: Target architecture virtual address (8 bytes)
@fn DW_FORM_data2()      return 5  @end // 0x05: 2 bytes unsigned data
@fn DW_FORM_data4()      return 6  @end // 0x06: 4 bytes unsigned data
@fn DW_FORM_data8()      return 7  @end // 0x07: 8 bytes unsigned data
@fn DW_FORM_string()     return 8  @end // 0x08: Inline null-terminated string
@fn DW_FORM_data1()      return 11 @end // 0x0B: 1 byte unsigned data
@fn DW_FORM_strp()       return 14 @end // 0x0E: 4-byte offset into .debug_str
@fn DW_FORM_udata()      return 15 @end // 0x0F: ULEB128 unsigned number
@fn DW_FORM_ref4()       return 19 @end // 0x13: 4-byte reference relative to start of CU
@fn DW_FORM_sec_offset() return 23 @end // 0x17: 4-byte section offset (DWARF4+)

// --- Language Identifiers ---
@fn DW_LANG_C99()  return 12    @end // 0x000C: C99 standard
@fn DW_LANG_LIPI() return 32769 @end // 0x8001: Sovereign Lipi language

// --- Base Type Encodings (DW_ATE) ---
@fn DW_ATE_address()  return 1 @end // 0x01: Pointer / address
@fn DW_ATE_boolean()  return 2 @end // 0x02: Boolean (true/false)
@fn DW_ATE_float()    return 4 @end // 0x04: IEEE-754 floating point
@fn DW_ATE_signed()   return 5 @end // 0x05: Two's complement signed integer
@fn DW_ATE_unsigned() return 7 @end // 0x07: Unsigned integer

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct DwarfFunctionInfo
  dwf_name: string
  dwf_low_pc: i64
  dwf_high_pc: i64
  dwf_decl_file: i64
  dwf_decl_line: i64
@end

@struct DwarfBaseTypeInfo
  dwt_name: string
  dwt_byte_size: i64
  dwt_encoding: i64
@end

@struct DwarfUnitInfo
  dwu_producer: string
  dwu_source_file: string
  dwu_comp_dir: string
  dwu_low_pc: i64
  dwu_high_pc: i64
  dwu_stmt_list_offset: i64
  dwu_functions: array
  dwu_types: array
@end

// ============================================================================
// 2. INTEGER & LEB128 PACKING HELPERS
// ============================================================================

@fn dwarf_info_uleb128(val)
  v = val
  bytes = []
  more = 1
  @while more == 1
    b = v & 127
    v = v >> 7
    @if v != 0
      bytes = bytes.push(b | 128)
    @else
      bytes = bytes.push(b)
      more = 0
    @end
  @end
  return bytes
@end

@fn dwarf_info_pack_u16(val)
  v = val
  @if v < 0 v = v + 65536 @end
  return [v % 256, (v / 256) % 256]
@end

@fn dwarf_info_pack_u32(val)
  v = val
  @if v < 0 v = v + 4294967296 @end
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn dwarf_info_pack_u64(val)
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

@fn dwarf_info_pack_string(str_val)
  bytes = []
  i = 0
  n = str_val.len()
  @while i < n
    bytes = bytes.push(str_char_at(str_val, i))
    i = i + 1
  @end
  bytes = bytes.push(0) // Terminating null byte
  return bytes
@end

// ============================================================================
// 3. FACTORY BUILDERS
// ============================================================================

@fn dwarf_unit_create(producer, source_file, comp_dir, low_pc, high_pc, stmt_list_offset)
  // WHY: Constructs a compilation unit metadata container.
  return {
    dwu_producer: producer,
    dwu_source_file: source_file,
    dwu_comp_dir: comp_dir,
    dwu_low_pc: low_pc,
    dwu_high_pc: high_pc,
    dwu_stmt_list_offset: stmt_list_offset,
    dwu_functions: [],
    dwu_types: []
  }
@end

@fn dwarf_unit_add_function(unit, name, low_pc, high_pc, decl_file, decl_line)
  // WHY: Registers a subprogram function DIE descriptor.
  unit.dwu_functions = unit.dwu_functions.push({
    dwf_name: name,
    dwf_low_pc: low_pc,
    dwf_high_pc: high_pc,
    dwf_decl_file: decl_file,
    dwf_decl_line: decl_line
  })
  return unit
@end

@fn dwarf_unit_add_base_type(unit, name, byte_size, encoding)
  // WHY: Registers a fundamental primitive type descriptor (e.g. i64, f64).
  unit.dwu_types = unit.dwu_types.push({
    dwt_name: name,
    dwt_byte_size: byte_size,
    dwt_encoding: encoding
  })
  return unit
@end

// ============================================================================
// 4. .debug_abbrev EMITTER
// ============================================================================

@fn dwarf_abbrev_build_standard()
  // WHY: Constructs the canonical .debug_abbrev table for Lipi compilation units.
  //
  // Abbrev 1: DW_TAG_compile_unit (has children = 1)
  //   DW_AT_producer  -> DW_FORM_string
  //   DW_AT_language  -> DW_FORM_data2
  //   DW_AT_name      -> DW_FORM_string
  //   DW_AT_comp_dir  -> DW_FORM_string
  //   DW_AT_low_pc    -> DW_FORM_addr
  //   DW_AT_high_pc   -> DW_FORM_addr
  //   DW_AT_stmt_list -> DW_FORM_sec_offset
  //   [0, 0]
  //
  // Abbrev 2: DW_TAG_subprogram (has children = 0)
  //   DW_AT_name      -> DW_FORM_string
  //   DW_AT_low_pc    -> DW_FORM_addr
  //   DW_AT_high_pc   -> DW_FORM_addr
  //   DW_AT_decl_file -> DW_FORM_udata
  //   DW_AT_decl_line -> DW_FORM_udata
  //   [0, 0]
  //
  // Abbrev 3: DW_TAG_base_type (has children = 0)
  //   DW_AT_name      -> DW_FORM_string
  //   DW_AT_byte_size -> DW_FORM_data1
  //   DW_AT_encoding  -> DW_FORM_data1
  //   [0, 0]
  //
  // Table ends with single 0 byte.

  out = []

  // --- Abbrev 1: Compile Unit ---
  out = out.push(1)                                // Abbrev code 1 (ULEB128)
  out = out.push(DW_TAG_compile_unit())            // Tag 0x11
  out = out.push(DW_CHILDREN_yes())                // Children = 1

  // Attributes:
  out = out.push(DW_AT_producer())  out = out.push(DW_FORM_string())
  out = out.push(DW_AT_language())  out = out.push(DW_FORM_data2())
  out = out.push(DW_AT_name())      out = out.push(DW_FORM_string())
  out = out.push(DW_AT_comp_dir())  out = out.push(DW_FORM_string())
  out = out.push(DW_AT_low_pc())    out = out.push(DW_FORM_addr())
  out = out.push(DW_AT_high_pc())   out = out.push(DW_FORM_addr())
  out = out.push(DW_AT_stmt_list()) out = out.push(DW_FORM_sec_offset())
  out = out.push(0) out = out.push(0)              // End attributes for abbrev 1

  // --- Abbrev 2: Subprogram ---
  out = out.push(2)                                // Abbrev code 2
  out = out.push(DW_TAG_subprogram())              // Tag 0x2E
  out = out.push(DW_CHILDREN_no())                 // Children = 0

  out = out.push(DW_AT_name())      out = out.push(DW_FORM_string())
  out = out.push(DW_AT_low_pc())    out = out.push(DW_FORM_addr())
  out = out.push(DW_AT_high_pc())   out = out.push(DW_FORM_addr())
  out = out.push(DW_AT_decl_file()) out = out.push(DW_FORM_udata())
  out = out.push(DW_AT_decl_line()) out = out.push(DW_FORM_udata())
  out = out.push(0) out = out.push(0)              // End attributes for abbrev 2

  // --- Abbrev 3: Base Type ---
  out = out.push(3)                                // Abbrev code 3
  out = out.push(DW_TAG_base_type())               // Tag 0x24
  out = out.push(DW_CHILDREN_no())                 // Children = 0

  out = out.push(DW_AT_name())      out = out.push(DW_FORM_string())
  out = out.push(DW_AT_byte_size()) out = out.push(DW_FORM_data1())
  out = out.push(DW_AT_encoding())  out = out.push(DW_FORM_data1())
  out = out.push(0) out = out.push(0)              // End attributes for abbrev 3

  // End of .debug_abbrev table
  out = out.push(0)

  return out
@end

@fn dwarf_info_append_bytes(dest, src)
  // WHY: Safely append bytes from src to dest avoiding single-line loop AST anomalies.
  k = 0
  @while k < src.len()
    dest = dest.push(src[k])
    k = k + 1
  @end
  return dest
@end

// ============================================================================
// 5. .debug_info EMITTER
// ============================================================================

@fn dwarf_info_serialize(unit)
  // WHY: Serializes the Compilation Unit DIE and its children into the .debug_info section.
  //
  // Layout:
  // 1. unit_length (4 bytes): Size of following fields (version + abbrev_offset + addr_size + DIEs)
  // 2. version (2 bytes: 4 for DWARF v4)
  // 3. debug_abbrev_offset (4 bytes: 0)
  // 4. address_size (1 byte: 8 for 64-bit)
  // 5. Root DIE (Abbrev 1: DW_TAG_compile_unit):
  //    - producer string
  //    - language (2 bytes)
  //    - source file name string
  //    - comp_dir string
  //    - low_pc (8 bytes)
  //    - high_pc (8 bytes)
  //    - stmt_list offset (4 bytes)
  // 6. Child DIEs:
  //    - Function DIEs (Abbrev 2)
  //    - Base Type DIEs (Abbrev 3)
  // 7. Null terminator (1 byte: 0) ending CU child list.

  dies_body = []

  // --- Root DIE: Compile Unit (Abbrev 1) ---
  dies_body = dies_body.push(1) // Abbrev code 1

  // DW_AT_producer (string)
  p_str = dwarf_info_pack_string(unit.dwu_producer)
  dies_body = dwarf_info_append_bytes(dies_body, p_str)

  // DW_AT_language (data2: 0x0C = C99)
  lang_bytes = dwarf_info_pack_u16(DW_LANG_C99())
  dies_body = dies_body.push(lang_bytes[0])
  dies_body = dies_body.push(lang_bytes[1])

  // DW_AT_name (string)
  n_str = dwarf_info_pack_string(unit.dwu_source_file)
  dies_body = dwarf_info_append_bytes(dies_body, n_str)

  // DW_AT_comp_dir (string)
  cd_str = dwarf_info_pack_string(unit.dwu_comp_dir)
  dies_body = dwarf_info_append_bytes(dies_body, cd_str)

  // DW_AT_low_pc (addr: 8 bytes)
  lp = dwarf_info_pack_u64(unit.dwu_low_pc)
  dies_body = dwarf_info_append_bytes(dies_body, lp)

  // DW_AT_high_pc (addr: 8 bytes)
  hp = dwarf_info_pack_u64(unit.dwu_high_pc)
  dies_body = dwarf_info_append_bytes(dies_body, hp)

  // DW_AT_stmt_list (sec_offset: 4 bytes)
  sl = dwarf_info_pack_u32(unit.dwu_stmt_list_offset)
  dies_body = dwarf_info_append_bytes(dies_body, sl)

  // --- Child DIEs: Functions (Abbrev 2) ---
  i = 0
  num_fn = unit.dwu_functions.len()
  @while i < num_fn
    fn_info = unit.dwu_functions[i]
    dies_body = dies_body.push(2) // Abbrev code 2

    // DW_AT_name (string)
    fn_name = dwarf_info_pack_string(fn_info.dwf_name)
    dies_body = dwarf_info_append_bytes(dies_body, fn_name)

    // DW_AT_low_pc (addr: 8 bytes)
    fn_lp = dwarf_info_pack_u64(fn_info.dwf_low_pc)
    dies_body = dwarf_info_append_bytes(dies_body, fn_lp)

    // DW_AT_high_pc (addr: 8 bytes)
    fn_hp = dwarf_info_pack_u64(fn_info.dwf_high_pc)
    dies_body = dwarf_info_append_bytes(dies_body, fn_hp)

    // DW_AT_decl_file (udata)
    df_uleb = dwarf_info_uleb128(fn_info.dwf_decl_file)
    dies_body = dwarf_info_append_bytes(dies_body, df_uleb)

    // DW_AT_decl_line (udata)
    dl_uleb = dwarf_info_uleb128(fn_info.dwf_decl_line)
    dies_body = dwarf_info_append_bytes(dies_body, dl_uleb)

    i = i + 1
  @end

  // --- Child DIEs: Base Types (Abbrev 3) ---
  i = 0
  num_ty = unit.dwu_types.len()
  @while i < num_ty
    ty_info = unit.dwu_types[i]
    dies_body = dies_body.push(3) // Abbrev code 3

    // DW_AT_name (string)
    ty_name = dwarf_info_pack_string(ty_info.dwt_name)
    dies_body = dwarf_info_append_bytes(dies_body, ty_name)

    // DW_AT_byte_size (data1: 1 byte)
    dies_body = dies_body.push(ty_info.dwt_byte_size % 256)

    // DW_AT_encoding (data1: 1 byte)
    dies_body = dies_body.push(ty_info.dwt_encoding % 256)

    i = i + 1
  @end

  // Terminating null byte ending children of Compile Unit
  dies_body = dies_body.push(0)

  // Total unit_length: version(2) + abbrev_offset(4) + addr_size(1) + dies_body
  unit_length = 2 + 4 + 1 + dies_body.len()

  out = []

  // 1. unit_length (4 bytes)
  ul = dwarf_info_pack_u32(unit_length)
  out = dwarf_info_append_bytes(out, ul)

  // 2. version (2 bytes: 4)
  ver = dwarf_info_pack_u16(4)
  out = out.push(ver[0]) out = out.push(ver[1])

  // 3. debug_abbrev_offset (4 bytes: 0)
  out = out.push(0) out = out.push(0) out = out.push(0) out = out.push(0)

  // 4. address_size (1 byte: 8)
  out = out.push(8)

  // 5. dies_body
  out = dwarf_info_append_bytes(out, dies_body)

  return out
@end
