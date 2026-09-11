@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MEMORY ARENA
@! Module: universe/core/arena.maya
@! Features: O(1) Allocation Arena, Zero-Fragmentation Memory Pooling
@! ============================================================================

@struct MemoryArena
  buffer: array
  capacity: i64
  offset: i64
@end

@fn arena_new(size_bytes: i64) -> MemoryArena
  buf = []
  i = 0
  @while i < size_bytes
    buf = buf.push(0)
    i = i + 1
  @end
  return {
    buffer: buf,
    capacity: size_bytes,
    offset: 0
  }
@end

@! Allocate a chunk of memory from the arena
@fn arena_alloc(arena: MemoryArena, size: i64) -> i64
  @if arena.offset + size > arena.capacity
    @! Out of memory in this arena
    return -1
  @end
  
  ptr = arena.offset
  arena.offset = arena.offset + size
  return ptr
@end

@! Reset the arena without freeing the underlying memory
@fn arena_reset(arena: MemoryArena) -> MemoryArena
  arena.offset = 0
  return arena
@end

@! Write data to the arena at specific ptr
@fn arena_write(arena: MemoryArena, ptr: i64, data: array) -> MemoryArena
  i = 0
  @while i < data.len()
    @if (ptr + i) < arena.capacity
      arena.buffer[ptr + i] = data[i]
    @end
    i = i + 1
  @end
  return arena
@end

@! Read data from arena
@fn arena_read(arena: MemoryArena, ptr: i64, size: i64) -> array
  res = []
  i = 0
  @while i < size
    @if (ptr + i) < arena.capacity
      res = res.push(arena.buffer[ptr + i])
    @else
      res = res.push(0)
    @end
    i = i + 1
  @end
  return res
@end
