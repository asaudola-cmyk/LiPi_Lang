import "utso/core/collections"
import "utso/core/string"

@struct Breakpoint
    bp_addr: i64
    bp_file: string
    bp_line: i64
    bp_enabled: i64
    bp_hits: i64
@end

@struct DebugSession
    ds_pid: i64
    ds_bps: array
    ds_running: i64
    ds_reason: string
@end

@fn debug_new(pid)
    return DebugSession(pid, arr_new(), 0, "initialized")
@end

@fn debug_add_bp(session, addr, file, line)
    session.ds_bps.push(Breakpoint(addr, file, line, 1, 0))
    return 1
@end

@fn debug_list_bps(session)
    return session.ds_bps.len()
@end

@fn debug_remove_bp(session, idx)
    // WHY: Removes breakpoint at index idx from active session list, returning 1 on success.
    n = session.ds_bps.len()
    @if idx < 0 || idx >= n
        return 0
    @end
    next_bps = []
    i = 0
    @while i < n
        @if i != idx
            next_bps = next_bps.push(session.ds_bps[i])
        @end
        i = i + 1
    @end
    session.ds_bps = next_bps
    return 1
@end

@fn debug_continue(session)
    session.ds_running = 1
    session.ds_reason = "running"
    return 1
@end

@fn debug_stop(session, reason)
    session.ds_running = 0
    session.ds_reason = reason
    return 1
@end

@fn debug_print_regs(rax, rbx, rcx, rip)
    println("RAX=" + to_str(rax) + " RBX=" + to_str(rbx) + " RCX=" + to_str(rcx) + " RIP=" + to_str(rip))
    return 1
@end

@fn debug_disasm(bytes, addr, count)
    // WHY: Decodes fundamental x86_64 instructions from byte stream up to requested count.
    blen = bytes.len()
    pos = 0
    decoded = 0
    @while pos < blen && decoded < count
        op = bytes[pos] & 255
        step = 1
        mnem = "db"
        @if op == 144
            mnem = "nop"
        @elif op == 195
            mnem = "ret"
        @elif op == 204
            mnem = "int3"
        @elif op == 15 && pos + 1 < blen && (bytes[pos + 1] & 255) == 5
            mnem = "syscall"
            step = 2
        @elif op >= 80 && op <= 87
            mnem = "push r" + to_str(op - 80)
        @elif op >= 88 && op <= 95
            mnem = "pop r" + to_str(op - 88)
        @end
        pos = pos + step
        decoded = decoded + 1
    @end
    return decoded
@end
