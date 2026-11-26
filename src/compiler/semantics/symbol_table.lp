// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: FAST SYMBOL TABLE & NAMESPACE RESOLVER (symbol_table.lp)
// Module: src/compiler/semantics/symbol_table.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// In large software systems (such as the LiPi Sovereign Universe with thousands of
// functions and structs), linear symbol search causes O(N) degradation during semantic
// analysis. This module provides:
// 1. Fast Bucket Hashing: A DJB2 64-bit hashing table yielding O(1) expected symbol
//    retrieval time.
// 2. Sovereign Prefixed Fields: `tab_`, `ns_`, and `na_` prefixes guarantee zero
//    struct offset collisions with AST or compiler internals.
// 3. Hierarchical Namespace Resolution: Resolves nested paths such as
//    `universe::core::collections` or `std.math.pi`, including import aliasing.
// 4. Collision Resistance: Bucket chaining guarantees deterministic correctness.
// ==============================================================================

import "utso/collections"
import "utso/string"
import "compiler/semantics/symbol"

// ── 1. FAST HASHING ALGORITHM (DJB2 VARIANT) ─────────────────────────────────

@fn symtab_hash(key, capacity)
  // WHY: DJB2 hash algorithm delivers exceptional avalanche distribution
  @if capacity <= 0 return 0 @end

  h = 5381
  k_len = str_len(key)
  i = 0
  @while i < k_len
    c = str_char_at(key, i)
    h = ((h * 33) + c)
    @if h < 0
      h = 0 - h
    @end
    h = h % 2147483647
    i = i + 1
  @end

  idx = h % capacity
  @if idx < 0
    idx = 0 - idx
  @end
  return idx
@end

// ── 2. FAST HASH-BASED SYMBOL TABLE ──────────────────────────────────────────

@struct FastSymbolTable
  tab_capacity: i64
  tab_count: i64
  tab_buckets: array
  tab_all_symbols: array
  tab_map: i64
  tab_idx_map: i64
  tab_writes: i64
@end

@fn symtab_new(capacity)
  // WHY: Allocates FastSymbolTable backed by native O(1) Silicon DICT0 hashmap
  // while preserving tab_all_symbols and tab_count for deterministic iteration.
  cap = capacity
  @if cap <= 0 cap = 64 @end

  tab = FastSymbolTable()
  tab.tab_capacity = cap
  tab.tab_count = 0
  tab.tab_buckets = []
  tab.tab_all_symbols = []
  tab.tab_map = dict()
  tab.tab_idx_map = dict()
  tab.tab_writes = 0
  return tab
@end

@fn symtab_put(tab, sym)
  // WHY: O(1) insert/update into native hashmap; keeps tab_all_symbols synchronized in O(1)
  @if tab == 0 || sym == 0 return 0 @end
  tab.tab_writes = tab.tab_writes + 1

  @if has_key(tab.tab_map, sym.sym_name) == 1
    tab.tab_map[sym.sym_name] = sym
    @if tab.tab_idx_map != 0 && has_key(tab.tab_idx_map, sym.sym_name) == 1
      e_idx = tab.tab_idx_map[sym.sym_name]
      @if e_idx >= 0 && e_idx < tab.tab_all_symbols.len()
        tab.tab_all_symbols[e_idx] = sym
        return 1
      @end
    @end
    return 1
  @end

  tab.tab_map[sym.sym_name] = sym
  @if tab.tab_idx_map != 0
    tab.tab_idx_map[sym.sym_name] = tab.tab_all_symbols.len()
  @end
  tab.tab_all_symbols = tab.tab_all_symbols.push(sym)
  tab.tab_count = tab.tab_count + 1
  return 1
@end

@fn symtab_get(tab, name)
  // WHY: O(1) expected symbol retrieval via native DICT0 lookup
  @if tab == 0 || tab.tab_count == 0 return 0 @end
  @if has_key(tab.tab_map, name) == 1
    return tab.tab_map[name]
  @end
  return 0
@end

@fn symtab_has(tab, name)
  @if tab == 0 || tab.tab_count == 0 return 0 @end
  return has_key(tab.tab_map, name)
@end

@fn symtab_remove(tab, name)
  @if tab == 0 || tab.tab_count == 0 return 0 @end
  @if has_key(tab.tab_map, name) == 0 return 0 @end

  del_key(tab.tab_map, name)
  new_all = []
  new_idx = dict()
  j = 0
  m = tab.tab_all_symbols.len()
  @while j < m
    @if str_eq(tab.tab_all_symbols[j].sym_name, name) == 0
      new_idx[tab.tab_all_symbols[j].sym_name] = new_all.len()
      new_all = new_all.push(tab.tab_all_symbols[j])
    @end
    j = j + 1
  @end
  tab.tab_all_symbols = new_all
  tab.tab_idx_map = new_idx
  tab.tab_writes = tab.tab_writes + 1
  tab.tab_count = tab.tab_count - 1
  return 1
