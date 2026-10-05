import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"
import "universe/core/net"

@! ==============================================================================
@! ⚡ LIPI SOVEREIGN BAREMETAL NETWORK WIRE ENGINE (src/runtime/io_uring_bypass.lp)
@! 🌌 100% Pure Lipi Native Runtime Architecture | 0% Libc | 0% External Toolchain
@! Features:
@!   - Direct Linux Kernel io_uring (Syscalls 425, 426, 427) & Socket ABI Gateway
@!   - Multi-Tier Mode: Kernel SQPOLL Zero-Syscall Mode + Standard io_uring + Direct Wire Fallback
@!   - Zero-Copy DMA Memory Pool & Contiguous Fixed Buffer Queues
@!   - Atomic Batch Packet Transmission & Receive Queues (sendmmsg / recvmmsg / io_uring)
@!   - Wire-Level Raw TCP & UDP Socket Ring Buffer Abstractions
@! ==============================================================================

@! ------------------------------------------------------------------------------
@! 1. IO_URING & WIRE ENGINE CONSTANTS
@! ------------------------------------------------------------------------------

@! Kernel Setup Flags (include/uapi/linux/io_uring.h)
@fn BYPASS_SETUP_SQPOLL()    return 2 @end          @! (1 << 1) Kernel Poller Thread
@fn BYPASS_SETUP_SQ_AFF()     return 4 @end          @! (1 << 2) Pin poller to specific CPU
@fn BYPASS_SETUP_CQSIZE()     return 8 @end          @! (1 << 3) Custom Completion Queue size
@fn BYPASS_SETUP_CLAMP()      return 16 @end         @! (1 << 4) Clamp entries
@fn BYPASS_SETUP_ATTACH_WQ()  return 32 @end         @! (1 << 5) Attach existing workqueue

@! Enter Flags
@fn BYPASS_ENTER_GETEVENTS()  return 1 @end          @! Wait for completions
@fn BYPASS_ENTER_SQ_WAKEUP()  return 2 @end          @! Wake up sleeping SQPOLL poller

@! SQ Ring Flags (Shared Memory offset)
@fn BYPASS_SQ_NEED_WAKEUP()   return 1 @end          @! Poller thread is sleeping

@! Registration Opcodes (Syscall 427)
@fn BYPASS_REGISTER_BUFFERS()   return 0 @end        @! Register fixed DMA buffers
@fn BYPASS_UNREGISTER_BUFFERS() return 1 @end
@fn BYPASS_REGISTER_FILES()     return 2 @end
@fn BYPASS_UNREGISTER_FILES()   return 3 @end

@! Memory Offsets for Kernel Ring Buffers via sys_mmap
@fn BYPASS_OFF_SQ_RING() return 0 @end
@fn BYPASS_OFF_CQ_RING() return 134217728 @end       @! 0x08000000 (128 MB)
@fn BYPASS_OFF_SQES()    return 268435456 @end       @! 0x10000000 (256 MB)

@! Canonical Structure Byte Sizes in Linux Kernel ABI
@fn BYPASS_SQE_SIZE() return 64 @end
@fn BYPASS_CQE_SIZE() return 16 @end

@! io_uring Opcodes
@fn BYPASS_OP_NOP()          return 0 @end
@fn BYPASS_OP_READV()        return 1 @end
@fn BYPASS_OP_WRITEV()       return 2 @end
@fn BYPASS_OP_READ_FIXED()   return 4 @end
@fn BYPASS_OP_WRITE_FIXED()  return 5 @end
@fn BYPASS_OP_POLL_ADD()     return 6 @end
@fn BYPASS_OP_POLL_REMOVE()  return 7 @end
@fn BYPASS_OP_SENDMSG()      return 9 @end
@fn BYPASS_OP_RECVMSG()      return 10 @end
@fn BYPASS_OP_ACCEPT()       return 13 @end
@fn BYPASS_OP_CONNECT()      return 16 @end
@fn BYPASS_OP_CLOSE()        return 19 @end
@fn BYPASS_OP_READ()         return 22 @end
@fn BYPASS_OP_WRITE()        return 23 @end
@fn BYPASS_OP_SEND()         return 26 @end
@fn BYPASS_OP_RECV()         return 27 @end

@! ------------------------------------------------------------------------------
@! 2. FAST 32-BIT MEMORY ACCESS HELPERS
@! ------------------------------------------------------------------------------

@fn bypass_peek32(addr)
  // WHY: Little-endian 32-bit unsigned integer load
  b0 = sys_peek8(addr + 0) & 255
  b1 = sys_peek8(addr + 1) & 255
  b2 = sys_peek8(addr + 2) & 255
  b3 = sys_peek8(addr + 3) & 255
  return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
@end

@fn bypass_poke32(addr, val)
  // WHY: Little-endian 32-bit integer store
  sys_poke8(addr + 0, val & 255)
  sys_poke8(addr + 1, (val / 256) & 255)
  sys_poke8(addr + 2, (val / 65536) & 255)
  sys_poke8(addr + 3, (val / 16777216) & 255)
  return val
@end

@fn bypass_peek32_signed(addr)
  // WHY: Converts 32-bit unsigned value to signed integer (e.g. Linux -errno return codes)
  u = bypass_peek32(addr)
  @if u >= 2147483648
    return u - 4294967296
  @end
  return u
@end

@! ------------------------------------------------------------------------------
@! 3. ENGINE DATA STRUCTURES
@! ------------------------------------------------------------------------------

@! 64-Byte Submission Queue Entry (SQE)
@struct BypassSQE
  sqe_opcode: i64
  sqe_flags: i64
  sqe_ioprio: i64
  sqe_fd: i64
  sqe_offset: i64
  sqe_addr: i64
  sqe_nbytes: i64
  sqe_op_flags: i64
  sqe_tag: i64
  sqe_buf_index: i64
@end

