@! ============================================================================
@! UNIVERSE B CORE: MULTITHREADING (Linux clone)
@! ============================================================================
import "universe/b_core/string"

@fn thread_spawn()
  @! Allocate 1MB stack
  stack = sys_mmap(0, 1048576, 3, 34, 0 - 1, 0)
  stack_top = stack + 1048576
  
  @! CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD | CLONE_SYSVSEM = 331520
  flags = 331520
  
  @! sys_clone (56)
  tid = sys_syscall(56, flags, stack_top, 0, 0, 0, 0)
  return tid
@end

@fn thread_exit()
  @! Threads must exit using sys_exit (60) or sys_exit_group (231)?
  @! sys_exit terminates the calling thread. sys_exit_group terminates all.
  sys_syscall(60, 0, 0, 0, 0, 0, 0)
  return 0
@end

@fn thread_sleep_ms(ms)
  @! nanosleep (35)
  @! struct timespec { time_t tv_sec; long tv_nsec; }
  ts = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  
  sec = ms / 1000
  nsec = (ms - (sec * 1000)) * 1000000
  
  sys_poke(ts + 0, sec)
  sys_poke(ts + 8, nsec)
  
  sys_syscall(35, ts, 0, 0, 0, 0, 0)
  return 0
@end
