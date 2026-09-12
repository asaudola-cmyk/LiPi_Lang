# 👑 সার্বভৌম লিপি পুস্তক (The Sovereign Lipi Book)
### *A Complete Architectural Guide to 100% Native Sovereign Systems Programming*

> **"সফটওয়্যার যখন কারো অধীনস্থ নয়, তখনই মানবজাতি স্বাধীন।"**
> — *The Lipi Sovereign Manifesto*

---

## 📖 সূচিপত্র (Table of Contents)

| অধ্যায় | শিরোনাম | বিষয়বস্তু |
|---|---|---|
| **০১** | [Introduction & Sovereign Setup](01_introduction_and_setup.md) | শূন্য নির্ভরতা, বুটস্ট্র্যাপ পাইপলাইন, সরাসরি ELF64 কোড জেনারেশন |
| **০২** | [Bilingual & Tri-Syntax Paradigm](02_bilingual_tri_syntax.md) | বাংলা ও ইংরেজি দ্বিভাষিক কোড, ত্রি-সিনট্যাক্স ক্যানোনিকাল টোকেনাইজার |
| **০৩** | [Memory Model, Slabs & Arenas](03_memory_model_and_slabs.md) | মেমরি মডেল, স্ল্যাব অ্যালোকোটর, অ্যারেনা এবং শূন্য ফ্র্যাগমেন্টেশন |
| **০৪** | [Fiber Runtime & CSP Channels](04_fiber_runtime_and_channels.md) | লাইটওয়েট ফাইবার কনকারেন্সি, চ্যানেল যোগাযোগ, ইভেন্ট ড্রাইভেন শিডিউলার |
| **০৫** | [High-Performance Web & Database](05_high_performance_web_and_db.md) | পলিমরফিক ওয়েব সার্ভার, B-Tree এবং কলামনার ডাটাবেজ ইঞ্জিন |
| **০৬** | [Silicon GPU & Native SPIR-V](06_silicon_gpu_and_spirv.md) | সরাসরি বাইনারি SPIR-V এমিশন, ভলকান/ওয়েবজিপিইউ ও সমান্তরাল গণনা |
| **০৭** | [Silicon AI & Vector Tensor Engine](07_silicon_ai_and_tensors.md) | টেনসর ইঞ্জিন, AVX2 ও AVX-512 সিলিকন ইন্ট্রিনসিক্স, GEMM অপ্টিমাইজেশন |
| **০৮** | [Sovereign FFI & Shared Libraries](08_sovereign_ffi_and_shared_libraries.md) | ডাইনামিক লাইব্রেরি (.so) এমিশন, সিস্টেম V ABI, সি-বাইন্ডিংহীন ইন্টারপ |
| **০৯** | [Cryptographic Suite & LipiPkg Hub](09_cryptographic_package_hub.md) | খাঁটি লিপি ক্রিপ্টো (TLS 1.3, AES-GCM, SHA256), নিরাপদ প্যাকেজ ম্যানেজার |
| **১০** | [Bare-Metal Ring-0 & Unikernels](10_baremetal_ring0_unikernels.md) | কোনো ওএস ছাড়া সরাসরি বায়োস/কিউইএমইউ বুট, মাল্টিবুট২ ও সিরিয়াল ড্রাইভ |

---

## 🏛️ সার্বিক উদ্দেশ্য (Core Architectural Objectives)
1. **১০০% সার্বভৌমত্ব (Zero External Toolchains)**: লিপি কোনো সি কম্পাইলার (GCC/Clang), পাইথন রানটাইম বা সি লাইব্রেরি (Libc/Glibc) এর উপর নির্ভরশীল নয়। এটি নিজের মেশিন কোড নিজেই তৈরি করে।
2. **হার্ডওয়্যার সিলিকন সরাসরি নিয়ন্ত্রণ**: সিপিইউ রেজিস্টার, মেমরি পেজ, নেটওয়ার্ক ইন্টারফেস ফ্রেম ও ডিস্ক আই/ও সরাসরি লিনাক্স সিস্টেম কলের মাধ্যমে পরিচালিত।
3. **দ্বিভাষিক সমতা**: বিশ্বের প্রথম শিল্প-গ্রেড প্রোগ্রামিং ভাষা যেখানে বাংলা এবং ইংরেজি উভয় ভাষায় নির্বিঘ্নে কোড লেখা এবং কম্পাইল করা যায়।
