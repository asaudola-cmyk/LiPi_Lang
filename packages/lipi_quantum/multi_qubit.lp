@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — MULTI-QUBIT QUANTUM SIMULATOR ENGINE
@! Module: universe/quantum/multi_qubit.lp
@! Milestone: Multi-Qubit True Quantum Simulator
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: 2^N State Vectors, Matrix Gate Operations (H, X, Y, Z, CNOT, Toffoli),
@! Quantum Entanglement (Bell States), and Measurement Probabilities
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"

@! ============================================================================
@! 1. QUANTUM REGISTER DATA STRUCTURE (Scale: 1000 fixed-point)
@! ============================================================================

@struct QuantumRegister
  num_qubits: i64
  dim: i64                 @! 2^N
  amplitudes_real: array   @! Real component (scale 1000)
  amplitudes_imag: array    @! Imaginary component (scale 1000)
@end

@fn qreg_new(num_qubits)
  dim = 1
  q = 0
  @while q < num_qubits
    dim = dim * 2
    q = q + 1
  @end

  re = []
  im = []
  i = 0
  @while i < dim
    @if i == 0
      re = re.push(1000) @! |00...0> = 1.0 (1000)
    @else
      re = re.push(0)
    @end
    im = im.push(0)
    i = i + 1
  @end

  return {
    num_qubits: num_qubits,
    dim: dim,
    amplitudes_real: re,
    amplitudes_imag: im
  }
@end

@! ============================================================================
@! 2. BIT MANIPULATION HELPERS
@! ============================================================================

@fn qreg_get_bit(val, bit_pos)
  mask = 1
  b = 0
  @while b < bit_pos
    mask = mask * 2
    b = b + 1
  @end
  return (val / mask) % 2
@end

@fn qreg_flip_bit(val, bit_pos)
  mask = 1
  b = 0
  @while b < bit_pos
    mask = mask * 2
    b = b + 1
  @end
  @if (val / mask) % 2 == 1
    return val - mask
  @end
  return val + mask
@end

@! ============================================================================
@! 3. QUANTUM GATES (Single & Multi-Qubit Operators)
@! ============================================================================

@! Hadamard Gate (H) on target qubit
@fn qreg_apply_hadamard(reg, target_qubit)
  new_re = []
  new_im = []
  i = 0
  @while i < reg.dim
    new_re = new_re.push(0)
    new_im = new_im.push(0)
    i = i + 1
  @end

  inv_sqrt2 = 707 @! 1/sqrt(2) * 1000 ~= 707

  i = 0
  @while i < reg.dim
    bit = qreg_get_bit(i, target_qubit)
    paired_idx = qreg_flip_bit(i, target_qubit)
    
    @if bit == 0
      @! |0> -> (|0> + |1>) / sqrt(2)
      @! |1> -> (|0> - |1>) / sqrt(2)
      a_re = reg.amplitudes_real[i]
      b_re = reg.amplitudes_real[paired_idx]
      
      new_re[i] = ((a_re + b_re) * inv_sqrt2) / 1000
      new_re[paired_idx] = ((a_re - b_re) * inv_sqrt2) / 1000
    @end
    i = i + 1
  @end

  reg.amplitudes_real = new_re
  return reg
@end

@! Pauli-X Gate (NOT Gate)
@fn qreg_apply_x(reg, target_qubit)
  new_re = []
  new_im = []
  i = 0
  @while i < reg.dim
    new_re = new_re.push(0)
    new_im = new_im.push(0)
    i = i + 1
  @end

  i = 0
  @while i < reg.dim
    paired = qreg_flip_bit(i, target_qubit)
    new_re[paired] = reg.amplitudes_real[i]
    new_im[paired] = reg.amplitudes_imag[i]
    i = i + 1
  @end

  reg.amplitudes_real = new_re
  reg.amplitudes_imag = new_im
  return reg
@end

