// 📜 লিপি সরাসরি কার্নেল নেটওয়ার্কিং ও সকেট লাইব্রেরি (Pure Lipi Native Networking)
// 🏛️ সরাসরি লিনাক্স কার্নেল টিসিপি/আইপি স্ট্যাক ও এইচটিটিপি প্রোটোকল ইঞ্জিন (Linux AMD64 Kernel ABI)
// ০% Libc, ০% বহিরাগত লাইব্রেরি — সরাসরি র লিনাক্স সকেট সিসকল

include "universe/core/memory.lp"

// ১. র টিসিপি সকেট তৈরি (Create TCP Socket via SYS_socket: syscall 41)
// WHY: কার্নেল থেকে AF_INET (IPv4 = 2) এবং SOCK_STREAM (TCP = 1) সকেট ফাইল ডেসক্রিপ্টর বরাদ্দ নেওয়া।
fn socket_create
    fd = syscall(41, 2, 1, 0, 0, 0, 0)
    return fd

fn সকেট_তৈরি
    return socket_create()

// ২. সকেট পুনঃব্যবহার অপশন সেট (Set SO_REUSEADDR via SYS_setsockopt: syscall 54)
// WHY: সার্ভার রিস্টার্টের সময় 'Address already in use' ত্রুটি এড়ানো।
// SOL_SOCKET = 1, SO_REUSEADDR = 2, optval = 1, optlen = 4
fn socket_set_reuseaddr fd mem_addr
    mem_write_word(mem_addr, 0, 1)
    code = syscall(54, fd, 1, 2, mem_addr, 4, 0)
    return code

fn সকেট_অপশন_সেট fd মেমরি_ঠিকানা
    return socket_set_reuseaddr(fd, মেমরি_ঠিকানা)

// ৩. নন-ব্লকিং মোড সক্রিয়করণ (Set O_NONBLOCK via SYS_fcntl: syscall 72)
// WHY: ক্লায়েন্ট সংযোগের জন্য অপেক্ষা করার সময় থ্রেড বা টেস্ট রানার ব্লক না হওয়া।
// F_GETFL = 3, F_SETFL = 4, O_NONBLOCK = 2048 (0x800)
fn socket_set_nonblocking fd
    flags = syscall(72, fd, 3, 0, 0, 0, 0)
    new_flags = flags + 2048
    code = syscall(72, fd, 4, new_flags, 0, 0, 0)
    return code

fn সকেট_ননব্লকিং_সেট fd
    return socket_set_nonblocking(fd)

// ৪. sockaddr_in স্ট্রাকচার কনস্ট্রাকশন (16-byte IPv4 Address Layout)
// WHY: পোর্ট ও আইপিকে নেটওয়ার্ক বাইট অর্ডারে (Big Endian) মেমরিতে সাজানো।
// offset 0..1: sin_family = AF_INET (2)
// offset 2..3: sin_port = htons(port)
// offset 4..7: sin_addr = INADDR_ANY (0.0.0.0)
// offset 8..15: zero padding
fn socket_addr_prepare buf_addr port
    hi_byte = port / 256
    lo_byte = port % 256
    mem_byte_write(buf_addr, 0, 2)
    mem_byte_write(buf_addr, 1, 0)
    mem_byte_write(buf_addr, 2, hi_byte)
    mem_byte_write(buf_addr, 3, lo_byte)
    i = 4
    while i < 16
        mem_byte_write(buf_addr, i, 0)
        i = i + 1
    return 0

fn সকেট_ঠিকানা_প্রস্তুত বাফার_ঠিকানা পোর্ট
    return socket_addr_prepare(বাফার_ঠিকানা, পোর্ট)

