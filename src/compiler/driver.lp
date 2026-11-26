// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DRIVER (src/compiler/driver.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Acts as the canonical programmatic and CLI entry point for the micro-architectural
//    compiler, decoupling command-line options from internal compiler stages.
// 2. Recursive Dependency Scanner: Automatically resolves and bundles all 'import'
//    and 'include' directives into a consolidated module stream with cycle prevention.
// 3. Bilingual Diagnostic Reporting: Emits terminal output in both English and Bengali,
//    honoring LiPi's national identity while adhering to universal UNIX standards.
// 4. Telemetry & Profiling: Captures phase-by-phase microsecond timings to identify
//    bottlenecks across lexing, parsing, and register allocation.
// ==============================================================================

include "src/compiler/pipeline.lp"

// ── 1. Recursive Dependency Scanner & Source Bundler ─────────────────────────

fn compiler_driver_dirname p
    // WHY: Pure string path directory extractor with zero external dependencies.
    i = len(p) - 1
    while i >= 0
        if mem_byte_read(p, i) == 47 // 47 is '/'
            if i == 0
                return "/"
            return str_sub(p, 0, i)
        i = i - 1
    return "."

fn compiler_driver_match_kw content p kw
    // WHY: Zero-allocation direct silicon byte comparison for keywords and directives.
    kw_len = len(kw)
    if p + kw_len > len(content)
        return 0
    k = 0
    while k < kw_len
        if mem_byte_read(content, p + k) != mem_byte_read(kw, k)
            return 0
        k = k + 1
    return 1

fn compiler_driver_streq s1 s2
    // WHY: Direct silicon byte-for-byte string comparison. Completely immune to pointer
    // inequality, virtual address offsets, and missing STR0 object headers.
    l1 = len(s1)
    l2 = len(s2)
    if l1 != l2
        return 0
    si = 0
    while si < l1
        if mem_byte_read(s1, si) != mem_byte_read(s2, si)
            return 0
        si = si + 1
    return 1

fn compiler_driver_starts_with s prefix
    // WHY: Zero-allocation direct silicon byte prefix comparison.
    slen = len(s)
    plen = len(prefix)
    if slen < plen
        return 0
    k = 0
    while k < plen
        if mem_byte_read(s, k) != mem_byte_read(prefix, k)
            return 0
        k = k + 1
    return 1

fn compiler_driver_has_include content
    // WHY: High-speed zero-allocation prefix scanner to identify whether a source file contains
    // any include/import/from/pub statements requiring bundler transformation.
    p = 0
    clen = len(content)
    while p < clen
        while p < clen and (mem_byte_read(content, p) == 32 or mem_byte_read(content, p) == 9)
            p = p + 1
        if p < clen
            b0 = mem_byte_read(content, p)
            if b0 == 105 // 'i'
                if compiler_driver_match_kw(content, p, "include ") == 1
                    return 1
                if compiler_driver_match_kw(content, p, "import ") == 1
                    return 1
            elif b0 == 102 // 'f'
                if compiler_driver_match_kw(content, p, "from ") == 1
                    return 1
            elif b0 == 112 // 'p'
                if compiler_driver_match_kw(content, p, "pub ") == 1
                    return 1
            elif b0 == 64 // '@'
                if compiler_driver_match_kw(content, p, "@include ") == 1
                    return 1
                if compiler_driver_match_kw(content, p, "@use ") == 1
                    return 1
                if compiler_driver_match_kw(content, p, "@অন্তর্ভুক্ত ") == 1
                    return 1
            elif compiler_driver_match_kw(content, p, "অন্তর্ভুক্ত ") == 1
                return 1
            elif compiler_driver_match_kw(content, p, "থেকে ") == 1
                return 1
        while p < clen and mem_byte_read(content, p) != 10
            p = p + 1
        if p < clen and mem_byte_read(content, p) == 10
            p = p + 1
    return 0

fn compiler_driver_join_chunks chunks
    // WHY: Single-pass O(N) ERMS ByteBuffer join eliminates all intermediate string allocations.
    n = chunks.len()
    if n == 0
        return ""
    end
    if n == 1
        return chunks[0]
    end
    jb = buf_new(8192)
    i = 0
    while i < n
        c = chunks[i]
        if len(c) > 0
            buf_write_str(jb, c)
        end
        i = i + 1
    end
    out = buf_to_str(jb)
    buf_free(jb)
    return out