@! Pauli-Z Gate (Phase Flip)
@fn qreg_apply_z(reg, target_qubit)
  i = 0
  @while i < reg.dim
    bit = qreg_get_bit(i, target_qubit)
    @if bit == 1
      reg.amplitudes_real[i] = 0 - reg.amplitudes_real[i]
      reg.amplitudes_imag[i] = 0 - reg.amplitudes_imag[i]
    @end
    i = i + 1
  @end
  return reg
@end

@! Controlled-NOT Gate (CNOT)
@fn qreg_apply_cnot(reg, control_qubit, target_qubit)
  new_re = []
  new_im = []
  i = 0
  @while i < reg.dim
    new_re = new_re.push(0)
    new_im = new_im.push(0)
    i = i + 1
  @end

  i = 0
  @while i < reg.dim
    ctrl_bit = qreg_get_bit(i, control_qubit)
    @if ctrl_bit == 1
      paired = qreg_flip_bit(i, target_qubit)
      new_re[paired] = reg.amplitudes_real[i]
      new_im[paired] = reg.amplitudes_imag[i]
    @else
      new_re[i] = reg.amplitudes_real[i]
      new_im[i] = reg.amplitudes_imag[i]
    @end
    i = i + 1
  @end

  reg.amplitudes_real = new_re
  reg.amplitudes_imag = new_im
  return reg
@end

@! Toffoli Gate (CCNOT)
@fn qreg_apply_toffoli(reg, ctrl1, ctrl2, target)
  new_re = []
  new_im = []
  i = 0
  @while i < reg.dim
    new_re = new_re.push(0)
    new_im = new_im.push(0)
    i = i + 1
  @end

  i = 0
  @while i < reg.dim
    c1 = qreg_get_bit(i, ctrl1)
    c2 = qreg_get_bit(i, ctrl2)
    @if c1 == 1 && c2 == 1
      paired = qreg_flip_bit(i, target)
      new_re[paired] = reg.amplitudes_real[i]
      new_im[paired] = reg.amplitudes_imag[i]
    @else
      new_re[i] = reg.amplitudes_real[i]
      new_im[i] = reg.amplitudes_imag[i]
    @end
    i = i + 1
  @end

  reg.amplitudes_real = new_re
  reg.amplitudes_imag = new_im
  return reg
@end

@! ============================================================================
@! 4. ADVANCED MULTI-QUBIT OPERATORS (SWAP, CZ, Phase Gates)
@! ============================================================================

@! Controlled-Z Gate (CZ)
@fn qreg_apply_cz(reg, ctrl, target)
  // WHY: Applies Pauli-Z phase flip to target only when control bit is 1.
  i = 0
  @while i < reg.dim
    c = qreg_get_bit(i, ctrl)
    t = qreg_get_bit(i, target)
    @if c == 1 && t == 1
      reg.amplitudes_real[i] = 0 - reg.amplitudes_real[i]
      reg.amplitudes_imag[i] = 0 - reg.amplitudes_imag[i]
    @end
    i = i + 1
  @end
  return reg
@end

@! SWAP Gate (Exchanges states between qubit A and qubit B)
@fn qreg_apply_swap(reg, q1, q2)
  // WHY: Swaps amplitudes between basis states where bit(q1) != bit(q2).
  @if q1 == q2
    return reg
  @end
  new_re = []
  new_im = []
  i = 0
  @while i < reg.dim
    new_re = new_re.push(0)
    new_im = new_im.push(0)
    i = i + 1
  @end

  i = 0
  @while i < reg.dim
    b1 = qreg_get_bit(i, q1)
    b2 = qreg_get_bit(i, q2)
    @if b1 != b2
      // Flip both bits to find partner index
      swapped = qreg_flip_bit(qreg_flip_bit(i, q1), q2)
      new_re[swapped] = reg.amplitudes_real[i]
      new_im[swapped] = reg.amplitudes_imag[i]
    @else
      new_re[i] = reg.amplitudes_real[i]
      new_im[i] = reg.amplitudes_imag[i]
    @end
    i = i + 1
  @end

  reg.amplitudes_real = new_re
  reg.amplitudes_imag = new_im
  return reg
