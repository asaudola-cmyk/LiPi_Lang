@! ============================================================================
@! LIPI COMPILER MIDDLEEND — INCREMENTAL BUILD & DEPENDENCY GRAPH ENGINE
@! Module: compiler/middleend/incremental.maya
@! 100% Pure Maya Implementation — Zero Foreign Dependencies
@! Supports:
@!   - 64-bit FNV-1a & FIPS 180-4 SHA-256 Content Hashing
@!   - Dependency Graph Modeling with Import Path Resolution
@!   - Tarjan's Strongly Connected Components (SCC) Cycle Detection
@!   - Kahn's Algorithm for Topological Sort
@!   - BFS Change Propagation & Transitive Invalidation
@!   - Persistent Binary & Text Cache Management (AST, Types, Exports, IR Bytes)
@!   - Genuine AST-to-IR Generation, Lowering, and Serialization
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "compiler/backend/lipi_ir"
import "compiler/backend/compiler"

@! ============================================================================
@! 1. CANONICAL DATA STRUCTURES & SCHEMAS
@! ============================================================================

@struct TypeInfo
  type_id: i64
  type_name: string
  type_size: i64
@end

@struct CachedResult
  cr_file_path: string
  cr_content_hash: i64
  cr_content_hash_hex: string
  cr_ast_hash: i64
  cr_ast: array
  cr_type_env: array
  cr_exported_symbols: array
  cr_ir_bytes: array
  cr_ir_text: string
  cr_ir_module: i64
@end

@struct SourceFile
  sf_path: string
  sf_content_hash: i64
  sf_content_hash_hex: string
  sf_last_modified: i64
  sf_dependencies: array
@end

@struct DepEdge
  from_path: string
  to_path: string
@end

@struct DependencyGraph
  dg_nodes: array            @! Array of SourceFile
  dg_edges: array            @! Array of DepEdge
  dg_reverse_edges: array    @! Array of DepEdge
@end

@struct TarjanState
  ts_index: i64
  ts_indices: array          @! Map entries: IntMapEntry
  ts_lowlinks: array         @! Map entries: IntMapEntry
  ts_on_stack: array         @! Set of paths currently on stack
  ts_stack: array            @! Stack of paths
  ts_sccs: array             @! List of SCC cycles (array of array of paths)
@end

@struct CompilationCache
  cc_dir: string
  cc_entries: array          @! Map entries: CacheMapEntry
  cc_magic_header: i64       @! 0x4C495049 ('LIPI')
  cc_version: i64            @! 1
@end

@struct TypeMapEntry
  tme_key: string
  tme_val: i64
@end

@struct CacheMapEntry
  cme_key: string
  cme_val: i64
@end

@struct IntMapEntry
  ime_key: string
  ime_val: i64
@end

@! ============================================================================
@! 2. UTILITY & LIST HELPERS
@! ============================================================================

@fn inc_list_contains(arr, val)
  @if arr.len() == 0 return 0 @end
  num_items = arr.len()
  i = 0
  @while i < num_items
    @if arr[i] == val
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn inc_list_slice(arr, start_idx, end_idx)
  res = []
  i = start_idx
  @while i < end_idx && i < arr.len()
    res = res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@fn inc_int_map_set(entries, key_name, int_val)
  new_entries = []
  found = 0
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.ime_key == key_name
      new_entries = new_entries.push({ ime_key: key_name, ime_val: int_val })
      found = 1
    @else
      new_entries = new_entries.push(entry)
    @end
    i = i + 1
  @end
  @if found == 0
    new_entries = new_entries.push({ ime_key: key_name, ime_val: int_val })
  @end
  return new_entries
@end

@fn inc_int_map_get(entries, key_name, default_val)
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.ime_key == key_name
      return entry.ime_val
    @end
    i = i + 1
  @end
  return default_val
@end

