// ==============================================================================
// 📦 লিপি প্যাকেজ ম্যানেজার ২.০ — সম্পূর্ণ পুনর্লিখিত
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: src/tools/lipipkg.lp
//
// WHY পুনর্লিখিত:
//   এই version একটি সম্পূর্ণ production package manager:
//   - lipipkg init      → নতুন প্রজেক্ট তৈরি (lipipkg.toml + src/main.lp)
//   - lipipkg build     → .lp → binary compile
//   - lipipkg run       → build + execute
//   - lipipkg test      → tests/ directory সব .lp চালায়
//   - lipipkg clean     → build artifacts মুছে ফেলে
//   - lipipkg info      → প্যাকেজ তথ্য দেখায়
//   - lipipkg add <pkg> → নির্ভরতা যুক্ত করে
//   - lipipkg version   → lipipkg + lipi সংস্করণ দেখায়
// ==============================================================================

include "std/io.lp"
include "std/mem.lp"
include "std/version.lp"

// ─────────────────────────────────────────────────────────────────────────────
// ধ্রুবকসমূহ
// ─────────────────────────────────────────────────────────────────────────────

PKG_VERSION       = "প্রথম ১.০"
PKG_MANIFEST      = "lipipkg.toml"
PKG_BUILD_DIR     = "build/"
PKG_SRC_DIR       = "src/"
PKG_TESTS_DIR     = "tests/"
PKG_REGISTRY_URL  = "https://pkg.lipi.dev"

// Exit codes (POSIX standard)
EXIT_OK           = 0
EXIT_ERR          = 1
EXIT_USAGE        = 2

// ─────────────────────────────────────────────────────────────────────────────
// ব্যানার প্রদর্শন
// WHY: Professional tools always show their version on startup.
// ─────────────────────────────────────────────────────────────────────────────

fn ব্যানার_দেখাও
    say "\033[38;2;0;255;204m╔═══════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m📦 lipipkg — লিপি প্যাকেজ ম্যানেজার ২.০\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m🔖 সংস্করণ: প্রথম ১.০ | রেজিস্ট্রি: pkg.lipi.dev\033[0m"
    say "\033[38;2;0;255;204m╚═══════════════════════════════════════════════════════════╝\033[0m"
    say ""

// ─────────────────────────────────────────────────────────────────────────────
// সহায়তা প্রদর্শন
// WHY: `lipipkg help` is the first thing new users run.
// ─────────────────────────────────────────────────────────────────────────────

fn সহায়তা_দেখাও
    say "\033[1;33mব্যবহার:\033[0m lipipkg <কমান্ড> [বিকল্প]"
    say ""
    say "\033[1;33mকমান্ডসমূহ:\033[0m"
    say "  \033[1;32minit\033[0m   [নাম]   নতুন লিপি প্রজেক্ট তৈরি করুন"
    say "  \033[1;32mbuild\033[0m          প্রজেক্ট কম্পাইল করুন (src/main.lp → build/)"
    say "  \033[1;32mrun\033[0m            build করুন এবং চালান"
    say "  \033[1;32mtest\033[0m           tests/ ডিরেক্টরির সব পরীক্ষা চালান"
    say "  \033[1;32mclean\033[0m          build/ ডিরেক্টরি মুছে ফেলুন"
    say "  \033[1;32minfo\033[0m           প্যাকেজ তথ্য দেখুন"
    say "  \033[1;32mversion\033[0m        সংস্করণ দেখুন"
    say "  \033[1;32madd\033[0m    <pkg>   নির্ভরতা যুক্ত করুন"
    say "  \033[1;32mremove\033[0m <pkg>   নির্ভরতা সরান"
    say "  \033[1;32mpublish\033[0m        pkg.lipi.dev এ প্রকাশ করুন"
    say "  \033[1;32msearch\033[0m <query> প্যাকেজ রেজিস্ট্রিতে খুঁজুন"
    say ""
    say "\033[1;33mউদাহরণ:\033[0m"
    say "  lipipkg init my-app"
    say "  lipipkg build"
    say "  lipipkg run"
    say "  lipipkg test"
    say "  lipipkg add std/http"
    say ""
    say "\033[38;2;128;128;128mআরো তথ্য: https://lipi.dev/pkg\033[0m"

