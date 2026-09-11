@! ============================================================================
@! MAYA UNIVERSE AI — RL POLICY GRADIENT & ACTOR-CRITIC ENGINES
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: REINFORCE (Monte Carlo Policy Gradient with Baseline),
@! Advantage Actor-Critic (A2C) with GAE & Entropy Regularization.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"
import "universe/ai/autodiff"
import "universe/ai/rl/policy"
import "universe/ai/rl/buffer"

@! ----------------------------------------------------------------------------
@! 1. REINFORCE (Monte Carlo Policy Gradient)
@! ----------------------------------------------------------------------------

@fn reinforce_agent_new(state_dim, hidden_dim, action_dim, lr, gamma)
  policy_net = policy_net_new(state_dim, hidden_dim, action_dim)
  params = [policy_net.l1.w, policy_net.l1.b, policy_net.l2.w, policy_net.l2.b]
  optimizer = optimizer_adam_new(params, lr)
  
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    action_dim: action_dim,
    lr: lr,
    gamma: gamma,
    policy_net: policy_net,
    optimizer: optimizer
  }
@end

@fn reinforce_select_action(agent, state, seed)
  st = tensor_with_grad(state, [1, agent.state_dim])
  probs = policy_net_forward(agent.policy_net, st)
  
  @! Sample action from categorical distribution
  next_seed = math_random_seed(seed)
  r = (next_seed % 10000) * 0.0001
  
  chosen_a = agent.action_dim - 1
  cum = 0.0
  i = 0
  @while i < agent.action_dim
    cum = cum + probs.data[i]
    @if r <= cum
      chosen_a = i
      i = agent.action_dim
    @end
    i = i + 1
  @end
  
  p_a = probs.data[chosen_a]
  @if p_a <= 0.00001 p_a = 0.00001 @end
  log_prob = math_log(p_a)
  
  return {
    action: chosen_a,
    probs: probs.data,
    log_prob: log_prob,
    next_seed: next_seed
  }
@end

@fn reinforce_update(agent, trajectory)
  t_len = trajectory.length
  @if t_len == 0 return agent @end
  
  @! 1. Compute discounted returns G_t = sum_{k=t}^T gamma^(k-t) * r_k
  returns = []
  i = 0
  @while i < t_len
    returns = returns.push(0.0)
    i = i + 1
  @end
  
  g = 0.0
  t = t_len - 1
  @while t >= 0
    g = trajectory.rewards[t] + (agent.gamma * g)
    returns = list_set(returns, t, g)
    t = t - 1
  @end
  
  @! 2. Return normalization (baseline subtraction)
  mean_g = 0.0
  i = 0
  @while i < t_len
    mean_g = mean_g + returns[i]
    i = i + 1
  @end
  mean_g = mean_g / (t_len * 1.0)
  
  std_g = 0.0
  i = 0
  @while i < t_len
    diff = returns[i] - mean_g
    std_g = std_g + (diff * diff)
    i = i + 1
  @end
  std_g = math_sqrt(std_g / (t_len * 1.0))
  @if std_g <= 0.0001 std_g = 1.0 @end
  
  @! 3. Accumulate policy gradient: grad_theta = sum_t (G_t - b) * grad(log pi(a_t | s_t))
  t = 0
  @while t < t_len
    norm_return = (returns[t] - mean_g) / std_g
    act = trajectory.actions[t]
    st = tensor_with_grad(trajectory.states[t], [1, agent.state_dim])
    probs = policy_net_forward(agent.policy_net, st)
    
    @! Gradient of cross-entropy: (probs - one_hot) * G_t
    i = 0
    @while i < agent.action_dim
      grad_logit = probs.data[i]
      @if i == act
        grad_logit = grad_logit - 1.0
      @end
      grad_scaled = grad_logit * norm_return / (t_len * 1.0)
      
      agent.policy_net.l2.b.grad = list_set(agent.policy_net.l2.b.grad, i, agent.policy_net.l2.b.grad[i] + grad_scaled)
      
      h = 0
      @while h < agent.hidden_dim
        w_idx = (h * agent.action_dim) + i
        agent.policy_net.l2.w.grad = list_set(agent.policy_net.l2.w.grad, w_idx, agent.policy_net.l2.w.grad[w_idx] + (grad_scaled * 0.1))
        h = h + 1
      @end
      i = i + 1
    @end
    t = t + 1
  @end
  
  @! 4. Optimizer update step
  agent.optimizer = optimizer_adam_step(agent.optimizer)
  return agent
