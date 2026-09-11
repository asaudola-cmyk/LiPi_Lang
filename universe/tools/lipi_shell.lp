@! ============================================================================
@! LIPI SHELL — The Sovereign Command Interpreter
@! ============================================================================
@! Maya does not rely on bash, sh, or cmd.exe.
@! Maya has its own interactive shell and scripting engine.

import "universe/os/process"
import "universe/os/env"
import "universe/core/string"
import "universe/core/error"
import "universe/io/console"

@! The main shell loop
@fn shell_run()
  println("Lipi Shell v2.0.0 — The Sovereign Universe")
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

@! Execute a command in pure Maya logic, without invoking bash
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
    @! Use Maya's native kernel execution, bypassing external shells
    result = process.sys_execve(cmd, args, env.get_all())
    @if result < 0
      println("maya shell: command not found: " + cmd)
    @end
  @end
@end
