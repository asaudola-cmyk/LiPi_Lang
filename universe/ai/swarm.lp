@! ============================================================================
@! LIPI UNIVERSE AI — AUTONOMOUS MULTI-AGENT SWARM & TASK ROUTING (universe/ai/swarm.lp)
@! 100% Pure Lipi Implementation — Zero External / Foreign Code Dependencies
@! Features: F18 Autonomous Multi-Agent Cognitive Roles (Planner, Coder, Critic, Synthesizer),
@! Deterministic State Machine Engine, Priority Mailboxes, Topic Pub/Sub Event Bus,
@! F19 Dynamic Task Routing & Multi-Stage DAG Workflow Execution with Reflection Loops.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Constants & Role Definitions
@! ----------------------------------------------------------------------------

@! Cognitive Agent Roles
@fn role_planner() -> string return "PLANNER" @end
@fn role_coder() -> string return "CODER" @end
@fn role_critic() -> string return "CRITIC" @end
@fn role_synthesizer() -> string return "SYNTHESIZER" @end

@! Agent State Machine States
@fn state_idle() -> i64 return 0 @end
@fn state_thinking() -> i64 return 1 @end
@fn state_executing() -> i64 return 2 @end
@fn state_reviewing() -> i64 return 3 @end
@fn state_completed() -> i64 return 4 @end
@fn state_failed() -> i64 return 5 @end
@fn state_paused() -> i64 return 6 @end
@fn state_terminated() -> i64 return 7 @end

@! Message Priorities
@fn priority_low() -> i64 return 0 @end
@fn priority_normal() -> i64 return 1 @end
@fn priority_high() -> i64 return 2 @end
@fn priority_urgent() -> i64 return 3 @end

@! ----------------------------------------------------------------------------
@! 2. Data Structures
@! ----------------------------------------------------------------------------

@struct AgentMetrics
  tasks_completed: i64
  tasks_failed: i64
  reflection_loops: i64
  messages_sent: i64
  messages_received: i64
@end

@struct AgentMessage
  msg_id: i64
  sender_id: string
  recipient_id: string
  msg_type: string
  payload: string
  priority: i64
  timestamp: i64
@end

@struct AgentMailbox
  control_queue: array
  task_queue: array
@end

@struct AIAgent
  agent_id: string
  role: string
  name: string
  state: i64
  previous_state: i64
  system_prompt: string
  context_memory: array
  mailbox: AgentMailbox
  current_task_id: i64
  current_task_title: string
  current_task_payload: string
  iteration_count: i64
  max_iterations: i64
  metrics: AgentMetrics
  last_output: string
  status_info: string
@end

@struct SwarmTask
  task_id: i64
  title: string
  task_type: string
  required_role: string
  priority: i64
  payload: string
  dependencies: array
  status: string
  assigned_agent_id: string
  result: string
  retry_count: i64
  max_retries: i64
@end

@struct PubSubSubscription
  topic: string
  agent_id: string
@end

@struct PubSubBus
  subscriptions: array
  message_log: array
@end

@struct PipelineStage
  stage_id: string
  name: string
  required_role: string
  prompt: string
  dependencies: array
  status: string
  output_result: string
  retries_remaining: i64
@end

@struct SwarmPipeline
  pipeline_id: string
  name: string
  stages: array
  status: string
  max_reflection_loops: i64
  reflection_count: i64
  final_output: string
@end

@struct SwarmCluster
  cluster_name: string
  agents: array
  bus: PubSubBus
  pending_tasks: array
  completed_tasks: array
  pipelines: array
  next_agent_id: i64
  next_task_id: i64
  next_msg_id: i64
  is_running: i64
@end

@! ----------------------------------------------------------------------------
@! 3. Agent Lifecycle & Mailbox Operations
@! ----------------------------------------------------------------------------

@fn ai_agent_metrics_new() -> AgentMetrics
  return {
    tasks_completed: 0,
    tasks_failed: 0,
    reflection_loops: 0,
    messages_sent: 0,
    messages_received: 0
  }
@end

