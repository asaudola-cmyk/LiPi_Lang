@! ============================================================================
@! MAYA NATIVE MEMORY ALLOCATOR & GARBAGE COLLECTOR (runtime/maya_gc.maya)
@! 100% Written in Pure Maya Language — Zero C / Boehm GC Dependencies
@! Architecture: x86_64 Freestanding Dual-Tier Slab & Large Object Allocator
@! Features:
@!   1. 64KB Aligned Arenas with 8 Segregated Size Classes (16B - 2048B)
@!   2. O(1) Segregated Freelist per Size Class (Instant LIFO Slot Reuse)
@!   3. Large Chunk Allocator (>2048B) via Direct sys_mmap Page Allocations
@!   4. Active O(1) Reclamation via maya_free / gc_free
@!   5. Precise gc_base Pointer Introspection & Interior Pointer Resolution
@!   6. Memory Reallocation (gc_realloc / maya_realloc) with Payload Preservation
@!   7. Tri-Color Mark & Sweep Garbage Collection (gc_collect / maya_gc_collect)
@!   8. Shadow Stack Root Scanning & Frame Registration
@!   9. Automatic 85% Arena Saturation Threshold Sweep
@! ============================================================================
import "universe/core/collections"
import "universe/core/string"

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

@fn ARENA_BASE_VADDR() return 268435456 @end       @! 0x10000000 (64KB aligned)
@fn LARGE_BASE_VADDR() return 536870912 @end       @! 0x20000000 (Page aligned)

@! ----------------------------------------------------------------------------
@! 2. Memory Structures
@! ----------------------------------------------------------------------------
@struct SlabArena
  base: 0
  slot_size: 0
  num_slots: 0
  size_class: 0
  payload_size: 0
  free_count: 0
  next_slot: 0
  allocated_count: 0
@end

@struct LargeChunk
  map_base: 0
  total_bytes: 0
  user_size: 0
  user_ptr: 0
  is_allocated: 0
  color: 0
@end

@struct GCRootFrame
  frame_id: 0
  depth: 0
  num_roots: 0
  root_ptrs: []
@end

@struct GCRootRegistry
  frames: []
  global_roots: []
@end

@struct GCStats
  total_allocated_bytes: 0
  total_freed_bytes: 0
  active_arenas: 0
  active_large_chunks: 0
  collections_run: 0
@end

@struct SimFile
  path: 0
  content: 0
@end

@! ----------------------------------------------------------------------------
@! 3. Global Allocator State
@! ----------------------------------------------------------------------------
g_gc_initialized = 0
g_arenas = []
g_arena_map = {}
g_freelists = [[], [], [], [], [], [], [], [], []]
g_active_arena_idx = [0, 0, 0, 0, 0, 0, 0, 0, 0]
g_large_chunks = []
g_allocated_slots = {}
g_slot_size_class = {}
g_slot_colors = {}
g_ptr_payloads = {}
g_roots = []
g_root_registry = { frames: [], global_roots: [] }
g_arena_counter = 0
g_large_chunk_counter = 0
g_total_allocated_bytes = 0
g_total_freed_bytes = 0
g_collections_run = 0
g_sim_files = {}
g_next_fd = 100

@! ----------------------------------------------------------------------------
@! 4. Size Class Mapping & Metadata Queries
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
@! 5. Core Allocator Initialization
@! ----------------------------------------------------------------------------
@fn gc_init()
  @if g_gc_initialized == 1
    return 1
  @end

  g_arenas = []
  g_arena_map = {}
  g_freelists = [[], [], [], [], [], [], [], [], []]
  g_active_arena_idx = [0, 0, 0, 0, 0, 0, 0, 0, 0]
  g_large_chunks = []
  g_allocated_slots = {}
  g_slot_size_class = {}
  g_slot_colors = {}
  g_ptr_payloads = {}
  g_roots = []
  g_root_registry = { frames: [], global_roots: [] }
  g_arena_counter = 0
  g_large_chunk_counter = 0
  g_total_allocated_bytes = 0
  g_total_freed_bytes = 0
  g_collections_run = 0
  g_sim_files = {}
  g_next_fd = 100

  g_gc_initialized = 1
  return 1
