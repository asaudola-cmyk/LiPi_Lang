@! Maya Native x86-64 JIT Emitter (Extended)
@! Handles control flow, jumps, and ModRM encoding

import "universe/core/collections"

@fn emit_rex(buf, w, r, x, b)
  @! REX prefix is 0100WRXB (0x40 + w<<3 + r<<2 + x<<1 + b)
  val = 64 + (w * 8) + (r * 4) + (x * 2) + b
  return buf.push(val)
@end

@fn emit_modrm(buf, mod, reg, rm)
  @! ModRM byte: mod(2 bits) reg(3 bits) rm(3 bits)
  val = (mod * 64) + (reg * 8) + rm
  return buf.push(val)
@end

@fn emit_sib(buf, scale, index, base)
  @! SIB byte: scale(2 bits) index(3 bits) base(3 bits)
  val = (scale * 64) + (index * 8) + base
  return buf.push(val)
@end

@! Emit Add r64, r64 -> 0x01 ModRM
@fn jit_emit_add_reg_reg(buf, dest_reg, src_reg)
  @! REX.W
  buf = emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  buf = buf.push(1) @! 0x01
  buf = emit_modrm(buf, 3, src_reg % 8, dest_reg % 8)
  return buf
@end

@! Emit Sub r64, r64 -> 0x29 ModRM
@fn jit_emit_sub_reg_reg(buf, dest_reg, src_reg)
  buf = emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  buf = buf.push(41) @! 0x29
  buf = emit_modrm(buf, 3, src_reg % 8, dest_reg % 8)
  return buf
@end

@! Jmp rel32 -> 0xE9 rel32
@fn jit_emit_jmp(buf, rel32)
  buf = buf.push(233) @! 0xE9
  buf = buf.push(rel32 % 256)
  buf = buf.push((rel32 / 256) % 256)
  buf = buf.push((rel32 / 65536) % 256)
  buf = buf.push((rel32 / 16777216) % 256)
  return buf
@end

@! Je rel32 -> 0x0F 0x84 rel32
@fn jit_emit_je(buf, rel32)
  buf = buf.push(15)  @! 0x0F
  buf = buf.push(132) @! 0x84
  buf = buf.push(rel32 % 256)
  buf = buf.push((rel32 / 256) % 256)
  buf = buf.push((rel32 / 65536) % 256)
  buf = buf.push((rel32 / 16777216) % 256)
  return buf
@end

@! Cmp r64, r64 -> 0x39 ModRM
@fn jit_emit_cmp_reg_reg(buf, reg1, reg2)
  buf = emit_rex(buf, 1, reg2 / 8, 0, reg1 / 8)
  buf = buf.push(57) @! 0x39
  buf = emit_modrm(buf, 3, reg2 % 8, reg1 % 8)
  return buf
@end

@! Backpatching logic for forward jumps
@fn jit_patch_jump(buf, jump_offset, target_offset)
  @! Offset is from the end of the instruction, so target - (jump_offset + 4)
  rel32 = target_offset - (jump_offset + 4)
  buf = list_set(buf, jump_offset, rel32 % 256)
  buf = list_set(buf, jump_offset + 1, (rel32 / 256) % 256)
  buf = list_set(buf, jump_offset + 2, (rel32 / 65536) % 256)
  buf = list_set(buf, jump_offset + 3, (rel32 / 16777216) % 256)
  return buf
@end

@fn jit_buffer_new()
  return { bytes: [] }
@end

@fn jit_emit_push_rbp(buf)
  buf.bytes = buf.bytes.push(0x55)
  return buf
@end

@fn jit_emit_mov_rbp_rsp(buf)
  buf.bytes = buf.bytes.push(0x48)
  buf.bytes = buf.bytes.push(0x89)
  buf.bytes = buf.bytes.push(0xe5)
  return buf
@end

@fn jit_emit_pop_rbp(buf)
  buf.bytes = buf.bytes.push(0x5d)
  return buf
@end

@fn jit_emit_ret(buf)
  buf.bytes = buf.bytes.push(0xc3)
  return buf
@end