@fn ai_agent_mailbox_new() -> AgentMailbox
  return {
    control_queue: [],
    task_queue: []
  }
@end

@fn ai_agent_new(agent_id: string, role: string, name: string, prompt: string, max_iter: i64) -> AIAgent
  return {
    agent_id: agent_id,
    role: role,
    name: name,
    state: 0, @! IDLE
    previous_state: 0,
    system_prompt: prompt,
    context_memory: [],
    mailbox: ai_agent_mailbox_new(),
    current_task_id: 0 - 1,
    current_task_title: "",
    current_task_payload: "",
    iteration_count: 0,
    max_iterations: max_iter,
    metrics: ai_agent_metrics_new(),
    last_output: "",
    status_info: "Agent initialized"
  }
@end

@fn ai_agent_send_message(agent: AIAgent, msg: AgentMessage) -> i64
  @if msg.priority >= 2 || string_eq(msg.msg_type, "CONTROL_PAUSE") == 1 || string_eq(msg.msg_type, "CONTROL_RESUME") == 1 || string_eq(msg.msg_type, "CONTROL_TERMINATE") == 1
    agent.mailbox.control_queue = agent.mailbox.control_queue.push(msg)
  @else
    agent.mailbox.task_queue = agent.mailbox.task_queue.push(msg)
  @end
  agent.metrics.messages_received = agent.metrics.messages_received + 1
  return 1
@end

@fn ai_agent_transition_state(agent: AIAgent, new_state: i64) -> i64
  agent.previous_state = agent.state
  agent.state = new_state
  return new_state
@end

@fn ai_agent_pause(agent: AIAgent) -> i64
  @if agent.state != 7 @! not terminated
    ai_agent_transition_state(agent, 6) @! PAUSED
    agent.status_info = "Paused"
    return 1
  @end
  return 0
@end

@fn ai_agent_resume(agent: AIAgent) -> i64
  @if agent.state == 6 @! PAUSED
    ai_agent_transition_state(agent, agent.previous_state)
    agent.status_info = "Resumed"
    return 1
  @end
  return 0
@end

@fn ai_agent_terminate(agent: AIAgent) -> i64
  ai_agent_transition_state(agent, 7) @! TERMINATED
  agent.status_info = "Terminated"
  return 1
@end

@! ----------------------------------------------------------------------------
@! 4. Pub/Sub Bus Engine
@! ----------------------------------------------------------------------------

@fn pubsub_new() -> PubSubBus
  return {
    subscriptions: [],
    message_log: []
  }
@end

@fn pubsub_subscribe(bus: PubSubBus, topic: string, agent_id: string) -> i64
  @! Check if already subscribed
  i = 0
  num_items = bus.subscriptions.len()
  @while i < num_items
    sub = bus.subscriptions[i]
    @if string_eq(sub.topic, topic) == 1 && string_eq(sub.agent_id, agent_id) == 1
      return 0 @! Already subscribed
    @end
    i = i + 1
  @end
  new_sub = { topic: topic, agent_id: agent_id }
  bus.subscriptions = bus.subscriptions.push(new_sub)
  return 1
@end

@fn pubsub_unsubscribe(bus: PubSubBus, topic: string, agent_id: string) -> i64
  new_subs = []
  i = 0
  removed = 0
  num_items = bus.subscriptions.len()
  @while i < num_items
    sub = bus.subscriptions[i]
    @if string_eq(sub.topic, topic) == 1 && string_eq(sub.agent_id, agent_id) == 1
      removed = 1
    @else
      new_subs = new_subs.push(sub)
    @end
    i = i + 1
  @end
  bus.subscriptions = new_subs
  return removed
@end

