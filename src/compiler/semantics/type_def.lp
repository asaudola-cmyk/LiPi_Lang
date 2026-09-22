// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: TYPE SYSTEM REPRESENTATION & REGISTRY (type_def.lp)
// Module: src/compiler/semantics/type_def.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// A statically sound sovereign programming language requires an uncompromising,
// hardware-aligned type system. In LiPi First 1.0.0, every value belongs to either:
// 1. A Primitive Silicon Type (i64, f64, bool, string, byte, void, any, never).
// 2. An Aggregate Struct Type with deterministic field offsets and alignment rules.
// 3. An Array (dynamic heap slice `[]T` or compile-time bounded `[T; N]`).
// 4. A Hardware Pointer (`*const T` or `*mut T`) for zero-cost hardware interfacing.
// 5. A Function Signature (`fn(T1, T2) -> R`) for higher-order first-class routines.
//
// DESIGN PRINCIPLES:
// Named constructors (`StructFieldDef()`, `TypeDef()`, `TypeRegistry()`) and sovereign
// prefixed fields (`fd_`, `ty_`, `tr_`) eliminate field name collisions across all
// compiler passes and user code.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

// ── 1. TYPE KIND CONSTANTS ───────────────────────────────────────────────────

@fn TYPE_KIND_VOID()        return 1  @end
@fn TYPE_KIND_I64()         return 2  @end
@fn TYPE_KIND_F64()         return 3  @end
@fn TYPE_KIND_BOOL()        return 4  @end
@fn TYPE_KIND_STRING()      return 5  @end
@fn TYPE_KIND_BYTE()        return 6  @end
@fn TYPE_KIND_ANY()         return 7  @end
@fn TYPE_KIND_NEVER()       return 8  @end
@fn TYPE_KIND_STRUCT()      return 9  @end
@fn TYPE_KIND_ARRAY()       return 10 @end
@fn TYPE_KIND_POINTER()     return 11 @end
@fn TYPE_KIND_FUNCTION()    return 12 @end
@fn TYPE_KIND_GENERIC_VAR() return 13 @end

// Predefined Builtin Type IDs (Fixed Slots 1..8)
@fn TYPE_ID_VOID()   return 1 @end
@fn TYPE_ID_I64()    return 2 @end
@fn TYPE_ID_F64()    return 3 @end
@fn TYPE_ID_BOOL()   return 4 @end
@fn TYPE_ID_STRING() return 5 @end
@fn TYPE_ID_BYTE()   return 6 @end
@fn TYPE_ID_ANY()    return 7 @end
@fn TYPE_ID_NEVER()  return 8 @end

// ── 2. STRUCT FIELD & TYPE DEFINITIONS ───────────────────────────────────────

@struct StructFieldDef
  fd_name: string
  fd_type_id: i64
  fd_offset: i64
  fd_size: i64
  fd_is_pub: i64
@end

@fn type_make_field(name, type_id, offset, size, is_pub)
  // WHY: Allocates a single field layout entry with named constructor
  f = StructFieldDef()
  f.fd_name = name
  f.fd_type_id = type_id
  f.fd_offset = offset
  f.fd_size = size
  f.fd_is_pub = is_pub
  return f
@end

@struct TypeDef
  ty_name: string
  ty_kind: i64
  ty_id: i64
  ty_elem_type_id: i64
  ty_array_len: i64
  ty_fields: array
  ty_param_types: array
  ty_ret_type_id: i64
  ty_size_bytes: i64
  ty_align_bytes: i64
  ty_is_mut: i64
  ty_generic_var_id: i64
@end

@fn type_def_new(id, kind, name, size_bytes, align_bytes)
  // WHY: Low-level constructor initializing all variants with named constructor
  ty = TypeDef()
  ty.ty_name = name
  ty.ty_kind = kind
  ty.ty_id = id
  ty.ty_elem_type_id = 0
  ty.ty_array_len = -1
  ty.ty_fields = []
  ty.ty_param_types = []
  ty.ty_ret_type_id = 0
  ty.ty_size_bytes = size_bytes
  ty.ty_align_bytes = align_bytes
  ty.ty_is_mut = 0
  ty.ty_generic_var_id = 0
  return ty
@end

// ── 3. TYPE REGISTRY (INTERN STORAGE) ────────────────────────────────────────

@struct TypeRegistry
  tr_types: array
  tr_next_id: i64
@end

