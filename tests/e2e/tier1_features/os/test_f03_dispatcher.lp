@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F03: NATIVE COMMAND DISPATCHER
@! File: tests/e2e/tier1_features/os/test_f03_dispatcher.maya
@! Description: Validates shell-free command tokenization, path lookup, and execution
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/os/dispatcher"
import "universe/tools/maya_test"

@fn test_f03_01_tokenize_basic()
  cmd = "echo 'hello sovereign world' 42"
  tokens = dispatcher_tokenize(cmd)
  assert_eq(tokens.len(), 3, "Token count must be 3 for space/quoted command")
  
  t0 = tokens[0]
  assert_str_eq(t0.kind, "WORD", "Token 0 kind must be WORD")
  assert_str_eq(t0.val, "echo", "Token 0 val must be 'echo'")

  t1 = tokens[1]
  assert_str_eq(t1.kind, "WORD", "Token 1 kind must be WORD")
  assert_str_eq(t1.val, "hello sovereign world", "Token 1 val must preserve quoted string content")

  t2 = tokens[2]
  assert_str_eq(t2.kind, "WORD", "Token 2 kind must be WORD")
  assert_str_eq(t2.val, "42", "Token 2 val must be '42'")
@end

@fn test_f03_02_path_resolution()
  @! Look up standard binaries without shell
  echo_path = dispatcher_resolve_path("echo")
  assert_true(echo_path.len() > 0, "dispatcher_resolve_path('echo') must find valid binary")

  ls_path = dispatcher_resolve_path("ls")
  assert_true(ls_path.len() > 0, "dispatcher_resolve_path('ls') must find valid binary")

  true_path = dispatcher_resolve_path("true")
  assert_true(true_path.len() > 0, "dispatcher_resolve_path('true') must find valid binary")
@end

@fn test_f03_03_builtin_execution()
  @! 1. echo builtin
  res_echo = dispatcher_exec_builtin("echo", ["echo", "maya", "sovereign", "kernel"])
  assert_eq(res_echo.exit_code, 0, "echo builtin exit code must be 0")
  assert_str_eq(res_echo.stdout_data, "maya sovereign kernel\n", "echo builtin stdout must match")

  @! 2. true builtin
  res_true = dispatcher_exec_builtin("true", ["true"])
  assert_eq(res_true.exit_code, 0, "true builtin exit code must be 0")

  @! 3. which builtin
  res_which = dispatcher_exec_builtin("which", ["which", "ls"])
  assert_eq(res_which.exit_code, 0, "which builtin exit code must be 0")
  assert_true(res_which.stdout_data.len() > 0, "which builtin must output resolved path")
@end

@fn test_f03_04_direct_exec_capture()
  res = dispatcher_run_capture("echo sovereign_dispatcher_test_payload")
  assert_eq(res.exit_code, 0, "dispatcher_run_capture exit code must be 0")
  assert_str_contains(res.stdout_data, "sovereign_dispatcher_test_payload", "Captured output must contain test string")
@end

@fn test_f03_05_pipeline_parser()
  pipe_cmd = "cat data.txt | grep sovereign | wc -l"
  tokens = dispatcher_tokenize(pipe_cmd)
  pipeline = dispatcher_parse_pipeline(tokens)
  stages = pipeline.stages
  assert_eq(stages.len(), 3, "Parsed pipeline must contain exactly 3 stages")

  s0 = stages[0]
  assert_str_eq(s0.command, "cat", "Stage 0 command must be 'cat'")
  assert_eq(s0.args.len(), 2, "Stage 0 must have 2 args ('cat', 'data.txt')")

  s1 = stages[1]
  assert_str_eq(s1.command, "grep", "Stage 1 command must be 'grep'")
  assert_eq(s1.args.len(), 2, "Stage 1 must have 2 args ('grep', 'sovereign')")

  s2 = stages[2]
  assert_str_eq(s2.command, "wc", "Stage 2 command must be 'wc'")
  assert_eq(s2.args.len(), 2, "Stage 2 must have 2 args ('wc', '-l')")
@end

@fn test_f03_06_redirection_tokens()
  cmd = "processor < input.dat > output.dat 2> error.log"
  tokens = dispatcher_tokenize(cmd)
  pipeline = dispatcher_parse_pipeline(tokens)
  stages = pipeline.stages
  assert_eq(stages.len(), 1, "Pipeline must have 1 stage")
  stg = stages[0]
  assert_str_eq(stg.command, "processor", "Command name must be 'processor'")
  assert_eq(stg.redirections.len(), 3, "Redirections list must contain 3 items (<, >, 2>)")
@end

@fn run_all_f03_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F03: Native Command Dispatcher Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f03_01_tokenize_basic")
  test_f03_01_tokenize_basic()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f03_01_tokenize_basic")

  println("  [RUN] test_f03_02_path_resolution")
  test_f03_02_path_resolution()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f03_02_path_resolution")

  println("  [RUN] test_f03_03_builtin_execution")
  test_f03_03_builtin_execution()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f03_03_builtin_execution")

  println("  [RUN] test_f03_04_direct_exec_capture")
  test_f03_04_direct_exec_capture()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f03_04_direct_exec_capture")

  println("  [RUN] test_f03_05_pipeline_parser")
  test_f03_05_pipeline_parser()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f03_05_pipeline_parser")

  println("  [RUN] test_f03_06_redirection_tokens")
  test_f03_06_redirection_tokens()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f03_06_redirection_tokens")

  println("-----------------------------------------------------------------")
  println("F03 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f03_tests()
@end
