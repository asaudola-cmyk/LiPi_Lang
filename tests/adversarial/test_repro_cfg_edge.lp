import "universe/core/collections"
import "compiler/backend/maya_ir"

@fn main()
  b0 = ir_block_new(0, "b0")
  b1 = ir_block_new(1, "b1")
  b0.is_terminated = 1
  println("Before ir_cfg_add_edge, b0 succs len: " + b0.succs.len().to_str())
  ir_cfg_add_edge(b0, b1)
  println("After ir_cfg_add_edge, b0 succs len: " + b0.succs.len().to_str())
  return 0
@end
