// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: LEXICAL SCOPE STACK (scope.lp)
// Module: src/compiler/semantics/scope.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Lexical scoping governs the visibility, lifetime, and resolution of identifiers
// across nested program blocks. In LiPi First 1.0.0, variables declared in an inner
// block shadow outer declarations without destroying them, while functions and
// modules establish rigid visibility boundaries.
//
// DESIGN PRINCIPLES:
// 1. Zero-Collision Prefixed Fields: (`sc_name`, `sc_kind`, `stk_scopes`, etc.)
//    eliminate cross-module field index ambiguity in the self-hosting compiler.
// 2. Persistent Lexical Tree: Retains all scopes in an arena list indexed by integer
//    ID for downstream DWARF debugging, LSP definition jumps, and closure binding.
// 3. Parent-Pointer Climbing: Standard O(D) lexical resolution from innermost block
//    up to Global root.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/semantics/symbol"

// ── 1. SCOPE KIND CONSTANTS ──────────────────────────────────────────────────

@fn SCOPE_GLOBAL()   return 0 @end
@fn SCOPE_MODULE()   return 1 @end
@fn SCOPE_FUNCTION() return 2 @end
@fn SCOPE_BLOCK()    return 3 @end

// ── 2. LEXICAL SCOPE DEFINITION ──────────────────────────────────────────────

@struct Scope
  sc_name: string
  sc_kind: i64
  sc_id: i64
  sc_parent_id: i64
  sc_depth: i64
  sc_symbols: array
  sc_symbol_names: array
  sc_child_ids: array
  sc_ret_type: i64
  sc_is_loop: i64
@end

@fn scope_new(id, kind, parent_id, depth, name)
  // WHY: Allocates a clean lexical environment node with named constructor
  sc = Scope()
  sc.sc_name = name
  sc.sc_kind = kind
  sc.sc_id = id
  sc.sc_parent_id = parent_id
  sc.sc_depth = depth
  sc.sc_symbols = []
  sc.sc_symbol_names = []
  sc.sc_child_ids = []
  sc.sc_ret_type = 0
  sc.sc_is_loop = 0
  return sc
@end

// ── 3. PERSISTENT SCOPE STACK (ARENA STORAGE) ────────────────────────────────

@struct ScopeStack
  stk_scopes: array
  stk_current_id: i64
  stk_next_id: i64
  stk_chain: array
@end

@fn scope_stack_new()
  // WHY: Initializes compiler environment with root Global Scope (id = 0)
  global_scope = scope_new(0, SCOPE_GLOBAL(), -1, 0, "global")
  scopes = []
  scopes = scopes.push(global_scope)
  chain = []
  chain = chain.push(0)

  stack = ScopeStack()
  stack.stk_scopes = scopes
  stack.stk_current_id = 0
  stack.stk_next_id = 1
  stack.stk_chain = chain
  return stack
@end

@fn scope_stack_current(stack)
  // WHY: O(1) retrieval of active lexical scope
  @if stack == 0 || stack.stk_current_id < 0 || stack.stk_current_id >= stack.stk_scopes.len()
    return 0
  @end
  return stack.stk_scopes[stack.stk_current_id]
@end

@fn scope_stack_get(stack, scope_id)
  // WHY: Direct lookup of any historical scope in the persistent tree
  @if stack == 0 || scope_id < 0 || scope_id >= stack.stk_scopes.len()
    return 0
  @end
  return stack.stk_scopes[scope_id]
@end

@fn scope_stack_push(stack, kind, name)
  // WHY: Entering a nested lexical boundary (e.g. entering a function or loop body)
  parent_id = stack.stk_current_id
  parent_scope = stack.stk_scopes[parent_id]
  new_depth = parent_scope.sc_depth + 1
  new_id = stack.stk_next_id
  stack.stk_next_id = stack.stk_next_id + 1

  child_scope = scope_new(new_id, kind, parent_id, new_depth, name)

  // Inherit loop boundary status if parent is inside loop
  @if parent_scope.sc_is_loop == 1
    child_scope.sc_is_loop = 1
  @end

  // Register in parent's child list
  parent_scope.sc_child_ids = parent_scope.sc_child_ids.push(new_id)

  // Append to global scope arena
  stack.stk_scopes = stack.stk_scopes.push(child_scope)

  // Update active tracking
  stack.stk_chain = stack.stk_chain.push(new_id)
  stack.stk_current_id = new_id

  return child_scope
@end

