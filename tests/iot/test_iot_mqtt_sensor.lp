import "universe/iot/mqtt"
import "universe/iot/sensor"

@fn main()
  println("--- IoT MQTT & Sensor Test Suite ---")

  // 1. MQTT Client Lifecycle
  client = mqtt_connect("127.0.0.1", 1883, "lipi_sensor_node_01")
  @if client.connected != 1
    println("FAIL: mqtt_connect")
    return 1
  @end
  println("PASS: mqtt_connect")

  // 2. MQTT Publish with real byte payload
  client = mqtt_publish(client, "telemetry/temp", "DATA_XYZ", 0)
  last_pkt = client.sent_packets[len(client.sent_packets) - 1]
  
  // Verify last bytes in the packet correspond to "DATA_XYZ": 'D'=68, 'A'=65, 'T'=84, 'A'=65, '_'=95, 'X'=88, 'Y'=89, 'Z'=90
  pkt_len = len(last_pkt)
  @if last_pkt[pkt_len - 1] != 90 || last_pkt[pkt_len - 2] != 89 || last_pkt[pkt_len - 3] != 88
    println("FAIL: mqtt_publish byte encoding")
    return 1
  @end
  println("PASS: mqtt_publish real payload byte encoding")

  // 3. MQTT Subscribe
  client = mqtt_subscribe(client, "telemetry/commands", 1)
  @if len(client.topics) != 1
    println("FAIL: mqtt_subscribe")
    return 1
  @end
  println("PASS: mqtt_subscribe")

  // 4. MQTT Disconnect
  client = mqtt_disconnect(client)
  @if client.connected != 0
    println("FAIL: mqtt_disconnect")
    return 1
  @end
  println("PASS: mqtt_disconnect")

  // 5. Sensor Abstraction
  s_temp = sensor_new("th_01", "temperature", "C")
  s_temp = sensor_read(s_temp)
  @if sensor_is_in_range(s_temp) != 1
    println("FAIL: sensor_read temperature range")
    return 1
  @end
  println("PASS: sensor_read temperature")

  s_hum = sensor_new("hum_01", "humidity", "%")
  s_hum = sensor_read(s_hum)
  @if sensor_is_in_range(s_hum) != 1
    println("FAIL: sensor_read humidity range")
    return 1
  @end
  println("PASS: sensor_read humidity")

  // 6. Sensor Calibration & JSON Export
  s_cal = sensor_calibrate(s_temp, 5)
  json = sensor_to_json(s_cal)
  @if len(json) == 0
    println("FAIL: sensor_to_json")
    return 1
  @end
  println("PASS: sensor_to_json")

  println("=== ALL IOT MQTT & SENSOR TESTS PASSED ===")
  return 0
@end
