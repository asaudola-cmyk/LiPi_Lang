// 📜 লিপি স্ট্যান্ডার্ড ইনপুট/আউটপুট লাইব্রেরি (Pure Lipi Standard I/O Library)
// 🏛️ সরাসরি লিনাক্স কার্নেল সিসকল রুটিন (POSIX / Linux AMD64 Kernel ABI)
// ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — সরাসরি কার্নেলে রিকোয়েস্ট প্রেরণ

// ১. কনসোল আউটপুট (Direct stdout write via SYS_write: syscall 1)
fn কনসোল_লেখো বার্তা len
    লিখিত = সিসকল(1, 1, বার্তা, len)
    return লিখিত

// ২. ফাইল তৈরি বা ট্রাঙ্কেট করা (Direct create/truncate via SYS_open: syscall 2)
// O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577, Mode 0644o = 420
fn ফাইল_তৈরি পথ
    fd = সিসকল(2, পথ, 577, 420)
    return fd

// ৩. ফাইল পড়ার জন্য খোলা (Direct open read-only via SYS_open: syscall 2)
// O_RDONLY = 0, Mode = 0
fn ফাইল_খোলো পথ
    fd = সিসকল(2, পথ, 0, 0)
    return fd

// ৪. ফাইল সংযোজন বা অ্যাপেন্ড করার জন্য খোলা (Direct append via SYS_open: syscall 2)
// O_WRONLY | O_CREAT | O_APPEND = 02001o = 1089, Mode 0644o = 420
fn ফাইল_খোলো_যুক্ত পথ
    fd = সিসকল(2, পথ, 1089, 420)
    return fd

// ৫. ফাইলে ডেটা লেখা (Direct write to file descriptor via SYS_write: syscall 1)
fn ফাইল_লেখো fd ডেটা len
    লিখিত = সিসকল(1, fd, ডেটা, len)
    return লিখিত

// ৬. ফাইল থেকে বাফারে ডেটা পড়া (Direct read from file descriptor via SYS_read: syscall 0)
fn ফাইল_পড়ো fd বাফার_ঠিকানা আকার
    পঠিত = সিসকল(0, fd, বাফার_ঠিকানা, আকার)
    return পঠিত

// ৭. ফাইল ক্লোজ বা বন্ধ করা (Direct close file descriptor via SYS_close: syscall 3)
fn ফাইল_বন্ধ fd
    কোড = সিসকল(3, fd)
    return কোড
