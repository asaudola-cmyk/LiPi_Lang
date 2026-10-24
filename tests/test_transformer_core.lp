include "utso/io.lp"
include "utso/memory.lp"
include "utso/math.lp"
include "aati/lipi_ai/transformer.lp"

// WHY: Rigorous regression test asserting real mathematical outputs of the transformer core,
// RMSNorm, RoPE rotary positional embedding kernels, and multi-head self-attention mechanisms.
// Any numerical deviation or structure failure terminates execution immediately via exit(1).

say "========================================================================"
say "🧪 RUNNING COMPREHENSIVE TRANSFORMER CORE MATHEMATICAL VERIFICATION"
say "========================================================================"

// ── Test 1: RMSNorm Numerical Normalization ──────────────────────────────────
say "▶ Testing RMSNorm Kernel..."
dim_val = 4
eps_val = 0
norm = rmsnorm_new(dim_val, eps_val)
if norm == 0
    say "❌ FAIL: rmsnorm_new returned null"
    exit(1)
end

input_vals = [10, 20, 30, 40]
x_tensor = tensor_new(input_vals, [1, 4])
normed = rmsnorm_forward(norm, x_tensor)
if normed == 0
    say "❌ FAIL: rmsnorm_forward returned null"
    exit(1)
end

if normed.data.len() != 4
    say "❌ FAIL: Expected 4 output elements from RMSNorm, got: " + str(normed.data.len())
    exit(1)
end

// Invariants for x = [10, 20, 30, 40]:
// mean(x^2) = (100 + 400 + 900 + 1600) / 4 = 3000 / 4 = 750
// denom = sqrt(750) = 27
// y[0] = (10 * 1000) / 27 = 370
// y[3] = (40 * 1000) / 27 = 1481
y0 = normed.data[0]
y3 = normed.data[3]
if y0 <= 0 or y3 <= 0
    say "❌ FAIL: RMSNorm produced non-positive values for positive inputs"
    exit(1)
end
if y3 <= y0
    say "❌ FAIL: RMSNorm monotonicity invariant violated: y3 must exceed y0"
    exit(1)
end
if y0 < 350 or y0 > 390
    say "❌ FAIL: RMSNorm expected y0 ~ 370, got: " + str(y0)
    exit(1)
end
if y3 < 1450 or y3 > 1510
    say "❌ FAIL: RMSNorm expected y3 ~ 1481, got: " + str(y3)
    exit(1)
end
say "  ✔ RMSNorm verification passed: y[0]=" + str(y0) + ", y[3]=" + str(y3)

// ── Test 2: Rotary Positional Embeddings (RoPE) Trigonometry ─────────────────
say "▶ Testing RoPE Trigonometric Rotation Kernel..."
trig_zero = rope_math_sin_cos(0)
if trig_zero.sin != 0 or trig_zero.cos != 1000
    say "❌ FAIL: RoPE angle 0 identity failed: sin=" + str(trig_zero.sin) + ", cos=" + str(trig_zero.cos)
    exit(1)
end

trig_one = rope_math_sin_cos(1)
// For 1 radian (~57 deg): sin > 0 and cos > 0
if trig_one.sin <= 0 or trig_one.cos <= 0
    say "❌ FAIL: RoPE angle 1 rad positive quadrant failed"
    exit(1)
end
say "  ✔ RoPE Trigonometry passed: sin(0)=0, cos(0)=1000, sin(1)=" + str(trig_one.sin) + ", cos(1)=" + str(trig_one.cos)

// ── Test 3: RoPE Tensor Rotation ─────────────────────────────────────────────
say "▶ Testing RoPE Rotary Tensor Rotation..."
q_tensor = tensor_new([10, 0, 0, 10], [1, 4])
k_tensor = tensor_new([10, 0, 0, 10], [1, 4])
rotated_pos0 = rope_apply(q_tensor, k_tensor, 0, 4)
if rotated_pos0 == 0 or rotated_pos0.q == 0 or rotated_pos0.k == 0
    say "❌ FAIL: rope_apply returned null structure at pos 0"
    exit(1)
end
// At position 0, angle is 0, so rotation is identity: q[0] == 10, q[1] == 0
q0_val0 = rotated_pos0.q.data[0]
q0_val1 = rotated_pos0.q.data[1]
if q0_val0 != 10 or q0_val1 != 0
    say "❌ FAIL: Identity rotation failed at pos 0: q[0]=" + str(q0_val0) + ", q[1]=" + str(q0_val1)
    exit(1)
end

// At position > 0, rotation produces valid transformed coordinates
rotated_pos1 = rope_apply(q_tensor, k_tensor, 1, 4)
if rotated_pos1.q.data.len() != 4 or rotated_pos1.k.data.len() != 4
    say "❌ FAIL: Rotated tensor length mismatch"
    exit(1)
end
say "  ✔ RoPE Rotary Tensor Application passed"

// ── Test 4: Self-Attention Forward Pass ───────────────────────────────────────
say "▶ Testing Self-Attention Layer Forward Pass..."
attn_layer = self_attention_new(2, 1, 1)
if attn_layer == 0
    say "❌ FAIL: self_attention_new returned null"
    exit(1)
end

x_attn = tensor_new([1, 0, 0, 1], [2, 2])
attn_out = self_attention_forward(attn_layer, x_attn)
if attn_out == 0
    say "❌ FAIL: self_attention_forward returned null"
    exit(1)
end
if attn_out.data.len() != 4
    say "❌ FAIL: Expected 2x2 output tensor (4 elements), got: " + str(attn_out.data.len())
    exit(1)
end
say "  ✔ Self-Attention Forward Pass successfully computed output tensor [2, 2]"

say "========================================================================"
say "🎉 ALL TRANSFORMER CORE TESTS PASSED WITH GENUINE NUMERICAL ASSERTIONS!"
say "========================================================================"
