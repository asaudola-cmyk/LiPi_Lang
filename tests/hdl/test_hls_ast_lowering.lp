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

@fn main()
  println("=================================================================")
  println("⚡ MAYA DYNAMIC AST-TO-VERILOG HLS COMPILER LOWERING TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Dynamic AST Expression Lowering
  println("▶ Section 1: Dynamic AST Expression to Verilog Lowering...")
  total_tests = total_tests + 1
  expr1 = ast_binary_op(ast_variable("a"), "+", ast_binary_op(ast_variable("b"), "*", ast_literal_int(42)))
  v_str1 = hls_lower_ast_expr(expr1)
  ok1 = assert_true(contains(v_str1, "(a + (b * 64'd42))"), "Arithmetic AST lowered to Verilog")

  @! SECTION 2: Dynamic 5-State FSM Synthesis
  println("▶ Section 2: Arbitrary 5-State FSM Synthesis & Bit-Width Calculation...")
  total_tests = total_tests + 1
  hls_fsm = hls_module_new("custom_controller")
  hls_fsm = hls_add_fsm_state(hls_fsm, 0, "ST_IDLE", "ready <= 1'b1;", "start", 1)
  hls_fsm = hls_add_fsm_state(hls_fsm, 1, "ST_FETCH", "addr <= addr + 1;", "mem_ok", 2)
  hls_fsm = hls_add_fsm_state(hls_fsm, 2, "ST_EXEC", "acc <= acc ^ data;", "1'b1", 3)
  hls_fsm = hls_add_fsm_state(hls_fsm, 3, "ST_WRITE", "we <= 1'b1;", "ack", 4)
  hls_fsm = hls_add_fsm_state(hls_fsm, 4, "ST_FINISH", "done <= 1'b1;", "!start", 0)

  v_fsm = hls_render_axi4_module(hls_fsm)
  ok2 = assert_true(contains(v_fsm, "localparam ST_FINISH = 3'd4;"), "5-state FSM uses 3-bit state encoding")
  ok3 = assert_true(contains(v_fsm, "reg [2:0] current_state"), "State registers declare [2:0]")
  ok4 = assert_true(contains(v_fsm, "case (current_state)"), "Synthesizable case statement generated")

  @! SECTION 3: Dynamic Custom 4-Stage Pipeline
  println("▶ Section 3: Dynamic 4-Stage DSP Pipelining...")
  total_tests = total_tests + 1
  hls_pipe = hls_module_new("fir_filter")
  hls_pipe = hls_add_pipeline_stage(hls_pipe, 1, "stage_coeff", "s_axi_wdata * 32'd13")
  hls_pipe = hls_add_pipeline_stage(hls_pipe, 2, "stage_accum", "stage_coeff + 64'd1024")
  hls_pipe = hls_add_pipeline_stage(hls_pipe, 3, "stage_round", "stage_accum >> 4")
  hls_pipe = hls_add_pipeline_stage(hls_pipe, 4, "stage_saturate", "stage_round ^ 64'hFFFF")

  v_pipe = hls_render_axi4_module(hls_pipe)
  ok5 = assert_true(contains(v_pipe, "reg [63:0] stage_coeff;"), "stage_coeff declared")
  ok6 = assert_true(contains(v_pipe, "stage_accum <= stage_coeff + 64'd1024;"), "stage_accum assignment generated")
  ok7 = assert_true(contains(v_pipe, "dsp_result <= stage_saturate;"), "Final output connected to stage_saturate")

  @! SECTION 4: AXI-Stream High-Throughput Streaming Wrapper
  println("▶ Section 4: AXI4-Stream Backpressure & Handshake Pipeline...")
  total_tests = total_tests + 1
  v_axis = hls_render_axis_module(hls_pipe)
  ok8 = assert_true(contains(v_axis, "assign s_axis_tready = pipe_enable;"), "Backpressure ready signal generated")
  ok9 = assert_true(contains(v_axis, "m_axis_tvalid"), "Master stream valid output present")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    println("🎉 ALL DYNAMIC AST-TO-VERILOG HLS TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME HLS TESTS FAILED")
    return 1
  @end
@end
