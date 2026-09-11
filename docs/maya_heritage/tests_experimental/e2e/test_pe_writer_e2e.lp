@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — END-TO-END VERIFICATION SUITE
@! Test Suite: tests/e2e/test_pe_writer_e2e.maya
@! Component: Windows PE32+ (AMD64 / PE64) Executable Binary Writer
@! Module under test: compiler/backend/pe_writer.maya
@! Target Architecture: Windows x86-64 (PE32+ / AMD64 Executable Format)
@! 100% Pure Maya Implementation — Zero External Assembler / Linker Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/core/io"
import "compiler/backend/pe_writer"

@! ============================================================================
@! 1. TEST STATE & ASSERTION FRAMEWORK
@! ============================================================================

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_true(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == 0 || cond == false
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@fn assert_ge_int(state, actual, min_val, test_id, desc)
  state.total = state.total + 1
  @if actual >= min_val
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected >= " + min_val.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@! ============================================================================
@! 2. BINARY PARSING & HELPER UTILITIES
@! ============================================================================

@fn bytes_to_u16_le(bytes, offset)
  b0 = bytes[offset] & 255
  b1 = bytes[offset + 1] & 255
  return b0 + (b1 * 256)
@end

@fn bytes_to_u32_le(bytes, offset)
  b0 = bytes[offset] & 255
  b1 = bytes[offset + 1] & 255
  b2 = bytes[offset + 2] & 255
  b3 = bytes[offset + 3] & 255
  return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
@end

@fn bytes_to_u64_le(bytes, offset)
  val = 0
  mul = 1
  i = 0
  @while i < 8
    b = bytes[offset + i] & 255
    val = val + (b * mul)
    mul = mul * 256
    i = i + 1
  @end
  return val
@end

@fn string_to_bytes(s)
  arr = []
  i = 0
  @while i < s.len()
    arr = arr.push(str_char_at(s, i))
    i = i + 1
  @end
  return arr
@end

@fn assemble_pe_in_memory(text_src, rodata_src, data_src, entry_off)
  @if text_src.len() == 0
    text_src = [144, 195]
  @end

  text_raw_len = text_src.len()
  text_virt_size = text_raw_len
  text_raw_size = pe_align_to(text_raw_len, 0x200)

  rodata_raw_len = rodata_src.len()
  rodata_virt_size = rodata_raw_len
  rodata_raw_size = pe_align_to(rodata_raw_len, 0x200)

  data_raw_len = data_src.len()
  data_virt_size = data_raw_len
  data_raw_size = pe_align_to(data_raw_len, 0x200)

  num_sections = 1
  @if rodata_raw_len > 0
    num_sections = num_sections + 1
  @end
  @if data_raw_len > 0
    num_sections = num_sections + 1
  @end

  headers_unpadded = 128 + 24 + 240 + (num_sections * 40)
  size_of_headers = pe_align_to(headers_unpadded, 0x200)

  text_vaddr = 0x1000
  text_raw_ptr = size_of_headers

  current_vaddr = text_vaddr + pe_align_to(text_virt_size, 0x1000)
  current_raw_ptr = text_raw_ptr + text_raw_size

  rodata_vaddr = 0
  rodata_raw_ptr = 0
  @if rodata_raw_len > 0
    rodata_vaddr = current_vaddr
    rodata_raw_ptr = current_raw_ptr
    current_vaddr = current_vaddr + pe_align_to(rodata_virt_size, 0x1000)
    current_raw_ptr = current_raw_ptr + rodata_raw_size
  @end

  data_vaddr = 0
  data_raw_ptr = 0
  @if data_raw_len > 0
    data_vaddr = current_vaddr
    data_raw_ptr = current_raw_ptr
    current_vaddr = current_vaddr + pe_align_to(data_virt_size, 0x1000)
    current_raw_ptr = current_raw_ptr + data_raw_size
  @end

  size_of_image = current_vaddr
  size_of_code = text_raw_size
  size_of_init_data = rodata_raw_size + data_raw_size
  entry_point_rva = text_vaddr + entry_off

  dos_header = pe_build_dos_header()
  dos_stub = pe_build_dos_stub()
  coff_header = pe_build_coff_header(num_sections, 0)
  opt_header = pe_build_optional_header(entry_point_rva, size_of_code, size_of_init_data, size_of_image, size_of_headers)

  sec_name_text = [46, 116, 101, 120, 116, 0, 0, 0]
  sec_text = pe_build_section_header(sec_name_text, text_virt_size, text_vaddr, text_raw_size, text_raw_ptr, 0x60000020)

  sec_rodata = []
  @if rodata_raw_len > 0
    sec_name_rodata = [46, 114, 100, 97, 116, 97, 0, 0]
    sec_rodata = pe_build_section_header(sec_name_rodata, rodata_virt_size, rodata_vaddr, rodata_raw_size, rodata_raw_ptr, 0x40000040)
  @end

  sec_data = []
  @if data_raw_len > 0
    sec_name_data = [46, 100, 97, 116, 97, 0, 0, 0]
    sec_data = pe_build_section_header(sec_name_data, data_virt_size, data_vaddr, data_raw_size, data_raw_ptr, 0xC0000040)
  @end

  final_bin = []
  final_bin = pe_append(final_bin, dos_header)
  final_bin = pe_append(final_bin, dos_stub)
  final_bin = pe_append(final_bin, coff_header)
  final_bin = pe_append(final_bin, opt_header)
  final_bin = pe_append(final_bin, sec_text)
  @if rodata_raw_len > 0
    final_bin = pe_append(final_bin, sec_rodata)
  @end
  @if data_raw_len > 0
    final_bin = pe_append(final_bin, sec_data)
  @end

  @while final_bin.len() < size_of_headers
    final_bin = final_bin.push(0)
  @end

  final_bin = pe_append(final_bin, text_src)
  @while final_bin.len() < text_raw_ptr + text_raw_size
    final_bin = final_bin.push(144)
  @end

  @if rodata_raw_len > 0
    final_bin = pe_append(final_bin, rodata_src)
    @while final_bin.len() < rodata_raw_ptr + rodata_raw_size
      final_bin = final_bin.push(0)
    @end
  @end

  @if data_raw_len > 0
    final_bin = pe_append(final_bin, data_src)
    @while final_bin.len() < data_raw_ptr + data_raw_size
      final_bin = final_bin.push(0)
    @end
  @end

  return final_bin
@end

@! ============================================================================
@! 3. TEST TIERS & VERIFICATION LOGIC
@! ============================================================================

@! Tier 1: Byte-Level Encoders & Alignment Verification
@fn test_tier1_encoders_alignment(state)
  println("▶ [Tier 1] Integer Encoders & Alignment Verification...")

  @! pe_u16_le tests
  u16_val1 = pe_u16_le(0x5A4D)
  assert_eq_int(state, u16_val1[0], 77, "PE-ENC-01", "pe_u16_le(0x5A4D) byte 0 == 0x4D (77 'M')")
  assert_eq_int(state, u16_val1[1], 90, "PE-ENC-02", "pe_u16_le(0x5A4D) byte 1 == 0x5A (90 'Z')")

  u16_val2 = pe_u16_le(0x8664)
  assert_eq_int(state, u16_val2[0], 0x64, "PE-ENC-03", "pe_u16_le(0x8664 AMD64) byte 0 == 0x64 (100)")
  assert_eq_int(state, u16_val2[1], 0x86, "PE-ENC-04", "pe_u16_le(0x8664 AMD64) byte 1 == 0x86 (134)")

  u16_val3 = pe_u16_le(0x020B)
  assert_eq_int(state, u16_val3[0], 0x0B, "PE-ENC-05", "pe_u16_le(0x020B PE32+) byte 0 == 0x0B (11)")
  assert_eq_int(state, u16_val3[1], 0x02, "PE-ENC-06", "pe_u16_le(0x020B PE32+) byte 1 == 0x02 (2)")

  @! pe_u32_le tests
  u32_val1 = pe_u32_le(128)
  assert_eq_int(state, u32_val1[0], 128, "PE-ENC-07", "pe_u32_le(128) byte 0 == 128 (0x80)")
  assert_eq_int(state, u32_val1[1], 0, "PE-ENC-08", "pe_u32_le(128) byte 1 == 0")
  assert_eq_int(state, u32_val1[2], 0, "PE-ENC-09", "pe_u32_le(128) byte 2 == 0")
  assert_eq_int(state, u32_val1[3], 0, "PE-ENC-10", "pe_u32_le(128) byte 3 == 0")

  u32_val2 = pe_u32_le(0x60000020)
  assert_eq_int(state, u32_val2[0], 0x20, "PE-ENC-11", "pe_u32_le(0x60000020) byte 0 == 0x20")
  assert_eq_int(state, u32_val2[1], 0x00, "PE-ENC-12", "pe_u32_le(0x60000020) byte 1 == 0x00")
  assert_eq_int(state, u32_val2[2], 0x00, "PE-ENC-13", "pe_u32_le(0x60000020) byte 2 == 0x00")
  assert_eq_int(state, u32_val2[3], 0x60, "PE-ENC-14", "pe_u32_le(0x60000020) byte 3 == 0x60")

  @! pe_u64_le tests
  u64_val1 = pe_u64_le(5368709120) @! 0x140000000 ImageBase
  assert_eq_int(state, u64_val1[0], 0, "PE-ENC-15", "pe_u64_le(0x140000000) byte 0 == 0")
  assert_eq_int(state, u64_val1[1], 0, "PE-ENC-16", "pe_u64_le(0x140000000) byte 1 == 0")
  assert_eq_int(state, u64_val1[2], 0, "PE-ENC-17", "pe_u64_le(0x140000000) byte 2 == 0")
  assert_eq_int(state, u64_val1[3], 64, "PE-ENC-18", "pe_u64_le(0x140000000) byte 3 == 64 (0x40)")
  assert_eq_int(state, u64_val1[4], 1, "PE-ENC-19", "pe_u64_le(0x140000000) byte 4 == 1 (0x01)")
  assert_eq_int(state, u64_val1[5], 0, "PE-ENC-20", "pe_u64_le(0x140000000) byte 5 == 0")
  assert_eq_int(state, u64_val1[6], 0, "PE-ENC-21", "pe_u64_le(0x140000000) byte 6 == 0")
  assert_eq_int(state, u64_val1[7], 0, "PE-ENC-22", "pe_u64_le(0x140000000) byte 7 == 0")

  @! pe_align_to tests
  assert_eq_int(state, pe_align_to(0, 0x200), 0, "PE-ALN-01", "pe_align_to(0, 0x200) == 0")
  assert_eq_int(state, pe_align_to(1, 0x200), 512, "PE-ALN-02", "pe_align_to(1, 0x200) == 512 (0x200)")
  assert_eq_int(state, pe_align_to(512, 0x200), 512, "PE-ALN-03", "pe_align_to(512, 0x200) == 512 (0x200)")
  assert_eq_int(state, pe_align_to(513, 0x200), 1024, "PE-ALN-04", "pe_align_to(513, 0x200) == 1024 (0x400)")
  assert_eq_int(state, pe_align_to(1, 0x1000), 4096, "PE-ALN-05", "pe_align_to(1, 0x1000) == 4096 (0x1000)")
  assert_eq_int(state, pe_align_to(4096, 0x1000), 4096, "PE-ALN-06", "pe_align_to(4096, 0x1000) == 4096 (0x1000)")
  assert_eq_int(state, pe_align_to(4097, 0x1000), 8192, "PE-ALN-07", "pe_align_to(4097, 0x1000) == 8192 (0x2000)")
  return 0
@end

@! Tier 2: DOS Header & DOS Stub Verification
@fn test_tier2_dos_header_and_stub(state)
  println("▶ [Tier 2] MS-DOS Header & 16-Bit Stub Verification...")

  dos_hdr = pe_build_dos_header()
  assert_eq_int(state, dos_hdr.len(), 64, "PE-DOS-01", "DOS Header length == exactly 64 bytes")

  @! MZ Magic Signature
  assert_eq_int(state, dos_hdr[0], 77, "PE-DOS-02", "DOS Header magic byte 0 == 'M' (77 / 0x4D)")
  assert_eq_int(state, dos_hdr[1], 90, "PE-DOS-03", "DOS Header magic byte 1 == 'Z' (90 / 0x5A)")
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 0), 0x5A4D, "PE-DOS-04", "DOS Header e_magic u16 == 0x5A4D")

  @! Standard MS-DOS Header fields
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 2), 0x0090, "PE-DOS-05", "DOS Header e_cblp == 0x0090")
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 4), 0x0003, "PE-DOS-06", "DOS Header e_cp == 0x0003")
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 8), 0x0004, "PE-DOS-07", "DOS Header e_cparhdr == 0x0004")
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 12), 0xFFFF, "PE-DOS-08", "DOS Header e_maxalloc == 0xFFFF")
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 16), 0x00B8, "PE-DOS-09", "DOS Header e_sp == 0x00B8")
  assert_eq_int(state, bytes_to_u16_le(dos_hdr, 24), 0x0040, "PE-DOS-10", "DOS Header e_lfarlc == 0x0040")

  @! e_lfanew at offset 0x3C (60) pointing to PE signature at offset 128
  assert_eq_int(state, dos_hdr[60], 128, "PE-DOS-11", "e_lfanew byte 0 == 128 (0x80)")
  assert_eq_int(state, dos_hdr[61], 0, "PE-DOS-12", "e_lfanew byte 1 == 0")
  assert_eq_int(state, dos_hdr[62], 0, "PE-DOS-13", "e_lfanew byte 2 == 0")
  assert_eq_int(state, dos_hdr[63], 0, "PE-DOS-14", "e_lfanew byte 3 == 0")
  assert_eq_int(state, bytes_to_u32_le(dos_hdr, 60), 128, "PE-DOS-15", "e_lfanew u32 == 128 (0x00000080)")

  @! DOS Stub
  dos_stub = pe_build_dos_stub()
  assert_eq_int(state, dos_stub.len(), 64, "PE-DOS-16", "DOS Stub length == exactly 64 bytes")
  assert_eq_int(state, dos_stub[0], 14, "PE-DOS-17", "DOS Stub opcode byte 0 == 0x0E (push cs)")
  assert_eq_int(state, dos_stub[1], 31, "PE-DOS-18", "DOS Stub opcode byte 1 == 0x1F (pop ds)")
  assert_eq_int(state, dos_stub[2], 186, "PE-DOS-19", "DOS Stub opcode byte 2 == 0xBA (mov dx, imm16)")

  @! DOS Stub message text: 'This program cannot be run in DOS mode.'
  assert_eq_int(state, dos_stub[14], 84, "PE-DOS-20", "DOS Stub text 'T' == 84")
  assert_eq_int(state, dos_stub[15], 104, "PE-DOS-21", "DOS Stub text 'h' == 104")
  assert_eq_int(state, dos_stub[16], 105, "PE-DOS-22", "DOS Stub text 'i' == 105")
  assert_eq_int(state, dos_stub[17], 115, "PE-DOS-23", "DOS Stub text 's' == 115")

  @! Combined DOS Header + Stub
  assert_eq_int(state, dos_hdr.len() + dos_stub.len(), 128, "PE-DOS-24", "DOS Header (64) + DOS Stub (64) == 128 bytes")
  return 0
