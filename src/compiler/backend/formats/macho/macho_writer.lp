// ============================================================================
// LIPI SOVEREIGN COMPILER — MACH-O 64-BIT BINARY EXECUTABLE WRITER
// Module: src/compiler/backend/formats/macho/macho_writer.lp
// Standard: Apple macOS Mach-O 64 (x86_64 and ARM64 / Apple Silicon)
// Permissions: Mode 0755
// Zero External Dependencies — 100% Pure Lipi First 1.0.0
// ============================================================================

import "utso/syscalls"
import "utso/collections"
import "utso/string"
import "utso/crypto/sha256"

import "src/compiler/backend/formats/macho/load_commands.lp"

// WHY: Mach-O binaries use an integrated segment architecture where the
// __TEXT segment maps both the file headers (mach_header_64, load commands)
// and executable code (__text section) starting at virtual address 0x100000000.
// This writer computes the exact header sizing, pads sections to page alignment,
// and outputs clean freestanding native Mach-O 64 executables.

// ============================================================================
// 1. DATA STRUCTURES
// ============================================================================

@struct MachOWriteResult
  mw_success: i64      // 1 on success, 0 on failure
  mw_out_path: string  // Output file path
  mw_file_size: i64    // Total byte count written to disk
  mw_entry_vaddr: i64  // Absolute virtual memory entry address
  mw_error_msg: string // Error description if any
  mw_bytes: array      // Serialized binary bytes
@end

// ============================================================================
// 2. BUFFER HELPERS
// ============================================================================

@fn macho_concat(target, source)
  i = 0
  n = source.len()
  @while i < n
    target = target.push(source[i])
    i = i + 1
  @end
  return target
@end

@fn macho_pad_to(bytes_list, target_alignment)
  @if target_alignment <= 1 return bytes_list @end
  rem = bytes_list.len() % target_alignment
  @if rem != 0
    pad_needed = target_alignment - rem
    k = 0
    @while k < pad_needed
      bytes_list = bytes_list.push(0)
      k = k + 1
    @end
  @end
  return bytes_list
@end

// ============================================================================
// 3. LOW-LEVEL DIRECT SYSCALL BINARY DISK SERIALIZER
// ============================================================================

@fn macho_write_to_disk(output_path, byte_list)
  // WHY: Writes raw binary bytes directly to disk via Linux/Darwin compatible syscalls.
  // Sets file access mode to 0755 (493 decimal) for executable execution.
  total = byte_list.len()
  @if total <= 0 return 0 - 1 @end
  @if output_path == "" return total @end

  sys_unlink(output_path)
  fd = sys_open(output_path, 577, 493) // O_WRONLY | O_CREAT | O_TRUNC = 577, 0755
  @if fd < 0
    return 0 - 1
  @end

  buf = sys_mmap(0, total + 16, 3, 34, 0 - 1, 0)
  @if buf <= 0
    sys_close(fd)
    return 0 - 2
  @end

  i = 0
  @while i < total
    sys_poke8(buf + i, byte_list[i])
    i = i + 1
  @end

  written = sys_write(fd, buf, total)
  sys_close(fd)

  sys_chmod(output_path, 493) // 0755

  return written
@end

// ============================================================================
// 4. MACH-O 64 EXECUTABLE EMITTER
// ============================================================================

@fn macho_darwin_sys_nr(linux_nr)
  // WHY: Translates Linux x86-64 syscall numbers to Darwin BSD class-2 syscall low bytes (0x020000xx).
  // Returns -1 if not a mapped syscall.
  @if linux_nr == 0  return 3   @end // SYS_read
  @if linux_nr == 1  return 4   @end // SYS_write
  @if linux_nr == 2  return 5   @end // SYS_open
  @if linux_nr == 3  return 6   @end // SYS_close
  @if linux_nr == 8  return 199 @end // SYS_lseek (0xC7)
  @if linux_nr == 9  return 197 @end // SYS_mmap (0xC5)
  @if linux_nr == 11 return 73  @end // SYS_munmap (0x49)
  @if linux_nr == 21 return 33  @end // SYS_access (0x21)
  @if linux_nr == 60 return 1   @end // SYS_exit
  @if linux_nr == 90 return 15  @end // SYS_chmod (0x0F)
  return 0 - 1
@end