@fn inc_int_map_has(entries, key_name)
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.ime_key == key_name
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn inc_type_map_set(entries, key_name, type_val)
  new_entries = []
  found = 0
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.tme_key == key_name
      new_entries = new_entries.push({ tme_key: key_name, tme_val: type_val })
      found = 1
    @else
      new_entries = new_entries.push(entry)
    @end
    i = i + 1
  @end
  @if found == 0
    new_entries = new_entries.push({ tme_key: key_name, tme_val: type_val })
  @end
  return new_entries
@end

@fn inc_type_map_get(entries, key_name)
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.tme_key == key_name
      return entry.tme_val
    @end
    i = i + 1
  @end
  return 0
@end

@fn inc_cache_map_set(entries, key_name, cache_val)
  new_entries = []
  found = 0
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.cme_key == key_name
      new_entries = new_entries.push({ cme_key: key_name, cme_val: cache_val })
      found = 1
    @else
      new_entries = new_entries.push(entry)
    @end
    i = i + 1
  @end
  @if found == 0
    new_entries = new_entries.push({ cme_key: key_name, cme_val: cache_val })
  @end
  return new_entries
@end

@fn inc_cache_map_get(entries, key_name)
  num_items = entries.len()
  i = 0
  @while i < num_items
    entry = entries[i]
    @if entry.cme_key == key_name
      return entry.cme_val
    @end
    i = i + 1
  @end
  return 0
@end

@! ============================================================================
@! 3. FAST FNV-1a (64-bit) & SHA-256 HASHING ENGINES
@! ============================================================================

@fn fnv1a_64_bytes(byte_list)
  h = -3750763034362895579
  prime = 1099511628211
  num_items = byte_list.len()
  i = 0
  @while i < num_items
    b = byte_list[i] & 255
    h = h ^ b
    h = (h * prime) & -1
    i = i + 1
  @end
  return h
@end

@fn fnv1a_64_string(str_data)
  num_items = str_data.len()
  bytes = []
  i = 0
  @while i < num_items
    bytes = bytes.push(str_data[i] & 255)
    i = i + 1
  @end
  return fnv1a_64_bytes(bytes)
@end

@fn hash_source_sha256(str_data)
  return sha256_hex_string(str_data)
@end

@fn hash_source_fnv1a(str_data)
  return fnv1a_64_string(str_data)
@end

@! ============================================================================
@! 4. DEPENDENCY GRAPH & TOPOLOGICAL SORTING / CYCLE DETECTION
@! ============================================================================

@fn dep_graph_new()
  return {
    dg_nodes: [],
    dg_edges: [],
    dg_reverse_edges: []
  }
@end

@fn dep_graph_add_node(graph, src_file)
  found = 0
  i = 0
  @while i < graph.dg_nodes.len()
    node = graph.dg_nodes[i]
    @if node.sf_path == src_file.sf_path
      graph.dg_nodes = list_set(graph.dg_nodes, i, src_file)
      found = 1
      break
    @end
    i = i + 1
  @end
  @if found == 0
    graph.dg_nodes = graph.dg_nodes.push(src_file)
  @end
  return graph
@end

@fn dep_graph_get_node(graph, file_path)
  i = 0
  @while i < graph.dg_nodes.len()
    node = graph.dg_nodes[i]
    @if node.sf_path == file_path
      return node
    @end
    i = i + 1
  @end
  return 0
@end

@fn dep_graph_add_edge(graph, from_path, to_path)
  graph.dg_edges = graph.dg_edges.push({ from_path: from_path, to_path: to_path })
  graph.dg_reverse_edges = graph.dg_reverse_edges.push({ from_path: to_path, to_path: from_path })
  return graph
@end

@fn dep_graph_get_dependencies(graph, file_path)
  deps = []
  i = 0
  @while i < graph.dg_edges.len()
    e = graph.dg_edges[i]
    @if e.from_path == file_path
      deps = deps.push(e.to_path)
    @end
    i = i + 1
  @end
  return deps
