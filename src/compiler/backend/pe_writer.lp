@! ============================================================================
@! MAYA COMPILER BACKEND — 100% PURE MAYA PE32+ (PE64) BINARY EXECUTABLE WRITER
@! Module: compiler/backend/pe_writer.maya
@! Target Architecture: Windows x86-64 (PE32+ / PE64 Executable Format)
@! Zero External Assembler / Linker (MSVC, MinGW, LLD) Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/core/io"

@! ============================================================================
@! 1. CANONICAL ZERO-COLLISION STRUCT SCHEMAS
@! ============================================================================

@struct PeCoffHeader
  ch_machine: i64
  ch_num_sections: i64
  ch_timestamp: i64
  ch_sym_table_ptr: i64
  ch_num_symbols: i64
  ch_opt_header_size: i64
  ch_characteristics: i64
@end

@struct PeOptionalHeader64
  poh_magic: i64
  poh_entry_point: i64
  poh_base_of_code: i64
  poh_image_base: i64
  poh_section_align: i64
  poh_file_align: i64
  poh_size_of_image: i64
  poh_size_of_headers: i64
  poh_subsystem: i64
  poh_dll_characteristics: i64
@end

@struct PeSectionHeader
  psh_name: array
  psh_virtual_size: i64
  psh_virtual_address: i64
  psh_size_of_raw_data: i64
  psh_pointer_to_raw_data: i64
  psh_characteristics: i64
@end

@struct PeWriteResult
  pe_success: i64
  pe_out_path: string
  pe_file_size: i64
  pe_entry_vaddr: i64
  pe_error_msg: string
@end

@struct WordPack
  w0: 0
  w1: 0
  w2: 0
  w3: 0
  w4: 0
  w5: 0
  w6: 0
  w7: 0
@end

@! ============================================================================
@! 2. INTEGER ENCODING & BUFFER UTILITIES
@! ============================================================================

@fn pe_u16_le(v)
  val = v
  @if val < 0
    val = val + 65536
  @end
  return [val % 256, (val / 256) % 256]
@end

@fn pe_u32_le(v)
  val = v
  @if val < 0
    val = val + 4294967296
  @end
  return [
    val % 256,
    (val / 256) % 256,
    (val / 65536) % 256,
    (val / 16777216) % 256
  ]
@end

@fn pe_u64_le(v)
  val = v
  @if val < 0
    val = val + 18446744073709551616
  @end
  bytes = []
  i = 0
  @while i < 8
    bytes = bytes.push(val % 256)
    val = val / 256
    i = i + 1
  @end
  return bytes
@end

@fn pe_append(target, source)
  @if source != 0
    _i_item_0 = 0
    @while _i_item_0 < source.len()
      item = source[_i_item_0]
      target = target.push(item)
      _i_item_0 = _i_item_0 + 1
    @end
  @end
  return target
@end

@fn pe_align_to(val, align)
  rem = val % align
  @if rem != 0
    return val + (align - rem)
  @end
  return val
@end

@! ============================================================================
@! 3. FILE SERIALIZATION ENGINE (Linux Syscalls & Direct File Fallback)
@! ============================================================================

@fn pack_u64_le(bytes_list, start_idx)
  num_items = bytes_list.len()
  val = 0
  mul = 1
  i = 0
  @while i < 8
    curr_idx = start_idx + i
    b = 0
    @if curr_idx < num_items
      b = bytes_list[curr_idx]
    @end
    val = val + ((b % 256) * mul)
    mul = mul * 256
    i = i + 1
  @end
  return val
@end

@fn pe_write_bytes_to_fd(fd, byte_list)
  total = byte_list.len()
  offset = 0
  @while offset < total
    rem = total - offset
    chunk_bytes = rem
    @if chunk_bytes > 64
      chunk_bytes = 64
    @end

    wp = {
      w0: pack_u64_le(byte_list, offset + 0),
      w1: pack_u64_le(byte_list, offset + 8),
      w2: pack_u64_le(byte_list, offset + 16),
      w3: pack_u64_le(byte_list, offset + 24),
      w4: pack_u64_le(byte_list, offset + 32),
      w5: pack_u64_le(byte_list, offset + 40),
      w6: pack_u64_le(byte_list, offset + 48),
      w7: pack_u64_le(byte_list, offset + 56)
    }

    written = sys_write(fd, wp, chunk_bytes)
    @if written < 0
      return written
    @end
    offset = offset + chunk_bytes
  @end
  return total
