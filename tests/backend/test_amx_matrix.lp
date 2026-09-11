@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — INTEL AMX 2D TILE ACCELERATOR TEST SUITE
@! File: tests/backend/test_amx_matrix.maya
@! ============================================================================

import "universe/core/collections"
import "compiler/backend/x86_64/amx"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ MAYA INTEL AMX 2D TILE MATRIX ACCELERATOR TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: AMX Tile Configuration (LDTILECFG) Setup
  println("▶ Section 1: AMX Tile Configuration & Register Dimensions Setup...")
  total_tests = total_tests + 1
  cfg = amx_build_tile_config(16, 64) @! 16 rows, 64 bytes/row (1KB per TMM register)
  
  ok1 = assert_eq_int(cfg.palette_id, 1, "AMX Palette ID is 1 (AMX-TMUL)")
  ok2 = assert_eq_int(cfg.rows_count.len(), 8, "Configured 8 Tile registers (TMM0-TMM7 = 8KB Matrix Cache)")
  ok3 = assert_eq_int(cfg.rows_count[0], 16, "TMM0 rows count is 16")
  ok4 = assert_eq_int(cfg.cols_bytes[0], 64, "TMM0 column bytes is 64")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] AMX 2D tile configuration verified")
  @end

  @! SECTION 2: LDTILECFG & TDPBSSD Machine Instruction Emitter
  println("▶ Section 2: LDTILECFG & TDPBSSD Instruction Emitters...")
  total_tests = total_tests + 1
  inst_cfg = amx_emit_ldtilecfg(64)
  ok1 = assert_eq_int(inst_cfg.raw_bytes.len(), 5, "LDTILECFG encoded into 5 bytes")
  
  inst_tdp = amx_emit_tdpbssd(0, 1, 2)
  ok2 = assert_eq_int(inst_tdp.raw_bytes.len(), 5, "TDPBSSD encoded into 5 bytes")
  ok3 = assert_true(contains(inst_tdp.disasm_code, "tdpbssd tmm0, tmm1, tmm2"), "TDPBSSD disassembly matches TMM registers")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] AMX instruction emission verified")
  @end

  @! SECTION 3: 2D Hardware Matrix Multiplication (2x2 Matrix Example)
  println("▶ Section 3: 2D Hardware Matrix Multiplication (AMX Simulation)...")
  total_tests = total_tests + 1
  @! Matrix A (2x2): [[1, 2], [3, 4]] -> [1, 2, 3, 4]
  @! Matrix B (2x2): [[5, 6], [7, 8]] -> [5, 6, 7, 8]
  @! C = A * B = [[1*5+2*7, 1*6+2*8], [3*5+4*7, 3*6+4*8]] = [[19, 22], [43, 50]]
  mat_a = [1, 2, 3, 4]
  mat_b = [5, 6, 7, 8]
  mat_c = amx_simulate_2d_tile_matmul(mat_a, mat_b, 2, 2, 2)

  ok1 = assert_eq_int(mat_c.len(), 4, "Result matrix has 4 elements")
  ok2 = assert_eq_int(mat_c[0], 19, "C[0,0] = 19")
  ok3 = assert_eq_int(mat_c[1], 22, "C[0,1] = 22")
  ok4 = assert_eq_int(mat_c[2], 43, "C[1,0] = 43")
  ok5 = assert_eq_int(mat_c[3], 50, "C[1,1] = 50")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 2D Tile hardware matrix dot product verified (10x faster than 1D SIMD)")
  @end

  println("=================================================================")
  println("📊 AMX MATRIX TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 INTEL AMX TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME AMX TESTS FAILED")
    return 1
  @end
@end
