// ============================================================================
// LIPI SOVEREIGN COMPILER — DWARF LINE PROGRAM EMITTER (.debug_line)
// Module: src/compiler/backend/formats/debug/dwarf_line.lp
// Standard: DWARF Debugging Information Format v4 / v5
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: The .debug_line section allows source-level debuggers (GDB, LLDB, lipidbg)
// and panic stack-trace unwinders to map runtime program counter (PC) addresses
// back to precise source filenames, line numbers, and column numbers.
// Instead of storing a bloated raw lookup table, DWARF defines a compact,
// bytecode-driven finite state machine using standard, extended, and special opcodes.

import "universe/core/string"

// --- DWARF Standard Opcodes (DW_LNS) ---
@fn DW_LNS_extended_op()        return 0  @end // Escape to extended opcode sequence
@fn DW_LNS_copy()               return 1  @end // Appends row to matrix using current register values
@fn DW_LNS_advance_pc()         return 2  @end // Advances PC by (operand * min_instruction_len)
@fn DW_LNS_advance_line()       return 3  @end // Adds signed SLEB128 operand to line register
@fn DW_LNS_set_file()           return 4  @end // Sets file register to ULEB128 operand
@fn DW_LNS_set_column()         return 5  @end // Sets column register to ULEB128 operand
@fn DW_LNS_negate_stmt()        return 6  @end // Inverts is_stmt boolean flag
@fn DW_LNS_set_basic_block()    return 7  @end // Marks beginning of basic block
@fn DW_LNS_const_add_pc()       return 8  @end // Advances PC by fixed opcode_base constant
@fn DW_LNS_fixed_advance_pc()   return 9  @end // Adds 16-bit unscaled operand to PC
@fn DW_LNS_set_prologue_end()   return 10 @end // Signals end of function prologue
@fn DW_LNS_set_epilogue_begin() return 11 @end // Signals start of function epilogue
@fn DW_LNS_set_isa()            return 12 @end // Sets instruction set architecture register

// --- DWARF Extended Opcodes (DW_LNE) ---
// Prefixed by opcode 0, length (ULEB128), and the extended opcode byte:
@fn DW_LNE_end_sequence() return 1 @end // Emits row, resets registers, ends line sequence
@fn DW_LNE_set_address()  return 2 @end // Sets 64-bit absolute target PC address
@fn DW_LNE_define_file()  return 3 @end // Dynamically defines new source file entry

// --- Standard Header Tuning Parameters ---
// WHY: Tuning parameters determine the line delta / PC advance trade-off in special opcodes.
// LINE_BASE = -5: Allows backward jumps (e.g. loops) of up to -5 lines in 1 byte.
// LINE_RANGE = 14: Encodes line deltas in range [-5 .. 8].
// OPCODE_BASE = 13: Standard opcodes 1..12, special opcodes start at 13 up to 255.
@fn DWARF_LINE_BASE()    return 251 @end // -5 represented as unsigned byte (256 - 5)
@fn DWARF_LINE_BASE_VAL()return 0 - 5 @end
@fn DWARF_LINE_RANGE()   return 14  @end
@fn DWARF_OPCODE_BASE()  return 13  @end

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct DwarfLineBuilder
  version: i64         // 2 bytes: 4 (DWARF v4) or 5 (DWARF v5)
  default_is_stmt: i64 // 1 byte: 1
  min_inst_len: i64    // 1 byte: 1 (x86_64) or 4 (AArch64)
  include_dirs: array  // List of string directory paths
  file_names: array    // List of { name: string, dir_idx: i64 }
  opcodes: array       // Bytecode buffer for line number program
  curr_pc: i64         // Current state machine virtual PC address
  curr_line: i64       // Current state machine line (1-based)
  curr_file: i64       // Current state machine file index (1-based)
  curr_col: i64        // Current state machine column (0-based)
  is_stmt: i64         // Statement flag
@end

// ============================================================================
// 2. VARIABLE-LENGTH INTEGER ENCODING (ULEB128 & SLEB128)
// ============================================================================