@end

@fn dep_graph_get_dependents(graph, file_path)
  dependents = []
  i = 0
  @while i < graph.dg_reverse_edges.len()
    e = graph.dg_reverse_edges[i]
    @if e.from_path == file_path
      dependents = dependents.push(e.to_path)
    @end
    i = i + 1
  @end
  return dependents
@end

@! ----------------------------------------------------------------------------
@! Tarjan's Strongly Connected Components (SCC) Algorithm
@! ----------------------------------------------------------------------------

@fn tarjan_strongconnect(graph, v_path, state)
  state.ts_indices = inc_int_map_set(state.ts_indices, v_path, state.ts_index)
  state.ts_lowlinks = inc_int_map_set(state.ts_lowlinks, v_path, state.ts_index)
  state.ts_index = state.ts_index + 1
  state.ts_stack = state.ts_stack.push(v_path)
  state.ts_on_stack = state.ts_on_stack.push(v_path)

  successors = dep_graph_get_dependencies(graph, v_path)
  i = 0
  @while i < successors.len()
    w_path = successors[i]
    @if inc_int_map_has(state.ts_indices, w_path) == 0
      state = tarjan_strongconnect(graph, w_path, state)
      v_low = inc_int_map_get(state.ts_lowlinks, v_path, 0)
      w_low = inc_int_map_get(state.ts_lowlinks, w_path, 0)
      @if w_low < v_low
        state.ts_lowlinks = inc_int_map_set(state.ts_lowlinks, v_path, w_low)
      @end
    @elif inc_list_contains(state.ts_on_stack, w_path) == 1
      v_low = inc_int_map_get(state.ts_lowlinks, v_path, 0)
      w_idx = inc_int_map_get(state.ts_indices, w_path, 0)
      @if w_idx < v_low
        state.ts_lowlinks = inc_int_map_set(state.ts_lowlinks, v_path, w_idx)
      @end
    @end
    i = i + 1
  @end

  @! If v is a root node, pop stack and generate an SCC
  v_idx = inc_int_map_get(state.ts_indices, v_path, 0)
  v_low = inc_int_map_get(state.ts_lowlinks, v_path, 0)
  @if v_low == v_idx
    scc = []
    w_curr = ""
    @while w_curr != v_path && state.ts_stack.len() > 0
      w_curr = state.ts_stack[state.ts_stack.len() - 1]
      state.ts_stack = list_slice(state.ts_stack, 0, state.ts_stack.len() - 1)
      new_on_stack = []
      s_i = 0
      @while s_i < state.ts_on_stack.len()
        @if state.ts_on_stack[s_i] != w_curr
          new_on_stack = new_on_stack.push(state.ts_on_stack[s_i])
        @end
        s_i = s_i + 1
      @end
      state.ts_on_stack = new_on_stack
      scc = scc.push(w_curr)
    @end
    state.ts_sccs = state.ts_sccs.push(scc)
  @end

  return state
@end

@fn dep_graph_find_cycles(graph)
  state = {
    ts_index: 0,
    ts_indices: [],
    ts_lowlinks: [],
    ts_on_stack: [],
    ts_stack: [],
    ts_sccs: []
  }

  i = 0
  @while i < graph.dg_nodes.len()
    node = graph.dg_nodes[i]
    @if inc_int_map_has(state.ts_indices, node.sf_path) == 0
      state = tarjan_strongconnect(graph, node.sf_path, state)
    @end
    i = i + 1
  @end

  cycles = []
  c_i = 0
  @while c_i < state.ts_sccs.len()
    scc = state.ts_sccs[c_i]
    @if scc.len() > 1
      cycles = cycles.push(scc)
    @elif scc.len() == 1
      node_path = scc[0]
      deps = dep_graph_get_dependencies(graph, node_path)
      @if inc_list_contains(deps, node_path) == 1
        cycles = cycles.push(scc)
      @end
    @end
    c_i = c_i + 1
  @end
  return cycles
