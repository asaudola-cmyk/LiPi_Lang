@! ============================================================================
@! MAYA PACKAGE MANAGER (MPM) — SEMVER 2.0.0 & DEPENDENCY GRAPH ENGINE
@! Module: tools/mpm/semver.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Full SemVer 2.0.0 Parser (major, minor, patch, prerelease, build)
@! - Semantic version precedence & comparison engine
@! - Rich constraint matching (^, ~, >=, <=, >, <, =, *, 1.x, ranges, ||)
@! - Max satisfying version selector from remote version indexes
@! - Topological dependency graph builder with 3-color DFS cycle detection
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"

@! ----------------------------------------------------------------------------
@! 1. SEMVER 2.0.0 PARSER & DATA STRUCTURE
@! ----------------------------------------------------------------------------

@fn semver_parse(version_str)
  s = string_trim(version_str)
  @if starts_with(s, "v") || starts_with(s, "V")
    s = string_slice(s, 1, s.len())
  @end
  
  @if s == "" || s == none
    return { major: 0, minor: 0, patch: 0, prerelease: "", build: "", valid: 0, raw: version_str }
  @end
  
  @! 1. Separate Build Metadata (+)
  build = ""
  @if contains(s, "+")
    parts_plus = string_split(s, "+")
    s = parts_plus[0]
    @if parts_plus.len() > 1
      build = parts_plus[1]
    @end
  @end
  
  @! 2. Separate Prerelease (-)
  prerelease = ""
  @if contains(s, "-")
    parts_dash = string_split(s, "-")
    s = parts_dash[0]
    @if parts_dash.len() > 1
      prerelease = parts_dash[1]
    @end
  @end
  
  @! 3. Parse Major, Minor, Patch (.)
  nums = string_split(s, ".")
  major = 0
  minor = 0
  patch = 0
  
  @if nums.len() >= 1
    major = string_to_int(nums[0])
  @end
  @if nums.len() >= 2
    minor = string_to_int(nums[1])
  @end
  @if nums.len() >= 3
    patch = string_to_int(nums[2])
  @end
  
  return {
    major: major,
    minor: minor,
    patch: patch,
    prerelease: prerelease,
    build: build,
    valid: 1,
    raw: version_str
  }
@end

@fn semver_to_str(ver)
  @if ver == 0 || ver == none return "0.0.0" @end
  res = ver.major.to_str() + "." + ver.minor.to_str() + "." + ver.patch.to_str()
  @if ver.prerelease != ""
    res = res + "-" + ver.prerelease
  @end
  @if ver.build != ""
    res = res + "+" + ver.build
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 2. PRECEDENCE & COMPARISON
@! ----------------------------------------------------------------------------

@fn semver_compare(v1, v2)
  @if v1.major > v2.major return 1 @end
  @if v1.major < v2.major return 0 - 1 @end
  
  @if v1.minor > v2.minor return 1 @end
  @if v1.minor < v2.minor return 0 - 1 @end
  
  @if v1.patch > v2.patch return 1 @end
  @if v1.patch < v2.patch return 0 - 1 @end
  
  @! Prerelease Comparison
  @! A normal version has higher precedence than a pre-release version
  @if v1.prerelease == "" && v2.prerelease != ""
    return 1
  @end
  @if v1.prerelease != "" && v2.prerelease == ""
    return 0 - 1
  @end
  
  @if v1.prerelease != "" && v2.prerelease != ""
    @if v1.prerelease > v2.prerelease return 1 @end
    @if v1.prerelease < v2.prerelease return 0 - 1 @end
  @end
  
  return 0
@end

@fn semver_compare_str(str1, str2)
  v1 = semver_parse(str1)
  v2 = semver_parse(str2)
  return semver_compare(v1, v2)
@end

@fn semver_eq(v1, v2)
  return semver_compare(v1, v2) == 0
@end

@fn semver_gt(v1, v2)
  return semver_compare(v1, v2) == 1
@end

@fn semver_gte(v1, v2)
  return semver_compare(v1, v2) >= 0
@end

@fn semver_lt(v1, v2)
  return semver_compare(v1, v2) == 0 - 1
@end

@fn semver_lte(v1, v2)
  return semver_compare(v1, v2) <= 0
@end

@! ----------------------------------------------------------------------------
@! 3. CONSTRAINT SATISFACTION ENGINE
@! ----------------------------------------------------------------------------

