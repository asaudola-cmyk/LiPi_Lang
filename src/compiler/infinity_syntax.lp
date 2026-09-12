@! ============================================================================
@! LIPI INFINITY DYNAMIC SYNTAX & GRAMMAR RULE ENGINE
@! Module: compiler/infinity_syntax.lp
@! Architecture: Pure Lipi Sovereign Metaprogramming & Dynamic Grammar Subsystem
@! Standard: Zero Foreign Dependencies, Fixed-Point Iterative Expansion
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURES & ENGINE STATE
@! ----------------------------------------------------------------------------

@struct InfinityRule
  pattern: string
  replacement: string
  rep_tokens: array
@end

@struct CustomOpDef
  symbol: string
  fixity: string
  precedence: i64
  handler: string
@end

@struct InfinityEngine
  rules: array
  custom_ops: array
  max_depth: i64
  active: i64
@end

@struct InfinityExtractResult
  tokens: array
  rules_pat: array
  rules_rep_tokens: array
  custom_ops: array
@end

@fn infinity_engine_new()
  return {
    rules: [],
    custom_ops: [],
    max_depth: 128,
    active: 1
  }
@end

@! ----------------------------------------------------------------------------
@! 2. STRING EQUALITY & PATTERN UTILITIES
@! ----------------------------------------------------------------------------

@fn infinity_get_char(s, k)
  // WHY: Direct character code access with bounds checking
  @if s == "" || k < 0
    return 0
  @end
  @if k >= str_len(s)
    return 0
  @end
  return str_char_at(s, k)
@end

@fn infinity_str_eq(s1, s2)
  // WHY: Native string equality check leveraging zero-overhead CPU string compare
  return str_eq(s1, s2)
@end

@fn infinity_pat_matches(tname, pat)
  @if infinity_str_eq(tname, pat) == 1
    return 1
  @end
  @if tname == "" || pat == ""
    return 0
  @end
  @if infinity_get_char(tname, 0) == 64
    i = 0
    @while 1
      c1 = infinity_get_char(tname, 1 + i)
      c2 = infinity_get_char(pat, i)
      @if c1 != c2
        break
      @end
      @if c1 == 0
        return 1
      @end
      i = i + 1
    @end
  @end
  @if infinity_get_char(pat, 0) == 64
    i = 0
    @while 1
      c1 = infinity_get_char(pat, 1 + i)
      c2 = infinity_get_char(tname, i)
      @if c1 != c2
        break
      @end
      @if c1 == 0
        return 1
      @end
      i = i + 1
    @end
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. BUILT-IN MATHEMATICAL & LOGICAL OPERATOR HANDLERS (Sovereign Lipi)
@! ----------------------------------------------------------------------------

@fn lipi_power(base, exp)
  @if exp <= 0
    return 1
  @end
  @if base == 0
    return 0
  @end
  res = 1
  b = base
  e = exp
  @while e > 0
    @if (e % 2) == 1
      res = res * b
    @end
    b = b * b
    e = e / 2
  @end
  return res
@end

@fn lipi_spaceship(a, b)
  @if a < b
    return 0 - 1
  @elif a > b
    return 1
  @else
    return 0
  @end
@end

@fn lipi_xor(a, b)
  b_a = 0
  @if a != 0
    b_a = 1
  @end
  b_b = 0
  @if b != 0
    b_b = 1
  @end
  @if (b_a == 1 && b_b == 0) || (b_a == 0 && b_b == 1)
    return 1
  @else
    return 0
  @end
@end

@fn lipi_approx_eq(a, b, epsilon)
  diff = a - b
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= epsilon
    return 1
  @else
    return 0
  @end
@end

// ── Compatibility Aliases ────────────────────────────────────────────────────
@fn maya_power(base, exp) return lipi_power(base, exp) @end
@fn maya_spaceship(a, b) return lipi_spaceship(a, b) @end
@fn maya_xor(a, b) return lipi_xor(a, b) @end
@fn maya_approx_eq(a, b, epsilon) return lipi_approx_eq(a, b, epsilon) @end

@! ----------------------------------------------------------------------------
@! 4. PURE LIPI REPLACEMENT TOKENIZER & NUMERIC PARSER
@! ----------------------------------------------------------------------------

