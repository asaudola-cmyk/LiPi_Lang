// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: TYPE UNIFICATION & EQUIVALENCE CHECKER (type_unify.lp)
// Module: src/compiler/semantics/type_unify.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Type systems require mathematical guarantees that:
// 1. Types assigned to variables or passed to functions are strictly sound.
// 2. Generic type variables during inference can be unified without introducing
//    cyclic infinite types (e.g. `T = []T`).
// 3. Subtyping relations (such as numeric widening, pointer const-decay, and `any`
//    top-type boxing) are deterministically governed.
//
// ALGORITHMS IMPLEMENTED:
// - Robinson First-Order Unification with Martelli-Montanari simplification rules.
// - Occurs-Check to detect and reject recursive / paradoxical type equations.
// - Coercion and assignability lattices (Top: `any`, Bottom: `never`).
// - Sovereign Prefixed Fields (`se_`, `subst_`, `ty_`) eliminate all collisions.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/semantics/type_def"

// ── 1. TYPE SUBSTITUTION ENVIRONMENT ─────────────────────────────────────────

@struct SubstEntry
  se_var_id: i64
  se_target_type_id: i64
@end

@struct TypeSubst
  subst_entries: array
@end

@fn subst_new()
  // WHY: Allocates a fresh substitution map with named constructor
  s = TypeSubst()
  s.subst_entries = []
  return s
@end

@fn subst_bind(subst, var_id, target_type_id)
  // WHY: Records a solved type equation: 'var_id := target_type_id
  @if subst == 0 || var_id <= 0 return 0 @end

  i = 0
  n = subst.subst_entries.len()
  @while i < n
    entry = subst.subst_entries[i]
    @if entry.se_var_id == var_id
      entry.se_target_type_id = target_type_id
      return 1
    @end
    i = i + 1
  @end

  new_entry = SubstEntry()
  new_entry.se_var_id = var_id
  new_entry.se_target_type_id = target_type_id
  subst.subst_entries = subst.subst_entries.push(new_entry)
  return 1
@end

@fn subst_lookup(subst, var_id)
  @if subst == 0 || var_id <= 0 return 0 @end

  i = 0
  n = subst.subst_entries.len()
  @while i < n
    entry = subst.subst_entries[i]
    @if entry.se_var_id == var_id
      return entry.se_target_type_id
    @end
    i = i + 1
  @end

  return 0
@end

@fn subst_apply(subst, reg, type_id)
  // WHY: Normalizes a type by chasing all type variable substitutions to a fixed point
  @if subst == 0 || reg == 0 || type_id <= 0 return type_id @end

  curr_id = type_id
  visited_depth = 0
  MAX_DEPTH = 32

  @while visited_depth < MAX_DEPTH
    ty = type_registry_get(reg, curr_id)
    @if ty == 0 return curr_id @end

    @if ty.ty_kind == TYPE_KIND_GENERIC_VAR()
      bound_id = subst_lookup(subst, ty.ty_generic_var_id)
      @if bound_id == 0 || bound_id == curr_id
        return curr_id
      @end
      curr_id = bound_id
      visited_depth = visited_depth + 1
    @else
      return curr_id
    @end
  @end

  return curr_id
@end

// ── 2. OCCURS CHECK (PREVENTS RECURSIVE / CYCLIC TYPES) ──────────────────────

@fn type_occurs_in(subst, reg, var_id, type_id)
  // WHY: Validates that variable `var_id` does not appear inside `type_id`.
  resolved_id = subst_apply(subst, reg, type_id)
  ty = type_registry_get(reg, resolved_id)
  @if ty == 0 return 0 @end

  @if ty.ty_kind == TYPE_KIND_GENERIC_VAR()
    @if ty.ty_generic_var_id == var_id return 1 @end
    return 0
  @end

  @if ty.ty_kind == TYPE_KIND_ARRAY() || ty.ty_kind == TYPE_KIND_POINTER()
    return type_occurs_in(subst, reg, var_id, ty.ty_elem_type_id)
  @end

  @if ty.ty_kind == TYPE_KIND_FUNCTION()
    @if type_occurs_in(subst, reg, var_id, ty.ty_ret_type_id) == 1 return 1 @end
    i = 0
    n = ty.ty_param_types.len()
    @while i < n
      @if type_occurs_in(subst, reg, var_id, ty.ty_param_types[i]) == 1 return 1 @end
      i = i + 1
    @end
  @end

  return 0
