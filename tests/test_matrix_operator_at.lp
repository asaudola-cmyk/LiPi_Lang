// ==============================================================================
// 🧪 LIPI REGRESSION TEST: FIRST-CLASS TENSOR & MATRIX INFIX '@' OPERATOR
// ⚡ Tests matrix multiplication, matrix-vector product, vector dot product,
//    scalar fallback, rectangular matrices, and operator precedence tiers.
// ==============================================================================

fn test_scalar_matmul()
    // WHY: Pure scalar arithmetic fallback when operands are integers
    s1 = 6 @ 7
    if s1 != 42
        println("FAIL: test_scalar_matmul expected 42, got " + str(s1))
        exit(1)
    end
    s2 = 0 @ 100
    if s2 != 0
        println("FAIL: test_scalar_matmul zero expected 0, got " + str(s2))
        exit(1)
    end
    println("✔ PASS: Scalar multiplication fallback (6 @ 7 == 42)")
    return 1
end

fn test_vector_dot_product()
    // WHY: 1D Vector dot product: A @ B = sum(A[p] * B[p])
    v1 = [1, 2, 3]
    v2 = [4, 5, 6]
    dot = v1 @ v2
    // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    if dot != 32
        println("FAIL: test_vector_dot_product expected 32, got " + str(dot))
        exit(1)
    end

    // Orthogonal vectors: [1, 0, 0] @ [0, 1, 0] == 0
    e1 = [1, 0, 0]
    e2 = [0, 1, 0]
    ortho = e1 @ e2
    if ortho != 0
        println("FAIL: test_vector_dot_product orthogonal expected 0, got " + str(ortho))
        exit(1)
    end
    println("✔ PASS: 1D Vector dot product ([1,2,3] @ [4,5,6] == 32)")
    return 1
end

fn test_matrix_vector_mul()
    // WHY: 2D Matrix (M x K) @ 1D Vector (K) -> 1D Vector (M)
    m = [[1, 2], [3, 4]]
    v = [5, 6]
    res = m @ v
    // res[0] = 1*5 + 2*6 = 17
    // res[1] = 3*5 + 4*6 = 39
    if len(res) != 2
        println("FAIL: test_matrix_vector_mul length expected 2, got " + str(len(res)))
        exit(1)
    end
    if res[0] != 17 or res[1] != 39
        println("FAIL: test_matrix_vector_mul expected [17, 39], got [" + str(res[0]) + ", " + str(res[1]) + "]")
        exit(1)
    end
    println("✔ PASS: 2D Matrix @ 1D Vector ([[1,2],[3,4]] @ [5,6] == [17, 39])")
    return 1
end

fn test_matrix_matrix_square()
    // WHY: Standard 2x2 Square Matrix Multiplication: C = A @ B
    a = [[1, 2], [3, 4]]
    b = [[5, 6], [7, 8]]
    c = a @ b

    if len(c) != 2
        println("FAIL: test_matrix_matrix_square outer length expected 2, got " + str(len(c)))
        exit(1)
    end
    r0 = c[0]
    r1 = c[1]
    if len(r0) != 2 or len(r1) != 2
        println("FAIL: test_matrix_matrix_square inner lengths expected 2")
        exit(1)
    end
    // Expected: [[19, 22], [43, 50]]
    if r0[0] != 19 or r0[1] != 22 or r1[0] != 43 or r1[1] != 50
        println("FAIL: test_matrix_matrix_square expected [[19,22],[43,50]], got [[" + str(r0[0]) + "," + str(r0[1]) + "],[" + str(r1[0]) + "," + str(r1[1]) + "]]")
        exit(1)
    end
    println("✔ PASS: 2x2 Square Matrix Multiplication ([[1,2],[3,4]] @ [[5,6],[7,8]] == [[19,22],[43,50]])")
    return 1
end

fn test_matrix_matrix_rectangular()
    // WHY: Rectangular (2x3) @ (3x2) -> (2x2) Matrix Multiplication
    a = [[1, 2, 3], [4, 5, 6]]
    b = [[7, 8], [9, 1], [2, 3]]
    c = a @ b

    // c[0][0] = 1*7 + 2*9 + 3*2 = 7 + 18 + 6 = 31
    // c[0][1] = 1*8 + 2*1 + 3*3 = 8 + 2 + 9 = 19
    // c[1][0] = 4*7 + 5*9 + 6*2 = 28 + 45 + 12 = 85
    // c[1][1] = 4*8 + 5*1 + 6*3 = 32 + 5 + 18 = 55
    r0 = c[0]
    r1 = c[1]
    if r0[0] != 31 or r0[1] != 19 or r1[0] != 85 or r1[1] != 55
        println("FAIL: test_matrix_matrix_rectangular expected [[31,19],[85,55]], got [[" + str(r0[0]) + "," + str(r0[1]) + "],[" + str(r1[0]) + "," + str(r1[1]) + "]]")
        exit(1)
    end
    println("✔ PASS: Rectangular Matrix Multiplication ((2x3) @ (3x2) == (2x2))")
    return 1
end

fn test_operator_precedence()
    // WHY: @ belongs to multiplicative tier (precedence 110), binding tighter than + or -
    res = 10 + 2 @ 3
    if res != 16
        println("FAIL: test_operator_precedence expected 16, got " + str(res))
        exit(1)
    end

    res2 = 2 @ 3 + 10
    if res2 != 16
        println("FAIL: test_operator_precedence 2 expected 16, got " + str(res2))
        exit(1)
    end
    println("✔ PASS: Operator Precedence (10 + 2 @ 3 == 16)")
    return 1
end

fn test_function_alias_matmul()
    // WHY: Builtin alias matmul(A, B) must invoke the exact same silicon entry point
    a = [[1, 2], [3, 4]]
    b = [[5, 6], [7, 8]]
    c = matmul(a, b)
    r0 = c[0]
    r1 = c[1]
    if r0[0] != 19 or r0[1] != 22 or r1[0] != 43 or r1[1] != 50
        println("FAIL: test_function_alias_matmul mismatch")
        exit(1)
    end
    println("✔ PASS: Builtin function alias matmul(A, B)")
    return 1
end

fn main()
    println("── Running Matrix Operator (@) Silicon Regression Suite ──")
    test_scalar_matmul()
    test_vector_dot_product()
    test_matrix_vector_mul()
    test_matrix_matrix_square()
    test_matrix_matrix_rectangular()
    test_operator_precedence()
    test_function_alias_matmul()
    println("🎉 ALL MATRIX OPERATOR REGRESSION TESTS PASSED!")
    return 0
end

main()
