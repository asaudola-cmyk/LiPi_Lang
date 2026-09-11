@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 1, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
@end
@fn main()
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  @if buf == 0
    sys_syscall(1, 1, "NULL
", 5, 0, 0, 0)
  @end
  return 0
@end
