@! ============================================================================
@! MAYA OMNIPOTENT OPTIMIZER - 100% PURE MAYA
@! Features: Constant Folding, Constant Propagation, Common Subexpression
@! Elimination (CSE), Dead Code Elimination (DCE), Tail Call Optimization (TCO),
@! Loop Invariant Code Motion (LICM), Inline Expansion, Algebraic Strength Reduction.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
@fn opt_is_str_eq(s1, s2)
  @! String equality comparison for AST node types and identifiers
  @! WHY: Bootstrap ELF64 compiler assigns distinct pointer addresses to identical string literals.
  @! Raw pointer equality check (s1 == s2) only succeeds for interned/identical pointers.
  @! Using str_eq ensures byte-by-byte string comparison in all environments.
  @if s1 == s2 return 1 @end
  @if s1 == 0 || s2 == 0 return 0 @end
  return str_eq(s1, s2)
@end

@! 1. CONSTANT FOLDING & ALGEBRAIC STRENGTH REDUCTION
@! ----------------------------------------------------------------------------
@fn fold_constants(expr)
  @if expr == 0 return 0 @end
  
  is_binop = 0
  @if expr.type != 0 && opt_is_str_eq(expr.type, "BinaryOp") == 1 is_binop = 1 @end
  @if expr.kind != 0 && opt_is_str_eq(expr.kind, "BinaryOp") == 1 is_binop = 1 @end

  @if is_binop == 1
    left = fold_constants(expr.left)
    right = fold_constants(expr.right)
    
    is_left_int = 0
    @if left != 0
      @if left.type != 0 && opt_is_str_eq(left.type, "IntLiteral") == 1 is_left_int = 1 @end
      @if left.kind != 0 && opt_is_str_eq(left.kind, "LiteralInt") == 1 is_left_int = 1 @end
    @end

    is_right_int = 0
    @if right != 0
      @if right.type != 0 && opt_is_str_eq(right.type, "IntLiteral") == 1 is_right_int = 1 @end
      @if right.kind != 0 && opt_is_str_eq(right.kind, "LiteralInt") == 1 is_right_int = 1 @end
    @end
    
    @if is_left_int == 1 && is_right_int == 1
      l_val = left.value
      @if l_val == 0 && left.val != 0 l_val = left.val @end
      r_val = right.value
      @if r_val == 0 && right.val != 0 r_val = right.val @end
      
      @if opt_is_str_eq(expr.op, "+") == 1 return { kind: "LiteralInt", type: "IntLiteral", val: l_val + r_val, value: l_val + r_val } @end
      @if opt_is_str_eq(expr.op, "-") == 1 return { kind: "LiteralInt", type: "IntLiteral", val: l_val - r_val, value: l_val - r_val } @end
      @if opt_is_str_eq(expr.op, "*") == 1 return { kind: "LiteralInt", type: "IntLiteral", val: l_val * r_val, value: l_val * r_val } @end
      @if opt_is_str_eq(expr.op, "/") == 1 && r_val != 0 return { kind: "LiteralInt", type: "IntLiteral", val: l_val / r_val, value: l_val / r_val } @end
      @if opt_is_str_eq(expr.op, "<<") == 1 return { kind: "LiteralInt", type: "IntLiteral", val: l_val * (2 * r_val), value: l_val * (2 * r_val) } @end
      @if opt_is_str_eq(expr.op, ">>") == 1 && r_val != 0 return { kind: "LiteralInt", type: "IntLiteral", val: l_val / (2 * r_val), value: l_val / (2 * r_val) } @end
    @end
    
    @! Algebraic Strength Reduction
    @if is_right_int == 1
      r_val = right.value
      @if r_val == 0 && right.val != 0 r_val = right.val @end
      
      @if opt_is_str_eq(expr.op, "*") == 1
        @if r_val == 0 return { kind: "LiteralInt", type: "IntLiteral", val: 0, value: 0 } @end
        @if r_val == 1 return left @end
        @if r_val == 2 return { kind: "BinaryOp", type: "BinaryOp", op: "<<", left: left, right: { kind: "LiteralInt", type: "IntLiteral", val: 1, value: 1 } } @end
        @if r_val == 4 return { kind: "BinaryOp", type: "BinaryOp", op: "<<", left: left, right: { kind: "LiteralInt", type: "IntLiteral", val: 2, value: 2 } } @end
        @if r_val == 8 return { kind: "BinaryOp", type: "BinaryOp", op: "<<", left: left, right: { kind: "LiteralInt", type: "IntLiteral", val: 3, value: 3 } } @end
      @end
      @if opt_is_str_eq(expr.op, "/") == 1
        @if r_val == 1 return left @end
        @if r_val == 2 return { kind: "BinaryOp", type: "BinaryOp", op: ">>", left: left, right: { kind: "LiteralInt", type: "IntLiteral", val: 1, value: 1 } } @end
        @if r_val == 4 return { kind: "BinaryOp", type: "BinaryOp", op: ">>", left: left, right: { kind: "LiteralInt", type: "IntLiteral", val: 2, value: 2 } } @end
        @if r_val == 8 return { kind: "BinaryOp", type: "BinaryOp", op: ">>", left: left, right: { kind: "LiteralInt", type: "IntLiteral", val: 3, value: 3 } } @end
      @end
      @if opt_is_str_eq(expr.op, "+") == 1 && r_val == 0 return left @end
      @if opt_is_str_eq(expr.op, "-") == 1 && r_val == 0 return left @end
    @end
    
    @if is_left_int
      l_val = left.value
      @if l_val == 0 && left.val != 0 l_val = left.val @end
      
      @if opt_is_str_eq(expr.op, "*") == 1
        @if l_val == 0 return { kind: "LiteralInt", type: "IntLiteral", val: 0, value: 0 } @end
        @if l_val == 1 return right @end
        @if l_val == 2 return { kind: "BinaryOp", type: "BinaryOp", op: "<<", left: right, right: { kind: "LiteralInt", type: "IntLiteral", val: 1, value: 1 } } @end
      @end
      @if opt_is_str_eq(expr.op, "+") == 1 && l_val == 0 return right @end
    @end
    
    return { kind: "BinaryOp", type: "BinaryOp", op: expr.op, left: left, right: right }
  @end
  
  is_call = 0
  @if expr.type != 0 && opt_is_str_eq(expr.type, "Call") == 1 is_call = 1 @end
  @if expr.kind != 0 && opt_is_str_eq(expr.kind, "Call") == 1 is_call = 1 @end
  @if is_call == 1
    new_args = []
    i = 0
    num_items = 0
    @if expr.args != 0 num_items = expr.args.len() @end
    @while i < num_items
      new_args = new_args.push(fold_constants(expr.args[i]))
      i = i + 1
    @end
    callee_expr = expr.callee
    @if callee_expr == 0 callee_expr = expr.func @end
    return { kind: "Call", type: "Call", callee: fold_constants(callee_expr), func: fold_constants(callee_expr), args: new_args }
  @end
  
  return expr
