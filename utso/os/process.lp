import "utso/os/syscalls"

@struct ProcessWaitStatus
  val: 0
@end

@fn SIGHUP() return 1 @end
@fn SIGINT() return 2 @end
@fn SIGQUIT() return 3 @end
@fn SIGKILL() return 9 @end
@fn SIGTERM() return 15 @end
@fn SIGCONT() return 18 @end
@fn SIGSTOP() return 19 @end

@fn WNOHANG() return 1 @end
@fn WUNTRACED() return 2 @end
@fn WCONTINUED() return 8 @end

@fn process_wexitstatus(status)
  s = status / 256
  return s & 255
@end

@fn process_wifexited(status)
  term = status & 127
  return term == 0
@end

@fn process_wtermsig(status)
  return status & 127
@end

@fn process_wifsignaled(status)
  term = status & 127
  @if term > 0
    @if term != 127
      return 1
    @end
  @end
  return 0
@end

@fn process_wifstopped(status)
  s = status & 255
  return s == 127
@end

@fn process_wstopsig(status)
  s = status / 256
  return s & 255
@end

@fn process_wifcontinued(status)
  return status == 65535
@end

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
  res = sys_kill(pid, 0)
  return res == 0
@end

@fn process_sleep_ms(ms)
  @if ms <= 0 return 0 @end
  // WHY: Passes a 16-byte Linux struct timespec [tv_sec, tv_nsec] in raw memory to sys_nanosleep.
  ts = lipi_alloc(16)
  @if ts <= 0 return 0 - 12 @end
  sec = ms / 1000
  nsec = (ms % 1000) * 1000000
  sys_poke64(ts, sec)
  sys_poke64(ts + 8, nsec)
  res = sys_nanosleep(ts, 0)
  lipi_free_sized(ts, 16)
  return res
@end

@fn process_fork()
  return sys_fork()
@end

@fn process_wait(pid)
  // WHY: Passes a real writable 4-byte int* buffer to Linux sys_wait4 and reads kernel status word.
  ws_buf = lipi_alloc(16)
  @if ws_buf <= 0 return 0 - 12 @end
  sys_poke64(ws_buf, 0)
  res = sys_wait4(pid, ws_buf, 0, 0)
  st = sys_peek32(ws_buf)
  lipi_free_sized(ws_buf, 16)
  @if res < 0
    return res
  @end
  return st
@end

@fn process_waitpid(pid, options)
  ws_buf = lipi_alloc(16)
  @if ws_buf <= 0 return 0 - 12 @end
  sys_poke64(ws_buf, 0)
  res = sys_wait4(pid, ws_buf, options, 0)
  st = sys_peek32(ws_buf)
  lipi_free_sized(ws_buf, 16)
  @if res < 0
    return res
  @end
  return st
@end

@fn process_kill(pid, sig)
  return sys_kill(pid, sig)
@end

@fn process_exit(code)
  sys_exit(code)
@end

@fn _proc_build_argv(command, args)
  // WHY: Converts a Lipi string list (or 0) into a NULL-terminated char** vector for Linux SYS_execve.
  @if args == 0
    vec = lipi_alloc(16)
    mem_word_write(vec, 0, command)
    mem_word_write(vec, 8, 0)
    return vec
  @end
  first_q = sys_peek64(args)
  @if first_q < 0 || first_q > 4096
    return args
  @end
  n = len(args)
  prepend_cmd = 1
  @if n > 0 && args[0] == command
    prepend_cmd = 0
  @end
  total = n + prepend_cmd + 1
  vec = lipi_alloc(total * 8)
  idx = 0
  @if prepend_cmd == 1
    mem_word_write(vec, 0, command)
    idx = 1
  @end
  i = 0
  @while i < n
    mem_word_write(vec, idx * 8, args[i])
    idx = idx + 1
    i = i + 1
  @end
  mem_word_write(vec, idx * 8, 0)
  return vec
@end

@fn _proc_build_envp(envp)
  @if envp == 0 return 0 @end
  first_q = sys_peek64(envp)
  @if first_q < 0 || first_q > 4096
    return envp
  @end
  n = len(envp)
  vec = lipi_alloc((n + 1) * 8)
  i = 0
  @while i < n
    mem_word_write(vec, i * 8, envp[i])
    i = i + 1
  @end
  mem_word_write(vec, n * 8, 0)
  return vec
@end

@fn process_execve(filename_ptr, argv_ptr, envp_ptr)
  c_argv = _proc_build_argv(filename_ptr, argv_ptr)
  c_envp = _proc_build_envp(envp_ptr)
  return sys_execve(filename_ptr, c_argv, c_envp)
@end

@fn process_spawn(command, args)
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

@fn process_capture(command, args)
  // WHY: Captures child stdout/stderr via SYS_pipe2 + fork + SYS_dup2 + execve into a real STR0 string.
  pbuf = lipi_alloc(16)
  @if pbuf <= 0 return { exit_code: -1, output: "" } @end
  @if syscall(293, pbuf, 0, 0, 0, 0, 0) < 0
    lipi_free_sized(pbuf, 16)
    return { exit_code: -1, output: "" }
  @end
  rfd = sys_peek32(pbuf)
  wfd = sys_peek32(pbuf + 4)
  lipi_free_sized(pbuf, 16)

  pid = process_fork()
  @if pid == 0
    sys_close(rfd)
    syscall(33, wfd, 1, 0, 0, 0, 0)
    syscall(33, wfd, 2, 0, 0, 0, 0)
    sys_close(wfd)
    process_execve(command, args, 0)
    process_exit(127)
  @end

  sys_close(wfd)
  @if pid < 0
    sys_close(rfd)
    return { exit_code: -1, output: "" }
  @end

  rbuf = lipi_alloc(4096)
  out = ""
  @while 1 == 1
    nr = sys_read(rfd, rbuf, 4096)
    @if nr <= 0 break @end
    k = 0
    @while k < nr
      out = out + chr(sys_peek8(rbuf + k))
      k = k + 1
    @end
  @end
  lipi_free_sized(rbuf, 4096)
  sys_close(rfd)
  st = process_wait(pid)
  code = st
  @if process_wifexited(st) == 1
    code = process_wexitstatus(st)
  @end
  return { exit_code: code, output: out }
@end

@fn process_run(command, args)
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
