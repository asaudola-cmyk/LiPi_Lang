import "utso/os/syscalls"
import "utso/os/env"

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
  // WHY: Uses Linux SYS_exit_group (231) so all threads in the process terminate cleanly together.
  sys_exit_group(code)
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
  cur_env = env_all()
  child_pid = process_fork()
  @if child_pid == 0
    res = process_execve(command, args, cur_env)
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
  // WHY: Captures child stdout/stderr via SYS_pipe2 + fork + SYS_dup2 + execve with inherited envp
  // and O(N) native ERMS ByteBuffer accumulation (zero O(N^2) chr() loop!).
  cur_env = env_all()
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
    process_execve(command, args, cur_env)
    process_exit(127)
  @end

  sys_close(wfd)
  @if pid < 0
    sys_close(rfd)
    return { exit_code: -1, output: "" }
  @end

  rbuf = lipi_alloc(8192)
  acc = buf_new(4096)
  @while 1 == 1
    nr = sys_read(rfd, rbuf, 8192)
    @if nr <= 0 break @end
    buf_write_mem(acc, rbuf, nr)
  @end
  lipi_free_sized(rbuf, 8192)
  sys_close(rfd)
  out = buf_to_str(acc)
  buf_free(acc)
  st = process_wait(pid)
  code = st
  @if process_wifexited(st) == 1
    code = process_wexitstatus(st)
  @end
  return { exit_code: code, output: out }
@end

@fn process_capture_full(command, args, stdin_data, timeout_ms)
  // WHY: Production subprocess runner with inherited environment, separate stdout & stderr pipes,
  // optional stdin feed, SYS_poll(7) deadlock-free multiplexing, and SIGKILL timeout enforcement.
  cur_env = env_all()
  pbuf = lipi_alloc(48)
  @if pbuf <= 0 return { exit_code: -1, stdout: "", stderr: "", timed_out: 0 } @end
  @if syscall(293, pbuf, 0, 0, 0, 0, 0) < 0 || syscall(293, pbuf + 16, 0, 0, 0, 0, 0) < 0 || syscall(293, pbuf + 32, 0, 0, 0, 0, 0) < 0
    lipi_free_sized(pbuf, 48)
    return { exit_code: -1, stdout: "", stderr: "", timed_out: 0 }
  @end
  in_r = sys_peek32(pbuf)
  in_w = sys_peek32(pbuf + 4)
  out_r = sys_peek32(pbuf + 16)
  out_w = sys_peek32(pbuf + 20)
  err_r = sys_peek32(pbuf + 32)
  err_w = sys_peek32(pbuf + 36)
  lipi_free_sized(pbuf, 48)

  pid = process_fork()
  @if pid == 0
    sys_close(in_w)
    sys_close(out_r)
    sys_close(err_r)
    syscall(33, in_r, 0, 0, 0, 0, 0)
    syscall(33, out_w, 1, 0, 0, 0, 0)
    syscall(33, err_w, 2, 0, 0, 0, 0)
    sys_close(in_r)
    sys_close(out_w)
    sys_close(err_w)
    process_execve(command, args, cur_env)
    process_exit(127)
  @end

  sys_close(in_r)
  sys_close(out_w)
  sys_close(err_w)
  @if pid < 0
    sys_close(in_w)
    sys_close(out_r)
    sys_close(err_r)
    return { exit_code: -1, stdout: "", stderr: "", timed_out: 0 }
  @end

  // Feed stdin payload and close stdin pipe to send EOF to child
  sin_len = len(stdin_data)
  @if sin_len > 0
    sw = 0
    @while sw < sin_len
      nw = sys_write(in_w, stdin_data + sw, sin_len - sw)
      @if nw <= 0 break @end
      sw = sw + nw
    @end
  @end
  sys_close(in_w)

  // Multiplex stdout & stderr using Linux SYS_poll (syscall 7, struct pollfd = 8 bytes each)
  pfd = lipi_alloc(32)
  rbuf = lipi_alloc(8192)
  out_acc = buf_new(4096)
  err_acc = buf_new(1024)
  out_open = 1
  err_open = 1
  timed_out = 0
  t_start = clock_ms()

  @while out_open == 1 || err_open == 1
    rem_ms = 50
    @if timeout_ms > 0
      elapsed = clock_ms() - t_start
      @if elapsed >= timeout_ms
        timed_out = 1
        sys_kill(pid, 9)
        break
      @end
      left = timeout_ms - elapsed
      @if left < rem_ms rem_ms = left @end
    @end
    // Build pollfd[0] (out_r) and pollfd[1] (err_r): { i32 fd, i16 events=POLLIN(1), i16 revents=0 }
    fd0 = 0 - 1
    @if out_open == 1 fd0 = out_r @end
    fd1 = 0 - 1
    @if err_open == 1 fd1 = err_r @end
    sys_poke32(pfd + 0, fd0)
    sys_poke16(pfd + 4, 1)
    sys_poke16(pfd + 6, 0)
    sys_poke32(pfd + 8, fd1)
    sys_poke16(pfd + 12, 1)
    sys_poke16(pfd + 14, 0)
    pr = syscall(7, pfd, 2, rem_ms, 0, 0, 0)
    @if pr > 0
      rev0 = sys_peek16(pfd + 6)
      @if out_open == 1 && (rev0 & (1 | 16 | 8)) != 0
        nr0 = sys_read(out_r, rbuf, 8192)
        @if nr0 > 0
          buf_write_mem(out_acc, rbuf, nr0)
        @else
          out_open = 0
        @end
      @end
      rev1 = sys_peek16(pfd + 14)
      @if err_open == 1 && (rev1 & (1 | 16 | 8)) != 0
        nr1 = sys_read(err_r, rbuf, 8192)
        @if nr1 > 0
          buf_write_mem(err_acc, rbuf, nr1)
        @else
          err_open = 0
        @end
      @end
    @end
  @end

  lipi_free_sized(pfd, 32)
  lipi_free_sized(rbuf, 8192)
  sys_close(out_r)
  sys_close(err_r)
  st = process_wait(pid)
  code = st
  @if process_wifexited(st) == 1
    code = process_wexitstatus(st)
  @end
  out_s = buf_to_str(out_acc)
  err_s = buf_to_str(err_acc)
  buf_free(out_acc)
  buf_free(err_acc)
  return { exit_code: code, stdout: out_s, stderr: err_s, timed_out: timed_out }
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
