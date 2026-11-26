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
  // WHY: Translates Linux x86-64 syscall numbers to Darwin BSD class-2 syscall numbers (0x02000000 | nr).
  // Returns -1 if not a mapped syscall.
  @if linux_nr == 0  return 3   @end // SYS_read
  @if linux_nr == 1  return 4   @end // SYS_write
  @if linux_nr == 2  return 5   @end // SYS_open
  @if linux_nr == 3  return 6   @end // SYS_close
  @if linux_nr == 8  return 199 @end // SYS_lseek (0xC7)
  @if linux_nr == 9  return 197 @end // SYS_mmap (0xC5)
  @if linux_nr == 10 return 74  @end // SYS_mprotect (0x4A)
  @if linux_nr == 11 return 73  @end // SYS_munmap (0x49)
  @if linux_nr == 21 return 33  @end // SYS_access (0x21)
  @if linux_nr == 60  return 1   @end // SYS_exit
  @if linux_nr == 231 return 1   @end // SYS_exit_group -> Darwin BSD SYS_exit
  @if linux_nr == 90  return 15  @end // SYS_chmod (0x0F)
  return 0 - 1
@end

@fn macho_patch_darwin_code_pie_ex(code_bytes, text_vmaddr, data_vmaddr, rodata_len, rw_data_off, bss_size)
  // WHY: Relocates ALL Linux ELF64 .rodata (1073742128 + code_len + off) and 16B-aligned W^X RW runtime
  // globals + @bss into Mach-O __DATA using TRUE position-independent RIP-relative `lea r64, [rip+disp32] + 3B nop`
  // when text_vmaddr > 0 (honoring MH_PIE under macOS ASLR!), translates Linux MAP_ANON (0x22 -> 0x1002),
  // translates Linux x86_64 syscalls into Darwin BSD class-2 syscalls (0x020000xx), and traps ALL unmapped
  // Linux syscalls (including >=256 like epoll_create1/epoll_pwait and raw `syscall(...)` intrinsics)
  // cleanly with -ENOSYS (-78) so zero raw Linux syscalls ever execute on macOS!
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
  linux_rw_end = linux_rw_base + 4096 + bss_size

  out = list()
  i = 0
  @while i < code_len
    b0 = code_bytes[i]
    // 1. 15-byte clock_ms Linux SYS_clock_gettime (228) -> Darwin SYS_gettimeofday (0x02000074)
    @if i + 15 <= code_len && b0 == 72 && code_bytes[i + 1] == 199 && code_bytes[i + 2] == 192 && code_bytes[i + 3] == 228 && code_bytes[i + 4] == 0 && code_bytes[i + 13] == 15 && code_bytes[i + 14] == 5
      push(out, 72) push(out, 137) push(out, 231)
      push(out, 72) push(out, 49) push(out, 246)
      push(out, 184) push(out, 116) push(out, 0) push(out, 0) push(out, 2)
      push(out, 15) push(out, 5)
      push(out, 144) push(out, 144)
      i = i + 15
      continue
    @end
    // 2. 10-byte movabs r64, imm64 -> PIE RIP-relative `lea r64, [rip+disp32] + 3B nop` (exact 10B!)
    @if i + 10 <= code_len && (b0 == 72 || b0 == 73)
      b1 = code_bytes[i + 1]
      @if (b1 >= 184 && b1 <= 191) && code_bytes[i + 6] == 0 && code_bytes[i + 7] == 0 && code_bytes[i + 8] == 0 && code_bytes[i + 9] == 0
        imm32 = code_bytes[i + 2] + (code_bytes[i + 3] * 256) + (code_bytes[i + 4] * 65536) + (code_bytes[i + 5] * 16777216)
        new_addr = 0
        @if imm32 >= linux_rodata_base && imm32 < linux_rodata_limit
          new_addr = data_vmaddr + (imm32 - linux_rodata_base)
        @elif imm32 >= linux_rw_base && imm32 <= linux_rw_end
          new_addr = data_vmaddr + rw_data_off + (imm32 - linux_rw_base)
        @end
        @if new_addr > 0
          @if text_vmaddr > 0
            // True PIE: lea r64, [rip + disp32] (7B) + 3B nop (0F 1F 00) = 10B exact!
            reg_id = b1 - 184
            rex_lea = 72
            @if b0 == 73
              rex_lea = 76 // REX.W | REX.R for r8..r15
            @end
            modrm_lea = (reg_id * 8) + 5
            disp = new_addr - (text_vmaddr + i + 7)
            dp = macho_pack_u32_le(disp)
            push(out, rex_lea) push(out, 141) push(out, modrm_lea)
            push(out, dp[0]) push(out, dp[1]) push(out, dp[2]) push(out, dp[3])
            push(out, 15) push(out, 31) push(out, 0)
          @else
            low32 = new_addr % 4294967296
            high32 = new_addr / 4294967296
            push(out, b0) push(out, b1)
            push(out, low32 % 256) push(out, (low32 / 256) % 256) push(out, (low32 / 65536) % 256) push(out, (low32 / 16777216) % 256)
            push(out, high32 % 256) push(out, (high32 / 256) % 256) push(out, (high32 / 65536) % 256) push(out, (high32 / 16777216) % 256)
          @end
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
    // 3a. Scoped Linux open(2) flag translation (0x241 -> Darwin 0x601, 0x441 -> Darwin 0x209)
    //     ONLY when directly followed by mode load + SYS_open (2) + syscall (zero user constant clobbering!).
    //     Pattern 1: _lipi_file_write_mem  [mov esi, 577; mov edx, 420; mov eax, 2; syscall] (17B)
    @if i + 17 <= code_len && b0 == 190 && code_bytes[i + 1] == 65 && code_bytes[i + 2] == 2 && code_bytes[i + 3] == 0 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 186 && code_bytes[i + 10] == 184 && code_bytes[i + 11] == 2 && code_bytes[i + 12] == 0 && code_bytes[i + 13] == 0 && code_bytes[i + 14] == 0 && code_bytes[i + 15] == 15 && code_bytes[i + 16] == 5
      push(out, 190) push(out, 1) push(out, 6) push(out, 0) push(out, 0)
      push(out, code_bytes[i + 5]) push(out, code_bytes[i + 6]) push(out, code_bytes[i + 7]) push(out, code_bytes[i + 8]) push(out, code_bytes[i + 9])
      push(out, 184) push(out, 5) push(out, 0) push(out, 0) push(out, 2)
      push(out, 15) push(out, 5)
      i = i + 17
      continue
    @end
    //     Pattern 2: _lipi_file_append_mem [mov esi, 1089; mov edx, 420; mov eax, 2; syscall] (17B)
    @if i + 17 <= code_len && b0 == 190 && code_bytes[i + 1] == 65 && code_bytes[i + 2] == 4 && code_bytes[i + 3] == 0 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 186 && code_bytes[i + 10] == 184 && code_bytes[i + 11] == 2 && code_bytes[i + 12] == 0 && code_bytes[i + 13] == 0 && code_bytes[i + 14] == 0 && code_bytes[i + 15] == 15 && code_bytes[i + 16] == 5
      push(out, 190) push(out, 9) push(out, 2) push(out, 0) push(out, 0)
      push(out, code_bytes[i + 5]) push(out, code_bytes[i + 6]) push(out, code_bytes[i + 7]) push(out, code_bytes[i + 8]) push(out, code_bytes[i + 9])
      push(out, 184) push(out, 5) push(out, 0) push(out, 0) push(out, 2)
      push(out, 15) push(out, 5)
      i = i + 17
      continue
    @end
    //     Pattern 3: _lipi_file_write_bytes [mov rsi, 577; mov rdx, 493; mov rax, 2; syscall] (23B)
    @if i + 23 <= code_len && b0 == 72 && code_bytes[i + 1] == 199 && code_bytes[i + 2] == 198 && code_bytes[i + 3] == 65 && code_bytes[i + 4] == 2 && code_bytes[i + 5] == 0 && code_bytes[i + 6] == 0 && code_bytes[i + 7] == 72 && code_bytes[i + 8] == 199 && code_bytes[i + 9] == 194 && code_bytes[i + 14] == 72 && code_bytes[i + 15] == 199 && code_bytes[i + 16] == 192 && code_bytes[i + 17] == 2 && code_bytes[i + 18] == 0 && code_bytes[i + 19] == 0 && code_bytes[i + 20] == 0 && code_bytes[i + 21] == 15 && code_bytes[i + 22] == 5
      push(out, 72) push(out, 199) push(out, 198) push(out, 1) push(out, 6) push(out, 0) push(out, 0)
      push(out, code_bytes[i + 7]) push(out, code_bytes[i + 8]) push(out, code_bytes[i + 9]) push(out, code_bytes[i + 10]) push(out, code_bytes[i + 11]) push(out, code_bytes[i + 12]) push(out, code_bytes[i + 13])
      push(out, 72) push(out, 199) push(out, 192) push(out, 5) push(out, 0) push(out, 0) push(out, 2)
      push(out, 15) push(out, 5)
      i = i + 23
      continue
    @end
    // 3b. Raw Linux syscall(...) intrinsics (7/6/5/4/3/2/1-arg stack-popped sequences): return -ENOSYS (-78) cleanly!
    @if i + 12 <= code_len && b0 == 65 && code_bytes[i + 1] == 89 && code_bytes[i + 2] == 65 && code_bytes[i + 3] == 88 && code_bytes[i + 4] == 65 && code_bytes[i + 5] == 90 && code_bytes[i + 6] == 90 && code_bytes[i + 7] == 94 && code_bytes[i + 8] == 95 && code_bytes[i + 9] == 88 && code_bytes[i + 10] == 15 && code_bytes[i + 11] == 5
      // add rsp, 56 (48 83 C4 38); push -78 (6A B2); pop rax (58); nop*5
      push(out, 72) push(out, 131) push(out, 196) push(out, 56)
      push(out, 106) push(out, 178) push(out, 88)
      push(out, 144) push(out, 144) push(out, 144) push(out, 144) push(out, 144)
      i = i + 12
      continue
    @end
    @if i + 10 <= code_len && b0 == 65 && code_bytes[i + 1] == 88 && code_bytes[i + 2] == 65 && code_bytes[i + 3] == 90 && code_bytes[i + 4] == 90 && code_bytes[i + 5] == 94 && code_bytes[i + 6] == 95 && code_bytes[i + 7] == 88 && code_bytes[i + 8] == 15 && code_bytes[i + 9] == 5
      // add rsp, 48 (48 83 C4 30); push -78 (6A B2); pop rax (58); nop*3
      push(out, 72) push(out, 131) push(out, 196) push(out, 48)
      push(out, 106) push(out, 178) push(out, 88)
      push(out, 144) push(out, 144) push(out, 144)
      i = i + 10
      continue
    @end
    @if i + 8 <= code_len && b0 == 65 && code_bytes[i + 1] == 90 && code_bytes[i + 2] == 90 && code_bytes[i + 3] == 94 && code_bytes[i + 4] == 95 && code_bytes[i + 5] == 88 && code_bytes[i + 6] == 15 && code_bytes[i + 7] == 5
      // add rsp, 40 (48 83 C4 28); push -78 (6A B2); pop rax (58); nop
      push(out, 72) push(out, 131) push(out, 196) push(out, 40)
      push(out, 106) push(out, 178) push(out, 88) push(out, 144)
      i = i + 8
      continue
    @end
    // 4-arg raw syscall: [pop rdx; pop rsi; pop rdi; pop rax; syscall; 5B nop] (11B) -> add rsp, 32; push -78; pop rax; nop*4
    @if i + 11 <= code_len && b0 == 90 && code_bytes[i + 1] == 94 && code_bytes[i + 2] == 95 && code_bytes[i + 3] == 88 && code_bytes[i + 4] == 15 && code_bytes[i + 5] == 5 && code_bytes[i + 6] == 15 && code_bytes[i + 7] == 31 && code_bytes[i + 8] == 68 && code_bytes[i + 9] == 0 && code_bytes[i + 10] == 0
      push(out, 72) push(out, 131) push(out, 196) push(out, 32)
      push(out, 106) push(out, 178) push(out, 88)
      push(out, 144) push(out, 144) push(out, 144) push(out, 144)
      i = i + 11
      continue
    @end
    // 3-arg raw syscall: [pop rsi; pop rdi; pop rax; syscall; 5B nop] (10B) -> add rsp, 24; push -78; pop rax; nop*3
    @if i + 10 <= code_len && b0 == 94 && code_bytes[i + 1] == 95 && code_bytes[i + 2] == 88 && code_bytes[i + 3] == 15 && code_bytes[i + 4] == 5 && code_bytes[i + 5] == 15 && code_bytes[i + 6] == 31 && code_bytes[i + 7] == 68 && code_bytes[i + 8] == 0 && code_bytes[i + 9] == 0
      push(out, 72) push(out, 131) push(out, 196) push(out, 24)
      push(out, 106) push(out, 178) push(out, 88)
      push(out, 144) push(out, 144) push(out, 144)
      i = i + 10
      continue
    @end
    // 2-arg raw syscall: [pop rdi; pop rax; syscall; 5B nop] (9B) -> add rsp, 16; push -78; pop rax; nop*2
    @if i + 9 <= code_len && b0 == 95 && code_bytes[i + 1] == 88 && code_bytes[i + 2] == 15 && code_bytes[i + 3] == 5 && code_bytes[i + 4] == 15 && code_bytes[i + 5] == 31 && code_bytes[i + 6] == 68 && code_bytes[i + 7] == 0 && code_bytes[i + 8] == 0
      push(out, 72) push(out, 131) push(out, 196) push(out, 16)
      push(out, 106) push(out, 178) push(out, 88)
      push(out, 144) push(out, 144)
      i = i + 9
      continue
    @end
    // 1-arg raw syscall: [pop rax; syscall; 5B nop] (8B) -> add rsp, 8; push -78; pop rax; nop
    @if i + 8 <= code_len && b0 == 88 && code_bytes[i + 1] == 15 && code_bytes[i + 2] == 5 && code_bytes[i + 3] == 15 && code_bytes[i + 4] == 31 && code_bytes[i + 5] == 68 && code_bytes[i + 6] == 0 && code_bytes[i + 7] == 0
      push(out, 72) push(out, 131) push(out, 196) push(out, 8)
      push(out, 106) push(out, 178) push(out, 88) push(out, 144)
      i = i + 8
      continue
    @end
    // 0-arg raw syscall: [syscall; 5B nop] (7B) -> push -78; pop rax; nop*4
    @if i + 7 <= code_len && b0 == 15 && code_bytes[i + 1] == 5 && code_bytes[i + 2] == 15 && code_bytes[i + 3] == 31 && code_bytes[i + 4] == 68 && code_bytes[i + 5] == 0 && code_bytes[i + 6] == 0
      push(out, 106) push(out, 178) push(out, 88)
      push(out, 144) push(out, 144) push(out, 144) push(out, 144)
      i = i + 7
      continue
    @end
    // 4. 9-byte mov rax, imm32; syscall (48 C7 C0 <lo> <hi> 00 00 0F 05) -> Darwin 0x0200xxxx (or -ENOSYS)
    @if i + 9 <= code_len && b0 == 72 && code_bytes[i + 1] == 199 && code_bytes[i + 2] == 192 && code_bytes[i + 5] == 0 && code_bytes[i + 6] == 0 && code_bytes[i + 7] == 15 && code_bytes[i + 8] == 5
      lnr9 = code_bytes[i + 3] + (code_bytes[i + 4] * 256)
      dnr9 = macho_darwin_sys_nr(lnr9)
      @if dnr9 >= 0
        push(out, 72) push(out, 199) push(out, 192)
        push(out, dnr9 & 255) push(out, (dnr9 / 256) & 255) push(out, 0) push(out, 2)
        push(out, 15) push(out, 5)
        i = i + 9
        continue
      @else
        // Unmapped Linux syscall: return -ENOSYS (-78) cleanly instead of executing wrong Darwin syscall!
        push(out, 72) push(out, 199) push(out, 192)
        push(out, 178) push(out, 255) push(out, 255) push(out, 255)
        push(out, 144) push(out, 144)
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
    // 6. 7-byte mov eax, <nr>; syscall (B8 <lo> <hi> 00 00 0F 05) -> Darwin BSD class-2 syscall (or -ENOSYS)
    @if i + 7 <= code_len && b0 == 184 && code_bytes[i + 3] == 0 && code_bytes[i + 4] == 0 && code_bytes[i + 5] == 15 && code_bytes[i + 6] == 5
      lnr7 = code_bytes[i + 1] + (code_bytes[i + 2] * 256)
      dnr7 = macho_darwin_sys_nr(lnr7)
      @if dnr7 >= 0
        push(out, 184) push(out, dnr7 & 255) push(out, (dnr7 / 256) & 255) push(out, 0) push(out, 2)
        push(out, 15) push(out, 5)
        i = i + 7
        continue
      @else
        // Unmapped Linux syscall (including epoll_create1=291, epoll_pwait=281, etc.): mov eax, -78 (-ENOSYS); nop; nop (7B)
        push(out, 184) push(out, 178) push(out, 255) push(out, 255) push(out, 255)
        push(out, 144) push(out, 144)
        i = i + 7
        continue
      @end
    @end
    push(out, b0)
    i = i + 1
  @end
  return out
