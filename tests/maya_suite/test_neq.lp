@fn main()
  c1 = 10
  c2 = 10
  @if c1 != c2 sys_syscall(1, 1, "Diff!\n", 6, 0, 0, 0) @end
  
  c1 = 10
  c2 = 11
  @if c1 != c2 sys_syscall(1, 1, "Diff2!\n", 7, 0, 0, 0) @end
  
  sys_syscall(60, 0, 0, 0, 0, 0, 0)
@end