@fn scope_stack_pop(stack)
  // WHY: Exiting a lexical block. Restores parent scope without deleting child data
  @if stack.stk_chain.len() <= 1
    return stack.stk_current_id
  @end

  exited_id = stack.stk_current_id
  current_scope = stack.stk_scopes[exited_id]
  new_current_id = current_scope.sc_parent_id

  // Pop from active chain
  new_chain = []
  i = 0
  chain_len = stack.stk_chain.len() - 1
  @while i < chain_len
    new_chain = new_chain.push(stack.stk_chain[i])
    i = i + 1
  @end
  stack.stk_chain = new_chain
  stack.stk_current_id = new_current_id

  return exited_id
@end

// ── 4. SYMBOL REGISTRATION & LOOKUP ──────────────────────────────────────────

@fn scope_define(stack, sym)
  // WHY: Registers a symbol in the current lexical scope
  curr = scope_stack_current(stack)
  @if curr == 0 || sym == 0
    return 0
  @end

  // Check if symbol already exists in THIS specific scope
  i = 0
  num_symbols = curr.sc_symbol_names.len()
  @while i < num_symbols
    @if str_eq(curr.sc_symbol_names[i], sym.sym_name) == 1
      return 0
    @end
    i = i + 1
  @end

  sym.sym_scope_id = curr.sc_id
  curr.sc_symbols = curr.sc_symbols.push(sym)
  curr.sc_symbol_names = curr.sc_symbol_names.push(sym.sym_name)
  return 1
@end

@fn scope_lookup_current(stack, name)
  // WHY: Checks ONLY the current scope without walking parent pointers
  curr = scope_stack_current(stack)
  @if curr == 0
    return 0
  @end

  i = 0
  num_symbols = curr.sc_symbols.len()
  @while i < num_symbols
    s = curr.sc_symbols[i]
    @if str_eq(s.sym_name, name) == 1
      return s
    @end
    i = i + 1
  @end

  return 0
@end

@fn scope_lookup(stack, name)
  // WHY: Canonical Lexical Scope Resolution Algorithm
  // Traverses upwards from current scope through parent pointers to Global root
  curr_id = stack.stk_current_id
  @while curr_id >= 0
    sc = stack.stk_scopes[curr_id]
    i = 0
    n = sc.sc_symbols.len()
    @while i < n
      s = sc.sc_symbols[i]
      @if str_eq(s.sym_name, name) == 1
        return s
      @end
      i = i + 1
    @end
    curr_id = sc.sc_parent_id
  @end

  return 0
@end

@fn scope_lookup_in_scope(stack, start_scope_id, name)
  // WHY: Arbitrary scope traversal starting from given scope_id
  curr_id = start_scope_id
  @while curr_id >= 0 && curr_id < stack.stk_scopes.len()
    sc = stack.stk_scopes[curr_id]
    i = 0
    n = sc.sc_symbols.len()
    @while i < n
      s = sc.sc_symbols[i]
      @if str_eq(s.sym_name, name) == 1
        return s
      @end
      i = i + 1
    @end
    curr_id = sc.sc_parent_id
  @end

  return 0
@end

// ── 5. ENCLOSING CONTEXT QUERIES ─────────────────────────────────────────────

@fn scope_get_enclosing_function(stack)
  // WHY: Climbs active chain to find the containing function declaration
  chain_idx = stack.stk_chain.len() - 1
  @while chain_idx >= 0
    sid = stack.stk_chain[chain_idx]
    sc = stack.stk_scopes[sid]
    @if sc.sc_kind == SCOPE_FUNCTION()
      return sc
    @end
    chain_idx = chain_idx - 1
  @end

  return 0
@end

@fn scope_is_inside_loop(stack)
  // WHY: Validates whether `break` or `continue` statements are legally positioned
  curr = scope_stack_current(stack)
  @if curr == 0 return 0 @end
  return curr.sc_is_loop
@end

@fn scope_set_loop(stack, is_loop)
  // WHY: Marks current block as a loop boundary
  curr = scope_stack_current(stack)
  @if curr != 0
    curr.sc_is_loop = is_loop
  @end
  return 0
@end

@fn scope_get_depth(stack)
  // WHY: Returns nesting level of current lexical scope
  curr = scope_stack_current(stack)
  @if curr == 0 return 0 @end
  return curr.sc_depth
@end

@fn scope_kind_to_string(kind)
  // WHY: Diagnostic formatting
  @if kind == SCOPE_GLOBAL()   return "Global"   @end
  @if kind == SCOPE_MODULE()   return "Module"   @end
  @if kind == SCOPE_FUNCTION() return "Function" @end
  @if kind == SCOPE_BLOCK()    return "Block"    @end
  return "Unknown"
@end
