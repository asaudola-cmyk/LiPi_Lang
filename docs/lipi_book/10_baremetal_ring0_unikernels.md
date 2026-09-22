# অধ্যায় ১০: বেয়ার-মেটাল রিং-০ ও ইউনিকার্নেল (Bare-Metal Ring-0 & Unikernels)

> **"যখন কোনো অপারেটিং সিস্টেমের দরকার নেই, তখন তোমার কোডই স্বয়ং অপারেটিং সিস্টেম।"**

---

## ১০.১ ইউনিকার্নেল আর্কিটেকচার (The Sovereign Unikernel Paradigm)
প্রথাগত সিস্টেমে একটি অ্যাপ্লিকেশন চলতে গেলে নিচে লিনাক্স কার্নেল, ডিভাইস ড্রাইভার, সিস্টেমডি, ইউজার স্পেস ইত্যাদি শত শত স্তরের সাহায্য নিতে হয়।

লিপির **ইউনিকার্নেল (Unikernel)** পদ্ধতিতে:
- অ্যাপ্লিকেশনটি নিজেই সরাসরি বুটেবল কার্নেল ইমেজে পরিণত হয়।
- এটি সরাসরি রিং-০ সুপারভাইজার মোডে রান করে।
- কোনো লিনাক্স ওএস ছাড়াই সরাসরি বায়োস, ইউইএফআই (UEFI) অথবা কিউইএমইউ (QEMU) হাইপারভাইজরে বুট নেয়।

```
    Traditional Stack:                 Lipi Bare-Metal Unikernel:
    ┌───────────────────────────┐      ┌───────────────────────────┐
    │ Application Code (Ring 3) │      │ Lipi Application + Logic  │
    ├───────────────────────────┤      ├───────────────────────────┤
    │ C Runtime / System Libs   │      │ Sovereign Unikernel Core  │
    ├───────────────────────────┤      │ (Ring 0 Bare-Metal Kernel)│
    │ Linux Kernel OS (Ring 0)  │      └─────────────┬─────────────┘
    ├───────────────────────────┤                    │
    │ Hardware / Hypervisor     │                    ▼
    └───────────────────────────┘      [ Physical CPU / QEMU Silicon ]
```

---

## ১০.২ মাল্টিবুট২ হেডার ও COM1 সিরিয়াল ড্রাইভার (Multiboot2 & Serial UART)
ইউনিকার্নেলের বাইনারিতে শুরুতে একটি ৪৪-বাইট মাল্টিবুট২ হেডার থাকে:
- **ম্যাজিক নম্বর**: `0xE85250D6`
- **আর্কিটেকচার**: `0` (i386/x86_64 Long Mode)
- **চেকসাম**: `-(0xE85250D6 + arch + header_length)`

বুট নেওয়ার সাথে সাথে এটি COM1 UART (পোর্ট `0x3F8`) ইনিশিয়ালাইজ করে এবং সরাসরি স্ক্রিন ও টার্মিনালে টেক্সট প্রিন্ট করে:

```lipi
include "universe/os/build_unikernel.lp"

fn main
    say "সার্বভৌম বেয়ার-মেটাল ইউনিকার্নেল বিল্ডার চালনা..."

    kernel_name = "lipi_sovereign_core"
    out_img = "/tmp/lipi_kernel.bin"

    // মাল্টিবুট২ ও সিরিয়াল ড্রাইভার সহ ইমেজ তৈরি
    res = build_unikernel_image(kernel_name, out_img)

    if file_exists(out_img) == 1
        say "✔ ইউনিকার্নেল বুট ইমেজ প্রস্তুত: " + out_img
        say "বুট করার জন্য রান করুন:"
        say "qemu-system-x86_64 -kernel " + out_img + " -nographic -serial mon:stdio"
    else
        say "❌ ইউনিকার্নেল তৈরিতে ত্রুটি!"
    return 0

main()
```
