@! ============================================================================
@! MAYA DIRECT HEAP & SLAB MEMORY ALLOCATOR (allocator.my)
@! 100% Written in Pure Maya Language — Zero malloc / free / libc.so
@! ============================================================================

import "universe/os/syscalls"

@! Page size constant (4096 bytes)
@fn PAGE_SIZE()
  return 4096
@end

@! Maya Heap Arena Structure
@fn arena_create(initial_pages)
  total_bytes = initial_pages * PAGE_SIZE()
  @! PROT_READ(1) | PROT_WRITE(2) = 3
  @! MAP_PRIVATE(2) | MAP_ANONYMOUS(32) = 34
  ptr = sys_mmap(0, total_bytes, 3, 34, 0 - 1, 0)
  
  return {
    base_ptr: ptr,
    capacity: total_bytes,
    offset: 0,
    allocations_count: 0
  }
@end

@! O(1) Bump Allocation inside Maya Arena
@fn arena_alloc(arena, size)
  @! Align to 8-byte boundary
  aligned_size = (size + 7) / 8 * 8
  
  @if arena.offset + aligned_size > arena.capacity
    @! Out of arena capacity: request next chunk via sys_mmap
    new_chunk_size = (aligned_size + PAGE_SIZE() - 1) / PAGE_SIZE() * PAGE_SIZE()
    new_ptr = sys_mmap(0, new_chunk_size, 3, 34, 0 - 1, 0)
    return {
      ptr: new_ptr,
      arena: {
        base_ptr: new_ptr,
        capacity: new_chunk_size,
        offset: aligned_size,
        allocations_count: arena.allocations_count + 1
      }
    }
  @end
  
  allocated_ptr = arena.base_ptr + arena.offset
  return {
    ptr: allocated_ptr,
    arena: {
      base_ptr: arena.base_ptr,
      capacity: arena.capacity,
      offset: arena.offset + aligned_size,
      allocations_count: arena.allocations_count + 1
    }
  }
@end

@! Reset Arena (Zero-cost instantaneous deallocation)
@fn arena_reset(arena)
  return {
    base_ptr: arena.base_ptr,
    capacity: arena.capacity,
    offset: 0,
    allocations_count: 0
  }
@end

@! Slab Allocator for Fixed-Size Small Objects (32B, 64B, 128B, 256B)
@fn slab_pool_create(slot_size, num_slots)
  total_size = slot_size * num_slots
  raw_ptr = sys_mmap(0, total_size, 3, 34, 0 - 1, 0)
  
  free_slots = []
  i = 0
  @while i < num_slots
    free_slots = free_slots.push(raw_ptr + (i * slot_size))
    i = i + 1
  @end
  
  return {
    slot_size: slot_size,
    num_slots: num_slots,
    base_ptr: raw_ptr,
    free_list: free_slots,
    used_count: 0
  }
@end

@fn slab_alloc(pool)
  @if pool.free_list.len() == 0
    @! Pool exhausted, return error or expand
    return { ptr: 0, pool: pool }
  @end
  
  allocated_ptr = pool.free_list[pool.free_list.len() - 1]
  
  @! Pop free slot
  new_free = []
  i = 0
  @while i < pool.free_list.len() - 1
    new_free = new_free.push(pool.free_list[i])
    i = i + 1
  @end
  
  return {
    ptr: allocated_ptr,
    pool: {
      slot_size: pool.slot_size,
      num_slots: pool.num_slots,
      base_ptr: pool.base_ptr,
      free_list: new_free,
      used_count: pool.used_count + 1
    }
  }
@end

@fn slab_free(pool, ptr)
  new_free = pool.free_list.push(ptr)
  return {
    slot_size: pool.slot_size,
    num_slots: pool.num_slots,
    base_ptr: pool.base_ptr,
    free_list: new_free,
    used_count: pool.used_count - 1
  }
@end
