@! ============================================================================
@! MAYA COMPILER MIDDLEEND: PATTERN MATCHING & EXHAUSTIVENESS ENGINE
@! Module: compiler/middleend/pattern_match
@! Matrix decomposition algorithm for exhaustiveness & decision tree generation
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@enum PatternKind
  Wildcard = 0
  LiteralInt = 1
  LiteralFloat = 2
  LiteralBool = 3
  LiteralString = 4
  Variable = 5
  Tuple = 6
  Struct = 7
  Enum = 8
  Or = 9
  Guard = 10
@end

@struct Span
  start: i64
  end_pos: i64
@end

@struct Pattern
  kind: i64
  span: Span
  val_str: string
  val_int: i64
  sub_patterns: array
@end

@struct MatchArm
  pattern: Pattern
  guard_cond: string
  body_expr: string
@end

@struct MatchExpr
  scrutinee: string
  arms: array
@end

@struct PatternMatrix
  rows: array
@end

@fn default_matrix(matrix: PatternMatrix) -> PatternMatrix
  new_rows = []
  i = 0
  num_items = matrix.rows.len()
  @while i < num_items
    row = matrix.rows[i]
    @if row.len() > 0
      first_pat = row[0]
      @if first_pat.kind == 0 || first_pat.kind == 5
        tail_row = []
        j = 1
        r_len = row.len()
        @while j < r_len
          tail_row = tail_row.push(row[j])
          j = j + 1
        @end
        new_rows = new_rows.push(tail_row)
      @end
    @end
    i = i + 1
  @end
  return { rows: new_rows }
@end

@fn specialize_matrix_lit_int(matrix: PatternMatrix, val: i64) -> PatternMatrix
  new_rows = []
  i = 0
  num_items = matrix.rows.len()
  @while i < num_items
    row = matrix.rows[i]
    @if row.len() > 0
      first_pat = row[0]
      @if (first_pat.kind == 1 && first_pat.val_int == val) || first_pat.kind == 0 || first_pat.kind == 5
        tail_row = []
        j = 1
        r_len = row.len()
        @while j < r_len
          tail_row = tail_row.push(row[j])
          j = j + 1
        @end
        new_rows = new_rows.push(tail_row)
      @end
    @end
    i = i + 1
  @end
  return { rows: new_rows }
@end

@fn specialize_matrix_lit_string(matrix: PatternMatrix, val: string) -> PatternMatrix
  new_rows = []
  i = 0
  num_items = matrix.rows.len()
  @while i < num_items
    row = matrix.rows[i]
    @if row.len() > 0
      first_pat = row[0]
      @if (first_pat.kind == 4 && first_pat.val_str == val) || first_pat.kind == 0 || first_pat.kind == 5
        tail_row = []
        j = 1
        r_len = row.len()
        @while j < r_len
          tail_row = tail_row.push(row[j])
          j = j + 1
        @end
        new_rows = new_rows.push(tail_row)
      @end
    @end
    i = i + 1
  @end
  return { rows: new_rows }
@end

@fn is_useful(matrix: PatternMatrix, q: array) -> i64
  @if matrix.rows.len() == 0
    return 1
  @end
  @if q.len() == 0
    return 0
  @end

  first_pat = q[0]
  rest_q = []
  k = 1
  q_len = q.len()
  @while k < q_len
    rest_q = rest_q.push(q[k])
    k = k + 1
  @end

  @if first_pat.kind == 0 || first_pat.kind == 5
    def_matrix = default_matrix(matrix)
    return is_useful(def_matrix, rest_q)
  @elif first_pat.kind == 1
    spec_matrix = specialize_matrix_lit_int(matrix, first_pat.val_int)
    return is_useful(spec_matrix, rest_q)
  @elif first_pat.kind == 4
    spec_matrix = specialize_matrix_lit_string(matrix, first_pat.val_str)
    return is_useful(spec_matrix, rest_q)
  @end

  return 1
@end

@fn check_exhaustiveness(arms: array) -> i64
  matrix = { rows: [] }
  i = 0
  num_items = arms.len()
  @while i < num_items
    arm = arms[i]
    q = [arm.pattern]
    @if is_useful(matrix, q) == 0
      return 0 @! Redundant pattern
    @end
    matrix.rows = matrix.rows.push(q)
    i = i + 1
  @end

  wild_q = [{ kind: 0, span: { start: 0, end_pos: 0 }, val_str: "", val_int: 0, sub_patterns: [] }]
  @if is_useful(matrix, wild_q) == 1
    return 0 @! Inexhaustive
  @end
  return 1
@end

@struct DecisionTree
  decision_type: i64
  arm_index: i64
@end

@fn compile_pattern_match(expr: MatchExpr) -> DecisionTree
  @if expr.arms.len() == 0
    return { decision_type: 0, arm_index: -1 }
  @end
  return { decision_type: 1, arm_index: 0 }
@end