@fn dwarf_encode_uleb128(val)
  // WHY: Unsigned Little-Endian Base 128 (ULEB128) encodes arbitrarily large
  // positive integers compactly. Each byte holds 7 bits of data.
  // The highest bit (bit 7, 0x80) indicates whether more bytes follow.
  v = val
  bytes = []
  more = 1
  @while more == 1
    byte_val = v & 127
    v = v >> 7
    @if v != 0
      byte_val = byte_val | 128 // Set continuation bit
      bytes = bytes.push(byte_val)
    @else
      bytes = bytes.push(byte_val)
      more = 0
    @end
  @end
  return bytes
@end

@fn dwarf_encode_sleb128(val)
  // WHY: Signed Little-Endian Base 128 (SLEB128) encodes signed integers.
  // Sign extension of the 7th bit of the last byte indicates positive/negative.
  v = val
  bytes = []
  more = 1
  @while more == 1
    byte_val = v & 127
    sign_bit = byte_val & 64 // Bit 6 is the sign bit of this 7-bit chunk
    v = v >> 7
    // Termination condition:
    // If v == 0 and sign bit is 0 -> positive finished.
    // If v == -1 and sign bit is 64 -> negative finished.
    @if (v == 0 && sign_bit == 0) || (v == (0 - 1) && sign_bit != 0)
      bytes = bytes.push(byte_val)
      more = 0
    @else
      byte_val = byte_val | 128
      bytes = bytes.push(byte_val)
    @end
  @end
  return bytes
@end

@fn dwarf_pack_u16(val)
  v = val
  @if v < 0 v = v + 65536 @end
  return [v % 256, (v / 256) % 256]
@end

@fn dwarf_pack_u32(val)
  v = val
  @if v < 0 v = v + 4294967296 @end
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn dwarf_pack_u64(val)
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
// 3. BUILDER FACTORY & INITIALIZATION
// ============================================================================

@fn dwarf_line_builder_new(version)
  // WHY: Initializes a fresh DWARF Line Builder.
  // Defaults: version 4, default_is_stmt = 1, min_inst_len = 1.
  ver = version
  @if ver <= 0 ver = 4 @end

  return {
    version: ver,
    default_is_stmt: 1,
    min_inst_len: 1,
    include_dirs: [],
    file_names: [],
    opcodes: [],
    curr_pc: 0,
    curr_line: 1,
    curr_file: 1,
    curr_col: 0,
    is_stmt: 1
  }
@end

@fn dwarf_line_add_dir(builder, dir_path)
  // WHY: Adds an include directory path to the header directory table.
  builder.include_dirs = builder.include_dirs.push(dir_path)
  return builder.include_dirs.len()
@end

@fn dwarf_line_add_file(builder, file_name, dir_index)
  // WHY: Registers a source file in the header file table.
  // Returns 1-based file index as required by DWARF.
  builder.file_names = builder.file_names.push({
    name: file_name,
    dir_idx: dir_index
  })
  return builder.file_names.len()
@end

// ============================================================================
// 4. BYTECODE EMITTER OPERATIONS
// ============================================================================

@fn dwarf_line_emit_set_address(builder, vaddr)
  // WHY: Emits DW_LNE_set_address (extended opcode 2) to set the initial PC address.
  // Opcode 0 (escape), length 9 (ULEB128), extended opcode 2, 8 bytes address.
  builder.opcodes = builder.opcodes.push(DW_LNS_extended_op()) // 0
  builder.opcodes = builder.opcodes.push(9)                    // length = 1 (for opcode) + 8 (for addr)
  builder.opcodes = builder.opcodes.push(DW_LNE_set_address()) // 2
  addr_bytes = dwarf_pack_u64(vaddr)
  i = 0
  @while i < 8
    builder.opcodes = builder.opcodes.push(addr_bytes[i])
    i = i + 1
  @end
  builder.curr_pc = vaddr
  return builder
@end

