@! ============================================================================
@! MAYA SWARM — P2P DISCOVERY & CLUSTER FORMATION (universe/swarm/discovery.maya)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! UDP Broadcast Beacons (SO_REUSEPORT), TCP Gossip, Heartbeat & Failure Detector
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
import "universe/net/udp"
import "universe/net/tcp"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"

@! ----------------------------------------------------------------------------
@! 1. Peer Table Data Structure & Management
@! ----------------------------------------------------------------------------

@struct PeerTable
  peers: array
@end

@fn peer_table_new()
  return { peers: [] }
@end

@fn peer_table_upsert(table, info)
  i = 0
  num_items = table.peers.len()
  found = 0
  @while i < num_items
    p = table.peers[i]
    @if p.node_id == info.node_id
      p.host = info.host
      p.tcp_port = info.tcp_port
      p.udp_port = info.udp_port
      p.load = info.load
      p.last_seen = info.last_seen
      p.status = info.status
      found = 1
    @end
    i = i + 1
  @end
  @if found == 0
    table.peers.push(info)
  @end
  return table
@end

@fn peer_table_find(table, node_id)
  i = 0
  num_items = table.peers.len()
  @while i < num_items
    p = table.peers[i]
    @if p.node_id == node_id
      return p
    @end
    i = i + 1
  @end
  return 0
@end

@fn peer_table_remove(table, node_id)
  new_peers = []
  i = 0
  num_items = table.peers.len()
  @while i < num_items
    p = table.peers[i]
    @if p.node_id != node_id
      new_peers.push(p)
    @end
    i = i + 1
  @end
  table.peers = new_peers
  return table
@end

@fn peer_table_get_alive(table)
  alive = []
  i = 0
  num_items = table.peers.len()
  @while i < num_items
    p = table.peers[i]
    @if p.status == "ALIVE"
      alive.push(p)
    @end
    i = i + 1
  @end
  return alive
@end

@fn peer_table_get_least_loaded(table)
  alive = peer_table_get_alive(table)
  @if alive.len() == 0 return 0 @end

  best = alive[0]
  i = 1
  @while i < alive.len()
    p = alive[i]
    @if p.load < best.load
      best = p
    @end
    i = i + 1
  @end
  return best
@end

@fn peer_table_count(table)
  return table.peers.len()
@end

@fn peer_table_to_array(table)
  return table.peers
@end

@! ----------------------------------------------------------------------------
@! 2. Heartbeat & Failure Detection (SUSPECT > 3s, DEAD > 6s)
@! ----------------------------------------------------------------------------

@struct HealthReport
  suspect_count: i64
  dead_count: i64
@end

@fn discovery_check_health(table, now_ms)
  suspect_count = 0
  dead_count = 0
  i = 0
  num_items = table.peers.len()
  @while i < num_items
    p = table.peers[i]
    @if p.status != "DEAD"
      diff = now_ms - p.last_seen
      @if diff > 6000
        p.status = "DEAD"
        dead_count = dead_count + 1
      @elif diff > 3000
        p.status = "SUSPECT"
        suspect_count = suspect_count + 1
      @end
    @end
    i = i + 1
  @end
  return { suspect_count: suspect_count, dead_count: dead_count }
@end

@! ----------------------------------------------------------------------------
@! 3. Peer Table Serialization & Gossip Table Merging
@! ----------------------------------------------------------------------------

@fn serialize_peer_table(table)
  res = "["
  i = 0
  num_items = table.peers.len()
  @while i < num_items
    @if i > 0 res = res + "," @end
    res = res + serialize_node_info(table.peers[i])
    i = i + 1
  @end
  return res + "]"
@end

@fn deserialize_and_merge_peer_table(table, json_str, local_node_id)
  tokens = swarm_json_tokenize(json_str)
  i = 0
  num_items = tokens.len()
  @if i < num_items && tokens[i].tok_type == "LBRACKET"
    i = i + 1
  @end

  @while i < num_items && tokens[i].tok_type != "RBRACKET"
    @if tokens[i].tok_type == "LBRACE"
      obj_tokens = []
      depth = 0
      @while i < num_items
        tok = tokens[i]
        obj_tokens.push(tok)
        @if tok.tok_type == "LBRACE" depth = depth + 1 @end
        @if tok.tok_type == "RBRACE"
          depth = depth - 1
          @if depth == 0
            i = i + 1
            break
          @end
        @end
        i = i + 1
      @end

      entries = parse_json_object(obj_tokens)
      node_id = json_get_str(entries, "node_id")
      @if node_id != "" && node_id != local_node_id
        host = json_get_str(entries, "host")
        tcp_port = json_get_num(entries, "tcp_port")
        udp_port = json_get_num(entries, "udp_port")
        load = json_get_num(entries, "load")
        last_seen = json_get_num(entries, "last_seen")
        status = json_get_str(entries, "status")
        @if status == "" status = "ALIVE" @end
        info = node_info_new(node_id, host, tcp_port, udp_port, load, last_seen, status)
        peer_table_upsert(table, info)
      @end
    @elif tokens[i].tok_type == "COMMA"
      i = i + 1
    @else
      i = i + 1
    @end
  @end
  return table
@end

@! ----------------------------------------------------------------------------
@! 4. UDP Beacon Broadcasting & Polling
@! ----------------------------------------------------------------------------

@fn discovery_broadcast_beacon(udp_sock, info, bcast_host, discovery_port)
  @if udp_sock.fd < 0 return -1 @end
  payload = serialize_node_info(info)
  return protocol_send_udp(udp_sock.fd, bcast_host, discovery_port, MSG_BEACON(), payload)
@end

@fn discovery_poll_beacons(udp_sock, table, local_node_id)
  @if udp_sock.fd < 0 return 0 @end
  res = protocol_recv_udp_nonblocking(udp_sock.fd)
  @if res.packet.valid == 1 && res.packet.msg_type == MSG_BEACON()
    peer_info = deserialize_node_info(res.packet.payload)
    @if peer_info.node_id != "" && peer_info.node_id != local_node_id
      peer_info.last_seen = clock_ms()
      peer_info.status = "ALIVE"
      @if peer_info.host == "" || peer_info.host == "0.0.0.0"
        peer_info.host = res.sender_host
      @end
      peer_table_upsert(table, peer_info)
      return 1
    @end
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. Seed-Node TCP Gossip Exchange
@! ----------------------------------------------------------------------------

@fn discovery_gossip_exchange(table, local_info, seed_host, seed_port)
  stream = tcp_stream_connect(seed_host, seed_port)
  @if stream.fd < 0 return -1 @end

  @! Send MSG_GOSSIP_REQ with our local peer table
  local_table_str = serialize_peer_table(table)
  protocol_send_tcp(stream.fd, MSG_GOSSIP_REQ(), local_table_str)

  @! Receive MSG_GOSSIP_RESP with remote peer table
  resp_pkt = protocol_recv_tcp(stream.fd)
  tcp_stream_close(stream)

  @if resp_pkt.valid == 1 && resp_pkt.msg_type == MSG_GOSSIP_RESP()
    deserialize_and_merge_peer_table(table, resp_pkt.payload, local_info.node_id)
    return 1
  @end

  return 0
@end