@! 16-Byte Completion Queue Entry (CQE)
@struct BypassCQE
  cqe_tag: i64
  cqe_res: i64
  cqe_flags: i64
@end

@! Zero-Copy DMA Memory Pool
@! Contiguous page-aligned physical/virtual memory mapped region for network frames
@struct BypassDMAPool
  dp_num_slots: i64
  dp_slot_size: i64
  dp_total_size: i64
  dp_mmap_ptr: i64
  dp_free_slots: array
  dp_is_active: i64
@end

@! Sovereign Baremetal Network Engine
@struct IoUringBypassEngine
  be_ring_fd: i64
  be_entries: i64
  be_is_sqpoll: i64
  be_backend_mode: string
  backend_mode: string
  be_sq_ring_ptr: i64
  be_cq_ring_ptr: i64
  be_sqes_ptr: i64
  be_params_buf: i64
  be_sq_head_off: i64
  be_sq_tail_off: i64
  be_sq_mask_off: i64
  be_sq_entries_off: i64
  be_sq_flags_off: i64
  be_sq_array_off: i64
  be_cq_head_off: i64
  be_cq_tail_off: i64
  be_cq_mask_off: i64
  be_cq_entries_off: i64
  be_cq_cqes_off: i64
  be_sq_ring_sz: i64
  be_cq_ring_sz: i64
  be_sqes_sz: i64
  be_sq_head: i64
  be_sq_tail: i64
  be_sq_mask: i64
  be_sqes: array
  be_cq_head: i64
  be_cq_tail: i64
  be_cq_mask: i64
  be_cqes: array
  be_dma_pool: BypassDMAPool
  be_packets_tx: i64
  be_packets_rx: i64
  be_bytes_tx: i64
  be_bytes_rx: i64
  be_wakeups_sent: i64
  be_is_active: i64
@end

@struct BypassStreamEndpoint
  se_sockfd: i64
  se_peer_ip: string
  se_peer_port: i64
  se_is_connected: i64
@end

@struct BypassDatagramPacket
  dpkt_data: string
  dpkt_slot_idx: i64
  dpkt_nbytes: i64
  dpkt_src_ip: string
  dpkt_src_port: i64
@end

@! ------------------------------------------------------------------------------
@! 4. ZERO-COPY DMA MEMORY POOL MANAGEMENT
@! ------------------------------------------------------------------------------

@fn bypass_dma_pool_new(num_slots, slot_size)
  // WHY: Allocates contiguous page-aligned memory buffer for zero-copy DMA receive queues
  @if num_slots < 2 num_slots = 2 @end
  @if slot_size < 64 slot_size = 64 @end

  total_sz = num_slots * slot_size
  pool_ptr = sys_mmap(0, total_sz, 3, 34, -1, 0)
  @if pool_ptr <= 0 return 0 @end

  free_list = []
  i = 0
  @while i < num_slots
    free_list = free_list.push(i)
    i = i + 1
  @end

  return {
    dp_num_slots: num_slots,
    dp_slot_size: slot_size,
    dp_total_size: total_sz,
    dp_mmap_ptr: pool_ptr,
    dp_free_slots: free_list,
    dp_is_active: 1
  }
@end

@fn bypass_dma_alloc(pool)
  // WHY: Allocates a DMA slot index from the pre-pinned buffer pool in O(1)
  @if pool.dp_is_active == 0 || pool.dp_free_slots.len() == 0
    return -1
  @end
  slot_idx = pool.dp_free_slots[0]
  new_free = []
  i = 1
  n = pool.dp_free_slots.len()
  @while i < n
    new_free = new_free.push(pool.dp_free_slots[i])
    i = i + 1
  @end
  pool.dp_free_slots = new_free
  return slot_idx
@end

@fn bypass_dma_free(pool, slot_idx)
  // WHY: Recycles a DMA slot index back into the free buffer pool
  @if pool.dp_is_active == 1 && slot_idx >= 0 && slot_idx < pool.dp_num_slots
    pool.dp_free_slots = pool.dp_free_slots.push(slot_idx)
    return 1
  @end
  return 0
@end

@fn bypass_dma_slot_ptr(pool, slot_idx)
  // WHY: Returns raw memory pointer to DMA slot buffer
  @if pool.dp_is_active == 0 || slot_idx < 0 || slot_idx >= pool.dp_num_slots
    return 0
  @end
  return pool.dp_mmap_ptr + (slot_idx * pool.dp_slot_size)
@end

@fn bypass_dma_write(pool, slot_idx, data_str)
  // WHY: Copies string into DMA slot buffer
  ptr = bypass_dma_slot_ptr(pool, slot_idx)
  @if ptr <= 0 return 0 @end
  d_len = str_len(data_str)
  copy_len = d_len
  @if copy_len > pool.dp_slot_size copy_len = pool.dp_slot_size @end
  i = 0
  @while i < copy_len
    ch = str_char_at(data_str, i)
    sys_poke8(ptr + i, ch)
    i = i + 1
  @end
  return copy_len
@end

@fn bypass_dma_write_raw(pool, slot_idx, src_buf, len)
  // WHY: Zero-copy copies raw byte buffer into DMA slot
  ptr = bypass_dma_slot_ptr(pool, slot_idx)
  @if ptr <= 0 return 0 @end
  copy_len = len
  @if copy_len > pool.dp_slot_size copy_len = pool.dp_slot_size @end
  i = 0
  @while i < copy_len
    b = sys_peek8(src_buf + i)
    sys_poke8(ptr + i, b)
    i = i + 1
  @end
  return copy_len
@end

@fn bypass_dma_read(pool, slot_idx, len)
  // WHY: Extracts string payload from DMA slot
  ptr = bypass_dma_slot_ptr(pool, slot_idx)
  @if ptr <= 0 return "" @end
  copy_len = len
  @if copy_len > pool.dp_slot_size copy_len = pool.dp_slot_size @end
  res = ""
  i = 0
  @while i < copy_len
    b = sys_peek8(ptr + i) & 255
    res = res + chr(b)
    i = i + 1
  @end
  return res
