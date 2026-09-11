import "universe/maya_universe"
import "universe/core/fmt"

@fn pad_right(s, width)
  @while str_len(s) < width
    s = s + " "
  @end
  return s
@end

@fn print_mat(m)
  i = 0
  @while i < m.len()
    s = "| "
    j = 0
    @while j < m[i].len()
      val_str = int_to_str(m[i][j])
      s = s + pad_right(val_str, 5) + " "
      j = j + 1
    @end
    s = s + "|"
    println(s)
    i = i + 1
  @end
@end

@fn mat_transpose(m)
  rows = m.len()
  @if rows == 0 return [] @end
  cols = m[0].len()
  res = []
  i = 0
  @while i < cols
    row = []
    j = 0
    @while j < rows
      row = row.push(m[j][i])
      j = j + 1
    @end
    res = res.push(row)
    i = i + 1
  @end
  return res
@end

@fn mat_dot(v1, v2)
  sum = 0
  i = 0
  @while i < v1.len()
    sum = sum + v1[i] * v2[i]
    i = i + 1
  @end
  return sum
@end

@fn mat_mul(a, b)
  rows_a = a.len()
  cols_a = a[0].len()
  cols_b = b[0].len()
  res = []
  i = 0
  @while i < rows_a
    row = []
    j = 0
    @while j < cols_b
      sum = 0
      k = 0
      @while k < cols_a
        sum = sum + a[i][k] * b[k][j]
        k = k + 1
      @end
      row = row.push(sum)
      j = j + 1
    @end
    res = res.push(row)
    i = i + 1
  @end
  return res
@end

@fn mat_det2(m)
  return m[0][0] * m[1][1] - m[0][1] * m[1][0]
@end

@fn mat_det3(m)
  term1 = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
  term2 = m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
  term3 = m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
  return term1 - term2 + term3
@end

@fn main()
  println("=== Maya Matrix Math ===")
  println("")

  v1 = [1, 2, 3]
  v2 = [4, 5, 6]
  println("Dot product of [1,2,3] and [4,5,6] = " + int_to_str(mat_dot(v1, v2)))
  println("")

  m2 = [[4, 3], [2, 1]]
  println("Matrix 2x2:")
  print_mat(m2)
  println("Determinant 2x2 = " + int_to_str(mat_det2(m2)))
  println("")

  m3 = [[6, 1, 1], [4, -2, 5], [2, 8, 7]]
  println("Matrix 3x3:")
  print_mat(m3)
  println("Determinant 3x3 = " + int_to_str(mat_det3(m3)))
  println("")

  m_a = [[1, 2], [3, 4]]
  m_b = [[2, 0], [1, 2]]
  println("Matrix A:")
  print_mat(m_a)
  println("Matrix B:")
  print_mat(m_b)
  println("Matrix A * B:")
  print_mat(mat_mul(m_a, m_b))
  println("")

  println("Transpose of Matrix A:")
  print_mat(mat_transpose(m_a))

  return 0
@end
