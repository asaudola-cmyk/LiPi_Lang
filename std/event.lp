// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: ASYNC EPOLL EVENT LOOP ENGINE (std/event.lp)
// ⚡ 100% Sovereign Non-Blocking Event-Driven Multiplexing | C10K Architecture
// ==============================================================================

// WHY: Thread-per-connection architectures break down at scale (C10K problem).
// The Linux epoll subsystem provides O(1) event notification for thousands
// of concurrent file descriptors without busy-polling or thread-context overhead.

include "std/mem.lp"

// epoll কনস্ট্যান্টস
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

// ১. কার্নেল epoll ইভেন্ট মনিটর অবজেক্ট তৈরি
ফাংশন ইভেন্ট_লুপ_তৈরি()
    // SYS_epoll_create1(flags = 0) -> Syscall 291
    লুপ_এফডি = সিসকল(291, 0, 0, 0, 0, 0, 0)
    return লুপ_এফডি

// ২. একটি সকেট বা এফডি-কে epoll মনিটরিং তালিকায় যুক্তকরণ (EPOLL_CTL_ADD)
// WHY: Linux AMD64 কার্নেলে struct epoll_event হলো ১২ বাইটের প্যাকড স্ট্রাকচার।
// অফসেট ০..৩: uint32 events (ইভেন্ট মাস্ক)
// অফসেট ৪..১১: uint64 data (সকেট ফাইল ডেসক্রিপ্টর)
ফাংশন ইভেন্ট_সকেট_যোগ(লুপ_এফডি, সকেট_এফডি, ইভেন্ট_মাস্ক)
    ইভেন্ট_মেম = malloc(16)
    মেমরি_শব্দ32_লেখো(ইভেন্ট_মেম, 0, ইভেন্ট_মাস্ক)
    মেমরি_লেখো(ইভেন্ট_মেম, 4, সকেট_এফডি)

    // SYS_epoll_ctl(epfd, EPOLL_CTL_ADD=1, fd, &event) -> Syscall 233
    স্ট্যাটাস = সিসকল(233, লুপ_এফডি, 1, সকেট_এফডি, ইভেন্ট_মেম, 0, 0)
    return স্ট্যাটাস

// ৩. epoll মনিটরিং তালিকা থেকে এফডি অপসারণ (EPOLL_CTL_DEL)
ফাংশন ইভেন্ট_সকেট_মুছো(লুপ_এফডি, সকেট_এফডি)
    // SYS_epoll_ctl(epfd, EPOLL_CTL_DEL=2, fd, NULL) -> Syscall 233
    স্ট্যাটাস = সিসকল(233, লুপ_এফডি, 2, সকেট_এফডি, 0, 0, 0)
    return স্ট্যাটাস

// ৪. ইভেন্ট ট্রিপল অপেক্ষা ও মাল্টিপ্লেক্সিং (SYS_epoll_wait)
// WHY: কোনো সিপিইউ ক্লক নষ্ট না করে কার্নেলে স্লিপ করা while না পর্যন্ত অন্তত একটি এফডি রেডি হয়।
ফাংশন ইভেন্ট_লুপ_অপেক্ষা(লুপ_এফডি, আউটপুট_বাফার, সর্বোচ্চ_ইভেন্ট, টাইমআউট_মিলিসেকেন্ড)
    // SYS_epoll_wait(epfd, events, maxevents, timeout) -> Syscall 232
    রেডি_সংখ্যা = সিসকল(232, লুপ_এফডি, আউটপুট_বাফার, সর্বোচ্চ_ইভেন্ট, টাইমআউট_মিলিসেকেন্ড, 0, 0)
    return রেডি_সংখ্যা

// ৫. ট্রিগার হওয়া ইভেন্ট থেকে ফাইল ডেসক্রিপ্টর পাঠ (Extract Ready FD)
ফাংশন ইভেন্ট_এফডি_পড়ো(আউটপুট_বাফার, ইনডেক্স)
    অফসেট = ইনডেক্স * 12 + 4
    return মেমরি_পড়ো(আউটপুট_বাফার, অফসেট)

// ৬. ট্রিগার হওয়া ইভেন্টের মাস্ক ফ্ল্যাগ পাঠ (Extract Event Mask)
ফাংশন ইভেন্ট_মাস্ক_পড়ো(আউটপুট_বাফার, ইনডেক্স)
    অফসেট = ইনডেক্স * 12
    return মেমরি_শব্দ32_পড়ো(আউটপুট_বাফার, অফসেট)

// ৭. ইভেন্ট লুপ বন্ধকরণ ও ওএস রিসোর্স মুক্ত
ফাংশন ইভেন্ট_লুপ_বন্ধ(লুপ_এফডি)
    // SYS_close(fd) -> Syscall 3
    সিসকল(3, লুপ_এফডি, 0, 0, 0, 0, 0)
    return 0
