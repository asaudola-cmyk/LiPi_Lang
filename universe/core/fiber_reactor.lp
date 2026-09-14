// ==============================================================================
// 👑 LIPI UNIVERSE CORE: HIGH-CONCURRENCY FIBER REACTOR (universe/core/fiber_reactor.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Cooperative Green-Thread Event Dispatcher
//
// WHY: Go's goroutines rely on a complex runtime and preemptive signal interruptions.
// In high-performance edge/network servers, cooperative fiber reactors with bounded
// memory footprints provide deterministic latency, zero cache thrashing, and zero GC pauses.
// Each fiber is a lightweight task descriptor multiplexed on user-space scheduling loops.
// ==============================================================================

include "universe/core/memory.lp"
include "universe/core/channel.lp"

// ── Fiber States ─────────────────────────────────────────────────────────────
FIBER_STATE_FREE    = 0
FIBER_STATE_READY   = 1
FIBER_STATE_RUNNING = 2
FIBER_STATE_BLOCKED = 3
FIBER_STATE_DONE    = 4

// ── Fiber Descriptor Layout (64 Bytes per Fiber) ─────────────────────────────
// Offset 0  : Fiber ID (8B)
// Offset 8  : State (8B)
// Offset 16 : Task Type / Code (8B)
// Offset 24 : Argument / Context Payload (8B)
// Offset 32 : Execution Counter / State Variable (8B)
// Offset 40 : Input Channel (8B)
// Offset 48 : Output Channel (8B)
// Offset 56 : Start Timestamp (8B)
FIBER_DESC_SIZE = 64

// ── Reactor Descriptor Layout (32 Bytes) ─────────────────────────────────────
// Offset 0  : Fiber Table Base Address (8B)
// Offset 8  : Max Fibers Capacity (8B)
// Offset 16 : Active Fiber Count (8B)
// Offset 24 : Next Task Monotonic ID (8B)
REACTOR_HDR_SIZE = 32

// ১. নতুন ফাইবার রিয়্যাক্টর তৈরি (Create Fiber Reactor Pool)
fn reactor_new max_fibers
    if max_fibers <= 0
        max_fibers = 128
    
    r = malloc(REACTOR_HDR_SIZE)
    table_size = max_fibers * FIBER_DESC_SIZE
    table = malloc(table_size)
    mem_zero(table, table_size)

    mem_write(r, 0, table)
    mem_write(r, 8, max_fibers)
    mem_write(r, 16, 0) // Active count
    mem_write(r, 24, 1) // Next ID starts at 1

    return r

// ২. নতুন ফাইবার স্পন করা (Spawn Fiber into Reactor Pool)
// Returns assigned Fiber ID, or 0 if pool full
fn reactor_spawn r task_type arg chan_in chan_out
    if r <= 0
        return 0

    table = mem_read(r, 0)
    max_fibers = mem_read(r, 8)
    active = mem_read(r, 16)
    next_id = mem_read(r, 24)

    // Find free slot in fiber table
    slot = 0
    idx = -1
    while slot < max_fibers
        desc_addr = table + (slot * FIBER_DESC_SIZE)
        st = mem_read(desc_addr, 8)
        if st == FIBER_STATE_FREE or st == FIBER_STATE_DONE
            idx = slot
            break
        slot = slot + 1

    if idx < 0
        return 0 // Reactor pool at maximum capacity

    desc = table + (idx * FIBER_DESC_SIZE)
    mem_write(desc, 0, next_id)
    mem_write(desc, 8, FIBER_STATE_READY)
    mem_write(desc, 16, task_type)
    mem_write(desc, 24, arg)
    mem_write(desc, 32, 0) // Step counter
    mem_write(desc, 40, chan_in)
    mem_write(desc, 48, chan_out)
    mem_write(desc, 56, cpu_clock())

    mem_write(r, 16, active + 1)
    mem_write(r, 24, next_id + 1)

    return next_id