@fn type_registry_new()
  // WHY: Initializes global compiler type environment with named TypeRegistry
  reg = TypeRegistry()
  reg.tr_types = []
  reg.tr_next_id = 9

  // Index 0: Invalid / Null type placeholder
  null_t = type_def_new(0, 0, "<invalid>", 0, 1)
  reg.tr_types = reg.tr_types.push(null_t)

  // 1: Void
  t_void = type_def_new(TYPE_ID_VOID(), TYPE_KIND_VOID(), "void", 0, 1)
  reg.tr_types = reg.tr_types.push(t_void)

  // 2: i64
  t_i64 = type_def_new(TYPE_ID_I64(), TYPE_KIND_I64(), "i64", 8, 8)
  reg.tr_types = reg.tr_types.push(t_i64)

  // 3: f64
  t_f64 = type_def_new(TYPE_ID_F64(), TYPE_KIND_F64(), "f64", 8, 8)
  reg.tr_types = reg.tr_types.push(t_f64)

  // 4: bool
  t_bool = type_def_new(TYPE_ID_BOOL(), TYPE_KIND_BOOL(), "bool", 1, 1)
  reg.tr_types = reg.tr_types.push(t_bool)

  // 5: string
  t_str = type_def_new(TYPE_ID_STRING(), TYPE_KIND_STRING(), "string", 16, 8)
  reg.tr_types = reg.tr_types.push(t_str)

  // 6: byte
  t_byte = type_def_new(TYPE_ID_BYTE(), TYPE_KIND_BYTE(), "byte", 1, 1)
  reg.tr_types = reg.tr_types.push(t_byte)

  // 7: any
  t_any = type_def_new(TYPE_ID_ANY(), TYPE_KIND_ANY(), "any", 16, 8)
  reg.tr_types = reg.tr_types.push(t_any)

  // 8: never
  t_never = type_def_new(TYPE_ID_NEVER(), TYPE_KIND_NEVER(), "never", 0, 1)
  reg.tr_types = reg.tr_types.push(t_never)

  return reg
@end

@fn type_registry_get(reg, type_id)
  @if reg == 0 || type_id < 0 || type_id >= reg.tr_types.len()
    return 0
  @end
  return reg.tr_types[type_id]
@end

@fn type_register_custom(reg, ty)
  @if reg == 0 || ty == 0 return 0 @end
  new_id = reg.tr_next_id
  reg.tr_next_id = reg.tr_next_id + 1
  ty.ty_id = new_id
  reg.tr_types = reg.tr_types.push(ty)
  return new_id
@end

// Builtin Shorthand Accessors
@fn type_void(reg)   return type_registry_get(reg, TYPE_ID_VOID())   @end
@fn type_i64(reg)    return type_registry_get(reg, TYPE_ID_I64())    @end
@fn type_f64(reg)    return type_registry_get(reg, TYPE_ID_F64())    @end
@fn type_bool(reg)   return type_registry_get(reg, TYPE_ID_BOOL())   @end
@fn type_string(reg) return type_registry_get(reg, TYPE_ID_STRING()) @end
@fn type_byte(reg)   return type_registry_get(reg, TYPE_ID_BYTE())   @end
@fn type_any(reg)    return type_registry_get(reg, TYPE_ID_ANY())    @end
@fn type_never(reg)  return type_registry_get(reg, TYPE_ID_NEVER())  @end

// ── 4. COMPOSITE TYPE CONSTRUCTORS ───────────────────────────────────────────

@fn type_align_up(val, align)
  @if align <= 1 return val @end
  rem = val % align
  @if rem == 0 return val @end
  return val + (align - rem)
@end

@fn type_make_struct(reg, name, fields)
  // WHY: Creates aggregate struct layout, calculating field offsets and packing
  total_size = 0
  max_align = 8
  adjusted_fields = []

  i = 0
  n = fields.len()
  @while i < n
    f = fields[i]
    f_type = type_registry_get(reg, f.fd_type_id)
    f_align = 8
    f_size = 8
    @if f_type != 0
      f_align = f_type.ty_align_bytes
      f_size = f_type.ty_size_bytes
    @end

    @if f_align > max_align
      max_align = f_align
    @end

    field_offset = type_align_up(total_size, f_align)
    f.fd_offset = field_offset
    f.fd_size = f_size
    total_size = field_offset + f_size
    adjusted_fields = adjusted_fields.push(f)
    i = i + 1
  @end

  total_size = type_align_up(total_size, max_align)

  ty = type_def_new(0, TYPE_KIND_STRUCT(), name, total_size, max_align)
  ty.ty_fields = adjusted_fields
  return type_register_custom(reg, ty)
@end

@fn type_make_array(reg, elem_type_id, fixed_len)
  elem_t = type_registry_get(reg, elem_type_id)
  e_size = 8
  e_align = 8
  @if elem_t != 0
    e_size = elem_t.ty_size_bytes
    e_align = elem_t.ty_align_bytes
  @end

  arr_name = "[]" + to_str(elem_type_id)
  total_size = 16
  @if fixed_len >= 0
    total_size = fixed_len * e_size
    arr_name = "[" + to_str(elem_type_id) + "; " + to_str(fixed_len) + "]"
  @end

  ty = type_def_new(0, TYPE_KIND_ARRAY(), arr_name, total_size, e_align)
  ty.ty_elem_type_id = elem_type_id
  ty.ty_array_len = fixed_len
  return type_register_custom(reg, ty)
@end

