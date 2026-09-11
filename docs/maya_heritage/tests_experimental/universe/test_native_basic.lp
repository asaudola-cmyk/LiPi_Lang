@! --- ENTRY POINT ---
main()
sys_exit(0)

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end

@fn main()
  sys_syscall(1, 1, "HELLO
", 6, 0, 0, 0)
  return 0
@end
