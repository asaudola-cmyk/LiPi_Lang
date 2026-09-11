@! ============================================================================
@! LIPI UNIVERSE IoT — MQTT CLIENT (universe/iot/mqtt.maya)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Implements: MQTT 3.1.1 wire protocol simulation (CONNECT/PUBLISH/SUBSCRIBE)
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@struct MqttClient
  host: "",
  port: 0,
  client_id: "",
  topics: [],
  connected: 0,
  packet_id: 1,
  sent_packets: [],
  recv_buf: []
@end

@fn mqtt_client_new(host, port, client_id)
  return {
    host: host,
    port: port,
    client_id: client_id,
    topics: [],
    connected: 0,
    packet_id: 1,
    sent_packets: [],
    recv_buf: []
  }
@end

@fn mqtt_encode_remaining_len(val)
  @if val == 0
    return [0]
  @end
  @if val < 128
    r0 = val % 128
    return [r0]
  @end
  @if val < 16384
    r0 = (val % 128) + 128
    r1 = (val / 128) % 128
    return [r0, r1]
  @end
  r0 = (val % 128) + 128
  r1 = ((val / 128) % 128) + 128
  r2 = (val / 16384) % 128
  return [r0, r1, r2]
@end

@fn mqtt_encode_utf8_len(s)
  @! Returns 2-byte length prefix for MQTT UTF-8 string
  n = str_len(s)
  hi = (n / 256) % 256
  lo = n % 256
  return [hi, lo]
@end

@fn mqtt_encode_utf8(s)
  @! 2-byte length prefix + string byte count (simplified for Maya)
  n = str_len(s)
  hi = (n / 256) % 256
  lo = n % 256
  @! We encode just the length prefix + approximate bytes (ASCII assumed)
  @! Full byte-level encoding avoided due to Maya interpreter char limitations
  result = [hi, lo]
  @! Push n placeholder bytes (value 65 = 'A') as size reservation
  @! Real MQTT brokers use the actual string bytes, but for wire-size calculation this is correct
  i = 0
  @while i < n
    result = result.push(65)
    i = i + 1
  @end
  return result
@end

@fn mqtt_build_connect(client)
  @! MQTT CONNECT packet (type 1)
  @! Fixed header: type=1, flags=0
  @! Variable header: protocol name "MQTT", level 4, flags, keepalive
  protocol = [0, 4, 77, 81, 84, 84, 4, 2, 0, 60] @! "MQTT" L4 CleanSession keepalive=60
  cid_bytes = mqtt_encode_utf8(client.client_id)
  payload_len = cid_bytes.len()
  rem_len = 10 + payload_len
  packet = [16]
  rem = mqtt_encode_remaining_len(rem_len)
  i = 0
  @while i < rem.len()
    packet = packet.push(rem[i])
    i = i + 1
  @end
  j = 0
  @while j < protocol.len()
    packet = packet.push(protocol[j])
    j = j + 1
  @end
  k = 0
  @while k < cid_bytes.len()
    packet = packet.push(cid_bytes[k])
    k = k + 1
  @end
  return packet
@end

@fn mqtt_connect(host, port, client_id)
  client = mqtt_client_new(host, port, client_id)
  pkt = mqtt_build_connect(client)
  client.sent_packets = client.sent_packets.push(pkt)
  @! Simulate CONNACK response [0x20, 0x02, 0x00, 0x00] = Connection Accepted
  client.recv_buf = [32, 2, 0, 0]
  @! Check CONNACK: byte[0]=0x20, byte[2]=0 (session present=0), byte[3]=0 (accepted)
  @if client.recv_buf[0] == 32 && client.recv_buf[3] == 0
    client.connected = 1
  @end
  return client
@end

@fn mqtt_publish(client, topic, payload, qos)
  @! MQTT PUBLISH packet (type 3)
  topic_bytes = mqtt_encode_utf8(topic)
  payload_len = str_len(payload)
  rem_len = topic_bytes.len() + payload_len
  @if qos > 0
    rem_len = rem_len + 2 @! packet ID for QoS 1/2
  @end
  fixed_byte = 48 @! type=3, dup=0, qos=0, retain=0
  @if qos == 1 fixed_byte = 50 @end
  packet = [fixed_byte]
  rem = mqtt_encode_remaining_len(rem_len)
  i = 0
  @while i < rem.len()
    packet = packet.push(rem[i])
    i = i + 1
  @end
  j = 0
  @while j < topic_bytes.len()
    packet = packet.push(topic_bytes[j])
    j = j + 1
  @end
  @if qos > 0
    pid = client.packet_id & 65535
    packet = packet.push((pid / 256) & 255)
    packet = packet.push(pid & 255)
    client.packet_id = client.packet_id + 1
  @end
  payload_i = 0
  @while payload_i < payload_len
    packet = packet.push(65)
    payload_i = payload_i + 1
  @end
  client.sent_packets = client.sent_packets.push(packet)
  return client
@end

@fn mqtt_subscribe(client, topic, qos)
  @! MQTT SUBSCRIBE packet (type 8)
  topic_bytes = mqtt_encode_utf8(topic)
  rem_len = 2 + topic_bytes.len() + 1 @! pid + topic + qos byte
  pid = client.packet_id & 65535
  client.packet_id = client.packet_id + 1
  packet = [130]
  rem = mqtt_encode_remaining_len(rem_len)
  i = 0
  @while i < rem.len()
    packet = packet.push(rem[i])
    i = i + 1
  @end
  packet = packet.push((pid / 256) & 255)
  packet = packet.push(pid & 255)
  j = 0
  @while j < topic_bytes.len()
    packet = packet.push(topic_bytes[j])
    j = j + 1
  @end
  packet = packet.push(qos & 3)
  client.topics = client.topics.push(topic)
  client.sent_packets = client.sent_packets.push(packet)
  return client
@end

@fn mqtt_disconnect(client)
  @! MQTT DISCONNECT packet (type 14) = [0xE0, 0x00]
  packet = [224, 0]
  client.sent_packets = client.sent_packets.push(packet)
  client.connected = 0
  return client
@end
