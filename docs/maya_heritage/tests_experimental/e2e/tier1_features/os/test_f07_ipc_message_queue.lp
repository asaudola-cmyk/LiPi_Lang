@! ============================================================================
@! MAYA E2E TIER 1 — F07.4: Priority IPC Message Queue
@! File: tests/e2e/tier1_features/os/test_f07_ipc_message_queue.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f07_ipc"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F07.4: Priority Message Queue")

  q = msg_queue_new()
  q = msg_queue_enqueue(q, 1, "Low")
  q = msg_queue_enqueue(q, 10, "High")
  q = msg_queue_enqueue(q, 5, "Med")

  m1 = msg_queue_dequeue(q)
  assert_eq(m1.priority, 10, "Highest priority dequeued first")
  assert_str_eq(m1.payload, "High", "Payload matches High")

  println("✓ PASS: F07.4 Priority Message Queue")
  return 0
@end