fn compiler_driver_resolve_std target
    // WHY: Seamlessly translates developer-friendly short primitive syntax ('utso/io', 'utso/memory')
    // and legacy paths ('std/*', 'universe/*') into canonical sovereign paths without breaking changes.
    // 1. Short Developer-Friendly Sovereign Primitives:
    if target == "utso/io" or target == "utso/io.lp" return "utso/io.lp"
    if target == "utso/mem" or target == "utso/memory" or target == "utso/memory.lp" return "utso/memory.lp"
    if target == "utso/str" or target == "utso/string" or target == "utso/string.lp" return "utso/string.lp"
    if target == "utso/unicode" or target == "utso/unicode.lp" return "utso/unicode.lp"
    if target == "utso/math" or target == "utso/math.lp" return "utso/math.lp"
    if target == "utso/collections" or target == "utso/collections.lp" return "utso/collections.lp"
    if target == "utso/socket" or target == "utso/socket.lp" or target == "utso/net" return "utso/socket.lp"
    if target == "utso/crypto" or target == "utso/crypto.lp" return "utso/crypto.lp"
    if target == "utso/syscalls" or target == "utso/syscalls.lp" or target == "utso/os" return "utso/syscalls.lp"
    if target == "utso/time" or target == "utso/time.lp" return "utso/time.lp"
    if target == "utso/fmt" or target == "utso/fmt.lp" return "utso/fmt.lp"
    if target == "utso/hashmap" or target == "utso/hashmap.lp" return "utso/hashmap.lp"
    if target == "utso/arena" or target == "utso/arena.lp" return "utso/arena.lp"
    if target == "utso/error" or target == "utso/error.lp" return "utso/error.lp"
    if target == "utso/option" or target == "utso/option.lp" return "utso/option.lp"
    if target == "utso/result" or target == "utso/result.lp" return "utso/result.lp"
    if target == "utso/ffi" or target == "utso/ffi.lp" return "utso/ffi.lp"
    if target == "utso/concurrency" or target == "utso/concurrency.lp" return "utso/concurrency.lp"
    if target == "utso/channel" or target == "utso/channel.lp" return "utso/channel.lp"
    if target == "utso/bare" or target == "utso/bare/core" or target == "utso/bare/core.lp" return "utso/bare/core.lp"
    if target == "utso/bare/gpt" or target == "utso/bare/gpt.lp" return "utso/bare/gpt.lp"
    if target == "utso/bare/fat32" or target == "utso/bare/fat32.lp" return "utso/bare/fat32.lp"
    if target == "utso/bare/iso9660" or target == "utso/bare/iso9660.lp" return "utso/bare/iso9660.lp"
    if target == "utso/bare/string" or target == "utso/bare/string.lp" return "utso/bare/string.lp"
    if target == "utso/bare/fmt" or target == "utso/bare/fmt.lp" return "utso/bare/fmt.lp"
    if target == "utso/silicon/serial" or target == "utso/silicon/serial.lp" return "utso/silicon/serial.lp"
    if target == "utso/silicon/vga" or target == "utso/silicon/vga.lp" return "utso/silicon/vga.lp"
    if target == "utso/silicon/cpu" or target == "utso/silicon/cpu.lp" return "utso/silicon/cpu.lp"
    if target == "utso/silicon/virtio" or target == "utso/silicon/virtio.lp" return "utso/silicon/virtio.lp"
    if target == "utso/silicon/uefi" or target == "utso/silicon/uefi.lp" return "utso/silicon/uefi.lp"
    if target == "utso/silicon/acpi" or target == "utso/silicon/acpi.lp" return "utso/silicon/acpi.lp"
    if target == "utso/silicon/pcie" or target == "utso/silicon/pcie.lp" return "utso/silicon/pcie.lp"
    if target == "utso/silicon/apic" or target == "utso/silicon/apic.lp" return "utso/silicon/apic.lp"
    if target == "utso/silicon/multiboot2" or target == "utso/silicon/multiboot2.lp" return "utso/silicon/multiboot2.lp"
    if target == "utso/silicon/nvme" or target == "utso/silicon/nvme.lp" return "utso/silicon/nvme.lp"
    if target == "utso/silicon/ahci" or target == "utso/silicon/ahci.lp" return "utso/silicon/ahci.lp"
    if target == "utso/silicon/xhci" or target == "utso/silicon/xhci.lp" return "utso/silicon/xhci.lp"
    if target == "utso/silicon/hda" or target == "utso/silicon/hda.lp" return "utso/silicon/hda.lp"
    if target == "utso/silicon/pl011" or target == "utso/silicon/pl011.lp" return "utso/silicon/pl011.lp"
    if target == "utso/silicon/gic" or target == "utso/silicon/gic.lp" return "utso/silicon/gic.lp"
    if target == "utso/silicon/opensbi" or target == "utso/silicon/opensbi.lp" return "utso/silicon/opensbi.lp"

    // 2. Legacy 'universe/core/*' and 'universe/os/*' mapping to sovereign primitives:
    if target == "universe/core/memory.lp" or target == "universe/core/memory" return "utso/memory.lp"
    if target == "universe/core/io.lp" or target == "universe/core/io" return "utso/io.lp"
    if target == "universe/core/string.lp" or target == "universe/core/string" return "utso/string.lp"
    if target == "universe/core/unicode.lp" or target == "universe/core/unicode" return "utso/unicode.lp"
    if target == "universe/core/math.lp" or target == "universe/core/math" return "utso/math.lp"
    if target == "universe/core/collections.lp" or target == "universe/core/collections" return "utso/collections.lp"
    if target == "universe/os/syscalls.lp" or target == "universe/os/syscalls" return "utso/syscalls.lp"
    if target == "universe/os/fs.lp" or target == "universe/os/fs" return "utso/os/fs.lp"
    if target == "universe/crypto/crypto.lp" or target == "universe/crypto/crypto" return "utso/crypto.lp"
    if target == "universe/crypto/sha256.lp" or target == "universe/crypto/sha256" return "utso/crypto/sha256.lp"
    if target == "universe/crypto/base64.lp" or target == "universe/crypto/base64" return "utso/crypto/base64.lp"
    if target == "universe/core/json.lp" or target == "universe/core/json" return "utso/core/json.lp"
    if target == "universe/core/net.lp" or target == "universe/core/net" return "utso/core/net.lp"
    if target == "universe/net/socket.lp" or target == "universe/net/socket" return "utso/socket.lp"
    if target == "universe/net/http.lp" or target == "universe/net/http" return "utso/net/http.lp"
    if target == "universe/net/tcp.lp" or target == "universe/net/tcp" return "utso/net/tcp.lp"
    if target == "universe/net/tcp_server.lp" or target == "universe/net/tcp_server" return "utso/net/tcp_server.lp"
    if target == "universe/net/udp.lp" or target == "universe/net/udp" return "utso/net/udp.lp"
    if target == "universe/db/engine.lp" or target == "universe/db/engine" return "aati/lipidb/engine.lp"
    if target == "universe/web/context.lp" or target == "universe/web/context" return "aati/lipi_web/context.lp"
    if target == "universe/web/url.lp" or target == "universe/web/url" return "aati/lipi_web/url.lp"
    if target == "universe/hypervisor/kvm.lp" or target == "universe/hypervisor/kvm" return "aati/lipi_hypervisor/kvm.lp"
    if target == "universe/os/kernel_multiboot.lp" or target == "universe/os/kernel_multiboot" return "utso/os/kernel_multiboot.lp"

    // 3. Complete legacy 'std/*' standard library mappings:
    if target == "std/mem.lp" or target == "std/mem" return "utso/memory.lp"
    if target == "std/io.lp" or target == "std/io" return "utso/io.lp"
    if target == "std/str.lp" or target == "std/str" return "utso/string.lp"
    if target == "std/math.lp" or target == "std/math" return "utso/math.lp"
    if target == "std/arena.lp" or target == "std/arena" return "utso/arena.lp"
    if target == "std/hashmap.lp" or target == "std/hashmap" return "utso/hashmap.lp"
    if target == "std/fmt.lp" or target == "std/fmt" return "utso/fmt.lp"
    if target == "std/time.lp" or target == "std/time" return "utso/time.lp"
    if target == "std/json.lp" or target == "std/json" return "aati/json_toolkit/json.lp"
    if target == "std/regex.lp" or target == "std/regex" return "utso/core/regex.lp"
    if target == "std/simd.lp" or target == "std/simd" return "utso/core/simd.lp"
    if target == "std/crypto.lp" or target == "std/crypto" return "utso/crypto.lp"
    if target == "std/crypto2.lp" or target == "std/crypto2" return "utso/crypto/advanced.lp"
    if target == "std/tls.lp" or target == "std/tls" return "utso/crypto/tls.lp"
    if target == "std/kernel.lp" or target == "std/kernel" return "utso/os/kernel_multiboot.lp"
    if target == "std/thread.lp" or target == "std/thread" return "utso/os/thread.lp"
    if target == "std/shm.lp" or target == "std/shm" return "utso/os/shm.lp"
    if target == "std/event.lp" or target == "std/event" return "utso/os/event.lp"
    if target == "std/cli.lp" or target == "std/cli" return "utso/tools/cli.lp"
    if target == "std/debug.lp" or target == "std/debug" return "utso/tools/debug.lp"
    if target == "std/test.lp" or target == "std/test" return "utso/tools/test_runner.lp"
    if target == "std/ai.lp" or target == "std/ai" return "aati/lipi_ai/tensor_engine.lp"
    if target == "std/gguf.lp" or target == "std/gguf" return "aati/lipi_ai/gguf.lp"
    if target == "std/gfx.lp" or target == "std/gfx" return "aati/lipi_gui/gfx.lp"
    if target == "std/x11.lp" or target == "std/x11" return "aati/lipi_gui/x11/x11.lp"
    if target == "std/tui.lp" or target == "std/tui" return "aati/lipi_gui/tui.lp"
    if target == "std/web.lp" or target == "std/web" return "aati/lipi_web/engine.lp"
    if target == "std/http.lp" or target == "std/http" return "aati/lipi_web/http.lp"
    if target == "std/net.lp" or target == "std/net" return "utso/socket.lp"
    if target == "std/websocket.lp" or target == "std/websocket" return "aati/lipi_web/ws_wire.lp"
    if target == "std/grpc.lp" or target == "std/grpc" return "aati/lipi_grpc/grpc_server.lp"
    if target == "std/db.lp" or target == "std/db" return "aati/lipidb/engine.lp"
    if target == "std/kv.lp" or target == "std/kv" return "aati/lipidb/kv.lp"
    if target == "std/orm.lp" or target == "std/orm" return "aati/lipidb/orm.lp"
    if target == "std/columnstore.lp" or target == "std/columnstore" return "aati/lipidb/column/columnstore.lp"

    // 3. Sovereign Aati Primary Shortcuts
    if target == "aati/web.lp" or target == "aati/web" return "aati/lipi_web/engine.lp"
    if target == "aati/http.lp" or target == "aati/http" return "aati/lipi_web/http.lp"
    if target == "aati/db.lp" or target == "aati/db" return "aati/lipidb/engine.lp"
    if target == "aati/ai.lp" or target == "aati/ai" return "aati/lipi_ai/tensor_engine.lp"
    if target == "aati/gui.lp" or target == "aati/gui" return "aati/lipi_gui/gfx.lp"
    if target == "aati/json.lp" or target == "aati/json" return "aati/json_toolkit/json.lp"
    if target == "aati/tui.lp" or target == "aati/tui" return "aati/lipi_gui/tui.lp"
    if target == "aati/gfx.lp" or target == "aati/gfx" return "aati/lipi_gui/gfx.lp"

    return target

