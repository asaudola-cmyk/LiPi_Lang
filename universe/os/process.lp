import "universe/os/syscalls"

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
  sec = ms / 1000
  nsec = (ms % 1000) * 1000000
  ts = [sec, nsec]
  return sys_nanosleep(ts, 0)
@end

@fn process_fork()
  return sys_fork()
@end

@fn process_wait(pid)
  ws = { val: 0 }
  res = sys_wait4(pid, ws, 0, 0)
  @if res < 0
    return res
  @end
  return ws.val
@end

@fn process_waitpid(pid, options)
  ws = { val: 0 }
  res = sys_wait4(pid, ws, options, 0)
  @if res < 0
    return res
  @end
  return ws.val
@end

@fn process_kill(pid, sig)
  return sys_kill(pid, sig)
@end

@fn process_exit(code)
  sys_exit(code)
@end

@fn process_execve(filename_ptr, argv_ptr, envp_ptr)
  return sys_execve(filename_ptr, argv_ptr, envp_ptr)
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
