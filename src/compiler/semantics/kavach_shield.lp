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
  kv_utso_ranges

fn kavach_checker_new
  kv = KavachChecker()
  kv.kv_error_count = 0
  kv.kv_first_msg = ""
  kv.kv_utso_ranges = 0
  return kv

fn kavach_record_error kv fn_name call_name
  if kv.kv_error_count == 0
    kv.kv_first_msg = "Kavach Shield Violation in '" + fn_name + "': raw hardware op '" + call_name + "' requires a 'silicon_*' / 'সিলিকন_*' crowned function"
  end
  kv.kv_error_count = kv.kv_error_count + 1
  return 0

fn kavach_line_in_utso line_no utso_ranges
  // WHY: Verifies whether a 1-based bundled source line originates from an authentic `utso/`
  // stdlib file recorded by the driver bundler, preventing user-space function name spoofing.
  if utso_ranges == 0 or line_no <= 0
    return 0
  end
  ri = 0
  rlen = utso_ranges.len()
  while ri + 1 < rlen
    if line_no >= utso_ranges[ri] and line_no <= utso_ranges[ri + 1]
      return 1
    end
    ri = ri + 2
  end
  return 0
end

fn kavach_node_in_utso(node: ASTNode, utso_ranges)
  if node == 0 or utso_ranges == 0
    return 0
  end
  sp: SourceSpan = node.span
  if sp == 0
    return 0
  end
  return kavach_line_in_utso(sp.span_start_line, utso_ranges)
end

fn kavach_is_silicon_crowned fn_name
  // WHY: Outside authentic `utso/` stdlib provenance ranges, ONLY explicitly crowned
  // `silicon_*` / `সিলিকন_*` functions may invoke raw hardware/kernel operations.
  // Never exempt user functions by spoofable names like `file_open`, `malloc`, or `_lipi_*`.
  if len(fn_name) == 0
    return 0
  end
  if str_starts_with(fn_name, "silicon_") == 1 or str_starts_with(fn_name, "সিলিকন_") == 1
    return 1
  end
  return 0
end

