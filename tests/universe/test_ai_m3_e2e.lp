@! ============================================================================
@! MAYA UNIVERSE MASTER END-TO-END INTEGRATION TEST: NATIVE AI NEURAL SWARM
@! Module: tests/universe/test_ai_m3_e2e.maya
@! Milestone: Milestone 3 (Native AI Neural Swarm)
@! Scope: End-to-end integration exercising Tensor -> Autograd -> NN -> Transformer -> Swarm
@! 100% Pure Maya Implementation — Zero Foreign / C++ / Python Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"
import "universe/ai/autograd"
import "universe/ai/nn"
import "universe/ai/transformer/gpt"
import "universe/ai/swarm"

@fn assert_eq_int(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_true(cond: i64, test_name: string) -> i64
  @if cond
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@! ============================================================================
@! Section 1: End-to-End Deep Learning Training Pipeline (F14, F15, F16)
@! ============================================================================

@fn run_e2e_deep_learning_pipeline() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [E2E SECTION 1: Deep Learning Training Pipeline (F14 - F16)]")
  println("-----------------------------------------------------------------")

  @! 1. Embedding Layer Lookup
  emb = embedding_new(8, 4)
  token_seq = [1, 3, 5]
  emb_out = embedding_forward(emb, token_seq)
  assert_eq_int(emb_out.ndim, 2, "Embedding output ndim == 2")
  assert_eq_int(emb_out.shape[0], 3, "Embedding sequence length == 3")
  assert_eq_int(emb_out.shape[1], 4, "Embedding dimension == 4")

  @! 2. Multi-Layer Perceptron (Linear1 -> ReLU -> Linear2)
  w1 = leaf_tensor([1, 0, 0, 1, 0, 1, 1, 0], [4, 2])
  b1 = leaf_tensor([1, 1], [1, 2])
  w2 = leaf_tensor([2, 1], [2, 1])
  b2 = leaf_tensor([0], [1, 1])

  h1_raw = tensor_add(tensor_matmul(emb_out, w1), b1)
  h1_act = tensor_relu(h1_raw)
  y_pred = tensor_add(tensor_matmul(h1_act, w2), b2)
  assert_eq_int(y_pred.shape[0], 3, "MLP output batch/seq == 3")
  assert_eq_int(y_pred.shape[1], 1, "MLP output dim == 1")

  @! 3. Target and Loss Computation (MSE)
  y_target = tensor_new([5, 8, 4], [3, 1])
  loss = tensor_sum(tensor_mul(tensor_sub(y_pred, y_target), tensor_sub(y_pred, y_target)), 0 - 1, 0)
  assert_true(loss.data[0] >= 0, "Loss value is non-negative")

  @! 4. Reverse-Mode Autograd Backpropagation
  tensor_backward(loss)
  assert_true(w1.grad.len() == 8, "w1 gradient buffer populated")
  assert_true(w2.grad.len() == 2, "w2 gradient buffer populated")

  @! 5. AdamW Optimizer Step with Decoupled Weight Decay
  opt = optimizer_adamw_new([w1, w2])
  opt_res = optimizer_adamw_step(opt, [w1, w2], 1, 90, 99, 1, 10)
  assert_eq_int(opt_res[1].len(), 2, "AdamW updated 2 weight tensors")

  @! 6. Model State Dict Serialization & Checkpointing
  named_weights = [
    { name: "mlp.w1", param: w1 },
    { name: "mlp.w2", param: w2 }
  ]
  chk = model_state_dict(named_weights)
  assert_eq_int(chk.len(), 2, "Checkpoint state dict contains 2 tensors")
  
  w1.data[0] = 777
  model_load_state_dict(named_weights, chk)
  assert_true(w1.data[0] != 777, "Weight restored successfully from state dict")

  println("    ✓ [PASS] Section 1: DL Pipeline (Embedding -> MLP -> Autograd -> AdamW -> Serialization) passed!")
  return 1
@end

@! ============================================================================
@! Section 2: End-to-End LLM Transformer & Sampling Pipeline (F17)
@! ============================================================================

@fn run_e2e_transformer_pipeline() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [E2E SECTION 2: LLM Transformer & Sampling Pipeline (F17)]")
  println("-----------------------------------------------------------------")

  @! 1. Transformer Initialization
  gpt = gpt_transformer_init("MayaGPT-M3", 1000, 64, 4, 2)
  assert_eq_int(gpt.num_heads, 4, "Model num_heads == 4")
  assert_eq_int(gpt.head_dim, 16, "Model head_dim == 16")

  @! 2. KV-Cache Ring Buffer Management
  k_token0 = [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8]
  v_token0 = [10, 20, 30, 40, 50, 60, 70, 80, 10, 20, 30, 40, 50, 60, 70, 80]
  gpt.kv_cache = kv_cache_append(gpt.kv_cache, k_token0, v_token0)
  assert_eq_int(gpt.kv_cache.current_pos, 1, "KV-Cache step 1 pos == 1")

  @! 3. FlashAttention Step
  q_query = [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8]
  attn_head_out = flash_attention_forward_head(q_query, gpt.kv_cache.k_cache_flat, gpt.kv_cache.v_cache_flat, 1, 16)
  assert_eq_int(attn_head_out.len(), 16, "Attention output dim matches head_dim (16)")

  @! 4. Sampler Engine (Top-K & Top-P Nucleus)
  logits = [10, 20, 85, 40, 5, 12, 90, 15]
  sampler_cfg = {
    temperature: 70,
    top_k: 3,
    top_p: 85
  }
  next_token = gpt_sample_token_advanced(logits, sampler_cfg)
  assert_eq_int(next_token, 6, "Sampled token matches argmax token index 6 (logit 90)")

  println("    ✓ [PASS] Section 2: LLM Pipeline (KV-Cache -> FlashAttention -> Nucleus Sampling) passed!")
  return 1
@end

@! ============================================================================
@! Section 3: End-to-End Autonomous Cognitive Swarm & Task Routing (F18, F19)
@! ============================================================================

@fn run_e2e_swarm_pipeline() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [E2E SECTION 3: Autonomous Cognitive Swarm & Task Routing (F18/F19)]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("m3_master_cluster")

  @! 1. Spawn Cognitive Roles
  planner = ai_agent_spawn(cluster, role_planner(), "LeadArchitect", "Decompose user mission", 3)
  coder = ai_agent_spawn(cluster, role_coder(), "SeniorCoder", "Implement pure Maya code", 3)
  critic = ai_agent_spawn(cluster, role_critic(), "ChiefAuditor", "Zero-defect purity enforcement", 3)
  synth = ai_agent_spawn(cluster, role_synthesizer(), "ReleaseManager", "Package milestone deliverables", 3)

  assert_eq_int(cluster.agents.len(), 4, "Swarm cluster active agents == 4")

  @! 2. Topic Pub/Sub Event Bus Verification
  pubsub_subscribe(cluster.bus, "planning/goals", coder.agent_id)
  pubsub_subscribe(cluster.bus, "code/proposals", critic.agent_id)
  pubsub_subscribe(cluster.bus, "synthesis/requests", synth.agent_id)
  assert_eq_int(cluster.bus.subscriptions.len(), 3, "Topic subscriptions == 3")

  @! 3. Multi-Stage DAG Workflow Pipeline
  pl = pipeline_new("m3_e2e_pipeline", "Full AI Stack Autonomous Engineering", 3)
  st1 = pipeline_stage_new("st1", "Milestone Planning", role_planner(), "Decompose M3 Native AI Swarm Architecture", [])
  st2 = pipeline_stage_new("st2", "Module Implementation", role_coder(), "Implement pure Maya Tensor and Swarm modules", ["st1"])
  st3 = pipeline_stage_new("st3", "Purity & Quality Audit", role_critic(), "Audit zero foreign code and test assertions", ["st2"])
  st4 = pipeline_stage_new("st4", "Sovereign Synthesis", role_synthesizer(), "Generate M3 handoff artifact and release manifest", ["st3"])

  pl = pipeline_add_stage(pl, st1)
  pl = pipeline_add_stage(pl, st2)
  pl = pipeline_add_stage(pl, st3)
  pl = pipeline_add_stage(pl, st4)

  assert_eq_int(pl.stages.len(), 4, "Workflow pipeline initialized with 4 DAG stages")

  @! Step through pipeline until fully completed
  steps = 0
  @while pl.status != "COMPLETED" && pl.status != "FAILED" && steps < 30
    pl = pipeline_run_step(pl, cluster)
    ai_cluster_step_all(cluster)
    steps = steps + 1
  @end

  assert_eq_int(pl.status == "COMPLETED", 1, "Multi-stage pipeline successfully COMPLETED")
  assert_true(pl.final_output.len() > 0, "Final release manifest produced")
  assert_true(planner.metrics.tasks_completed > 0, "Planner completed task")
  assert_true(coder.metrics.tasks_completed > 0, "Coder completed task")
  assert_true(critic.metrics.tasks_completed > 0, "Critic completed audit")
  assert_true(synth.metrics.tasks_completed > 0, "Synthesizer completed release")

  println("    ✓ [PASS] Section 3: Autonomous Cognitive Swarm & DAG Workflow passed!")
  return 1
@end

@! ============================================================================
@! Master E2E Runner
@! ============================================================================

@fn main() -> i64
  println("=================================================================")
  println("🌟 MAYA UNIVERSE MILESTONE 3 (NATIVE AI NEURAL SWARM) E2E MASTER")
  println("=================================================================")

  s1 = run_e2e_deep_learning_pipeline()
  s2 = run_e2e_transformer_pipeline()
  s3 = run_e2e_swarm_pipeline()

  total = s1 + s2 + s3
  println("=================================================================")
  println("🏆 ALL MILESTONE 3 E2E INTEGRATION SECTIONS PASSED (" + total.to_str() + "/3)")
  println("   F14: N-D Tensor Engine ................... [VERIFIED]")
  println("   F15: Autograd Differentiation DAG ........ [VERIFIED]")
  println("   F16: Neural Network Architecture ......... [VERIFIED]")
  println("   F17: LLM Transformer & FlashAttention .... [VERIFIED]")
  println("   F18: Autonomous Multi-Agent Swarm ........ [VERIFIED]")
  println("   F19: Autonomous Dynamic Task Router ...... [VERIFIED]")
  println("=================================================================")
  return 0
@end
