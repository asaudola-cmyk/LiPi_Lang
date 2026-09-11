@! ============================================================================
@! WebAssembly Low-Level Instruction & Buffer Codegen
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/wasm/wasm_emitter"

@struct WasmBuf
  wb_data: array
  wb_size: i64
@end

@fn wasm_magic()
  return 1836278016 @! '\0asm'
@end

@fn wasm_buf_new()
  return { wb_data: [], wb_size: 0 }
@end

@fn wasm_buf_push(buf, byte)
  buf.wb_data = buf.wb_data.push(byte % 256)
  buf.wb_size = buf.wb_size + 1
  return 1
@end

@! Unsigned 64-bit LEB128
@fn wasm_buf_leb128(buf, val)
  v = val
  @while 1
    byte = v & 127
    @if v < 0
      v = (v >> 7) & 144115188075855871 @! 0x01FFFFFFFFFFFFFF (57-bit mask)
    @else
      v = v >> 7
    @end
    @if v == 0
      wasm_buf_push(buf, byte)
      return 1
    @else
      wasm_buf_push(buf, byte | 128)
    @end
  @end
  return 1
@end

@! Signed 64-bit LEB128
@fn wasm_buf_sleb128(buf, val)
  v = val
  @while 1
    byte = v & 127
    v = v >> 7
    sign_bit = byte & 64
    @if (v == 0 && sign_bit == 0) || (v == -1 && sign_bit != 0)
      wasm_buf_push(buf, byte)
      return 1
    @else
      wasm_buf_push(buf, byte | 128)
    @end
  @end
  return 1
@end

@fn wasm_emit_i32_const(buf, val)
  wasm_buf_push(buf, 65) @! 0x41 i32.const
  wasm_buf_sleb128(buf, val)
  return 1
@end

@fn wasm_emit_i64_const(buf, val)
  wasm_buf_push(buf, 66) @! 0x42 i64.const
  wasm_buf_sleb128(buf, val)
  return 1
@end

@fn wasm_emit_local_get(buf, idx)
  wasm_buf_push(buf, 32) @! 0x20 local.get
  wasm_buf_leb128(buf, idx)
  return 1
@end

@fn wasm_emit_local_set(buf, idx)
  wasm_buf_push(buf, 33) @! 0x21 local.set
  wasm_buf_leb128(buf, idx)
  return 1
@end

@fn wasm_emit_local_tee(buf, idx)
  wasm_buf_push(buf, 34) @! 0x22 local.tee
  wasm_buf_leb128(buf, idx)
  return 1
@end

@fn wasm_emit_global_get(buf, idx)
  wasm_buf_push(buf, 35) @! 0x23 global.get
  wasm_buf_leb128(buf, idx)
  return 1
@end

@fn wasm_emit_global_set(buf, idx)
  wasm_buf_push(buf, 36) @! 0x24 global.set
  wasm_buf_leb128(buf, idx)
  return 1
@end

@fn wasm_emit_add_i32(buf)
  wasm_buf_push(buf, 106) @! 0x6A i32.add
  return 1
@end

@fn wasm_emit_sub_i32(buf)
  wasm_buf_push(buf, 107) @! 0x6B i32.sub
  return 1
@end

@fn wasm_emit_mul_i32(buf)
  wasm_buf_push(buf, 108) @! 0x6C i32.mul
  return 1
@end

@fn wasm_emit_add_i64(buf)
  wasm_buf_push(buf, 124) @! 0x7C i64.add
  return 1
@end

@fn wasm_emit_sub_i64(buf)
  wasm_buf_push(buf, 125) @! 0x7D i64.sub
  return 1
@end

@fn wasm_emit_mul_i64(buf)
  wasm_buf_push(buf, 126) @! 0x7E i64.mul
  return 1
@end

@fn wasm_emit_return(buf)
  wasm_buf_push(buf, 15) @! 0x0F return
  return 1
@end

@fn wasm_emit_unreachable(buf)
  wasm_buf_push(buf, 0) @! 0x00 unreachable
  return 1
@end

@fn wasm_emit_nop(buf)
  wasm_buf_push(buf, 1) @! 0x01 nop
  return 1
@end

@fn wasm_emit_drop(buf)
  wasm_buf_push(buf, 26) @! 0x1A drop
  return 1
@end

@fn wasm_emit_block(buf, block_type)
  wasm_buf_push(buf, 2) @! 0x02 block
  wasm_buf_push(buf, block_type)
  return 1
@end

@fn wasm_emit_loop(buf, block_type)
  wasm_buf_push(buf, 3) @! 0x03 loop
  wasm_buf_push(buf, block_type)
  return 1
@end

@fn wasm_emit_if(buf)
  wasm_buf_push(buf, 4)  @! 0x04 if
  wasm_buf_push(buf, 64) @! 0x40 empty block type
  return 1
@end

@fn wasm_emit_else(buf)
  wasm_buf_push(buf, 5) @! 0x05 else
  return 1
@end

@fn wasm_emit_end(buf)
  wasm_buf_push(buf, 11) @! 0x0B end
  return 1
@end

@fn wasm_emit_call(buf, fn_idx)
  wasm_buf_push(buf, 16) @! 0x10 call
  wasm_buf_leb128(buf, fn_idx)
  return 1
@end

@fn wasm_emit_br(buf, depth)
  wasm_buf_push(buf, 12) @! 0x0C br
  wasm_buf_leb128(buf, depth)
  return 1
@end

@fn wasm_emit_br_if(buf, depth)
  wasm_buf_push(buf, 13) @! 0x0D br_if
  wasm_buf_leb128(buf, depth)
  return 1
@end

@fn wasm_build_header(buf)
  wasm_buf_push(buf, 0)
  wasm_buf_push(buf, 97)
  wasm_buf_push(buf, 115)
  wasm_buf_push(buf, 109)
  wasm_buf_push(buf, 1)
  wasm_buf_push(buf, 0)
  wasm_buf_push(buf, 0)
  wasm_buf_push(buf, 0)
  return 8
@end

@fn wasm_write_module(functions_or_module, output_path)
  @! Determine if functions_or_module is already a WasmModule
  module = functions_or_module
  @if module == 0
    return 0
  @end

  @! If passed array of functions, construct valid wrapper module
  @! Check if functions_or_module is a list or module struct
  @! In Maya, structs have field access. If module has .types, write directly:
  res_buf = write_wasm_module(module)
  status = wasm_write_file(output_path, res_buf.bytes)
  @if status >= 0
    return 1
  @end
  return 0
@end