@end

@! Tier 3: PE Signature & COFF File Header Verification
@fn test_tier3_pe_signature_and_coff(state)
  println("▶ [Tier 3] PE Signature & COFF Header Verification...")

  coff_hdr = pe_build_coff_header(2, 0x60000000)
  assert_eq_int(state, coff_hdr.len(), 24, "PE-COFF-01", "COFF Header length (including PE sig) == 24 bytes")

  @! PE Signature: 'PE\0\0' (0x00004550)
  assert_eq_int(state, coff_hdr[0], 80, "PE-COFF-02", "PE signature byte 0 == 'P' (80 / 0x50)")
  assert_eq_int(state, coff_hdr[1], 69, "PE-COFF-03", "PE signature byte 1 == 'E' (69 / 0x45)")
  assert_eq_int(state, coff_hdr[2], 0, "PE-COFF-04", "PE signature byte 2 == 0x00")
  assert_eq_int(state, coff_hdr[3], 0, "PE-COFF-05", "PE signature byte 3 == 0x00")
  assert_eq_int(state, bytes_to_u32_le(coff_hdr, 0), 0x00004550, "PE-COFF-06", "PE signature u32 == 0x00004550")

  @! Machine: AMD64 / x86-64 (0x8664)
  assert_eq_int(state, coff_hdr[4], 0x64, "PE-COFF-07", "Machine byte 0 == 0x64 (100)")
  assert_eq_int(state, coff_hdr[5], 0x86, "PE-COFF-08", "Machine byte 1 == 0x86 (134)")
  assert_eq_int(state, bytes_to_u16_le(coff_hdr, 4), 0x8664, "PE-COFF-09", "Machine u16 == 0x8664 (IMAGE_FILE_MACHINE_AMD64)")

  @! Number of Sections
  assert_eq_int(state, bytes_to_u16_le(coff_hdr, 6), 2, "PE-COFF-10", "NumberOfSections == 2")

  @! TimeDateStamp
  assert_eq_int(state, bytes_to_u32_le(coff_hdr, 8), 0x60000000, "PE-COFF-11", "TimeDateStamp == 0x60000000")

  @! Symbol Table & Symbols
  assert_eq_int(state, bytes_to_u32_le(coff_hdr, 12), 0, "PE-COFF-12", "PointerToSymbolTable == 0")
  assert_eq_int(state, bytes_to_u32_le(coff_hdr, 16), 0, "PE-COFF-13", "NumberOfSymbols == 0")

  @! SizeOfOptionalHeader = 240 (0x00F0 for PE32+)
  assert_eq_int(state, coff_hdr[20], 240, "PE-COFF-14", "SizeOfOptionalHeader byte 0 == 240 (0xF0)")
  assert_eq_int(state, coff_hdr[21], 0, "PE-COFF-15", "SizeOfOptionalHeader byte 1 == 0")
  assert_eq_int(state, bytes_to_u16_le(coff_hdr, 20), 240, "PE-COFF-16", "SizeOfOptionalHeader == 240 bytes (PE32+ standard)")

  @! Characteristics = 0x0022 (EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE)
  assert_eq_int(state, coff_hdr[22], 0x22, "PE-COFF-17", "Characteristics byte 0 == 0x22 (34)")
  assert_eq_int(state, coff_hdr[23], 0x00, "PE-COFF-18", "Characteristics byte 1 == 0x00")
  assert_eq_int(state, bytes_to_u16_le(coff_hdr, 22), 0x0022, "PE-COFF-19", "Characteristics == 0x0022 (EXECUTABLE | LARGE_ADDRESS_AWARE)")
  return 0
