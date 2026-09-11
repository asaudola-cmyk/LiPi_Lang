@! ============================================================================
@! MAYA SOVEREIGN INTERACTIVE REPL ENGINE
@! Module: compiler/backend/jit/repl.maya
@! Architecture: In-Memory JIT-Powered Interactive Read-Eval-Print Loop
@! Features: Multiline Input Buffering, Metacommands, Persistent Variable & Function
@! Environment, Machine Code Inspection, Syntax Error Reporting
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURES & INTERFACES
@! ----------------------------------------------------------------------------

@struct ReplState
  engine: any
  history: array
  multiline_buf: string
  running: i64
  prompt: string
  prompt_cont: string
  vars: array
@end

@struct ReplVar
  name: string
  val: i64
  is_str: i64
  sval: string
  type_name: string
@end

@struct ReplEvalOutput
  output: string
  is_error: i64
  is_incomplete: i64
  quit: i64
@end

@! ----------------------------------------------------------------------------
@! 2. REPL INITIALIZATION & STATE MANAGEMENT
@! ----------------------------------------------------------------------------

@! Initializes a new sovereign REPL state
@fn repl_init()
  engine = jit_engine_new()
  return {
    engine: engine,
    history: [],
    multiline_buf: "",
    running: 1,
    prompt: "maya > ",
    prompt_cont: "... ",
    vars: []
  }
@end

@! Sets or updates a variable in the REPL environment
@fn repl_state_set_var(state, name, val, is_str, sval, type_name)
  new_vars = []
  updated = 0
  i = 0
  num_items = state.vars.len()
  @while i < num_items
    v = state.vars[i]
    @if v.name == name
      new_vars = new_vars.push({
        name: name,
        val: val,
        is_str: is_str,
        sval: sval,
        type_name: type_name
      })
      updated = 1
    @else
      new_vars = new_vars.push(v)
    @end
    i = i + 1
  @end

  @if updated == 0
    new_vars = new_vars.push({
      name: name,
      val: val,
      is_str: is_str,
      sval: sval,
      type_name: type_name
    })
  @end

  state.vars = new_vars
  jit_env_set_var(state.engine, name, val, is_str, sval)
  return state
@end

@! ----------------------------------------------------------------------------
@! 3. MULTILINE INCOMPLETENESS DETECTION
@! ----------------------------------------------------------------------------

@! Checks if a string buffer is incomplete and requires continuation lines
@fn repl_is_incomplete(buffer)
  s = str_trim(buffer)
  num_items = s.len()
  @if num_items == 0
    return 0
  @end

  paren_depth = 0
  bracket_depth = 0
  brace_depth = 0
  in_quote = 0
  in_directive_block = 0
  open_blocks = 0

  i = 0
  @while i < num_items
    c = str_char_at(s, i)

    @if c == 34 @! '"'
      @if in_quote == 0
        in_quote = 1
      @elif i > 0 && str_char_at(s, i - 1) != 92 @! not '\"'
        in_quote = 0
      @end
    @elif in_quote == 0
      @if c == 40 @! '('
        paren_depth = paren_depth + 1
      @elif c == 41 @! ')'
        @if paren_depth > 0
          paren_depth = paren_depth - 1
        @end
      @elif c == 91 @! '['
        bracket_depth = bracket_depth + 1
      @elif c == 93 @! ']'
        @if bracket_depth > 0
          bracket_depth = bracket_depth - 1
        @end
      @elif c == 123 @! '{'
        brace_depth = brace_depth + 1
      @elif c == 125 @! '}'
        @if brace_depth > 0
          brace_depth = brace_depth - 1
        @end
      @end

      @! Check for block start: @fn, @if, @while, @for, @struct, fn
      @if i + 3 <= num_items && (str_substr(s, i, 3) == "@fn" || str_substr(s, i, 3) == "@if")
        open_blocks = open_blocks + 1
        i = i + 2
      @elif i + 6 <= num_items && (str_substr(s, i, 6) == "@while" || str_substr(s, i, 6) == "@struct")
        open_blocks = open_blocks + 1
        i = i + 5
      @elif i + 4 <= num_items && str_substr(s, i, 4) == "@for"
        open_blocks = open_blocks + 1
        i = i + 3
      @elif i + 4 <= num_items && str_substr(s, i, 4) == "@end"
        @if open_blocks > 0
          open_blocks = open_blocks - 1
        @end
        i = i + 3
      @end
    @end
    i = i + 1
  @end

  @if in_quote == 1
    return 1
  @end
  @if paren_depth > 0 || bracket_depth > 0 || brace_depth > 0
    return 1
  @end
  @if open_blocks > 0
    return 1
  @end

  @! Check trailing operators that demand continuation
  last_c = str_char_at(s, num_items - 1)
  @if last_c == 43 || last_c == 45 || last_c == 42 || last_c == 47 || last_c == 44 || last_c == 61 || last_c == 124 || last_c == 38
    @! '+', '-', '*', '/', ',', '=', '|', '&'
    return 1
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. METACOMMAND DISPATCHER (:help, :vars, :clear, :type, :quit, :disasm, :env)
@! ----------------------------------------------------------------------------

