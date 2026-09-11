import "universe/b_core/io"
import "universe/b_core/tensor"

@fn main()
  sys_syscall(1, 1, "=== Native Maya AI (Universe B Tensor) ===\n", 43, 0, 0, 0)
  
  @! Create shape [2, 2]
  shape_ptr = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(shape_ptr + 0, 2)
  sys_poke(shape_ptr + 8, 2)
  
  @! Matrix A
  tA = tensor_new(shape_ptr, 2)
  tensor_set_data(tA, 0, int_to_float(1))
  tensor_set_data(tA, 1, int_to_float(2))
  tensor_set_data(tA, 2, int_to_float(3))
  tensor_set_data(tA, 3, int_to_float(4))
  
  @! Matrix B
  tB = tensor_new(shape_ptr, 2)
  tensor_set_data(tB, 0, int_to_float(2))
  tensor_set_data(tB, 1, int_to_float(0))
  tensor_set_data(tB, 2, int_to_float(1))
  tensor_set_data(tB, 3, int_to_float(2))
  
  @! C = A * B (Matrix Multiplication)
  tC = tensor_dot_2d(tA, tB)
  
  @! Expected Output:
  @! [1 2] * [2 0] = [ (2+2) (0+4) ] = [4 4]
  @! [3 4]   [1 2]   [ (6+4) (0+8) ]   [10 8]
  
  sys_syscall(1, 1, "Matrix C (A dot B):\n", 20, 0, 0, 0)
  
  c_data = sys_peek(tC + 0)
  
  v0 = sys_peek(c_data + 0)
  v1 = sys_peek(c_data + 8)
  v2 = sys_peek(c_data + 16)
  v3 = sys_peek(c_data + 24)
  
  print_float(v0, 1)
  print_float(v1, 1)
  print_float(v2, 1)
  print_float(v3, 1)
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
