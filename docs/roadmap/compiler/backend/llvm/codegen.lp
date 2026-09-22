@! ============================================================================
@! MAYA COMPILER STAGE 3 — LLVM CODEGEN ADAPTER
@! ============================================================================

import "compiler/backend/llvm_ir"

@fn llvm_generate_program(mir_or_ast)
  return mir_to_llvm_ir(mir_or_ast)
@end
