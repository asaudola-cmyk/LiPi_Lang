import "universe/os/syscalls"

@fn main()
  pid = sys_getpid()
  @if pid > 0
    return 0
  @end
  return 1
@end
