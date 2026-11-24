// ==============================================================================
// LIPI CORE LANGUAGE, DETERMINISTIC MEMORY & STRICT TYPE SAFETY REGRESSION TEST
// 100% Pure Lipi | 0% C / libc / Python | Verified with real Linux /proc VmRSS
// ==============================================================================
// Covers:
//   Pillar 1: Deep chained lvalue assignments (o.inn.arr[i], m[i][j], arr[0].inn.arr[0]),
//             value-returning match expressions (indented + braced), multi-line block
//             closures (=> {...}, multi-line end, typed params), scoped region...end
//             and Bengali অঞ্চল...শেষ blocks.
//   Pillar 2: Magic-XOR O(N) string/list GC reclamation, flat RSS across 100k->300k
//             temp strings, and real Linux SYS_madvise(MADV_DONTNEED) physical RAM
//             return to the OS on gc_collect() and region exit.
//   Pillar 3: Zero-collision struct field resolution under --strict-types across
//             inferred struct returns, typed parameters, and struct array literals.
// ==============================================================================

include "utso/core/memory.lp"

struct CoreInner
    arr
    tag
end

struct CoreOuter
    inn
    id
end

struct CollideAlpha
    val
    pad_a
end

struct CollideBeta
    pad_b1
    pad_b2
    val
end

fn make_collide_beta v
    return CollideBeta(11, 22, v)
end

fn read_collide_beta x: CollideBeta
    return x.val
end

fn run_gc_burst()
    // WHY: Function-scoped allocation ensures burst temporaries leave the stack on return,
    // allowing conservative GC tail-shrink to call SYS_madvise(MADV_DONTNEED) on all freed pages.
    bag = list()
    i = 0
    while i < 150000
        push(bag, "burst_payload_item_" + str(i))
        i = i + 1
    end
    return read_vmrss_kb()
end

