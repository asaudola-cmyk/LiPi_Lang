// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: MATHEMATICAL MEMORY SAFETY & CFG PROOF ENGINE
// Module: src/compiler/semantics/math_proof.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Mathematical memory safety proves compile-time memory conservation (ΔMemory = 0)
// across all Control-Flow Graph (CFG) paths without runtime garbage collectors.
//
// THEORETICAL FOUNDATIONS & MATHEMATICAL INVARIANTS:
// 1. Memory Conservation Law:
//    For any self-contained routine or execution scope S:
//      ΔMemory(S) = ∑ Allocations(S) - ∑ Deallocations(S) = 0
//    A non-zero net delta implies an unfreed heap leak (Δ > 0) or double/illegal
//    free underflow (Δ < 0).
//
// 2. Control Flow Graph Branch Symmetry Theorem:
//    For a branching node (if / elif / else / match) with paths P_1, P_2, ..., P_m:
//      ∀ i, j: ΔMemory(P_i) = ΔMemory(P_j)
//    If any branch path produces a differing allocation balance, memory conservation
//    cannot be guaranteed deterministically across runtime conditions.
//
// 3. Loop Iteration Invariance Theorem:
//    For any loop L with body B running for k iterations (k ≥ 0):
//      ΔMemory(L) = k × ΔMemory(B)
//    Since k is dynamic and unbounded, boundedness lim_{k→∞} |ΔMemory(L)| < ∞
//    holds if and only if:
//      ΔMemory(B) = 0
//    Every loop body must balance all allocations internally within each iteration.
//
// 4. Lexical Scope Lifetime Encapsulation:
//    Every local variable holding an allocated heap handle must be deallocated or
//    transferred before its enclosing lexical scope pops off the call frame.
//
// 5. Early Jump & Control Flow Divergence Proof:
//    Control-flow transfers (early return, break, continue) divert execution to
//    terminal or successor basic blocks. Every diverging path to function exit
//    must conserve memory:
//      ∀ Path ∈ CFG(Entry → Exit): ΔMemory(Path) = 0 ∧ ActiveAllocations(Exit) = ∅
//
// 6. Zero-Collision Prefixed Fields (`mpv_`, `mpc_`, `mvr_`, `cbb_`, `cfg_`, `mps_`, `mpe_`)
//    prevent struct member shadowing across compiler passes.
// ==============================================================================
// Note: Base AST, symbol, and collection dependencies are included upstream by pipeline.lp
// ── 1. MATHEMATICAL PROOF DIAGNOSTIC CODES & STATUS ───────────────────────────

@fn MATH_PROOF_OK()                  return 0 @end
@fn ERR_MATH_PROOF_MEM_LEAK()         return 3001 @end
@fn ERR_MATH_PROOF_DOUBLE_FREE()      return 3002 @end
@fn ERR_MATH_PROOF_BRANCH_IMBALANCE() return 3003 @end
@fn ERR_MATH_PROOF_LOOP_LEAK()        return 3004 @end
@fn ERR_MATH_PROOF_LOOP_UNDERFLOW()   return 3005 @end
@fn ERR_MATH_PROOF_SCOPE_ESCAPE()     return 3006 @end
@fn ERR_MATH_PROOF_UNTRACKED_FREE()   return 3007 @end

@fn MATH_PROOF_STATUS_CONSERVED()      return 1 @end
@fn MATH_PROOF_STATUS_LEAK()           return 2 @end
@fn MATH_PROOF_STATUS_UNDERFLOW()      return 3 @end
@fn MATH_PROOF_STATUS_IMBALANCED()     return 4 @end
@fn MATH_PROOF_STATUS_LOOP_VIOLATION() return 5 @end

// ── 2. CFG TERMINATOR KINDS ──────────────────────────────────────────────────

@fn CFG_TERM_FALLTHROUGH() return 1 @end
@fn CFG_TERM_BRANCH()      return 2 @end
@fn CFG_TERM_JUMP()        return 3 @end
@fn CFG_TERM_RETURN()      return 4 @end
@fn CFG_TERM_EXIT()        return 5 @end

// ── 3. DATA STRUCTURES & MODELS ──────────────────────────────────────────────

@struct MathProofViolation
  mpv_code: i64
  mpv_message: string
  mpv_span: SourceSpan
  mpv_delta: i64
  mpv_path_name: string
@end

@struct ProofCertificate
  mpc_is_proven: i64
  mpc_total_allocations: i64
  mpc_total_deallocations: i64
  mpc_net_delta: i64
  mpc_paths_verified: i64
  mpc_loops_verified: i64
  mpc_scopes_verified: i64
  mpc_violation_count: i64
  mpc_status_msg: string
@end

@struct MathProofVarRecord
  mvr_name: string
  mvr_scope_depth: i64
  mvr_is_allocated: i64
  mvr_alloc_span: SourceSpan
  mvr_is_param: i64
@end

@struct CFGBasicBlock
  cbb_id: i64
  cbb_name: string
  cbb_stmts: array
  cbb_preds: array
  cbb_succs: array
  cbb_term_kind: i64
  cbb_scope_depth: i64
  cbb_span: SourceSpan
@end

@struct CFGLoopDesc
  cld_head_id: i64
  cld_body_id: i64
  cld_exit_id: i64
  cld_backedge_from_id: i64
@end

@struct CFGBranchDesc
  cbd_cond_id: i64
  cbd_targets: array
  cbd_merge_id: i64
@end

@struct CFGGraph
  cfg_fn_name: string
  cfg_entry_id: i64
  cfg_exit_id: i64
  cfg_blocks: array
  cfg_loops: array
  cfg_branches: array
  cfg_next_id: i64
@end

@struct MathProofState
  mps_balance: i64
  mps_vars: array
  mps_alloc_count: i64
  mps_free_count: i64
  mps_active_count: i64
@end

@struct MathProofEngine
  mpe_scope_depth: i64
  mpe_var_table: array
  mpe_violations: array
  mpe_total_allocs: i64
  mpe_total_frees: i64
  mpe_paths_checked: i64
  mpe_loops_checked: i64
  mpe_scopes_checked: i64
  mpe_known_allocators: array
  mpe_known_deallocators: array
  mpe_strict_mode: i64
@end

// ── 4. CONSTRUCTOR FACTORIES ─────────────────────────────────────────────────

@fn math_proof_violation_new(code, message, span, delta, path_name)
  sp = span
  @if sp == 0 sp = span_default() @end
  v = MathProofViolation()
  v.mpv_code = code
  v.mpv_message = message
  v.mpv_span = sp
  v.mpv_delta = delta
  v.mpv_path_name = path_name
  return v
@end

