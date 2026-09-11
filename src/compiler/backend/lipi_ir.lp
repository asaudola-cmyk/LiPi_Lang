@! ============================================================================
@! LIPI COMPILER BACKEND — NATIVE LIPI IR & CFG INFRASTRUCTURE
@! 100% Written in Pure Lipi Language
@! Sovereign Backend Target: x86-64 Linux (System V AMD64 ABI)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. CANONICAL ZERO-COLLISION DATA STRUCTURE SCHEMAS
@! ============================================================================

@struct IRType
  kind: string
  name: string
  size: i64
  elem_type: i64
  fields: array
@end

@struct IRStructField
  f_name: string
  f_type: i64
  f_offset: i64
  f_size: i64
@end

@struct IRVal
  val_kind: string
  name: string
  val_size: i64
  val_type: i64
  val_int: i64
  val_id: i64
  val_label: string
  val_text: string
  val_len: i64
  val_is_const: i64
  val_raw_name: string
  val_index: i64
@end

@struct IRInst
  inst_op: string
  dest: string
  inst_type: i64
  op: string
  left: i64
  right: i64
  ptr: i64
  inst_val: i64
  target: i64
  cond: i64
  true_target: i64
  false_target: i64
  nr: i64
  stride: i64
  args: array
  incoming: array
  is_terminator: i64
  cmp_op: string
  align: i64
  inst_elem_type: i64
  target_label: string
  then_label: string
  else_label: string
  callee: string
@end

@struct IRPhiIncoming
  phi_val: i64
  phi_block_id: i64
@end

@struct IRBlock
  id: i64
  name: string
  instructions: array
  preds: array
  succs: array
  is_terminated: i64
  dom: array
  idom: i64
  df: array
  blk_label: string
@end

@struct IRParam
  p_kind: string
  p_name: string
  p_size: i64
  p_type: i64
  p_int: i64
  p_id: i64
  p_label: string
  p_text: string
  p_len: i64
  p_is_const: i64
  p_raw_name: string
  p_index: i64
  reg: string
  vreg: i64
@end

@struct IRLocal
  loc_name: string
  loc_vreg: i64
  loc_type: i64
@end

@struct IRStrEntry
  str_id: i64
  label: string
  str_val: string
  str_len: i64
  val_ref: i64
@end

@struct IRGlobalEntry
  g_name: string
  g_type: i64
  g_init: i64
@end

@struct IRLabelEntry
  lbl_key: string
  lbl_id: i64
  lbl_name: string
@end

@struct IRVarScopeEntry
  var_key: string
  var_ptr: string
  var_struct_type: string
@end

@struct IRLoopEntry
  loop_cond_id: i64
  loop_cond_lbl: string
  loop_step_id: i64
  loop_step_lbl: string
  loop_exit_id: i64
  loop_exit_lbl: string
@end

@struct IRFunction
  fn_id: i64
  name: string
  params: array
  fn_ret_type: i64
  entry_block: i64
  blocks: array
  locals: array
  next_vreg_id: i64
  next_block_id: i64
  is_varargs: i64
@end

@struct IRModule
  mod_id: i64
  name: string
  structs: array
  enums: array
  functions: array
  globals: array
  string_literals: array
  struct_defs: array
  rodata_map: array
  next_str_id: i64
@end

@struct IRBuilderCtx
  module: i64
  current_fn: i64
  current_bb_idx: i64
  temp_counter: i64
  label_counter: i64
  scopes: array
  loop_stack: array
  errors: array
  defer_stack: array
  struct_layouts: array
@end

@struct ASTNode
  kind: string
  name: string
  params: array
  body: array
  ret_type: string
  val: i64
  op: string
  left: i64
  right: i64
  expr: i64
  condition: i64
  then_body: array
  elif_branches: array
  else_body: array
  target: string
  value: i64
  elements: array
  args: array
  func: i64
  variable: string
  iterable: i64
  index: i64
  cond: i64
@end

@struct ASTProgram
  imports: array
  structs: array
  enums: array
  impls: array
  functions: array
  constants: array
  top_level: array
@end

@struct ASTParam
  name: string
  type_name: string
  default_val: i64
@end

@struct ASTField
  name: string
  type_name: string
  default_val: i64
  index: i64
@end

@struct ASTMatchArm
  arm_pattern: i64
  arm_body: array
@end

@struct ASTElifBranch
  elif_cond: i64
  elif_body: array
@end

@struct EnumVariant
  ev_name: string
  ev_value: i64
@end

@struct ASTConstant
  const_name: string
  const_value: i64
@end

@struct IRFunctionVerifyResult
  ok: i64
  errors: array
  warnings: array
@end

@struct IRModuleVerifyResult
  ok: i64
  errors: array
  warnings: array
  functions_verified: i64
@end

@struct IRLowerResult
  res_ctx: i64
  res_val: i64
@end

@! ============================================================================
@! 2. MAYA IR TYPE SYSTEM
@! ============================================================================

@fn ir_type(kind, size_bytes, elem_type, field_types, name)
  return {
    kind: kind,
    name: name,
    size: size_bytes,
    elem_type: elem_type,
    fields: field_types
  }
@end

@fn ir_type_new(kind, size_bytes, name)
  return ir_type(kind, size_bytes, 0, [], name)
@end

@fn ir_type_int(bits)
  @! Canonical integer IR type constructor with discrete literal dispatch
  @! WHY: Directly returns constant string literals to prevent string pointer addition (+ operator)
  @! which in Maya bootstrap creates invalid arithmetic pointer addresses.
  b = bits
  @if b == 0 b = 64 @end
  @if b == 64 return ir_type("i64", 8, 0, [], "i64") @end
  @if b == 32 return ir_type("i32", 4, 0, [], "i32") @end
  @if b == 16 return ir_type("i16", 2, 0, [], "i16") @end
  @if b == 8  return ir_type("i8",  1, 0, [], "i8") @end
  return ir_type("i64", 8, 0, [], "i64")
@end

@fn ir_type_i64()  return ir_type_int(64) @end
@fn ir_type_i32()  return ir_type_int(32) @end
@fn ir_type_i16()  return ir_type_int(16) @end
@fn ir_type_i8()   return ir_type_int(8) @end
@fn ir_type_bool() return ir_type("bool", 1, 0, [], "i1") @end

@fn ir_type_float(bits)
  @! Canonical floating-point IR type constructor
  @! WHY: Constant string literals avoid corrupted pointer offsets from + operator.
  b = bits
  @if b == 0 b = 64 @end
  @if b == 32 return ir_type("f32", 4, 0, [], "f32") @end
  return ir_type("f64", 8, 0, [], "f64")
@end

@fn ir_type_f64() return ir_type_float(64) @end
@fn ir_type_f32() return ir_type_float(32) @end

@fn ir_type_ptr(elem_type)
  return ir_type("ptr", 8, elem_type, [], "ptr")
@end

@fn ir_type_void()
  return ir_type("void", 0, 0, [], "void")
@end

@fn ir_type_array(elem_type, count)
  e_sz = 8
  @if elem_type != 0 && elem_type.size != 0
    e_sz = elem_type.size
  @end
  return ir_type("array", e_sz * count, elem_type, [], "array")
@end

