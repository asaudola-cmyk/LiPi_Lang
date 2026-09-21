@! ============================================================================
@! MAYA COMPILER BACKEND — 100% PURE MAYA ELF64 NATIVE BINARY EMITTER
@! Module: compiler/backend/elf_writer.maya
@! Target Architecture: Linux x86-64 (System V AMD64 ABI & Linux Kernel Syscalls)
@! Zero External Assembler / Linker (GCC, Clang, LLD) Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"

@! ============================================================================
@! 1. CANONICAL ZERO-COLLISION STRUCT SCHEMAS
@! ============================================================================

@struct ElfHeader
  eh_ident: array
  eh_type: i64
  eh_machine: i64
  eh_version: i64
  eh_entry: i64
  eh_phoff: i64
  eh_shoff: i64
  eh_flags: i64
  eh_ehsize: i64
  eh_phentsize: i64
  eh_phnum: i64
  eh_shentsize: i64
  eh_shnum: i64
  eh_shstrndx: i64
@end

@struct ElfProgramHeader
  ph_type: i64
  ph_flags: i64
  ph_offset: i64
  ph_vaddr: i64
  ph_paddr: i64
  ph_filesz: i64
  ph_memsz: i64
  ph_align: i64
@end

@struct ElfSectionHeader
  sh_name: i64
  sh_type: i64
  sh_flags: i64
  sh_addr: i64
  sh_offset: i64
  sh_size: i64
  sh_link: i64
  sh_info: i64
  sh_addralign: i64
  sh_entsize: i64
@end

@struct ElfWriteResult
  ew_success: i64
  ew_out_path: string
  ew_file_size: i64
  ew_entry_vaddr: i64
  ew_error_msg: string
  ew_bytes: array
@end

@struct ElfByteBuf
  eb_bytes: array
  eb_size: i64
@end

@struct WordPack
  w0: i64
  w1: i64
  w2: i64
  w3: i64
  w4: i64
  w5: i64
  w6: i64
  w7: i64
@end

@! ============================================================================
@! 2. PURE MAYA BYTE BUFFER & INTEGER ENCODING UTILITIES
@! ============================================================================

@fn elf_bytebuf_new()
  return {
    eb_bytes: [],
    eb_size: 0
  }
@end

@fn elf_bytebuf_push(buf, byte_val)
  v = (byte_val % 256 + 256) % 256
  buf.eb_bytes = buf.eb_bytes.push(v)
  buf.eb_size = buf.eb_size + 1
  return buf
@end

@fn elf_bytebuf_push_bytes(buf, byte_list)
  i = 0
  num_items = byte_list.len()
  @while i < num_items
    b = byte_list[i]
    buf = elf_bytebuf_push(buf, b)
    i = i + 1
  @end
  return buf
@end

@fn elf_bytebuf_push16(buf, val)
  v = val
  @if v < 0
    v = v + 65536
  @end
  elf_bytebuf_push(buf, v % 256)
  elf_bytebuf_push(buf, (v / 256) % 256)
  return buf
@end

