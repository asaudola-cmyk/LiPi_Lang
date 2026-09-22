// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: BUILD DEPENDENCY DAG ANALYZER (src/toolkit/build/dep_graph.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Incremental Compilation & Cycle Detector
// ==============================================================================
//
// WHY THIS MODULE:
// Incremental compilation and high-speed build orchestration require modeling the
// project source tree as a Directed Acyclic Graph (DAG):
// 1. Extracts `include` and `import` directives from source text without full parsing.
// 2. Traverses include dependencies recursively to construct the complete dependency DAG.
// 3. Implements 3-color DFS cycle detection to prevent infinite compilation loops.
// 4. Executes Kahn's topological sort algorithm to determine deterministic build ordering.
// 5. Propagates file changes through transitive dependents to calculate minimal rebuild sets.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates single source file node with collision-free field names.
struct DepNode
    node_path            // Normalized filesystem path
    node_dependencies    // List of paths this file directly depends upon (outgoing edges)
    node_dependents      // List of paths that depend upon this file (incoming edges)
    node_color           // DFS visitation color: 0 = White (unvisited), 1 = Gray (visiting), 2 = Black (visited)
    node_in_degree       // In-degree counter for Kahn's topological sort algorithm

// WHY: Master DAG container managing nodes, dependency edges, and graph diagnostics.
struct DepGraph
    graph_nodes          // List of DepNode structs
    graph_node_count     // Total registered node count
    graph_has_cycle      // 1 if a circular dependency cycle exists, 0 otherwise
    graph_cycle_info     // Human-readable diagnostic description of detected cycle

// ── 2. Constructor & Node Registry ────────────────────────────────────────────

// WHY: Allocates clean dependency graph instance.
fn dep_graph_new
    g = DepGraph()
    g.graph_nodes = list()
    g.graph_node_count = 0
    g.graph_has_cycle = 0
    g.graph_cycle_info = ""
    return g

// WHY: Locates existing node by normalized file path. Returns 0 if absent.
fn dep_find_node graph file_path
    nodes = graph.graph_nodes
    c = len(nodes)
    i = 0
    while i < c
        node = get(nodes, i)
        if node.node_path == file_path
            return node
        i = i + 1
    return 0

// WHY: Inserts new node into graph if not already registered.
fn dep_add_node graph file_path
    existing = dep_find_node(graph, file_path)
    if existing != 0 return existing

    node = DepNode()
    node.node_path = file_path
    node.node_dependencies = list()
    node.node_dependents = list()
    node.node_color = 0
    node.node_in_degree = 0

    push(graph.graph_nodes, node)
    graph.graph_node_count = graph.graph_node_count + 1
    return node

// WHY: Adds directed dependency edge: `from_file` depends on `to_file`.
fn dep_add_edge graph from_file to_file
    from_node = dep_add_node(graph, from_file)
    to_node = dep_add_node(graph, to_file)

    // Check if edge already registered
    deps = from_node.node_dependencies
    d_count = len(deps)
    i = 0
    already_has = 0
    while i < d_count
        if get(deps, i) == to_file
            already_has = 1
            break
        i = i + 1

    if already_has == 0
        push(from_node.node_dependencies, to_file)
        push(to_node.node_dependents, from_file)
        from_node.node_in_degree = from_node.node_in_degree + 1

    return 0

// ── 3. Path Normalization & Include Directive Extractor ────────────────────────

// WHY: Computes directory prefix for a given file path.
fn dep_dirname file_path
    slen = len(file_path)
    last_slash = -1
    i = 0
    while i < slen
        if char_at(file_path, i) == "/" last_slash = i
        i = i + 1
    if last_slash < 0 return "."
    if last_slash == 0 return "/"
    return str_sub(file_path, 0, last_slash)

// WHY: Resolves relative include target path relative to directory of including file.
fn dep_resolve_relative dir target
    if len(target) == 0 return ""
    if char_at(target, 0) == "/" return target

    if dir == "." or len(dir) == 0
        return target
    return dir + "/" + target

// WHY: Fast lexical scanner extracting target paths from `include "..."` directives.
fn dep_extract_includes source_text current_file
    includes = list()
    tlen = len(source_text)
    if tlen == 0 return includes

    cur_dir = dep_dirname(current_file)
    i = 0

    while i < tlen
        is_inc = 0
        inc_len = 0

        if (i + 9) <= tlen and str_sub(source_text, i, i + 9) == "include \""
            is_inc = 1
            inc_len = 9
        elif (i + 8) <= tlen and str_sub(source_text, i, i + 8) == "import \""
            is_inc = 1
            inc_len = 8

        if is_inc == 1
            start_q = i + inc_len
            end_q = -1
            j = start_q
            while j < tlen
                if char_at(source_text, j) == "\""
                    end_q = j
                    break
                j = j + 1

            if end_q > start_q
                inc_target = str_sub(source_text, start_q, end_q)
                resolved = inc_target
                if file_exists(resolved) == 0
                    rel_target = dep_resolve_relative(cur_dir, inc_target)
                    if file_exists(rel_target) == 1
                        resolved = rel_target

                push(includes, resolved)
                i = end_q + 1
                continue

        i = i + 1

    return includes

// ── 4. Graph Construction Engine ──────────────────────────────────────────────

