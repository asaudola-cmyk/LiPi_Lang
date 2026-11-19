@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — NETWORKING
@! Module: utso/net/p2p_gossip.lp
@! Features: Epidemic Gossip Protocol for Decentralized P2P Networks
@! ============================================================================

import "utso/core/string"
import "utso/core/collections"
import "utso/net/udp"

@struct GossipMessage
  msg_id: string
  sender_id: string
  payload: string
  ttl: i64
@end

@struct GossipNode
  node_id: string
  peers: array
  seen_messages: array
  port: i64
@end

@fn gossip_node_new(node_id: string, port: i64) -> GossipNode
  return {
    node_id: node_id,
    peers: [],
    seen_messages: [],
    port: port
  }
@end

@fn gossip_add_peer(node: GossipNode, peer_address: string) -> GossipNode
  node.peers = node.peers.push(peer_address)
  return node
@end

@fn _has_seen_message(node: GossipNode, msg_id: string) -> i64
  i = 0
  @while i < node.seen_messages.len()
    @if node.seen_messages[i] == msg_id
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@! Broadcast a message to random subset of peers (Gossip dissemination)
@fn gossip_broadcast(node: GossipNode, payload: string, ttl: i64) -> GossipNode
  msg_id = node.node_id + "_" + payload @! Unique ID generation simplified
  
  @if _has_seen_message(node, msg_id) == 1
    return node
  @end
  
  node.seen_messages = node.seen_messages.push(msg_id)
  
  @! In a real system, we'd select a random subset (fanout). Here we broadcast to all known peers
  i = 0
  @while i < node.peers.len()
    peer = node.peers[i]
    _send_gossip_udp(peer, msg_id, node.node_id, payload, ttl - 1)
    i = i + 1
  @end
  
  return node
@end

@! Handle incoming gossip message
@fn gossip_receive(node: GossipNode, msg_id: string, sender: string, payload: string, ttl: i64) -> GossipNode
  @if _has_seen_message(node, msg_id) == 1
    @! Already seen, ignore (prevents infinite loops)
    return node
  @end
  
  @! Process message
  node.seen_messages = node.seen_messages.push(msg_id)
  
  @! Propagate further if TTL > 0
  @if ttl > 0
    i = 0
    @while i < node.peers.len()
      peer = node.peers[i]
      @! Don't send back to the sender
      @if peer != sender
        _send_gossip_udp(peer, msg_id, node.node_id, payload, ttl - 1)
      @end
      i = i + 1
    @end
  @end
  
  return node
@end

@struct GossipEndpoint
  host: string
  port: i64
@end

@fn _gossip_parse_target(target: string) -> GossipEndpoint
  tlen = target.len()
  colon_pos = 0 - 1
  i = 0
  @while i < tlen
    @if char_at(target, i) == ":"
      colon_pos = i
      @break
    @end
    i = i + 1
  @end
  @if colon_pos > 0 && colon_pos + 1 < tlen
    h = str_sub(target, 0, colon_pos)
    p = to_int(str_sub(target, colon_pos + 1, tlen))
    @if p <= 0 p = 9000 @end
    return { host: h, port: p }
  @end
  @if tlen > 0
    return { host: target, port: 9000 }
  @end
  return { host: "127.0.0.1", port: 9000 }
@end

@! Real UDP datagram gossip frame transmission via utso/net/udp
@fn _send_gossip_udp(target: string, msg_id: string, sender: string, payload: string, ttl: i64) -> i64
  ep = _gossip_parse_target(target)
  wire = "GOSSIP|" + msg_id + "|" + sender + "|" + to_str(ttl) + "|" + payload
  fd = udp_socket_new()
  @if fd < 0 return 0 - 1 @end
  sent = udp_send_to(fd, ep.host, ep.port, wire)
  udp_close(fd)
  return sent
@end
