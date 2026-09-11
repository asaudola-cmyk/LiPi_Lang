// ==============================================================================
// 📜 লিপি খাঁটি কার্নেল মাল্টি-থ্রেডিং ও কনকারেন্সি লাইব্রেরি (Pure Lipi Native Multithreading Library)
// 🏛️ সরাসরি লিনাক্স কার্নেল পেজ-শেয়ার্ড মাল্টি-থ্রেডিং (Linux AMD64 Kernel SYS_clone ABI)
// ০% Libc, ০% pthreads নির্ভরতা — সরাসরি SYS_clone (56), SYS_sched_yield (24), SYS_exit (60)
// ==============================================================================
//
// WHY: আধুনিক মাল্টি-কোর সিলিকন প্রসেসরের পূর্ণ শক্তি ব্যবহারের জন্য সরাসরি কার্নেল থ্রেড সৃষ্টি করা।
// CLONE_VM (256) | CLONE_FS (512) | CLONE_FILES (1024) | CLONE_SIGHAND (2048) | CLONE_THREAD (65536) = 69376 (0x10f00)

include "universe/core/memory.lp"

// ── ১. নেটিভ লিনাক্স কার্নেল থ্রেড সৃষ্টি (Spawn Real Linux Thread via SYS_clone: syscall 56) ──
// WHY: নতুন থ্রেডের জন্য কার্নেল স্পেসে এক্সিকিউশন কন্টেক্সট তৈরি করা।
// চাইল্ড থ্রেডে ০ রিটার্ন করে, প্যারেন্ট থ্রেডে চাইল্ড থ্রেড আইডি (TID > 0) রিটার্ন করে।
fn thread_create stack_top
    flag = 69376
    tid = syscall(56, flag, stack_top, 0, 0, 0)
    return tid

fn থ্রেড_তৈরি স্ট্যাক_টপ
    return thread_create(স্ট্যাক_টপ)

// ── ২. সিপিউ সময় ছেড়ে দেওয়া (Yield CPU Timeslice via SYS_sched_yield: syscall 24) ──
// WHY: বিজি-লুপে সিপিউ অপচয় না করে অন্যান্য থ্রেডকে তাত্ক্ষণিক রান করার সুযোগ দেওয়া।
fn thread_yield
    result = syscall(24)
    return result

fn থ্রেড_ছেড়ে_দাও
    return thread_yield()

// ── ৩. থ্রেড প্রস্থান বা সমাপ্তি (Terminate Calling Thread via SYS_exit: syscall 60) ──
// WHY: চাইল্ড থ্রেডের কাজ সমাপ্ত হলে প্যারেন্ট প্রসেসকে অক্ষত রেখে কেবলমাত্র কলিং থ্রেডটি নিষ্ক্রিয় করা।
// সতর্কতা: exit_group (231) পুরো প্রসেস বন্ধ করে দেয়, কিন্তু SYS_exit (60) শুধু বর্তমান থ্রেড সমাপ্ত করে।
fn thread_exit status
    syscall(60, status)

fn থ্রেড_প্রস্থান status
    thread_exit(status)

// ── ৪. পরমাণু স্পিনলক আটকানো (Acquire Spinlock with Sched Yield) ──
// WHY: একাধিক থ্রেডের মধ্যে ক্রিটিক্যাল সেকশন সুরক্ষায় রেস কন্ডিশন প্রতিরোধ করা।
// লক ইতিমধ্যে দখলকৃত থাকলে (লক_ঠিকানা মান != 0) থ্রেড_ছেড়ে_দাও() ডেকে অন্য থ্রেডকে রান করতে দেয়।
fn spinlock_lock lock_addr
    while মেমরি_পড়ো(lock_addr, 0) != 0
        thread_yield()
    মেমরি_লেখো(lock_addr, 0, 1)
    return 1

fn স্পিনলক_আটকা লক_ঠিকানা
    return spinlock_lock(লক_ঠিকানা)

fn স্পিনলক_আটক লক_ঠিকানা
    return spinlock_lock(লক_ঠিকানা)

// ── ৫. পরমাণু স্পিনলক অবমুক্তি (Release Spinlock) ──
// WHY: ক্রিটিক্যাল সেকশনের কাজ শেষে অন্যান্য থ্রেডের জন্য রিসোর্স উন্মুক্ত করা।
fn spinlock_unlock lock_addr
    মেমরি_লেখো(lock_addr, 0, 0)
    return 0

fn স্পিনলক_মুক্ত লক_ঠিকানা
    return spinlock_unlock(লক_ঠিকানা)

