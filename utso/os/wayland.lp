// ==============================================================================
// LIPI PURE-KERNEL DISPLAY: WAYLAND WIRE PROTOCOL + MEMFD SHM (utso/os/wayland.lp)
// 100% Pure Lipi | 0% libwayland-client.so | 0% libc | Direct Linux Syscalls
// ==============================================================================
//
// WHY THIS MODULE:
// Implements the Wayland binary wire protocol directly over Linux AF_UNIX sockets
// (SYS_socket=41, SYS_connect=42, SYS_sendmsg=46, SYS_recvmsg=47) with true
// zero-copy shared memory pixel buffers via SYS_memfd_create(319) + SYS_ftruncate(77)
// + SYS_mmap(9, MAP_SHARED) + SCM_RIGHTS file-descriptor passing.
// ==============================================================================

include "utso/core/memory.lp"

// Linux ABI constants (x86_64)
WL_AF_UNIX          = 1
WL_SOCK_STREAM      = 1
WL_SOL_SOCKET       = 1
WL_SCM_RIGHTS       = 1
WL_MFD_CLOEXEC      = 1
WL_MAP_SHARED       = 1
WL_PROT_RW          = 3

// Wayland SHM pixel formats
WL_SHM_FORMAT_ARGB8888 = 0
WL_SHM_FORMAT_XRGB8888 = 1

// Well-known Wayland object IDs & opcodes
WL_DISPLAY_ID            = 1
WL_DISPLAY_SYNC          = 0
WL_DISPLAY_GET_REGISTRY  = 1
WL_REGISTRY_BIND         = 0
WL_COMPOSITOR_CREATE_SFC = 0
WL_SHM_CREATE_POOL       = 0
WL_SHM_POOL_CREATE_BUF   = 0
WL_SHM_POOL_DESTROY      = 1
WL_SURFACE_ATTACH        = 1
WL_SURFACE_COMMIT        = 6
WL_SURFACE_DAMAGE_BUFFER = 9
XDG_WM_BASE_GET_SURFACE  = 2
XDG_WM_BASE_PONG         = 3
XDG_SURFACE_GET_TOPLEVEL = 1
XDG_SURFACE_ACK_CONFIG   = 4
XDG_TOPLEVEL_SET_TITLE   = 2

struct WlShmBuffer
    wl_fd
    wl_pixels
    wl_width
    wl_height
    wl_stride
    wl_size
    wl_pool_id
    wl_buf_id
end

struct WlClient
    wl_sock_fd
    wl_next_id
    wl_registry_id
    wl_compositor_id
    wl_shm_id
    wl_xdg_base_id
    wl_surface_id
    wl_xdg_surface_id
    wl_xdg_toplevel_id
    wl_comp_global
    wl_shm_global
    wl_xdg_global
    wl_last_configure_serial
end

fn _wl_align4 n
    rem = n % 4
    if rem == 0
        return n
    end
    return n + (4 - rem)
end

fn _wl_write_u16 ptr off val
    mem_write_byte(ptr, off, val & 255)
    mem_write_byte(ptr, off + 1, (val >> 8) & 255)
    return 2
end

fn _wl_write_u32 ptr off val
    mem_write_byte(ptr, off, val & 255)
    mem_write_byte(ptr, off + 1, (val >> 8) & 255)
    mem_write_byte(ptr, off + 2, (val >> 16) & 255)
    mem_write_byte(ptr, off + 3, (val >> 24) & 255)
    return 4
end

fn _wl_read_u32 ptr off
    b0 = mem_read_byte(ptr, off)
    b1 = mem_read_byte(ptr, off + 1)
    b2 = mem_read_byte(ptr, off + 2)
    b3 = mem_read_byte(ptr, off + 3)
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

fn _wl_write_str ptr off s
    // WHY: Wayland wire strings are u32(len + 1) followed by bytes + NUL, padded to 4B boundary.
    slen = len(s)
    wire_len = slen + 1
    _wl_write_u32(ptr, off, wire_len)
    i = 0
    while i < slen
        mem_write_byte(ptr, off + 4 + i, ord(char_at(s, i)))
        i = i + 1
    end
    mem_write_byte(ptr, off + 4 + slen, 0)
    padded = _wl_align4(wire_len)
    pi = wire_len
    while pi < padded
        mem_write_byte(ptr, off + 4 + pi, 0)
        pi = pi + 1
    end
    return 4 + padded
