# 📖 লিপি ভাষার সম্পূর্ণ গাইড
# Lipi Programming Language — Complete Language Guide
## সংস্করণ: প্রথম ১.০.০ | Version: First 1.0.0

---

## ভূমিকা (Introduction)

**লিপি** (Lipi) পৃথিবীর প্রথম বাংলা প্রোগ্রামিং ভাষা।
বাংলায় কোড লিখুন, সরাসরি CPU-তে চলবে। শূন্য Python, শূন্য GCC, শূন্য libc।

**Lipi** is the world's first Bengali programming language.
Write code in Bengali — runs directly on CPU. Zero Python, Zero GCC, Zero libc.

```bash
# ইনস্টল করুন (Install)
curl -fsSL https://lipi.dev/install | bash

# প্রথম প্রোগ্রাম (First program)
echo 'দেখাও "সালাম দুনিয়া!"' > hello.lp
lipic hello.lp -o hello
./hello
# আউটপুট: সালাম দুনিয়া!
```

---

## অধ্যায় ১: মূল ধারণা (Chapter 1: Core Concepts)

### ১.১ — চলক (Variables)

```lipi
// ধরি = let/var (declare a variable)
// WHY: বাংলায় "ধরি" মানে "ধরে নিই" — assume/let it be
ধরি নাম = "রফিক আহমেদ"
ধরি বয়স = ২৫
ধরি উচ্চতা = ৫.৮
ধরি বিবাহিত = মিথ্যা

// English equivalent keywords also work
let name = "Rafiq Ahmed"
var age = 25
```

**সমতুল্য কীওয়ার্ড (Keyword Equivalents):**
| বাংলা | English |
|-------|---------|
| `ধরি` | `let` / `var` |
| `দেখাও` | `print` / `show` |
| `যদি` | `if` |
| `নাহলে` | `else` |
| `যতক্ষণ` | `while` |
| `কাজ` | `fun` / `func` |
| `ফেরত` | `return` |
| `সত্য` | `true` |
| `মিথ্যা` | `false` |
| `শূন্য` | `null` / `nil` |
| `ধরনক` | generic type param |

---

### ১.২ — প্রদর্শন (Output)

```lipi
// দেখাও = show/print
দেখাও "হ্যালো লিপি!"

// Comma-separated (multiple values)
ধরি ফলাফল = ৪২
দেখাও "উত্তর:", ফলাফল

// Bengali numerals are native
দেখাও বাংলা_সংখ্যা(৪২)   // → ৪২
দেখাও বাংলা_সংখ্যা(১০০০) // → ১০০০
```

---

### ১.৩ — ডেটা ধরন (Data Types)

```lipi
// সংখ্যা = Number (integer & float)
ধরি ক: সংখ্যা = ১০০
ধরি খ: সংখ্যা = ৩.১৪

// লেখা = String (text)
ধরি বার্তা: লেখা = "লিপিতে স্বাগতম"

// সত্যমিথ্যা = Boolean
ধরি সত্যিকার: সত্যমিথ্যা = সত্য
ধরি মিথ্যাকার: সত্যমিথ্যা = মিথ্যা

// শূন্য = Null/None
ধরি খালি = শূন্য
```

---

## অধ্যায় ২: অপারেটর (Chapter 2: Operators)

### ২.১ — গাণিতিক অপারেটর (Arithmetic)

```lipi
ধরি ক = ১০
ধরি খ = ৩

দেখাও ক + খ    // ১৩ (যোগ)
দেখাও ক - খ    // ৭  (বিয়োগ)
দেখাও ক * খ    // ৩০ (গুণ)
দেখাও ক / খ    // ৩  (ভাগ, integer)
দেখাও ক % খ    // ১  (ভাগশেষ/modulo)
দেখাও ক ** খ   // ১০০০ (ঘাত/power)
```

### ২.২ — তুলনা অপারেটর (Comparison)

```lipi
ধরি ক = ১০
দেখাও ক == ১০   // সত্য (equal)
দেখাও ক != ৫    // সত্য (not equal)
দেখাও ক > ৫     // সত্য (greater than)
দেখাও ক < ২০    // সত্য (less than)
দেখাও ক >= ১০   // সত্য (greater or equal)
দেখাও ক <= ১০   // সত্য (less or equal)
```

### ২.৩ — বিটওয়াইজ অপারেটর (Bitwise)

