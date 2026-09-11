@! --- ENTRY POINT ---
main()
sys_exit(0)

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end

@fn main()
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  sys_poke8(buf, 56)
  sys_poke8(buf + 1, 10)
  sys_syscall(1, 1, buf, 2, 0, 0, 0)
  return 0
@end