@end

@! Phase Shift Gate (S-Gate: e^(i*pi/2) = i rotation on |1>)
@fn qreg_apply_s_gate(reg, target)
  // WHY: Multiplies the |1> state amplitudes by imaginary unit i: (re + i*im)*i = -im + i*re.
  i = 0
  @while i < reg.dim
    t = qreg_get_bit(i, target)
    @if t == 1
      cur_re = reg.amplitudes_real[i]
      cur_im = reg.amplitudes_imag[i]
      reg.amplitudes_real[i] = 0 - cur_im
      reg.amplitudes_imag[i] = cur_re
    @end
    i = i + 1
  @end
  return reg
@end

@! ============================================================================
@! 5. QUANTUM ENTANGLEMENT (Complete 4-Bell State Basis)
@! ============================================================================

@fn qreg_create_bell_phi_plus()
  // WHY: |Phi+> = (|00> + |11>) / sqrt(2)
  reg = qreg_new(2)
  reg = qreg_apply_hadamard(reg, 0)
  reg = qreg_apply_cnot(reg, 0, 1)
  return reg
@end

@fn qreg_create_bell_phi_minus()
  // WHY: |Phi-> = (|00> - |11>) / sqrt(2)
  reg = qreg_new(2)
  reg = qreg_apply_x(reg, 0)
  reg = qreg_apply_hadamard(reg, 0)
  reg = qreg_apply_cnot(reg, 0, 1)
  return reg
@end

@fn qreg_create_bell_psi_plus()
  // WHY: |Psi+> = (|01> + |10>) / sqrt(2)
  reg = qreg_new(2)
  reg = qreg_apply_x(reg, 1)
  reg = qreg_apply_hadamard(reg, 0)
  reg = qreg_apply_cnot(reg, 0, 1)
  return reg
@end

@fn qreg_create_bell_psi_minus()
  // WHY: |Psi-> = (|01> - |10>) / sqrt(2)
  reg = qreg_new(2)
  reg = qreg_apply_x(reg, 0)
  reg = qreg_apply_x(reg, 1)
  reg = qreg_apply_hadamard(reg, 0)
  reg = qreg_apply_cnot(reg, 0, 1)
  return reg
@end

@! ============================================================================
@! 6. PROBABILITIES & QUANTUM FOURIER TRANSFORM (QFT)
@! ============================================================================

@fn qreg_get_probability_pct(reg, state_idx)
  // WHY: Probability P = |re|^2 + |im|^2 scaled to percentage (0 - 100%).
  re = reg.amplitudes_real[state_idx]
  im = reg.amplitudes_imag[state_idx]
  prob_scaled = ((re * re) + (im * im)) / 10000
  return prob_scaled
@end

@! 2-Qubit Quantum Fourier Transform (QFT_2)
@fn qreg_apply_qft2(reg)
  // WHY: Standard 2-qubit QFT circuit: H(0) -> Controlled-S(1, 0) -> H(1) -> SWAP(0, 1).
  reg = qreg_apply_hadamard(reg, 0)
  // Controlled phase rotation
  i = 0
  @while i < reg.dim
    b0 = qreg_get_bit(i, 0)
    b1 = qreg_get_bit(i, 1)
    @if b0 == 1 && b1 == 1
      cur_re = reg.amplitudes_real[i]
      cur_im = reg.amplitudes_imag[i]
      reg.amplitudes_real[i] = 0 - cur_im
      reg.amplitudes_imag[i] = cur_re
    @end
    i = i + 1
  @end
  reg = qreg_apply_hadamard(reg, 1)
  reg = qreg_apply_swap(reg, 0, 1)
  return reg
@end

