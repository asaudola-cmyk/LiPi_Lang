import "universe/b_core/io"

@fn emit_byte(arena, b)
  len = sys_peek(arena + 60000000)
  sys_poke8(arena + len, b)
  sys_poke(arena + 60000000, len + 1)
  return 0
@end

@fn emit_leb128_u32(arena, val)
  parsing = 1
  @while parsing == 1
    byte = val & 127
    val = val >> 7
    @if val != 0
      byte = byte | 128
      emit_byte(arena, byte)
    @else
      emit_byte(arena, byte)
      parsing = 0
    @end
  @end
  return 0
@end

@fn emit_wasm_string(arena, str, len)
  emit_leb128_u32(arena, len)
  i = 0
  @while i < len
    emit_byte(arena, sys_peek8(str + i))
    i = i + 1
  @end
  return 0
@end

@fn main()
  arena = sys_mmap(0, 67108864, 3, 34, 0 - 1, 0)
  sys_poke(arena + 60000000, 0)
  
  @! Magic: \0asm
  emit_byte(arena, 0) emit_byte(arena, 97) emit_byte(arena, 115) emit_byte(arena, 109)
  @! Version: 1
  emit_byte(arena, 1) emit_byte(arena, 0) emit_byte(arena, 0) emit_byte(arena, 0)
  
  @! Section 1: Type (0x01)
  emit_byte(arena, 1)
  emit_leb128_u32(arena, 5) @! Size of section (5 bytes)
  emit_leb128_u32(arena, 1) @! 1 type
  emit_byte(arena, 96)      @! func (0x60)
  emit_leb128_u32(arena, 0) @! 0 params
  emit_leb128_u32(arena, 1) @! 1 return
  emit_byte(arena, 126)     @! i64 (0x7E)
  
  @! Section 3: Function (0x03)
  emit_byte(arena, 3)
  emit_leb128_u32(arena, 2) @! Size (2 bytes)
  emit_leb128_u32(arena, 1) @! 1 function
  emit_leb128_u32(arena, 0) @! type index 0
  
  @! Section 7: Export (0x07)
  emit_byte(arena, 7)
  emit_leb128_u32(arena, 8) @! Size (8 bytes)
  emit_leb128_u32(arena, 1) @! 1 export
  emit_wasm_string(arena, "main", 4)
  emit_byte(arena, 0)       @! Export kind: func (0)
  emit_leb128_u32(arena, 0) @! Func index 0
  
  @! Section 10: Code (0x0A)
  emit_byte(arena, 10)
  @! Hardcode size for: [1 vector], [size of code block = 4], [0 locals], [i64.const (0x42)], [42], [end (0x0B)]
  @! Total bytes inside section: 1 (vector) + 1 (size) + 1 (locals) + 1 (const) + 1 (42) + 1 (end) = 6 bytes
  emit_leb128_u32(arena, 6)
  emit_leb128_u32(arena, 1) @! 1 function body
  emit_leb128_u32(arena, 4) @! Size of function body = 4 bytes
  emit_leb128_u32(arena, 0) @! 0 local variables
  
  @! i64.const 42
  emit_byte(arena, 66) @! 0x42
  emit_leb128_u32(arena, 42)
  
  emit_byte(arena, 11) @! 0x0B (end)
  
  @! Write to file
  out_len = sys_peek(arena + 60000000)
  
  @! O_WRONLY | O_CREAT | O_TRUNC = 577, mode = 0644
  fd = sys_syscall(2, "test.wasm", 577, 420, 0, 0, 0)
  sys_syscall(1, fd, arena, out_len, 0, 0, 0)
  sys_syscall(3, fd, 0, 0, 0, 0, 0)
  
  sys_syscall(1, 1, "WASM Compiled Successfully!\n", 28, 0, 0, 0)
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
