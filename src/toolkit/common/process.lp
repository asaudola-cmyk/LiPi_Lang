// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: NATIVE KERNEL PROCESS ENGINE (src/toolkit/common/process.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | SYS_fork/SYS_execve/SYS_wait4 | Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Language toolchains must spawn compilers, test runners, and child binaries without
// relying on glibc's system(), popen(), or posix_spawn().
// Direct Linux AMD64 kernel ABI invocation provides:
// 1. Immunity from libc buffer corruption or signal handler hijacking.
// 2. Direct pipe IPC capturing child stdout without intermediate disk files.
// 3. Exact POSIX exit code extraction and termination signal reporting.
// 4. Guaranteed zero zombie process leaks through synchronous wait4 reaping.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates execution results, return status, and captured output stream.
struct ProcessResult
    pid             // Child process identifier
    exit_code       // Process exit code (0 = success)
    is_success      // 1 if exited normally with code 0, 0 otherwise
    output          // Captured standard output stream
    term_signal     // Termination signal number if killed by signal (0 if normal exit)

// ── 2. Memory & Argument Marshalling Helpers ──────────────────────────────────

// WHY: Serializes array of string pointers according to Linux System V AMD64 ABI.
// Layout: argv[0] = cmd_path, argv[1..N] = args, argv[N+1] = NULL (0).
fn proc_build_argv cmd_path args_list
    arg_count = len(args_list)
    total_ptrs = arg_count + 2 // +1 for cmd_path, +1 for terminating NULL
    buf_size = total_ptrs * 8
    if buf_size < 64
        buf_size = 64

    argv_buf = malloc(buf_size)
    mem_word_write(argv_buf, 0, cmd_path)

    i = 0
    while i < arg_count
        arg_val = get(args_list, i)
        offset = (i + 1) * 8
        mem_word_write(argv_buf, offset, arg_val)
        i = i + 1

    // Write terminating NULL pointer
    last_offset = (arg_count + 1) * 8
    mem_word_write(argv_buf, last_offset, 0)
    return argv_buf

// WHY: Prepares minimal safe environment containing essential execution PATH.
fn proc_build_envp
    envp_buf = malloc(32)
    path_str = "PATH=/usr/local/bin:/usr/bin:/bin"
    mem_word_write(envp_buf, 0, path_str)
    mem_word_write(envp_buf, 8, 0) // NULL terminator
    return envp_buf

// ── 3. Direct Process Spawning (Interactive / Inherited I/O) ──────────────────

// WHY: Executes child command with inherited standard input/output/error.
// Ideal for interactive compilers, debuggers, and REPL invocations.
fn proc_spawn cmd_path args_list
    argv = proc_build_argv(cmd_path, args_list)
    envp = proc_build_envp()
    status_buf = malloc(8)
    mem_word_write(status_buf, 0, 0)

    // Linux SYS_fork (syscall 57)
    pid = syscall(57, 0, 0, 0, 0, 0, 0)

    if pid == 0
        // Child process: execute binary via Linux SYS_execve (syscall 59)
        syscall(59, cmd_path, argv, envp, 0, 0, 0)
        // If execve returns, execution failed (binary missing or not executable)
        syscall(60, 127, 0, 0, 0, 0, 0)

    // Parent process: wait for child termination via Linux SYS_wait4 (syscall 61)
    syscall(61, pid, status_buf, 0, 0, 0, 0)
    raw_status = mem_word_read(status_buf, 0)

    // POSIX WEXITSTATUS extraction
    exit_code = (raw_status / 256) % 256

    // Free argument and status buffers
    arg_count = len(args_list)
    argv_sz = (arg_count + 2) * 8
    if argv_sz < 64 argv_sz = 64
    free(argv, argv_sz)
    free(envp, 32)
    free(status_buf, 8)

    return exit_code

// ── 4. Captured Process Execution (Direct Kernel Pipe IPC) ────────────────────

// WHY: Spawns child process, redirects its stdout to a pipe, streams the output
// into memory, reaps the child, and returns a structured ProcessResult.
fn proc_spawn_capture cmd_path args_list
    res = ProcessResult()
    res.pid = 0
    res.exit_code = -1
    res.is_success = 0
    res.output = ""
    res.term_signal = 0

    // Allocate pipe file descriptor pair: pipefd[0] = read, pipefd[1] = write
    pipe_buf = malloc(8)
    mem_word_write(pipe_buf, 0, 0)

    // Linux SYS_pipe (syscall 22)
    pipe_rc = syscall(22, pipe_buf, 0, 0, 0, 0, 0)
    if pipe_rc < 0
        free(pipe_buf, 8)
        res.exit_code = 126
        return res

    read_fd = mem_byte_read(pipe_buf, 0) + (mem_byte_read(pipe_buf, 1) * 256)
    write_fd = mem_byte_read(pipe_buf, 4) + (mem_byte_read(pipe_buf, 5) * 256)
    free(pipe_buf, 8)

    argv = proc_build_argv(cmd_path, args_list)
    envp = proc_build_envp()

    // Linux SYS_fork (syscall 57)
    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    res.pid = pid

    if pid == 0
        // ── Child Process ──
        // Close read end of pipe in child
        syscall(3, read_fd, 0, 0, 0, 0, 0)

        // Duplicate write end to STDOUT (fd 1) via Linux SYS_dup2 (syscall 33)
        syscall(33, write_fd, 1, 0, 0, 0, 0)
        // Also duplicate to STDERR (fd 2) to capture compiler diagnostics
        syscall(33, write_fd, 2, 0, 0, 0, 0)

        // Close redundant write_fd
        syscall(3, write_fd, 0, 0, 0, 0, 0)

        // Replace process image with target executable
        syscall(59, cmd_path, argv, envp, 0, 0, 0)

        // Exit immediately if execve fails
        syscall(60, 127, 0, 0, 0, 0, 0)

    // ── Parent Process ──
    // Close unused write end in parent so read will hit EOF when child closes stdout
    syscall(3, write_fd, 0, 0, 0, 0, 0)

    // Stream child stdout in chunks via Linux SYS_read (syscall 0)
    chunk_buf = malloc(4096)
    captured_text = ""

    while 1
        n = syscall(0, read_fd, chunk_buf, 4096, 0, 0, 0)
        if n <= 0
            break
        i = 0
        while i < n
            b = mem_byte_read(chunk_buf, i)
            captured_text = captured_text + chr(b)
            i = i + 1

    free(chunk_buf, 4096)
    syscall(3, read_fd, 0, 0, 0, 0, 0)

    // Wait for child process to terminate
    status_buf = malloc(8)
    mem_word_write(status_buf, 0, 0)
    syscall(61, pid, status_buf, 0, 0, 0, 0)
    raw_status = mem_word_read(status_buf, 0)
    free(status_buf, 8)

    // Parse status word: bits 8-15 = exit status, bits 0-6 = termination signal
    exit_code = (raw_status / 256) % 256
    sig_num = raw_status % 128

    res.exit_code = exit_code
    res.term_signal = sig_num
    res.output = captured_text
    if exit_code == 0 and sig_num == 0
        res.is_success = 1

    // Free argv and envp memory blocks
    arg_count = len(args_list)
    argv_sz = (arg_count + 2) * 8
    if argv_sz < 64 argv_sz = 64
    free(argv, argv_sz)
    free(envp, 32)

    return res
