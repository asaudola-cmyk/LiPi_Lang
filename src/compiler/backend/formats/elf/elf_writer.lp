// ============================================================================
// LIPI SOVEREIGN COMPILER — STREAMLINED ELF64 BINARY EMITTER
// Module: src/compiler/backend/formats/elf/elf_writer.lp
// Standard: Linux x86-64 Native ELF64 Executable Writer (SysV AMD64 ABI)
// Permissions: Mode 0755 (S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH)
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "utso/syscalls"
import "utso/collections"
import "utso/string"

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
  @if output_path == "" return total @end

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

@fn elf_emit_header_machine_type(arr, entry_vaddr, sh_offset, num_sections, shstr_idx, machine, e_type)
  // WHY: Emits exact 64-byte ELF64 header conforming to System V ABI for the specified
  // target CPU architecture (EM_X86_64 = 62, EM_AARCH64 = 183, EM_RISCV = 243) and e_type (2=ET_EXEC, 3=ET_DYN).
  // Constrained to <= 7 parameters.
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

  // 2. e_type: (2 bytes: ET_EXEC=2 or ET_DYN=3)
  elf_emit_u16_le(arr, e_type)

  // 3. e_machine: (2 bytes)
  elf_emit_u16_le(arr, machine)

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

  // 11. e_phnum: 3 (2 bytes LE: PT_LOAD RX, PT_LOAD RW, PT_GNU_STACK RW)
  push(arr, 3)
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

@fn elf_emit_header_machine(arr, entry_vaddr, sh_offset, num_sections, shstr_idx, machine)
  return elf_emit_header_machine_type(arr, entry_vaddr, sh_offset, num_sections, shstr_idx, machine, 2)
@end

@fn elf_emit_header_direct(arr, entry_vaddr, sh_offset, num_sections, shstr_idx)
  // WHY: Legacy convenience wrapper emitting AMD64 (EM_X86_64 = 62) ELF64 header
  return elf_emit_header_machine(arr, entry_vaddr, sh_offset, num_sections, shstr_idx, 62)
@end

@fn elf_build_start_stub_wx(main_entry_offset, rw_vaddr)
  // WHY: Strict W^X SysV AMD64 _start bootstrap stub (exact 64 bytes, ZERO writable data in .text).
  // Stores [rsp]=argc, [rsp+8]=argv, and rsp=g_stack_bottom into RW PT_LOAD[1] at rw_vaddr+0/8/112,
  // calls user entry point at stub+64+main_entry_offset, and exits cleanly via Linux SYS_exit (60).
  rel32 = 27 + main_entry_offset
  stub = [49, 237, 72, 186]
  elf_emit_u64_le(stub, rw_vaddr)
  push(stub, 72) push(stub, 139) push(stub, 4) push(stub, 36)
  push(stub, 72) push(stub, 137) push(stub, 2)
  push(stub, 72) push(stub, 141) push(stub, 68) push(stub, 36) push(stub, 8)
  push(stub, 72) push(stub, 137) push(stub, 66) push(stub, 8)
  push(stub, 72) push(stub, 137) push(stub, 98) push(stub, 112)
  push(stub, 232)
  elf_emit_u32_le(stub, rel32)
  push(stub, 72) push(stub, 137) push(stub, 199)
  push(stub, 184) push(stub, 60) push(stub, 0) push(stub, 0) push(stub, 0)
  push(stub, 15) push(stub, 5)
  push(stub, 244)
  @while stub.len() < 64
    push(stub, 144)
  @end
  return stub
@end

@fn elf_build_start_stub_pie(main_entry_offset, rw_file_offset)
  // WHY: Strict W^X + ASLR Static-PIE _start bootstrap stub (exact 64 bytes at file offset 240).
  // Uses RIP-relative `lea rdx, [rip + disp32]` (disp32 = rw_file_offset - 249) so kernel ASLR
  // can slide the base address arbitrarily while capturing argc, argv, and g_stack_bottom (+112).
  disp32 = rw_file_offset - 249
  rel32 = 27 + main_entry_offset
  stub = [49, 237, 72, 141, 21]
  elf_emit_u32_le(stub, disp32)
  push(stub, 144) push(stub, 144) push(stub, 144)
  push(stub, 72) push(stub, 139) push(stub, 4) push(stub, 36)
  push(stub, 72) push(stub, 137) push(stub, 2)
  push(stub, 72) push(stub, 141) push(stub, 68) push(stub, 36) push(stub, 8)
  push(stub, 72) push(stub, 137) push(stub, 66) push(stub, 8)
  push(stub, 72) push(stub, 137) push(stub, 98) push(stub, 112)
  push(stub, 232)
  elf_emit_u32_le(stub, rel32)
  push(stub, 72) push(stub, 137) push(stub, 199)
  push(stub, 184) push(stub, 60) push(stub, 0) push(stub, 0) push(stub, 0)
  push(stub, 15) push(stub, 5)
  push(stub, 244)
  @while stub.len() < 64
    push(stub, 144)
  @end
  return stub