fn kavach_is_raw_hw_op call_name
  if call_name == "syscall" or call_name == "সিসকল" or call_name == "sys_syscall"
    return 1
  end
  if call_name == "mem_write" or call_name == "mem_word_write" or call_name == "মেমরি_লেখো" or call_name == "মেমরি_শব্দ_লেখো" or call_name == "mem_write_word"
    return 1
  end
  if call_name == "mem_byte_write" or call_name == "mem_write_byte" or call_name == "মেমরি_বাইট_লেখো" or call_name == "mem_byte_লেখো"
    return 1
  end
  if call_name == "mem_write_u64" or call_name == "mem_write_u32" or call_name == "mem_write_f64" or call_name == "mem_write_f32" or call_name == "মেমরি_দশমিক_লেখো" or call_name == "mem_write_idx" or call_name == "মেমরি_সূচক_লেখো"
    return 1
  end
  if call_name == "mem_copy" or call_name == "মেমরি_কপি" or call_name == "mem_fill" or call_name == "মেমরি_ভরাট" or call_name == "mem_zero" or call_name == "মেমরি_শূন্য"
    return 1
  end
  if call_name == "mem_read" or call_name == "mem_word_read" or call_name == "মেমরি_পড়ো" or call_name == "মেমরি_শব্দ_পড়ো" or call_name == "mem_read_word"
    return 1
  end
  if call_name == "mem_byte_read" or call_name == "mem_read_byte" or call_name == "মেমরি_বাইট_পড়ো" or call_name == "mem_read_u64" or call_name == "mem_read_u32" or call_name == "mem_read_f64" or call_name == "mem_read_f32" or call_name == "মেমরি_দশমিক_পড়ো" or call_name == "mem_read_idx" or call_name == "মেমরি_সূচক_পড়ো"
    return 1
  end
  if call_name == "sys_poke" or call_name == "sys_poke8" or call_name == "sys_peek" or call_name == "sys_peek8" or call_name == "sys_mmap" or call_name == "sys_munmap"
    return 1
  end
  // Sovereign Ring-0 Privileged & Hardware MMIO / Port I/O / Inline Assembly Authority Guard
  if call_name == "@asm" or call_name == "@অ্যাসেম্বলি" or call_name == "uefi_call" or call_name == "ms_x64_call"
    return 1
  end
  if call_name == "port_in8" or call_name == "port_out8" or call_name == "port_in16" or call_name == "port_out16" or call_name == "port_in32" or call_name == "port_out32" or call_name == "inb" or call_name == "outb" or call_name == "inw" or call_name == "outw" or call_name == "inl" or call_name == "outl" or call_name == "পোর্ট_পড়ো৮" or call_name == "পোর্ট_লেখো৮" or call_name == "পোর্ট_পড়ো১৬" or call_name == "পোর্ট_লেখো১৬" or call_name == "পোর্ট_পড়ো৩২" or call_name == "পোর্ট_লেখো৩২"
    return 1
  end
  if call_name == "mmio_r8" or call_name == "mmio_w8" or call_name == "mmio_r16" or call_name == "mmio_w16" or call_name == "mmio_r32" or call_name == "mmio_w32" or call_name == "mmio_r64" or call_name == "mmio_w64" or call_name == "mmio_read8" or call_name == "mmio_write8" or call_name == "mmio_read16" or call_name == "mmio_write16" or call_name == "mmio_read32" or call_name == "mmio_write32" or call_name == "mmio_read32_hw" or call_name == "mmio_write32_hw" or call_name == "mmio_read64" or call_name == "mmio_write64"
    return 1
  end
  if call_name == "mem_u8_read" or call_name == "mem_u8_write" or call_name == "mem_u16_read" or call_name == "mem_u16_write" or call_name == "mem_u32_read" or call_name == "mem_u32_write" or call_name == "mem_u64_read" or call_name == "mem_u64_write"
    return 1
  end
  if call_name == "cpu_cli" or call_name == "cli" or call_name == "cpu_sti" or call_name == "sti" or call_name == "cpu_hlt" or call_name == "hlt" or call_name == "cpu_lgdt" or call_name == "lgdt" or call_name == "cpu_lidt" or call_name == "lidt" or call_name == "cpu_sgdt" or call_name == "sgdt" or call_name == "cpu_sidt" or call_name == "sidt" or call_name == "cpu_ltr" or call_name == "ltr" or call_name == "cpu_read_cr0" or call_name == "read_cr0" or call_name == "cpu_write_cr0" or call_name == "write_cr0" or call_name == "cpu_read_cr2" or call_name == "read_cr2" or call_name == "cpu_read_cr3" or call_name == "read_cr3" or call_name == "cpu_write_cr3" or call_name == "write_cr3" or call_name == "cpu_read_cr4" or call_name == "read_cr4" or call_name == "cpu_write_cr4" or call_name == "write_cr4" or call_name == "cpu_rdmsr" or call_name == "rdmsr" or call_name == "cpu_wrmsr" or call_name == "wrmsr" or call_name == "cpu_invlpg" or call_name == "invlpg" or call_name == "cpu_swapgs" or call_name == "swapgs" or call_name == "cpu_wbinvd"
    return 1
  end
  return 0
end

fn kavach_is_ident_byte b
  if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b == 95 or b == 64 or b >= 128
    return 1
  end
  return 0
end

