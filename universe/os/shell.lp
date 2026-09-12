@! ============================================================================
@! LIPI NATIVE SHELL — universe/os/shell.lp
@! A self-contained command interpreter written in 100% pure Maya.
@! Zero dependency on bash / sh / libc.  All I/O via raw Linux syscalls.
@!
@! Syscall numbers (x86_64 Linux):
@!   sys_read    =   0
@!   sys_write   =   1
@!   sys_open    =   2
@!   sys_close   =   3
@!   sys_fork    =  57
@!   sys_execve  =  59
@!   sys_exit    =  60
@!   sys_wait4   =  61
@!
@! Architecture: REPL loop
@!   1. Print prompt "maya> " via sys_write
@!   2. Read a line from stdin via sys_read
@!   3. Parse the line into command + args
@!   4. Handle built-in commands (exit, cd, help, echo)
@!   5. For external commands: sys_fork → child sys_execve, parent sys_wait4
@! ============================================================================

import "universe/os/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Constants
@! ----------------------------------------------------------------------------
@fn SHELL_BUF_SIZE()  return 4096  @end
@fn SHELL_ARGV_MAX()  return 64    @end
@fn SHELL_PATH_MAX()  return 1024  @end
@fn STDIN_FD()        return 0     @end
@fn STDOUT_FD()       return 1     @end
@fn STDERR_FD()       return 2     @end
@fn SYS_READ()        return 0     @end
@fn SYS_WRITE()       return 1     @end
@fn SYS_FORK()        return 57    @end
@fn SYS_EXECVE()      return 59    @end
@fn SYS_EXIT()        return 60    @end
@fn SYS_WAIT4()       return 61    @end

@! Shell runtime state
g_shell_running  = 1
g_last_exit_code = 0
g_cwd            = "/"
g_history        = []

@! ----------------------------------------------------------------------------
@! 2. Low-level I/O helpers (wrap syscalls)
@! ----------------------------------------------------------------------------

@fn shell_write(fd, str_val)
  @! Write a string to a file descriptor via sys_write
  @if str_val.len() == 0
    return 0
  @end
  return syscall(SYS_WRITE(), fd, str_val, str_val.len())
@end

@fn shell_print(msg)
  return shell_write(STDOUT_FD(), msg)
@end

@fn shell_println(msg)
  shell_write(STDOUT_FD(), msg)
  return shell_write(STDOUT_FD(), "\n")
@end

@fn shell_eprint(msg)
  return shell_write(STDERR_FD(), msg)
@end

@fn shell_read_line(buf_size)
  @! Read up to buf_size bytes from stdin; return the string read.
  @! In the freestanding runtime, syscall(SYS_READ, 0, buf, n) returns bytes read.
  raw = syscall(SYS_READ(), STDIN_FD(), buf_size, buf_size)
  @if raw <= 0
    return ""
  @end
  @! raw is the byte count; the syscall layer delivers the buffer as a string
  return raw.to_str()
@end

@! ----------------------------------------------------------------------------
@! 3. String Parsing Utilities
@! ----------------------------------------------------------------------------

@fn shell_is_whitespace(ch)
  @if ch == " "  return 1 @end
  @if ch == "\t" return 1 @end
  @if ch == "\r" return 1 @end
  @if ch == "\n" return 1 @end
  return 0
@end

@fn shell_str_trim(s)
  @! Strip leading and trailing whitespace from string s
  n = s.len()
  @if n == 0 return "" @end

  start = 0
  @while start < n
    @if shell_is_whitespace(s[start]) == 0
      @! found first non-whitespace
      start = n  @! break
    @else
      start = start + 1
    @end
  @end
  @! fix: re-scan properly
  left = 0
  @while left < n && shell_is_whitespace(s[left]) == 1
    left = left + 1
  @end
  right = n - 1
  @while right >= left && shell_is_whitespace(s[right]) == 1
    right = right - 1
  @end
  @if left > right return "" @end
  return s.substr(left, right + 1)
@end

@fn shell_parse_command(line)
  @! Split line by whitespace into { cmd, args } structure.
  @! Handles single-quoted strings (no escape sequences for simplicity).
  @! Returns { cmd: string, args: array, raw: string }

  trimmed = shell_str_trim(line)
  n = trimmed.len()
  argv = []
  token = ""
  in_single_quote = 0
  i = 0

  @while i < n
    ch = trimmed[i]

    @if in_single_quote == 1
      @! Inside single quotes — accumulate until closing '
      @if ch == "'"
        in_single_quote = 0
      @else
        token = token + ch
      @end
      i = i + 1
    @elif ch == "'"
      @! Enter single-quote mode
      in_single_quote = 1
      i = i + 1
    @elif shell_is_whitespace(ch) == 1
      @! Token boundary
      @if token.len() > 0
        argv = argv.push(token)
        token = ""
      @end
      i = i + 1
    @else
      token = token + ch
      i = i + 1
    @end
  @end

  @! Push final token if any
  @if token.len() > 0
    argv = argv.push(token)
  @end

  @! Build result
  cmd = ""
  @if argv.len() > 0
    cmd = argv[0]
  @end

  args = []
  ai = 1
  @while ai < argv.len()
    args = args.push(argv[ai])
    ai = ai + 1
  @end

  return { cmd: cmd, args: args, raw: trimmed }
@end

@! ----------------------------------------------------------------------------
@! 4. Built-in command handlers
@! ----------------------------------------------------------------------------

@fn builtin_echo(args)
  i = 0
  @while i < args.len()
    @if i > 0
      shell_write(STDOUT_FD(), " ")
    @end
    shell_write(STDOUT_FD(), args[i])
    i = i + 1
  @end
  shell_write(STDOUT_FD(), "\n")
  return 0
