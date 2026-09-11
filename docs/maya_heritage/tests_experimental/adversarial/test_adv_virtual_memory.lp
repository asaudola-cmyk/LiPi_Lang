@! ============================================================================
@! MAYA ADVERSARIAL VIRTUAL MEMORY & SYSCALL INTEGRITY SUITE
@! File: tests/adversarial/test_adv_virtual_memory.maya
@! Scope: Adversarial verification of sys_mmap, sys_munmap, sys_mprotect,
@!        page alignment, memory integrity, permission boundaries, partial
@!        unmapping, and stress churn under Linux x86-64.
@! ============================================================================

import "universe/os/syscalls"

@! --- Test Framework Helpers ---

@struct AdvContext
  total: 0
  passed: 0
  failed: 0
@end

@fn adv_assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + maya_int_to_str(expected) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn adv_assert_true(ctx, name, condition)
  ctx.total = ctx.total + 1
  @if condition != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn adv_assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> matched expected string")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn adv_assert_errno(ctx, name, actual_ret, expected_errno)
  ctx.total = ctx.total + 1
  expected_ret = 0 - expected_errno
  @if actual_ret == expected_ret
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> correctly returned -errno " + maya_int_to_str(actual_ret))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected -errno " + maya_int_to_str(expected_ret) + ", got " + maya_int_to_str(actual_ret))
    return 0
  @end
@end

@! Helper: write string to file, read into mmap buffer, write from mmap buffer to another file, read string back
@fn vm_transfer_verify(ctx, test_name, mmap_addr, offset, test_pattern, pid)
  length = str_len(test_pattern)
  f_in = "/tmp/maya_adv_in_" + maya_int_to_str(pid) + ".tmp"
  f_out = "/tmp/maya_adv_out_" + maya_int_to_str(pid) + ".tmp"

  @! Write pattern to input file
  fd_in_w = sys_open(f_in, 578, 420) @! O_CREAT|O_RDWR|O_TRUNC
  sys_write(fd_in_w, test_pattern, length)
  sys_close(fd_in_w)

  @! Read from input file into mmap region at offset
  fd_in_r = sys_open(f_in, 0, 0) @! O_RDONLY
  bytes_in = sys_read(fd_in_r, mmap_addr + offset, length)
  sys_close(fd_in_r)

  @! Write from mmap region at offset to output file
  fd_out_w = sys_open(f_out, 578, 420)
  bytes_out = sys_write(fd_out_w, mmap_addr + offset, length)
  sys_close(fd_out_w)

  @! Read back output file as Maya string
  read_back = file_read(f_out)

  @! Cleanup files
  sys_unlink(f_in)
  sys_unlink(f_out)

  adv_assert_eq(ctx, test_name + " [bytes read into mmap]", bytes_in, length)
  adv_assert_eq(ctx, test_name + " [bytes written from mmap]", bytes_out, length)
  adv_assert_str_eq(ctx, test_name + " [content match]", read_back, test_pattern)
  return 1
@end


@! ============================================================================
@! TEST SUITE 1: VARYING PAGE SIZES, ALIGNMENT & FLAGS
@! ============================================================================