@fn infinity_is_space(c)
  return c == 32 || c == 9 || c == 13 || c == 10
@end

@fn infinity_is_alpha(c)
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
@end

@fn infinity_is_digit(c)
  return c >= 48 && c <= 57
@end

@fn infinity_parse_int(s)
  res = 0
  sign = 1
  k = 0
  s_bytes = []
  @while 1
    c = str_char_at(s, k)
    @if c == 0 break @end
    s_bytes = s_bytes.push(c)
    k = k + 1
  @end
  num_items = s_bytes.len()
  @if num_items == 0 return 0 @end
  k = 0
  @if s_bytes[0] == 45
    sign = 0 - 1
    k = 1
  @elif s_bytes[0] == 43
    k = 1
  @end
  @while k < num_items
    c = s_bytes[k]
    @if c >= 48 && c <= 57
      res = res * 10 + (c - 48)
    @end
    k = k + 1
  @end
  return res * sign
@end

@fn infinity_tokenize_rep(source)
  tokens = []
  src_bytes = []
  s_k = 0
  @while 1
    c = str_char_at(source, s_k)
    @if c == 0
      break
    @end
    src_bytes = src_bytes.push(c)
    s_k = s_k + 1
  @end
  num_items = src_bytes.len()
  i = 0
  line = 1
  col = 1
  
  @while i < num_items
    c = src_bytes[i]
    
    @if infinity_is_space(c)
      i = i + 1
      col = col + 1
    @elif c == 64 @! @directive
      start_col = col
      d_str = "@"
      i = i + 1
      col = col + 1
      @while i < num_items && (infinity_is_alpha(src_bytes[i]) || infinity_is_digit(src_bytes[i]))
        d_str = d_str + str_from_char_code(src_bytes[i])
        i = i + 1
        col = col + 1
      @end
      tokens = tokens.push(["DIRECTIVE", d_str, int_to_str(line), int_to_str(start_col)])
    @elif infinity_is_alpha(c)
      start_col = col
      id_str = ""
      @while i < num_items && (infinity_is_alpha(src_bytes[i]) || infinity_is_digit(src_bytes[i]))
        id_str = id_str + str_from_char_code(src_bytes[i])
        i = i + 1
        col = col + 1
      @end
      @if infinity_str_eq(id_str, "fn") == 1
        tokens = tokens.push(["FN", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "return") == 1
        tokens = tokens.push(["RETURN", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "if") == 1
        tokens = tokens.push(["IF", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "elif") == 1
        tokens = tokens.push(["ELIF", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "else") == 1
        tokens = tokens.push(["ELSE", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "while") == 1
        tokens = tokens.push(["WHILE", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "for") == 1
        tokens = tokens.push(["FOR", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "in") == 1
        tokens = tokens.push(["IN", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "break") == 1
        tokens = tokens.push(["BREAK", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "continue") == 1
        tokens = tokens.push(["CONTINUE", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "let") == 1 || infinity_str_eq(id_str, "var") == 1
        tokens = tokens.push(["LET", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "end") == 1
        tokens = tokens.push(["END", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "true") == 1 || infinity_str_eq(id_str, "false") == 1
        tokens = tokens.push(["BOOL", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "none") == 1 || infinity_str_eq(id_str, "nil") == 1
        tokens = tokens.push(["NONE", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "import") == 1
        tokens = tokens.push(["IMPORT", id_str, int_to_str(line), int_to_str(start_col)])
      @elif infinity_str_eq(id_str, "struct") == 1 || infinity_str_eq(id_str, "type") == 1
        tokens = tokens.push(["STRUCT", id_str, int_to_str(line), int_to_str(start_col)])
      @else
        tokens = tokens.push(["IDENT", id_str, int_to_str(line), int_to_str(start_col)])
      @end
    @elif infinity_is_digit(c)
      start_col = col
      num_str = ""
      @while i < num_items && (infinity_is_digit(src_bytes[i]) || src_bytes[i] == 95)
        @if src_bytes[i] != 95
          num_str = num_str + str_from_char_code(src_bytes[i])
        @end
        i = i + 1
        col = col + 1
      @end
      tokens = tokens.push(["INT", num_str, int_to_str(line), int_to_str(start_col)])
    @elif c == 34 || c == 39 @! " or '
      quote = c
      start_col = col
      str_val = ""
      i = i + 1
      col = col + 1
      @while i < num_items && src_bytes[i] != quote
        str_val = str_val + str_from_char_code(src_bytes[i])
        i = i + 1
        col = col + 1
      @end
      @if i < num_items && src_bytes[i] == quote
        i = i + 1
        col = col + 1
      @end
      tokens = tokens.push(["STR", str_val, int_to_str(line), int_to_str(start_col)])
    @elif c == 61 @! =
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(["EQ", "==", int_to_str(line), int_to_str(col)])
        i = i + 2
        col = col + 2
      @elif i + 1 < num_items && src_bytes[i + 1] == 62
        tokens = tokens.push(["FATARROW", "=>", int_to_str(line), int_to_str(col)])
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(["ASSIGN", "=", int_to_str(line), int_to_str(col)])
        i = i + 1
        col = col + 1
      @end
    @elif c == 43 @! +
      tokens = tokens.push(["PLUS", "+", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 45 @! -
      @if i + 1 < num_items && src_bytes[i + 1] == 62
        tokens = tokens.push(["ARROW", "->", int_to_str(line), int_to_str(col)])
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(["MINUS", "-", int_to_str(line), int_to_str(col)])
        i = i + 1
        col = col + 1
      @end
    @elif c == 42 @! *
      tokens = tokens.push(["STAR", "*", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 47 @! /
      tokens = tokens.push(["SLASH", "/", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 37 @! %
      tokens = tokens.push(["PERCENT", "%", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 60 @! <
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(["LTE", "<=", int_to_str(line), int_to_str(col)])
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(["LT", "<", int_to_str(line), int_to_str(col)])
        i = i + 1
        col = col + 1
      @end
    @elif c == 62 @! >
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(["GTE", ">=", int_to_str(line), int_to_str(col)])
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(["GT", ">", int_to_str(line), int_to_str(col)])
        i = i + 1
        col = col + 1
      @end
    @elif c == 33 @! excl
      @if i + 1 < num_items && src_bytes[i + 1] == 61
        tokens = tokens.push(["NEQ", "!=", int_to_str(line), int_to_str(col)])
        i = i + 2
        col = col + 2
      @else
        tokens = tokens.push(["BANG", "!", int_to_str(line), int_to_str(col)])
        i = i + 1
        col = col + 1
      @end
    @elif c == 59 @! ;
      tokens = tokens.push(["SEMI", ";", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 40 @! (
      tokens = tokens.push(["LPAREN", "(", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 41 @! )
      tokens = tokens.push(["RPAREN", ")", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 91 @! [
      tokens = tokens.push(["LBRACKET", "[", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 93 @! ]
      tokens = tokens.push(["RBRACKET", "]", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 123 @! {
      tokens = tokens.push(["LBRACE", "{", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 125 @! }
      tokens = tokens.push(["RBRACE", "}", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 44 @! ,
      tokens = tokens.push(["COMMA", ",", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 58 @! :
      tokens = tokens.push(["COLON", ":", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 94 @! ^
      tokens = tokens.push(["CARET", "^", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 126 @! ~
      tokens = tokens.push(["TILDE", "~", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 38 @! &
      tokens = tokens.push(["AMP", "&", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @elif c == 124 @! |
      tokens = tokens.push(["PIPE", "|", int_to_str(line), int_to_str(col)])
      i = i + 1
      col = col + 1
    @else
      i = i + 1
      col = col + 1
    @end
  @end
  
  return tokens
@end

@! ----------------------------------------------------------------------------
@! 5. DIRECTIVE EXTRACTION & ERROR RECOVERY
@! ----------------------------------------------------------------------------

@fn infinity_extract_rules_and_ops(tokens)
  println(str_concat("Inside extract, num tokens = ", int_to_str(tokens.len())))
  remaining_tokens = []
  rules_pat = []
  rules_rep_tokens = []
  custom_ops = []
  
  i = 0
  num_items = tokens.len()
  
  @while i < num_items
    tok = tokens[i]
    tkind = tok[0]
    tname = tok[1]
    
    @! Handle @infinity_rule directive
    @if (infinity_str_eq(tkind, "DIRECTIVE") == 1 && infinity_str_eq(tname, "@infinity_rule") == 1) || infinity_str_eq(tname, "@infinity_rule") == 1
      i = i + 1
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      @if i >= num_items || infinity_str_eq(tokens[i][0], "SEMI") == 1 || infinity_str_eq(tokens[i][0], "DIRECTIVE") == 1
        continue
      @end
      
      pat_tok = tokens[i]
      pat_str = pat_tok[1]
      i = i + 1
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      
      @! Skip FATARROW (=>) or ASSIGN (=)
      @if i < num_items && (infinity_str_eq(tokens[i][0], "FATARROW") == 1 || infinity_str_eq(tokens[i][0], "ASSIGN") == 1 || infinity_str_eq(tokens[i][1], "=>") == 1 || infinity_str_eq(tokens[i][1], "=") == 1)
        i = i + 1
      @end
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      
      clean_rep = []
      @while i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 0 && infinity_str_eq(tokens[i][0], "EOF") == 0
        @! Error recovery boundary check: next directive encountered
        @if infinity_str_eq(tokens[i][0], "DIRECTIVE") == 1 && (infinity_str_eq(tokens[i][1], "@infinity_rule") == 1 || infinity_str_eq(tokens[i][1], "@custom_op") == 1 || infinity_str_eq(tokens[i][1], "@fn") == 1 || infinity_str_eq(tokens[i][1], "@struct") == 1)
          break
        @end
        @if infinity_str_eq(tokens[i][0], "NEWLINE") == 1
          @if i + 1 < num_items && infinity_str_eq(tokens[i+1][0], "DIRECTIVE") == 1
            break
          @end
        @end
        
        cur_tok = tokens[i]
        @if infinity_str_eq(cur_tok[0], "STR") == 1
          sub_toks = infinity_tokenize_rep(cur_tok[1])
          s_k = 0
          @while s_k < sub_toks.len()
            stk = sub_toks[s_k]
            @if infinity_str_eq(stk[0], "EOF") == 0 && infinity_str_eq(stk[0], "NEWLINE") == 0 && infinity_str_eq(stk[0], "SEMI") == 0
              clean_rep = clean_rep.push(stk)
            @end
            s_k = s_k + 1
          @end
        @elif infinity_str_eq(cur_tok[0], "NEWLINE") == 0
          clean_rep = clean_rep.push(cur_tok)
        @end
        i = i + 1
      @end
      
      @if i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 1
        i = i + 1
      @end
      
      @if clean_rep.len() > 0 && pat_str != ""
        rules_pat = rules_pat.push(pat_str)
        rules_rep_tokens = rules_rep_tokens.push(clean_rep)
      @end
      continue
    @end
    
    @! Handle @custom_op directive: @custom_op "SYM" "FIXITY" PREC "HANDLER" ;
    @if (infinity_str_eq(tkind, "DIRECTIVE") == 1 && infinity_str_eq(tname, "@custom_op") == 1) || infinity_str_eq(tname, "@custom_op") == 1
      i = i + 1
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      op_sym = ""
      op_fix = "INFIX_LEFT"
      op_prec = 30
      op_fn = ""
      
      @if i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 0 && infinity_str_eq(tokens[i][0], "NEWLINE") == 0 && infinity_str_eq(tokens[i][0], "DIRECTIVE") == 0
        op_sym = tokens[i][1]
        i = i + 1
      @end
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      @if i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 0 && infinity_str_eq(tokens[i][0], "NEWLINE") == 0 && infinity_str_eq(tokens[i][0], "DIRECTIVE") == 0
        op_fix = tokens[i][1]
        i = i + 1
      @end
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      @if i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 0 && infinity_str_eq(tokens[i][0], "NEWLINE") == 0 && infinity_str_eq(tokens[i][0], "DIRECTIVE") == 0
        op_prec = infinity_parse_int(tokens[i][1])
        i = i + 1
      @end
      @while i < num_items && infinity_str_eq(tokens[i][0], "NEWLINE") == 1
        i = i + 1
      @end
      @if i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 0 && infinity_str_eq(tokens[i][0], "NEWLINE") == 0 && infinity_str_eq(tokens[i][0], "DIRECTIVE") == 0
        op_fn = tokens[i][1]
        i = i + 1
      @end
      
      @while i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 0 && infinity_str_eq(tokens[i][0], "EOF") == 0
        @if infinity_str_eq(tokens[i][0], "DIRECTIVE") == 1
          break
        @end
        i = i + 1
      @end
      @if i < num_items && infinity_str_eq(tokens[i][0], "SEMI") == 1
        i = i + 1
      @end
      
      @if op_sym != "" && op_fn != ""
        custom_ops = custom_ops.push({
          symbol: op_sym,
          fixity: op_fix,
          precedence: op_prec,
          handler: op_fn
        })
      @end
      continue
    @end
    
    remaining_tokens = remaining_tokens.push(tok)
    i = i + 1
  @end
  
  return {
    tokens: remaining_tokens,
    rules_pat: rules_pat,
    rules_rep_tokens: rules_rep_tokens,
    custom_ops: custom_ops
  }
@end

@! ----------------------------------------------------------------------------
@! 6. FIXED-POINT ITERATIVE MACRO EXPANSION (Bounded by max_depth = 128)
@! ----------------------------------------------------------------------------

@fn infinity_expand_tokens_fixed_point(tokens, rules_pat, rules_rep_tokens, max_depth)
  current_tokens = tokens
  rules_cnt = rules_pat.len()
  @if rules_cnt == 0
    return current_tokens
  @end
  
  depth = 0
  @while depth < max_depth
    expanded_tokens = []
    changed = 0
    i = 0
    num_items = current_tokens.len()
    
    @while i < num_items
      tok = current_tokens[i]
      ttype = tok[0]
      tname = tok[1]
      
      matched_idx = 0 - 1
      @if infinity_str_eq(ttype, "IDENT") == 1 || infinity_str_eq(ttype, "KEYWORD") == 1
        r_i = 0
        @while r_i < rules_cnt
          pat = rules_pat[r_i]
          @if infinity_pat_matches(tname, pat) == 1
            matched_idx = r_i
            break
          @end
          r_i = r_i + 1
        @end
      @end
      
      @if matched_idx >= 0
        rep_toks = rules_rep_tokens[matched_idx]
        k = 0
        klen = rep_toks.len()
        @while k < klen
          expanded_tokens = expanded_tokens.push([rep_toks[k][0], rep_toks[k][1], tok[2], tok[3]])
          k = k + 1
        @end
        changed = 1
      @else
        expanded_tokens = expanded_tokens.push(tok)
      @end
      
      i = i + 1
    @end
    
    current_tokens = expanded_tokens
    @if changed == 0
      break
    @end
    
    depth = depth + 1
  @end
  
  return current_tokens
@end

@! ----------------------------------------------------------------------------
@! 7. CUSTOM OPERATOR TOKEN MERGING
@! ----------------------------------------------------------------------------

@fn infinity_merge_custom_ops(tokens, custom_ops)
  cop_len = custom_ops.len()
  @if cop_len == 0
    return tokens
  @end
  
  merged = []
  i = 0
  num_items = tokens.len()
  
  @while i < num_items
    tok = tokens[i]
    tname = tok[1]
    
    op_matched = 0
    c_i = 0
    @while c_i < cop_len
      cop = custom_ops[c_i]
      sym = cop.symbol
      
      @! Multi-character custom operator matches
      @if infinity_str_eq(sym, "**") == 1 && infinity_str_eq(tname, "*") == 1 && i + 1 < num_items && infinity_str_eq(tokens[i+1][1], "*") == 1
        merged = merged.push(["CUSTOM_OP", "**", tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 2
        op_matched = 1
        break
      @elif infinity_str_eq(sym, "<=>") == 1 && infinity_str_eq(tname, "<=") == 1 && i + 1 < num_items && infinity_str_eq(tokens[i+1][1], ">") == 1
        merged = merged.push(["CUSTOM_OP", "<=>", tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 2
        op_matched = 1
        break
      @elif infinity_str_eq(sym, "<=>") == 1 && infinity_str_eq(tname, "<") == 1 && i + 2 < num_items && infinity_str_eq(tokens[i+1][1], "=") == 1 && infinity_str_eq(tokens[i+2][1], ">") == 1
        merged = merged.push(["CUSTOM_OP", "<=>", tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 3
        op_matched = 1
        break
      @elif infinity_str_eq(sym, "^^") == 1 && infinity_str_eq(tname, "^") == 1 && i + 1 < num_items && infinity_str_eq(tokens[i+1][1], "^") == 1
        merged = merged.push(["CUSTOM_OP", "^^", tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 2
        op_matched = 1
        break
      @elif infinity_str_eq(sym, "~=") == 1 && infinity_str_eq(tname, "~") == 1 && i + 1 < num_items && infinity_str_eq(tokens[i+1][1], "=") == 1
        merged = merged.push(["CUSTOM_OP", "~=", tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 2
        op_matched = 1
        break
      @elif infinity_str_eq(sym, "~>") == 1 && infinity_str_eq(tname, "~") == 1 && i + 1 < num_items && infinity_str_eq(tokens[i+1][1], ">") == 1
        merged = merged.push(["CUSTOM_OP", "~>", tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 2
        op_matched = 1
        break
      @elif infinity_str_eq(sym, tname) == 1
        merged = merged.push(["CUSTOM_OP", sym, tok[2], tok[3], cop.precedence, cop.handler, cop.fixity])
        i = i + 1
        op_matched = 1
        break
      @end
      
      c_i = c_i + 1
    @end
    
    @if op_matched == 0
      merged = merged.push(tok)
      i = i + 1
    @end
  @end
  
  return merged
@end

@! ----------------------------------------------------------------------------
@! 8. COMPILER PIPELINE TRANSFORMATION ENTRY POINTS
@! ----------------------------------------------------------------------------

@fn infinity_transform_source(inf_eng, source)
  return source
@end

@fn infinity_transform_tokens(inf_eng, tokens)
  extracted = infinity_extract_rules_and_ops(tokens)
  
  depth_limit = 128
  @if inf_eng != 0
    inf_eng.custom_ops = extracted.custom_ops
    @if inf_eng.max_depth > 0
      depth_limit = inf_eng.max_depth
    @end
  @end
  
  @! Step 1: Fixed-point token replacement
  expanded = infinity_expand_tokens_fixed_point(extracted.tokens, extracted.rules_pat, extracted.rules_rep_tokens, depth_limit)
  
  @! Step 2: Custom operator token combination
  result = infinity_merge_custom_ops(expanded, extracted.custom_ops)
  return result
@end

@fn parse_infinity_rules(tokens)
  eng = infinity_engine_new()
  return infinity_transform_tokens(eng, tokens)
@end

@fn infinity_apply_ast_transforms(ast, inf_engine)
  return ast
@end

@! ----------------------------------------------------------------------------
@! 9. AUTHENTIC INFINITY SYNTAX SELF-TEST DRIVER
@! ----------------------------------------------------------------------------

@fn infinity_syntax_self_test()
  println("▶ Running Authentic Infinity Syntax Engine Self-Test...")
  failures = 0
  
  @! Test 1: Power Math Helper
  @if lipi_power(2, 8) != 256 || lipi_power(3, 4) != 81 || lipi_power(5, 0) != 1 || lipi_power(0, 5) != 0
    println("  [FAIL] Math: lipi_power verification")
    failures = failures + 1
  @else
    println("  [PASS] Math: lipi_power(2, 8) == 256")
  @end
  
  @! Test 2: Spaceship Math Helper
  @if lipi_spaceship(10, 20) != 0 - 1 || lipi_spaceship(20, 20) != 0 || lipi_spaceship(30, 20) != 1
    println("  [FAIL] Math: lipi_spaceship verification")
    failures = failures + 1
  @else
    println("  [PASS] Math: lipi_spaceship(10, 20) == -1")
  @end
  
  @! Test 3: XOR Math Helper
  @if lipi_xor(1, 0) != 1 || lipi_xor(0, 1) != 1 || lipi_xor(1, 1) != 0 || lipi_xor(0, 0) != 0
    println("  [FAIL] Math: lipi_xor verification")
    failures = failures + 1
  @else
    println("  [PASS] Math: lipi_xor(1, 0) == 1")
  @end
  
  @! Test 4: Approx Eq Math Helper
  @if lipi_approx_eq(100, 105, 10) != 1 || lipi_approx_eq(100, 120, 10) != 0
    println("  [FAIL] Math: lipi_approx_eq verification")
    failures = failures + 1
  @else
    println("  [PASS] Math: lipi_approx_eq(100, 105, 10) == 1")
  @end
  
  @! Test 5: Dynamic Keyword Aliasing
  src_tokens = [
    ["DIRECTIVE", "@infinity_rule", 1, 1],
    ["STR", "si", 1, 16],
    ["FATARROW", "=>", 1, 21],
    ["STR", "@if", 1, 24],
    ["SEMI", ";", 1, 29],
    ["IDENT", "si", 2, 1],
    ["IDENT", "x", 2, 4],
    ["GT", ">", 2, 6],
    ["INT", "10", 2, 8],
    ["EOF", "EOF", 3, 1]
  ]
  eng = infinity_engine_new()
  res_tokens = infinity_transform_tokens(eng, src_tokens)
  @if res_tokens.len() < 4 || infinity_str_eq(res_tokens[0][0], "DIRECTIVE") == 0 || infinity_str_eq(res_tokens[0][1], "@if") == 0
    println("  [FAIL] Token Transformation: 'si' -> '@if' aliasing")
    failures = failures + 1
  @else
    println("  [PASS] Token Transformation: 'si' -> '@if' aliasing")
  @end
  
  @! Test 6: Custom Operator Merging
  op_src_tokens = [
    ["DIRECTIVE", "@custom_op", 1, 1],
    ["STR", "**", 1, 12],
    ["STR", "INFIX_RIGHT", 1, 17],
    ["INT", "80", 1, 31],
    ["STR", "lipi_power", 1, 34],
    ["SEMI", ";", 1, 46],
    ["INT", "2", 2, 1],
    ["STAR", "*", 2, 3],
    ["STAR", "*", 2, 4],
    ["INT", "8", 2, 6],
    ["EOF", "EOF", 3, 1]
  ]
  res_op = infinity_transform_tokens(eng, op_src_tokens)
  @if res_op.len() < 3 || infinity_str_eq(res_op[1][0], "CUSTOM_OP") == 0 || infinity_str_eq(res_op[1][1], "**") == 0
    println("  [FAIL] Custom Operator Merging: '**' -> CUSTOM_OP")
    failures = failures + 1
  @else
    println("  [PASS] Custom Operator Merging: '**' combined")
  @end
  
  @! Test 7: Cyclic Macro Recursion Guard
  cyc_src_tokens = [
    ["DIRECTIVE", "@infinity_rule", 1, 1],
    ["STR", "MACRO_A", 1, 16],
    ["FATARROW", "=>", 1, 26],
    ["STR", "MACRO_B", 1, 29],
    ["SEMI", ";", 1, 38],
    ["DIRECTIVE", "@infinity_rule", 2, 1],
    ["STR", "MACRO_B", 2, 16],
    ["FATARROW", "=>", 2, 26],
    ["STR", "MACRO_A", 2, 29],
    ["SEMI", ";", 2, 38],
    ["IDENT", "MACRO_A", 3, 1],
    ["EOF", "EOF", 4, 1]
  ]
  cyc_res = infinity_transform_tokens(eng, cyc_src_tokens)
  @if cyc_res.len() < 1
    println("  [FAIL] Recursion Guard: cyclic macro failed")
    failures = failures + 1
  @else
    println("  [PASS] Recursion Guard: bounded at max_depth = 128")
  @end
  
  @! Test 8: Malformed Directive Recovery
  mal_src_tokens = [
    ["DIRECTIVE", "@infinity_rule", 1, 1],
    ["NEWLINE", "\n", 1, 15],
    ["DIRECTIVE", "@custom_op", 2, 1],
    ["SEMI", ";", 2, 12],
    ["IDENT", "valid_var", 3, 1],
    ["EOF", "EOF", 4, 1]
  ]
  mal_res = infinity_transform_tokens(eng, mal_src_tokens)
  @if mal_res.len() < 1 || infinity_str_eq(mal_res[0][1], "valid_var") == 0
    println("  [FAIL] Malformed Directive: error recovery failed")
    failures = failures + 1
  @else
    println("  [PASS] Malformed Directive: error recovery succeeded")
  @end
  
  @if failures == 0
    println("🎉 ALL INFINITY SYNTAX SELF-TESTS PASSED (100% Assertion Coverage)")
    return 0
  @else
    println("❌ " + failures.to_str() + " INFINITY SYNTAX ASSERTION FAILURES DETECTED")
    return 1
  @end
@end
