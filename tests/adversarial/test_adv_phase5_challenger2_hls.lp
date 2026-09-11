@! ============================================================================
@! ADVERSARIAL TEST SUITE — PHASE 5: HLS & VERILOG GENERATION (CHALLENGER 2)
@! Module: tests/adversarial/test_adv_phase5_challenger2_hls.maya
@! Stress-testing dynamic AST lowering, FSM state calculations, AXI4 memory-mapped
@! rendering, and AXI4-Stream backpressure logic.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/frontend/ast"
import "compiler/backend/hdl/hls"
import "compiler/backend/hdl/verilog"

@fn assert_true(cond, msg)
  @if cond != 1
    println("  [FAIL] Assertion failed: " + msg)
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_str(got, exp, msg)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: '" + got + "', Expected: '" + exp + "')")
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_int(got, exp, msg)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: " + got.to_str() + ", Expected: " + exp.to_str() + ")")
    exit(1)
  @else
    println("  [PASS] " + msg + " == " + exp.to_str())
  @end
@end

@fn assert_contains(haystack, needle, msg)
  @if string_contains(haystack, needle) != 1
    println("  [FAIL] String does not contain needle: '" + needle + "' - " + msg)
    exit(1)
  @else
    println("  [PASS] Contains '" + needle + "' (" + msg + ")")
  @end
@end
