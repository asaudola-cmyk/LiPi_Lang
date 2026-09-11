@! ============================================================================
@! ADVERSARIAL CHALLENGER STRESS SUITE: FRONTEND PIPELINE (MILESTONE M2)
@! Focus Areas:
@! 1. @if ... @elif ... @elif ... @else chains with complex expressions & returns
@! 2. Deeply nested match expressions and statements
@! 3. Enum variants with custom discriminant values (hex, sparse, sequential)
@! 4. Stress cycles, memory stability, and zero-crash verification
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
  println("🔥 ADVERSARIAL FRONTEND STRESS TEST SUITE (M2 ITERATION 2) 🔥")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! ============================================================================
  @! SECTION 1: COMPLEX @if ... @elif ... @else CHAINS
  @! ============================================================================
  println("\n--- [1] Stress-Testing @if ... @elif ... @else Chains ---")

  @! 1.1 Long chain (10 @elif branches) with arbitrary expressions and exhaustive returns
  src_long_elif = "
  @fn classify_val(x: i64, y: i64, z: i64) -> i64
    @if x > 100 && y < 50
      @return 1
    @elif x == 100 || (y == 50 && z > 0)
      @return 2
    @elif x == 90 && y == 40
      @return 3
    @elif x == 80
      @return 4
    @elif x == 70 + z
      @return 5
    @elif x == 60 * 2 - z
      @return 6
    @elif x == 50 && (y + z > 10)
      @return 7
    @elif x == 40 || y == 30 || z == 20
      @return 8
    @elif x == 30
      @return 9
    @elif x == 20
      @return 10
    @elif x == 10
      @return 11
    @else
      @return 0
    @end
  @end
  "
  prog_long = parse_source_program(src_long_elif)
  env_long = typecheck_program_ast(prog_long)
  @if assert_eq_i64(env_long.errors.len(), 0, "11-branch @if/@elif chain produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_long.warnings.len(), 0, "Exhaustive 11-branch @if/@elif produces 0 return warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.2 Missing return in middle @elif branch must produce 1 warning
  src_missing_elif_ret = "
  @fn check_missing(x: i64) -> i64
    @if x > 10
      @return 1
    @elif x == 5
      temp = x + 1
      @! No return here!
    @elif x < 0
      @return -1
    @else
      @return 0
    @end
  @end
  "
  env_miss_elif = typecheck_source(src_missing_elif_ret)
  @if assert_eq_i64(env_miss_elif.warnings.len(), 1, "Missing return in middle @elif branch triggers 1 warning") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.3 Missing return in @else branch must produce 1 warning
  src_missing_else_ret = "
  @fn check_missing_else(x: i64) -> i64
    @if x > 10
      @return 1
    @elif x == 5
      @return 2
    @else
      temp = 0
      @! Missing return
    @end
  @end
  "
  env_miss_else = typecheck_source(src_missing_else_ret)
  @if assert_eq_i64(env_miss_else.warnings.len(), 1, "Missing return in @else branch triggers 1 warning") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.4 Deeply nested @if..@elif inside @elif branch
  src_nested_elif = "
  @fn nested_eval(a: i64, b: i64) -> i64
    @if a > 100
      @return 1
    @elif a > 50
      @if b > 20
        @return 2
      @elif b > 10
        @return 3
      @else
        @return 4
      @end
    @elif a > 0
      @if b == 0
        @return 5
      @else
        @return 6
      @end
    @else
      @return 7
    @end
  @end
  "
  env_nest_elif = typecheck_source(src_nested_elif)
  @if assert_eq_i64(env_nest_elif.errors.len(), 0, "Deeply nested @if/@elif branches produce 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_nest_elif.warnings.len(), 0, "Deeply nested @if/@elif with full returns produces 0 warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.5 Variable scoping inside @elif branches: variables defined in @if or @elif do not bleed into outer scope
  src_elif_scoping = "
  @fn scope_test(x: i64) -> i64
    @if x > 10
      scoped_var_a = 100
      @return scoped_var_a
    @elif x > 5
      scoped_var_b = 200
      @return scoped_var_b
    @else
      scoped_var_c = 300
      @return scoped_var_c
    @end
  @end
  "
  env_elif_scoping = typecheck_source(src_elif_scoping)
  @if assert_eq_i64(env_elif_scoping.errors.len(), 0, "Scope isolation across @if/@elif branches produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end


  @! ============================================================================
  @! SECTION 2: DEEPLY NESTED MATCH EXPRESSIONS & STATEMENTS
  @! ============================================================================
  println("\n--- [2] Stress-Testing Match Expressions & Statements ---")

  @! 2.1 Deeply nested Match Expression (3 levels)
  src_nested_match_expr = "
  @fn eval_matrix_cell(x: i64, y: i64, z: i64) -> string
    res = match x
      case 0 => match y
        case 0 => match z
          case 0 => \"origin\"
          case 1 => \"z_unit\"
          case 2 => \"z_double\"
        @end
        case 1 => \"y_unit\"
        case 2 => \"y_double\"
      @end
      case 1 => \"x_unit\"
      case 2 => \"x_double\"
    @end
    @return res
  @end
  "
  env_nested_match = typecheck_source(src_nested_match_expr)
  @if assert_eq_i64(env_nested_match.errors.len(), 0, "3-level nested Match Expression produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_nested_match.warnings.len(), 0, "3-level nested Match Expression produces 0 warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.2 Match Statement with multiple statements per arm and internal loops
  src_match_stmt_complex = "
  @fn dispatch_command(cmd: i64, count: i64) -> i64
    total = 0
    match cmd
      case 1 =>
        i = 0
        @while i < count
          total = total + i
          i = i + 1
        @end
        @return total
      case 2 =>
        total = count * 10
        @return total
      case 3 =>
        @if count > 5
          total = 50
        @else
          total = 10
        @end
        @return total
    @end
    @return 0
  @end
  "
  env_match_stmt = typecheck_source(src_match_stmt_complex)
  @if assert_eq_i64(env_match_stmt.errors.len(), 0, "Complex Match Statement with while/if blocks produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_match_stmt.warnings.len(), 0, "Complex Match Statement produces 0 warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.3 Match with 8 arms matching various integer literals
  src_match_many_arms = "
  @fn get_name_by_id(id: i64) -> string
    name = match id
      case 100 => \"OneHundred\"
      case 200 => \"TwoHundred\"
      case 300 => \"ThreeHundred\"
      case 400 => \"FourHundred\"
      case 500 => \"FiveHundred\"
      case 600 => \"SixHundred\"
      case 700 => \"SevenHundred\"
      case 800 => \"EightHundred\"
    @end
    @return name
  @end
  "
  env_many_arms = typecheck_source(src_match_many_arms)
  @if assert_eq_i64(env_many_arms.errors.len(), 0, "8-arm Match Expression produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end


  @! ============================================================================
  @! SECTION 3: ENUM VARIANTS WITH CUSTOM DISCRIMINANT VALUES
  @! ============================================================================
  println("\n--- [3] Stress-Testing Enum Variants & Discriminants ---")

  @! 3.1 Multiple enums with hex, large values, and auto-increment
  src_enums = "
  @enum HttpStatus
    OK = 200
    CREATED = 201
    ACCEPTED = 202
    BAD_REQUEST = 400
    UNAUTHORIZED = 401
    FORBIDDEN = 403
    NOT_FOUND = 404
    SERVER_ERROR = 500
  @end

  @enum BitFlags
    NONE = 0
    READ = 1
    WRITE = 2
    EXEC = 4
    ALL = 7
  @end

  @enum SparseEnum
    ALPHA = 10
    BETA
    GAMMA
    DELTA = 100
    EPSILON
  @end
  "
  prog_enums = parse_source_program(src_enums)
  env_enums = typecheck_program_ast(prog_enums)

  @if assert_eq_i64(env_enums.errors.len(), 0, "3 distinct enums parse and typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check HttpStatus variants
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_OK"), 200, "HttpStatus_OK is 200") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_CREATED"), 201, "HttpStatus_CREATED is 201") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_NOT_FOUND"), 404, "HttpStatus_NOT_FOUND is 404") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_SERVER_ERROR"), 500, "HttpStatus_SERVER_ERROR is 500") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check BitFlags variants
  @if assert_eq_i64(tc_lookup_constant(env_enums, "BitFlags_NONE"), 0, "BitFlags_NONE is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "BitFlags_READ"), 1, "BitFlags_READ is 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "BitFlags_WRITE"), 2, "BitFlags_WRITE is 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "BitFlags_EXEC"), 4, "BitFlags_EXEC is 4") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "BitFlags_ALL"), 7, "BitFlags_ALL is 7") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check SparseEnum auto-increment values
  @if assert_eq_i64(tc_lookup_constant(env_enums, "SparseEnum_ALPHA"), 10, "SparseEnum_ALPHA is 10") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "SparseEnum_BETA"), 11, "SparseEnum_BETA is 11 (auto-incremented)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "SparseEnum_GAMMA"), 12, "SparseEnum_GAMMA is 12 (auto-incremented)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "SparseEnum_DELTA"), 100, "SparseEnum_DELTA is 100") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "SparseEnum_EPSILON"), 101, "SparseEnum_EPSILON is 101 (auto-incremented)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.2 Enum constants in match statement inside function
  src_enum_match = "
  @enum Action
    START = 1
    STOP = 2
    PAUSE = 3
    RESUME = 4
  @end

  @fn handle_action(act: i64) -> string
    res = match act
      case Action_START => \"starting\"
      case Action_STOP => \"stopping\"
      case Action_PAUSE => \"pausing\"
      case Action_RESUME => \"resuming\"
    @end
    @return res
  @end
  "
  env_enum_match = typecheck_source(src_enum_match)
  @if assert_eq_i64(env_enum_match.errors.len(), 0, "Enum constants in Match arms typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end


  @! ============================================================================
  @! SECTION 4: STRESS CYCLES & MEMORY STABILITY
  @! ============================================================================
  println("\n--- [4] High-Repetition Stress & Pipeline Invariance ---")

  src_stress_sample = "
  @struct Node
    id: i64
    label: string
    value: f64
    is_active: bool
  @end

  @enum Severity
    LOW = 1
    MED = 5
    HIGH = 10
    CRITICAL = 50
  @end

  @impl Node
    @fn get_id(self) -> i64
      @return self.id
    @end
    @fn is_valid(self) -> bool
      @if self.is_active && self.id > 0
        @return true
      @elif self.id == 0
        @return false
      @else
        @return false
      @end
    @end
  @end

  @fn process_nodes(nodes: array, sev: i64) -> i64
    count = 0
    i = 0
    @while i < nodes.len()
      n = nodes[i]
      @if n.is_valid()
        count = count + 1
      @end
      i = i + 1
    @end
    @return count
  @end
  "

  println("Running 100 consecutive full lex -> parse -> typecheck cycles...")
  cycle_idx = 0
  cycle_failures = 0
  @while cycle_idx < 100
    prog_c = parse_source_program(src_stress_sample)
    env_c = typecheck_program_ast(prog_c)
    @if env_c.errors.len() != 0 || env_c.warnings.len() != 0
      cycle_failures = cycle_failures + 1
    @end
    cycle_idx = cycle_idx + 1
  @end

  @if assert_eq_i64(cycle_failures, 0, "100 consecutive frontend pipeline cycles completed with 0 errors/warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ============================================================================
  @! FINAL REPORT & SUMMARY
  @! ============================================================================
  println("\n=================================================================")
  println("📊 ADVERSARIAL STRESS SUITE SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("🏆 ALL ADVERSARIAL STRESS CHALLENGES PASSED (100% SUCCESS)!")
    return 0
  @else
    println("❌ FAILURES DETECTED IN FRONTEND PIPELINE!")
    return 1
  @end
@end
