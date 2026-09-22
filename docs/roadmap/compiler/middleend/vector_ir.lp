@! ============================================================================
@! MAYA COMPILER MIDDLEEND — VECTOR INTERMEDIATE REPRESENTATION (vector_ir.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Strongly-Typed Vector Types (VEC128, VEC256, VEC512),
@!           Vector IR Opcodes (VLOAD, VSTORE, VADD, VMUL, VFMA, VREDUCE_SUM)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. VECTOR TYPE DEFINITIONS
@! ----------------------------------------------------------------------------

@fn vec_type_new(elem_type, lanes, bit_width)
  name = "v" + lanes.to_str()
  @if elem_type == "float32"
    name = name + "f32"
  @elif elem_type == "float64"
    name = name + "f64"
  @elif elem_type == "int32"
    name = name + "i32"
  @elif elem_type == "int64"
    name = name + "i64"
  @end

  return {
    kind: "VectorType",
    elem_type: elem_type,
    lanes: lanes,
    bit_width: bit_width,
    byte_size: bit_width / 8,
    name: name
  }
@end

@fn vec_type_f32(lanes)
  return vec_type_new("float32", lanes, lanes * 32)
@end

@fn vec_type_i32(lanes)
  return vec_type_new("int32", lanes, lanes * 32)
@end

@fn vec_type_f64(lanes)
  return vec_type_new("float64", lanes, lanes * 64)
@end

@fn vec_type_byte_size(vtype)
  @if vtype == 0 return 32 @end
  return vtype.byte_size
@end

@! ----------------------------------------------------------------------------
@! 2. VECTOR REGISTER DESCRIPTOR
@! ----------------------------------------------------------------------------

@fn vreg_new(id, name, vtype)
  return {
    kind: "VectorRegister",
    id: id,
    name: name,
    type: vtype,
    is_vector: 1
  }
@end

@! ----------------------------------------------------------------------------
@! 3. VECTOR IR INSTRUCTION BUILDERS
@! ----------------------------------------------------------------------------

@fn vir_vload(dest_vreg, base_ptr, offset, vtype)
  return {
    op: "VLOAD",
    kind: "VectorInst",
    dest: dest_vreg,
    base: base_ptr,
    offset: offset,
    type: vtype
  }
@end

@fn vir_vstore(base_ptr, offset, src_vreg, vtype)
  return {
    op: "VSTORE",
    kind: "VectorInst",
    base: base_ptr,
    offset: offset,
    src: src_vreg,
    type: vtype
  }
@end

@fn vir_vbroadcast(dest_vreg, scalar_src, vtype)
  return {
    op: "VBROADCAST",
    kind: "VectorInst",
    dest: dest_vreg,
    src: scalar_src,
    type: vtype
  }
@end

@fn vir_vadd(dest_vreg, vreg_a, vreg_b, vtype)
  return {
    op: "VADD",
    kind: "VectorInst",
    dest: dest_vreg,
    left: vreg_a,
    right: vreg_b,
    type: vtype
  }
@end

@fn vir_vsub(dest_vreg, vreg_a, vreg_b, vtype)
  return {
    op: "VSUB",
    kind: "VectorInst",
    dest: dest_vreg,
    left: vreg_a,
    right: vreg_b,
    type: vtype
  }
@end

@fn vir_vmul(dest_vreg, vreg_a, vreg_b, vtype)
  return {
    op: "VMUL",
    kind: "VectorInst",
    dest: dest_vreg,
    left: vreg_a,
    right: vreg_b,
    type: vtype
  }
@end

@fn vir_vdiv(dest_vreg, vreg_a, vreg_b, vtype)
  return {
    op: "VDIV",
    kind: "VectorInst",
    dest: dest_vreg,
    left: vreg_a,
    right: vreg_b,
    type: vtype
  }
@end

@fn vir_vfma(dest_vreg, vreg_a, vreg_b, vreg_c, vtype)
  return {
    op: "VFMA",
    kind: "VectorInst",
    dest: dest_vreg,
    a: vreg_a,
    b: vreg_b,
    c: vreg_c,
    type: vtype
  }
@end

@fn vir_vmin(dest_vreg, vreg_a, vreg_b, vtype)
  return {
    op: "VMIN",
    kind: "VectorInst",
    dest: dest_vreg,
    left: vreg_a,
    right: vreg_b,
    type: vtype
  }
@end

@fn vir_vmax(dest_vreg, vreg_a, vreg_b, vtype)
  return {
    op: "VMAX",
    kind: "VectorInst",
    dest: dest_vreg,
    left: vreg_a,
    right: vreg_b,
    type: vtype
  }
@end

@fn vir_vreduce_sum(dest_scalar, vreg_src, vtype)
  return {
    op: "VREDUCE_SUM",
    kind: "VectorInst",
    dest: dest_scalar,
    src: vreg_src,
    type: vtype
  }
@end

@fn vir_vmask_load(dest_vreg, base_ptr, mask_vreg, vtype)
  return {
    op: "VMASK_LOAD",
    kind: "VectorInst",
    dest: dest_vreg,
    base: base_ptr,
    mask: mask_vreg,
    type: vtype
  }
@end

@fn vir_vmask_store(base_ptr, mask_vreg, src_vreg, vtype)
  return {
    op: "VMASK_STORE",
    kind: "VectorInst",
    base: base_ptr,
    mask: mask_vreg,
    src: src_vreg,
    type: vtype
  }
@end

@fn vir_vshuffle(dest_vreg, src_vreg, imm8, vtype)
  return {
    op: "VSHUFFLE",
    kind: "VectorInst",
    dest: dest_vreg,
    src: src_vreg,
    imm8: imm8,
    type: vtype
  }
@end

@! ----------------------------------------------------------------------------
@! 4. VECTOR IR PRETTY PRINTER / STRINGIFIER
@! ----------------------------------------------------------------------------

@fn vir_operand_name(op)
  @if op == 0 return "null" @end
  @if op.name != 0 return op.name @end
  @if op.id != 0 return "%v" + op.id.to_str() @end
  return op.to_str()
@end

@fn vir_to_string(inst)
  op = inst.op
  t_name = ""
  @if inst.type != 0
    t_name = "<" + inst.type.name + "> "
  @end

  @if op == "VLOAD"
    return vir_operand_name(inst.dest) + " = VLOAD " + t_name + "[" + vir_operand_name(inst.base) + " + " + vir_operand_name(inst.offset) + "]"
  @elif op == "VSTORE"
    return "VSTORE " + t_name + "[" + vir_operand_name(inst.base) + " + " + vir_operand_name(inst.offset) + "], " + vir_operand_name(inst.src)
  @elif op == "VBROADCAST"
    return vir_operand_name(inst.dest) + " = VBROADCAST " + t_name + vir_operand_name(inst.src)
  @elif op == "VADD" || op == "VSUB" || op == "VMUL" || op == "VDIV" || op == "VMIN" || op == "VMAX"
    return vir_operand_name(inst.dest) + " = " + op + " " + t_name + vir_operand_name(inst.left) + ", " + vir_operand_name(inst.right)
  @elif op == "VFMA"
    return vir_operand_name(inst.dest) + " = VFMA " + t_name + vir_operand_name(inst.a) + ", " + vir_operand_name(inst.b) + ", " + vir_operand_name(inst.c)
  @elif op == "VREDUCE_SUM"
    return vir_operand_name(inst.dest) + " = VREDUCE_SUM " + t_name + vir_operand_name(inst.src)
  @elif op == "VMASK_LOAD"
    return vir_operand_name(inst.dest) + " = VMASK_LOAD " + t_name + "[" + vir_operand_name(inst.base) + "], mask=" + vir_operand_name(inst.mask)
  @elif op == "VMASK_STORE"
    return "VMASK_STORE " + t_name + "[" + vir_operand_name(inst.base) + "], mask=" + vir_operand_name(inst.mask) + ", " + vir_operand_name(inst.src)
  @end

  return op + " " + t_name
@end
