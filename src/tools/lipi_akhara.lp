// ==============================================================================
// LIPI AKHARA (লিপি আখড়া) — Sovereign Silicon Studio & Binary Inspector
// ==============================================================================
// Pure Lipi 1.0 | 0% Python | 0% Node | 0% External Web Server | Direct Linux Sockets
// Modes:
//   lipi_akhara [port]                 Launch persistent HTTP studio (default: 8085)
//   lipi_akhara --selftest             Verify compiler discovery, --kavach, & ELF parsing
//   lipi_akhara --inspect <file.lp> [--kavach]  Compile, execute, & inspect machine ELF
//   lipi_akhara --oneshot-http <port> [count]   Serve <count> HTTP requests and exit cleanly

include "utso/io"
include "utso/memory"
include "utso/string"

fn akhara_str_eq a b
    return a == b

fn akhara_parse_int s fallback_val
    n = len(s)
    if n == 0
        return fallback_val
    i = 0
    neg = 0
    if char_at(s, 0) == "-"
        neg = 1
        i = 1
    if i >= n
        return fallback_val
    acc = 0
    while i < n
        ch = ord(char_at(s, i))
        if ch < 48 or ch > 57
            return fallback_val
        acc = acc * 10 + (ch - 48)
        i = i + 1
    if neg == 1
        return 0 - acc
    return acc

fn akhara_byte_hex b
    v = b % 256
    if v < 0
        v = v + 256
    hi = v / 16
    lo = v % 16
    digits = "0123456789abcdef"
    return char_at(digits, hi) + char_at(digits, lo)

fn akhara_u64_hex val
    if val == 0
        return "0x0"
    digits = "0123456789abcdef"
    out = ""
    cur = val
    steps = 0
    while cur > 0 and steps < 16
        nib = cur % 16
        if nib < 0
            nib = nib + 16
        out = char_at(digits, nib) + out
        cur = cur / 16
        steps = steps + 1
    if len(out) == 0
        return "0x0"
    return "0x" + out

fn akhara_read_u16_le buf off
    b0 = silicon_mem_byte_read(buf, off)
    b1 = silicon_mem_byte_read(buf, off + 1)
    return b0 + b1 * 256

fn akhara_read_u32_le buf off
    b0 = silicon_mem_byte_read(buf, off)
    b1 = silicon_mem_byte_read(buf, off + 1)
    b2 = silicon_mem_byte_read(buf, off + 2)
    b3 = silicon_mem_byte_read(buf, off + 3)
    return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216

fn akhara_read_u64_le buf off
    lo = akhara_read_u32_le(buf, off)
    hi = akhara_read_u32_le(buf, off + 4)
    return lo + hi * 4294967296

// ── Sovereign Silicon Hardware Boundary (--kavach Crowned Layer) ───────────────
// WHY: Under --kavach, only silicon_* functions touch raw kernel syscalls or pointer writes.
fn silicon_mem_byte_read ptr off
    return mem_byte_read(ptr, off)

fn silicon_alloc_raw size
    return syscall(9, 0, size, 3, 34, -1, 0)

fn silicon_free_raw ptr size
    return syscall(11, ptr, size, 0, 0, 0, 0)

fn silicon_open_ro path
    return syscall(2, path, 0, 0, 0, 0, 0)

fn silicon_open_trunc path
    return syscall(2, path, 577, 420, 0, 0, 0)

fn silicon_read_fd fd buf cap
    return syscall(0, fd, buf, cap, 0, 0, 0)

fn silicon_write_fd fd buf cnt
    return syscall(1, fd, buf, cnt, 0, 0, 0)

fn silicon_close_fd fd
    return syscall(3, fd, 0, 0, 0, 0, 0)

fn silicon_unlink path
    return syscall(87, path, 0, 0, 0, 0, 0)

fn silicon_access_ok path
    if syscall(21, path, 0, 0, 0, 0, 0) == 0
        return 1
    return 0

fn silicon_getpid
    return syscall(39, 0, 0, 0, 0, 0, 0)

fn silicon_readlink_exe buf cap
    n = syscall(89, "/proc/self/exe", buf, cap, 0, 0, 0)
    if n > 0
        mem_byte_write(buf, n, 0)
    return n

fn silicon_rand_hex n_bytes
    buf = silicon_alloc_raw(n_bytes)
    if buf <= 0
        return ""
    got = syscall(318, buf, n_bytes, 0, 0, 0, 0)
    out = ""
    if got == n_bytes
        i = 0
        while i < n_bytes
            out = out + akhara_byte_hex(mem_byte_read(buf, i) & 255)
            i = i + 1
    silicon_free_raw(buf, n_bytes)
    return out

fn silicon_now_us
    ts = silicon_alloc_raw(16)
    rc = syscall(228, 1, ts, 0, 0, 0, 0)
    res = 0
    if rc >= 0
        sec = mem_read(ts, 0)
        nsec = mem_read(ts, 8)
        res = sec * 1000000 + nsec / 1000
    silicon_free_raw(ts, 16)
    return res

