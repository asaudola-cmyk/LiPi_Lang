@! ============================================================================
@! MAYA COMPILER MIDDLEEND: HINDLEY-MILNER TYPE INFERENCE (ALGORITHM W)
@! Module: compiler/middleend/type_inference
@! Canonical Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@enum TypeKind
  Var = 0
  Con = 1
  Fn = 2
  Tuple = 3
  App = 4
  Unit = 5
  Never = 6
@end

@struct TypeVar
  id: i64
@end

@struct MayaType
  kind: i64
  var_id: i64
  con_name: string
  fn_param: array
  fn_ret: array
@end

@struct TypeScheme
  vars: array
  ty: MayaType
@end

@struct TypeEnvEntry
  name: string
  scheme: TypeScheme
@end

@struct TypeEnv
  entries: array
@end

@struct SubstEntry
  var_id: i64
  target_type: MayaType
@end

@struct TypeSubstitution
  entries: array
@end

@struct InferState
  next_var: i64
@end

@fn infer_state_new() -> InferState
  return { next_var: 1 }
@end

@fn fresh_var(state: InferState) -> MayaType
  id = state.next_var
  state.next_var = state.next_var + 1
  return {
    kind: 0,
    var_id: id,
    con_name: "",
    fn_param: [],
    fn_ret: []
  }
@end

@fn type_con(name: string) -> MayaType
  return {
    kind: 1,
    var_id: 0,
    con_name: name,
    fn_param: [],
    fn_ret: []
  }
@end

@fn type_fn(param_t: MayaType, ret_t: MayaType) -> MayaType
  return {
    kind: 2,
    var_id: 0,
    con_name: "",
    fn_param: [param_t],
    fn_ret: [ret_t]
  }
@end

@fn apply_subst(subst: TypeSubstitution, ty: MayaType) -> MayaType
  @if ty.kind == 0
    i = 0
    num_items = subst.entries.len()
    @while i < num_items
      entry = subst.entries[i]
      @if entry.var_id == ty.var_id
        return entry.target_type
      @end
      i = i + 1
    @end
    return ty
  @elif ty.kind == 2
    p = ty.fn_param[0]
    r = ty.fn_ret[0]
    new_p = apply_subst(subst, p)
    new_r = apply_subst(subst, r)
    return type_fn(new_p, new_r)
  @end
  return ty
@end

@fn occurs_check(var_id: i64, ty: MayaType) -> i64
  @if ty.kind == 0
    @if ty.var_id == var_id
      return 1
    @end
    return 0
  @elif ty.kind == 2
    p = ty.fn_param[0]
    r = ty.fn_ret[0]
    @if occurs_check(var_id, p) == 1 || occurs_check(var_id, r) == 1
      return 1
    @end
    return 0
  @end
  return 0
@end

@fn unify(t1: MayaType, t2: MayaType) -> TypeSubstitution
  @if t1.kind == 0 && t2.kind == 0 && t1.var_id == t2.var_id
    return { entries: [] }
  @end

  @if t1.kind == 0
    @if occurs_check(t1.var_id, t2) == 1
      return { entries: [] }
    @end
    return { entries: [{ var_id: t1.var_id, target_type: t2 }] }
  @end

  @if t2.kind == 0
    @if occurs_check(t2.var_id, t1) == 1
      return { entries: [] }
    @end
    return { entries: [{ var_id: t2.var_id, target_type: t1 }] }
  @end

  @if t1.kind == 1 && t2.kind == 1 && t1.con_name == t2.con_name
    return { entries: [] }
  @end

  return { entries: [] }
@end
