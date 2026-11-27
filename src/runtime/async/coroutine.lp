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

// ============================================================================
// ⚡ REAL HARDWARE STACKFUL FIBER ENGINE (Strict W^X AMD64 Context Switching)
// ============================================================================
// WHY: Replaces state-only simulation with true user-space register & stack
// switching (`rbx, rbp, r12..r15, rsp, rip`) over private SYS_mmap stacks,
// enabling real suspend/resume coroutines & epoll-driven async I/O with 0% libc.
//
// Raw Fiber Descriptor Layout (160 bytes via SYS_mmap):
//   [+0..+63]   fiber_ctx  (rsp, rbp, rbx, r12, r13, r14, r15, rip)
//   [+64..+127] parent_ctx (caller's saved registers on resume)
//   [+128]      stack_base
//   [+136]      stack_size
//   [+144]      state (0=CREATED, 1=RUNNING, 2=SUSPENDED, 3=COMPLETED)
//   [+152]      yield_or_return_val

G_CORO_SILICON_PAGE = 0
G_CORO_ACTIVE_FIBER = 0

fn _coro_write_bytes(page: i64, off: i64, arr: array) -> i64
  i = 0
  n = len(arr)
  while i < n
    mem_byte_write(page, off + i, get(arr, i))
    i = i + 1
  end
  return off + n
end

fn coro_init_silicon_trampoline() -> i64
  if G_CORO_SILICON_PAGE > 0
    return G_CORO_SILICON_PAGE
  end
  page = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
  if page <= 0
    return 0
  end
  // +0: fiber_context_switch(rdi=old_ctx, rsi=new_ctx) — 69 bytes
  // Saves callee-saved GPRs + caller RIP + caller RSP into old_ctx, loads new_ctx, jumps to new RIP.
  _coro_write_bytes(page, 0, [
    72, 137, 111, 8,         // mov [rdi+8], rbp
    72, 137, 95, 16,         // mov [rdi+16], rbx
    76, 137, 103, 24,        // mov [rdi+24], r12
    76, 137, 111, 32,        // mov [rdi+32], r13
    76, 137, 119, 40,        // mov [rdi+40], r14
    76, 137, 127, 48,        // mov [rdi+48], r15
    72, 139, 4, 36,          // mov rax, [rsp]
    72, 137, 71, 56,         // mov [rdi+56], rax
    72, 141, 68, 36, 8,      // lea rax, [rsp+8]
    72, 137, 7,              // mov [rdi+0], rax
    72, 139, 110, 8,         // mov rbp, [rsi+8]
    72, 139, 94, 16,         // mov rbx, [rsi+16]
    76, 139, 102, 24,        // mov r12, [rsi+24]
    76, 139, 110, 32,        // mov r13, [rsi+32]
    76, 139, 118, 40,        // mov r14, [rsi+40]
    76, 139, 126, 48,        // mov r15, [rsi+48]
    72, 139, 38,             // mov rsp, [rsi+0]
    255, 102, 56             // jmp qword [rsi+56]
  ])
  // +96: fiber_entry_trampoline (r12=fn_ptr, r13=user_arg, r14=fiber_desc, r15=on_exit_fn) — 18 bytes
  // RSP is 16B-aligned on entry so `call r12` obeys System V AMD64 ABI (`rsp % 16 == 8` at callee entry).
  _coro_write_bytes(page, 96, [
    76, 137, 239,            // mov rdi, r13 (user_arg)
    76, 137, 246,            // mov rsi, r14 (fiber_desc)
    65, 255, 212,            // call r12
    76, 137, 247,            // mov rdi, r14 (fiber_desc)
    72, 137, 198,            // mov rsi, rax (return value)
    65, 255, 231             // jmp r15 (_coro_on_fiber_exit)
  ])
  // Strict W^X transition: RW -> RX (PROT_READ | PROT_EXEC = 5)
  if syscall(10, page, 4096, 5, 0, 0, 0) < 0
    syscall(11, page, 4096, 0, 0, 0, 0)
    return 0
  end
  G_CORO_SILICON_PAGE = page
  return page
end

fn fiber_context_switch(old_ctx: i64, new_ctx: i64) -> i64
  pg = coro_init_silicon_trampoline()
  if pg <= 0
    return 0 - 1
  end
  return pg(old_ctx, new_ctx)
end

fn _coro_on_fiber_exit(fiber_desc: i64, ret_val: i64) -> i64
  mem_write(fiber_desc, 144, CORO_COMPLETED)
  mem_write(fiber_desc, 152, ret_val)
  G_CORO_ACTIVE_FIBER = 0
  // Switch permanently back to parent_ctx at fiber_desc + 64
  fiber_context_switch(fiber_desc, fiber_desc + 64)
  return 0
end

