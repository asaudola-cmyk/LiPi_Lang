// ==============================================================================
// 👑 LIPI HELLO WORLD DEMO PROJECT (examples/01_hello_world/main.lp)
// ⚡ 100% Native Silicon Hardware Execution | Zero External Dependencies
// ==============================================================================

// WHY: Demonstrates the foundational syntax, bilingual greeting, and direct
// hardware timestamp counter (RDTSC) invocation in sovereign Lipi.

include "std/io.lp"

fn প্রধান
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 HELLO WORLD FROM SOVEREIGN LIPI PROGRAMMING LANGUAGE\033[0m              \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Direct Linux ELF 64-bit Machine Code | Zero Libc | Pure Silicon Engine\033[0m\033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

    সাইকেল_শুরু = cpu_clock()

    say "স্বাগতম! লিপি একটি ১০০% স্বাধীন, দেশীয় ও সিলিকন-নেটিভ প্রোগ্রামিং ভাষা।"
    say "Welcome to Lipi! A 100% sovereign, self-hosted, bare-metal language."

    সাইকেল_শেষ = cpu_clock()
    মোট_সাইকেল = সাইকেল_শেষ - সাইকেল_শুরু

    say ""
    say "• হার্ডওয়্যার সিপিউ ক্লক সাইকেল (RDTSC): " + মোট_সাইকেল
    say "• এক্সিকিউশন স্ট্যাটাস: সাফল্যজনক (Exit 0)"

    return 0

প্রধান()
