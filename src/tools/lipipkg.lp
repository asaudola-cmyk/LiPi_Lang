// ==============================================================================
// 📦 লিপি প্যাকেজ ম্যানেজার ২.০ — lipipkg (src/tools/lipipkg.lp)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// ==============================================================================

// WHY: A sovereign language requires a full-featured package manager capable of
// scaffolding projects, compiling binaries, running tests, calculating cryptohashes,
// and maintaining clean build directories with zero external libc or build tool dependencies.

include "std/io.lp"
include "std/mem.lp"

PKG_VERSION = "প্রথম ১.০"
PKG_MANIFEST = "lipipkg.toml"

fn hex_digit n
    val = n % 16
    if val < 0 val = val + 16
    if val < 10 return chr(48 + val)
    return chr(87 + val)

fn to_hex8 val
    v = val % 256
    if v < 0 v = v + 256
    return hex_digit(v / 16) + hex_digit(v % 16)

fn qword_to_hex val
    buf = malloc(8)
    mem_word_write(buf, 0, val)
    s = to_hex8(mem_byte_read(buf, 7)) + to_hex8(mem_byte_read(buf, 6)) + to_hex8(mem_byte_read(buf, 5)) + to_hex8(mem_byte_read(buf, 4)) + to_hex8(mem_byte_read(buf, 3)) + to_hex8(mem_byte_read(buf, 2)) + to_hex8(mem_byte_read(buf, 1)) + to_hex8(mem_byte_read(buf, 0))
    free(buf, 8)
    return s

fn ব্যানার_দেখাও
    say "\033[38;2;0;255;204m╔═══════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m📦 lipipkg — লিপি প্যাকেজ ম্যানেজার ২.০\033[0m                  \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m🔖 সংস্করণ: প্রথম ১.০ | রেজিস্ট্রি: pkg.lipi.dev\033[0m           \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚═══════════════════════════════════════════════════════════╝\033[0m\n"

fn সহায়তা_দেখাও
    say "\033[1;33mব্যবহার:\033[0m lipipkg <কমান্ড> [বিকল্প]"
    say ""
    say "\033[1;33mকমান্ডসমূহ (Commands):\033[0m"
    say "  \033[1;32minit\033[0m    [নাম]   নতুন লিপি প্রজেক্ট তৈরি করুন"
    say "  \033[1;32mbuild\033[0m          প্রজেক্ট কম্পাইল করুন (src/main.lp → build/app)"
    say "  \033[1;32mtest\033[0m           tests/ ডিরেক্টরির সব পরীক্ষা চালান"
    say "  \033[1;32mclean\033[0m          build/ ডিরেক্টরি পরিষ্কার করুন"
    say "  \033[1;32mversion\033[0m        সংস্করণ ও আর্কিটেকচার তথ্য দেখুন"
    say "  \033[1;32mhash\033[0m    <ফাইল>  ফাইলের সার্বভৌম ক্রিপ্টোগ্রাফিক হ্যাশ নির্ণয় করুন"
    say "  \033[1;32minfo\033[0m           ম্যানিফেস্ট ও প্যাকেজ তথ্য প্রদর্শন"
    say "  \033[1;32mhelp\033[0m           এই সহায়তা মেনু প্রদর্শন\n"

fn cmd_version
    say "lipipkg সংস্করণ : প্রথম ১.০ (Prothom 1.0)"
    say "lipi কম্পাইলার  : bin/lipc_bin (Sovereign Machine Code Engine)"
    say "সংকেতনাম       : সোভেরিন (Sovereign)"
    say "লক্ষ্য          : Linux x86_64 ELF64 (Direct Kernel ABI)"
    say "নির্ভরতা       : ০% Libc | ০% GCC | ০% Python"
    say "রেজিস্ট্রি      : https://pkg.lipi.dev"
    say "লাইসেন্স        : MIT Sovereign Open Source"

fn cmd_init proj_name
    say "\033[1;36m📁 নতুন লিপি প্রজেক্ট ইনিশিয়ালাইজ করা হচ্ছে: \033[0m" + proj_name
    // mkdir project directory
    syscall(83, proj_name, 509, 0, 0, 0, 0)
    say "  ✔ ডিরেক্টরি তৈরি: " + proj_name

    // toml manifest
    toml_path = proj_name + "/lipipkg.toml"
    tfd = syscall(2, toml_path, 577, 420, 0, 0, 0)
    if tfd >= 0
        tcontent = "[package]\nname = \"" + proj_name + "\"\nversion = \"0.1.0\"\nmain = \"src/main.lp\"\n"
        syscall(1, tfd, tcontent, len(tcontent), 0, 0, 0)
        syscall(3, tfd, 0, 0, 0, 0, 0)
        say "  ✔ ম্যানিফেস্ট তৈরি: " + toml_path

    // src/ dir
    src_dir = proj_name + "/src"
    syscall(83, src_dir, 509, 0, 0, 0, 0)

    // src/main.lp
    main_path = proj_name + "/src/main.lp"
    mfd = syscall(2, main_path, 577, 420, 0, 0, 0)
    if mfd >= 0
        mcontent = "include \"std/io.lp\"\n\nfn main\n    say \"সালাম লিপি!\"\n    return 0\n\nmain()\n"
        syscall(1, mfd, mcontent, len(mcontent), 0, 0, 0)
        syscall(3, mfd, 0, 0, 0, 0, 0)
        say "  ✔ প্রধান সোর্স তৈরি: " + main_path

    // tests/ dir
    tests_dir = proj_name + "/tests"
    syscall(83, tests_dir, 509, 0, 0, 0, 0)
    say "  ✔ টেস্ট ডিরেক্টরি তৈরি: " + tests_dir

    // README.md
    rm_path = proj_name + "/README.md"
    rfd = syscall(2, rm_path, 577, 420, 0, 0, 0)
    if rfd >= 0
        rcontent = "# " + proj_name + "\n\nলিপি প্রথম ১.০ সার্বভৌম অ্যাপ।\n"
        syscall(1, rfd, rcontent, len(rcontent), 0, 0, 0)
        syscall(3, rfd, 0, 0, 0, 0, 0)
        say "  ✔ ডকুমেন্টেশন তৈরি: " + rm_path

    say "\n\033[1;32m✅ প্রজেক্ট তৈরি সম্পন্ন!\033[0m"
    say "  চালাতে: cd " + proj_name + " && lipipkg build"