@fn elf_bytebuf_push32(buf, val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  elf_bytebuf_push(buf, v % 256)
  elf_bytebuf_push(buf, (v / 256) % 256)
  elf_bytebuf_push(buf, (v / 65536) % 256)
  elf_bytebuf_push(buf, (v / 16777216) % 256)
  return buf
@end

@fn elf_bytebuf_push64(buf, val)
  v = val
  i = 0
  @while i < 8
    b = v % 256
    @if b < 0
      b = b + 256
    @end
    elf_bytebuf_push(buf, b)
    v = (v - b) / 256
    i = i + 1
  @end
  return buf
@end

@fn elf_bytebuf_patch32(buf, offset, val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  b0 = v % 256
  b1 = (v / 256) % 256
  b2 = (v / 65536) % 256
  b3 = (v / 16777216) % 256
  buf.eb_bytes = list_set(buf.eb_bytes, offset, b0)
  buf.eb_bytes = list_set(buf.eb_bytes, offset + 1, b1)
  buf.eb_bytes = list_set(buf.eb_bytes, offset + 2, b2)
  buf.eb_bytes = list_set(buf.eb_bytes, offset + 3, b3)
  return buf
@end

@fn elf_bytebuf_to_bytes(buf)
  return buf.eb_bytes
@end

@fn elf_u16_le(v)
  val = v
  @if val < 0
    val = val + 65536
  @end
  return [val % 256, (val / 256) % 256]
@end

@fn elf_u32_le(v)
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

@fn elf_u64_le(v)
  val = v
  bytes = []
  i = 0
  @while i < 8
    b = val % 256
    @if b < 0
      b = b + 256
    @end
    bytes = bytes.push(b)
    val = (val - b) / 256
    i = i + 1
  @end
  return bytes
@end

@fn u16_to_bytes(v)
  return elf_u16_le(v)
@end

@fn u32_to_bytes(v)
  return elf_u32_le(v)
@end

@fn u64_to_bytes(v)
  return elf_u64_le(v)
@end

@fn elf_append(target, source)
  i = 0
  num_items = source.len()
  @while i < num_items
    item = source[i]
    target = target.push(item)
    i = i + 1
  @end
  return target
@end

@fn elf_append_bytes(target, source)
  return elf_append(target, source)
@end

@! ============================================================================
@! 3. DIRECT BIT-PERFECT WORD-PACKED SYSCALL SERIALIZER
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

@fn elf_write_bytes_to_fd(fd, byte_list)
  @! Direct memory-mapped raw binary serializer
  @! WHY: Anonymous map/struct literals { w0: ... } are not raw byte buffers in Maya's object model.
  @! Using sys_mmap creates a dedicated page-aligned raw buffer in Linux kernel memory,
  @! sys_poke8 writes byte-exact data at offset i, and sys_write sends the raw buffer to the file descriptor.
  total = byte_list.len()
  @if total <= 0 return 0 @end
  buf = sys_mmap(0, total + 16, 3, 34, 0 - 1, 0)
  @if buf <= 0 return 0 - 1 @end
  i = 0
  @while i < total
    sys_poke8(buf + i, byte_list[i])
    i = i + 1
  @end
  written = sys_write(fd, buf, total)
  return written
@end

@fn elf_write_file(output_path, byte_list)
  @! O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577, mode 0755 = 493
  fd = sys_open(output_path, 577, 493)
  @if fd < 0
    return 0 - 1
  @end

  status = elf_write_bytes_to_fd(fd, byte_list)
  sys_close(fd)

  @! Explicitly apply 0755 permissions via sys_chmod (Linux syscall 90)
  sys_chmod(output_path, 493)

  return status
@end

@! ============================================================================
@! 4. LINUX STANDALONE _start ENTRY STUB BUILDER (32 Bytes)
@! ============================================================================

@fn elf_build_start_stub(main_entry_offset)
  @! Linux x86-64 Standalone _start Entry Stub (64 bytes):
  @! 0x00: 31 ED                      (xor ebp, ebp)
  @! 0x02: 48 8B 04 24                (mov rax, [rsp] -> argc)
  @! 0x06: 48 89 05 23 00 00 00       (mov [rip + 0x23], rax -> 0x30 = g_argc)
  @! 0x0D: 48 8D 44 24 08             (lea rax, [rsp + 8] -> argv)
  @! 0x12: 48 89 05 1F 00 00 00       (mov [rip + 0x1F], rax -> 0x38 = g_argv)
  @! 0x19: E8 xx xx xx xx             (call main) -> next PC = 0x1E (30). rel32 = (64 - 30) + main_entry_offset = 34 + main_entry_offset
  @! 0x1E: 48 89 C7                   (mov rdi, rax)
  @! 0x21: B8 3C 00 00 00             (mov eax, 60 -> sys_exit)
  @! 0x26: 0F 05                      (syscall)
  @! 0x28: F4                         (hlt)
  @! 0x29..0x2F: 7 x NOP (0x90) -> pads to 0x30 (48 bytes)
  @! 0x30..0x37: 8 bytes 0 (g_argc) at 0x400078 + 0x30 = 0x4000A8 (4194472)
  @! 0x38..0x3F: 8 bytes 0 (g_argv) at 0x400078 + 0x38 = 0x4000B0 (4194480)

  rel32 = 34 + main_entry_offset
  stub = [
    49, 237,                      @! xor ebp, ebp (2 bytes)
    72, 139, 4, 36,               @! mov rax, [rsp] (4 bytes)
    72, 137, 5, 35, 0, 0, 0,      @! mov [rip + 0x23], rax (7 bytes)
    72, 141, 68, 36, 8,           @! lea rax, [rsp + 8] (5 bytes)
    72, 137, 5, 31, 0, 0, 0,      @! mov [rip + 0x1F], rax (7 bytes)
    232,                          @! call rel32 opcode (1 byte)
    rel32 % 256,
    (rel32 / 256) % 256,
    (rel32 / 65536) % 256,
    (rel32 / 16777216) % 256,     @! rel32 displacement (4 bytes)
    72, 137, 199,                 @! mov rdi, rax (3 bytes)
    184, 60, 0, 0, 0,             @! mov eax, 60 (5 bytes)
    15, 5,                        @! syscall (2 bytes)
    244                           @! hlt (1 byte)
  ]
  @while stub.len() < 48
    stub = stub.push(144)         @! NOP padding to 48 bytes (0x30)
  @end
  k = 0
  @while k < 8
    stub = stub.push(0)           @! g_argc = 0
    k = k + 1
  @end
  k = 0
  @while k < 8
    stub = stub.push(0)           @! g_argv = 0
    k = k + 1
  @end
  return stub
@end

@! ============================================================================
@! 5. ELF64 HEADER BUILDERS (64-byte Header, 56-byte Program Header, 64-byte Section Header)
@! ============================================================================

@fn elf_build_header(entry_point, sh_offset, sh_count, sh_strndx)
  hdr = [
    127, 69, 76, 70,              @! Magic: 0x7F, 'E', 'L', 'F'
    2,                            @! 64-bit ELF (ELFCLASS64)
    1,                            @! Little Endian (ELFDATA2LSB)
    1,                            @! Current ELF Version (EV_CURRENT)
    0, 0, 0, 0, 0, 0, 0, 0, 0,    @! System V OSABI & 8-byte padding
    2, 0,                         @! ET_EXEC (Executable file)
    62, 0,                        @! EM_X86_64 (AMD x86-64)
    1, 0, 0, 0                    @! EV_CURRENT (1)
  ]
  hdr = elf_append(hdr, elf_u64_le(entry_point))  @! e_entry
  hdr = elf_append(hdr, elf_u64_le(64))           @! e_phoff (64)
  hdr = elf_append(hdr, elf_u64_le(sh_offset))    @! e_shoff
  hdr = elf_append(hdr, elf_u32_le(0))            @! e_flags
  hdr = elf_append(hdr, elf_u16_le(64))           @! e_ehsize (64 bytes)
  hdr = elf_append(hdr, elf_u16_le(56))           @! e_phentsize (56 bytes)
  hdr = elf_append(hdr, elf_u16_le(1))            @! e_phnum (1 PT_LOAD)
  hdr = elf_append(hdr, elf_u16_le(64))           @! e_shentsize (64 bytes)
  hdr = elf_append(hdr, elf_u16_le(sh_count))     @! e_shnum
  hdr = elf_append(hdr, elf_u16_le(sh_strndx))    @! e_shstrndx
  return hdr
@end

@fn elf_create_header_struct(entry_point, sh_offset, sh_count, sh_strndx)
  return {
    eh_ident: [127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    eh_type: 2,
    eh_machine: 62,
    eh_version: 1,
    eh_entry: entry_point,
    eh_phoff: 64,
    eh_shoff: sh_offset,
    eh_flags: 0,
    eh_ehsize: 64,
    eh_phentsize: 56,
    eh_phnum: 1,
    eh_shentsize: 64,
    eh_shnum: sh_count,
    eh_shstrndx: sh_strndx
  }
@end

@fn elf_header_to_bytes(ehdr)
  hdr = []
  hdr = elf_append(hdr, ehdr.eh_ident)
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_type))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_machine))
  hdr = elf_append(hdr, elf_u32_le(ehdr.eh_version))
  hdr = elf_append(hdr, elf_u64_le(ehdr.eh_entry))
  hdr = elf_append(hdr, elf_u64_le(ehdr.eh_phoff))
  hdr = elf_append(hdr, elf_u64_le(ehdr.eh_shoff))
  hdr = elf_append(hdr, elf_u32_le(ehdr.eh_flags))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_ehsize))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_phentsize))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_phnum))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_shentsize))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_shnum))
  hdr = elf_append(hdr, elf_u16_le(ehdr.eh_shstrndx))
  return hdr
