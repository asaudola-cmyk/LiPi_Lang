@fn main()
  buf = sys_mmap(0, 32, 3, 34, -1, 0)
  @if buf == 0 || buf == 18446744073709551615
    sys_syscall(1, 1, "MMAP FAILED
", 12, 0, 0, 0)
    return 1
  @end
  sys_syscall(1, 1, "MMAP SUCCESS
", 13, 0, 0, 0)
  return 0
@end
