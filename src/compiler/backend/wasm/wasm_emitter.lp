@! ============================================================================
@! WebAssembly Binary Encoder (Expanded MVP + 2.0)
@! ============================================================================
import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/x86_64/codegen" @! for bytebuf

@struct WordPack
  w0: 0
  w1: 0
  w2: 0
  w3: 0
  w4: 0
  w5: 0
  w6: 0
  w7: 0
@end

@fn wasm_pack_u64_le(bytes_list, start_idx)
  num_items = bytes_list.len()
  val = 0
  mul = 1
  i = 0
  @while i < 8
    curr_idx = start_idx + i
    b = 0
    @if curr_idx < num_items
      b = bytes_list[curr_idx]
    @end
    val = val + ((b % 256) * mul)
    mul = mul * 256
    i = i + 1
  @end
  return val
@end

@fn wasm_write_bytes_to_fd(fd, byte_list)
  total = byte_list.len()
  offset = 0
  @while offset < total
    rem = total - offset
    chunk_bytes = rem
    @if chunk_bytes > 64
      chunk_bytes = 64
    @end

    wp = {
      w0: wasm_pack_u64_le(byte_list, offset + 0),
      w1: wasm_pack_u64_le(byte_list, offset + 8),
      w2: wasm_pack_u64_le(byte_list, offset + 16),
      w3: wasm_pack_u64_le(byte_list, offset + 24),
      w4: wasm_pack_u64_le(byte_list, offset + 32),
      w5: wasm_pack_u64_le(byte_list, offset + 40),
      w6: wasm_pack_u64_le(byte_list, offset + 48),
      w7: wasm_pack_u64_le(byte_list, offset + 56)
    }

    written = sys_write(fd, wp, chunk_bytes)
    @if written < 0
      return written
    @end
    offset = offset + chunk_bytes
  @end
  return total
@end

@fn wasm_write_file(output_path, byte_list)
  @! O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577, mode 0755 = 493
  fd = sys_open(output_path, 577, 493)
  @if fd < 0
    return fd
  @end

  status = wasm_write_bytes_to_fd(fd, byte_list)
  sys_close(fd)
  sys_chmod(output_path, 493)
  return status
@end

@fn encode_u64_leb128(buf, val)
  v = val
  @while 1
    byte = v & 127
    @if v < 0
      v = (v / 128) & 144115188075855871 @! 0x01FFFFFFFFFFFFFF (57 bits logical shift)
    @else
      v = v / 128
    @end
    @if v == 0
      buf = bytebuf_push(buf, byte)
      return buf
    @else
      buf = bytebuf_push(buf, byte + 128)
    @end
  @end
  return buf
@end

@fn encode_u32_leb128(buf, val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  @while 1
    byte = v & 127
    v = v / 128
    @if v == 0
      buf = bytebuf_push(buf, byte)
      return buf
    @else
      buf = bytebuf_push(buf, byte + 128)
    @end
  @end
  return buf
@end

@fn encode_i64_leb128(buf, val)
  v = val
  @while 1
    byte = v & 127
    v = v / 128
    sign_bit = byte & 64
    @if (v == 0 && sign_bit == 0) || (v == -1 && sign_bit != 0)
      buf = bytebuf_push(buf, byte)
      return buf
    @else
      buf = bytebuf_push(buf, byte + 128)
    @end
  @end
  return buf
@end

@fn encode_i32_leb128(buf, val)
  return encode_i64_leb128(buf, val)
@end

@fn encode_f32(buf, val)
  buf = bytebuf_push32(buf, val)
  return buf
@end

@fn encode_f64(buf, val)
  buf = bytebuf_push64(buf, val)
  return buf
@end

@fn encode_string(buf, str)
  slen = str_len(str)
  buf = encode_u32_leb128(buf, slen)
  i = 0
  @while i < slen
    sc = str_char_at(str, i)
    buf = bytebuf_push(buf, sc)
    i = i + 1
  @end
  return buf
@end

@fn write_type_section(buf, types)
  @if types.len() == 0 return buf @end
  buf = bytebuf_push(buf, 1) @! Section 1
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, types.len())
_i_t_0 = 0
@while _i_t_0 < types.len()
  t = types[_i_t_0]
    sec_buf = bytebuf_push(sec_buf, 96) @! 0x60 func
    sec_buf = encode_u32_leb128(sec_buf, t.params.len())
_i_p_1 = 0
@while _i_p_1 < t.params.len()
  p = t.params[_i_p_1]
      sec_buf = bytebuf_push(sec_buf, p)
  _i_p_1 = _i_p_1 + 1
@end
    sec_buf = encode_u32_leb128(sec_buf, t.results.len())
_i_r_1 = 0
@while _i_r_1 < t.results.len()
  r = t.results[_i_r_1]
      sec_buf = bytebuf_push(sec_buf, r)
  _i_r_1 = _i_r_1 + 1
