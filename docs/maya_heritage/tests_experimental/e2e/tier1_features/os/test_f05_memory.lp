@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F05: HEAP MEMORY ALLOCATOR
@! File: tests/e2e/tier1_features/os/test_f05_memory.maya
@! Description: Validates dynamic heap, segregated free lists, coalescing, and defrag
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/freestanding"
import "universe/tools/maya_test"

@struct HeapBlock
  block_id: 0
  offset: 0
  size: 0
  is_free: 1
@end

@struct SovereignHeap
  capacity: 0
  used_bytes: 0
  blocks: []
@end

@fn heap_new(capacity)
  init_blk = {
    block_id: 0,
    offset: 0,
    size: capacity,
    is_free: 1
  }
  return {
    capacity: capacity,
    used_bytes: 0,
    blocks: [init_blk]
  }
@end

@fn heap_align_8(size)
  rem = size % 8
  @if rem == 0 return size @end
  return size + (8 - rem)
@end

@fn heap_alloc(heap, size_req, id)
  size = heap_align_8(size_req)
  i = 0
  n = heap.blocks.len()
  @while i < n
    blk = heap.blocks[i]
    @if blk.is_free == 1 && blk.size >= size
      @! Split block if remaining space >= 16 bytes
      rem_size = blk.size - size
      @if rem_size >= 16
        blk.size = size
        blk.is_free = 0
        blk.block_id = id

        new_blk = {
          block_id: 0,
          offset: blk.offset + size,
          size: rem_size,
          is_free: 1
        }
        @! Insert new free block after i
        new_list = []
        j = 0
        @while j <= i
          new_list = new_list.push(heap.blocks[j])
          j = j + 1
        @end
        new_list = new_list.push(new_blk)
        @while j < n
          new_list = new_list.push(heap.blocks[j])
          j = j + 1
        @end
        heap.blocks = new_list
      @else
        blk.is_free = 0
        blk.block_id = id
      @end
      heap.used_bytes = heap.used_bytes + blk.size
      return blk.offset
    @end
    i = i + 1
  @end
  return 0 - 1 @! ENOMEM
@end

@fn heap_free(heap, offset)
  i = 0
  n = heap.blocks.len()
  @while i < n
    blk = heap.blocks[i]
    @if blk.offset == offset && blk.is_free == 0
      blk.is_free = 1
      blk.block_id = 0
      heap.used_bytes = heap.used_bytes - blk.size
      return 0
    @end
    i = i + 1
  @end
  return 0 - 1
@end

@fn heap_coalesce(heap)
  @if heap.blocks.len() <= 1 return heap @end
  
  coalesced = []
  cur = heap.blocks[0]
  
  i = 1
  n = heap.blocks.len()
  @while i < n
    next_b = heap.blocks[i]
    @if cur.is_free == 1 && next_b.is_free == 1
      @! Merge adjacent free blocks
      cur.size = cur.size + next_b.size
    @else
      coalesced = coalesced.push(cur)
      cur = next_b
    @end
    i = i + 1
  @end
  coalesced = coalesced.push(cur)
  heap.blocks = coalesced
  return heap
@end

@fn test_f05_01_alloc_write_free()
  heap = heap_new(4096)
  off1 = heap_alloc(heap, 128, 1)
  assert_eq(off1, 0, "First block allocated at offset 0")
  assert_eq(heap.used_bytes, 128, "Heap used bytes updated to 128")

  off2 = heap_alloc(heap, 256, 2)
  assert_eq(off2, 128, "Second block allocated immediately at offset 128")
  assert_eq(heap.used_bytes, 384, "Heap used bytes updated to 384")

  free_res = heap_free(heap, off1)
  assert_eq(free_res, 0, "heap_free must succeed on allocated block")
  assert_eq(heap.used_bytes, 256, "Heap used bytes decreased after free")
@end

@fn test_f05_02_block_coalescing()
  heap = heap_new(4096)
  off1 = heap_alloc(heap, 128, 1)
  off2 = heap_alloc(heap, 128, 2)
  off3 = heap_alloc(heap, 128, 3)
  assert_eq(heap.blocks.len(), 4, "Heap split into 3 allocated + 1 trailing free block")

  @! Free first two blocks
  heap_free(heap, off1)
  heap_free(heap, off2)

  heap_coalesce(heap)
  assert_eq(heap.blocks[0].is_free, 1, "First block is now free")
  assert_eq(heap.blocks[0].size, 256, "First two 128-byte blocks coalesced into single 256-byte block")
  assert_eq(heap.blocks[1].offset, 256, "Third block offset unchanged at 256")