@end

@fn macho_patch_darwin_code_pie(code_bytes, text_vmaddr, data_vmaddr, rodata_len)
  return macho_patch_darwin_code_pie_ex(code_bytes, text_vmaddr, data_vmaddr, rodata_len, rodata_len, 0)
@end

@fn macho_patch_darwin_code_full(code_bytes, data_vmaddr, rodata_len)
  return macho_patch_darwin_code_pie(code_bytes, 0, data_vmaddr, rodata_len)
@end

@fn macho_patch_darwin_code(code_bytes, data_vmaddr)
  return macho_patch_darwin_code_pie(code_bytes, 0, data_vmaddr, 0)
@end

@fn macho_darwin_arm64_sys_word(w)
  // WHY: Translates Linux AArch64 MOVZ X8, #<linux_nr> into Darwin MOVZ X16, #<bsd_nr>.
  // Returns 0 if w is not a recognized Linux syscall load.
  @if w == 3531605768 return 3531618800 @end // openat(56) -> Darwin openat(463)
  @if w == 3531605800 return 3531604176 @end // close(57)  -> Darwin close(6)
  @if w == 3531605960 return 3531610352 @end // lseek(62)  -> Darwin lseek(199)
  @if w == 3531605992 return 3531604080 @end // read(63)   -> Darwin read(3)
  @if w == 3531606024 return 3531604112 @end // write(64)  -> Darwin write(4)
  @if w == 3531606952 return 3531604016 @end // exit(93)   -> Darwin exit(1)
  @if w == 3531606984 return 3531604016 @end // exit_group(94) -> Darwin exit(1)
  @if w == 3531610856 return 3531606320 @end // munmap(215)-> Darwin munmap(73)
  @if w == 3531611080 return 3531610288 @end // mmap(222)  -> Darwin mmap(197)
  @if w == 3531605512 return 3531618896 @end // faccessat(48) -> Darwin faccessat(466)
  @if w == 3531605096 return 3531619088 @end // unlinkat(35)  -> Darwin unlinkat(472)
  @if w == 3531609480 return 3531604624 @end // getpid(172)   -> Darwin getpid(20)
  return 0
