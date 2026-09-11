@! ============================================================================
@! MAYA UNIVERSE IoT — GATEWAY (universe/iot/gateway.maya)
@! 100% Pure Maya Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/string"
import "universe/iot/mqtt"
import "universe/iot/sensor"

@struct IoTGateway
  device_id: "",
  sensors: [],
  mqtt_host: "",
  mqtt_port: 0,
  message_queue: [],
  poll_count: 0,
  mqtt_client: 0
@end

@fn gateway_new(device_id, mqtt_host, mqtt_port)
  client = mqtt_connect(mqtt_host, mqtt_port, device_id)
  return {
    device_id: device_id,
    sensors: [],
    mqtt_host: mqtt_host,
    mqtt_port: mqtt_port,
    message_queue: [],
    poll_count: 0,
    mqtt_client: client
  }
@end

@fn gateway_register_sensor(gateway, sensor)
  @! Subscribe to sensor's command topic
  topic = "maya/iot/" + gateway.device_id + "/" + sensor.sensor_id + "/cmd"
  gateway.mqtt_client = mqtt_subscribe(gateway.mqtt_client, topic, 1)
  gateway.sensors = gateway.sensors.push(sensor)
  return gateway
@end

@fn gateway_poll_and_publish(gateway)
  @! Read all sensors and publish their values
  i = 0
  @while i < gateway.sensors.len()
    s = gateway.sensors[i]
    s = sensor_read(s)
    gateway.sensors[i] = s
    json_payload = sensor_to_json(s)
    topic = "maya/iot/" + gateway.device_id + "/" + s.sensor_id + "/data"
    gateway.mqtt_client = mqtt_publish(gateway.mqtt_client, topic, json_payload, 1)
    gateway.message_queue = gateway.message_queue.push(json_payload)
    i = i + 1
  @end
  gateway.poll_count = gateway.poll_count + 1
  return gateway
@end

@fn gateway_run_loop(gateway, iterations)
  i = 0
  @while i < iterations
    gateway = gateway_poll_and_publish(gateway)
    i = i + 1
  @end
  return gateway
@end

@fn gateway_get_sensor_value(gateway, sensor_id)
  n = gateway.sensors.len()
  @if n >= 1
    s0 = gateway.sensors[0]
    @if s0.sensor_id == sensor_id return sensor_get_value(s0) @end
  @end
  @if n >= 2
    s1 = gateway.sensors[1]
    @if s1.sensor_id == sensor_id return sensor_get_value(s1) @end
  @end
  @if n >= 3
    s2 = gateway.sensors[2]
    @if s2.sensor_id == sensor_id return sensor_get_value(s2) @end
  @end
  @if n >= 4
    s3 = gateway.sensors[3]
    @if s3.sensor_id == sensor_id return sensor_get_value(s3) @end
  @end
  return 0 - 1
@end
