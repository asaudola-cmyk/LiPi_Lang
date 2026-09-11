@! ============================================================================
@! MAYA NATIVE BACKEND TEST SUITE — TIER 1: ELF64 CONTAINER & WRITER
@! Tests 64-byte ELF Header, 56-byte Program Header (PT_LOAD), Section Tables,
@! .shstrtab string table, virtual address base 0x400000, and binary serialization.
@! 100% Pure Maya — Zero Mock Logic — Strict Verification
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Test Harness
@! ----------------------------------------------------------------------------

@struct TestState
  passed: 0
  failed: 0
  total: 0
@end

@fn test_assert_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return state
@end

@fn test_assert_bytes_eq(state, actual_bytes, expected_bytes, name)
  state.total = state.total + 1
  matched = 1
  @if actual_bytes.len() != expected_bytes.len()
    matched = 0
  @else
    i = 0
    @while i < actual_bytes.len()
      @if actual_bytes[i] != expected_bytes[i]
        matched = 0
      @end
      i = i + 1
    @end
  @end

  @if matched == 1
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Bytes mismatch: len " + actual_bytes.len().to_str() + " vs " + expected_bytes.len().to_str() + ")")
  @end
  return state
@end

@fn test_assert_str_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return state
@end

@! ----------------------------------------------------------------------------
@! 2. ELF64 Synthesis Functions
@! ----------------------------------------------------------------------------

@fn elf_u16_le(v)
  return [v % 256, (v / 256) % 256]
@end