@fn macho_patch_darwin_code_full(code_bytes, data_vmaddr, rodata_len)
  // WHY: Relocates ALL Linux ELF64 .rodata (1073742128 + code_len + off) and W^X RW runtime
  // globals (g_argc, g_argv, _heap_base, _heap_ptr, _slab_buckets) into Mach-O __DATA segment
  // addresses, translates Linux MAP_ANON (0x22 -> 0x1002), and lowers ALL Linux x86_64 syscalls
  // into Darwin BSD class-2 syscalls (0x020000xx) in-place without shifting instruction offsets.
  code_len = code_bytes.len()
  @if code_len < 7
    return code_bytes
  @end
  linux_rodata_base = 1073742128 + code_len
  linux_rodata_limit = linux_rodata_base + rodata_len + 64
  text_ro_end = 304 + code_len + rodata_len
  rem_page = text_ro_end % 4096
  pad_bytes = 0
  @if rem_page != 0
    pad_bytes = 4096 - rem_page
  @end
  linux_rw_base = 1073741824 + text_ro_end + pad_bytes
  linux_rw_end = linux_rw_base + 128

  out = list()
  i = 0
  @while i < code_len
    b0 = code_bytes[i]
    // 1. 15-byte clock_ms Linux SYS_clock_gettime (228) -> Darwin SYS_gettimeofday (0x02000074)
    @if i + 15 <= code_len && b0 == 72 && code_bytes[i + 1] == 199 && code_bytes[i + 2] == 192 && code_bytes[i + 3] == 228 && code_bytes[i + 4] == 0 && code_bytes[i + 13] == 15 && code_bytes[i + 14] == 5
      // mov rdi, rsp (3B); xor rsi, rsi (3B); mov eax, 0x02000074 (5B); syscall (2B); nop; nop (2B)
      push(out, 72) push(out, 137) push(out, 231)
      push(out, 72) push(out, 49) push(out, 246)
      push(out, 184) push(out, 116) push(out, 0) push(out, 0) push(out, 2)
      push(out, 15) push(out, 5)
      push(out, 144) push(out, 144)
      i = i + 15
      continue
    @end
    // 2. 10-byte movabs r64, imm64 -> relocate .rodata AND W^X RW runtime globals into __DATA
    @if i + 10 <= code_len && b0 == 72
      b1 = code_bytes[i + 1]
      @if (b1 >= 184 && b1 <= 191) && code_bytes[i + 6] == 0 && code_bytes[i + 7] == 0 && code_bytes[i + 8] == 0 && code_bytes[i + 9] == 0
        imm32 = code_bytes[i + 2] + (code_bytes[i + 3] * 256) + (code_bytes[i + 4] * 65536) + (code_bytes[i + 5] * 16777216)
        new_addr = 0
        @if imm32 >= linux_rodata_base && imm32 < linux_rodata_limit
          new_addr = data_vmaddr + (imm32 - linux_rodata_base)
        @elif imm32 >= linux_rw_base && imm32 <= linux_rw_end
          new_addr = data_vmaddr + rodata_len + (imm32 - linux_rw_base)
        @end
        @if new_addr > 0
          low32 = new_addr % 4294967296
          high32 = new_addr / 4294967296
          push(out, 72)
          push(out, b1)
          push(out, low32 % 256)
          push(out, (low32 / 256) % 256)
          push(out, (low32 / 65536) % 256)
          push(out, (low32 / 16777216) % 256)
          push(out, high32 % 256)
          push(out, (high32 / 256) % 256)
          push(out, (high32 / 65536) % 256)
          push(out, (high32 / 16777216) % 256)
          i = i + 10
          continue
        @end
      @end
    @end
    // 3. 6-byte Linux MAP_PRIVATE|MAP_ANON (mov r10d, 34) -> Darwin MAP_PRIVATE|MAP_ANON (mov r10d, 0x1002)
    @if i + 6 <= code_len && b0 == 65 && code_bytes[i + 1] == 186 && code_bytes[i + 2] == 34 && code_bytes[i + 3] == 0 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 0
      push(out, 65) push(out, 186) push(out, 2) push(out, 16) push(out, 0) push(out, 0)
      i = i + 6
      continue
    @end
    // 4. 9-byte mov rax, imm32; syscall (48 C7 C0 <nr> 00 00 00 0F 05) -> Darwin 0x020000xx
    @if i + 9 <= code_len && b0 == 72 && code_bytes[i + 1] == 199 && code_bytes[i + 2] == 192 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 0 && code_bytes[i + 6] == 0 && code_bytes[i + 7] == 15 && code_bytes[i + 8] == 5
      dnr9 = macho_darwin_sys_nr(code_bytes[i + 3])
      @if dnr9 >= 0
        push(out, 72) push(out, 199) push(out, 192)
        push(out, dnr9) push(out, 0) push(out, 0) push(out, 2)
        push(out, 15) push(out, 5)
        i = i + 9
        continue
      @end
    @end
    // 5. 18-byte print_float & 27-byte inline say: mov eax, 1; mov edi, 1 ... syscall -> Darwin SYS_write (0x02000004)
    @if i + 10 <= code_len && b0 == 184 && code_bytes[i + 1] == 1 && code_bytes[i + 2] == 0 && code_bytes[i + 3] == 0 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 191 && code_bytes[i + 6] == 1 && code_bytes[i + 7] == 0 && code_bytes[i + 8] == 0 && code_bytes[i + 9] == 0
      push(out, 184) push(out, 4) push(out, 0) push(out, 0) push(out, 2)
      i = i + 5
      continue
    @end
    // 6. 7-byte mov eax, <nr>; syscall (B8 <nr> 00 00 00 0F 05) -> Darwin BSD class-2 syscall
    @if i + 7 <= code_len && b0 == 184 && code_bytes[i + 2] == 0 && code_bytes[i + 3] == 0 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 15 && code_bytes[i + 6] == 5
      dnr7 = macho_darwin_sys_nr(code_bytes[i + 1])
      @if dnr7 >= 0
        push(out, 184) push(out, dnr7) push(out, 0) push(out, 0) push(out, 2)
        push(out, 15) push(out, 5)
        i = i + 7
        continue
      @end
    @end
    push(out, b0)
    i = i + 1
  @end
  return out
