// ==============================================================================
// 👑 LIPI SOVEREIGN GENERIC MONOMORPHIZATION ENGINE (Zero-Cost Generics)
// ⚡ 100% Pure Lipi | 0% C | 0% LLVM | Zero Runtime Boxing Overhead
// 🏛️ File: src/compiler/middleend/monomorphize.lp
//
// WHY: Dynamic language polymorphism relies on heap-allocated boxed objects and
//      expensive dictionary/vtable lookups on every function call.
//      Monomorphization specializes generic templates (e.g., fn max[T] a b) at
//      compile-time for each concrete type argument (max_i64, max_f64).
//      The emitted machine code runs at direct bare-metal CPU speed with 0% runtime cost.
// ==============================================================================

import "src/compiler/ssa_ir.lp"

// ── 1. Generic Template Data Structure ─────────────────────────────────────────
// A Generic Template is a 5-element list:
//   [0]: name         (string: base template name, e.g. "max")
//   [1]: type_params  (list of string: generic type parameter names, e.g. ["T"])
//   [2]: params       (list of string: parameter names)
//   [3]: param_types  (list of string: parameter type expressions, e.g. ["T", "T"])
//   [4]: ret_type     (string: return type expression, e.g. "T")

fn generic_template_new name type_params params param_types ret_type
    t = list()
    push(t, name)
    push(t, type_params)
    push(t, params)
    push(t, param_types)
    push(t, ret_type)
    return t

fn generic_template_name t = get(t, 0)
fn generic_template_type_params t = get(t, 1)
fn generic_template_params t = get(t, 2)
fn generic_template_param_types t = get(t, 3)
fn generic_template_ret_type t = get(t, 4)

// ── 2. Specialization Registry ────────────────────────────────────────────────
// WHY: Caches generated specializations so identical type instantiations (e.g. max[i64])
//      are emitted exactly once, preventing code bloat while ensuring deduplicated symbols.

fn monomorph_registry_new
    reg = list()
    push(reg, ssa_map_new()) // 0: templates (name -> GenericTemplate)
    push(reg, ssa_map_new()) // 1: specializations (mangled_name -> 1)
    push(reg, list())        // 2: specialized_functions_list
    return reg

fn monomorph_register_template reg template
    t_map = get(reg, 0)
    name = generic_template_name(template)
    ssa_map_set(t_map, name, template)

fn monomorph_has_template reg name
    t_map = get(reg, 0)
    return ssa_map_has(t_map, name)

// ── 3. Symbol Mangling for Specialized Instances ──────────────────────────────
// WHY: Produces deterministic, collision-free native symbols (e.g. "max_i64", "pair_str_i64")
fn monomorph_mangle_name base_name concrete_types
    mangled = base_name
    i = 0
    tlen = len(concrete_types)
    while i < tlen
        t = get(concrete_types, i)
        mangled = mangled + "_" + t
        i = i + 1
    return mangled

// ── 4. Type Substitution & Specialization Engine ──────────────────────────────
// Returns a 4-element Specialized Function representation:
//   [0]: specialized_name (string, e.g. "max_i64")
//   [1]: concrete_params  (list of string: param names)
//   [2]: concrete_types   (list of string: concrete types, e.g. ["i64", "i64"])
//   [3]: concrete_ret_ty  (string: concrete return type, e.g. "i64")

fn monomorph_specialize reg template_name concrete_type_args
    t_map = get(reg, 0)
    spec_map = get(reg, 1)
    spec_list = get(reg, 2)

    template = ssa_map_get(t_map, template_name, 0)
    if template == 0
        return 0

    mangled = monomorph_mangle_name(template_name, concrete_type_args)

    // Check if already specialized
    if ssa_map_get(spec_map, mangled, 0) == 1
        // Already specialized, return existing descriptor
        i = 0
        while i < len(spec_list)
            spec_inst = get(spec_list, i)
            if get(spec_inst, 0) == mangled
                return spec_inst
            i = i + 1

    // Build type substitution map: e.g. {"T" -> "i64"}
    type_params = generic_template_type_params(template)
    subst_map = ssa_map_new()
    tp_i = 0
    tplen = len(type_params)
    while tp_i < tplen
        tp_name = get(type_params, tp_i)
        conc_ty = "unknown"
        if tp_i < len(concrete_type_args)
            conc_ty = get(concrete_type_args, tp_i)
        ssa_map_set(subst_map, tp_name, conc_ty)
        tp_i = tp_i + 1

    // Substitute parameter types
    param_types = generic_template_param_types(template)
    conc_param_types = list()
    p_i = 0
    plen = len(param_types)
    while p_i < plen
        pty = get(param_types, p_i)
        resolved_ty = ssa_map_get(subst_map, pty, pty)
        push(conc_param_types, resolved_ty)
        p_i = p_i + 1

    // Substitute return type
    ret_ty = generic_template_ret_type(template)
    conc_ret_ty = ssa_map_get(subst_map, ret_ty, ret_ty)

    // Construct specialized instance
    spec = list()
    push(spec, mangled)
    push(spec, generic_template_params(template))
    push(spec, conc_param_types)
    push(spec, conc_ret_ty)

    // Register into cache
    ssa_map_set(spec_map, mangled, 1)
    push(spec_list, spec)

    return spec

// ── 5. Concrete Call Site Rewriter ────────────────────────────────────────────
// WHY: At each call site `res = call "max", args`, if "max" is generic,
//      rewrites the call target to the specialized symbol (e.g. "max_i64").
fn monomorph_rewrite_call reg call_inst arg_types
    dest = ir_inst_dest(call_inst)
    callee = ir_inst_src1(call_inst)
    args = ir_inst_extra(call_inst)

    if monomorph_has_template(reg, callee) == 1
        spec = monomorph_specialize(reg, callee, arg_types)
        specialized_name = get(spec, 0)
        // Return updated IR instruction targeting specialized function
        return ir_call(dest, specialized_name, args)

    return call_inst
