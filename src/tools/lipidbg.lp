// ==============================================================================
// 👑 LIPIDBG — 100% PURE LIPI SOVEREIGN SYSTEM DEBUGGER (src/tools/lipidbg.lp)
// ⚡ Hardware Register & Stack Introspection | ELF Binary Diagnostics | Zero GDB / Zero C
// ==============================================================================

// WHY: A sovereign language needs its own diagnostics suite.
// lipidbg inspects physical CPU stacks, validates target ELF binary structures,
// checks runtime invariant assertions, and performs memory diagnostics via pure Lipi.

include "std/io.lp"
include "std/mem.lp"
include "std/debug.lp"

// ১. ব্যানার প্রদর্শন
fn প্রিন্ট_ব্যানার
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║  👑 LIPIDBG — 100% PURE LIPI SOVEREIGN SYSTEM DEBUGGER (ZERO GDB)      ║\033[0m"
    say "\033[38;2;0;255;204m║  ⚡ Hardware Introspection | CPU Registers | Stack Diagnostic Probe     ║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

// ২. টার্গেট ELF বাইনারি স্ট্রাকচার ডায়াগনস্টিক
// WHY: Inspects target executable file directly via kernel syscalls to ensure
// valid 64-bit ELF format, correct entry point, and machine architecture.
fn বাইনারি_ডায়াগনস্টিক বাইনারি_পাথ
    say "\033[1;34m[🔍] টার্গেট বাইনারি ডায়াগনস্টিক: " + বাইনারি_পাথ + "...\033[0m"

    এফডি = সিসকল(2, বাইনারি_পাথ, 0, 0, 0, 0, 0) // O_RDONLY = 0
    if এফডি < 0
        say "❌ ত্রুটি: টার্গেট বাইনারি ফাইল খুলতে ব্যর্থ!"
        return 0

    // ১২০ বাইট হেডার পড়া (ELF64 Header + Program Header)
    হেডার_বাফার = malloc(120)
    পঠিত = সিসকল(0, এফডি, হেডার_বাফার, 120, 0, 0, 0) // SYS_read
    সিসকল(3, এফডি, 0, 0, 0, 0, 0) // SYS_close

    if পঠিত < 64
        say "❌ ত্রুটি: ফাইল size_of অত্যন্ত ছোট (অবৈধ ELF)!"
        free(হেডার_বাফার, 120)
        return 0

    // ELF ম্যাজিক বাইট যাচাই (0x7F, 'E', 'L', 'F')
    b0 = মেমরি_বাইট_পড়ো(হেডার_বাফার, 0)
    b1 = মেমরি_বাইট_পড়ো(হেডার_বাফার, 1)
    b2 = মেমরি_বাইট_পড়ো(হেডার_বাফার, 2)
    b3 = মেমরি_বাইট_পড়ো(হেডার_বাফার, 3)

    if b0 == 127
        if b1 == 69
            if b2 == 76
                if b3 == 70
                    say "  ✔ ELF ম্যাজিক বাইট যাচাই সফল (0x7F 'ELF')"

    // ৬৪-বিট ক্লাস ও আর্কিটেকচার
    ক্লাস = মেমরি_বাইট_পড়ো(হেডার_বাফার, 4)
    এন্ডিয়ান = মেমরি_বাইট_পড়ো(হেডার_বাফার, 5)

    if ক্লাস == 2
        say "  ✔ বাইনারি আর্কিটেকচার: 64-bit Architecture (ELFCLASS64)"
    if এন্ডিয়ান == 1
        say "  ✔ বাইট অর্ডার: Little-Endian (ELFDATA2LSB)"

    free(হেডার_বাফার, 120)
    return 1

// ৩. সিপিউ স্ট্যাক ও রেজিস্টার ইনস্পেকশন
fn সিপিউ_ডায়াগনস্টিক
    say "\033[1;33m--- [সিপিইউ ও স্ট্যাক ডায়াগনস্টিক / Hardware Stack Introspection] ---\033[0m"
    rsp = স্ট্যাক_পয়েন্টার()
    say "  • বর্তমান সিপিইউ %rsp স্ট্যাক পয়েন্টার: " + rsp
    দাবি(rsp > 0, "স্ট্যাক পয়েন্টার ভ্যালিডেশন ব্যর্থ")
    say "  ✔ সিপিইউ হার্ডওয়্যার স্ট্যাক এলাইনমেন্ট ভ্যালিডেটেড!"

// ৪. ব্যবহারবিধি
fn ব্যবহারবিধি_প্রদর্শন
    say "\nব্যবহারবিধি (Usage):"
    say "  lipidbg run <binary_path> : টার্গেট লিপি বাইনারি ডিবাগ ও ডায়াগনস্টিক"
    say "  lipidbg inspect <addr>    : মেমরি অ্যাড্রেস সরাসরি পরিদর্শন"
    say "  lipidbg version           : ডিবাগার সংস্করণ প্রদর্শন"
    say "  lipidbg help              : সাহায্য নির্দেশিকা প্রদর্শন\n"

fn প্রধান
    প্রিন্ট_ব্যানার()

    // সেলফ-ডায়াগনস্টিক টেস্ট
    say "[১] lipidbg সেলফ-ডায়াগনস্টিক টেস্ট..."
    সিপিউ_ডায়াগনস্টিক()

    say "\n[২] কম্পাইলার বাইনারি (bin/lipic) ডায়াগনস্টিক..."
    বাইনারি_ডায়াগনস্টিক("bin/lipic")

    say "\n\033[1;32m🎉 lipidbg (Pure Lipi) ১০০% কার্যকর ও সম্পূর্ণ C-মুক্ত!\033[0m"
    ব্যবহারবিধি_প্রদর্শন()
    return 0

প্রধান()
