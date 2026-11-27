// ==============================================================================
// 👑 WAVE CC SOVEREIGN TOOLING, W^X JIT, WASM PARITY & OS STDLIB REGRESSION SUITE
// File: tests/test_wave_cc_tooling_wasm_stdlib.lp
// 100% Pure LiPi | Zero Placeholders | Live End-to-End Execution Verification
// ==============================================================================
//
// Coverage Matrix:
//   CC1: lipidbg — ELF64 e_type/e_machine decode (ET_DYN/EXEC/REL, X86_64/AARCH64/RISCV),
//        live ptrace register reads (byte offsets), breakpoint hit + RIP rewind +
//        single-step + re-arm + resume, and live TTD single-step ring-buffer snapshots
//   CC2: lipifmt — syntax-safe formatting preserving <T>, dict<K,V>, nested <<>>,
//        Enum::Var, *mut/*const, &/&mut, default params, pub async fn, /* */, 'c', #, @!,
//        ..=, mixed {} inside indented blocks, atomic -w, idempotent --check, & --kavach build
//   CC3: lipilsp — live JSON-RPC zero false diagnostics (/* */, 'c', #, @!), no-staircase
//        formatting, pub async fn / enum / relative include definition with real column &
//        canonical file:/// URI, comment-skipping references, live completion & hover
//   CC4: aati — real SHA-256 cmd_hash (NIST "abc"), staging-before-verify rejecting tampered
//        bundles with zero leaked files, --trust-key pinning, unified install + verify-lock,
//        exact HOME= env lookup ignoring XDG_CONFIG_HOME=
//   CC5: W^X jit_engine — real SSA IR -> x86_64 machine code execution (arithmetic, calls,
//        loops) with 0 rwxp mappings in /proc/self/maps + fail-closed RWX/write guards,
//        live lipirepl variable & function persistence with zero double-munmap, & lipi --jit
//   CC6: WASM Parity (live V8 WebAssembly via node) — IEEE-754 say(3.5 + 1.25) == "4.75",
//        float locals/calls/struct fields/arrays/compound ops, ("ab" + "c") == "abc",
//        short-circuit 0 and bump() / 1 or bump(), dict literals/dict()/read/write/has/grow,
//        and >300 KB dynamic memory.grow + post-grow LPST strings
//   CC7: utso/os/* — @deprecated notices on scheduler/vfs/storage/ipc + real CLONE_VM
//        shared MAP_PRIVATE memory & stack_top in utso/os/thread.lp thread_create
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/socket"
import "utso/os/thread"
import "src/compiler/backend/jit/jit_engine"

global g_cc_passed = 0
global g_cc_failed = 0

fn cc_check cond label
    if cond == 1
        g_cc_passed = g_cc_passed + 1
        return 1
    end
    say "  FAIL [Wave CC]: " + label
    g_cc_failed = g_cc_failed + 1
    return 0
end

fn cc_unlink path
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0
end

fn cc_rmdir path
    syscall(84, path, 0, 0, 0, 0, 0)
    return 0
end

fn cc_mkdir path
    syscall(83, path, 493, 0, 0, 0, 0)
    return 0
end

fn cc_getcwd
    buf = malloc(1024)
    r = syscall(79, buf, 1024, 0, 0, 0, 0)
    res = "."
    if r > 1
        res = bytes_to_str(buf, r - 1)
    end
    free(buf, 1024)
    return res
end

