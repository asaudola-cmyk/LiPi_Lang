// ==============================================================================
// 👑 LIPI UTSO BARE — ZERO-HEAP / NO_STD STRING UTILITIES (utso/bare/string.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero GC | Zero Linux Syscalls | Ring-0 Safe
// ==============================================================================

fn bare_str_len ptr
    i = 0
    while mmio_r8(ptr + i) != 0
        i = i + 1
    end
    return i

fn bare_str_cmp a b
    i = 0
    while 1
        ca = mmio_r8(a + i)
        cb = mmio_r8(b + i)
        if ca != cb return ca - cb end
        if ca == 0 return 0 end
        i = i + 1
    end
    return 0

fn bare_str_ncmp a b max_n
    i = 0
    while i < max_n
        ca = mmio_r8(a + i)
        cb = mmio_r8(b + i)
        if ca != cb return ca - cb end
        if ca == 0 return 0 end
        i = i + 1
    end
    return 0

fn bare_str_copy dst src max_bytes
    if max_bytes <= 0 return 0 end
    i = 0
    while i + 1 < max_bytes
        c = mmio_r8(src + i)
        mmio_w8(dst + i, c)
        if c == 0 return i end
        i = i + 1
    end
    mmio_w8(dst + i, 0)
    return i

fn bare_str_find_byte ptr ch max_len
    i = 0
    while i < max_len
        c = mmio_r8(ptr + i)
        if c == ch return i end
        if c == 0 return 0 - 1 end
        i = i + 1
    end
    return 0 - 1

fn bare_str_parse_u64 ptr
    acc = 0
    i = 0
    while 1
        c = mmio_r8(ptr + i)
        if c < 48 or c > 57 break end
        acc = (acc * 10) + (c - 48)
        i = i + 1
    end
    return acc