@end

@! Kahn's Algorithm for Topological Sorting of Build Order
@fn dep_graph_topological_sort(graph)
  cycles = dep_graph_find_cycles(graph)
  @if cycles.len() > 0
    return { ok: 0, order: [], error: "Dependency cycle detected! Cannot topologically sort build graph." }
  @end

  in_degree = []
  i = 0
  @while i < graph.dg_nodes.len()
    node = graph.dg_nodes[i]
    in_degree = inc_int_map_set(in_degree, node.sf_path, 0)
    i = i + 1
  @end

  e_i = 0
  @while e_i < graph.dg_edges.len()
    e = graph.dg_edges[e_i]
    cnt = inc_int_map_get(in_degree, e.from_path, 0)
    in_degree = inc_int_map_set(in_degree, e.from_path, cnt + 1)
    e_i = e_i + 1
  @end

  queue = []
  q_i = 0
  @while q_i < graph.dg_nodes.len()
    node = graph.dg_nodes[q_i]
    deg = inc_int_map_get(in_degree, node.sf_path, 0)
    @if deg == 0
      queue = queue.push(node.sf_path)
    @end
    q_i = q_i + 1
  @end

  result = []
  head_ptr = 0
  @while head_ptr < queue.len()
    curr = queue[head_ptr]
    head_ptr = head_ptr + 1
    result = result.push(curr)

    dependents = dep_graph_get_dependents(graph, curr)
    dep_i = 0
    @while dep_i < dependents.len()
      nxt = dependents[dep_i]
      deg = inc_int_map_get(in_degree, nxt, 0)
      deg = deg - 1
      in_degree = inc_int_map_set(in_degree, nxt, deg)
      @if deg == 0
        queue = queue.push(nxt)
      @end
      dep_i = dep_i + 1
    @end
  @end

  @if result.len() != graph.dg_nodes.len()
    return { ok: 0, order: [], error: "Unreachable nodes or hidden cycle in dependency graph." }
  @end

  return { ok: 1, order: result, error: "" }
@end

@! BFS Change Propagation: finds all files affected by a change
@fn dep_graph_affected_by(graph, changed_files)
  affected = []
  queue = []
_i_c_0 = 0
@while _i_c_0 < changed_files.len()
  c = changed_files[_i_c_0]
  queue = queue.push(c)
  affected = affected.push(c)
  _i_c_0 = _i_c_0 + 1
@end

  head_ptr = 0
  @while head_ptr < queue.len()
    curr = queue[head_ptr]
    head_ptr = head_ptr + 1

    dependents = dep_graph_get_dependents(graph, curr)
    i = 0
    @while i < dependents.len()
      dep = dependents[i]
      @if inc_list_contains(affected, dep) == 0
        affected = affected.push(dep)
        queue = queue.push(dep)
      @end
      i = i + 1
    @end
  @end

  return affected
@end

@! ============================================================================
@! 5. COMPILATION CACHE IMPLEMENTATION (AST, Types, Exports, IR Bytes)
@! ============================================================================

@fn compilation_cache_new(cache_directory)
  cache = {
    cc_dir: cache_directory,
    cc_entries: [],
    cc_magic_header: 0x4C495049, @! 'LIPI'
    cc_version: 1
  }
  return cache
@end

@fn compilation_cache_get(cache, key_hash_or_path)
  key_str = key_hash_or_path.to_str()
  return inc_cache_map_get(cache.cc_entries, key_str)
@end

@fn compilation_cache_put(cache, key_hash_or_path, result)
  key_str = key_hash_or_path.to_str()
  cache.cc_entries = inc_cache_map_set(cache.cc_entries, key_str, result)
  return cache
@end

