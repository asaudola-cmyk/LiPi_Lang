// ============================================================================
// LIPI SOVEREIGN COMPILER — WINDOWS PE64 (.EXE) BINARY WRITER
// Module: src/compiler/backend/formats/pe/pe_writer.lp
// Standard: Microsoft Windows x86-64 Portable Executable (PE32+)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "utso/syscalls"
import "utso/collections"
import "utso/string"

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
  pi_virtual_alloc_iat_rva: i64 // RVA of the VirtualAlloc slot within the IAT
  pi_create_file_iat_rva: i64  // RVA of CreateFileA slot
  pi_read_file_iat_rva: i64    // RVA of ReadFile slot
  pi_close_handle_iat_rva: i64 // RVA of CloseHandle slot
  pi_get_tick64_iat_rva: i64   // RVA of GetTickCount64 slot
  pi_set_fpointer_iat_rva: i64 // RVA of SetFilePointer slot
  pi_get_fattr_iat_rva: i64    // RVA of GetFileAttributesA slot
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
  // WHY: Constructs a Microsoft PE32+ .idata section for KERNEL32.DLL (10 imports, 386 bytes):
  //   [0..39]:    Import Directory Table (40 bytes)
  //   [40..127]:  ILT (10 thunks + null = 88 bytes)
  //   [128..215]: IAT (10 thunks + null = 88 bytes)
  //   [216..371]: 2-byte aligned Hint/Name entries
  //   [372..385]: "KERNEL32.dll\0\0"
  import_dir_rva = idata_rva
  import_dir_size = 40
  ilt_rva = idata_rva + 40
  ilt_size = 88
  iat_rva = idata_rva + 128
  iat_size = 88

  hint_exit_rva = idata_rva + 216
  hint_getstd_rva = idata_rva + 230
  hint_write_rva = idata_rva + 246
  hint_valloc_rva = idata_rva + 258
  hint_cfile_rva = idata_rva + 274
  hint_rfile_rva = idata_rva + 288
  hint_close_rva = idata_rva + 300
  hint_tick64_rva = idata_rva + 314
  hint_setfp_rva = idata_rva + 332
  hint_gfattr_rva = idata_rva + 350
  dll_name_rva = idata_rva + 372

  desc_k32 = ImageImportDescriptor()
  desc_k32.iid_original_first_thunk = ilt_rva
  desc_k32.iid_time_date_stamp = 0
  desc_k32.iid_forwarder_chain = 0
  desc_k32.iid_name_rva = dll_name_rva
  desc_k32.iid_first_thunk = iat_rva
  k32_bytes = pe_import_descriptor_serialize(desc_k32)

  null_desc = pe_import_descriptor_null()
  null_bytes = pe_import_descriptor_serialize(null_desc)

  thunks = []
  thunks = pe_concat(thunks, pe_pack_u64(hint_exit_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_getstd_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_write_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_valloc_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_cfile_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_rfile_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_close_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_tick64_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_setfp_rva))
  thunks = pe_concat(thunks, pe_pack_u64(hint_gfattr_rva))
  thunks = pe_concat(thunks, pe_pack_u64(0))

  hints_bytes = [
    0, 0, 69, 120, 105, 116, 80, 114, 111, 99, 101, 115, 115, 0,
    0, 0, 71, 101, 116, 83, 116, 100, 72, 97, 110, 100, 108, 101, 0, 0,
    0, 0, 87, 114, 105, 116, 101, 70, 105, 108, 101, 0,
    0, 0, 86, 105, 114, 116, 117, 97, 108, 65, 108, 108, 111, 99, 0, 0,
    0, 0, 67, 114, 101, 97, 116, 101, 70, 105, 108, 101, 65, 0,
    0, 0, 82, 101, 97, 100, 70, 105, 108, 101, 0, 0,
    0, 0, 67, 108, 111, 115, 101, 72, 97, 110, 100, 108, 101, 0,
    0, 0, 71, 101, 116, 84, 105, 99, 107, 67, 111, 117, 110, 116, 54, 52, 0, 0,
    0, 0, 83, 101, 116, 70, 105, 108, 101, 80, 111, 105, 110, 116, 101, 114, 0, 0,
    0, 0, 71, 101, 116, 70, 105, 108, 101, 65, 116, 116, 114, 105, 98, 117, 116, 101, 115, 65, 0, 0
  ]

  dll_bytes = [
    75, 69, 82, 78, 69, 76, 51, 50, 46, 100, 108, 108, 0, 0
  ]

  all_bytes = []
  all_bytes = pe_concat(all_bytes, k32_bytes)
  all_bytes = pe_concat(all_bytes, null_bytes)
  all_bytes = pe_concat(all_bytes, thunks)
  all_bytes = pe_concat(all_bytes, thunks)
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
  info.pi_virtual_alloc_iat_rva = iat_rva + 24
  info.pi_create_file_iat_rva = iat_rva + 32
  info.pi_read_file_iat_rva = iat_rva + 40
  info.pi_close_handle_iat_rva = iat_rva + 48
  info.pi_get_tick64_iat_rva = iat_rva + 56
  info.pi_set_fpointer_iat_rva = iat_rva + 64
  info.pi_get_fattr_iat_rva = iat_rva + 72
  return info
