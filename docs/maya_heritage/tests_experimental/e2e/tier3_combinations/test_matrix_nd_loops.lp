@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: MULTI-DIMENSIONAL MATRIX & NESTED LOOPS
@! File: tests/e2e/tier3_combinations/test_matrix_nd_loops.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@fn matrix_new(rows, cols, init_val)
  m = []
  r = 0
  @while r < rows
    row = []
    c = 0
    @while c < cols
      row.push(init_val)
      c = c + 1
    @end
    m.push(row)
    r = r + 1
  @end
  return m
@end

@fn matrix_multiply(a, b, r_a, c_a, c_b)
  res = matrix_new(r_a, c_b, 0)
  i = 0
  @while i < r_a
    j = 0
    @while j < c_b
      sum = 0
      k = 0
      @while k < c_a
        sum = sum + a[i][k] * b[k][j]
        k = k + 1
      @end
      res[i][j] = sum
      j = j + 1
    @end
    i = i + 1
  @end
  return res
@end

@fn matrix_transpose(m, rows, cols)
  t = matrix_new(cols, rows, 0)
  r = 0
  @while r < rows
    c = 0
    @while c < cols
      t[c][r] = m[r][c]
      c = c + 1
    @end
    r = r + 1
  @end
  return t
@end

@fn matrix_trace(m, n)
  tr = 0
  i = 0
  @while i < n
    tr = tr + m[i][i]
    i = i + 1
  @end
  return tr
@end

@fn det_2x2(m)
  return m[0][0] * m[1][1] - m[0][1] * m[1][0]
@end

@fn det_3x3(m)
  a = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
  b = m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
  c = m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
  return a - b + c
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 11: Multi-Dimensional Matrix & Loops")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.11.1: Matrix Multiplication 4x3 by 3x4 -> 4x4
  total = total + 1
  a = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
    [1, 0, 2]
  ]
  b = [
    [1, 0, 1, 2],
    [0, 1, 2, 1],
    [2, 1, 0, 1]
  ]
  @! Expected c = a * b:
  @! row 0: [1*1+2*0+3*2, 1*0+2*1+3*1, 1*1+2*2+3*0, 1*2+2*1+3*1] = [7, 5, 5, 7]
  @! row 1: [4*1+5*0+6*2, 4*0+5*1+6*1, 4*1+5*2+6*0, 4*2+5*1+6*1] = [16, 11, 14, 19]
  @! row 2: [7*1+8*0+9*2, 7*0+8*1+9*1, 7*1+8*2+9*0, 7*2+8*1+9*1] = [25, 17, 23, 31]
  @! row 3: [1*1+0*0+2*2, 1*0+0*1+2*1, 1*1+0*2+2*0, 1*2+0*1+2*1] = [5, 2, 1, 4]

  c = matrix_multiply(a, b, 4, 3, 4)

  @if c[0][0] == 7 && c[0][1] == 5 && c[1][0] == 16 && c[2][3] == 31 && c[3][0] == 5 && c[3][3] == 4
    passed = passed + 1
    println("  [PASS] T3.11.1: 4x3 by 3x4 Matrix multiplication produces exact 4x4 product")
  @else
    failed = failed + 1
    println("  [FAIL] T3.11.1: Matrix multiplication failed")
  @end

  @! T3.11.2: Matrix Trace Invariant
  total = total + 1
  @! Trace of 4x4 product c = 7 + 11 + 23 + 4 = 45
  tr = matrix_trace(c, 4)
  @if tr == 45
    passed = passed + 1
    println("  [PASS] T3.11.2: Matrix trace matches diagonal sum (tr == 45)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.11.2: Matrix trace expected 45, got " + int_to_str(tr))
  @end

  @! T3.11.3: Matrix Transposition Invariant (M^T)^T == M
  total = total + 1
  a_t = matrix_transpose(a, 4, 3)
  a_tt = matrix_transpose(a_t, 3, 4)
  is_equal = 1
  r = 0
  @while r < 4
    col = 0
    @while col < 3
      @if a[r][col] != a_tt[r][col]
        is_equal = 0
      @end
      col = col + 1
    @end
    r = r + 1
  @end

  @if a_t[0][1] == 4 && a_t[1][0] == 2 && is_equal == 1
    passed = passed + 1
    println("  [PASS] T3.11.3: Matrix transposition (A^T)^T == A holds identically")
  @else
    failed = failed + 1
    println("  [FAIL] T3.11.3: Matrix transposition failed")
  @end

  @! T3.11.4: 2x2 Determinant Calculation
  total = total + 1
  m2 = [
    [4, 6],
    [3, 8]
  ]
  @! det = 4 * 8 - 6 * 3 = 32 - 18 = 14
  d2 = det_2x2(m2)
  @if d2 == 14
    passed = passed + 1
    println("  [PASS] T3.11.4: 2x2 Matrix determinant (det == 14)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.11.4: 2x2 Determinant expected 14, got " + int_to_str(d2))
  @end

  @! T3.11.5: 3x3 Determinant Calculation
  total = total + 1
  m3 = [
    [6, 1, 1],
    [4, -2, 5],
    [2, 8, 7]
  ]
  @! det = 6 * (-2*7 - 5*8) - 1 * (4*7 - 5*2) + 1 * (4*8 - (-2)*2)
  @!     = 6 * (-14 - 40) - 1 * (28 - 10) + 1 * (32 + 4)
  @!     = 6 * (-54) - 1 * 18 + 1 * 36
  @!     = -324 - 18 + 36 = -306
  d3 = det_3x3(m3)
  @if d3 == -306
    passed = passed + 1
    println("  [PASS] T3.11.5: 3x3 Matrix determinant (det == -306)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.11.5: 3x3 Determinant expected -306, got " + int_to_str(d3))
  @end

  println("-----------------------------------------------------------------")
  println("Combination 11 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 11 (Multi-Dimensional Matrix & Loops) PASSED")
    return 0
  @else
    println("✗ Combination 11 (Multi-Dimensional Matrix & Loops) FAILED")
    return 1
  @end
@end
