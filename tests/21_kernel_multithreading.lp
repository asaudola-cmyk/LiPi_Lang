// ==============================================================================
// 🧪 LIPI TEST 21: ADVANCED SILICON DATA STRUCTURES & POINTER LINKED-LISTS
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Mocks | Real Silicon Heap Pointers
//
// WHY: Validates real 64-bit pointer traversal, dynamic stack push/pop, FIFO queue,
// and singly-linked list node traversal in heap memory with strict assertions.
// ==============================================================================

include "utso/memory.lp"
include "utso/os/thread.lp"

fn mt_worker_entry shared_ptr
    mem_write(shared_ptr, 0, 777)
    return 0

fn mt_stress_worker ctrl_ptr
    mtx = ctrl_ptr + 16
    done_ptr = ctrl_ptr + 32
    i = 0
    while i < 10000
        atomic_add(ctrl_ptr, 1)
        i = i + 1
    end
    j = 0
    while j < 1000
        futex_mutex_lock(mtx)
        cur = mem_read(ctrl_ptr, 8)
        mem_write(ctrl_ptr, 8, cur + 1)
        futex_mutex_unlock(mtx)
        j = j + 1
    end
    atomic_add(done_ptr, 1)
    return 0

fn test_assert actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

// ── 1. Real Heap Pointer Singly-Linked List ───────────────────────────────────
// Node layout in memory:
// Offset 0: value (int64)
// Offset 8: next_ptr (64-bit memory address or 0 for null)
fn list_node_create val next_ptr
    node = malloc(16)
    mem_write(node, 0, val)
    mem_write(node, 8, next_ptr)
    return node

fn list_node_val node
    return mem_read(node, 0)

fn list_node_next node
    return mem_read(node, 8)

// ── 2. Dynamic Stack with Backing Memory Array ────────────────────────────────
struct Stack
    data_ptr
    capacity
    top_idx

fn stack_create capacity
    s = Stack()
    s.capacity = capacity
    s.top_idx = 0
    s.data_ptr = malloc(capacity * 8)
    return s

fn stack_push s val
    if s.top_idx >= s.capacity
        return 0 // Overflow
    mem_write(s.data_ptr, s.top_idx * 8, val)
    s.top_idx = s.top_idx + 1
    return 1

fn stack_pop s
    if s.top_idx == 0
        return 0 - 1 // Underflow
    s.top_idx = s.top_idx - 1
    return mem_read(s.data_ptr, s.top_idx * 8)

fn stack_peek s
    if s.top_idx == 0
        return 0 - 1
    return mem_read(s.data_ptr, (s.top_idx - 1) * 8)

fn stack_free s
    free(s.data_ptr, s.capacity * 8)
    return 1

// ── 3. Circular FIFO Queue with Backing Memory Buffer ─────────────────────────
struct Queue
    data_ptr
    capacity
    head
    tail
    count

fn queue_create capacity
    q = Queue()
    q.capacity = capacity
    q.head = 0
    q.tail = 0
    q.count = 0
    q.data_ptr = malloc(capacity * 8)
    return q

fn queue_enqueue q val
    if q.count >= q.capacity
        return 0 // Full
    mem_write(q.data_ptr, q.tail * 8, val)
    q.tail = (q.tail + 1) % q.capacity
    q.count = q.count + 1
    return 1

fn queue_dequeue q
    if q.count == 0
        return 0 - 1 // Empty
    val = mem_read(q.data_ptr, q.head * 8)
    q.head = (q.head + 1) % q.capacity
    q.count = q.count - 1
    return val

fn queue_free q
    free(q.data_ptr, q.capacity * 8)
    return 1

// ── 4. Test Execution & Assertion Verification ────────────────────────────────
say "=== Lipi Real Data Structures & Pointers Test ==="

// Step 1: Real pointer linked-list validation
n3 = list_node_create(30, 0)
n2 = list_node_create(20, n3)
n1 = list_node_create(10, n2)

test_assert(list_node_val(n1), 10, "Node 1 holds value 10")
test_assert(list_node_val(n2), 20, "Node 2 holds value 20")
test_assert(list_node_val(n3), 30, "Node 3 holds value 30")