@end

@fn builtin_exit(args)
  code = 0
  @if args.len() > 0
    code = args[0].to_int()
  @end
  g_shell_running = 0
  g_last_exit_code = code
  return code
@end

@fn builtin_help()
  shell_println("Maya Shell — Built-in commands:")
  shell_println("  echo [args...]   Print arguments to stdout")
  shell_println("  exit [code]      Exit the shell with optional exit code")
  shell_println("  help             Show this help message")
  shell_println("  history          Show command history")
  shell_println("  pwd              Print working directory")
  shell_println("  env              Show environment summary")
  shell_println("  true             Return exit code 0")
  shell_println("  false            Return exit code 1")
  return 0
@end

@fn builtin_history()
  i = 0
  @while i < g_history.len()
    num = (i + 1).to_str()
    @while num.len() < 4
      num = " " + num
    @end
    shell_println(num + "  " + g_history[i])
    i = i + 1
  @end
  return 0
@end

@fn builtin_pwd()
  shell_println(g_cwd)
  return 0
@end

@fn builtin_env()
  shell_println("SHELL=maya")
  shell_println("PWD=" + g_cwd)
  shell_println("LANG=C.UTF-8")
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. External Command Execution via fork/execve
@! ----------------------------------------------------------------------------

@fn shell_exec(cmd_struct)
  @! Fork and exec an external command.
  @! child  → sys_execve(cmd_struct.cmd, argv_with_cmd, envp=[])
  @! parent → sys_wait4(child_pid, &status, 0, NULL)

  cmd   = cmd_struct.cmd
  args  = cmd_struct.args

  @! Build full argv = [cmd] ++ args
  full_argv = []
  full_argv = full_argv.push(cmd)
  ai = 0
  @while ai < args.len()
    full_argv = full_argv.push(args[ai])
    ai = ai + 1
  @end

  @! sys_fork() — returns 0 in child, child PID in parent, < 0 on error
  pid = syscall(SYS_FORK(), 0, 0, 0, 0, 0, 0)

  @if pid < 0
    @! Fork failed
    shell_eprint("maya-shell: fork failed\n")
    return 1
  @end

  @if pid == 0
    @! ---- CHILD PROCESS ----
    @! sys_execve(path, argv, envp)
    @! In the Maya runtime the syscall layer handles marshalling argv/envp.
    ret = syscall(SYS_EXECVE(), cmd, full_argv, [])
    @! execve only returns on error
    shell_eprint("maya-shell: execve failed for: " + cmd + "\n")
    syscall(SYS_EXIT(), 127, 0, 0, 0, 0, 0)
    return 127
  @end

  @! ---- PARENT PROCESS ----
  @! sys_wait4(pid, &status, options=0, rusage=NULL)
  status = syscall(SYS_WAIT4(), pid, 0, 0, 0, 0, 0)
  @! Extract exit code from wait status (low 8 bits of high byte)
  exit_code = (status / 256) % 256
  g_last_exit_code = exit_code
  return exit_code
@end

@! ----------------------------------------------------------------------------
@! 6. Command Dispatch
@! ----------------------------------------------------------------------------

@fn shell_dispatch(cmd_struct)
  cmd  = cmd_struct.cmd
  args = cmd_struct.args

  @! Skip empty commands
  @if cmd.len() == 0
    return 0
  @end

  @! Record in history
  g_history = g_history.push(cmd_struct.raw)

  @! Built-ins first
  @if cmd == "exit"
    return builtin_exit(args)
  @end
  @if cmd == "echo"
    return builtin_echo(args)
  @end
  @if cmd == "help"
    return builtin_help()
  @end
  @if cmd == "history"
    return builtin_history()
  @end
  @if cmd == "pwd"
    return builtin_pwd()
  @end
  @if cmd == "env"
    return builtin_env()
  @end
  @if cmd == "true"
    g_last_exit_code = 0
    return 0
  @end
  @if cmd == "false"
    g_last_exit_code = 1
    return 1
  @end

  @! External command
  return shell_exec(cmd_struct)
@end

@! ----------------------------------------------------------------------------
@! 7. Main REPL Loop
@! ----------------------------------------------------------------------------

@fn shell_run()
  @! Main Read-Eval-Print Loop
  @! Reads from stdin, parses, dispatches, loops until "exit".

  @while g_shell_running == 1
    @! Print prompt: "maya> "
    shell_write(STDOUT_FD(), "maya> ")

    @! Read a line from stdin
    line = shell_read_line(SHELL_BUF_SIZE())

    @! EOF or error → exit cleanly
    @if line.len() == 0
      g_shell_running = 0
    @else
      @! Parse and dispatch
      cmd_struct = shell_parse_command(line)
      shell_dispatch(cmd_struct)
    @end
  @end

  return g_last_exit_code
@end

@! ----------------------------------------------------------------------------
@! 8. Non-interactive batch execution
@! ----------------------------------------------------------------------------

@fn shell_exec_string(command_str)
  @! Execute a single command string (useful for scripting / tests)
  cmd_struct = shell_parse_command(command_str)
  return shell_dispatch(cmd_struct)
@end

@fn shell_exec_script(lines)
  @! Execute an array of command strings sequentially
  i = 0
  last_exit = 0
  @while i < lines.len()
    cmd_struct = shell_parse_command(lines[i])
    last_exit = shell_dispatch(cmd_struct)
    @! Check if shell was asked to exit
    @if g_shell_running == 0
      return last_exit
    @end
    i = i + 1
  @end
  return last_exit
@end

@! ----------------------------------------------------------------------------
@! 9. Entry point
@! ----------------------------------------------------------------------------

@fn main()
  @! Start the interactive shell REPL
  return shell_run()
@end