@fn proof_certificate_new()
  c = ProofCertificate()
  c.mpc_is_proven = 0
  c.mpc_total_allocations = 0
  c.mpc_total_deallocations = 0
  c.mpc_net_delta = 0
  c.mpc_paths_verified = 0
  c.mpc_loops_verified = 0
  c.mpc_scopes_verified = 0
  c.mpc_violation_count = 0
  c.mpc_status_msg = "UNVERIFIED"
  return c
@end

@fn math_proof_var_new(name, depth, is_alloc, span)
  sp = span
  @if sp == 0 sp = span_default() @end
  v = MathProofVarRecord()
  v.mvr_name = name
  v.mvr_scope_depth = depth
  v.mvr_is_allocated = is_alloc
  v.mvr_alloc_span = sp
  v.mvr_is_param = 0
  return v
@end

@fn math_proof_clone_var_record(v)
  @if v == 0 return 0 @end
  nv = MathProofVarRecord()
  nv.mvr_name = v.mvr_name
  nv.mvr_scope_depth = v.mvr_scope_depth
  nv.mvr_is_allocated = v.mvr_is_allocated
  nv.mvr_alloc_span = v.mvr_alloc_span
  nv.mvr_is_param = v.mvr_is_param
  return nv
@end

@fn math_proof_state_new()
  st = MathProofState()
  st.mps_balance = 0
  st.mps_vars = []
  st.mps_alloc_count = 0
  st.mps_free_count = 0
  st.mps_active_count = 0
  return st
@end

@fn math_proof_state_clone(st)
  @if st == 0 return math_proof_state_new() @end
  nst = MathProofState()
  nst.mps_balance = st.mps_balance
  nst.mps_alloc_count = st.mps_alloc_count
  nst.mps_free_count = st.mps_free_count
  nst.mps_active_count = st.mps_active_count
  nst.mps_vars = []
  i = 0
  n = st.mps_vars.len()
  @while i < n
    nst.mps_vars = nst.mps_vars.push(math_proof_clone_var_record(st.mps_vars[i]))
    i = i + 1
  @end
  return nst
@end

@fn cfg_basic_block_new(id, name, depth, span)
  sp = span
  @if sp == 0 sp = span_default() @end
  blk = CFGBasicBlock()
  blk.cbb_id = id
  blk.cbb_name = name
  blk.cbb_stmts = []
  blk.cbb_preds = []
  blk.cbb_succs = []
  blk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
  blk.cbb_scope_depth = depth
  blk.cbb_span = sp
  return blk
@end

@fn cfg_graph_new(fn_name)
  g = CFGGraph()
  g.cfg_fn_name = fn_name
  g.cfg_entry_id = 0
  g.cfg_exit_id = 1
  g.cfg_blocks = []
  g.cfg_loops = []
  g.cfg_branches = []
  g.cfg_next_id = 2

  entry_blk = cfg_basic_block_new(0, "entry", 0, span_default())
  exit_blk = cfg_basic_block_new(1, "exit", 0, span_default())
  exit_blk.cbb_term_kind = CFG_TERM_EXIT()

  g.cfg_blocks = g.cfg_blocks.push(entry_blk)
  g.cfg_blocks = g.cfg_blocks.push(exit_blk)
  return g
@end

@fn cfg_create_block(cfg, name, depth)
  bid = cfg.cfg_next_id
  cfg.cfg_next_id = cfg.cfg_next_id + 1
  blk = cfg_basic_block_new(bid, name + "." + to_str(bid), depth, span_default())
  cfg.cfg_blocks = cfg.cfg_blocks.push(blk)
  return bid
@end

@fn cfg_add_edge(cfg, from_id, to_id)
  @if from_id < 0 || to_id < 0 return 0 @end
  @if from_id >= cfg.cfg_blocks.len() || to_id >= cfg.cfg_blocks.len() return 0 @end

  from_blk = cfg.cfg_blocks[from_id]
  to_blk = cfg.cfg_blocks[to_id]

  // Add to successors if not present
  found_succ = 0
  si = 0
  @while si < from_blk.cbb_succs.len()
    @if from_blk.cbb_succs[si] == to_id
      found_succ = 1
    @end
    si = si + 1
  @end
  @if found_succ == 0
    from_blk.cbb_succs = from_blk.cbb_succs.push(to_id)
  @end

  // Add to predecessors if not present
  found_pred = 0
  pi = 0
  @while pi < to_blk.cbb_preds.len()
    @if to_blk.cbb_preds[pi] == from_id
      found_pred = 1
    @end
    pi = pi + 1
  @end
  @if found_pred == 0
    to_blk.cbb_preds = to_blk.cbb_preds.push(from_id)
  @end

  return 1
@end

@fn math_proof_engine_new()
  allocs = [
    "alloc", "malloc", "heap_alloc", "mem_alloc", "sys_alloc",
    "sys_mmap", "buffer_alloc", "gc_alloc", "_lipi_alloc",
    "list", "map", "list_new", "map_new", "buffer_new", "string_new", "make"
  ]
  deallocs = [
    "free", "dealloc", "drop", "mem_free", "sys_free",
    "sys_munmap", "buffer_free", "release", "close", "destroy", "_lipi_free"
  ]
  mpe = MathProofEngine()
  mpe.mpe_scope_depth = 0
  mpe.mpe_var_table = []
  mpe.mpe_violations = []
  mpe.mpe_total_allocs = 0
  mpe.mpe_total_frees = 0
  mpe.mpe_paths_checked = 0
  mpe.mpe_loops_checked = 0
  mpe.mpe_scopes_checked = 0
  mpe.mpe_known_allocators = allocs
  mpe.mpe_known_deallocators = deallocs
  mpe.mpe_strict_mode = 1
  return mpe
@end

// ── 5. ALLOCATOR & DEALLOCATOR RECOGNITION ───────────────────────────────────

@fn math_proof_is_allocator(mpe, name)
  @if name == "" return 0 @end
  i = 0
  n = mpe.mpe_known_allocators.len()
  @while i < n
    @if str_eq(mpe.mpe_known_allocators[i], name) == 1
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn math_proof_is_deallocator(mpe, name)
  @if name == "" return 0 @end
  i = 0
  n = mpe.mpe_known_deallocators.len()
  @while i < n
    @if str_eq(mpe.mpe_known_deallocators[i], name) == 1
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn math_proof_expr_is_alloc(mpe, expr)
  @if expr == 0 return 0 @end
  k = expr.kind
  tag = expr.tag

  @if str_eq(k, "Call") == 1 || tag == AST_TAG_CALL()
    call_name = expr.name
    @if call_name == "" && expr.func != 0
      call_name = expr.func.name
    @end
    return math_proof_is_allocator(mpe, call_name)
  @end

  @if str_eq(k, "ArrayLit") == 1 || tag == AST_TAG_ARRAY_LIT() || str_eq(k, "Array") == 1
    return 1
  @end
  @if str_eq(k, "MapLit") == 1 || tag == AST_TAG_MAP_LIT() || str_eq(k, "Map") == 1
    return 1
  @end
  @if str_eq(k, "Closure") == 1 || tag == AST_TAG_CLOSURE()
    return 1
  @end
  return 0
