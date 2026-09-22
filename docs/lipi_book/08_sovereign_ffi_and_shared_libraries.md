# অধ্যায় ৮: সার্বভৌম FFI ও শেয়ার্ড লাইব্রেরি এমিটার (Sovereign FFI & Shared Libraries)

> **"বিশ্বের সাথে যুক্ত হওয়ার জন্য নতজানু হতে হয় না; শক্তিশালী ও সমমর্যাদায় নিজস্ব স্ট্যান্ডার্ডে হাত মেলাতে হয়।"**

---

## ৮.১ খাঁটি ডাইনামিক লাইব্রেরি (.so) এমিশন (Pure Shared Object Emitter)
লিপি কেবল একক এক্সিকিউটেবল তৈরি করে না; এটি সরাসরি লিনাক্স ডায়নামিক শেয়ার্ড অবজেক্ট (`.so`) ফাইল তৈরি করে যাতে যেকোনো বিদেশি ভাষা বা সিস্টেম (যেমন সি, রাস্ট, গো, পাইথন বা লিনাক্স ওএস) সরাসরি লিপি লাইব্রেরি ব্যবহার করতে পারে।
- **ELF Type**: `ET_DYN` (Type 3)
- **পজিশন ইনডিপেনডেন্ট কোড (PIC)**: সম্পূর্ণ RIP-রিলেটিভ অ্যাড্রেসিং (`[rip + disp32]`), যার ফলে লিনাক্স ASLR মেমরি র‍্যান্ডমাইজেশনে কোনো ক্র্যাশ হয় না।
- **সিস্টেম V ABI কম্প্যাটিবল**: স্ট্যান্ডার্ড রেজিস্টার কলিং কনভেনশন (`rdi, rsi, rdx, rcx, r8, r9, rax`)।
- **এক্সপোর্টেড সিম্বল ও হ্যাশ টেবিল**: নিজস্ব `.dynstr`, `.dynsym` এবং SysV `.hash` টেবিল জেনারেশন।

```
    Lipi Source Module (my_lib.lp)
                 │
                 ▼
    lipc -shared my_lib.lp -o libmy_lib.so
                 │
                 ├────────────────────────────────────────┐
                 ▼                                        ▼
    ELF64 Shared Object Header                Dynamic Sections (.text, .dynsym,
    (e_type: ET_DYN, e_phnum: 2)               .dynstr, SysV .hash, .dynamic)
                 │                                        │
                 └──────────────────┬─────────────────────┘
                                    ▼
                      Native Linux Dynamic Linker
                           (ld-linux-x86-64.so)
```

---

## ৮.২ শেয়ার্ড লাইব্রেরি তৈরি ও এক্সপোর্টের উদাহরণ (Working Example)
নিচের কোডটি লিখুন `math_lib.lp`:

```lipi
// সার্বভৌম গণিত লাইব্রেরি
fn lipi_math_add a b
    return a + b

fn lipi_math_multiply a b
    return a * b
```

এটি শেয়ার্ড লাইব্রেরি হিসেবে কম্পাইল করুন:
```bash
bin/lipc -shared math_lib.lp -o libmath.so
```

আপনি `readelf -h libmath.so` এবং `readelf --dyn-syms libmath.so` চালিয়ে দেখতে পারেন—এটি শতভাগ বৈধ একটি লিনাক্স ডায়নামিক লাইব্রেরি যা অন্য যেকোনো ভাষায় সরাসরি লোড করা যায়!
