@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: PATTERN MATCHING ON STRUCT FIELDS
@! File: tests/e2e/tier3_combinations/test_match_struct_fields.maya
@! ============================================================================

@struct AgentTask
  id: 0
  status: 0
  priority: 0
@end

@struct Position
  x: 0
  y: 0
@end

@fn describe_task_status(task)
  @match task.status
    case 0:
      return 10 @! PENDING
    case 1:
      return 20 @! RUNNING
    case 2:
      return 30 @! COMPLETED
    case 3:
      return 40 @! FAILED
    case _:
      return 99 @! UNKNOWN
  @end
@end

@fn move_position_by_dir(pos, dir_code, step)
  @match dir_code
    case 1: @! UP
      pos.y = pos.y + step
    case 2: @! DOWN
      pos.y = pos.y - step
    case 3: @! LEFT
      pos.x = pos.x - step
    case 4: @! RIGHT
      pos.x = pos.x + step
    case _:
      pos.x = pos.x
  @end
  return pos
@end

@fn process_event_batch(events, count)
  processed_sum = 0
  i = 0
  @while i < count
    ev = events[i]
    @match ev.status
      case 100:
        processed_sum = processed_sum + ev.priority * 1
      case 200:
        processed_sum = processed_sum + ev.priority * 2
      case _:
        processed_sum = processed_sum + 0
    @end
    i = i + 1
  @end
  return processed_sum
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 4: Pattern Matching on Struct Fields")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.16: Match on Struct Status Field
  total = total + 1
  t_pending = { id: 1, status: 0, priority: 1 }
  t_running = { id: 2, status: 1, priority: 2 }
  t_done = { id: 3, status: 2, priority: 3 }
  t_fail = { id: 4, status: 3, priority: 1 }
  s0 = describe_task_status(t_pending)
  s1 = describe_task_status(t_running)
  s2 = describe_task_status(t_done)
  s3 = describe_task_status(t_fail)
  @if s0 == 10 && s1 == 20 && s2 == 30 && s3 == 40
    passed = passed + 1
    println("  [PASS] T3.16: Pattern matching on struct status fields (10, 20, 30, 40)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.16: Pattern matching on struct status fields")
  @end

  @! T3.17: Directional Movement Dispatch via Match on Struct
  total = total + 1
  pos = { x: 0, y: 0 }
  pos = move_position_by_dir(pos, 4, 10)  @! RIGHT -> (10, 0)
  pos = move_position_by_dir(pos, 1, 15)  @! UP -> (10, 15)
  pos = move_position_by_dir(pos, 3, 4)   @! LEFT -> (6, 15)
  pos = move_position_by_dir(pos, 2, 5)   @! DOWN -> (6, 10)
  @if pos.x == 6 && pos.y == 10
    passed = passed + 1
    println("  [PASS] T3.17: Match-dispatched struct coordinate transformations (6, 10)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.17: Match-dispatched struct coordinate transformations")
  @end

  @! T3.18: Batch Event Processing with Match in Loop over Struct Array
  total = total + 1
  e1 = { id: 1, status: 100, priority: 5 }
  e2 = { id: 2, status: 200, priority: 10 }
  e3 = { id: 3, status: 100, priority: 20 }
  batch = [e1, e2, e3]
  @! (5 * 1) + (10 * 2) + (20 * 1) = 5 + 20 + 20 = 45
  batch_res = process_event_batch(batch, 3)
  @if batch_res == 45
    passed = passed + 1
    println("  [PASS] T3.18: Match dispatch inside loop iterating array of structs (batch == 45)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.18: Match dispatch iterating array of structs")
  @end

  @! T3.19: Match Fallthrough to Default on Struct with Out-of-Bounds Status
  total = total + 1
  t_unknown = { id: 99, status: 999, priority: 0 }
  s_unk = describe_task_status(t_unknown)
  @if s_unk == 99
    passed = passed + 1
    println("  [PASS] T3.19: Default branch matched for unknown struct status (99)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.19: Default branch for struct status")
  @end

  @! T3.20: State Machine Sequence on Struct Instance
  total = total + 1
  current_state = 0
  step_count = 0
  @while current_state < 3
    @match current_state
      case 0:
        current_state = 1
        step_count = step_count + 1
      case 1:
        current_state = 2
        step_count = step_count + 1
      case 2:
        current_state = 3
        step_count = step_count + 1
      case _:
        current_state = 99
    @end
  @end
  @if current_state == 3 && step_count == 3
    passed = passed + 1
    println("  [PASS] T3.20: Sequential state machine execution via @match (3 transitions)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.20: State machine execution via @match")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 4 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 4 (Match On Struct Fields) PASSED")
    return 0
  @else
    println("✗ Combination 4 (Match On Struct Fields) FAILED")
    return 1
  @end
@end