@end

@fn macho_arm64_has_svc_nearby(out, idx, n)
  // WHY: Scopes Linux->Darwin syscall register/flag rewrites strictly to instructions
  // immediately preceding an AArch64 `SVC #0` (0xD4000001) so user integer constants
  // (-100, 34, 577, 56..222) in ordinary functions are never clobbered.
  la = idx + 4
  lim = idx + 36
  @if lim > n lim = n @end
  @while la + 3 < lim
    lw = out[la] + (out[la + 1] * 256) + (out[la + 2] * 65536) + (out[la + 3] * 16777216)
    @if lw == 3556769793
      return 1
    @end
    // Stop scanning across RET (0xD65F03C0) or unconditional B/BL
    @if lw == 3596551104 || ((lw / 67108864) & 63) == 5 || ((lw / 67108864) & 63) == 37
      return 0
    @end
    la = la + 4
  @end
  return 0
@end

@fn macho_patch_darwin_arm64_pie_ex(code_bytes, text_vmaddr, data_vmaddr, rodata_len, rw_data_off)
  // WHY: Relocates Linux AArch64 ELF64 .rodata and 16B-aligned RW heap slots into Mach-O __DATA using
  // TRUE Apple Silicon position-independent `ADRP Xd, page_delta; ADD Xd, Xd, #page_off; NOP; NOP`
  // when text_vmaddr > 0, translates ALL Linux AArch64 syscalls (openat/close/read/write/lseek/
  // mmap/munmap/exit/faccessat/unlinkat/getpid + AT_FDCWD -100->-2 + O_CREAT|O_TRUNC 577->1537 +
  // MAP_ANON 34->0x1002) strictly near SVC #0 sites to Darwin XNU BSD ABI, and replaces unmapped
  // Linux SVC #0 with MOVN X0,#77 (-ENOSYS)!
  n = code_bytes.len()
  @if n < 4 return code_bytes @end
  out = []
  ri = 0
  @while ri < n
    out = out.push(code_bytes[ri])
    ri = ri + 1
  @end

  linux_ro_base = 4194536 + n
  linux_ro_end = linux_ro_base + rodata_len + 64
  rx_sz = 232 + n + rodata_len
  rem_rx = rx_sz % 4096
  rx_pad = 0
  @if rem_rx != 0
    rx_pad = 4096 - rem_rx
  @end
  linux_rw_base = 4259840 + rx_sz + rx_pad

  // 1. Rewrite 4-instruction MOVZ/MOVK absolute address quads into PIE ADRP+ADD+NOP+NOP (16B exact!)
  idx = 0
  @while idx + 15 < n
    w0 = out[idx] + (out[idx + 1] * 256) + (out[idx + 2] * 65536) + (out[idx + 3] * 16777216)
    w1 = out[idx + 4] + (out[idx + 5] * 256) + (out[idx + 6] * 65536) + (out[idx + 7] * 16777216)
    w2 = out[idx + 8] + (out[idx + 9] * 256) + (out[idx + 10] * 65536) + (out[idx + 11] * 16777216)
    w3 = out[idx + 12] + (out[idx + 13] * 256) + (out[idx + 14] * 65536) + (out[idx + 15] * 16777216)
    reg0 = w0 & 31
    @if ((w0 / 2097152) & 2047) == 1684 && ((w1 / 2097152) & 2047) == 1941 && (w1 & 31) == reg0 && ((w2 / 2097152) & 2047) == 1942 && (w2 & 31) == reg0 && ((w3 / 2097152) & 2047) == 1943 && (w3 & 31) == reg0
      c0 = (w0 / 32) & 65535
      c1 = (w1 / 32) & 65535
      c2 = (w2 / 32) & 65535
      c3 = (w3 / 32) & 65535
      addr = c0 + (c1 * 65536) + (c2 * 4294967296)
      @if c3 == 0
        new_addr = 0
        @if addr >= linux_ro_base && addr < linux_ro_end
          new_addr = data_vmaddr + (addr - linux_ro_base)
        @elif addr >= linux_rw_base && addr < (linux_rw_base + 16777216)
          new_addr = data_vmaddr + rw_data_off + (addr - linux_rw_base)
        @end
        @if new_addr > 0
          @if text_vmaddr > 0
            // True PIE ARM64: ADRP Xd, page_delta; ADD Xd, Xd, #page_off; NOP; NOP
            pc_va = text_vmaddr + idx
            pc_page = pc_va - (pc_va % 4096)
            tgt_page = new_addr - (new_addr % 4096)
            p_delta = (tgt_page - pc_page) / 4096
            @if p_delta < 0
              p_delta = p_delta + 2097152
            @end
            immlo = p_delta & 3
            immhi = (p_delta / 4) & 524287
            nw0 = 2415919104 | (immlo * 536870912) | (immhi * 32) | reg0
            page_off = new_addr & 4095
            nw1 = 2432696320 | (page_off * 1024) | (reg0 * 32) | reg0
            nw2 = 3573751839 // NOP
            nw3 = 3573751839 // NOP
          @else
            nc0 = new_addr & 65535
            nc1 = (new_addr / 65536) & 65535
            nc2 = (new_addr / 4294967296) & 65535
            nw0 = 3531603968 | (nc0 * 32) | reg0
            nw1 = 4070572032 | (nc1 * 32) | reg0
            nw2 = 4072669184 | (nc2 * 32) | reg0
            nw3 = 4074766336 | reg0
          @end
          p0 = macho_pack_u32_le(nw0)
          p1 = macho_pack_u32_le(nw1)
          p2 = macho_pack_u32_le(nw2)
          p3 = macho_pack_u32_le(nw3)
          list_set(out, idx + 0, p0[0]) list_set(out, idx + 1, p0[1]) list_set(out, idx + 2, p0[2]) list_set(out, idx + 3, p0[3])
          list_set(out, idx + 4, p1[0]) list_set(out, idx + 5, p1[1]) list_set(out, idx + 6, p1[2]) list_set(out, idx + 7, p1[3])
          list_set(out, idx + 8, p2[0]) list_set(out, idx + 9, p2[1]) list_set(out, idx + 10, p2[2]) list_set(out, idx + 11, p2[3])
          list_set(out, idx + 12, p3[0]) list_set(out, idx + 13, p3[1]) list_set(out, idx + 14, p3[2]) list_set(out, idx + 15, p3[3])
        @end
      @end
    @end
    idx = idx + 4
  @end

  // 2. Rewrite Linux AArch64 syscalls -> Darwin Apple Silicon XNU BSD ABI (strictly scoped to SVC #0 sites!)
  last_sys_mapped = 0
  idx = 0
  @while idx + 3 < n
    w = out[idx] + (out[idx + 1] * 256) + (out[idx + 2] * 65536) + (out[idx + 3] * 16777216)
    nw = w
    // Detect MOVZ X8, #<imm> ONLY when an SVC #0 follows within 8 instructions
    @if ((w / 2097152) & 2047) == 1684 && (w & 31) == 8 && macho_arm64_has_svc_nearby(out, idx, n) == 1
      mapped_w = macho_darwin_arm64_sys_word(w)
      @if mapped_w != 0
        nw = mapped_w
        last_sys_mapped = 1
      @else
        // Unmapped Linux syscall number in X8: neutralize & mark so following SVC #0 returns -ENOSYS!
        nw = 3573751839 // NOP
        last_sys_mapped = 0
      @end
    @elif w == 4165011432 && macho_arm64_has_svc_nearby(out, idx, n) == 1
      // LDR X8, [sp], #16 (raw Linux syscall(...) intrinsic): do not execute Linux nr under Darwin SVC #0x80
      last_sys_mapped = 0
    @elif w == 2457865312 && macho_arm64_has_svc_nearby(out, idx, n) == 1
      nw = 2457862176 // MOVN X0, #99 (Linux AT_FDCWD=-100) -> MOVN X0, #1 (Darwin AT_FDCWD=-2)
    @elif w == 3531622434 && macho_arm64_has_svc_nearby(out, idx, n) == 1
      nw = 3531653154 // MOVZ X2, #577 (Linux O_WR|CR|TR) -> MOVZ X2, #1537 (Darwin O_WR|CR|TR)
    @elif w == 3531605059 && macho_arm64_has_svc_nearby(out, idx, n) == 1
      nw = 3531735107 // MOVZ X3, #34 (Linux MAP_ANON|PRIVATE) -> MOVZ X3, #0x1002 (Darwin)
    @elif w == 3556769793
      // SVC #0 -> SVC #0x80 ONLY if immediately preceded by a mapped Darwin syscall; else MOVN X0, #77 (-ENOSYS = -78)!
      @if last_sys_mapped == 1
        nw = 3556773889 // SVC #0x80
      @else
        nw = 2457864608 // MOVN X0, #77 (-78 = -ENOSYS)
      @end
      last_sys_mapped = 0
    @end
    @if nw != w
      pb = macho_pack_u32_le(nw)
      list_set(out, idx + 0, pb[0])
      list_set(out, idx + 1, pb[1])
      list_set(out, idx + 2, pb[2])
      list_set(out, idx + 3, pb[3])
    @end
    idx = idx + 4
  @end
  return out
