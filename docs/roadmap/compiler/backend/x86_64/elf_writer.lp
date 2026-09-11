@! ============================================================================
@! MAYA COMPILER STAGE 4 — COMPLETE ELF64 NATIVE BINARY EMITTER
@! 100% Written in Pure Maya Language — Zero GCC / Clang / LLD Dependency
import "universe/os/fs"
@! ============================================================================

import "universe/core/collections"

@fn u16_to_bytes(v)
  return [v % 256, (v / 256) % 256]
@end

@fn u32_to_bytes(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn u64_to_bytes(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256,
    0, 0, 0, 0
  ]
@end

@fn elf_append(target, source)
  @for item in source
    target = target.push(item)
  @end
  return target
@end

@fn elf_make_section_header(name_offset, type_flags, flags, addr, offset, size, link, info, addralign, entsize)
  sh = []
  sh = elf_append(sh, u32_to_bytes(name_offset))  @! sh_name
  sh = elf_append(sh, u32_to_bytes(type_flags))   @! sh_type
  sh = elf_append(sh, u64_to_bytes(flags))        @! sh_flags
  sh = elf_append(sh, u64_to_bytes(addr))         @! sh_addr
  sh = elf_append(sh, u64_to_bytes(offset))       @! sh_offset
  sh = elf_append(sh, u64_to_bytes(size))         @! sh_size
  sh = elf_append(sh, u32_to_bytes(link))         @! sh_link
  sh = elf_append(sh, u32_to_bytes(info))         @! sh_info
  sh = elf_append(sh, u64_to_bytes(addralign))    @! sh_addralign
  sh = elf_append(sh, u64_to_bytes(entsize))      @! sh_entsize
  return sh
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

@fn emit_elf_64_executable(out_path, machine_code_bytes)
  println("  [ELF Emitter] Building complete 64-bit ELF executable with Section Tables...")
  
  code_size = machine_code_bytes.len()
  shstrtab = [0, 46, 116, 101, 120, 116, 0, 46, 115, 104, 115, 116, 114, 116, 97, 98, 0]
  shstrtab_size = shstrtab.len()
  
  code_offset = 64 + 56
  entry_point = 0x400000 + code_offset
  shstrtab_offset = code_offset + code_size
  sh_offset = shstrtab_offset + shstrtab_size
  
  elf_header = [
    0x7F, 69, 76, 70,
    2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 0,
    0x3E, 0,
    1, 0, 0, 0
  ]
  
  elf_header = elf_append(elf_header, u64_to_bytes(entry_point))
  elf_header = elf_append(elf_header, u64_to_bytes(64))
  elf_header = elf_append(elf_header, u64_to_bytes(sh_offset))
  elf_header = elf_append(elf_header, u32_to_bytes(0))
  elf_header = elf_append(elf_header, u16_to_bytes(64))
  elf_header = elf_append(elf_header, u16_to_bytes(56))
  elf_header = elf_append(elf_header, u16_to_bytes(1))
  elf_header = elf_append(elf_header, u16_to_bytes(64))
  elf_header = elf_append(elf_header, u16_to_bytes(3))
  elf_header = elf_append(elf_header, u16_to_bytes(2))
  
  file_total_mem = code_offset + code_size + shstrtab_size
  prog_header = [1, 0, 0, 0, 5, 0, 0, 0]
  prog_header = elf_append(prog_header, u64_to_bytes(0))
  prog_header = elf_append(prog_header, u64_to_bytes(0x400000))
  prog_header = elf_append(prog_header, u64_to_bytes(0x400000))
  prog_header = elf_append(prog_header, u64_to_bytes(file_total_mem))
  prog_header = elf_append(prog_header, u64_to_bytes(file_total_mem))
  prog_header = elf_append(prog_header, u64_to_bytes(0x1000))
  
  sh_null = elf_make_section_header(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  sh_text = elf_make_section_header(1, 1, 6, entry_point, code_offset, code_size, 0, 0, 16, 0)
  sh_shstrtab = elf_make_section_header(7, 3, 0, 0, shstrtab_offset, shstrtab_size, 0, 0, 1, 0)
  
  final_binary = []
  final_binary = elf_append(final_binary, elf_header)
  final_binary = elf_append(final_binary, prog_header)
  final_binary = elf_append(final_binary, machine_code_bytes)
  final_binary = elf_append(final_binary, shstrtab)
  final_binary = elf_append(final_binary, sh_null)
  final_binary = elf_append(final_binary, sh_text)
  final_binary = elf_append(final_binary, sh_shstrtab)
  
  raw_bytes = bytes_to_raw_string(final_binary)
  write_file(out_path, raw_bytes)
  println("  ✓ ELF64 Native Executable successfully generated: " + out_path + " (" + final_binary.len().to_str() + " bytes)")
  return out_path
@end
