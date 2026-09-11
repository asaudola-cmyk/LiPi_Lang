@! ============================================================================
@! LIPI UNIVERSE DB - TIMESERIES ENGINE (universe/db/timeseries.maya)
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/collections"

@struct TimeSeries
  metric_name: "",
  timestamps: [],
  values: []
@end

@fn new_timeseries(metric_name)
  return {
    metric_name: metric_name,
    timestamps: [],
    values: []
  }
@end

@fn delta_delta_encode(timestamps)
  @if timestamps.len() <= 1
    return timestamps
  @end

  encoded = []
  @! 1. Store first timestamp directly
  encoded = encoded.push(timestamps[0])

  @! 2. Store first delta
  d0 = timestamps[1] - timestamps[0]
  encoded = encoded.push(d0)

  @! 3. Store delta-of-delta for remaining
  prev_delta = d0
  i = 2
  n = timestamps.len()
  @while i < n
    curr_delta = timestamps[i] - timestamps[i - 1]
    d_d = curr_delta - prev_delta
    encoded = encoded.push(d_d)
    prev_delta = curr_delta
    i = i + 1
  @end

  return encoded
@end

@fn delta_delta_decode(encoded)
  @if encoded.len() <= 1
    return encoded
  @end

  timestamps = []
  t0 = encoded[0]
  timestamps = timestamps.push(t0)

  d0 = encoded[1]
  t1 = t0 + d0
  timestamps = timestamps.push(t1)

  prev_t = t1
  prev_d = d0
  i = 2
  n = encoded.len()
  @while i < n
    d_d = encoded[i]
    curr_d = prev_d + d_d
    curr_t = prev_t + curr_d
    timestamps = timestamps.push(curr_t)
    prev_t = curr_t
    prev_d = curr_d
    i = i + 1
  @end

  return timestamps
@end

@fn xor_compress(values)
  @if values.len() == 0
    return []
  @end

  compressed = []
  prev_val = values[0]
  compressed = compressed.push(prev_val)

  i = 1
  n = values.len()
  @while i < n
    curr_val = values[i]
    diff_xor = curr_val ^ prev_val
    compressed = compressed.push(diff_xor)
    prev_val = curr_val
    i = i + 1
  @end

  return compressed
@end