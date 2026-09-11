# মায়া (Maya) প্রোগ্রামিং ভাষা ইকোসিস্টেমের চূড়ান্ত স্থাপত্য ও ফরেনসিক নিরীক্ষা প্রতিবেদন
**নথি পরিচিতি**: `MAYA-FINAL-BLUEPRINT-AUDIT-BN-2026`  
**তারিখ**: ১ সেপ্টেম্বর, ২০২৬  
**লেখক / নিরীক্ষক**: সিনিয়র সিস্টেমস আর্কিটেক্ট ও টেকনিক্যাল রাইটার (Senior Systems Architect & Technical Writer)  
**বিষয়বস্তু**: মায়া কোডবেসের সার্বিক সাবসিস্টেম পর্যালোচনা, সাম্প্রতিক ১২ ঘণ্টার ফিক্সের ফরেনসিক নিরীক্ষা, অবশিষ্ট ব্লুপ্রিন্ট/স্টাব ক্যাটালগ, নিরাপত্তা দুর্বলতা এবং প্রধান স্থপতির অগ্রাধিকার রোডম্যাপ।  
**লক্ষ্য ফাইল**: `/home/shafiullah/Documents/file/maya/maya_final_blueprint_audit_bn.md`  

---

## সূচিপত্র (Table of Contents)
1. [১. নির্বাহী সারসংক্ষেপ (Executive Summary)](#১-নির্বাহী-সারসংক্ষেপ-executive-summary)
   - [১.১ সার্বিক আর্কিটেকচারাল মূল্যায়ন](#১১-সার্বিক-আর্কিটেকচারাল-মূল্যায়ন)
   - [১.২ বাস্তবায়িত পূর্ণাঙ্গ বনাম ব্লুপ্রিন্ট/স্টাব মডিউলের পরিসংখ্যান](#১২-বাস্তবায়িত-পূর্ণাঙ্গ-বনাম-ব্লুপ্রিন্টস্টাব-মডিউলের-পরিসংখ্যান)
   - [১.৩ সাম্প্রতিক ১২ ঘণ্টার জটিল ফিক্সসমূহের ফলাফল](#১৩-সাম্প্রতিক-১২-ঘণ্টার-জটিল-ফিক্সসমূহের-ফলাফল)
2. [২. সাম্প্রতিক ১২ ঘণ্টার জটিল ফিক্সসমূহের ফরেনসিক নিরীক্ষা (Forensic Audit of 5 Recent Fixes)](#২-সাম্প্রতিক-১২-ঘণ্টার-জটিল-ফিক্সসমূহের-ফরেনসিক-নিরীক্ষা-forensic-audit-of-5-recent-fixes)
   - [২.১ PLONK ZKP (`universe/crypto/plonk.maya`) — [PARTIAL_STUB]](#২১-plonk-zkp-universecryptoplonkmaya--partial_stub)
   - [২.২ Ed25519 Math (`universe/crypto/ed25519.maya`) — [CLEAN - 100% Production Ready]](#২২-ed25519-math-universecryptoed25519maya--clean---100-production-ready)
   - [২.৩ GC Mark-and-Sweep (`runtime/maya_gc.c`) — [CLEAN - 100% Production Ready]](#২৩-gc-mark-and-sweep-runtimemaya_gcc--clean---100-production-ready)
   - [২.৪ Omni-Binary APE Trampoline (`compiler/backend/omni_binary.maya`) — [PARTIAL_STUB]](#২৪-omni-binary-ape-trampoline-compilerbackendomni_binarymaya--partial_stub)
   - [২.৫ io_uring Syscalls (`universe/io/uring.maya`) — [PARTIAL_STUB]](#২৫-io_uring-syscalls-universeiouringmaya--partial_stub)
3. [৩. সাবসিস্টেম-ভিত্তিক পুঙ্খানুপুঙ্খ নিরীক্ষা (Subsystem-by-Subsystem Deep Audit)](#৩-সাবসিস্টেম-ভিত্তিক-পুঙ্খানুপুঙ্খ-নিরীক্ষা-subsystem-by-subsystem-deep-audit)
   - [৩.১ কম্পাইলার সাবসিস্টেম (Compiler)](#৩১-কম্পাইলার-সাবসিস্টেম-compiler)
   - [৩.২ অপারেটিং সিস্টেম সাবসিস্টেম (OS)](#৩২-অপারেটিং-সিস্টেম-সাবসিস্টেম-os)
   - [৩.৩ নেটওয়ার্ক সাবসিস্টেম (Net)](#৩৩-নেটওয়ার্ক-সাবসিস্টেম-net)
   - [৩.৪ কৃত্রিম বুদ্ধিমত্তা ও মেশিন লার্নিং সাবসিস্টেম (AI & ML)](#৩৪-কৃত্রিম-বুদ্ধিমত্তা-ও-মেশিন-লার্নিং-সাবসিস্টেম-ai--ml)
   - [৩.৫ ক্রিপ্টোগ্রাফি সাবসিস্টেম (Crypto)](#৩৫-ক্রিপ্টোগ্রাফি-সাবসিস্টেম-crypto)
   - [৩.৬ মোবাইল সাবসিস্টেম (Mobile: Android & iOS)](#৩৬-মোবাইল-সাবসিস্টেম-mobile-android--ios)
   - [৩.৭ আইওটি ও এমবেডেড সাবসিস্টেম (IoT & Bare-Metal)](#৩৭-আইওটি-ও-এমবেডেড-সাবসিস্টেম-iot--bare-metal)
   - [৩.৮ ওয়েব ও ওয়াসম সাবসিস্টেম (Web & WASM)](#৩৮-ওয়েব-ও-ওয়াসম-সাবসিস্টেম-web--wasm)
4. [৪. অবশিষ্ট ব্লুপ্রিন্ট, স্টাব ও মকসমূহের পুঙ্খানুপুঙ্খ মাস্টার ক্যাটালগ (Master Blueprint/Stub Inventory)](#৪-অবশিষ্ট-ব্লুপ্রিন্ট-স্টাব-ও-মকসমূহের-পুঙ্খানুপুঙ্খ-মাস্টার-ক্যাটালগ-master-blueprintstub-inventory)
5. [৫. ক্রিটিক্যাল নিরাপত্তা ঝুঁকি ও স্থাপত্যগত দুর্বলতা (Critical Security Vulnerabilities)](#৫-ক্রিটিক্যাল-নিরাপত্তা-ঝুঁকি-ও-স্থাপত্যগত-দুর্বলতা-critical-security-vulnerabilities)
6. [৬. প্রধান স্থপতির জন্য বাস্তবায়ন রোডম্যাপ ও অগ্রাধিকার তালিকা (Lead Architect's Roadmap)](#৬-প্রধান-স্থপতির-জন্য-বাস্তবায়ন-রোডম্যাপ-ও-অগ্রাধিকার-তালিকা-lead-architects-roadmap)
7. [৭. স্বাধীন পুনরুৎপাদন ও যাচাইকরণ কমান্ড (Independent Verification Commands)](#৭-স্বাধীন-পুনরুৎপাদন-ও-যাচাইকরণ-কমান্ড-independent-verification-commands)

---

## ১. নির্বাহী সারসংক্ষেপ (Executive Summary)

### ১.১ সার্বিক আর্কিটেকচারাল মূল্যায়ন
মায়া (Maya) একটি উচ্চাভিলাষী, স্বাধীন এবং বহু-স্তরবিশিষ্ট (Multi-Tier) সিস্টেম প্রোগ্রামিং ভাষা ইকোসিস্টেম। এই প্ল্যাটফর্মটি হোস্ট অপারেটিং সিস্টেম ও কোনো বাহ্যিক থার্ড-পার্টি সি/সি++ লাইব্রেরি (`libc`, OpenSSL, PyTorch ইত্যাদি) নির্ভরতা ছাড়াই নিজস্ব কম্পাইলার, কার্নেল ইন্টারফেস, ক্রিপ্টোগ্রাফিক ইঞ্জিন, এন-ডাইমেনশনাল টেনসর ও অটো-ডিফারেনসিয়েশন এবং নেটওয়ার্ক প্রোটোকল স্ট্যাক বাস্তবায়নের লক্ষ্যে ডিজাইন করা হয়েছে।

সার্বিক কোডবেস নিরীক্ষায় প্রতীয়মান হয় যে, ভাষার কোর ইঞ্জিন (Core Engine), মেমোরি ম্যানেজমেন্ট, নেটওয়ার্কের নিম্ন-স্তর এবং গাণিতিক ক্রিপ্টোগ্রাফির অধিকাংশ অংশ **অত্যন্ত উন্নত ও উৎপাদন-উপযোগী (Production-Ready)**। বিশেষ করে পিওর মায়া ভাষায় রচিত লেক্সার, পার্সার, টাইপচেকার, SSA ইন্টারমিডিয়েট রিপ্রেজেন্টেশন (MIR), x86_64/ARM64/Mach-O বাইনারি এমিটার, RFC 8032 Ed25519 উপবৃত্তীয় বক্ররেখা (Elliptic Curve), এবং সি-রানটাইমে নির্মিত সেগ্রেগেটেড স্ল্যাব মার্ক-অ্যান্ড-সুইপ গার্বেজ কালেক্টর (GC) আন্তর্জাতিক মানের।

তবে প্ল্যাটফর্মটির প্রান্তিক (Edge) সাবসিস্টেমগুলোতে—বিশেষ করে মোবাইল (Android/iOS), এমবেডেড বেয়ার-মেটাল হার্ডওয়্যার ইন্টারফেস (HAL), ওয়েবঅ্যাসেম্বলি লিঙ্কার লোয়ারিং এবং কার্নেল-বাইপাস রিং বাফারে—বেশ কিছু আর্কিটেকচারাল ব্লুপ্রিন্ট (Blueprint), মক ডাটা কাঠামো এবং ইউজারল্যান্ড সিমুলেশন বিদ্যমান রয়েছে যা হার্ডওয়্যার বা ওএস লেভেলে সংযুক্ত নয়।

---

### ১.২ বাস্তবায়িত পূর্ণাঙ্গ বনাম ব্লুপ্রিন্ট/স্টাব মডিউলের পরিসংখ্যান

সমগ্র মায়া ইকোসিস্টেমের ৮টি প্রধান সাবসিস্টেমের পুঙ্খানুপুঙ্খ নিরীক্ষার সারসংক্ষেপ নিম্নরূপ:

| সাবসিস্টেম (Subsystem) | মোট নিরীক্ষিত ফাইল | পূর্ণাঙ্গ বাস্তবায়িত মডিউল (Production-Ready) | আংশিক / ব্লুপ্রিন্ট / স্টাব (Blueprint/Stubs) | বাস্তবায়ন পরিপক্বতা (Maturity %) | প্রধান শক্তি ও অবশিষ্ট সীমাবদ্ধতা |
|---|:---:|:---:|:---:|:---:|---|
| **১. কম্পাইলার (Compiler)** | ৪৫+ | ৪০ | ৫ | **৮৮%** | C++17/LLVM বুটস্ট্র্যাপ ও Pure Maya v2 স্বাগতিক কম্পাইলার পূর্ণাঙ্গ; APE ট্রাম্পোলিন ও Generational RBP স্টাব। |
| **২. অপারেটিং সিস্টেম (OS)** | ৩৫+ | ২৫ | ১০ | **৭০%** | পিওর অ্যাসেম্বলি ডিরেক্ট সিসকল, স্ল্যাব GC, আইডিটি ও পেজিং পূর্ণাঙ্গ; `process_spawn`, `path_*`, এবং ডিস্ক ড্রাইভারে স্টাব বিদ্যমান। |
| **৩. নেটওয়ার্ক (Net)** | ৩০+ | ২২ | ৮ | **৭২%** | লেয়ার ২-৪ পিওর প্রোটোকল স্ট্যাক, TCP/UDP, HTTP/1.1, HTTP/2 HPACK, QUIC, WebSocket পূর্ণাঙ্গ; DNS অ্যান্সার, TLS রেকর্ডে স্টাব। |
| **৪. এআই ও মেশিন লার্নিং (AI/ML)** | ২৫+ | ২০ | ৫ | **৮০%** | N-D টেনসর, রিভার্স অটোগ্র্যাড DAG, Vision CNN `im2col`, ONNX প্রোটোবাফ, AMX/AVX-512 GEMM পূর্ণাঙ্গ; স্যাম্পলিং ও GPU ড্রাইভার সিমুলেটেড। |
| **৫. ক্রিপ্টোগ্রাফি (Crypto)** | ২০+ | ১৬ | ৪ | **৮০%** | RFC 8032 Ed25519, BN254 টাওয়ার ও KZG পেয়ারিং, ফাস্ট RSA, AES FIPS 197 পূর্ণাঙ্গ; Core Secp256k1 ঝুঁকিপূর্ণ, PLONK পারমুটেশন অসম্পূর্ণ। |
| **৬. মোবাইল (Mobile)** | ৮ | ২ | ৬ | **২৫%** | এলাইনড জিপ APK প্যাকেজিং কাঠামো সঠিক; ডালভিক DEX, `.so` মেশিন কোড ও iOS সম্পূর্ণ স্কেলিটন/ব্লুপ্রিন্ট। |
| **৭. আইওটি ও এমবেডেড (IoT)** | ১৫ | ৪ | ১১ | **২৫%** | কর্টেক্স-এম IVT ও ২-ফিঙ্গার কমপ্যাকশন অ্যালগরিদম উপস্থিত; কিন্তু GPIO/I2C/SPI হার্ডওয়্যার রেজিস্টার ও ESP32/AVR অনুপস্থিত। |
| **৮. ওয়েব ও ওয়াসম (Web/WASM)** | ২০ | ৮ | ১২ | **৪০%** | WASM বাইনারি সেকশন এনকোডার ও DOM-Bypass ক্যানভাস ইঞ্জিন উপস্থিত; WASM লিঙ্করে ডামি IR ও JS ব্রিজে কনসোল স্টাব। |

---

### ১.৩ সাম্প্রতিক ১২ ঘণ্টার জটিল ফিক্সসমূহের ফলাফল

গত ১২ ঘণ্টায় টিম কর্তৃক সমাধানকৃত ৫টি জটিল সিস্টেমের ফরেনসিক পরীক্ষার ফলাফল:

```
+-------------------------------------------------------------------------------------------------------+
|                              সাম্প্রতিক ১২ ঘণ্টার ৫টি ফিক্সের নিরীক্ষা স্কোরকার্ড                        |
+-------------------------------------------------------------------------------------------------------+
| ১. Ed25519 Math       | universe/crypto/ed25519.maya      | CLEAN (100% Production Ready)             |
| ২. GC Mark-and-Sweep  | runtime/maya_gc.c                 | CLEAN (100% Production Ready)             |
| ৩. PLONK ZKP          | universe/crypto/plonk.maya        | PARTIAL_STUB (ফিল্ড টাওয়ার ও KZG আসল)      |
| ৪. Omni-Binary APE    | compiler/backend/omni_binary.maya | PARTIAL_STUB (হেডার উপস্থিত, ট্রাম্পোলিন স্টাব) |
| ৫. io_uring Syscalls  | universe/io/uring.maya            | PARTIAL_STUB (সিসকল আসল, রিং হার্ভেস্টিং নকল) |
+-------------------------------------------------------------------------------------------------------+
```

---

## ২. সাম্প্রতিক ১২ ঘণ্টার জটিল ফিক্সসমূহের ফরেনসিক নিরীক্ষা (Forensic Audit of 5 Recent Fixes)

---

### ২.১ PLONK ZKP (`universe/crypto/plonk.maya`) — [PARTIAL_STUB]

#### ক. যা বাস্তবায়িত এবং গাণিতিকভাবে নির্ভুল:
1. **BN254 ফিল্ড টাওয়ার এরিথমেটিক (Field Tower Arithmetic $\mathbb{F}_p \to \mathbb{F}_{p^2} \to \mathbb{F}_{p^6} \to \mathbb{F}_{p^{12}}$)**:
   - বেস ফিল্ড $\mathbb{F}_p$: ফার্মার লিটল থিওরেম ($a^{p-2} \pmod p$) দ্বারা মাল্টিপ্লিকেটিভ ইনভার্সন (`fp_inv`, লাইন ১০০–১১৪)।
   - দ্বিঘাত এক্সটেনশন $\mathbb{F}_{p^2} = \mathbb{F}_p[i] / (i^2 + 1)$: $(a_0 + a_1 i)(b_0 + b_1 i) = (a_0 b_0 - a_1 b_1) + (a_0 b_1 + a_1 b_0) i$ (`fp2_mul`, লাইন ১৩৭–১৪২)।
   - ষড়ঘাত এক্সটেনশন $\mathbb{F}_{p^6} = \mathbb{F}_{p^2}[v] / (v^3 - \xi)$ যেখানে $\xi = 1 + i$ (`fp6_mul`, লাইন ১৮৩–১৯৮)।
   - দ্বাদশঘাত এক্সটেনশন $\mathbb{F}_{p^{12}} = \mathbb{F}_{p^6}[w] / (w^2 - v)$ (`fp12_mul`, লাইন ২২৮–২৩৬)।
2. **উপবৃত্তীয় বক্ররেখা ও মিলার লুপ (Miller Loop & KZG Pairing)**:
   - $G_1$ কার্ভ ($y^2 = x^3 + 3 \pmod p$) এবং $G_2$ কার্ভের ওপর কমপ্লিট পয়েন্ট অ্যাডিশন ও ডাবলিং।
   - KZG পলিনোমিয়াল কমিটমেন্ট $C = \sum_{i=0}^d c_i [\tau^i]_1$ (`kzg_commit_polynomial`, লাইন ৪৭১–৪৯৭)।
   - ওপেনিং প্রুফ কোশেন্ট $q(X) = \frac{P(X) - v}{X - z}$ সিন্থেটিক ডিভিশন (রুফিনি নিয়ম) দ্বারা গণনা (`kzg_create_opening_proof`, লাইন ৪৯৯–৫৩৭)।
   - পেয়ারিং সমীকরণ $e(W, [\tau - z]_2) = e(C - v[1]_1, [1]_2)$ এর খাঁটি বাস্তবায়ন (`kzg_verify`, লাইন ৫৩৯–৫৫৬)।

#### খ. যা অনুপস্থিত ও স্টাব (Why PARTIAL_STUB):
1. **কপি কনস্ট্রেইন্ট ও পারমুটেশন আর্গুমেন্ট (Grand Product Permutation Accumulator $z(X)$ অনুপস্থিত)**:
   PLONK-এর প্রাণকেন্দ্র হলো গ্র্যান্ড প্রোডাক্ট পারমুটেশন:
   $$z(\omega X) = z(X) \cdot \frac{(w_a(X) + \beta X + \gamma)(w_b(X) + \beta k_1 X + \gamma)(w_c(X) + \beta k_2 X + \gamma)}{(w_a(X) + \beta \sigma_1(X) + \gamma)(w_b(X) + \beta \sigma_2(X) + \gamma)(w_c(X) + \beta \sigma_3(X) + \gamma)}$$
   কোডবেসে ওয়্যার সমূহের মধ্যে পারমুটেশন $\sigma_1, \sigma_2, \sigma_3$ এবং $z(X)$ পলিনোমিয়াল অনুপস্থিত। শুধুমাত্র একক আইসোলেটেড গেট সমীকরণ ($q_L a + q_R b + q_O c + q_M ab + q_C \equiv 0$) যাচাই করা হয় (`plonk_verify_gate`, লাইন ৪৩২–৪৪৬)।
2. **ভ্যানিশিং পলিনোমিয়াল ও স্প্লিট কোশেন্ট পলিনোমিয়াল অনুপস্থিত**:
   সাবগ্রুপ ডোমেইনে $Z_H(X) = X^n - 1$ দ্বারা ভাগ এবং $t(X)$ কে $t_{lo}, t_{mid}, t_{hi}$ অংশে বিভক্ত করার কোনো মেকানিজম নেই।
3. **হার্ডকোডেড টেস্ট প্রুফ কনস্ট্রাকশন**:
   `plonk_create_recursive_proof` (লাইন ৫৫৮–৫৭৭) ফাংশনে ফিক্সড পলিনোমিয়াল কোএফিসিয়েন্ট `coeffs = [5, 2, 3]` ($P(X) = 3X^2 + 2X + 5$), ফিক্সড ইভ্যালুয়েশন পয়েন্ট $z=4, v=61$, এবং ফিক্সড সাইজ `proof_size_bytes: 840` হার্ডকোড করা রয়েছে।
4. **পেয়ারিং-এ ফাইনাল এক্সপোনেনশিয়েশন অনুপস্থিত**:
   `ate_pairing` (লাইন ৪২৪) শুধুমাত্র `miller_loop` কল করে কিন্তু চূড়ান্ত এক্সপোনেনশিয়েশন $f^{(p^{12}-1)/r}$ সম্পন্ন করে না।
5. **R1CS প্রুভারে গাণিতিক টাউটোলজি (`universe/crypto/zkp.maya:112-117`)**:
   প্রুভার $h = (A \cdot B - C) \pmod p$ সংজ্ঞায়িত করে এবং ভেরিফায়ার $A \cdot B \equiv C + h \pmod p$ চেক করে, যা কোনো গাণিতিক প্রুফ গঠন করে না বরং স্বতঃসিদ্ধ সমীকরণ।

---

### ২.২ Ed25519 Math (`universe/crypto/ed25519.maya`) — [CLEAN - 100% Production Ready]

#### ক. গাণিতিক ও প্রযুক্তিগত বাস্তবায়ন:
1. **$\mathbb{F}_{2^{255}-19}$ ফিল্ড এরিথমেটিক (16-Limb Radix-16 Representation)**:
   - প্রতিটি ২৫৬-বিট ফিল্ড এলিমেন্ট ১৬টি ১৬-বিট আনসাইন্ড ইন্টিজার লিম্বে সংরক্ষিত ($\sum_{i=0}^{15} c_i \cdot 2^{16i}$)।
   - ক্যারি প্রপাগেশন এবং মডুলার রিডাকশন (`fe_normalize`, লাইন ৯৬–১৬৯): $2^{255} \equiv 19 \pmod p$ এবং $2^{256} \equiv 38 \pmod p$ সমতা ব্যবহার করে শীর্ষ লিম্ব ১৫-এর ওভারফ্লো $c_{15} \ge 2^{15}$ কে $carry \cdot 38 + top\_bit \cdot 19$ আকারে লিম্ব ০-এ ফোল্ড করা হয়।
   - গুণন (`fe_mul`, লাইন ১৯৬–২৩৮): ৩২-লিম্ব কনভোলিউশন $\sum_{i+j=k} a_i b_j$ সম্পন্ন করে উচ্চ ১৬টি লিম্বকে $prod_{i+16} \cdot 38$ দ্বারা রিডিউস করা হয় এবং অবশিষ্ট ক্যারিকে $carry \cdot 1444$ ($1444 = 38^2 \equiv 2^{512} \pmod p$) দ্বারা সমন্বয় করা হয়।
   - মাল্টিপ্লিকেটিভ ইনভার্সন (`fe_inv`, লাইন ২৭৯–২৮৪): ফার্মার লিটল থিওরেম $a^{2^{255}-21} \pmod p$ সঠিক স্কয়ার-অ্যান্ড-মাল্টিপ্লাই লিম্ব চেইন দ্বারা বাস্তবায়িত।
2. **টুইস্টেড এডওয়ার্ডস এক্সটেন্ডেড প্রজেক্টিভ কোঅর্ডিনেট $(X:Y:Z:T)$**:
   - কার্ভ সমীকরণ: $-x^2 + y^2 = 1 + d x^2 y^2$ যেখানে $d = -\frac{121665}{121666} \pmod p$।
   - প্রজেক্টিভ রূপান্তর: $x = X/Z, y = Y/Z, x y = T/Z$।
   - কমপ্লিট পয়েন্ট অ্যাডিশন (RFC 8032 Section 5.1.4) এবং ডেডিকেটেড ডাবলিং ফর্মুলা (`ed25519_point_add` ও `ed25519_point_double`, লাইন ৫১৩–৫৬৩)।
3. **প্রাইম অর্ডার $L$ রিডাকশন ও ক্যানোনিকাল এনফোর্সমেন্ট**:
   - প্রাইম অর্ডার $L = 2^{252} + 27742317777372353535851937790883648493$।
   - `scalar_mod_l` (লাইন ৩২৫–৩৯৪): ৫১২-বিট ইনপুটের ওপর খাঁটি শিফট-অ্যান্ড-সাবট্র্যাক্ট বাইনারি লং ডিভিশন অ্যালগরিদম।
   - `scalar_is_less_than_l` (লাইন ৩১০–৩২৩): জালিয়াতি রোধে নন-ক্যানোনিকাল $S \ge L$ স্বাক্ষর কঠোরভাবে বাতিল করে। বেস পয়েন্ট অ্যানিহিলেশন $[L]B = \mathcal{O}$ গাণিতিকভাবে সত্য প্রমাণিত।
4. **RFC 8032 সিগনেচার অ্যালগরিদম**:
   - কি-জেনারেট: $h = \text{SHA-512}(seed)$, ক্ল্যাম্পিং (বিট ০,১,২ ক্লিয়ার, বিট ২৫৪ সেট, বিট ২৫৫ ক্লিয়ার), $A = [s]B$।
   - সাইন: $r = \text{SHA-512}(h_{32..63} \parallel M) \pmod L$, $R = [r]B$, $k = \text{SHA-512}(R \parallel A \parallel M) \pmod L$, $S = (r + k \cdot s) \pmod L$।
   - ভেরিফাই: $[S]B = R + [k]A$ প্রজেক্টিভ সমতা $X_1 Z_2 = X_2 Z_1$ এবং $Y_1 Z_2 = Y_2 Z_1$ দ্বারা যাচাইকৃত।
5. **ভেরিফিকেশন ফলাফল**:
   - RFC 8032 টেস্ট ভেক্টর ১, ২, ৩, ৪, ৫ হুবহু বিট-টু-বিট পাস।
   - ৬৪-পজিশন বিট-ফ্লিপ ম্যাট্রিক্সে ৬৪টি জাল স্বাক্ষরই বাতিল হয়েছে।

---

### ২.৩ GC Mark-and-Sweep (`runtime/maya_gc.c`) — [CLEAN - 100% Production Ready]

```
+------------------------------------------------------------------------------------+
|                         মায়া রানটাইম গার্বেজ কালেক্টর আর্কিটেকচার                     |
+------------------------------------------------------------------------------------+
| ১. স্ল্যাব অ্যালোকেটর (বস্তু <= ২০৪৮ বাইট):                                         |
|    - ৬৪KB mmap এরিনা (MAP_PRIVATE | MAP_ANONYMOUS)                                 |
|    - ৮টি সাইজ ক্লাস: ১৬, ৩২, ৬৪, ১২৮, ২৫৬, ৫১২, ১০২৪, ২০৪৮ বাইট                     |
|    - থ্রেড-সেফ LIFO ফ্রি-লিস্ট (g_free_lists[1..8])                                |
|    - ১৬ বাইট অবজেক্ট হেডার { size, size_class, flags, gc_color, magic, type_id }    |
+------------------------------------------------------------------------------------+
| ২. লার্জ অবজেক্ট অ্যালোকেটর (বস্তু > ২০৪৮ বাইট):                                     |
|    - ডিরেক্ট পেজ-অ্যালাইনড mmap এবং সর্টেড মেটাডাটা রেজিস্ট্রি (g_large_chunks)        |
+------------------------------------------------------------------------------------+
| ৩. রুট স্ক্যানিং ও ট্রাভার্সাল (Root Scanning & Tracing):                           |
|    - setjmp(jb) দ্বারা ক্যালার-সেভড রেজিস্টার (%rbx, %rsp, %rbp, %r12-%r15) স্ট্যাকে ফ্ল্যাশ|
|    - pthread_getattr_np / pthread_attr_getstack দ্বারা গতিশীল স্ট্যাক বাউন্ডারি নির্ণয় |
|    - কনজারভেটিভ স্ট্যাক স্ক্যানার: ৮-বাইট অ্যালাইনড ওয়ার্ড ট্রাভার্সাল                  |
|    - gc_base_locked(): এরিনা ও লার্জ চাঙ্কে বাইনারি সার্চ ও 0x4D415941 ম্যাজিক চেক   |
|    - ওয়ার্কলিস্ট ট্রানজিটিভ মার্ক ফেজ: সাইকেল হ্যান্ডলিং সহ অবজেক্ট গ্রাফ ট্রাভার্সাল |
+------------------------------------------------------------------------------------+
| ৪. সুইপ ও মেমোরি রিক্লেমেশন (Sweep & Reclamation):                                 |
|    - স্ল্যাব এরিনা: মৃত স্লট শনাক্ত করে ফ্রি-লিস্ট পুনর্নির্মাণ                         |
|    - লার্জ চাঙ্ক: unreferenced অবজেক্টের ওপর সরাসরি munmap() আহ্বান                |
|    - অটো-ট্রিগার: হিপের ধারণক্ষমতার >= ৮৫% মেমোরি বরাদ্দ হলেই স্বয়ংক্রিয় GC রান হয়   |
+------------------------------------------------------------------------------------+
```

#### বাস্তবায়ন যাচাইকরণ:
- পয়েন্টার ইন্ট্রোস্পেকশন: `gc_base` স্ট্যাক/নাল/বহিরাগত পয়েন্টার সম্পূর্ণ নির্ভুলভাবে ফিল্টার করে।
- টাইপ ট্যাগিং: `type_id` (`TYPE_RAW_BYTES`, `TYPE_MAYA_STRING`, `TYPE_MAYA_ARRAY`, `TYPE_MAYA_STRUCT` ইত্যাদি) প্রয়োগের ফলে ফলস-পজিটিভ ট্রাভার্সাল দূরীভূত হয়েছে।
- স্ট্রেস টেস্ট: ১৬টি কনকারেন্ট থ্রেডে ৮০,০০০ অ্যালোকেশন/ডিঅ্যালোকেশন এবং ১,০০০ লার্জ অবজেক্ট `mmap`/`munmap` সাইকেলে শূন্য মেমোরি লিক এবং শূন্য ক্র্যাশ পরিলক্ষিত হয়েছে।

---

### ২.৪ Omni-Binary APE Trampoline (`compiler/backend/omni_binary.maya`) — [PARTIAL_STUB]

#### ক. যা বাস্তবায়িত:
`compiler/backend/omni_binary.maya` (লাইন ১২০–১৯৯)-এ কসমোপলিটান পলিগ্লট বাইনারি হেডার অফসেটগুলো সঠিকভাবে সাজানো হয়েছে:
- অফসেট `0x00..0x3B` (৬০ বাইট): ডস/শেল ট্রাম্পোলিন স্ট্রিং `"MZqFpD='\n'\nexit 0\n"`।
- অফসেট `0x3C..0x3F` (৪ বাইট): `e_lfanew` পয়েন্টার যা `0x100` (PE হেডার) নির্দেশ করে।
- অফসেট `0x40..0x7F` (৬৪ বাইট): ELF64 হেডার (`\x7fELF\x02\x01\x01\x00`)।
- অফসেট `0x80..0xFF` (১২৮ বাইট): Mach-O 64-বিট হেডার (`\xCF\xFA\xED\xFE`)।
- অফসেট `0x100` (২৫৬ বাইট): উইন্ডোজ PE হেডার (`PE\0\0`)।

#### খ. যা অসম্পূর্ণ ও স্টাব (Why PARTIAL_STUB):
1. **শেল স্ক্রিপ্ট ট্রাম্পোলিন ফেইলিউর**:
   বাইনারিটি শেল স্ক্রিপ্ট হিসেবে চালালে (`/bin/sh`) এটি অবিলম্বে `exit 0` এক্সিকিউট করে বন্ধ হয়ে যায়; ভেতরের কোনো এক্সিকিউটেবল পেলোড রান করে না।
2. **লিনাক্স কার্নেল `execve` ব্যর্থতা (`ENOEXEC`)**:
   ফাইলটিকে সরাসরি লিনাক্স কার্নেলের মাধ্যমে `execve` সিসকলে এক্সিকিউট করলে কার্নেল `ENOEXEC` (Exec format error, Errno 8) প্রদান করে। কারণ অফসেট ০-তে কোনো `\x7fELF` বা `#!` নেই।
3. **নেটিভ মেশিন কোড ট্রাম্পোলিন অনুপস্থিত**:
   প্রকৃত Cosmopolitan APE ফরম্যাটে `MZqFpD='` বাইটগুলো আসলে বৈধ x86-64 মেশিন ইনস্ট্রাকশন (`pop %r10`, `jno`, `jo`) যা একটি অ্যাসেম্বলি বুটস্ট্র্যাপে জাম্প করে, হোস্ট কার্নেল ডিটেক্ট করে এবং সঠিক পেলোডে এক্সিকিউশন স্থানান্তর করে। মায়াতে এই নেটিভ অ্যাসেম্বলি ট্রাম্পোলিন অনুপস্থিত।

---

### ২.৫ io_uring Syscalls (`universe/io/uring.maya`) — [PARTIAL_STUB]

#### ক. যা বাস্তবায়িত:
- **আসল সিসকল গেটওয়ে**:
  - `sys_io_uring_setup(entries, params_ptr)` $\to$ লিনাক্স x86_64 সিসকল ৪২৫।
  - `sys_io_uring_enter(fd, to_submit, min_complete, flags, sig_ptr)` $\to$ সিসকল ৪২৬।
  - `sys_io_uring_register(fd, opcode, arg_ptr, nr_args)` $\to$ সিসকল ৪২৭।
- **মেমোরি ম্যাপড অফসেট**:
  - `IORING_OFF_SQ_RING = 0`, `IORING_OFF_CQ_RING = 134217728` (`0x8000000`), `IORING_OFF_SQES = 268435456` (`0x10000000`)।

#### খ. যা অসম্পূর্ণ ও স্টাব (Why PARTIAL_STUB):
1. **ইউজারল্যান্ড সিমুলেটেড ইভেন্ট হার্ভেস্টিং**:
   `universe/io/uring.maya` (লাইন ২১৫–২৩২)-এ `io_uring_submit_and_reap` ফাংশনে কার্নেল সিসকল ডাকা হলেও, CQE ইভেন্ট জেনারেশন কার্নেল mmap CQ রিং বাফার থেকে রিড করার বদলে ইউজারল্যান্ড অ্যারে লুপের মাধ্যমে নকল তৈরি করা হয়:
   ```maya
   res_val = sqe.nbytes
   @if sqe.opcode == 13 res_val = 100 @end
   cqe = IOUringCQE { cqe_tag: sqe.sqe_tag, res: res_val, flags: 0 }
   ring.cqes = ring.cqes.push(cqe)
   ```
2. **SQPOLL কার্নেল থ্রেড ইমুলেশন**:
   `universe/io/uring_sqpoll.maya` (লাইন ১২৭–১৪২)-এ `io_uring_sqpoll_poll_kthread` কার্নেল থ্রেডের বদলে ইউজারল্যান্ডে ম্যানুয়ালি SQE থেকে CQE কপি করে।

---

## ৩. সাবসিস্টেম-ভিত্তিক পুঙ্খানুপুঙ্খ নিরীক্ষা (Subsystem-by-Subsystem Deep Audit)

---

### ৩.১ কম্পাইলার সাবসিস্টেম (Compiler)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
1. **C++17 / LLVM 18 বুটস্ট্র্যাপ কম্পাইলার (`src/`)**:
   - `src/lexer.cpp`: ৬০টির অধিক টোকেন, ইন্ডেন্টেশন ও `@` ডিরেক্টিভ স্ক্যানার।
   - `src/parser.cpp`: ১৩টি অপারেটর প্রেসিডেন্স লেভেল বিশিষ্ট রিকার্সিভ ডিসেন্ট পার্সার।
   - `src/typecheck.cpp`: ৪-পাস হিন্ডলে-মিলনার টাইপ চেকার ও সাইক্লিক ইমপোর্ট রেজোলিউশন।
   - `src/codegen.cpp` (২,৬১৬ লাইন): LLVM 18 IR জেনারেটর, SSA PHI নোড এবং অবজেক্ট কোড এমিটার।
   - `src/lsp/`, `src/fmt/`, `src/pkg/`: ল্যাঙ্গুয়েজ সার্ভার প্রোটোকল, অটো-ফরম্যাটার এবং MPM প্যাকেজ ম্যানেজার।
2. **পিওর মায়া স্বাগতিক কম্পাইলার v2 (`compiler/`)**:
   - **ফ্রন্টএন্ড**: `compiler/frontend/lexer.maya` (৬৭৮ লাইন DFA), `parser.maya` (৯৪২ লাইন প্র্যাট পার্সার), `typecheck.maya` (১,২৫২ লাইন)।
   - **মিডলএন্ড**: `optimizer.maya` (কনস্ট্যান্ট ফোল্ডিং, ডেড কোড এলিমিনেশন, লুপ ইনভ্যারিয়েন্ট কোড মোশন), `maya_ir.maya` (SSA বেসিক ব্লক ও CFG)।
   - **ব্যাকএন্ড ও টার্গেট কোড জেনারেটর**:
     - `compiler/backend/x86_64/`: নেটিভ মেশিন কোড, AVX-512 ভেক্টর এবং Intel AMX টাইল ইনস্ট্রাকশন।
     - `compiler/backend/arm64/`: AArch64 ইনস্ট্রাকশন এনকোডিং এবং AAPCS64 কলিং কনভেনশন।
     - `compiler/backend/macho_writer.maya` (৪৭৫ লাইন): পূর্ণাঙ্গ Mach-O 64 হেডার, সেগমেন্ট ও ডিস্ক রাইটার।
     - `compiler/backend/wasm/wasm_emitter.maya` (৪০৯ লাইন): সম্পূর্ণ LEB128 বাইনারি সেকশন এমিটার।
     - `compiler/backend/jit/`: `sys_mmap(PROT_READ|PROT_WRITE|PROT_EXEC)` ভিত্তিক মেমোরি জেআইটি এক্সিকিউটর।
     - `compiler/backend/hdl/`: মায়া AST থেকে ভেরিলগ (Verilog FSM) ও AXI4 হাই-লেভেল সিন্থেসিস (HLS)।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `compiler/backend/omni_binary.maya:123-140`: APE ট্রাম্পোলিনে `exit 0\n` শেল স্ট্রিং।
- `compiler/backend/gc.maya:451-453`: জেনারেশনাল GC ব্লুপ্রিন্টে `fn get_current_rbp() -> usize { return 0; }` যা স্ট্যাক আনওয়াইন্ডিং লুপ বাইপাস করে।

---

### ৩.২ অপারেটিং সিস্টেম সাবসিস্টেম (OS)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
1. **ডিরেক্ট অ্যাসেম্বলি সিসকল লেয়ার (`universe/os/syscalls.maya`, `runtime/syscall.s`)**:
   - কোনো সি-লাইব্রেরি ছাড়াই সরাসরি কার্নেল গেটওয়ে: মেমোরি (`sys_mmap`, `sys_munmap`, `sys_mprotect`, `sys_brk`), প্রসেস (`sys_fork`, `sys_execve`, `sys_wait4`, `sys_kill`, `sys_getpid`), ফাইল ও ডিরেক্টরি (`sys_read`, `sys_write`, `sys_open`, `sys_close`, `sys_getdents64`), উন্নত আই/ও (`sys_io_uring_*`)।
2. **ফ্রি-স্ট্যান্ডিং মেমোরি ও বেয়ার-মেটাল (`universe/os/freestanding.maya`, ৫৪২ লাইন)**:
   - `#[no_os]` মোডে কাজ করার জন্য ২MB এরিনা অ্যালোকেটর এবং টু-ফিঙ্গার কম্প্যাকশন অ্যালগরিদম।
3. **ভার্চুয়াল মেমোরি ও ইন্টারাপ্ট হ্যান্ডলিং (`universe/os/drivers/memory.maya`, `idt.maya`)**:
   - PML4, PDPT, PD, PT ৪-লেভেল পেজিং ডেটা স্ট্রাকচার, বিটম্যাপ পেজ ফ্রেম অ্যালোকেটর, ৬৪-বিট IDT গেট ডেসক্রিপ্টর এবং PIC 8259A/PIT 8254 টাইমার সেটআপ।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `universe/os/process.maya:79-86`: `process_spawn` ফাংশনে ফর্ক করার পর চাইল্ড ব্রাঞ্চ `process_execve` ডাকার বদলে অবিলম্বে `process_exit(0)` এক্সিকিউট করে। ফলে চাইল্ড প্রসেস কোনো প্রোগ্রাম রান না করেই বন্ধ হয়।
- `universe/os/path.maya:5-15, 26-28`: `path_dirname`, `path_basename`, `path_ext`, `path_normalize` ফাংশনগুলো কোনো পার্সিং ছাড়াই মূল স্ট্রিং `p` হুবহু রিটার্ন করে।
- `universe/os/env.maya:61-62`: `env_home()` স্থির `"/home"` এবং `env_tmp()` স্থির `"/tmp"` রিটার্ন করে ($HOME বা $TMPDIR চেক করে না)।
- `universe/os/drivers/disk.maya:20-42, 68-82`: AHCI SATA ড্রাইভার কোনো হার্ডওয়্যার বা ব্লক ডিভাইসের সাথে যুক্ত নয়; `disk_read_sector` ৫১২টি শূন্যযুক্ত অ্যারে রিটার্ন করে এবং `disk_write_sector` কনসোলে প্রিন্ট করে ১ রিটার্ন করে।
- `universe/fs/mayafs.maya:65, 99-102`: CoW ফাইলসিস্টেমের মারকেল চেকসাম আসল কন্টেন্ট হ্যাশ না করে ফাইলের নাম ও সাইজ হ্যাশ করে।
- `runtime/async/coroutine.maya:82-98` ও `scheduler.maya:64-69`: রেজিস্টার কনটেক্সট সুইচিং ছাড়া শুধুমাত্র ইন্টিজার ফ্ল্যাগ টগল করে করুটিন সিমুলেট করা হয়।

---

### ৩.৩ নেটওয়ার্ক সাবসিস্টেম (Net)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
1. **OS-স্বাধীন পিওর লেয়ার ২-৪ স্ট্যাক (`universe/net/raw.maya`, ২,০২১ লাইন)**:
   - ইথারনেট II ফ্রেমিং, ARP টেবিল, IPv4/IPv6 প্যাকেট কনস্ট্রাকশন, ইন্টারনেট চেকসাম, ICMP ইকো/রিপ্লাই, UDP এবং সম্পূর্ণ TCP স্টেট মেশিন (SYN, ACK, FIN, RST, উইন্ডো সাইজ ও সিকোয়েন্স নম্বর)।
2. **লিনাক্স বিএসডি সকেট স্ট্যাক (`universe/net/tcp.maya`, `udp.maya`)**:
   - ডিরেক্ট সিসকল সকেট (`AF_INET`, `SOCK_STREAM`/`SOCK_DGRAM`), `sys_bind`, `sys_listen`, `sys_accept`, `sys_connect`, `sys_sendto`, `sys_recvfrom`।
3. **উচ্চ-স্তরের নেটওয়ার্ক প্রোটোকল**:
   - **HTTP/1.1 (`universe/net/http.maya`, ৫৬৮ লাইন)**: RFC 7230 ওয়্যার ফরম্যাট, চাঙ্কড ট্রান্সফার এনকোডিং ডিকোডার, হেডার পার্সার।
   - **HTTP/2 (`universe/net/http2/`, ৩টি ফাইল)**: ১০টি ফ্রেম টাইপ, ৯-বাইট বাইনারি হেডার, RFC 7541 HPACK ৬১-এন্ট্রি স্ট্যাটিক টেবিল ডিকোডার।
   - **QUIC (`universe/net/quic.maya`, ১,১৮৩ লাইন)**: RFC 9000 লং/শর্ট প্যাকেট, ভ্যারিয়েবল ইন্টিজার, RFC 9002 কনজেশন কন্ট্রোল (Slow Start, RTT ট্র্যাকিং)।
   - **WebSocket (`universe/net/websocket.maya`, ৫৯৬ লাইন)**: RFC 6455 আসল SHA-1 + Base64 `Sec-WebSocket-Accept` হ্যান্ডশেক কি এবং ফ্রেম মাস্কিং/আনমাস্কিং।
   - **FastCGI (`universe/web/polymorphic_server.maya`, ৩২৬ লাইন)**: RFC 3875 বাইনারি ফ্রেম পার্সার।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `universe/net/dns.maya:161-195`: `dns_parse_response` ১২-বাইটের হেডার পার্স করলেও কোনো Answer Resource Record (A, AAAA, CNAME) ডিকোড করে না; খালি অ্যারে `answers: []` রিটার্ন করে।
- `universe/net/tls/tls13.maya:34, 55`: `tls_aes_gcm_encrypt`/`decrypt` কলারের কি উপেক্ষা করে একটি হার্ডকোডেড ৩২-বাইট কি (`[0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,0,1]`) ব্যবহার করে।
- `universe/net/tls/record.maya:18-26`: `record_layer_encrypt`/`decrypt` প্লেইনটেক্সট কোনো এনক্রিপশন ছাড়াই সরাসরি ফেরত দেয়।
- `universe/net/xdp.maya:85-97` ও `ebpf_p4.maya:79-100`: AF_XDP কার্নেল বাইপাস (Family 44) ও eBPF (`sys_bpf`) সিসকলের বদলে ইউজারল্যান্ড মেমোরি অ্যারে ম্যাচিং করে।

---

### ৩.৪ কৃত্রিম বুদ্ধিমত্তা ও মেশিন লার্নিং সাবসিস্টেম (AI & ML)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
1. **N-ডাইমেনশনাল টেনসর ইঞ্জিন (`universe/ai/tensor.maya`, ১,৯৪৩ লাইন)**:
   - রো-মেজর স্ট্রাইডেড মেমরি ইন্ডেক্সিং: $\text{Offset}(c) = \text{offset}_{\text{base}} + \sum c_i \times \text{strides}_i$।
   - জিরো-কপি স্লাইসিং ও মাল্টিডাইরেকশনাল ব্রডকাস্টিং ($\text{stride}=0$ অ্যাসাইনমেন্ট)।
   - বিশুদ্ধ মায়া ট্রানসেন্ডেন্টাল ফাংশন: $1/1024$ রেঞ্জ রিডাকশন ও স্কয়ারিং সহ Taylor সিরিজ $e^x$, পলিনোমিয়াল $\ln(x)$, এবং ২০-ইটারেশন নিউটন-র‌্যাফসন $\sqrt{x}$ (`tensor_math_sqrt`)।
2. **রিভার্স-মোড অটোগ্র্যাড ইঞ্জিন (`universe/ai/autograd.maya`, ৯৪৬ লাইন)**:
   - পোস্ট-অর্ডার ডিএফএস টপোলজিক্যাল সর্ট DAG, মাল্টি-পাথ গ্রেডিয়েন্ট অ্যাকুমুলেশন এবং আনব্রডকাস্টিং রিডাকশন।
   - ২০টির অধিক অপারেশনের জন্য নির্ভুল Vector-Jacobian Product (VJP) (Linear, Matmul, ReLU, GELU, Sigmoid, Softmax, Cross-Entropy Loss)।
3. **নিউরাল নেটওয়ার্ক, ভিশন ও লার্জ ল্যাঙ্গুয়েজ মডেল**:
   - `universe/ai/vision/cnn.maya` (৫৮০ লাইন): ডিফারেনশিয়েবল `im2col`/`col2im` ইমেজ আনফোল্ডিং, `Conv2D`, `MaxPool2D` (আর্গম্যাক্স রাউটিং সহ), `BatchNorm2D`, `ResNetBlock`।
   - `universe/ai/transformer/gpt.maya` (৩১২ লাইন): FlashAttention অনলাইন টাইল্ড অ্যাটেনশন, সার্কুলার রিং বাফার KV-Cache, SafeTensors JSON হেডার পার্সার।
   - `universe/ai/onnx.maya` (৮১৮ লাইন): জিরো-ডিপেনডেন্সি স্ট্রিমিং ONNX প্রোটোবাফ ডিকোডার (LEB128 Varint, IEEE 754 Float32 ডিকোডার) এবং ইন-মেমোরি অনক্স এক্সিকিউশন রানটাইম।
   - `universe/ai/llm/tokenizer.maya` (১৭৭ লাইন): ২৫৬-বাইট ইনিশিয়ালাইজেশন ও ফ্রিকোয়েন্সি মার্জিং সহ সম্পূর্ণ BPE টোকেনাইজার।
4. **হার্ডওয়্যার এক্সিলারেশন ও AMX ম্যাট্রিক্স মাল্টিপ্লিকেশন**:
   - `/proc/cpuinfo` থেকে AMX/AVX-512 ইন্ট্রোস্পেকশন।
   - Intel AMX 16x16 টাইল্ড GEMM কার্নেল (`TDPBSSD`/`TDPBF16PS` সিমুলেশন) এবং AVX-512 16-ওয়াইড আনরোল্ড FMA ভেক্টরাইজড কার্নেল।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `universe/ai/inference.maya:125-138`: `temperature_sample`, `top_k_sample`, `top_p_sample` প্রোবাবিলিটি ডিস্ট্রিবিউশন প্রয়োগ না করে নিঃশর্তভাবে `greedy_sample(logits)` রিটার্ন করে।
- `universe/ai/inference.maya:46-52`: `quantize_dynamic` লিনিয়ার স্কেলিং না করে সকল পজিটিভ মানকে ফিক্সড ১২৮-এ সেট করে।
- `universe/ai/cnn.maya:1-131`: মেথডবিহীন খালি স্ট্রাকট ডিক্লারেশন (যদিও `universe/ai/vision/cnn.maya`-তে পূর্ণাঙ্গ সংস্করণ রয়েছে)।
- `universe/gpu/compute.maya:477-562`: SPIR-V শেডার জেনারেট করলেও রানটাইম বাফার এক্সিকিউশনে `device: "CPU"` সেট করে সিঙ্গেল থ্রেডেড লুপ চালায়।
- `tests/ai/`: বেশ কিছু ইউনিট টেস্ট (`test_cnn.maya`, `test_inference.maya`) আসল মডিউল ইমপোর্ট না করে স্থানীয় ডামি স্ট্রাকট টেস্ট করে।
- `tests/universe/test_ai_tensor.maya:84`: `math_sqrt(4.0)` কল করায় সি-রানটাইমের `int64_t math_sqrt(int64_t)`-এর সাথে টাইপ সিগনেচার ক্ল্যাশ করে LLVM যাচাইকরণ ফেইল করে।

---

### ৩.৫ ক্রিপ্টোগ্রাফি সাবসিস্টেম (Crypto)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
1. **RFC 8032 Ed25519 (`universe/crypto/ed25519.maya`, ৮৫১ লাইন)**: ১৬-লিম্ব $\mathbb{F}_{2^{255}-19}$ ফিল্ড এরিথমেটিক, প্রজেক্টিভ পয়েন্ট অপারেশন, মডুলো $L$ শিফট-অ্যান্ড-সাবট্র্যাক্ট রিডাকশন, স্কয়ার রুট ক্যান্ডিডেট রেজোলিউশন এবং টেস্ট ভেক্টর ১-৫ ভেরিফায়েড।
2. **BN254 PLONK KZG (`universe/crypto/plonk.maya`, ৫৯৬ লাইন)**: ফিল্ড টাওয়ার $\mathbb{F}_p \to \mathbb{F}_{p^{12}}$, মিলার লুপ, KZG পলিনোমিয়াল কমিটমেন্ট ও ওপেনিং প্রুফ ভেরিফিকেশন।
3. **ফাস্ট RSA (`universe/crypto/rsa.maya`, ১২৭ লাইন)**: $O(\log \phi)$ এক্সটেন্ডেড ইউক্লিডিয়ান অ্যালগরিদম (`ext_gcd`) দ্বারা দ্রুত মডুলার ইনভার্সন।
4. **সিমেট্রিক সাইফার ও হ্যাশ ফাংশন**:
   - FIPS 197 AES-128/256 (`universe/crypto/aes.maya`, ৭০৬ লাইন): আসল রিজন্ডেল এস-বক্স, ইনভার্স এস-বক্স, $GF(2^8)$ ফিল্ড গুণন, ECB/CBC/CTR মোড।
   - FIPS 180-4 SHA-256 (২৮৯ লাইন) এবং SHA-512 (৪০১ লাইন): ৬৪/৮০ রাউন্ড কনস্ট্যান্ট সহ স্ট্রিমিং হ্যাশ ইঞ্জিন।
   - $GF(2^{128})$ GHASH পলিনোমিয়াল মাল্টিপ্লিকেশন (`universe/net/tls/tls13.maya:72-112`)।
   - Knuth Algorithm D মাল্টি-প্রিসিশন বিগ-ইন্টিজার ডিভিশন (`universe/security/rsa.maya:55-163`)।

#### খ. অসম্পূর্ণতা ও নিরাপত্তা ঝুঁকি:
- `universe/core/crypto.maya:57-76`: **মারাত্মক নিরাপত্তা ত্রুটি** — Secp256k1 উপবৃত্তীয় বক্ররেখা সমীকরণের বদলে লিনিয়ার যোগফল $(p_1.x + p_2.x) \pmod{10^9+7}$ ব্যবহার করে এবং সিগনেচার হ্যাশের প্রথম ২-বাইটকে $r, s$ হিসেবে গ্রহণ করে।
- `universe/core/crypto.maya:92-114`: ব্লকচেইন মাইনিং মাত্র ২-বাইট চেক করে এবং নিমোনিক ফ্রেজ হার্ডকোডেড ১২টি শব্দ প্রদান করে।
- অনুপস্থিত প্রিমিটিভ: ChaCha20-Poly1305, Keccak-256 (SHA-3), Blake3, RIPEMD160।

---

### ৩.৬ মোবাইল সাবসিস্টেম (Mobile: Android & iOS)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
- **Android APK প্যাকেজিং (`universe/mobile/mobile.maya`, ৪৪২–৫৬৩ লাইন)**:
  - খাঁটি PKZip ফরম্যাটে আনকম্প্রেসড স্টোরড এন্ট্রি, সেন্ট্রাল ডিরেক্টরি হেডার এবং Android `zipalign` ৪,০৯৬-বাইট পেজ বাউন্ডারি এলাইনমেন্ট বাস্তবায়িত।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `universe/mobile/mobile.maya:260-264`: `.so` শেয়ার্ড লাইব্রেরির `.text` সেকশনে `Java_com_maya_MayaNativeActivity_nativeInit` এবং `ANativeActivity_onCreate` এর জন্য মাত্র ২টি আর্ম মেশিন ইনস্ট্রাকশন (`mov x0, #0; ret`) রয়েছে। কোনো `ANativeActivityCallbacks` বা ইভেন্ট লুপ নেই।
- `universe/mobile/mobile.maya:403-424`: `mobile_emit_classes_dex` ডালভিক ম্যাজিক `dex\n035\0`-এর পর ১০৪টি শূন্য বাইট (মোট ১১২ বাইট) লেখে। কোনো ক্লাস বা মেথড বাইটকোড নেই।
- `universe/mobile/mobile.maya:585-598`: সারফেস ফ্রেমবাফারে `pixel_buffer` মাত্র ৪টি ইন্টিজারের অ্যারে। EGL/Vulkan WSI অনুপস্থিত।
- `universe/mobile/platform.maya:326-338`: `jni_generate_native_binding` শুধুমাত্র সি-ফাংশন ডিক্লারেশন স্ট্রিং প্রিন্ট করে; কোনো `JNIEnv*` মার্শালার নেই।
- `universe/mobile/platform.maya:253-267`: পারমিশন, ভাইব্রেশন, নোটিফিকেশন হার্ডকোডেড `1` রিটার্ন করে।
- `universe/mobile/mobile.maya:569-583`: iOS IPA প্যাকেজ একটি হার্ডকোডেড সাইজ (`8388608`) সহ অবজেক্ট রিটার্ন করে; কোনো `.ipa` জিপ ফাইল বা কোড সাইনিং তৈরি করে না।
- **iOS সম্পূর্ণ অনুপস্থিত (0%)**: কোনো Objective-C রানটাইম ব্রিজ (`objc_msgSend`), সুইফট মেটাডাটা, কোকো টাচ UI (`UIApplicationMain`), মেটাল রেন্ডারিং বা কোর-অডিও বাস্তবায়ন নেই।

---

### ৩.৭ আইওটি ও এমবেডেড সাবসিস্টেম (IoT & Bare-Metal)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
- **কর্টেক্স-এম ভেক্টর টেবিল ও লিঙ্কার (`universe/os/freestanding.maya`, ১১১–২০১ লাইন)**:
  - ১৯২-বাইটের স্ট্যান্ডার্ড কর্টেক্স-এম ভেক্টর টেবিল ফরম্যাট (SP, Reset, NMI, HardFault, SysTick ও ৩২টি এক্সটার্নাল IRQ) এবং থাম্ব বিট (`handler | 1`) সেটআপ।
- **RISC-V বেসিক এনকোডার (`compiler/backend/riscv64/codegen.maya`)**:
  - RV64 পূর্ণাঙ্গ ৩২-বিট ইনস্ট্রাকশন এনকোডার (`add`, `sub`, `mul`, `ld`, `sd`, `jalr`, `ecall`)।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `universe/os/hal.maya:23-89`: হার্ডওয়্যার অ্যাবস্ট্রাকশন লেয়ার শুধুমাত্র লিনাক্স হোস্টের `/proc/cpuinfo` রিড করে এবং DMA অ্যালোকেশনে `sys_mmap` কল করে। **GPIO, I2C, SPI, PWM, ADC, DAC, ওয়াকডগ টাইমার বা পাওয়ার ম্যানেজমেন্ট সম্পূর্ণ অনুপস্থিত (0%)**।
- `universe/os/drivers/serial.maya:51-54`: UART 16550 ড্রাইভার কোনো I/O পোর্ট (0x3F8) বা MMIO তে না লিখে মায়া অ্যারেতে পুশ করে।
- `universe/os/freestanding.maya:290-346`: কর্টেক্স-এম ও RISC-V এর CRT0 বুটস্ট্র্যাপ মাত্র ১১টি এবং ৪টি হার্ডকোডেড অপকোড বাইট অ্যারে প্রদান করে। মায়া AST থেকে কর্টেক্স-এম থাম্ব বা RV32IMC-তে কম্পাইল করার পূর্ণাঙ্গ লোয়ারিং ব্যাকএন্ড অনুপস্থিত।
- **অনুপস্থিত আর্কিটেকচার ও RTOS (0%)**: ESP32 (Xtensa ISA), AVR (ATmega328P), FreeRTOS টাস্ক ও কিউ বাইন্ডিং (`xTaskCreate`), এবং Zephyr RTOS বাইন্ডিং অনুপস্থিত।

---

### ৩.৮ ওয়েব ও ওয়াসম সাবসিস্টেম (Web & WASM)

#### ক. স্থাপত্য ও প্রোডাকশন উপাদান:
- **WASM বাইনারি সেকশন এমিটার (`compiler/backend/wasm/wasm_emitter.maya`, ৪০৯ লাইন)**:
  - Type, Import, Function, Table, Memory, Global, Export, Element, Code, Data সেকশনের পূর্ণাঙ্গ LEB128 এনকোডার।
- **DOM-Bypass আর্কিটেকচার (`universe/web/frontend/`)**:
  - ব্রাউজার ডম বাইপাস করে সরাসরি `<canvas>` এলিমেন্টে রেন্ডার করার আর্কিটেকচারাল পাইপলাইন।

#### খ. অসম্পূর্ণতা ও স্টাব:
- `compiler/backend/wasm/wasm_linker.maya:53-82`: `compile_maya_func` শুধুমাত্র ৪টি IR নির্দেশ ("ADD", "SUB", "LOAD", "STORE") চেনে; কোনো কন্ট্রোল ফ্লো বা লোকাল ইনডেক্সিং নেই।
- `compiler/backend/wasm/wasm_linker.maya:84-136`: `emit_wasm` ইনপুট মডিউল ফেলে দিয়ে হার্ডকোডেড `local.get 0; local.get 1; i32.add` ফাংশন ও খালি GC বডি রিটার্ন করে।
- `universe/assimilator/js_bridge.maya:30-76`: `js_eval`, `js_require`, `js_fetch` কনসোলে স্ট্রিং প্রিন্ট করে `js_undefined()` রিটার্ন করে। কোনো JS-WASM ট্রাম্পোলিন নেই।
- `universe/web/frontend/renderer/webgpu_renderer.maya:505-603`: ওয়েবজিপিইউ কমান্ড ডিকশনারি তৈরি করে কিন্তু ব্রাউজার `navigator.gpu` এপিআই কল করে না।
- **অনুপস্থিত ওয়েব উপাদান**: ব্রাউজার ডম ম্যানিপুলেশন বাইন্ডিং (`document.*`), Web Audio API (`AudioContext`), এবং রিয়েল ওয়েব ওয়ার্কার মাল্টি-থ্রেডিং (`SharedArrayBuffer` / `Atomics`) অনুপস্থিত।

---

## ৪. অবশিষ্ট ব্লুপ্রিন্ট, স্টাব ও মকসমূহের পুঙ্খানুপুঙ্খ মাস্টার ক্যাটালগ (Master Blueprint/Stub Inventory)

নিচে সমগ্র কোডবেসের প্রতিটি অবশিষ্ট ব্লুপ্রিন্ট, স্টাব ও সিমুলেশনের নির্ভুল ফাইল পাথ, লাইন নম্বর ও প্রযুক্তিগত বিবরণ প্রদান করা হলো:

| ক্রমিক | সাবসিস্টেম | ফাইলের পাথ (File Path) | লাইন নম্বর | ফাংশন / প্রতীক | তীব্রতা (Severity) | ত্রুটির ধরন ও বিস্তারিত কোড বিশ্লেষণ |
|:---:|---|---|:---:|---|:---:|---|
| **১** | Compiler | `compiler/backend/omni_binary.maya` | ১২৩–১৪০ | `omni_emit_polyglot_raw_binary` | **HIGH** | **Incomplete APE Trampoline**: শেল স্ক্রিপ্ট `"MZqFpD='\n'\nexit 0\n"` নির্গমন করে; লিনাক্স `execve`-এ `ENOEXEC` (Errno 8) দেয়; নেটিভ মেশিন কোড ট্রাম্পোলিন অনুপস্থিত। |
| **২** | Compiler | `compiler/backend/gc.maya` | ৪৫১–৪৫৩ | `get_current_rbp` | **MEDIUM** | **Stubbed RBP Unwinder**: কনস্ট্যান্ট `0` রিটার্ন করায় স্ট্যাক ফ্রেম ট্রাভার্সাল লুপ কখনো কার্যকর হয় না। |
| **৩** | OS | `universe/os/process.maya` | ৭৯–৮৬ | `process_spawn` | **HIGH** | **Stubbed Child Branch**: ফর্কের পর চাইল্ড প্রসেস `process_execve` ডাকার বদলে `process_exit(0)` এক্সিকিউট করে বন্ধ হয়ে যায়। |
| **৪** | OS | `universe/os/path.maya` | ৫–১৫, ২৬–২৮ | `path_dirname`, `path_basename`, `path_ext`, `path_normalize` | **HIGH** | **Dummy Pass-Through**: কোনো স্ট্রিং পার্সিং বা পাথ নরমালাইজেশন না করে সরাসরি ইনপুট `p` রিটার্ন করে। |
| **৫** | OS | `universe/os/env.maya` | ৬১–৬২ | `env_home`, `env_tmp` | **MEDIUM** | **Hardcoded Paths**: সিস্টেম এনভায়রনমেন্ট ভেরিয়েবল না পড়ে স্থির `"/home"` ও `"/tmp"` প্রদান করে। |
| **৬** | OS | `universe/os/drivers/disk.maya` | ২০–৪২, ৬৮–৮২ | `disk_read_sector`, `disk_write_sector`, `ahci_*` | **MEDIUM** | **Simulated Disk Driver**: ৫১২টি শূন্যযুক্ত ডামি বাফার রিটার্ন করে; রাইট অপারেশন শুধু কনসোলে প্রিন্ট করে। |
| **৭** | OS | `universe/fs/mayafs.maya` | ৬৫, ৯৯–১০২ | `mayafs_write_file_cow`, `mayafs_verify_and_heal_block` | **MEDIUM** | **Pseudo Merkle Checksum**: আসল কন্টেন্ট হ্যাশ না করে ফাইলের নাম ও সাইজ হ্যাশ করে; ভেরিফিকেশনে হ্যাশ তুলনা না করেই ১ দেয়। |
| **৮** | OS | `runtime/async/coroutine.maya` | ৮২–৯৮ | `coro_resume`, `coro_yield` | **LOW** | **State Simulation**: কোনো হার্ডওয়্যার/স্ট্যাক কনটেক্সট সুইচিং ছাড়া ইন্টিজার স্টেট টগল করে। |
| **৯** | OS | `runtime/async/event_loop.maya` | ৪৮–৫১ | `event_loop_register` | **LOW** | **In-Memory Event Registration**: লিনাক্স `epoll` সিসকল ছাড়া শুধুমাত্র মায়া অ্যারেতে FD পুশ করে। |
| **১০** | OS | `runtime/async/scheduler.maya` | ৬৪–৬৯ | `scheduler_spawn_task` | **LOW** | **Mock Scheduler**: ওয়ার্ক-স্টিলিং বা থ্রেড পুল ছাড়া শুধু টাস্ক অ্যারেতে আইডি যোগ করে। |
| **১১** | Net | `universe/net/dns.maya` | ১৬১–১৯৫ | `dns_parse_response` | **HIGH** | **Stubbed DNS Answers**: ১২-বাইট হেডার পার্স করে কিন্তু Resource Records পার্স না করে খালি `answers: []` রিটার্ন করে। |
| **১২** | Net | `universe/net/tls/tls13.maya` | ৩৪, ৫৫ | `tls_aes_gcm_encrypt`, `tls_aes_gcm_decrypt` | **HIGH** | **Hardcoded Fixed Key**: ইউজারের সেশন কি উপেক্ষা করে হার্ডকোডেড ৩২-বাইট কি `[0..9..]` ব্যবহার করে। |
| **১৩** | Net | `universe/net/tls/record.maya` | ১৮–২৬ | `record_layer_encrypt`, `record_layer_decrypt` | **HIGH** | **Pass-Through Encryption**: কোনো সাইফার রূপান্তর ছাড়াই প্লেইনটেক্সট হুবহু রিটার্ন করে। |
| **১৪** | Net | `universe/io/uring.maya` | ২১৫–২৩২ | `io_uring_submit_and_reap` | **MEDIUM** | **Simulated CQE Harvesting**: কার্নেল CQ রিং মেমোরি রিড না করে নকল `res = sqe.nbytes` অ্যারে রিটার্ন করে। |
| **১৫** | Net | `universe/io/uring_sqpoll.maya` | ১২৭–১৪২ | `io_uring_sqpoll_poll_kthread` | **MEDIUM** | **Simulated SQPOLL**: ইউজারল্যান্ডে ম্যানুয়ালি কপি করে কার্নেল পোলিং সিমুলেট করে। |
| **১৬** | Net | `universe/net/xdp.maya` | ৮৫–৯৭, ১০৩–১৬৪ | `xdp_socket_open`, `xdp_poll_rx` | **MEDIUM** | **Userland Ring Simulation**: AF_XDP কার্নেল সকেটের বদলে সাধারণ ইউজারল্যান্ড মেমোরি অ্যারে ব্যবহার করে। |
| **১৭** | Net | `universe/net/ebpf_p4.maya` | ৭৯–১০০ | `smartnic_evaluate_packet` | **LOW** | **In-Memory AST Matcher**: `sys_bpf` সিসকল ছাড়া মেমোরি অবজেক্ট ম্যাচিং করে। |
| **১৮** | AI | `universe/ai/inference.maya` | ১২৫–১৩৮ | `temperature_sample`, `top_k_sample`, `top_p_sample` | **HIGH** | **Stubbed Sampling**: কোনো প্রোবাবিলিস্টিক স্যাম্পলিং না করে নিঃশর্তভাবে `greedy_sample(logits)` রিটার্ন করে। |
| **১৯** | AI | `universe/ai/inference.maya` | ৪৬–৫২ | `quantize_dynamic` | **MEDIUM** | **Mock Quantization**: লিনিয়ার স্কেলিং ছাড়া সব পজিটিভ মানকে ফিক্সড ১২৮ বানায়। |
| **২০** | AI | `universe/ai/cnn.maya` | ১–১৩১ | `Conv2D`, `MaxPool2D` ইত্যাদি | **LOW** | **Empty Struct Skeletons**: মেথডবিহীন ফাঁকা স্ট্রাকট (যা `universe/ai/vision/cnn.maya` দ্বারা প্রতিস্থাপিত)। |
| **২১** | AI | `universe/gpu/compute.maya` | ৪৭৭–৫৬২ | `GpuBuffer`, `gpu_kernel_launch` | **MEDIUM** | **CPU Array Fallback**: GPU ড্রাইভারে না পাঠিয়ে সিঙ্গেল থ্রেডেড CPU লুপে চালায়। |
| **২২** | AI | `tests/ai/test_cnn.maya`, `test_inference.maya` | সর্বত্র | টেস্ট সুইট | **MEDIUM** | **Tautological Mock Tests**: আসল মডিউল লোড না করে স্থানীয় ডামি স্ট্রাকট টেস্ট করে। |
| **২৩** | AI | `tests/universe/test_ai_tensor.maya` | ৮৪ | `math_sqrt` কল | **MEDIUM** | **LLVM Type Conflict**: ফ্লোট আর্গুমেন্ট পাঠানোয় C রানটাইম `int64_t math_sqrt(int64_t)`-এর সাথে ক্ল্যাশ করে। |
| **২৪** | Crypto | `universe/core/crypto.maya` | ৫৭–৭৬ | `secp256k1_point_add`, `secp256k1_sign` | **CRITICAL** | **Broken Curve Math**: উপবৃত্তীয় বক্ররেখার বদলে লিনিয়ার মডুলো যোগ ($10^9+7$) এবং ২-বাইট হ্যাশ ট্রাংকেশন। |
| **২৫** | Crypto | `universe/core/crypto.maya` | ৯২–১১৪, ৩২০–৩৪১ | `mine_block`, `wallet_new` | **HIGH** | **Simulated Blockchain**: ২-বাইট মাইনিং এবং হার্ডকোডেড ১২-শব্দের নিমোনিক স্টাব। |
| **২৬** | Crypto | `universe/crypto/plonk.maya` | ৫৫৮–৫৭৭ | `plonk_create_recursive_proof` | **MEDIUM** | **Hardcoded Proof**: ফিক্সড পলিনোমিয়াল `coeffs = [5, 2, 3]` ও ফিক্সড ইভ্যালুয়েশন পয়েন্ট। |
| **২৭** | Mobile | `universe/mobile/platform.maya` | ৩২৬–৩৩৮ | `jni_generate_native_binding` | **HIGH** | **String Prototype Only**: শুধু C সিগনেচার স্ট্রিং জেনারেট করে; রানটাইম JNIEnv FFI নেই। |
| **২৮** | Mobile | `universe/mobile/mobile.maya` | ২৬০–২৬৪ | `mobile_emit_arm64_libmaya_so` | **HIGH** | **Stubbed ARM64 .so**: `.text` এ মাত্র ২টি নির্দেশ (`mov x0, #0; ret`); কোনো `ANativeActivityCallbacks` নেই। |
| **২৯** | Mobile | `universe/mobile/mobile.maya` | ৪০৩–৪২৪ | `mobile_emit_classes_dex` | **HIGH** | **Zero-Padded DEX**: ম্যাজিক হেডার বাদে ১০৪টি শূন্য বাইট; কোনো এক্সিকিউটেবল ডালভিক বাইটকোড নেই। |
| **৩০** | Mobile | `universe/mobile/mobile.maya` | ৫৮৫–৫৯৮ | `mobile_surface_push_frame` | **MEDIUM** | **Mock Framebuffer**: ৪টি ইন্টিজারের ডামি অ্যারে; Vulkan/EGL WSI নেই। |
| **৩১** | Mobile | `universe/mobile/platform.maya` | ২৫৩–২৬৭ | `app_request_permission` ইত্যাদি | **LOW** | **Hardcoded Stubs**: পারমিশন, ভাইব্রেশন, নোটিফিকেশনে সর্বদা ১ রিটার্ন করে। |
| **৩২** | Mobile | `universe/mobile/mobile.maya` | ৫৬৯–৫৮৩ | `mobile_build_ios_ipa` | **HIGH** | **Hardcoded IPA Blueprint**: হার্ডকোডেড সাইজ `8388608` দেয়; আসল `.ipa` জিপ ফাইল বা সাইনিং তৈরি করে না। |
| **৩৩** | Mobile | `compiler/backend/macho_writer.maya` | ২১৪–২২৫ | `macho_build_header` | **MEDIUM** | **Desktop Only Mach-O**: শুধুমাত্র x86-64 সমর্থন করে; iOS ARM64 বা `LC_BUILD_VERSION` নেই। |
| **৩৪** | IoT | `universe/os/hal.maya` | ১০–১১২ | HAL মডিউল | **HIGH** | **Host-Only HAL**: শুধুমাত্র হোস্ট লিনাক্স `/proc/cpuinfo` পড়ে; কোনো GPIO, I2C, SPI, PWM, ADC নেই। |
| **৩৫** | IoT | `universe/os/drivers/serial.maya` | ৫১–৫৪ | `serial_write_byte` | **MEDIUM** | **Array Simulation**: UART পোর্টে (0x3F8) না লিখে মায়া অ্যারেতে পুশ করে। |
| **৩৬** | IoT | `universe/os/drivers/vga.maya` | ৪৭–৬৮ | `vga_text_buffer_new` | **LOW** | **Array Simulation**: ফিজিক্যাল মেমোরি `0xB8000`-এ না লিখে মেমোরি অবজেক্ট বানায়। |
| **৩৭** | IoT | `universe/os/freestanding.maya` | ২৯০–৩৪৭ | `cortex_m_emit_crt0_thumb`, `riscv_*` | **HIGH** | **Synthetic Opcode Buffers**: ১১টি এবং ৪টি হার্ডকোডেড অপকোড দেয়; পূর্ণাঙ্গ কম্পাইলার কোডজেন নেই। |
| **৩৮** | IoT | `compiler/backend/riscv/codegen.maya` | ১–৮৭ | `rv_emit_*` | **MEDIUM** | **Incomplete RV32 Codegen**: ব্রাঞ্চিং ও লেবেল রেজোলিউশন ছাড়া আংশিক নির্দেশ এনকোডার। |
| **৩৯** | Web | `compiler/backend/wasm/wasm_linker.maya` | ৫৩–৮২ | `compile_maya_func` | **HIGH** | **Dummy IR Loop**: মাত্র ৪টি নির্দেশ চেনে ("ADD", "SUB", "LOAD", "STORE"); কোনো মেমরি লোয়ারিং নেই। |
| **৪০** | Web | `compiler/backend/wasm/wasm_linker.maya` | ৮৪–১৩৬ | `emit_wasm` | **HIGH** | **Hardcoded WASM Module**: ইনপুট ফেলে দিয়ে ফিক্সড `i32.add` ফাংশন ও খালি GC বডি নির্গমন করে। |
| **৪১** | Web | `universe/assimilator/js_bridge.maya` | ৩০–৭৬ | `js_eval`, `js_require`, `js_fetch` | **HIGH** | **Stdout Logger Stubs**: কনসোলে প্রিন্ট করে `js_undefined()` দেয়; কোনো JS-WASM ট্রাম্পোলিন নেই। |
| **৪২** | Web | `universe/web/frontend/renderer/webgpu_renderer.maya` | ৫০৫–৬০৩ | `webgpu_renderer_end_frame` | **MEDIUM** | **Mock WebGPU Commands**: ব্রাউজার WebGPU কল ছাড়া ডিকশনারি কমান্ড রেকর্ড করে। |
| **৪৩** | Web | `universe/web/frontend/concurrency/worker_pool.maya` | ১–৪২০ | `worker_pool_*` | **LOW** | **In-Memory Thread Sim**: ব্রাউজার `Worker` বা `Atomics` ছাড়া রিং বাফার সিমুলেশন করে। |

---

## ৫. ক্রিটিক্যাল নিরাপত্তা ঝুঁকি ও স্থাপত্যগত দুর্বলতা (Critical Security Vulnerabilities)

---

### ৫.১ Secp256k1 লিনিয়ার মোডুলো অ্যাডিশন ও ২-বাইট ট্রাংকেশন (`universe/core/crypto.maya:57-76`)
- **কোড বিশ্লেষণ**:
  ```maya
  @fn secp256k1_point_add(p1, p2)
    return { x: (p1.x + p2.x) % 1000000007, y: (p1.y + p2.y) % 1000000007 }
  @end

  @fn secp256k1_sign(priv_key, message_hash)
    h = sha256_hash_bytes(message_hash)
    r_val = 1
    @if h.len() > 0 r_val = h[0] @end
    s_val = 2
    @if h.len() > 1 s_val = h[1] @end
    return { r: r_val, s: s_val, v: 27 }
  @end

  @fn secp256k1_recover_pubkey(signature, message_hash)
    return { x: signature.r, y: signature.s }
  @end
  ```
- **ঝুঁকির তীব্রতা**: **CRITICAL (CVE-Grade Vulnerability)**
- **প্রভাব**: এটি কোনো ক্রিপ্টোগ্রাফিক সুরক্ষা প্রদান করে না। উপবৃত্তীয় বক্ররেখা সমীকরণের পরিবর্তে সাধারণ প্রাইম $10^9+7$ দ্বারা যোগ করা হয়েছে এবং সিগনেচারের প্রথম ২-বাইটকে $r, s$ হিসেবে গ্রহণ করে পাবলিক কি হিসেবে ফেরত দেওয়া হয়েছে। কোনো ওয়ালেট বা প্রমাণীকরণ সিস্টেমে এটি ব্যবহার করলে যে কেউ শূন্য চেষ্টায় জালিয়াতি করতে সক্ষম হবে।

---

### ৫.২ TLS 1.3 ফিক্সড সিমেট্রিক কি ও পাস-থ্রু এনক্রিপশন (`universe/net/tls/`)
- **কোড বিশ্লেষণ**:
  `universe/net/tls/tls13.maya:34, 55` ফাংশনদ্বয়ে ডাইনামিক সেশন কি ব্যবহারের পরিবর্তে ফিক্সড ৩২-বাইট অ্যারে ব্যবহার করা হয়। এছাড়া `universe/net/tls/record.maya:18-26`-এ `record_layer_encrypt` প্লেইনটেক্সট কোনো এনক্রিপশন ছাড়াই নেটওয়ার্কে প্রেরণ করে।
- **ঝুঁকির তীব্রতা**: **CRITICAL**
- **প্রভাব**: ম্যান-ইন-দ্য-মিডল (MITM) আক্রমণকারী সম্পূর্ণ নেটওয়ার্ক ট্র্যাফিক প্লেইনটেক্সট আকারে পড়তে ও পরিবর্তন করতে পারবে।

---

### ৫.৩ MayaFS ভুয়া মারকেল ভ্যালিডেশন (`universe/fs/mayafs.maya:65, 99-102`)
- **কোড বিশ্লেষণ**:
  `mayafs_write_file_cow` ব্লকের আসল বাইট হ্যাশ না করে `filename + ":" + content_bytes.len()` হ্যাশ করে। `mayafs_verify_and_heal_block` ব্লকের আইডি হ্যাশ করে কিন্তু মূল ব্লকের সাথে তুলনা না করেই ১ রিটার্ন করে।
- **ঝুঁকির তীব্রতা**: **HIGH**
- **প্রভাব**: ফাইলসিস্টেমের ডেটা ডিস্কে করাপ্ট বা পরিবর্তিত হলেও ফাইলসিস্টেম তা শনাক্ত বা হিল (Heal) করতে পারবে না; সাইাইলেন্ট ডেটা করাপশন ঘটবে।

---

### ৫.৪ ZKP R1CS টাউটোলজি (`universe/crypto/zkp.maya:112-117`)
- **কোড বিশ্লেষণ**:
  প্রুভার $h = (A \cdot B - C) \pmod p$ তৈরি করে এবং ভেরিফায়ার $A \cdot B \equiv C + h \pmod p$ চেক করে।
- **ঝুঁকির তীব্রতা**: **MEDIUM**
- **প্রভাব**: এটি গাণিতিক প্রুফ সিস্টেম নয়; যেকোনো মিথ্যা স্টেটমেন্টের জন্যও $h$ তৈরি করে ভেরিফায়ারকে ফাঁকি দেওয়া সম্ভব।

---

## ৬. প্রধান স্থপতির জন্য বাস্তবায়ন রোডম্যাপ ও অগ্রাধিকার তালিকা (Lead Architect's Roadmap)

মায়া ইকোসিস্টেমের প্রধান স্থপতির (Lead Architect) জন্য বাস্তবায়নের অগ্রাধিকার রোডম্যাপ:

```
+=======================================================================================================+
|                                  মায়া ইকোসিস্টেমের অগ্রাধিকার রোডম্যাপ                                |
+=======================================================================================================+
| [P0] জরুরি নিরাপত্তা ও কার্নেল কারেক্টনেস (Immediate Security & Kernel Correctness)                     |
|  ├── ১. universe/core/crypto.maya-র ভুয়া Secp256k1 অপসারন ও Ed25519-এ সম্পূর্ণ স্থানান্তর।             |
|  ├── ২. universe/net/tls/-এ ডাইনামিক সেশন কি, আসল AES-GCM ও রেকর্ড লেয়ার এনক্রিপশন যুক্ত করা।        |
|  ├── ৩. universe/os/process.maya-র `process_spawn` চাইল্ড ব্রাঞ্চে `process_execve` ওয়্যারিং করা।    |
|  ├── ৪. universe/os/path.maya-তে স্ট্রিং স্প্লিট ও পাথ রিলেটিভ/অ্যাবসোলিউট রেজোলিউশন বাস্তবায়ন।       |
|  └── ৫. tests/universe/test_ai_tensor.maya:84-এ `tensor_math_sqrt` নাম পরিবর্তন করে LLVM ঠিক করা।    |
+-------------------------------------------------------------------------------------------------------+
| [P1] লিঙ্কার, ট্রাম্পোলিন ও আইও-ইউরিং কার্নেল ইন্টিগ্রেশন (Linker, Trampoline & IO_URING)            |
|  ├── ১. compiler/backend/omni_binary.maya-তে Cosmopolitan মেশিন কোড অ্যাসেম্বলি ট্রাম্পোলিন লোড করা।   |
|  ├── ২. universe/io/uring.maya-তে ইউজারল্যান্ড নকল বাদ দিয়ে mmap CQ রিং বাফার থেকে আসল CQE রিড করা। |
|  ├── ৩. universe/net/dns.maya:161-195-এ DNS Answer Resource Record (A, AAAA, CNAME) পার্সার তৈরি।  |
|  └── ৪. compiler/backend/wasm/wasm_linker.maya-তে সম্পূর্ণ MIR-টু-WASM স্ট্যাক মেশিন লোয়ারিং তৈরি।    |
+-------------------------------------------------------------------------------------------------------+
| [P2] পলিনোমিয়াল জেডকেপি ও এআই স্যাম্পলিং কমপ্লিশন (ZKP Completion & AI Probabilistic Sampling)       |
|  ├── ১. universe/crypto/plonk.maya-তে গ্র্যান্ড প্রোডাক্ট পারমুটেশন $z(X)$ ও ভ্যানিশিং পলিনোমিয়াল তৈরি।|
|  ├── ২. universe/ai/inference.maya-তে আসল টেম্পারেচার, Top-K, Top-P মাল্টিনমিয়াল স্যাম্পলিং তৈরি।  |
|  ├── ৩. universe/ai/inference.maya-তে রিয়েল লিনিয়ার INT8 কোয়ান্টাইজেশন ($q = (x-min)/scale$) তৈরি।  |
|  └── ৪. tests/ai/ টেস্ট সুইট পুনর্লিখন করে আসল AI মডিউলসমূহ টেস্টের আওতায় আনা।                      |
+-------------------------------------------------------------------------------------------------------+
| [P3] মোবাইল, এমবেডেড ও ব্রাউজার রানটাইম বাস্তবায়ন (Mobile, Embedded HAL & Web Runtime)               |
|  ├── ১. universe/mobile/mobile.maya-তে ARM64 কোডজেন ও `ANativeActivityCallbacks` ইভেন্ট লুপ তৈরি।    |
|  ├── ২. universe/mobile/mobile.maya-তে বৈধ Dalvik DEX ক্লাস ডেসক্রিপ্টর ও মেথড বাইটকোড তৈরি।           |
|  ├── ৩. compiler/backend/macho_writer.maya-তে iOS ARM64 ও `LC_BUILD_VERSION` সাপোর্ট যুক্ত করা।      |
|  ├── ৪. universe/os/hal.maya-তে মেমোরি-ম্যাপড (MMIO) GPIO, I2C, SPI, UART, Timer হার্ডওয়্যার ড্রাইভার।|
|  ├── ৫. compiler/backend/riscv ও arm-এ পূর্ণাঙ্গ RV32IMC এবং Thumb-2 ব্রাঞ্চিং কোড জেনারেটর তৈরি।     |
|  └── ৬. universe/assimilator/js_bridge.maya-তে দ্বিমুখী WASM-JS টাইপড-অ্যারে মেমোরি ট্রাম্পোলিন তৈরি।  |
+=======================================================================================================+
```

---

## ৭. স্বাধীন পুনরুৎপাদন ও যাচাইকরণ কমান্ড (Independent Verification Commands)

এই নিরীক্ষা প্রতিবেদনের ফলাফল ও পর্যবেক্ষণসমূহ স্বাধীনভাবে পুনরুৎপাদন ও যাচাই করার জন্য ওয়ার্কস্পেস রুটে (`/home/shafiullah/Documents/file/maya`) নিচের কমান্ডসমূহ এক্সিকিউট করুন:

### ১. সম্প্রতি ঠিক করা ৫টি জটিল সিস্টেমের যাচাইকরণ
```bash
# ক. Ed25519 RFC 8032 টেস্ট ভেক্টর (১-৫) ও অ্যাডভারসারিয়াল ৬৪-বিট ফ্লিপ টেস্ট
./bin/maya tests/e2e/tier4_applications/test_app_ed25519_rfc8032_vectors.maya
./bin/maya tests/adversarial/test_crypto_adversarial_sha512_ed25519.maya

# খ. GC Mark-and-Sweep ১৬-থ্রেড ৮০,০০০ অপারেশন স্ট্রেস টেস্ট
make -C runtime test
./bin/test_gc_challenger2_stress
./bin/test_syscall_gc_stress_native

# গ. PLONK KZG পেয়ারিং যাচাইকরণ ও হার্ডকোডেড কনস্ট্যান্ট পরিদর্শন
./bin/maya tests/crypto/test_plonk_kzg.maya
grep -n "coeffs = \[5, 2, 3\]" universe/crypto/plonk.maya

# ঘ. Omni-Binary APE শেল বনাম কার্নেল execve এর অমিল যাচাইকরণ
./bin/maya tests/backend/test_omni_binary.maya
/bin/sh /tmp/test_omni_app # শেল মোডে ০ কোডে এক্সিট করে
python3 -c "import os; os.execv('/tmp/test_omni_app', ['/tmp/test_omni_app'])" # কার্নেল execve-এ OSError: [Errno 8] Exec format error দেবে

# ঙ. io_uring সিসকল ও ইউজারল্যান্ড নকল ইভেন্ট লুপ পরিদর্শন
./bin/maya tests/io/test_io_uring.maya
grep -n "res_val = sqe.nbytes" universe/io/uring.maya
```

### ২. এআই, কম্পাইলার ও ক্রিপ্টো সাবসিস্টেমের লাইভ টেস্ট
```bash
# ক. AI টেনসর ইঞ্জিন, AMX Tiled GEMM, AVX-512 ও ONNX প্রোটোবাফ পার্সার
./bin/maya tests/ai/test_amx_tensor_gemm.maya
./bin/maya tests/ai/test_simd_amx_matmul.maya
./bin/maya tests/ai/test_onnx.maya
./bin/maya tests/ai/test_maya_gpt.maya
./bin/maya tests/e2e/tier4_applications/test_app_safetensors_transformer.maya

# খ. RSA ext_gcd দ্রুত মডুলার ইনভার্সন টেস্ট
./bin/maya tests/e2e/tier1_features/test_crypto_rsa_extgcd.maya

# গ. Mach-O 64 ও WASM বাইনারি এমিটার পরিদর্শন
grep -n "write_macho64_executable" compiler/backend/macho_writer.maya
grep -n "write_wasm_module" compiler/backend/wasm/wasm_emitter.maya
```

### ৩. স্টাব ও নিরাপত্তা দুর্বলতাসমূহের সোর্স কোড লাইন পরিদর্শন
```bash
# ১. Secp256k1 এর বিপজ্জনক 10^9+7 যোগফল ও ২-বাইট ট্রাংকেশন
sed -n '57,77p' universe/core/crypto.maya

# ২. process_spawn এর চাইল্ড এক্সিট স্টাব
sed -n '78,87p' universe/os/process.maya

# ৩. path_* ডামি পাস-থ্রু ফাংশনসমূহ
cat universe/os/path.maya

# ৪. DNS Answer খালি রাখার প্রমাণ
sed -n '160,196p' universe/net/dns.maya

# ৫. TLS 1.3 হার্ডকোডেড কি ও রেকর্ড লেয়ার পাস-থ্রু
sed -n '30,58p' universe/net/tls/tls13.maya
cat universe/net/tls/record.maya

# ৬. Android .so এর ২-ইনস্ট্রাকশন আর্ম স্টাব ও ডালভিক ০-প্যাডেড DEX
sed -n '260,265p' universe/mobile/mobile.maya
sed -n '403,425p' universe/mobile/mobile.maya

# ৭. WASM লিঙ্কারের ৪-অপারেশন ডামি লুপ ও হার্ডকোডেড emit_wasm
sed -n '53,136p' compiler/backend/wasm/wasm_linker.maya

# ৮. JS ব্রিজের কনসোল লগ স্টাব
cat universe/assimilator/js_bridge.maya
```

---
**প্রতিবেদন সমাপ্ত**  
*এই মহা-নিরীক্ষা প্রতিবেদনটি মায়া প্রোগ্রামিং ভাষা ইকোসিস্টেমের প্রতিটি সোর্স ফাইল ও টেস্ট কেসের প্রত্যক্ষ পর্যবেক্ষণের ভিত্তিতে সম্পূর্ণ সততা ও নিখুঁত প্রযুক্তিগত মানদণ্ডে রচিত।*
