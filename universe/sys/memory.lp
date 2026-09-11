@! ============================================================================
@! MAYA FREESTANDING VIRTUAL MEMORY SUBSYSTEM (universe/sys/memory.maya)
@! 100% Written in Pure Maya Language — Complete Independence from libc malloc/free
@! Direct Kernel MMAP, MUNMAP, MPROTECT, BRK Memory Primitives
@! ============================================================================

import "universe/sys/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Memory Architectural Constants
@! ----------------------------------------------------------------------------

@fn PAGE_SIZE() return 4096 @end
@fn PAGE_MASK() return 4095 @end

@fn sys_page_align_up(val)
  @! Align address up to 4096-byte boundary: (val + 4095) & ~4095
  rem = val % 4096
  @if rem == 0 return val @end
  return val + (4096 - rem)
@end

@fn sys_page_align_down(val)
  @! Align address down to 4096-byte boundary
  return val - (val % 4096)
@end

@! ----------------------------------------------------------------------------
@! 2. Direct Kernel Anonymous Memory Allocation & Deallocation
@! ----------------------------------------------------------------------------

@fn sys_mmap_anon(size, prot)
  @! Allocate anonymous zeroed virtual memory pages directly from Linux kernel
  @! PROT: PROT_READ(1) | PROT_WRITE(2) = 3 (Default Read/Write)
  @! FLAGS: MAP_PRIVATE(2) | MAP_ANONYMOUS(32) = 34
  @! FD: -1, OFFSET: 0
  @if size <= 0 return 0 @end
  aligned_size = sys_page_align_up(size)
  res = sys_mmap(0, aligned_size, prot, 34, 0 - 1, 0)
  @if res < 0 return 0 @end
  return res
@end

@fn sys_munmap_anon(ptr, size)
  @! Release mapped virtual memory pages back to operating system
  @if ptr == 0 || size <= 0 return 0 @end
  aligned_size = sys_page_align_up(size)
  return sys_munmap(ptr, aligned_size)
@end

@fn sys_mprotect_range(ptr, size, prot)
  @! Change page protection permissions (PROT_READ, PROT_WRITE, PROT_EXEC)
  @if ptr == 0 || size <= 0 return 0 - 22 @end  @! -EINVAL
  aligned_addr = sys_page_align_down(ptr)
  aligned_size = sys_page_align_up(size)
  return sys_mprotect(aligned_addr, aligned_size, prot)
@end

@! ----------------------------------------------------------------------------
@! 3. Heap Break (BRK) Control
@! ----------------------------------------------------------------------------

@fn sys_brk_query()
  @! Query current break point address via sys_brk(0)
  return sys_brk(0)
@end

@fn sys_brk_grow(increment)
  @! Extend data segment break by specified increment
  current_brk = sys_brk_query()
  @if increment == 0 return current_brk @end
  target_brk = current_brk + increment
  new_brk = sys_brk(target_brk)
  @if new_brk < target_brk
    return 0  @! Failed to expand break
  @end
  return new_brk
@end

@! ----------------------------------------------------------------------------
@! 4. Pure Freestanding Memory Operations (Zero-Libc memset, memcpy, memcmp)
@! ----------------------------------------------------------------------------

@fn sys_memset(dst, byte_val, count)
  @! Set count bytes starting at dst to byte_val
  @if dst == 0 || count <= 0 return dst @end
  i = 0
  @while i < count
    sys_poke8(dst + i, byte_val)
    i = i + 1
  @end
  return dst
@end

@fn sys_memcpy(dst, src, count)
  @! Copy count bytes from src to dst
  @if dst == 0 || src == 0 || count <= 0 return dst @end
  i = 0
  @while i < count
    val = sys_peek8(src + i)
    sys_poke8(dst + i, val)
    i = i + 1
  @end
  return dst
@end

@fn sys_memcmp(p1, p2, count)
  @! Compare count bytes between p1 and p2; returns 0 if equal, 1/-1 otherwise
  @if p1 == p2 || count <= 0 return 0 @end
  i = 0
  @while i < count
    b1 = sys_peek8(p1 + i)
    b2 = sys_peek8(p2 + i)
    @if b1 != b2
      @if b1 > b2 return 1 @end
      return 0 - 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn sys_memzero(dst, count)
  return sys_memset(dst, 0, count)
@end
