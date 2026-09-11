import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/universal_math"

@fn main()
  println("Reading /tmp/hello")
  fd = sys_syscall(2, "/tmp/hello", 0, 0, 0, 0, 0)
  @if fd < 0
    // WHY: Create hermetic sample input file if /tmp/hello is not present
    fd_w = sys_syscall(2, "/tmp/hello", 65, 420, 0, 0, 0)
    sys_syscall(1, fd_w, "hello\n", 6, 0, 0, 0)
    sys_syscall(3, fd_w, 0, 0, 0, 0, 0)
    fd = sys_syscall(2, "/tmp/hello", 0, 0, 0, 0, 0)
  @end
  buf = sys_mmap(0, 1000, 3, 34, 0 - 1, 0)
  bytes_read = sys_syscall(0, fd, buf, 1000, 0, 0, 0)
  sys_syscall(3, fd, 0, 0, 0, 0, 0)
  
  println("Bytes read: " + to_str(bytes_read))
  
  bytes = []
  i = 0
  @while i < bytes_read
    bytes = bytes.push(sys_peek8(buf + i))
    i = i + 1
  @end
  
  println("Generating Universal Number...")
  g = generate_universal_number(bytes)
  
  println("Converting to String...")
  g_str = bigint_to_string(g)
  
  println("String length: " + to_str(c_len(g_str)))
  
  return 0
@end
