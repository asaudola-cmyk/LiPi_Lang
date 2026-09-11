@fn print_int_custom(val)
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  i = 30
  sys_poke8(buf + 31, 10)
  @if val == 0
    sys_poke8(buf + 30, 48)
    sys_syscall(1, 1, buf + 30, 2, 0, 0, 0)
    return 0
  @end
  @while val > 0
    rem = val - ((val / 10) * 10)
    sys_poke8(buf + i, 48 + rem)
    val = val / 10
    i = i - 1
  @end
  sys_syscall(1, 1, buf + i + 1, 30 - i + 1, 0, 0, 0)
@end

@fn main()
  val1 = 1 << 24
  print_int_custom(val1)
  
  val2 = 24 << 1
  print_int_custom(val2)
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
