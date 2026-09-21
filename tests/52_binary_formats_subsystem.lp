// ==============================================================================
// 👑 TEST 52: BINARY FORMATS, LINKERS & DWARF DEBUG SUBSYSTEM
// ⚡ 100% Pure Lipi First 1.0.0 | Zero External Dependencies | Zero Libc
// ==============================================================================

// WHY: Comprehensive integration verification test for the modular micro-subsystems:
// 1. elf/elf_header.lp
// 2. elf/program_header.lp
// 3. elf/section_header.lp
// 4. elf/relocation.lp
// 5. elf/elf_writer.lp
// 6. macho/load_commands.lp
// 7. macho/macho_writer.lp
// 8. pe/dos_header.lp
// 9. pe/coff_header.lp
// 10. pe/pe_writer.lp
// 11. unikernel/multiboot2.lp
// 12. debug/dwarf_line.lp
// 13. debug/dwarf_info.lp

import "src/compiler/backend/formats/elf/elf_header.lp"
import "src/compiler/backend/formats/elf/program_header.lp"
import "src/compiler/backend/formats/elf/section_header.lp"
import "src/compiler/backend/formats/elf/relocation.lp"
import "src/compiler/backend/formats/elf/elf_writer.lp"

import "src/compiler/backend/formats/macho/load_commands.lp"
import "src/compiler/backend/formats/macho/macho_writer.lp"

import "src/compiler/backend/formats/pe/dos_header.lp"
import "src/compiler/backend/formats/pe/coff_header.lp"
import "src/compiler/backend/formats/pe/pe_writer.lp"

import "src/compiler/backend/formats/unikernel/multiboot2.lp"

import "src/compiler/backend/formats/debug/dwarf_line.lp"
import "src/compiler/backend/formats/debug/dwarf_info.lp"

@fn assert_eq(actual, expected, test_name)
  @if actual == expected
    say "  [PASS] " + test_name + " == " + expected
    return 1
  @else
    say "  [FAIL] " + test_name + ": expected " + expected + ", got " + actual
    return 0
  @end
@end