@end

@fn elf_build_program_header(file_size, mem_size)
  ph = [
    1, 0, 0, 0,                   @! p_type: PT_LOAD (1)
    7, 0, 0, 0                    @! p_flags: PF_R | PF_W | PF_X (7)
  ]
  ph = elf_append(ph, elf_u64_le(0))              @! p_offset (0)
  ph = elf_append(ph, elf_u64_le(4194304))        @! p_vaddr (0x400000)
  ph = elf_append(ph, elf_u64_le(4194304))        @! p_paddr (0x400000)
  ph = elf_append(ph, elf_u64_le(file_size))      @! p_filesz
  ph = elf_append(ph, elf_u64_le(mem_size))       @! p_memsz
  ph = elf_append(ph, elf_u64_le(4096))           @! p_align (0x1000 = 4096)
  return ph
@end

@fn elf_create_program_header_struct(file_size, mem_size)
  return {
    ph_type: 1,
    ph_flags: 7,
    ph_offset: 0,
    ph_vaddr: 4194304,
    ph_paddr: 4194304,
    ph_filesz: file_size,
    ph_memsz: mem_size,
    ph_align: 4096
  }
@end

@fn elf_program_header_to_bytes(phdr)
  ph = []
  ph = elf_append(ph, elf_u32_le(phdr.ph_type))
  ph = elf_append(ph, elf_u32_le(phdr.ph_flags))
  ph = elf_append(ph, elf_u64_le(phdr.ph_offset))
  ph = elf_append(ph, elf_u64_le(phdr.ph_vaddr))
  ph = elf_append(ph, elf_u64_le(phdr.ph_paddr))
  ph = elf_append(ph, elf_u64_le(phdr.ph_filesz))
  ph = elf_append(ph, elf_u64_le(phdr.ph_memsz))
  ph = elf_append(ph, elf_u64_le(phdr.ph_align))
  return ph