@end

@fn pe_write_file(output_path, byte_list)
  @! O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577, mode 0755 = 493
  fd = sys_open(output_path, 577, 493)
  @if fd < 0
    return 0 - 1
  @end

  status = pe_write_bytes_to_fd(fd, byte_list)
  sys_close(fd)
  sys_chmod(output_path, 493)
  return status
@end

@! ============================================================================
@! 4. PE HEADER BUILDERS (DOS Header, DOS Stub, COFF, Optional Header, Sections)
@! ============================================================================

@! 64-byte DOS Header (MZ signature at 0x00, e_lfanew at 0x3C = 0x80)
@fn pe_build_dos_header()
  hdr = [
    77, 90,                       @! e_magic = 0x5A4D ('MZ')
    144, 0,                       @! e_cblp = 0x0090
    3, 0,                         @! e_cp = 0x0003
    0, 0,                         @! e_crlc = 0x0000
    4, 0,                         @! e_cparhdr = 0x0004
    0, 0,                         @! e_minalloc = 0x0000
    255, 255,                     @! e_maxalloc = 0xFFFF
    0, 0,                         @! e_ss = 0x0000
    184, 0,                       @! e_sp = 0x00B8
    0, 0,                         @! e_csum = 0x0000
    0, 0,                         @! e_ip = 0x0000
    0, 0,                         @! e_cs = 0x0000
    64, 0,                        @! e_lfarlc = 0x0040
    0, 0                          @! e_ovno = 0x0000
  ]
  @! e_res[4] = 8 bytes zeros
  @while hdr.len() < 36
    hdr = hdr.push(0)
  @end
  @! e_oemid, e_oeminfo (4 bytes)
  hdr = pe_append(hdr, [0, 0, 0, 0])
  @! e_res2[10] = 20 bytes zeros
  @while hdr.len() < 60
    hdr = hdr.push(0)
  @end
  @! e_lfanew at offset 0x3C (60) = 0x00000080 (128 -> PE header offset)
  hdr = pe_append(hdr, pe_u32_le(128))
  return hdr
@end

@! 64-byte DOS Stub ("This program cannot be run in DOS mode.")
@fn pe_build_dos_stub()
  stub = [
    14, 31, 186, 14, 0, 180, 9, 205, 33, 184, 1, 76, 205, 33,
    84, 104, 105, 115, 32, 112, 114, 111, 103, 114, 97, 109, 32,
    99, 97, 110, 110, 111, 116, 32, 98, 101, 32, 114, 117, 110, 32,
    105, 110, 32, 68, 79, 83, 32, 109, 111, 100, 101, 46, 13, 13, 10, 36
  ]
  @! Pad to exactly 64 bytes
  @while stub.len() < 64
    stub = stub.push(0)
  @end
  return stub
@end

@! 20-byte COFF File Header (IMAGE_FILE_HEADER)
@fn pe_build_coff_header(num_sections, timestamp)
  hdr = [
    80, 69, 0, 0                  @! PE Signature: 'PE' (0x00004550)
  ]
  hdr = pe_append(hdr, pe_u16_le(0x8664))        @! Machine: AMD64 (0x8664)
  hdr = pe_append(hdr, pe_u16_le(num_sections))  @! NumberOfSections
  hdr = pe_append(hdr, pe_u32_le(timestamp))     @! TimeDateStamp
  hdr = pe_append(hdr, pe_u32_le(0))             @! PointerToSymbolTable
  hdr = pe_append(hdr, pe_u32_le(0))             @! NumberOfSymbols
  hdr = pe_append(hdr, pe_u16_le(240))           @! SizeOfOptionalHeader: 240 (PE32+)
  hdr = pe_append(hdr, pe_u16_le(0x0022))        @! Characteristics: EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE
  return hdr
