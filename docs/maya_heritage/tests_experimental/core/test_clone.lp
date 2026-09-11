@fn sys_mmap(addr, length, prot, flags, fd, offset)
  return syscall(9, addr, length, prot, flags, fd, offset)
@end

@fn main()
  stack_size = 2097152
  stack = sys_mmap(0, stack_size, 3, 34 | 256, 0 - 1, 0)
  stack_top = stack + stack_size - 16
  flags = 256 | 512 | 1024 | 2048 | 65536
  pid = syscall(56, flags, stack_top, 0, 0, 0, 0)
  return pid
@end