@end

@fn elf_build_section_header(name_off, type_flags, flags, addr, offset, size, link, info, align, entsize)
  sh = []
  sh = elf_append(sh, elf_u32_le(name_off))
  sh = elf_append(sh, elf_u32_le(type_flags))
  sh = elf_append(sh, elf_u64_le(flags))
  sh = elf_append(sh, elf_u64_le(addr))
  sh = elf_append(sh, elf_u64_le(offset))
  sh = elf_append(sh, elf_u64_le(size))
  sh = elf_append(sh, elf_u32_le(link))
  sh = elf_append(sh, elf_u32_le(info))
  sh = elf_append(sh, elf_u64_le(align))
  sh = elf_append(sh, elf_u64_le(entsize))
  return sh
@end

@fn elf_make_section_header(name_offset, type_flags, flags, addr, offset, size, link, info, addralign, entsize)
  return elf_build_section_header(name_offset, type_flags, flags, addr, offset, size, link, info, addralign, entsize)
@end

@fn elf_create_section_header_struct(name_off, type_flags, flags, addr, offset, size, link, info, align, entsize)
  return {
    sh_name: name_off,
    sh_type: type_flags,
    sh_flags: flags,
    sh_addr: addr,
    sh_offset: offset,
    sh_size: size,
    sh_link: link,
    sh_info: info,
    sh_addralign: align,
    sh_entsize: entsize
  }
@end

@fn elf_section_header_to_bytes(shdr)
  sh = []
  sh = elf_append(sh, elf_u32_le(shdr.sh_name))
  sh = elf_append(sh, elf_u32_le(shdr.sh_type))
  sh = elf_append(sh, elf_u64_le(shdr.sh_flags))
  sh = elf_append(sh, elf_u64_le(shdr.sh_addr))
  sh = elf_append(sh, elf_u64_le(shdr.sh_offset))
  sh = elf_append(sh, elf_u64_le(shdr.sh_size))
  sh = elf_append(sh, elf_u32_le(shdr.sh_link))
  sh = elf_append(sh, elf_u32_le(shdr.sh_info))
  sh = elf_append(sh, elf_u64_le(shdr.sh_addralign))
  sh = elf_append(sh, elf_u64_le(shdr.sh_entsize))
  return sh
@end

@! ============================================================================
@! 6. PRIMARY API: elf_write_executable(x86_result, output_path)
@! ============================================================================

