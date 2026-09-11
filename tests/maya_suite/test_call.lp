@fn main()
  sys_syscall(1, 1, 4194304 + 116, 12, 0, 0, 0)
  sys_exit(0)
  return 0
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
  return 0
@end
