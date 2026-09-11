// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: ASYNC EPOLL EVENT LOOP ENGINE (std/event.lp)
// ⚡ 100% Sovereign Non-Blocking Event-Driven Multiplexing | C10K Architecture
// ==============================================================================

// WHY: Thread-per-connection architectures break down at scale (C10K problem).
// The Linux epoll subsystem provides O(1) event notification for thousands
// of concurrent file descriptors without busy-polling or thread-context overhead.

include "std/mem.lp"

// ১. লিনাক্স কার্নেল সিসকল ও epoll কনস্ট্যান্টস (Kernel Syscalls & Epoll Flags)
SYS_EPOLL_CREATE1 = 291
SYS_EPOLL_CTL     = 233
SYS_EPOLL_WAIT    = 232

EPOLL_CTL_ADD     = 1
EPOLL_CTL_DEL     = 2
EPOLL_CTL_MOD     = 3

EPOLLIN           = 1
EPOLLPRI          = 2
EPOLLOUT          = 4
EPOLLERR          = 8
EPOLLHUP          = 16
EPOLLET           = 2147483648 // (1 << 31) Edge-Triggered
EPOLLONESHOT      = 1073741824 // (1 << 30)

// ২. কার্নেল epoll ইভেন্ট মনিটর অবজেক্ট তৈরি (Create Epoll Instance)
// WHY: Creates a new epoll file descriptor in the Linux kernel via SYS_epoll_create1 (291).
fn ইভেন্ট_লুপ_তৈরি
    // SYS_epoll_create1(flags = 0) -> Syscall 291
    loop_fd = syscall(291, 0, 0, 0, 0, 0, 0)
    return loop_fd

fn event_loop_create
    return ইভেন্ট_লুপ_তৈরি()

fn event_লুপ_created
    return ইভেন্ট_লুপ_তৈরি()

// ৩. একটি সকেট বা ফাইল ডেসক্রিপ্টরকে epoll লিস্টে যুক্তকরণ (EPOLL_CTL_ADD)
// WHY: In Linux x86_64 ABI, struct epoll_event is a 12-byte packed structure:
// offset 0..3 : uint32 events (bitmask of EPOLLIN, EPOLLOUT, EPOLLET, etc.)
// offset 4..11: uint64 data (socket fd or user payload pointer)
fn ইভেন্ট_সকেট_যোগ loop_fd socket_fd event_mask
    event_mem = malloc(16)
    // Write uint32 event mask (offset 0..3) using 256-base arithmetic
    ev0 = event_mask % 256
    ev1 = (event_mask / 256) % 256
    ev2 = (event_mask / 65536) % 256
    ev3 = (event_mask / 16777216) % 256

    mem_write_byte(event_mem, 0, ev0)
    mem_write_byte(event_mem, 1, ev1)
    mem_write_byte(event_mem, 2, ev2)
    mem_write_byte(event_mem, 3, ev3)

    // Write uint64 socket data (offset 4..11)
    fd0 = socket_fd % 256
    fd1 = (socket_fd / 256) % 256
    fd2 = (socket_fd / 65536) % 256
    fd3 = (socket_fd / 16777216) % 256

    mem_write_byte(event_mem, 4, fd0)
    mem_write_byte(event_mem, 5, fd1)
    mem_write_byte(event_mem, 6, fd2)
    mem_write_byte(event_mem, 7, fd3)
    mem_write_byte(event_mem, 8, 0)
    mem_write_byte(event_mem, 9, 0)
    mem_write_byte(event_mem, 10, 0)
    mem_write_byte(event_mem, 11, 0)

    // SYS_epoll_ctl(epfd, EPOLL_CTL_ADD=1, fd, &event) -> Syscall 233
    status = syscall(233, loop_fd, 1, socket_fd, event_mem, 0, 0)
    free(event_mem, 16)
    return status

fn event_socket_add loop_fd socket_fd event_mask
    return ইভেন্ট_সকেট_যোগ(loop_fd, socket_fd, event_mask)


// ৪. epoll মনিটরিং লিস্ট থেকে fd অপসারণ (EPOLL_CTL_DEL)
// WHY: Stops monitoring the file descriptor and deregisters it from the kernel event table.
fn ইভেন্ট_সকেট_মুছে_ফেলো loop_fd socket_fd
    // SYS_epoll_ctl(epfd, EPOLL_CTL_DEL=2, fd, NULL) -> Syscall 233
    status = syscall(233, loop_fd, 2, socket_fd, 0, 0, 0)
    return status

fn event_socket_del loop_fd socket_fd
    return ইভেন্ট_সকেট_মুছে_ফেলো(loop_fd, socket_fd)


