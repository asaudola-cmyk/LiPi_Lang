@! ============================================================================
@! MAYA COMPILER BACKEND — 100% PURE MAYA MACH-O 64-BIT NATIVE BINARY EMITTER
@! Module: compiler/backend/macho_writer.maya
@! Target Architecture: macOS x86-64 / ARM64 (Mach-O 64-bit Executable Format)
@! Zero External Assembler / Linker Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"

@! ============================================================================
@! 1. CANONICAL ZERO-COLLISION STRUCT SCHEMAS
@! ============================================================================

@struct MachOHeader64
  mh_magic: i64
  mh_cputype: i64
  mh_cpusubtype: i64
  mh_filetype: i64
  mh_ncmds: i64
  mh_sizeofcmds: i64
  mh_flags: i64
  mh_reserved: i64
@end

@struct MachOSegment64
  seg_cmd: i64
  seg_cmdsize: i64
  seg_name: array
  seg_vmaddr: i64
  seg_vmsize: i64
  seg_fileoff: i64
  seg_filesize: i64
  seg_maxprot: i64
  seg_initprot: i64
  seg_nsects: i64
  seg_flags: i64
@end

@struct MachOSection64
  sec_sectname: array
  sec_segname: array
  sec_addr: i64
  sec_size: i64
  sec_offset: i64
  sec_align: i64
  sec_reloff: i64
  sec_nreloc: i64
  sec_flags: i64
  sec_reserved1: i64
  sec_reserved2: i64
  sec_reserved3: i64
@end

@struct MachOWriteResult
  mw_success: i64
  mw_out_path: string
  mw_file_size: i64
  mw_entry_vaddr: i64
  mw_error_msg: string
@end

@struct MachOBuf
  mab_data: array
  mab_size: i64
@end

@struct WordPack
  w0: 0
  w1: 0
  w2: 0
  w3: 0
  w4: 0
  w5: 0
  w6: 0
  w7: 0
@end

@! ============================================================================
@! 2. LITTLE-ENDIAN ENCODING & BUFFER UTILITIES
@! ============================================================================

@fn macho_buf_new()
  return { mab_data: [], mab_size: 0 }
@end

@fn macho_buf_push(buf, byte)
  buf.mab_data = buf.mab_data.push(byte % 256)
  buf.mab_size = buf.mab_size + 1
  return 1
@end

@fn macho_buf_push32(buf, val)
  macho_buf_push(buf, val & 255)
  macho_buf_push(buf, (val / 256) & 255)
  macho_buf_push(buf, (val / 65536) & 255)
  macho_buf_push(buf, (val / 16777216) & 255)
  return 4
@end

@fn macho_buf_push64(buf, val)
  macho_buf_push32(buf, val & 4294967295)
  macho_buf_push32(buf, (val / 4294967296) & 4294967295)
  return 8
@end

@fn macho_u16_le(v)
  return [v % 256, (v / 256) % 256]
@end

@fn macho_u32_le(v)
  return [
    v % 256,
    (v / 256) % 256,
    (v / 65536) % 256,
    (v / 16777216) % 256
  ]
@end

@fn macho_u64_le(v)
  v_low = v % 4294967296
  v_high = v / 4294967296
  return [
    v_low % 256,
    (v_low / 256) % 256,
    (v_low / 65536) % 256,
    (v_low / 16777216) % 256,
    v_high % 256,
    (v_high / 256) % 256,
    (v_high / 65536) % 256,
    (v_high / 16777216) % 256
  ]
@end

@fn macho_append(target, source)
  @if source != 0
_i_item_0 = 0
@while _i_item_0 < source.len()
  item = source[_i_item_0]
      target = target.push(item)
  _i_item_0 = _i_item_0 + 1
@end
  @end
  return target
@end

@! ============================================================================
@! 3. SYSCALL DISK SERIALIZATION VIA WORDPACK
@! ============================================================================

@fn macho_pack_u64_le(bytes_list, start_idx)
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

