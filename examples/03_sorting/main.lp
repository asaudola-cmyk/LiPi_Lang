// Sorting Algorithms — Lipi 2.0 Example

fn bubble_pass a b c d e
    // One pass of bubble sort — move largest right
    if a > b
        t = a
        a = b
        b = t
    if b > c
        t = b
        b = c
        c = t
    if c > d
        t = c
        c = d
        d = t
    if d > e
        t = d
        d = e
        e = t
    say "  " + a + " " + b + " " + c + " " + d + " " + e

fn binary_search target lo hi
    if lo > hi
        return -1
    mid = (lo + hi) / 2
    if mid == target
        return mid
    elif mid > target
        return binary_search(target, lo, mid - 1)
    else
        return binary_search(target, mid + 1, hi)

say "=== Sorting Algorithms ==="
say ""
say "Bubble Sort — [64, 34, 25, 12, 22]:"
say "  Pass 0: 64 34 25 12 22"
bubble_pass 64 34 25 12 22
bubble_pass 34 25 12 22 64
bubble_pass 25 12 22 34 64
bubble_pass 12 22 25 34 64

say ""
say "Binary Search in [1..20]:"
for t in 1..8
    pos = binary_search(t, 1, 20)
    say "  search " + t + " → pos " + pos

say ""
say "Counting sort on [3,1,4,1,5,9,2,6,5,3,5]:"
counts = list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
sample = list(3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5)
for digit in sample
    old = get(counts, digit)
    counts = list_set(counts, digit, old + 1)

say "Digit frequencies:"
for d in 0..9
    cnt = get(counts, d)
    if cnt > 0
        say "  " + d + " → " + cnt + " times"

say ""
say "List sort builtin:"
unsorted = list(9, 3, 7, 1, 5, 2, 8, 4, 6)
say "  Before: " + unsorted
say "  After:  " + sort(unsorted)
