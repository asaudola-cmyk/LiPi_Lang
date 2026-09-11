@! ============================================================================
@! MAYA RUNTIME ASYNC: STACKFUL COROUTINE ENGINE
@! Module: runtime/async/coroutine
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@enum CoroutineState
  Created = 0
  Running = 1
  Suspended = 2
  Completed = 3
  Panicked = 4
@end

@struct CoroutineValue
  kind: i64,
  int_val: i64,
  str_val: string
@end

@struct CoroutineContext
  rsp: i64,
  rbp: i64,
  rbx: i64,
  r12: i64,
  r13: i64,
  r14: i64,
  r15: i64
@end

@struct Coroutine
  id: i64,
  state: i64,
  stack_size: i64,
  parent_id: i64,
  context: CoroutineContext
@end

@struct CoroutineRegistry
  coroutines: array,
  next_id: i64,
  current_coro_id: i64
@end

@fn coroutine_registry_new() -> CoroutineRegistry
  return CoroutineRegistry {
    coroutines: [],
    next_id: 1,
    current_coro_id: 0
  }
@end

@fn create_coroutine(reg: CoroutineRegistry, stack_size: i64) -> CoroutineRegistry
  id = reg.next_id
  reg.next_id = reg.next_id + 1

  ctx = CoroutineContext {
    rsp: 0,
    rbp: 0,
    rbx: 0,
    r12: 0,
    r13: 0,
    r14: 0,
    r15: 0
  }

  coro = Coroutine {
    id: id,
    state: 0, @! Created
    stack_size: stack_size,
    parent_id: 0,
    context: ctx
  }

  reg.coroutines = reg.coroutines.push(coro)
  return reg
@end

@fn coro_resume(coro: Coroutine) -> Coroutine
  @if coro.state == 3 || coro.state == 4
    return coro
  @end
  coro.state = 1 @! Running
  return coro
@end

@fn coro_yield(coro: Coroutine) -> Coroutine
  coro.state = 2 @! Suspended
  return coro
@end

@fn coro_complete(coro: Coroutine) -> Coroutine
  coro.state = 3 @! Completed
  return coro
@end
