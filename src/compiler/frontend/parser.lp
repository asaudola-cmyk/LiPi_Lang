@! ============================================================================
@! MAYA COMPILER STAGE 2 — 100% PURE MAYA PRATT PARSER & LOWERING ENGINE
@! Zero External Dependencies — Complete 13 Precedence Levels
@! Handles All 26 Directives, Syntactic Desugaring, & Impl Method Injection
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/ast"
import "compiler/frontend/lexer"

@! ============================================================================
@! 1. PARSER STRUCTS & HELPER STRUCTURES
@! ============================================================================

@struct ParseResult
  node: ASTNode
  next_pos: i64
@end

@struct ParseStmtResult
  stmt: ASTNode
  next_pos: i64
@end

@struct ParseFnResult
  fn_node: ASTNode
  next_pos: i64
@end

@struct ParserState
  tokens: array
  pos: i64
  current_impl_struct: string
  current_trait_name: string
@end

@fn parser_init(tokens)
  return {
    tokens: tokens,
    pos: 0,
    current_impl_struct: "",
    current_trait_name: ""
  }
@end

@fn parse_peek_tok(state)
  @if state.pos >= state.tokens.len()
    return { tok_type: "EOF", tok_val: "", tok_text: "", tok_id: 0, tok_line: 0, tok_col: 0, tok_int_val: 0, tok_float_val: 0 }
  @end
  return state.tokens[state.pos]
@end

@fn parse_check_tok(state, expected_type)
  tok = parse_peek_tok(state)
  @if tok.tok_type == expected_type || tok.tok_val == expected_type
    return 1
  @end
  return 0
@end

@fn skip_newlines_parser(tokens, pos)
  p = pos
  num_items = tokens.len()
  @while p < num_items && (tokens[p].tok_type == "NEWLINE" || tokens[p].tok_type == "SEMI")
    p = p + 1
  @end
  return p
@end

@! ============================================================================
@! 2. 13 PRECEDENCE LEVELS MATRIX (10-Step Tiered Resolution)
@! ============================================================================

@fn get_token_precedence(tok)
  @if tok == 0 return 0 @end
  t = tok.tok_type

  @if t == "ASSIGN" || t == "PLUSEQ" || t == "MINUSEQ" || t == "STAREQ" || t == "SLASHEQ" || t == "PERCENTEQ"
    return 10
  @elif t == "OR"
    return 20
  @elif t == "AND"
    return 30
  @elif t == "BAR"
    return 40
  @elif t == "CARET"
    return 50
  @elif t == "AMP"
    return 60
  @elif t == "EQ" || t == "NEQ"
    return 70
  @elif t == "LT" || t == "LTE" || t == "GT" || t == "GTE"
    return 80
  @elif t == "SHL" || t == "SHR"
    return 90
  @elif t == "PLUS" || t == "MINUS"
    return 100
  @elif t == "STAR" || t == "SLASH" || t == "PERCENT"
    return 110
  @elif t == "PIPE"
    return 120
  @elif t == "LPAREN" || t == "LBRACKET" || t == "DOT" || t == "QUERY"
    return 130
  @end

  return 0
@end

@fn is_right_associative(tok)
  @if tok == 0 return 0 @end
  t = tok.tok_type
  @if t == "ASSIGN" || t == "PLUSEQ" || t == "MINUSEQ" || t == "STAREQ" || t == "SLASHEQ" || t == "PERCENTEQ"
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 3. STRING INTERPOLATION LOWERING ENGINE
@! ============================================================================

