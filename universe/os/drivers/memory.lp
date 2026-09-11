@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — BARE-METAL PHYSICAL MEMORY & 4-LEVEL PAGING
@! Module: universe/os/drivers/memory.maya
@! Milestone: Grand Sovereign Pillar 4
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features: Physical Page Frame Allocator (4KB Frames), PML4/PDPT/PD/PT
@! 4-Level Paging Table Descriptors and Address Translation Math
@! ============================================================================

import "universe/core/collections"

@! ============================================================================
@! 1. PHYSICAL PAGE FRAME ALLOCATOR
@! ============================================================================

@struct PageFrameAllocator
  total_frames: i64
  free_frames: i64
  bitmap: array
  page_size: i64
@end

@struct PageTableEntry
  present: i64
  writable: i64
  user_access: i64
  write_through: i64
  cache_disabled: i64
  accessed: i64
  dirty: i64
  page_size_huge: i64
  frame_address: i64
@end

@struct VirtualAddress4Level
  pml4_index: i64
  pdpt_index: i64
  pd_index: i64
  pt_index: i64
  offset_in_page: i64
@end

@fn page_allocator_new(total_memory_bytes)
  page_sz = 4096 @! 4KB
  n_frames = total_memory_bytes / page_sz
  n_words = (n_frames + 63) / 64
  
  bm = []
  i = 0
  @while i < n_words
    bm = bm.push(0) @! All free (0)
    i = i + 1
  @end

  return {
    total_frames: n_frames,
    free_frames: n_frames,
    bitmap: bm,
    page_size: page_sz
  }
@end

@fn page_alloc_frame(allocator)
  i = 0
  n_words = allocator.bitmap.len()
  @while i < n_words
    w = allocator.bitmap[i]
    @if w != -1 @! Has free bit
      bit = 0
      @while bit < 64
        mask = 1
        b_idx = 0
        @while b_idx < bit
          mask = mask * 2
          b_idx = b_idx + 1
        @end

        @if (w / mask) % 2 == 0 @! Bit is 0 (Free)
          allocator.bitmap[i] = w + mask
          allocator.free_frames = allocator.free_frames - 1
          frame_idx = (i * 64) + bit
          return frame_idx * allocator.page_size
        @end
        bit = bit + 1
      @end
    @end
    i = i + 1
  @end
  return -1 @! Out of physical memory
@end

@fn page_free_frame(allocator, phys_addr)
  frame_idx = phys_addr / allocator.page_size
  word_idx = frame_idx / 64
  bit_idx = frame_idx % 64

  mask = 1
  b = 0
  @while b < bit_idx
    mask = mask * 2
    b = b + 1
  @end

  w = allocator.bitmap[word_idx]
  @if (w / mask) % 2 == 1
    allocator.bitmap[word_idx] = w - mask
    allocator.free_frames = allocator.free_frames + 1
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 2. 4-LEVEL PAGING (x86_64 Virtual Address Decomposition)
@! ============================================================================

@fn page_split_virtual_address(virt_addr)
  offset = virt_addr % 4096
  rest = virt_addr / 4096
  
  pt_i = rest % 512
  rest = rest / 512
  
  pd_i = rest % 512
  rest = rest / 512
  
  pdpt_i = rest % 512
  rest = rest / 512
  
  pml4_i = rest % 512

  return {
    pml4_index: pml4_i,
    pdpt_index: pdpt_i,
    pd_index: pd_i,
    pt_index: pt_i,
    offset_in_page: offset
  }
@end

@fn page_entry_encode(entry)
  flags = 0
  @if entry.present == 1 flags = flags + 1 @end
  @if entry.writable == 1 flags = flags + 2 @end
  @if entry.user_access == 1 flags = flags + 4 @end
  @if entry.write_through == 1 flags = flags + 8 @end
  @if entry.cache_disabled == 1 flags = flags + 16 @end
  @if entry.accessed == 1 flags = flags + 32 @end
  @if entry.dirty == 1 flags = flags + 64 @end
  @if entry.page_size_huge == 1 flags = flags + 128 @end

  aligned_frame = entry.frame_address - (entry.frame_address % 4096)
  return aligned_frame + flags
@end
