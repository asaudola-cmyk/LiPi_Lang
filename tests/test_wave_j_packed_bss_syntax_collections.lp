// ==============================================================================
// Wave J Test: Exact Hardware Data Layout (@packed, @align, [N]T, @bss, sizeof,
// offsetof), Braced Functions `{ ... }`, and Honest O(1) collections.lp pop()
// ==============================================================================

import "utso/core/collections.lp"

@packed
struct HwDesc
    d_magic: u32
    d_flags: u16
    d_ver: u8
    d_delta: i8
    d_addr: u64
end

struct InlineArrPacket
    p_id: u32
    p_bytes: [16]u8
    p_tail: u32
end

@bss @align(4096)
g_dma_ring: [64]u32

@bss
g_static_desc: HwDesc

fn braced_add(a, b) { return a + b }

fn braced_make_pair(x, y) {
    sum = braced_add(x, y)
    return { first: x, second: y, total: sum }
}

fn main()
    // 1. Exact compile-time sizeof & offsetof (replacing legacy hardcoded 64!)
    if sizeof(u8) != 1 or sizeof(u16) != 2 or sizeof(u32) != 4 or sizeof(u64) != 8
        say "FAIL scalar sizeof"
        exit(1)
    end
    if sizeof([16]u32) != 64
        say "FAIL array sizeof"
        exit(1)
    end
    if sizeof(HwDesc) != 16
        say "FAIL packed sizeof=" + str(sizeof(HwDesc))
        exit(1)
    end
    if offsetof(HwDesc, d_magic) != 0 or offsetof(HwDesc, d_flags) != 4 or offsetof(HwDesc, d_ver) != 6 or offsetof(HwDesc, d_delta) != 7 or offsetof(HwDesc, d_addr) != 8
        say "FAIL packed offsetof"
        exit(1)
    end
    if sizeof(InlineArrPacket) != 24 or offsetof(InlineArrPacket, p_bytes) != 4 or offsetof(InlineArrPacket, p_tail) != 20
        say "FAIL inline array struct layout"
        exit(1)
    end

    // 2. Non-clobbering packed struct writes + signed i8 load
    h = HwDesc()
    h.d_magic = 305419896
    h.d_flags = 4660
    h.d_ver = 200
    h.d_delta = 0 - 5
    h.d_addr = 1048576
    if h.d_magic != 305419896 or h.d_flags != 4660 or h.d_ver != 200 or h.d_delta != (0 - 5) or h.d_addr != 1048576
        say "FAIL packed struct rw"
        exit(1)
    end

    // 3. Static @bss @align(4096) buffer + static @bss struct (zero heap/mmap)
    if (g_dma_ring & 4095) != 0
        say "FAIL bss 4096 alignment"
        exit(1)
    end
    if sizeof(g_dma_ring) != 256
        say "FAIL bss sizeof"
        exit(1)
    end
    g_dma_ring[0] = 100
    g_dma_ring[1] = 200
    g_dma_ring[63] = 333
    if (g_dma_ring[0] + g_dma_ring[1] + g_dma_ring[63]) != 633
        say "FAIL bss array rw"
        exit(1)
    end

    g_static_desc.d_magic = 77777
    g_static_desc.d_flags = 555
    g_static_desc.d_ver = 9
    g_static_desc.d_addr = 4096
    if g_static_desc.d_magic != 77777 or g_static_desc.d_flags != 555 or g_static_desc.d_ver != 9 or g_static_desc.d_addr != 4096
        say "FAIL bss struct rw"
        exit(1)
    end

    // 4. Inline fixed-size array inside struct
    pkt = InlineArrPacket()
    pkt.p_id = 42
    pkt.p_tail = 99
    mmio_w8(pkt.p_bytes + 0, 65)
    mmio_w8(pkt.p_bytes + 15, 90)
    if pkt.p_id != 42 or pkt.p_tail != 99 or pkt.p_bytes[0] != 65 or pkt.p_bytes[15] != 90
        say "FAIL inline array struct rw"
        exit(1)
    end

    // 5. Braced functions `{ ... }` + object literal inside braced function
    pr = braced_make_pair(12, 30)
    if pr.first != 12 or pr.second != 30 or pr.total != 42
        say "FAIL braced fn"
        exit(1)
    end

    // 6. Honest O(1) in-place collections.lp pop() + pop_value() + list_drop_last()
    xs = [10, 20, 30, 40]
    pop(xs)
    if len(xs) != 3 or xs[2] != 30
        say "FAIL in-place pop statement"
        exit(1)
    end
    v = pop_value(xs)
    if v != 30 or len(xs) != 2
        say "FAIL pop_value"
        exit(1)
    end
    xs = pop(xs)
    if len(xs) != 1 or xs[0] != 10
        say "FAIL assigned pop"
        exit(1)
    end
    ys = [1, 2, 3]
    zs = list_drop_last(ys)
    if len(ys) != 3 or len(zs) != 2 or zs[1] != 2
        say "FAIL list_drop_last"
        exit(1)
    end

    say "PASS_WAVE_J_PACKED_BSS_SYNTAX_COLLECTIONS"
    return 0
end
