import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@fn main()
  v1 = ir_val_reg("%v1", ir_type_i64())
  v2 = ir_val_reg("%v2", ir_type_i64())
  phi_incoming = [
    { phi_val: v1, phi_block_id: 1 },
    { phi_val: v2, phi_block_id: 2 }
  ]
  phi_inst = ir_inst_phi("%res", phi_incoming, ir_type_i64())
  phi_str = ir_inst_to_string(phi_inst)
  println("Serialized PHI: " + phi_str)
  return 0
@end