fn cc_spawn_io work_dir cmd_path args stdin_path stdout_path extra_env
    // WHY: Pure Linux fork/exec helper supporting stdin redirection, stdout+stderr capture,
    // custom working directory, and explicit envp ordering for exact HOME= testing.
    argv = syscall(9, 0, 256, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < len(args) and i < 28
        mem_word_write(argv, (i + 1) * 8, get(args, i))
        i = i + 1
    end
    mem_word_write(argv, (i + 1) * 8, 0)

    envp = syscall(9, 0, 128, 3, 34, -1, 0)
    ei = 0
    if extra_env != 0 and len(extra_env) > 0
        while ei < len(extra_env) and ei < 14
            mem_word_write(envp, ei * 8, get(extra_env, ei))
            ei = ei + 1
        end
    else
        mem_word_write(envp, 0, "PATH=/usr/local/bin:/usr/bin:/bin")
        mem_word_write(envp, 8, "HOME=/tmp")
        ei = 2
    end
    mem_word_write(envp, ei * 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        if len(work_dir) > 0
            syscall(80, work_dir, 0, 0, 0, 0, 0)
        end
        if len(stdin_path) > 0
            ifd = syscall(2, stdin_path, 0, 0)
            if ifd >= 0
                syscall(33, ifd, 0, 0, 0, 0, 0)
                syscall(3, ifd, 0, 0, 0, 0, 0)
            end
        end
        if len(stdout_path) > 0
            ofd = syscall(2, stdout_path, 577, 420)
            if ofd >= 0
                syscall(33, ofd, 1, 0, 0, 0, 0)
                syscall(33, ofd, 2, 0, 0, 0, 0)
                syscall(3, ofd, 0, 0, 0, 0, 0)
            end
        end
        syscall(59, cmd_path, argv, envp, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)
    end

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_st = mem_word_read(st, 0)
    sig = raw_st & 127
    rc = 0
    if sig != 0
        rc = 128 + sig
    else
        rc = (raw_st / 256) % 256
    end
    syscall(11, argv, 256, 0, 0, 0, 0)
    syscall(11, envp, 128, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn cc_rm_rf path
    return cc_spawn_io("", "/bin/rm", ["-rf", path], "", "", 0)
end

fn cc_find_node
    // WHY: Discovers installed Node.js binary across standard system paths and PATH entries
    // so live V8 WebAssembly tests execute cleanly in both local and CI environments.
    if syscall(21, "/usr/bin/node", 1, 0, 0, 0, 0) == 0
        return "/usr/bin/node"
    end
    if syscall(21, "/usr/local/bin/node", 1, 0, 0, 0, 0) == 0
        return "/usr/local/bin/node"
    end
    if syscall(21, "/home/shafiullah/.nvm/versions/node/v20.20.2/bin/node", 1, 0, 0, 0, 0) == 0
        return "/home/shafiullah/.nvm/versions/node/v20.20.2/bin/node"
    end
    // Scan PATH from /proc/self/environ
    fd = syscall(2, "/proc/self/environ", 0, 0)
    if fd >= 0
        ebuf = malloc(65536)
        n = syscall(0, fd, ebuf, 65535, 0, 0, 0)
        syscall(3, fd, 0, 0, 0, 0, 0)
        i = 0
        path_val = ""
        while i < n
            st = i
            while i < n and mem_byte_read(ebuf, i) != 0
                i = i + 1
            end
            entry = bytes_to_str(ebuf + st, i - st)
            if str_starts_with(entry, "PATH=") == 1
                path_val = str_sub(entry, 5, len(entry))
                break
            end
            i = i + 1
        end
        free(ebuf, 65536)
        if len(path_val) > 0
            p = 0
            plen = len(path_val)
            while p < plen
                q = p
                while q < plen and char_at(path_val, q) != ":"
                    q = q + 1
                end
                if q > p
                    cand = str_sub(path_val, p, q) + "/node"
                    if syscall(21, cand, 1, 0, 0, 0, 0) == 0
                        return cand
                    end
                end
                p = q + 1
            end
        end
    end
    return ""
end

// ==============================================================================
// CC1: lipidbg Real Debugger (ELF decode, ptrace regs, BP rewind/resume, TTD)
// ==============================================================================
fn cc_write_minimal_elf path e_type e_machine
    // WHY: Synthesizes a 64-byte ELF64 header with controlled e_type & e_machine to prove
    // lipidbg decodes header fields dynamically instead of hardcoding ET_EXEC/EM_X86_64.
    buf = malloc(64)
    i = 0
    while i < 64
        mem_byte_write(buf, i, 0)
        i = i + 1
    end
    mem_byte_write(buf, 0, 127)
    mem_byte_write(buf, 1, 69)
    mem_byte_write(buf, 2, 76)
    mem_byte_write(buf, 3, 70)
    mem_byte_write(buf, 4, 2)
    mem_byte_write(buf, 5, 1)
    mem_byte_write(buf, 6, 1)
    mem_byte_write(buf, 16, e_type & 255)
    mem_byte_write(buf, 17, (e_type >> 8) & 255)
    mem_byte_write(buf, 18, e_machine & 255)
    mem_byte_write(buf, 19, (e_machine >> 8) & 255)
    file_write_mem(path, buf, 64)
    free(buf, 64)
    return 0
end

fn cc_test_lipidbg
    say "[CC1] Verifying lipidbg (ELF decode, ptrace regs, BP rewind/resume, real TTD)..."

    // 1a. Real ET_DYN / EM_X86_64 ELF decode on bin/lipidbg
    out1 = "/tmp/lipi_cc_dbg_elf1.out"
    rc1 = cc_spawn_io("", "./bin/lipidbg", ["./bin/lipidbg"], "", out1, 0)
    txt1 = file_read(out1)
    cc_check(rc1 == 0, "lipidbg ./bin/lipidbg exits 0")
    cc_check(str_contains(txt1, "ET_DYN") == 1 and str_contains(txt1, "EM_X86_64") == 1, "lipidbg decodes ET_DYN + EM_X86_64")

    // 1b. Synthetic ET_EXEC / EM_AARCH64 and ET_REL / EM_RISCV headers
    elf_a64 = "/tmp/lipi_cc_a64.elf"
    elf_rv = "/tmp/lipi_cc_rv64.elf"
    out2 = "/tmp/lipi_cc_dbg_elf2.out"
    out3 = "/tmp/lipi_cc_dbg_elf3.out"
    cc_write_minimal_elf(elf_a64, 2, 183)
    cc_write_minimal_elf(elf_rv, 1, 243)
    cc_spawn_io("", "./bin/lipidbg", [elf_a64], "", out2, 0)
    cc_spawn_io("", "./bin/lipidbg", [elf_rv], "", out3, 0)
    txt2 = file_read(out2)
    txt3 = file_read(out3)
    cc_check(str_contains(txt2, "ET_EXEC") == 1 and str_contains(txt2, "EM_AARCH64") == 1, "lipidbg decodes ET_EXEC + EM_AARCH64")
    cc_check(str_contains(txt3, "ET_REL") == 1 and str_contains(txt3, "EM_RISCV") == 1, "lipidbg decodes ET_REL + EM_RISCV")

    // 1c. Live ptrace registers + breakpoint hit + RIP rewind + single-step + re-arm + resume
    tgt_src = "/tmp/lipi_cc_dbg_tgt.lp"
    tgt_bin = "/tmp/lipi_cc_dbg_tgt"
    tgt_log = "/tmp/lipi_cc_dbg_build.log"
    file_write(tgt_src, "fn main()\n    say \"CC_DBG_LIVE_OK\"\n    return 0\nend\n")
    brc = cc_spawn_io("", "./bin/lipc", [tgt_src, "-o", tgt_bin], "", tgt_log, 0)
    cc_check(brc == 0, "compiled live lipidbg target binary")

    dbg_in = "/tmp/lipi_cc_dbg_live.in"
    dbg_out = "/tmp/lipi_cc_dbg_live.out"
    file_write(dbg_in, "r\nb +9\nb +9\nc\nr\nc\nq\n")
    lrc = cc_spawn_io("", "./bin/lipidbg", ["live", tgt_bin], dbg_in, dbg_out, 0)
    ltxt = file_read(dbg_out)
    cc_check(lrc == 0, "lipidbg live session exited cleanly")
    cc_check(str_contains(ltxt, "RIP:") == 1 and str_contains(ltxt, "RSP:") == 1, "lipidbg reads live ptrace registers via byte offsets")
    cc_check(str_contains(ltxt, "(INT3)") == 1, "lipidbg arms & hits software 0xCC breakpoint")
    cc_check(str_contains(ltxt, "ইতিমধ্যেই স্থাপিত") == 1, "lipidbg deduplicates repeated breakpoint at same address")
    cc_check(str_contains(ltxt, "CC_DBG_LIVE_OK") == 1 and str_contains(ltxt, "exit=0") == 1, "lipidbg rewinds RIP, steps over restored opcode, and resumes cleanly")

    // 1c-2. Missing target binary fails closed with non-zero exit code
    dbg_miss_out = "/tmp/lipi_cc_dbg_miss.out"
    mrc = cc_spawn_io("", "./bin/lipidbg", ["live", "/tmp/lipi_cc_definitely_missing_bin"], dbg_in, dbg_miss_out, 0)
    cc_check(mrc != 0, "lipidbg live rejects nonexistent target binary with non-zero exit")
    cc_unlink(dbg_miss_out)

    // 1d. Real ptrace TTD single-step ring buffer (live child + self-trace, zero hardcoded 0x401000)
    ttd_out = "/tmp/lipi_cc_dbg_ttd.out"
    ttd_self = "/tmp/lipi_cc_dbg_ttd_self.out"
    trc1 = cc_spawn_io("", "./bin/lipidbg", ["ttd", tgt_bin, "6"], "", ttd_out, 0)
    ttxt1 = file_read(ttd_out)
    cc_check(trc1 == 0 and str_contains(ttxt1, "PC (RIP):  0x") == 1 and str_contains(ttxt1, "SP (RSP):  0x") == 1, "lipidbg ttd records live child RIP/RSP frames")
    cc_check(str_contains(ttxt1, "0x401000") == 0, "lipidbg ttd contains zero fake hardcoded 0x401000 addresses")
    trc2 = cc_spawn_io("", "./bin/lipidbg", ["ttd"], "", ttd_self, 0)
    ttxt2 = file_read(ttd_self)
    cc_check(trc2 == 0 and str_contains(ttxt2, "PC (RIP):  0x") == 1, "lipidbg ttd no-arg self-trace records real frames")

    cc_unlink(out1)
    cc_unlink(out2)
    cc_unlink(out3)
    cc_unlink(elf_a64)
    cc_unlink(elf_rv)
    cc_unlink(tgt_src)
    cc_unlink(tgt_bin)
    cc_unlink(tgt_log)
    cc_unlink(dbg_in)
    cc_unlink(dbg_out)
    cc_unlink(ttd_out)
    cc_unlink(ttd_self)
    return 0
end

// ==============================================================================
// CC2: lipifmt Syntax-Safe Formatter + --kavach Build
// ==============================================================================
fn cc_test_lipifmt
    say "[CC2] Verifying lipifmt (syntax-safe generics/::/*mut/&mut/comments + --kavach)..."

    fsrc = ""
    fsrc = fsrc + "@! doc comment\n"
    fsrc = fsrc + "# hash comment\n"
    fsrc = fsrc + "/* multi-line\n   block comment */\n"
    fsrc = fsrc + "pub async fn compute(xs: list<i64>, m: list<dict<string, i64>>, b = 10) -> dict<string, i64>\n"
    fsrc = fsrc + "    c = 'z' /* inline */\n"
    fsrc = fsrc + "    p: *mut u8 = 0\n"
    fsrc = fsrc + "    q: *const u8 = 0\n"
    fsrc = fsrc + "    r = &xs\n"
    fsrc = fsrc + "    rm = &mut xs\n"
    fsrc = fsrc + "    v = Mode::Fast\n"
    fsrc = fsrc + "    d = { \"a\": 1 }\n"
    fsrc = fsrc + "    for i in 0..=10\n"
    fsrc = fsrc + "        if i < b and b > 0\n"
    fsrc = fsrc + "            say c\n"
    fsrc = fsrc + "        end\n"
    fsrc = fsrc + "    end\n"
    fsrc = fsrc + "    for item in [1, 2, 3]\n"
    fsrc = fsrc + "        if not (item == 2)\n"
    fsrc = fsrc + "            hx = 0x1e-1\n"
    fsrc = fsrc + "            am = &mut [1, 2]\n"
    fsrc = fsrc + "        end\n"
    fsrc = fsrc + "    end\n"
    fsrc = fsrc + "    return d\n"
    fsrc = fsrc + "end\n"

    fmt_p = "/tmp/lipi_cc_fmt.lp"
    fmt_log = "/tmp/lipi_cc_fmt.log"
    file_write(fmt_p, fsrc)
    rc_w = cc_spawn_io("", "./bin/lipifmt", ["-w", fmt_p], "", fmt_log, 0)
    cc_check(rc_w == 0, "lipifmt -w atomic rewrite exits 0")

    res = file_read(fmt_p)
    cc_check(str_contains(res, "list<i64>") == 1 and str_contains(res, "list < i64 >") == 0, "lipifmt preserves list<i64>")
    cc_check(str_contains(res, "dict<string, i64>") == 1, "lipifmt preserves dict<string, i64>")
    cc_check(str_contains(res, "list<dict<string, i64>>") == 1, "lipifmt preserves nested list<dict<string, i64>>")
    cc_check(str_contains(res, "Mode::Fast") == 1 and str_contains(res, "Mode:: Fast") == 0, "lipifmt preserves Enum::Var")
    cc_check(str_contains(res, "*mut u8") == 1 and str_contains(res, "*const u8") == 1, "lipifmt preserves *mut / *const")
    cc_check(str_contains(res, "&xs") == 1 and str_contains(res, "&mut xs") == 1, "lipifmt preserves &x and &mut x")
    cc_check(str_contains(res, "b = 10") == 1 and str_contains(res, "pub async fn compute") == 1, "lipifmt preserves pub async fn + default param b = 10")
    cc_check(str_contains(res, "0..=10") == 1 and str_contains(res, "'z'") == 1, "lipifmt preserves ..= and single-quoted 'z'")
    cc_check(str_contains(res, "/* inline */") == 1 and str_contains(res, "# hash comment") == 1 and str_contains(res, "@! doc comment") == 1, "lipifmt preserves /* */, #, and @! comments")
    cc_check(str_contains(res, "for item in [1, 2, 3]") == 1 and str_contains(res, "if not (item == 2)") == 1 and str_contains(res, "hx = 0x1e - 1") == 1 and str_contains(res, "am = &mut [1, 2]") == 1, "lipifmt preserves in [, not (, 0x1e - 1, and &mut [")

    rc_chk = cc_spawn_io("", "./bin/lipifmt", ["--check", fmt_p], "", fmt_log, 0)
    cc_check(rc_chk == 0, "lipifmt --check passes idempotently after -w")

    // Flat file (max_indent == 0) with comment '=', comment '{', and /* if fake */
    flat_p = "/tmp/lipi_cc_fmt_flat.lp"
    flat_out = "/tmp/lipi_cc_fmt_flat.out"
    file_write(flat_p, "fn f(a, b = 10) // a = b\nx = 1\n// comment {\n/* block\nif fake\n*/\ny = 2\nend\n")
    cc_spawn_io("", "./bin/lipifmt", [flat_p], "", flat_out, 0)
    ftxt = file_read(flat_out)
    cc_check(str_contains(ftxt, "    x = 1\n") == 1 and str_contains(ftxt, "    y = 2\n") == 1 and str_contains(ftxt, "        y = 2") == 0, "lipifmt flat mode ignores comments with '=' / '{' / block-comment keywords")

    // Mis-aligned dedent (0->4->2->0) must NOT collapse body statement to column 0
    ded_p = "/tmp/lipi_cc_fmt_ded.lp"
    ded_out = "/tmp/lipi_cc_fmt_ded.out"
    file_write(ded_p, "fn main()\n    x = 1\n  y = 2\nend\n")
    cc_spawn_io("", "./bin/lipifmt", [ded_p], "", ded_out, 0)
    dtxt = file_read(ded_out)
    cc_check(str_contains(dtxt, "    y = 2\n") == 1, "lipifmt preserves intermediate non-zero dedent inside block")
    cc_unlink(flat_p)
    cc_unlink(flat_out)
    cc_unlink(ded_p)
    cc_unlink(ded_out)

    kav_bin = "/tmp/lipi_cc_lipifmt_kavach"
    kav_log = "/tmp/lipi_cc_lipifmt_kavach.log"
    rc_k = cc_spawn_io("", "./bin/lipc", ["src/tools/lipifmt.lp", "-o", kav_bin, "--kavach"], "", kav_log, 0)
    cc_check(rc_k == 0, "src/tools/lipifmt.lp compiles cleanly under --kavach")

    cc_unlink(fmt_p)
    cc_unlink(fmt_log)
    cc_unlink(kav_bin)
    cc_unlink(kav_log)
    return 0
end

// ==============================================================================
// CC3: lipilsp Real Document-Aware JSON-RPC LSP
// ==============================================================================
fn cc_lsp_frame body
    return "Content-Length: " + str(len(body)) + "\r\n\r\n" + body
end

fn cc_test_lipilsp
    say "[CC3] Verifying lipilsp (live JSON-RPC diagnostics/format/def/refs/completion/hover)..."

    ldir = "/tmp/lipi_cc_lsp_dir"
    cc_rm_rf(ldir)
    cc_mkdir(ldir)
    hpath = ldir + "/helper.lp"
    mpath = ldir + "/main.lp"
    file_write(hpath, "pub async fn remote_calc(x)\n    return x + 1\nend\n")
    // Line 0: include "helper.lp"
    // Line 1: /* block ( [ { */
    // Line 2: # hash "unclosed
    // Line 3: @! doc 'a'
    // Line 4: enum Mode
    // Line 5:     Fast
    // Line 6: end
    // Line 7: pub async fn local_worker(n)
    // Line 8:     if n > 0
    // Line 9:         x = 'z'
    // Line 10:         // remote_calc comment
    // Line 11:         return remote_calc(n)
    // Line 12:     end
    // Line 13:     return 0
    // Line 14: end
    msrc_json = "include \\\"helper.lp\\\"\\n/* block ( [ { */\\n# hash \\\"unclosed\\n@! doc 'a'\\nenum Mode\\n    Fast\\nend\\npub async fn local_worker(n)\\n    if n > 0\\n        x = 'z'\\n        // remote_calc comment\\n        return remote_calc(n)\\n    end\\n    return 0\\nend\\n"
    muri = "file://" + mpath

    req = ""
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\",\"languageId\":\"lipi\",\"version\":1,\"text\":\"" + msrc_json + "\"}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"},\"position\":{\"line\":7,\"character\":15}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"},\"position\":{\"line\":11,\"character\":18}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"},\"position\":{\"line\":4,\"character\":6}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"textDocument/references\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"},\"position\":{\"line\":11,\"character\":18}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"},\"position\":{\"line\":13,\"character\":10}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"" + muri + "\"},\"position\":{\"line\":7,\"character\":15}}}")
    // Adversarial LSP checks: block-comment fake decl skipped, flat fn ver = "1.0" / comment '{' no staircase, unterminated /* diag
    uri_adv1 = "file://" + ldir + "/adv1.lp"
    src_adv1 = "/*\\nfn real_fn()\\n*/\\nfn real_fn()\\n    return 1\\nend\\nx = real_fn()\\n"
    uri_adv2 = "file://" + ldir + "/adv2.lp"
    src_adv2 = "fn ver = \\\"1.0\\\"\\n// comment {\\nx = 1\\n"
    uri_adv3 = "file://" + ldir + "/adv3.lp"
    src_adv3 = "/* unterminated\\nx = 1\\n"
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"" + uri_adv1 + "\",\"languageId\":\"lipi\",\"version\":1,\"text\":\"" + src_adv1 + "\"}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"" + uri_adv1 + "\"},\"position\":{\"line\":6,\"character\":6}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"" + uri_adv2 + "\",\"languageId\":\"lipi\",\"version\":1,\"text\":\"" + src_adv2 + "\"}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"" + uri_adv2 + "\"}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"" + uri_adv3 + "\",\"languageId\":\"lipi\",\"version\":1,\"text\":\"" + src_adv3 + "\"}}}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"shutdown\",\"params\":null}")
    req = req + cc_lsp_frame("{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}")

    lin = "/tmp/lipi_cc_lsp.in"
    lout = "/tmp/lipi_cc_lsp.out"
    file_write(lin, req)
    rc = cc_spawn_io("", "./bin/lipilsp", [], lin, lout, 0)
    resp = file_read(lout)

    cc_check(rc == 0, "lipilsp JSON-RPC session exits 0")
    cc_check(str_contains(resp, "\"diagnostics\":[]") == 1, "lipilsp diagnostics skips /* */, 'c', #, @! with 0 false positives")
    cc_check(str_contains(resp, "\"character\":13") == 1, "lipilsp definition computes real column (13) for pub async fn local_worker")
    cc_check(str_contains(resp, "file:///tmp/lipi_cc_lsp_dir/helper.lp") == 1, "lipilsp definition resolves relative include to canonical file:/// URI")
    cc_check(str_contains(resp, "\"character\":5") == 1, "lipilsp definition resolves enum Mode at real column 5")
    cc_check(str_contains(resp, "\"line\":10") == 0, "lipilsp references skips commented occurrence on line 10")
    cc_check(str_contains(resp, "\"label\":\"local_worker\"") == 1 and str_contains(resp, "\"label\":\"Mode\"") == 1, "lipilsp completion exposes live document-defined symbols")
    cc_check(str_contains(resp, "pub async fn local_worker") == 1, "lipilsp hover exposes live document symbol signature")
    cc_check(str_contains(resp, "                return 0") == 0, "lipilsp formatting does not staircase indentation-based blocks")
    cc_check(str_contains(resp, "\"id\":10,\"result\":{\"uri\":\"" + uri_adv1 + "\",\"range\":{\"start\":{\"line\":3,\"character\":3}") == 1, "lipilsp definition skips fake fn declaration inside /* ... */ block comment")
    cc_check(str_contains(resp, "newText\":\"fn ver = \\\"1.0\\\"\\n// comment {\\nx = 1\\n\"") == 1, "lipilsp flat formatting does not staircase on single-line fn= or comment '{'")
    cc_check(str_contains(resp, "Unterminated block comment") == 1, "lipilsp diagnostics reports unterminated /* block comment at EOF")

    cc_unlink(lin)
    cc_unlink(lout)
    cc_rm_rf(ldir)
    return 0