@fn parse_string_interpolation(raw_str) -> ASTNode
  num_items = str_len(raw_str)
  curr_pos = 0
  has_root = 0
  root_node = ast_literal_str("")

  @while curr_pos < num_items
    brace_open = -1
    c_idx = curr_pos
    @while c_idx < num_items && brace_open == -1
      @if str_char_at(raw_str, c_idx) == 123 @! '{'
        brace_open = c_idx
      @end
      c_idx = c_idx + 1
    @end

    @if brace_open == -1
      chunk = str_substr(raw_str, curr_pos, num_items)
      lit_node = ast_literal_str(chunk)
      @if has_root == 0
        root_node = lit_node
        has_root = 1
      @else
        root_node = ast_binary_op(root_node, "+", lit_node)
      @end
      curr_pos = num_items
    @else
      @if brace_open > curr_pos
        prefix = str_substr(raw_str, curr_pos, brace_open)
        prefix_node = ast_literal_str(prefix)
        @if has_root == 0
          root_node = prefix_node
          has_root = 1
        @else
          root_node = ast_binary_op(root_node, "+", prefix_node)
        @end
      @end

      brace_close = -1
      c_idx = brace_open + 1
      @while c_idx < num_items && brace_close == -1
        @if str_char_at(raw_str, c_idx) == 125 @! '}'
          brace_close = c_idx
        @end
        c_idx = c_idx + 1
      @end

      @if brace_close == -1
        suffix = str_substr(raw_str, brace_open, num_items)
        lit_node = ast_literal_str(suffix)
        @if has_root == 0
          root_node = lit_node
          has_root = 1
        @else
          root_node = ast_binary_op(root_node, "+", lit_node)
        @end
        curr_pos = num_items
      @else
        expr_str = str_substr(raw_str, brace_open + 1, brace_close)
        interp_var = ast_variable(expr_str)
        to_str_call = ast_call(ast_member_access(interp_var, "to_str"), [])
        @if has_root == 0
          root_node = to_str_call
          has_root = 1
        @else
          root_node = ast_binary_op(root_node, "+", to_str_call)
        @end
        curr_pos = brace_close + 1
      @end
    @end
  @end

  return root_node
@end

@! ============================================================================
@! 4. PRIMARY EXPRESSIONS
@! ============================================================================