@end

@fn elf_emit_wx_split_phdrs_base(arr, base_vaddr, text_ro_filesz, data_offset, data_vaddr, data_filesz, data_memsz)
  // WHY: Emits strict W^X (Write XOR Execute) separated ELF64 Program Headers (168 bytes):
  //   1. PT_LOAD (1) for .text + .rodata with PF_R | PF_X (5) at base_vaddr
  //   2. PT_LOAD (1) for .data + .bss    with PF_R | PF_W (6) at 4KB page-aligned data_vaddr
  //   3. PT_GNU_STACK (1685382481)       with PF_R | PF_W (6) enforcing non-executable stack
  elf_emit_u32_le(arr, 1)
  elf_emit_u32_le(arr, 5)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, base_vaddr)
  elf_emit_u64_le(arr, base_vaddr)
  elf_emit_u64_le(arr, text_ro_filesz)
  elf_emit_u64_le(arr, text_ro_filesz)
  elf_emit_u64_le(arr, 4096)

  // Program Header 1: .data + .bss (RW)
  elf_emit_u32_le(arr, 1)
  elf_emit_u32_le(arr, 6)
  elf_emit_u64_le(arr, data_offset)
  elf_emit_u64_le(arr, data_vaddr)
  elf_emit_u64_le(arr, data_vaddr)
  elf_emit_u64_le(arr, data_filesz)
  elf_emit_u64_le(arr, data_memsz)
  elf_emit_u64_le(arr, 4096)

  // Program Header 2: PT_GNU_STACK (RW, non-executable stack)
  elf_emit_u32_le(arr, 1685382481)
  elf_emit_u32_le(arr, 6)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 0)
  elf_emit_u64_le(arr, 16)
  return 0
@end

@fn elf_emit_wx_split_phdrs(arr, text_ro_filesz, data_offset, data_vaddr, data_filesz, data_memsz)
  return elf_emit_wx_split_phdrs_base(arr, 1073741824, text_ro_filesz, data_offset, data_vaddr, data_filesz, data_memsz)
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

