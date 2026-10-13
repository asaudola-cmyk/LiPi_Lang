@! ============================================================================
@! LIPI SHELL — The Sovereign Command Interpreter
@! ============================================================================
@! LiPi does not rely on bash, sh, or cmd.exe.
@! LiPi has its own interactive shell and scripting engine.
import "utso/os/process"
import "utso/os/env"
import "utso/core/string"
import "utso/core/error"
import "packages/lipi_ide/console"

@! The main shell loop
@fn shell_run()
  println("Lipi Shell First 1.0.0 (প্রথম ১.০.০) — The Sovereign Universe")
  println("Type 'exit' to leave.")
  
  @while 1
    print("lipi> ")
    cmd = console.read_line()
    
    @if string.trim(cmd) == "exit"
      break
    @end
    
    @if string.trim(cmd) == ""
      continue
    @end
    
    shell_execute(cmd)
  @end
@end

@! Execute a command in pure LiPi logic, without invoking bash
@fn shell_execute(cmd_line)
  args = string.split(cmd_line, " ")
  cmd = args[0]
  
  @if cmd == "cd"
    @if args.len() > 1
      env.env_chdir(args[1])
    @else
      println("cd: missing argument")
    @end
  @else @if cmd == "echo"
    i = 1
    out = ""
    @while i < args.len()
      out = out + args[i] + " "
      i = i + 1
    @end
    println(string.trim(out))
  @else
    // WHY: Uses LiPi's native kernel execution, completely bypassing external shells
    result = process.sys_execve(cmd, args, env.get_all())
    @if result < 0
      println("lipi shell: command not found: " + cmd)
    @end
  @end
@end