@end

@! 240-byte Optional Header (IMAGE_OPTIONAL_HEADER64 for PE32+)
@fn pe_build_optional_header(entry_rva, size_of_code, size_of_init_data, size_of_image, size_of_headers)
  hdr = []
  hdr = pe_append(hdr, pe_u16_le(0x020B))        @! Magic: 0x020B (PE32+)
  hdr = pe_append(hdr, [14, 0])                  @! MajorLinkerVersion (14), MinorLinkerVersion (0)
  hdr = pe_append(hdr, pe_u32_le(size_of_code))  @! SizeOfCode
  hdr = pe_append(hdr, pe_u32_le(size_of_init_data)) @! SizeOfInitializedData
  hdr = pe_append(hdr, pe_u32_le(0))             @! SizeOfUninitializedData
  hdr = pe_append(hdr, pe_u32_le(entry_rva))     @! AddressOfEntryPoint
  hdr = pe_append(hdr, pe_u32_le(0x1000))        @! BaseOfCode (RVA of .text = 0x1000)

  @! ImageBase: 0x140000000 (8 bytes)
  hdr = pe_append(hdr, [0, 0, 0, 64, 1, 0, 0, 0])

  hdr = pe_append(hdr, pe_u32_le(0x1000))        @! SectionAlignment: 0x1000 (4096)
  hdr = pe_append(hdr, pe_u32_le(0x200))         @! FileAlignment: 0x200 (512)
  hdr = pe_append(hdr, pe_u16_le(6))             @! MajorOperatingSystemVersion (6)
  hdr = pe_append(hdr, pe_u16_le(0))             @! MinorOperatingSystemVersion (0)
  hdr = pe_append(hdr, pe_u16_le(0))             @! MajorImageVersion (0)
  hdr = pe_append(hdr, pe_u16_le(0))             @! MinorImageVersion (0)
  hdr = pe_append(hdr, pe_u16_le(6))             @! MajorSubsystemVersion (6)
  hdr = pe_append(hdr, pe_u16_le(0))             @! MinorSubsystemVersion (0)
  hdr = pe_append(hdr, pe_u32_le(0))             @! Win32VersionValue (0)
  hdr = pe_append(hdr, pe_u32_le(size_of_image)) @! SizeOfImage
  hdr = pe_append(hdr, pe_u32_le(size_of_headers)) @! SizeOfHeaders
  hdr = pe_append(hdr, pe_u32_le(0))             @! CheckSum (0)
  hdr = pe_append(hdr, pe_u16_le(3))             @! Subsystem: 3 (IMAGE_SUBSYSTEM_WINDOWS_CUI)
  hdr = pe_append(hdr, pe_u16_le(0x8160))        @! DllCharacteristics: HIGH_ENTROPY_VA | DYNAMIC_BASE | NX_COMPAT | TERMINAL_SERVER_AWARE

  @! SizeOfStackReserve: 0x100000 (1MB)
  hdr = pe_append(hdr, pe_u64_le(1048576))
  @! SizeOfStackCommit: 0x1000 (4KB)
  hdr = pe_append(hdr, pe_u64_le(4096))
  @! SizeOfHeapReserve: 0x100000 (1MB)
  hdr = pe_append(hdr, pe_u64_le(1048576))
  @! SizeOfHeapCommit: 0x1000 (4KB)
  hdr = pe_append(hdr, pe_u64_le(4096))
  hdr = pe_append(hdr, pe_u32_le(0))             @! LoaderFlags (0)
  hdr = pe_append(hdr, pe_u32_le(16))            @! NumberOfRvaAndSizes (16 Data Directories)

  @! 16 Data Directories (16 * 8 = 128 bytes)
  dir_i = 0
  @while dir_i < 16
    hdr = pe_append(hdr, pe_u32_le(0))           @! VirtualAddress (0)
    hdr = pe_append(hdr, pe_u32_le(0))           @! Size (0)
    dir_i = dir_i + 1
  @end

  return hdr
@end

