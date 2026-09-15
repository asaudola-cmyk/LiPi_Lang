// ============================================================================
// LIPI SOVEREIGN COMPILER — WINDOWS PE64 (.EXE) BINARY WRITER
// Module: src/compiler/backend/formats/pe/pe_writer.lp
// Standard: Microsoft Windows x86-64 Portable Executable (PE32+)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"

import "src/compiler/backend/formats/pe/dos_header.lp"
import "src/compiler/backend/formats/pe/coff_header.lp"

// WHY: On Windows systems, executables require the PE32+ (64-bit) container format.
// The Windows kernel loader (ntdll.dll / LdrpInitializeProcess) maps sections into
// virtual memory according to the RVAs (Relative Virtual Addresses) and SectionAlignment (4KB),
// while disk images are aligned to FileAlignment (512 bytes).
// This module provides a complete, freestanding PE64 emitter producing valid .exe files.

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct PeWriteResult
  pe_success: i64      // 1 on success, 0 on failure
  pe_out_path: string  // Target file path
  pe_file_size: i64    // Total byte count written
  pe_entry_vaddr: i64  // Full virtual address of entry point (ImageBase + EntryRVA)
  pe_error_msg: string // Diagnostic error message
  pe_bytes: array      // Serialized binary bytes
@end

// ============================================================================
// 2. BUFFER HELPERS
// ============================================================================

@fn pe_concat(target, source)
  i = 0
  n = source.len()
  @while i < n
    target = target.push(source[i])
    i = i + 1
  @end
  return target
@end

@fn pe_pad_zeros(bytes_list, target_len)
  @while bytes_list.len() < target_len
    bytes_list = bytes_list.push(0)
  @end
  return bytes_list
@end

// ============================================================================
// 3. LOW-LEVEL DISK SERIALIZER VIA SYSCALLS
// ============================================================================

@fn pe_write_to_disk(output_path, byte_list)
  // WHY: Directly writes the PE64 .exe payload to disk via pure syscalls.
  // Sets file permissions to 0755 (493 decimal) for execution support.
  total = byte_list.len()
  @if total <= 0 return 0 - 1 @end

  fd = sys_open(output_path, 577, 493) // O_WRONLY | O_CREAT | O_TRUNC = 577
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
// 4. PE64 (.EXE) BINARY EMITTER
// ============================================================================

