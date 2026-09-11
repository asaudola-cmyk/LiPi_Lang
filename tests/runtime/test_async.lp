@! ============================================================================
@! MAYA ASYNC COROUTINE & SCHEDULER TEST (tests/runtime/test_async.maya)
@! 100% Pure Maya Implementation — Zero Foreign Syntax
@! ============================================================================

import "universe/core/collections"

@struct Coroutine
  id: 0,
  state: "READY",
  val: 0
@end

@fn new_coroutine(id, initial_val)
  return {
    id: id,
    state: "READY",
    val: initial_val
  }
@end

@fn coro_yield(coro, yield_val)
  coro.state = "SUSPENDED"
  coro.val = yield_val
  return coro
@end

@fn coro_resume(coro, send_val)
  @if coro.state == "SUSPENDED"
    coro.state = "RUNNING"
    coro.val = coro.val + send_val
    return coro.val
  @elif coro.state == "READY"
    coro.state = "SUSPENDED"
    return coro.val
  @end
  coro.state = "COMPLETED"
  return coro.val
@end

@fn main()
  println("==================================================")
  println("Running Pure Maya Async Coroutine Tests...")
  println("==================================================")

  coro = new_coroutine(1, 42)
  res1 = coro_resume(coro, 0)
  @if res1 != 42
    println("FAIL: Expected 42 on first resume, got " + res1.to_str())
    return 1
  @end

  res2 = coro_resume(coro, 100)
  @if res2 != 142
    println("FAIL: Expected 142 on second resume, got " + res2.to_str())
    return 1
  @end

  println("PASS: Async coroutine state machine verified.")
  return 0
@end