// WHY: আইপি অ্যাড্রেস নির্দিষ্ট করে sockaddr_in স্ট্রাকচার প্রস্তুত (e.g. 127.0.0.1)
fn socket_addr_prepare_ip buf_addr ip0 ip1 ip2 ip3 port
    hi_byte = port / 256
    lo_byte = port % 256
    mem_byte_write(buf_addr, 0, 2)
    mem_byte_write(buf_addr, 1, 0)
    mem_byte_write(buf_addr, 2, hi_byte)
    mem_byte_write(buf_addr, 3, lo_byte)
    mem_byte_write(buf_addr, 4, ip0)
    mem_byte_write(buf_addr, 5, ip1)
    mem_byte_write(buf_addr, 6, ip2)
    mem_byte_write(buf_addr, 7, ip3)
    i = 8
    while i < 16
        mem_byte_write(buf_addr, i, 0)
        i = i + 1
    return 0

fn সকেট_ঠিকানা_আইপি_প্রস্তুত বাফার_ঠিকানা ip0 ip1 ip2 ip3 পোর্ট
    return socket_addr_prepare_ip(বাফার_ঠিকানা, ip0, ip1, ip2, ip3, পোর্ট)

// ৫. নির্দিষ্ট পোর্টে বাইন্ড করা (Bind Socket via SYS_bind: syscall 49)
// WHY: অপারেটিং সিস্টেমে লোকাল টিসিপি পোর্টে সকেট ফাইল ডেসক্রিপ্টর নিবন্ধন করা।
fn socket_bind fd buf_addr port
    socket_addr_prepare(buf_addr, port)
    res = syscall(49, fd, buf_addr, 16, 0, 0, 0)
    return res

fn পোর্ট_বাইন্ড fd বাফার_ঠিকানা পোর্ট
    return socket_bind(fd, বাফার_ঠিকানা, পোর্ট)

// ৬. সংযোগ শোনার মোড (Listen via SYS_listen: syscall 50)
// WHY: ইনকামিং ক্লায়েন্ট কানেকশনের জন্য কার্নেল কিউ সক্রিয় করা।
fn socket_listen fd backlog
    res = syscall(50, fd, backlog, 0, 0, 0, 0)
    return res

fn সকেট_লিসেন fd ব্যাকলগ
    return socket_listen(fd, ব্যাকলগ)

// ৭. ইনকামিং সংযোগ গ্রহণ (Accept Connection via SYS_accept: syscall 43)
// WHY: পেন্ডিং ক্লায়েন্ট কানেকশন থেকে নতুন ক্লায়েন্ট ফাইল ডেসক্রিপ্টর রিটার্ন পাওয়া।
fn socket_accept fd
    client_fd = syscall(43, fd, 0, 0, 0, 0, 0)
    return client_fd

fn সকেট_গ্রহণ fd
    return socket_accept(fd)

// ৮. রিমোট হোস্টে সংযোগ স্থাপন (Connect via SYS_connect: syscall 42)
// WHY: কার্নেলকে নির্দেশ দিয়ে রিমোট টিসিপি সার্ভারে সংযোগ স্থাপন ও থ্রি-ওয়ে হ্যান্ডশেক শুরু করা।
fn socket_connect fd buf_addr port
    socket_addr_prepare(buf_addr, port)
    res = syscall(42, fd, buf_addr, 16, 0, 0, 0)
    return res

fn সকেট_সংযোগ fd বাফার_ঠিকানা পোর্ট
    return socket_connect(fd, বাফার_ঠিকানা, পোর্ট)

fn socket_connect_ip fd buf_addr ip0 ip1 ip2 ip3 port
    // WHY: নির্দিষ্ট রিমোট আইপি ও পোর্টে টিসিপি সংযোগ স্থাপন করা।
    socket_addr_prepare_ip(buf_addr, ip0, ip1, ip2, ip3, port)
    res = syscall(42, fd, buf_addr, 16, 0, 0, 0)
    return res

fn সকেট_আইপি_সংযোগ fd বাফার_ঠিকানা ip0 ip1 ip2 ip3 পোর্ট
    return socket_connect_ip(fd, বাফার_ঠিকানা, ip0, ip1, ip2, ip3, পোর্ট)

// ৯. সকেট বন্ধ করা (Close Socket via SYS_close: syscall 3)
// WHY: নেটওয়ার্ক রিসোর্স সঠিকভাবে কার্নেলকে ফেরত দেওয়া।
fn socket_close fd
    code = syscall(3, fd, 0, 0, 0, 0, 0)
    return code