// ৩. ফাইবার এক্সিকিউশন স্টেপ (Execute One Fiber Time-Slice)
// Internal dispatcher for cooperative tasks
fn fiber_execute_slice desc
    fid = mem_read(desc, 0)
    st = mem_read(desc, 8)
    task_type = mem_read(desc, 16)
    arg = mem_read(desc, 24)
    counter = mem_read(desc, 32)
    chan_in = mem_read(desc, 40)
    chan_out = mem_read(desc, 48)

    // Task Type 1: Compute Counter Loop (Increment until arg limit)
    if task_type == 1
        new_cnt = counter + 1
        mem_write(desc, 32, new_cnt)
        if new_cnt >= arg
            // Reached target limit, push result to channel if present and finish
            if chan_out > 0
                channel_send(chan_out, new_cnt)
            mem_write(desc, 8, FIBER_STATE_DONE)
            return 1 // Completed
        return 0 // Yielded / more work pending

    // Task Type 2: Channel Consumer / Processor
    elif task_type == 2
        if chan_in > 0
            val = channel_recv(chan_in)
            if val > 0
                // Process received value and write to chan_out
                processed = val * arg
                if chan_out > 0
                    channel_send(chan_out, processed)
                mem_write(desc, 32, counter + 1)
                mem_write(desc, 8, FIBER_STATE_DONE)
                return 1
            else
                // No data yet, yield cooperatively
                mem_write(desc, 8, FIBER_STATE_BLOCKED)
                return 0

    // Task Type 3: Direct Function/Payload Pass-through
    elif task_type == 3
        if chan_out > 0
            channel_send(chan_out, arg)
        mem_write(desc, 32, arg)
        mem_write(desc, 8, FIBER_STATE_DONE)
        return 1

    // Default: Mark complete
    mem_write(desc, 8, FIBER_STATE_DONE)
    return 1

// ৪. রিয়্যাক্টর সিঙ্গেল সাইকেল রান (Single-Pass Dispatcher Step)
// Dispatches all ready and unblocked fibers for one cooperative slice
fn reactor_step r
    if r <= 0
        return 0

    table = mem_read(r, 0)
    max_fibers = mem_read(r, 8)
    completed_in_pass = 0

    slot = 0
    while slot < max_fibers
        desc = table + (slot * FIBER_DESC_SIZE)
        st = mem_read(desc, 8)

        if st == FIBER_STATE_BLOCKED
            // Check if input channel now has data to unblock
            chan_in = mem_read(desc, 40)
            if chan_in > 0
                if channel_len(chan_in) > 0
                    st = FIBER_STATE_READY
                    mem_write(desc, 8, FIBER_STATE_READY)

        if st == FIBER_STATE_READY
            mem_write(desc, 8, FIBER_STATE_RUNNING)
            done = fiber_execute_slice(desc)
            if done == 1
                completed_in_pass = completed_in_pass + 1
            else
                cur_st = mem_read(desc, 8)
                if cur_st == FIBER_STATE_RUNNING
                    mem_write(desc, 8, FIBER_STATE_READY)

        slot = slot + 1

    return completed_in_pass

// ৫. রিয়্যাক্টর সম্পূর্ণ ড্রেন করা (Run All Fibers Until Idle)
// Runs cooperative event loop until all tasks complete or max_cycles reached
fn reactor_run_until_idle r max_cycles
    if r <= 0
        return 0
    if max_cycles <= 0
        max_cycles = 1000

    cycle = 0
    total_completed = 0
    while cycle < max_cycles
        active = reactor_active_count(r)
        if active <= 0
            break
        pass_done = reactor_step(r)
        total_completed = total_completed + pass_done
        cycle = cycle + 1

    return total_completed

// ৬. সক্রিয় ফাইবারের সংখ্যা গণনা (Count Non-Done Active Fibers)
fn reactor_active_count r
    if r <= 0
        return 0

    table = mem_read(r, 0)
    max_fibers = mem_read(r, 8)
    active = 0

    slot = 0
    while slot < max_fibers
        desc = table + (slot * FIBER_DESC_SIZE)
        st = mem_read(desc, 8)
        if st == FIBER_STATE_READY or st == FIBER_STATE_RUNNING or st == FIBER_STATE_BLOCKED
            active = active + 1
        slot = slot + 1

    return active

// ৭. রিয়্যাক্টর ক্লিনআপ (Free Reactor Pool Memory)
fn reactor_free r
    if r <= 0
        return 0
    table = mem_read(r, 0)
    max_fibers = mem_read(r, 8)
    if table > 0
        free(table, max_fibers * FIBER_DESC_SIZE)
    free(r, REACTOR_HDR_SIZE)
    return 1
