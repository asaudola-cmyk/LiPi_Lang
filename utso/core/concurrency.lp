@! ============================================================================
@! LIPI UNIVERSE CORE — CONCURRENCY & GREEN THREADS (utso/core/concurrency.lp)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Native Linux x86-64 sys_clone Green Threads & Dynamic Swarm Routing Bridge
@! ============================================================================

@fn PROT_READ() return 1 @end
@fn PROT_WRITE() return 2 @end
@fn MAP_PRIVATE() return 2 @end
@fn MAP_ANONYMOUS() return 32 @end
@fn MAP_GROWSDOWN() return 256 @end
@fn MAP_FAILED() return 0 - 1 @end

@fn CLONE_VM() return 256 @end
@fn CLONE_FS() return 512 @end
@fn CLONE_FILES() return 1024 @end
@fn CLONE_SIGHAND() return 2048 @end
@fn CLONE_THREAD() return 65536 @end

@fn sys_mmap(addr, length, prot, flags, fd, offset)
  return syscall(9, addr, length, prot, flags, fd, offset)
@end

@fn sys_munmap(addr, length)
  return syscall(11, addr, length, 0, 0, 0, 0)
@end

@fn sys_wait4(pid, status_ptr, options, rusage_ptr)
  return syscall(61, pid, status_ptr, options, rusage_ptr, 0, 0)
@end

@! ----------------------------------------------------------------------------
@! 1. Native Shared-Memory Kernel Thread Spawning (CLONE_VM + SYS_futex)
@! ----------------------------------------------------------------------------

@fn lipi_spawn(func, arg)
  // WHY: Initializes runtime heap globals before clone so parent & child share heap state safely,
  // allocates a guard-safe anonymous stack, and enters the native thread_spawn_vm trampoline.
  _heap_init = []
  size = 2097152
  stack = sys_mmap(0, size, 3, 34, 0 - 1, 0)
  @if stack <= 0
    return 0 - 1
  @end
  return thread_spawn_vm(func, arg, stack + size)
@end

// WHY: Spawns a joinable OS thread via CLONE_PARENT_SETTID | CLONE_CHILD_CLEARTID + futex handle.
@fn lipi_spawn_joinable(func, arg)
  _heap_init = []
  size = 2097152
  stack = sys_mmap(0, size, 3, 34, 0 - 1, 0)
  @if stack <= 0
    return 0
  @end
  handle = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  @if handle <= 0
    sys_munmap(stack, size)
    return 0
  @end
  mem_word_write(handle, 0, 1)
  mem_word_write(handle, 8, stack)
  mem_word_write(handle, 16, size)
  tid = thread_spawn_vm_joinable(func, arg, stack + size, handle)
  @if tid <= 0
    sys_munmap(stack, size)
    sys_munmap(handle, 4096)
    return 0
  @end
  return handle
@end

// WHY: Zero-spin kernel SYS_futex join blocking until child thread exit clears tid word.
@fn lipi_join(handle)
  @if handle == 0 return 0 @end
  cur_tid = mem_word_read(handle, 0) & 4294967295
  @while cur_tid != 0
    futex_wait(handle, cur_tid)
    cur_tid = mem_word_read(handle, 0) & 4294967295
  @end
  stack = mem_word_read(handle, 8)
  size = mem_word_read(handle, 16)
  @if stack > 0 && size > 0
    sys_munmap(stack, size)
  @end
  sys_munmap(handle, 4096)
  return 1
@end

// WHY: thread_spawn provides standard cross-module naming for green/OS thread creation.
@fn thread_spawn(func, arg)
  return lipi_spawn(func, arg)
@end

@! ----------------------------------------------------------------------------
@! 2. Swarm Task & Concurrency Join
@! ----------------------------------------------------------------------------

@fn swarm_join(join_h)
  @if join_h == 0 return 0 @end
  return join_h.result
@end