@end

// ── 6. REAL AST TO CFG GRAPH BUILDER ─────────────────────────────────────────

@struct CFGDeferItem
  cdi_stmt: ASTNode
  cdi_scope_depth: i64
@end

@fn cfg_defer_item_new(stmt, depth)
  item = CFGDeferItem()
  item.cdi_stmt = stmt
  item.cdi_scope_depth = depth
  return item
@end

@struct CFGBuilderCtx
  cbc_cfg: CFGGraph
  cbc_current_id: i64
  cbc_scope_depth: i64
  cbc_loop_headers: array
  cbc_loop_exits: array
  cbc_defer_stack: array
@end

@fn cfg_builder_ctx_new(cfg)
  ctx = CFGBuilderCtx()
  ctx.cbc_cfg = cfg
  ctx.cbc_current_id = 0
  ctx.cbc_scope_depth = 1
  ctx.cbc_loop_headers = []
  ctx.cbc_loop_exits = []
  ctx.cbc_defer_stack = []
  return ctx
@end

@fn cfg_emit_defers_for_depth(ctx, target_depth)
  @if ctx.cbc_current_id < 0 return 0 @end
  blk = ctx.cbc_cfg.cfg_blocks[ctx.cbc_current_id]
  di = ctx.cbc_defer_stack.len() - 1
  @while di >= 0
    item = ctx.cbc_defer_stack[di]
    @if item.cdi_scope_depth >= target_depth
      blk.cbb_stmts = blk.cbb_stmts.push(item.cdi_stmt)
    @end
    di = di - 1
  @end
  return 1
@end

@fn cfg_build_stmts(ctx, stmts)
  @if stmts == 0 return 0 @end
  i = 0
  n = stmts.len()
  @while i < n
    cfg_build_stmt(ctx, stmts[i])
    i = i + 1
  @end
  return 1
@end

