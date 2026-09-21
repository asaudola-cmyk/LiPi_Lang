// ============================================================================
// LIPI SOVEREIGN COMPILER — ELF64 HEADER SERIALIZER
// Module: src/compiler/backend/formats/elf/elf_header.lp
// Standard: System V Application Binary Interface AMD64 / ELF-64 Object File Format
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: The ELF (Executable and Linkable Format) 64-bit header is the mandatory
// first 64 bytes (0x00 - 0x3F) of any standard Linux/BSD 64-bit binary.
// Operating system loaders (e.g., Linux kernel fs/binfmt_elf.c) read this exact
// layout before creating the virtual memory space, configuring segment permissions,
// and jumping to the entry point address.

// --- ELF Magic Identification Constants ---
// WHY: The 4-byte magic signature 0x7F, 'E', 'L', 'F' (0x7F, 0x45, 0x4C, 0x46)
// identifies the file format unequivocally across UNIX systems.
@fn ELF_MAG0() return 127 @end // 0x7F
@fn ELF_MAG1() return 69  @end // 'E'
@fn ELF_MAG2() return 76  @end // 'L'
@fn ELF_MAG3() return 70  @end // 'F'

// --- EI_CLASS: File Class (Architecture Bit Width) ---
// WHY: Distinguishes 32-bit (ELFCLASS32=1) from 64-bit (ELFCLASS64=2) address spaces.
// 64-bit uses 8-byte pointer offsets and 64-byte ELF headers.
@fn ELFCLASSNONE() return 0 @end
@fn ELFCLASS32()   return 1 @end
@fn ELFCLASS64()   return 2 @end

// --- EI_DATA: Data Encoding (Endianness) ---
// WHY: Dictates multi-byte integer byte ordering.
// ELFDATA2LSB (1) means Least Significant Byte first (Little-Endian, used by x86-64 and AArch64).
// ELFDATA2MSB (2) means Most Significant Byte first (Big-Endian).
@fn ELFDATANONE() return 0 @end
@fn ELFDATA2LSB() return 1 @end // Little Endian
@fn ELFDATA2MSB() return 2 @end // Big Endian

// --- EI_VERSION / EV_CURRENT: ELF Specification Version ---
// WHY: ELF standard version is always 1 (EV_CURRENT). Any other value is rejected by kernel.
@fn EV_NONE()    return 0 @end
@fn EV_CURRENT() return 1 @end

// --- EI_OSABI: Target Operating System ABI ---
// WHY: Identifies OS ABI conventions. 0 is System V (covers standard Linux glibc/musl/bare-metal),
// while 3 is Linux-specific (for features like STB_GNU_UNIQUE).
@fn ELFOSABI_NONE()       return 0 @end // System V AMD64 ABI
@fn ELFOSABI_SYSV()       return 0 @end // Alias System V
@fn ELFOSABI_HPUX()       return 1 @end
@fn ELFOSABI_NETBSD()     return 2 @end
@fn ELFOSABI_LINUX()      return 3 @end // Linux ABI
@fn ELFOSABI_SOLARIS()    return 6 @end
@fn ELFOSABI_FREEBSD()    return 9 @end
@fn ELFOSABI_OPENBSD()    return 12 @end
@fn ELFOSABI_ARM_AEABI()   return 64 @end
@fn ELFOSABI_STANDALONE() return 255 @end

// --- e_type: Object File Type ---
// WHY: Tells the OS loader whether this file is a relocatable object (.o),
// a static/fixed executable (ET_EXEC), a shared library / Position Independent Executable (ET_DYN),
// or a core dump (ET_CORE).
@fn ET_NONE() return 0 @end // No file type
@fn ET_REL()  return 1 @end // Relocatable object file (.o)
@fn ET_EXEC() return 2 @end // Executable binary (fixed virtual address, e.g. 0x400000)
@fn ET_DYN()  return 3 @end // Shared object / Position Independent Executable (.so / PIE)
@fn ET_CORE() return 4 @end // Core dump file

