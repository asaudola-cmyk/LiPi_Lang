import "universe/core/collections"
import "universe/os/fs"

@fn macho_u16(v)
  return [v % 256, (v / 256) % 256]
@end

@fn macho_u32(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn macho_u64(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256,
    0, 0, 0, 0
  ]
@end

@fn macho_append(target, source)
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

@fn write_macho64_executable(machine_code, output_path)
  println("  [Mach-O Emitter] Building macOS 64-bit Mach-O Executable...")
  
  code_len = machine_code.len()
  aligned_code_size = code_len
  @while aligned_code_size % 16 != 0
    aligned_code_size = aligned_code_size + 1
  @end
  
  header_and_cmds_size = 32 + 72 + 80 + 184 @! mach_header(32) + LC_SEGMENT(72) + section(80) + LC_UNIXTHREAD(184)
  offset_to_code = 4096 @! Aligned to 4KB page
  entry_point = 4294967296 + offset_to_code @! 0x100000000 + 0x1000
  
  @! 1. Mach-O 64-bit Header (32 bytes)
  hdr = []
  hdr = macho_append(hdr, [207, 250, 237, 254])  @! MH_MAGIC_64 (0xFEEDFACF)
  hdr = macho_append(hdr, [7, 0, 0, 1])          @! CPU_TYPE_X86_64 (0x01000007)
  hdr = macho_append(hdr, [3, 0, 0, 128])        @! CPU_SUBTYPE_LIB64 (0x80000003)
  hdr = macho_append(hdr, macho_u32(2))          @! MH_EXECUTE (2)
  hdr = macho_append(hdr, macho_u32(2))          @! ncmds = 2 (LC_SEGMENT_64 + LC_UNIXTHREAD)
  hdr = macho_append(hdr, macho_u32(152 + 184))  @! sizeofcmds (72+80 + 184)
  hdr = macho_append(hdr, macho_u32(133))        @! flags = MH_NOUNDEFS (0x85)
  hdr = macho_append(hdr, macho_u32(0))          @! reserved
  
  @! 2. LC_SEGMENT_64 Command (__TEXT, 72 bytes + 80 bytes section)
  seg_cmd = []
  seg_cmd = macho_append(seg_cmd, macho_u32(25))        @! LC_SEGMENT_64 (0x19)
  seg_cmd = macho_append(seg_cmd, macho_u32(72 + 80))   @! cmdsize
  seg_cmd = macho_append(seg_cmd, [95, 95, 84, 69, 88, 84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) @! "__TEXT\0..."
  seg_cmd = macho_append(seg_cmd, macho_u64(4294967296)) @! vmaddr (0x100000000)
  seg_cmd = macho_append(seg_cmd, macho_u64(4096 + aligned_code_size)) @! vmsize
  seg_cmd = macho_append(seg_cmd, macho_u64(0))          @! fileoff (0)
  seg_cmd = macho_append(seg_cmd, macho_u64(4096 + aligned_code_size)) @! filesize
  seg_cmd = macho_append(seg_cmd, macho_u32(7))          @! maxprot (VM_PROT_ALL)
  seg_cmd = macho_append(seg_cmd, macho_u32(5))          @! initprot (VM_PROT_READ | VM_PROT_EXEC)
  seg_cmd = macho_append(seg_cmd, macho_u32(1))          @! nsects = 1
  seg_cmd = macho_append(seg_cmd, macho_u32(0))          @! flags
  
  @! Section 64 (__text, 80 bytes)
  sec_cmd = []
  sec_cmd = macho_append(sec_cmd, [95, 95, 116, 101, 120, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) @! "__text\0..."
  sec_cmd = macho_append(sec_cmd, [95, 95, 84, 69, 88, 84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) @! "__TEXT\0..."
  sec_cmd = macho_append(sec_cmd, macho_u64(entry_point))       @! addr
  sec_cmd = macho_append(sec_cmd, macho_u64(aligned_code_size)) @! size
  sec_cmd = macho_append(sec_cmd, macho_u32(offset_to_code))    @! offset
  sec_cmd = macho_append(sec_cmd, macho_u32(4))                 @! align (2^4 = 16)
  sec_cmd = macho_append(sec_cmd, macho_u32(0))                 @! reloff
  sec_cmd = macho_append(sec_cmd, macho_u32(0))                 @! nreloc
  sec_cmd = macho_append(sec_cmd, macho_u32(2147484672))        @! flags = S_ATTR_SOME_INSTRUCTIONS | S_ATTR_PURE_INSTRUCTIONS
  sec_cmd = macho_append(sec_cmd, macho_u32(0))                 @! reserved1
  sec_cmd = macho_append(sec_cmd, macho_u32(0))                 @! reserved2
  sec_cmd = macho_append(sec_cmd, macho_u32(0))                 @! reserved3
  
  @! 3. LC_UNIXTHREAD Command (184 bytes for x86_64)
  th_cmd = []
  th_cmd = macho_append(th_cmd, macho_u32(5))     @! LC_UNIXTHREAD (5)
  th_cmd = macho_append(th_cmd, macho_u32(184))   @! cmdsize (184)
  th_cmd = macho_append(th_cmd, macho_u32(4))     @! flavor = x86_THREAD_STATE64 (4)
  th_cmd = macho_append(th_cmd, macho_u32(42))    @! count = x86_THREAD_STATE64_COUNT (42 uint32s)
  
  @! Thread State: rax, rbx, rcx, rdx, rdi, rsi, rbp, rsp, r8..r15 (16 * 8 = 128 bytes)
  i = 0
  @while i < 128
    th_cmd = th_cmd.push(0)
    i = i + 1
  @end
  @! RIP at offset 128 (8 bytes)
  th_cmd = macho_append(th_cmd, macho_u64(entry_point))
  @! RFLAGS, CS, FS, GS (16 bytes of zeros)
  i = 0
  @while i < 16
    th_cmd = th_cmd.push(0)
    i = i + 1
  @end
  
  @! Assemble Headers
  full_bytes = []
  full_bytes = macho_append(full_bytes, hdr)
  full_bytes = macho_append(full_bytes, seg_cmd)
  full_bytes = macho_append(full_bytes, sec_cmd)
  full_bytes = macho_append(full_bytes, th_cmd)
  
  @! Pad up to offset_to_code (4096)
  @while full_bytes.len() < offset_to_code
    full_bytes = full_bytes.push(0)
  @end
  
  @! Append code bytes
  full_bytes = macho_append(full_bytes, machine_code)
  @while full_bytes.len() < (offset_to_code + aligned_code_size)
    full_bytes = full_bytes.push(0)
  @end
  
  raw_bytes = bytes_to_raw_string(full_bytes)
  write_file(output_path, raw_bytes)
  println("  ✓ Mach-O executable written successfully: " + output_path)
  return full_bytes
@end

@fn emit_macho_64_executable(out_path, machine_code_bytes)
  write_macho64_executable(machine_code_bytes, out_path)
  return 1
@end