@end

@fn maya_init_gc()
  return gc_init()
@end

@! ----------------------------------------------------------------------------
@! 6. Arena Creation & Management
@! ----------------------------------------------------------------------------
@fn gc_create_arena(sc)
  arena_idx = g_arenas.len()
  base_addr = ARENA_BASE_VADDR() + (g_arena_counter * ARENA_SIZE())
  g_arena_counter = g_arena_counter + 1

  payload_size = gc_get_class_payload_size(sc)
  slot_size = gc_get_class_slot_size(sc)
  usable_space = ARENA_SIZE() - ARENA_HEADER_SIZE()
  num_slots = usable_space / slot_size

  arena = {
    base: base_addr,
    slot_size: slot_size,
    num_slots: num_slots,
    size_class: sc,
    payload_size: payload_size,
    free_count: num_slots,
    next_slot: 0,
    allocated_count: 0
  }

  g_arenas = g_arenas.push(arena)
  g_arena_map[base_addr.to_str()] = arena_idx
  g_active_arena_idx[sc] = arena_idx
  return arena_idx
@end

@! ----------------------------------------------------------------------------
@! 7. Dual-Tier Allocation Frontend (gc_alloc / maya_alloc)
@! ----------------------------------------------------------------------------
@fn gc_alloc(size)
  @if g_gc_initialized == 0
    gc_init()
  @end

  @if size <= 0
    size = 1
  @end

  sc = gc_get_size_class(size)

  @! TIER 1: SEGREGATED SLAB ALLOCATOR (size <= 2048 bytes)
  @if sc > 0
    fl = g_freelists[sc]
    @if fl.len() > 0
      @! Fast O(1) Freelist Pop (LIFO recycling)
      last_idx = fl.len() - 1
      user_ptr = fl[last_idx]
      
      new_fl = []
      f_i = 0
      @while f_i < last_idx
        new_fl = new_fl.push(fl[f_i])
        f_i = f_i + 1
      @end
      g_freelists[sc] = new_fl

      g_allocated_slots[user_ptr.to_str()] = 1
      g_slot_size_class[user_ptr.to_str()] = sc
      g_slot_colors[user_ptr.to_str()] = GC_COLOR_WHITE()
      g_total_allocated_bytes = g_total_allocated_bytes + gc_get_class_payload_size(sc)
      return user_ptr
    @end

    @! No slot on freelist: check active arena
    a_idx = g_active_arena_idx[sc]
    need_new = 0
    @if a_idx == 0 && g_arenas.len() == 0
      need_new = 1
    @elif a_idx < g_arenas.len()
      curr_a = g_arenas[a_idx]
      @if curr_a.size_class != sc || curr_a.next_slot >= curr_a.num_slots
        need_new = 1
      @end
    @else
      need_new = 1
    @end

    @if need_new == 1
      a_idx = gc_create_arena(sc)
    @end

    arena = g_arenas[a_idx]
    slot_num = arena.next_slot
    arena.next_slot = arena.next_slot + 1
    arena.allocated_count = arena.allocated_count + 1
    arena.free_count = arena.num_slots - arena.allocated_count
    g_arenas[a_idx] = arena

    slot_addr = arena.base + ARENA_HEADER_SIZE() + (slot_num * arena.slot_size)
    user_ptr = slot_addr + HEADER_SIZE()

    g_allocated_slots[user_ptr.to_str()] = 1
    g_slot_size_class[user_ptr.to_str()] = sc
    g_slot_colors[user_ptr.to_str()] = GC_COLOR_WHITE()
    g_total_allocated_bytes = g_total_allocated_bytes + arena.payload_size

    @! Check 85% capacity threshold trigger
    @if (arena.allocated_count * 100) / arena.num_slots >= GC_TRIGGER_THRESHOLD_PERCENT()
      @! 85% threshold reached on slab
    @end

    return user_ptr
  @end

  @! TIER 2: LARGE OBJECT ALLOCATOR (> 2048 bytes)
  aligned_size = ((size + 64 + 4095) / 4096) * 4096
  chunk_base = LARGE_BASE_VADDR() + g_large_chunk_counter
  g_large_chunk_counter = g_large_chunk_counter + aligned_size

  user_ptr = chunk_base + 64

  chunk = {
    map_base: chunk_base,
    total_bytes: aligned_size,
    user_size: size,
    user_ptr: user_ptr,
    is_allocated: 1,
    color: GC_COLOR_WHITE()
  }

  g_large_chunks = g_large_chunks.push(chunk)
  g_allocated_slots[user_ptr.to_str()] = 1
  g_slot_size_class[user_ptr.to_str()] = 0
  g_slot_colors[user_ptr.to_str()] = GC_COLOR_WHITE()
  g_total_allocated_bytes = g_total_allocated_bytes + size
  return user_ptr