// --- e_machine: Target Instruction Set Architecture ---
// WHY: Ensures the CPU hardware matches the instructions emitted by the compiler.
// Kernel checks e_machine against current CPU family before executing.
@fn EM_NONE()    return 0   @end
@fn EM_386()     return 3   @end // Intel 80386 (x86 32-bit)
@fn EM_X86_64()  return 62  @end // AMD x86-64 / Intel 64 (0x3E)
@fn EM_ARM()     return 40  @end // ARM 32-bit
@fn EM_AARCH64() return 183 @end // ARM 64-bit AArch64 (0xB7)
@fn EM_RISCV()   return 243 @end // RISC-V (0xF3)

// --- Fixed Sizes for ELF64 Specification ---
// WHY: In ELF64, header sizes are strictly standardized:
// ELF header = 64 bytes, Program Header = 56 bytes, Section Header = 64 bytes.
@fn ELF64_HDR_SIZE()    return 64 @end
@fn ELF64_PHDR_SIZE()   return 56 @end
@fn ELF64_SHDR_SIZE()   return 64 @end

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct Elf64Header
  e_ident: array      // 16 bytes identification array
  e_type: i64         // 2 bytes: ET_EXEC, ET_DYN, ET_REL
  e_machine: i64      // 2 bytes: EM_X86_64, EM_AARCH64, EM_RISCV
  e_version: i64      // 4 bytes: EV_CURRENT (1)
  e_entry: i64        // 8 bytes: Virtual memory entry point address
  e_phoff: i64        // 8 bytes: Program header table file offset (typically 64)
  e_shoff: i64        // 8 bytes: Section header table file offset
  e_flags: i64        // 4 bytes: Architecture-specific processor flags
  e_ehsize: i64       // 2 bytes: ELF header size in bytes (64)
  e_phentsize: i64    // 2 bytes: Size of one program header entry (56)
  e_phnum: i64        // 2 bytes: Number of program header entries
  e_shentsize: i64    // 2 bytes: Size of one section header entry (64)
  e_shnum: i64        // 2 bytes: Number of section header entries
  e_shstrndx: i64     // 2 bytes: Section index of the section name string table (.shstrtab)
@end

// ============================================================================
// 2. BYTE ENCODING PRIMITIVES (LITTLE-ENDIAN SYSTEM V AMD64 & AARCH64)
// ============================================================================

@fn elf_pack_u16_le(val)
  // WHY: Encodes a 16-bit unsigned integer into 2 bytes in Little-Endian order.
  // Masking handles negative signed integer wrapping cleanly.
  v = val
  @if v < 0
    v = v + 65536
  @end
  return [v % 256, (v / 256) % 256]
@end

@fn elf_pack_u32_le(val)
  // WHY: Encodes a 32-bit unsigned integer into 4 bytes in Little-Endian order.
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  b0 = v % 256
  b1 = (v / 256) % 256
  b2 = (v / 65536) % 256
  b3 = (v / 16777216) % 256
  return [b0, b1, b2, b3]
@end

@fn elf_pack_u64_le(val)
  // WHY: Encodes a 64-bit unsigned integer into 8 bytes in Little-Endian order.
  // Iterative division guarantees bit-exact extraction without floating-point loss.
  v = val
  bytes = []
  i = 0
  @while i < 8
    b = v % 256
    @if b < 0
      b = b + 256
    @end
    bytes = bytes.push(b)
    v = (v - b) / 256
    i = i + 1
  @end
  return bytes
@end

// ============================================================================
// 3. ELF64 IDENTIFICATION BUILDER (e_ident)
// ============================================================================

