@! ==================================================================
@! MAYA UNIVERSE - Core Memory Library
@! ==================================================================

@! Returns the fixed address of the global heap: 0x4000000000 (274877906944)
@fn heap_global()
  return 274877906944
@end

@! Initializes a 1GB heap at the fixed global address
@fn heap_init()
  heap = heap_global()
  size = 1073741824 @! 1 GB
  @! MAP_PRIVATE (2) | MAP_ANONYMOUS (32) | MAP_FIXED (16) = 50
  res = sys_mmap(heap, size, 3, 50, -1, 0)
  
  @if res != heap
    println("Fatal: Failed to initialize global heap!")
    sys_exit(1)
  @end
  
  @! Initialize the first free block
  @! Header: size (negative means free), next (0)
  sys_poke(heap + 0, 0 - (size - 16))
  sys_poke(heap + 8, 0)
  return 0
@end

@! Allocates memory from the global heap
@fn malloc(size)
  @! Align to 8 bytes
  rem = size - ((size / 8) * 8)
  @if rem != 0 size = size + (8 - rem) @end
  
  curr = heap_global()
  
  @while curr != 0
    curr_size = sys_peek(curr + 0)
    is_free = 0
    @if curr_size < 0
      is_free = 1
      curr_size = 0 - curr_size
    @end
    
    @if is_free == 1
      @if curr_size >= size
        @! We found a suitable block! Can we split it?
        remaining = curr_size - size
        @if remaining >= 32
          @! Split the block
          new_block = curr + 16 + size
          sys_poke(new_block + 0, 0 - (remaining - 16))
          sys_poke(new_block + 8, sys_peek(curr + 8))
          
          sys_poke(curr + 0, size)
          sys_poke(curr + 8, new_block)
          return curr + 16
        @else
          @! Just use the whole block
          sys_poke(curr + 0, curr_size)
          return curr + 16
        @end
      @end
    @end
    curr = sys_peek(curr + 8)
  @end
  
  println("Fatal: Out of memory!")
  sys_exit(1)
  return 0
@end

@! Frees memory back to the global heap
@fn free(ptr)
  @if ptr == 0 return 0 @end
  header = ptr - 16
  size = sys_peek(header + 0)
  @if size > 0
    sys_poke(header + 0, 0 - size)
  @end
  return 0
@end
