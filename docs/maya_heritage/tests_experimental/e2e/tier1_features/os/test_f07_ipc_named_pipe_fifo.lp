@! ============================================================================
@! MAYA E2E TIER 1 — F07.1: Inter-Process Pipe / FIFO Data Transfer
@! File: tests/e2e/tier1_features/os/test_f07_ipc_named_pipe_fifo.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F07.1: IPC Pipe Data Transfer")

  pipefds = [0, 0]
  sys_pipe(pipefds)

  payload = "MAYA_IPC_PIPE_PAYLOAD"
  sys_write(pipefds[1], payload, payload.len())

  buf = maya_alloc(32)
  n = sys_read(pipefds[0], buf, 32)
  assert_eq(n, payload.len(), "Read matches written byte length")
  assert_str_eq(maya_str_new(buf), payload, "Pipe string payload verified")

  sys_close(pipefds[0])
  sys_close(pipefds[1])

  println("✓ PASS: F07.1 IPC Pipe Data Transfer")
  return 0
@end