@fn elf_emit_executable_mode(code_bytes, rodata_bytes, data_bytes, bss_size, machine, is_pie, output_path)
  // WHY: Sovereign standalone strict W^X ELF64 emitter (zero RWE segments),
  // supporting both Static-PIE (is_pie=1: ET_DYN=3, base_vaddr=0, full kernel ASLR)
  // and fixed-address ET_EXEC (is_pie=0: ET_EXEC=2, base_vaddr=0x40000000 for Unikernel/ARM64/RISC-V).
  base_vaddr = 1073741824 // 0x40000000 (1GB)
  e_type = 2              // ET_EXEC
  @if is_pie == 1
    base_vaddr = 0
    e_type = 3            // ET_DYN (Static-PIE Position-Independent Executable)
  @end
  start_stub_offset = 240 // 64 (ELF Header) + 168 (3 Phdrs) + 8 (align pad)
  entry_point_vaddr = base_vaddr + start_stub_offset

  stub_size = 0
  if machine == 0 || machine == 62
    stub_size = 64
  end

  code_file_offset = start_stub_offset
  code_size = stub_size + code_bytes.len()
  code_vaddr = base_vaddr + code_file_offset

  rodata_file_offset = code_file_offset + code_size
  rodata_size = rodata_bytes.len()
  rodata_vaddr = base_vaddr + rodata_file_offset

  text_ro_end = rodata_file_offset + rodata_size
  rem_page = text_ro_end % 4096
  pad_bytes = 0
  @if rem_page != 0
    pad_bytes = 4096 - rem_page
  @end

  data_file_offset = text_ro_end + pad_bytes
  data_vaddr = base_vaddr + data_file_offset

  // 1. Build .text payload (W^X PIE or fixed _start stub + user code)
  text_payload = list()
  if machine == 0 || machine == 62
    @if is_pie == 1
      start_stub = elf_build_start_stub_pie(0, data_file_offset)
    @else
      start_stub = elf_build_start_stub_wx(0, data_vaddr)
    @end
    elf_concat(text_payload, start_stub)
  end
  elf_concat(text_payload, code_bytes)

  // 1b. Build RW .data payload: 128-byte runtime globals (g_argc, g_argv, _heap_base, _heap_ptr, _slab_buckets) + user .data
  rw_payload = list()
  gi = 0
  @while gi < 128
    push(rw_payload, 0)
    gi = gi + 1
  @end
  elf_concat(rw_payload, data_bytes)
  data_size = rw_payload.len()
  data_memsz = data_size + bss_size

  shstr_file_offset = data_file_offset + data_size
  // .shstrtab content: \0.text\0.rodata\0.data\0.bss\0.shstrtab\0
  shstr_bytes = [
    0,
    46, 116, 101, 120, 116, 0,                      // .text\0 (offset 1)
    46, 114, 111, 100, 97, 116, 97, 0,              // .rodata\0 (offset 7)
    46, 100, 97, 116, 97, 0,                        // .data\0 (offset 15)
    46, 98, 115, 115, 0,                            // .bss\0 (offset 21)
    46, 115, 104, 115, 116, 114, 116, 97, 98, 0     // .shstrtab\0 (offset 26)
  ]
  shstr_size = shstr_bytes.len()

  sh_offset = shstr_file_offset + shstr_size
  num_sections = 6
  shstr_idx = 5

  // 2. Assemble complete W^X binary
  binary = list()

  // 2.1 ELF Header (64 bytes, e_phnum = 3)
  target_mach = 62
  if machine != 0
    target_mach = machine
  end
  elf_emit_header_machine_type(binary, entry_point_vaddr, sh_offset, num_sections, shstr_idx, target_mach, e_type)

  // 2.2 Strict W^X Program Headers (168 bytes) + 8-byte alignment pad
  elf_emit_wx_split_phdrs_base(binary, base_vaddr, text_ro_end, data_file_offset, data_vaddr, data_size, data_memsz)
  pi = 0
  @while pi < 8
    push(binary, 0)
    pi = pi + 1
  @end

  // 2.3 .text (code payload)
  elf_concat(binary, text_payload)

  // 2.4 .rodata
  elf_concat(binary, rodata_bytes)

  // 2.4b Pad to 4KB page boundary for hardware W^X page isolation
  pi = 0
  @while pi < pad_bytes
    push(binary, 0)
    pi = pi + 1
  @end

  // 2.5 .data (RW runtime globals + user .data)
  elf_concat(binary, rw_payload)

  // 2.6 .shstrtab
  elf_concat(binary, shstr_bytes)

  // 2.7 Section Headers (6 * 64 = 384 bytes)
  k = 0
  while k < 64
    push(binary, 0)
    k = k + 1
  end
  elf_emit_shdr_bits(binary, 1, 6, code_vaddr, code_file_offset, code_size)
  elf_emit_shdr_bits(binary, 7, 2, rodata_vaddr, rodata_file_offset, rodata_size)
  elf_emit_shdr_bits(binary, 15, 3, data_vaddr, data_file_offset, data_size)
  elf_emit_shdr_nobits(binary, 21, data_vaddr + data_size, data_file_offset + data_size, bss_size)
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
  end

  res.ew_success = 1
  res.ew_out_path = output_path
  res.ew_file_size = binary.len()
  res.ew_entry_vaddr = entry_point_vaddr
  res.ew_error_msg = ""
  res.ew_bytes = binary
  return res
@end

@fn elf_emit_executable_target(code_bytes, rodata_bytes, data_bytes, bss_size, machine, output_path)
  return elf_emit_executable_mode(code_bytes, rodata_bytes, data_bytes, bss_size, machine, 0, output_path)
@end

@fn elf_emit_executable_pie(code_bytes, rodata_bytes, data_bytes, bss_size, output_path)
  return elf_emit_executable_mode(code_bytes, rodata_bytes, data_bytes, bss_size, 62, 1, output_path)
@end

@fn elf_emit_executable(code_bytes, rodata_bytes, data_bytes, bss_size, output_path)
  return elf_emit_executable_target(code_bytes, rodata_bytes, data_bytes, bss_size, 62, output_path)
@end

