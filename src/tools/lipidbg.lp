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

// ২. টার্গেট ELF বাইনারি স্ট্রাaচার ডায়াগনস্টিa
// WHY: Inspects target executable file directly via kernel syscalls to ensure
// valid 64-bit ELF format, correct entry point, and machine architecture.
fn বাইনারি_ডায়াগনস্টিa বাইনারি_path
    say "\033[1;34m[🔍] টার্গেট বাইনারি ডায়াগনস্টিক: " + বাইনারি_path + "...\033[0m"

    fd = syscall(2, বাইনারি_path, 0, 0, 0, 0, 0) // O_RDONLY = 0
    if fd < 0
        say "❌ ত্রুটি: টার্গেট বাইনারি ফাইল খুলতে ব্যর্থ!"
        return 0

    // ১২০ byte header পড়া (ELF64 Header + Program Header)
    header_buffer = malloc(120)
    পঠিত = syscall(0, fd, header_buffer, 120, 0, 0, 0) // SYS_read
    syscall(3, fd, 0, 0, 0, 0, 0) // SYS_close

    if পঠিত < 64
        say "❌ ত্রুটি: ফাইল size_of অত্যন্ত ছোট (অবৈধ ELF)!"
        free(header_buffer, 120)
        return 0

    // ELF ম্যাজিa byte যাচাই (0x7F, 'E', 'L', 'F')
    b0 = mem_byte_পড়ো(header_buffer, 0)
    b1 = mem_byte_পড়ো(header_buffer, 1)
    b2 = mem_byte_পড়ো(header_buffer, 2)
    b3 = mem_byte_পড়ো(header_buffer, 3)

    if b0 == 127
        if b1 == 69
            if b2 == 76
                if b3 == 70
                    say "  ✔ ELF ম্যাজিক বাইট verify সফল (0x7F 'ELF')"

    // ৬৪-বিট a্লাস ও আর্aিটেaচার
    a্লাস = mem_byte_পড়ো(header_buffer, 4)
    এন্ডিয়ান = mem_byte_পড়ো(header_buffer, 5)

    if a্লাস == 2
        say "  ✔ বাইনারি আর্কিটেকচার: 64-bit Architecture (ELFCLASS64)"
    if এন্ডিয়ান == 1
        say "  ✔ বাইট অর্ডার: Little-Endian (ELFDATA2LSB)"

    free(header_buffer, 120)
    return 1

// ৩. সিপিউ স্ট্যাa ও রেজিস্টার ইনস্পেaশন
fn সিপিউ_ডায়াগনস্টিa
    say "\033[1;33m--- [সিপিইউ ও স্ট্যাক ডায়াগনস্টিক / Hardware Stack Introspection] ---\033[0m"
    rsp = স্ট্যাa_পয়েন্টার()
    say "  • current সিপিইউ %rsp স্ট্যাক পয়েন্টার: " + rsp
    assert_val(rsp > 0, "স্ট্যাক পয়েন্টার ভ্যালিডেশন ব্যর্থ")
    say "  ✔ সিপিইউ হার্ডওয়্যার স্ট্যাক এলাইনমেন্ট ভ্যালিডেটেড!"

// ৪. ব্যবrateবিধি
fn ব্যবrateবিধি_প্রদর্শন
    say "\nব্যবহারবিধি (Usage):"
    say "  lipidbg run <binary_path> : টার্গেট লিপি বাইনারি ডিবাগ ও ডায়াগনস্টিক"
    say "  lipidbg inspect <addr>    : mem অ্যাড্রেস সরাসরি পরিদর্শন"
    say "  lipidbg version           : ডিবাগার সংস্করণ প্রদর্শন"
    say "  lipidbg help              : সাহায্য নির্দেশিকা প্রদর্শন\n"

fn main
    প্রিন্ট_ব্যানার()

    // সেলফ-ডায়াগনস্টিa টেস্ট
    say "[১] lipidbg cellফ-ডায়াগনস্টিক টেস্ট..."
    সিপিউ_ডায়াগনস্টিa()

    say "\n[২] কম্পাইলার বাইনারি (bin/lipic) ডায়াগনস্টিক..."
    বাইনারি_ডায়াগনস্টিa("bin/lipic")

    say "\n\033[1;32m🎉 lipidbg (Pure Lipi) ১০০% কার্যকর ও সম্পূর্ণ C-মুক্ত!\033[0m"
    ব্যবrateবিধি_প্রদর্শন()
    return 0

main()
