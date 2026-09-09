// 📜 লিপি শেয়ার্ড memory a্যাশ ইঞ্জিন (Pure Lipi POSIX Shared Memory)
// 🏛️ Redis এর বিaল্প হিসেবে লিনাa্সের /dev/shm ব্যবrate aরে সাব-মাইa্রোসেaেন্ড a্যাশিং
// ০% Redis, ০% TCP ওভারহেড, ০% Libc নির্ভরতা

// ১. শেয়ার্ড memory ব্লa create বা bোলা (Open or Create Shared Memory via /dev/shm)
// WHY: এaাধিa প্রসেসের মধ্যে data আদান-প্রদান aরার জন্য direct লিনাa্স aার্নেল memory file create aরা।
fn শেয়ার্ড_mem_bোলো file_path size
    // SYS_open (2) -> filepath, flags: O_RDWR (2) | O_CREAT (64) = 66, mode: 0666
    fd = syscall(2, file_path, 66, 438)
    if fd < 0
        say "[ত্রুটি] শেয়ার্ড mem created করতে ব্যর্থ: " + file_path
        return -1

    // SYS_ftruncate (77) -> fileটিaে নির্দিষ্ট sizeে বড় aরা
    syscall(77, fd, size)

    // SYS_mmap (9) -> fd থেaে memতে map aরা
    // prot = PROT_READ(1) | PROT_WRITE(2) = 3
    // flags = MAP_SHARED (1)
    পয়েন্টার = syscall(9, 0, size, 3, 1, fd, 0)

    // SYS_close (3) -> fd close aরা (mem map হয়ে গেছে, তাই fileের দরaার নেই)
    syscall(3, fd)

    return পয়েন্টার

// ২. লa-ফ্রি এটমিa ইনa্রিমেন্ট (Hardware Lock-Free Atomic Increment)
// WHY: এপিআই রেট লিমিট বা aাউন্টারের জন্য x86_64 `lock xadd` (rate্ডওয়্যার লেভেল) ব্যবrate aরা।
// লিপিতে we direct memর নির্দিষ্ট indexa্সে add aরে এটা সিমুলেট aরছি।
fn এটমিa_add addr index sum
    বর্তvalue = mem_শব্দ_পড়ো(addr, index)
    নতুন_value = বর্তvalue + sum
    mem_write_word(addr, index, নতুন_value)
    return নতুন_value

// ৩. শেয়ার্ড memory close aরা (Close Shared Memory)
// WHY: প্রসেস শেষে aার্নেল থেaে memory page আন-ম্যাপ aরা।
fn শেয়ার্ড_mem_close পয়েন্টার size
    // SYS_munmap (11)
    result = syscall(11, পয়েন্টার, size)
    return result