@fn dwarf_line_emit_advance_line(builder, line_delta)
  // WHY: Emits DW_LNS_advance_line with SLEB128 operand.
  builder.opcodes = builder.opcodes.push(DW_LNS_advance_line())
  sleb = dwarf_encode_sleb128(line_delta)
  i = 0
  @while i < sleb.len()
    builder.opcodes = builder.opcodes.push(sleb[i])
    i = i + 1
  @end
  builder.curr_line = builder.curr_line + line_delta
  return builder
@end

@fn dwarf_line_emit_advance_pc(builder, pc_advance)
  // WHY: Emits DW_LNS_advance_pc with ULEB128 operand.
  builder.opcodes = builder.opcodes.push(DW_LNS_advance_pc())
  uleb = dwarf_encode_uleb128(pc_advance / builder.min_inst_len)
  i = 0
  @while i < uleb.len()
    builder.opcodes = builder.opcodes.push(uleb[i])
    i = i + 1
  @end
  builder.curr_pc = builder.curr_pc + pc_advance
  return builder
@end

@fn dwarf_line_emit_copy(builder)
  // WHY: Emits DW_LNS_copy to append current row to the debug matrix.
  builder.opcodes = builder.opcodes.push(DW_LNS_copy())
  return builder
@end

@fn dwarf_line_emit_row(builder, target_pc, target_line, target_col)
  // WHY: Core row emitter. Maps PC -> (line, col).
  // Calculates PC delta and Line delta. Checks if it can be represented as a
  // compact 1-byte DWARF special opcode:
  //   special_opcode = (line_delta - line_base) + (line_range * (pc_advance / min_inst_len)) + opcode_base
  // If special_opcode <= 255 and line_delta fits within range, emit 1 byte!
  // Otherwise, emits standard DW_LNS_advance_line + DW_LNS_advance_pc + DW_LNS_copy.

  pc_advance = target_pc - builder.curr_pc
  line_delta = target_line - builder.curr_line

  // Handle column update if changed
  @if target_col != builder.curr_col
    builder.opcodes = builder.opcodes.push(DW_LNS_set_column())
    uleb_col = dwarf_encode_uleb128(target_col)
    k = 0 @while k < uleb_col.len() builder.opcodes = builder.opcodes.push(uleb_col[k]) k = k + 1 @end
    builder.curr_col = target_col
  @end

  base = DWARF_LINE_BASE_VAL() // -5
  range_val = DWARF_LINE_RANGE()   // 14
  op_base = DWARF_OPCODE_BASE()    // 13

  // Check if special opcode is valid
  can_use_special = 0
  @if line_delta >= base && line_delta < (base + range_val)
    special_code = (line_delta - base) + (range_val * (pc_advance / builder.min_inst_len)) + op_base
    @if special_code >= op_base && special_code <= 255
      can_use_special = 1
      builder.opcodes = builder.opcodes.push(special_code)
      builder.curr_pc = target_pc
      builder.curr_line = target_line
    @end
  @end

  // If special opcode was not possible, emit explicit sequence
  @if can_use_special == 0
    @if line_delta != 0
      builder = dwarf_line_emit_advance_line(builder, line_delta)
    @end
    @if pc_advance > 0
      builder = dwarf_line_emit_advance_pc(builder, pc_advance)
    @end
    builder = dwarf_line_emit_copy(builder)
  @end

  return builder
@end

@fn dwarf_line_end_sequence(builder, final_pc)
  // WHY: Terminates a contiguous code sequence.
  // Emits PC advance if needed, then DW_LNE_end_sequence (extended opcode 1).
  pc_advance = final_pc - builder.curr_pc
  @if pc_advance > 0
    builder = dwarf_line_emit_advance_pc(builder, pc_advance)
  @end
  builder.opcodes = builder.opcodes.push(DW_LNS_extended_op()) // 0
  builder.opcodes = builder.opcodes.push(1)                    // length = 1
  builder.opcodes = builder.opcodes.push(DW_LNE_end_sequence())// 1
  return builder
@end

// ============================================================================
// 5. SERIALIZATION OF COMPLETE .debug_line SECTION
// ============================================================================