@fn elf_ident_create(osabi, abiversion)
  // WHY: Build the canonical 16-byte ELF identification sequence.
  // Bytes 0-3:   Magic (0x7F, 'E', 'L', 'F')
  // Byte 4:      64-bit architecture (ELFCLASS64 = 2)
  // Byte 5:      Little Endian encoding (ELFDATA2LSB = 1)
  // Byte 6:      ELF version (EV_CURRENT = 1)
  // Byte 7:      Target OS ABI (e.g. System V = 0, Linux = 3)
  // Byte 8:      ABI Version (0 for standard ELF)
  // Bytes 9-15:  Reserved padding zeroes (7 bytes)
  ident = [
    ELF_MAG0(),
    ELF_MAG1(),
    ELF_MAG2(),
    ELF_MAG3(),
    ELFCLASS64(),
    ELFDATA2LSB(),
    EV_CURRENT(),
    osabi,
    abiversion,
    0, 0, 0, 0, 0, 0, 0 // 7 reserved bytes
  ]
  return ident
@end

// ============================================================================
// 4. ELF64 HEADER FACTORY
// ============================================================================

@fn elf_header_create(machine, entry_point, phoff, shoff, phnum, shnum)
  // WHY: Construct a fully populated Elf64Header struct.
  // Distinguishes between fixed static executables (ET_EXEC = 2) and shared/PIE (ET_DYN = 3).
  // Automatically sets standard 64-bit header sizes (ehsize=64, phentsize=56, shentsize=64).
  // Kept to <= 6 parameters for System V register calling convention compliance.
  file_type = ET_EXEC()
  shstrndx = 0
  @if shnum > 0
    shstrndx = shnum - 1
  @end

  return {
    e_ident: elf_ident_create(ELFOSABI_SYSV(), 0),
    e_type: file_type,
    e_machine: machine,
    e_version: EV_CURRENT(),
    e_entry: entry_point,
    e_phoff: phoff,
    e_shoff: shoff,
    e_flags: 0,
    e_ehsize: ELF64_HDR_SIZE(),
    e_phentsize: ELF64_PHDR_SIZE(),
    e_phnum: phnum,
    e_shentsize: ELF64_SHDR_SIZE(),
    e_shnum: shnum,
    e_shstrndx: shstrndx
  }
@end

@fn elf_header_x86_64(entry_point, phoff, shoff, phnum, shnum)
  // WHY: Convenience helper for AMD64 (x86-64) Linux binaries.
  return elf_header_create(EM_X86_64(), entry_point, phoff, shoff, phnum, shnum)
@end

@fn elf_header_aarch64(entry_point, phoff, shoff, phnum, shnum)
  // WHY: Convenience helper for 64-bit ARM (AArch64) Linux binaries.
  return elf_header_create(EM_AARCH64(), entry_point, phoff, shoff, phnum, shnum)
@end

// ============================================================================
// 5. ELF64 HEADER SERIALIZER (64 Bytes Out)
// ============================================================================