@end
  _i_t_0 = _i_t_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_import_section(buf, imports)
  @if imports.len() == 0 return buf @end
  buf = bytebuf_push(buf, 2)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, imports.len())
_i_i_0 = 0
@while _i_i_0 < imports.len()
  i = imports[_i_i_0]
    sec_buf = encode_string(sec_buf, i.module_name)
    sec_buf = encode_string(sec_buf, i.field_name)
    sec_buf = bytebuf_push(sec_buf, i.kind)
    @if i.kind == 0
      sec_buf = encode_u32_leb128(sec_buf, i.type_idx)
    @end
  _i_i_0 = _i_i_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_function_section(buf, funcs)
  @if funcs.len() == 0 return buf @end
  buf = bytebuf_push(buf, 3)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, funcs.len())
_i_f_0 = 0
@while _i_f_0 < funcs.len()
  f = funcs[_i_f_0]
    sec_buf = encode_u32_leb128(sec_buf, f.type_idx)
  _i_f_0 = _i_f_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_table_section(buf, tables)
  @if tables.len() == 0 return buf @end
  buf = bytebuf_push(buf, 4)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, tables.len())
_i_t_0 = 0
@while _i_t_0 < tables.len()
  t = tables[_i_t_0]
    sec_buf = bytebuf_push(sec_buf, t.elem_type)
    sec_buf = bytebuf_push(sec_buf, t.has_max)
    sec_buf = encode_u32_leb128(sec_buf, t.limits_min)
    @if t.has_max == 1
      sec_buf = encode_u32_leb128(sec_buf, t.limits_max)
    @end
  _i_t_0 = _i_t_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_memory_section(buf, mems)
  @if mems.len() == 0 return buf @end
  buf = bytebuf_push(buf, 5)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, mems.len())
_i_m_0 = 0
@while _i_m_0 < mems.len()
  m = mems[_i_m_0]
    sec_buf = bytebuf_push(sec_buf, m.has_max)
    sec_buf = encode_u32_leb128(sec_buf, m.limits_min)
    @if m.has_max == 1
      sec_buf = encode_u32_leb128(sec_buf, m.limits_max)
    @end
  _i_m_0 = _i_m_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_global_section(buf, globals)
  @if globals.len() == 0 return buf @end
  buf = bytebuf_push(buf, 6)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, globals.len())
_i_g_0 = 0
@while _i_g_0 < globals.len()
  g = globals[_i_g_0]
    sec_buf = bytebuf_push(sec_buf, g.val_type)
    sec_buf = bytebuf_push(sec_buf, g.is_mut)
_i_i_1 = 0
@while _i_i_1 < g.init_expr.len()
  i = g.init_expr[_i_i_1]
      sec_buf = encode_instr(sec_buf, i)
  _i_i_1 = _i_i_1 + 1
@end
    sec_buf = bytebuf_push(sec_buf, 11) @! End
  _i_g_0 = _i_g_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_export_section(buf, exports)
  @if exports.len() == 0 return buf @end
  buf = bytebuf_push(buf, 7)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, exports.len())
_i_e_0 = 0
@while _i_e_0 < exports.len()
  e = exports[_i_e_0]
    sec_buf = encode_string(sec_buf, e.name)
    sec_buf = bytebuf_push(sec_buf, e.kind)
    sec_buf = encode_u32_leb128(sec_buf, e.index)
  _i_e_0 = _i_e_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_start_section(buf, start, has_start)
  @if has_start == 0 return buf @end
  buf = bytebuf_push(buf, 8)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, start)
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_element_section(buf, elements)
  @if elements.len() == 0 return buf @end
  buf = bytebuf_push(buf, 9)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, elements.len())
_i_e_0 = 0
@while _i_e_0 < elements.len()
  e = elements[_i_e_0]
    sec_buf = encode_u32_leb128(sec_buf, e.table_idx)
_i_i_1 = 0
@while _i_i_1 < e.offset_expr.len()
  i = e.offset_expr[_i_i_1]
      sec_buf = encode_instr(sec_buf, i)
  _i_i_1 = _i_i_1 + 1
@end
    sec_buf = bytebuf_push(sec_buf, 11) @! End
    sec_buf = encode_u32_leb128(sec_buf, e.init.len())
_i_idx_1 = 0
@while _i_idx_1 < e.init.len()
  idx = e.init[_i_idx_1]
      sec_buf = encode_u32_leb128(sec_buf, idx)
  _i_idx_1 = _i_idx_1 + 1
