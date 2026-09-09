// Test 33: Shared Memory Ring Buffer — Lipi 2.0 Global Standard

struct RingBuffer
    head
    tail
    size
    capacity

fn ring_new cap
    r = RingBuffer()
    r.head = 0
    r.tail = 0
    r.size = 0
    r.capacity = cap
    return r

fn ring_is_full rb
    return rb.size == rb.capacity

fn ring_is_empty rb
    return rb.size == 0

fn ring_push rb val
    full = ring_is_full(rb)
    if full == 1
        say "Buffer full!"
        return 0
    rb.tail = (rb.tail + 1) % rb.capacity
    rb.size = rb.size + 1
    say "Push " + val + " tail=" + rb.tail + " size=" + rb.size
    return 1

fn ring_pop rb
    empty = ring_is_empty(rb)
    if empty == 1
        say "Buffer empty!"
        return -1
    rb.head = (rb.head + 1) % rb.capacity
    rb.size = rb.size - 1
    say "Pop head=" + rb.head + " size=" + rb.size
    return rb.head

say "=== Ring Buffer IPC ==="
buf = ring_new(4)

ring_push(buf, 10)
ring_push(buf, 20)
ring_push(buf, 30)
ring_push(buf, 40)
ring_push(buf, 50)

ring_pop(buf)
ring_pop(buf)
ring_push(buf, 50)
ring_push(buf, 60)

say "Final size: " + buf.size
say "PASS: Test 33 Shared Memory"
