@! ============================================================================
@! LIPI UNIVERSE AI — RL MDP ENVIRONMENTS & SIMULATION ENGINE
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Unified MDP Protocol (env_reset, env_step, env_render),
@! GridWorld, CartPole Physics ODE (Euler Integration), Multi-Armed Bandit.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/rl/space"

@! ----------------------------------------------------------------------------
@! 1. Unified MDP Environment Interface Dispatchers
@! ----------------------------------------------------------------------------

@fn env_reset(env)
  @if env.env_type == "gridworld"
    return env_gridworld_reset(env)
  @elif env.env_type == "cartpole"
    return env_cartpole_reset(env)
  @elif env.env_type == "bandit"
    return env_bandit_reset(env)
  @end
  return { env: env, state: [], info: {} }
@end

@fn env_step(env, action)
  @if env.env_type == "gridworld"
    return env_gridworld_step(env, action)
  @elif env.env_type == "cartpole"
    return env_cartpole_step(env, action)
  @elif env.env_type == "bandit"
    return env_bandit_step(env, action)
  @end
  return { env: env, next_state: [], reward: 0.0, done: 1, info: {} }
@end

@fn env_render(env)
  @if env.env_type == "gridworld"
    return env_gridworld_render(env)
  @elif env.env_type == "cartpole"
    return env_cartpole_render(env)
  @end
  return ""
@end

@! ----------------------------------------------------------------------------
@! 2. GridWorld Environment
@! ----------------------------------------------------------------------------

@fn env_gridworld_new(width, height, start_x, start_y, goal_x, goal_y, obstacles)
  obs_space = space_discrete_new(width * height)
  act_space = space_discrete_new(4) @! 0: Up, 1: Right, 2: Down, 3: Left
  
  return {
    env_type: "gridworld",
    width: width,
    height: height,
    start_x: start_x,
    start_y: start_y,
    goal_x: goal_x,
    goal_y: goal_y,
    cur_x: start_x,
    cur_y: start_y,
    obstacles: obstacles, @! list of { x, y, type: "wall" | "pit" }
    observation_space: obs_space,
    action_space: act_space,
    steps: 0,
    max_steps: 100
  }
@end

@fn env_gridworld_reset(env)
  env.cur_x = env.start_x
  env.cur_y = env.start_y
  env.steps = 0
  
  state_id = (env.cur_y * env.width) + env.cur_x
  return {
    env: env,
    state: [state_id * 1.0, env.cur_x * 1.0, env.cur_y * 1.0],
    state_id: state_id,
    info: {}
  }
@end

@fn env_gridworld_step(env, action)
  env.steps = env.steps + 1
  
  nx = env.cur_x
  ny = env.cur_y
  
  @if action == 0 ny = ny - 1 @end @! Up
  @if action == 1 nx = nx + 1 @end @! Right
  @if action == 2 ny = ny + 1 @end @! Down
  @if action == 3 nx = nx - 1 @end @! Left
  
  @! Boundary check
  @if nx < 0 nx = 0 @end
  @if nx >= env.width nx = env.width - 1 @end
  @if ny < 0 ny = 0 @end
  @if ny >= env.height ny = env.height - 1 @end
  
  @! Obstacle check
  hit_pit = 0
  hit_wall = 0
  i = 0
  num_items = env.obstacles.len()
  @while i < num_items
    obs = env.obstacles[i]
    @if obs.x == nx && obs.y == ny
      @if obs.type == "wall"
        hit_wall = 1
      @elif obs.type == "pit"
        hit_pit = 1
      @end
    @end
    i = i + 1
  @end
  
  @if hit_wall == 0
    env.cur_x = nx
    env.cur_y = ny
  @end
  
  reward = 0.0 - 0.01
  done = 0
  
  @if env.cur_x == env.goal_x && env.cur_y == env.goal_y
    reward = 1.0
    done = 1
  @elif hit_pit == 1
    reward = 0.0 - 1.0
    done = 1
  @elif env.steps >= env.max_steps
    done = 1
  @end
  
  state_id = (env.cur_y * env.width) + env.cur_x
  next_state = [state_id * 1.0, env.cur_x * 1.0, env.cur_y * 1.0]
  
  return {
    env: env,
    next_state: next_state,
    state_id: state_id,
    reward: reward,
    done: done,
    info: { steps: env.steps }
  }
@end

@fn env_gridworld_render(env)
  out = ""
  y = 0
  @while y < env.height
    x = 0
    @while x < env.width
      ch = "."
      @if x == env.cur_x && y == env.cur_y
        ch = "A"
      @elif x == env.goal_x && y == env.goal_y
        ch = "G"
      @else
        i = 0
        @while i < env.obstacles.len()
          obs = env.obstacles[i]
          @if obs.x == x && obs.y == y
            @if obs.type == "wall" ch = "#" @end
            @if obs.type == "pit" ch = "X" @end
          @end
          i = i + 1
        @end
      @end
      out = out + ch
      x = x + 1
    @end
    out = out + "\n"
    y = y + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 3. CartPole Continuous Physics Simulation (Euler Integration ODE)
@! ----------------------------------------------------------------------------

