import "universe/core/concurrency"

@fn sys_nanosleep(req, rem)
  return syscall(35, req, rem, 0, 0, 0, 0)
@end

@fn sleep_ms(ms)
  @! timespec struct size is 16 bytes: [sec: 8 bytes, nsec: 8 bytes]
  @! However, we don't have struct allocation for C structures easily.
  @! We can allocate a small array or string? Or just use raw pointers.
  return 0
@end

@fn atomic_add(ptr, val)
  @! Calling our syscall 999 which routes to __atomic_fetch_add
  return syscall(999, ptr, val, 0, 0, 0, 0)
@end

@fn worker(args_ptr)
  @! arguments might be a pointer to a struct or just an integer.
  @! In this test, let's just make args_ptr the address of our shared counter!
  atomic_add(args_ptr, 1)
  return 0
@end

@fn sys_wait4(pid, status_ptr, options, rusage_ptr)
  return syscall(61, pid, status_ptr, options, rusage_ptr, 0, 0)
@end

@fn main()
  @! Allocate 8 bytes for our shared counter
  shared_ptr = sys_mmap(0, 8, 3, 33, 0 - 1, 0) @! PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS
  
  @! Initialize to 0
  atomic_add(shared_ptr, 0 - syscall(999, shared_ptr, 0, 0,0,0,0)) @! actually just set to 0. It is 0 by mmap anyway.
  
  println("Spawning 1000 Maya Threads...")
  
  pids = [0]
  i = 0
  @while i < 1000
    pid = maya_spawn(worker, shared_ptr)
    pids = pids.push(pid)
    i = i + 1
  @end
  
  println("Waiting for threads to finish...")
  
  @! wait for all threads
  i = 0
  @while i < 1000
    pid = pids[i + 1]
    sys_wait4(pid, 0, 0, 0)
    i = i + 1
  @end
  
  final_val = syscall(999, shared_ptr, 0, 0, 0, 0, 0)
  
  @if final_val == 1000
    println("SUCCESS: Atomic counter is 1000!")
  @else
    println("FAILURE: Atomic counter is not 1000")
    println(final_val)
    return 1
  @end
  
  return 0
@end