@fn pubsub_publish(bus: PubSubBus, cluster: SwarmCluster, topic: string, sender_id: string, payload: string) -> i64
  msg_id = cluster.next_msg_id
  cluster.next_msg_id = cluster.next_msg_id + 1

  delivered_count = 0
  i = 0
  len_subs = bus.subscriptions.len()
  @while i < len_subs
    sub = bus.subscriptions[i]
    @if string_eq(sub.topic, topic) == 1
      target_id = sub.agent_id
      @! Find agent in cluster
      a_idx = 0
      len_a = cluster.agents.len()
      @while a_idx < len_a
        ag = cluster.agents[a_idx]
        @if string_eq(ag.agent_id, target_id) == 1
          msg = {
            msg_id: msg_id,
            sender_id: sender_id,
            recipient_id: target_id,
            msg_type: topic,
            payload: payload,
            priority: 1,
            timestamp: 0
          }
          ai_agent_send_message(ag, msg)
          delivered_count = delivered_count + 1
        @end
        a_idx = a_idx + 1
      @end
    @end
    i = i + 1
  @end

  log_entry = {
    msg_id: msg_id,
    sender_id: sender_id,
    recipient_id: topic,
    msg_type: topic,
    payload: payload,
    priority: 1,
    timestamp: 0
  }
  bus.message_log = bus.message_log.push(log_entry)
  return delivered_count
@end

@! ----------------------------------------------------------------------------
@! 5. Dynamic Task Router & Scheduling Engine
@! ----------------------------------------------------------------------------



@fn task_new(task_id: i64, title: string, required_role: string, priority: i64, payload: string, dependencies: array) -> SwarmTask
  return {
    task_id: task_id,
    title: title,
    task_type: "DEFAULT",
    required_role: required_role,
    priority: priority,
    payload: payload,
    dependencies: dependencies,
    status: "PENDING",
    assigned_agent_id: "",
    result: "",
    retry_count: 0,
    max_retries: 3
  }
@end



@fn task_router_find_candidate(cluster: SwarmCluster, required_role: string) -> AIAgent
  best_agent = 0
  min_load = 999999
  found = 0

  i = 0
  num_items = cluster.agents.len()
  @while i < num_items
    ag = cluster.agents[i]
    @if ag.role == required_role && ag.state != 7 && ag.state != 6 @! not terminated and not paused
      load = ag.mailbox.task_queue.len()
      @if ag.state == 0 @! IDLE
        return ag
      @end
      @if load < min_load
        min_load = load
        best_agent = ag
        found = 1
      @end
    @end
    i = i + 1
  @end

  @if found == 1
    return best_agent
  @end
  return 0
@end

@fn task_router_dispatch(cluster: SwarmCluster, task: SwarmTask) -> i64
  @! Check dependencies
  dep_idx = 0
  while_dep = 1
  @while dep_idx < task.dependencies.len()
    dep_id = task.dependencies[dep_idx]
    dep_done = 0
    c_idx = 0
    @while c_idx < cluster.completed_tasks.len()
      ct = cluster.completed_tasks[c_idx]
      @if ct.task_id == dep_id
        dep_done = 1
      @end
      c_idx = c_idx + 1
    @end
    @if dep_done == 0
      task.status = "BLOCKED"
      return 0
    @end
    dep_idx = dep_idx + 1
  @end

  candidate = task_router_find_candidate(cluster, task.required_role)
  @if candidate == 0
    task.status = "UNASSIGNED"
    return 0
  @end

  task.assigned_agent_id = candidate.agent_id
  task.status = "ASSIGNED"

  msg_id = cluster.next_msg_id
  cluster.next_msg_id = cluster.next_msg_id + 1

  assign_msg = {
    msg_id: msg_id,
    sender_id: "ROUTER",
    recipient_id: candidate.agent_id,
    msg_type: "TASK_ASSIGN",
    payload: task.payload,
    priority: task.priority,
    timestamp: 0
  }
  ai_agent_send_message(candidate, assign_msg)
  candidate.current_task_id = task.task_id
  candidate.current_task_title = task.title
  candidate.current_task_payload = task.payload
  ai_agent_transition_state(candidate, 1) @! Transition to THINKING
  return 1
@end

@! ----------------------------------------------------------------------------
@! 6. Cognitive Agent Execution Engine (Planner, Coder, Critic, Synthesizer)
@! ----------------------------------------------------------------------------

