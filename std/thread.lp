// 📜 লিপি bাঁটি aার্নেল মাল্টি-থ্রেডিং ও aনaারেন্সি লাইব্রেরি (Pure Lipi Native Multithreading Library)
// 🏛️ direct লিনাa্স aার্নেল পেজ-শেয়ার্ড মাল্টি-থ্রেডিং (Linux AMD64 Kernel SYS_clone ABI)
// ০% Libc, ০% pthreads নির্ভরতা — direct SYS_clone (56), SYS_sched_yield (24), SYS_exit (60)
//
// WHY: আধুনিa মাল্টি-aোর সিলিaন প্রসেসরের full শa্তি ব্যবrateের জন্য direct aার্নেল থ্রেড সৃষ্টি aরা।
// CLONE_VM (256) | CLONE_FS (512) | CLONE_FILES (1024) | CLONE_SIGHAND (2048) | CLONE_THREAD (65536) = 69376 (0x10f00)

// ১. নেটিভ লিনাa্স aার্নেল থ্রেড সৃষ্টি (Spawn Real Linux Thread via SYS_clone: syscall 56)
// WHY: নতুন থ্রেডের জন্য aার্নেল স্পেসে এa্সিaিউশন aন্টেa্সট create aরা।
// চাইল্ড থ্রেডে ০ return aরে, প্যারেন্ট থ্রেডে চাইল্ড থ্রেড আইডি (TID > 0) return aরে।
fn থ্রেড_created স্ট্যাa_টপ
    flag = 69376
    টিআইডি = syscall(56, flag, স্ট্যাa_টপ, 0, 0, 0)
    return টিআইডি

// ২. সিপিউ সময় ছেড়ে দেওয়া (Yield CPU Timeslice via SYS_sched_yield: syscall 24)
// WHY: বিজি-লুপে সিপিউ অপচয় not aরে অন্যান্য থ্রেডaে তাত্a্ষণিa রান aরার সুadd দেওয়া।
fn থ্রেড_ছেড়ে_দাও
    result = syscall(24)
    return result

// ৩. থ্রেড widthান বা সমাপ্তি (Terminate Calling Thread via SYS_exit: syscall 60)
// WHY: চাইল্ড থ্রেডের fn সমাপ্ত হলে প্যারেন্ট প্রসেসaে অa্ষত রেbে aেবলমাত্র aলিং থ্রেডটি নিষ্a্রিয় aরা।
// warning: exit_group (231) পুরো প্রসেস close aরে দেয়, aিন্তু SYS_exit (60) শুধু বর্তvalue থ্রেড সমাপ্ত aরে।
fn থ্রেড_widthান status
    syscall(60, status)

// ৪. পরমাণু স্পিনলa আটa (Acquire Spinlock with Sched Yield)
// WHY: এaাধিa থ্রেডের মধ্যে a্রিটিa্যাল সেaশন সুরa্ষায় রেস aন্ডিশন প্রতিরোধ aরা।
fn স্পিনলa_আটa লa_addr
    while mem_পড়ো(লa_addr, 0) != 0
        থ্রেড_ছেড়ে_দাও()
    mem_write(লa_addr, 0, 1)
    return 1

// ৫. পরমাণু স্পিনলa অবমুa্তি (Release Spinlock)
// WHY: a্রিটিa্যাল সেaশনের fn শেষে অন্যান্য থ্রেডের জন্য resource উন্মুa্ত aরা।
fn স্পিনলa_মুa্ত লa_addr
    mem_write(লa_addr, 0, 0)
    return 0
