// ==============================================================================
// 👑 LIPI BENCHMARK: RECURSIVE FIBONACCI (fib 35)
// ==============================================================================

fn malloc size
    return syscall(9, 0, size, 3, 34, -1, 0)

fn free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

fn get_nanoseconds ts_buf
    syscall(228, 1, ts_buf, 0, 0, 0, 0)
    sec = mem_read(ts_buf, 0)
    nsec = mem_read(ts_buf, 8)
    return sec * 1000000000 + nsec

fn fib n
    if n <= 1
        return n
    return fib(n - 1) + fib(n - 2)

fn main
    ts_buf = malloc(64)
    t0_ns = get_nanoseconds(ts_buf)
    t0_cyc = cpu_clock()

    res = fib(35)

    t1_cyc = cpu_clock()
    t1_ns = get_nanoseconds(ts_buf)
    free(ts_buf, 64)

    delta_ns = t1_ns - t0_ns
    if delta_ns <= 0 delta_ns = 1
    delta_cyc = t1_cyc - t0_cyc

    ms_int = delta_ns / 1000000
    ms_frac = (delta_ns % 1000000) / 10000
    frac_str = "" + ms_frac
    if ms_frac < 10
        frac_str = "0" + ms_frac

    say "Lipi Recursive Fibonacci (35) Complete!"
    say "Sum: " + res
    say "Elapsed Time: " + ms_int + "." + frac_str + " ms"
    say "CPU Cycles: " + delta_cyc
    return 0

main()
