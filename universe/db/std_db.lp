// 📜 লিপি খাঁটি এমবেডেড পারসিস্টেন্ট ডাটাবেস ইঞ্জিন (Pure Lipi Embedded DB Engine)
// 🏛️ সরাসরি লিনাক্স কার্নেল ফাইল সিসকল ও বাইনারি রেকর্ড পারসিস্টেন্স (Linux AMD64 Kernel ABI)
// ০% SQLite, ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — সরাসরি SYS_open, SYS_write, SYS_read, SYS_lseek, SYS_fsync
//
// WHY: অ্যাপ্লিকেশন ডাটা স্থায়ীভাবে হার্ড ড্রাইভ/NVMe সিলিকনে সংরক্ষণের জন্য একটি হালকা,
// অতি-দ্রুত এবং নির্ভরযোগ্য এমবেডেড কি-ভ্যালু স্টোরেজ ইঞ্জিন।
// রেকর্ড ফরম্যাট: প্রতিটি রেকর্ড ঠিক ১৬ বাইট (৮ বাইট কি + ৮ বাইট ভ্যালু)।

include "universe/core/std_mem.lp"

// ১. ডাটাবেস ফাইল খোলা বা তৈরি করা (Open/Create DB via SYS_open: syscall 2)
// WHY: O_RDWR (2) | O_CREAT (64) = 66, মোড 0644 (420 decimal)
fn database_open path
    flag = 66
    mode = 420
    fd = syscall(2, path, flag, mode, 0, 0, 0)
    return fd

// ২. ডাটাবেসে কি-ভ্যালু রেকর্ড সংরক্ষণ (Append Record via SYS_lseek: 8 & SYS_write: 1)
// WHY: ফাইলের শেষে পয়েন্টার নিয়ে গিয়ে ১৬ বাইটের বাইনারি কি-ভ্যালু পেয়ার অ্যাপেন্ড করা।
fn database_put fd key value
    // SEEK_END (2) দিয়ে ফাইলের শেষ প্রান্তে যাওয়া
    syscall(8, fd, 0, 2, 0, 0, 0)
    buf = malloc(16)
    mem_write_word(buf, 0, key)
    mem_write_word(buf, 1, value)
    // ১৬ বাইট বাইনারি ডাটা ডিস্কে রাইট করা
    written = syscall(1, fd, buf, 16, 0, 0, 0)
    free(buf, 16)
    return written

// ৩. ডাটাবেস থেকে কি অনুযায়ী ভ্যালু অনুসন্ধান (Lookup Record via SYS_lseek: 8 & SYS_read: 0)
// WHY: ফাইলের শুরু (SEEK_SET = 0) থেকে পর্যায়ক্রমে ১৬ বাইট করে স্ক্যান করে কাঙ্ক্ষিত কি খুঁজে বের করা।
fn database_get fd search_key
    // SEEK_SET (0) দিয়ে ফাইলের শুরুতে যাওয়া
    syscall(8, fd, 0, 0, 0, 0, 0)
    result = -1
    running = 1
    buf = malloc(16)

    while running == 1
        read_bytes = syscall(0, fd, buf, 16, 0, 0, 0)
        if read_bytes < 16
            running = 0
        else
            cur_key = mem_word_read(buf, 0)
            if cur_key == search_key
                result = mem_word_read(buf, 1)
                running = 0
    free(buf, 16)
    return result

fn database_পড়ো fd search_key
    return database_get(fd, search_key)

// ৪. ডিস্ক সিঙ্ক্রোনাইজেশন (Durable Silicon Flush via SYS_fsync: syscall 74)
// WHY: ওএস পেজ ক্যাশে থাকা সমস্ত ডার্টি পেজ সরাসরি হার্ডওয়্যার স্টোরেজে ফ্লাশ করা (Zero Data Loss)।
fn database_sync fd
    result = syscall(74, fd, 0, 0, 0, 0, 0)
    return result

// ৫. ডাটাবেস বন্ধ করা (Close DB via SYS_close: syscall 3)
// WHY: ফাইল ডেসক্রিপ্টর কার্নেলে মুক্ত করা।
fn database_close fd
    result = syscall(3, fd, 0, 0, 0, 0, 0)
    return result