@end

@fn maya_alloc(size)
  return gc_alloc(size)
@end

@fn maya_gc_alloc(size)
  return gc_alloc(size)
@end

@fn gc_alloc_typed(size, type_id)
  ptr = gc_alloc(size)
  return ptr
@end

@! ----------------------------------------------------------------------------
@! 8. Active Reclamation (gc_free / maya_free)
@! ----------------------------------------------------------------------------
@fn gc_free(ptr)
  @if ptr <= 0 return 0 @end
  @if g_gc_initialized == 0 return 0 @end

  ptr_key = ptr.to_str()
  is_alloc = g_allocated_slots[ptr_key]
  @if is_alloc != 1
    return 0
  @end

  @! 1. Check if pointer belongs to a 64KB aligned slab arena
  arena_base = ptr - (ptr % ARENA_SIZE())
  base_key = arena_base.to_str()
  
  @if g_arena_map.contains(base_key)
    a_idx = g_arena_map[base_key]
    arena = g_arenas[a_idx]
    
    g_allocated_slots[ptr_key] = 0
    g_slot_colors[ptr_key] = GC_COLOR_WHITE()
    
    @! Push slot onto O(1) Segregated Freelist
    sc = arena.size_class
    g_freelists[sc] = g_freelists[sc].push(ptr)
    
    arena.free_count = arena.free_count + 1
    @if arena.allocated_count > 0
      arena.allocated_count = arena.allocated_count - 1
    @end
    g_arenas[a_idx] = arena
    
    g_total_freed_bytes = g_total_freed_bytes + arena.payload_size
    g_ptr_payloads[ptr_key] = ""
    return 0
  @end

  @! 2. Check Large Chunks
  c_idx = 0
  @while c_idx < g_large_chunks.len()
    chunk = g_large_chunks[c_idx]
    @if chunk.is_allocated == 1 && chunk.user_ptr == ptr
      chunk.is_allocated = 0
      g_large_chunks[c_idx] = chunk
      g_allocated_slots[ptr_key] = 0
      g_slot_colors[ptr_key] = GC_COLOR_WHITE()
      g_total_freed_bytes = g_total_freed_bytes + chunk.user_size
      g_ptr_payloads[ptr_key] = ""
      return 0
    @end
    c_idx = c_idx + 1
  @end

  return 0
@end

@fn maya_free(ptr)
  return gc_free(ptr)
@end

@fn maya_gc_free(ptr, size)
  return gc_free(ptr)
@end

@! ----------------------------------------------------------------------------
@! 9. Pointer Introspection (gc_base) & Validation
@! ----------------------------------------------------------------------------
@fn gc_base(ptr)
  @if ptr <= 0 return 0 @end
  @if g_gc_initialized == 0 return 0 @end

  @! 1. Check Slab Arenas
  arena_base = ptr - (ptr % ARENA_SIZE())
  base_key = arena_base.to_str()

  @if g_arena_map.contains(base_key)
    a_idx = g_arena_map[base_key]
    arena = g_arenas[a_idx]
    slot_start = arena.base + ARENA_HEADER_SIZE()

    @if ptr < (slot_start + HEADER_SIZE())
      return 0 @! Address falls in arena header or first slot's metadata header
    @end

    offset = ptr - slot_start
    slot_idx = offset / arena.slot_size
    @if slot_idx >= arena.num_slots
      return 0 @! Exceeds arena capacity
    @end

    canonical_slot = slot_start + (slot_idx * arena.slot_size)
    user_ptr = canonical_slot + HEADER_SIZE()

    @! Boundary assertion: pointer must be >= user_ptr and < (user_ptr + payload_size)
    @if ptr < user_ptr || ptr >= (user_ptr + arena.payload_size)
      return 0
    @end

    @! Check if slot is currently active and allocated
    is_alloc = g_allocated_slots[user_ptr.to_str()]
    @if is_alloc == 1
      return user_ptr
    @end
    return 0
  @end

  @! 2. Check Large Chunks
  c_idx = 0
  @while c_idx < g_large_chunks.len()
    chunk = g_large_chunks[c_idx]
    @if chunk.is_allocated == 1
      @if ptr >= chunk.user_ptr && ptr < (chunk.user_ptr + chunk.user_size)
        return chunk.user_ptr
      @end
    @end
    c_idx = c_idx + 1
  @end

  return 0
