@! ============================================================================
@! LIPI JIT COMPILER & INTERACTIVE REPL ENGINE — UNIFIED ROOT MODULE
@! Module: compiler/backend/jit/mod.lp
@! Architecture: In-Memory Executable RAM Compilation, Execution & REPL Stack
@! ============================================================================

import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"
import "compiler/backend/jit/repl"

@! Re-exports and top-level convenience functions

@! Compiles and executes LiPi code in RAM with zero disk I/O
@fn lipi_jit_execute(source_code)
  return jit_compile_and_exec(source_code)
@end

@! Top-level alias for convenience
@fn jit_execute(source_code)
  return lipi_jit_execute(source_code)
@end

@! Launches the sovereign LiPi interactive REPL session
@fn lipi_repl_start()
  state = repl_init()
  return repl_run(state)
@end

@fn repl_start()
  return lipi_repl_start()
@end
