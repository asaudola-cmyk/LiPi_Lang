// ==============================================================================
// LIPI WAVE A REGRESSION TEST: Multithreaded STW Auto-GC + Universal Top-Level Globals
// 100% Pure Lipi — Proves:
//   1. 4 concurrent CLONE_VM OS threads allocating 10,000 strings each with Auto-GC enabled (0 SIGSEGV!)
//   2. Both futex_wait (joinable) AND pure spin-wait main thread (SIGURG preemption) under STW GC
//   3. Non-integer top-level globals (G_STR, G_LIST, G_NUM, G_KEEP, G_FLT, G_NODE, lowercase non-int)
//      initialized before main(), forward-referenced, mutated via push/index/field, and surviving GC!
// ==============================================================================

include "utso/os/thread.lp"

struct GNode
    gn_id
    gn_tag
end

// Forward reference test: function declared BEFORE the top-level globals it reads!
fn check_forward_glob
    if FWD_STR != "forward_ok"
        say "FAIL: FWD_STR mismatch: " + str(FWD_STR)
        exit(1)
    end
    if FWD_LIST[1] != 200
        say "FAIL: FWD_LIST[1] mismatch: " + str(FWD_LIST[1])
        exit(1)
    end
    return 1
end

G_STR = "survive_global"
G_LIST = [10, 20, 30]
G_NUM = 777
G_KEEP = []
G_FLT = 3.25
G_NODE = GNode(42, "root_node")
FWD_STR = "forward_ok"
FWD_LIST = [100, 200, 300]
app_banner = "lipi_sovereign"
G_DONE_BOX = 0
G_ERR_BOX = 0

fn check_glob
    // Verify exact user reproducer case + struct + float + lowercase non-int global
    if G_NUM != 777
        say "FAIL: G_NUM != 777"
        exit(1)
    end
    if G_STR != "survive_global"
        say "FAIL: G_STR != survive_global, got: " + str(G_STR)
        exit(1)
    end
    if G_LIST[0] != 10 or G_LIST[2] != 30
        say "FAIL: G_LIST mismatch"
        exit(1)
    end
    if app_banner != "lipi_sovereign"
        say "FAIL: app_banner mismatch"
        exit(1)
    end
    if G_NODE.gn_id != 42 or G_NODE.gn_tag != "root_node"
        say "FAIL: G_NODE mismatch"
        exit(1)
    end
    fsum = G_FLT + 0.75
    if str(fsum) != "4.0" and str(fsum) != "4"
        say "FAIL: G_FLT arithmetic mismatch: " + str(fsum)
        exit(1)
    end
    // Mutate G_KEEP via push and force GC to prove RW globals are scanned as GC roots
    ki = 0
    while ki < 50
        nd = GNode(ki, "keep_" + str(ki))
        push(G_KEEP, nd)
        ki = ki + 1
    end
    gc_collect()
    if len(G_KEEP) != 50
        say "FAIL: G_KEEP len mismatch after GC"
        exit(1)
    end
    last_nd = G_KEEP[49]
    if last_nd.gn_id != 49 or last_nd.gn_tag != "keep_49"
        say "FAIL: G_KEEP[49] corrupted after GC"
        exit(1)
    end
    // Also check local shadowing inside function does not corrupt lowercase global
    app_banner = "local_only"
    if app_banner != "local_only"
        say "FAIL: local shadow failed"
        exit(1)
    end
    return 1
end

fn check_banner_intact
    if app_banner != "lipi_sovereign"
        say "FAIL: local shadow clobbered top-level app_banner!"
        exit(1)
    end
    return 1
end

