@! ============================================================================
@! LIPI UNIVERSE AI — RL POLICIES, VALUE NETWORKS & EXPLORATION
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Q-Table, Epsilon-Greedy, Boltzmann Softmax Exploration, UCB1,
@! Categorical Policy Network, State-Value V(s) Network, Continuous Gaussian Policy.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"
import "universe/ai/autodiff"

@! ----------------------------------------------------------------------------
@! 1. Tabular Q-Table
@! ----------------------------------------------------------------------------

@fn q_table_new(num_states, num_actions, init_val)
  table = []
  total = num_states * num_actions
  i = 0
  @while i < total
    table = table.push(init_val)
    i = i + 1
  @end
  return {
    num_states: num_states,
    num_actions: num_actions,
    table: table
  }
@end

@fn q_table_get(q_tab, s, a)
  @if s < 0 || s >= q_tab.num_states || a < 0 || a >= q_tab.num_actions
    return 0.0
  @end
  idx = (s * q_tab.num_actions) + a
  return q_tab.table[idx]
@end

@fn q_table_set(q_tab, s, a, val)
  @if s >= 0 && s < q_tab.num_states && a >= 0 && a < q_tab.num_actions
    idx = (s * q_tab.num_actions) + a
    q_tab.table = list_set(q_tab.table, idx, val)
  @end
  return q_tab
@end

@fn q_table_max_q(q_tab, s)
  max_val = q_table_get(q_tab, s, 0)
  a = 1
  @while a < q_tab.num_actions
    val = q_table_get(q_tab, s, a)
    @if val > max_val max_val = val @end
    a = a + 1
  @end
  return max_val
@end

@fn q_table_best_action(q_tab, s)
  best_a = 0
  max_val = q_table_get(q_tab, s, 0)
  a = 1
  @while a < q_tab.num_actions
    val = q_table_get(q_tab, s, a)
    @if val > max_val
      max_val = val
      best_a = a
    @end
    a = a + 1
  @end
  return { action: best_a, q_value: max_val }
@end

@! ----------------------------------------------------------------------------
@! 2. Exploration Strategies
@! ----------------------------------------------------------------------------

@fn exploration_epsilon_greedy(q_values, num_actions, epsilon, seed)
  next_seed = math_random_seed(seed)
  r = (next_seed % 10000) * 0.0001
  
  @if r < epsilon
    @! Random exploration action
    next_seed = math_random_seed(next_seed)
    act = next_seed % num_actions
    @if act < 0 act = 0 - act @end
    return { action: act, next_seed: next_seed }
  @else
    @! Greedy action
    best_a = 0
    max_q = q_values[0]
    a = 1
    @while a < num_actions
      @if q_values[a] > max_q
        max_q = q_values[a]
        best_a = a
      @end
      a = a + 1
    @end
    return { action: best_a, next_seed: next_seed }
  @end
@end

@fn exploration_epsilon_decay(eps, min_eps, decay_rate)
  new_eps = eps * decay_rate
  @if new_eps < min_eps new_eps = min_eps @end
  return new_eps
@end

@fn exploration_boltzmann_softmax(q_values, temperature, seed)
  temp = temperature
  @if temp <= 0.0001 temp = 0.0001 @end
  
  @! Compute max Q for numerical stability
  max_q = q_values[0]
  i = 1
  x_len = q_values.len()
  @while i < x_len
    @if q_values[i] > max_q max_q = q_values[i] @end
    i = i + 1
  @end
  
  exp_sum = 0.0
  exp_vals = []
  i = 0
  @while i < x_len
    ev = math_exp((q_values[i] - max_q) / temp)
    exp_vals = exp_vals.push(ev)
    exp_sum = exp_sum + ev
    i = i + 1
  @end
  
  probs = []
  i = 0
  @while i < x_len
    probs = probs.push(exp_vals[i] / exp_sum)
    i = i + 1
  @end
  
  @! Sample according to probabilities
  next_seed = math_random_seed(seed)
  r = (next_seed % 10000) * 0.0001
  cum = 0.0
  chosen_act = x_len - 1
  i = 0
  @while i < x_len
    cum = cum + probs[i]
    @if r <= cum
      chosen_act = i
      i = x_len
    @end
    i = i + 1
  @end
  
  return {
    action: chosen_act,
    probs: probs,
    next_seed: next_seed
  }
@end