fn kavach_scan_interp_str kv fn_name stext
  // WHY: Interpolated strings (`"${expr}"` / `"{expr}"`) are re-lexed and compiled by backends.
  // Scanning every identifier inside `${...}` and `{...}` blocks raw hardware ops like
  // `"${syscall(60, 42, 0, 0, 0, 0, 0)}"` from bypassing --kavach!
  n = len(stext)
  i = 0
  while i < n
    b = mem_byte_read(stext, i) & 255
    is_expr_start = 0
    expr_start = 0
    if b == 36 and i + 1 < n and (mem_byte_read(stext, i + 1) & 255) == 123
      is_expr_start = 1
      expr_start = i + 2
    elif b == 123
      is_expr_start = 1
      expr_start = i + 1
    end
    if is_expr_start == 1
      // Find matching '}' respecting nested braces and quoted strings
      dep = 1
      j = expr_start
      in_q = 0
      while j < n and dep > 0
        c = mem_byte_read(stext, j) & 255
        if in_q != 0
          if c == 92 and j + 1 < n
            j = j + 2
            continue
          elif c == in_q
            in_q = 0
          end
        else
          if c == 34 or c == 39
            in_q = c
          elif c == 123
            dep = dep + 1
          elif c == 125
            dep = dep - 1
            if dep == 0
              break
            end
          end
        end
        j = j + 1
      end
      // Scan identifiers inside [expr_start .. j) (outside nested string literals)
      k = expr_start
      q2 = 0
      while k < j
        c2 = mem_byte_read(stext, k) & 255
        if q2 != 0
          if c2 == 92 and k + 1 < j
            k = k + 2
            continue
          elif c2 == q2
            q2 = 0
          end
          k = k + 1
          continue
        end
        if c2 == 34 or c2 == 39
          q2 = c2
          k = k + 1
          continue
        end
        if kavach_is_ident_byte(c2) == 1
          id_s = k
          while k < j and kavach_is_ident_byte(mem_byte_read(stext, k) & 255) == 1
            k = k + 1
          end
          ident = str_sub(stext, id_s, k)
          if kavach_is_raw_hw_op(ident) == 1
            kavach_record_error(kv, fn_name, ident)
          end
          continue
        end
        k = k + 1
      end
      if j < n
        i = j + 1
      else
        i = n
      end
      continue
    end
    i = i + 1
  end
  return 0
end

fn kavach_scan_expr kv fn_name expr
  if expr == 0
    return 0
  end
  k = expr.kind
  tag = expr.tag

  if k == "LiteralStr" or k == "StrLiteral" or tag == AST_TAG_LITERAL_STR()
    if expr.op == "interp" and expr.name != 0 and len(expr.name) > 0
      kavach_scan_interp_str(kv, fn_name, expr.name)
    end
    return 0
  end

  if k == "ExprStmt" or k == "ExpressionStmt" or tag == AST_TAG_EXPR_STMT()
    return kavach_scan_expr(kv, fn_name, expr.expr)
  end

  if k == "Variable" or k == "IDENT" or k == "Identifier" or tag == AST_TAG_VARIABLE()
    vname = expr.name
    if vname == ""
      vname = expr.target
    end
    if kavach_is_raw_hw_op(vname) == 1
      kavach_record_error(kv, fn_name, vname)
    end
    return 0
  end

  if k == "Field"
    if expr.value != 0
      kavach_scan_expr(kv, fn_name, expr.value)
    end
    if expr.expr != 0
      kavach_scan_expr(kv, fn_name, expr.expr)
    end
    return 0
  end

  if k == "Call" or k == "CallExpr" or tag == AST_TAG_CALL()
    cname = ""
    if expr.func != 0
      fk_k = expr.func.kind
      if fk_k == "Variable" or fk_k == "IDENT" or fk_k == "Identifier"
        cname = expr.func.name
      elif fk_k == "MemberAccess" or fk_k == "FieldAccess"
        cname = expr.func.name
        kavach_scan_expr(kv, fn_name, expr.func)
      else
        kavach_scan_expr(kv, fn_name, expr.func)
      end
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

  if k == "Binary" or k == "BinaryExpr" or k == "BinaryOp" or tag == AST_TAG_BINARY_OP() or k == "Pipeline" or tag == AST_TAG_PIPELINE()
    kavach_scan_expr(kv, fn_name, expr.left)
    kavach_scan_expr(kv, fn_name, expr.right)
    return 0
  end

  if k == "Unary" or k == "UnaryOp" or tag == AST_TAG_UNARY_OP()
    kavach_scan_expr(kv, fn_name, expr.expr)
    return 0
  end

  if k == "Index" or k == "Member" or k == "MemberAccess" or k == "FieldAccess" or tag == AST_TAG_INDEX() or tag == AST_TAG_MEMBER_ACCESS()
    kavach_scan_expr(kv, fn_name, expr.left)
    if expr.target != 0 and expr.target != expr.left
      kavach_scan_expr(kv, fn_name, expr.target)
    end
    if expr.right != 0
      kavach_scan_expr(kv, fn_name, expr.right)
    end
    if expr.index != 0
      kavach_scan_expr(kv, fn_name, expr.index)
    end
    return 0
  end

  if k == "ArrayLit" or k == "MapLit" or k == "StructLit" or tag == AST_TAG_ARRAY_LIT() or tag == AST_TAG_MAP_LIT()
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

  if k == "MatchExpr"
    if expr.expr != 0
      kavach_scan_expr(kv, fn_name, expr.expr)
    end
    if expr.body != 0
      kavach_scan_stmt_list(kv, fn_name, expr.body)
    end
    return 0
  end

  return 0