end

// ==============================================================================
// CC4: aati Security, SHA-256, Staging-Before-Verify, Keyring & Lockfile Integrity
// ==============================================================================
fn cc_test_aati
    say "[CC4] Verifying aati (SHA-256 hash, staging rollback, keyring, lockfile, exact HOME=)..."

    cwd = cc_getcwd()
    aati_bin = cwd + "/bin/aati"

    // 4a. Real SHA-256 cmd_hash against NIST test vector ("abc")
    abc_p = "/tmp/lipi_cc_abc.txt"
    hash_out = "/tmp/lipi_cc_hash.out"
    file_write(abc_p, "abc")
    hrc = cc_spawn_io("", aati_bin, ["hash", abc_p], "", hash_out, 0)
    htxt = file_read(hash_out)
    cc_check(hrc == 0 and str_contains(htxt, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") == 1, "aati hash outputs real NIST SHA-256 for 'abc'")

    // 4b. Exact HOME= lookup when XDG_CONFIG_HOME= precedes HOME= in envp
    w_home = "/tmp/lipi_cc_wrong_home"
    r_home = "/tmp/lipi_cc_real_home"
    cc_rm_rf(w_home)
    cc_rm_rf(r_home)
    cc_mkdir(w_home)
    cc_mkdir(r_home)
    kg_out = "/tmp/lipi_cc_kg.out"
    kg_env = ["PATH=/usr/bin:/bin", "XDG_CONFIG_HOME=" + w_home, "HOME=" + r_home]

    // 4c. Sign & pack temp package (sign auto-generates ~/.lipi/keys/ed25519.pub under exact HOME=)
    pkg_dir = "/tmp/lipi_cc_pkg_src"
    cc_rm_rf(pkg_dir)
    cc_mkdir(pkg_dir)
    cc_mkdir(pkg_dir + "/src")
    file_write(pkg_dir + "/aati.toml", "[package]\nname = \"cc_demo\"\nversion = \"1.0.0\"\n")
    file_write(pkg_dir + "/src/lib.lp", "fn demo_val()\n    return 77\nend\n")
    s_out = "/tmp/lipi_cc_sign.out"
    src1 = cc_spawn_io(pkg_dir, aati_bin, ["sign"], "", s_out, kg_env)
    cc_check(src1 == 0 and file_exists(pkg_dir + "/lipi.sig") == 1, "aati sign creates Ed25519 lipi.sig")
    cc_check(file_exists(r_home + "/.lipi/keys/ed25519.pub") == 1, "aati sign writes keypair to exact HOME= directory")
    cc_check(file_exists(w_home + "/.lipi/keys/ed25519.pub") == 0, "aati ignores XDG_CONFIG_HOME= when looking up HOME=")
    real_pub = str_trim(file_read(r_home + "/.lipi/keys/ed25519.pub"))

    wrong_key = "0000000000000000000000000000000000000000000000000000000000000000"
    v_bad = cc_spawn_io("", aati_bin, ["verify", pkg_dir, "--trust-key", wrong_key], "", s_out, kg_env)
    v_ok = cc_spawn_io("", aati_bin, ["verify", pkg_dir, "--trust-key", real_pub], "", s_out, kg_env)
    cc_check(v_bad != 0, "aati verify --trust-key rejects untrusted author pubkey")
    cc_check(v_ok == 0, "aati verify --trust-key accepts pinned author pubkey")

    bundle_good = pkg_dir + "/dist/cc_demo-1.0.0.aati"
    bundle_bad = "/tmp/lipi_cc_bad.aati"
    prc = cc_spawn_io(pkg_dir, aati_bin, ["pack", "."], "", s_out, kg_env)
    cc_check(prc == 0 and file_exists(bundle_good) == 1, "aati pack produces signed .aati bundle")

    // 4d. Tamper bundle -> install must reject AND leak zero files into actual aati/ install path!
    braw = file_read(bundle_good)
    btampered = str_replace(braw, "return 77", "return 99")
    file_write(bundle_bad, btampered)
    ws_bad = "/tmp/lipi_cc_ws_bad"
    cc_rm_rf(ws_bad)
    cc_mkdir(ws_bad)
    irc_bad = cc_spawn_io(ws_bad, aati_bin, ["install", bundle_bad], "", s_out, kg_env)
    cc_check(irc_bad != 0, "aati install rejects tampered .aati bundle")
    cc_check(file_exists(ws_bad + "/aati/lipi_cc_bad/src/lib.lp") == 0 and file_exists(ws_bad + "/aati/cc_demo/src/lib.lp") == 0 and file_exists(ws_bad + "/aati/cc_demo-1.0.0/src/lib.lp") == 0, "aati staging-before-verify leaks zero files into aati/ on signature failure")

    // 4e. Install valid bundle -> unified lockfile hash matches verify-lock
    ws_good = "/tmp/lipi_cc_ws_good"
    cc_rm_rf(ws_good)
    cc_mkdir(ws_good)
    irc_ok = cc_spawn_io(ws_good, aati_bin, ["install", bundle_good], "", s_out, kg_env)
    cc_check(irc_ok == 0 and file_exists(ws_good + "/aati.lock") == 1, "aati install succeeds and records aati.lock")
    vl_rc = cc_spawn_io(ws_good, aati_bin, ["verify-lock", "aati.lock"], "", s_out, kg_env)
    cc_check(vl_rc == 0, "aati verify-lock matches unified install lockfile hash")

    // 4f. Empty checksum in TOML aati.lock must fail closed (never pass without 64-hex SHA-256!)
    file_write(ws_good + "/bad_empty.lock", "[[aati]]\nname = \"cc_demo-1.0.0\"\nversion = \"1.0.0\"\nchecksum = \"\"\n")
    vl_emp = cc_spawn_io(ws_good, aati_bin, ["verify-lock", "bad_empty.lock"], "", s_out, kg_env)
    cc_check(vl_emp != 0, "aati verify-lock rejects empty checksum fail-closed")

    // 4g. Zero-arg `aati install` enforces [dependencies] SemVer constraints
    ws_sv = "/tmp/lipi_cc_ws_sv"
    cc_rm_rf(ws_sv)
    cc_mkdir(ws_sv)
    cc_mkdir(ws_sv + "/aati")
    cc_mkdir(ws_sv + "/aati/svlib")
    file_write(ws_sv + "/aati/svlib/aati.toml", "[package]\nname = \"svlib\"\nversion = \"1.0.0\"\n")
    file_write(ws_sv + "/aati.toml", "[package]\nname = \"app\"\nversion = \"1.0.0\"\n\n[dependencies]\nsvlib = \">=2.0.0\"\n")
    sv_bad = cc_spawn_io(ws_sv, aati_bin, ["install"], "", s_out, kg_env)
    cc_check(sv_bad != 0, "aati zero-arg install rejects incompatible SemVer (>=2.0.0 vs 1.0.0)")
    file_write(ws_sv + "/aati.toml", "[package]\nname = \"app\"\nversion = \"1.0.0\"\n\n[dependencies]\nsvlib = \"^1.0.0\"\n")
    sv_ok = cc_spawn_io(ws_sv, aati_bin, ["install"], "", s_out, kg_env)
    cc_check(sv_ok == 0, "aati zero-arg install accepts compatible SemVer (^1.0.0 vs 1.0.0)")
    cc_rm_rf(ws_sv)

    // 4h. Live mock TCP registry asserts exact Authorization: Bearer header from `aati publish`
    srv_fd = socket_create()
    opt_b = malloc(4)
    mem_byte_write(opt_b, 0, 1)
    mem_byte_write(opt_b, 1, 0)
    mem_byte_write(opt_b, 2, 0)
    mem_byte_write(opt_b, 3, 0)
    syscall(54, srv_fd, 1, 2, opt_b, 4, 0)
    free(opt_b, 4)
    addr_b = malloc(16)
    b_rc = socket_bind(srv_fd, addr_b, 19877)
    free(addr_b, 16)
    if b_rc == 0
        socket_listen(srv_fd, 4)
        wire_p = "/tmp/lipi_cc_pub_wire.txt"
        cc_unlink(wire_p)
        spid = syscall(57, 0, 0, 0, 0, 0, 0)
        if spid == 0
            cfd = socket_accept(srv_fd)
            rbuf = malloc(8192)
            nr = syscall(0, cfd, rbuf, 8191, 0, 0, 0)
            if nr > 0 file_write(wire_p, bytes_to_str(rbuf, nr)) end
            free(rbuf, 8192)
            resp_ok = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
            syscall(1, cfd, resp_ok, len(resp_ok), 0, 0, 0)
            socket_close(cfd)
            socket_close(srv_fd)
            syscall(60, 0, 0, 0, 0, 0, 0)
        end
        socket_close(srv_fd)
        pub_env = ["PATH=/usr/bin:/bin", "HOME=" + r_home, "AATI_TOKEN=WaveCC_Bearer_77"]
        pub_rc = cc_spawn_io(pkg_dir, aati_bin, ["publish", ".", "http://127.0.0.1:19877"], "", s_out, pub_env)
        wst = malloc(8)
        syscall(61, spid, wst, 0, 0, 0, 0)
        free(wst, 8)
        wire_txt = file_read(wire_p)
        cc_check(pub_rc == 0 and str_contains(wire_txt, "Authorization: Bearer WaveCC_Bearer_77") == 1, "aati publish sends Authorization: Bearer <AATI_TOKEN> over live TCP")
        cc_unlink(wire_p)
    else
        socket_close(srv_fd)
        cc_check(0, "mock TCP bind on 19877 for aati publish test")
    end

    cc_unlink(abc_p)
    cc_unlink(hash_out)
    cc_unlink(kg_out)
    cc_unlink(s_out)
    cc_unlink(bundle_good)
    cc_unlink(bundle_bad)
    cc_rm_rf(w_home)
    cc_rm_rf(r_home)
    cc_rm_rf(pkg_dir)
    cc_rm_rf(ws_bad)
    cc_rm_rf(ws_good)
    return 0
end

// ==============================================================================
// CC5: W^X JIT Engine (Live Execution + 0 RWX) & lipirepl Persistence
// ==============================================================================
fn cc_test_jit_and_repl
    say "[CC5] Verifying W^X jit_engine live x86_64 execution (0 RWX) & lipirepl persistence..."

    // Build SSA IR module with add_one(x), calc_ops(a, b), and sum_loop(n)
    m = ir_module_new("cc_jit_mod")

    // Helper: fn add_one(x) -> x + 1
    f0 = ir_function_new("add_one", "i64")
    p_x = ssa_value_new_arg("x", "i64")
    ir_function_add_param(f0, p_x)
    b0 = ir_function_create_block(f0, "entry")
    v_one = ssa_value_new_const(1, "i64")
    v_res0 = ir_function_new_val(f0, "i64")
    basic_block_append_inst(b0, ir_build_binop(1, OP_ADD, v_res0, p_x, v_one))
    basic_block_append_inst(b0, ir_build_ret(2, v_res0))
    ir_module_add_function(m, f0)

    // Arithmetic + call: fn calc_ops(a, b) -> add_one(((a + b) * (a - b)) / 2 + (a % b))
    // For (10, 4): ((14 * 6) / 2) + (10 % 4) = 42 + 2 = 44 -> add_one(44) = 45
    f1 = ir_function_new("calc_ops", "i64")
    p_a = ssa_value_new_arg("a", "i64")
    p_b = ssa_value_new_arg("b", "i64")
    ir_function_add_param(f1, p_a)
    ir_function_add_param(f1, p_b)
    b1 = ir_function_create_block(f1, "entry")
    v_add = ir_function_new_val(f1, "i64")
    v_sub = ir_function_new_val(f1, "i64")
    v_mul = ir_function_new_val(f1, "i64")
    v_div = ir_function_new_val(f1, "i64")
    v_mod = ir_function_new_val(f1, "i64")
    v_sum = ir_function_new_val(f1, "i64")
    v_fin = ir_function_new_val(f1, "i64")
    basic_block_append_inst(b1, ir_build_binop(10, OP_ADD, v_add, p_a, p_b))
    basic_block_append_inst(b1, ir_build_binop(11, OP_SUB, v_sub, p_a, p_b))
    basic_block_append_inst(b1, ir_build_binop(12, OP_MUL, v_mul, v_add, v_sub))
    basic_block_append_inst(b1, ir_build_binop(13, OP_DIV, v_div, v_mul, ssa_value_new_const(2, "i64")))
    basic_block_append_inst(b1, ir_build_binop(14, OP_MOD, v_mod, p_a, p_b))
    basic_block_append_inst(b1, ir_build_binop(15, OP_ADD, v_sum, v_div, v_mod))
    basic_block_append_inst(b1, ir_build_call(16, v_fin, "add_one", [v_sum]))
    basic_block_append_inst(b1, ir_build_ret(17, v_fin))
    ir_module_add_function(m, f1)

    // Loop: fn sum_loop(n) -> 1 + 2 + ... + n
    f2 = ir_function_new("sum_loop", "i64")
    p_n = ssa_value_new_arg("n", "i64")
    ir_function_add_param(f2, p_n)
    b_en = ir_function_create_block(f2, "entry")
    b_hd = ir_function_create_block(f2, "head")
    b_bd = ir_function_create_block(f2, "body")
    b_ex = ir_function_create_block(f2, "exit")
    p_acc = ir_function_new_val(f2, "i64")
    p_i = ir_function_new_val(f2, "i64")
    basic_block_append_inst(b_en, ir_build_alloca(20, p_acc, "i64", ssa_value_new_const(8, "i64")))
    basic_block_append_inst(b_en, ir_build_alloca(21, p_i, "i64", ssa_value_new_const(8, "i64")))
    basic_block_append_inst(b_en, ir_build_store(22, ssa_value_new_const(0, "i64"), p_acc))
    basic_block_append_inst(b_en, ir_build_store(23, ssa_value_new_const(1, "i64"), p_i))
    basic_block_append_inst(b_en, ir_build_jmp(24, b_hd.label))

    v_ci = ir_function_new_val(f2, "i64")
    v_cmp = ir_function_new_val(f2, "i64")
    basic_block_append_inst(b_hd, ir_build_load(25, v_ci, p_i))
    basic_block_append_inst(b_hd, ir_build_cmp(26, CMP_SLE, v_cmp, v_ci, p_n))
    basic_block_append_inst(b_hd, ir_build_br(27, v_cmp, b_bd.label, b_ex.label))

    v_ca = ir_function_new_val(f2, "i64")
    v_ci2 = ir_function_new_val(f2, "i64")
    v_na = ir_function_new_val(f2, "i64")
    v_ni = ir_function_new_val(f2, "i64")
    basic_block_append_inst(b_bd, ir_build_load(28, v_ca, p_acc))
    basic_block_append_inst(b_bd, ir_build_load(29, v_ci2, p_i))
    basic_block_append_inst(b_bd, ir_build_binop(30, OP_ADD, v_na, v_ca, v_ci2))
    basic_block_append_inst(b_bd, ir_build_store(31, v_na, p_acc))
    basic_block_append_inst(b_bd, ir_build_binop(32, OP_ADD, v_ni, v_ci2, ssa_value_new_const(1, "i64")))
    basic_block_append_inst(b_bd, ir_build_store(33, v_ni, p_i))
    basic_block_append_inst(b_bd, ir_build_jmp(34, b_hd.label))

    v_out = ir_function_new_val(f2, "i64")
    basic_block_append_inst(b_ex, ir_build_load(35, v_out, p_acc))
    basic_block_append_inst(b_ex, ir_build_ret(36, v_out))
    ir_module_add_function(m, f2)

    eng = jit_engine_new()
    ok = jit_compile_ir_to_memory(eng, m)
    cc_check(ok.success == 1, "jit_compile_ir_to_memory succeeds with strict W^X RX transition")
    mb0 = get(eng.memory_blocks, 0)
    cc_check(mb0.is_exec == 1, "JIT memory block transitioned to RX (is_exec == 1)")
    cc_check(jit_mem_protect_rwx(mb0) < 0, "jit_mem_protect_rwx fails closed (zero RWX allowed)")
    cc_check(jit_mem_write_byte(mb0, 0, 144) == 0, "jit_mem_write_byte refuses writes to RX region")

    // Verify zero rwxp mappings exist in /proc/self/maps while JIT code is live
    maps_txt = file_read("/proc/self/maps")
    cc_check(str_contains(maps_txt, "rwxp") == 0, "/proc/self/maps has ZERO rwxp mappings while JIT is live")

    p_calc = jit_lookup_symbol(eng, "calc_ops")
    p_sum = jit_lookup_symbol(eng, "sum_loop")
    cc_check(p_calc != 0 and p_sum != 0, "jit_lookup_symbol resolves calc_ops and sum_loop")
    cc_check(jit_invoke_fn2(p_calc, 10, 4) == 45, "live W^X JIT calc_ops(10, 4) == 45 (arith + call)")
    cc_check(jit_invoke_fn1(p_sum, 10) == 55, "live W^X JIT sum_loop(10) == 55")
    cc_check(jit_invoke_fn1(p_sum, 100) == 5050, "live W^X JIT sum_loop(100) == 5050")
    jit_engine_free(eng)

    // High-level jit_compile_and_exec (proves zero IRModule/ASTProgram field collision SIGSEGV) + INT64_MIN/-1 + unresolved call fail-closed
    cc_check(jit_compile_and_exec("@fn main()\n  return 21 + 21\n@end\n") == 42, "jit_compile_and_exec compiles & executes LiPi source in W^X RAM == 42")
    mbad = ir_module_new("cc_bad_call")
    fbad = ir_function_new("bad_caller", "i64")
    bbad = ir_function_create_block(fbad, "entry")
    vbad = ir_function_new_val(fbad, "i64")
    basic_block_append_inst(bbad, ir_build_call(1, vbad, "missing_sym", []))
    basic_block_append_inst(bbad, ir_build_ret(2, vbad))
    ir_module_add_function(mbad, fbad)
    eng_bad = jit_engine_new()
    c_bad = jit_compile_ir_to_memory(eng_bad, mbad)
    cc_check(c_bad.success == 0, "jit_compile_ir_to_memory fails closed on unresolved OP_CALL target")
    jit_engine_free(eng_bad)

    // Live lipirepl persistence, assignment-with-==, multi-line if block & zero double-munmap crash
    rin = "/tmp/lipi_cc_repl.in"
    rout = "/tmp/lipi_cc_repl.out"
    file_write(rin, "x = 10\neq_ok = (x == 10)\ny = x + 32\nif eq_ok == 1\nz = y + 1\nend\nfn triple(n)\nreturn n * 3\nend\ntriple(z)\n:quit\n")
    rrc = cc_spawn_io("", "./bin/lipirepl", [], rin, rout, 0)
    rtxt = file_read(rout)
    cc_check(rrc == 0, "lipirepl exits 0 with zero double-munmap crash")
    cc_check(str_contains(rtxt, "129") == 1, "lipirepl persists vars, == assignments, multi-line if blocks & fns (triple(43) == 129)")

    // Verify lipi run --jit reports honest mode (no misleading Zero Disk Latency theater)
    j_src = "/tmp/lipi_cc_jrun.lp"
    j_out = "/tmp/lipi_cc_jrun.out"
    file_write(j_src, "fn main()\n    say 21 + 21\n    return 0\nend\n")
    jrc = cc_spawn_io("", "./bin/lipi", ["run", "--jit", j_src], "", j_out, 0)
    jtxt = file_read(j_out)
    cc_check(jrc == 0 and str_contains(jtxt, "42") == 1, "lipi run --jit executes program cleanly")
    cc_check(str_contains(jtxt, "Zero Disk Latency") == 0, "lipi run --jit omits misleading Zero Disk Latency claim")

    cc_unlink(rin)
    cc_unlink(rout)
    cc_unlink(j_src)
    cc_unlink(j_out)
    return 0
end

// ==============================================================================
// CC6: Live V8 WebAssembly (node) Parity Verification
// ==============================================================================
fn cc_test_wasm_live
    say "[CC6] Verifying WASM backend parity LIVE in V8 WebAssembly (node)..."

    node_bin = cc_find_node()
    cc_check(len(node_bin) > 0, "discovered node binary for live V8 WebAssembly execution")
    if len(node_bin) == 0
        return 0
    end

    wsrc = ""
    wsrc = wsrc + "struct Pt\n"
    wsrc = wsrc + "    px: float\n"
    wsrc = wsrc + "    py: float\n"
    wsrc = wsrc + "end\n"
    wsrc = wsrc + "fn add_f(a: float, b: float) -> float\n"
    wsrc = wsrc + "    return a + b\n"
    wsrc = wsrc + "end\n"
    wsrc = wsrc + "fn eq_str(a, b)\n"
    wsrc = wsrc + "    return a == b\n"
    wsrc = wsrc + "end\n"
    wsrc = wsrc + "fn bump(c)\n"
    wsrc = wsrc + "    c[0] = c[0] + 1\n"
    wsrc = wsrc + "    return 1\n"
    wsrc = wsrc + "end\n"
    wsrc = wsrc + "fn main()\n"
    wsrc = wsrc + "    say(3.5 + 1.25)\n"
    wsrc = wsrc + "    f = 10.0\n"
    wsrc = wsrc + "    f += 2.5\n"
    wsrc = wsrc + "    f -= 0.5\n"
    wsrc = wsrc + "    f *= 2.0\n"
    wsrc = wsrc + "    f /= 4.0\n"
    wsrc = wsrc + "    say(f)\n"
    wsrc = wsrc + "    say(add_f(1.25, 2.5))\n"
    wsrc = wsrc + "    p = Pt(1.5, 2.25)\n"
    wsrc = wsrc + "    p.px += 0.75\n"
    wsrc = wsrc + "    say(p.px)\n"
    wsrc = wsrc + "    fa = [1.5, 2.5]\n"
    wsrc = wsrc + "    fa[1] += 0.5\n"
    wsrc = wsrc + "    say(fa[1])\n"
    wsrc = wsrc + "    say((\"ab\" + \"c\") == \"abc\")\n"
    wsrc = wsrc + "    say((\"ab\" + \"c\") != \"abc\")\n"
    wsrc = wsrc + "    say(eq_str(\"ab\" + \"c\", \"abc\"))\n"
    wsrc = wsrc + "    cnt = [0]\n"
    wsrc = wsrc + "    ra = 0 and bump(cnt)\n"
    wsrc = wsrc + "    ro = 1 or bump(cnt)\n"
    wsrc = wsrc + "    say(cnt[0])\n"
    wsrc = wsrc + "    rb = 1 and bump(cnt)\n"
    wsrc = wsrc + "    rc2 = 0 or bump(cnt)\n"
    wsrc = wsrc + "    say(cnt[0])\n"
    wsrc = wsrc + "    d = { \"alpha\": 10 }\n"
    wsrc = wsrc + "    d[\"al\" + \"pha\"] = 15\n"
    wsrc = wsrc + "    d[\"beta\"] = 20\n"
    wsrc = wsrc + "    say(d[\"alpha\"] + d[\"beta\"])\n"
    wsrc = wsrc + "    say(has_key(d, \"alpha\"))\n"
    wsrc = wsrc + "    say(d.has(\"missing\"))\n"
    wsrc = wsrc + "    d2 = dict()\n"
    wsrc = wsrc + "    k = 0\n"
    wsrc = wsrc + "    while k < 25\n"
    wsrc = wsrc + "        d2[k] = k * 3\n"
    wsrc = wsrc + "        k += 1\n"
    wsrc = wsrc + "    end\n"
    wsrc = wsrc + "    say(d2[20])\n"
    wsrc = wsrc + "    big = malloc(350000)\n"
    wsrc = wsrc + "    mem_byte_write(big, 349999, 77)\n"
    wsrc = wsrc + "    say(mem_byte_read(big, 349999))\n"
    wsrc = wsrc + "    ps = \"grow_\" + \"ok\"\n"
    wsrc = wsrc + "    say(ps)\n"
    wsrc = wsrc + "    return 0\n"
    wsrc = wsrc + "end\n"

    runner_js = "import fs from 'node:fs';\nconst bytes = fs.readFileSync(process.argv[2]);\nlet out = ''; let mem;\nconst { instance } = await WebAssembly.instantiate(bytes, { wasi_snapshot_preview1: { fd_write(fd, iovs, len, nw) { const v = new DataView(mem.buffer); let w = 0; for (let i = 0; i < len; i++) { const p = v.getUint32(iovs + i * 8, true); const l = v.getUint32(iovs + i * 8 + 4, true); out += Buffer.from(new Uint8Array(mem.buffer, p, l)).toString('utf8'); w += l; } v.setUint32(nw, w, true); return 0; } } });\nmem = instance.exports.memory;\ninstance.exports._start();\nprocess.stdout.write(out);\n"

    wp = "/tmp/lipi_cc_wasm.lp"
    wb = "/tmp/lipi_cc_wasm.wasm"
    wl = "/tmp/lipi_cc_wasm.log"
    wj = "/tmp/lipi_cc_wasi.mjs"
    wo = "/tmp/lipi_cc_wasm.out"
    file_write(wp, wsrc)
    file_write(wj, runner_js)

    crc = cc_spawn_io("", "./bin/lipc", [wp, "--target=wasm", "-o", wb], "", wl, 0)
    cc_check(crc == 0 and file_exists(wb) == 1, "compiled WASM parity module cleanly")

    rrc = cc_spawn_io("", node_bin, [wj, wb], "", wo, 0)
    wout = file_read(wo)
    expected = "4.75\n6.0\n3.75\n2.25\n3.0\n1\n0\n1\n0\n2\n35\n1\n0\n60\n77\ngrow_ok\n"
    cc_check(rrc == 0, "live V8 WebAssembly execution exited 0 without trapping")
    cc_check(wout == expected, "V8 WASM output matches exact expected 16 lines (float/str==/short-circuit/dict/memory.grow)")

    // Verify 2^32-page i32 wraparound OOM request traps cleanly instead of bypassing memory.grow
    wp_oom = "/tmp/lipi_cc_wasm_oom.lp"
    wb_oom = "/tmp/lipi_cc_wasm_oom.wasm"
    wo_oom = "/tmp/lipi_cc_wasm_oom.out"
    file_write(wp_oom, "fn main()\n    p = malloc(281474976907264)\n    say(p)\n    return 0\nend\n")
    cc_spawn_io("", "./bin/lipc", [wp_oom, "--target=wasm", "-o", wb_oom], "", wl, 0)
    oom_rc = cc_spawn_io("", node_bin, [wj, wb_oom], "", wo_oom, 0)
    cc_check(oom_rc != 0, "V8 WASM bump_alloc traps cleanly on >4GiB / 2^32-page wraparound malloc")
    cc_unlink(wp_oom)
    cc_unlink(wb_oom)
    cc_unlink(wo_oom)

    cc_unlink(wp)
    cc_unlink(wb)
    cc_unlink(wl)
    cc_unlink(wj)
    cc_unlink(wo)
    return 0
end

// ==============================================================================
// CC7: utso/os/* @deprecated Notices & Real CLONE_VM thread_create
// ==============================================================================
fn cc_test_os_hygiene_and_thread
    say "[CC7] Verifying utso/os/* @deprecated notices & real CLONE_VM thread_create..."

    cc_check(str_contains(file_read("utso/os/scheduler.lp"), "@deprecated") == 1, "utso/os/scheduler.lp has @deprecated notice")
    cc_check(str_contains(file_read("utso/os/vfs.lp"), "@deprecated") == 1, "utso/os/vfs.lp has @deprecated notice")
    cc_check(str_contains(file_read("utso/os/storage.lp"), "@deprecated") == 1, "utso/os/storage.lp has @deprecated notice")
    cc_check(str_contains(file_read("utso/os/ipc.lp"), "@deprecated") == 1, "utso/os/ipc.lp has @deprecated notice")

    // Allocate MAP_PRIVATE buffer (flags=34) + 64KB thread stack: only real CLONE_VM shares MAP_PRIVATE writes!
    priv_buf = syscall(9, 0, 4096, 3, 34, -1, 0)
    mem_word_write(priv_buf, 0, 0)
    t_stack = syscall(9, 0, 65536, 3, 34, -1, 0)
    t_top = t_stack + 65536
    w_st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(w_st, 0, 0)

    child_tid = thread_create(t_top)
    if child_tid == 0
        mem_word_write(priv_buf, 0, 322420958)
        syscall(60, 0, 0, 0, 0, 0, 0)
    end
    cc_check(child_tid > 0, "thread_create(stack_top) spawned real kernel thread tid > 0")
    syscall(61, child_tid, w_st, 1073741824, 0, 0, 0)
    observed = mem_word_read(priv_buf, 0)
    cc_check(observed == 322420958, "CLONE_VM thread shared MAP_PRIVATE write back to parent (0x1337C0DE)")

    syscall(11, priv_buf, 4096, 0, 0, 0, 0)
    syscall(11, t_stack, 65536, 0, 0, 0, 0)
    syscall(11, w_st, 8, 0, 0, 0, 0)
    return 0
end

fn main()
    say "========================================================================"
    say "👑 WAVE CC SOVEREIGN TOOLING, W^X JIT, WASM PARITY & OS STDLIB SUITE"
    say "========================================================================"
    cc_test_lipidbg()
    cc_test_lipifmt()
    cc_test_lipilsp()
    cc_test_aati()
    cc_test_jit_and_repl()
    cc_test_wasm_live()
    cc_test_os_hygiene_and_thread()

    say "========================================================================"
    say "Wave CC Results: " + str(g_cc_passed) + " passed, " + str(g_cc_failed) + " failed"
    say "========================================================================"
    if g_cc_failed == 0
        say "PASS: Wave CC Tooling, W^X JIT, WASM Parity & OS Stdlib Suite"
        return 0
    end
    exit(1)
end