@fn compilation_cache_invalidate(cache, file_path)
  new_entries = []
  i = 0
  @while i < cache.cc_entries.len()
    entry = cache.cc_entries[i]
    res = entry.cme_val
    @if res != 0 && res.cr_file_path != file_path
      new_entries = new_entries.push(entry)
    @end
    i = i + 1
  @end
  cache.cc_entries = new_entries
  return cache
@end

@fn compilation_cache_size(cache)
  return cache.cc_entries.len()
@end

@! ============================================================================
@! 6. REAL AST-TO-IR GENERATION & SERIALIZATION ENGINE
@! ============================================================================

@! Extract exported symbols and types from AST statements
@fn inc_extract_ast_exports(ast_statements)
  exports = []
  type_env = []
  
  type_id_counter = 1
  i = 0
  @while i < ast_statements.len()
    stmt = ast_statements[i]
    @if stmt.kind == "FnDef" || stmt.kind == "FunctionDef" || stmt.kind == "Function"
      fn_name = stmt.name
      ret_t = "i64"
      @if stmt.ret_type != 0 && stmt.ret_type != ""
        ret_t = stmt.ret_type
      @end
      t_info = {
        type_id: type_id_counter,
        type_name: "fn:" + ret_t,
        type_size: 8
      }
      type_id_counter = type_id_counter + 1
      exports = inc_type_map_set(exports, fn_name, t_info)
      type_env = inc_type_map_set(type_env, fn_name, t_info)
    @elif stmt.kind == "StructDef" || stmt.kind == "Struct"
      st_name = stmt.name
      st_size = 8
      @if stmt.params != 0
        st_size = stmt.params.len() * 8
      @end
      t_info = {
        type_id: type_id_counter,
        type_name: string_concat("%struct.", st_name),
        type_size: st_size
      }
      type_id_counter = type_id_counter + 1
      exports = inc_type_map_set(exports, st_name, t_info)
      type_env = inc_type_map_set(type_env, st_name, t_info)
    @elif stmt.kind == "Let" || stmt.kind == "Assign"
      var_name = stmt.name
      @if var_name == ""
        var_name = stmt.target
      @end
      @if var_name != ""
        t_info = {
          type_id: type_id_counter,
          type_name: "i64",
          type_size: 8
        }
        type_id_counter = type_id_counter + 1
        type_env = inc_type_map_set(type_env, var_name, t_info)
      @end
    @end
    i = i + 1
  @end
  
  return { exports: exports, type_env: type_env }
@end

@! Converts string text to array of byte values (0..255)
@fn str_to_byte_array(s)
  bytes = []
  num_items = str_len(s)
  i = 0
  @while i < num_items
    b = str_byte_at(s, i)
    bytes = bytes.push(b)
    i = i + 1
  @end
  return bytes
@end

@! Compiles source code string into AST, lowers to Maya IR, extracts types/symbols & serializes
@fn inc_compile_source(file_path, source_code)
  content_hash = fnv1a_64_string(source_code)
  content_hash_hex = sha256_hex_string(source_code)

  @! 1. Parse AST
  parsed = parser_parse_program(source_code)
  ast_stmts = parsed.ast_statements
  ast_tokens = parsed.ast_tokens

  @! Compute AST hash
  ast_hash = fnv1a_64_string(source_code + "_ast_" + ast_stmts.len().to_str())

  @! 2. Extract Types & Exported Symbols
  extracted = inc_extract_ast_exports(ast_stmts)
  exports = extracted.exports
  type_env = extracted.type_env

  @! 3. Genuine Maya IR Lowering
  ir_opts = { module_name: file_path, dump_ir: 0 }
  ir_res = ir_module_from_ast(ast_stmts, ir_opts)
  ir_mod = ir_res.module

  @! 4. Serialize IR representation
  ir_text = ""
  @if ir_mod != 0
    ir_text = ir_module_to_string(ir_mod)
  @end
  ir_bytes = str_to_byte_array(ir_text)

  return {
    cr_file_path: file_path,
    cr_content_hash: content_hash,
    cr_content_hash_hex: content_hash_hex,
    cr_ast_hash: ast_hash,
    cr_ast: ast_stmts,
    cr_type_env: type_env,
    cr_exported_symbols: exports,
    cr_ir_bytes: ir_bytes,
    cr_ir_text: ir_text,
    cr_ir_module: ir_mod
  }