@end

@fn macho_patch_darwin_code(code_bytes, data_vmaddr)
  return macho_patch_darwin_code_full(code_bytes, data_vmaddr, 0)
@end

@fn macho_build_adhoc_codesig(binary_prefix, code_limit)
  // WHY: Generates a real Apple CS_SuperBlob (0xFADE0CC0) + SHA-256 CS_CodeDirectory (0xFADE0C02)
  // covering every 4KB page of binary_prefix[0..code_limit) so Apple Silicon / macOS validates ad-hoc signing.
  n_slots = (code_limit + 4095) / 4096
  @if n_slots < 1 n_slots = 1 @end
  cd_len = 44 + 9 + (n_slots * 32)
  total_len = 20 + cd_len

  blob = []
  blob = macho_concat(blob, macho_pack_u32_be(4208856256))
  blob = macho_concat(blob, macho_pack_u32_be(total_len))
  blob = macho_concat(blob, macho_pack_u32_be(1))
  blob = macho_concat(blob, macho_pack_u32_be(0))
  blob = macho_concat(blob, macho_pack_u32_be(20))

  blob = macho_concat(blob, macho_pack_u32_be(4208856066))
  blob = macho_concat(blob, macho_pack_u32_be(cd_len))
  blob = macho_concat(blob, macho_pack_u32_be(132096))
  blob = macho_concat(blob, macho_pack_u32_be(131074))
  blob = macho_concat(blob, macho_pack_u32_be(53))
  blob = macho_concat(blob, macho_pack_u32_be(44))
  blob = macho_concat(blob, macho_pack_u32_be(0))
  blob = macho_concat(blob, macho_pack_u32_be(n_slots))
  blob = macho_concat(blob, macho_pack_u32_be(code_limit))
  blob = blob.push(32)
  blob = blob.push(2)
  blob = blob.push(0)
  blob = blob.push(12)
  blob = macho_concat(blob, macho_pack_u32_be(0))

  ident_bytes = [108, 105, 112, 105, 95, 98, 105, 110, 0]
  blob = macho_concat(blob, ident_bytes)

  si = 0
  @while si < n_slots
    p_start = si * 4096
    p_end = p_start + 4096
    @if p_end > code_limit
      p_end = code_limit
    @end
    chunk = []
    bi = p_start
    @while bi < p_end
      chunk = chunk.push(binary_prefix[bi])
      bi = bi + 1
    @end
    digest = sha256_hash_bytes(chunk)
    blob = macho_concat(blob, digest)
    si = si + 1
  @end

  return blob
@end

