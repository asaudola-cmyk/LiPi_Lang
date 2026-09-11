@! ============================================================================
@! MAYA COMPILER BACKEND — PURE MAYA X86-64 MACHINE CODE GENERATOR
@! 100% Written in Pure Maya Language — Zero External Assembler Dependencies
@! Target Architecture: Linux x86-64 (System V AMD64 ABI & Linux Kernel Syscalls)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/lipi_ir"

@! ============================================================================
@! 1. PURE MAYA BYTE BUFFER MANAGEMENT (ByteBuf)
@! ============================================================================

@struct SymbolOffsetEntry
  sym_id: i64
  name: string
  sym_offset: i64
@end

@struct ByteBuf
  bytes: array
  size: i64
@end

@fn bytebuf_new()
  return {
    bytes: [],
    size: 0
  }
@end

@fn bytebuf_push(buf, byte_val)
  v = (byte_val % 256 + 256) % 256
  buf.bytes = buf.bytes.push(v)
  buf.size = buf.size + 1
  return buf
@end

@fn bytebuf_push_bytes(buf, byte_list)
  i = 0
  num_items = byte_list.len()
  @while i < num_items
    b = byte_list[i]
    buf = bytebuf_push(buf, b)
    i = i + 1
  @end
  return buf
@end

@fn bytebuf_push16(buf, val)
  v = val
  @if v < 0
    v = v + 65536
  @end
  buf = bytebuf_push(buf, v % 256)
  buf = bytebuf_push(buf, (v / 256) % 256)
  return buf
@end