@fn exploration_ucb1(action_counts, action_rewards, total_steps, c)
  num_actions = action_counts.len()
  best_a = 0
  max_ucb = 0.0 - 1000000.0
  ln_t = math_log(total_steps * 1.0)
  
  a = 0
  @while a < num_actions
    count = action_counts[a]
    @if count == 0
      return a @! Explore unvisited arms first
    @end
    
    mean_reward = action_rewards[a] / (count * 1.0)
    bonus = c * math_sqrt(ln_t / (count * 1.0))
    ucb = mean_reward + bonus
    
    @if ucb > max_ucb
      max_ucb = ucb
      best_a = a
    @end
    a = a + 1
  @end
  
  return best_a
@end

@! ----------------------------------------------------------------------------
@! 3. Neural Network Policy & Value Models
@! ----------------------------------------------------------------------------

@fn mlp_layer_init(in_dim, out_dim)
  scale = 1.0 / math_sqrt(in_dim * 1.0)
  w_data = []
  total = in_dim * out_dim
  i = 0
  @while i < total
    val = (((i * 23 + 7) % 100) * 0.02 - 1.0) * scale
    w_data = w_data.push(val)
    i = i + 1
  @end
  
  b_data = []
  i = 0
  @while i < out_dim
    b_data = b_data.push(0.0)
    i = i + 1
  @end
  
  return {
    in_dim: in_dim,
    out_dim: out_dim,
    w: tensor_with_grad(w_data, [in_dim, out_dim]),
    b: tensor_with_grad(b_data, [1, out_dim])
  }
@end

@fn mlp_forward(layer, x)
  @! y = x * W + b
  out_data = []
  j = 0
  @while j < layer.out_dim
    sum = 0.0
    k = 0
    @while k < layer.in_dim
      sum = sum + (x.data[k] * layer.w.data[(k * layer.out_dim) + j])
      k = k + 1
    @end
    out_data = out_data.push(sum + layer.b.data[j])
    j = j + 1
  @end
  
  out = tensor_with_grad(out_data, [1, layer.out_dim])
  out.parents = [x, layer.w, layer.b]
  return out
@end

@fn policy_net_new(state_dim, hidden_dim, action_dim)
  l1 = mlp_layer_init(state_dim, hidden_dim)
  l2 = mlp_layer_init(hidden_dim, action_dim)
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    action_dim: action_dim,
    l1: l1,
    l2: l2
  }
@end

@fn policy_net_forward(net, state_tensor)
  h1 = autodiff_relu(mlp_forward(net.l1, state_tensor))
  logits = mlp_forward(net.l2, h1)
  probs = tensor_softmax(logits)
  return probs
@end

@fn value_net_new(state_dim, hidden_dim)
  l1 = mlp_layer_init(state_dim, hidden_dim)
  l2 = mlp_layer_init(hidden_dim, 1)
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    l1: l1,
    l2: l2
  }
@end

@fn value_net_forward(net, state_tensor)
  h1 = autodiff_relu(mlp_forward(net.l1, state_tensor))
  v = mlp_forward(net.l2, h1)
  return v
@end

@fn gaussian_policy_new(state_dim, hidden_dim, action_dim)
  l1 = mlp_layer_init(state_dim, hidden_dim)
  l_mean = mlp_layer_init(hidden_dim, action_dim)
  
  log_std = []
  i = 0
  @while i < action_dim
    log_std = log_std.push(0.0) @! std = exp(0) = 1.0
    i = i + 1
  @end
  
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    action_dim: action_dim,
    l1: l1,
    l_mean: l_mean,
    log_std: tensor_with_grad(log_std, [1, action_dim])
  }
@end

@fn gaussian_policy_sample(policy, state_tensor, seed)
  h1 = autodiff_relu(mlp_forward(policy.l1, state_tensor))
  mean_t = mlp_forward(policy.l_mean, h1)
  
  actions = []
  curr_seed = seed
  i = 0
  @while i < policy.action_dim
    curr_seed = math_random_seed(curr_seed)
    u1 = ((curr_seed % 10000) * 0.0001) + 0.0001
    curr_seed = math_random_seed(curr_seed)
    u2 = (curr_seed % 10000) * 0.0001
    
    eps = math_sqrt((0.0 - 2.0) * math_log(u1)) * math_cos(6.2831853 * u2)
    std = math_exp(policy.log_std.data[i])
    act_val = mean_t.data[i] + (std * eps)
    actions = actions.push(act_val)
    i = i + 1
  @end
  
  return {
    actions: actions,
    mean: mean_t.data,
    next_seed: curr_seed
  }
@end
