@! ============================================================================
@! MAYA COMPILER STAGE 3 — WEBASSEMBLY (WASM32) CODEGEN ADAPTER
@! ============================================================================

import "compiler/backend/wasm"

@fn wasm_generate_program(mir_or_ast)
  return mir_to_wasm_wat(mir_or_ast)
@end
