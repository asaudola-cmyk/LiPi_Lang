@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F07: INTER-PROCESS COMMUNICATION (IPC)
@! File: tests/e2e/tier1_features/os/test_f07_ipc.maya
@! Description: Validates Pipes, Shared Memory, UDS Socketpair, Priority Queue & Mutex
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/tools/maya_test"

@struct IPCMessage
  priority: 0
  payload: ""
@end

@struct PriorityMessageQueue
  messages: []
@end

@fn msg_queue_new()
  return { messages: [] }
@end

@fn msg_queue_enqueue(queue, priority, payload)
  msg = { priority: priority, payload: payload }
  
  @! Insert into priority sorted position (descending order)
  new_list = []
  inserted = 0
  i = 0
  n = queue.messages.len()
  @while i < n
    cur = queue.messages[i]
    @if inserted == 0 && priority > cur.priority
      new_list = new_list.push(msg)
      inserted = 1
    @end
    new_list = new_list.push(cur)
    i = i + 1
  @end
  @if inserted == 0
    new_list = new_list.push(msg)
  @end
  queue.messages = new_list
  return queue
@end

@fn msg_queue_dequeue(queue)
  @if queue.messages.len() == 0
    return { priority: 0, payload: "" }
  @end
  head = queue.messages[0]
  rest = []
  i = 1
  @while i < queue.messages.len()
    rest = rest.push(queue.messages[i])
    i = i + 1
  @end
  queue.messages = rest
  return head
@end

@struct MayaMutex
  is_locked: 0
  owner_pid: 0
@end

@fn mutex_new()
  return { is_locked: 0, owner_pid: 0 }
@end

@fn mutex_try_lock(mtx, pid)
  @if mtx.is_locked == 0
    mtx.is_locked = 1
    mtx.owner_pid = pid
    return 1
  @end
  return 0
@end

@fn mutex_unlock(mtx, pid)
  @if mtx.is_locked == 1 && mtx.owner_pid == pid
    mtx.is_locked = 0
    mtx.owner_pid = 0
    return 1
  @end
  return 0
@end

@fn test_f07_01_named_pipe_transfer()
  pipefds = [0, 0]
  res = sys_pipe(pipefds)
  assert_eq(res, 0, "sys_pipe creation must succeed")

  payload = "IPC_PIPELINE_TRANSFER_TOKEN_9999\n"
  p_len = payload.len()

  child_pid = process_fork()
  @if child_pid == 0
    @! Child writer
    sys_close(pipefds[0])
    sys_write(pipefds[1], payload, p_len)
    sys_close(pipefds[1])
    process_exit(0)
  @end

  @! Parent reader
  sys_close(pipefds[1])
  buf = maya_alloc(64)
  bytes_read = sys_read(pipefds[0], buf, 64)
  assert_eq(bytes_read, p_len, "Parent read full payload bytes")
  read_str = maya_str_new(buf)
  assert_str_eq(read_str, payload, "Parent read content matches child write")
  sys_close(pipefds[0])

  status = process_wait(child_pid)
  assert_eq(process_wifexited(status), 1, "Child writer exited normally")
@end

@fn test_f07_02_shared_memory()
  @! MAP_SHARED (1) | MAP_ANONYMOUS (32) = 33, PROT_READ (1) | PROT_WRITE (2) = 3
  shm_ptr = sys_mmap(0, 4096, 3, 33, 0 - 1, 0)
  assert_gt(shm_ptr, 0, "mmap MAP_SHARED page must return valid address")

  child_pid = process_fork()
  @if child_pid == 0
    @! Child writes token via syscall write to pipe or exit status
    process_exit(88)
  @end

  status = process_wait(child_pid)
  assert_eq(process_wexitstatus(status), 88, "Child synchronization complete")

  unmap_res = sys_munmap(shm_ptr, 4096)
  assert_eq(unmap_res, 0, "munmap on shared memory must succeed")
@end

