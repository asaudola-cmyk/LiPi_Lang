@! ============================================================================
@! LIPI SOVEREIGN PROCESS LIFECYCLE & CORE RUNTIME ENGINE (universe/sys/runtime.lp)
@! 100% Written in Pure Lipi Language — Absolute Zero-Libc Independence
@! Process Lifecycle, CRT0 _start Vectors, Signal Handlers, Panic Recovery
@! ============================================================================

import "universe/sys/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Process Status Data Structures & Signal Definitions
@! ----------------------------------------------------------------------------

@struct ProcessWaitStatus
  val: i64
@end

@fn SIGHUP()    return 1 @end
@fn SIGINT()    return 2 @end
@fn SIGQUIT()   return 3 @end
@fn SIGILL()    return 4 @end
@fn SIGTRAP()   return 5 @end
@fn SIGABRT()   return 6 @end
@fn SIGBUS()    return 7 @end
@fn SIGFPE()    return 8 @end
@fn SIGKILL()   return 9 @end
@fn SIGUSR1()   return 10 @end
@fn SIGSEGV()   return 11 @end
@fn SIGUSR2()   return 12 @end
@fn SIGPIPE()   return 13 @end
@fn SIGALRM()   return 14 @end
@fn SIGTERM()   return 15 @end
@fn SIGSTKFLT() return 16 @end
@fn SIGCHLD()   return 17 @end
@fn SIGCONT()   return 18 @end
@fn SIGSTOP()   return 19 @end
@fn SIGTSTP()   return 20 @end
@fn SIGTTIN()   return 21 @end
@fn SIGTTOU()   return 22 @end
@fn SIGURG()    return 23 @end
@fn SIGXCPU()   return 24 @end
@fn SIGXFSZ()   return 25 @end
@fn SIGVTALRM() return 26 @end
@fn SIGPROF()   return 27 @end
@fn SIGWINCH()  return 28 @end
@fn SIGIO()     return 29 @end
@fn SIGPWR()    return 30 @end
@fn SIGSYS()    return 31 @end

@fn WNOHANG()     return 1 @end
@fn WUNTRACED()   return 2 @end
@fn WCONTINUED()  return 8 @end

@! ----------------------------------------------------------------------------
@! 2. Process Exit Status Decoders (Pure Bitwise Manipulation)
@! ----------------------------------------------------------------------------

@fn process_wexitstatus(status)
  @! Extract high 8 bits of exit code: (status >> 8) & 0xFF
  s = status / 256
  return s & 255
@end

@fn process_wifexited(status)
  @! True if process terminated normally (low 7 bits are 0)
  term = status & 127
  return term == 0
@end

@fn process_wtermsig(status)
  @! Return signal that caused termination
  return status & 127
@end

@fn process_wifsignaled(status)
  @! True if terminated by an unhandled signal
  term = status & 127
  @if term > 0
    @if term != 127
      return 1
    @end
  @end
  return 0
@end

@fn process_wifstopped(status)
  @! True if process is currently stopped
  s = status & 255
  return s == 127
@end

@fn process_wstopsig(status)
  @! Return signal that stopped the child
  s = status / 256
  return s & 255
@end

@fn process_wifcontinued(status)
  @! True if process resumed via SIGCONT
  return status == 65535
@end

@! ----------------------------------------------------------------------------
@! 3. Process Credentials & Identity Queries
@! ----------------------------------------------------------------------------

@fn process_getpid()
  return sys_getpid()
@end

@fn process_getppid()
  return sys_getppid()
@end

@fn process_getpgrp()
  return sys_getpgrp()
@end

@fn process_setpgid(pid, pgid)
  return sys_setpgid(pid, pgid)
@end

@fn process_setsid()
  return sys_setsid()
@end

@fn process_getuid()
  return sys_getuid()
@end

@fn process_getgid()
  return sys_getgid()
@end

@fn process_setuid(uid)
  return sys_setuid(uid)
@end

@fn process_setgid(gid)
  return sys_setgid(gid)
@end

@fn process_geteuid()
  return sys_geteuid()
@end

@fn process_getegid()
  return sys_getegid()
@end

@fn process_yield()
  return sys_sched_yield()
@end

@fn process_is_alive(pid)
  @! Probe process existence with signal 0
  res = sys_kill(pid, 0)
  return res == 0
@end

