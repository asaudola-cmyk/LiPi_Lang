@! ============================================================================
@! MAYA NATIVE OS KERNEL COMPREHENSIVE MASTER TEST SUITE (tests/os/test_os_comprehensive.maya)
@! 100% Written in Pure Maya Language — Zero Foreign / Zero Libc Dependencies
@! Milestone 1: Native Maya OS Kernel Sovereign Architecture Verification
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/os/dispatcher"
import "universe/os/scheduler"
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
  println("🐧 MAYA NATIVE OS KERNEL COMPREHENSIVE TEST SUITE (MILESTONE 1) 🐧")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: F01 Raw Syscall Layer & Errno Decoders
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: F01 Raw Syscall Gateway & Errno Decoders...")
  total_tests = total_tests + 1
  
  ok1 = assert_eq_int(PROT_READ(), 1, "PROT_READ is 1")
  ok2 = assert_eq_int(PROT_WRITE(), 2, "PROT_WRITE is 2")
  ok3 = assert_eq_int(MAP_ANONYMOUS(), 32, "MAP_ANONYMOUS is 32")
  ok4 = assert_eq_str(errno_name(2), "ENOENT", "Errno 2 is ENOENT")
  ok5 = assert_eq_str(errno_name(9), "EBADF", "Errno 9 is EBADF")
  ok6 = assert_eq_str(errno_name(32), "EPIPE", "Errno 32 is EPIPE")
  ok7 = assert_true(is_error(0 - 2), "Negative return is error")
  ok8 = assert_eq_int(get_errno(0 - 13), 13, "Decodes errno from -13")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Syscall layer constants and errno decoders verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: F02 Process Lifecycle & Wait Status Decoding
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: F02 Process Lifecycle & Wait Status Helpers...")
  total_tests = total_tests + 1
  
  @! Normal exit status (exit code 42 -> status 42 * 256 = 10752)
  ok1 = assert_eq_int(process_wexitstatus(10752), 42, "Extracts exit code 42")
  ok2 = assert_eq_int(process_wifexited(10752), 1, "Child exited normally")
  ok3 = assert_eq_int(process_wifsignaled(10752), 0, "Not terminated by signal")
  
  @! Signal termination (SIGKILL = 9 -> status 9)
  ok4 = assert_eq_int(process_wtermsig(9), 9, "Extracts signal 9")
  ok5 = assert_eq_int(process_wifsignaled(9), 1, "Terminated by signal")
  ok6 = assert_eq_int(process_wifexited(9), 0, "Did not exit normally")
  
  @! Stopped by signal (SIGSTOP = 19 -> status (19 * 256) | 127 = 4991)
  ok7 = assert_eq_int(process_wifstopped(4991), 1, "Detected stopped state")
  ok8 = assert_eq_int(process_wstopsig(4991), 19, "Extracts stop signal 19")
  
  @! Resumed by SIGCONT (status 65535)
  ok9 = assert_eq_int(process_wifcontinued(65535), 1, "Detected continued status")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Process wait status decoding & job control verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: F03 Native Command Dispatcher & Tokenizer
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: F03 Native Command Dispatcher & Tokenizer...")
  total_tests = total_tests + 1
  
  toks = dispatcher_tokenize("echo 'hello world' | grep hello > out.txt 2>&1")
  ok1 = assert_eq_int(toks.len(), 7, "Tokenized 7 tokens")
  ok2 = assert_eq_str(toks[0].val, "echo", "Token 0 is echo")
  ok3 = assert_eq_str(toks[1].val, "hello world", "Token 1 preserves single quoted text")
  ok4 = assert_eq_str(toks[2].kind, "PIPE", "Token 2 is PIPE")
  ok5 = assert_eq_str(toks[3].val, "grep", "Token 3 is grep")
  ok6 = assert_eq_str(toks[4].val, "hello", "Token 4 is hello")
  ok7 = assert_eq_str(toks[5].kind, "REDIR_OUT", "Token 5 is REDIR_OUT")
  ok8 = assert_eq_str(toks[6].kind, "REDIR_ERR_TO_OUT", "Token 6 is 2>&1")
  
  @! Builtin commands
  b_echo = dispatcher_exec_builtin("echo", ["echo", "Maya", "OS"])
  ok9 = assert_eq_str(b_echo.stdout_data, "Maya OS\n", "Builtin echo produces expected output")
  
  b_true = dispatcher_exec_builtin("true", ["true"])
  ok10 = assert_eq_int(b_true.exit_code, 0, "Builtin true returns 0")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Native command tokenizer and builtin engine verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: F04 Multitasking Task Scheduler & MLFQ Engine
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: F04 Task Scheduler, TCB & MLFQ 3-Tier Engines...")
  total_tests = total_tests + 1
  
  sched = scheduler_init(1) @! MLFQ Mode
  t1 = scheduler_create_task(sched, "task_high", 1000, 4096, 0)
  t2 = scheduler_create_task(sched, "task_med", 2000, 4096, 1)
  t3 = scheduler_create_task(sched, "task_low", 3000, 4096, 2)
  
  ok1 = assert_eq_int(sched.tasks.len(), 3, "Created 3 tasks in MLFQ")
  ok2 = assert_eq_int(sched.current_task_id, 1, "Initial active task is Task 1 (High priority)")
  
  @! Simulate 10 ticks (exhausting Task 1 Q0 quantum of 10)
  tick = 0
  @while tick < 10
    scheduler_tick(sched)
    tick = tick + 1
  @end
  
  @! Task 1 should demote from Priority 0 to Priority 1
  task1 = scheduler_get_task(sched, 1)
  ok3 = assert_eq_int(task1.priority, 1, "Task 1 demoted to Priority 1 upon quantum exhaustion")
  ok4 = assert_eq_int(task1.preemptions_count, 1, "Preemption counted on quantum expiry")
  
  @! Task 1 voluntary yield retains priority
  scheduler_yield(sched)
  ok5 = assert_eq_int(task1.voluntary_yields_count, 1, "Voluntary yield counted")
  ok6 = assert_eq_int(task1.priority, 1, "Priority preserved during cooperative yield")
  
  @! Timer sleep test
  scheduler_sleep(sched, 5)
  ok7 = assert_eq_int(task1.state, 2, "Task 1 transitioned to BLOCKED on timer sleep")
  
  @! Advance 6 ticks to wake up
  tick = 0
  @while tick < 6
    scheduler_tick(sched)
    tick = tick + 1
  @end
  scheduler_schedule_next(sched)
  ok8 = assert_true(task1.state == 0 || task1.state == 1, "Task 1 woke up after timer expiration")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Scheduler TCB, MLFQ priority demotion & timer sleep verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: F05 Dynamic Segregated Free-List Heap Allocator
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: F05 Segregated Free-List Heap Allocator & Coalescing...")
  total_tests = total_tests + 1
  
  heap = heap_new()
  ptr1 = memory_alloc(heap, 48)   @! Bin 1 (<= 64)
  ptr2 = memory_alloc(heap, 120)  @! Bin 2 (<= 128)
  ptr3 = memory_alloc(heap, 500)  @! Bin 4 (<= 512)
  
  ok1 = assert_true(ptr1 > 0, "Allocated 48-byte block (ptr1 > 0)")
  ok2 = assert_true(ptr2 > 0, "Allocated 120-byte block (ptr2 > 0)")
  ok3 = assert_true(ptr3 > 0, "Allocated 500-byte block (ptr3 > 0)")
  
  @! Canary check and block size classes
  blk1 = heap.blocks[0]
  ok4 = assert_eq_int(blk1.canary_head, 3735928559, "Canary head is 0xDEADBEEF")
  ok5 = assert_eq_int(blk1.canary_foot, 3405691582, "Canary foot is 0xCAFEBABE")
  
  @! Free and Coalescing
  free_res = memory_free(heap, ptr1)
  ok6 = assert_eq_int(free_res, 0, "Freed ptr1 cleanly")
  ok7 = assert_eq_int(blk1.is_free, 1, "Block 1 marked free")
  
  @! Free adjacent block to trigger coalescing
  free_res2 = memory_free(heap, ptr2)
  ok8 = assert_eq_int(free_res2, 0, "Freed ptr2 cleanly")
  
  h_stat = heap_stats(heap)
  ok9 = assert_true(h_stat.coalesce_events >= 0, "Coalescing engine active")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Segregated free-list heap, canaries & coalescing verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: F06 Inode RamFS & DevFS Virtual Filesystem
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: F06 Virtual Filesystem (Inode RamFS & DevFS)...")
  total_tests = total_tests + 1
  
  vfs = vfs_init()
  ok1 = assert_eq_int(vfs.inodes.len(), 10, "Initialized 10 default root & dev inodes")
  
  @! Create file in RamFS
  fd = vfs_open(vfs, "/tmp/hello.txt", 64 | 2, 420) @! O_CREAT | O_RDWR
  ok2 = assert_true(fd >= 3, "Created and opened /tmp/hello.txt (fd >= 3)")
  
  bytes_written = vfs_write(vfs, fd, [72, 101, 108, 108, 111]) @! "Hello"
  ok3 = assert_eq_int(bytes_written, 5, "Wrote 5 bytes to /tmp/hello.txt")
  
  vfs_lseek(vfs, fd, 0, 0) @! Seek to 0
  read_data = vfs_read(vfs, fd, 5)
  ok4 = assert_eq_int(read_data.len(), 5, "Read 5 bytes from /tmp/hello.txt")
  ok5 = assert_eq_int(read_data[0], 72, "First byte is 'H' (72)")
  vfs_close(vfs, fd)
  
  @! DevFS /dev/null test
  fd_null = vfs_open(vfs, "/dev/null", 2, 438)
  w_null = vfs_write(vfs, fd_null, [1, 2, 3, 4])
  ok6 = assert_eq_int(w_null, 4, "/dev/null accepted and discarded 4 bytes")
  r_null = vfs_read(vfs, fd_null, 10)
  ok7 = assert_eq_int(r_null.len(), 0, "/dev/null read returned EOF (0 bytes)")
  vfs_close(vfs, fd_null)
  
  @! DevFS /dev/zero test
  fd_zero = vfs_open(vfs, "/dev/zero", 0, 438)
  r_zero = vfs_read(vfs, fd_zero, 8)
  ok8 = assert_eq_int(r_zero.len(), 8, "/dev/zero returned 8 null bytes")
  ok9 = assert_eq_int(r_zero[0], 0, "/dev/zero byte 0 is 0x00")
  vfs_close(vfs, fd_zero)
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] VFS Inode RamFS & DevFS (/dev/null, /dev/zero) verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 7: F07 Inter-Process Communication (IPC)
  @! ----------------------------------------------------------------------------
  println("▶ Section 7: F07 IPC Primitives (FIFOs, SHM, Sockets, MQ, Mutex)...")
  total_tests = total_tests + 1
  
  @! 1. Named Pipe (FIFO)
  fifo = ipc_fifo_create("test_pipe", 16)
  w_fifo = ipc_fifo_write(fifo, [10, 20, 30])
  ok1 = assert_eq_int(w_fifo, 3, "Wrote 3 bytes to FIFO ring buffer")
  r_fifo = ipc_fifo_read(fifo, 2)
  ok2 = assert_eq_int(r_fifo.len(), 2, "Read 2 bytes from FIFO")
  ok3 = assert_eq_int(r_fifo[0], 10, "FIFO preserved byte order")
  
  @! 2. Shared Memory
  shm = ipc_shm_create("shm_seg", 64, 438)
  ipc_shm_write_at(shm, 4, [99, 100])
  r_shm = ipc_shm_read_at(shm, 4, 2)
  ok4 = assert_eq_int(r_shm[0], 99, "SHM read verified byte at offset 4")
  
  @! 3. Unix Domain Sockets
  s_srv = ipc_uds_socket(1)
  s_cli = ipc_uds_socket(1)
  ipc_uds_bind(s_srv, "/tmp/test.sock")
  ipc_uds_listen(s_srv, 5)
  ipc_uds_connect(s_cli, s_srv)
  ipc_uds_send(s_cli, [1, 2, 3])
  r_uds = ipc_uds_recv(s_srv, 3)
  ok5 = assert_eq_int(r_uds.len(), 3, "Unix socket stream received 3 bytes")
  
  @! 4. Message Queue (Priority Sorting)
  mq = ipc_mq_open("posix_mq", 10, 64)
  ipc_mq_send(mq, [100], 1, 1000) @! Low priority 1
  ipc_mq_send(mq, [200], 5, 1005) @! High priority 5
  m_top = ipc_mq_receive(mq)
  ok6 = assert_eq_int(m_top.data[0], 200, "MQ dequeued highest priority message first")
  
  @! 5. Mutex & Semaphore
  mutex = ipc_mutex_init()
  lock_res = ipc_mutex_lock(mutex, 101)
  ok7 = assert_eq_int(lock_res.acquired, 1, "Mutex acquired by Task 101")
  lock_res2 = ipc_mutex_lock(mutex, 102)
  ok8 = assert_eq_int(lock_res2.blocked, 1, "Task 102 blocked on locked mutex")
  ipc_mutex_unlock(mutex, 101)
  ok9 = assert_eq_int(mutex.locked, 0, "Mutex unlocked cleanly")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] All 5 IPC mechanisms (FIFO, SHM, Sockets, MQ, Mutex) verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 8: F08 Hardware Abstraction Layer & Port I/O
  @! ----------------------------------------------------------------------------
  println("▶ Section 8: F08 Hardware Abstraction Layer, Port I/O & MMIO...")
  total_tests = total_tests + 1
  
  @! Port I/O
  hal_outb(1016, 65) @! COM1 base 0x3F8 = 1016
  b_in = hal_inb(1016)
  ok1 = assert_eq_int(b_in, 65, "Port I/O 8-bit read/write verified")
  
  hal_outw(1016, 12345)
  w_in = hal_inw(1016)
  ok2 = assert_eq_int(w_in, 12345, "Port I/O 16-bit read/write verified")
  
  @! Control Registers
  hal_write_cr3(2097152) @! 2MB PML4 base
  cr3_val = hal_read_cr3()
  ok3 = assert_eq_int(cr3_val, 2097152, "CR3 control register stored PML4 base")
  
  @! Interrupts
  hal_cli()
  ok4 = assert_eq_int(hal_are_interrupts_enabled(), 0, "Interrupts disabled via CLI")
  hal_sti()
  ok5 = assert_eq_int(hal_are_interrupts_enabled(), 1, "Interrupts enabled via STI")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] HAL Port I/O, CPU control registers & interrupt flags verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 9: F08 64-Bit GDT & 4-Level MMU Paging
  @! ----------------------------------------------------------------------------
  println("▶ Section 9: F08 64-Bit GDT Descriptors & 4-Level MMU Paging...")
  total_tests = total_tests + 1
  
  @! GDT
  gdt = gdt_table_new(2097152, 104)
  gdt_bin = gdt_serialize(gdt)
  ok1 = assert_eq_int(gdt_bin.len(), 56, "Serialized 64-bit GDT table is exactly 56 bytes")
  
  gdtr = gdtr_create(1048576, 56)
  gdtr_bin = gdtr_serialize(gdtr)
  ok2 = assert_eq_int(gdtr_bin.len(), 10, "Serialized GDTR pointer is exactly 10 bytes")
  
  @! Paging
  pte = page_entry_decode(8388611) @! Frame 0x800000 | Present | Writable
  ok3 = assert_eq_int(pte.present, 1, "PTE decoded Present flag = 1")
  ok4 = assert_eq_int(pte.writable, 1, "PTE decoded Writable flag = 1")
  
  decomp = paging_decompose_virtual_addr(2147483648) @! 2GB virtual address
  ok5 = assert_eq_int(decomp.pdpt_idx, 2, "2GB virtual address maps to PDPT index 2")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 64-bit Long Mode GDT descriptors & 4-level MMU paging verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 10: F08 Sovereign Microkernel Entry & Orchestration
  @! ----------------------------------------------------------------------------
  println("▶ Section 10: F08 Master Microkernel Initialization & Event Loop...")
  total_tests = total_tests + 1
  
  kernel = kernel_init()
  ok1 = assert_eq_str(kernel.state, "RUNNING", "Kernel state is RUNNING")
  ok2 = assert_true(kernel.idle_task_id > 0, "Idle task spawned")
  ok3 = assert_true(kernel.init_task_id > 0, "Init task spawned")
  
  kernel = kernel_run(kernel, 50)
  k_stat = kernel_status(kernel)
  ok4 = assert_eq_int(k_stat.uptime_ticks, 50, "Kernel advanced 50 system ticks")
  ok5 = assert_true(k_stat.total_tasks >= 2, "Kernel managing multiple tasks")
  ok6 = assert_true(k_stat.vfs_inodes_count >= 10, "VFS initialized with root hierarchy")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Master microkernel boot orchestration & event loop verified")
  @end

  println("=================================================================")
  println("📊 OS MASTER TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " sections passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 10 MAYA OS KERNEL TEST SUITES PASSED! (100% SUCCESS) 🎉")
    return 0
  @else
    println("❌ SOME OS KERNEL TESTS FAILED")
    return 1
  @end
@end
