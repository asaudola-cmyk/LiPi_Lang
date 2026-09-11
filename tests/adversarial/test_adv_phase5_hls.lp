@! ============================================================================
@! ADVERSARIAL STRESS TEST: Dynamic HLS Lowering & Synthesis (Challenger 1)
@! File: tests/adversarial/test_adv_phase5_hls.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "compiler/frontend/ast"
import "compiler/backend/hdl/hls"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  ❌ [ADV FAIL] " + msg)
    return 0
  @end
  println("  ✓ [ADV PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 [CHALLENGE 1: Dynamic HLS Lowering, Complex AST & FSM Synthesis] 🔥")
  println("=================================================================")

  total_asserts = 0
  passed_asserts = 0

  @! 1.1 Deeply Nested AST Expressions (unary, binary, logical, bitwise)
  expr_complex = ast_binary_op(
    ast_binary_op(
      ast_binary_op(ast_variable("x"), "&", ast_variable("mask")),
      "|",
      ast_binary_op(ast_variable("y"), "^", ast_literal_int(255))
    ),
    "+",
    ast_binary_op(ast_unary_op("~", ast_variable("z")), ">>", ast_literal_int(4))
  )
  v_expr = hls_lower_ast_expr(expr_complex)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_expr, "(((x & mask) | (y ^ 64'd255)) + ((~z) >> 64'd4))"),
    "HLS lowers complex nested bitwise/arithmetic AST expression"
  )

  @! 1.2 Unary Logical Not, Negation, Comparisons, Array Index & Builtin Functions
  u_not = ast_unary_op("!", ast_binary_op(ast_variable("flag"), "==", ast_literal_bool(1)))
  v_not = hls_lower_ast_expr(u_not)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_not, "(!(flag == 1'b1))"),
    "HLS lowers unary logical NOT and boolean literal"
  )

  call_abs = ast_call(ast_variable("abs"), [ast_variable("diff")])
  v_abs = hls_lower_ast_expr(call_abs)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_abs, "(diff < 0 ? -diff : diff)"),
    "HLS lowers abs() function call to ternary hardware expression"
  )

  call_min = ast_call(ast_variable("min"), [ast_variable("val_a"), ast_variable("val_b")])
  v_min = hls_lower_ast_expr(call_min)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_min, "(val_a < val_b ? val_a : val_b)"),
    "HLS lowers min(a, b) function call to hardware comparator"
  )

  idx_expr = ast_index(ast_variable("coeffs"), ast_variable("idx"))
  v_idx = hls_lower_ast_expr(idx_expr)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_idx, "coeffs[idx]"),
    "HLS lowers array indexing expression"
  )

  @! 1.3 FSM State Bit Width Calculation Stress
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(1), 1, "1 state -> 1 bit")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(2), 1, "2 states -> 1 bit")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(3), 2, "3 states -> 2 bits")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(4), 2, "4 states -> 2 bits")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(7), 3, "7 states -> 3 bits")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(16), 4, "16 states -> 4 bits")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(32), 5, "32 states -> 5 bits")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(hls_calc_state_bits(33), 6, "33 states -> 6 bits")

  @! 1.4 Dynamic Multi-Branch FSM Synthesis (9 States, Conditional & Else branches)
  hls_fsm9 = hls_module_new("matrix_accel_fsm")
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 0, "ST_IDLE", "ready <= 1'b1;", "start_cmd", 1, 0)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 1, "ST_LOAD_A", "a_req <= 1'b1;", "a_ack", 2, 1)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 2, "ST_LOAD_B", "b_req <= 1'b1;", "b_ack", 3, 2)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 3, "ST_MAC1", "acc <= acc + (a0 * b0);", "1'b1", 4, 4)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 4, "ST_MAC2", "acc <= acc + (a1 * b1);", "1'b1", 5, 5)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 5, "ST_MAC3", "acc <= acc + (a2 * b2);", "1'b1", 6, 6)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 6, "ST_STORE", "out_vld <= 1'b1;", "out_ack", 7, 6)
  hls_fsm9 = hls_add_fsm_state_branch(hls_fsm9, 7, "ST_CHECK_NEXT", "", "row_idx < row_max", 1, 8)
  hls_fsm9 = hls_add_fsm_state(hls_fsm9, 8, "ST_DONE", "done <= 1'b1;", "!start_cmd", 0)

  v_fsm9 = hls_render_axi4_module(hls_fsm9)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_fsm9, "localparam ST_DONE = 4'd8;"),
    "9-state FSM uses 4-bit state encoding (localparam ST_DONE = 4'd8)"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_fsm9, "reg [3:0] current_state, next_state;"),
    "9-state FSM declares reg [3:0] current_state"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_fsm9, "if (row_idx < row_max) current_state <= ST_LOAD_A;\n          else current_state <= ST_DONE;"),
    "FSM branch with else generates proper if-else state transitions"
  )

  @! 1.5 Dynamic 8-Stage Deep Pipeline with Custom Bit Widths
  hls_pipe8 = hls_module_new("crypto_hash_pipeline")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 1, "st1_expand", "s_axi_wdata ^ 32'h5A5A5A5A", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 2, "st2_rot", "(st1_expand << 5) | (st1_expand >> 27)", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 3, "st3_add", "st2_rot + 32'd12345", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 4, "st4_mix", "st3_add ^ 32'hDEADBEEF", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 5, "st5_sbox", "st4_mix * 32'd7", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 6, "st6_perm", "(st5_sbox << 13) | (st5_sbox >> 19)", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 7, "st7_xor", "st6_perm ^ 32'hA5A5A5A5", 32, "")
  hls_pipe8 = hls_add_pipeline_stage_detailed(hls_pipe8, 8, "st8_final", "st7_xor + 32'd9999", 64, "")

  v_pipe8 = hls_render_axi4_module(hls_pipe8)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_pipe8, "reg [31:0] st1_expand;"),
    "32-bit pipeline stage declared correctly"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_pipe8, "reg [63:0] st8_final;"),
    "64-bit pipeline stage declared correctly"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_pipe8, "st8_final   <= 64'd0;"),
    "Pipeline sequential reset correctly formatted"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_pipe8, "dsp_result <= st8_final;"),
    "dsp_result bound to last pipeline stage st8_final"
  )

  @! 1.6 WhileLoop Statement AST Lowering to Synthesizable FSM
  stmt_while = ast_while_loop(
    ast_binary_op(ast_variable("loop_idx"), "<", ast_variable("loop_limit")),
    [
      ast_assign("accum", ast_binary_op(ast_variable("accum"), "+", ast_variable("data_in"))),
      ast_assign_op("counter", ast_literal_int(1), "+")
    ]
  )
  hls_while = hls_module_new("loop_accumulator")
  hls_while = hls_lower_ast_stmt(hls_while, stmt_while)
  v_while = hls_render_axi4_module(hls_while)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_while, "localparam STATE_BODY = 2'd2;"),
    "WhileLoop AST lowered to 4-state FSM"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(v_while, "accum <= (accum + data_in); counter <= counter + 64'd1;"),
    "WhileLoop body actions lowered to non-blocking Verilog assignments"
  )

  println("\n=================================================================")
  println("📊 HLS RESULTS: " + passed_asserts.to_str() + " / " + total_asserts.to_str() + " assertions passed")
  println("=================================================================")
  @if passed_asserts == total_asserts
    return 0
  @else
    return 1
  @end
@end