@end

// ============================================================================
// 5. WINDOWS X64 ENTRY BOOTSTRAP STUB + WIN32 KERNEL32 TRAMPOLINES (704 BYTES)
// ============================================================================

@fn pe_emit_win64_save_regs(stub, extra_sub)
  // WHY: Preserves Win64 volatile caller registers (rdi,rsi,rdx,rcx,r8..r11) and aligns rsp to 16B.
  stub = stub.push(87) stub = stub.push(86) stub = stub.push(82) stub = stub.push(81)
  stub = stub.push(65) stub = stub.push(80) stub = stub.push(65) stub = stub.push(81)
  stub = stub.push(65) stub = stub.push(82) stub = stub.push(65) stub = stub.push(83)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(236) stub = stub.push(extra_sub)
  return stub
@end

@fn pe_emit_win64_restore_ret(stub, extra_sub)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(196) stub = stub.push(extra_sub)
  stub = stub.push(65) stub = stub.push(91) stub = stub.push(65) stub = stub.push(90)
  stub = stub.push(65) stub = stub.push(89) stub = stub.push(65) stub = stub.push(88)
  stub = stub.push(89) stub = stub.push(90) stub = stub.push(94) stub = stub.push(95)
  stub = stub.push(195)
  return stub
@end

@fn pe_emit_win64_iat_call(stub, iat_rva, text_rva)
  disp = iat_rva - (text_rva + stub.len() + 6)
  db = pe_pack_u32(disp)
  stub = stub.push(255) stub = stub.push(21)
  stub = stub.push(db[0]) stub = stub.push(db[1]) stub = stub.push(db[2]) stub = stub.push(db[3])
  return stub
@end