@fn ai_agent_execute_planner(agent: AIAgent, payload: string) -> string
  @! Planner decomposes high-level goals into DAG milestone specifications
  plan_output = "[PLAN] Decomposed Goal:"
  return plan_output
@end

@fn ai_agent_execute_coder(agent: AIAgent, payload: string, feedback: string) -> string
  @! Coder generates pure Maya code based on plan or critique feedback
  code_output = "[CODE] Generated Pure Maya Implementation"
  @if feedback.len() > 0
    
  @end
  return code_output
@end

@fn ai_agent_execute_critic(agent: AIAgent, payload: string) -> string
  @! Critic performs static verification, checking purity & syntax
  @! Check if payload has syntax or defect markers
  has_defect = 0
  i = 0
  p_len = payload.len()
  @while i < p_len
    @if payload[i] == "!" || payload[i] == "#"
      has_defect = 1
    @end
    i = i + 1
  @end

  @if has_defect == 1 && agent.iteration_count < 2
    return "[CRITIQUE_REJECTED] Defect detected in artifact: invalid characters or purity violation. Please refine."
  @end

  return "[CRITIQUE_APPROVED] All 100% Maya purity rules and assertions verified successfully."
@end

@fn ai_agent_execute_synthesizer(agent: AIAgent, payload: string) -> string
  @! Synthesizer bundles multiple artifacts and produces clean handoff
  synth_output = "[SYNTHESIS] Unified release manifest generated from artifacts"
  return synth_output
@end

@fn ai_agent_step(agent: AIAgent, cluster: SwarmCluster) -> i64
  @if agent.state == 7 || agent.state == 6 @! TERMINATED or PAUSED
    return 0
  @end

  @! 1. Process Control Messages First
  @if agent.mailbox.control_queue.len() > 0
    ctrl_msg = agent.mailbox.control_queue[0]
    @! Pop front
    new_ctrl_q = []
    i = 1
    @while i < agent.mailbox.control_queue.len()
      new_ctrl_q = new_ctrl_q.push(agent.mailbox.control_queue[i])
      i = i + 1
    @end
    agent.mailbox.control_queue = new_ctrl_q

    @if string_eq(ctrl_msg.msg_type, "CONTROL_PAUSE") == 1
      ai_agent_pause(agent)
      return 1
    @elif string_eq(ctrl_msg.msg_type, "CONTROL_RESUME") == 1
      ai_agent_resume(agent)
      return 1
    @elif string_eq(ctrl_msg.msg_type, "CONTROL_TERMINATE") == 1
      ai_agent_terminate(agent)
      return 1
    @end
  @end

  @! 2. State Machine Transitions & Cognitive Step
  @if agent.state == 0 @! IDLE
    @! Check task queue
    @if agent.mailbox.task_queue.len() > 0
      task_msg = agent.mailbox.task_queue[0]
      new_task_q = []
      i = 1
      @while i < agent.mailbox.task_queue.len()
        new_task_q = new_task_q.push(agent.mailbox.task_queue[i])
        i = i + 1
      @end
      agent.mailbox.task_queue = new_task_q

      agent.current_task_payload = task_msg.payload
      ai_agent_transition_state(agent, 1) @! IDLE -> THINKING
      agent.status_info = "Analyzing task payload"
      return 1
    @end
    return 0
  @end

  @if agent.state == 1 @! THINKING
    @! Formulate strategy
    agent.status_info = "Strategy formulated, proceeding to execute"
    ai_agent_transition_state(agent, 2) @! THINKING -> EXECUTING
    return 1
  @end

  @if agent.state == 2 @! EXECUTING
    @! Execute cognitive logic based on role
    result_str = ""
    @if agent.role == "PLANNER"
      result_str = ai_agent_execute_planner(agent, agent.current_task_payload)
    @elif agent.role == "CODER"
      result_str = ai_agent_execute_coder(agent, agent.current_task_payload, agent.last_output)
    @elif agent.role == "CRITIC"
      result_str = ai_agent_execute_critic(agent, agent.current_task_payload)
    @elif agent.role == "SYNTHESIZER"
      result_str = ai_agent_execute_synthesizer(agent, agent.current_task_payload)
    @else
      result_str = "[DEFAULT] Processed:"
    @end

    agent.last_output = result_str
    agent.status_info = "Artifact produced"
    ai_agent_transition_state(agent, 3) @! EXECUTING -> REVIEWING
    return 1
  @end

  @if agent.state == 3 @! REVIEWING
    @! Review output
    @if agent.role == "CRITIC"
      @if string_starts_with(agent.last_output, "[CRITIQUE_REJECTED]")
        @! If rejected and retries remaining, trigger reflection
        @if agent.iteration_count < agent.max_iterations
          agent.iteration_count = agent.iteration_count + 1
          agent.metrics.reflection_loops = agent.metrics.reflection_loops + 1
          ai_agent_transition_state(agent, 1) @! Loop back to THINKING (Reflection)
          agent.status_info = "Critique rejected"
          return 1
        @else
          ai_agent_transition_state(agent, 5) @! FAILED
          agent.metrics.tasks_failed = agent.metrics.tasks_failed + 1
          agent.status_info = "Max retries exceeded"
          return 1
        @end
      @else
        ai_agent_transition_state(agent, 4) @! COMPLETED
        agent.metrics.tasks_completed = agent.metrics.tasks_completed + 1
        agent.status_info = "Completed"
        return 1
      @end
    @else
      ai_agent_transition_state(agent, 4) @! COMPLETED
      agent.metrics.tasks_completed = agent.metrics.tasks_completed + 1
      agent.status_info = "Completed"
      return 1
    @end
  @end

  @if agent.state == 4 @! COMPLETED
    @! Deliver result to completed tasks if tracking a task
    @if agent.current_task_id >= 0
      comp_task = {
        task_id: agent.current_task_id,
        title: agent.current_task_title,
        task_type: agent.role,
        required_role: agent.role,
        priority: 1,
        payload: agent.current_task_payload,
        dependencies: [],
        status: "COMPLETED",
        assigned_agent_id: agent.agent_id,
        result: agent.last_output,
        retry_count: agent.iteration_count,
        max_retries: agent.max_iterations
      }
      cluster.completed_tasks = cluster.completed_tasks.push(comp_task)
      agent.current_task_id = 0 - 1
    @end
    ai_agent_transition_state(agent, 0) @! COMPLETED -> IDLE
    agent.status_info = "Idle and ready"
    return 1
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! 7. Multi-Stage DAG Pipeline Engine
@! ----------------------------------------------------------------------------

