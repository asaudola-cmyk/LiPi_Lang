// ==============================================================================
// LIPI PURE-KERNEL LINUX PSEUDO-TERMINAL (PTY) DRIVER (utso/os/pty.lp)
// 100% Pure Lipi | 0% libc / openpty / util | Direct /dev/ptmx & SYS_ioctl ABI
// ==============================================================================
//
// WHY THIS MODULE:
// Enables interactive terminals, shells, REPLs, and web terminal backends directly
// on top of Linux kernel /dev/ptmx + TIOCSPTLCK + TIOCGPTN + TIOCSCTTY + TIOCSWINSZ
// + SYS_setsid + SYS_dup2 with zero external C libraries.
// ==============================================================================

import "utso/os/syscalls"
import "utso/os/process"
import "utso/os/env"

// Linux x86_64 PTY ioctl constants
PTY_TIOCSPTLCK = 1074025521  // 0x40045431 (unlock slave pts)
PTY_TIOCGPTN   = 2147767344  // 0x80045430 (get slave pts number)
PTY_TIOCSCTTY  = 21518       // 0x540E     (set controlling tty)
PTY_TIOCSWINSZ = 21524       // 0x5414     (set terminal window size)
PTY_O_RDWR_NOCTTY = 258      // O_RDWR (2) | O_NOCTTY (256)

struct PtyHandle
    pty_master_fd
    pty_slave_fd
    pty_slave_num
    pty_child_pid
    pty_rows
    pty_cols
    pty_slave_path
end

fn pty_set_winsize fd rows cols
    if fd < 0 return 0 - 1 end
    // struct winsize { u16 ws_row, ws_col, ws_xpixel, ws_ypixel } = 8 bytes
    ws = lipi_alloc(16)
    if ws <= 0 return 0 - 1 end
    sys_poke16(ws + 0, rows)
    sys_poke16(ws + 2, cols)
    sys_poke16(ws + 4, 0)
    sys_poke16(ws + 6, 0)
    rc = syscall(16, fd, PTY_TIOCSWINSZ, ws, 0, 0, 0)
    lipi_free_sized(ws, 16)
    return rc
end

fn pty_open rows cols
    if rows <= 0 rows = 24 end
    if cols <= 0 cols = 80 end
    mfd = sys_open("/dev/ptmx", PTY_O_RDWR_NOCTTY, 0)
    if mfd < 0
        return PtyHandle(0 - 1, 0 - 1, 0 - 1, 0 - 1, rows, cols, "")
    end
    // Unlock slave PTY: ioctl(mfd, TIOCSPTLCK, &0)
    ibuf = lipi_alloc(16)
    sys_poke32(ibuf, 0)
    rc_u = syscall(16, mfd, PTY_TIOCSPTLCK, ibuf, 0, 0, 0)
    if rc_u < 0
        lipi_free_sized(ibuf, 16)
        sys_close(mfd)
        return PtyHandle(0 - 1, 0 - 1, 0 - 1, 0 - 1, rows, cols, "")
    end
    // Query slave number: ioctl(mfd, TIOCGPTN, &ptn)
    sys_poke32(ibuf, 0)
    rc_n = syscall(16, mfd, PTY_TIOCGPTN, ibuf, 0, 0, 0)
    ptn = sys_peek32(ibuf)
    lipi_free_sized(ibuf, 16)
    if rc_n < 0
        sys_close(mfd)
        return PtyHandle(0 - 1, 0 - 1, 0 - 1, 0 - 1, rows, cols, "")
    end
    spath = "/dev/pts/" + str(ptn)
    sfd = sys_open(spath, PTY_O_RDWR_NOCTTY, 0)
    if sfd < 0
        sys_close(mfd)
        return PtyHandle(0 - 1, 0 - 1, ptn, 0 - 1, rows, cols, spath)
    end
    pty_set_winsize(mfd, rows, cols)
    return PtyHandle(mfd, sfd, ptn, 0 - 1, rows, cols, spath)
end

fn pty_spawn cmd args rows cols
    p = pty_open(rows, cols)
    if p.pty_master_fd < 0 or p.pty_slave_fd < 0
        return p
    end
    cur_env = env_all()
    if env_has("TERM") == 0
        cur_env = cur_env.push("TERM=xterm-256color")
    end
    pid = process_fork()
    if pid == 0
        sys_close(p.pty_master_fd)
        syscall(112, 0, 0, 0, 0, 0, 0) // SYS_setsid
        syscall(16, p.pty_slave_fd, PTY_TIOCSCTTY, 0, 0, 0, 0)
        syscall(33, p.pty_slave_fd, 0, 0, 0, 0, 0)
        syscall(33, p.pty_slave_fd, 1, 0, 0, 0, 0)
        syscall(33, p.pty_slave_fd, 2, 0, 0, 0, 0)
        if p.pty_slave_fd > 2
            sys_close(p.pty_slave_fd)
        end
        process_execve(cmd, args, cur_env)
        process_exit(127)
    end
    sys_close(p.pty_slave_fd)
    p.pty_slave_fd = 0 - 1
    p.pty_child_pid = pid
    return p
end

fn pty_write p: PtyHandle data
    if p == 0 or p.pty_master_fd < 0 return 0 - 1 end
    n = len(data)
    if n == 0 return 0 end
    sent = 0
    while sent < n
        w = sys_write(p.pty_master_fd, data + sent, n - sent)
        if w <= 0 break end
        sent = sent + w
    end
    return sent
end

fn pty_read p: PtyHandle max_bytes timeout_ms
    if p == 0 or p.pty_master_fd < 0 or max_bytes <= 0 return "" end
    if timeout_ms >= 0
        pfd = lipi_alloc(16)
        sys_poke32(pfd, p.pty_master_fd)
        sys_poke16(pfd + 4, 1) // POLLIN
        sys_poke16(pfd + 6, 0)
        pr = syscall(7, pfd, 1, timeout_ms, 0, 0, 0)
        lipi_free_sized(pfd, 16)
        if pr <= 0 return "" end
    end
    rbuf = lipi_alloc(max_bytes)
    if rbuf <= 0 return "" end
    nr = sys_read(p.pty_master_fd, rbuf, max_bytes)
    out = ""
    if nr > 0
        out = bytes_to_str(rbuf, nr)
    end
    lipi_free_sized(rbuf, max_bytes)
    return out
end

fn pty_resize p: PtyHandle rows cols
    if p == 0 or p.pty_master_fd < 0 return 0 - 1 end
    p.pty_rows = rows
    p.pty_cols = cols
    return pty_set_winsize(p.pty_master_fd, rows, cols)
end

fn pty_close p: PtyHandle
    if p == 0 return 0 end
    if p.pty_master_fd >= 0
        sys_close(p.pty_master_fd)
        p.pty_master_fd = 0 - 1
    end
    if p.pty_slave_fd >= 0
        sys_close(p.pty_slave_fd)
        p.pty_slave_fd = 0 - 1
    end
    if p.pty_child_pid > 0
        st = process_wait(p.pty_child_pid)
        p.pty_child_pid = 0 - 1
        return st
    end
    return 0
end