@fn pe_emit_executable(code_bytes, rdata_bytes, data_bytes, bss_size, is_gui, output_path)
  // WHY: Assembles a complete Windows 64-bit console or GUI executable (.exe).
  // 1. Memory Configuration:
  //    ImageBase:        0x140000000 (5368709120)
  //    SectionAlignment: 4096 (0x1000)
  //    FileAlignment:    512  (0x200)
  // 2. Sections:
  //    .text  (Code)
  //    .rdata (Read-only constants / strings)
  //    .data  (Mutable globals)

  file_align = 512
  sect_align = 4096
  image_base = 5368709120 // 0x140000000

  // Determine active sections
  has_rdata = 0
  @if rdata_bytes.len() > 0
    has_rdata = 1
  @end

  has_data = 0
  @if data_bytes.len() > 0 || bss_size > 0
    has_data = 1
  @end

  num_sections = 1 // At least .text
  @if has_rdata == 1 num_sections = num_sections + 1 @end
  @if has_data == 1  num_sections = num_sections + 1 @end

  // Calculate SizeOfHeaders:
  // DOS Header + Stub = 128 bytes
  // PE Signature      = 4 bytes
  // COFF Header       = 20 bytes
  // Optional Header   = 240 bytes
  // Section Headers   = num_sections * 40 bytes
  // Total raw headers = 128 + 4 + 20 + 240 + (num_sections * 40) = 392 + (num_sections * 40)
  raw_headers_size = 392 + (num_sections * 40)
  size_of_headers = pe_align_to(raw_headers_size, file_align) // 512 bytes

  // Section 1: .text (Code)
  text_vsize = code_bytes.len()
  text_rva = sect_align // 0x1000
  text_raw_size = pe_align_to(text_vsize, file_align)
  text_raw_ptr = size_of_headers
  entry_point_rva = text_rva
  entry_vaddr = image_base + entry_point_rva

  // Section 2: .rdata (if present)
  rdata_vsize = rdata_bytes.len()
  rdata_rva = text_rva + pe_align_to(text_vsize, sect_align)
  rdata_raw_size = pe_align_to(rdata_vsize, file_align)
  rdata_raw_ptr = text_raw_ptr + text_raw_size

  // Section 3: .data (if present)
  data_vsize = data_bytes.len() + bss_size
  data_rva = rdata_rva
  data_raw_ptr = rdata_raw_ptr
  @if has_rdata == 1
    data_rva = rdata_rva + pe_align_to(rdata_vsize, sect_align)
    data_raw_ptr = rdata_raw_ptr + rdata_raw_size
  @else
    data_rva = text_rva + pe_align_to(text_vsize, sect_align)
    data_raw_ptr = text_raw_ptr + text_raw_size
  @end
  data_raw_size = pe_align_to(data_bytes.len(), file_align)

  // Calculate Total SizeOfImage (RVA extent aligned to sect_align)
  last_rva = data_rva
  last_vsize = data_vsize
  @if has_data == 0
    @if has_rdata == 1
      last_rva = rdata_rva
      last_vsize = rdata_vsize
    @else
      last_rva = text_rva
      last_vsize = text_vsize
    @end
  @end
  size_of_image = last_rva + pe_align_to(last_vsize, sect_align)

  // 1. Build DOS Block (128 bytes)
  dos_block = pe_dos_block_serialize()

  // 2. Build PE Signature (4 bytes)
  pe_sig = pe_signature_bytes()

  // 3. Build COFF Header (20 bytes)
  coff_hdr = pe_coff_header_create(IMAGE_FILE_MACHINE_AMD64(), num_sections)
  coff_bytes = pe_coff_header_serialize(coff_hdr)

  // 4. Build Optional Header 64 (240 bytes)
  opt_hdr = pe_optional_header64_create(
    entry_point_rva,
    text_rva,
    text_raw_size,
    rdata_raw_size + data_raw_size,
    bss_size,
    size_of_image,
    size_of_headers,
    is_gui
  )
  opt_bytes = pe_optional_header64_serialize(opt_hdr)

  // 5. Build Section Headers
  sec_text = pe_section_text_create(text_vsize, text_rva, text_raw_size, text_raw_ptr)
  sec_text_bytes = pe_section_header_serialize(sec_text)

  sec_rdata_bytes = []
  @if has_rdata == 1
    sec_rdata = pe_section_rdata_create(rdata_vsize, rdata_rva, rdata_raw_size, rdata_raw_ptr)
    sec_rdata_bytes = pe_section_header_serialize(sec_rdata)
  @end

  sec_data_bytes = []
  @if has_data == 1
    sec_data = pe_section_data_create(data_vsize, data_rva, data_raw_size, data_raw_ptr)
    sec_data_bytes = pe_section_header_serialize(sec_data)
  @end

  // 6. Assemble Headers Block
  headers_blob = []
  headers_blob = pe_concat(headers_blob, dos_block)
  headers_blob = pe_concat(headers_blob, pe_sig)
  headers_blob = pe_concat(headers_blob, coff_bytes)
  headers_blob = pe_concat(headers_blob, opt_bytes)
  headers_blob = pe_concat(headers_blob, sec_text_bytes)
  @if has_rdata == 1
    headers_blob = pe_concat(headers_blob, sec_rdata_bytes)
  @end
  @if has_data == 1
    headers_blob = pe_concat(headers_blob, sec_data_bytes)
  @end

  // Pad headers to FileAlignment (512 bytes)
  headers_blob = pe_pad_zeros(headers_blob, size_of_headers)

  // 7. Assemble Complete Binary File
  binary = []
  binary = pe_concat(binary, headers_blob)

  // Append .text data (padded to text_raw_size)
  text_blob = []
  text_blob = pe_concat(text_blob, code_bytes)
  text_blob = pe_pad_zeros(text_blob, text_raw_size)
  binary = pe_concat(binary, text_blob)

  // Append .rdata data (if present, padded to rdata_raw_size)
  @if has_rdata == 1
    rdata_blob = []
    rdata_blob = pe_concat(rdata_blob, rdata_bytes)
    rdata_blob = pe_pad_zeros(rdata_blob, rdata_raw_size)
    binary = pe_concat(binary, rdata_blob)
  @end

  // Append .data data (if present, padded to data_raw_size)
  @if has_data == 1
    data_blob = []
    data_blob = pe_concat(data_blob, data_bytes)
    data_blob = pe_pad_zeros(data_blob, data_raw_size)
    binary = pe_concat(binary, data_blob)
  @end

  // 8. Write to disk
  written = pe_write_to_disk(output_path, binary)
  @if written < 0
    return {
      pe_success: 0,
      pe_out_path: output_path,
      pe_file_size: 0,
      pe_entry_vaddr: entry_vaddr,
      pe_error_msg: "Failed to write PE64 binary to filesystem",
      pe_bytes: binary
    }
  @end

  return {
    pe_success: 1,
    pe_out_path: output_path,
    pe_file_size: binary.len(),
    pe_entry_vaddr: entry_vaddr,
    pe_error_msg: "",
    pe_bytes: binary
  }
@end
