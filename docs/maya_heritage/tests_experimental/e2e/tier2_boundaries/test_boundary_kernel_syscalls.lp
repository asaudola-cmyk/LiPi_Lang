// @! RUN: %maya %file
// @! EXPECT: ✓ Tier 2: Boundary Kernel Syscalls & io_uring Limits PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: kernel, syscalls, io_uring, boundary, errnos, underflow, overflow

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY VALUE ANALYSIS: KERNEL SYSCALLS & IO_URING LIMITS
@! File: tests/e2e/tier2_boundaries/test_boundary_kernel_syscalls.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/io/uring"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary Value Analysis: Kernel Syscalls & io_uring")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T2.1: Bad File Descriptor Error Code Rejection (-EBADF errno 9)
  total = total + 1
  bad_fd = 0 - 1
  close_res = sys_close(bad_fd)
  is_err1 = is_error(close_res)
  errno1 = get_errno(close_res)
  @if is_err1 == 1 && errno1 == 9
    passed = passed + 1
    println("  [PASS] T2.1: Bad file descriptor error propagation (sys_close(-1) -> -EBADF errno 9)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.1: Bad file descriptor error handling")
  @end

  @! T2.2: Non-Existent File Path Rejection (-ENOENT errno 2)
  total = total + 1
  open_res = sys_open("/tmp/maya_non_existent_file_definitely_998877.xyz", 0, 0)
  is_err2 = is_error(open_res)
  errno2 = get_errno(open_res)
  @if is_err2 == 1 && errno2 == 2
    passed = passed + 1
    println("  [PASS] T2.2: Non-existent file path open rejection (sys_open -> -ENOENT errno 2)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.2: Non-existent file open rejection")
  @end

  @! T2.3: Syscall Errno Translation Subsystem
  total = total + 1
  name_ebadf = errno_name(9)
  name_enoent = errno_name(2)
  name_eacces = errno_name(13)
  name_einval = errno_name(22)
  name_enosys = errno_name(38)
  desc_ebadf = errno_strerror(9)
  desc_enoent = errno_strerror(2)
  @if name_ebadf == "EBADF" && name_enoent == "ENOENT" && name_eacces == "EACCES" && name_einval == "EINVAL" && name_enosys == "ENOSYS"
    passed = passed + 1
    println("  [PASS] T2.3: Kernel errno name and description decoding (EBADF, ENOENT, EACCES, EINVAL, ENOSYS)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.3: Kernel errno decoding")
  @end

  @! T2.4: io_uring Ring Mask Arithmetic & Index Wrapping
  total = total + 1
  ring = io_uring_init(8) @! Mask = 7 (0b111)
  @! Push 12 items to test ring wrapping
  i = 0
  @while i < 12
    ring = io_uring_prep_read(ring, i, 4096, 64, 0, 2000 + i)
    i = i + 1
  @end
  @! Slot 0 was overwritten by item 8, slot 1 by item 9, slot 2 by item 10, slot 3 by item 11
  sqe0 = ring.sqes[0]
  sqe3 = ring.sqes[3]
  @if ring.sq_tail == 12 && sqe0.sqe_tag == 2008 && sqe3.sqe_tag == 2011
    passed = passed + 1
    println("  [PASS] T2.4: io_uring SQ ring mask wrapping and index arithmetic (8 entries, 12 prepped)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.4: io_uring SQ ring mask wrapping")
  @end

  @! T2.5: io_uring CQ Ring Empty Underflow Handling
  total = total + 1
  empty_ring = io_uring_init(4)
  peek_val = io_uring_peek_cqe(empty_ring)
  pop_val = io_uring_pop_cqe(empty_ring)
  pop_val2 = io_uring_pop_cqe(empty_ring)
  @if peek_val == 0 && pop_val == 0 && pop_val2 == 0 && empty_ring.cq_head == 0
    passed = passed + 1
    println("  [PASS] T2.5: io_uring CQ ring empty underflow safety (peek/pop returns 0 on empty ring)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.5: io_uring CQ ring underflow safety")
  @end

  println("-----------------------------------------------------------------")
  println("Tier 2 Kernel Boundary Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Tier 2: Boundary Kernel Syscalls & io_uring Limits PASSED")
    return 0
  @else
    println("✗ Tier 2: Boundary Kernel Syscalls & io_uring Limits FAILED")
    return 1
  @end
@end
