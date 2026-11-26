// ==============================================================================
// 👑 LIPI UTSO BARE — ZERO-HEAP / NO_STD FORMATTER (utso/bare/fmt.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero GC | Zero Linux Syscalls | Ring-0 Safe
// ==============================================================================

fn bare_fmt_write_cstr dst pos max_len src
    i = 0
    while pos + 1 < max_len
        c = mmio_r8(src + i)
        if c == 0 break end
        mmio_w8(dst + pos, c)
        pos = pos + 1
        i = i + 1
    end
    mmio_w8(dst + pos, 0)
    return pos

fn bare_fmt_write_dec dst pos max_len val
    // Formats signed 64-bit decimal into caller buffer at [dst + pos], returns new pos.
    if pos + 2 >= max_len return pos end
    v = val
    if v < 0
        mmio_w8(dst + pos, 45)
        pos = pos + 1
        v = 0 - v
    end
    if v == 0
        mmio_w8(dst + pos, 48)
        pos = pos + 1
        mmio_w8(dst + pos, 0)
        return pos
    end
    start_p = pos
    while v > 0 and pos + 1 < max_len
        d = v % 10
        mmio_w8(dst + pos, 48 + d)
        pos = pos + 1
        v = v / 10
    end
    // Reverse digits in-place
    lo = start_p
    hi = pos - 1
    while lo < hi
        tmp = mmio_r8(dst + lo)
        mmio_w8(dst + lo, mmio_r8(dst + hi))
        mmio_w8(dst + hi, tmp)
        lo = lo + 1
        hi = hi - 1
    end
    mmio_w8(dst + pos, 0)
    return pos

fn bare_fmt_write_hex dst pos max_len val digits
    // Formats `digits` lowercase/uppercase hex nibbles prefixed by "0x" into [dst + pos].
    if pos + digits + 3 > max_len return pos end
    mmio_w8(dst + pos, 48)
    mmio_w8(dst + pos + 1, 120)
    pos = pos + 2
    i = digits - 1
    while i >= 0
        nib = (val >> (i * 4)) & 15
        ch = 48 + nib
        if nib >= 10 ch = 55 + nib end
        mmio_w8(dst + pos, ch)
        pos = pos + 1
        i = i - 1
    end
    mmio_w8(dst + pos, 0)
    return pos
