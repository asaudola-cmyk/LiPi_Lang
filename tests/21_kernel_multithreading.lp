// Test 21: Data Structures — Lipi 2.0
// Demonstrates: stack, queue, linked-list patterns via structs

struct Node
    value
    next_val   // stores next node's value (simplified, no real pointers)

struct Stack
    top
    size

struct Queue
    head_val
    size

// Stack: push — update top and size
fn stack_push s val
    s.top = val
    s.size = s.size + 1
    return s

fn stack_top s
    return s.top

fn stack_empty s
    if s.size == 0
        return 1
    return 0

// Queue: enqueue — update head_val on first insert
fn queue_enqueue q val
    if q.size == 0
        q.head_val = val
    q.size = q.size + 1
    return q

fn queue_front q
    return q.head_val

// Linked list node creation
fn make_node val
    n = Node()
    n.value = val
    n.next_val = -1   // -1 = null sentinel
    return n

// Stack demo — note: create struct inline, NOT via no-arg fn
say "=== Stack ==="
s = Stack()
s.top = 0
s.size = 0

// Push via paren syntax (struct, value)
s = stack_push(s, 10)
s = stack_push(s, 20)
s = stack_push(s, 30)
say "Top of stack:"
say stack_top s
say "Stack size:"
say s.size
say "Is empty:"
say stack_empty s

// Queue demo
say "=== Queue ==="
q = Queue()
q.head_val = 0
q.size = 0
q = queue_enqueue(q, 100)
q = queue_enqueue(q, 200)
say "Front of queue:"
say queue_front q
say "Queue size:"
say q.size

// Linked list demo
say "=== Linked List Nodes ==="
n1 = make_node 1
n2 = make_node 2
n3 = make_node 3
n1.next_val = n2.value
n2.next_val = n3.value
say n1.value
say n1.next_val
say n2.value
say n2.next_val
say n3.value

say "PASS: Test 21 Data Structures"