end

fn _wl_read_str ptr off
    wlen = _wl_read_u32(ptr, off)
    if wlen <= 1 or wlen > 4096
        return ""
    end
    out = ""
    i = 0
    while i < wlen - 1
        out = out + chr(mem_read_byte(ptr, off + 4 + i))
        i = i + 1
    end
    return out
end

// ── 1. Zero-Copy Shared Memory Framebuffer via SYS_memfd_create + MAP_SHARED ──

fn wl_shm_alloc_buffer width height
    // WHY: Allocates an anonymous kernel memfd backed by MAP_SHARED pages so both Lipi's
    // rasterizer and the Wayland compositor read/write the exact same physical RAM pages.
    buf = WlShmBuffer(0 - 1, 0, 0, 0, 0, 0, 0, 0)
    if width <= 0 or height <= 0
        return buf
    end
    stride = width * 4
    total_sz = stride * height
    name_buf = malloc(16)
    // "lipi_wl\0"
    mem_write_byte(name_buf, 0, 108)
    mem_write_byte(name_buf, 1, 105)
    mem_write_byte(name_buf, 2, 112)
    mem_write_byte(name_buf, 3, 105)
    mem_write_byte(name_buf, 4, 95)
    mem_write_byte(name_buf, 5, 119)
    mem_write_byte(name_buf, 6, 108)
    mem_write_byte(name_buf, 7, 0)
    mfd = syscall(319, name_buf, WL_MFD_CLOEXEC, 0, 0, 0, 0)
    free(name_buf, 16)
    if mfd < 0
        return buf
    end
    tr = syscall(77, mfd, total_sz, 0, 0, 0, 0)
    if tr < 0
        syscall(3, mfd, 0, 0, 0, 0, 0)
        return buf
    end
    px = syscall(9, 0, total_sz, WL_PROT_RW, WL_MAP_SHARED, mfd, 0)
    if px <= 0
        syscall(3, mfd, 0, 0, 0, 0, 0)
        return buf
    end
    buf.wl_fd = mfd
    buf.wl_pixels = px
    buf.wl_width = width
    buf.wl_height = height
    buf.wl_stride = stride
    buf.wl_size = total_sz
    return buf
end

fn wl_shm_free_buffer buf
    if buf.wl_pixels > 0 and buf.wl_size > 0
        syscall(11, buf.wl_pixels, buf.wl_size, 0, 0, 0, 0)
        buf.wl_pixels = 0
    end
    if buf.wl_fd >= 0
        syscall(3, buf.wl_fd, 0, 0, 0, 0, 0)
        buf.wl_fd = 0 - 1
    end
    return 0
end

// ── 2. Linux AF_UNIX Socket Connection & SCM_RIGHTS Ancillary FD Passing ──────

fn wl_connect_socket sock_path
    fd = syscall(41, WL_AF_UNIX, WL_SOCK_STREAM, 0, 0, 0, 0)
    if fd < 0
        return 0 - 1
    end
    sa = malloc(128)
    mem_zero(sa, 128)
    _wl_write_u16(sa, 0, WL_AF_UNIX)
    plen = len(sock_path)
    if plen > 107
        plen = 107
    end
    i = 0
    while i < plen
        mem_write_byte(sa, 2 + i, ord(char_at(sock_path, i)))
        i = i + 1
    end
    mem_write_byte(sa, 2 + plen, 0)
    rc = syscall(42, fd, sa, 2 + plen + 1, 0, 0, 0)
    free(sa, 128)
    if rc < 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return 0 - 1
    end
    return fd
end