@end

@! Tier 4: Optional Header (IMAGE_OPTIONAL_HEADER64) Verification
@fn test_tier4_optional_header_64(state)
  println("▶ [Tier 4] PE32+ Optional Header Verification...")

  entry_rva = 0x1010
  size_of_code = 0x200
  size_of_init_data = 0x400
  size_of_image = 0x3000
  size_of_headers = 0x200

  opt_hdr = pe_build_optional_header(entry_rva, size_of_code, size_of_init_data, size_of_image, size_of_headers)
  assert_eq_int(state, opt_hdr.len(), 240, "PE-OPT-01", "PE32+ Optional Header length == exactly 240 bytes")

  @! Magic: 0x020B (PE32+ 64-bit)
  assert_eq_int(state, opt_hdr[0], 0x0B, "PE-OPT-02", "Optional Header magic byte 0 == 0x0B (11)")
  assert_eq_int(state, opt_hdr[1], 0x02, "PE-OPT-03", "Optional Header magic byte 1 == 0x02 (2)")
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 0), 0x020B, "PE-OPT-04", "Optional Header magic u16 == 0x020B (PE32+)")

  @! Linker Version: Major 14, Minor 0
  assert_eq_int(state, opt_hdr[2], 14, "PE-OPT-05", "MajorLinkerVersion == 14")
  assert_eq_int(state, opt_hdr[3], 0, "PE-OPT-06", "MinorLinkerVersion == 0")

  @! SizeOfCode & SizeOfInitializedData
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 4), size_of_code, "PE-OPT-07", "SizeOfCode == 0x200 (512)")
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 8), size_of_init_data, "PE-OPT-08", "SizeOfInitializedData == 0x400 (1024)")
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 12), 0, "PE-OPT-09", "SizeOfUninitializedData == 0")

  @! EntryPoint RVA & BaseOfCode
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 16), entry_rva, "PE-OPT-10", "AddressOfEntryPoint RVA == 0x1010 (0x1000 + 0x10)")
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 20), 0x1000, "PE-OPT-11", "BaseOfCode RVA == 0x1000 (4096)")

  @! ImageBase = 0x140000000 (8 bytes)
  assert_eq_int(state, bytes_to_u64_le(opt_hdr, 24), 5368709120, "PE-OPT-12", "ImageBase == 0x140000000 (5368709120)")

  @! SectionAlignment & FileAlignment
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 32), 0x1000, "PE-OPT-13", "SectionAlignment == 0x1000 (4096)")
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 36), 0x200, "PE-OPT-14", "FileAlignment == 0x200 (512)")

  @! Major/Minor OS & Subsystem Versions
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 40), 6, "PE-OPT-15", "MajorOperatingSystemVersion == 6")
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 42), 0, "PE-OPT-16", "MinorOperatingSystemVersion == 0")
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 48), 6, "PE-OPT-17", "MajorSubsystemVersion == 6")
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 50), 0, "PE-OPT-18", "MinorSubsystemVersion == 0")

  @! SizeOfImage & SizeOfHeaders
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 56), size_of_image, "PE-OPT-19", "SizeOfImage == 0x3000 (12288)")
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 60), size_of_headers, "PE-OPT-20", "SizeOfHeaders == 0x200 (512)")
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 64), 0, "PE-OPT-21", "CheckSum == 0")

  @! Subsystem: 3 (IMAGE_SUBSYSTEM_WINDOWS_CUI)
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 68), 3, "PE-OPT-22", "Subsystem == 3 (IMAGE_SUBSYSTEM_WINDOWS_CUI)")

  @! DllCharacteristics: 0x8160 (HIGH_ENTROPY_VA | DYNAMIC_BASE | NX_COMPAT | TERMINAL_SERVER_AWARE)
  assert_eq_int(state, opt_hdr[70], 0x60, "PE-OPT-23", "DllCharacteristics byte 0 == 0x60 (96)")
  assert_eq_int(state, opt_hdr[71], 0x81, "PE-OPT-24", "DllCharacteristics byte 1 == 0x81 (129)")
  assert_eq_int(state, bytes_to_u16_le(opt_hdr, 70), 0x8160, "PE-OPT-25", "DllCharacteristics == 0x8160 (33120)")

  @! Stack & Heap allocations (1MB reserve, 4KB commit)
  assert_eq_int(state, bytes_to_u64_le(opt_hdr, 72), 1048576, "PE-OPT-26", "SizeOfStackReserve == 1MB (1048576)")
  assert_eq_int(state, bytes_to_u64_le(opt_hdr, 80), 4096, "PE-OPT-27", "SizeOfStackCommit == 4KB (4096)")
  assert_eq_int(state, bytes_to_u64_le(opt_hdr, 88), 1048576, "PE-OPT-28", "SizeOfHeapReserve == 1MB (1048576)")
  assert_eq_int(state, bytes_to_u64_le(opt_hdr, 96), 4096, "PE-OPT-29", "SizeOfHeapCommit == 4KB (4096)")

  @! NumberOfRvaAndSizes == 16
  assert_eq_int(state, bytes_to_u32_le(opt_hdr, 108), 16, "PE-OPT-30", "NumberOfRvaAndSizes == 16 Data Directories")

  @! 16 Data Directory slots (128 bytes total from offset 112 to 239)
  dir_idx = 0
  all_dirs_zero = 1
  @while dir_idx < 16
    dir_off = 112 + (dir_idx * 8)
    dir_rva = bytes_to_u32_le(opt_hdr, dir_off)
    dir_size = bytes_to_u32_le(opt_hdr, dir_off + 4)
    @if dir_rva != 0 || dir_size != 0
      all_dirs_zero = 0
    @end
    dir_idx = dir_idx + 1
  @end
  assert_eq_int(state, all_dirs_zero, 1, "PE-OPT-31", "All 16 Data Directory entries (128 bytes) are cleanly initialized to 0")
  return 0