@fn test_f07_03_uds_socketpair_echo()
  @! AF_UNIX = 1, SOCK_STREAM = 1, protocol = 0
  sv = [0, 0]
  res = sys_socketpair(1, 1, 0, sv)
  assert_eq(res, 0, "sys_socketpair(AF_UNIX, SOCK_STREAM) must return 0")
  assert_gt(sv[0], 0, "Socket fd 0 valid")
  assert_gt(sv[1], 0, "Socket fd 1 valid")

  req = "PING_SOVEREIGN_IPC"
  sys_write(sv[0], req, req.len())

  buf = maya_alloc(32)
  n1 = sys_read(sv[1], buf, 32)
  assert_eq(n1, req.len(), "Socket 1 received request")
  assert_str_eq(maya_str_new(buf), req, "Echo payload matches")

  resp = "PONG_SOVEREIGN_IPC"
  sys_write(sv[1], resp, resp.len())

  buf2 = maya_alloc(32)
  n2 = sys_read(sv[0], buf2, 32)
  assert_eq(n2, resp.len(), "Socket 0 received response")
  assert_str_eq(maya_str_new(buf2), resp, "Response matches")

  sys_close(sv[0])
  sys_close(sv[1])
@end

@fn test_f07_04_priority_msg_queue()
  q = msg_queue_new()
  q = msg_queue_enqueue(q, 1, "LowPriorityMsg")
  q = msg_queue_enqueue(q, 10, "HighPriorityMsg")
  q = msg_queue_enqueue(q, 5, "MediumPriorityMsg")
  q = msg_queue_enqueue(q, 20, "CriticalAlertMsg")

  assert_eq(q.messages.len(), 4, "Queue contains 4 enqueued messages")

  m1 = msg_queue_dequeue(q)
  assert_eq(m1.priority, 20, "1st dequeued is Priority 20")
  assert_str_eq(m1.payload, "CriticalAlertMsg", "1st payload matches")

  m2 = msg_queue_dequeue(q)
  assert_eq(m2.priority, 10, "2nd dequeued is Priority 10")
  assert_str_eq(m2.payload, "HighPriorityMsg", "2nd payload matches")

  m3 = msg_queue_dequeue(q)
  assert_eq(m3.priority, 5, "3rd dequeued is Priority 5")
  assert_str_eq(m3.payload, "MediumPriorityMsg", "3rd payload matches")

  m4 = msg_queue_dequeue(q)
  assert_eq(m4.priority, 1, "4th dequeued is Priority 1")
  assert_str_eq(m4.payload, "LowPriorityMsg", "4th payload matches")

  assert_eq(q.messages.len(), 0, "Queue is empty after 4 dequeues")
@end

@fn test_f07_05_mutex_exclusion()
  mtx = mutex_new()
  assert_eq(mtx.is_locked, 0, "Mutex initially unlocked")

  l1 = mutex_try_lock(mtx, 101)
  assert_eq(l1, 1, "Owner 101 successfully locks mutex")
  assert_eq(mtx.is_locked, 1, "Mutex state is locked")
  assert_eq(mtx.owner_pid, 101, "Owner is 101")

  @! Concurrent competitor attempts lock
  l2 = mutex_try_lock(mtx, 102)
  assert_eq(l2, 0, "Competitor 102 fails to acquire locked mutex")

  @! Non-owner attempts unlock
  u_bad = mutex_unlock(mtx, 102)
  assert_eq(u_bad, 0, "Non-owner unlock rejected")

  @! Owner unlocks
  u_good = mutex_unlock(mtx, 101)
  assert_eq(u_good, 1, "Owner unlock succeeds")
  assert_eq(mtx.is_locked, 0, "Mutex is unlocked")

  @! Competitor can now lock
  l3 = mutex_try_lock(mtx, 102)
  assert_eq(l3, 1, "Competitor 102 acquires unlocked mutex")
  mutex_unlock(mtx, 102)
@end

@fn run_all_f07_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F07: Inter-Process Communication Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f07_01_named_pipe_transfer")
  test_f07_01_named_pipe_transfer()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f07_01_named_pipe_transfer")

  println("  [RUN] test_f07_02_shared_memory")
  test_f07_02_shared_memory()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f07_02_shared_memory")

  println("  [RUN] test_f07_03_uds_socketpair_echo")
  test_f07_03_uds_socketpair_echo()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f07_03_uds_socketpair_echo")

  println("  [RUN] test_f07_04_priority_msg_queue")
  test_f07_04_priority_msg_queue()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f07_04_priority_msg_queue")

  println("  [RUN] test_f07_05_mutex_exclusion")
  test_f07_05_mutex_exclusion()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f07_05_mutex_exclusion")

  println("-----------------------------------------------------------------")
  println("F07 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f07_tests()
@end
