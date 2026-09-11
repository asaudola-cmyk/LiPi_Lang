@! ============================================================================
@! LIPI UNIVERSE DB — LRU BUFFER POOL & PAGE CACHE (universe/db/buffer.maya)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Complete Sovereign Linux x86-64 Native Syscalls (sys_open, sys_lseek, sys_read, sys_write, sys_fsync)
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"
import "universe/db/page"

@! ----------------------------------------------------------------------------
@! 1. Constants
@! ----------------------------------------------------------------------------
@fn PAGE_SIZE() return 4096 @end
@fn PAGE_HEADER_SIZE() return 32 @end
@fn DEFAULT_CAPACITY() return 64 @end
@fn DB_MAGIC() return 0x4D415941 @end  @! ASCII "MAYA" (1296128321)
@fn DB_VERSION() return 1 @end

@! ----------------------------------------------------------------------------
@! 2. Data Structures
@! ----------------------------------------------------------------------------

@struct PageTableEntry
  pte_page_id: i64
  pte_frame_id: i64
@end

@struct PageFrame
  frame_id: i64
  page_id: i64
  dirty: i64
  pin_count: i64
  buffer: array
  prev_lru: i64
  next_lru: i64
  access_count: i64
@end

@struct BufferPool
  fd: i64
  file_path: string
  capacity: i64
  total_pages: i64
  root_page_id: i64
  free_page_head: i64
  frames: array
  page_table: array
  table_size: i64
  free_frames: array
  lru_head: i64
  lru_tail: i64
  stats_hits: i64
  stats_misses: i64
  stats_evictions: i64
  stats_flushes: i64
@end

@! ----------------------------------------------------------------------------
@! 3. Page Table (Hash Map with Separate Chaining)
@! ----------------------------------------------------------------------------

@fn page_table_init(table_size)
  table = []
  i = 0
  @while i < table_size
    table = table.push([])
    i = i + 1
  @end
  return table
@end

@fn page_table_hash(page_id, table_size)
  h = (page_id * 2654435761) & 2147483647
  return h % table_size
@end

@fn page_table_lookup(pool, page_id)
  idx = page_table_hash(page_id, pool.table_size)
  bucket = pool.page_table[idx]
  i = 0
  num_items = bucket.len()
  @while i < num_items
    entry = bucket[i]
    @if entry.pte_page_id == page_id
      return entry.pte_frame_id
    @end
    i = i + 1
  @end
  return 0 - 1
@end

@fn page_table_insert(pool, page_id, frame_id)
  idx = page_table_hash(page_id, pool.table_size)
  bucket = pool.page_table[idx]
  i = 0
  num_items = bucket.len()
  found = 0
  @while i < num_items
    entry = bucket[i]
    @if entry.pte_page_id == page_id
      entry.pte_frame_id = frame_id
      found = 1
      break
    @end
    i = i + 1
  @end
  @if found == 0
    pool.page_table[idx] = pool.page_table[idx].push({ pte_page_id: page_id, pte_frame_id: frame_id })
  @end
  return 1
@end

@fn page_table_remove(pool, page_id)
  idx = page_table_hash(page_id, pool.table_size)
  bucket = pool.page_table[idx]
  new_bucket = []
  i = 0
  num_items = bucket.len()
  @while i < num_items
    entry = bucket[i]
    @if entry.pte_page_id != page_id
      new_bucket = new_bucket.push(entry)
    @end
    i = i + 1
  @end
  pool.page_table[idx] = new_bucket
  return 1
@end

@! ----------------------------------------------------------------------------
@! 4. LRU Doubly-Linked List Eviction Management
@! ----------------------------------------------------------------------------

@fn lru_remove(pool, frame_id)
  frame = pool.frames[frame_id]
  @if frame.prev_lru == (0 - 1) && frame.next_lru == (0 - 1) && pool.lru_head != frame_id && pool.lru_tail != frame_id
    return 0
  @end

  @if frame.prev_lru != (0 - 1)
    pool.frames[frame.prev_lru].next_lru = frame.next_lru
  @else
    pool.lru_head = frame.next_lru
  @end

  @if frame.next_lru != (0 - 1)
    pool.frames[frame.next_lru].prev_lru = frame.prev_lru
  @else
    pool.lru_tail = frame.prev_lru
  @end

  frame.prev_lru = 0 - 1
  frame.next_lru = 0 - 1
  return 1
