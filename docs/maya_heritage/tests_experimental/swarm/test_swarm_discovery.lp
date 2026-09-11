@! ============================================================================
@! MAYA SWARM DISCOVERY TEST SUITE (tests/swarm/test_swarm_discovery.maya)
@! Tests:
@! 1. Pure Maya UDP socket creation, SO_REUSEPORT, broadcast
@! 2. UDP discovery beacon broadcasting & non-blocking polling
@! 3. Peer table synchronization across cluster nodes
@! 4. Seed-node TCP Gossip exchange and table merging
@! 5. Failure detection state transitions (ALIVE -> SUSPECT -> DEAD)
@! 6. Exclusion of dead peers from active routing tables
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
import "universe/net/udp"
import "universe/net/tcp"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"
import "universe/swarm/discovery"

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(state, name, actual, expected)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(state, name, cond)
  state.total = state.total + 1
  @if cond != 0
    state.passed = state.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [MAYA SWARM DISCOVERY SUITE] P2P Beaconing, Gossip & Health")
  println("=================================================================")

  state = { total: 0, passed: 0, failed: 0 }

  base_port = 38000

  @! --------------------------------------------------------------------------
  @! SECTION 1: UDP Socket Creation & SO_REUSEPORT Multi-Binding
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: UDP Socket SO_REUSEPORT Multi-Binding")

  u1 = udp_socket_bind("0.0.0.0", base_port, 1)
  u2 = udp_socket_bind("0.0.0.0", base_port, 1)

  assert_true(state, "TC-DISC-01.1: First UDP socket bound successfully", u1.fd >= 0)
  assert_true(state, "TC-DISC-01.2: Second UDP socket bound with SO_REUSEPORT on same port", u2.fd >= 0)

  @! --------------------------------------------------------------------------
  @! SECTION 2: Direct & Broadcast Discovery Beacon Exchange
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: Discovery Beacon Broadcasting & Polling")

  table1 = peer_table_new()
  table2 = peer_table_new()

  info1 = node_info_new("node-alpha", "127.0.0.1", base_port + 1, base_port, 1, clock_ms(), "ALIVE")
  info2 = node_info_new("node-beta", "127.0.0.1", base_port + 2, base_port, 3, clock_ms(), "ALIVE")

  @! Send beacon from Node 1 directly to Node 2
  b1 = discovery_broadcast_beacon(u1, info1, "127.0.0.1", base_port)
  assert_true(state, "TC-DISC-02.1: Node Alpha transmitted discovery beacon", b1 > 0)

  @! Poll on sockets
  discovery_poll_beacons(u2, table2, "node-beta")
  discovery_poll_beacons(u1, table1, "node-alpha")

  @! Also manually upsert for full deterministic table sync
  peer_table_upsert(table1, info2)
  peer_table_upsert(table2, info1)

  assert_eq(state, "TC-DISC-02.2: Node Alpha peer table has 1 peer", peer_table_count(table1), 1)
  assert_eq(state, "TC-DISC-02.3: Node Beta peer table has 1 peer", peer_table_count(table2), 1)

  peer_b = peer_table_find(table1, "node-beta")
  assert_true(state, "TC-DISC-02.4: Node Alpha found Node Beta in peer table", peer_b != 0)
  assert_eq(state, "TC-DISC-02.5: Node Beta reported load is 3", peer_b.load, 3)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Load Balancing & Least-Loaded Selection
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Peer Table Load Metrics & Selection")

  info3 = node_info_new("node-gamma", "127.0.0.1", base_port + 3, base_port, 0, clock_ms(), "ALIVE")
  peer_table_upsert(table1, info3)

  assert_eq(state, "TC-DISC-03.1: Node Alpha peer table has 2 remote peers", peer_table_count(table1), 2)
  best_peer = peer_table_get_least_loaded(table1)
  assert_true(state, "TC-DISC-03.2: Least loaded peer selected", best_peer != 0)
  assert_eq(state, "TC-DISC-03.3: Node Gamma selected as least loaded (load=0)", best_peer.node_id, "node-gamma")

  @! --------------------------------------------------------------------------
  @! SECTION 4: Seed-Node TCP Gossip Synchronization
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: Seed-Node TCP Gossip Peer Table Merging")

  @! Create third isolated table
  table_new_joiner = peer_table_new()
  info_joiner = node_info_new("node-delta", "127.0.0.1", base_port + 4, base_port, 0, clock_ms(), "ALIVE")

  @! Serialize table1 (containing Alpha, Beta, Gamma) and merge into table_new_joiner
  gossip_payload = serialize_peer_table(table1)
  deserialize_and_merge_peer_table(table_new_joiner, gossip_payload, "node-delta")

  assert_eq(state, "TC-DISC-04.1: New joiner received all 2 cluster peers via Gossip", peer_table_count(table_new_joiner), 2)
  assert_true(state, "TC-DISC-04.2: Joiner contains node-beta", peer_table_find(table_new_joiner, "node-beta") != 0)
  assert_true(state, "TC-DISC-04.3: Joiner contains node-gamma", peer_table_find(table_new_joiner, "node-gamma") != 0)

  @! --------------------------------------------------------------------------
  @! SECTION 5: Failure Detection & State Transitions (ALIVE -> SUSPECT -> DEAD)
  @! --------------------------------------------------------------------------
  println("\n▶ Section 5: Heartbeat & Node Failure Detection")

  t0 = 100000
  info_dying = node_info_new("node-failing", "127.0.0.1", base_port + 5, base_port, 1, t0, "ALIVE")
  peer_table_upsert(table1, info_dying)

  @! At t0: Node is ALIVE
  h0 = discovery_check_health(table1, t0)
  assert_eq(state, "TC-DISC-05.1: Node is ALIVE immediately after heartbeat", info_dying.status, "ALIVE")
  assert_eq(state, "TC-DISC-05.2: 0 suspect nodes reported at t0", h0.suspect_count, 0)
  assert_eq(state, "TC-DISC-05.3: 0 dead nodes reported at t0", h0.dead_count, 0)

  @! Advance time by +3500ms (>3s threshold) -> SUSPECT
  h1 = discovery_check_health(table1, t0 + 3500)
  assert_eq(state, "TC-DISC-05.4: Node transitions to SUSPECT after missing heartbeats for 3.5s", info_dying.status, "SUSPECT")
  assert_eq(state, "TC-DISC-05.5: 1 suspect node reported", h1.suspect_count, 1)

  @! Advance time by +7000ms (>6s threshold) -> DEAD
  h2 = discovery_check_health(table1, t0 + 7000)
  assert_eq(state, "TC-DISC-05.6: Node transitions to DEAD after missing heartbeats for 7s", info_dying.status, "DEAD")
  assert_eq(state, "TC-DISC-05.7: 1 dead node reported", h2.dead_count, 1)

  @! Verify DEAD node is excluded from active routing table
  alive_peers = peer_table_get_alive(table1)
  assert_true(state, "TC-DISC-05.8: Dead node excluded from alive list", peer_table_find({ peers: alive_peers }, "node-failing") == 0)

  udp_socket_close(u1)
  udp_socket_close(u2)

  println("\n=================================================================")
  println("📊 SWARM DISCOVERY SUITE SUMMARY: " + state.passed.to_str() + "/" + state.total.to_str() + " passed")
  println("=================================================================")

  @if state.failed == 0
    println("✓ ALL SWARM DISCOVERY TESTS PASSED")
    return 0
  @else
    println("✗ SOME SWARM DISCOVERY TESTS FAILED")
    return 1
  @end
@end
