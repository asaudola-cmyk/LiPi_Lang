// ============================================================================
// LIPI SOVEREIGN COMPILER — ELF64 PROGRAM HEADER GENERATOR
// Module: src/compiler/backend/formats/elf/program_header.lp
// Standard: System V AMD64 ABI / Linux ELF64 Program Header (Phdr) Table
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

// WHY: Program headers (also known as segment headers) guide the operating
// system kernel's virtual memory subsystem (mmap / execve) on how to map
// binary chunks from disk into hardware-protected CPU virtual pages.
// Each Elf64_Phdr structure is exactly 56 bytes long.

// --- Program Header Types (p_type) ---
// WHY: Tells the kernel loader what kind of action to take for this segment.
@fn PT_NULL()          return 0          @end // Unused entry
@fn PT_LOAD()          return 1          @end // Loadable segment mapped into virtual memory
@fn PT_DYNAMIC()       return 2          @end // Dynamic linking information (.dynamic)
@fn PT_INTERP()        return 3          @end // Program interpreter path string (e.g., /lib64/ld-linux-x86-64.so.2)
@fn PT_NOTE()          return 4          @end // Auxiliary vendor / build identification notes (.note.gnu.build-id)
@fn PT_SHLIB()         return 5          @end // Reserved (unspecified semantics)
@fn PT_PHDR()          return 6          @end // Program header table location within memory image
@fn PT_TLS()           return 7          @end // Thread-Local Storage initialization image
@fn PT_GNU_EH_FRAME()  return 1685382480 @end // 0x6474E550: GCC exception handling unwind tables (.eh_frame_hdr)
@fn PT_GNU_STACK()     return 1685382481 @end // 0x6474E551: Controls executable stack permission (NX / DEP security)
@fn PT_GNU_RELRO()     return 1685382482 @end // 0x6474E552: Read-only after relocation (ROP mitigation)

// --- Segment Access Permission Flags (p_flags) ---
// WHY: Enforces hardware Memory Management Unit (MMU) page permissions.
// Enforces W^X (Write XOR Execute) so code cannot be overwritten, and data/stack cannot execute.
@fn PF_X() return 1 @end // Execute permission
@fn PF_W() return 2 @end // Write permission
@fn PF_R() return 4 @end // Read permission

// Common compound permission masks:
@fn PF_R_X()   return 5 @end // Read + Execute (Code / .text)
@fn PF_R_W()   return 6 @end // Read + Write (Initialized data, BSS, Heap, Stack)
@fn PF_R_W_X() return 7 @end // Read + Write + Execute (Avoid: violates W^X security principle)

// --- Memory Page Constants ---
// WHY: Standard x86-64 and AArch64 virtual memory pages are 4096 bytes (4KB).
// Huge pages are 2MB (2097152 bytes). The ELF specification requires:
// (p_vaddr % p_align) == (p_offset % p_align) for the kernel to mmap directly.
@fn ELF_PAGE_SIZE_4K()  return 4096    @end
@fn ELF_PAGE_SIZE_2M()  return 2097152 @end
@fn ELF64_PHDR_BYTES()  return 56      @end

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct Elf64ProgramHeader
  p_type: i64   // 4 bytes: PT_LOAD, PT_GNU_STACK, etc.
  p_flags: i64  // 4 bytes: PF_R, PF_W, PF_X bitmask
  p_offset: i64 // 8 bytes: Segment file offset on disk
  p_vaddr: i64  // 8 bytes: Target virtual address in virtual memory
  p_paddr: i64  // 8 bytes: Physical address (usually equal to vaddr)
  p_filesz: i64 // 8 bytes: Byte count of data present in executable file
  p_memsz: i64  // 8 bytes: Byte count of memory footprint (memsz >= filesz; diff is .bss)
  p_align: i64  // 8 bytes: Memory & file alignment boundary (typically 4096)
@end

// ============================================================================
// 2. PAGE ALIGNMENT UTILITIES
// ============================================================================

@fn elf_page_align_up(val, page_size)
  // WHY: Rounds an address or offset UP to the nearest multiple of page_size.
  // Standard integer formula avoiding bitwise negation: ((val + page_size - 1) / page_size) * page_size.
  @if page_size <= 0 return val @end
  remainder = val % page_size
  @if remainder == 0 return val @end
  return val + (page_size - remainder)
@end

@fn elf_page_align_down(val, page_size)
  // WHY: Rounds an address or offset DOWN to the nearest multiple of page_size.
  @if page_size <= 0 return val @end
  return (val / page_size) * page_size
@end

// ============================================================================
// 3. INTEGER PACKING HELPERS (LITTLE ENDIAN)
// ============================================================================

