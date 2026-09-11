import "universe/os/syscalls"

@fn main()
  @! Syscall 1 is sys_write (fd, buf, len)
  @! fd 1 is STDOUT
  @! Since Maya strings might need raw pointers for sys_write,
  @! this is just a syntax verification test.
  
  a = 10
  b = 20
  c = a + b
  return c
@end