@fn bytebuf_push32(buf, val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  buf = bytebuf_push(buf, v % 256)
  buf = bytebuf_push(buf, (v / 256) % 256)
  buf = bytebuf_push(buf, (v / 65536) % 256)
  buf = bytebuf_push(buf, (v / 16777216) % 256)
  return buf
@end

@fn bytebuf_push64(buf, val)
  v = val
  i = 0
  @while i < 8
    b = v % 256
    @if b < 0
      b = b + 256
    @end
    buf = bytebuf_push(buf, b)
    v = (v - b) / 256
    i = i + 1
  @end
  return buf
@end

@fn bytebuf_patch32(buf, offset, val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  b0 = v % 256
  b1 = (v / 256) % 256
  b2 = (v / 65536) % 256
  b3 = (v / 16777216) % 256
  buf.bytes = list_set(buf.bytes, offset, b0)
  buf.bytes = list_set(buf.bytes, offset + 1, b1)
  buf.bytes = list_set(buf.bytes, offset + 2, b2)
  buf.bytes = list_set(buf.bytes, offset + 3, b3)
  return buf
@end

@fn bytebuf_to_bytes(buf)
  return buf.bytes
@end

@! ============================================================================
@! 2. HARDWARE REGISTER DEFINITIONS & AMD64 ARCHITECTURE MAP
@! ============================================================================

@! Register IDs:
@! 0=RAX, 1=RCX, 2=RDX, 3=RBX, 4=RSP, 5=RBP, 6=RSI, 7=RDI,
@! 8=R8, 9=R9, 10=R10, 11=R11, 12=R12, 13=R13, 14=R14, 15=R15

@struct PhysReg
  id: i64
  name: string
  is_callee_saved: i64
  is_arg_reg: i64
  arg_index: i64
  is_syscall_arg: i64
  syscall_arg_idx: i64
@end

@fn reg_name_to_id(name)
  n = name
  @if n == "rax" || n == "eax" || n == "ax" || n == "al" return 0 @end
  @if n == "rcx" || n == "ecx" || n == "cx" || n == "cl" return 1 @end
  @if n == "rdx" || n == "edx" || n == "dx" || n == "dl" return 2 @end
  @if n == "rbx" || n == "ebx" || n == "bx" || n == "bl" return 3 @end
  @if n == "rsp" || n == "esp" || n == "sp" || n == "spl" return 4 @end
  @if n == "rbp" || n == "ebp" || n == "bp" || n == "bpl" return 5 @end
  @if n == "rsi" || n == "esi" || n == "si" || n == "sil" return 6 @end
  @if n == "rdi" || n == "edi" || n == "di" || n == "dil" return 7 @end
  @if n == "r8"  || n == "r8d"  || n == "r8w"  || n == "r8b"  return 8 @end
  @if n == "r9"  || n == "r9d"  || n == "r9w"  || n == "r9b"  return 9 @end
  @if n == "r10" || n == "r10d" || n == "r10w" || n == "r10b" return 10 @end
  @if n == "r11" || n == "r11d" || n == "r11w" || n == "r11b" return 11 @end
  @if n == "r12" || n == "r12d" || n == "r12w" || n == "r12b" return 12 @end
  @if n == "r13" || n == "r13d" || n == "r13w" || n == "r13b" return 13 @end
  @if n == "r14" || n == "r14d" || n == "r14w" || n == "r14b" return 14 @end
  @if n == "r15" || n == "r15d" || n == "r15w" || n == "r15b" return 15 @end
  return -1
@end

@fn reg_id_to_name(id)
  @if id == 0 return "rax" @end
  @if id == 1 return "rcx" @end
  @if id == 2 return "rdx" @end
  @if id == 3 return "rbx" @end
  @if id == 4 return "rsp" @end
  @if id == 5 return "rbp" @end
  @if id == 6 return "rsi" @end
  @if id == 7 return "rdi" @end
  @if id == 8 return "r8" @end
  @if id == 9 return "r9" @end
  @if id == 10 return "r10" @end
  @if id == 11 return "r11" @end
  @if id == 12 return "r12" @end
  @if id == 13 return "r13" @end
  @if id == 14 return "r14" @end
  @if id == 15 return "r15" @end
  return "unknown"
@end

@! System V AMD64 Argument Registers (RDI, RSI, RDX, RCX, R8, R9)
@fn abi_sysv_arg_reg(idx)
  @if idx == 0 return 7 @end  @! RDI
  @if idx == 1 return 6 @end  @! RSI
  @if idx == 2 return 2 @end  @! RDX
  @if idx == 3 return 1 @end  @! RCX
  @if idx == 4 return 8 @end  @! R8
  @if idx == 5 return 9 @end  @! R9
  return -1
@end

@! Linux Syscall Argument Registers (RAX=nr, RDI, RSI, RDX, R10, R8, R9)
@fn abi_syscall_arg_reg(idx)
  @if idx == 0 return 7 @end  @! RDI
  @if idx == 1 return 6 @end  @! RSI
  @if idx == 2 return 2 @end  @! RDX
  @if idx == 3 return 10 @end @! R10 (Kernel replaces RCX)
  @if idx == 4 return 8 @end  @! R8
  @if idx == 5 return 9 @end  @! R9
  return -1
@end

@fn abi_is_callee_saved(reg_id)
  @if reg_id == 3 || reg_id == 4 || reg_id == 5 || reg_id == 12 || reg_id == 13 || reg_id == 14 || reg_id == 15
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 3. X86-64 INSTRUCTION ENCODING ENGINE
@! ============================================================================

@fn x86_rex_byte(w, r, x, b)
  return 64 + (w * 8) + (r * 4) + (x * 2) + b
@end

@fn x86_modrm_byte(mod, reg, rm)
  return (mod * 64) + ((reg % 8) * 8) + (rm % 8)
@end

@fn x86_sib_byte(scale_power, index, base)
  return (scale_power * 64) + ((index % 8) * 8) + (base % 8)
@end

@! Emit REX prefix byte if required (or forced if w=1)
@fn emit_rex(buf, w, r, x, b)
  @if w == 1 || r == 1 || x == 1 || b == 1
    b_byte = x86_rex_byte(w, r, x, b)
    bytebuf_push(buf, b_byte)
  @end
  return buf
@end

@! MOV reg, reg (64-bit)
@fn emit_mov_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  bytebuf_push(buf, 137) @! 0x89 MOV r/m64, r64
  b_byte = x86_modrm_byte(3, src_reg % 8, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! MOV reg, imm64
@fn emit_mov_reg_imm64(buf, dest_reg, imm64)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 184 + (dest_reg % 8)) @! 0xB8 + reg
  bytebuf_push64(buf, imm64)
  return buf
@end

@! MOV reg, imm32 (sign-extended to 64-bit)
@fn emit_mov_reg_imm32(buf, dest_reg, imm32)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 199) @! 0xC7
  b_byte = x86_modrm_byte(3, 0, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push32(buf, imm32)
  return buf
@end

@! MOV reg32, imm32 (zero-extended to 64-bit)
@fn emit_mov_reg32_imm32(buf, dest_reg, imm32)
  @if dest_reg >= 8
    emit_rex(buf, 0, 0, 0, 1)
  @end
  bytebuf_push(buf, 184 + (dest_reg % 8)) @! 0xB8 + reg
  bytebuf_push32(buf, imm32)
  return buf
@end

@! MOV reg, [base + disp32] (or disp8 if within signed 8-bit range, with SIB handling)
@fn emit_mov_reg_mem(buf, dest_reg, base_reg, disp32)
  emit_rex(buf, 1, dest_reg / 8, 0, base_reg / 8)
  bytebuf_push(buf, 139) @! 0x8B MOV r64, r/m64
  @if disp32 >= -128 && disp32 <= 127
    b_byte = x86_modrm_byte(1, dest_reg % 8, base_reg % 8)
    bytebuf_push(buf, b_byte)
    @if base_reg % 8 == 4
      b_byte = x86_sib_byte(0, 4, 4)
      bytebuf_push(buf, b_byte) @! 0x24 SIB for RSP/R12
    @end
    bytebuf_push(buf, disp32)
  @else
    b_byte = x86_modrm_byte(2, dest_reg % 8, base_reg % 8)
    bytebuf_push(buf, b_byte)
    @if base_reg % 8 == 4
      b_byte = x86_sib_byte(0, 4, 4)
      bytebuf_push(buf, b_byte) @! 0x24 SIB for RSP/R12
    @end
    bytebuf_push32(buf, disp32)
  @end
  return buf
@end

@! MOV [base + disp32], reg
@fn emit_mov_mem_reg(buf, base_reg, disp32, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, base_reg / 8)
  bytebuf_push(buf, 137) @! 0x89 MOV r/m64, r64
  @if disp32 >= -128 && disp32 <= 127
    b_byte = x86_modrm_byte(1, src_reg % 8, base_reg % 8)
    bytebuf_push(buf, b_byte)
    @if base_reg % 8 == 4
      b_byte = x86_sib_byte(0, 4, 4)
      bytebuf_push(buf, b_byte) @! 0x24 SIB for RSP/R12
    @end
    bytebuf_push(buf, disp32)
  @else
    b_byte = x86_modrm_byte(2, src_reg % 8, base_reg % 8)
    bytebuf_push(buf, b_byte)
    @if base_reg % 8 == 4
      b_byte = x86_sib_byte(0, 4, 4)
      bytebuf_push(buf, b_byte) @! 0x24 SIB for RSP/R12
    @end
    bytebuf_push32(buf, disp32)
  @end
  return buf
@end

@! MOV reg, [base + index*scale + disp32] (SIB addressing)
@fn emit_mov_reg_mem_sib(buf, dest_reg, base_reg, index_reg, scale_power, disp32)
  emit_rex(buf, 1, dest_reg / 8, index_reg / 8, base_reg / 8)
  bytebuf_push(buf, 139) @! 0x8B
  b_byte = x86_modrm_byte(2, dest_reg % 8, 4)
  bytebuf_push(buf, b_byte) @! rm=4 triggers SIB
  b_byte = x86_sib_byte(scale_power, index_reg % 8, base_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push32(buf, disp32)
  return buf
@end

@! MOV [base + index*scale + disp32], reg (SIB addressing)
@fn emit_mov_mem_sib_reg(buf, base_reg, index_reg, scale_power, disp32, src_reg)
  emit_rex(buf, 1, src_reg / 8, index_reg / 8, base_reg / 8)
  bytebuf_push(buf, 137) @! 0x89
  b_byte = x86_modrm_byte(2, src_reg % 8, 4)
  bytebuf_push(buf, b_byte) @! rm=4 triggers SIB
  b_byte = x86_sib_byte(scale_power, index_reg % 8, base_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push32(buf, disp32)
  return buf
@end

@! ADD dest, src (64-bit)
@fn emit_add_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  bytebuf_push(buf, 1) @! 0x01 ADD r/m64, r64
  b_byte = x86_modrm_byte(3, src_reg % 8, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! ADD dest, imm32 (64-bit)
@fn emit_add_reg_imm32(buf, dest_reg, imm32)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  @if imm32 >= -128 && imm32 <= 127
    bytebuf_push(buf, 131) @! 0x83
    b_byte = x86_modrm_byte(3, 0, dest_reg % 8)
    bytebuf_push(buf, b_byte)
    bytebuf_push(buf, imm32)
  @else
    bytebuf_push(buf, 129) @! 0x81
    b_byte = x86_modrm_byte(3, 0, dest_reg % 8)
    bytebuf_push(buf, b_byte)
    bytebuf_push32(buf, imm32)
  @end
  return buf
@end

@! SUB dest, src (64-bit)
@fn emit_sub_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  bytebuf_push(buf, 41) @! 0x29 SUB r/m64, r64
  b_byte = x86_modrm_byte(3, src_reg % 8, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! SUB dest, imm32 (64-bit)
@fn emit_sub_reg_imm32(buf, dest_reg, imm32)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  @if imm32 >= -128 && imm32 <= 127
    bytebuf_push(buf, 131) @! 0x83
    b_byte = x86_modrm_byte(3, 5, dest_reg % 8)
    bytebuf_push(buf, b_byte)
    bytebuf_push(buf, imm32)
  @else
    bytebuf_push(buf, 129) @! 0x81
    b_byte = x86_modrm_byte(3, 5, dest_reg % 8)
    bytebuf_push(buf, b_byte)
    bytebuf_push32(buf, imm32)
  @end
  return buf
@end

@! IMUL dest, src (64-bit signed multiply)
@fn emit_imul_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, dest_reg / 8, 0, src_reg / 8)
  bytebuf_push(buf, 15)  @! 0x0F
  bytebuf_push(buf, 175) @! 0xAF
  b_byte = x86_modrm_byte(3, dest_reg % 8, src_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! IMUL dest, src, imm32 (64-bit)
@fn emit_imul_reg_reg_imm32(buf, dest_reg, src_reg, imm32)
  emit_rex(buf, 1, dest_reg / 8, 0, src_reg / 8)
  bytebuf_push(buf, 105) @! 0x69
  b_byte = x86_modrm_byte(3, dest_reg % 8, src_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push32(buf, imm32)
  return buf
@end

@! IDIV src (64-bit signed divide RDX:RAX by src; RAX=quotient, RDX=remainder)
@fn emit_idiv_reg(buf, src_reg)
  emit_rex(buf, 1, 0, 0, src_reg / 8)
  bytebuf_push(buf, 247) @! 0xF7
  b_byte = x86_modrm_byte(3, 7, src_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! CQO (sign-extend RAX into RDX:RAX)
@fn emit_cqo(buf)
  bytebuf_push(buf, 72)  @! 0x48 REX.W
  bytebuf_push(buf, 153) @! 0x99 CQO
  return buf
@end

@! AND dest, src (64-bit)
@fn emit_and_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  bytebuf_push(buf, 33) @! 0x21
  b_byte = x86_modrm_byte(3, src_reg % 8, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! OR dest, src (64-bit)
@fn emit_or_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  bytebuf_push(buf, 9) @! 0x09
  b_byte = x86_modrm_byte(3, src_reg % 8, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! XOR dest, src (64-bit)
@fn emit_xor_reg_reg(buf, dest_reg, src_reg)
  emit_rex(buf, 1, src_reg / 8, 0, dest_reg / 8)
  bytebuf_push(buf, 49) @! 0x31
  b_byte = x86_modrm_byte(3, src_reg % 8, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! SHL dest, CL (64-bit logical shift left)
@fn emit_shl_reg_cl(buf, dest_reg)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 211) @! 0xD3
  b_byte = x86_modrm_byte(3, 4, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! SHL dest, imm8
@fn emit_shl_reg_imm8(buf, dest_reg, imm8)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 193) @! 0xC1
  b_byte = x86_modrm_byte(3, 4, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push(buf, imm8)
  return buf
@end

@! SHR dest, CL (64-bit logical shift right)
@fn emit_shr_reg_cl(buf, dest_reg)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 211) @! 0xD3
  b_byte = x86_modrm_byte(3, 5, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! SHR dest, imm8
@fn emit_shr_reg_imm8(buf, dest_reg, imm8)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 193) @! 0xC1
  b_byte = x86_modrm_byte(3, 5, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push(buf, imm8)
  return buf
@end

@! SAR dest, CL (64-bit arithmetic shift right)
@fn emit_sar_reg_cl(buf, dest_reg)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 211) @! 0xD3
  b_byte = x86_modrm_byte(3, 7, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! SAR dest, imm8
@fn emit_sar_reg_imm8(buf, dest_reg, imm8)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 193) @! 0xC1
  b_byte = x86_modrm_byte(3, 7, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push(buf, imm8)
  return buf
@end

@! NEG dest (64-bit two's complement negation)
@fn emit_neg_reg(buf, dest_reg)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 247) @! 0xF7
  b_byte = x86_modrm_byte(3, 3, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! NOT dest (64-bit bitwise NOT)
@fn emit_not_reg(buf, dest_reg)
  emit_rex(buf, 1, 0, 0, dest_reg / 8)
  bytebuf_push(buf, 247) @! 0xF7
  b_byte = x86_modrm_byte(3, 2, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! CMP reg1, reg2 (64-bit)
@fn emit_cmp_reg_reg(buf, reg1, reg2)
  emit_rex(buf, 1, reg2 / 8, 0, reg1 / 8)
  bytebuf_push(buf, 57) @! 0x39 CMP r/m64, r64
  b_byte = x86_modrm_byte(3, reg2 % 8, reg1 % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! CMP reg, imm32 (64-bit)
@fn emit_cmp_reg_imm32(buf, reg, imm32)
  emit_rex(buf, 1, 0, 0, reg / 8)
  bytebuf_push(buf, 129) @! 0x81
  b_byte = x86_modrm_byte(3, 7, reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push32(buf, imm32)
  return buf
@end

@! TEST reg1, reg2 (64-bit)
@fn emit_test_reg_reg(buf, reg1, reg2)
  emit_rex(buf, 1, reg2 / 8, 0, reg1 / 8)
  bytebuf_push(buf, 133) @! 0x85 TEST r/m64, r64
  b_byte = x86_modrm_byte(3, reg2 % 8, reg1 % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! LEA dest, [base + disp32] (64-bit)
@fn emit_lea_reg_mem(buf, dest_reg, base_reg, disp32)
  emit_rex(buf, 1, dest_reg / 8, 0, base_reg / 8)
  bytebuf_push(buf, 141) @! 0x8D LEA r64, m
  b_byte = x86_modrm_byte(2, dest_reg % 8, base_reg % 8)
  bytebuf_push(buf, b_byte)
  @if base_reg % 8 == 4
    b_byte = x86_sib_byte(0, 4, 4)
    bytebuf_push(buf, b_byte)
  @end
  bytebuf_push32(buf, disp32)
  return buf
@end

@! LEA dest, [base + index*scale + disp32] (64-bit SIB)
@fn emit_lea_reg_sib(buf, dest_reg, base_reg, index_reg, scale_power, disp32)
  emit_rex(buf, 1, dest_reg / 8, index_reg / 8, base_reg / 8)
  bytebuf_push(buf, 141) @! 0x8D
  b_byte = x86_modrm_byte(2, dest_reg % 8, 4)
  bytebuf_push(buf, b_byte)
  b_byte = x86_sib_byte(scale_power, index_reg % 8, base_reg % 8)
  bytebuf_push(buf, b_byte)
  bytebuf_push32(buf, disp32)
  return buf
@end

@! PUSH reg (64-bit)
@fn emit_push_reg(buf, reg)
  @if reg >= 8
    bytebuf_push(buf, 65) @! 0x41 REX.B
  @end
  bytebuf_push(buf, 80 + (reg % 8)) @! 0x50 + reg
  return buf
@end

@! POP reg (64-bit)
@fn emit_pop_reg(buf, reg)
  @if reg >= 8
    bytebuf_push(buf, 65) @! 0x41 REX.B
  @end
  bytebuf_push(buf, 88 + (reg % 8)) @! 0x58 + reg
  return buf
@end

@! RET (Near return)
@fn emit_ret(buf)
  bytebuf_push(buf, 195) @! 0xC3 RET
  return buf
@end

@! NOP
@fn emit_nop(buf)
  bytebuf_push(buf, 144) @! 0x90 NOP
  return buf
@end

@! SYSCALL (0x0F, 0x05)
@fn emit_syscall(buf)
  bytebuf_push(buf, 15) @! 0x0F
  bytebuf_push(buf, 5)  @! 0x05
  return buf
@end

@! JMP rel32 (0xE9 disp32)
@fn emit_jmp_rel32(buf, rel32)
  bytebuf_push(buf, 233) @! 0xE9
  bytebuf_push32(buf, rel32)
  return buf
@end

@! JMP reg (indirect jump 0xFF /4)
@fn emit_jmp_reg(buf, reg)
  @if reg >= 8
    bytebuf_push(buf, 65) @! 0x41
  @end
  bytebuf_push(buf, 255) @! 0xFF
  b_byte = x86_modrm_byte(3, 4, reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! Jcc rel32 (Conditional branch with 32-bit displacement)
@fn emit_jcc_rel32(buf, cond_code, rel32)
  @! Emits conditional jump (Jcc) rel32 with byte-comparative condition code dispatch
  @! WHY: Uses str_eq to match condition mnemonic instead of pointer comparison (==),
  @! which fails across function boundaries in freestanding Maya.
  bytebuf_push(buf, 15) @! 0x0F
  op = 132 @! Default 0x84 (JE)
  @if str_eq(cond_code, "je") == 1  || str_eq(cond_code, "eq") == 1 || str_eq(cond_code, "jz") == 1  op = 132 @end @! 0x84
  @if str_eq(cond_code, "jne") == 1 || str_eq(cond_code, "ne") == 1 || str_eq(cond_code, "jnz") == 1 op = 133 @end @! 0x85
  @if str_eq(cond_code, "jb") == 1  || str_eq(cond_code, "jc") == 1 || str_eq(cond_code, "ult") == 1 op = 130 @end @! 0x82
  @if str_eq(cond_code, "jae") == 1 || str_eq(cond_code, "jnc") == 1|| str_eq(cond_code, "uge") == 1 op = 131 @end @! 0x83
  @if str_eq(cond_code, "jl") == 1  || str_eq(cond_code, "slt") == 1                       op = 140 @end @! 0x8C
  @if str_eq(cond_code, "jge") == 1 || str_eq(cond_code, "sge") == 1                       op = 141 @end @! 0x8D
  @if str_eq(cond_code, "jle") == 1 || str_eq(cond_code, "sle") == 1                       op = 142 @end @! 0x8E
  @if str_eq(cond_code, "jg") == 1  || str_eq(cond_code, "sgt") == 1                       op = 143 @end @! 0x8F
  bytebuf_push(buf, op)
  bytebuf_push32(buf, rel32)
  return buf
@end

@! CALL rel32 (0xE8 disp32)
@fn emit_call_rel32(buf, rel32)
  bytebuf_push(buf, 232) @! 0xE8
  bytebuf_push32(buf, rel32)
  return buf
@end

@! CALL reg (indirect call 0xFF /2)
@fn emit_call_reg(buf, reg)
  @if reg >= 8
    bytebuf_push(buf, 65) @! 0x41
  @end
  bytebuf_push(buf, 255) @! 0xFF
  b_byte = x86_modrm_byte(3, 2, reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! SETcc reg8 (Sets lower 8-bit register according to condition flags)
@fn emit_setcc_reg8(buf, cond_code, dest_reg)
  @if dest_reg >= 4 && dest_reg < 8
    @! Requires REX prefix to access SPL, BPL, SIL, DIL
    bytebuf_push(buf, 64) @! 0x40
  @elif dest_reg >= 8
    bytebuf_push(buf, 65) @! 0x41 (REX.B)
  @end
  bytebuf_push(buf, 15) @! 0x0F
  op = 148 @! Default 0x94 (SETE)
  @if str_eq(cond_code, "eq") == 1  || str_eq(cond_code, "je") == 1  || str_eq(cond_code, "sete") == 1  op = 148 @end @! 0x94
  @if str_eq(cond_code, "ne") == 1  || str_eq(cond_code, "jne") == 1 || str_eq(cond_code, "setne") == 1 op = 149 @end @! 0x95
  @if str_eq(cond_code, "ult") == 1 || str_eq(cond_code, "jb") == 1  || str_eq(cond_code, "setb") == 1  op = 146 @end @! 0x92
  @if str_eq(cond_code, "uge") == 1 || str_eq(cond_code, "jae") == 1 || str_eq(cond_code, "setae") == 1 op = 147 @end @! 0x93
  @if str_eq(cond_code, "slt") == 1 || str_eq(cond_code, "jl") == 1  || str_eq(cond_code, "setl") == 1  op = 156 @end @! 0x9C
  @if str_eq(cond_code, "sge") == 1 || str_eq(cond_code, "jge") == 1 || str_eq(cond_code, "setge") == 1 op = 157 @end @! 0x9D
  @if str_eq(cond_code, "sle") == 1 || str_eq(cond_code, "jle") == 1 || str_eq(cond_code, "setle") == 1 op = 158 @end @! 0x9E
  @if str_eq(cond_code, "sgt") == 1 || str_eq(cond_code, "jg") == 1  || str_eq(cond_code, "setg") == 1  op = 159 @end @! 0x9F
  bytebuf_push(buf, op)
  b_byte = x86_modrm_byte(3, 0, dest_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! MOVZX reg64, reg8 (Zero-extends 8-bit register to 64-bit)
@fn emit_movzx_reg64_reg8(buf, dest_reg, src_reg)
  r_bit = dest_reg / 8
  b_bit = 0
  @if src_reg >= 4 && src_reg < 8
    b_bit = 0 @! REX required
  @elif src_reg >= 8
    b_bit = 1
  @end
  emit_rex(buf, 1, r_bit, 0, b_bit)
  bytebuf_push(buf, 15)  @! 0x0F
  bytebuf_push(buf, 182) @! 0xB6
  b_byte = x86_modrm_byte(3, dest_reg % 8, src_reg % 8)
  bytebuf_push(buf, b_byte)
  return buf
@end

@! ============================================================================
@! 4. STACK FRAME LAYOUT & PROLOGUE / EPILOGUE ARCHITECTURE
@! ============================================================================

@struct FrameSlot
  slot_kind: string    @! "local", "spill", "param", "saved_reg"
  name: string         @! "%v0", "loc_0", "param_0"
  rbp_offset: i64      @! Negative for stack locals (-8, -16...); Positive for incoming stack args
  size_bytes: i64
@end

@struct StackFrameLayout
  fn_name: string
  num_locals: i64
  num_spills: i64
  num_saved_regs: i64
  num_out_args: i64
  total_bytes: i64
  aligned_size: i64    @! Divisible by 16 (minimum 16)
  slots: array         @! Array of FrameSlot
  saved_reg_ids: array
@end

@fn stack_frame_build(fn_name, num_locals, num_spills, saved_reg_ids, max_out_args)
  saved_cnt = saved_reg_ids.len()
  out_args_cnt = 0
  @if max_out_args > 6
    out_args_cnt = max_out_args - 6
  @end

  total_slots = saved_cnt + num_locals + num_spills + out_args_cnt
  raw_bytes = total_slots * 8
  
  @! 16-byte alignment calculation
  aligned_bytes = raw_bytes
  rem = raw_bytes % 16
  @if rem != 0
    aligned_bytes = raw_bytes + (16 - rem)
  @end
  @if aligned_bytes == 0
    aligned_bytes = 16
  @end

  slots = []
  current_offset = -8

  @! Callee-saved register slots
  i = 0
  @while i < saved_cnt
    slots = slots.push({
      slot_kind: "saved_reg",
      name: string_concat("saved_", reg_id_to_name(saved_reg_ids[i])),
      rbp_offset: current_offset,
      size_bytes: 8
    })
    current_offset = current_offset - 8
    i = i + 1
  @end

  @! Local variable slots
  j = 0
  @while j < num_locals
    slots = slots.push({
      slot_kind: "local",
      name: string_concat("local_", int_to_str(j)),
      rbp_offset: current_offset,
      size_bytes: 8
    })
    current_offset = current_offset - 8
    j = j + 1
  @end

  @! Virtual register spill slots
  k = 0
  @while k < num_spills
    slots = slots.push({
      slot_kind: "spill",
      name: string_concat("spill_", int_to_str(k)),
      rbp_offset: current_offset,
      size_bytes: 8
    })
    current_offset = current_offset - 8
    k = k + 1
  @end

  return {
    fn_name: fn_name,
    num_locals: num_locals,
    num_spills: num_spills,
    num_saved_regs: saved_cnt,
    num_out_args: out_args_cnt,
    total_bytes: raw_bytes,
    aligned_size: aligned_bytes,
    slots: slots,
    saved_reg_ids: saved_reg_ids
  }
@end

@fn emit_frame_prologue(buf, frame)
  @! push rbp (0x55)
  emit_push_reg(buf, 5)
  @! mov rbp, rsp (0x48, 0x89, 0xE5)
  emit_mov_reg_reg(buf, 5, 4)
  @! sub rsp, aligned_size (0x48, 0x81, 0xEC, disp32)
  @if frame.aligned_size > 0
    emit_sub_reg_imm32(buf, 4, frame.aligned_size)
  @end
  idx = 0
  len = frame.saved_reg_ids.len()
  @while idx < len
    reg_id = frame.saved_reg_ids[idx]
    emit_push_reg(buf, reg_id)
    idx = idx + 1
  @end
  return buf
@end

@fn emit_frame_epilogue(buf, frame)
  @! Pop callee-saved registers in reverse order
  idx = frame.saved_reg_ids.len() - 1
  @while idx >= 0
    reg_id = frame.saved_reg_ids[idx]
    emit_pop_reg(buf, reg_id)
    idx = idx - 1
  @end
  @! mov rsp, rbp (0x48, 0x89, 0xEC)
  emit_mov_reg_reg(buf, 4, 5)
  @! pop rbp (0x5D)
  emit_pop_reg(buf, 5)
  @! ret (0xC3)
  emit_ret(buf)
  return buf
@end

@! ============================================================================
@! 5. RELOCATION & FIXUP DATA STRUCTURES
@! ============================================================================

@struct X86Fixup
  kind: string         @! "jmp", "jcc", "call", "rodata"
  cond_code: string    @! For conditional jumps ("je", "jne", etc.)
  fixup_offset: i64    @! Offset in byte buffer where 4-byte displacement is located
  target_id: i64       @! Target basic block ID
  target_name: string  @! Target function or symbol name
@end

@struct FnOffsetEntry
  fn_sym: string
  fn_byte_off: i64
@end

@struct RodataOffsetEntry
  ro_lbl: string
  ro_byte_off: i64
@end

@struct X86Symbol
  name: string
  offset: i64
  size: i64
  section: string      @! ".text", ".rodata"
@end

@struct X86Emitter
  buf: ByteBuf
  block_offsets: array @! Maps block_id -> byte buffer offset
  fixups: array        @! Branch fixups within function
  fn_fixups: array     @! Inter-function call fixups
  rodata_fixups: array @! Rodata references
  slot_map: array      @! Maps variable/vreg name -> RBP offset
  frame: StackFrameLayout
  alloca_set: array    @! Names of alloca registers/variables that represent stack slots
@end

@fn x86_emitter_new(frame)
  return {
    buf: bytebuf_new(),
    block_offsets: [],
    fixups: [],
    fn_fixups: [],
    rodata_fixups: [],
    slot_map: [],
    frame: frame,
    alloca_set: []
  }
@end

@! ============================================================================
@! 6. MAYA IR TO MACHINE CODE LOWERING ENGINE
@! ============================================================================

@fn slot_map_get(slots, key, default_val)
  @if key == "" return default_val @end
_i_entry_0 = 0
@while _i_entry_0 < slots.len()
  entry = slots[_i_entry_0]
    @if str_eq(entry.name, key) == 1
      return entry.rbp_offset
    @end
  _i_entry_0 = _i_entry_0 + 1
@end
  return default_val
@end

@fn slot_map_set(slots, key, offset)
  @if key == "" return slots @end
  _i_entry_0 = 0
  @while _i_entry_0 < slots.len()
    entry = slots[_i_entry_0]
    @if str_eq(entry.name, key) == 1
      entry.rbp_offset = offset
      return slots
    @end
    _i_entry_0 = _i_entry_0 + 1
  @end
  return slots.push({
    slot_kind: "local",
    name: key,
    rbp_offset: offset,
    size_bytes: 8
  })
@end

@! Check if a variable or register name represents an alloca stack slot
@! WHY: Local variables and parameters are stored in stack slots (RBP offsets), whereas
@! pointer expressions (GEP struct fields, array element pointers) hold memory addresses
@! in registers and must be dereferenced with MOV RAX, [RCX] or written with MOV [RCX], RAX.
@fn is_alloca_reg(alloca_set, name)
  @if str_len(name) == 0 return 0 @end
  idx = 0
  num = alloca_set.len()
  @while idx < num
    @if str_eq(alloca_set[idx], name) == 1
      return 1
    @end
    idx = idx + 1
  @end
  return 0
@end

@! Helper to load an IRVal into a designated physical register (RAX, RCX, RDX, etc.)
@fn x86_lower_load_val_to_reg(emitter, val, target_reg)
  buf = emitter.buf
  @if val == 0
    emit_xor_reg_reg(buf, target_reg, target_reg)
    return emitter
  @end

  kind = val.val_kind
  @if str_eq(kind, "const_int") == 1
    emit_mov_reg_imm64(buf, target_reg, val.val_int)
  @elif str_eq(kind, "const_bool") == 1
    emit_mov_reg_imm32(buf, target_reg, val.val_int)
  @elif str_eq(kind, "const_null") == 1
    emit_xor_reg_reg(buf, target_reg, target_reg)
  @elif str_eq(kind, "str_ref") == 1
    @! Emit LEA target_reg, [RIP + disp32] with rodata fixup
    emit_rex(buf, 1, target_reg / 8, 0, 0)
    bytebuf_push(buf, 141) @! 0x8D LEA
    b_byte = x86_modrm_byte(0, target_reg % 8, 5)
    bytebuf_push(buf, b_byte) @! mod=0, rm=5 -> RIP-relative
    fixup_off = buf.bytes.len()
    bytebuf_push32(buf, 0) @! Placeholder displacement
    emitter.rodata_fixups = emitter.rodata_fixups.push({
      kind: "rodata",
      cond_code: "",
      fixup_offset: fixup_off,
      target_id: -1,
      target_name: val.name
    })
  @elif str_eq(kind, "param") == 1
    p_off = 0
    @if val.val_index >= 0
      p_off = slot_map_get(emitter.slot_map, string_concat("%param_", int_to_str(val.val_index)), 0)
    @end
    @if p_off == 0 && val.name != ""
      p_off = slot_map_get(emitter.slot_map, val.name, 0)
    @end
    @if p_off != 0
      emit_mov_reg_mem(buf, target_reg, 5, p_off)
    @else
      emit_xor_reg_reg(buf, target_reg, target_reg)
    @end
  @else
    @! "reg", "param", or local variable identifier
    var_name = val.name
    off = slot_map_get(emitter.slot_map, var_name, 0)
    @if off == 0 && val.val_id >= 0
      off = slot_map_get(emitter.slot_map, string_concat("%v_", int_to_str(val.val_id)), 0)
    @end

    @if off != 0
      emit_mov_reg_mem(buf, target_reg, 5, off) @! [rbp + off]
    @else
      @! If not in slot map, check if it's a numeric constant
      @if val.val_int != 0 || var_name == "0"
        emit_mov_reg_imm64(buf, target_reg, val.val_int)
      @else
        emit_xor_reg_reg(buf, target_reg, target_reg)
      @end
    @end
  @end

  return emitter
@end

@! Helper to store a physical register into destination variable's stack slot
@fn x86_lower_store_reg_to_dest(emitter, src_reg, dest_name)
  @if dest_name == "" || dest_name == 0
    return emitter
  @end
  off = slot_map_get(emitter.slot_map, dest_name, 0)
  @if off != 0
    emit_mov_mem_reg(emitter.buf, 5, off, src_reg) @! [rbp + off] = src_reg
  @end
  return emitter
@end

@! Lower an individual IR instruction
@fn x86_lower_ir_inst(emitter, inst)
  buf = emitter.buf
  op = inst.op
  @if op == "" || op == 0 op = inst.inst_op @end

  @! --------------------------------------------------------------------------
  @! 1. ALLOCA (Stack Slot Allocation)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "ALLOCA") == 1 || str_eq(op, "alloca") == 1
    @! Stack slot is already allocated in the frame layout.
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 2. LOAD (Memory Dereference / Stack Slot Read)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "LOAD") == 1 || str_eq(op, "load") == 1
    ptr_val = inst.ptr
    @if ptr_val == 0 && inst.args.len() > 0 ptr_val = inst.args[0] @end
    ptr_name = ""
    @if ptr_val != 0
      @if ptr_val.name != 0 && str_len(ptr_val.name) > 0
        ptr_name = ptr_val.name
      @elif ptr_val.val_id >= 0
        ptr_name = string_concat("%v_", int_to_str(ptr_val.val_id))
      @end
    @end

    @! WHY: Differentiate alloca stack slots (local variables/params) from general pointers
    @! (GEP struct fields, array element pointers, heap memory). Stack slots are loaded from
    @! [RBP + off], whereas memory pointers in registers are dereferenced via MOV RAX, [RCX].
    is_alloca = is_alloca_reg(emitter.alloca_set, ptr_name)
    @if is_alloca == 0 && ptr_val != 0 && ptr_val.val_id >= 0
      is_alloca = is_alloca_reg(emitter.alloca_set, string_concat("%v_", int_to_str(ptr_val.val_id)))
    @end

    @if is_alloca == 1
      off = slot_map_get(emitter.slot_map, ptr_name, 0)
      @if off == 0 && ptr_val != 0 && ptr_val.val_id >= 0
        off = slot_map_get(emitter.slot_map, string_concat("%v_", int_to_str(ptr_val.val_id)), 0)
      @end
      @if off == 0 && ptr_name != ""
        cur_off = - (emitter.slot_map.len() + 1) * 8
        emitter.slot_map = slot_map_set(emitter.slot_map, ptr_name, cur_off)
        off = cur_off
      @end
      @! Local stack slot variable: load directly into RAX
      emit_mov_reg_mem(buf, 0, 5, off) @! MOV RAX, [RBP + off]
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    @else
      @! Direct memory pointer dereference: load pointer address into RCX, then read [RCX] into RAX
      x86_lower_load_val_to_reg(emitter, ptr_val, 1) @! Load pointer address into RCX
      emit_mov_reg_mem(buf, 0, 1, 0)                 @! MOV RAX, [RCX]
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    @end
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 3. STORE (Memory Write / Stack Slot Write)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "STORE") == 1 || str_eq(op, "store") == 1
    val_operand = inst.inst_val
    ptr_operand = inst.ptr
    @if inst.args.len() >= 2
      val_operand = inst.args[0]
      ptr_operand = inst.args[1]
    @end

    ptr_name = ""
    @if ptr_operand != 0
      @if ptr_operand.name != 0 && str_len(ptr_operand.name) > 0
        ptr_name = ptr_operand.name
      @elif ptr_operand.val_id >= 0
        ptr_name = string_concat("%v_", int_to_str(ptr_operand.val_id))
      @end
    @end

    @! WHY: Differentiate alloca stack slots (local variables/params) from general pointers
    @! (GEP struct fields, array element pointers, heap memory). Stack slots are written via
    @! MOV [RBP + off], RAX, whereas memory pointers in registers are written via MOV [RCX], RAX.
    is_alloca = is_alloca_reg(emitter.alloca_set, ptr_name)
    @if is_alloca == 0 && ptr_operand != 0 && ptr_operand.val_id >= 0
      is_alloca = is_alloca_reg(emitter.alloca_set, string_concat("%v_", int_to_str(ptr_operand.val_id)))
    @end

    x86_lower_load_val_to_reg(emitter, val_operand, 0) @! Load value into RAX

    @if is_alloca == 1
      off = slot_map_get(emitter.slot_map, ptr_name, 0)
      @if off == 0 && ptr_operand != 0 && ptr_operand.val_id >= 0
        off = slot_map_get(emitter.slot_map, string_concat("%v_", int_to_str(ptr_operand.val_id)), 0)
      @end
      @if off == 0 && ptr_name != ""
        cur_off = - (emitter.slot_map.len() + 1) * 8
        emitter.slot_map = slot_map_set(emitter.slot_map, ptr_name, cur_off)
        off = cur_off
      @end
      @! Local stack slot variable: store RAX directly into [RBP + off]
      emit_mov_mem_reg(buf, 5, off, 0)                 @! MOV [RBP + off], RAX
    @else
      @! Direct memory pointer write: load pointer address into RCX, then write RAX into [RCX]
      x86_lower_load_val_to_reg(emitter, ptr_operand, 1) @! Load pointer into RCX
      emit_mov_mem_reg(buf, 1, 0, 0)                     @! MOV [RCX], RAX
    @end
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 4. GEP (Get Element Pointer)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "GEP") == 1 || str_eq(op, "gep") == 1
    base_val = inst.left
    idx_val  = inst.right
    @if inst.args.len() >= 2
      base_val = inst.args[0]
      idx_val  = inst.args[1]
    @end
    x86_lower_load_val_to_reg(emitter, base_val, 0) @! Base pointer into RAX
    x86_lower_load_val_to_reg(emitter, idx_val, 1)  @! Index into RCX
    stride = inst.stride
    @if stride == 8
      emit_lea_reg_sib(buf, 0, 0, 1, 3, 0) @! LEA RAX, [RAX + RCX*8]
    @elif stride == 4
      emit_lea_reg_sib(buf, 0, 0, 1, 2, 0) @! LEA RAX, [RAX + RCX*4]
    @elif stride == 2
      emit_lea_reg_sib(buf, 0, 0, 1, 1, 0) @! LEA RAX, [RAX + RCX*2]
    @elif stride == 1
      emit_lea_reg_sib(buf, 0, 0, 1, 0, 0) @! LEA RAX, [RAX + RCX*1]
    @else
      @if stride != 0
        emit_imul_reg_reg_imm32(buf, 1, 1, stride)
      @end
      emit_add_reg_reg(buf, 0, 1)
    @end
    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 5. BINARY ARITHMETIC & LOGIC (ADD, SUB, MUL, SDIV, SREM, AND, OR, XOR, SHL, SHR)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "ADD") == 1 || str_eq(op, "SUB") == 1 || str_eq(op, "MUL") == 1 || str_eq(op, "SDIV") == 1 || str_eq(op, "SREM") == 1 || str_eq(op, "AND") == 1 || str_eq(op, "OR") == 1 || str_eq(op, "XOR") == 1 || str_eq(op, "SHL") == 1 || str_eq(op, "SHR") == 1 || str_eq(op, "add") == 1 || str_eq(op, "sub") == 1 || str_eq(op, "mul") == 1 || str_eq(op, "div") == 1 || str_eq(op, "mod") == 1 || str_eq(op, "and") == 1 || str_eq(op, "or") == 1 || str_eq(op, "xor") == 1 || str_eq(op, "shl") == 1 || str_eq(op, "shr") == 1
    lhs_val = inst.left
    rhs_val = inst.right
    @if inst.args.len() >= 2
      lhs_val = inst.args[0]
      rhs_val = inst.args[1]
    @end
    x86_lower_load_val_to_reg(emitter, lhs_val, 0) @! LHS into RAX
    x86_lower_load_val_to_reg(emitter, rhs_val, 1) @! RHS into RCX

    @if str_eq(op, "ADD") == 1 || str_eq(op, "add") == 1
      emit_add_reg_reg(buf, 0, 1)
    @elif str_eq(op, "SUB") == 1 || str_eq(op, "sub") == 1
      emit_sub_reg_reg(buf, 0, 1)
    @elif str_eq(op, "MUL") == 1 || str_eq(op, "mul") == 1
      emit_imul_reg_reg(buf, 0, 1)
    @elif str_eq(op, "SDIV") == 1 || str_eq(op, "div") == 1
      emit_cqo(buf)
      emit_idiv_reg(buf, 1) @! RAX = RAX / RCX
    @elif str_eq(op, "SREM") == 1 || str_eq(op, "mod") == 1
      emit_cqo(buf)
      emit_idiv_reg(buf, 1) @! RDX = RAX % RCX
      emit_mov_reg_reg(buf, 0, 2) @! MOV RAX, RDX
    @elif str_eq(op, "AND") == 1 || str_eq(op, "and") == 1
      emit_and_reg_reg(buf, 0, 1)
    @elif str_eq(op, "OR") == 1 || str_eq(op, "or") == 1
      emit_or_reg_reg(buf, 0, 1)
    @elif str_eq(op, "XOR") == 1 || str_eq(op, "xor") == 1
      emit_xor_reg_reg(buf, 0, 1)
    @elif str_eq(op, "SHL") == 1 || str_eq(op, "shl") == 1
      emit_shl_reg_cl(buf, 0)
    @elif str_eq(op, "SHR") == 1 || str_eq(op, "shr") == 1
      emit_sar_reg_cl(buf, 0)
    @end

    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 6. UNARY (NEG, NOT)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "NEG") == 1 || str_eq(op, "neg") == 1
    operand = inst.left
    @if operand == 0 && inst.args.len() > 0 operand = inst.args[0] @end
    x86_lower_load_val_to_reg(emitter, operand, 0)
    emit_neg_reg(buf, 0)
    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @if str_eq(op, "NOT") == 1 || str_eq(op, "not") == 1
    operand = inst.left
    @if operand == 0 && inst.args.len() > 0 operand = inst.args[0] @end
    x86_lower_load_val_to_reg(emitter, operand, 0)
    emit_not_reg(buf, 0)
    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 7. CMP (Comparison Operations)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "CMP") == 1 || str_eq(op, "cmp") == 1
    lhs_val = inst.left
    rhs_val = inst.right
    @if inst.args.len() >= 2
      lhs_val = inst.args[0]
      rhs_val = inst.args[1]
    @end
    x86_lower_load_val_to_reg(emitter, lhs_val, 0) @! LHS into RAX
    x86_lower_load_val_to_reg(emitter, rhs_val, 1) @! RHS into RCX
    emit_cmp_reg_reg(buf, 0, 1)                    @! CMP RAX, RCX

    cmp_c = inst.cmp_op
    @if cmp_c == "" cmp_c = "eq" @end
    emit_setcc_reg8(buf, cmp_c, 0)                 @! SETcc AL
    emit_movzx_reg64_reg8(buf, 0, 0)               @! MOVZX RAX, AL
    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 8. BR (Unconditional Branch)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "BR") == 1 || str_eq(op, "br") == 1
    fixup_off = buf.bytes.len() + 1 @! After 0xE9 opcode byte
    emit_jmp_rel32(buf, 0)          @! Placeholder
    emitter.fixups = emitter.fixups.push({
      kind: "jmp",
      cond_code: "",
      fixup_offset: fixup_off,
      target_id: inst.target,
      target_name: inst.target_label
    })
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 9. BR_COND (Conditional Branch)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "BR_COND") == 1 || str_eq(op, "br_cond") == 1
    cond_v = inst.cond
    @if cond_v == 0 && inst.args.len() > 0 cond_v = inst.args[0] @end
    x86_lower_load_val_to_reg(emitter, cond_v, 0) @! Condition into RAX
    emit_test_reg_reg(buf, 0, 0)                  @! TEST RAX, RAX

    @! Branch to TRUE block on non-zero (JNE rel32)
    jne_fixup_off = buf.bytes.len() + 2           @! After 0x0F 0x85 opcode bytes
    emit_jcc_rel32(buf, "jne", 0)                 @! Placeholder
    emitter.fixups = emitter.fixups.push({
      kind: "jcc",
      cond_code: "jne",
      fixup_offset: jne_fixup_off,
      target_id: inst.true_target,
      target_name: inst.then_label
    })

    @! Branch to FALSE block (JMP rel32)
    jmp_fixup_off = buf.bytes.len() + 1           @! After 0xE9 opcode byte
    emit_jmp_rel32(buf, 0)                        @! Placeholder
    emitter.fixups = emitter.fixups.push({
      kind: "jmp",
      cond_code: "",
      fixup_offset: jmp_fixup_off,
      target_id: inst.false_target,
      target_name: inst.else_label
    })
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 10. RET (Function Return)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "RET") == 1 || str_eq(op, "ret") == 1
    ret_v = inst.inst_val
    @if ret_v == 0 && inst.args.len() > 0 ret_v = inst.args[0] @end
    @if ret_v != 0
      x86_lower_load_val_to_reg(emitter, ret_v, 0) @! Return value into RAX
    @else
      emit_xor_reg_reg(buf, 0, 0)                  @! XOR RAX, RAX
    @end
    emit_frame_epilogue(buf, emitter.frame)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 11. CALL (Function Invocation)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "CALL") == 1 || str_eq(op, "call") == 1


    @if str_eq(inst.callee, "maya_array_new") == 1
      @! Call universe/core/gc.maya -> gc_alloc
      x86_lower_load_val_to_reg(emitter, inst.args[0], 0) @! RAX = num_items
      emit_mov_reg_imm64(buf, 1, 8)
      emit_imul_reg_reg(buf, 0, 1)                  @! RAX = num_items * 8
      emit_add_reg_imm32(buf, 0, 16)               @! RAX = num_items * 8 + 16 (Header is 16 bytes: cap, len)
      
      @! Move size to RDI (Arg 1)
      emit_mov_reg_reg(buf, 7, 0)
      
      @! Emit CALL gc_alloc
      fixup_off = buf.bytes.len() + 1
      emit_call_rel32(buf, 0)
      emitter.fn_fixups = emitter.fn_fixups.push({
        kind: "call",
        cond_code: "",
        fixup_offset: fixup_off,
        target_id: -1,
        target_name: "maya_gc_alloc"
      })
      
      @! Now RAX has the allocated pointer from gc_alloc.
      @! Initialize MayaArray header: capacity, length
      x86_lower_load_val_to_reg(emitter, inst.args[0], 1) @! RCX = num_items
      
      @! capacity = num_items (offset 0)
      emit_mov_mem_reg(buf, 0, 0, 1)
      
      @! length = num_items (offset 8)
      emit_mov_mem_reg(buf, 0, 8, 1)
      
      @! Return data ptr = RAX + 16
      emit_add_reg_imm32(buf, 0, 16)
      
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end


    @if str_eq(inst.callee, "sys_peek") == 1
      x86_lower_load_val_to_reg(emitter, inst.args[0], 0) @! RAX = addr
      emit_mov_reg_mem(buf, 0, 0, 0)                      @! RAX = [RAX]
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end

    @if str_eq(inst.callee, "sys_peek8") == 1
      x86_lower_load_val_to_reg(emitter, inst.args[0], 0) @! RAX = addr
      bytebuf_push(buf, 15) bytebuf_push(buf, 182) bytebuf_push(buf, 0) @! movzx eax, byte [rax]
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end

    @if str_eq(inst.callee, "sys_poke") == 1
      x86_lower_load_val_to_reg(emitter, inst.args[0], 0) @! RAX = addr
      x86_lower_load_val_to_reg(emitter, inst.args[1], 1) @! RCX = val
      emit_mov_mem_reg(buf, 0, 0, 1)                      @! [RAX] = RCX
      return emitter
    @end

    @if str_eq(inst.callee, "sys_poke8") == 1
      x86_lower_load_val_to_reg(emitter, inst.args[0], 0) @! RAX = addr
      x86_lower_load_val_to_reg(emitter, inst.args[1], 1) @! RCX = val
      @! WHY: 0x88 0x08 is MOV byte [RAX], CL (Mod=00, Reg=001 (CL), R/M=000 (RAX)).
      @! 0x09 was mistakenly encoding R/M=001 (RCX), which caused a segfault when RCX was 0.
      bytebuf_push(buf, 136) bytebuf_push(buf, 8)               @! mov byte [rax], cl
      return emitter
    @end


    @if str_eq(inst.callee, "sys_syscall") == 1
      @! Load syscall nr and args into Linux syscall registers
      @! inst.args[0] -> RAX (nr)
      @! inst.args[1] -> RDI (arg1)
      @! inst.args[2] -> RSI (arg2)
      @! inst.args[3] -> RDX (arg3)
      @! inst.args[4] -> R10 (arg4)
      @! inst.args[5] -> R8  (arg5)
      @! inst.args[6] -> R9  (arg6)
      
      args_cnt = inst.args.len()
      @if args_cnt > 0
        x86_lower_load_val_to_reg(emitter, inst.args[0], 0) @! RAX
      @end
      @if args_cnt > 1
        x86_lower_load_val_to_reg(emitter, inst.args[1], 7) @! RDI
      @end
      @if args_cnt > 2
        x86_lower_load_val_to_reg(emitter, inst.args[2], 6) @! RSI
      @end
      @if args_cnt > 3
        x86_lower_load_val_to_reg(emitter, inst.args[3], 2) @! RDX
      @end
      @if args_cnt > 4
        x86_lower_load_val_to_reg(emitter, inst.args[4], 10) @! R10
      @end
      @if args_cnt > 5
        x86_lower_load_val_to_reg(emitter, inst.args[5], 8) @! R8
      @end
      @if args_cnt > 6
        x86_lower_load_val_to_reg(emitter, inst.args[6], 9) @! R9
      @end
      
      emit_syscall(buf)
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end

    @! WHY: Direct Linux SYS_mmap (Syscall 9) lowering.
    @! Ensures any call to sys_mmap(addr, length, prot, flags, fd, offset) anywhere
    @! in the universe or user code executes direct kernel syscalls without symbol resolution or missing imports.
    @if str_eq(inst.callee, "sys_mmap") == 1
      args_cnt = inst.args.len()
      @if args_cnt > 0
        x86_lower_load_val_to_reg(emitter, inst.args[0], 7) @! RDI = addr
      @else
        emit_xor_reg_reg(buf, 7, 7)
      @end
      @if args_cnt > 1
        x86_lower_load_val_to_reg(emitter, inst.args[1], 6) @! RSI = length
      @else
        emit_xor_reg_reg(buf, 6, 6)
      @end
      @if args_cnt > 2
        x86_lower_load_val_to_reg(emitter, inst.args[2], 2) @! RDX = prot
      @else
        emit_xor_reg_reg(buf, 2, 2)
      @end
      @if args_cnt > 3
        x86_lower_load_val_to_reg(emitter, inst.args[3], 10) @! R10 = flags
      @else
        emit_xor_reg_reg(buf, 10, 10)
      @end
      @if args_cnt > 4
        x86_lower_load_val_to_reg(emitter, inst.args[4], 8) @! R8 = fd
      @else
        emit_xor_reg_reg(buf, 8, 8)
      @end
      @if args_cnt > 5
        x86_lower_load_val_to_reg(emitter, inst.args[5], 9) @! R9 = offset
      @else
        emit_xor_reg_reg(buf, 9, 9)
      @end
      emit_mov_reg_imm64(buf, 0, 9) @! RAX = 9 (SYS_MMAP)
      emit_syscall(buf)
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end

    @! WHY: Direct Linux SYS_exit (Syscall 60) lowering.
    @if str_eq(inst.callee, "sys_exit") == 1
      @if inst.args.len() > 0
        x86_lower_load_val_to_reg(emitter, inst.args[0], 7) @! RDI = exit code
      @else
        emit_xor_reg_reg(buf, 7, 7)
      @end
      emit_mov_reg_imm64(buf, 0, 60) @! RAX = 60 (SYS_EXIT)
      emit_syscall(buf)
      return emitter
    @end

    @if str_eq(inst.callee, "HACKED_ARGC") == 1 || str_eq(inst.callee, "maya_process_argc") == 1 || str_eq(inst.callee, "sys_argc") == 1
      @! Load argc from [4194472] into RAX
      emit_mov_reg_imm64(buf, 0, 4194472)
      emit_mov_reg_mem(buf, 0, 0, 0)
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end

    @if str_eq(inst.callee, "process_argv") == 1 || str_eq(inst.callee, "maya_process_argv") == 1 || str_eq(inst.callee, "sys_argv") == 1
      @! Load index into RAX
      x86_lower_load_val_to_reg(emitter, inst.args[0], 0)
      @! Load argv pointer from [4194480] into RCX
      emit_mov_reg_imm64(buf, 1, 4194480)
      emit_mov_reg_mem(buf, 1, 1, 0)
      @! RCX = argv pointer, RAX = index * 8
      emit_mov_reg_imm64(buf, 2, 8)
      emit_imul_reg_reg(buf, 0, 2)
      emit_add_reg_reg(buf, 1, 0)
      @! RAX = cstr_ptr = [RCX]
      emit_mov_reg_mem(buf, 0, 1, 0)
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
      return emitter
    @end

    args_cnt = inst.args.len()
    reg_args = 6
    @if args_cnt < 6 reg_args = args_cnt @end

    @! Load first 6 arguments into System V ABI registers
    a_i = 0
    @while a_i < reg_args
      arg_r = abi_sysv_arg_reg(a_i)
      x86_lower_load_val_to_reg(emitter, inst.args[a_i], arg_r)
      a_i = a_i + 1
    @end

    @! Push any stack arguments (>6) in reverse order
    stack_args_cnt = 0
    @if args_cnt > 6
      stk_i = args_cnt - 1
      @while stk_i >= 6
        x86_lower_load_val_to_reg(emitter, inst.args[stk_i], 0)
        emit_push_reg(buf, 0)
        stack_args_cnt = stack_args_cnt + 1
        stk_i = stk_i - 1
      @end
    @end

    @! Emit CALL rel32
    fixup_off = buf.bytes.len() + 1 @! After 0xE8 opcode byte
    emit_call_rel32(buf, 0)         @! Placeholder
    emitter.fn_fixups = emitter.fn_fixups.push({
      kind: "call",
      cond_code: "",
      fixup_offset: fixup_off,
      target_id: -1,
      target_name: inst.callee
    })

    @! Clean up outgoing stack arguments if any
    @if stack_args_cnt > 0
      emit_add_reg_imm32(buf, 4, stack_args_cnt * 8) @! ADD RSP, 8*N
    @end

    @! Store return value from RAX into destination variable
    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 12. SYSCALL (Direct Linux Kernel Syscall)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "SYSCALL") == 1 || str_eq(op, "syscall") == 1
    @! Load Syscall Number into RAX
    emit_mov_reg_imm64(buf, 0, inst.nr)

    @! Load up to 6 arguments into Syscall registers [RDI, RSI, RDX, R10, R8, R9]
    sys_argc = inst.args.len()
    @if sys_argc > 6 sys_argc = 6 @end
    s_i = 0
    @while s_i < sys_argc
      s_reg = abi_syscall_arg_reg(s_i)
      x86_lower_load_val_to_reg(emitter, inst.args[s_i], s_reg)
      s_i = s_i + 1
    @end

    @! Emit direct SYSCALL opcode (0x0F, 0x05)
    emit_syscall(buf)

    @! Result returned in RAX -> store to dest
    x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    return emitter
  @end

  @! --------------------------------------------------------------------------
  @! 13. PHI (Merged Variable Binding)
  @! --------------------------------------------------------------------------
  @if str_eq(op, "PHI") == 1 || str_eq(op, "phi") == 1
    @! For PHI nodes, if incoming pairs exist, copy first defined value to destination
    @if inst.incoming.len() > 0
      first_pair = inst.incoming[0]
      x86_lower_load_val_to_reg(emitter, first_pair.phi_val, 0)
      x86_lower_store_reg_to_dest(emitter, 0, inst.dest)
    @end
    return emitter
  @end

  return emitter
@end

@! ============================================================================
@! 7. FUNCTION CODEGEN & 2-PASS BRANCH RESOLUTION
@! ============================================================================

@fn codegen_get_char(s, k)
  return str_char_at(s, k)
@end

@fn codegen_str_eq(s1, s2)
  @if s1 == s2
    return 1
  @end
  @if s1 == "" || s2 == ""
    return 0
  @end
  i = 0
  @while 1
    c1 = codegen_get_char(s1, i)
    c2 = codegen_get_char(s2, i)
    @if c1 != c2
      return 0
    @end
    @if c1 == 0
      return 1
    @end
    i = i + 1
  @end
  return 1
@end

@fn x86_codegen_function(func)
  @! 1. Calculate number of slots needed (params, locals, vregs)
  num_params = func.params.len()
  num_locals = func.locals.len()
  num_vregs  = func.next_vreg_id
  @if str_ends_with(func.name, "parser_parse_statement")
    println(string_concat(string_concat("vregs for ", func.name), string_concat(": ", num_vregs.to_str())))
  @end
  @if num_vregs < 16 num_vregs = 16 @end

  total_vars = num_params + num_locals + num_vregs + 64
  frame = stack_frame_build(func.name, total_vars, 0, [], 0)
  emitter = x86_emitter_new(frame)

  @! 2. Populate Slot Map
  cur_off = -8

  @! Parameters mapping
  p_idx = 0
  @while p_idx < num_params
    p = func.params[p_idx]
    p_name = p.p_name
    @if str_len(p_name) == 0 p_name = string_concat("arg", int_to_str(p_idx)) @end
    emitter.slot_map = slot_map_set(emitter.slot_map, p_name, cur_off)
    emitter.slot_map = slot_map_set(emitter.slot_map, string_concat("%", p_name), cur_off)
    emitter.slot_map = slot_map_set(emitter.slot_map, string_concat("%param_", p_name), cur_off)
    emitter.slot_map = slot_map_set(emitter.slot_map, string_concat("%param_", int_to_str(p_idx)), cur_off)
    emitter.alloca_set = emitter.alloca_set.push(p_name)
    emitter.alloca_set = emitter.alloca_set.push(string_concat("%", p_name))
    emitter.alloca_set = emitter.alloca_set.push(string_concat("%param_", p_name))
    emitter.alloca_set = emitter.alloca_set.push(string_concat("%param_", int_to_str(p_idx)))
    cur_off = cur_off - 8
    p_idx = p_idx + 1
  @end

  @! Locals mapping
  l_idx = 0
  @while l_idx < num_locals
    loc = func.locals[l_idx]
    emitter.slot_map = slot_map_set(emitter.slot_map, loc.loc_name, cur_off)
    emitter.alloca_set = emitter.alloca_set.push(loc.loc_name)
    @if loc.loc_vreg != 0
      @if str_len(loc.loc_vreg.name) > 0
        emitter.slot_map = slot_map_set(emitter.slot_map, loc.loc_vreg.name, cur_off)
        emitter.alloca_set = emitter.alloca_set.push(loc.loc_vreg.name)
      @end
    @end
    cur_off = cur_off - 8
    l_idx = l_idx + 1
  @end

  @! Scan blocks for ALLOCA instructions to ensure 100% alloca coverage
  b_i = 0
  @while b_i < func.blocks.len()
    bb = func.blocks[b_i]
    ins_i = 0
    @while ins_i < bb.instructions.len()
      in_cur = bb.instructions[ins_i]
      in_op = in_cur.op
      @if str_len(in_op) == 0 in_op = in_cur.inst_op @end
      @if str_eq(in_op, "ALLOCA") == 1 || str_eq(in_op, "alloca") == 1
        @if str_len(in_cur.dest) > 0
          emitter.alloca_set = emitter.alloca_set.push(in_cur.dest)
        @end
      @end
      ins_i = ins_i + 1
    @end
    b_i = b_i + 1
  @end

  @! Virtual registers mapping
  v_idx = 0
  @while v_idx < num_vregs
    v_name = string_concat("%v", int_to_str(v_idx))
    @if slot_map_get(emitter.slot_map, v_name, 0) == 0
      emitter.slot_map = slot_map_set(emitter.slot_map, v_name, cur_off)
      emitter.slot_map = slot_map_set(emitter.slot_map, string_concat("%v_", int_to_str(v_idx)), cur_off)
      emitter.slot_map = slot_map_set(emitter.slot_map, string_concat("%tmp_", int_to_str(v_idx)), cur_off)
      cur_off = cur_off - 8
    @end
    v_idx = v_idx + 1
  @end

  @! 3. Emit Function Prologue
  emit_frame_prologue(emitter.buf, emitter.frame)

  @! 4. Store incoming System V argument registers and stack arguments to stack slots
  p_s_i = 0
  @while p_s_i < num_params
    p_off = slot_map_get(emitter.slot_map, string_concat("%param_", int_to_str(p_s_i)), 0)
    @if p_s_i < 6
      arg_reg = abi_sysv_arg_reg(p_s_i)
      @if p_off != 0
        emit_mov_mem_reg(emitter.buf, 5, p_off, arg_reg)
      @end
    @else
      @! Stack argument at [RBP + 16 + (p_s_i - 6)*8]
      stk_arg_disp = 16 + (p_s_i - 6) * 8
      emit_mov_reg_mem(emitter.buf, 0, 5, stk_arg_disp) @! MOV RAX, [RBP + stk_arg_disp]
      @if p_off != 0
        emit_mov_mem_reg(emitter.buf, 5, p_off, 0)        @! MOV [RBP + p_off], RAX
      @end
    @end
    p_s_i = p_s_i + 1
  @end

  @! 5. Pass 1: Linearize Basic Blocks & Lower Instructions
  @! Initialize block offsets map
  max_block_id = 64
_i_blk_0 = 0
@while _i_blk_0 < func.blocks.len()
  blk = func.blocks[_i_blk_0]
    @if blk.id >= max_block_id max_block_id = blk.id + 16 @end
  _i_blk_0 = _i_blk_0 + 1
@end
  b_init = 0
  @while b_init < max_block_id
    emitter.block_offsets = emitter.block_offsets.push(-1)
    b_init = b_init + 1
  @end
_i_blk_0 = 0
@while _i_blk_0 < func.blocks.len()
  blk = func.blocks[_i_blk_0]
    @! Record block starting byte offset
    blk_start_off = emitter.buf.bytes.len()
    emitter.block_offsets = list_set(emitter.block_offsets, blk.id, blk_start_off)

    @! Lower all instructions in block
_i_inst_1 = 0
@while _i_inst_1 < blk.instructions.len()
  inst = blk.instructions[_i_inst_1]
      x86_lower_ir_inst(emitter, inst)
  _i_inst_1 = _i_inst_1 + 1
@end
  _i_blk_0 = _i_blk_0 + 1
@end

_i_fixup_0 = 0
@while _i_fixup_0 < emitter.fixups.len()
  fixup = emitter.fixups[_i_fixup_0]
    target_id = fixup.target_id
    target_off = -1
    @if target_id >= 0 && target_id < emitter.block_offsets.len()
      target_off = emitter.block_offsets[target_id]
    @end
    @if target_off < 0 && fixup.target_name != ""
_i_blk_1 = 0
@while _i_blk_1 < func.blocks.len()
  blk = func.blocks[_i_blk_1]
        @if codegen_str_eq(blk.blk_label, fixup.target_name) == 1 || codegen_str_eq(blk.name, fixup.target_name) == 1
          @if blk.id >= 0 && blk.id < emitter.block_offsets.len()
            target_off = emitter.block_offsets[blk.id]
          @end
        @end
  _i_blk_1 = _i_blk_1 + 1
@end
    @end
    @if target_off >= 0
      next_inst_pc = fixup.fixup_offset + 4
      rel32 = target_off - next_inst_pc
      emitter.buf = bytebuf_patch32(emitter.buf, fixup.fixup_offset, rel32)
    @end
  _i_fixup_0 = _i_fixup_0 + 1
@end

  return emitter
@end

@! ============================================================================
@! 8. MODULE-LEVEL CODE GENERATION (x86_codegen_module)
@! ============================================================================

@struct X86ModuleResult
  text_bytes: array
  rodata_bytes: array
  symbol_offsets: array
  symbols: array
  entry_offset: i64
@end

@fn x86_codegen_module(ir_mod)
  text_buf = bytebuf_new()
  rodata_buf = bytebuf_new()
  symbols = []
  symbol_offsets = []
  fn_offsets_map = []
  rodata_offsets_map = []
  all_fn_fixups = []
  all_rodata_fixups = []
  entry_off = 0

  @! --------------------------------------------------------------------------
  @! 1. Serialize Read-Only Data (.rodata)
  @! --------------------------------------------------------------------------
  @if ir_mod.string_literals != 0
_i_str_entry_0 = 0
@while _i_str_entry_0 < ir_mod.string_literals.len()
  str_entry = ir_mod.string_literals[_i_str_entry_0]
      str_off = rodata_buf.bytes.len()
      rodata_offsets_map = rodata_offsets_map.push({
        ro_lbl: str_entry.label,
        ro_byte_off: str_off
      })
      symbols = symbols.push({
        name: str_entry.label,
        offset: str_off,
        size: str_entry.str_val.len() + 1,
        section: ".rodata"
      })
      @! Write ASCII string bytes
      s = str_entry.str_val
      s_len = str_len(s)
      s_i = 0
      @while s_i < s_len
        sc = str_char_at(s, s_i)
        bytebuf_push(rodata_buf, sc)
        s_i = s_i + 1
      @end
      @! Null terminator
      bytebuf_push(rodata_buf, 0)
  _i_str_entry_0 = _i_str_entry_0 + 1
@end
  @end

  @! --------------------------------------------------------------------------
  @! 2. Emit Functions to Machine Code (.text)
  @! --------------------------------------------------------------------------
_i_func_0 = 0
@while _i_func_0 < ir_mod.functions.len()
  func = ir_mod.functions[_i_func_0]
    @! 16-byte align function entry with NOPs (0x90)
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end

    fn_start = text_buf.bytes.len()
    @if str_eq(func.name, "main") == 1
      entry_off = fn_start
    @end

    fn_offsets_map = fn_offsets_map.push({
      fn_sym: func.name,
      fn_byte_off: fn_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: func.name, sym_offset: fn_start })

    @! Compile function
    fn_emitter = x86_codegen_function(func)
    fn_bytes = fn_emitter.buf.bytes

    @! Collect inter-function call fixups with adjusted offsets
_i_c_fix_1 = 0
@while _i_c_fix_1 < fn_emitter.fn_fixups.len()
  c_fix = fn_emitter.fn_fixups[_i_c_fix_1]
      all_fn_fixups = all_fn_fixups.push({
        kind: c_fix.kind,
        cond_code: c_fix.cond_code,
        fixup_offset: fn_start + c_fix.fixup_offset,
        target_id: c_fix.target_id,
        target_name: c_fix.target_name
      })
  _i_c_fix_1 = _i_c_fix_1 + 1
@end

    @! Collect rodata fixups with adjusted offsets
_i_r_fix_1 = 0
@while _i_r_fix_1 < fn_emitter.rodata_fixups.len()
  r_fix = fn_emitter.rodata_fixups[_i_r_fix_1]
      all_rodata_fixups = all_rodata_fixups.push({
        kind: r_fix.kind,
        cond_code: r_fix.cond_code,
        fixup_offset: fn_start + r_fix.fixup_offset,
        target_id: r_fix.target_id,
        target_name: r_fix.target_name
      })
  _i_r_fix_1 = _i_r_fix_1 + 1
@end

    @! Append function bytes to module text buffer
    bytebuf_push_bytes(text_buf, fn_bytes)

    symbols = symbols.push({
      name: func.name,
      offset: fn_start,
      size: fn_bytes.len(),
      section: ".text"
    })
  _i_func_0 = _i_func_0 + 1
@end

  @! --------------------------------------------------------------------------
  @! 2.5. Emit Maya Builtin Runtime Helpers (maya_print_str, maya_print_int, maya_print)
  @! --------------------------------------------------------------------------
  has_maya_print_str = 0
  has_maya_print_int = 0
  has_maya_print = 0
_i_func_0 = 0
@while _i_func_0 < ir_mod.functions.len()
  func = ir_mod.functions[_i_func_0]
    @if str_eq(func.name, "maya_print_str") == 1
      has_maya_print_str = 1
    @end
    @if str_eq(func.name, "maya_print_int") == 1
      has_maya_print_int = 1
    @end
    @if str_eq(func.name, "maya_print") == 1
      has_maya_print = 1
    @end
  _i_func_0 = _i_func_0 + 1
@end

  mps_start = -1
  @if has_maya_print_str == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end

    mps_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "maya_print_str",
      fn_byte_off: mps_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_print_str", sym_offset: mps_start })

    mps_bytes = [85, 72, 137, 229, 72, 131, 236, 32, 72, 133, 255, 116, 34, 72, 137, 254, 72, 49, 210, 128, 60, 22, 0, 116, 5, 72, 255, 194, 235, 245, 72, 133, 210, 116, 12, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 49, 192, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, mps_bytes)

    symbols = symbols.push({
      name: "maya_print_str",
      offset: mps_start,
      size: mps_bytes.len(),
      section: ".text"
    })
  @end

  mpi_start = -1
  @if has_maya_print_int == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end

    mpi_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "maya_print_int",
      fn_byte_off: mpi_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_print_int", sym_offset: mpi_start })

    mpi_bytes = [85, 72, 137, 229, 72, 131, 236, 64, 72, 137, 248, 72, 141, 117, 255, 198, 6, 0, 72, 49, 201, 72, 133, 192, 121, 8, 72, 247, 216, 185, 1, 0, 0, 0, 65, 184, 10, 0, 0, 0, 72, 255, 206, 72, 49, 210, 73, 247, 240, 128, 194, 48, 136, 22, 72, 133, 192, 117, 237, 72, 133, 201, 116, 6, 72, 255, 206, 198, 6, 45, 72, 141, 85, 255, 72, 41, 242, 191, 1, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 72, 49, 192, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, mpi_bytes)

    symbols = symbols.push({
      name: "maya_print_int",
      offset: mpi_start,
      size: mpi_bytes.len(),
      section: ".text"
    })
  @end

  @if has_maya_print == 0
    mp_target_off = mpi_start
    @if mp_target_off < 0
      mp_target_off = mps_start
    @end
    @if mp_target_off >= 0
      fn_offsets_map = fn_offsets_map.push({
        fn_sym: "maya_print",
        fn_byte_off: mp_target_off
      })
      symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_print", sym_offset: mp_target_off })
    @end
  @end

  @! --------------------------------------------------------------------------
  @! 2.6. Emit Maya Builtin Math Helpers (math_sqrt, math_abs, math_max, math_min, math_clamp, math_pow)
  @! --------------------------------------------------------------------------
  has_math_sqrt = 0
  has_math_abs = 0
  has_math_max = 0
  has_math_min = 0
  has_math_clamp = 0
  has_math_pow = 0
_i_func_0 = 0
@while _i_func_0 < ir_mod.functions.len()
  func = ir_mod.functions[_i_func_0]
    @if str_eq(func.name, "math_sqrt") == 1 has_math_sqrt = 1 @end
    @if str_eq(func.name, "math_abs") == 1 has_math_abs = 1 @end
    @if str_eq(func.name, "math_max") == 1 has_math_max = 1 @end
    @if str_eq(func.name, "math_min") == 1 has_math_min = 1 @end
    @if str_eq(func.name, "math_clamp") == 1 has_math_clamp = 1 @end
    @if str_eq(func.name, "math_pow") == 1 has_math_pow = 1 @end
  _i_func_0 = _i_func_0 + 1
@end

  @if has_math_sqrt == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    m_sqrt_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "math_sqrt",
      fn_byte_off: m_sqrt_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "math_sqrt", sym_offset: m_sqrt_start })
    m_sqrt_bytes = [242, 72, 15, 42, 199, 242, 15, 81, 192, 242, 72, 15, 44, 192, 195]
    bytebuf_push_bytes(text_buf, m_sqrt_bytes)
    symbols = symbols.push({
      name: "math_sqrt",
      offset: m_sqrt_start,
      size: m_sqrt_bytes.len(),
      section: ".text"
    })
  @end

  @if has_math_abs == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    m_abs_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "math_abs",
      fn_byte_off: m_abs_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "math_abs", sym_offset: m_abs_start })
    m_abs_bytes = [72, 137, 248, 72, 133, 192, 121, 3, 72, 247, 216, 195]
    bytebuf_push_bytes(text_buf, m_abs_bytes)
    symbols = symbols.push({
      name: "math_abs",
      offset: m_abs_start,
      size: m_abs_bytes.len(),
      section: ".text"
    })
  @end

  @if has_math_max == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    m_max_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "math_max",
      fn_byte_off: m_max_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "math_max", sym_offset: m_max_start })
    m_max_bytes = [72, 137, 248, 72, 57, 240, 72, 15, 76, 198, 195]
    bytebuf_push_bytes(text_buf, m_max_bytes)
    symbols = symbols.push({
      name: "math_max",
      offset: m_max_start,
      size: m_max_bytes.len(),
      section: ".text"
    })
  @end

  @if has_math_min == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    m_min_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "math_min",
      fn_byte_off: m_min_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "math_min", sym_offset: m_min_start })
    m_min_bytes = [72, 137, 248, 72, 57, 240, 72, 15, 79, 198, 195]
    bytebuf_push_bytes(text_buf, m_min_bytes)
    symbols = symbols.push({
      name: "math_min",
      offset: m_min_start,
      size: m_min_bytes.len(),
      section: ".text"
    })
  @end

  @if has_math_clamp == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    m_clamp_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "math_clamp",
      fn_byte_off: m_clamp_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "math_clamp", sym_offset: m_clamp_start })
    m_clamp_bytes = [72, 137, 248, 72, 57, 240, 72, 15, 76, 198, 72, 57, 208, 72, 15, 79, 194, 195]
    bytebuf_push_bytes(text_buf, m_clamp_bytes)
    symbols = symbols.push({
      name: "math_clamp",
      offset: m_clamp_start,
      size: m_clamp_bytes.len(),
      section: ".text"
    })
  @end

  @if has_math_pow == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    m_pow_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "math_pow",
      fn_byte_off: m_pow_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "math_pow", sym_offset: m_pow_start })
    m_pow_bytes = [72, 199, 192, 1, 0, 0, 0, 72, 137, 241, 72, 133, 201, 126, 7, 72, 15, 175, 199, 72, 255, 201, 235, 240, 195]
    bytebuf_push_bytes(text_buf, m_pow_bytes)
    symbols = symbols.push({
      name: "math_pow",
      offset: m_pow_start,
      size: m_pow_bytes.len(),
      section: ".text"
    })
  @end

  @! --------------------------------------------------------------------------
  @! 2.7. Emit Embedded Runtime Builtins (if unlinked)
  @! --------------------------------------------------------------------------
  has_str_char_at = 0
  has_str_len = 0
  has_str_from_char_code = 0
  has_maya_int_to_str = 0
  has_maya_str_concat = 0
  has_maya_str_eq = 0
  has_maya_str_substr = 0
  has_gc_alloc = 0