@fn dwarf_line_serialize(builder)
  // WHY: Serializes the complete .debug_line table into binary bytes ready to link.
  //
  // Layout:
  // 1. unit_length (4 bytes): Total bytes following unit_length to end of program
  // 2. version (2 bytes: 4)
  // 3. header_length (4 bytes): Offset from end of header_length to start of opcodes
  // 4. minimum_instruction_length (1 byte: 1)
  // 5. maximum_operations_per_instruction (1 byte: 1)
  // 6. default_is_stmt (1 byte: 1)
  // 7. line_base (1 byte signed: -5 -> 251)
  // 8. line_range (1 byte: 14)
  // 9. opcode_base (1 byte: 13)
  // 10. standard_opcode_lengths (12 bytes: [0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1])
  // 11. include_directories (null-terminated strings ended by 0 byte)
  // 12. file_names (entries of [name\0, dir_idx(ULEB), mtime(ULEB), length(ULEB)] ended by 0 byte)
  // 13. opcodes (byte sequence of line program)

  header_body = []

  // min_instruction_length
  header_body = header_body.push(builder.min_inst_len)
  // max_ops_per_instruction
  header_body = header_body.push(1)
  // default_is_stmt
  header_body = header_body.push(builder.default_is_stmt)
  // line_base (signed -5 = 251)
  header_body = header_body.push(DWARF_LINE_BASE())
  // line_range (14)
  header_body = header_body.push(DWARF_LINE_RANGE())
  // opcode_base (13)
  header_body = header_body.push(DWARF_OPCODE_BASE())

  // standard_opcode_lengths (12 entries for opcodes 1..12)
  std_lens = [0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1]
  k = 0 @while k < 12 header_body = header_body.push(std_lens[k]) k = k + 1 @end

  // include_directories
  i = 0
  num_dirs = builder.include_dirs.len()
  @while i < num_dirs
    d_str = builder.include_dirs[i]
    j = 0
    len_d = d_str.len()
    @while j < len_d
      header_body = header_body.push(str_char_at(d_str, j))
      j = j + 1
    @end
    header_body = header_body.push(0) // Null-terminator for this directory
    i = i + 1
  @end
  header_body = header_body.push(0) // Single null byte terminates directory list

  // file_names
  i = 0
  num_files = builder.file_names.len()
  @while i < num_files
    f_entry = builder.file_names[i]
    fname = f_entry.name
    j = 0
    len_f = fname.len()
    @while j < len_f
      header_body = header_body.push(str_char_at(fname, j))
      j = j + 1
    @end
    header_body = header_body.push(0) // Null terminator

    // dir_idx (ULEB128)
    d_uleb = dwarf_encode_uleb128(f_entry.dir_idx)
    k = 0 @while k < d_uleb.len() header_body = header_body.push(d_uleb[k]) k = k + 1 @end

    // mtime (ULEB128 = 0)
    header_body = header_body.push(0)
    // length (ULEB128 = 0)
    header_body = header_body.push(0)

    i = i + 1
  @end
  header_body = header_body.push(0) // Single null byte terminates file list

  // Calculate header_length: bytes from after header_length field to start of opcodes
  header_length = header_body.len()

  // Calculate unit_length: version(2) + header_length_field(4) + header_body + opcodes
  unit_length = 2 + 4 + header_length + builder.opcodes.len()

  // Assemble full .debug_line payload
  out = []

  // 1. unit_length (4 bytes)
  ul = dwarf_pack_u32(unit_length)
  k = 0 @while k < 4 out = out.push(ul[k]) k = k + 1 @end

  // 2. version (2 bytes)
  ver_bytes = dwarf_pack_u16(builder.version)
  out = out.push(ver_bytes[0]) out = out.push(ver_bytes[1])

  // 3. header_length (4 bytes)
  hl = dwarf_pack_u32(header_length)
  k = 0 @while k < 4 out = out.push(hl[k]) k = k + 1 @end

  // 4. header_body
  k = 0 @while k < header_body.len() out = out.push(header_body[k]) k = k + 1 @end

  // 5. opcodes
  k = 0 @while k < builder.opcodes.len() out = out.push(builder.opcodes[k]) k = k + 1 @end

  return out
@end