@! 40-byte Section Header (IMAGE_SECTION_HEADER)
@fn pe_build_section_header(name_8bytes, virt_size, virt_addr, raw_size, raw_ptr, characteristics)
  sh = []
  sh = pe_append(sh, name_8bytes)
  sh = pe_append(sh, pe_u32_le(virt_size))
  sh = pe_append(sh, pe_u32_le(virt_addr))
  sh = pe_append(sh, pe_u32_le(raw_size))
  sh = pe_append(sh, pe_u32_le(raw_ptr))
  sh = pe_append(sh, pe_u32_le(0))               @! PointerToRelocations
  sh = pe_append(sh, pe_u32_le(0))               @! PointerToLinenumbers
  sh = pe_append(sh, pe_u16_le(0))               @! NumberOfRelocations
  sh = pe_append(sh, pe_u16_le(0))               @! NumberOfLinenumbers
  sh = pe_append(sh, pe_u32_le(characteristics))
  return sh
@end

@! ============================================================================
@! 5. PRIMARY API: pe_write_executable(x86_res, output_path)
@! ============================================================================

@fn pe_write_executable(x86_res, output_path)
  @! 1. Extract Machine Code & Read-Only Data
  text_src = []
  rodata_src = []
  data_src = []
  entry_off = 0

  @if x86_res != 0
    @if x86_res.text_bytes != 0
      text_src = x86_res.text_bytes
    @elif x86_res.num_items != 0 && x86_res.len() > 0
      @! x86_res passed directly as array of bytes
      text_src = x86_res
    @end
    @if x86_res.rodata_bytes != 0
      rodata_src = x86_res.rodata_bytes
    @end
    @if x86_res.data_bytes != 0
      data_src = x86_res.data_bytes
    @end
    @if x86_res.entry_offset != 0
      entry_off = x86_res.entry_offset
    @end
  @end

  @! Ensure .text is at least 1 byte
  @if text_src.len() == 0
    text_src = [144, 195] @! NOP, RET
  @end

  text_raw_len = text_src.len()
  text_virt_size = text_raw_len
  text_raw_size = pe_align_to(text_raw_len, 0x200)

  rodata_raw_len = rodata_src.len()
  rodata_virt_size = rodata_raw_len
  rodata_raw_size = pe_align_to(rodata_raw_len, 0x200)

  data_raw_len = data_src.len()
  data_virt_size = data_raw_len
  data_raw_size = pe_align_to(data_raw_len, 0x200)

  num_sections = 1
  @if rodata_raw_len > 0
    num_sections = num_sections + 1
  @end
  @if data_raw_len > 0
    num_sections = num_sections + 1
  @end

  @! 2. Calculate Layout & Offsets
  @! DOS Header (64) + DOS Stub (64) + PE Sig (4) + COFF (20) + Opt Header (240) + Section Headers (40 * num_sections)
  headers_unpadded = 128 + 24 + 240 + (num_sections * 40)
  size_of_headers = pe_align_to(headers_unpadded, 0x200) @! 0x400 (1024 bytes)

  text_vaddr = 0x1000
  text_raw_ptr = size_of_headers

  current_vaddr = text_vaddr + pe_align_to(text_virt_size, 0x1000)
  current_raw_ptr = text_raw_ptr + text_raw_size

  rodata_vaddr = 0
  rodata_raw_ptr = 0
  @if rodata_raw_len > 0
    rodata_vaddr = current_vaddr
    rodata_raw_ptr = current_raw_ptr
    current_vaddr = current_vaddr + pe_align_to(rodata_virt_size, 0x1000)
    current_raw_ptr = current_raw_ptr + rodata_raw_size
  @end

  data_vaddr = 0
  data_raw_ptr = 0
  @if data_raw_len > 0
    data_vaddr = current_vaddr
    data_raw_ptr = current_raw_ptr
    current_vaddr = current_vaddr + pe_align_to(data_virt_size, 0x1000)
    current_raw_ptr = current_raw_ptr + data_raw_size
  @end

  size_of_image = current_vaddr
  size_of_code = text_raw_size
  size_of_init_data = rodata_raw_size + data_raw_size
  entry_point_rva = text_vaddr + entry_off

  @! 3. Build All Headers
  dos_header = pe_build_dos_header()
  dos_stub = pe_build_dos_stub()
  coff_header = pe_build_coff_header(num_sections, 0)
  opt_header = pe_build_optional_header(entry_point_rva, size_of_code, size_of_init_data, size_of_image, size_of_headers)

  @! Section Headers
  @! .text
  sec_name_text = [46, 116, 101, 120, 116, 0, 0, 0]
  sec_text = pe_build_section_header(sec_name_text, text_virt_size, text_vaddr, text_raw_size, text_raw_ptr, 0x60000020)

  sec_rodata = []
  @if rodata_raw_len > 0
    @! .rdata
    sec_name_rodata = [46, 114, 100, 97, 116, 97, 0, 0]
    sec_rodata = pe_build_section_header(sec_name_rodata, rodata_virt_size, rodata_vaddr, rodata_raw_size, rodata_raw_ptr, 0x40000040)
  @end

  sec_data = []
  @if data_raw_len > 0
    @! .data
    sec_name_data = [46, 100, 97, 116, 97, 0, 0, 0]
    sec_data = pe_build_section_header(sec_name_data, data_virt_size, data_vaddr, data_raw_size, data_raw_ptr, 0xC0000040)
  @end

  @! 4. Assemble Complete Binary Byte Vector
  final_bin = []
  final_bin = pe_append(final_bin, dos_header)
  final_bin = pe_append(final_bin, dos_stub)
  final_bin = pe_append(final_bin, coff_header)
  final_bin = pe_append(final_bin, opt_header)
  final_bin = pe_append(final_bin, sec_text)
  @if rodata_raw_len > 0
    final_bin = pe_append(final_bin, sec_rodata)
  @end
  @if data_raw_len > 0
    final_bin = pe_append(final_bin, sec_data)
  @end

  @! Pad headers to size_of_headers (0x400)
  @while final_bin.len() < size_of_headers
    final_bin = final_bin.push(0)
  @end

  @! Write .text Section Bytes
  final_bin = pe_append(final_bin, text_src)
  @! Pad .text to text_raw_size
  @while final_bin.len() < text_raw_ptr + text_raw_size
    final_bin = final_bin.push(144) @! NOP (0x90) padding for code
  @end

  @! Write .rdata Section Bytes (if present)
  @if rodata_raw_len > 0
    final_bin = pe_append(final_bin, rodata_src)
    @while final_bin.len() < rodata_raw_ptr + rodata_raw_size
      final_bin = final_bin.push(0)
    @end
  @end

  @! Write .data Section Bytes (if present)
  @if data_raw_len > 0
    final_bin = pe_append(final_bin, data_src)
    @while final_bin.len() < data_raw_ptr + data_raw_size
      final_bin = final_bin.push(0)
    @end
  @end

  @! 5. Write to Disk
  write_status = pe_write_file(output_path, final_bin)
  @if write_status < 0
    return {
      pe_success: 0,
      pe_out_path: output_path,
      pe_file_size: 0,
      pe_entry_vaddr: 0,
      pe_error_msg: "Failed to write PE binary to disk: " + output_path
    }
  @end

  return {
    pe_success: 1,
    pe_out_path: output_path,
    pe_file_size: final_bin.len(),
    pe_entry_vaddr: 0x140000000 + entry_point_rva,
    pe_error_msg: ""
  }
@end

@! Convenience Wrapper
@fn emit_pe_64_executable(output_path, machine_code_bytes)
  res = pe_write_executable({ text_bytes: machine_code_bytes, rodata_bytes: [], data_bytes: [], entry_offset: 0 }, output_path)
  @if res.pe_success == 1
    return 1
  @end
  return 0
@end

@fn write_pe64_executable(machine_code_bytes, output_path)
  @! WHY: Thin wrapper alias matching other backend naming conventions (e.g. write_macho64_executable)
  return emit_pe_64_executable(output_path, machine_code_bytes)
@end