fn mt_gc_worker tid_arg
    // Allocate 10,000 strings per thread (40,000 total -> triggers multiple Auto-GC cycles!)
    // while retaining a live list of 100 strings on our stack to verify zero premature sweep.
    kept = list()
    i = 0
    while i < 10000
        s = "t" + str(tid_arg) + "_iter_" + str(i) + "_payload_0123456789abcdef"
        if (i % 100) == 0
            push(kept, s)
        end
        i = i + 1
    end
    // Verify all 100 kept strings survived concurrent STW Auto-GC intact!
    if len(kept) != 100
        atomic_add(G_ERR_BOX, 1)
    else
        first_s = kept[0]
        last_s = kept[99]
        if first_s != ("t" + str(tid_arg) + "_iter_0_payload_0123456789abcdef")
            atomic_add(G_ERR_BOX, 1)
        end
        if last_s != ("t" + str(tid_arg) + "_iter_9900_payload_0123456789abcdef")
            atomic_add(G_ERR_BOX, 1)
        end
    end
    atomic_add(G_DONE_BOX, 1)
    return 0
end

fn main
    check_forward_glob()
    check_glob()
    check_banner_intact()

    // Allocate shared atomic counters for multithreaded stress test
    G_DONE_BOX = malloc(16)
    G_ERR_BOX = malloc(16)
    mem_write(G_DONE_BOX, 0, 0)
    mem_write(G_ERR_BOX, 0, 0)

    // Test 1: 4 joinable CLONE_VM threads x 10,000 strings (main blocks in futex_wait!)
    handles = list()
    stacks = list()
    t = 0
    while t < 4
        st_sz = 131072
        st = malloc(st_sz)
        h = malloc(16)
        mem_write(h, 0, 1)
        push(stacks, st)
        push(handles, h)
        tid = thread_spawn_vm_joinable(fn_ptr(mt_gc_worker), t, st + st_sz, h)
        if tid <= 0
            say "FAIL: thread_spawn_vm_joinable failed"
            exit(1)
        end
        t = t + 1
    end

    // Wait via futex_wait while workers trigger multiple STW Auto-GCs!
    t = 0
    while t < 4
        h = handles[t]
        while mem_read(h, 0) != 0
            cur_v = mem_read(h, 0)
            if cur_v != 0
                futex_wait(h, cur_v)
            end
        end
        t = t + 1
    end

    if mem_read(G_DONE_BOX, 0) != 4 or mem_read(G_ERR_BOX, 0) != 0
        say "FAIL: Joinable MT Auto-GC test failed: done=" + str(mem_read(G_DONE_BOX, 0)) + " err=" + str(mem_read(G_ERR_BOX, 0))
        exit(1)
    end

    // Test 2: 4 detached CLONE_VM threads x 8,000 strings while main thread does a PURE SPIN LOOP
    // (zero allocs, zero futex_wait in main -> exercises SIGURG async preemption!)
    mem_write(G_DONE_BOX, 0, 0)
    t = 0
    while t < 4
        st = stacks[t]
        tid2 = thread_spawn_vm(fn_ptr(mt_gc_worker), 10 + t, st + 131072)
        if tid2 <= 0
            say "FAIL: thread_spawn_vm failed"
            exit(1)
        end
        t = t + 1
    end
    // Pure spin wait in main thread — must NEVER deadlock when workers run STW Auto-GC!
    while mem_read(G_DONE_BOX, 0) < 4
        spin_dummy = 1
    end

    if mem_read(G_ERR_BOX, 0) != 0
        say "FAIL: Spin-wait MT Auto-GC test had errors: " + str(mem_read(G_ERR_BOX, 0))
        exit(1)
    end

    // Verify top-level globals STILL intact after 8 threads & ~80,000 allocations + multiple STW GCs!
    if G_STR != "survive_global" or G_LIST[2] != 30 or G_NODE.gn_tag != "root_node" or len(G_KEEP) != 50
        say "FAIL: Top-level globals corrupted after multithreaded STW Auto-GC!"
        exit(1)
    end

    t = 0
    while t < 4
        free(stacks[t], 131072)
        free(handles[t], 16)
        t = t + 1
    end
    free(G_DONE_BOX, 16)
    free(G_ERR_BOX, 16)

    say "PASS: test_wave_a_mt_gc_globals (4x10K joinable + 4x10K spin-preempt STW Auto-GC + universal globals)"
    return 0
end
