@! ============================================================================
@! MAYA JIT COMPILER & INTERACTIVE REPL ENGINE — UNIFIED ROOT MODULE
@! Module: compiler/backend/jit/mod.maya
@! Architecture: In-Memory Executable RAM Compilation, Execution & REPL Stack
@! ============================================================================

import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"
import "compiler/backend/jit/repl"

@! Re-exports and top-level convenience functions

@! Compiles and executes Maya code in RAM with zero disk I/O
@fn maya_jit_execute(source_code)
  return jit_compile_and_exec(source_code)
@end

@! Launches the sovereign Maya interactive REPL session
@fn maya_repl_start()
  state = repl_init()
  return repl_run(state)
@end