@fn env_cartpole_new()
  low = [0.0 - 4.8, 0.0 - 10.0, 0.0 - 0.418, 0.0 - 10.0]
  high = [4.8, 10.0, 0.418, 10.0]
  obs_space = space_box_new(low, high, [4])
  act_space = space_discrete_new(2) @! 0: Push Left, 1: Push Right
  
  return {
    env_type: "cartpole",
    gravity: 9.8,
    masscart: 1.0,
    masspole: 0.1,
    total_mass: 1.1,
    length: 0.5, @! Half-pole length
    polemass_length: 0.05,
    force_mag: 10.0,
    tau: 0.02, @! 20ms physics time step
    
    @! Angle threshold 12 degrees = 0.2094395 rad
    theta_threshold_radians: 0.20943951,
    x_threshold: 2.4,
    
    @! State: [x, x_dot, theta, theta_dot]
    state: [0.0, 0.0, 0.0, 0.0],
    steps: 0,
    max_steps: 500,
    seed: 12345,
    
    observation_space: obs_space,
    action_space: act_space
  }
@end

@fn env_cartpole_reset(env)
  env.seed = math_random_seed(env.seed)
  r1 = ((env.seed % 1000) * 0.0001) - 0.05
  env.seed = math_random_seed(env.seed)
  r2 = ((env.seed % 1000) * 0.0001) - 0.05
  env.seed = math_random_seed(env.seed)
  r3 = ((env.seed % 1000) * 0.0001) - 0.05
  env.seed = math_random_seed(env.seed)
  r4 = ((env.seed % 1000) * 0.0001) - 0.05
  
  env.state = [r1, r2, r3, r4]
  env.steps = 0
  
  return {
    env: env,
    state: env.state,
    info: {}
  }
@end

@fn env_cartpole_step(env, action)
  x = env.state[0]
  x_dot = env.state[1]
  theta = env.state[2]
  theta_dot = env.state[3]
  
  force = env.force_mag
  @if action == 0
    force = 0.0 - env.force_mag
  @end
  
  costheta = math_cos(theta)
  sintheta = math_sin(theta)
  
  @! Equations of motion (Euler method)
  temp = (force + (env.polemass_length * theta_dot * theta_dot * sintheta)) / env.total_mass
  thetaacc_denom = env.length * (1.3333333333333333 - ((env.masspole * costheta * costheta) / env.total_mass))
  thetaacc = ((env.gravity * sintheta) - (costheta * temp)) / thetaacc_denom
  xacc = temp - ((env.polemass_length * thetaacc * costheta) / env.total_mass)
  
  @! Semi-implicit Euler updates
  x = x + (env.tau * x_dot)
  x_dot = x_dot + (env.tau * xacc)
  theta = theta + (env.tau * theta_dot)
  theta_dot = theta_dot + (env.tau * thetaacc)
  
  env.state = [x, x_dot, theta, theta_dot]
  env.steps = env.steps + 1
  
  done = 0
  @if x < (0.0 - env.x_threshold) || x > env.x_threshold || theta < (0.0 - env.theta_threshold_radians) || theta > env.theta_threshold_radians
    done = 1
  @elif env.steps >= env.max_steps
    done = 1
  @end
  
  reward = 1.0
  @if done == 1 && env.steps < env.max_steps
    reward = 0.0
  @end
  
  return {
    env: env,
    next_state: env.state,
    reward: reward,
    done: done,
    info: { steps: env.steps }
  }
@end

@fn env_cartpole_render(env)
  x = env.state[0]
  theta = env.state[2]
  return "CartPole [x=" + x.to_str() + ", theta=" + theta.to_str() + ", step=" + env.steps.to_str() + "]"
@end

@! ----------------------------------------------------------------------------
@! 4. Multi-Armed Bandit Environment
@! ----------------------------------------------------------------------------

@fn env_bandit_new(num_arms, true_means, true_stds, seed)
  act_space = space_discrete_new(num_arms)
  return {
    env_type: "bandit",
    num_arms: num_arms,
    means: true_means,
    stds: true_stds,
    seed: seed,
    action_space: act_space,
    steps: 0
  }
@end

@fn env_bandit_reset(env)
  env.steps = 0
  return {
    env: env,
    state: [0.0],
    info: {}
  }
@end

@fn env_bandit_step(env, action)
  env.steps = env.steps + 1
  arm = action
  @if arm < 0 arm = 0 @end
  @if arm >= env.num_arms arm = env.num_arms - 1 @end
  
  env.seed = math_random_seed(env.seed)
  @! Box-Muller standard normal approximation
  u1 = ((env.seed % 10000) * 0.0001) + 0.0001
  env.seed = math_random_seed(env.seed)
  u2 = (env.seed % 10000) * 0.0001
  
  r_norm = math_sqrt((0.0 - 2.0) * math_log(u1)) * math_cos(6.2831853 * u2)
  reward = env.means[arm] + (env.stds[arm] * r_norm)
  
  return {
    env: env,
    next_state: [0.0],
    reward: reward,
    done: 0,
    info: { arm: arm, steps: env.steps }
  }
@end