```lipi
দেখাও ১০ & ৬    // ২  (AND)
দেখাও ১০ | ৬    // ১৪ (OR)
দেখাও ১০ ^ ৬    // ১২ (XOR)
দেখাও ১ << ৪    // ১৬ (left shift)
দেখাও ১৬ >> ২   // ৪  (right shift)
```

---

## অধ্যায় ৩: শর্তাধীন লজিক (Chapter 3: Conditionals)

### ৩.১ — যদি/নাহলে (if/else)

```lipi
ধরি বয়স = ২০

যদি বয়স >= ১৮ {
    দেখাও "প্রাপ্তবয়স্ক (adult)"
} নাহলে {
    দেখাও "অপ্রাপ্তবয়স্ক (minor)"
}
```

### ৩.২ — nested যদি (nested if — for else-if effect)

```lipi
// WHY: লিপি প্রথম ১.০ এ নাহলে_যদি এর পরিবর্তে nested যদি ব্যবহার করুন
ধরি নম্বর = ৭৬

যদি নম্বর >= ৯০ {
    দেখাও "গ্রেড: A+"
} নাহলে {
    যদি নম্বর >= ৮০ {
        দেখাও "গ্রেড: A"
    } নাহলে {
        যদি নম্বর >= ৭০ {
            দেখাও "গ্রেড: B"
        } নাহলে {
            দেখাও "গ্রেড: F"
        }
    }
}
// আউটপুট: গ্রেড: B

// ─── ভবিষ্যৎ (প্রথম ২.০ এ): ───────────────
// যদি নম্বর >= ৯০ { ... }
// নাহলে_যদি নম্বর >= ৮০ { ... }
// নাহলে { ... }
```

---

## অধ্যায় ৪: লুপ (Chapter 4: Loops)

### ৪.১ — যতক্ষণ লুপ (while loop)

```lipi
// WHY: "যতক্ষণ" = "as long as" — সবচেয়ে মৌলিক iteration
ধরি গণনা = ১

যতক্ষণ গণনা <= ১০ {
    দেখাও "সংখ্যা:", বাংলা_সংখ্যা(গণনা)
    গণনা = গণনা + ১
}

// ─── পারফরম্যান্স লুপ (১ কোটি iteration) ────
ধরি যোগফল = ০
ধরি আই = ১
ধরি শুরু = সিপিউ_ক্লক()

যতক্ষণ আই <= ১০০০০০০০ {
    যোগফল = যোগফল + (আই % ৭)
    আই = আই + ১
}

ধরি শেষ = সিপিউ_ক্লক()
দেখাও "যোগফল:", যোগফল
দেখাও "CPU Cycles:", (শেষ - শুরু)
```

### ৪.২ — গণনা লুপ (counted loop)

```lipi
// লুপ ভেরিয়েবল বাইরে declare করুন
ধরি i = ০
যতক্ষণ i < ৫ {
    দেখাও i
    i = i + ১
}
// আউটপুট: ০ ১ ২ ৩ ৪
```

---

## অধ্যায় ৫: ফাংশন (Chapter 5: Functions)

### ৫.১ — ফাংশন সংজ্ঞা (Function Definition)

```lipi
// কাজ = function/fun/def
// WHY: "কাজ" বাংলায় "task/work" — একটি কাজ সম্পাদন করে

কাজ স্বাগত() {
    দেখাও "লিপিতে স্বাগতম!"
}

কাজ যোগ(ক, খ) {
    ফেরত ক + খ
}

কাজ গড়(সংখ্যাগুলো, মোট) {
    ফেরত সংখ্যাগুলো / মোট
}

// কল করুন
স্বাগত()
ধরি ফল = যোগ(৫, ৭)
দেখাও "৫ + ৭ =", ফল
```

### ৫.২ — পুনরাবৃত্তি (Recursion)

```lipi
// WHY: Recursion = function calling itself — গণিতের মতো
কাজ ফ্যাক্টোরিয়াল(ন) {
    যদি ন <= ১ {
        ফেরত ১
    }
    ফেরত ন * ফ্যাক্টোরিয়াল(ন - ১)
}

দেখাও "১০! =", ফ্যাক্টোরিয়াল(১০)
// আউটপুট: ১০! = ৩৬২৮৮০০

কাজ ফিবোনাচি(ন) {
    যদি ন <= ১ { ফেরত ন }
    ফেরত ফিবোনাচি(ন - ১) + ফিবোনাচি(ন - ২)
}

দেখাও "ফিবোনাচি(১০) =", ফিবোনাচি(১০)
// আউটপুট: ৫৫
```

