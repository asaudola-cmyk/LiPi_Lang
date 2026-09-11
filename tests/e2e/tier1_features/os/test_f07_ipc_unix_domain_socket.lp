@! ============================================================================
@! MAYA E2E TIER 1 — F07.3: Unix Domain Socket Echo Roundtrip
@! File: tests/e2e/tier1_features/os/test_f07_ipc_unix_domain_socket.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F07.3: UDS Echo Roundtrip")

  sv = [0, 0]
  res = sys_socketpair(1, 1, 0, sv)
  assert_eq(res, 0, "sys_socketpair succeeded")

  req = "ECHO_PING_123"
  sys_write(sv[0], req, req.len())

  buf = maya_alloc(32)
  n = sys_read(sv[1], buf, 32)
  assert_eq(n, req.len(), "Echo read full length")
  assert_str_eq(maya_str_new(buf), req, "Echo content matched")

  sys_close(sv[0])
  sys_close(sv[1])

  println("✓ PASS: F07.3 UDS Echo Roundtrip")
  return 0
@end
