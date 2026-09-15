// ============================================================================
// LIPI SOVEREIGN COMPILER — MACH-O 64-BIT BINARY EXECUTABLE WRITER
// Module: src/compiler/backend/formats/macho/macho_writer.lp
// Standard: Apple macOS Mach-O 64 (x86_64 and ARM64 / Apple Silicon)
// Permissions: Mode 0755
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"

import "src/compiler/backend/formats/macho/load_commands.lp"

// WHY: Mach-O binaries use an integrated segment architecture where the
// __TEXT segment maps both the file headers (mach_header_64, load commands)
// and executable code (__text section) starting at virtual address 0x100000000.
// This writer computes the exact header sizing, pads sections to page alignment,
// and outputs clean freestanding native Mach-O 64 executables.

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct MachOWriteResult
  mw_success: i64      // 1 on success, 0 on failure
  mw_out_path: string  // Output file path
  mw_file_size: i64    // Total byte count written to disk
  mw_entry_vaddr: i64  // Absolute virtual memory entry address
  mw_error_msg: string // Error description if any
  mw_bytes: array      // Serialized binary bytes
@end

// ============================================================================
// 2. BUFFER HELPERS
// ============================================================================

@fn macho_concat(target, source)
  i = 0
  n = source.len()
  @while i < n
    target = target.push(source[i])
    i = i + 1
  @end
  return target
@end

@fn macho_pad_to(bytes_list, target_alignment)
  @if target_alignment <= 1 return bytes_list @end
  rem = bytes_list.len() % target_alignment
  @if rem != 0
    pad_needed = target_alignment - rem
    k = 0
    @while k < pad_needed
      bytes_list = bytes_list.push(0)
      k = k + 1
    @end
  @end
  return bytes_list
@end

// ============================================================================
// 3. LOW-LEVEL DIRECT SYSCALL BINARY DISK SERIALIZER
// ============================================================================

@fn macho_write_to_disk(output_path, byte_list)
  // WHY: Writes raw binary bytes directly to disk via Linux/Darwin compatible syscalls.
  // Sets file access mode to 0755 (493 decimal) for executable execution.
  total = byte_list.len()
  @if total <= 0 return 0 - 1 @end

  fd = sys_open(output_path, 577, 493) // O_WRONLY | O_CREAT | O_TRUNC = 577, 0755
  @if fd < 0
    return 0 - 1
  @end

  buf = sys_mmap(0, total + 16, 3, 34, 0 - 1, 0)
  @if buf <= 0
    sys_close(fd)
    return 0 - 2
  @end

  i = 0
  @while i < total
    sys_poke8(buf + i, byte_list[i])
    i = i + 1
  @end

  written = sys_write(fd, buf, total)
  sys_close(fd)

  sys_chmod(output_path, 493) // 0755

  return written
@end

// ============================================================================
// 4. MACH-O 64 EXECUTABLE EMITTER
// ============================================================================

