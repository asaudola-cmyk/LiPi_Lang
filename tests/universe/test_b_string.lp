import "universe/b_core/io"
import "universe/b_core/string"

@fn main()
  s1 = "Hello, "
  s2 = "Universe B!"
  
  s3 = string_concat(s1, s2)
  
  string_print("s3 = ")
  string_println(s3)
  
  string_print("Length of s3: ")
  print_int(string_len(s3))
  
  @if string_eq(s3, "Hello, Universe B!") == 1
    string_println("String equality check PASSED!")
  @else
    string_println("String equality check FAILED!")
  @end
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
