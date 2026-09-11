// Data Structures — Lipi 2.0 Example
// Demonstrates: Stack, Queue, Binary Search Tree, Set, Map, and Pure Sorting

// ─── 1. Stack (LIFO) ──────────────────────────────────────────
struct Stack
    data    // list
    size

fn stack_new
    s = Stack()
    s.data = list()
    s.size = 0
    return s

fn stack_push s item
    s.data = push(s.data, item)
    s.size = s.size + 1

fn stack_pop s
    if s.size == 0
        say "Stack underflow!"
        return null
    s.size = s.size - 1
    return pop(s.data)

fn stack_peek s
    if s.size == 0
        return null
    return get(s.data, s.size - 1)

fn stack_empty s
    return s.size == 0

// ─── 2. Queue (FIFO) ──────────────────────────────────────────
struct Queue
    data
    size

fn queue_new
    q = Queue()
    q.data = list()
    q.size = 0
    return q

fn enqueue q item
    q.data = push(q.data, item)
    q.size = q.size + 1

fn dequeue q
    if q.size == 0
        say "Queue empty!"
        return null
    q.size = q.size - 1
    item = get(q.data, 0)
    new_data = list()
    i = 1
    while i < len(q.data)
        new_data = push(new_data, get(q.data, i))
        i = i + 1
    q.data = new_data
    return item

fn queue_empty q
    return q.size == 0

// ─── 3. Binary Search Tree (BST) ──────────────────────────────
struct TreeNode
    val
    left
    right

fn tree_node_new val
    node = TreeNode()
    node.val = val
    node.left = 0
    node.right = 0
    return node

// WHY: Inserts val into binary search tree preserving BST invariants (left < node < right).
fn tree_insert root val
    if root == 0
        return tree_node_new(val)
    if val < root.val
        root.left = tree_insert(root.left, val)
    elif val > root.val
        root.right = tree_insert(root.right, val)
    return root

// WHY: Searches for val in BST in O(log n) average time. Returns 1 if present, 0 if absent.
fn tree_contains root val
    if root == 0
        return 0
    if val == root.val
        return 1
    elif val < root.val
        return tree_contains(root.left, val)
    else
        return tree_contains(root.right, val)

// WHY: Counts total nodes in subtree.
fn tree_size root
    if root == 0
        return 0
    return 1 + tree_size(root.left) + tree_size(root.right)

// ─── 4. Set (Unique Elements Collection) ──────────────────────
struct Set
    items
    size

fn set_new
    s = Set()
    s.items = list()
    s.size = 0
    return s

fn set_contains s item
    i = 0
    while i < s.size
        if get(s.items, i) == item
            return 1
        i = i + 1
    return 0

fn set_add s item
    if set_contains(s, item) == 1
        return s
    s.items = push(s.items, item)
    s.size = s.size + 1
    return s

// ─── 5. Map (Key-Value Store) ─────────────────────────────────
struct Map
    keys
    values
    size

fn map_new
    m = Map()
    m.keys = list()
    m.values = list()
    m.size = 0
    return m

fn map_has m key
    i = 0
    while i < m.size
        if get(m.keys, i) == key
            return 1
        i = i + 1
    return 0

fn map_put m key val
    i = 0
    while i < m.size
        if get(m.keys, i) == key
            list_set(m.values, i, val)
            return m
        i = i + 1
    m.keys = push(m.keys, key)
    m.values = push(m.values, val)
    m.size = m.size + 1
    return m

fn map_get m key default_val
    i = 0
    while i < m.size
        if get(m.keys, i) == key
            return get(m.values, i)
        i = i + 1
    return default_val

// ─── 6. List Operations & Pure Quicksort ───────────────────────
fn list_to_str lst
    res = "["
    idx = 0
    n = len(lst)
    while idx < n
        res = res + str(get(lst, idx))
        if idx < n - 1
            res = res + ", "
        idx = idx + 1
    return res + "]"

fn quicksort_partition lst low high
    pivot = get(lst, high)
    pi = low - 1
    pj = low
    while pj < high
        if get(lst, pj) <= pivot
            pi = pi + 1
            tmp = get(lst, pi)
            list_set(lst, pi, get(lst, pj))
            list_set(lst, pj, tmp)
        pj = pj + 1
    tmp = get(lst, pi + 1)
    list_set(lst, pi + 1, get(lst, high))
    list_set(lst, high, tmp)
    return pi + 1

fn quicksort_helper lst low high
    if low < high
        p = quicksort_partition(lst, low, high)
        quicksort_helper(lst, low, p - 1)
        quicksort_helper(lst, p + 1, high)
    return lst

// WHY: Pure Lipi in-place quicksort routine replacing undefined compiler label.
fn sort lst
    n = len(lst)
    if n <= 1
        return lst
    return quicksort_helper(lst, 0, n - 1)

fn list_sum lst n
    if n <= 0
        return 0
    return get(lst, n - 1) + list_sum(lst, n - 1)

// ─── Main Execution Demonstration ─────────────────────────────
say "=== Data Structures Demo ==="

say ""
say "── Stack (LIFO) ──"
s = stack_new()
stack_push(s, 10)
stack_push(s, 20)
stack_push(s, 30)
say "Pushed: 10, 20, 30"
say "Peek: " + stack_peek(s)
say "Pop: " + stack_pop(s)
say "Pop: " + stack_pop(s)
say "Size: " + s.size

say ""
say "── Queue (FIFO) ──"
q = queue_new()
enqueue(q, "task_1")
enqueue(q, "task_2")
enqueue(q, "task_3")
say "Enqueued: task_1, task_2, task_3"
say "Dequeue: " + dequeue(q)
say "Dequeue: " + dequeue(q)
say "Size: " + q.size

say ""
say "── Binary Search Tree ──"
root = 0
root = tree_insert(root, 50)
root = tree_insert(root, 30)
root = tree_insert(root, 70)
root = tree_insert(root, 20)
root = tree_insert(root, 40)
say "Inserted: 50, 30, 70, 20, 40"
say "Tree size: " + tree_size(root)
say "Contains 30: " + tree_contains(root, 30)
say "Contains 99: " + tree_contains(root, 99)

say ""
say "── Set (Unique Elements) ──"
my_set = set_new()
set_add(my_set, "Lipi")
set_add(my_set, "Compiler")
set_add(my_set, "Sovereign")
set_add(my_set, "Lipi")
say "Added: Lipi, Compiler, Sovereign, Lipi (duplicate)"
say "Set size: " + my_set.size
say "Contains 'Compiler': " + set_contains(my_set, "Compiler")
say "Contains 'Python':   " + set_contains(my_set, "Python")

say ""
say "── Map (Key-Value) ──"
m = map_new()
map_put(m, "language", "Lipi")
map_put(m, "paradigm", "Sovereign")
map_put(m, "version", "2.0")
say "Map size: " + m.size
say "Get 'language': " + map_get(m, "language", "unknown")
say "Get 'version':  " + map_get(m, "version", "unknown")
say "Has 'paradigm': " + map_has(m, "paradigm")
say "Has 'missing':  " + map_has(m, "missing")

say ""
say "── Recursive List Operations & Sorting ──"
nums = list(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
say "Sum of 1..10 = " + list_sum(nums, 10)
unsorted = list(64, 25, 12, 22, 11)
say "Unsorted: " + list_to_str(unsorted)
sorted_list = sort(unsorted)
say "Sorted:   " + list_to_str(sorted_list)

