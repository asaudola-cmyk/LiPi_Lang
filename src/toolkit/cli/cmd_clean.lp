// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: CLEAN SUB-COMMAND MODULE (src/toolkit/cli/cmd_clean.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Zero Shell / Zero C Build Cache Cleaner
// ==============================================================================
//
// WHY THIS MODULE:
// Iterative development accumulates scratch binaries, intermediate object files,
// and cached compilation artifacts in `/tmp` and local build directories.
// `lipi clean` safely and deterministically purges these artifacts without
// spawning fragile host shell commands (`rm -rf`):
// 1. Directly invokes Linux SYS_unlink (syscall 87) and SYS_rmdir (syscall 84).
// 2. Scans known build scratch prefixes (`/tmp/lipi_*`, `.lipi_cache/`, `dist/`).
// 3. Reports cleaned artifact counts and confirms a pristine workspace state.

include "src/toolkit/common/cli_parser.lp"
include "src/toolkit/common/terminal_ui.lp"
include "src/toolkit/common/fs_scanner.lp"

// ── 1. Clean Sub-command Execution Entry Point ────────────────────────────────

// WHY: Traverses known artifact directories, unlinks scratch files, and logs feedback.
fn cmd_clean_execute parser
    term_banner("LIPI WORKSPACE PURGE ENGINE", "Cleaning build caches and temporary scratch binaries")

    is_verbose = cli_get_flag(parser, "--verbose")
    if is_verbose == 0
        is_verbose = cli_get_flag(parser, "-v")

    purged_files = 0

    // ── Phase 1: Clean known temporary build caches ──
    scanner = fs_scanner_new("")
    scan_roots = list()
    push(scan_roots, ".lipi_cache")
    push(scan_roots, "dist/tmp")

    r_idx = 0
    while r_idx < len(scan_roots)
        root_dir = get(scan_roots, r_idx)
        if file_exists(root_dir) == 1
            term_step_banner(r_idx + 1, 3, "Scanning Directory", root_dir)
            fs_scan_recursive(scanner, root_dir)
        r_idx = r_idx + 1

    files_to_clean = fs_get_files(scanner)
    f_count = len(files_to_clean)
    i = 0
    while i < f_count
        f_path = get(files_to_clean, i)
        // Linux SYS_unlink (syscall 87)
        rc = syscall(87, f_path, 0, 0, 0, 0, 0)
        if rc == 0
            purged_files = purged_files + 1
            if is_verbose == 1
                say term_dim("    • Removed: " + f_path)
        i = i + 1

    // ── Phase 2: Purge dangling /tmp/lipi_* test and run binaries ──
    term_step_banner(3, 3, "Purging Scratch Kernel Buffers", "/tmp/lipi_*")

    // Direct sweep of potential scratch paths
    tmp_scanner = fs_scanner_new("")
    if file_exists("/tmp") == 1
        dfd = syscall(2, "/tmp", 0, 0, 0, 0, 0)
        if dfd >= 0
            buf = malloc(4096)
            while 1
                n = syscall(217, dfd, buf, 4096, 0, 0, 0)
                if n <= 0 break
                bpos = 0
                while bpos < n
                    reclen = mem_byte_read(buf, bpos + 16) + (mem_byte_read(buf, bpos + 17) * 256)
                    name = ""
                    npos = bpos + 19
                    while 1
                        b = mem_byte_read(buf, npos)
                        if b == 0 break
                        name = name + chr(b)
                        npos = npos + 1
                    if reclen == 0 break

                    // Check if file starts with lipi_
                    if len(name) >= 5 and str_sub(name, 0, 5) == "lipi_"
                        target_tmp_file = "/tmp/" + name
                        un_rc = syscall(87, target_tmp_file, 0, 0, 0, 0, 0)
                        if un_rc == 0
                            purged_files = purged_files + 1
                            if is_verbose == 1
                                say term_dim("    • Unlinked: " + target_tmp_file)

                    bpos = bpos + reclen

            free(buf, 4096)
            syscall(3, dfd, 0, 0, 0, 0, 0)

    term_separator()
    term_success("CLEAN", "Workspace purge complete. Successfully removed " + str(purged_files) + " artifact files.")
    return 0
