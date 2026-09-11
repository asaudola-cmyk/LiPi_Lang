@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — NEURAL NETWORK MODULES & OPTIMIZERS (Tiers 1-4)
@! 100% Pure Maya Implementation — Zero Mock Logic
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"
import "universe/ai/nn"

@! ----------------------------------------------------------------------------
@! 0. Test Assertions Framework
@! ----------------------------------------------------------------------------

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

@fn assert_eq_int(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@fn assert_near_int(actual: i64, expected: i64, tol: i64, test_name: string) -> i64
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@! ============================================================================
@! Main NN Test Suite Runner (Tiers 1-4)
@! ============================================================================

@fn main() -> i64
  println("=================================================================")
  println("🤖 MAYA UNIVERSE NEURAL NETWORK MODULES & OPTIMIZERS TEST SUITE")
  println("=================================================================")

  @! ---------------------------------------------------------------------------
  @! [TIER 1: Parameter & Linear Layer Forward/Backward Tests]
  @! ---------------------------------------------------------------------------
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1: Parameter & Linear Layer Forward/Backward Tests]")
  println("-----------------------------------------------------------------")

  p = parameter_new([10, 20, 30], [1, 3])
  assert_eq_int(p.size, 3, "Parameter size == 3")
  assert_eq_int(p.requires_grad, 1, "Parameter requires_grad == 1")
  p.grad = [1, 1, 1]
  nn_zero_grad([p])
  assert_eq_int(p.grad[0], 0, "Parameter zero_grad reset element 0")
  assert_eq_int(p.grad[1], 0, "Parameter zero_grad reset element 1")
  assert_eq_int(p.grad[2], 0, "Parameter zero_grad reset element 2")

  @! 1.2 Linear Layer Forward Pass: Y = X @ W + b
  lin = linear_layer_new(2, 2)
  lin.weight.data = [2, 0, 1, 3]
  lin.bias.data = [10, 20]
  
  x = tensor_new([1, 2, 3, 4], [2, 2])
  y = linear_forward(lin, x)
  assert_eq_int(tensor_get_flat(y, 0), 14, "Linear Y[0, 0] == 14")
  assert_eq_int(tensor_get_flat(y, 1), 26, "Linear Y[0, 1] == 26")
  assert_eq_int(tensor_get_flat(y, 2), 20, "Linear Y[1, 0] == 20")
  assert_eq_int(tensor_get_flat(y, 3), 32, "Linear Y[1, 1] == 32")

  @! 1.3 Linear Layer Backward Pass
  grad_out = tensor_new([1, 1, 1, 1], [2, 2])
  nn_zero_grad([lin.weight, lin.bias])
  grad_x = linear_backward(lin, x, grad_out)
  assert_eq_int(lin.weight.grad[0], 4, "Linear dL/dW[0, 0] == 4")
  assert_eq_int(lin.weight.grad[1], 4, "Linear dL/dW[0, 1] == 4")
  assert_eq_int(lin.weight.grad[2], 6, "Linear dL/dW[1, 0] == 6")
  assert_eq_int(lin.weight.grad[3], 6, "Linear dL/dW[1, 1] == 6")
  assert_eq_int(lin.bias.grad[0], 2, "Linear dL/db[0] == 2")
  assert_eq_int(lin.bias.grad[1], 2, "Linear dL/db[1] == 2")

  @! ---------------------------------------------------------------------------
  @! [TIER 2: LayerNorm, Dropout & Loss Functions]
  @! ---------------------------------------------------------------------------
  println("-----------------------------------------------------------------")
  println("▶ [TIER 2: LayerNorm, Dropout & Loss Functions]")
  println("-----------------------------------------------------------------")

  @! 2.1 LayerNorm Forward Pass
  ln = layernorm_layer_new(4, 1)
  x_ln = tensor_new([10, 20, 30, 40], [1, 4])
  y_ln = layernorm_forward(ln, x_ln)
  sum_y = tensor_get_flat(y_ln, 0) + tensor_get_flat(y_ln, 1) + tensor_get_flat(y_ln, 2) + tensor_get_flat(y_ln, 3)
  assert_eq_int(sum_y, 0, "LayerNorm output zero-mean sum == 0")

  @! 2.2 Dropout (Eval vs Train Mode)
  x_drop = tensor_new([10, 20, 30, 40], [1, 4])
  drop = dropout_new(50)
  drop = dropout_eval(drop)
  eval_out = dropout_layer_forward(drop, x_drop)
  assert_eq_int(tensor_get_flat(eval_out, 0), 10, "Dropout eval mode preserves element 0")
  assert_eq_int(tensor_get_flat(eval_out, 3), 40, "Dropout eval mode preserves element 3")
  
  drop = dropout_train(drop)
  train_out = dropout_layer_forward(drop, x_drop)
  assert_eq_int(tensor_get_flat(train_out, 0), 20, "Dropout training mode scaled element 0 (x2)")
  assert_eq_int(tensor_get_flat(train_out, 1), 0, "Dropout training mode zeroed element 1")

  @! 2.3 MSE Loss
  pred_mse = tensor_new([10, 20], [1, 2])
  tgt_mse = tensor_new([6, 14], [1, 2])
  mse_res = loss_mse(pred_mse, tgt_mse)
  assert_eq_int(mse_res.loss, 26, "MSE Loss value == 26")
  assert_eq_int(tensor_get_flat(mse_res.loss_grad, 0), 4, "MSE Loss grad[0] == 4")
  assert_eq_int(tensor_get_flat(mse_res.loss_grad, 1), 6, "MSE Loss grad[1] == 6")

  @! 2.4 CrossEntropy Loss with Softmax
  logits = tensor_new([100, 500, 200], [1, 3])
  tgt_ce = tensor_new([0, 1000, 0], [1, 3])
  ce_res = loss_cross_entropy(logits, tgt_ce)
  is_pos = (ce_res.loss > 0 && ce_res.loss < 1000)
  assert_true(is_pos, "CrossEntropy loss is positive, bounded and stable")
  
  t_grad1 = tensor_get_flat(ce_res.loss_grad, 1)
  assert_true(t_grad1 < 0, "Target class gradient is negative in CrossEntropy")

  @! ---------------------------------------------------------------------------
  @! [TIER 3: Multi-Head Attention & Optimizer Step Tests]
  @! ---------------------------------------------------------------------------
  println("-----------------------------------------------------------------")
  println("▶ [TIER 3: Multi-Head Attention & Optimizer Step Tests]")
  println("-----------------------------------------------------------------")

  @! 3.1 Multi-Head Attention Forward Pass
  mha = multihead_attention_new(4, 2)
  x_seq = tensor_new([1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1], [3, 4])
  mha_out = multihead_attention_forward(mha, x_seq, 1)
  assert_eq_int(mha_out.shape[0], 3, "Attention output seq_len == 3")
  assert_eq_int(mha_out.shape[1], 4, "Attention output embed_dim == 4")

  @! 3.2 SGD Optimizer Step with Momentum & Weight Decay
  w_param = parameter_new([100, 200], [1, 2])
  w_param.grad = [10, 20]
  velocities = [[0, 0]]
  
  sgd_res = optimizer_sgd_step([w_param], 10, 90, 0, velocities)
  sgd_params = sgd_res[0]
  w_updated = sgd_params[0]
  velocities = sgd_res[1]
  assert_eq_int(w_updated.data[0], 99, "SGD updated weight 0 (100 -> 99)")
  assert_eq_int(w_updated.data[1], 198, "SGD updated weight 1 (200 -> 198)")

  @! 3.3 Adam Optimizer Step with Moments
  adam_param = parameter_new([100, 200], [1, 2])
  adam_param.grad = [50, 100]
  adam_state = optimizer_adam_new([adam_param])
  adam_res = optimizer_adam_step(adam_state, [adam_param], 10, 90, 99, 1)
  adam_state = adam_res[0]
  adam_params = adam_res[1]
  adam_p_updated = adam_params[0]
  
  assert_true(adam_p_updated.data[0] < 100, "Adam step decreased parameter 0 in descent direction")
  assert_true(adam_p_updated.data[1] < 200, "Adam step decreased parameter 1 in descent direction")

  @! ---------------------------------------------------------------------------
  @! [TIER 4: End-to-End Neural Network Training Convergence Loop]
  @! ---------------------------------------------------------------------------
  println("-----------------------------------------------------------------")
  println("▶ [TIER 4: End-to-End Neural Network Training Convergence Loop]")
  println("-----------------------------------------------------------------")

  @! Model: Linear Layer Y = X @ W + b
  @! Ground Truth target function: y = 2*x1 + 3*x2
  @! Dataset:
  @! X = [[1, 2], [2, 1], [3, 2], [1, 4]]
  @! Y_target = [[8], [7], [12], [14]]
  
  lin_model = linear_layer_new(2, 1)
  lin_model.weight.data = [0, 0]
  lin_model.bias.data = [0]
  
  x_train = tensor_new([1, 2, 2, 1, 3, 2, 1, 4], [4, 2])
  y_train = tensor_new([8, 7, 12, 14], [4, 1])
  
  params = [lin_model.weight, lin_model.bias]
  adam_opt = optimizer_adam_new(params)
  
  initial_loss = 0
  final_loss = 0
  
  epoch = 0
  @while epoch < 30
    @! 1. Zero gradients
    nn_zero_grad(params)
    
    @! 2. Forward Pass
    pred = linear_forward(lin_model, x_train)
    
    @! 3. Compute Loss
    loss_obj = loss_mse(pred, y_train)
    @if epoch == 0
      initial_loss = loss_obj.loss
      println("    Epoch 0 Initial Loss: " + initial_loss.to_str())
    @end
    @if epoch % 5 == 0 || epoch == 29
      println("    Epoch " + epoch.to_str() + " Loss: " + loss_obj.loss.to_str())
    @end
    @if epoch == 29
      final_loss = loss_obj.loss
    @end
    
    @! 4. Backward Pass
    grad_x_train = linear_backward(lin_model, x_train, loss_obj.loss_grad)
    
    @! 5. Optimizer Step (Adam)
    adam_res_loop = optimizer_adam_step(adam_opt, params, 1, 90, 99, 1)
    adam_opt = adam_res_loop[0]
    params = adam_res_loop[1]
    lin_model.weight = params[0]
    lin_model.bias = params[1]
    
    epoch = epoch + 1
  @end
  
  assert_true(initial_loss > 100, "Initial training loss is high (uninitialized weights)")
  assert_true(final_loss < 5, "Final training loss converged to near zero (< 5)")
  
  loss_reduction = initial_loss - final_loss
  assert_true(loss_reduction > 100, "Verified >95% empirical loss reduction: " + loss_reduction.to_str())
  
  assert_near_int(lin_model.weight.data[0], 2, 1, "Learned Weight 0 converged to target 2")
  assert_near_int(lin_model.weight.data[1], 3, 1, "Learned Weight 1 converged to target 3")

  @! ---------------------------------------------------------------------------
  @! [TIER 5: Embedding, AdamW & State Dict Serialization Tests]
  @! ---------------------------------------------------------------------------
  println("-----------------------------------------------------------------")
  println("▶ [TIER 5: Embedding, AdamW & State Dict Serialization Tests]")
  println("-----------------------------------------------------------------")

  @! 5.1 Embedding Layer
  emb = embedding_new(10, 4)
  assert_eq_int(emb.num_embeddings, 10, "Embedding vocab size == 10")
  assert_eq_int(emb.embedding_dim, 4, "Embedding dim == 4")
  
  tokens = [2, 0, 5]
  emb_out = embedding_forward(emb, tokens)
  assert_eq_int(emb_out.ndim, 2, "Embedding out ndim == 2")
  assert_eq_int(emb_out.shape[0], 3, "Embedding out seq_len == 3")
  assert_eq_int(emb_out.shape[1], 4, "Embedding out dim == 4")
  assert_eq_int(tensor_get_flat(emb_out, 0), emb.weight.data[8], "Embedding lookup matches row 2")

  @! 5.2 NamedParameter & State Dict Serialization
  p_w1 = parameter_new([10, 20], [2])
  p_b1 = parameter_new([5], [1])
  np1 = { name: "layer1.weight", param: p_w1 }
  np2 = { name: "layer1.bias", param: p_b1 }
  named_list = [np1, np2]
  
  sd = model_state_dict(named_list)
  assert_eq_int(sd.len(), 2, "State dict entry count == 2")
  
  @! Mutate parameters
  p_w1.data[0] = 999
  assert_eq_int(p_w1.data[0], 999, "Parameter mutated to 999")
  
  loaded = model_load_state_dict(named_list, sd)
  assert_eq_int(loaded, 2, "Loaded 2 entries from state dict")
  assert_eq_int(p_w1.data[0], 10, "Parameter restored to 10 from state dict")

  @! 5.3 AdamW Optimizer
  p_adamw = parameter_new([100], [1])
  p_adamw.grad = [10]
  opt_w = optimizer_adamw_new([p_adamw])
  step_res = optimizer_adamw_step(opt_w, [p_adamw], 1, 90, 99, 1, 10)
  p_after = step_res[1][0]
  assert_true(p_after.data[0] < 100, "AdamW step decreased parameter value from 100")

  println("=================================================================")
  println("🎉 ALL NN MODULES SUITE TESTS PASSED SUCCESSFULLY (5/5 TIERS)")
  println("=================================================================")
  return 0
@end