@end

@fn lru_push_front(pool, frame_id)
  lru_remove(pool, frame_id)
  frame = pool.frames[frame_id]
  frame.prev_lru = 0 - 1
  frame.next_lru = pool.lru_head

  @if pool.lru_head != (0 - 1)
    pool.frames[pool.lru_head].prev_lru = frame_id
  @end
  pool.lru_head = frame_id

  @if pool.lru_tail == (0 - 1)
    pool.lru_tail = frame_id
  @end
  return 1
@end

@fn lru_find_victim(pool)
  curr = pool.lru_tail
  @while curr != (0 - 1)
    frame = pool.frames[curr]
    @if frame.pin_count == 0
      return curr
    @end
    curr = frame.prev_lru
  @end
  return 0 - 1
@end

@! ----------------------------------------------------------------------------
@! 5. Page 0 Database Header Serialization
@! ----------------------------------------------------------------------------

@fn bp_write_page_0(pool)
  p0_buf = page_new()
  page_write_u32(p0_buf, 0, DB_MAGIC())
  page_write_u32(p0_buf, 4, DB_VERSION())
  page_write_u32(p0_buf, 8, PAGE_SIZE())
  page_write_u64(p0_buf, 12, pool.total_pages)
  page_write_u64(p0_buf, 20, pool.root_page_id)
  page_write_u64(p0_buf, 28, pool.free_page_head)
  page_write_u64(p0_buf, 36, 0)
  page_write_u64(p0_buf, 44, clock_ms())

  sys_lseek(pool.fd, 0, 0)
  sys_write(pool.fd, page_data_ptr(p0_buf), 4096)
  pool.stats_flushes = pool.stats_flushes + 1
  return 1
@end

@fn bp_read_page_0(pool)
  p0_buf = page_new()
  sys_lseek(pool.fd, 0, 0)
  bytes = page_read_from_fd(pool.fd, p0_buf)
  @if bytes < 4096
    return 0
  @end

  magic = page_read_u32(p0_buf, 0)
  @if magic != DB_MAGIC()
    return 0
  @end

  pool.total_pages = page_read_u64(p0_buf, 12)
  pool.root_page_id = page_read_u64(p0_buf, 20)
  pool.free_page_head = page_read_u64(p0_buf, 28)
  return 1
@end

@! ----------------------------------------------------------------------------
@! 6. Public Buffer Pool API Operations
@! ----------------------------------------------------------------------------

@! Opens or creates a database file and initializes the LRU Buffer Pool
@fn buffer_pool_open(file_path, capacity)
  @if capacity <= 0
    capacity = DEFAULT_CAPACITY()
  @end

  @! O_RDWR (2) | O_CREAT (64) = 66, mode 0644 = 420
  fd = sys_open(file_path, 66, 420)
  @if fd < 0
    println("  [BufferPool] Error opening file: " + file_path)
    return {
      fd: 0 - 1,
      file_path: file_path,
      capacity: capacity,
      total_pages: 0,
      root_page_id: 1,
      free_page_head: 0,
      frames: [],
      page_table: [],
      table_size: 0,
      free_frames: [],
      lru_head: 0 - 1,
      lru_tail: 0 - 1,
      stats_hits: 0,
      stats_misses: 0,
      stats_evictions: 0,
      stats_flushes: 0
    }
  @end

  table_size = (capacity * 2) + 1
  page_table = page_table_init(table_size)

  frames = []
  free_frames = []
  i = 0
  @while i < capacity
    frame_buf = page_new()
    frame = {
      frame_id: i,
      page_id: 0 - 1,
      dirty: 0,
      pin_count: 0,
      buffer: frame_buf,
      prev_lru: 0 - 1,
      next_lru: 0 - 1,
      access_count: 0
    }
    frames = frames.push(frame)
    free_frames = free_frames.push(i)
    i = i + 1
  @end

  pool = {
    fd: fd,
    file_path: file_path,
    capacity: capacity,
    total_pages: 2,
    root_page_id: 1,
    free_page_head: 0,
    frames: frames,
    page_table: page_table,
    table_size: table_size,
    free_frames: free_frames,
    lru_head: 0 - 1,
    lru_tail: 0 - 1,
    stats_hits: 0,
    stats_misses: 0,
    stats_evictions: 0,
    stats_flushes: 0
  }

  file_size = sys_lseek(fd, 0, 2)  @! SEEK_END = 2
  @if file_size < 4096
    @! Initialize Page 0 (DB Metadata) and Page 1 (Initial B+Tree Leaf Root)
    pool.total_pages = 2
    pool.root_page_id = 1
    bp_write_page_0(pool)

    @! Format and write empty leaf Page 1
    p1_buf = page_new()
    page_format_leaf(p1_buf, 1, 0, 0)
    sys_lseek(fd, 4096, 0)
    sys_write(fd, page_data_ptr(p1_buf), 4096)
    sys_fsync(fd)
  @else
    bp_read_page_0(pool)
  @end

  return pool
