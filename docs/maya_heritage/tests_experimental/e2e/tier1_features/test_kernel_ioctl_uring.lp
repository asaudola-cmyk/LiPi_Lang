// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Linux Kernel ioctl & io_uring PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: os, kernel, syscalls, ioctl, uring, io_uring

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: KERNEL IOCTL & IO_URING ASYNC ENGINE
@! File: tests/e2e/tier1_features/test_kernel_ioctl_uring.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/io/uring"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 7: Linux sys_ioctl, sys_mmap & io_uring Engine")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.1: Direct sys_mmap (Syscall 9) & sys_munmap (Syscall 11)
  total = total + 1
  @! PROT_READ(1) | PROT_WRITE(2) = 3, MAP_PRIVATE(2) | MAP_ANONYMOUS(32) = 34
  mmap_ptr = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  unmap_status = sys_munmap(mmap_ptr, 4096)
  @if mmap_ptr > 0 && unmap_status == 0
    passed = passed + 1
    println("  [PASS] T1.1: Direct sys_mmap (Syscall 9) anonymous 4KB page allocation & sys_munmap")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: Direct sys_mmap and sys_munmap")
  @end

  @! T1.2: Direct sys_ioctl (Syscall 16) Gateway Handling
  total = total + 1
  @! Test sys_ioctl on an invalid fd (0-1), should safely return -EBADF (-9) or negative error
  ioctl_res = syscall(16, 0 - 1, 21505, 0, 0, 0, 0) @! 21505 = 0x5401 TCGETS
  is_err = is_error(ioctl_res)
  err_no = get_errno(ioctl_res)
  @if is_err == 1 && (err_no == 9 || err_no == 25 || err_no == 22)
    passed = passed + 1
    println("  [PASS] T1.2: Direct Linux sys_ioctl (Syscall 16) gateway error handling (errno=" + err_no.to_str() + " " + errno_name(err_no) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Direct sys_ioctl error handling")
  @end

  @! T1.3: io_uring Queue Ring Buffer Initialization
  total = total + 1
  ring = io_uring_init(16)
  is_ring_valid = ring.entries == 16 && ring.sq_mask == 15 && ring.sqes.len() == 16
  @if is_ring_valid && ring.sq_head == 0 && ring.sq_tail == 0
    passed = passed + 1
    println("  [PASS] T1.3: io_uring ring queue initialization (entries=16, sq_mask=15)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: io_uring ring initialization")
  @end

  @! T1.4: SQE Preparation (READ, WRITE, ACCEPT Opcodes)
  total = total + 1
  ring = io_uring_prep_read(ring, 10, 4096, 512, 0, 1001)
  ring = io_uring_prep_write(ring, 11, 8192, 1024, 512, 1002)
  ring = io_uring_prep_accept(ring, 12, 1003)

  sqe0 = ring.sqes[0]
  sqe1 = ring.sqes[1]
  sqe2 = ring.sqes[2]

  ok_sqes = sqe0.opcode == 22 && sqe1.opcode == 23 && sqe2.opcode == 13
  ok_tags = sqe0.sqe_tag == 1001 && sqe1.sqe_tag == 1002 && sqe2.sqe_tag == 1003
  @if ok_sqes && ok_tags && ring.sq_tail == 3
    passed = passed + 1
    println("  [PASS] T1.4: SQE opcode preparation (READ=22, WRITE=23, ACCEPT=13 with tags 1001..1003)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: SQE preparation")
  @end

  @! T1.5: Batch Submission & Completion Queue Event Reaping
  total = total + 1
  submitted = io_uring_submit_and_reap(ring)
  is_cqes_full = ring.cqes.len() == 3
  @if submitted == 3 && is_cqes_full && ring.sq_head == 3
    passed = passed + 1
    println("  [PASS] T1.5: Batch async submission and CQE event reaping (3 submitted, 3 reaped)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Batch submission and CQE reaping")
  @end

  @! T1.6: CQE FIFO Reaping and Tag Matching
  total = total + 1
  cqe0 = io_uring_pop_cqe(ring)
  cqe1 = io_uring_pop_cqe(ring)
  cqe2 = io_uring_pop_cqe(ring)
  empty_cqe = io_uring_pop_cqe(ring)

  is_fifo = cqe0.cqe_tag == 1001 && cqe1.cqe_tag == 1002 && cqe2.cqe_tag == 1003
  is_empty = empty_cqe == 0 && ring.cqes.len() == 0
  @if is_fifo && is_empty
    passed = passed + 1
    println("  [PASS] T1.6: CQE FIFO event popping and tag association")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: CQE popping")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 7 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Linux Kernel ioctl & io_uring PASSED")
    return 0
  @else
    println("✗ Feature: Linux Kernel ioctl & io_uring FAILED")
    return 1
  @end
@end