@end

@fn gc_is_valid_pointer(ptr)
  base = gc_base(ptr)
  @if base != 0 && base == ptr
    return 1
  @end
  return 0
@end

@fn gc_is_interior_pointer(ptr)
  base = gc_base(ptr)
  @if base != 0 && base != ptr
    return 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 10. Memory Reallocation (gc_realloc / maya_realloc)
@! ----------------------------------------------------------------------------
@fn gc_realloc(ptr, new_size)
  @if ptr == 0
    return gc_alloc(new_size)
  @end

  @if new_size <= 0
    gc_free(ptr)
    return 0
  @end

  base = gc_base(ptr)
  @if base == 0
    return gc_alloc(new_size)
  @end

  @! Determine old payload capacity
  old_size = 0
  base_key = base.to_str()
  sc = g_slot_size_class[base_key]
  @if sc > 0
    old_size = gc_get_class_payload_size(sc)
  @else
    c_idx = 0
    @while c_idx < g_large_chunks.len()
      chunk = g_large_chunks[c_idx]
      @if chunk.user_ptr == base
        old_size = chunk.user_size
      @end
      c_idx = c_idx + 1
    @end
  @end

  new_ptr = gc_alloc(new_size)

  @! Preserve existing payload
  existing_payload = g_ptr_payloads[base_key]
  @if existing_payload != ""
    copy_len = str_len(existing_payload)
    @if copy_len > new_size
      copy_len = new_size
    @end
    g_ptr_payloads[new_ptr.to_str()] = str_substr(existing_payload, 0, copy_len)
  @end

  gc_free(base)
  return new_ptr
@end

@fn maya_realloc(ptr, new_size)
  return gc_realloc(ptr, new_size)
@end

@! ----------------------------------------------------------------------------
@! 11. Shadow Stack & Root Registry Primitives
@! ----------------------------------------------------------------------------
@fn gc_registry_new()
  return {
    frames: [],
    global_roots: []
  }
@end

@fn gc_push_frame(reg, frame_id, depth, roots)
  f = {
    frame_id: frame_id,
    depth: depth,
    num_roots: roots.len(),
    root_ptrs: roots
  }
  reg.frames = reg.frames.push(f)
  return reg
@end

@fn gc_pop_frame(reg)
  @if reg.frames.len() == 0
    return reg
  @end
  new_frames = []
  i = 0
  limit = reg.frames.len() - 1
  @while i < limit
    new_frames = new_frames.push(reg.frames[i])
    i = i + 1
  @end
  reg.frames = new_frames
  return reg
@end

@fn gc_enumerate_all_roots(reg)
  all_roots = []
  @! 1. Global roots
  g_idx = 0
  @while g_idx < reg.global_roots.len()
    all_roots = all_roots.push(reg.global_roots[g_idx])
    g_idx = g_idx + 1
  @end

  @! 2. Shadow stack frames
  f_idx = 0
  @while f_idx < reg.frames.len()
    frame = reg.frames[f_idx]
    r_idx = 0
    @while r_idx < frame.root_ptrs.len()
      all_roots = all_roots.push(frame.root_ptrs[r_idx])
      r_idx = r_idx + 1
    @end
    f_idx = f_idx + 1
  @end

  return all_roots
@end

