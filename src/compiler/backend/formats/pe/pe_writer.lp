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

@struct PeIdataInfo
  pi_idata_bytes: array        // Complete serialized bytes of .idata section
  pi_import_dir_rva: i64       // Relative Virtual Address of IMAGE_IMPORT_DESCRIPTOR array
  pi_import_dir_size: i64      // Size in bytes of import descriptor array
  pi_iat_rva: i64              // Relative Virtual Address of Import Address Table (IAT)
  pi_iat_size: i64             // Size in bytes of IAT array
  pi_exit_process_iat_rva: i64 // RVA of the ExitProcess slot within the IAT
  pi_get_std_handle_iat_rva: i64 // RVA of the GetStdHandle slot within the IAT
  pi_write_file_iat_rva: i64   // RVA of the WriteFile slot within the IAT
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
  @if output_path == "" return total @end

  sys_unlink(output_path)
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
// 4. WINDOWS PE64 KERNEL32 IAT & IMPORT DIRECTORY BUILDER
// ============================================================================

@fn pe_build_kernel32_idata(idata_rva)
  // WHY: Constructs a bit-perfect Microsoft PE32+ .idata (Import Table) section for KERNEL32.DLL:
  // Layout within .idata:
  // 1. [Offset 0x00 .. 0x27]: Import Directory Table (2 x IMAGE_IMPORT_DESCRIPTOR: KERNEL32 + null terminator = 40 bytes)
  // 2. [Offset 0x28 .. 0x47]: Import Lookup Table / INT (4 x 64-bit thunks: ExitProcess, GetStdHandle, WriteFile, null = 32 bytes)
  // 3. [Offset 0x48 .. 0x67]: Import Address Table / IAT (4 x 64-bit thunks: ExitProcess, GetStdHandle, WriteFile, null = 32 bytes)
  // 4. [Offset 0x68 .. 0x75]: Hint/Name for ExitProcess (Hint: 2 bytes, Name: 12 bytes = 14 bytes)
  // 5. [Offset 0x76 .. 0x85]: Hint/Name for GetStdHandle (Hint: 2 bytes, Name: 13 bytes + 1 pad = 16 bytes)
  // 6. [Offset 0x86 .. 0x91]: Hint/Name for WriteFile (Hint: 2 bytes, Name: 10 bytes = 12 bytes)
  // 7. [Offset 0x92 .. 0x9F]: DLL Name "KERNEL32.dll\0" (13 bytes + 1 pad = 14 bytes)
  // Total raw size: 160 bytes.
  import_dir_rva = idata_rva
  import_dir_size = 40
  ilt_rva = idata_rva + 40
  ilt_size = 32
  iat_rva = idata_rva + 72
  iat_size = 32

  hint_exit_rva = idata_rva + 104
  hint_getstd_rva = idata_rva + 118
  hint_write_rva = idata_rva + 134
  dll_name_rva = idata_rva + 146

  // 1. KERNEL32.DLL Import Descriptor (20 bytes)
  desc_k32 = ImageImportDescriptor()
  desc_k32.iid_original_first_thunk = ilt_rva
  desc_k32.iid_time_date_stamp = 0
  desc_k32.iid_forwarder_chain = 0
  desc_k32.iid_name_rva = dll_name_rva
  desc_k32.iid_first_thunk = iat_rva
  k32_bytes = pe_import_descriptor_serialize(desc_k32)

  // 2. Null Terminator Descriptor (20 bytes)
  null_desc = pe_import_descriptor_null()
  null_bytes = pe_import_descriptor_serialize(null_desc)

  // 3. ILT (Import Lookup Table) entries (32 bytes)
  ilt_bytes = []
  e0 = pe_pack_u64(hint_exit_rva)
  ilt_bytes = pe_concat(ilt_bytes, e0)
  e1 = pe_pack_u64(hint_getstd_rva)
  ilt_bytes = pe_concat(ilt_bytes, e1)
  e2 = pe_pack_u64(hint_write_rva)
  ilt_bytes = pe_concat(ilt_bytes, e2)
  e3 = pe_pack_u64(0)
  ilt_bytes = pe_concat(ilt_bytes, e3)

  // 4. IAT (Import Address Table) entries (32 bytes)
  iat_bytes = []
  iat_bytes = pe_concat(iat_bytes, e0)
  iat_bytes = pe_concat(iat_bytes, e1)
  iat_bytes = pe_concat(iat_bytes, e2)
  iat_bytes = pe_concat(iat_bytes, e3)

  // 5. Hint/Name Table (14 + 16 + 12 = 42 bytes)
  hints_bytes = [
    0, 0, 69, 120, 105, 116, 80, 114, 111, 99, 101, 115, 115, 0,
    0, 0, 71, 101, 116, 83, 116, 100, 72, 97, 110, 100, 108, 101, 0, 0,
    0, 0, 87, 114, 105, 116, 101, 70, 105, 108, 101, 0
  ]

  // 6. DLL Name ASCII string "KERNEL32.dll\0" padded to even boundary (14 bytes)
  dll_bytes = [
    75, 69, 82, 78, 69, 76, 51, 50, 46, 100, 108, 108, 0, 0
  ]

  all_bytes = []
  all_bytes = pe_concat(all_bytes, k32_bytes)
  all_bytes = pe_concat(all_bytes, null_bytes)
  all_bytes = pe_concat(all_bytes, ilt_bytes)
  all_bytes = pe_concat(all_bytes, iat_bytes)
  all_bytes = pe_concat(all_bytes, hints_bytes)
  all_bytes = pe_concat(all_bytes, dll_bytes)

  info = PeIdataInfo()
  info.pi_idata_bytes = all_bytes
  info.pi_import_dir_rva = import_dir_rva
  info.pi_import_dir_size = import_dir_size
  info.pi_iat_rva = iat_rva
  info.pi_iat_size = iat_size
  info.pi_exit_process_iat_rva = iat_rva + 0
  info.pi_get_std_handle_iat_rva = iat_rva + 8
  info.pi_write_file_iat_rva = iat_rva + 16
  return info