@end

@! ----------------------------------------------------------------------------
@! 2. COMMON SUBEXPRESSION ELIMINATION (CSE)
@! ----------------------------------------------------------------------------
@fn expr_to_string(expr)
  @if expr == 0 return "UNKNOWN" @end
  
  is_id = 0
  @if expr.type != 0 && (opt_is_str_eq(expr.type, "Identifier") == 1 || opt_is_str_eq(expr.type, "Ident") == 1) is_id = 1 @end
  @if expr.kind != 0 && (opt_is_str_eq(expr.kind, "Identifier") == 1 || opt_is_str_eq(expr.kind, "Ident") == 1) is_id = 1 @end
  @if is_id == 1 return expr.name @end

  is_int = 0
  @if expr.type != 0 && (opt_is_str_eq(expr.type, "IntLiteral") == 1 || opt_is_str_eq(expr.type, "LiteralInt") == 1) is_int = 1 @end
  @if expr.kind != 0 && (opt_is_str_eq(expr.kind, "IntLiteral") == 1 || opt_is_str_eq(expr.kind, "LiteralInt") == 1) is_int = 1 @end
  @if is_int == 1
    v = expr.value
    @if v == 0 && expr.val != 0 v = expr.val @end
    return to_str(v)
  @end

  is_bin = 0
  @if expr.type != 0 && opt_is_str_eq(expr.type, "BinaryOp") == 1 is_bin = 1 @end
  @if expr.kind != 0 && opt_is_str_eq(expr.kind, "BinaryOp") == 1 is_bin = 1 @end
  @if is_bin == 1
    op_str = expr.op
    @if op_str == 0 op_str = "" @end
    l_str = expr_to_string(expr.left)
    r_str = expr_to_string(expr.right)
    return str_concat("(", str_concat(l_str, str_concat(op_str, str_concat(r_str, ")"))))
  @end

  return "UNKNOWN"