---

## অধ্যায় ৬: গঠন (Chapter 6: Structs)

### ৬.১ — গঠন সংজ্ঞা (Struct Definition)

```lipi
// গঠন = struct/record — কাস্টম ডেটা টাইপ
// WHY: Real-world objects have multiple properties
// A "person" has name, age, height — গঠন এটা model করে

গঠন মানুষ {
    আইডি,
    বয়স,
    উচ্চতা
}

// মেমরি বরাদ্দ করে instance তৈরি
ধরি আকার = সাইজ(মানুষ)
ধরি রফিক = মেমরি_বরাদ্দ(আকার)
রফিক.আইডি = ১
রফিক.বয়স = ২৫
রফিক.উচ্চতা = ১৭৫

দেখাও "আইডি:", রফিক.আইডি
দেখাও "বয়স:", রফিক.বয়স
দেখাও "উচ্চতা:", রফিক.উচ্চতা

// মেমরি মুক্তি (good practice)
মেমরি_মুক্তি(রফিক, আকার)
```

---

## অধ্যায় ৭: মডিউল (Chapter 7: Modules)

### ৭.১ — stdlib import

```lipi
// অন্তর্ভুক্ত = include/import
// WHY: Code reuse — "include" করা মানে সেই ফাইলের সব কোড এখানে নিয়ে আসা

অন্তর্ভুক্ত "std/io.lp"        // ফাইল I/O
অন্তর্ভুক্ত "std/net.lp"       // নেটওয়ার্ক
অন্তর্ভুক্ত "std/mem.lp"       // মেমরি
অন্তর্ভুক্ত "std/str.lp"       // স্ট্রিং
অন্তর্ভুক্ত "std/math.lp"      // গণিত
অন্তর্ভুক্ত "std/crypto.lp"    // SHA-256, TLS
অন্তর্ভুক্ত "std/version.lp"   // সংস্করণ তথ্য
```

### ৭.২ — নিজস্ব মডিউল (Custom Module)

```lipi
// modules/আমার_গণিত.lp ফাইল তৈরি করুন:
ধরি পাই = ৩১৪৬ / ১০০০   // ≈ 3.14159

কাজ বর্গ(সংখ্যা) {
    ফেরত সংখ্যা * সংখ্যা
}

কাজ বর্গমূল_আনুমানিক(ন) {
    // Newton's method
    ধরি অনুমান = ন / ২
    ধরি গণনা = ০
    যতক্ষণ গণনা < ১০ {
        অনুমান = (অনুমান + ন / অনুমান) / ২
        গণনা = গণনা + ১
    }
    ফেরত অনুমান
}

// প্রধান ফাইলে ব্যবহার:
অন্তর্ভুক্ত "modules/আমার_গণিত.lp"
দেখাও "৯ এর বর্গ:", বর্গ(৯)
দেখাও "√১৬ ≈", বর্গমূল_আনুমানিক(১৬)
```

---

## অধ্যায় ৮: ফাইল I/O (Chapter 8: File I/O)

```lipi
অন্তর্ভুক্ত "std/io.lp"

// ফাইল লেখা (File Write)
// WHY: syscall write() directly — no stdio buffering
ধরি ফাইল = ফাইল_খোলো("data.txt", O_WRONLY | O_CREAT, ৬৪৪)
ফাইল_লিখো(ফাইল, "লিপিতে লেখা ফাইল")
ফাইল_বন্ধ করো(ফাইল)

// ফাইল পড়া (File Read)
ধরি পড়ার_ফাইল = ফাইল_খোলো("data.txt", O_RDONLY, ০)
ধরি বাফার = মেমরি_বরাদ্দ(৪০৯৬)
ধরি পড়া_বাইট = ফাইল_পড়ো(পড়ার_ফাইল, বাফার, ৪০৯৬)
দেখাও "পড়া হয়েছে:", পড়া_বাইট, "বাইট"
ফাইল_বন্ধ করো(পড়ার_ফাইল)
```

---

## অধ্যায় ৯: নেটওয়ার্ক (Chapter 9: Networking)