@fn semver_eval_single_clause(ver, clause)
  c = string_trim(clause)
  @if c == "" || c == "*" || c == "x" || c == "X" || c == "latest"
    return 1
  @end
  
  @! Caret Constraint (^)
  @! ^1.2.3 -> >= 1.2.3 < 2.0.0
  @! ^0.2.3 -> >= 0.2.3 < 0.3.0
  @! ^0.0.3 -> == 0.0.3
  @if starts_with(c, "^")
    req = semver_parse(string_slice(c, 1, c.len()))
    @if semver_lt(ver, req)
      return 0
    @end
    @if req.major > 0
      upper = { major: req.major + 1, minor: 0, patch: 0, prerelease: "", build: "" }
      return semver_lt(ver, upper)
    @elif req.minor > 0
      upper = { major: 0, minor: req.minor + 1, patch: 0, prerelease: "", build: "" }
      return semver_lt(ver, upper)
    @else
      return semver_eq(ver, req)
    @end
  @end
  
  @! Tilde Constraint (~)
  @! ~1.2.3 -> >= 1.2.3 < 1.3.0
  @! ~1.2   -> >= 1.2.0 < 2.0.0
  @! ~1     -> >= 1.0.0 < 2.0.0
  @if starts_with(c, "~")
    req = semver_parse(string_slice(c, 1, c.len()))
    @if semver_lt(ver, req)
      return 0
    @end
    upper = { major: req.major, minor: req.minor + 1, patch: 0, prerelease: "", build: "" }
    return semver_lt(ver, upper)
  @end
  
  @! Greater Than or Equal (>=)
  @if starts_with(c, ">=")
    req = semver_parse(string_slice(c, 2, c.len()))
    return semver_gte(ver, req)
  @end
  
  @! Less Than or Equal (<=)
  @if starts_with(c, "<=")
    req = semver_parse(string_slice(c, 2, c.len()))
    return semver_lte(ver, req)
  @end
  
  @! Greater Than (>)
  @if starts_with(c, ">")
    req = semver_parse(string_slice(c, 1, c.len()))
    return semver_gt(ver, req)
  @end
  
  @! Less Than (<)
  @if starts_with(c, "<")
    req = semver_parse(string_slice(c, 1, c.len()))
    return semver_lt(ver, req)
  @end
  
  @! Equal (=) or Exact Match
  @if starts_with(c, "=")
    req = semver_parse(string_slice(c, 1, c.len()))
    return semver_eq(ver, req)
  @end
  
  @! Wildcard Prefix e.g. "1.*", "1.x", "1.2.*"
  @if contains(c, "*") || contains(c, "x") || contains(c, "X")
    parts = string_split(c, ".")
    @if parts.len() >= 1 && parts[0] != "*" && parts[0] != "x" && parts[0] != "X"
      req_m = string_to_int(parts[0])
      @if ver.major != req_m return 0 @end
    @end
    @if parts.len() >= 2 && parts[1] != "*" && parts[1] != "x" && parts[1] != "X"
      req_mi = string_to_int(parts[1])
      @if ver.minor != req_mi return 0 @end
    @end
    return 1
  @end
  
  @! Default Exact Match
  req = semver_parse(c)
  return semver_eq(ver, req)
@end

@fn semver_satisfies(version_str, constraint_str)
  ver = semver_parse(version_str)
  @if ver.valid == 0
    return 0
  @end
  
  c_str = string_trim(constraint_str)
  @if c_str == "" || c_str == "*"
    return 1
  @end
  
  @! 1. Handle Logical OR (||)
  @if contains(c_str, "||")
    or_clauses = string_split(c_str, "||")
    i = 0
    len = or_clauses.len()
    @while i < len
      @if semver_satisfies(version_str, or_clauses[i]) == 1
        return 1
      @end
      i = i + 1
    @end
    return 0
  @end
  
  @! 2. Handle Hyphen Range ("1.0.0 - 2.0.0")
  @if contains(c_str, " - ")
    parts = string_split(c_str, " - ")
    @if parts.len() == 2
      lower = semver_parse(parts[0])
      upper = semver_parse(parts[1])
      @if semver_gte(ver, lower) && semver_lte(ver, upper)
        return 1
      @end
      return 0
    @end
  @end
  
  @! 3. Handle Space-separated AND clauses (e.g. ">=1.0.0 <2.0.0")
  clauses = string_split(c_str, " ")
  i = 0
  len = clauses.len()
  @while i < len
    clause = string_trim(clauses[i])
    @if clause != ""
      @if semver_eval_single_clause(ver, clause) == 0
        return 0
      @end
    @end
    i = i + 1
  @end
  
  return 1
@end

@fn semver_max_satisfying(versions_list, constraint_str)
  best_ver = 0
  best_str = ""
  
  i = 0
  len = versions_list.len()
  @while i < len
    candidate_str = versions_list[i]
    @if semver_satisfies(candidate_str, constraint_str) == 1
      cand_ver = semver_parse(candidate_str)
      @if best_ver == 0 || semver_gt(cand_ver, best_ver)
        best_ver = cand_ver
        best_str = candidate_str
      @end
    @end
    i = i + 1
  @end
  
  return best_str
