@! ============================================================================
@! UNIVERSE B CORE: FILESYSTEM (Raw Linux Syscalls)
@! ============================================================================

@fn fs_open_read(filename)
  @! sys_syscall(2 = sys_open, filename, flags=0 (O_RDONLY), mode=0, 0, 0)
  return sys_syscall(2, filename, 0, 0, 0, 0, 0)
@end

@fn fs_open_write(filename)
  @! flags = O_WRONLY (1) | O_CREAT (64) | O_TRUNC (512) = 577
  @! mode = 0644 (420)
  return sys_syscall(2, filename, 577, 420, 0, 0, 0)
@end

@fn fs_open_append(filename)
  @! flags = O_WRONLY (1) | O_CREAT (64) | O_APPEND (1024) = 1089
  @! mode = 0644 (420)
  return sys_syscall(2, filename, 1089, 420, 0, 0, 0)
@end

@fn fs_read(fd, buf, count)
  @! sys_syscall(0 = sys_read, fd, buf, count, 0, 0)
  return sys_syscall(0, fd, buf, count, 0, 0, 0)
@end

@fn fs_write(fd, buf, count)
  @! sys_syscall(1 = sys_write, fd, buf, count, 0, 0)
  return sys_syscall(1, fd, buf, count, 0, 0, 0)
@end

@fn fs_close(fd)
  @! sys_syscall(3 = sys_close, fd, 0, 0, 0, 0)
  return sys_syscall(3, fd, 0, 0, 0, 0, 0)
@end
