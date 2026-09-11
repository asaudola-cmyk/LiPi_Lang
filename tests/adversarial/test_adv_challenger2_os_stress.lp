@! ============================================================================
@! ADVERSARIAL STRESS SUITE — CHALLENGER 2: MAYA OS KERNEL
@! Modules Tested:
@! 1. universe/os/memory.maya (Segregated Heap Allocator, Coalescing, Canaries)
@! 2. universe/os/freestanding.maya (2MB Arena, Two-Finger Compaction, CRT0, Linker)
@! 3. universe/os/vfs.maya (Deep Inode RamFS, Boundary lseek, DevFS, Unlink)
@! 4. universe/os/ipc.maya (FIFO Ring Buffer Wrap-around, MQ Priority, UDS, Sem/Mutex)
@! 5. universe/os/boot/ (4-Level MMU Paging, Long Mode GDT, Multiboot)
@! ============================================================================

import "universe/os/memory"
import "universe/os/freestanding"
import "universe/os/vfs"
import "universe/os/ipc"
import "universe/os/boot/paging"
import "universe/os/boot/gdt"
import "universe/os/boot/multiboot"

@fn assert_test(cond, id, msg)
  @if cond == 1 || cond == true
    println("  [PASS] " + id + ": " + msg)
    return 1
  @else
    println("  [FAIL] " + id + ": " + msg)
    return 0
  @end
@end

