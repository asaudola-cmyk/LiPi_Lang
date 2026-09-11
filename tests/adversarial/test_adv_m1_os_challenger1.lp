@! ============================================================================
@! ADVERSARIAL CHALLENGER 1 STRESS TEST SUITE: NATIVE MAYA OS KERNEL
@! Milestone 1: Syscalls, Command Dispatcher & Task Scheduler Stress Testing
@! File: tests/adversarial/test_adv_m1_os_challenger1.maya
@! 100% Written in Pure Maya Language — Zero Foreign Code / Zero Libc
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/os/dispatcher"
import "universe/os/scheduler"
import "universe/core/string"

@struct ChallengerState
  passed: 0
  failed: 0
  total: 0
@end

@fn assert_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return state
@end

@fn assert_str_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return state
@end

@fn assert_true(state, cond, name)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Condition was false)")
  @end
  return state
@end

@fn assert_false(state, cond, name)
  state.total = state.total + 1
  @if cond == 0 || cond == false
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Condition was true)")
  @end
  return state
@end

@! ============================================================================
@! 1. SYSCALL LAYER ADVERSARIAL STRESS & BOUNDARY TESTS
@! ============================================================================

@fn test_syscall_layer_stress(state)
  println("\n▶ [Challenger 1.1] Stress Testing Syscall Layer & Error Decoders...")

  @! 1.1 Syscall ABI Constants Verification
  state = assert_eq(state, PROT_NONE(), 0, "PROT_NONE is 0")
  state = assert_eq(state, PROT_READ(), 1, "PROT_READ is 1")
  state = assert_eq(state, PROT_WRITE(), 2, "PROT_WRITE is 2")
  state = assert_eq(state, PROT_EXEC(), 4, "PROT_EXEC is 4")
  state = assert_eq(state, MAP_ANONYMOUS(), 32, "MAP_ANONYMOUS is 32")
  state = assert_eq(state, MAP_PRIVATE(), 2, "MAP_PRIVATE is 2")
  state = assert_eq(state, MAP_SHARED(), 1, "MAP_SHARED is 1")
  state = assert_eq(state, O_RDONLY(), 0, "O_RDONLY is 0")
  state = assert_eq(state, O_WRONLY(), 1, "O_WRONLY is 1")
  state = assert_eq(state, O_RDWR(), 2, "O_RDWR is 2")
  state = assert_eq(state, O_CREAT(), 64, "O_CREAT is 64")
  state = assert_eq(state, O_TRUNC(), 512, "O_TRUNC is 512")
  state = assert_eq(state, O_APPEND(), 1024, "O_APPEND is 1024")
  state = assert_eq(state, CLOCK_REALTIME(), 0, "CLOCK_REALTIME is 0")
  state = assert_eq(state, CLOCK_MONOTONIC(), 1, "CLOCK_MONOTONIC is 1")
  state = assert_eq(state, FUTEX_WAIT(), 0, "FUTEX_WAIT is 0")
  state = assert_eq(state, FUTEX_WAKE(), 1, "FUTEX_WAKE is 1")
  state = assert_eq(state, EPOLL_CTL_ADD(), 1, "EPOLL_CTL_ADD is 1")
  state = assert_eq(state, EPOLL_CTL_DEL(), 2, "EPOLL_CTL_DEL is 2")
  state = assert_eq(state, EPOLL_CTL_MOD(), 3, "EPOLL_CTL_MOD is 3")

  @! 1.2 Errno Constants Verification
  state = assert_eq(state, EPERM(), 1, "EPERM is 1")
  state = assert_eq(state, ENOENT(), 2, "ENOENT is 2")
  state = assert_eq(state, ESRCH(), 3, "ESRCH is 3")
  state = assert_eq(state, EINTR(), 4, "EINTR is 4")
  state = assert_eq(state, EIO(), 5, "EIO is 5")
  state = assert_eq(state, EBADF(), 9, "EBADF is 9")
  state = assert_eq(state, EAGAIN(), 11, "EAGAIN is 11")
  state = assert_eq(state, ENOMEM(), 12, "ENOMEM is 12")
  state = assert_eq(state, EACCES(), 13, "EACCES is 13")
  state = assert_eq(state, EFAULT(), 14, "EFAULT is 14")
  state = assert_eq(state, EEXIST(), 17, "EEXIST is 17")
  state = assert_eq(state, EINVAL(), 22, "EINVAL is 22")
  state = assert_eq(state, EPIPE(), 32, "EPIPE is 32")
  state = assert_eq(state, ENOSYS(), 38, "ENOSYS is 38")

  @! 1.3 Error Detection Boundary Helpers
  state = assert_true(state, is_error(0 - 1), "is_error(-1) is true (EPERM)")
  state = assert_true(state, is_error(0 - 2), "is_error(-2) is true (ENOENT)")
  state = assert_true(state, is_error(0 - 4095), "is_error(-4095) is true (Max Linux Errno)")
  state = assert_false(state, is_error(0), "is_error(0) is false (Success)")
  state = assert_false(state, is_error(1), "is_error(1) is false (Positive return)")
  state = assert_false(state, is_error(4096), "is_error(4096) is false (Buffer size / address)")
  state = assert_false(state, is_error(0 - 4096), "is_error(-4096) is false (Beyond Linux errno range)")

  state = assert_true(state, is_ok(0), "is_ok(0) is true")
  state = assert_true(state, is_ok(1024), "is_ok(1024) is true")
  state = assert_false(state, is_ok(0 - 9), "is_ok(-9) is false")

  state = assert_eq(state, get_errno(0 - 1), 1, "get_errno(-1) extracts errno 1 (EPERM)")
  state = assert_eq(state, get_errno(0 - 22), 22, "get_errno(-22) extracts errno 22 (EINVAL)")
  state = assert_eq(state, get_errno(0 - 38), 38, "get_errno(-38) extracts errno 38 (ENOSYS)")
  state = assert_eq(state, get_errno(0), 0, "get_errno(0) returns 0 on non-error")
  state = assert_eq(state, get_errno(100), 0, "get_errno(100) returns 0 on non-error")

  @! 1.4 Errno Name & String Translations
  state = assert_str_eq(state, errno_name(1), "EPERM", "errno_name(1) == EPERM")
  state = assert_str_eq(state, errno_name(2), "ENOENT", "errno_name(2) == ENOENT")
  state = assert_str_eq(state, errno_name(9), "EBADF", "errno_name(9) == EBADF")
  state = assert_str_eq(state, errno_name(22), "EINVAL", "errno_name(22) == EINVAL")
  state = assert_str_eq(state, errno_name(38), "ENOSYS", "errno_name(38) == ENOSYS")
  state = assert_str_eq(state, errno_name(9999), "EUNKNOWN", "errno_name(9999) == EUNKNOWN fallback")

  state = assert_str_eq(state, errno_strerror(1), "Operation not permitted", "errno_strerror(1)")
  state = assert_str_eq(state, errno_strerror(2), "No such file or directory", "errno_strerror(2)")
  state = assert_str_eq(state, errno_strerror(9), "Bad file descriptor", "errno_strerror(9)")
  state = assert_str_eq(state, errno_strerror(22), "Invalid argument", "errno_strerror(22)")
  state = assert_str_eq(state, errno_strerror(38), "Function not implemented", "errno_strerror(38)")
  state = assert_str_eq(state, errno_strerror(9999), "Unknown system error", "errno_strerror(9999) fallback")

  @! 1.5 Adversarial Raw Syscall Execution with Invalid Arguments
  @! Invalid syscall number (99999) should return -ENOSYS (-38)
  res_bad_sys = syscall(99999, 0, 0, 0, 0, 0, 0)
  state = assert_true(state, is_error(res_bad_sys), "Invalid syscall 99999 returns negative error code")
  state = assert_eq(state, get_errno(res_bad_sys), 38, "Invalid syscall 99999 yields ENOSYS (38)")

  @! Bad file descriptor operations (fd = -1 or fd = 999999)
  res_close_bad = sys_close(0 - 1)
  state = assert_true(state, is_error(res_close_bad), "sys_close(-1) returns negative error")
  state = assert_eq(state, get_errno(res_close_bad), 9, "sys_close(-1) yields EBADF (9)")

  res_read_bad = sys_read(0 - 1, 0, 100)
  state = assert_true(state, is_error(res_read_bad), "sys_read(-1, null, 100) returns negative error")
  state = assert_eq(state, get_errno(res_read_bad), 9, "sys_read(-1) yields EBADF (9)")

  res_write_bad = sys_write(0 - 1, 0, 100)
  state = assert_true(state, is_error(res_write_bad), "sys_write(-1, null, 100) returns negative error")
  state = assert_eq(state, get_errno(res_write_bad), 9, "sys_write(-1) yields EBADF (9)")

  res_lseek_bad = sys_lseek(0 - 1, 0, 0)
  state = assert_true(state, is_error(res_lseek_bad), "sys_lseek(-1, 0, 0) returns negative error")
  state = assert_eq(state, get_errno(res_lseek_bad), 9, "sys_lseek(-1) yields EBADF (9)")

  @! Nonexistent process signal (PID 999999) -> ESRCH (3)
  res_kill_bad = sys_kill(999999, 0)
  state = assert_true(state, is_error(res_kill_bad), "sys_kill(999999, 0) returns negative error")
  state = assert_eq(state, get_errno(res_kill_bad), 3, "sys_kill(999999, 0) yields ESRCH (3)")

  return state
