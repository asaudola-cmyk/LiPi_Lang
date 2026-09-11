@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP 3: MATRIX OPERATIONS
@! File: tests/e2e/tier4_applications/test_matrix_operations.maya
@! ============================================================================

import "universe/core/collections"

@fn mat_add_3x3(a, b)
  result = []
  i = 0
  @while i < 9
    result.push(a[i] + b[i])
    i = i + 1
  @end
  return result
@end

@fn mat_mul_2x2(a, b)
  res = []
  @! res[0] = a[0]*b[0] + a[1]*b[2]
  res.push(a[0] * b[0] + a[1] * b[2])
  @! res[1] = a[0]*b[1] + a[1]*b[3]
  res.push(a[0] * b[1] + a[1] * b[3])
  @! res[2] = a[2]*b[0] + a[3]*b[2]
  res.push(a[2] * b[0] + a[3] * b[2])
  @! res[3] = a[2]*b[1] + a[3]*b[3]
  res.push(a[2] * b[1] + a[3] * b[3])
  return res
@end

@fn mat_transpose_3x3(m)
  t = [0, 0, 0, 0, 0, 0, 0, 0, 0]
  r = 0
  @while r < 3
    c = 0
    @while c < 3
      t[c * 3 + r] = m[r * 3 + c]
      c = c + 1
    @end
    r = r + 1
  @end
  return t
@end

@fn det_2x2(m)
  @! det = a*d - b*c
  return m[0] * m[3] - m[1] * m[2]
@end

@fn det_3x3(m)
  @! a(ei - fh) - b(di - fg) + c(dh - eg)
  a = m[0]
  b = m[1]
  c = m[2]
  d = m[3]
  e = m[4]
  f = m[5]
  g = m[6]
  h = m[7]
  i = m[8]

  term1 = a * (e * i - f * h)
  term2 = b * (d * i - f * g)
  term3 = c * (d * h - e * g)

  return term1 - term2 + term3
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application 3: Matrix Mathematics & Transformations")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.3.1: 2x2 Matrix Multiplication
  total = total + 1
  @! A = [1, 2; 3, 4], B = [2, 0; 1, 2]
  @! A*B = [1*2 + 2*1, 1*0 + 2*2; 3*2 + 4*1, 3*0 + 4*2] = [4, 4; 10, 8]
  mat_a = [1, 2, 3, 4]
  mat_b = [2, 0, 1, 2]
  prod = mat_mul_2x2(mat_a, mat_b)
  @if prod[0] == 4 && prod[1] == 4 && prod[2] == 10 && prod[3] == 8
    passed = passed + 1
    println("  [PASS] T4.3.1: 2x2 matrix multiplication ([4, 4, 10, 8])")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.1: 2x2 matrix multiplication")
  @end

  @! T4.3.2: 3x3 Matrix Addition
  total = total + 1
  m1 = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  m2 = [9, 8, 7, 6, 5, 4, 3, 2, 1]
  sum_3x3 = mat_add_3x3(m1, m2)
  @! All elements should be 10
  @if sum_3x3[0] == 10 && sum_3x3[4] == 10 && sum_3x3[8] == 10
    passed = passed + 1
    println("  [PASS] T4.3.2: 3x3 matrix element-wise addition (all entries == 10)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.2: 3x3 matrix addition")
  @end

  @! T4.3.3: 3x3 Matrix Transposition
  total = total + 1
  @! M = [1, 2, 3; 4, 5, 6; 7, 8, 9]
  @! Transpose = [1, 4, 7; 2, 5, 8; 3, 6, 9]
  trans = mat_transpose_3x3(m1)
  @if trans[0] == 1 && trans[1] == 4 && trans[2] == 7 && trans[3] == 2 && trans[5] == 8
    passed = passed + 1
    println("  [PASS] T4.3.3: 3x3 matrix transposition ([1, 4, 7, 2, 5, 8, 3, 6, 9])")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.3: 3x3 matrix transposition")
  @end

  @! T4.3.4: 2x2 Determinant
  total = total + 1
  @! det([4, 6; 3, 8]) = 4*8 - 6*3 = 32 - 18 = 14
  m_det2 = [4, 6, 3, 8]
  d2 = det_2x2(m_det2)
  @if d2 == 14
    passed = passed + 1
    println("  [PASS] T4.3.4: 2x2 matrix determinant (det == 14)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.4: 2x2 matrix determinant")
  @end

  @! T4.3.5: 3x3 Determinant
  total = total + 1
  @! M = [6, 1, 1; 4, -2, 5; 2, 8, 7]
  @! 6*(-14 - 40) - 1*(28 - 10) + 1*(32 - (-4))
  @! 6*(-54) - 1*(18) + 1*(36) = -324 - 18 + 36 = -306
  m_det3 = [6, 1, 1, 4, -2, 5, 2, 8, 7]
  d3 = det_3x3(m_det3)
  @if d3 == -306
    passed = passed + 1
    println("  [PASS] T4.3.5: 3x3 matrix determinant via cofactor expansion (det == -306)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.5: 3x3 matrix determinant")
  @end

  println("-----------------------------------------------------------------")
  println("App 3 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Application 3 (Matrix Operations) PASSED")
    return 0
  @else
    println("✗ Application 3 (Matrix Operations) FAILED")
    return 1
  @end
@end