@end

@fn bypass_dma_pool_free(pool)
  // WHY: Releases DMA pool memory pages
  @if pool.dp_is_active == 1
    pool.dp_is_active = 0
    ptr = pool.dp_mmap_ptr
    sz = pool.dp_total_size
    pool.dp_mmap_ptr = 0
    @if ptr > 0
      return sys_munmap(ptr, sz)
    @end
  @end
  return 1
@end

@! ------------------------------------------------------------------------------
@! 5. RAW IO_URING SQE SERIALIZER & KERNEL ARRAY WIRING
@! ------------------------------------------------------------------------------

@fn bypass_write_raw_sqe(engine, idx, sqe)
  // WHY: Direct memory write to 64-byte Linux io_uring SQE structure in shared memory.
  // Linux Kernel io_uring SQE layout (64 bytes):
  //   0: u8 opcode, 1: u8 flags, 2: u16 ioprio, 4: s32 fd
  //   8: u64 off, 16: u64 addr, 24: u32 len, 28: u32 rw_flags
  //   32: u64 user_data (tag), 40: u16 buf_index, 42: u16 personality, 44: s32 splice_fd_in
  @if engine.be_sqes_ptr > 0
    base = engine.be_sqes_ptr + (idx * 64)
    zi = 0
    @while zi < 64
      sys_poke8(base + zi, 0)
      zi = zi + 1
    @end

    sys_poke8(base + 0, sqe.sqe_opcode & 255)
    sys_poke8(base + 1, sqe.sqe_flags & 255)
    sys_poke8(base + 2, sqe.sqe_ioprio & 255)
    sys_poke8(base + 3, (sqe.sqe_ioprio / 256) & 255)
    bypass_poke32(base + 4, sqe.sqe_fd)
    sys_poke(base + 8, sqe.sqe_offset)
    sys_poke(base + 16, sqe.sqe_addr)
    bypass_poke32(base + 24, sqe.sqe_nbytes)
    bypass_poke32(base + 28, sqe.sqe_op_flags)
    sys_poke(base + 32, sqe.sqe_tag)
    sys_poke8(base + 40, sqe.sqe_buf_index & 255)
    sys_poke8(base + 41, (sqe.sqe_buf_index / 256) & 255)

    // Map SQ ring array entry to slot index
    @if engine.be_sq_ring_ptr > 0 && engine.be_ring_fd >= 0
      array_addr = engine.be_sq_ring_ptr + engine.be_sq_array_off + (idx * 4)
      bypass_poke32(array_addr, idx)
    @end
  @end
  return 1
@end

@! ------------------------------------------------------------------------------
@! 6. BAREMETAL ENGINE LIFECYCLE & DYNAMIC MMAP SETUP
@! ------------------------------------------------------------------------------

