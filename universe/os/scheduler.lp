@! ============================================================================
@! LIPI COROUTINE & TASK SCHEDULER — universe/os/scheduler.lp
@! 100% Pure Lipi Implementation — Zero C / Libc Dependencies
@! Features: TCB, x86-64 Context Save, Round-Robin & 3-Tier MLFQ Scheduler
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. Constants & Task States
@! ----------------------------------------------------------------------------

@fn TASK_STATE_READY() return 0 @end
@fn TASK_STATE_RUNNING() return 1 @end
@fn TASK_STATE_BLOCKED() return 2 @end
@fn TASK_STATE_TERMINATED() return 3 @end
@fn TASK_STATE_YIELDED() return 4 @end

@fn SCHED_MODE_ROUND_ROBIN() return 0 @end
@fn SCHED_MODE_MLFQ() return 1 @end

@fn MLFQ_Q0_QUANTUM() return 10 @end
@fn MLFQ_Q1_QUANTUM() return 20 @end
@fn MLFQ_Q2_QUANTUM() return 40 @end
@fn MLFQ_STARVATION_BOOST() return 100 @end

@! ----------------------------------------------------------------------------
@! 2. Task Control Block (TCB) & Context Helpers
@! ----------------------------------------------------------------------------

@fn tcb_create_context(entry_point, stack_top)
  return {
    rip: entry_point,
    rsp: stack_top,
    rbp: stack_top,
    rax: 0,
    rbx: 0,
    rcx: 0,
    rdx: 0,
    rsi: 0,
    rdi: 0,
    r8: 0,
    r9: 0,
    r10: 0,
    r11: 0,
    r12: 0,
    r13: 0,
    r14: 0,
    r15: 0,
    rflags: 514 @! 0x202 (IF bit enabled)
  }
@end

