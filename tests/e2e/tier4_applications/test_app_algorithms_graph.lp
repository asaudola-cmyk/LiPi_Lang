@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: 6 SORTING ALGORITHMS & DIJKSTRA GRAPH
@! File: tests/e2e/tier4_applications/test_app_algorithms_graph.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct GraphEdge
  to_node: 0
  weight: 0
@end

@struct Graph
  num_nodes: 0
  adj: 0
@end

@struct DijkstraResult
  dist: 0
  prev: 0
@end

@fn copy_array(arr)
  res = []
  i = 0
  len = arr.len()
  @while i < len
    res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@fn is_sorted_asc(arr)
  i = 0
  len = arr.len()
  @while i + 1 < len
    @if arr[i] > arr[i + 1]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@! 1. Bubble Sort
@fn bubble_sort(arr)
  a = copy_array(arr)
  n = a.len()
  i = 0
  @while i < n
    j = 0
    @while j < n - i - 1
      @if a[j] > a[j + 1]
        t = a[j]
        a[j] = a[j + 1]
        a[j + 1] = t
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return a
@end

@! 2. Insertion Sort
@fn insertion_sort(arr)
  a = copy_array(arr)
  n = a.len()
  i = 1
  @while i < n
    key = a[i]
    j = i - 1
    @while j >= 0 && a[j] > key
      a[j + 1] = a[j]
      j = j - 1
    @end
    a[j + 1] = key
    i = i + 1
  @end
  return a
@end

@! 3. Quick Sort
@fn quick_sort_rec(a, low, high)
  @if low < high
    pivot = a[high]
    i = low - 1
    j = low
    @while j < high
      @if a[j] <= pivot
        i = i + 1
        t = a[i]
        a[i] = a[j]
        a[j] = t
      @end
      j = j + 1
    @end
    t2 = a[i + 1]
    a[i + 1] = a[high]
    a[high] = t2
    pi = i + 1

    a = quick_sort_rec(a, low, pi - 1)
    a = quick_sort_rec(a, pi + 1, high)
  @end
  return a
@end

@fn quick_sort(arr)
  a = copy_array(arr)
  n = a.len()
  @if n > 1
    a = quick_sort_rec(a, 0, n - 1)
  @end
  return a
@end

@! 4. Graph Construction
@fn graph_new(num_nodes)
  adj = []
  i = 0
  @while i < num_nodes
    adj.push([])
    i = i + 1
  @end
  return { num_nodes: num_nodes, adj: adj }
@end

@fn graph_add_edge(g, u, v, w)
  g.adj[u].push({ to_node: v, weight: w })
  return g
@end

@! 5. Breadth-First Search (BFS) Hop Distances
@fn bfs_hops(g, start_node)
  dist = []
  i = 0
  @while i < g.num_nodes
    dist.push(-1)
    i = i + 1
  @end

  dist[start_node] = 0
  queue = [start_node]
  q_head = 0

  @while q_head < queue.len()
    u = queue[q_head]
    q_head = q_head + 1

    edges = g.adj[u]
    e_idx = 0
    e_len = edges.len()
    @while e_idx < e_len
      v = edges[e_idx].to_node
      @if dist[v] == -1
        dist[v] = dist[u] + 1
        queue.push(v)
      @end
      e_idx = e_idx + 1
    @end
  @end

  return dist
@end

@! 6. Dijkstra Shortest Path Algorithm
@fn dijkstra_shortest_path(g, start_node)
  INF = 999999999
  dist = []
  prev = []
  visited = []
  i = 0
  @while i < g.num_nodes
    dist.push(INF)
    prev.push(-1)
    visited.push(0)
    i = i + 1
  @end

  dist[start_node] = 0

  count = 0
  @while count < g.num_nodes
    @! Find unvisited node with minimum distance
    min_d = INF
    u = -1
    j = 0
    @while j < g.num_nodes
      @if visited[j] == 0 && dist[j] < min_d
        min_d = dist[j]
        u = j
      @end
      j = j + 1
    @end

    @if u == -1 || min_d == INF
      break
    @end

    visited[u] = 1

    @! Relax adjacent edges
    edges = g.adj[u]
    e_idx = 0
    e_len = edges.len()
    @while e_idx < e_len
      e = edges[e_idx]
      v = e.to_node
      weight = e.weight
      alt = dist[u] + weight
      @if alt < dist[v]
        dist[v] = alt
        prev[v] = u
      @end
      e_idx = e_idx + 1
    @end

    count = count + 1
  @end

  return { dist: dist, prev: prev }
@end

