@! ============================================================================
@! CHALLENGER 2: LARGE MEMORY ALLOCATIONS & RAW SYSCALL FILE I/O STRESS SUITE
@! File: tests/gc/test_gc_syscall_large_io_stress.maya
@! Scope: Extreme memory allocation (>1MB, >4MB, >16MB), Slab-to-Mmap realloc,
@!        concurrent multi-file I/O streaming, interior pointer validation.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct StressContext
  total: 0
  passed: 0
  failed: 0
@end

@fn chk_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was 0")
    return 0
  @end
@end

@fn chk_eq(ctx, name, actual, expected)
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

@fn chk_ge(ctx, name, actual, min_val)
  ctx.total = ctx.total + 1
  @if actual >= min_val
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual) + " (>= " + maya_int_to_str(min_val) + ")")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected >= " + maya_int_to_str(min_val) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@! ----------------------------------------------------------------------------
@! 1. Large Allocations (>1MB, 4MB, 16MB) & Interior Pointer Introspection
@! ----------------------------------------------------------------------------
@fn test_huge_allocations_and_gc_base(ctx)
  println("\n--- [Test 1] Massive Page Allocations (1MB, 4MB, 16MB) & gc_base ---")

  @! 1MB allocation
  p_1mb = gc_alloc(1048576)
  chk_true(ctx, "Allocated 1MB large buffer", p_1mb > 0)
  chk_eq(ctx, "gc_base(p_1mb) == p_1mb", gc_base(p_1mb), p_1mb)
  chk_eq(ctx, "gc_base(p_1mb + 512KB) == p_1mb", gc_base(p_1mb + 524288), p_1mb)
  chk_eq(ctx, "gc_base(p_1mb + 1048575) == p_1mb (last byte)", gc_base(p_1mb + 1048575), p_1mb)

  @! 4MB allocation
  p_4mb = gc_alloc(4194304)
  chk_true(ctx, "Allocated 4MB large buffer", p_4mb > 0)
  chk_eq(ctx, "gc_base(p_4mb) == p_4mb", gc_base(p_4mb), p_4mb)
  chk_eq(ctx, "gc_base(p_4mb + 2MB) == p_4mb", gc_base(p_4mb + 2097152), p_4mb)

  @! 16MB allocation
  p_16mb = gc_alloc(16777216)
  chk_true(ctx, "Allocated 16MB huge buffer", p_16mb > 0)
  chk_eq(ctx, "gc_base(p_16mb) == p_16mb", gc_base(p_16mb), p_16mb)
  chk_eq(ctx, "gc_base(p_16mb + 15MB) == p_16mb", gc_base(p_16mb + 15728640), p_16mb)

  @! Free 16MB and verify unmap
  gc_free(p_16mb)
  chk_eq(ctx, "gc_base(p_16mb) == 0 after gc_free", gc_base(p_16mb), 0)

  @! Free 4MB and 1MB
  gc_free(p_4mb)
  gc_free(p_1mb)
  chk_eq(ctx, "gc_base(p_4mb) == 0 after gc_free", gc_base(p_4mb), 0)
  chk_eq(ctx, "gc_base(p_1mb) == 0 after gc_free", gc_base(p_1mb), 0)
@end