@end

// ── 3. STRICT EQUALITY CHECKER ───────────────────────────────────────────────

@fn type_is_equal(reg, t1_id, t2_id)
  @if t1_id == t2_id return 1 @end

  t1 = type_registry_get(reg, t1_id)
  t2 = type_registry_get(reg, t2_id)
  @if t1 == 0 || t2 == 0 return 0 @end

  @if t1.ty_kind != t2.ty_kind return 0 @end

  // Primitive types with matching kind are equal
  @if t1.ty_kind >= TYPE_KIND_VOID() && t1.ty_kind <= TYPE_KIND_NEVER()
    return 1
  @end

  // Struct equality is nominal in LiPi
  @if t1.ty_kind == TYPE_KIND_STRUCT()
    @if str_eq(t1.ty_name, t2.ty_name) == 1 return 1 @end
    return 0
  @end

  // Array equality requires matching element type and bounds
  @if t1.ty_kind == TYPE_KIND_ARRAY()
    @if t1.ty_array_len != t2.ty_array_len return 0 @end
    return type_is_equal(reg, t1.ty_elem_type_id, t2.ty_elem_type_id)
  @end

  // Pointer equality requires matching target type and mutability
  @if t1.ty_kind == TYPE_KIND_POINTER()
    @if t1.ty_is_mut != t2.ty_is_mut return 0 @end
    return type_is_equal(reg, t1.ty_elem_type_id, t2.ty_elem_type_id)
  @end

  // Function signature equality
  @if t1.ty_kind == TYPE_KIND_FUNCTION()
    @if t1.ty_param_types.len() != t2.ty_param_types.len() return 0 @end
    @if type_is_equal(reg, t1.ty_ret_type_id, t2.ty_ret_type_id) == 0 return 0 @end
    i = 0
    n = t1.ty_param_types.len()
    @while i < n
      @if type_is_equal(reg, t1.ty_param_types[i], t2.ty_param_types[i]) == 0 return 0 @end
      i = i + 1
    @end
    return 1
  @end

  return 0
@end

// ── 4. ASSIGNABILITY & SUBTYPING LATTICE ──────────────────────────────────────

@fn type_is_assignable(reg, target_id, src_id)
  @if target_id == src_id return 1 @end
  @if target_id == TYPE_ID_ANY() return 1 @end
  @if src_id == TYPE_ID_NEVER() return 1 @end

  @if type_is_equal(reg, target_id, src_id) == 1 return 1 @end

  t_target = type_registry_get(reg, target_id)
  t_src = type_registry_get(reg, src_id)
  @if t_target == 0 || t_src == 0 return 0 @end

  // Numeric widening: byte -> i64
  @if t_target.ty_kind == TYPE_KIND_I64() && t_src.ty_kind == TYPE_KIND_BYTE() return 1 @end

  // Numeric widening: byte -> f64, i64 -> f64
  @if t_target.ty_kind == TYPE_KIND_F64() && (t_src.ty_kind == TYPE_KIND_I64() || t_src.ty_kind == TYPE_KIND_BYTE()) return 1 @end

  // Slice coercion: Fixed array [T; N] can be passed to dynamic slice []T
  @if t_target.ty_kind == TYPE_KIND_ARRAY() && t_target.ty_array_len == -1
    @if t_src.ty_kind == TYPE_KIND_ARRAY()
      return type_is_assignable(reg, t_target.ty_elem_type_id, t_src.ty_elem_type_id)
    @end
  @end

  // Pointer const-decay: *mut T can be assigned to *const T
  @if t_target.ty_kind == TYPE_KIND_POINTER() && t_src.ty_kind == TYPE_KIND_POINTER()
    @if t_target.ty_is_mut == 0 && t_src.ty_is_mut == 1
      return type_is_equal(reg, t_target.ty_elem_type_id, t_src.ty_elem_type_id)
    @end
  @end

  return 0
@end