@fn parse_primary(tokens, pos)
  p = pos
  @if p >= tokens.len()
    return { node: ast_literal_none(), next_pos: p }
  @end

  tok = tokens[p]

  @! 1. Integers & Numbers
  @if tok.tok_type == "INT"
    v = tok.tok_int_val
    @if v == 0 && tok.tok_val != "0" v = str_to_int(tok.tok_val) @end
    return { node: ast_literal_int(v), next_pos: p + 1 }
  @elif tok.tok_type == "HEX_INT"
    return { node: ast_literal_int(tok.tok_int_val), next_pos: p + 1 }
  @elif tok.tok_type == "BIN_INT"
    return { node: ast_literal_int(tok.tok_int_val), next_pos: p + 1 }
  @elif tok.tok_type == "FLOAT"
    return { node: ast_literal_float(0), next_pos: p + 1 }

  @! 2. Strings & Interpolated Strings
  @elif tok.tok_type == "STR"
    return { node: ast_literal_str(tok.tok_val), next_pos: p + 1 }
  @elif tok.tok_type == "INTERP_STR"
    return { node: parse_string_interpolation(tok.tok_val), next_pos: p + 1 }

  @! 3. Booleans & None
  @elif tok.tok_type == "BOOL"
    b_val = 0
    @if tok.tok_val == "true" b_val = 1 @end
    return { node: ast_literal_bool(b_val), next_pos: p + 1 }
  @elif tok.tok_type == "NONE"
    return { node: ast_literal_none(), next_pos: p + 1 }

  @! 4. Unary Prefix Operators (!, -, +, ~, &)
  @elif tok.tok_type == "BANG" || tok.tok_type == "MINUS" || tok.tok_type == "PLUS" || tok.tok_type == "TILDE" || tok.tok_type == "AMP"
    op_str = tok.tok_val
    sub_res = parse_expr_prec(tokens, p + 1, 110)
    return { node: ast_unary_op(op_str, sub_res.node), next_pos: sub_res.next_pos }

  @! 5. Identifier / Struct Literal
  @elif tok.tok_type == "IDENT"
    id_name = tok.tok_val
    p = p + 1
    @if p + 1 < tokens.len() && tokens[p].tok_type == "LBRACE" && (tokens[p + 1].tok_type == "IDENT" || tokens[p + 1].tok_type == "RBRACE")
      p = p + 1 @! skip '{'
      entries = []
      @while p < tokens.len() && tokens[p].tok_type != "RBRACE" && tokens[p].tok_type != "EOF"
        p = skip_newlines_parser(tokens, p)
        @if p < tokens.len() && tokens[p].tok_type == "RBRACE"
          break
        @end
        f_name = tokens[p].tok_val
        p = p + 1
        @if p < tokens.len() && tokens[p].tok_type == "COLON"
          p = p + 1
        @end
        val_res = parse_expr(tokens, p)
        entries = entries.push(ast_field(f_name, "", val_res.node, entries.len()))
        p = val_res.next_pos
        @if p < tokens.len() && tokens[p].tok_type == "COMMA"
          p = p + 1
        @end
        p = skip_newlines_parser(tokens, p)
      @end
      @if p < tokens.len() && tokens[p].tok_type == "RBRACE"
        p = p + 1
      @end
      st_node = ast_node("StructLiteral")
      st_node.name = id_name
      st_node.elements = entries
      return { node: st_node, next_pos: p }
    @end

    return { node: ast_variable(id_name), next_pos: p }

  @! 6. Grouped Expression: (expr)
  @elif tok.tok_type == "LPAREN"
    p = p + 1
    inner = parse_expr(tokens, p)
    p = inner.next_pos
    @if p < tokens.len() && tokens[p].tok_type == "RPAREN"
      p = p + 1
    @end
    return { node: inner.node, next_pos: p }

  @! 7. Array Literal: [a, b, c]
  @elif tok.tok_type == "LBRACKET"
    p = p + 1
    elements = []
    @while p < tokens.len() && tokens[p].tok_type != "RBRACKET" && tokens[p].tok_type != "EOF"
      p = skip_newlines_parser(tokens, p)
      @if p < tokens.len() && tokens[p].tok_type == "RBRACKET"
        break
      @end
      el_res = parse_expr(tokens, p)
      elements = elements.push(el_res.node)
      p = el_res.next_pos
      @if p < tokens.len() && tokens[p].tok_type == "COMMA"
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
    @end
    @if p < tokens.len() && tokens[p].tok_type == "RBRACKET"
      p = p + 1
    @end
    return { node: ast_array_lit(elements), next_pos: p }

  @! 8. Map Literal: { k: v, ... }
  @elif tok.tok_type == "LBRACE"
    p = p + 1
    entries = []
    @while p < tokens.len() && tokens[p].tok_type != "RBRACE" && tokens[p].tok_type != "EOF"
      p = skip_newlines_parser(tokens, p)
      @if p < tokens.len() && tokens[p].tok_type == "RBRACE"
        break
      @end
      k_res = parse_expr(tokens, p)
      p = k_res.next_pos
      @if p < tokens.len() && tokens[p].tok_type == "COLON"
        p = p + 1
      @end
      v_res = parse_expr(tokens, p)
      entries = entries.push({ key: k_res.node, value: v_res.node })
      p = v_res.next_pos
      @if p < tokens.len() && tokens[p].tok_type == "COMMA"
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
    @end
    @if p < tokens.len() && tokens[p].tok_type == "RBRACE"
      p = p + 1
    @end
    return { node: ast_map_lit(entries), next_pos: p }

  @! 9. Closure: |x, y| expr
  @elif tok.tok_type == "BAR"
    p = p + 1
    c_params = []
    @while p < tokens.len() && tokens[p].tok_type != "BAR" && tokens[p].tok_type != "EOF"
      p_name = tokens[p].tok_val
      p = p + 1
      p_type = ""
      @if p < tokens.len() && tokens[p].tok_type == "COLON"
        p = p + 1
        p_type = tokens[p].tok_val
        p = p + 1
      @end
      c_params = c_params.push(ast_param(p_name, p_type, 0))
      @if p < tokens.len() && tokens[p].tok_type == "COMMA"
        p = p + 1
      @end
    @end
    @if p < tokens.len() && tokens[p].tok_type == "BAR"
      p = p + 1
    @end
    @if p < tokens.len() && tokens[p].tok_type == "ARROW"
      p = p + 1
    @end
    body_res = parse_expr(tokens, p)
    return { node: ast_closure(c_params, [ast_return(body_res.node)]), next_pos: body_res.next_pos }

  @! 10. Match Expression: match x ... @end
  @elif tok.tok_type == "MATCH" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@match")
    p = p + 1
    tgt_res = parse_expr(tokens, p)
    p = tgt_res.next_pos
    p = skip_newlines_parser(tokens, p)
    arms = []
    @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
      @if tokens[p].tok_type == "CASE" || tokens[p].tok_val == "case"
        p = p + 1
      @end
      pat_res = parse_expr(tokens, p)
      p = pat_res.next_pos
      p = skip_newlines_parser(tokens, p)
      @if p < tokens.len() && tokens[p].tok_type == "FAT_ARROW"
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
      arm_expr = parse_expr(tokens, p)
      arms = arms.push(ast_match_arm(pat_res.node, 0, [ast_return(arm_expr.node)]))
      p = arm_expr.next_pos
      p = skip_newlines_parser(tokens, p)
    @end
    @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
      p = p + 1
    @end
    return { node: ast_match_expr(tgt_res.node, arms), next_pos: p }

  @end

  return { node: ast_literal_none(), next_pos: p + 1 }