@end

@! Alias conforming to PROJECT.md
@fn buffer_pool_new(file_path, capacity)
  return buffer_pool_open(file_path, capacity)
@end

@! Fetches a page by ID (returns memory buffer, pinned with pin_count + 1)
@fn buffer_pool_fetch_page(pool, page_id)
  frame_id = page_table_lookup(pool, page_id)

  @! Cache Hit
  @if frame_id != (0 - 1)
    frame = pool.frames[frame_id]
    frame.pin_count = frame.pin_count + 1
    frame.access_count = frame.access_count + 1
    lru_push_front(pool, frame_id)
    pool.stats_hits = pool.stats_hits + 1
    return frame.buffer
  @end

  @! Cache Miss
  pool.stats_misses = pool.stats_misses + 1
  target_frame_id = 0 - 1

  @if pool.free_frames.len() > 0
    target_frame_id = pool.free_frames[pool.free_frames.len() - 1]
    new_free = []
    i = 0
    @while i < pool.free_frames.len() - 1
      new_free = new_free.push(pool.free_frames[i])
      i = i + 1
    @end
    pool.free_frames = new_free
  @else
    target_frame_id = lru_find_victim(pool)
    @if target_frame_id == (0 - 1)
      println("  [BufferPool] FATAL: All page frames pinned! Cannot evict victim.")
      return page_new()
    @end

    victim = pool.frames[target_frame_id]
    @if victim.dirty == 1
      sys_lseek(pool.fd, victim.page_id * 4096, 0)
      sys_write(pool.fd, page_data_ptr(victim.buffer), 4096)
      victim.dirty = 0
      pool.stats_flushes = pool.stats_flushes + 1
    @end

    page_table_remove(pool, victim.page_id)
    pool.stats_evictions = pool.stats_evictions + 1
  @end

  frame = pool.frames[target_frame_id]
  sys_lseek(pool.fd, page_id * 4096, 0)
  bytes_read = page_read_from_fd(pool.fd, frame.buffer)
  @if bytes_read < 4096
    @! Zero remainder of page buffer if file read was shorter than 4KB
    j = bytes_read
    @while j < 4096
      frame.buffer[j] = 0
      j = j + 1
    @end
  @end

  frame.page_id = page_id
  frame.dirty = 0
  frame.pin_count = 1
  frame.access_count = frame.access_count + 1

  page_table_insert(pool, page_id, target_frame_id)
  lru_push_front(pool, target_frame_id)

  return frame.buffer
@end

@! Alias conforming to PROJECT.md
@fn buffer_pool_get_page(pool, page_id)
  return buffer_pool_fetch_page(pool, page_id)
@end

