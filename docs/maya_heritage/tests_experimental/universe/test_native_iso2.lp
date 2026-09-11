@fn print_int(n)
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
  return 0
@end
@fn main()
  print_int(8)
  return 0
@end
