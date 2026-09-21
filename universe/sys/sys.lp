@! ============================================================================
@! LIPI FREESTANDING CORE RUNTIME SUBSYSTEM (universe/sys/sys.lp)
@! 100% Written in Pure Lipi Language — Absolute Zero-Libc Independence
@! Domain: universe/sys (Freestanding Core Runtime Engineer)
@! ============================================================================

import "universe/sys/syscalls"
import "universe/sys/runtime"
import "universe/sys/memory"

@fn sys_version()
  // WHY: Official sovereign brand string for freestanding LiPi core runtime engine.
  return "LiPi Sovereign Core Runtime Engine v1.0.0 (Zero-Libc Freestanding)"
@end

@fn sys_is_sovereign()
  return 1
@end
