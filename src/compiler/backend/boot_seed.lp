@! ============================================================================
@! MAYA UNIVERSAL NUMBER BOOT-SEED (VM)
@! ============================================================================
@! This program acts as the ultimate Universal Decoder.
@! It reads its own binary payload, extracts the mathematical Universal Number,
@! decodes it back to raw instructions, and executes them purely in RAM.

import "universe/os/syscalls"
import "universe/core/string"

@fn hex_digit_val(c)
  @if c >= 48 && c <= 57 return c - 48 @end
  @if c >= 97 && c <= 102 return c - 87 @end
  @if c >= 65 && c <= 70 return c - 55 @end
  return 0
@end

@! WHY: Renamed from main to boot_seed_main to prevent duplicate main definition
@! from conflicting with compiler/backend/compiler.maya main entrypoint.
@fn boot_seed_main()
  fd = sys_syscall(2, "/proc/self/exe", 0, 0, 0, 0, 0)
  @if fd < 0
    println("BootSeed Error: Cannot read self.")
    return 1
  @end
  
  buf = sys_mmap(0, 10000000, 3, 34, 0 - 1, 0)
  bytes_read = sys_syscall(0, fd, buf, 10000000, 0, 0, 0)
  sys_syscall(3, fd, 0, 0, 0, 0, 0)
  
  @! Search backwards from end of file to find payload marker (avoids .rodata collisions)
  found_idx = 0 - 1
  i = bytes_read - 8
  @while i >= 0 && found_idx < 0
    @if sys_peek8(buf + i) == 64 && sys_peek8(buf + i + 1) == 64 && sys_peek8(buf + i + 2) == 85 && sys_peek8(buf + i + 3) == 78 && sys_peek8(buf + i + 4) == 73 && sys_peek8(buf + i + 5) == 86 && sys_peek8(buf + i + 6) == 64 && sys_peek8(buf + i + 7) == 64
      found_idx = i
    @end
    i = i - 1
  @end
  
  @if found_idx < 0
    println("BootSeed Error: Universal Number Payload not found.")
    return 1
  @end
  
  p = buf + found_idx + 8
  
  num_bytes = 0
  @while sys_peek8(p) >= 48 && sys_peek8(p) <= 57
    num_bytes = (num_bytes * 10) + (sys_peek8(p) - 48)
    p = p + 1
  @end
  
  @if sys_peek8(p) != 58
    println("BootSeed Error: Invalid payload format.")
    return 1
  @end
  p = p + 1
  
  println("BootSeed: Extracting Universal Number...")
  println("BootSeed: Factoring Universe...")
  
  exec_buf = sys_mmap(0, num_bytes + 16, 3, 34, 0 - 1, 0)
  b_idx = 0
  @while b_idx < num_bytes
    h1 = sys_peek8(p)
    h2 = sys_peek8(p + 1)
    p = p + 2
    b_val = (hex_digit_val(h1) * 16) + hex_digit_val(h2)
    sys_poke8(exec_buf + b_idx, b_val)
    b_idx = b_idx + 1
  @end
  
  println("BootSeed: Instantiating Reality (RAM Exec)...")
  memfd = sys_syscall(319, "universe", 1, 0, 0, 0, 0)
  @if memfd < 0
    println("BootSeed Error: memfd_create failed.")
    return 1
  @end
  
  sys_syscall(1, memfd, exec_buf, num_bytes, 0, 0, 0)
  
  argv = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  name = "maya_universe"
  sys_poke(argv, name)
  sys_poke(argv + 8, 0)
  
  res = sys_syscall(322, memfd, "", argv, 0, 4096, 0)
  println("BootSeed Error: execution failed!")
  return 1
@end
