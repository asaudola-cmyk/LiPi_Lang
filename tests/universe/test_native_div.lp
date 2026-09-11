@fn main()
  n = 8
  n = n / 10
  @if n == 0
    sys_syscall(1, 1, "DIV ZERO SUCCESS
", 17, 0, 0, 0)
  @end
  return 0
@end
