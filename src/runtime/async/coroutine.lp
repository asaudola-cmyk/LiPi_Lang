// ============================================================================
// 👑 LIPI RUNTIME ASYNC: STACKFUL COROUTINE ENGINE
// Module: src/runtime/async/coroutine.lp
// 100% Pure LiPi Implementation — Direct Silicon Concurrency
// ============================================================================
// WHY: Stackful coroutines allow lightweight user-space execution contexts
// with distinct register state and stack segments. This engine provides
// explicit context lifecycle tracking (Created, Running, Suspended, Completed, Panicked)
// and centralized registry coordination for fiber and task schedulers.



// ── Coroutine Lifecycle States ───────────────────────────────────────────────
CORO_CREATED   = 0
CORO_RUNNING   = 1
CORO_SUSPENDED = 2
CORO_COMPLETED = 3
CORO_PANICKED  = 4

// ── Boxed Coroutine Value ───────────────────────────────────────────────────
struct CoroutineValue
  kind: i64
  int_val: i64
  str_val: string
end

// ── Saved CPU Context Registers (x86_64 Callee-Saved ABI) ───────────────────
struct CoroutineContext
  rsp: i64
  rbp: i64
  rbx: i64
  r12: i64
  r13: i64
  r14: i64
  r15: i64
end

// ── Coroutine Instance Descriptor ───────────────────────────────────────────
struct Coroutine
  id: i64
  state: i64
  stack_size: i64
  parent_id: i64
  context: CoroutineContext
end

// ── Coroutine Registry ──────────────────────────────────────────────────────
struct CoroutineRegistry
  coroutines: array
  next_id: i64
  current_coro_id: i64
end

// Allocates and initializes a new empty coroutine registry.
fn coroutine_registry_new() -> CoroutineRegistry
  return CoroutineRegistry([], 1, 0)
end

// Spawns a new coroutine with specified stack size and registers it into the pool.
fn create_coroutine(reg: CoroutineRegistry, stack_size: i64) -> CoroutineRegistry
  id = reg.next_id
  reg.next_id = reg.next_id + 1

  ctx = CoroutineContext(0, 0, 0, 0, 0, 0, 0)
  coro = Coroutine(id, CORO_CREATED, stack_size, 0, ctx)

  reg.coroutines = reg.coroutines.push(coro)
  return reg
end

// Transitions a coroutine to running state, guarding against completed or panicked states.
fn coro_resume(coro: Coroutine) -> Coroutine
  if coro.state == CORO_COMPLETED or coro.state == CORO_PANICKED
    return coro
  end
  coro.state = CORO_RUNNING
  return coro
end

// Suspends an active coroutine.
fn coro_yield(coro: Coroutine) -> Coroutine
  coro.state = CORO_SUSPENDED
  return coro
end

// Marks a coroutine as successfully finished.
fn coro_complete(coro: Coroutine) -> Coroutine
  coro.state = CORO_COMPLETED
  return coro
end