fn silicon_exec_capture exe_path a1 a2 a3 a4 home_s capture_path
    argv = silicon_alloc_raw(64)
    env = silicon_alloc_raw(32)
    st = silicon_alloc_raw(8)

    i = 0
    while i < 64
        mem_byte_write(argv, i, 0)
        i = i + 1
    i = 0
    while i < 32
        mem_byte_write(env, i, 0)
        i = i + 1
    mem_write(st, 0, 0)

    mem_write(argv, 0, exe_path)
    idx = 1
    if len(a1) > 0
        mem_write(argv, idx * 8, a1)
        idx = idx + 1
    if len(a2) > 0
        mem_write(argv, idx * 8, a2)
        idx = idx + 1
    if len(a3) > 0
        mem_write(argv, idx * 8, a3)
        idx = idx + 1
    if len(a4) > 0
        mem_write(argv, idx * 8, a4)
        idx = idx + 1
    mem_write(argv, idx * 8, 0)

    if len(home_s) > 0
        env_home = "HOME=" + home_s
        mem_write(env, 0, env_home)
        mem_write(env, 8, 0)
    else
        mem_write(env, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        if len(capture_path) > 0
            cfd = syscall(2, capture_path, 577, 420, 0, 0, 0)
            if cfd >= 0
                syscall(33, cfd, 1, 0, 0, 0, 0)
                syscall(33, cfd, 2, 0, 0, 0, 0)
                syscall(3, cfd, 0, 0, 0, 0, 0)
        syscall(59, exe_path, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    exit_code = 127
    if pid > 0
        syscall(61, pid, st, 0, 0, 0, 0)
        raw_st = mem_read(st, 0) & 65535
        sig_num = raw_st & 127
        if sig_num != 0
            exit_code = 128 + sig_num
        else
            exit_code = (raw_st / 256) % 256

    silicon_free_raw(argv, 64)
    silicon_free_raw(env, 32)
    silicon_free_raw(st, 8)
    return exit_code

fn silicon_tcp_bind_listen port
    srv_fd = syscall(41, 2, 1, 0, 0, 0, 0)
    if srv_fd < 0
        return 0 - 1

    opt = silicon_alloc_raw(8)
    mem_write(opt, 0, 1)
    syscall(54, srv_fd, 1, 2, opt, 4, 0)
    silicon_free_raw(opt, 8)

    sa = silicon_alloc_raw(16)
    i = 0
    while i < 16
        mem_byte_write(sa, i, 0)
        i = i + 1
    mem_byte_write(sa, 0, 2)
    mem_byte_write(sa, 1, 0)
    mem_byte_write(sa, 2, (port / 256) % 256)
    mem_byte_write(sa, 3, port % 256)
    mem_byte_write(sa, 4, 127)
    mem_byte_write(sa, 5, 0)
    mem_byte_write(sa, 6, 0)
    mem_byte_write(sa, 7, 1)

    b_rc = syscall(49, srv_fd, sa, 16, 0, 0, 0)
    silicon_free_raw(sa, 16)
    if b_rc < 0
        syscall(3, srv_fd, 0, 0, 0, 0, 0)
        return 0 - 2

    l_rc = syscall(50, srv_fd, 32, 0, 0, 0, 0)
    if l_rc < 0
        syscall(3, srv_fd, 0, 0, 0, 0, 0)
        return 0 - 3

    return srv_fd

fn silicon_tcp_accept srv_fd
    return syscall(43, srv_fd, 0, 0, 0, 0, 0)

fn akhara_get_env target_key
    data = file_read("/proc/self/environ")
    if len(data) == 0
        return ""
    // /proc/self/environ is NUL-delimited; read raw bytes cleanly via crowned helpers.
    buf = silicon_alloc_raw(16384)
    fd = silicon_open_ro("/proc/self/environ")
    out_val = ""
    if fd >= 0
        n = silicon_read_fd(fd, buf, 16383)
        silicon_close_fd(fd)
        klen = len(target_key)
        i = 0
        while i < n
            matched = 1
            if i + klen + 1 >= n
                matched = 0
            else
                j = 0
                while j < klen
                    if silicon_mem_byte_read(buf, i + j) != ord(char_at(target_key, j))
                        matched = 0
                        break
                    j = j + 1
                if matched == 1 and silicon_mem_byte_read(buf, i + klen) != 61
                    matched = 0
            if matched == 1
                val = ""
                p = i + klen + 1
                while p < n
                    b = silicon_mem_byte_read(buf, p)
                    if b == 0
                        break
                    val = val + chr(b)
                    p = p + 1
                out_val = val
                break
            while i < n and silicon_mem_byte_read(buf, i) != 0
                i = i + 1
            i = i + 1
    silicon_free_raw(buf, 16384)
    return out_val

fn akhara_resolve_compiler
    l_home = akhara_get_env("LIPI_HOME")
    if len(l_home) > 0
        c0 = l_home + "/bin/lipc"
        if silicon_access_ok(c0) == 1
            return c0
    if silicon_access_ok("bin/lipc") == 1
        return "bin/lipc"
    if silicon_access_ok("bin/lipc_bin") == 1
        return "bin/lipc_bin"

    exe_buf = silicon_alloc_raw(512)
    n = silicon_readlink_exe(exe_buf, 511)
    found_sib = ""
    if n > 0
        last_slash = 0 - 1
        si = n - 1
        while si >= 0
            if silicon_mem_byte_read(exe_buf, si) == 47
                last_slash = si
                break
            si = si - 1
        if last_slash >= 0
            dir_s = ""
            di = 0
            while di <= last_slash
                dir_s = dir_s + chr(silicon_mem_byte_read(exe_buf, di))
                di = di + 1
            cand_sib = dir_s + "lipc"
            if silicon_access_ok(cand_sib) == 1
                found_sib = cand_sib
            else
                cand_sib2 = dir_s + "lipc_bin"
                if silicon_access_ok(cand_sib2) == 1
                    found_sib = cand_sib2
    silicon_free_raw(exe_buf, 512)
    if len(found_sib) > 0
        return found_sib

    u_home = akhara_get_env("HOME")
    if len(u_home) > 0
        c1 = u_home + "/.lipi/bin/lipc"
        if silicon_access_ok(c1) == 1
            return c1
        c2 = u_home + "/.local/bin/lipc"
        if silicon_access_ok(c2) == 1
            return c2
    if silicon_access_ok("/usr/local/bin/lipc") == 1
        return "/usr/local/bin/lipc"
    return "bin/lipc"

fn akhara_exec_capture exe_path a1 a2 a3 a4 capture_path
    home_s = akhara_get_env("HOME")
    return silicon_exec_capture(exe_path, a1, a2, a3, a4, home_s, capture_path)

fn akhara_json_escape s
    out = ""
    n = len(s)
    i = 0
    while i < n
        ch = char_at(s, i)
        code = ord(ch)
        if code == 34
            out = out + "\\\""
        elif code == 92
            out = out + "\\\\"
        elif code == 10
            out = out + "\\n"
        elif code == 13
            out = out + "\\r"
        elif code == 9
            out = out + "\\t"
        elif code < 32
            out = out + " "
        else
            out = out + ch
        i = i + 1
    return out

fn akhara_json_extract_str body key
    pat = "\"" + key + "\":\""
    plen = len(pat)
    blen = len(body)
    // Also handle optional space after ':' -> "key": "..."
    pat_sp = "\"" + key + "\": \""
    pslen = len(pat_sp)

    start_idx = 0 - 1
    i = 0
    while i + plen <= blen
        if str_sub(body, i, i + plen) == pat
            start_idx = i + plen
            break
        if i + pslen <= blen and str_sub(body, i, i + pslen) == pat_sp
            start_idx = i + pslen
            break
        i = i + 1
    if start_idx < 0
        return ""

    out = ""
    p = start_idx
    while p < blen
        ch = char_at(body, p)
        if ch == "\""
            break
        if ch == "\\" and p + 1 < blen
            nx = char_at(body, p + 1)
            if nx == "n"
                out = out + "\n"
            elif nx == "r"
                out = out + "\r"
            elif nx == "t"
                out = out + "\t"
            elif nx == "\""
                out = out + "\""
            elif nx == "\\"
                out = out + "\\"
            elif nx == "/"
                out = out + "/"
            else
                out = out + nx
            p = p + 2
        else
            out = out + ch
            p = p + 1
    return out

fn akhara_json_extract_bool body key
    pat_t1 = "\"" + key + "\":true"
    pat_t2 = "\"" + key + "\": true"
    if str_contains(body, pat_t1) == 1 or str_contains(body, pat_t2) == 1
        return 1
    return 0

struct ElfReport
    er_valid
    er_size
    er_type_name
    er_machine_name
    er_entry_hex
    er_phnum
    er_rwe_count
    er_silicon_bytes

// WHY: Reads raw ELF64 bytes via SYS_open/SYS_read (preserving embedded 0x00 bytes) to audit PIE ET_DYN, W^X PHDRs, and entry machine opcodes.
fn akhara_inspect_elf bin_path
    rep = ElfReport(0, 0, "INVALID", "UNKNOWN", "0x0", 0, 0, "")
    fd = silicon_open_ro(bin_path)
    if fd < 0
        return rep

    cap = 524288
    buf = silicon_alloc_raw(cap)
    total = 0
    while total < cap
        chunk = silicon_read_fd(fd, buf + total, cap - total)
        if chunk <= 0
            break
        total = total + chunk
    silicon_close_fd(fd)

    rep.er_size = total
    if total >= 64 and silicon_mem_byte_read(buf, 0) == 127 and silicon_mem_byte_read(buf, 1) == 69 and silicon_mem_byte_read(buf, 2) == 76 and silicon_mem_byte_read(buf, 3) == 70
        rep.er_valid = 1
        e_type = akhara_read_u16_le(buf, 16)
        if e_type == 3
            rep.er_type_name = "ET_DYN"
        elif e_type == 2
            rep.er_type_name = "ET_EXEC"
        else
            rep.er_type_name = "ELF_" + str(e_type)

        e_mach = akhara_read_u16_le(buf, 18)
        if e_mach == 62
            rep.er_machine_name = "x86_64"
        elif e_mach == 183
            rep.er_machine_name = "aarch64"
        elif e_mach == 243
            rep.er_machine_name = "riscv64"
        else
            rep.er_machine_name = "arch_" + str(e_mach)

        e_entry = akhara_read_u64_le(buf, 24)
        rep.er_entry_hex = akhara_u64_hex(e_entry)

        e_phoff = akhara_read_u64_le(buf, 32)
        e_phentsize = akhara_read_u16_le(buf, 54)
        e_phnum = akhara_read_u16_le(buf, 56)
        rep.er_phnum = e_phnum

        entry_file_off = 0 - 1
        rwe_hits = 0
        pi = 0
        while pi < e_phnum and pi < 32
            off = e_phoff + pi * e_phentsize
            if off + 56 <= total
                p_type = akhara_read_u32_le(buf, off)
                p_flags = akhara_read_u32_le(buf, off + 4)
                p_offset = akhara_read_u64_le(buf, off + 8)
                p_vaddr = akhara_read_u64_le(buf, off + 16)
                p_memsz = akhara_read_u64_le(buf, off + 40)
                if p_type == 1
                    if (p_flags & 7) == 7
                        rwe_hits = rwe_hits + 1
                    if e_entry >= p_vaddr and e_entry < p_vaddr + p_memsz
                        entry_file_off = p_offset + (e_entry - p_vaddr)
            pi = pi + 1

        rep.er_rwe_count = rwe_hits

        bytes_hex = ""
        if entry_file_off >= 0 and entry_file_off < total
            k = 0
            while k < 24 and entry_file_off + k < total
                if k > 0
                    bytes_hex = bytes_hex + " "
                bytes_hex = bytes_hex + akhara_byte_hex(silicon_mem_byte_read(buf, entry_file_off + k))
                k = k + 1
        rep.er_silicon_bytes = bytes_hex

    silicon_free_raw(buf, cap)
    return rep

struct RunResult
    rr_ok
    rr_compile_exit
    rr_run_exit
    rr_compile_us
    rr_run_us
    rr_stdout
    rr_compiler_log
    rr_elf

fn akhara_compile_and_run_file src_path use_kavach seq_tag
    pid = silicon_getpid()
    bin_path = "/tmp/akhara_bin_" + str(pid) + "_" + str(seq_tag) + ".elf"
    clog_path = "/tmp/akhara_clog_" + str(pid) + "_" + str(seq_tag) + ".txt"
    rlog_path = "/tmp/akhara_rlog_" + str(pid) + "_" + str(seq_tag) + ".txt"

    compiler = akhara_resolve_compiler()
    t0 = silicon_now_us()
    cexit = 0
    if use_kavach == 1
        cexit = akhara_exec_capture(compiler, src_path, bin_path, "--kavach", "", clog_path)
    else
        cexit = akhara_exec_capture(compiler, src_path, bin_path, "", "", clog_path)
    t1 = silicon_now_us()
    c_us = t1 - t0
    if c_us < 0
        c_us = 0

    clog = file_read(clog_path)
    silicon_unlink(clog_path)

    empty_elf = ElfReport(0, 0, "NONE", "NONE", "0x0", 0, 0, "")
    if cexit != 0
        silicon_unlink(bin_path)
        return RunResult(0, cexit, 0 - 1, c_us, 0, "", clog, empty_elf)

    elf_rep = akhara_inspect_elf(bin_path)
    t2 = silicon_now_us()
    rexit = akhara_exec_capture(bin_path, "", "", "", "", rlog_path)
    t3 = silicon_now_us()
    r_us = t3 - t2
    if r_us < 0
        r_us = 0

    r_out = file_read(rlog_path)
    silicon_unlink(rlog_path)
    silicon_unlink(bin_path)

    return RunResult(1, 0, rexit, c_us, r_us, r_out, clog, elf_rep)

fn akhara_compile_and_run_code code_str use_kavach seq_tag
    pid = silicon_getpid()
    tmp_src = "/tmp/akhara_play_" + str(pid) + "_" + str(seq_tag) + ".lp"
    if len(code_str) > 32768
        empty_elf = ElfReport(0, 0, "NONE", "NONE", "0x0", 0, 0, "")
        return RunResult(0, 1, 0 - 1, 0, 0, "", "Error: source size exceeds 32 KiB limit", empty_elf)

    fd = silicon_open_trunc(tmp_src)
    if fd < 0
        empty_elf = ElfReport(0, 0, "NONE", "NONE", "0x0", 0, 0, "")
        return RunResult(0, 1, 0 - 1, 0, 0, "", "Error: failed to create temporary source file", empty_elf)
    silicon_write_fd(fd, code_str, len(code_str))
    silicon_close_fd(fd)

    res = akhara_compile_and_run_file(tmp_src, use_kavach, seq_tag)
    silicon_unlink(tmp_src)
    return res

fn akhara_result_to_json res
    elf = res.rr_elf
    ok_str = "false"
    if res.rr_ok == 1
        ok_str = "true"
    j = "{"
    j = j + "\"ok\":" + ok_str + ","
    j = j + "\"compile_exit\":" + str(res.rr_compile_exit) + ","
    j = j + "\"run_exit\":" + str(res.rr_run_exit) + ","
    j = j + "\"compile_us\":" + str(res.rr_compile_us) + ","
    j = j + "\"run_us\":" + str(res.rr_run_us) + ","
    j = j + "\"bin_bytes\":" + str(elf.er_size) + ","
    j = j + "\"elf_type\":\"" + akhara_json_escape(elf.er_type_name) + "\","
    j = j + "\"machine\":\"" + akhara_json_escape(elf.er_machine_name) + "\","
    j = j + "\"entry_hex\":\"" + akhara_json_escape(elf.er_entry_hex) + "\","
    j = j + "\"rwe_segments\":" + str(elf.er_rwe_count) + ","
    j = j + "\"silicon_bytes\":\"" + akhara_json_escape(elf.er_silicon_bytes) + "\","
    j = j + "\"stdout\":\"" + akhara_json_escape(res.rr_stdout) + "\","
    j = j + "\"compiler_log\":\"" + akhara_json_escape(res.rr_compiler_log) + "\""
    j = j + "}"
    return j

fn akhara_studio_html csrf_tok
    h = "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
    h = h + "<title>Lipi Akhara (লিপি আখড়া) — Sovereign Silicon Studio</title>"
    h = h + "<style>body{margin:0;background:#0a0e17;color:#e6edf3;font-family:ui-monospace,SFMono-Regular,Consolas,monospace;padding:20px;}"
    h = h + ".wrap{max-width:1100px;margin:0 auto;}h1{color:#38bdf8;margin:0 0 6px;} .sub{color:#94a3b8;margin-bottom:16px;font-size:13px;}"
    h = h + ".grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;}@media(max-width:860px){.grid{grid-template-columns:1fr;}}"
    h = h + ".card{background:#111827;border:1px solid #1f2937;border-radius:10px;padding:14px;}"
    h = h + "textarea{width:100%;height:310px;background:#070b12;color:#a5f3fc;border:1px solid #334155;border-radius:6px;padding:10px;font:inherit;box-sizing:border-box;}"
    h = h + ".bar{display:flex;gap:12px;align-items:center;margin-top:10px;}"
    h = h + "button{background:#0284c7;color:#fff;border:0;border-radius:6px;padding:9px 16px;font-weight:700;cursor:pointer;}button:hover{background:#0369a1;}"
    h = h + "pre{background:#070b12;border:1px solid #1e293b;border-radius:6px;padding:10px;min-height:110px;white-space:pre-wrap;word-break:break-word;margin:8px 0;color:#86efac;}"
    h = h + ".meta{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:8px;font-size:12px;}"
    h = h + ".pill{background:#0f172a;border:1px solid #334155;border-radius:6px;padding:7px;}"
    h = h + "</style></head><body><div class='wrap'>"
    h = h + "<h1>লিপি আখড়া · Lipi Sovereign Silicon Studio</h1>"
    h = h + "<div class='sub'>0% Libc · 0% LLVM · Pure Native ELF64 Execution & Machine-Byte Inspector</div>"
    h = h + "<div class='grid'><div class='card'><label>Source (.lp)</label>"
    h = h + "<textarea id='src'>fn main\n    buf = alloc(64)\n    say \"Sovereign Silicon Live!\"\n    free(buf)\n    return 0\n\nmain()</textarea>"
    h = h + "<div class='bar'><button onclick='runCode()'>Compile &amp; Run on Silicon</button>"
    h = h + "<label><input type='checkbox' id='kav' checked> Enforce --kavach (সর্বভৌম কবচ)</label></div></div>"
    h = h + "<div class='card'><div><b>Telemetry</b></div><div class='meta'>"
    h = h + "<div class='pill'>ELF: <span id='m_elf'>-</span></div>"
    h = h + "<div class='pill'>RWE Segments: <span id='m_rwe'>-</span></div>"
    h = h + "<div class='pill'>Size: <span id='m_sz'>-</span></div>"
    h = h + "<div class='pill'>Compile: <span id='m_ct'>-</span></div>"
    h = h + "<div class='pill'>Run: <span id='m_rt'>-</span></div>"
    h = h + "<div class='pill'>Entry: <span id='m_ent'>-</span></div></div>"
    h = h + "<div style='margin-top:10px'><b>_start Machine Bytes</b></div><pre id='m_bytes' style='min-height:36px;color:#fcd34d'>-</pre>"
    h = h + "<div><b>Silicon Stdout &amp; Compiler Output</b></div><pre id='out'>Ready.</pre></div></div></div>"
    h = h + "<script>const LIPI_TOK='" + csrf_tok + "';async function runCode(){const r=await fetch('/api/run',{method:'POST',headers:{'Content-Type':'application/json','X-Lipi-Token':LIPI_TOK},"
    h = h + "body:JSON.stringify({code:document.getElementById('src').value,kavach:document.getElementById('kav').checked})});"
    h = h + "const d=await r.json();document.getElementById('m_elf').textContent=d.elf_type+' ('+d.machine+')';"
    h = h + "document.getElementById('m_rwe').textContent=d.rwe_segments;document.getElementById('m_sz').textContent=d.bin_bytes+' B';"
    h = h + "document.getElementById('m_ct').textContent=d.compile_us+' us';document.getElementById('m_rt').textContent=d.run_us+' us';"
    h = h + "document.getElementById('m_ent').textContent=d.entry_hex;document.getElementById('m_bytes').textContent=d.silicon_bytes||'-';"
    h = h + "document.getElementById('out').textContent=(d.ok?d.stdout:d.compiler_log)+'\\n[exit='+ (d.ok?d.run_exit:d.compile_exit) +']';}</script></body></html>"
    return h

fn _akhara_ascii_lower c
    o = ord(c)
    if o >= 65 and o <= 90
        return chr(o + 32)
    return c

fn _akhara_str_lower s
    out = ""
    i = 0
    while i < len(s)
        out = out + _akhara_ascii_lower(char_at(s, i))
        i = i + 1
    return out

fn _akhara_get_header hdrs name_lower
    hlen = len(hdrs)
    nlen = len(name_lower)
    pos = 0
    while pos < hlen
        eol = pos
        while eol < hlen and char_at(hdrs, eol) != "\n"
            eol = eol + 1
        line = str_sub(hdrs, pos, eol)
        if len(line) > 0 and char_at(line, len(line) - 1) == "\r"
            line = str_sub(line, 0, len(line) - 1)
        col = 0
        while col < len(line) and char_at(line, col) != ":"
            col = col + 1
        if col > 0 and col < len(line)
            hn = _akhara_str_lower(str_sub(line, 0, col))
            if hn == name_lower
                vs = col + 1
                while vs < len(line) and (char_at(line, vs) == " " or char_at(line, vs) == "\t")
                    vs = vs + 1
                return str_sub(line, vs, len(line))
        pos = eol + 1
    return ""

fn _akhara_ct_eq a b
    if len(a) == 0 or len(a) != len(b)
        return 0
    diff = 0
    i = 0
    while i < len(a)
        diff = diff | (ord(char_at(a, i)) ^ ord(char_at(b, i)))
        i = i + 1
    if diff == 0 return 1
    return 0

fn _akhara_is_local_host_or_origin val port allow_scheme
    v = _akhara_str_lower(val)
    p_s = str(port)
    if allow_scheme == 0
        if v == ("127.0.0.1:" + p_s) or v == ("localhost:" + p_s) or v == "127.0.0.1" or v == "localhost"
            return 1
        return 0
    if v == ("http://127.0.0.1:" + p_s) or v == ("http://localhost:" + p_s) or v == "http://127.0.0.1" or v == "http://localhost"
        return 1
    return 0

fn akhara_send_http cfd status_line content_type body
    hdr = "HTTP/1.1 " + status_line + "\r\n"
    hdr = hdr + "Content-Type: " + content_type + "\r\n"
    hdr = hdr + "Content-Length: " + str(len(body)) + "\r\n"
    hdr = hdr + "Connection: close\r\n"
    hdr = hdr + "X-Lipi-Sovereign: Direct-Silicon\r\n\r\n"
    pkt = hdr + body
    silicon_write_fd(cfd, pkt, len(pkt))

fn akhara_read_http_request cfd
    cap = 65536
    buf = silicon_alloc_raw(cap)
    total = 0
    header_end = 0 - 1
    expected_total = 0 - 1

    while total < cap - 1
        n = silicon_read_fd(cfd, buf + total, cap - 1 - total)
        if n <= 0
            break
        total = total + n
        if header_end < 0 and total >= 4
            k = 0
            while k + 3 < total
                if silicon_mem_byte_read(buf, k) == 13 and silicon_mem_byte_read(buf, k + 1) == 10 and silicon_mem_byte_read(buf, k + 2) == 13 and silicon_mem_byte_read(buf, k + 3) == 10
                    header_end = k + 4
                    break
                k = k + 1
            if header_end >= 0
                hdr_txt = ""
                hi = 0
                while hi < header_end
                    hdr_txt = hdr_txt + chr(silicon_mem_byte_read(buf, hi))
                    hi = hi + 1
                cl_val = 0
                hl = len(hdr_txt)
                ci = 0
                while ci + 15 <= hl
                    sub15 = str_sub(hdr_txt, ci, ci + 15)
                    if sub15 == "Content-Length:" or sub15 == "content-length:"
                        p = ci + 15
                        while p < hl and (char_at(hdr_txt, p) == " " or char_at(hdr_txt, p) == "\t")
                            p = p + 1
                        num_s = ""
                        while p < hl
                            c = ord(char_at(hdr_txt, p))
                            if c < 48 or c > 57
                                break
                            num_s = num_s + chr(c)
                            p = p + 1
                        cl_val = akhara_parse_int(num_s, 0)
                        break
                    ci = ci + 1
                expected_total = header_end + cl_val
        if expected_total >= 0 and total >= expected_total
            break

    req = ""
    i = 0
    while i < total
        req = req + chr(silicon_mem_byte_read(buf, i))
        i = i + 1
    silicon_free_raw(buf, cap)
    return req

fn akhara_serve port max_requests
    csrf_tok = silicon_rand_hex(24)
    if len(csrf_tok) < 32
        say "❌ CSPRNG token allocation failed"
        return 1
    srv_fd = silicon_tcp_bind_listen(port)
    if srv_fd < 0
        say "❌ Socket setup/bind/listen failed on 127.0.0.1:" + str(port) + " (rc=" + str(srv_fd) + ")"
        return 1

    say "AKHARA_READY port=" + str(port)
    handled = 0
    seq = 1

    while max_requests == 0 or handled < max_requests
        cfd = silicon_tcp_accept(srv_fd)
        if cfd < 0
            continue

        req = akhara_read_http_request(cfd)
        rlen = len(req)
        if rlen > 0
            eol = 0
            while eol < rlen
                ch = char_at(req, eol)
                if ch == "\r" or ch == "\n"
                    break
                eol = eol + 1
            req_line = str_sub(req, 0, eol)

            body_idx = 0 - 1
            bi = 0
            while bi + 3 < rlen
                if str_sub(req, bi, bi + 4) == "\r\n\r\n"
                    body_idx = bi + 4
                    break
                bi = bi + 1
            hdr_part = req
            if body_idx >= 4
                hdr_part = str_sub(req, 0, body_idx)

            if str_starts_with(req_line, "GET /health ") == 1
                akhara_send_http(cfd, "200 OK", "application/json", "{\"status\":\"ok\",\"service\":\"lipi_akhara\",\"zero_deps\":true}")
            elif str_starts_with(req_line, "GET / ") == 1
                akhara_send_http(cfd, "200 OK", "text/html; charset=utf-8", akhara_studio_html(csrf_tok))
            elif str_starts_with(req_line, "POST /api/run ") == 1
                host_v = _akhara_get_header(hdr_part, "host")
                origin_v = _akhara_get_header(hdr_part, "origin")
                ctype_v = _akhara_str_lower(_akhara_get_header(hdr_part, "content-type"))
                tok_v = _akhara_get_header(hdr_part, "x-lipi-token")
                host_ok = _akhara_is_local_host_or_origin(host_v, port, 0)
                origin_ok = 1
                if len(origin_v) > 0
                    origin_ok = _akhara_is_local_host_or_origin(origin_v, port, 1)
                ctype_ok = str_starts_with(ctype_v, "application/json")
                tok_ok = _akhara_ct_eq(tok_v, csrf_tok)

                if host_ok != 1 or origin_ok != 1 or ctype_ok != 1 or tok_ok != 1
                    akhara_send_http(cfd, "403 Forbidden", "application/json", "{\"ok\":false,\"error\":\"csrf_origin_or_content_type_rejected\"}")
                else
                    body = ""
                    if body_idx >= 0 and body_idx < rlen
                        body = str_sub(req, body_idx, rlen)
                    code_str = akhara_json_extract_str(body, "code")
                    use_kav = akhara_json_extract_bool(body, "kavach")
                    if len(code_str) == 0
                        akhara_send_http(cfd, "400 Bad Request", "application/json", "{\"ok\":false,\"compiler_log\":\"Missing code payload\"}")
                    else
                        rr = akhara_compile_and_run_code(code_str, use_kav, seq)
                        seq = seq + 1
                        akhara_send_http(cfd, "200 OK", "application/json", akhara_result_to_json(rr))
            else
                akhara_send_http(cfd, "404 Not Found", "application/json", "{\"error\":\"not_found\"}")
            handled = handled + 1

        silicon_close_fd(cfd)

    silicon_close_fd(srv_fd)
    return 0

fn akhara_run_selftest
    say "⚔️ Lipi Akhara (লিপি আখড়া) Self-Test Suite"
    // 1. JSON escape + extract roundtrip
    sample_json = "{\"code\":\"fn main\\n  say \\\"HI\\\"\\n  return 0\",\"kavach\":true}"
    ext_code = akhara_json_extract_str(sample_json, "code")
    ext_kav = akhara_json_extract_bool(sample_json, "kavach")
    if ext_kav != 1 or str_contains(ext_code, "say \"HI\"") != 1
        say "[ERR] JSON codec roundtrip mismatch"
        return 1
    say "[PASS] JSON codec escape/unescape & boolean parsing"

    // 2. Valid --kavach bare-silicon execution + ELF64 inspection
    valid_src = "fn main\n    b = alloc(64)\n    say \"AKHARA_SILICON_OK\"\n    free(b)\n    return 0\n\nmain()\n"
    r1 = akhara_compile_and_run_code(valid_src, 1, 901)
    if r1.rr_ok != 1 or r1.rr_run_exit != 0
        say "[ERR] Valid --kavach compilation or execution stopped: " + r1.rr_compiler_log
        return 1
    if str_contains(r1.rr_stdout, "AKHARA_SILICON_OK") != 1
        say "[ERR] Expected AKHARA_SILICON_OK in stdout, got: " + r1.rr_stdout
        return 1
    elf = r1.rr_elf
    if elf.er_valid != 1 or elf.er_type_name != "ET_DYN" or elf.er_rwe_count != 0 or len(elf.er_silicon_bytes) == 0
        say "[ERR] ELF security check unexpected: type=" + elf.er_type_name + " rwe=" + str(elf.er_rwe_count)
        return 1
    say "[PASS] --kavach valid compile & ELF64 audit (" + elf.er_type_name + ", RWE=" + str(elf.er_rwe_count) + ", entry=" + elf.er_entry_hex + ", bytes=" + str(elf.er_size) + ")"

    // 3. Negative --kavach guard verification (unguarded raw syscall outside silicon_ function must reject)
    rogue_src = "fn rogue_fn\n    return syscall(39, 0, 0, 0, 0, 0, 0)\n\nfn main\n    return rogue_fn()\n\nmain()\n"
    r2 = akhara_compile_and_run_code(rogue_src, 1, 902)
    if r2.rr_ok != 0
        say "[ERR] --kavach allowed unguarded raw syscall inside rogue_fn"
        return 1
    say "[PASS] --kavach blocked unguarded raw syscall outside silicon_* authority"
    say "✅ AKHARA_SELFTEST_COMPLETE"
    return 0

fn akhara_run_inspect file_path use_kavach
    if file_exists(file_path) == 0
        say "❌ File not found: " + file_path
        return 1
    res = akhara_compile_and_run_file(file_path, use_kavach, 501)
    elf = res.rr_elf
    say "── Lipi Sovereign Binary Inspector ──"
    say "Source      : " + file_path
    say "Kavach Mode : " + str(use_kavach)
    say "Compile Exit: " + str(res.rr_compile_exit) + " (" + str(res.rr_compile_us) + " us)"
    if res.rr_ok == 0
        say "Compiler Log:\n" + res.rr_compiler_log
        return 1
    say "ELF Type    : " + elf.er_type_name + " (" + elf.er_machine_name + ")"
    say "PHDR Count  : " + str(elf.er_phnum) + " | RWE Segments: " + str(elf.er_rwe_count)
    say "Entry Addr  : " + elf.er_entry_hex + " | Binary Size: " + str(elf.er_size) + " B"
    say "_start Bytes: " + elf.er_silicon_bytes
    say "Run Exit    : " + str(res.rr_run_exit) + " (" + str(res.rr_run_us) + " us)"
    say "Stdout      :\n" + res.rr_stdout
    return 0

fn main
    args = argv()
    argc = len(args)
    if argc <= 1
        return akhara_serve(8085, 0)

    cmd = get(args, 1)
    if cmd == "--selftest"
        return akhara_run_selftest()
    if cmd == "--inspect"
        if argc < 3
            say "Usage: lipi_akhara --inspect <file.lp> [--kavach]"
            return 1
        target = get(args, 2)
        use_kav = 0
        if argc >= 4 and get(args, 3) == "--kavach"
            use_kav = 1
        return akhara_run_inspect(target, use_kav)
    if cmd == "--oneshot-http"
        port = 18085
        cnt = 1
        if argc >= 3
            port = akhara_parse_int(get(args, 2), 18085)
        if argc >= 4
            cnt = akhara_parse_int(get(args, 3), 1)
        return akhara_serve(port, cnt)

    port = akhara_parse_int(cmd, 8085)
    return akhara_serve(port, 0)

main()