@end

@! Tier 5: Section Headers Verification
@fn test_tier5_section_headers(state)
  println("▶ [Tier 5] Section Headers Verification (.text, .rdata, .data)...")

  @! .text section
  sec_name_text = [46, 116, 101, 120, 116, 0, 0, 0] @! '.text\0\0\0'
  sh_text = pe_build_section_header(sec_name_text, 120, 0x1000, 0x200, 0x200, 0x60000020)
  assert_eq_int(state, sh_text.len(), 40, "PE-SEC-01", ".text Section Header length == exactly 40 bytes")
  assert_eq_int(state, sh_text[0], 46, "PE-SEC-02", ".text name byte 0 == '.' (46)")
  assert_eq_int(state, sh_text[1], 116, "PE-SEC-03", ".text name byte 1 == 't' (116)")
  assert_eq_int(state, sh_text[2], 101, "PE-SEC-04", ".text name byte 2 == 'e' (101)")
  assert_eq_int(state, sh_text[3], 120, "PE-SEC-05", ".text name byte 3 == 'x' (120)")
  assert_eq_int(state, sh_text[4], 116, "PE-SEC-06", ".text name byte 4 == 't' (116)")
  assert_eq_int(state, sh_text[5], 0, "PE-SEC-07", ".text name byte 5 == 0")
  assert_eq_int(state, bytes_to_u32_le(sh_text, 8), 120, "PE-SEC-08", ".text VirtualSize == 120")
  assert_eq_int(state, bytes_to_u32_le(sh_text, 12), 0x1000, "PE-SEC-09", ".text VirtualAddress == 0x1000 (4096)")
  assert_eq_int(state, bytes_to_u32_le(sh_text, 16), 0x200, "PE-SEC-10", ".text SizeOfRawData == 0x200 (512)")
  assert_eq_int(state, bytes_to_u32_le(sh_text, 20), 0x200, "PE-SEC-11", ".text PointerToRawData == 0x200 (512)")
  assert_eq_int(state, bytes_to_u32_le(sh_text, 36), 0x60000020, "PE-SEC-12", ".text Characteristics == 0x60000020 (CODE | EXEC | READ)")

  @! .rdata section
  sec_name_rodata = [46, 114, 100, 97, 116, 97, 0, 0] @! '.rdata\0\0'
  sh_rodata = pe_build_section_header(sec_name_rodata, 64, 0x2000, 0x200, 0x400, 0x40000040)
  assert_eq_int(state, sh_rodata.len(), 40, "PE-SEC-13", ".rdata Section Header length == exactly 40 bytes")
  assert_eq_int(state, sh_rodata[0], 46, "PE-SEC-14", ".rdata name byte 0 == '.'")
  assert_eq_int(state, sh_rodata[1], 114, "PE-SEC-15", ".rdata name byte 1 == 'r'")
  assert_eq_int(state, sh_rodata[2], 100, "PE-SEC-16", ".rdata name byte 2 == 'd'")
  assert_eq_int(state, bytes_to_u32_le(sh_rodata, 8), 64, "PE-SEC-17", ".rdata VirtualSize == 64")
  assert_eq_int(state, bytes_to_u32_le(sh_rodata, 12), 0x2000, "PE-SEC-18", ".rdata VirtualAddress == 0x2000 (8192)")
  assert_eq_int(state, bytes_to_u32_le(sh_rodata, 16), 0x200, "PE-SEC-19", ".rdata SizeOfRawData == 0x200 (512)")
  assert_eq_int(state, bytes_to_u32_le(sh_rodata, 20), 0x400, "PE-SEC-20", ".rdata PointerToRawData == 0x400 (1024)")
  assert_eq_int(state, bytes_to_u32_le(sh_rodata, 36), 0x40000040, "PE-SEC-21", ".rdata Characteristics == 0x40000040 (INIT_DATA | READ)")

  @! .data section
  sec_name_data = [46, 100, 97, 116, 97, 0, 0, 0] @! '.data\0\0\0'
  sh_data = pe_build_section_header(sec_name_data, 32, 0x3000, 0x200, 0x600, 0xC0000040)
  assert_eq_int(state, sh_data.len(), 40, "PE-SEC-22", ".data Section Header length == exactly 40 bytes")
  assert_eq_int(state, sh_data[0], 46, "PE-SEC-23", ".data name byte 0 == '.'")
  assert_eq_int(state, sh_data[1], 100, "PE-SEC-24", ".data name byte 1 == 'd'")
  assert_eq_int(state, bytes_to_u32_le(sh_data, 12), 0x3000, "PE-SEC-25", ".data VirtualAddress == 0x3000 (12288)")
  assert_eq_int(state, bytes_to_u32_le(sh_data, 20), 0x600, "PE-SEC-26", ".data PointerToRawData == 0x600 (1536)")
  assert_eq_int(state, bytes_to_u32_le(sh_data, 36), 0xC0000040, "PE-SEC-27", ".data Characteristics == 0xC0000040 (INIT_DATA | READ | WRITE)")
  return 0