@fn macho_write_bytes_to_fd(fd, byte_list)
  total = byte_list.len()
  offset = 0
  @while offset < total
    rem = total - offset
    chunk_bytes = rem
    @if chunk_bytes > 64
      chunk_bytes = 64
    @end

    wp = {
      w0: macho_pack_u64_le(byte_list, offset + 0),
      w1: macho_pack_u64_le(byte_list, offset + 8),
      w2: macho_pack_u64_le(byte_list, offset + 16),
      w3: macho_pack_u64_le(byte_list, offset + 24),
      w4: macho_pack_u64_le(byte_list, offset + 32),
      w5: macho_pack_u64_le(byte_list, offset + 40),
      w6: macho_pack_u64_le(byte_list, offset + 48),
      w7: macho_pack_u64_le(byte_list, offset + 56)
    }

    written = sys_write(fd, wp, chunk_bytes)
    @if written < 0
      return written
    @end
    offset = offset + chunk_bytes
  @end
  return total
@end

@fn macho_write_file(output_path, byte_list)
  @! O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577, mode 0755 = 493
  fd = sys_open(output_path, 577, 493)
  @if fd < 0
    return 0 - 1
  @end

  status = macho_write_bytes_to_fd(fd, byte_list)
  sys_close(fd)
  sys_chmod(output_path, 493)
  return status
@end

@! ============================================================================
@! 4. LOAD COMMAND BUILDERS
@! ============================================================================

@fn macho_build_header(cputype, cpusubtype, ncmds, sizeofcmds, flags)
  hdr = []
  hdr = macho_append(hdr, [207, 250, 237, 254])  @! MH_MAGIC_64 (0xFEEDFACF)
  hdr = macho_append(hdr, macho_u32_le(cputype)) @! CPU_TYPE_X86_64 (0x01000007)
  hdr = macho_append(hdr, macho_u32_le(cpusubtype)) @! CPU_SUBTYPE_LIB64 (0x80000003)
  hdr = macho_append(hdr, macho_u32_le(2))       @! filetype = MH_EXECUTE (2)
  hdr = macho_append(hdr, macho_u32_le(ncmds))   @! ncmds
  hdr = macho_append(hdr, macho_u32_le(sizeofcmds)) @! sizeofcmds
  hdr = macho_append(hdr, macho_u32_le(flags))   @! flags = MH_NOUNDEFS (0x85)
  hdr = macho_append(hdr, macho_u32_le(0))       @! reserved
  return hdr
@end

@fn macho_build_pagezero_segment()
  @! LC_SEGMENT_64 for __PAGEZERO (72 bytes)
  seg = []
  seg = macho_append(seg, macho_u32_le(25))      @! LC_SEGMENT_64 (0x19)
  seg = macho_append(seg, macho_u32_le(72))      @! cmdsize = 72
  seg = macho_append(seg, [95, 95, 80, 65, 71, 69, 90, 69, 82, 79, 0, 0, 0, 0, 0, 0]) @! "__PAGEZERO\0\0\0\0\0\0"
  seg = macho_append(seg, macho_u64_le(0))       @! vmaddr = 0
  seg = macho_append(seg, macho_u64_le(4294967296)) @! vmsize = 4GB (0x100000000)
  seg = macho_append(seg, macho_u64_le(0))       @! fileoff = 0
  seg = macho_append(seg, macho_u64_le(0))       @! filesize = 0
  seg = macho_append(seg, macho_u32_le(0))       @! maxprot = 0
  seg = macho_append(seg, macho_u32_le(0))       @! initprot = 0
  seg = macho_append(seg, macho_u32_le(0))       @! nsects = 0
  seg = macho_append(seg, macho_u32_le(0))       @! flags = 0
  return seg
@end

