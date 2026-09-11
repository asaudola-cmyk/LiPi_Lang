@! ============================================================================
@! MAYA NATIVE MEMORY ALLOCATOR & GARBAGE COLLECTOR (universe/core/gc.maya)
@! 100% Written in Pure Maya Language — Zero C / Boehm GC Dependencies
@! Architecture: x86_64 Linux Anonymous Memory Slab & Large Object Allocator
@! ============================================================================

import "universe/os/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Allocator Constants & Metadata Configuration
@! ----------------------------------------------------------------------------
@fn GC_MAGIC() return 1296128321 @end             @! 0x4D415941 ("MAYA")
@fn ARENA_MAGIC() return 4706902967675712587 @end @! 0x4152454E4136344B ("ARENA64K")
@fn ARENA_SIZE() return 65536 @end                @! 64 KB per Slab Arena
@fn ARENA_HEADER_SIZE() return 64 @end            @! 64 Bytes Arena Header
@fn PAGE_SIZE() return 4096 @end                  @! 4 KB Linux Page Size
@fn HEADER_SIZE() return 16 @end                  @! 16 Bytes Object Header

@fn FLAG_ALLOCATED() return 1 @end
@fn FLAG_MARKED() return 2 @end
@fn FLAG_PTRS() return 4 @end
@fn FLAG_LARGE() return 8 @end

@fn GC_COLOR_WHITE() return 0 @end
@fn GC_COLOR_GREY() return 1 @end
@fn GC_COLOR_BLACK() return 2 @end

@fn TYPE_RAW_BYTES() return 0 @end
@fn TYPE_MAYA_STRING() return 1 @end
@fn TYPE_MAYA_ARRAY() return 2 @end
@fn TYPE_MAYA_STRUCT() return 3 @end
@fn TYPE_MAYA_CLOSURE() return 4 @end
@fn TYPE_MAYA_MAP() return 3 @end
@fn TYPE_MAYA_BOXED_FLOAT() return 6 @end

@fn GC_TRIGGER_THRESHOLD_PERCENT() return 85 @end
@fn MAX_ARENAS() return 65536 @end
@fn MAX_LARGE_CHUNKS() return 65536 @end

@! ----------------------------------------------------------------------------
@! 2. Memory Structures
@! ----------------------------------------------------------------------------
@struct SlabArena
  base: 0
  slot_size: 0
  num_slots: 0
  size_class: 0
@end

@struct LargeChunk
  map_base: 0
  total_bytes: 0
  user_size: 0
@end

@! ----------------------------------------------------------------------------
@! 3. Size Class Mapping & Helper Functions
@! ----------------------------------------------------------------------------
@fn gc_get_size_class(size)
  @if size <= 16   return 1 @end
  @if size <= 32   return 2 @end
  @if size <= 64   return 3 @end
  @if size <= 128  return 4 @end
  @if size <= 256  return 5 @end
  @if size <= 512  return 6 @end
  @if size <= 1024 return 7 @end
  @if size <= 2048 return 8 @end
  return 0 @! Large Object (> 2048B)
@end

@fn gc_get_class_payload_size(sc)
  @if sc == 1 return 16 @end
  @if sc == 2 return 32 @end
  @if sc == 3 return 64 @end
  @if sc == 4 return 128 @end
  @if sc == 5 return 256 @end
  @if sc == 6 return 512 @end
  @if sc == 7 return 1024 @end
  @if sc == 8 return 2048 @end
  return 0
@end

@fn gc_get_class_slot_size(sc)
  payload = gc_get_class_payload_size(sc)
  @if payload > 0
    return payload + HEADER_SIZE()
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. Introspection & Memory Diagnostic Helpers
@! ----------------------------------------------------------------------------

@fn gc_is_valid_pointer(ptr)
  base = gc_base(ptr)
  return base != 0 && base == ptr
@end

@fn gc_is_interior_pointer(ptr)
  base = gc_base(ptr)
  return base != 0 && base != ptr
@end

@! ----------------------------------------------------------------------------
@! 5. Core Memory Allocation Fallbacks
@! ----------------------------------------------------------------------------
@fn maya_gc_alloc(size)
  @! Call sys_mmap: Syscall 9
  prot = 3
  flags = 34
  fd = 0 - 1
  ptr = maya_syscall(9, 0, size, prot, flags, fd, 0)
  return ptr
@end

@fn maya_gc_free(ptr, size)
  @! Call sys_munmap: Syscall 11
  maya_syscall(11, ptr, size, 0, 0, 0, 0)
  return 0
@end