@fn macho_emit_executable(code_bytes, data_bytes, bss_size, cputype, output_path)
  // WHY: Comprehensive Mach-O 64 binary generator.
  // Supported architectures:
  //   - CPU_TYPE_X86_64 (16777223)
  //   - CPU_TYPE_ARM64  (16777228)
  //
  // Memory Layout:
  // 1. [0x000000000 .. 0x0FFFFFFFF]: __PAGEZERO (4GB protected zone)
  // 2. [0x100000000 .. text_end]:   __TEXT Segment (Header + Cmds + __text)
  // 3. [data_start  .. data_end]:   __DATA Segment (__data + __bss)

  page_size = 4096

  // 1. Calculate Load Commands Size
  // Header: 32 bytes
  // Cmd 1: __PAGEZERO segment command = 72 bytes
  // Cmd 2: __TEXT segment command with 1 section (__text) = 72 + 80 = 152 bytes
  // Cmd 3: LC_MAIN command = 24 bytes
  // Optional Cmd 4: __DATA segment command with 2 sections (__data, __bss) = 72 + 80 + 80 = 232 bytes (if data or bss exists)

  has_data = 0
  @if data_bytes.len() > 0 || bss_size > 0
    has_data = 1
  @end

  ncmds = 3
  sizeofcmds = 72 + 152 + 24 // PAGEZERO (72) + TEXT (152) + LC_MAIN (24) = 248 bytes
  @if has_data == 1
    ncmds = 4
    sizeofcmds = sizeofcmds + 232 // DATA (232)
  @end

  header_and_cmds_size = 32 + sizeofcmds

  // Align __text section offset to 16 bytes
  text_offset = header_and_cmds_size
  rem16 = text_offset % 16
  @if rem16 != 0
    text_offset = text_offset + (16 - rem16)
  @end

  text_size = code_bytes.len()
  text_vmaddr = 4294967296 + text_offset // 0x100000000 + text_offset
  entry_vaddr = text_vmaddr

  // Size of __TEXT in file and memory (aligned to 4KB page)
  text_file_end = text_offset + text_size
  text_vmsize = text_file_end
  rem_page = text_vmsize % page_size
  @if rem_page != 0
    text_vmsize = text_vmsize + (page_size - rem_page)
  @end

  // 2. Configure __DATA Segment (if present)
  data_offset = text_vmsize
  data_size = data_bytes.len()
  data_vmaddr = 4294967296 + text_vmsize
  data_vmsize = data_size + bss_size
  rem_dpage = data_vmsize % page_size
  @if rem_dpage != 0
    data_vmsize = data_vmsize + (page_size - rem_dpage)
  @end

  // 3. Build Mach-O Header
  m_hdr = macho_header_create(cputype, ncmds, sizeofcmds)
  hdr_bytes = macho_header_serialize(m_hdr) // 32 bytes

  // 4. Build Load Commands
  // Cmd 1: __PAGEZERO
  seg_pagezero = macho_segment_pagezero()
  cmd_pagezero_bytes = macho_segment_header_serialize(seg_pagezero) // 72 bytes

  // Cmd 2: __TEXT
  seg_text = macho_segment_text(text_vmsize, text_file_end, 1)
  cmd_text_header_bytes = macho_segment_header_serialize(seg_text) // 72 bytes
  sec_text = macho_section_text(text_vmaddr, text_size, text_offset)
  sec_text_bytes = macho_section_serialize(sec_text) // 80 bytes

  // Cmd 3: LC_MAIN
  lc_main = macho_lc_main_create(text_offset, 0)
  lc_main_bytes = macho_lc_main_serialize(lc_main) // 24 bytes

  // Optional Cmd 4: __DATA
  cmd_data_bytes = []
  @if has_data == 1
    seg_data = macho_segment_data(data_vmaddr, data_vmsize, data_offset, data_size, 2)
    cmd_data_hdr = macho_segment_header_serialize(seg_data) // 72 bytes
    sec_data = macho_section_data(data_vmaddr, data_size, data_offset)
    sec_data_bytes = macho_section_serialize(sec_data) // 80 bytes
    sec_bss = macho_section_bss(data_vmaddr + data_size, bss_size)
    sec_bss_bytes = macho_section_serialize(sec_bss) // 80 bytes

    cmd_data_bytes = macho_concat(cmd_data_bytes, cmd_data_hdr)
    cmd_data_bytes = macho_concat(cmd_data_bytes, sec_data_bytes)
    cmd_data_bytes = macho_concat(cmd_data_bytes, sec_bss_bytes)
  @end

  // 5. Assemble Binary Stream
  binary = []
  binary = macho_concat(binary, hdr_bytes)
  binary = macho_concat(binary, cmd_pagezero_bytes)
  binary = macho_concat(binary, cmd_text_header_bytes)
  binary = macho_concat(binary, sec_text_bytes)
  binary = macho_concat(binary, lc_main_bytes)
  @if has_data == 1
    binary = macho_concat(binary, cmd_data_bytes)
  @end

  // Pad up to text_offset
  @while binary.len() < text_offset
    binary = binary.push(0)
  @end

  // Append __text machine code
  binary = macho_concat(binary, code_bytes)

  // Append __DATA if present
  @if has_data == 1
    // Pad to data_offset (4KB page boundary)
    @while binary.len() < data_offset
      binary = binary.push(0)
    @end
    binary = macho_concat(binary, data_bytes)
  @end

  // 6. Write to disk
  written = macho_write_to_disk(output_path, binary)
  @if written < 0
    return {
      mw_success: 0,
      mw_out_path: output_path,
      mw_file_size: 0,
      mw_entry_vaddr: entry_vaddr,
      mw_error_msg: "Failed to write Mach-O 64 binary to filesystem",
      mw_bytes: binary
    }
  @end

  return {
    mw_success: 1,
    mw_out_path: output_path,
    mw_file_size: binary.len(),
    mw_entry_vaddr: entry_vaddr,
    mw_error_msg: "",
    mw_bytes: binary
  }
@end