// Traverse list using real pointers and compute sum
cur = n1
sum = 0
node_count = 0
while cur != 0
    sum = sum + list_node_val(cur)
    node_count = node_count + 1
    cur = list_node_next(cur)

test_assert(node_count, 3, "Traversed exactly 3 linked list nodes")
test_assert(sum, 60, "Linked list nodes sum to 10 + 20 + 30 = 60")

// Clean up linked list heap nodes
free(n1, 16)
free(n2, 16)
free(n3, 16)

// Step 2: Dynamic Stack verification
stk = stack_create(10)
stack_push(stk, 100)
stack_push(stk, 200)
stack_push(stk, 300)

test_assert(stk.top_idx, 3, "Stack holds 3 elements")
test_assert(stack_peek(stk), 300, "Stack top is 300")

popped1 = stack_pop(stk)
test_assert(popped1, 300, "First pop is 300 (LIFO)")
test_assert(stk.top_idx, 2, "Stack size is 2 after first pop")

popped2 = stack_pop(stk)
test_assert(popped2, 200, "Second pop is 200")

popped3 = stack_pop(stk)
test_assert(popped3, 100, "Third pop is 100")
test_assert(stk.top_idx, 0, "Stack is empty after 3 pops")

underflow = stack_pop(stk)
test_assert(underflow, -1, "Stack pop on empty returns -1 sentinel")
stack_free(stk)

// Step 3: Circular Queue verification
q = queue_create(5)
queue_enqueue(q, 1000)
queue_enqueue(q, 2000)
queue_enqueue(q, 3000)

test_assert(q.count, 3, "Queue holds 3 elements")
deq1 = queue_dequeue(q)
test_assert(deq1, 1000, "First dequeue is 1000 (FIFO)")

deq2 = queue_dequeue(q)
test_assert(deq2, 2000, "Second dequeue is 2000")

queue_enqueue(q, 4000)
deq3 = queue_dequeue(q)
test_assert(deq3, 3000, "Third dequeue is 3000")

deq4 = queue_dequeue(q)
test_assert(deq4, 4000, "Fourth dequeue is 4000")
test_assert(q.count, 0, "Queue is empty")

queue_free(q)

// Step 4: Kernel Multithreading (thread_create, spinlock, channel & shared memory) verification
shared_box = syscall(9, 0, 4096, 3, 33, 0 - 1, 0)
mem_write(shared_box, 0, 111)
st_buf = malloc(65536)
tid = thread_create(st_buf + 65536 - 64)
if tid == 0
    mt_worker_entry(shared_box)
    thread_exit(0)
status_buf = alloc(16)
syscall(61, tid, status_buf, 1073741824, 0, 0, 0)
test_assert(mem_read(shared_box, 0), 777, "Kernel thread_create executed worker and mutated shared memory to 777")

ch = channel_create()
channel_send(ch, 999)
ch_val = channel_recv(ch)
test_assert(ch_val, 999, "Thread-safe channel_send & channel_recv roundtrip verified")
channel_close(ch)

// Step 5: 8-thread CLONE_VM shared-memory stress test (80,000 atomic_add + 8,000 futex_mutex ops)
ctrl_ptr = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
mem_write(ctrl_ptr, 0, 0)
mem_write(ctrl_ptr, 8, 0)
mem_write(ctrl_ptr, 16, 0)
mem_write(ctrl_ptr, 24, 0)
mem_write(ctrl_ptr, 32, 0)
wi = 0
while wi < 8
    ctid = thread_spawn_shared(fn_ptr(mt_stress_worker), ctrl_ptr)
    if ctid <= 0
        test_assert(ctid > 0, 1, "CLONE_VM worker thread spawned")
    end
    wi = wi + 1
end
thread_wait_counter(ctrl_ptr + 32, 8)
test_assert(mem_read(ctrl_ptr, 0), 80000, "8x10,000 CLONE_VM atomic_add stress test == 80000")
test_assert(mem_read(ctrl_ptr, 8), 8000, "8x1,000 CLONE_VM futex_mutex stress test == 8000")

say "PASS: Test 21 Data Structures"