fn সকেট_বন্ধ fd
    return socket_close(fd)

// ১০. সকেট রিসিভ টাইমআউট সেট (Set SO_RCVTIMEO via SYS_setsockopt: syscall 54)
// WHY: Slowloris DoS প্রতিরোধে ক্লায়েন্ট সংযোগে সর্বোচ্চ ডেটা আসার সময়সীমা নির্ধারণ করা।
// SOL_SOCKET = 1, SO_RCVTIMEO = 20, sizeof(timeval) = 16 bytes
fn socket_set_rcvtimeo fd sec
    tv = malloc(16)
    mem_write(tv, 0, sec)
    mem_write(tv, 8, 0)
    res = syscall(54, fd, 1, 20, tv, 16, 0)
    free(tv, 16)
    return res

fn সকেট_রিসিভ_টাইমআউট fd সেকেন্ড
    return socket_set_rcvtimeo(fd, সেকেন্ড)

// ১১. সকেট সেন্ড টাইমআউট সেট (Set SO_SNDTIMEO via SYS_setsockopt: syscall 54)
// WHY: ধীরগতির বা হ্যাং হওয়া ক্লায়েন্ট সকেটে রেসপন্স পাঠানোর সর্বোচ্চ সময়সীমা নির্ধারণ।
// SOL_SOCKET = 1, SO_SNDTIMEO = 21, sizeof(timeval) = 16 bytes
fn socket_set_sndtimeo fd sec
    tv = malloc(16)
    mem_write(tv, 0, sec)
    mem_write(tv, 8, 0)
    res = syscall(54, fd, 1, 21, tv, 16, 0)
    free(tv, 16)
    return res

fn সকেট_সেন্ড_টাইমআউট fd সেকেন্ড
    return socket_set_sndtimeo(fd, সেকেন্ড)

// ১২. সকেট পোল রিড (Poll Socket Read Readiness via SYS_poll: syscall 7)
// WHY: সকেট থেকে ডেটা আসার জন্য নন-ব্লকিং অপেক্ষা (POLLIN = 1)। টাইমআউট পার হলে ০ রিটার্ন করে।
// struct pollfd layout: fd (4 bytes), events (2 bytes), revents (2 bytes) = 8 bytes
fn socket_poll_read fd timeout_ms
    pfd = malloc(8)
    mem_byte_write(pfd, 0, fd % 256)
    mem_byte_write(pfd, 1, (fd / 256) % 256)
    mem_byte_write(pfd, 2, (fd / 65536) % 256)
    mem_byte_write(pfd, 3, (fd / 16777216) % 256)
    mem_byte_write(pfd, 4, 1) // POLLIN = 0x0001
    mem_byte_write(pfd, 5, 0)
    mem_byte_write(pfd, 6, 0)
    mem_byte_write(pfd, 7, 0)
    res = syscall(7, pfd, 1, timeout_ms, 0, 0, 0)
    free(pfd, 8)
    return res

fn সকেট_পোল_রিড fd মিলিসেকেন্ড
    return socket_poll_read(fd, মিলিসেকেন্ড)

// ── ১৩. লিনাক্স কার্নেল হাই-কনকারেন্সি ইপোল ইঞ্জিন (Pure Linux Kernel Epoll Engine) ───
// WHY: $O(1)$ স্কেলেবিলিটির সাথে একসাথে হাজার হাজার সমান্তরাল সকেট সংযোগ পরিচালনা করা।
// ০% Libc, ০% libevent/libuv — সরাসরি লিনাক্স কার্নেল সিসকল SYS_epoll_create1 (291),
// SYS_epoll_ctl (233), এবং SYS_epoll_wait (232)।

EPOLL_CTL_ADD = 1
EPOLL_CTL_DEL = 2
EPOLL_CTL_MOD = 3

EPOLLIN      = 1
EPOLLPRI     = 2
EPOLLOUT     = 4
EPOLLERR     = 8
EPOLLHUP     = 16

