<div align="center">

# 👑 LIPI (লিপি): সার্বভৌম সিস্টেম প্রোগ্রামিং ভাষা
### Sovereign Systems Programming Language & Silicon Compiler

[![Native ELF](https://img.shields.io/badge/Binary-Native%20ELF%2064--bit-emerald.svg)]()
[![Zero Dependencies](https://img.shields.io/badge/Runtime-0%25%20PHP%20%7C%200%25%20Libc%20%7C%200%25%20GCC-blue.svg)]()
[![Self-Hosting](https://img.shields.io/badge/Self--Hosting-100%25%20Closure%20Proven-purple.svg)]()
[![Hardware ALU](https://img.shields.io/badge/Hardware-Direct%20x86__64%20ALU%20%26%20RDTSC-orange.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*লিপি কোনো ফ্রেমওয়ার্ক নয় — এটি একটি ১০০% স্বাধীন, সার্বভৌম সিস্টেম প্রোগ্রামিং ভাষা। লিপি সরাসরি সিলিকন প্রসেসর ও লিনাক্স কার্নেল নিয়ন্ত্রণ করে।*

</div>

---

## ⚡ ১. পরিচিতি ও দর্শন (The Lipi Sovereign Paradigm)

ঐতিহ্যবাহী প্রোগ্রামিং ভাষাগুলো রানটাইম ইন্টারপ্রেটার (PHP, Python, Node.js) বা ভারী বহিরাগত লাইব্রেরি ফ্রেমওয়ার্কের ওপর নির্ভরশীল। **লিপি (Lipi)** এই পরাধীনতা সম্পূর্ণভাবে ভেঙে দিয়েছে।

- **০% PHP / ০% Libc / ০% GCC রানটাইম নির্ভরতা:** লিপি সোর্স কোড (`.lp`) কম্পাইল করার পর সরাসরি লিনাক্স ELF ৬৪-বিট স্ট্যান্ডঅ্যালোন বাইনারি উৎপন্ন হয়। এটি রান করার জন্য কোনো PHP, Python, Libc বা বহিরাগত কম্পাইলারের প্রয়োজন নেই।
- **সরাসরি সিলিকন হার্ডওয়্যার এক্সিকিউশন:** গাণিতিক হিসাব (`imul`, `add`, `sub`, `idiv`), কন্ডিশনাল ব্রাঞ্চিং (`cmp`, `jle`, `jg`) এবং হার্ডওয়্যার ক্লক রিডিং (`RDTSC`) সরাসরি সিপিইউ রেজিস্টার (`%rax`, `%rbx`, `%rdx`, `%rsi`) ও স্ট্যাক ফ্রেমে রান করে।
- **দ্বিভাষিক ইউনিকোড সিনট্যাক্স:** বাংলায় কিংবা ইংরেজিতে সম্পূর্ণ সমান দক্ষতায় সিস্টেম কোড লেখা যায়।

---

## 🏛️ ২. ৪-ধাপের সার্বভৌম বুটস্ট্র্যাপিং আর্কিটেকচার (4-Stage Bootstrapping)

```
[ধাপ ০: বীজ / Bootstrapper] 
       │  (src/seed/bootstrapper.c -> bin/lipic & bin/lipi-seed)
       │  একক ফাইল C সিড যা লিপির প্রথম স্ট্যান্ডঅ্যালোন কম্পাইলার তৈরি করে
       ▼
[ধাপ ১: খাঁটি লিপিতে কম্পাইলার (src/Lipi/compiler.lp)]
       │  টোকেনাইজার, এএসটি স্ক্যানার, x86_64 মেশিন কোড ও ELF হেডার জেনারেটর
       ▼
[ধাপ ২: সেলফ-হোস্টিং ক্লোজার (Self-Hosting Closure)]
       │  bin/lipi (Gen-1) == bin/lipi-gen2 (Gen-2)
       │  লিপি বাইনারি এখন নিজেই নিজের সোর্স কোড কম্পাইল করে (Bit-for-Bit Determinism)
       ▼
[ধাপ ৩: সম্পূর্ণ সার্বভৌমত্ব (Total Sovereignty)]
          কোডবেস থেকে সমস্ত লেগ্যাসি .php অপসারিত, লিপি ১০০% স্বাধীন!
```

---

## 🚀 ৩. দ্রুত ব্যবহার নির্দেশিকা (Quick Start)

### সম্পূর্ণ পাইপলাইন বিল্ড ও টেস্ট রান:
```bash
./build.sh
```

### লিপি সোর্স কোড কম্পাইল করা:
```bash
# যেকোনো .lp ফাইল সরাসরি স্ট্যান্ডঅ্যালোন লিনাক্স ELF বাইনারিতে কম্পাইল করুন:
./bin/lipi examples/01_hello.lp -o dist/my_app

# তৈরি বাইনারি সরাসরি রান করুন:
./dist/my_app
```

### বাইনারির স্বাধীনতা যাচাই (Audit & Verification):
```bash
file dist/my_app
# dist/my_app: ELF 64-bit LSB executable, x86-64, statically linked, no section header

ldd dist/my_app
# not a dynamic executable (শূন্য ডায়নামিক লাইব্রেরি নির্ভরতা)
```

---

## 📜 ৪. লিপি কোড উদাহরণ (Example Code)

```lipi
// 📜 লিপি কোড উদাহরণ (লুপ, এরিথমেটিক ও সিলিকন ক্লক)
দেখাও "=== স্বাগতম লিপি প্রোগ্রামিং ভাষায়! ==="

ধরি ফ্যাক্টোরিয়াল = ১
ধরি গণনা = ১

যতক্ষণ গণনা <= ৫ {
    ফ্যাক্টোরিয়াল = ফ্যাক্টোরিয়াল * গণনা
    গণনা = গণনা + ১
}

দেখাও "১ থেকে ৫ পর্যন্ত গুণফল = " + ফ্যাক্টোরিয়াল

ধরি শুরু_ক্লক = সিপিউ_ক্লক()
ধরি যোগফল = ০
ধরি i = ১
যতক্ষণ i <= ১০ {
    যোগফল = যোগফল + i
    i = i + ১
}
ধরি শেষ_ক্লক = সিপিউ_ক্লক()
ধরি মোট_ক্লক = শেষ_ক্লক - শুরু_ক্লক

দেখাও "১ থেকে ১০ পর্যন্ত যোগফল = " + যোগফল
দেখাও "সিপিইউ এক্সিকিউশন ক্লক সাইকেল = " + মোট_ক্লক
```

---

## 📊 ৫. এম্পিরিক্যাল পারফরম্যান্স ও ক্লোজার ম্যাট্রিক্স

| প্যারামিটার | লিপির মান | স্ট্যাটাস |
| :--- | :--- | :--- |
| **কম্পাইল করা বাইনারি টাইপ** | Linux ELF 64-bit Static Executable | ✅ প্রমাণিত |
| **ডায়নামিক লাইব্রেরি (`ldd`)** | `not a dynamic executable` | ✅ ০% Libc |
| **PHP নির্ভরতা** | 0% PHP (কোডবেসে ০টি `.php` ফাইল) | ✅ সম্পূর্ণ স্বাধীন |
| **সেলফ-হোস্টিং ক্লোজার** | `bin/lipi` ↔ `bin/lipi-gen2` (100% Bit-for-Bit Deterministic) | ✅ প্রমাণিত |
| **সিপিইউ ইন্সট্রাকশন সেট** | x86_64 Direct Machine Code (ALU + RDTSC) | ✅ সিলিকন হার্ডওয়্যার |

---

## 👤 Author & Core Intelligence
**Shafiullah (Gyani Supreme Core)**  
*Universal Sovereign Computing & Systems Architecture*