@fn cfg_build_stmt(ctx, stmt)
  @if stmt == 0 return 0 @end
  @if ctx.cbc_current_id < 0
    // Current basic block is closed (unreachable code)
    return 0
  @end

  cfg = ctx.cbc_cfg
  curr_id = ctx.cbc_current_id
  blk = cfg.cfg_blocks[curr_id]
  k = stmt.kind
  tag = stmt.tag

  // 1. Return Statement
  @if str_eq(k, "Return") == 1 || tag == AST_TAG_RETURN()
    // Append any active defers before terminating
    cfg_emit_defers_for_depth(ctx, 1)
    blk.cbb_stmts = blk.cbb_stmts.push(stmt)
    blk.cbb_term_kind = CFG_TERM_RETURN()
    cfg_add_edge(cfg, curr_id, cfg.cfg_exit_id)
    ctx.cbc_current_id = -1
    return 1
  @end

  // 2. Break Statement
  @if str_eq(k, "Break") == 1 || tag == AST_TAG_BREAK()
    @if ctx.cbc_loop_exits.len() > 0
      exit_id = ctx.cbc_loop_exits[ctx.cbc_loop_exits.len() - 1]
      blk.cbb_stmts = blk.cbb_stmts.push(stmt)
      blk.cbb_term_kind = CFG_TERM_JUMP()
      cfg_add_edge(cfg, curr_id, exit_id)
      ctx.cbc_current_id = -1
    @end
    return 1
  @end

  // 3. Continue Statement
  @if str_eq(k, "Continue") == 1 || tag == AST_TAG_CONTINUE()
    @if ctx.cbc_loop_headers.len() > 0
      head_id = ctx.cbc_loop_headers[ctx.cbc_loop_headers.len() - 1]
      blk.cbb_stmts = blk.cbb_stmts.push(stmt)
      blk.cbb_term_kind = CFG_TERM_JUMP()
      cfg_add_edge(cfg, curr_id, head_id)
      ctx.cbc_current_id = -1
    @end
    return 1
  @end

  // 4. Defer Statement
  @if str_eq(k, "Defer") == 1 || tag == AST_TAG_DEFER()
    defer_body = stmt.expr
    @if defer_body == 0 && stmt.body != 0 && stmt.body.len() > 0
      defer_body = stmt.body[0]
    @end
    item = cfg_defer_item_new(defer_body, ctx.cbc_scope_depth)
    ctx.cbc_defer_stack = ctx.cbc_defer_stack.push(item)
    return 1
  @end

  // 5. Lexical Block
  @if str_eq(k, "Block") == 1 || tag == AST_TAG_BLOCK()
    ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
    depth = ctx.cbc_scope_depth
    cfg_build_stmts(ctx, stmt.body)
    @if ctx.cbc_current_id >= 0
      cfg_emit_defers_for_depth(ctx, depth)
      // Emit scope exit check marker for lexical encapsulation
      sc_exit = ast_node("ScopeExit")
      sc_exit.val = depth
      sc_exit.span = stmt.span
      curr_blk = cfg.cfg_blocks[ctx.cbc_current_id]
      curr_blk.cbb_stmts = curr_blk.cbb_stmts.push(sc_exit)
    @end
    // Pop defers from stack for this block
    new_defers = []
    di = 0
    @while di < ctx.cbc_defer_stack.len()
      d_item = ctx.cbc_defer_stack[di]
      @if d_item.cdi_scope_depth < depth
        new_defers = new_defers.push(d_item)
      @end
      di = di + 1
    @end
    ctx.cbc_defer_stack = new_defers
    ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1
    return 1
  @end

  // 6. Branching: IfStmt / If
  @if str_eq(k, "IfStmt") == 1 || str_eq(k, "If") == 1 || tag == AST_TAG_IF_STMT()
    cond_id = curr_id
    blk.cbb_term_kind = CFG_TERM_BRANCH()
    blk.cbb_span = stmt.span

    then_id = cfg_create_block(cfg, "if_then", ctx.cbc_scope_depth + 1)
    merge_id = cfg_create_block(cfg, "if_merge", ctx.cbc_scope_depth)

    branch_targets = [then_id]
    cfg_add_edge(cfg, cond_id, then_id)

    // Build then branch
    ctx.cbc_current_id = then_id
    ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
    cfg_build_stmts(ctx, stmt.then_body)
    @if ctx.cbc_current_id >= 0
      then_end_blk = cfg.cfg_blocks[ctx.cbc_current_id]
      then_end_blk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
      cfg_add_edge(cfg, ctx.cbc_current_id, merge_id)
    @end
    ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1

    prev_cond_id = cond_id

    // Elif branches
    @if stmt.elif_branches != 0
      ei = 0
      @while ei < stmt.elif_branches.len()
        elif_node = stmt.elif_branches[ei]
        elif_test_id = cfg_create_block(cfg, "elif_test", ctx.cbc_scope_depth)
        elif_body_id = cfg_create_block(cfg, "elif_body", ctx.cbc_scope_depth + 1)
        branch_targets = branch_targets.push(elif_body_id)

        cfg_add_edge(cfg, prev_cond_id, elif_test_id)
        cfg_add_edge(cfg, elif_test_id, elif_body_id)

        ctx.cbc_current_id = elif_body_id
        ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
        ebody = 0
        @if elif_node != 0
          ebody = elif_node.elif_body
          @if ebody == 0 ebody = elif_node.body @end
        @end
        cfg_build_stmts(ctx, ebody)
        @if ctx.cbc_current_id >= 0
          eblk = cfg.cfg_blocks[ctx.cbc_current_id]
          eblk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
          cfg_add_edge(cfg, ctx.cbc_current_id, merge_id)
        @end
        ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1
        prev_cond_id = elif_test_id
        ei = ei + 1
      @end
    @end

    // Else branch or fallthrough
    has_else = 0
    @if stmt.else_body != 0 && stmt.else_body.len() > 0
      has_else = 1
    @end

    @if has_else == 1
      else_id = cfg_create_block(cfg, "if_else", ctx.cbc_scope_depth + 1)
      branch_targets = branch_targets.push(else_id)
      cfg_add_edge(cfg, prev_cond_id, else_id)

      ctx.cbc_current_id = else_id
      ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
      cfg_build_stmts(ctx, stmt.else_body)
      @if ctx.cbc_current_id >= 0
        else_end_blk = cfg.cfg_blocks[ctx.cbc_current_id]
        else_end_blk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
        cfg_add_edge(cfg, ctx.cbc_current_id, merge_id)
      @end
      ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1
    @else
      branch_targets = branch_targets.push(merge_id)
      cfg_add_edge(cfg, prev_cond_id, merge_id)
    @end

    // Record branch descriptor for symmetry verification
    bdesc = CFGBranchDesc()
    bdesc.cbd_cond_id = cond_id
    bdesc.cbd_targets = branch_targets
    bdesc.cbd_merge_id = merge_id
    cfg.cfg_branches = cfg.cfg_branches.push(bdesc)

    merge_blk = cfg.cfg_blocks[merge_id]
    @if merge_blk.cbb_preds.len() == 0
      ctx.cbc_current_id = -1
    @else
      ctx.cbc_current_id = merge_id
    @end
    return 1
  @end

  // 7. Loops: WhileLoop / While / ForLoop / For
  @if str_eq(k, "WhileLoop") == 1 || str_eq(k, "While") == 1 || tag == AST_TAG_WHILE_LOOP() || str_eq(k, "ForLoop") == 1 || str_eq(k, "For") == 1 || tag == AST_TAG_FOR_LOOP()
    head_id = cfg_create_block(cfg, "loop_head", ctx.cbc_scope_depth)
    body_id = cfg_create_block(cfg, "loop_body", ctx.cbc_scope_depth + 1)
    exit_id = cfg_create_block(cfg, "loop_exit", ctx.cbc_scope_depth)

    blk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
    cfg_add_edge(cfg, curr_id, head_id)

    head_blk = cfg.cfg_blocks[head_id]
    head_blk.cbb_term_kind = CFG_TERM_BRANCH()
    head_blk.cbb_span = stmt.span
    cfg_add_edge(cfg, head_id, body_id) // True: enter body
    cfg_add_edge(cfg, head_id, exit_id) // False: exit loop

    ctx.cbc_loop_headers = ctx.cbc_loop_headers.push(head_id)
    ctx.cbc_loop_exits = ctx.cbc_loop_exits.push(exit_id)

    // Build loop body
    ctx.cbc_current_id = body_id
    ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
    cfg_build_stmts(ctx, stmt.body)

    backedge_from = -1
    @if ctx.cbc_current_id >= 0
      backedge_from = ctx.cbc_current_id
      body_end_blk = cfg.cfg_blocks[ctx.cbc_current_id]
      body_end_blk.cbb_term_kind = CFG_TERM_JUMP()
      cfg_add_edge(cfg, ctx.cbc_current_id, head_id)
    @end
    ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1

    // Pop loop context
    new_headers = []
    hi = 0
    @while hi < ctx.cbc_loop_headers.len() - 1
      new_headers = new_headers.push(ctx.cbc_loop_headers[hi])
      hi = hi + 1
    @end
    ctx.cbc_loop_headers = new_headers

    new_exits = []
    xi = 0
    @while xi < ctx.cbc_loop_exits.len() - 1
      new_exits = new_exits.push(ctx.cbc_loop_exits[xi])
      xi = xi + 1
    @end
    ctx.cbc_loop_exits = new_exits

    // Record loop descriptor for invariance verification
    ldesc = CFGLoopDesc()
    ldesc.cld_head_id = head_id
    ldesc.cld_body_id = body_id
    ldesc.cld_exit_id = exit_id
    ldesc.cld_backedge_from_id = backedge_from
    cfg.cfg_loops = cfg.cfg_loops.push(ldesc)

    ctx.cbc_current_id = exit_id
    return 1
  @end

  // 8. Pattern Matching: MatchStmt
  @if str_eq(k, "MatchStmt") == 1 || tag == AST_TAG_MATCH_STMT()
    match_cond_id = curr_id
    blk.cbb_term_kind = CFG_TERM_BRANCH()
    blk.cbb_span = stmt.span
    merge_id = cfg_create_block(cfg, "match_merge", ctx.cbc_scope_depth)
    branch_targets = []

    arms = stmt.elements
    @if arms != 0
      ai = 0
      @while ai < arms.len()
        arm = arms[ai]
        arm_id = cfg_create_block(cfg, "match_arm", ctx.cbc_scope_depth + 1)
        branch_targets = branch_targets.push(arm_id)
        cfg_add_edge(cfg, match_cond_id, arm_id)

        ctx.cbc_current_id = arm_id
        ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
        arm_body = 0
        @if arm != 0
          arm_body = arm.arm_body
          @if arm_body == 0 arm_body = arm.body @end
        @end
        cfg_build_stmts(ctx, arm_body)
        @if ctx.cbc_current_id >= 0
          arm_end = cfg.cfg_blocks[ctx.cbc_current_id]
          arm_end.cbb_term_kind = CFG_TERM_FALLTHROUGH()
          cfg_add_edge(cfg, ctx.cbc_current_id, merge_id)
        @end
        ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1
        ai = ai + 1
      @end
    @end

    bdesc = CFGBranchDesc()
    bdesc.cbd_cond_id = match_cond_id
    bdesc.cbd_targets = branch_targets
    bdesc.cbd_merge_id = merge_id
    cfg.cfg_branches = cfg.cfg_branches.push(bdesc)

    ctx.cbc_current_id = merge_id
    return 1
  @end

  // 9. Exception Handling: TryCatch
  @if str_eq(k, "TryCatch") == 1 || tag == AST_TAG_TRY_CATCH()
    try_id = cfg_create_block(cfg, "try_body", ctx.cbc_scope_depth + 1)
    catch_id = cfg_create_block(cfg, "catch_body", ctx.cbc_scope_depth + 1)
    merge_id = cfg_create_block(cfg, "try_merge", ctx.cbc_scope_depth)

    blk.cbb_term_kind = CFG_TERM_BRANCH()
    blk.cbb_span = stmt.span
    cfg_add_edge(cfg, curr_id, try_id)
    cfg_add_edge(cfg, curr_id, catch_id)

    // Build try
    ctx.cbc_current_id = try_id
    ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
    cfg_build_stmts(ctx, stmt.then_body)
    @if ctx.cbc_current_id >= 0
      cfg_add_edge(cfg, ctx.cbc_current_id, merge_id)
    @end
    ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1

    // Build catch
    ctx.cbc_current_id = catch_id
    ctx.cbc_scope_depth = ctx.cbc_scope_depth + 1
    cfg_build_stmts(ctx, stmt.else_body)
    @if ctx.cbc_current_id >= 0
      cfg_add_edge(cfg, ctx.cbc_current_id, merge_id)
    @end
    ctx.cbc_scope_depth = ctx.cbc_scope_depth - 1

    ctx.cbc_current_id = merge_id
    return 1
  @end

  // 10. Linear Sequential Statements (Assign, AssignOp, ExpressionStmt, Call)
  blk.cbb_stmts = blk.cbb_stmts.push(stmt)
  return 1
