// Test 24: Matrix Operations — Lipi 2.0
// Demonstrates: 2x2 and 3x3 matrix arithmetic using flat variables

// 2x2 Matrix: stored as a11, a12, a21, a22
// Add two 2x2 matrices
fn mat2_add a11 a12 a21 a22 b11 b12 b21 b22
    say a11 + b11
    say a12 + b12
    say a21 + b21
    say a22 + b22

// Multiply two 2x2 matrices: C = A * B
fn mat2_mul_c11 a11 a12 a21 a22 b11 b12 b21 b22
    return a11 * b11 + a12 * b21

fn mat2_mul_c12 a11 a12 a21 a22 b11 b12 b21 b22
    return a11 * b12 + a12 * b22

fn mat2_mul_c21 a11 a12 a21 a22 b11 b12 b21 b22
    return a21 * b11 + a22 * b21

fn mat2_mul_c22 a11 a12 a21 a22 b11 b12 b21 b22
    return a21 * b12 + a22 * b22

// Determinant of 2x2
fn mat2_det a11 a12 a21 a22
    return a11 * a22 - a12 * a21

// Trace of 2x2 (sum of diagonal)
fn mat2_trace a11 a12 a21 a22
    return a11 + a22

// Dot product of two 3-vectors
fn dot3 x1 y1 z1 x2 y2 z2
    return x1 * x2 + y1 * y2 + z1 * z2

// Vector magnitude squared
fn mag_sq3 x y z
    return x*x + y*y + z*z

// === Tests ===
say "=== 2x2 Matrix Operations ==="

// A = [[1,2],[3,4]], B = [[5,6],[7,8]]
say "A + B:"
mat2_add 1 2 3 4 5 6 7 8

say "A * B:"
say mat2_mul_c11 1 2 3 4 5 6 7 8
say mat2_mul_c12 1 2 3 4 5 6 7 8
say mat2_mul_c21 1 2 3 4 5 6 7 8
say mat2_mul_c22 1 2 3 4 5 6 7 8

say "det(A):"
say mat2_det 1 2 3 4

say "trace(A):"
say mat2_trace 1 2 3 4

say "=== 3D Vector Operations ==="
// u = (1, 2, 3), v = (4, 5, 6)
say "dot(u, v):"
say dot3 1 2 3 4 5 6

say "mag_sq(u):"
say mag_sq3 1 2 3

say "mag_sq(3,4,0) = 25:"
say mag_sq3 3 4 0

// Identity matrix product with I: A * I = A
say "det(Identity):"
say mat2_det 1 0 0 1

// Scalar multiply 2x2 matrix by k=3
k = 3
say "3 * A diagonal:"
say k * 1
say k * 4

say "PASS: Test 24 Matrix Operations"
