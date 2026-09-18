// ============================================================================
// LIPI SOVEREIGN COMPILER — STREAMLINED ELF64 BINARY EMITTER
// Module: src/compiler/backend/formats/elf/elf_writer.lp
// Standard: Linux x86-64 Native ELF64 Executable Writer (SysV AMD64 ABI)
// Permissions: Mode 0755 (S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"

import "src/compiler/backend/formats/elf/elf_header.lp"
import "src/compiler/backend/formats/elf/program_header.lp"
import "src/compiler/backend/formats/elf/section_header.lp"
import "src/compiler/backend/formats/elf/relocation.lp"

// WHY: Standalone executables in Linux require no external C runtime or glibc.
// The kernel reads the 64-byte ELF header and Program Headers, sets up the initial
// stack pointer [rsp] holding argc and argv, and jumps directly to e_entry.
// This writer packages code, constants, data, and BSS into a bit-perfect binary
// and persists it to disk with executable permissions (0755).

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct ElfWriteResult
  ew_success: i64      // 1 on success, 0 on failure
  ew_out_path: string  // Destination file path
  ew_file_size: i64    // Total byte count written
  ew_entry_vaddr: i64  // Absolute virtual memory entry address
  ew_error_msg: string // Human-readable error diagnostic
  ew_bytes: array      // Assembled raw executable byte buffer
@end

// ============================================================================
// 2. HELPER BUFFER CONCATENATION
// ============================================================================

@fn elf_concat(target, source)
  // WHY: Efficiently appends all bytes from source array into target array.
  i = 0
  n = source.len()
  @while i < n
    target = target.push(source[i])
    i = i + 1
  @end
  return target
@end

@fn elf_pad_to(bytes_list, target_alignment)
  // WHY: Pads byte stream with zeros until byte count is a multiple of target_alignment.
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
// 3. LINUX STANDALONE _start BOOTSTRAP STUB (System V AMD64 ABI)
// ============================================================================

@fn elf_build_start_stub(main_entry_offset)
  // WHY: Linux kernel initializes the stack as:
  //   [rsp]     = argc
  //   [rsp + 8] = argv[0]
  //   ...
  // The _start stub extracts argc/argv, calls user main, and exits via sys_exit (syscall 60).
  //
  // 0x00: 31 ED                      (xor ebp, ebp) -> clear frame pointer per SysV ABI
  // 0x02: 48 8B 04 24                (mov rax, [rsp] -> argc)
  // 0x06: 48 89 05 23 00 00 00       (mov [rip + 0x23], rax -> g_argc at +0x30)
  // 0x0D: 48 8D 44 24 08             (lea rax, [rsp + 8] -> argv)
  // 0x12: 48 89 05 1F 00 00 00       (mov [rip + 0x1F], rax -> g_argv at +0x38)
  // 0x19: E8 xx xx xx xx             (call main)
  // 0x1E: 48 89 C7                   (mov rdi, rax -> exit code)
  // 0x21: B8 3C 00 00 00             (mov eax, 60 -> __NR_exit)
  // 0x26: 0F 05                      (syscall)
  // 0x28: F4                         (hlt)
  // 0x29..0x2F: NOP padding to 48 bytes (0x30)
  // 0x30..0x37: 8 bytes reserved for g_argc
  // 0x38..0x3F: 8 bytes reserved for g_argv
  // Total size: exactly 64 bytes.

  rel32 = 34 + main_entry_offset
  stub = [
    49, 237,                     // xor ebp, ebp (2 bytes)
    72, 139, 4, 36,              // mov rax, [rsp] (4 bytes)
    72, 137, 5, 35, 0, 0, 0,     // mov [rip + 0x23], rax (7 bytes)
    72, 141, 68, 36, 8,          // lea rax, [rsp + 8] (5 bytes)
    72, 137, 5, 31, 0, 0, 0,     // mov [rip + 0x1F], rax (7 bytes)
    232,                         // call rel32 opcode (1 byte)
    rel32 % 256,
    (rel32 / 256) % 256,
    (rel32 / 65536) % 256,
    (rel32 / 16777216) % 256,    // 4-byte displacement
    72, 137, 199,                // mov rdi, rax (3 bytes)
    184, 60, 0, 0, 0,            // mov eax, 60 (5 bytes)
    15, 5,                       // syscall (2 bytes)
    244                          // hlt (1 byte)
  ]

  @while stub.len() < 48
    stub = stub.push(144)        // NOP (0x90)
  @end

  // 8 bytes g_argc storage
  k = 0
  @while k < 8
    stub = stub.push(0)
    k = k + 1
  @end

  // 8 bytes g_argv storage
  k = 0
  @while k < 8
    stub = stub.push(0)
    k = k + 1
  @end

  return stub
@end