@fn phdr_pack_u32_le(val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn phdr_pack_u64_le(val)
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
// 4. SEGMENT FACTORY FUNCTIONS
// ============================================================================

@fn elf_pt_load_create(file_offset, vaddr, file_size, mem_size, flags, page_align)
  // WHY: Creates a standard PT_LOAD segment.
  // If mem_size > file_size, the kernel automatically zeroes out the delta (used for .bss).
  align_val = page_align
  @if align_val <= 0
    align_val = ELF_PAGE_SIZE_4K()
  @end

  return {
    p_type: PT_LOAD(),
    p_flags: flags,
    p_offset: file_offset,
    p_vaddr: vaddr,
    p_paddr: vaddr,
    p_filesz: file_size,
    p_memsz: mem_size,
    p_align: align_val
  }
@end

@fn elf_pt_gnu_stack_create(is_executable)
  // WHY: Modern Linux kernels (since 2.6.8) check for the PT_GNU_STACK segment.
  // If p_flags has PF_X (1), the stack is executable (vulnerable to shellcode injection).
  // If p_flags is PF_R | PF_W (6), the stack is non-executable (enforces NX bit hardware protection).
  // Lipi strictly defaults to non-executable stack (flags = 6) for sovereign security.
  flags = PF_R_W()
  @if is_executable == 1
    flags = PF_R_W_X()
  @end

  return {
    p_type: PT_GNU_STACK(),
    p_flags: flags,
    p_offset: 0,
    p_vaddr: 0,
    p_paddr: 0,
    p_filesz: 0,
    p_memsz: 0,
    p_align: 8 // Alignment is 8 (or 16)
  }
@end

@fn elf_pt_gnu_relro_create(file_offset, vaddr, size)
  // WHY: Read-Only Relocations (RELRO) security hardening segment.
  // Marks segments like GOT (Global Offset Table) or init arrays as read-only after dynamic linker finishes.
  return {
    p_type: PT_GNU_RELRO(),
    p_flags: PF_R(), // Read-only after relocations applied
    p_offset: file_offset,
    p_vaddr: vaddr,
    p_paddr: vaddr,
    p_filesz: size,
    p_memsz: size,
    p_align: 1
  }
@end

@fn elf_pt_dynamic_create(file_offset, vaddr, size)
  // WHY: Generates the PT_DYNAMIC segment entry referencing the .dynamic section for shared libraries.
  return {
    p_type: PT_DYNAMIC(),
    p_flags: PF_R_W(),
    p_offset: file_offset,
    p_vaddr: vaddr,
    p_paddr: vaddr,
    p_filesz: size,
    p_memsz: size,
    p_align: 8
  }
@end

// ============================================================================
// 5. SERIALIZATION (56 Bytes per Phdr)
// ============================================================================

@fn elf_program_header_serialize(phdr)
  // WHY: Serializes a single Elf64_Phdr structure to exactly 56 bytes.
  // Layout in System V ELF-64 ABI:
  // Offset 0x00: p_type   (Elf64_Word, 4 bytes)
  // Offset 0x04: p_flags  (Elf64_Word, 4 bytes)
  // Offset 0x08: p_offset (Elf64_Off,  8 bytes)
  // Offset 0x10: p_vaddr  (Elf64_Addr, 8 bytes)
  // Offset 0x18: p_paddr  (Elf64_Addr, 8 bytes)
  // Offset 0x20: p_filesz (Elf64_Xword,8 bytes)
  // Offset 0x28: p_memsz  (Elf64_Xword,8 bytes)
  // Offset 0x30: p_align  (Elf64_Xword,8 bytes)
  // Total: 56 bytes exactly.
  out = []

  // 1. p_type (4 bytes)
  t_bytes = phdr_pack_u32_le(phdr.p_type)
  out = out.push(t_bytes[0])
  out = out.push(t_bytes[1])
  out = out.push(t_bytes[2])
  out = out.push(t_bytes[3])

  // 2. p_flags (4 bytes)
  f_bytes = phdr_pack_u32_le(phdr.p_flags)
  out = out.push(f_bytes[0])
  out = out.push(f_bytes[1])
  out = out.push(f_bytes[2])
  out = out.push(f_bytes[3])

  // 3. p_offset (8 bytes)
  o_bytes = phdr_pack_u64_le(phdr.p_offset)
  i = 0
  @while i < 8
    out = out.push(o_bytes[i])
    i = i + 1
  @end

  // 4. p_vaddr (8 bytes)
  va_bytes = phdr_pack_u64_le(phdr.p_vaddr)
  i = 0
  @while i < 8
    out = out.push(va_bytes[i])
    i = i + 1
  @end

  // 5. p_paddr (8 bytes)
  pa_bytes = phdr_pack_u64_le(phdr.p_paddr)
  i = 0
  @while i < 8
    out = out.push(pa_bytes[i])
    i = i + 1
  @end

  // 6. p_filesz (8 bytes)
  fs_bytes = phdr_pack_u64_le(phdr.p_filesz)
  i = 0
  @while i < 8
    out = out.push(fs_bytes[i])
    i = i + 1
  @end

  // 7. p_memsz (8 bytes)
  ms_bytes = phdr_pack_u64_le(phdr.p_memsz)
  i = 0
  @while i < 8
    out = out.push(ms_bytes[i])
    i = i + 1
  @end

  // 8. p_align (8 bytes)
  al_bytes = phdr_pack_u64_le(phdr.p_align)
  i = 0
  @while i < 8
    out = out.push(al_bytes[i])
    i = i + 1
  @end

  return out
@end

@fn elf_program_headers_serialize(phdrs)
  // WHY: Serializes an ordered list of program headers into a contiguous byte stream.
  // Total byte size will be phdrs.len() * 56 bytes.
  out = []
  i = 0
  count = phdrs.len()
  @while i < count
    hdr_bytes = elf_program_header_serialize(phdrs[i])
    j = 0
    @while j < 56
      out = out.push(hdr_bytes[j])
      j = j + 1
    @end
    i = i + 1
  @end
  return out
@end