fn epoll_create
    // WHY: SYS_epoll_create1 (291) কল করে নতুন কার্নেল ইপোল ইনস্ট্যান্স বরাদ্দ নেওয়া।
    // flags = 0 (or EPOLL_CLOEXEC = 524288)
    return syscall(291, 524288, 0, 0, 0, 0, 0)

fn ইপোল_তৈরি
    return epoll_create()

fn epoll_add_fd epfd fd events_mask
    // WHY: কার্নেল ইপোল তালিকায় নির্দিষ্ট সকেট ফাইল ডেসক্রিপ্টর ও ইভেন্ট মাস্ক যোগ করা।
    // x86_64 struct epoll_event layout (16 bytes):
    // offset 0..3: uint32 events
    // offset 4..7: padding (4 bytes)
    // offset 8..15: uint64 data (fd)
    ev = malloc(16)
    mem_write_u32(ev, 0, events_mask)
    mem_write_u32(ev, 4, 0)
    mem_write(ev, 8, fd)
    res = syscall(233, epfd, 1, fd, ev, 0, 0) // EPOLL_CTL_ADD = 1
    free(ev, 16)
    return res

fn ইপোল_যুক্ত epfd fd ইভেন্ট_মাস্ক
    return epoll_add_fd(epfd, fd, ইভেন্ট_মাস্ক)

fn epoll_del_fd epfd fd
    // WHY: কার্নেল ইপোল তালিকা থেকে নির্দিষ্ট সকেট অপসারিত করা (EPOLL_CTL_DEL = 2)।
    return syscall(233, epfd, 2, fd, 0, 0, 0)

fn ইপোল_মুছ epfd fd
    return epoll_del_fd(epfd, fd)

fn epoll_mod_fd epfd fd events_mask
    // WHY: চলমান সকেট মনিটরিং ইভেন্ট মাস্ক পরিবর্তন করা (EPOLL_CTL_MOD = 3)।
    ev = malloc(16)
    mem_write_u32(ev, 0, events_mask)
    mem_write_u32(ev, 4, 0)
    mem_write(ev, 8, fd)
    res = syscall(233, epfd, 3, fd, ev, 0, 0) // EPOLL_CTL_MOD = 3
    free(ev, 16)
    return res

fn ইপোল_পরিবর্তন epfd fd ইভেন্ট_মাস্ক
    return epoll_mod_fd(epfd, fd, ইভেন্ট_মাস্ক)

fn epoll_wait_events epfd events_buf maxevents timeout_ms
    // WHY: কার্নেলে সক্রিয় সকেট ইভেন্ট আসার জন্য অপেক্ষা (SYS_epoll_wait: syscall 232)।
    return syscall(232, epfd, events_buf, maxevents, timeout_ms, 0, 0)

fn ইপোল_অপেক্ষা epfd ইভেন্টস_বাফার সর্বোচ্চ_ইভেন্ট টাইমআউট
    return epoll_wait_events(epfd, ইভেন্টস_বাফার, সর্বোচ্চ_ইভেন্ট, টাইমআউট)

fn epoll_event_get_fd events_buf idx
    // WHY: ইপোল রেজাল্ট বাফার থেকে idx-তম সক্রিয় সকেটের ফাইল ডেসক্রিপ্টর নিষ্কাশন।
    offset = (idx * 16) + 8
    return mem_read(events_buf, offset)

fn ইপোল_ঘটনা_এফডি ইভেন্টস_বাফার সূচক
    return epoll_event_get_fd(ইভেন্টস_বাফার, সূচক)

fn epoll_event_get_events events_buf idx
    // WHY: ইপোল রেজাল্ট বাফার থেকে idx-তম ট্রিগার হওয়া ইভেন্ট ফ্ল্যাগ (EPOLLIN/EPOLLOUT) পড়া।
    offset = idx * 16
    return mem_read_u32(events_buf, offset)

fn ইপোল_ঘটনা_ইভেন্টস ইভেন্টস_বাফার সূচক
    return epoll_event_get_events(ইভেন্টস_বাফার, সূচক)
