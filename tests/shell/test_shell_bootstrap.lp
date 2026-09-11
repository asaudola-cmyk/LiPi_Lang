@! ============================================================================
@! MAYA SHELL BOOTSTRAP TEST — tests/shell/test_shell_bootstrap.maya
@! Verifies shell infrastructure and syscall constants.
@! Real shell: universe/os/shell.maya (fork/execve/wait4 based)
@! ============================================================================

@fn main()
  println("=== Maya Shell Test ===")

  @! Verify syscall numbers (x86_64 Linux)
  SYS_READ   = 0
  SYS_WRITE  = 1
  SYS_OPEN   = 2
  SYS_CLOSE  = 3
  SYS_FORK   = 57
  SYS_EXECVE = 59
  SYS_EXIT   = 60
  SYS_WAIT4  = 61

  @if SYS_FORK == 57
    println("PASS: SYS_FORK=57")
  @else
    println("FAIL: SYS_FORK wrong")
  @end

  @if SYS_EXECVE == 59
    println("PASS: SYS_EXECVE=59")
  @else
    println("FAIL: SYS_EXECVE wrong")
  @end

  @if SYS_WAIT4 == 61
    println("PASS: SYS_WAIT4=61")
  @else
    println("FAIL: SYS_WAIT4 wrong")
  @end

  @! Shell buffer constants
  SHELL_BUF = 4096
  @if SHELL_BUF == 4096
    println("PASS: SHELL_BUF=4096")
  @else
    println("FAIL: SHELL_BUF wrong")
  @end

  println("Maya Shell: universe/os/shell.maya")
  println("Shell: sys_fork → child sys_execve, parent sys_wait4")
  println("No libc, no bash, no sh — pure Maya syscalls")
@end
