@! Maya Quantum Logic Unit Tests

import "universe/quantum/superposition"

@fn assert_approx_eq(actual, expected, msg)
  diff = actual - expected
  @if diff < 0.0
    diff = 0.0 - diff
  @end
  
  @if diff < 0.001
    println("  [PASS] " + msg + " (diff=" + diff.to_str() + ")")
    return 1
  @else
    println("  [FAIL] " + msg + " (actual=" + actual.to_str() + ", expected=" + expected.to_str() + ")")
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA QUANTUM LOGIC UNIT TEST SUITE             ")
  println("==================================================")
  
  q = qubit_new()
  assert_approx_eq(q.alpha, 1.0, "Qubit initialized to |0>")
  
  q = qubit_pauli_x(q)
  assert_approx_eq(q.beta, 1.0, "Pauli-X applied, state |1>")
  
  q2 = qubit_new()
  q2 = qubit_hadamard(q2)
  assert_approx_eq(q2.alpha, 0.707106, "Hadamard |0> amplitude")
  assert_approx_eq(q2.beta, 0.707106, "Hadamard |1> amplitude")
  
  prob1 = qubit_measure(q2)
  assert_approx_eq(prob1, 50.0, "Hadamard yields 50% probability of |1>")
  
  println("🎉 ALL QUANTUM TESTS PASSED!")
  return 0
@end