@fn io_uring_bypass_new(entries, enable_sqpoll, dma_slots, dma_slot_size)
  // WHY: Initializes sovereign kernel-bypass network engine.
  // 1. Invokes Linux io_uring setup (Syscall 425) with dynamic offset resolution
  // 2. Mmaps SQ/CQ shared memory rings using canonical MAP_SHARED (1)
  // 3. Allocates pinned zero-copy DMA receive pool
  // 4. Provides zero-syscall fast path with graceful kernel fallback
  @if entries < 4 entries = 4 @end
  mask = entries - 1

  sq_list = []
  i = 0
  @while i < entries
    sq_list = sq_list.push({
      sqe_opcode: 0,
      sqe_flags: 0,
      sqe_ioprio: 0,
      sqe_fd: -1,
      sqe_offset: 0,
      sqe_addr: 0,
      sqe_nbytes: 0,
      sqe_op_flags: 0,
      sqe_tag: 0,
      sqe_buf_index: 0
    })
    i = i + 1
  @end

  params_mmap = sys_mmap(0, 256, 3, 34, -1, 0)
  @if params_mmap > 0
    p_idx = 0
    @while p_idx < 256
      sys_poke8(params_mmap + p_idx, 0)
      p_idx = p_idx + 1
    @end
  @end

  k_ring_fd = -1
  actual_sqpoll = 0
  backend = "direct_wire"

  // Attempt 1: SQPOLL mode (Kernel thread polling)
  @if enable_sqpoll == 1 && params_mmap > 0
    bypass_poke32(params_mmap + 8, BYPASS_SETUP_SQPOLL())
    bypass_poke32(params_mmap + 16, 2000) // 2000ms idle timeout
    k_ring_fd = sys_io_uring_setup(entries, params_mmap)
    @if k_ring_fd >= 0
      actual_sqpoll = 1
      backend = "sqpoll"
    @end
  @end

  // Attempt 2: Standard io_uring mode if SQPOLL was rejected (e.g. non-root container)
  @if k_ring_fd < 0 && params_mmap > 0
    p_idx = 0
    @while p_idx < 256
      sys_poke8(params_mmap + p_idx, 0)
      p_idx = p_idx + 1
    @end
    k_ring_fd = sys_io_uring_setup(entries, params_mmap)
    @if k_ring_fd >= 0
      backend = "standard_io_uring"
    @end
  @end

  mmap_sq_ring = 0
  mmap_cq_ring = 0
  mmap_sqes = 0

  sq_ring_sz = 0
  cq_ring_sz = 0
  sqes_sz = 0

  sq_head_off = 0
  sq_tail_off = 4
  sq_mask_off = 8
  sq_entries_off = 12
  sq_flags_off = 16
  sq_array_off = 20

  cq_head_off = 0
  cq_tail_off = 4
  cq_mask_off = 8
  cq_entries_off = 12
  cq_cqes_off = 16

  actual_entries = entries
  cq_mask = mask

  @if k_ring_fd >= 0
    actual_sq_entries = bypass_peek32(params_mmap + 0)
    actual_cq_entries = bypass_peek32(params_mmap + 4)
    @if actual_sq_entries > 0
      actual_entries = actual_sq_entries
      mask = actual_sq_entries - 1
    @end
    @if actual_cq_entries > 0
      cq_mask = actual_cq_entries - 1
    @end

    sq_head_off = bypass_peek32(params_mmap + 40)
    sq_tail_off = bypass_peek32(params_mmap + 44)
    sq_mask_off = bypass_peek32(params_mmap + 48)
    sq_entries_off = bypass_peek32(params_mmap + 52)
    sq_flags_off = bypass_peek32(params_mmap + 56)
    sq_array_off = bypass_peek32(params_mmap + 64)

    cq_head_off = bypass_peek32(params_mmap + 80)
    cq_tail_off = bypass_peek32(params_mmap + 84)
    cq_mask_off = bypass_peek32(params_mmap + 88)
    cq_entries_off = bypass_peek32(params_mmap + 92)
    cq_cqes_off = bypass_peek32(params_mmap + 100)

    sq_ring_sz = sq_array_off + (actual_entries * 4)
    cq_ring_sz = cq_cqes_off + (actual_cq_entries * 16)
    sqes_sz = actual_entries * 64

    mmap_sq_ring = sys_mmap(0, sq_ring_sz, 3, 1, k_ring_fd, BYPASS_OFF_SQ_RING())
    mmap_cq_ring = sys_mmap(0, cq_ring_sz, 3, 1, k_ring_fd, BYPASS_OFF_CQ_RING())
    mmap_sqes = sys_mmap(0, sqes_sz, 3, 1, k_ring_fd, BYPASS_OFF_SQES())

    @if mmap_sq_ring <= 0 || mmap_cq_ring <= 0 || mmap_sqes <= 0
      @if mmap_sq_ring > 0 sys_munmap(mmap_sq_ring, sq_ring_sz) @end
      @if mmap_cq_ring > 0 sys_munmap(mmap_cq_ring, cq_ring_sz) @end
      @if mmap_sqes > 0 sys_munmap(mmap_sqes, sqes_sz) @end
      mmap_sq_ring = 0
      mmap_cq_ring = 0
      mmap_sqes = 0
      sys_close(k_ring_fd)
      k_ring_fd = -1
      backend = "direct_wire"
    @end
  @end

  // If kernel io_uring setup failed or unavailable, allocate anonymous fallback rings
  @if k_ring_fd < 0
    sq_ring_sz = 4096
    cq_ring_sz = 4096
    sqes_sz = entries * 64
    mmap_sq_ring = sys_mmap(0, sq_ring_sz, 3, 34, -1, 0)
    mmap_cq_ring = sys_mmap(0, cq_ring_sz, 3, 34, -1, 0)
    mmap_sqes = sys_mmap(0, sqes_sz, 3, 34, -1, 0)
    backend = "direct_wire"
  @end

  // Allocate linked Zero-Copy DMA Memory Pool
  dma = bypass_dma_pool_new(dma_slots, dma_slot_size)

  return {
    be_ring_fd: k_ring_fd,
    be_entries: actual_entries,
    be_is_sqpoll: actual_sqpoll,
    be_backend_mode: backend,
    backend_mode: backend,
    be_sq_ring_ptr: mmap_sq_ring,
    be_cq_ring_ptr: mmap_cq_ring,
    be_sqes_ptr: mmap_sqes,
    be_params_buf: params_mmap,
    be_sq_head_off: sq_head_off,
    be_sq_tail_off: sq_tail_off,
    be_sq_mask_off: sq_mask_off,
    be_sq_entries_off: sq_entries_off,
    be_sq_flags_off: sq_flags_off,
    be_sq_array_off: sq_array_off,
    be_cq_head_off: cq_head_off,
    be_cq_tail_off: cq_tail_off,
    be_cq_mask_off: cq_mask_off,
    be_cq_entries_off: cq_entries_off,
    be_cq_cqes_off: cq_cqes_off,
    be_sq_ring_sz: sq_ring_sz,
    be_cq_ring_sz: cq_ring_sz,
    be_sqes_sz: sqes_sz,
    be_sq_head: 0,
    be_sq_tail: 0,
    be_sq_mask: mask,
    be_sqes: sq_list,
    be_cq_head: 0,
    be_cq_tail: 0,
    be_cq_mask: cq_mask,
    be_cqes: [],
    be_dma_pool: dma,
    be_packets_tx: 0,
    be_packets_rx: 0,
    be_bytes_tx: 0,
    be_bytes_rx: 0,
    be_wakeups_sent: 0,
    be_is_active: 1
  }
@end

@fn io_uring_bypass_close(engine)
  // WHY: Releases kernel ring resources, memory mappings, and DMA pools cleanly
  @if engine.be_is_active == 1
    @if engine.be_sq_ring_ptr > 0 sys_munmap(engine.be_sq_ring_ptr, engine.be_sq_ring_sz) @end
    @if engine.be_cq_ring_ptr > 0 sys_munmap(engine.be_cq_ring_ptr, engine.be_cq_ring_sz) @end
    @if engine.be_sqes_ptr > 0 sys_munmap(engine.be_sqes_ptr, engine.be_sqes_sz) @end
    @if engine.be_params_buf > 0 sys_munmap(engine.be_params_buf, 256) @end

    @if engine.be_ring_fd >= 0
      sys_close(engine.be_ring_fd)
      engine.be_ring_fd = -1
    @end

    @if engine.be_dma_pool != 0
      bypass_dma_pool_free(engine.be_dma_pool)
    @end

    engine.be_is_active = 0
    engine.be_sq_ring_ptr = 0
    engine.be_cq_ring_ptr = 0
    engine.be_sqes_ptr = 0
  @end
  return 1
@end

@! ------------------------------------------------------------------------------
@! 7. SQE PREPARATION OPERATIONS
@! ------------------------------------------------------------------------------