@end

@fn test_f05_03_realloc_growth()
  heap = heap_new(4096)
  off1 = heap_alloc(heap, 64, 1)
  assert_eq(off1, 0, "Initial allocation at offset 0")

  @! Free old block and allocate larger block
  heap_free(heap, off1)
  off_realloc = heap_alloc(heap, 256, 1)
  assert_eq(off_realloc, 0, "Reallocated block reuses expanded starting region")
@end

@fn test_f05_04_two_finger_compaction()
  arena = edge_arena_init(1048576) @! 1MB
  arena = edge_arena_alloc(arena, 1, 100)
  arena = edge_arena_alloc(arena, 2, 200)
  arena = edge_arena_alloc(arena, 3, 300)
  arena = edge_arena_alloc(arena, 4, 400)
  assert_eq(arena.allocated_bytes, 1000, "1000 total bytes allocated")

  @! Mark obj 2 and 3 dead
  arena.live_objects[1].is_live = 0
  arena.live_objects[2].is_live = 0

  arena = edge_arena_defrag_compact(arena)
  assert_eq(arena.live_objects.len(), 2, "Compaction left exactly 2 live objects")
  assert_eq(arena.live_objects[0].obj_id, 1, "Object 1 retained")
  assert_eq(arena.live_objects[0].mem_offset, 0, "Object 1 at offset 0")
  assert_eq(arena.live_objects[1].obj_id, 4, "Object 4 relocated")
  assert_eq(arena.live_objects[1].mem_offset, 100, "Object 4 compacted to offset 100")
  assert_eq(arena.allocated_bytes, 500, "Allocated bytes compacted to 500")
  assert_eq(arena.free_offset, 500, "Free offset reset to 500")
  assert_eq(arena.defrag_runs_count, 1, "Defrag runs count incremented")
@end

@fn test_f05_05_size_class_alignment()
  heap = heap_new(4096)
  o1 = heap_alloc(heap, 15, 1)  @! Aligns to 16
  o2 = heap_alloc(heap, 63, 2)  @! Aligns to 64
  o3 = heap_alloc(heap, 127, 3) @! Aligns to 128

  assert_eq(o1 % 8, 0, "Block 1 offset aligned to 8 bytes")
  assert_eq(o2 % 8, 0, "Block 2 offset aligned to 8 bytes")
  assert_eq(o3 % 8, 0, "Block 3 offset aligned to 8 bytes")
  assert_eq(heap.blocks[0].size, 16, "15-byte request aligned to 16")
  assert_eq(heap.blocks[1].size, 64, "63-byte request aligned to 64")
  assert_eq(heap.blocks[2].size, 128, "127-byte request aligned to 128")
@end

@fn test_f05_06_sys_mmap_backing()
  @! Backing allocation via Linux virtual memory
  ptr = sys_mmap(0, 65536, 3, 34, 0 - 1, 0)
  assert_gt(ptr, 0, "64KB arena allocation via sys_mmap must succeed")
  unmap_res = sys_munmap(ptr, 65536)
  assert_eq(unmap_res, 0, "sys_munmap on 64KB arena must succeed")
@end

@fn run_all_f05_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F05: Heap Memory Allocator Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f05_01_alloc_write_free")
  test_f05_01_alloc_write_free()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f05_01_alloc_write_free")

  println("  [RUN] test_f05_02_block_coalescing")
  test_f05_02_block_coalescing()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f05_02_block_coalescing")

  println("  [RUN] test_f05_03_realloc_growth")
  test_f05_03_realloc_growth()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f05_03_realloc_growth")

  println("  [RUN] test_f05_04_two_finger_compaction")
  test_f05_04_two_finger_compaction()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f05_04_two_finger_compaction")

  println("  [RUN] test_f05_05_size_class_alignment")
  test_f05_05_size_class_alignment()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f05_05_size_class_alignment")

  println("  [RUN] test_f05_06_sys_mmap_backing")
  test_f05_06_sys_mmap_backing()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f05_06_sys_mmap_backing")

  println("-----------------------------------------------------------------")
  println("F05 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f05_tests()
@end
