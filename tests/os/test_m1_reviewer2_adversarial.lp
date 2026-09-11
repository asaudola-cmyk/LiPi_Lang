@! ============================================================================
@! REVIEWER 2 ADVERSARIAL STRESS TEST: F05-F08 (tests/os/test_m1_reviewer2_adversarial.maya)
@! Independent Verification of Memory, VFS, IPC, Boot, HAL & Kernel Subsystems
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/memory"
import "universe/os/freestanding"
import "universe/os/vfs"
import "universe/os/ipc"
import "universe/os/hal"
import "universe/os/boot/gdt"
import "universe/os/boot/paging"
import "universe/os/kernel"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔬 REVIEWER 2: ADVERSARIAL STRESS TEST SUITE (F05-F08) 🔬")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! TEST 1: F05 Heap Memory Allocator, Splitting, Coalescing & Canaries
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 1] Heap Allocator, Block Splitting, Canary Tampering & Coalescing...")
  total_tests = total_tests + 1
  fail_f05 = 0

  heap = heap_new()

  @! Allocate 4 contiguous blocks: A (32), B (64), C (128), D (256)
  ptr_a = memory_alloc(heap, 32)
  ptr_b = memory_alloc(heap, 64)
  ptr_c = memory_alloc(heap, 128)
  ptr_d = memory_alloc(heap, 256)

  @if assert_true(ptr_a > 0 && ptr_b > 0 && ptr_c > 0 && ptr_d > 0, "All 4 heap allocations succeeded") == 0
    fail_f05 = fail_f05 + 1
  @end

  @! Verify size classes
  @if assert_eq_int(memory_size_class(8), 0, "8 bytes -> Bin 0") == 0 fail_f05 = fail_f05 + 1 @end
  @if assert_eq_int(memory_size_class(32), 0, "32 bytes -> Bin 0") == 0 fail_f05 = fail_f05 + 1 @end
  @if assert_eq_int(memory_size_class(33), 1, "33 bytes -> Bin 1") == 0 fail_f05 = fail_f05 + 1 @end
  @if assert_eq_int(memory_size_class(64), 1, "64 bytes -> Bin 1") == 0 fail_f05 = fail_f05 + 1 @end
  @if assert_eq_int(memory_size_class(1024), 5, "1024 bytes -> Bin 5") == 0 fail_f05 = fail_f05 + 1 @end
  @if assert_eq_int(memory_size_class(5000), 8, "5000 bytes -> Bin 8") == 0 fail_f05 = fail_f05 + 1 @end

  @! Canary Tampering Stress: Intentionally corrupt block header canary
  blk_a = heap.blocks[0]
  blk_a.canary_head = 12345678 @! Corrupt canary_head
  free_corrupt_res = memory_free(heap, ptr_a)
  @if assert_eq_int(free_corrupt_res, 0 - 2, "Memory corruption detected on tampered canary head") == 0
    fail_f05 = fail_f05 + 1
  @end

  @! Restore canary and free cleanly
  blk_a.canary_head = CANARY_HEAD()
  free_clean_a = memory_free(heap, ptr_a)
  @if assert_eq_int(free_clean_a, 0, "Block A freed cleanly after restoring canary") == 0
    fail_f05 = fail_f05 + 1
  @end

  @! Double free test
  double_free_res = memory_free(heap, ptr_a)
  @if assert_eq_int(double_free_res, 0, "Double free handled gracefully (ignored)") == 0
    fail_f05 = fail_f05 + 1
  @end

  @! Invalid pointer free test
  inv_free_res = memory_free(heap, 9999999)
  @if assert_eq_int(inv_free_res, 0 - 1, "Freeing non-existent pointer returns -1") == 0
    fail_f05 = fail_f05 + 1
  @end

  @! Free B and C to trigger multi-block coalescing
  memory_free(heap, ptr_b)
  memory_free(heap, ptr_c)
  memory_free(heap, ptr_d)

  stats = heap_stats(heap)
  @if assert_eq_int(stats.allocated_bytes, 0, "All allocations reclaimed to 0 bytes allocated") == 0
    fail_f05 = fail_f05 + 1
  @end
  @if assert_true(stats.coalesce_events >= 1, "Coalescing events triggered successfully") == 0
    fail_f05 = fail_f05 + 1
  @end

  @! Realloc Test: Shrink, Expand, and Free
  p_re = memory_alloc(heap, 64)
  p_re2 = memory_realloc(heap, p_re, 32) @! Shrink / reuse
  @if assert_eq_int(p_re2, p_re, "Realloc to smaller size reuses same pointer") == 0
    fail_f05 = fail_f05 + 1
  @end
  p_re3 = memory_realloc(heap, p_re, 512) @! Expand (new allocation)
  @if assert_true(p_re3 > 0, "Realloc expansion returned valid pointer") == 0
    fail_f05 = fail_f05 + 1
  @end
  memory_realloc(heap, p_re3, 0) @! Realloc size 0 frees pointer

  @if fail_f05 == 0
    passed_tests = passed_tests + 1
    println("  [PASS] F05 heap memory allocator & canary integrity tests passed.")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 2: F06 Virtual Filesystem (VFS) Pathing, DevFS & Error Modes
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 2] VFS Deep Hierarchy, Char Devices & Error Boundaries...")
  total_tests = total_tests + 1
  fail_f06 = 0

  vfs = vfs_init()

  @! Deep directory hierarchy creation: /home/user/workspace/docs
  @if assert_eq_int(vfs_mkdir(vfs, "/home/user", 493), 0, "mkdir /home/user") == 0 fail_f06 = fail_f06 + 1 @end
  @if assert_eq_int(vfs_mkdir(vfs, "/home/user/workspace", 493), 0, "mkdir /home/user/workspace") == 0 fail_f06 = fail_f06 + 1 @end
  @if assert_eq_int(vfs_mkdir(vfs, "/home/user/workspace/docs", 493), 0, "mkdir /home/user/workspace/docs") == 0 fail_f06 = fail_f06 + 1 @end

  @! EEXIST on creating duplicate directory
  @if assert_eq_int(vfs_mkdir(vfs, "/home/user", 493), 0 - 17, "mkdir duplicate returns EEXIST (-17)") == 0
    fail_f06 = fail_f06 + 1
  @end

  @! ENOENT on creating in non-existent parent
  @if assert_eq_int(vfs_mkdir(vfs, "/nonexistent/sub", 493), 0 - 2, "mkdir in missing parent returns ENOENT (-2)") == 0
    fail_f06 = fail_f06 + 1
  @end

  @! Create file in deep path
  fd_file = vfs_open(vfs, "/home/user/workspace/docs/notes.txt", 64 | 2, 420)
  @if assert_true(fd_file >= 3, "Opened file in deep hierarchy with fd >= 3") == 0
    fail_f06 = fail_f06 + 1
  @end

  @! Write and Read with Seeking
  w_len = vfs_write(vfs, fd_file, [65, 66, 67, 68, 69, 70]) @! "ABCDEF"
  @if assert_eq_int(w_len, 6, "Wrote 6 bytes to file") == 0 fail_f06 = fail_f06 + 1 @end

  @! Seek CUR (+2 from 6 -> 8) then SET (2)
  vfs_lseek(vfs, fd_file, 2, 0) @! SEEK_SET to offset 2 ('C')
  r_part = vfs_read(vfs, fd_file, 3)
  @if assert_eq_int(r_part.len(), 3, "Read 3 bytes from offset 2") == 0 fail_f06 = fail_f06 + 1 @end
  @if assert_eq_int(r_part[0], 67, "Byte 0 at offset 2 is 'C' (67)") == 0 fail_f06 = fail_f06 + 1 @end
  @if assert_eq_int(r_part[1], 68, "Byte 1 is 'D' (68)") == 0 fail_f06 = fail_f06 + 1 @end
  @if assert_eq_int(r_part[2], 69, "Byte 2 is 'E' (69)") == 0 fail_f06 = fail_f06 + 1 @end

  @! Seek past END
  vfs_lseek(vfs, fd_file, 0, 2) @! SEEK_END
  r_eof = vfs_read(vfs, fd_file, 5)
  @if assert_eq_int(r_eof.len(), 0, "Read at SEEK_END returns EOF empty array") == 0
    fail_f06 = fail_f06 + 1
  @end

  @! Invalid Seek (< 0) returns EINVAL (-22)
  seek_inv = vfs_lseek(vfs, fd_file, 0 - 10, 0)
  @if assert_eq_int(seek_inv, 0 - 22, "Negative seek offset returns EINVAL (-22)") == 0
    fail_f06 = fail_f06 + 1
  @end

  vfs_close(vfs, fd_file)

  @! EBADF on reading closed fd
  r_closed = vfs_read(vfs, fd_file, 5)
  @if assert_eq_int(r_closed.len(), 0, "Read on closed fd returns empty") == 0
    fail_f06 = fail_f06 + 1
  @end

  @! DevFS /dev/random & /dev/urandom seeding and PRNG verification
  fd_rand = vfs_open(vfs, "/dev/random", 2, 438)
  vfs_write(vfs, fd_rand, [1, 2, 3, 4]) @! Seed PRNG
  rand_bytes = vfs_read(vfs, fd_rand, 16)
  @if assert_eq_int(rand_bytes.len(), 16, "Generated 16 random bytes from /dev/random") == 0
    fail_f06 = fail_f06 + 1
  @end
  vfs_close(vfs, fd_rand)

  @! Unlink file and verify ENOENT afterwards
  @if assert_eq_int(vfs_unlink(vfs, "/home/user/workspace/docs/notes.txt"), 0, "Unlinked notes.txt") == 0
    fail_f06 = fail_f06 + 1
  @end
  st_gone = vfs_stat(vfs, "/home/user/workspace/docs/notes.txt")
  @if assert_eq_int(st_gone, 0, "vfs_stat returns 0 for unlinked file") == 0
    fail_f06 = fail_f06 + 1
  @end

  @! EISDIR on unlinking a directory
  unl_dir = vfs_unlink(vfs, "/home/user/workspace/docs")
  @if assert_eq_int(unl_dir, 0 - 21, "vfs_unlink on directory returns EISDIR (-21)") == 0
    fail_f06 = fail_f06 + 1
  @end

  @if fail_f06 == 0
    passed_tests = passed_tests + 1
    println("  [PASS] F06 VFS pathing, devices and error boundary tests passed.")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 3: F07 Inter-Process Communication (IPC) Comprehensive Concurrency
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 3] IPC FIFO Full/Empty, Sockets State Machine, MQ Preemption & Mutex Ownership...")
  total_tests = total_tests + 1
  fail_f07 = 0

  @! 3.1 FIFO Ring Buffer Overflow Stress
  fifo = ipc_fifo_create("tight_pipe", 4)
  w1 = ipc_fifo_write(fifo, [10, 20, 30, 40])
  @if assert_eq_int(w1, 4, "Filled FIFO buffer to capacity (4 bytes)") == 0 fail_f07 = fail_f07 + 1 @end
  w_full = ipc_fifo_write(fifo, [50, 60])
  @if assert_eq_int(w_full, 0, "Writing to full FIFO returns 0 (no overrun)") == 0 fail_f07 = fail_f07 + 1 @end
  ipc_fifo_close(fifo)
  w_closed = ipc_fifo_write(fifo, [1])
  @if assert_eq_int(w_closed, 0 - 32, "Writing to closed FIFO returns EPIPE (-32)") == 0 fail_f07 = fail_f07 + 1 @end

  @! 3.2 Shared Memory Out of Bounds Stress
  shm = ipc_shm_create("shm_test", 32, 438)
  w_shm_oob = ipc_shm_write_at(shm, 40, [1, 2, 3])
  @if assert_eq_int(w_shm_oob, 0 - 22, "Write at OOB offset returns EINVAL (-22)") == 0 fail_f07 = fail_f07 + 1 @end
  r_shm_oob = ipc_shm_read_at(shm, 40, 5)
  @if assert_eq_int(r_shm_oob.len(), 0, "Read at OOB offset returns empty array") == 0 fail_f07 = fail_f07 + 1 @end

  @! 3.3 Unix Domain Sockets State Machine Stress
  s1 = ipc_uds_socket(1)
  s2 = ipc_uds_socket(1)
  @! Connect before listen returns ECONNREFUSED (-111)
  conn_unbound = ipc_uds_connect(s2, s1)
  @if assert_eq_int(conn_unbound, 0 - 111, "Connecting to unlistening socket returns ECONNREFUSED (-111)") == 0
    fail_f07 = fail_f07 + 1
  @end
  @! Send before connect returns ENOTCONN (-107)
  send_unconn = ipc_uds_send(s2, [1, 2])
  @if assert_eq_int(send_unconn, 0 - 107, "Sending on unconnected socket returns ENOTCONN (-107)") == 0
    fail_f07 = fail_f07 + 1
  @end
  @! Proper handshake sequence
  ipc_uds_bind(s1, "/tmp/svc.sock")
  ipc_uds_listen(s1, 5)
  ipc_uds_connect(s2, s1)
  ipc_uds_send(s2, [77, 88, 99])
  rx_data = ipc_uds_recv(s1, 2)
  @if assert_eq_int(rx_data.len(), 2, "Partial recv of 2 bytes") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(rx_data[0], 77, "First received byte is 77") == 0 fail_f07 = fail_f07 + 1 @end
  rx_rem = ipc_uds_recv(s1, 2)
  @if assert_eq_int(rx_rem.len(), 1, "Remaining 1 byte received") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(rx_rem[0], 99, "Remaining byte is 99") == 0 fail_f07 = fail_f07 + 1 @end

  @! 3.4 Message Queue Priority Ordering Stress (5 messages inserted randomly)
  mq = ipc_mq_open("stress_mq", 10, 128)
  ipc_mq_send(mq, [10], 1, 100)
  ipc_mq_send(mq, [50], 5, 101)
  ipc_mq_send(mq, [30], 3, 102)
  ipc_mq_send(mq, [90], 9, 103)
  ipc_mq_send(mq, [20], 2, 104)

  m1 = ipc_mq_receive(mq)
  m2 = ipc_mq_receive(mq)
  m3 = ipc_mq_receive(mq)
  m4 = ipc_mq_receive(mq)
  m5 = ipc_mq_receive(mq)
  m_none = ipc_mq_receive(mq)

  @if assert_eq_int(m1.data[0], 90, "Priority 9 dequeued 1st") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(m2.data[0], 50, "Priority 5 dequeued 2nd") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(m3.data[0], 30, "Priority 3 dequeued 3rd") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(m4.data[0], 20, "Priority 2 dequeued 4th") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(m5.data[0], 10, "Priority 1 dequeued 5th") == 0 fail_f07 = fail_f07 + 1 @end
  @if assert_eq_int(m_none, 0, "Empty queue receive returns 0") == 0 fail_f07 = fail_f07 + 1 @end

  @! 3.5 Mutex Ownership Enforcement Stress
  mut = ipc_mutex_init()
  l1 = ipc_mutex_lock(mut, 1001)
  @if assert_eq_int(l1.acquired, 1, "Task 1001 acquired mutex") == 0 fail_f07 = fail_f07 + 1 @end
  @! Rogue task 9999 attempts unlock
  unl_rogue = ipc_mutex_unlock(mut, 9999)
  @if assert_eq_int(unl_rogue, 0 - 1, "Unlock by non-owner rejected with EPERM (-1)") == 0
    fail_f07 = fail_f07 + 1
  @end
  @if assert_eq_int(mut.locked, 1, "Mutex remains locked after rogue unlock attempt") == 0
    fail_f07 = fail_f07 + 1
  @end
  ipc_mutex_unlock(mut, 1001)
  @if assert_eq_int(mut.locked, 0, "Mutex unlocked by legitimate owner") == 0 fail_f07 = fail_f07 + 1 @end

  @if fail_f07 == 0
    passed_tests = passed_tests + 1
    println("  [PASS] F07 IPC concurrency, socket state machines & mutex ownership tests passed.")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 4: F08 HAL, 64-Bit GDT, 4-Level MMU Paging & Microkernel Loop
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 4] Long Mode GDT Serialization, 4-Level Virtual Address Math & Microkernel...")
  total_tests = total_tests + 1
  fail_f08 = 0

  @! 4.1 GDT 56-byte Descriptor Layout Validation
  gdt = gdt_table_new(0x200000, 104)
  gdt_bytes = gdt_serialize(gdt)
  @if assert_eq_int(gdt_bytes.len(), 56, "GDT table binary is exactly 56 bytes") == 0 fail_f08 = fail_f08 + 1 @end
  @! Check Kernel CS (Selector 0x08, Entry 1: Access 0x9A at offset 8+5=13)
  @if assert_eq_int(gdt_bytes[13], 154, "Kernel Code Segment Access Byte is 0x9A (154)") == 0 fail_f08 = fail_f08 + 1 @end
  @! Check User CS (Selector 0x1B, Entry 3: Access 0xFA at offset 24+5=29)
  @if assert_eq_int(gdt_bytes[29], 250, "User Code Segment Access Byte is 0xFA (250)") == 0 fail_f08 = fail_f08 + 1 @end

  @! 4.2 4-Level MMU Decomposition Stress across Boundary Addresses
  @! Virtual Address 0x00007FFFF7DCB042 (140737351823426)
  d1 = paging_decompose_virtual_addr(140737351823426)
  @if assert_eq_int(d1.offset, 66, "Offset is 0x42 (66)") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(d1.pt_idx, 459, "PT index calculated correctly") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(d1.pd_idx, 507, "PD index calculated correctly") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(d1.pdpt_idx, 511, "PDPT index calculated correctly") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(d1.pml4_idx, 255, "PML4 index calculated correctly") == 0 fail_f08 = fail_f08 + 1 @end

  @! 4.3 Full 1GB Identity Map Page Tables Serialization (PML4, PDPT, PD)
  p_map = paging_create_identity_map_1gb(0x200000, 0x201000, 0x202000)
  pml4_serialized = paging_serialize_table(p_map.pml4)
  pdpt_serialized = paging_serialize_table(p_map.pdpt)
  pd_serialized = paging_serialize_table(p_map.pd)
  @if assert_eq_int(pml4_serialized.len(), 4096, "PML4 table serialized to 4096 bytes (512 entries x 8 bytes)") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(pdpt_serialized.len(), 4096, "PDPT table serialized to 4096 bytes") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(pd_serialized.len(), 4096, "PD table serialized to 4096 bytes (512 x 2MB huge pages = 1GB)") == 0 fail_f08 = fail_f08 + 1 @end

  @! 4.4 Master Microkernel Boot & 100-Tick Event Loop Orchestration
  kernel = kernel_init()
  @if assert_eq_str(kernel.state, "RUNNING", "Kernel initialized to RUNNING state") == 0 fail_f08 = fail_f08 + 1 @end
  kernel = kernel_run(kernel, 100)
  k_status = kernel_status(kernel)
  @if assert_eq_int(k_status.uptime_ticks, 100, "Kernel advanced exactly 100 ticks") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_true(k_status.total_tasks >= 2, "Kernel managing tasks (idle + init)") == 0 fail_f08 = fail_f08 + 1 @end
  @if assert_eq_int(k_status.interrupts_enabled, 1, "Hardware interrupts enabled during kernel run") == 0 fail_f08 = fail_f08 + 1 @end

  @if fail_f08 == 0
    passed_tests = passed_tests + 1
    println("  [PASS] F08 HAL, Long Mode GDT, 4-Level MMU paging & microkernel tests passed.")
  @end

  println("=================================================================")
  println("📊 REVIEWER 2 ADVERSARIAL RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " sections passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 4 ADVERSARIAL STRESS TEST SUITES PASSED! (100% SUCCESS) 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL STRESS TEST FAILURES DETECTED")
    return 1
  @end
@end
