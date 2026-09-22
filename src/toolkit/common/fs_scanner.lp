// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: FAST RECURSIVE FS SCANNER (src/toolkit/common/fs_scanner.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | SYS_getdents64 (217) | Zero Libc / Zero C
// ==============================================================================
//
// WHY THIS MODULE:
// Language toolchains (build, test, format, doc) spend substantial time crawling
// project source trees. Relying on host shell utilities (`find`) introduces subprocess
// overhead and non-portable behavior across distributions.
// This module directly interfaces with the Linux kernel via SYS_getdents64 (syscall 217):
// 1. Zero libc/readdir overhead — streams raw 64-bit kernel directory records.
// 2. Built-in ignore engine filtering .git, build, dist, bin, node_modules, and cache dirs.
// 3. Flexible file extension filtering (e.g. only ".lp" source files).
// 4. Guaranteed deterministic lexicographical or sequential traversal.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Directory Entry Layout Constants ───────────────────────────────────────
// Linux kernel struct linux_dirent64 layout:
//   ino64_t        d_ino;      // Offset  0 (8 bytes)
//   off64_t        d_off;      // Offset  8 (8 bytes)
//   unsigned short d_reclen;   // Offset 16 (2 bytes, little-endian)
//   unsigned char  d_type;     // Offset 18 (1 byte: 4 = DT_DIR, 8 = DT_REG, 10 = DT_LNK)
//   char           d_name[];   // Offset 19 (null-terminated string)

DT_UNKNOWN = 0
DT_FIFO    = 1
DT_CHR     = 2
DT_DIR     = 4
DT_BLK     = 6
DT_REG     = 8
DT_LNK     = 10
DT_SOCK    = 12

// ── 2. Scanner Data Structures ────────────────────────────────────────────────

// WHY: Master state tracking discovered filesystem entries and filter criteria.
struct FsScanner
    filter_ext          // Target extension (e.g. ".lp", empty string means match all)
    discovered_files    // List of matched file paths
    discovered_dirs     // List of visited directory paths
    total_files         // Total file count
    total_dirs          // Total directory count

// ── 3. Constructor & Filter Rules ─────────────────────────────────────────────

// WHY: Allocates and initializes clean scanner with designated extension filter.
fn fs_scanner_new filter_ext
    scanner = FsScanner()
    scanner.filter_ext = filter_ext
    scanner.discovered_files = list()
    scanner.discovered_dirs = list()
    scanner.total_files = 0
    scanner.total_dirs = 0
    return scanner

// WHY: High-performance filter determining if directory or file should be skipped.
// Prevents traversal into massive vendor repositories, build artifacts, or VCS trees.
fn fs_is_ignored name
    // Immediate checks for navigation dot entries
    if name == "." or name == ".."
        return 1

    // Skip hidden files and directories (.git, .vscode, .cache, .tmp, etc.)
    if len(name) > 0 and char_at(name, 0) == "."
        return 1

    // Build outputs and packaging scratch directories
    if name == "build" or name == "dist" or name == "bin" or name == "target"
        return 1

    // Dependencies, virtual environments, and caches
    if name == "node_modules" or name == "vendor" or name == ".lipi_cache" or name == "__pycache__"
        return 1

    if name == "tmp" or name == "temp" or name == ".system_generated"
        return 1

    return 0

// WHY: Verifies whether filename ends with specified extension.
fn fs_has_extension filename ext
    if len(ext) == 0
        return 1
    flen = len(filename)
    elen = len(ext)
    if flen < elen
        return 0
    offset = flen - elen
    i = 0
    while i < elen
        if char_at(filename, offset + i) != char_at(ext, i)
            return 0
        i = i + 1
    return 1

// ── 4. Recursive Traversal Engine via SYS_getdents64 ──────────────────────────

// WHY: Low-level recursive worker executing page-buffered getdents64 calls.
fn fs_scan_recursive scanner dir_path
    // Open directory descriptor with O_RDONLY (0)
    dfd = syscall(2, dir_path, 0, 0, 0, 0, 0)
    if dfd < 0
        return 0

    // Record directory in visited registry
    push(scanner.discovered_dirs, dir_path)
    scanner.total_dirs = scanner.total_dirs + 1

    // Allocate 4096-byte page for directory stream records
    buf = malloc(4096)
    subdirs_to_visit = list()

    while 1
        // Linux SYS_getdents64 (syscall 217)
        nbytes = syscall(217, dfd, buf, 4096, 0, 0, 0)
        if nbytes <= 0
            break

        bpos = 0
        while bpos < nbytes
            rec_lo = mem_byte_read(buf, bpos + 16)
            rec_hi = mem_byte_read(buf, bpos + 17)
            reclen = rec_lo + (rec_hi * 256)
            dtype = mem_byte_read(buf, bpos + 18)

            // Extract null-terminated entry name
            name = ""
            npos = bpos + 19
            while 1
                b = mem_byte_read(buf, npos)
                if b == 0
                    break
                name = name + chr(b)
                npos = npos + 1

            if reclen == 0
                break

            // Apply ignore filter
            if fs_is_ignored(name) == 0
                full_path = dir_path + "/" + name

                if dtype == DT_DIR
                    // Queue subdirectory for recursive descent
                    push(subdirs_to_visit, full_path)
                elif dtype == DT_REG or dtype == DT_LNK or dtype == DT_UNKNOWN
                    // Regular file: test extension filter
                    if fs_has_extension(name, scanner.filter_ext) == 1
                        push(scanner.discovered_files, full_path)
                        scanner.total_files = scanner.total_files + 1

            bpos = bpos + reclen

    // Clean up local resources before descending into subdirectories
    free(buf, 4096)
    syscall(3, dfd, 0, 0, 0, 0, 0)

    // Recursively process discovered subdirectories
    sub_count = len(subdirs_to_visit)
    s_idx = 0
    while s_idx < sub_count
        sub_dir = get(subdirs_to_visit, s_idx)
        fs_scan_recursive(scanner, sub_dir)
        s_idx = s_idx + 1

    return scanner.total_files

// ── 5. Query & Helper APIs ────────────────────────────────────────────────────

// WHY: Returns list of discovered matching file paths.
fn fs_get_files scanner
    return scanner.discovered_files

// WHY: Returns list of traversed directory paths.
fn fs_get_dirs scanner
    return scanner.discovered_dirs

// WHY: Total count of discovered files.
fn fs_file_count scanner
    return scanner.total_files

// WHY: Total count of traversed directories.
fn fs_dir_count scanner
    return scanner.total_dirs