_i_func_0 = 0
@while _i_func_0 < ir_mod.functions.len()
  func = ir_mod.functions[_i_func_0]
    @if str_eq(func.name, "str_char_at") == 1 || str_eq(func.name, "maya_str_char_at") == 1 has_str_char_at = 1 @end
    @if str_eq(func.name, "str_len") == 1 || str_eq(func.name, "maya_str_len") == 1 || str_eq(func.name, "string_length") == 1 has_str_len = 1 @end
    @if str_eq(func.name, "str_from_char_code") == 1 || str_eq(func.name, "maya_str_from_char_code") == 1 || str_eq(func.name, "string_from_char_code") == 1 || str_eq(func.name, "from_char") == 1 has_str_from_char_code = 1 @end
    @if str_eq(func.name, "maya_int_to_str") == 1 || str_eq(func.name, "int_to_str") == 1 || str_eq(func.name, "to_str") == 1 || str_eq(func.name, "to_string") == 1 || str_eq(func.name, "int_to_string") == 1 has_maya_int_to_str = 1 @end
    @if str_eq(func.name, "maya_str_concat") == 1 || str_eq(func.name, "str_concat") == 1 || str_eq(func.name, "maya_string_concat") == 1 || str_eq(func.name, "string_concat") == 1 has_maya_str_concat = 1 @end
    @if str_eq(func.name, "maya_str_eq") == 1 || str_eq(func.name, "str_eq") == 1 || str_eq(func.name, "compiler_str_eq") == 1 || str_eq(func.name, "infinity_str_eq") == 1 has_maya_str_eq = 1 @end
    @if str_eq(func.name, "maya_str_substr") == 1 || str_eq(func.name, "str_substr") == 1 || str_eq(func.name, "string_slice") == 1 has_maya_str_substr = 1 @end
    @if str_eq(func.name, "maya_gc_alloc") == 1 || str_eq(func.name, "gc_alloc") == 1 || str_eq(func.name, "maya_alloc") == 1 has_gc_alloc = 1 @end
  _i_func_0 = _i_func_0 + 1