// WHY: Recursively traverses includes starting from root entry point to assemble full DAG.
fn dep_build_from_root graph root_file
    if file_exists(root_file) == 0 return 0

    dep_add_node(graph, root_file)
    queue = list()
    push(queue, root_file)

    while len(queue) > 0
        curr_file = get(queue, 0)
        qlen = len(queue)
        new_queue = list()
        q_i = 1
        while q_i < qlen
            push(new_queue, get(queue, q_i))
            q_i = q_i + 1
        queue = new_queue

        if file_exists(curr_file) == 1
            content = file_read(curr_file)
            includes = dep_extract_includes(content, curr_file)
            inc_count = len(includes)
            i = 0
            while i < inc_count
                inc_path = get(includes, i)
                dep_add_edge(graph, curr_file, inc_path)

                inc_node = dep_find_node(graph, inc_path)
                if len(inc_node.node_dependencies) == 0 and file_exists(inc_path) == 1
                    push(queue, inc_path)

                i = i + 1

    return graph.graph_node_count

// ── 5. Cycle Detection (3-Color DFS) ───────────────────────────────────────────

// WHY: Recursive DFS worker marking nodes White (0), Gray (1), and Black (2).
// Encountering a Gray node indicates a back-edge in the DFS tree, proving a cyclic dependency.
fn dep_dfs_cycle graph node
    node.node_color = 1 // Gray (visiting / on current recursion stack)

    deps = node.node_dependencies
    c = len(deps)
    i = 0
    while i < c
        dep_path = get(deps, i)
        child = dep_find_node(graph, dep_path)
        if child != 0
            if child.node_color == 1
                // Cycle detected!
                graph.graph_has_cycle = 1
                graph.graph_cycle_info = "Circular include detected: " + node.node_path + " -> " + child.node_path
                return 1
            elif child.node_color == 0
                if dep_dfs_cycle(graph, child) == 1
                    return 1
        i = i + 1

    node.node_color = 2 // Black (fully explored)
    return 0

// WHY: Scans all graph components for circular include cycles.
fn dep_detect_cycles graph
    graph.graph_has_cycle = 0
    graph.graph_cycle_info = ""

    nodes = graph.graph_nodes
    c = len(nodes)
    i = 0
    while i < c
        n = get(nodes, i)
        n.node_color = 0
        i = i + 1

    i = 0
    while i < c
        n = get(nodes, i)
        if n.node_color == 0
            if dep_dfs_cycle(graph, n) == 1
                return 1
        i = i + 1

    return 0

// ── 6. Topological Sort (Deterministic Compilation Order) ─────────────────────

// WHY: Produces linear build sequence where all dependencies precede their dependents.
fn dep_topological_sort graph
    if dep_detect_cycles(graph) == 1
        return list() // Cannot topologically sort a cyclic graph

    nodes = graph.graph_nodes
    c = len(nodes)

    in_degrees = list()
    i = 0
    while i < c
        n = get(nodes, i)
        push(in_degrees, len(n.node_dependencies))
        i = i + 1

    ready_queue = list()
    i = 0
    while i < c
        if get(in_degrees, i) == 0
            push(ready_queue, get(nodes, i))
        i = i + 1

    order = list()

    while len(ready_queue) > 0
        curr_node = get(ready_queue, 0)
        qlen = len(ready_queue)
        new_ready = list()
        q_i = 1
        while q_i < qlen
            push(new_ready, get(ready_queue, q_i))
            q_i = q_i + 1
        ready_queue = new_ready

        push(order, curr_node.node_path)

        dependents = curr_node.node_dependents
        d_count = len(dependents)
        d_i = 0
        while d_i < d_count
            dep_path = get(dependents, d_i)
            n_idx = 0
            while n_idx < c
                test_node = get(nodes, n_idx)
                if test_node.node_path == dep_path
                    cur_deg = get(in_degrees, n_idx) - 1
                    list_set(in_degrees, n_idx, cur_deg)
                    if cur_deg == 0
                        push(ready_queue, test_node)
                    break
                n_idx = n_idx + 1
            d_i = d_i + 1

    return order

// ── 7. Change Propagation (Transitive Invalidation) ───────────────────────────

// WHY: Given modified source files, computes minimal set of all files that must be recompiled.
fn dep_propagate_changes graph modified_files
    rebuild_set = list()
    queue = list()

    m_count = len(modified_files)
    i = 0
    while i < m_count
        push(queue, get(modified_files, i))
        push(rebuild_set, get(modified_files, i))
        i = i + 1

    while len(queue) > 0
        curr_path = get(queue, 0)
        qlen = len(queue)
        new_q = list()
        q_i = 1
        while q_i < qlen
            push(new_q, get(queue, q_i))
            q_i = q_i + 1
        queue = new_q

        curr_node = dep_find_node(graph, curr_path)
        if curr_node != 0
            dependents = curr_node.node_dependents
            d_count = len(dependents)
            d_i = 0
            while d_i < d_count
                dep_path = get(dependents, d_i)
                already_in = 0
                r_idx = 0
                while r_idx < len(rebuild_set)
                    if get(rebuild_set, r_idx) == dep_path
                        already_in = 1
                        break
                    r_idx = r_idx + 1

                if already_in == 0
                    push(rebuild_set, dep_path)
                    push(queue, dep_path)

                d_i = d_i + 1

    return rebuild_set