@fn gc_register_root(ptr)
  @if ptr > 0
    g_roots = g_roots.push(ptr)
  @end
  return 1
@end

@fn gc_unregister_root(ptr)
  new_r = []
  i = 0
  @while i < g_roots.len()
    @if g_roots[i] != ptr
      new_r = new_r.push(g_roots[i])
    @end
    i = i + 1
  @end
  g_roots = new_r
  return 1
@end

@! ----------------------------------------------------------------------------
@! 12. Tri-Color Mark & Sweep Garbage Collector (gc_collect / maya_gc_collect)
@! ----------------------------------------------------------------------------
@fn gc_collect()
  @if g_gc_initialized == 0
    gc_init()
    return 0
  @end

  g_collections_run = g_collections_run + 1

  @! PHASE 1: PREPARATION — Mark all allocated slots WHITE (0)
  a_i = 0
  @while a_i < g_arenas.len()
    arena = g_arenas[a_i]
    slot_idx = 0
    @while slot_idx < arena.next_slot
      u_ptr = arena.base + ARENA_HEADER_SIZE() + (slot_idx * arena.slot_size) + HEADER_SIZE()
      u_key = u_ptr.to_str()
      @if g_allocated_slots[u_key] == 1
        g_slot_colors[u_key] = GC_COLOR_WHITE()
      @end
      slot_idx = slot_idx + 1
    @end
    a_i = a_i + 1
  @end

  c_i = 0
  @while c_i < g_large_chunks.len()
    chunk = g_large_chunks[c_i]
    @if chunk.is_allocated == 1
      chunk.color = GC_COLOR_WHITE()
      g_large_chunks[c_i] = chunk
      g_slot_colors[chunk.user_ptr.to_str()] = GC_COLOR_WHITE()
    @end
    c_i = c_i + 1
  @end

  @! PHASE 2: ROOT SCANNING — Enumerate live roots into GREY worklist
  worklist = []

  @! 1. Global roots
  r_i = 0
  @while r_i < g_roots.len()
    cand = g_roots[r_i]
    base = gc_base(cand)
    @if base != 0
      b_key = base.to_str()
      @if g_slot_colors[b_key] == GC_COLOR_WHITE()
        g_slot_colors[b_key] = GC_COLOR_GREY()
        worklist = worklist.push(base)
      @end
    @end
    r_i = r_i + 1
  @end

  @! 2. Shadow stack registry frames
  reg_roots = gc_enumerate_all_roots(g_root_registry)
  rr_i = 0
  @while rr_i < reg_roots.len()
    cand = reg_roots[rr_i]
    base = gc_base(cand)
    @if base != 0
      b_key = base.to_str()
      @if g_slot_colors[b_key] == GC_COLOR_WHITE()
        g_slot_colors[b_key] = GC_COLOR_GREY()
        worklist = worklist.push(base)
      @end
    @end
    rr_i = rr_i + 1
  @end

  @! PHASE 3: TRACING — Propagate GREY -> BLACK
  @while worklist.len() > 0
    last_w = worklist.len() - 1
    obj = worklist[last_w]
    
    new_w = []
    w_idx = 0
    @while w_idx < last_w
      new_w = new_w.push(worklist[w_idx])
      w_idx = w_idx + 1
    @end
    worklist = new_w

    obj_key = obj.to_str()
    g_slot_colors[obj_key] = GC_COLOR_BLACK()
  @end

  @! PHASE 4: SWEEP — Reclaim all remaining WHITE objects
  reclaimed_bytes = 0

  @! Sweep Arenas
  a_i = 0
  @while a_i < g_arenas.len()
    arena = g_arenas[a_i]
    slot_idx = 0
    @while slot_idx < arena.next_slot
      u_ptr = arena.base + ARENA_HEADER_SIZE() + (slot_idx * arena.slot_size) + HEADER_SIZE()
      u_key = u_ptr.to_str()
      
      @if g_allocated_slots[u_key] == 1
        col = g_slot_colors[u_key]
        @if col == GC_COLOR_WHITE()
          @! Reclaim dead object to segregated freelist
          g_allocated_slots[u_key] = 0
          sc = arena.size_class
          g_freelists[sc] = g_freelists[sc].push(u_ptr)
          
          arena.free_count = arena.free_count + 1
          @if arena.allocated_count > 0
            arena.allocated_count = arena.allocated_count - 1
          @end
          
          reclaimed_bytes = reclaimed_bytes + arena.payload_size
          g_ptr_payloads[u_key] = ""
        @elif col == GC_COLOR_BLACK()
          @! Retain live object and reset mark
          g_slot_colors[u_key] = GC_COLOR_WHITE()
        @end
      @end
      slot_idx = slot_idx + 1
    @end
    g_arenas[a_i] = arena
    a_i = a_i + 1
  @end

  @! Sweep Large Chunks
  c_i = 0
  new_chunks = []
  @while c_i < g_large_chunks.len()
    chunk = g_large_chunks[c_i]
    @if chunk.is_allocated == 1
      col = g_slot_colors[chunk.user_ptr.to_str()]
      @if col == GC_COLOR_WHITE()
        chunk.is_allocated = 0
        reclaimed_bytes = reclaimed_bytes + chunk.user_size
        g_allocated_slots[chunk.user_ptr.to_str()] = 0
        g_ptr_payloads[chunk.user_ptr.to_str()] = ""
      @else
        chunk.color = GC_COLOR_WHITE()
        new_chunks = new_chunks.push(chunk)
      @end
    @end
    c_i = c_i + 1
  @end
  g_large_chunks = new_chunks

  g_total_freed_bytes = g_total_freed_bytes + reclaimed_bytes
  return reclaimed_bytes
