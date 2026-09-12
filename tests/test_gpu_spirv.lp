// ==============================================================================
// 🧪 LIPI TEST: Sovereign Silicon GPU Compute & SPIR-V Binary Emitter Test Suite
// ⚡ Tests Khronos SPIR-V 1.0/1.5 header, dynamic opcode word count (Trap 4 defense),
//    Vector Add & GEMM compute kernels, binary serialization, syscall disk I/O,
//    and reference CPU compute engines.
// ==============================================================================

include "universe/gpu/spirv_native.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi Sovereign Silicon GPU & SPIR-V Emitter"
say "========================================================"

// ── Test 1: Khronos SPIR-V Binary Header Specification ────────────────────────
say "[1/6] Testing Khronos SPIR-V Binary Header Specification..."
b1 = spirv_builder_new()
spirv_emit_header(b1)
words1 = get(b1, 0)

assert_eq(len(words1), 5, "Header contains exactly 5 32-bit words")
assert_eq(get(words1, 0), 119734787, "Word 0: Khronos Magic 0x07230203 (119734787)")
assert_eq(get(words1, 1), 65536, "Word 1: SPIR-V 1.0 Version (65536)")
assert_eq(get(words1, 2), 1769473, "Word 2: Lipi Sovereign Generator ID (1769473)")
assert_eq(get(words1, 3), 1, "Word 3: Initial Bound ID (1)")
assert_eq(get(words1, 4), 0, "Word 4: Reserved Schema (0)")

// ── Test 2: Dynamic Opcode Word-Count Calculation (Trap 4 Defense) ─────────────
say "[2/6] Testing Dynamic Opcode Word-Count Calculation (Trap 4 Defense)..."
// Instruction with 0 operands -> word count = 1
ops_0 = list()
spirv_emit_inst(b1, OP_RETURN, ops_0)
w_ret = get(words1, 5)
wc_ret = w_ret / 65536
op_ret = w_ret % 65536
assert_eq(wc_ret, 1, "OpReturn: WordCount dynamically calculated as 1 (0 operands + 1)")
assert_eq(op_ret, 253, "OpReturn: Opcode is OP_RETURN (253)")

// Instruction with 3 operands -> word count = 4
ops_3 = list()
push(ops_3, 10)
push(ops_3, 20)
push(ops_3, 30)
spirv_emit_inst(b1, OP_IADD, ops_3)
w_add = get(words1, 6)
wc_add = w_add / 65536
op_add = w_add % 65536
assert_eq(wc_add, 4, "OpIAdd: WordCount dynamically calculated as 4 (3 operands + 1)")
assert_eq(op_add, 128, "OpIAdd: Opcode is OP_IADD (128)")

// Verify operands are packed correctly
assert_eq(get(words1, 7), 10, "Operand 0 correctly placed at word 7")
assert_eq(get(words1, 8), 20, "Operand 1 correctly placed at word 8")
assert_eq(get(words1, 9), 30, "Operand 2 correctly placed at word 9")

// ── Test 3: Vector Addition Compute Shader Kernel ─────────────────────────────
say "[3/6] Testing Vector Addition Compute Shader Generation..."
b_vadd = spirv_build_vector_add_kernel()
vadd_words = get(b_vadd, 0)
vadd_len = len(vadd_words)

assert_eq(get(vadd_words, 0), 119734787, "Vector Add: SPIR-V Magic valid")
if vadd_len < 40
    say "  ❌ FAILED: Vector Add kernel too small (" + str(vadd_len) + " words)"
    exit(1)
say "  ✔ Vector Add kernel generated (" + str(vadd_len) + " words emitted)"

// Check final bound in header
final_bound = get(vadd_words, 3)
if final_bound < 10
    say "  ❌ FAILED: Invalid bound in header (" + str(final_bound) + ")"
    exit(1)
say "  ✔ Header bound dynamically updated to " + str(final_bound)

// ── Test 4: Matrix Multiplication (GEMM) Compute Shader Kernel ────────────────
say "[4/6] Testing GEMM Matrix Multiplication Shader Generation..."
b_gemm = spirv_build_gemm_kernel()
gemm_words = get(b_gemm, 0)
gemm_len = len(gemm_words)

assert_eq(get(gemm_words, 0), 119734787, "GEMM: SPIR-V Magic valid")
if gemm_len < 30
    say "  ❌ FAILED: GEMM kernel too small (" + str(gemm_len) + " words)"
    exit(1)
say "  ✔ GEMM kernel generated (" + str(gemm_len) + " words emitted)"

// ── Test 5: Binary Serialization & Raw Syscall Disk Emitter ───────────────────
say "[5/6] Testing Binary Serialization & Direct Syscall Disk Output..."
bytes = spirv_to_bytes(b_vadd)
expected_bytes = vadd_len * 4
assert_eq(len(bytes), expected_bytes, "Serialization produced exact 4-bytes-per-word (" + str(expected_bytes) + " bytes)")

// Little-endian check of magic: 0x07230203 -> 0x03, 0x02, 0x23, 0x07
assert_eq(get(bytes, 0), 3, "Byte 0 of magic is 0x03")
assert_eq(get(bytes, 1), 2, "Byte 1 of magic is 0x02")
assert_eq(get(bytes, 2), 35, "Byte 2 of magic is 0x23 (35)")
assert_eq(get(bytes, 3), 7, "Byte 3 of magic is 0x07")

// Write directly to disk via raw Linux syscalls
out_file = "bin/test_kernel.spv"
written = spirv_write_binary(b_vadd, out_file)
assert_eq(written, expected_bytes, "Direct kernel SYS_write wrote " + str(expected_bytes) + " bytes to " + out_file)

// ── Test 6: CPU Reference Mathematics Validation ──────────────────────────────
say "[6/6] Testing CPU Reference Compute Verification..."
// Vector Addition: [10, 20, 30] + [1, 2, 3] = [11, 22, 33]
v_a = list()
push(v_a, 10)
push(v_a, 20)
push(v_a, 30)

v_b = list()
push(v_b, 1)
push(v_b, 2)
push(v_b, 3)

v_c = gpu_vector_add_cpu(v_a, v_b, 3)
assert_eq(get(v_c, 0), 11, "v_c[0] == 11")
assert_eq(get(v_c, 1), 22, "v_c[1] == 22")
assert_eq(get(v_c, 2), 33, "v_c[2] == 33")

// GEMM: [1, 2; 3, 4] * [1, 0; 0, 1] (Identity matrix multiplication)
m_a = list()
push(m_a, 1)
push(m_a, 2)
push(m_a, 3)
push(m_a, 4)

m_identity = list()
push(m_identity, 1)
push(m_identity, 0)
push(m_identity, 0)
push(m_identity, 1)

m_res = gpu_gemm_cpu(m_a, m_identity, 2, 2, 2)
assert_eq(get(m_res, 0), 1, "GEMM Identity: m_res[0] == 1")
assert_eq(get(m_res, 1), 2, "GEMM Identity: m_res[1] == 2")
assert_eq(get(m_res, 2), 3, "GEMM Identity: m_res[2] == 3")
assert_eq(get(m_res, 3), 4, "GEMM Identity: m_res[3] == 4")

say "========================================================"
say "PASS: Lipi Sovereign Silicon GPU & SPIR-V Emitter Verified 100%!"
say "========================================================"