```lipi
অন্তর্ভুক্ত "std/net.lp"

// HTTP সার্ভার (HTTP Server)
// WHY: Direct Linux TCP socket — no Node.js, no nginx needed
কাজ হ্যান্ডলার(ক্লায়েন্ট_fd) {
    ধরি রেসপন্স = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>লিপি সার্ভার!</h1>"
    সকেট_লিখো(ক্লায়েন্ট_fd, রেসপন্স)
    সকেট_বন্ধ(ক্লায়েন্ট_fd)
}

ধরি সার্ভার = TCP_সকেট_তৈরি()
সকেট_বাঁধো(সার্ভার, ৮০৮০)
সকেট_শোনো(সার্ভার, ১২৮)

যতক্ষণ সত্য {
    ধরি ক্লায়েন্ট = সকেট_গ্রহণ(সার্ভার)
    হ্যান্ডলার(ক্লায়েন্ট)
}
```

---

## অধ্যায় ১০: হার্ডওয়্যার প্রোগ্রামিং (Chapter 10: Hardware Programming)

```lipi
// সরাসরি CPU clock পড়া
ধরি শুরু = সিপিউ_ক্লক()

// SIMD — একসাথে ৮টি সংখ্যা প্রক্রিয়াকরণ
অন্তর্ভুক্ত "std/sys/simd.lp"
ধরি ভেক্টর_ক = SIMD_লোড(ptr_ক)
ধরি ভেক্টর_খ = SIMD_লোড(ptr_খ)
ধরি ফলাফল = SIMD_যোগ(ভেক্টর_ক, ভেক্টর_খ)

// kernel syscall সরাসরি
অন্তর্ভুক্ত "std/sys/kernel.lp"
ধরি pid = getpid()
দেখাও "প্রসেস আইডি:", pid
```

---

## দ্রুত রেফারেন্স (Quick Reference)

### Built-in Functions

| ফাংশন | কাজ | উদাহরণ |
|-------|-----|---------|
| `দেখাও(...)` | screen এ দেখানো | `দেখাও "হ্যালো"` |
| `দৈর্ঘ্য(x)` | length of string/array | `দৈর্ঘ্য("abc")` → ৩ |
| `বাংলা_সংখ্যা(n)` | number → Bengali string | `বাংলা_সংখ্যা(৪২)` |
| `সিপিউ_ক্লক()` | RDTSC hardware clock | nanosecond timer |
| `মেমরি_বরাদ্দ(n)` | allocate n bytes | raw memory |
| `মেমরি_মুক্তি(p, n)` | free memory | release allocation |
| `মেমরি_বাইট_লেখো(p, i, v)` | write byte | low-level write |
| `মেমরি_বাইট_পড়ো(p, i)` | read byte | low-level read |
| `সাইজ(T)` | sizeof struct T | struct memory size |
| `ফাইল_খোলো(path, flags, mode)` | open file | returns fd |
| `ফাইল_পড়ো(fd, buf, n)` | read n bytes | returns bytes read |
| `ফাইল_লিখো(fd, data)` | write to file | returns bytes written |
| `ফাইল_বন্ধ করো(fd)` | close file | releases fd |

### বিশেষ ধ্রুবক (Special Constants)
| ধ্রুবক | মান |
|--------|-----|
| `সত্য` | 1 (true) |
| `মিথ্যা` | 0 (false) |
| `শূন্য` | 0 (null/nil) |
| `O_RDONLY` | 0 |
| `O_WRONLY` | 1 |
| `O_CREAT` | 64 |

---

## কম্পাইল ও রান (Compile & Run)

```bash
# সাধারণ compile
lipic আমার_প্রোগ্রাম.lp -o আমার_প্রোগ্রাম
./আমার_প্রোগ্রাম

# স্বনির্ভর (sovereign) compiler ব্যবহার
lipi আমার_প্রোগ্রাম.lp -o আমার_প্রোগ্রাম

# binary type verify করুন
file আমার_প্রোগ্রাম  # → ELF 64-bit, statically linked

# sovereignty audit
ldd আমার_প্রোগ্রাম   # → not a dynamic executable ✔
```

---

## আরো শিখুন (Learn More)

- **স্পেসিফিকেশন:** `docs/SPECIFICATION_v1.md`
- **আর্কিটেকচার:** `docs/ARCHITECTURE.md`
- **stdlib ডক:** `docs/STANDARD_LIBRARY.md`
- **উদাহরণ:** `tests/*.lp` (৪২টি প্রোগ্রাম)
- **ওয়েবসাইট:** `apps/website/` চালিয়ে দেখুন

---

*গাইড রচনা: Gyani Supreme | লিপি প্রথম ১.০ | ২০২৬-০৯-০৯*
