// ============================================================================
// LIPI COMPILER — SOVEREIGN KAVACH SEMANTIC SHIELD (src/compiler/semantics/kavach_shield.lp)
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero Foreign Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Sovereign Silicon Crown Boundary (লিপির নিজস্ব কবচ):
//    - Instead of Rust's `unsafe { ... }` block syntax inside arbitrary business logic,
//      Lipi separates application logic from raw silicon mutations at the function boundary:
//      only explicitly crowned `silicon_*` / `সিলিকন_*` functions (and core `utso` memory/OS
//      primitives) may invoke direct kernel `syscall` or raw pointer writes (`mem_write`,
//      `mem_byte_write`, `sys_poke`).
// 2. Unified `--kavach` / `--কবচ` Mode:
//    - Combines (1) Affine Ownership & Borrow Check, (2) CFG Memory Conservation Proof
//      with escape-exact return ownership transfer, and (3) Sovereign Silicon Crown enforcement.
// 3. Zero-Collision Fields: Uses strict `kv_` field prefixes to guarantee zero offset collisions.
// ============================================================================

import "utso/string"
import "src/compiler/frontend/ast/ast_node"

struct KavachChecker
  kv_error_count
  kv_first_msg

fn kavach_checker_new
  kv = KavachChecker()
  kv.kv_error_count = 0
  kv.kv_first_msg = ""
  return kv

fn kavach_record_error kv fn_name call_name
  if kv.kv_error_count == 0
    kv.kv_first_msg = "Kavach Shield Violation in '" + fn_name + "': raw hardware op '" + call_name + "' requires a 'silicon_*' / 'সিলিকন_*' crowned function"
  end
  kv.kv_error_count = kv.kv_error_count + 1
  return 0

fn kavach_is_silicon_crowned fn_name
  if len(fn_name) == 0
    return 0
  end
  if str_starts_with(fn_name, "silicon_") == 1 or str_starts_with(fn_name, "সিলিকন_") == 1
    return 1
  end
  if str_starts_with(fn_name, "_lipi_") == 1
    return 1
  end
  // Trusted utso core OS/memory primitive namespaces
  if str_starts_with(fn_name, "sys_") == 1 or str_starts_with(fn_name, "mem_") == 1
    return 1
  end
  if str_starts_with(fn_name, "মেমরি_") == 1 or str_starts_with(fn_name, "file_") == 1 or str_starts_with(fn_name, "ফাইল_") == 1
    return 1
  end
  if str_starts_with(fn_name, "slab_") == 1 or str_starts_with(fn_name, "স্ল্যাব_") == 1 or str_starts_with(fn_name, "obj_") == 1 or str_starts_with(fn_name, "অবজেক্ট_") == 1
    return 1
  end
  if fn_name == "malloc" or fn_name == "free" or fn_name == "alloc" or fn_name == "বরাদ্দ" or fn_name == "মুক্ত"
    return 1
  end
  if fn_name == "write_out" or fn_name == "write_err" or fn_name == "write_file" or fn_name == "read_file"
    return 1
  end
  if fn_name == "println" or fn_name == "print_raw" or fn_name == "প্রিন্ট_র" or fn_name == "print_inline" or fn_name == "প্রিন্ট_ইনলাইন"
    return 1
  end
  if fn_name == "read_line" or fn_name == "রিড_লাইন" or fn_name == "path_exists"
    return 1
  end
  return 0

fn kavach_is_raw_hw_op call_name
  if call_name == "syscall" or call_name == "সিসকল"
    return 1
  end
  if call_name == "mem_write" or call_name == "mem_word_write" or call_name == "মেমরি_লেখো" or call_name == "মেমরি_শব্দ_লেখো"
    return 1
  end
  if call_name == "mem_byte_write" or call_name == "mem_write_byte" or call_name == "মেমরি_বাইট_লেখো"
    return 1
  end
  if call_name == "sys_poke" or call_name == "sys_poke8"
    return 1
  end
  return 0

fn kavach_scan_expr kv fn_name expr
  if expr == 0
    return 0
  end
  k = expr.kind
  tag = expr.tag

  if k == "ExprStmt" or k == "ExpressionStmt" or tag == AST_TAG_EXPR_STMT()
    return kavach_scan_expr(kv, fn_name, expr.expr)
  end

  if k == "Call" or k == "CallExpr" or tag == AST_TAG_CALL()
    cname = ""
    if expr.func != 0
      cname = expr.func.name
    end
    if cname == ""
      cname = expr.name
    end
    if kavach_is_raw_hw_op(cname) == 1
      kavach_record_error(kv, fn_name, cname)
    end
    cargs = expr.args
    if cargs == 0
      cargs = expr.params
    end
    if cargs != 0
      ai = 0
      while ai < cargs.len()
        kavach_scan_expr(kv, fn_name, cargs[ai])
        ai = ai + 1
      end
    end
    return 0
  end

  if k == "Binary" or k == "BinaryExpr" or k == "BinaryOp" or tag == AST_TAG_BINARY_OP()
    kavach_scan_expr(kv, fn_name, expr.left)
    kavach_scan_expr(kv, fn_name, expr.right)
    return 0
  end

  if k == "Unary" or k == "UnaryOp" or tag == AST_TAG_UNARY_OP()
    kavach_scan_expr(kv, fn_name, expr.expr)
    return 0
  end

  if k == "Index" or k == "Member" or k == "MemberAccess" or tag == AST_TAG_INDEX() or tag == AST_TAG_MEMBER_ACCESS()
    kavach_scan_expr(kv, fn_name, expr.left)
    if expr.right != 0
      kavach_scan_expr(kv, fn_name, expr.right)
    end
    if expr.index != 0
      kavach_scan_expr(kv, fn_name, expr.index)
    end
    return 0
  end

  if k == "ArrayLit" or k == "MapLit" or tag == AST_TAG_ARRAY_LIT() or tag == AST_TAG_MAP_LIT()
    if expr.elements != 0
      ei = 0
      while ei < expr.elements.len()
        kavach_scan_expr(kv, fn_name, expr.elements[ei])
        ei = ei + 1
      end
    end
    return 0
  end

  if k == "Closure" or tag == AST_TAG_CLOSURE()
    kavach_scan_stmt_list(kv, fn_name, expr.body)
    return 0
  end

  return 0

