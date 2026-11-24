// ==============================================================================
// LIPI PERMANENT REGRESSION TEST: MULTITHREADED SYS_EXIT_GROUP vs THREAD_EXIT
// Verifies:
//   1. exit(42) terminates all sibling OS threads cleanly via SYS_exit_group (231)
//   2. process_exit(19) terminates all sibling OS threads cleanly via SYS_exit_group (231)
//   3. Unhandled throw terminates all sibling OS threads cleanly with status 1
//   4. Returning from main() (_start epilogue) terminates detached OS threads cleanly
//   5. thread_exit(0) terminates ONLY the calling thread (SYS_exit 60), preserving parent
// ==============================================================================

include "utso/os/thread.lp"
include "utso/os/process.lp"

fn eg_assert cond msg
    if cond == 0
        say "FAIL EXIT_GROUP: " + msg
        exit(1)
    end
    return 0

fn eg_infinite_daemon flag_ptr
    atomic_add(flag_ptr, 1)
    while 1 == 1
        process_sleep_ms(50)
    end
    return 0

fn eg_thread_exit_worker cnt_ptr
    atomic_add(cnt_ptr, 1)
    thread_exit(0)
    return 0

fn eg_wait_bounded pid timeout_ms
    // WHY: Polls wait4(WNOHANG) up to timeout_ms so a broken SYS_exit(60) hang fails fast instead of deadlocking CI.
    t0 = clock_ms()
    ws = lipi_alloc(16)
    while 1 == 1
        sys_poke64(ws, 0)
        rc = sys_wait4(pid, ws, 1, 0) // WNOHANG = 1
        if rc == pid
            st = sys_peek32(ws)
            lipi_free_sized(ws, 16)
            return st
        end
        if (clock_ms() - t0) >= timeout_ms
            sys_kill(pid, 9)
            sys_wait4(pid, ws, 0, 0)
            lipi_free_sized(ws, 16)
            return 0 - 999
        end
        process_sleep_ms(5)
    end
    return 0 - 999

fn main
    // 1. exit(42) kills entire thread group even with 2 active infinite-loop OS threads
    pid1 = process_fork()
    if pid1 == 0
        ready1 = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
        mem_word_write(ready1, 0, 0)
        thread_spawn_shared(fn_ptr(eg_infinite_daemon), ready1)
        thread_spawn_shared(fn_ptr(eg_infinite_daemon), ready1)
        while mem_word_read(ready1, 0) < 2
            thread_yield()
        end
        exit(42)
    end
    st1 = eg_wait_bounded(pid1, 2000)
    eg_assert(st1 != (0 - 999), "exit(42) did not hang with live daemon threads")
    eg_assert(process_wifexited(st1) == 1 && process_wexitstatus(st1) == 42, "exit(42) status == 42")

    // 2. process_exit(19) kills entire thread group cleanly
    pid2 = process_fork()
    if pid2 == 0
        ready2 = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
        mem_word_write(ready2, 0, 0)
        thread_spawn_shared(fn_ptr(eg_infinite_daemon), ready2)
        while mem_word_read(ready2, 0) < 1
            thread_yield()
        end
        process_exit(19)
    end
    st2 = eg_wait_bounded(pid2, 2000)
    eg_assert(st2 != (0 - 999), "process_exit(19) did not hang with live daemon thread")
    eg_assert(process_wifexited(st2) == 1 && process_wexitstatus(st2) == 19, "process_exit(19) status == 19")

    // 3. Unhandled throw kills entire thread group cleanly with status 1
    pid3 = process_fork()
    if pid3 == 0
        ready3 = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
        mem_word_write(ready3, 0, 0)
        thread_spawn_shared(fn_ptr(eg_infinite_daemon), ready3)
        while mem_word_read(ready3, 0) < 1
            thread_yield()
        end
        throw 777
    end
    st3 = eg_wait_bounded(pid3, 2000)
    eg_assert(st3 != (0 - 999), "unhandled throw did not hang with live daemon thread")
    eg_assert(process_wifexited(st3) == 1 && process_wexitstatus(st3) == 1, "unhandled throw status == 1")

    // 4. Returning from main() (_start epilogue SYS_exit_group) terminates detached threads cleanly
    compiler = ""
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        compiler = "./bin/lipc"
    elif syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        compiler = "./bin/lipc_bin"
    end
    if compiler != ""
        src_p = "/tmp/lipi_tst_eg_main_" + str(process_getpid()) + ".lp"
        bin_p = "/tmp/lipi_tst_eg_main_" + str(process_getpid())
        child_code = "include \"utso/os/thread.lp\"\nfn bg p\n    atomic_add(p, 1)\n    while 1 == 1\n        thread_yield()\n    end\n    return 0\nfn main\n    p = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)\n    mem_word_write(p, 0, 0)\n    thread_spawn_shared(fn_ptr(bg), p)\n    while mem_word_read(p, 0) < 1\n        thread_yield()\n    end\n    return 7\nmain()\n"
        file_write(src_p, child_code)
        c_res = process_capture_full(compiler, [src_p, "-o", bin_p], "", 15000)
        eg_assert(c_res.exit_code == 0, "compiled _start exit_group child")
        r_res = process_capture_full(bin_p, [], "", 2000)
        syscall(87, src_p, 0, 0, 0, 0, 0)
        syscall(87, bin_p, 0, 0, 0, 0, 0)
        eg_assert(r_res.timed_out == 0 && r_res.exit_code == 7, "_start normal main return terminated detached thread with code 7")
    end

    // 5. thread_exit(0) terminates ONLY the calling thread (SYS_exit 60), leaving parent intact
    cnt = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    mem_word_write(cnt, 0, 0)
    hs = []
    i = 0
    while i < 4
        hs = push(hs, thread_spawn_joinable(fn_ptr(eg_thread_exit_worker), cnt, 65536))
        i = i + 1
    end
    i = 0
    while i < 4
        thread_join(hs[i])
        i = i + 1
    end
    eg_assert(mem_word_read(cnt, 0) == 4, "4 threads exited via thread_exit(0) without killing parent")
    syscall(11, cnt, 4096, 0, 0, 0, 0)

    say "PASS: test_exit_group_multithreaded (exit+process_exit+throw+_start_return+thread_exit)"
    return 0
