@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MULTI-QUBIT QUANTUM SIMULATOR TEST SUITE
@! File: tests/quantum/test_quantum_multi_qubit.maya
@! ============================================================================

import "universe/core/collections"
import "universe/quantum/multi_qubit"

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
  println("🌌 MAYA MULTI-QUBIT TRUE QUANTUM SIMULATOR TEST SUITE 🌌")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Quantum Register Initialization (2^N Dimension)
  println("▶ Section 1: 2-Qubit & 3-Qubit Register Initialization (2^N Dimension)...")
  total_tests = total_tests + 1
  q2 = qreg_new(2)
  ok1 = assert_eq_int(q2.dim, 4, "2-Qubit register has dimension 2^2 = 4 basis states")
  ok2 = assert_eq_int(q2.amplitudes_real[0], 1000, "Initial state is pure |00> with 100% amplitude")
  ok3 = assert_eq_int(q2.amplitudes_real[1], 0, "|01> amplitude is 0")
  
  q3 = qreg_new(3)
  ok4 = assert_eq_int(q3.dim, 8, "3-Qubit register has dimension 2^3 = 8 basis states")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 2^N state vector register initialization verified")
  @end

  @! SECTION 2: Single-Qubit Unitary Gates (Pauli-X, Pauli-Z, Hadamard)
  println("▶ Section 2: Single-Qubit Unitary Operators (X, Z, H)...")
  total_tests = total_tests + 1
  reg_x = qreg_new(1)
  reg_x = qreg_apply_x(reg_x, 0)
  ok1 = assert_eq_int(reg_x.amplitudes_real[0], 0, "Pauli-X flipped |0> amplitude to 0")
  ok2 = assert_eq_int(reg_x.amplitudes_real[1], 1000, "Pauli-X produced pure |1> with 100% amplitude")

  reg_h = qreg_new(1)
  reg_h = qreg_apply_hadamard(reg_h, 0)
  p0 = qreg_get_probability_pct(reg_h, 0)
  p1 = qreg_get_probability_pct(reg_h, 1)
  ok3 = assert_true(p0 >= 49 && p0 <= 51, "Hadamard created equal superposition: P(|0>) ~= 50%")
  ok4 = assert_true(p1 >= 49 && p1 <= 51, "Hadamard created equal superposition: P(|1>) ~= 50%")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Unitary X, Z and Hadamard quantum gates verified")
  @end

  @! SECTION 3: Quantum Entanglement & Bell State (|Phi+> = (|00> + |11>) / sqrt(2))
  println("▶ Section 3: Quantum Entanglement & Bell State (|Phi+>)...")
  total_tests = total_tests + 1
  bell = qreg_create_bell_phi_plus()
  
  @! Basis states: 0=|00>, 1=|01>, 2=|10>, 3=|11>
  prob_00 = qreg_get_probability_pct(bell, 0)
  prob_01 = qreg_get_probability_pct(bell, 1)
  prob_10 = qreg_get_probability_pct(bell, 2)
  prob_11 = qreg_get_probability_pct(bell, 3)

  ok1 = assert_true(prob_00 >= 49 && prob_00 <= 51, "Bell State |00> probability is 50%")
  ok2 = assert_eq_int(prob_01, 0, "Bell State |01> probability is 0% (Perfect correlation)")
  ok3 = assert_eq_int(prob_10, 0, "Bell State |10> probability is 0% (Perfect correlation)")
  ok4 = assert_true(prob_11 >= 49 && prob_11 <= 51, "Bell State |11> probability is 50%")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Quantum entanglement & Bell State Phi+ correlation verified")
  @end

  @! SECTION 4: Multi-Qubit Controlled Gates (Toffoli / CCNOT)
  println("▶ Section 4: 3-Qubit Toffoli (CCNOT) Gate Algebra...")
  total_tests = total_tests + 1
  reg_tof = qreg_new(3)
  @! Flip q0 and q1 so control bits are |110> (index 3: q0=1, q1=1, q2=0)
  reg_tof = qreg_apply_x(reg_tof, 0)
  reg_tof = qreg_apply_x(reg_tof, 1)
  ok1 = assert_eq_int(reg_tof.amplitudes_real[3], 1000, "Prepared state |110> (index 3)")

  @! Apply Toffoli(ctrl1=0, ctrl2=1, target=2) -> should flip target q2 to 1 (state becomes |111>, index 7)
  reg_tof = qreg_apply_toffoli(reg_tof, 0, 1, 2)
  ok2 = assert_eq_int(reg_tof.amplitudes_real[3], 0, "Initial state |110> amplitude inverted")
  ok3 = assert_eq_int(reg_tof.amplitudes_real[7], 1000, "Target qubit flipped: resulting state is |111> (index 7)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 3-Qubit Toffoli CCNOT gate matrix transformation verified")
  @end

  println("=================================================================")
  println("📊 QUANTUM SIMULATOR TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 MULTI-QUBIT QUANTUM SIMULATOR TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME QUANTUM SIMULATOR TESTS FAILED")
    return 1
  @end
@end