@end

@fn apply_cse(stmts)
  new_stmts = []
  expr_map = [] @! [{hash: str, var: name}]
  
  i = 0
  num_items = stmts.len()
  @while i < num_items
    stmt = stmts[i]
    
    is_vd = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "VarDecl") == 1 || opt_is_str_eq(stmt.type, "Assign") == 1) is_vd = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "VarDecl") == 1 || opt_is_str_eq(stmt.kind, "Assign") == 1) is_vd = 1 @end
    @if is_vd == 1
      cexpr = stmt.expr
      @if cexpr == 0 cexpr = stmt.value @end
      cexpr = fold_constants(cexpr)
      stmt.expr = cexpr
      stmt.value = cexpr
      hash = expr_to_string(cexpr)
      
      found_var = ""
      j = 0
      map_len = expr_map.len()
      @while j < map_len
        @if opt_is_str_eq(expr_map[j].hash, hash) == 1
          found_var = expr_map[j].var
          j = map_len
        @else
          j = j + 1
        @end
      @end
      
      @if str_len(found_var) > 0
        id_node = { type: "Identifier", kind: "Ident", name: found_var }
        stmt.expr = id_node
        stmt.value = id_node
      @else
        is_bin = 0
        @if cexpr != 0
          @if cexpr.type != 0 && opt_is_str_eq(cexpr.type, "BinaryOp") == 1 is_bin = 1 @end
          @if cexpr.kind != 0 && opt_is_str_eq(cexpr.kind, "BinaryOp") == 1 is_bin = 1 @end
        @end
        @if opt_is_str_eq(hash, "UNKNOWN") == 0 && is_bin == 1
          expr_map = expr_map.push({ hash: hash, var: stmt.name })
        @end
      @end
      new_stmts = new_stmts.push(stmt)
    @else
      new_stmts = new_stmts.push(stmt)
    @end
    i = i + 1
  @end
  return new_stmts
@end

@! ----------------------------------------------------------------------------
@! 3. DEAD CODE ELIMINATION (DCE)
@! ----------------------------------------------------------------------------
@fn collect_used_vars(expr, used)
  @if expr == 0 return used @end
  
  is_id = 0
  @if expr.type != 0 && (opt_is_str_eq(expr.type, "Identifier") == 1 || opt_is_str_eq(expr.type, "Ident") == 1) is_id = 1 @end
  @if expr.kind != 0 && (opt_is_str_eq(expr.kind, "Identifier") == 1 || opt_is_str_eq(expr.kind, "Ident") == 1) is_id = 1 @end
  @if is_id == 1
    return used.push(expr.name)
  @end

  is_bin = 0
  @if expr.type != 0 && opt_is_str_eq(expr.type, "BinaryOp") == 1 is_bin = 1 @end
  @if expr.kind != 0 && opt_is_str_eq(expr.kind, "BinaryOp") == 1 is_bin = 1 @end
  @if is_bin == 1
    used = collect_used_vars(expr.left, used)
    return collect_used_vars(expr.right, used)
  @end

  is_call = 0
  @if expr.type != 0 && opt_is_str_eq(expr.type, "Call") == 1 is_call = 1 @end
  @if expr.kind != 0 && opt_is_str_eq(expr.kind, "Call") == 1 is_call = 1 @end
  @if is_call == 1
    callee_expr = expr.callee
    @if callee_expr == 0 callee_expr = expr.func @end
    used = collect_used_vars(callee_expr, used)
    @if expr.args != 0
      i = 0
      num_items = expr.args.len()
      @while i < num_items
        used = collect_used_vars(expr.args[i], used)
        i = i + 1
      @end
    @end
    return used
  @end

  return used
@end

