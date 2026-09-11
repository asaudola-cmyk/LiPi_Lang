@fn main()
  str = "Hello"
  c1 = sys_peek8(str + 0)
  c2 = sys_peek8(str + 1)
  
  @if c1 == 72 sys_syscall(1, 1, "H", 1, 0, 0, 0) @end
  @if c2 == 101 sys_syscall(1, 1, "e", 1, 0, 0, 0) @end
  
  sys_syscall(1, 1, "\n", 1, 0, 0, 0)
  sys_syscall(60, 0, 0, 0, 0, 0, 0)
@end