// ── ৬. থ্রেড-সেফ চ্যানেল (Thread-Safe Channel Primitives) ──
// WHY: লক-সুরক্ষিত সার্কুলার চ্যানেলের মাধ্যমে একাধিক থ্রেডের মধ্যে নিরাপদ ও সিনক্রোনাস বার্তা আদান-প্রদান।
// মেমরি কাঠামো (Header: 64 Bytes):
//   Offset 0:  spinlock লক (০ = আনলকড, ১ = লকড)
//   Offset 8:  ক্যাপাসিটি (ডিফল্ট ১৬)
//   Offset 16: বর্তমান আইটেম কাউন্ট
//   Offset 24: হেড সূচক (পড়ার ইনডেক্স)
//   Offset 32: টেইল সূচক (লেখার ইনডেক্স)
//   Offset 40: চ্যানেল বন্ধের ফ্ল্যাগ (০ = সক্রিয়, ১ = বন্ধ)
//   Offset 48: বাফার পয়েন্টার (ক্যাপাসিটি * ৮ বাইট)

fn channel_create
    // WHY: চ্যানেলের হেডার ও মেসেজ বাফার মেমরি বরাদ্দ ও প্রাথমিকীকরণ।
    chan = malloc(64)
    cap = 16
    buf = malloc(cap * 8)
    মেমরি_লেখো(chan, 0, 0)       // লক = ০ (আনলকড)
    মেমরি_লেখো(chan, 8, cap)     // ক্যাপাসিটি = ১৬
    মেমরি_লেখো(chan, 16, 0)      // আইটেম কাউন্ট = ০
    মেমরি_লেখো(chan, 24, 0)      // হেড = ০
    মেমরি_লেখো(chan, 32, 0)      // টেইল = ০
    মেমরি_লেখো(chan, 40, 0)      // বন্ধ = ০
    মেমরি_লেখো(chan, 48, buf)    // বাফার অ্যাড্রেস
    return chan

fn চ্যানেল_তৈরি
    return channel_create()

fn channel_send chan val
    // WHY: চ্যানেলে নিরাপদভাবে মান প্রেরণ; চ্যানেল পূর্ণ থাকলে লক ছেড়ে দিয়ে অপেক্ষা।
    cap = মেমরি_পড়ো(chan, 8)
    buf = মেমরি_পড়ো(chan, 48)
    sent = 0
    while sent == 0
        spinlock_lock(chan)
        count = মেমরি_পড়ো(chan, 16)
        if count < cap
            tail = মেমরি_পড়ো(chan, 32)
            মেমরি_লেখো(buf, tail * 8, val)
            next_tail = (tail + 1) % cap
            মেমরি_লেখো(chan, 32, next_tail)
            মেমরি_লেখো(chan, 16, count + 1)
            spinlock_unlock(chan)
            sent = 1
            return 1
        spinlock_unlock(chan)
        thread_yield()
    return 1

fn চ্যানেল_পাঠাও chan val
    return channel_send(chan, val)

fn channel_recv chan
    // WHY: চ্যানেল থেকে নিরাপদভাবে মান গ্রহণ; চ্যানেল খালি থাকলে লক ছেড়ে দিয়ে অপেক্ষা।
    cap = মেমরি_পড়ো(chan, 8)
    buf = মেমরি_পড়ো(chan, 48)
    recvd = 0
    while recvd == 0
        spinlock_lock(chan)
        count = মেমরি_পড়ো(chan, 16)
        if count > 0
            head = মেমরি_পড়ো(chan, 24)
            val = মেমরি_পড়ো(buf, head * 8)
            next_head = (head + 1) % cap
            মেমরি_লেখো(chan, 24, next_head)
            মেমরি_লেখো(chan, 16, count - 1)
            spinlock_unlock(chan)
            recvd = 1
            return val
        closed = মেমরি_পড়ো(chan, 40)
        if closed == 1
            spinlock_unlock(chan)
            return 0
        spinlock_unlock(chan)
        thread_yield()
    return 0

fn চ্যানেল_গ্রহণ chan
    return channel_recv(chan)

fn channel_close chan
    // WHY: চ্যানেল সমাপ্তি ঘোষণা যাতে অপেক্ষারত গ্রাহক থ্রেড বের হয়ে আসতে পারে।
    spinlock_lock(chan)
    মেমরি_লেখো(chan, 40, 1)
    spinlock_unlock(chan)
    return 1

fn চ্যানেল_বন্ধ chan
    return channel_close(chan)

fn channel_destroy chan
    // WHY: চ্যানেলের বাফার ও হেডার মেমরি কার্নেলে সফলভাবে ফিরিয়ে দেওয়া।
    buf = মেমরি_পড়ো(chan, 48)
    cap = মেমরি_পড়ো(chan, 8)
    free(buf, cap * 8)
    free(chan, 64)
    return 0

fn চ্যানেল_ধ্বংস chan
    return channel_destroy(chan)
