@! ============================================================================
@! LIPI UNIVERSE AI — RL REPLAY BUFFERS & GAE TRAJECTORIES
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Uniform Replay Buffer, Prioritized Experience Replay (SumTree PER),
@! On-Policy Trajectory Buffer, Generalized Advantage Estimation (GAE).
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. Uniform Experience Replay Buffer
@! ----------------------------------------------------------------------------

@fn replay_buffer_new(capacity)
  return {
    capacity: capacity,
    buffer: [],
    position: 0,
    size: 0
  }
@end

@fn replay_buffer_push(buf, state, action, reward, next_state, done)
  transition = {
    s: state,
    a: action,
    r: reward,
    s_next: next_state,
    d: done
  }
  
  @if buf.buffer.len() < buf.capacity
    buf.buffer = buf.buffer.push(transition)
  @else
    buf.buffer = list_set(buf.buffer, buf.position, transition)
  @end
  
  buf.position = (buf.position + 1) % buf.capacity
  @if buf.size < buf.capacity
    buf.size = buf.size + 1
  @end
  return buf
@end

@fn replay_buffer_sample(buf, batch_size, seed)
  batch = []
  curr_seed = seed
  i = 0
  count = batch_size
  @if count > buf.size count = buf.size @end
  
  @while i < count
    curr_seed = math_random_seed(curr_seed)
    idx = curr_seed % buf.size
    @if idx < 0 idx = 0 - idx @end
    batch = batch.push(buf.buffer[idx])
    i = i + 1
  @end
  
  return {
    batch: batch,
    next_seed: curr_seed
  }
@end

@fn replay_buffer_size(buf)
  return buf.size
@end

@! ----------------------------------------------------------------------------
@! 2. Prioritized Experience Replay (PER with SumTree)
@! ----------------------------------------------------------------------------

@fn sum_tree_new(capacity)
  total_nodes = (2 * capacity) - 1
  tree = []
  i = 0
  @while i < total_nodes
    tree = tree.push(0.0)
    i = i + 1
  @end
  
  data = []
  i = 0
  @while i < capacity
    data = data.push(0)
    i = i + 1
  @end
  
  return {
    capacity: capacity,
    tree: tree,
    data: data,
    data_pointer: 0,
    size: 0
  }
@end

@fn sum_tree_update(sum_tree, tree_idx, priority)
  change = priority - sum_tree.tree[tree_idx]
  sum_tree.tree = list_set(sum_tree.tree, tree_idx, priority)
  
  idx = tree_idx
  @while idx != 0
    idx = (idx - 1) / 2
    sum_tree.tree = list_set(sum_tree.tree, idx, sum_tree.tree[idx] + change)
  @end
  return sum_tree
@end

@fn sum_tree_add(sum_tree, priority, data_item)
  tree_idx = sum_tree.data_pointer + sum_tree.capacity - 1
  
  sum_tree.data = list_set(sum_tree.data, sum_tree.data_pointer, data_item)
  sum_tree = sum_tree_update(sum_tree, tree_idx, priority)
  
  sum_tree.data_pointer = sum_tree.data_pointer + 1
  @if sum_tree.data_pointer >= sum_tree.capacity
    sum_tree.data_pointer = 0
  @end
  
  @if sum_tree.size < sum_tree.capacity
    sum_tree.size = sum_tree.size + 1
  @end
  
  return sum_tree
@end

@fn sum_tree_get(sum_tree, v)
  parent_idx = 0
  @while 1 == 1
    left_child_idx = (2 * parent_idx) + 1
    right_child_idx = left_child_idx + 1
    
    @if left_child_idx >= sum_tree.tree.len()
      leaf_idx = parent_idx
      data_idx = leaf_idx - sum_tree.capacity + 1
      return {
        tree_idx: leaf_idx,
        priority: sum_tree.tree[leaf_idx],
        data: sum_tree.data[data_idx]
      }
    @end
    
    left_val = sum_tree.tree[left_child_idx]
    @if v <= left_val
      parent_idx = left_child_idx
    @else
      v = v - left_val
      parent_idx = right_child_idx
    @end
  @end
  return { tree_idx: 0, priority: 0.0, data: 0 }
@end

@fn sum_tree_total_priority(sum_tree)
  return sum_tree.tree[0]
@end

@fn per_buffer_new(capacity, alpha, beta)
  tree = sum_tree_new(capacity)
  return {
    capacity: capacity,
    alpha: alpha,     @! Priority exponent (0 = uniform, 1 = full PER)
    beta: beta,       @! Importance-sampling exponent (0 = no correction, 1 = full correction)
    beta_increment: 0.001,
    epsilon: 0.0001,  @! Minimum priority to avoid 0 probability
    tree: tree
  }
@end

