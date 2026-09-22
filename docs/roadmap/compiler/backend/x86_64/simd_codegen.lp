@! ============================================================================
@! MAYA COMPILER BACKEND — x86_64 AVX2 / AVX-512 SIMD CODEGEN (simd_codegen.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: 2-Byte (0xC5) and 3-Byte (0xC4) VEX Prefix Byte Encoders,
@!           YMM0-YMM15 Vector Register Model, AVX2 SIMD Instruction Synthesis
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. VEX PREFIX ENCODERS
@! ----------------------------------------------------------------------------

@fn vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  @! 2-byte VEX: 0xC5 [R' | vvvv | L | pp]
  @! Byte 1: 0xC5 (197)
  buf = buf.push(197)
  
  b2 = ((r_inv % 2) * 128) + ((vvvv_inv % 16) * 8) + ((l_bit % 2) * 4) + (pp % 4)
  buf = buf.push(b2)
  return buf
@end

@fn vex_emit_3byte(buf, r_inv, x_inv, b_inv, m_mmmm, w_bit, vvvv_inv, l_bit, pp)
  @! 3-byte VEX: 0xC4 [R | X | B | m-mmmm] [W | vvvv | L | pp]
  @! Byte 1: 0xC4 (196)
  buf = buf.push(196)

  b2 = ((r_inv % 2) * 128) + ((x_inv % 2) * 64) + ((b_inv % 2) * 32) + (m_mmmm % 32)
  buf = buf.push(b2)

  b3 = ((w_bit % 2) * 128) + ((vvvv_inv % 16) * 8) + ((l_bit % 2) * 4) + (pp % 4)
  buf = buf.push(b3)
  return buf
@end

@! ModRM Byte Encoder: mod(2 bits), reg(3 bits), rm(3 bits)
@fn simd_emit_modrm(buf, mod, reg, rm)
  val = ((mod % 4) * 64) + ((reg % 8) * 8) + (rm % 8)
  return buf.push(val)
@end

@! SIB Byte Encoder: scale(2 bits), index(3 bits), base(3 bits)
@fn simd_emit_sib(buf, scale, index, base)
  val = ((scale % 4) * 64) + ((index % 8) * 8) + (base % 8)
  return buf.push(val)
@end

@! ----------------------------------------------------------------------------
@! 2. AVX2 / YMM INSTRUCTION SYNTHESIS
@! ----------------------------------------------------------------------------

@! VMOVUPS ymm_dest, [base_reg + offset] (Load 256-bit unaligned)
@fn simd_emit_vmovups_load(buf, dest_ymm, base_reg, offset)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 @! unused -> all 1s
  l_bit = 1     @! 256-bit YMM
  pp = 0        @! None (0x0F 0x28)
  
  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(40) @! 0x28

  @! ModRM encoding
  @if offset == 0 && (base_reg % 8) != 5
    buf = simd_emit_modrm(buf, 0, dest_ymm % 8, base_reg % 8)
  @elif offset >= -128 && offset <= 127
    buf = simd_emit_modrm(buf, 1, dest_ymm % 8, base_reg % 8)
    disp = offset
    @if disp < 0 disp = 256 + disp @end
    buf = buf.push(disp % 256)
  @else
    buf = simd_emit_modrm(buf, 2, dest_ymm % 8, base_reg % 8)
    buf = buf.push(offset % 256)
    buf = buf.push((offset / 256) % 256)
    buf = buf.push((offset / 65536) % 256)
    buf = buf.push((offset / 16777216) % 256)
  @end
  return buf
@end

@! VMOVUPS [base_reg + offset], ymm_src (Store 256-bit unaligned)
@fn simd_emit_vmovups_store(buf, base_reg, offset, src_ymm)
  r_inv = 1 - (src_ymm / 8)
  vvvv_inv = 15
  l_bit = 1
  pp = 0
  
  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(41) @! 0x29

  @if offset == 0 && (base_reg % 8) != 5
    buf = simd_emit_modrm(buf, 0, src_ymm % 8, base_reg % 8)
  @elif offset >= -128 && offset <= 127
    buf = simd_emit_modrm(buf, 1, src_ymm % 8, base_reg % 8)
    disp = offset
    @if disp < 0 disp = 256 + disp @end
    buf = buf.push(disp % 256)
  @else
    buf = simd_emit_modrm(buf, 2, src_ymm % 8, base_reg % 8)
    buf = buf.push(offset % 256)
    buf = buf.push((offset / 256) % 256)
    buf = buf.push((offset / 65536) % 256)
    buf = buf.push((offset / 16777216) % 256)
  @end
  return buf
@end

@! VBROADCASTSS ymm_dest, [base_reg + offset] (Broadcast 32-bit float across all 8 lanes)
@fn simd_emit_vbroadcastss(buf, dest_ymm, base_reg, offset)
  r_inv = 1 - (dest_ymm / 8)
  x_inv = 1
  b_inv = 1 - (base_reg / 8)
  m_mmmm = 2    @! 0x0F 0x38
  w_bit = 0
  vvvv_inv = 15
  l_bit = 1     @! 256-bit YMM
  pp = 1        @! 0x66

  buf = vex_emit_3byte(buf, r_inv, x_inv, b_inv, m_mmmm, w_bit, vvvv_inv, l_bit, pp)
  buf = buf.push(24) @! 0x18
  buf = simd_emit_modrm(buf, 1, dest_ymm % 8, base_reg % 8)
  disp = offset
  @if disp < 0 disp = 256 + disp @end
  buf = buf.push(disp % 256)
  return buf
@end

@! VADDPS ymm_dest, ymm_src1, ymm_src2 (Add 8x float32 parallel)
@fn simd_emit_vaddps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 0

  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(88) @! 0x58
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VSUBPS ymm_dest, ymm_src1, ymm_src2 (Sub 8x float32 parallel)
@fn simd_emit_vsubps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 0

  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(92) @! 0x5C
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VMULPS ymm_dest, ymm_src1, ymm_src2 (Mul 8x float32 parallel)
@fn simd_emit_vmulps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 0

  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(89) @! 0x59
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VDIVPS ymm_dest, ymm_src1, ymm_src2 (Div 8x float32 parallel)
@fn simd_emit_vdivps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 0

  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(94) @! 0x5E
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VFMADD213PS ymm_dest, ymm_src1, ymm_src2 (dest = dest * src1 + src2)
@fn simd_emit_vfmadd213ps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  x_inv = 1
  b_inv = 1 - (src2_ymm / 8)
  m_mmmm = 2    @! 0x0F 0x38
  w_bit = 0
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1     @! 256-bit YMM
  pp = 1        @! 0x66

  buf = vex_emit_3byte(buf, r_inv, x_inv, b_inv, m_mmmm, w_bit, vvvv_inv, l_bit, pp)
  buf = buf.push(168) @! 0xA8
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VHADDPS ymm_dest, ymm_src1, ymm_src2 (Horizontal add adjacent pairs)
@fn simd_emit_vhaddps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 1 @! 0x66

  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(124) @! 0x7C
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VMINPS ymm_dest, ymm_src1, ymm_src2
@fn simd_emit_vminps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 0
  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(93) @! 0x5D
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VMAXPS ymm_dest, ymm_src1, ymm_src2
@fn simd_emit_vmaxps(buf, dest_ymm, src1_ymm, src2_ymm)
  r_inv = 1 - (dest_ymm / 8)
  vvvv_inv = 15 - (src1_ymm % 16)
  l_bit = 1
  pp = 0
  buf = vex_emit_2byte(buf, r_inv, vvvv_inv, l_bit, pp)
  buf = buf.push(95) @! 0x5F
  buf = simd_emit_modrm(buf, 3, dest_ymm % 8, src2_ymm % 8)
  return buf
@end

@! VZEROUPPER (Cleans upper 128-bit YMM registers to eliminate AVX-SSE state transition penalty)
@fn simd_emit_vzeroupper(buf)
  @! 0xC5 0xF8 0x77
  buf = buf.push(197)
  buf = buf.push(248)
  buf = buf.push(119)
  return buf
@end

@! ----------------------------------------------------------------------------
@! 3. VECTOR IR LOWERING ENGINE
@! ----------------------------------------------------------------------------

@fn simd_lower_vector_ir(vir_inst, buf)
  op = vir_inst.op
  @if op == "VLOAD"
    @! Base register RDI (7), dest YMM0
    dest_reg = 0
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    return simd_emit_vmovups_load(buf, dest_reg, 7, 0)
  @elif op == "VSTORE"
    src_reg = 0
    @if vir_inst.src != 0 && vir_inst.src.id != 0 src_reg = vir_inst.src.id % 16 @end
    return simd_emit_vmovups_store(buf, 7, 0, src_reg)
  @elif op == "VBROADCAST"
    dest_reg = 0
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    return simd_emit_vbroadcastss(buf, dest_reg, 7, 0)
  @elif op == "VADD"
    dest_reg = 0
    s1 = 0
    s2 = 1
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    @if vir_inst.left != 0 && vir_inst.left.id != 0 s1 = vir_inst.left.id % 16 @end
    @if vir_inst.right != 0 && vir_inst.right.id != 0 s2 = vir_inst.right.id % 16 @end
    return simd_emit_vaddps(buf, dest_reg, s1, s2)
  @elif op == "VSUB"
    dest_reg = 0
    s1 = 0
    s2 = 1
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    @if vir_inst.left != 0 && vir_inst.left.id != 0 s1 = vir_inst.left.id % 16 @end
    @if vir_inst.right != 0 && vir_inst.right.id != 0 s2 = vir_inst.right.id % 16 @end
    return simd_emit_vsubps(buf, dest_reg, s1, s2)
  @elif op == "VMUL"
    dest_reg = 0
    s1 = 0
    s2 = 1
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    @if vir_inst.left != 0 && vir_inst.left.id != 0 s1 = vir_inst.left.id % 16 @end
    @if vir_inst.right != 0 && vir_inst.right.id != 0 s2 = vir_inst.right.id % 16 @end
    return simd_emit_vmulps(buf, dest_reg, s1, s2)
  @elif op == "VDIV"
    dest_reg = 0
    s1 = 0
    s2 = 1
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    @if vir_inst.left != 0 && vir_inst.left.id != 0 s1 = vir_inst.left.id % 16 @end
    @if vir_inst.right != 0 && vir_inst.right.id != 0 s2 = vir_inst.right.id % 16 @end
    return simd_emit_vdivps(buf, dest_reg, s1, s2)
  @elif op == "VFMA"
    dest_reg = 0
    s1 = 0
    s2 = 1
    @if vir_inst.dest != 0 && vir_inst.dest.id != 0 dest_reg = vir_inst.dest.id % 16 @end
    @if vir_inst.a != 0 && vir_inst.a.id != 0 s1 = vir_inst.a.id % 16 @end
    @if vir_inst.b != 0 && vir_inst.b.id != 0 s2 = vir_inst.b.id % 16 @end
    return simd_emit_vfmadd213ps(buf, dest_reg, s1, s2)
  @elif op == "VREDUCE_SUM"
    @! Horizontal reduction sequence: vhaddps + extract
    dest_reg = 0
    s_reg = 0
    @if vir_inst.src != 0 && vir_inst.src.id != 0 s_reg = vir_inst.src.id % 16 @end
    buf = simd_emit_vhaddps(buf, dest_reg, s_reg, s_reg)
    buf = simd_emit_vhaddps(buf, dest_reg, dest_reg, dest_reg)
    return buf
  @end
  return buf
@end