@fn process_sleep_ms(ms)
  @! Nanosecond precision sleep via direct sys_nanosleep
  sec = ms / 1000
  nsec = (ms % 1000) * 1000000
  ts = [sec, nsec]
  return sys_nanosleep(ts, 0)
@end

@! ----------------------------------------------------------------------------
@! 4. Process Lifecycle & Execution Control (Zero C Library Wrappers)
@! ----------------------------------------------------------------------------

@fn process_fork()
  @! Direct clone/fork via raw Linux syscall 57
  return sys_fork()
@end

@fn process_wait(pid)
  @! Wait for child process exit using raw sys_wait4 (syscall 61)
  ws = { val: 0 }
  res = sys_wait4(pid, ws, 0, 0)
  @if res < 0
    return res
  @end
  return ws.val
@end

@fn process_waitpid(pid, options)
  @! Wait for specific process with options (WNOHANG, WUNTRACED)
  ws = { val: 0 }
  res = sys_wait4(pid, ws, options, 0)
  @if res < 0
    return res
  @end
  return ws.val
@end

@fn process_kill(pid, sig)
  @! Send signal directly via raw Linux syscall 62
  return sys_kill(pid, sig)
@end

@fn process_exit(code)
  @! Terminate current process immediately via raw sys_exit (syscall 60)
  sys_exit(code)
@end

@fn process_exit_group(code)
  @! Terminate all threads in process group via raw sys_exit_group (syscall 231)
  sys_exit_group(code)
@end

@fn process_execve(filename_ptr, argv_ptr, envp_ptr)
  @! Execute new program replacing current address space via raw sys_execve (syscall 59)
  return sys_execve(filename_ptr, argv_ptr, envp_ptr)
@end

@fn process_spawn(command, args)
  @! Sovereign process fork and execve without shell or libc wrappers
  child_pid = process_fork()
  @if child_pid == 0
    res = process_execve(command, args, 0)
    process_exit(127)
  @end
  return child_pid
@end

@fn process_spawn_env(command, args, envp)
  child_pid = process_fork()
  @if child_pid == 0
    res = process_execve(command, args, envp)
    process_exit(127)
  @end
  return child_pid
@end

@fn process_run(command, args)
  @! Spawn child, wait for termination, and decode exit status
  child_pid = process_spawn(command, args)
  @if child_pid < 0
    return child_pid
  @end
  status = process_wait(child_pid)
  @if status < 0
    return status
  @end
  @if process_wifexited(status) == 1
    return process_wexitstatus(status)
  @end
  return status
@end

@! ----------------------------------------------------------------------------
@! 5. CRT0 _start Process Bootstrap & Stack Vector Extraction
@! ----------------------------------------------------------------------------

@fn sys_crt0_argc(stack_ptr)
  @! On Linux ELF entry point, [rsp] contains argc as 64-bit integer
  @if stack_ptr == 0 return 0 @end
  return sys_peek(stack_ptr)
@end

@fn sys_crt0_argv(stack_ptr, idx)
  @! [rsp + 8 + 8*idx] contains argv[idx] pointer
  @if stack_ptr == 0 return 0 @end
  argc = sys_peek(stack_ptr)
  @if idx < 0 || idx >= argc return 0 @end
  return sys_peek(stack_ptr + 8 + (idx * 8))
@end

@fn sys_crt0_envp(stack_ptr)
  @! envp starts immediately after the NULL terminator of argv: [rsp + 8 + 8*(argc+1)]
  @if stack_ptr == 0 return 0 @end
  argc = sys_peek(stack_ptr)
  return stack_ptr + 16 + (argc * 8)
@end