@fn per_buffer_push(buf, state, action, reward, next_state, done, error)
  p = math_pow(math_abs(error) + buf.epsilon, buf.alpha)
  transition = {
    s: state,
    a: action,
    r: reward,
    s_next: next_state,
    d: done
  }
  buf.tree = sum_tree_add(buf.tree, p, transition)
  return buf
@end

@fn per_buffer_sample(buf, batch_size, seed)
  batch = []
  indices = []
  priorities = []
  
  total_p = sum_tree_total_priority(buf.tree)
  @if total_p <= 0.0 total_p = 1.0 @end
  
  segment = total_p / (batch_size * 1.0)
  curr_seed = seed
  
  i = 0
  @while i < batch_size
    a = segment * (i * 1.0)
    b = segment * ((i + 1) * 1.0)
    
    curr_seed = math_random_seed(curr_seed)
    r = (curr_seed % 10000) * 0.0001
    val = a + (r * (b - a))
    
    res = sum_tree_get(buf.tree, val)
    batch = batch.push(res.data)
    indices = indices.push(res.tree_idx)
    priorities = priorities.push(res.priority)
    i = i + 1
  @end
  
  @! Compute Importance Sampling Weights: w_i = (N * P(i))^(-beta) / max_w
  n = buf.tree.size * 1.0
  @if n <= 0.0 n = 1.0 @end
  
  weights = []
  max_weight = 0.000001
  i = 0
  @while i < batch_size
    prob = priorities[i] / total_p
    @if prob <= 0.000001 prob = 0.000001 @end
    w = math_pow(n * prob, 0.0 - buf.beta)
    @if w > max_weight max_weight = w @end
    weights = weights.push(w)
    i = i + 1
  @end
  
  @! Normalize weights
  norm_weights = []
  i = 0
  @while i < batch_size
    norm_weights = norm_weights.push(weights[i] / max_weight)
    i = i + 1
  @end
  
  buf.beta = math_min(1.0, buf.beta + buf.beta_increment)
  
  return {
    batch: batch,
    indices: indices,
    weights: norm_weights,
    next_seed: curr_seed
  }
@end

@fn per_buffer_update_priorities(buf, indices, errors)
  i = 0
  num_items = indices.len()
  @while i < num_items
    p = math_pow(math_abs(errors[i]) + buf.epsilon, buf.alpha)
    buf.tree = sum_tree_update(buf.tree, indices[i], p)
    i = i + 1
  @end
  return buf
@end

@! ----------------------------------------------------------------------------
@! 3. On-Policy Trajectory Buffer & Generalized Advantage Estimation (GAE)
@! ----------------------------------------------------------------------------

@fn trajectory_buffer_new()
  return {
    states: [],
    actions: [],
    rewards: [],
    values: [],
    log_probs: [],
    dones: [],
    length: 0
  }
@end

@fn trajectory_buffer_add(buf, state, action, reward, value, log_prob, done)
  buf.states = buf.states.push(state)
  buf.actions = buf.actions.push(action)
  buf.rewards = buf.rewards.push(reward)
  buf.values = buf.values.push(value)
  buf.log_probs = buf.log_probs.push(log_prob)
  buf.dones = buf.dones.push(done)
  buf.length = buf.length + 1
  return buf
@end

@fn trajectory_compute_gae(buf, last_value, gamma, gae_lambda)
  t_len = buf.length
  advantages = []
  returns = []
  
  @! Initialize advantage array
  i = 0
  @while i < t_len
    advantages = advantages.push(0.0)
    returns = returns.push(0.0)
    i = i + 1
  @end
  
  last_gae_lam = 0.0
  t = t_len - 1
  @while t >= 0
    next_val = last_value
    next_non_terminal = 1.0
    
    @if t < t_len - 1
      next_val = buf.values[t + 1]
      @if buf.dones[t] == 1
        next_non_terminal = 0.0
      @end
    @else
      @if buf.dones[t] == 1
        next_non_terminal = 0.0
      @end
    @end
    
    @! TD Residual: delta = r_t + gamma * V(s_{t+1}) * (1 - d_t) - V(s_t)
    delta = buf.rewards[t] + (gamma * next_val * next_non_terminal) - buf.values[t]
    
    @! GAE: A_t = delta + gamma * lambda * (1 - d_t) * {t+1}
    last_gae_lam = delta + (gamma * gae_lambda * next_non_terminal * last_gae_lam)
    
    advantages = list_set(advantages, t, last_gae_lam)
    returns = list_set(returns, t, last_gae_lam + buf.values[t])
    
    t = t - 1
  @end
  
  return {
    advantages: advantages,
    returns: returns
  }
@end

@fn trajectory_buffer_clear(buf)
  buf.states = []
  buf.actions = []
  buf.rewards = []
  buf.values = []
  buf.log_probs = []
  buf.dones = []
  buf.length = 0
  return buf
@end
