import "universe/b_core/io"
import "universe/b_core/math"

@fn main()
  sys_syscall(1, 1, "Testing Universe B Core:\n", 25, 0, 0, 0)
  
  sys_syscall(1, 1, "math_abs(-42) = ", 16, 0, 0, 0)
  print_int(math_abs(0 - 42))
  
  sys_syscall(1, 1, "math_max(10, 20) = ", 19, 0, 0, 0)
  print_int(math_max(10, 20))
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