// ============================================================================
// 4. LOW-LEVEL DIRECT SYSCALL BINARY DISK SERIALIZER
// ============================================================================

@fn elf_write_to_disk(output_path, byte_list)
  // WHY: Writes the assembled binary bytes directly to the Linux filesystem
  // using pure kernel syscalls (sys_open, sys_mmap, sys_poke8, sys_write, sys_chmod).
  // Zero dependence on libc, fopen, or fwrite.
  // Flags: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577.
  // Permissions: 0755 = 493 decimal (rwxr-xr-x).
  total = byte_list.len()
  @if total <= 0 return 0 - 1 @end

  fd = sys_open(output_path, 577, 493)
  @if fd < 0
    return 0 - 1
  @end

  // Allocate an anonymous page-aligned buffer in kernel memory to stream out bytes
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

  // Explicitly apply executable permissions: 0755 (493) via sys_chmod
  sys_chmod(output_path, 493)

  return written
@end

// ============================================================================
// 5. STREAMLINED ELF64 EXECUTABLE EMITTER
// ============================================================================

@fn elf_emit_executable_with_debug(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, output_path)
  // WHY: Comprehensive single-pass ELF64 executable assembler supporting optional DWARF v4/v5 debug sections.
  // 1. Layouts:
  //    Base Vaddr: 0x400000 (4194304)
  //    ELF Header: 64 bytes
  //    2 Program Headers: PT_LOAD (RX) and PT_GNU_STACK (RW, NX stack) = 2 * 56 = 112 bytes
  //    Padding to 16 bytes: 64 + 112 = 176 bytes
  //    _start Stub: 64 bytes (Offset 176 / 0xB0)
  //    .text (Code): Immediately follows _start stub
  //    .rodata: Follows .text, aligned to 8 bytes
  //    .data / .bss: Handled in segment
  //    .debug_line, .debug_info, .debug_abbrev (optional DWARF sections)
  //    .shstrtab: Section name string table
  //    Section Header Table: 64 bytes * N sections

  base_vaddr = 4194304 // 0x400000

  // 1. Build _start stub calling user code at relative offset 0
  start_stub = elf_build_start_stub(0)
  start_stub_offset = 176 // 64 (ElfHdr) + 112 (2 Phdrs)
  entry_point_vaddr = base_vaddr + start_stub_offset

  // 2. Assemble .text payload: _start stub followed immediately by user machine code
  text_payload = []
  text_payload = elf_concat(text_payload, start_stub)
  text_payload = elf_concat(text_payload, code_bytes)

  // 3. String Table for Section Names (.shstrtab)
  strtab = elf_strtab_new()
  text_name_off   = elf_strtab_add(strtab, ".text")
  rodata_name_off = elf_strtab_add(strtab, ".rodata")
  data_name_off   = elf_strtab_add(strtab, ".data")
  bss_name_off    = elf_strtab_add(strtab, ".bss")

  has_debug = 0
  dline_name_off = 0
  dinfo_name_off = 0
  dabbrev_name_off = 0
  @if debug_line.len() > 0
    has_debug = 1
    dline_name_off   = elf_strtab_add(strtab, ".debug_line")
    dinfo_name_off   = elf_strtab_add(strtab, ".debug_info")
    dabbrev_name_off = elf_strtab_add(strtab, ".debug_abbrev")
  @end

  shstr_name_off  = elf_strtab_add(strtab, ".shstrtab")
  shstr_bytes     = elf_strtab_get_bytes(strtab)

  // 4. File layout calculations
  code_file_offset = start_stub_offset
  code_size = text_payload.len()
  code_vaddr = base_vaddr + code_file_offset

  rodata_file_offset = code_file_offset + code_size
  rodata_size = rodata_bytes.len()
  rodata_vaddr = base_vaddr + rodata_file_offset

  data_file_offset = rodata_file_offset + rodata_size
  data_size = data_bytes.len()
  data_vaddr = base_vaddr + data_file_offset

  next_offset = data_file_offset + data_size

  dline_file_offset = next_offset
  dline_size = debug_line.len()
  @if dline_size > 0 next_offset = next_offset + dline_size @end

  dinfo_file_offset = next_offset
  dinfo_size = debug_info.len()
  @if dinfo_size > 0 next_offset = next_offset + dinfo_size @end

  dabbrev_file_offset = next_offset
  dabbrev_size = debug_abbrev.len()
  @if dabbrev_size > 0 next_offset = next_offset + dabbrev_size @end

  shstr_file_offset = next_offset
  shstr_size = shstr_bytes.len()

  // Section header table offset (placed right after .shstrtab)
  sh_offset = shstr_file_offset + shstr_size

  num_sections = 6
  shstr_idx = 5
  @if has_debug == 1
    num_sections = 9
    shstr_idx = 8
  @end

  // 5. Program Headers (PT_LOAD and PT_GNU_STACK)
  total_load_filesz = data_file_offset + data_size
  total_load_memsz  = total_load_filesz + bss_size

  phdr_load = elf_pt_load_create(0, base_vaddr, total_load_filesz, total_load_memsz, PF_R_W_X(), ELF_PAGE_SIZE_4K())
  phdr_stack = elf_pt_gnu_stack_create(0) // Non-executable stack (NX enabled)

  phdrs = [phdr_load, phdr_stack]
  phdrs_bytes = elf_program_headers_serialize(phdrs) // 2 * 56 = 112 bytes

  // 6. ELF64 Header
  elf_hdr = elf_header_x86_64(entry_point_vaddr, 64, sh_offset, 2, num_sections, shstr_idx)
  elf_hdr_bytes = elf_header_serialize(elf_hdr) // 64 bytes

  // 7. Section Headers
  sh_null = elf_sh_null()
  sh_text = elf_sh_text(text_name_off, code_vaddr, code_file_offset, code_size)
  sh_rodata = elf_sh_rodata(rodata_name_off, rodata_vaddr, rodata_file_offset, rodata_size)
  sh_data = elf_sh_data(data_name_off, data_vaddr, data_file_offset, data_size)
  sh_bss = elf_sh_bss(bss_name_off, data_vaddr + data_size, data_file_offset + data_size, bss_size)
  sh_shstr = elf_sh_shstrtab(shstr_name_off, shstr_file_offset, shstr_size)

  shdrs = [sh_null, sh_text, sh_rodata, sh_data, sh_bss]
  @if has_debug == 1
    sh_dline = {
      sh_name: dline_name_off,
      sh_type: SHT_PROGBITS(),
      sh_flags: 0,
      sh_addr: 0,
      sh_offset: dline_file_offset,
      sh_size: dline_size,
      sh_link: 0,
      sh_info: 0,
      sh_addralign: 1,
      sh_entsize: 0
    }
    sh_dinfo = {
      sh_name: dinfo_name_off,
      sh_type: SHT_PROGBITS(),
      sh_flags: 0,
      sh_addr: 0,
      sh_offset: dinfo_file_offset,
      sh_size: dinfo_size,
      sh_link: 0,
      sh_info: 0,
      sh_addralign: 1,
      sh_entsize: 0
    }
    sh_dabbrev = {
      sh_name: dabbrev_name_off,
      sh_type: SHT_PROGBITS(),
      sh_flags: 0,
      sh_addr: 0,
      sh_offset: dabbrev_file_offset,
      sh_size: dabbrev_size,
      sh_link: 0,
      sh_info: 0,
      sh_addralign: 1,
      sh_entsize: 0
    }
    shdrs = shdrs.push(sh_dline)
    shdrs = shdrs.push(sh_dinfo)
    shdrs = shdrs.push(sh_dabbrev)
  @end
  shdrs = shdrs.push(sh_shstr)

  shdrs_bytes = elf_section_headers_serialize(shdrs)

  // 8. Assemble Full Contiguous Binary
  binary = []
  binary = elf_concat(binary, elf_hdr_bytes)   // 0x00..0x3F (64 bytes)
  binary = elf_concat(binary, phdrs_bytes)     // 0x40..0xAF (112 bytes) -> Total 176 bytes
  binary = elf_concat(binary, text_payload)    // Offset 176 onwards
  binary = elf_concat(binary, rodata_bytes)
  binary = elf_concat(binary, data_bytes)
  @if has_debug == 1
    binary = elf_concat(binary, debug_line)
    binary = elf_concat(binary, debug_info)
    binary = elf_concat(binary, debug_abbrev)
  @end
  binary = elf_concat(binary, shstr_bytes)
  binary = elf_concat(binary, shdrs_bytes)

  // 9. Write to disk and enforce 0755 permissions
  bytes_written = elf_write_to_disk(output_path, binary)
  @if bytes_written < 0
    return {
      ew_success: 0,
      ew_out_path: output_path,
      ew_file_size: 0,
      ew_entry_vaddr: entry_point_vaddr,
      ew_error_msg: "Failed to write ELF64 binary to filesystem",
      ew_bytes: binary
    }
  @end

  return {
    ew_success: 1,
    ew_out_path: output_path,
    ew_file_size: binary.len(),
    ew_entry_vaddr: entry_point_vaddr,
    ew_error_msg: "",
    ew_bytes: binary
  }
@end

@fn elf_emit_executable(code_bytes, rodata_bytes, data_bytes, bss_size, output_path)
  // WHY: Canonical wrapper for live binaries without debug symbols
  return elf_emit_executable_with_debug(code_bytes, rodata_bytes, data_bytes, bss_size, [], [], [], output_path)
@end