@fn macho_emit_executable(code_bytes, data_bytes, bss_size, cputype, output_path)
  // WHY: Comprehensive Mach-O 64 binary generator.
  // Supported architectures:
  //   - CPU_TYPE_X86_64 (16777223)
  //   - CPU_TYPE_ARM64  (16777228)
  //
  // Memory Layout:
  // 1. [0x000000000 .. 0x0FFFFFFFF]: __PAGEZERO (4GB protected zone)
  // 2. [0x100000000 .. text_end]:   __TEXT Segment (Header + Cmds + __text)
  // 3. [data_start  .. data_end]:   __DATA Segment (__data + __bss)
  // 4. [linkedit_start ..]:         __LINKEDIT (LC_CODE_SIGNATURE ad-hoc SHA-256)

  page_size = 4096

  // 1. Calculate Load Commands Size
  // Header: 32 bytes
  // Cmd 1: __PAGEZERO segment command = 72 bytes
  // Cmd 2: __TEXT segment command with 1 section (__text) = 72 + 80 = 152 bytes
  // Cmd 3: LC_LOAD_DYLINKER command (/usr/lib/dyld) = 32 bytes
  // Cmd 4: LC_LOAD_DYLIB command (/usr/lib/libSystem.B.dylib) = 56 bytes
  // Cmd 5: LC_MAIN command = 24 bytes
  // Cmd 6: __DATA segment command with 2 sections (__data, __bss) = 72 + 80 + 80 = 232 bytes
  // Cmd 7: __LINKEDIT segment command = 72 bytes; Cmd 8: LC_CODE_SIGNATURE = 16 bytes

  // Always emit __DATA with rodata + 128B RW runtime globals + __LINKEDIT (LC_CODE_SIGNATURE)
  ro_orig_len = data_bytes.len()
  full_data_bytes = []
  full_data_bytes = macho_concat(full_data_bytes, data_bytes)
  gi = 0
  @while gi < 128
    full_data_bytes = full_data_bytes.push(0)
    gi = gi + 1
  @end
  has_data = 1

  ncmds = 8
  sizeofcmds = 72 + 152 + 32 + 56 + 24 + 232 + 72 + 16 // + __LINKEDIT + LC_CODE_SIGNATURE = 656 bytes

  header_and_cmds_size = 32 + sizeofcmds

  // Align __text section offset to 16 bytes
  text_offset = header_and_cmds_size
  rem16 = text_offset % 16
  @if rem16 != 0
    text_offset = text_offset + (16 - rem16)
  @end

  text_size = code_bytes.len()
  text_vmaddr = 4294967296 + text_offset // 0x100000000 + text_offset
  entry_vaddr = text_vmaddr

  // Size of __TEXT in file and memory (aligned to 4KB page)
  text_file_end = text_offset + text_size
  text_vmsize = text_file_end
  rem_page = text_vmsize % page_size
  @if rem_page != 0
    text_vmsize = text_vmsize + (page_size - rem_page)
  @end

  // 2. Configure __DATA Segment (rodata + 128B RW runtime globals + bss)
  data_offset = text_vmsize
  data_size = full_data_bytes.len()
  data_vmaddr = 4294967296 + text_vmsize
  data_vmsize = data_size + bss_size
  rem_dpage = data_vmsize % page_size
  @if rem_dpage != 0
    data_vmsize = data_vmsize + (page_size - rem_dpage)
  @end
  data_file_aligned = data_size
  rem_dfp = data_file_aligned % page_size
  @if rem_dfp != 0
    data_file_aligned = data_file_aligned + (page_size - rem_dfp)
  @end

  // 2b. Configure __LINKEDIT + LC_CODE_SIGNATURE ad-hoc SHA-256 CodeDirectory layout
  linkedit_offset = data_offset + data_file_aligned
  linkedit_vmaddr = data_vmaddr + data_vmsize
  n_cs_slots = (linkedit_offset + 4095) / 4096
  @if n_cs_slots < 1 n_cs_slots = 1 @end
  codesig_size = 20 + 44 + 9 + (n_cs_slots * 32)
  linkedit_vmsize = codesig_size
  rem_lpage = linkedit_vmsize % page_size
  @if rem_lpage != 0
    linkedit_vmsize = linkedit_vmsize + (page_size - rem_lpage)
  @end

  // Relocate x86_64 Linux .rodata, RW globals, and ALL Linux syscalls to Darwin BSD Mach-O ABI
  @if cputype == 16777223
    code_bytes = macho_patch_darwin_code_full(code_bytes, data_vmaddr, ro_orig_len)
  @end

  // 3. Build Mach-O Header
  m_hdr = macho_header_create(cputype, ncmds, sizeofcmds)
  hdr_bytes = macho_header_serialize(m_hdr) // 32 bytes

  // 4. Build Load Commands
  // Cmd 1: __PAGEZERO
  seg_pagezero = macho_segment_pagezero()
  cmd_pagezero_bytes = macho_segment_header_serialize(seg_pagezero) // 72 bytes

  // Cmd 2: __TEXT
  seg_text = macho_segment_text(text_vmsize, text_file_end, 1)
  cmd_text_header_bytes = macho_segment_header_serialize(seg_text) // 72 bytes
  sec_text = macho_section_text(text_vmaddr, text_size, text_offset)
  sec_text_bytes = macho_section_serialize(sec_text) // 80 bytes

  // Cmd 3: LC_LOAD_DYLINKER (/usr/lib/dyld)
  cmd_dylinker = macho_lc_dylinker_create("/usr/lib/dyld")
  cmd_dylinker_bytes = macho_lc_dylinker_serialize(cmd_dylinker) // 32 bytes

  // Cmd 4: LC_LOAD_DYLIB (/usr/lib/libSystem.B.dylib)
  cmd_dylib = macho_lc_dylib_create("/usr/lib/libSystem.B.dylib")
  cmd_dylib_bytes = macho_lc_dylib_serialize(cmd_dylib) // 56 bytes

  // Cmd 5: LC_MAIN
  lc_main = macho_lc_main_create(text_offset, 0)
  lc_main_bytes = macho_lc_main_serialize(lc_main) // 24 bytes

  // Cmd 6: __DATA
  cmd_data_bytes = []
  @if has_data == 1
    seg_data = macho_segment_data(data_vmaddr, data_vmsize, data_offset, data_size, 2)
    cmd_data_hdr = macho_segment_header_serialize(seg_data) // 72 bytes
    sec_data = macho_section_data(data_vmaddr, data_size, data_offset)
    sec_data_bytes = macho_section_serialize(sec_data) // 80 bytes
    sec_bss = macho_section_bss(data_vmaddr + data_size, bss_size)
    sec_bss_bytes = macho_section_serialize(sec_bss) // 80 bytes

    cmd_data_bytes = macho_concat(cmd_data_bytes, cmd_data_hdr)
    cmd_data_bytes = macho_concat(cmd_data_bytes, sec_data_bytes)
    cmd_data_bytes = macho_concat(cmd_data_bytes, sec_bss_bytes)
  @end

  // Cmd 7: __LINKEDIT & Cmd 8: LC_CODE_SIGNATURE
  seg_linkedit = macho_segment_linkedit(linkedit_vmaddr, linkedit_vmsize, linkedit_offset, codesig_size)
  cmd_linkedit_bytes = macho_segment_header_serialize(seg_linkedit) // 72 bytes
  cmd_codesig_bytes = macho_lc_code_signature_serialize(linkedit_offset, codesig_size) // 16 bytes

  // 5. Assemble Binary Stream
  binary = []
  binary = macho_concat(binary, hdr_bytes)
  binary = macho_concat(binary, cmd_pagezero_bytes)
  binary = macho_concat(binary, cmd_text_header_bytes)
  binary = macho_concat(binary, sec_text_bytes)
  binary = macho_concat(binary, cmd_dylinker_bytes)
  binary = macho_concat(binary, cmd_dylib_bytes)
  binary = macho_concat(binary, lc_main_bytes)
  @if has_data == 1
    binary = macho_concat(binary, cmd_data_bytes)
  @end
  binary = macho_concat(binary, cmd_linkedit_bytes)
  binary = macho_concat(binary, cmd_codesig_bytes)

  // Pad up to text_offset
  @while binary.len() < text_offset
    binary = binary.push(0)
  @end

  // Append __text machine code
  binary = macho_concat(binary, code_bytes)

  // Append __DATA if present
  @if has_data == 1
    // Pad to data_offset (4KB page boundary)
    @while binary.len() < data_offset
      binary = binary.push(0)
    @end
    binary = macho_concat(binary, full_data_bytes)
  @end

  // Pad up to linkedit_offset and append SHA-256 ad-hoc SuperBlob CodeDirectory
  @while binary.len() < linkedit_offset
    binary = binary.push(0)
  @end
  codesig_blob = macho_build_adhoc_codesig(binary, linkedit_offset)
  binary = macho_concat(binary, codesig_blob)

  // 6. Write to disk
  written = macho_write_to_disk(output_path, binary)
  res = MachOWriteResult()
  @if written < 0
    res.mw_success = 0
    res.mw_out_path = output_path
    res.mw_file_size = 0
    res.mw_entry_vaddr = entry_vaddr
    res.mw_error_msg = "Failed to write Mach-O 64 binary to filesystem"
    res.mw_bytes = binary
    return res
  @end

  res.mw_success = 1
  res.mw_out_path = output_path
  res.mw_file_size = binary.len()
  res.mw_entry_vaddr = entry_vaddr
  res.mw_error_msg = ""
  res.mw_bytes = binary
  return res
@end

@fn emit_macho_64_executable(machine_code_bytes, output_path)
  // WHY: Compatibility bridge for omni-target executable synthesis
  empty_data = []
  res = macho_emit_executable(machine_code_bytes, empty_data, 0, CPU_TYPE_X86_64(), output_path)
  return res.mw_success
@end
