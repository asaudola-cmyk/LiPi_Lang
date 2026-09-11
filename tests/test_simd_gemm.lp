// tests/test_simd_gemm.lp
// Validates 256-bit AVX2 Tiled GEMM Matrix Multiplication kernel
include "universe/core/io.lp"
include "universe/ai/simd_gemm.lp"

fn test_gemm_4x4
    a = [
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 1, 2, 3,
        4, 5, 6, 7
    ]
    
    b = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    ]
    
    c = [
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0
    ]
    
    simd_gemm_blocked(a, b, c, 4, 4, 4)
    
    match_all = 1
    i = 0
    while i < 16
        if c[i] != a[i]
            match_all = 0
        i = i + 1
        
    if match_all == 1
        say "PASS: SIMD GEMM Identity Multiplication"
    else
        say "FAIL: SIMD GEMM Identity Mismatch"

fn test_gemm_general
    a = [
        1, 2, 3, 4,
        5, 6, 7, 8
    ]
    b = [
        1, 2,
        3, 4,
        5, 6,
        7, 8
    ]
    c = [0, 0, 0, 0]
    
    simd_gemm_blocked(a, b, c, 2, 4, 2)
    // c0 = 50, c1 = 60, c2 = 114, c3 = 140
    c0 = c[0]
    c1 = c[1]
    c2 = c[2]
    c3 = c[3]
    
    if c0 == 50 and c1 == 60 and c2 == 114 and c3 == 140
        say "PASS: SIMD GEMM Rectangular Matrix Multiplication"
    else
        say "FAIL: Mismatch in SIMD GEMM calculation"

fn main
    test_gemm_4x4()
    test_gemm_general()
    return 0

main()
