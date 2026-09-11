@@! Graph Algorithms in Lipi
@@! Demonstrates Breadth-First Search (BFS), Depth-First Search (DFS), and Dijkstra's Shortest Path

@fn bfs(matrix, n, start_node, names)
  visited = []
  i = 0
  @while i < n
    visited = visited.push(0)
    i = i + 1
  @end
  
  q = []
  q = q.push(start_node)
  visited[start_node] = 1
  
  head = 0
  order = ""
  
  @while head < q.len()
    u = q[head]
    head = head + 1
    
    @if str_len(order) > 0
      order = order + " -> "
    @end
    order = order + names[u]
    
    v = 0
    @while v < n
      w = matrix[u * n + v]
      @if w > 0
        @if visited[v] == 0
          visited[v] = 1
          q = q.push(v)
        @end
      @end
      v = v + 1
    @end
  @end
  
  println("BFS Order: " + order)
@end

@fn dfs_recurse(matrix, n, u, visited, order_arr)
  visited[u] = 1
  order_arr = order_arr.push(u)
  
  v = 0
  @while v < n
    w = matrix[u * n + v]
    @if w > 0
      @if visited[v] == 0
        dfs_recurse(matrix, n, v, visited, order_arr)
      @end
    @end
    v = v + 1
  @end
@end

@fn dfs(matrix, n, start_node, names)
  visited = []
  i = 0
  @while i < n
    visited = visited.push(0)
    i = i + 1
  @end
  
  order_arr = []
  dfs_recurse(matrix, n, start_node, visited, order_arr)
  
  order_str = ""
  i = 0
  @while i < order_arr.len()
    @if i > 0
      order_str = order_str + " -> "
    @end
    order_str = order_str + names[order_arr[i]]
    i = i + 1
  @end
  
  println("DFS Order: " + order_str)
@end

@fn dijkstra(matrix, n, start_node, names)
  dist = []
  visited = []
  
  i = 0
  @while i < n
    dist = dist.push(999999)
    visited = visited.push(0)
    i = i + 1
  @end
  
  dist[start_node] = 0
  
  i = 0
  @while i < n
    u = -1
    min_d = 999999
    
    j = 0
    @while j < n
      @if visited[j] == 0
        @if dist[j] < min_d
          min_d = dist[j]
          u = j
        @end
      @end
      j = j + 1
    @end
    
    @if u != -1
      visited[u] = 1
      v = 0
      @while v < n
        w = matrix[u * n + v]
        @if w > 0
          @if visited[v] == 0
            alt = dist[u] + w
            @if alt < dist[v]
              dist[v] = alt
            @end
          @end
        @end
        v = v + 1
      @end
    @end
    i = i + 1
  @end
  
  println("Dijkstra Shortest Paths from " + names[start_node] + ":")
  i = 0
  @while i < n
    @if dist[i] == 999999
      println("  " + names[i] + ": unreachable")
    @else
      println("  " + names[i] + ": " + int_to_str(dist[i]))
    @end
    i = i + 1
  @end
@end

@fn main()
  println("=== Graph Algorithms ===")
  names = ["A", "B", "C", "D", "E"]
  n = 5
  
  @! Initialize 5x5 matrix with 0
  matrix = []
  i = 0
  @while i < 25
    matrix = matrix.push(0)
    i = i + 1
  @end
  
  @! Add edges (directed)
  @! A -> B (10), A -> D (5)
  matrix[0 * n + 1] = 10
  matrix[0 * n + 3] = 5
  
  @! B -> C (1), B -> D (2)
  matrix[1 * n + 2] = 1
  matrix[1 * n + 3] = 2
  
  @! C -> E (4)
  matrix[2 * n + 4] = 4
  
  @! D -> B (3), D -> C (9), D -> E (2)
  matrix[3 * n + 1] = 3
  matrix[3 * n + 2] = 9
  matrix[3 * n + 4] = 2
  
  @! E -> A (7), E -> C (6)
  matrix[4 * n + 0] = 7
  matrix[4 * n + 2] = 6
  
  bfs(matrix, n, 0, names)
  dfs(matrix, n, 0, names)
  dijkstra(matrix, n, 0, names)
  
  return 0
@end