@end
  _i_e_0 = _i_e_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn encode_instr(buf, instr)
  buf = bytebuf_push(buf, instr.opcode)
  @if instr.opcode == wasm_op_i32_const()
    buf = encode_i32_leb128(buf, instr.imm_i64)
  @end
  @if instr.opcode == wasm_op_i64_const()
    buf = encode_i64_leb128(buf, instr.imm_i64)
  @end
  @if instr.opcode == wasm_op_f32_const()
    buf = encode_f32(buf, instr.imm_i64)
  @end
  @if instr.opcode == wasm_op_f64_const()
    buf = encode_f64(buf, instr.imm_i64)
  @end
  @if instr.opcode == wasm_op_local_get() || instr.opcode == wasm_op_local_set() || instr.opcode == wasm_op_local_tee() || instr.opcode == wasm_op_global_get() || instr.opcode == wasm_op_global_set() || instr.opcode == wasm_op_call() || instr.opcode == wasm_op_br() || instr.opcode == wasm_op_br_if()
    buf = encode_u32_leb128(buf, instr.imm_list[0])
  @end
  @if instr.opcode >= 40 && instr.opcode <= 62
    @! Memory load/store: align, offset
    buf = encode_u32_leb128(buf, instr.imm_list[0])
    buf = encode_u32_leb128(buf, instr.imm_list[1])
  @end
  @if instr.opcode == wasm_op_block() || instr.opcode == wasm_op_loop() || instr.opcode == wasm_op_if()
    buf = bytebuf_push(buf, instr.block_type)
  @end
  @if instr.opcode == wasm_op_call_indirect()
    buf = encode_u32_leb128(buf, instr.imm_list[0])
    buf = bytebuf_push(buf, 0)
  @end
  return buf
@end

@fn write_code_section(buf, funcs)
  @if funcs.len() == 0 return buf @end
  buf = bytebuf_push(buf, 10)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, funcs.len())
_i_f_0 = 0
@while _i_f_0 < funcs.len()
  f = funcs[_i_f_0]
    body_buf = bytebuf_new()
    body_buf = encode_u32_leb128(body_buf, f.locals.len())
_i_l_1 = 0
@while _i_l_1 < f.locals.len()
  l = f.locals[_i_l_1]
      body_buf = encode_u32_leb128(body_buf, l[0])
      body_buf = bytebuf_push(body_buf, l[1])
  _i_l_1 = _i_l_1 + 1
@end
_i_instr_1 = 0
@while _i_instr_1 < f.body.len()
  instr = f.body[_i_instr_1]
      body_buf = encode_instr(body_buf, instr)
  _i_instr_1 = _i_instr_1 + 1
@end
    body_buf = bytebuf_push(body_buf, 11) @! End
    
    sec_buf = encode_u32_leb128(sec_buf, body_buf.size)
    sec_buf = bytebuf_push_bytes(sec_buf, body_buf.bytes)
  _i_f_0 = _i_f_0 + 1
@end
  
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_data_section(buf, segments)
  @if segments.len() == 0 return buf @end
  buf = bytebuf_push(buf, 11)
  sec_buf = bytebuf_new()
  sec_buf = encode_u32_leb128(sec_buf, segments.len())
_i_s_0 = 0
@while _i_s_0 < segments.len()
  s = segments[_i_s_0]
    sec_buf = encode_u32_leb128(sec_buf, s.mem_idx)
_i_i_1 = 0
@while _i_i_1 < s.offset_expr.len()
  i = s.offset_expr[_i_i_1]
      sec_buf = encode_instr(sec_buf, i)
  _i_i_1 = _i_i_1 + 1
@end
    sec_buf = bytebuf_push(sec_buf, 11) @! End
    sec_buf = encode_u32_leb128(sec_buf, s.data.len())
    sec_buf = bytebuf_push_bytes(sec_buf, s.data)
  _i_s_0 = _i_s_0 + 1
@end
  buf = encode_u32_leb128(buf, sec_buf.size)
  buf = bytebuf_push_bytes(buf, sec_buf.bytes)
  return buf
@end

@fn write_wasm_module(module)
  buf = bytebuf_new()
  buf = bytebuf_push32(buf, 1836278016) @! \0asm
  buf = bytebuf_push32(buf, 1) @! version 1
  buf = write_type_section(buf, module.types)
  buf = write_import_section(buf, module.imports)
  buf = write_function_section(buf, module.functions)
  buf = write_table_section(buf, module.tables)
  buf = write_memory_section(buf, module.memories)
  buf = write_global_section(buf, module.globals)
  buf = write_export_section(buf, module.exports)
  buf = write_start_section(buf, module.start, module.has_start)
  buf = write_element_section(buf, module.elements)
  buf = write_code_section(buf, module.functions)
  buf = write_data_section(buf, module.data)
  return buf
@end

@fn emit_wasm_module_to_file(module, output_path)
  buf = write_wasm_module(module)
  return wasm_write_file(output_path, buf.bytes)
@end
