@! ============================================================================
@! MAYA UNIVERSE AI — RL OBSERVATION & ACTION SPACES (space.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Discrete, Continuous Box, MultiDiscrete Spaces with Stochastic Sampling,
@! Value Containment & Bound Clamping.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. Discrete Space
@! ----------------------------------------------------------------------------

@fn space_discrete_new(n)
  return {
    type: "discrete",
    n: n,
    shape: [1]
  }
@end

@fn space_discrete_sample(space, seed)
  next_seed = math_random_seed(seed)
  act = next_seed % space.n
  @if act < 0 act = 0 - act @end
  return {
    action: act,
    next_seed: next_seed
  }
@end

@fn space_discrete_contains(space, x)
  @if x >= 0 && x < space.n
    return 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 2. Continuous Bounded Box Space
@! ----------------------------------------------------------------------------

@fn space_box_new(low_arr, high_arr, shape)
  return {
    type: "box",
    low: low_arr,
    high: high_arr,
    shape: shape
  }
@end

@fn space_box_sample(space, seed)
  sample_data = []
  curr_seed = seed
  i = 0
  num_items = space.low.len()
  @while i < num_items
    curr_seed = math_random_seed(curr_seed)
    r_unit = (curr_seed % 10000) * 0.0001
    val = space.low[i] + (r_unit * (space.high[i] - space.low[i]))
    sample_data = sample_data.push(val)
    i = i + 1
  @end
  return {
    sample: sample_data,
    next_seed: curr_seed
  }
@end

@fn space_box_contains(space, val_arr)
  @if val_arr.len() != space.low.len()
    return 0
  @end
  i = 0
  num_items = val_arr.len()
  @while i < num_items
    @if val_arr[i] < space.low[i] || val_arr[i] > space.high[i]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn space_box_clamp(space, val_arr)
  clamped = []
  i = 0
  num_items = val_arr.len()
  @while i < num_items
    v = val_arr[i]
    @if v < space.low[i] v = space.low[i] @end
    @if v > space.high[i] v = space.high[i] @end
    clamped = clamped.push(v)
    i = i + 1
  @end
  return clamped
@end

@! ----------------------------------------------------------------------------
@! 3. MultiDiscrete Space
@! ----------------------------------------------------------------------------

@fn space_multidiscrete_new(nvec)
  return {
    type: "multidiscrete",
    nvec: nvec,
    shape: [nvec.len()]
  }
@end

@fn space_multidiscrete_sample(space, seed)
  sample_data = []
  curr_seed = seed
  i = 0
  num_items = space.nvec.len()
  @while i < num_items
    curr_seed = math_random_seed(curr_seed)
    act = curr_seed % space.nvec[i]
    @if act < 0 act = 0 - act @end
    sample_data = sample_data.push(act)
    i = i + 1
  @end
  return {
    sample: sample_data,
    next_seed: curr_seed
  }
@end

@fn space_multidiscrete_contains(space, val_arr)
  @if val_arr.len() != space.nvec.len()
    return 0
  @end
  i = 0
  num_items = val_arr.len()
  @while i < num_items
    @if val_arr[i] < 0 || val_arr[i] >= space.nvec[i]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end