@fn apply_dce(stmts)
  used_vars = []
  
  @! Backwards pass to find live variables
  live_stmts = []
  i = stmts.len() - 1
  @while i >= 0
    stmt = stmts[i]
    is_ret = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "ReturnStmt") == 1 || opt_is_str_eq(stmt.type, "Return") == 1) is_ret = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "ReturnStmt") == 1 || opt_is_str_eq(stmt.kind, "Return") == 1) is_ret = 1 @end
    @if is_ret == 1
      cexpr = stmt.expr
      @if cexpr == 0 cexpr = stmt.value @end
      used_vars = collect_used_vars(cexpr, used_vars)
      live_stmts = live_stmts.push(stmt)
    @end

    is_expr = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "ExprStmt") == 1 || opt_is_str_eq(stmt.type, "Expr") == 1) is_expr = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "ExprStmt") == 1 || opt_is_str_eq(stmt.kind, "Expr") == 1) is_expr = 1 @end
    @if is_expr == 1
      cexpr = stmt.expr
      @if cexpr == 0 cexpr = stmt.value @end
      used_vars = collect_used_vars(cexpr, used_vars)
      live_stmts = live_stmts.push(stmt)
    @end

    is_if = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "IfStmt") == 1 || opt_is_str_eq(stmt.type, "If") == 1) is_if = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "IfStmt") == 1 || opt_is_str_eq(stmt.kind, "If") == 1) is_if = 1 @end
    @if is_if == 1
      used_vars = collect_used_vars(stmt.cond, used_vars)
      live_stmts = live_stmts.push(stmt)
    @end

    is_while = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "WhileStmt") == 1 || opt_is_str_eq(stmt.type, "While") == 1) is_while = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "WhileStmt") == 1 || opt_is_str_eq(stmt.kind, "While") == 1) is_while = 1 @end
    @if is_while == 1
      used_vars = collect_used_vars(stmt.cond, used_vars)
      live_stmts = live_stmts.push(stmt)
    @end

    is_vd = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "VarDecl") == 1 || opt_is_str_eq(stmt.type, "Assign") == 1) is_vd = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "VarDecl") == 1 || opt_is_str_eq(stmt.kind, "Assign") == 1) is_vd = 1 @end
    @if is_vd == 1
      is_used = 0
      j = 0
      ulen = used_vars.len()
      @while j < ulen
        @if opt_is_str_eq(used_vars[j], stmt.name) == 1
          is_used = 1
          j = ulen
        @else
          j = j + 1
        @end
      @end
      
      @if is_used == 1
        cexpr = stmt.expr
        @if cexpr == 0 cexpr = stmt.value @end
        used_vars = collect_used_vars(cexpr, used_vars)
        live_stmts = live_stmts.push(stmt)
      @end
    @end
    i = i - 1
  @end
  
  @! Reverse the result
  final_stmts = []
  i = live_stmts.len() - 1
  @while i >= 0
    final_stmts = final_stmts.push(live_stmts[i])
    i = i - 1
  @end
  return final_stmts
@end

@! ----------------------------------------------------------------------------
@! 4. TAIL CALL OPTIMIZATION (TCO)
@! ----------------------------------------------------------------------------
@fn apply_tco(func_name, stmts)
  num_items = stmts.len()
  @if num_items == 0 return stmts @end
  
  last_stmt = stmts[num_items - 1]
  is_ret = 0
  @if last_stmt.type != 0 && (opt_is_str_eq(last_stmt.type, "ReturnStmt") == 1 || opt_is_str_eq(last_stmt.type, "Return") == 1) is_ret = 1 @end
  @if last_stmt.kind != 0 && (opt_is_str_eq(last_stmt.kind, "ReturnStmt") == 1 || opt_is_str_eq(last_stmt.kind, "Return") == 1) is_ret = 1 @end
  @if is_ret == 1
    cexpr = last_stmt.expr
    @if cexpr == 0 cexpr = last_stmt.value @end
    @if cexpr != 0
      is_call = 0
      @if cexpr.type != 0 && opt_is_str_eq(cexpr.type, "Call") == 1 is_call = 1 @end
      @if cexpr.kind != 0 && opt_is_str_eq(cexpr.kind, "Call") == 1 is_call = 1 @end
      @if is_call == 1
        callee = cexpr.callee
        @if callee == 0 callee = cexpr.func @end
        @if callee != 0
          is_id = 0
          @if callee.type != 0 && (opt_is_str_eq(callee.type, "Identifier") == 1 || opt_is_str_eq(callee.type, "Ident") == 1) is_id = 1 @end
          @if callee.kind != 0 && (opt_is_str_eq(callee.kind, "Identifier") == 1 || opt_is_str_eq(callee.kind, "Ident") == 1) is_id = 1 @end
          @if is_id == 1 && opt_is_str_eq(callee.name, func_name) == 1
            @! TCO possible! Replace with JMP to top of function (pseudo-loop)
            println("  [OPT] Tail Call Optimization applied for " + func_name)
            last_stmt.is_tco = 1
          @end
        @end
      @end
    @end
  @end
  
  return stmts