@end

  @if has_str_char_at == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    sca_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "str_char_at", fn_byte_off: sca_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_str_char_at", fn_byte_off: sca_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "str_char_at", sym_offset: sca_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_str_char_at", sym_offset: sca_start })
    sca_bytes = [85, 72, 137, 229, 72, 133, 255, 116, 42, 72, 131, 254, 0, 124, 36, 235, 24, 144, 144, 72, 57, 71, 8, 117, 16, 72, 59, 55, 125, 21, 72, 15, 182, 68, 55, 16, 72, 137, 236, 93, 195, 72, 15, 182, 4, 55, 72, 137, 236, 93, 195, 72, 49, 192, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, sca_bytes)
    symbols = symbols.push({ name: "str_char_at", offset: sca_start, size: sca_bytes.len(), section: ".text" })
  @end

  @if has_str_len == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    slen_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "str_len", fn_byte_off: slen_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_str_len", fn_byte_off: slen_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "string_length", fn_byte_off: slen_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "str_len", sym_offset: slen_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_str_len", sym_offset: slen_start })
    slen_bytes = [85, 72, 137, 229, 72, 133, 255, 116, 40, 235, 16, 144, 144, 72, 57, 71, 8, 117, 8, 72, 139, 7, 72, 137, 236, 93, 195, 72, 49, 201, 128, 60, 15, 0, 116, 5, 72, 255, 193, 235, 245, 72, 137, 200, 72, 137, 236, 93, 195, 72, 49, 192, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, slen_bytes)
    symbols = symbols.push({ name: "str_len", offset: slen_start, size: slen_bytes.len(), section: ".text" })
  @end

  @if has_str_from_char_code == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    sfc_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "str_from_char_code", fn_byte_off: sfc_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_str_from_char_code", fn_byte_off: sfc_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "string_from_char_code", fn_byte_off: sfc_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "from_char", fn_byte_off: sfc_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "str_from_char_code", sym_offset: sfc_start })
    sfc_bytes = [85, 72, 137, 229, 83, 72, 131, 236, 8, 72, 137, 251, 72, 199, 199, 16, 0, 0, 0, 232, 0, 0, 0, 0, 136, 24, 198, 64, 1, 0, 72, 131, 196, 8, 91, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, sfc_bytes)
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: sfc_start + 20, target_id: -1, target_name: "maya_gc_alloc" })
    symbols = symbols.push({ name: "str_from_char_code", offset: sfc_start, size: sfc_bytes.len(), section: ".text" })
  @end

  @if has_maya_int_to_str == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    its_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_int_to_str", fn_byte_off: its_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "int_to_str", fn_byte_off: its_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "int_to_string", fn_byte_off: its_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "to_str", fn_byte_off: its_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "to_string", fn_byte_off: its_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_int_to_str", sym_offset: its_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "int_to_str", sym_offset: its_start })
    its_bytes = [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 72, 131, 236, 40, 73, 137, 252, 72, 199, 199, 32, 0, 0, 0, 232, 0, 0, 0, 0, 72, 137, 195, 72, 141, 117, 255, 198, 6, 0, 77, 49, 237, 76, 137, 224, 72, 133, 192, 121, 10, 72, 247, 216, 73, 199, 197, 1, 0, 0, 0, 73, 199, 198, 10, 0, 0, 0, 72, 255, 206, 72, 49, 210, 73, 247, 246, 128, 194, 48, 136, 22, 72, 133, 192, 117, 237, 77, 133, 237, 116, 6, 72, 255, 206, 198, 6, 45, 72, 137, 223, 138, 6, 136, 7, 132, 192, 116, 8, 72, 255, 198, 72, 255, 199, 235, 240, 72, 137, 216, 72, 131, 196, 40, 65, 94, 65, 93, 65, 92, 91, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, its_bytes)
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: its_start + 26, target_id: -1, target_name: "maya_gc_alloc" })
    symbols = symbols.push({ name: "maya_int_to_str", offset: its_start, size: its_bytes.len(), section: ".text" })
  @end

  @if has_maya_str_concat == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    cat_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_str_concat", fn_byte_off: cat_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "str_concat", fn_byte_off: cat_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_string_concat", fn_byte_off: cat_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "string_concat", fn_byte_off: cat_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_str_concat", sym_offset: cat_start })
    cat_bytes = [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 252, 73, 137, 245, 76, 137, 231, 232, 0, 0, 0, 0, 73, 137, 198, 76, 137, 239, 232, 0, 0, 0, 0, 73, 137, 199, 76, 137, 247, 76, 1, 255, 72, 131, 199, 16, 232, 0, 0, 0, 0, 72, 137, 195, 72, 49, 201, 73, 57, 206, 126, 21, 76, 137, 231, 72, 137, 206, 81, 232, 0, 0, 0, 0, 89, 136, 4, 11, 72, 255, 193, 235, 230, 72, 49, 201, 73, 57, 207, 126, 25, 76, 137, 239, 72, 137, 206, 81, 232, 0, 0, 0, 0, 89, 73, 141, 20, 14, 136, 4, 19, 72, 255, 193, 235, 226, 75, 141, 20, 62, 198, 4, 19, 0, 72, 137, 216, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, cat_bytes)
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: cat_start + 27, target_id: -1, target_name: "str_len" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: cat_start + 38, target_id: -1, target_name: "str_len" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: cat_start + 56, target_id: -1, target_name: "maya_gc_alloc" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: cat_start + 79, target_id: -1, target_name: "str_char_at" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: cat_start + 108, target_id: -1, target_name: "str_char_at" })
    symbols = symbols.push({ name: "maya_str_concat", offset: cat_start, size: cat_bytes.len(), section: ".text" })
  @end

  @if has_maya_str_eq == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    eq_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_str_eq", fn_byte_off: eq_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "str_eq", fn_byte_off: eq_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "compiler_str_eq", fn_byte_off: eq_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "infinity_str_eq", fn_byte_off: eq_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_str_eq", sym_offset: eq_start })
    eq_bytes = [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 72, 131, 236, 8, 73, 137, 252, 73, 137, 245, 77, 57, 229, 116, 50, 77, 133, 228, 116, 54, 77, 133, 237, 116, 49, 77, 49, 246, 76, 137, 231, 76, 137, 246, 232, 0, 0, 0, 0, 136, 195, 76, 137, 239, 76, 137, 246, 232, 0, 0, 0, 0, 56, 216, 117, 18, 132, 192, 116, 5, 73, 255, 198, 235, 219, 72, 199, 192, 1, 0, 0, 0, 235, 3, 72, 49, 192, 72, 131, 196, 8, 65, 94, 65, 93, 65, 92, 91, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, eq_bytes)
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: eq_start + 46, target_id: -1, target_name: "str_char_at" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: eq_start + 59, target_id: -1, target_name: "str_char_at" })
    symbols = symbols.push({ name: "maya_str_eq", offset: eq_start, size: eq_bytes.len(), section: ".text" })
  @end

  @if has_maya_str_substr == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144)
    @end
    sub_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "maya_str_substr", fn_byte_off: sub_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "str_substr", fn_byte_off: sub_start })
    fn_offsets_map = fn_offsets_map.push({ fn_sym: "string_slice", fn_byte_off: sub_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_str_substr", sym_offset: sub_start })
    sub_bytes = [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 252, 73, 137, 245, 73, 137, 214, 77, 133, 228, 116, 77, 73, 131, 253, 0, 125, 3, 77, 49, 237, 77, 137, 247, 77, 41, 239, 73, 131, 255, 0, 126, 56, 76, 137, 255, 72, 131, 199, 16, 232, 0, 0, 0, 0, 72, 137, 195, 72, 49, 201, 73, 57, 207, 126, 23, 76, 137, 231, 73, 141, 116, 13, 0, 81, 232, 0, 0, 0, 0, 89, 136, 4, 11, 72, 255, 193, 235, 228, 66, 198, 4, 59, 0, 72, 137, 216, 235, 15, 72, 199, 199, 16, 0, 0, 0, 232, 0, 0, 0, 0, 198, 0, 0, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 72, 137, 236, 93, 195]
    bytebuf_push_bytes(text_buf, sub_bytes)
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: sub_start + 60, target_id: -1, target_name: "maya_gc_alloc" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: sub_start + 85, target_id: -1, target_name: "str_char_at" })
    all_fn_fixups = all_fn_fixups.push({ kind: "call", cond_code: "", fixup_offset: sub_start + 116, target_id: -1, target_name: "maya_gc_alloc" })
    symbols = symbols.push({ name: "maya_str_substr", offset: sub_start, size: sub_bytes.len(), section: ".text" })
  @end

  @if has_gc_alloc == 0
    @while text_buf.bytes.len() % 16 != 0
      bytebuf_push(text_buf, 144) @! 0x90
    @end
    gc_alloc_start = text_buf.bytes.len()
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "maya_gc_alloc",
      fn_byte_off: gc_alloc_start
    })
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "maya_alloc",
      fn_byte_off: gc_alloc_start
    })
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "gc_alloc",
      fn_byte_off: gc_alloc_start
    })
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "maya_str_new",
      fn_byte_off: gc_alloc_start
    })
    fn_offsets_map = fn_offsets_map.push({
      fn_sym: "maya_string_new",
      fn_byte_off: gc_alloc_start
    })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_gc_alloc", sym_offset: gc_alloc_start })
    symbol_offsets = symbol_offsets.push({ sym_id: 0, name: "maya_alloc", sym_offset: gc_alloc_start })
    @! Standalone Linux x86-64 sys_mmap memory allocator (Syscall 9)
    @! mov rsi, rdi; xor edi, edi; mov edx, 3; mov r10d, 34; mov r8, -1; xor r9d, r9d; mov eax, 9; syscall; ret
    gc_alloc_bytes = [72, 137, 254, 49, 255, 186, 3, 0, 0, 0, 65, 186, 34, 0, 0, 0, 73, 199, 192, 255, 255, 255, 255, 69, 49, 201, 184, 9, 0, 0, 0, 15, 5, 195]
    bytebuf_push_bytes(text_buf, gc_alloc_bytes)
    symbols = symbols.push({
      sym_id: 0,
      name: "maya_gc_alloc",
      offset: gc_alloc_start,
      size: gc_alloc_bytes.len(),
      section: ".text"
    })
  @end

  @! Align text_buf to 16 bytes before calculating rodata fixups
  @while text_buf.bytes.len() % 16 != 0
    bytebuf_push(text_buf, 144) @! 0x90
  @end

  @! --------------------------------------------------------------------------
  @! 3. Resolve Inter-Function Call Fixups
  @! --------------------------------------------------------------------------