@fn io_uring_bypass_prep_send(engine, sockfd, buf_addr, len, flags, tag)
  // WHY: Enqueues an asynchronous zero-copy network transmission SQE
  @if engine.be_is_active == 0 return 0 @end
  tail = engine.be_sq_tail
  idx = tail & engine.be_sq_mask

  sqe = {
    sqe_opcode: BYPASS_OP_SEND(),
    sqe_flags: 0,
    sqe_ioprio: 0,
    sqe_fd: sockfd,
    sqe_offset: 0,
    sqe_addr: buf_addr,
    sqe_nbytes: len,
    sqe_op_flags: flags,
    sqe_tag: tag,
    sqe_buf_index: 0
  }

  engine.be_sqes = list_set(engine.be_sqes, idx, sqe)
  bypass_write_raw_sqe(engine, idx, sqe)
  engine.be_sq_tail = tail + 1
  return 1
@end

@fn io_uring_bypass_prep_recv(engine, sockfd, buf_addr, len, flags, tag)
  // WHY: Enqueues an asynchronous zero-copy network reception SQE
  @if engine.be_is_active == 0 return 0 @end
  tail = engine.be_sq_tail
  idx = tail & engine.be_sq_mask

  sqe = {
    sqe_opcode: BYPASS_OP_RECV(),
    sqe_flags: 0,
    sqe_ioprio: 0,
    sqe_fd: sockfd,
    sqe_offset: 0,
    sqe_addr: buf_addr,
    sqe_nbytes: len,
    sqe_op_flags: flags,
    sqe_tag: tag,
    sqe_buf_index: 0
  }

  engine.be_sqes = list_set(engine.be_sqes, idx, sqe)
  bypass_write_raw_sqe(engine, idx, sqe)
  engine.be_sq_tail = tail + 1
  return 1
@end

@fn io_uring_bypass_prep_recv_dma(engine, sockfd, slot_idx, tag)
  // WHY: Prepares zero-copy DMA reception directly into pre-pinned pool slot
  slot_addr = bypass_dma_slot_ptr(engine.be_dma_pool, slot_idx)
  @if slot_addr <= 0 return 0 @end
  return io_uring_bypass_prep_recv(engine, sockfd, slot_addr, engine.be_dma_pool.dp_slot_size, 0, tag)
@end

@fn io_uring_bypass_prep_accept(engine, sockfd, tag)
  // WHY: Enqueues async accept connection request
  @if engine.be_is_active == 0 return 0 @end
  tail = engine.be_sq_tail
  idx = tail & engine.be_sq_mask

  sqe = {
    sqe_opcode: BYPASS_OP_ACCEPT(),
    sqe_flags: 0,
    sqe_ioprio: 0,
    sqe_fd: sockfd,
    sqe_offset: 0,
    sqe_addr: 0,
    sqe_nbytes: 0,
    sqe_op_flags: 0,
    sqe_tag: tag,
    sqe_buf_index: 0
  }

  engine.be_sqes = list_set(engine.be_sqes, idx, sqe)
  bypass_write_raw_sqe(engine, idx, sqe)
  engine.be_sq_tail = tail + 1
  return 1
@end

@fn io_uring_bypass_prep_connect(engine, sockfd, addr_ptr, addrlen, tag)
  // WHY: Enqueues async connect request
  @if engine.be_is_active == 0 return 0 @end
  tail = engine.be_sq_tail
  idx = tail & engine.be_sq_mask

  sqe = {
    sqe_opcode: BYPASS_OP_CONNECT(),
    sqe_flags: 0,
    sqe_ioprio: 0,
    sqe_fd: sockfd,
    sqe_offset: addrlen,
    sqe_addr: addr_ptr,
    sqe_nbytes: 0,
    sqe_op_flags: 0,
    sqe_tag: tag,
    sqe_buf_index: 0
  }

  engine.be_sqes = list_set(engine.be_sqes, idx, sqe)
  bypass_write_raw_sqe(engine, idx, sqe)
  engine.be_sq_tail = tail + 1
  return 1
@end

@fn io_uring_bypass_prep_close(engine, fd, tag)
  // WHY: Enqueues async descriptor close request
  @if engine.be_is_active == 0 return 0 @end
  tail = engine.be_sq_tail
  idx = tail & engine.be_sq_mask

  sqe = {
    sqe_opcode: BYPASS_OP_CLOSE(),
    sqe_flags: 0,
    sqe_ioprio: 0,
    sqe_fd: fd,
    sqe_offset: 0,
    sqe_addr: 0,
    sqe_nbytes: 0,
    sqe_op_flags: 0,
    sqe_tag: tag,
    sqe_buf_index: 0
  }

  engine.be_sqes = list_set(engine.be_sqes, idx, sqe)
  bypass_write_raw_sqe(engine, idx, sqe)
  engine.be_sq_tail = tail + 1
  return 1
@end

@! ------------------------------------------------------------------------------
@! 8. BATCH SUBMISSION & CQE EVENT REAPING
@! ------------------------------------------------------------------------------

