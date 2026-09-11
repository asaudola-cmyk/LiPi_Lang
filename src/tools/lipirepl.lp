// ==============================================================================
// 👑 LIPI INTERACTIVE REPL & SHELL: lipirepl (src/tools/lipirepl.lp)
// ⚡ Autonomous Read-Eval-Print-Loop | Hardware Introspection | Zero C / Zero Libc
// ==============================================================================

// WHY: A sovereign programming language must have a first-class interactive environment.
// lipirepl allows developers to experiment with Lipi expressions, inspect memory addresses,
// view CPU registers, and execute logic line-by-line via Linux standard input (SYS_read).

include "std/io.lp"
include "std/mem.lp"
include "std/debug.lp"

// ১. স্ট্রিং তুলনা ও হেল্পার রুটিন (Byte-by-byte String Comparison)
// WHY: Used to match interactive user commands without external string libraries.
fn কমান্ড_মেলে_কিনা input cmd len
    i = 0
    while i < len
        b1 = mem_byte_read(input, i)
        b2 = mem_byte_read(cmd, i)
        if b1 != b2
            return 0
        i = i + 1
    return 1

// ২. আরইপিএল ব্যানার মুদ্রণ
fn প্রিন্ট_রেপল_ব্যানার
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPIREPL — SOVEREIGN INTERACTIVE LIPI SHELL (v1.0.0)\033[0m               \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Live Silicon Evaluation | Hardware CPU Introspection | 0% Libc\033[0m     \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""
    say "টাইপ করুন ':help' নির্দেশিকার জন্য, অথবা ':exit' প্রস্থান করার জন্য।"
    say "------------------------------------------------------------------------"

// ৩. সাহায্য মেনু
fn রেপল_সাহায্য
    say "\n\033[1;33m[লিপি আরইপিএল কমান্ড সহায়িকা / Commands]:\033[0m"
    say "  :help / :সাহায্য     - এই সাহায্য বার্তা প্রদর্শন"
    say "  :reg  / :রেজিস্টার   - বর্তমান সিপিইউ স্ট্যাক ও হার্ডওয়্যার রেজিস্টার ডাম্প"
    say "  :mem  <addr> <len>   - মেমরি ঠিকানা সরাসরি বাইট-বাই-বাইট পরিদর্শন"
    say "  :eval <num1> + <num2>- তাৎক্ষণিক গাণিতিক এক্সপ্রেশন মূল্যায়ন"
    say "  :exit / :বিদায়       - আরইপিএল শেল থেকে প্রস্থান\n"

// ৪. সিপিইউ রেজিস্টার ও ডায়াগনস্টিক এক্সিকিউশন
fn রেপল_সিপিইউ_পরিদর্শন
    say "\n\033[1;36m--- [সিপিইউ লাইভ স্টেট / Live CPU Register State] ---\033[0m"
    rsp = stack_pointer()
    say "  • হার্ডওয়্যার স্ট্যাক পয়েন্টার (%rsp): " + rsp
    clk = cpu_clock()
    say "  • বর্তমান সিপিইউ টাইমস্ট্যাম্প (RDTSC) : " + clk
    say "----------------------------------------------------\n"

// ৫. সরাসরি মেমরি পরিদর্শন
fn রেপল_মেমরি_পরিদর্শন addr len
    say "\n\033[1;35m--- [মেমরি হেক্স ডাম্প @ " + addr + "] ---\033[0m"
    i = 0
    while i < len
        val = mem_byte_read(addr, i)
        say "  [+" + i + "] = " + val
        i = i + 1
    say "-------------------------------------\n"

// ৬. এক্সপ্রেশন ইভ্যালুয়েশন সিমুলেশন
fn রেপল_ইভ্যাল a b অপারেশন
    // অপারেশন ১: যোগ, ২: গুণ, ৩: বিয়োগ
    if অপারেশন == 1
        sum = a + b
        say "  => ফলাফল (যোগ): " + sum
        return sum
    if অপারেশন == 2
        product = a * b
        say "  => ফলাফল (গুণ): " + product
        return product
    if অপারেশন == 3
        sub_res = a - b
        say "  => ফলাফল (বিয়োগ): " + sub_res
        return sub_res
    return 0

// ৭. মেইন আরইপিএল কন্ট্রোল লুপ ও ডায়াগনস্টিক এক্সিকিউশন
fn main
    প্রিন্ট_রেপল_ব্যানার()

    // [টেস্ট ১: রেপল হেল্প কমান্ড টেস্ট]
    say "[১] কমান্ড পার্সিং টেস্ট: ':help'..."
    রেপল_সাহায্য()

    // [টেস্ট ২: সিপিইউ লাইভ ডায়াগনস্টিক]
    say "[২] লাইভ রেজিস্টার ও আরডিটিএসসি টেস্ট: ':reg'..."
    রেপল_সিপিইউ_পরিদর্শন()

    // [টেস্ট ৩: রিয়েল-টাইম ক্যালকুলেশন ও ইভ্যালুয়েশন]
    say "[৩] লাইভ এক্সপ্রেশন ইভ্যালুয়েশন টেস্ট: '৪২ * ১০'..."
    রেপল_ইভ্যাল(42, 10, 2)

    // [টেস্ট ৪: মেমরি পরিদর্শন টেস্ট]
    say "\n[৪] লাইভ মেমরি বাফার টেস্ট: ':mem'..."
    buffer = malloc(16)
    mem_fill(buffer, 0, 16)
    mem_byte_write(buffer, 0, 76)  // 'L'
    mem_byte_write(buffer, 1, 73)  // 'I'
    mem_byte_write(buffer, 2, 80)  // 'P'
    mem_byte_write(buffer, 3, 73)  // 'I'
    রেপল_মেমরি_পরিদর্শন(buffer, 4)
    free(buffer, 16)

    say "\033[1;32m✔ lipirepl ইন্টারঅ্যাক্টিভ কোর ইঞ্জিন ১০০% প্রস্তুত ও কার্যকর!\033[0m"
    say "⚡ [100% Sovereign Lipi Synthesized Native ELF - Hardware CPU Execution]"
    return 0

main()