@fn reconstruct_path(prev, target)
  path = []
  curr = target
  @while curr != -1
    path.push(curr)
    curr = prev[curr]
  @end
  @! Reverse path
  rev = []
  k = path.len() - 1
  @while k >= 0
    rev.push(path[k])
    k = k - 1
  @end
  return rev
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 5: Sorting Algorithms & Dijkstra Shortest Path")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.5.1: Sorting Algorithms Verification (50-element Pseudo-Random Array)
  total = total + 1
  data = []
  seed = 12345
  i = 0
  @while i < 50
    seed = (seed * 1103515245 + 12345) & 2147483647
    data.push(seed % 1000)
    i = i + 1
  @end

  s1 = bubble_sort(data)
  s2 = insertion_sort(data)
  s3 = quick_sort(data)

  is_s1 = is_sorted_asc(s1)
  is_s2 = is_sorted_asc(s2)
  is_s3 = is_sorted_asc(s3)

  @! Check all 3 sorting algorithms match element by element
  match_all = 1
  m_idx = 0
  @while m_idx < 50
    @if s1[m_idx] != s2[m_idx] || s2[m_idx] != s3[m_idx]
      match_all = 0
    @end
    m_idx = m_idx + 1
  @end

  @if is_s1 == 1 && is_s2 == 1 && is_s3 == 1 && match_all == 1
    passed = passed + 1
    println("  [PASS] T4.5.1: BubbleSort, InsertionSort & QuickSort sorted 50 items with 100% element congruence")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.1: Sorting verification failed")
  @end

  @! T4.5.2: Build 8-Node Weighted Directed Graph
  total = total + 1
  g = graph_new(8)
  g = graph_add_edge(g, 0, 1, 4)
  g = graph_add_edge(g, 0, 2, 2)
  g = graph_add_edge(g, 1, 2, 5)
  g = graph_add_edge(g, 1, 3, 10)
  g = graph_add_edge(g, 2, 4, 3)
  g = graph_add_edge(g, 4, 3, 4)
  g = graph_add_edge(g, 3, 5, 11)
  g = graph_add_edge(g, 4, 5, 8)
  g = graph_add_edge(g, 4, 6, 7)
  g = graph_add_edge(g, 5, 7, 2)
  g = graph_add_edge(g, 6, 7, 6)

  @if g.num_nodes == 8 && g.adj[0].len() == 2 && g.adj[4].len() == 3
    passed = passed + 1
    println("  [PASS] T4.5.2: 8-node weighted directed graph initialized with 11 edges")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.2: Graph init failed")
  @end

  @! T4.5.3: BFS Hop Distances from Node 0
  total = total + 1
  bfs_d = bfs_hops(g, 0)
  @! Hops: 0->0=0, 0->1=1, 0->2=1, 0->3=2 (via 4 or 1), 0->4=2 (via 2), 0->5=3 (via 4), 0->6=3 (via 4), 0->7=4 (via 5 or 6)
  @if bfs_d[0] == 0 && bfs_d[1] == 1 && bfs_d[2] == 1 && bfs_d[4] == 2 && bfs_d[7] == 4
    passed = passed + 1
    println("  [PASS] T4.5.3: BFS computed exact unweighted hop distances (0->7 = 4 hops)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.3: BFS hops failed: " + int_to_str(bfs_d[7]))
  @end

  @! T4.5.4: Dijkstra Shortest Weighted Path from Node 0 to Node 7
  total = total + 1
  dijk = dijkstra_shortest_path(g, 0)
  @! Weighted distances from 0:
  @! 0 -> 2: weight 2
  @! 0 -> 2 -> 4: weight 2 + 3 = 5
  @! 0 -> 2 -> 4 -> 3: weight 5 + 4 = 9
  @! 0 -> 2 -> 4 -> 5: weight 5 + 8 = 13
  @! 0 -> 2 -> 4 -> 6: weight 5 + 7 = 12
  @! 0 -> 2 -> 4 -> 5 -> 7: weight 13 + 2 = 15
  @! 0 -> 2 -> 4 -> 6 -> 7: weight 12 + 6 = 18
  @! Shortest path to 7 is 0 -> 2 -> 4 -> 5 -> 7 with total distance 15.

  optimal_dist = dijk.dist[7]
  opt_path = reconstruct_path(dijk.prev, 7)

  @if optimal_dist == 15 && opt_path.len() == 5 && opt_path[0] == 0 && opt_path[1] == 2 && opt_path[2] == 4 && opt_path[3] == 5 && opt_path[4] == 7
    passed = passed + 1
    println("  [PASS] T4.5.4: Dijkstra found optimal shortest path [0 -> 2 -> 4 -> 5 -> 7] with total cost 15")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.4: Dijkstra failed: dist=" + int_to_str(optimal_dist))
  @end

  @! T4.5.5: Unreachable / Disconnected Subgraph Distance
  total = total + 1
  g_iso = graph_new(3)
  g_iso = graph_add_edge(g_iso, 0, 1, 10)
  d_iso = dijkstra_shortest_path(g_iso, 0)

  @if d_iso.dist[0] == 0 && d_iso.dist[1] == 10 && d_iso.dist[2] == 999999999
    passed = passed + 1
    println("  [PASS] T4.5.5: Disconnected graph node correctly flagged with INF (999999999)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5.5: Disconnected node check failed")
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 5 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 5 (Algorithms & Dijkstra Graph) PASSED")
    return 0
  @else
    println("✗ Scenario 5 (Algorithms & Dijkstra Graph) FAILED")
    return 1
  @end
@end