// ── 5. ROBINSON FIRST-ORDER UNIFICATION ───────────────────────────────────────

@fn type_unify(reg, subst, t1_id, t2_id)
  u1_id = subst_apply(subst, reg, t1_id)
  u2_id = subst_apply(subst, reg, t2_id)

  @if u1_id == u2_id return 1 @end
  @if u1_id == TYPE_ID_ANY() || u2_id == TYPE_ID_ANY() return 1 @end

  u1 = type_registry_get(reg, u1_id)
  u2 = type_registry_get(reg, u2_id)
  @if u1 == 0 || u2 == 0 return 0 @end

  // Case 1: u1 is a type variable
  @if u1.ty_kind == TYPE_KIND_GENERIC_VAR()
    @if type_occurs_in(subst, reg, u1.ty_generic_var_id, u2_id) == 1 return 0 @end
    return subst_bind(subst, u1.ty_generic_var_id, u2_id)
  @end

  // Case 2: u2 is a type variable
  @if u2.ty_kind == TYPE_KIND_GENERIC_VAR()
    @if type_occurs_in(subst, reg, u2.ty_generic_var_id, u1_id) == 1 return 0 @end
    return subst_bind(subst, u2.ty_generic_var_id, u1_id)
  @end

  // Case 3: Both are Arrays
  @if u1.ty_kind == TYPE_KIND_ARRAY() && u2.ty_kind == TYPE_KIND_ARRAY()
    @if u1.ty_array_len != -1 && u2.ty_array_len != -1 && u1.ty_array_len != u2.ty_array_len return 0 @end
    return type_unify(reg, subst, u1.ty_elem_type_id, u2.ty_elem_type_id)
  @end

  // Case 4: Both are Pointers
  @if u1.ty_kind == TYPE_KIND_POINTER() && u2.ty_kind == TYPE_KIND_POINTER()
    return type_unify(reg, subst, u1.ty_elem_type_id, u2.ty_elem_type_id)
  @end

  // Case 5: Both are Functions
  @if u1.ty_kind == TYPE_KIND_FUNCTION() && u2.ty_kind == TYPE_KIND_FUNCTION()
    @if u1.ty_param_types.len() != u2.ty_param_types.len() return 0 @end
    @if type_unify(reg, subst, u1.ty_ret_type_id, u2.ty_ret_type_id) == 0 return 0 @end
    i = 0
    n = u1.ty_param_types.len()
    @while i < n
      @if type_unify(reg, subst, u1.ty_param_types[i], u2.ty_param_types[i]) == 0 return 0 @end
      i = i + 1
    @end
    return 1
  @end

  // Case 6: Primitives or Structs
  @if type_is_assignable(reg, u1_id, u2_id) == 1 || type_is_assignable(reg, u2_id, u1_id) == 1
    return 1
  @end

  return 0
@end

// ── 6. COMMON SUPERTYPE RESOLUTION (BRANCH MERGING) ──────────────────────────

@fn type_common_supertype(reg, t1_id, t2_id)
  @if t1_id == t2_id return t1_id @end

  @if t1_id == TYPE_ID_NEVER() return t2_id @end
  @if t2_id == TYPE_ID_NEVER() return t1_id @end

  @if t1_id == TYPE_ID_ANY() || t2_id == TYPE_ID_ANY() return TYPE_ID_ANY() @end

  @if type_is_assignable(reg, t1_id, t2_id) == 1 return t1_id @end
  @if type_is_assignable(reg, t2_id, t1_id) == 1 return t2_id @end

  // Numeric branch promotions
  @if (t1_id == TYPE_ID_I64() && t2_id == TYPE_ID_BYTE()) || (t1_id == TYPE_ID_BYTE() && t2_id == TYPE_ID_I64())
    return TYPE_ID_I64()
  @end

  @if (t1_id == TYPE_ID_F64() && (t2_id == TYPE_ID_I64() || t2_id == TYPE_ID_BYTE())) || (t2_id == TYPE_ID_F64() && (t1_id == TYPE_ID_I64() || t1_id == TYPE_ID_BYTE()))
    return TYPE_ID_F64()
  @end

  return TYPE_ID_ANY()
@end