@! Allocates a new page on disk and returns { page_id, buffer, page_buf }
@fn buffer_pool_allocate_page(pool)
  new_page_id = pool.total_pages
  pool.total_pages = pool.total_pages + 1

  target_frame_id = 0 - 1
  @if pool.free_frames.len() > 0
    target_frame_id = pool.free_frames[pool.free_frames.len() - 1]
    new_free = []
    i = 0
    @while i < pool.free_frames.len() - 1
      new_free = new_free.push(pool.free_frames[i])
      i = i + 1
    @end
    pool.free_frames = new_free
  @else
    target_frame_id = lru_find_victim(pool)
    @if target_frame_id == (0 - 1)
      println("  [BufferPool] FATAL: All page frames pinned! Cannot allocate page.")
      return { page_id: 0 - 1, buffer: page_new(), page_buf: page_new() }
    @end

    victim = pool.frames[target_frame_id]
    @if victim.dirty == 1
      sys_lseek(pool.fd, victim.page_id * 4096, 0)
      sys_write(pool.fd, page_data_ptr(victim.buffer), 4096)
      victim.dirty = 0
      pool.stats_flushes = pool.stats_flushes + 1
    @end

    page_table_remove(pool, victim.page_id)
    pool.stats_evictions = pool.stats_evictions + 1
  @end

  frame = pool.frames[target_frame_id]
  @! Zero the new page frame buffer
  j = 0
  @while j < 4096
    frame.buffer[j] = 0
    j = j + 1
  @end

  frame.page_id = new_page_id
  frame.dirty = 1
  frame.pin_count = 1
  frame.access_count = 1
  page_write_u64(frame.buffer, 0, new_page_id)

  page_table_insert(pool, new_page_id, target_frame_id)
  lru_push_front(pool, target_frame_id)

  @! Update Page 0 on disk
  bp_write_page_0(pool)

  return {
    page_id: new_page_id,
    buffer: frame.buffer,
    page_buf: frame.buffer
  }
@end

@! Alias conforming to PROJECT.md
@fn buffer_pool_new_page(pool)
  return buffer_pool_allocate_page(pool)
@end

@! Unpins a page and updates dirty flag
@fn buffer_pool_unpin_page(pool, page_id, is_dirty)
  frame_id = page_table_lookup(pool, page_id)
  @if frame_id == (0 - 1)
    return 0
  @end

  frame = pool.frames[frame_id]
  @if is_dirty == 1
    frame.dirty = 1
  @end

  @if frame.pin_count > 0
    frame.pin_count = frame.pin_count - 1
  @end

  lru_push_front(pool, frame_id)
  return 1
@end

@! Alias conforming to PROJECT.md
@fn buffer_pool_unpin(pool, page_id)
  return buffer_pool_unpin_page(pool, page_id, 0)
@end

@! Marks an in-memory page frame as dirty
@fn buffer_pool_mark_dirty(pool, page_id)
  frame_id = page_table_lookup(pool, page_id)
  @if frame_id != (0 - 1)
    pool.frames[frame_id].dirty = 1
    return 1
  @end
@end

@! Flushes a specific page to disk if dirty
@fn buffer_pool_flush_page(pool, page_id)
  frame_id = page_table_lookup(pool, page_id)
  @if frame_id == (0 - 1)
    return 0
  @end

  frame = pool.frames[frame_id]
  @if frame.dirty == 1
    sys_lseek(pool.fd, page_id * 4096, 0)
    sys_write(pool.fd, page_data_ptr(frame.buffer), 4096)
    frame.dirty = 0
    pool.stats_flushes = pool.stats_flushes + 1
    return 1
  @end
  return 0
@end

@! Flushes all dirty frames to disk and calls sys_fsync
@fn buffer_pool_flush_all(pool: BufferPool)
  flushed = 0
  i = 0
  @while i < pool.capacity
    frame: PageFrame = pool.frames[i]
    @if frame.page_id != (0 - 1) && frame.dirty == 1
      sys_lseek(pool.fd, frame.page_id * 4096, 0)
      sys_write(pool.fd, page_data_ptr(frame.buffer), 4096)
      frame.dirty = 0
      flushed = flushed + 1
      pool.stats_flushes = pool.stats_flushes + 1
    @end
    i = i + 1
  @end

  bp_write_page_0(pool)
  sys_fsync(pool.fd)
  return flushed
@end

@! Flushes all data and closes the database file descriptor
@fn buffer_pool_close(pool: BufferPool)
  @if pool.fd >= 0
    buffer_pool_flush_all(pool)
    sys_close(pool.fd)
    pool.fd = 0 - 1
  @end
  return 1
@end

@! Diagnostics
@fn buffer_pool_get_stats(pool)
  return {
    hits: pool.stats_hits,
    misses: pool.stats_misses,
    evictions: pool.stats_evictions,
    flushes: pool.stats_flushes,
    total_pages: pool.total_pages,
    capacity: pool.capacity
  }
@end