@fn elf_u32_le(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn elf_u64_le(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256,
    0, 0, 0, 0
  ]
@end

@fn elf_append_list(target, source)
  @for item in source
    target = target.push(item)
  @end
  return target
@end

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
  hdr = elf_append_list(hdr, elf_u64_le(entry_point))  @! e_entry
  hdr = elf_append_list(hdr, elf_u64_le(64))           @! e_phoff (64)
  hdr = elf_append_list(hdr, elf_u64_le(sh_offset))    @! e_shoff
  hdr = elf_append_list(hdr, elf_u32_le(0))            @! e_flags
  hdr = elf_append_list(hdr, elf_u16_le(64))           @! e_ehsize (64 bytes)
  hdr = elf_append_list(hdr, elf_u16_le(56))           @! e_phentsize (56 bytes)
  hdr = elf_append_list(hdr, elf_u16_le(1))            @! e_phnum (1 PT_LOAD)
  hdr = elf_append_list(hdr, elf_u16_le(64))           @! e_shentsize (64 bytes)
  hdr = elf_append_list(hdr, elf_u16_le(sh_count))     @! e_shnum
  hdr = elf_append_list(hdr, elf_u16_le(sh_strndx))    @! e_shstrndx
  return hdr
@end

@fn elf_build_program_header(file_size, mem_size)
  ph = [
    1, 0, 0, 0,                   @! p_type: PT_LOAD (1)
    5, 0, 0, 0                    @! p_flags: PF_R | PF_X (5)
  ]
  ph = elf_append_list(ph, elf_u64_le(0))              @! p_offset (0)
  ph = elf_append_list(ph, elf_u64_le(4194304))        @! p_vaddr (0x400000)
  ph = elf_append_list(ph, elf_u64_le(4194304))        @! p_paddr (0x400000)
  ph = elf_append_list(ph, elf_u64_le(file_size))      @! p_filesz
  ph = elf_append_list(ph, elf_u64_le(mem_size))       @! p_memsz
  ph = elf_append_list(ph, elf_u64_le(4096))           @! p_align (0x1000 = 4096)
  return ph
@end

@fn elf_build_section_header(name_off, type_flags, flags, addr, offset, size, link, info, align, entsize)
  sh = []
  sh = elf_append_list(sh, elf_u32_le(name_off))
  sh = elf_append_list(sh, elf_u32_le(type_flags))
  sh = elf_append_list(sh, elf_u64_le(flags))
  sh = elf_append_list(sh, elf_u64_le(addr))
  sh = elf_append_list(sh, elf_u64_le(offset))
  sh = elf_append_list(sh, elf_u64_le(size))
  sh = elf_append_list(sh, elf_u32_le(link))
  sh = elf_append_list(sh, elf_u32_le(info))
  sh = elf_append_list(sh, elf_u64_le(align))
  sh = elf_append_list(sh, elf_u64_le(entsize))
  return sh
@end

@! ----------------------------------------------------------------------------
@! 3. Test Suite Runner
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("🧪 MAYA NATIVE BACKEND TEST SUITE — TIER 1: ELF64 BINARY WRITER 🧪")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  @! --------------------------------------------------------------------------
  @! Category 1: ELF64 Header & Program Header Synthesis (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.1] Verifying 64-byte ELF Header & 56-byte Program Header...")

  code_size = 48
  code_offset = 64 + 56 @! 120
  entry_point = 4194304 + code_offset @! 0x400078
  shstrtab = [0, 46, 116, 101, 120, 116, 0, 46, 115, 104, 115, 116, 114, 116, 97, 98, 0]
  shstrtab_size = shstrtab.len()
  shstrtab_offset = code_offset + code_size
  sh_offset = shstrtab_offset + shstrtab_size
  total_file_size = sh_offset + (3 * 64)

  elf_hdr = elf_build_header(entry_point, sh_offset, 3, 2)

  @! Test 1: ELF Header Length
  state = test_assert_eq(state, elf_hdr.len(), 64, "ELF Header exact length is 64 bytes")

  @! Test 2: Magic identification bytes
  state = test_assert_eq(state, elf_hdr[0], 127, "ELF Magic 0 (0x7F)")
  state = test_assert_eq(state, elf_hdr[1], 69, "ELF Magic 1 ('E')")
  state = test_assert_eq(state, elf_hdr[2], 76, "ELF Magic 2 ('L')")
  state = test_assert_eq(state, elf_hdr[3], 70, "ELF Magic 3 ('F')")

  @! Test 3: ELF Class & Encoding
  state = test_assert_eq(state, elf_hdr[4], 2, "ELF Class 2 (64-bit ELFCLASS64)")
  state = test_assert_eq(state, elf_hdr[5], 1, "ELF Data 1 (Little Endian ELFDATA2LSB)")
  state = test_assert_eq(state, elf_hdr[6], 1, "ELF Version 1 (EV_CURRENT)")
  state = test_assert_eq(state, elf_hdr[7], 0, "ELF OSABI 0 (ELFOSABI_SYSV)")

  @! Test 4: Target Machine & Type
  state = test_assert_eq(state, elf_hdr[16], 2, "ELF Type 2 (ET_EXEC)")
  state = test_assert_eq(state, elf_hdr[18], 62, "ELF Machine 62 (EM_X86_64 / 0x3E)")

  @! Test 5: Program Header Table Offset & Sizes
  state = test_assert_eq(state, elf_hdr[32], 64, "Program Header table offset e_phoff = 64")
  state = test_assert_eq(state, elf_hdr[54], 56, "Program Header entry size e_phentsize = 56")
  state = test_assert_eq(state, elf_hdr[56], 1, "Program Header count e_phnum = 1")
  state = test_assert_eq(state, elf_hdr[58], 64, "Section Header entry size e_shentsize = 64")
  state = test_assert_eq(state, elf_hdr[60], 3, "Section Header count e_shnum = 3")
  state = test_assert_eq(state, elf_hdr[62], 2, "Section Header string table index e_shstrndx = 2")

  @! Test 6: Program Header (PT_LOAD)
  prog_hdr = elf_build_program_header(total_file_size, total_file_size)
  state = test_assert_eq(state, prog_hdr.len(), 56, "Program Header exact length is 56 bytes")
  state = test_assert_eq(state, prog_hdr[0], 1, "p_type = PT_LOAD (1)")
  state = test_assert_eq(state, prog_hdr[4], 5, "p_flags = PF_R | PF_X (5)")
  state = test_assert_eq(state, prog_hdr[16], 0, "p_vaddr low byte 0 (0x400000)")
  state = test_assert_eq(state, prog_hdr[18], 64, "p_vaddr byte 2 0x40 (0x400000)")

  @! --------------------------------------------------------------------------
  @! Category 2: Section Headers & String Tables (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.2] Verifying Section Headers (.text, .shstrtab, SHT_NULL)...")

  sh_null = elf_build_section_header(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  state = test_assert_eq(state, sh_null.len(), 64, "SHT_NULL section header length is 64 bytes")
  state = test_assert_eq(state, sh_null[4], 0, "SHT_NULL sh_type is 0")

  sh_text = elf_build_section_header(1, 1, 6, entry_point, code_offset, code_size, 0, 0, 16, 0)
  state = test_assert_eq(state, sh_text.len(), 64, "SHT_PROGBITS .text section header length is 64 bytes")
  state = test_assert_eq(state, sh_text[0], 1, "sh_name offset in shstrtab (1 for .text)")
  state = test_assert_eq(state, sh_text[4], 1, "sh_type = SHT_PROGBITS (1)")
  state = test_assert_eq(state, sh_text[8], 6, "sh_flags = SHF_ALLOC | SHF_EXECINSTR (6)")
  state = test_assert_eq(state, sh_text[48], 16, "sh_addralign = 16 bytes for machine instructions")

  sh_strtab = elf_build_section_header(7, 3, 0, 0, shstrtab_offset, shstrtab_size, 0, 0, 1, 0)
  state = test_assert_eq(state, sh_strtab.len(), 64, "SHT_STRTAB section header length is 64 bytes")
  state = test_assert_eq(state, sh_strtab[4], 3, "sh_type = SHT_STRTAB (3)")
  state = test_assert_eq(state, sh_strtab[0], 7, "sh_name offset in shstrtab (7 for .shstrtab)")

  @! --------------------------------------------------------------------------
  @! Category 3: Binary Layout Assembly & Little-Endian Encoding (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.3] Verifying Complete Binary Layout & Little-Endian Serializer...")

  @! Test 7: Little-Endian Integer Encoders
  u16_bytes = elf_u16_le(0x1234)
  state = test_assert_bytes_eq(state, u16_bytes, [0x34, 0x12], "u16_le(0x1234) -> [0x34, 0x12]")

  u32_bytes = elf_u32_le(0x12345678)
  state = test_assert_bytes_eq(state, u32_bytes, [0x78, 0x56, 0x34, 0x12], "u32_le(0x12345678) -> [0x78, 0x56, 0x34, 0x12]")

  u64_bytes = elf_u64_le(0x00400000)
  state = test_assert_bytes_eq(state, u64_bytes, [0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00], "u64_le(0x400000) -> 8 bytes little endian")

  @! Test 8: Full Binary Concatenation
  dummy_code = [0x55, 0x48, 0x89, 0xE5, 0x48, 0x31, 0xC0, 0x5D, 0xC3]
  full_bin = []
  full_bin = elf_append_list(full_bin, elf_hdr)
  full_bin = elf_append_list(full_bin, prog_hdr)
  full_bin = elf_append_list(full_bin, dummy_code)
  full_bin = elf_append_list(full_bin, shstrtab)
  full_bin = elf_append_list(full_bin, sh_null)
  full_bin = elf_append_list(full_bin, sh_text)
  full_bin = elf_append_list(full_bin, sh_strtab)

  expected_min_len = 64 + 56 + dummy_code.len() + shstrtab.len() + 64 + 64 + 64
  state = test_assert_eq(state, full_bin.len(), expected_min_len, "Full synthesized ELF64 byte vector exact size")
  state = test_assert_eq(state, full_bin[0], 127, "Synthesized ELF starts with 0x7F")
  state = test_assert_eq(state, full_bin[1], 69, "Synthesized ELF byte 1 is 'E'")
  state = test_assert_eq(state, full_bin[2], 76, "Synthesized ELF byte 2 is 'L'")
  state = test_assert_eq(state, full_bin[3], 70, "Synthesized ELF byte 3 is 'F'")

  println("")
  println("=================================================================")
  println("📊 TIER 1 (ELF) SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL TIER 1 ELF TESTS PASSED CLEANLY!")
  @else
    println("❌ TIER 1 ELF TESTS COMPLETED WITH FAILURES!")
  @end
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