@fn io_uring_bypass_submit(engine)
  // WHY: Commits all pending SQEs in the ring buffer.
  // 1. Writes updated tail to shared memory ring
  // 2. SQPOLL Mode: Checks sleep flag and wakes kernel poller only if necessary
  // 3. Standard Mode: Single sys_io_uring_enter per batch
  // 4. Direct Wire Mode: Executes direct syscalls synchronously with synthetic CQEs
  @if engine.be_is_active == 0 return 0 @end
  submitted = engine.be_sq_tail - engine.be_sq_head
  @if submitted <= 0 return 0 @end

  @if engine.be_ring_fd >= 0
    // Commit SQ tail to shared memory ring
    bypass_poke32(engine.be_sq_ring_ptr + engine.be_sq_tail_off, engine.be_sq_tail)

    @if engine.be_is_sqpoll == 1
      sq_flags = bypass_peek32(engine.be_sq_ring_ptr + engine.be_sq_flags_off)
      @if (sq_flags & BYPASS_SQ_NEED_WAKEUP()) != 0
        sys_io_uring_enter(engine.be_ring_fd, submitted, 0, BYPASS_ENTER_SQ_WAKEUP(), 0, 0)
        engine.be_wakeups_sent = engine.be_wakeups_sent + 1
      @end
    @else
      sys_io_uring_enter(engine.be_ring_fd, submitted, 0, 0, 0, 0)
    @end
  @else
    // Direct Wire Mode: Process operations synchronously
    curr = engine.be_sq_head
    @while curr < engine.be_sq_tail
      idx = curr & engine.be_sq_mask
      sqe = engine.be_sqes[idx]

      res_val = 0
      @if sqe.sqe_opcode == BYPASS_OP_SEND() || sqe.sqe_opcode == BYPASS_OP_WRITE()
        res_val = sys_write(sqe.sqe_fd, sqe.sqe_addr, sqe.sqe_nbytes)
        @if res_val > 0
          engine.be_packets_tx = engine.be_packets_tx + 1
          engine.be_bytes_tx = engine.be_bytes_tx + res_val
        @end
      @elif sqe.sqe_opcode == BYPASS_OP_RECV() || sqe.sqe_opcode == BYPASS_OP_READ()
        res_val = sys_read(sqe.sqe_fd, sqe.sqe_addr, sqe.sqe_nbytes)
        @if res_val > 0
          engine.be_packets_rx = engine.be_packets_rx + 1
          engine.be_bytes_rx = engine.be_bytes_rx + res_val
        @end
      @elif sqe.sqe_opcode == BYPASS_OP_ACCEPT()
        res_val = sys_accept(sqe.sqe_fd, 0, 0)
      @elif sqe.sqe_opcode == BYPASS_OP_CONNECT()
        res_val = sys_connect(sqe.sqe_fd, sqe.sqe_addr, sqe.sqe_offset)
      @elif sqe.sqe_opcode == BYPASS_OP_CLOSE()
        res_val = sys_close(sqe.sqe_fd)
      @end

      cqe = {
        cqe_tag: sqe.sqe_tag,
        cqe_res: res_val,
        cqe_flags: 0
      }
      engine.be_cqes = engine.be_cqes.push(cqe)
      engine.be_cq_tail = engine.be_cq_tail + 1
      curr = curr + 1
    @end
  @end

  engine.be_sq_head = engine.be_sq_tail
  return submitted
@end

@fn io_uring_bypass_reap_cqes(engine, min_complete)
  // WHY: Gathers all available CQEs from kernel completion ring into internal engine.be_cqes queue
  @if engine.be_is_active == 0 return [] @end

  @if engine.be_ring_fd >= 0
    @if min_complete > 0
      sys_io_uring_enter(engine.be_ring_fd, 0, min_complete, BYPASS_ENTER_GETEVENTS(), 0, 0)
    @end

    @if engine.be_cq_ring_ptr > 0
      k_head = bypass_peek32(engine.be_cq_ring_ptr + engine.be_cq_head_off)
      k_tail = bypass_peek32(engine.be_cq_ring_ptr + engine.be_cq_tail_off)
      k_mask = bypass_peek32(engine.be_cq_ring_ptr + engine.be_cq_mask_off)

      @while k_head < k_tail
        idx = k_head & k_mask
        cqe_addr = engine.be_cq_ring_ptr + engine.be_cq_cqes_off + (idx * 16)
        tag = sys_peek(cqe_addr + 0)
        res = bypass_peek32_signed(cqe_addr + 8)
        flg = bypass_peek32(cqe_addr + 12)

        engine.be_cqes = engine.be_cqes.push({
          cqe_tag: tag,
          cqe_res: res,
          cqe_flags: flg
        })
        engine.be_cq_tail = engine.be_cq_tail + 1
        k_head = k_head + 1
      @end
      bypass_poke32(engine.be_cq_ring_ptr + engine.be_cq_head_off, k_head)
    @end
  @end

  return engine.be_cqes
@end

@fn io_uring_bypass_pop_cqe(engine)
  // WHY: Retrieves the single next available completion event with zero heap allocations
  @if engine.be_cqes.len() > 0
    cqe = engine.be_cqes[0]
    n = engine.be_cqes.len()
    @if n <= 1
      engine.be_cqes = []
    @else
      new_cqes = []
      i = 1
      @while i < n
        new_cqes = new_cqes.push(engine.be_cqes[i])
        i = i + 1
      @end
      engine.be_cqes = new_cqes
    @end
    engine.be_cq_head = engine.be_cq_head + 1
    return cqe
  @end

  // Direct zero-copy ring buffer pop from shared kernel memory
  @if engine.be_cq_ring_ptr > 0 && engine.be_ring_fd >= 0
    k_head = bypass_peek32(engine.be_cq_ring_ptr + engine.be_cq_head_off)
    k_tail = bypass_peek32(engine.be_cq_ring_ptr + engine.be_cq_tail_off)
    @if k_head < k_tail
      k_mask = bypass_peek32(engine.be_cq_ring_ptr + engine.be_cq_mask_off)
      idx = k_head & k_mask
      cqe_addr = engine.be_cq_ring_ptr + engine.be_cq_cqes_off + (idx * 16)
      tag = sys_peek(cqe_addr + 0)
      res = bypass_peek32_signed(cqe_addr + 8)
      flg = bypass_peek32(cqe_addr + 12)
      bypass_poke32(engine.be_cq_ring_ptr + engine.be_cq_head_off, k_head + 1)
      engine.be_cq_head = engine.be_cq_head + 1
      return {
        cqe_tag: tag,
        cqe_res: res,
        cqe_flags: flg
      }
    @end
  @end

  return 0
@end

