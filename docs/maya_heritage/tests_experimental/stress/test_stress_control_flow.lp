@! ============================================================================
@! MAYA ADVERSARIAL STRESS SUITE: INTRICATE CONTROL FLOW & MATCH
@! File: tests/stress/test_stress_control_flow.maya
@! ============================================================================

@fn deep_nested_if(a, b, c, d, e, f, g, h)
  @if a > 0
    @if b > 0
      @if c > 0
        @if d > 0
          @if e > 0
            @if f > 0
              @if g > 0
                @if h > 0
                  return 8
                @else
                  return 7
                @end
              @else
                return 6
              @end
            @else
              return 5
            @end
          @else
            return 4
          @end
        @else
          return 3
        @end
      @else
        return 2
      @end
    @else
      return 1
    @end
  @else
    return 0
  @end
@end

@fn complex_boolean_tree(x, y, z)
  @if (x > 10 && y < 20) || (z == 100 && (x < 0 || y > 50))
    @if x == 15 && y == 15
      return 1001
    @elif z == 100 && x < 0
      return 1002
    @else
      return 1003
    @end
  @elif (x == 0 || y == 0) && !(z == 0)
    return 2001
  @else
    return 3001
  @end
@end

@fn nested_match_eval(op1, op2, val)
  @match op1
    case 1:
      @match op2
        case 10:
          return val + 10
        case 20:
          return val + 20
        case _:
          return val + 1
      @end
    case 2:
      @match op2
        case 10:
          return val * 10
        case 20:
          return val * 20
        case _:
          return val * 2
      @end
    case _:
      @match op2
        case 100:
          return 9999
        case _:
          return 0
      @end
  @end
@end

@fn run_dfa_simulation(num_steps)
  state = 0
  step = 0
  checksum = 0

  @while step < num_steps
    event = step % 4
    @match state
      case 0:
        @if event == 0
          state = 1
        @elif event == 1
          state = 2
        @else
          state = 3
        @end
      case 1:
        @if event == 2
          state = 4
        @else
          state = 0
        @end
      case 2:
        @if event == 3
          state = 5
        @else
          state = 1
        @end
      case 3:
        state = 6
      case 4:
        @match event
          case 0:
            state = 7
          case 1:
            state = 8
          case _:
            state = 0
        @end
      case 5:
        state = 9
      case 6:
        state = 0
      case 7:
        state = 2
      case 8:
        state = 3
      case 9:
        state = 0
      case _:
        state = 0
    @end

    checksum = checksum + state
    step = step + 1
  @end

  return checksum
@end

@fn match_with_early_returns(tier, code)
  @match tier
    case 1:
      @if code == 100
        return 1100
      @elif code == 200
        return 1200
      @end
      return 1000
    case 2:
      @match code
        case 10:
          return 2010
        case 20:
          return 2020
        case _:
          return 2000
      @end
    case _:
      return 9999
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS TEST 4: INTRICATE CONTROL FLOW & MATCH 🔥")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Stress 4.1: 8-Level Deeply Nested @if/@else Decision Tree
  total = total + 1
  c0 = deep_nested_if(0, 1, 1, 1, 1, 1, 1, 1)
  c3 = deep_nested_if(1, 1, 1, 0, 1, 1, 1, 1)
  c7 = deep_nested_if(1, 1, 1, 1, 1, 1, 1, 0)
  c8 = deep_nested_if(1, 1, 1, 1, 1, 1, 1, 1)

  @if c0 == 0 && c3 == 3 && c7 == 7 && c8 == 8
    passed = passed + 1
    println("  [PASS] S4.1: 8-level nested @if/@else path dispatch (0, 3, 7, 8)")
  @else
    failed = failed + 1
    println("  [FAIL] S4.1: 8-level nested @if/@else path dispatch")
  @end

  @! Stress 4.2: Complex Boolean Expression Tree (@if - @elif - @else)
  total = total + 1
  b1 = complex_boolean_tree(15, 15, 0)    @! 1001
  b2 = complex_boolean_tree(-5, 60, 100)  @! 1002
  b3 = complex_boolean_tree(12, 5, 0)     @! 1003
  b4 = complex_boolean_tree(0, 10, 50)    @! 2001
  b5 = complex_boolean_tree(5, 25, 0)     @! 3001

  @if b1 == 1001 && b2 == 1002 && b3 == 1003 && b4 == 2001 && b5 == 3001
    passed = passed + 1
    println("  [PASS] S4.2: Complex boolean expressions with short-circuiting logic (1001..3001)")
  @else
    failed = failed + 1
    println("  [FAIL] S4.2: Complex boolean expressions")
  @end

  @! Stress 4.3: 2-Tier Nested Pattern Matching (@match in @match)
  total = total + 1
  m1_10 = nested_match_eval(1, 10, 5)   @! 5 + 10 = 15
  m1_20 = nested_match_eval(1, 20, 5)   @! 5 + 20 = 25
  m1_df = nested_match_eval(1, 99, 5)   @! 5 + 1 = 6
  m2_10 = nested_match_eval(2, 10, 5)   @! 5 * 10 = 50
  m2_20 = nested_match_eval(2, 20, 5)   @! 5 * 20 = 100
  m2_df = nested_match_eval(2, 99, 5)   @! 5 * 2 = 10
  m_wc1 = nested_match_eval(9, 100, 0)  @! 9999
  m_wc2 = nested_match_eval(9, 0, 0)    @! 0

  @if m1_10 == 15 && m1_20 == 25 && m1_df == 6 && m2_10 == 50 && m2_20 == 100 && m2_df == 10 && m_wc1 == 9999 && m_wc2 == 0
    passed = passed + 1
    println("  [PASS] S4.3: Multi-tier nested @match dispatch across all pattern branches")
  @else
    failed = failed + 1
    println("  [FAIL] S4.3: Multi-tier nested @match dispatch")
  @end

  @! Stress 4.4: 10-State DFA Simulation over 2,000 Transitions
  total = total + 1
  dfa_sum = run_dfa_simulation(2000)
  @if dfa_sum > 0
    passed = passed + 1
    println("  [PASS] S4.4: 10-state DFA simulation 2,000 steps executed (checksum == " + dfa_sum.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] S4.4: 10-state DFA simulation")
  @end

  @! Stress 4.5: Early Returns Across Nested @match and @if Arms
  total = total + 1
  er1 = match_with_early_returns(1, 100) @! 1100
  er2 = match_with_early_returns(1, 200) @! 1200
  er3 = match_with_early_returns(1, 999) @! 1000
  er4 = match_with_early_returns(2, 10)  @! 2010
  er5 = match_with_early_returns(2, 20)  @! 2020
  er6 = match_with_early_returns(2, 999) @! 2000
  er7 = match_with_early_returns(9, 0)   @! 9999

  @if er1 == 1100 && er2 == 1200 && er3 == 1000 && er4 == 2010 && er5 == 2020 && er6 == 2000 && er7 == 9999
    passed = passed + 1
    println("  [PASS] S4.5: Early returns inside nested match/if branches (1100..9999)")
  @else
    failed = failed + 1
    println("  [FAIL] S4.5: Early returns inside nested match/if branches")
  @end

  println("-----------------------------------------------------------------")
  println("Stress Suite 4 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ ALL CONTROL FLOW STRESS TESTS PASSED")
    return 0
  @else
    println("✗ CONTROL FLOW STRESS TESTS FAILED")
    return 1
  @end
@end