fn compiler_driver_get_env name
    // WHY: Reads environment variables directly from Linux /proc/self/environ using pure syscalls (0% libc).
    // Uses direct sys_open (2), sys_mmap (9), sys_read (0), sys_close (3), sys_munmap (11).
    fd = syscall(2, "/proc/self/environ", 0, 0, 0, 0, 0)
    if fd < 0
        return ""
    buf = syscall(9, 0, 32768, 3, 34, -1, 0)
    nr = syscall(0, fd, buf, 32768, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if nr <= 0
        syscall(11, buf, 32768, 0, 0, 0, 0)
        return ""
    prefix = name + "="
    plen = len(prefix)
    p = 0
    start = 0
    while p < nr
        b = mem_byte_read(buf, p)
        if b == 0
            entry_len = p - start
            if entry_len > plen
                match = 1
                k = 0
                while k < plen
                    if mem_byte_read(buf, start + k) != mem_byte_read(prefix, k)
                        match = 0
                        break
                    k = k + 1
                if match == 1
                    val = ""
                    vi = start + plen
                    while vi < p
                        val = val + chr(mem_byte_read(buf, vi))
                        vi = vi + 1
                    syscall(11, buf, 32768, 0, 0, 0, 0)
                    return val
            start = p + 1
        p = p + 1
    syscall(11, buf, 32768, 0, 0, 0, 0)
    return ""

fn compiler_driver_is_lipi_dir dir
    if len(dir) == 0 return 0
    if file_exists(dir + "/utso/memory.lp") == 1 return 1
    if file_exists(dir + "/utso/core/memory.lp") == 1 return 1
    return 0

fn compiler_driver_get_lipi_root
    // WHY: Sovereign self-location of LiPi compiler installation root (0% libc / 0% external tools).
    // Discovers canonical root containing 'utso/', 'packages/', 'universe/', and 'src/' across all OS paths.

    // 1. Check environment variables LIPI_ROOT, LIPI_HOME, LIPI_PATH (explicit user override)
    r_env = compiler_driver_get_env("LIPI_ROOT")
    if compiler_driver_is_lipi_dir(r_env) == 1
        return r_env

    r_home = compiler_driver_get_env("LIPI_HOME")
    if compiler_driver_is_lipi_dir(r_home) == 1
        return r_home

    r_path = compiler_driver_get_env("LIPI_PATH")
    if compiler_driver_is_lipi_dir(r_path) == 1
        return r_path

    // 2. Inspect Linux /proc/self/exe via direct sys_readlink (Syscall 89)
    exe_buf = syscall(9, 0, 1024, 3, 34, -1, 0)
    n = syscall(89, "/proc/self/exe", exe_buf, 1024, 0, 0, 0)
    if n > 0
        exe_path = ""
        ei = 0
        while ei < n
            exe_path = exe_path + chr(mem_byte_read(exe_buf, ei))
            ei = ei + 1
        syscall(11, exe_buf, 1024, 0, 0, 0, 0)

        bin_dir = compiler_driver_dirname(exe_path)
        cand_root = compiler_driver_dirname(bin_dir)
        if compiler_driver_is_lipi_dir(cand_root) == 1
            return cand_root
        if compiler_driver_is_lipi_dir(bin_dir) == 1
            return bin_dir
    else
        syscall(11, exe_buf, 1024, 0, 0, 0, 0)

    // 3. Check user home installation directory (~/.lipi)
    u_home = compiler_driver_get_env("HOME")
    if len(u_home) > 0 and compiler_driver_is_lipi_dir(u_home + "/.lipi") == 1
        return u_home + "/.lipi"

    // 4. Standard global system paths
    if compiler_driver_is_lipi_dir("/usr/local/lib/lipi") == 1
        return "/usr/local/lib/lipi"
    if compiler_driver_is_lipi_dir("/usr/lib/lipi") == 1
        return "/usr/lib/lipi"
    if compiler_driver_is_lipi_dir("/opt/lipi") == 1
        return "/opt/lipi"

    // 5. Current working directory fallback
    if compiler_driver_is_lipi_dir(".") == 1
        return "."

    return ""

fn compiler_driver_resolve_path inc_target cur_dir lipi_root
    // WHY: Deterministic 4-tier module path resolution engine.
    // Tier 1: Local directory relative to the current file (project-level module imports)
    // Tier 2: Current working directory, 'utso/' primitives, and 'packages/' repositories
    // Tier 3: Sovereign LiPi root (utso standard library, packages, and compiler subsystems)
    // Tier 4: Fallback to raw inc_target for unified compiler diagnostic error reporting

    // Bi-directional dual-alias normalization:
    // If referencing packages/... and aati/... exists, or vice versa, seamlessly resolve without breaking legacy references.
    if compiler_driver_starts_with(inc_target, "packages/") == 1
        aati_equiv = "aati/" + str_sub(inc_target, 9, len(inc_target))
        if file_exists(aati_equiv + ".lp") == 1 return aati_equiv + ".lp"
        if file_exists(aati_equiv) == 1 return aati_equiv
        if cur_dir != "." and len(cur_dir) > 0
            if file_exists(cur_dir + "/" + aati_equiv + ".lp") == 1 return cur_dir + "/" + aati_equiv + ".lp"
            if file_exists(cur_dir + "/" + aati_equiv) == 1 return cur_dir + "/" + aati_equiv
        if len(lipi_root) > 0 and lipi_root != "."
            if file_exists(lipi_root + "/" + aati_equiv + ".lp") == 1 return lipi_root + "/" + aati_equiv + ".lp"
            if file_exists(lipi_root + "/" + aati_equiv) == 1 return lipi_root + "/" + aati_equiv
        if file_exists(inc_target + ".lp") == 0 and file_exists(inc_target) == 0
            inc_target = aati_equiv
    elif compiler_driver_starts_with(inc_target, "aati/") == 1
        pkg_equiv = "packages/" + str_sub(inc_target, 5, len(inc_target))
        if file_exists(inc_target + ".lp") == 1 return inc_target + ".lp"
        if file_exists(inc_target) == 1 return inc_target
        if file_exists(pkg_equiv + ".lp") == 1 return pkg_equiv + ".lp"
        if file_exists(pkg_equiv) == 1 return pkg_equiv
        if cur_dir != "." and len(cur_dir) > 0
            if file_exists(cur_dir + "/" + inc_target + ".lp") == 1 return cur_dir + "/" + inc_target + ".lp"
            if file_exists(cur_dir + "/" + inc_target) == 1 return cur_dir + "/" + inc_target
            if file_exists(cur_dir + "/" + pkg_equiv + ".lp") == 1 return cur_dir + "/" + pkg_equiv + ".lp"
            if file_exists(cur_dir + "/" + pkg_equiv) == 1 return cur_dir + "/" + pkg_equiv
        if len(lipi_root) > 0 and lipi_root != "."
            if file_exists(lipi_root + "/" + inc_target + ".lp") == 1 return lipi_root + "/" + inc_target + ".lp"
            if file_exists(lipi_root + "/" + inc_target) == 1 return lipi_root + "/" + inc_target
            if file_exists(lipi_root + "/" + pkg_equiv + ".lp") == 1 return lipi_root + "/" + pkg_equiv + ".lp"
            if file_exists(lipi_root + "/" + pkg_equiv) == 1 return lipi_root + "/" + pkg_equiv

    // Tier 1: CWD & relative project path first (user application source files ALWAYS take precedence)
    if file_exists(inc_target + ".lp") == 1
        return inc_target + ".lp"
    if file_exists(inc_target) == 1
        return inc_target

    // Prioritize .lp extension to prevent matching filesystem directories
    if cur_dir != "." and len(cur_dir) > 0
        if file_exists(cur_dir + "/" + inc_target + ".lp") == 1
            return cur_dir + "/" + inc_target + ".lp"
        if file_exists(cur_dir + "/" + inc_target) == 1
            return cur_dir + "/" + inc_target

    // Tier 1b: If lipi_root is explicit and not ".", resolve canonical system libraries (utso/, aati/, packages/)
    // directly from lipi_root. NOTE: 'src/' is reserved for user applications and never resolved from lipi_root.
    if len(lipi_root) > 0 and lipi_root != "."
        if compiler_driver_starts_with(inc_target, "utso/") == 1 or compiler_driver_starts_with(inc_target, "aati/") == 1 or compiler_driver_starts_with(inc_target, "packages/") == 1
            if file_exists(lipi_root + "/" + inc_target + ".lp") == 1 return lipi_root + "/" + inc_target + ".lp"
            if file_exists(lipi_root + "/" + inc_target) == 1 return lipi_root + "/" + inc_target

    // Tier 2: Canonical fallback paths
    if file_exists("utso/" + inc_target + ".lp") == 1
        return "utso/" + inc_target + ".lp"
    if file_exists("utso/" + inc_target) == 1
        return "utso/" + inc_target
    if file_exists("aati/" + inc_target + ".lp") == 1
        return "aati/" + inc_target + ".lp"
    if file_exists("aati/" + inc_target) == 1
        return "aati/" + inc_target
    if file_exists("packages/" + inc_target + ".lp") == 1
        return "packages/" + inc_target + ".lp"
    if file_exists("packages/" + inc_target) == 1
        return "packages/" + inc_target
    if file_exists("src/" + inc_target + ".lp") == 1
        return "src/" + inc_target + ".lp"
    if file_exists("src/" + inc_target) == 1
        return "src/" + inc_target

    // Domain mappings for aati/ (e.g. aati/web, aati/db, aati/ai, aati/gui, aati/json, etc.)
    if compiler_driver_starts_with(inc_target, "aati/") == 1
        sub_aati = str_sub(inc_target, 5, len(inc_target))
        if compiler_driver_starts_with(sub_aati, "ai/") == 1
            cand = "aati/lipi_ai/" + str_sub(sub_aati, 3, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "db/") == 1
            cand = "aati/lipidb/" + str_sub(sub_aati, 3, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "web/") == 1
            cand = "aati/lipi_web/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "gui/") == 1
            cand = "aati/lipi_gui/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "json/") == 1
            cand = "aati/json_toolkit/" + str_sub(sub_aati, 5, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "crypto/") == 1
            cand = "aati/crypto_vault/" + str_sub(sub_aati, 7, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "engine3d/") == 1
            cand = "aati/lipi_engine3d/" + str_sub(sub_aati, 9, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "quantum/") == 1
            cand = "aati/lipi_quantum/" + str_sub(sub_aati, 8, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "blockchain/") == 1
            cand = "aati/lipi_blockchain/" + str_sub(sub_aati, 11, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "hypervisor/") == 1
            cand = "aati/lipi_hypervisor/" + str_sub(sub_aati, 11, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "swarm/") == 1
            cand = "aati/lipi_swarm/" + str_sub(sub_aati, 6, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "iot/") == 1
            cand = "aati/lipi_iot/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "media/") == 1
            cand = "aati/lipi_media/" + str_sub(sub_aati, 6, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "gpu/") == 1
            cand = "aati/lipi_gpu/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "fs/") == 1
            cand = "aati/lipi_fs/" + str_sub(sub_aati, 3, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "mobile/") == 1
            cand = "aati/lipi_mobile/" + str_sub(sub_aati, 7, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "p2p/") == 1
            cand = "aati/lipi_p2p/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "security/") == 1
            cand = "aati/lipi_security/" + str_sub(sub_aati, 9, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "boot/") == 1
            cand = "aati/lipi_boot/" + str_sub(sub_aati, 5, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "ide/") == 1
            cand = "aati/lipi_ide/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "registry/") == 1
            cand = "aati/lipi_registry/" + str_sub(sub_aati, 9, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_aati, "pkg/") == 1
            cand = "aati/lipi_registry/" + str_sub(sub_aati, 4, len(sub_aati))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand

    // Dynamic translation for legacy universe/ paths:
    if compiler_driver_starts_with(inc_target, "universe/") == 1
        sub_p = str_sub(inc_target, 9, len(inc_target))
        // 1. Try utso/
        if file_exists("utso/" + sub_p + ".lp") == 1
            return "utso/" + sub_p + ".lp"
        if file_exists("utso/" + sub_p) == 1
            return "utso/" + sub_p
        // 2. Try aati/ and packages/
        if file_exists("aati/" + sub_p + ".lp") == 1
            return "aati/" + sub_p + ".lp"
        if file_exists("aati/" + sub_p) == 1
            return "aati/" + sub_p
        if file_exists("packages/" + sub_p + ".lp") == 1
            return "packages/" + sub_p + ".lp"
        if file_exists("packages/" + sub_p) == 1
            return "packages/" + sub_p
        // 3. Domain mappings in aati/
        if compiler_driver_starts_with(sub_p, "ai/") == 1
            cand = "aati/lipi_ai/" + str_sub(sub_p, 3, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "db/") == 1
            cand = "aati/lipidb/" + str_sub(sub_p, 3, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "web/") == 1
            cand = "aati/lipi_web/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "gui/") == 1
            cand = "aati/lipi_gui/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "engine3d/") == 1
            cand = "aati/lipi_engine3d/" + str_sub(sub_p, 9, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "quantum/") == 1
            cand = "aati/lipi_quantum/" + str_sub(sub_p, 8, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "blockchain/") == 1
            cand = "aati/lipi_blockchain/" + str_sub(sub_p, 11, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "hypervisor/") == 1
            cand = "aati/lipi_hypervisor/" + str_sub(sub_p, 11, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "swarm/") == 1
            cand = "aati/lipi_swarm/" + str_sub(sub_p, 6, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "iot/") == 1
            cand = "aati/lipi_iot/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "media/") == 1
            cand = "aati/lipi_media/" + str_sub(sub_p, 6, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "gpu/") == 1
            cand = "aati/lipi_gpu/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "fs/") == 1
            cand = "aati/lipi_fs/" + str_sub(sub_p, 3, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "mobile/") == 1
            cand = "aati/lipi_mobile/" + str_sub(sub_p, 7, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "p2p/") == 1
            cand = "aati/lipi_p2p/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "security/") == 1
            cand = "aati/lipi_security/" + str_sub(sub_p, 9, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "boot/") == 1
            cand = "aati/lipi_boot/" + str_sub(sub_p, 5, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "ide/") == 1
            cand = "aati/lipi_ide/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "registry/") == 1
            cand = "aati/lipi_registry/" + str_sub(sub_p, 9, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "pkg/") == 1
            cand = "aati/lipi_registry/" + str_sub(sub_p, 4, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "tools/") == 1
            cand = "utso/tools/" + str_sub(sub_p, 6, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand
        elif compiler_driver_starts_with(sub_p, "io/") == 1
            cand = "utso/io/" + str_sub(sub_p, 3, len(sub_p))
            if file_exists(cand + ".lp") == 1 return cand + ".lp"
            if file_exists(cand) == 1 return cand

    // Tier 3: Sovereign LiPi root
    if len(lipi_root) > 0 and lipi_root != "."
        if file_exists(lipi_root + "/" + inc_target + ".lp") == 1
            return lipi_root + "/" + inc_target + ".lp"
        if file_exists(lipi_root + "/" + inc_target) == 1
            return lipi_root + "/" + inc_target
        if file_exists(lipi_root + "/utso/" + inc_target + ".lp") == 1
            return lipi_root + "/utso/" + inc_target + ".lp"
        if file_exists(lipi_root + "/utso/" + inc_target) == 1
            return lipi_root + "/utso/" + inc_target
        if file_exists(lipi_root + "/aati/" + inc_target + ".lp") == 1
            return lipi_root + "/aati/" + inc_target + ".lp"
        if file_exists(lipi_root + "/aati/" + inc_target) == 1
            return lipi_root + "/aati/" + inc_target
        if file_exists(lipi_root + "/packages/" + inc_target + ".lp") == 1
            return lipi_root + "/packages/" + inc_target + ".lp"
        if file_exists(lipi_root + "/packages/" + inc_target) == 1
            return lipi_root + "/packages/" + inc_target
        if file_exists(lipi_root + "/src/" + inc_target + ".lp") == 1
            return lipi_root + "/src/" + inc_target + ".lp"
        if file_exists(lipi_root + "/src/" + inc_target) == 1
            return lipi_root + "/src/" + inc_target

    return inc_target

fn compiler_driver_is_ident_ch b
    if (b >= 97 and b <= 122) or (b >= 65 and b <= 90) or (b >= 48 and b <= 57) or b == 95 or b >= 128
        return 1
    end
    return 0
end

G_DRV_SEL_COUNTER = 0

fn compiler_driver_strip_pub src
    // WHY: Strips leading `pub ` visibility modifiers before declarations so lexer/parser/backend
    // remain 100% clean while bundler enforces module export encapsulation.
    n = len(src)
    p = 0
    seg_start = 0
    out_chunks = list()
    found_any = 0
    while p < n
        ls = p
        while p < n and (mem_byte_read(src, p) == 32 or mem_byte_read(src, p) == 9)
            p = p + 1
        end
        if p + 4 < n and mem_byte_read(src, p) == 112 and compiler_driver_match_kw(src, p, "pub ") == 1
            q = p + 4
            while q < n and (mem_byte_read(src, q) == 32 or mem_byte_read(src, q) == 9)
                q = q + 1
            end
            is_decl = 0
            if compiler_driver_match_kw(src, q, "fn ") == 1 or compiler_driver_match_kw(src, q, "@fn ") == 1 or compiler_driver_match_kw(src, q, "struct ") == 1 or compiler_driver_match_kw(src, q, "@struct ") == 1 or compiler_driver_match_kw(src, q, "union ") == 1 or compiler_driver_match_kw(src, q, "@union ") == 1 or compiler_driver_match_kw(src, q, "trait ") == 1 or compiler_driver_match_kw(src, q, "@trait ") == 1 or compiler_driver_match_kw(src, q, "enum ") == 1 or compiler_driver_match_kw(src, q, "@enum ") == 1 or compiler_driver_match_kw(src, q, "const ") == 1 or compiler_driver_match_kw(src, q, "let ") == 1 or compiler_driver_match_kw(src, q, "global ") == 1 or compiler_driver_match_kw(src, q, "বৈশ্বিক ") == 1 or compiler_driver_match_kw(src, q, "কাজ ") == 1 or compiler_driver_match_kw(src, q, "গঠন ") == 1 or compiler_driver_match_kw(src, q, "ইউনিয়ন ") == 1 or compiler_driver_match_kw(src, q, "গণনা ") == 1
                is_decl = 1
            end
            if is_decl == 1
                found_any = 1
                if p > seg_start
                    push(out_chunks, str_sub(src, seg_start, p))
                end
                seg_start = q
            end
        end
        while p < n and mem_byte_read(src, p) != 10
            p = p + 1
        end
        if p < n p = p + 1 end
    end
    if found_any == 0
        return src
    end
    if seg_start < n
        push(out_chunks, str_sub(src, seg_start, n))
    end
    return compiler_driver_join_chunks(out_chunks)
end

fn compiler_driver_list_has lst val
    i = 0
    while i < lst.len()
        if compiler_driver_streq(lst[i], val) == 1
            return 1
        end
        i = i + 1
    end
    return 0
end

fn compiler_driver_collect_mod_meta src
    // WHY: AST/Token-driven module symbol table builder using Lipi's real lexer (`tokenize_source`)
    // and O(1) `FastSymbolTable` (`symbol_table.lp`), immune to comments (`//`, `/* */`, `#`, `@!`)
    // and string literals. Extracts all top-level fn/struct/union/enum/trait/const/let symbols
    // and enforces `pub` visibility encapsulation.
    all_syms = list()
    pub_syms = list()
    has_pub = 0
    mod_tab = symtab_new(64)
    mod_toks = tokenize_source(src)
    tn = mod_toks.len()
    ti = 0
    while ti < tn
        tk = mod_toks[ti]
        if tk.tok_span.span_start_col == 1
            is_pub = 0
            cur_i = ti
            if tk.tok_kind == TOK_IDENT() and tk.tok_text == "pub"
                is_pub = 1
                has_pub = 1
                cur_i = cur_i + 1
            end
            if cur_i < tn and (mod_toks[cur_i].tok_kind == TOK_KW_ASYNC() or (mod_toks[cur_i].tok_kind == TOK_IDENT() and mod_toks[cur_i].tok_text == "async"))
                cur_i = cur_i + 1
            end
            if cur_i + 1 < tn
                dk = mod_toks[cur_i].tok_kind
                dt = mod_toks[cur_i].tok_text
                is_decl_tok = 0
                if dk == TOK_KW_FN() or dk == TOK_DIR_FN() or dk == TOK_KW_STRUCT() or dk == TOK_DIR_STRUCT() or dk == TOK_KW_ENUM() or dk == TOK_DIR_ENUM() or dk == TOK_DIR_TRAIT() or dk == TOK_KW_LET() or dk == TOK_KW_CONST()
                    is_decl_tok = 1
                elif dk == TOK_IDENT() and (dt == "union" or dt == "@union" or dt == "ইউনিয়ন" or dt == "global" or dt == "বৈশ্বিক")
                    is_decl_tok = 1
                end
                if is_decl_tok == 1 and mod_toks[cur_i + 1].tok_kind == TOK_IDENT()
                    nm = mod_toks[cur_i + 1].tok_text
                    if symtab_has(mod_tab, nm) == 0
                        sym_entry = symbol_new(nm, SYM_KIND_FUNCTION(), TYPE_ID_ANY(), 0, span_default(), 0)
                        sym_entry.sym_is_public = is_pub
                        symtab_put(mod_tab, sym_entry)
                        push(all_syms, nm)
                    end
                    if is_pub == 1 and compiler_driver_list_has(pub_syms, nm) == 0
                        push(pub_syms, nm)
                    end
                end
            end
        end
        ti = ti + 1
    end
    return [all_syms, pub_syms, has_pub, mod_tab]
end

fn compiler_driver_mod_id resolved_path
    // WHY: Canonical FNV-1a path-based module ID so two files using the same alias (`as m`) for
    // different modules never collide, and duplicate imports of the same file share one canonical prefix.
    h = 2166136261
    n = len(resolved_path)
    i = 0
    while i < n
        h = ((h ^ (mem_byte_read(resolved_path, i) & 255)) * 16777619) & 2147483647
        i = i + 1
    end
    return "m_" + str(h)
end

fn compiler_driver_mangle_module src mod_id all_syms
    // WHY: Scope-aware module symbol rewriter using O(1) `FastSymbolTable`:
    //   1. Never mangles string literals, comments (`//`, `/* */`, `#`, `@!`), or member accesses `.field`.
    //   2. Never mangles struct/union field declarations (while still mangling `: Type` references).
    //   3. Never mangles formal function parameters or `let`/`for` local variables that shadow a module symbol.
    clean_src = compiler_driver_strip_pub(src)
    if all_syms.len() == 0
        return clean_src
    end
    sym_tab = symtab_new(64)
    sp0 = span_default()
    si = 0
    while si < all_syms.len()
        symtab_put(sym_tab, symbol_new(all_syms[si], SYM_KIND_FUNCTION(), TYPE_ID_ANY(), 0, sp0, 0))
        si = si + 1
    end
    prefix = "__mod_" + mod_id + "__"
    out_chunks = list()
    n = len(clean_src)
    p = 0
    seg_start = 0
    col_start = 0
    in_struct_body = 0
    struct_braced = 0
    struct_brace_depth = 0
    fn_shadow_tab = 0
    in_fn_params = 0
    fn_param_type_next = 0
    let_or_for_next = 0
    struct_field_type_next = 0

    while p < n
        b = mem_byte_read(clean_src, p)
        if b == 10
            p = p + 1
            col_start = p
            in_fn_params = 0
            fn_param_type_next = 0
            let_or_for_next = 0
            struct_field_type_next = 0
            continue
        end
        // Skip string literals
        if b == 34 or b == 39
            q_ch = b
            p = p + 1
            while p < n
                cb = mem_byte_read(clean_src, p)
                if cb == 92 and p + 1 < n
                    p = p + 2
                elif cb == q_ch
                    p = p + 1
                    break
                else
                    p = p + 1
                end
            end
            continue
        end
        // Skip // line comments, /* ... */ block comments, # and @! comments
        if b == 47 and p + 1 < n and mem_byte_read(clean_src, p + 1) == 47
            while p < n and mem_byte_read(clean_src, p) != 10
                p = p + 1
            end
            continue
        end
        if b == 47 and p + 1 < n and mem_byte_read(clean_src, p + 1) == 42
            p = p + 2
            while p + 1 < n and not (mem_byte_read(clean_src, p) == 42 and mem_byte_read(clean_src, p + 1) == 47)
                if mem_byte_read(clean_src, p) == 10
                    col_start = p + 1
                end
                p = p + 1
            end
            if p + 1 < n p = p + 2 end
            continue
        end
        if b == 35 or (b == 64 and p + 1 < n and mem_byte_read(clean_src, p + 1) == 33)
            while p < n and mem_byte_read(clean_src, p) != 10
                p = p + 1
            end
            continue
        end
        if b == 123 // '{'
            if in_struct_body == 1
                struct_braced = 1
                struct_brace_depth = struct_brace_depth + 1
            end
            in_fn_params = 0
            fn_param_type_next = 0
            p = p + 1
            continue
        end
        if b == 125 // '}'
            if in_struct_body == 1 and struct_braced == 1
                struct_brace_depth = struct_brace_depth - 1
                if struct_brace_depth <= 0
                    in_struct_body = 0
                    struct_braced = 0
                    struct_brace_depth = 0
                    struct_field_type_next = 0
                end
            end
            p = p + 1
            continue
        end
        if b == 58 // ':'
            if in_fn_params == 1
                fn_param_type_next = 1
            elif in_struct_body == 1
                struct_field_type_next = 1
            end
            p = p + 1
            continue
        end
        if b == 44 // ','
            fn_param_type_next = 0
            struct_field_type_next = 0
            p = p + 1
            continue
        end
        if b == 45 and p + 1 < n and mem_byte_read(clean_src, p + 1) == 62 // '->'
            in_fn_params = 0
            fn_param_type_next = 0
            p = p + 2
            continue
        end
        if b == 41 // ')'
            if in_fn_params == 1
                in_fn_params = 0
                fn_param_type_next = 0
            end
            p = p + 1
            continue
        end
        if b == 61 // '='
            if in_fn_params == 1
                in_fn_params = 0
                fn_param_type_next = 0
            end
            p = p + 1
            continue
        end

        if compiler_driver_is_ident_ch(b) == 1 and (b < 48 or b > 57)
            id_start = p
            is_col0 = 0
            if id_start == col_start
                is_col0 = 1
            end
            p = p + 1
            while p < n and compiler_driver_is_ident_ch(mem_byte_read(clean_src, p)) == 1
                p = p + 1
            end
            prev_is_dot = 0
            if id_start > 0 and mem_byte_read(clean_src, id_start - 1) == 46
                prev_is_dot = 1
            end
            word = str_sub(clean_src, id_start, p)

            // Leave indented struct body when encountering next col-0 declaration/token
            if is_col0 == 1 and in_struct_body == 1 and struct_braced == 0
                in_struct_body = 0
                struct_field_type_next = 0
            end

            // Detect top-level struct/union/fn scope transitions
            if is_col0 == 1 and (word == "struct" or word == "গঠন" or word == "union" or word == "ইউনিয়ন")
                fn_shadow_tab = 0
                in_struct_body = 1
                struct_braced = 0
                struct_brace_depth = 0
                struct_field_type_next = 0
                // Consume and mangle the struct name itself immediately after keyword
                ws_p = p
                while ws_p < n and (mem_byte_read(clean_src, ws_p) == 32 or mem_byte_read(clean_src, ws_p) == 9)
                    ws_p = ws_p + 1
                end
                if ws_p < n and compiler_driver_is_ident_ch(mem_byte_read(clean_src, ws_p)) == 1
                    sn_end = ws_p + 1
                    while sn_end < n and compiler_driver_is_ident_ch(mem_byte_read(clean_src, sn_end)) == 1
                        sn_end = sn_end + 1
                    end
                    sn_word = str_sub(clean_src, ws_p, sn_end)
                    if symtab_has(sym_tab, sn_word) == 1
                        if ws_p > seg_start
                            push(out_chunks, str_sub(clean_src, seg_start, ws_p))
                        end
                        push(out_chunks, prefix + sn_word)
                        seg_start = sn_end
                    end
                    p = sn_end
                end
                continue
            end

            if is_col0 == 1 and (word == "fn" or word == "কাজ" or word == "async")
                if word == "async"
                    continue
                end
                fn_shadow_tab = symtab_new(16)
                in_fn_params = 1
                fn_param_type_next = 0
                // Consume and mangle the function name itself immediately after `fn`
                ws_p = p
                while ws_p < n and (mem_byte_read(clean_src, ws_p) == 32 or mem_byte_read(clean_src, ws_p) == 9)
                    ws_p = ws_p + 1
                end
                if ws_p < n and compiler_driver_is_ident_ch(mem_byte_read(clean_src, ws_p)) == 1
                    fn_end = ws_p + 1
                    while fn_end < n and compiler_driver_is_ident_ch(mem_byte_read(clean_src, fn_end)) == 1
                        fn_end = fn_end + 1
                    end
                    fn_word = str_sub(clean_src, ws_p, fn_end)
                    if symtab_has(sym_tab, fn_word) == 1
                        if ws_p > seg_start
                            push(out_chunks, str_sub(clean_src, seg_start, ws_p))
                        end
                        push(out_chunks, prefix + fn_word)
                        seg_start = fn_end
                    end
                    p = fn_end
                end
                continue
            end

            if is_col0 == 1 and word != "end" and word != "শেষ" and in_fn_params == 0
                // Top-level statement (global/const/enum/etc.) exits previous fn local shadow scope
                if word == "enum" or word == "trait" or word == "const" or word == "global" or word == "let"
                    fn_shadow_tab = 0
                end
            end

            // Inside struct body: do NOT mangle field names, DO mangle `: Type` annotations!
            if in_struct_body == 1
                if word == "end" or word == "শেষ"
                    in_struct_body = 0
                    struct_field_type_next = 0
                    continue
                end
                if struct_field_type_next == 1
                    struct_field_type_next = 0
                    if prev_is_dot == 0 and symtab_has(sym_tab, word) == 1
                        if id_start > seg_start
                            push(out_chunks, str_sub(clean_src, seg_start, id_start))
                        end
                        push(out_chunks, prefix + word)
                        seg_start = p
                    end
                end
                continue
            end

            // Inside function signature parameter list: record formal params as shadowed, mangle `: Type`!
            if in_fn_params == 1
                if fn_param_type_next == 1
                    fn_param_type_next = 0
                    if prev_is_dot == 0 and symtab_has(sym_tab, word) == 1
                        if id_start > seg_start
                            push(out_chunks, str_sub(clean_src, seg_start, id_start))
                        end
                        push(out_chunks, prefix + word)
                        seg_start = p
                    end
                else
                    if fn_shadow_tab != 0 and symtab_has(fn_shadow_tab, word) == 0
                        symtab_put(fn_shadow_tab, symbol_new(word, SYM_KIND_VARIABLE(), TYPE_ID_ANY(), 0, sp0, 0))
                    end
                end
                continue
            end

            // Inside function body: track `let <var>` / `for <var>` local shadows
            if fn_shadow_tab != 0 and is_col0 == 0
                if let_or_for_next == 1
                    let_or_for_next = 0
                    if symtab_has(fn_shadow_tab, word) == 0
                        symtab_put(fn_shadow_tab, symbol_new(word, SYM_KIND_VARIABLE(), TYPE_ID_ANY(), 0, sp0, 0))
                    end
                    continue
                end
                if word == "let" or word == "var" or word == "চলক" or word == "ধরি" or word == "for" or word == "প্রতিটি"
                    let_or_for_next = 1
                    continue
                end
            end

            // Standard reference mangling (skip `.field` and shadowed local params/vars)
            if prev_is_dot == 0
                is_shadowed = 0
                if fn_shadow_tab != 0 and symtab_has(fn_shadow_tab, word) == 1
                    is_shadowed = 1
                end
                if is_shadowed == 0 and symtab_has(sym_tab, word) == 1
                    if id_start > seg_start
                        push(out_chunks, str_sub(clean_src, seg_start, id_start))
                    end
                    push(out_chunks, prefix + word)
                    seg_start = p
                end
            end
            continue
        end
        p = p + 1
    end
    if seg_start < n
        push(out_chunks, str_sub(clean_src, seg_start, n))
    end
    return compiler_driver_join_chunks(out_chunks)
end

fn compiler_driver_rewrite_aliases src aliases alias_prefixes alias_pubs alias_has_pub alias_paths sel_locals sel_targets
    // WHY: Rewrites `alias::symbol`, `alias.symbol`, and selectively imported `from "..." import sym`
    // references to canonical path-hashed `__mod_<id>__<sym>` prefixes while skipping strings AND
    // all comment forms (`//`, `/* */`, `#`, `@!`) and enforcing `pub` visibility encapsulation.
    if aliases.len() == 0 and sel_locals.len() == 0
        return src
    end
    out_chunks = list()
    n = len(src)
    p = 0
    seg_start = 0
    while p < n
        b = mem_byte_read(src, p)
        if b == 34 or b == 39
            q_ch = b
            p = p + 1
            while p < n
                cb = mem_byte_read(src, p)
                if cb == 92 and p + 1 < n
                    p = p + 2
                elif cb == q_ch
                    p = p + 1
                    break
                else
                    p = p + 1
                end
            end
            continue
        end
        if b == 47 and p + 1 < n and mem_byte_read(src, p + 1) == 47
            while p < n and mem_byte_read(src, p) != 10
                p = p + 1
            end
            continue
        end
        if b == 47 and p + 1 < n and mem_byte_read(src, p + 1) == 42
            p = p + 2
            while p + 1 < n and not (mem_byte_read(src, p) == 42 and mem_byte_read(src, p + 1) == 47)
                p = p + 1
            end
            if p + 1 < n p = p + 2 end
            continue
        end
        if b == 35 or (b == 64 and p + 1 < n and mem_byte_read(src, p + 1) == 33)
            while p < n and mem_byte_read(src, p) != 10
                p = p + 1
            end
            continue
        end
        if compiler_driver_is_ident_ch(b) == 1 and (b < 48 or b > 57)
            id_start = p
            p = p + 1
            while p < n and compiler_driver_is_ident_ch(mem_byte_read(src, p)) == 1
                p = p + 1
            end
            prev_is_dot = 0
            if id_start > 0 and mem_byte_read(src, id_start - 1) == 46
                prev_is_dot = 1
            end
            word = str_sub(src, id_start, p)
            // Case 1: Qualified module access `alias::sym` or `alias.sym`
            sep_len = 0
            if p + 2 < n and mem_byte_read(src, p) == 58 and mem_byte_read(src, p + 1) == 58
                sep_len = 2
            elif p + 1 < n and mem_byte_read(src, p) == 46
                sep_len = 1
            end
            if prev_is_dot == 0 and sep_len > 0 and aliases.len() > 0
                ai = 0
                al_idx = 0 - 1
                while ai < aliases.len()
                    if compiler_driver_streq(aliases[ai], word) == 1
                        al_idx = ai
                        break
                    end
                    ai = ai + 1
                end
                if al_idx >= 0
                    m_start = p + sep_len
                    m_end = m_start
                    while m_end < n and compiler_driver_is_ident_ch(mem_byte_read(src, m_end)) == 1
                        m_end = m_end + 1
                    end
                    if m_end > m_start
                        mem_sym = str_sub(src, m_start, m_end)
                        if alias_has_pub[al_idx] == 1 and compiler_driver_list_has(alias_pubs[al_idx], mem_sym) == 0
                            say "❌ [Visibility Error]: Symbol '" + mem_sym + "' in module '" + alias_paths[al_idx] + "' is private (mark it 'pub' to export)."
                            exit(1)
                        end
                        if id_start > seg_start
                            push(out_chunks, str_sub(src, seg_start, id_start))
                        end
                        push(out_chunks, alias_prefixes[al_idx] + mem_sym)
                        seg_start = m_end
                        p = m_end
                        continue
                    end
                end
            end
            // Case 2: Selective import binding `from "mod" import sym [as local]`
            if prev_is_dot == 0 and sel_locals.len() > 0
                si = 0
                sel_idx = 0 - 1
                while si < sel_locals.len()
                    if compiler_driver_streq(sel_locals[si], word) == 1
                        sel_idx = si
                        break
                    end
                    si = si + 1
                end
                if sel_idx >= 0
                    if id_start > seg_start
                        push(out_chunks, str_sub(src, seg_start, id_start))
                    end
                    push(out_chunks, sel_targets[sel_idx])
                    seg_start = p
                    continue
                end
            end
            continue
        end
        p = p + 1
    end
    if seg_start < n
        push(out_chunks, str_sub(src, seg_start, n))
    end
    return compiler_driver_join_chunks(out_chunks)
end

global G_DRV_IMPORT_STACK = 0
global G_DRV_ROOT_CHUNKS = 0
global G_DRV_MOD_PATHS = 0
global G_DRV_MOD_PREFIXES = 0
global G_DRV_MOD_ALL = 0
global G_DRV_MOD_PUB = 0
global G_DRV_MOD_HASPUB = 0

fn compiler_driver_load_canonical_mod resolved chunks lipi_root
    // WHY: Loads, collects metadata for, and canonically mangles a scoped module ONCE per compilation
    // keyed by canonical file path, always emitting into root chunks (topological post-order) so
    // nested scoped imports are NEVER double-mangled by their parent module!
    if G_DRV_MOD_PATHS == 0
        G_DRV_MOD_PATHS = list()
        G_DRV_MOD_PREFIXES = list()
        G_DRV_MOD_ALL = list()
        G_DRV_MOD_PUB = list()
        G_DRV_MOD_HASPUB = list()
    end
    ci = 0
    while ci < G_DRV_MOD_PATHS.len()
        if compiler_driver_streq(G_DRV_MOD_PATHS[ci], resolved) == 1
            return [G_DRV_MOD_PREFIXES[ci], G_DRV_MOD_ALL[ci], G_DRV_MOD_PUB[ci], G_DRV_MOD_HASPUB[ci]]
        end
        ci = ci + 1
    end
    mod_id = compiler_driver_mod_id(resolved)
    mod_prefix = "__mod_" + mod_id + "__"
    mod_vis = list()
    mod_chunks = list()
    compiler_driver_bundle_into_chunks(resolved, mod_vis, mod_chunks, lipi_root)
    mod_joined = compiler_driver_join_chunks(mod_chunks)
    meta = compiler_driver_collect_mod_meta(mod_joined)
    m_all = meta[0]
    m_pub = meta[1]
    m_has_pub = meta[2]
    mod_mangled = compiler_driver_mangle_module(mod_joined, mod_id, m_all)
    emit_target = chunks
    if G_DRV_ROOT_CHUNKS != 0
        emit_target = G_DRV_ROOT_CHUNKS
    end
    push(emit_target, mod_mangled)
    push(emit_target, "\n")
    push(G_DRV_MOD_PATHS, resolved)
    push(G_DRV_MOD_PREFIXES, mod_prefix)
    push(G_DRV_MOD_ALL, m_all)
    push(G_DRV_MOD_PUB, m_pub)
    push(G_DRV_MOD_HASPUB, m_has_pub)
    return [mod_prefix, m_all, m_pub, m_has_pub]
end

fn compiler_driver_bundle_into_chunks file_path visited chunks lipi_root
    // WHY: 3-color DFS recursive dependency bundler (white/grey/black) with explicit circular-import
    // cycle breaking across BOTH plain imports AND scoped (`import ... as alias`, `from ... import`) imports.
    if len(file_path) > 2 and mem_byte_read(file_path, 0) == 46 and mem_byte_read(file_path, 1) == 47
        file_path = str_sub(file_path, 2, len(file_path))
    end
    if G_DRV_IMPORT_STACK == 0
        G_DRV_IMPORT_STACK = list()
    end
    // Grey-node cycle check: prevents infinite recursion even across aliased/selective circular imports!
    gi = 0
    while gi < G_DRV_IMPORT_STACK.len()
        if compiler_driver_streq(G_DRV_IMPORT_STACK[gi], file_path) == 1
            say "  [bundle] circular import cycle resolved via forward hoisting -> " + file_path
            return 0
        end
        gi = gi + 1
    end

    i = 0
    while i < visited.len()
        if compiler_driver_streq(visited[i], file_path) == 1
            return 0
        i = i + 1
    push(visited, file_path)
    push(G_DRV_IMPORT_STACK, file_path)
    say "  [bundle] -> " + file_path

    if file_exists(file_path) == 0
        _lipi_list_pop(G_DRV_IMPORT_STACK)
        return 0
    end

    content = file_read(file_path)
    if compiler_driver_has_include(content) == 0
        push(chunks, content)
        push(chunks, "\n")
        _lipi_list_pop(G_DRV_IMPORT_STACK)
        return 0
    end

    cur_dir = compiler_driver_dirname(file_path)
    file_aliases = list()
    file_alias_prefixes = list()
    file_alias_pubs = list()
    file_alias_has_pub = list()
    file_alias_paths = list()
    file_sel_locals = list()
    file_sel_targets = list()
    local_chunk_idxs = list()
    chunk_start = 0
    p = 0
    clen = len(content)

    while p < clen
        line_start = p
        while p < clen
            b = mem_byte_read(content, p)
            if b != 32 and b != 9
                break
            p = p + 1

        is_inc = 0
        is_from_import = 0
        inc_target = ""
        inc_alias = ""
        from_syms = list()
        from_locals = list()
        plen = 0

        if p < clen
            b0 = mem_byte_read(content, p)
            if b0 == 105 // 'i'
                if compiler_driver_match_kw(content, p, "include ") == 1
                    plen = 8
                elif compiler_driver_match_kw(content, p, "import ") == 1
                    plen = 7
            elif b0 == 102 // 'f'
                if compiler_driver_match_kw(content, p, "from ") == 1
                    plen = 5
                    is_from_import = 1
            elif b0 == 64 // '@'
                if compiler_driver_match_kw(content, p, "@include ") == 1
                    plen = 9
                elif compiler_driver_match_kw(content, p, "@use ") == 1
                    plen = 5
                elif compiler_driver_match_kw(content, p, "@অন্তর্ভুক্ত ") == 1
                    plen = 35
            elif compiler_driver_match_kw(content, p, "অন্তর্ভুক্ত ") == 1
                plen = 34
            elif compiler_driver_match_kw(content, p, "থেকে ") == 1
                plen = 13
                is_from_import = 1

        if plen > 0 and p + plen < clen
            p_scan = p + plen
            while p_scan < clen
                qb = mem_byte_read(content, p_scan)
                if qb != 32 and qb != 9
                    break
                p_scan = p_scan + 1
            if p_scan < clen
                q = mem_byte_read(content, p_scan)
                if q == 34 or q == 39 // '"' or '\''
                    p_tstart = p_scan + 1
                    p_tend = p_tstart
                    while p_tend < clen
                        qb = mem_byte_read(content, p_tend)
                        if qb == q or qb == 10
                            break
                        p_tend = p_tend + 1
                    if p_tend < clen and mem_byte_read(content, p_tend) == q
                        inc_target = str_sub(content, p_tstart, p_tend)
                        pa = p_tend + 1
                        while pa < clen and (mem_byte_read(content, pa) == 32 or mem_byte_read(content, pa) == 9)
                            pa = pa + 1
                        end
                        if is_from_import == 1
                            // Parse: from "mod" import sym1, sym2 [as local2]
                            if compiler_driver_match_kw(content, pa, "import ") == 1
                                pa = pa + 7
                                is_inc = 1
                                while pa < clen and mem_byte_read(content, pa) != 10
                                    while pa < clen and (mem_byte_read(content, pa) == 32 or mem_byte_read(content, pa) == 9 or mem_byte_read(content, pa) == 44)
                                        pa = pa + 1
                                    end
                                    if pa >= clen or mem_byte_read(content, pa) == 10 or (mem_byte_read(content, pa) == 47 and pa + 1 < clen and mem_byte_read(content, pa + 1) == 47)
                                        break
                                    end
                                    s0 = pa
                                    while pa < clen and compiler_driver_is_ident_ch(mem_byte_read(content, pa)) == 1
                                        pa = pa + 1
                                    end
                                    if pa > s0
                                        req_sym = str_sub(content, s0, pa)
                                        loc_sym = req_sym
                                        while pa < clen and (mem_byte_read(content, pa) == 32 or mem_byte_read(content, pa) == 9)
                                            pa = pa + 1
                                        end
                                        if compiler_driver_match_kw(content, pa, "as ") == 1
                                            pa = pa + 3
                                            while pa < clen and (mem_byte_read(content, pa) == 32 or mem_byte_read(content, pa) == 9)
                                                pa = pa + 1
                                            end
                                            a0 = pa
                                            while pa < clen and compiler_driver_is_ident_ch(mem_byte_read(content, pa)) == 1
                                                pa = pa + 1
                                            end
                                            if pa > a0
                                                loc_sym = str_sub(content, a0, pa)
                                            end
                                        end
                                        push(from_syms, req_sym)
                                        push(from_locals, loc_sym)
                                    else
                                        pa = pa + 1
                                    end
                                end
                            end
                        else
                            is_inc = 1
                            if compiler_driver_match_kw(content, pa, "as ") == 1
                                pa = pa + 3
                                while pa < clen and (mem_byte_read(content, pa) == 32 or mem_byte_read(content, pa) == 9)
                                    pa = pa + 1
                                end
                                a_start = pa
                                while pa < clen and compiler_driver_is_ident_ch(mem_byte_read(content, pa)) == 1
                                    pa = pa + 1
                                end
                                if pa > a_start
                                    inc_alias = str_sub(content, a_start, pa)
                                end
                            end
                        end

        while p < clen and mem_byte_read(content, p) != 10
            p = p + 1
        if p < clen and mem_byte_read(content, p) == 10
            p = p + 1

        if is_inc == 1
            if line_start > chunk_start
                push(local_chunk_idxs, chunks.len())
                push(chunks, str_sub(content, chunk_start, line_start))
            end
            inc_target = compiler_driver_resolve_std(inc_target)
            resolved = compiler_driver_resolve_path(inc_target, cur_dir, lipi_root)
            if is_from_import == 1 and from_syms.len() > 0
                c_mod = compiler_driver_load_canonical_mod(resolved, chunks, lipi_root)
                c_prefix = c_mod[0]
                m_all = c_mod[1]
                m_pub = c_mod[2]
                m_has_pub = c_mod[3]
                fi_s = 0
                while fi_s < from_syms.len()
                    rsym = from_syms[fi_s]
                    if m_has_pub == 1 and compiler_driver_list_has(m_pub, rsym) == 0
                        say "❌ [Visibility Error]: Cannot import private symbol '" + rsym + "' from module '" + resolved + "' (mark it 'pub' to export)."
                        exit(1)
                    end
                    if compiler_driver_list_has(m_all, rsym) == 0
                        say "❌ [Import Error]: Symbol '" + rsym + "' not found in module '" + resolved + "'."
                        exit(1)
                    end
                    push(file_sel_locals, from_locals[fi_s])
                    push(file_sel_targets, c_prefix + rsym)
                    fi_s = fi_s + 1
                end
            elif len(inc_alias) > 0
                c_mod = compiler_driver_load_canonical_mod(resolved, chunks, lipi_root)
                c_prefix = c_mod[0]
                m_pub = c_mod[2]
                m_has_pub = c_mod[3]
                push(file_aliases, inc_alias)
                push(file_alias_prefixes, c_prefix)
                push(file_alias_pubs, m_pub)
                push(file_alias_has_pub, m_has_pub)
                push(file_alias_paths, resolved)
            else
                compiler_driver_bundle_into_chunks(resolved, visited, chunks, lipi_root)
                push(chunks, "\n")
            end
            chunk_start = p

    if chunk_start < clen
        push(local_chunk_idxs, chunks.len())
        push(chunks, str_sub(content, chunk_start, clen))
    end
    if file_aliases.len() > 0 or file_sel_locals.len() > 0
        li_c = 0
        while li_c < local_chunk_idxs.len()
            c_idx = local_chunk_idxs[li_c]
            list_set(chunks, c_idx, compiler_driver_rewrite_aliases(chunks[c_idx], file_aliases, file_alias_prefixes, file_alias_pubs, file_alias_has_pub, file_alias_paths, file_sel_locals, file_sel_targets))
            li_c = li_c + 1
        end
    end

    if G_DRV_IMPORT_STACK != 0 and G_DRV_IMPORT_STACK.len() > 0
        _lipi_list_pop(G_DRV_IMPORT_STACK)
    end
    return 0

fn compiler_driver_bundle_source file_path visited
    G_DRV_MOD_PATHS = list()
    G_DRV_MOD_PREFIXES = list()
    G_DRV_MOD_ALL = list()
    G_DRV_MOD_PUB = list()
    G_DRV_MOD_HASPUB = list()
    chunks = list()
    G_DRV_ROOT_CHUNKS = chunks
    lipi_root = compiler_driver_get_lipi_root()
    real_path = file_path
    if file_exists(real_path) == 0
        if compiler_driver_starts_with(real_path, "packages/") == 1
            cand_aati = "aati/" + str_sub(real_path, 9, len(real_path))
            if file_exists(cand_aati) == 1
                real_path = cand_aati
            elif len(lipi_root) > 0 and file_exists(lipi_root + "/" + cand_aati) == 1
                real_path = lipi_root + "/" + cand_aati
        elif compiler_driver_starts_with(real_path, "aati/") == 1
            cand_pkg = "packages/" + str_sub(real_path, 5, len(real_path))
            if file_exists(cand_pkg) == 1
                real_path = cand_pkg
            elif len(lipi_root) > 0 and file_exists(lipi_root + "/" + cand_pkg) == 1
                real_path = lipi_root + "/" + cand_pkg
        elif len(lipi_root) > 0 and lipi_root != "."
            if file_exists(lipi_root + "/" + file_path) == 1
                real_path = lipi_root + "/" + file_path
    compiler_driver_bundle_into_chunks(real_path, visited, chunks, lipi_root)
    return compiler_driver_strip_pub(compiler_driver_join_chunks(chunks))

// ── 2. Driver Execution Wrapper ───────────────────────────────────────────────

fn compiler_driver_compile_string src_name source_code target_arch opt_level
    cfg = compiler_config_new(src_name, "a.out", target_arch, opt_level, FORMAT_ELF(), 1)
    res = compiler_pipeline_execute(cfg, source_code)
    return res

fn compiler_driver_print_banner
    say "╔══════════════════════════════════════════════════════════════════════╗"
    say "║  👑 LIPI FIRST 1.0.0 MODULAR MICRO-ARCHITECTURAL COMPILER DRIVER    ║"
    say "║  ⚡ 100% Pure Silicon Machine Code | 0% C | 0% Libc | Sovereign      ║"
    say "╚══════════════════════════════════════════════════════════════════════╝"

global g_driver_base_vaddr = 1073741824
global g_driver_entry_sym = ""
global g_driver_cache_dir = ""

fn compiler_driver_set_base_vaddr vaddr
    g_driver_base_vaddr = vaddr
    return vaddr

fn compiler_driver_set_entry_sym sym
    g_driver_entry_sym = sym
    return sym

fn compiler_driver_set_cache_dir dir_path
    g_driver_cache_dir = dir_path
    return dir_path

fn compiler_driver_compile_file_full src_path out_path target_arch opt_level emit_fmt mode_flags
    // WHY: Sovereign compilation entry point supporting packed mode flags while staying within <= 6 SysV registers:
    // bit 0 (1): DWARF debug (-g), bit 1 (2): --no-pie, bit 2 (4): --strict-ownership,
    // bit 3 (8): --strict-proof, bit 4 (16): --kavach, bit 5 (32): --strict-types,
    // bit 6 (64): --freestanding / --no-runtime, bit 7 (128): --ssa-codegen.
    lipi_root = compiler_driver_get_lipi_root()
    if file_exists(src_path) == 0
        if compiler_driver_starts_with(src_path, "packages/") == 1
            cand_aati = "aati/" + str_sub(src_path, 9, len(src_path))
            if file_exists(cand_aati) == 1
                src_path = cand_aati
            elif len(lipi_root) > 0 and file_exists(lipi_root + "/" + cand_aati) == 1
                src_path = lipi_root + "/" + cand_aati
        elif compiler_driver_starts_with(src_path, "aati/") == 1
            cand_pkg = "packages/" + str_sub(src_path, 5, len(src_path))
            if file_exists(cand_pkg) == 1
                src_path = cand_pkg
            elif len(lipi_root) > 0 and file_exists(lipi_root + "/" + cand_pkg) == 1
                src_path = lipi_root + "/" + cand_pkg
        elif len(lipi_root) > 0 and lipi_root != "."
            if file_exists(lipi_root + "/" + src_path) == 1
                src_path = lipi_root + "/" + src_path
    visited = list()
    source_code = compiler_driver_bundle_source(src_path, visited)
    if len(source_code) == 0
        source_code = file_read(src_path)
    if len(source_code) == 0
        res = compiler_result_new()
        res.res_error_count = 1
        res.res_error_msg = "Source file empty or not found: " + src_path
        res.res_stage_reached = PIPELINE_STAGE_INIT()
        res.res_success = 0
        return res
    cfg = compiler_config_new(src_path, out_path, target_arch, opt_level, emit_fmt, 0)
    cfg.cfg_debug_mode = mode_flags % 2
    cfg.cfg_no_pie = (mode_flags / 2) % 2
    cfg.cfg_strict_ownership = (mode_flags / 4) % 2
    cfg.cfg_strict_proof = (mode_flags / 8) % 2
    cfg.cfg_kavach_mode = (mode_flags / 16) % 2
    cfg.cfg_strict_types = (mode_flags / 32) % 2
    cfg.cfg_freestanding = (mode_flags / 64) % 2
    cfg.cfg_ssa_codegen = (mode_flags / 128) % 2
    cfg.cfg_base_vaddr = g_driver_base_vaddr
    cfg.cfg_entry_sym = g_driver_entry_sym
    // Content-hashed .lpo object cache fast-path when compiling to FORMAT_OBJ with --cache-dir
    lpo_cache_path = ""
    lpo_src_h = 0
    if emit_fmt == FORMAT_OBJ() and len(g_driver_cache_dir) > 0
        lpo_src_h = lpo_source_hash(source_code + "|" + str(opt_level) + "|" + str(mode_flags))
        lpo_cache_path = g_driver_cache_dir + "/obj_" + str(lpo_src_h) + ".lpo"
        cached_sz = lpo_read_cache(lpo_cache_path, lpo_src_h, out_path)
        if cached_sz > 0
            c_res = compiler_result_new()
            c_res.res_success = 1
            c_res.res_stage_reached = PIPELINE_STAGE_COMPLETE()
            c_res.res_output_bytes = cached_sz
            return c_res
        end
    end
    res = compiler_pipeline_execute(cfg, source_code)
    if res.res_success == 1 and len(lpo_cache_path) > 0
        lpo_write_cache(lpo_cache_path, lpo_src_h, out_path)
    end
    return res

fn compiler_driver_compile_file_advanced src_path out_path target_arch opt_level emit_fmt is_debug
    // WHY: Backward-compatible compilation entry point supporting DWARF debug symbols (-g) and Shared Object (.so) format.
    flag_dbg = 0
    if is_debug != 0
        flag_dbg = 1
    return compiler_driver_compile_file_full(src_path, out_path, target_arch, opt_level, emit_fmt, flag_dbg)

fn compiler_driver_compile_file src_path out_path target_arch opt_level
    // WHY: Reads source file from filesystem, recursively resolves dependencies, and routes through decoupled pipeline.
    return compiler_driver_compile_file_advanced(src_path, out_path, target_arch, opt_level, FORMAT_ELF(), 0)

fn compiler_driver_print_result res
    if res.res_success == 1
        say "✔ [COMPILATION SUCCESS]: All micro-subsystems completed successfully!"
        say "  • Tokens Scanned: " + res.res_tokens_scanned
        say "  • Register Spills: " + res.res_reg_alloc_spills
        say "  • Binary Header Size: " + res.res_output_bytes + " bytes"
    else
        say "❌ [COMPILATION ERROR at Stage " + res.res_stage_reached + "]: " + res.res_error_msg
    return res.res_success
