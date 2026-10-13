@! ============================================================================
@! LIPI FREESTANDING CORE RUNTIME SUBSYSTEM (utso/sys/sys.lp)
@! 100% Written in Pure Lipi Language — Absolute Zero-Libc Independence
@! Domain: utso/sys (Freestanding Core Runtime Engineer)
@! ============================================================================

// WHY: Consolidated to canonical utso/os/syscalls kernel gateway.
import "utso/os/syscalls"
import "utso/sys/runtime"
import "utso/sys/memory"

@fn sys_version()
  // WHY: Official sovereign brand string for freestanding LiPi core runtime engine.
  return "LiPi Sovereign Core Runtime Engine v1.0.0 (Zero-Libc Freestanding)"
@end

@fn sys_is_sovereign()
  return 1
@end
