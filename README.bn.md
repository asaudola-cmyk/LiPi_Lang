# লিপি (Lipi)

[![CI](https://github.com/asaudola-cmyk/LiPi_Lang/actions/workflows/lipi-ci.yml/badge.svg)](https://github.com/asaudola-cmyk/LiPi_Lang/actions/workflows/lipi-ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) | বাংলা (Bengali)

লিপি একটি সেলফ-হোস্টেড, স্ট্যাটিক্যালি কম্পাইল্ড দ্বিভাষিক (বাংলা ও ইংরেজি) সিস্টেমস প্রোগ্রামিং ভাষা। এর কম্পাইলার, রানটাইম, স্ট্যান্ডার্ড লাইব্রেরি এবং ডেভেলপার টুলচেইন লিপিতেই লেখা এবং এটি GCC, Clang, LLVM বা `libc` ছাড়াই সরাসরি নেটিভ মেশিন কোড তৈরি করে।

## মূল বৈশিষ্ট্য

- **সেলফ-হোস্টেড নেটিভ কম্পাইলার (`src/compiler/`)**: সরাসরি Static-PIE Linux x86_64 ELF64 বাইনারি (`0 RWE` সেগমেন্ট), Windows PE32+, macOS Mach-O, ARM64, RISC-V 64 এবং WebAssembly তৈরি করে। `src/boot/lipi-seed` থেকে ৩-ধাপে বিট-ফর-বিট ডিটারমিনিস্টিক বুটস্ট্র্যাপ সমর্থিত।
- **জিরো এক্সটার্নাল রানটাইম ডিপেনডেন্সি**: প্রোগ্রামগুলো কোনো ডাইনামিক লিংকার বা C রানটাইম ছাড়াই সরাসরি OS কার্নেল সিসকল ব্যবহার করে।
- **দ্বিভাষিক সিনট্যাক্স**: একই AST-তে বাংলা কীওয়ার্ড ও সংখ্যা, ইংরেজি কীওয়ার্ড এবং `@`-ডিরেক্টিভ সিনট্যাক্স সমর্থিত।
- **স্ট্যাটিক সেফটি (`--kavach`) ও W^X আইসোলেশন**: ঐচ্ছিক কম্পাইল-টাইম ওনারশিপ/মেমরি লিক যাচাই ও `silicon_*` হার্ডওয়্যার বাউন্ডারি চেক, পাশাপাশি Ed25519-স্বাক্ষরিত `LPKC` W^X ক্যাপসুল (`utso/core/kavach_capsule.lp`) এবং W^X ELF শেয়ার্ড-অবজেক্ট লোডার (`utso/core/ffi_sovereign.lp`)।
- **নেটিভ ক্রিপ্টোগ্রাফি, TLS 1.3 ও HTTP/2**: সম্পূর্ণ লিপিতে লেখা SHA-256/384/512, AES-128/256-GCM, ChaCha20-Poly1305, X25519, Ed25519, NIST P-256/P-384 ECDSA, RSA-PSS/PKCS#1 v1.5, X.509 চেইন ভ্যালিডেশন, TLS 1.3 ক্লায়েন্ট/সার্ভার (SNI মাল্টি-ডোমেইন, P-256/P-384/Ed25519 সাইনিং, PSK সেশন রিজাম্পশন, ALPN `h2`/`http/1.1`) এবং RFC 7540/7541 HTTP/2 (`h2c` ও `h2`, HPACK Huffman ডিকোডারসহ) (`utso/crypto/`, `utso/net/`)।
- **WAL-ভিত্তিক রিলেশনাল স্টোরেজ ও টুলচেইন**: CRC-32 `fsync` WAL-সহ SQL ইঞ্জিন (`BEGIN`/`COMMIT`/`ROLLBACK` ACID ট্রানজ্যাকশন, সেকেন্ডারি হ্যাশ ইনডেক্স, `INNER`/`LEFT` হ্যাশ জয়েন ও `GROUP BY` অ্যাগ্রিগেশন — `aati/lipi_sql/`) এবং থ্রেড-সেফ জব কিউ (`aati/lipi_web/`), সাথে CLI (`lipi`), Ed25519 প্যাকেজ ম্যানেজার (`aati`), ফরম্যাটার (`lipifmt`), LSP (`lipilsp`), ডিবাগার (`lipidbg`), ডক জেনারেটর (`lipidoc`), REPL (`lipirepl`) ও ELF ইন্সপেক্টর (`lipi_akhara`)।

## উদাহরণ

বাংলা সিনট্যাক্স:

```lipi
ফাংশন ফ্যাক্টোরিয়াল সংখ্যা
    যদি সংখ্যা <= ১
        ফেরত ১
    ফেরত সংখ্যা * ফ্যাক্টোরিয়াল(সংখ্যা - ১)

ফাংশন প্রধান
    বলো "৫! = " + to_str(ফ্যাক্টোরিয়াল(৫))
    ফেরত ০

প্রধান()
```

ইংরেজি সিনট্যাক্স:

```lipi
fn factorial n
    if n <= 1
        return 1
    return n * factorial(n - 1)

fn main
    say "5! = " + to_str(factorial(5))
    return 0

main()
```

কম্পাইল ও রান:

```bash
./bin/lipc hello.lp -o hello
./hello

# অথবা একীভূত CLI দিয়ে সরাসরি রান করুন
./bin/lipi run hello.lp
```

## সোর্স থেকে বিল্ড

Linux x86_64-এ বিল্ড করতে কোনো C কম্পাইলার, Python বা LLVM প্রয়োজন নেই।

```bash
git clone https://github.com/asaudola-cmyk/LiPi_Lang.git
cd LiPi_Lang
make
```

### টেস্ট ও ভেরিফিকেশন

```bash
# পূর্ণ রিগ্রেশন টেস্ট স্যুট (২৭৪টি টেস্ট)
./bin/lipi test

# ৩১টি aati/ প্যাকেজের Ed25519 সিগনেচার ও লকফাইল যাচাই
./bin/aati verify-lock aati.lock
```

### ইনস্টল

Linux / macOS:

```bash
./install.sh
```

Windows (PowerShell):

```powershell
.\install.ps1
```

## রিপোজিটরি কাঠামো

```text
LiPi_Lang/
├── src/            # বুটস্ট্র্যাপ সিড, কম্পাইলার, রানটাইম, টুলকিট ও CLI টুলস
├── utso/           # কোর স্ট্যান্ডার্ড লাইব্রেরি (syscalls, memory, io, crypto, net, cpu, os)
├── aati/           # ৩১টি স্বাক্ষরিত প্যাকেজ (aati.toml ও aati.lock দ্রষ্টব্য)
├── tests/          # ২৭৪টি রিগ্রেশন টেস্ট (tests/run_tests.lp)
├── examples/       # রানযোগ্য উদাহরণ প্রোগ্রাম
├── benchmarks/     # বেঞ্চমার্ক হারনেস ও ক্রস-ল্যাঙ্গুয়েজ রেফারেন্স
├── editors/vscode/ # VS Code এক্সটেনশন (TextMate গ্রামার, স্নিপেট, LSP ক্লায়েন্ট)
├── scripts/        # ভেরিফিকেশন স্ক্রিপ্ট
└── docs/           # টেকনিক্যাল ডকুমেন্টেশন
```

## বেঞ্চমার্ক

নিজের মেশিনে সরাসরি মাপতে `./bin/lipi bench --quick` চালান। লিপি কম্পাইল-টাইম অ্যালজেব্রিক কনস্ট্যান্ট ফোল্ডিং (**Tier I**) এবং রানটাইম-সিডেড আনফোল্ডেবল ওয়ার্কলোড (**Tier II**) আলাদাভাবে পরিমাপ করে।

নমুনা পরিমাপ (`./bin/lipi bench --quick`, Linux x86_64):

| ওয়ার্কলোড | ধরন | ফলাফল |
|---|---|---|
| Dynamic Xorshift64\* (১০ লক্ষ ইটারেশন, রানটাইম সিড) | Tier II (কম্পিউট) | `1,879 µs` (`531 M ops/s`, ~7 cycles/op) |
| Dynamic 64 KiB Slab Scan (১ MiB) | Tier II (মেমরি ব্যান্ডউইথ) | `205 µs` (`5,112 MB/s`) |
| Segregated Slab Alloc/Free (৫০ হাজার পেয়ার) | Tier II (অ্যালোকেটর) | `352 µs` (`7 ns/pair`, `0 B` heap delta) |
| Inline Integer Equality Branch (১০ লক্ষ ইটারেশন) | Tier II (কন্ট্রোল ফ্লো) | `1,302 µs` (`767 M ops/s`) |
| Constant 10M Modulo Loop Fold (`O(N)` → `O(1)`) | Tier I (কম্পাইল-টাইম ফোল্ড) | `650 ns` (`84 cycles`) |

বিস্তারিত জানতে [docs/BENCHMARKS.md](docs/BENCHMARKS.md) দেখুন।

## VS Code এক্সটেনশন

এক্সটেনশনের সোর্স কোড এই রিপোজিটরির [editors/vscode/](editors/vscode/) ডিরেক্টরিতে রয়েছে:

```bash
make
code --install-extension dist/lipi-language-1.0.1.vsix
```

ম্যানুয়াল ইনস্টলেশনের জন্য [editors/vscode/README.md](editors/vscode/README.md) দেখুন।

## ডকুমেন্টেশন

- [আর্কিটেকচার (Architecture)](docs/ARCHITECTURE.md)
- [ভাষা গাইড (Language Guide)](docs/LANGUAGE_GUIDE.md)
- [স্ট্যান্ডার্ড লাইব্রেরি রেফারেন্স (Standard Library)](docs/STANDARD_LIBRARY.md)
- [বেঞ্চমার্ক (Benchmarks)](docs/BENCHMARKS.md)
- [চেঞ্জলগ (Changelog)](docs/CHANGELOG.md)
- [উদাহরণসমূহ (Examples)](examples/README.md)
- [কন্ট্রিবিউটিং গাইড](.github/CONTRIBUTING.md) ও [সিকিউরিটি পলিসি](.github/SECURITY.md)

## লাইসেন্স

MIT License — বিস্তারিত [LICENSE](LICENSE) ফাইলে।
