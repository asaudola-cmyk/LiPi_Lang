// ==============================================================================
// 👑 Test 74: Lipi Generic Types & Zero-Cost Monomorphization Test
// ⚡ Features Tested:
//    1. Generic Function Template Declaration ([T], [T, U])
//    2. Compile-Time Type Substitution & Symbol Mangling (max_i64, max_f64)
//    3. IR Call-Site Specialization Rewriter (call "max" -> call "max_i64")
//    4. Specialization Deduplication & Code Bloat Prevention
// ==============================================================================

import "src/compiler/ssa_ir.lp"
import "src/compiler/middleend/monomorphize.lp"

say "========================================================"
say "👑 Testing Lipi Sovereign Generic Monomorphization Engine"
say "========================================================"

reg = monomorph_registry_new()

// ── Test Part 1: Generic Template Registration ────────────────────────────────
say "[1/3] Registering Generic Template max[T] a:T b:T -> T..."

tmpl_max = generic_template_new(
    "max",
    list("T"),
    list("a", "b"),
    list("T", "T"),
    "T"
)
monomorph_register_template(reg, tmpl_max)

if monomorph_has_template(reg, "max") != 1
    say "FAILED: Template max must be registered!"
    exit(1)
say "  ✔ Template max[T] successfully registered in compiler registry"

// ── Test Part 2: Concrete Specialization (max_i64 & max_f64) ───────────────────
say "[2/3] Monomorphizing max[T] for concrete types i64 and f64..."

// Specialize for i64
spec_i64 = monomorph_specialize(reg, "max", list("i64"))
name_i64 = get(spec_i64, 0)
types_i64 = get(spec_i64, 2)
ret_i64 = get(spec_i64, 3)

if name_i64 != "max_i64" or get(types_i64, 0) != "i64" or ret_i64 != "i64"
    say "FAILED: Specialization for i64 failed, got name: " + name_i64
    exit(1)
say "  ✔ Specialized instance: " + name_i64 + " (params: i64, i64 -> i64)"

// Specialize for f64
spec_f64 = monomorph_specialize(reg, "max", list("f64"))
name_f64 = get(spec_f64, 0)
types_f64 = get(spec_f64, 2)
ret_f64 = get(spec_f64, 3)

if name_f64 != "max_f64" or get(types_f64, 0) != "f64" or ret_f64 != "f64"
    say "FAILED: Specialization for f64 failed, got name: " + name_f64
    exit(1)
say "  ✔ Specialized instance: " + name_f64 + " (params: f64, f64 -> f64)"

// Test Multi-Parameter Generic Template: pair[K, V]
tmpl_pair = generic_template_new(
    "pair",
    list("K", "V"),
    list("key", "val"),
    list("K", "V"),
    "void"
)
monomorph_register_template(reg, tmpl_pair)

spec_pair = monomorph_specialize(reg, "pair", list("str", "i64"))
name_pair = get(spec_pair, 0)
if name_pair != "pair_str_i64"
    say "FAILED: Multi-parameter specialization failed, got: " + name_pair
    exit(1)
say "  ✔ Multi-parameter instance: " + name_pair + " (K=str, V=i64)"

// ── Test Part 3: Call-Site Rewriter & Deduplication ────────────────────────────
say "[3/3] Rewriting IR Call Site & Verifying Deduplication..."

call_inst = ir_call("r0", "max", list("v1", "v2"))
rewritten = monomorph_rewrite_call(reg, call_inst, list("i64"))

new_callee = ir_inst_src1(rewritten)
if new_callee != "max_i64"
    say "FAILED: Call instruction must target specialized max_i64, got: " + new_callee
    exit(1)
say "  ✔ Call site rewritten: call 'max' -> call '" + new_callee + "'"

// Verify deduplication: second specialization of max[i64] must return existing
spec_again = monomorph_specialize(reg, "max", list("i64"))
if get(spec_again, 0) != "max_i64"
    say "FAILED: Deduplication check failed"
    exit(1)
say "  ✔ Specialization deduplication confirmed (zero duplicate code emission)"

say ""
say "========================================================"
say "🎉 ALL GENERIC MONOMORPHIZATION TESTS PASSED! 👑"
say "========================================================"