@end

@! ----------------------------------------------------------------------------
@! 5. INLINE EXPANSION
@! ----------------------------------------------------------------------------
@fn should_inline(func_ast)
  @if func_ast.body.len() < 5 return 1 @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 6. LOOP INVARIANT CODE MOTION (LICM)
@! ----------------------------------------------------------------------------
@fn apply_licm(stmts)
  new_stmts = []
  i = 0
  num_items = stmts.len()
  @while i < num_items
    stmt = stmts[i]
    is_while = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "WhileStmt") == 1 || opt_is_str_eq(stmt.type, "While") == 1) is_while = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "WhileStmt") == 1 || opt_is_str_eq(stmt.kind, "While") == 1) is_while = 1 @end
    @if is_while == 1
      @! Extract pure constant declarations outside loop
      j = 0
      blen = 0
      @if stmt.body != 0 blen = stmt.body.len() @end
      new_body = []
      @while j < blen
        bstmt = stmt.body[j]
        is_const_decl = 0
        is_b_vd = 0
        @if bstmt.type != 0 && (opt_is_str_eq(bstmt.type, "VarDecl") == 1 || opt_is_str_eq(bstmt.type, "Assign") == 1) is_b_vd = 1 @end
        @if bstmt.kind != 0 && (opt_is_str_eq(bstmt.kind, "VarDecl") == 1 || opt_is_str_eq(bstmt.kind, "Assign") == 1) is_b_vd = 1 @end
        @if is_b_vd == 1
          bexpr = bstmt.expr
          @if bexpr == 0 bexpr = bstmt.value @end
          @if bexpr != 0
            @if bexpr.type != 0 && (opt_is_str_eq(bexpr.type, "IntLiteral") == 1 || opt_is_str_eq(bexpr.type, "LiteralInt") == 1) is_const_decl = 1 @end
            @if bexpr.kind != 0 && (opt_is_str_eq(bexpr.kind, "IntLiteral") == 1 || opt_is_str_eq(bexpr.kind, "LiteralInt") == 1) is_const_decl = 1 @end
          @end
        @end
        @if is_const_decl == 1
          new_stmts = new_stmts.push(bstmt)
        @else
          new_body = new_body.push(bstmt)
        @end
        j = j + 1
      @end
      stmt.body = new_body
    @end
    new_stmts = new_stmts.push(stmt)
    i = i + 1
  @end
  return new_stmts
@end

