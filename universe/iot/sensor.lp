@! ============================================================================
@! LIPI UNIVERSE IoT — SENSOR ABSTRACTION (universe/iot/sensor.lp)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Simulates: Temperature, Humidity, Pressure sensors with calibration
@! ============================================================================

import "universe/core/string"
import "universe/core/math"

@struct Sensor
  sensor_id: "",
  sensor_type: "",
  unit: "",
  raw_value: 0,
  offset: 0,
  scale: 1,
  min_val: 0,
  max_val: 100,
  sample_count: 0,
  last_timestamp: 0
@end

@fn sensor_new(id, sensor_type, unit)
  min_v = 0
  max_v = 100
  @if sensor_type == "temperature"
    min_v = 0 - 40
    max_v = 125
  @end
  @if sensor_type == "humidity"
    min_v = 0
    max_v = 100
  @end
  @if sensor_type == "pressure"
    min_v = 30000
    max_v = 110000
  @end
  return {
    sensor_id: id,
    sensor_type: sensor_type,
    unit: unit,
    raw_value: 0,
    offset: 0,
    scale: 1,
    min_val: min_v,
    max_val: max_v,
    sample_count: 0,
    last_timestamp: 0
  }
@end

@fn sensor_read(sensor)
  @! Simulate sensor reading with realistic values
  base = 0
  @if sensor.sensor_type == "temperature"
    @! Returns value in range 20-30°C (simulated drift)
    base = 250 @! 25.0°C × 10
    drift = (sensor.sample_count * 3) % 50 @! ±5°C drift
    @if drift > 25 drift = drift - 50 @end
    base = base + drift
  @end
  @if sensor.sensor_type == "humidity"
    base = 550 @! 55.0% × 10
    noise = (sensor.sample_count * 7) % 200 @! ±20% range
    @if noise > 100 noise = noise - 200 @end
    base = base + noise
  @end
  @if sensor.sensor_type == "pressure"
    base = 1013250 @! 101325.0 Pa × 10
    noise = (sensor.sample_count * 11) % 1000
    base = base + noise
  @end
  @! Apply calibration: value = (raw + offset) × scale
  calibrated = (base + sensor.offset) * sensor.scale
  sensor.raw_value = calibrated
  sensor.sample_count = sensor.sample_count + 1
  sensor.last_timestamp = sensor.last_timestamp + 1000
  return sensor
@end

@fn sensor_calibrate(sensor, offset)
  sensor.offset = offset
  return sensor
@end

@fn sensor_get_value(sensor)
  @! Return scaled value (divide by 10 for 1 decimal precision)
  return sensor.raw_value / 10
@end

@fn sensor_to_json(sensor)
  val = sensor.raw_value / 10
  json = "{"
  json = json + "\"id\":\"" + sensor.sensor_id + "\","
  json = json + "\"type\":\"" + sensor.sensor_type + "\","
  json = json + "\"unit\":\"" + sensor.unit + "\","
  json = json + "\"value\":" + val.to_str() + ","
  json = json + "\"samples\":" + sensor.sample_count.to_str()
  json = json + "}"
  return json
@end

@fn sensor_is_in_range(sensor)
  val = sensor.raw_value / 10
  @if val < sensor.min_val return 0 @end
  @if val > sensor.max_val return 0 @end
  return 1
@end
