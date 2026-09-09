# 👑 LIPI (লিপি) অফিশিয়াল ওয়েবসাইট ও ডাইনামিক ওয়েব সার্ভার (`apps/webs/`)

এই ডিরেক্টরিটি লিপি প্রোগ্রামিং ভাষায় তৈরি একটি সম্পূর্ণ **সার্বভৌম, ডাইনামিক ও আধুনিক প্রিমিয়াম ওয়েব অ্যাপ্লিকেশন**। এটি কোনো বহিরাগত সার্ভার ইঞ্জিন (Apache, Nginx, Node.js, PHP-FPM) বা ফ্রেমওয়ার্ক ছাড়া সরাসরি লিনাক্স কার্নেল সকেটের ওপর চলে।

[![Native ELF](https://img.shields.io/badge/Binary-Native%20ELF%2064--bit-emerald.svg)]()
[![Zero Dependencies](https://img.shields.io/badge/Runtime-0%25%20PHP%20%7C%200%25%20Libc%20%7C%200%25%20GCC-blue.svg)]()
[![Sovereign Socket](https://img.shields.io/badge/Networking-Direct%20Linux%20TCP%20Syscalls-orange.svg)]()

---

## 🏛️ স্থাপত্য ওভারভিউ (Architecture Overview)

```
apps/webs/
├── server.lp                  # ১০০% খাঁটি লিপিতে লিখিত ডাইনামিক HTTP ওয়েব সার্ভার
├── site_builder.lp            # অ্যাসেট অডিটর ও ভ্যালিডেটর
├── build_and_run.sh           # কম্পাইলেশন ও সার্ভার রানার স্ক্রিপ্ট
├── test_web.sh                # এন্ড-টু-এন্ড অটোমেটেড HTTP টেস্ট স্যুট
└── public/
    ├── index.html             # প্রিমিয়াম ডার্ক সাইবার-সিলিকন অফিশিয়াল হোমপেজ UI
    ├── style.css              # গ্লাস মরফিজম ও নিয়ন ডিজাইন সিস্টেম
    ├── app.js                 # ডাইনামিক ক্লায়েন্ট ইঞ্জিন, প্লেগ্রাউন্ড ও লাইভ পোলিং
    └── favicon.svg            # লিপি সার্বভৌম ক্রাউন লোগো
```

---

## ⚡ ডাইনামিক ক্ষমতা ও ফিচারসমূহ

1. **সরাসরি কার্নেল টিসিপি সকেট স্ট্যাক**:
   - `SYS_socket` (৪১), `SYS_setsockopt` (৫৪), `SYS_bind` (৪৯), `SYS_listen` (৫০), `SYS_accept` (৪৩) ব্যবহার করে পোর্ট ৮০৮০ তে সরাসরি ট্রাফিক হ্যান্ডেল করে।
2. **ডাইনামিক রিকোয়েস্ট রাউটিং**:
   - `GET /` ও `GET /index.html` -> আধুনিক হোমপেজ পরিবেশন।
   - `GET /style.css` -> ডিজাইন সিস্টেম সিএসএস পরিবেশন।
   - `GET /app.js` -> ক্লায়েন্ট ইন্টারঅ্যাক্টিভ ইঞ্জিন পরিবেশন।
   - `GET /favicon.svg` -> এসভিজি ব্র্যান্ড আইকন পরিবেশন।
   - `GET /api/status` -> **লাইভ সিলিকন মেট্রিক্স JSON**:
     ```json
     {
       "status": "sovereign_online",
       "engine": "Lipi Native Silicon ELF64",
       "version": "2.1-ultra",
       "cpu_cycles": 140584460537808,
       "uptime_cycles": 2232081264,
       "requests_served": 42,
       "memory_allocated_kb": 128,
       "active_horizons": 21,
       "php_dependency": 0,
       "libc_dependency": 0
     }
     ```
3. **আধুনিক প্রিমিয়াম ফ্রন্টএন্ড UI**:
   - ডার্ক স্পেস ব্যাকগ্রাউন্ড ও নিয়ন সাইয়ান গ্লাস মরফিজম।
   - ৬টি লাইভ এক্সিকিউটেবল কোড স্নিপেট সহ ইন্টারঅ্যাক্টিভ সিলিকন প্লেগ্রাউন্ড।
   - ২১টি মাস্টার মহাদিগন্তের ফিল্টারেবল লাইভ ম্যাট্রিক্স।
   - সিপিইউ সাইকেল ও অ্যালোকশন তুলনা সহ হার্ডওয়্যার বেঞ্চমার্ক।
   - লাইভ টেলিমেট্রি বার যা প্রতি ২.৫ সেকেন্ড পর পর ব্যাকএন্ডের `/api/status` থেকে রিয়েল-টাইম ডাটা আপডেট করে।

---

## 🚀 দ্রুত ব্যবহার নির্দেশিকা (Quickstart)

### ১. সার্ভার সংকলন ও চালু করা:
```bash
# স্বয়ংক্রিয় রানার স্ক্রিপ্ট দিয়ে চালু করুন:
./apps/webs/build_and_run.sh

# অথবা সরাসরি লিপিক কম্পাইলার দিয়ে:
./bin/lipic apps/webs/server.lp -o apps/webs/lipi_server
./apps/webs/lipi_server
```

### ২. ব্রাউজারে প্রবেশ করুন:
```
http://localhost:8080/
অথবা
http://127.0.0.1:8080/
```

### ৩. অটোমেটেড এন্ড-টু-এন্ড টেস্ট রান:
```bash
./apps/webs/test_web.sh
```

---

## 🛡️ সার্বভৌমত্ব ও ডিপেন্ডেন্সি অডিট
```bash
file apps/webs/lipi_server
# ELF 64-bit LSB executable, x86-64, statically linked, no section header

ldd apps/webs/lipi_server
# not a dynamic executable (০% Libc, ০% GCC, ০% PHP)
```
