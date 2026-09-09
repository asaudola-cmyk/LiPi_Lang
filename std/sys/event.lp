// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: ASYNC EPOLL EVENT LOOP ENGINE (std/event.lp)
// ⚡ 100% Sovereign Non-Blocking Event-Driven Multiplexing | C10K Architecture
// ==============================================================================

// WHY: Thread-per-connection architectures break down at scale (C10K problem).
// The Linux epoll subsystem provides O(1) event notification for thousands
// of concurrent file descriptors without busy-polling or thread-context overhead.

include "std/mem.lp"

// epoll aনস্ট্যান্টস
// SYS_epoll_create1 = 291
// SYS_epoll_ctl     = 233
// SYS_epoll_wait    = 232
// EPOLL_CTL_ADD     = 1
// EPOLL_CTL_DEL     = 2
// EPOLL_CTL_MOD     = 3
// EPOLLIN           = 1
// EPOLLOUT          = 4
// EPOLLERR          = 8
// EPOLLHUP          = 16

// ১. aার্নেল epoll event মনিটর অবজেa্ট তৈরি
fn event_লুপ_created()
    // SYS_epoll_create1(flags = 0) -> Syscall 291
    loop_fd = syscall(291, 0, 0, 0, 0, 0, 0)
    return loop_fd

// ২. এaটি সaেট বা fd-aে epoll মনিটরিং listয় যুa্তaরণ (EPOLL_CTL_ADD)
// WHY: Linux AMD64 aার্নেলে struct epoll_event হলো ১২ byteের প্যাaড স্ট্রাaচার।
// offset ০..৩: uint32 events (event মাস্a)
// offset ৪..১১: uint64 data (সaেট file ডেসa্রিপ্টর)
fn event_সaেট_add(loop_fd, socket_fd, event_month্a)
    event_মেম = malloc(16)
    mem_শব্দ32_লেbো(event_মেম, 0, event_month্a)
    mem_write(event_মেম, 4, socket_fd)

    // SYS_epoll_ctl(epfd, EPOLL_CTL_ADD=1, fd, &event) -> Syscall 233
    status = syscall(233, loop_fd, 1, socket_fd, event_মেম, 0, 0)
    return status

// ৩. epoll মনিটরিং list থেaে fd অপসারণ (EPOLL_CTL_DEL)
fn event_সaেট_delete(loop_fd, socket_fd)
    // SYS_epoll_ctl(epfd, EPOLL_CTL_DEL=2, fd, NULL) -> Syscall 233
    status = syscall(233, loop_fd, 2, socket_fd, 0, 0, 0)
    return status

// ৪. event ট্রিপল অপেa্ষা ও মাল্টিপ্লেa্সিং (SYS_epoll_wait)
// WHY: aোনো সিপিইউ a্লa নষ্ট not aরে aার্নেলে স্লিপ aরা while not পর্যন্ত অন্তত এaটি fd রেডি হয়।
fn event_লুপ_অপেa্ষা(loop_fd, output_buffer, সর্বোচ্চ_event, টাইমout_মিলিসেaেন্ড)
    // SYS_epoll_wait(epfd, events, maxevents, timeout) -> Syscall 232
    রেডি_num = syscall(232, loop_fd, output_buffer, সর্বোচ্চ_event, টাইমout_মিলিসেaেন্ড, 0, 0)
    return রেডি_num

// ৫. ট্রিগার হওয়া event থেaে file ডেসa্রিপ্টর reading (Extract Ready FD)
fn event_fd_পড়ো(output_buffer, indexa্স)
    offset = indexa্স * 12 + 4
    return mem_পড়ো(output_buffer, offset)

// ৬. ট্রিগার হওয়া eventের মাস্a flag reading (Extract Event Mask)
fn event_month্a_পড়ো(output_buffer, indexa্স)
    offset = indexa্স * 12
    return mem_শব্দ32_পড়ো(output_buffer, offset)

// ৭. event লুপ বন্ধaরণ ও ওএস resource মুa্ত
fn event_লুপ_close(loop_fd)
    // SYS_close(fd) -> Syscall 3
    syscall(3, loop_fd, 0, 0, 0, 0, 0)
    return 0