fn read_vmrss_kb()
    // WHY: Linux /proc/self/status reports lseek(SEEK_END)==0, so read directly with SYS_open/SYS_read.
    fd = syscall(2, "/proc/self/status", 0, 0, 0, 0, 0)
    if fd < 0
        return 0
    end
    buf = malloc(4096)
    n = syscall(0, fd, buf, 4095, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if n <= 0
        free(buf, 4096)
        return 0
    end
    // Scan for "VmRSS:" (86, 109, 82, 83, 83, 58)
    i = 0
    res = 0
    while i + 6 < n
        if mem_read_byte(buf, i) == 86 and mem_read_byte(buf, i + 1) == 109 and mem_read_byte(buf, i + 2) == 82 and mem_read_byte(buf, i + 3) == 83 and mem_read_byte(buf, i + 4) == 83 and mem_read_byte(buf, i + 5) == 58
            j = i + 6
            while j < n and (mem_read_byte(buf, j) == 32 or mem_read_byte(buf, j) == 9)
                j = j + 1
            end
            while j < n
                c = mem_read_byte(buf, j)
                if c >= 48 and c <= 57
                    res = (res * 10) + (c - 48)
                    j = j + 1
                else
                    break
                end
            end
            break
        end
        i = i + 1
    end
    free(buf, 4096)
    return res
end

fn main()
    // ── Pillar 1: Deep Chained Lvalue Assignments ─────────────────────────────
    o = CoreOuter(CoreInner([10, 20, 30], 7), 1)
    o.inn.arr[1] = 99
    o.inn.arr[1] += 11
    if o.inn.arr[1] != 110
        say "FAIL P1.1: o.inn.arr[1]=" + str(o.inn.arr[1])
        return 1
    end

    m = [[1, 2, 3], [4, 5, 6]]
    m[1][2] = 777
    m[1][2] -= 7
    if m[1][2] != 770
        say "FAIL P1.2: m[1][2]=" + str(m[1][2])
        return 1
    end

    arr = [CoreOuter(CoreInner([5, 6], 9), 2)]
    arr[0].inn.arr[0] = 55
    arr[0].inn.arr[0] += 5
    if arr[0].inn.arr[0] != 60
        say "FAIL P1.3: arr[0].inn.arr[0]=" + str(arr[0].inn.arr[0])
        return 1
    end

    // ── Pillar 1: Value-Returning match Expressions (Indented & Braced) ───────
    code = 2
    r1 = match code
        1 => 100
        2 => 200
        _ => 999
    end
    r2 = match code {
        1 => 10
        2 => 6
        _ => 0
    }
    if r1 != 200 or r2 != 6
        say "FAIL P1.4: match r1=" + str(r1) + " r2=" + str(r2)
        return 1
    end

    // ── Pillar 1: Multi-Line Block Closures & Typed Lambda Params ─────────────
    cb1 = fn(a, b) => {
        t = a + b
        return t * 5
    }
    cb2 = fn(a: int, b: int)
        t = a * 2
        return t + b
    end
    cb3 = |a: int, b: int| => {
        return (a * b) + 1
    }
    if cb1(3, 4) != 35 or cb2(10, 7) != 27 or cb3(6, 7) != 43
        say "FAIL P1.5: closure mismatch"
        return 1
    end

    // ── Pillar 1: Scoped Deterministic Memory Regions (EN & BN) ───────────────
    mk0 = arena_mark()
    region
        ri = 0
        while ri < 1000
            tmp_s = "reg_" + str(ri)
            ri = ri + 1
        end
    end
    mk1 = arena_mark()
    অঞ্চল
        bi = 0
        while bi < 1000
            tmp_bn = "bn_" + str(bi)
            bi = bi + 1
        end
    শেষ
    mk2 = arena_mark()
    if mk1 != mk0 or mk2 != mk0
        say "FAIL P1.6: region arena_mark drift " + str(mk0) + " -> " + str(mk1) + " -> " + str(mk2)
        return 1
    end
    say "Pillar 1 (Chained Lvalues + Match Expr + Block Closures + Region): PASS"

    // ── Pillar 3: Zero-Collision Struct Layout Safety ─────────────────────────
    a_obj = CollideAlpha(123, 999)
    b_obj = make_collide_beta(777)
    b_via_param = read_collide_beta(b_obj)
    b_arr = [CollideBeta(1, 2, 111), CollideBeta(3, 4, 222)]
    if a_obj.val != 123 or b_obj.val != 777 or b_via_param != 777 or b_arr[0].val != 111 or b_arr[1].val != 222
        say "FAIL P3: struct field collision detected"
        return 3
    end
    say "Pillar 3 (Zero-Collision Struct Inference & Array Element Types): PASS"

    // ── Pillar 2: Real String GC Reclamation & OS Physical Page Return ────────
    // Scenario A: 100k temporary strings in a plain loop (NO region, NO manual free)
    i = 0
    while i < 100000
        s_tmp = "lipi_gc_" + str(i)
        i = i + 1
    end
    gc_collect()
    rss_100k = read_vmrss_kb()
    live_100k = gc_live_bytes()

    // Scenario B: 300k temporary strings (3x more work — RSS must stay flat!)
    i = 0
    while i < 300000
        s_tmp2 = "lipi_gc2_" + str(i)
        i = i + 1
    end
    gc_collect()
    rss_300k = read_vmrss_kb()

    if rss_100k > 4096 or rss_300k > 4096
        say "FAIL P2.1: string loop leaked RSS 100k=" + str(rss_100k) + "KB 300k=" + str(rss_300k) + "KB"
        return 2
    end

    // Scenario C: 150k live burst in function -> return -> gc_collect() -> physical RAM returns to OS!
    rss_peak_gc = run_gc_burst()
    reclaimed = gc_collect()
    rss_after_gc = read_vmrss_kb()
    if rss_peak_gc < 8000 or reclaimed < 10000000 or rss_after_gc > (rss_peak_gc / 2)
        say "FAIL P2.2: GC did not return physical pages peak=" + str(rss_peak_gc) + "KB after=" + str(rss_after_gc) + "KB reclaimed=" + str(reclaimed)
        return 2
    end

    // Scenario D: 120k burst inside region ... end -> instant OS page return, zero GC pause!
    rss_peak_reg = 0
    region
        rbag = list()
        i = 0
        while i < 120000
            push(rbag, "region_payload_item_" + str(i))
            i = i + 1
        end
        rss_peak_reg = read_vmrss_kb()
    end
    rss_after_reg = read_vmrss_kb()
    if rss_peak_reg < 8000 or rss_after_reg > (rss_peak_reg / 2)
        say "FAIL P2.3: region did not return physical pages peak=" + str(rss_peak_reg) + "KB after=" + str(rss_after_reg) + "KB"
        return 2
    end

    // Scenario E: GC runtime tuning hooks
    gc_set_auto(0)
    gc_set_threshold(1048576)
    gc_set_auto(1)
    gc_set_threshold(524288)

    say "Pillar 2 (GC + MADV_DONTNEED OS Return): 100k=" + str(rss_100k) + "KB 300k=" + str(rss_300k) + "KB live=" + str(live_100k) + "B gc_burst=" + str(rss_peak_gc) + "KB->" + str(rss_after_gc) + "KB reg_burst=" + str(rss_peak_reg) + "KB->" + str(rss_after_reg) + "KB PASS"
    say "CORE LANGUAGE, MEMORY & STRICT TYPE SAFETY REGRESSION PASSED!"
    return 0
end
