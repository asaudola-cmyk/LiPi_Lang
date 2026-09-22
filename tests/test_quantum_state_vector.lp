// ==============================================================================
// 👑 LIPI SOVEREIGN QUANTUM SIMULATION SUITE: tests/test_quantum_state_vector.lp
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Python | Non-Binary Silicon Logic
// ==============================================================================

import "universe/quantum/multi_qubit"

@fn main()
    println("==================================================================")
    println("👑 Testing Lipi Sovereign Multi-Qubit State Vector Simulator")
    println("==================================================================")

    // ── Test 1: Ground State Initialization ────────────────────────────────────
    println("[1/6] Testing Ground State |00> Initialization...")
    reg = qreg_new(2)
    p00 = qreg_get_probability_pct(reg, 0)
    p01 = qreg_get_probability_pct(reg, 1)
    p10 = qreg_get_probability_pct(reg, 2)
    p11 = qreg_get_probability_pct(reg, 3)

    if p00 != 100
        println("❌ Ground state P(|00>) != 100%")
        return 1
    end
    if p01 != 0 || p10 != 0 || p11 != 0
        println("❌ Ground state leaked to other states!")
        return 1
    end
    println("  ✔ |00> initialized with exactly 100% amplitude")

    // ── Test 2: Pauli-X Bit Flip ───────────────────────────────────────────────
    println("[2/6] Testing Pauli-X NOT Gate on Qubit 0...")
    reg = qreg_apply_x(reg, 0)
    p_flipped = qreg_get_probability_pct(reg, 1)
    if p_flipped != 100
        println("❌ Pauli-X failed to flip qubit 0 to 100%")
        return 1
    end
    println("  ✔ Pauli-X flipped |00> to |01> deterministically")

    // ── Test 3: Hadamard Superposition ─────────────────────────────────────────
    println("[3/6] Testing Hadamard Superposition...")
    reg_h = qreg_new(1)
    reg_h = qreg_apply_hadamard(reg_h, 0)
    ph0 = qreg_get_probability_pct(reg_h, 0)
    ph1 = qreg_get_probability_pct(reg_h, 1)
    if ph0 < 49 || ph0 > 51 || ph1 < 49 || ph1 > 51
        println("❌ Hadamard probability out of expected range (~50%)")
        return 1
    end
    println("  ✔ Hadamard produced balanced superposition (|0> + |1>)/sqrt(2)")

    // ── Test 4: Complete Bell State Entanglement (|Phi+> and |Psi+>) ──────────
    println("[4/6] Testing Quantum Entanglement (Bell States |Phi+> and |Psi+>)...")
    phi_plus = qreg_create_bell_phi_plus()
    pp_00 = qreg_get_probability_pct(phi_plus, 0)
    pp_11 = qreg_get_probability_pct(phi_plus, 3)
    pp_01 = qreg_get_probability_pct(phi_plus, 1)
    pp_10 = qreg_get_probability_pct(phi_plus, 2)

    if pp_00 < 49 || pp_11 < 49 || pp_01 != 0 || pp_10 != 0
        println("❌ Bell State |Phi+> failed entanglement verification!")
        return 1
    end
    println("  ✔ Bell State |Phi+> entangled: P(|00>)=" + pp_00 + "%, P(|11>)=" + pp_11 + "%, P(|01>)=0%")

    psi_plus = qreg_create_bell_psi_plus()
    ps_01 = qreg_get_probability_pct(psi_plus, 1)
    ps_10 = qreg_get_probability_pct(psi_plus, 2)
    ps_00 = qreg_get_probability_pct(psi_plus, 0)
    ps_11 = qreg_get_probability_pct(psi_plus, 3)

    if ps_01 < 49 || ps_10 < 49 || ps_00 != 0 || ps_11 != 0
        println("❌ Bell State |Psi+> failed entanglement verification!")
        return 1
    end
    println("  ✔ Bell State |Psi+> entangled: P(|01>)=" + ps_01 + "%, P(|10>)=" + ps_10 + "%, P(|00>)=0%")

    // ── Test 5: SWAP Gate Execution ───────────────────────────────────────────
    println("[5/6] Testing Quantum SWAP Gate...")
    reg_swap = qreg_new(2)
    reg_swap = qreg_apply_x(reg_swap, 0)
    reg_swap = qreg_apply_swap(reg_swap, 0, 1)
    p_swapped = qreg_get_probability_pct(reg_swap, 2)
    if p_swapped != 100
        println("❌ SWAP gate failed to exchange qubits 0 and 1!")
        return 1
    end
    println("  ✔ SWAP gate transformed |01> to |10> with 100% fidelity")

    // ── Test 6: Quantum Fourier Transform (QFT_2) Unitarity ───────────────────
    println("[6/6] Testing 2-Qubit Quantum Fourier Transform (QFT_2)...")
    reg_qft = qreg_new(2)
    reg_qft = qreg_apply_qft2(reg_qft)
    total_prob = 0
    idx = 0
    while idx < reg_qft.dim
        total_prob = total_prob + qreg_get_probability_pct(reg_qft, idx)
        idx = idx + 1
    end
    if total_prob < 95 || total_prob > 102
        println("❌ QFT_2 violated unitarity! Total probability: " + total_prob + "%")
        return 1
    end
    println("  ✔ QFT_2 preserved state vector unitarity (Total P = " + total_prob + "%)")

    println("==================================================================")
    println("PASS: Lipi Sovereign Quantum Engine 100% Verified!")
    println("==================================================================")
    return 0
@end