@fn elf_write_executable(x86_result, output_path)
  @! 1. Extract Machine Code & Read-Only Data
  text_src = []
  rodata_src = []
  entry_off = 0

  @if x86_result != 0
    @if x86_result.text_bytes != 0
      text_src = x86_result.text_bytes
    @end
    @if x86_result.rodata_bytes != 0
      rodata_src = x86_result.rodata_bytes
    @end
    entry_off = x86_result.entry_offset
  @end

  @! 2. Build .text with Linux Standalone _start Entry Stub (32 bytes)
  start_stub = elf_build_start_stub(entry_off)
  full_text = []
  full_text = elf_append(full_text, start_stub)
  full_text = elf_append(full_text, text_src)

  @! Ensure .text is 16-byte aligned
  @while full_text.len() % 16 != 0
    full_text = full_text.push(144) @! NOP (0x90)
  @end
  text_size = full_text.len()

  @! 3. Build .rodata
  full_rodata = []
  @if rodata_src != 0
    full_rodata = elf_append(full_rodata, rodata_src)
  @end
  @! Ensure .rodata is 8-byte aligned
  @while full_rodata.len() % 8 != 0
    full_rodata = full_rodata.push(0)
  @end
  rodata_size = full_rodata.len()

  @! 4. Build .shstrtab String Table
  @! Indices: \0 (0), .text\0 (1..6), .rodata\0 (7..14), .shstrtab\0 (15..24)
  shstrtab = [
    0,
    46, 116, 101, 120, 116, 0,
    46, 114, 111, 100, 97, 116, 97, 0,
    46, 115, 104, 115, 116, 114, 116, 97, 98, 0
  ]
  shstrtab_size = shstrtab.len()

  @! 5. Calculate File Offsets and Virtual Memory Addresses (Base = 0x400000)
  ehdr_size = 64
  phdr_size = 56
  text_offset = ehdr_size + phdr_size @! 120 (0x78)
  entry_vaddr = 4194304 + text_offset @! 0x400078 (4194424)

  rodata_offset = text_offset + text_size
  rodata_vaddr = 4194304 + rodata_offset

  shstrtab_offset = rodata_offset + rodata_size
  sh_offset = shstrtab_offset + shstrtab_size
  rem_sh = sh_offset % 8
  @if rem_sh != 0
    sh_offset = sh_offset + (8 - rem_sh)
  @end

  total_mem_size = rodata_offset + rodata_size

  @! 6. Synthesize 64-byte ELF Header & 56-byte Program Header
  ehdr = elf_build_header(entry_vaddr, sh_offset, 4, 3)
  phdr = elf_build_program_header(total_mem_size, total_mem_size)

  @! 7. Synthesize Section Headers (4 entries: Null, .text, .rodata, .shstrtab)
  sh_null = elf_build_section_header(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  sh_text = elf_build_section_header(1, 1, 6, entry_vaddr, text_offset, text_size, 0, 0, 16, 0)
  sh_rodata = elf_build_section_header(7, 1, 2, rodata_vaddr, rodata_offset, rodata_size, 0, 0, 8, 0)
  sh_shstrtab = elf_build_section_header(15, 3, 0, 0, shstrtab_offset, shstrtab_size, 0, 0, 1, 0)

  @! 8. Assemble Complete Binary Byte Vector
  final_bin = []
  final_bin = elf_append(final_bin, ehdr)
  final_bin = elf_append(final_bin, phdr)
  final_bin = elf_append(final_bin, full_text)
  final_bin = elf_append(final_bin, full_rodata)
  final_bin = elf_append(final_bin, shstrtab)

  @! Align to section header table offset
  @while final_bin.len() < sh_offset
    final_bin = final_bin.push(0)
  @end

  final_bin = elf_append(final_bin, sh_null)
  final_bin = elf_append(final_bin, sh_text)
  final_bin = elf_append(final_bin, sh_rodata)
  final_bin = elf_append(final_bin, sh_shstrtab)

  @! 9. Direct File Serialization via Linux Syscalls & Apply 0755 Mode
  write_status = elf_write_file(output_path, final_bin)
  @if write_status < 0
    return {
      ew_success: 0,
      ew_out_path: output_path,
      ew_file_size: 0,
      ew_entry_vaddr: 0,
      ew_error_msg: "Failed to write ELF binary to disk",
      ew_bytes: []
    }
  @end

  return {
    ew_success: 1,
    ew_out_path: output_path,
    ew_file_size: final_bin.len(),
    ew_entry_vaddr: entry_vaddr,
    ew_error_msg: "",
    ew_bytes: final_bin
  }
@end

@! ============================================================================
@! 7. BACKWARDS-COMPATIBLE EMITTER HELPER
@! ============================================================================

@fn emit_elf_64_executable(out_path, machine_code_bytes)
  spec = { text_bytes: machine_code_bytes, rodata_bytes: [], symbol_offsets: [], symbols: [], entry_offset: 0 }
  res = elf_write_executable(spec, out_path)
  @if res.ew_success == 1
    return out_path
  @end
  return ""
@end
