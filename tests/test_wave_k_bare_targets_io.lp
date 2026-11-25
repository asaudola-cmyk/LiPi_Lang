// ==============================================================================
// Wave K Test: Zero-Copy NUL-Safe Binary I/O (file_write_mem/file_append_mem),
// Partial-Write Safe file_append, and utso/bare/core.lp Zero-Heap Primitives
// ==============================================================================

import "utso/core/io.lp"
import "utso/bare/core.lp"

@bss
g_bare_arena: [4096]u8

@bss
g_bare_state: [24]u8

@bss
g_bare_bitmap: [64]u8

@bss
g_bare_lock: [8]u8

@bss
g_fmt_buf: [64]u8

fn main()
    // 1. NUL-safe zero-copy file_write_mem & file_append_mem
    raw = malloc(16)
    mem_byte_write(raw, 0, 76)   // 'L'
    mem_byte_write(raw, 1, 0)    // embedded NUL!
    mem_byte_write(raw, 2, 80)   // 'P'
    mem_byte_write(raw, 3, 255)  // 0xFF
    mem_byte_write(raw, 4, 0)    // embedded NUL!
    mem_byte_write(raw, 5, 42)

    p = "/tmp/lipi_wave_k_bin_io.dat"
    w1 = file_write_mem(p, raw, 6)
    w2 = file_append_mem(p, raw, 6)
    if w1 != 6 or w2 != 6
        say "FAIL file_write_mem/append_mem return counts"
        exit(1)
    end
    data = file_read(p)
    f_sz = len(data)
    if f_sz != 12
        say "FAIL file_read len expected 12 got " + str(f_sz)
        exit(1)
    end
    if mem_byte_read(data, 0) != 76 or mem_byte_read(data, 1) != 0 or mem_byte_read(data, 3) != 255 or mem_byte_read(data, 6) != 76 or mem_byte_read(data, 11) != 42
        say "FAIL NUL-safe binary roundtrip"
        exit(1)
    end

    // 2. Partial-write/EINTR-safe file_append
    tp = "/tmp/lipi_wave_k_text.txt"
    file_write(tp, "alpha\n")
    file_append(tp, "beta\n")
    t_data = file_read(tp)
    if t_data != "alpha\nbeta\n"
        say "FAIL file_append"
        exit(1)
    end

    // 3. utso/bare/core.lp zero-heap primitives
    bare_memset(g_bare_arena, 0, 256)
    bare_bump_init(g_bare_state, g_bare_arena, 4096)
    a1 = bare_bump_alloc(g_bare_state, 32, 16)
    a2 = bare_bump_alloc(g_bare_state, 64, 64)
    if a1 == 0 or a2 == 0 or (a2 & 63) != 0 or a2 <= a1
        say "FAIL bare_bump_alloc"
        exit(1)
    end

    bare_spin_lock(g_bare_lock)
    bare_spin_unlock(g_bare_lock)

    bare_pmm_init(g_bare_bitmap, 64)
    f0 = bare_pmm_alloc_frame(g_bare_bitmap, 64, 1048576)
    f1 = bare_pmm_alloc_frame(g_bare_bitmap, 64, 1048576)
    bare_pmm_mark_free(g_bare_bitmap, 0)
    f2 = bare_pmm_alloc_frame(g_bare_bitmap, 64, 1048576)
    if f0 != 1048576 or f1 != 1052672 or f2 != 1048576
        say "FAIL bare_pmm"
        exit(1)
    end

    bare_fmt_u64(g_fmt_buf, 123456)
    if bare_strlen(g_fmt_buf) != 6 or mem_byte_read(g_fmt_buf, 0) != 49 or mem_byte_read(g_fmt_buf, 5) != 54
        say "FAIL bare_fmt_u64"
        exit(1)
    end

    bare_fmt_hex64(g_fmt_buf, 305419896)
    if bare_strlen(g_fmt_buf) != 18 or mem_byte_read(g_fmt_buf, 0) != 48 or mem_byte_read(g_fmt_buf, 1) != 120 or mem_byte_read(g_fmt_buf, 17) != 56
        say "FAIL bare_fmt_hex64"
        exit(1)
    end

    say "PASS_WAVE_K_BARE_CORE_AND_BINARY_IO"
    return 0
end