@fn assert_eq_num(actual, expected, id, msg)
  @if actual == expected
    println("  [PASS] " + id + ": " + msg)
    return 1
  @else
    println("  [FAIL] " + id + ": " + msg + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("⚔️  ADVERSARIAL STRESS SUITE — CHALLENGER 2: MAYA OS KERNEL ⚔️")
  println("=================================================================")

  total = 0
  passed = 0

  @! ==========================================================================
  @! SECTION 1: SEGREGATED HEAP ALLOCATOR STRESS (universe/os/memory.maya)
  @! ==========================================================================
  println("\n▶ Section 1: Segregated Free-List Heap Allocator Stress...")

  heap = heap_new()

  @! MEM1.1: Rapid Allocate & Free Cycles (100 Allocations)
  total = total + 1
  ptrs = []
  i = 0
  all_valid = 1
  @while i < 100
    p = memory_alloc(heap, 48)
    @if p <= 0
      all_valid = 0
    @end
    ptrs = ptrs.push(p)
    i = i + 1
  @end
  @if assert_test(all_valid, "MEM1.1a", "100 rapid allocations succeeded with valid non-null addresses") == 1
    passed = passed + 1
  @end

  total = total + 1
  j = 0
  all_freed = 1
  @while j < 100
    res = memory_free(heap, ptrs[j])
    @if res != 0
      all_freed = 0
    @end
    j = j + 1
  @end
  @if assert_test(all_freed, "MEM1.1b", "100 rapid deallocations returned cleanly") == 1
    passed = passed + 1
  @end

  total = total + 1
  st1 = heap_stats(heap)
  @if assert_eq_num(st1.allocated_bytes, 0, "MEM1.1c", "Heap allocated_bytes returned to 0 after full deallocation") == 1
    passed = passed + 1
  @end

  @! MEM1.2: Alternating Block Sizes Across All Size Classes
  total = total + 1
  sizes = [16, 32, 48, 64, 96, 128, 200, 256, 400, 512, 800, 1024, 1500, 2048, 3000, 4096, 6000, 8192]
  alt_ptrs = []
  all_aligned = 1
  s_idx = 0
  @while s_idx < sizes.len()
    sz = sizes[s_idx]
    ap = memory_alloc(heap, sz)
    @if ap <= 0 || (ap % 8 != 0)
      all_aligned = 0
    @end
    alt_ptrs = alt_ptrs.push(ap)
    s_idx = s_idx + 1
  @end
  @if assert_test(all_aligned, "MEM1.2", "Alternating sizes (16B to 8KB) allocated with strict 8-byte alignment") == 1
    passed = passed + 1
  @end

  @! Clean up alternating allocations
  s_idx = 0
  @while s_idx < alt_ptrs.len()
    memory_free(heap, alt_ptrs[s_idx])
    s_idx = s_idx + 1
  @end

  @! MEM1.3: Double-Free Detection & Resiliency
  total = total + 1
  df_heap = heap_new()
  df_p = memory_alloc(df_heap, 128)
  df_res1 = memory_free(df_heap, df_p)
  df_res2 = memory_free(df_heap, df_p) @! Double free
  @if assert_test(df_res1 == 0 && df_res2 == 0, "MEM1.3", "Double free is safely tolerated and returns 0 without crashing") == 1
    passed = passed + 1
  @end

  @! MEM1.4: Invalid Pointer Handling
  total = total + 1
  inv_res1 = memory_free(df_heap, 0)
  inv_res2 = memory_free(df_heap, 0 - 999)
  inv_res3 = memory_free(df_heap, 99999999)
  @if assert_test(inv_res1 == 0 && inv_res2 == 0 && inv_res3 == (0 - 1), "MEM1.4", "Invalid/unregistered pointers safely rejected") == 1
    passed = passed + 1
  @end

  @! MEM1.5: Canary Corruption Resistance
  total = total + 1
  can_heap = heap_new()
  can_p = memory_alloc(can_heap, 64)
  @! Find block and corrupt head canary
  can_blk_idx = 0
  @while can_blk_idx < can_heap.blocks.len()
    @if can_heap.blocks[can_blk_idx].addr == can_p
      can_heap.blocks[can_blk_idx].canary_head = 31337 @! Corrupt canary
      break
    @end
    can_blk_idx = can_blk_idx + 1
  @end
  can_free_res = memory_free(can_heap, can_p)
  @if assert_eq_num(can_free_res, 0 - 2, "MEM1.5", "Corrupted canary detected and rejected with code -2") == 1
    passed = passed + 1
  @end

  @! MEM1.6: High-Fragmentation Coalescing Stress
  total = total + 1
  frag_heap = heap_new()
  frag_ptrs = []
  f_i = 0
  @while f_i < 8
    frag_ptrs = frag_ptrs.push(memory_alloc(frag_heap, 64))
    f_i = f_i + 1
  @end
  @! Free alternating odd blocks first (1, 3, 5, 7)
  memory_free(frag_heap, frag_ptrs[1])
  memory_free(frag_heap, frag_ptrs[3])
  memory_free(frag_heap, frag_ptrs[5])
  memory_free(frag_heap, frag_ptrs[7])
  @! Now free even blocks to trigger adjacent coalescing merges
  memory_free(frag_heap, frag_ptrs[0])
  memory_free(frag_heap, frag_ptrs[2])
  memory_free(frag_heap, frag_ptrs[4])
  memory_free(frag_heap, frag_ptrs[6])
  st_frag = heap_stats(frag_heap)
  @if assert_test(st_frag.coalesce_events > 0 && st_frag.allocated_bytes == 0, "MEM1.6", "Interleaved deallocation triggers immediate coalescing merges") == 1
    passed = passed + 1
  @end

  @! MEM1.7: Realloc Boundary Invariants
  total = total + 1
  r_heap = heap_new()
  r_p1 = memory_alloc(r_heap, 32)
  memory_write32(r_p1, 123456789)
  @! Shrinking realloc reuses same pointer
  r_p2 = memory_realloc(r_heap, r_p1, 16)
  r_ok1 = (r_p2 == r_p1)
  @! Expanding realloc relocates and preserves data
  r_p3 = memory_realloc(r_heap, r_p2, 256)
  r_val = memory_read32(r_p3)
  r_ok2 = (r_val == 123456789)
  @! Realloc with size 0 frees pointer
  r_p4 = memory_realloc(r_heap, r_p3, 0)
  r_ok3 = (r_p4 == 0)
  @if assert_test(r_ok1 && r_ok2 && r_ok3, "MEM1.7", "memory_realloc correctly handles shrink-in-place, expansion with data copy, and size 0 free") == 1
    passed = passed + 1
  @end

  @! MEM1.8: Raw Memory Operations (8-bit, 16-bit, 32-bit Little-Endian)
  total = total + 1
  raw_heap = heap_new()
  raw_p = memory_alloc(raw_heap, 64)
  memory_set(raw_p, 0, 64)
  memory_write8(raw_p, 255)
  memory_write16(raw_p + 2, 65535)
  memory_write32(raw_p + 8, 305419896) @! 0x12345678
  m_b = memory_read8(raw_p)
  m_w = memory_read16(raw_p + 2)
  m_d = memory_read32(raw_p + 8)
  memory_free(raw_heap, raw_p)
  @if assert_test(m_b == 255 && m_w == 65535 && m_d == 305419896, "MEM1.8", "Memory read/write 8/16/32-bit little endian invariants verified") == 1
    passed = passed + 1
  @end

  @! ==========================================================================
  @! SECTION 2: FREESTANDING ARENA & TWO-FINGER COMPACTION (freestanding.maya)
  @! ==========================================================================
  println("\n▶ Section 2: Freestanding Arena & Two-Finger Compaction...")

  @! ARENA2.1: 2MB Arena Boundary Limits & Zero Syscalls
  total = total + 1
  arena = edge_arena_init(2097152) @! 2MB
  edge_arena_alloc(arena, 1, 1048576) @! 1MB
  edge_arena_alloc(arena, 2, 524288)  @! 512KB
  edge_arena_alloc(arena, 3, 524288)  @! 512KB
  oom_res = edge_arena_alloc(arena, 4, 1) @! Over capacity by 1 byte -> should return 0
  @if assert_test(arena.free_offset == 2097152 && oom_res == 0 && arena.syscalls_executed == 0, "ARENA2.1", "2MB exact boundary limits enforced with zero syscalls") == 1
    passed = passed + 1
  @end

  @! ARENA2.2: Alternating Live/Dead Objects Defragmentation Compaction
  total = total + 1
  c_arena = edge_arena_init(10000)
  edge_arena_alloc(c_arena, 10, 100)
  edge_arena_alloc(c_arena, 11, 200)
  edge_arena_alloc(c_arena, 12, 150)
  edge_arena_alloc(c_arena, 13, 300)
  edge_arena_alloc(c_arena, 14, 250)
  @! Mark odd objects as dead
  c_arena.live_objects[1].is_live = 0 @! obj 11 (200 bytes) dead
  c_arena.live_objects[3].is_live = 0 @! obj 13 (300 bytes) dead
  @! Run compaction
  edge_arena_defrag_compact(c_arena)
  @! Surviving live objects: obj 10 (100B), obj 12 (150B), obj 14 (250B) = Total 500 bytes
  c_ok1 = (c_arena.live_objects.len() == 3)
  c_ok2 = (c_arena.live_objects[0].mem_offset == 0)
  c_ok3 = (c_arena.live_objects[1].mem_offset == 100)
  c_ok4 = (c_arena.live_objects[2].mem_offset == 250)
  c_ok5 = (c_arena.free_offset == 500)
  c_ok6 = (c_arena.defrag_runs_count == 1)
  @if assert_test(c_ok1 && c_ok2 && c_ok3 && c_ok4 && c_ok5 && c_ok6, "ARENA2.2", "Two-finger compaction coalesced surviving objects contiguously at base offset 0") == 1
    passed = passed + 1
  @end

  @! ARENA2.3: ARM Cortex-M Vector Table Serialization & Thumb Invariant
  total = total + 1
  arm_vt = cortex_m_vector_table_new(536870912, 134217728) @! SP: 0x20000000, Reset: 0x08000000
  cortex_m_set_irq_handler(arm_vt, 0, 134217800)
  arm_bytes = cortex_m_serialize_vector_table(arm_vt)
  @! Reset handler must have Thumb bit set (134217728 | 1 = 134217729)
  @if assert_test(arm_vt.reset_handler == 134217729 && arm_bytes.len() == 192, "ARENA2.3", "ARM Cortex-M vector table serialized to 192 bytes with Thumb mode bit 0 enforced") == 1
    passed = passed + 1
  @end

  @! ARENA2.4: RISC-V MTVEC & Trap Table Serialization
  total = total + 1
  mtvec = riscv_encode_mtvec(2147483648, 1) @! 0x80000000, Vectored mode 1
  mt_base = riscv_decode_mtvec_base(mtvec)
  mt_mode = riscv_decode_mtvec_mode(mtvec)
  rv_trap = riscv_trap_table_new(2147483648, 1)
  rv_bytes = riscv_serialize_trap_table(rv_trap)
  @if assert_test(mt_base == 2147483648 && mt_mode == 1 && rv_bytes.len() == 128, "ARENA2.4", "RISC-V MTVEC encoded/decoded and trap table serialized to 128 bytes") == 1
    passed = passed + 1
  @end

  @! ARENA2.5: CRT0 Machine Code Emission & Hardware Simulator Verification
  total = total + 1
  crt0_cfg = freestanding_crt0_config_new(134217728, 134218752, 536870912, 64, 536870976, 128, 536875008, 134217736)
  arm_crt0 = cortex_m_emit_crt0_thumb(crt0_cfg)
  rv_crt0 = riscv_emit_crt0_rv32(crt0_cfg)
  
  sim = freestanding_sim_new(134217728, 536870912)
  @! Populate flash .data payload with pattern 0x55 (85)
  d_i = 0
  @while d_i < crt0_cfg.data_size
    freestanding_sim_write_flash(sim, d_i, 85) @! offset in flash
    d_i = d_i + 1
  @end
  freestanding_sim_execute_crt0(sim, crt0_cfg)
  bss_ok = freestanding_sim_verify_bss_zeroed(sim, crt0_cfg)
  @if assert_test(arm_crt0.len() == 48 && rv_crt0.len() == 48 && bss_ok == true, "ARENA2.5", "CRT0 Thumb/RV32 emitters valid (48B) and hardware memory simulator verified .bss zeroing") == 1
    passed = passed + 1
  @end

  @! ==========================================================================
  @! SECTION 3: VIRTUAL FILESYSTEM (VFS) STRESS & EDGE CASES (universe/os/vfs.maya)
  @! ==========================================================================
  println("\n▶ Section 3: Virtual Filesystem (VFS) Stress...")

  vfs = vfs_init()

  @! VFS3.1: Deep Directory Creation & File Hierarchy
  total = total + 1
  vfs_mkdir(vfs, "/home/maya", 493)
  vfs_mkdir(vfs, "/home/maya/projects", 493)
  vfs_mkdir(vfs, "/home/maya/projects/kernel", 493)
  vfs_mkdir(vfs, "/home/maya/projects/kernel/src", 493)
  
  src_node = vfs_lookup_path(vfs, "/home/maya/projects/kernel/src")
  dup_mkdir = vfs_mkdir(vfs, "/home/maya/projects/kernel/src", 493) @! EEXIST (-17)
  @if assert_test(src_node != 0 && src_node.kind == 2 && dup_mkdir == (0 - 17), "VFS3.1", "Deep 5-level directory hierarchy created and EEXIST returned for duplicate directory") == 1
    passed = passed + 1
  @end

  @! VFS3.2: File Creation, Write, Lseek & Read
  total = total + 1
  fd1 = vfs_open(vfs, "/home/maya/projects/kernel/src/main.maya", 64 | 2, 438) @! O_CREAT | O_RDWR
  test_data = [77, 97, 121, 97, 32, 79, 83] @! "Maya OS"
  vfs_write(vfs, fd1, test_data)
  
  @! Test Seek to beginning
  vfs_lseek(vfs, fd1, 0, 0) @! SEEK_SET 0
  read_back = vfs_read(vfs, fd1, 7)
  
  @! Test Negative seek error
  neg_seek = vfs_lseek(vfs, fd1, 0 - 50, 0) @! Should return EINVAL (-22)
  vfs_close(vfs, fd1)
  @if assert_test(read_back.len() == 7 && read_back[0] == 77 && read_back[6] == 83 && neg_seek == (0 - 22), "VFS3.2", "VFS file write, seek, read-back, and negative seek EINVAL invariant verified") == 1
    passed = passed + 1
  @end

  @! VFS3.3: Reading Past EOF & Zero-Length Reads
  total = total + 1
  fd_eof = vfs_open(vfs, "/home/maya/projects/kernel/src/main.maya", 0, 0)
  vfs_lseek(vfs, fd_eof, 1000, 0) @! Seek far past EOF
  past_eof_read = vfs_read(vfs, fd_eof, 50)
  zero_read = vfs_read(vfs, fd_eof, 0)
  vfs_close(vfs, fd_eof)
  @if assert_test(past_eof_read.len() == 0 && zero_read.len() == 0, "VFS3.3", "Reading past EOF or requesting 0 bytes cleanly returns empty array") == 1
    passed = passed + 1
  @end

  @! VFS3.4: DevFS Edge Cases (/dev/null, /dev/zero, /dev/random)
  total = total + 1
  @! /dev/null
  fd_null = vfs_open(vfs, "/dev/null", 2, 0)
  null_read = vfs_read(vfs, fd_null, 100) @! EOF immediately
  null_write = vfs_write(vfs, fd_null, [1, 2, 3, 4, 5]) @! Discards and returns length
  vfs_close(vfs, fd_null)

  @! /dev/zero
  fd_zero = vfs_open(vfs, "/dev/zero", 2, 0)
  zero_bytes = vfs_read(vfs, fd_zero, 64)
  all_zeros = 1
  z_i = 0
  @while z_i < zero_bytes.len()
    @if zero_bytes[z_i] != 0 all_zeros = 0 @end
    z_i = z_i + 1
  @end
  vfs_close(vfs, fd_zero)

  @! /dev/random
  fd_rand = vfs_open(vfs, "/dev/random", 2, 0)
  rand_bytes = vfs_read(vfs, fd_rand, 32)
  vfs_write(vfs, fd_rand, [123, 45, 67, 89]) @! Seed PRNG
  rand_bytes_after = vfs_read(vfs, fd_rand, 32)
  vfs_close(vfs, fd_rand)

  devfs_ok = (null_read.len() == 0 && null_write == 5 && zero_bytes.len() == 64 && all_zeros == 1 && rand_bytes.len() == 32 && rand_bytes_after.len() == 32)
  @if assert_test(devfs_ok, "VFS3.4", "DevFS /dev/null, /dev/zero, /dev/random character device semantics verified") == 1
    passed = passed + 1
  @end

  @! VFS3.5: File Truncation (O_TRUNC) and Unlink (vfs_unlink)
  total = total + 1
  fd_trunc = vfs_open(vfs, "/tmp/trunc_test.txt", 64 | 2, 438)
  vfs_write(vfs, fd_trunc, [1, 2, 3, 4, 5, 6, 7, 8])
  vfs_close(vfs, fd_trunc)
  
  @! Reopen with O_TRUNC (512)
  fd_reopen = vfs_open(vfs, "/tmp/trunc_test.txt", 512 | 2, 438)
  st_trunc = vfs_stat(vfs, "/tmp/trunc_test.txt")
  vfs_close(vfs, fd_reopen)

  @! Unlink file
  unl_res = vfs_unlink(vfs, "/tmp/trunc_test.txt")
  unl_stat = vfs_stat(vfs, "/tmp/trunc_test.txt")
  @! Attempt to unlink directory returns EISDIR (-21)
  unl_dir = vfs_unlink(vfs, "/tmp")
  
  @if assert_test(st_trunc.size == 0 && unl_res == 0 && unl_stat == 0 && unl_dir == (0 - 21), "VFS3.5", "O_TRUNC zeroes file size, vfs_unlink purges inode, and directory unlink returns EISDIR") == 1
    passed = passed + 1
  @end

  @! ==========================================================================
  @! SECTION 4: IPC SUBSYSTEM STRESS & BOUNDARIES (universe/os/ipc.maya)
  @! ==========================================================================
  println("\n▶ Section 4: Inter-Process Communication (IPC) Stress...")

  @! IPC4.1: FIFO Ring Buffer Wrap-Around & Full-Capacity Boundary
  total = total + 1
  fifo = ipc_fifo_create("test_fifo", 16)
  
  @! Write 10 bytes: positions 0..9
  w1 = ipc_fifo_write(fifo, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  @! Read 8 bytes: read_ptr moves to 8, count is now 2
  r1 = ipc_fifo_read(fifo, 8)
  @! Write 12 bytes: wraps around past index 15 to 0..3, count is now 14
  w2 = ipc_fifo_write(fifo, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22])
  @! Write 10 bytes when only 2 slots remain: should write exactly 2 bytes
  w3 = ipc_fifo_write(fifo, [23, 24, 25, 26, 27, 28, 29, 30, 31, 32])
  @! Now read all 16 bytes: should reconstruct the exact continuous stream
  r2 = ipc_fifo_read(fifo, 16)
  
  fifo_wrap_ok = (w1 == 10 && r1.len() == 8 && w2 == 12 && w3 == 2 && r2.len() == 16 && r2[0] == 9 && r2[1] == 10 && r2[2] == 11 && r2[15] == 24)
  @if assert_test(fifo_wrap_ok, "IPC4.1", "FIFO ring buffer capacity limit and circular index wrap-around verified") == 1
    passed = passed + 1
  @end

  @! IPC4.2: Shared Memory Boundary Invariants
  total = total + 1
  shm = ipc_shm_create("shm_seg1", 64, 438)
  shm_w1 = ipc_shm_write_at(shm, 0, [65, 66, 67, 68])
  shm_r1 = ipc_shm_read_at(shm, 0, 4)
  @! Out of bounds write
  shm_oob_w = ipc_shm_write_at(shm, 70, [1, 2, 3]) @! EINVAL (-22)
  shm_oob_r = ipc_shm_read_at(shm, 70, 4)          @! empty []
  @if assert_test(shm_w1 == 4 && shm_r1[0] == 65 && shm_oob_w == (0 - 22) && shm_oob_r.len() == 0, "IPC4.2", "Shared memory valid read/write and out-of-bounds EINVAL enforcement verified") == 1
    passed = passed + 1
  @end

  @! IPC4.3: Unix Domain Sockets State Transitions & Error Paths
  total = total + 1
  server_sock = ipc_uds_socket(1) @! SOCK_STREAM
  client_sock = ipc_uds_socket(1)
  
  @! Connect before listen returns ECONNREFUSED (-111)
  unconnected_conn = ipc_uds_connect(client_sock, server_sock)
  
  ipc_uds_bind(server_sock, "/tmp/maya_uds.sock")
  ipc_uds_listen(server_sock, 5)
  conn_res = ipc_uds_connect(client_sock, server_sock)
  
  send_res = ipc_uds_send(client_sock, [10, 20, 30, 40])
  recv_res = ipc_uds_recv(server_sock, 2) @! Read first 2 bytes
  rem_res = ipc_uds_recv(server_sock, 10)  @! Read remaining 2 bytes
  
  ipc_uds_close(client_sock)
  ipc_uds_close(server_sock)
  @if assert_test(unconnected_conn == (0 - 111) && conn_res == 0 && send_res == 4 && recv_res.len() == 2 && rem_res.len() == 2, "IPC4.3", "Unix Domain Socket bind/listen/connect handshake and buffered recv verified") == 1
    passed = passed + 1
  @end

  @! IPC4.4: Priority Message Queue Under Burst Invariants
  total = total + 1
  mq = ipc_mq_open("priority_queue", 10, 32)
  
  @! Enqueue with mixed, scrambled priorities
  ipc_mq_send(mq, [10], 10, 100)
  ipc_mq_send(mq, [99], 99, 101)
  ipc_mq_send(mq, [5], 5, 102)
  ipc_mq_send(mq, [50], 50, 103)
  ipc_mq_send(mq, [75], 75, 104)
  ipc_mq_send(mq, [1], 1, 105)
  
  @! Dequeue order must be strictly descending: 99, 75, 50, 10, 5, 1
  m1 = ipc_mq_receive(mq)
  m2 = ipc_mq_receive(mq)
  m3 = ipc_mq_receive(mq)
  m4 = ipc_mq_receive(mq)
  m5 = ipc_mq_receive(mq)
  m6 = ipc_mq_receive(mq)
  m7 = ipc_mq_receive(mq) @! Empty queue returns 0
  
  mq_ok = (m1.priority == 99 && m2.priority == 75 && m3.priority == 50 && m4.priority == 10 && m5.priority == 5 && m6.priority == 1 && m7 == 0)
  @if assert_test(mq_ok, "IPC4.4", "Message queue prioritized burst dequeues in strict descending priority order") == 1
    passed = passed + 1
  @end

  @! IPC4.5: Counting Semaphore Waiter Queue & Clamping
  total = total + 1
  sem = ipc_sem_init(1, 2) @! init=1, max=2
  w_r1 = ipc_sem_wait(sem) @! acquired=1, val=0
  w_r2 = ipc_sem_wait(sem) @! acquired=0, blocked=1, waiters_count=1
  w_r3 = ipc_sem_wait(sem) @! acquired=0, blocked=1, waiters_count=2
  
  ipc_sem_post(sem) @! wakes waiter 1, waiters_count=1, val=0
  ipc_sem_post(sem) @! wakes waiter 2, waiters_count=0, val=0
  ipc_sem_post(sem) @! val=1
  ipc_sem_post(sem) @! val=2 (max)
  ipc_sem_post(sem) @! clamped at 2
  
  sem_ok = (w_r1.acquired == 1 && w_r2.blocked == 1 && w_r3.blocked == 1 && sem.waiters_count == 0 && sem.value == 2)
  @if assert_test(sem_ok, "IPC4.5", "Counting semaphore handles blocking waiters, post-wakeups, and max value clamping") == 1
    passed = passed + 1
  @end

  @! IPC4.6: Mutex Ownership & Contention
  total = total + 1
  mtx = ipc_mutex_init()
  mtx_l1 = ipc_mutex_lock(mtx, 1001) @! Task 1001 locks
  mtx_l2 = ipc_mutex_lock(mtx, 1002) @! Task 1002 fails (blocked)
  mtx_u_fail = ipc_mutex_unlock(mtx, 1002) @! Task 1002 cannot unlock -> EPERM (-1)
  mtx_u_ok = ipc_mutex_unlock(mtx, 1001)   @! Task 1001 unlocks -> 1
  mtx_l3 = ipc_mutex_lock(mtx, 1002) @! Task 1002 can now lock
  
  mtx_ok = (mtx_l1.acquired == 1 && mtx_l2.blocked == 1 && mtx_u_fail == (0 - 1) && mtx_u_ok == 1 && mtx_l3.acquired == 1)
  @if assert_test(mtx_ok, "IPC4.6", "Mutex ownership validation, lock contention, and non-owner unlock rejection verified") == 1
    passed = passed + 1
  @end

  @! ==========================================================================
  @! SECTION 5: PAGING, GDT & BOOT DESCRIPTORS (universe/os/boot/)
  @! ==========================================================================
  println("\n▶ Section 5: Paging, GDT & Boot Descriptors...")

  @! BOOT5.1: 4-Level MMU Virtual Address Bit Decomposition
  total = total + 1
  @! Test 0x0000000000201ABC -> offset 0xABC (2748), PT index 1, PD index 1, PDPT 0, PML4 0
  v1 = paging_decompose_virtual_addr(2103996)
  v1_ok = (v1.offset == 2748 && v1.pt_idx == 1 && v1.pd_idx == 1 && v1.pdpt_idx == 0 && v1.pml4_idx == 0)
  
  @! Test 1GB Boundary + 2MB: 1073741824 + 2097152 = 1075838976
  v2 = paging_decompose_virtual_addr(1075838976)
  v2_ok = (v2.offset == 0 && v2.pt_idx == 0 && v2.pd_idx == 1 && v2.pdpt_idx == 1 && v2.pml4_idx == 0)
  @if assert_test(v1_ok && v2_ok, "BOOT5.1", "4-level MMU virtual address bit decomposition into PML4/PDPT/PD/PT/offset verified") == 1
    passed = passed + 1
  @end

  @! BOOT5.2: Page Table Entry Encoder/Decoder Round-Trip
  total = total + 1
  p_entry = {
    frame_addr: 536870912, @! 512MB
    present: 1,
    writable: 1,
    user: 1,
    write_through: 0,
    cache_disable: 0,
    accessed: 1,
    dirty: 1,
    huge: 1,
    global: 1
  }
  enc_val = page_entry_encode(p_entry)
  dec_entry = page_entry_decode(enc_val)
  
  pte_ok = (dec_entry.frame_addr == 536870912 && dec_entry.present == 1 && dec_entry.writable == 1 && dec_entry.user == 1 && dec_entry.accessed == 1 && dec_entry.dirty == 1 && dec_entry.huge == 1 && dec_entry.global == 1)
  @if assert_test(pte_ok, "BOOT5.2", "Page table entry 64-bit flag encoding/decoding round-trip verified") == 1
    passed = passed + 1
  @end

  @! BOOT5.3: 1GB Identity Map Generation & Table Serialization
  total = total + 1
  map1gb = paging_create_identity_map_1gb(4096, 8192, 12288)
  pml4_ser = paging_serialize_table(map1gb.pml4)
  pd_ser = paging_serialize_table(map1gb.pd)
  @! Verify PD entry 0 has 2MB Huge bit set (128) and Global (256)
  pd0_dec = page_entry_decode(map1gb.pd[0])
  pd511_dec = page_entry_decode(map1gb.pd[511])
  
  idmap_ok = (pml4_ser.len() == 4096 && pd_ser.len() == 4096 && pd0_dec.huge == 1 && pd0_dec.frame_addr == 0 && pd511_dec.frame_addr == (511 * 2097152))
  @if assert_test(idmap_ok, "BOOT5.3", "1GB identity map tables correctly generated with 512x 2MB huge pages serialized to 4096 bytes") == 1
    passed = passed + 1
  @end

  @! BOOT5.4: Long Mode GDT Descriptors & Selectors
  total = total + 1
  gdt_tbl = gdt_table_new(65536, 104)
  gdt_bytes = gdt_serialize(gdt_tbl)
  gdtr = gdtr_create(2097152, gdt_bytes.len())
  gdtr_bytes = gdtr_serialize(gdtr)
  
  sel_ok1 = (GDT_NULL_SEL() == 0 && GDT_KERNEL_CS_SEL() == 8 && GDT_KERNEL_DS_SEL() == 16)
  sel_ok2 = (GDT_USER_CS_SEL() == 27 && GDT_USER_DS_SEL() == 35 && GDT_TSS_SEL() == 40)
  gdt_ok = (sel_ok1 && sel_ok2 && gdt_bytes.len() == 56 && gdtr_bytes.len() == 10)
  @if assert_test(gdt_ok, "BOOT5.4", "Long mode GDT table (56B) and GDTR register descriptor (10B) correctly encoded") == 1
    passed = passed + 1
  @end

  @! BOOT5.5: Multiboot 1 & Multiboot 2 Header Emission
  total = total + 1
  mb1 = multiboot1_create_header(1048576, 1024, 768, 32)
  mb1_bytes = multiboot1_serialize_header(mb1)
  @! Multiboot 1 checksum invariant: magic + flags + checksum == 0
  mb1_chk_ok = ((mb1.magic + mb1.flags + mb1.checksum) == 0)

  mb2 = multiboot2_create_header(1920, 1080, 32)
  mb2_bytes = multiboot2_serialize_binary(mb2, 1920, 1080, 32)
  @! Multiboot 2 checksum invariant: magic + arch + len + checksum == 0
  mb2_chk_ok = ((mb2.magic + mb2.architecture + mb2.header_length + mb2.checksum) == 0)

  mb_ok = (mb1_chk_ok && mb1_bytes.len() == 48 && mb2_chk_ok && mb2_bytes.len() == 44)
  @if assert_test(mb_ok, "BOOT5.5", "Multiboot 1 (48B) and Multiboot 2 (44B) headers emitted with valid specification checksums") == 1
    passed = passed + 1
  @end

  @! ==========================================================================
  @! FINAL SUMMARY
  @! ==========================================================================
  println("\n=================================================================")
  println("🏆 ADVERSARIAL STRESS SUITE RESULTS:")
  println("   Total Tests:  " + total.to_str())
  println("   Passed Tests: " + passed.to_str())
  println("   Failed Tests: " + (total - passed).to_str())
  @if passed == total
    println("🎉 ALL OS KERNEL STRESS TESTS PASSED WITH 100% PURITY & INTEGRITY!")
  @else
    println("❌ SOME STRESS TESTS FAILED!")
  @end
  println("=================================================================")
@end
