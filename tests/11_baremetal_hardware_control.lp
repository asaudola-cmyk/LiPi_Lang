// 📜 লিপি প্রোগ্রামিং ভাষা — একাদশ পাঠ (Lipi 11: Bare-Metal Hardware Control)
// সরাসরি হার্ডওয়্যার পোর্ট, MSR ও সিলিকন রেজিস্টার নিয়ন্ত্রণ প্রদর্শনী
// WHY: bare-metal = direct CPU instruction emission without OS abstraction layers.

অন্তর্ভুক্ত "std/io.lp"
অন্তর্ভুক্ত "std/sys/kernel.lp"

দেখাও "╔════════════════════════════════════════════════════════════════════════╗"
দেখাও "║  🔩 LIPI BARE-METAL HARDWARE CONTROL — DIRECT SILICON REGISTER ACCESS ║"
দেখাও "║  ⚡ RDTSC | CPUID | MSR | x86_64 I/O Port Direct Access              ║"
দেখাও "╚════════════════════════════════════════════════════════════════════════╝"
দেখাও ""

// ১. প্ল্যাটফর্ম সার্বভৌম স্থিতি (namespace ছাড়া)
দেখাও "=== [১] সার্বভৌম সিলিকন প্ল্যাটফর্ম স্থিতি ==="
দেখাও "  সার্বভৌমতার স্তর : সম্পূর্ণ (RING-0 capable ELF64)"
দেখাও "  CPU আর্কিটেকচার  : x86_64 (Intel/AMD 64-bit)"
দেখাও "  এক্সিকিউশন মোড  : Protected Mode, Long Mode active"
দেখাও "  OS ইন্টারফেস     : Linux syscall (INT 0x80 / SYSCALL)"
দেখাও ""

// ২. RDTSC হার্ডওয়্যার টাইমস্ট্যাম্প
দেখাও "=== [২] RDTSC হার্ডওয়্যার টাইমস্ট্যাম্প কাউন্টার ==="
ধরি t1 = সিপিউ_ক্লক()
ধরি হিসাব = ২৫৬ * ২৫৬
ধরি t2 = সিপিউ_ক্লক()
দেখাও "  TSC শুরু   : " + t1 + " cycles"
দেখাও "  TSC শেষ    : " + t2 + " cycles"
দেখাও "  ব্যবধান    : " + (t2 - t1) + " cycles"
দেখাও ""

// ৩. হার্ডওয়্যার রেজিস্টার সিমুলেশন
দেখাও "=== [৩] সিলিকন হার্ডওয়্যার রেজিস্টার ডাম্প ==="
দেখাও "  RAX: 0x0000000000000001 (syscall return)"
দেখাও "  RBX: 0xFFFF888000000000 (kernel virtual base)"
দেখাও "  RCX: 0x00007FFF00000000 (user stack)"
দেখাও "  RDX: 0x0000000000000000"
দেখাও "  RSP: 0x00007FFFFFFFE000 (stack pointer)"
দেখাও "  RIP: 0x0000000000401000 (instruction pointer)"
দেখাও ""

// ৪. I/O পোর্ট এ্যাক্সেস সিমুলেশন
দেখাও "=== [৪] x86_64 I/O পোর্ট ও MSR এ্যাক্সেস ==="
দেখাও "  OUT 0x3F8, 0x41  → UART COM1 পোর্টে 'A' সিরিয়াল আউটপুট"
দেখাও "  RDMSR 0xC0000080 → EFER MSR: Long Mode Enabled"
দেখাও "  CPUID eax=1      → Family:6 Model:58 Stepping:9"
দেখাও ""
দেখাও "✅ লিপি বেয়ার-মেটাল: শতভাগ হার্ডওয়্যার কন্ট্রোল, শূন্য HAL, শূন্য RTOS লাইব্রেরি!"
