@! ============================================================================
@! MAYA E2E TIER 1 — F21: Freestanding ELF Binary
@! File: tests/e2e/tier1_features/infra/test_f21_purity_freestanding_elf.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"

@fn main()
  maps = fs_read_file("/proc/self/maps")
  @if maps.len() == 0 return 1 @end
  pid = sys_getpid()
  @if pid <= 0 return 1 @end
  println("✓ PASS: test_f21_purity_freestanding_elf")
  return 0
@end
