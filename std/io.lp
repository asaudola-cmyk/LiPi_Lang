// 📜 লিপি স্ট্যান্ডার্ড ইনপুট/আউটপুট লাইব্রেরি (Pure Lipi Standard I/O Library)
// 🏛️ সরাসরি লিনাক্স কার্নেল সিসকল রুটিন (POSIX / Linux AMD64 Kernel ABI)
// ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — সরাসরি কার্নেলে রিকোয়েস্ট প্রেরণ

// ১. কনসোল আউটপুট (Direct stdout write via SYS_write: syscall 1)
কাজ কনসোল_লেখো(বার্তা, দৈর্ঘ্য) {
    ধরি লিখিত = সিসকল(১, ১, বার্তা, দৈর্ঘ্য)
    ফেরত লিখিত
}

// ২. ফাইল তৈরি বা ট্রাঙ্কেট করা (Direct create/truncate via SYS_open: syscall 2)
// O_WRONLY | O_CREAT | O_TRUNC = 0101o = 65, Mode 0644o = 420
কাজ ফাইল_তৈরি(পথ) {
    ধরি fd = সিসকল(২, পথ, ৬৫, ৪২০)
    ফেরত fd
}

// ৩. ফাইল পড়ার জন্য খোলা (Direct open read-only via SYS_open: syscall 2)
// O_RDONLY = 0, Mode = 0
কাজ ফাইল_খোলো(পথ) {
    ধরি fd = সিসকল(২, পথ, ০, ০)
    ফেরত fd
}

// ৪. ফাইল সংযোজন বা অ্যাপেন্ড করার জন্য খোলা (Direct append via SYS_open: syscall 2)
// O_WRONLY | O_CREAT | O_APPEND = 02001o = 1089, Mode 0644o = 420
কাজ ফাইল_খোলো_যুক্ত(পথ) {
    ধরি fd = সিসকল(২, পথ, ১০৮৯, ৪২০)
    ফেরত fd
}

// ৫. ফাইলে ডেটা লেখা (Direct write to file descriptor via SYS_write: syscall 1)
কাজ ফাইল_লেখো(fd, ডেটা, দৈর্ঘ্য) {
    ধরি লিখিত = সিসকল(১, fd, ডেটা, দৈর্ঘ্য)
    ফেরত লিখিত
}

// ৬. ফাইল থেকে বাফারে ডেটা পড়া (Direct read from file descriptor via SYS_read: syscall 0)
কাজ ফাইল_পড়ো(fd, বাফার_ঠিকানা, আকার) {
    ধরি পঠিত = সিসকল(০, fd, বাফার_ঠিকানা, আকার)
    ফেরত পঠিত
}

// ৭. ফাইল ক্লোজ বা বন্ধ করা (Direct close file descriptor via SYS_close: syscall 3)
কাজ ফাইল_বন্ধ(fd) {
    ধরি কোড = সিসকল(৩, fd)
    ফেরত কোড
}
