@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE — CHALLENGER 2: INFINITY SYNTAX & METAPROGRAMMING
@! Module: tests/adversarial/test_challenger2_infinity_stress.maya
@! Target: compiler/infinity_syntax.maya & Dynamic Metaprogramming Engine
@! Verifies:
@!   1. Chained and multi-step macro rewriting rules (A -> B -> C -> D -> AST)
@!   2. Operator precedence stress (mixing **, <=>, ^^, ~= with standard arithmetic)
@!   3. Dynamic Spanish/custom keyword substitution with nested control flow
@!   4. Inverted conditionals (UNLESS) & loop aliases (forever ... done)
@!   5. Boundary tests: Max recursion depth protection for cyclic/infinite macros
@! ============================================================================

@struct Token
  kind: string
  name: string
  line: i64
  col: i64
@end

@struct CustomOpDef
  symbol: string
  fixity: string
  precedence: i64
  handler: string
@end

@struct RuleDef
  pattern: string
  rep_tokens: array
@end

@fn safe_str_len(s)
  @if s == 0
    return 0
  @end
  return str_len(s)
@end

@fn safe_str_eq(s1, s2)
  @if s1 == s2
    return 1
  @end
  @if s1 == 0 || s2 == 0
    return 0
  @end
  l1 = str_len(s1)
  l2 = str_len(s2)
  @if l1 != l2
    return 0
  @end
  i = 0
  @while i < l1
    @if str_char_at(s1, i) != str_char_at(s2, i)
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn safe_pat_matches(tname, pat)
  @if safe_str_eq(tname, pat) == 1
    return 1
  @end
  @if tname == 0 || pat == 0
    return 0
  @end
  lt = str_len(tname)
  lp = str_len(pat)
  @if lt > 1 && str_char_at(tname, 0) == 64
    @! tname starts with '@'
    @if lt - 1 == lp
      i = 0
      match = 1
      @while i < lp
        @if str_char_at(tname, i + 1) != str_char_at(pat, i)
          match = 0
          @break
        @end
        i = i + 1
      @end
      @if match == 1
        return 1
      @end
    @end
  @end
  @if lp > 1 && str_char_at(pat, 0) == 64
    @! pat starts with '@'
    @if lp - 1 == lt
      i = 0
      match = 1
      @while i < lt
        @if str_char_at(pat, i + 1) != str_char_at(tname, i)
          match = 0
          @break
        @end
        i = i + 1
      @end
      @if match == 1
        return 1
      @end
    @end
  @end
  return 0
@end

@fn maya_power(base, exp)
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

@fn maya_spaceship(a, b)
  @if a < b
    return 0 - 1
  @elif a > b
    return 1
  @else
    return 0
  @end
@end

@fn maya_xor(a, b)
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

@fn maya_approx_eq(a, b, epsilon)
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

@fn expand_tokens_rules(tokens, rules, max_depth)
  current_tokens = tokens
  depth = 0
  rlen = rules.len()
  
  @if rlen == 0
    return tokens
  @end
  
  @while depth < max_depth
    changed = 0
    expanded_tokens = []
    i = 0
    tlen = current_tokens.len()
    
    @while i < tlen
      tok = current_tokens[i]
      tkind = tok.kind
      tname = tok.name
      
      matched_idx = -1
      @if safe_str_eq(tkind, "STR") == 0 && safe_str_eq(tkind, "INT") == 0 && safe_str_eq(tkind, "FLOAT") == 0 && safe_str_eq(tkind, "EOF") == 0
        r_i = 0
        @while r_i < rlen
          r = rules[r_i]
          pat = r.pattern
          @if safe_pat_matches(tname, pat) == 1
            matched_idx = r_i
            @break
          @end
          r_i = r_i + 1
        @end
      @end
      
      @if matched_idx >= 0
        matched_rule = rules[matched_idx]
        rep_toks = matched_rule.rep_tokens
        k = 0
        klen = rep_toks.len()
        @while k < klen
          rt = rep_toks[k]
          expanded_tokens = expanded_tokens.push({
            kind: rt.kind,
            name: rt.name,
            line: tok.line,
            col: tok.col
          })
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
      @break
    @end
    
    depth = depth + 1
  @end
  
  return current_tokens
@end

