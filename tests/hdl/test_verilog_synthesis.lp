@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — VERILOG HDL SYNTHESIS TEST SUITE
@! File: tests/hdl/test_verilog_synthesis.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/hdl/verilog"

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

@fn main()
  println("=================================================================")
  println("⚡ MAYA HARDWARE SYNTHESIS & VERILOG HDL EMITTER TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Combinational Logic ALU Module Synthesis
  println("▶ Section 1: Combinational 64-Bit Arithmetic Logic Unit (ALU)...")
  total_tests = total_tests + 1
  alu = verilog_module_new("maya_alu64")
  alu = verilog_add_port(alu, "a", "input", "wire", 64)
  alu = verilog_add_port(alu, "b", "input", "wire", 64)
  alu = verilog_add_port(alu, "sum", "output", "wire", 64)
  alu = verilog_add_assign(alu, "sum", "a + b")

  v_src = verilog_render_module(alu)
  ok1 = assert_true(contains(v_src, "module maya_alu64"), "Module header rendered accurately")
  ok2 = assert_true(contains(v_src, "input wire [63:0] a"), "64-Bit input bus port defined")
  ok3 = assert_true(contains(v_src, "assign sum = a + b;"), "Continuous assignment synthesized")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Combinational ALU Verilog synthesis verified")
  @end

  @! SECTION 2: Sequential Clocked Register & State Machine Synthesis
  println("▶ Section 2: Sequential Clocked Flip-Flop & Counter Synthesis...")
  total_tests = total_tests + 1
  counter = verilog_module_new("maya_counter64")
  counter = verilog_add_port(counter, "clk", "input", "wire", 1)
  counter = verilog_add_port(counter, "rst", "input", "wire", 1)
  counter = verilog_add_port(counter, "count", "output", "reg", 64)
  counter = verilog_add_always_ff(counter, "clk", "rst", "count", "count + 64'd1", 0)

  v_counter = verilog_render_module(counter)
  ok1 = assert_true(contains(v_counter, "always @(posedge clk or posedge rst)"), "Pos-edge clock and reset sensitivity list generated")
  ok2 = assert_true(contains(v_counter, "count <= count + 64'd1;"), "Non-blocking sequential assignment synthesized")
  ok3 = assert_true(contains(v_counter, "count <= 0;"), "Synchronous reset branch synthesized")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Sequential clocked always register synthesis verified")
  @end

  println("=================================================================")
  println("📊 VERILOG HDL TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 2 VERILOG HARDWARE SYNTHESIS TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME VERILOG SYNTHESIS TESTS FAILED")
    return 1
  @end
@end
