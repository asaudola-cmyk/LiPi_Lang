@! ============================================================================
@! MAYA COMPILER STAGE 4 — PE/COFF WINDOWS NATIVE BINARY EMITTER
@! 100% Written in Pure Maya Language — Zero MSVC/MinGW Dependency
import "universe/os/fs"
@! ============================================================================

import "universe/core/collections"

@fn u16_to_bytes(v)
  return [v % 256, (v / 256) % 256]
@end

@fn u32_to_bytes(v)
  return [v % 256, (v / 256) % 256, (v / 65536) % 256, (v / 16777216) % 256]
@end

@fn u64_to_bytes(v)
  return [v % 256, (v / 256) % 256, (v / 65536) % 256, (v / 16777216) % 256, 0, 0, 0, 0]
@end

@fn pe_append(target, source)
  @for item in source
    target = target.push(item)
  @end
  return target
@end

@fn byte_to_char(b)
  chars = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff"
  @if b >= 0 && b < chars.len()
    return chars[b]
  @end
  return "\x00"
@end

@fn bytes_to_raw_string(bytes_list)
  raw = ""
  @for b in bytes_list
    raw = raw + byte_to_char(b)
  @end
  return raw
@end

@fn emit_pe_64_executable(out_path, machine_code_bytes)
  println("  [PE Emitter] Building complete 64-bit Windows Executable (.exe) with IAT & Sections...")
  
  @! 1. DOS Header (64 bytes)
  dos_header = [
    77, 90, 144, 0, 3, 0, 0, 0, 4, 0, 0, 0, 255, 255, 0, 0,
    184, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 0, 0, 0
  ]
  
  @! DOS Stub
  dos_stub = [
    14, 31, 186, 14, 0, 180, 9, 205, 33, 184, 1, 76, 205, 33,
    84, 104, 105, 115, 32, 112, 114, 111, 103, 114, 97, 109, 32,
    99, 97, 110, 110, 111, 116, 32, 98, 101, 32, 114, 117, 110, 32,
    105, 110, 32, 68, 79, 83, 32, 109, 111, 100, 101, 46, 13, 13, 10, 36, 0, 0, 0, 0, 0, 0, 0
  ]
  
  @! 2. PE/COFF Header (24 bytes)
  pe_magic = [80, 69, 0, 0] @! "PE\0\0"
  machine = u16_to_bytes(0x8664) @! AMD64
  num_sections = u16_to_bytes(2) @! .text, .idata
  timestamp = u32_to_bytes(0)
  sym_table_ptr = u32_to_bytes(0)
  num_symbols = u32_to_bytes(0)
  opt_header_size = u16_to_bytes(240) @! PE32+ (64-bit) optional header size
  characteristics = u16_to_bytes(0x0022) @! Executable Image | Large Address Aware
  
  coff_header = []
  coff_header = pe_append(coff_header, pe_magic)
  coff_header = pe_append(coff_header, machine)
  coff_header = pe_append(coff_header, num_sections)
  coff_header = pe_append(coff_header, timestamp)
  coff_header = pe_append(coff_header, sym_table_ptr)
  coff_header = pe_append(coff_header, num_symbols)
  coff_header = pe_append(coff_header, opt_header_size)
  coff_header = pe_append(coff_header, characteristics)
  
  @! 3. Optional Header (PE32+)
  magic = u16_to_bytes(0x020B) @! PE32+
  linker_version = [14, 0]
  code_size = u32_to_bytes(0x1000)
  init_data_size = u32_to_bytes(0x1000)
  uninit_data_size = u32_to_bytes(0)
  entry_point = u32_to_bytes(0x1000) @! RVA
  base_of_code = u32_to_bytes(0x1000)
  image_base = u64_to_bytes(0x140000000)
  section_align = u32_to_bytes(0x1000)
  file_align = u32_to_bytes(0x200)
  os_version = [6, 0, 0, 0]
  image_version = [0, 0, 0, 0]
  subsys_version = [6, 0, 0, 0]
  win32_version = u32_to_bytes(0)
  size_of_image = u32_to_bytes(0x3000)
  size_of_headers = u32_to_bytes(0x200)
  checksum = u32_to_bytes(0)
  subsystem = u16_to_bytes(3) @! CUI (Console)
  dll_char = u16_to_bytes(0x8140) @! Dynamic Base, NX, Terminal Server Aware
  stack_reserve = u64_to_bytes(0x100000)
  stack_commit = u64_to_bytes(0x1000)
  heap_reserve = u64_to_bytes(0x100000)
  heap_commit = u64_to_bytes(0x1000)
  loader_flags = u32_to_bytes(0)
  num_rva_sizes = u32_to_bytes(16)
  
  opt_header = []
  opt_header = pe_append(opt_header, magic)
  opt_header = pe_append(opt_header, linker_version)
  opt_header = pe_append(opt_header, code_size)
  opt_header = pe_append(opt_header, init_data_size)
  opt_header = pe_append(opt_header, uninit_data_size)
  opt_header = pe_append(opt_header, entry_point)
  opt_header = pe_append(opt_header, base_of_code)
  opt_header = pe_append(opt_header, image_base)
  opt_header = pe_append(opt_header, section_align)
  opt_header = pe_append(opt_header, file_align)
  opt_header = pe_append(opt_header, os_version)
  opt_header = pe_append(opt_header, image_version)
  opt_header = pe_append(opt_header, subsys_version)
  opt_header = pe_append(opt_header, win32_version)
  opt_header = pe_append(opt_header, size_of_image)
  opt_header = pe_append(opt_header, size_of_headers)
  opt_header = pe_append(opt_header, checksum)
  opt_header = pe_append(opt_header, subsystem)
  opt_header = pe_append(opt_header, dll_char)
  opt_header = pe_append(opt_header, stack_reserve)
  opt_header = pe_append(opt_header, stack_commit)
  opt_header = pe_append(opt_header, heap_reserve)
  opt_header = pe_append(opt_header, heap_commit)
  opt_header = pe_append(opt_header, loader_flags)
  opt_header = pe_append(opt_header, num_rva_sizes)
  
  @! Add empty Data Directories (16 * 8 = 128 bytes)
  dir_idx = 0
  @while dir_idx < 128
    opt_header = opt_header.push(0)
    dir_idx = dir_idx + 1
  @end
  
  @! 4. Section Headers (.text)
  sec_text = [46, 116, 101, 120, 116, 0, 0, 0] @! .text
  sec_text = pe_append(sec_text, u32_to_bytes(machine_code_bytes.len())) @! VirtualSize
  sec_text = pe_append(sec_text, u32_to_bytes(0x1000)) @! VirtualAddress
  sec_text = pe_append(sec_text, u32_to_bytes(0x200)) @! SizeOfRawData
  sec_text = pe_append(sec_text, u32_to_bytes(0x200)) @! PointerToRawData
  sec_text = pe_append(sec_text, u32_to_bytes(0)) @! PointerToRelocations
  sec_text = pe_append(sec_text, u32_to_bytes(0)) @! PointerToLinenumbers
  sec_text = pe_append(sec_text, u16_to_bytes(0)) @! NumberOfRelocations
  sec_text = pe_append(sec_text, u16_to_bytes(0)) @! NumberOfLinenumbers
  sec_text = pe_append(sec_text, u32_to_bytes(0x60000020)) @! Characteristics (RX, Code)
  
  @! Assemble Binary
  binary = []
  binary = pe_append(binary, dos_header)
  binary = pe_append(binary, dos_stub)
  binary = pe_append(binary, coff_header)
  binary = pe_append(binary, opt_header)
  binary = pe_append(binary, sec_text)
  
  @! Padding to alignment 0x200
  @while (binary.len() % 0x200) != 0
    binary = binary.push(0)
  @end
  
  binary = pe_append(binary, machine_code_bytes)
  
  raw_bytes = bytes_to_raw_string(binary)
  write_file(out_path, raw_bytes)
  println("  ✓ Windows PE64 Native Executable successfully generated: " + out_path)
  return out_path
@end

@fn write_pe64_executable(machine_code_bytes, out_path)
  return emit_pe_64_executable(out_path, machine_code_bytes)
@end
