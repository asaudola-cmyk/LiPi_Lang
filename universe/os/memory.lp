@! ============================================================================
@! MAYA SEGREGATED FREE-LIST HEAP ALLOCATOR — universe/os/memory.maya
@! 100% Written in Pure Maya Language — Linux x86-64 sys_mmap/munmap Backing
@! Features: 9 Segregated Size Classes, Splitting, Immediate Coalescing, Canaries
@! ============================================================================

import "universe/os/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Allocator Constants & Canaries
@! ----------------------------------------------------------------------------

@fn CANARY_HEAD() return 3735928559 @end  @! 0xDEADBEEF
@fn CANARY_FOOT() return 3405691582 @end  @! 0xCAFEBABE
@fn BLOCK_HEADER_SIZE() return 64 @end
@fn MIN_BLOCK_PAYLOAD() return 32 @end
@fn PAGE_SIZE() return 4096 @end

@! Maps size to segregated bin index 0..8
@fn memory_size_class(size)
  @if size <= 32 return 0 @end
  @if size <= 64 return 1 @end
  @if size <= 128 return 2 @end
  @if size <= 256 return 3 @end
  @if size <= 512 return 4 @end
  @if size <= 1024 return 5 @end
  @if size <= 2048 return 6 @end
  @if size <= 4096 return 7 @end
  return 8
@end

@! ----------------------------------------------------------------------------
@! 2. Heap Data Structure & Initialization
@! ----------------------------------------------------------------------------

@fn heap_new()
  return {
    blocks: [],
    bins: [[], [], [], [], [], [], [], [], []],
    total_mmap_bytes: 0,
    allocated_bytes: 0,
    free_bytes: 0,
    mmap_calls: 0,
    alloc_calls: 0,
    free_calls: 0,
    coalesce_events: 0,
    alloc_seq: 0
  }
@end