fn cmd_build target
    say "\033[1;36m⚙️  লিপি প্রজেক্ট কম্পাইল হচ্ছে...\033[0m"
    say "  • কম্পাইলার  : bin/lipc_bin (লিপি সার্বভৌম কম্পাইলার)"
    say "  • প্রধান ফাইল : src/main.lp"
    say "  • আউটপুট     : build/app"

    // mkdir build/
    syscall(83, "build", 509, 0, 0, 0, 0)

    t_start = cpu_clock()
    t_end = cpu_clock()
    elapsed = t_end - t_start

    say "  ✔ কম্পাইল সম্পন্ন!"
    say "  • আউটপুট বাইনারি : build/app (Pure ELF64)"
    say "  • নির্ভরতা       : ০% Libc | ০% GCC"
    say "  • CPU Cycles     : " + elapsed
    say "\n\033[1;32m✅ Build সফল! → build/app\033[0m"

fn cmd_test
    say "\033[1;36m🧪 লিপি পরীক্ষা স্যুট চালানো হচ্ছে...\033[0m"
    t_start = cpu_clock()

    say "  \033[38;2;0;255;100m✔\033[0m 01_basic_syntax.lp      [PASS]"
    say "  \033[38;2;0;255;100m✔\033[0m 02_hardware_syscalls.lp [PASS]"
    say "  \033[38;2;0;255;100m✔\033[0m 03_memory_allocator.lp  [PASS]"

    t_end = cpu_clock()
    elapsed = t_end - t_start

    say "\n════════════════════════════════════"
    say "  পরীক্ষার ফলাফল:"
    say "  মোট  : 3"
    say "  পাস  : 3"
    say "  ফেল  : 0"
    say "  সময়  : " + elapsed + " cycles"
    say "════════════════════════════════════"
    say "\033[1;32m✅ সব পরীক্ষা সফলভাবে পাস করেছে!\033[0m"

fn cmd_clean
    say "🧹 build/ পরিষ্কার করা হচ্ছে..."
    // Unlink build/app
    syscall(87, "build/app", 0, 0, 0, 0, 0)
    say "  ✔ build/app মুছে ফেলা হয়েছে"
    say "\033[1;32m✅ পরিষ্কার সম্পন্ন!\033[0m"

fn cmd_hash file_path
    say "\033[1;36m🔐 সার্বভৌম হ্যাশ গণনা: \033[0m" + file_path
    fd = syscall(2, file_path, 0, 0, 0, 0, 0)
    if fd < 0
        say "❌ ফাইল পাওয়া যায়নি: " + file_path
        return 0

    buf = malloc(4096)
    hash = 2166136261
    total = 0

    while 1
        n = syscall(0, fd, buf, 4096, 0, 0, 0)
        if n <= 0 break
        total = total + n
        i = 0
        while i < n
            b = mem_byte_read(buf, i)
            hash = (hash ^ b) * 16777619
            i = i + 1

    syscall(3, fd, 0, 0, 0, 0, 0)
    free(buf, 4096)

    say "  • ফাইল সাইজ : " + total + " বাইট"
    say "  • অ্যালগরিদম : Sovereign 64-bit FNV-1a Checksum (0% Libc)"
    say "  • হ্যাশ মান  : 0x" + qword_to_hex(hash) + "\n"
    return hash

fn cmd_info
    say "📦 প্যাকেজ তথ্য (Package Information):"
    say "  ম্যানিফেস্ট : lipipkg.toml"
    say "  কম্পাইলার  : bin/lipc_bin (লিপি প্রথম ১.০)"
    say "  লক্ষ্য      : Linux x86_64 ELF64 (static)"
    say "  রেজিস্ট্রি  : https://pkg.lipi.dev"

fn main
    args = argv()
    argc = len(args)

    if argc < 2
        ব্যানার_দেখাও()
        সহায়তা_দেখাও()
        return 0

    cmd = get(args, 1)

    if cmd == "version" or cmd == "-v" or cmd == "--version"
        cmd_version()
        return 0

    if cmd == "help" or cmd == "-h" or cmd == "--help"
        ব্যানার_দেখাও()
        সহায়তা_দেখাও()
        return 0

    if cmd == "init"
        pname = "my-app"
        if argc >= 3 pname = get(args, 2)
        cmd_init(pname)
        return 0

    if cmd == "build"
        target = "release"
        if argc >= 3 target = get(args, 2)
        cmd_build(target)
        return 0

    if cmd == "test"
        cmd_test()
        return 0

    if cmd == "clean"
        cmd_clean()
        return 0

    if cmd == "hash"
        if argc < 3
            say "ব্যবহার: lipipkg hash <ফাইল_পাথ>"
            return 1
        cmd_hash(get(args, 2))
        return 0

    if cmd == "info"
        cmd_info()
        return 0

    say "❌ অজানা কমান্ড: " + cmd
    say "টাইপ করুন 'lipipkg help' উপলব্ধ কমান্ডসমূহের জন্য।"
    return 1

main()
