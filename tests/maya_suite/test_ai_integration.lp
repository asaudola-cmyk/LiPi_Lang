import "universe/ai/tensor"

println("--- AI Tensor Integration Test ---")

t1 = tensor_new([1, 2, 3, 4], [2, 2])
t2 = tensor_new([5, 6, 7, 8], [2, 2])

t_add = tensor_add(t1, t2)
@if t_add.data[0] == 6
  println("PASS: tensor_add")
@else
  println("FAIL: tensor_add")
@end

t_mul = tensor_mul(t1, t2)
@if t_mul.data[0] == 5
  println("PASS: tensor_mul")
@else
  println("FAIL: tensor_mul")
@end

t3 = tensor_new([0 - 1, 5, 0 - 3, 8], [2, 2])
t_relu = tensor_relu(t3)
@if t_relu.data[0] == 0
  println("PASS: tensor_relu")
@else
  println("FAIL: tensor_relu")
@end
