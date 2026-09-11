@! ============================================================================
@! REVIEWER 1 ADVERSARIAL STRESS TEST: F01-F04 (tests/os/test_m1_reviewer_adversarial.maya)
@! Independent Verification of Syscalls, Process, Dispatcher, and Scheduler
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/os/dispatcher"
import "universe/os/scheduler"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔬 REVIEWER 1: ADVERSARIAL STRESS TEST SUITE (F01-F04) 🔬")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! TEST 1: F01 Syscalls & Errno Boundary Stress
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 1] Syscall Errno Boundaries & Unknown Code Handling...")
  total_tests = total_tests + 1
  
  ok1 = assert_eq_str(errno_name(9999), "EUNKNOWN", "Unknown errno maps to EUNKNOWN")
  ok2 = assert_eq_str(errno_strerror(9999), "Unknown system error", "Unknown errno message maps correctly")
  ok3 = assert_true(is_error(0 - 4095), "-4095 is recognized as error")
  ok4 = assert_true(is_error(0 - 1), "-1 is recognized as error")
  ok5 = assert_true(!is_error(0), "0 is not an error")
  ok6 = assert_true(!is_error(100), "100 is not an error")
  ok7 = assert_true(!is_error(0 - 4096), "-4096 is outside standard Linux errno range")
  ok8 = assert_eq_int(get_errno(0), 0, "get_errno(0) returns 0")
  ok9 = assert_eq_int(get_errno(100), 0, "get_errno(100) returns 0")
  ok10 = assert_eq_int(get_errno(0 - 22), 22, "get_errno(-22) returns 22 (EINVAL)")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Syscall errno boundary checks verified.")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 2: F02 Process Wait Status Exhaustive Signal / Exit Matrix
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 2] Process Wait Status Matrix Stress...")
  total_tests = total_tests + 1

  fail_f02 = 0
  @! Test all exit codes 0..255
  code = 0
  @while code <= 255
    raw_status = code * 256
    @if process_wexitstatus(raw_status) != code
      println("  [FAIL] process_wexitstatus mismatch for code " + code.to_str())
      fail_f02 = fail_f02 + 1
    @end
    @if process_wifexited(raw_status) != 1
      println("  [FAIL] process_wifexited mismatch for code " + code.to_str())
      fail_f02 = fail_f02 + 1
    @end
    @if process_wifsignaled(raw_status) != 0
      println("  [FAIL] process_wifsignaled false positive for code " + code.to_str())
      fail_f02 = fail_f02 + 1
    @end
    code = code + 1
  @end

  @! Test all terminating signals 1..31
  sig = 1
  @while sig <= 31
    raw_sig_status = sig
    @if process_wtermsig(raw_sig_status) != sig
      println("  [FAIL] process_wtermsig mismatch for signal " + sig.to_str())
      fail_f02 = fail_f02 + 1
    @end
    @if process_wifsignaled(raw_sig_status) != 1
      println("  [FAIL] process_wifsignaled false negative for signal " + sig.to_str())
      fail_f02 = fail_f02 + 1
    @end
    @if process_wifexited(raw_sig_status) != 0
      println("  [FAIL] process_wifexited false positive for signal " + sig.to_str())
      fail_f02 = fail_f02 + 1
    @end
    sig = sig + 1
  @end

  @if fail_f02 == 0
    passed_tests = passed_tests + 1
    println("  [PASS] All 256 exit codes and 31 signals verified in wait status matrix.")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 3: F03 Command Tokenizer & Pipeline Parser Corner Cases
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 3] Command Tokenizer & Pipeline Parser Edge Cases...")
  total_tests = total_tests + 1

  @! 3.1 Empty input
  toks_empty = dispatcher_tokenize("")
  ok_tok_empty = assert_eq_int(toks_empty.len(), 0, "Empty command line produces 0 tokens")

  @! 3.2 Whitespace only
  toks_ws = dispatcher_tokenize("   \t  \n  \r  ")
  ok_tok_ws = assert_eq_int(toks_ws.len(), 0, "Whitespace only produces 0 tokens")

  @! 3.3 Escapes inside quotes and outside quotes
  toks_esc = dispatcher_tokenize("echo \"hello\\nworld\" 'tab\\ttest' foo\\ bar")
  ok_tok_len = assert_eq_int(toks_esc.len(), 4, "Token count with mixed quotes and escapes is 4")
  ok_esc1 = assert_eq_str(toks_esc[1].val, "hello\nworld", "Double quote escape \\n decoded")
  ok_esc2 = assert_eq_str(toks_esc[2].val, "tab\\ttest", "Single quote escape preserved literally")
  ok_esc3 = assert_eq_str(toks_esc[3].val, "foo bar", "Unquoted escaped space merged into word")

  @! 3.4 Multiple Redirections and Pipelines
  pipe_str = "cat < in.txt | grep 'pattern' | sort -r >> out.log 2>&1 &"
  pipe_toks = dispatcher_tokenize(pipe_str)
  pipe_ast = dispatcher_parse_pipeline(pipe_toks)
  ok_stages = assert_eq_int(pipe_ast.stages.len(), 3, "Parsed 3 pipeline stages")
  ok_bg = assert_eq_int(pipe_ast.is_background, 1, "Background execution flag '&' detected")
  
  stg1 = pipe_ast.stages[0]
  ok_stg1_cmd = assert_eq_str(stg1.command, "cat", "Stage 1 command is cat")
  ok_stg1_redir = assert_eq_int(stg1.redirections[0].redir_type, 1, "Stage 1 has REDIR_IN")

  stg3 = pipe_ast.stages[2]
  ok_stg3_cmd = assert_eq_str(stg3.command, "sort", "Stage 3 command is sort")
  ok_stg3_redirs = assert_eq_int(stg3.redirections.len(), 2, "Stage 3 has 2 redirections (>> and 2>&1)")
  ok_stg3_r1 = assert_eq_int(stg3.redirections[0].redir_type, 3, "Stage 3 redir 1 is REDIR_APP (>>)")
  ok_stg3_r2 = assert_eq_int(stg3.redirections[1].redir_type, 6, "Stage 3 redir 2 is REDIR_ERR_TO_OUT (2>&1)")

  @if ok_tok_empty == 1 && ok_tok_ws == 1 && ok_tok_len == 1 && ok_esc1 == 1 && ok_esc2 == 1 && ok_esc3 == 1 && ok_stages == 1 && ok_bg == 1 && ok_stg1_cmd == 1 && ok_stg1_redir == 1 && ok_stg3_cmd == 1 && ok_stg3_redirs == 1 && ok_stg3_r1 == 1 && ok_stg3_r2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Complex tokenizer, escapes, redirections and pipeline parsing verified.")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 4: F04 Scheduler High-Load MLFQ & Starvation Stress
  @! ----------------------------------------------------------------------------
  println("▶ [ADVERSARIAL 4] Scheduler High-Load MLFQ & Task Lifecycle Stress...")
  total_tests = total_tests + 1

  sched = scheduler_init(1) @! MLFQ
  @! Create 20 tasks
  k = 0
  @while k < 20
    scheduler_create_task(sched, "task_" + k.to_str(), 1000 + k, 4096, 0)
    k = k + 1
  @end

  m1 = scheduler_metrics(sched)
  ok_m_total = assert_eq_int(m1.total_tasks, 20, "20 tasks registered in scheduler")
  ok_m_ready = assert_eq_int(m1.ready, 19, "19 ready tasks")
  ok_m_running = assert_eq_int(m1.running, 1, "1 running task")

  @! Advance 250 ticks across all tasks
  t = 0
  @while t < 250
    scheduler_tick(sched)
    t = t + 1
  @end

  m2 = scheduler_metrics(sched)
  ok_ticks = assert_eq_int(m2.system_ticks, 250, "Scheduler system ticks reached 250")
  ok_switches = assert_true(m2.context_switches > 10, "Multiple context switches executed across tasks")

  @! Block and unblock tasks
  ok_block = assert_eq_int(scheduler_block_task(sched, 5, "io_wait"), 1, "Blocked task 5")
  t5 = scheduler_get_task(sched, 5)
  ok_t5_state = assert_eq_int(t5.state, 2, "Task 5 is BLOCKED (state 2)")
  
  ok_unblock = assert_eq_int(scheduler_unblock_task(sched, 5), 1, "Unblocked task 5")
  ok_t5_unblocked = assert_eq_int(t5.state, 0, "Task 5 returned to READY (state 0)")

  @! Terminate task
  ok_term = assert_eq_int(scheduler_terminate_task(sched, 10), 1, "Terminated task 10")
  t10 = scheduler_get_task(sched, 10)
  ok_t10_state = assert_eq_int(t10.state, 3, "Task 10 is TERMINATED (state 3)")

  @! Non-existent task handling
  ok_bad_block = assert_eq_int(scheduler_block_task(sched, 9999, "none"), 0, "Blocking non-existent task returns 0")
  ok_bad_unblock = assert_eq_int(scheduler_unblock_task(sched, 9999), 0, "Unblocking non-existent task returns 0")
  ok_bad_term = assert_eq_int(scheduler_terminate_task(sched, 9999), 0, "Terminating non-existent task returns 0")

  @if ok_m_total == 1 && ok_m_ready == 1 && ok_m_running == 1 && ok_ticks == 1 && ok_switches == 1 && ok_block == 1 && ok_t5_state == 1 && ok_unblock == 1 && ok_t5_unblocked == 1 && ok_term == 1 && ok_t10_state == 1 && ok_bad_block == 1 && ok_bad_unblock == 1 && ok_bad_term == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Scheduler high-load MLFQ, blocking, termination, and metrics stress tests passed.")
  @end

  println("=================================================================")
  println("📊 ADVERSARIAL STRESS RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " sections passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL REVIEWER ADVERSARIAL TESTS PASSED! (100% SUCCESS) 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL STRESS TESTS FAILED")
    return 1
  @end
@end