// Raw Fiber Descriptor Layout (4096 bytes via SYS_mmap):
//   [+0..+63]    fiber_ctx  (rsp, rbp, rbx, r12, r13, r14, r15, rip)
//   [+64..+127]  parent_ctx (caller's saved registers on resume)
//   [+128]       stack_base
//   [+136]       stack_size
//   [+144]       state (0=CREATED, 1=RUNNING, 2=SUSPENDED, 3=COMPLETED)
//   [+152]       yield_or_return_val
//   [+160]       gc_sched (AsyncSched* from _lipi_async_get_sched)
//   [+256..+415] gc_node (160B FUTR-layout GC root descriptor for suspended fiber stack)
//   [+512..+671] parent_node (160B FUTR-layout GC root descriptor for suspended parent stack)
//   [+768..+927] ctx_node (160B FUTR-layout GC root descriptor scanning [+0..+160) saved regs)

fn _coro_gc_unlink_node(sched: i64, target: i64) -> i64
  if sched <= 0 or target <= 0
    return 0
  end
  head = mem_read(sched, 56)
  if head == target
    mem_write(sched, 56, mem_read(target, 136))
    mem_write(target, 136, 0)
    return 1
  end
  prev = head
  while prev != 0
    nxt = mem_read(prev, 136)
    if nxt == target
      mem_write(prev, 136, mem_read(target, 136))
      mem_write(target, 136, 0)
      return 1
    end
    prev = nxt
  end
  return 0
end

fn coro_spawn_fiber(entry_fn_ptr: i64, user_arg: i64, stack_size: i64) -> i64
  // WHY: Allocates a real 16-byte-aligned private fiber stack with a 4KB PROT_NONE guard page
  // + 4KB FiberDesc via SYS_mmap, primes initial register state, and registers GC stack-root
  // descriptors on `_lipi_async_get_sched()->all_live_head` so `gc_collect()` is 100% safe
  // inside fibers, across nested resumes, and while fibers are suspended.
  pg = coro_init_silicon_trampoline()
  if pg <= 0 or entry_fn_ptr <= 0
    return 0
  end
  ssz = stack_size
  if ssz < 65536
    ssz = 65536
  end
  // Round up to 4KB page multiple
  if (ssz % 4096) != 0
    ssz = ((ssz / 4096) + 1) * 4096
  end
  desc = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
  if desc <= 0
    return 0
  end
  stk = syscall(9, 0, ssz, 3, 34, 0 - 1, 0)
  if stk <= 0
    syscall(11, desc, 4096, 0, 0, 0, 0)
    return 0
  end
  // Bottom 4KB PROT_NONE guard page (matches runtime_async.lp and _lipi_gc_collect's +4096 skip)
  syscall(10, stk, 4096, 0, 0, 0, 0)
  // Top of stack aligned strictly to 16 bytes (reserve 32B safety margin)
  top = ((stk + ssz - 32) / 16) * 16
  mem_write(desc, 0, top)                        // rsp
  mem_write(desc, 8, 0)                          // rbp
  mem_write(desc, 16, 0)                         // rbx
  mem_write(desc, 24, entry_fn_ptr)              // r12
  mem_write(desc, 32, user_arg)                  // r13
  mem_write(desc, 40, desc)                      // r14
  mem_write(desc, 48, fn_ptr(_coro_on_fiber_exit)) // r15
  mem_write(desc, 56, pg + 96)                   // rip = fiber_entry_trampoline
  mem_write(desc, 128, stk)
  mem_write(desc, 136, ssz)
  mem_write(desc, 144, CORO_CREATED)
  mem_write(desc, 152, 0)

  // Register GC stack/register root scan descriptors on runtime AsyncSched->all_live_head ([sched+56])
  sched = _lipi_async_get_sched()
  mem_write(desc, 160, sched)
  if sched > 0
    gc_node = desc + 256
    parent_node = desc + 512
    ctx_node = desc + 768
    // gc_node: scans suspended fiber stack [saved_rsp .. stk + ssz) when state == 2
    mem_write(gc_node, 8, 2)
    mem_write(gc_node, 16, top)
    mem_write(gc_node, 24, stk)
    mem_write(gc_node, 32, ssz)
    // parent_node: scans suspended caller stack while fiber is actively running (state 3 = inactive now)
    mem_write(parent_node, 8, 3)
    mem_write(parent_node, 16, 0)
    mem_write(parent_node, 24, 0)
    mem_write(parent_node, 32, 0)
    // ctx_node: scans [desc+0 .. desc+160) so callee-saved regs (rbx/r12..r15) & yield val stay GC-rooted
    mem_write(ctx_node, 8, 2)
    mem_write(ctx_node, 16, desc)
    mem_write(ctx_node, 24, desc - 4096)
    mem_write(ctx_node, 32, 4096 + 160)
    // Push all 3 nodes onto sched->all_live_head
    old_head = mem_read(sched, 56)
    mem_write(gc_node, 136, old_head)
    mem_write(parent_node, 136, gc_node)
    mem_write(ctx_node, 136, parent_node)
    mem_write(sched, 56, ctx_node)
  end
  return desc
