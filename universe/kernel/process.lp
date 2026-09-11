@struct KernProc
    kp_pid: i64
    kp_cmd: string
    kp_state: string
@end

@fn kproc_get_pid()
    return syscall(39, 0, 0, 0, 0, 0, 0)
@end

@fn kproc_get_ppid()
    return syscall(110, 0, 0, 0, 0, 0, 0)
@end

@fn kproc_exit(code)
    return syscall(60, code, 0, 0, 0, 0, 0)
@end

@fn kproc_fork()
    return syscall(57, 0, 0, 0, 0, 0, 0)
@end

@fn kproc_kill(pid, sig)
    return syscall(62, pid, sig, 0, 0, 0, 0)
@end
