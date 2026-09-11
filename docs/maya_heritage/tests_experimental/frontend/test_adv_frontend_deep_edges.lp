@! ============================================================================
@! ADVERSARIAL CHALLENGER DEEP EDGES SUITE (MILESTONE M2 ITERATION 2)
@! Focus Areas:
@! 1. Hexadecimal & Binary integer literals in expressions & enums
@! 2. Multiple @impl blocks on the same struct
@! 3. Forward struct references in mutual recursive layouts
@! 4. Complex precedence chains & unary compositions (!, -, ~, &)
@! 5. Pipe operator |> chains
@! 6. Deeply nested while loops (5 levels) with break & continue validation
@! ============================================================================

import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "universe/core/string"

@fn assert_true(cond, test_name)
  @if cond == 1
    println("[PASS] " + test_name)
    return 1
  @else
    println("[FAIL] " + test_name)
    return 0
  @end
@end

@fn assert_eq_i64(actual, expected, test_name)
  @if actual == expected
    println("[PASS] " + test_name + " -> got " + int_to_str(actual))
    return 1
  @else
    println("[FAIL] " + test_name + " -> expected " + int_to_str(expected) + ", got " + int_to_str(actual))
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, test_name)
  @if actual == expected
    println("[PASS] " + test_name + " -> got \"" + actual + "\"")
    return 1
  @else
    println("[FAIL] " + test_name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("⚡ ADVERSARIAL FRONTEND DEEP EDGES SUITE (M2 ITERATION 2) ⚡")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! ---------------------------------------------------------------------------
  @! TEST 1: HEX & BINARY CONSTANTS IN ENUMS
  @! ---------------------------------------------------------------------------
  println("\n--- [1] Hex and Binary Enum Discriminants ---")
  src_hex_bin = "
  @enum Permissions
    NONE = 0
    EXEC = 0x01
    WRITE = 0x02
    READ = 0x04
    ALL = 0x07
  @end

  @enum Masks
    BIT0 = 0b0001
    BIT1 = 0b0010
    BIT2 = 0b0100
    BIT3 = 0b1000
  @end
  "
  prog_hex = parse_source_program(src_hex_bin)
  env_hex = typecheck_program_ast(prog_hex)
  @if assert_eq_i64(env_hex.errors.len(), 0, "Hex and Binary enums parse and typecheck without errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_hex, "Permissions_EXEC"), 1, "Permissions_EXEC is 1 (0x01)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_hex, "Permissions_ALL"), 7, "Permissions_ALL is 7 (0x07)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_hex, "Masks_BIT3"), 8, "Masks_BIT3 is 8 (0b1000)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST 2: MULTIPLE @impl BLOCKS FOR SAME STRUCT
  @! ---------------------------------------------------------------------------
  println("\n--- [2] Multiple @impl Blocks On Same Struct ---")
  src_multi_impl = "
  @struct Player
    id: i64
    score: i64
  @end

  @impl Player
    @fn get_id(self) -> i64
      @return self.id
    @end
  @end

  @impl Player
    @fn get_score(self) -> i64
      @return self.score
    @end
    @fn add_score(self, pts: i64) -> void
      self.score = self.score + pts
    @end
  @end
  "
  prog_impl = parse_source_program(src_multi_impl)
  env_impl = typecheck_program_ast(prog_impl)
  @if assert_eq_i64(env_impl.errors.len(), 0, "Multiple @impl blocks for Player parse with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  
  st_player = tc_get_struct(env_impl, "Player")
  @if assert_eq_i64(st_player.methods.len(), 3, "Player struct has all 3 methods registered across both @impl blocks") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(st_player.methods[0], "Player_get_id", "Method 0 is Player_get_id") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(st_player.methods[1], "Player_get_score", "Method 1 is Player_get_score") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(st_player.methods[2], "Player_add_score", "Method 2 is Player_add_score") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST 3: MUTUAL FORWARD REFERENCES IN STRUCTS
  @! ---------------------------------------------------------------------------
  println("\n--- [3] Mutual Forward References in Structs ---")
  src_mutual = "
  @struct Alpha
    id: i64
    partner: Beta
  @end

  @struct Beta
    code: string
    peer: Gamma
  @end

  @struct Gamma
    flag: bool
    ref_alpha: Alpha
  @end
  "
  prog_mutual = parse_source_program(src_mutual)
  env_mutual = typecheck_program_ast(prog_mutual)
  @if assert_eq_i64(env_mutual.errors.len(), 0, "Mutual 3-struct forward chain typechecks with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  
  st_alpha = tc_get_struct(env_mutual, "Alpha")
  st_beta = tc_get_struct(env_mutual, "Beta")
  st_gamma = tc_get_struct(env_mutual, "Gamma")
  f_partner = tc_struct_get_field(st_alpha, "partner")
  f_peer = tc_struct_get_field(st_beta, "peer")
  f_ref_alpha = tc_struct_get_field(st_gamma, "ref_alpha")

  @if assert_eq_str(type_to_string(tc_field_get_type(f_partner)), "Beta", "Alpha.partner resolved to Beta") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f_peer)), "Gamma", "Beta.peer resolved to Gamma") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f_ref_alpha)), "Alpha", "Gamma.ref_alpha resolved to Alpha") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST 4: COMPLEX OPERATOR PRECEDENCE & PIPE PIPELINE
  @! ---------------------------------------------------------------------------
  println("\n--- [4] Complex Expressions & Pipe Pipeline ---")
  src_pipe_prec = "
  @fn double_it(x: i64) -> i64
    @return x * 2
  @end

  @fn add_ten(x: i64) -> i64
    @return x + 10
  @end

  @fn format_num(x: i64) -> string
    @return \"num: \" + int_to_str(x)
  @end

  @fn pipeline_test(v: i64) -> string
    res = v + 5 * 2 |> double_it |> add_ten |> format_num
    @return res
  @end
  "
  prog_pipe = parse_source_program(src_pipe_prec)
  env_pipe = typecheck_program_ast(prog_pipe)
  @if assert_eq_i64(env_pipe.errors.len(), 0, "Pipe expressions typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST 5: DEEPLY NESTED WHILE LOOPS WITH BREAK/CONTINUE
  @! ---------------------------------------------------------------------------
  println("\n--- [5] Deeply Nested Loops with Control Statements ---")
  src_deep_loops = "
  @fn deep_search(matrix: array, target: i64) -> i64
    found = 0
    i = 0
    @while i < 10
      j = 0
      @while j < 10
        k = 0
        @while k < 10
          @if i * 100 + j * 10 + k == target
            found = 1
            @break
          @end
          k = k + 1
        @end
        @if found == 1
          @break
        @end
        j = j + 1
      @end
      @if found == 1
        @break
      @end
      i = i + 1
    @end
    @return found
  @end
  "
  prog_loops = parse_source_program(src_deep_loops)
  env_loops = typecheck_program_ast(prog_loops)
  @if assert_eq_i64(env_loops.errors.len(), 0, "3-level nested while loops with internal @break typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! SUMMARY
  @! ---------------------------------------------------------------------------
  println("\n=================================================================")
  println("📊 DEEP EDGES SUITE SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("🏆 ALL DEEP EDGE TESTS PASSED (100% SUCCESS)!")
    return 0
  @else
    println("❌ FAILURES DETECTED!")
    return 1
  @end
@end