fn wl_send_raw sock_fd data_ptr data_len attach_fd
    // WHY: Uses Linux SYS_sendmsg (46) with optional SCM_RIGHTS cmsghdr to transmit
    // Wayland binary wire messages alongside kernel file descriptors (e.g. memfd).
    iov = malloc(16)
    mem_write(iov, 0, data_ptr)
    mem_write(iov, 8, data_len)

    mhdr = malloc(64)
    mem_zero(mhdr, 64)
    mem_write(mhdr, 16, iov)
    mem_write(mhdr, 24, 1)

    cmsg = 0
    if attach_fd >= 0
        cmsg = malloc(32)
        mem_zero(cmsg, 32)
        // x86_64 struct cmsghdr: cmsg_len(u64)=20, cmsg_level(i32)=SOL_SOCKET(1), cmsg_type(i32)=SCM_RIGHTS(1), fd(i32)
        mem_write(cmsg, 0, 20)
        _wl_write_u32(cmsg, 8, WL_SOL_SOCKET)
        _wl_write_u32(cmsg, 12, WL_SCM_RIGHTS)
        _wl_write_u32(cmsg, 16, attach_fd)
        mem_write(mhdr, 32, cmsg)
        mem_write(mhdr, 40, 24)
    end

    sent = syscall(46, sock_fd, mhdr, 0, 0, 0, 0)
    if cmsg != 0
        free(cmsg, 32)
    end
    free(mhdr, 64)
    free(iov, 16)
    return sent
end

fn wl_recv_raw sock_fd data_ptr max_len out_fd_box
    // WHY: Uses Linux SYS_recvmsg (47) to receive Wayland binary events and optional SCM_RIGHTS FDs.
    iov = malloc(16)
    mem_write(iov, 0, data_ptr)
    mem_write(iov, 8, max_len)

    cmsg = malloc(32)
    mem_zero(cmsg, 32)

    mhdr = malloc(64)
    mem_zero(mhdr, 64)
    mem_write(mhdr, 16, iov)
    mem_write(mhdr, 24, 1)
    mem_write(mhdr, 32, cmsg)
    mem_write(mhdr, 40, 24)

    got = syscall(47, sock_fd, mhdr, 0, 0, 0, 0)
    rx_fd = 0 - 1
    if got >= 0
        clen = mem_read(mhdr, 40)
        if clen >= 20
            c_lvl = _wl_read_u32(cmsg, 8)
            c_typ = _wl_read_u32(cmsg, 12)
            if c_lvl == WL_SOL_SOCKET and c_typ == WL_SCM_RIGHTS
                rx_fd = _wl_read_u32(cmsg, 16)
            end
        end
    end
    if out_fd_box != 0
        list_set(out_fd_box, 0, rx_fd)
    end
    free(mhdr, 64)
    free(cmsg, 32)
    free(iov, 16)
    return got
end

// ── 3. Wayland Wire Protocol Request Encoders ─────────────────────────────────