end

fn kavach_scan_stmt kv fn_name stmt
  if stmt == 0
    return 0
  end
  if kavach_node_in_utso(stmt, kv.kv_utso_ranges) == 1
    return 0
  end
  k = stmt.kind
  tag = stmt.tag

  if k == "MultiAssign"
    if stmt.args != 0
      mi = 0
      while mi < stmt.args.len()
        kavach_scan_expr(kv, fn_name, stmt.args[mi])
        mi = mi + 1
      end
    end
    return 0
  end

  if k == "Assign" or k == "AssignOp" or tag == AST_TAG_ASSIGN() or tag == AST_TAG_ASSIGN_OP()
    if stmt.index != 0
      kavach_scan_expr(kv, fn_name, stmt.index)
    end
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
    if stmt.args != 0
      rai = 0
      while rai < stmt.args.len()
        kavach_scan_expr(kv, fn_name, stmt.args[rai])
        rai = rai + 1
      end
    end
    return 0
  end

  if k == "Print" or k == "Say" or k == "Throw"
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

  if k == "Block" or tag == AST_TAG_BLOCK() or k == "Defer" or tag == AST_TAG_DEFER() or k == "Region"
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

fn kavach_verify_program_with_utso ast_decls utso_ranges
  kv = kavach_checker_new()
  kv.kv_utso_ranges = utso_ranges
  if ast_decls == 0
    return kv
  end
  di = 0
  n = ast_decls.len()
  while di < n
    decl = ast_decls[di]
    if decl != 0
      dk = decl.kind
      dtag = decl.tag
      if dk == "FnDef" or dk == "Function" or dk == "কাজ" or dk == "Component" or dtag == AST_TAG_FN_DEF()
        fn_ctx = decl.name
        if fn_ctx == ""
          fn_ctx = "<toplevel>"
        end
        // WHY: Synthetic or explicit `main`/`মূল` may contain prepended top-level statements
        // from authentic `utso/` modules alongside user code; scan statement-by-statement so
        // authentic `utso/` lines pass while user code in `main` is strictly verified.
        if fn_ctx == "main" or fn_ctx == "মূল"
          if decl.params != 0 and kavach_node_in_utso(decl, utso_ranges) == 0
            dpi = 0
            while dpi < decl.params.len()
              dp = decl.params[dpi]
              if dp != 0 and dp.param_default != 0
                kavach_scan_expr(kv, fn_ctx, dp.param_default)
              end
              dpi = dpi + 1
            end
          end
          kavach_scan_stmt_list(kv, fn_ctx, decl.body)
        elif kavach_is_silicon_crowned(fn_ctx) == 0 and kavach_node_in_utso(decl, utso_ranges) == 0
          if decl.params != 0
            dpi = 0
            while dpi < decl.params.len()
              dp = decl.params[dpi]
              if dp != 0 and dp.param_default != 0
                kavach_scan_expr(kv, fn_ctx, dp.param_default)
              end
              dpi = dpi + 1
            end
          end
          kavach_scan_stmt_list(kv, fn_ctx, decl.body)
        end
      elif dk != "StructDef" and dk != "EnumDef" and dtag != AST_TAG_STRUCT_DEF() and dtag != AST_TAG_ENUM_DEF()
        kavach_scan_stmt(kv, "<toplevel>", decl)
      end
    end
    di = di + 1
  end
  return kv
end

fn kavach_verify_program ast_decls
  return kavach_verify_program_with_utso(ast_decls, 0)
end
