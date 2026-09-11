@! ============================================================================
@! MAYA ADVANCED INTERACTIVE REPL ENGINE
@! 100% Written in Pure Maya Language
@! Features: Multi-operator Arithmetic Parsing, Parentheses, Variable Environment,
@! REPL Metacommands (.help, .vars, .version, .exit, .clear)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. ENVIRONMENT / SYMBOL TABLE
@! ----------------------------------------------------------------------------

@fn repl_env_new()
  return {
    vars: [] @! array of { name: "x", val: 42, is_str: 0, sval: "" }
  }
@end

@fn repl_env_set_int(env, name, val)
  new_vars = []
  updated = 0
  i = 0
  len = env.vars.len()
  @while i < len
    v = env.vars[i]
    @if v.name == name
      new_vars = new_vars.push({ name: name, val: val, is_str: 0, sval: "" })
      updated = 1
    @else
      new_vars = new_vars.push(v)
    @end
    i = i + 1
  @end
  @if updated == 0
    new_vars = new_vars.push({ name: name, val: val, is_str: 0, sval: "" })
  @end
  env.vars = new_vars
  return env
@end

@fn repl_env_get_int(env, name)
  i = 0
  len = env.vars.len()
  @while i < len
    v = env.vars[i]
    @if v.name == name && v.is_str == 0
      return v.val
    @end
    i = i + 1
  @end
  return 0
@end

@fn repl_env_has(env, name)
  i = 0
  len = env.vars.len()
  @while i < len
    @if env.vars[i].name == name return 1 @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 2. RECURSIVE DESCENT ARITHMETIC EVALUATOR
@! ----------------------------------------------------------------------------

@fn eval_skip_spaces(s, idx)
  len = str_len(s)
  @while idx < len && (str_char_at(s, idx) == 32 || str_char_at(s, idx) == 9)
    idx = idx + 1
  @end
  return idx
@end

@fn eval_primary(s, idx, env)
  idx = eval_skip_spaces(s, idx)
  len = str_len(s)
  @if idx >= len return { val: 0, next_idx: idx } @end
  
  ch = str_char_at(s, idx)
  
  @! Parenthesized expression: ( expr )
  @if ch == 40 @! '('
    res = eval_expression(s, idx + 1, env)
    next_i = eval_skip_spaces(s, res.next_idx)
    @if next_i < len && str_char_at(s, next_i) == 41 @! ')'
      return { val: res.val, next_idx: next_i + 1 }
    @end
    return res
  @end
  
  @! Unary minus: -x
  @if ch == 45 @! '-'
    res = eval_primary(s, idx + 1, env)
    return { val: 0 - res.val, next_idx: res.next_idx }
  @end
  
  @! Number literal
  @if ch >= 48 && ch <= 57
    num = 0
    @while idx < len && str_char_at(s, idx) >= 48 && str_char_at(s, idx) <= 57
      digit = str_char_at(s, idx) - 48
      num = num * 10 + digit
      idx = idx + 1
    @end
    return { val: num, next_idx: idx }
  @end
  
  @! Variable identifier: x, y, total
  @if (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 95
    vname = ""
    is_done = 0
    @while idx < len && is_done == 0
      c = str_char_at(s, idx)
      @if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95
        vname = vname + str_substr(s, idx, idx + 1)
        idx = idx + 1
      @else
        is_done = 1
      @end
    @end
    v_val = repl_env_get_int(env, vname)
    return { val: v_val, next_idx: idx }
  @end
  
  return { val: 0, next_idx: idx }
@end

@fn eval_factor(s, idx, env)
  res = eval_primary(s, idx, env)
  cur_val = res.val
  idx = res.next_idx
  len = str_len(s)
  
  @while 1 == 1
    idx = eval_skip_spaces(s, idx)
    @if idx >= len return { val: cur_val, next_idx: idx } @end
    
    op = str_char_at(s, idx)
    @if op == 42 @! '*'
      r = eval_primary(s, idx + 1, env)
      cur_val = cur_val * r.val
      idx = r.next_idx
    @elif op == 47 @! '/'
      r = eval_primary(s, idx + 1, env)
      @if r.val != 0
        cur_val = cur_val / r.val
      @end
      idx = r.next_idx
    @elif op == 37 @! '%'
      r = eval_primary(s, idx + 1, env)
      @if r.val != 0
        cur_val = cur_val % r.val
      @end
      idx = r.next_idx
    @else
      return { val: cur_val, next_idx: idx }
    @end
  @end
  return { val: cur_val, next_idx: idx }
@end

@fn eval_expression(s, idx, env)
  res = eval_factor(s, idx, env)
  cur_val = res.val
  idx = res.next_idx
  len = str_len(s)
  
  @while 1 == 1
    idx = eval_skip_spaces(s, idx)
    @if idx >= len return { val: cur_val, next_idx: idx } @end
    
    op = str_char_at(s, idx)
    @if op == 43 @! '+'
      r = eval_factor(s, idx + 1, env)
      cur_val = cur_val + r.val
      idx = r.next_idx
    @elif op == 45 @! '-'
      r = eval_factor(s, idx + 1, env)
      cur_val = cur_val - r.val
      idx = r.next_idx
    @else
      return { val: cur_val, next_idx: idx }
    @end
  @end
  return { val: cur_val, next_idx: idx }
@end

@! ----------------------------------------------------------------------------
@! 3. REPL LINE PROCESSOR
@! ----------------------------------------------------------------------------

@fn repl_process_line(line, env)
  trimmed = str_trim(line)
  @if str_len(trimmed) == 0 return { output: "", env: env, exit_req: 0 } @end
  
  @! Metacommands
  @if trimmed == "help" || trimmed == ".help"
    println("  Maya REPL Help:")
    println("    .vars        List all environment variables")
    println("    .version     Display language version")
    println("    .clear       Clear terminal state")
    println("    exit / quit  Exit REPL")
    println("    <expr>       Evaluate arithmetic expression (e.g. (10 + 20) * 3)")
    println("    x = <expr>   Assign variable value")
    return { output: "", env: env, exit_req: 0 }
  @end
  
  @if trimmed == "exit" || trimmed == "quit" || trimmed == ".exit"
    return { output: "Goodbye!", env: env, exit_req: 1 }
  @end
  
  @if trimmed == "version" || trimmed == ".version"
    println("  Maya Programming Language v2.0.0 (Universe Edition)")
    return { output: "", env: env, exit_req: 0 }
  @end
  
  @if trimmed == "vars" || trimmed == ".vars"
    println("  Environment Variables (" + env.vars.len().to_str() + "):")
    i = 0
    @while i < env.vars.len()
      v = env.vars[i]
      println("    " + v.name + " = " + v.val.to_str())
      i = i + 1
    @end
    return { output: "", env: env, exit_req: 0 }
  @end
  
  @! Check for variable assignment: 'name = expr'
  @if contains(trimmed, "=")
    eq_idx = str_index_of(trimmed, "=")
    vname = str_trim(str_substr(trimmed, 0, eq_idx))
    expr_str = str_trim(str_substr(trimmed, eq_idx + 1, str_len(trimmed)))
    res = eval_expression(expr_str, 0, env)
    env = repl_env_set_int(env, vname, res.val)
    return { output: vname + " = " + res.val.to_str(), env: env, exit_req: 0 }
  @end
  
  @! Expression evaluation
  res = eval_expression(trimmed, 0, env)
  return { output: res.val.to_str(), env: env, exit_req: 0 }
@end