fn wl_client_new sock_fd
    return WlClient(sock_fd, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
end

fn wl_alloc_id cli
    id = cli.wl_next_id
    cli.wl_next_id = id + 1
    return id
end

fn wl_req_get_registry cli
    reg_id = wl_alloc_id(cli)
    cli.wl_registry_id = reg_id
    msg = malloc(16)
    _wl_write_u32(msg, 0, WL_DISPLAY_ID)
    _wl_write_u32(msg, 4, (12 << 16) | WL_DISPLAY_GET_REGISTRY)
    _wl_write_u32(msg, 8, reg_id)
    sent = wl_send_raw(cli.wl_sock_fd, msg, 12, 0 - 1)
    free(msg, 16)
    if sent != 12
        return 0 - 1
    end
    return reg_id
end

fn wl_req_display_sync cli
    cb_id = wl_alloc_id(cli)
    msg = malloc(16)
    _wl_write_u32(msg, 0, WL_DISPLAY_ID)
    _wl_write_u32(msg, 4, (12 << 16) | WL_DISPLAY_SYNC)
    _wl_write_u32(msg, 8, cb_id)
    sent = wl_send_raw(cli.wl_sock_fd, msg, 12, 0 - 1)
    free(msg, 16)
    if sent != 12
        return 0 - 1
    end
    return cb_id
end

fn wl_req_registry_bind cli global_name iface_name version
    new_id = wl_alloc_id(cli)
    msg = malloc(256)
    _wl_write_u32(msg, 8, global_name)
    slen = _wl_write_str(msg, 12, iface_name)
    pos = 12 + slen
    _wl_write_u32(msg, pos, version)
    _wl_write_u32(msg, pos + 4, new_id)
    total = pos + 8
    _wl_write_u32(msg, 0, cli.wl_registry_id)
    _wl_write_u32(msg, 4, (total << 16) | WL_REGISTRY_BIND)
    sent = wl_send_raw(cli.wl_sock_fd, msg, total, 0 - 1)
    free(msg, 256)
    if sent != total
        return 0 - 1
    end
    return new_id
end

fn wl_req_create_surface cli
    sfc_id = wl_alloc_id(cli)
    cli.wl_surface_id = sfc_id
    msg = malloc(16)
    _wl_write_u32(msg, 0, cli.wl_compositor_id)
    _wl_write_u32(msg, 4, (12 << 16) | WL_COMPOSITOR_CREATE_SFC)
    _wl_write_u32(msg, 8, sfc_id)
    sent = wl_send_raw(cli.wl_sock_fd, msg, 12, 0 - 1)
    free(msg, 16)
    if sent != 12
        return 0 - 1
    end
    return sfc_id
end

fn wl_req_shm_create_pool cli shm_buf
    // WHY: Sends wl_shm.create_pool(pool_id, fd, size) transmitting shm_buf.wl_fd via SCM_RIGHTS.
    pool_id = wl_alloc_id(cli)
    shm_buf.wl_pool_id = pool_id
    msg = malloc(16)
    _wl_write_u32(msg, 0, cli.wl_shm_id)
    _wl_write_u32(msg, 4, (16 << 16) | WL_SHM_CREATE_POOL)
    _wl_write_u32(msg, 8, pool_id)
    _wl_write_u32(msg, 12, shm_buf.wl_size)
    sent = wl_send_raw(cli.wl_sock_fd, msg, 16, shm_buf.wl_fd)
    free(msg, 16)
    if sent != 16
        return 0 - 1
    end
    return pool_id
end

fn wl_req_pool_create_buffer cli shm_buf fmt
    buf_id = wl_alloc_id(cli)
    shm_buf.wl_buf_id = buf_id
    msg = malloc(32)
    _wl_write_u32(msg, 0, shm_buf.wl_pool_id)
    _wl_write_u32(msg, 4, (32 << 16) | WL_SHM_POOL_CREATE_BUF)
    _wl_write_u32(msg, 8, buf_id)
    _wl_write_u32(msg, 12, 0)
    _wl_write_u32(msg, 16, shm_buf.wl_width)
    _wl_write_u32(msg, 20, shm_buf.wl_height)
    _wl_write_u32(msg, 24, shm_buf.wl_stride)
    _wl_write_u32(msg, 28, fmt)
    sent = wl_send_raw(cli.wl_sock_fd, msg, 32, 0 - 1)
    free(msg, 32)
    if sent != 32
        return 0 - 1
    end
    return buf_id
end

fn wl_req_surface_attach_and_commit cli shm_buf
    msg = malloc(64)
    // 1. wl_surface.attach(buffer_id, 0, 0) = 20 bytes
    _wl_write_u32(msg, 0, cli.wl_surface_id)
    _wl_write_u32(msg, 4, (20 << 16) | WL_SURFACE_ATTACH)
    _wl_write_u32(msg, 8, shm_buf.wl_buf_id)
    _wl_write_u32(msg, 12, 0)
    _wl_write_u32(msg, 16, 0)
    // 2. wl_surface.damage_buffer(0, 0, w, h) = 24 bytes
    _wl_write_u32(msg, 20, cli.wl_surface_id)
    _wl_write_u32(msg, 24, (24 << 16) | WL_SURFACE_DAMAGE_BUFFER)
    _wl_write_u32(msg, 28, 0)
    _wl_write_u32(msg, 32, 0)
    _wl_write_u32(msg, 36, shm_buf.wl_width)
    _wl_write_u32(msg, 40, shm_buf.wl_height)
    // 3. wl_surface.commit() = 8 bytes
    _wl_write_u32(msg, 44, cli.wl_surface_id)
    _wl_write_u32(msg, 48, (8 << 16) | WL_SURFACE_COMMIT)
    sent = wl_send_raw(cli.wl_sock_fd, msg, 52, 0 - 1)
    free(msg, 64)
    return sent
end

fn wl_req_xdg_setup cli title
    // 1. xdg_wm_base.get_xdg_surface(xdg_sfc_id, wl_surface_id)
    xs_id = wl_alloc_id(cli)
    cli.wl_xdg_surface_id = xs_id
    msg = malloc(256)
    _wl_write_u32(msg, 0, cli.wl_xdg_base_id)
    _wl_write_u32(msg, 4, (16 << 16) | XDG_WM_BASE_GET_SURFACE)
    _wl_write_u32(msg, 8, xs_id)
    _wl_write_u32(msg, 12, cli.wl_surface_id)
    wl_send_raw(cli.wl_sock_fd, msg, 16, 0 - 1)
    // 2. xdg_surface.get_toplevel(toplevel_id)
    tl_id = wl_alloc_id(cli)
    cli.wl_xdg_toplevel_id = tl_id
    _wl_write_u32(msg, 0, xs_id)
    _wl_write_u32(msg, 4, (12 << 16) | XDG_SURFACE_GET_TOPLEVEL)
    _wl_write_u32(msg, 8, tl_id)
    wl_send_raw(cli.wl_sock_fd, msg, 12, 0 - 1)
    // 3. xdg_toplevel.set_title(title)
    slen = _wl_write_str(msg, 8, title)
    tot = 8 + slen
    _wl_write_u32(msg, 0, tl_id)
    _wl_write_u32(msg, 4, (tot << 16) | XDG_TOPLEVEL_SET_TITLE)
    wl_send_raw(cli.wl_sock_fd, msg, tot, 0 - 1)
    free(msg, 256)
    return tl_id
end

fn wl_dispatch_events cli buf_ptr buf_len
    // WHY: Parses incoming Wayland wire events (wl_registry.global, xdg_wm_base.ping,
    // xdg_surface.configure) and auto-responds to protocol pings & configure acks.
    off = 0
    handled = 0
    while off + 8 <= buf_len
        obj_id = _wl_read_u32(buf_ptr, off)
        hdr = _wl_read_u32(buf_ptr, off + 4)
        msg_sz = (hdr >> 16) & 65535
        opcode = hdr & 65535
        if msg_sz < 8 or off + msg_sz > buf_len
            break
        end
        if obj_id == cli.wl_registry_id and opcode == 0 and msg_sz >= 16
            g_name = _wl_read_u32(buf_ptr, off + 8)
            g_iface = _wl_read_str(buf_ptr, off + 12)
            if g_iface == "wl_compositor"
                cli.wl_comp_global = g_name
            elif g_iface == "wl_shm"
                cli.wl_shm_global = g_name
            elif g_iface == "xdg_wm_base"
                cli.wl_xdg_global = g_name
            end
        elif obj_id == cli.wl_xdg_base_id and opcode == 0 and msg_sz >= 12
            serial = _wl_read_u32(buf_ptr, off + 8)
            pmsg = malloc(16)
            _wl_write_u32(pmsg, 0, cli.wl_xdg_base_id)
            _wl_write_u32(pmsg, 4, (12 << 16) | XDG_WM_BASE_PONG)
            _wl_write_u32(pmsg, 8, serial)
            wl_send_raw(cli.wl_sock_fd, pmsg, 12, 0 - 1)
            free(pmsg, 16)
        elif obj_id == cli.wl_xdg_surface_id and opcode == 0 and msg_sz >= 12
            serial = _wl_read_u32(buf_ptr, off + 8)
            cli.wl_last_configure_serial = serial
            amsg = malloc(16)
            _wl_write_u32(amsg, 0, cli.wl_xdg_surface_id)
            _wl_write_u32(amsg, 4, (12 << 16) | XDG_SURFACE_ACK_CONFIG)
            _wl_write_u32(amsg, 8, serial)
            wl_send_raw(cli.wl_sock_fd, amsg, 12, 0 - 1)
            free(amsg, 16)
        end
        handled = handled + 1
        off = off + msg_sz
    end
    return handled
end