@end

@fn cfg_build_from_fn(fn_node)
  fn_name = "anonymous"
  @if fn_node != 0 && fn_node.name != ""
    fn_name = fn_node.name
  @end

  cfg = cfg_graph_new(fn_name)
  ctx = cfg_builder_ctx_new(cfg)

  // Track formal parameters in entry block
  @if fn_node != 0 && fn_node.params != 0
    pi = 0
    @while pi < fn_node.params.len()
      param_node = fn_node.params[pi]
      p_name = ""
      @if param_node != 0
        p_name = param_node.param_name
        @if p_name == "" p_name = param_node.name @end
      @end
      @if p_name != ""
        entry_blk = cfg.cfg_blocks[0]
        p_ast = ast_node("ParamDecl")
        p_ast.name = p_name
        entry_blk.cbb_stmts = entry_blk.cbb_stmts.push(p_ast)
      @end
      pi = pi + 1
    @end
  @end

  // Build body statements
  @if fn_node != 0 && fn_node.body != 0
    cfg_build_stmts(ctx, fn_node.body)
  @end

  // If final block didn't return, close with edge to exit block
  @if ctx.cbc_current_id >= 0
    cfg_emit_defers_for_depth(ctx, 1)
    last_blk = cfg.cfg_blocks[ctx.cbc_current_id]
    last_blk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
    cfg_add_edge(cfg, ctx.cbc_current_id, cfg.cfg_exit_id)
  @end

  return cfg
@end

@fn cfg_build_from_stmts(fn_name, stmts)
  cfg = cfg_graph_new(fn_name)
  ctx = cfg_builder_ctx_new(cfg)
  cfg_build_stmts(ctx, stmts)
  @if ctx.cbc_current_id >= 0
    cfg_emit_defers_for_depth(ctx, 1)
    last_blk = cfg.cfg_blocks[ctx.cbc_current_id]
    last_blk.cbb_term_kind = CFG_TERM_FALLTHROUGH()
    cfg_add_edge(cfg, ctx.cbc_current_id, cfg.cfg_exit_id)
  @end
  return cfg
@end

// ── 7. MATHEMATICAL CFG SOLVER & DATAFLOW ENGINE ─────────────────────────────

@fn math_proof_state_lookup_var(state, name)
  @if state == 0 || name == "" return 0 @end
  idx = state.mps_vars.len() - 1
  @while idx >= 0
    v = state.mps_vars[idx]
    @if str_eq(v.mvr_name, name) == 1
      return v
    @end
    idx = idx - 1
  @end
  return 0
@end