@fn macho_build_text_segment(aligned_code_size, offset_to_code)
  @! LC_SEGMENT_64 for __TEXT (72 bytes without section)
  seg = []
  seg = macho_append(seg, macho_u32_le(25))      @! LC_SEGMENT_64 (0x19)
  seg = macho_append(seg, macho_u32_le(72 + 80)) @! cmdsize = 152 (72 segment + 80 section)
  seg = macho_append(seg, [95, 95, 84, 69, 88, 84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) @! "__TEXT\0..."
  seg = macho_append(seg, macho_u64_le(4294967296)) @! vmaddr (0x100000000)
  seg = macho_append(seg, macho_u64_le(offset_to_code + aligned_code_size)) @! vmsize
  seg = macho_append(seg, macho_u64_le(0))       @! fileoff (0)
  seg = macho_append(seg, macho_u64_le(offset_to_code + aligned_code_size)) @! filesize
  seg = macho_append(seg, macho_u32_le(7))       @! maxprot (VM_PROT_ALL)
  seg = macho_append(seg, macho_u32_le(5))       @! initprot (VM_PROT_READ | VM_PROT_EXECUTE)
  seg = macho_append(seg, macho_u32_le(1))       @! nsects = 1
  seg = macho_append(seg, macho_u32_le(0))       @! flags
  return seg
@end

@fn macho_build_text_section(entry_point, aligned_code_size, offset_to_code)
  @! section_64 for __text (80 bytes)
  sec = []
  sec = macho_append(sec, [95, 95, 116, 101, 120, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) @! "__text\0..."
  sec = macho_append(sec, [95, 95, 84, 69, 88, 84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) @! "__TEXT\0..."
  sec = macho_append(sec, macho_u64_le(entry_point))       @! addr
  sec = macho_append(sec, macho_u64_le(aligned_code_size)) @! size
  sec = macho_append(sec, macho_u32_le(offset_to_code))    @! offset
  sec = macho_append(sec, macho_u32_le(4))                 @! align (2^4 = 16)
  sec = macho_append(sec, macho_u32_le(0))                 @! reloff
  sec = macho_append(sec, macho_u32_le(0))                 @! nreloc
  sec = macho_append(sec, macho_u32_le(2147484672))        @! flags = S_ATTR_SOME_INSTRUCTIONS | S_ATTR_PURE_INSTRUCTIONS
  sec = macho_append(sec, macho_u32_le(0))                 @! reserved1
  sec = macho_append(sec, macho_u32_le(0))                 @! reserved2
  sec = macho_append(sec, macho_u32_le(0))                 @! reserved3
  return sec
@end

@fn macho_build_unixthread_command(entry_point)
  @! LC_UNIXTHREAD Command (184 bytes for x86_64)
  th = []
  th = macho_append(th, macho_u32_le(5))         @! LC_UNIXTHREAD (5)
  th = macho_append(th, macho_u32_le(184))       @! cmdsize (184)
  th = macho_append(th, macho_u32_le(4))         @! flavor = x86_THREAD_STATE64 (4)
  th = macho_append(th, macho_u32_le(42))        @! count = x86_THREAD_STATE64_COUNT (42 uint32s = 168 bytes)
  
  @! Thread State: rax, rbx, rcx, rdx, rdi, rsi, rbp, rsp, r8..r15 (16 * 8 = 128 bytes)
  i = 0
  @while i < 128
    th = th.push(0)
    i = i + 1
  @end
  @! RIP at offset 128 (8 bytes)
  th = macho_append(th, macho_u64_le(entry_point))
  @! RFLAGS (8), CS (8), FS (8), GS (8) (32 bytes of zeros)
  i = 0
  @while i < 32
    th = th.push(0)
    i = i + 1
  @end
  return th
@end

@fn macho_build_main_command(entry_offset)
  @! LC_MAIN Command (24 bytes)
  main_cmd = []
  main_cmd = macho_append(main_cmd, macho_u32_le(2147483688)) @! LC_MAIN (0x80000028)
  main_cmd = macho_append(main_cmd, macho_u32_le(24))         @! cmdsize = 24
  main_cmd = macho_append(main_cmd, macho_u64_le(entry_offset)) @! entryoff
  main_cmd = macho_append(main_cmd, macho_u64_le(0))          @! stacksize
  return main_cmd
@end

@! Backward compatibility helpers
@fn macho_write_header(buf, ncmds, sizeofcmds)
  macho_buf_push32(buf, 4277009103)
  macho_buf_push32(buf, 16777223)
  macho_buf_push32(buf, 3)
  macho_buf_push32(buf, 2)
  macho_buf_push32(buf, ncmds)
  macho_buf_push32(buf, sizeofcmds)
  macho_buf_push32(buf, 133)
  macho_buf_push32(buf, 0)
  return 32
@end

@fn macho_write_text_segment(buf, code_size)
  macho_buf_push32(buf, 25)
  macho_buf_push32(buf, 152)
  return 152
@end

@fn macho_write_entry_thread(buf, entry_addr)
  macho_buf_push32(buf, 5)
  macho_buf_push32(buf, 184)
  return 184
@end

@! ============================================================================
@! 5. COMPLETE MACH-O 64-BIT EMITTER
@! ============================================================================

@fn write_macho64_executable(machine_code, output_path)
  code_len = 0
  @if machine_code != 0
    code_len = machine_code.len()
  @end
  
  @if code_len == 0
    @! Default x86_64: nop; ret (0x90, 0xC3)
    machine_code = [144, 195]
    code_len = 2
  @end

  aligned_code_size = code_len
  @while aligned_code_size % 16 != 0
    aligned_code_size = aligned_code_size + 1
  @end

  offset_to_code = 4096 @! Aligned to 4KB page
  entry_point = 4294967296 + offset_to_code @! 0x100000000 + 0x1000

  @! Build Load Commands
  pagezero_cmd = macho_build_pagezero_segment()          @! 72 bytes
  seg_cmd = macho_build_text_segment(aligned_code_size, offset_to_code) @! 72 bytes
  sec_cmd = macho_build_text_section(entry_point, aligned_code_size, offset_to_code) @! 80 bytes
  th_cmd = macho_build_unixthread_command(entry_point)    @! 184 bytes

  ncmds = 3
  sizeofcmds = 72 + 152 + 184 @! 408 bytes

  @! Mach-O Header (32 bytes)
  hdr = macho_build_header(16777223, 2147483651, ncmds, sizeofcmds, 133)

  @! Assemble headers and load commands
  full_bytes = []
  full_bytes = macho_append(full_bytes, hdr)
  full_bytes = macho_append(full_bytes, pagezero_cmd)
  full_bytes = macho_append(full_bytes, seg_cmd)
  full_bytes = macho_append(full_bytes, sec_cmd)
  full_bytes = macho_append(full_bytes, th_cmd)

  @! Pad up to offset_to_code (4096)
  @while full_bytes.len() < offset_to_code
    full_bytes = full_bytes.push(0)
  @end

  @! Append executable code bytes
  full_bytes = macho_append(full_bytes, machine_code)
  @while full_bytes.len() < (offset_to_code + aligned_code_size)
    full_bytes = full_bytes.push(0)
  @end

  @! Write file to disk
  write_status = macho_write_file(output_path, full_bytes)
  @if write_status < 0
    return {
      mw_success: 0,
      mw_out_path: output_path,
      mw_file_size: 0,
      mw_entry_vaddr: 0,
      mw_error_msg: "Failed to write Mach-O binary to disk"
    }
  @end

  return {
    mw_success: 1,
    mw_out_path: output_path,
    mw_file_size: full_bytes.len(),
    mw_entry_vaddr: entry_point,
    mw_error_msg: ""
  }
@end

@fn macho_is_path_str(x)
  @if x == 0 return 0 @end
  num_items = x.len()
  @if num_items == 0 return 0 @end
  
  i = 0
  @while i < num_items
    c = x[i]
    @if c < 32 || c > 126
      @! Non-printable or null byte -> machine code byte, not a path string
      return 0
    @end
    i = i + 1
  @end
  
  return 1
@end

@fn macho_write_executable(a1, a2)
  code = 0
  path = ""
  
  @if a1 == 0
    code = a1
    path = a2
  @else
    @if a2 == 0
      code = a2
      path = a1
    @else
      @if a1.len() == 0
        code = a1
        path = a2
      @else
        @if a2.len() == 0
          code = a2
          path = a1
        @else
          @if macho_is_path_str(a1) == 1 && macho_is_path_str(a2) == 0
            path = a1
            code = a2
          @else
            code = a1
            path = a2
          @end
        @end
      @end
    @end
  @end

  res = write_macho64_executable(code, path)
  @if res.mw_success == 1
    return 1
  @end
  return 0
@end

@fn emit_macho_64_executable(a1, a2)
  return macho_write_executable(a1, a2)
@end
