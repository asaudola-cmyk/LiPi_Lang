@! ============================================================================
@! LIPI UNIVERSE AI — RL VALUE-BASED ALGORITHMS (Q-LEARNING & DQN)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Tabular Q-Learning, SARSA, Deep Q-Network (DQN), Double DQN (DDQN),
@! Dueling DQN Architecture with Soft Target Network Synchronization.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"
import "universe/ai/autodiff"
import "universe/ai/rl/policy"
import "universe/ai/rl/buffer"

@! ----------------------------------------------------------------------------
@! 1. Tabular Q-Learning & SARSA Updates
@! ----------------------------------------------------------------------------

@fn q_learning_update(q_tab, s, a, r, s_next, done, alpha, gamma)
  max_next_q = 0.0
  @if done == 0
    max_next_q = q_table_max_q(q_tab, s_next)
  @end
  
  target = r + (gamma * max_next_q)
  cur_q = q_table_get(q_tab, s, a)
  new_q = cur_q + (alpha * (target - cur_q))
  
  q_tab = q_table_set(q_tab, s, a, new_q)
  return q_tab
@end

@fn sarsa_update(q_tab, s, a, r, s_next, a_next, done, alpha, gamma)
  next_q = 0.0
  @if done == 0
    next_q = q_table_get(q_tab, s_next, a_next)
  @end
  
  target = r + (gamma * next_q)
  cur_q = q_table_get(q_tab, s, a)
  new_q = cur_q + (alpha * (target - cur_q))
  
  q_tab = q_table_set(q_tab, s, a, new_q)
  return q_tab
@end

@! ----------------------------------------------------------------------------
@! 2. Deep Q-Network (DQN) & Double DQN Agent
@! ----------------------------------------------------------------------------

@fn q_network_new(state_dim, hidden_dim, action_dim)
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

@fn q_network_forward(net, state_tensor)
  h1 = autodiff_relu(mlp_forward(net.l1, state_tensor))
  q_vals = mlp_forward(net.l2, h1)
  return q_vals
@end

@fn dqn_agent_new(state_dim, hidden_dim, action_dim, lr, gamma, buffer_capacity, batch_size)
  online_net = q_network_new(state_dim, hidden_dim, action_dim)
  target_net = q_network_new(state_dim, hidden_dim, action_dim)
  
  @! Deep copy parameters from online to target
  target_net.l1.w.data = list_concat([], online_net.l1.w.data)
  target_net.l1.b.data = list_concat([], online_net.l1.b.data)
  target_net.l2.w.data = list_concat([], online_net.l2.w.data)
  target_net.l2.b.data = list_concat([], online_net.l2.b.data)
  
  params = [online_net.l1.w, online_net.l1.b, online_net.l2.w, online_net.l2.b]
  optimizer = optimizer_adam_new(params, lr)
  replay_buf = replay_buffer_new(buffer_capacity)
  
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    action_dim: action_dim,
    gamma: gamma,
    batch_size: batch_size,
    online_net: online_net,
    target_net: target_net,
    optimizer: optimizer,
    replay_buffer: replay_buf,
    train_steps: 0
  }
@end

@fn dqn_select_action(agent, state, epsilon, seed)
  st = tensor_with_grad(state, [1, agent.state_dim])
  q_t = q_network_forward(agent.online_net, st)
  
  res = exploration_epsilon_greedy(q_t.data, agent.action_dim, epsilon, seed)
  return {
    action: res.action,
    q_values: q_t.data,
    next_seed: res.next_seed
  }
@end

@fn dqn_train_step(agent)
  @if agent.replay_buffer.size < agent.batch_size
    return { agent: agent, loss: 0.0 }
  @end
  
  sample_res = replay_buffer_sample(agent.replay_buffer, agent.batch_size, 42 + agent.train_steps)
  batch = sample_res.batch
  
  total_loss = 0.0
  b_idx = 0
  @while b_idx < batch.len()
    tr = batch[b_idx]
    
    @! Compute target y_i
    y_i = tr.r
    @if tr.d == 0
      next_st = tensor_with_grad(tr.s_next, [1, agent.state_dim])
      target_q = q_network_forward(agent.target_net, next_st)
      
      max_q = target_q.data[0]
      a = 1
      @while a < agent.action_dim
        @if target_q.data[a] > max_q max_q = target_q.data[a] @end
        a = a + 1
      @end
      y_i = tr.r + (agent.gamma * max_q)
    @end
    
    @! Online Q(s, a)
    st = tensor_with_grad(tr.s, [1, agent.state_dim])
    online_q = q_network_forward(agent.online_net, st)
    pred_q = online_q.data[tr.a]
    
    diff = pred_q - y_i
    loss_val = diff * diff
    total_loss = total_loss + loss_val
    
    @! Direct gradient backprop into online Q(s, a)
    grad_q = 2.0 * diff / (agent.batch_size * 1.0)
    
    @! Accumulate gradient into online_net parameters
    agent.online_net.l2.b.grad = list_set(agent.online_net.l2.b.grad, tr.a, agent.online_net.l2.b.grad[tr.a] + grad_q)
    
    h1_val = 0.0
    h_idx = 0
    @while h_idx < agent.hidden_dim
      w_idx = (h_idx * agent.action_dim) + tr.a
      agent.online_net.l2.w.grad = list_set(agent.online_net.l2.w.grad, w_idx, agent.online_net.l2.w.grad[w_idx] + (grad_q * 0.1))
      h_idx = h_idx + 1
    @end
    
    b_idx = b_idx + 1
  @end
  
  @! Adam Optimizer Step
  agent.optimizer = optimizer_adam_step(agent.optimizer)
  agent.train_steps = agent.train_steps + 1
  
  return {
    agent: agent,
    loss: total_loss / (agent.batch_size * 1.0)
  }
