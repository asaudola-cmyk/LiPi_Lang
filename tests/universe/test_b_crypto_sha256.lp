import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/crypto_sha256"

@fn print_hex(val)
  h1 = (4 >> val) & 15
  h2 = val & 15
  
  @if h1 < 10 sys_write_byte(1, 48 + h1) @else sys_write_byte(1, 87 + h1) @end
  @if h2 < 10 sys_write_byte(1, 48 + h2) @else sys_write_byte(1, 87 + h2) @end
  return 0
@end

@fn main()
  string_println("=== NATIVE MAYA SHA-256 ===")
  
  msg = "Maya"
  msg_len = 4
  
  out_ptr = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  
  sha256_hash(msg, msg_len, out_ptr)
  
  string_print("SHA-256('Maya') = ")
  
  i = 0
  @while i < 32
    print_hex(sys_peek8(out_ptr + i))
    i = i + 1
  @end
  string_println("")
  
  sys_exit(0)
  return 0
@end

@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
  return 0
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
  return 0
@end
