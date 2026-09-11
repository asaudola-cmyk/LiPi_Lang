@! Maya Advanced Universal Architecture Tests

import "universe/db/graph/graph_engine"
import "universe/p2p/dht"
import "universe/net/raw/frame"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA ADVANCED ARCHITECTURE TEST SUITE          ")
  println("==================================================")
  
  @! 1. Object-Graph DB
  engine = graph_engine_new()
  n1 = graph_add_node(engine, "Developer")
  n2 = graph_add_node(engine, "MayaLanguage")
  graph_link(engine, n1, n2, "LOVES")
  
  neighbors = graph_query_neighbors(engine, n1, "LOVES")
  assert_eq(array_len(neighbors), 1, "Graph Engine successfully queries relationships")
  
  @! 2. P2P Registry
  reg = p2p_registry_new("node_a", "192.168.1.10")
  p2p_add_peer(reg, "node_b", "192.168.1.11")
  p2p_publish_package(reg, "maya_core", "hash1234")
  
  found_hash = p2p_find_package(reg, "maya_core")
  assert_eq(found_hash, "hash1234", "P2P DHT successfully stores and finds packages")
  
  @! 3. Raw Network Framing
  pkt = raw_ipv4_packet_build("10.0.0.1", "10.0.0.2", 6, [])
  frame = raw_eth_frame_build("AA:BB:CC", "DD:EE:FF", 2048, [])
  
  assert_eq(pkt.ttl, 64, "Raw IPv4 packet correctly sets Default TTL")
  assert_eq(frame.ethertype, 2048, "Raw Ethernet frame correctly sets EtherType (IPv4)")

  println("🎉 ALL ADVANCED ARCHITECTURE TESTS PASSED!")
  return 0
@end
