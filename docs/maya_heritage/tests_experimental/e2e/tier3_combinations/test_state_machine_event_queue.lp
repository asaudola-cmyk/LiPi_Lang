@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: STATE MACHINE & EVENT QUEUE
@! File: tests/e2e/tier3_combinations/test_state_machine_event_queue.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@enum State
  Idle
  Connecting
  Connected
  Streaming
  Disconnecting
  Terminated
@end

@enum Event
  EvConnect
  EvConnected
  EvStartStream
  EvDataPacket
  EvStopStream
  EvDisconnect
  EvDisconnected
  EvReset
@end

@struct StateMachine
  current_state: 0
  transition_count: 0
  history: 0
  packets_processed: 0
  error_count: 0
@end

@fn sm_new()
  return {
    current_state: 0,  @! State_Idle
    transition_count: 0,
    history: [],
    packets_processed: 0,
    error_count: 0
  }
@end

@fn sm_transition(sm, new_state, event_name)
  sm.history.push(event_name)
  sm.current_state = new_state
  sm.transition_count = sm.transition_count + 1
  return sm
@end

@fn sm_handle_event(sm, ev)
  s = sm.current_state
  @match s
    case 0: @! State_Idle
      @if ev == 0  @! EvConnect
        return sm_transition(sm, 1, "CONNECTING")
      @else
        sm.error_count = sm.error_count + 1
        return sm
      @end

    case 1: @! State_Connecting
      @if ev == 1  @! EvConnected
        return sm_transition(sm, 2, "CONNECTED")
      @elif ev == 5  @! EvDisconnect
        return sm_transition(sm, 4, "DISCONNECTING")
      @else
        sm.error_count = sm.error_count + 1
        return sm
      @end

    case 2: @! State_Connected
      @if ev == 2  @! EvStartStream
        return sm_transition(sm, 3, "STREAMING")
      @elif ev == 5  @! EvDisconnect
        return sm_transition(sm, 4, "DISCONNECTING")
      @else
        sm.error_count = sm.error_count + 1
        return sm
      @end

    case 3: @! State_Streaming
      @if ev == 3  @! EvDataPacket
        sm.packets_processed = sm.packets_processed + 1
        return sm
      @elif ev == 4  @! EvStopStream
        return sm_transition(sm, 2, "STREAM_STOPPED")
      @elif ev == 5  @! EvDisconnect
        return sm_transition(sm, 4, "DISCONNECTING")
      @else
        sm.error_count = sm.error_count + 1
        return sm
      @end

    case 4: @! State_Disconnecting
      @if ev == 6  @! EvDisconnected
        return sm_transition(sm, 5, "TERMINATED")
      @else
        sm.error_count = sm.error_count + 1
        return sm
      @end

    case 5: @! State_Terminated
      @if ev == 7  @! EvReset
        return sm_transition(sm, 0, "IDLE")
      @else
        sm.error_count = sm.error_count + 1
        return sm
      @end

    case _:
      sm.error_count = sm.error_count + 1
      return sm
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 15: State Machine & Event Queue")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.15.1: State Machine Initialization
  total = total + 1
  sm = sm_new()
  @if sm.current_state == 0 && sm.transition_count == 0 && sm.packets_processed == 0
    passed = passed + 1
    println("  [PASS] T3.15.1: State machine initialized to Idle (state=0, transitions=0)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.15.1: State machine init failed")
  @end

  @! T3.15.2: Process Valid Lifecycle Event Stream
  total = total + 1
  @! Sequence:
  @! 1. EvConnect (0) -> Connecting (1)
  @! 2. EvConnected (1) -> Connected (2)
  @! 3. EvStartStream (2) -> Streaming (3)
  @! 4-8. EvDataPacket (3) x 5 -> Streaming (3, packets=5)
  @! 9. EvStopStream (4) -> Connected (2)
  @! 10. EvDisconnect (5) -> Disconnecting (4)
  @! 11. EvDisconnected (6) -> Terminated (5)
  event_queue = [0, 1, 2, 3, 3, 3, 3, 3, 4, 5, 6]

  i = 0
  @while i < event_queue.len()
    sm = sm_handle_event(sm, event_queue[i])
    i = i + 1
  @end

  @if sm.current_state == 5 && sm.packets_processed == 5 && sm.error_count == 0 && sm.transition_count == 6
    passed = passed + 1
    println("  [PASS] T3.15.2: Valid event stream transitioned through Idle->Connecting->Connected->Streaming->Terminated (6 transitions, 5 packets)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.15.2: Event stream processing failed: state=" + int_to_str(sm.current_state) + ", errs=" + int_to_str(sm.error_count))
  @end

  @! T3.15.3: Transition History Verification
  total = total + 1
  @! Expected history: ["CONNECTING", "CONNECTED", "STREAMING", "STREAM_STOPPED", "DISCONNECTING", "TERMINATED"]
  @if sm.history.len() == 6 && sm.history[0] == "CONNECTING" && sm.history[2] == "STREAMING" && sm.history[5] == "TERMINATED"
    passed = passed + 1
    println("  [PASS] T3.15.3: State transition audit history matches expected chronological order")
  @else
    failed = failed + 1
    println("  [FAIL] T3.15.3: Transition history mismatch")
  @end

  @! T3.15.4: Invalid Event Handling in Terminated State
  total = total + 1
  @! EvStartStream (2) is illegal when in Terminated state (5)
  sm = sm_handle_event(sm, 2)
  @if sm.error_count == 1 && sm.current_state == 5
    passed = passed + 1
    println("  [PASS] T3.15.4: Illegal event correctly rejected and incremented error counter (errors=1)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.15.4: Illegal event handling failed")
  @end

  @! T3.15.5: Reset Event Cycle Back to Idle
  total = total + 1
  @! EvReset (7) -> Idle (0)
  sm = sm_handle_event(sm, 7)
  @if sm.current_state == 0 && sm.transition_count == 7 && sm.history[6] == "IDLE"
    passed = passed + 1
    println("  [PASS] T3.15.5: Reset event successfully returned machine to initial Idle state")
  @else
    failed = failed + 1
    println("  [FAIL] T3.15.5: Reset event failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 15 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 15 (State Machine & Event Queue) PASSED")
    return 0
  @else
    println("✗ Combination 15 (State Machine & Event Queue) FAILED")
    return 1
  @end
@end
