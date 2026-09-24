@! ============================================================================
@! LIPI JIT COMPILER BACKEND — FUNCTION INVOCATION & EXECUTION BRIDGE
@! Module: compiler/backend/jit/jit_executor.lp
@! Architecture: System V AMD64 ABI Native Userspace Execution Bridge
@! Standard: Function Pointer Calls (0 to 4 Arguments) & Evaluation Retrieval
@! ============================================================================

import "compiler/backend/jit/jit_memory"

@! ----------------------------------------------------------------------------
@! 1. FUNCTION INVOCATION BRIDGES (0 - 4 ARGUMENTS)
@! ----------------------------------------------------------------------------

@! Low-level AMD64 indirect call bridges executing function pointers in RAM
@fn lipi_jit_call0(fn_ptr)
  // WHY: Direct Silicon jump to executable JIT machine code page without
  // libc or trampolines, conforming strictly to System V AMD64 ABI.
  @if fn_ptr == 0
    return 0
  @end
  return fn_ptr()
@end

@fn lipi_jit_call1(fn_ptr, a1)
  // WHY: AMD64 indirect call passing a1 in %rdi
  @if fn_ptr == 0
    return 0
  @end
  return fn_ptr(a1)
@end

@fn lipi_jit_call2(fn_ptr, a1, a2)
  // WHY: AMD64 indirect call passing a1 in %rdi, a2 in %rsi
  @if fn_ptr == 0
    return 0
  @end
  return fn_ptr(a1, a2)
@end

@fn lipi_jit_call3(fn_ptr, a1, a2, a3)
  // WHY: AMD64 indirect call passing a1 in %rdi, a2 in %rsi, a3 in %rdx
  @if fn_ptr == 0
    return 0
  @end
  return fn_ptr(a1, a2, a3)
@end

@fn lipi_jit_call4(fn_ptr, a1, a2, a3, a4)
  // WHY: AMD64 indirect call passing 4 arguments via System V ABI registers
  @if fn_ptr == 0
    return 0
  @end
  return fn_ptr(a1, a2, a3, a4)
@end

@! Invokes a 0-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn0(fn_ptr)
  return lipi_jit_call0(fn_ptr)
@end

@! Invokes a 1-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn1(fn_ptr, a1)
  return lipi_jit_call1(fn_ptr, a1)
@end

@! Invokes a 2-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn2(fn_ptr, a1, a2)
  return lipi_jit_call2(fn_ptr, a1, a2)
@end

@! Invokes a 3-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn3(fn_ptr, a1, a2, a3)
  return lipi_jit_call3(fn_ptr, a1, a2, a3)
@end

@! Invokes a 4-argument JIT-compiled function pointer in RAM
@fn jit_invoke_fn4(fn_ptr, a1, a2, a3, a4)
  return lipi_jit_call4(fn_ptr, a1, a2, a3, a4)
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
