@! --- ENTRY POINT ---
main()
sys_exit(0)

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end

@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 1, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
@end

@fn main()
  sys_syscall(1, 1, "Native Execution Verified
", 26, 0, 0, 0)
  return 0
@end