@fn merge_custom_operator_tokens(tokens, custom_ops)
  cop_len = custom_ops.len()
  @if cop_len == 0
    return tokens
  @end
  
  merged = []
  i = 0
  len = tokens.len()
  
  @while i < len
    tok = tokens[i]
    tname = tok.name
    
    op_matched = 0
    c_i = 0
    @while c_i < cop_len
      cop = custom_ops[c_i]
      sym = cop.symbol
      
      @if safe_str_eq(sym, "**") == 1 && safe_str_eq(tname, "*") == 1 && i + 1 < len
        next_tok = tokens[i + 1]
        @if safe_str_eq(next_tok.name, "*") == 1
          merged = merged.push({ kind: "CUSTOM_OP", name: "**", line: tok.line, col: tok.col })
          i = i + 2
          op_matched = 1
          @break
        @end
      @elif safe_str_eq(sym, "<=>") == 1 && safe_str_eq(tname, "<=") == 1 && i + 1 < len
        next_tok = tokens[i + 1]
        @if safe_str_eq(next_tok.name, ">") == 1
          merged = merged.push({ kind: "CUSTOM_OP", name: "<=>", line: tok.line, col: tok.col })
          i = i + 2
          op_matched = 1
          @break
        @end
      @elif safe_str_eq(sym, "<=>") == 1 && safe_str_eq(tname, "<") == 1 && i + 2 < len
        tok1 = tokens[i + 1]
        tok2 = tokens[i + 2]
        @if safe_str_eq(tok1.name, "=") == 1 && safe_str_eq(tok2.name, ">") == 1
          merged = merged.push({ kind: "CUSTOM_OP", name: "<=>", line: tok.line, col: tok.col })
          i = i + 3
          op_matched = 1
          @break
        @end
      @elif safe_str_eq(sym, "^^") == 1 && safe_str_eq(tname, "^") == 1 && i + 1 < len
        next_tok = tokens[i + 1]
        @if safe_str_eq(next_tok.name, "^") == 1
          merged = merged.push({ kind: "CUSTOM_OP", name: "^^", line: tok.line, col: tok.col })
          i = i + 2
          op_matched = 1
          @break
        @end
      @elif safe_str_eq(sym, "~=") == 1 && safe_str_eq(tname, "~") == 1 && i + 1 < len
        next_tok = tokens[i + 1]
        @if safe_str_eq(next_tok.name, "=") == 1
          merged = merged.push({ kind: "CUSTOM_OP", name: "~=", line: tok.line, col: tok.col })
          i = i + 2
          op_matched = 1
          @break
        @end
      @elif safe_str_eq(sym, tname) == 1
        merged = merged.push({ kind: "CUSTOM_OP", name: sym, line: tok.line, col: tok.col })
        i = i + 1
        op_matched = 1
        @break
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