fn kavach_scan_stmt kv fn_name stmt
  if stmt == 0
    return 0
  end
  k = stmt.kind
  tag = stmt.tag

  if k == "Assign" or k == "AssignOp" or tag == AST_TAG_ASSIGN() or tag == AST_TAG_ASSIGN_OP()
    rhs = stmt.value
    if rhs == 0
      rhs = stmt.expr
    end
    kavach_scan_expr(kv, fn_name, rhs)
    return 0
  end

  if k == "ExprStmt" or k == "ExpressionStmt" or k == "Call" or k == "CallExpr" or tag == AST_TAG_EXPR_STMT() or tag == AST_TAG_CALL()
    kavach_scan_expr(kv, fn_name, stmt)
    return 0
  end

  if k == "Return" or k == "ফেরত" or tag == AST_TAG_RETURN()
    if stmt.expr != 0
      kavach_scan_expr(kv, fn_name, stmt.expr)
    end
    if stmt.value != 0
      kavach_scan_expr(kv, fn_name, stmt.value)
    end
    return 0
  end

  if k == "IfStmt" or k == "If" or k == "যদি" or tag == AST_TAG_IF_STMT()
    if stmt.condition != 0
      kavach_scan_expr(kv, fn_name, stmt.condition)
    else
      kavach_scan_expr(kv, fn_name, stmt.expr)
    end
    kavach_scan_stmt_list(kv, fn_name, stmt.then_body)
    if stmt.elif_branches != 0
      ei = 0
      while ei < stmt.elif_branches.len()
        eb = stmt.elif_branches[ei]
        if eb != 0
          kavach_scan_expr(kv, fn_name, eb.elif_condition)
          kavach_scan_stmt_list(kv, fn_name, eb.elif_body)
        end
        ei = ei + 1
      end
    end
    kavach_scan_stmt_list(kv, fn_name, stmt.else_body)
    return 0
  end

  if k == "While" or k == "WhileLoop" or k == "যতক্ষণ" or tag == AST_TAG_WHILE_LOOP()
    if stmt.condition != 0
      kavach_scan_expr(kv, fn_name, stmt.condition)
    else
      kavach_scan_expr(kv, fn_name, stmt.expr)
    end
    kavach_scan_stmt_list(kv, fn_name, stmt.body)
    return 0
  end

  if k == "For" or k == "ForLoop" or k == "প্রতিটি" or tag == AST_TAG_FOR_LOOP()
    if stmt.iterable != 0
      kavach_scan_expr(kv, fn_name, stmt.iterable)
    else
      kavach_scan_expr(kv, fn_name, stmt.expr)
    end
    kavach_scan_stmt_list(kv, fn_name, stmt.body)
    return 0
  end

  if k == "Block" or tag == AST_TAG_BLOCK() or k == "Defer" or tag == AST_TAG_DEFER()
    kavach_scan_stmt_list(kv, fn_name, stmt.body)
    if stmt.expr != 0
      kavach_scan_expr(kv, fn_name, stmt.expr)
    end
    return 0
  end

  if k == "MatchStmt" or tag == AST_TAG_MATCH_STMT()
    if stmt.expr != 0
      kavach_scan_expr(kv, fn_name, stmt.expr)
    end
    if stmt.elements != 0
      mi = 0
      while mi < stmt.elements.len()
        arm = stmt.elements[mi]
        if arm != 0
          kavach_scan_stmt_list(kv, fn_name, arm.arm_body)
        end
        mi = mi + 1
      end
    end
    return 0
  end

  if k == "TryCatch" or tag == AST_TAG_TRY_CATCH()
    kavach_scan_stmt_list(kv, fn_name, stmt.then_body)
    kavach_scan_stmt_list(kv, fn_name, stmt.else_body)
    return 0
  end

  return 0

fn kavach_scan_stmt_list kv fn_name stmts
  if stmts == 0
    return 0
  end
  si = 0
  n = stmts.len()
  while si < n
    kavach_scan_stmt(kv, fn_name, stmts[si])
    si = si + 1
  end
  return 0

fn kavach_verify_program ast_decls
  kv = kavach_checker_new()
  if ast_decls == 0
    return kv
  end
  di = 0
  n = ast_decls.len()
  while di < n
    decl = ast_decls[di]
    if decl != 0
      if decl.kind == "FnDef" or decl.kind == "Function" or decl.kind == "কাজ" or decl.tag == AST_TAG_FN_DEF()
        if kavach_is_silicon_crowned(decl.name) == 0
          kavach_scan_stmt_list(kv, decl.name, decl.body)
        end
      end
    end
    di = di + 1
  end
  return kv