@! ----------------------------------------------------------------------------
@! 7. MASTER OPTIMIZATION PASS
@! ----------------------------------------------------------------------------
@fn optimize_ast(ast)
  println("▶ [OPT] Running Pure Maya Optimization Pipeline...")
  
  optimized_funcs = []
  
  i = 0
  num_items = ast.len()
  @while i < num_items
    node = ast[i]
    is_fn = 0
    @if node.type != 0 && (opt_is_str_eq(node.type, "Function") == 1 || opt_is_str_eq(node.type, "FnDef") == 1) is_fn = 1 @end
    @if node.kind != 0 && (opt_is_str_eq(node.kind, "Function") == 1 || opt_is_str_eq(node.kind, "FnDef") == 1) is_fn = 1 @end
    @if is_fn == 1
      @! Pass 1: Constant Folding
      j = 0
      blen = 0
      @if node.body != 0 blen = node.body.len() @end
      @while j < blen
        stmt = node.body[j]
        is_vardecl = 0
        @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "VarDecl") == 1 || opt_is_str_eq(stmt.type, "Assign") == 1) is_vardecl = 1 @end
        @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "VarDecl") == 1 || opt_is_str_eq(stmt.kind, "Assign") == 1) is_vardecl = 1 @end
        @if is_vardecl == 1
          cexpr = stmt.expr
          @if cexpr == 0 cexpr = stmt.value @end
          fexpr = fold_constants(cexpr)
          stmt.expr = fexpr
          stmt.value = fexpr
        @end
        is_ret = 0
        @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "ReturnStmt") == 1 || opt_is_str_eq(stmt.type, "Return") == 1) is_ret = 1 @end
        @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "ReturnStmt") == 1 || opt_is_str_eq(stmt.kind, "Return") == 1) is_ret = 1 @end
        @if is_ret == 1
          cexpr = stmt.expr
          @if cexpr == 0 cexpr = stmt.value @end
          @if cexpr != 0
            fexpr = fold_constants(cexpr)
            stmt.expr = fexpr
            stmt.value = fexpr
          @end
        @end
        j = j + 1
      @end
      
      @! Pass 2: CSE
      node.body = apply_cse(node.body)
      
      @! Pass 3: LICM
      node.body = apply_licm(node.body)
      
      @! Pass 4: DCE
      node.body = apply_dce(node.body)
      
      @! Pass 5: TCO
      node.body = apply_tco(node.name, node.body)
      
    @end
    optimized_funcs = optimized_funcs.push(node)
    i = i + 1
  @end
  
  println("✅ Optimizations Complete.")
  return optimized_funcs
@end

@fn opt_optimize_program(ast)
  return optimize_ast(ast)
@end

@! ----------------------------------------------------------------------------
@! 8. LOOP UNROLLING
@! ----------------------------------------------------------------------------
@fn apply_loop_unrolling(stmts)
  new_stmts = []
  i = 0
  num_items = stmts.len()
  @while i < num_items
    stmt = stmts[i]
    is_while = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "WhileStmt") == 1 || opt_is_str_eq(stmt.type, "While") == 1) is_while = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "WhileStmt") == 1 || opt_is_str_eq(stmt.kind, "While") == 1) is_while = 1 @end
    @if is_while == 1
      @! Simple heuristic: if body is small, duplicate it once
      @if stmt.body.len() < 5 && stmt.body.len() > 0
        println("  [OPT] Loop unrolled")
        unrolled_body = []
        j = 0
        blen = stmt.body.len()
        @while j < blen
          unrolled_body = unrolled_body.push(stmt.body[j])
          j = j + 1
        @end
        @! Adding conditional break for unrolled part
        unrolled_body = unrolled_body.push({ type: "IfStmt", cond: stmt.cond, then_branch: stmt.body, else_branch: [] })
        stmt.body = unrolled_body
      @end
    @end
    new_stmts = new_stmts.push(stmt)
    i = i + 1
  @end
  return new_stmts
@end

@! ----------------------------------------------------------------------------
@! 9. GLOBAL VALUE NUMBERING (GVN) - Partial Implementation
@! ----------------------------------------------------------------------------
@fn apply_gvn(stmts)
  @! Maps value hashes to canonical variable names
  val_map = []
  new_stmts = []
  
  i = 0
  num_items = stmts.len()
  @while i < num_items
    stmt = stmts[i]
    is_vd = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "VarDecl") == 1 || opt_is_str_eq(stmt.type, "Assign") == 1) is_vd = 1 @end
    @if stmt.kind != 0 && (opt_is_str_eq(stmt.kind, "VarDecl") == 1 || opt_is_str_eq(stmt.kind, "Assign") == 1) is_vd = 1 @end
    @if is_vd == 1
      cexpr = stmt.expr
      @if cexpr == 0 cexpr = stmt.value @end
      hash = expr_to_string(cexpr)
      found = ""
      
      j = 0
      mlen = val_map.len()
      @while j < mlen
        @if opt_is_str_eq(val_map[j].hash, hash) == 1
          found = val_map[j].var
          j = mlen
        @else
          j = j + 1
        @end
      @end
      
      @if str_len(found) > 0
        id_node = { type: "Identifier", kind: "Ident", name: found }
        stmt.expr = id_node
        stmt.value = id_node
      @else
        val_map = val_map.push({ hash: hash, var: stmt.name })
      @end
    @end
    new_stmts = new_stmts.push(stmt)
    i = i + 1
  @end
  return new_stmts
