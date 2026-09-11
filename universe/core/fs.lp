@! ==================================================================
@! MAYA UNIVERSE - Core Filesystem Library (Phase 14)
@! ==================================================================

@! O_RDONLY = 0
@fn fs_open(filename)
  @! sys_syscall(2 = sys_open, filename, flags=0, mode=0, 0, 0)
  return sys_syscall(2, filename, 0, 0, 0, 0)
@end

@fn fs_read(fd, buf, count)
  @! sys_syscall(0 = sys_read, fd, buf, count, 0, 0)
  return sys_syscall(0, fd, buf, count, 0, 0)
@end

@fn fs_write(fd, buf, count)
  @! sys_syscall(1 = sys_write, fd, buf, count, 0, 0)
  return sys_syscall(1, fd, buf, count, 0, 0)
@end

@fn fs_close(fd)
  @! sys_syscall(3 = sys_close, fd, 0, 0, 0, 0)
  return sys_syscall(3, fd, 0, 0, 0, 0)
@end

@! Reads entire file into a mallocd buffer and returns a struct {ptr, size}
@! We will just return the pointer, and the caller can figure out the size if it is a string.
@! But wait, we want to know how many bytes were read.
@! Let us just return a mallocd null-terminated string!
@fn fs_read_all(filename)
  fd = fs_open(filename)
  @if fd < 0
    return 0
  @end
  
  @! Max file size 64KB for now
  buf = malloc(65536)
  bytes_read = fs_read(fd, buf, 65535)
  sys_poke8(buf + bytes_read, 0)
  fs_close(fd)
  return buf
@end