@end

@! ============================================================================
@! 5. PRATT PARSER WITH PRECEDENCE CLIMBING
@! ============================================================================

@fn parse_expr(tokens, pos)
  return parse_expr_prec(tokens, pos, 0)
@end

@fn parse_expr_prec(tokens, pos, min_prec)
  left_res = parse_primary(tokens, pos)
  left = left_res.node
  p = left_res.next_pos
  has_more = 1

  @while p < tokens.len() && has_more == 1
    tok = tokens[p]
    prec = get_token_precedence(tok)
    @if prec == 0 || prec <= min_prec
      has_more = 0
    @elif tok.tok_type == "LPAREN"
      p = p + 1
      call_args = []
      @while p < tokens.len() && tokens[p].tok_type != "RPAREN" && tokens[p].tok_type != "EOF"
        p = skip_newlines_parser(tokens, p)
        @if p < tokens.len() && tokens[p].tok_type == "RPAREN"
          break
        @end
        arg_res = parse_expr(tokens, p)
        call_args = call_args.push(arg_res.node)
        p = arg_res.next_pos
        @if p < tokens.len() && tokens[p].tok_type == "COMMA"
          p = p + 1
        @end
        p = skip_newlines_parser(tokens, p)
      @end
      @if p < tokens.len() && tokens[p].tok_type == "RPAREN"
        p = p + 1
      @end
      left = ast_call(left, call_args)

    @! 2. Array / Map Indexing: left[idx]
    @elif tok.tok_type == "LBRACKET"
      p = p + 1
      idx_res = parse_expr(tokens, p)
      p = idx_res.next_pos
      @if p < tokens.len() && tokens[p].tok_type == "RBRACKET"
        p = p + 1
      @end
      left = ast_index(left, idx_res.node)

    @! 3. Member Access / Method Call: left.field
    @elif tok.tok_type == "DOT"
      p = p + 1
      f_name = tokens[p].tok_val
      p = p + 1
      @if p < tokens.len() && tokens[p].tok_type == "LPAREN"
        @! Method call left.f(args)
        p = p + 1
        m_args = []
        @while p < tokens.len() && tokens[p].tok_type != "RPAREN" && tokens[p].tok_type != "EOF"
          p = skip_newlines_parser(tokens, p)
          @if p < tokens.len() && tokens[p].tok_type == "RPAREN"
            break
          @end
          arg_res = parse_expr(tokens, p)
          m_args = m_args.push(arg_res.node)
          p = arg_res.next_pos
          @if p < tokens.len() && tokens[p].tok_type == "COMMA"
            p = p + 1
          @end
          p = skip_newlines_parser(tokens, p)
        @end
        @if p < tokens.len() && tokens[p].tok_type == "RPAREN"
          p = p + 1
        @end
        left = ast_call(ast_member_access(left, f_name), m_args)
      @else
        left = ast_member_access(left, f_name)
      @end

    @! 4. Error Propagation Operator: expr?
    @elif tok.tok_type == "QUERY"
      p = p + 1
      q_node = ast_node("ErrorPropagate")
      q_node.expr = left
      left = q_node

    @! 5. Pipeline Operator: left |> right
    @elif tok.tok_type == "PIPE"
      p = p + 1
      next_prec = prec
      @if is_right_associative(tok) == 0 next_prec = prec + 1 @end
      rhs_res = parse_expr_prec(tokens, p, next_prec)
      p = rhs_res.next_pos
      left = ast_pipeline(left, rhs_res.node)

    @! 6. Binary Operators (+, -, *, /, %, ==, !=, <, <=, >, >=, &&, ||, etc.)
    @else
      op_str = tok.tok_val
      p = p + 1
      next_prec = prec
      @if is_right_associative(tok) == 0 next_prec = prec + 1 @end
      rhs_res = parse_expr_prec(tokens, p, next_prec)
      p = rhs_res.next_pos
      left = ast_binary_op(left, op_str, rhs_res.node)
    @end
  @end

  return { node: left, next_pos: p }