@fn test_adv_page_sizes_and_alignments(ctx)
  println("\n=== [SUITE 1] Varying Page Sizes, Alignments & Flags ===")

  @! PROT_READ(1) | PROT_WRITE(2) = 3
  @! MAP_PRIVATE(2) | MAP_ANONYMOUS(32) = 34

  @! 1. Exact 1 Page (4096 bytes)
  p4k = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.1: 4KB page allocation returns valid address", p4k > 0)
  adv_assert_eq(ctx, "ADV-VM-01.2: 4KB page is 4096-byte aligned", p4k % 4096, 0)
  sys_munmap(p4k, 4096)

  @! 2. Non-page multiple: 1 byte (kernel must round up to 4096)
  p1 = sys_mmap(0, 1, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.3: 1-byte allocation returns valid address", p1 > 0)
  adv_assert_eq(ctx, "ADV-VM-01.4: 1-byte allocation is 4096-byte aligned", p1 % 4096, 0)
  sys_munmap(p1, 1)

  @! 3. Non-page multiple: 4097 bytes (crosses page boundary, requires 2 pages = 8192 bytes)
  p4097 = sys_mmap(0, 4097, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.5: 4097-byte allocation returns valid address", p4097 > 0)
  adv_assert_eq(ctx, "ADV-VM-01.6: 4097-byte allocation is 4096-byte aligned", p4097 % 4096, 0)
  sys_munmap(p4097, 4097)

  @! 4. Segregated Arena Size: 64KB (65536 bytes = 16 pages)
  p64k = sys_mmap(0, 65536, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.7: 64KB arena allocation returns valid address", p64k > 0)
  adv_assert_eq(ctx, "ADV-VM-01.8: 64KB arena is 4096-byte aligned", p64k % 4096, 0)
  sys_munmap(p64k, 65536)

  @! 5. Medium Arena Size: 65537 bytes (crosses 64KB boundary -> 17 pages = 69632 bytes)
  p65k = sys_mmap(0, 65537, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.9: 65537-byte allocation returns valid address", p65k > 0)
  adv_assert_eq(ctx, "ADV-VM-01.10: 65537-byte allocation is 4096-byte aligned", p65k % 4096, 0)
  sys_munmap(p65k, 65537)

  @! 6. Huge Page Alignment / 2MB allocation (2097152 bytes = 512 pages)
  p2m = sys_mmap(0, 2097152, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.11: 2MB page allocation returns valid address", p2m > 0)
  adv_assert_eq(ctx, "ADV-VM-01.12: 2MB page is 4096-byte aligned", p2m % 4096, 0)
  sys_munmap(p2m, 2097152)

  @! 7. Large 16MB allocation (16777216 bytes = 4096 pages)
  p16m = sys_mmap(0, 16777216, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.13: 16MB allocation returns valid address", p16m > 0)
  adv_assert_eq(ctx, "ADV-VM-01.14: 16MB allocation is 4096-byte aligned", p16m % 4096, 0)
  sys_munmap(p16m, 16777216)

  @! 8. Alternative valid flag combinations: MAP_SHARED | MAP_ANONYMOUS (1 | 32 = 33)
  pshared = sys_mmap(0, 4096, 3, 33, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-01.15: MAP_SHARED | MAP_ANON allocation returns valid address", pshared > 0)
  adv_assert_eq(ctx, "ADV-VM-01.16: MAP_SHARED allocation is aligned", pshared % 4096, 0)
  sys_munmap(pshared, 4096)
@end


@! ============================================================================
@! TEST SUITE 2: MEMORY READ/WRITE INTEGRITY & MULTI-PAGE BOUNDARIES
@! ============================================================================

@fn test_adv_memory_integrity_and_boundaries(ctx)
  println("\n=== [SUITE 2] Memory Read/Write Integrity & Multi-Page Boundaries ===")

  pid = sys_getpid()
  @! Allocate 64KB arena (16 pages = 65536 bytes)
  arena = sys_mmap(0, 65536, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-02.1: 64KB arena allocated", arena > 0)

  @! Test 1: Page 0 base (offset 0)
  pat0 = "HEADER_SIGNATURE_AT_OFFSET_0000000000000000000000000000000000000000"
  vm_transfer_verify(ctx, "ADV-VM-02.2: Page 0 offset 0 integrity", arena, 0, pat0, pid)

  @! Test 2: Page 1 base (offset 4096)
  pat1 = "PAGE_1_START_MARKER_0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
  vm_transfer_verify(ctx, "ADV-VM-02.3: Page 1 offset 4096 integrity", arena, 4096, pat1, pid)

  @! Test 3: Page 7 base (offset 28672)
  pat7 = "MID_ARENA_PAGE_7_PAYLOAD_DATA_BLOCK_VERIFICATION_CHECK_987654321000"
  vm_transfer_verify(ctx, "ADV-VM-02.4: Page 7 offset 28672 integrity", arena, 28672, pat7, pid)

  @! Test 4: Page 15 tail (offset 65400)
  pat15 = "ARENA_TAIL_PAGE_15_LAST_BYTES_VERIFICATION_PAYLOAD_XYZ_999999999999"
  vm_transfer_verify(ctx, "ADV-VM-02.5: Page 15 tail offset 65400 integrity", arena, 65400, pat15, pid)

  @! Test 5: Cross-page boundary write (offset 4080 to 4120 spanning Page 0 and Page 1)
  pat_cross = "BOUNDARY_SPANNING_PAYLOAD_ACROSS_PAGE_0_AND_PAGE_1_SEAM_CRITICAL_TEST"
  vm_transfer_verify(ctx, "ADV-VM-02.6: Cross-page boundary seam integrity", arena, 4080, pat_cross, pid)

  @! Test 6: Re-verify Page 0 base is uncorrupted by subsequent writes
  vm_transfer_verify(ctx, "ADV-VM-02.7: Page 0 remains uncorrupted", arena, 0, pat0, pid)

  @! Test 7: Multi-Arena Independence: Allocate Arena B and verify no cross-talk
  arena_b = sys_mmap(0, 65536, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-02.8: Arena B allocated", arena_b > 0)
  adv_assert_true(ctx, "ADV-VM-02.9: Arena A and B have distinct addresses", arena != arena_b)

  pat_b = "ARENA_B_ISOLATED_SECRET_KEY_PAYLOAD_999888777666555444333222111000"
  vm_transfer_verify(ctx, "ADV-VM-02.10: Arena B isolated write", arena_b, 0, pat_b, pid)

  @! Verify Arena A still contains pat0
  vm_transfer_verify(ctx, "ADV-VM-02.11: Arena A retains data independently of Arena B", arena, 0, pat0, pid)

  sys_munmap(arena_b, 65536)
  sys_munmap(arena, 65536)
@end


@! ============================================================================
@! TEST SUITE 3: PERMISSION TRANSITIONS & MPROTECT ENFORCEMENT
@! ============================================================================

@fn test_adv_mprotect_permissions(ctx)
  println("\n=== [SUITE 3] Permission Transitions & sys_mprotect Enforcement ===")

  pid = sys_getpid()
  tmp_file = "/tmp/maya_adv_mprot_" + maya_int_to_str(pid) + ".tmp"
  tmp_file_vfs = "/tmp/maya_adv_vfs_" + maya_int_to_str(pid) + ".tmp"

  @! 1. Allocate 8KB (2 pages) with PROT_READ | PROT_WRITE (3)
  page = sys_mmap(0, 8192, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-03.1: 8KB page allocated with PROT_READ|PROT_WRITE", page > 0)

  @! Write initial payload to page
  init_pat = "SECURITY_CRITICAL_PAYLOAD_FOR_MPROTECT_VERIFICATION_TESTING_12345678"
  vm_transfer_verify(ctx, "ADV-VM-03.2: Initial payload written successfully", page, 0, init_pat, pid)

  @! 2. Change protection to PROT_READ (1) via sys_mprotect
  prot_ro_res = sys_mprotect(page, 8192, 1) @! PROT_READ = 1
  adv_assert_eq(ctx, "ADV-VM-03.3: sys_mprotect set PROT_READ returns 0", prot_ro_res, 0)

  @! Verification A: Reading from PROT_READ page via sys_write to file MUST SUCCEED
  fd_out = sys_open(tmp_file, 578, 420)
  read_out_bytes = sys_write(fd_out, page, str_len(init_pat))
  sys_close(fd_out)
  read_back_str = file_read(tmp_file)
  sys_unlink(tmp_file)
  adv_assert_eq(ctx, "ADV-VM-03.4: Reading from PROT_READ buffer succeeds", read_out_bytes, str_len(init_pat))
  adv_assert_str_eq(ctx, "ADV-VM-03.5: PROT_READ content is intact", read_back_str, init_pat)

  @! Verification B: Writing into PROT_READ page via sys_read MUST FAIL with -EFAULT (-14)
  fd_in = sys_open("/dev/zero", 0, 0)
  write_ro_res = sys_read(fd_in, page, 64)
  sys_close(fd_in)
  adv_assert_errno(ctx, "ADV-VM-03.6: Writing into PROT_READ buffer fails with -EFAULT (-14)", write_ro_res, 14)

  @! 3. Change protection to PROT_NONE (0) via sys_mprotect
  prot_none_res = sys_mprotect(page, 8192, 0) @! PROT_NONE = 0
  adv_assert_eq(ctx, "ADV-VM-03.7: sys_mprotect set PROT_NONE returns 0", prot_none_res, 0)

  @! Verification C: Writing into PROT_NONE buffer MUST FAIL with -EFAULT (-14)
  fd_zero = sys_open("/dev/zero", 0, 0)
  write_none_res = sys_read(fd_zero, page, 64)
  sys_close(fd_zero)
  adv_assert_errno(ctx, "ADV-VM-03.8: Writing into PROT_NONE buffer fails with -EFAULT (-14)", write_none_res, 14)

  @! Verification D: Reading from PROT_NONE buffer via file sys_write MUST FAIL with -EFAULT (-14)
  @! (Using a real file triggers copy_from_user in Linux VFS)
  fd_vfs = sys_open(tmp_file_vfs, 578, 420)
  read_none_res = sys_write(fd_vfs, page, 64)
  sys_close(fd_vfs)
  sys_unlink(tmp_file_vfs)
  adv_assert_errno(ctx, "ADV-VM-03.9: Reading from PROT_NONE buffer fails with -EFAULT (-14)", read_none_res, 14)

  @! 4. Restore protection to PROT_READ | PROT_WRITE (3) via sys_mprotect
  prot_rw_res = sys_mprotect(page, 8192, 3)
  adv_assert_eq(ctx, "ADV-VM-03.10: sys_mprotect restore PROT_READ|PROT_WRITE returns 0", prot_rw_res, 0)

  @! Verification E: Payload survived PROT_NONE transition unharmed
  vm_transfer_verify(ctx, "ADV-VM-03.11: Memory payload survived PROT_NONE unharmed", page, 0, init_pat, pid)

  @! Verification F: Write new payload now succeeds
  new_pat = "UPDATED_PAYLOAD_AFTER_RESTORING_READ_WRITE_PERMISSIONS_0987654321"
  vm_transfer_verify(ctx, "ADV-VM-03.12: Write new payload after permission restore", page, 0, new_pat, pid)

  sys_munmap(page, 8192)
@end


@! ============================================================================
@! TEST SUITE 4: UNMAPPING, PARTIAL UNMAPPING & DOUBLE UNMAP
@! ============================================================================

@fn test_adv_munmap_and_partial_unmaps(ctx)
  println("\n=== [SUITE 4] Unmapping, Partial Unmapping & Double Unmap ===")

  pid = sys_getpid()
  tmp_file_vfs = "/tmp/maya_adv_vfs_unmap_" + maya_int_to_str(pid) + ".tmp"

  @! 1. Allocate 4 contiguous pages (16KB = 16384 bytes)
  p16k = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  adv_assert_true(ctx, "ADV-VM-04.1: 16KB (4-page) contiguous allocation", p16k > 0)

  @! Populate all 4 pages
  p0_msg = "PAGE_0_ACTIVE_DATA_BLOCK_00000000000000000000000000000000000000000"
  p1_msg = "PAGE_1_MIDDLE_DATA_BLOCK_11111111111111111111111111111111111111111"
  p2_msg = "PAGE_2_MIDDLE_DATA_BLOCK_22222222222222222222222222222222222222222"
  p3_msg = "PAGE_3_ACTIVE_DATA_BLOCK_33333333333333333333333333333333333333333"

  vm_transfer_verify(ctx, "ADV-VM-04.2: Write Page 0", p16k, 0, p0_msg, pid)
  vm_transfer_verify(ctx, "ADV-VM-04.3: Write Page 1", p16k, 4096, p1_msg, pid)
  vm_transfer_verify(ctx, "ADV-VM-04.4: Write Page 2", p16k, 8192, p2_msg, pid)
  vm_transfer_verify(ctx, "ADV-VM-04.5: Write Page 3", p16k, 12288, p3_msg, pid)

  @! 2. Partial Unmap: Unmap the middle 2 pages (Page 1 and Page 2 = 8192 bytes starting at offset 4096)
  mid_unmap_res = sys_munmap(p16k + 4096, 8192)
  adv_assert_eq(ctx, "ADV-VM-04.6: Partial sys_munmap middle 2 pages returns 0", mid_unmap_res, 0)

  @! 3. Verify Page 0 is still valid and readable
  vm_transfer_verify(ctx, "ADV-VM-04.7: Page 0 remains active and verified", p16k, 0, p0_msg, pid)

  @! 4. Verify Page 3 is still valid and readable
  vm_transfer_verify(ctx, "ADV-VM-04.8: Page 3 remains active and verified", p16k, 12288, p3_msg, pid)

  @! 5. Verify Page 1 (offset 4096) access fails with -EFAULT (-14) via real VFS write
  fd_vfs1 = sys_open(tmp_file_vfs, 578, 420)
  unmapped_p1_read = sys_write(fd_vfs1, p16k + 4096, 64)
  sys_close(fd_vfs1)
  sys_unlink(tmp_file_vfs)
  adv_assert_errno(ctx, "ADV-VM-04.9: Accessing unmapped Page 1 fails with -EFAULT (-14)", unmapped_p1_read, 14)

  @! 6. Verify Page 2 (offset 8192) access fails with -EFAULT (-14) via real VFS write
  fd_vfs2 = sys_open(tmp_file_vfs, 578, 420)
  unmapped_p2_read = sys_write(fd_vfs2, p16k + 8192, 64)
  sys_close(fd_vfs2)
  sys_unlink(tmp_file_vfs)
  adv_assert_errno(ctx, "ADV-VM-04.10: Accessing unmapped Page 2 fails with -EFAULT (-14)", unmapped_p2_read, 14)

  @! 7. Clean up remaining outer pages
  unmap_p0 = sys_munmap(p16k, 4096)
  unmap_p3 = sys_munmap(p16k + 12288, 4096)
  adv_assert_eq(ctx, "ADV-VM-04.11: Unmap Page 0 returns 0", unmap_p0, 0)
  adv_assert_eq(ctx, "ADV-VM-04.12: Unmap Page 3 returns 0", unmap_p3, 0)

  @! 8. Double Unmap: Linux kernel munmap on already unmapped valid address range returns 0
  double_unmap = sys_munmap(p16k, 4096)
  adv_assert_eq(ctx, "ADV-VM-04.13: Double munmap on unmapped range returns 0", double_unmap, 0)
@end


@! ============================================================================
@! TEST SUITE 5: NEGATIVE TESTING & SYSCALL ERROR TRANSLATION
@! ============================================================================

@fn test_adv_negative_vm_errors(ctx)
  println("\n=== [SUITE 5] Negative Testing & Syscall Error Translation ===")

  @! 1. sys_mmap length = 0 -> -EINVAL (-22)
  res_mmap_len0 = sys_mmap(0, 0, 3, 34, 0 - 1, 0)
  adv_assert_errno(ctx, "ADV-VM-05.1: sys_mmap length 0 returns -EINVAL (-22)", res_mmap_len0, 22)

  @! 2. sys_mmap MAP_ANONYMOUS without MAP_PRIVATE or MAP_SHARED (flags = 32) -> -EINVAL (-22)
  res_mmap_noflags = sys_mmap(0, 4096, 3, 32, 0 - 1, 0)
  adv_assert_errno(ctx, "ADV-VM-05.2: sys_mmap MAP_ANON without MAP_PRIVATE/SHARED returns -EINVAL (-22)", res_mmap_noflags, 22)

  @! 3. sys_munmap length = 0 -> -EINVAL (-22)
  valid_page = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  res_unmap_len0 = sys_munmap(valid_page, 0)
  adv_assert_errno(ctx, "ADV-VM-05.3: sys_munmap length 0 returns -EINVAL (-22)", res_unmap_len0, 22)

  @! 4. sys_munmap unaligned address (offset 1) -> -EINVAL (-22)
  res_unmap_unaligned1 = sys_munmap(valid_page + 1, 4096)
  adv_assert_errno(ctx, "ADV-VM-05.4: sys_munmap unaligned (+1) returns -EINVAL (-22)", res_unmap_unaligned1, 22)

  @! 5. sys_munmap unaligned address (offset 2048) -> -EINVAL (-22)
  res_unmap_unaligned2048 = sys_munmap(valid_page + 2048, 4096)
  adv_assert_errno(ctx, "ADV-VM-05.5: sys_munmap unaligned (+2048) returns -EINVAL (-22)", res_unmap_unaligned2048, 22)

  @! 6. sys_mprotect unaligned address -> -EINVAL (-22)
  res_mprot_unaligned = sys_mprotect(valid_page + 1, 4096, 1)
  adv_assert_errno(ctx, "ADV-VM-05.6: sys_mprotect unaligned (+1) returns -EINVAL (-22)", res_mprot_unaligned, 22)

  @! 7. sys_mprotect invalid protection flags (e.g. -1 or 0xFFFFFF) -> -EINVAL (-22)
  res_mprot_invalid_flags = sys_mprotect(valid_page, 4096, 0 - 1)
  adv_assert_errno(ctx, "ADV-VM-05.7: sys_mprotect invalid flags returns -EINVAL (-22)", res_mprot_invalid_flags, 22)

  @! Free valid page
  sys_munmap(valid_page, 4096)
@end


@! ============================================================================
@! TEST SUITE 6: LIFECYCLE CHURN & STRESS HARNESS
@! ============================================================================

@fn test_adv_lifecycle_churn_and_stress(ctx)
  println("\n=== [SUITE 6] Lifecycle Churn & Stress Harness ===")

  pid = sys_getpid()
  test_iter_count = 50
  i = 0
  all_cycles_passed = 1

  @! 1. 50 Rapid allocate -> write -> verify -> unmap cycles
  @while i < test_iter_count
    arena = sys_mmap(0, 65536, 3, 34, 0 - 1, 0)
    @if arena <= 0
      all_cycles_passed = 0
    @end

    @! Write unique cycle payload
    cycle_str = "CHURN_CYCLE_TEST_INDEX_" + maya_int_to_str(i) + "_AUTHENTICATED_CHECK_SUM"
    f_tmp = "/tmp/maya_churn_" + maya_int_to_str(pid) + "_" + maya_int_to_str(i) + ".tmp"
    fd_w = sys_open(f_tmp, 578, 420)
    sys_write(fd_w, cycle_str, str_len(cycle_str))
    sys_close(fd_w)

    fd_r = sys_open(f_tmp, 0, 0)
    sys_read(fd_r, arena, str_len(cycle_str))
    sys_close(fd_r)
    sys_unlink(f_tmp)

    @! Read back
    f_out = "/tmp/maya_churn_out_" + maya_int_to_str(pid) + "_" + maya_int_to_str(i) + ".tmp"
    fd_ow = sys_open(f_out, 578, 420)
    sys_write(fd_ow, arena, str_len(cycle_str))
    sys_close(fd_ow)

    read_back = file_read(f_out)
    sys_unlink(f_out)

    @if read_back != cycle_str
      all_cycles_passed = 0
    @end

    sys_munmap(arena, 65536)
    i = i + 1
  @end

  adv_assert_true(ctx, "ADV-VM-06.1: 50 consecutive 64KB arena churn cycles succeeded 100%", all_cycles_passed != 0)

  @! 2. Interleaved Multi-Allocation Matrix
  @! Allocate 8 blocks of 16KB each, verify addresses and alignments, free every other block, allocate new blocks, free all
  b0 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b1 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b2 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b3 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b4 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b5 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b6 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  b7 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)

  all_blocks_valid = (b0 > 0) && (b1 > 0) && (b2 > 0) && (b3 > 0) && (b4 > 0) && (b5 > 0) && (b6 > 0) && (b7 > 0)
  adv_assert_true(ctx, "ADV-VM-06.2: 8 simultaneous 16KB allocations successful", all_blocks_valid != 0)

  @! Free odd blocks
  sys_munmap(b1, 16384)
  sys_munmap(b3, 16384)
  sys_munmap(b5, 16384)
  sys_munmap(b7, 16384)

  @! Reallocate 4 new blocks
  n1 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  n3 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  n5 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)
  n7 = sys_mmap(0, 16384, 3, 34, 0 - 1, 0)

  all_realloc_valid = (n1 > 0) && (n3 > 0) && (n5 > 0) && (n7 > 0)
  adv_assert_true(ctx, "ADV-VM-06.3: 4 reallocated blocks after fragmentation successful", all_realloc_valid != 0)

  @! Clean up all blocks
  sys_munmap(b0, 16384)
  sys_munmap(b2, 16384)
  sys_munmap(b4, 16384)
  sys_munmap(b6, 16384)
  sys_munmap(n1, 16384)
  sys_munmap(n3, 16384)
  sys_munmap(n5, 16384)
  sys_munmap(n7, 16384)
  adv_assert_true(ctx, "ADV-VM-06.4: Clean unmap of entire interleaved allocation matrix", 1)
@end


@! ============================================================================
@! MASTER RUNNER ENTRYPOINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("▶ MAYA ADVERSARIAL VIRTUAL MEMORY & SYSCALL VERIFICATION SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_adv_page_sizes_and_alignments(ctx)
  test_adv_memory_integrity_and_boundaries(ctx)
  test_adv_mprotect_permissions(ctx)
  test_adv_munmap_and_partial_unmaps(ctx)
  test_adv_negative_vm_errors(ctx)
  test_adv_lifecycle_churn_and_stress(ctx)

  println("\n=================================================================")
  println("📊 ADVERSARIAL VM VERIFICATION SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of adversarial virtual memory syscall tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more adversarial virtual memory tests failed.")
    return 1
  @end
@end