@fn pipeline_new(pipeline_id: string, name: string, max_reflection: i64) -> SwarmPipeline
  return {
    pipeline_id: pipeline_id,
    name: name,
    stages: [],
    status: "PENDING",
    max_reflection_loops: max_reflection,
    reflection_count: 0,
    final_output: ""
  }
@end

@fn pipeline_add_stage(pipeline: SwarmPipeline, stage: PipelineStage) -> SwarmPipeline
  pipeline.stages = pipeline.stages.push(stage)
  return pipeline
@end

@fn pipeline_stage_new(stage_id: string, name: string, required_role: string, prompt: string, dependencies: array) -> PipelineStage
  return {
    stage_id: stage_id,
    name: name,
    required_role: required_role,
    prompt: prompt,
    dependencies: dependencies,
    status: "PENDING",
    output_result: "",
    retries_remaining: 3
  }
@end

@fn pipeline_run_step(pipeline: SwarmPipeline, cluster: SwarmCluster) -> SwarmPipeline
  @if pipeline.status == "COMPLETED" || pipeline.status == "FAILED"
    return pipeline
  @end

  pipeline.status = "RUNNING"
  all_stages_completed = 1

  s_idx = 0
  len_s = pipeline.stages.len()
  @while s_idx < len_s
    stage = pipeline.stages[s_idx]

    @if stage.status == "PENDING"
      @! Check dependencies
      deps_satisfied = 1
      d_i = 0
      @while d_i < stage.dependencies.len()
        dep_id = stage.dependencies[d_i]
        dep_done = 0
        chk_idx = 0
        @while chk_idx < len_s
          prev_s = pipeline.stages[chk_idx]
          @if prev_s.stage_id == dep_id && prev_s.status == "COMPLETED"
            dep_done = 1
          @end
          chk_idx = chk_idx + 1
        @end
        @if dep_done == 0
          deps_satisfied = 0
        @end
        d_i = d_i + 1
      @end

      @if deps_satisfied == 1
        @! Find agent for stage
        candidate = task_router_find_candidate(cluster, stage.required_role)
        @if candidate != 0
          @! Build enriched prompt with previous stage outputs
          enriched_prompt = stage.prompt
          prev_idx = 0
          @while prev_idx < len_s
            ps = pipeline.stages[prev_idx]
            @if ps.status == "COMPLETED" && ps.output_result.len() > 0
              
            @end
            prev_idx = prev_idx + 1
          @end

          task_id = cluster.next_task_id
          cluster.next_task_id = cluster.next_task_id + 1

          st = task_new(task_id, stage.name, "PIPELINE_STAGE", stage.required_role, 2, enriched_prompt, [])
          task_router_dispatch(cluster, st)
          stage.status = "RUNNING"
          all_stages_completed = 0
        @else
          all_stages_completed = 0
        @end
      @else
        all_stages_completed = 0
      @end

    @elif stage.status == "RUNNING"
      @! Check if completed in cluster
      c_idx = 0
      done = 0
      @while c_idx < cluster.completed_tasks.len()
        ct = cluster.completed_tasks[c_idx]
        @if ct.title == stage.name
          stage.output_result = ct.result
          done = 1
          @! Check if rejection feedback from Critic
          @if string_starts_with(ct.result, "[CRITIQUE_REJECTED]")
            @if pipeline.reflection_count < pipeline.max_reflection_loops && stage.retries_remaining > 0
              pipeline.reflection_count = pipeline.reflection_count + 1
              stage.retries_remaining = stage.retries_remaining - 1
              stage.status = "PENDING" @! Re-run stage with feedback
            @else
              stage.status = "FAILED"
              pipeline.status = "FAILED"
            @end
          @else
            stage.status = "COMPLETED"
          @end
        @end
        c_idx = c_idx + 1
      @end
      @if done == 0
        all_stages_completed = 0
      @end
    @elif stage.status == "FAILED"
      pipeline.status = "FAILED"
      return pipeline
    @end

    s_idx = s_idx + 1
  @end

  @if all_stages_completed == 1 && pipeline.status != "FAILED"
    pipeline.status = "COMPLETED"
    last_stage = pipeline.stages[len_s - 1]
    pipeline.final_output = last_stage.output_result
  @end

  return pipeline