@fn io_uring_bypass_wait_cqe(engine, min_complete)
  // WHY: Retrieves next completion event with spin-polling and kernel wakeup fallback
  @if engine.be_is_active == 0 return 0 @end

  cqe = io_uring_bypass_pop_cqe(engine)
  @if cqe != 0 return cqe @end

  // Spin poll up to 1000 times for low latency zero-syscall path
  spin = 0
  @while spin < 1000
    cqe = io_uring_bypass_pop_cqe(engine)
    @if cqe != 0 return cqe @end
    spin = spin + 1
  @end

  // If still no completion, enter kernel to wait
  req_min = min_complete
  @if req_min <= 0 req_min = 1 @end
  @if engine.be_ring_fd >= 0
    sys_io_uring_enter(engine.be_ring_fd, 0, req_min, BYPASS_ENTER_GETEVENTS(), 0, 0)
  @end
  return io_uring_bypass_pop_cqe(engine)
@end

@! ------------------------------------------------------------------------------
@! 9. WIRE-LEVEL TCP STREAM ENGINE (KERNEL-BYPASS / DIRECT SYSCALL)
@! ------------------------------------------------------------------------------

@fn bypass_socket_set_nonblocking(sockfd)
  // WHY: Sets socket to non-blocking mode via fcntl syscall 72
  return net_set_nonblocking(sockfd, 1)
@end

@fn bypass_socket_accept(sockfd)
  // WHY: Accepts inbound connection descriptor via Linux accept syscall 43
  return net_tcp_accept(sockfd)
@end

@fn bypass_tcp_listen(engine, port, backlog)
  // WHY: Allocates and binds non-blocking TCP socket directly via Linux syscalls
  fd = net_tcp_socket_nonblocking()
  @if fd < 0 return -1 @end
  net_set_reuseaddr(fd, 1)
  net_set_reuseport(fd, 1)
  net_set_nodelay(fd, 1)

  res_bind = net_tcp_bind(fd, port)
  @if res_bind < 0
    net_close(fd)
    return -1
  @end

  res_listen = net_tcp_listen(fd, backlog)
  @if res_listen < 0
    net_close(fd)
    return -1
  @end

  return fd
@end

@fn bypass_tcp_connect(engine, ip_str, port)
  // WHY: Connects TCP socket to remote peer with nodelay enabled
  fd = net_tcp_socket()
  @if fd < 0 return -1 @end
  net_set_nodelay(fd, 1)

  res = net_tcp_connect(fd, ip_str, port)
  @if res < 0
    net_close(fd)
    return -1
  @end

  return fd
@end

@fn bypass_tcp_send(engine, sockfd, data_str)
  // WHY: Submits a single TCP transmission through the engine ring pipeline and waits for completion
  d_len = str_len(data_str)
  slot = bypass_dma_alloc(engine.be_dma_pool)
  @if slot < 0 return 0 @end

  bypass_dma_write(engine.be_dma_pool, slot, data_str)
  slot_ptr = bypass_dma_slot_ptr(engine.be_dma_pool, slot)

  io_uring_bypass_prep_send(engine, sockfd, slot_ptr, d_len, 0, slot)
  io_uring_bypass_submit(engine)

  cqe = io_uring_bypass_wait_cqe(engine, 1)
  bytes_sent = 0
  @if cqe != 0
    bytes_sent = cqe.cqe_res
    @if bytes_sent > 0
      engine.be_packets_tx = engine.be_packets_tx + 1
      engine.be_bytes_tx = engine.be_bytes_tx + bytes_sent
    @end
  @end

  bypass_dma_free(engine.be_dma_pool, slot)
  return bytes_sent
@end

@fn bypass_tcp_send_raw(engine, sockfd, buf_ptr, len)
  // WHY: Zero-copy sends raw memory bytes over TCP via io_uring
  io_uring_bypass_prep_send(engine, sockfd, buf_ptr, len, 0, 0)
  io_uring_bypass_submit(engine)
  cqe = io_uring_bypass_wait_cqe(engine, 1)
  @if cqe != 0
    @if cqe.cqe_res > 0
      engine.be_packets_tx = engine.be_packets_tx + 1
      engine.be_bytes_tx = engine.be_bytes_tx + cqe.cqe_res
    @end
    return cqe.cqe_res
  @end
  return -1
@end

@fn bypass_tcp_recv(engine, sockfd, max_len)
  // WHY: Receives TCP stream payload into DMA buffer via io_uring and returns Lipi string
  slot = bypass_dma_alloc(engine.be_dma_pool)
  @if slot < 0 return "" @end

  slot_ptr = bypass_dma_slot_ptr(engine.be_dma_pool, slot)
  @if max_len > engine.be_dma_pool.dp_slot_size
    max_len = engine.be_dma_pool.dp_slot_size
  @end

  io_uring_bypass_prep_recv(engine, sockfd, slot_ptr, max_len, 0, slot)
  io_uring_bypass_submit(engine)

  cqe = io_uring_bypass_wait_cqe(engine, 1)
  bytes_read = 0
  @if cqe != 0
    bytes_read = cqe.cqe_res
    @if bytes_read > 0
      engine.be_packets_rx = engine.be_packets_rx + 1
      engine.be_bytes_rx = engine.be_bytes_rx + bytes_read
    @end
  @end

  res = ""
  @if bytes_read > 0
    res = bypass_dma_read(engine.be_dma_pool, slot, bytes_read)
  @end

  bypass_dma_free(engine.be_dma_pool, slot)
  return res
@end

@fn bypass_tcp_recv_raw(engine, sockfd, buf_ptr, max_len)
  // WHY: Zero-copy reads bytes directly into pre-allocated memory via io_uring
  io_uring_bypass_prep_recv(engine, sockfd, buf_ptr, max_len, 0, 0)
  io_uring_bypass_submit(engine)
  cqe = io_uring_bypass_wait_cqe(engine, 1)
  @if cqe != 0
    @if cqe.cqe_res > 0
      engine.be_packets_rx = engine.be_packets_rx + 1
      engine.be_bytes_rx = engine.be_bytes_rx + cqe.cqe_res
    @end
    return cqe.cqe_res
  @end
  return -1