@end

@! ----------------------------------------------------------------------------
@! 4. TOPOLOGICAL DEPENDENCY GRAPH SOLVER & CYCLE DETECTION
@! ----------------------------------------------------------------------------

@fn dep_graph_new()
  return {
    nodes: [],
    edges: []
  }
@end

@fn dep_graph_add_node(graph, pkg_name, version, dependencies)
  @! dependencies is list of { name: "foo", constraint: "^1.0.0" }
  node = {
    name: pkg_name,
    version: version,
    deps: dependencies
  }
  graph.nodes = graph.nodes.push(node)
  
  i = 0
  len = dependencies.len()
  @while i < len
    dep = dependencies[i]
    edge = { from: pkg_name, to: dep.name, constraint: dep.constraint }
    graph.edges = graph.edges.push(edge)
    i = i + 1
  @end
  
  return graph
@end

@fn dep_graph_find_node(graph, name)
  i = 0
  len = graph.nodes.len()
  @while i < len
    n = graph.nodes[i]
    @if n.name == name return n @end
    i = i + 1
  @end
  return 0
@end

@fn dep_graph_get_deps(graph, name)
  deps = []
  i = 0
  len = graph.edges.len()
  @while i < len
    e = graph.edges[i]
    @if e.from == name
      deps = deps.push(e.to)
    @end
    i = i + 1
  @end
  return deps
@end

@fn dep_graph_dfs(graph, node_name, visited_state, current_path, out_order)
  @! visited_state: 0 = UNVISITED (WHITE), 1 = VISITING (GREY), 2 = VISITED (BLACK)
  state = 0
  si = 0
  while_si = visited_state.len()
  @while si < while_si
    if_st = visited_state[si]
    @if if_st.name == node_name
      state = if_st.state
      si = while_si
    @end
    si = si + 1
  @end
  
  @if state == 1
    @! Cycle detected! Return cycle path
    cycle_path = current_path.push(node_name)
    return { has_cycle: 1, cycle: cycle_path, order: out_order, visited: visited_state }
  @end
  
  @if state == 2
    @! Already processed
    return { has_cycle: 0, cycle: [], order: out_order, visited: visited_state }
  @end
  
  @! Mark GREY (VISITING)
  visited_state = visited_state.push({ name: node_name, state: 1 })
  current_path = current_path.push(node_name)
  
  children = dep_graph_get_deps(graph, node_name)
  ci = 0
  clen = children.len()
  @while ci < clen
    child_name = children[ci]
    res = dep_graph_dfs(graph, child_name, visited_state, current_path, out_order)
    @if res.has_cycle == 1
      return res
    @end
    visited_state = res.visited
    out_order = res.order
    ci = ci + 1
  @end
  
  @! Mark BLACK (VISITED)
  new_vis = []
  vi = 0
  vlen = visited_state.len()
  @while vi < vlen
    ve = visited_state[vi]
    @if ve.name == node_name
      new_vis = new_vis.push({ name: node_name, state: 2 })
    @else
      new_vis = new_vis.push(ve)
    @end
    vi = vi + 1
  @end
  visited_state = new_vis
  
  @! Append to topological build order
  out_order = out_order.push(node_name)
  
  return { has_cycle: 0, cycle: [], order: out_order, visited: visited_state }
@end

@fn dep_graph_resolve(graph, root_pkgs)
  visited_state = []
  order = []
  
  i = 0
  len = root_pkgs.len()
  @while i < len
    root_name = root_pkgs[i]
    res = dep_graph_dfs(graph, root_name, visited_state, [], order)
    @if res.has_cycle == 1
      cycle_str = join(res.cycle, " -> ")
      return {
        success: 0,
        cycle: res.cycle,
        order: [],
        error: "Cyclic dependency detected: " + cycle_str
      }
    @end
    visited_state = res.visited
    order = res.order
    i = i + 1
  @end
  
  @! Remove duplicate package names in order while preserving resolution order
  dedup_order = []
  oi = 0
  olen = order.len()
  @while oi < olen
    pkg = order[oi]
    found = 0
    di = 0
    dlen = dedup_order.len()
    @while di < dlen
      @if dedup_order[di] == pkg found = 1 @end
      di = di + 1
    @end
    @if found == 0
      dedup_order = dedup_order.push(pkg)
    @end
    oi = oi + 1
  @end
  
  return {
    success: 1,
    order: dedup_order,
    cycle: [],
    error: "none"
  }
@end