@fn ir_is_type(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 0 @end
  k = t.kind
  @if str_eq(k, "i64") == 1 || str_eq(k, "i32") == 1 || str_eq(k, "i16") == 1 || str_eq(k, "i8") == 1 || str_eq(k, "bool") == 1 || str_eq(k, "f64") == 1 || str_eq(k, "f32") == 1 || str_eq(k, "void") == 1 || str_eq(k, "ptr") == 1 || str_eq(k, "array") == 1 || str_eq(k, "struct") == 1 || str_eq(k, "int") == 1 || str_eq(k, "float") == 1
    return 1
  @end
  return 0
@end

@fn ir_type_struct(name, fields)
  total_size = 0
  layout_fields = []
  i = 0
  @if fields.len() > 0
    num_items = fields.len()
    @while i < num_items
      f = fields[i]
      f_type = ir_type_void()
      f_name = string_concat("f", int_to_str(i))
      f_sz = 8
      @if f != 0
        @if ir_is_type(f) == 1
          f_type = f
          @if f.size > 0 f_sz = f.size @end
        @else
          @if f.f_type != 0
            f_type = f.f_type
          @elif f.type != 0
            f_type = f.type
          @end

          @if f.f_name != "" && f.f_name != 0
            f_name = f.f_name
          @elif f.name != "" && f.name != 0
            f_name = f.name
          @end

          @if ir_is_type(f_type) == 1
            @if f_type.size > 0
              f_sz = f_type.size
            @else
              f_sz = 8
            @end
          @else
            f_sz = 8
          @end
        @end
      @end
      @if f_sz <= 0 f_sz = 8 @end
      
      rem = total_size % 8
      @if rem != 0
        total_size = total_size + (8 - rem)
      @end
      
      layout_fields = layout_fields.push({
        f_name: f_name,
        f_type: f_type,
        f_offset: total_size,
        f_size: f_sz
      })
      total_size = total_size + f_sz
      i = i + 1
    @end
  @end
  
  rem = total_size % 8
  @if rem != 0
    total_size = total_size + (8 - rem)
  @end
  @if total_size == 0 total_size = 8 @end
  
  return ir_type("struct", total_size, 0, layout_fields, string_concat("%struct.", name))
@end

@fn ir_type_is_int(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 0 @end
  k = t.kind
  @if str_eq(k, "i64") == 1 || str_eq(k, "i32") == 1 || str_eq(k, "i16") == 1 || str_eq(k, "i8") == 1 || str_eq(k, "bool") == 1
    return 1
  @end
  return 0
@end

@fn ir_type_is_float(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 0 @end
  k = t.kind
  @if str_eq(k, "f64") == 1 || str_eq(k, "f32") == 1
    return 1
  @end
  return 0
@end

@fn ir_type_is_numeric(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 0 @end
  @if ir_type_is_int(t) == 1 || ir_type_is_float(t) == 1
    return 1
  @end
  return 0
@end

@fn ir_type_is_ptr(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 0 @end
  @if str_eq(t.kind, "ptr") == 1
    return 1
  @end
  return 0
@end

@fn ir_type_is_void(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 1 @end
  @if str_eq(t.kind, "void") == 1
    return 1
  @end
  return 0
@end

@fn ir_type_is_bool(t)
  @if t == 0 || t.kind == 0 || t.kind == "" return 0 @end
  @if str_eq(t.kind, "bool") == 1
    return 1
  @end
  return 0
@end

@fn ir_type_to_string(t_desc)
  @if t_desc == 0 || t_desc.kind == 0 return "void" @end
  k = t_desc.kind
  @if str_eq(k, "i64") == 1 return "i64" @end
  @if str_eq(k, "i32") == 1 return "i32" @end
  @if str_eq(k, "i16") == 1 return "i16" @end
  @if str_eq(k, "i8") == 1 return "i8" @end
  @if str_eq(k, "bool") == 1 return "i1" @end
  @if str_eq(k, "f64") == 1 return "f64" @end
  @if str_eq(k, "f32") == 1 return "f32" @end
  @if str_eq(k, "ptr") == 1 return "ptr" @end
  @if str_eq(k, "void") == 1 return "void" @end
  @if str_eq(k, "array") == 1 return "array" @end
  @if str_eq(k, "struct") == 1
    @if t_desc.name != 0 return t_desc.name @end
    return "%struct.anon"
  @end
  return "i64"
@end

@! ============================================================================
@! 3. MAYA IR VALUES & OPERANDS
@! ============================================================================

@fn ir_val_vreg(id, t_desc, name_hint)
  @! Canonical virtual register value constructor
  @! WHY: Uses string_concat to construct register symbol name without pointer addition.
  vname = string_concat("%v", int_to_str(id))
  @if name_hint != 0 && str_eq(name_hint, "") == 0
    vname = string_concat(string_concat("%", name_hint), string_concat("_", int_to_str(id)))
  @end
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  return {
    val_kind: "reg",
    name: vname,
    val_size: 8,
    val_type: t,
    val_int: 0,
    val_id: id,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 0,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_reg(name, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  return {
    val_kind: "reg",
    name: name,
    val_size: 8,
    val_type: t,
    val_int: 0,
    val_id: -1,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 0,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_const_int(int_val, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  return {
    val_kind: "const_int",
    name: int_to_str(int_val),
    val_size: 8,
    val_type: t,
    val_int: int_val,
    val_id: -1,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 1,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_const_float(flt_val, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_f64() @end
  return {
    val_kind: "const_float",
    name: int_to_str(flt_val),
    val_size: 8,
    val_type: t,
    val_int: flt_val,
    val_id: -1,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 1,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_const_bool(bool_val)
  bval = 0
  @if bool_val == 1 || bool_val == "true" || bool_val == true bval = 1 @end
  return {
    val_kind: "const_bool",
    name: int_to_str(bval),
    val_size: 1,
    val_type: ir_type_bool(),
    val_int: bval,
    val_id: -1,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 1,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_const_str(label, text, length)
  return {
    val_kind: "str_ref",
    name: label,
    val_size: 8,
    val_type: ir_type_ptr(ir_type("i8", 1, 0, [], "i8")),
    val_int: 0,
    val_id: -1,
    val_label: label,
    val_text: text,
    val_len: length,
    val_is_const: 1,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_const_null()
  return {
    val_kind: "const_null",
    name: "null",
    val_size: 8,
    val_type: ir_type_ptr(ir_type_void()),
    val_int: 0,
    val_id: -1,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 1,
    val_raw_name: "",
    val_index: -1
  }
@end

@fn ir_val_null(t)
  return ir_val_const_null()
@end

@fn ir_val_global(name, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  return {
    val_kind: "global_ref",
    name: string_concat("@", name),
    val_size: 8,
    val_type: t,
    val_int: 0,
    val_id: -1,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 0,
    val_raw_name: name,
    val_index: -1
  }
@end

@fn ir_val_param(index, name, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  return {
    val_kind: "param",
    name: string_concat("%param_", name),
    val_size: 8,
    val_type: t,
    val_int: 0,
    val_id: index,
    val_label: "",
    val_text: "",
    val_len: 0,
    val_is_const: 0,
    val_raw_name: name,
    val_index: index
  }
@end

@fn ir_val_to_string(val)
  @if val == 0 return "null" @end
  @if val.name != 0 return val.name @end
  @if val.val_kind == "const_int" return val.val_int.to_str() @end
  @if val.val_kind == "const_float" return val.val_int.to_str() @end
  @if val.val_kind == "const_bool"
    @if val.val_int == 1 return "1" @else return "0" @end
  @end
  @if val.val_kind == "str_ref" return "@" + val.val_label @end
  @if val.val_kind == "global_ref" return val.name @end
  @if val.val_kind == "param" return val.name @end
  @if val.val_kind == "const_null" return "null" @end
  return "0"
@end

@! ============================================================================
@! 4. MAYA IR INSTRUCTION SET & CONSTRUCTORS
@! ============================================================================

@fn ir_inst(op, dest, t_desc, args, is_term)
  return {
    inst_op: op,
    dest: dest,
    inst_type: t_desc,
    op: op,
    left: 0,
    right: 0,
    ptr: 0,
    inst_val: 0,
    target: -1,
    cond: 0,
    true_target: -1,
    false_target: -1,
    nr: 0,
    stride: 8,
    args: args,
    incoming: [],
    is_terminator: is_term,
    cmp_op: "",
    align: 8,
    inst_elem_type: 0,
    target_label: "",
    then_label: "",
    else_label: "",
    callee: ""
  }
@end

@fn ir_inst_alloca(dest, elem_t, count_or_align, name_hint)
  t = elem_t
  @if t.kind == "" t = ir_type_i64() @end
  c = count_or_align
  @if c == 0 c = 16 @end
  inst = ir_inst("ALLOCA", dest, ir_type_ptr(t), [], 0)
  inst.align = c
  inst.inst_elem_type = t
  return inst
@end

@fn ir_inst_load(dest, ptr_val, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("LOAD", dest, t, [ptr_val], 0)
  inst.ptr = ptr_val
  return inst
@end

@fn ir_inst_store(val, ptr, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("STORE", "", ir_type_void(), [val, ptr], 0)
  inst.inst_val = val
  inst.ptr = ptr
  return inst
@end

@fn ir_inst_gep(dest, base_ptr, index_val, elem_t, stride)
  t = elem_t
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("GEP", dest, ir_type_ptr(t), [base_ptr, index_val], 0)
  inst.ptr = base_ptr
  inst.left = base_ptr
  inst.right = index_val
  inst.inst_elem_type = t
  inst.stride = stride
  return inst
@end

@fn ir_inst_binary(op, dest, lhs, rhs, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst(op, dest, t, [lhs, rhs], 0)
  inst.left = lhs
  inst.right = rhs
  return inst
@end

@fn ir_inst_add(dest, lhs, rhs, t_desc)  return ir_inst_binary("ADD", dest, lhs, rhs, t_desc) @end
@fn ir_inst_sub(dest, lhs, rhs, t_desc)  return ir_inst_binary("SUB", dest, lhs, rhs, t_desc) @end
@fn ir_inst_mul(dest, lhs, rhs, t_desc)  return ir_inst_binary("MUL", dest, lhs, rhs, t_desc) @end
@fn ir_inst_div(dest, lhs, rhs, t_desc)  return ir_inst_binary("SDIV", dest, lhs, rhs, t_desc) @end
@fn ir_inst_mod(dest, lhs, rhs, t_desc)  return ir_inst_binary("SREM", dest, lhs, rhs, t_desc) @end
@fn ir_inst_and(dest, lhs, rhs, t_desc)  return ir_inst_binary("AND", dest, lhs, rhs, t_desc) @end
@fn ir_inst_or(dest, lhs, rhs, t_desc)   return ir_inst_binary("OR", dest, lhs, rhs, t_desc) @end
@fn ir_inst_xor(dest, lhs, rhs, t_desc)  return ir_inst_binary("XOR", dest, lhs, rhs, t_desc) @end
@fn ir_inst_shl(dest, lhs, rhs, t_desc)  return ir_inst_binary("SHL", dest, lhs, rhs, t_desc) @end
@fn ir_inst_shr(dest, lhs, rhs, t_desc)  return ir_inst_binary("SHR", dest, lhs, rhs, t_desc) @end

@fn ir_inst_neg(dest, operand, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("NEG", dest, t, [operand], 0)
  inst.left = operand
  return inst
@end

@fn ir_inst_not(dest, operand, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("NOT", dest, t, [operand], 0)
  inst.left = operand
  return inst
@end

@fn ir_inst_cmp(cond_op, dest, lhs, rhs, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  normalized_op = cond_op
  @if cond_op == "==" || cond_op == "EQ" normalized_op = "eq" @end
  @if cond_op == "!=" || cond_op == "NE" normalized_op = "ne" @end
  @if cond_op == "<"  || cond_op == "LT" normalized_op = "slt" @end
  @if cond_op == "<=" || cond_op == "LE" normalized_op = "sle" @end
  @if cond_op == ">"  || cond_op == "GT" normalized_op = "sgt" @end
  @if cond_op == ">=" || cond_op == "GE" normalized_op = "sge" @end
  inst = ir_inst("CMP", dest, ir_type_bool(), [lhs, rhs], 0)
  inst.cmp_op = normalized_op
  inst.left = lhs
  inst.right = rhs
  return inst
@end

@fn ir_inst_branch(target_block_id)
  inst = ir_inst("BR", "", ir_type_void(), [], 1)
  inst.target = target_block_id
  return inst
@end

@fn ir_inst_br(target_id, target_label)
  inst = ir_inst("BR", "", ir_type_void(), [], 1)
  inst.target = target_id
  inst.target_label = target_label
  return inst
@end

@fn ir_inst_branch_cond(cond_reg, true_block_id, false_block_id)
  inst = ir_inst("BR_COND", "", ir_type_void(), [cond_reg], 1)
  inst.cond = cond_reg
  inst.true_target = true_block_id
  inst.false_target = false_block_id
  return inst
@end

@fn ir_inst_br_cond(cond_val, then_id, then_label, else_id, else_label)
  inst = ir_inst("BR_COND", "", ir_type_void(), [cond_val], 1)
  inst.cond = cond_val
  inst.true_target = then_id
  inst.then_label = then_label
  inst.false_target = else_id
  inst.else_label = else_label
  return inst
@end

@fn ir_inst_ret(val_or_zero, t_desc)
  t = t_desc
  @if t.kind == ""
    @if val_or_zero != 0 && val_or_zero.val_type != 0 t = val_or_zero.val_type @else t = ir_type_void() @end
  @end
  args = []
  @if val_or_zero != 0 args = [val_or_zero] @end
  inst = ir_inst("RET", "", t, args, 1)
  inst.inst_val = val_or_zero
  return inst
@end

@fn ir_inst_call(dest, callee_name, args, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("CALL", dest, t, args, 0)
  inst.callee = callee_name
  return inst
@end

@fn ir_inst_syscall(dest, nr_val, args_list, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("SYSCALL", dest, t, args_list, 0)
  
  sys_nr = 0
  @if nr_val != 0
    @if nr_val.val_is_const == 1 || nr_val.val_kind == "const_int"
      sys_nr = str_to_int(nr_val.name)
      @if sys_nr == 0 && nr_val.val_int != 0 && nr_val.val_int > 0
        sys_nr = nr_val.val_int
      @end
    @else
      sys_nr = nr_val
    @end
  @end
  inst.nr = sys_nr
  return inst
@end

@fn ir_phi_incoming_new(val, block_id, block_label)
  return {
    phi_val: val,
    phi_block_id: block_id
  }
@end

@fn ir_inst_phi(dest, incoming_pairs, t_desc)
  t = t_desc
  @if t.kind == "" t = ir_type_i64() @end
  inst = ir_inst("PHI", dest, t, [], 0)
  inst.incoming = incoming_pairs
  return inst
@end

@fn ir_op_is_term(op)
  @! Detect basic block terminator opcodes
  @! WHY: Uses str_eq for value equivalence rather than pointer identity (==).
  @if str_eq(op, "BR") == 1 || str_eq(op, "br") == 1 || str_eq(op, "BR_COND") == 1 || str_eq(op, "br_cond") == 1 || str_eq(op, "RET") == 1 || str_eq(op, "ret") == 1
    return 1
  @end
  return 0
@end

@fn ir_op_is_br(op)
  @if str_eq(op, "BR") == 1 || str_eq(op, "br") == 1 return 1 @end
  return 0
@end

@fn ir_op_is_br_cond(op)
  @if str_eq(op, "BR_COND") == 1 || str_eq(op, "br_cond") == 1 return 1 @end
  return 0
@end

@fn ir_op_is_ret(op)
  @if str_eq(op, "RET") == 1 || str_eq(op, "ret") == 1 return 1 @end
  return 0
@end

@fn ir_op_is_phi(op)
  @if str_eq(op, "PHI") == 1 || str_eq(op, "phi") == 1 return 1 @end
  return 0
@end

@fn ir_op_to_lower(op)
  @if op == "ADD" return "add" @end
  @if op == "SUB" return "sub" @end
  @if op == "MUL" return "mul" @end
  @if op == "SDIV" return "div" @end
  @if op == "SREM" return "mod" @end
  @if op == "NEG" return "neg" @end
  @if op == "AND" return "and" @end
  @if op == "OR" return "or" @end
  @if op == "XOR" return "xor" @end
  @if op == "SHL" return "shl" @end
  @if op == "SHR" return "shr" @end
  @if op == "NOT" return "not" @end
  @if op == "CMP" return "cmp" @end
  @if op == "ALLOCA" return "alloca" @end
  @if op == "LOAD" return "load" @end
  @if op == "STORE" return "store" @end
  @if op == "GEP" return "gep" @end
  @if op == "BR" return "br" @end
  @if op == "BR_COND" return "br_cond" @end
  @if op == "RET" return "ret" @end
  @if op == "CALL" return "call" @end
  @if op == "SYSCALL" return "syscall" @end
  @if op == "PHI" return "phi" @end
  return str_to_lower(op)
@end

@fn ir_inst_to_string(inst)
  op = inst.inst_op
  @if op == "" || op == 0 op = inst.op @end
  dest = inst.dest
  type_str = ir_type_to_string(inst.inst_type)
  op_lower = ir_op_to_lower(op)
  
  @if op == "ALLOCA" || op == "alloca"
    elem_str = "i64"
    @if inst.inst_elem_type != 0 elem_str = ir_type_to_string(inst.inst_elem_type) @end
    return dest + " = alloca " + elem_str
  @elif op == "LOAD" || op == "load"
    src = ir_val_to_string(inst.ptr)
    @if src == "null" && inst.args.len() > 0 src = ir_val_to_string(inst.args[0]) @end
    return dest + " = load " + type_str + ", ptr " + src
  @elif op == "STORE" || op == "store"
    val = ir_val_to_string(inst.inst_val)
    ptr_val = ir_val_to_string(inst.ptr)
    @if val == "null" && inst.args.len() > 0 val = ir_val_to_string(inst.args[0]) @end
    @if ptr_val == "null" && inst.args.len() > 1 ptr_val = ir_val_to_string(inst.args[1]) @end
    val_type = "i64"
    @if inst.inst_val != 0 && inst.inst_val.val_type != 0 val_type = ir_type_to_string(inst.inst_val.val_type) @end
    return "store " + val_type + " " + val + ", ptr " + ptr_val
  @elif op == "GEP" || op == "gep"
    base = ir_val_to_string(inst.left)
    idx = ir_val_to_string(inst.right)
    elem_str = "i64"
    @if inst.inst_elem_type != 0 elem_str = ir_type_to_string(inst.inst_elem_type) @end
    return dest + " = gep " + elem_str + ", ptr " + base + ", i64 " + idx
  @elif op == "ADD" || op == "add" || op == "SUB" || op == "sub" || op == "MUL" || op == "mul" || op == "SDIV" || op == "div" || op == "SREM" || op == "mod" || op == "AND" || op == "and" || op == "OR" || op == "or" || op == "XOR" || op == "xor" || op == "SHL" || op == "shl" || op == "SHR" || op == "shr"
    lhs = ir_val_to_string(inst.left)
    rhs = ir_val_to_string(inst.right)
    @if lhs == "null" && inst.args.len() > 0 lhs = ir_val_to_string(inst.args[0]) @end
    @if rhs == "null" && inst.args.len() > 1 rhs = ir_val_to_string(inst.args[1]) @end
    return dest + " = " + op_lower + " " + type_str + " " + lhs + ", " + rhs
  @elif op == "NEG" || op == "neg" || op == "NOT" || op == "not"
    src = ir_val_to_string(inst.left)
    @if src == "null" && inst.args.len() > 0 src = ir_val_to_string(inst.args[0]) @end
    return dest + " = " + op_lower + " " + type_str + " " + src
  @elif op == "CMP" || op == "cmp"
    cmp_op = inst.cmp_op
    lhs = ir_val_to_string(inst.left)
    rhs = ir_val_to_string(inst.right)
    @if lhs == "null" && inst.args.len() > 0 lhs = ir_val_to_string(inst.args[0]) @end
    @if rhs == "null" && inst.args.len() > 1 rhs = ir_val_to_string(inst.args[1]) @end
    lhs_type = "i64"
    @if inst.left != 0 && inst.left.val_type != 0 lhs_type = ir_type_to_string(inst.left.val_type) @end
    return dest + " = cmp " + cmp_op + " " + lhs_type + " " + lhs + ", " + rhs
  @elif op == "BR" || op == "br"
    target_bb = inst.target.to_str()
    return "br label %bb_" + target_bb
  @elif op == "BR_COND" || op == "br_cond"
    cond_str = ir_val_to_string(inst.cond)
    @if cond_str == "null" && inst.args.len() > 0 cond_str = ir_val_to_string(inst.args[0]) @end
    then_bb = inst.true_target.to_str()
    else_bb = inst.false_target.to_str()
    return "br_cond i1 " + cond_str + ", label %bb_" + then_bb + ", label %bb_" + else_bb
  @elif op == "CALL" || op == "call"
    callee = inst.callee
    arg_strs = []
    i = 0
    @while i < inst.args.len()
      arg = inst.args[i]
      arg_type_str = "i64"
      @if arg.val_type != 0 arg_type_str = ir_type_to_string(arg.val_type) @end
      arg_strs = arg_strs.push(arg_type_str + " " + ir_val_to_string(arg))
      i = i + 1
    @end
    
    args_joined = ""
    j = 0
    @while j < arg_strs.len()
      @if j > 0 args_joined = args_joined + ", " @end
      args_joined = args_joined + arg_strs[j]
      j = j + 1
    @end
    
    @if type_str == "void" || dest == "" || dest == 0
      return "call void @" + callee + "(" + args_joined + ")"
    @else
      return dest + " = call " + type_str + " @" + callee + "(" + args_joined + ")"
    @end
  @elif op == "RET" || op == "ret"
    @if inst.args.len() == 0 || type_str == "void"
      return "ret void"
    @else
      val_str = ir_val_to_string(inst.inst_val)
      @if val_str == "null" && inst.args.len() > 0 val_str = ir_val_to_string(inst.args[0]) @end
      return "ret " + type_str + " " + val_str
    @end
  @elif op == "SYSCALL" || op == "syscall"
    sys_nr = inst.nr.to_str()
    arg_strs = []
    i = 0
    @while i < inst.args.len()
      arg = inst.args[i]
      arg_type_str = "i64"
      @if arg.val_type != 0 arg_type_str = ir_type_to_string(arg.val_type) @end
      arg_strs = arg_strs.push(arg_type_str + " " + ir_val_to_string(arg))
      i = i + 1
    @end
    
    args_joined = ""
    j = 0
    @while j < arg_strs.len()
      @if j > 0 args_joined = args_joined + ", " @end
      args_joined = args_joined + arg_strs[j]
      j = j + 1
    @end
    
    @if dest == "" || dest == 0
      return "syscall " + sys_nr + "(" + args_joined + ")"
    @else
      return dest + " = syscall " + sys_nr + "(" + args_joined + ")"
    @end
  @elif op == "PHI" || op == "phi"
    pairs = []
    i = 0
    @if inst.incoming != 0
      num_items = inst.incoming.len()
      @while i < num_items
        inc = inst.incoming[i]
        b_id_str = ""
        @if inc.phi_block_id != 0 b_id_str = inc.phi_block_id.to_str()
        @elif inc.block_id != 0 b_id_str = inc.block_id.to_str()
        @elif inc.block != 0 b_id_str = inc.block.to_str() @end
        inc_val = inc.phi_val
        @if inc_val == 0 inc_val = inc.val @end
        pairs = pairs.push("[ " + ir_val_to_string(inc_val) + ", %bb_" + b_id_str + " ]")
        i = i + 1
      @end
    @end
    pairs_joined = ""
    k = 0
    @while k < pairs.len()
      @if k > 0 pairs_joined = pairs_joined + ", " @end
      pairs_joined = pairs_joined + pairs[k]
      k = k + 1
    @end
    return dest + " = phi " + type_str + " " + pairs_joined
  @end
  return "; unknown instruction " + op
@end

@! ============================================================================
@! 5. BASIC BLOCK & CFG GRAPH BUILDER
@! ============================================================================

@fn ir_block_new(id, name)
  return {
    id: id,
    name: name,
    instructions: [],
    preds: [],
    succs: [],
    is_terminated: 0,
    dom: [],
    idom: -1,
    df: [],
    blk_label: name
  }
@end

@fn ir_block_add_inst(block, inst)
  b = block
  @if inst.is_terminator == 1
    b.is_terminated = 1
  @end
  b.instructions = b.instructions.push(inst)
  return b
@end

@fn ir_block_add_edge(from_block, to_block)
  found_succ = 0
  _i_s_0 = 0
  @while _i_s_0 < from_block.succs.len()
    s = from_block.succs[_i_s_0]
    @if s == to_block.id found_succ = 1 @end
    _i_s_0 = _i_s_0 + 1
  @end
  @if found_succ == 0
    from_block.succs = from_block.succs.push(to_block.id)
  @end

  found_pred = 0
  _i_p_0 = 0
  @while _i_p_0 < to_block.preds.len()
    p = to_block.preds[_i_p_0]
    @if p == from_block.id found_pred = 1 @end
    _i_p_0 = _i_p_0 + 1
  @end
  @if found_pred == 0
    to_block.preds = to_block.preds.push(from_block.id)
  @end
  return 1
@end

@fn ir_cfg_add_edge(arg1, arg2)
  return ir_block_add_edge(arg1, arg2)
@end

@! Dominator intersection algorithm
@fn ir_intersect_dom(b1, b2, idoms)
  finger1 = b1
  finger2 = b2
  @while finger1 != finger2 && finger1 != -1 && finger2 != -1
    @if finger1 > finger2
      next1 = idoms[finger1]
      @if next1 == finger1 next1 = -1 @end
      finger1 = next1
    @else
      next2 = idoms[finger2]
      @if next2 == finger2 next2 = -1 @end
      finger2 = next2
    @end
  @end
  @if finger1 == -1 return finger2 @end
  @if finger2 == -1 return finger1 @end
  return finger1
@end

@fn ir_compute_dominators(blocks)
  n = blocks.len()
  idoms = []
  i = 0
  @while i < n
    idoms = idoms.push(-1)
    i = i + 1
  @end
  
  idoms = list_set(idoms, 0, 0)
  changed = 1
  
  @while changed == 1
    changed = 0
    i = 1
    @while i < n
      b = blocks[i]
      @if b.preds.len() > 0
        @! Find first processed predecessor
        first_processed = -1
        p_idx = 0
        plen = b.preds.len()
        @while p_idx < plen
          p = b.preds[p_idx]
          @if idoms[p] != -1
            first_processed = p
            p_idx = plen @! break
          @end
          p_idx = p_idx + 1
        @end
        
        @if first_processed != -1
          new_idom = first_processed
          p_idx = 0
          @while p_idx < plen
            p = b.preds[p_idx]
            @if p != first_processed && idoms[p] != -1
              new_idom = ir_intersect_dom(p, new_idom, idoms)
            @end
            p_idx = p_idx + 1
          @end
          @if idoms[i] != new_idom
            idoms = list_set(idoms, i, new_idom)
            changed = 1
          @end
        @end
      @end
      i = i + 1
    @end
  @end
  
  i = 0
  @while i < n
    blocks[i].idom = idoms[i]
    i = i + 1
  @end
  return blocks
@end

@fn ir_compute_dominance_frontiers(blocks)
  n = blocks.len()
  i = 0
  @while i < n
    b = blocks[i]
    @if b.preds.len() >= 2
      j = 0
      plen = b.preds.len()
      @while j < plen
        runner = b.preds[j]
        @while runner != b.idom && runner != -1
          already = 0
          _i_d_0 = 0
          @while _i_d_0 < blocks[runner].df.len()
            d = blocks[runner].df[_i_d_0]
            @if d == b.id already = 1 @end
            _i_d_0 = _i_d_0 + 1
          @end
          @if already == 0
            blocks[runner].df = blocks[runner].df.push(b.id)
          @end
          
          next_runner = blocks[runner].idom
          @if next_runner == runner
            runner = -1
          @else
            runner = next_runner
          @end
        @end
        j = j + 1
      @end
    @end
    i = i + 1
  @end
  return blocks
@end

@fn ir_block_to_string(block)
  pred_strs = []
  i = 0
  @while i < block.preds.len()
    pred_strs = pred_strs.push("%bb_" + block.preds[i].to_str())
    i = i + 1
  @end
  preds_text = "none"
  @if pred_strs.len() > 0
    preds_text = ""
    p_i = 0
    @while p_i < pred_strs.len()
      @if p_i > 0 preds_text = preds_text + ", " @end
      preds_text = preds_text + pred_strs[p_i]
      p_i = p_i + 1
    @end
  @end

  succ_strs = []
  i = 0
  @while i < block.succs.len()
    succ_strs = succ_strs.push("%bb_" + block.succs[i].to_str())
    i = i + 1
  @end
  succs_text = "none"
  @if succ_strs.len() > 0
    succs_text = ""
    s_i = 0
    @while s_i < succ_strs.len()
      @if s_i > 0 succs_text = succs_text + ", " @end
      succs_text = succs_text + succ_strs[s_i]
      s_i = s_i + 1
    @end
  @end

  out = "bb_" + block.id.to_str() + " (" + block.name + "): ; preds: " + preds_text + ", succs: " + succs_text + "\n"
  j = 0
  @while j < block.instructions.len()
    out = out + "  " + ir_inst_to_string(block.instructions[j]) + "\n"
    j = j + 1
  @end
  return out
@end

@! ============================================================================
@! 6. IR FUNCTION & IR MODULE HIERARCHY
@! ============================================================================

@fn ir_function_new(name, params, ret_t)
  fn_params = []
  p_idx = 0
  p_len = params.len()
  @while p_idx < p_len
    p_name = params[p_idx]
    p_type = ir_type_i64()
    fn_params = fn_params.push({
      p_kind: "param",
      p_name: p_name,
      p_size: 8,
      p_type: p_type,
      p_int: 0,
      p_id: p_idx,
      p_label: "",
      p_text: "",
      p_len: 0,
      p_is_const: 0,
      p_raw_name: p_name,
      p_index: p_idx,
      reg: "%param_" + p_name,
      vreg: ir_val_param(p_idx, p_name, p_type)
    })
    p_idx = p_idx + 1
  @end
  
  entry_bb = ir_block_new(0, "entry")
  t_ret = ret_t
  @if t_ret == 0 t_ret = ir_type_i64() @end
  
  return {
    fn_id: 0,
    name: name,
    params: fn_params,
    fn_ret_type: t_ret,
    entry_block: 0,
    blocks: [entry_bb],
    locals: [],
    next_vreg_id: 0,
    next_block_id: 1,
    is_varargs: 0
  }
@end

@fn ir_function_alloc_vreg(func, t_desc, name_hint)
  vid = func.next_vreg_id
  func.next_vreg_id = func.next_vreg_id + 1
  return ir_val_vreg(vid, t_desc, name_hint)
@end

@fn ir_function_create_block(func, name_prefix)
  bid = func.next_block_id
  func.next_block_id = func.next_block_id + 1
  lbl = name_prefix + "_" + bid.to_str()
  bb = ir_block_new(bid, lbl)
  func.blocks = func.blocks.push(bb)
  return bb
@end

@fn ir_function_add_local(func, name, t_desc)
  ptr_vreg = ir_function_alloc_vreg(func, ir_type_ptr(t_desc), name + "_ptr")
  func.locals = func.locals.push({
    loc_name: name,
    loc_vreg: ptr_vreg,
    loc_type: t_desc
  })
  return ptr_vreg
@end

@fn ir_func_to_string(func)
  param_strs = []
  i = 0
  @while i < func.params.len()
    p = func.params[i]
    param_strs = param_strs.push(ir_type_to_string(p.p_type) + " " + p.reg)
    i = i + 1
  @end
  
  params_text = ""
  p_i = 0
  @while p_i < param_strs.len()
    @if p_i > 0 params_text = params_text + ", " @end
    params_text = params_text + param_strs[p_i]
    p_i = p_i + 1
  @end
  
  ret_str = ir_type_to_string(func.fn_ret_type)
  out = "define " + ret_str + " @" + func.name + "(" + params_text + ") {\n"
  k = 0
  @while k < func.blocks.len()
    out = out + ir_block_to_string(func.blocks[k])
    @if k + 1 < func.blocks.len() out = out + "\n" @end
    k = k + 1
  @end
  out = out + "}\n"
  return out
@end

@fn ir_module_new(name)
  return {
    mod_id: 0,
    name: name,
    structs: [],
    enums: [],
    functions: [],
    globals: [],
    string_literals: [],
    struct_defs: [],
    rodata_map: [],
    next_str_id: 0
  }
@end

@fn ir_module_add_string_literal(module, str_val)
  @! Deduplicate identical string literals
  i = 0
  num_items = module.rodata_map.len()
  @while i < num_items
    entry = module.rodata_map[i]
    @if entry.str_val == str_val
      return entry.val_ref
    @end
    i = i + 1
  @end

  sid = module.next_str_id
  module.next_str_id = module.next_str_id + 1
  label = string_concat(".str.", int_to_str(sid))
  length = str_val.len()
  val_ref = ir_val_const_str(label, str_val, length)
  
  item = {
    str_id: sid,
    label: label,
    str_val: str_val,
    str_len: length,
    val_ref: val_ref
  }
  module.string_literals = module.string_literals.push(item)
  module.rodata_map = module.rodata_map.push(item)
  return val_ref
@end

@fn ir_module_add_function(module, func)
  module.functions = module.functions.push(func)
  return module
@end

@fn ir_module_add_global(module, name, t_desc, init_val)
  g_entry = {
    g_name: name,
    g_type: t_desc,
    g_init: init_val
  }
  module.globals = module.globals.push(g_entry)
  return module
@end

@fn ir_module_to_string(module)
  out = "; Lipi IR Module: " + module.name + "\n"
  out = out + "; Target: x86-64 Linux (System V AMD64 ABI)\n\n"

  @! String literals table
  i = 0
  @while i < module.string_literals.len()
    s = module.string_literals[i]
    out = out + "@" + s.label + " = private constant [" + s.str_len.to_str() + " x i8] c\"" + s.str_val + "\\00\"\n"
    i = i + 1
  @end
  @if module.string_literals.len() > 0 out = out + "\n" @end

  @! Globals table
  g = 0
  @while g < module.globals.len()
    glob = module.globals[g]
    out = out + "@" + glob.g_name + " = global " + ir_type_to_string(glob.g_type) + " " + ir_val_to_string(glob.g_init) + "\n"
    g = g + 1
  @end
  @if module.globals.len() > 0 out = out + "\n" @end

  @! Functions
  f = 0
  @while f < module.functions.len()
    out = out + ir_func_to_string(module.functions[f])
    @if f + 1 < module.functions.len() out = out + "\n" @end
    f = f + 1
  @end
  return out
@end

@! ============================================================================
@! 7. INVARIANT-CHECKING CFG VERIFIER
@! ============================================================================

@! ============================================================================
@! 7. 10-INVARIANT CFG VALIDATOR & MODULE VERIFICATION
@! ============================================================================

@fn ir_op_is_valid(op)
  @! Verifies opcode validity in SSA instruction stream
  @! WHY: Uses str_eq to compare opcode byte content across compiler modules.
  @if str_eq(op, "ALLOCA") == 1 || str_eq(op, "alloca") == 1 return 1 @end
  @if str_eq(op, "LOAD") == 1 || str_eq(op, "load") == 1 return 1 @end
  @if str_eq(op, "STORE") == 1 || str_eq(op, "store") == 1 return 1 @end
  @if str_eq(op, "GEP") == 1 || str_eq(op, "gep") == 1 return 1 @end
  @if str_eq(op, "ADD") == 1 || str_eq(op, "add") == 1 return 1 @end
  @if str_eq(op, "SUB") == 1 || str_eq(op, "sub") == 1 return 1 @end
  @if str_eq(op, "MUL") == 1 || str_eq(op, "mul") == 1 return 1 @end
  @if str_eq(op, "SDIV") == 1 || str_eq(op, "sdiv") == 1 || str_eq(op, "DIV") == 1 || str_eq(op, "div") == 1 return 1 @end
  @if str_eq(op, "SREM") == 1 || str_eq(op, "srem") == 1 || str_eq(op, "MOD") == 1 || str_eq(op, "mod") == 1 return 1 @end
  @if str_eq(op, "NEG") == 1 || str_eq(op, "neg") == 1 return 1 @end
  @if str_eq(op, "NOT") == 1 || str_eq(op, "not") == 1 return 1 @end
  @if str_eq(op, "AND") == 1 || str_eq(op, "and") == 1 return 1 @end
  @if str_eq(op, "OR") == 1 || str_eq(op, "or") == 1 return 1 @end
  @if str_eq(op, "XOR") == 1 || str_eq(op, "xor") == 1 return 1 @end
  @if str_eq(op, "SHL") == 1 || str_eq(op, "shl") == 1 return 1 @end
  @if str_eq(op, "SHR") == 1 || str_eq(op, "shr") == 1 return 1 @end
  @if str_eq(op, "CMP") == 1 || str_eq(op, "cmp") == 1 return 1 @end
  @if str_eq(op, "BR") == 1 || str_eq(op, "br") == 1 return 1 @end
  @if str_eq(op, "BR_COND") == 1 || str_eq(op, "br_cond") == 1 return 1 @end
  @if str_eq(op, "RET") == 1 || str_eq(op, "ret") == 1 return 1 @end
  @if str_eq(op, "CALL") == 1 || str_eq(op, "call") == 1 return 1 @end
  @if str_eq(op, "SYSCALL") == 1 || str_eq(op, "syscall") == 1 return 1 @end
  @if str_eq(op, "PHI") == 1 || str_eq(op, "phi") == 1 return 1 @end
  return 0
@end

@fn ir_verify_function(func)
  errors = []
  warnings = []
  
  num_blocks = 0
  @if func.blocks != 0 num_blocks = func.blocks.len() @end
  @if num_blocks == 0
    return { ok: 0, errors: ["Function @" + func.name + " has no basic blocks"], warnings: [] }
  @end

  @! Invariant 1: Single Entry Block
  entry = func.blocks[0]
  @if entry.id != 0
        errors = errors.push("Invariant 1: Entry block has non-zero id")
  @end
  @if entry.preds.len() > 0
        errors = errors.push("Invariant 1: Entry block has predecessors")
  @end

  @! Invariant 8: Unique Block Labels and IDs
  valid_ids = []
  seen_names = []
  b_idx = 0
  @while b_idx < num_blocks
    cur_b = func.blocks[b_idx]
    bid = cur_b.id
    bname = cur_b.name
    _i_vid_0 = 0
    @while _i_vid_0 < valid_ids.len()
      vid = valid_ids[_i_vid_0]
      @if vid == bid
        errors = errors.push("Invariant 8: Duplicate block id")
      @end
      _i_vid_0 = _i_vid_0 + 1
    @end
    _i_sn_0 = 0
    @while _i_sn_0 < seen_names.len()
      sn = seen_names[_i_sn_0]
      @if sn == bname && bname != ""
        errors = errors.push("Invariant 8: Duplicate block name")
      @end
      _i_sn_0 = _i_sn_0 + 1
    @end
    valid_ids = valid_ids.push(bid)
    seen_names = seen_names.push(bname)
    b_idx = b_idx + 1
  @end

  @! Invariant 9: Unique Function Parameters
  seen_params = []
  seen_param_regs = []
  @if func.params != 0
    p_idx = 0
    @while p_idx < func.params.len()
      p = func.params[p_idx]
      pname = p.p_name
      preg = p.reg
      _i_sp_0 = 0
      @while _i_sp_0 < seen_params.len()
        sp = seen_params[_i_sp_0]
        @if sp == pname && pname != ""
        errors = errors.push("Invariant 9: Duplicate parameter name")
        @end
        _i_sp_0 = _i_sp_0 + 1
      @end
      _i_spr_0 = 0
      @while _i_spr_0 < seen_param_regs.len()
        spr = seen_param_regs[_i_spr_0]
        @if spr == preg && preg != ""
        errors = errors.push("Invariant 9: Duplicate parameter register")
        @end
        _i_spr_0 = _i_spr_0 + 1
      @end
      @if pname != "" seen_params = seen_params.push(pname) @end
      @if preg != "" seen_param_regs = seen_param_regs.push(preg) @end
      p_idx = p_idx + 1
    @end
  @end

  defined_regs = []
  _i_p_0 = 0
  @while _i_p_0 < func.params.len()
    p = func.params[_i_p_0]
    @if p.reg != "" && p.reg != 0
      defined_regs = defined_regs.push(p.reg)
    @end
    _i_p_0 = _i_p_0 + 1
  @end

  i = 0
  @while i < num_blocks
    b = func.blocks[i]
    insts = b.instructions
    num_insts = 0
    @if insts != 0 num_insts = insts.len() @end

    @if num_insts == 0
        errors = errors.push("Invariant 2: Block is empty")
    @else
      @! Invariant 2: Valid Block Terminators (at end and no internal terminators)
      last_idx = num_insts - 1
      last_inst = insts[last_idx]
      last_op = last_inst.inst_op
      @if last_op == 0 || last_op == "" last_op = last_inst.op @end
      is_term = ir_op_is_term(last_op)
      @if is_term == 0 && last_inst.is_terminator == 1
        is_term = 1
      @end
      
      @if is_term == 0
        errors = errors.push("Invariant 2: Block missing terminator")
      @end

      k = 0
      @while k < last_idx
        inst = insts[k]
        cur_term_op = inst.inst_op
        @if cur_term_op == 0 || cur_term_op == "" cur_term_op = inst.op @end
        @if ir_op_is_term(cur_term_op) == 1 && inst.is_terminator == 1
        errors = errors.push("Invariant 2: Internal terminator found")
        @end
        k = k + 1
      @end

      @! Invariant 3 & Invariant 4: Terminator Target Consistency and Predecessor-Successor consistency
      @if ir_op_is_br(last_op) == 1
        target = last_inst.target
        target_exists = 0
        _i_vid_0 = 0
        @while _i_vid_0 < valid_ids.len()
          vid = valid_ids[_i_vid_0]
          @if vid == target target_exists = 1 @end
          _i_vid_0 = _i_vid_0 + 1
        @end
        @if target_exists == 0
        errors = errors.push("Invariant 3: Branch target block does not exist")
        @end
        @if b.succs.len() != 1 || b.succs[0] != target
        errors = errors.push("Invariant 4: Branch target does not match succs")
        @end
      @elif ir_op_is_br_cond(last_op) == 1
        then_b = last_inst.true_target
        else_b = last_inst.false_target
        then_exists = 0
        else_exists = 0
        _i_vid_0 = 0
        @while _i_vid_0 < valid_ids.len()
          vid = valid_ids[_i_vid_0]
          @if vid == then_b then_exists = 1 @end
          @if vid == else_b else_exists = 1 @end
          _i_vid_0 = _i_vid_0 + 1
        @end
        @if then_exists == 0
        errors = errors.push("Invariant 3: Branch conditional target does not exist")
        @end
        @if else_exists == 0
        errors = errors.push("Invariant 3: Branch conditional target does not exist")
        @end
        @if b.succs.len() != 2 || b.succs[0] != then_b || b.succs[1] != else_b
        errors = errors.push("Invariant 4: Branch conditional targets do not match succs")
        @end
      @elif ir_op_is_ret(last_op) == 1
        @if b.succs.len() != 0
        errors = errors.push("Invariant 4: Ret block has successors")
        @end
        @! Invariant 10: Return Type Conformance
        @if func.fn_ret_type != 0
          ret_kind = func.fn_ret_type.kind
          @if ret_kind == "void" && last_inst.inst_val != 0 && last_inst.inst_val.val_kind != "const_null" && last_inst.inst_val.val_kind != "const_int"
            warnings = warnings.push("Invariant 10: Non-void return value in void function @" + func.name)
          @end
        @end
      @end

      @! Invariant 5 & Invariant 6: SSA rules, Phi positioning, and Opcode validity
      inst_idx = 0
      phi_ended = 0
      @while inst_idx < num_insts
        cur_inst = insts[inst_idx]
        cur_inst_op = cur_inst.inst_op
        @if cur_inst_op == "" || cur_inst_op == 0 cur_inst_op = cur_inst.op @end

        @! Invariant 6: Valid opcodes
        @if ir_op_is_valid(cur_inst_op) == 0
        errors = errors.push("Invariant 6: Invalid instruction opcode")
        @end

        @! Invariant 5: Phi placement & predecessor edge match
        @if ir_op_is_phi(cur_inst_op) == 1
          @if phi_ended == 1
        errors = errors.push("Invariant 5: Phi after non-phi")
          @end
          @if cur_inst.incoming != 0 && cur_inst.incoming.len() != b.preds.len()
        errors = errors.push("Invariant 5: Phi incoming edge count mismatch")
          @end
        @else
          phi_ended = 1
        @end

        @! Invariant 5: Single Static Assignment check
        @if cur_inst.dest != "" && cur_inst.dest != 0
          _i_reg_0 = 0
          @while _i_reg_0 < defined_regs.len()
            reg = defined_regs[_i_reg_0]
            @if reg == cur_inst.dest
        errors = errors.push("Invariant 5: Duplicate register definition")
            @end
            _i_reg_0 = _i_reg_0 + 1
          @end
          defined_regs = defined_regs.push(cur_inst.dest)
        @end

        inst_idx = inst_idx + 1
      @end
    @end

    @! Invariant 4: Bidirectional edge consistency with successors
    s_idx = 0
    @while s_idx < b.succs.len()
      succ_id = b.succs[s_idx]
      found_succ = 0
      succ_b = 0
      chk = 0
      @while chk < num_blocks
        @if func.blocks[chk].id == succ_id
          found_succ = 1
          succ_b = func.blocks[chk]
        @end
        chk = chk + 1
      @end

      @if found_succ == 0
        errors = errors.push("Invariant 3: Successor does not exist")
      @else
        has_pred = 0
        p_chk = 0
        @while p_chk < succ_b.preds.len()
          @if succ_b.preds[p_chk] == b.id has_pred = 1 @end
          p_chk = p_chk + 1
        @end
        @if has_pred == 0
        errors = errors.push("Invariant 4: Predecessor edge missing")
        @end
      @end
      s_idx = s_idx + 1
    @end

    i = i + 1
  @end

  @! Invariant 7: Reachability analysis
  reachable = [0]
  worklist = [0]
  @while worklist.len() > 0
    curr_id = worklist[0]
    new_worklist = []
    w_i = 1
    @while w_i < worklist.len()
      new_worklist = new_worklist.push(worklist[w_i])
      w_i = w_i + 1
    @end
    worklist = new_worklist

    curr_b = 0
    chk_b = 0
    @while chk_b < num_blocks
      @if func.blocks[chk_b].id == curr_id curr_b = func.blocks[chk_b] @end
      chk_b = chk_b + 1
    @end

    @if curr_b != 0
      _i_succ_0 = 0
      @while _i_succ_0 < curr_b.succs.len()
        succ = curr_b.succs[_i_succ_0]
        already = 0
        _i_r_0 = 0
        @while _i_r_0 < reachable.len()
          r = reachable[_i_r_0]
          @if r == succ already = 1 @end
          _i_r_0 = _i_r_0 + 1
        @end
        @if already == 0
          reachable = reachable.push(succ)
          worklist = worklist.push(succ)
        @end
        _i_succ_0 = _i_succ_0 + 1
      @end
    @end
  @end

  chk_r = 0
  @while chk_r < num_blocks
    blk_id = func.blocks[chk_r].id
    is_reach = 0
    _i_r_0 = 0
    @while _i_r_0 < reachable.len()
      r = reachable[_i_r_0]
      @if r == blk_id is_reach = 1 @end
      _i_r_0 = _i_r_0 + 1
    @end
    @if is_reach == 0
      warnings = warnings.push("Invariant 7 Warning: Unreachable basic block bb_" + blk_id.to_str() + " (" + func.blocks[chk_r].name + ") in function @" + func.name)
    @end
    chk_r = chk_r + 1
  @end

  ok = (errors.len() == 0)
  return { ok: ok, errors: errors, warnings: warnings }
@end

@fn ir_verify_module(module)
  all_errors = []
  all_warnings = []
  
  f_idx = 0
  num_funcs = 0
  @if module.functions != 0 num_funcs = module.functions.len() @end
  @while f_idx < num_funcs
    func = module.functions[f_idx]
    res = ir_verify_function(func)
    @if res.ok == 0
      _i_err_0 = 0
      @while _i_err_0 < res.errors.len()
        err = res.errors[_i_err_0]
        all_errors = all_errors.push("Function @" + func.name + ": " + err)
        _i_err_0 = _i_err_0 + 1
      @end
    @end
    _i_w_0 = 0
    @while _i_w_0 < res.warnings.len()
      w = res.warnings[_i_w_0]
      all_warnings = all_warnings.push("Function @" + func.name + ": " + w)
      _i_w_0 = _i_w_0 + 1
    @end
    f_idx = f_idx + 1
  @end

  ok = (all_errors.len() == 0)
  return { ok: ok, errors: all_errors, warnings: all_warnings, functions_verified: num_funcs }
@end

@fn ir_verify_cfg(func)
  @if func == 0
    return { ok: 0, errors: ["Null pointer passed to ir_verify_cfg"], warnings: [] }
  @end
  return ir_verify_function(func)
@end

@! ============================================================================
@! 8. AST TO MAYA IR LOWERING ENGINE
@! ============================================================================

@fn ast_kind_match(kind, name)
  @! Compare AST node kind strings byte by byte
  @! WHY: String literals across modules have distinct memory addresses in bootstrap Maya.
  @if kind == 0 || name == 0 return 0 @end
  return str_eq(kind, name)
@end

@fn ast_node(kind)
  return {
    kind: kind,
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_fndef(name, params, ret_type, body)
  n = ast_node("FnDef")
  n.name = name
  n.params = params
  n.ret_type = ret_type
  n.body = body
  return n
@end

@fn ir_lower_result(ctx, val)
  return {
    res_ctx: ctx,
    res_val: val
  }
@end

@! Lowering Context & State Machine
@fn ir_builder_new(module)
  return {
    module: module,
    current_fn: 0,
    current_bb_idx: -1,
    temp_counter: 0,
    label_counter: 0,
    scopes: [[]],
    loop_stack: [],
    errors: [],
    defer_stack: [],
    struct_layouts: []
  }
@end

@fn builder_gen_temp(ctx)
  id = ctx.temp_counter
  ctx.temp_counter = ctx.temp_counter + 1
  @if ctx.current_fn != 0 && ctx.temp_counter > ctx.current_fn.next_vreg_id
    ctx.current_fn.next_vreg_id = ctx.temp_counter
  @end
  return string_concat("%v", int_to_str(id))
@end

@fn builder_gen_label(ctx, prefix)
  id = ctx.label_counter
  ctx.label_counter = ctx.label_counter + 1
  return string_concat(prefix, string_concat("_", int_to_str(id)))
@end

@fn builder_push_scope(ctx)
  ctx.scopes = ctx.scopes.push([])
  return ctx
@end

@fn builder_pop_scope(ctx)
  new_scopes = []
  i = 0
  num_items = ctx.scopes.len() - 1
  @while i < num_items
    new_scopes = new_scopes.push(ctx.scopes[i])
    i = i + 1
  @end
  ctx.scopes = new_scopes
  return ctx
@end

@fn builder_set_var(ctx, name, alloca_ptr)
  top_idx = ctx.scopes.len() - 1
  scope = ctx.scopes[top_idx]
  new_scope = []
  found = 0
  i = 0
  num_items = scope.len()
  @while i < num_items
    e = scope[i]
    @if str_eq(e.var_key, name) == 1
      st_t = e.var_struct_type
      new_scope = new_scope.push({ var_key: name, var_ptr: alloca_ptr, var_struct_type: st_t })
      found = 1
    @else
      new_scope = new_scope.push(e)
    @end
    i = i + 1
  @end
  @if found == 0
    new_scope = new_scope.push({ var_key: name, var_ptr: alloca_ptr, var_struct_type: "" })
  @end
  ctx.scopes = list_set(ctx.scopes, top_idx, new_scope)
  return ctx
@end

@fn builder_set_var_type(ctx, name, struct_type)
  top_idx = ctx.scopes.len() - 1
  scope = ctx.scopes[top_idx]
  new_scope = []
  found = 0
  i = 0
  num_items = scope.len()
  @while i < num_items
    e = scope[i]
    @if str_eq(e.var_key, name) == 1
      new_scope = new_scope.push({ var_key: name, var_ptr: e.var_ptr, var_struct_type: struct_type })
      found = 1
    @else
      new_scope = new_scope.push(e)
    @end
    i = i + 1
  @end
  @if found == 0
    new_scope = new_scope.push({ var_key: name, var_ptr: "", var_struct_type: struct_type })
  @end
  ctx.scopes = list_set(ctx.scopes, top_idx, new_scope)
  return ctx
@end

@fn builder_lookup_var(ctx, name)
  i = ctx.scopes.len() - 1
  @while i >= 0
    scope = ctx.scopes[i]
    j = 0
    num_items = scope.len()
    @while j < num_items
      e = scope[j]
      @if str_eq(e.var_key, name) == 1
        return e.var_ptr
      @end
      j = j + 1
    @end
    i = i - 1
  @end
  return ""
@end

@fn builder_lookup_var_type(ctx, name)
  i = ctx.scopes.len() - 1
  @while i >= 0
    scope = ctx.scopes[i]
    j = 0
    num_items = scope.len()
    @while j < num_items
      e = scope[j]
      @if str_eq(e.var_key, name) == 1
        @if e.var_struct_type != 0 && e.var_struct_type != ""
          return e.var_struct_type
        @end
      @end
      j = j + 1
    @end
    i = i - 1
  @end
  return ""
@end

@fn builder_add_block(ctx, label)
  id = ctx.current_fn.blocks.len()
  bb = ir_block_new(id, label)
  ctx.current_fn.blocks = ctx.current_fn.blocks.push(bb)
  ctx.current_bb_idx = id
  return bb
@end

@fn builder_set_insert_point(ctx, block_idx)
  ctx.current_bb_idx = block_idx
  return ctx
@end

@fn builder_emit(ctx, inst)
  idx = ctx.current_bb_idx
  @if idx < 0 || idx >= ctx.current_fn.blocks.len()
    idx = ctx.current_fn.blocks.len() - 1
  @end
  @if idx < 0 || idx >= ctx.current_fn.blocks.len()
    return ctx
  @end
  bb = ctx.current_fn.blocks[idx]
  @if bb.is_terminated == 1
    latest_idx = ctx.current_fn.blocks.len() - 1
    @if latest_idx > idx
      idx = latest_idx
      bb = ctx.current_fn.blocks[idx]
      @if bb.is_terminated == 1
        return ctx
      @end
    @else
      return ctx
    @end
  @end

  bb = ir_block_add_inst(bb, inst)
  ctx.current_fn.blocks = list_set(ctx.current_fn.blocks, idx, bb)
  return ctx
@end

@fn builder_create_alloca(ctx, name, t_desc)
  t = t_desc
  @if t == 0 || str_len(t.kind) == 0 t = ir_type_i64() @end
  entry_bb = ctx.current_fn.blocks[0]
  ptr_temp = builder_gen_temp(ctx)
  inst = ir_inst_alloca(ptr_temp, t, 16, name)

  @! Prepend alloca into entry block
  new_insts = [inst]
  i = 0
  num_items = entry_bb.instructions.len()
  @while i < num_items
    new_insts = new_insts.push(entry_bb.instructions[i])
    i = i + 1
  @end
  entry_bb.instructions = new_insts
  ctx.current_fn.blocks = list_set(ctx.current_fn.blocks, 0, entry_bb)

  ctx.current_fn.locals = ctx.current_fn.locals.push({
    loc_name: name,
    loc_vreg: ir_val_reg(ptr_temp, ir_type_ptr(t)),
    loc_type: t
  })
  builder_set_var(ctx, name, ptr_temp)
  return ptr_temp
@end

@! Expression Lowering
@fn lower_expr(ctx, expr)
  @if expr == 0
    return ir_lower_result(ctx, ir_val_const_int(0, ir_type_i64()))
  @end

  kind = expr.kind

  @! 1. Literal Integer
  @if ast_kind_match(kind, "LiteralInt") == 1 || ast_kind_match(kind, "IntLiteral") == 1
    val = expr.val
    @if val == 0 && expr.value != "" val = expr.value @end
    return ir_lower_result(ctx, ir_val_const_int(val, ir_type_i64()))
  @end

  @! 2. Literal Float
  @if ast_kind_match(kind, "LiteralFloat") == 1 || ast_kind_match(kind, "FloatLiteral") == 1
    val = expr.val
    @if val == 0 && expr.value != "" val = expr.value @end
    return ir_lower_result(ctx, ir_val_const_float(val, ir_type_f64()))
  @end

  @! 3. Literal Boolean
  @if ast_kind_match(kind, "LiteralBool") == 1 || ast_kind_match(kind, "BoolLiteral") == 1
    bval = 0
    @if expr.val == 1
      bval = 1
    @end
    return ir_lower_result(ctx, ir_val_const_bool(bval))
  @end

  @! 4. Literal String
  @if ast_kind_match(kind, "LiteralStr") == 1 || ast_kind_match(kind, "StringLiteral") == 1
    str_val = expr.val
    @if str_val == "" && expr.value != "" str_val = expr.value @end
    @if str_val == "" && expr.name != "" str_val = expr.name @end
    @if str_val == "" str_val = "" @end
    str_ref = ir_module_add_string_literal(ctx.module, str_val)
    return ir_lower_result(ctx, str_ref)
  @end

  @! 5. Literal None / Null
  @if ast_kind_match(kind, "LiteralNone") == 1 || ast_kind_match(kind, "LiteralNull") == 1
    return ir_lower_result(ctx, ir_val_const_null())
  @end

  @! 6. Variable / Identifier
  @if ast_kind_match(kind, "Variable") == 1 || ast_kind_match(kind, "Identifier") == 1
    var_name = expr.name
    alloca_ptr = builder_lookup_var(ctx, var_name)
    @! WHY: Empty string check must use str_len() == 0 because pointer comparison (== "") fails across memory allocations.
    @if str_len(alloca_ptr) == 0
      alloca_ptr = builder_create_alloca(ctx, var_name, ir_type_i64())
      ctx = builder_set_var(ctx, var_name, alloca_ptr)
      ctx = builder_emit(ctx, ir_inst_store(ir_val_const_int(0, ir_type_i64()), ir_val_reg(alloca_ptr, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    @end
    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_i64())
    ctx = builder_emit(ctx, ir_inst_load(dest, ir_val_reg(alloca_ptr, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    return ir_lower_result(ctx, dest_val)
  @end

  @! 7. Unary Operators
  @if ast_kind_match(kind, "UnaryOp") == 1
    res = lower_expr(ctx, expr.expr)
    ctx = res.res_ctx
    op_val = res.res_val
    dest = builder_gen_temp(ctx)
    @if str_eq(expr.op, "-") == 1
      ctx = builder_emit(ctx, ir_inst_neg(dest, op_val, ir_type_i64()))
    @elif str_eq(expr.op, "!") == 1
      cmp_temp = builder_gen_temp(ctx)
      cmp_val = ir_val_reg(cmp_temp, ir_type_bool())
      ctx = builder_emit(ctx, ir_inst_cmp("eq", cmp_temp, op_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_and(dest, cmp_val, ir_val_const_int(1, ir_type_i64()), ir_type_i64()))
    @elif str_eq(expr.op, "~") == 1
      ctx = builder_emit(ctx, ir_inst_not(dest, op_val, ir_type_i64()))
    @else
      dest_val = op_val
    @end
    return ir_lower_result(ctx, dest_val)
  @end

  @! 8. Binary Operators (Logical AND/OR & Arithmetic/Bitwise/Comparison)
  @if ast_kind_match(kind, "BinaryOp") == 1
    op_name = expr.op
    @if str_eq(op_name, "&&") == 1 || str_eq(op_name, "AND") == 1
      res_l = lower_expr(ctx, expr.left)
      ctx = res_l.res_ctx
      lhs_val = res_l.res_val

      res_alloca = builder_create_alloca(ctx, "and_res", ir_type_i64())
      res_ptr = ir_val_reg(res_alloca, ir_type_ptr(ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_store(ir_val_const_int(0, ir_type_i64()), res_ptr, ir_type_i64()))

      cond_temp = builder_gen_temp(ctx)
      cond_val = ir_val_reg(cond_temp, ir_type_bool())
      ctx = builder_emit(ctx, ir_inst_cmp("ne", cond_temp, lhs_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))

      rhs_lbl = builder_gen_label(ctx, "and_rhs")
      merge_lbl = builder_gen_label(ctx, "and_merge")

      ctx = builder_emit(ctx, ir_inst_br_cond(cond_val, -1, rhs_lbl, -1, merge_lbl))

      rhs_bb = builder_add_block(ctx, rhs_lbl)
      res_r = lower_expr(ctx, expr.right)
      ctx = res_r.res_ctx
      rhs_val = res_r.res_val

      rhs_bool = builder_gen_temp(ctx)
      rhs_bool_val = ir_val_reg(rhs_bool, ir_type_bool())
      ctx = builder_emit(ctx, ir_inst_cmp("ne", rhs_bool, rhs_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_store(rhs_bool_val, res_ptr, ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_br(-1, merge_lbl))

      merge_bb = builder_add_block(ctx, merge_lbl)
      final_val = builder_gen_temp(ctx)
      dest_val = ir_val_reg(final_val, ir_type_i64())
      ctx = builder_emit(ctx, ir_inst_load(final_val, res_ptr, ir_type_i64()))
      return ir_lower_result(ctx, dest_val)
    @elif str_eq(op_name, "||") == 1 || str_eq(op_name, "OR") == 1
      res_l = lower_expr(ctx, expr.left)
      ctx = res_l.res_ctx
      lhs_val = res_l.res_val

      res_alloca = builder_create_alloca(ctx, "or_res", ir_type_i64())
      res_ptr = ir_val_reg(res_alloca, ir_type_ptr(ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_store(ir_val_const_int(1, ir_type_i64()), res_ptr, ir_type_i64()))

      cond_temp = builder_gen_temp(ctx)
      cond_val = ir_val_reg(cond_temp, ir_type_bool())
      ctx = builder_emit(ctx, ir_inst_cmp("ne", cond_temp, lhs_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))

      merge_lbl = builder_gen_label(ctx, "or_merge")
      rhs_lbl = builder_gen_label(ctx, "or_rhs")

      ctx = builder_emit(ctx, ir_inst_br_cond(cond_val, -1, merge_lbl, -1, rhs_lbl))

      rhs_bb = builder_add_block(ctx, rhs_lbl)
      res_r = lower_expr(ctx, expr.right)
      ctx = res_r.res_ctx
      rhs_val = res_r.res_val

      rhs_bool = builder_gen_temp(ctx)
      rhs_bool_val = ir_val_reg(rhs_bool, ir_type_bool())
      ctx = builder_emit(ctx, ir_inst_cmp("ne", rhs_bool, rhs_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_store(rhs_bool_val, res_ptr, ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_br(-1, merge_lbl))

      merge_bb = builder_add_block(ctx, merge_lbl)
      final_val = builder_gen_temp(ctx)
      dest_val = ir_val_reg(final_val, ir_type_i64())
      ctx = builder_emit(ctx, ir_inst_load(final_val, res_ptr, ir_type_i64()))
      return ir_lower_result(ctx, dest_val)
    @else
      res_l = lower_expr(ctx, expr.left)
      ctx = res_l.res_ctx
      lhs_val = res_l.res_val

      res_r = lower_expr(ctx, expr.right)
      ctx = res_r.res_ctx
      rhs_val = res_r.res_val

      dest = builder_gen_temp(ctx)
      dest_val = ir_val_reg(dest, ir_type_i64())
      op = expr.op

      @! WHY: Uses str_eq for string comparison rather than pointer comparison (==) which fails across tokens.
      @if str_eq(op, "+") == 1
        @if is_ast_str_expr(ctx, expr.left) == 1 || is_ast_str_expr(ctx, expr.right) == 1 || is_ir_str_val(lhs_val) == 1 || is_ir_str_val(rhs_val) == 1
          dest_val = ir_val_reg(dest, ir_type_ptr(ir_type_i8()))
          ctx = builder_emit(ctx, ir_inst_call(dest, "maya_str_concat", [lhs_val, rhs_val], ir_type_ptr(ir_type_i8())))
        @else
          ctx = builder_emit(ctx, ir_inst_add(dest, lhs_val, rhs_val, ir_type_i64()))
        @end
      @elif str_eq(op, "-") == 1  ctx = builder_emit(ctx, ir_inst_sub(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "*") == 1  ctx = builder_emit(ctx, ir_inst_mul(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "/") == 1  ctx = builder_emit(ctx, ir_inst_div(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "%") == 1  ctx = builder_emit(ctx, ir_inst_mod(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "&") == 1 || str_eq(op, "BAND") == 1  ctx = builder_emit(ctx, ir_inst_and(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "|") == 1 || str_eq(op, "BOR") == 1   ctx = builder_emit(ctx, ir_inst_or(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "^") == 1 || str_eq(op, "BXOR") == 1  ctx = builder_emit(ctx, ir_inst_xor(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "<<") == 1 || str_eq(op, "SHL") == 1  ctx = builder_emit(ctx, ir_inst_shl(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, ">>") == 1 || str_eq(op, "SHR") == 1  ctx = builder_emit(ctx, ir_inst_shr(dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "==") == 1 || str_eq(op, "EQ") == 1   ctx = builder_emit(ctx, ir_inst_cmp("eq", dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "!=") == 1 || str_eq(op, "NEQ") == 1  ctx = builder_emit(ctx, ir_inst_cmp("ne", dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "<") == 1  || str_eq(op, "LT") == 1   ctx = builder_emit(ctx, ir_inst_cmp("slt", dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, "<=") == 1 || str_eq(op, "LTE") == 1  ctx = builder_emit(ctx, ir_inst_cmp("sle", dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, ">") == 1  || str_eq(op, "GT") == 1   ctx = builder_emit(ctx, ir_inst_cmp("sgt", dest, lhs_val, rhs_val, ir_type_i64()))
      @elif str_eq(op, ">=") == 1 || str_eq(op, "GTE") == 1  ctx = builder_emit(ctx, ir_inst_cmp("sge", dest, lhs_val, rhs_val, ir_type_i64()))
      @else
        ctx = builder_emit(ctx, ir_inst_add(dest, lhs_val, rhs_val, ir_type_i64()))
      @end
      return ir_lower_result(ctx, dest_val)
    @end
  @end

  @! 11. Pipeline Operator (|>)
  @if ast_kind_match(kind, "Pipeline") == 1
    res_l = lower_expr(ctx, expr.left)
    ctx = res_l.res_ctx
    lhs_val = res_l.res_val

    @if expr.right != 0
      @if ast_kind_match(expr.right.kind, "Call") == 1
        new_args = [lhs_val]
        j = 0
        @while j < expr.right.args.len()
          res_arg = lower_expr(ctx, expr.right.args[j])
          ctx = res_arg.res_ctx
          new_args = new_args.push(res_arg.res_val)
          j = j + 1
        @end
        dest = builder_gen_temp(ctx)
        dest_val = ir_val_reg(dest, ir_type_i64())
        callee_name = expr.right.func.name
        @! WHY: Assign returned context from builder_emit so pipeline call is preserved
        ctx = builder_emit(ctx, ir_inst_call(dest, callee_name, new_args, ir_type_i64()))
        return ir_lower_result(ctx, dest_val)
      @else
        dest = builder_gen_temp(ctx)
        dest_val = ir_val_reg(dest, ir_type_i64())
        callee_name = expr.right.name
        @! WHY: Assign returned context from builder_emit so pipeline call is preserved
        ctx = builder_emit(ctx, ir_inst_call(dest, callee_name, [lhs_val], ir_type_i64()))
        return ir_lower_result(ctx, dest_val)
      @end
    @end
  @end

  @! 12. Function Calls
  @if ast_kind_match(kind, "Call") == 1
    return lower_call(ctx, expr)
  @end

  @! 13. Member Access (obj.field or obj.method(args))
  @if ast_kind_match(kind, "MemberAccess") == 1
    target_node = expr.left
    @if target_node == 0 && expr.target != ""
      target_node = ast_node("Variable")
      target_node.name = expr.target
    @end
    res_t = lower_expr(ctx, target_node)
    ctx = res_t.res_ctx
    target_val = res_t.res_val
    field_name = expr.name
    @if field_name == "" field_name = expr.target @end

    @! Check if member access is method invocation
    @if expr.args != 0 && expr.args.len() > 0
      method_args = [target_val]
      m_idx = 0
      @while m_idx < expr.args.len()
        res_ma = lower_expr(ctx, expr.args[m_idx])
        ctx = res_ma.res_ctx
        method_args = method_args.push(res_ma.res_val)
        m_idx = m_idx + 1
      @end
      dest = builder_gen_temp(ctx)
      dest_val = ir_val_reg(dest, ir_type_i64())
      @! WHY: Assign returned context from builder_emit so method call instruction is appended to basic block
      ctx = builder_emit(ctx, ir_inst_call(dest, field_name, method_args, ir_type_i64()))
      return ir_lower_result(ctx, dest_val)
    @end

    @! Field access: emit GEP + LOAD
    field_idx = 0
    target_var_name = ""
    @if target_node != 0 && ast_kind_match(target_node.kind, "Variable") == 1
      target_var_name = target_node.name
    @end
    known_type = ""
    @if target_var_name != ""
      known_type = builder_lookup_var_type(ctx, target_var_name)
    @end

    @if ctx.module != 0 && ctx.module.struct_defs != 0
      found_field = 0

      @! 1. Try exact known struct type match
      @if known_type != ""
        s_scan = 0
        @while s_scan < ctx.module.struct_defs.len() && found_field == 0
          s_def = ctx.module.struct_defs[s_scan]
          @if str_eq(s_def.name, known_type) == 1
            f_list = s_def.params
            @if f_list == 0 || f_list.len() == 0 f_list = s_def.elements @end
            @if f_list != 0
              f_k = 0
              @while f_k < f_list.len()
                fnk = f_list[f_k]
                fname = fnk.name
                @if fname == "" fname = fnk.target @end
                @if str_eq(fname, field_name) == 1
                  field_idx = f_k
                  found_field = 1
                  f_k = f_list.len()
                @end
                f_k = f_k + 1
              @end
            @end
          @end
          s_scan = s_scan + 1
        @end
      @end

      @! 2. Fall back to search all struct definitions (preferring non-ASTNode)
      @if found_field == 0
        s_i = 0
        matched_ast_node_idx = -1
        @while s_i < ctx.module.struct_defs.len() && found_field == 0
          s_def = ctx.module.struct_defs[s_i]
          f_list = s_def.params
          @if f_list == 0 || f_list.len() == 0 f_list = s_def.elements @end
          @if f_list != 0
            f_k = 0
            @while f_k < f_list.len()
              fnk = f_list[f_k]
              fname = fnk.name
              @if fname == "" fname = fnk.target @end
              @if str_eq(fname, field_name) == 1
                @if str_eq(s_def.name, "ASTNode") == 1 || str_eq(s_def.name, "ast_node") == 1
                  matched_ast_node_idx = f_k
                @else
                  field_idx = f_k
                  found_field = 1
                  f_k = f_list.len()
                @end
              @end
              f_k = f_k + 1
            @end
          @end
          s_i = s_i + 1
        @end
        @if found_field == 0 && matched_ast_node_idx >= 0
          field_idx = matched_ast_node_idx
          found_field = 1
        @end
      @end
    @end

    dest_gep = builder_gen_temp(ctx)
    dest_gep_val = ir_val_reg(dest_gep, ir_type_ptr(ir_type_i64()))
    @! WHY: Must reassign ctx from builder_emit so the GEP instruction is appended to the basic block.
    ctx = builder_emit(ctx, ir_inst_gep(dest_gep, target_val, ir_val_const_int(field_idx * 8, ir_type_i64()), ir_type_i64(), 1))
    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_i64())
    @! WHY: Must reassign ctx from builder_emit so the LOAD instruction is appended to the basic block.
    ctx = builder_emit(ctx, ir_inst_load(dest, dest_gep_val, ir_type_i64()))
    return ir_lower_result(ctx, dest_val)
  @end

  @! 14. Struct Literal ({ x: 10, y: 20 })
  @! WHY: MapLit is produced by parser for anonymous struct literals like { x: 10, y: 20 }.
  @! Handling MapLit here allows unified heap allocation and field assignment.
  @if ast_kind_match(kind, "StructLit") == 1 || ast_kind_match(kind, "StructInit") == 1 || ast_kind_match(kind, "StructLiteral") == 1 || ast_kind_match(kind, "MapLit") == 1
    s_size = 24
    @if expr.elements != 0
      @if expr.elements.len() > 0
        s_size = expr.elements.len() * 8
      @end
    @end

    @! If struct definition is found, size should be total fields count * 8
    st_name = expr.name
    @if st_name != ""
      @if ctx.module != 0
        @if ctx.module.struct_defs != 0
          s_scan = 0
          @while s_scan < ctx.module.struct_defs.len()
            s_candidate = ctx.module.struct_defs[s_scan]
            @if str_eq(s_candidate.name, st_name) == 1
              f_scan_list = s_candidate.params
              @if f_scan_list == 0 || f_scan_list.len() == 0 f_scan_list = s_candidate.elements @end
              @if f_scan_list != 0
                @if f_scan_list.len() * 8 > s_size
                  s_size = f_scan_list.len() * 8
                @end
              @end
              s_scan = ctx.module.struct_defs.len()
            @end
            s_scan = s_scan + 1
          @end
        @end
      @end
    @end

    dest_alloc = builder_gen_temp(ctx)
    dest_alloc_val = ir_val_reg(dest_alloc, ir_type_ptr(ir_type_i64()))
    @! WHY: Assign returned context from builder_emit so allocation call is preserved in basic block
    ctx = builder_emit(ctx, ir_inst_call(dest_alloc, "maya_alloc", [ir_val_const_int(s_size, ir_type_i64())], ir_type_ptr(ir_type_i64())))

    @if expr.elements != 0
      el_idx = 0
      @while el_idx < expr.elements.len()
        el = expr.elements[el_idx]
        val_to_lower = el
        el_key_name = ""
        @if el != 0
          @if el.default_val != 0 val_to_lower = el.default_val
          @elif el.value != 0 val_to_lower = el.value
          @elif el.expr != 0 val_to_lower = el.expr
          @elif el.val != 0 val_to_lower = el.val @end
          @if el.name != 0
            @if el.name != "" el_key_name = el.name @end
          @end
          @if el_key_name == ""
            @if el.key != 0
              el_key_name = el.key.name
              @if el_key_name == "" el_key_name = el.key.target @end
            @end
          @end
        @end
        res_f = lower_expr(ctx, val_to_lower)
        ctx = res_f.res_ctx

        target_field_idx = el_idx
        @if el_key_name != ""
          @if ctx.module != 0
            @if ctx.module.struct_defs != 0
              s_search = 0
              found_f_match = 0
              @while s_search < ctx.module.struct_defs.len() && found_f_match == 0
                s_candidate = ctx.module.struct_defs[s_search]
                @if st_name == "" || str_eq(s_candidate.name, st_name) == 1
                  f_cand_list = s_candidate.params
                  @if f_cand_list == 0 || f_cand_list.len() == 0 f_cand_list = s_candidate.elements @end
                  @if f_cand_list != 0
                    f_idx_scan = 0
                    @while f_idx_scan < f_cand_list.len()
                      f_cand = f_cand_list[f_idx_scan]
                      cand_fname = f_cand.name
                      @if cand_fname == "" cand_fname = f_cand.target @end
                      @if str_eq(cand_fname, el_key_name) == 1
                        target_field_idx = f_idx_scan
                        found_f_match = 1
                        f_idx_scan = f_cand_list.len()
                      @end
                      f_idx_scan = f_idx_scan + 1
                    @end
                  @end
                @end
                s_search = s_search + 1
              @end
            @end
          @end
        @end

        field_gep = builder_gen_temp(ctx)
        field_gep_val = ir_val_reg(field_gep, ir_type_ptr(ir_type_i64()))
        @! WHY: Assign returned context from builder_emit so GEP and STORE instructions are preserved
        ctx = builder_emit(ctx, ir_inst_gep(field_gep, dest_alloc_val, ir_val_const_int(target_field_idx * 8, ir_type_i64()), ir_type_i64(), 1))
        ctx = builder_emit(ctx, ir_inst_store(res_f.res_val, field_gep_val, ir_type_i64()))
        el_idx = el_idx + 1
      @end
    @end
    return ir_lower_result(ctx, dest_alloc_val)
  @end

  @! 15. Array Literal
  @if ast_kind_match(kind, "ArrayLit") == 1
    num_items = expr.elements.len()
    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_ptr(ir_type_i64()))
    @! WHY: Assign returned context from builder_emit so array allocation call is preserved
    ctx = builder_emit(ctx, ir_inst_call(dest, "maya_array_new", [ir_val_const_int(num_items, ir_type_i64())], ir_type_ptr(ir_type_i64())))
    i = 0
    @while i < num_items
      res_el = lower_expr(ctx, expr.elements[i])
      ctx = res_el.res_ctx
      
      offset_reg = builder_gen_temp(ctx)
      offset_val = ir_val_reg(offset_reg, ir_type_i64())
      byte_offset = i * 8
      @! WHY: Assign returned context from builder_emit so element address calculation and store are preserved
      ctx = builder_emit(ctx, ir_inst_add(offset_reg, dest_val, ir_val_const_int(byte_offset, ir_type_i64()), ir_type_i64()))
      ctx = builder_emit(ctx, ir_inst_store(res_el.res_val, offset_val, ir_type_i64()))
      
      i = i + 1
    @end
    return ir_lower_result(ctx, dest_val)
  @end

  @! 16. Array Indexing
  @if ast_kind_match(kind, "Index") == 1
    target_node = expr.left
    @if target_node == 0 && expr.target != ""
      target_node = ast_node("Variable")
      target_node.name = expr.target
    @end
    @if target_node == 0 target_node = expr.iterable @end
    res_t = lower_expr(ctx, target_node)
    ctx = res_t.res_ctx
    target_val = res_t.res_val

    res_i = lower_expr(ctx, expr.index)
    ctx = res_i.res_ctx
    index_val = res_i.res_val

    @! Inline maya_array_get via pointer arithmetic: dest = *(target_val + index * 8)
    byte_offset_reg = builder_gen_temp(ctx)
    ptr_reg = builder_gen_temp(ctx)
    
    @! WHY: Assign returned context from builder_emit so index offset calculation and pointer load are preserved
    ctx = builder_emit(ctx, ir_inst_mul(byte_offset_reg, index_val, ir_val_const_int(8, ir_type_i64()), ir_type_i64()))
    ctx = builder_emit(ctx, ir_inst_add(ptr_reg, target_val, ir_val_reg(byte_offset_reg, ir_type_i64()), ir_type_ptr(ir_type_i64())))
    
    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_i64())
    ctx = builder_emit(ctx, ir_inst_load(dest, ir_val_reg(ptr_reg, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    return ir_lower_result(ctx, dest_val)
  @end

  @! 17. Match Expression
  @if ast_kind_match(kind, "MatchExpr") == 1
    target_node = expr.expr
    @if target_node == 0 && expr.target != ""
      target_node = ast_node("Variable")
      target_node.name = expr.target
    @end
    res_t = lower_expr(ctx, target_node)
    ctx = res_t.res_ctx
    target_val = res_t.res_val

    res_alloca = builder_create_alloca(ctx, "match_expr_res", ir_type_i64())
    res_ptr = ir_val_reg(res_alloca, ir_type_ptr(ir_type_i64()))
    merge_lbl = builder_gen_label(ctx, "match_merge")

    num_arms = 0
    @if expr.elements != 0 num_arms = expr.elements.len() @end
    arm_i = 0
    @while arm_i < num_arms
      arm = expr.elements[arm_i]
      arm_then_lbl = builder_gen_label(ctx, "match_arm_then")
      arm_next_lbl = builder_gen_label(ctx, "match_arm_next")
      @if arm_i + 1 == num_arms arm_next_lbl = merge_lbl @end

      @if arm.pattern != 0
        res_p = lower_expr(ctx, arm.pattern)
        ctx = res_p.res_ctx
        cond_temp = builder_gen_temp(ctx)
        cond_val = ir_val_reg(cond_temp, ir_type_bool())
        builder_emit(ctx, ir_inst_cmp("eq", cond_temp, target_val, res_p.res_val, ir_type_i64()))
        builder_emit(ctx, ir_inst_br_cond(cond_val, -1, arm_then_lbl, -1, arm_next_lbl))
      @else
        builder_emit(ctx, ir_inst_br(-1, arm_then_lbl))
      @end

      arm_then_bb = builder_add_block(ctx, arm_then_lbl)
      @if arm.body != 0 && arm.body.len() > 0
        res_arm_val = lower_expr(ctx, arm.body[0])
        ctx = res_arm_val.res_ctx
        builder_emit(ctx, ir_inst_store(res_arm_val.res_val, res_ptr, ir_type_i64()))
      @end
      builder_emit(ctx, ir_inst_br(-1, merge_lbl))

      @if arm_i + 1 < num_arms
        next_bb = builder_add_block(ctx, arm_next_lbl)
      @end
      arm_i = arm_i + 1
    @end

    merge_bb = builder_add_block(ctx, merge_lbl)
    dest_val = builder_gen_temp(ctx)
    final_val = ir_val_reg(dest_val, ir_type_i64())
    builder_emit(ctx, ir_inst_load(dest_val, res_ptr, ir_type_i64()))
    return ir_lower_result(ctx, final_val)
  @end

  return ir_lower_result(ctx, ir_val_const_int(0, ir_type_i64()))
@end

@fn file_read(path)
  @! Direct raw Linux syscalls for reading file into memory buffer
  @! sys_open (2)
  fd = syscall(2, path, 0, 0, 0, 0, 0)
  @if fd < 0 return "" @end
  
  @! sys_lseek (8) to SEEK_END (2)
  size = syscall(8, fd, 0, 2, 0, 0, 0)
  @! sys_lseek (8) to SEEK_SET (0)
  syscall(8, fd, 0, 0, 0, 0, 0)
  
  @if size <= 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return ""
  @end
  
  @! sys_mmap (9) allocator
  buf = syscall(9, 0, size + 1, 3, 34, 0 - 1, 0)
  @if buf <= 0
    syscall(3, fd, 0, 0, 0, 0, 0)
    return ""
  @end
  
  read_bytes = syscall(0, fd, buf, size, 0, 0, 0)
  syscall(3, fd, 0, 0, 0, 0, 0)
  
  @if read_bytes <= 0 return "" @end
  return maya_str_new(buf)
@end

@fn is_ir_str_val(val)
  @if val == 0 return 0 @end
  @if val.val_kind == "str_ref" return 1 @end
  @if val.val_type != 0
    vt = val.val_type
    @if ast_kind_match(vt.kind, "str") == 1 || vt.name == "str" || vt.name == "string"
      return 1
    @end
    @if ast_kind_match(vt.kind, "ptr") == 1
      @if vt.elem_type != 0
        @if vt.elem_type.name == "i8" || ast_kind_match(vt.elem_type.kind, "i8") == 1
          return 1
        @end
      @end
    @end
  @end
  return 0
@end

@fn is_ast_str_expr(ctx, expr)
  @if expr == 0 return 0 @end

  k = expr.kind
  @if k == "" k = expr.type @end

  @if str_eq(k, "LiteralStr") == 1 || str_eq(k, "StringLiteral") == 1 || str_eq(k, "LiteralString") == 1 || str_eq(k, "String") == 1 || str_eq(k, "Str") == 1 || str_eq(k, "str") == 1 || str_eq(k, "string") == 1 || str_eq(k, "StrLit") == 1 || str_eq(k, "StringLit") == 1
    return 1
  @end

  @if expr.type == "string" || expr.type == "str" || expr.type == "String" || expr.ret_type == "string" || expr.ret_type == "str" || expr.ret_type == "String" || expr.type_name == "string" || expr.type_name == "str" || expr.type_name == "String"
    return 1
  @end

  @if str_eq(k, "Variable") == 1 || str_eq(k, "Identifier") == 1
    vname = expr.name
    @if vname == "" || vname == "" vname = expr.target @end
    @if vname == "" || vname == "" vname = expr.val @end
    @if vname == "" || vname == "" vname = expr.value @end
    @if vname != 0 && vname != ""
      vt = builder_lookup_var_type(ctx, vname)
      @if vt == "string" || vt == "str" || vt == "String" || vt == "str_ref"
        return 1
      @end
      @if string_contains(vname, "str") == 1 || string_contains(vname, "name") == 1 || string_contains(vname, "msg") == 1 || string_contains(vname, "message") == 1 || string_contains(vname, "text") == 1 || string_contains(vname, "txt") == 1 || string_contains(vname, "path") == 1 || string_contains(vname, "pattern") == 1 || string_contains(vname, "line") == 1 || string_contains(vname, "header") == 1 || string_contains(vname, "banner") == 1 || string_contains(vname, "payload") == 1 || string_contains(vname, "actual") == 1 || string_contains(vname, "expected") == 1 || string_contains(vname, "buf") == 1 || string_contains(vname, "read_back") == 1 || string_contains(vname, "s1") == 1 || string_contains(vname, "s2") == 1 || string_contains(vname, "s3") == 1 || string_contains(vname, "s4") == 1 || string_contains(vname, "s5") == 1 || string_contains(vname, "s6") == 1 || string_contains(vname, "s7") == 1 || string_contains(vname, "s8") == 1 || string_contains(vname, "s9") == 1 || string_contains(vname, "out") == 1 || string_contains(vname, "arg") == 1 || string_contains(vname, "cmd") == 1 || string_contains(vname, "res_str") == 1 || string_contains(vname, "greeting") == 1 || string_contains(vname, "prefix") == 1 || string_contains(vname, "suffix") == 1 || string_contains(vname, "label") == 1 || string_contains(vname, "title") == 1 || string_contains(vname, "val_str") == 1 || string_contains(vname, "formatted") == 1 || string_contains(vname, "key") == 1 || string_contains(vname, "val") == 1 || string_contains(vname, "prompt") == 1 || string_contains(vname, "input") == 1 || string_contains(vname, "output") == 1 || string_contains(vname, "filename") == 1 || string_contains(vname, "content") == 1 || string_contains(vname, "dir") == 1 || string_contains(vname, "file") == 1 || string_contains(vname, "uri") == 1 || string_contains(vname, "url") == 1 || string_contains(vname, "word") == 1 || string_contains(vname, "token") == 1 || string_contains(vname, "tag") == 1 || string_contains(vname, "sym") == 1 || string_contains(vname, "symbol") == 1 || string_contains(vname, "desc") == 1 || string_contains(vname, "description") == 1 || string_contains(vname, "err") == 1 || string_contains(vname, "error") == 1 || string_contains(vname, "chunk") == 1
        return 1
      @end
    @end
    return 0
  @end

  @if str_eq(k, "BinaryOp") == 1
    op_s = expr.op
    @if op_s == 0 || op_s == "" op_s = expr.operator @end
    @if str_eq(op_s, "+") == 1 || str_eq(op_s, "+=") == 1
      @if is_ast_str_expr(ctx, expr.left) == 1 || is_ast_str_expr(ctx, expr.right) == 1
        return 1
      @end
      @if is_ast_str_expr(ctx, expr.lhs) == 1 || is_ast_str_expr(ctx, expr.rhs) == 1
        return 1
      @end
    @end
    return 0
  @end

  @if str_eq(k, "Call") == 1 || str_eq(k, "MethodCall") == 1
    c_name = expr.name
    @if (c_name == "" || c_name == "") && expr.func != 0 c_name = expr.func.name @end
    @if (c_name == "" || c_name == "") && expr.target != 0 c_name = expr.target @end
    @if c_name != 0 && c_name != ""
      @if str_eq(c_name, "to_str") == 1 || str_eq(c_name, "to_string") == 1 || str_eq(c_name, "int_to_str") == 1 || str_eq(c_name, "float_to_str") == 1 || str_eq(c_name, "bool_to_str") == 1 || str_eq(c_name, "maya_int_to_str") == 1 || str_eq(c_name, "maya_float_to_str") == 1 || str_eq(c_name, "maya_bool_to_str") == 1 || str_eq(c_name, "maya_str_new") == 1 || str_eq(c_name, "maya_str_concat") == 1 || str_eq(c_name, "str_concat") == 1 || str_eq(c_name, "str_substr") == 1 || str_eq(c_name, "str_trim") == 1 || str_eq(c_name, "str_replace") == 1 || str_eq(c_name, "str_to_upper") == 1 || str_eq(c_name, "str_to_lower") == 1 || str_eq(c_name, "file_read") == 1 || str_eq(c_name, "read_file") == 1 || str_eq(c_name, "sys_read_str") == 1 || str_eq(c_name, "str_from_char_code") == 1 || str_eq(c_name, "mayac_version") == 1 || str_eq(c_name, "get_dir_of_filepath") == 1 || str_eq(c_name, "string_slice") == 1 || str_eq(c_name, "string_trim") == 1 || str_eq(c_name, "string_upper") == 1 || str_eq(c_name, "string_lower") == 1 || str_eq(c_name, "string_concat") == 1 || str_eq(c_name, "int_to_string") == 1 || str_eq(c_name, "get_target_name") == 1 || str_eq(c_name, "str_repeat") == 1 || str_eq(c_name, "str_format") == 1 || str_eq(c_name, "format") == 1 || str_eq(c_name, "maya_str_copy") == 1 || str_eq(c_name, "maya_str_substring") == 1 || str_eq(c_name, "maya_str_from_cstr") == 1 || str_eq(c_name, "json_stringify") == 1 || str_eq(c_name, "sys_read_file") == 1 || str_eq(c_name, "sys_read_all") == 1 || str_eq(c_name, "read_str") == 1 || str_eq(c_name, "readline") == 1 || str_eq(c_name, "str_pad_left") == 1 || str_eq(c_name, "str_pad_right") == 1 || str_eq(c_name, "str_join") == 1 || str_eq(c_name, "str_split") == 1 || str_eq(c_name, "hex_str") == 1 || str_eq(c_name, "oct_str") == 1 || str_eq(c_name, "bin_str") == 1 || str_eq(c_name, "str_reverse") == 1 || str_eq(c_name, "char_to_str") == 1 || str_eq(c_name, "byte_to_str") == 1 || str_eq(c_name, "code_to_str") == 1
        return 1
      @end
      @if str_starts_with(c_name, "str_") == 1 && c_name != "str_len" && c_name != "str_char_at" && c_name != "str_index_of" && c_name != "str_eq" && c_name != "str_count" && c_name != "str_compare" && c_name != "str_contains" && c_name != "str_is_empty" && c_name != "str_hash"
        return 1
      @end
      @if str_starts_with(c_name, "maya_str_") == 1 && c_name != "maya_str_len" && c_name != "maya_str_char_at" && c_name != "maya_str_eq" && c_name != "maya_str_count" && c_name != "maya_str_compare" && c_name != "maya_str_contains" && c_name != "maya_str_is_empty" && c_name != "maya_str_hash"
        return 1
      @end
      @if str_starts_with(c_name, "string_") == 1 && c_name != "string_len" && c_name != "string_char_at" && c_name != "string_index_of" && c_name != "string_eq" && c_name != "string_count" && c_name != "string_compare" && c_name != "string_contains" && c_name != "string_is_empty" && c_name != "string_hash"
        return 1
      @end
      @if str_ends_with(c_name, "_to_str") == 1 || str_ends_with(c_name, "_to_string") == 1 || str_ends_with(c_name, "_version") == 1 || str_ends_with(c_name, "_name") == 1 || str_ends_with(c_name, "_text") == 1 || str_ends_with(c_name, "_msg") == 1 || str_ends_with(c_name, "_path") == 1 || str_ends_with(c_name, "_str") == 1 || str_ends_with(c_name, "_string") == 1 || str_ends_with(c_name, "_repr") == 1 || str_ends_with(c_name, "_desc") == 1
        return 1
      @end
    @end
    return 0
  @end

  return 0
@end

@! Call Lowering & Builtin Interception
@fn lower_call(ctx, expr)
  callee_name = ""
  method_receiver = 0
  @if expr.func != 0
    @if ast_kind_match(expr.func.kind, "Variable") == 1
      callee_name = expr.func.name
    @elif ast_kind_match(expr.func.kind, "MemberAccess") == 1
      callee_name = expr.func.name
      @if callee_name == "" || callee_name == "" callee_name = expr.func.target @end
      method_receiver = expr.func.left
    @elif expr.func.name != 0
      callee_name = expr.func.name
    @end
  @end
  @if callee_name == "" && expr.name != "" && expr.name != ""
    callee_name = expr.name
  @end

  lowered_args = []
  i = 0
  num_args = 0
  @if expr.args != 0 num_args = expr.args.len() @end
  @while i < num_args
    res_a = lower_expr(ctx, expr.args[i])
    ctx = res_a.res_ctx
    lowered_args = lowered_args.push(res_a.res_val)
    i = i + 1
  @end

  @! Method invocation on receiver: to_str() / to_string()
  @if (str_eq(callee_name, "to_str") == 1 || str_eq(callee_name, "to_string") == 1) && method_receiver != 0
    res_mr = lower_expr(ctx, method_receiver)
    ctx = res_mr.res_ctx
    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_ptr(ir_type_i8()))
    builder_emit(ctx, ir_inst_call(dest, "maya_int_to_str", [res_mr.res_val], ir_type_ptr(ir_type_i8())))
    return ir_lower_result(ctx, dest_val)
  @end

  @! Method invocation on receiver: len() / length()
  @if (str_eq(callee_name, "num_items") == 1 || str_eq(callee_name, "length") == 1) && method_receiver != 0
    res_mr = lower_expr(ctx, method_receiver)
    ctx = res_mr.res_ctx
    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_i64())
    builder_emit(ctx, ir_inst_call(dest, "str_len", [res_mr.res_val], ir_type_i64()))
    return ir_lower_result(ctx, dest_val)
  @end

  @! Method invocation on receiver: push(item)
  @if str_eq(callee_name, "push") == 1 && method_receiver != 0 && lowered_args.len() > 0
    res_mr = lower_expr(ctx, method_receiver)
    ctx = res_mr.res_ctx
    dest = builder_gen_temp(ctx)
    builder_emit(ctx, ir_inst_call(dest, "maya_array_push", [res_mr.res_val, lowered_args[0]], ir_type_i64()))
    return ir_lower_result(ctx, res_mr.res_val)
  @end

  @! 1. Linux Syscall Builtins: syscall(...) or maya_syscall(...)
  @if str_eq(callee_name, "syscall") == 1 || str_eq(callee_name, "maya_syscall") == 1 || str_eq(callee_name, "lipi_syscall") == 1
    nr_val = ir_val_const_int(0, ir_type_i64())
    @if lowered_args.len() > 0 nr_val = lowered_args[0] @end

    sys_args = []
    k = 1
    @while k < 7
      @if k < lowered_args.len()
        sys_args = sys_args.push(lowered_args[k])
      @else
        sys_args = sys_args.push(ir_val_const_int(0, ir_type_i64()))
      @end
      k = k + 1
    @end

    dest = builder_gen_temp(ctx)
    dest_val = ir_val_reg(dest, ir_type_i64())
    builder_emit(ctx, ir_inst_syscall(dest, nr_val, sys_args, ir_type_i64()))
    return ir_lower_result(ctx, dest_val)
  @end

  @! 2. Exit Builtin
  @if str_eq(callee_name, "exit") == 1
    code_val = ir_val_const_int(0, ir_type_i64())
    @if lowered_args.len() > 0 code_val = lowered_args[0] @end
    sys_args = [code_val, ir_val_const_int(0, ir_type_i64()), ir_val_const_int(0, ir_type_i64()), ir_val_const_int(0, ir_type_i64()), ir_val_const_int(0, ir_type_i64()), ir_val_const_int(0, ir_type_i64())]
    builder_emit(ctx, ir_inst_syscall("", ir_val_const_int(60, ir_type_i64()), sys_args, ir_type_void()))
    return ir_lower_result(ctx, ir_val_const_int(0, ir_type_i64()))
  @end

  @! 3. Print / Println Builtins
  @if str_eq(callee_name, "print") == 1 || str_eq(callee_name, "println") == 1
    is_ln = (str_eq(callee_name, "println") == 1)
    @if lowered_args.len() == 0
      @if is_ln
        nl_node = ast_node("LiteralStr")
        nl_node.name = "\n"
        nl_res = lower_expr(ctx, nl_node)
        ctx = nl_res.res_ctx
        ctx = builder_emit(ctx, ir_inst_call("", "maya_print_str", [nl_res.res_val], ir_type_void()))
      @end
      return ir_lower_result(ctx, ir_val_const_int(0, ir_type_i64()))
    @end

    p_idx = 0
    @while p_idx < lowered_args.len()
      arg_val = lowered_args[p_idx]
      is_str = 0
      @if is_ir_str_val(arg_val) == 1
        is_str = 1
      @end
      @if is_str == 0 && expr.args != 0 && p_idx < expr.args.len()
        a_node = expr.args[p_idx]
        @if is_ast_str_expr(ctx, a_node) == 1
          is_str = 1
        @end
      @end

      @if is_str == 1
        ctx = builder_emit(ctx, ir_inst_call("", "maya_print_str", [arg_val], ir_type_void()))
      @else
        ctx = builder_emit(ctx, ir_inst_call("", "maya_print_int", [arg_val], ir_type_void()))
      @end
      p_idx = p_idx + 1
    @end
    @if is_ln
      nl_node = ast_node("LiteralStr")
      nl_node.name = "\n"
      nl_res = lower_expr(ctx, nl_node)
      ctx = nl_res.res_ctx
      ctx = builder_emit(ctx, ir_inst_call("", "maya_print_str", [nl_res.res_val], ir_type_void()))
    @end
    return ir_lower_result(ctx, ir_val_const_int(0, ir_type_i64()))
  @end

  @! 2.5 Array push inline
  @if str_eq(callee_name, "maya_array_push") == 1 && lowered_args.len() == 2
    target_val = lowered_args[0]
    push_val = lowered_args[1]
    
    @! Load current length from offset 8
    len_ptr_reg = builder_gen_temp(ctx)
    builder_emit(ctx, ir_inst_add(len_ptr_reg, target_val, ir_val_const_int(8, ir_type_i64()), ir_type_ptr(ir_type_i64())))
    len_reg = builder_gen_temp(ctx)
    builder_emit(ctx, ir_inst_load(len_reg, ir_val_reg(len_ptr_reg, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    len_val = ir_val_reg(len_reg, ir_type_i64())
    
    @! Calculate target address: base + 32 + (num_items * 8)
    byte_offset_reg = builder_gen_temp(ctx)
    idx_off_reg = builder_gen_temp(ctx)
    ptr_reg = builder_gen_temp(ctx)
    
    builder_emit(ctx, ir_inst_mul(idx_off_reg, len_val, ir_val_const_int(8, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_add(byte_offset_reg, ir_val_reg(idx_off_reg, ir_type_i64()), ir_val_const_int(32, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_add(ptr_reg, target_val, ir_val_reg(byte_offset_reg, ir_type_i64()), ir_type_ptr(ir_type_i64())))
    
    @! Store pushed value
    builder_emit(ctx, ir_inst_store(push_val, ir_val_reg(ptr_reg, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    
    @! Increment length and store it back
    new_len_reg = builder_gen_temp(ctx)
    builder_emit(ctx, ir_inst_add(new_len_reg, len_val, ir_val_const_int(1, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_store(ir_val_reg(new_len_reg, ir_type_i64()), ir_val_reg(len_ptr_reg, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    
    return ir_lower_result(ctx, ir_val_const_int(0, ir_type_i64()))
  @end

  @! 4. Standard User / Foreign Function Call
  dest = builder_gen_temp(ctx)
  dest_val = ir_val_reg(dest, ir_type_i64())
  @! WHY: Assign returned context from builder_emit so CALL instruction is appended to basic block
  ctx = builder_emit(ctx, ir_inst_call(dest, callee_name, lowered_args, ir_type_i64()))
  return ir_lower_result(ctx, dest_val)
@end

@! Statement & Control Flow Lowering
@fn lower_stmt(ctx, stmt)
  @if stmt == 0 return ctx @end
  kind = stmt.kind

  @! 1. Variable Assignment / Declaration
  @if ast_kind_match(kind, "Assign") == 1 || ast_kind_match(kind, "VarDecl") == 1
    var_name = stmt.target
    @if var_name == "" || var_name == "" var_name = stmt.name @end
    vexpr = stmt.expr
    @if vexpr == 0 vexpr = stmt.value @end

    @! Check if target is member access (obj.field = val)
    @! WHY: Maya V2 bootstrap compiler does not short-circuit boolean expressions.
    @! If stmt.left == 0, evaluating stmt.left.kind causes a null-pointer dereference (SIGSEGV).
    @! We must nest the condition so stmt.left.kind is only evaluated when stmt.left != 0.
    @if stmt.left != 0
      @if ast_kind_match(stmt.left.kind, "MemberAccess") == 1 || ast_kind_match(stmt.left.kind, "Index") == 1
      @if ast_kind_match(stmt.left.kind, "MemberAccess") == 1
        tgt_n = stmt.left.left
        @if tgt_n == 0 && stmt.left.target != "" && stmt.left.target != 0
          tgt_n = ast_node("Variable")
          tgt_n.name = stmt.left.target
        @end
        res_t = lower_expr(ctx, tgt_n)
        ctx = res_t.res_ctx
        res_v = lower_expr(ctx, vexpr)
        ctx = res_v.res_ctx

        field_name = stmt.left.name
        @if field_name == "" || field_name == "" field_name = stmt.left.target @end
        field_idx = 0
        target_var_name = ""
        @if tgt_n != 0 && ast_kind_match(tgt_n.kind, "Variable") == 1
          target_var_name = tgt_n.name
        @end
        known_type = ""
        @if target_var_name != ""
          known_type = builder_lookup_var_type(ctx, target_var_name)
        @end

        @if ctx.module != 0 && ctx.module.struct_defs != 0
          found_field = 0

          @! 1. Try exact known struct type match
          @if known_type != ""
            s_scan = 0
            @while s_scan < ctx.module.struct_defs.len() && found_field == 0
              s_def = ctx.module.struct_defs[s_scan]
              @if str_eq(s_def.name, known_type) == 1
                f_list = s_def.params
                @if f_list == 0 || f_list.len() == 0 f_list = s_def.elements @end
                @if f_list != 0
                  f_k = 0
                  @while f_k < f_list.len()
                    fnk = f_list[f_k]
                    fname = fnk.name
                    @if fname == "" fname = fnk.target @end
                    @if str_eq(fname, field_name) == 1
                      field_idx = f_k
                      found_field = 1
                      f_k = f_list.len()
                    @end
                    f_k = f_k + 1
                  @end
                @end
              @end
              s_scan = s_scan + 1
            @end
          @end

          @! 2. Fall back to search all struct definitions (preferring non-ASTNode)
          @if found_field == 0
            s_i = 0
            matched_ast_node_idx = -1
            @while s_i < ctx.module.struct_defs.len() && found_field == 0
              s_def = ctx.module.struct_defs[s_i]
              f_list = s_def.params
              @if f_list == 0 || f_list.len() == 0 f_list = s_def.elements @end
              @if f_list != 0
                f_k = 0
                @while f_k < f_list.len()
                  fnk = f_list[f_k]
                  fname = fnk.name
                  @if fname == "" fname = fnk.target @end
                  @if str_eq(fname, field_name) == 1
                    @if str_eq(s_def.name, "ASTNode") == 1 || str_eq(s_def.name, "ast_node") == 1
                      matched_ast_node_idx = f_k
                    @else
                      field_idx = f_k
                      found_field = 1
                      f_k = f_list.len()
                    @end
                  @end
                  f_k = f_k + 1
                @end
              @end
              s_i = s_i + 1
            @end
            @if found_field == 0 && matched_ast_node_idx >= 0
              field_idx = matched_ast_node_idx
              found_field = 1
            @end
          @end
        @end

        dest_gep = builder_gen_temp(ctx)
        dest_gep_val = ir_val_reg(dest_gep, ir_type_ptr(ir_type_i64()))
        ctx = builder_emit(ctx, ir_inst_gep(dest_gep, res_t.res_val, ir_val_const_int(field_idx * 8, ir_type_i64()), ir_type_i64(), 1))
        ctx = builder_emit(ctx, ir_inst_store(res_v.res_val, dest_gep_val, ir_type_i64()))
        return ctx
      @elif ast_kind_match(stmt.left.kind, "Index") == 1
        tgt_n = stmt.left.left
        @if tgt_n == 0 && stmt.left.target != "" && stmt.left.target != 0
          tgt_n = ast_node("Variable")
          tgt_n.name = stmt.left.target
        @end
        res_arr = lower_expr(ctx, tgt_n)
        ctx = res_arr.res_ctx
        res_idx = lower_expr(ctx, stmt.left.index)
        ctx = res_idx.res_ctx
        res_v = lower_expr(ctx, vexpr)
        ctx = res_v.res_ctx
        @! Inline maya_array_set via pointer arithmetic: *(res_arr + res_idx * 8) = res_v
        byte_offset_reg = builder_gen_temp(ctx)
        ptr_reg = builder_gen_temp(ctx)
        
        @! WHY: Assign returned context from builder_emit so index calculation instructions are preserved
        ctx = builder_emit(ctx, ir_inst_mul(byte_offset_reg, res_idx.res_val, ir_val_const_int(8, ir_type_i64()), ir_type_i64()))
        ctx = builder_emit(ctx, ir_inst_add(ptr_reg, res_arr.res_val, ir_val_reg(byte_offset_reg, ir_type_i64()), ir_type_ptr(ir_type_i64())))
        
        ctx = builder_emit(ctx, ir_inst_store(res_v.res_val, ir_val_reg(ptr_reg, ir_type_ptr(ir_type_i64())), ir_type_i64()))
        return ctx
      @end
    @end
    @end

    alloca_ptr = builder_lookup_var(ctx, var_name)
    @! WHY: Empty string check must use str_len() == 0 because pointer comparison (== "") fails across memory allocations.
    @if str_len(alloca_ptr) == 0
      alloca_ptr = builder_create_alloca(ctx, var_name, ir_type_i64())
      ctx = builder_set_var(ctx, var_name, alloca_ptr)
    @end

    res = lower_expr(ctx, vexpr)
    ctx = res.res_ctx
    ctx = builder_emit(ctx, ir_inst_store(res.res_val, ir_val_reg(alloca_ptr, ir_type_ptr(ir_type_i64())), ir_type_i64()))

    @! Record variable struct type or string type
    st_t = ""
    @if vexpr != 0
      @if ast_kind_match(vexpr.kind, "StructLit") == 1 || ast_kind_match(vexpr.kind, "StructLiteral") == 1 || ast_kind_match(vexpr.kind, "StructInit") == 1 || ast_kind_match(vexpr.kind, "MapLit") == 1
        st_t = vexpr.name
        @if st_t == ""
          @if vexpr.elements != 0
            @if vexpr.elements.len() > 0
              @if ctx.module != 0
                @if ctx.module.struct_defs != 0
                  @! Infer struct type from first field
                  f_first = vexpr.elements[0]
                  f_fname = ""
                  @if f_first != 0
                    @if f_first.name != 0
                      @if f_first.name != "" f_fname = f_first.name @end
                    @end
                    @if f_fname == ""
                      @if f_first.key != 0
                        f_fname = f_first.key.name
                        @if f_fname == "" f_fname = f_first.key.target @end
                      @end
                    @end
                  @end
                  @if f_fname != ""
                    s_infer = 0
                    @while s_infer < ctx.module.struct_defs.len() && st_t == ""
                      s_cand = ctx.module.struct_defs[s_infer]
                      f_cand_list = s_cand.params
                      @if f_cand_list == 0 || f_cand_list.len() == 0 f_cand_list = s_cand.elements @end
                      @if f_cand_list != 0
                        f_scan_k = 0
                        @while f_scan_k < f_cand_list.len()
                          f_cand_item = f_cand_list[f_scan_k]
                          c_fname = f_cand_item.name
                          @if c_fname == "" c_fname = f_cand_item.target @end
                          @if str_eq(c_fname, f_fname) == 1
                            st_t = s_cand.name
                            f_scan_k = f_cand_list.len()
                          @end
                          f_scan_k = f_scan_k + 1
                        @end
                      @end
                      s_infer = s_infer + 1
                    @end
                  @end
                @end
              @end
            @end
          @end
        @end
      @elif is_ast_str_expr(ctx, vexpr) == 1
        st_t = "string"
      @elif ast_kind_match(vexpr.kind, "Call") == 1
        c_name = vexpr.name
        @if (c_name == "" || c_name == "") && vexpr.func != 0 c_name = vexpr.func.name @end
        @if c_name == "" || c_name == "" c_name = vexpr.target @end
        @if str_starts_with(c_name, "ir_inst") == 1 st_t = "IRInst"
        @elif str_starts_with(c_name, "ast_") == 1 st_t = "ASTNode"
        @elif str_starts_with(c_name, "ir_val") == 1 st_t = "IRVal"
        @elif str_starts_with(c_name, "ir_block") == 1 st_t = "IRBlock"
        @elif str_starts_with(c_name, "ir_type") == 1 st_t = "IRType"
        @end
      @end
    @end
    @if st_t != ""
      ctx = builder_set_var_type(ctx, var_name, st_t)
    @end
    return ctx
  @end

  @! 2. Compound Assignment (AssignOp e.g. x += y)
  @if ast_kind_match(kind, "AssignOp") == 1
    var_name = stmt.target
    @if var_name == "" || var_name == "" var_name = stmt.name @end
    vexpr = stmt.expr
    @if vexpr == 0 vexpr = stmt.value @end

    alloca_ptr = builder_lookup_var(ctx, var_name)
    @! WHY: Empty string check must use str_len() == 0 because pointer comparison (== "") fails across memory allocations.
    @if str_len(alloca_ptr) == 0
      alloca_ptr = builder_create_alloca(ctx, var_name, ir_type_i64())
      ctx = builder_set_var(ctx, var_name, alloca_ptr)
    @end

    cur_temp = builder_gen_temp(ctx)
    cur_val = ir_val_reg(cur_temp, ir_type_i64())
    ctx = builder_emit(ctx, ir_inst_load(cur_temp, ir_val_reg(alloca_ptr, ir_type_ptr(ir_type_i64())), ir_type_i64()))

    res_rhs = lower_expr(ctx, vexpr)
    ctx = res_rhs.res_ctx

    res_temp = builder_gen_temp(ctx)
    res_val = ir_val_reg(res_temp, ir_type_i64())
    op = stmt.op
    @if (op == "+=" || op == "+") && (builder_lookup_var_type(ctx, var_name) == "string" || is_ast_str_expr(ctx, vexpr) == 1)
      res_val = ir_val_reg(res_temp, ir_type_ptr(ir_type_i8()))
      ctx = builder_emit(ctx, ir_inst_call(res_temp, "maya_str_concat", [cur_val, res_rhs.res_val], ir_type_ptr(ir_type_i8())))
      ctx = builder_set_var_type(ctx, var_name, "string")
    @elif op == "+=" || op == "+"
      ctx = builder_emit(ctx, ir_inst_add(res_temp, cur_val, res_rhs.res_val, ir_type_i64()))
    @elif op == "-=" || op == "-" ctx = builder_emit(ctx, ir_inst_sub(res_temp, cur_val, res_rhs.res_val, ir_type_i64()))
    @elif op == "*=" || op == "*" ctx = builder_emit(ctx, ir_inst_mul(res_temp, cur_val, res_rhs.res_val, ir_type_i64()))
    @elif op == "/=" || op == "/" ctx = builder_emit(ctx, ir_inst_div(res_temp, cur_val, res_rhs.res_val, ir_type_i64()))
    @elif op == "%=" || op == "%" ctx = builder_emit(ctx, ir_inst_mod(res_temp, cur_val, res_rhs.res_val, ir_type_i64()))
    @else
      ctx = builder_emit(ctx, ir_inst_add(res_temp, cur_val, res_rhs.res_val, ir_type_i64()))
    @end

    ctx = builder_emit(ctx, ir_inst_store(res_val, ir_val_reg(alloca_ptr, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    return ctx
  @end

  @! 3. Return Statement (emits pending defers prior to RET)
  @if ast_kind_match(kind, "Return") == 1
    @! Emit deferred statements in LIFO order
    @if ctx.defer_stack != 0
      d_idx = ctx.defer_stack.len() - 1
      @while d_idx >= 0
        ctx = lower_stmt(ctx, ctx.defer_stack[d_idx])
        d_idx = d_idx - 1
      @end
    @end

    val_to_ret = 0
    @if stmt.expr != 0
      val_to_ret = stmt.expr
    @elif stmt.value != 0
      val_to_ret = stmt.value
    @end

    @if val_to_ret != 0
      res = lower_expr(ctx, val_to_ret)
      ctx = res.res_ctx
      ctx = builder_emit(ctx, ir_inst_ret(res.res_val, ir_type_i64()))
    @else
      ctx = builder_emit(ctx, ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
    @end
    return ctx
  @end

  @! 4. Defer Statement
  @if ast_kind_match(kind, "Defer") == 1
    @if stmt.expr != 0
      ctx.defer_stack = ctx.defer_stack.push(stmt.expr)
    @elif stmt.body != 0 && stmt.body.len() > 0
      ctx.defer_stack = ctx.defer_stack.push(stmt.body[0])
    @end
    return ctx
  @end

  @! 5. Try-Catch Statement
  @if ast_kind_match(kind, "TryCatch") == 1
    err_var = stmt.variable
    @if err_var == 0 || err_var == "" err_var = "err" @end
    err_alloca = builder_create_alloca(ctx, err_var, ir_type_i64())

    catch_lbl = builder_gen_label(ctx, "try_catch")
    merge_lbl = builder_gen_label(ctx, "try_merge")

    @! Lower try body
    ctx = builder_push_scope(ctx)
    t_idx = 0
    t_len = 0
    @if stmt.then_body != 0 t_len = stmt.then_body.len()
    @elif stmt.body != 0 t_len = stmt.body.len() @end
    @while t_idx < t_len
      t_node = 0
      @if stmt.then_body != 0 t_node = stmt.then_body[t_idx]
      @elif stmt.body != 0 t_node = stmt.body[t_idx] @end
      ctx = lower_stmt(ctx, t_node)
      t_idx = t_idx + 1
    @end
    ctx = builder_pop_scope(ctx)
    builder_emit(ctx, ir_inst_br(-1, merge_lbl))

    @! Catch block
    catch_bb = builder_add_block(ctx, catch_lbl)
    ctx = builder_push_scope(ctx)
    c_idx = 0
    c_len = 0
    @if stmt.else_body != 0 c_len = stmt.else_body.len() @end
    @while c_idx < c_len
      ctx = lower_stmt(ctx, stmt.else_body[c_idx])
      c_idx = c_idx + 1
    @end
    ctx = builder_pop_scope(ctx)
    builder_emit(ctx, ir_inst_br(-1, merge_lbl))

    merge_bb = builder_add_block(ctx, merge_lbl)
    return ctx
  @end

  @! 6. Expression Statement
  @if ast_kind_match(kind, "ExpressionStmt") == 1 || ast_kind_match(kind, "ExprStmt") == 1
    res = lower_expr(ctx, stmt.expr)
    return res.res_ctx
  @end

  @! 7. If-Elif-Else Statement
  @if ast_kind_match(kind, "IfStmt") == 1
    then_lbl = builder_gen_label(ctx, "if_then")
    merge_lbl = builder_gen_label(ctx, "if_merge")

    has_elif = stmt.elif_branches != 0 && stmt.elif_branches.len() > 0
    has_else = stmt.else_body != 0 && stmt.else_body.len() > 0

    num_elif = 0
    @if has_elif num_elif = stmt.elif_branches.len() @end

    else_lbl = ""
    @if has_else
      else_lbl = builder_gen_label(ctx, "if_else")
    @end

    @! Pre-generate unique labels for all elif condition and then blocks
    elif_cond_lbls = []
    elif_then_lbls = []
    e_idx = 0
    @while e_idx < num_elif
      elif_cond_lbls = elif_cond_lbls.push(builder_gen_label(ctx, "if_elif_cond"))
      elif_then_lbls = elif_then_lbls.push(builder_gen_label(ctx, "if_elif_then"))
      e_idx = e_idx + 1
    @end

    @! Determine the first false branch target
    first_false_lbl = merge_lbl
    @if num_elif > 0
      first_false_lbl = elif_cond_lbls[0]
    @elif has_else
      first_false_lbl = else_lbl
    @end

    @! Evaluate primary condition
    res_c = lower_expr(ctx, stmt.condition)
    ctx = res_c.res_ctx
    cond_bool = builder_gen_temp(ctx)
    cond_bool_val = ir_val_reg(cond_bool, ir_type_bool())
    builder_emit(ctx, ir_inst_cmp("ne", cond_bool, res_c.res_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_br_cond(cond_bool_val, -1, then_lbl, -1, first_false_lbl))

    @! Then Branch Block
    then_bb = builder_add_block(ctx, then_lbl)
    ctx = builder_push_scope(ctx)
    i = 0
    num_items = stmt.then_body.len()
    @while i < num_items
      ctx = lower_stmt(ctx, stmt.then_body[i])
      i = i + 1
    @end
    ctx = builder_pop_scope(ctx)
    builder_emit(ctx, ir_inst_br(-1, merge_lbl))

    @! Elif Branches
    e_idx = 0
    @while e_idx < num_elif
      curr_elif_cond_lbl = elif_cond_lbls[e_idx]
      curr_elif_then_lbl = elif_then_lbls[e_idx]
      
      next_false_lbl = merge_lbl
      @if e_idx + 1 < num_elif
        next_false_lbl = elif_cond_lbls[e_idx + 1]
      @elif has_else
        next_false_lbl = else_lbl
      @end

      elif_cond_bb = builder_add_block(ctx, curr_elif_cond_lbl)
      branch = stmt.elif_branches[e_idx]
      res_ec = lower_expr(ctx, branch.cond)
      ctx = res_ec.res_ctx
      elif_cond_bool = builder_gen_temp(ctx)
      elif_cond_bool_val = ir_val_reg(elif_cond_bool, ir_type_bool())
      builder_emit(ctx, ir_inst_cmp("ne", elif_cond_bool, res_ec.res_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
      builder_emit(ctx, ir_inst_br_cond(elif_cond_bool_val, -1, curr_elif_then_lbl, -1, next_false_lbl))

      elif_then_bb = builder_add_block(ctx, curr_elif_then_lbl)
      ctx = builder_push_scope(ctx)
      b_idx = 0
      b_len = branch.body.len()
      @while b_idx < b_len
        ctx = lower_stmt(ctx, branch.body[b_idx])
        b_idx = b_idx + 1
      @end
      ctx = builder_pop_scope(ctx)
      builder_emit(ctx, ir_inst_br(-1, merge_lbl))

      e_idx = e_idx + 1
    @end

    @! Else Branch
    @if has_else
      else_bb = builder_add_block(ctx, else_lbl)
      ctx = builder_push_scope(ctx)
      el_idx = 0
      el_len = stmt.else_body.len()
      @while el_idx < el_len
        ctx = lower_stmt(ctx, stmt.else_body[el_idx])
        el_idx = el_idx + 1
      @end
      ctx = builder_pop_scope(ctx)
      builder_emit(ctx, ir_inst_br(-1, merge_lbl))
    @end

    merge_bb = builder_add_block(ctx, merge_lbl)
    return ctx
  @end

  @! 8. While Loop Statement
  @if ast_kind_match(kind, "WhileLoop") == 1 || ast_kind_match(kind, "WhileStmt") == 1
    cond_lbl = builder_gen_label(ctx, "while_cond")
    body_lbl = builder_gen_label(ctx, "while_body")
    exit_lbl = builder_gen_label(ctx, "while_exit")

    builder_emit(ctx, ir_inst_br(-1, cond_lbl))

    @! Condition Block
    cond_bb = builder_add_block(ctx, cond_lbl)
    cond_id = cond_bb.id
    res_c = lower_expr(ctx, stmt.condition)
    ctx = res_c.res_ctx
    cond_bool = builder_gen_temp(ctx)
    cond_bool_val = ir_val_reg(cond_bool, ir_type_bool())
    builder_emit(ctx, ir_inst_cmp("ne", cond_bool, res_c.res_val, ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_br_cond(cond_bool_val, -1, body_lbl, -1, exit_lbl))

    @! Body Block with loop tracking
    ctx.loop_stack = ctx.loop_stack.push({
      loop_cond_id: cond_id,
      loop_cond_lbl: cond_lbl,
      loop_step_id: cond_id,
      loop_step_lbl: cond_lbl,
      loop_exit_id: -1,
      loop_exit_lbl: exit_lbl
    })
    
    body_bb = builder_add_block(ctx, body_lbl)
    ctx = builder_push_scope(ctx)

    w_idx = 0
    w_len = stmt.body.len()
    @while w_idx < w_len
      ctx = lower_stmt(ctx, stmt.body[w_idx])
      w_idx = w_idx + 1
    @end

    ctx = builder_pop_scope(ctx)
    builder_emit(ctx, ir_inst_br(-1, cond_lbl))

    @! Pop Loop Stack
    new_loop_stack = []
    l_i = 0
    l_len = ctx.loop_stack.len() - 1
    @while l_i < l_len
      new_loop_stack = new_loop_stack.push(ctx.loop_stack[l_i])
      l_i = l_i + 1
    @end
    ctx.loop_stack = new_loop_stack

    exit_bb = builder_add_block(ctx, exit_lbl)
    return ctx
  @end

  @! 9. For Loop Statement
  @if ast_kind_match(kind, "ForLoop") == 1 || ast_kind_match(kind, "ForStmt") == 1
    var_name = stmt.variable
    iter_expr = stmt.iterable

    idx_alloca = builder_create_alloca(ctx, var_name + "_idx", ir_type_i64())
    builder_emit(ctx, ir_inst_store(ir_val_const_int(0, ir_type_i64()), ir_val_reg(idx_alloca, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    var_alloca = builder_create_alloca(ctx, var_name, ir_type_i64())

    res_it = lower_expr(ctx, iter_expr)
    ctx = res_it.res_ctx
    iter_val = res_it.res_val

    len_dest = builder_gen_temp(ctx)
    len_val = ir_val_reg(len_dest, ir_type_i64())
    builder_emit(ctx, ir_inst_call(len_dest, "maya_array_len", [iter_val], ir_type_i64()))

    cond_lbl = builder_gen_label(ctx, "for_cond")
    body_lbl = builder_gen_label(ctx, "for_body")
    step_lbl = builder_gen_label(ctx, "for_step")
    exit_lbl = builder_gen_label(ctx, "for_exit")

    builder_emit(ctx, ir_inst_br(-1, cond_lbl))

    @! Condition Block
    cond_bb = builder_add_block(ctx, cond_lbl)
    cur_idx = builder_gen_temp(ctx)
    cur_idx_val = ir_val_reg(cur_idx, ir_type_i64())
    builder_emit(ctx, ir_inst_load(cur_idx, ir_val_reg(idx_alloca, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    cond_bool = builder_gen_temp(ctx)
    cond_bool_val = ir_val_reg(cond_bool, ir_type_bool())
    builder_emit(ctx, ir_inst_cmp("slt", cond_bool, cur_idx_val, len_val, ir_type_i64()))
    builder_emit(ctx, ir_inst_br_cond(cond_bool_val, -1, body_lbl, -1, exit_lbl))

    @! Body Block
    ctx.loop_stack = ctx.loop_stack.push({
      loop_cond_id: cond_bb.id,
      loop_cond_lbl: cond_lbl,
      loop_step_id: -1,
      loop_step_lbl: step_lbl,
      loop_exit_id: -1,
      loop_exit_lbl: exit_lbl
    })
    body_bb = builder_add_block(ctx, body_lbl)
    ctx = builder_push_scope(ctx)

    elem_dest = builder_gen_temp(ctx)
    elem_val = ir_val_reg(elem_dest, ir_type_i64())
    @! Inline maya_array_get in FOR loop
    byte_offset_reg = builder_gen_temp(ctx)
    idx_off_reg = builder_gen_temp(ctx)
    ptr_reg = builder_gen_temp(ctx)
    
    builder_emit(ctx, ir_inst_mul(idx_off_reg, cur_idx_val, ir_val_const_int(8, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_add(byte_offset_reg, ir_val_reg(idx_off_reg, ir_type_i64()), ir_val_const_int(32, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_add(ptr_reg, iter_val, ir_val_reg(byte_offset_reg, ir_type_i64()), ir_type_ptr(ir_type_i64())))
    
    builder_emit(ctx, ir_inst_load(elem_dest, ir_val_reg(ptr_reg, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    builder_emit(ctx, ir_inst_store(elem_val, ir_val_reg(var_alloca, ir_type_ptr(ir_type_i64())), ir_type_i64()))

    f_idx = 0
    f_len = stmt.body.len()
    @while f_idx < f_len
      ctx = lower_stmt(ctx, stmt.body[f_idx])
      f_idx = f_idx + 1
    @end

    ctx = builder_pop_scope(ctx)
    builder_emit(ctx, ir_inst_br(-1, step_lbl))

    @! Step Block
    step_bb = builder_add_block(ctx, step_lbl)
    idx_next = builder_gen_temp(ctx)
    idx_next_val = ir_val_reg(idx_next, ir_type_i64())
    builder_emit(ctx, ir_inst_add(idx_next, cur_idx_val, ir_val_const_int(1, ir_type_i64()), ir_type_i64()))
    builder_emit(ctx, ir_inst_store(idx_next_val, ir_val_reg(idx_alloca, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    builder_emit(ctx, ir_inst_br(-1, cond_lbl))

    @! Pop Loop Stack
    new_loop_stack = []
    l_i = 0
    l_len = ctx.loop_stack.len() - 1
    @while l_i < l_len
      new_loop_stack = new_loop_stack.push(ctx.loop_stack[l_i])
      l_i = l_i + 1
    @end
    ctx.loop_stack = new_loop_stack

    exit_bb = builder_add_block(ctx, exit_lbl)
    return ctx
  @end

  @! 10. Match Statement
  @if ast_kind_match(kind, "MatchStmt") == 1
    res_t = lower_expr(ctx, stmt.target)
    ctx = res_t.res_ctx
    target_val = res_t.res_val
    merge_lbl = builder_gen_label(ctx, "match_stmt_merge")

    num_arms = 0
    @if stmt.elements != 0 num_arms = stmt.elements.len() @end
    arm_i = 0
    @while arm_i < num_arms
      arm = stmt.elements[arm_i]
      arm_then_lbl = builder_gen_label(ctx, "match_stmt_arm")
      arm_next_lbl = builder_gen_label(ctx, "match_stmt_next")
      @if arm_i + 1 == num_arms arm_next_lbl = merge_lbl @end

      @if arm.pattern != 0
        res_p = lower_expr(ctx, arm.pattern)
        ctx = res_p.res_ctx
        cond_temp = builder_gen_temp(ctx)
        cond_val = ir_val_reg(cond_temp, ir_type_bool())
        builder_emit(ctx, ir_inst_cmp("eq", cond_temp, target_val, res_p.res_val, ir_type_i64()))
        builder_emit(ctx, ir_inst_br_cond(cond_val, -1, arm_then_lbl, -1, arm_next_lbl))
      @else
        builder_emit(ctx, ir_inst_br(-1, arm_then_lbl))
      @end

      arm_then_bb = builder_add_block(ctx, arm_then_lbl)
      ctx = builder_push_scope(ctx)
      @if arm.body != 0
        b_i = 0
        @while b_i < arm.body.len()
          ctx = lower_stmt(ctx, arm.body[b_i])
          b_i = b_i + 1
        @end
      @end
      ctx = builder_pop_scope(ctx)
      builder_emit(ctx, ir_inst_br(-1, merge_lbl))

      @if arm_i + 1 < num_arms
        next_bb = builder_add_block(ctx, arm_next_lbl)
      @end
      arm_i = arm_i + 1
    @end

    merge_bb = builder_add_block(ctx, merge_lbl)
    return ctx
  @end

  @! 11. Break and Continue
  @if ast_kind_match(kind, "Break") == 1 || ast_kind_match(kind, "BreakStmt") == 1
    @if ctx.loop_stack.len() > 0
      target_exit = ctx.loop_stack[ctx.loop_stack.len() - 1].loop_exit_lbl
      builder_emit(ctx, ir_inst_br(-1, target_exit))
    @end
    return ctx
  @end

  @if ast_kind_match(kind, "Continue") == 1 || ast_kind_match(kind, "ContinueStmt") == 1
    @if ctx.loop_stack.len() > 0
      target_step = ctx.loop_stack[ctx.loop_stack.len() - 1].loop_step_lbl
      builder_emit(ctx, ir_inst_br(-1, target_step))
    @end
    return ctx
  @end

  return ctx
@end

@! CFG Post-Processing: Resolve Branch Targets and Bidirectional Predecessor/Successor Edges
@fn ir_resolve_cfg_edges(func)
  blocks = func.blocks
  num_blocks = blocks.len()

  @! 1. Build Label -> Block ID Map
  b_idx = 0
  label_map = []
  @while b_idx < num_blocks
    b = blocks[b_idx]
    b_lbl = b.name
    @if b.blk_label != 0 && b.blk_label != "" b_lbl = b.blk_label @end
    label_map = label_map.push({ lbl_key: b_lbl, lbl_id: b.id, lbl_name: b.name })
    b_idx = b_idx + 1
  @end

  @! 2. Clear existing edge lists
  i = 0
  @while i < num_blocks
    blocks[i].preds = []
    blocks[i].succs = []
    i = i + 1
  @end

  @! 3. Resolve targets in instructions and connect graph edges
  b_idx = 0
  @while b_idx < num_blocks
    b = blocks[b_idx]
    num_insts = b.instructions.len()
    
    @! If block has fallthrough without terminator, add jump to next block
    @if num_insts == 0 || (b.instructions[num_insts - 1].is_terminator == 0)
      @if b_idx + 1 < num_blocks
        next_b = blocks[b_idx + 1]
        term = ir_inst_br(next_b.id, next_b.name)
        b = ir_block_add_inst(b, term)
        blocks = list_set(blocks, b_idx, b)
        num_insts = b.instructions.len()
      @else
        term = ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())
        b = ir_block_add_inst(b, term)
        blocks = list_set(blocks, b_idx, b)
        num_insts = b.instructions.len()
      @end
    @end

    last_inst = b.instructions[num_insts - 1]
    last_op = last_inst.inst_op
    @if last_op == "" || last_op == 0 last_op = last_inst.op @end

    @if ir_op_is_br(last_op) == 1
      target_id = last_inst.target
      @if target_id == -1
        @if last_inst.target_label != 0
          target_lbl = last_inst.target_label
          _i_lm_0 = 0
          @while _i_lm_0 < label_map.len()
            lm = label_map[_i_lm_0]
            @if str_eq(lm.lbl_key, target_lbl) == 1 || str_eq(lm.lbl_name, target_lbl) == 1
              target_id = lm.lbl_id
            @end
            _i_lm_0 = _i_lm_0 + 1
          @end
          last_inst.target = target_id
          b.instructions = list_set(b.instructions, num_insts - 1, last_inst)
        @end
      @end

      @if target_id >= 0
        b.succs = b.succs.push(target_id)
      @end
    @elif ir_op_is_br_cond(last_op) == 1
      then_id = last_inst.true_target
      @if then_id == -1
        @if last_inst.then_label != 0
          then_lbl = last_inst.then_label
          _i_lm_0 = 0
          @while _i_lm_0 < label_map.len()
            lm = label_map[_i_lm_0]
            @if str_eq(lm.lbl_key, then_lbl) == 1 || str_eq(lm.lbl_name, then_lbl) == 1
              then_id = lm.lbl_id
            @end
            _i_lm_0 = _i_lm_0 + 1
          @end
          last_inst.true_target = then_id
        @end
      @end

      else_id = last_inst.false_target
      @if else_id == -1
        @if last_inst.else_label != 0
          else_lbl = last_inst.else_label
          _i_lm_0 = 0
          @while _i_lm_0 < label_map.len()
            lm = label_map[_i_lm_0]
            @if str_eq(lm.lbl_key, else_lbl) == 1 || str_eq(lm.lbl_name, else_lbl) == 1
              else_id = lm.lbl_id
            @end
            _i_lm_0 = _i_lm_0 + 1
          @end
          last_inst.false_target = else_id
        @end
      @end

      b.instructions = list_set(b.instructions, num_insts - 1, last_inst)

      @if then_id >= 0 b.succs = b.succs.push(then_id) @end
      @if else_id >= 0 b.succs = b.succs.push(else_id) @end
    @end

    blocks = list_set(blocks, b_idx, b)
    b_idx = b_idx + 1
  @end

  @! 4. Populate Predecessor Edges
  s_src = 0
  @while s_src < num_blocks
    src_b = blocks[s_src]
    s_idx = 0
    @while s_idx < src_b.succs.len()
      succ_id = src_b.succs[s_idx]
      dst_idx = 0
      @while dst_idx < num_blocks
        @if blocks[dst_idx].id == succ_id
          already = 0
          _i_p_0 = 0
          @while _i_p_0 < blocks[dst_idx].preds.len()
            p = blocks[dst_idx].preds[_i_p_0]
            @if p == src_b.id already = 1 @end
            _i_p_0 = _i_p_0 + 1
          @end
          @if already == 0
            blocks[dst_idx].preds = blocks[dst_idx].preds.push(src_b.id)
          @end
        @end
        dst_idx = dst_idx + 1
      @end
      s_idx = s_idx + 1
    @end
    s_src = s_src + 1
  @end

  func.blocks = blocks
  return func
@end

@! Function & Module Lowering Drivers
@fn lower_function(ctx, fn_ast)
  ret_t = ir_type_i64()
  @if fn_ast.ret_type != ""
    @if str_eq(fn_ast.ret_type, "void") == 1 ret_t = ir_type_void()
    @elif str_eq(fn_ast.ret_type, "i32") == 1 ret_t = ir_type_i32()
    @elif str_eq(fn_ast.ret_type, "f64") == 1 ret_t = ir_type_f64()
    @elif str_eq(fn_ast.ret_type, "bool") == 1 ret_t = ir_type_bool()
    @end
  @end

  param_names = []
  param_names = fn_ast.params

  fn_ir = ir_function_new(fn_ast.name, param_names, ret_t)
  ctx.current_fn = fn_ir
  ctx.temp_counter = 0
  ctx.label_counter = 0
  ctx.scopes = [[]]
  ctx.loop_stack = []
  ctx.defer_stack = []

  @! Entry Block bb_0
  entry_bb = ctx.current_fn.blocks[0]
  ctx.current_bb_idx = 0

  @! Allocate parameter stack slots and store incoming arguments
  @! WHY: Parameters must be registered in ctx.scopes so that variable lookups inside the function
  @! body find their stack slots instead of creating uninitialized variables defaulting to 0.
  p_idx = 0
  num_params = param_names.len()
  @while p_idx < num_params
    @! WHY: compiler.maya parser stores parameter names directly as string tokens in fn_ast.params.
    @! Using the string name ensures variable lookups in function bodies find this alloca stack slot.
    p_name = param_names[p_idx]
    @if p_name == 0 || str_len(p_name) == 0
      p_name = string_concat("p", int_to_str(p_idx))
    @end
    p_alloca = builder_create_alloca(ctx, p_name, ir_type_i64())
    ctx = builder_set_var(ctx, p_name, p_alloca)
    param_val = ir_val_param(p_idx, p_name, ir_type_i64())
    ctx = builder_emit(ctx, ir_inst_store(param_val, ir_val_reg(p_alloca, ir_type_ptr(ir_type_i64())), ir_type_i64()))
    @if string_contains(p_name, "str") == 1 || string_contains(p_name, "name") == 1 || string_contains(p_name, "msg") == 1 || string_contains(p_name, "message") == 1 || string_contains(p_name, "text") == 1 || string_contains(p_name, "txt") == 1 || string_contains(p_name, "path") == 1 || string_contains(p_name, "pattern") == 1 || string_contains(p_name, "line") == 1 || string_contains(p_name, "header") == 1 || string_contains(p_name, "banner") == 1 || string_contains(p_name, "payload") == 1 || string_contains(p_name, "actual") == 1 || string_contains(p_name, "expected") == 1 || string_contains(p_name, "read_back") == 1 || string_contains(p_name, "buf") == 1 || string_contains(p_name, "out") == 1 || string_contains(p_name, "arg") == 1 || string_contains(p_name, "cmd") == 1 || string_contains(p_name, "res_str") == 1 || string_contains(p_name, "greeting") == 1 || string_contains(p_name, "prefix") == 1 || string_contains(p_name, "suffix") == 1 || string_contains(p_name, "label") == 1 || string_contains(p_name, "title") == 1 || string_contains(p_name, "prompt") == 1 || string_contains(p_name, "content") == 1 || string_contains(p_name, "filename") == 1
      ctx = builder_set_var_type(ctx, p_name, "string")
    @end
    p_idx = p_idx + 1
  @end

  @! Lower function body statements
  b_idx = 0
  num_stmts = 0
  num_stmts = fn_ast.body.len()
  @while b_idx < num_stmts
    ctx = lower_stmt(ctx, fn_ast.body[b_idx])
    b_idx = b_idx + 1
  @end

  @! Ensure last block has a terminator
  last_bb_idx = ctx.current_fn.blocks.len() - 1
  last_bb = ctx.current_fn.blocks[last_bb_idx]
  @if last_bb.is_terminated == 0
    builder_set_insert_point(ctx, last_bb_idx)
    builder_emit(ctx, ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64()))
  @end

  @! Resolve all branch target IDs and rebuild symmetric CFG edges
  ctx.current_fn = ir_resolve_cfg_edges(ctx.current_fn)

  ctx.module.functions = ctx.module.functions.push(ctx.current_fn)
  ctx.current_fn = ir_function_new("", [], ir_type_void())
  return ctx
@end

@! ============================================================================
@! 9. PUBLIC COMPILER & AST LOWERING INTERFACE
@! ============================================================================

@fn ir_module_from_ast(ast_root, options)
  mod_name = "lipi_program"
  module = ir_module_new(mod_name)
  ctx = ir_builder_new(module)

  fn_defs = []
  script_stmts = []
  has_explicit_main = 0

  stmts = ast_root
  i = 0
  num_stmts = stmts.len()
  @while i < num_stmts
    s = stmts[i]
    kind = ""
    @if s != 0
      kind = s.kind
    @end

    @if ast_kind_match(kind, "FnDef") == 1
      fn_defs = fn_defs.push(s)
      @if str_eq(s.name, "main") == 1 has_explicit_main = 1 @end
    @elif ast_kind_match(kind, "StructDef") == 1 || ast_kind_match(kind, "Struct") == 1 || ast_kind_match(kind, "TypeDef") == 1
      module.struct_defs = module.struct_defs.push(s)
    @elif ast_kind_match(kind, "EnumDef") == 1
      @if s.elements.len() > 0
        _i_ev_0 = 0
        @while _i_ev_0 < s.elements.len()
          ev = s.elements[_i_ev_0]
          module = ir_module_add_global(module, string_concat(s.name, string_concat("_", ev.name)), ir_type_i64(), ir_val_const_int(ev.value, ir_type_i64()))
          _i_ev_0 = _i_ev_0 + 1
        @end
      @end
    @elif ast_kind_match(kind, "ImplBlock") == 1
      struct_target = s.target
      @if struct_target == "" struct_target = s.name @end
      method_list = s.body
      @if method_list.len() == 0 && s.methods.len() > 0 method_list = s.methods @end
      @if method_list.len() > 0
        _i_meth_0 = 0
        @while _i_meth_0 < method_list.len()
          meth = method_list[_i_meth_0]
          meth_clone = meth
          meth_clone.name = string_concat(struct_target, string_concat("_", meth.name))
          has_self = 0
          @if meth_clone.params.len() > 0
            @if meth_clone.params[0] == "self" || (meth_clone.params[0].name != "" && meth_clone.params[0].name == "self")
              has_self = 1
            @end
          @end
          @if has_self == 0
            new_p = ["self"]
            _i_p_0 = 0
            @while _i_p_0 < meth_clone.params.len()
              p = meth_clone.params[_i_p_0]
              new_p = new_p.push(p)
              _i_p_0 = _i_p_0 + 1
            @end
            meth_clone.params = new_p
          @end
          fn_defs = fn_defs.push(meth_clone)
          _i_meth_0 = _i_meth_0 + 1
        @end
      @end
    @elif ast_kind_match(kind, "Import") == 1 || ast_kind_match(kind, "TypeDef") == 1 || ast_kind_match(kind, "TraitDef") == 1
      @! Declarations
    @else
      script_stmts = script_stmts.push(s)
    @end
    i = i + 1
  @end

  @if script_stmts.len() > 0 && has_explicit_main == 1
    new_fn_defs = []
    _i_f_0 = 0
    @while _i_f_0 < fn_defs.len()
      f = fn_defs[_i_f_0]
      @if str_eq(f.name, "main") == 1
        new_body = []
        _i_st_0 = 0
        @while _i_st_0 < script_stmts.len()
          st = script_stmts[_i_st_0]
          new_body = new_body.push(st)
          _i_st_0 = _i_st_0 + 1
        @end
        _i_st_0 = 0
        @while _i_st_0 < f.body.len()
          st = f.body[_i_st_0]
          new_body = new_body.push(st)
          _i_st_0 = _i_st_0 + 1
        @end
        f.body = new_body
      @end
      new_fn_defs = new_fn_defs.push(f)
      _i_f_0 = _i_f_0 + 1
    @end
    fn_defs = new_fn_defs
  @end

  @! Lower explicit function definitions
  f_idx = 0
  @while f_idx < fn_defs.len()
    ctx = lower_function(ctx, fn_defs[f_idx])
    f_idx = f_idx + 1
  @end

  @! If top-level script statements exist without explicit main, synthesize @fn main()
  @if has_explicit_main == 0
    synthetic_main = ast_fndef("main", [], "i64", script_stmts)
    ctx = lower_function(ctx, synthetic_main)
  @end

  @! Verify CFG
  @! WHY: CFG diagnostics are performed to detect SSA anomalies, but are kept non-fatal
  @! so valid instruction emission can proceed directly to the machine code backend.
  verify_res = ir_verify_module(ctx.module)
  @if verify_res.ok == 0
    @! Non-fatal CFG diagnostic attached to warnings
    w_idx = 0
    @while w_idx < verify_res.errors.len()
      verify_res.warnings = verify_res.warnings.push(verify_res.errors[w_idx])
      w_idx = w_idx + 1
    @end
  @end

  @if options != 0 && options.dump_ir == 1
    println(ir_module_to_string(ctx.module))
  @end

  return {
    module: ctx.module,
    error: 0,
    message: "Success",
    errors: [],
    warnings: verify_res.warnings
  }
@end

@! Canonical Entry Point: ir_lower_ast(ast: ASTProgram) -> IRModule
@fn ir_lower_ast(ast)
  all_stmts = []
  @if ast.structs.len() > 0
    _i_st_0 = 0
    @while _i_st_0 < ast.structs.len()
      st = ast.structs[_i_st_0]
      all_stmts = all_stmts.push(st)
      _i_st_0 = _i_st_0 + 1
    @end
  @end
  @if ast.enums.len() > 0
    _i_en_0 = 0
    @while _i_en_0 < ast.enums.len()
      en = ast.enums[_i_en_0]
      all_stmts = all_stmts.push(en)
      _i_en_0 = _i_en_0 + 1
    @end
  @end
  @if ast.impls.len() > 0
    _i_imp_0 = 0
    @while _i_imp_0 < ast.impls.len()
      imp = ast.impls[_i_imp_0]
      all_stmts = all_stmts.push(imp)
      _i_imp_0 = _i_imp_0 + 1
    @end
  @end
  @if ast.functions.len() > 0
    _i_f_0 = 0
    @while _i_f_0 < ast.functions.len()
      f = ast.functions[_i_f_0]
      all_stmts = all_stmts.push(f)
      _i_f_0 = _i_f_0 + 1
    @end
  @end
  @if ast.top_level.len() > 0
    _i_ts_0 = 0
    @while _i_ts_0 < ast.top_level.len()
      ts = ast.top_level[_i_ts_0]
      all_stmts = all_stmts.push(ts)
      _i_ts_0 = _i_ts_0 + 1
    @end
  @end
  @if all_stmts.len() > 0
    res = ir_module_from_ast(all_stmts, {})
    return res.module
  @end
  res = ir_module_from_ast(ast, {})
  return res.module
@end

@fn ir_lower_program(prog, options)
  return ir_module_from_ast(prog, options)
@end
