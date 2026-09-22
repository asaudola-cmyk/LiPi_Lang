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

  // WHY: Self-hosting binaries may be currently mapped and executing in memory.
  // Overwriting an executing binary directly causes the Linux kernel to reject the open
  // with -ETXTBSY (errno 26). Calling sys_unlink first removes the directory link while
  // preserving the executing process's memory map, allowing sys_open to create a fresh inode.
  sys_unlink(output_path)

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

@fn elf_emit_u16_le(arr, val)
  // WHY: Serializes a 16-bit integer in little-endian order without struct allocations.
  push(arr, val % 256)
  push(arr, (val / 256) % 256)
  return 0
@end

@fn elf_emit_u32_le(arr, val)
  // WHY: Serializes a 32-bit unsigned integer in little-endian order.
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  push(arr, v % 256)
  push(arr, (v / 256) % 256)
  push(arr, (v / 65536) % 256)
  push(arr, (v / 16777216) % 256)
  return 0
@end

@fn elf_emit_u64_le(arr, val)
  // WHY: Serializes a 64-bit integer into 8 bytes in little-endian order.
  v = val
  i = 0
  @while i < 8
    b = v % 256
    @if b < 0
      b = b + 256
    @end
    push(arr, b)
    v = (v - b) / 256
    i = i + 1
  @end
  return 0
@end

@fn elf_emit_header_direct(arr, entry_vaddr, sh_offset, num_sections, shstr_idx)
  // WHY: Emits exact 64-byte ELF64 AMD64 header conforming to System V ABI without struct overhead.
  // Constrained to 5 parameters for zero register spilling across SysV ABI calling convention.
  // 1. e_ident (16 bytes)
  push(arr, 127) // 0x7F
  push(arr, 69)  // 'E'
  push(arr, 76)  // 'L'
  push(arr, 70)  // 'F'
  push(arr, 2)   // ELFCLASS64
  push(arr, 1)   // ELFDATA2LSB
  push(arr, 1)   // EV_CURRENT
  push(arr, 0)   // ELFOSABI_SYSV
  push(arr, 0)   // ABI Version
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)   // 7 pad bytes

  // 2. e_type: ET_EXEC (2) (2 bytes)
  push(arr, 2)
  push(arr, 0)

  // 3. e_machine: EM_X86_64 (62 = 0x3E) (2 bytes)
  push(arr, 62)
  push(arr, 0)

  // 4. e_version: EV_CURRENT (1) (4 bytes)
  push(arr, 1)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)

  // 5. e_entry: 8 bytes LE
  elf_emit_u64_le(arr, entry_vaddr)

  // 6. e_phoff: 64 (8 bytes LE)
  elf_emit_u64_le(arr, 64)

  // 7. e_shoff: 8 bytes LE
  elf_emit_u64_le(arr, sh_offset)

  // 8. e_flags: 0 (4 bytes LE)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)

  // 9. e_ehsize: 64 (2 bytes LE)
  push(arr, 64)
  push(arr, 0)

  // 10. e_phentsize: 56 (2 bytes LE)
  push(arr, 56)
  push(arr, 0)

  // 11. e_phnum: 2 (2 bytes LE)
  push(arr, 2)
  push(arr, 0)

  // 12. e_shentsize: 64 (2 bytes LE)
  push(arr, 64)
  push(arr, 0)

  // 13. e_shnum: 2 bytes LE
  elf_emit_u16_le(arr, num_sections)

  // 14. e_shstrndx: 2 bytes LE
  elf_emit_u16_le(arr, shstr_idx)
  return 0
@end

@fn elf_emit_phdrs_direct(arr, total_filesz, total_memsz)
  // WHY: Emits 2 program headers (112 bytes total): PT_LOAD (RX) and PT_GNU_STACK (RW NX).
  // Phdr 1: PT_LOAD
  push(arr, 1) // PT_LOAD
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  push(arr, 7) // PF_R | PF_W | PF_X
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  elf_emit_u64_le(arr, 0)         // p_offset = 0
  elf_emit_u64_le(arr, 1073741824) // p_vaddr = 0x40000000 (1GB)
  elf_emit_u64_le(arr, 1073741824) // p_paddr = 0x40000000 (1GB)
  elf_emit_u64_le(arr, total_filesz) // p_filesz
  elf_emit_u64_le(arr, total_memsz)  // p_memsz
  elf_emit_u64_le(arr, 4096)      // p_align = 4KB

  // Phdr 2: PT_GNU_STACK
  push(arr, 81)  // 0x51
  push(arr, 229) // 0xE5
  push(arr, 116) // 0x74
  push(arr, 100) // 0x64 (0x6474e551 = PT_GNU_STACK)
  push(arr, 6)   // PF_R | PF_W = 6 (non-executable NX stack)
  push(arr, 0)
  push(arr, 0)
  push(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 8) // align 8
  return 0
