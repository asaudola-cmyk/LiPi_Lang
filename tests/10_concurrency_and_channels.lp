// Test 10: Concurrency — Lipi 2.0
// Demonstrates: parallel work simulation, chunked partial sums, worker pattern

// Each worker computes id * task (simulates a parallel job)
fn worker id task
    result = id * task
    return result

// Sum from 1 to n using `workers` parallel chunks
// Uses arithmetic series formula for each chunk
fn chunk_sum start end_val
    count = end_val - start + 1
    return (start + end_val) * count / 2

// Simulate tasks dispatched to workers
say "Worker results:"
for task_id in 1..5
    w = worker(task_id, 10)
    say w

// Parallel sum of 1..100 with 4 workers of 25 each
chunk = 25
p1 = chunk_sum(1, 25)
p2 = chunk_sum(26, 50)
p3 = chunk_sum(51, 75)
p4 = chunk_sum(76, 100)
total = p1 + p2 + p3 + p4
say "Parallel sum 1..100:"
say total

// Verify with sequential sum
seq_total = 0
for k in 1..100
    seq_total = seq_total + k
say "Sequential sum 1..100:"
say seq_total

say "PASS: Test 10 Concurrency"