@end

@! Tier 6: Full In-Memory Binary Construction & Exact Layout Verification
@fn test_tier6_in_memory_full_pe_layout(state)
  println("▶ [Tier 6] In-Memory Full PE32+ Binary Assembly & Layout Verification...")

  code = [
    72, 131, 236, 40,             @! sub rsp, 40 (4 bytes)
    72, 199, 193, 0, 0, 0, 0,     @! mov rcx, 0 (7 bytes)
    72, 199, 192, 42, 0, 0, 0,    @! mov rax, 42 (7 bytes)
    72, 131, 196, 40,             @! add rsp, 40 (4 bytes)
    195                           @! ret (1 byte) -> Total 23 bytes
  ]
  rodata = [72, 101, 108, 108, 111, 44, 32, 87, 105, 110, 100, 111, 119, 115, 33, 0] @! "Hello, Windows!\0"
  data = [10, 20, 30, 40, 50, 60, 70, 80]
  entry_offset = 0

  bin = assemble_pe_in_memory(code, rodata, data, entry_offset)

  @! Total File Size: Header (0x200) + .text (0x200) + .rdata (0x200) + .data (0x200) = 0x800 (2048 bytes)
  assert_eq_int(state, bin.len(), 2048, "PE-MEM-01", "Full PE32+ assembled size == 2048 bytes (0x800)")
  assert_eq_int(state, bin.len() % 0x200, 0, "PE-MEM-02", "Binary size is cleanly aligned to FileAlignment (0x200)")

  @! DOS Header at offset 0
  assert_eq_int(state, bin[0], 77, "PE-MEM-03", "Offset 0 == 'M' (77)")
  assert_eq_int(state, bin[1], 90, "PE-MEM-04", "Offset 1 == 'Z' (90)")
  assert_eq_int(state, bytes_to_u32_le(bin, 60), 128, "PE-MEM-05", "Offset 60 e_lfanew == 128 (points to PE sig at 128)")

  @! DOS Stub at offset 64..127
  assert_eq_int(state, bin[64], 14, "PE-MEM-06", "Offset 64 (DOS stub start) == 0x0E")

  @! PE Signature at offset 128
  assert_eq_int(state, bin[128], 80, "PE-MEM-07", "Offset 128 PE sig byte 0 == 'P'")
  assert_eq_int(state, bin[129], 69, "PE-MEM-08", "Offset 129 PE sig byte 1 == 'E'")
  assert_eq_int(state, bin[130], 0, "PE-MEM-09", "Offset 130 PE sig byte 2 == 0")
  assert_eq_int(state, bin[131], 0, "PE-MEM-10", "Offset 131 PE sig byte 3 == 0")

  @! COFF Header at offset 132..151
  assert_eq_int(state, bytes_to_u16_le(bin, 132), 0x8664, "PE-MEM-11", "Offset 132 Machine == 0x8664 (AMD64)")
  assert_eq_int(state, bytes_to_u16_le(bin, 134), 3, "PE-MEM-12", "Offset 134 NumberOfSections == 3")
  assert_eq_int(state, bytes_to_u16_le(bin, 148), 240, "PE-MEM-13", "Offset 148 SizeOfOptionalHeader == 240")
  assert_eq_int(state, bytes_to_u16_le(bin, 150), 0x0022, "PE-MEM-14", "Offset 150 Characteristics == 0x0022")

  @! Optional Header at offset 152..391
  assert_eq_int(state, bytes_to_u16_le(bin, 152), 0x020B, "PE-MEM-15", "Offset 152 Opt Magic == 0x020B (PE32+)")
  assert_eq_int(state, bytes_to_u32_le(bin, 168), 0x1000, "PE-MEM-16", "Offset 168 AddressOfEntryPoint == 0x1000")
  assert_eq_int(state, bytes_to_u32_le(bin, 172), 0x1000, "PE-MEM-17", "Offset 172 BaseOfCode == 0x1000")
  assert_eq_int(state, bytes_to_u64_le(bin, 176), 5368709120, "PE-MEM-18", "Offset 176 ImageBase == 0x140000000 (5368709120)")
  assert_eq_int(state, bytes_to_u32_le(bin, 184), 0x1000, "PE-MEM-19", "Offset 184 SectionAlignment == 0x1000")
  assert_eq_int(state, bytes_to_u32_le(bin, 188), 0x200, "PE-MEM-20", "Offset 188 FileAlignment == 0x200")
  assert_eq_int(state, bytes_to_u32_le(bin, 208), 0x4000, "PE-MEM-21", "Offset 208 SizeOfImage == 0x4000 (16384)")
  assert_eq_int(state, bytes_to_u32_le(bin, 212), 0x200, "PE-MEM-22", "Offset 212 SizeOfHeaders == 0x200 (512)")
  assert_eq_int(state, bytes_to_u16_le(bin, 220), 3, "PE-MEM-23", "Offset 220 Subsystem == 3 (CUI)")
  assert_eq_int(state, bytes_to_u16_le(bin, 222), 0x8160, "PE-MEM-24", "Offset 222 DllCharacteristics == 0x8160")
  assert_eq_int(state, bytes_to_u32_le(bin, 260), 16, "PE-MEM-25", "Offset 260 NumberOfRvaAndSizes == 16")

  @! Section Header 1 (.text) at offset 392..431
  assert_eq_int(state, bin[392], 46, "PE-MEM-26", "Offset 392 .text name byte 0 == '.'")
  assert_eq_int(state, bin[393], 116, "PE-MEM-27", "Offset 393 .text name byte 1 == 't'")
  assert_eq_int(state, bytes_to_u32_le(bin, 404), 0x1000, "PE-MEM-28", "Offset 404 .text VirtualAddress == 0x1000")
  assert_eq_int(state, bytes_to_u32_le(bin, 408), 0x200, "PE-MEM-29", "Offset 408 .text SizeOfRawData == 0x200")
  assert_eq_int(state, bytes_to_u32_le(bin, 412), 0x200, "PE-MEM-30", "Offset 412 .text PointerToRawData == 0x200")
  assert_eq_int(state, bytes_to_u32_le(bin, 428), 0x60000020, "PE-MEM-31", "Offset 428 .text Characteristics == 0x60000020")

  @! Section Header 2 (.rdata) at offset 432..471
  assert_eq_int(state, bin[432], 46, "PE-MEM-32", "Offset 432 .rdata name byte 0 == '.'")
  assert_eq_int(state, bin[433], 114, "PE-MEM-33", "Offset 433 .rdata name byte 1 == 'r'")
  assert_eq_int(state, bytes_to_u32_le(bin, 444), 0x2000, "PE-MEM-34", "Offset 444 .rdata VirtualAddress == 0x2000")
  assert_eq_int(state, bytes_to_u32_le(bin, 448), 0x200, "PE-MEM-35", "Offset 448 .rdata SizeOfRawData == 0x200")
  assert_eq_int(state, bytes_to_u32_le(bin, 452), 0x400, "PE-MEM-36", "Offset 452 .rdata PointerToRawData == 0x400")
  assert_eq_int(state, bytes_to_u32_le(bin, 468), 0x40000040, "PE-MEM-37", "Offset 468 .rdata Characteristics == 0x40000040")

  @! Section Header 3 (.data) at offset 472..511
  assert_eq_int(state, bin[472], 46, "PE-MEM-38", "Offset 472 .data name byte 0 == '.'")
  assert_eq_int(state, bin[473], 100, "PE-MEM-39", "Offset 473 .data name byte 1 == 'd'")
  assert_eq_int(state, bytes_to_u32_le(bin, 484), 0x3000, "PE-MEM-40", "Offset 484 .data VirtualAddress == 0x3000")
  assert_eq_int(state, bytes_to_u32_le(bin, 488), 0x200, "PE-MEM-41", "Offset 488 .data SizeOfRawData == 0x200")
  assert_eq_int(state, bytes_to_u32_le(bin, 492), 0x600, "PE-MEM-42", "Offset 492 .data PointerToRawData == 0x600")
  assert_eq_int(state, bytes_to_u32_le(bin, 508), 0xC0000040, "PE-MEM-43", "Offset 508 .data Characteristics == 0xC0000040")

  @! .text raw data at offset 0x200 (512)
  assert_eq_int(state, bin[512], 72, "PE-MEM-44", "Offset 512 (.text raw start) == 0x48 (72)")
  assert_eq_int(state, bin[513], 131, "PE-MEM-45", "Offset 513 == 0x83 (131)")
  assert_eq_int(state, bin[534], 195, "PE-MEM-46", "Offset 534 (.text code end) == 0xC3 (195 ret)")
  @! NOP (0x90 = 144) padding in .text
  assert_eq_int(state, bin[535], 144, "PE-MEM-47", "Offset 535 (.text NOP padding start) == 0x90 (144)")
  assert_eq_int(state, bin[1023], 144, "PE-MEM-48", "Offset 1023 (.text NOP padding end) == 0x90 (144)")

  @! .rdata raw data at offset 0x400 (1024)
  assert_eq_int(state, bin[1024], 72, "PE-MEM-49", "Offset 1024 (.rdata raw start) == 'H' (72)")
  assert_eq_int(state, bin[1025], 101, "PE-MEM-50", "Offset 1025 (.rdata raw) == 'e' (101)")
  assert_eq_int(state, bin[1039], 0, "PE-MEM-51", "Offset 1039 (.rdata string null terminator) == 0")
  assert_eq_int(state, bin[1040], 0, "PE-MEM-52", "Offset 1040 (.rdata zero padding) == 0")
  assert_eq_int(state, bin[1535], 0, "PE-MEM-53", "Offset 1535 (.rdata zero padding end) == 0")

  @! .data raw data at offset 0x600 (1536)
  assert_eq_int(state, bin[1536], 10, "PE-MEM-54", "Offset 1536 (.data raw start) == 10")
  assert_eq_int(state, bin[1537], 20, "PE-MEM-55", "Offset 1537 (.data raw) == 20")
  assert_eq_int(state, bin[1543], 80, "PE-MEM-56", "Offset 1543 (.data raw) == 80")
  assert_eq_int(state, bin[1544], 0, "PE-MEM-57", "Offset 1544 (.data zero padding) == 0")
  assert_eq_int(state, bin[2047], 0, "PE-MEM-58", "Offset 2047 (binary end) == 0")
  return 0