@end

@fn elf_emit_shdr_bits(arr, name_off, flags, addr, offset, size)
  // WHY: SHT_PROGBITS section header (64 bytes).
  elf_emit_u32_le(arr, name_off) // sh_name
  elf_emit_u32_le(arr, 1)        // sh_type = SHT_PROGBITS (1)
  elf_emit_u64_le(arr, flags)    // sh_flags
  elf_emit_u64_le(arr, addr)     // sh_addr
  elf_emit_u64_le(arr, offset)   // sh_offset
  elf_emit_u64_le(arr, size)     // sh_size
  elf_emit_u32_le(arr, 0)        // sh_link
  elf_emit_u32_le(arr, 0)        // sh_info
  elf_emit_u64_le(arr, 16)       // sh_addralign (16 for alignment)
  elf_emit_u64_le(arr, 0)        // sh_entsize
  return 0
@end

@fn elf_emit_shdr_nobits(arr, name_off, addr, offset, size)
  // WHY: SHT_NOBITS section header for .bss (64 bytes).
  elf_emit_u32_le(arr, name_off)
  elf_emit_u32_le(arr, 8)        // SHT_NOBITS (8)
  elf_emit_u64_le(arr, 3)        // SHF_WRITE | SHF_ALLOC (3)
  elf_emit_u64_le(arr, addr)
  elf_emit_u64_le(arr, offset)
  elf_emit_u64_le(arr, size)
  elf_emit_u32_le(arr, 0)
  elf_emit_u32_le(arr, 0)
  elf_emit_u64_le(arr, 8)
  elf_emit_u64_le(arr, 0)
  return 0
@end

@fn elf_emit_shdr_strtab(arr, name_off, offset, size)
  // WHY: SHT_STRTAB section header for .shstrtab (64 bytes).
  elf_emit_u32_le(arr, name_off)
  elf_emit_u32_le(arr, 3)        // SHT_STRTAB (3)
  elf_emit_u64_le(arr, 0)        // flags = 0
  elf_emit_u64_le(arr, 0)        // addr = 0
  elf_emit_u64_le(arr, offset)
  elf_emit_u64_le(arr, size)
  elf_emit_u32_le(arr, 0)
  elf_emit_u32_le(arr, 0)
  elf_emit_u64_le(arr, 1)
  elf_emit_u64_le(arr, 0)
  return 0
@end

