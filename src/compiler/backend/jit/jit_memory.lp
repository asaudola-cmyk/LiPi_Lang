@! ============================================================================
@! LIPI JIT COMPILER BACKEND — EXECUTABLE MEMORY ALLOCATOR & PROTECTION (W^X)
@! Module: compiler/backend/jit/jit_memory.lp
@! Architecture: Linux x86-64 Userspace Anonymous Memory Management
@! Standard: sys_mmap (PROT_EXEC), sys_mprotect (W^X), sys_munmap, RAM Byte Writer
@! ============================================================================

import "utso/syscalls"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURES
@! ----------------------------------------------------------------------------

@struct JitMemoryBlock
  addr: 0        @! Virtual memory base address returned by sys_mmap
  size: 0        @! Total allocated size in bytes (4096-aligned)
  capacity: 0    @! Maximum usable byte capacity
  used: 0        @! Current byte write offset / cursor
  is_exec: 0      @! 1 if PROT_EXEC is currently enabled, 0 otherwise
@end

@! Page size constant for Linux x86-64 (4KB)
@fn jit_page_size()
  return 4096
@end

@! ----------------------------------------------------------------------------
@! 2. MEMORY ALLOCATION & DEALLOCATION
@! ----------------------------------------------------------------------------

@! Allocates anonymous writable (RW-only, strict W^X) RAM page(s) via sys_mmap.
@! WHY: Never maps pages RWX (prot=7); callers write code under PROT_READ|PROT_WRITE (3)
@! and transition to PROT_READ|PROT_EXEC (5) via jit_mem_protect_rx before execution.
@fn jit_mem_alloc(size_bytes)
  page_sz = jit_page_size()
  req_sz = size_bytes
  @if req_sz <= 0
    req_sz = page_sz
  @end

  @! Align requested size to next 4096-byte page boundary
  aligned_sz = ((req_sz + page_sz - 1) / page_sz) * page_sz

  @! Strict W^X: PROT_READ (1) | PROT_WRITE (2) = 3 (ZERO RWX mappings)
  prot_rw = PROT_READ() | PROT_WRITE()
  @! MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
  map_flags = MAP_PRIVATE() | MAP_ANONYMOUS()

  @! sys_mmap(addr=0, length=aligned_sz, prot=3, flags=34, fd=-1, offset=0)
  mmap_addr = sys_mmap(0, aligned_sz, prot_rw, map_flags, 0 - 1, 0)

  @if is_error(mmap_addr) || mmap_addr <= 0
    return {
      addr: 0,
      size: 0,
      capacity: 0,
      used: 0,
      is_exec: 0
    }
  @end

  return {
    addr: mmap_addr,
    size: aligned_sz,
    capacity: aligned_sz,
    used: 0,
    is_exec: 0
  }
@end

@! Releases allocated JIT memory page(s) back to kernel via sys_munmap
@fn jit_mem_free(block)
  @if block == 0 || block.addr == 0 || block.size <= 0
    return 0
  @end

  unmap_res = sys_munmap(block.addr, block.size)
  block.addr = 0
  block.size = 0
  block.capacity = 0
  block.used = 0
  block.is_exec = 0
  return unmap_res
@end

@! ----------------------------------------------------------------------------
@! 3. W^X MEMORY PROTECTION TRANSITIONS
@! ----------------------------------------------------------------------------

@! Transitions memory page to Read + Execute (RX) protection (W^X security)
@fn jit_mem_protect_rx(block)
  @if block == 0 || block.addr == 0 || block.size <= 0
    return 0 - 1
  @end

  prot_rx = PROT_READ() | PROT_EXEC()
  res = sys_mprotect(block.addr, block.size, prot_rx)
  @if is_ok(res)
    block.is_exec = 1
  @end
  return res
@end

@! Transitions memory page to Read + Write (RW) protection for code modification
@fn jit_mem_protect_rw(block)
  @if block == 0 || block.addr == 0 || block.size <= 0
    return 0 - 1
  @end

  prot_rw = PROT_READ() | PROT_WRITE()
  res = sys_mprotect(block.addr, block.size, prot_rw)
  @if is_ok(res)
    block.is_exec = 0
  @end
  return res
@end

@! Enforces strict W^X invariant: RWX (prot=7) is unconditionally forbidden.
@fn jit_mem_protect_rwx(block)
  // WHY: W^X forbids simultaneous write and execute permissions; reject RWX requests fail-closed.
  return 0 - 1
@end

@! ----------------------------------------------------------------------------
@! 4. RAM BYTE READ / WRITE OPERATIONS
@! ----------------------------------------------------------------------------

@! Writes a single byte into the JIT memory block at specified offset (requires RW mode)
@fn jit_mem_write_byte(block, offset, byte_val)
  // WHY: Enforces W^X by refusing writes while block is PROT_EXEC (is_exec == 1).
  @if block == 0 || block.addr == 0 || block.is_exec == 1 || offset < 0 || offset >= block.capacity
    return 0
  @end

  dest_addr = block.addr + offset
  b_val = (byte_val % 256 + 256) % 256
  lipi_mem_write_u8(dest_addr, b_val)

  @if offset + 1 > block.used
    block.used = offset + 1
  @end
  return 1
@end

@! Reads a single byte from the JIT memory block at specified offset
@fn jit_mem_read_byte(block, offset)
  @if block == 0 || block.addr == 0 || offset < 0 || offset >= block.capacity
    return 0
  @end

  src_addr = block.addr + offset
  return lipi_mem_read_u8(src_addr)
@end

@! Writes a contiguous sequence of machine code bytes into the JIT memory block (requires RW mode)
@fn jit_mem_write_bytes(block, offset, bytes)
  // WHY: Bulk-emits compiled native machine instructions into writable RW memory before mprotect(RX).
  @if block == 0 || block.addr == 0 || block.is_exec == 1 || offset < 0
    return 0
  @end

  b_len = bytes.len()
  @if offset + b_len > block.capacity
    return 0
  @end

  dest_addr = block.addr + offset
  i = 0
  @while i < b_len
    b_val = (bytes[i] % 256 + 256) % 256
    lipi_mem_write_u8(dest_addr + i, b_val)
    i = i + 1
  @end

  @if offset + b_len > block.used
    block.used = offset + b_len
  @end
  return b_len
@end