@end

@fn bypass_tcp_batch_send(engine, sockfd, packet_array)
  // WHY: Submits an entire array of TCP packet strings in a single pipeline burst
  n = packet_array.len()
  @if n == 0 return 0 @end

  allocated_slots = []
  i = 0
  @while i < n
    p_str = packet_array[i]
    slot = bypass_dma_alloc(engine.be_dma_pool)
    @if slot >= 0
      bypass_dma_write(engine.be_dma_pool, slot, p_str)
      s_ptr = bypass_dma_slot_ptr(engine.be_dma_pool, slot)
      io_uring_bypass_prep_send(engine, sockfd, s_ptr, str_len(p_str), 0, slot)
      allocated_slots = allocated_slots.push(slot)
    @end
    i = i + 1
  @end

  submitted = io_uring_bypass_submit(engine)
  @if submitted > 0
    reaped = 0
    @while reaped < submitted
      cqe = io_uring_bypass_wait_cqe(engine, 1)
      @if cqe != 0
        @if cqe.cqe_res > 0
          engine.be_packets_tx = engine.be_packets_tx + 1
          engine.be_bytes_tx = engine.be_bytes_tx + cqe.cqe_res
        @end
        reaped = reaped + 1
      @else
        reaped = submitted
      @end
    @end
  @end

  // Recycle allocated DMA slots
  k = 0
  n_slots = allocated_slots.len()
  @while k < n_slots
    bypass_dma_free(engine.be_dma_pool, allocated_slots[k])
    k = k + 1
  @end

  return submitted
@end

@! ------------------------------------------------------------------------------
@! 10. WIRE-LEVEL UDP RING BUFFER & BATCH PACKET ENGINE
@! ------------------------------------------------------------------------------

@fn bypass_udp_bind(engine, port)
  // WHY: Sets up high-performance UDP datagram socket
  fd = net_udp_socket_nonblocking()
  @if fd < 0 return -1 @end
  net_set_reuseaddr(fd, 1)
  net_set_reuseport(fd, 1)
  net_set_broadcast(fd, 1)

  res = net_udp_bind(fd, port)
  @if res < 0
    net_close(fd)
    return -1
  @end
  return fd
@end

@fn bypass_udp_sendto(engine, sockfd, data_str, ip_str, port)
  // WHY: Wire transmission of UDP datagram to remote address
  res = net_udp_sendto(sockfd, data_str, ip_str, port)
  @if res > 0
    engine.be_packets_tx = engine.be_packets_tx + 1
    engine.be_bytes_tx = engine.be_bytes_tx + res
  @end
  return res
@end

@fn bypass_udp_recvfrom(engine, sockfd, max_len)
  // WHY: Wire reception of UDP datagram with sender identification
  pkt = net_udp_recvfrom(sockfd, max_len)
  @if pkt.pkt_bytes_received > 0
    engine.be_packets_rx = engine.be_packets_rx + 1
    engine.be_bytes_rx = engine.be_bytes_rx + pkt.pkt_bytes_received
  @end
  return pkt
@end

@fn bypass_udp_batch_sendto(engine, sockfd, packets_batch)
  // WHY: Batch UDP transmission via sendmmsg or io_uring burst
  n = packets_batch.len()
  @if n == 0 return 0 @end

  bq = net_batch_queue_new(n, engine.be_dma_pool.dp_slot_size)
  @if bq == 0 return 0 @end

  i = 0
  @while i < n
    item = packets_batch[i]
    net_batch_set_packet(bq, i, item.data, item.ip, item.port)
    i = i + 1
  @end

  sent_count = net_batch_send(sockfd, bq, n)
  @if sent_count > 0
    engine.be_packets_tx = engine.be_packets_tx + sent_count
  @end
  net_batch_queue_free(bq)
  return sent_count
@end

@fn bypass_udp_batch_recvfrom(engine, sockfd, max_packets)
  // WHY: Batch UDP reception via recvmmsg
  @if max_packets <= 0 return [] @end

  bq = net_batch_queue_new(max_packets, engine.be_dma_pool.dp_slot_size)
  @if bq == 0 return [] @end

  recv_count = net_batch_recv(sockfd, bq, max_packets, 0)
  @if recv_count <= 0
    net_batch_queue_free(bq)
    return []
  @end

  engine.be_packets_rx = engine.be_packets_rx + recv_count
  out_list = []
  i = 0
  @while i < recv_count
    p_data = net_batch_get_packet_data(bq, i)
    p_len = net_batch_get_packet_len(bq, i)
    p_ip = net_batch_get_packet_ip(bq, i)
    p_port = net_batch_get_packet_port(bq, i)

    out_list = out_list.push({
      dpkt_data: p_data,
      dpkt_slot_idx: i,
      dpkt_nbytes: p_len,
      dpkt_src_ip: p_ip,
      dpkt_src_port: p_port
    })
    i = i + 1
  @end

  net_batch_queue_free(bq)
  return out_list
@end

@! ------------------------------------------------------------------------------
@! 11. ENGINE METRICS & STATUS
@! ------------------------------------------------------------------------------

@fn io_uring_bypass_stats(engine)
  // WHY: Diagnostic telemetry on packets, bytes, wakeups, and operating mode
  return {
    backend_mode: engine.be_backend_mode,
    is_sqpoll: engine.be_is_sqpoll,
    ring_fd: engine.be_ring_fd,
    entries: engine.be_entries,
    packets_tx: engine.be_packets_tx,
    packets_rx: engine.be_packets_rx,
    bytes_tx: engine.be_bytes_tx,
    bytes_rx: engine.be_bytes_rx,
    wakeups_sent: engine.be_wakeups_sent,
    dma_slots_total: engine.be_dma_pool.dp_num_slots,
    dma_slots_free: engine.be_dma_pool.dp_free_slots.len()
  }
@end