@fn elf_emit_executable_debug_mode(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, is_pie, output_path)
  // WHY: Sovereign standalone strict W^X (+ optional Static-PIE) ELF64 emitter embedding DWARF v4/v5.
  base_vaddr = 1073741824
  e_type = 2
  @if is_pie == 1
    base_vaddr = 0
    e_type = 3
  @end
  start_stub_offset = 240
  entry_point_vaddr = base_vaddr + start_stub_offset

  code_file_offset = start_stub_offset
  code_size = 64 + code_bytes.len()
  code_vaddr = base_vaddr + code_file_offset

  rodata_file_offset = code_file_offset + code_size
  rodata_size = rodata_bytes.len()
  rodata_vaddr = base_vaddr + rodata_file_offset

  text_ro_end = rodata_file_offset + rodata_size
  rem_page = text_ro_end % 4096
  pad_bytes = 0
  @if rem_page != 0
    pad_bytes = 4096 - rem_page
  @end

  data_file_offset = text_ro_end + pad_bytes
  data_vaddr = base_vaddr + data_file_offset

  // 1. .text payload = W^X (PIE or fixed) _start stub + user code
  @if is_pie == 1
    start_stub = elf_build_start_stub_pie(0, data_file_offset)
  @else
    start_stub = elf_build_start_stub_wx(0, data_vaddr)
  @end
  text_payload = list()
  elf_concat(text_payload, start_stub)
  elf_concat(text_payload, code_bytes)

  rw_payload = list()
  gi = 0
  @while gi < 128
    push(rw_payload, 0)
    gi = gi + 1
  @end
  elf_concat(rw_payload, data_bytes)
  data_size = rw_payload.len()
  data_memsz = data_size + bss_size

  // DWARF debug sections: placed after loadable segments on disk
  debug_line_file_offset = data_file_offset + data_size
  debug_line_size = debug_line.len()

  debug_info_file_offset = debug_line_file_offset + debug_line_size
  debug_info_size = debug_info.len()

  debug_abbrev_file_offset = debug_info_file_offset + debug_info_size
  debug_abbrev_size = debug_abbrev.len()

  shstr_file_offset = debug_abbrev_file_offset + debug_abbrev_size
  shstr_bytes = [
    0,
    46, 116, 101, 120, 116, 0,
    46, 114, 111, 100, 97, 116, 97, 0,
    46, 100, 97, 116, 97, 0,
    46, 98, 115, 115, 0,
    46, 100, 101, 98, 117, 103, 95, 108, 105, 110, 101, 0,
    46, 100, 101, 98, 117, 103, 95, 105, 110, 102, 111, 0,
    46, 100, 101, 98, 117, 103, 95, 97, 98, 98, 114, 101, 118, 0,
    46, 115, 104, 115, 116, 114, 116, 97, 98, 0
  ]
  shstr_size = shstr_bytes.len()

  sh_offset = shstr_file_offset + shstr_size
  num_sections = 9
  shstr_idx = 8

  binary = list()
  elf_emit_header_machine_type(binary, entry_point_vaddr, sh_offset, num_sections, shstr_idx, 62, e_type)
  elf_emit_wx_split_phdrs_base(binary, base_vaddr, text_ro_end, data_file_offset, data_vaddr, data_size, data_memsz)
  pi = 0
  @while pi < 8
    push(binary, 0)
    pi = pi + 1
  @end

  // 2.3 .text (code with W^X _start stub)
  elf_concat(binary, text_payload)

  // 2.4 .rodata
  elf_concat(binary, rodata_bytes)

  // 2.4b Pad to 4KB page boundary for W^X isolation
  pi = 0
  @while pi < pad_bytes
    push(binary, 0)
    pi = pi + 1
  @end

  // 2.5 .data (RW runtime globals + user .data)
  elf_concat(binary, rw_payload)

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

@fn elf_emit_executable_with_debug(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, output_path)
  return elf_emit_executable_debug_mode(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, 0, output_path)
@end

@fn elf_emit_executable_pie_with_debug(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, output_path)
  return elf_emit_executable_debug_mode(code_bytes, rodata_bytes, data_bytes, bss_size, debug_line, debug_info, debug_abbrev, 1, output_path)
@end

@fn elf_emit_executable_wx(code_bytes, rodata_bytes, data_bytes, bss_size, output_path)
  // WHY: Strict W^X ELF64 emitter (unified with default elf_emit_executable_target).
  return elf_emit_executable_target(code_bytes, rodata_bytes, data_bytes, bss_size, 62, output_path)
@end