@end

// ============================================================================
// 5. WINDOWS X64 ENTRY BOOTSTRAP STUB
// ============================================================================

@fn pe_build_start_stub(main_entry_offset, exit_process_iat_rva, text_rva)
  // WHY: Windows x64 process entry bootstrap stub (64 bytes).
  // Conforms strictly to Microsoft x64 calling convention:
  // 1. sub rsp, 40                [0x48, 0x83, 0xEC, 0x28] (4 bytes: align stack & shadow space)
  // 2. call rel32                 [0xE8, d0, d1, d2, d3]   (5 bytes: call user main)
  // 3. mov ecx, eax               [0x89, 0xC1]             (2 bytes: copy exit code to ecx)
  // 4. call [rip + disp32]        [0xFF, 0x15, d0, d1, d2, d3] (6 bytes: call ExitProcess in IAT)
  // 5. add rsp, 40                [0x48, 0x83, 0xC4, 0x28] (4 bytes: clean shadow frame)
  // 6. ret                        [0xC3]                   (1 byte: return)
  // 7. int3                       [0xCC]                   (1 byte: trap)
  // 8. NOPs (0x90) up to 64 bytes total
  stub = []
  // 1. sub rsp, 40
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(236) stub = stub.push(40)

  // 2. call rel32 (target is at text_rva + 64 + main_entry_offset; rip after call is text_rva + 9)
  rel32 = (64 + main_entry_offset) - 9
  cd = pe_pack_u32(rel32)
  stub = stub.push(232)
  stub = stub.push(cd[0]) stub = stub.push(cd[1]) stub = stub.push(cd[2]) stub = stub.push(cd[3])

  // 3. mov ecx, eax
  stub = stub.push(137) stub = stub.push(193)

  // 4. call qword ptr [rip + disp32] (call ExitProcess through IAT)
  disp32 = exit_process_iat_rva - (text_rva + 17)
  id = pe_pack_u32(disp32)
  stub = stub.push(255) stub = stub.push(21)
  stub = stub.push(id[0]) stub = stub.push(id[1]) stub = stub.push(id[2]) stub = stub.push(id[3])

  // 5. add rsp, 40
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(196) stub = stub.push(40)

  // 6. ret
  stub = stub.push(195)

  // 7. int3
  stub = stub.push(204)

  // 8. Pad with NOPs to 64 bytes
  @while stub.len() < 64
    stub = stub.push(144)
  @end

  return stub