@end

@! Tier 7: End-to-End Disk Emission & Binary Verification
@fn test_tier7_disk_emission_and_syscalls(state)
  println("▶ [Tier 7] Disk File Emission & Syscall Output Verification...")

  out_path = "/tmp/maya_test_e2e_pe64_full.exe"

  code = [
    72, 199, 192, 1, 0, 0, 0,     @! mov rax, 1
    72, 199, 199, 0, 0, 0, 0,     @! mov rdi, 0
    195                           @! ret
  ]
  rodata = [80, 69, 54, 52, 32, 77, 97, 121, 97, 0] @! "PE64 Maya\0"
  data = [255, 0, 255, 0]
  entry_offset = 0

  x86_obj = {
    text_bytes: code,
    rodata_bytes: rodata,
    data_bytes: data,
    entry_offset: entry_offset
  }

  pe_res = pe_write_executable(x86_obj, out_path)

  assert_eq_int(state, pe_res.pe_success, 1, "PE-DISK-01", "pe_write_executable returns pe_success == 1")
  assert_eq_str(state, pe_res.pe_out_path, out_path, "PE-DISK-02", "pe_write_executable returns correct pe_out_path")
  assert_eq_int(state, pe_res.pe_file_size, 2048, "PE-DISK-03", "pe_write_executable returns pe_file_size == 2048")
  assert_eq_int(state, pe_res.pe_entry_vaddr, 5368713216, "PE-DISK-04", "pe_entry_vaddr == 0x140001000 (ImageBase + 0x1000)")
  assert_eq_str(state, pe_res.pe_error_msg, "", "PE-DISK-05", "pe_error_msg is empty string")

  @! Verify file exists on filesystem
  exists = path_exists(out_path)
  assert_eq_int(state, exists, 1, "PE-DISK-06", "Output executable file exists on disk (/tmp/maya_test_e2e_pe64_full.exe)")

  @! Clean up temporary executable
  sys_unlink(out_path)
  return 0