@! ----------------------------------------------------------------------------
@! 2. 4MB Streamed File I/O via Raw Syscalls with Native GC Buffers
@! ----------------------------------------------------------------------------
@fn test_large_file_io_stream(ctx)
  println("\n--- [Test 2] 4MB File Streaming (sys_write & sys_read) with GC Memory ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_large_io_test_" + maya_int_to_str(pid) + ".bin"

  @! Open file: O_CREAT (64) | O_RDWR (2) | O_TRUNC (512) = 578, mode 0644 (420)
  fd = sys_open(test_file, 578, 420)
  chk_ge(ctx, "sys_open created large temporary file", fd, 3)

  @! Allocate 4MB source buffer via native GC
  src_buf = gc_alloc(4194304)
  chk_true(ctx, "Allocated 4MB source buffer", src_buf > 0)

  @! Write 4MB in 64 64KB blocks (65536 bytes)
  total_written = 0
  block_idx = 0
  @while block_idx < 64
    chunk_ptr = src_buf + (block_idx * 65536)
    w_bytes = sys_write(fd, chunk_ptr, 65536)
    total_written = total_written + w_bytes
    block_idx = block_idx + 1
  @end
  chk_eq(ctx, "Wrote exactly 4,194,304 bytes (64 x 64KB chunks)", total_written, 4194304)

  @! Verify file size via sys_lseek SEEK_END (2)
  file_size = sys_lseek(fd, 0, 2)
  chk_eq(ctx, "File size reported by sys_lseek is 4,194,304", file_size, 4194304)

  @! Seek back to beginning: SEEK_SET (0)
  seek_start = sys_lseek(fd, 0, 0)
  chk_eq(ctx, "Seeked to start of file (offset 0)", seek_start, 0)

  @! Allocate 4MB destination buffer via native GC
  dst_buf = gc_alloc(4194304)
  chk_true(ctx, "Allocated 4MB destination buffer", dst_buf > 0)

  @! Read 4MB back in 64 64KB blocks
  total_read = 0
  read_block_idx = 0
  @while read_block_idx < 64
    r_chunk_ptr = dst_buf + (read_block_idx * 65536)
    r_bytes = sys_read(fd, r_chunk_ptr, 65536)
    total_read = total_read + r_bytes
    read_block_idx = read_block_idx + 1
  @end
  chk_eq(ctx, "Read back exactly 4,194,304 bytes (64 x 64KB chunks)", total_read, 4194304)

  @! Seek to 2MB (2097152), seek backwards 512KB (524288) -> offset 1,572,864
  seek_mid = sys_lseek(fd, 2097152, 0)
  seek_back = sys_lseek(fd, 0 - 524288, 1)
  chk_eq(ctx, "Seek offset after +2MB and -512KB is 1,572,864", seek_back, 1572864)

  @! Read 1MB chunk from middle
  mid_buf = gc_alloc(1048576)
  mid_read = sys_read(fd, mid_buf, 1048576)
  chk_eq(ctx, "Read 1MB mid-file chunk", mid_read, 1048576)

  @! Close, unlink and free
  close_res = sys_close(fd)
  chk_eq(ctx, "Closed file descriptor", close_res, 0)
  unlink_res = sys_unlink(test_file)
  chk_eq(ctx, "Unlinked test file", unlink_res, 0)

  gc_free(src_buf)
  gc_free(dst_buf)
  gc_free(mid_buf)
  chk_eq(ctx, "Freed all test buffers, gc_base(src_buf) == 0", gc_base(src_buf), 0)
@end

@! ----------------------------------------------------------------------------
@! 3. Slab-to-Mmap Realloc Escalation under File I/O
@! ----------------------------------------------------------------------------
@fn test_slab_to_mmap_realloc_io(ctx)
  println("\n--- [Test 3] Slab-to-Mmap Realloc Transition under Active I/O ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_realloc_io_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(test_file, 578, 420)

  @! 1. Start with 64B slab buffer (Size class 3)
  buf = gc_alloc(64)
  chk_true(ctx, "Allocated initial 64B slab buffer", buf > 0)
  chk_eq(ctx, "gc_base(buf) == buf", gc_base(buf), buf)

  @! Write 32 bytes to file
  sys_write(fd, buf, 32)

  @! 2. Realloc to 512B (Size class 6)
  buf = gc_realloc(buf, 512)
  chk_true(ctx, "Reallocated to 512B slab buffer", buf > 0)
  chk_eq(ctx, "gc_base(buf) == buf after 512B realloc", gc_base(buf), buf)
  sys_write(fd, buf, 256)

  @! 3. Realloc to 2048B (Size class 8 - max slab size)
  buf = gc_realloc(buf, 2048)
  chk_true(ctx, "Reallocated to 2048B slab buffer", buf > 0)
  chk_eq(ctx, "gc_base(buf) == buf after 2048B realloc", gc_base(buf), buf)
  sys_write(fd, buf, 1024)

  @! 4. Realloc to 65536B (Escalates across boundary into Large Mmap Chunk!)
  buf = gc_realloc(buf, 65536)
  chk_true(ctx, "Reallocated across boundary to 64KB Large Mmap Chunk", buf > 0)
  chk_eq(ctx, "gc_base(buf) == buf after large mmap realloc", gc_base(buf), buf)
  chk_eq(ctx, "gc_base(buf + 32768) == buf (interior query)", gc_base(buf + 32768), buf)
  sys_write(fd, buf, 65536)

  @! 5. Realloc to 262144B (256KB Large Mmap)
  buf = gc_realloc(buf, 262144)
  chk_true(ctx, "Reallocated to 256KB Large Mmap Chunk", buf > 0)
  chk_eq(ctx, "gc_base(buf) == buf after 256KB realloc", gc_base(buf), buf)
  sys_write(fd, buf, 262144)

  @! Total written = 32 + 256 + 1024 + 65536 + 262144 = 328,992 bytes
  total_len = sys_lseek(fd, 0, 2)
  chk_eq(ctx, "Total file length matches cumulative writes (328,992 bytes)", total_len, 328992)

  sys_close(fd)
  sys_unlink(test_file)
  gc_free(buf)
  chk_eq(ctx, "gc_base(buf) == 0 after final large gc_free", gc_base(buf), 0)
@end

@! ----------------------------------------------------------------------------
@! 4. Multi-File Concurrent Descriptor & Slab Churn Loop
@! ----------------------------------------------------------------------------
@fn test_multi_file_concurrent_churn(ctx)
  println("\n--- [Test 4] Concurrent Multi-File I/O (8 Descriptors) & 1,000 Allocation Churn ---")

  pid = sys_getpid()
  fds = []
  paths = []
  
  @! Open 8 distinct files
  f_idx = 0
  all_fds_ok = 1
  @while f_idx < 8
    p = "/tmp/maya_multi_fd_" + maya_int_to_str(pid) + "_" + maya_int_to_str(f_idx) + ".tmp"
    fd = sys_open(p, 578, 420)
    @if fd < 3
      all_fds_ok = 0
    @end
    fds = fds.push(fd)
    paths = paths.push(p)
    f_idx = f_idx + 1
  @end
  chk_true(ctx, "Opened 8 distinct live file descriptors", all_fds_ok != 0)

  @! Churn loop: 1,000 iterations allocating memory, writing, reading, and freeing
  i = 0
  churn_ok = 1
  @while i < 1000
    target_fd_idx = i % 8
    target_fd = fds[target_fd_idx]

    @! Allocate small or medium buffer
    sz = 16 * ((i % 16) + 1)
    b = gc_alloc(sz)
    @if b <= 0
      churn_ok = 0
    @end

    @! Write 16 bytes to file
    w = sys_write(target_fd, b, 16)
    @if w != 16
      churn_ok = 0
    @end

    gc_free(b)
    i = i + 1
  @end
  chk_true(ctx, "Completed 1,000 interleaved allocations, file writes, and frees", churn_ok != 0)

  @! Verify file lengths: 1000 / 8 = 125 writes of 16B = 2,000 bytes per file
  f_check_idx = 0
  all_sizes_match = 1
  @while f_check_idx < 8
    fd = fds[f_check_idx]
    sz = sys_lseek(fd, 0, 2)
    @if sz != 2000
      all_sizes_match = 0
    @end
    sys_close(fd)
    sys_unlink(paths[f_check_idx])
    f_check_idx = f_check_idx + 1
  @end
  chk_true(ctx, "All 8 concurrent file streams contain exactly 2,000 bytes", all_sizes_match != 0)
@end

@! ----------------------------------------------------------------------------
@! MASTER RUNNER
@! ----------------------------------------------------------------------------
@fn main()
  println("=================================================================")
  println("⚔ CHALLENGER 2: LARGE MEMORY & SYSCALL FILE I/O STRESS TEST")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_huge_allocations_and_gc_base(ctx)
  test_large_file_io_stream(ctx)
  test_slab_to_mmap_realloc_io(ctx)
  test_multi_file_concurrent_churn(ctx)

  println("\n=================================================================")
  println("📊 LARGE MEMORY & FILE I/O STRESS TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of large memory and syscall file I/O stress tests PASSED!")
    return 0
  @else
    println("\n✗ [FAILURE] Failures detected in large memory / file I/O stress tests.")
    return 1
  @end
@end