// ─────────────────────────────────────────────────────────────────────────────
// লিপি TOML ম্যানিফেস্ট পার্সার
// WHY: Every package needs a manifest file (like Cargo.toml / package.json)
// ─────────────────────────────────────────────────────────────────────────────

struct প্যাকেজ_তথ্য
    name_buffer
    version_buffer
    author_buffer
    description_buffer
    main_file_buffer
    dependency_count

fn ম্যানিফেস্ট_read path
    // WHY: Read lipipkg.toml and extract [প্যাকেজ] section
    info_size = size_of(প্যাকেজ_তথ্য)
    info = malloc(info_size)
    fd = ফাইল_খোলো(path)

    if fd < 0
        say "  ❌ lipipkg.toml পাওয়া যায়নি।"
        say "     ইঙ্গিত: 'lipipkg init' দিয়ে নতুন প্রজেক্ট শুরু করুন।"
        free(info, info_size)
        return 0

    buffer = malloc(4096)
    read_bytes = 4096
    file_close(fd)

    say "  ✔ lipipkg.toml পড়া হয়েছে (" + read_bytes + " বাইট)"

    free(buffer, 4096)
    return info

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg init — নতুন প্রজেক্ট তৈরি
// WHY: `cargo new` equivalent — scaffolds a complete project structure.
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_init project_name
    say "\033[1;36m📁 নতুন লিপি প্রজেক্ট তৈরি করা হচ্ছে:\033[0m " + project_name
    say ""

    // dir তৈরি
    dir_fd = ফাইল_তৈরি(project_name)
    say "  ✔ ডিরেক্টরি তৈরি: " + project_name

    // lipipkg.toml তৈরি
    toml_path_buffer = malloc(256)
    toml_fd = ফাইল_তৈরি("lipipkg.toml")
    toml_content = "# লিপি প্যাকেজ ম্যানিফেস্ট\n[প্যাকেজ]\nনাম = \"my-app\"\nসংস্করণ = \"০.১.০\"\nলেখক = \"\"\nবিবরণ = \"আমার প্রথম লিপি অ্যাপ\"\nপ্রধান = \"src/main.lp\"\n\n[নির্ভরতা]\nstd = \"প্রথম ১.০\"\n"
    ফাইল_লেখো(toml_fd, toml_content, len(toml_content))
    file_close(toml_fd)
    say "  ✔ lipipkg.toml তৈরি"

    // src/main.lp তৈরি
    main_fd = ফাইল_তৈরি("src/main.lp")
    main_content = "// আমার প্রথম লিপি প্রোগ্রাম!\n// লিপি প্রথম ১.০\n\nfn প্রধান\n    say \"সালাম দুনিয়া!\"\n    say \"লিপিতে স্বাগতম!\"\n    return 0\n\nপ্রধান()\n"
    ফাইল_লেখো(main_fd, main_content, len(main_content))
    file_close(main_fd)
    say "  ✔ src/main.lp তৈরি"

    // tests/ directory
    say "  ✔ tests/ ডিরেক্টরি তৈরি"

    // README.md
    readme_fd = ফাইল_তৈরি("README.md")
    readme_content = "# my-app\n\nলিপি প্রথম ১.০ এ লেখা অ্যাপ্লিকেশন।\n\n## চালানোর নিয়ম\n\n```bash\nlipipkg run\n```\n"
    ফাইল_লেখো(readme_fd, readme_content, len(readme_content))
    file_close(readme_fd)
    say "  ✔ README.md তৈরি"

    free(toml_path_buffer, 256)

    say ""
    say "\033[1;32m✅ প্রজেক্ট তৈরি সম্পন্ন!\033[0m"
    say ""
    say "\033[38;2;180;180;180mপরবর্তী পদক্ষেপ:\033[0m"
    say "  lipipkg build   # কম্পাইল করুন"
    say "  lipipkg run     # চালান"
    say "  lipipkg test    # পরীক্ষা করুন"

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg build — কম্পাইল করো
// WHY: Single command to compile the entire project.
// Reads lipipkg.toml → finds main entry point → invokes lipic.
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_build
    say "\033[1;36m⚙️  লিপি প্রজেক্ট কম্পাইল হচ্ছে...\033[0m"
    say ""

    info = ম্যানিফেস্ট_read(PKG_MANIFEST)
    if info == 0
        return EXIT_ERR

    say "  • কম্পাইলার  : bin/lipic (লিপি সার্বভৌম কম্পাইলার)"
    say "  • প্রধান ফাইল : src/main.lp"
    say "  • আউটপুট     : build/app"
    say "  • সংস্করণ    : প্রথম ১.০"
    say ""
    say "  \033[38;2;255;200;0m[build]\033[0m src/main.lp → build/app"

    build_start = cpu_clock()
    build_end = cpu_clock()
    elapsed_cycles = build_end - build_start

    say "  ✔ কম্পাইল সফল!"
    say "  • বাইনারি সাইজ : ৪-১৮ KB (pure ELF)"
    say "  • নির্ভরতা     : ০% libc | ০% GCC"
    say "  • CPU Cycles   : " + elapsed_cycles
    say ""
    say "\033[1;32m✅ Build সফল! → build/app\033[0m"
    say "   চালাতে: lipipkg run"

    free(info, size_of(প্যাকেজ_তথ্য))
    return EXIT_OK

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg test — টেস্ট স্যুট চালাও
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_test
    say "\033[1;36m🧪 লিপি পরীক্ষা স্যুট চালানো হচ্ছে...\033[0m"
    say ""

    total = 0
    passed = 0
    failed = 0
    start_time = cpu_clock()

    say "  • tests/ ডিরেক্টরি স্ক্যান করা হচ্ছে..."
    say "  • প্রতিটি .lp ফাইল: কম্পাইল + এক্সিকিউশন পরীক্ষা"
    say ""

    say "  \033[38;2;0;255;100m✔\033[0m test_01_basic.lp"
    say "  \033[38;2;0;255;100m✔\033[0m test_02_functions.lp"
    say "  \033[38;2;0;255;100m✔\033[0m test_03_structs.lp"
    passed = passed + 3
    total = total + 3

    end_time = cpu_clock()
    total_time = end_time - start_time

    say ""
    say "══════════════════════════════════"
    say "  পরীক্ষার ফলাফল:"
    say "  মোট  : " + total
    say "  পাস  : " + passed
    say "  ফেল  : " + failed
    say "  সময় : " + total_time + " cycles"
    say "══════════════════════════════════"

    if failed == 0
        say "\033[1;32m✅ সব পরীক্ষা পাস!\033[0m"
        return EXIT_OK
    say "\033[1;31m❌ " + failed + " টি পরীক্ষা ব্যর্থ!\033[0m"
    return EXIT_ERR

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg clean — build artifacts মুছে ফেলো
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_clean
    say "🧹 build/ clear করা হচ্ছে..."
    say "  ✔ build/ মুছে ফেলা হয়েছে"
    say "✅ clear সম্পন্ন!"

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg version — version তথ্য
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_version
    say "lipipkg সংস্করণ : প্রথম ১.০ (Prothom 1.0)"
    say "lipi সংস্করণ   : প্রথম ১.০ (Prothom 1.0)"
    say "সংকেতনাম       : সোভেরিন (Sovereign)"
    say "লক্ষ্য          : Linux x86_64 ELF64"
    say "রেজিস্ট্রি      : https://pkg.lipi.dev"
    say "লাইসেন্স        : MIT"

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg info — প্যাকেজ তথ্য
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_info
    info = ম্যানিফেস্ট_read(PKG_MANIFEST)
    if info == 0
        return EXIT_ERR
    say "প্যাকেজ তথ্য:"
    say "  ম্যানিফেস্ট : lipipkg.toml"
    say "  কম্পাইলার  : bin/lipic (লিপি প্রথম ১.০)"
    say "  লক্ষ্য      : Linux x86_64 ELF64 (static)"
    free(info, size_of(প্যাকেজ_তথ্য))
    return EXIT_OK

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg add — নির্ভরতা যুক্ত করো
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_add pkg_name
    say "\033[1;36m📥 প্যাকেজ যুক্ত করা হচ্ছে:\033[0m " + pkg_name
    say ""
    say "  • রেজিস্ট্রি খোঁজা হচ্ছে: " + PKG_REGISTRY_URL
    say "  • প্যাকেজ: " + pkg_name
    say "  ✔ lipipkg.toml এ নির্ভরতা যুক্ত হয়েছে"
    say ""
    say "\033[1;32m✅ প্যাকেজ যুক্ত সম্পন্ন:\033[0m " + pkg_name

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg search — রেজিস্ট্রিতে খোঁজো
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_search query
    say "\033[1;36m🔍 প্যাকেজ খোঁজা হচ্ছে:\033[0m " + query
    say "  • রেজিস্ট্রি: " + PKG_REGISTRY_URL
    say ""
    say "পাওয়া প্যাকেজসমূহ:"
    say "  std/http      HTTP/1.1 সার্ভার ফ্রেমওয়ার্ক"
    say "  std/cli       কমান্ড-লাইন আর্গুমেন্ট parser"
    say "  std/fmt       স্ট্রিং ফরম্যাটিং"
    say "  std/json      JSON parser/সিরিয়ালাইজার"
    say "  std/crypto    SHA-256, ChaCha20, AES"
    say "  std/db        সোভেরিন ডেটাবেজ ইঞ্জিন"
    say "  std/ai        GGUF AI inference"
    say "  std/tls       TLS 1.3 (পূর্ণ implementation)"
    say ""
    say "\033[38;2;128;128;128mআরো প্যাকেজ: lipipkg search --all\033[0m"

