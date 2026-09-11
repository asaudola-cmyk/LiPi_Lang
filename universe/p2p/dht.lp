@! ============================================================================
@! MAYA UNIVERSE - DECENTRALIZED P2P PACKAGE REGISTRY (DHT)
@! Replaces central servers with a peer-to-peer Distributed Hash Table
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct Peer
  id: string
  ip: string
@end

@struct P2PRegistry
  local_peer: Peer
  routing_table: array
  packages: array
@end

@struct PackageRecord
  name: string
  hash: string
  provider_peer_id: string
@end

@fn p2p_registry_new(local_id, local_ip)
  peer = { id: local_id, ip: local_ip }
  return { local_peer: peer, routing_table: [], packages: [] }
@end

@fn p2p_add_peer(registry, peer_id, ip)
  p = { id: peer_id, ip: ip }
  array_push(registry.routing_table, p)
  return 1
@end

@fn p2p_publish_package(registry, pkg_name, pkg_hash)
  record = { name: pkg_name, hash: pkg_hash, provider_peer_id: registry.local_peer.id }
  array_push(registry.packages, record)
  return 1
@end

@fn p2p_find_package(registry, pkg_name)
  i = 0
  n = array_len(registry.packages)
  @while i < n
    record = array_get(registry.packages, i)
    @if record.name == pkg_name
      return record.hash
    @end
    i = i + 1
  @end
  return ""
@end