@end

@fn macho_patch_darwin_arm64_pie(code_bytes, text_vmaddr, data_vmaddr, rodata_len)
  return macho_patch_darwin_arm64_pie_ex(code_bytes, text_vmaddr, data_vmaddr, rodata_len, rodata_len)
@end

@fn macho_patch_darwin_arm64(code_bytes, data_vmaddr, rodata_len)
  return macho_patch_darwin_arm64_pie(code_bytes, 0, data_vmaddr, rodata_len)
@end

@fn macho_build_adhoc_codesig_ex(binary_prefix, code_limit, text_vmsize, cs_page, cs_log2)
  // WHY: Generates a real Apple CS_SuperBlob (0xFADE0CC0) + 88-byte v0x20400 SHA-256
  // CS_CodeDirectory (0xFADE0C02) with execSegBase/execSegLimit/execSegFlags for Apple Silicon.
  n_slots = (code_limit + cs_page - 1) / cs_page
  @if n_slots < 1 n_slots = 1 @end
  cd_len = 88 + 9 + (n_slots * 32)
  total_len = 20 + cd_len

  blob = []
  blob = macho_concat(blob, macho_pack_u32_be(4208856256)) // 0xFADE0CC0 SuperBlob
  blob = macho_concat(blob, macho_pack_u32_be(total_len))
  blob = macho_concat(blob, macho_pack_u32_be(1))
  blob = macho_concat(blob, macho_pack_u32_be(0))
  blob = macho_concat(blob, macho_pack_u32_be(20))

  blob = macho_concat(blob, macho_pack_u32_be(4208856066)) // 0xFADE0C02 CodeDirectory
  blob = macho_concat(blob, macho_pack_u32_be(cd_len))
  blob = macho_concat(blob, macho_pack_u32_be(132096))     // version = 0x20400
  blob = macho_concat(blob, macho_pack_u32_be(131074))     // flags = adhoc | linkerSigned
  blob = macho_concat(blob, macho_pack_u32_be(97))         // hashOffset = 88 + 9
  blob = macho_concat(blob, macho_pack_u32_be(88))         // identOffset = 88
  blob = macho_concat(blob, macho_pack_u32_be(0))          // nSpecialSlots
  blob = macho_concat(blob, macho_pack_u32_be(n_slots))    // nCodeSlots
  blob = macho_concat(blob, macho_pack_u32_be(code_limit)) // codeLimit
  blob = blob.push(32)                                     // hashSize = 32
  blob = blob.push(2)                                      // hashType = SHA-256
  blob = blob.push(0)                                      // platform = 0
  blob = blob.push(cs_log2)                                // pageSize log2 (14 for ARM64 16KB, 12 for x86_64 4KB)
  blob = macho_concat(blob, macho_pack_u32_be(0))          // spare2
  // v0x20200 .. v0x20400 fields (44 bytes -> total 88-byte header)
  blob = macho_concat(blob, macho_pack_u32_be(0))          // scatterOffset
  blob = macho_concat(blob, macho_pack_u32_be(0))          // teamOffset
  blob = macho_concat(blob, macho_pack_u32_be(0))          // spare3
  blob = macho_concat(blob, macho_pack_u32_be(0))          // codeLimit64 hi
  blob = macho_concat(blob, macho_pack_u32_be(0))          // codeLimit64 lo
  blob = macho_concat(blob, macho_pack_u32_be(0))          // execSegBase hi
  blob = macho_concat(blob, macho_pack_u32_be(0))          // execSegBase lo
  es_hi = (text_vmsize / 4294967296) & 4294967295
  es_lo = text_vmsize & 4294967295
  blob = macho_concat(blob, macho_pack_u32_be(es_hi))      // execSegLimit hi
  blob = macho_concat(blob, macho_pack_u32_be(es_lo))      // execSegLimit lo
  blob = macho_concat(blob, macho_pack_u32_be(0))          // execSegFlags hi
  blob = macho_concat(blob, macho_pack_u32_be(1))          // execSegFlags lo (CS_EXECSEG_MAIN_BINARY = 1)

  ident_bytes = [108, 105, 112, 105, 95, 98, 105, 110, 0]
  blob = macho_concat(blob, ident_bytes)

  si = 0
  @while si < n_slots
    p_start = si * cs_page
    p_end = p_start + cs_page
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

