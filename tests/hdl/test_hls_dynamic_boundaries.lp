@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — HLS DYNAMIC BOUNDARIES & STRESS TEST SUITE
@! File: tests/hdl/test_hls_dynamic_boundaries.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 2
@! TAGS: hdl, hls, boundaries, verilog
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/frontend/ast"
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
  println("⚡ MAYA HLS DYNAMIC BOUNDARIES & CORNER CASES TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: 1-Stage Direct Pass-Through Pipeline (Minimal Latency Boundary)
  println("▶ Test 1: 1-Stage Direct Pass-Through Pipeline...")
  total_tests = total_tests + 1
  hls1 = hls_module_new("maya_pass_through")
  hls1 = hls_add_pipeline_stage_detailed(hls1, 1, "direct_stage", "s_axi_wdata", 64, "")
  
  v1 = hls_render_axi4_module(hls1)
  ok1_1 = assert_true(contains(v1, "reg [63:0] direct_stage;"), "direct_stage register declared")
  ok1_2 = assert_true(contains(v1, "dsp_result <= direct_stage;"), "Single stage connected directly to dsp_result")
  ok1_3 = assert_true(!contains(v1, "pipe_stage2"), "No spurious extra stages present")
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: 1-Stage direct pass-through boundary verified")
  @end

  @! TEST 2: 8-Stage Deep DSP Pipeline (Maximum Latency Forwarding)
  println("▶ Test 2: 8-Stage Deep DSP Pipeline Synthesis...")
  total_tests = total_tests + 1
  hls2 = hls_module_new("maya_deep_dsp")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 1, "p_stage1", "s_axi_wdata * 32'd2", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 2, "p_stage2", "p_stage1 + 64'd10", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 3, "p_stage3", "p_stage2 << 2", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 4, "p_stage4", "p_stage3 ^ 64'h5555", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 5, "p_stage5", "p_stage4 - 64'd1", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 6, "p_stage6", "p_stage5 | 64'h0F0F", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 7, "p_stage7", "p_stage6 >> 1", 64, "")
  hls2 = hls_add_pipeline_stage_detailed(hls2, 8, "p_stage8", "p_stage7 + 64'd1000", 64, "")

  v2 = hls_render_axi4_module(hls2)
  ok2_1 = assert_eq_int(hls2.pipeline_stages.len(), 8, "8 pipeline stages configured")
  ok2_2 = assert_true(contains(v2, "reg [63:0] p_stage8;"), "p_stage8 register declared")
  ok2_3 = assert_true(contains(v2, "p_stage8 <= p_stage7 + 64'd1000;"), "Sequential forwarding to stage 8 emitted")
  ok2_4 = assert_true(contains(v2, "dsp_result <= p_stage8;"), "Final dsp_result driven by stage 8")
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: 8-Stage deep DSP pipeline verified")
  @end

  @! TEST 3: Parameterizable Bitwidths (32-bit, 128-bit, 256-bit Data Paths)
  println("▶ Test 3: Parameterizable Bitwidth Pipelines (32-bit & 256-bit)...")
  total_tests = total_tests + 1
  hls3 = hls_module_new("maya_wide_bus")
  hls3 = hls_add_pipeline_stage_detailed(hls3, 1, "narrow_stage", "s_axi_wdata[31:0]", 32, "")
  hls3 = hls_add_pipeline_stage_detailed(hls3, 2, "wide_stage", "{8{narrow_stage}}", 256, "")

  v3 = hls_render_axi4_module(hls3)
  ok3_1 = assert_true(contains(v3, "reg [31:0] narrow_stage;"), "32-bit register width [31:0] emitted")
  ok3_2 = assert_true(contains(v3, "reg [255:0] wide_stage;"), "256-bit register width [255:0] emitted")
  ok3_3 = assert_true(contains(v3, "narrow_stage   <= 32'd0;"), "Reset logic for 32-bit register emitted")
  ok3_4 = assert_true(contains(v3, "wide_stage   <= 256'd0;"), "Reset logic for 256-bit register emitted")
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Parameterizable bitwidth synthesis verified")
  @end

  @! TEST 4: Large Multi-State FSM (16-State & 32-State Encoding Bounds)
  println("▶ Test 4: Large 16-State & 32-State FSM Synthesis & Bit Allocation...")
  total_tests = total_tests + 1
  hls4 = hls_module_new("maya_large_fsm")
  s_idx = 0
  @while s_idx < 16
    st_name = "ST_PHASE_" + s_idx.to_str()
    next_s = (s_idx + 1) % 16
    hls4 = hls_add_fsm_state(hls4, s_idx, st_name, "cycle_counter <= cycle_counter + 1;", "step_en", next_s)
    s_idx = s_idx + 1
  @end

  b16 = hls_calc_state_bits(16)
  ok4_b16 = assert_eq_int(b16, 4, "16 states require 4 state bits (2^4 = 16)")
  b32 = hls_calc_state_bits(32)
  ok4_b32 = assert_eq_int(b32, 5, "32 states require 5 state bits (2^5 = 32)")
  b64 = hls_calc_state_bits(64)
  ok4_b64 = assert_eq_int(b64, 6, "64 states require 6 state bits (2^6 = 64)")

  v4 = hls_render_axi4_module(hls4)
  ok4_1 = assert_true(contains(v4, "localparam ST_PHASE_0 = 4'd0;"), "ST_PHASE_0 encoded as 4'd0")
  ok4_2 = assert_true(contains(v4, "localparam ST_PHASE_15 = 4'd15;"), "ST_PHASE_15 encoded as 4'd15")
  ok4_3 = assert_true(contains(v4, "reg [3:0] current_state, next_state;"), "reg [3:0] state register allocated")
  ok4_4 = assert_true(contains(v4, "default: current_state <= ST_PHASE_0;"), "Default reset transition to state 0 emitted")
  @if ok4_b16 == 1 && ok4_b32 == 1 && ok4_b64 == 1 && ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: Large multi-state FSM state synthesis verified")
  @end

  @! TEST 5: Dynamic AST Expression & Builtin Lowering
  println("▶ Test 5: Dynamic AST Expression Lowering to Hardware Verilog...")
  total_tests = total_tests + 1
  
  @! Binary arithmetic and bitwise ops
  ast_add = ast_binary_op(ast_literal_int(42), "+", ast_variable("x"))
  v_add = hls_lower_ast_expr(ast_add)
  ok5_1 = assert_true(contains(v_add, "(64'd42 + x)"), "Binary add lowered to Verilog")

  @! Relational and logical ops
  cmp_l = ast_binary_op(ast_variable("a"), "<=", ast_literal_int(100))
  cmp_r = ast_binary_op(ast_variable("b"), "!=", ast_literal_int(0))
  ast_cmp = ast_binary_op(cmp_l, "&&", cmp_r)
  v_cmp = hls_lower_ast_expr(ast_cmp)
  ok5_2 = assert_true(contains(v_cmp, "<=") && contains(v_cmp, "!="), "Relational comparison lowered to Verilog")

  @! Unary ops
  ast_not = ast_unary_op("!", ast_variable("flag"))
  v_not = hls_lower_ast_expr(ast_not)
  ok5_3 = assert_true(contains(v_not, "(!flag)"), "Unary NOT lowered to Verilog")

  @! Builtin function calls (abs, min, max)
  ast_abs = ast_call(ast_variable("abs"), [ast_variable("delta")])
  v_abs = hls_lower_ast_expr(ast_abs)
  ok5_4 = assert_true(contains(v_abs, "delta < 0 ? -delta : delta"), "abs() call lowered to ternary operator")

  ast_max = ast_call(ast_variable("max"), [ast_variable("val1"), ast_variable("val2")])
  v_max = hls_lower_ast_expr(ast_max)
  ok5_5 = assert_true(contains(v_max, "val1 > val2 ? val1 : val2"), "max() call lowered to ternary operator")

  @if ok5_1 == 1 && ok5_2 == 1 && ok5_3 == 1 && ok5_4 == 1 && ok5_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: Dynamic AST expression lowering verified")
  @end

  println("=================================================================")
  println("📊 HLS BOUNDARIES TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 HLS BOUNDARIES TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME HLS BOUNDARIES TESTS FAILED")
    return 1
  @end
@end
