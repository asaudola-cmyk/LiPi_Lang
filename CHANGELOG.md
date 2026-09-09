# লিপি পরিবর্তন ইতিহাস (CHANGELOG)
# Lipi Programming Language — Change Log

---

## 🔖 প্রথম ১.০ — "সোভেরিন" | Prothom 1.0 — "Sovereign"
**মুক্তির তারিখ:** ২০২৬-০৯-০৯

> *"বিশ্বের প্রথম বাংলা প্রোগ্রামিং ভাষার প্রথম সার্বজনীন মুক্তি।"*
> *"First public release of the world's first Bengali programming language."*

---

### 🏆 মুখ্য অর্জন (Major Achievements)

#### ১. স্বনির্ভর কম্পাইলার (Self-Hosting Compiler)
- `bin/lipi` — ১৭KB স্ট্যাটিক ELF, শূন্য libc, শূন্য GCC
- লিপি দিয়ে লিপি কম্পাইল হয় (gen-1 ≡ gen-2, bit-for-bit)
- সরাসরি Linux kernel syscall — কোনো মধ্যস্থতাকারী নেই
- পাঁচটি কম্পাইলার পাইপলাইন স্টেজ:
  - Lexer → AST → SSA IR → Register Allocation → ELF Emitter

#### ২. সম্পূর্ণ টুলচেইন (Complete Toolchain)
| টুল | উদ্দেশ্য |
|-----|---------|
| `bin/lipic` | C bootstrap compiler (স্থায়ী কম্পাইলার) |
| `bin/lipi` | স্বনির্ভর সোভেরিন কম্পাইলার |
| `bin/lipipkg` | প্যাকেজ ম্যানেজার |
| `bin/lipidbg` | ptrace-based debugger |
| `bin/lipirepl` | ইন্টারেক্টিভ REPL |
| `bin/lipiconvert` | কোড রূপান্তরকারী |

#### ৩. স্ট্যান্ডার্ড লাইব্রেরি (Standard Library)
৪,৮৭০+ লাইনের বিশুদ্ধ লিপি কোড:

| মডিউল | বিষয়বস্তু |
|--------|----------|
| `std/core/io.lp` | ফাইল I/O, stdin/stdout |
| `std/core/mem.lp` | হিপ মেমরি বরাদ্দ |
| `std/core/str.lp` | স্ট্রিং প্রক্রিয়াকরণ |
| `std/core/math.lp` | গণিত ফাংশন |
| `std/core/json.lp` | JSON পার্সার |
| `std/core/arena.lp` | Arena allocator |
| `std/net/net.lp` | TCP/UDP socket |
| `std/net/tls.lp` | TLS 1.3 (ChaCha20) |
| `std/net/crypto.lp` | SHA-256, RDRAND |
| `std/net/websocket.lp` | WebSocket protocol |
| `std/sys/thread.lp` | Linux kernel threading |
| `std/sys/kernel.lp` | syscall wrappers |
| `std/sys/simd.lp` | AVX-512 SIMD |
| `std/sys/shm.lp` | POSIX shared memory |
| `std/sys/time.lp` | RDTSC, time |
| `std/sys/debug.lp` | ptrace debugger |
| `std/sys/event.lp` | epoll event loop |
| `std/ai/gguf.lp` | GGUF tensor inference |
| `std/ai/ai.lp` | AI/ML primitives |
| `std/db/db.lp` | Binary database engine |
| `std/db/columnstore.lp` | Column-oriented store |
| `std/db/hashmap.lp` | Robin Hood hashmap |
| `std/ui/gfx.lp` | BMP/framebuffer graphics |
| `std/ui/tui.lp` | ANSI terminal UI |
| `std/ui/x11.lp` | X11 window system |
| `std/version.lp` | ভাষার সংস্করণ তথ্য |

#### ৪. পরীক্ষা স্যুট (Test Suite)
**৪২/৪২ পাস** — সম্পূর্ণ রিগ্রেশন কভারেজ:

| পরীক্ষা পরিসর | বিষয় |
|--------------|-------|
| ০১-১১ | ভাষার মূল বৈশিষ্ট্য |
| ১২-২০ | সিলিকন লজিক, CPU arithmetic, stdlib |
| ২১-২৫ | থ্রেড, স্ট্রাকচার, DB, SIMD, Arena |
| ২৬-৩০ | Epoll, PKG, SHA-256, Debugger, AST optimizer |
| ৩১-৩৫ | TLS crypto, Graphics, Shared mem, TUI, ColumnAI |
| ৩৬-৪০ | Robin Hood, WebSocket, X11 GUI, Production app, GGUF |
| ৪১-৪২ | Bare-metal kernel, বাইলিঙ্গুয়াল syntax |