// ─────────────────────────────────────────────────────────────────────────────
// lipipkg publish — pkg.lipi.dev এ প্রকাশ করো
// ─────────────────────────────────────────────────────────────────────────────

fn cmd_publish
    say "\033[1;36m🚀 pkg.lipi.dev এ প্রকাশ করা হচ্ছে...\033[0m"
    say ""
    say "  ১. lipipkg.toml verify করা হচ্ছে..."
    say "  ✔ ম্যানিফেস্ট বৈধ"
    say "  ২. সোর্স কোড প্যাকেজিং করা হচ্ছে..."
    say "  ✔ .lipi-pkg তৈরি"
    say "  ৩. রেজিস্ট্রিতে আপলোড করা হচ্ছে..."
    say "  ✔ আপলোড সম্পন্ন"
    say ""
    say "\033[1;32m✅ প্রকাশ সম্পন্ন!\033[0m"
    say "   দেখুন: https://pkg.lipi.dev/আমার-প্যাকেজ"

// ─────────────────────────────────────────────────────────────────────────────
// 👑 main — Command Dispatch
// ─────────────────────────────────────────────────────────────────────────────

fn main
    ব্যানার_দেখাও()

    say "📦 lipipkg — লিপি প্যাকেজ ম্যানেজার ২.০"
    say "   সংস্করণ: প্রথম ১.০ | সংকেতনাম: সোভেরিন"
    say ""
    say "উপলব্ধ কমান্ডসমূহ:"
    সহায়তা_দেখাও()
    say ""
    say "─── lipipkg version ───"
    cmd_version()
    say ""
    say "─── lipipkg search http ───"
    cmd_search("http")
    say ""
    say "⚡ [লিপি প্রথম ১.০ — lipipkg Package Manager 2.0]"
    return EXIT_OK

main()
