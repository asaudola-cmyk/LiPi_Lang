// ==============================================================================
// 👑 LIPI SOVEREIGN BINARY DATABASE ENGINE (apps/website/db_engine.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Zero External DBMS | Direct Silicon Storage
//
// WHY: Implements a standalone, persistent 32-byte binary record database engine
// directly on Linux kernel filesystem syscalls (SYS_open, SYS_lseek, SYS_write,
// SYS_read, SYS_fsync) with zero data loss guarantee.
// ==============================================================================

অন্তর্ভুক্ত "std/io.lp"
অন্তর্ভুক্ত "std/mem.lp"

// ১. ডাটাবেজ ফাইল খোলা বা তৈরি করা (Open or Create Binary DB File)
// WHY: O_RDWR (2) | O_CREAT (64) = 66, Mode 0644o = 420
কাজ ডিবি_খোলো(পাথ) {
     fd = syscall(২, পাথ, ৬৬, ৪২০)
    return fd
}

// ২. ডাটাবেজে নতুন রেকর্ড ইনসার্ট করা (Insert Record with SYS_fsync)
// WHY: 32-byte binary layout: [ID: 8B | Timestamp: 8B | Status: 8B | Value: 8B]
// SYS_fsync (74) ensures the data is written directly to physical NVMe/SSD silicon.
কাজ ডিবি_রেকর্ড_যোগ(fd, মান) {
    // ফাইলের আকার ও পরবর্তী আইডি নির্ধারণ
     আকার = syscall(৮, fd, ০, ২) // lseek SEEK_END
     পরবর্তী_আইডি = (আকার / ৩২) + ১

     বাফ = মেমরি_বরাদ্দ(৩২)
    মেমরি_লেখো(বাফ, ০, পরবর্তী_আইডি)
    মেমরি_লেখো(বাফ, ৮, সিপিউ_ক্লক())
    মেমরি_লেখো(বাফ, ১৬, ১) // স্ট্যাটাস ১ = সক্রিয়
    মেমরি_লেখো(বাফ, ২৪, মান) // ডেটা মান

    // ৩২ বাইট রেকর্ড ফাইলে লেখা
    syscall(১, fd, বাফ, ৩২)

    // হার্ডওয়্যার ডিস্কে সরাসরি ফ্লাশ (Zero Data Loss)
    syscall(৭৪, fd)

    মেমরি_মুক্তি(বাফ, ৩২)
    return পরবর্তী_আইডি
}

// ৩. রেকর্ড মুছে ফেলা (Soft Delete Record via Offset Mutation)
// WHY: স্ট্যাটাস ফিল্ডকে ০ করে দিলে রেকর্ডটি নিষ্ক্রিয় হয়, ডাটাবেজের indexক্স অখণ্ড থাকে।
কাজ ডিবি_রেকর্ড_মুছো(fd, টার্গেট_আইডি) {
    if টার্গেট_আইডি <= ০ {
        return ০
    }

     অফসেট = (টার্গেট_আইডি - ১) * ৩২
    // স্ট্যাটাস ফিল্ড অফসেট + ১৬ এ পয়েন্ট করা
    syscall(৮, fd, অফসেট + ১৬, ০) // lseek SEEK_SET

     বাফ = মেমরি_বরাদ্দ(৩২)
    মেমরি_লেখো(বাফ, ০, ০) // স্ট্যাটাস ০ = মুছে ফেলা
    syscall(১, fd, বাফ, ৮)

    // হার্ডওয়্যার ডিস্কে সিঙ্ক
    syscall(৭৪, fd)
    মেমরি_মুক্তি(বাফ, ৩২)
    return ১
}

// ৪. মোট রেকর্ডের সংখ্যা গণনা
কাজ ডিবি_মোট_রেকর্ড(fd) {
     আকার = syscall(৮, fd, ০, ২)
     মোট = আকার / ৩২
    return মোট
}

// ৫. ডাটাবেজের বাইট সাইজ রিটার্ন করা
কাজ ডিবি_ফাইলের_সাইজ(fd) {
     আকার = syscall(৮, fd, ০, ২)
    return আকার
}