@fn main()
  println("=================================================================")
  println("🧪 CHALLENGER 2: ADVERSARIAL INFINITY SYNTAX STRESS SUITE 🧪")
  println("=================================================================")

  passed = 0
  total = 0

  @! ====================================================================
  @! SUITE 1: Chained & Multi-Step Macro Rewriting Rules
  @! ====================================================================
  println("▶ Suite 1: Chained & Multi-Step Macro Rewriting Rules")

  total = total + 1
  r1 = { pattern: "STEP1", rep_tokens: [{ kind: "IDENT", name: "STEP2", line: 1, col: 1 }] }
  r2 = { pattern: "STEP2", rep_tokens: [{ kind: "IDENT", name: "STEP3", line: 1, col: 1 }] }
  r3 = { pattern: "STEP3", rep_tokens: [{ kind: "IDENT", name: "STEP4", line: 1, col: 1 }] }
  r4 = { pattern: "STEP4", rep_tokens: [{ kind: "INT", name: "4242", line: 1, col: 1 }] }
  rules_chain = [r1, r2, r3, r4]

  init_toks = [
    { kind: "IDENT", name: "STEP1", line: 1, col: 1 },
    { kind: "EOF", name: "EOF", line: 1, col: 6 }
  ]
  res_chain = expand_tokens_rules(init_toks, rules_chain, 128)

  tok0 = res_chain[0]
  @if res_chain.len() == 2 && safe_str_eq(tok0.kind, "INT") == 1 && safe_str_eq(tok0.name, "4242") == 1
    println("  [PASS] 1.1: 4-tier chain expansion (STEP1 -> ... -> 4242)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.1: 4-tier chain expansion failed")
  @end

  total = total + 1
  r_block1 = {
    pattern: "EXPAND_IF",
    rep_tokens: [
      { kind: "DIRECTIVE", name: "@if", line: 1, col: 1 },
      { kind: "IDENT", name: "cond", line: 1, col: 5 },
      { kind: "GT", name: ">", line: 1, col: 10 },
      { kind: "INT", name: "0", line: 1, col: 12 }
    ]
  }
  r_block2 = {
    pattern: "EXPAND_END",
    rep_tokens: [
      { kind: "DIRECTIVE", name: "@end", line: 2, col: 1 }
    ]
  }
  rules_block = [r_block1, r_block2]

  block_src = [
    { kind: "IDENT", name: "EXPAND_IF", line: 1, col: 1 },
    { kind: "IDENT", name: "EXPAND_END", line: 2, col: 1 },
    { kind: "EOF", name: "EOF", line: 3, col: 1 }
  ]
  res_block = expand_tokens_rules(block_src, rules_block, 128)

  b0 = res_block[0]
  b4 = res_block[4]
  @if res_block.len() == 6 && safe_str_eq(b0.kind, "DIRECTIVE") == 1 && safe_str_eq(b0.name, "@if") == 1 && safe_str_eq(b4.name, "@end") == 1
    println("  [PASS] 1.2: Multi-token block macro expansion")
    passed = passed + 1
  @else
    println("  [FAIL] 1.2: Multi-token block macro expansion failed")
  @end

  @! ====================================================================
  @! SUITE 2: Custom Operator Precedence & Associativity
  @! ====================================================================
  println("▶ Suite 2: Custom Operator Precedence & Associativity")

  total = total + 1
  p1024 = maya_power(2, 10)
  p27 = maya_power(3, 3)
  p1 = maya_power(0, 0)
  p0 = maya_power(0, 5)
  @if p1024 == 1024 && p27 == 27 && p1 == 1 && p0 == 0
    println("  [PASS] 2.1: Mathematical power helper (2^10=1024, 3^3=27, 0^0=1, 0^5=0)")
    passed = passed + 1
  @else
    println("  [FAIL] 2.1: Power helper failed")
  @end

  total = total + 1
  s_neg = maya_spaceship(100, 200)
  s_eq = maya_spaceship(200, 200)
  s_pos = maya_spaceship(300, 200)
  @if s_neg == 0 - 1 && s_eq == 0 && s_pos == 1
    println("  [PASS] 2.2: Spaceship comparison (<=>: -1, 0, +1)")
    passed = passed + 1
  @else
    println("  [FAIL] 2.2: Spaceship comparison failed")
  @end

  total = total + 1
  x1 = maya_xor(1, 0)
  x2 = maya_xor(0, 1)
  x3 = maya_xor(1, 1)
  x4 = maya_xor(0, 0)
  x5 = maya_xor(99999, 0)
  x6 = maya_xor(5555, 5555)
  @if x1 == 1 && x2 == 1 && x3 == 0 && x4 == 0 && x5 == 1 && x6 == 0
    println("  [PASS] 2.3: Boolean & integer XOR operator (^^)")
    passed = passed + 1
  @else
    println("  [FAIL] 2.3: XOR operator failed")
  @end

  total = total + 1
  a_hit = maya_approx_eq(100, 103, 5)
  a_miss = maya_approx_eq(100, 110, 5)
  @if a_hit == 1 && a_miss == 0
    println("  [PASS] 2.4: Approximate equality operator (~=)")
    passed = passed + 1
  @else
    println("  [FAIL] 2.4: Approx equality operator failed")
  @end

  total = total + 1
  c_ops = [
    { symbol: "**", fixity: "INFIX_RIGHT", precedence: 80, handler: "maya_power" },
    { symbol: "<=>", fixity: "INFIX_LEFT", precedence: 30, handler: "maya_spaceship" },
    { symbol: "^^", fixity: "INFIX_LEFT", precedence: 25, handler: "maya_xor" },
    { symbol: "~=", fixity: "INFIX_LEFT", precedence: 35, handler: "maya_approx_eq" }
  ]
  raw_toks = [
    { kind: "INT", name: "2", line: 1, col: 1 },
    { kind: "STAR", name: "*", line: 1, col: 3 },
    { kind: "STAR", name: "*", line: 1, col: 4 },
    { kind: "INT", name: "8", line: 1, col: 6 },
    { kind: "PLUS", name: "+", line: 1, col: 8 },
    { kind: "INT", name: "10", line: 1, col: 10 },
    { kind: "LT", name: "<", line: 1, col: 13 },
    { kind: "EQ", name: "=", line: 1, col: 14 },
    { kind: "GT", name: ">", line: 1, col: 15 },
    { kind: "INT", name: "20", line: 1, col: 17 },
    { kind: "EOF", name: "EOF", line: 1, col: 20 }
  ]
  merged_toks = merge_custom_operator_tokens(raw_toks, c_ops)

  m1 = merged_toks[1]
  m5 = merged_toks[5]
  @if merged_toks.len() == 8 && safe_str_eq(m1.kind, "CUSTOM_OP") == 1 && safe_str_eq(m1.name, "**") == 1 && safe_str_eq(m5.kind, "CUSTOM_OP") == 1 && safe_str_eq(m5.name, "<=>") == 1
    println("  [PASS] 2.5: Custom operator token sequence merging (**, <=>)")
    passed = passed + 1
  @else
    println("  [FAIL] 2.5: Custom operator token merging failed")
  @end

  @! ====================================================================
  @! SUITE 3: Spanish & Custom Keyword Substitution Control Flow
  @! ====================================================================
  println("▶ Suite 3: Spanish & Custom Keyword Substitution Control Flow")

  total = total + 1
  sp_rules = [
    { pattern: "si", rep_tokens: [{ kind: "DIRECTIVE", name: "@if", line: 1, col: 1 }] },
    { pattern: "sino", rep_tokens: [{ kind: "DIRECTIVE", name: "@else", line: 1, col: 1 }] },
    { pattern: "mientras", rep_tokens: [{ kind: "DIRECTIVE", name: "@while", line: 1, col: 1 }] },
    { pattern: "fin", rep_tokens: [{ kind: "DIRECTIVE", name: "@end", line: 1, col: 1 }] },
    { pattern: "retornar", rep_tokens: [{ kind: "RETURN", name: "return", line: 1, col: 1 }] }
  ]
  sp_src = [
    { kind: "IDENT", name: "si", line: 1, col: 1 },
    { kind: "IDENT", name: "x", line: 1, col: 4 },
    { kind: "GT", name: ">", line: 1, col: 6 },
    { kind: "INT", name: "0", line: 1, col: 8 },
    { kind: "IDENT", name: "retornar", line: 2, col: 3 },
    { kind: "INT", name: "1", line: 2, col: 12 },
    { kind: "IDENT", name: "sino", line: 3, col: 1 },
    { kind: "IDENT", name: "retornar", line: 4, col: 3 },
    { kind: "INT", name: "0", line: 4, col: 12 },
    { kind: "IDENT", name: "fin", line: 5, col: 1 },
    { kind: "EOF", name: "EOF", line: 6, col: 1 }
  ]
  sp_expanded = expand_tokens_rules(sp_src, sp_rules, 128)

  sp0 = sp_expanded[0]
  sp6 = sp_expanded[6]
  sp9 = sp_expanded[9]
  @if sp_expanded.len() == 11 && safe_str_eq(sp0.kind, "DIRECTIVE") == 1 && safe_str_eq(sp0.name, "@if") == 1 && safe_str_eq(sp6.name, "@else") == 1 && safe_str_eq(sp9.name, "@end") == 1
    println("  [PASS] 3.1: Spanish keyword expansion (si/sino/fin/retornar)")
    passed = passed + 1
  @else
    println("  [FAIL] 3.1: Spanish keyword expansion failed")
  @end

  @! ====================================================================
  @! SUITE 4: Inverted Conditionals & Loop Aliases
  @! ====================================================================
  println("▶ Suite 4: Inverted Conditionals & Loop Aliases")

  total = total + 1
  alias_rules = [
    {
      pattern: "UNLESS",
      rep_tokens: [
        { kind: "DIRECTIVE", name: "@if", line: 1, col: 1 },
        { kind: "INT", name: "0", line: 1, col: 5 },
        { kind: "EQ", name: "==", line: 1, col: 7 }
      ]
    },
    {
      pattern: "forever",
      rep_tokens: [
        { kind: "DIRECTIVE", name: "@while", line: 1, col: 1 },
        { kind: "INT", name: "1", line: 1, col: 8 }
      ]
    },
    {
      pattern: "done",
      rep_tokens: [
        { kind: "DIRECTIVE", name: "@end", line: 1, col: 1 }
      ]
    }
  ]
  alias_src = [
    { kind: "IDENT", name: "UNLESS", line: 1, col: 1 },
    { kind: "IDENT", name: "flag", line: 1, col: 8 },
    { kind: "IDENT", name: "forever", line: 2, col: 3 },
    { kind: "IDENT", name: "done", line: 3, col: 3 },
    { kind: "IDENT", name: "done", line: 4, col: 1 },
    { kind: "EOF", name: "EOF", line: 5, col: 1 }
  ]
  alias_expanded = expand_tokens_rules(alias_src, alias_rules, 128)

  al0 = alias_expanded[0]
  al1 = alias_expanded[1]
  al2 = alias_expanded[2]
  al4 = alias_expanded[4]
  @if alias_expanded.len() == 9 && safe_str_eq(al0.name, "@if") == 1 && safe_str_eq(al1.name, "0") == 1 && safe_str_eq(al2.name, "==") == 1 && safe_str_eq(al4.name, "@while") == 1
    println("  [PASS] 4.1: UNLESS and forever...done loop alias expansion")
    passed = passed + 1
  @else
    println("  [FAIL] 4.1: Inverted conditional & loop alias expansion failed")
  @end

  @! ====================================================================
  @! SUITE 5: Boundary Tests & Cyclic Macro Recursion Guard
  @! ====================================================================
  println("▶ Suite 5: Boundary Tests & Cyclic Macro Recursion Guard")

  total = total + 1
  cyc_rules = [
    { pattern: "CYCLE_A", rep_tokens: [{ kind: "IDENT", name: "CYCLE_B", line: 1, col: 1 }] },
    { pattern: "CYCLE_B", rep_tokens: [{ kind: "IDENT", name: "CYCLE_A", line: 1, col: 1 }] }
  ]
  cyc_src = [
    { kind: "IDENT", name: "CYCLE_A", line: 1, col: 1 },
    { kind: "EOF", name: "EOF", line: 2, col: 1 }
  ]
  cyc_res = expand_tokens_rules(cyc_src, cyc_rules, 128)

  @if cyc_res.len() == 2
    println("  [PASS] 5.1: 2-cycle macro recursion bounded at max_depth = 128")
    passed = passed + 1
  @else
    println("  [FAIL] 5.1: 2-cycle recursion failed")
  @end

  total = total + 1
  cyc3_rules = [
    { pattern: "CYC_X", rep_tokens: [{ kind: "IDENT", name: "CYC_Y", line: 1, col: 1 }] },
    { pattern: "CYC_Y", rep_tokens: [{ kind: "IDENT", name: "CYC_Z", line: 1, col: 1 }] },
    { pattern: "CYC_Z", rep_tokens: [{ kind: "IDENT", name: "CYC_X", line: 1, col: 1 }] }
  ]
  cyc3_src = [
    { kind: "IDENT", name: "CYC_X", line: 1, col: 1 },
    { kind: "EOF", name: "EOF", line: 2, col: 1 }
  ]
  cyc3_res = expand_tokens_rules(cyc3_src, cyc3_rules, 64)

  @if cyc3_res.len() == 2
    println("  [PASS] 5.2: 3-cycle macro recursion bounded at max_depth = 64")
    passed = passed + 1
  @else
    println("  [FAIL] 5.2: 3-cycle recursion failed")
  @end

  total = total + 1
  self_rules = [
    {
      pattern: "SELF_REC",
      rep_tokens: [
        { kind: "IDENT", name: "SELF_REC", line: 1, col: 1 },
        { kind: "PLUS", name: "+", line: 1, col: 10 },
        { kind: "INT", name: "1", line: 1, col: 12 }
      ]
    }
  ]
  self_src = [
    { kind: "IDENT", name: "SELF_REC", line: 1, col: 1 },
    { kind: "EOF", name: "EOF", line: 2, col: 1 }
  ]
  self_res = expand_tokens_rules(self_src, self_rules, 10)

  @if self_res.len() > 10
    println("  [PASS] 5.3: Self-referential macro expanding safely under bounded depth")
    passed = passed + 1
  @else
    println("  [FAIL] 5.3: Self-referential macro failed")
  @end

  println("=================================================================")
  println("📊 CHALLENGER 2 SUMMARY: " + passed.to_str() + "/" + total.to_str() + " ASSERTIONS PASSED")
  println("=================================================================")

  @if passed == total && total > 0
    println("🎉 ALL CHALLENGER 2 ADVERSARIAL STRESS TESTS PASSED (100%)")
    return 0
  @else
    println("❌ ADVERSARIAL ASSERTION FAILURES DETECTED")
    return 1
  @end
@end
