import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/math_ml"

@fn print_float_approx(val)
  @! Print something like 0.XXX
  f_zero = int_to_float(0)
  @if flt(val, f_zero) == 1
    string_print("-")
    val = fsub(f_zero, val)
  @end
  
  i_part = float_to_int(val)
  rem = fsub(val, int_to_float(i_part))
  
  @! multiply by 1000 to get 3 decimals
  i_rem = float_to_int(fmul(rem, int_to_float(1000)))
  
  sys_syscall(1, 1, "0.", 2, 0, 0, 0)
  
  buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  idx = 0
  temp = i_rem
  @if temp == 0
    sys_syscall(1, 1, "000", 3, 0, 0, 0)
    return 0
  @end
  
  @while temp > 0
    temp = temp / 10
    idx = idx + 1
  @end
  @! pad zeros
  pad = 3 - idx
  @while pad > 0
    sys_syscall(1, 1, "0", 1, 0, 0, 0)
    pad = pad - 1
  @end
  
  temp = i_rem
  i = idx - 1
  @while temp > 0
    digit = temp - ((temp / 10) * 10)
    sys_poke8(buf + i, 48 + digit)
    temp = temp / 10
    i = i - 1
  @end
  
  sys_syscall(1, 1, buf, idx, 0, 0, 0)
  return 0
@end

@fn main()
  string_println("=== Native Maya Neural Network (Backprop/XOR) ===")
  
  @! Init weights randomly
  w1_00 = float(0, 5, 10)
  w1_01 = float_neg(0, 2, 10)
  w1_10 = float_neg(0, 6, 10)
  w1_11 = float(0, 8, 10)
  
  w2_00 = float(0, 4, 10)
  w2_10 = float_neg(0, 3, 10)
  
  b1_0 = float(0, 1, 10)
  b1_1 = float_neg(0, 1, 10)
  b2_0 = float(0, 2, 10)
  
  lr = float(1, 5, 10) @! Learning rate = 1.5
  
  epoch = 0
  @while epoch < 3000
    err_sum = int_to_float(0)
    
    @! Dataset: 4 pairs (XOR)
    i = 0
    @while i < 4
      x0 = int_to_float(0)
      x1 = int_to_float(0)
      target = int_to_float(0)
      
      @if i == 0 x0 = int_to_float(0) x1 = int_to_float(0) target = int_to_float(0) @end
      @if i == 1 x0 = int_to_float(0) x1 = int_to_float(1) target = int_to_float(1) @end
      @if i == 2 x0 = int_to_float(1) x1 = int_to_float(0) target = int_to_float(1) @end
      @if i == 3 x0 = int_to_float(1) x1 = int_to_float(1) target = int_to_float(0) @end
      
      @! Forward
      h0_sum = fadd(fadd(fmul(x0, w1_00), fmul(x1, w1_10)), b1_0)
      h1_sum = fadd(fadd(fmul(x0, w1_01), fmul(x1, w1_11)), b1_1)
      h0 = sigmoid(h0_sum)
      h1 = sigmoid(h1_sum)
      
      o_sum = fadd(fadd(fmul(h0, w2_00), fmul(h1, w2_10)), b2_0)
      o = sigmoid(o_sum)
      
      @! Error
      err = fsub(o, target)
      err_sum = fadd(err_sum, fmul(err, err))
      
      @! Backward
      do_net = fmul(err, sigmoid_deriv(o))
      
      dW2_00 = fmul(h0, do_net)
      dW2_10 = fmul(h1, do_net)
      dB2_0 = do_net
      
      dh0 = fmul(do_net, w2_00)
      dh1 = fmul(do_net, w2_10)
      
      dh0_net = fmul(dh0, sigmoid_deriv(h0))
      dh1_net = fmul(dh1, sigmoid_deriv(h1))
      
      dW1_00 = fmul(x0, dh0_net)
      dW1_10 = fmul(x1, dh0_net)
      dW1_01 = fmul(x0, dh1_net)
      dW1_11 = fmul(x1, dh1_net)
      
      dB1_0 = dh0_net
      dB1_1 = dh1_net
      
      @! Update
      w2_00 = fsub(w2_00, fmul(lr, dW2_00))
      w2_10 = fsub(w2_10, fmul(lr, dW2_10))
      b2_0 = fsub(b2_0, fmul(lr, dB2_0))
      
      w1_00 = fsub(w1_00, fmul(lr, dW1_00))
      w1_10 = fsub(w1_10, fmul(lr, dW1_10))
      w1_01 = fsub(w1_01, fmul(lr, dW1_01))
      w1_11 = fsub(w1_11, fmul(lr, dW1_11))
      
      b1_0 = fsub(b1_0, fmul(lr, dB1_0))
      b1_1 = fsub(b1_1, fmul(lr, dB1_1))
      
      i = i + 1
    @end
    
    @if epoch == 0 || epoch == 1000 || epoch == 2999
      string_print("Epoch ")
      buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
      @! Just use a cheap print since no int_to_string here
      @! Instead I'll print loss approximate
      string_print(" - Loss: ") print_float_approx(err_sum) string_println("")
    @end
    
    epoch = epoch + 1
  @end
  
  string_println("Training Complete. Testing Predictions:")
  @! Test 1,0
  x0 = int_to_float(1) x1 = int_to_float(0)
  h0 = sigmoid(fadd(fadd(fmul(x0, w1_00), fmul(x1, w1_10)), b1_0))
  h1 = sigmoid(fadd(fadd(fmul(x0, w1_01), fmul(x1, w1_11)), b1_1))
  o = sigmoid(fadd(fadd(fmul(h0, w2_00), fmul(h1, w2_10)), b2_0))
  string_print("Input(1,0) [Expect 1]: ") print_float_approx(o) string_println("")
  
  @! Test 1,1
  x0 = int_to_float(1) x1 = int_to_float(1)
  h0 = sigmoid(fadd(fadd(fmul(x0, w1_00), fmul(x1, w1_10)), b1_0))
  h1 = sigmoid(fadd(fadd(fmul(x0, w1_01), fmul(x1, w1_11)), b1_1))
  o = sigmoid(fadd(fadd(fmul(h0, w2_00), fmul(h1, w2_10)), b2_0))
  string_print("Input(1,1) [Expect 0]: ") print_float_approx(o) string_println("")
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
