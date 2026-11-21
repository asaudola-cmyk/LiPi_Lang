@! ============================================================================
@! LIPI SHELL — The Sovereign Command Interpreter
@! ============================================================================
@! LiPi does not rely on bash, sh, or cmd.exe.
@! LiPi has its own interactive shell and scripting engine.
import "utso/os/process"
import "utso/os/env"
import "utso/core/collections"
import "utso/core/string"
import "utso/core/error"
import "utso/core/io"

@! The main shell loop
@fn shell_run()
  println("Lipi Shell First 1.0.0 (প্রথম ১.০.০) — The Sovereign Universe")
  println("Type 'exit' to leave.")

  @while 1
    cmd = read_line("lipi> ")
    @if cmd == ":EOF:"
      break
    @end

    cleaned = str_trim(cmd)
    @if cleaned == "exit"
      break
    @end

    @if cleaned == ""
      continue
    @end

    shell_execute(cleaned)
  @end
@end

@! Execute a command in pure LiPi logic, without invoking bash
@fn shell_execute(cmd_line)
  raw_args = str_split(str_trim(cmd_line), " ")
  args = []
  i = 0
  @while i < raw_args.len()
    tok = str_trim(raw_args[i])
    @if tok != ""
      args = args.push(tok)
    @end
    i = i + 1
  @end
  @if args.len() == 0
    return 0
  @end
  cmd = args[0]

  @if cmd == "cd"
    @if args.len() > 1
      env_chdir(args[1])
    @else
      println("cd: missing argument")
    @end
  @elif cmd == "echo"
    k = 1
    out = ""
    @while k < args.len()
      out = out + args[k] + " "
      k = k + 1
    @end
    println(str_trim(out))
  @else
    // WHY: Executes command directly via Lipi fork + execve + wait without spawning bash/sh.
    result = process_run(cmd, args)
    @if result < 0
      println("lipi shell: command not found: " + cmd)
    @end
  @end
  return 0
@end