@! Evaluates REPL metacommands starting with ':' or '.'
@fn repl_handle_metacommand(state, line)
  trimmed = str_trim(line)

  @if trimmed == ":quit" || trimmed == ":exit" || trimmed == ".exit" || trimmed == ":q" || trimmed == "exit" || trimmed == "quit"
    state.running = 0
    return {
      output: "Goodbye.",
      is_error: 0,
      is_incomplete: 0,
      quit: 1
    }
  @end

  @if trimmed == ":help" || trimmed == ".help" || trimmed == "help" || trimmed == ":h" || trimmed == "?"
    help_text = "Maya Sovereign Interactive REPL (JIT Engine)\n"
    help_text = help_text + "=============================================\n"
    help_text = help_text + "Metacommands:\n"
    help_text = help_text + "  :help, :h, ?         Show this command overview\n"
    help_text = help_text + "  :vars                List all persistent variable bindings\n"
    help_text = help_text + "  :type <expr>, :t     Show the deduced type of an expression\n"
    help_text = help_text + "  :disasm <fn>         Disassemble machine code bytes for JIT function\n"
    help_text = help_text + "  :env                 Show JIT engine memory usage & symbol table\n"
    help_text = help_text + "  :clear, :c           Clear the terminal screen and input buffer\n"
    help_text = help_text + "  :quit, :q, exit      Exit the interactive REPL session\n\n"
    help_text = help_text + "Features:\n"
    help_text = help_text + "  - Instant in-memory mathematical expression evaluation with zero disk I/O\n"
    help_text = help_text + "  - Multiline continuation (... prompt) for @fn, @if, loops, and brackets\n"
    help_text = help_text + "  - Persistent variable bindings (e.g. x = 42, let name = \"Alice\")\n"
    help_text = help_text + "  - Incremental function compilation (e.g. @fn add(a, b) return a + b @end)"
    return {
      output: help_text,
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @end

  @if trimmed == ":vars" || trimmed == ".vars"
    @if state.vars.len() == 0
      return {
        output: "No variables currently defined.",
        is_error: 0,
        is_incomplete: 0,
        quit: 0
      }
    @end

    var_list = "Active Variables (" + state.vars.len().to_str() + "):\n"
    i = 0
    num_items = state.vars.len()
    @while i < num_items
      v = state.vars[i]
      @if v.is_str == 1
        var_list = var_list + "  " + v.name + ": string = \"" + v.sval + "\"\n"
      @else
        var_list = var_list + "  " + v.name + ": " + v.type_name + " = " + v.val.to_str() + "\n"
      @end
      i = i + 1
    @end
    return {
      output: str_trim(var_list),
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @end

  @if trimmed == ":clear" || trimmed == ".clear" || trimmed == ":c"
    state.multiline_buf = ""
    return {
      output: "",
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @end

  @if trimmed == ":env"
    blk_cnt = state.engine.memory_blocks.len()
    sym_cnt = state.engine.symbol_table.len()
    fn_cnt = state.engine.fn_sources.len()
    var_cnt = state.vars.len()
    total_mem = blk_cnt * 4096

    env_info = "Maya JIT Engine Statistics:\n"
    env_info = env_info + "  Memory Pages Allocated : " + blk_cnt.to_str() + " (" + total_mem.to_str() + " bytes)\n"
    env_info = env_info + "  Registered Symbols     : " + sym_cnt.to_str() + "\n"
    env_info = env_info + "  Persistent Functions   : " + fn_cnt.to_str() + "\n"
    env_info = env_info + "  Active Variables       : " + var_cnt.to_str()

    @if sym_cnt > 0
      env_info = env_info + "\n\nSymbol Table:\n"
      s_i = 0
      @while s_i < sym_cnt
        s_entry = state.engine.symbol_table[s_i]
        env_info = env_info + "  " + s_entry.sym_name + " -> 0x" + s_entry.fn_addr.to_str() + " (" + s_entry.code_size.to_str() + " bytes)\n"
        s_i = s_i + 1
      @end
    @end

    return {
      output: str_trim(env_info),
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @end

  @if str_starts_with(trimmed, ":type ") || str_starts_with(trimmed, ":t ")
    expr_to_check = ""
    @if str_starts_with(trimmed, ":type ")
      expr_to_check = string_trim(string_slice(trimmed, 6, str_len(trimmed)))
    @else
      expr_to_check = string_trim(string_slice(trimmed, 3, str_len(trimmed)))
    @end

    @! Simple type inspector
    @if expr_to_check == "true" || expr_to_check == "false"
      return { output: expr_to_check + " : bool", is_error: 0, is_incomplete: 0, quit: 0 }
    @elif str_starts_with(expr_to_check, "\"") && str_ends_with(expr_to_check, "\"")
      return { output: expr_to_check + " : string", is_error: 0, is_incomplete: 0, quit: 0 }
    @elif str_starts_with(expr_to_check, "[") && str_ends_with(expr_to_check, "]")
      return { output: expr_to_check + " : array", is_error: 0, is_incomplete: 0, quit: 0 }
    @else
      @! Evaluate expression to deduce type
      eval_res = jit_eval_expression(state.engine, expr_to_check)
      @if eval_res.success == 1
        return {
          output: expr_to_check + " : " + eval_res.val_type + " = " + int_to_str(eval_res.value),
          is_error: 0,
          is_incomplete: 0,
          quit: 0
        }
      @else
        return {
          output: "Type Error: Unable to deduce type of '" + expr_to_check + "' (" + eval_res.error_msg + ")",
          is_error: 1,
          is_incomplete: 0,
          quit: 0
        }
      @end
    @end
  @end

  @if str_starts_with(trimmed, ":disasm ")
    target_fn = string_trim(string_slice(trimmed, 8, str_len(trimmed)))
    entry = jit_lookup_symbol_entry(state.engine, target_fn)
    @if entry == 0 || entry.fn_addr == 0
      return {
        output: "Disasm Error: Function '" + target_fn + "' not found in JIT symbol table.",
        is_error: 1,
        is_incomplete: 0,
        quit: 0
      }
    @end

    dis_out = "Disassembly for " + target_fn + " at 0x" + int_to_str(entry.fn_addr) + " (" + int_to_str(entry.code_size) + " bytes):\n"
    block = state.engine.memory_blocks[entry.block_idx]
    d_i = 0
    @while d_i < entry.code_size && d_i < 64
      b = jit_mem_read_byte(block, d_i)
      hex_str = int_to_str(b)
      @if str_len(hex_str) < 2
        hex_str = "0" + hex_str
      @end
      dis_out = dis_out + hex_str + " "
      @if (d_i + 1) % 16 == 0
        dis_out = dis_out + "\n"
      @end
      d_i = d_i + 1
    @end

    return {
      output: string_trim(dis_out),
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @end

  return {
    output: "Unknown command: '" + trimmed + "'. Type :help for command list.",
    is_error: 1,
    is_incomplete: 0,
    quit: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 5. LINE EVALUATION & EXECUTION ENGINE
@! ----------------------------------------------------------------------------

@! Evaluates a single input line or accumulates multiline buffers
@fn repl_eval_line(state, line)
  raw_line = line
  trimmed = string_trim(raw_line)

  @! Check for empty line
  @if str_len(trimmed) == 0 && str_len(state.multiline_buf) == 0
    return {
      output: "",
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @end

  @! Check for metacommands (only if not currently buffering multiline)
  @if str_len(state.multiline_buf) == 0 && (str_starts_with(trimmed, ":") || str_starts_with(trimmed, ".") || trimmed == "exit" || trimmed == "quit" || trimmed == "help")
    return repl_handle_metacommand(state, trimmed)
  @end

  @! Accumulate into multiline buffer
  @if str_len(state.multiline_buf) == 0
    state.multiline_buf = raw_line
  @else
    state.multiline_buf = state.multiline_buf + "\n" + raw_line
  @end

  @! Check if input is incomplete
  @if repl_is_incomplete(state.multiline_buf) == 1
    return {
      output: "",
      is_error: 0,
      is_incomplete: 1,
      quit: 0
    }
  @end

  full_input = string_trim(state.multiline_buf)
  state.multiline_buf = ""
  state.history = state.history.push(full_input)

  @! --------------------------------------------------------------------------
  @! 1. Function Definition: `@fn ... @end` or `fn ... end`
  @! --------------------------------------------------------------------------
  @if str_starts_with(full_input, "@fn ") || str_starts_with(full_input, "fn ")
    @! Extract function name
    fn_name = ""
    f_p = 4
    @if str_starts_with(full_input, "fn ")
      f_p = 3
    @end
    fi_len = str_len(full_input)
    @while f_p < fi_len && str_char_at(full_input, f_p) == 32
      f_p = f_p + 1
    @end
    n_start = f_p
    @while f_p < fi_len && str_char_at(full_input, f_p) != 40 && str_char_at(full_input, f_p) != 32
      f_p = f_p + 1
    @end
    fn_name = str_trim(string_slice(full_input, n_start, f_p))
    @if fn_name == ""
      return {
        output: "Syntax Error: Expected function identifier after '@fn'",
        is_error: 1,
        is_incomplete: 0,
        quit: 0
      }
    @end

    comp_res = jit_compile_function(state.engine, fn_name, full_input)
    @if comp_res.success == 1
      return {
        output: "Defined function: " + fn_name + " (compiled to RAM @ 0x" + int_to_str(comp_res.entry_addr) + ")",
        is_error: 0,
        is_incomplete: 0,
        quit: 0
      }
    @else
      return {
        output: "Function Compilation Error: " + comp_res.error_msg,
        is_error: 1,
        is_incomplete: 0,
        quit: 0
      }
    @end
  @end

  @! --------------------------------------------------------------------------
  @! 2. Variable Assignment: `var = expr` or `let var = expr`
  @! --------------------------------------------------------------------------
  is_let = 0
  stmt = full_input
  @if str_starts_with(stmt, "let ")
    stmt = string_trim(string_slice(stmt, 4, str_len(stmt)))
    is_let = 1
  @end

  eq_idx = str_index_of(stmt, "=")
  @if eq_idx > 0 && str_char_at(stmt, eq_idx - 1) != 33 && str_char_at(stmt, eq_idx - 1) != 60 && str_char_at(stmt, eq_idx - 1) != 62 && str_char_at(stmt, eq_idx - 1) != 61 && str_char_at(stmt, eq_idx + 1) != 61
    var_name = string_trim(string_slice(stmt, 0, eq_idx))
    val_expr = string_trim(string_slice(stmt, eq_idx + 1, str_len(stmt)))

    @! Check if string literal assignment
    @if str_starts_with(val_expr, "\"") && str_ends_with(val_expr, "\"") && str_len(val_expr) >= 2
      s_val = string_slice(val_expr, 1, str_len(val_expr) - 1)
      repl_state_set_var(state, var_name, 0, 1, s_val, "string")
      return {
        output: var_name + " = \"" + s_val + "\"",
        is_error: 0,
        is_incomplete: 0,
        quit: 0
      }
    @else
      @! Evaluate numerical/computed expression via JIT
      eval_res = jit_eval_expression(state.engine, val_expr)
      @if eval_res.success == 1
        repl_state_set_var(state, var_name, eval_res.value, 0, "", "i64")
        return {
          output: var_name + " = " + int_to_str(eval_res.value),
          is_error: 0,
          is_incomplete: 0,
          quit: 0
        }
      @else
        return {
          output: "Evaluation Error in assignment to '" + var_name + "': " + eval_res.error_msg,
          is_error: 1,
          is_incomplete: 0,
          quit: 0
        }
      @end
    @end
  @end

  @! --------------------------------------------------------------------------
  @! 3. Pure Expression Evaluation: `expr`
  @! --------------------------------------------------------------------------
  eval_res = jit_eval_expression(state.engine, full_input)
  @if eval_res.success == 1
    return {
      output: int_to_str(eval_res.value),
      is_error: 0,
      is_incomplete: 0,
      quit: 0
    }
  @else
    return {
      output: "Error: " + eval_res.error_msg,
      is_error: 1,
      is_incomplete: 0,
      quit: 0
    }
  @end
@end

@! ----------------------------------------------------------------------------
@! 6. INTERACTIVE REPL LOOP RUNNER
@! ----------------------------------------------------------------------------

@! Runs the interactive sovereign Maya REPL loop on standard input/output
@fn repl_run(state)
  println("=================================================================")
  println("  Maya Interactive REPL & JIT Engine v2.0")
  println("  Type :help for commands, :quit to exit.")
  println("=================================================================")

  @while state.running == 1
    @if state.multiline_buf.len() == 0
      print(state.prompt)
    @else
      print(state.prompt_cont)
    @end

    line = read_line(4096)
    @if line == 0 || (line.len() == 0 && state.multiline_buf.len() == 0)
      @! EOF reached
      println("\nExiting Maya REPL.")
      break
    @end

    res = repl_eval_line(state, line)

    @if res.quit == 1
      println(res.output)
      break
    @end

    @if res.is_incomplete == 0 && res.output.len() > 0
      println(res.output)
    @end
  @end

  jit_engine_free(state.engine)
  return 0
@end
