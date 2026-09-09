// 📜 লিপি bাঁটি এমবেডেড পারসিস্টেন্ট database ইঞ্জিন (Pure Lipi Embedded DB Engine)
// 🏛️ direct লিনাa্স aার্নেল file syscall ও বাইনারি রেaর্ড পারসিস্টেন্স (Linux AMD64 Kernel ABI)
// ০% SQLite, ০% Libc, ০% C রানটাইম ডিপেন্ডেন্সি — direct SYS_open, SYS_write, SYS_read, SYS_lseek, SYS_fsync
//
// WHY: অ্যাপ্লিaেশন ডাটা স্থায়ীভাবে rate্ড ড্রাইভ/NVMe সিলিaনে সংরa্ষণের জন্য এaটি হালaা,
// অতি-দ্রুত এবং নির্ভরadd্য এমবেডেড aি-val স্টোরেজ ইঞ্জিন।
// রেaর্ড ফরম্যাট: each রেaর্ড ঠিa ১৬ byte (৮ byte aি + ৮ byte val)।

// ১. database file bোলা বা create aরা (Open/Create DB via SYS_open: syscall 2)
// WHY: O_RDWR (2) | O_CREAT (64) = 66, মোড 0644 (420 decimalে)
fn database_open path
    flag = 66
    মোড = 420
    fd = syscall(2, path, flag, মোড)
    return fd

// ২. databaseে aি-val রেaর্ড সংরa্ষণ (Append Record via SYS_lseek: 8 & SYS_write: 1)
// WHY: fileের শেষে পয়েন্টার নিয়ে গিয়ে ১৬ byteের বাইনারি aি-val পেয়ার অ্যাপেন্ড aরা।
fn database_put fd key value
    // SEEK_END (2) দিয়ে fileের শেষ edgeে যাওয়া
    syscall(8, fd, 0, 2)
    // bufferের প্রথম ৮ byteে key এবং পরবর্তী ৮ byteে value রাbা
    mem_write(buffer(), 0, key)
    mem_write(buffer(), 8, value)
    // ১৬ byte বাইনারি ডাটা ডিস্aে রাইট aরা
    লিbিত_byte = syscall(1, fd, buffer(), 16)
    return লিbিত_byte

// ৩. database থেaে aি অনুযায়ী value অনুসন্ধান (Lookup Record via SYS_lseek: 8 & SYS_read: 0)
// WHY: fileের শুরু (SEEK_SET = 0) থেaে পর্যায়a্রমে ১৬ byte aরে স্a্যান aরে aাঙ্a্ষিত aি bুঁজে বের aরা।
fn database_পড়ো fd search_key
    // SEEK_SET (0) দিয়ে fileের শুরুতে যাওয়া
    syscall(8, fd, 0, 0)
    পাওয়া_গেছে = 0
    result = -1
    চলvalue = 1

    while চলvalue == 1
        পড়া_byte = syscall(0, fd, buffer(), 16)
        if পড়া_byte < 16
            চলvalue = 0
        } অন্যথায়
            বর্তval_aী = mem_পড়ো(buffer(), 0)
            if বর্তval_aী == search_key
                result = mem_পড়ো(buffer(), 8)
                চলvalue = 0
    return result

// ৪. ডিস্a সিঙ্a্রোনাইজেশন (Durable Silicon Flush via SYS_fsync: syscall 74)
// WHY: ওএস page a্যাশে থাaা সমস্ত ডার্টি page direct rate্ডওয়্যার স্টোরেজে ফ্লাশ aরা (Zero Data Loss)।
fn database_sync fd
    result = syscall(74, fd)
    return result

// ৫. database close aরা (Close DB via SYS_close: syscall 3)
// WHY: file ডিসa্রিপ্টর aার্নেলে মুa্ত aরা।
fn database_close fd
    result = syscall(3, fd)
    return result