// ৫. epoll মনিটরিং ইভেন্ট মাস্ক সংশোধন (EPOLL_CTL_MOD)
// WHY: Switches monitored states between read, write, and edge-triggered without re-adding.
fn ইভেন্ট_সকেট_সংশোধন loop_fd socket_fd event_mask
    event_mem = malloc(16)
    ev0 = event_mask % 256
    ev1 = (event_mask / 256) % 256
    ev2 = (event_mask / 65536) % 256
    ev3 = (event_mask / 16777216) % 256

    mem_write_byte(event_mem, 0, ev0)
    mem_write_byte(event_mem, 1, ev1)
    mem_write_byte(event_mem, 2, ev2)
    mem_write_byte(event_mem, 3, ev3)

    fd0 = socket_fd % 256
    fd1 = (socket_fd / 256) % 256
    fd2 = (socket_fd / 65536) % 256
    fd3 = (socket_fd / 16777216) % 256

    mem_write_byte(event_mem, 4, fd0)
    mem_write_byte(event_mem, 5, fd1)
    mem_write_byte(event_mem, 6, fd2)
    mem_write_byte(event_mem, 7, fd3)
    mem_write_byte(event_mem, 8, 0)
    mem_write_byte(event_mem, 9, 0)
    mem_write_byte(event_mem, 10, 0)
    mem_write_byte(event_mem, 11, 0)

    status = syscall(233, loop_fd, 3, socket_fd, event_mem, 0, 0)
    free(event_mem, 16)
    return status

fn event_socket_mod loop_fd socket_fd event_mask
    return ইভেন্ট_সকেট_সংশোধন(loop_fd, socket_fd, event_mask)

// ৬. ইভেন্ট অপেক্ষা ও মাল্টিপ্লেক্সিং (SYS_epoll_wait)
// WHY: Sleeps until one or more registered file descriptors become ready for I/O.
// Zero CPU cycles are wasted during the wait.
fn ইভেন্ট_লুপ_অপেক্ষা loop_fd output_buffer max_events timeout_ms
    // SYS_epoll_wait(epfd, events, maxevents, timeout) -> Syscall 232
    ready_count = syscall(232, loop_fd, output_buffer, max_events, timeout_ms, 0, 0)
    return ready_count

fn event_loop_wait loop_fd output_buffer max_events timeout_ms
    return ইভেন্ট_লুপ_অপেক্ষা(loop_fd, output_buffer, max_events, timeout_ms)


// ৭. ট্রিগার হওয়া ইভেন্ট থেকে ফাইল ডেসক্রিপ্টর পড়া (Extract Ready FD)
// WHY: Retrieves the 32-bit socket file descriptor stored at offset 4 of struct epoll_event.
fn ইভেন্ট_এফডি_পড়ো output_buffer index
    offset = (index * 12) + 4
    b0 = mem_byte_পড়ো(output_buffer, offset + 0)
    b1 = mem_byte_পড়ো(output_buffer, offset + 1)
    b2 = mem_byte_পড়ো(output_buffer, offset + 2)
    b3 = mem_byte_পড়ো(output_buffer, offset + 3)
    fd = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
    return fd

fn event_fd_read output_buffer index
    return ইভেন্ট_এফডি_পড়ো(output_buffer, index)

fn event_fd_পড়ো output_buffer index
    return ইভেন্ট_এফডি_পড়ো(output_buffer, index)

// ৮. ট্রিগার হওয়া ইভেন্টের মাস্ক পড়া (Extract Event Mask)
// WHY: Retrieves the 32-bit event mask (e.g. EPOLLIN=1, EPOLLOUT=4) stored at offset 0.
fn ইভেন্ট_মাস্ক_পড়ো output_buffer index
    offset = index * 12
    b0 = mem_byte_পড়ো(output_buffer, offset + 0)
    b1 = mem_byte_পড়ো(output_buffer, offset + 1)
    b2 = mem_byte_পড়ো(output_buffer, offset + 2)
    b3 = mem_byte_পড়ো(output_buffer, offset + 3)
    mask = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
    return mask

fn event_mask_read output_buffer index
    return ইভেন্ট_মাস্ক_পড়ো(output_buffer, index)


// ৯. ইভেন্ট লুপ বন্ধকরণ ও ওএস রিসোর্স মুক্ত (Close Event Loop)
// WHY: Releases the kernel epoll instance file descriptor via SYS_close (3).
fn ইভেন্ট_লুপ_বন্ধ loop_fd
    // SYS_close(fd) -> Syscall 3
    syscall(3, loop_fd, 0, 0, 0, 0, 0)
    return 0

fn event_loop_close loop_fd
    return ইভেন্ট_লুপ_বন্ধ(loop_fd)

fn event_লুপ_close loop_fd
    return ইভেন্ট_লুপ_বন্ধ(loop_fd)