@fn sys_getenv(name)
  @! Zero-libc pure Maya environment reader
  @! Reads /proc/self/environ via direct raw syscalls without libc getenv()
  fd = sys_open("/proc/self/environ", 0, 0)
  @if fd < 0
    return ""
  @end

  buf = sys_mmap(0, 8192, 3, 34, 0 - 1, 0)
  @if buf <= 0
    sys_close(fd)
    return ""
  @end

  read_bytes = sys_read(fd, buf, 8192)
  sys_close(fd)
  @if read_bytes <= 0
    sys_munmap(buf, 8192)
    return ""
  @end

  target_prefix = str_concat(name, "=")
  prefix_len = str_len(target_prefix)
  entry_start = 0
  pos = 0

  @while pos < read_bytes
    byte_val = sys_peek8(buf + pos)
    @if byte_val == 0
      @! End of environment entry: check match
      entry_len = pos - entry_start
      @if entry_len > prefix_len
        matched = 1
        k = 0
        @while k < prefix_len
          c1 = sys_peek8(buf + entry_start + k)
          c2 = str_char_at(target_prefix, k)
          @if c1 != c2
            matched = 0
            k = prefix_len
          @end
          k = k + 1
        @end
        @if matched == 1
          val_len = entry_len - prefix_len
          val_buf = sys_mmap(0, val_len + 1, 3, 34, 0 - 1, 0)
          v_i = 0
          @while v_i < val_len
            sys_poke8(val_buf + v_i, sys_peek8(buf + entry_start + prefix_len + v_i))
            v_i = v_i + 1
          @end
          sys_poke8(val_buf + val_len, 0)
          sys_munmap(buf, 8192)
          return val_buf
        @end
      @end
      entry_start = pos + 1
    @end
    pos = pos + 1
  @end

  sys_munmap(buf, 8192)
  return ""
@end

@! ----------------------------------------------------------------------------
@! 6. Signal Handling & Registration (Direct Kernel RT Signals)
@! ----------------------------------------------------------------------------

@struct SigAction
  sa_handler: i64
  sa_flags: i64
  sa_restorer: i64
  sa_mask: i64
@end

@fn sys_signal_register(sig, handler_ptr)
  @! Direct sys_rt_sigaction (syscall 13)
  @! Allocates 32-byte kernel sigaction struct:
  @! sa_handler (8 bytes), sa_flags (8 bytes), sa_restorer (8 bytes), sa_mask (8 bytes)
  act = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  @if act <= 0 return 0 - 12 @end  @! -ENOMEM
  sys_poke(act, handler_ptr)
  sys_poke(act + 8, 0x04000000)   @! SA_RESTORER
  sys_poke(act + 16, 0)
  sys_poke(act + 24, 0)           @! sa_mask = empty
  res = sys_rt_sigaction(sig, act, 0, 8)
  sys_munmap(act, 32)
  return res
@end

@fn sys_signal_block(sig)
  @! Blocks signal via sys_rt_sigprocmask (syscall 14, SIG_BLOCK = 0)
  set_ptr = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  @if set_ptr <= 0 return 0 - 12 @end
  mask = 1 << (sig - 1)
  sys_poke(set_ptr, mask)
  res = sys_rt_sigprocmask(0, set_ptr, 0, 8)
  sys_munmap(set_ptr, 8)
  return res
@end

@fn sys_signal_unblock(sig)
  @! Unblocks signal via sys_rt_sigprocmask (syscall 14, SIG_UNBLOCK = 1)
  set_ptr = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  @if set_ptr <= 0 return 0 - 12 @end
  mask = 1 << (sig - 1)
  sys_poke(set_ptr, mask)
  res = sys_rt_sigprocmask(1, set_ptr, 0, 8)
  sys_munmap(set_ptr, 8)
  return res
@end

@! ----------------------------------------------------------------------------
@! 7. Stack Unwinding & Sovereign Panic Recovery
@! ----------------------------------------------------------------------------

@fn sys_stack_unwind(bp, max_frames)
  @! Walk frame pointers along RBP chain
  @! WHY: Pure freestanding frame pointer traversal without libunwind or glibc backtrace()
  frames = []
  @if bp == 0 return frames @end
  count = 0
  curr_bp = bp
  @while curr_bp != 0 && count < max_frames
    ret_addr = sys_peek(curr_bp + 8)
    @if ret_addr == 0
      count = max_frames
    @else
      frames = frames.push(ret_addr)
      curr_bp = sys_peek(curr_bp)
      count = count + 1
    @end
  @end
  return frames
@end

@fn sys_panic(msg)
  @! Freestanding Panic Recovery Handler: Writes directly to STDERR and terminates process cleanly
  prefix = "\n[LIPI CORE RUNTIME PANIC] "
  sys_write(2, prefix, str_len(prefix))
  sys_write(2, msg, str_len(msg))
  newline = "\nTerminating process via direct kernel sys_exit_group(134)\n"
  sys_write(2, newline, str_len(newline))
  @! Exit code 134 corresponds to fatal abort (128 + SIGABRT)
  sys_exit_group(134)
@end

@fn sys_abort()
  sys_panic("Execution aborted abnormally via sys_abort()")
@end