@fn macho_build_adhoc_codesig(binary_prefix, code_limit)
  return macho_build_adhoc_codesig_ex(binary_prefix, code_limit, code_limit, 4096, 12)
@end

@fn macho_emit_executable(code_bytes, data_bytes, bss_size, cputype, output_path)
  // WHY: Comprehensive Mach-O 64 binary generator with Apple Silicon 16KB paging & v0x20400 CodeDirectory.
  page_size = 4096
  cs_page = 4096
  cs_log2 = 12
  @if cputype == 16777228
    page_size = 16384
    cs_page = 16384
    cs_log2 = 14
  @end

  // 1. Calculate Load Commands Size
  // Header: 32 bytes
  // Cmd 1: __PAGEZERO segment command = 72 bytes
  // Cmd 2: __TEXT segment command with 1 section (__text) = 72 + 80 = 152 bytes
  // Cmd 3: LC_LOAD_DYLINKER command (/usr/lib/dyld) = 32 bytes
  // Cmd 4: LC_LOAD_DYLIB command (/usr/lib/libSystem.B.dylib) = 56 bytes
  // Cmd 5: LC_MAIN command = 24 bytes
  // Cmd 6: __DATA segment command with 2 sections (__data, __bss) = 72 + 80 + 80 = 232 bytes
  // Cmd 7: __LINKEDIT segment command = 72 bytes; Cmd 8: LC_CODE_SIGNATURE = 16 bytes

  // Always emit __DATA with rodata + 16B alignment pad + 4096B RW runtime/mutable globals + __LINKEDIT (LC_CODE_SIGNATURE)
  ro_orig_len = data_bytes.len()
  full_data_bytes = []
  full_data_bytes = macho_concat(full_data_bytes, data_bytes)
  full_data_bytes = macho_pad_to(full_data_bytes, 16)
  rw_data_off = full_data_bytes.len()
  gi = 0
  @while gi < 4096
    full_data_bytes = full_data_bytes.push(0)
    gi = gi + 1
  @end
  has_data = 1

  // 11 Load Commands (784B total -> header 32 + 784 = 816, 16-byte aligned):
  //   1: __PAGEZERO (72)  2: __TEXT+__text (152)  3: LC_LOAD_DYLINKER (32)  4: LC_LOAD_DYLIB (56)
  //   5: LC_BUILD_VERSION (24)  6: LC_MAIN (24)  7: __DATA+__data+__bss (232)
  //   8: __LINKEDIT (72)  9: LC_SYMTAB (24)  10: LC_DYSYMTAB (80)  11: LC_CODE_SIGNATURE (16)
  ncmds = 11
  sizeofcmds = 72 + 152 + 32 + 56 + 24 + 24 + 232 + 72 + 24 + 80 + 16 // = 784 bytes

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

  // Size of __TEXT in file and memory (aligned to page_size)
  text_file_end = text_offset + text_size
  text_vmsize = text_file_end
  rem_page = text_vmsize % page_size
  @if rem_page != 0
    text_vmsize = text_vmsize + (page_size - rem_page)
  @end

  // 2. Configure __DATA Segment (rodata + 4096B RW runtime globals + bss)
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

  // 2b. Configure __LINKEDIT: [symtab 16B (1 nlist_64: _main)] + [strtab 8B ("\0_main\0\0")] + [8B pad] + [CodeSignature]
  linkedit_offset = data_offset + data_file_aligned
  linkedit_vmaddr = data_vmaddr + data_vmsize
  symtab_off = linkedit_offset
  strtab_off = symtab_off + 16
  strtab_sz = 8
  codesig_offset = linkedit_offset + 32 // 16-byte aligned!
  n_cs_slots = (codesig_offset + cs_page - 1) / cs_page
  @if n_cs_slots < 1 n_cs_slots = 1 @end
  codesig_size = 20 + 88 + 9 + (n_cs_slots * 32)
  linkedit_filesize = 32 + codesig_size
  linkedit_vmsize = linkedit_filesize
  rem_lpage = linkedit_vmsize % page_size
  @if rem_lpage != 0
    linkedit_vmsize = linkedit_vmsize + (page_size - rem_lpage)
  @end

  // Relocate x86_64 or ARM64 Linux ELF64 .rodata, 16B-aligned RW globals/@bss, and syscalls to TRUE PIE Darwin Mach-O ABI!
  @if cputype == 16777223
    code_bytes = macho_patch_darwin_code_pie_ex(code_bytes, text_vmaddr, data_vmaddr, ro_orig_len, rw_data_off, bss_size)
  @elif cputype == 16777228
    code_bytes = macho_patch_darwin_arm64_pie_ex(code_bytes, text_vmaddr, data_vmaddr, ro_orig_len, rw_data_off)
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

  // Cmd 5: LC_BUILD_VERSION (PLATFORM_MACOS = 1, minos = 14.0.0 = 0x000E0000, sdk = 14.0.0)
  cmd_build_ver_bytes = macho_lc_build_version_serialize(PLATFORM_MACOS(), 917504, 917504) // 24 bytes

  // Cmd 6: LC_MAIN
  lc_main = macho_lc_main_create(text_offset, 0)
  lc_main_bytes = macho_lc_main_serialize(lc_main) // 24 bytes

  // Cmd 7: __DATA
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

  // Cmd 8..11: __LINKEDIT, LC_SYMTAB, LC_DYSYMTAB, LC_CODE_SIGNATURE
  seg_linkedit = macho_segment_linkedit(linkedit_vmaddr, linkedit_vmsize, linkedit_offset, linkedit_filesize)
  cmd_linkedit_bytes = macho_segment_header_serialize(seg_linkedit) // 72 bytes
  cmd_symtab_bytes = macho_lc_symtab_serialize(symtab_off, 1, strtab_off, strtab_sz) // 24 bytes
  cmd_dysymtab_bytes = macho_lc_dysymtab_serialize(0, 1, 1) // 80 bytes
  cmd_codesig_bytes = macho_lc_code_signature_serialize(codesig_offset, codesig_size) // 16 bytes

  // 5. Assemble Binary Stream
  binary = []
  binary = macho_concat(binary, hdr_bytes)
  binary = macho_concat(binary, cmd_pagezero_bytes)
  binary = macho_concat(binary, cmd_text_header_bytes)
  binary = macho_concat(binary, sec_text_bytes)
  binary = macho_concat(binary, cmd_dylinker_bytes)
  binary = macho_concat(binary, cmd_dylib_bytes)
  binary = macho_concat(binary, cmd_build_ver_bytes)
  binary = macho_concat(binary, lc_main_bytes)
  @if has_data == 1
    binary = macho_concat(binary, cmd_data_bytes)
  @end
  binary = macho_concat(binary, cmd_linkedit_bytes)
  binary = macho_concat(binary, cmd_symtab_bytes)
  binary = macho_concat(binary, cmd_dysymtab_bytes)
  binary = macho_concat(binary, cmd_codesig_bytes)

  // Pad up to text_offset
  @while binary.len() < text_offset
    binary = binary.push(0)
  @end

  // Append __text machine code
  binary = macho_concat(binary, code_bytes)

  // Append __DATA if present
  @if has_data == 1
    @while binary.len() < data_offset
      binary = binary.push(0)
    @end
    binary = macho_concat(binary, full_data_bytes)
  @end

  // Pad up to linkedit_offset and emit 16B nlist_64 (_main) + 8B strtab ("\0_main\0\0") + 8B pad
  @while binary.len() < linkedit_offset
    binary = binary.push(0)
  @end
  // nlist_64: n_strx=1(4B), n_type=0x0F (N_EXT|N_SECT)(1B), n_sect=1(__text)(1B), n_desc=0(2B), n_value=text_vmaddr(8B)
  binary = macho_concat(binary, macho_pack_u32_le(1))
  binary = binary.push(15)
  binary = binary.push(1)
  binary = binary.push(0)
  binary = binary.push(0)
  binary = macho_concat(binary, macho_pack_u64_le(text_vmaddr))
  // strtab: "\0_main\0\0" (8B) + 8B alignment pad = 16B (total 32B before CodeSignature)
  binary = macho_concat(binary, [0, 95, 109, 97, 105, 110, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

  codesig_blob = macho_build_adhoc_codesig_ex(binary, codesig_offset, text_vmsize, cs_page, cs_log2)
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
