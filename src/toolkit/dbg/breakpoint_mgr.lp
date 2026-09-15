// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: SOFTWARE BREAKPOINT MANAGER (src/toolkit/dbg/breakpoint_mgr.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | INT3 (0xCC) Trap Injection & Step-Over
// ==============================================================================
//
// WHY THIS MODULE:
// Interactive debugging requires setting non-destructive breakpoints in running CPU code.
// On x86_64, this is achieved by replacing the target instruction's first opcode byte
// with INT3 (0xCC / decimal 204):
// 1. Injects INT3 (0xCC) into child virtual memory via PTRACE_POKETEXT.
// 2. Preserves the original displaced byte in a structured breakpoint registry.
// 3. Compensates for the CPU's post-trap RIP overshoot (rewinds %rip by -1 byte).
// 4. Executes deterministic instruction step-over (unhook -> singlestep -> rearm).
// 5. Zero reliance on GDB, LLDB, or external debugger engines.

include "src/toolkit/dbg/ptrace_linux.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates state of a single software breakpoint.
struct Breakpoint
    id              // Monotonic breakpoint identifier (1, 2, 3...)
    address         // Absolute 64-bit virtual memory address
    orig_byte       // Original displaced instruction opcode byte
    is_active       // 1 if currently armed with INT3, 0 if disabled
    hit_count       // Number of times execution halted at this breakpoint

// WHY: Master breakpoint manager tracking all injection points for a target PID.
struct BreakpointManager
    pid             // Target traced Linux process identifier
    breakpoints     // List of Breakpoint structs
    next_id         // Monotonic counter for breakpoint IDs

// ── 2. Constructor Primitives ─────────────────────────────────────────────────

// WHY: Allocates clean breakpoint manager attached to traced process.
fn bp_mgr_new pid
    mgr = BreakpointManager()
    mgr.pid = pid
    mgr.breakpoints = list()
    mgr.next_id = 1
    return mgr

// ── 3. Breakpoint Insertion & Armed State Control ──────────────────────────────

// WHY: Displaces opcode byte at addr with INT3 (0xCC) and registers state.
fn bp_add mgr addr
    // Read original instruction byte before modification
    orig_byte = ptrace_peek_byte(mgr.pid, addr)

    bp = Breakpoint()
    bp.id = mgr.next_id
    mgr.next_id = mgr.next_id + 1
    bp.address = addr
    bp.orig_byte = orig_byte
    bp.is_active = 1
    bp.hit_count = 0

    // Inject INT3 (0xCC / 204)
    ptrace_poke_byte(mgr.pid, addr, 204)

    push(mgr.breakpoints, bp)
    return bp

// WHY: Searches manager registry for breakpoint by ID.
fn bp_find_by_id mgr bp_id
    bps = mgr.breakpoints
    count = len(bps)
    i = 0
    while i < count
        b = get(bps, i)
        if b.id == bp_id
            return b
        i = i + 1
    return 0

// WHY: Searches manager registry for breakpoint by memory address.
fn bp_find_by_addr mgr addr
    bps = mgr.breakpoints
    count = len(bps)
    i = 0
    while i < count
        b = get(bps, i)
        if b.address == addr
            return b
        i = i + 1
    return 0

// WHY: Restores original instruction opcode and disarms breakpoint.
fn bp_disable mgr bp_id
    bp = bp_find_by_id(mgr, bp_id)
    if bp == 0 return 0
    if bp.is_active == 1
        ptrace_poke_byte(mgr.pid, bp.address, bp.orig_byte)
        bp.is_active = 0
    return 1

// WHY: Re-injects INT3 (0xCC) into previously disabled breakpoint.
fn bp_enable mgr bp_id
    bp = bp_find_by_id(mgr, bp_id)
    if bp == 0 return 0
    if bp.is_active == 0
        ptrace_poke_byte(mgr.pid, bp.address, 204)
        bp.is_active = 1
    return 1

// WHY: Restores original byte and purges breakpoint from registry permanently.
fn bp_remove mgr bp_id
    bp_disable(mgr, bp_id)
    bps = mgr.breakpoints
    count = len(bps)
    new_list = list()
    i = 0
    while i < count
        b = get(bps, i)
        if b.id != bp_id
            push(new_list, b)
        i = i + 1
    mgr.breakpoints = new_list
    return 1

// ── 4. Trap Handling & Instruction Step-Over Engine ───────────────────────────

// WHY: Handles CPU SIGTRAP event:
// 1. Reads current %rip register.
// 2. Adjusts %rip backward by 1 byte (since CPU advanced past 0xCC upon interrupt).
// 3. Temporarily restores original opcode so the user can inspect pristine state.
fn bp_handle_trap mgr
    regs = ptrace_get_regs(mgr.pid)
    if regs == 0 return 0

    // INT3 is a 1-byte opcode; upon trap, %rip points to addr + 1
    trap_addr = regs.rip - 1
    bp = bp_find_by_addr(mgr, trap_addr)
    if bp == 0
        return 0 // Trap caused by explicit int3 or singlestep, not a registered BP

    bp.hit_count = bp.hit_count + 1

    // Rewind instruction pointer back to start of original instruction
    regs.rip = trap_addr
    ptrace_set_regs(mgr.pid, regs)

    // Restore original opcode byte in child memory
    ptrace_poke_byte(mgr.pid, bp.address, bp.orig_byte)

    return bp

// WHY: Resumes execution past a breakpoint:
// Executes the original instruction via PTRACE_SINGLESTEP, waits for trap,
// and re-arms INT3 (0xCC) so subsequent loops continue to trigger the breakpoint.
fn bp_step_and_rearm mgr bp
    if bp == 0 return 0

    // Single-step original instruction
    ptrace_singlestep(mgr.pid)

    // Wait for single-step trap completion via Linux SYS_wait4 (61)
    status_buf = malloc(8)
    mem_word_write(status_buf, 0, 0)
    syscall(61, mgr.pid, status_buf, 0, 0, 0, 0)
    free(status_buf, 8)

    // Re-inject INT3 (0xCC) to maintain breakpoint armed state
    if bp.is_active == 1
        ptrace_poke_byte(mgr.pid, bp.address, 204)

    return 1

// ── 5. Formatted Breakpoint Registry Display ──────────────────────────────────

// WHY: Renders clean terminal table listing all registered breakpoints.
fn bp_list_all mgr
    bps = mgr.breakpoints
    count = len(bps)
    say "  ╔══════════════════════════════════════════════════════════════════════╗"
    say "  ║  ACTIVE SOFTWARE BREAKPOINTS (INT3 0xCC)                             ║"
    say "  ╠══════════════════════════════════════════════════════════════════════╣"
    if count == 0
        say "  ║  No breakpoints currently set.                                       ║"
    else
        i = 0
        while i < count
            bp = get(bps, i)
            state_str = "ARMED"
            if bp.is_active == 0 state_str = "OFF  "
            say "  ║  [" + bp.id + "] " + ptrace_format_hex(bp.address) + "  " + state_str + "  Hits: " + str(bp.hit_count) + "  OrigOp: 0x" + ptrace_hex8(bp.orig_byte) + "  ║"
            i = i + 1
    say "  ╚══════════════════════════════════════════════════════════════════════╝"
    return count
