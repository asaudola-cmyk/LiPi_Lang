@fn print_int(n)
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  i = 30
  sys_poke8(buf + 31, 10)
  sys_syscall(1, 1, buf + 31, 1, 0, 0, 0)
  return 0
@end
@fn main()
  print_int(8)
  return 0
@end