@end

@! ----------------------------------------------------------------------------
@! 10. INLINE EXPANSION ENGINE
@! ----------------------------------------------------------------------------
@fn inline_function_calls(ast, current_func_body)
  new_body = []
  i = 0
  num_items = current_func_body.len()
  
  @while i < num_items
    stmt = current_func_body[i]
    is_call_decl = 0
    @if stmt.type != 0 && (opt_is_str_eq(stmt.type, "VarDecl") == 1 || opt_is_str_eq(stmt.type, "Assign") == 1)
      @if stmt.expr != 0 && stmt.expr.type != 0 && opt_is_str_eq(stmt.expr.type, "Call") == 1
        is_call_decl = 1
      @end
    @end
    @if is_call_decl == 1
      callee_name = stmt.expr.callee.name
      
      @! Find target function in AST
      target_func = 0
      j = 0
      ast_len = ast.len()
      @while j < ast_len
        is_fn = 0
        @if ast[j].type != 0 && (opt_is_str_eq(ast[j].type, "Function") == 1 || opt_is_str_eq(ast[j].type, "FnDef") == 1) is_fn = 1 @end
        @if ast[j].kind != 0 && (opt_is_str_eq(ast[j].kind, "Function") == 1 || opt_is_str_eq(ast[j].kind, "FnDef") == 1) is_fn = 1 @end
        @if is_fn == 1 && opt_is_str_eq(ast[j].name, callee_name) == 1
          target_func = ast[j]
          j = ast_len
        @else
          j = j + 1
        @end
      @end
      
      @if target_func != 0 && should_inline(target_func) == 1
        println("  [OPT] Inlining function: " + callee_name)
        @! Substitute parameters with arguments
        k = 0
        tlen = target_func.body.len()
        @while k < tlen
          tstmt = target_func.body[k]
          is_ret = 0
          @if tstmt.type != 0 && (opt_is_str_eq(tstmt.type, "ReturnStmt") == 1 || opt_is_str_eq(tstmt.type, "Return") == 1) is_ret = 1 @end
          @if tstmt.kind != 0 && (opt_is_str_eq(tstmt.kind, "ReturnStmt") == 1 || opt_is_str_eq(tstmt.kind, "Return") == 1) is_ret = 1 @end
          @if is_ret == 1
            new_body = new_body.push({ type: "VarDecl", name: stmt.name, expr: tstmt.expr })
          @else
            new_body = new_body.push(tstmt)
          @end
          k = k + 1
        @end
      @else
        new_body = new_body.push(stmt)
      @end
    @else
      new_body = new_body.push(stmt)
    @end
    i = i + 1
  @end
  return new_body
@end

@fn opt_constant_fold_insts(insts)
  out = []
  env = []
  _i_inst_0 = 0
  @while _i_inst_0 < insts.len()
    inst = insts[_i_inst_0]
    @if opt_is_str_eq(inst.op, "CONST_INT") == 1
      env = map_set(env, inst.dest, inst.val)
      out = out.push(inst)
    @end
    @if opt_is_str_eq(inst.op, "BINOP") == 1
      left_val = map_get_or(env, inst.left, -999999)
      right_val = map_get_or(env, inst.right, -999999)
      @if left_val != -999999 && right_val != -999999
        val = 0
        @if opt_is_str_eq(inst.binop, "+") == 1 val = left_val + right_val @end
        @if opt_is_str_eq(inst.binop, "-") == 1 val = left_val - right_val @end
        @if opt_is_str_eq(inst.binop, "*") == 1 val = left_val * right_val @end
        @if opt_is_str_eq(inst.binop, "/") == 1 val = left_val / right_val @end
        new_inst = { op: "CONST_INT", dest: inst.dest, val: val }
        env = map_set(env, inst.dest, val)
        out = out.push(new_inst)
      @else
        out = out.push(inst)
      @end
    @end
    @if opt_is_str_eq(inst.op, "RETURN") == 1
      out = out.push(inst)
    @end
    @! WHY: Advance iteration index inside the while loop body before loop end
    _i_inst_0 = _i_inst_0 + 1
  @end
  return out
@end