@end

@! ============================================================================
@! 2. COMMAND DISPATCHER ADVERSARIAL STRESS TESTS
@! ============================================================================

@fn test_command_dispatcher_stress(state)
  println("\n▶ [Challenger 1.2] Stress Testing Command Dispatcher & Tokenizer...")

  @! 2.1 Malformed and Unterminated Quotes
  toks_single_unclosed = dispatcher_tokenize("'unterminated single quote")
  state = assert_eq(state, toks_single_unclosed.len(), 1, "Unterminated single quote produces 1 token")
  state = assert_str_eq(state, toks_single_unclosed[0].val, "unterminated single quote", "Unterminated single quote content extracted")

  toks_double_unclosed = dispatcher_tokenize("\"unterminated double quote with words")
  state = assert_eq(state, toks_double_unclosed.len(), 1, "Unterminated double quote produces 1 token")
  state = assert_str_eq(state, toks_double_unclosed[0].val, "unterminated double quote with words", "Unterminated double quote content extracted")

  @! 2.2 Nested Escapes & Escape Characters
  toks_escapes = dispatcher_tokenize("\"hello\\nworld\\ttab\\\"quote\\\\backslash\"")
  state = assert_eq(state, toks_escapes.len(), 1, "Double quotes with nested escapes produce 1 token")
  state = assert_str_eq(state, toks_escapes[0].val, "hello\nworld\ttab\"quote\\backslash", "Nested escape sequences decoded correctly")

  @! 2.3 Empty and Adjacent Quotes
  toks_empty = dispatcher_tokenize("\"\" '' \"hello\"")
  state = assert_eq(state, toks_empty.len(), 3, "Empty quotes produce separate empty tokens")
  state = assert_str_eq(state, toks_empty[0].val, "", "Token 0 is empty string")
  state = assert_str_eq(state, toks_empty[1].val, "", "Token 1 is empty string")
  state = assert_str_eq(state, toks_empty[2].val, "hello", "Token 2 is hello")

  @! 2.4 Complex Multi-Pipe Chains (5-Stage Pipeline)
  cmd_5pipe = "echo 'stage1' | cat | tr a b | sort | uniq"
  toks_5pipe = dispatcher_tokenize(cmd_5pipe)
  state = assert_eq(state, toks_5pipe.len(), 11, "5-stage pipeline tokenized into 11 tokens")

  pipe_parsed = dispatcher_parse_pipeline(toks_5pipe)
  state = assert_eq(state, pipe_parsed.stages.len(), 5, "Parsed exactly 5 pipeline stages")
  state = assert_str_eq(state, pipe_parsed.stages[0].command, "echo", "Stage 1 command is echo")
  state = assert_str_eq(state, pipe_parsed.stages[1].command, "cat", "Stage 2 command is cat")
  state = assert_str_eq(state, pipe_parsed.stages[2].command, "tr", "Stage 3 command is tr")
  state = assert_str_eq(state, pipe_parsed.stages[3].command, "sort", "Stage 4 command is sort")
  state = assert_str_eq(state, pipe_parsed.stages[4].command, "uniq", "Stage 5 command is uniq")

  @! 2.5 Pipe Edge Cases (Leading, Trailing, Consecutive Pipes)
  toks_lead_pipe = dispatcher_tokenize("| echo foo")
  parsed_lead = dispatcher_parse_pipeline(toks_lead_pipe)
  state = assert_eq(state, parsed_lead.stages.len(), 1, "Leading pipe does not create empty stage")
  state = assert_str_eq(state, parsed_lead.stages[0].command, "echo", "Leading pipe stage command is echo")

  toks_trail_pipe = dispatcher_tokenize("echo foo |")
  parsed_trail = dispatcher_parse_pipeline(toks_trail_pipe)
  state = assert_eq(state, parsed_trail.stages.len(), 1, "Trailing pipe does not create empty trailing stage")

  toks_consec_pipe = dispatcher_tokenize("echo foo || cat bar")
  parsed_consec = dispatcher_parse_pipeline(toks_consec_pipe)
  state = assert_eq(state, parsed_consec.stages.len(), 2, "Consecutive pipes produce 2 valid stages")

  @! 2.6 Redirection Collisions & Complex Redirects
  cmd_redir = "app < input.txt > output.log 2>> error.log 2>&1 &"
  toks_redir = dispatcher_tokenize(cmd_redir)
  parsed_redir = dispatcher_parse_pipeline(toks_redir)
  state = assert_eq(state, parsed_redir.is_background, 1, "Background ampersand '&' detected")
  state = assert_eq(state, parsed_redir.stages.len(), 1, "Single command with multiple redirections")
  
  stg_r = parsed_redir.stages[0]
  state = assert_eq(state, stg_r.redirections.len(), 4, "Extracted all 4 redirections (<, >, 2>>, 2>&1)")
  state = assert_eq(state, stg_r.redirections[0].redir_type, REDIR_IN(), "Redirection 0 is REDIR_IN")
  state = assert_str_eq(state, stg_r.redirections[0].target, "input.txt", "Target 0 is input.txt")
  state = assert_eq(state, stg_r.redirections[1].redir_type, REDIR_OUT(), "Redirection 1 is REDIR_OUT")
  state = assert_str_eq(state, stg_r.redirections[1].target, "output.log", "Target 1 is output.log")
  state = assert_eq(state, stg_r.redirections[2].redir_type, REDIR_ERR_APP(), "Redirection 2 is REDIR_ERR_APP")
  state = assert_str_eq(state, stg_r.redirections[2].target, "error.log", "Target 2 is error.log")
  state = assert_eq(state, stg_r.redirections[3].redir_type, REDIR_ERR_TO_OUT(), "Redirection 3 is REDIR_ERR_TO_OUT")

  @! Redirection without target at end of line
  toks_dangling_redir = dispatcher_tokenize("echo hello >")
  parsed_dangling = dispatcher_parse_pipeline(toks_dangling_redir)
  state = assert_eq(state, parsed_dangling.stages.len(), 1, "Dangling redirect command parsed safely")
  state = assert_eq(state, parsed_dangling.stages[0].redirections.len(), 0, "Dangling redirect safely dropped")

  @! 2.7 PATH Resolution & Nonexistent Command
  path_ls = dispatcher_resolve_path("ls")
  state = assert_true(state, path_ls.len() > 0, "Resolved 'ls' in system PATH")
  state = assert_true(state, dispatcher_str_contains(path_ls, "/bin/ls"), "'ls' resolves to /bin/ls or /usr/bin/ls")

  path_direct = dispatcher_resolve_path("/bin/sh")
  state = assert_str_eq(state, path_direct, "/bin/sh", "Direct absolute path '/bin/sh' resolves directly")

  path_nonexistent = dispatcher_resolve_path("nonexistent_binary_maya_123456789")
  state = assert_str_eq(state, path_nonexistent, "", "Nonexistent binary returns empty string")

  @! 2.8 Builtin Execution Stress
  b_echo = dispatcher_exec_builtin("echo", ["echo", "A", "B", "C", "D", "E"])
  state = assert_eq(state, b_echo.exit_code, 0, "echo builtin exit code is 0")
  state = assert_str_eq(state, b_echo.stdout_data, "A B C D E\n", "echo builtin multi-arg formatting")

  b_echo_empty = dispatcher_exec_builtin("echo", ["echo"])
  state = assert_str_eq(state, b_echo_empty.stdout_data, "\n", "echo builtin with 0 args outputs newline")

  b_true = dispatcher_exec_builtin("true", ["true"])
  state = assert_eq(state, b_true.exit_code, 0, "true builtin exit code is 0")

  b_false = dispatcher_exec_builtin("false", ["false"])
  state = assert_eq(state, b_false.exit_code, 1, "false builtin exit code is 1")

  b_which_good = dispatcher_exec_builtin("which", ["which", "ls"])
  state = assert_eq(state, b_which_good.exit_code, 0, "which builtin finds existing command")
  state = assert_true(state, b_which_good.stdout_data.len() > 0, "which builtin outputs binary path")

  b_which_missing = dispatcher_exec_builtin("which", ["which", "nonexistent_binary_xyz_999"])
  state = assert_eq(state, b_which_missing.exit_code, 1, "which builtin fails for nonexistent binary")

  b_cd_bad = dispatcher_exec_builtin("cd", ["cd", "/nonexistent_maya_directory_404"])
  state = assert_eq(state, b_cd_bad.exit_code, 1, "cd to nonexistent directory returns error code 1")

  return state