@end

@! Tier 8: Convenience Wrappers & Varied Payload Suites
@fn test_tier8_wrappers_and_variations(state)
  println("▶ [Tier 8] Convenience Wrappers & Varied Section Topologies...")

  @! 1. Minimal 1-Section Binary (Code Only)
  out_path_min = "/tmp/maya_test_pe_min.exe"
  min_code = [144, 195] @! NOP, RET
  min_res = pe_write_executable({ text_bytes: min_code, rodata_bytes: [], data_bytes: [], entry_offset: 0 }, out_path_min)
  assert_eq_int(state, min_res.pe_success, 1, "PE-VAR-01", "1-section minimal PE executable generated successfully")
  assert_eq_int(state, min_res.pe_file_size, 1024, "PE-VAR-02", "1-section PE file size == 0x400 (1024 bytes: 0x200 hdr + 0x200 text)")
  assert_eq_int(state, path_exists(out_path_min), 1, "PE-VAR-03", "1-section PE file created on disk")
  sys_unlink(out_path_min)

  @! 2. 2-Section Binary (.text + .rdata)
  out_path_2sec = "/tmp/maya_test_pe_2sec.exe"
  sec2_res = pe_write_executable({ text_bytes: min_code, rodata_bytes: [65, 66, 67, 0], data_bytes: [], entry_offset: 0 }, out_path_2sec)
  assert_eq_int(state, sec2_res.pe_success, 1, "PE-VAR-04", "2-section (.text + .rdata) PE executable generated successfully")
  assert_eq_int(state, sec2_res.pe_file_size, 1536, "PE-VAR-05", "2-section PE file size == 0x600 (1536 bytes: 0x200 hdr + 0x200 text + 0x200 rdata)")
  assert_eq_int(state, path_exists(out_path_2sec), 1, "PE-VAR-06", "2-section PE file created on disk")
  sys_unlink(out_path_2sec)

  @! 3. Custom Entrypoint Offset
  out_path_custom_entry = "/tmp/maya_test_pe_custom_entry.exe"
  entry_custom_res = pe_write_executable({ text_bytes: min_code, rodata_bytes: [], data_bytes: [], entry_offset: 0x20 }, out_path_custom_entry)
  assert_eq_int(state, entry_custom_res.pe_success, 1, "PE-VAR-07", "Custom entrypoint offset PE generated successfully")
  assert_eq_int(state, entry_custom_res.pe_entry_vaddr, 5368713248, "PE-VAR-08", "pe_entry_vaddr == 0x140001020 (ImageBase + 0x1000 + 0x20)")
  sys_unlink(out_path_custom_entry)

  @! 4. emit_pe_64_executable Convenience Wrapper
  out_path_wrap = "/tmp/maya_test_pe_wrap.exe"
  wrap_res = emit_pe_64_executable(out_path_wrap, [72, 199, 192, 0, 0, 0, 0, 195])
  assert_eq_int(state, wrap_res, 1, "PE-VAR-09", "emit_pe_64_executable returns 1 (success)")
  assert_eq_int(state, path_exists(out_path_wrap), 1, "PE-VAR-10", "Wrapped executable exists on disk")
  sys_unlink(out_path_wrap)

  @! 5. write_pe64_executable Alias Wrapper
  out_path_alias = "/tmp/maya_test_pe_alias.exe"
  alias_res = write_pe64_executable([72, 199, 192, 1, 0, 0, 0, 195], out_path_alias)
  assert_eq_int(state, alias_res, 1, "PE-VAR-11", "write_pe64_executable returns 1 (success)")
  assert_eq_int(state, path_exists(out_path_alias), 1, "PE-VAR-12", "Aliased executable exists on disk")
  sys_unlink(out_path_alias)

  @! 6. Multi-Block Code Section (> 512 bytes) Alignment
  out_path_large = "/tmp/maya_test_pe_large.exe"
  large_code = []
  i = 0
  @while i < 600
    large_code = large_code.push(144) @! 600 NOP instructions
    i = i + 1
  @end
  large_code = large_code.push(195) @! RET

  large_res = pe_write_executable({ text_bytes: large_code, rodata_bytes: [], data_bytes: [], entry_offset: 0 }, out_path_large)
  assert_eq_int(state, large_res.pe_success, 1, "PE-VAR-13", "Large multi-block code PE generated successfully")
  @! 601 bytes code -> text_raw_size aligns to 1024 (0x400) -> file_size = 0x200 (headers) + 0x400 (code) = 1536 (0x600)
  assert_eq_int(state, large_res.pe_file_size, 1536, "PE-VAR-14", "Large code section raw size correctly aligned to 0x400 -> total 1536 bytes")
  assert_eq_int(state, path_exists(out_path_large), 1, "PE-VAR-15", "Large code PE exists on disk")
  sys_unlink(out_path_large)
  return 0
@end

@! ============================================================================
@! 4. MAIN RUNNER
@! ============================================================================

@fn main()
  println("============================================================================")
  println("   MAYA UNIVERSAL ARCHITECTURE: WINDOWS PE32+ (PE64) WRITER E2E TEST SUITE  ")
  println("============================================================================")

  state = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_tier1_encoders_alignment(state)
  test_tier2_dos_header_and_stub(state)
  test_tier3_pe_signature_and_coff(state)
  test_tier4_optional_header_64(state)
  test_tier5_section_headers(state)
  test_tier6_in_memory_full_pe_layout(state)
  test_tier7_disk_emission_and_syscalls(state)
  test_tier8_wrappers_and_variations(state)

  println("----------------------------------------------------------------------------")
  println("E2E PE WRITER TEST SUMMARY:")
  println("  Total Assertions : " + state.total.to_str())
  println("  Passed           : " + state.passed.to_str())
  println("  Failed           : " + state.failed.to_str())
  println("----------------------------------------------------------------------------")

  @if state.failed == 0
    println("🎉 ALL WINDOWS PE32+ WRITER E2E TESTS PASSED WITH 100% SUCCESS!")
    return 0
  @else
    println("❌ SOME TESTS FAILED!")
    return 1
  @end
@end
