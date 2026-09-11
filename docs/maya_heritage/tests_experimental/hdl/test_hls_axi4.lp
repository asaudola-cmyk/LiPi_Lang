@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ADVANCED HLS & AXI4 TEST SUITE
@! File: tests/hdl/test_hls_axi4.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 1
@! TAGS: hdl, hls, axi4, verilog
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/hdl/hls"

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
  println("⚡ MAYA ADVANCED HLS, FSM & AXI4 SILICON COMPILER TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: Automatic Loop-to-FSM State Machine Synthesis
  println("▶ Test 1: While-Loop to Hardware FSM State Synthesis...")
  total_tests = total_tests + 1
  hls1 = hls_module_new("maya_dsp_loop")
  hls1 = hls_synthesize_while_loop_fsm(hls1, "idx", "16", "acc <= acc + buffer[idx]")
  
  ok1 = assert_eq_int(hls1.states.len(), 4, "Synthesized 4 FSM hardware states (IDLE, CHECK, BODY, DONE)")
  st0 = hls1.states[0]
  ok2 = assert_true(contains(st0.state_name, "STATE_IDLE"), "State 0 is STATE_IDLE")
  st1 = hls1.states[1]
  ok3 = assert_true(contains(st1.next_state_cond, "idx < 16"), "State 1 condition checks idx < 16")
  st2 = hls1.states[2]
  ok4 = assert_true(contains(st2.action_code, "acc <= acc + buffer[idx]"), "State 2 executes loop accumulation")
  st3 = hls1.states[3]
  ok5 = assert_true(contains(st3.action_code, "done <= 1'b1;"), "State 3 asserts done signal")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: While-loop to hardware FSM synthesis verified")
  @end

  @! TEST 2: Dynamic Custom Multi-State FSM Synthesis
  println("▶ Test 2: Custom Multi-State FSM Synthesis & State Bit Calculation...")
  total_tests = total_tests + 1
  hls2 = hls_module_new("maya_custom_fsm")
  hls2 = hls_add_fsm_state(hls2, 0, "FSM_INIT", "ready <= 1'b0;", "start_pulse", 1)
  hls2 = hls_add_fsm_state(hls2, 1, "FSM_FETCH", "data_reg <= mem_in;", "valid_in", 2)
  hls2 = hls_add_fsm_state_branch(hls2, 2, "FSM_BRANCH", "", "data_reg > 64'd100", 3, 4)
  hls2 = hls_add_fsm_state(hls2, 3, "FSM_FAST_PATH", "out_val <= data_reg << 2;", "1'b1", 5)
  hls2 = hls_add_fsm_state(hls2, 4, "FSM_SLOW_PATH", "out_val <= data_reg * 64'd7;", "1'b1", 5)
  hls2 = hls_add_fsm_state(hls2, 5, "FSM_ACK", "ready <= 1'b1; done <= 1'b1;", "!start_pulse", 0)

  s_bits = hls_calc_state_bits(hls2.states.len())
  ok_sbits = assert_eq_int(s_bits, 3, "6 states encoded in 3 bits (2^3 = 8 >= 6)")
  v_code2 = hls_render_axi4_module(hls2)
  ok_init = assert_true(contains(v_code2, "localparam FSM_INIT = 3'd0;"), "FSM_INIT localparam emitted")
  ok_branch = assert_true(contains(v_code2, "if (data_reg > 64'd100) current_state <= FSM_FAST_PATH;"), "Branch condition emitted")
  ok_else = assert_true(contains(v_code2, "else current_state <= FSM_SLOW_PATH;"), "Else state branch emitted")
  @if ok_sbits == 1 && ok_init == 1 && ok_branch == 1 && ok_else == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Custom multi-state FSM synthesis verified")
  @end

  @! TEST 3: Dynamic Multi-Stage DSP Pipeline & Register Generation
  println("▶ Test 3: Dynamic 4-Stage DSP Pipeline Synthesis...")
  total_tests = total_tests + 1
  hls3 = hls_module_new("maya_fir_dsp")
  hls3 = hls_add_pipeline_stage_detailed(hls3, 1, "coeff_mul", "s_axi_wdata * 32'd13", 64, "")
  hls3 = hls_add_pipeline_stage_detailed(hls3, 2, "accum_stage", "coeff_mul + prev_accum", 64, "")
  hls3 = hls_add_pipeline_stage_detailed(hls3, 3, "rounding_stage", "accum_stage + 64'd4", 64, "")
  hls3 = hls_add_pipeline_stage_detailed(hls3, 4, "sat_output", "rounding_stage >> 3", 64, "")
  
  v_code3 = hls_render_axi4_module(hls3)
  ok_reg1 = assert_true(contains(v_code3, "reg [63:0] coeff_mul;"), "coeff_mul register declared")
  ok_reg2 = assert_true(contains(v_code3, "reg [63:0] sat_output;"), "sat_output register declared")
  ok_assign = assert_true(contains(v_code3, "coeff_mul <= s_axi_wdata * 32'd13;"), "Stage 1 computation assigned")
  ok_res = assert_true(contains(v_code3, "dsp_result <= sat_output;"), "Final stage assigned to dsp_result")
  @if ok_reg1 == 1 && ok_reg2 == 1 && ok_assign == 1 && ok_res == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Dynamic 4-stage DSP pipeline verified")
  @end

  @! TEST 4: AXI4 Slave Protocol Compliance & Reset Architecture
  println("▶ Test 4: AXI4 Slave Protocol Handshake & Asynchronous Reset...")
  total_tests = total_tests + 1
  v_code4 = hls_render_axi4_module(hls3)
  
  ok_clk = assert_true(contains(v_code4, "input  wire        s_axi_aclk"), "AXI clock port present")
  ok_rstn = assert_true(contains(v_code4, "input  wire        s_axi_aresetn"), "AXI active-low reset port present")
  ok_aw = assert_true(contains(v_code4, "s_axi_awready <= s_axi_awvalid;"), "AW ready handshake logic present")
  ok_w = assert_true(contains(v_code4, "s_axi_wready  <= s_axi_wvalid;"), "W ready handshake logic present")
  ok_b = assert_true(contains(v_code4, "s_axi_bvalid  <= s_axi_wvalid && s_axi_wready;"), "B valid handshake logic present")
  ok_rst_blk = assert_true(contains(v_code4, "if (!s_axi_aresetn) begin"), "Active-low reset branch present")
  @if ok_clk == 1 && ok_rstn == 1 && ok_aw == 1 && ok_w == 1 && ok_b == 1 && ok_rst_blk == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: AXI4 slave protocol & reset architecture verified")
  @end

  @! TEST 5: High-Throughput AXI4-Stream (AXIS) Streaming Engine
  println("▶ Test 5: AXI4-Stream (AXIS) Pipelined Streaming Interface...")
  total_tests = total_tests + 1
  hls5 = hls_module_new("maya_streaming_accel")
  hls5.data_width = 128
  hls5 = hls_add_pipeline_stage_detailed(hls5, 1, "st_stage1", "s_axis_tdata ^ 128'hFFFF", 128, "")
  hls5 = hls_add_pipeline_stage_detailed(hls5, 2, "st_stage2", "st_stage1 + 128'd1024", 128, "")
  
  v_axis = hls_render_axis_module(hls5)
  ok_ax_w = assert_true(contains(v_axis, "[127:0] s_axis_tdata"), "128-bit streaming input width synthesized")
  ok_ax_out = assert_true(contains(v_axis, "[127:0] m_axis_tdata"), "128-bit streaming output width synthesized")
  ok_ax_bp = assert_true(contains(v_axis, "assign s_axis_tready = pipe_enable;"), "Backpressure propagation assigned")
  ok_ax_vld = assert_true(contains(v_axis, "st_stage1_vld <= s_axis_tvalid;"), "Stage valid propagation synthesized")
  @if ok_ax_w == 1 && ok_ax_out == 1 && ok_ax_bp == 1 && ok_ax_vld == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: AXI4-Stream streaming engine verified")
  @end

  println("=================================================================")
  println("📊 ADVANCED HLS TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 ADVANCED HLS & AXI4 TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ADVANCED HLS TESTS FAILED")
    return 1
  @end
@end