@fn elf_header_serialize(hdr)
  // WHY: Serializes the Elf64Header into exactly 64 contiguous bytes.
  // Kernel loader verifies:
  // Offset 0x00: e_ident (16 bytes)
  // Offset 0x10: e_type (2 bytes)
  // Offset 0x12: e_machine (2 bytes)
  // Offset 0x14: e_version (4 bytes)
  // Offset 0x18: e_entry (8 bytes)
  // Offset 0x20: e_phoff (8 bytes)
  // Offset 0x28: e_shoff (8 bytes)
  // Offset 0x30: e_flags (4 bytes)
  // Offset 0x34: e_ehsize (2 bytes)
  // Offset 0x36: e_phentsize (2 bytes)
  // Offset 0x38: e_phnum (2 bytes)
  // Offset 0x3A: e_shentsize (2 bytes)
  // Offset 0x3C: e_shnum (2 bytes)
  // Offset 0x3E: e_shstrndx (2 bytes)
  // Total: 64 bytes exactly.
  out = []

  // 1. e_ident (16 bytes)
  i = 0
  ident = hdr.e_ident
  @while i < 16
    out = out.push(ident[i])
    i = i + 1
  @end

  // 2. e_type (2 bytes)
  t_bytes = elf_pack_u16_le(hdr.e_type)
  out = out.push(t_bytes[0])
  out = out.push(t_bytes[1])

  // 3. e_machine (2 bytes)
  m_bytes = elf_pack_u16_le(hdr.e_machine)
  out = out.push(m_bytes[0])
  out = out.push(m_bytes[1])

  // 4. e_version (4 bytes)
  v_bytes = elf_pack_u32_le(hdr.e_version)
  out = out.push(v_bytes[0])
  out = out.push(v_bytes[1])
  out = out.push(v_bytes[2])
  out = out.push(v_bytes[3])

  // 5. e_entry (8 bytes)
  e_bytes = elf_pack_u64_le(hdr.e_entry)
  i = 0
  @while i < 8
    out = out.push(e_bytes[i])
    i = i + 1
  @end

  // 6. e_phoff (8 bytes)
  pho_bytes = elf_pack_u64_le(hdr.e_phoff)
  i = 0
  @while i < 8
    out = out.push(pho_bytes[i])
    i = i + 1
  @end

  // 7. e_shoff (8 bytes)
  sho_bytes = elf_pack_u64_le(hdr.e_shoff)
  i = 0
  @while i < 8
    out = out.push(sho_bytes[i])
    i = i + 1
  @end

  // 8. e_flags (4 bytes)
  f_bytes = elf_pack_u32_le(hdr.e_flags)
  out = out.push(f_bytes[0])
  out = out.push(f_bytes[1])
  out = out.push(f_bytes[2])
  out = out.push(f_bytes[3])

  // 9. e_ehsize (2 bytes, 64)
  eh_bytes = elf_pack_u16_le(hdr.e_ehsize)
  out = out.push(eh_bytes[0])
  out = out.push(eh_bytes[1])

  // 10. e_phentsize (2 bytes, 56)
  ph_bytes = elf_pack_u16_le(hdr.e_phentsize)
  out = out.push(ph_bytes[0])
  out = out.push(ph_bytes[1])

  // 11. e_phnum (2 bytes)
  phn_bytes = elf_pack_u16_le(hdr.e_phnum)
  out = out.push(phn_bytes[0])
  out = out.push(phn_bytes[1])

  // 12. e_shentsize (2 bytes, 64)
  sh_bytes = elf_pack_u16_le(hdr.e_shentsize)
  out = out.push(sh_bytes[0])
  out = out.push(sh_bytes[1])

  // 13. e_shnum (2 bytes)
  shn_bytes = elf_pack_u16_le(hdr.e_shnum)
  out = out.push(shn_bytes[0])
  out = out.push(shn_bytes[1])

  // 14. e_shstrndx (2 bytes)
  shs_bytes = elf_pack_u16_le(hdr.e_shstrndx)
  out = out.push(shs_bytes[0])
  out = out.push(shs_bytes[1])

  return out
@end

// ============================================================================
// 6. VALIDATION & SANITY CHECKS
// ============================================================================

@fn elf_header_validate(raw_bytes)
  // WHY: Asserts that a serialized buffer conforms to ELF64 rules:
  // 1. Must be at least 64 bytes.
  // 2. Must start with \x7F ELF.
  // 3. Class must be ELFCLASS64 (2).
  // 4. Endianness must be Little-Endian (1).
  // 5. Version must be EV_CURRENT (1).
  // Returns 1 if valid, 0 otherwise.
  @if raw_bytes.len() < 64 return 0 @end
  @if raw_bytes[0] != ELF_MAG0() return 0 @end
  @if raw_bytes[1] != ELF_MAG1() return 0 @end
  @if raw_bytes[2] != ELF_MAG2() return 0 @end
  @if raw_bytes[3] != ELF_MAG3() return 0 @end
  @if raw_bytes[4] != ELFCLASS64() return 0 @end
  @if raw_bytes[5] != ELFDATA2LSB() return 0 @end
  @if raw_bytes[6] != EV_CURRENT() return 0 @end
  return 1
@end
