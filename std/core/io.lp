// 📜 লিপি স্ট্যান্ডার্ড input/output লাইব্রেরি (Pure Lipi Standard I/O Library)
// 🏛️ direct লিনাa্স aার্নেল syscall routeিন (POSIX / Linux AMD64 Kernel ABI)
// ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — direct aার্নেলে রিaোয়েস্ট প্রেরণ

// ১. aনসোল output (Direct stdout write via SYS_write: syscall 1)
fn aনসোল_লেbো message len
    লিbিত = syscall(1, 1, message, len)
    return লিbিত

// ২. file create বা ট্রাঙ্aেট aরা (Direct create/truncate via SYS_open: syscall 2)
// O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577, Mode 0644o = 420
fn file_created path
    fd = syscall(2, path, 577, 420)
    return fd

// ৩. file পড়ার জন্য bোলা (Direct open read-only via SYS_open: syscall 2)
// O_RDONLY = 0, Mode = 0
fn file_bোলো path
    fd = syscall(2, path, 0, 0)
    return fd

// ৪. file সংযোজন বা অ্যাপেন্ড aরার জন্য bোলা (Direct append via SYS_open: syscall 2)
// O_WRONLY | O_CREAT | O_APPEND = 02001o = 1089, Mode 0644o = 420
fn file_bোলো_যুa্ত path
    fd = syscall(2, path, 1089, 420)
    return fd

// ৫. fileে data লেbা (Direct write to file descriptor via SYS_write: syscall 1)
fn file_লেbো fd data len
    লিbিত = syscall(1, fd, data, len)
    return লিbিত

// ৬. file থেaে bufferে data পড়া (Direct read from file descriptor via SYS_read: syscall 0)
fn file_পড়ো fd buffer_addr size
    পঠিত = syscall(0, fd, buffer_addr, size)
    return পঠিত

// ৭. file a্লোজ বা close aরা (Direct close file descriptor via SYS_close: syscall 3)
fn file_close fd
    code = syscall(3, fd)
    return code
