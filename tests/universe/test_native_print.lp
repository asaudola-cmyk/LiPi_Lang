@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 1, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
@end

@fn print_int(n)
  @if n == 0
    sys_write_byte(1, 48)
    sys_write_byte(1, 10)
    return 0
  @end
  
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  i = 30
  sys_poke8(buf + 31, 10)
  
  @while n > 0
    rem = n - ((n / 10) * 10)
    sys_poke8(buf + i, 48 + rem)
    n = n / 10
    i = i - 1
  @end
  
  sys_syscall(1, 1, buf + i + 1, 31 - i, 0, 0, 0)
@end

@fn main()
  println("▶ [NATIVE V5] Testing print_int...")
  print_int(123456789)
  
  println("▶ [NATIVE V5] Testing Bitwise Math...")
  a = 12
  b = 10
  
  println("12 & 10 = ")
  print_int(a & b)
  
  println("12 | 10 = ")
  print_int(a | b)
  
  println("12 ^ 10 = ")
  print_int(a ^ b)
  return 0
@end
