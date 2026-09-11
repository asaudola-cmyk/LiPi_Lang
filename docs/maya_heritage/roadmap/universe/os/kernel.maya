@! ============================================================================
@! MAYA UNIVERSE OS - MICROKERNEL & PROCESS MANAGER
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! Represents a Thread in Maya OS
@fn thread_new(id, entry_func)
  return {
    id: id,
    state: "READY", @! READY, RUNNING, BLOCKED, DEAD
    priority: 1,
    program_counter: entry_func,
    stack: [],
    registers: {}
  }
@end

@! Represents a Process
@fn process_new(pid, name)
  return {
    pid: pid,
    name: name,
    threads: [],
    memory_pages: [],
    open_files: [],
    state: "ALIVE"
  }
@end

@! The OS Kernel State
@fn kernel_new()
  return {
    processes: [],
    ready_queue: [],
    blocked_queue: [],
    current_thread: 0,
    time_slice: 10, @! ms per thread
    tick_count: 0
  }
@end

@! Create and start a new process
@fn kernel_spawn_process(kernel, name, main_func)
  pid = kernel.processes.len() + 1
  proc = process_new(pid, name)
  
  main_thread = thread_new(pid * 1000, main_func)
  proc.threads = proc.threads.push(main_thread)
  
  kernel.processes = kernel.processes.push(proc)
  kernel.ready_queue = kernel.ready_queue.push(main_thread)
  
  return kernel
@end

@! Context Switch
@fn kernel_schedule(kernel)
  @if kernel.ready_queue.len() == 0
    @! System Idle
    return kernel
  @end
  
  @! Preempt current thread
  @if kernel.current_thread != 0
    @if kernel.current_thread.state == "RUNNING"
      kernel.current_thread.state = "READY"
      kernel.ready_queue = kernel.ready_queue.push(kernel.current_thread)
    @end
  @end
  
  @! Pop next thread from ready queue
  next_thread = kernel.ready_queue[0]
  new_queue = []
  q_i = 1
  @while q_i < kernel.ready_queue.len()
    new_queue = new_queue.push(kernel.ready_queue[q_i])
    q_i = q_i + 1
  @end
  kernel.ready_queue = new_queue
  
  next_thread.state = "RUNNING"
  kernel.current_thread = next_thread
  
  @! Load registers and resume...
  return kernel
@end

@! Interrupt Timer Tick
@fn kernel_tick(kernel)
  kernel.tick_count = kernel.tick_count + 1
  @if kernel.tick_count % kernel.time_slice == 0
    kernel = kernel_schedule(kernel)
  @end
  return kernel
@end