_i_call_fix_0 = 0
@while _i_call_fix_0 < all_fn_fixups.len()
  call_fix = all_fn_fixups[_i_call_fix_0]
    callee_name = call_fix.target_name
    callee_off = -1
_i_fn_entry_1 = 0
@while _i_fn_entry_1 < fn_offsets_map.len()
  fn_entry = fn_offsets_map[_i_fn_entry_1]
      @if str_eq(fn_entry.fn_sym, callee_name) == 1 || ((str_eq(callee_name, "maya_gc_alloc") == 1 || str_eq(callee_name, "maya_alloc") == 1 || str_eq(callee_name, "gc_alloc") == 1) && (str_eq(fn_entry.fn_sym, "maya_gc_alloc") == 1 || str_eq(fn_entry.fn_sym, "maya_alloc") == 1 || str_eq(fn_entry.fn_sym, "gc_alloc") == 1))
        callee_off = fn_entry.fn_byte_off
      @end
  _i_fn_entry_1 = _i_fn_entry_1 + 1
@end

    @if callee_off >= 0
      next_pc = call_fix.fixup_offset + 4
      rel32 = callee_off - next_pc
      text_buf = bytebuf_patch32(text_buf, call_fix.fixup_offset, rel32)
    @end
  _i_call_fix_0 = _i_call_fix_0 + 1