@end

@fn symtab_size(tab)
  @if tab == 0 return 0 @end
  return tab.tab_count
@end

@fn symtab_all(tab)
  @if tab == 0 return [] @end
  return tab.tab_all_symbols
@end

// ── 3. HIERARCHICAL NAMESPACE RESOLVER ────────────────────────────────────────

@struct NamespaceAlias
  na_alias_name: string
  na_target_path: string
@end

@struct Namespace
  ns_name: string
  ns_full_path: string
  ns_table: FastSymbolTable
  ns_children: array
  ns_aliases: array
@end

@fn namespace_new(name, full_path)
  // WHY: Instantiates a modular namespace node with its own isolated symbol table
  tab = symtab_new(64)
  ns = Namespace()
  ns.ns_name = name
  ns.ns_full_path = full_path
  ns.ns_table = tab
  ns.ns_children = []
  ns.ns_aliases = []
  return ns
@end

@fn namespace_add_child(parent_ns, child_name)
  @if parent_ns == 0 return 0 @end

  i = 0
  n = parent_ns.ns_children.len()
  @while i < n
    child = parent_ns.ns_children[i]
    @if str_eq(child.ns_name, child_name) == 1
      return child
    @end
    i = i + 1
  @end

  child_path = child_name
  @if parent_ns.ns_full_path != ""
    child_path = parent_ns.ns_full_path + "::" + child_name
  @end

  new_child = namespace_new(child_name, child_path)
  parent_ns.ns_children = parent_ns.ns_children.push(new_child)
  return new_child
@end

@fn namespace_find_child(parent_ns, child_name)
  @if parent_ns == 0 return 0 @end

  i = 0
  n = parent_ns.ns_children.len()
  @while i < n
    child = parent_ns.ns_children[i]
    @if str_eq(child.ns_name, child_name) == 1
      return child
    @end
    i = i + 1
  @end

  return 0
@end

@fn namespace_add_symbol(ns, sym)
  @if ns == 0 || sym == 0 return 0 @end
  return symtab_put(ns.ns_table, sym)
@end

@fn namespace_get_symbol(ns, name)
  @if ns == 0 return 0 @end
  return symtab_get(ns.ns_table, name)
@end

@fn namespace_register_alias(ns, alias_name, target_path)
  @if ns == 0 return 0 @end
  entry = NamespaceAlias()
  entry.na_alias_name = alias_name
  entry.na_target_path = target_path
  ns.ns_aliases = ns.ns_aliases.push(entry)
  return 1
@end

@fn namespace_resolve_alias(ns, alias_name)
  @if ns == 0 return "" @end
  i = 0
  n = ns.ns_aliases.len()
  @while i < n
    a = ns.ns_aliases[i]
    @if str_eq(a.na_alias_name, alias_name) == 1
      return a.na_target_path
    @end
    i = i + 1
  @end
  return ""
@end

// ── 4. QUALIFIED PATH RESOLUTION ENGINE ───────────────────────────────────────

@fn namespace_split_path(path_str)
  // WHY: Splits qualified path on "::" or "." into an array of path segments
  segments = []
  curr = ""
  p_len = str_len(path_str)
  i = 0

  @while i < p_len
    c = str_char_at(path_str, i)
    @if c == 58 && i + 1 < p_len && str_char_at(path_str, i + 1) == 58
      @if curr != ""
        segments = segments.push(curr)
        curr = ""
      @end
      i = i + 2
    @elif c == 46
      @if curr != ""
        segments = segments.push(curr)
        curr = ""
      @end
      i = i + 1
    @else
      curr = curr + str_from_char_code(c)
      i = i + 1
    @end
  @end

  @if curr != ""
    segments = segments.push(curr)
  @end

  return segments
@end

@fn namespace_resolve(root_ns, qualified_path)
  // WHY: Canonical multi-segment path resolution engine
  @if root_ns == 0 || qualified_path == "" return 0 @end

  segments = namespace_split_path(qualified_path)
  @if segments.len() == 0 return 0 @end

  @if segments.len() == 1
    return namespace_get_symbol(root_ns, segments[0])
  @end

  first_seg = segments[0]
  expanded_alias = namespace_resolve_alias(root_ns, first_seg)
  @if expanded_alias != ""
    rem = ""
    k = 1
    @while k < segments.len()
      @if rem != ""
        rem = rem + "::"
      @end
      rem = rem + segments[k]
      k = k + 1
    @end
    return namespace_resolve(root_ns, expanded_alias + "::" + rem)
  @end

  curr_ns = root_ns
  i = 0
  last_idx = segments.len() - 1

  @while i < last_idx
    seg = segments[i]
    next_ns = namespace_find_child(curr_ns, seg)
    @if next_ns == 0 return 0 @end
    curr_ns = next_ns
    i = i + 1
  @end

  leaf_symbol_name = segments[last_idx]
  return namespace_get_symbol(curr_ns, leaf_symbol_name)
@end