@end

@! ============================================================================
@! 3. TASK SCHEDULER ADVERSARIAL STRESS & MLFQ ENGINE HARNESS
@! ============================================================================

@fn test_task_scheduler_stress(state)
  println("\n▶ [Challenger 1.3] Stress Testing Task Scheduler & MLFQ 3-Tier Engine...")

  @! 3.1 Rapid Bulk Task Creation Stress (250 Tasks)
  sched_bulk = scheduler_init(SCHED_MODE_MLFQ())
  state = assert_eq(state, sched_bulk.tasks.len(), 0, "Scheduler initialized with 0 tasks")
  state = assert_eq(state, sched_bulk.mode, 1, "Scheduler mode is MLFQ (1)")

  k = 1
  @while k <= 250
    priority_level = (k % 3)
    tid = scheduler_create_task(sched_bulk, "bulk_task_" + k.to_str(), 1000 + k * 8, 4096, priority_level)
    state = assert_eq(state, tid, k, "Task " + k.to_str() + " assigned monotonic ID " + k.to_str())
    k = k + 1
  @end

  state = assert_eq(state, sched_bulk.tasks.len(), 250, "Bulk created 250 tasks successfully")
  state = assert_eq(state, sched_bulk.current_task_id, 1, "Active running task is Task 1")

  @! Verify Task 1 (first created) is in RUNNING state, and others are in READY state
  t1 = scheduler_get_task(sched_bulk, 1)
  t250 = scheduler_get_task(sched_bulk, 250)
  state = assert_eq(state, t1.state, TASK_STATE_RUNNING(), "Task 1 initial state is RUNNING (1)")
  state = assert_eq(state, t250.state, TASK_STATE_READY(), "Task 250 initial state is READY (0)")
  state = assert_eq(state, t250.stack_size, 4096, "Task 250 stack size is 4096")
  state = assert_eq(state, t250.context.rflags, 514, "Task 250 context rflags is 514 (0x202)")

  @! 3.2 Heavy CPU Bursts & MLFQ Demotion Across Q0 -> Q1 -> Q2
  sched_mlfq = scheduler_init(SCHED_MODE_MLFQ())
  tid_cpu = scheduler_create_task(sched_mlfq, "cpu_burner", 5000, 4096, 0)
  state = assert_eq(state, tid_cpu, 1, "Created CPU burner task at Q0 (priority 0)")

  task_cpu = scheduler_get_task(sched_mlfq, 1)
  state = assert_eq(state, task_cpu.priority, 0, "Initial priority is 0 (Q0)")
  state = assert_eq(state, task_cpu.time_slice, MLFQ_Q0_QUANTUM(), "Initial Q0 quantum is 10")
  state = assert_eq(state, task_cpu.quantum_remaining, 10, "Initial quantum remaining is 10")
  state = assert_eq(state, task_cpu.preemptions_count, 0, "Initial preemptions count is 0")

  @! Burn 9 ticks (just below Q0 quantum of 10)
  t_idx = 0
  @while t_idx < 9
    scheduler_tick(sched_mlfq)
    t_idx = t_idx + 1
  @end

  state = assert_eq(state, task_cpu.total_ticks_run, 9, "Ran 9 ticks")
  state = assert_eq(state, task_cpu.quantum_remaining, 1, "1 tick remaining in Q0 quantum")
  state = assert_eq(state, task_cpu.priority, 0, "Priority remains 0 (Q0) before expiration")
  state = assert_eq(state, task_cpu.preemptions_count, 0, "No preemption yet")

  @! 10th tick expires Q0 quantum -> Demote to Priority 1 (Q1, quantum 20)
  scheduler_tick(sched_mlfq)
  state = assert_eq(state, task_cpu.total_ticks_run, 10, "Ran 10 ticks total")
  state = assert_eq(state, task_cpu.priority, 1, "Demoted from Q0 (0) to Q1 (1) after 10 ticks")
  state = assert_eq(state, task_cpu.time_slice, MLFQ_Q1_QUANTUM(), "New time slice is Q1 quantum (20)")
  state = assert_eq(state, task_cpu.quantum_remaining, 20, "Reset quantum remaining to 20")
  state = assert_eq(state, task_cpu.preemptions_count, 1, "Preemptions count incremented to 1")

  @! Burn 19 ticks in Q1
  t_idx = 0
  @while t_idx < 19
    scheduler_tick(sched_mlfq)
    t_idx = t_idx + 1
  @end

  state = assert_eq(state, task_cpu.total_ticks_run, 29, "Ran 29 ticks total")
  state = assert_eq(state, task_cpu.quantum_remaining, 1, "1 tick remaining in Q1 quantum")
  state = assert_eq(state, task_cpu.priority, 1, "Priority remains 1 (Q1)")

  @! 20th tick in Q1 (30th total) expires Q1 quantum -> Demote to Priority 2 (Q2, quantum 40)
  scheduler_tick(sched_mlfq)
  state = assert_eq(state, task_cpu.total_ticks_run, 30, "Ran 30 ticks total")
  state = assert_eq(state, task_cpu.priority, 2, "Demoted from Q1 (1) to Q2 (2) after 30 ticks")
  state = assert_eq(state, task_cpu.time_slice, MLFQ_Q2_QUANTUM(), "New time slice is Q2 quantum (40)")
  state = assert_eq(state, task_cpu.quantum_remaining, 40, "Reset quantum remaining to 40")
  state = assert_eq(state, task_cpu.preemptions_count, 2, "Preemptions count incremented to 2")

  @! Burn 40 ticks in Q2 (70 ticks total) -> Stays in Priority 2, quantum resets to 40
  t_idx = 0
  @while t_idx < 40
    scheduler_tick(sched_mlfq)
    t_idx = t_idx + 1
  @end

  state = assert_eq(state, task_cpu.total_ticks_run, 70, "Ran 70 ticks total")
  state = assert_eq(state, task_cpu.priority, 2, "Priority capped at Q2 (2)")
  state = assert_eq(state, task_cpu.time_slice, 40, "Time slice remains 40 in Q2")
  state = assert_eq(state, task_cpu.quantum_remaining, 40, "Quantum reset to 40 after Q2 preemption")
  state = assert_eq(state, task_cpu.preemptions_count, 3, "Preemptions count incremented to 3")

  @! 3.3 Cooperative Yields Retain Priority & Quantum Remaining
  sched_coop = scheduler_init(SCHED_MODE_MLFQ())
  tid_coop1 = scheduler_create_task(sched_coop, "coop1", 100, 4096, 0)
  tid_coop2 = scheduler_create_task(sched_coop, "coop2", 200, 4096, 0)

  @! Run 4 ticks on Task 1
  t_idx = 0
  @while t_idx < 4
    scheduler_tick(sched_coop)
    t_idx = t_idx + 1
  @end

  t_coop1 = scheduler_get_task(sched_coop, 1)
  state = assert_eq(state, t_coop1.quantum_remaining, 6, "Task 1 has 6 ticks quantum remaining")

  @! Cooperative yield: switches to Task 2, Task 1 preserves priority 0
  next_tid = scheduler_yield(sched_coop)
  state = assert_eq(state, next_tid, 2, "scheduler_yield switched context to Task 2")
  state = assert_eq(state, t_coop1.voluntary_yields_count, 1, "Voluntary yield count incremented")
  state = assert_eq(state, t_coop1.priority, 0, "Priority 0 preserved during voluntary yield (no demotion penalty)")
  state = assert_eq(state, t_coop1.state, TASK_STATE_READY(), "Task 1 returned to READY after yield")

  t_coop2 = scheduler_get_task(sched_coop, 2)
  state = assert_eq(state, t_coop2.state, TASK_STATE_RUNNING(), "Task 2 is now RUNNING")

  @! 3.4 100-Tick Starvation Boost Validation
  @! Advance system ticks to reach 100-tick threshold
  sched_boost = scheduler_init(SCHED_MODE_MLFQ())
  t_demoted1 = scheduler_create_task(sched_boost, "demoted_q1", 10, 4096, 1)
  t_demoted2 = scheduler_create_task(sched_boost, "demoted_q2", 20, 4096, 2)
  t_fresh = scheduler_create_task(sched_boost, "fresh_q0", 30, 4096, 0)

  task_d1 = scheduler_get_task(sched_boost, 1)
  task_d2 = scheduler_get_task(sched_boost, 2)
  state = assert_eq(state, task_d1.priority, 1, "Task D1 initially at Priority 1")
  state = assert_eq(state, task_d2.priority, 2, "Task D2 initially at Priority 2")

  @! Advance 105 ticks to exceed 100-tick starvation boost window
  tick_count = 0
  @while tick_count < 105
    scheduler_tick(sched_boost)
    tick_count = tick_count + 1
  @end

  @! Trigger schedule check to evaluate starvation boost
  scheduler_schedule_next(sched_boost)

  state = assert_eq(state, task_d1.priority, 0, "Anti-starvation boost promoted Task D1 from Q1 back to Q0 (0)")
  state = assert_eq(state, task_d1.quantum_remaining, 10, "Task D1 quantum reset to Q0 quantum 10")
  state = assert_eq(state, task_d2.priority, 0, "Anti-starvation boost promoted Task D2 from Q2 back to Q0 (0)")
  state = assert_eq(state, task_d2.quantum_remaining, 10, "Task D2 quantum reset to Q0 quantum 10")
  state = assert_true(state, sched_boost.last_boost_tick >= 100, "Scheduler recorded boost timestamp >= 100")

  @! 3.5 Sleep Wakeup Under High Load & Metric Invariants
  sched_sleep = scheduler_init(SCHED_MODE_ROUND_ROBIN())
  tid_worker = scheduler_create_task(sched_sleep, "worker", 10, 4096, 0)
  tid_sleeper1 = scheduler_create_task(sched_sleep, "sleeper_5", 20, 4096, 0)
  tid_sleeper2 = scheduler_create_task(sched_sleep, "sleeper_15", 30, 4096, 0)

  @! Switch to sleeper 1 and put it to sleep for 5 ticks
  scheduler_schedule_next(sched_sleep)
  scheduler_sleep(sched_sleep, 5)

  task_slp1 = scheduler_get_task(sched_sleep, tid_sleeper1)
  state = assert_eq(state, task_slp1.state, TASK_STATE_BLOCKED(), "Sleeper 1 is BLOCKED (2)")
  state = assert_str_eq(state, task_slp1.block_reason, "timer_sleep", "Block reason is timer_sleep")

  @! Switch to sleeper 2 and put it to sleep for 15 ticks
  scheduler_schedule_next(sched_sleep)
  scheduler_sleep(sched_sleep, 15)

  task_slp2 = scheduler_get_task(sched_sleep, tid_sleeper2)
  state = assert_eq(state, task_slp2.state, TASK_STATE_BLOCKED(), "Sleeper 2 is BLOCKED (2)")

  @! Check metrics under sleep
  m_pre = scheduler_metrics(sched_sleep)
  state = assert_eq(state, m_pre.blocked, 2, "Metrics report exactly 2 blocked tasks")
  state = assert_eq(state, m_pre.total_tasks, 3, "Metrics report 3 total tasks")

  @! Advance 6 ticks: Sleeper 1 should wake up, Sleeper 2 still sleeping
  t_adv = 0
  @while t_adv < 6
    scheduler_tick(sched_sleep)
    t_adv = t_adv + 1
  @end

  scheduler_schedule_next(sched_sleep)
  state = assert_true(state, task_slp1.state == TASK_STATE_READY() || task_slp1.state == TASK_STATE_RUNNING(), "Sleeper 1 woke up after 6 ticks")
  state = assert_eq(state, task_slp2.state, TASK_STATE_BLOCKED(), "Sleeper 2 remains BLOCKED at 6 ticks")

  @! Advance another 10 ticks (16 total): Sleeper 2 wakes up
  t_adv = 0
  @while t_adv < 10
    scheduler_tick(sched_sleep)
    t_adv = t_adv + 1
  @end

  scheduler_schedule_next(sched_sleep)
  state = assert_true(state, task_slp2.state == TASK_STATE_READY() || task_slp2.state == TASK_STATE_RUNNING(), "Sleeper 2 woke up after 16 ticks")

  @! 3.6 Task Termination & Empty Scheduler Handling
  state = assert_eq(state, scheduler_terminate_task(sched_sleep, tid_worker), 1, "Terminated worker task")
  state = assert_eq(state, scheduler_terminate_task(sched_sleep, tid_sleeper1), 1, "Terminated sleeper 1")
  state = assert_eq(state, scheduler_terminate_task(sched_sleep, tid_sleeper2), 1, "Terminated sleeper 2")

  m_post = scheduler_metrics(sched_sleep)
  state = assert_eq(state, m_post.terminated, 3, "Metrics report 3 terminated tasks")
  state = assert_eq(state, m_post.ready, 0, "Metrics report 0 ready tasks")
  state = assert_eq(state, m_post.running, 0, "Metrics report 0 running tasks")

  @! Scheduling with all tasks terminated gracefully returns -1
  next_empty = scheduler_schedule_next(sched_sleep)
  state = assert_eq(state, next_empty, 0 - 1, "Scheduling with all tasks terminated returns -1 safely")

  return state
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("⚔️ ADVERSARIAL CHALLENGER 1 SUITE: NATIVE MAYA OS KERNEL ⚔️")
  println("Milestone 1: Syscalls, Command Dispatcher & Task Scheduler")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  state = test_syscall_layer_stress(state)
  state = test_command_dispatcher_stress(state)
  state = test_task_scheduler_stress(state)

  println("\n=================================================================")
  println("📊 ADVERSARIAL CHALLENGER 1 RESULTS:")
  println("   Total Assertions : " + state.total.to_str())
  println("   Passed           : " + state.passed.to_str())
  println("   Failed           : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed > 0
    println("❌ CHALLENGER 1 DETECTED BUGS / TEST FAILURES!")
    return 1
  @end

  println("🎉 ALL CHALLENGER 1 ADVERSARIAL STRESS TESTS PASSED CLEANLY! 🎉")
  return 0
@end