@fn tcb_new(id, name, entry_point, stack_size, priority)
  quantum = 10
  @if priority == 1
    quantum = 20
  @elif priority >= 2
    quantum = 40
  @end
  
  stack_base = 1048576 * (id + 1) @! Virtual stack offset
  stack_top = stack_base + stack_size
  
  return {
    id: id,
    name: name,
    state: 0, @! TASK_STATE_READY
    priority: priority,
    base_priority: priority,
    time_slice: quantum,
    quantum_remaining: quantum,
    total_ticks_run: 0,
    voluntary_yields_count: 0,
    preemptions_count: 0,
    sleep_until_tick: 0 - 1,
    block_reason: "",
    stack_base: stack_base,
    stack_size: stack_size,
    context: tcb_create_context(entry_point, stack_top)
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Scheduler Engine Initialization
@! ----------------------------------------------------------------------------

@fn scheduler_init(mode)
  return {
    mode: mode,
    current_task_id: 0 - 1,
    next_task_id: 1,
    tasks: [],
    system_ticks: 0,
    last_boost_tick: 0,
    total_context_switches: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Task Creation & Registration
@! ----------------------------------------------------------------------------

@fn scheduler_create_task(sched, name, entry_point, stack_size, priority)
  tid = sched.next_task_id
  task = tcb_new(tid, name, entry_point, stack_size, priority)
  
  sched.tasks = sched.tasks.push(task)
  sched.next_task_id = tid + 1
  
  @if sched.current_task_id < 0
    sched.current_task_id = tid
    sched.tasks[sched.tasks.len() - 1].state = 1 @! RUNNING
  @end
  
  return tid
@end

@! ----------------------------------------------------------------------------
@! 5. Scheduler Selection & Context Switch
@! ----------------------------------------------------------------------------

@fn scheduler_schedule_next(sched)
  num_tasks = sched.tasks.len()
  @if num_tasks == 0 return 0 - 1 @end
  
  @! Unblock sleeping tasks whose sleep timer expired
  t = 0
  @while t < num_tasks
    task = sched.tasks[t]
    @if task.state == 2 && task.sleep_until_tick >= 0 && sched.system_ticks >= task.sleep_until_tick
      task.state = 0 @! READY
      task.sleep_until_tick = 0 - 1
      task.block_reason = ""
    @end
    t = t + 1
  @end
  
  @! Check Anti-Starvation Boost for MLFQ
  @if sched.mode == 1
    @if sched.system_ticks - sched.last_boost_tick >= 100
      sched.last_boost_tick = sched.system_ticks
      b = 0
      @while b < num_tasks
        btask = sched.tasks[b]
        @if btask.state != 3 @! Not terminated
          btask.priority = 0
          btask.quantum_remaining = 10
          btask.time_slice = 10
        @end
        b = b + 1
      @end
    @end
  @end
  
  @! Find best next ready task
  best_idx = 0 - 1
  
  @if sched.mode == 1 @! MLFQ (Priority 0 > Priority 1 > Priority 2)
    p = 0
    @while p <= 2
      idx = 0
      @while idx < num_tasks
        tsk = sched.tasks[idx]
        @if (tsk.state == 0 || tsk.state == 4) && tsk.priority == p
          best_idx = idx
          break
        @end
        idx = idx + 1
      @end
      @if best_idx >= 0
        break
      @end
      p = p + 1
    @end
  @else @! Round-Robin
    curr_idx = 0 - 1
    i = 0
    @while i < num_tasks
      @if sched.tasks[i].id == sched.current_task_id
        curr_idx = i
        break
      @end
      i = i + 1
    @end
    
    step = 1
    @while step <= num_tasks
      check_idx = (curr_idx + step) % num_tasks
      tsk = sched.tasks[check_idx]
      @if tsk.state == 0 || tsk.state == 4
        best_idx = check_idx
        break
      @end
      step = step + 1
    @end
  @end
  
  @if best_idx >= 0
    next_task = sched.tasks[best_idx]
    
    @! Save previous running task
    @if sched.current_task_id >= 0
      c = 0
      @while c < num_tasks
        @if sched.tasks[c].id == sched.current_task_id
          @if sched.tasks[c].state == 1
            sched.tasks[c].state = 0 @! Set back to READY
          @end
          break
        @end
        c = c + 1
      @end
    @end
    
    sched.current_task_id = next_task.id
    next_task.state = 1 @! RUNNING
    sched.total_context_switches = sched.total_context_switches + 1
    return next_task.id
  @end
  
  return 0 - 1
@end

@! ----------------------------------------------------------------------------
@! 6. Scheduler Tick & Timer Preemption
@! ----------------------------------------------------------------------------

@fn scheduler_tick(sched)
  sched.system_ticks = sched.system_ticks + 1
  num_tasks = sched.tasks.len()
  
  @! Account ticks for currently running task
  @if sched.current_task_id >= 0
    i = 0
    @while i < num_tasks
      task = sched.tasks[i]
      @if task.id == sched.current_task_id && task.state == 1
        task.total_ticks_run = task.total_ticks_run + 1
        task.quantum_remaining = task.quantum_remaining - 1
        
        @! Quantum expired: Demote in MLFQ and trigger preemption
        @if task.quantum_remaining <= 0
          task.preemptions_count = task.preemptions_count + 1
          @if sched.mode == 1
            @if task.priority < 2
              task.priority = task.priority + 1
            @end
            @if task.priority == 1
              task.time_slice = 20
              task.quantum_remaining = 20
            @else
              task.time_slice = 40
              task.quantum_remaining = 40
            @end
          @else
            task.quantum_remaining = task.time_slice
          @end
          task.state = 0 @! READY
          scheduler_schedule_next(sched)
        @end
        break
      @end
      i = i + 1
    @end
  @end
  
  return sched.system_ticks
@end

@! ----------------------------------------------------------------------------
@! 7. Cooperative Yield, Sleep & Lifecycle Control
@! ----------------------------------------------------------------------------

@fn scheduler_yield(sched)
  @if sched.current_task_id < 0 return 0 @end
  
  i = 0
  num = sched.tasks.len()
  @while i < num
    task = sched.tasks[i]
    @if task.id == sched.current_task_id
      task.voluntary_yields_count = task.voluntary_yields_count + 1
      task.state = 4 @! YIELDED (retains priority level)
      break
    @end
    i = i + 1
  @end
  
  return scheduler_schedule_next(sched)
@end

@fn scheduler_sleep(sched, ticks)
  @if sched.current_task_id < 0 return 0 @end
  
  i = 0
  num = sched.tasks.len()
  @while i < num
    task = sched.tasks[i]
    @if task.id == sched.current_task_id
      task.state = 2 @! BLOCKED
      task.sleep_until_tick = sched.system_ticks + ticks
      task.block_reason = "timer_sleep"
      break
    @end
    i = i + 1
  @end
  
  return scheduler_schedule_next(sched)
@end

@fn scheduler_block_task(sched, task_id, reason)
  i = 0
  num = sched.tasks.len()
  @while i < num
    task = sched.tasks[i]
    @if task.id == task_id
      task.state = 2 @! BLOCKED
      task.block_reason = reason
      @if task_id == sched.current_task_id
        scheduler_schedule_next(sched)
      @end
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn scheduler_unblock_task(sched, task_id)
  i = 0
  num = sched.tasks.len()
  @while i < num
    task = sched.tasks[i]
    @if task.id == task_id
      @if task.state == 2
        task.state = 0 @! READY
        task.block_reason = ""
        return 1
      @end
    @end
    i = i + 1
  @end
  return 0
@end

@fn scheduler_terminate_task(sched, task_id)
  i = 0
  num = sched.tasks.len()
  @while i < num
    task = sched.tasks[i]
    @if task.id == task_id
      task.state = 3 @! TERMINATED
      @if task_id == sched.current_task_id
        scheduler_schedule_next(sched)
      @end
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn scheduler_get_task(sched, task_id)
  i = 0
  num = sched.tasks.len()
  @while i < num
    @if sched.tasks[i].id == task_id
      return sched.tasks[i]
    @end
    i = i + 1
  @end
  return 0
@end

@fn scheduler_metrics(sched)
  ready_cnt = 0
  running_cnt = 0
  blocked_cnt = 0
  term_cnt = 0
  
  i = 0
  num = sched.tasks.len()
  @while i < num
    st = sched.tasks[i].state
    @if st == 0 || st == 4
      ready_cnt = ready_cnt + 1
    @elif st == 1
      running_cnt = running_cnt + 1
    @elif st == 2
      blocked_cnt = blocked_cnt + 1
    @elif st == 3
      term_cnt = term_cnt + 1
    @end
    i = i + 1
  @end
  
  return {
    total_tasks: num,
    ready: ready_cnt,
    running: running_cnt,
    blocked: blocked_cnt,
    terminated: term_cnt,
    system_ticks: sched.system_ticks,
    context_switches: sched.total_context_switches
  }
@end