#### ৫. বেঞ্চমার্ক (Benchmark Results)
লিপি ১১টি ভাষার বিরুদ্ধে পরীক্ষিত: C, C++, Rust, Go, Python, JS, TS, Java, Swift, C#, Zig

**১০ মিলিয়ন লুপ বেঞ্চমার্কে** লিপি C-সমতুল্য পারফরম্যান্স অর্জন করেছে।

#### ৬. ডিরেক্টরি কাঠামো (Directory Structure)
```
lipi/
├── apps/website/     অফিসিয়াল ওয়েবসাইট ও ওয়েব সার্ভার
├── benchmarks/       ১১ ভাষার বেঞ্চমার্ক স্যুট
├── bin/              ৬টি প্রডাকশন বাইনারি
├── boot/lipi-seed    C bootstrap seed
├── docs/             স্পেসিফিকেশন ও ম্যানুয়াল
├── editors/vscode-lipi  VSCode এক্সটেনশন
├── examples/         ৪টি রিয়েল-ওয়ার্ল্ড ডেমো
├── modules/          ব্যবহারকারী মডিউল
├── scripts/          install, release, QEMU scripts
├── src/compiler/     কম্পাইলার সোর্স কোড
├── src/tools/        টুলচেইন সোর্স কোড
├── std/              স্ট্যান্ডার্ড লাইব্রেরি (৪৮৭০+ লাইন)
└── tests/            ৪২টি পরীক্ষা ফাইল
```

#### ৭. GitHub CI/CD
- ৬-স্টেজ GitHub Actions পাইপলাইন:
  1. Boot seed verification
  2. Compiler compilation
  3. Full toolchain build
  4. Self-hosting closure proof (bit-for-bit)
  5. Sovereignty audit (0% PHP/C in src/)
  6. Regression test suite (42/42)

---

### 🐛 পরিচিত সমস্যা (Known Issues)

#### কম্পাইলার সীমাবদ্ধতা (Compiler Limitations) — Phase 2 তে ঠিক হবে:
| সমস্যা | অবস্থা | ঠিক হবে |
|--------|--------|---------|
| `নাহলে_যদি` chain কাজ করে না | ⚠️ পরিচিত | প্রথম ২.০ |
| Array literal `[{...}]` segfault | ⚠️ পরিচিত | প্রথম ২.০ |
| `প্রতিটি x ভেতরে` for-each segfault | ⚠️ পরিচিত | প্রথম ২.০ |
| String concat initial value হারায় | ⚠️ পরিচিত | প্রথম ২.০ |
| Function string return → address | ⚠️ পরিচিত | প্রথম ২.০ |
| `চেষ্টা...ধরো` try-catch অবাস্তবায়িত | ⚠️ পরিচিত | প্রথম ২.০ |
| Namespace.method() calls | ⚠️ পরিচিত | প্রথম ২.০ |
| শুধু Linux x86_64 | ⚠️ পরিচিত | প্রথম ৩.০ |

#### Workaround:
- `নাহলে_যদি` এর পরিবর্তে nested `যদি...নাহলে` ব্যবহার করুন
- Array এর পরিবর্তে individual variables ব্যবহার করুন
- `দেখাও "label:", variable` পদ্ধতি ব্যবহার করুন (+ এর বদলে ,)

---

### 🗺️ পরবর্তী পদক্ষেপ (Roadmap)

| সংস্করণ | পরিকল্পিত বৈশিষ্ট্য |
|---------|---------------------|
| **প্রথম ২.০** | Compiler 2.0 (else-if fix, arrays, strings, try-catch, generics) |
| **প্রথম ৩.০** | Windows/macOS/Android/iOS cross-platform |
| **দ্বিতীয় ১.০** | WASM, AI framework, lipipkg registry |
| **তৃতীয় ১.০** | Multilingual keywords (Hindi, Arabic, Chinese...) |
| **চতুর্থ ১.০** | Lipi OS (sovereign computing stack) |

---

*পরিবর্তন লগ রক্ষণাবেক্ষণ: Gyani Supreme | শেষ আপডেট: ২০২৬-০৯-০৯*
