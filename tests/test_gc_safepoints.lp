// ==============================================================================
// 👑 LIPI FIRST 1.0.0 REGRESSION TEST: GC SAFEPOINTS & MEMORY WATERMARKS
// ⚡ Tests gc_collect, lipi_gc_collect, arena marks, and slab recycling
// ==============================================================================

fn main()
    // Test 1: Calling gc_collect and lipi_gc_collect builtins
    let gc_res1 = gc_collect()
    say "gc_collect res:"
    say gc_res1

    let gc_res2 = lipi_gc_collect()
    say "lipi_gc_collect res:"
    say gc_res2

    // Test 2: Allocations and deallocations across slab sizes
    let p1 = alloc(64)
    if p1 <= 0
        say "FAIL: alloc 64 failed"
        return 1
    end
    free(p1)

    let p2 = alloc(256)
    if p2 <= 0
        say "FAIL: alloc 256 failed"
        return 1
    end
    free(p2)

    // Test 3: Arena mark and reset
    let mark = arena_mark()
    let p3 = alloc(128)
    arena_reset(mark)

    say "GC SAFEPOINTS & WATERMARK TESTS PASSED ✔"
    return 0
end
