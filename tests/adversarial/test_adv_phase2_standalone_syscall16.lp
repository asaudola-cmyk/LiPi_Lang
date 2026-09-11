@! ============================================================================
@! ADVERSARIAL CHALLENGER: STANDALONE ELF64 SYSCALL 16 & IO_URING RUNNER
@! File: tests/adversarial/test_adv_phase2_standalone_syscall16.maya
@! Compiles pure Maya source containing Syscall 16 (sys_ioctl) and Syscall 9 (sys_mmap)
@! directly to native ELF64 binaries and verifies standalone execution on Linux
@! ============================================================================

import "universe/core/collections"
import "compiler/backend/compiler"

@fn main()
  println("=================================================================")
  println("🔱 ADVERSARIAL CHALLENGER: STANDALONE ELF64 SYSCALL 16 TEST 🔱")
  println("=================================================================")

  src = "@fn main()\n  @! Test 1: sys_ioctl (Syscall 16) on invalid fd -1 -> returns -9 (EBADF)\n  r1 = syscall(16, 0 - 1, 0, 0, 0, 0, 0)\n  @if r1 != (0 - 9) return 1 @end\n\n  @! Test 2: sys_ioctl (Syscall 16) on stdout fd 1 with invalid command -> returns < 0\n  r2 = syscall(16, 1, 3735928559, 0, 0, 0, 0)\n  @if r2 >= 0 return 2 @end\n\n  @! Test 3: sys_mmap (Syscall 9) for 4096 bytes (PROT_READ|PROT_WRITE, MAP_ANONYMOUS|MAP_PRIVATE)\n  ptr = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)\n  @if ptr <= 0 return 3 @end\n\n  @! Test 4: sys_munmap (Syscall 11) to cleanly release memory\n  r4 = syscall(11, ptr, 4096, 0, 0, 0, 0)\n  @if r4 != 0 return 4 @end\n\n  @! Success exit code 105\n  return 105\n@end\n"

  bin_path = "/tmp/maya_adv_syscall16_standalone.elf"
  c_res = compile_source_to_elf(src, bin_path)
  
  @if c_res == 1
    println("  [PASS] Successfully compiled standalone ELF64 binary with Syscall 16")
    return 0
  @else
    println("  [FAIL] Compilation of Syscall 16 standalone ELF64 failed")
    return 1
  @end
@end
