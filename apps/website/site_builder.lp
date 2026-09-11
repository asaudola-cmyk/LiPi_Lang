// ==============================================================================
// 👑 LIPI WEB ASSET INSPECTOR & BUILD VALIDATOR (apps/website/site_builder.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Linux Kernel AMD64 Syscalls
//
// WHY: Verifies that all official website assets (HTML, CSS, JS, SVG) are
// present on disk and properly sized before server deployment.
// ==============================================================================

অন্তর্ভুক্ত "universe/core/io.lp"
অন্তর্ভুক্ত "universe/core/string.lp"

কাজ ফাইল_আকার_যাচাই(পাথ) {
     fd = ফাইল_খোলো(পাথ)
    if fd < ০ {
        say "  ❌ মিসিং ফাইল: " + পাথ
        return -১
    }
     আকার = syscall(৮, fd, ০, ২) // lseek SEEK_END
    ফাইল_বন্ধ(fd)
    say "  ✔ পাওয়া গেছে: " + পাথ + " (" + আকার + " বাইট)"
    return আকার
}

say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI OFFICIAL WEB ASSET AUDITOR & BUILD VALIDATOR\033[0m                 \033[38;2;0;255;204m║\033[0m"
say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Direct Linux Kernel Syscall Asset Inspection | Zero Dependencies\033[0m   \033[38;2;0;255;204m║\033[0m"
say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
say ""

say "\033[1;33m[১] ওয়েবসাইট অ্যাসেট ভেরিফিকেশন শুরু হচ্ছে...\033[0m"
 s1 = ফাইল_আকার_যাচাই("apps/website/public/index.html")
 s2 = ফাইল_আকার_যাচাই("apps/website/public/style.css")
 s3 = ফাইল_আকার_যাচাই("apps/website/public/app.js")
 s4 = ফাইল_আকার_যাচাই("apps/website/public/favicon.svg")

if s1 > ০ {
    if s2 > ০ {
        if s3 > ০ {
            if s4 > ০ {
                 মোট_সাইজ = s1 + s2 + s3 + s4
                say ""
                say "\033[1;32m✔ সকল ওয়েব অ্যাসেট শতভাগ প্রস্তুত ও ভ্যালিডেটেড!\033[0m"
                say "  • মোট অ্যাসেট আকার: " + মোট_সাইজ + " বাইট"
                say "  • সার্ভার রেডি: apps/website/server.lp দিয়ে তাৎক্ষণিক ডিপ্লয়যোগ্য।"
                return ০
            }
        }
    }
}

say "\033[1;31m❌ সতর্কতা: কিছু অ্যাসেট খুঁজে পাওয়া যায়নি!\033[0m"
return ১