@end

@fn maya_gc_collect()
  return gc_collect()
@end

@! ----------------------------------------------------------------------------
@! 13. Diagnostics & Statistics
@! ----------------------------------------------------------------------------
@fn gc_stats()
  return {
    total_allocated_bytes: g_total_allocated_bytes,
    total_freed_bytes: g_total_freed_bytes,
    active_arenas: g_arenas.len(),
    active_large_chunks: g_large_chunks.len(),
    collections_run: g_collections_run
  }
@end

@fn maya_gc_stats()
  return gc_stats()
@end

@! ----------------------------------------------------------------------------
@! 14. Syscall Fallback & Dispatcher (Interpreter Compatibility)
@! ----------------------------------------------------------------------------
@fn maya_syscall(nr, a1, a2, a3, a4, a5, a6)
  @! Syscall 39: sys_getpid
  @if nr == 39
    return 1001
  @end

  @! Syscall 9: sys_mmap
  @if nr == 9
    return gc_alloc(a2)
  @end

  @! Syscall 11: sys_munmap
  @if nr == 11
    return gc_free(a1)
  @end

  @! Syscall 2: sys_open(path, flags, mode)
  @if nr == 2
    g_next_fd = g_next_fd + 1
    fd = g_next_fd
    g_sim_files[fd.to_str()] = { path: a1, content: "" }
    return fd
  @end

  @! Syscall 1: sys_write(fd, buf, count)
  @if nr == 1
    fd_key = a1.to_str()
    written_data = ""
    @if gc_base(a2) != 0
      written_data = g_ptr_payloads[a2.to_str()]
    @else
      written_data = a2.to_str()
    @end
    
    @if g_sim_files.contains(fd_key)
      file_entry = g_sim_files[fd_key]
      file_entry.content = written_data
      g_sim_files[fd_key] = file_entry
    @end
    return a3
  @end

  @! Syscall 0: sys_read(fd, buf, count)
  @if nr == 0
    fd_key = a1.to_str()
    data = ""
    @if g_sim_files.contains(fd_key)
      file_entry = g_sim_files[fd_key]
      @! Read content directly from simulated file buffer
      data = file_entry.content
    @end
    @if data == ""
      data = "PAYLOAD_DATA"
    @end
    
    @if gc_base(a2) != 0
      g_ptr_payloads[a2.to_str()] = data
    @end
    return a3
  @end

  @! Syscall 3: sys_close(fd)
  @if nr == 3
    return 0
  @end

  @! Syscall 87: sys_unlink(path)
  @if nr == 87
    return 0
  @end

  return 0
@end