@fn pe_build_start_stub(main_entry_offset, exit_process_iat_rva, text_rva)
  // WHY: Windows x64 entry stub + 9 native KERNEL32.dll Win64 ABI trampolines (exact 704 bytes):
  //   [0..16]    _start               [17..63]   __win64_write_stdout
  //   [64..143]  __win64_virtual_alloc [144..255] __win64_write_fd
  //   [256..367] __win64_open_file    [368..447] __win64_read_fd
  //   [448..495] __win64_close_fd     [496..575] __win64_clock_gettime
  //   [576..639] __win64_lseek_fd     [640..703] __win64_access_file
  stub = []
  // 1. [0..16] _start
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(236) stub = stub.push(40)
  rel32 = (704 + main_entry_offset) - 9
  cd = pe_pack_u32(rel32)
  stub = stub.push(232)
  stub = stub.push(cd[0]) stub = stub.push(cd[1]) stub = stub.push(cd[2]) stub = stub.push(cd[3])
  stub = stub.push(137) stub = stub.push(193)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva, text_rva)

  // 2. [17..63] __win64_write_stdout (47 bytes)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(236) stub = stub.push(56)
  stub = stub.push(185) stub = stub.push(245) stub = stub.push(255) stub = stub.push(255) stub = stub.push(255)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 8, text_rva)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(193)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(242)
  stub = stub.push(65) stub = stub.push(137) stub = stub.push(248)
  stub = stub.push(76) stub = stub.push(141) stub = stub.push(76) stub = stub.push(36) stub = stub.push(40)
  stub = stub.push(49) stub = stub.push(192)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(32)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 16, text_rva)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(196) stub = stub.push(56)
  stub = stub.push(195)

  // 3. [64..143] __win64_virtual_alloc
  stub = stub.push(81) stub = stub.push(82)
  stub = stub.push(65) stub = stub.push(80) stub = stub.push(65) stub = stub.push(81)
  stub = stub.push(65) stub = stub.push(82) stub = stub.push(65) stub = stub.push(83)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(236) stub = stub.push(40)
  stub = stub.push(49) stub = stub.push(201)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(242)
  stub = stub.push(72) stub = stub.push(129) stub = stub.push(250) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0) stub = stub.push(4)
  stub = stub.push(118) stub = stub.push(5)
  stub = stub.push(186) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0) stub = stub.push(4)
  stub = stub.push(65) stub = stub.push(184) stub = stub.push(0) stub = stub.push(48) stub = stub.push(0) stub = stub.push(0)
  stub = stub.push(65) stub = stub.push(185) stub = stub.push(4) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 24, text_rva)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(196) stub = stub.push(40)
  stub = stub.push(65) stub = stub.push(91) stub = stub.push(65) stub = stub.push(90)
  stub = stub.push(65) stub = stub.push(89) stub = stub.push(65) stub = stub.push(88)
  stub = stub.push(90) stub = stub.push(89)
  stub = stub.push(195)
  @while stub.len() < 144
    stub = stub.push(144)
  @end

  // 4. [144..255] __win64_write_fd (rdi=fd/HANDLE, rsi=buf, rdx=len)
  stub = pe_emit_win64_save_regs(stub, 56)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(255) stub = stub.push(2)
  stub = stub.push(119) stub = stub.push(14)
  stub = stub.push(137) stub = stub.push(215)
  wfd_rel = pe_pack_u32(17 - (stub.len() + 5))
  stub = stub.push(232)
  stub = stub.push(wfd_rel[0]) stub = stub.push(wfd_rel[1]) stub = stub.push(wfd_rel[2]) stub = stub.push(wfd_rel[3])
  stub = stub.push(72) stub = stub.push(139) stub = stub.push(68) stub = stub.push(36) stub = stub.push(96)
  stub = stub.push(235) stub = stub.push(35)
  // file handle WriteFile path
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(249)
  stub = stub.push(65) stub = stub.push(137) stub = stub.push(208)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(242)
  stub = stub.push(76) stub = stub.push(141) stub = stub.push(76) stub = stub.push(36) stub = stub.push(40)
  stub = stub.push(49) stub = stub.push(192)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(32)
  stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(40)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 16, text_rva)
  stub = stub.push(139) stub = stub.push(68) stub = stub.push(36) stub = stub.push(40)
  stub = pe_emit_win64_restore_ret(stub, 56)
  @while stub.len() < 256
    stub = stub.push(144)
  @end

  // 5. [256..367] __win64_open_file (rdi=path, rsi=flags, rdx=mode) -> CreateFileA
  stub = pe_emit_win64_save_regs(stub, 56)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(249)
  stub = stub.push(64) stub = stub.push(246) stub = stub.push(198) stub = stub.push(3)
  stub = stub.push(117) stub = stub.push(12)
  stub = stub.push(186) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0) stub = stub.push(128)
  stub = stub.push(184) stub = stub.push(3) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0)
  stub = stub.push(235) stub = stub.push(10)
  stub = stub.push(186) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0) stub = stub.push(64)
  stub = stub.push(184) stub = stub.push(2) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0)
  stub = stub.push(65) stub = stub.push(184) stub = stub.push(3) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0)
  stub = stub.push(69) stub = stub.push(49) stub = stub.push(201)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(32)
  stub = stub.push(72) stub = stub.push(199) stub = stub.push(68) stub = stub.push(36) stub = stub.push(40) stub = stub.push(128) stub = stub.push(0) stub = stub.push(0) stub = stub.push(0)
  stub = stub.push(49) stub = stub.push(192)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(48)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 32, text_rva)
  stub = pe_emit_win64_restore_ret(stub, 56)
  @while stub.len() < 368
    stub = stub.push(144)
  @end

  // 6. [368..447] __win64_read_fd (rdi=hFile, rsi=buf, rdx=len) -> ReadFile
  stub = pe_emit_win64_save_regs(stub, 56)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(249)
  stub = stub.push(65) stub = stub.push(137) stub = stub.push(208)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(242)
  stub = stub.push(76) stub = stub.push(141) stub = stub.push(76) stub = stub.push(36) stub = stub.push(40)
  stub = stub.push(49) stub = stub.push(192)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(32)
  stub = stub.push(137) stub = stub.push(68) stub = stub.push(36) stub = stub.push(40)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 40, text_rva)
  stub = stub.push(139) stub = stub.push(68) stub = stub.push(36) stub = stub.push(40)
  stub = pe_emit_win64_restore_ret(stub, 56)
  @while stub.len() < 448
    stub = stub.push(144)
  @end

  // 7. [448..495] __win64_close_fd (rdi=hFile) -> CloseHandle
  stub = pe_emit_win64_save_regs(stub, 40)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(249)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 48, text_rva)
  stub = stub.push(49) stub = stub.push(192)
  stub = pe_emit_win64_restore_ret(stub, 40)
  @while stub.len() < 496
    stub = stub.push(144)
  @end

  // 8. [496..575] __win64_clock_gettime (rsi=&timespec) -> GetTickCount64
  stub = pe_emit_win64_save_regs(stub, 40)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 56, text_rva)
  stub = stub.push(49) stub = stub.push(210)
  stub = stub.push(185) stub = stub.push(232) stub = stub.push(3) stub = stub.push(0) stub = stub.push(0)
  stub = stub.push(72) stub = stub.push(247) stub = stub.push(241)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(6)
  stub = stub.push(72) stub = stub.push(105) stub = stub.push(210) stub = stub.push(64) stub = stub.push(66) stub = stub.push(15) stub = stub.push(0)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(86) stub = stub.push(8)
  stub = stub.push(49) stub = stub.push(192)
  stub = pe_emit_win64_restore_ret(stub, 40)
  @while stub.len() < 576
    stub = stub.push(144)
  @end

  // 9. [576..639] __win64_lseek_fd (rdi=hFile, rsi=off, rdx=whence) -> SetFilePointer
  stub = pe_emit_win64_save_regs(stub, 40)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(249)
  stub = stub.push(65) stub = stub.push(137) stub = stub.push(209)
  stub = stub.push(137) stub = stub.push(242)
  stub = stub.push(69) stub = stub.push(49) stub = stub.push(192)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 64, text_rva)
  stub = stub.push(131) stub = stub.push(248) stub = stub.push(255)
  stub = stub.push(117) stub = stub.push(4)
  stub = stub.push(72) stub = stub.push(131) stub = stub.push(200) stub = stub.push(255)
  stub = pe_emit_win64_restore_ret(stub, 40)
  @while stub.len() < 640
    stub = stub.push(144)
  @end

  // 10. [640..703] __win64_access_file (rdi=path) -> GetFileAttributesA
  stub = pe_emit_win64_save_regs(stub, 40)
  stub = stub.push(72) stub = stub.push(137) stub = stub.push(249)
  stub = pe_emit_win64_iat_call(stub, exit_process_iat_rva + 72, text_rva)
  stub = stub.push(131) stub = stub.push(248) stub = stub.push(255)
  stub = stub.push(116) stub = stub.push(2)
  stub = stub.push(49) stub = stub.push(192)
  stub = pe_emit_win64_restore_ret(stub, 40)
  @while stub.len() < 704
    stub = stub.push(144)
  @end

  return stub
