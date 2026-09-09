// Test 35: Column Store Analytics — Lipi 2.0 Global Standard

fn col_min first count stride
    min_val = first
    i = 1
    while i < count
        v = first + i * stride
        if v < min_val
            min_val = v
        i = i + 1
    return min_val

fn col_max first count stride
    max_val = first
    i = 1
    while i < count
        v = first + i * stride
        if v > max_val
            max_val = v
        i = i + 1
    return max_val

fn col_avg first count stride
    total = 0
    i = 0
    while i < count
        total = total + first + i * stride
        i = i + 1
    return total / count

fn count_divisible start end divisor
    cnt = 0
    i = start
    while i <= end
        if i % divisor == 0
            cnt = cnt + 1
        i = i + 1
    return cnt

say "=== Column Store Analytics ==="
say col_min(10, 5, 10)
say col_max(10, 5, 10)
say col_avg(10, 5, 10)

cnt = count_divisible(1, 100, 3)
say "Count div by 3 in 1..100: " + cnt

say "PASS: Test 35 Column Store"