@fn type_make_pointer(reg, target_type_id, is_mut)
  prefix = "*const "
  @if is_mut == 1 prefix = "*mut " @end
  p_name = prefix + to_str(target_type_id)

  ty = type_def_new(0, TYPE_KIND_POINTER(), p_name, 8, 8)
  ty.ty_elem_type_id = target_type_id
  ty.ty_is_mut = is_mut
  return type_register_custom(reg, ty)
@end

@fn type_make_function(reg, param_type_ids, ret_type_id)
  fn_name = "fn("
  i = 0
  n = param_type_ids.len()
  @while i < n
    @if i > 0
      fn_name = fn_name + ", "
    @end
    fn_name = fn_name + to_str(param_type_ids[i])
    i = i + 1
  @end
  fn_name = fn_name + ") -> " + to_str(ret_type_id)

  ty = type_def_new(0, TYPE_KIND_FUNCTION(), fn_name, 8, 8)
  ty.ty_param_types = param_type_ids
  ty.ty_ret_type_id = ret_type_id
  return type_register_custom(reg, ty)
@end

@fn type_make_var(reg, var_id, var_name)
  ty = type_def_new(0, TYPE_KIND_GENERIC_VAR(), var_name, 8, 8)
  ty.ty_generic_var_id = var_id
  return type_register_custom(reg, ty)
@end

// ── 5. TYPE SYSTEM QUERY & UTILITY FUNCTIONS ─────────────────────────────────

@fn type_is_primitive(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return 0 @end
  k = ty.ty_kind
  @if k >= TYPE_KIND_VOID() && k <= TYPE_KIND_NEVER()
    return 1
  @end
  return 0
@end

@fn type_is_numeric(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return 0 @end
  @if ty.ty_kind == TYPE_KIND_I64() || ty.ty_kind == TYPE_KIND_F64() || ty.ty_kind == TYPE_KIND_BYTE()
    return 1
  @end
  return 0
@end

@fn type_is_pointer(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return 0 @end
  @if ty.ty_kind == TYPE_KIND_POINTER() return 1 @end
  return 0
@end

@fn type_is_function(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return 0 @end
  @if ty.ty_kind == TYPE_KIND_FUNCTION() return 1 @end
  return 0
@end

@fn type_is_struct(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return 0 @end
  @if ty.ty_kind == TYPE_KIND_STRUCT() return 1 @end
  return 0
@end

@fn type_is_array(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return 0 @end
  @if ty.ty_kind == TYPE_KIND_ARRAY() return 1 @end
  return 0
@end

@fn type_find_field(reg, struct_type_id, field_name)
  st = type_registry_get(reg, struct_type_id)
  @if st == 0 || st.ty_kind != TYPE_KIND_STRUCT()
    return 0
  @end

  i = 0
  n = st.ty_fields.len()
  @while i < n
    f = st.ty_fields[i]
    @if str_eq(f.fd_name, field_name) == 1
      return f
    @end
    i = i + 1
  @end

  return 0
@end

@fn type_to_string(reg, type_id)
  ty = type_registry_get(reg, type_id)
  @if ty == 0 return "<unknown>" @end

  @if ty.ty_kind == TYPE_KIND_VOID()   return "void"   @end
  @if ty.ty_kind == TYPE_KIND_I64()    return "i64"    @end
  @if ty.ty_kind == TYPE_KIND_F64()    return "f64"    @end
  @if ty.ty_kind == TYPE_KIND_BOOL()   return "bool"   @end
  @if ty.ty_kind == TYPE_KIND_STRING() return "string" @end
  @if ty.ty_kind == TYPE_KIND_BYTE()   return "byte"   @end
  @if ty.ty_kind == TYPE_KIND_ANY()    return "any"    @end
  @if ty.ty_kind == TYPE_KIND_NEVER()  return "never"  @end

  @if ty.ty_kind == TYPE_KIND_STRUCT()
    return ty.ty_name
  @end

  @if ty.ty_kind == TYPE_KIND_ARRAY()
    elem_str = type_to_string(reg, ty.ty_elem_type_id)
    @if ty.ty_array_len >= 0
      return "[" + elem_str + "; " + to_str(ty.ty_array_len) + "]"
    @end
    return "[]" + elem_str
  @end

  @if ty.ty_kind == TYPE_KIND_POINTER()
    target_str = type_to_string(reg, ty.ty_elem_type_id)
    @if ty.ty_is_mut == 1
      return "*mut " + target_str
    @end
    return "*const " + target_str
  @end

  @if ty.ty_kind == TYPE_KIND_FUNCTION()
    s = "fn("
    k = 0
    p_len = ty.ty_param_types.len()
    @while k < p_len
      @if k > 0
        s = s + ", "
      @end
      s = s + type_to_string(reg, ty.ty_param_types[k])
      k = k + 1
    @end
    s = s + ") -> " + type_to_string(reg, ty.ty_ret_type_id)
    return s
  @end

  @if ty.ty_kind == TYPE_KIND_GENERIC_VAR()
    return "'" + ty.ty_name
  @end

  return ty.ty_name
@end
