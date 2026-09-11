@! ============================================================================
@! MAYA UNIVERSE - OS-INDEPENDENT RAW NETWORK STACK
@! Bypasses OS socket layer to build raw Ethernet/IP packets directly in memory
@! ============================================================================

import "universe/core/collections"

@struct EthFrame
  dest_mac: string
  src_mac: string
  ethertype: i64
  payload: array
@end

@struct IPv4Packet
  src_ip: string
  dest_ip: string
  protocol: i64
  ttl: i64
  payload: array
@end

@fn raw_eth_frame_build(dest, src, type_val, payload_data)
  return {
    dest_mac: dest,
    src_mac: src,
    ethertype: type_val,
    payload: payload_data
  }
@end

@fn raw_ipv4_packet_build(src_ip, dest_ip, proto, data)
  return {
    src_ip: src_ip,
    dest_ip: dest_ip,
    protocol: proto,
    ttl: 64,
    payload: data
  }
@end
