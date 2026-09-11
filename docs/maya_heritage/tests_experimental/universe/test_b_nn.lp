import "universe/b_core/io"
import "universe/b_core/tensor"

@fn float(int_part, frac_part, divisor)
  f_int = int_to_float(int_part)
  f_frac = int_to_float(frac_part)
  f_div = int_to_float(divisor)
  return fadd(f_int, fdiv(f_frac, f_div))
@end

@fn float_neg(int_part, frac_part, divisor)
  f_int = int_to_float(int_part)
  f_frac = int_to_float(frac_part)
  f_div = int_to_float(divisor)
  f_val = fadd(f_int, fdiv(f_frac, f_div))
  return fsub(int_to_float(0), f_val)
@end

@fn main()
  sys_syscall(1, 1, "=== Native Neural Network Inference ===\n", 40, 0, 0, 0)
  
  @! 1. Input X [1, 2]
  s_x = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(s_x + 0, 1) sys_poke(s_x + 8, 2)
  X = tensor_new(s_x, 2)
  tensor_set_data(X, 0, float(0, 5, 10))    @! 0.5
  tensor_set_data(X, 1, float_neg(1, 2, 10)) @! -1.2
  
  @! 2. Layer 1 Weights W1 [2, 3]
  s_w1 = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(s_w1 + 0, 2) sys_poke(s_w1 + 8, 3)
  W1 = tensor_new(s_w1, 2)
  tensor_set_data(W1, 0, float(1, 0, 1))   @! 1.0
  tensor_set_data(W1, 1, float(0, 5, 10))  @! 0.5
  tensor_set_data(W1, 2, float_neg(0, 1, 10)) @! -0.1
  tensor_set_data(W1, 3, float_neg(2, 0, 1)) @! -2.0
  tensor_set_data(W1, 4, float(0, 0, 1))   @! 0.0
  tensor_set_data(W1, 5, float(1, 5, 10))  @! 1.5
  
  @! 3. Layer 1 Bias b1 [3]
  s_b1 = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke(s_b1 + 0, 3)
  B1 = tensor_new(s_b1, 1)
  tensor_set_data(B1, 0, float(0, 1, 10))  @! 0.1
  tensor_set_data(B1, 1, float(0, 2, 10))  @! 0.2
  tensor_set_data(B1, 2, float(0, 3, 10))  @! 0.3
  
  @! 4. Layer 2 Weights W2 [3, 1]
  s_w2 = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(s_w2 + 0, 3) sys_poke(s_w2 + 8, 1)
  W2 = tensor_new(s_w2, 2)
  tensor_set_data(W2, 0, float(1, 0, 1))   @! 1.0
  tensor_set_data(W2, 1, float_neg(1, 0, 1)) @! -1.0
  tensor_set_data(W2, 2, float(2, 0, 1))   @! 2.0
  
  @! 5. Layer 2 Bias b2 [1]
  s_b2 = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke(s_b2 + 0, 1)
  B2 = tensor_new(s_b2, 1)
  tensor_set_data(B2, 0, float_neg(0, 5, 10)) @! -0.5
  
  @! --- INFERENCE EXECUTION ---
  
  @! h_pre = X @ W1
  sys_syscall(1, 1, "Executing: h_pre = X @ W1\n", 26, 0, 0, 0)
  h_pre = tensor_dot_2d(X, W1)
  
  @! h_bias = h_pre + B1
  sys_syscall(1, 1, "Executing: h_bias = h_pre + B1\n", 31, 0, 0, 0)
  h_bias = tensor_add_bias_2d(h_pre, B1)
  
  @! h = ReLU(h_bias)
  sys_syscall(1, 1, "Executing: h = ReLU(h_bias)\n", 28, 0, 0, 0)
  h = tensor_relu(h_bias)
  
  @! y_pre = h @ W2
  sys_syscall(1, 1, "Executing: y_pre = h @ W2\n", 26, 0, 0, 0)
  y_pre = tensor_dot_2d(h, W2)
  
  @! y = y_pre + B2
  sys_syscall(1, 1, "Executing: y = y_pre + B2\n", 26, 0, 0, 0)
  y = tensor_add_bias_2d(y_pre, B2)
  
  sys_syscall(1, 1, "Network Output (y):\n", 20, 0, 0, 0)
  
  out_data = sys_peek(y + 0)
  y_val = sys_peek(out_data + 0)
  
  print_float(y_val, 4)
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
