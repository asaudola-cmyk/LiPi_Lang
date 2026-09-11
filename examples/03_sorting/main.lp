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
i = 0
while i < len(sample)
    digit = get(sample, i)
    old = get(counts, digit)
    counts = list_set(counts, digit, old + 1)
    i = i + 1

say "Digit frequencies:"
for d in 0..9
    cnt = get(counts, d)
    if cnt > 0
        say "  " + d + " → " + cnt + " times"

// WHY: Formats a list of integers into human-readable bracketed representation "[1, 2, 3]".
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

// WHY: Lomuto partition scheme for pure Lipi quicksort.
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

// WHY: Recursive divide-and-conquer quicksort helper.
fn quicksort_helper lst low high
    if low < high
        p = quicksort_partition(lst, low, high)
        quicksort_helper(lst, low, p - 1)
        quicksort_helper(lst, p + 1, high)
    return lst

// WHY: Sovereign O(n log n) sorting routine in pure Lipi 2.0.
// Sorts list in-place and returns the list.
fn sort lst
    n = len(lst)
    if n <= 1
        return lst
    return quicksort_helper(lst, 0, n - 1)

say ""
say "List sort:"
unsorted = list(9, 3, 7, 1, 5, 2, 8, 4, 6)
say "  Before: " + list_to_str(unsorted)
sorted_items = sort(unsorted)
say "  After:  " + list_to_str(sorted_items)