@end

@! ----------------------------------------------------------------------------
@! 2. Advantage Actor-Critic (A2C)
@! ----------------------------------------------------------------------------

@fn a2c_agent_new(state_dim, hidden_dim, action_dim, actor_lr, critic_lr, gamma, gae_lambda, entropy_coef)
  actor = policy_net_new(state_dim, hidden_dim, action_dim)
  critic = value_net_new(state_dim, hidden_dim)
  
  actor_params = [actor.l1.w, actor.l1.b, actor.l2.w, actor.l2.b]
  critic_params = [critic.l1.w, critic.l1.b, critic.l2.w, critic.l2.b]
  
  actor_opt = optimizer_adam_new(actor_params, actor_lr)
  critic_opt = optimizer_adam_new(critic_params, critic_lr)
  
  return {
    state_dim: state_dim,
    hidden_dim: hidden_dim,
    action_dim: action_dim,
    gamma: gamma,
    gae_lambda: gae_lambda,
    entropy_coef: entropy_coef,
    actor: actor,
    critic: critic,
    actor_opt: actor_opt,
    critic_opt: critic_opt
  }
@end

@fn a2c_select_action(agent, state, seed)
  st = tensor_with_grad(state, [1, agent.state_dim])
  probs = policy_net_forward(agent.actor, st)
  val = value_net_forward(agent.critic, st)
  
  next_seed = math_random_seed(seed)
  r = (next_seed % 10000) * 0.0001
  
  chosen_a = agent.action_dim - 1
  cum = 0.0
  i = 0
  @while i < agent.action_dim
    cum = cum + probs.data[i]
    @if r <= cum
      chosen_a = i
      i = agent.action_dim
    @end
    i = i + 1
  @end
  
  p_a = probs.data[chosen_a]
  @if p_a <= 0.00001 p_a = 0.00001 @end
  log_prob = math_log(p_a)
  
  return {
    action: chosen_a,
    value: val.data[0],
    probs: probs.data,
    log_prob: log_prob,
    next_seed: next_seed
  }
@end

@fn a2c_update(agent, trajectory, last_val)
  t_len = trajectory.length
  @if t_len == 0 return agent @end
  
  @! 1. Compute GAE Advantages and Target Returns
  gae_res = trajectory_compute_gae(trajectory, last_val, agent.gamma, agent.gae_lambda)
  advantages = gae_res.advantages
  returns = gae_res.returns
  
  @! 2. Update Critic (MSE Loss against target returns)
  t = 0
  @while t < t_len
    target_v = returns[t]
    st = tensor_with_grad(trajectory.states[t], [1, agent.state_dim])
    pred_v = value_net_forward(agent.critic, st).data[0]
    
    v_err = 2.0 * (pred_v - target_v) / (t_len * 1.0)
    agent.critic.l2.b.grad = list_set(agent.critic.l2.b.grad, 0, agent.critic.l2.b.grad[0] + v_err)
    
    t = t + 1
  @end
  agent.critic_opt = optimizer_adam_step(agent.critic_opt)
  
  @! 3. Update Actor (Policy Loss with Entropy Bonus)
  t = 0
  @while t < t_len
    adv = advantages[t]
    act = trajectory.actions[t]
    st = tensor_with_grad(trajectory.states[t], [1, agent.state_dim])
    probs = policy_net_forward(agent.actor, st)
    
    @! Entropy calculation: H = - sum(p * log(p))
    entropy = 0.0
    i = 0
    @while i < agent.action_dim
      p_i = probs.data[i]
      @if p_i > 0.00001
        entropy = entropy - (p_i * math_log(p_i))
      @end
      i = i + 1
    @end
    
    @! Policy gradient: (probs - 1_{a}) * Adv - beta * entropy_grad
    i = 0
    @while i < agent.action_dim
      grad_p = probs.data[i]
      @if i == act grad_p = grad_p - 1.0 @end
      
      grad_total = (grad_p * adv / (t_len * 1.0)) - (agent.entropy_coef * (1.0 + math_log(math_max(probs.data[i], 0.00001))))
      agent.actor.l2.b.grad = list_set(agent.actor.l2.b.grad, i, agent.actor.l2.b.grad[i] + grad_total)
      i = i + 1
    @end
    
    t = t + 1
  @end
  agent.actor_opt = optimizer_adam_step(agent.actor_opt)
  
  return agent
@end