@end

  @! --------------------------------------------------------------------------
  @! 4. Resolve Rodata Reference Fixups
  @! --------------------------------------------------------------------------
_i_r_fix_0 = 0
@while _i_r_fix_0 < all_rodata_fixups.len()
  r_fix = all_rodata_fixups[_i_r_fix_0]
    rodata_lbl = r_fix.target_name
    ro_off = -1
_i_ro_entry_1 = 0
@while _i_ro_entry_1 < rodata_offsets_map.len()
  ro_entry = rodata_offsets_map[_i_ro_entry_1]
      @if str_eq(ro_entry.ro_lbl, rodata_lbl) == 1 || str_eq(string_concat("@", ro_entry.ro_lbl), rodata_lbl) == 1 || str_eq(ro_entry.ro_lbl, string_concat("@", rodata_lbl)) == 1
        ro_off = ro_entry.ro_byte_off
      @end
  _i_ro_entry_1 = _i_ro_entry_1 + 1
@end

    @if ro_off >= 0
      @! In standard ELF text/rodata layout, compute relative distance
      next_pc = r_fix.fixup_offset + 4
      rel32 = (text_buf.bytes.len() + ro_off) - next_pc
      text_buf = bytebuf_patch32(text_buf, r_fix.fixup_offset, rel32)
    @end
  _i_r_fix_0 = _i_r_fix_0 + 1
@end

  return {
    text_bytes: text_buf.bytes,
    rodata_bytes: rodata_buf.bytes,
    symbol_offsets: symbol_offsets,
    symbols: symbols,
    entry_offset: entry_off
  }
@end
