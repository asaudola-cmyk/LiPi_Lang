// ==============================================================================
// 👑 LIPI UTSO — FREESTANDING ZERO-HEAP CORE LIBRARY (utso/bare/core.lp)
// ⚡ 100% Pure Lipi | 0% Linux Syscalls | 0% sys_mmap | 0% GC | Ring-0 Safe
// ==============================================================================
//
// WHY THIS MODULE:
// Provides deterministic no_std / bare-metal primitives for OS kernels, hypervisors,
// UEFI bootloaders, and embedded firmware: raw memory operations, atomic spinlocks,
// lock-free byte ring buffers, bump/bitmap physical page-frame allocators, and
// zero-allocation decimal/hex formatters writing directly into caller buffers.
// ==============================================================================

fn bare_memset dst val count
    i = 0
    while i < count
        mem_byte_write(dst, i, val)
        i = i + 1
    end
    return dst

fn bare_memcpy dst src count
    i = 0
    while i < count
        b = mem_byte_read(src, i)
        mem_byte_write(dst, i, b)
        i = i + 1
    end
    return dst

fn bare_memcmp a b count
    i = 0
    while i < count
        ba = mem_byte_read(a, i)
        bb = mem_byte_read(b, i)
        if ba != bb
            return ba - bb
        end
        i = i + 1
    end
    return 0

fn bare_strlen ptr
    n = 0
    while mem_byte_read(ptr, n) != 0
        n = n + 1
    end
    return n

// ── Hardware Atomic Spinlock (0% Linux futex, pure LOCK CMPXCHG + PAUSE) ──────

fn bare_spin_lock lock_ptr
    while atomic_cas64(lock_ptr, 0, 1) == 0
        cpu_pause()
    end
    fence_full()
    return 1

fn bare_spin_unlock lock_ptr
    fence_full()
    mmio_w64(lock_ptr, 0)
    return 0

// ── Static Fixed-Memory Bump Allocator (state stored in 24B caller struct/buf) ─
// Layout at state_ptr: [0]=cur_ptr, [8]=end_ptr, [16]=alloc_count

fn bare_bump_init state_ptr base_addr size_bytes
    mmio_w64(state_ptr, base_addr)
    mmio_w64(state_ptr + 8, base_addr + size_bytes)
    mmio_w64(state_ptr + 16, 0)
    return 1

fn bare_bump_alloc state_ptr req_bytes align_bytes
    cur = mmio_r64(state_ptr)
    lim = mmio_r64(state_ptr + 8)
    al = align_bytes
    if al < 8 al = 8 end
    rem = cur % al
    if rem != 0
        cur = cur + (al - rem)
    end
    nxt = cur + req_bytes
    if nxt > lim
        return 0
    end
    mmio_w64(state_ptr, nxt)
    cnt = mmio_r64(state_ptr + 16)
    mmio_w64(state_ptr + 16, cnt + 1)
    return cur

// ── Bitmap Physical Page-Frame Allocator (4KB frames, zero heap) ──────────────

fn bare_pmm_init bitmap_ptr total_frames
    n_bytes = (total_frames + 7) / 8
    bare_memset(bitmap_ptr, 0, n_bytes)
    return total_frames

fn bare_pmm_mark_used bitmap_ptr frame_idx
    byte_i = frame_idx >> 3
    bit_m = 1 << (frame_idx & 7)
    cur = mem_byte_read(bitmap_ptr, byte_i)
    mem_byte_write(bitmap_ptr, byte_i, cur | bit_m)
    return 1

fn bare_pmm_mark_free bitmap_ptr frame_idx
    byte_i = frame_idx >> 3
    bit_m = 1 << (frame_idx & 7)
    cur = mem_byte_read(bitmap_ptr, byte_i)
    mem_byte_write(bitmap_ptr, byte_i, cur & (255 ^ bit_m))
    return 1

fn bare_pmm_alloc_frame bitmap_ptr total_frames phys_base
    fi = 0
    while fi < total_frames
        byte_i = fi >> 3
        bit_m = 1 << (fi & 7)
        if (mem_byte_read(bitmap_ptr, byte_i) & bit_m) == 0
            mem_byte_write(bitmap_ptr, byte_i, mem_byte_read(bitmap_ptr, byte_i) | bit_m)
            return phys_base + (fi * 4096)
        end
        fi = fi + 1
    end
    return 0

// ── Zero-Allocation Integer/Hex Formatters into Caller Buffer ─────────────────

fn bare_fmt_u64 out_buf val
    if val == 0
        mem_byte_write(out_buf, 0, 48)
        mem_byte_write(out_buf, 1, 0)
        return 1
    end
    v = val
    n = 0
    while v > 0
        d = v % 10
        mem_byte_write(out_buf, n, 48 + d)
        v = v / 10
        n = n + 1
    end
    // Reverse in-place
    lo = 0
    hi = n - 1
    while lo < hi
        a = mem_byte_read(out_buf, lo)
        b = mem_byte_read(out_buf, hi)
        mem_byte_write(out_buf, lo, b)
        mem_byte_write(out_buf, hi, a)
        lo = lo + 1
        hi = hi - 1
    end
    mem_byte_write(out_buf, n, 0)
    return n

fn bare_fmt_hex64 out_buf val
    mem_byte_write(out_buf, 0, 48) // '0'
    mem_byte_write(out_buf, 1, 120) // 'x'
    i = 0
    while i < 16
        shift = (15 - i) * 4
        nib = (val >> shift) & 15
        ch = 48 + nib
        if nib >= 10
            ch = 55 + nib // 'A'..'F'
        end
        mem_byte_write(out_buf, 2 + i, ch)
        i = i + 1
    end
    mem_byte_write(out_buf, 18, 0)
    return 18
