// ==============================================================================
// 👑 LIPI HELLO WORLD DEMO PROJECT (examples/01_hello_world/main.lp)
// ⚡ 100% Native Silicon Hardware Execution | Zero External Dependencies
// ==============================================================================

// WHY: Demonstrates the foundational syntax, bilingual greeting, and direct
// hardware timestamp counter (RDTSC) invocation in sovereign Lipi.

অন্তর্ভুক্ত "std/io.lp"

কাজ প্রধান() {
    দেখাও "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    দেখাও "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 HELLO WORLD FROM SOVEREIGN LIPI PROGRAMMING LANGUAGE\033[0m              \033[38;2;0;255;204m║\033[0m"
    দেখাও "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Direct Linux ELF 64-bit Machine Code | Zero Libc | Pure Silicon Engine\033[0m\033[38;2;0;255;204m║\033[0m"
    দেখাও "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    দেখাও ""

    ধরি সাইকেল_শুরু = সিপিউ_ক্লক()
    
    দেখাও "স্বাগতম! লিপি একটি ১০০% স্বাধীন, দেশীয় ও সিলিকন-নেটিভ প্রোগ্রামিং ভাষা।"
    দেখাও "Welcome to Lipi! A 100% sovereign, self-hosted, bare-metal language."
    
    ধরি সাইকেল_শেষ = সিপিউ_ক্লক()
    ধরি মোট_সাইকেল = সাইকেল_শেষ - সাইকেল_শুরু
    
    দেখাও ""
    দেখাও "• হার্ডওয়্যার সিপিউ ক্লক সাইকেল (RDTSC): " + মোট_সাইকেল
    দেখাও "• এক্সিকিউশন স্ট্যাটাস: সাফল্যজনক (Exit 0)"
    
    ফেরত ০
}

প্রধান()