@fn elf_emit_executable(code_bytes, rodata_bytes, data_bytes, bss_size, output_path)
  // WHY: Sovereign standalone ELF64 emitter for pure AMD64 silicon execution.
  // Constrained to 5 arguments, zero map literals, and zero register spilling.
  base_vaddr = 1073741824 // 0x40000000 (1GB)
  start_stub = elf_build_start_stub(0) // 64 bytes
  start_stub_offset = 176 // 64 (ELF Header) + 112 (2 Phdrs)
  entry_point_vaddr = base_vaddr + start_stub_offset // 1073742000 (0x400000b0)

  // 1. .text payload = _start stub + user code
  text_payload = list()
  elf_concat(text_payload, start_stub)
  elf_concat(text_payload, code_bytes)

  code_file_offset = start_stub_offset // 176
  code_size = text_payload.len()
  code_vaddr = base_vaddr + code_file_offset

  rodata_file_offset = code_file_offset + code_size
  rodata_size = rodata_bytes.len()
  rodata_vaddr = base_vaddr + rodata_file_offset

  data_file_offset = rodata_file_offset + rodata_size
  data_size = data_bytes.len()
  data_vaddr = base_vaddr + data_file_offset

  shstr_file_offset = data_file_offset + data_size
  // .shstrtab content:
  // \0.text\0.rodata\0.data\0.bss\0.shstrtab\0
  shstr_bytes = [
    0,
    46, 116, 101, 120, 116, 0,                      // .text\0 (offset 1)
    46, 114, 111, 100, 97, 116, 97, 0,              // .rodata\0 (offset 7)
    46, 100, 97, 116, 97, 0,                        // .data\0 (offset 15)
    46, 98, 115, 115, 0,                            // .bss\0 (offset 21)
    46, 115, 104, 115, 116, 114, 116, 97, 98, 0     // .shstrtab\0 (offset 26)
  ]
  shstr_size = shstr_bytes.len() // 36 bytes

  sh_offset = shstr_file_offset + shstr_size
  num_sections = 6
  shstr_idx = 5

  total_load_filesz = data_file_offset + data_size
  total_load_memsz = total_load_filesz + bss_size

  // 2. Assemble complete binary
  binary = list()

  // 2.1 ELF Header (64 bytes)
  elf_emit_header_direct(binary, entry_point_vaddr, sh_offset, num_sections, shstr_idx)

  // 2.2 Program Headers (112 bytes)
  elf_emit_phdrs_direct(binary, total_load_filesz, total_load_memsz)

  // 2.3 .text (code with _start stub)
  elf_concat(binary, text_payload)

  // 2.4 .rodata
  elf_concat(binary, rodata_bytes)

  // 2.5 .data
  elf_concat(binary, data_bytes)

  // 2.6 .shstrtab
  elf_concat(binary, shstr_bytes)

  // 2.7 Section Headers (6 * 64 = 384 bytes)
  // Section 0: NULL (64 zero bytes)
  k = 0
  while k < 64
    push(binary, 0)
    k = k + 1
  // Section 1: .text (name 1, flags 6 = RX)
  elf_emit_shdr_bits(binary, 1, 6, code_vaddr, code_file_offset, code_size)
  // Section 2: .rodata (name 7, flags 2 = A)
  elf_emit_shdr_bits(binary, 7, 2, rodata_vaddr, rodata_file_offset, rodata_size)
  // Section 3: .data (name 15, flags 3 = WA)
  elf_emit_shdr_bits(binary, 15, 3, data_vaddr, data_file_offset, data_size)
  // Section 4: .bss (name 21)
  elf_emit_shdr_nobits(binary, 21, data_vaddr + data_size, data_file_offset + data_size, bss_size)
  // Section 5: .shstrtab (name 26)
  elf_emit_shdr_strtab(binary, 26, shstr_file_offset, shstr_size)

  // 3. Write binary to disk and apply chmod +x (0755)
  bytes_written = elf_write_to_disk(output_path, binary)

  res = ElfWriteResult()
  if bytes_written < 0
    res.ew_success = 0
    res.ew_out_path = output_path
    res.ew_file_size = 0
    res.ew_entry_vaddr = entry_point_vaddr
    res.ew_error_msg = "Failed to write ELF64 binary to filesystem"
    res.ew_bytes = binary
    return res

  res.ew_success = 1
  res.ew_out_path = output_path
  res.ew_file_size = binary.len()
  res.ew_entry_vaddr = entry_point_vaddr
  res.ew_error_msg = ""
  res.ew_bytes = binary
  return res
@end