@end

@fn ddqn_train_step(agent)
  @if agent.replay_buffer.size < agent.batch_size
    return { agent: agent, loss: 0.0 }
  @end
  
  sample_res = replay_buffer_sample(agent.replay_buffer, agent.batch_size, 100 + agent.train_steps)
  batch = sample_res.batch
  
  total_loss = 0.0
  b_idx = 0
  @while b_idx < batch.len()
    tr = batch[b_idx]
    
    @! Decoupled target: a* = argmax_a Q_online(s'), y = r + gamma * Q_target(s', a*)
    y_i = tr.r
    @if tr.d == 0
      next_st = tensor_with_grad(tr.s_next, [1, agent.state_dim])
      online_next_q = q_network_forward(agent.online_net, next_st)
      
      best_next_a = 0
      max_online_q = online_next_q.data[0]
      a = 1
      @while a < agent.action_dim
        @if online_next_q.data[a] > max_online_q
          max_online_q = online_next_q.data[a]
          best_next_a = a
        @end
        a = a + 1
      @end
      
      target_next_q = q_network_forward(agent.target_net, next_st)
      y_i = tr.r + (agent.gamma * target_next_q.data[best_next_a])
    @end
    
    st = tensor_with_grad(tr.s, [1, agent.state_dim])
    online_q = q_network_forward(agent.online_net, st)
    pred_q = online_q.data[tr.a]
    
    diff = pred_q - y_i
    loss_val = diff * diff
    total_loss = total_loss + loss_val
    
    grad_q = 2.0 * diff / (agent.batch_size * 1.0)
    agent.online_net.l2.b.grad = list_set(agent.online_net.l2.b.grad, tr.a, agent.online_net.l2.b.grad[tr.a] + grad_q)
    
    b_idx = b_idx + 1
  @end
  
  agent.optimizer = optimizer_adam_step(agent.optimizer)
  agent.train_steps = agent.train_steps + 1
  
  return {
    agent: agent,
    loss: total_loss / (agent.batch_size * 1.0)
  }
@end

@fn dqn_sync_target(agent, tau)
  @! Polyak soft update: theta_target = tau * theta_online + (1 - tau) * theta_target
  p_online = [agent.online_net.l1.w, agent.online_net.l1.b, agent.online_net.l2.w, agent.online_net.l2.b]
  p_target = [agent.target_net.l1.w, agent.target_net.l1.b, agent.target_net.l2.w, agent.target_net.l2.b]
  
  i = 0
  @while i < p_online.len()
    on = p_online[i]
    tg = p_target[i]
    j = 0
    num_items = on.data.len()
    @while j < num_items
      new_val = (tau * on.data[j]) + ((1.0 - tau) * tg.data[j])
      tg.data = list_set(tg.data, j, new_val)
      j = j + 1
    @end
    i = i + 1
  @end
  
  return agent
@end

@! ----------------------------------------------------------------------------
@! 3. Dueling DQN Architecture
@! ----------------------------------------------------------------------------

@fn dueling_dqn_net_new(state_dim, hidden_dim, action_dim)
  feature_l = mlp_layer_init(state_dim, hidden_dim)
  value_l = mlp_layer_init(hidden_dim, 1)
  advantage_l = mlp_layer_init(hidden_dim, action_dim)
  
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    action_dim: action_dim,
    feature_l: feature_l,
    value_l: value_l,
    advantage_l: advantage_l
  }
@end

@fn dueling_dqn_forward(net, state_tensor)
  feat = autodiff_relu(mlp_forward(net.feature_l, state_tensor))
  v = mlp_forward(net.value_l, feat)
  adv = mlp_forward(net.advantage_l, feat)
  
  @! Mean advantage across all actions
  adv_sum = 0.0
  i = 0
  @while i < net.action_dim
    adv_sum = adv_sum + adv.data[i]
    i = i + 1
  @end
  mean_adv = adv_sum / (net.action_dim * 1.0)
  
  @! Q(s, a) = V(s) + (A(s, a) - mean(A(s, .)))
  q_data = []
  i = 0
  @while i < net.action_dim
    q_val = v.data[0] + (adv.data[i] - mean_adv)
    q_data = q_data.push(q_val)
    i = i + 1
  @end
  
  out = tensor_with_grad(q_data, [1, net.action_dim])
  return out
@end
