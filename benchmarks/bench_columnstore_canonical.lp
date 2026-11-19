// ==============================================================================
// 👑 LIPI CANONICAL COLUMNSTORE SCAN: 1,000,000 ROWS
// ⚡ Matches C/Rust/Python benchmark exactly: total += (i % 100) for i = 0..999,999
// ⚡ Reports Checksum, Elapsed Time (ms), and CPU RDTSC Cycles
// ==============================================================================

// Minimal Sovereign Kernel Allocator (sys_mmap / sys_munmap)
// WHY: Avoids bundling 355 lines of standard library, achieving pure 5.7 KB standalone ELF.
fn malloc size
    return syscall(9, 0, size, 3, 34, -1, 0)

fn free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

fn get_nanoseconds ts_buf
    syscall(228, 1, ts_buf, 0, 0, 0, 0)
    sec = mem_read(ts_buf, 0)
    nsec = mem_read(ts_buf, 8)
    return sec * 1000000000 + nsec

fn scan_column count
    total = 0
    i = 0
    while i < count
        total = total + (i % 100)
        i = i + 1
    return total

fn main
    ts_buf = malloc(64)
    t0_ns = get_nanoseconds(ts_buf)
    t0_cyc = cpu_clock()

    res = scan_column(1000000)

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

    say "Lipi ColumnStore 1,000,000 Scan Complete!"
    say "Sum: " + res
    say "Elapsed Time: " + ms_int + "." + frac_str + " ms"
    say "CPU Cycles: " + delta_cyc
    return 0

main()
