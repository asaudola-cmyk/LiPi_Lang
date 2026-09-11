@! ============================================================================
@! MAYA JIT COMPILER BACKEND — FUNCTION INVOCATION & EXECUTION BRIDGE
@! Module: compiler/backend/jit/jit_executor.maya
@! Architecture: System V AMD64 ABI Native Userspace Execution Bridge
@! Standard: Function Pointer Calls (0 to 4 Arguments) & Evaluation Retrieval
@! ============================================================================

import "compiler/backend/jit/jit_memory"

@! ----------------------------------------------------------------------------
@! 1. FUNCTION INVOCATION BRIDGES (0 - 4 ARGUMENTS)
@! ----------------------------------------------------------------------------

@! Invokes a 0-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn0(fn_ptr)
  @if fn_ptr == 0
    return 0
  @end
  return maya_jit_call0(fn_ptr)
@end

@! Invokes a 1-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn1(fn_ptr, a1)
  @if fn_ptr == 0
    return 0
  @end
  return maya_jit_call1(fn_ptr, a1)
@end

@! Invokes a 2-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn2(fn_ptr, a1, a2)
  @if fn_ptr == 0
    return 0
  @end
  return maya_jit_call2(fn_ptr, a1, a2)
@end

@! Invokes a 3-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn3(fn_ptr, a1, a2, a3)
  @if fn_ptr == 0
    return 0
  @end
  return maya_jit_call3(fn_ptr, a1, a2, a3)
@end

@! Invokes a 4-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn4(fn_ptr, a1, a2, a3, a4)
  @if fn_ptr == 0
    return 0
  @end
  return maya_jit_call4(fn_ptr, a1, a2, a3, a4)
@end

@! Dynamic argument dispatcher for JIT function pointers
@fn jit_invoke_fn_args(fn_ptr, args)
  @if fn_ptr == 0
    return 0
  @end

  argc = args.len()
  @if argc == 0
    return jit_invoke_fn0(fn_ptr)
  @elif argc == 1
    return jit_invoke_fn1(fn_ptr, args[0])
  @elif argc == 2
    return jit_invoke_fn2(fn_ptr, args[0], args[1])
  @elif argc == 3
    return jit_invoke_fn3(fn_ptr, args[0], args[1], args[2])
  @elif argc == 4
    return jit_invoke_fn4(fn_ptr, args[0], args[1], args[2], args[3])
  @end

  @! Fallback for 0 args
  return jit_invoke_fn0(fn_ptr)
@end