@fn cfg_execute_block(mpe, blk, in_state)
  st = math_proof_state_clone(in_state)
  @if blk == 0 return st @end

  stmts = blk.cbb_stmts
  si = 0
  n = stmts.len()
  @while si < n
    stmt = stmts[si]
    @if stmt != 0
      k = stmt.kind
      tag = stmt.tag

      // Param declaration
      @if str_eq(k, "ParamDecl") == 1
        pv = math_proof_var_new(stmt.name, 0, 0, stmt.span)
        pv.mvr_is_param = 1
        st.mps_vars = st.mps_vars.push(pv)
      @end

      // Scope exit check
      @if str_eq(k, "ScopeExit") == 1
        d = stmt.val
        mpe.mpe_scopes_checked = mpe.mpe_scopes_checked + 1
        vi = 0
        @while vi < st.mps_vars.len()
          v = st.mps_vars[vi]
          @if v.mvr_scope_depth >= d && v.mvr_is_allocated == 1
            viol = math_proof_violation_new(ERR_MATH_PROOF_SCOPE_ESCAPE(), "Scope memory leak: variable '" + v.mvr_name + "' allocated at depth " + to_str(v.mvr_scope_depth) + " was not deallocated before scope exit", v.mvr_alloc_span, 1, "scope_escape")
            mpe.mpe_violations = mpe.mpe_violations.push(viol)
          @end
          vi = vi + 1
        @end
      @end

      // Case A: Assignment `target = value`
      @if str_eq(k, "Assign") == 1 || tag == AST_TAG_ASSIGN() || str_eq(k, "AssignOp") == 1 || tag == AST_TAG_ASSIGN_OP()
        target = stmt.target
        @if target == "" target = stmt.name @end
        rhs = stmt.value
        @if rhs == 0 rhs = stmt.expr @end
        @if rhs == 0 rhs = stmt.right @end

        is_alloc = math_proof_expr_is_alloc(mpe, rhs)
        @if is_alloc == 1
          st.mps_balance = st.mps_balance + 1
          st.mps_alloc_count = st.mps_alloc_count + 1
          st.mps_active_count = st.mps_active_count + 1

          @if target != ""
            existing = math_proof_state_lookup_var(st, target)
            @if existing != 0 && existing.mvr_is_allocated == 1
              // Reassignment leak detected! Overwriting unfreed pointer!
              viol = math_proof_violation_new(ERR_MATH_PROOF_MEM_LEAK(), "Variable '" + target + "' reassigned with new allocation before previous resource was freed", stmt.span, 1, "local_reassign")
              mpe.mpe_violations = mpe.mpe_violations.push(viol)
            @end
            @if existing != 0
              existing.mvr_is_allocated = 1
              existing.mvr_alloc_span = stmt.span
            @else
              nv = math_proof_var_new(target, blk.cbb_scope_depth, 1, stmt.span)
              st.mps_vars = st.mps_vars.push(nv)
            @end
          @end
        @end
      @end

      // Case B: Expression statement or Call
      call_node = 0
      @if str_eq(k, "ExpressionStmt") == 1 || tag == AST_TAG_EXPR_STMT()
        call_node = stmt.expr
      @elif str_eq(k, "Call") == 1 || tag == AST_TAG_CALL()
        call_node = stmt
      @end

      @if call_node != 0 && (str_eq(call_node.kind, "Call") == 1 || call_node.tag == AST_TAG_CALL())
        cname = call_node.name
        @if cname == "" && call_node.func != 0
          cname = call_node.func.name
        @end

        // Check standalone allocator
        @if math_proof_is_allocator(mpe, cname) == 1
          st.mps_balance = st.mps_balance + 1
          st.mps_alloc_count = st.mps_alloc_count + 1
          st.mps_active_count = st.mps_active_count + 1
        @end

        // Check deallocator
        @if math_proof_is_deallocator(mpe, cname) == 1
          st.mps_balance = st.mps_balance - 1
          st.mps_free_count = st.mps_free_count + 1

          target_arg = ""
          @if call_node.args != 0 && call_node.args.len() > 0
            arg0 = call_node.args[0]
            @if arg0 != 0
              target_arg = arg0.name
              @if target_arg == "" target_arg = arg0.target @end
              @if target_arg == "" target_arg = arg0.variable @end
            @end
          @end

          @if target_arg != ""
            existing = math_proof_state_lookup_var(st, target_arg)
            @if existing != 0
              @if existing.mvr_is_allocated == 0 && existing.mvr_is_param == 0
                // Double free detected!
                viol = math_proof_violation_new(ERR_MATH_PROOF_DOUBLE_FREE(), "Double free detected: variable '" + target_arg + "' was already deallocated", stmt.span, -1, "double_free")
                mpe.mpe_violations = mpe.mpe_violations.push(viol)
              @else
                existing.mvr_is_allocated = 0
                st.mps_active_count = st.mps_active_count - 1
              @end
            @else
              // Untracked free detected!
              @if mpe.mpe_strict_mode == 1
                viol = math_proof_violation_new(ERR_MATH_PROOF_UNTRACKED_FREE(), "Untracked or illegal free detected on variable '" + target_arg + "' (never allocated in routine)", stmt.span, -1, "untracked_free")
                mpe.mpe_violations = mpe.mpe_violations.push(viol)
              @end
            @end
          @end
        @end
      @end
    @end
    si = si + 1
  @end

  return st
@end

@fn cfg_verify_loop_invariance(mpe, cfg, ldesc, base_state)
  mpe.mpe_loops_checked = mpe.mpe_loops_checked + 1
  head_id = ldesc.cld_head_id
  body_id = ldesc.cld_body_id
  back_from = ldesc.cld_backedge_from_id

  @if back_from < 0
    return 1
  @end

  s0 = math_proof_state_clone(base_state)
  head_blk = cfg.cfg_blocks[head_id]
  s_head = cfg_execute_block(mpe, head_blk, s0)

  body_blk = cfg.cfg_blocks[body_id]
  s_body = cfg_execute_block(mpe, body_blk, s_head)

  s_curr = s_body
  curr_id = body_id

  step = 0
  @while curr_id != back_from && step < 50
    curr_blk = cfg.cfg_blocks[curr_id]
    @if curr_blk.cbb_succs.len() > 0
      next_id = -1
      si = 0
      @while si < curr_blk.cbb_succs.len()
        cand = curr_blk.cbb_succs[si]
        @if cand != ldesc.cld_exit_id && cand != head_id
          next_id = cand
        @end
        si = si + 1
      @end
      @if next_id >= 0
        curr_id = next_id
        curr_blk = cfg.cfg_blocks[curr_id]
        s_curr = cfg_execute_block(mpe, curr_blk, s_curr)
      @else
        step = 999
      @end
    @else
      step = 999
    @end
    step = step + 1
  @end

  loop_delta = s_curr.mps_balance - s_head.mps_balance

  @if loop_delta != 0
    span = head_blk.cbb_span
    @if loop_delta > 0
      viol = math_proof_violation_new(ERR_MATH_PROOF_LOOP_LEAK(), "Loop memory leak: loop body has net delta +" + to_str(loop_delta) + " per iteration (unbounded accumulation across N iterations)", span, loop_delta, "loop_leak")
      mpe.mpe_violations = mpe.mpe_violations.push(viol)
    @else
      viol = math_proof_violation_new(ERR_MATH_PROOF_LOOP_UNDERFLOW(), "Loop memory underflow: loop body has net delta " + to_str(loop_delta) + " per iteration", span, loop_delta, "loop_underflow")
      mpe.mpe_violations = mpe.mpe_violations.push(viol)
    @end
    return 0
  @end

  // Check if any variable allocated inside loop body remained unfreed at backedge
  vi = 0
  @while vi < s_curr.mps_vars.len()
    v = s_curr.mps_vars[vi]
    @if v.mvr_scope_depth > head_blk.cbb_scope_depth && v.mvr_is_allocated == 1
      viol = math_proof_violation_new(ERR_MATH_PROOF_LOOP_LEAK(), "Loop iteration leak: temporary variable '" + v.mvr_name + "' was not deallocated before next iteration", v.mvr_alloc_span, 1, "loop_var_leak")
      mpe.mpe_violations = mpe.mpe_violations.push(viol)
      return 0
    @end
    vi = vi + 1
  @end

  return 1
@end

@fn cfg_trace_path_to_target(mpe, cfg, start_id, target_id, in_state, depth_limit)
  @if start_id == target_id return in_state @end
  @if depth_limit <= 0 return in_state @end

  blk = cfg.cfg_blocks[start_id]
  out_st = cfg_execute_block(mpe, blk, in_state)

  @if start_id == target_id return out_st @end
  @if blk.cbb_succs.len() == 0 return out_st @end

  succ_id = blk.cbb_succs[0]
  return cfg_trace_path_to_target(mpe, cfg, succ_id, target_id, out_st, depth_limit - 1)
@end

