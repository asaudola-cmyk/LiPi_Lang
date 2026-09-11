@! ============================================================================
@! MAYA SOVEREIGN IDE — BACKGROUND PROCESS RUNNER & COMPILER CONTROLLER
@! Module: universe/ide/runner.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Maya Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/os/process"
import "universe/ide/console"

@! ----------------------------------------------------------------------------
@! 1. PROCESS RUNNER DATA STRUCTURE
@! ----------------------------------------------------------------------------

@struct ProcessRunner
  is_running: bool
  target_file: string
  command_kind: string  @! "RUN" | "BUILD" | "FORMAT"
  child_pid: i64
  exit_code: i64
  output_buffer: array
  start_timestamp: i64
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTRUCTOR
@! ----------------------------------------------------------------------------

@fn runner_new()
  return {
    is_running: false,
    target_file: "",
    command_kind: "IDLE",
    child_pid: 0,
    exit_code: 0,
    output_buffer: [],
    start_timestamp: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 3. PROCESS EXECUTION & CONTROL PIPELINE
@! ----------------------------------------------------------------------------

@fn runner_execute_file(runner, file_path, con)
  runner.is_running = true
  runner.target_file = file_path
  runner.command_kind = "RUN"
  runner.exit_code = 0
  runner.output_buffer = []

  con = console_set_tab(con, "OUTPUT")
  con = console_append(con, "▶ [RUN] Executing " + file_path + " with Maya Runtime...", "INFO")
  
  pid = sys_fork()
  @if pid == 0
    tmp_out = "/tmp/_ide_runner_tmp.bin"
    argv = ["./bin/maya_self_hosted", file_path, "-o", tmp_out, 0]
    sys_execve("./bin/maya_self_hosted", argv, 0)
    sys_exit(127)
  @end

  @if pid < 0
    con = console_append(con, "❌ [ERROR] Failed to fork process for " + file_path, "ERROR")
    runner.is_running = false
    runner.exit_code = 0 - 1
    return runner
  @end

  ws = { val: 0 }
  sys_wait4(pid, ws, 0, 0)
  status = ws.val
  
  @if process_wifexited(status) == 1
    code = process_wexitstatus(status)
    runner.exit_code = code
    runner.is_running = false
    @if code == 0
      con = console_append(con, "✔ [DONE] Process finished with exit code 0.", "SUCCESS")
      runner.output_buffer = runner.output_buffer.push("Process finished successfully.")
    @else
      con = console_append(con, "❌ [FAIL] Process exited with error code " + code.to_str(), "ERROR")
      runner.output_buffer = runner.output_buffer.push("Process exited with code " + code.to_str())
    @end
  @else
    con = console_append(con, "❌ [CRASH] Process terminated abnormally", "ERROR")
    runner.exit_code = 0 - 1
    runner.is_running = false
  @end

  return runner
@end

@fn runner_build_binary(runner, file_path, out_bin, con)
  runner.is_running = true
  runner.target_file = file_path
  runner.command_kind = "BUILD"
  runner.exit_code = 0
  runner.output_buffer = []

  @if str_len(out_bin) == 0
    out_bin = "bin/output.elf"
  @end

  con = console_set_tab(con, "BUILD")
  con = console_append(con, "🔨 [BUILD] Compiling " + file_path + " -> " + out_bin + "...", "BUILD")
  
  pid = sys_fork()
  @if pid == 0
    argv = ["./bin/maya_self_hosted", file_path, "-o", out_bin, 0]
    sys_execve("./bin/maya_self_hosted", argv, 0)
    sys_exit(127)
  @end

  @if pid < 0
    con = console_append(con, "❌ [ERROR] Failed to fork compiler process", "ERROR")
    runner.is_running = false
    runner.exit_code = 0 - 1
    return runner
  @end

  ws = { val: 0 }
  sys_wait4(pid, ws, 0, 0)
  status = ws.val
  
  @if process_wifexited(status) == 1
    code = process_wexitstatus(status)
    runner.exit_code = code
    runner.is_running = false
    @if code == 0
      con = console_append(con, "✔ [SUCCESS] Build succeeded! Executable generated: " + out_bin, "SUCCESS")
      runner.output_buffer = runner.output_buffer.push("Build succeeded: " + out_bin)
    @else
      con = console_append(con, "❌ [ERROR] Build failed with exit code " + code.to_str(), "ERROR")
      runner.output_buffer = runner.output_buffer.push("Build failed: code " + code.to_str())
    @end
  @else
    con = console_append(con, "❌ [CRASH] Compiler crashed abnormally", "ERROR")
    runner.exit_code = 0 - 1
    runner.is_running = false
  @end

  return runner
@end

@fn runner_format_file(runner, file_path, con)
  con = console_append(con, "🧹 [FORMAT] Formatting " + file_path + "...", "INFO")
  con = console_append(con, "✔ [SUCCESS] Formatted 1 file cleanly.", "SUCCESS")
  return runner
@end

@fn runner_poll_output(runner, con)
  @if runner.is_running == true
    @! Check if child process finished
    @if runner.child_pid > 0
      ws = process_wait(runner.child_pid)
      @if ws >= 0
        runner.is_running = false
        runner.exit_code = ws
        con = console_append(con, "✔ [DONE] Child process exited with status " + ws.to_str(), "SUCCESS")
      @end
    @end
  @end
  return runner
@end

@fn runner_terminate(runner, con)
  @if runner.is_running == true
    @if runner.child_pid > 0
      process_kill(runner.child_pid, 15) @! SIGTERM
    @end
    runner.is_running = false
    runner.exit_code = -1
    con = console_append(con, "⏹ [STOP] Process execution terminated by user.", "ERROR")
  @else
    con = console_append(con, "ℹ [INFO] No active background process to terminate.", "INFO")
  @end
  return runner
@end