@fn elf_emit_executable_with_debug(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, output_path)
  // WHY: Sovereign standalone ELF64 emitter embedding native DWARF v4/v5 metadata.
  // Directly constructs standard ELF64 headers, PT_LOAD and PT_GNU_STACK program headers,
  // 9 section headers (.null, .text, .rodata, .data, .bss, .debug_line, .debug_info, .debug_abbrev, .shstrtab),
  // and writes the complete executable to disk with 0755 permissions with zero C or toolchain dependencies.
  base_vaddr = 1073741824 // 0x40000000 (1GB)
  start_stub = elf_build_start_stub(0) // 64 bytes
  start_stub_offset = 176 // 64 (ELF Header) + 112 (2 Phdrs)
  entry_point_vaddr = base_vaddr + start_stub_offset // 1073742000 (0x400000b0)

  // 1. .text payload = _start stub + user code
  text_payload = list()
  elf_concat(text_payload, start_stub)
  elf_concat(text_payload, code_bytes)

  code_file_offset = start_stub_offset // 176
  code_size = text_payload.len()
  code_vaddr = base_vaddr + code_file_offset

  rodata_file_offset = code_file_offset + code_size
  rodata_size = rodata_bytes.len()
  rodata_vaddr = base_vaddr + rodata_file_offset

  data_file_offset = rodata_file_offset + rodata_size
  data_size = data_bytes.len()
  data_vaddr = base_vaddr + data_file_offset

  // DWARF debug sections: placed after loadable segments on disk
  debug_line_file_offset = data_file_offset + data_size
  debug_line_size = debug_line.len()

  debug_info_file_offset = debug_line_file_offset + debug_line_size
  debug_info_size = debug_info.len()

  debug_abbrev_file_offset = debug_info_file_offset + debug_info_size
  debug_abbrev_size = debug_abbrev.len()

  shstr_file_offset = debug_abbrev_file_offset + debug_abbrev_size
  // .shstrtab content:
  // \0.text\0.rodata\0.data\0.bss\0.debug_line\0.debug_info\0.debug_abbrev\0.shstrtab\0
  shstr_bytes = [
    0,
    46, 116, 101, 120, 116, 0,                                                    // .text\0 (offset 1)
    46, 114, 111, 100, 97, 116, 97, 0,                                            // .rodata\0 (offset 7)
    46, 100, 97, 116, 97, 0,                                                      // .data\0 (offset 15)
    46, 98, 115, 115, 0,                                                          // .bss\0 (offset 21)
    46, 100, 101, 98, 117, 103, 95, 108, 105, 110, 101, 0,                       // .debug_line\0 (offset 26)
    46, 100, 101, 98, 117, 103, 95, 105, 110, 102, 111, 0,                       // .debug_info\0 (offset 38)
    46, 100, 101, 98, 117, 103, 95, 97, 98, 98, 114, 101, 118, 0,                // .debug_abbrev\0 (offset 50)
    46, 115, 104, 115, 116, 114, 116, 97, 98, 0                                   // .shstrtab\0 (offset 64)
  ]
  shstr_size = shstr_bytes.len()

  sh_offset = shstr_file_offset + shstr_size
  num_sections = 9
  shstr_idx = 8

  total_load_filesz = data_file_offset + data_size
  total_load_memsz = total_load_filesz + bss_size

  // 2. Assemble complete binary
  binary = list()

  // 2.1 ELF Header (64 bytes)
  elf_emit_header_direct(binary, entry_point_vaddr, sh_offset, num_sections, shstr_idx)

  // 2.2 Program Headers (112 bytes)
  elf_emit_phdrs_direct(binary, total_load_filesz, total_load_memsz)

  // 2.3 .text (code with _start stub)
  elf_concat(binary, text_payload)

  // 2.4 .rodata
  elf_concat(binary, rodata_bytes)

  // 2.5 .data
  elf_concat(binary, data_bytes)

  // 2.6 .debug_line
  elf_concat(binary, debug_line)

  // 2.7 .debug_info
  elf_concat(binary, debug_info)

  // 2.8 .debug_abbrev
  elf_concat(binary, debug_abbrev)

  // 2.9 .shstrtab
  elf_concat(binary, shstr_bytes)

  // 2.10 Section Headers (9 * 64 = 576 bytes)
  // Section 0: NULL (64 zero bytes)
  k = 0
  while k < 64
    push(binary, 0)
    k = k + 1
  // Section 1: .text (name 1, flags 6 = RX)
  elf_emit_shdr_bits(binary, 1, 6, code_vaddr, code_file_offset, code_size)
  // Section 2: .rodata (name 7, flags 2 = A)
  elf_emit_shdr_bits(binary, 7, 2, rodata_vaddr, rodata_file_offset, rodata_size)
  // Section 3: .data (name 15, flags 3 = WA)
  elf_emit_shdr_bits(binary, 15, 3, data_vaddr, data_file_offset, data_size)
  // Section 4: .bss (name 21)
  elf_emit_shdr_nobits(binary, 21, data_vaddr + data_size, data_file_offset + data_size, bss_size)
  // Section 5: .debug_line (name 26, flags 0, addr 0)
  elf_emit_shdr_bits(binary, 26, 0, 0, debug_line_file_offset, debug_line_size)
  // Section 6: .debug_info (name 38, flags 0, addr 0)
  elf_emit_shdr_bits(binary, 38, 0, 0, debug_info_file_offset, debug_info_size)
  // Section 7: .debug_abbrev (name 50, flags 0, addr 0)
  elf_emit_shdr_bits(binary, 50, 0, 0, debug_abbrev_file_offset, debug_abbrev_size)
  // Section 8: .shstrtab (name 64)
  elf_emit_shdr_strtab(binary, 64, shstr_file_offset, shstr_size)

  // 3. Write binary to disk and apply chmod +x (0755)
  bytes_written = elf_write_to_disk(output_path, binary)

  res = ElfWriteResult()
  if bytes_written < 0
    res.ew_success = 0
    res.ew_out_path = output_path
    res.ew_file_size = 0
    res.ew_entry_vaddr = entry_point_vaddr
    res.ew_error_msg = "Failed to write ELF64 binary with DWARF debug info to filesystem"
    res.ew_bytes = binary
    return res

  res.ew_success = 1
  res.ew_out_path = output_path
  res.ew_file_size = binary.len()
  res.ew_entry_vaddr = entry_point_vaddr
  res.ew_error_msg = ""
  res.ew_bytes = binary
  return res
@end

@fn elf_write_executable(x86_result, output_path)
  // WHY: Compatibility bridge for legacy compiler drivers
  text_src = []
  rodata_src = []
  if x86_result != 0
    if x86_result.text_bytes != 0
      text_src = x86_result.text_bytes
    end
    if x86_result.rodata_bytes != 0
      rodata_src = x86_result.rodata_bytes
    end
  end
  return elf_emit_executable(text_src, rodata_src, list(), 0, output_path)
@end