end

fn coro_resume_fiber(fiber_desc: i64) -> i64
  // WHY: Suspends caller into parent_ctx and resumes stackful fiber until it yields or finishes,
  // switching `_lipi_stack_bottom` ([slab+80]) to the fiber's stack top and marking the caller's
  // stack live on `sched->all_live_head` so `gc_collect()` inside the fiber never crosses unmapped gaps.
  if fiber_desc <= 0
    return 0
  end
  st = mem_read(fiber_desc, 144)
  if st == CORO_COMPLETED or st == CORO_PANICKED or st == CORO_RUNNING
    return mem_read(fiber_desc, 152)
  end
  stk = mem_read(fiber_desc, 128)
  ssz = mem_read(fiber_desc, 136)
  slab = _lipi_slab_buckets_ptr()
  parent_sb = mem_read(slab, 80)
  parent_rsp = stack_pointer()
  gc_node = fiber_desc + 256
  parent_node = fiber_desc + 512

  // Expose suspended caller stack [parent_rsp .. parent_sb) to GC while fiber runs
  if parent_rsp > 4104 and parent_rsp < parent_sb and (parent_sb - parent_rsp) <= 16777216
    p_base = parent_rsp - 4104
    mem_write(parent_node, 24, p_base)
    mem_write(parent_node, 32, parent_sb - p_base)
    mem_write(parent_node, 16, parent_rsp)
    mem_write(parent_node, 8, 2)
  end
  // Mark fiber's gc_node inactive (3) since fiber is about to be the active live stack
  mem_write(gc_node, 8, 3)
  // Switch runtime _lipi_stack_bottom to this fiber's exact stack top
  if stk > 0 and ssz > 0
    mem_write(slab, 80, stk + ssz)
  end

  prev_active = G_CORO_ACTIVE_FIBER
  G_CORO_ACTIVE_FIBER = fiber_desc
  mem_write(fiber_desc, 144, CORO_RUNNING)
  // WHY: Guard fiber_context_switch with try/catch so if the fiber throws an uncaught
  // exception that unwinds out of the fiber stack, `_lipi_stack_bottom` ([slab+80]),
  // `G_CORO_ACTIVE_FIBER`, and GC stack-chain nodes are ALWAYS restored before rethrowing.
  try
    fiber_context_switch(fiber_desc + 64, fiber_desc)
  catch f_err
    G_CORO_ACTIVE_FIBER = prev_active
    mem_write(slab, 80, parent_sb)
    mem_write(parent_node, 8, 3)
    mem_write(gc_node, 8, 3)
    mem_write(fiber_desc, 144, CORO_PANICKED)
    throw f_err
  end
  G_CORO_ACTIVE_FIBER = prev_active

  // Immediately restore caller's _lipi_stack_bottom and deactivate parent_node
  mem_write(slab, 80, parent_sb)
  mem_write(parent_node, 8, 3)
  // If fiber suspended (not finished), keep its stack live for any GC run in the caller
  new_st = mem_read(fiber_desc, 144)
  if new_st == CORO_SUSPENDED
    mem_write(gc_node, 16, mem_read(fiber_desc, 0))
    mem_write(gc_node, 8, 2)
  else
    mem_write(gc_node, 8, 3)
  end
  return mem_read(fiber_desc, 152)
end

fn coro_yield_value(val: i64) -> i64
  // WHY: Suspends the currently running fiber, returning `val` to the caller of `coro_resume_fiber`.
  fiber_desc = G_CORO_ACTIVE_FIBER
  if fiber_desc <= 0
    return val
  end
  mem_write(fiber_desc, 144, CORO_SUSPENDED)
  mem_write(fiber_desc, 152, val)
  fiber_context_switch(fiber_desc, fiber_desc + 64)
  return mem_read(fiber_desc, 152)
end

fn coro_fiber_state(fiber_desc: i64) -> i64
  if fiber_desc <= 0 return CORO_COMPLETED end
  return mem_read(fiber_desc, 144)
end

fn coro_destroy_fiber(fiber_desc: i64) -> i64
  if fiber_desc <= 0 return 0 end
  gc_node = fiber_desc + 256
  parent_node = fiber_desc + 512
  ctx_node = fiber_desc + 768
  mem_write(gc_node, 8, 3)
  mem_write(parent_node, 8, 3)
  mem_write(ctx_node, 8, 3)
  sched = mem_read(fiber_desc, 160)
  if sched > 0
    _coro_gc_unlink_node(sched, ctx_node)
    _coro_gc_unlink_node(sched, parent_node)
    _coro_gc_unlink_node(sched, gc_node)
  end
  stk = mem_read(fiber_desc, 128)
  ssz = mem_read(fiber_desc, 136)
  if stk > 0 and ssz > 0
    syscall(11, stk, ssz, 0, 0, 0, 0)
  end
  syscall(11, fiber_desc, 4096, 0, 0, 0, 0)
  return 1
end