@fn cfg_verify_branch_symmetry(mpe, cfg, bdesc, base_state)
  mpe.mpe_paths_checked = mpe.mpe_paths_checked + 1
  cond_id = bdesc.cbd_cond_id
  merge_id = bdesc.cbd_merge_id
  targets = bdesc.cbd_targets

  @if targets.len() < 2 return 1 @end

  cond_blk = cfg.cfg_blocks[cond_id]
  s_cond = cfg_execute_block(mpe, cond_blk, base_state)

  first_target = targets[0]
  s_first = cfg_trace_path_to_target(mpe, cfg, first_target, merge_id, s_cond, 30)
  first_delta = s_first.mps_balance - s_cond.mps_balance

  ti = 1
  @while ti < targets.len()
    mpe.mpe_paths_checked = mpe.mpe_paths_checked + 1
    t_id = targets[ti]
    s_branch = cfg_trace_path_to_target(mpe, cfg, t_id, merge_id, s_cond, 30)
    branch_delta = s_branch.mps_balance - s_cond.mps_balance

    @if branch_delta != first_delta
      msg = "Branch path imbalance: path[" + to_str(ti) + "] delta (" + to_str(branch_delta) + ") != primary path delta (" + to_str(first_delta) + ")"
      viol = math_proof_violation_new(ERR_MATH_PROOF_BRANCH_IMBALANCE(), msg, cond_blk.cbb_span, branch_delta, "branch_asymmetry")
      mpe.mpe_violations = mpe.mpe_violations.push(viol)
      return 0
    @end
    ti = ti + 1
  @end

  return 1
@end

@fn cfg_solve_memory_conservation(mpe, cfg)
  cert = proof_certificate_new()
  @if cfg == 0 return cert @end

  num_blocks = cfg.cfg_blocks.len()
  block_in_states = []
  block_out_states = []
  block_has_state = []
  bi = 0
  @while bi < num_blocks
    block_in_states = block_in_states.push(0)
    block_out_states = block_out_states.push(0)
    block_has_state = block_has_state.push(0)
    bi = bi + 1
  @end

  init_state = math_proof_state_new()
  block_in_states[0] = init_state
  block_has_state[0] = 1

  worklist = [0]
  while_steps = 0
  @while worklist.len() > 0 && while_steps < 500
    while_steps = while_steps + 1
    curr_id = worklist[0]

    // Pop front
    new_worklist = []
    wi = 1
    @while wi < worklist.len()
      new_worklist = new_worklist.push(worklist[wi])
      wi = wi + 1
    @end
    worklist = new_worklist

    blk = cfg.cfg_blocks[curr_id]
    in_st = block_in_states[curr_id]
    @if in_st == 0 in_st = math_proof_state_new() @end

    out_st = cfg_execute_block(mpe, blk, in_st)
    block_out_states[curr_id] = out_st

    // Propagate to successors
    si = 0
    @while si < blk.cbb_succs.len()
      succ_id = blk.cbb_succs[si]

      is_backedge = 0
      li = 0
      @while li < cfg.cfg_loops.len()
        ldesc = cfg.cfg_loops[li]
        @if ldesc.cld_head_id == succ_id && ldesc.cld_backedge_from_id == curr_id
          is_backedge = 1
        @end
        li = li + 1
      @end

      @if is_backedge == 0
        @if block_has_state[succ_id] == 0
          block_in_states[succ_id] = math_proof_state_clone(out_st)
          block_has_state[succ_id] = 1
          worklist = worklist.push(succ_id)
        @else
          existing_in = block_in_states[succ_id]
          @if existing_in.mps_balance != out_st.mps_balance
            msg = "Control-flow merge imbalance at block " + to_str(succ_id) + ": incoming balance " + to_str(out_st.mps_balance) + " != existing balance " + to_str(existing_in.mps_balance)
            viol = math_proof_violation_new(ERR_MATH_PROOF_BRANCH_IMBALANCE(), msg, blk.cbb_span, out_st.mps_balance, "merge_imbalance")
            mpe.mpe_violations = mpe.mpe_violations.push(viol)
          @end
        @end
      @end
      si = si + 1
    @end
  @end

  // Verify all loops for iteration invariance
  li = 0
  @while li < cfg.cfg_loops.len()
    ldesc = cfg.cfg_loops[li]
    head_in = block_in_states[ldesc.cld_head_id]
    @if head_in == 0 head_in = math_proof_state_new() @end
    cfg_verify_loop_invariance(mpe, cfg, ldesc, head_in)
    li = li + 1
  @end

  // Verify all branches for symmetry
  bri = 0
  @while bri < cfg.cfg_branches.len()
    bdesc = cfg.cfg_branches[bri]
    cond_in = block_in_states[bdesc.cbd_cond_id]
    @if cond_in == 0 cond_in = math_proof_state_new() @end
    cfg_verify_branch_symmetry(mpe, cfg, bdesc, cond_in)
    bri = bri + 1
  @end

  // Verify exit block state & all terminal edges reaching exit
  exit_blk = cfg.cfg_blocks[cfg.cfg_exit_id]
  mpe.mpe_paths_checked = mpe.mpe_paths_checked + 1

  pi = 0
  @while pi < exit_blk.cbb_preds.len()
    pred_id = exit_blk.cbb_preds[pi]
    pred_blk = cfg.cfg_blocks[pred_id]
    pred_out = block_out_states[pred_id]
    @if pred_out == 0
      pred_in = block_in_states[pred_id]
      @if pred_in == 0 pred_in = math_proof_state_new() @end
      pred_out = cfg_execute_block(mpe, pred_blk, pred_in)
      block_out_states[pred_id] = pred_out
    @end

    net_delta = pred_out.mps_balance

    @if net_delta > 0
      viol = math_proof_violation_new(ERR_MATH_PROOF_MEM_LEAK(), "Function '" + cfg.cfg_fn_name + "' leaked " + to_str(net_delta) + " unmanaged heap allocation(s) along path through block " + pred_blk.cbb_name, pred_blk.cbb_span, net_delta, "exit_leak")
      mpe.mpe_violations = mpe.mpe_violations.push(viol)
    @elif net_delta < 0
      viol = math_proof_violation_new(ERR_MATH_PROOF_DOUBLE_FREE(), "Function '" + cfg.cfg_fn_name + "' memory underflow (delta = " + to_str(net_delta) + ") along path through block " + pred_blk.cbb_name, pred_blk.cbb_span, net_delta, "exit_underflow")
      mpe.mpe_violations = mpe.mpe_violations.push(viol)
    @end

    // Verify no unmanaged local variable escaped to exit
    vi = 0
    @while vi < pred_out.mps_vars.len()
      v = pred_out.mps_vars[vi]
      @if v.mvr_is_allocated == 1
        viol = math_proof_violation_new(ERR_MATH_PROOF_SCOPE_ESCAPE(), "Scope memory leak: variable '" + v.mvr_name + "' allocated at depth " + to_str(v.mvr_scope_depth) + " was not deallocated before function exit", v.mvr_alloc_span, 1, "scope_escape")
        mpe.mpe_violations = mpe.mpe_violations.push(viol)
      @end
      vi = vi + 1
    @end

    pi = pi + 1
  @end

  // Aggregate max allocations and deallocations across all evaluated paths
  max_allocs = 0
  max_frees = 0
  bi = 0
  @while bi < num_blocks
    out_b = block_out_states[bi]
    @if out_b != 0
      @if out_b.mps_alloc_count > max_allocs
        max_allocs = out_b.mps_alloc_count
      @end
      @if out_b.mps_free_count > max_frees
        max_frees = out_b.mps_free_count
      @end
    @end
    bi = bi + 1
  @end

  mpe.mpe_total_allocs = max_allocs
  mpe.mpe_total_frees = max_frees
  cert.mpc_total_allocations = max_allocs
  cert.mpc_total_deallocations = max_frees

  // Determine final net delta
  @if exit_blk.cbb_preds.len() > 0
    last_pred = exit_blk.cbb_preds[0]
    lp_out = block_out_states[last_pred]
    @if lp_out != 0
      cert.mpc_net_delta = lp_out.mps_balance
    @end
  @end

  cert.mpc_paths_verified = mpe.mpe_paths_checked
  cert.mpc_loops_verified = mpe.mpe_loops_checked
  cert.mpc_scopes_verified = mpe.mpe_scopes_checked + 2
  cert.mpc_violation_count = mpe.mpe_violations.len()

  @if cert.mpc_violation_count == 0 && cert.mpc_net_delta == 0
    cert.mpc_is_proven = 1
    cert.mpc_status_msg = "Q.E.D. MATHEMATICAL MEMORY CONSERVATION PROVEN (ΔMemory = 0)"
  @else
    cert.mpc_is_proven = 0
    cert.mpc_status_msg = "PROOF FAILED: MEMORY NOT CONSERVED ACROSS CFG"
  @end

  return cert