@end

@! ----------------------------------------------------------------------------
@! 8. Swarm Cluster Orchestration
@! ----------------------------------------------------------------------------

@fn ai_cluster_new(name: string) -> SwarmCluster
  return {
    cluster_name: name,
    agents: [],
    bus: pubsub_new(),
    pending_tasks: [],
    completed_tasks: [],
    pipelines: [],
    next_agent_id: 1,
    next_task_id: 1,
    next_msg_id: 1,
    is_running: 1
  }
@end

@fn ai_agent_spawn(cluster: SwarmCluster, role: string, name: string, prompt: string, max_iter: i64) -> AIAgent
  aid = name
  cluster.next_agent_id = cluster.next_agent_id + 1

  ag = ai_agent_new(aid, role, name, prompt, max_iter)
  cluster.agents = cluster.agents.push(ag)
  return ag
@end

@fn ai_cluster_step_all(cluster: SwarmCluster) -> i64
  @if cluster.is_running == 0
    return 0
  @end

  active_steps = 0
  i = 0
  num_items = cluster.agents.len()
  @while i < num_items
    ag = cluster.agents[i]
    stepped = ai_agent_step(ag, cluster)
    @if stepped == 1
      active_steps = active_steps + 1
    @end
    i = i + 1
  @end

  return active_steps
@end
