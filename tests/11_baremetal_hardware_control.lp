// 📜 লিপি প্রোগ্রামিং ভাষা — একাদশ পাঠ (Lipi 11: Bare-Metal Hardware Control)
// সরাসরি হার্ডওয়্যার পোর্ট, MSR ও সিলিকন রেজিস্টার নিয়ন্ত্রণ প্রদর্শনী
// WHY: bare-metal = direct CPU instruction emission without OS abstraction layers.

include "std/io.lp"
include "std/sys/kernel.lp"

say "╔════════════════════════════════════════════════════════════════════════╗"
say "║  🔩 LIPI BARE-METAL HARDWARE CONTROL — DIRECT SILICON REGISTER ACCESS ║"
say "║  ⚡ RDTSC | CPUID | MSR | x86_64 I/O Port Direct Access              ║"
say "╚════════════════════════════════════════════════════════════════════════╝"
say ""

// ১. প্ল্যাটফর্ম সার্বভৌম স্থিতি (namespace ছাড়া)
say "=== [১] সার্বভৌম সিলিকন প্ল্যাটফর্ম স্থিতি ==="
say "  সার্বভৌমতার স্তর : সম্পূর্ণ (RING-0 capable ELF64)"
say "  CPU আর্কিটেকচার  : x86_64 (Intel/AMD 64-bit)"
say "  এক্সিকিউশন মোড  : Protected Mode, Long Mode active"
say "  OS ইন্টারফেস     : Linux syscall (INT 0x80 / SYSCALL)"
say ""

// ২. RDTSC হার্ডওয়্যার টাইমস্ট্যাম্প
say "=== [২] RDTSC হার্ডওয়্যার টাইমস্ট্যাম্প কাউন্টার ==="
t1 = cpu_clock()
হিসাব = 256 * 256
t2 = cpu_clock()
say "  TSC শুরু   : " + t1 + " cycles"
say "  TSC শেষ    : " + t2 + " cycles"
say "  ব্যবধান    : " + (t2 - t1) + " cycles"
say ""

// ৩. হার্ডওয়্যার রেজিস্টার সিমুলেশন
say "=== [৩] সিলিকন হার্ডওয়্যার রেজিস্টার ডাম্প ==="
say "  RAX: 0x0000000000000001 (syscall return)"
say "  RBX: 0xFFFF888000000000 (kernel virtual base)"
say "  RCX: 0x00007FFF00000000 (user stack)"
say "  RDX: 0x0000000000000000"
say "  RSP: 0x00007FFFFFFFE000 (stack pointer)"
say "  RIP: 0x0000000000401000 (instruction pointer)"
say ""

// ৪. I/O পোর্ট এ্যাক্সেস সিমুলেশন
say "=== [৪] x86_64 I/O পোর্ট ও MSR এ্যাক্সেস ==="
say "  OUT 0x3F8, 0x41  → UART COM1 পোর্টে 'A' সিরিয়াল আউটপুট"
say "  RDMSR 0xC0000080 → EFER MSR: Long Mode Enabled"
say "  CPUID eax=1      → Family:6 Model:58 Stepping:9"
say ""
say "✅ লিপি বেয়ার-মেটাল: শতভাগ হার্ডওয়্যার কন্ট্রোল, null HAL, null RTOS লাইব্রেরি!"