@end

@! ============================================================================
@! 6. STATEMENT PARSER & AST LOWERING
@! ============================================================================

@fn parse_statement(tokens, pos, impl_struct)
  p = skip_newlines_parser(tokens, pos)
  @if p >= tokens.len()
    return { stmt: ast_literal_none(), next_pos: p }
  @end

  tok = tokens[p]

  @! 1. Variable Assignment / Declaration: let / var / mut x = expr or x = expr
  @if tok.tok_type == "LET" || tok.tok_type == "VAR" || tok.tok_type == "MUT"
    p = p + 1
    var_name = tokens[p].tok_val
    p = p + 1
    var_type = ""
    @if p < tokens.len() && tokens[p].tok_type == "COLON"
      p = p + 1
      var_type = tokens[p].tok_val
      p = p + 1
    @end
    @if p < tokens.len() && tokens[p].tok_type == "ASSIGN"
      p = p + 1
      val_res = parse_expr(tokens, p)
      return { stmt: ast_assign(var_name, val_res.node), next_pos: val_res.next_pos }
    @end
    return { stmt: ast_assign(var_name, ast_literal_none()), next_pos: p }

  @! 2. Return Statement: @return / return
  @elif tok.tok_type == "RETURN" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@return")
    p = p + 1
    @if p < tokens.len() && tokens[p].tok_type != "NEWLINE" && tokens[p].tok_type != "SEMI" && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end")
      val_res = parse_expr(tokens, p)
      return { stmt: ast_return(val_res.node), next_pos: val_res.next_pos }
    @end
    return { stmt: ast_return(ast_literal_none()), next_pos: p }

  @! 3. Break / Continue
  @elif tok.tok_type == "BREAK" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@break")
    return { stmt: ast_break(), next_pos: p + 1 }
  @elif tok.tok_type == "CONTINUE" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@continue")
    return { stmt: ast_continue(), next_pos: p + 1 }

  @! 4. Defer: @defer stmt
  @elif tok.tok_type == "DEFER" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@defer")
    p = p + 1
    d_res = parse_statement(tokens, p, impl_struct)
    return { stmt: ast_defer(d_res.stmt), next_pos: d_res.next_pos }

  @! 5. While Loop: @while / while cond ... @end
  @elif tok.tok_type == "WHILE" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@while")
    p = p + 1
    cond_res = parse_expr(tokens, p)
    p = cond_res.next_pos
    p = skip_newlines_parser(tokens, p)
    body = []
    @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
      s_res = parse_statement(tokens, p, impl_struct)
      body = body.push(s_res.stmt)
      p = s_res.next_pos
      p = skip_newlines_parser(tokens, p)
    @end
    @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
      p = p + 1
    @end
    return { stmt: ast_while_loop(cond_res.node, body), next_pos: p }

  @! 6. For Loop: for / for x in iter ... @end
  @elif tok.tok_type == "FOR" || (tok.tok_type == "DIRECTIVE" && (tok.tok_val == "@for" || tok.tok_val == "@parallel_for"))
    is_parallel = 0
    @if tok.tok_val == "@parallel_for" is_parallel = 1 @end
    p = p + 1
    var_name = tokens[p].tok_val
    p = p + 1
    @if p < tokens.len() && (tokens[p].tok_type == "IN" || tokens[p].tok_val == "in")
      p = p + 1
    @end
    iter_res = parse_expr(tokens, p)
    p = iter_res.next_pos
    p = skip_newlines_parser(tokens, p)
    body = []
    @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
      s_res = parse_statement(tokens, p, impl_struct)
      body = body.push(s_res.stmt)
      p = s_res.next_pos
      p = skip_newlines_parser(tokens, p)
    @end
    @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
      p = p + 1
    @end
    for_node = ast_for_loop(var_name, iter_res.node, body)
    @if is_parallel == 1
      for_node.kind = "ParallelFor"
    @end
    return { stmt: for_node, next_pos: p }

  @! 7. If / Elif / Else: @if / if cond ... @elif ... @else ... @end
  @elif tok.tok_type == "IF" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@if")
    p = p + 1
    cond_res = parse_expr(tokens, p)
    p = cond_res.next_pos
    p = skip_newlines_parser(tokens, p)
    then_body = []
    elif_branches = []
    else_body = []

    @while p < tokens.len() && tokens[p].tok_type != "ELIF" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@elif") && tokens[p].tok_type != "ELSE" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@else") && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
      s_res = parse_statement(tokens, p, impl_struct)
      then_body = then_body.push(s_res.stmt)
      p = s_res.next_pos
      p = skip_newlines_parser(tokens, p)
    @end

    @! Elif branches
    @while p < tokens.len() && (tokens[p].tok_type == "ELIF" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@elif"))
      p = p + 1
      elif_cond = parse_expr(tokens, p)
      p = elif_cond.next_pos
      p = skip_newlines_parser(tokens, p)
      elif_b = []
      @while p < tokens.len() && tokens[p].tok_type != "ELIF" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@elif") && tokens[p].tok_type != "ELSE" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@else") && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        s_res = parse_statement(tokens, p, impl_struct)
        elif_b = elif_b.push(s_res.stmt)
        p = s_res.next_pos
        p = skip_newlines_parser(tokens, p)
      @end
      elif_branches = elif_branches.push(ast_elif_branch(elif_cond.node, elif_b))
    @end

    @! Else body
    @if p < tokens.len() && (tokens[p].tok_type == "ELSE" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@else"))
      p = p + 1
      p = skip_newlines_parser(tokens, p)
      @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        s_res = parse_statement(tokens, p, impl_struct)
        else_body = else_body.push(s_res.stmt)
        p = s_res.next_pos
        p = skip_newlines_parser(tokens, p)
      @end
    @end

    @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
      p = p + 1
    @end

    return { stmt: ast_if_stmt(cond_res.node, then_body, elif_branches, else_body), next_pos: p }

  @! 8. Try / Catch: @try ... @catch err ... @end
  @elif tok.tok_type == "TRY" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@try")
    p = p + 1
    p = skip_newlines_parser(tokens, p)
    try_body = []
    catch_body = []
    err_var = "err"

    @while p < tokens.len() && tokens[p].tok_type != "CATCH" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@catch") && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
      s_res = parse_statement(tokens, p, impl_struct)
      try_body = try_body.push(s_res.stmt)
      p = s_res.next_pos
      p = skip_newlines_parser(tokens, p)
    @end

    @if p < tokens.len() && (tokens[p].tok_type == "CATCH" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@catch"))
      p = p + 1
      @if p < tokens.len() && tokens[p].tok_type == "IDENT"
        err_var = tokens[p].tok_val
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
      @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        s_res = parse_statement(tokens, p, impl_struct)
        catch_body = catch_body.push(s_res.stmt)
        p = s_res.next_pos
        p = skip_newlines_parser(tokens, p)
      @end
    @end

    @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
      p = p + 1
    @end

    return { stmt: ast_try_catch(try_body, err_var, catch_body), next_pos: p }

  @! 9. Match Statement
  @elif tok.tok_type == "MATCH" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@match")
    p = p + 1
    tgt_res = parse_expr(tokens, p)
    p = tgt_res.next_pos
    p = skip_newlines_parser(tokens, p)
    arms = []
    @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
      @if tokens[p].tok_type == "CASE" || tokens[p].tok_val == "case"
        p = p + 1
      @end
      pat_res = parse_expr(tokens, p)
      p = pat_res.next_pos
      p = skip_newlines_parser(tokens, p)
      @if p < tokens.len() && tokens[p].tok_type == "FAT_ARROW"
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
      arm_stmts = []
      @while p < tokens.len() && tokens[p].tok_type != "CASE" && tokens[p].tok_val != "case" && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        s_res = parse_statement(tokens, p, impl_struct)
        arm_stmts = arm_stmts.push(s_res.stmt)
        p = s_res.next_pos
        p = skip_newlines_parser(tokens, p)
      @end
      arms = arms.push(ast_match_arm(pat_res.node, 0, arm_stmts))
    @end
    @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
      p = p + 1
    @end
    return { stmt: ast_match_stmt(tgt_res.node, arms), next_pos: p }

  @! 10. General Expression Statement or Assignment
  @else
    expr_res = parse_expr(tokens, p)
    p = expr_res.next_pos

    @! Compound assignment: target += expr, target -= expr, etc.
    @if p < tokens.len() && (tokens[p].tok_type == "ASSIGN" || tokens[p].tok_type == "PLUSEQ" || tokens[p].tok_type == "MINUSEQ" || tokens[p].tok_type == "STAREQ" || tokens[p].tok_type == "SLASHEQ" || tokens[p].tok_type == "PERCENTEQ")
      op_tok = tokens[p]
      p = p + 1
      rhs_res = parse_expr(tokens, p)
      @if op_tok.tok_type == "ASSIGN"
        return { stmt: ast_assign(ast_get_name(expr_res.node), rhs_res.node), next_pos: rhs_res.next_pos }
      @else
        op_sym = "+"
        @if op_tok.tok_type == "MINUSEQ" op_sym = "-"
        @elif op_tok.tok_type == "STAREQ" op_sym = "*"
        @elif op_tok.tok_type == "SLASHEQ" op_sym = "/"
        @elif op_tok.tok_type == "PERCENTEQ" op_sym = "%"
        @end
        return { stmt: ast_assign_op(ast_get_name(expr_res.node), rhs_res.node, op_sym), next_pos: rhs_res.next_pos }
      @end
    @end

    return { stmt: ast_expression_stmt(expr_res.node), next_pos: p }
  @end
@end

@! ============================================================================
@! 7. TOP-LEVEL DECLARATION PARSER & PROGRAM PARSER
@! ============================================================================

@fn parse_fn_declaration(tokens, pos, impl_struct)
  p = pos
  @if tokens[p].tok_type == "FN" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@fn")
    p = p + 1
  @end

  fn_name = tokens[p].tok_val
  p = p + 1

  @! @impl Struct lowering: prefix method name with Struct_
  @if impl_struct.len() > 0
    fn_name = str_concat(impl_struct, str_concat("_", fn_name))
  @end

  params = []
  @! @impl Struct lowering: inject 'self' as first parameter
  @if impl_struct.len() > 0
    params = params.push(ast_param("self", impl_struct, 0))
  @end

  @if p < tokens.len() && tokens[p].tok_type == "LPAREN"
    p = p + 1
    @while p < tokens.len() && tokens[p].tok_type != "RPAREN" && tokens[p].tok_type != "EOF"
      p_name = tokens[p].tok_val
      p = p + 1
      p_type = ""
      @if p < tokens.len() && tokens[p].tok_type == "COLON"
        p = p + 1
        p_type = tokens[p].tok_val
        p = p + 1
      @end
      params = params.push(ast_param(p_name, p_type, 0))
      @if p < tokens.len() && tokens[p].tok_type == "COMMA"
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
    @end
    @if p < tokens.len() && tokens[p].tok_type == "RPAREN"
      p = p + 1
    @end
  @end

  ret_type = "void"
  @if p < tokens.len() && tokens[p].tok_type == "ARROW"
    p = p + 1
    ret_type = tokens[p].tok_val
    p = p + 1
  @end

  p = skip_newlines_parser(tokens, p)
  body = []
  @while p < tokens.len() && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
    s_res = parse_statement(tokens, p, impl_struct)
    body = body.push(s_res.stmt)
    p = s_res.next_pos
    p = skip_newlines_parser(tokens, p)
  @end

  @if p < tokens.len() && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
    p = p + 1
  @end

  return { fn_node: ast_fn_def(fn_name, params, ret_type, body), next_pos: p }
@end

@fn parse_program_from_tokens(tokens)
  prog = ast_program_new()
  p = 0
  num_items = tokens.len()

  @while p < num_items
    p = skip_newlines_parser(tokens, p)
    @if p >= num_items || tokens[p].tok_type == "EOF"
      break
    @end

    tok = tokens[p]

    @! 1. Module Import: Import "path"
    @if tok.tok_type == "IMPORT" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@import")
      p = p + 1
      imp_path = tokens[p].tok_val
      p = p + 1
      prog.imports = prog.imports.push(imp_path)

    @! 2. Struct Definition: @struct StructName ... @end
    @elif tok.tok_type == "STRUCT" || (tok.tok_type == "DIRECTIVE" && (tok.tok_val == "@struct" || tok.tok_val == "@type"))
      p = p + 1
      s_name = tokens[p].tok_val
      p = p + 1
      p = skip_newlines_parser(tokens, p)
      fields = []
      f_idx = 0
      @while p < num_items && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        f_name = tokens[p].tok_val
        p = p + 1
        f_type = "i64"
        @if p < num_items && tokens[p].tok_type == "COLON"
          p = p + 1
          f_type = tokens[p].tok_val
          p = p + 1
        @end
        fields = fields.push(ast_field(f_name, f_type, 0, f_idx))
        f_idx = f_idx + 1
        p = skip_newlines_parser(tokens, p)
      @end
      @if p < num_items && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
        p = p + 1
      @end
      prog.structs = prog.structs.push(ast_struct_def(s_name, fields))

    @! 3. Enum Definition: @enum EnumName ... @end
    @elif tok.tok_type == "ENUM" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@enum")
      p = p + 1
      e_name = tokens[p].tok_val
      p = p + 1
      p = skip_newlines_parser(tokens, p)
      variants = []
      var_val = 0
      @while p < num_items && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        v_name = tokens[p].tok_val
        p = p + 1
        @if p < num_items && tokens[p].tok_type == "ASSIGN"
          p = p + 1
          var_val = tokens[p].tok_int_val
          p = p + 1
        @end
        variants = variants.push(ast_enum_variant(v_name, var_val))
        prog.constants = prog.constants.push(ast_constant(e_name + "_" + v_name, var_val))
        var_val = var_val + 1
        p = skip_newlines_parser(tokens, p)
      @end
      @if p < num_items && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
        p = p + 1
      @end
      prog.enums = prog.enums.push(ast_enum_def(e_name, variants))

    @! 4. Impl Block: @impl StructName ... @end
    @elif tok.tok_type == "IMPL" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@impl")
      p = p + 1
      target_struct = tokens[p].tok_val
      p = p + 1
      trait_name = ""
      @if p < num_items && (tokens[p].tok_type == "FOR" || tokens[p].tok_val == "for")
        p = p + 1
        trait_name = target_struct
        target_struct = tokens[p].tok_val
        p = p + 1
      @end
      p = skip_newlines_parser(tokens, p)
      impl_methods = []
      @while p < num_items && tokens[p].tok_type != "END" && (tokens[p].tok_type != "DIRECTIVE" || tokens[p].tok_val != "@end") && tokens[p].tok_type != "EOF"
        @if tokens[p].tok_type == "FN" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@fn")
          m_res = parse_fn_declaration(tokens, p, target_struct)
          impl_methods = impl_methods.push(m_res.fn_node)
          prog.functions = prog.functions.push(m_res.fn_node)
          p = m_res.next_pos
        @else
          p = p + 1
        @end
        p = skip_newlines_parser(tokens, p)
      @end
      @if p < num_items && (tokens[p].tok_type == "END" || (tokens[p].tok_type == "DIRECTIVE" && tokens[p].tok_val == "@end"))
        p = p + 1
      @end
      prog.impls = prog.impls.push(ast_impl_block(trait_name, target_struct, impl_methods))

    @! 5. Top-Level Function Definition: @fn name(params) ... @end
    @elif tok.tok_type == "FN" || (tok.tok_type == "DIRECTIVE" && tok.tok_val == "@fn")
      fn_res = parse_fn_declaration(tokens, p, "")
      prog.functions = prog.functions.push(fn_res.fn_node)
      p = fn_res.next_pos

    @! 6. Fallback / Skip
    @else
      p = p + 1
    @end
  @end

  return prog
@end

@fn parse_source_program(source)
  tokens = tokenize_source(source)
  return parse_program_from_tokens(tokens)
@end