@end

// ============================================================================
// 6. PE64 (.EXE) BINARY EMITTER
// ============================================================================

@fn pe_emit_executable(code_bytes, rdata_bytes, data_bytes, bss_size, is_gui, output_path)
  // WHY: Assembles a complete Windows 64-bit console or GUI executable (.exe)
  // with standalone native dynamic linking to KERNEL32.DLL (ExitProcess, GetStdHandle, WriteFile)
  // via bit-perfect Import Directory and Import Address Table (IAT).
  // Zero external linkers required (0% ld, 0% link.exe).
  file_align = 512
  sect_align = 4096
  image_base = 5368709120 // 0x140000000

  // 1. Determine active sections
  has_rdata = 0
  @if rdata_bytes.len() > 0 has_rdata = 1 @end

  has_data = 0
  @if data_bytes.len() > 0 || bss_size > 0 has_data = 1 @end

  // Sections: .text, optional .rdata, optional .data, mandatory .idata (for KERNEL32 IAT)
  num_sections = 2 // .text + .idata
  @if has_rdata == 1 num_sections = num_sections + 1 @end
  @if has_data == 1  num_sections = num_sections + 1 @end

  raw_headers_size = 392 + (num_sections * 40)
  size_of_headers = pe_align_to(raw_headers_size, file_align)

  // 2. Compute Memory Layout & RVAs
  // Section 1: .text (Start stub + User code)
  stub_len = 64
  user_code = code_bytes
  @if user_code.len() == 0
    user_code = [72, 49, 192, 195] // xor rax, rax; ret
  @end
  text_vsize = stub_len + user_code.len()
  text_rva = sect_align // 0x1000
  text_raw_size = pe_align_to(text_vsize, file_align)
  text_raw_ptr = size_of_headers
  entry_point_rva = text_rva
  entry_vaddr = image_base + entry_point_rva

  next_rva = text_rva + pe_align_to(text_vsize, sect_align)
  next_ptr = text_raw_ptr + text_raw_size

  // Section 2: .rdata (if present)
  rdata_rva = next_rva
  rdata_raw_ptr = next_ptr
  rdata_vsize = rdata_bytes.len()
  rdata_raw_size = pe_align_to(rdata_vsize, file_align)
  @if has_rdata == 1
    next_rva = rdata_rva + pe_align_to(rdata_vsize, sect_align)
    next_ptr = rdata_raw_ptr + rdata_raw_size
  @end

  // Section 3: .data (if present)
  data_rva = next_rva
  data_raw_ptr = next_ptr
  data_vsize = data_bytes.len() + bss_size
  data_raw_size = pe_align_to(data_bytes.len(), file_align)
  @if has_data == 1
    next_rva = data_rva + pe_align_to(data_vsize, sect_align)
    next_ptr = data_raw_ptr + data_raw_size
  @end

  // Section 4: .idata (Import Directory Table + IAT for KERNEL32.DLL)
  idata_rva = next_rva
  idata_raw_ptr = next_ptr
  idata_info = pe_build_kernel32_idata(idata_rva)
  idata_vsize = idata_info.pi_idata_bytes.len()
  idata_raw_size = pe_align_to(idata_vsize, file_align)
  next_rva = idata_rva + pe_align_to(idata_vsize, sect_align)
  next_ptr = idata_raw_ptr + idata_raw_size

  size_of_image = next_rva

  // 3. Build Windows x64 entry bootstrap stub
  start_stub = pe_build_start_stub(0, idata_info.pi_exit_process_iat_rva, text_rva)
  text_payload = []
  text_payload = pe_concat(text_payload, start_stub)
  text_payload = pe_concat(text_payload, user_code)

  // 4. Construct Headers
  dos_block = pe_dos_block_serialize()
  pe_sig = pe_signature_bytes()
  coff_hdr = pe_coff_header_create(IMAGE_FILE_MACHINE_AMD64(), num_sections)
  coff_bytes = pe_coff_header_serialize(coff_hdr)

  opt_hdr = ImageOptionalHeader64()
  opt_hdr.magic = PE32PLUS_MAGIC()
  opt_hdr.major_linker_version = 1
  opt_hdr.minor_linker_version = 0
  opt_hdr.size_of_code = text_raw_size
  opt_hdr.size_of_initialized_data = rdata_raw_size + data_raw_size + idata_raw_size
  opt_hdr.size_of_uninitialized_data = bss_size
  opt_hdr.address_of_entry_point = entry_point_rva
  opt_hdr.base_of_code = text_rva
  opt_hdr.image_base = image_base
  opt_hdr.section_alignment = sect_align
  opt_hdr.file_alignment = file_align
  opt_hdr.major_os_version = 6
  opt_hdr.minor_os_version = 0
  opt_hdr.major_subsystem_version = 6
  opt_hdr.minor_subsystem_version = 0
  opt_hdr.size_of_image = size_of_image
  opt_hdr.size_of_headers = size_of_headers
  opt_hdr.checksum = 0
  opt_hdr.subsystem = IMAGE_SUBSYSTEM_WINDOWS_CUI()
  @if is_gui == 1
    opt_hdr.subsystem = IMAGE_SUBSYSTEM_WINDOWS_GUI()
  @end
  opt_hdr.dll_characteristics = IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE() | IMAGE_DLLCHARACTERISTICS_NX_COMPAT() | IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE()
  opt_hdr.size_of_stack_reserve = 1048576
  opt_hdr.size_of_stack_commit = 4096
  opt_hdr.size_of_heap_reserve = 1048576
  opt_hdr.size_of_heap_commit = 4096
  opt_hdr.opt_import_table_rva = idata_info.pi_import_dir_rva
  opt_hdr.opt_import_table_size = idata_info.pi_import_dir_size
  opt_hdr.opt_iat_rva = idata_info.pi_iat_rva
  opt_hdr.opt_iat_size = idata_info.pi_iat_size
  opt_bytes = pe_optional_header64_serialize(opt_hdr)

  // 5. Section Headers
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

  sec_idata = pe_section_idata_create(idata_vsize, idata_rva, idata_raw_size, idata_raw_ptr)
  sec_idata_bytes = pe_section_header_serialize(sec_idata)

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
  headers_blob = pe_concat(headers_blob, sec_idata_bytes)
  headers_blob = pe_pad_zeros(headers_blob, size_of_headers)

  // 7. Assemble Binary Payload
  binary = []
  binary = pe_concat(binary, headers_blob)

  text_blob = []
  text_blob = pe_concat(text_blob, text_payload)
  text_blob = pe_pad_zeros(text_blob, text_raw_size)
  binary = pe_concat(binary, text_blob)

  @if has_rdata == 1
    rdata_blob = []
    rdata_blob = pe_concat(rdata_blob, rdata_bytes)
    rdata_blob = pe_pad_zeros(rdata_blob, rdata_raw_size)
    binary = pe_concat(binary, rdata_blob)
  @end

  @if has_data == 1
    data_blob = []
    data_blob = pe_concat(data_blob, data_bytes)
    data_blob = pe_pad_zeros(data_blob, data_raw_size)
    binary = pe_concat(binary, data_blob)
  @end

  idata_blob = []
  idata_blob = pe_concat(idata_blob, idata_info.pi_idata_bytes)
  idata_blob = pe_pad_zeros(idata_blob, idata_raw_size)
  binary = pe_concat(binary, idata_blob)

  // 8. Write to filesystem
  written = pe_write_to_disk(output_path, binary)
  res = PeWriteResult()
  @if written < 0
    res.pe_success = 0
    res.pe_out_path = output_path
    res.pe_file_size = 0
    res.pe_entry_vaddr = entry_vaddr
    res.pe_error_msg = "Failed to write PE64 binary to filesystem"
    res.pe_bytes = binary
    return res
  @end

  res.pe_success = 1
  res.pe_out_path = output_path
  res.pe_file_size = binary.len()
  res.pe_entry_vaddr = entry_vaddr
  res.pe_error_msg = ""
  res.pe_bytes = binary
  return res
@end

@fn emit_pe_64_executable(output_path, machine_code_bytes)
  // WHY: Compatibility bridge for omni-target executable synthesis
  empty_rdata = []
  empty_data = []
  res = pe_emit_executable(machine_code_bytes, empty_rdata, empty_data, 0, 0, output_path)
  return res.pe_success
@end
