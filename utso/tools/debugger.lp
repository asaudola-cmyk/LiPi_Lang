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
    return 0
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
    return 1
@end

@fn debug_disasm(bytes, addr, count)
    return count
@end
