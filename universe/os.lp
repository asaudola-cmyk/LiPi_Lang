// ==============================================================================
// 👑 LIPI UNIVERSE OS — GRAND UMBRELLA PRELUDE (universe/os.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero Libc | Ring-0 Bare-Metal
// ==============================================================================
//
// WHY: Provides a unified gateway for direct Linux kernel syscalls, bare-metal
// Ring-0 x86_64 kernel primitives, task schedulers, and device drivers in pure Lipi.
// Developers can simply write:
//     import "universe/os"
// to invoke raw kernel syscalls, virtual file systems, preemptive coroutine
// scheduling, and COM1 serial/VGA hardware interfaces.
// ==============================================================================

import "universe/os/syscalls"
import "universe/os/kernel"
import "universe/os/scheduler"
import "universe/os/drivers/vga"
import "universe/os/drivers/serial"
import "universe/os/fs"

// ── Kernel Syscall Intrinsic ──────────────────────────────────────────────────
// WHY: Executes direct Linux sys_getpid to query current process ID without libc.
@fn lipi_os_pid()
    return sys_getpid()
@end

@fn লিপি_ওএস_পিআইডি()
    return lipi_os_pid()
@end