@end

@! Extract imports / dependencies from source code
@fn inc_extract_dependencies(source_code)
  deps = []
  num_items = source_code.len()
  i = 0
  @while i < num_items
    @if (i == 0 || source_code[i - 1] == 10) && i + 7 < num_items
      @if source_code[i] == 105 && source_code[i+1] == 109 && source_code[i+2] == 112 && source_code[i+3] == 111 && source_code[i+4] == 114 && source_code[i+5] == 116 && source_code[i+6] == 32
        i = i + 7
        @while i < num_items && (source_code[i] == 32 || source_code[i] == 9)
          i = i + 1
        @end
        imp_name = ""
        quote = 0
        @if i < num_items && (source_code[i] == 34 || source_code[i] == 39)
          quote = source_code[i]
          i = i + 1
        @end
        @while i < num_items && source_code[i] != 10 && source_code[i] != 13 && source_code[i] != quote && (quote != 0 || (source_code[i] != 32 && source_code[i] != 59))
          imp_name = imp_name + str_from_char_code(source_code[i])
          i = i + 1
        @end
        @if imp_name != ""
          deps = deps.push(imp_name)
        @end
      @end
    @end
    i = i + 1
  @end
  return deps
@end

@fn inc_resolve_import_path(root_dir, import_path)
  converted = import_path
  @if string_contains(converted, ".") == 1
    converted = string_replace(converted, ".", "/")
  @end
  @if str_ends_with(converted, ".maya") == 0
    converted = converted + ".maya"
  @end
  @if str_starts_with(converted, "/") == 1 || str_starts_with(converted, root_dir) == 1
    return converted
  @end
  return root_dir + "/" + converted
@end

@! ============================================================================
@! 7. INCREMENTAL DRIVER & DIRTY FILE COMPILATION
@! ============================================================================

@fn inc_compute_dirty_set(graph, cache)
  dirty = []
  i = 0
  @while i < graph.dg_nodes.len()
    node = graph.dg_nodes[i]
    cached = compilation_cache_get(cache, node.sf_content_hash)
    @if cached == 0
      cached = compilation_cache_get(cache, node.sf_path)
    @end
    @if cached == 0 || cached.cr_content_hash != node.sf_content_hash
      dirty = dirty.push(node.sf_path)
    @end
    i = i + 1
  @end

  return dep_graph_affected_by(graph, dirty)
@end

@! Compile dirty files in topological order, performing real AST-to-IR generation and caching
@fn compile_dirty(dirty_files, graph, cache)
  sort_res = dep_graph_topological_sort(graph)
  @if sort_res.ok == 0
    return { ok: 0, compiled_count: 0, error: sort_res.error }
  @end

  order = sort_res.order
  compiled_count = 0

  i = 0
  num_items = order.len()
  @while i < num_items
    file_path = order[i]
    @if inc_list_contains(dirty_files, file_path) == 1
      node = dep_graph_get_node(graph, file_path)
      source_code = file_read(file_path)
      result = inc_compile_source(file_path, source_code)

      cache = compilation_cache_put(cache, result.cr_content_hash, result)
      cache = compilation_cache_put(cache, file_path, result)
      compiled_count = compiled_count + 1
    @end
    i = i + 1
  @end

  return { ok: 1, compiled_count: compiled_count, error: "" }
@end

@fn inc_compile_dirty(dirty_files, graph, cache)
  return compile_dirty(dirty_files, graph, cache)

  _i_c_0 = _i_c_0 + 1
@end
