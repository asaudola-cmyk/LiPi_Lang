@! ============================================================================
@! MAYA OS KERNEL — PROCESS SCHEDULER & CONTEXT SWITCHING (scheduler.my)
@! 100% Written in Pure Maya Language — Multitasking Kernel Scheduler
@! ============================================================================

@! Process State Constants:
@! 0 = READY, 1 = RUNNING, 2 = BLOCKED, 3 = TERMINATED

@fn create_task(task_id, name, entry_point, stack_size)
  return {
    id: task_id,
    name: name,
    state: 0, @! READY
    rip: entry_point,
    rsp: 0x800000 + (task_id * stack_size),
    rax: 0,
    rbx: 0,
    rcx: 0,
    rdx: 0,
    rsi: 0,
    rdi: 0,
    rflags: 0x202, @! Interrupts enabled
    priority: 10,
    time_slice_ticks: 20
  }
@end

@fn scheduler_init()
  return {
    tasks: [],
    current_index: 0,
    ticks: 0
  }
@end

@fn scheduler_add_task(sched, task)
  new_tasks = sched.tasks.push(task)
  return {
    tasks: new_tasks,
    current_index: sched.current_index,
    ticks: sched.ticks
  }
@end

@! Round-Robin Next Task Selector
@fn scheduler_schedule_next(sched)
  @if sched.tasks.len() == 0
    return { next_task: 0, sched: sched }
  @end
  
  next_idx = (sched.current_index + 1) % sched.tasks.len()
  next_task = sched.tasks[next_idx]
  
  return {
    next_task: next_task,
    sched: {
      tasks: sched.tasks,
      current_index: next_idx,
      ticks: sched.ticks + 1
    }
  }
@end