@fn main()
  say "======================================================================"
  say "LIPI SOVEREIGN BINARY FORMATS & DWARF SUBSYSTEM VERIFICATION"
  say "======================================================================"

  all_passed = 1

  // --------------------------------------------------------------------------
  // 1. ELF64 Header Serializer Verification
  // --------------------------------------------------------------------------
  say "\n--- 1. Verifying elf/elf_header.lp ---"
  hdr_x86 = elf_header_x86_64(4198400, 64, 512, 2, 6, 5)
  bytes_hdr = elf_header_serialize(hdr_x86)
  all_passed = all_passed & assert_eq(bytes_hdr.len(), 64, "ELF64 Header exact size (64 bytes)")
  all_passed = all_passed & assert_eq(bytes_hdr[0], 127, "ELF Magic 0 (0x7F)")
  all_passed = all_passed & assert_eq(bytes_hdr[1], 69, "ELF Magic 1 ('E')")
  all_passed = all_passed & assert_eq(bytes_hdr[2], 76, "ELF Magic 2 ('L')")
  all_passed = all_passed & assert_eq(bytes_hdr[3], 70, "ELF Magic 3 ('F')")
  all_passed = all_passed & assert_eq(bytes_hdr[4], 2, "ELFCLASS64 (64-bit)")
  all_passed = all_passed & assert_eq(bytes_hdr[5], 1, "ELFDATA2LSB (Little-Endian)")
  all_passed = all_passed & assert_eq(bytes_hdr[16], 2, "ET_EXEC (Executable)")
  all_passed = all_passed & assert_eq(bytes_hdr[18], 62, "EM_X86_64 (Machine AMD64)")
  valid_elf = elf_header_validate(bytes_hdr)
  all_passed = all_passed & assert_eq(valid_elf, 1, "elf_header_validate() integrity check")

  // ARM64 verification
  hdr_arm = elf_header_aarch64(4198400, 64, 512, 2, 6, 5)
  bytes_arm = elf_header_serialize(hdr_arm)
  all_passed = all_passed & assert_eq(bytes_arm[18], 183, "EM_AARCH64 (Machine ARM64 0xB7)")

  // --------------------------------------------------------------------------
  // 2. ELF Program Header Generator Verification
  // --------------------------------------------------------------------------
  say "\n--- 2. Verifying elf/program_header.lp ---"
  aligned_page = elf_page_align_up(4500, 4096)
  all_passed = all_passed & assert_eq(aligned_page, 8192, "Page alignment up 4500 -> 8192")

  pt_load = elf_pt_load_create(0, 4194304, 1024, 2048, PF_R_X(), 4096)
  pt_stack = elf_pt_gnu_stack_create(0) // Non-executable stack
  ph_bytes = elf_program_header_serialize(pt_load)
  all_passed = all_passed & assert_eq(ph_bytes.len(), 56, "Program Header exact size (56 bytes)")
  all_passed = all_passed & assert_eq(ph_bytes[0], 1, "p_type PT_LOAD (1)")
  all_passed = all_passed & assert_eq(ph_bytes[4], 5, "p_flags PF_R_X (5)")

  ph_stack_bytes = elf_program_header_serialize(pt_stack)
  all_passed = all_passed & assert_eq(pt_stack.p_type, PT_GNU_STACK(), "PT_GNU_STACK type (0x6474E551)")
  all_passed = all_passed & assert_eq(pt_stack.p_flags, 6, "PT_GNU_STACK non-executable stack PF_R_W (6)")

  // --------------------------------------------------------------------------
  // 3. ELF Section Header Generator Verification
  // --------------------------------------------------------------------------
  say "\n--- 3. Verifying elf/section_header.lp ---"
  sh_str = elf_strtab_new()
  off_text = elf_strtab_add(sh_str, ".text")
  off_rodata = elf_strtab_add(sh_str, ".rodata")
  all_passed = all_passed & assert_eq(off_text, 1, "First string offset in .shstrtab after \\0")
  all_passed = all_passed & assert_eq(off_rodata, 7, "Second string offset in .shstrtab")

  sh_t = elf_sh_text(off_text, 4198400, 512, 128)
  sh_bytes = elf_section_header_serialize(sh_t)
  all_passed = all_passed & assert_eq(sh_bytes.len(), 64, "Section Header exact size (64 bytes)")
  all_passed = all_passed & assert_eq(sh_t.sh_type, SHT_PROGBITS(), "SHT_PROGBITS (1)")
  all_passed = all_passed & assert_eq(sh_t.sh_flags, 6, "SHF_ALLOC | SHF_EXECINSTR (6)")

  // --------------------------------------------------------------------------
  // 4. ELF Relocation Resolver Verification
  // --------------------------------------------------------------------------
  say "\n--- 4. Verifying elf/relocation.lp ---"
  // Relocation test: target func at 0x401050, call site at 0x401010
  // Place = 0x401011 (displacement field), addend = -4
  disp_res = elf_resolve_pc32(4198480, 0 - 4, 4198417)
  all_passed = all_passed & assert_eq(disp_res, 59, "R_X86_64_PC32 displacement calculation")

  mock_code = [232, 0, 0, 0, 0, 144] // call rel32 + nop
  mock_code = elf_apply_relocation_pc32(mock_code, 1, 4198480, 0 - 4, 4198417)
  all_passed = all_passed & assert_eq(mock_code[1], 59, "Patched displacement byte 0")
  all_passed = all_passed & assert_eq(mock_code[2], 0, "Patched displacement byte 1")

  sym = elf_symbol_create(1, 4198400, 64, STB_GLOBAL(), STT_FUNC(), 1)
  sym_bytes = elf_symbol_serialize(sym)
  all_passed = all_passed & assert_eq(sym_bytes.len(), 24, "Elf64_Sym exact size (24 bytes)")

  rela = elf_rela_create(16, 1, R_X86_64_PC32(), 0 - 4)
  rela_bytes = elf_rela_serialize(rela)
  all_passed = all_passed & assert_eq(rela_bytes.len(), 24, "Elf64_Rela exact size (24 bytes)")

  // --------------------------------------------------------------------------
  // 5. ELF Writer Verification
  // --------------------------------------------------------------------------
  say "\n--- 5. Verifying elf/elf_writer.lp ---"
  code_sample = [72, 199, 192, 42, 0, 0, 0, 195] // mov rax, 42; ret
  res_elf = elf_emit_executable(code_sample, [], [], 0, "/tmp/lipi_test_elf_out")
  all_passed = all_passed & assert_eq(res_elf.ew_success, 1, "ELF executable compilation and write")
  all_passed = all_passed & assert_eq(res_elf.ew_bytes[0], 127, "Generated ELF file starts with 0x7F")

  // --------------------------------------------------------------------------
  // 6. Mach-O Load Commands Verification
  // --------------------------------------------------------------------------
  say "\n--- 6. Verifying macho/load_commands.lp ---"
  m_hdr = macho_header_create(CPU_TYPE_X86_64(), 3, 248)
  m_hdr_bytes = macho_header_serialize(m_hdr)
  all_passed = all_passed & assert_eq(m_hdr_bytes.len(), 32, "Mach-O 64 Header exact size (32 bytes)")
  all_passed = all_passed & assert_eq(m_hdr.mh_magic, MH_MAGIC_64(), "MH_MAGIC_64 (0xFEEDFACF)")

  pz = macho_segment_pagezero()
  pz_bytes = macho_segment_header_serialize(pz)
  all_passed = all_passed & assert_eq(pz_bytes.len(), 72, "LC_SEGMENT_64 base size (72 bytes)")

  sec_t = macho_section_text(4294967296, 64, 512)
  sec_t_bytes = macho_section_serialize(sec_t)
  all_passed = all_passed & assert_eq(sec_t_bytes.len(), 80, "section_64 exact size (80 bytes)")

  lc_m = macho_lc_main_create(512, 0)
  lc_m_bytes = macho_lc_main_serialize(lc_m)
  all_passed = all_passed & assert_eq(lc_m_bytes.len(), 24, "LC_MAIN exact size (24 bytes)")

  // --------------------------------------------------------------------------
  // 7. Mach-O Writer Verification
  // --------------------------------------------------------------------------
  say "\n--- 7. Verifying macho/macho_writer.lp ---"
  res_macho = macho_emit_executable(code_sample, [], 0, CPU_TYPE_X86_64(), "/tmp/lipi_test_macho_out")
  all_passed = all_passed & assert_eq(res_macho.mw_success, 1, "Mach-O binary compilation and write")
  all_passed = all_passed & assert_eq(res_macho.mw_bytes[0], 207, "Mach-O magic byte 0 (0xCF)")
  all_passed = all_passed & assert_eq(res_macho.mw_bytes[1], 250, "Mach-O magic byte 1 (0xFA)")
  all_passed = all_passed & assert_eq(res_macho.mw_bytes[2], 237, "Mach-O magic byte 2 (0xED)")
  all_passed = all_passed & assert_eq(res_macho.mw_bytes[3], 254, "Mach-O magic byte 3 (0xFE)")

  // --------------------------------------------------------------------------
  // 8. PE DOS Header & Stub Verification
  // --------------------------------------------------------------------------
  say "\n--- 8. Verifying pe/dos_header.lp ---"
  dos_block = pe_dos_block_serialize()
  all_passed = all_passed & assert_eq(dos_block.len(), 128, "PE DOS Block exact size (128 bytes)")
  all_passed = all_passed & assert_eq(dos_block[0], 77, "MZ Magic 0 ('M')")
  all_passed = all_passed & assert_eq(dos_block[1], 90, "MZ Magic 1 ('Z')")
  all_passed = all_passed & assert_eq(dos_block[60], 128, "e_lfanew points to offset 128 (0x80)")

  pe_sig = pe_signature_bytes()
  all_passed = all_passed & assert_eq(pe_sig[0], 80, "PE Signature byte 0 ('P')")
  all_passed = all_passed & assert_eq(pe_sig[1], 69, "PE Signature byte 1 ('E')")

  // --------------------------------------------------------------------------
  // 9. PE COFF & Section Table Verification
  // --------------------------------------------------------------------------
  say "\n--- 9. Verifying pe/coff_header.lp ---"
  coff_hdr = pe_coff_header_create(IMAGE_FILE_MACHINE_AMD64(), 2)
  coff_bytes = pe_coff_header_serialize(coff_hdr)
  all_passed = all_passed & assert_eq(coff_bytes.len(), 20, "COFF File Header exact size (20 bytes)")

  opt_hdr = pe_optional_header64_default()
  opt_bytes = pe_optional_header64_serialize(opt_hdr)
  all_passed = all_passed & assert_eq(opt_bytes.len(), 240, "PE32+ Optional Header exact size (240 bytes)")
  all_passed = all_passed & assert_eq(opt_hdr.magic, PE32PLUS_MAGIC(), "PE32+ Magic (0x020B)")

  pe_sec_t = pe_section_text_create(128, 4096, 512, 512)
  pe_sec_bytes = pe_section_header_serialize(pe_sec_t)
  all_passed = all_passed & assert_eq(pe_sec_bytes.len(), 40, "IMAGE_SECTION_HEADER exact size (40 bytes)")

  // --------------------------------------------------------------------------
  // 10. PE Writer Verification
  // --------------------------------------------------------------------------
  say "\n--- 10. Verifying pe/pe_writer.lp ---"
  res_pe = pe_emit_executable(code_sample, [], [], 0, 0, "/tmp/lipi_test_pe_out.exe")
  all_passed = all_passed & assert_eq(res_pe.pe_success, 1, "PE64 (.exe) compilation and write")
  all_passed = all_passed & assert_eq(res_pe.pe_bytes[0], 77, "Generated .exe starts with 'M'")
  all_passed = all_passed & assert_eq(res_pe.pe_bytes[1], 90, "Generated .exe starts with 'Z'")
  all_passed = all_passed & assert_eq(res_pe.pe_bytes[128], 80, "PE Signature 'P' at offset 128")
  all_passed = all_passed & assert_eq(res_pe.pe_bytes[129], 69, "PE Signature 'E' at offset 129")

  // --------------------------------------------------------------------------
  // 11. Multiboot2 Unikernel Verification
  // --------------------------------------------------------------------------
  say "\n--- 11. Verifying unikernel/multiboot2.lp ---"
  mb_hdr_bytes = mb2_header_build(1048576, 1, 1024, 768, 32)
  all_passed = all_passed & assert_eq(mb_hdr_bytes[0], 214, "Multiboot2 magic byte 0 (0xD6)")
  all_passed = all_passed & assert_eq(mb_hdr_bytes[1], 80, "Multiboot2 magic byte 1 (0x50)")
  all_passed = all_passed & assert_eq(mb_hdr_bytes[2], 82, "Multiboot2 magic byte 2 (0x52)")
  all_passed = all_passed & assert_eq(mb_hdr_bytes[3], 232, "Multiboot2 magic byte 3 (0xE8)")

  // Verify mathematical checksum formula: magic + arch + length + csum == 0 mod 2^32
  csum_test = mb2_checksum_compute(MULTIBOOT2_HEADER_MAGIC(), 0, 64)
  csum_ok = mb2_checksum_verify(MULTIBOOT2_HEADER_MAGIC(), 0, 64, csum_test)
  all_passed = all_passed & assert_eq(csum_ok, 1, "Multiboot2 checksum modular verification")

  tramp = mb2_generate_entry_trampoline(64)
  all_passed = all_passed & assert_eq(tramp[0], 250, "Trampoline starts with cli (0xFA)")

  // --------------------------------------------------------------------------
  // 12. DWARF .debug_line Verification
  // --------------------------------------------------------------------------
  say "\n--- 12. Verifying debug/dwarf_line.lp ---"
  // LEB128 tests
  uleb = dwarf_encode_uleb128(624485)
  all_passed = all_passed & assert_eq(uleb.len(), 3, "ULEB128 624485 length == 3 bytes")
  all_passed = all_passed & assert_eq(uleb[0], 229, "ULEB128 byte 0 (0xE5)")
  all_passed = all_passed & assert_eq(uleb[1], 142, "ULEB128 byte 1 (0x8E)")
  all_passed = all_passed & assert_eq(uleb[2], 38, "ULEB128 byte 2 (0x26)")

  sleb = dwarf_encode_sleb128(0 - 5)
  all_passed = all_passed & assert_eq(sleb.len(), 1, "SLEB128 -5 length == 1 byte")
  all_passed = all_passed & assert_eq(sleb[0], 123, "SLEB128 -5 byte (0x7B = 123)")

  // Line builder test
  dl_builder = dwarf_line_builder_new(4)
  dwarf_line_add_dir(dl_builder, "src/compiler")
  dwarf_line_add_file(dl_builder, "main.lp", 1)
  dwarf_line_emit_set_address(dl_builder, 4198400)
  dwarf_line_emit_row(dl_builder, 4198416, 2, 4)
  dwarf_line_end_sequence(dl_builder, 4198432)
  dl_bytes = dwarf_line_serialize(dl_builder)
  all_passed = all_passed & assert_eq(dl_bytes[4], 4, "DWARF .debug_line version 4")
  all_passed = all_passed & assert_eq(dl_bytes.len() > 30, 1, "DWARF .debug_line serialized byte count > 30")

  // --------------------------------------------------------------------------
  // 13. DWARF .debug_info & .debug_abbrev Verification
  // --------------------------------------------------------------------------
  say "\n--- 13. Verifying debug/dwarf_info.lp ---"
  abbrev_bytes = dwarf_abbrev_build_standard()
  all_passed = all_passed & assert_eq(abbrev_bytes[0], 1, "Abbrev table starts with code 1")
  all_passed = all_passed & assert_eq(abbrev_bytes[1], DW_TAG_compile_unit(), "Abbrev 1 tag is DW_TAG_compile_unit (0x11)")
  all_passed = all_passed & assert_eq(abbrev_bytes[2], DW_CHILDREN_yes(), "Compile unit has children (1)")

  cu = dwarf_unit_create("Lipi Sovereign Compiler First 1.0.0", "main.lp", "/project", 4198400, 4198500, 0)
  dwarf_unit_add_function(cu, "sovereign_main", 4198400, 4198450, 1, 10)
  dwarf_unit_add_base_type(cu, "i64", 8, DW_ATE_signed())
  info_bytes = dwarf_info_serialize(cu)
  all_passed = all_passed & assert_eq(info_bytes[4], 4, "DWARF .debug_info version 4")
  all_passed = all_passed & assert_eq(info_bytes[10], 8, "DWARF .debug_info address_size 8 bytes (64-bit)")
  all_passed = all_passed & assert_eq(info_bytes.len() > 50, 1, "DWARF .debug_info serialized byte count > 50")

  say "======================================================================"
  @if all_passed == 1
    say "ALL 13 SUBSYSTEM MODULES PASSED COMPILATION & VERIFICATION!"
  @else
    say "SOME VERIFICATION CHECKS FAILED!"
  @end
  say "======================================================================"

  return 0
@end

main()
