import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/thread"

@fn child_task(id)
  i = 0
  @while i < 5
    @if id == 1 string_println("Thread 1: Working...") @end
    @if id == 2 string_println("Thread 2: Working...") @end
    thread_sleep_ms(100)
    i = i + 1
  @end
  
  @if id == 1 string_println("Thread 1: Done!") @end
  @if id == 2 string_println("Thread 2: Done!") @end
  
  thread_exit()
@end

@fn main()
  string_println("=== Native Maya Multithreading ===")
  
  tid1 = thread_spawn()
  @if tid1 == 0
    @! Child thread 1
    child_task(1)
  @end
  
  tid2 = thread_spawn()
  @if tid2 == 0
    @! Child thread 2
    child_task(2)
  @end
  
  @! Main thread
  string_println("Main thread waiting for children...")
  thread_sleep_ms(700)
  string_println("Main thread exiting.")
  
  sys_syscall(231, 0, 0, 0, 0, 0, 0) @! exit_group to kill all threads just in case
@end
