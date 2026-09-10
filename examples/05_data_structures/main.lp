// Data Structures — Lipi 2.0 Example
// Stack, Queue, Linked List patterns

// ─── Stack ─────────────────────────────────────────────────
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

fn stack_empty s = s.size == 0

// ─── Queue (circular buffer simulation) ─────────────────────
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
    // Remove first element (O(n) — acceptable for demo)
    new_data = list()
    i = 1
    while i < len(q.data)
        new_data = push(new_data, get(q.data, i))
        i = i + 1
    q.data = new_data
    return item

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
say "── Recursive List Operations ──"
fn list_sum lst n
    // Sum first n elements of lst
    if n <= 0
        return 0
    return get(lst, n - 1) + list_sum(lst, n - 1)

nums = list(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
say "Sum of 1..10 = " + list_sum(nums, 10)
say "Sort: " + sort(nums)
