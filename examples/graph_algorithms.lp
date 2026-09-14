// ==============================================================================
// 👑 LIPI EXAMPLE: GRAPH ALGORITHMS (examples/graph_algorithms.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// Demonstrates Breadth-First Search (BFS), Depth-First Search (DFS), and Dijkstra
// ==============================================================================

fn make_zero_list count
    lst = list()
    i = 0
    while i < count
        push(lst, 0)
        i = i + 1
    return lst

fn bfs matrix n start_node names
    visited = make_zero_list(n)
    q = list()
    push(q, start_node)
    list_set(visited, start_node, 1)
    
    head = 0
    order = ""
    while head < len(q)
        u = get(q, head)
        head = head + 1
        
        if len(order) > 0
            order = order + " -> "
        order = order + get(names, u)
        
        v = 0
        while v < n
            w = get(matrix, u * n + v)
            if w > 0
                if get(visited, v) == 0
                    list_set(visited, v, 1)
                    push(q, v)
            v = v + 1
    return order

fn dfs_helper matrix n u visited names out_order
    list_set(visited, u, 1)
    if len(get(out_order, 0)) > 0
        list_set(out_order, 0, get(out_order, 0) + " -> ")
    list_set(out_order, 0, get(out_order, 0) + get(names, u))
    
    v = 0
    while v < n
        w = get(matrix, u * n + v)
        if w > 0
            if get(visited, v) == 0
                dfs_helper(matrix, n, v, visited, names, out_order)
        v = v + 1
    return 0

fn dfs matrix n start_node names
    visited = make_zero_list(n)
    out_order = list()
    push(out_order, "")
    dfs_helper(matrix, n, start_node, visited, names, out_order)
    return get(out_order, 0)

fn dijkstra matrix n start_node names
    inf = 999999
    dist = list()
    i = 0
    while i < n
        push(dist, inf)
        i = i + 1
    list_set(dist, start_node, 0)
    
    visited = make_zero_list(n)
    
    count = 0
    while count < n
        min_d = inf
        u = -1
        i = 0
        while i < n
            if get(visited, i) == 0 and get(dist, i) < min_d
                min_d = get(dist, i)
                u = i
            i = i + 1
            
        if u == -1
            count = n
        else
            list_set(visited, u, 1)
            v = 0
            while v < n
                w = get(matrix, u * n + v)
                if w > 0 and get(visited, v) == 0
                    new_d = get(dist, u) + w
                    if new_d < get(dist, v)
                        list_set(dist, v, new_d)
                v = v + 1
            count = count + 1
            
    say "Dijkstra Shortest Paths from " + get(names, start_node) + ":"
    i = 0
    while i < n
        d = get(dist, i)
        d_str = str(d)
        if d >= inf
            d_str = "INF"
        say "  To " + get(names, i) + ": " + d_str + " km"
        i = i + 1
    return 0

fn main
    say "=== Lipi Graph Algorithms ==="
    say ""
    
    names = list()
    push(names, "Dhaka")
    push(names, "Chittagong")
    push(names, "Sylhet")
    push(names, "Rajshahi")
    push(names, "Khulna")
    
    n = 5
    matrix = make_zero_list(25)
    
    // Distances
    list_set(matrix, 0 * n + 1, 248)
    list_set(matrix, 1 * n + 0, 248)
    
    list_set(matrix, 0 * n + 2, 240)
    list_set(matrix, 2 * n + 0, 240)
    
    list_set(matrix, 0 * n + 3, 245)
    list_set(matrix, 3 * n + 0, 245)
    
    list_set(matrix, 0 * n + 4, 180)
    list_set(matrix, 4 * n + 0, 180)
    
    list_set(matrix, 1 * n + 2, 380)
    list_set(matrix, 2 * n + 1, 380)
    
    list_set(matrix, 3 * n + 4, 270)
    list_set(matrix, 4 * n + 3, 270)
    
    say "Cities: Dhaka, Chittagong, Sylhet, Rajshahi, Khulna"
    say ""
    
    bfs_order = bfs(matrix, n, 0, names)
    say "BFS Traversal from Dhaka:"
    say "  " + bfs_order
    say ""
    
    dfs_order = dfs(matrix, n, 0, names)
    say "DFS Traversal from Dhaka:"
    say "  " + dfs_order
    say ""
    
    dijkstra(matrix, n, 0, names)
    return 0

main()