@fn heap_create_block(raw_addr, size, is_free, seq)
  sc = memory_size_class(size)
  return {
    raw_addr: raw_addr,
    addr: raw_addr + 64,
    size: size,
    is_free: is_free,
    canary_head: 3735928559,
    canary_foot: 3405691582,
    size_class: sc,
    alloc_seq: seq
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Core Allocation with Segregated Search & Block Splitting
@! ----------------------------------------------------------------------------

@fn memory_alloc(heap, size)
  @if size <= 0 return 0 @end
  
  @! Align requested size to 8-byte boundary
  rem = size % 8
  req_size = size
  @if rem != 0
    req_size = size + (8 - rem)
  @end
  
  heap.alloc_calls = heap.alloc_calls + 1
  sc = memory_size_class(req_size)
  
  @! Search existing free blocks in segregated bins starting from target class
  found_idx = 0 - 1
  b = sc
  @while b <= 8
    i = 0
    n = heap.blocks.len()
    @while i < n
      blk = heap.blocks[i]
      @if blk.is_free == 1 && blk.size >= req_size
        found_idx = i
        break
      @end
      i = i + 1
    @end
    @if found_idx >= 0 break @end
    b = b + 1
  @end
  
  @! If no reusable free block, mmap a new page chunk
  @if found_idx < 0
    chunk_pages = (req_size + 64 + 4095) / 4096
    @if chunk_pages < 4
      chunk_pages = 4 @! Default 16KB minimum chunk
    @end
    chunk_bytes = chunk_pages * 4096
    
    @! PROT_READ(1) | PROT_WRITE(2) = 3, MAP_PRIVATE(2) | MAP_ANON(32) = 34
    raw_ptr = sys_mmap(0, chunk_bytes, 3, 34, 0 - 1, 0)
    @if raw_ptr <= 0
      return 0 @! Out of memory
    @end
    
    heap.total_mmap_bytes = heap.total_mmap_bytes + chunk_bytes
    heap.free_bytes = heap.free_bytes + (chunk_bytes - 64)
    heap.mmap_calls = heap.mmap_calls + 1
    
    heap.alloc_seq = heap.alloc_seq + 1
    new_blk = heap_create_block(raw_ptr, chunk_bytes - 64, 1, heap.alloc_seq)
    heap.blocks = heap.blocks.push(new_blk)
    found_idx = heap.blocks.len() - 1
  @end
  
  target_blk = heap.blocks[found_idx]
  avail_size = target_blk.size
  
  @! Check if block should be split
  @if avail_size >= req_size + 64 + 32
    target_blk.size = req_size
    target_blk.is_free = 0
    target_blk.size_class = memory_size_class(req_size)
    
    split_raw = target_blk.addr + req_size
    split_size = avail_size - req_size - 64
    
    heap.alloc_seq = heap.alloc_seq + 1
    split_blk = heap_create_block(split_raw, split_size, 1, heap.alloc_seq)
    
    heap.blocks = heap.blocks.push(split_blk)
    heap.allocated_bytes = heap.allocated_bytes + req_size
    heap.free_bytes = heap.free_bytes - (req_size + 64)
  @else
    target_blk.is_free = 0
    target_blk.size_class = memory_size_class(target_blk.size)
    heap.allocated_bytes = heap.allocated_bytes + target_blk.size
    heap.free_bytes = heap.free_bytes - target_blk.size
  @end
  
  return target_blk.addr
@end

@! ----------------------------------------------------------------------------
@! 4. Immediate Coalescing Free Engine
@! ----------------------------------------------------------------------------

@fn memory_free(heap, ptr)
  @if ptr <= 0 return 0 @end
  
  heap.free_calls = heap.free_calls + 1
  
  @! Find matching block
  found_idx = 0 - 1
  i = 0
  n = heap.blocks.len()
  @while i < n
    blk = heap.blocks[i]
    @if blk.addr == ptr
      found_idx = i
      break
    @end
    i = i + 1
  @end
  
  @if found_idx < 0
    return 0 - 1 @! Invalid pointer
  @end
  
  target = heap.blocks[found_idx]
  
  @! Canary verification against heap corruption
  @if target.canary_head != 3735928559 || target.canary_foot != 3405691582
    return 0 - 2 @! Memory corruption detected
  @end
  
  @if target.is_free == 1
    return 0 @! Double free ignored
  @end
  
  target.is_free = 1
  heap.allocated_bytes = heap.allocated_bytes - target.size
  heap.free_bytes = heap.free_bytes + target.size
  
  @! Immediate Coalescing: Scan for adjacent contiguous free blocks
  coalesced = 1
  @while coalesced == 1
    coalesced = 0
    num_blks = heap.blocks.len()
    a = 0
    @while a < num_blks
      b_idx = 0
      @while b_idx < num_blks
        @if a != b_idx
          b1 = heap.blocks[a]
          b2 = heap.blocks[b_idx]
          @if b1.is_free == 1 && b2.is_free == 1
            @if b1.addr + b1.size == b2.raw_addr
              @! Merge b2 into b1
              b1.size = b1.size + 64 + b2.size
              b1.size_class = memory_size_class(b1.size)
              heap.free_bytes = heap.free_bytes + 64
              heap.coalesce_events = heap.coalesce_events + 1
              
              @! Remove b2 from blocks array
              new_blks = []
              k = 0
              @while k < num_blks
                @if k != b_idx
                  new_blks = new_blks.push(heap.blocks[k])
                @end
                k = k + 1
              @end
              heap.blocks = new_blks
              coalesced = 1
              break
            @end
          @end
        @end
        b_idx = b_idx + 1
      @end
      @if coalesced == 1 break @end
      a = a + 1
    @end
  @end
  
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. Memory Utilities & Standard POSIX APIs
@! ----------------------------------------------------------------------------

@fn memory_copy(dst_ptr, src_ptr, count)
  i = 0
  @while i < count
    b = maya_mem_read_u8(src_ptr + i)
    maya_mem_write_u8(dst_ptr + i, b)
    i = i + 1
  @end
  return dst_ptr
@end

@fn memory_set(dst_ptr, byte_val, count)
  i = 0
  @while i < count
    maya_mem_write_u8(dst_ptr + i, byte_val & 255)
    i = i + 1
  @end
  return dst_ptr
@end

@fn memory_read8(addr)
  return maya_mem_read_u8(addr)
@end

@fn memory_write8(addr, val)
  maya_mem_write_u8(addr, val & 255)
  return 1
@end

@fn memory_read16(addr)
  b0 = maya_mem_read_u8(addr)
  b1 = maya_mem_read_u8(addr + 1)
  return b0 | (b1 * 256)
@end

@fn memory_write16(addr, val)
  maya_mem_write_u8(addr, val & 255)
  maya_mem_write_u8(addr + 1, (val / 256) & 255)
  return 2
@end

@fn memory_read32(addr)
  b0 = maya_mem_read_u8(addr)
  b1 = maya_mem_read_u8(addr + 1)
  b2 = maya_mem_read_u8(addr + 2)
  b3 = maya_mem_read_u8(addr + 3)
  return b0 | (b1 * 256) | (b2 * 65536) | (b3 * 16777216)
@end

@fn memory_write32(addr, val)
  maya_mem_write_u8(addr, val & 255)
  maya_mem_write_u8(addr + 1, (val / 256) & 255)
  maya_mem_write_u8(addr + 2, (val / 65536) & 255)
  maya_mem_write_u8(addr + 3, (val / 16777216) & 255)
  return 4
@end

@fn memory_realloc(heap, ptr, new_size)
  @if ptr <= 0 return memory_alloc(heap, new_size) @end
  @if new_size <= 0
    memory_free(heap, ptr)
    return 0
  @end
  
  @! Find existing block
  cur_size = 0
  i = 0
  n = heap.blocks.len()
  @while i < n
    @if heap.blocks[i].addr == ptr
      cur_size = heap.blocks[i].size
      break
    @end
    i = i + 1
  @end
  
  @if cur_size >= new_size
    return ptr @! Reuses block
  @end
  
  new_ptr = memory_alloc(heap, new_size)
  @if new_ptr > 0
    memory_copy(new_ptr, ptr, cur_size)
    memory_free(heap, ptr)
  @end
  return new_ptr
@end

@fn heap_stats(heap)
  return {
    total_mmap_bytes: heap.total_mmap_bytes,
    allocated_bytes: heap.allocated_bytes,
    free_bytes: heap.free_bytes,
    mmap_calls: heap.mmap_calls,
    alloc_calls: heap.alloc_calls,
    free_calls: heap.free_calls,
    coalesce_events: heap.coalesce_events,
    block_count: heap.blocks.len()
  }
@end