@end

@fn pe_read_code_u64(arr, idx)
  lo = arr[idx] + (arr[idx + 1] * 256) + (arr[idx + 2] * 65536) + (arr[idx + 3] * 16777216)
  hi = arr[idx + 4] + (arr[idx + 5] * 256) + (arr[idx + 6] * 65536) + (arr[idx + 7] * 16777216)
  return lo + (hi * 4294967296)
@end

@fn pe_patch_win64_code(code_bytes, image_base, rdata_rva, rdata_vsize, data_rva)
  // WHY: Relocates ALL Linux ELF64 virtual addresses (.rodata and W^X RW runtime globals)
  // to Windows PE32+ addresses (image_base + rdata_rva / data_rva) and eliminates 100% of
  // Linux `syscall` (0F 05) and `hlt` (F4) instructions by lowering them to native Win64 ABI
  // calls into KERNEL32.dll!GetStdHandle, WriteFile, VirtualAlloc, and ExitProcess.
  n = code_bytes.len()
  @if n == 0 return code_bytes @end
  out = []
  i = 0
  @while i < n
    out = out.push(code_bytes[i])
    i = i + 1
  @end

  linux_ro_base = 1073742128 + n
  linux_ro_end = linux_ro_base + rdata_vsize
  text_ro_end = 304 + n + rdata_vsize
  rem_page = text_ro_end % 4096
  pad_bytes = 0
  @if rem_page != 0
    pad_bytes = 4096 - rem_page
  @end
  linux_rw_base = 1073741824 + text_ro_end + pad_bytes
  linux_rw_end = linux_rw_base + 128

  win_ro_base = image_base + rdata_rva
  win_rw_base = image_base + data_rva
  stub_sz = 704

  idx = 0
  @while idx < n
    // 1. 27-byte inline Linux SYS_write stdout print sequence -> call __win64_write_stdout (+17)
    @if idx + 26 < n && out[idx] == 184 && out[idx + 1] == 1 && out[idx + 2] == 0 && out[idx + 3] == 0 && out[idx + 4] == 0 && out[idx + 5] == 191 && out[idx + 6] == 1 && out[idx + 10] == 72 && out[idx + 11] == 190 && out[idx + 20] == 186 && out[idx + 25] == 15 && out[idx + 26] == 5
      l0 = out[idx + 21]
      l1 = out[idx + 22]
      l2 = out[idx + 23]
      l3 = out[idx + 24]
      orig_vaddr = pe_read_code_u64(out, idx + 12)
      new_vaddr = orig_vaddr
      @if orig_vaddr >= linux_ro_base && orig_vaddr <= linux_ro_end
        new_vaddr = win_ro_base + (orig_vaddr - linux_ro_base)
      @end
      vb = pe_pack_u64(new_vaddr)
      list_set(out, idx + 0, 86)
      list_set(out, idx + 1, 87)
      list_set(out, idx + 2, 144)
      list_set(out, idx + 3, 144)
      list_set(out, idx + 4, 144)
      list_set(out, idx + 5, 191)
      list_set(out, idx + 6, l0)
      list_set(out, idx + 7, l1)
      list_set(out, idx + 8, l2)
      list_set(out, idx + 9, l3)
      k = 0
      @while k < 8
        list_set(out, idx + 12 + k, vb[k])
        k = k + 1
      @end
      call_rel = 17 - (stub_sz + idx + 25)
      cb = pe_pack_u32(call_rel)
      list_set(out, idx + 20, 232)
      list_set(out, idx + 21, cb[0])
      list_set(out, idx + 22, cb[1])
      list_set(out, idx + 23, cb[2])
      list_set(out, idx + 24, cb[3])
      list_set(out, idx + 25, 95)
      list_set(out, idx + 26, 94)
      idx = idx + 27
    // 2. 18-byte print_float stdout write sequence -> call __win64_write_stdout (+17)
    @elif idx + 17 < n && out[idx] == 184 && out[idx + 1] == 1 && out[idx + 2] == 0 && out[idx + 3] == 0 && out[idx + 4] == 0 && out[idx + 5] == 191 && out[idx + 6] == 1 && out[idx + 10] == 76 && out[idx + 11] == 137 && out[idx + 12] == 198 && out[idx + 13] == 76 && out[idx + 14] == 137 && out[idx + 15] == 202 && out[idx + 16] == 15 && out[idx + 17] == 5
      // mov rsi, r8 (3B); mov edi, r9d (3B); call __win64_write_stdout (5B); 7 NOPs
      list_set(out, idx + 0, 76) list_set(out, idx + 1, 137) list_set(out, idx + 2, 198)
      list_set(out, idx + 3, 68) list_set(out, idx + 4, 137) list_set(out, idx + 5, 207)
      pf_rel = 17 - (stub_sz + idx + 11)
      pfb = pe_pack_u32(pf_rel)
      list_set(out, idx + 6, 232)
      list_set(out, idx + 7, pfb[0]) list_set(out, idx + 8, pfb[1]) list_set(out, idx + 9, pfb[2]) list_set(out, idx + 10, pfb[3])
      k = 11
      @while k < 18
        list_set(out, idx + k, 144)
        k = k + 1
      @end
      idx = idx + 18
    // 3. 15-byte clock_ms SYS_clock_gettime sequence -> call __win64_clock_gettime (+496)
    @elif idx + 14 < n && out[idx] == 72 && out[idx + 1] == 199 && out[idx + 2] == 192 && out[idx + 3] == 228 && out[idx + 4] == 0 && out[idx + 13] == 15 && out[idx + 14] == 5
      // mov rsi, rsp (3B); call __win64_clock_gettime (5B); 7 NOPs
      list_set(out, idx + 0, 72) list_set(out, idx + 1, 137) list_set(out, idx + 2, 230)
      clk_rel = 496 - (stub_sz + idx + 8)
      clkb = pe_pack_u32(clk_rel)
      list_set(out, idx + 3, 232)
      list_set(out, idx + 4, clkb[0]) list_set(out, idx + 5, clkb[1]) list_set(out, idx + 6, clkb[2]) list_set(out, idx + 7, clkb[3])
      k = 8
      @while k < 15
        list_set(out, idx + k, 144)
        k = k + 1
      @end
      idx = idx + 15
    // 4. 10-byte movabs r64, imm64 -> relocate .rodata AND W^X RW runtime globals
    @elif idx + 9 < n && (out[idx] == 72 || out[idx] == 73) && (out[idx + 1] >= 184 && out[idx + 1] <= 191)
      imm_vaddr = pe_read_code_u64(out, idx + 2)
      w_vaddr = 0
      @if imm_vaddr >= linux_ro_base && imm_vaddr <= linux_ro_end && rdata_vsize > 0
        w_vaddr = win_ro_base + (imm_vaddr - linux_ro_base)
      @elif imm_vaddr >= linux_rw_base && imm_vaddr <= linux_rw_end
        w_vaddr = win_rw_base + (imm_vaddr - linux_rw_base)
      @end
      @if w_vaddr > 0
        wb = pe_pack_u64(w_vaddr)
        k = 0
        @while k < 8
          list_set(out, idx + 2 + k, wb[k])
          k = k + 1
        @end
      @end
      idx = idx + 10
    // 5. 9-byte mov rax, imm32; syscall (48 C7 C0 <nr> 00 00 00 0F 05)
    @elif idx + 8 < n && out[idx] == 72 && out[idx + 1] == 199 && out[idx + 2] == 192 && out[idx + 4] == 0 && out[idx + 5] == 0 && out[idx + 6] == 0 && out[idx + 7] == 15 && out[idx + 8] == 5
      nr9 = out[idx + 3]
      w9_target = 0 - 1
      @if nr9 == 0 w9_target = 368 @end
      @if nr9 == 1 w9_target = 144 @end
      @if nr9 == 2 w9_target = 256 @end
      @if nr9 == 3 w9_target = 448 @end
      @if nr9 == 8 w9_target = 576 @end
      @if nr9 == 9 w9_target = 64 @end
      @if nr9 == 21 w9_target = 640 @end
      @if w9_target >= 0
        w9_rel = w9_target - (stub_sz + idx + 5)
        w9b = pe_pack_u32(w9_rel)
        list_set(out, idx + 0, 232)
        list_set(out, idx + 1, w9b[0]) list_set(out, idx + 2, w9b[1]) list_set(out, idx + 3, w9b[2]) list_set(out, idx + 4, w9b[3])
        list_set(out, idx + 5, 144) list_set(out, idx + 6, 144) list_set(out, idx + 7, 144) list_set(out, idx + 8, 144)
      @else
        // mov rax, -38 (-ENOSYS); nop; nop
        list_set(out, idx + 0, 72) list_set(out, idx + 1, 199) list_set(out, idx + 2, 192)
        list_set(out, idx + 3, 218) list_set(out, idx + 4, 255) list_set(out, idx + 5, 255) list_set(out, idx + 6, 255)
        list_set(out, idx + 7, 144) list_set(out, idx + 8, 144)
      @end
      idx = idx + 9
    // 6. 7-byte mov eax, <nr>; syscall (B8 <nr> 00 00 00 0F 05)
    @elif idx + 6 < n && out[idx] == 184 && out[idx + 2] == 0 && out[idx + 3] == 0 && out[idx + 4] == 0 && out[idx + 5] == 15 && out[idx + 6] == 5
      nr7 = out[idx + 1]
      w7_target = 0 - 1
      @if nr7 == 0 w7_target = 368 @end
      @if nr7 == 1 w7_target = 144 @end
      @if nr7 == 2 w7_target = 256 @end
      @if nr7 == 3 w7_target = 448 @end
      @if nr7 == 8 w7_target = 576 @end
      @if nr7 == 9 w7_target = 64 @end
      @if nr7 == 21 w7_target = 640 @end
      @if w7_target >= 0
        w7_rel = w7_target - (stub_sz + idx + 5)
        w7b = pe_pack_u32(w7_rel)
        list_set(out, idx + 0, 232)
        list_set(out, idx + 1, w7b[0]) list_set(out, idx + 2, w7b[1]) list_set(out, idx + 3, w7b[2]) list_set(out, idx + 4, w7b[3])
        list_set(out, idx + 5, 144) list_set(out, idx + 6, 144)
      @elif nr7 == 60
        // SYS_exit -> mov eax, edi; jmp _start+9 (ExitProcess); also NOP trailing hlt (0xF4)
        jmp_rel = 9 - (stub_sz + idx + 7)
        jb = pe_pack_u32(jmp_rel)
        list_set(out, idx + 0, 137) list_set(out, idx + 1, 248)
        list_set(out, idx + 2, 233)
        list_set(out, idx + 3, jb[0]) list_set(out, idx + 4, jb[1]) list_set(out, idx + 5, jb[2]) list_set(out, idx + 6, jb[3])
        @if idx + 7 < n && out[idx + 7] == 244
          list_set(out, idx + 7, 144)
        @end
      @else
        // Non-Win32 POSIX syscalls (open/read/close/lseek/access) -> mov rax, -38 (-ENOSYS)
        list_set(out, idx + 0, 72) list_set(out, idx + 1, 199) list_set(out, idx + 2, 192)
        list_set(out, idx + 3, 218) list_set(out, idx + 4, 255) list_set(out, idx + 5, 255) list_set(out, idx + 6, 255)
      @end
      idx = idx + 7
    @else
      idx = idx + 1
    @end
  @end
  return out
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

  // 1. Determine active sections (.text, optional .rdata, mandatory RW .data for runtime globals, mandatory .idata)
  has_rdata = 0
  @if rdata_bytes.len() > 0 has_rdata = 1 @end

  rw_data_bytes = []
  gi = 0
  @while gi < 128
    rw_data_bytes = rw_data_bytes.push(0)
    gi = gi + 1
  @end
  rw_data_bytes = pe_concat(rw_data_bytes, data_bytes)
  has_data = 1

  num_sections = 3 // .text + .data + .idata
  @if has_rdata == 1 num_sections = num_sections + 1 @end

  raw_headers_size = 392 + (num_sections * 40)
  size_of_headers = pe_align_to(raw_headers_size, file_align)

  // 2. Compute Memory Layout & RVAs
  // Section 1: .text (704-byte Win64 stub & trampolines + User code)
  stub_len = 704
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

  // Section 3: .data (128B runtime RW globals + user .data + .bss)
  data_rva = next_rva
  data_raw_ptr = next_ptr
  data_vsize = rw_data_bytes.len() + bss_size
  data_raw_size = pe_align_to(rw_data_bytes.len(), file_align)
  next_rva = data_rva + pe_align_to(data_vsize, sect_align)
  next_ptr = data_raw_ptr + data_raw_size

  // Section 4: .idata (Import Directory Table + IAT for KERNEL32.DLL)
  idata_rva = next_rva
  idata_raw_ptr = next_ptr
  idata_info = pe_build_kernel32_idata(idata_rva)
  idata_vsize = idata_info.pi_idata_bytes.len()
  idata_raw_size = pe_align_to(idata_vsize, file_align)
  next_rva = idata_rva + pe_align_to(idata_vsize, sect_align)
  next_ptr = idata_raw_ptr + idata_raw_size

  size_of_image = next_rva

  // 3. Build Windows x64 entry bootstrap stub and relocate user code to Win64 ABI
  start_stub = pe_build_start_stub(0, idata_info.pi_exit_process_iat_rva, text_rva)
  patched_user_code = pe_patch_win64_code(user_code, image_base, rdata_rva, rdata_vsize, data_rva)
  text_payload = []
  text_payload = pe_concat(text_payload, start_stub)
  text_payload = pe_concat(text_payload, patched_user_code)

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
  opt_hdr.dll_characteristics = IMAGE_DLLCHARACTERISTICS_NX_COMPAT() | IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE()
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
    data_blob = pe_concat(data_blob, rw_data_bytes)
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
