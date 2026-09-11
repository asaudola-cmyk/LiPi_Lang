// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Enums PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: enums, constants, pattern_matching, struct_field, functions

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: ENUMS & CONSTANTS
@! File: tests/e2e/tier1_features/test_enums.maya
@! ============================================================================

@enum Status
  Pending
  Running
  Paused
  Completed
  Failed
@end

@enum Direction
  North
  South
  East
  West
@end

@struct Task
  id: i64
  name: string
  status: i64
@end

@fn get_initial_status()
  return Status_Pending
@end

@fn is_terminal_status(st)
  @if st == Status_Completed || st == Status_Failed
    return 1
  @end
  return 0
@end

@fn describe_status(st)
  @if st == Status_Pending
    return "PENDING"
  @elif st == Status_Running
    return "RUNNING"
  @elif st == Status_Paused
    return "PAUSED"
  @elif st == Status_Completed
    return "COMPLETED"
  @elif st == Status_Failed
    return "FAILED"
  @else
    return "UNKNOWN"
  @end
@end

@fn match_status_code(code)
  res = @match code
    0 => "ST_ZERO"
    1 => "ST_ONE"
    2 => "ST_TWO"
    _ => "ST_OTHER"
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Enums & Named Constants")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-EN-01: Enum variant lowering to numeric constants
  total = total + 1
  @if Status_Pending == 0 && Status_Running == 1 && Status_Paused == 2 && Status_Completed == 3 && Status_Failed == 4
    passed = passed + 1
    println("  [PASS] TC-EN-01: Status variants evaluate to 0..4")
  @else
    failed = failed + 1
    println("  [FAIL] TC-EN-01: Status variants")
  @end

  @! TC-EN-02: Enum comparison in branching
  total = total + 1
  cur_dir = Direction_East
  is_horizontal = 0
  @if cur_dir == Direction_East || cur_dir == Direction_West
    is_horizontal = 1
  @end
  @if is_horizontal == 1 && cur_dir == 2
    passed = passed + 1
    println("  [PASS] TC-EN-02: Enum comparison in conditional branches (East == 2)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-EN-02: Enum comparison")
  @end

  @! TC-EN-03: Enum branch resolution and code matching
  total = total + 1
  desc_run = describe_status(Status_Running)
  desc_done = describe_status(Status_Completed)
  desc_other = describe_status(99)
  match_0 = match_status_code(Status_Pending)
  match_1 = match_status_code(Status_Running)
  @if desc_run == "RUNNING" && desc_done == "COMPLETED" && desc_other == "UNKNOWN" && match_0 == "ST_ZERO" && match_1 == "ST_ONE"
    passed = passed + 1
    println("  [PASS] TC-EN-03: Enum branch resolution (\"RUNNING\", \"COMPLETED\", ST_ZERO)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-EN-03: Enum branch resolution")
  @end

  @! TC-EN-04: Enum stored in struct field
  total = total + 1
  t = { id: 101, name: "Bootstrap Compiler", status: Status_Running }
  @if t.id == 101 && t.status == Status_Running && t.status == 1
    passed = passed + 1
    println("  [PASS] TC-EN-04: Task struct storing enum variant in status field")
  @else
    failed = failed + 1
    println("  [FAIL] TC-EN-04: Enum in struct field")
  @end

  @! TC-EN-05: Enum as function return and parameter
  total = total + 1
  init_st = get_initial_status()
  term_init = is_terminal_status(init_st)
  term_fail = is_terminal_status(Status_Failed)
  @if init_st == Status_Pending && term_init == 0 && term_fail == 1
    passed = passed + 1
    println("  [PASS] TC-EN-05: Enum function return and parameter checking (is_terminal_status)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-EN-05: Enum function passing")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Enums PASSED")
    return 0
  @else
    println("✗ Feature: Enums FAILED")
    return 1
  @end
@end
