// ==============================================================================
// 👑 LIPI TEST SUITE: NATIVE KERNEL I/O & EPOLL HIGH-CONCURRENCY ENGINE (tests/test_io_and_epoll.lp)
// Milestone: First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi — Zero Foreign Dependencies
// ==============================================================================

include "universe/core/io.lp"
include "universe/net/socket.lp"

fn main
    say "=== LIPI KERNEL I/O & EPOLL TEST ==="

    // 1. Unbuffered Raw Inline Printing
    say "1. Testing unbuffered raw inline printing:"
    print_raw("  [Lipi Raw]")
    print_inline(" -> Inline Verified\n")

    // 2. Epoll Instance Creation via Linux Syscall 291 (SYS_epoll_create1)
    say "2. Testing Linux Kernel epoll_create1:"
    epfd = epoll_create()
    if epfd < 0
        say "FAIL: epoll_create failed"
        exit(1)
    say "✔ Successfully allocated kernel epoll instance fd: " + str(epfd)

    // 3. Create TCP Socket and Register with Epoll
    sfd = socket_create()
    if sfd < 0
        say "FAIL: socket_create failed"
        exit(1)
    say "✔ Created TCP socket fd: " + str(sfd)

    // Add socket to epoll monitoring for READ (EPOLLIN)
    add_res = epoll_add_fd(epfd, sfd, EPOLLIN)
    if add_res != 0
        say "FAIL: epoll_add_fd failed"
        exit(1)
    say "✔ Registered socket with kernel epoll instance (EPOLL_CTL_ADD)"

    // Modify socket epoll mask to READ | WRITE
    mod_res = epoll_mod_fd(epfd, sfd, EPOLLIN + EPOLLOUT)
    if mod_res != 0
        say "FAIL: epoll_mod_fd failed"
        exit(1)
    say "✔ Modified epoll monitoring mask (EPOLL_CTL_MOD)"

    // Delete socket from epoll
    del_res = epoll_del_fd(epfd, sfd)
    if del_res != 0
        say "FAIL: epoll_del_fd failed"
        exit(1)
    say "✔ Deregistered socket from epoll (EPOLL_CTL_DEL)"

    // Clean up
    socket_close(sfd)
    syscall(3, epfd, 0, 0, 0, 0, 0) // SYS_close epfd

    say "PASS: test_io_and_epoll"
    return 0
