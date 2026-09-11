import "universe/core/collections"

@fn main()
  println("Testing memfd_create and execveat")
  
  @! sys_memfd_create(name, flags)
  @! MFD_CLOEXEC = 1
  fd = sys_syscall(319, "univ_vm", 1, 0, 0, 0, 0)
  println(to_str(fd))
  
  @if fd > 0
    println("memfd created successfully!")
  @end
  
  @! ELF bytes for a tiny x86_64 program that exits with 42
  @! 7f 45 4c 46 02 01 01 00 ... (too long to hand write here quickly)
  @! Let's just create a tiny file in /tmp/tiny_ret42
  
  return 0
@end
