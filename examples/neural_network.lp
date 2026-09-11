import "universe/maya_universe"
import "universe/core/fmt"

@fn math_abs(x)
  @if x < 0 return -x @end
  return x
@end

@fn sigmoid(x)
  @! fast sigmoid scaled by 10000
  abs_x = math_abs(x)
  denom = 10000 + abs_x
  frac = (x * 10000) / denom
  return 5000 + (frac / 2)
@end

@fn main()
  println("=== Maya Neural Network (XOR Problem) ===")
  println("Network: 2 Input -> 3 Hidden -> 1 Output")
  println("Activation: Fast Sigmoid")
  println("Training for 1000 Epochs...")
  println("")
  
  SCALE = 10000
  LR = 20000
  
  @! Weights initialization
  W1_00 = 1200; W1_01 = -2300; W1_02 = 3400
  W1_10 = -1500; W1_11 = 2600; W1_12 = -3700
  b1_0 = 100; b1_1 = -200; b1_2 = 300
  W2_0 = 4500; W2_1 = -5600; W2_2 = 6700
  b2 = -400
  
  epoch = 0
  EPOCHS = 1000
  
  @while epoch <= EPOCHS
    loss_sum = 0
    c = 0
    @while c < 4
      x1 = 0; x2 = 0; y_true = 0
      @if c == 1
        x2 = SCALE; y_true = SCALE
      @elif c == 2
        x1 = SCALE; y_true = SCALE
      @elif c == 3
        x1 = SCALE; x2 = SCALE; y_true = 0
      @end
      
      @! Forward Pass Hidden Layer
      z1_0 = (x1 * W1_00 + x2 * W1_10) / SCALE + b1_0
      z1_1 = (x1 * W1_01 + x2 * W1_11) / SCALE + b1_1
      z1_2 = (x1 * W1_02 + x2 * W1_12) / SCALE + b1_2
      
      a1_0 = sigmoid(z1_0)
      a1_1 = sigmoid(z1_1)
      a1_2 = sigmoid(z1_2)
      
      @! Forward Pass Output Layer
      z2 = (a1_0 * W2_0 + a1_1 * W2_1 + a1_2 * W2_2) / SCALE + b2
      a2 = sigmoid(z2)
      
      @! Error
      err = a2 - y_true
      loss_sum = loss_sum + (err * err) / SCALE
      
      @! Backprop Output Layer
      d_a2 = err
      a2_deriv = (a2 * (SCALE - a2)) / SCALE
      d_z2 = (d_a2 * a2_deriv) / SCALE
      
      @! Backprop Hidden Layer
      d_a1_0 = (d_z2 * W2_0) / SCALE
      d_a1_1 = (d_z2 * W2_1) / SCALE
      d_a1_2 = (d_z2 * W2_2) / SCALE
      
      d_z1_0 = (d_a1_0 * ((a1_0 * (SCALE - a1_0)) / SCALE)) / SCALE
      d_z1_1 = (d_a1_1 * ((a1_1 * (SCALE - a1_1)) / SCALE)) / SCALE
      d_z1_2 = (d_a1_2 * ((a1_2 * (SCALE - a1_2)) / SCALE)) / SCALE
      
      @! Update Weights Output Layer
      W2_0 = W2_0 - (LR * ((d_z2 * a1_0) / SCALE)) / SCALE
      W2_1 = W2_1 - (LR * ((d_z2 * a1_1) / SCALE)) / SCALE
      W2_2 = W2_2 - (LR * ((d_z2 * a1_2) / SCALE)) / SCALE
      b2 = b2 - (LR * d_z2) / SCALE
      
      @! Update Weights Hidden Layer
      W1_00 = W1_00 - (LR * ((d_z1_0 * x1) / SCALE)) / SCALE
      W1_01 = W1_01 - (LR * ((d_z1_1 * x1) / SCALE)) / SCALE
      W1_02 = W1_02 - (LR * ((d_z1_2 * x1) / SCALE)) / SCALE
      
      W1_10 = W1_10 - (LR * ((d_z1_0 * x2) / SCALE)) / SCALE
      W1_11 = W1_11 - (LR * ((d_z1_1 * x2) / SCALE)) / SCALE
      W1_12 = W1_12 - (LR * ((d_z1_2 * x2) / SCALE)) / SCALE
      
      b1_0 = b1_0 - (LR * d_z1_0) / SCALE
      b1_1 = b1_1 - (LR * d_z1_1) / SCALE
      b1_2 = b1_2 - (LR * d_z1_2) / SCALE
      
      c = c + 1
    @end
    
    @if epoch % 100 == 0
      
      loss_str = int_to_str(loss_sum)
      @while str_len(loss_str) < 4
        loss_str = "0" + loss_str
      @end
      @if loss_sum >= 10000
        @! If >= 1.0, just print as is, simple trick
        loss_str = int_to_str(loss_sum / 10000) + "." + int_to_str(loss_sum % 10000)
      @else
        loss_str = "0." + loss_str
      @end
      println("Epoch " + pad_right(int_to_str(epoch), 4) + " | Loss: " + loss_str)

    @end
    
    epoch = epoch + 1
  @end
  
  println("")
  println("Final Predictions:")
  
  c = 0
  @while c < 4
    x1 = 0; x2 = 0
    @if c == 1
      x2 = SCALE
    @elif c == 2
      x1 = SCALE
    @elif c == 3
      x1 = SCALE; x2 = SCALE
    @end
    
    z1_0 = (x1 * W1_00 + x2 * W1_10) / SCALE + b1_0
    z1_1 = (x1 * W1_01 + x2 * W1_11) / SCALE + b1_1
    z1_2 = (x1 * W1_02 + x2 * W1_12) / SCALE + b1_2
    
    a1_0 = sigmoid(z1_0)
    a1_1 = sigmoid(z1_1)
    a1_2 = sigmoid(z1_2)
    
    z2 = (a1_0 * W2_0 + a1_1 * W2_1 + a1_2 * W2_2) / SCALE + b2
    a2 = sigmoid(z2)
    
    s1 = int_to_str(x1 / 10000)
    s2 = int_to_str(x2 / 10000)
    
    @! Formatting for leading zeros
    a2_str = int_to_str(a2)
    @while str_len(a2_str) < 4
      a2_str = "0" + a2_str
    @end
    
    println("Input (" + s1 + "," + s2 + ") -> Prediction: 0." + a2_str)
    c = c + 1
  @end
  
  return 0
@end

@fn pad_right(s, width)
  @while str_len(s) < width
    s = s + " "
  @end
  return s
@end