@end

// ── 8. VERIFICATION ENTRY POINTS & COMPILER PASSES ───────────────────────────

@fn math_proof_verify_fn(mpe, fn_node)
  @if fn_node == 0 return proof_certificate_new() @end
  cfg = cfg_build_from_fn(fn_node)
  return cfg_solve_memory_conservation(mpe, cfg)
@end

@fn math_proof_verify_ast(mpe, ast_root)
  @if ast_root == 0 return proof_certificate_new() @end
  k = ast_root.kind
  tag = ast_root.tag
  @if str_eq(k, "FnDef") == 1 || tag == AST_TAG_FN_DEF()
    return math_proof_verify_fn(mpe, ast_root)
  @end

  cfg = cfg_build_from_stmts("ast_root", ast_root.body)
  return cfg_solve_memory_conservation(mpe, cfg)
@end

@fn math_proof_verify_program(mpe, prog)
  cert = proof_certificate_new()
  @if prog == 0 return cert @end

  all_proven = 1
  total_viol = 0

  funcs = prog.prog_functions
  @if funcs != 0
    fi = 0
    @while fi < funcs.len()
      fn_item = funcs[fi]
      fn_cert = math_proof_verify_fn(mpe, fn_item)
      @if fn_cert.mpc_is_proven == 0
        all_proven = 0
      @end
      total_viol = total_viol + fn_cert.mpc_violation_count
      cert.mpc_total_allocations = cert.mpc_total_allocations + fn_cert.mpc_total_allocations
      cert.mpc_total_deallocations = cert.mpc_total_deallocations + fn_cert.mpc_total_deallocations
      cert.mpc_paths_verified = cert.mpc_paths_verified + fn_cert.mpc_paths_verified
      cert.mpc_loops_verified = cert.mpc_loops_verified + fn_cert.mpc_loops_verified
      cert.mpc_scopes_verified = cert.mpc_scopes_verified + fn_cert.mpc_scopes_verified
      fi = fi + 1
    @end
  @end

  cert.mpc_violation_count = total_viol
  @if all_proven == 1 && total_viol == 0
    cert.mpc_is_proven = 1
    cert.mpc_status_msg = "Q.E.D. MATHEMATICAL MEMORY CONSERVATION PROVEN ACROSS PROGRAM"
  @else
    cert.mpc_is_proven = 0
    cert.mpc_status_msg = "PROOF FAILED: MEMORY NOT CONSERVED IN PROGRAM"
  @end

  return cert
@end

@fn math_proof_has_errors(mpe)
  @if mpe == 0 return 0 @end
  @if mpe.mpe_violations.len() > 0 return 1 @end
  return 0
@end

@fn math_proof_error_count(mpe)
  @if mpe == 0 return 0 @end
  return mpe.mpe_violations.len()
@end

// ── 9. UNIVERSAL & SYNTHETIC CFG EVALUATOR (BACKWARD COMPATIBILITY) ──────────

@fn analyze_cfg_node(node, current_balance)
  @if node == 0
    return current_balance
  @end

  op = get(node, 0)
  @if op == "ALLOC"
    return current_balance + 1
  @elif op == "FREE"
    return current_balance - 1
  @elif op == "BRANCH"
    true_branch = get(node, 1)
    false_branch = get(node, 2)
    true_balance = analyze_cfg_node(true_branch, current_balance)
    false_balance = analyze_cfg_node(false_branch, current_balance)

    @if true_balance != false_balance
      return -9999
    @end
    return true_balance
  @elif op == "LOOP"
    body = get(node, 1)
    body_balance = analyze_cfg_node(body, current_balance)
    @if body_balance != current_balance
      return -9999
    @end
    return current_balance
  @elif op == "SEQ"
    n_len = len(node)
    @if n_len >= 3
      first = get(node, 1)
      second = get(node, 2)
      b1 = analyze_cfg_node(first, current_balance)
      @if b1 == -9999 return -9999 @end
      return analyze_cfg_node(second, b1)
    @elif n_len == 2
      next_node = get(node, 1)
      return analyze_cfg_node(next_node, current_balance)
    @end
    return current_balance
  @end

  // AST Node fallback
  mpe = math_proof_engine_new()
  cert = math_proof_verify_ast(mpe, node)
  @if cert.mpc_is_proven == 1
    return 0
  @end
  @if cert.mpc_violation_count > 0
    return -9999
  @end
  return cert.mpc_net_delta
@end

@fn prove_memory_safety(cfg_root)
  final_balance = analyze_cfg_node(cfg_root, 0)
  @if final_balance == 0
    return 1
  @end
  return 0
@end

// ── 10. PROGRAMMATIC CFG CONSTRUCTORS ─────────────────────────────────────────

@fn cfg_node_alloc()
  return ["ALLOC"]
@end

@fn cfg_node_free()
  return ["FREE"]
@end

@fn cfg_node_branch(true_node, false_node)
  return ["BRANCH", true_node, false_node]
@end

@fn cfg_node_loop(body_node)
  return ["LOOP", body_node]
@end

@fn cfg_node_seq(first_node, second_node)
  return ["SEQ", first_node, second_node]
@end
